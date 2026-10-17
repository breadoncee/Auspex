//
//  BatteryCollector.swift
//  Auspex
//
//  Battery charge/state via the public IOKit power-sources API, plus
//  health/cycle-count via the AppleSmartBattery IORegistry entry.
//  Returns isPresent == false on desktop Macs (no battery) so the UI can
//  hide the section.
//

import Foundation
import IOKit
import IOKit.ps

struct BatteryCollector {
    func collect() -> BatteryInfo {
        var info = BatteryInfo()

        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return info }

        var descriptions: [[String: Any]] = []
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any] else { return info }
            descriptions.append(description)
        }
        info = Self.snapshot(from: descriptions)
        if info.isAvailable && info.isPresent { enrichWithSmartBattery(&info) }
        return info
    }

    /// nil represents a failed query; an empty source list is valid on desktops.
    static func snapshot(from descriptions: [[String: Any]]?) -> BatteryInfo {
        var info = BatteryInfo()
        guard let descriptions,
              descriptions.allSatisfy({ $0[kIOPSTypeKey] is String }) else { return info }
        guard let desc = descriptions.first(where: {
            ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType
        }) else {
            info.isAvailable = true
            return info
        }
        info.isPresent = true
        guard let current = desc[kIOPSCurrentCapacityKey] as? Int,
              let maximum = desc[kIOPSMaxCapacityKey] as? Int, maximum > 0,
              current >= 0 else { return info }
        info.isAvailable = true
        info.percent = min(100, Int((Double(current) / Double(maximum) * 100).rounded()))
        info.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        if let state = desc[kIOPSPowerSourceStateKey] as? String {
            info.isPluggedIn = (state == kIOPSACPowerValue)
        }
        if let mins = desc[kIOPSTimeToEmptyKey] as? Int, mins > 0, !info.isCharging {
            info.timeRemainingMinutes = mins
        } else if let mins = desc[kIOPSTimeToFullChargeKey] as? Int, mins > 0, info.isCharging {
            info.timeRemainingMinutes = mins
        }

        return info
    }

    /// Cycle count, condition, and health % from AppleSmartBattery.
    private func enrichWithSmartBattery(_ info: inout BatteryInfo) {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
                == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any]
        else { return }

        if let cycles = dict["CycleCount"] as? Int { info.cycleCount = cycles }
        if let condition = dict["BatteryHealthCondition"] as? String {
            info.condition = condition
        }

        info.healthPercent = Self.healthPercent(from: dict)
    }

    // macOS may expose capacities at the top level or under BatteryData.
    static func healthPercent(from properties: [String: Any]) -> Int? {
        let dict = properties
        let batteryData = dict["BatteryData"] as? [String: Any] ?? [:]
        if let design = (dict["DesignCapacity"] as? Int) ?? (batteryData["DesignCapacity"] as? Int), design > 0 {
            let nominal = (dict["AppleRawMaxCapacity"] as? Int)
                ?? (dict["NominalChargeCapacity"] as? Int)
                ?? (batteryData["NominalChargeCapacity"] as? Int)
                ?? (batteryData["FullChargeCapacity"] as? Int)
            if let nominal, nominal > 0 {
                return min(100, Int((Double(nominal) / Double(design) * 100).rounded()))
            }
        }
        return nil
    }
}

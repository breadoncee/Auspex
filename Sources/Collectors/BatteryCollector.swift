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
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                as? [String: Any]
        else {
            return info   // no battery present
        }

        // Only treat it as a battery if the type says so.
        if let type = desc[kIOPSTypeKey] as? String, type != kIOPSInternalBatteryType {
            return info
        }
        info.isPresent = true

        if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
           let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
            info.percent = Int((Double(cur) / Double(max) * 100).rounded())
        }
        info.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        if let state = desc[kIOPSPowerSourceStateKey] as? String {
            info.isPluggedIn = (state == kIOPSACPowerValue)
        }
        if let mins = desc[kIOPSTimeToEmptyKey] as? Int, mins > 0, !info.isCharging {
            info.timeRemainingMinutes = mins
        } else if let mins = desc[kIOPSTimeToFullChargeKey] as? Int, mins > 0, info.isCharging {
            info.timeRemainingMinutes = mins
        }

        enrichWithSmartBattery(&info)
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
        } else {
            info.condition = "Normal"
        }

        // Health = current full-charge capacity vs design capacity.
        if let design = dict["DesignCapacity"] as? Int, design > 0 {
            let nominal = (dict["AppleRawMaxCapacity"] as? Int)
                ?? (dict["MaxCapacity"] as? Int)
            if let nominal {
                info.healthPercent = Int((Double(nominal) / Double(design) * 100).rounded())
            }
        }
    }
}

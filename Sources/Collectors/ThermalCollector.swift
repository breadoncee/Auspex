//
//  ThermalCollector.swift
//  Auspex
//
//  Reads on-die temperature sensors via the PRIVATE IOHIDEventSystemClient
//  API (declared in IOHID-Bridging.h). Apple Silicon exposes no public
//  temperature API, so this is best-effort: every call is guarded and the
//  collector always reports the public ProcessInfo.thermalState as a
//  guaranteed fallback signal.
//

import Foundation

// Caches the HID client; accessed serially on the collection queue.
final class ThermalCollector: @unchecked Sendable {
    // Apple-vendor temperature sensors.
    private let kHIDPage_AppleVendor = 0xff00
    private let kHIDUsage_AppleVendor_TemperatureSensor = 0x0005

    private var client: IOHIDEventSystemClient?
    private var didAttemptInit = false

    func collect() -> ThermalSnapshot {
        var snap = ThermalSnapshot()
        snap.thermalState = ThermalLevel(ProcessInfo.processInfo.thermalState)

        let sensors = readSensors()
        snap.sensors = sensors

        // Derive a representative CPU temperature from die/CPU-named sensors.
        let cpuSensors = sensors.filter { s in
            let n = s.name.lowercased()
            return n.contains("cpu") || n.contains("soc") || n.contains("die")
                || n.contains("pmgr") || n.contains("acc")
        }
        let pool = cpuSensors.isEmpty ? sensors : cpuSensors
        if !pool.isEmpty {
            snap.cpuCelsius = pool.map(\.celsius).reduce(0, +) / Double(pool.count)
        }
        return snap
    }

    private func ensureClient() -> IOHIDEventSystemClient? {
        if let client { return client }
        if didAttemptInit { return nil }
        didAttemptInit = true

        // Create/Copy functions return +1 (Unmanaged); take ownership so ARC
        // manages the lifetime thereafter.
        guard let created = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return nil }
        let c = created.takeRetainedValue()
        let match: [String: Int] = [
            "PrimaryUsagePage": kHIDPage_AppleVendor,
            "PrimaryUsage": kHIDUsage_AppleVendor_TemperatureSensor,
        ]
        IOHIDEventSystemClientSetMatching(c, match as CFDictionary)
        client = c
        return c
    }

    private func readSensors() -> [TempSensor] {
        guard let client = ensureClient() else { return [] }
        guard let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient]
        else { return [] }

        // IOHIDEventFieldBase(type) == type << 16 (the macro isn't imported).
        let field = Int32(kIOHIDEventTypeTemperature << 16)

        var sensors: [TempSensor] = []
        sensors.reserveCapacity(services.count)

        for service in services {
            guard let nameRef = IOHIDServiceClientCopyProperty(service, "Product" as CFString),
                  let name = nameRef as? String
            else { continue }

            guard let eventRef = IOHIDServiceClientCopyEvent(
                service, Int64(kIOHIDEventTypeTemperature), 0, 0
            ) else { continue }
            let event = eventRef.takeRetainedValue()

            let temp = IOHIDEventGetFloatValue(event, field)

            // Filter obviously bogus readings.
            if temp.isFinite, temp > 0, temp < 130 {
                sensors.append(TempSensor(name: name, celsius: temp))
            }
        }
        sensors.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return sensors
    }
}

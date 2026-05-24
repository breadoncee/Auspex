//
//  Metrics.swift
//  Auspex
//
//  Plain value types describing a single point-in-time snapshot of each
//  metric. Collectors produce these; the SwiftUI views render them.
//

import Foundation

// MARK: - CPU

struct CPUSnapshot: Equatable {
    /// Overall busy fraction 0...1.
    var total: Double = 0
    /// Per-core busy fraction 0...1, ordered by logical core index.
    var perCore: [Double] = []
    /// Optional E/P labels per core (e.g. "E", "P"); empty if unknown.
    var coreKinds: [String] = []

    var totalPercent: Int { Int((total * 100).rounded()) }
}

// MARK: - Memory

struct MemorySnapshot: Equatable {
    var total: UInt64 = 0          // bytes
    var used: UInt64 = 0          // active + wired + compressed
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var app: UInt64 = 0           // active + inactive approximation
    var pressure: MemoryPressure = .normal

    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    var usedPercent: Int { Int((usedFraction * 100).rounded()) }
}

enum MemoryPressure: Int, Equatable {
    case normal = 1
    case warning = 2
    case critical = 4

    init(rawLevel: Int32) {
        switch rawLevel {
        case 2: self = .warning
        case 4: self = .critical
        default: self = .normal
        }
    }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Disk

struct DiskInfo: Identifiable, Equatable {
    var id: String { url.path }
    var url: URL
    var name: String
    var total: UInt64
    var available: UInt64
    var isRemovable: Bool
    var isInternal: Bool

    var used: UInt64 { total > available ? total - available : 0 }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    var usedPercent: Int { Int((usedFraction * 100).rounded()) }
}

// MARK: - Network

struct NetworkSnapshot: Equatable {
    /// Bytes per second.
    var downBytesPerSec: Double = 0
    var upBytesPerSec: Double = 0
    /// Cumulative totals since boot (bytes).
    var totalDown: UInt64 = 0
    var totalUp: UInt64 = 0
}

// MARK: - Battery

struct BatteryInfo: Equatable {
    var isPresent: Bool = false
    var percent: Int = 0
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var timeRemainingMinutes: Int? = nil   // nil = calculating / unknown
    var cycleCount: Int? = nil
    var healthPercent: Int? = nil          // current max capacity / design capacity
    var condition: String? = nil           // e.g. "Normal"
}

// MARK: - Thermal

struct TempSensor: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var celsius: Double
}

struct ThermalSnapshot: Equatable {
    var sensors: [TempSensor] = []
    /// Public, always-available coarse signal.
    var thermalState: ThermalLevel = .nominal
    /// Representative CPU temp derived from sensor averaging, if available.
    var cpuCelsius: Double? = nil

    var hasSensors: Bool { !sensors.isEmpty }
}

enum ThermalLevel: Int, Equatable {
    case nominal, fair, serious, critical

    init(_ s: ProcessInfo.ThermalState) {
        switch s {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }

    var label: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        }
    }
}

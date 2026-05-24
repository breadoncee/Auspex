//
//  Thresholds.swift
//  Auspex
//
//  Central place for usage-fraction -> color mapping so every gauge/bar
//  stays consistent (green = healthy, yellow = watch, red = problem).
//

import SwiftUI

enum Thresholds {
    /// Generic usage coloring for fractions 0...1 (CPU, RAM, disk).
    static func usageColor(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.70: return .green
        case ..<0.90: return .yellow
        default: return .red
        }
    }

    static func pressureColor(_ p: MemoryPressure) -> Color {
        switch p {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    static func thermalColor(_ t: ThermalLevel) -> Color {
        switch t {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }

    static func batteryColor(percent: Int, charging: Bool) -> Color {
        if charging { return .green }
        switch percent {
        case ..<15: return .red
        case ..<35: return .yellow
        default: return .green
        }
    }

    /// Temperature coloring (°C) for a generic die sensor.
    static func tempColor(_ celsius: Double) -> Color {
        switch celsius {
        case ..<65: return .green
        case ..<85: return .yellow
        default: return .red
        }
    }
}

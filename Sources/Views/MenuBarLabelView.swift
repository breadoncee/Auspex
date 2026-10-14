//
//  MenuBarLabelView.swift
//  Auspex
//
//  The content shown directly in the menu bar: the custom Auspex pulse mark
//  plus an optional inline CPU/RAM percentage. Monochrome so it adapts to
//  light/dark menu bars.
//

import SwiftUI

struct MenuBarLabelView: View {
    let monitor: SystemMonitor

    var body: some View {
        HStack(spacing: 3) {
            Image("MenuBarGlyph")
                .renderingMode(.template)
            switch monitor.menuBarMetric {
            case .cpu:
                Text(monitor.cpu.isReady ? "\(monitor.cpu.totalPercent)%" : "—").monospacedDigit()
            case .memory:
                Text(monitor.memory.isReady ? "\(monitor.memory.usedPercent)%" : "—").monospacedDigit()
            case .none:
                EmptyView()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Auspex system monitor")
        .accessibilityValue(accessibilityMetric)
    }

    private var accessibilityMetric: String {
        guard monitor.lastUpdated != nil else { return "Reading system metrics" }
        switch monitor.menuBarMetric {
        case .cpu: return monitor.cpu.isReady ? "CPU \(monitor.cpu.totalPercent) percent" : "Reading CPU usage"
        case .memory: return monitor.memory.isReady ? "Memory \(monitor.memory.usedPercent) percent" : "Reading memory usage"
        case .none: return "Open system vitals"
        }
    }
}

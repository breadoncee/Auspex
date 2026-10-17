//
//  MenuBarLabelView.swift
//  Auspex
//
//  The content shown directly in the menu bar: the custom Auspex pulse mark
//  plus an optional inline CPU/RAM percentage or temperature. Monochrome so it adapts to
//  light/dark menu bars.
//

import SwiftUI

struct MenuBarLabelView: View {
    let monitor: SystemMonitor

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: MenuBarIcon.image)
                .renderingMode(.template)
            switch monitor.menuBarMetric {
            case .cpu:
                Text(monitor.readingStatus(for: .cpu).isCurrent ? "\(monitor.cpu.totalPercent)%" : "—").monospacedDigit()
            case .memory:
                Text(monitor.readingStatus(for: .memory).isCurrent ? "\(monitor.memory.usedPercent)%" : "—").monospacedDigit()
            case .temperature:
                Text(monitor.readingStatus(for: .thermal).isCurrent ? SystemMonitor.temperatureValue(in: monitor.thermal).map { "\(Fmt.celsius($0))C" } ?? "—" : "—").monospacedDigit()
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
        case .cpu: return monitor.readingStatus(for: .cpu).isCurrent ? "CPU \(monitor.cpu.totalPercent) percent" : "CPU usage \(monitor.readingStatus(for: .cpu).label.lowercased())"
        case .memory: return monitor.readingStatus(for: .memory).isCurrent ? "Memory \(monitor.memory.usedPercent) percent" : "Memory usage \(monitor.readingStatus(for: .memory).label.lowercased())"
        case .temperature:
            if monitor.readingStatus(for: .thermal).isCurrent, let temperature = SystemMonitor.temperatureValue(in: monitor.thermal) {
                return "\(monitor.thermal.cpuCelsius == nil ? "Hottest sensor" : "CPU and SoC temperature") \(Int(temperature.rounded())) degrees Celsius"
            }
            return "Temperature \(monitor.readingStatus(for: .thermal).label.lowercased())"
        case .none: return "Open system vitals"
        }
    }
}

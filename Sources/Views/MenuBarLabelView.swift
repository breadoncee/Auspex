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
                Text("\(monitor.cpu.totalPercent)%").monospacedDigit()
            case .memory:
                Text("\(monitor.memory.usedPercent)%").monospacedDigit()
            case .none:
                EmptyView()
            }
        }
    }
}

//
//  CPUCoreGrid.swift
//  Auspex
//
//  Per-core vertical bars with a glowing gradient fill, labeled E/P.
//

import SwiftUI

struct CPUCoreGrid: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let perCore: [Double]
    let coreKinds: [String]

    private let columns = [GridItem(.adaptive(minimum: 20, maximum: 34), spacing: 5)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(Array(perCore.enumerated()), id: \.offset) { idx, load in
                VStack(spacing: 3) {
                    coreBar(load)
                    Text(label(idx))
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Core \(idx + 1)")
                .accessibilityValue("\(Int((load * 100).rounded())) percent used")
            }
        }
    }

    private func label(_ idx: Int) -> String {
        return "\(idx + 1)"
    }

    private func coreBar(_ load: Double) -> some View {
        let c = Thresholds.usageColor(load)
        return GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [c.opacity(0.65), c],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .frame(height: max(3, min(1, load) * geo.size.height))
            }
        }
        .frame(height: 30)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: load)
    }
}

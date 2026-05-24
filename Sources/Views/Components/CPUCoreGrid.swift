//
//  CPUCoreGrid.swift
//  Auspex
//
//  Per-core vertical bars with a glowing gradient fill, labeled E/P.
//

import SwiftUI

struct CPUCoreGrid: View {
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
            }
        }
    }

    private func label(_ idx: Int) -> String {
        if idx < coreKinds.count { return "\(coreKinds[idx])\(idx)" }
        return "\(idx)"
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
                    .shadow(color: c.opacity(0.5), radius: 2)
            }
        }
        .frame(height: 30)
        .animation(.easeOut(duration: 0.25), value: load)
    }
}

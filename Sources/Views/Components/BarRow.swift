//
//  BarRow.swift
//  Auspex
//
//  A labeled capacity bar: "Name ........ detail" over a glowing gradient bar.
//  Used for disk volumes and the battery level.
//

import SwiftUI

struct BarRow: View {
    let title: String
    let detail: String
    let fraction: Double
    var subtitle: String? = nil
    var color: Color? = nil

    private var barColor: Color { color ?? Thresholds.usageColor(fraction) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
                Spacer(minLength: 8)
                Text(detail)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            CapacityBar(fraction: fraction, color: barColor)
        }
    }
}

/// Rounded track + glowing gradient fill, animated.
struct CapacityBar: View {
    let fraction: Double
    var color: Color = .accentColor
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.75), color],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth(geo.size.width))
                    .shadow(color: color.opacity(0.5), radius: 3)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.3), value: fraction)
    }

    private func fillWidth(_ total: CGFloat) -> CGFloat {
        let f = max(0, min(1, fraction))
        guard f > 0 else { return 0 }
        return max(height, f * total)   // keep at least a rounded dot when tiny
    }
}

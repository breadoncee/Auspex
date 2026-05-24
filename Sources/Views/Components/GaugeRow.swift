//
//  GaugeRow.swift
//  Auspex
//
//  A circular ring gauge with a glowing gradient track and a center value,
//  plus a caption column. Used for the CPU and RAM headline numbers.
//

import SwiftUI

struct RingGauge: View {
    let fraction: Double
    let centerText: String
    var color: Color? = nil
    var size: CGFloat = 66
    var lineWidth: CGFloat = 8

    private var ringColor: Color { color ?? Thresholds.usageColor(fraction) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.65), ringColor],
                        center: .center, startAngle: .degrees(0), endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.55), radius: 5)
                .animation(.easeOut(duration: 0.35), value: fraction)
            Text(centerText)
                .font(.system(size: size * 0.27, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: centerText)
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
    }
}

/// Ring + caption + optional secondary line, as a compact column.
struct GaugeColumn: View {
    let fraction: Double
    let centerText: String
    let caption: String
    var secondary: String? = nil
    var color: Color? = nil

    var body: some View {
        VStack(spacing: 5) {
            RingGauge(fraction: fraction, centerText: centerText, color: color)
            Text(caption)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            if let secondary {
                Text(secondary)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }
}

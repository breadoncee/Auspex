//
//  Sparkline.swift
//  Auspex
//
//  A tiny trend chart: a smooth-ish line with a soft gradient area fill.
//  Used for CPU load and network throughput history.
//

import SwiftUI

struct Sparkline: View {
    let values: [Double]
    var color: Color
    /// If set, the chart is scaled to this maximum (e.g. 1.0 for a 0–100%
    /// CPU line). If nil, it auto-scales to the window's own peak.
    var fixedMax: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pts = points(in: CGSize(width: w, height: h))

            ZStack {
                if pts.count >= 2 {
                    // Area fill
                    area(pts, height: h)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.35), color.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    // Line
                    line(pts)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: color.opacity(0.5), radius: 2)
                } else {
                    // Not enough samples yet — a faint baseline.
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let maxV = max(fixedMax ?? (values.max() ?? 1), 0.0001)
        let n = values.count
        let stepX = n > 1 ? size.width / CGFloat(n - 1) : size.width
        return values.enumerated().map { i, v in
            let norm = min(1, max(0, v / maxV))
            return CGPoint(x: CGFloat(i) * stepX,
                           y: size.height - CGFloat(norm) * size.height)
        }
    }

    private func line(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.move(to: pts[0])
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }

    private func area(_ pts: [CGPoint], height: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: pts[0].x, y: height))
        for pt in pts { p.addLine(to: pt) }
        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: height))
        p.closeSubpath()
        return p
    }
}

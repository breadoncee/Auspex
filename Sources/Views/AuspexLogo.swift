//
//  AuspexLogo.swift
//  Auspex
//
//  The Auspex "pulse" mark, drawn as a vector so it stays crisp at any size
//  and adopts the current foreground color (template-style) in the menu bar.
//  Mirrors the heartbeat element of the app icon.
//

import SwiftUI

struct AuspexMark: View {
    /// Stroke thickness as a fraction of the smaller dimension.
    var weight: CGFloat = 0.13

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let lw = max(1.2, min(w, h) * weight)

            // EKG-style pulse: flat, spike down/up, settle, flat.
            let pts: [(CGFloat, CGFloat)] = [
                (0.03, 0.52), (0.28, 0.52), (0.40, 0.80),
                (0.53, 0.16), (0.65, 0.64), (0.73, 0.52), (0.97, 0.52),
            ]
            var path = Path()
            path.move(to: CGPoint(x: pts[0].0 * w, y: pts[0].1 * h))
            for p in pts.dropFirst() {
                path.addLine(to: CGPoint(x: p.0 * w, y: p.1 * h))
            }
            ctx.stroke(
                path,
                with: .foreground,
                style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

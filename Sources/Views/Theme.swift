//
//  Theme.swift
//  Auspex
//
//  Shared visual language for the glassy/vibrant look: a per-metric accent
//  palette (identity color of each card) and a Liquid Glass card modifier.
//  Note: accent colors give each section its identity; health is still shown
//  with the green/yellow/red threshold colors on the rings, bars and values.
//

import SwiftUI

enum Palette {
    static let cpu = Color(red: 0.35, green: 0.78, blue: 0.98)      // sky
    static let memory = Color(red: 0.69, green: 0.55, blue: 0.99)   // violet
    static let disk = Color(red: 0.42, green: 0.63, blue: 0.99)     // blue
    static let network = Color(red: 0.27, green: 0.85, blue: 0.71)  // teal
    static let battery = Color(red: 0.43, green: 0.86, blue: 0.49)  // green
    static let thermal = Color(red: 0.99, green: 0.64, blue: 0.36)  // amber
}

/// A frosted Liquid Glass card with a faint accent tint, hairline edge, and
/// soft drop shadow for depth.
struct GlassCard: ViewModifier {
    var tint: Color
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(tint.opacity(0.14)),
                         in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.22), radius: 9, x: 0, y: 4)
    }
}

extension View {
    func glassCard(tint: Color = .clear, cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassCard(tint: tint, cornerRadius: cornerRadius))
    }
}

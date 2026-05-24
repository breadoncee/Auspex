//
//  MetricSection.swift
//  Auspex
//
//  A titled Liquid Glass card with an accent-tinted icon chip and an optional
//  trailing accessory. Gives every metric block a consistent, premium frame.
//

import SwiftUI

struct MetricSection<Content: View, Accessory: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    init(
        _ title: String,
        systemImage: String,
        tint: Color = .secondary,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(
                        tint.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                accessory()
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: tint)
    }
}

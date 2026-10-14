import SwiftUI

enum Palette {
    static let cpu = Color.blue
    static let memory = Color.purple
    static let disk = Color.indigo
    static let network = Color.teal
    static let battery = Color.green
    static let thermal = Color.orange
}

/// Data stays on a stable, readable surface. Native buttons provide the
/// system's glass treatment for the controls above it.
struct GlassCard: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    var tint: Color
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.primary.opacity(contrast == .increased ? 0.35 : 0.08), lineWidth: 1)
            }
    }
}

extension View {
    func glassCard(tint: Color = .clear, cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(tint: tint, cornerRadius: cornerRadius))
    }
}

import AppKit

/// Resolve the native image before passing it to MenuBarExtra. SwiftUI's
/// named-image lookup can miss loose PNGs in Command Line Tools builds.
@MainActor
enum MenuBarIcon {
    static let image = load(in: .main)

    static func load(in bundle: Bundle) -> NSImage {
        let image = (bundle.image(forResource: "MenuBarGlyph")?.copy() as? NSImage)
            ?? fallback()
        image.size = NSSize(width: 18, height: 15)
        image.isTemplate = true
        image.accessibilityDescription = "Auspex"
        return image
    }

    private static func fallback() -> NSImage {
        NSImage(size: NSSize(width: 18, height: 15), flipped: true) { rect in
            let points: [(CGFloat, CGFloat)] = [
                (0.03, 0.52), (0.28, 0.52), (0.40, 0.80),
                (0.53, 0.16), (0.65, 0.64), (0.73, 0.52), (0.97, 0.52),
            ]
            let path = NSBezierPath()
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            for (index, point) in points.enumerated() {
                let position = NSPoint(x: point.0 * rect.width, y: point.1 * rect.height)
                if index == 0 { path.move(to: position) }
                else { path.line(to: position) }
            }
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
    }
}

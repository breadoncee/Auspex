import AppKit
import SwiftUI

/// MenuBarExtra can keep its native host appearance after a SwiftUI preference
/// changes. Apply the choice to both the content and its owning native window.
private struct WindowAppearanceModifier: ViewModifier {
    let selection: AppAppearance
    @Environment(\.colorScheme) private var inheritedScheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, selection.colorScheme ?? inheritedScheme)
            .background(WindowAppearanceBridge(selection: selection))
    }
}

private struct WindowAppearanceBridge: NSViewRepresentable {
    let selection: AppAppearance

    func makeNSView(context: Context) -> AppearanceView {
        AppearanceView(selection: selection)
    }

    func updateNSView(_ view: AppearanceView, context: Context) {
        view.selection = selection
        view.applyAppearance()
    }

    final class AppearanceView: NSView {
        var selection: AppAppearance

        init(selection: AppAppearance) {
            self.selection = selection
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyAppearance()
        }

        func applyAppearance() {
            let name: NSAppearance.Name?
            switch selection {
            case .system: name = nil
            case .light: name = .aqua
            case .dark: name = .darkAqua
            }
            if appearance?.name != name { appearance = name.flatMap(NSAppearance.init(named:)) }
            if let window, window.appearance?.name != name {
                window.appearance = name.flatMap(NSAppearance.init(named:))
            }
        }
    }
}

extension View {
    func appWindowAppearance(_ selection: AppAppearance) -> some View {
        modifier(WindowAppearanceModifier(selection: selection))
    }
}

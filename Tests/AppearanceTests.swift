import AppKit
import SwiftUI

enum AppearanceTests {
    @MainActor
    static func run(monitor: SystemMonitor, preferences: PanelPreferences) {
        let original = NSApp.appearance
        defer { NSApp.appearance = original; monitor.appearance = .system }

        for inherited in [NSAppearance.Name.darkAqua, .aqua] {
            NSApp.appearance = NSAppearance(named: inherited)
            monitor.appearance = .system
            // Existing native hosts remain offscreen for this development test.
            let panel = NSPanel(contentRect: NSRect(x: -10_000, y: -10_000, width: 400, height: 740),
                                styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
            let settings = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 480, height: 700),
                                    styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            settings.isReleasedWhenClosed = false
            panel.appearance = NSAppearance(named: inherited)
            settings.appearance = NSAppearance(named: inherited)
            let host = NSHostingView(rootView: PanelView().environment(monitor).environment(preferences))
            let settingsHost = NSHostingView(rootView: SettingsView().environment(monitor).environment(preferences))
            panel.contentView = host
            settings.contentView = settingsHost
            defer { panel.close(); settings.close() }

            for mode in [AppAppearance.light, .dark, .light, .system] {
                monitor.appearance = mode
                host.layoutSubtreeIfNeeded()
                settingsHost.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                host.layoutSubtreeIfNeeded()
                settingsHost.layoutSubtreeIfNeeded()
                let expected: NSAppearance.Name = mode == .system ? inherited : mode == .light ? .aqua : .darkAqua
                for window in [panel as NSWindow, settings] {
                    let actual = window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
                    precondition(actual == expected,
                                 "Selected \(mode.label), but an existing window still uses \(actual?.rawValue ?? "unknown")")
                    if mode == .system {
                        precondition(window.appearance == nil, "Follow macOS must clear the explicit window override")
                    }
                }
                for view in [host as NSView, settingsHost] {
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                        preconditionFailure("Appearance test could not capture the content")
                    }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    var luminance: CGFloat = 0
                    var count: CGFloat = 0
                    for x in stride(from: 0, to: bitmap.pixelsWide, by: max(1, bitmap.pixelsWide / 16)) {
                        for y in stride(from: 0, to: bitmap.pixelsHigh, by: max(1, bitmap.pixelsHigh / 16)) {
                            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                            luminance += color.redComponent * 0.2126 + color.greenComponent * 0.7152 + color.blueComponent * 0.0722
                            count += 1
                        }
                    }
                    let average = luminance / max(1, count)
                    precondition(expected == .aqua ? average > 0.55 : average < 0.45,
                                 "Content does not match selected appearance: \(mode.label), brightness \(average)")
                }
                print("PASS: existing panel and Settings switch to \(mode.label) (system \(inherited.rawValue))")
            }
        }
    }
}

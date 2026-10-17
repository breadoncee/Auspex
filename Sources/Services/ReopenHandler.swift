import AppKit
import SwiftUI

/// Reopening a menu-only app provides a way back to settings if macOS hides its item.
@MainActor
final class ReopenHandler: NSObject, NSApplicationDelegate {
    static var settingsContent: (() -> AnyView)?
    private var settingsWindow: NSWindow?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { sender.activate(ignoringOtherApps: true); return true }
        guard let content = Self.settingsContent else { return false }
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.title = "Auspex Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        sender.activate(ignoringOtherApps: true)
        return true
    }
}

struct ReopenSettingsContent: View {
    @Environment(SystemMonitor.self) private var monitor
    var body: some View {
        SettingsView().preferredColorScheme(monitor.appearance.colorScheme)
    }
}

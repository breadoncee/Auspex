import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(PanelPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?
    @State private var requiresApproval = LaunchAtLogin.requiresApproval

    var body: some View {
        @Bindable var monitor = monitor
        Form {
            Section {
                Picker("Appearance", selection: $monitor.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Follow your Mac’s appearance, or choose Light or Dark for Auspex.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
            }

            Section {
                Picker("Menu bar reading", selection: $monitor.menuBarMetric) {
                    ForEach(MenuBarMetric.allCases) { Text($0.label).tag($0) }
                }
                Text("Show CPU, RAM or CPU / SoC temperature beside the Auspex icon, or keep just the icon.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("If the icon disappears, check that Auspex is allowed in the menu bar in System Settings. macOS can also hide items when space is limited.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Open Menu Bar Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") { NSWorkspace.shared.open(url) }
                }
            } header: {
                Label("Menu bar", systemImage: "menubar.rectangle")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Refresh interval")
                        Spacer()
                        Text("\(monitor.refreshInterval.formatted(.number.precision(.fractionLength(0...1)))) \(monitor.refreshInterval == 1 ? "second" : "seconds")")
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                    Slider(value: $monitor.refreshInterval, in: 0.5...5, step: 0.5)
                        .accessibilityLabel("Refresh interval in seconds")
                }
                Text("Faster updates use more energy. With the panel closed, only the selected menu bar reading updates, at most every 3 seconds. Low Power Mode and elevated system thermal pressure slow updates further. Icon-only mode pauses idle polling; all polling pauses during sleep.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } header: {
                Label("Refresh & energy", systemImage: "arrow.clockwise")
            }

            Section {
                Text("Show the readings you use most and move them into your preferred order. Expand a card in the panel for details and history.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ForEach(preferences.cards) { card in
                    HStack(spacing: 12) {
                        Toggle(card.title, isOn: Binding(get: { preferences.isVisible(card) }, set: { preferences.setVisible(card, visible: $0) }))
                        Spacer(minLength: 8)
                        Button { preferences.move(card, direction: -1) } label: { Image(systemName: "chevron.up") }
                            .disabled(preferences.cards.first == card)
                            .accessibilityLabel("Move \(card.title) up")
                        Button { preferences.move(card, direction: 1) } label: { Image(systemName: "chevron.down") }
                            .disabled(preferences.cards.last == card)
                            .accessibilityLabel("Move \(card.title) down")
                    }.controlSize(.small)
                }
                Text("Battery appears only on Macs with a battery. Hiding a card changes the panel layout; it does not change the collection schedule.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Restore default cards") { preferences.reset() }
            } header: {
                Label("Panel cards", systemImage: "rectangle.stack")
            }

            Section {
                Toggle("Open Auspex at login", isOn: Binding(get: { launchAtLogin }, set: { enabled in
                        do {
                            try LaunchAtLogin.setEnabled(enabled)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                        }
                        syncLoginStatus()
                    }))
                if requiresApproval {
                    Text("macOS needs your approval to open Auspex at login.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                }
                if let loginError {
                    Label(loginError, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Label("Startup", systemImage: "power")
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auspex \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1")")
                            .font(.subheadline.weight(.semibold))
                        Text("A quieter view of your Mac.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset preferences") {
                        monitor.refreshInterval = 1
                        monitor.menuBarMetric = .cpu
                        monitor.appearance = .system
                        preferences.reset()
                    }.help("Reset appearance, refresh interval, menu bar reading and panel layout to their defaults")
                }
                UpdateSettingsView()
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: min(700, max(360, (NSScreen.main?.visibleFrame.height ?? 800) - 80)))
        .navigationTitle("Auspex Settings")
        .onAppear { syncLoginStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { syncLoginStatus() }
        }
    }

    private func syncLoginStatus() {
        launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.requiresApproval
        requiresApproval = LaunchAtLogin.requiresApproval
    }
}

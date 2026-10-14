import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(SystemMonitor.self) private var monitor
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
                Text("Show a live percentage beside the Auspex icon, or keep just the icon.")
                    .font(.caption).foregroundStyle(.secondary)
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
                Text("Faster updates use more energy. When the panel is closed, only your menu bar reading updates every 3 seconds. Icon-only mode pauses polling. All polling pauses during sleep.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } header: {
                Label("Refresh & energy", systemImage: "arrow.clockwise")
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
                    }.help("Reset appearance, refresh interval and menu bar reading to their defaults")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 640)
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

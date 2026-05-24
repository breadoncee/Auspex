//
//  SettingsView.swift
//  Auspex
//
//  Preferences: refresh cadence, the inline menu-bar metric, and launch at
//  login. Bindings write straight through SystemMonitor (persisted to
//  UserDefaults) and SMAppService.
//

import SwiftUI

struct SettingsView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        @Bindable var monitor = monitor

        Form {
            Section("Updates") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Refresh interval")
                        Spacer()
                        Text(String(format: "%.1fs", monitor.refreshInterval))
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                    Slider(value: $monitor.refreshInterval, in: 0.5...5.0, step: 0.5)
                }
                Text("Polling pauses automatically while the panel is closed.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Menu bar") {
                Picker("Show inline", selection: $monitor.menuBarMetric) {
                    ForEach(MenuBarMetric.allCases) { metric in
                        Text(metric.label).tag(metric)
                    }
                }
            }

            Section("General") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLogin.set(newValue)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                if LaunchAtLogin.requiresApproval {
                    Text("Approve in System Settings → General → Login Items.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 320)
        .navigationTitle("Resource Monitor Settings")
    }
}

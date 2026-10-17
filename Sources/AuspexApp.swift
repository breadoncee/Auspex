//
//  AuspexApp.swift
//  Auspex
//
//  Menu-bar-only system monitor. LSUIElement (set in Info.plist) keeps it out
//  of the Dock. MenuBarExtra(.window) hosts the rich live panel; the panel's
//  appearance/disappearance drives the monitor's active/idle polling.
//

import SwiftUI

@main
struct AuspexApp: App {
    @NSApplicationDelegateAdaptor(ReopenHandler.self) private var reopenHandler
    @State private var monitor: SystemMonitor
    @State private var panelPreferences: PanelPreferences

    init() {
        let monitor = SystemMonitor()
        let preferences = PanelPreferences()
        _monitor = State(initialValue: monitor)
        _panelPreferences = State(initialValue: preferences)
        ReopenHandler.settingsContent = {
            AnyView(ReopenSettingsContent().environment(monitor).environment(preferences))
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(monitor)
                .environment(panelPreferences)
                .onAppear { monitor.startActive() }
                .onDisappear { monitor.goIdle() }
        } label: {
            MenuBarLabelView(monitor: monitor)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(monitor)
                .environment(panelPreferences)
        }
    }
}

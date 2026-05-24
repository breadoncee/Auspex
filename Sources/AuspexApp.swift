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
    @State private var monitor = SystemMonitor()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(monitor)
                .onAppear { monitor.startActive() }
                .onDisappear { monitor.goIdle() }
        } label: {
            MenuBarLabelView(monitor: monitor)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(monitor)
        }
    }
}

//
//  LaunchAtLogin.swift
//  Auspex
//
//  Thin wrapper over SMAppService.mainApp (macOS 13+) for the
//  "Open at Login" toggle. Reads live status rather than persisting a bool.
//

import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Returns true on success. On failure (e.g. requires approval) the
    /// caller should reflect the live `isEnabled` value.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("LaunchAtLogin toggle failed: \(error.localizedDescription)")
            return false
        }
    }
}

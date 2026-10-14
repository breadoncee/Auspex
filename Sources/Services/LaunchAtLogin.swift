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
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled && SMAppService.mainApp.status != .requiresApproval {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }
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
            try setEnabled(enabled)
            return true
        } catch {
            NSLog("LaunchAtLogin toggle failed: \(error.localizedDescription)")
            return false
        }
    }
}

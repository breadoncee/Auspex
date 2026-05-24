//
//  Formatters.swift
//  Auspex
//
//  Small, allocation-light helpers for humanizing byte counts and rates.
//

import Foundation

enum Fmt {
    // Reused formatter; accessed only from the main actor (views). The
    // unsafe annotation opts out of Swift 6's Sendable check for this global.
    nonisolated(unsafe) private static let byteFmt: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file        // base-1000, matches Finder
        f.allowedUnits = [.useGB, .useMB, .useKB, .useTB]
        f.zeroPadsFractionDigits = false
        return f
    }()

    /// "12.3 GB"
    static func bytes(_ value: UInt64) -> String {
        byteFmt.string(fromByteCount: Int64(value))
    }

    /// "1.2 MB/s" — compact rate for the network row.
    static func rate(_ bytesPerSec: Double) -> String {
        let v = max(0, bytesPerSec)
        switch v {
        case ..<1024:
            return String(format: "%.0f B/s", v)
        case ..<(1024 * 1024):
            return String(format: "%.1f KB/s", v / 1024)
        case ..<(1024 * 1024 * 1024):
            return String(format: "%.1f MB/s", v / (1024 * 1024))
        default:
            return String(format: "%.2f GB/s", v / (1024 * 1024 * 1024))
        }
    }

    /// "1h 23m" or "45m"
    static func minutes(_ mins: Int) -> String {
        if mins <= 0 { return "—" }
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    static func celsius(_ c: Double) -> String {
        String(format: "%.0f°", c)
    }
}

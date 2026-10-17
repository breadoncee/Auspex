import Foundation

enum MetricKind: String, CaseIterable, Hashable {
    case cpu, memory, storage, network, battery, thermal
}

/// A failed attempt never renews a last-good value's timestamp.
struct ReadingStatus: Equatable {
    private(set) var lastAttempt: Date?
    private(set) var lastSuccess: Date?
    private(set) var latestAttemptSucceeded = false
    private(set) var isWarmingUp = false
    var expectedInterval: TimeInterval = 1
    var now = Date()
    var isPaused = false

    var hasValue: Bool { lastSuccess != nil }
    var isCurrent: Bool {
        guard !isPaused, latestAttemptSucceeded, let lastSuccess else { return false }
        let age = now.timeIntervalSince(lastSuccess)
        return age >= 0 && age <= max(expectedInterval * 3, expectedInterval + 2)
    }
    var label: String {
        if isCurrent { return "Current" }
        if hasValue { return "Stale" }
        return lastAttempt == nil || isWarmingUp ? "Reading…" : "Unavailable"
    }

    mutating func recordBaseline(at date: Date) {
        lastAttempt = date
        latestAttemptSucceeded = false
        isWarmingUp = true
        now = date
    }

    mutating func record(success: Bool, at date: Date) {
        isWarmingUp = false
        lastAttempt = date
        latestAttemptSucceeded = success
        if success { lastSuccess = date }
        now = date
    }
}

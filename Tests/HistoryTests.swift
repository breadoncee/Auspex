import Foundation

/// Deterministic history/freshness tests, called by the shared regression entry point.
enum HistoryTests {
    @MainActor
    static func run() {
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
        }
        let start = Date(timeIntervalSinceReferenceDate: 10_000)
        var history = MetricHistory()
        for index in 0...1_000 { history.append(Double(index), at: start.addingTimeInterval(Double(index) * 0.5)) }
        let end = start.addingTimeInterval(500)
        expect(history.points.count == 601, "Five minutes at the fastest cadence must stay bounded")
        expect(history.visible(in: .minute, now: end).count == 121, "A minute is real elapsed time, independent of sample count")
        expect(history.visible(in: .fiveMinutes, now: end).first?.timestamp == end.addingTimeInterval(-300), "Retention must preserve exactly the requested elapsed window")
        history.markGap()
        history.append(1_001, at: end.addingTimeInterval(5))
        expect(history.segments(in: .minute, now: end.addingTimeInterval(5)).count == 2, "Reopening must produce a visible gap rather than joining old and new samples")
        let count = history.points.count
        history.append(.nan, at: end.addingTimeInterval(6))
        history.append(9, at: end.addingTimeInterval(-1))
        expect(history.points.count == count, "Non-finite or backwards samples must not corrupt history")
        expect(history.visible(in: .minute, now: end.addingTimeInterval(100)).isEmpty, "A paused chart cannot stretch old samples to fill its time axis")
        var down = MetricHistory(), up = MetricHistory()
        down.append(100, at: end); up.append(10, at: end)
        expect(max(down.maximum(in: .minute, now: end), up.maximum(in: .minute, now: end)) == 100,
               "Comparable network charts must support a shared visible maximum")

        var reading = ReadingStatus()
        reading.expectedInterval = 10
        reading.now = start
        expect(!reading.hasValue && reading.label == "Reading…", "Unattempted readings must not imply zero")
        reading.recordBaseline(at: start)
        expect(reading.label == "Reading…" && !reading.isCurrent, "A baseline establishes timing without presenting a measured zero")
        reading.record(success: true, at: start)
        reading.now = start.addingTimeInterval(20)
        expect(reading.isCurrent, "Storage remains current within its own slower cadence")
        reading.now = start.addingTimeInterval(31)
        expect(!reading.isCurrent && reading.label == "Stale", "Expired values must become stale")
        reading.record(success: false, at: start.addingTimeInterval(32))
        expect(reading.lastSuccess == start && reading.label == "Stale", "Failure preserves the dated last-good reading without renewing it")
        reading.record(success: true, at: start.addingTimeInterval(40))
        reading.isPaused = true
        expect(!reading.isCurrent, "Sleep must never expose a live reading")
        var unavailable = ReadingStatus()
        unavailable.record(success: false, at: start)
        expect(!unavailable.hasValue && unavailable.label == "Unavailable", "A failed first attempt must remain unavailable")
        expect(SystemMonitor.effectiveInterval(requested: 0.5, lowPower: true, thermal: .nominal) == 2,
               "Low Power Mode reduces optional collection frequency")
        expect(SystemMonitor.effectiveInterval(requested: 1, lowPower: false, thermal: .critical) == 5,
               "Critical thermals reduce optional collection frequency")
        expect(SystemMonitor.effectiveInterval(requested: 5, lowPower: true, thermal: .serious) == 5,
               "Energy policy must not speed up a user's slower cadence")
        expect(SystemMonitor.pressureHistoryValue(.unknown) == nil && SystemMonitor.pressureHistoryValue(.critical) == 1,
               "Unknown pressure must be a gap rather than healthy zero")
        #if DEBUG
        let suite = "com.local.auspex.history-fixture.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        func fixture(pressure: MemoryPressure, swap: UInt64?, stale: Bool = false) -> SystemMonitor {
            SystemMonitor.fixture(defaults: defaults,
                memory: MemorySnapshot(isReady: true, total: 16_000, used: 12_000, swapUsed: swap, pressure: pressure),
                disks: [], thermal: ThermalSnapshot(cpuCelsius: 50),
                cpu: CPUSnapshot(isReady: true, total: 0.4, perCore: [0.4]),
                network: NetworkSnapshot(isReady: true, isAvailable: true, interfaceCount: 1),
                battery: BatteryInfo(isAvailable: true), stale: stale)
        }
        let current = fixture(pressure: .normal, swap: 0)
        expect(current.panelStatus == "Live", "A complete healthy snapshot should be live, including zero swap")
        expect(fixture(pressure: .unknown, swap: 0).panelStatus != "Live", "Missing pressure must not be hidden by healthy RAM")
        expect(fixture(pressure: .normal, swap: nil).panelStatus != "Live", "Missing swap must not appear completely live")
        let stale = fixture(pressure: .warning, swap: 100, stale: true)
        expect(stale.memory.pressure == .warning && !stale.memoryPressureStatus().isCurrent,
               "Retained pressure must have its own stale state")
        expect(stale.panelStatus == "Stale" && stale.readingStatus(for: .storage).hasValue,
               "Stale fixtures preserve dated values without pretending collection succeeded")
        current.refreshNow()
        expect(!current.isCollecting, "Snapshot fixtures never launch collectors")
        #endif
        print("PASS: timestamped history, retention, gaps, shared scales, per-metric freshness and energy policy")
    }
}

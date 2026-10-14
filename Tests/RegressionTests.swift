import Foundation

@main
struct RegressionTests {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }

    @MainActor
    static func main() async {
        var network = NetworkAccumulator()
        let large: UInt64 = 5_000_000_000
        let first = network.sample(["en0": .init(down: large, up: large)], at: 10)
        expect(first.totalDown == 0 && first.downBytesPerSec == 0, "First counters establish a baseline, not session totals")
        let second = network.sample(["en0": .init(down: large + 200, up: large + 40)], at: 12)
        expect(second.downBytesPerSec == 100 && second.upBytesPerSec == 20, "64-bit counters must retain rates after 4 GB")
        let added = network.sample(["en0": .init(down: large + 400, up: large + 80), "en1": .init(down: large, up: large)], at: 14)
        expect(added.downBytesPerSec == 100 && added.totalDown == 400, "A newly attached interface must not spike traffic")
        let removed = network.sample(["en0": .init(down: large + 600, up: large + 120)], at: 16)
        expect(removed.downBytesPerSec == 100, "Removing an interface must not hide traffic on the remaining interface")
        let reset = network.sample(["en0": .init(down: 10, up: 20)], at: 18)
        expect(reset.downBytesPerSec == 0 && reset.upBytesPerSec == 0, "Reset counters must not produce an underflow spike")
        network.resetBaseline()
        let wake = network.sample(["en0": .init(down: large, up: large)], at: 100)
        expect(wake.downBytesPerSec == 0 && wake.totalDown == 600, "Wake must rebaseline rates and preserve accumulated traffic")
        let repeated = network.sample(["en0": .init(down: large + 100, up: large)], at: 100)
        expect(repeated.downBytesPerSec == 0, "Zero elapsed time must never produce non-finite rates")
        print("PASS: network counter rollover, interface churn, reset, wake and elapsed time")

        let memory = MemoryCollector().collect()
        expect(memory.total > 0 && memory.used > 0, "Memory collector must return live readings")
        expect(memory.used == memory.app + memory.wired + memory.compressed, "Memory components must add up to Memory Used")
        expect(memory.used <= memory.total, "Resident memory must not exceed physical memory")
        print("PASS: live memory accounting")

        let cpu = CPUCollector()
        let baseline = cpu.collect()
        expect(!baseline.isReady, "An initial CPU baseline must not be presented as a real zero-percent reading")
        try? await Task.sleep(for: .milliseconds(150))
        let load = cpu.collect()
        expect(load.isReady, "CPU rate must be ready after two samples")
        expect(load.perCore.count == ProcessInfo.processInfo.processorCount, "CPU core count must match the system")
        expect(load.total.isFinite && (0...1).contains(load.total), "CPU load must stay in range")
        expect(load.perCore.allSatisfy { $0.isFinite && (0...1).contains($0) }, "Per-core load must stay in range")
        print("PASS: live CPU readings")

        let thermal = ThermalCollector().collect()
        if ProcessInfo.processInfo.arguments.contains("--require-temperatures") {
            expect(thermal.hasSensors && thermal.cpuCelsius != nil, "Live temperature sensors and the CPU/SoC reading must be available on this Mac")
        }
        expect(Set(thermal.sensors.map(\.id)).count == thermal.sensors.count, "Repeated sensor names must still have unique SwiftUI identities")
        expect(thermal.sensors.allSatisfy { $0.celsius.isFinite && $0.celsius > 0 && $0.celsius < 130 }, "Temperature readings must be plausible")
        print("PASS: thermal identities and fallback (\(thermal.sensors.count) sensors, CPU/SoC \(thermal.cpuCelsius.map { String(format: "%.1f°C", $0) } ?? "unavailable"))")
        let battery = BatteryCollector().collect()
        expect(BatteryCollector.healthPercent(from: ["BatteryData": ["DesignCapacity": 6249, "NominalChargeCapacity": 5261]]) == 84,
               "Nested macOS battery capacity data must restore health readings")
        expect(BatteryCollector.healthPercent(from: ["DesignCapacity": 6249, "MaxCapacity": 100]) == nil,
               "A percentage capacity must never be treated as a charge capacity")
        expect((0...100).contains(battery.percent), "Battery percentage must be bounded")
        expect(battery.healthPercent.map { (0...100).contains($0) } ?? true, "Battery health must be bounded")
        print("PASS: battery bounds and nested health data (\(battery.healthPercent.map { "\($0)%" } ?? "unavailable"))")
        let disks = DiskCollector().collect()
        expect(disks.allSatisfy { $0.available <= $0.total && $0.used + $0.available == $0.total }, "Disk capacity arithmetic must be consistent")
        if ProcessInfo.processInfo.arguments.contains("--require-volumes") {
            expect(!disks.isEmpty, "Mounted volumes must be visible outside the sandbox")
        }
        print("PASS: storage accounting (\(disks.count) volumes)")

        expect(SystemMonitor.validInterval(.nan) == 1, "Invalid intervals must fall back safely")
        expect(SystemMonitor.validInterval(.infinity) == 1, "Infinite intervals must fall back safely")
        expect(SystemMonitor.validInterval(0) == 0.5 && SystemMonitor.validInterval(100) == 5, "Cadence must be bounded")
        let suite = "com.local.auspex.regression.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("none", forKey: "menuBarMetric")
        let monitor = SystemMonitor(defaults: defaults)
        monitor.startActive()
        expect(monitor.isActive, "Opening the panel enables active mode")
        monitor.goIdle()
        expect(!monitor.isActive, "Closing the panel enables idle mode")
        monitor.suspend()
        let before = monitor.lastUpdated
        for _ in 0..<100 { monitor.refreshNow() }
        try? await Task.sleep(for: .milliseconds(200))
        expect(monitor.isSleeping && monitor.lastUpdated == before, "Refresh requests must not publish during sleep")
        monitor.resume()
        expect(!monitor.isSleeping, "Wake resumes the monitor")
        for _ in 0..<100 { monitor.refreshNow() }
        for _ in 0..<100 {
            if monitor.lastUpdated != nil && !monitor.isCollecting { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        expect(monitor.lastUpdated != nil && !monitor.isCollecting, "Refresh bursts must coalesce and finish without a backlog")
        monitor.suspend()
        print("PASS: monitor cadence, panel lifecycle, sleep/wake and refresh bursts")
        print("All regression checks passed.")
    }
}

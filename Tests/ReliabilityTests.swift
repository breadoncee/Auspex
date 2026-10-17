import Foundation
import IOKit.ps

enum ReliabilityTests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    static func run() {
        expect(MemorySnapshot().pressure == .unknown, "Initial pressure is unknown")
        expect(MemoryPressure(rawLevel: 0) == .unknown, "Unavailable pressure is not normal")
        expect(MemoryPressure(rawLevel: 3) == .unknown, "Unrecognized pressure is not normal")
        expect(MemoryPressure(rawLevel: 1) == .normal, "Level 1 is normal")
        expect(MemoryPressure(rawLevel: 2) == .warning, "Level 2 is warning")
        expect(MemoryPressure(rawLevel: 4) == .critical, "Level 4 is critical")

        expect(DiskCollector.availableBytes(total: 100, important: nil, basic: nil) == nil,
               "Failed capacity queries are unknown")
        expect(DiskCollector.availableBytes(total: 100, important: 0, basic: 80) == 0,
               "A real zero free-space reading must not fall back")
        expect(DiskCollector.availableBytes(total: 100, important: -1, basic: 80) == 80,
               "A negative capacity is unavailable and may use the basic fallback")
        expect(DiskCollector.availableBytes(total: 100, important: 200, basic: nil) == 100,
               "Available capacity must not exceed total capacity")
        expect(DiskCollector.availableBytes(total: 0, important: 0, basic: 0) == nil,
               "Unknown total capacity must not become a full disk")

        let writable = DiskInfo(url: URL(fileURLWithPath: "/"), name: "Writable", total: 100,
                                available: 0, isRemovable: false, isInternal: true)
        expect(writable.used == 100 && writable.usedFraction == 1 && writable.usedPercent == 100,
               "A writable full volume must retain a real 100-percent reading")
        expect(writable.shouldWarnAboutCapacity, "A full writable local volume must warn")
        var image = writable
        image.url = URL(fileURLWithPath: "/Volumes/Installer")
        image.isReadOnly = true
        expect(!image.shouldWarnAboutCapacity && image.classificationLabel == "Read-only volume",
               "A full read-only image must be identified without a disk-full warning")
        var networkVolume = writable
        networkVolume.isLocal = false
        expect(!networkVolume.shouldWarnAboutCapacity && networkVolume.classificationLabel == "Network volume",
               "Remote storage must be classified separately from writable local storage")
        var unknown = writable
        unknown.available = nil
        expect(unknown.used == nil && unknown.usedFraction == nil && unknown.usedPercent == nil,
               "Missing capacity must remain unknown through derived readings")
        expect(!unknown.shouldWarnAboutCapacity, "Unknown space must not trigger a full-disk warning")
        expect([image, writable].sorted(by: DiskCollector.orderedBefore).first?.id == writable.id,
               "Writable internal storage should precede read-only images")

        var accumulator = NetworkAccumulator()
        let baseline = accumulator.sample(["en0": .init(down: 100, up: 100)], at: 10)
        expect(baseline.isAvailable && !baseline.isReady, "A baseline is available but not a valid rate")
        let idle = accumulator.sample(["en0": .init(down: 100, up: 100)], at: 11)
        expect(idle.isAvailable && idle.isReady && idle.downBytesPerSec == 0,
               "A valid idle rate is distinguishable from an unavailable reading")
        _ = accumulator.sample(["en0": .init(down: 200, up: 100)], at: 12)
        let failure = accumulator.unavailableSnapshot()
        expect(!failure.isAvailable && !failure.isReady && failure.totalDown == 100,
               "A failed query preserves session totals but marks rates unavailable")
        let recovery = accumulator.sample(["en0": .init(down: 1000, up: 1000)], at: 13)
        expect(recovery.isAvailable && !recovery.isReady && recovery.totalDown == 100,
               "Recovery must rebaseline without counting traffic across a failed query")

        expect(!BatteryCollector.snapshot(from: nil).isAvailable, "A failed battery query is unavailable")
        let desktop = BatteryCollector.snapshot(from: [])
        expect(desktop.isAvailable && !desktop.isPresent, "No internal battery after a valid query is a desktop")
        let emptyBattery: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType,
                                         kIOPSCurrentCapacityKey: 0, kIOPSMaxCapacityKey: 100]
        let battery = BatteryCollector.snapshot(from: [emptyBattery])
        expect(battery.isAvailable && battery.isPresent && battery.percent == 0,
               "A real empty battery is distinct from a query failure")
        let malformed = BatteryCollector.snapshot(from: [[kIOPSTypeKey: kIOPSInternalBatteryType]])
        expect(malformed.isPresent && !malformed.isAvailable, "Missing battery capacity must not become zero percent")
        print("PASS: pressure mapping, storage failures/classification, network availability, battery absent/unavailable/zero")
    }
}

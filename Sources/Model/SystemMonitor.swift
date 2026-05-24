//
//  SystemMonitor.swift
//  Auspex
//
//  The single @Observable model the whole UI reads from. Owns ONE timer and
//  orchestrates every collector. Designed to be resource-frugal:
//   - Fast tick only while the panel is open (active); paused when closed.
//   - Slow-changing metrics (disk, battery) run every Nth tick.
//   - Collection happens off the main actor; results are published back.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class SystemMonitor {

    // MARK: Published snapshots (views observe these)
    private(set) var cpu = CPUSnapshot()
    private(set) var memory = MemorySnapshot()
    private(set) var disks: [DiskInfo] = []
    private(set) var network = NetworkSnapshot()
    private(set) var battery = BatteryInfo()
    private(set) var thermal = ThermalSnapshot()
    private(set) var isActive = false

    // MARK: Rolling history for sparklines (most recent last)
    private(set) var cpuHistory: [Double] = []          // load fraction 0...1
    private(set) var netDownHistory: [Double] = []      // bytes/sec
    private(set) var netUpHistory: [Double] = []        // bytes/sec
    private let maxHistory = 40

    // MARK: User settings (persisted)
    var refreshInterval: Double {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            if isActive { startActive() }   // restart timer with new cadence
        }
    }
    var menuBarMetric: MenuBarMetric {
        didSet {
            UserDefaults.standard.set(menuBarMetric.rawValue, forKey: "menuBarMetric")
            if !isActive { goIdle() }   // re-evaluate idle polling for the new choice
        }
    }

    // MARK: Collectors
    private let diskCollector = DiskCollector()
    private let memoryCollector = MemoryCollector()
    private let cpuCollector = CPUCollector()
    private let networkCollector = NetworkCollector()
    private let batteryCollector = BatteryCollector()
    private let thermalCollector = ThermalCollector()

    // MARK: Timing
    private var timer: Timer?
    private var tickCount = 0
    private let diskEveryNTicks = 10      // disk changes slowly
    private let batteryEveryNTicks = 5
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    // Serialize off-main collection so the runs never overlap.
    private let workQueue = DispatchQueue(label: "com.local.auspex.collect",
                                          qos: .utility)

    init() {
        let savedInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        self.refreshInterval = savedInterval >= 0.5 ? savedInterval : 1.0
        let savedMetric = UserDefaults.standard.string(forKey: "menuBarMetric")
            .flatMap(MenuBarMetric.init(rawValue:))
        self.menuBarMetric = savedMetric ?? .cpu

        installMemoryPressureSource()
        // Seed an immediate sample, then begin slow idle polling so the menu
        // bar stat stays current before the panel is ever opened.
        Task { await self.tick(forceAll: true) }
        goIdle()
    }

    // MARK: Lifecycle driven by the panel

    func startActive() {
        isActive = true
        timer?.invalidate()
        let t = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.tick() }
        }
        t.tolerance = refreshInterval * 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
        Task { await tick(forceAll: true) }   // refresh instantly on open
    }

    func goIdle() {
        isActive = false
        timer?.invalidate()
        timer = nil

        // Keep the menu bar number alive with an infrequent tick (cheap), but
        // pause entirely if nothing is shown inline.
        guard menuBarMetric != .none else { return }
        let t = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.tick() }
        }
        t.tolerance = 1.0
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: One sampling pass

    private func tick(forceAll: Bool = false) async {
        tickCount &+= 1
        let doDisk = forceAll || tickCount % diskEveryNTicks == 1
        let doBattery = forceAll || tickCount % batteryEveryNTicks == 1

        // Capture collectors locally; run the blocking syscalls off-main.
        let cpuC = cpuCollector
        let memC = memoryCollector
        let netC = networkCollector
        let thermC = thermalCollector
        let diskC = diskCollector
        let batC = batteryCollector

        let result = await withCheckedContinuation { (cont: CheckedContinuation<Sample, Never>) in
            workQueue.async {
                var s = Sample()
                s.cpu = cpuC.collect()
                s.memory = memC.collect()
                s.network = netC.collect()
                s.thermal = thermC.collect()
                if doDisk { s.disks = diskC.collect() }
                if doBattery { s.battery = batC.collect() }
                cont.resume(returning: s)
            }
        }

        // Publish on the main actor.
        cpu = result.cpu
        memory = result.memory
        network = result.network
        thermal = result.thermal
        if let d = result.disks { disks = d }
        if let b = result.battery { battery = b }

        append(&cpuHistory, result.cpu.total)
        append(&netDownHistory, result.network.downBytesPerSec)
        append(&netUpHistory, result.network.upBytesPerSec)
    }

    private func append(_ buffer: inout [Double], _ value: Double) {
        buffer.append(value)
        if buffer.count > maxHistory { buffer.removeFirst(buffer.count - maxHistory) }
    }

    // MARK: Instant memory-pressure reaction

    private func installMemoryPressureSource() {
        let src = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let event = src.data
            let level: MemoryPressure
            if event.contains(.critical) { level = .critical }
            else if event.contains(.warning) { level = .warning }
            else { level = .normal }
            // Patch just the pressure field for an instant UI response.
            var m = self.memory
            m.pressure = level
            self.memory = m
        }
        src.resume()
        memoryPressureSource = src
    }

    private struct Sample {
        var cpu = CPUSnapshot()
        var memory = MemorySnapshot()
        var network = NetworkSnapshot()
        var thermal = ThermalSnapshot()
        var disks: [DiskInfo]? = nil
        var battery: BatteryInfo? = nil
    }
}

// MARK: - Menu bar inline metric choice

enum MenuBarMetric: String, CaseIterable, Identifiable {
    case cpu, memory, none
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cpu: return "CPU %"
        case .memory: return "RAM %"
        case .none: return "Icon only"
        }
    }
}

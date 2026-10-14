import Foundation
import Observation
import AppKit
import Combine

@MainActor
@Observable
final class SystemMonitor {
    private(set) var cpu = CPUSnapshot()
    private(set) var memory = MemorySnapshot()
    private(set) var disks: [DiskInfo] = []
    private(set) var network = NetworkSnapshot()
    private(set) var battery = BatteryInfo()
    private(set) var thermal = ThermalSnapshot()
    private(set) var isActive = false
    private(set) var isSleeping = false
    private(set) var isCollecting = false
    private(set) var lastUpdated: Date?
    private(set) var cpuHistory: [Double] = []
    private(set) var netDownHistory: [Double] = []
    private(set) var netUpHistory: [Double] = []
    private let maxHistory = 40
    private let defaults: UserDefaults

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }

    var refreshInterval: Double {
        didSet {
            let clamped = Self.validInterval(refreshInterval)
            if clamped != refreshInterval { refreshInterval = clamped }
            defaults.set(refreshInterval, forKey: "refreshInterval")
            configureTimer()
        }
    }
    var menuBarMetric: MenuBarMetric {
        didSet {
            defaults.set(menuBarMetric.rawValue, forKey: "menuBarMetric")
            configureTimer()
            if !isActive && !isSleeping && menuBarMetric != .none {
                Task { await tick() }
            }
        }
    }

    private let diskCollector = DiskCollector()
    private let memoryCollector = MemoryCollector()
    private let cpuCollector = CPUCollector()
    private let networkCollector = NetworkCollector()
    private let batteryCollector = BatteryCollector()
    private let thermalCollector = ThermalCollector()
    private let workQueue = DispatchQueue(label: "com.local.auspex.collect", qos: .utility)
    private var timer: Timer?
    private var lastDiskTime: TimeInterval = -.infinity
    private var lastBatteryTime: TimeInterval = -.infinity
    private var lastThermalTime: TimeInterval = -.infinity
    private var resetRates = true
    private var pendingFullRefresh = false
    private var generation = 0
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var workspaceSubscriptions: [AnyCancellable] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: "appearance")
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        let saved = defaults.object(forKey: "refreshInterval") as? Double ?? 1
        refreshInterval = Self.validInterval(saved)
        menuBarMetric = defaults.string(forKey: "menuBarMetric")
            .flatMap(MenuBarMetric.init(rawValue:)) ?? .cpu
        installMemoryPressureSource()
        let notifications = NSWorkspace.shared.notificationCenter
        workspaceSubscriptions = [
            notifications.publisher(for: NSWorkspace.willSleepNotification).sink { [weak self] _ in
                Task { @MainActor in self?.suspend() }
            },
            notifications.publisher(for: NSWorkspace.didWakeNotification).sink { [weak self] _ in
                Task { @MainActor in self?.resume() }
            },
            notifications.publisher(for: NSWorkspace.didMountNotification).sink { [weak self] _ in
                Task { @MainActor in self?.refreshNow() }
            },
            notifications.publisher(for: NSWorkspace.didUnmountNotification).sink { [weak self] _ in
                Task { @MainActor in self?.refreshNow() }
            }
        ]
        configureTimer()
        Task { await tick(forceAll: true) }
    }

    static func validInterval(_ value: Double) -> Double {
        value.isFinite ? min(5, max(0.5, value)) : 1
    }

    func startActive() {
        guard !isActive else { return }
        isActive = true
        resetRates = true
        cpuHistory.removeAll()
        netDownHistory.removeAll()
        netUpHistory.removeAll()
        configureTimer()
        Task { await tick(forceAll: true) }
    }

    func goIdle() {
        guard isActive else { return }
        isActive = false
        configureTimer()
    }

    func suspend() {
        isSleeping = true
        generation &+= 1
        timer?.invalidate()
        timer = nil
        resetRates = true
    }

    func resume() {
        guard isSleeping else { return }
        isSleeping = false
        resetRates = true
        cpuHistory.removeAll()
        netDownHistory.removeAll()
        netUpHistory.removeAll()
        configureTimer()
        Task { await tick(forceAll: true) }
    }

    func refreshNow() {
        Task { await tick(forceAll: true) }
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = nil
        guard !isSleeping, isActive || menuBarMetric != .none else { return }
        let interval = isActive ? refreshInterval : 3
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.tick() }
        }
        t.tolerance = interval * 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick(forceAll: Bool = false) async {
        guard !isSleeping else { return }
        // A serial queue alone does not bound the backlog. At most one
        // sample may be in flight; coalesce explicit refresh requests.
        guard !isCollecting else {
            pendingFullRefresh = pendingFullRefresh || forceAll
            return
        }
        isCollecting = true
        defer {
            isCollecting = false
            if pendingFullRefresh && !isSleeping {
                pendingFullRefresh = false
                Task { await tick(forceAll: true) }
            }
        }
        let sampleGeneration = generation
        let now = ProcessInfo.processInfo.systemUptime
        let full = isActive || forceAll
        let doDisk = full && (forceAll || now - lastDiskTime >= 10)
        let doBattery = full && (forceAll || now - lastBatteryTime >= 5)
        let doThermal = full && (forceAll || now - lastThermalTime >= 3)
        let doCPU = full || menuBarMetric == .cpu
        let doMemory = full || menuBarMetric == .memory
        let shouldReset = resetRates
        resetRates = false
        let cpuC = cpuCollector, netC = networkCollector, thermC = thermalCollector
        let memC = memoryCollector, diskC = diskCollector, batC = batteryCollector

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Sample, Never>) in
            workQueue.async {
                if shouldReset {
                    cpuC.resetBaseline()
                    netC.resetBaseline()
                }
                var sample = Sample()
                if doCPU { sample.cpu = cpuC.collect() }
                if doMemory { sample.memory = memC.collect() }
                if full { sample.network = netC.collect() }
                if doThermal { sample.thermal = thermC.collect() }
                if doDisk { sample.disks = diskC.collect() }
                if doBattery { sample.battery = batC.collect() }
                continuation.resume(returning: sample)
            }
        }
        guard !isSleeping, generation == sampleGeneration else { return }
        if let value = result.cpu { cpu = value }
        if let value = result.memory { memory = value }
        if let value = result.network { network = value }
        if let value = result.thermal { thermal = value; lastThermalTime = now }
        if let value = result.disks { disks = value; lastDiskTime = now }
        if let value = result.battery { battery = value; lastBatteryTime = now }
        lastUpdated = Date()
        if isActive && !shouldReset {
            if let value = result.cpu { append(&cpuHistory, value.total) }
            if let value = result.network {
                append(&netDownHistory, value.downBytesPerSec)
                append(&netUpHistory, value.upBytesPerSec)
            }
        }
    }

    private func append(_ buffer: inout [Double], _ value: Double) {
        buffer.append(value)
        if buffer.count > maxHistory { buffer.removeFirst(buffer.count - maxHistory) }
    }

    private func installMemoryPressureSource() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self, let source = self.memoryPressureSource else { return }
            let event = source.data
            self.memory.pressure = event.contains(.critical) ? .critical : event.contains(.warning) ? .warning : .normal
        }
        source.resume()
        memoryPressureSource = source
    }

    private struct Sample: Sendable {
        var cpu: CPUSnapshot?
        var memory: MemorySnapshot?
        var network: NetworkSnapshot?
        var thermal: ThermalSnapshot?
        var disks: [DiskInfo]?
        var battery: BatteryInfo?
    }
}

enum MenuBarMetric: String, CaseIterable, Identifiable {
    case none, cpu, memory
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Icon only"
        case .cpu: return "CPU usage"
        case .memory: return "Memory usage"
        }
    }
}

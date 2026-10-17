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
    private(set) var cpuTrend = MetricHistory()
    private(set) var netDownTrend = MetricHistory()
    private(set) var netUpTrend = MetricHistory()
    private(set) var temperatureTrend = MetricHistory()
    private(set) var swapTrend = MetricHistory()
    private(set) var memoryPressureTrend = MetricHistory()
    private(set) var isEnergySaving = false
    private var systemThermalState = ProcessInfo.processInfo.thermalState
    private var statuses: [MetricKind: ReadingStatus] = [:]
    private var pressureEventVersion = 0
    private var pressureStatus = ReadingStatus()
    private let maxHistory = 40
    private let defaults: UserDefaults
    private let monitoringEnabled: Bool

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
            if !isActive && oldValue != menuBarMetric { resetRates = true }
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

    var effectiveRefreshInterval: Double {
        Self.effectiveInterval(requested: refreshInterval, lowPower: isEnergySaving,
                               thermal: systemThermalState)
    }

    var samplingDescription: String {
        let interval = String(format: "%g", effectiveRefreshInterval)
        return "Every \(interval)s" + (isEnergySaving || systemThermalState == .serious || systemThermalState == .critical
            ? " · Reduced activity" : "")
    }

    static func effectiveInterval(requested: Double, lowPower: Bool, thermal: ProcessInfo.ThermalState) -> Double {
        let interval = validInterval(requested)
        if thermal == .critical { return max(interval, 5) }
        if lowPower || thermal == .serious { return max(interval, 2) }
        return interval
    }

    func readingStatus(for kind: MetricKind, now: Date = Date()) -> ReadingStatus {
        var status = statuses[kind] ?? ReadingStatus()
        status.now = now
        status.isPaused = isSleeping
        let base = isActive ? effectiveRefreshInterval : max(3, effectiveRefreshInterval)
        let saving = isEnergySaving || systemThermalState == .serious || systemThermalState == .critical
        switch kind {
        case .storage: status.expectedInterval = max(base, saving ? 20 : 10)
        case .battery: status.expectedInterval = max(base, saving ? 10 : 5)
        case .thermal: status.expectedInterval = max(base, saving ? 6 : 3)
        default: status.expectedInterval = base
        }
        return status
    }

    func memoryPressureStatus(now: Date = Date()) -> ReadingStatus {
        var status = pressureStatus
        status.now = now
        status.isPaused = isSleeping
        status.expectedInterval = readingStatus(for: .memory, now: now).expectedInterval
        return status
    }

    var panelStatus: String {
        if isSleeping { return "Paused" }
        if isCollecting { return "Updating" }
        let readings = MetricKind.allCases.map { readingStatus(for: $0) } + [memoryPressureStatus()]
        if readings.allSatisfy(\.isCurrent), memory.swapUsed != nil { return "Live" }
        if readings.contains(where: { $0.hasValue && !$0.isCurrent }) { return "Stale" }
        if readings.contains(where: { $0.lastAttempt != nil && !$0.hasValue }) { return "Some readings unavailable" }
        if memory.isReady, memory.swapUsed == nil { return "Some readings unavailable" }
        return "Starting"
    }

    private func record(_ kind: MetricKind, success: Bool, at date: Date, baseline: Bool = false) {
        // A delayed timer or stalled collection also creates a real history gap.
        let previous = readingStatus(for: kind, now: date)
        if previous.hasValue && !previous.isCurrent {
            switch kind {
            case .cpu: cpuTrend.markGap()
            case .memory: swapTrend.markGap(); memoryPressureTrend.markGap()
            case .network: netDownTrend.markGap(); netUpTrend.markGap()
            case .thermal: temperatureTrend.markGap()
            default: break
            }
        }
        var status = statuses[kind] ?? ReadingStatus()
        if baseline { status.recordBaseline(at: date) }
        else { status.record(success: success, at: date) }
        statuses[kind] = status
    }

    private func markHistoryGap() {
        cpuTrend.markGap(); netDownTrend.markGap(); netUpTrend.markGap()
        temperatureTrend.markGap(); swapTrend.markGap(); memoryPressureTrend.markGap()
    }

    init(defaults: UserDefaults = .standard, startMonitoring: Bool = true) {
        self.defaults = defaults
        monitoringEnabled = startMonitoring
        appearance = defaults.string(forKey: "appearance")
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        let saved = defaults.object(forKey: "refreshInterval") as? Double ?? 1
        refreshInterval = Self.validInterval(saved)
        menuBarMetric = defaults.string(forKey: "menuBarMetric")
            .flatMap(MenuBarMetric.init(rawValue:)) ?? .cpu
        isEnergySaving = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard startMonitoring else { return }
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
        let processNotifications = NotificationCenter.default
        workspaceSubscriptions += [
            processNotifications.publisher(for: .NSProcessInfoPowerStateDidChange).sink { [weak self] _ in
                Task { @MainActor in self?.updateEnergyPolicy() }
            },
            processNotifications.publisher(for: ProcessInfo.thermalStateDidChangeNotification).sink { [weak self] _ in
                Task { @MainActor in self?.updateEnergyPolicy() }
            }
        ]
        configureTimer()
        Task { await tick(forceAll: true) }
    }

    #if DEBUG
    /// Snapshot-only fixture: no timers, sources, notifications or collector work.
    static func fixture(defaults: UserDefaults, memory: MemorySnapshot, disks: [DiskInfo],
                        thermal: ThermalSnapshot, cpu: CPUSnapshot = CPUSnapshot(),
                        network: NetworkSnapshot = NetworkSnapshot(), battery: BatteryInfo = BatteryInfo(),
                        stale: Bool = false) -> SystemMonitor {
        let monitor = SystemMonitor(defaults: defaults, startMonitoring: false)
        monitor.memory = memory; monitor.disks = disks; monitor.thermal = thermal
        monitor.cpu = cpu; monitor.network = network; monitor.battery = battery
        monitor.isActive = true
        let now = Date()
        let date = stale ? now.addingTimeInterval(-30) : now
        monitor.lastUpdated = date
        for kind in MetricKind.allCases {
            let success: Bool
            switch kind {
            case .cpu: success = cpu.isReady
            case .memory: success = memory.isReady
            case .storage: success = true
            case .network: success = network.isAvailable && network.isReady
            case .battery: success = battery.isAvailable
            case .thermal: success = temperatureValue(in: thermal) != nil
            }
            monitor.record(kind, success: success, at: date)
            if stale { monitor.record(kind, success: false, at: now) }
        }
        monitor.pressureStatus.record(success: memory.pressure != .unknown, at: date)
        if stale { monitor.pressureStatus.record(success: false, at: now) }
        for index in 0...30 {
            let timestamp = date.addingTimeInterval(Double(index - 30) * 2)
            if cpu.isReady { monitor.cpuTrend.append(cpu.total, at: timestamp) }
            if network.isReady {
                monitor.netDownTrend.append(network.downBytesPerSec, at: timestamp)
                monitor.netUpTrend.append(network.upBytesPerSec, at: timestamp)
            }
            if let value = temperatureValue(in: thermal) { monitor.temperatureTrend.append(value, at: timestamp) }
            if let swap = memory.swapUsed { monitor.swapTrend.append(Double(swap), at: timestamp) }
            if let pressure = pressureHistoryValue(memory.pressure) { monitor.memoryPressureTrend.append(pressure, at: timestamp) }
        }
        return monitor
    }
    #endif

    private func updateEnergyPolicy() {
        isEnergySaving = ProcessInfo.processInfo.isLowPowerModeEnabled
        systemThermalState = ProcessInfo.processInfo.thermalState
        configureTimer()
    }

    static func validInterval(_ value: Double) -> Double {
        value.isFinite ? min(5, max(0.5, value)) : 1
    }

    func startActive() {
        guard !isActive else { return }
        isActive = true
        resetRates = true
        markHistoryGap()
        configureTimer()
        Task { await tick(forceAll: true) }
    }

    func goIdle() {
        guard isActive else { return }
        isActive = false
        markHistoryGap()
        configureTimer()
    }

    func suspend() {
        isSleeping = true
        markHistoryGap()
        generation &+= 1
        timer?.invalidate()
        timer = nil
        resetRates = true
    }

    func resume() {
        guard isSleeping else { return }
        isSleeping = false
        resetRates = true
        markHistoryGap()
        configureTimer()
        Task { await tick(forceAll: true) }
    }

    func refreshNow() {
        Task { await tick(forceAll: true) }
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = nil
        guard monitoringEnabled, !isSleeping, isActive || menuBarMetric != .none else { return }
        let interval = isActive ? effectiveRefreshInterval : max(3, effectiveRefreshInterval)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.tick() }
        }
        t.tolerance = interval * 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick(forceAll: Bool = false) async {
        guard monitoringEnabled, !isSleeping else { return }
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
        let saving = isEnergySaving || systemThermalState == .serious || systemThermalState == .critical
        let doDisk = full && (forceAll || now - lastDiskTime >= (saving ? 20 : 10))
        let doBattery = full && (forceAll || now - lastBatteryTime >= (saving ? 10 : 5))
        let doThermal = (full || menuBarMetric == .temperature) && (forceAll || now - lastThermalTime >= (saving ? 6 : 3))
        let doCPU = full || menuBarMetric == .cpu
        let doMemory = full || menuBarMetric == .memory
        let pressureVersion = pressureEventVersion
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
                if doDisk { sample.disks = diskC.collectReading() }
                if doBattery { sample.battery = batC.collect() }
                continuation.resume(returning: sample)
            }
        }
        guard !isSleeping, generation == sampleGeneration else { return }
        let date = Date()
        if doCPU {
            let success = result.cpu?.isReady == true
            record(.cpu, success: success, at: date, baseline: !success && !(result.cpu?.perCore.isEmpty ?? true))
            if success, let value = result.cpu { cpu = value }
            else { cpuTrend.markGap() }
        }
        if doMemory {
            let success = result.memory?.isReady == true
            record(.memory, success: success, at: date)
            if pressureVersion == pressureEventVersion {
                pressureStatus.record(success: result.memory?.pressure != .unknown && success, at: date)
            }
            if success, var value = result.memory {
                // A newer dispatch event wins over a sample already in flight.
                // A failed pressure query never fabricates a return to normal.
                if value.pressure == .unknown || pressureVersion != pressureEventVersion {
                    value.pressure = memory.pressure
                }
                memory = value
            } else { swapTrend.markGap(); memoryPressureTrend.markGap() }
        }
        if full {
            let success = result.network?.isAvailable == true && result.network?.isReady == true
            record(.network, success: success, at: date, baseline: !success && result.network?.isAvailable == true)
            if success, let value = result.network { network = value }
            else { netDownTrend.markGap(); netUpTrend.markGap() }
        }
        if doThermal {
            lastThermalTime = now
            let success = result.thermal.map { Self.temperatureValue(in: $0) != nil } ?? false
            record(.thermal, success: success, at: date)
            if let value = result.thermal {
                if success { thermal = value }
                else { thermal.thermalState = value.thermalState; temperatureTrend.markGap() }
            }
        }
        if doDisk {
            lastDiskTime = now
            record(.storage, success: result.disks != nil, at: date)
            if let value = result.disks { disks = value }
        }
        if doBattery {
            lastBatteryTime = now
            let success = result.battery?.isAvailable == true
            record(.battery, success: success, at: date)
            if success, let value = result.battery { battery = value }
        }
        // Compatibility timestamp means an attempt completed, not that all values are current.
        lastUpdated = date
        if isActive {
            if let value = result.cpu, value.isReady, !shouldReset {
                append(&cpuHistory, value.total)
                cpuTrend.append(value.total, at: date)
            }
            if let value = result.network, value.isAvailable, value.isReady, !shouldReset {
                append(&netDownHistory, value.downBytesPerSec)
                append(&netUpHistory, value.upBytesPerSec)
                netDownTrend.append(value.downBytesPerSec, at: date)
                netUpTrend.append(value.upBytesPerSec, at: date)
            }
            if let snapshot = result.thermal, let value = Self.temperatureValue(in: snapshot) {
                temperatureTrend.append(value, at: date)
            }
            if let value = result.memory, value.isReady {
                if let swap = value.swapUsed { swapTrend.append(Double(swap), at: date) }
                else { swapTrend.markGap() }
                if memoryPressureStatus(now: date).isCurrent, let pressure = Self.pressureHistoryValue(memory.pressure) {
                    memoryPressureTrend.append(pressure, at: date)
                } else { memoryPressureTrend.markGap() }
            }
        }
    }

    static func temperatureValue(in snapshot: ThermalSnapshot) -> Double? {
        snapshot.cpuCelsius ?? snapshot.sensors.map(\.celsius).max()
    }

    static func pressureHistoryValue(_ pressure: MemoryPressure) -> Double? {
        switch pressure {
        case .normal: return 0
        case .warning: return 0.5
        case .critical: return 1
        case .unknown: return nil
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
            guard !event.intersection([.normal, .warning, .critical]).isEmpty else { return }
            self.pressureStatus.record(success: true, at: Date())
            self.pressureEventVersion &+= 1
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
    case none, cpu, memory, temperature
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Icon only"
        case .cpu: return "CPU usage"
        case .memory: return "Memory usage"
        case .temperature: return "Temperature"
        }
    }
}

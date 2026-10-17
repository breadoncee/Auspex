// Development-only collection benchmark. No windows, status items or user UI.
import AppKit
import Darwin
import Foundation
import Observation

private enum BenchmarkMode: String {
    case icon, cpu, memory, temperature
    case panel = "open"

    var menuMetric: MenuBarMetric {
        switch self {
        case .icon: return .none
        case .cpu, .panel: return .cpu
        case .memory: return .memory
        case .temperature: return .temperature
        }
    }
}

private struct Options {
    var mode: BenchmarkMode = .cpu
    var duration: TimeInterval = 60
    var interval: Double = 1

    init(arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            guard index + 1 < arguments.count else { throw UsageError.invalidArguments }
            let value = arguments[index + 1]
            switch flag {
            case "--mode":
                guard let mode = BenchmarkMode(rawValue: value) else { throw UsageError.invalidArguments }
                self.mode = mode
            case "--duration":
                guard let duration = Double(value), duration.isFinite, duration > 0, duration <= 86_400
                else { throw UsageError.invalidArguments }
                self.duration = duration
            case "--interval":
                guard let interval = Double(value), interval.isFinite, (0.5...5).contains(interval)
                else { throw UsageError.invalidArguments }
                self.interval = interval
            default: throw UsageError.invalidArguments
            }
            index += 2
        }
    }

    enum UsageError: Error { case invalidArguments }
    static let usage = "Usage: Tools/benchmark.sh [--mode icon|cpu|memory|temperature|open] [--duration seconds] [--interval 0.5...5]\nDefaults: cpu, 60 seconds, 1-second requested panel cadence."
}

private struct ProcessUsage {
    let userSeconds: Double
    let systemSeconds: Double
    let peakResidentBytes: Int64

    init?() {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        userSeconds = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
        systemSeconds = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        // Darwin reports ru_maxrss in bytes, unlike Linux's KiB convention.
        peakResidentBytes = Int64(usage.ru_maxrss)
    }
}

@MainActor
private final class Measurement {
    let options: Options
    let suiteName = "com.local.auspex.benchmark.\(UUID().uuidString)"
    let defaults: UserDefaults
    let startTime: TimeInterval
    let startUsage: ProcessUsage
    let monitor: SystemMonitor
    private var attempts: [MetricKind: Int] = [:]
    private var successes: [MetricKind: Int] = [:]
    private var previousAttempt: [MetricKind: Date] = [:]
    private var previousSuccess: [MetricKind: Date] = [:]
    private var completedSamples = 0
    private var deadline: Timer?

    init(options: Options) {
        self.options = options
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(options.mode.menuMetric.rawValue, forKey: "menuBarMetric")
        defaults.set(options.interval, forKey: "refreshInterval")
        startTime = ProcessInfo.processInfo.systemUptime
        guard let usage = ProcessUsage() else {
            defaults.removePersistentDomain(forName: suiteName)
            fatalError("getrusage failed before measurement")
        }
        startUsage = usage
        monitor = SystemMonitor(defaults: defaults)
    }

    func start() {
        observeNextSample()
        if options.mode == .panel { monitor.startActive() }
        // This deadline is the harness's only timer. Collection cadence belongs
        // to SystemMonitor; observing completed samples adds no polling timer.
        let timer = Timer(timeInterval: options.duration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish() }
        }
        RunLoop.main.add(timer, forMode: .common)
        deadline = timer
    }

    private func observeNextSample() {
        withObservationTracking {
            _ = monitor.lastUpdated
        } onChange: { [weak self] in
            // Observation notifies before mutation. Resume on the main actor
            // after the whole sample has published, then observe the next one.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recordCompletedSample()
                self.observeNextSample()
            }
        }
    }

    private func recordCompletedSample() {
        completedSamples += 1
        for kind in MetricKind.allCases {
            let status = monitor.readingStatus(for: kind)
            if let date = status.lastAttempt, previousAttempt[kind] != date {
                attempts[kind, default: 0] += 1
                previousAttempt[kind] = date
            }
            if let date = status.lastSuccess, previousSuccess[kind] != date {
                successes[kind, default: 0] += 1
                previousSuccess[kind] = date
            }
        }
    }

    private func finish() {
        let elapsed = ProcessInfo.processInfo.systemUptime - startTime
        let wasActive = monitor.isActive
        let lowPower = monitor.isEnergySaving
        let interval: Any
        if wasActive || options.mode != .icon {
            interval = wasActive ? monitor.effectiveRefreshInterval : max(3, monitor.effectiveRefreshInterval)
        } else { interval = NSNull() }
        monitor.suspend()
        defaults.removePersistentDomain(forName: suiteName)
        guard let usage = ProcessUsage() else {
            fputs("getrusage failed after measurement\n", stderr)
            exit(EXIT_FAILURE)
        }
        let user = max(0, usage.userSeconds - startUsage.userSeconds)
        let system = max(0, usage.systemSeconds - startUsage.systemSeconds)
        let report: [String: Any] = [
            "mode": options.mode.rawValue,
            "requested_duration_seconds": options.duration,
            "elapsed_monotonic_seconds": elapsed,
            "requested_panel_interval_seconds": options.interval,
            "effective_timer_interval_seconds": interval,
            "low_power_mode": lowPower,
            "thermal_state_at_end": ThermalLevel(ProcessInfo.processInfo.thermalState).label,
            "logical_processor_count": ProcessInfo.processInfo.processorCount,
            "cpu_user_seconds": user,
            "cpu_system_seconds": system,
            "cpu_percent_of_one_core": elapsed > 0 ? (user + system) / elapsed * 100 : 0,
            "peak_resident_bytes": usage.peakResidentBytes,
            "peak_resident_mib": Double(usage.peakResidentBytes) / 1_048_576,
            "completed_monitor_samples": completedSamples,
            "completed_metric_attempts": Dictionary(uniqueKeysWithValues: MetricKind.allCases.map { ($0.rawValue, attempts[$0, default: 0]) }),
            "completed_metric_successes": Dictionary(uniqueKeysWithValues: MetricKind.allCases.map { ($0.rawValue, successes[$0, default: 0]) }),
            "measurement_scope": "Collectors, monitor lifecycle and history, including startup; no SwiftUI rendering or updater. Counts are completed attempts, not OS wakeups."
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([10]))
            exit(EXIT_SUCCESS)
        } catch {
            fputs("Could not encode measurement\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}

@main
@MainActor
private struct Benchmark {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] {
            print(Options.usage)
            return
        }
        let options: Options
        do { options = try Options(arguments: arguments) }
        catch {
            fputs(Options.usage + "\n", stderr)
            exit(2)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let measurement = Measurement(options: options)
        measurement.start()
        withExtendedLifetime(measurement) { app.run() }
    }
}

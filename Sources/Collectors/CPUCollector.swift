//
//  CPUCollector.swift
//  Auspex
//
//  Per-core CPU usage by diffing PROCESSOR_CPU_LOAD_INFO tick counters
//  between samples. Holds the previous sample as state, so it's a class.
//

import Darwin
import Foundation

// Holds previous-sample state; only ever accessed serially on SystemMonitor's
// collection queue, so the unchecked Sendable conformance is sound.
final class CPUCollector: @unchecked Sendable {
    private var previous: [host_cpu_load_info]?
    private let coreKinds: [String] = CPUCollector.perfLevelKinds()

    func collect() -> CPUSnapshot {
        var snap = CPUSnapshot()
        snap.coreKinds = coreKinds

        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )
        guard kr == KERN_SUCCESS, let info else { return snap }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let states = Int(CPU_STATE_MAX)
        var current: [host_cpu_load_info] = []
        current.reserveCapacity(Int(cpuCount))

        info.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) { ptr in
            for i in 0..<Int(cpuCount) {
                let base = i * states
                var load = host_cpu_load_info()
                load.cpu_ticks.0 = UInt32(bitPattern: ptr[base + Int(CPU_STATE_USER)])
                load.cpu_ticks.1 = UInt32(bitPattern: ptr[base + Int(CPU_STATE_SYSTEM)])
                load.cpu_ticks.2 = UInt32(bitPattern: ptr[base + Int(CPU_STATE_IDLE)])
                load.cpu_ticks.3 = UInt32(bitPattern: ptr[base + Int(CPU_STATE_NICE)])
                current.append(load)
            }
        }

        var perCore: [Double] = Array(repeating: 0, count: current.count)
        if let prev = previous, prev.count == current.count {
            for i in 0..<current.count {
                let dUser = Double(current[i].cpu_ticks.0 &- prev[i].cpu_ticks.0)
                let dSys = Double(current[i].cpu_ticks.1 &- prev[i].cpu_ticks.1)
                let dIdle = Double(current[i].cpu_ticks.2 &- prev[i].cpu_ticks.2)
                let dNice = Double(current[i].cpu_ticks.3 &- prev[i].cpu_ticks.3)
                let busy = dUser + dSys + dNice
                let totalTicks = busy + dIdle
                perCore[i] = totalTicks > 0 ? min(1, max(0, busy / totalTicks)) : 0
            }
        }
        previous = current

        snap.perCore = perCore
        snap.total = perCore.isEmpty ? 0 : perCore.reduce(0, +) / Double(perCore.count)
        return snap
    }

    /// Best-effort E/P labels using hw.perflevelN.logicalcpu (Apple Silicon).
    /// perflevel0 = Performance cores, perflevel1 = Efficiency cores.
    private static func perfLevelKinds() -> [String] {
        func sysctlInt(_ name: String) -> Int? {
            var value: Int = 0
            var size = MemoryLayout<Int>.size
            return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
        }
        guard let nLevels = sysctlInt("hw.nperflevels"), nLevels > 1 else { return [] }

        var kinds: [String] = []
        for level in 0..<nLevels {
            guard let n = sysctlInt("hw.perflevel\(level).logicalcpu") else { continue }
            let label = level == 0 ? "P" : "E"
            kinds.append(contentsOf: Array(repeating: label, count: n))
        }
        return kinds
    }
}

//
//  MemoryCollector.swift
//  Auspex
//
//  Reads live VM statistics via host_statistics64 and the current memory
//  pressure level via sysctl. "Used" mirrors Activity Monitor's Memory Used
//  (App + Wired + Compressed).
//

import Darwin
import Foundation

struct MemoryCollector {
    private let total: UInt64 = ProcessInfo.processInfo.physicalMemory

    func collect() -> MemorySnapshot {
        var snap = MemorySnapshot()
        snap.total = total
        snap.pressure = MemoryPressure(rawLevel: pressureLevel())

        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return snap }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize)
        let active = UInt64(stats.active_count) * page
        let inactive = UInt64(stats.inactive_count) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page

        snap.wired = wired
        snap.compressed = compressed
        snap.app = active + inactive
        snap.used = active + wired + compressed
        return snap
    }

    /// `kern.memorystatus_vm_pressure_level`: 1 normal, 2 warn, 4 critical.
    private func pressureLevel() -> Int32 {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        return result == 0 ? level : 1
    }
}

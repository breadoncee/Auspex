//
//  MemoryCollector.swift
//  Auspex
//
//  Reads live VM statistics via host_statistics64 and the current memory
//  pressure level and disk-backed swap via sysctl. Resident memory is an
//  estimate (App + Wired + Compressed); swap is reported separately.
//

import Darwin
import Foundation

struct MemoryCollector {
    private let total: UInt64 = ProcessInfo.processInfo.physicalMemory

    func collect() -> MemorySnapshot {
        var snap = MemorySnapshot()
        snap.total = total
        snap.pressure = MemoryPressure(rawLevel: pressureLevel())
        snap.swapUsed = swapUsedBytes()

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
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS, pageSize > 0 else { return snap }
        let page = UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page

        snap.wired = wired
        snap.compressed = compressed
        // Internal pages are anonymous memory. File-backed active/inactive
        // pages are cache and can be reclaimed; they are not app memory.
        let anonymous = UInt64(stats.internal_page_count) * page
        let purgeable = UInt64(stats.purgeable_count) * page
        snap.app = anonymous > purgeable ? anonymous - purgeable : 0
        snap.used = snap.app + wired + compressed
        snap.isReady = true
        return snap
    }

    private func swapUsedBytes() -> UInt64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0,
              size == MemoryLayout<xsw_usage>.size else { return nil }
        return usage.xsu_used
    }

    /// `kern.memorystatus_vm_pressure_level`: 1 normal, 2 warn, 4 critical.
    private func pressureLevel() -> Int32 {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        return result == 0 && size == MemoryLayout<Int32>.size ? level : 0
    }
}

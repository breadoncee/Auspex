//
//  NetworkCollector.swift
//  Auspex
//
//  Throughput by diffing cumulative interface byte counters (if_data) from
//  getifaddrs over wall-clock time. Sums physical interfaces, skips loopback.
//

import Darwin
import Foundation

// Holds previous byte counters; accessed serially on the collection queue.
final class NetworkCollector: @unchecked Sendable {
    private var lastDown: UInt64 = 0
    private var lastUp: UInt64 = 0
    private var lastTime: Date?

    func collect() -> NetworkSnapshot {
        var snap = NetworkSnapshot()
        let (down, up) = readCounters()
        snap.totalDown = down
        snap.totalUp = up

        let now = Date()
        if let last = lastTime {
            let dt = now.timeIntervalSince(last)
            if dt > 0 {
                // Clamp negative deltas (counter reset / interface removed).
                let dDown = down >= lastDown ? Double(down - lastDown) : 0
                let dUp = up >= lastUp ? Double(up - lastUp) : 0
                snap.downBytesPerSec = dDown / dt
                snap.upBytesPerSec = dUp / dt
            }
        }
        lastDown = down
        lastUp = up
        lastTime = now
        return snap
    }

    private func readCounters() -> (down: UInt64, up: UInt64) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return (0, 0) }
        defer { freeifaddrs(ifaddrPtr) }

        var down: UInt64 = 0
        var up: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }

            let flags = Int32(cur.pointee.ifa_flags)
            guard (flags & IFF_UP) == IFF_UP else { continue }
            guard cur.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let name = String(cString: cur.pointee.ifa_name)
            if name == "lo0" { continue }                 // skip loopback
            if name.hasPrefix("utun") { continue }        // skip VPN tunnels (double counts)

            if let data = cur.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                down &+= UInt64(data.pointee.ifi_ibytes)
                up &+= UInt64(data.pointee.ifi_obytes)
            }
        }
        return (down, up)
    }
}

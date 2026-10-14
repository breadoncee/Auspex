import Darwin
import Foundation

struct InterfaceTraffic: Equatable {
    var down: UInt64
    var up: UInt64
}

/// Differences each interface separately so adding/removing a device or
/// resetting its counters cannot create a spike in another device's rate.
struct NetworkAccumulator {
    private var previous: [String: InterfaceTraffic] = [:]
    private var lastTime: TimeInterval?
    private var totalDown: UInt64 = 0
    private var totalUp: UInt64 = 0

    mutating func resetBaseline() {
        previous = [:]
        lastTime = nil
    }

    mutating func sample(_ counters: [String: InterfaceTraffic], at now: TimeInterval) -> NetworkSnapshot {
        var down: UInt64 = 0
        var up: UInt64 = 0
        if let lastTime, now > lastTime {
            for (name, current) in counters {
                guard let old = previous[name] else { continue }
                down += current.down >= old.down ? current.down - old.down : 0
                up += current.up >= old.up ? current.up - old.up : 0
            }
        }
        let elapsed = lastTime.map { now - $0 } ?? 0
        totalDown += down
        totalUp += up
        previous = counters
        lastTime = now
        return NetworkSnapshot(
            interfaceCount: counters.count,
            downBytesPerSec: elapsed > 0 ? Double(down) / elapsed : 0,
            upBytesPerSec: elapsed > 0 ? Double(up) / elapsed : 0,
            totalDown: totalDown, totalUp: totalUp
        )
    }
}

// All mutable state is confined to SystemMonitor's serial collection queue.
final class NetworkCollector: @unchecked Sendable {
    private var accumulator = NetworkAccumulator()

    func resetBaseline() { accumulator.resetBaseline() }

    func collect() -> NetworkSnapshot {
        guard let counters = readCounters() else {
            resetBaseline()
            return accumulator.sample([:], at: ProcessInfo.processInfo.systemUptime)
        }
        return accumulator.sample(counters, at: ProcessInfo.processInfo.systemUptime)
    }

    private func readCounters() -> [String: InterfaceTraffic]? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }
        var counters: [String: InterfaceTraffic] = [:]
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard current.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                  (Int32(current.pointee.ifa_flags) & IFF_UP) != 0 else { continue }
            let name = String(cString: current.pointee.ifa_name)
            // Physical Wi-Fi/Ethernet; omit loopback, VPN and peer-to-peer
            // interfaces so the same packet is never counted twice.
            guard name.hasPrefix("en") else { continue }
            let index = if_nametoindex(current.pointee.ifa_name)
            guard index > 0 else { continue }
            var mib: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA,
                                Int32(index), IFDATA_GENERAL]
            var data = ifmibdata()
            var size = MemoryLayout<ifmibdata>.size
            let result = mib.withUnsafeMutableBufferPointer {
                sysctl($0.baseAddress, u_int($0.count), &data, &size, nil, 0)
            }
            guard result == 0 else { continue }
            // getifaddrs' if_data only has 32-bit byte counters. ifmibdata
            // exposes 64-bit counters, including after >4 GB of traffic.
            counters[name] = InterfaceTraffic(down: data.ifmd_data.ifi_ibytes,
                                               up: data.ifmd_data.ifi_obytes)
        }
        return counters
    }
}

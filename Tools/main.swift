//
//  montest_main.swift
//  Verification harness — exercises the real collectors and prints a snapshot
//  so values can be cross-checked against df / vm_stat / top / ioreg.
//  Not part of the app target.
//

import Foundation

let disk = DiskCollector()
let mem = MemoryCollector()
let cpu = CPUCollector()
let net = NetworkCollector()
let bat = BatteryCollector()
let therm = ThermalCollector()

// CPU and network need two samples to produce a rate; prime, wait, re-sample.
_ = cpu.collect()
_ = net.collect()
Thread.sleep(forTimeInterval: 1.0)

let c = cpu.collect()
let m = mem.collect()
let d = disk.collect()
let n = net.collect()
let b = bat.collect()
let t = therm.collect()

print("=== CPU ===")
print("total: \(c.totalPercent)%  cores: \(c.perCore.count)  kinds: \(c.coreKinds.prefix(12))")
print("perCore%: " + c.perCore.map { String(Int(($0 * 100).rounded())) }.joined(separator: " "))

print("\n=== MEMORY ===")
print("total: \(Fmt.bytes(m.total))  used: \(Fmt.bytes(m.used)) (\(m.usedPercent)%)")
print("wired: \(Fmt.bytes(m.wired))  compressed: \(Fmt.bytes(m.compressed))  app: \(Fmt.bytes(m.app))")
print("pressure: \(m.pressure.label)")

print("\n=== DISKS ===")
for vol in d {
    let kind = vol.isInternal ? "internal" : (vol.isRemovable ? "removable" : "external")
    print("\(vol.name) [\(kind)]: \(Fmt.bytes(vol.used)) used / \(Fmt.bytes(vol.total)) (\(vol.usedPercent)%), \(Fmt.bytes(vol.available)) free")
}

print("\n=== NETWORK ===")
print("down: \(Fmt.rate(n.downBytesPerSec))  up: \(Fmt.rate(n.upBytesPerSec))")
print("total down: \(Fmt.bytes(n.totalDown))  total up: \(Fmt.bytes(n.totalUp))")

print("\n=== BATTERY ===")
if b.isPresent {
    print("\(b.percent)%  charging: \(b.isCharging)  pluggedIn: \(b.isPluggedIn)")
    print("health: \(b.healthPercent.map { "\($0)%" } ?? "n/a")  cycles: \(b.cycleCount.map(String.init) ?? "n/a")  condition: \(b.condition ?? "n/a")")
    print("time remaining: \(b.timeRemainingMinutes.map { Fmt.minutes($0) } ?? "n/a")")
} else {
    print("no battery present")
}

print("\n=== THERMAL ===")
print("thermalState: \(t.thermalState.label)  cpuCelsius: \(t.cpuCelsius.map { String(format: "%.1f", $0) } ?? "n/a")")
print("sensors: \(t.sensors.count)")
for s in t.sensors.prefix(20) {
    print("  \(s.name): \(String(format: "%.1f", s.celsius))°C")
}

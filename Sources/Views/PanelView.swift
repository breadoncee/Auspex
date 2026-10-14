import SwiftUI

struct PanelView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var showCores = false
    @State private var showAllVolumes = false
    @State private var showSensors = false

    private var panelHeight: CGFloat {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        return min(740, max(360, (screen?.visibleFrame.height ?? 800) - 36))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    overview
                    thermalSection
                    networkSection
                    diskSection
                    if monitor.battery.isPresent { batterySection }
                    cpuSection
                    memorySection
                }
                .padding(16)
            }
            .scrollIndicators(.automatic)
            Divider()
            footer
        }
        .frame(width: 400, height: panelHeight)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AuspexMark(weight: 0.16)
                .foregroundStyle(Palette.cpu)
                .frame(width: 24, height: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Auspex").font(.system(size: 18, weight: .semibold))
                Text(macOSVersion)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Label(monitor.lastUpdated == nil ? "Starting" : "Live", systemImage: "circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(monitor.lastUpdated == nil ? Color.secondary : Color.green)
                Text("Every \(monitor.refreshInterval.formatted(.number.precision(.fractionLength(0...1))))s")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private var footer: some View {
        HStack(spacing: 8) {
            SettingsLink { Label("Settings", systemImage: "gearshape") }
                .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
                .keyboardShortcut(",", modifiers: .command)
                .help("Open Auspex settings")
            Button { monitor.refreshNow() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(monitor.isCollecting)
            .accessibilityLabel("Refresh all readings")
            .help("Refresh all readings now")
            Spacer()
            Button("Quit", systemImage: "power") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .controlSize(.regular)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var overview: some View {
        HStack(spacing: 12) {
            summary("CPU", symbol: "cpu", value: "\(monitor.cpu.totalPercent)%",
                    detail: "Overall load", fraction: monitor.cpu.total, tint: Palette.cpu, ready: monitor.cpu.isReady)
            summary("Memory", symbol: "memorychip", value: "\(monitor.memory.usedPercent)%",
                    detail: "\(Fmt.bytes(monitor.memory.used)) · \(monitor.memory.pressure.label)", fraction: monitor.memory.usedFraction,
                    tint: Palette.memory, ready: monitor.memory.isReady)
        }
    }

    private func summary(_ title: String, symbol: String, value: String,
                         detail: String, fraction: Double, tint: Color, ready: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.medium)).foregroundStyle(tint)
            Text(ready ? value : "—")
                .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(ready ? detail : "Reading…")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            CapacityBar(fraction: fraction, color: tint, height: 5)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).glassCard()
        .accessibilityElement(children: .combine)
    }

    private var cpuSection: some View {
        MetricSection("CPU activity", systemImage: "waveform.path", tint: Palette.cpu) {
            Text("\(monitor.cpu.perCore.count) cores").font(.caption).foregroundStyle(.secondary)
        } content: {
            Sparkline(values: monitor.cpuHistory, color: Palette.cpu, fixedMax: 1).frame(height: 30)
                .accessibilityLabel("CPU usage history")
                .accessibilityValue("Current usage \(monitor.cpu.totalPercent) percent")
            DisclosureGroup("Per-core usage", isExpanded: $showCores) {
                CPUCoreGrid(perCore: monitor.cpu.perCore, coreKinds: monitor.cpu.coreKinds)
                    .padding(.top, 8)
            }.font(.caption)
        }
    }

    private var memorySection: some View {
        let memory = monitor.memory
        return MetricSection("Memory", systemImage: "memorychip", tint: Palette.memory) {
            badge("\(memory.pressure.label) pressure", Thresholds.pressureColor(memory.pressure))
        } content: {
            HStack(spacing: 12) {
                miniStat("App", Fmt.bytes(memory.app))
                miniStat("Wired", Fmt.bytes(memory.wired))
                miniStat("Compressed", Fmt.bytes(memory.compressed))
            }
            Text("\(Fmt.bytes(memory.used)) of \(Fmt.bytes(memory.total)) · resident memory estimate")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var networkSection: some View {
        MetricSection("Network", systemImage: "network", tint: Palette.network) {
            Text("Wi-Fi / Ethernet").font(.caption).foregroundStyle(.secondary)
        } content: {
            if monitor.network.interfaceCount == 0 {
                Label("No interface readings available", systemImage: "wifi.slash")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    throughput("Download", symbol: "arrow.down", value: monitor.network.downBytesPerSec,
                               total: monitor.network.totalDown, history: monitor.netDownHistory, color: Palette.network)
                    Divider()
                    throughput("Upload", symbol: "arrow.up", value: monitor.network.upBytesPerSec,
                               total: monitor.network.totalUp, history: monitor.netUpHistory, color: Palette.cpu)
                }
                Text("Totals since Auspex opened; excludes traffic while the panel is closed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func throughput(_ title: String, symbol: String, value: Double, total: UInt64,
                            history: [Double], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(Fmt.rate(value)).font(.system(size: 18, weight: .semibold)).monospacedDigit().lineLimit(1)
            Sparkline(values: history, color: color).frame(height: 20).accessibilityHidden(true)
            Text("\(Fmt.bytes(total)) total").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }

    private var diskSection: some View {
        MetricSection("Storage", systemImage: "internaldrive", tint: Palette.disk) {
            Text("\(monitor.disks.count) volumes").font(.caption).foregroundStyle(.secondary)
        } content: {
            if monitor.disks.isEmpty {
                Label(monitor.lastUpdated == nil ? "Reading volumes…" : "No accessible volumes", systemImage: "externaldrive.badge.questionmark")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Use Refresh to try again.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(showAllVolumes ? monitor.disks : Array(monitor.disks.prefix(2))) { disk in
                    BarRow(title: disk.name, detail: "\(Fmt.bytes(disk.available)) free",
                           fraction: disk.usedFraction, subtitle: disk.isInternal ? nil : "External")
                        .help("\(disk.url.path) · \(Fmt.bytes(disk.used)) used of \(Fmt.bytes(disk.total))")
                        .accessibilityElement(children: .combine)
                        .accessibilityValue("\(disk.usedPercent) percent used")
                }
                if monitor.disks.count > 2 {
                    Button(showAllVolumes ? "Show fewer volumes" : "Show all \(monitor.disks.count) volumes") {
                        showAllVolumes.toggle()
                    }.buttonStyle(.link).font(.caption)
                }
            }
        }
    }

    private var batterySection: some View {
        let battery = monitor.battery
        let color = Thresholds.batteryColor(percent: battery.percent, charging: battery.isCharging)
        return MetricSection("Battery", systemImage: battery.isCharging ? "battery.100.bolt" : "battery.100", tint: Palette.battery) {
            badge("\(battery.percent)%", color)
        } content: {
            CapacityBar(fraction: Double(battery.percent) / 100, color: color, height: 6).accessibilityHidden(true)
            HStack {
                Text(batteryStatus(battery)).font(.subheadline)
                Spacer()
                if let cycles = battery.cycleCount { Text("\(cycles) cycles").font(.caption).foregroundStyle(.secondary) }
            }
            if let health = battery.healthPercent {
                Text("Maximum capacity \(health)%").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var thermalSection: some View {
        let thermal = monitor.thermal
        return MetricSection("Temperature", systemImage: "thermometer.medium", tint: Palette.thermal) {
            badge(thermal.thermalState.label, Thresholds.thermalColor(thermal.thermalState))
        } content: {
            if let temperature = thermal.cpuCelsius ?? thermal.sensors.map(\.celsius).max() {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Fmt.celsius(temperature))C")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(thermal.cpuCelsius == nil ? "Hottest sensor" : "CPU / SoC average")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    if thermal.cpuCelsius != nil, let hottest = thermal.sensors.max(by: { $0.celsius < $1.celsius }) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Fmt.celsius(hottest.celsius))C")
                                .font(.subheadline.weight(.semibold)).monospacedDigit()
                            Text("Hottest sensor").font(.caption).foregroundStyle(.secondary)
                        }
                        .help(hottest.name)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            if thermal.hasSensors {
                DisclosureGroup("\(thermal.sensors.count) temperature sensors", isExpanded: $showSensors) {
                    VStack(spacing: 8) {
                        ForEach(thermal.sensors) { sensor in
                            HStack {
                                Text(sensor.name).lineLimit(1).help(sensor.name)
                                Spacer()
                                Text("\(Fmt.celsius(sensor.celsius))C").monospacedDigit()
                            }.font(.caption).accessibilityElement(children: .combine)
                        }
                    }.padding(.top, 8)
                }.font(.caption)
            } else {
                Text("Temperature sensors are unavailable on this Mac. System thermal status remains available.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit().lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(.primary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func batteryStatus(_ battery: BatteryInfo) -> String {
        if battery.isCharging {
            return battery.timeRemainingMinutes.map { "\(Fmt.minutes($0)) to full" } ?? "Charging"
        }
        if battery.isPluggedIn { return battery.percent >= 100 ? "Fully charged" : "Plugged in · not charging" }
        return battery.timeRemainingMinutes.map { "\(Fmt.minutes($0)) remaining" } ?? "On battery"
    }
}

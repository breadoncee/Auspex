//
//  PanelView.swift
//  Auspex
//
//  The popover content shown when the menu bar icon is clicked. A vibrant,
//  glassy column of metric cards over a softly gradient-washed material.
//

import SwiftUI

struct PanelView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                GlassEffectContainer(spacing: 11) {
                    VStack(spacing: 11) {
                        cpuSection
                        memorySection
                        diskSection
                        networkSection
                        if monitor.battery.isPresent { batterySection }
                        thermalSection
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            }
            .scrollIndicators(.hidden)
            footer
        }
        .frame(width: 340)
        .frame(maxHeight: 660)
        .fontDesign(.rounded)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [Palette.cpu.opacity(0.12), .clear, Palette.memory.opacity(0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [.clear, Palette.thermal.opacity(0.06)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Header / footer

    private var header: some View {
        HStack(spacing: 10) {
            AuspexMark(weight: 0.16)
                .foregroundStyle(.white)
                .frame(width: 18, height: 15)
                .frame(width: 30, height: 30)
                .background(
                    LinearGradient(
                        colors: [Palette.cpu, Palette.memory],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .shadow(color: Palette.cpu.opacity(0.45), radius: 5, y: 2)
            VStack(alignment: .leading, spacing: 0) {
                Text("Auspex")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("System vitals")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            thermalPill
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 9)
    }

    private var thermalPill: some View {
        let c = Thresholds.thermalColor(monitor.thermal.thermalState)
        return HStack(spacing: 5) {
            Circle()
                .fill(c)
                .frame(width: 6, height: 6)
                .shadow(color: c.opacity(0.8), radius: 3)
            Text(monitor.thermal.thermalState.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: Capsule())
    }

    private var footer: some View {
        HStack(spacing: 8) {
            SettingsLink {
                footerLabel("Settings", "gearshape")
            }
            .buttonStyle(.plain)
            .onTapGesture { NSApp.activate(ignoringOtherApps: true) }

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                footerLabel("Quit", "power")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func footerLabel(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: Capsule())
    }

    // MARK: Sections

    private var cpuSection: some View {
        MetricSection("CPU", systemImage: "cpu", tint: Palette.cpu) {
            valueBadge("\(monitor.cpu.totalPercent)%", Thresholds.usageColor(monitor.cpu.total))
        } content: {
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 14) {
                    GaugeColumn(fraction: monitor.cpu.total,
                                centerText: "\(monitor.cpu.totalPercent)%",
                                caption: "Load")
                    if !monitor.cpu.perCore.isEmpty {
                        CPUCoreGrid(perCore: monitor.cpu.perCore,
                                    coreKinds: monitor.cpu.coreKinds)
                    }
                }
                Sparkline(values: monitor.cpuHistory, color: Palette.cpu, fixedMax: 1.0)
                    .frame(height: 26)
            }
        }
    }

    private var memorySection: some View {
        let m = monitor.memory
        return MetricSection("Memory", systemImage: "memorychip", tint: Palette.memory) {
            valueBadge(m.pressure.label, Thresholds.pressureColor(m.pressure))
        } content: {
            HStack(alignment: .center, spacing: 14) {
                GaugeColumn(fraction: m.usedFraction,
                            centerText: "\(m.usedPercent)%",
                            caption: "Used",
                            secondary: "\(Fmt.bytes(m.used)) / \(Fmt.bytes(m.total))",
                            color: Thresholds.pressureColor(m.pressure))
                VStack(alignment: .leading, spacing: 7) {
                    statLine("Wired", Fmt.bytes(m.wired))
                    statLine("Compressed", Fmt.bytes(m.compressed))
                    statLine("App", Fmt.bytes(m.app))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var diskSection: some View {
        MetricSection("Storage", systemImage: "internaldrive", tint: Palette.disk) {
            EmptyView()
        } content: {
            VStack(spacing: 11) {
                if monitor.disks.isEmpty {
                    Text("Reading volumes…")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(monitor.disks) { disk in
                    BarRow(
                        title: disk.name,
                        detail: "\(Fmt.bytes(disk.available)) free",
                        fraction: disk.usedFraction,
                        subtitle: disk.isInternal ? nil : "external"
                    )
                }
            }
        }
    }

    private var networkSection: some View {
        let n = monitor.network
        return MetricSection("Network", systemImage: "network", tint: Palette.network) {
            EmptyView()
        } content: {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    throughput(symbol: "arrow.down", color: Palette.network,
                               value: Fmt.rate(n.downBytesPerSec),
                               caption: Fmt.bytes(n.totalDown))
                    Divider().frame(height: 30).opacity(0.4)
                    throughput(symbol: "arrow.up", color: Palette.thermal,
                               value: Fmt.rate(n.upBytesPerSec),
                               caption: Fmt.bytes(n.totalUp))
                }
                .frame(maxWidth: .infinity)
                HStack(spacing: 12) {
                    Sparkline(values: monitor.netDownHistory, color: Palette.network)
                        .frame(height: 22)
                    Sparkline(values: monitor.netUpHistory, color: Palette.thermal)
                        .frame(height: 22)
                }
            }
        }
    }

    private var batterySection: some View {
        let b = monitor.battery
        let color = Thresholds.batteryColor(percent: b.percent, charging: b.isCharging)
        return MetricSection("Battery", systemImage: batterySymbol(b), tint: Palette.battery) {
            valueBadge("\(b.percent)%", color)
        } content: {
            VStack(spacing: 9) {
                CapacityBar(fraction: Double(b.percent) / 100, color: color, height: 8)
                HStack {
                    Text(batteryStatusText(b))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    if let h = b.healthPercent {
                        Text("Health \(h)%")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    if let c = b.cycleCount {
                        Text("· \(c) cycles")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var thermalSection: some View {
        let t = monitor.thermal
        return MetricSection("Temperatures", systemImage: "thermometer.medium",
                             tint: Palette.thermal) {
            if let cpu = t.cpuCelsius {
                valueBadge(Fmt.celsius(cpu), Thresholds.tempColor(cpu))
            }
        } content: {
            if t.hasSensors {
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                    ForEach(t.sensors.prefix(8)) { sensor in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Thresholds.tempColor(sensor.celsius))
                                .frame(width: 6, height: 6)
                                .shadow(color: Thresholds.tempColor(sensor.celsius).opacity(0.6),
                                        radius: 2)
                            Text(shortSensorName(sensor.name))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text(Fmt.celsius(sensor.celsius))
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                }
            } else {
                Text("Sensor readout unavailable — showing system thermal state: \(t.thermalState.label)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Small helpers

    private func valueBadge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy, value: text)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .animation(.easeInOut(duration: 0.3), value: color)
    }

    private func statLine(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).font(.system(size: 10)).foregroundStyle(.tertiary)
            Spacer(minLength: 4)
            Text(value).font(.system(size: 10, weight: .semibold))
                .monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private func throughput(symbol: String, color: Color,
                            value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol).foregroundStyle(color)
                    .font(.system(size: 11, weight: .bold))
                Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
            }
            Text("total \(caption)")
                .font(.system(size: 9)).foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func batterySymbol(_ b: BatteryInfo) -> String {
        if b.isCharging { return "battery.100.bolt" }
        switch b.percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryStatusText(_ b: BatteryInfo) -> String {
        if b.isCharging {
            if let m = b.timeRemainingMinutes { return "Charging · \(Fmt.minutes(m)) to full" }
            return "Charging"
        }
        if b.isPluggedIn { return "Plugged in" }
        if let m = b.timeRemainingMinutes { return "\(Fmt.minutes(m)) remaining" }
        return "On battery"
    }

    /// Trim verbose sensor names for the compact grid.
    private func shortSensorName(_ raw: String) -> String {
        raw.replacingOccurrences(of: " Temp Sensor", with: "")
           .replacingOccurrences(of: "Temperature", with: "Temp")
    }
}

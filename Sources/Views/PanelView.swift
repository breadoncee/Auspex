import SwiftUI

struct PanelView: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(PanelPreferences.self) private var preferences
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var expanded: Set<PanelCard> = []
    @State private var showAllVolumes = false
    @State private var showReferenceVolumes = false
    @State private var window: HistoryWindow = .minute
    @State private var activityMonitorError = false

    init(initiallyExpanded: Set<PanelCard> = [], initiallyShowReferenceVolumes: Bool = false) {
        _expanded = State(initialValue: initiallyExpanded)
        _showReferenceVolumes = State(initialValue: initiallyShowReferenceVolumes)
    }

    private var panelHeight: CGFloat {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        return min(740, max(360, (screen?.visibleFrame.height ?? 800) - 36))
    }

    private var visibleCards: [PanelCard] {
        preferences.cards.filter { preferences.isVisible($0) && ($0 != .battery || monitor.battery.isPresent) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    if visibleCards.isEmpty {
                        ContentUnavailableView("No cards shown", systemImage: "rectangle.stack", description: Text("Choose the readings you want in Settings → Panel cards."))
                    }
                    ForEach(visibleCards) { card in
                        switch card {
                        case .memory: memorySection
                        case .thermal: thermalSection
                        case .cpu: cpuSection
                        case .network: networkSection
                        case .storage: diskSection
                        case .battery: batterySection
                        }
                    }
                }.padding(16)
            }.scrollIndicators(.automatic)
            Divider()
            footer
        }
        .frame(width: 400, height: panelHeight)
        .background {
            if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
            else { Rectangle().fill(.regularMaterial) }
        }
        .alert("Activity Monitor could not open", isPresented: $activityMonitorError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Open Activity Monitor from Applications → Utilities to inspect individual processes.") }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                AuspexMark(weight: 0.16).foregroundStyle(Palette.cpu).frame(width: 24, height: 20).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auspex").font(.system(size: 18, weight: .semibold))
                    Text(macOSVersion).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Label(monitor.panelStatus, systemImage: monitor.panelStatus == "Live" ? "circle.fill" : "clock")
                        .font(.caption.weight(.medium)).foregroundStyle(monitor.panelStatus == "Live" ? Color.green : .secondary)
                    Text(monitor.samplingDescription).font(.caption).foregroundStyle(.secondary)
                }
            }
            Picker("History window", selection: $window) {
                Text("60 seconds").tag(HistoryWindow.minute)
                Text("5 minutes").tag(HistoryWindow.fiveMinutes)
            }.pickerStyle(.segmented).controlSize(.small)
                .help("Time span for expanded trend charts. Gaps indicate periods without readings.")
        }.padding(16)
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
            Button { monitor.refreshNow() } label: { Image(systemName: "arrow.clockwise") }
                .disabled(monitor.isCollecting).accessibilityLabel("Refresh all readings").help("Refresh all readings now")
            Spacer()
            Menu {
                Button("Open Activity Monitor…") { openActivityMonitor() }
                Button("Menu bar icon missing? Open Settings…") { openMenuBarSettings() }
            } label: { Image(systemName: "questionmark.circle") }
                .menuStyle(.borderlessButton).frame(width: 24).accessibilityLabel("Help and tools")
            Button("Quit", systemImage: "power") { NSApp.terminate(nil) }.keyboardShortcut("q", modifiers: .command)
        }.controlSize(.regular).padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func details<Content: View>(_ card: PanelCard, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup("Details & history", isExpanded: Binding(get: { expanded.contains(card) }, set: {
            if $0 { expanded.insert(card) } else { expanded.remove(card) }
        })) {
            VStack(alignment: .leading, spacing: 12, content: content).padding(.top, 10)
        }.font(.caption)
    }

    private func freshness(_ kind: MetricKind) -> some View {
        freshness(monitor.readingStatus(for: kind))
    }

    private func freshness(_ status: ReadingStatus, prefix: String? = nil) -> some View {
        let title = prefix.map { "\($0): \(status.label)" } ?? status.label
        return Group {
            if !status.isCurrent {
                Label(status.lastSuccess.map { "\(title) · last read \($0.formatted(date: .omitted, time: .shortened))" } ?? title, systemImage: status.hasValue ? "clock" : "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
                    .help(status.lastSuccess.map { "Last successful reading: \($0.formatted(date: .omitted, time: .standard)). Use Refresh to try again." } ?? "Use Refresh to try again.")
            }
        }
    }

    private var swapUsedText: String {
        guard let used = monitor.memory.swapUsed else { return "Unavailable" }
        return used == 0 ? "0 B" : Fmt.bytes(used)
    }

    private var memorySection: some View {
        let memory = monitor.memory
        let status = monitor.readingStatus(for: .memory)
        let pressureStatus = monitor.memoryPressureStatus()
        return MetricSection("Memory", systemImage: "memorychip", tint: Palette.memory) {
            Text(status.hasValue ? "\(memory.usedPercent)% RAM" : "RAM unavailable").font(.caption.weight(.medium)).monospacedDigit()
        } content: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pressureStatus.hasValue ? memory.pressure.label : "Unknown").font(.system(size: 26, weight: .semibold, design: .rounded))
                    Label("Memory pressure", systemImage: pressureStatus.hasValue ? "circle.fill" : "questionmark.circle")
                        .font(.caption).foregroundStyle(pressureStatus.hasValue ? Thresholds.pressureColor(memory.pressure) : .secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(swapUsedText).font(.title3.weight(.semibold)).monospacedDigit()
                    Text("Swap used on disk").font(.caption).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
                    .help("Disk space currently holding swapped-out memory. Separate from RAM usage; this is not an SSD wear reading.")
            }
            Text(status.hasValue ? "\(Fmt.bytes(memory.used)) of \(Fmt.bytes(memory.total)) RAM" : "RAM reading unavailable")
                .font(.caption).foregroundStyle(.secondary)
            freshness(.memory)
            if !pressureStatus.isCurrent { freshness(pressureStatus, prefix: "Pressure") }
            details(.memory) {
                Text("Pressure describes how well macOS can meet memory needs. High RAM or swap usage alone does not mean a problem.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    miniStat("App", status.hasValue ? Fmt.bytes(memory.app) : "—")
                    miniStat("Wired", status.hasValue ? Fmt.bytes(memory.wired) : "—")
                    miniStat("Compressed", status.hasValue ? Fmt.bytes(memory.compressed) : "—")
                }
                Text("Resident memory estimate").font(.caption).foregroundStyle(.secondary)
                Text("Memory pressure").font(.caption.weight(.medium))
                HistoryChart(history: monitor.memoryPressureTrend, window: window, color: Palette.memory, fixedMax: 1, valueLabel: { $0 >= 1 ? "Critical" : $0 >= 0.5 ? "Warning" : "Normal" }, minimumLabel: "Normal").frame(height: 62)
                Text("Swap used").font(.caption.weight(.medium))
                HistoryChart(history: monitor.swapTrend, window: window, color: Palette.memory, valueLabel: { $0 == 0 ? "0 B" : Fmt.bytes(UInt64(max(0, $0))) }).frame(height: 62)
                Button("Inspect processes in Activity Monitor…") { openActivityMonitor() }.buttonStyle(.link)
            }
        }
    }

    private var cpuSection: some View {
        let status = monitor.readingStatus(for: .cpu)
        return MetricSection("CPU", systemImage: "cpu", tint: Palette.cpu) {
            Text(status.hasValue ? "\(monitor.cpu.totalPercent)% load" : "Unavailable").font(.subheadline.weight(.semibold)).monospacedDigit()
        } content: {
            if status.hasValue { CapacityBar(fraction: monitor.cpu.total, color: Palette.cpu, height: 5).accessibilityLabel("CPU usage").accessibilityValue("\(monitor.cpu.totalPercent) percent") }
            freshness(.cpu)
            details(.cpu) {
                HistoryChart(history: monitor.cpuTrend, window: window, color: Palette.cpu, fixedMax: 1, valueLabel: { "\(Int(($0 * 100).rounded()))%" }).frame(height: 70)
                Text("\(monitor.cpu.perCore.count) logical cores").font(.caption).foregroundStyle(.secondary)
                CPUCoreGrid(perCore: monitor.cpu.perCore, coreKinds: monitor.cpu.coreKinds)
                Button("Inspect processes in Activity Monitor…") { openActivityMonitor() }.buttonStyle(.link)
            }
        }
    }

    private var thermalSection: some View {
        let thermal = monitor.thermal
        let temperature = SystemMonitor.temperatureValue(in: thermal)
        return MetricSection("Temperature", systemImage: "thermometer.medium", tint: Palette.thermal) {
            badge(thermal.thermalState.label, Thresholds.thermalColor(thermal.thermalState))
        } content: {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(temperature.map { "\(Fmt.celsius($0))C" } ?? "—").font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text(temperature == nil ? "Temperature sensors unavailable" : thermal.cpuCelsius == nil ? "Hottest sensor" : "CPU / SoC average").font(.caption).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
                Spacer()
                if thermal.cpuCelsius != nil, let hottest = thermal.sensors.max(by: { $0.celsius < $1.celsius }) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Fmt.celsius(hottest.celsius))C").font(.subheadline.weight(.semibold)).monospacedDigit()
                        Text("Hottest sensor").font(.caption).foregroundStyle(.secondary)
                    }.help(hottest.name).accessibilityElement(children: .combine)
                }
            }
            freshness(.thermal)
            details(.thermal) {
                HistoryChart(history: monitor.temperatureTrend, window: window, color: Palette.thermal, valueLabel: { "\(Fmt.celsius($0))C" }).frame(height: 70)
                if thermal.hasSensors {
                    Text("\(thermal.sensors.count) temperature sensors").font(.caption).foregroundStyle(.secondary)
                    ForEach(thermal.sensors) { sensor in
                        HStack(alignment: .firstTextBaseline) {
                            Text(sensor.name).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 10)
                            Text("\(Fmt.celsius(sensor.celsius))C").monospacedDigit()
                        }.font(.caption).accessibilityElement(children: .combine)
                    }
                } else {
                    Text("Sensor access varies by Mac and macOS version. The macOS thermal status remains available.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var networkSection: some View {
        let status = monitor.readingStatus(for: .network)
        let sharedMax = max(1, max(monitor.netDownTrend.maximum(in: window, now: Date()), monitor.netUpTrend.maximum(in: window, now: Date())))
        return MetricSection("Network", systemImage: "network", tint: Palette.network) {
            Text("Wi-Fi / Ethernet").font(.caption).foregroundStyle(.secondary)
        } content: {
            HStack(spacing: 16) {
                miniStat("↓ Download", status.hasValue ? Fmt.rate(monitor.network.downBytesPerSec) : "—")
                miniStat("↑ Upload", status.hasValue ? Fmt.rate(monitor.network.upBytesPerSec) : "—")
            }
            freshness(.network)
            details(.network) {
                Text("Download").font(.caption.weight(.medium))
                HistoryChart(history: monitor.netDownTrend, window: window, color: Palette.network, fixedMax: sharedMax, valueLabel: Fmt.rate).frame(height: 62)
                Text("Upload · same scale").font(.caption.weight(.medium))
                HistoryChart(history: monitor.netUpTrend, window: window, color: Palette.cpu, fixedMax: sharedMax, valueLabel: Fmt.rate).frame(height: 62)
                Text("Observed totals: ↓ \(Fmt.bytes(monitor.network.totalDown)) · ↑ \(Fmt.bytes(monitor.network.totalUp))").font(.caption).monospacedDigit()
                Text("Totals exclude traffic while the panel is closed or your Mac sleeps. Chart gaps show missing observations.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var diskSection: some View {
        let writable = monitor.disks.filter { $0.isLocal && !$0.isReadOnly }
        let reference = monitor.disks.filter { !$0.isLocal || $0.isReadOnly }
        return MetricSection("Storage", systemImage: "internaldrive", tint: Palette.disk) {
            Text("\(writable.count) writable").font(.caption).foregroundStyle(.secondary)
        } content: {
            if writable.isEmpty {
                Text(monitor.readingStatus(for: .storage).label == "Reading…" ? "Reading volumes…" : "No writable local volumes available").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(showAllVolumes ? writable : Array(writable.prefix(2))) { disk in diskRow(disk) }
                if writable.count > 2 {
                    Button(showAllVolumes ? "Show fewer volumes" : "Show all \(writable.count) writable volumes") { showAllVolumes.toggle() }.buttonStyle(.link).font(.caption)
                }
            }
            if !reference.isEmpty {
                DisclosureGroup("Other volumes (\(reference.count))", isExpanded: $showReferenceVolumes) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Read-only and network volumes are shown separately. Their capacity does not trigger local low-space warnings.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(reference) { disk in diskRow(disk) }
                    }.padding(.top, 8)
                }.font(.caption)
            }
            freshness(.storage)
        }
    }

    private func diskRow(_ disk: DiskInfo) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(disk.name).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(disk.available.map { "\(Fmt.bytes($0)) available" } ?? "Space unavailable").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            if let fraction = disk.usedFraction {
                CapacityBar(fraction: fraction, color: disk.shouldWarnAboutCapacity ? .red : Palette.disk, height: 5).accessibilityHidden(true)
            }
            HStack {
                Text(disk.classificationLabel)
                Spacer()
                if disk.shouldWarnAboutCapacity { Text("Low space").fontWeight(.medium) }
            }.font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine).help(disk.url.path)
    }

    private var batterySection: some View {
        let battery = monitor.battery
        let color = Thresholds.batteryColor(percent: battery.percent, charging: battery.isCharging)
        return MetricSection("Battery", systemImage: battery.isCharging ? "battery.100.bolt" : "battery.100", tint: Palette.battery) {
            badge("\(battery.percent)%", color)
        } content: {
            Text(batteryStatus(battery)).font(.subheadline)
            freshness(.battery)
            details(.battery) {
                if let cycles = battery.cycleCount { Text("\(cycles) charge cycles") }
                if let health = battery.healthPercent { Text("Maximum capacity \(health)%") }
                if let condition = battery.condition { Text("Condition: \(condition)") }
            }
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.15), in: Capsule())
    }

    private func batteryStatus(_ battery: BatteryInfo) -> String {
        if battery.isCharging { return battery.timeRemainingMinutes.map { "\(Fmt.minutes($0)) to full" } ?? "Charging" }
        if battery.isPluggedIn { return battery.percent >= 100 ? "Fully charged" : "Plugged in · not charging" }
        return battery.timeRemainingMinutes.map { "\(Fmt.minutes($0)) remaining" } ?? "On battery"
    }

    private func openActivityMonitor() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else { activityMonitorError = true; return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if error != nil { Task { @MainActor in activityMonitorError = true } }
        }
    }

    private func openMenuBarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") { NSWorkspace.shared.open(url) }
    }
}

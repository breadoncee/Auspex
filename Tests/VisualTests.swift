import AppKit
import SwiftUI

/// Offscreen development renders use fixed data and never start live collectors.
@main
struct VisualTests {
    @MainActor
    static func render<V: View>(_ view: V, size: CGSize, path: String) throws {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("No render bitmap") }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
        try png.write(to: URL(fileURLWithPath: path))
        print("Rendered \(path)")
    }

    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let suite = "com.local.auspex.visual-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PanelPreferences(defaults: defaults)
        let disks = [
            DiskInfo(url: URL(fileURLWithPath: "/"), name: "Macintosh HD", total: 500_000_000_000,
                     available: 130_000_000_000, isRemovable: false, isInternal: true),
            DiskInfo(url: URL(fileURLWithPath: "/Volumes/Installer"), name: "Installer image", total: 1_000_000_000,
                     available: 0, isRemovable: false, isInternal: false, isReadOnly: true),
            DiskInfo(url: URL(fileURLWithPath: "/Volumes/Network"), name: "A network volume with a long descriptive name",
                     total: 1_000_000_000, available: nil, isRemovable: false, isInternal: false, isLocal: false)
        ]
        let cpu = CPUSnapshot(isReady: true, total: 0.28, perCore: [0.1, 0.2, 0.6, 0.4], coreKinds: ["E", "E", "P", "P"])
        let network = NetworkSnapshot(isReady: true, isAvailable: true, interfaceCount: 1,
                                      downBytesPerSec: 2_900_000, upBytesPerSec: 132_900,
                                      totalDown: 34_000_000, totalUp: 4_000_000)
        let thermal = ThermalSnapshot(sensors: [.init(id: "cpu", name: "CPU performance cluster", celsius: 65),
                                              .init(id: "soc", name: "SoC sensor with a deliberately long descriptive label", celsius: 67)],
                                      thermalState: .nominal, cpuCelsius: 65)
        for (name, pressure, swap, stale) in [
            ("normal", MemoryPressure.normal, UInt64(0), false),
            ("refreshing", MemoryPressure.normal, UInt64(0), false),
            ("warning", MemoryPressure.warning, UInt64(5_600_000_000), false),
            ("unavailable", MemoryPressure.unknown, nil, false),
            ("stale", MemoryPressure.warning, UInt64(5_600_000_000), true)
        ] {
            let memory = MemorySnapshot(isReady: true, total: 16_000_000_000, used: 13_000_000_000,
                                        wired: 3_000_000_000, compressed: 2_000_000_000, app: 8_000_000_000,
                                        swapUsed: swap, pressure: pressure)
            let monitor = SystemMonitor.fixture(defaults: defaults, memory: memory, disks: disks,
                                                thermal: thermal, cpu: cpu, network: network,
                                                battery: BatteryInfo(isAvailable: true), stale: stale,
                                                collecting: name == "refreshing")
            for scheme in [ColorScheme.light, .dark] {
                let appearance = scheme == .light ? "light" : "dark"
                try render(PanelView().environment(monitor).environment(preferences)
                    .environment(\.colorScheme, scheme).preferredColorScheme(scheme),
                    size: CGSize(width: 400, height: 740), path: "build/verification/\(name)-\(appearance).png")
            }
            if name == "normal" {
                try render(SettingsView().environment(monitor).environment(preferences)
                    .environment(\.colorScheme, .light).preferredColorScheme(.light),
                           size: CGSize(width: 480, height: 700), path: "build/verification/settings-improved.png")
                try render(PanelView(initiallyExpanded: [.memory]).environment(monitor).environment(preferences)
                    .preferredColorScheme(.dark),
                    size: CGSize(width: 400, height: 740), path: "build/verification/history-dark.png")
            }
        }
        for appearance in ["light", "dark"] {
            let steady = try Data(contentsOf: URL(fileURLWithPath: "build/verification/normal-\(appearance).png"))
            let refreshing = try Data(contentsOf: URL(fileURLWithPath: "build/verification/refreshing-\(appearance).png"))
            precondition(steady == refreshing,
                         "Routine collection must not alter the visible panel, badge, refresh button or layout (\(appearance))")
            print("PASS: identical steady/refreshing panel in \(appearance) appearance")
        }
        for card in PanelCard.allCases { preferences.setVisible(card, visible: card == .storage) }
        var fullDisks = disks
        fullDisks[0].available = 5_000_000_000
        let storage = SystemMonitor.fixture(defaults: defaults, memory: MemorySnapshot(), disks: fullDisks,
                                             thermal: thermal, cpu: cpu, network: network,
                                             battery: BatteryInfo(isAvailable: true))
        try render(PanelView(initiallyShowReferenceVolumes: true).environment(storage).environment(preferences)
                    .environment(\.colorScheme, .light).preferredColorScheme(.light),
                   size: CGSize(width: 400, height: 740), path: "build/verification/storage-classification.png")
        storage.menuBarMetric = .temperature
        try render(MenuBarLabelView(monitor: storage).font(.system(size: 13))
                    .frame(width: 90, height: 24).environment(\.colorScheme, .dark).preferredColorScheme(.dark),
                   size: CGSize(width: 90, height: 24), path: "build/verification/temperature-menu.png")
        try render(UpdateSettingsView().frame(width: 420, height: 80, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .environment(\.colorScheme, .light).preferredColorScheme(.light),
                   size: CGSize(width: 420, height: 80), path: "build/verification/update-settings.png")
        for card in PanelCard.allCases { preferences.setVisible(card, visible: false) }
        let empty = SystemMonitor.fixture(defaults: defaults, memory: MemorySnapshot(), disks: [], thermal: ThermalSnapshot())
        try render(PanelView().environment(empty).environment(preferences).preferredColorScheme(.light),
                   size: CGSize(width: 400, height: 740), path: "build/verification/empty-panel.png")
    }
}

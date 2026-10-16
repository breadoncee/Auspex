import AppKit
import SwiftUI

@main
struct MenuBarIconTests {
    @MainActor
    static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let root = URL(fileURLWithPath: "build/verification/icon-fixtures-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        for hasPNG in [true, false] {
            let url = root.appendingPathComponent(hasPNG ? "Loose.bundle" : "Missing.bundle")
            let resources = url.appendingPathComponent("Contents/Resources")
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            let info: [String: String] = ["CFBundleIdentifier": "com.local.auspex.icon-test.\(UUID().uuidString)", "CFBundlePackageType": "BNDL"]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: url.appendingPathComponent("Contents/Info.plist"))
            if hasPNG {
                try FileManager.default.copyItem(
                    at: URL(fileURLWithPath: "Sources/Assets.xcassets/MenuBarGlyph.imageset/glyph_18.png"),
                    to: resources.appendingPathComponent("MenuBarGlyph.png"))
            }
            guard let bundle = Bundle(url: url) else { fatalError("Cannot create icon fixture bundle") }
            let icon = MenuBarIcon.load(in: bundle)
            precondition(icon.isTemplate, "Status image must follow menu bar foreground colors")
            precondition(icon.size == NSSize(width: 18, height: 15), "Status image must keep its point size")
            for dark in [false, true] {
                let renderer = ImageRenderer(content: Image(nsImage: icon).renderingMode(.template)
                    .foregroundStyle(dark ? Color.white : Color.black))
                renderer.scale = 2
                guard let image = renderer.cgImage else { fatalError("Menu bar logo cannot render") }
                let bitmap = NSBitmapImageRep(cgImage: image)
                precondition(bitmap.pixelsWide == 36 && bitmap.pixelsHigh == 30, "Retina icon dimensions changed")
                var visible = 0
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<bitmap.pixelsWide {
                        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                              color.alphaComponent > 0.2 else { continue }
                        visible += 1
                        precondition(dark ? color.redComponent > 0.9 : color.redComponent < 0.1,
                                     "Template icon must be light on a dark menu bar and dark on a light menu bar")
                    }
                }
                precondition(visible > 20, "Menu bar logo is blank")
                print("PASS: \(hasPNG ? "loose PNG" : "missing-resource fallback"), \(dark ? "dark" : "light") menu bar (\(visible) visible pixels)")
            }
        }
    }
}

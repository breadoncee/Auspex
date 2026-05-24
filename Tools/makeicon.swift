//
//  makeicon.swift
//  Auspex — generates the app icon (1024px PNG) with Core Graphics.
//  Run:  swift Tools/makeicon.swift /tmp/auspex_icon.png
//

import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/auspex_icon.png"
let S: CGFloat = 1024

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r/255, g/255, b/255, a])!
}

// MARK: Squircle background (inset like a native macOS icon)
let inset: CGFloat = 96
let rect = CGRect(x: inset, y: inset, width: S - 2*inset, height: S - 2*inset)
let radius: CGFloat = (S - 2*inset) * 0.225
let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()

// Diagonal vibrant gradient: sky-blue -> violet
let grad = CGGradient(colorsSpace: cs, colors: [
    rgb(70, 178, 250),    // sky
    rgb(120, 120, 250),
    rgb(166, 110, 248),   // violet
] as CFArray, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: inset, y: S - inset),
                       end: CGPoint(x: S - inset, y: inset), options: [])

// Soft top highlight
let hi = CGGradient(colorsSpace: cs, colors: [
    rgb(255, 255, 255, 0.28), rgb(255, 255, 255, 0)
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(hi, startCenter: CGPoint(x: S*0.5, y: S*0.86), startRadius: 0,
                       endCenter: CGPoint(x: S*0.5, y: S*0.86), endRadius: S*0.6, options: [])
ctx.restoreGState()

// MARK: Gauge
let center = CGPoint(x: S/2, y: S/2)
let R: CGFloat = 300
let lw: CGFloat = 78
func rad(_ deg: CGFloat) -> CGFloat { deg * .pi / 180 }

// Track arc (open at the bottom): from 320° CCW to 220°
ctx.setLineCap(.round)
ctx.setLineWidth(lw)
ctx.setStrokeColor(rgb(255, 255, 255, 0.30))
ctx.addArc(center: center, radius: R, startAngle: rad(320), endAngle: rad(220),
           clockwise: false)
ctx.strokePath()

// Progress arc (~0.64) from lower-left (220°) clockwise
let sweep: CGFloat = 260
let frac: CGFloat = 0.64
let endDeg = 220 - sweep * frac
ctx.setStrokeColor(rgb(255, 255, 255, 1))
ctx.setShadow(offset: .zero, blur: 26, color: rgb(255, 255, 255, 0.55))
ctx.addArc(center: center, radius: R, startAngle: rad(220), endAngle: rad(endDeg),
           clockwise: true)
ctx.strokePath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// MARK: Pulse / heartbeat line across the middle
let pulse = CGMutablePath()
let pts: [CGPoint] = [
    CGPoint(x: 320, y: 512),
    CGPoint(x: 430, y: 512),
    CGPoint(x: 470, y: 596),
    CGPoint(x: 524, y: 408),
    CGPoint(x: 566, y: 560),
    CGPoint(x: 602, y: 512),
    CGPoint(x: 704, y: 512),
]
pulse.move(to: pts[0])
for p in pts.dropFirst() { pulse.addLine(to: p) }
ctx.setLineWidth(34)
ctx.setLineJoin(.round)
ctx.setStrokeColor(rgb(255, 255, 255, 1))
ctx.setShadow(offset: .zero, blur: 18, color: rgb(120, 120, 250, 0.8))
ctx.addPath(pulse)
ctx.strokePath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// MARK: Write PNG
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")

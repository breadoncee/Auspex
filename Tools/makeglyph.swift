//
//  makeglyph.swift
//  Auspex — renders the menu bar pulse glyph as a black-on-transparent
//  template PNG (macOS recolors template images for the menu bar).
//  Run:  swift Tools/makeglyph.swift <out.png> <width> <height>
//

import AppKit

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "/tmp/glyph.png"
let W = args.count > 3 ? Int(args[2]) ?? 36 : 36
let H = args.count > 3 ? Int(args[3]) ?? 30 : 30

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

let w = CGFloat(W), h = CGFloat(H)
// Note: CG is y-up, so flip the y fractions used by the SwiftUI mark.
let pts: [(CGFloat, CGFloat)] = [
    (0.05, 0.50), (0.30, 0.50), (0.41, 0.20),
    (0.53, 0.86), (0.65, 0.40), (0.73, 0.50), (0.95, 0.50),
]
let path = CGMutablePath()
path.move(to: CGPoint(x: pts[0].0 * w, y: pts[0].1 * h))
for p in pts.dropFirst() { path.addLine(to: CGPoint(x: p.0 * w, y: p.1 * h)) }

ctx.setLineWidth(max(1.4, min(w, h) * 0.14))
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.setStrokeColor(CGColor(colorSpace: cs, components: [0, 0, 0, 1])!)  // black template
ctx.addPath(path)
ctx.strokePath()

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) \(W)x\(H)")

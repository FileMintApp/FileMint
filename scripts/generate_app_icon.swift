#!/usr/bin/env swift
import AppKit

// Vector master, in a 1024-point coordinate space. AppKit renders every size
// directly, so small icons never inherit blurred downscaled edges.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Resources/Assets.xcassets")
let sources = root.appendingPathComponent("Resources/IconSource")
let fm = FileManager.default
try fm.createDirectory(at: sources, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

func document() -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 324, y: 212))
    p.line(to: NSPoint(x: 680, y: 212))
    p.curve(to: NSPoint(x: 724, y: 256), controlPoint1: NSPoint(x: 708, y: 212), controlPoint2: NSPoint(x: 724, y: 230))
    p.line(to: NSPoint(x: 724, y: 624))
    p.line(to: NSPoint(x: 556, y: 808))
    p.line(to: NSPoint(x: 324, y: 808))
    p.curve(to: NSPoint(x: 280, y: 764), controlPoint1: NSPoint(x: 296, y: 808), controlPoint2: NSPoint(x: 280, y: 790))
    p.line(to: NSPoint(x: 280, y: 256))
    p.curve(to: NSPoint(x: 324, y: 212), controlPoint1: NSPoint(x: 280, y: 230), controlPoint2: NSPoint(x: 296, y: 212))
    p.close()
    return p
}

func draw(pixels: Int, glyph: Bool = false) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
    (transform as NSAffineTransform).concat()
    if glyph {
        let shape = document()
        NSColor.black.setStroke()
        shape.lineWidth = 66
        shape.lineJoinStyle = .round
        shape.stroke()
        let plus = NSBezierPath()
        plus.move(to: NSPoint(x: 394, y: 448)); plus.line(to: NSPoint(x: 610, y: 448))
        plus.move(to: NSPoint(x: 502, y: 340)); plus.line(to: NSPoint(x: 502, y: 556))
        plus.lineWidth = 66; plus.lineCapStyle = .round; plus.stroke()
    } else {
        let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 194, yRadius: 194)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -10); shadow.set()
        color(19, 69, 64).setFill(); tile.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: color(32, 98, 85), ending: color(14, 48, 49))!.draw(in: tile, angle: -75)
        NSGraphicsContext.saveGraphicsState()
        let paperShadow = NSShadow(); paperShadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
        paperShadow.shadowBlurRadius = 16; paperShadow.shadowOffset = NSSize(width: 0, height: -10); paperShadow.set()
        color(241, 255, 248).setFill(); document().fill()
        NSGraphicsContext.restoreGraphicsState()
        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: 556, y: 808)); fold.line(to: NSPoint(x: 556, y: 664))
        fold.curve(to: NSPoint(x: 596, y: 624), controlPoint1: NSPoint(x: 556, y: 636), controlPoint2: NSPoint(x: 568, y: 624))
        fold.line(to: NSPoint(x: 724, y: 624)); fold.close()
        color(165, 226, 205).setFill(); fold.fill()
        let plus = NSBezierPath()
        plus.move(to: NSPoint(x: 394, y: 440)); plus.line(to: NSPoint(x: 610, y: 440))
        plus.move(to: NSPoint(x: 502, y: 332)); plus.line(to: NSPoint(x: 502, y: 548))
        plus.lineWidth = 60; plus.lineCapStyle = .round
        color(25, 131, 101).setStroke(); plus.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func png(_ pixels: Int, to url: URL, glyph: Bool = false) throws {
    try draw(pixels: pixels, glyph: glyph).representation(using: .png, properties: [:])!.write(to: url)
}
func manifest(_ images: [[String: String]], at directory: URL, glyph: Bool = false) throws {
    var data: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    if glyph { data["properties"] = ["template-rendering-intent": "template"] }
    try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("Contents.json"))
}

let appDir = assets.appendingPathComponent("AppIcon.appiconset")
try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
var slots: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "FileMint-\(size)x\(size)@\(scale)x.png"
        try png(size * scale, to: appDir.appendingPathComponent(name))
        slots.append(["filename": name, "idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x"])
    }
}
try manifest(slots, at: appDir)
try png(1024, to: sources.appendingPathComponent("FileMint-AppIcon-1024.png"))
for name in ["MenuBarIcon", "FinderMenuIcon"] {
    let dir = assets.appendingPathComponent("\(name).imageset")
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    var images: [[String: String]] = []
    for scale in [1, 2] {
        let filename = "FileMint-\(name)-18x18@\(scale)x.png"
        try png(18 * scale, to: dir.appendingPathComponent(filename), glyph: true)
        images.append(["filename": filename, "idiom": "mac", "scale": "\(scale)x"])
    }
    try manifest(images, at: dir, glyph: true)
    try png(54, to: sources.appendingPathComponent("FileMint-\(name)-54.png"), glyph: true)
}
print("Generated FileMint app, menu bar and Finder toolbar icons.")

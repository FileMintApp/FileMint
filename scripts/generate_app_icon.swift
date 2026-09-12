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

func foldedF() -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 354, y: 208))
    p.line(to: NSPoint(x: 438, y: 208))
    p.curve(to: NSPoint(x: 484, y: 254), controlPoint1: NSPoint(x: 467, y: 208), controlPoint2: NSPoint(x: 484, y: 225))
    p.line(to: NSPoint(x: 484, y: 438))
    p.line(to: NSPoint(x: 654, y: 438))
    p.curve(to: NSPoint(x: 696, y: 480), controlPoint1: NSPoint(x: 682, y: 438), controlPoint2: NSPoint(x: 696, y: 452))
    p.line(to: NSPoint(x: 696, y: 520))
    p.curve(to: NSPoint(x: 654, y: 562), controlPoint1: NSPoint(x: 696, y: 548), controlPoint2: NSPoint(x: 682, y: 562))
    p.line(to: NSPoint(x: 484, y: 562))
    p.line(to: NSPoint(x: 484, y: 630))
    p.line(to: NSPoint(x: 718, y: 630))
    p.curve(to: NSPoint(x: 764, y: 674), controlPoint1: NSPoint(x: 751, y: 630), controlPoint2: NSPoint(x: 764, y: 647))
    p.line(to: NSPoint(x: 622, y: 816))
    p.line(to: NSPoint(x: 378, y: 816))
    p.curve(to: NSPoint(x: 304, y: 742), controlPoint1: NSPoint(x: 333, y: 816), controlPoint2: NSPoint(x: 304, y: 787))
    p.line(to: NSPoint(x: 304, y: 258))
    p.curve(to: NSPoint(x: 354, y: 208), controlPoint1: NSPoint(x: 304, y: 226), controlPoint2: NSPoint(x: 322, y: 208))
    p.close()
    return p
}

func paperFold() -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 622, y: 816))
    p.curve(to: NSPoint(x: 644, y: 788), controlPoint1: NSPoint(x: 639, y: 816), controlPoint2: NSPoint(x: 644, y: 805))
    p.line(to: NSPoint(x: 644, y: 720))
    p.curve(to: NSPoint(x: 680, y: 682), controlPoint1: NSPoint(x: 644, y: 693), controlPoint2: NSPoint(x: 655, y: 682))
    p.line(to: NSPoint(x: 720, y: 682))
    p.curve(to: NSPoint(x: 758, y: 653), controlPoint1: NSPoint(x: 742, y: 682), controlPoint2: NSPoint(x: 758, y: 670))
    p.curve(to: NSPoint(x: 764, y: 674), controlPoint1: NSPoint(x: 763, y: 659), controlPoint2: NSPoint(x: 764, y: 668))
    p.close()
    return p
}

func draw(pixels: Int, glyph: Bool = false, tinted: Bool = false) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
    (transform as NSAffineTransform).concat()
    let shape = foldedF()
    if glyph {
        // Fit the actual silhouette into 15 points of an 18-point toolbar asset.
        let placement = AffineTransform(m11: 1.42, m12: 0, m21: 0, m22: 1.42, tX: -246, tY: -215)
        shape.transform(using: placement)
        (tinted ? color(24, 154, 115) : NSColor.black).setFill(); shape.fill()
        let foldCut = NSBezierPath()
        foldCut.move(to: NSPoint(x: 636, y: 778))
        foldCut.line(to: NSPoint(x: 636, y: 703))
        foldCut.line(to: NSPoint(x: 711, y: 703))
        foldCut.close()
        foldCut.transform(using: placement)
        NSGraphicsContext.current?.compositingOperation = .clear
        foldCut.fill()
    } else {
        let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 188, yRadius: 188)
        NSGraphicsContext.saveGraphicsState()
        let tileShadow = NSShadow()
        tileShadow.shadowColor = NSColor.black.withAlphaComponent(0.10)
        tileShadow.shadowBlurRadius = 12
        tileShadow.shadowOffset = NSSize(width: 0, height: -5)
        tileShadow.set()
        color(247, 246, 240).setFill(); tile.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: color(255, 254, 250), ending: color(232, 231, 224))!.draw(in: tile, angle: -85)
        NSColor.white.withAlphaComponent(0.85).setStroke(); tile.lineWidth = 2; tile.stroke()

        NSGraphicsContext.saveGraphicsState()
        let paperShadow = NSShadow()
        paperShadow.shadowColor = color(39, 67, 47).withAlphaComponent(0.28)
        paperShadow.shadowBlurRadius = 22
        paperShadow.shadowOffset = NSSize(width: 6, height: -16)
        paperShadow.set()
        color(22, 159, 123).setFill(); shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [color(21, 154, 122), color(68, 195, 151), color(169, 255, 212)])!
            .draw(in: shape, angle: 82)
        color(30, 137, 105).withAlphaComponent(0.42).setStroke()
        shape.lineWidth = 2; shape.stroke()

        // Subtle sheet overlap; all geometry remains vector-native at small sizes.
        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        let middle = NSBezierPath(roundedRect: NSRect(x: 484, y: 438, width: 212, height: 124), xRadius: 38, yRadius: 38)
        NSGradient(starting: color(134, 237, 190), ending: color(60, 187, 146))!.draw(in: middle, angle: -80)
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        let foldShadow = NSShadow()
        foldShadow.shadowColor = color(5, 96, 64).withAlphaComponent(0.38)
        foldShadow.shadowBlurRadius = 12
        foldShadow.shadowOffset = NSSize(width: 0, height: -12)
        foldShadow.set()
        color(180, 255, 218).setFill(); paperFold().fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: color(221, 255, 235), ending: color(153, 239, 193))!.draw(in: paperFold(), angle: -65)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func png(_ pixels: Int, to url: URL, glyph: Bool = false, tinted: Bool = false) throws {
    try draw(pixels: pixels, glyph: glyph, tinted: tinted).representation(using: .png, properties: [:])!.write(to: url)
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

// A native-size light/dark proof of the independently drawn template glyph.
let proof = NSImage(size: NSSize(width: 360, height: 90))
proof.lockFocus()
for (offset, background, foreground, label) in [
    (CGFloat(0), NSColor.white, NSColor.black, "18 pt · Light"),
    (CGFloat(180), color(28, 29, 31), NSColor.white, "18 pt · Dark")
] {
    background.setFill(); NSBezierPath(rect: NSRect(x: offset, y: 0, width: 180, height: 90)).fill()
    let mark = foldedF()
    let scale = CGFloat(18) / 1024
    let placement = AffineTransform(m11: 1.42 * scale, m12: 0, m21: 0, m22: 1.42 * scale,
                                   tX: offset + 81 - 246 * scale, tY: 48 - 215 * scale)
    mark.transform(using: placement)
    foreground.setFill(); mark.fill()
    let cut = NSBezierPath()
    cut.move(to: NSPoint(x: 636, y: 778)); cut.line(to: NSPoint(x: 636, y: 703))
    cut.line(to: NSPoint(x: 711, y: 703)); cut.close(); cut.transform(using: placement)
    background.setFill(); cut.fill()
    (label as NSString).draw(at: NSPoint(x: offset + 51, y: 20), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12), .foregroundColor: foreground.withAlphaComponent(0.65)
    ])
}
proof.unlockFocus()
let proofRep = NSBitmapImageRep(data: proof.tiffRepresentation!)!
try proofRep.representation(using: .png, properties: [:])!
    .write(to: sources.appendingPathComponent("FileMint-GlyphPreview.png"))

let rootMenuDirectory = assets.appendingPathComponent("FinderRootMenuIcon.imageset")
try fm.createDirectory(at: rootMenuDirectory, withIntermediateDirectories: true)
var rootMenuImages: [[String: String]] = []
for scale in [1, 2] {
    let name = "FileMint-FinderRootMenuIcon-16x16@\(scale)x.png"
    try png(16 * scale, to: rootMenuDirectory.appendingPathComponent(name), glyph: true, tinted: true)
    rootMenuImages.append(["filename": name, "idiom": "mac", "scale": "\(scale)x"])
}
try manifest(rootMenuImages, at: rootMenuDirectory)
try png(48, to: sources.appendingPathComponent("FileMint-FinderRootMenuIcon-48.png"), glyph: true, tinted: true)

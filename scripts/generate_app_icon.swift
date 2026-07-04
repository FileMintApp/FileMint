#!/usr/bin/env swift

import AppKit
import Foundation

struct IconSlot {
    let size: Int
    let scale: Int

    var pixels: Int { size * scale }
    var filename: String { "FileMint-\(size)x\(size)@\(scale)x.png" }
}

struct ImageSetSlot {
    let pointSize: Int
    let scale: Int

    var pixels: Int { pointSize * scale }
    var filename: String { "FileMint-MenuBarIcon-\(pointSize)x\(pointSize)@\(scale)x.png" }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = root.appendingPathComponent("Resources", isDirectory: true)
let iconSourceURL = resourcesURL.appendingPathComponent("IconSource", isDirectory: true)
let assetsURL = resourcesURL.appendingPathComponent("Assets.xcassets", isDirectory: true)
let appIconURL = assetsURL.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
let menuBarIconURL = assetsURL.appendingPathComponent("MenuBarIcon.imageset", isDirectory: true)
let appIconSourceURL = iconSourceURL.appendingPathComponent("FileMint-AppIcon-1024.png")
let menuBarIconSourceURL = iconSourceURL.appendingPathComponent("FileMint-MenuBarIcon-54.png")

let appIconSlots = [
    IconSlot(size: 16, scale: 1),
    IconSlot(size: 16, scale: 2),
    IconSlot(size: 32, scale: 1),
    IconSlot(size: 32, scale: 2),
    IconSlot(size: 128, scale: 1),
    IconSlot(size: 128, scale: 2),
    IconSlot(size: 256, scale: 1),
    IconSlot(size: 256, scale: 2),
    IconSlot(size: 512, scale: 1),
    IconSlot(size: 512, scale: 2)
]

let menuBarSlots = [
    ImageSetSlot(pointSize: 18, scale: 1),
    ImageSetSlot(pointSize: 18, scale: 2)
]

try FileManager.default.createDirectory(at: iconSourceURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: appIconURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuBarIconURL, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func withGraphicsState(_ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

func withCompositingOperation(_ operation: NSCompositingOperation, body: () -> Void) {
    withGraphicsState {
        NSGraphicsContext.current?.compositingOperation = operation
        body()
    }
}

func withRotation(around center: NSPoint, degrees: CGFloat, body: () -> Void) {
    withGraphicsState {
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()
        body()
    }
}

func makeBitmap(pixels: Int, draw: (CGFloat) -> Void) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    let context = NSGraphicsContext(bitmapImageRep: bitmap)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let side = CGFloat(pixels)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
    draw(side)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func drawRoundedRect(
    _ rect: NSRect,
    radius: CGFloat,
    fill: NSColor,
    stroke: NSColor? = nil,
    lineWidth: CGFloat = 1,
    shadow: NSShadow? = nil
) {
    shadow?.set()
    let path = roundedRect(rect, radius: radius)
    fill.setFill()
    path.fill()
    NSShadow().set()

    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawGradient(_ colors: [NSColor], in path: NSBezierPath, angle: CGFloat) {
    NSGradient(colors: colors)!.draw(in: path, angle: angle)
}

func drawDefaultAppIcon(pixels: Int) -> NSBitmapImageRep {
    makeBitmap(pixels: pixels) { side in
        let canvas = NSRect(x: 0, y: 0, width: side, height: side)
        let inset = side * 0.055
        let baseRect = canvas.insetBy(dx: inset, dy: inset)
        let basePath = roundedRect(baseRect, radius: side * 0.22)

        drawGradient(
            [
                color(19, 32, 42),
                color(26, 84, 89),
                color(76, 215, 172)
            ],
            in: basePath,
            angle: 315
        )

        withGraphicsState {
            basePath.addClip()

            let haloRect = NSRect(x: side * -0.06, y: side * 0.53, width: side * 0.72, height: side * 0.48)
            drawGradient(
                [color(126, 255, 211, 0.42), color(126, 255, 211, 0)],
                in: NSBezierPath(ovalIn: haloRect),
                angle: 45
            )

            let lowBand = NSBezierPath()
            lowBand.move(to: NSPoint(x: baseRect.minX, y: baseRect.minY + side * 0.20))
            lowBand.curve(
                to: NSPoint(x: baseRect.maxX, y: baseRect.minY + side * 0.36),
                controlPoint1: NSPoint(x: baseRect.minX + side * 0.30, y: baseRect.minY + side * 0.02),
                controlPoint2: NSPoint(x: baseRect.maxX - side * 0.20, y: baseRect.minY + side * 0.56)
            )
            lowBand.line(to: NSPoint(x: baseRect.maxX, y: baseRect.minY))
            lowBand.line(to: NSPoint(x: baseRect.minX, y: baseRect.minY))
            lowBand.close()
            color(6, 22, 32, 0.30).setFill()
            lowBand.fill()

            let diagonal = NSBezierPath()
            diagonal.move(to: NSPoint(x: baseRect.minX + side * 0.10, y: baseRect.minY))
            diagonal.line(to: NSPoint(x: baseRect.maxX, y: baseRect.minY + side * 0.62))
            diagonal.line(to: NSPoint(x: baseRect.maxX, y: baseRect.minY + side * 0.38))
            diagonal.line(to: NSPoint(x: baseRect.minX + side * 0.31, y: baseRect.minY))
            diagonal.close()
            color(255, 255, 255, 0.06).setFill()
            diagonal.fill()
        }

        let cardShadow = NSShadow()
        cardShadow.shadowBlurRadius = side * 0.040
        cardShadow.shadowOffset = NSSize(width: 0, height: -side * 0.022)
        cardShadow.shadowColor = color(0, 10, 18, 0.30)

        let backCard = NSRect(x: side * 0.265, y: side * 0.275, width: side * 0.43, height: side * 0.48)
        withRotation(around: NSPoint(x: backCard.midX, y: backCard.midY), degrees: -8) {
            drawRoundedRect(
                backCard,
                radius: side * 0.060,
                fill: color(212, 246, 237, 0.52),
                stroke: color(255, 255, 255, 0.26),
                lineWidth: max(1, side * 0.004),
                shadow: cardShadow
            )
        }

        let frontCard = NSRect(x: side * 0.315, y: side * 0.235, width: side * 0.43, height: side * 0.52)
        withRotation(around: NSPoint(x: frontCard.midX, y: frontCard.midY), degrees: 4) {
            drawRoundedRect(
                frontCard,
                radius: side * 0.065,
                fill: color(247, 255, 251, 0.92),
                stroke: color(255, 255, 255, 0.62),
                lineWidth: max(1, side * 0.004),
                shadow: cardShadow
            )

            let fold = NSBezierPath()
            fold.move(to: NSPoint(x: frontCard.maxX - side * 0.125, y: frontCard.maxY))
            fold.line(to: NSPoint(x: frontCard.maxX, y: frontCard.maxY - side * 0.125))
            fold.line(to: NSPoint(x: frontCard.maxX, y: frontCard.maxY))
            fold.close()
            color(199, 241, 232, 0.70).setFill()
            fold.fill()
        }

        let sealShadow = NSShadow()
        sealShadow.shadowBlurRadius = side * 0.030
        sealShadow.shadowOffset = NSSize(width: 0, height: -side * 0.018)
        sealShadow.shadowColor = color(0, 25, 30, 0.30)
        sealShadow.set()

        let sealRect = NSRect(x: side * 0.545, y: side * 0.280, width: side * 0.245, height: side * 0.245)
        let sealPath = NSBezierPath(ovalIn: sealRect)
        drawGradient([color(33, 222, 163), color(11, 150, 134)], in: sealPath, angle: 270)
        NSShadow().set()

        color(255, 255, 255, 0.18).setStroke()
        sealPath.lineWidth = max(1, side * 0.006)
        sealPath.stroke()

        let barRadius = side * 0.018
        let markColor = color(247, 255, 251, 0.96)
        let markShadow = NSShadow()
        markShadow.shadowBlurRadius = side * 0.010
        markShadow.shadowOffset = NSSize(width: 0, height: -side * 0.006)
        markShadow.shadowColor = color(0, 45, 48, 0.18)

        let fOrigin = NSPoint(x: sealRect.minX + side * 0.083, y: sealRect.minY + side * 0.062)
        drawRoundedRect(
            NSRect(x: fOrigin.x, y: fOrigin.y, width: side * 0.040, height: side * 0.134),
            radius: barRadius,
            fill: markColor,
            shadow: markShadow
        )
        drawRoundedRect(
            NSRect(x: fOrigin.x, y: fOrigin.y + side * 0.102, width: side * 0.108, height: side * 0.039),
            radius: barRadius,
            fill: markColor,
            shadow: markShadow
        )
        drawRoundedRect(
            NSRect(x: fOrigin.x, y: fOrigin.y + side * 0.052, width: side * 0.086, height: side * 0.036),
            radius: barRadius,
            fill: markColor,
            shadow: markShadow
        )
    }
}

func drawDefaultMenuBarIcon(pixels: Int) -> NSBitmapImageRep {
    makeBitmap(pixels: pixels) { side in
        let ink = color(255, 255, 255)
        ink.setFill()
        ink.setStroke()

        let badgeRect = NSRect(x: side * 0.12, y: side * 0.10, width: side * 0.76, height: side * 0.76)
        NSBezierPath(ovalIn: badgeRect).fill()

        withCompositingOperation(.clear) {
            let cutoutRadius = side * 0.035
            roundedRect(
                NSRect(x: side * 0.37, y: side * 0.27, width: side * 0.12, height: side * 0.43),
                radius: cutoutRadius
            ).fill()
            roundedRect(
                NSRect(x: side * 0.37, y: side * 0.58, width: side * 0.30, height: side * 0.12),
                radius: cutoutRadius
            ).fill()
            roundedRect(
                NSRect(x: side * 0.37, y: side * 0.44, width: side * 0.24, height: side * 0.11),
                radius: cutoutRadius
            ).fill()
        }
    }
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "FileMintIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }

    try data.write(to: url, options: .atomic)
}

func loadSourceImage(at url: URL, defaultBitmap: () -> NSBitmapImageRep) throws -> NSImage {
    if !FileManager.default.fileExists(atPath: url.path) {
        try writePNG(defaultBitmap(), to: url)
    }

    guard let image = NSImage(contentsOf: url) else {
        throw NSError(domain: "FileMintIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not load icon source at \(url.path)"])
    }

    if let representation = image.representations.first {
        image.size = NSSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }

    return image
}

func render(_ image: NSImage, pixels: Int) -> NSBitmapImageRep {
    makeBitmap(pixels: pixels) { side in
        let destination = NSRect(x: 0, y: 0, width: side, height: side)
        let source = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        image.draw(in: destination, from: source, operation: .sourceOver, fraction: 1)
    }
}

func writeIfMissing(_ text: String, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        return
    }

    try text.write(to: url, atomically: true, encoding: .utf8)
}

let iconSourceReadme = """
# FileMint Icon Source

This folder contains editable icon source PNGs.

- `FileMint-AppIcon-1024.png` is the master app icon source for Dock, Finder, app bundle, and extension icons.
- `FileMint-MenuBarIcon-54.png` is the master template icon source for the macOS menu bar.

After editing either source file, run `make icon` from the repository root to regenerate `Resources/Assets.xcassets`.
"""

try writeIfMissing(iconSourceReadme, to: iconSourceURL.appendingPathComponent("README.md"))

let appIconSource = try loadSourceImage(at: appIconSourceURL) {
    drawDefaultAppIcon(pixels: 1024)
}

let menuBarIconSource = try loadSourceImage(at: menuBarIconSourceURL) {
    drawDefaultMenuBarIcon(pixels: 54)
}

for slot in appIconSlots {
    try writePNG(render(appIconSource, pixels: slot.pixels), to: appIconURL.appendingPathComponent(slot.filename))
}

for slot in menuBarSlots {
    try writePNG(render(menuBarIconSource, pixels: slot.pixels), to: menuBarIconURL.appendingPathComponent(slot.filename))
}

let assetContents = """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try assetContents.write(to: assetsURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

let appIconImages = appIconSlots.map { slot -> String in
    """
    {
      "filename" : "\(slot.filename)",
      "idiom" : "mac",
      "scale" : "\(slot.scale)x",
      "size" : "\(slot.size)x\(slot.size)"
    }
    """
}.joined(separator: ",\n")

let appIconContents = """
{
  "images" : [
\(appIconImages.split(separator: "\n").map { "    \($0)" }.joined(separator: "\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try appIconContents.write(to: appIconURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

let menuBarImages = menuBarSlots.map { slot -> String in
    """
    {
      "filename" : "\(slot.filename)",
      "idiom" : "mac",
      "scale" : "\(slot.scale)x"
    }
    """
}.joined(separator: ",\n")

let menuBarIconContents = """
{
  "images" : [
\(menuBarImages.split(separator: "\n").map { "    \($0)" }.joined(separator: "\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
"""
try menuBarIconContents.write(to: menuBarIconURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

print("Icon sources: \(iconSourceURL.path)")
print("Generated AppIcon: \(appIconURL.path)")
print("Generated MenuBarIcon: \(menuBarIconURL.path)")

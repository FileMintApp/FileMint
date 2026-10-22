import AppKit
import FileMintCore

/// One native symbol renderer for settings and both Finder menu locations.
enum FileToolAppearance {
    static let openWithSymbol = "square.stack.3d.up"
    private static let applicationIcons = ApplicationIconCache()

    static func image(for tool: FileTool, size: CGFloat = 16,
                      customization: MenuIconCustomization? = nil,
                      style: FinderMenuIconStyle = .colored) -> NSImage? {
        image(for: tool.menuIconSlot, customization: customization, size: size, style: style)
    }

    static func image(for tool: ResourceTool, size: CGFloat = 16,
                      customization: MenuIconCustomization? = nil,
                      style: FinderMenuIconStyle = .colored) -> NSImage? {
        image(for: tool.menuIconSlot, customization: customization, size: size, style: style)
    }

    static var toolsImage: NSImage? {
        image(for: .fileTools)
    }

    static var moveHereImage: NSImage? {
        image(for: .moveHere)
    }

    static var resourceToolsImage: NSImage? {
        image(for: .resourceTools)
    }

    static var favoriteImage: NSImage? {
        image(for: .favoriteLocations)
    }

    static var openWithImage: NSImage? {
        image(for: .openWith)
    }

    static func image(for slot: MenuIconSlot, customization: MenuIconCustomization? = nil,
                      size: CGFloat = 16, defaultBundle: Bundle? = nil,
                      style: FinderMenuIconStyle = .colored) -> NSImage? {
        if let customization, let chosen = image(for: customization, size: size, style: style) {
            return chosen
        }
        if (slot == .newFile || slot == .customNewFile), let bundle = defaultBundle,
           let logo = bundle.image(forResource: style == .colored ? "FinderRootMenuIcon" : "FinderMenuIcon")?.copy() as? NSImage {
            logo.size = NSSize(width: size, height: size)
            logo.isTemplate = style == .systemMonochrome
            return logo
        }
        let colors = defaultColors(for: slot)
        return image(slot.defaultSymbolName, palette: [colors.0, colors.1], size: size, style: style)
    }

    static func image(for template: FileTemplate, size: CGFloat = 16,
                      style: FinderMenuIconStyle = .colored) -> NSImage? {
        if let custom = template.customMenuIcon,
           let chosen = image(for: custom, size: size, style: style) {
            return chosen
        }
        let colors = defaultColors(for: template)
        let symbol = TemplateCatalog.defaultMenuSymbol(forSuffix: template.fileExtension)
        return image(symbol, palette: [colors.0, colors.1], size: size, style: style)
            ?? image("doc", palette: [colors.0, colors.1], size: size, style: style)
    }

    static func defaultColors(for slot: MenuIconSlot) -> (NSColor, NSColor) {
        switch slot {
        case .newFile, .customNewFile: (.systemMint, .systemTeal)
        case .clipboardText: (.systemBlue, .systemCyan)
        case .clipboardImage: (.systemPurple, .systemPink)
        case .fileTools, .resourceTools: (.systemMint, .systemBlue)
        case .moveHere: (.systemMint, .systemTeal)
        case .move: (.systemTeal, .systemMint)
        case .copyNames: (.systemBlue, .systemCyan)
        case .copyPaths: (.systemIndigo, .systemBlue)
        case .copyContents: (.systemBlue, .systemTeal)
        case .permanentDelete: (.systemOrange, .systemRed)
        case .airDrop: (.systemPurple, .systemIndigo)
        case .desktopAlias: (.systemBlue, .systemTeal)
        case .batchRename: (.systemMint, .systemTeal)
        case .fileInfo: (.systemTeal, .systemBlue)
        case .convert: (.systemBlue, .systemTeal)
        case .compress: (.systemOrange, .systemRed)
        case .resize: (.systemIndigo, .systemBlue)
        case .icons: (.systemPurple, .systemPink)
        case .stitch: (.systemMint, .systemTeal)
        case .ocr: (.systemGreen, .systemBlue)
        case .removeMetadata: (.systemMint, .systemGreen)
        case .openWith: (.systemMint, .systemTeal)
        case .favoriteLocations: (.systemMint, .systemYellow)
        }
    }

    static func defaultColors(for template: FileTemplate) -> (NSColor, NSColor) {
        switch template.fileExtension.lowercased() {
        case "md", "markdown", "docx": (.systemIndigo, .systemBlue)
        case "csv", "xlsx", "sql": (.systemGreen, .systemTeal)
        case "swift", "json", "html", "css", "sh", "yaml", "xml", "js", "ts", "py": (.systemPurple, .systemBlue)
        default: (.systemBlue, .systemTeal)
        }
    }

    static func applicationImage(at url: URL, size: CGFloat = 16) -> NSImage? {
        applicationIcons.image(at: url, size: size)
    }

    static func image(for customization: MenuIconCustomization, size: CGFloat = 16,
                      style: FinderMenuIconStyle = .colored) -> NSImage? {
        image(customization.symbolName,
              palette: [color(customization.primaryHex), color(customization.secondaryHex)], size: size, style: style)
    }

    /// Give Finder explicit black/white pixels that do not rely on host template tinting.
    /// Settings keep the original template; configured application icons bypass this.
    static func finderMenuImage(_ source: NSImage?, foreground: MonochromeMenuForeground?) -> NSImage? {
        guard let source, source.isTemplate, let foreground else { return source }
        let size = source.size
        guard size.width > 0, size.height > 0 else { return source }
        let result = NSImage(size: size)
        let bounds = NSRect(origin: .zero, size: size)
        for scale: CGFloat in [1, 2] {
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                pixelsWide: Int(ceil(size.width * scale)), pixelsHigh: Int(ceil(size.height * scale)),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return source }
            bitmap.size = size
            context.cgContext.scaleBy(x: scale, y: scale)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            source.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
            foreground.color.setFill()
            bounds.fill(using: .sourceIn)
            NSGraphicsContext.restoreGraphicsState()
            result.addRepresentation(bitmap)
        }
        result.isTemplate = false
        return result
    }

    private static func color(_ hex: String) -> NSColor {
        let digits = Array(hex.dropFirst().utf8)
        func channel(_ offset: Int) -> CGFloat {
            let value = String(decoding: digits[offset..<(offset + 2)], as: UTF8.self)
            return CGFloat(Int(value, radix: 16) ?? 0) / 255
        }
        return NSColor(srgbRed: channel(0), green: channel(2), blue: channel(4), alpha: 1)
    }

    private static func image(_ symbol: String, palette: [NSColor], size: CGFloat = 16,
                              style: FinderMenuIconStyle = .colored) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(style == .systemMonochrome ? .preferringMonochrome() : .init(paletteColors: palette))
        guard let source = NSImage(systemSymbolName: symbol, accessibilityDescription: nil),
              let image = source.withSymbolConfiguration(configuration) else { return nil }
        image.size = NSSize(width: size, height: size)
        // Native previews use template tinting; Finder also receives resolved pixels.
        image.isTemplate = style == .systemMonochrome
        return image
    }
}

/// Only the resolved black/white tone crosses from the main thread to Finder's callback.
struct MonochromeMenuForeground: Sendable {
    private let tone: CGFloat

    init(appearance: NSAppearance) {
        tone = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 1 : 0
    }

    var color: NSColor {
        NSColor(white: tone, alpha: 1)
    }
}

private final class ApplicationIconCache: @unchecked Sendable {
    private let lock = NSLock()
    private let icons: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 64
        return cache
    }()

    func image(at url: URL, size: CGFloat) -> NSImage? {
        lock.lock(); defer { lock.unlock() }
        let key = "\(url.standardizedFileURL.path)#\(Int(size))" as NSString
        if let cached = icons.object(forKey: key) { return cached.copy() as? NSImage }
        guard let image = NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage else { return nil }
        image.size = NSSize(width: size, height: size)
        image.isTemplate = false
        icons.setObject(image, forKey: key)
        return image.copy() as? NSImage
    }
}

import AppKit
import FileMintCore

/// One native symbol palette for settings and both Finder menu locations.
enum FileToolAppearance {
    static let openWithSymbol = "square.stack.3d.up"
    private static let applicationIcons = ApplicationIconCache()

    static func image(for tool: FileTool, size: CGFloat = 16) -> NSImage? {
        switch tool {
        case .copyNames: image("doc.on.doc", palette: [.systemBlue, .systemCyan], size: size)
        case .copyPaths: image("link", palette: [.systemIndigo, .systemBlue], size: size)
        case .move: image("folder", palette: [.systemTeal, .systemMint], size: size)
        case .permanentDelete: image("trash", palette: [.systemOrange, .systemRed], size: size)
        case .desktopAlias: image("arrowshape.turn.up.right", palette: [.systemBlue, .systemTeal], size: size)
        case .airDrop: image("airplayaudio", palette: [.systemPurple, .systemIndigo], size: size)
        }
    }

    static func image(for tool: ResourceTool, size: CGFloat = 16) -> NSImage? {
        let palette: [NSColor] = switch tool {
        case .convert: [.systemBlue, .systemTeal]
        case .compress: [.systemOrange, .systemRed]
        case .resize: [.systemIndigo, .systemBlue]
        case .icons: [.systemPurple, .systemPink]
        case .stitch: [.systemMint, .systemTeal]
        case .ocr: [.systemGreen, .systemBlue]
        }
        return image(tool.symbol, palette: palette, size: size)
    }

    static var toolsImage: NSImage? {
        image("wrench.and.screwdriver", palette: [.systemMint, .systemBlue])
    }

    static var moveHereImage: NSImage? {
        image("arrow.right.square", palette: [.systemMint, .systemTeal])
    }

    static var resourceToolsImage: NSImage? {
        image("photo.on.rectangle", palette: [.systemMint, .systemBlue])
    }

    static var openWithImage: NSImage? {
        image(openWithSymbol, palette: [.systemMint, .systemTeal])
    }

    static func applicationImage(at url: URL, size: CGFloat = 16) -> NSImage? {
        applicationIcons.image(at: url, size: size)
    }

    private static func image(_ symbol: String, palette: [NSColor], size: CGFloat = 16) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: palette))
        guard let source = NSImage(systemSymbolName: symbol, accessibilityDescription: nil),
              let image = source.withSymbolConfiguration(configuration) else { return nil }
        image.size = NSSize(width: size, height: size)
        // Finder must retain the palette, including when an item is highlighted.
        image.isTemplate = false
        return image
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

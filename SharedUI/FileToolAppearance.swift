import AppKit
import FileMintCore

/// One native symbol palette for settings and both Finder menu locations.
enum FileToolAppearance {
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

    static var toolsImage: NSImage? {
        image("wrench.and.screwdriver", palette: [.systemMint, .systemBlue])
    }

    static var moveHereImage: NSImage? {
        image("arrow.right.square", palette: [.systemMint, .systemTeal])
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

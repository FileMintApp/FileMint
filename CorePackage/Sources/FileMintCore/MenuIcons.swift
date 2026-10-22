import Foundation

public enum FinderMenuIconStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case colored, systemMonochrome

    public var id: String { rawValue }
    public var title: FileMintTextKey {
        switch self {
        case .colored: .coloredMenuIcons
        case .systemMonochrome: .systemMonochromeMenuIcons
        }
    }
}

/// Only names and colors are stored; the system supplies the symbol artwork.
public struct MenuIconCustomization: Codable, Equatable, Sendable {
    public let symbolName: String
    public let primaryHex: String
    public let secondaryHex: String

    public init?(symbolName: String, primaryHex: String, secondaryHex: String) {
        let name = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.utf8.count <= 128,
              name.utf8.allSatisfy({ byte in
                  (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte)
                      || byte == 46 || byte == 95
              }),
              let primary = Self.normalizedHex(primaryHex),
              let secondary = Self.normalizedHex(secondaryHex) else { return nil }
        self.symbolName = name
        self.primaryHex = primary
        self.secondaryHex = secondary
    }

    private static func normalizedHex(_ input: String) -> String? {
        let digits = input.hasPrefix("#") ? String(input.dropFirst()) : input
        guard digits.utf8.count == 6,
              digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })
        else { return nil }
        return "#" + digits.uppercased()
    }

    private enum CodingKeys: String, CodingKey { case symbolName, primaryHex, secondaryHex }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let symbol = try values.decode(String.self, forKey: .symbolName)
        let primary = try values.decode(String.self, forKey: .primaryHex)
        let secondary = try values.decode(String.self, forKey: .secondaryHex)
        guard let valid = Self(symbolName: symbol, primaryHex: primary, secondaryHex: secondary) else {
            throw DecodingError.dataCorruptedError(forKey: .symbolName, in: values, debugDescription: "Invalid menu symbol or color")
        }
        self = valid
    }
}

public enum MenuIconSlot: String, CaseIterable, Sendable {
    case newFile, customNewFile, clipboardText, clipboardImage
    case fileTools, moveHere, copyNames, copyPaths, copyContents, move, permanentDelete, airDrop, desktopAlias, batchRename, fileInfo
    case resourceTools, convert, compress, resize, icons, stitch, ocr, removeMetadata
    case openWith, favoriteLocations

    public var defaultSymbolName: String {
        switch self {
        case .newFile, .customNewFile: "doc.badge.plus"
        case .clipboardText: "doc.on.clipboard"
        case .clipboardImage: "photo"
        case .fileTools: "wrench.and.screwdriver"
        case .moveHere: "arrow.right.square"
        case .copyNames: "doc.on.doc"
        case .copyPaths: "link"
        case .copyContents: "doc.text"
        case .move: "folder"
        case .permanentDelete: "trash"
        case .airDrop: "airplayaudio"
        case .desktopAlias: "arrowshape.turn.up.right"
        case .batchRename: "pencil"
        case .fileInfo: "info.circle"
        case .resourceTools: "photo.on.rectangle"
        case .convert: "arrow.triangle.2.circlepath"
        case .compress: "arrow.down.right.and.arrow.up.left"
        case .resize: "arrow.up.left.and.arrow.down.right"
        case .icons: "app.dashed"
        case .stitch: "rectangle.split.2x1"
        case .ocr: "text.viewfinder"
        case .removeMetadata: "checkmark.shield"
        case .openWith: "square.stack.3d.up"
        case .favoriteLocations: "star"
        }
    }
}

extension FileTool {
    public var menuIconSlot: MenuIconSlot {
        switch self {
        case .copyNames: .copyNames
        case .copyPaths: .copyPaths
        case .copyContents: .copyContents
        case .move: .move
        case .permanentDelete: .permanentDelete
        case .airDrop: .airDrop
        case .desktopAlias: .desktopAlias
        case .batchRename: .batchRename
        case .fileInfo: .fileInfo
        }
    }
}

extension ResourceTool {
    public var menuIconSlot: MenuIconSlot {
        switch self {
        case .convert: .convert
        case .compress: .compress
        case .resize: .resize
        case .icons: .icons
        case .stitch: .stitch
        case .ocr: .ocr
        case .removeMetadata: .removeMetadata
        }
    }
}

extension TemplateCatalog {
    public static func defaultMenuSymbol(forSuffix suffix: String) -> String {
        switch suffix.lowercased() {
        case "txt": "doc.text"
        case "md", "markdown", "docx": "doc.richtext"
        case "csv", "xlsx", "sql": "tablecells"
        case "swift", "json", "html", "css", "sh", "yaml", "xml", "js", "ts", "py": "curlybraces"
        default: "doc"
        }
    }
}

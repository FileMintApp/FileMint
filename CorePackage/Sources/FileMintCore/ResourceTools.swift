import Foundation

public enum ResourceTool: String, Codable, CaseIterable, Identifiable, Sendable {
    case convert, compress, resize, icons, stitch, ocr
    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .convert: "arrow.triangle.2.circlepath"
        case .compress: "arrow.down.right.and.arrow.up.left"
        case .resize: "arrow.up.left.and.arrow.down.right"
        case .icons: "app.dashed"
        case .stitch: "rectangle.split.2x1"
        case .ocr: "text.viewfinder"
        }
    }
    public func title(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .convert: ("Convert Image…", "转换图片格式…")
        case .compress: ("Compress Image…", "压缩图片…")
        case .resize: ("Resize Image…", "调整图片尺寸…")
        case .icons: ("Generate Icons…", "生成图标…")
        case .stitch: ("Stitch Images…", "拼接图片…")
        case .ocr: ("Extract Text…", "提取图片文字…")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }

    public func summary(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .convert: ("JPEG, PNG, HEIC and TIFF", "JPEG、PNG、HEIC、TIFF")
        case .compress: ("Ready for sending and sharing", "让图片更适合发送与分享")
        case .resize: ("Resize a batch, keep proportions", "保留比例，批量统一尺寸")
        case .icons: ("ICNS, ICO and PNG size sets", "ICNS、ICO 与多尺寸 PNG")
        case .stitch: ("Turn several images into one", "把一组图片，拼成一张")
        case .ocr: ("Read editable text from images", "从图片中读出可编辑文字")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}

public struct ResourceToolsPreferences: Codable, Equatable, Sendable {
    public var isEnabled = false
    public var enabledTools = Set(ResourceTool.allCases)
    public init() {}
    private enum CodingKeys: CodingKey { case isEnabled, enabledTools }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = (try? values.decode(Bool.self, forKey: .isEnabled)) ?? false
        if let saved = try? values.decode([String].self, forKey: .enabledTools) {
            enabledTools = Set(saved.compactMap(ResourceTool.init(rawValue:)))
        }
    }
}

public enum ResourceToolsPolicy {
    public static let maximumItems = 100
    public static let maximumInputBytes = 64 * 1024 * 1024
    public static let maximumSourcePixels = 64_000_000
    public static let maximumWorkingPixels = 16_000_000
    public static let maximumDimension = 16_384
    public static let inputExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp", "gif"]

    /// Name-only eligibility is intentionally cheap; the worker validates bytes.
    public static func allowsAppSelection(_ selection: [URL], tool: ResourceTool) -> Bool {
        (1...maximumItems).contains(selection.count) && (tool != .stitch || selection.count > 1) &&
            Set(selection.map { $0.standardizedFileURL }).count == selection.count &&
            selection.allSatisfy { $0.isFileURL && !$0.hasDirectoryPath && inputExtensions.contains($0.pathExtension.lowercased()) }
    }

    public static func availableTools(selection: [URL], isItemMenu: Bool,
                                      preferences: FileMintPreferences) -> [ResourceTool] {
        guard isItemMenu, preferences.resourceTools.isEnabled,
              (1...maximumItems).contains(selection.count),
              Set(selection.map { $0.standardizedFileURL }).count == selection.count,
              selection.allSatisfy({ $0.isFileURL && !$0.hasDirectoryPath &&
                  inputExtensions.contains($0.pathExtension.lowercased()) &&
                  FolderScope.contains($0, in: preferences.monitoredFolderURLs) }) else { return [] }
        return ResourceTool.allCases.filter {
            preferences.resourceTools.enabledTools.contains($0) && ($0 != .stitch || selection.count > 1)
        }
    }

    public static func outputName(stem: String, suffix: String, number: Int = 1) -> String {
        // Leave room for the generated suffix and filesystem UTF-8 name limit.
        var stem = stem
        while stem.utf8.count > 180 { stem.removeLast() }
        let tail = number == 1 ? "" : " \(number)"
        return "\(stem.isEmpty ? "Image" : stem)\(tail).\(suffix)"
    }
}

public enum ResourceError: String, Error, Sendable {
    case invalidSelection, unsupportedImage, multipleFrames, sourceChanged, inputTooLarge
    case dimensionsTooLarge, invalidOptions, unsupportedOutput, encodingFailed, accessDenied
    case noText, textTooLarge, disabled, failed
}

public enum ImageOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg, png, heic, tiff, icns, ico, pngSet
    public var id: String { rawValue }
    public var identifier: String {
        switch self {
        case .jpeg: "public.jpeg"
        case .png, .pngSet: "public.png"
        case .heic: "public.heic"
        case .tiff: "public.tiff"
        case .icns: "com.apple.icns"
        case .ico: "com.microsoft.ico"
        }
    }
    public var suffix: String { self == .jpeg ? "jpg" : rawValue }
    public var isLossy: Bool { self == .jpeg || self == .heic }
    public static let conversions: [Self] = [.jpeg, .png, .heic, .tiff]
    public static let icons: [Self] = [.icns, .ico, .pngSet]
    public var iconSizes: [Int] {
        self == .ico ? [16, 32, 48, 64, 128, 256] : [16, 32, 64, 128, 256, 512, 1024]
    }
}

public struct ImageJobOptions: Equatable, Sendable {
    public var format: ImageOutputFormat = .png
    public var quality: Double = 0.8
    public var longestEdge = 1920
    public var stitchEdge = 1024
    public var horizontal = false
    public init() {}

    public func validate(for tool: ResourceTool) throws {
        guard quality.isFinite, (0...1).contains(quality),
              (1...ResourceToolsPolicy.maximumDimension).contains(longestEdge),
              (1...ResourceToolsPolicy.maximumDimension).contains(stitchEdge) else {
            throw ResourceError.invalidOptions
        }
        if tool == .icons {
            guard ImageOutputFormat.icons.contains(format) else { throw ResourceError.invalidOptions }
        } else if tool == .convert || tool == .resize {
            guard ImageOutputFormat.conversions.contains(format) else { throw ResourceError.invalidOptions }
        }
    }
}

public struct ImageDimensions: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public init(width: Int, height: Int) { self.width = width; self.height = height }
    public func validate(source: Bool = false) throws {
        let limit = source ? ResourceToolsPolicy.maximumSourcePixels : ResourceToolsPolicy.maximumWorkingPixels
        guard width > 0, height > 0, width <= limit / height,
              source || max(width, height) <= ResourceToolsPolicy.maximumDimension else {
            throw ResourceError.dimensionsTooLarge
        }
    }
    public func fitting(longestEdge: Int) throws -> Self {
        try validate(source: true)
        guard (1...ResourceToolsPolicy.maximumDimension).contains(longestEdge) else { throw ResourceError.invalidOptions }
        let scale = min(1, Double(longestEdge) / Double(max(width, height)))
        let size = Self(width: max(1, Int((Double(width) * scale).rounded(.down))),
                        height: max(1, Int((Double(height) * scale).rounded(.down))))
        try size.validate()
        return size
    }
}

public struct ImageStitchLayout: Sendable {
    public let sizes: [ImageDimensions]
    public let canvas: ImageDimensions
    public init(inputs: [ImageDimensions], edge: Int, horizontal: Bool) throws {
        guard (2...ResourceToolsPolicy.maximumItems).contains(inputs.count),
              (1...ResourceToolsPolicy.maximumDimension).contains(edge) else { throw ResourceError.invalidOptions }
        sizes = try inputs.map { input in
            try input.validate(source: true)
            let scale = Double(edge) / Double(horizontal ? input.height : input.width)
            let w = Double(input.width) * scale, h = Double(input.height) * scale
            guard w <= Double(ResourceToolsPolicy.maximumDimension), h <= Double(ResourceToolsPolicy.maximumDimension) else {
                throw ResourceError.dimensionsTooLarge
            }
            let size = ImageDimensions(width: max(1, Int(w.rounded())), height: max(1, Int(h.rounded())))
            try size.validate()
            return size
        }
        canvas = ImageDimensions(width: horizontal ? sizes.reduce(0) { $0 + $1.width } : edge,
                                 height: horizontal ? edge : sizes.reduce(0) { $0 + $1.height })
        try canvas.validate()
    }
}

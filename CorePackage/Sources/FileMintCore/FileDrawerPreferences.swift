import CoreGraphics
import Foundation

public enum FileDrawerSort: String, Codable, CaseIterable, Sendable {
    case name, kind, size, date

    public var defaultAscending: Bool { self == .name || self == .kind }
}

public enum FileDrawerViewMode: String, Codable, CaseIterable, Sendable {
    case icons, list, compact
}

public struct FileDrawerPreferences: Codable, Equatable, Sendable {
    public enum Position: String, Codable, CaseIterable, Sendable {
        case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight

        /// Unit coordinates in the AppKit window, with the origin at bottom left.
        public var anchor: CGPoint {
            switch self {
            case .topLeft: CGPoint(x: 0, y: 1)
            case .top: CGPoint(x: 0.5, y: 1)
            case .topRight: CGPoint(x: 1, y: 1)
            case .left: CGPoint(x: 0, y: 0.5)
            case .right: CGPoint(x: 1, y: 0.5)
            case .bottomLeft: CGPoint(x: 0, y: 0)
            case .bottom: CGPoint(x: 0.5, y: 0)
            case .bottomRight: CGPoint(x: 1, y: 0)
            }
        }

        public var widthDragMultiplier: CGFloat {
            switch anchor.x {
            case 0: 1
            case 1: -1
            default: 2
            }
        }
    }
    public enum Animation: String, Codable, CaseIterable, Sendable { case slide, scale, genie }

    public static let supportedWidths = 240.0...2_000.0
    public static let supportedHeights = 480.0...4_320.0

    public var enabled = false
    public var defaultDirectoryPath: String?
    public var remembersLastLocation = true
    public var shortcut = GlobalShortcutPreferences(isEnabled: true, combination: .suggestedDrawer)
    public var effectiveShortcut: GlobalShortcutPreferences {
        .init(isEnabled: enabled && shortcut.isEnabled, combination: shortcut.combination)
    }
    public var autoPreview = false
    public var showsShortcutHints = true
    public var viewMode: FileDrawerViewMode = .list
    public var sort: FileDrawerSort = .name
    public var sortAscending = true
    public var position: Position = .right
    public var animation: Animation = .genie
    public var glass = true
    public var transparency = 0.3
    public var minimumWidth = 320.0
    public var maximumWidth = 640.0
    public var width = 520.0
    public var fitsDisplayWidth = true
    public var fitsDisplayHeight = true
    public var minimumHeight = 480.0
    public var maximumHeight = 1_100.0
    public var height = 640.0

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case enabled, remembersLastLocation, shortcut, autoPreview, showsShortcutHints, viewMode, sort, sortAscending
        case position = "side"
        case animation, glass, transparency, minimumWidth, maximumWidth, width, fitsDisplayWidth
        case fitsDisplayHeight, minimumHeight, maximumHeight, height
        case defaultDirectoryPath = "rootDirectoryPath"
    }

    public var hasValidWidthLimits: Bool {
        Self.supportedWidths.contains(minimumWidth) && Self.supportedWidths.contains(maximumWidth)
            && minimumWidth <= maximumWidth
    }

    public var hasValidHeightLimits: Bool {
        Self.supportedHeights.contains(minimumHeight) && Self.supportedHeights.contains(maximumHeight)
            && minimumHeight <= maximumHeight
    }

    /// A temporarily smaller screen does not replace the user's preferred width.
    public func effectiveWidth(availableWidth: Double) -> Double {
        min(max(0, availableWidth), min(max(width, minimumWidth), maximumWidth))
    }

    public func panelFrame(in visible: CGRect) -> CGRect {
        let margin = min(6, visible.width / 2, visible.height / 2)
        let available = visible.insetBy(dx: margin, dy: margin)
        var sized = self
        if fitsDisplayWidth { sized.width = (visible.width * 520 / 1_440).rounded() }
        let width = sized.effectiveWidth(availableWidth: available.width)
        let desiredHeight = fitsDisplayHeight ? (visible.height * 0.72).rounded() : self.height
        let height = min(available.height, min(max(desiredHeight, minimumHeight), maximumHeight))
        let anchor = position.anchor
        return CGRect(x: available.minX + anchor.x * (available.width - width),
                      y: available.minY + anchor.y * (available.height - height), width: width, height: height)
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? fields.decode(Bool.self, forKey: .enabled)) ?? enabled
        if let path = try? fields.decode(String.self, forKey: .defaultDirectoryPath),
           path.hasPrefix("/"), !path.utf8.contains(0) {
            defaultDirectoryPath = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        }
        remembersLastLocation = (try? fields.decode(Bool.self, forKey: .remembersLastLocation)) ?? remembersLastLocation
        if fields.contains(.shortcut) {
            shortcut = (try? fields.decode(GlobalShortcutPreferences.self, forKey: .shortcut)) ?? .init()
        }
        autoPreview = (try? fields.decode(Bool.self, forKey: .autoPreview)) ?? autoPreview
        showsShortcutHints = (try? fields.decode(Bool.self, forKey: .showsShortcutHints)) ?? showsShortcutHints
        viewMode = (try? fields.decode(FileDrawerViewMode.self, forKey: .viewMode)) ?? viewMode
        sort = (try? fields.decode(FileDrawerSort.self, forKey: .sort)) ?? sort
        sortAscending = (try? fields.decode(Bool.self, forKey: .sortAscending)) ?? sort.defaultAscending
        position = (try? fields.decode(Position.self, forKey: .position)) ?? position
        animation = (try? fields.decode(Animation.self, forKey: .animation)) ?? animation
        glass = (try? fields.decode(Bool.self, forKey: .glass)) ?? glass
        if let value = try? fields.decode(Double.self, forKey: .transparency), (0...1).contains(value) {
            transparency = value
        }
        let defaults = FileDrawerPreferences()
        if let value = try? fields.decode(Double.self, forKey: .minimumWidth), Self.supportedWidths.contains(value) {
            minimumWidth = value
        }
        if let value = try? fields.decode(Double.self, forKey: .maximumWidth), Self.supportedWidths.contains(value) {
            maximumWidth = value
        }
        if !hasValidWidthLimits {
            minimumWidth = defaults.minimumWidth
            maximumWidth = defaults.maximumWidth
        }
        if let value = try? fields.decode(Double.self, forKey: .width), value.isFinite { width = value }
        if let value = try? fields.decode(Bool.self, forKey: .fitsDisplayWidth) {
            fitsDisplayWidth = value
        } else if !fields.contains(.fitsDisplayWidth), Self.supportedWidths.contains(width), width != defaults.width {
            // A customized width saved before the switch existed was fixed.
            fitsDisplayWidth = false
        }
        width = effectiveWidth(availableWidth: maximumWidth)
        fitsDisplayHeight = (try? fields.decode(Bool.self, forKey: .fitsDisplayHeight)) ?? fitsDisplayHeight
        if let value = try? fields.decode(Double.self, forKey: .height), Self.supportedHeights.contains(value) {
            height = value
        }
        if let value = try? fields.decode(Double.self, forKey: .minimumHeight), Self.supportedHeights.contains(value) {
            minimumHeight = value
        }
        if let value = try? fields.decode(Double.self, forKey: .maximumHeight), Self.supportedHeights.contains(value) {
            maximumHeight = value
        } else if !fields.contains(.maximumHeight) {
            maximumHeight = max(maximumHeight, height)
        }
        if !hasValidHeightLimits {
            minimumHeight = defaults.minimumHeight
            maximumHeight = max(defaults.maximumHeight, height)
        }
        height = min(max(height, minimumHeight), maximumHeight)
    }
}

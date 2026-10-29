import Foundation

/// Physical macOS key code and the four supported modifier bits. No event APIs
/// belong in Core; the app alone validates/registers the system combination.
public struct GlobalShortcut: Codable, Equatable, Hashable, Sendable {
    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12
    public static let suggested = Self(keyCode: 40, modifiers: control | option)
    public let keyCode: UInt32
    public let modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var isValid: Bool {
        let supported = Self.command | Self.shift | Self.option | Self.control
        return keyCode < 128 && modifiers & (Self.command | Self.control) != 0
            && modifiers & ~supported == 0
            && ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 72, 73, 74].contains(keyCode)
    }
}

public struct GlobalShortcutPreferences: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var combination: GlobalShortcut?
    public var effectiveCombination: GlobalShortcut? {
        isEnabled && combination?.isValid == true ? combination : nil
    }

    public init(isEnabled: Bool = false, combination: GlobalShortcut? = nil) {
        self.isEnabled = isEnabled
        self.combination = combination?.isValid == true ? combination : nil
    }

    private enum CodingKeys: String, CodingKey { case isEnabled, combination }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = (try? values.decode(Bool.self, forKey: .isEnabled)) ?? false
        let key = try? values.decode(GlobalShortcut.self, forKey: .combination)
        combination = key?.isValid == true ? key : nil
    }
}

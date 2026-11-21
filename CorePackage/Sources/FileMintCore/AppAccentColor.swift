import Foundation

public enum AppAccentColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case mint, blue, purple, amber, teal, indigo, moss, coral, rose, slate, custom

    public var id: String { rawValue }

    public var title: FileMintTextKey {
        switch self {
        case .mint: .mintAccent
        case .blue: .blueAccent
        case .purple: .purpleAccent
        case .amber: .amberAccent
        case .teal: .tealAccent
        case .indigo: .indigoAccent
        case .moss: .mossAccent
        case .coral: .coralAccent
        case .rose: .roseAccent
        case .slate: .slateAccent
        case .custom: .customAccent
        }
    }

    public static func parseCustomRGB(_ text: String) -> UInt32? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.hasPrefix("#") ? trimmed.dropFirst() : trimmed[...]
        guard digits.utf8.count == 6,
              digits.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
        return UInt32(digits, radix: 16)
    }
}

public struct AppAccentPalette: Equatable, Sendable {
    public let accent: UInt32
    public let selection: UInt32
    public let strong: UInt32
    public let onStrong: UInt32

    public init(rgb: UInt32, dark: Bool) {
        let surface: UInt32 = dark ? 0x2B302D : 0xFBFBFA
        let soft: UInt32 = dark ? surface : 0xF1F3EF
        let direction: UInt32 = dark ? 0xFFFFFF : 0x000000
        selection = Self.mix(surface, toward: rgb, fraction: dark ? 0.24 : 0.14)
        // Use the least favorable surface for foregrounds, including selected rows.
        let surfaceLight = Self.luminance(soft)
        let selectionLight = Self.luminance(selection)
        let backgroundLight = dark ? max(surfaceLight, selectionLight) : min(surfaceLight, selectionLight)
        var adjusted = rgb
        for percent in stride(from: 0, through: 100, by: 5) {
            adjusted = Self.mix(rgb, toward: direction, fraction: Double(percent) / 100)
            let foregroundLight = Self.luminance(adjusted)
            if (max(foregroundLight, backgroundLight) + 0.05) / (min(foregroundLight, backgroundLight) + 0.05) >= 4.5 {
                break
            }
        }
        accent = adjusted
        strong = Self.mix(adjusted, toward: direction, fraction: 0.20)
        onStrong = dark ? 0x171717 : 0xFFFFFF
    }

    private static func mix(_ rgb: UInt32, toward target: UInt32, fraction: Double) -> UInt32 {
        var result: UInt32 = 0
        for shift in [16, 8, 0] {
            let source = Double((rgb >> shift) & 255)
            let destination = Double((target >> shift) & 255)
            result |= UInt32((source + (destination - source) * fraction).rounded()) << shift
        }
        return result
    }

    private static func luminance(_ rgb: UInt32) -> Double {
        func linear(_ shift: Int) -> Double {
            let channel = Double((rgb >> shift) & 255) / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0)
    }
}

import Foundation

public enum RenameItemKind: String, Sendable {
    case file
    case directory
}

/// The original spelling and its protected parts are captured once per session.
public struct RenameNameParts: Sendable {
    public let originalName: String
    public let hiddenMarker: String
    public let body: String
    public let suffix: String
    public let kind: RenameItemKind

    fileprivate init(originalName: String, hiddenMarker: String, body: String,
                     suffix: String, kind: RenameItemKind) {
        self.originalName = originalName
        self.hiddenMarker = hiddenMarker
        self.body = body
        self.suffix = suffix
        self.kind = kind
    }
}

public enum RenameNameError: Error, Equatable, Sendable {
    case invalidComponent
    case originalNameTooLong
    case emptyBody
    case hiddenStatusChange
    case extensionChange
    case leadingOrTrailingWhitespace
    case trailingPeriod
    case invalidCharacter
    case outputNameTooLong(limit: Int)
}

/// Pure rename rules. This policy does not sanitize names or inspect the filesystem.
public enum RenameNamePolicy {
    private static let comparisonLocale = Locale(identifier: "en_US_POSIX")
    private static let compoundSuffixes = [".tar.bz2", ".tar.gz", ".tar.xz", ".tar.zst", ".d.ts"]

    public static func split(_ original: String, kind: RenameItemKind) throws -> RenameNameParts {
        try validateRestorationComponent(original)
        guard original.utf8.count <= 1_024 else { throw RenameNameError.originalNameTooLong }

        // A period can share a grapheme cluster with a combining scalar. Remove
        // exactly the leading scalar, not the whole first Character.
        let hasMarker = original.unicodeScalars.first?.value == 0x2E
        let remaining = hasMarker ? String(original.unicodeScalars.dropFirst()) : original
        var body = remaining
        var suffix = ""

        if kind == .file {
            let matches = compoundSuffixes.compactMap { candidate -> Range<String.Index>? in
                remaining.range(of: candidate, options: [.caseInsensitive, .anchored, .backwards],
                                locale: comparisonLocale)
            }.filter { $0.lowerBound != remaining.startIndex }
            if let match = matches.max(by: {
                remaining[$0].utf8.count < remaining[$1].utf8.count
            }) {
                body = String(remaining[..<match.lowerBound])
                suffix = String(remaining[match])
            } else if let period = remaining.unicodeScalars.lastIndex(where: { $0.value == 0x2E }) {
                let afterPeriod = remaining.unicodeScalars.index(after: period)
                if period != remaining.startIndex && afterPeriod != remaining.endIndex {
                    body = String(remaining[..<period])
                    suffix = String(remaining[period...])
                }
            }
        }
        return RenameNameParts(originalName: original, hiddenMarker: hasMarker ? "." : "",
                               body: body, suffix: suffix, kind: kind)
    }

    public static func output(body: String, parts: RenameNameParts,
                              nativeNameByteLimit: Int? = nil) throws -> String {
        // Swift String equality is canonically equivalent. Only identical UTF-8
        // qualifies for the original-name exemption.
        if body.utf8.elementsEqual(parts.body.utf8) { return parts.originalName }

        guard !body.isEmpty else { throw RenameNameError.emptyBody }
        guard body.unicodeScalars.first?.value != 0x2E else { throw RenameNameError.hiddenStatusChange }
        if parts.kind == .file && parts.suffix.isEmpty && body.utf8.contains(0x2E) {
            throw RenameNameError.extensionChange
        }

        let name = parts.hiddenMarker + body + parts.suffix
        try validateRestorationComponent(name)
        if name.unicodeScalars.first?.properties.isWhitespace == true ||
            name.unicodeScalars.last?.properties.isWhitespace == true {
            throw RenameNameError.leadingOrTrailingWhitespace
        }
        guard name.unicodeScalars.last?.value != 0x2E else { throw RenameNameError.trailingPeriod }
        guard !name.unicodeScalars.contains(where: { scalar in
            scalar.value == 0x2F || scalar.value == 0x3A || scalar.value == 0x5C ||
            scalar.properties.generalCategory == .control ||
            scalar.properties.generalCategory == .lineSeparator ||
            scalar.properties.generalCategory == .paragraphSeparator
        }) else { throw RenameNameError.invalidCharacter }

        let nativeLimit = nativeNameByteLimit.flatMap { $0 > 0 ? $0 : nil }
        let limit = min(255, nativeLimit ?? 255)
        guard name.utf8.count <= limit else { throw RenameNameError.outputNameTooLong(limit: limit) }
        return name
    }

    /// Restoration accepts an exact previously captured component, including
    /// old spellings that would fail every stricter new-output rule.
    public static func validateRestorationComponent(_ name: String) throws {
        guard !name.isEmpty, !name.utf8.contains(0), !name.utf8.contains(0x2F),
              !name.utf8.elementsEqual([0x2E]), !name.utf8.elementsEqual([0x2E, 0x2E]) else {
            throw RenameNameError.invalidComponent
        }
    }

    /// A conservative namespace precheck, not an emulation of APFS lookup.
    public static func namespaceKey(_ name: String, caseSensitive: Bool) -> Data {
        let decomposed = name.decomposedStringWithCanonicalMapping
        let folded = caseSensitive ? decomposed :
            decomposed.folding(options: [.caseInsensitive], locale: comparisonLocale)
        return Data(folded.decomposedStringWithCanonicalMapping.utf8)
    }

    public static func compareOriginalNames(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let natural = lhs.compare(rhs, options: [.numeric, .caseInsensitive], locale: comparisonLocale)
        guard natural == .orderedSame else { return natural }
        if lhs.utf8.elementsEqual(rhs.utf8) { return .orderedSame }
        return lhs.utf8.lexicographicallyPrecedes(rhs.utf8) ? .orderedAscending : .orderedDescending
    }
}

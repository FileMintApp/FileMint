import CoreFoundation
import Foundation

public enum BatchRenameRule: Equatable, Sendable {
    case replace(search: String, replacement: String)
    case prepend(String)
    case append(String)
    case number(BatchRenameNumbering)
    case uppercase
    case lowercase

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.replace(leftSearch, leftReplacement), .replace(rightSearch, rightReplacement)):
            leftSearch.utf8.elementsEqual(rightSearch.utf8)
                && leftReplacement.utf8.elementsEqual(rightReplacement.utf8)
        case let (.prepend(left), .prepend(right)), let (.append(left), .append(right)):
            left.utf8.elementsEqual(right.utf8)
        case let (.number(left), .number(right)):
            left == right
        case (.uppercase, .uppercase), (.lowercase, .lowercase):
            true
        default:
            false
        }
    }
}

public struct BatchRenameNumbering: Equatable, Sendable {
    public enum Position: Equatable, Sendable {
        case before
        case after
    }

    public enum Body: Equatable, Sendable {
        case current
        case unified(String)

        public static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.current, .current): true
            case let (.unified(left), .unified(right)): left.utf8.elementsEqual(right.utf8)
            default: false
            }
        }
    }

    public var start: Int64
    public var step: Int64
    public var width: Int
    public var separator: String
    public var position: Position
    public var body: Body

    public init(
        start: Int64 = 1,
        step: Int64 = 1,
        width: Int = 3,
        separator: String = "_",
        position: Position = .after,
        body: Body = .current
    ) {
        self.start = start
        self.step = step
        self.width = width
        self.separator = separator
        self.position = position
        self.body = body
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.start == rhs.start && lhs.step == rhs.step && lhs.width == rhs.width
            && lhs.separator.utf8.elementsEqual(rhs.separator.utf8)
            && lhs.position == rhs.position && lhs.body == rhs.body
    }
}

public enum BatchRenameRuleError: Error, Equatable, Sendable {
    case invalidRowCount
    case invalidSortedOrdinal
    case tooManyRules
    case emptySearch(ruleIndex: Int)
    case literalTooLong(ruleIndex: Int)
    case invalidNumbering(ruleIndex: Int)
    case numberingOverflow(ruleIndex: Int)
    /// A nil index identifies an oversized input, before applying any rule.
    case workingBodyTooLong(ruleIndex: Int?)
}

/// Pure body transformations. The name policy validates the final component;
/// temporary empty bodies and filename-invalid characters are not repaired here.
public enum BatchRenameRuleEngine {
    public static let maximumRuleCount = 32
    public static let maximumLiteralUTF8Bytes = 1_024
    public static let maximumWorkingBodyUTF8Bytes = 4_096
    public static let maximumRowCount = 1_000

    /// Checks every parameter and the last row's numbering, even when an earlier
    /// row would be unchanged. The planner owns the two-item selection minimum.
    public static func validate(_ rules: [BatchRenameRule], rowCount: Int) throws {
        guard (1...maximumRowCount).contains(rowCount) else {
            throw BatchRenameRuleError.invalidRowCount
        }
        guard rules.count <= maximumRuleCount else {
            throw BatchRenameRuleError.tooManyRules
        }

        for (index, rule) in rules.enumerated() {
            switch rule {
            case let .replace(search, replacement):
                guard !search.isEmpty else {
                    throw BatchRenameRuleError.emptySearch(ruleIndex: index)
                }
                try validateLiteral(search, ruleIndex: index)
                try validateLiteral(replacement, ruleIndex: index)
            case let .prepend(text), let .append(text):
                try validateLiteral(text, ruleIndex: index)
            case let .number(numbering):
                guard numbering.start >= 0, numbering.step >= 1,
                      (1...20).contains(numbering.width) else {
                    throw BatchRenameRuleError.invalidNumbering(ruleIndex: index)
                }
                try validateLiteral(numbering.separator, ruleIndex: index)
                if case let .unified(body) = numbering.body {
                    try validateLiteral(body, ruleIndex: index)
                }
                _ = try numberValue(numbering, ordinal: rowCount - 1, ruleIndex: index)
            case .uppercase, .lowercase:
                break
            }
        }
    }

    public static func apply(
        _ rules: [BatchRenameRule],
        to originalBody: String,
        sortedOrdinal: Int,
        rowCount: Int
    ) throws -> String {
        try validate(rules, rowCount: rowCount)
        guard (0..<rowCount).contains(sortedOrdinal) else {
            throw BatchRenameRuleError.invalidSortedOrdinal
        }
        try validateWorkingSize(originalBody.utf8.count, ruleIndex: nil)

        var body = originalBody
        for (index, rule) in rules.enumerated() {
            switch rule {
            case let .replace(search, replacement):
                body = try replacing(search, with: replacement, in: body, ruleIndex: index)
            case let .prepend(text):
                try validateWorkingSize(text.utf8.count + body.utf8.count, ruleIndex: index)
                body = text + body
            case let .append(text):
                try validateWorkingSize(body.utf8.count + text.utf8.count, ruleIndex: index)
                body += text
            case let .number(numbering):
                body = try numbered(body, with: numbering, ordinal: sortedOrdinal, ruleIndex: index)
            case .uppercase:
                body = try changingCase(body, uppercase: true, ruleIndex: index)
            case .lowercase:
                body = try changingCase(body, uppercase: false, ruleIndex: index)
            }
        }
        return body
    }

    private static func validateLiteral(_ literal: String, ruleIndex: Int) throws {
        guard literal.utf8.count <= maximumLiteralUTF8Bytes else {
            throw BatchRenameRuleError.literalTooLong(ruleIndex: ruleIndex)
        }
    }

    private static func validateWorkingSize(_ bytes: Int, ruleIndex: Int?) throws {
        guard bytes <= maximumWorkingBodyUTF8Bytes else {
            throw BatchRenameRuleError.workingBodyTooLong(ruleIndex: ruleIndex)
        }
    }

    private static func numberValue(
        _ numbering: BatchRenameNumbering,
        ordinal: Int,
        ruleIndex: Int
    ) throws -> Int64 {
        let (offset, multiplyOverflow) = Int64(ordinal).multipliedReportingOverflow(by: numbering.step)
        let (value, addOverflow) = numbering.start.addingReportingOverflow(offset)
        guard !multiplyOverflow, !addOverflow else {
            throw BatchRenameRuleError.numberingOverflow(ruleIndex: ruleIndex)
        }
        return value
    }

    private static func numbered(
        _ currentBody: String,
        with numbering: BatchRenameNumbering,
        ordinal: Int,
        ruleIndex: Int
    ) throws -> String {
        let value = try numberValue(numbering, ordinal: ordinal, ruleIndex: ruleIndex)
        let body: String
        switch numbering.body {
        case .current: body = currentBody
        case let .unified(text): body = text
        }

        var digitCount = 1
        var remaining = value
        while remaining >= 10 {
            remaining /= 10
            digitCount += 1
        }
        let paddedCount = max(digitCount, numbering.width)
        let size = body.isEmpty ? paddedCount : body.utf8.count + numbering.separator.utf8.count + paddedCount
        try validateWorkingSize(size, ruleIndex: ruleIndex)

        let digits = String(repeating: "0", count: paddedCount - digitCount) + String(value)
        guard !body.isEmpty else { return digits }
        switch numbering.position {
        case .before: return digits + numbering.separator + body
        case .after: return body + numbering.separator + digits
        }
    }

    private static func replacing(
        _ search: String,
        with replacement: String,
        in body: String,
        ruleIndex: Int
    ) throws -> String {
        // UTF-8 exact matching is scalar-exact for valid Swift strings, including
        // matches inside a grapheme cluster. It never equates NFC and NFD text.
        let source = Array(body.utf8)
        let pattern = Array(search.utf8)
        guard pattern.count <= source.count else { return body }
        let inserted = Array(replacement.utf8)
        var prefix = [Int](repeating: 0, count: pattern.count)
        var matched = 0
        for index in 1..<pattern.count {
            while matched > 0, pattern[index] != pattern[matched] {
                matched = prefix[matched - 1]
            }
            if pattern[index] == pattern[matched] { matched += 1 }
            prefix[index] = matched
        }

        var starts: [Int] = []
        var size = source.count
        matched = 0
        for index in source.indices {
            while matched > 0, source[index] != pattern[matched] {
                matched = prefix[matched - 1]
            }
            if source[index] == pattern[matched] { matched += 1 }
            if matched == pattern.count {
                starts.append(index + 1 - pattern.count)
                size += inserted.count - pattern.count
                // Every match has the same size delta. Once an expanding rule
                // exceeds the budget, later matches cannot make it fit again.
                try validateWorkingSize(size, ruleIndex: ruleIndex)
                matched = 0 // Consume the match; overlaps are never reused.
            }
        }
        guard !starts.isEmpty else { return body }

        var result: [UInt8] = []
        result.reserveCapacity(size)
        var cursor = 0
        for start in starts {
            result.append(contentsOf: source[cursor..<start])
            result.append(contentsOf: inserted)
            cursor = start + pattern.count
        }
        result.append(contentsOf: source[cursor...])
        return String(decoding: result, as: UTF8.self)
    }

    private static func changingCase(_ body: String, uppercase: Bool, ruleIndex: Int) throws -> String {
        // Budget the default Unicode mapping without constructing the combined
        // output. Its only language-independent contextual mapping is Final_Sigma;
        // final/non-final sigma have the same UTF-8 length. Locale-specific
        // Turkish/Azeri/Lithuanian tailoring is intentionally not used.
        // See Unicode SpecialCasing.txt, Language-Insensitive Mappings.
        var size = 0
        for scalar in body.unicodeScalars {
            let mapped = defaultCaseMapping(String(scalar), uppercase: uppercase)
            size += mapped.utf8.count
            try validateWorkingSize(size, ruleIndex: ruleIndex)
        }
        // Map the whole string after budgeting to retain word-final sigma.
        let result = defaultCaseMapping(body, uppercase: uppercase)
        try validateWorkingSize(result.utf8.count, ruleIndex: ruleIndex)
        return result
    }

    private static func defaultCaseMapping(_ text: String, uppercase: Bool) -> String {
        let mutable = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, text as CFString)!
        // CoreFoundation's nil locale selects no language tailoring; it does
        // not resolve the user's locale. Its lowercase path still applies the
        // contextual Final_Sigma rule. Keep budgeting on this same API path.
        // Apple CFString.c: _CFCanUseLocale, CFStringUppercase/CFStringLowercase.
        if uppercase {
            CFStringUppercase(mutable, nil)
        } else {
            CFStringLowercase(mutable, nil)
        }
        return mutable as String
    }
}

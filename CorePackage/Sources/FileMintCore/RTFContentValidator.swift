import Foundation

/// An intentionally small RTF language, not a renderer. Every accepted token has
/// a known text effect; unknown destinations cannot silently discard body text.
enum RTFContentValidator {
    static func text(in data: Data) throws -> String {
        guard data.count <= FileContentCopyPolicy.maximumBytes else { throw FileContentCopyError.tooLarge }
        var parser = Parser(bytes: Array(data))
        return try parser.parse()
    }

    private enum Destination: Hashable { case body, fonts, colors, expandedColors }
    private struct State {
        var destination = Destination.body
        var unicodeFallback = 1
    }
    private struct GroupFrame {
        var state: State
        var atStart = true
        var starred = false
        var colorChannels = Set<String>()
        var expandedChannels: Int?
        var expandedCount = 0
    }
    private enum Control {
        case word(String, Int?), byte(UInt8), symbol(UInt8)
    }

    private struct Parser {
        let bytes: [UInt8]
        var index = 0
        var codePage = 1252
        var headerOpen = true
        var headerWords = Set<String>()
        var tables = Set<Destination>()
        var pendingHighSurrogate: UInt16?
        var fontNameStarted = false
        var fontNameHasContent = false
        var output = ""
        var outputBytes = 0

        mutating func parse() throws -> String {
            guard bytes.first == 123 else { throw FileContentCopyError.invalidRTF }
            index = 1
            guard case .word("rtf", 1) = try control() else { throw FileContentCopyError.invalidRTF }
            try groups()
            guard bytes[index...].allSatisfy({ [9, 10, 13, 32].contains($0) }) else {
                throw FileContentCopyError.invalidRTF
            }
            try FileContentCopyPolicy.validateText(output)
            return output
        }

        /// Explicit frames bound nesting without consuming a thread's call
        /// stack. Each frame owns its uc and metadata state until its closing brace.
        mutating func groups() throws {
            var frames = [GroupFrame(state: State(), atStart: false)]
            while !frames.isEmpty {
                guard index < bytes.count else { throw FileContentCopyError.invalidRTF }
                var frame = frames.removeLast()
                let depth = frames.count + 1
                var keepFrame = true
                defer { if keepFrame { frames.append(frame) } }
                let byte = bytes[index]
                if byte == 10 || byte == 13 { index += 1; continue }
                if byte == 125 {
                    guard !frame.starred, pendingHighSurrogate == nil, frame.colorChannels.isEmpty,
                          frame.expandedChannels == nil else { throw FileContentCopyError.invalidRTF }
                    index += 1
                    keepFrame = false
                    continue
                }
                if byte == 123 {
                    guard !frame.starred, pendingHighSurrogate == nil, frame.state.destination == .body else {
                        throw FileContentCopyError.invalidRTF
                    }
                    guard depth < 128 else { throw FileContentCopyError.invalidRTF }
                    index += 1
                    frame.atStart = false
                    frames.append(frame)
                    frames.append(GroupFrame(state: frame.state))
                    keepFrame = false
                    continue
                }
                if byte != 92 {
                    guard !frame.starred else { throw FileContentCopyError.invalidRTF }
                    frame.atStart = false
                    index += 1
                    switch frame.state.destination {
                    case .body:
                        try appendByte(byte, to: frame.state.destination)
                    case .fonts: throw FileContentCopyError.invalidRTF
                    case .colors:
                        guard byte == 59 || byte == 32 else { throw FileContentCopyError.invalidRTF }
                        if byte == 59 { frame.colorChannels.removeAll() }
                    case .expandedColors:
                        guard byte == 59 || byte == 32 else { throw FileContentCopyError.invalidRTF }
                        if byte == 59 {
                            guard frame.expandedChannels == nil || frame.expandedChannels == frame.expandedCount else {
                                throw FileContentCopyError.invalidRTF
                            }
                            frame.expandedChannels = nil; frame.expandedCount = 0
                        }
                    }
                    continue
                }
                let token = try control()
                if case .symbol(42) = token {
                    guard frame.atStart, !frame.starred, depth == 2, frame.state.destination == .body,
                          headerOpen else { throw FileContentCopyError.invalidRTF }
                    frame.starred = true
                    continue
                }
                if case let .word(word, value) = token,
                   let destination = Self.destination(word) {
                    guard frame.atStart, depth == 2, frame.state.destination == .body, headerOpen,
                          value == nil, !tables.contains(destination),
                          !frame.starred || destination == .expandedColors else { throw FileContentCopyError.invalidRTF }
                    tables.insert(destination)
                    frame.state.destination = destination; frame.atStart = false; frame.starred = false
                    if destination == .fonts {
                        try fontTable(frame.state)
                        keepFrame = false
                    }
                    continue
                }
                guard !frame.starred else { throw FileContentCopyError.invalidRTF }
                frame.atStart = false
                if case let .word(word, value) = token {
                    if word == "u" || word == "uc" {
                        guard frame.state.destination == .body else {
                            throw FileContentCopyError.invalidRTF
                        }
                        if word == "uc" {
                            guard pendingHighSurrogate == nil else { throw FileContentCopyError.invalidRTF }
                            frame.state.unicodeFallback = try parameter(value, in: 0...1)
                        } else {
                            let number = try parameter(value, in: -32768...65535)
                            try appendUnicode(UInt16(truncatingIfNeeded: number), to: frame.state.destination)
                            if frame.state.unicodeFallback == 1 { try fallback() }
                        }
                        continue
                    }
                    guard pendingHighSurrogate == nil else { throw FileContentCopyError.invalidRTF }
                    switch frame.state.destination {
                    case .body:
                        try bodyControl(word, value, depth: depth)
                    case .fonts: throw FileContentCopyError.invalidRTF
                    case .colors:
                        guard ["red", "green", "blue"].contains(word), !frame.colorChannels.contains(word) else {
                            throw FileContentCopyError.invalidRTF
                        }
                        _ = try parameter(value, in: 0...255)
                        frame.colorChannels.insert(word)
                    case .expandedColors:
                        if word == "c" {
                            guard let count = frame.expandedChannels, frame.expandedCount < count else {
                                throw FileContentCopyError.invalidRTF
                            }
                            _ = try parameter(value, in: 0...100000); frame.expandedCount += 1
                        } else {
                            guard value == nil, frame.expandedChannels == nil,
                                  ["csgray", "cssrgb", "csgenericrgb"].contains(word) else {
                                throw FileContentCopyError.invalidRTF
                            }
                            frame.expandedChannels = word == "csgray" ? 1 : 3
                        }
                    }
                } else {
                    guard frame.state.destination == .body else {
                        throw FileContentCopyError.invalidRTF
                    }
                    switch token {
                    case let .byte(value): try appendByte(value, to: frame.state.destination)
                    case let .symbol(value):
                        let scalar: UInt32
                        switch value {
                        case 92, 123, 125: scalar = UInt32(value)
                        case 126: scalar = 0xA0
                        case 95: scalar = 0x2011
                        case 10, 13: scalar = 10
                        default: throw FileContentCopyError.invalidRTF
                        }
                        try append(scalar, to: frame.state.destination)
                    case .word: throw FileContentCopyError.invalidRTF
                    }
                }
            }
        }

        static func destination(_ word: String) -> Destination? {
            switch word {
            case "fonttbl": .fonts
            case "colortbl": .colors
            case "expandedcolortbl": .expandedColors
            default: nil
            }
        }

        mutating func bodyControl(_ word: String, _ value: Int?, depth: Int) throws {
            let header: Set<String> = ["ansi", "ansicpg", "deff", "deflang", "deflangfe", "deftab",
                "cocoartf", "cocoatextscaling", "cocoaplatform", "vieww", "viewh", "viewkind",
                "paperw", "paperh", "margl", "margr", "margt", "margb", "widowctrl"]
            if header.contains(word) {
                guard depth == 1, headerOpen, !headerWords.contains(word) else {
                    throw FileContentCopyError.invalidRTF
                }
                headerWords.insert(word)
                switch word {
                case "ansi": try noParameter(value)
                case "ansicpg": codePage = try parameter(value, in: 1...65535)
                case "deff": _ = try parameter(value, in: 0...32767)
                case "deflang", "deflangfe": _ = try parameter(value, in: 0...65535)
                case "paperw", "paperh": _ = try parameter(value, in: 1...Int(Int32.max))
                case "viewkind": _ = try parameter(value, in: 0...5)
                case "widowctrl": try toggle(value)
                default: _ = try parameter(value, in: 0...Int(Int32.max))
                }
                return
            }
            headerOpen = false
            let characters: [String: UInt32] = ["par": 10, "line": 0x2028, "tab": 9,
                "emdash": 0x2014, "endash": 0x2013, "emspace": 0x2003, "enspace": 0x2002,
                "bullet": 0x2022, "lquote": 0x2018, "rquote": 0x2019,
                "ldblquote": 0x201C, "rdblquote": 0x201D]
            if let scalar = characters[word] {
                try noParameter(value); try append(scalar, to: .body); return
            }
            switch word {
            case "b", "i", "ul", "uldb", "uld", "uldash", "ulwave", "strike", "noproof", "widctlpar":
                try toggle(value)
            case "plain", "pard", "ulnone", "super", "sub", "nosupersub", "ql", "qr", "qc", "qj",
                 "ltrch", "rtlch", "ltrpar", "rtlpar", "pardirnatural", "nowidctlpar",
                 "tql", "tqr", "tqc", "tqdec", "tldot", "tlhyph", "tlul", "tlth", "tleq":
                try noParameter(value)
            case "f", "cf", "cb", "highlight", "up", "dn", "kerning", "tx":
                _ = try parameter(value, in: 0...32767)
            case "fs": _ = try parameter(value, in: 1...32767)
            case "lang", "langfe": _ = try parameter(value, in: 0...65535)
            case "fi", "li", "ri", "sb", "sa", "sl", "expnd", "expndtw", "partightenfactor":
                _ = try parameter(value, in: -32768...32767)
            case "slmult": _ = try parameter(value, in: 0...1)
            default: throw FileContentCopyError.invalidRTF
            }
        }

        /// Font metadata has its own grammar: either flat entries, or one group
        /// per entry. Every fN declaration needs a name and a final semicolon.
        mutating func fontTable(_ inherited: State) throws {
            var identifiers = Set<Int>()
            var grouped = false
            while index < bytes.count {
                let byte = bytes[index]
                if [9, 10, 13, 32].contains(byte) { index += 1; continue }
                if byte == 123 {
                    grouped = true; index += 1
                    try fontEntries(inherited, single: true, identifiers: &identifiers)
                } else if byte == 92, !grouped {
                    try fontEntries(inherited, single: false, identifiers: &identifiers)
                    return
                } else if byte == 125, grouped, !identifiers.isEmpty {
                    index += 1
                    return
                } else { throw FileContentCopyError.invalidRTF }
            }
            throw FileContentCopyError.invalidRTF
        }

        mutating func fontEntries(_ inherited: State, single: Bool, identifiers: inout Set<Int>) throws {
            var state = inherited
            var active = false
            var completed = 0
            while index < bytes.count {
                let byte = bytes[index]
                if byte == 10 || byte == 13 { index += 1; continue }
                if byte == 125 {
                    guard !active, completed > 0, !single || completed == 1,
                          pendingHighSurrogate == nil else { throw FileContentCopyError.invalidRTF }
                    index += 1
                    return
                }
                guard byte != 123 else { throw FileContentCopyError.invalidRTF }
                if byte != 92 {
                    index += 1
                    if !active, byte == 32 || byte == 9 { continue }
                    guard active else { throw FileContentCopyError.invalidRTF }
                    if byte == 59 {
                        guard fontNameHasContent, pendingHighSurrogate == nil else { throw FileContentCopyError.invalidRTF }
                        active = false; completed += 1
                    } else { try appendByte(byte, to: .fonts) }
                    continue
                }
                switch try control() {
                case let .word(word, value):
                    if word == "f" {
                        guard !active, !single || completed == 0 else { throw FileContentCopyError.invalidRTF }
                        let identifier = try parameter(value, in: 0...32767)
                        guard identifiers.insert(identifier).inserted else { throw FileContentCopyError.invalidRTF }
                        active = true; fontNameStarted = false; fontNameHasContent = false
                    } else {
                        guard active else { throw FileContentCopyError.invalidRTF }
                        if word == "u" {
                            let number = try parameter(value, in: -32768...65535)
                            try appendUnicode(UInt16(truncatingIfNeeded: number), to: .fonts)
                            if state.unicodeFallback == 1 { try fallback() }
                        } else if word == "uc" {
                            guard pendingHighSurrogate == nil else { throw FileContentCopyError.invalidRTF }
                            state.unicodeFallback = try parameter(value, in: 0...1)
                        } else {
                            guard !fontNameStarted, pendingHighSurrogate == nil else { throw FileContentCopyError.invalidRTF }
                            try fontControl(word, value)
                        }
                    }
                case let .byte(value):
                    guard active else { throw FileContentCopyError.invalidRTF }
                    try appendByte(value, to: .fonts)
                case let .symbol(value):
                    guard active, [92, 123, 125].contains(value) else { throw FileContentCopyError.invalidRTF }
                    try append(UInt32(value), to: .fonts)
                }
            }
            throw FileContentCopyError.invalidRTF
        }

        func fontControl(_ word: String, _ value: Int?) throws {
            switch word {
            case "fcharset": _ = try parameter(value, in: 0...0)
            case "fprq": _ = try parameter(value, in: 0...2)
            case "fnil", "froman", "fswiss", "fmodern", "fscript", "fdecor", "ftech", "fbidi":
                try noParameter(value)
            default: throw FileContentCopyError.invalidRTF
            }
        }

        /// Only one literal/hex/escaped ANSI character may supply uc1 fallback.
        /// Consuming arbitrary control words here could hide structural text loss.
        mutating func fallback() throws {
            while index < bytes.count, bytes[index] == 10 || bytes[index] == 13 { index += 1 }
            guard index < bytes.count else { throw FileContentCopyError.invalidRTF }
            let byte = bytes[index]
            if byte == 92 {
                switch try control() {
                case let .byte(value): _ = try ansi(value)
                case let .symbol(value) where [92, 123, 125].contains(value): break
                default: throw FileContentCopyError.invalidRTF
                }
            } else {
                guard byte != 123, byte != 125 else { throw FileContentCopyError.invalidRTF }
                _ = try ansi(byte); index += 1
            }
        }

        mutating func appendByte(_ byte: UInt8, to destination: Destination) throws {
            try append(ansi(byte), to: destination)
        }

        func ansi(_ byte: UInt8) throws -> UInt32 {
            guard byte >= 32 || byte == 9 else { throw FileContentCopyError.invalidRTF }
            guard byte != 127, byte < 128 || codePage == 1252 else { throw FileContentCopyError.invalidRTF }
            if byte < 128 || byte >= 160 { return UInt32(byte) }
            let cp1252: [UInt32] = [0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
                0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
                0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
                0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178]
            let scalar = cp1252[Int(byte) - 128]
            guard scalar != 0 else { throw FileContentCopyError.invalidRTF }
            return scalar
        }

        mutating func appendUnicode(_ unit: UInt16, to destination: Destination) throws {
            if let high = pendingHighSurrogate {
                guard (0xDC00...0xDFFF).contains(unit) else { throw FileContentCopyError.invalidRTF }
                pendingHighSurrogate = nil
                try append(0x10000 + (UInt32(high) - 0xD800) * 1024 + UInt32(unit) - 0xDC00, to: destination)
            } else if (0xD800...0xDBFF).contains(unit) {
                pendingHighSurrogate = unit
            } else {
                guard !(0xDC00...0xDFFF).contains(unit) else { throw FileContentCopyError.invalidRTF }
                try append(UInt32(unit), to: destination)
            }
        }

        mutating func append(_ value: UInt32, to destination: Destination) throws {
            guard pendingHighSurrogate == nil, let scalar = Unicode.Scalar(value),
                  value != 127, value >= 32 || [9, 10, 12, 13].contains(value) else {
                throw FileContentCopyError.invalidRTF
            }
            if destination == .body {
                headerOpen = false
                outputBytes += value < 0x80 ? 1 : value < 0x800 ? 2 : value < 0x10000 ? 3 : 4
                guard outputBytes <= FileContentCopyPolicy.maximumBytes else { throw FileContentCopyError.tooLarge }
                output.unicodeScalars.append(scalar)
            } else if destination == .fonts {
                // An encoded semicolon cannot bypass the entry terminator.
                guard value != 59 else { throw FileContentCopyError.invalidRTF }
                fontNameStarted = true
                if !CharacterSet.whitespacesAndNewlines.contains(scalar) { fontNameHasContent = true }
            }
        }

        mutating func control() throws -> Control {
            guard index < bytes.count, bytes[index] == 92, index + 1 < bytes.count else {
                throw FileContentCopyError.invalidRTF
            }
            index += 1
            let start = index
            let byte = bytes[index]
            if byte == 39 {
                guard index + 2 < bytes.count, let high = Self.hex(bytes[index + 1]),
                      let low = Self.hex(bytes[index + 2]) else { throw FileContentCopyError.invalidRTF }
                index += 3
                return .byte(high * 16 + low)
            }
            guard Self.letter(byte) else {
                index += 1
                if byte == 13, index < bytes.count, bytes[index] == 10 { index += 1 }
                return .symbol(byte)
            }
            while index < bytes.count, Self.letter(bytes[index]) { index += 1 }
            guard index - start <= 32 else { throw FileContentCopyError.invalidRTF }
            let word = String(decoding: bytes[start..<index], as: UTF8.self)
            var value: Int?
            var negative = false
            if index < bytes.count, bytes[index] == 45 { negative = true; index += 1 }
            let digits = index
            var magnitude = 0
            while index < bytes.count, (48...57).contains(bytes[index]) {
                guard index - digits < 10 else { throw FileContentCopyError.invalidRTF }
                magnitude = magnitude * 10 + Int(bytes[index] - 48)
                guard magnitude <= 2_147_483_648 else { throw FileContentCopyError.invalidRTF }
                index += 1
            }
            guard !negative || index > digits else { throw FileContentCopyError.invalidRTF }
            if index > digits {
                let number = negative ? -magnitude : magnitude
                guard number <= Int(Int32.max) else { throw FileContentCopyError.invalidRTF }
                value = number
            }
            if index < bytes.count, bytes[index] == 32 { index += 1 }
            return .word(word, value)
        }

        func parameter(_ value: Int?, in range: ClosedRange<Int>) throws -> Int {
            guard let value, range.contains(value) else { throw FileContentCopyError.invalidRTF }
            return value
        }
        func noParameter(_ value: Int?) throws {
            guard value == nil else { throw FileContentCopyError.invalidRTF }
        }
        func toggle(_ value: Int?) throws {
            guard value == nil || value == 0 || value == 1 else { throw FileContentCopyError.invalidRTF }
        }
        static func letter(_ value: UInt8) -> Bool { (65...90).contains(value) || (97...122).contains(value) }
        static func hex(_ value: UInt8) -> UInt8? {
            switch value {
            case 48...57: value - 48
            case 65...70: value - 65 + 10
            case 97...102: value - 97 + 10
            default: nil
            }
        }
    }
}

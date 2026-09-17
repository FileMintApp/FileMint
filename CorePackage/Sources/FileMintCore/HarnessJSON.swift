import Foundation

/// The standard decoder discards duplicate object keys. Inspect raw keys first,
/// keeping object scopes and escaped strings intact; Foundation decodes values.
struct HarnessJSON {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) throws {
        guard String(data: data, encoding: .utf8) != nil else {
            throw HarnessDiagnostic(code: "invalidUTF8", path: "$", message: "Input must be UTF-8 JSON")
        }
        bytes = Array(data)
    }

    mutating func validate() throws {
        try value(depth: 0, path: "$")
        whitespace()
        guard offset == bytes.count else { throw invalid("Unexpected trailing input") }
    }

    private mutating func value(depth: Int, path: String) throws {
        whitespace()
        guard offset < bytes.count else { throw invalid("Expected a JSON value") }
        switch bytes[offset] {
        case 123, 91: // object or array
            guard depth < HarnessSuite.maximumDepth else {
                throw HarnessDiagnostic(code: "depthLimit", path: path, message: "JSON nesting exceeds 32 levels")
            }
            let isObject = bytes[offset] == 123
            offset += 1
            whitespace()
            if consume(isObject ? 125 : 93) { return }
            var keys = Set<Data>()
            var index = 0
            while true {
                let childPath: String
                if isObject {
                    whitespace()
                    let key = try string()
                    childPath = path + "." + String(key.prefix(80))
                    guard keys.insert(Data(key.utf8)).inserted else {
                        throw HarnessDiagnostic(code: "duplicateKey", path: childPath, message: "Duplicate JSON object key")
                    }
                    whitespace()
                    guard consume(58) else { throw invalid("Expected ':' after an object key") }
                } else {
                    childPath = "\(path)[\(index)]"
                }
                try value(depth: depth + 1, path: childPath)
                whitespace()
                if consume(isObject ? 125 : 93) { return }
                guard consume(44) else { throw invalid("Expected ',' or end of container") }
                index += 1
            }
        case 34:
            _ = try string()
        case 45, 48...57, 116, 102, 110: // number, true, false, null
            // The typed decoder validates scalar spelling/type after this scan.
            while offset < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[offset]) {
                offset += 1
            }
        default:
            throw invalid("Expected a JSON value")
        }
    }

    private mutating func string() throws -> String {
        let start = offset
        guard consume(34) else { throw invalid("Expected a JSON string") }
        while offset < bytes.count {
            let byte = bytes[offset]
            guard byte >= 32 else { throw invalid("Unescaped control character in string") }
            if byte == 92 {
                offset += 2 // Skip an escaped byte; Foundation validates the escape.
            } else if byte == 34 {
                offset += 1
                do {
                    return try JSONDecoder().decode(String.self, from: Data(bytes[start..<offset]))
                } catch {
                    throw invalid("Invalid string escape or Unicode scalar")
                }
            } else {
                offset += 1
            }
        }
        throw invalid("Unterminated JSON string")
    }

    private mutating func whitespace() {
        while offset < bytes.count && [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard offset < bytes.count, bytes[offset] == byte else { return false }
        offset += 1
        return true
    }

    private func invalid(_ message: String) -> HarnessDiagnostic {
        HarnessDiagnostic(code: "invalidJSON", path: "$", message: "\(message) at byte \(offset)")
    }
}

struct HarnessKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

func harnessPath(_ keys: [any CodingKey]) -> String {
    keys.reduce("$") { path, key in
        if let index = key.intValue { return "\(path)[\(index)]" }
        return path + "." + String(key.stringValue.prefix(80))
    }
}

func harnessContainer(_ decoder: any Decoder, allowing keys: Set<String>) throws -> KeyedDecodingContainer<HarnessKey> {
    let container = try decoder.container(keyedBy: HarnessKey.self)
    try harnessKeys(container, allowing: keys)
    return container
}

func harnessKeys(_ container: KeyedDecodingContainer<HarnessKey>, allowing keys: Set<String>) throws {
    if let unknown = container.allKeys.map(\.stringValue).filter({ !keys.contains($0) }).sorted().first {
        throw HarnessDiagnostic(code: "unknownField", path: harnessPath(container.codingPath + [HarnessKey(unknown)]),
                                message: "Unknown field; allowed fields: \(keys.sorted().joined(separator: ", "))")
    }
}

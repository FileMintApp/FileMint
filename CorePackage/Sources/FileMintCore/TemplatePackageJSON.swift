import Foundation

/// The standard decoder discards duplicate object keys. Inspect raw keys first,
/// keeping object scopes and escaped strings intact; Foundation decodes values.
struct TemplatePackageJSON {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) throws {
        guard String(data: data, encoding: .utf8) != nil else {
            throw TemplatePackageError.invalid
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
            guard depth < 32 else {
                throw TemplatePackageError.invalid
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
                        throw TemplatePackageError.invalid
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

    private func invalid(_ message: String) -> TemplatePackageError { .invalid }
}

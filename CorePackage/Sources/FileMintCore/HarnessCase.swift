import Foundation

/// Constructible only through the shared loader. No unchecked array runner exists.
public struct HarnessSuite: Sendable {
    public static let maximumBytes = 1_048_576
    public static let maximumDepth = 32
    public static let maximumCases = 1_000
    let cases: [HarnessCase]
    public var caseCount: Int { cases.count }

    private init(cases: [HarnessCase]) { self.cases = cases }

    public static func load(data: Data) throws -> HarnessSuite {
        guard data.count <= maximumBytes else { throw sizeError }
        var json = try HarnessJSON(data)
        try json.validate()
        let document: HarnessDocument
        do {
            document = try JSONDecoder().decode(HarnessDocument.self, from: data)
        } catch {
            throw HarnessDiagnostic.decoding(error)
        }
        guard !document.cases.isEmpty, document.cases.count <= maximumCases else {
            throw HarnessDiagnostic(code: "caseCount", path: "$.cases", message: "Expected 1...1000 cases")
        }
        var identifiers = Set<String>()
        for (index, item) in document.cases.enumerated() {
            let path = "$.cases[\(index)]"
            guard !item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  identifiers.insert(item.id).inserted else {
                throw HarnessDiagnostic(code: "caseID", path: path + ".id", message: "Case IDs must be nonblank and unique")
            }
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HarnessDiagnostic(code: "caseName", path: path + ".name", message: "Case name must not be blank")
            }
            guard TemplateCatalog.template(withID: item.templateID) != nil else {
                throw HarnessDiagnostic(code: "template", path: path + ".templateID", message: "Unknown built-in template")
            }
            try validateFileName(item.expect.fileName, path: path + ".expect.fileName")
            var names = Set<String>()
            for (fileIndex, file) in item.existingFiles.enumerated() {
                let filePath = "\(path).existingFiles[\(fileIndex)].name"
                try validateFileName(file.name, path: filePath)
                guard names.insert(file.name).inserted else {
                    throw HarnessDiagnostic(code: "fixtureName", path: filePath, message: "Duplicate fixture filename")
                }
            }
        }
        return HarnessSuite(cases: document.cases)
    }

    public static func load(from url: URL) throws -> HarnessSuite {
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) }
        catch { throw HarnessDiagnostic(code: "inputRead", path: "$", message: "Cannot open suite input") }
        defer { try? handle.close() }
        var data = Data()
        do {
            while data.count <= maximumBytes {
                let chunk = try handle.read(upToCount: min(65_536, maximumBytes + 1 - data.count)) ?? Data()
                if chunk.isEmpty { break }
                data.append(chunk)
            }
        } catch {
            throw HarnessDiagnostic(code: "inputRead", path: "$", message: "Cannot read suite input")
        }
        return try load(data: data)
    }

    private static var sizeError: HarnessDiagnostic {
        HarnessDiagnostic(code: "sizeLimit", path: "$", message: "Suite input exceeds 1 MiB")
    }

    private static func validateFileName(_ name: String, path: String) throws {
        let forbidden = CharacterSet(charactersIn: "/\\:").union(.controlCharacters)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name != ".", name != "..", name.unicodeScalars.allSatisfy({ !forbidden.contains($0) }) else {
            throw HarnessDiagnostic(code: "fileName", path: path, message: "Expected a single nonblank filename without separators or controls")
        }
    }
}

private struct HarnessDocument: Decodable {
    let cases: [HarnessCase]
    init(from decoder: any Decoder) throws {
        let c = try harnessContainer(decoder, allowing: ["schemaVersion", "cases"])
        guard try c.decode(Int.self, forKey: HarnessKey("schemaVersion")) == 1 else {
            throw HarnessDiagnostic(code: "schemaVersion", path: "$.schemaVersion", message: "Expected schemaVersion 1")
        }
        cases = try c.decode([HarnessCase].self, forKey: HarnessKey("cases"))
    }
}

struct HarnessCase: Decodable, Sendable {
    let id: String
    let name: String
    let templateID: String
    let requestedFileName: String?
    let existingFiles: [HarnessFixture]
    let expect: HarnessExpectation

    init(from decoder: any Decoder) throws {
        let c = try harnessContainer(decoder, allowing: ["id", "name", "templateID", "requestedFileName", "existingFiles", "expect"])
        id = try c.decode(String.self, forKey: HarnessKey("id"))
        name = try c.decode(String.self, forKey: HarnessKey("name"))
        templateID = try c.decode(String.self, forKey: HarnessKey("templateID"))
        requestedFileName = try c.decodeIfPresent(String.self, forKey: HarnessKey("requestedFileName"))
        existingFiles = try c.decode([HarnessFixture].self, forKey: HarnessKey("existingFiles"))
        expect = try c.decode(HarnessExpectation.self, forKey: HarnessKey("expect"))
    }
}

struct HarnessFixture: Decodable, Sendable {
    let name: String
    let content: String
    init(from decoder: any Decoder) throws {
        let c = try harnessContainer(decoder, allowing: ["name", "content"])
        name = try c.decode(String.self, forKey: HarnessKey("name"))
        content = try c.decode(String.self, forKey: HarnessKey("content"))
    }
}

struct HarnessExpectation: Decodable, Sendable {
    let fileName: String
    let content: HarnessContent
    init(from decoder: any Decoder) throws {
        let c = try harnessContainer(decoder, allowing: ["fileName", "content"])
        fileName = try c.decode(String.self, forKey: HarnessKey("fileName"))
        content = try c.decode(HarnessContent.self, forKey: HarnessKey("content"))
    }
}

enum HarnessContent: Decodable, Sendable {
    case exact(String)
    case contains([String])

    init(from decoder: any Decoder) throws {
        let c = try harnessContainer(decoder, allowing: ["mode", "value", "values"])
        let mode = try c.decode(String.self, forKey: HarnessKey("mode"))
        switch mode {
        case "exact":
            try harnessKeys(c, allowing: ["mode", "value"])
            self = .exact(try c.decode(String.self, forKey: HarnessKey("value")))
        case "contains":
            try harnessKeys(c, allowing: ["mode", "values"])
            let values = try c.decode([String].self, forKey: HarnessKey("values"))
            guard !values.isEmpty, values.allSatisfy({ !$0.isEmpty }) else {
                throw HarnessDiagnostic(code: "content", path: harnessPath(c.codingPath) + ".values", message: "Expected nonempty UTF-8 fragments")
            }
            self = .contains(values)
        default:
            throw HarnessDiagnostic(code: "contentMode", path: harnessPath(c.codingPath) + ".mode", message: "Expected exact or contains")
        }
    }
}

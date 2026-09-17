@testable import FileMintCore
import Foundation
import Testing

@Suite("Harness validation and execution")
struct HarnessValidationTests {
    private func sample(id: String = "sample") -> [String: Any] {
        ["id": id, "name": "Sample", "templateID": "plain-text", "existingFiles": [],
         "expect": ["fileName": "Untitled.txt", "content": ["mode": "exact", "value": ""]]]
    }

    private func data(_ cases: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "cases": cases], options: .sortedKeys)
    }

    private func invalid(_ data: Data, code: String) {
        do {
            _ = try HarnessSuite.load(data: data)
            Issue.record("Invalid input was accepted; expected \(code)")
        } catch let error as HarnessDiagnostic {
            #expect(error.code == code, "\(error)")
        } catch {
            Issue.record("Unstructured error: \(error)")
        }
    }

    private func workspace<T>(_ body: (URL) throws -> T) throws -> T {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HarnessTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        return try body(root)
    }

    @Test("empty suites, missing versions and old arrays cannot pass")
    func suiteShape() throws {
        invalid(try data([]), code: "caseCount")
        invalid(Data("[]".utf8), code: "fieldType")
        invalid(Data("{}".utf8), code: "missingField")
        invalid(Data(#"{"schemaVersion":2,"cases":[]}"#.utf8), code: "schemaVersion")
        invalid(Data(#"{"schemaVersion":true,"cases":[]}"#.utf8), code: "fieldType")
    }

    @Test("unknown keys are rejected at every level", arguments: ["root", "case", "fixture", "expect", "content"])
    func unknownFields(level: String) throws {
        var item = sample()
        switch level {
        case "case": item["requestedFileNmae"] = "Chosen.txt"
        case "fixture": item["existingFiles"] = [["name": "seed.txt", "content": "", "ignored": true]]
        case "expect": item["expect"] = ["fileName": "Untitled.txt", "ignored": true, "content": ["mode": "exact", "value": ""]]
        case "content": item["expect"] = ["fileName": "Untitled.txt", "content": ["mode": "exact", "value": "", "ignored": true]]
        default: break
        }
        var document: [String: Any] = ["schemaVersion": 1, "cases": [item]]
        if level == "root" { document["ignored"] = true }
        invalid(try JSONSerialization.data(withJSONObject: document), code: "unknownField")
    }

    @Test("required fields, types, null and invalid modes fail before execution")
    func fieldValidation() throws {
        var item = sample()
        item.removeValue(forKey: "expect")
        invalid(try data([item]), code: "missingField")
        item = sample(); item["id"] = 1
        invalid(try data([item]), code: "fieldType")
        item = sample(); item["name"] = NSNull()
        invalid(try data([item]), code: "nullField")
        item = sample(); item["templateID"] = "does-not-exist"
        invalid(try data([item]), code: "template")
        item = sample(); item["id"] = " \n"
        invalid(try data([item]), code: "caseID")
        item = sample(); item["name"] = " "
        invalid(try data([item]), code: "caseName")
        invalid(try data([sample(), sample()]), code: "caseID")
        // Descriptions may repeat, but stable identifiers must not.
        #expect(try HarnessSuite.load(data: data([sample(id: "one"), sample(id: "two")])).caseCount == 2)
    }

    @Test("requested filename is arbitrary input, optional or null")
    func requestedFilename() throws {
        var item = sample()
        _ = try HarnessSuite.load(data: data([item]))
        item["requestedFileName"] = NSNull()
        _ = try HarnessSuite.load(data: data([item]))
        item["requestedFileName"] = "api/config.json"
        item["templateID"] = "json"
        item["expect"] = ["fileName": "api-config.json", "content": ["mode": "exact", "value": "{}\n"]]
        #expect(HarnessRunner.run(try HarnessSuite.load(data: data([item]))).exitCode == 0)
        item["requestedFileName"] = 12
        invalid(try data([item]), code: "fieldType")
    }

    @Test("content modes have exclusive required fields and cannot skip", arguments: ["empty-array", "empty-fragment", "skip", "cross-mode", "missing", "null"])
    func contentModes(scenario: String) throws {
        var item = sample()
        var content: [String: Any] = ["mode": "contains", "values": ["x"]]
        let code: String
        switch scenario {
        case "empty-array": content["values"] = []; code = "content"
        case "empty-fragment": content["values"] = [""]; code = "content"
        case "skip": content = ["mode": "skip"]; code = "contentMode"
        case "cross-mode": content = ["mode": "exact", "value": "", "values": ["x"]]; code = "unknownField"
        case "missing": content = ["mode": "exact"]; code = "missingField"
        default: content = ["mode": "exact", "value": NSNull()]; code = "nullField"
        }
        item["expect"] = ["fileName": "Untitled.txt", "content": content]
        invalid(try data([item]), code: code)
    }

    @Test("duplicate keys including escaped equivalents are rejected", arguments: ["root", "case", "nested", "escaped"])
    func duplicateKeys(level: String) throws {
        var json = String(decoding: try data([sample()]), as: UTF8.self)
        switch level {
        case "root": json = json.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"schemaVersion\":1")
        case "case": json = json.replacingOccurrences(of: "\"id\":\"sample\"", with: "\"id\":\"sample\",\"id\":\"other\"")
        case "nested": json = json.replacingOccurrences(of: "\"value\":\"\"", with: "\"value\":\"\",\"value\":\"different\"")
        default: json = json.replacingOccurrences(of: "\"schemaVersion\":1", with: #""schemaVersion":1,"schema\u0056ersion":1"#)
        }
        invalid(Data(json.utf8), code: "duplicateKey")
    }

    @Test("JSON keys are scoped, strings with structural characters remain data")
    func stringScanning() throws {
        var item = sample()
        item["name"] = "quotes: \"id\": 1, braces { }, arrays [], slash \\, literal \\u0061 🌱"
        #expect(try HarnessSuite.load(data: data([item, sample(id: "another")])).caseCount == 2)
        let escaped = String(decoding: try data([sample()]), as: UTF8.self)
            .replacingOccurrences(of: "\"name\"", with: #""na\u006de""#)
        #expect(try HarnessSuite.load(data: Data(escaped.utf8)).caseCount == 1)
        for json in ["", "{", "[1,]", "{\"a\":1,}", "{} {}", #"{"a":"\q"}"#, #"{"a":"\uD800"}"#, "{\"a\":\"raw\nnewline\"}"] {
            invalid(Data(json.utf8), code: "invalidJSON")
        }
        invalid(Data([0xFF]), code: "invalidUTF8")
    }

    @Test("byte, nesting and case limits are enforced without silent truncation")
    func limits() throws {
        let base = try data([sample()])
        let exact = base + Data(repeating: 32, count: HarnessSuite.maximumBytes - base.count)
        #expect(try HarnessSuite.load(data: exact).caseCount == 1)
        invalid(exact + Data([32]), code: "sizeLimit")
        var scanner = try HarnessJSON(Data((String(repeating: "[", count: 32) + "0" + String(repeating: "]", count: 32)).utf8))
        try scanner.validate()
        invalid(Data((String(repeating: "[", count: 33) + "0" + String(repeating: "]", count: 33)).utf8), code: "depthLimit")
        let cases = (0..<1000).map { sample(id: "case-\($0)") }
        #expect(try HarnessSuite.load(data: data(cases)).caseCount == 1000)
        invalid(try data(cases + [sample(id: "extra")]), code: "caseCount")
    }

    @Test("fixture and expected names cannot become paths", arguments: ["", " ", ".", "..", "../outside", "/tmp/outside", "sub/file", "back\\slash", "bad:name", "bad\u{0}name", "line\nname"])
    func unsafeNames(name: String) throws {
        var item = sample()
        item["existingFiles"] = [["name": name, "content": "seed"]]
        invalid(try data([item]), code: "fileName")
        item = sample()
        item["expect"] = ["fileName": name, "content": ["mode": "exact", "value": ""]]
        invalid(try data([item]), code: "fileName")
    }

    @Test("duplicate fixtures are invalid")
    func duplicateFixtures() throws {
        var item = sample()
        item["existingFiles"] = [["name": "seed", "content": "one"], ["name": "seed", "content": "two"]]
        invalid(try data([item]), code: "fixtureName")
    }

    @Test("filesystem filename aliases never silently overwrite prepared fixtures")
    func fixtureAliases() throws {
        try workspace { root in
            let lower = root.appendingPathComponent("case-probe")
            try Data("probe".utf8).write(to: lower)
            let aliases = FileManager.default.fileExists(atPath: root.appendingPathComponent("CASE-PROBE").path)
            try FileManager.default.removeItem(at: lower)
            var item = sample()
            item["existingFiles"] = [["name": "seed.txt", "content": "one"], ["name": "SEED.TXT", "content": "two"]]
            let report = HarnessRunner.run(try HarnessSuite.load(data: data([item])), temporaryDirectory: root)
            #expect(report.exitCode == (aliases ? 2 : 0))
            if aliases { #expect(report.cases[0].errors.first?.code == "setup") }
            let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
            #expect(remaining.isEmpty)
        }
    }

    @Test("exact assertions use bytes, not Unicode canonical equality", arguments: ["\r\n", " \n", "\n\n", "é", "e\u{301}"])
    func byteAssertions(actual: String) {
        let expected = actual == "é" ? Data("é".utf8) : Data("\n".utf8)
        let check = HarnessAssertion.bytes(path: "content", expected: expected, actual: Data(actual.utf8))
        #expect(check.passed == (expected == Data(actual.utf8)))
        if !check.passed { #expect(check.actual.contains("first difference at byte")) }
        let long = HarnessAssertion.byteSummary(Data(repeating: 65, count: 100_000))
        #expect(long.count < 200)
    }

    @Test("fixture preparation failures prevent product calls", arguments: ["throw", "no-write", "wrong-bytes"])
    func setupFailure(mode: String) throws {
        var item = sample()
        item["existingFiles"] = [["name": "seed.txt", "content": "keep"]]
        let suite = try HarnessSuite.load(data: data([item]))
        try workspace { root in
            var calls = 0
            var ops = HarnessOperations()
            ops.writeFixture = { _, url in
                if mode == "throw" { throw CocoaError(.fileWriteNoPermission) }
                if mode == "wrong-bytes" { try Data("wrong".utf8).write(to: url) }
            }
            ops.createFile = { _, _ in calls += 1; throw CocoaError(.fileWriteUnknown) }
            let report = HarnessRunner.run(suite, temporaryDirectory: root, operations: ops)
            #expect(report.exitCode == 2)
            #expect(report.cases[0].errors.first?.code == "setup")
            #expect(calls == 0)
            let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
            #expect(remaining.isEmpty)
        }
    }

    @Test("creation failures retain later results; cleanup errors take precedence")
    func aggregation() throws {
        let suite = try HarnessSuite.load(data: data([sample(id: "one"), sample(id: "two")]))
        try workspace { root in
            var calls = 0
            var ops = HarnessOperations()
            ops.createFile = { request, date in
                calls += 1
                if calls == 1 { throw CocoaError(.fileWriteUnknown) }
                return try FileCreationService().createFile(request, now: date)
            }
            let report = HarnessRunner.run(suite, temporaryDirectory: root, operations: ops)
            #expect(report.exitCode == 1)
            #expect(report.cases.map(\.status) == [.failed, .passed])
            let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
            #expect(remaining.isEmpty)
            calls = 0
            ops.cleanup = { _ in throw CocoaError(.fileWriteNoPermission) }
            let cleanup = HarnessRunner.run(suite, temporaryDirectory: root, operations: ops)
            #expect(cleanup.exitCode == 2)
            #expect(cleanup.errors.first?.code == "cleanup")
        }
    }

    @Test("replacing a case directory with an outside symlink cannot redefine containment")
    func replacedCaseDirectory() throws {
        let suite = try HarnessSuite.load(data: data([sample()]))
        try workspace { root in
            let outside = root.appendingPathComponent("outside", isDirectory: true)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
            let sentinel = outside.appendingPathComponent("Untitled.txt")
            try Data("OUTSIDE SECRET".utf8).write(to: sentinel)
            var ops = HarnessOperations()
            ops.createFile = { request, _ in
                try FileManager.default.removeItem(at: request.destinationDirectory)
                try FileManager.default.createSymbolicLink(at: request.destinationDirectory, withDestinationURL: outside)
                return FileCreationResult(createdURL: request.destinationDirectory.appendingPathComponent("Untitled.txt"), usedCollisionFallback: false)
            }
            let report = HarnessRunner.run(suite, temporaryDirectory: root, operations: ops)
            #expect(report.exitCode == 1)
            #expect(report.cases[0].assertions.first?.path == "output.location")
            #expect(try Data(contentsOf: sentinel) == Data("OUTSIDE SECRET".utf8))
            #expect(!report.text().contains("OUTSIDE SECRET"))
        }
    }

    @Test("setup errors do not discard independent later cases")
    func setupErrorContinuation() throws {
        var bad = sample(id: "bad-setup")
        bad["existingFiles"] = [["name": "seed.txt", "content": "keep"]]
        let suite = try HarnessSuite.load(data: data([bad, sample(id: "good")]))
        try workspace { root in
            var ops = HarnessOperations()
            ops.writeFixture = { _, _ in throw CocoaError(.fileWriteNoPermission) }
            let report = HarnessRunner.run(suite, temporaryDirectory: root, operations: ops)
            #expect(report.exitCode == 2)
            #expect(report.cases.map(\.status) == [.error, .passed])
        }
    }

    @Test("outside URLs and symlink outputs are rejected without reading them", arguments: ["outside", "symlink"])
    func containment(mode: String) throws {
        let suite = try HarnessSuite.load(data: data([sample()]))
        try workspace { root in
            let outside = root.appendingPathComponent("outside.txt")
            try Data("PRESERVE".utf8).write(to: outside)
            var ops = HarnessOperations()
            ops.createFile = { request, _ in
                let result: URL
                if mode == "symlink" {
                    result = request.destinationDirectory.appendingPathComponent("Untitled.txt")
                    try FileManager.default.createSymbolicLink(at: result, withDestinationURL: outside)
                } else { result = outside }
                return FileCreationResult(createdURL: result, usedCollisionFallback: false)
            }
            let report = HarnessRunner.run(suite, temporaryDirectory: root, operations: ops)
            #expect(report.exitCode == 1)
            #expect(try Data(contentsOf: outside) == Data("PRESERVE".utf8))
            #expect(!report.text().contains("PRESERVE"))
        }
    }

    @Test("changed fixtures and extra files fail even if output content is correct", arguments: ["overwrite", "extra"])
    func sideEffects(mode: String) throws {
        var item = sample()
        item["existingFiles"] = [["name": "seed.txt", "content": "keep"]]
        let suite = try HarnessSuite.load(data: data([item]))
        try workspace { root in
            var ops = HarnessOperations()
            ops.createFile = { request, date in
                let result = try FileCreationService().createFile(request, now: date)
                let name = mode == "overwrite" ? "seed.txt" : "extra.txt"
                try Data("changed".utf8).write(to: request.destinationDirectory.appendingPathComponent(name))
                return result
            }
            let report = HarnessRunner.run(suite, temporaryDirectory: root, operations: ops)
            #expect(report.exitCode == 1)
            let path = mode == "overwrite" ? "existingFiles[0].unchanged" : "directory.entries"
            #expect(report.cases[0].assertions.contains { $0.path == path && !$0.passed })
        }
    }

    @Test("old fixed workspaces are untouched and reports agree")
    func ownershipAndReports() throws {
        let suite = try HarnessSuite.load(data: data([sample()]))
        try workspace { root in
            let old = root.appendingPathComponent("FileMintHarness")
            try FileManager.default.createDirectory(at: old, withIntermediateDirectories: false)
            let marker = old.appendingPathComponent("keep")
            try Data("keep".utf8).write(to: marker)
            let report = HarnessRunner.run(suite, temporaryDirectory: root)
            #expect(report.exitCode == 0)
            #expect(try Data(contentsOf: marker) == Data("keep".utf8))
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["FileMintHarness"])
            let json = try #require(JSONSerialization.jsonObject(with: report.jsonData()) as? [String: Any])
            #expect(json["status"] as? String == report.status.rawValue)
            #expect(json["exitCode"] as? Int == Int(report.exitCode))
            #expect(report.text().contains("PASSED suite"))
        }
        let error = HarnessRunner.run(suite, temporaryDirectory: URL(fileURLWithPath: "/no-such-filemint-test-directory"))
        #expect(error.exitCode == 2)
        #expect(error.cases.isEmpty)
        #expect(HarnessReport(declaredCases: 0, cases: []).exitCode == 2)
        #expect(HarnessReport(declaredCases: 1, cases: []).exitCode == 2)
        #expect(HarnessReport.usageError().exitCode == 64)
    }
}

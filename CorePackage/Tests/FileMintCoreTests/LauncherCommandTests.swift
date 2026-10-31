import FileMintCore
import Foundation
import Testing

@Suite("Launcher command export")
struct LauncherCommandTests {
    @Test("headers cannot introduce another shell line")
    func headers() throws {
        for title in ["", " ", "name\n/usr/bin/false", "name\rnext", "name\u{2028}next", String(repeating: "x", count: 257)] {
            #expect(throws: ExternalInvocationError.invalidRequest) { try LauncherCommand(title: title, invocation: .search) }
        }
        #expect(throws: ExternalInvocationError.invalidRequest) { try LauncherCommand(title: "Search", invocation: .search, runtimeName: true) }
        #expect(throws: ExternalInvocationError.invalidRequest) {
            try LauncherCommand(title: "Draft", invocation: .draft(.init(name: "fixed")), runtimeName: true)
        }
    }

    @Test("actual bash execution keeps fixed configuration and runtime argv as data")
    func shellData() throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let escaped = root.appendingPathComponent("must-not-exist")
        let request = try ExternalDraftRequest(templateID: "markdown",
            content: .verbatim("中文\r\n`literal` $() & # + % {{year}}"),
            destination: .directory(root.appendingPathComponent("quotes ' $() `literal`").path))
        let command = try LauncherCommand(title: "Note $(touch \(escaped.path)) `literal`", invocation: .draft(request), runtimeName: true)
        let script = try command.raycastScript()
        #expect(script.contains("\"percentEncoded\":true"))
        #expect(!script.contains("eval "))
        #expect(!script.contains("python"))
        #expect(!script.contains("node "))
        let mock = root.appendingPathComponent("mock-open")
        let captured = root.appendingPathComponent("argv")
        let mockBytes = "#!/bin/bash\nprintf '%s\\0' \"$@\" > \"$FILEMINT_MOCK_OUTPUT\"\n"
        try Data(mockBytes.utf8).write(to: mock)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: mock.path)
        // Replace only the fixed OS transport; execute the renderer's exact body.
        #expect(script.components(separatedBy: "/usr/bin/open").count == 2)
        let runnable = script.replacingOccurrences(of: "/usr/bin/open", with: mock.path)
        let file = root.appendingPathComponent("command.sh")
        try Data(runnable.utf8).write(to: file)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [file.path, "Project%20%E4%B8%AD%E6%96%87%20%26%20%23%20%2B%20%25%20%24%28%29%20%60literal%60"]
        process.environment = ProcessInfo.processInfo.environment.merging(["FILEMINT_MOCK_OUTPUT": captured.path]) { _, new in new }
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let arguments = try String(decoding: Data(contentsOf: captured), as: UTF8.self).split(separator: "\0", omittingEmptySubsequences: false)
        #expect(Array(arguments.prefix(2)) == ["-b", "io.github.daigua.filemint"])
        guard case .draft(let actual) = try ExternalDraftRoute.parse(String(arguments[2])) else { Issue.record("Missing request"); return }
        #expect(actual.name == "Project 中文 & # + % $() `literal`")
        #expect(actual.content == request.content)
        #expect(actual.destination == request.destination)
        #expect(!FileManager.default.fileExists(atPath: escaped.path))
        // A literal malicious argv is also data, even outside Raycast's encoder.
        let malicious = Process()
        malicious.executableURL = URL(fileURLWithPath: "/bin/bash")
        malicious.arguments = [file.path, "$(touch \(escaped.path))"]
        malicious.environment = process.environment
        try malicious.run(); malicious.waitUntilExit()
        #expect(malicious.terminationStatus == 0)
        #expect(!FileManager.default.fileExists(atPath: escaped.path))
    }

    @Test("export prepares executable permissions and preserves existing destinations on failure")
    func atomicExport() throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("command.sh")
        try Data("old script\n".utf8).write(to: target)
        let command = try LauncherCommand(title: "Search", invocation: .search)
        try command.exportRaycast(to: target)
        #expect(try String(contentsOf: target, encoding: .utf8) == command.raycastScript())
        #expect((try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        let preserved = try Data(contentsOf: target)
        #expect(throws: ExternalInvocationError.invalidRequest) { try command.exportRaycast(to: target, bundleIdentifier: "bad\nidentity") }
        #expect(try Data(contentsOf: target) == preserved)
        let directory = root.appendingPathComponent("existing.sh", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try Data("keep\n".utf8).write(to: directory.appendingPathComponent("original.txt"))
        #expect(throws: (any Error).self) { try command.exportRaycast(to: directory) }
        #expect(try Data(contentsOf: directory.appendingPathComponent("original.txt")) == Data("keep\n".utf8))
        let original = root.appendingPathComponent("preserved-original.sh")
        try Data("preserve link target\n".utf8).write(to: original)
        let link = root.appendingPathComponent("selected-link.sh")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
        // Coordination may reject a redirected target. Success must replace the
        // selected link itself; neither outcome may modify its original target.
        let result = Result { try command.exportRaycast(to: link) }
        #expect(try Data(contentsOf: original) == Data("preserve link target\n".utf8))
        switch result {
        case .success:
            #expect(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == false)
            #expect(try String(contentsOf: link, encoding: .utf8) == command.raycastScript())
        case .failure:
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == original.path)
        }
    }

    private func workspace() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-Launcher-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

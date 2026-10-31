import FileMintCore
import Foundation
import Testing

@Suite("Managed launcher scripts")
struct LauncherScriptStoreTests {
    @Test("existing exports round-trip as data, including empty and literal text")
    func roundTrip() throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("note.sh")
        let requests: [(ExternalInvocation, Bool)] = [(.search, false),
            (.draft(try .init(templateID: "markdown", destination: .ask)), true),
            (.draft(try .init(name: "中文 Note", content: .verbatim(""), destination: .favorite(UUID()))), false),
            (.draft(try .init(content: .verbatim("  literal $() `text`\r\n{{year}}\n"), destination: .directory(root.path))), false)]
        for (invocation, runtime) in requests {
            let command = try LauncherCommand(title: "项目笔记", invocation: invocation, runtimeName: runtime)
            try command.exportRaycast(to: target)
            let contents = try LauncherScriptSnapshot.read(at: target).contents()
            #expect(contents.command.title == "项目笔记")
            #expect(contents.command.invocation == invocation)
            #expect(contents.command.runtimeName == runtime)
            #expect(contents.bundleIdentifier == "io.github.daigua.filemint")
            #expect(contents.scheme == "filemint")
        }
        // Changing any executable line or adding a second title is rejected, never executed.
        let original = try String(contentsOf: target, encoding: .utf8)
        for script in [original + "touch must-not-run\n", original.replacingOccurrences(of: "set -eu", with: "set +eu"),
                       original + "# @raycast.title forged\n", "#!/bin/bash\necho unrelated\n"] {
            try Data(script.utf8).write(to: target)
            #expect(throws: (any Error).self) { try LauncherScriptSnapshot.read(at: target).contents() }
        }
    }

    @Test("editing updates the same file and rejects changed, replaced or redirected files")
    func guardedUpdate() throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("original.sh")
        let command = try LauncherCommand(title: "Before", invocation: .search)
        try command.exportRaycast(to: target)
        let before = try LauncherScriptSnapshot.read(at: target)
        let edited = try LauncherCommand(title: "After", invocation: .draft(.init(name: "Fixed", templateID: "markdown")))
        try edited.exportRaycast(to: target, replacing: before)
        #expect(try String(contentsOf: target, encoding: .utf8) == edited.raycastScript())
        let current = try LauncherScriptSnapshot.read(at: target)
        #expect(throws: (any Error).self) { try command.exportRaycast(to: target, replacing: before) }
        #expect(try LauncherScriptSnapshot.read(at: target) == current)
        // Same bytes in a new file still do not identify the original exported item.
        try FileManager.default.removeItem(at: target)
        try current.data.write(to: target)
        #expect(throws: (any Error).self) { try command.exportRaycast(to: target, replacing: current) }
        #expect(try Data(contentsOf: target) == current.data)
        let original = root.appendingPathComponent("preserve.sh")
        try Data("keep\n".utf8).write(to: original)
        try FileManager.default.removeItem(at: target)
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: original)
        #expect(throws: (any Error).self) { try command.exportRaycast(to: target, replacing: current) }
        #expect(try Data(contentsOf: original) == Data("keep\n".utf8))
    }

    @Test("private index reloads exact references without duplicating content")
    func indexRoundTrip() throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("note.sh")
        let command = try LauncherCommand(title: "Note", invocation: .draft(.init(content: .verbatim("private-body-sentinel"))))
        try command.exportRaycast(to: target)
        let snapshot = try LauncherScriptSnapshot.read(at: target)
        let record = try LauncherScriptRecord(url: target, bookmark: Data([1, 2, 3]), snapshot: snapshot)
        let store = LauncherScriptStore(file: root.appendingPathComponent("private/index.json"))
        #expect(try store.load().isEmpty)
        try store.save([record])
        #expect(try store.load() == [record])
        #expect(try record.read(at: target) == snapshot)
        #expect(!(try String(contentsOf: store.file, encoding: .utf8)).contains("private-body-sentinel"))
        #expect((try FileManager.default.attributesOfItem(atPath: store.file.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(throws: LauncherScriptError.invalidIndex) { try store.save([record, record]) }
        #expect(try store.load() == [record])
        try Data("external edit\n".utf8).write(to: target)
        #expect(throws: LauncherScriptError.changedScript) { try record.read(at: target) }
        try store.save([])
        #expect(try Data(contentsOf: target) == Data("external edit\n".utf8))
    }

    @Test("corrupt, oversized and symlink indexes are preserved")
    func damagedIndex() throws {
        let root = try workspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("index.json"), store = LauncherScriptStore(file: file)
        for data in [Data("damaged".utf8), Data(repeating: 32, count: LauncherScriptStore.maximumBytes + 1)] {
            try data.write(to: file)
            #expect(throws: LauncherScriptError.invalidIndex) { try store.load() }
            #expect(throws: LauncherScriptError.invalidIndex) { try store.save([]) }
            #expect(try Data(contentsOf: file) == data)
        }
        try FileManager.default.removeItem(at: file)
        let preserved = root.appendingPathComponent("preserve.json")
        try Data("[]".utf8).write(to: preserved)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: preserved)
        #expect(throws: LauncherScriptError.invalidIndex) { try store.save([]) }
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: file.path) == preserved.path)
        #expect(try Data(contentsOf: preserved) == Data("[]".utf8))
    }

    private func workspace() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-ManagedScripts-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }
}

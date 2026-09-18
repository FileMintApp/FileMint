import FileMintCore
import Foundation
import Testing

@Suite("Native Desktop aliases")
struct DesktopAliasTests {
    private func workspace(_ body: (URL, URL, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-alias-test-\(UUID())")
        let source = root.appendingPathComponent("source")
        let desktop = root.appendingPathComponent("Desktop")
        for url in [source, desktop] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root, source, desktop)
    }

    private func resolve(_ url: URL) throws -> URL {
        try URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting]).standardizedFileURL
    }

    @Test("files, folders and packages produce real aliases while originals remain unchanged")
    func realAliases() throws {
        try workspace { _, source, desktop in
            let file = source.appendingPathComponent("报告 % 🪴.txt")
            let folder = source.appendingPathComponent("Folder.name")
            let package = source.appendingPathComponent("Example.app")
            let bytes = Data([0, 255, 10, 42])
            try bytes.write(to: file)
            for url in [folder, package] {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                try bytes.write(to: url.appendingPathComponent("child"))
            }
            let originals = [file, folder, package]
            let aliases = try DesktopAliasService.perform(items: DesktopAliasService.capture(originals), in: desktop) { true }
            #expect(aliases.map(\.lastPathComponent) == originals.map(\.lastPathComponent))
            for (alias, original) in zip(aliases, originals) {
                let values = try alias.resourceValues(forKeys: [.isAliasFileKey, .isSymbolicLinkKey])
                #expect(values.isAliasFile == true)
                #expect(values.isSymbolicLink == false)
                #expect(try resolve(alias) == original.standardizedFileURL)
                try FileManager.default.removeItem(at: alias)
            }
            #expect(try Data(contentsOf: file) == bytes)
            #expect(try Data(contentsOf: folder.appendingPathComponent("child")) == bytes)
            #expect(try Data(contentsOf: package.appendingPathComponent("child")) == bytes)
            #expect(try FileManager.default.contentsOfDirectory(atPath: desktop.path).isEmpty)
        }
    }

    @Test("collisions preserve files, folders and dangling links; repeats number names")
    func collisions() throws {
        try workspace { _, source, desktop in
            let file = source.appendingPathComponent("report.txt")
            let folder = source.appendingPathComponent("Folder.name")
            try Data("source".utf8).write(to: file)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            try Data("keep".utf8).write(to: desktop.appendingPathComponent("report.txt"))
            try FileManager.default.createSymbolicLink(atPath: desktop.appendingPathComponent("report 2.txt").path,
                                                      withDestinationPath: "missing")
            try FileManager.default.createDirectory(at: desktop.appendingPathComponent("Folder.name"), withIntermediateDirectories: false)
            let items = try DesktopAliasService.capture([file, folder])
            let first = try DesktopAliasService.perform(items: items, in: desktop) { true }
            let second = try DesktopAliasService.perform(items: items, in: desktop) { true }
            #expect(first.map(\.lastPathComponent) == ["report 3.txt", "Folder.name 2"])
            #expect(second.map(\.lastPathComponent) == ["report 4.txt", "Folder.name 3"])
            #expect(try String(contentsOf: desktop.appendingPathComponent("report.txt"), encoding: .utf8) == "keep")
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: desktop.appendingPathComponent("report 2.txt").path) == "missing")
            #expect(try FileManager.default.contentsOfDirectory(atPath: desktop.path).count == 7)
        }
    }

    @Test("disabled, invalid and replaced selections create nothing")
    func invalidSelections() throws {
        try workspace { _, source, desktop in
            let file = source.appendingPathComponent("file")
            try Data("before".utf8).write(to: file)
            let items = try DesktopAliasService.capture([file])
            #expect(throws: FileMoveError.invalidSelection) { try DesktopAliasService.capture([]) }
            #expect(throws: FileMoveError.invalidSelection) { try DesktopAliasService.capture([file, file]) }
            #expect(throws: FileMoveError.invalidSelection) { try DesktopAliasService.capture([URL(fileURLWithPath: "/")]) }
            #expect(throws: DesktopAliasFailure.self) {
                try DesktopAliasService.perform(items: items, in: desktop) { false }
            }
            try Data("replacement".utf8).write(to: file, options: .atomic)
            #expect(throws: DesktopAliasFailure.self) {
                try DesktopAliasService.perform(items: items, in: desktop) { true }
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: desktop.path).isEmpty)
            #expect(try String(contentsOf: file, encoding: .utf8) == "replacement")
        }
    }

    @Test("a partial failure preserves finished aliases and reports exact counts")
    func partialFailure() throws {
        try workspace { _, source, desktop in
            let a = source.appendingPathComponent("a")
            let b = source.appendingPathComponent("b")
            try Data().write(to: a)
            try Data().write(to: b)
            let items = try DesktopAliasService.capture([a, b])
            do {
                try DesktopAliasService.perform(items: items, in: desktop) {
                    !FileManager.default.fileExists(atPath: desktop.appendingPathComponent("a").path)
                }
                Issue.record("Expected a partial failure")
            } catch let failure as DesktopAliasFailure {
                #expect(failure.completed == 1 && failure.total == 2)
            }
            #expect(try resolve(desktop.appendingPathComponent("a")) == a.standardizedFileURL)
            #expect(try FileManager.default.contentsOfDirectory(atPath: desktop.path) == ["a"])
            #expect(FileManager.default.fileExists(atPath: b.path))
        }
    }

    @Test("a concurrent destination at publication is kept and numbering retries")
    func publicationCollision() throws {
        try workspace { _, source, desktop in
            let file = source.appendingPathComponent("file")
            let collision = desktop.appendingPathComponent("file")
            try Data().write(to: file)
            let items = try DesktopAliasService.capture([file])
            var calls = 0
            let aliases = try DesktopAliasService.perform(items: items, in: desktop) {
                calls += 1
                if calls == 3 { try! Data("concurrent".utf8).write(to: collision, options: .withoutOverwriting) }
                return true
            }
            #expect(aliases.map(\.lastPathComponent) == ["file 2"])
            #expect(try String(contentsOf: collision, encoding: .utf8) == "concurrent")
            #expect(try resolve(aliases[0]) == file.standardizedFileURL)
        }
    }

    @Test("aliases to selected aliases and symbolic links retain native resolution")
    func selectedLinks() throws {
        try workspace { _, source, desktop in
            let file = source.appendingPathComponent("original")
            let link = source.appendingPathComponent("symbolic")
            let alias = source.appendingPathComponent("existing-alias")
            try Data("original".utf8).write(to: file)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
            try URL.writeBookmarkData(file.bookmarkData(options: .suitableForBookmarkFile), to: alias)
            let outputs = try DesktopAliasService.perform(items: DesktopAliasService.capture([link, alias]), in: desktop) { true }
            for output in outputs {
                #expect(try output.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile == true)
                // Foundation resolves the reference; source links are not rewritten.
                let resolved = try resolve(output)
                #expect(FileManager.default.fileExists(atPath: resolved.path))
            }
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == file.path)
            #expect(try String(contentsOf: file, encoding: .utf8) == "original")
        }
    }

    @Test("new preference is opt-in, placement persists, grants do not expand scope")
    func preferencesAndAccess() throws {
        try workspace { root, _, _ in
            var preferences = try JSONDecoder().decode(FileMintPreferences.self, from: Data("{}".utf8))
            #expect(!preferences.fileTools.desktopAlias)
            preferences.fileTools.desktopAlias = true
            preferences.fileTools.mainMenuTools.insert(.desktopAlias)
            let saved = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(preferences))
            #expect(saved.fileTools.desktopAlias && saved.fileTools.mainMenuTools.contains(.desktopAlias))
            let store = DesktopAliasAccessStore(file: root.appendingPathComponent("private/access.json"))
            #expect(try store.load().isEmpty)
            let grants = ["example": Data([1, 2, 3])]
            try store.save(grants)
            #expect(try store.load() == grants)
            #expect(saved.monitoredFolderURLs == preferences.monitoredFolderURLs)
            #expect(saved.monitoredFolderBookmarks == preferences.monitoredFolderBookmarks)
            #expect((try FileManager.default.attributesOfItem(atPath: store.file.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        }
    }

    @Test("a redirected Desktop and sources already on Desktop preserve originals")
    func redirectedAndSameFolder() throws {
        try workspace { root, _, desktop in
            let redirected = root.appendingPathComponent("Desktop-link")
            try FileManager.default.createSymbolicLink(at: redirected, withDestinationURL: desktop)
            let file = desktop.appendingPathComponent("original.txt")
            try Data("keep".utf8).write(to: file)
            let outputs = try DesktopAliasService.perform(items: DesktopAliasService.capture([file]), in: redirected) { true }
            #expect(outputs.map(\.lastPathComponent) == ["original 2.txt"])
            #expect(try resolve(outputs[0]) == file.standardizedFileURL)
            #expect(try String(contentsOf: file, encoding: .utf8) == "keep")
        }
    }
}

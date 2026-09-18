import FileMintCore
import Foundation
import Testing

@Suite("Two-step file and folder moves")
struct FileMoveTests {
    private func workspace(_ body: (URL, URL, URL, PendingFileMoveStore) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let target = root.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root, source, target, PendingFileMoveStore(file: root.appendingPathComponent("state/pending.json")))
    }

    @Test("pending items persist, new selections replace them, disabled switches preserve state")
    func persistence() throws {
        try workspace { _, source, _, store in
            let first = source.appendingPathComponent("图片.png")
            let second = source.appendingPathComponent("script.sh")
            try Data([0, 1, 255]).write(to: first)
            try Data("#!/bin/sh".utf8).write(to: second)
            let a = try PendingFileMove.capture(selection: [first])
            try store.save(a)
            #expect(try PendingFileMoveStore(file: store.file).load() == a)
            let b = try PendingFileMove.capture(selection: [second])
            try store.save(b)
            #expect(try store.load()?.items.map(\.source) == [second])
            #expect(a.id != b.id)
            var preferences = FileMintPreferences.default
            preferences.monitoredFolderURLs = [source]
            #expect(!FileMovePolicy.isEnabled(preferences, pending: b))
            preferences.fileTools.isEnabled = true
            #expect(FileMovePolicy.isEnabled(preferences, pending: b))
            preferences.fileTools.move = false
            #expect(!FileMovePolicy.isEnabled(preferences, pending: b))
            #expect(try store.load() == b)
        }
    }

    @Test("binary files, package contents, directories and links move intact")
    func actualMoves() throws {
        try workspace { _, source, target, store in
            let file = source.appendingPathComponent("图 像.png")
            let app = source.appendingPathComponent("Demo.app", isDirectory: true)
            let directory = source.appendingPathComponent("文件夹", isDirectory: true)
            let link = source.appendingPathComponent("link")
            let original = source.appendingPathComponent("untouched")
            try Data([0, 255, 14, 0]).write(to: file)
            try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
            try Data("payload".utf8).write(to: app.appendingPathComponent("Contents/data"))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("keep".utf8).write(to: original)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
            let pending = try PendingFileMove.capture(selection: [file, app, directory, link])
            try store.save(pending)
            try FileMoveService().perform(batchID: pending.id, to: target, store: store) { _ in true }
            #expect(try store.load() == nil)
            #expect(!FileManager.default.fileExists(atPath: file.path))
            #expect(try Data(contentsOf: target.appendingPathComponent("图 像.png")) == Data([0, 255, 14, 0]))
            #expect(try String(contentsOf: target.appendingPathComponent("Demo.app/Contents/data"), encoding: .utf8) == "payload")
            #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("文件夹").path))
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: target.appendingPathComponent("link").path) == original.path)
            #expect(try String(contentsOf: original, encoding: .utf8) == "keep")
        }
    }

    @Test("partial failure keeps only unfinished items and invalidates old menus")
    func partialFailure() throws {
        try workspace { _, source, target, store in
            let a = source.appendingPathComponent("a")
            let b = source.appendingPathComponent("b")
            try Data("a".utf8).write(to: a)
            try Data("source".utf8).write(to: b)
            try Data("existing".utf8).write(to: target.appendingPathComponent("b"))
            let pending = try PendingFileMove.capture(selection: [a, b])
            try store.save(pending)
            #expect(throws: FileMoveError.destinationExists) {
                try FileMoveService().perform(batchID: pending.id, to: target, store: store) { _ in true }
            }
            let loaded = try store.load()
            let remaining = try #require(loaded)
            #expect(remaining.items.map(\.source) == [b])
            #expect(remaining.id != pending.id)
            #expect(try String(contentsOf: b, encoding: .utf8) == "source")
            #expect(try String(contentsOf: target.appendingPathComponent("b"), encoding: .utf8) == "existing")
            #expect(throws: FileMoveError.staleRequest) {
                try FileMoveService().perform(batchID: pending.id, to: target, store: store) { _ in true }
            }
        }
    }

    @Test("replaced sources and disabled actions never move the wrong item")
    func identityAndSwitches() throws {
        try workspace { _, source, target, store in
            let file = source.appendingPathComponent("note")
            try Data("old".utf8).write(to: file)
            let pending = try PendingFileMove.capture(selection: [file])
            try store.save(pending)
            #expect(throws: FileMoveError.disabled) {
                try FileMoveService().perform(batchID: pending.id, to: target, store: store) { _ in false }
            }
            // Atomic replacement guarantees a different object while retaining the name.
            try Data("replacement".utf8).write(to: file, options: .atomic)
            #expect(throws: FileMoveError.sourceChanged) {
                try FileMoveService().perform(batchID: pending.id, to: target, store: store) { _ in true }
            }
            #expect(try String(contentsOf: file, encoding: .utf8) == "replacement")
            #expect(try store.load() == pending)
        }
    }

    @Test("same folder, nested selections and symlink descendant destinations are rejected")
    func unsafeDestinations() throws {
        try workspace { root, source, _, _ in
            let directory = source.appendingPathComponent("parent", isDirectory: true)
            let child = directory.appendingPathComponent("child", isDirectory: true)
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            let alias = root.appendingPathComponent("alias", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: child)
            #expect(throws: FileMoveError.invalidSelection) { try PendingFileMove.capture(selection: [directory, child]) }
            let item = try FileMoveItem.capture(directory)
            for destination in [source, directory, child, alias] {
                #expect(throws: FileMoveError.invalidDestination) { try FileMoveService().move(item: item, to: destination) }
            }
            #expect(FileManager.default.fileExists(atPath: child.path))
        }
    }

    @Test("dangling target links are never overwritten")
    func danglingCollision() throws {
        try workspace { root, source, target, _ in
            let file = source.appendingPathComponent("note")
            try Data("keep".utf8).write(to: file)
            let missing = root.appendingPathComponent("missing")
            try FileManager.default.createSymbolicLink(at: target.appendingPathComponent("note"), withDestinationURL: missing)
            #expect(throws: FileMoveError.destinationExists) {
                try FileMoveService().move(item: FileMoveItem.capture(file), to: target)
            }
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: target.appendingPathComponent("note").path) == missing.path)
        }
    }

    @Test("only unambiguous folder/background menus accept a destination")
    func menuDestinations() {
        let root = URL(fileURLWithPath: "/work", isDirectory: true)
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        #expect(FileMovePolicy.destination(target: root, isContainer: true, selectionCount: 0,
            targetIsDirectory: false, targetIsPackage: false, isItemMenu: false, preferences: preferences) == root)
        for (count, directory, package, itemMenu) in [(1, false, false, true), (2, true, false, true),
                                                    (1, true, true, true), (1, true, false, false)] {
            #expect(FileMovePolicy.destination(target: root, isContainer: false, selectionCount: count,
                targetIsDirectory: directory, targetIsPackage: package, isItemMenu: itemMenu, preferences: preferences) == nil)
        }
    }

    @Test("transport is single-use and expiring, while pending state has no clock")
    func tickets() throws {
        try workspace { root, source, target, _ in
            let tickets = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
            let date = Date(timeIntervalSince1970: 1_000)
            let request = FileOperationRequest.prepare([source.appendingPathComponent("file")])
            let url = try tickets.enqueue(request, now: date)
            #expect(try tickets.consume(url, now: date) == request)
            #expect(try tickets.consume(url, now: date) == nil)
            let expired = try tickets.enqueue(.perform(batchID: UUID(), destination: target), now: date)
            #expect(try tickets.consume(expired, now: date.addingTimeInterval(61)) == nil)
            #expect(try tickets.consume(URL(string: "filemint://move?destination=/work")!, now: date) == nil)
            #expect(try tickets.consume(URL(string: "filemint://move?id=../file")!, now: date) == nil)
        }
    }
}

@testable import FileMintCore
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

    @Test("per-item policy stops a batch after the last allowed source")
    func perItemPolicy() throws {
        try workspace { _, source, target, store in
            let first = source.appendingPathComponent("first")
            let second = source.appendingPathComponent("second")
            try Data("one".utf8).write(to: first)
            try Data("two".utf8).write(to: second)
            let pending = try PendingFileMove.capture(selection: [first, second])
            try store.save(pending)
            #expect(throws: FileMoveError.disabled) {
                try FileMoveService().performPerItem(batchID: pending.id, to: target, store: store) {
                    $0.source == first
                }
            }
            #expect(try String(contentsOf: target.appendingPathComponent("first"), encoding: .utf8) == "one")
            #expect(try String(contentsOf: second, encoding: .utf8) == "two")
            #expect(try store.load()?.items.map(\.source) == [second])
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

    @Test("a replacement arriving between identity check and claim is restored, not moved")
    func replacementDuringClaim() throws {
        try workspace { _, source, _, _ in
            let file = source.appendingPathComponent("note")
            try Data("original".utf8).write(to: file)
            let captured = try FileMoveItem.capture(file)
            #expect(throws: FileMoveError.sourceChanged) {
                try StagedFileEntry.claim(captured) {
                    try Data("replacement".utf8).write(to: file, options: .atomic)
                }
            }
            #expect(try String(contentsOf: file, encoding: .utf8) == "replacement")
            #expect(try FileManager.default.contentsOfDirectory(atPath: source.path) == ["note"])
        }
    }

    @Test("large flat selections validate without pairwise path comparisons")
    func largeSelection() throws {
        try workspace { _, source, _, _ in
            let files = (0..<256).map { source.appendingPathComponent("item-\($0)") }
            for file in files { try Data().write(to: file) }
            #expect(try PendingFileMove.capture(selection: files).items.count == files.count)
        }
    }

    @Test("copy fallback publishes files and symlinks exclusively and restores on collision")
    func copyFallback() throws {
        try workspace { root, source, target, _ in
            let file = source.appendingPathComponent("note")
            let link = source.appendingPathComponent("link")
            try Data("source".utf8).write(to: file)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
            var service = FileMoveService()
            service.retire = { original in
                try FileManager.default.moveItem(at: original, to: root.appendingPathComponent(UUID().uuidString))
            }
            try service.move(item: FileMoveItem.capture(link), to: target, forceCopy: true)
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: target.appendingPathComponent("link").path) == file.path)
            #expect(!FileManager.default.fileExists(atPath: link.path))

            try Data("existing".utf8).write(to: target.appendingPathComponent("note"))
            #expect(throws: FileMoveError.destinationExists) {
                try service.move(item: FileMoveItem.capture(file), to: target, forceCopy: true)
            }
            #expect(try String(contentsOf: file, encoding: .utf8) == "source")
            #expect(try String(contentsOf: target.appendingPathComponent("note"), encoding: .utf8) == "existing")

            try FileManager.default.removeItem(at: target.appendingPathComponent("note"))
            try service.move(item: FileMoveItem.capture(file), to: target, forceCopy: true)
            #expect(try String(contentsOf: target.appendingPathComponent("note"), encoding: .utf8) == "source")
            #expect(!FileManager.default.fileExists(atPath: file.path))
        }
    }

    @Test("a queued move ticket cannot bind a replacement after authorization")
    func queuedReplacement() throws {
        try workspace { root, source, _, _ in
            let file = source.appendingPathComponent("item")
            try Data([1]).write(to: file)
            let tickets = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
            let url = try tickets.enqueue(.prepare([file]))
            guard case .prepare(let items) = try tickets.consume(url) else { Issue.record("Missing ticket"); return }
            try Data([2]).write(to: file, options: .atomic)
            #expect(throws: FileMoveError.sourceChanged) { try PendingFileMove.validate(captured: items) }
        }
    }

    @Test("a retry advances past an already published item and moves the rest")
    func publishedCheckpoint() throws {
        for crossVolume in [false, true] {
            try workspace { root, source, target, store in
                let a = source.appendingPathComponent("a"), b = source.appendingPathComponent("b")
                try Data([1]).write(to: a)
                try Data([2]).write(to: b)
                let pending = try PendingFileMove.capture(selection: [a, b])
                try store.save(pending)
                var service = FileMoveService()
                service.forceCopy = crossVolume
                service.retire = { try FileManager.default.moveItem(at: $0, to: root.appendingPathComponent(UUID().uuidString)) }
                service.checkpoint = { if $0 == .published { throw InterruptedFileMove() } }
                #expect(throws: InterruptedFileMove.self) {
                    try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
                }
                #expect(try Data(contentsOf: target.appendingPathComponent("a")) == Data([1]))
                #expect(throws: FileMoveError.self) { try store.replaceSelection(PendingFileMove(items: [])) }
                service.checkpoint = nil
                try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
                #expect(try store.load() == nil)
                #expect(try Data(contentsOf: target.appendingPathComponent("b")) == Data([2]))
            }
        }
    }

    @Test("rollback conflicts keep the exact staged original before and after copy publication")
    func blockedRestore() throws {
        for published in [false, true] {
            for freeOriginalName in [false, true] {
                try workspace { root, source, target, store in
                    let name = "report.txt"
                    let file = source.appendingPathComponent(name), output = target.appendingPathComponent(name)
                    let heldReplacement = source.appendingPathComponent("replacement.txt")
                    let retired = root.appendingPathComponent("retired")
                    try Data([1]).write(to: file)
                    let pending = try PendingFileMove.capture(selection: [file])
                    try store.save(pending)
                    var service = FileMoveService()
                    service.forceCopy = published
                    service.retire = { try FileManager.default.moveItem(at: $0, to: retired) }
                    service.checkpoint = { step in
                        if step == (published ? .published : .claimed) {
                            try Data([2]).write(to: file, options: .withoutOverwriting)
                            throw CocoaError(.fileWriteNoPermission)
                        }
                    }
                    do {
                        try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
                        Issue.record("Expected the replacement to block restoration")
                    } catch FileMoveError.restoreBlocked(let staged, let directory) {
                        let progress = try #require(try store.load()?.progress)
                        #expect(progress.sourceTransition == .restoring)
                        #expect(staged.path == progress.sourceStage.source.appendingPathComponent(name).path)
                        #expect(directory.path == target.resolvingSymlinksInPath().standardizedFileURL.path)
                        #expect(try Data(contentsOf: staged) == Data([1]))
                        if published && !freeOriginalName {
                            // A published copy alone cannot prove retirement if
                            // the user temporarily moves the staged original.
                            let elsewhere = source.appendingPathComponent("manual-recovery.txt")
                            try FileManager.default.moveItem(at: staged, to: elsewhere)
                            #expect(throws: FileMoveError.recoveryRequired(staged)) {
                                try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
                            }
                            try FileManager.default.moveItem(at: elsewhere, to: staged)
                        }
                    }
                    #expect(try Data(contentsOf: file) == Data([2]))
                    #expect(FileManager.default.fileExists(atPath: output.path) == published)
                    let replacementSelection = try PendingFileMove.capture(selection: [file])
                    #expect(throws: FileMoveError.self) { try store.replaceSelection(replacementSelection) }
                    service.checkpoint = nil
                    if freeOriginalName {
                        try FileManager.default.moveItem(at: file, to: heldReplacement)
                        let expected: FileMoveError = published ? .copiedSourceRetained : .sourceRestored
                        #expect(throws: expected) {
                            try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
                        }
                        #expect(try Data(contentsOf: file) == Data([1]))
                        #expect(try Data(contentsOf: heldReplacement) == Data([2]))
                        if published { #expect(try Data(contentsOf: output) == Data([1])) }
                        else { #expect(!FileManager.default.fileExists(atPath: output.path)) }
                        try store.replaceSelection(PendingFileMove.capture(selection: [heldReplacement]))
                    } else {
                        try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
                        #expect(try store.load() == nil)
                        #expect(try Data(contentsOf: file) == Data([2]))
                        #expect(try Data(contentsOf: output) == Data([1]))
                        if published { #expect(try Data(contentsOf: retired) == Data([1])) }
                        try store.replaceSelection(replacementSelection)
                    }
                }
            }
        }
    }

    @Test("interrupted copies preserve an unknown object in the destination scratch directory")
    func unknownPartialCopy() throws {
        try workspace { root, source, target, store in
            let file = source.appendingPathComponent("item")
            try Data([1]).write(to: file)
            let pending = try PendingFileMove.capture(selection: [file])
            try store.save(pending)
            var service = FileMoveService()
            service.forceCopy = true
            service.retire = { try FileManager.default.moveItem(at: $0, to: root.appendingPathComponent("retained")) }
            service.checkpoint = { if $0 == .copied { throw InterruptedFileMove() } }
            #expect(throws: InterruptedFileMove.self) {
                try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
            }
            let folder = try #require(try store.load()?.progress?.copyStage?.source)
            let partial = folder.appendingPathComponent("item")
            try FileManager.default.removeItem(at: partial)
            try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: false)
            let extra = partial.appendingPathComponent("keep.txt")
            try Data([42]).write(to: extra)
            service.checkpoint = nil
            try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
            #expect(try Data(contentsOf: extra) == Data([42]))
            #expect(try Data(contentsOf: target.appendingPathComponent("item")) == Data([1]))
        }
    }

    @Test("cross-volume copies detect changes through open file and child descriptors")
    func modifiedWhileCopying() throws {
        for folder in [false, true] {
            try workspace { _, source, target, _ in
                let item = source.appendingPathComponent("source")
                if folder { try FileManager.default.createDirectory(at: item, withIntermediateDirectories: false) }
                let file = folder ? item.appendingPathComponent("child") : item
                try Data([1]).write(to: file)
                let handle = try FileHandle(forWritingTo: file)
                defer { try? handle.close() }
                try handle.seekToEnd()
                var service = FileMoveService()
                service.checkpoint = { if $0 == .copied { try handle.write(contentsOf: Data([2])) } }
                service.retire = { _ in Issue.record("Changed source must not be retired") }
                #expect(throws: FileMoveError.sourceChanged) {
                    try service.move(item: FileMoveItem.capture(item), to: target, forceCopy: true)
                }
                #expect(try Data(contentsOf: file) == Data([1, 2]))
                #expect(try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty)
            }
        }
    }

    @Test("source retirement failure is retryable and an open writer keeps its recoverable original")
    func recoverableRetirement() throws {
        try workspace { root, source, target, store in
            let file = source.appendingPathComponent("file")
            try Data([1]).write(to: file)
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            let pending = try PendingFileMove.capture(selection: [file])
            try store.save(pending)
            var service = FileMoveService()
            service.forceCopy = true
            service.retire = { _ in throw CocoaError(.fileWriteNoPermission) }
            #expect(throws: FileMoveError.copiedSourceRetained) {
                try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
            }
            let published = target.appendingPathComponent("file")
            let copied = try FileMoveItem.capture(published)
            #expect(try Data(contentsOf: file) == Data([1]))
            #expect(try store.load()?.progress?.originalRestored == true)
            let retained = root.appendingPathComponent("retained")
            service.retire = { try FileManager.default.moveItem(at: $0, to: retained) }
            try service.perform(batchID: pending.id, to: target, store: store) { _ in true }
            try handle.write(contentsOf: Data([2]))
            #expect(try Data(contentsOf: retained) == Data([1, 2]))
            #expect(try Data(contentsOf: published) == Data([1]))
            #expect(try FileMoveItem.capture(published) == copied)
            #expect(try store.load() == nil)
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
            let file = source.appendingPathComponent("file")
            try Data().write(to: file)
            let request = try FileOperationRequest.prepare([file])
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

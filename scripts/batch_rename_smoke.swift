import AppKit
import Darwin
import FileMintCore
import SwiftUI

private struct RenameSmokeFailure: Error { let message: String }

private final class RenameSmokeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; count += 1; return count }
}

private final class RenameSmokePreviewGate: @unchecked Sendable {
    private let counter = RenameSmokeCounter()
    private let gate = DispatchSemaphore(value: 0)
    func waitOnce() throws {
        if counter.next() == 1, gate.wait(timeout: .now() + 15) != .success {
            throw RenameSmokeFailure(message: "Preview gate timed out")
        }
    }
    func release() { gate.signal() }
}

@main
@MainActor
final class BatchRenameSmoke: NSObject, NSApplicationDelegate {
    private var activeController: BatchRenameController?
    private var assertions = 0

    static func main() {
        let app = NSApplication.shared
        let delegate = BatchRenameSmoke()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do {
                if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--crash-fixture" {
                    try await Self.crashChild(URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true))
                    throw RenameSmokeFailure(message: "Crash child returned without interruption")
                }
                let root = try makeRunRoot()
                if ProcessInfo.processInfo.environment["FILEMINT_BATCH_RENAME_MODE"] == "external-export" {
                    try await externalExport(root: root)
                    print("PASS external recovery export: \(assertions) assertions; confirmation/save cancellation, disabled-switch access, manual retirement and original preservation")
                    fflush(stdout)
                    NSApp.terminate(nil)
                    return
                }
                let clipboardCount = NSPasteboard.general.changeCount
                print("CHECK remembered folder access")
                try await authorizationScenarios(root: root)
                try await renumberedAuthorizationScenarios(root: root)
                print("CHECK production engine")
                try await engineScenarios(root: root)
                print("CHECK interrupted recovery")
                try await interruptedRecovery(root: root)
                print("CHECK native previews and keyboard")
                try await previewScenarios(root: root)
                print("CHECK serialized coordinator")
                try await coordinatorScenarios(root: root)
                try require(NSPasteboard.general.changeCount == clipboardCount, "Fixture changed clipboard")
                print("PASS batch rename sandbox: \(assertions) assertions; mixed files/folders, swap, case, rollback, crash recovery, undo, latest preview, keyboard dispatch, native view renders and serialized ticket intake")
                print("Fixture artifacts: \(root.path)")
                fflush(stdout)
                NSApp.terminate(nil)
            } catch {
                // Only fixed assertion labels/codes: no user paths or file contents.
                if let failure = error as? RenameSmokeFailure { print("FAIL batch rename sandbox: \(failure.message)") }
                else { let value = error as NSError; print("FAIL batch rename sandbox: \(value.domain) \(value.code)") }
                fflush(stdout)
                exit(1)
            }
        }
    }

    private func makeRunRoot() throws -> URL {
        guard Bundle.main.bundleIdentifier == "io.github.daigua.filemint.batch-rename-smoke",
              let runID = Bundle.main.object(forInfoDictionaryKey: "FixtureRunID") as? String,
              !runID.contains("/"), !runID.isEmpty else {
            throw RenameSmokeFailure(message: "Unpublished or wrong fixture identity")
        }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FileMintBatchRenameQA", isDirectory: true)
            .appendingPathComponent(runID, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    nonisolated private static func fixture(_ root: URL, names: [String] = ["First.txt", "Folder"]) throws -> [URL] {
        let parent = root.appendingPathComponent("items", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        var values: [URL] = []
        for (index, name) in names.enumerated() {
            let url = parent.appendingPathComponent(name)
            if name == "Folder" {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                try Data("nested-original".utf8).write(to: url.appendingPathComponent("child.txt"), options: .withoutOverwriting)
            } else { try Data("original-\(index)".utf8).write(to: url, options: .withoutOverwriting) }
            values.append(url)
        }
        return values
    }

    nonisolated private static func prepared(root: URL, selection: [URL]) throws -> (BatchRenameService, BatchRenameSession) {
        let service = BatchRenameService(store: BatchRenameStore(directory: root.appendingPathComponent("state", isDirectory: true)))
        let capture = try BatchRenameSelection.capture(selection: selection)
        let bookmark = try capture.parent.bookmarkData(options: .withSecurityScope,
            includingResourceValuesForKeys: nil, relativeTo: nil)
        let session = try service.prepare(selection: capture, parentBookmark: bookmark,
            observationRoots: [root], privateLocations: [root.appendingPathComponent("state", isDirectory: true)])
        return (service, session)
    }

    nonisolated private static func plan(_ session: BatchRenameSession, service: BatchRenameService,
                             mode: BatchRenameMode) throws -> BatchRenamePlan {
        let proposed = try BatchRenamePlanner.preview(batch: session.batch, revision: 1, mode: mode,
            caseSensitivity: session.caseSensitivity, nativeNameByteLimit: session.nativeNameByteLimit)
        let checked = try BatchRenamePlanner.checkingTargets(of: proposed,
            using: service.observeTargets(preview: proposed, session: session))
        return try BatchRenamePlanner.freeze(checked)
    }

    private func authorizationScenarios(root: URL) async throws {
        let directory = root.appendingPathComponent("remembered-access", isDirectory: true)
        let selection = try Self.fixture(directory, names: ["a.txt", "b.txt"])
        let captured = try await Task.detached(priority: .userInitiated) {
            try BatchRenameSelection.capture(selection: selection)
        }.value
        let cache = BatchRenameAccessStore(file: directory.appendingPathComponent("folder-access.json"))
        let bookmark = try captured.parent.bookmarkData(options: .withSecurityScope,
            includingResourceValuesForKeys: nil, relativeTo: nil)
        try cache.remember(parent: captured.parent, identity: captured.parentIdentity, bookmark: bookmark)
        var pickerCount = 0
        for _ in 0..<2 {
            let access = BatchRenameAccess(store: BatchRenameAccessStore(file: cache.file),
                chooseDirectory: { _, _ in pickerCount += 1; return nil })
            let restored = try await access.authorize(parent: captured.parent, identity: captured.parentIdentity,
                bookmark: nil, allowRelocation: false, language: .english)
            try require(restored != nil && pickerCount == 0, "Fresh access instance did not restore the remembered parent")
            access.release()
        }
        try cache.save([captured.parent.path: .init(identity: captured.parentIdentity, bookmark: Data([255]))])
        let invalidBytes = try Data(contentsOf: cache.file)
        let invalid = BatchRenameAccess(store: cache, chooseDirectory: { _, _ in pickerCount += 1; return nil })
        let cancelled = try await invalid.authorize(parent: captured.parent, identity: captured.parentIdentity,
            bookmark: bookmark, allowRelocation: false, language: .english)
        try require(cancelled == nil && pickerCount == 1, "Invalid saved authority did not request renewed consent")
        invalid.release()
        try require(try Data(contentsOf: cache.file) == invalidBytes, "Cancelled renewal changed remembered authority")

        try Data("damaged".utf8).write(to: cache.file)
        let recovery = BatchRenameAccess(chooseDirectory: { _, _ in pickerCount += 1; return nil })
        let original = try await recovery.authorize(parent: captured.parent, identity: captured.parentIdentity,
            bookmark: bookmark, allowRelocation: true, language: .english)
        try require(original?.0.path == captured.parent.path && pickerCount == 1,
                    "Independent operation bookmark could not restore access with a damaged cache")
        recovery.release()

        let replacementCache = BatchRenameAccessStore(file: directory.appendingPathComponent("replacement-access.json"))
        try replacementCache.remember(parent: captured.parent, identity: captured.parentIdentity, bookmark: bookmark)
        let displaced = directory.appendingPathComponent("original-parent", isDirectory: true)
        try FileManager.default.moveItem(at: captured.parent, to: displaced)
        try FileManager.default.createDirectory(at: captured.parent, withIntermediateDirectories: false)
        for name in ["a.txt", "b.txt"] { try Data("replacement".utf8).write(to: captured.parent.appendingPathComponent(name)) }
        let replacement = try BatchRenameSelection.capture(selection: ["a.txt", "b.txt"].map { captured.parent.appendingPathComponent($0) })
        let replaced = BatchRenameAccess(store: replacementCache, chooseDirectory: { _, _ in pickerCount += 1; return nil })
        let denied = try await replaced.authorize(parent: replacement.parent, identity: replacement.parentIdentity,
            bookmark: nil, allowRelocation: false, language: .english)
        try require(denied == nil && pickerCount == 2, "Replacement parent reused another directory's saved authority")
        replaced.release()

    }

    private func renumberedAuthorizationScenarios(root: URL) async throws {
        let directory = root.appendingPathComponent("renumbered-access", isDirectory: true)
        let names = ["a.txt", "b.txt"]
        let selection = try Self.fixture(directory, names: names)
        let captured = try BatchRenameSelection.capture(selection: selection)
        let bookmark = try captured.parent.bookmarkData(options: .withSecurityScope,
            includingResourceValuesForKeys: nil, relativeTo: nil)
        var fields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(captured.parentIdentity)) as! [String: Any]
        fields["device"] = captured.parentIdentity.device + 37
        let previous = try JSONDecoder().decode(BatchRenameIdentity.self, from: JSONSerialization.data(withJSONObject: fields))
        let cache = BatchRenameAccessStore(file: directory.appendingPathComponent("folder-access.json"))
        try cache.save([captured.parent.path: .init(identity: previous, bookmark: bookmark)])
        var pickerCount = 0
        for moved in [false, true] {
            let parent = moved ? directory.appendingPathComponent("moved-items", isDirectory: true) : captured.parent
            if moved { try FileManager.default.moveItem(at: captured.parent, to: parent) }
            let snapshot = try BatchRenameSelection.capture(selection: names.map { parent.appendingPathComponent($0) })
            let access = BatchRenameAccess(store: BatchRenameAccessStore(file: cache.file),
                chooseDirectory: { _, _ in pickerCount += 1; return nil })
            defer { access.release() }
            let restored = try await access.authorize(parent: snapshot.parent, identity: snapshot.parentIdentity,
                bookmark: nil, allowRelocation: false, language: .english)
            try require(restored != nil && pickerCount == 0,
                        "Device renumbering or relocation prompted for an already granted directory")
            guard let (resolved, refreshed) = restored else { throw RenameSmokeFailure(message: "Missing restored authority") }
            try require(resolved.path == parent.path && (try snapshot.parentIdentity.matchesDirectory(at: resolved)),
                        "Restored grant did not retain the current operation identity")
            let service = BatchRenameService(store: BatchRenameStore(directory: directory.appendingPathComponent("state")))
            _ = try service.prepare(selection: snapshot, parentBookmark: refreshed,
                observationRoots: [directory], privateLocations: [cache.file])
            if moved {
                try cache.remember(parent: resolved, identity: snapshot.parentIdentity, bookmark: refreshed)
                let grants = try cache.load()
                try require(grants.count == 1 && grants[captured.parent.path] == nil
                            && grants[resolved.path]?.identity == snapshot.parentIdentity,
                            "Refreshing a relocated grant retained the old mount/path entry")
                try require(grants[resolved.path]?.volumeUUID != nil, "Refreshed bookmark omitted persistent volume identity")
            }
        }
    }

    private func engineScenarios(root: URL) async throws {
        let evidence = try await Task.detached(priority: .userInitiated) { () throws -> Int in
            var count = 0
            func check(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
                guard try condition() else { throw RenameSmokeFailure(message: label) }; count += 1
            }
            for (kind, names, mode) in [
                ("mixed", ["First.txt", "Folder"], BatchRenameMode.rules([.prepend("Renamed_")])),
                ("case", ["alpha.txt", "beta.txt"], .rules([.uppercase]))
            ] {
                let directory = root.appendingPathComponent(kind, isDirectory: true)
                let selection = try Self.fixture(directory, names: names)
                let (service, session) = try Self.prepared(root: directory, selection: selection)
                let plan = try Self.plan(session, service: service, mode: mode)
                let result = try service.execute(plan: plan, session: session, shouldContinue: { true })
                try check(result.outcome == .renamed && result.renamedCount == 2, "Mixed/case rename did not complete")
                if kind == "mixed" {
                    try check(String(contentsOf: session.parentURL.appendingPathComponent("Renamed_Folder/child.txt"), encoding: .utf8) == "nested-original", "Directory descendant changed")
                }
                let undo = try service.undoPreview(parentURL: session.parentURL,
                    observationRoots: [directory], privateLocations: [directory.appendingPathComponent("state")])
                let reverted = try service.undo(preview: undo, shouldContinue: { true })
                try check(reverted.outcome == .undone, "Undo did not complete")
                try check(String(contentsOf: selection[0], encoding: .utf8) == "original-0", "Undo changed file bytes")
                try check(!BatchRenameStore(directory: directory.appendingPathComponent("state")).status().canUndo, "Undo generated a redo receipt")
            }

            let swappedRoot = root.appendingPathComponent("swap", isDirectory: true)
            let swapped = try Self.fixture(swappedRoot, names: ["Alpha.txt", "Beta.txt"])
            let (swapService, swapSession) = try Self.prepared(root: swappedRoot, selection: swapped)
            let list = try BatchRenameNameList(text: "Beta\nAlpha", rowIDs: BatchRenamePlanner.orderedRowIDs(in: swapSession.batch))
            let swapPlan = try Self.plan(swapSession, service: swapService, mode: .nameList(list))
            let swapResult = try swapService.execute(plan: swapPlan, session: swapSession, shouldContinue: { true })
            try check(swapResult.outcome == .renamed, "Swap did not complete")
            try check(String(contentsOf: swapped[0], encoding: .utf8) == "original-1", "Swap overwrote first original")
            try check(String(contentsOf: swapped[1], encoding: .utf8) == "original-0", "Swap overwrote second original")

            for stopAt in [3, 5] {
                let directory = root.appendingPathComponent("rollback-\(stopAt)", isDirectory: true)
                let selected = try Self.fixture(directory)
                let (service, session) = try Self.prepared(root: directory, selection: selected)
                let proposed = try Self.plan(session, service: service, mode: .rules([.prepend("Changed_")]))
                let counter = RenameSmokeCounter()
                let result = try service.execute(plan: proposed, session: session, shouldContinue: { counter.next() < stopAt })
                try check(result.outcome == .restored && result.restoredCount == 2, "Cancellation did not fully restore")
                try check(String(contentsOf: selected[0], encoding: .utf8) == "original-0", "Rollback changed original file")
                try check(String(contentsOf: selected[1].appendingPathComponent("child.txt"), encoding: .utf8) == "nested-original", "Rollback changed directory contents")
                try check(!BatchRenameStore(directory: directory.appendingPathComponent("state")).status().hasUnresolvedOperation, "Restored cancellation left a blocker")
            }
            return count
        }.value
        assertions += evidence
    }

    private static func crashChild(_ root: URL) async throws {
        guard root.deletingLastPathComponent().lastPathComponent.count == 36,
              root.lastPathComponent == "interrupted",
              root.path.contains("/FileMintBatchRenameQA/") else {
            throw RenameSmokeFailure(message: "Invalid owned crash fixture")
        }
        try await Task.detached(priority: .userInitiated) {
            let selection = try Self.fixture(root)
            let (service, session) = try Self.prepared(root: root, selection: selection)
            let plan = try Self.plan(session, service: service, mode: .rules([.prepend("Changed_")]))
            let counter = RenameSmokeCounter()
            _ = try service.execute(plan: plan, session: session, shouldContinue: {
                // Production ordering: manifest+stage precede call two, and the
                // first original is staged before call three. Never fake a log.
                if counter.next() == 3 { _exit(73) }
                return true
            })
        }.value
    }

    private func interruptedRecovery(root: URL) async throws {
        let directory = root.appendingPathComponent("interrupted", isDirectory: true)
        let executable = try unwrap(Bundle.main.executableURL, "Missing fixture executable")
        let status = try await Task.detached(priority: .userInitiated) {
            let child = Process()
            child.executableURL = executable
            child.arguments = ["--crash-fixture", directory.path]
            child.standardOutput = FileHandle.nullDevice
            child.standardError = FileHandle.nullDevice
            try child.run()
            child.waitUntilExit()
            return child.terminationStatus
        }.value
        try require(status == 73, "Child failed before the intended crash boundary")
        let store = BatchRenameStore(directory: directory.appendingPathComponent("state", isDirectory: true))
        try require(store.status().hasUnresolvedOperation, "Interrupted operation was not discovered")
        let result = try await Task.detached(priority: .userInitiated) {
            try BatchRenameService(store: store).restore(parentURL: directory.appendingPathComponent("items", isDirectory: true))
        }.value
        try require(result.outcome == .restored && result.restoredCount == 2, "Crash recovery did not fully restore")
        try require(!store.status().hasUnresolvedOperation, "Crash recovery left a blocker")
        try require(try String(contentsOf: directory.appendingPathComponent("items/First.txt"), encoding: .utf8) == "original-0", "Crash recovery changed original bytes")
        try require(try String(contentsOf: directory.appendingPathComponent("items/Folder/child.txt"), encoding: .utf8) == "nested-original", "Crash recovery changed directory contents")
    }

    private func previewScenarios(root: URL) async throws {
        for (language, appearance) in [(AppLanguage.chinese, NSAppearance.Name.aqua), (.english, .darkAqua)] {
            let directory = root.appendingPathComponent("ui-\(language.rawValue)", isDirectory: true)
            let (service, session) = try await Task.detached(priority: .userInitiated) {
                let selection = try Self.fixture(directory)
                return try Self.prepared(root: directory, selection: selection)
            }.value
            NSApp.appearance = NSAppearance(named: appearance)
            let gate = RenameSmokePreviewGate()
            let controller = BatchRenameController()
            activeController = controller
            let presentation = Task {
                try await controller.present(session: session, language: language, checkTargets: { preview in
                    try gate.waitOnce()
                    return try service.observeTargets(preview: preview, session: session)
                }, execute: { plan, continuation in
                    try service.execute(plan: plan, session: session, shouldContinue: continuation)
                })
            }
            try await waitUntil { controller.isChecking && controller.rows.count == 2 }
            controller.addRule(.prepend)
            var draft = try unwrap(controller.rules.first, "Missing prepend draft")
            draft.text = "Old_"; controller.updateRule(draft)
            try require(!controller.canSubmit, "Checking preview enabled submission")
            draft.text = "Current_"; controller.updateRule(draft)
            gate.release()
            try await waitUntil { !controller.isChecking && controller.canSubmit }
            try require(controller.rows.allSatisfy { $0.target.hasPrefix("Current_") }, "Obsolete preview replaced the latest revision")
            let panel = try unwrap(NSApp.windows.first { $0 is NSPanel && $0.isVisible }, "Missing rename panel")
            try require(panel.isKeyWindow && NSApp.isActive, "Rename panel did not take focus")
            panel.appearance = NSAppearance(named: appearance)
            try await Task.sleep(for: .milliseconds(180))
            try render(panel, to: root.appendingPathComponent("preview-\(language.rawValue).png"))
            let ruleField = try unwrap(descendant(in: panel.contentView, matching: { (field: NSTextField) in
                field.isEditable && field.stringValue == "Current_"
            }), "Missing native rule text field")
            try require(panel.makeFirstResponder(ruleField), "Cannot focus the native rule text field")
            try sendKey("\r", code: 36, modifiers: [], window: panel)
            try await Task.sleep(for: .milliseconds(120))
            try require(!controller.isRunning && controller.result == nil, "Ordinary Return committed a rename")
            // Ending text-field editing may deliver a binding update and start
            // another preview. A keyboard commit must wait for that revision.
            try await waitUntil { !controller.isChecking && controller.canSubmit }
            if ProcessInfo.processInfo.environment["FILEMINT_BATCH_RENAME_INTERACTIVE"] == "1" {
                print("READY native batch rename \(language.rawValue); fixture artifacts: \(root.path)")
                fflush(stdout)
                _ = try await presentation.value
                activeController = nil
                continue
            }
            // The production submit action and engine run, while this fixture
            // owns every input and all private operation records.
            try sendKey("\r", code: 36, modifiers: .command, window: panel)
            try await waitUntil { !controller.isRunning && controller.result != nil }
            try require(controller.result?.outcome == .renamed, "Native submit did not rename")
            try render(panel, to: root.appendingPathComponent("result-\(language.rawValue).png"))
            try sendKey("\u{1b}", code: 53, modifiers: [], window: panel)
            try await waitUntil { !panel.isVisible }
            _ = try await presentation.value
            activeController = nil
        }
        try await maximumPreview(root: root)
    }

    private func maximumPreview(root: URL) async throws {
        let directory = root.appendingPathComponent("maximum-preview", isDirectory: true)
        let (service, session) = try await Task.detached(priority: .userInitiated) {
            let selected = try Self.fixture(directory, names: (0..<1_000).map { "Item-\($0).txt" })
            return try Self.prepared(root: directory, selection: selected)
        }.value
        let controller = BatchRenameController()
        activeController = controller
        let presentation = Task {
            try await controller.present(session: session, language: .english, checkTargets: { preview in
                try service.observeTargets(preview: preview, session: session)
            }, execute: { plan, continuation in
                try service.execute(plan: plan, session: session, shouldContinue: continuation)
            })
        }
        try await waitUntil { !controller.isChecking && controller.rows.count == 1_000 }
        controller.chooseMode(.nameList)
        let list = (0..<1_000).map { "Revised-\($0)" }.joined(separator: "\n")
        controller.setListText(list)
        try await waitUntil { !controller.isChecking && controller.canSubmit }
        try require(controller.rows.count == 1_000 && controller.rows.allSatisfy { $0.target.hasPrefix("Revised-") && $0.target.hasSuffix(".txt") }, "Name-list preview lost rows or protected suffixes")
        controller.setListText(String(repeating: "x", count: BatchRenameNameList.maximumBytes + 1))
        try require(controller.listText == list, "Oversized list edit replaced the previous draft")
        let panel = try unwrap(NSApp.windows.first { $0 is NSPanel && $0.isVisible }, "Missing thousand-row panel")
        try await Task.sleep(for: .milliseconds(180))
        try render(panel, to: root.appendingPathComponent("name-list-1000.png"))
        let editor = try unwrap(descendant(in: panel.contentView, matching: { (view: NSTextView) in
            view.isEditable && view.string == list
        }), "Missing native name-list editor")
        try require(panel.makeFirstResponder(editor), "Cannot focus the native name-list editor")
        try sendKey("\u{1b}", code: 53, modifiers: [], window: panel)
        try await waitUntil { !panel.isVisible }
        _ = try await presentation.value
        activeController = nil
        try require(!BatchRenameStore(directory: directory.appendingPathComponent("state")).status().hasUnresolvedOperation, "Closing preview created operation state")
        try require(try String(contentsOf: session.parentURL.appendingPathComponent("Item-0.txt"), encoding: .utf8) == "original-0", "Preview changed the first file")
        try require(try String(contentsOf: session.parentURL.appendingPathComponent("Item-999.txt"), encoding: .utf8) == "original-999", "Preview changed the last file")
    }

    private func render(_ window: NSWindow, to output: URL) throws {
        let view = try unwrap(window.contentView, "Missing native content view")
        view.layoutSubtreeIfNeeded(); window.display()
        let bitmap = try unwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds), "Native render allocation failed")
        view.cacheDisplay(in: view.bounds, to: bitmap)
        // NSHostingView's root can be transparent. Composite its real cached
        // pixels onto the window background without changing product visuals.
        let opaque = NSImage(size: view.bounds.size)
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            opaque.lockFocus()
            window.backgroundColor.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: view.bounds.size)).fill()
            bitmap.draw(in: NSRect(origin: .zero, size: view.bounds.size))
            opaque.unlockFocus()
        }
        let tiff = try unwrap(opaque.tiffRepresentation, "Opaque native render failed")
        let composite = try unwrap(NSBitmapImageRep(data: tiff), "Opaque native bitmap failed")
        let data = try unwrap(composite.representation(using: .png, properties: [:]), "Native PNG render failed")
        try data.write(to: output, options: .withoutOverwriting)
        if ProcessInfo.processInfo.environment["FILEMINT_BATCH_RENAME_EXPORT_ARTIFACTS"] == "1" {
            // Explicitly export only this render's newly generated bytes. The
            // host can inspect QA artifacts without opening container files.
            let record = ["artifact": output.lastPathComponent, "pngBase64": data.base64EncodedString()]
            let encoded = try JSONSerialization.data(withJSONObject: record, options: .sortedKeys)
            FileHandle.standardOutput.write(encoded)
            FileHandle.standardOutput.write(Data([10]))
        }
        assertions += 1
    }

    private func coordinatorScenarios(root: URL) async throws {
        let directory = root.appendingPathComponent("coordinator", isDirectory: true)
        let first = try Self.fixture(directory.appendingPathComponent("first", isDirectory: true))
        let later = try Self.fixture(directory.appendingPathComponent("later", isDirectory: true), names: ["Later-1.txt", "Later-2.txt"])
        let captures = try await Task.detached(priority: .userInitiated) {
            (try BatchRenameSelection.capture(selection: first), try BatchRenameSelection.capture(selection: later))
        }.value
        let preferencesFile = directory.appendingPathComponent("preferences.json")
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [directory]
        preferences.monitoredFolderBookmarks = [:]
        preferences.fileTools.isEnabled = true
        preferences.fileTools.batchRename = true
        preferences.language = .english
        try FileMintPreferencesStore(fileURL: preferencesFile).save(preferences)
        let ticketsDirectory = directory.appendingPathComponent("tickets", isDirectory: true)
        let tickets = FileOperationTicketStore(directory: ticketsDirectory)
        let pending = PendingFileMoveStore(file: directory.appendingPathComponent("pending-move.json"))
        let controller = BatchRenameController()
        activeController = controller
        var feedback: [String] = []
        let operations = BatchRenameOperations(store: BatchRenameStore(directory: directory.appendingPathComponent("rename-state")),
            accessStore: BatchRenameAccessStore(file: directory.appendingPathComponent("rename-folder-access.json")),
            controller: controller, preferencesFile: preferencesFile, feedback: { feedback.append($0) })
        let coordinator = FileOperationCoordinator(store: pending, tickets: tickets, preferencesFile: preferencesFile,
            aliasAccessStore: DesktopAliasAccessStore(file: directory.appendingPathComponent("alias-access.json")),
            openWithAccessStore: OpenWithFolderAccessStore(file: directory.appendingPathComponent("open-access.json")),
            desktopDirectory: directory.appendingPathComponent("unused-desktop"),
            resourceController: ResourceToolsController(preferencesFile: preferencesFile), renameOperations: operations)
        let firstURL = try tickets.enqueue(.batchRename(selection: captures.0))
        coordinator.enqueue(firstURL)
        try require(coordinator.isBusy, "Rename intake did not synchronously reserve ownership")
        try await waitUntil { !feedback.isEmpty || !controller.isChecking && controller.rows.count == 2 }
        try require(feedback.isEmpty, "Initial coordinator request failed: \(feedback.joined(separator: "; "))")
        let remembered = try BatchRenameAccessStore(file: directory.appendingPathComponent("rename-folder-access.json")).load()
        try require(remembered[captures.0.parent.path]?.identity == captures.0.parentIdentity,
                    "An eligible new preview did not persist its independent parent grant")
        let firstRows = controller.rows.map(\.id)
        let secondURL = try tickets.enqueue(.batchRename(selection: captures.1))
        coordinator.enqueue(secondURL)
        try await waitUntil { feedback.count == 1 }
        try require(feedback[0] == BatchRenameText.busy.text(.english), "Busy request did not report rejection")
        try require(try tickets.consume(secondURL) == nil, "Busy ticket was not promptly consumed")
        try require(controller.rows.map(\.id) == firstRows && coordinator.isBusy, "Second request replaced the active batch")
        try require(!ApplicationTerminationPolicy.canQuit(pendingCreations: 0, hasActiveWrite: false,
            hasFileOperation: coordinator.isBusy, hasFavoriteOperation: false), "Panel did not hold quit guard")
        let queuedMove = try tickets.enqueue(.prepare(later))
        coordinator.enqueue(queuedMove)
        let id = try unwrap(URLComponents(url: queuedMove, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "Missing queued ticket ID")
        try require(FileManager.default.fileExists(atPath: ticketsDirectory.appendingPathComponent("\(id).json").path), "Other operation ticket consumed before rename closed")
        controller.requestClose()
        try await waitUntil { !coordinator.isBusy }
        try require(try pending.load()?.items.map(\.source) == later, "Existing move queue did not resume after rename closed")
        let expired = try tickets.enqueue(.batchRename(selection: captures.1), now: Date().addingTimeInterval(-61))
        coordinator.enqueue(expired)
        try await waitUntil { !coordinator.isBusy && feedback.count == 2 }
        try require(feedback[1] == BatchRenameText.invalidPreview.text(.english), "Expired request lacked explicit rejection")
        try require(try tickets.consume(expired) == nil, "Expired ticket remained replayable")
        coordinator.enqueue(firstURL)
        try await waitUntil { !coordinator.isBusy && feedback.count == 3 }
        try require(!controller.focusExistingPanel(), "Rejected request opened another panel")
        try require(ApplicationTerminationPolicy.canQuit(pendingCreations: 0, hasActiveWrite: false,
            hasFileOperation: coordinator.isBusy, hasFavoriteOperation: false), "Closed panel retained quit guard")
        activeController = nil
    }

    /// Interactive permission acceptance only targets a newly created host QA
    /// destination. The source evidence and remaining original are synthetic.
    private func externalExport(root: URL) async throws {
        let externalPath = ProcessInfo.processInfo.environment["FILEMINT_BATCH_RENAME_EXPORT_DIRECTORY"]
        if let externalPath {
            guard externalPath.hasPrefix("/private/tmp/filemint-batch-rename-export.") else {
                throw RenameSmokeFailure(message: "External export requires a dedicated host QA destination")
            }
            let handle = open(externalPath, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
            if handle >= 0 { close(handle) }
            try require(handle < 0, "External QA destination was readable before the Save panel grant")
        }
        let store = BatchRenameStore(directory: root.appendingPathComponent("corrupt-state", isDirectory: true))
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let originalIndex = Data("FileMint QA corrupt control record\n".utf8)
        let index = store.directory.appendingPathComponent("index.json")
        try originalIndex.write(to: index, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: index.path)
        let remaining = root.appendingPathComponent("remaining-staged-original.txt")
        let originalBytes = Data("FileMint QA remaining original\n".utf8)
        try originalBytes.write(to: remaining, options: .withoutOverwriting)
        let preferencesFile = root.appendingPathComponent("preferences.json")
        var preferences = FileMintPreferences.default
        preferences.language = .english
        preferences.monitoredFolderURLs = []
        preferences.monitoredFolderBookmarks = [:]
        preferences.fileTools.isEnabled = false
        preferences.fileTools.batchRename = false
        try FileMintPreferencesStore(fileURL: preferencesFile).save(preferences)
        var feedback: [String] = []
        let operations = BatchRenameOperations(store: store,
            accessStore: BatchRenameAccessStore(file: root.appendingPathComponent("rename-folder-access.json")),
            controller: BatchRenameController(),
            preferencesFile: preferencesFile, feedback: { feedback.append($0) })
        try require(store.status().hasUnresolvedOperation && store.status().isCorrupt, "Synthetic corrupt record not blocked")
        for stage in ["cancel confirmation", "cancel save panel"] {
            print("READY external export: \(stage)")
            fflush(stdout)
            try await operations.perform(.exportAndUnblock, preferencesFile: preferencesFile)
            try require(store.status().hasUnresolvedOperation, "Cancelled export cleared the blocker")
            try require(try Data(contentsOf: index) == originalIndex, "Cancelled export altered original control bytes")
            try require(try Data(contentsOf: remaining) == originalBytes, "Cancelled export touched a remaining original")
            try require(feedback.isEmpty, "Cancelled export reported success")
        }
        print("READY external export: confirm and choose the unique host QA destination")
        fflush(stdout)
        try await operations.perform(.exportAndUnblock, preferencesFile: preferencesFile)
        try require(!store.status().hasUnresolvedOperation && !store.status().canUndo, "Manual retirement left a blocker or undo")
        try require(!FileManager.default.fileExists(atPath: index.path), "Manual retirement retained retired private index")
        try require(try Data(contentsOf: remaining) == originalBytes, "Manual retirement touched a remaining original")
        try require(feedback.count == 1 && feedback[0].contains("manually closed"), "Manual retirement did not report its actual outcome")
    }

    private func sendKey(_ characters: String, code: UInt16, modifiers: NSEvent.ModifierFlags, window: NSWindow) throws {
        let event = try unwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code), "Unable to create keyboard event")
        NSApp.sendEvent(event)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<300 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw RenameSmokeFailure(message: "Native condition timed out")
    }

    private func require(_ condition: Bool, _ label: String) throws {
        guard condition else { throw RenameSmokeFailure(message: label) }
        assertions += 1
    }

    private func unwrap<T>(_ value: T?, _ label: String) throws -> T {
        guard let value else { throw RenameSmokeFailure(message: label) }
        return value
    }

    private func descendant<T: NSView>(in root: NSView?, matching predicate: (T) -> Bool) -> T? {
        guard let root else { return nil }
        if let value = root as? T, predicate(value) { return value }
        for child in root.subviews {
            if let result = descendant(in: child, matching: predicate) { return result }
        }
        return nil
    }
}

import AppKit
import Darwin
import FileMintCore
import Foundation

/// Runs inside the existing signed sandboxed template fixture, using only its
/// private temporary files/stores. No Finder launch or system permission prompt.
@MainActor
enum FileVisibilityChecks {
    static func run(root: URL) async throws {
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "FileVisibilityQA", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let file = root.appendingPathComponent("selected.txt"), folder = root.appendingPathComponent("SelectedFolder")
        let other = root.appendingPathComponent("later-selection.txt")
        let legacy = root.appendingPathComponent("legacy-hidden.txt")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let child = folder.appendingPathComponent("child.txt")
        for url in [file, other, child, legacy] { try Data("preserved fixture".utf8).write(to: url) }
        var finderInfo = [UInt8](repeating: 0, count: 32); finderInfo[8] = 0x40
        let legacyResult = finderInfo.withUnsafeBytes {
            setxattr(legacy.path, "com.apple.FinderInfo", $0.baseAddress, $0.count, 0, 0)
        }
        try require(legacyResult == 0, "Could not prepare legacy invisible metadata")
        let original = try Data(contentsOf: file)
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.fileTools.isEnabled = true; preferences.fileTools.fileVisibility = true
        preferences.launchAtLogin = false; preferences.automaticallyChecksForUpdates = false
        let preferencesFile = root.appendingPathComponent("preferences.json")
        let store = FileMintPreferencesStore(fileURL: preferencesFile)
        try store.save(preferences)
        let beforePreferences = try Data(contentsOf: preferencesFile)
        let tickets = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
        let rename = BatchRenameOperations(store: BatchRenameStore(directory: root.appendingPathComponent("rename-state")),
            accessStore: BatchRenameAccessStore(file: root.appendingPathComponent("rename-access.json")),
            controller: BatchRenameController(), preferencesFile: preferencesFile)
        let coordinator = FileOperationCoordinator(store: PendingFileMoveStore(file: root.appendingPathComponent("pending.json")),
            tickets: tickets, preferencesFile: preferencesFile,
            aliasAccessStore: DesktopAliasAccessStore(file: root.appendingPathComponent("alias-access.json")),
            openWithAccessStore: OpenWithFolderAccessStore(file: root.appendingPathComponent("open-access.json")),
            desktopDirectory: root.appendingPathComponent("unused-desktop"),
            resourceController: ResourceToolsController(preferencesFile: preferencesFile), renameOperations: rename)
        let captured = try FileVisibilityService.capture([file, folder, legacy])
        var registry = FileMenuActionRegistry()
        var snapshot = FileMenuAction(directory: root, tool: .fileVisibility, selection: [file, folder, legacy])
        snapshot.visibilityAction = .hide
        let tag = registry.register([snapshot])[0]
        guard let action = registry.takeAction(for: tag), let visibility = action.visibilityAction else {
            throw NSError(domain: "FileVisibilityQA", code: 2)
        }
        try require(action.selection.map { $0.standardizedFileURL.path } == captured.map { $0.source.path }
                    && registry.takeAction(for: tag) == nil,
                    "Menu selection/action was replaced or replayed")
        let url = try tickets.enqueue(.fileVisibility(items: captured, action: visibility))
        coordinator.enqueue(url)
        for _ in 0..<100 where coordinator.isBusy { try await Task.sleep(for: .milliseconds(30)) }
        try require(!coordinator.isBusy, "Visibility ticket did not release operation ownership")
        try require(FileVisibilityService.menuActions(for: [file, folder, legacy]) == [.unhide] &&
                    FileVisibilityService.menuActions(for: [other, child]) == [.hide],
                    "Sandboxed ticket changed the wrong objects or failed to hide selected entries")
        let unhide = try tickets.enqueue(.fileVisibility(items: captured, action: .unhide))
        coordinator.enqueue(unhide)
        for _ in 0..<100 where coordinator.isBusy { try await Task.sleep(for: .milliseconds(30)) }
        try require(!coordinator.isBusy && FileVisibilityService.menuActions(for: [file, folder, legacy]) == [.hide],
                    "Sandboxed unhide ticket failed")
        try require(try Data(contentsOf: file) == original && Data(contentsOf: child) == original &&
                    Data(contentsOf: other) == original && Data(contentsOf: legacy) == original &&
                    Data(contentsOf: preferencesFile) == beforePreferences,
                    "Visibility changed contents, descendants, later selection or saved settings")
        try require(try tickets.consume(url) == nil && tickets.consume(unhide) == nil,
                    "Completed visibility tickets could be replayed")
        try require(!NSApp.windows.contains { $0.isVisible }, "Silent success opened a window")
        print("PASS file visibility: signed sandbox, production coordinator, explicit hide/unhide tickets, immutable selection, contents/descendants preserved and silent success")
        fflush(nil)
    }
}

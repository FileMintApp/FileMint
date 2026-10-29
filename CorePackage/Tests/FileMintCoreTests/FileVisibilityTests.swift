import Darwin
@testable import FileMintCore
import Foundation
import Testing

@Suite("Selected item visibility")
struct FileVisibilityTests {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-visibility-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    private func write(_ root: URL, _ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("original \(name) 🪴\r\n".utf8).write(to: url)
        return url
    }
    private func flags(_ url: URL) throws -> UInt32 {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return info.st_flags
    }
    private func hidden(_ url: URL) throws -> Bool {
        try #require(URL(fileURLWithPath: url.path).resourceValues(forKeys: [.isHiddenKey]).isHidden)
    }

    @Test("uniform selections have one explicit action; mixed and unknown have both")
    func actions() {
        #expect(FileVisibilityPolicy.actions(hiddenStates: []) == [])
        #expect(FileVisibilityPolicy.actions(hiddenStates: [false, false]) == [.hide])
        #expect(FileVisibilityPolicy.actions(hiddenStates: [true, true]) == [.unhide])
        let mixed: [[Bool?]] = [[true, false], [nil], [false, nil], [true, nil]]
        for states in mixed {
            #expect(FileVisibilityPolicy.actions(hiddenStates: states) == [.hide, .unhide])
        }
        #expect(FileMintStrings.text(FileVisibilityAction.hide.title(selectionCount: 1), language: .chinese) == "隐藏此项目")
        #expect(FileMintStrings.text(FileVisibilityAction.unhide.title(selectionCount: 2), language: .chinese) == "取消隐藏所选项目")
        #expect(FileMintStrings.text(FileVisibilityAction.unhide.title(selectionCount: 1), language: .english) == "Unhide This Item")
    }

    @Test("visibility switch is opt-in and placement survives disabling and persistence")
    func preferences() throws {
        for json in ["{}", #"{"fileVisibility":"invalid"}"#] {
            let old = try JSONDecoder().decode(FileToolsPreferences.self, from: Data(json.utf8))
            #expect(!old.fileVisibility)
        }
        var value = FileToolsPreferences()
        value.setEnabled(true, for: .fileVisibility)
        value.mainMenuTools.insert(.fileVisibility)
        let loaded = try JSONDecoder().decode(FileToolsPreferences.self, from: JSONEncoder().encode(value))
        #expect(loaded.fileVisibility && !loaded.allows(.fileVisibility))
        #expect(loaded.mainMenuTools == [.fileVisibility])
    }

    @Test("real attributes round-trip without reading descendants or changing bytes, names or other flags")
    func attributes() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let file = try write(root, "资料 % 🪴.txt"), folder = root.appendingPathComponent("Folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let child = try write(folder, "child.txt")
        let bytes = try Data(contentsOf: file), childBytes = try Data(contentsOf: child)
        #expect(chflags(file.path, UInt32(UF_NODUMP)) == 0)
        let selections = try FileVisibilityService.capture([file, folder])
        #expect(FileVisibilityService.menuActions(for: [file, folder]) == [.hide])
        #expect(try FileVisibilityService.perform(selections, action: .hide) == 2)
        #expect(try hidden(file) && hidden(folder) && !hidden(child))
        #expect(try flags(file) == UInt32(UF_NODUMP | UF_HIDDEN))
        #expect(FileVisibilityService.menuActions(for: [file, folder]) == [.unhide])
        #expect(try FileVisibilityService.perform(selections, action: .unhide) == 2)
        #expect(try !hidden(file) && !hidden(folder) && !hidden(child))
        #expect(try flags(file) == UInt32(UF_NODUMP))
        #expect(try Data(contentsOf: file) == bytes && Data(contentsOf: child) == childBytes)
        for selection in selections { try selection.validate() }
    }

    @Test("explicit state remains idempotent after visibility changes since menu capture")
    func explicitState() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let file = try write(root, "note.txt")
        let captured = try FileVisibilityService.capture([file])
        #expect(FileVisibilityService.menuActions(for: [file]) == [.hide])
        #expect(chflags(file.path, UInt32(UF_HIDDEN)) == 0)
        try FileVisibilityService.perform(captured, action: .hide)
        try FileVisibilityService.perform(captured, action: .hide)
        #expect(try hidden(file))
        try FileVisibilityService.perform(captured, action: .unhide)
        try FileVisibilityService.perform(captured, action: .unhide)
        #expect(try !hidden(file))
    }

    @Test("dot-name unhide is rejected before any selected item changes")
    func dotName() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let file = try write(root, "note.txt"), dot = try write(root, ".env")
        #expect(chflags(file.path, UInt32(UF_HIDDEN)) == 0)
        let captured = try FileVisibilityService.capture([file, dot])
        #expect(throws: FileVisibilityError.nameHidden) {
            try FileVisibilityService.perform(captured, action: .unhide)
        }
        #expect(try hidden(file) && hidden(dot) && flags(dot) == 0)
        try FileVisibilityService.perform([captured[1]], action: .hide)
        #expect(try flags(dot) == 0)
    }

    @Test("whole-batch identity preflight rejects replacements without changing earlier items")
    func replaced() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let first = try write(root, "first.txt"), second = try write(root, "second.txt")
        let captured = try FileVisibilityService.capture([first, second])
        try FileManager.default.moveItem(at: second, to: root.appendingPathComponent("original.txt"))
        _ = try write(root, "second.txt")
        #expect(throws: FileVisibilityError.changed) {
            try FileVisibilityService.perform(captured, action: .hide)
        }
        #expect(try !hidden(first) && !hidden(second))
    }

    @Test("legacy Finder invisibility is detected and cleared without changing other metadata")
    func legacyInvisible() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let file = try write(root, "legacy.txt")
        // FinderInfo stores the classic kIsInvisible flag (0x4000) in the
        // big-endian finderFlags field at bytes 8–9, independently of UF_HIDDEN.
        var finderInfo = [UInt8](repeating: 0, count: 32)
        finderInfo[8] = 0x40
        finderInfo[9] = 0x0E
        let result = finderInfo.withUnsafeBytes {
            setxattr(file.path, "com.apple.FinderInfo", $0.baseAddress, $0.count, 0, 0)
        }
        #expect(result == 0)
        #expect(FileVisibilityService.menuActions(for: [file]) == [.unhide])
        let captured = try FileVisibilityService.capture([file])
        for flags in [UInt32(0), UInt32(UF_HIDDEN)] {
            let result = finderInfo.withUnsafeBytes {
                setxattr(file.path, "com.apple.FinderInfo", $0.baseAddress, $0.count, 0, 0)
            }
            #expect(result == 0 && chflags(file.path, flags) == 0)
            try FileVisibilityService.perform(captured, action: .unhide)
            #expect(FileVisibilityService.menuActions(for: [file]) == [.hide])
            var after = [UInt8](repeating: 0, count: 32)
            let count = after.withUnsafeMutableBytes {
                getxattr(file.path, "com.apple.FinderInfo", $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW)
            }
            var expected = finderInfo; expected[8] = 0
            #expect(count == 32 && after == expected)
            #expect(try !hidden(file) && self.flags(file) & UInt32(UF_HIDDEN) == 0)
        }
    }

    @Test("symlinks, special files, duplicate objects, roots and nonlocal URLs are rejected")
    func unsupported() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let file = try write(root, "target.txt"), link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        let hardlink = root.appendingPathComponent("hardlink")
        try FileManager.default.linkItem(at: file, to: hardlink)
        let fifo = root.appendingPathComponent("fifo")
        #expect(mkfifo(fifo.path, 0o600) == 0)
        #expect(!FileVisibilityService.supportsMenuSelection([link]))
        #expect(!FileVisibilityService.supportsMenuSelection([fifo]))
        #expect(throws: FileVisibilityError.unsupported) { try FileVisibilityService.capture([link]) }
        #expect(throws: FileVisibilityError.invalidSelection) { try FileVisibilityService.capture([file, hardlink]) }
        for urls in [[], [file, file], [URL(fileURLWithPath: "/")], [URL(string: "file://remote/item")!]] {
            #expect(!FileVisibilityPolicy.canSelect(urls))
        }
        #expect(try !hidden(file))
    }

    @Test("mixed files produce both actions and scope/placement still govern exposure")
    func mixedScopeAndPlacement() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let first = try write(root, "visible.txt"), second = try write(root, "hidden.txt")
        #expect(chflags(second.path, UInt32(UF_HIDDEN)) == 0)
        #expect(FileVisibilityService.menuActions(for: [first, second]) == [.hide, .unhide])
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]; preferences.fileTools.isEnabled = true
        preferences.fileTools.fileVisibility = true
        #expect(FileToolsPolicy.availableTools(selection: [first, second], isItemMenu: true,
                                              preferences: preferences).contains(.fileVisibility))
        #expect(!FileToolsPolicy.availableTools(selection: [first], isItemMenu: false,
                                               preferences: preferences).contains(.fileVisibility))
        let layout = FileToolsMenuLayout(tools: [.fileVisibility], hasMoveDestination: false, preferences: preferences.fileTools)
        #expect(layout.submenu == [.fileVisibility] && layout.main.isEmpty)
        preferences.monitoredFolderURLs = []
        #expect(!FileVisibilityPolicy.isEnabled(for: [first], preferences: preferences))
    }

    @Test("partial revocation reports processed counts and preserves untouched items")
    func partialFailure() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let first = try write(root, "first.txt"), second = try write(root, "second.txt")
        let captured = try FileVisibilityService.capture([first, second])
        let counter = VisibilityCallCounter()
        do {
            try FileVisibilityService.perform(captured, action: .hide) { _ in counter.next() <= 3 }
            Issue.record("Revoked operation unexpectedly completed")
        } catch let failure as FileVisibilityFailure {
            #expect(failure.processed == 1 && failure.total == 2)
            #expect(failure.underlying as? FileVisibilityError == .disabled)
        }
        #expect(try hidden(first) && !hidden(second))
    }

    @Test("tickets and menu snapshots retain the explicit action, selection and one-use lifetime")
    func tickets() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let file = try write(root, "note.txt")
        let captured = try FileVisibilityService.capture([file])
        let tickets = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
        let request = FileOperationRequest.fileVisibility(items: captured, action: .unhide)
        let now = Date()
        let url = try tickets.enqueue(request, now: now)
        #expect(try tickets.consume(url, now: now) == request)
        #expect(try tickets.consume(url, now: now) == nil)
        let expired = try tickets.enqueue(request, now: now)
        #expect(try tickets.consume(expired, now: now.addingTimeInterval(61)) == nil)
        #expect(throws: FileVisibilityError.invalidSelection) {
            try tickets.enqueue(.fileVisibility(items: [], action: .hide))
        }
        var registry = FileMenuActionRegistry()
        var action = FileMenuAction(directory: root, tool: .fileVisibility, selection: [file])
        action.visibilityAction = .hide
        let tag = registry.register([action])[0]
        #expect(registry.takeAction(for: tag) == action)
        #expect(registry.takeAction(for: tag) == nil)
    }
}

private final class VisibilityCallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
}

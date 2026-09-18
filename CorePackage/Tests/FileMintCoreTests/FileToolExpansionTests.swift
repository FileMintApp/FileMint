import FileMintCore
import Foundation
import Testing

@Suite("File tool placement, deletion and AirDrop")
struct FileToolExpansionTests {
    @Test("all placements partition applicable tools exactly once and hide empty groups")
    func placement() {
        var preferences = FileToolsPreferences()
        preferences.isEnabled = true
        preferences.permanentDelete = true
        preferences.airDrop = true
        for mask in 0..<(1 << FileTool.allCases.count) {
            preferences.mainMenuTools = Set(FileTool.allCases.enumerated().compactMap {
                mask & (1 << $0.offset) != 0 ? $0.element : nil
            })
            for moveMain in [true, false] {
                preferences.moveHereInMainMenu = moveMain
                let layout = FileToolsMenuLayout(tools: FileTool.allCases, hasMoveDestination: true, preferences: preferences)
                #expect(Set(layout.main + layout.submenu) == Set(FileTool.allCases))
                #expect(layout.main.count + layout.submenu.count == FileTool.allCases.count)
                #expect(Set(layout.main).isDisjoint(with: layout.submenu))
                #expect(layout.moveHereInMain == moveMain)
                #expect(layout.moveHereInSubmenu == !moveMain)
                #expect(layout.showsSubmenu == (!layout.submenu.isEmpty || !moveMain))
            }
        }
        let background = FileToolsMenuLayout(tools: [], hasMoveDestination: true, preferences: preferences)
        #expect(background.main.isEmpty && background.submenu.isEmpty && background.showsSubmenu)
        preferences.isEnabled = false
        let hidden = FileToolsMenuLayout(tools: FileTool.allCases, hasMoveDestination: true, preferences: preferences)
        #expect(hidden.main.isEmpty && !hidden.showsSubmenu && !hidden.moveHereInMain)
    }

    @Test("new defaults, malformed confirmation and saved placement preserve creation settings")
    func preferences() throws {
        for json in [#"{}"#, #"{"deleteConfirmation":"invalid"}"#] {
            let value = try JSONDecoder().decode(FileToolsPreferences.self, from: Data(json.utf8))
            #expect(value.deleteConfirmation == .required)
            #expect(!value.permanentDelete && !value.airDrop && value.mainMenuTools.isEmpty)
            #expect(value.moveHereInMainMenu)
        }
        var value = FileMintPreferences.default
        value.fileTools.mainMenuTools = [.airDrop, .permanentDelete, .copyPaths]
        value.fileTools.deleteConfirmation = .silent
        value.fileTools.moveHereInMainMenu = false
        value.fileTools.setEnabled(true, for: .airDrop)
        value.fileTools.setEnabled(true, for: .permanentDelete)
        value.fileTools.isEnabled = false
        let saved = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(value))
        #expect(saved.fileTools == value.fileTools)
        #expect(saved.templates == value.templates)
        #expect(saved.collisionStrategy == value.collisionStrategy)
        #expect(saved.revealAfterCreation == value.revealAfterCreation)
        #expect(DeleteConfirmation.isRequired(captured: .required, current: .silent))
        #expect(DeleteConfirmation.isRequired(captured: .silent, current: .required))
        #expect(!DeleteConfirmation.isRequired(captured: .silent, current: .silent))
    }

    @Test("new tools use the whole selection scope and never generate clipboard contents")
    func scope() {
        let root = URL(fileURLWithPath: "/example")
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.fileTools.isEnabled = true
        for tool in [FileTool.airDrop, .permanentDelete] {
            preferences.fileTools.setEnabled(true, for: tool)
            let selection = [root.appendingPathComponent("one"), root.appendingPathComponent("two")]
            #expect(FileToolsPolicy.availableTools(selection: selection, isItemMenu: true, preferences: preferences).contains(tool))
            #expect(FileToolsPolicy.clipboardText(for: tool, selection: selection) == nil)
            #expect(FileToolsPolicy.availableTools(selection: selection, isItemMenu: false, preferences: preferences).isEmpty)
            #expect(FileToolsPolicy.availableTools(selection: selection + [URL(fileURLWithPath: "/outside")],
                isItemMenu: true, preferences: preferences).isEmpty)
            preferences.fileTools.setEnabled(false, for: tool)
            #expect(!FileToolsPolicy.availableTools(selection: selection, isItemMenu: true, preferences: preferences).contains(tool))
        }
    }

    private func workspace(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-delete-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    @Test("explicit deletion removes files, packages and directories but preserves symlink targets")
    func deletion() throws {
        try workspace { root in
            let file = root.appendingPathComponent("说明 % 🪴.txt")
            let folder = root.appendingPathComponent("Folder")
            let package = root.appendingPathComponent("Demo.app")
            let target = root.appendingPathComponent("keep")
            let link = root.appendingPathComponent("link")
            try Data([0, 255]).write(to: file)
            for directory in [folder, package] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try Data("contents".utf8).write(to: directory.appendingPathComponent("child"))
            }
            try Data("preserve".utf8).write(to: target)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
            let selection = [file, folder, package, link]
            let items = try FileDeletionService.capture(selection)
            try FileDeletionService.perform(items: items) { true }
            for url in selection { #expect(!FileManager.default.fileExists(atPath: url.path)) }
            #expect(try String(contentsOf: target, encoding: .utf8) == "preserve")
        }
    }

    @Test("invalid, disabled, replaced and overlapping selections delete nothing")
    func rejectedDeletion() throws {
        try workspace { root in
            let a = root.appendingPathComponent("a")
            let b = root.appendingPathComponent("b")
            try Data("a".utf8).write(to: a)
            try Data("b".utf8).write(to: b)
            let items = try FileDeletionService.capture([a, b])
            #expect(throws: FileDeletionFailure.self) { try FileDeletionService.perform(items: items) { false } }
            try Data("replacement".utf8).write(to: b, options: .atomic)
            #expect(throws: FileDeletionFailure.self) { try FileDeletionService.perform(items: items) { true } }
            #expect(try String(contentsOf: a, encoding: .utf8) == "a")
            #expect(try String(contentsOf: b, encoding: .utf8) == "replacement")
            #expect(throws: FileMoveError.invalidSelection) { try FileDeletionService.capture([]) }
            #expect(throws: FileMoveError.invalidSelection) { try FileDeletionService.capture([a, a]) }
            #expect(throws: FileMoveError.invalidSelection) { try FileDeletionService.capture([root, a]) }
            #expect(throws: FileMoveError.invalidSelection) { try FileDeletionService.capture([URL(fileURLWithPath: "/")]) }
        }
    }

    @Test("partial deletion stops and reports completed count without retrying remaining items")
    func partialDeletion() throws {
        try workspace { root in
            let a = root.appendingPathComponent("a")
            let b = root.appendingPathComponent("b")
            try Data("a".utf8).write(to: a)
            try Data("b".utf8).write(to: b)
            let items = try FileDeletionService.capture([a, b])
            var checks = 0
            do {
                try FileDeletionService.perform(items: items) { checks += 1; return checks < 3 }
                Issue.record("Expected partial failure")
            } catch let failure as FileDeletionFailure {
                #expect(failure.completed == 1 && failure.total == 2)
            }
            #expect(!FileManager.default.fileExists(atPath: a.path))
            #expect(try String(contentsOf: b, encoding: .utf8) == "b")
        }
    }

    @Test("delete and AirDrop tickets preserve snapshots, expire, and reject replay and bare paths")
    func tickets() throws {
        try workspace { root in
            let file = root.appendingPathComponent("file")
            try Data("keep".utf8).write(to: file)
            let items = try FileDeletionService.capture([file])
            let store = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
            let now = Date()
            for request in [FileOperationRequest.permanentDelete(items: items, confirmation: .required), .airDrop([file])] {
                let url = try store.enqueue(request, now: now)
                #expect(try store.consume(url, now: now) == request)
                #expect(try store.consume(url, now: now) == nil)
                let expired = try store.enqueue(request, now: now)
                #expect(try store.consume(expired, now: now.addingTimeInterval(61)) == nil)
                let future = try store.enqueue(request, now: now)
                #expect(try store.consume(future, now: now.addingTimeInterval(-1)) == nil)
            }
            #expect(try store.consume(URL(string: "filemint://move?delete=/tmp/file")!) == nil)
            #expect(try String(contentsOf: file, encoding: .utf8) == "keep")
        }
    }
}

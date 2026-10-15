import FileMintCore
import Foundation
import Testing

@Suite("Batch rename Finder integration")
struct BatchRenameIntegrationTests {
    private let root = URL(fileURLWithPath: "/Users/example/Work", isDirectory: true)

    private func preferences() -> FileMintPreferences {
        var value = FileMintPreferences.default
        value.monitoredFolderURLs = [root]
        value.fileTools.isEnabled = true
        value.fileTools.batchRename = true
        return value
    }

    @Test("new, old and malformed settings keep batch rename off independently")
    func defaultOff() throws {
        #expect(!FileToolsPreferences().batchRename)
        let invalidValues: [Any?] = [nil, NSNull(), "true", 1, [String]()]
        for invalid in invalidValues {
            var object: [String: Any] = ["isEnabled": true, "copyNames": false, "move": true,
                                         "mainMenuTools": ["copyPaths"]]
            object["batchRename"] = invalid
            let decoded = try JSONDecoder().decode(FileToolsPreferences.self,
                from: JSONSerialization.data(withJSONObject: object))
            #expect(!decoded.batchRename)
            #expect(decoded.isEnabled && !decoded.copyNames && decoded.move)
            #expect(decoded.mainMenuTools == [.copyPaths])
            #expect(!decoded.mainMenuTools.contains(.batchRename))
        }
    }

    @Test("saved child placement and icon survive turning the module off")
    func preferenceRoundTrip() throws {
        var value = preferences()
        value.fileTools.mainMenuTools = [.copyPaths, .batchRename]
        value.menuIcons[MenuIconSlot.batchRename.rawValue] = try #require(MenuIconCustomization(
            symbolName: "pencil.circle", primaryHex: "#123456", secondaryHex: "#ABCDEF"))
        value.fileTools.isEnabled = false
        let decoded = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(value))
        #expect(decoded == value)
        #expect(decoded.fileTools.batchRename && !decoded.fileTools.allows(.batchRename))
        #expect(FileTool.batchRename.menuIconSlot == .batchRename)
        #expect(MenuIconSlot.batchRename.defaultSymbolName == "pencil")
    }

    @Test("menu admission is bounded, complete and lexical without probing item metadata")
    func menuAdmission() {
        let value = preferences()
        // Deliberately nonexistent paths prove the menu policy needs no metadata.
        let selection = [root.appendingPathComponent("one.txt"), root.appendingPathComponent("two")]
        func offers(_ urls: [URL], itemMenu: Bool = true) -> Bool {
            FileToolsPolicy.availableTools(selection: urls, isItemMenu: itemMenu, preferences: value).contains(.batchRename)
        }
        #expect(offers(selection))
        #expect(!offers(selection, itemMenu: false))
        #expect(!offers([]))
        #expect(!offers([selection[0]]))
        #expect(!offers([selection[0], selection[0]]))
        #expect(!offers([selection[0], root.appendingPathComponent("child/two.txt")]))
        #expect(!offers([selection[0], URL(fileURLWithPath: "/Users/example/Work-Other/two.txt")]))
        #expect(!offers([selection[0], URL(string: "https://example.com/two.txt")!]))
        #expect(!offers([selection[0], URL(string: "file://remote/Users/example/Work/two.txt")!]))
        let maximum = (0..<1_000).map { root.appendingPathComponent("item-\($0)") }
        #expect(offers(maximum))
        #expect(!offers(maximum + [root.appendingPathComponent("overflow")]))
        #expect(!FileToolsPolicy.availableTools(target: .directory(root), preferences: value).contains(.batchRename))
    }

    @Test("default submenu placement, disabled settings and old menu selection remain independent")
    func oldMenu() throws {
        var value = preferences()
        let selection = [root.appendingPathComponent("first"), root.appendingPathComponent("second")]
        var registry = FileMenuActionRegistry()
        let first = registry.register([FileMenuAction(directory: root, tool: .batchRename, selection: selection)])[0]
        _ = registry.register([FileMenuAction(directory: root, tool: .batchRename,
            selection: [root.appendingPathComponent("later-1"), root.appendingPathComponent("later-2")])])
        let taken = registry.takeAction(for: first)
        let captured = try #require(taken)
        #expect(captured.selection == selection)
        let replay = registry.takeAction(for: first)
        #expect(replay == nil)
        let layout = FileToolsMenuLayout(tools: [.batchRename], hasMoveDestination: false, preferences: value.fileTools)
        #expect(layout.main.isEmpty && layout.submenu == [.batchRename])
        value.fileTools.batchRename = false
        #expect(!FileToolsPolicy.availableTools(selection: captured.selection, isItemMenu: true, preferences: value).contains(.batchRename))
        value.fileTools.batchRename = true
        value.monitoredFolderURLs = []
        #expect(!FileToolsPolicy.availableTools(selection: captured.selection, isItemMenu: true, preferences: value).contains(.batchRename))
    }

    @Test("rename tickets preserve all captured identities and stay single-use and expiring")
    func tickets() throws {
        try workspace { directory, selection in
            let captured = try BatchRenameSelection.capture(selection: selection)
            let request = FileOperationRequest.batchRename(selection: captured)
            let store = FileOperationTicketStore(directory: directory.appendingPathComponent("tickets"))
            let now = Date(timeIntervalSince1970: 1_000)
            let url = try store.enqueue(request, now: now)
            #expect(FileOperationTicketStore.isBatchRenameURL(url))
            #expect(url.host == "rename")
            #expect(try store.consume(url, now: now) == request)
            #expect(try store.consume(url, now: now) == nil)
            let expired = try store.enqueue(request, now: now)
            #expect(try store.consume(expired, now: now.addingTimeInterval(61)) == nil)
            #expect(try store.consume(expired, now: now) == nil)
            let future = try store.enqueue(request, now: now.addingTimeInterval(1))
            #expect(try store.consume(future, now: now) == nil)
        }
    }

    @Test("routes cannot disguise rename tickets as queued operations or the reverse")
    func ticketRouteBinding() throws {
        try workspace { directory, selection in
            let store = FileOperationTicketStore(directory: directory.appendingPathComponent("tickets"))
            let rename = try store.enqueue(.batchRename(selection: BatchRenameSelection.capture(selection: selection)))
            var oldRoute = try #require(URLComponents(url: rename, resolvingAgainstBaseURL: false))
            oldRoute.host = "move"
            #expect(try store.consume(try #require(oldRoute.url)) == nil)
            #expect(try store.consume(rename) == nil)
            let move = try store.enqueue(.prepare(selection))
            #expect(!FileOperationTicketStore.isBatchRenameURL(move))
            var newRoute = try #require(URLComponents(url: move, resolvingAgainstBaseURL: false))
            newRoute.host = "rename"
            #expect(try store.consume(try #require(newRoute.url)) == nil)
        }
        let id = UUID().uuidString
        for value in ["filemint://rename?id=../bad", "filemint://rename?id=\(id)&extra=1",
                      "filemint://rename/path?id=\(id)", "filemint://user@rename?id=\(id)",
                      "filemint://rename:10?id=\(id)", "filemint://rename?id=\(id)#fragment"] {
            #expect(!FileOperationTicketStore.isBatchRenameURL(URL(string: value)!))
        }
    }

    @Test("ticket byte limit rejects valid paths below the item cap without truncation")
    func ticketByteLimit() throws {
        try workspace { directory, _ in
            // Keep every path within native limits. A 600,000-character component
            // fails URL admission on older Foundation versions before ticket sizing.
            let parent = (0..<3).reduce(directory) {
                $0.appendingPathComponent(String(repeating: "p", count: 180) + String($1), isDirectory: true)
            }
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let selection = (0..<700).map {
                parent.appendingPathComponent(String(repeating: "x", count: 180) + "\($0).txt")
            }
            try #require(selection.allSatisfy {
                $0.path.utf8.count < 1_024 && $0.lastPathComponent.utf8.count <= 255
            })
            try #require(FileToolsPolicy.canBatchRename(selection))
            for source in selection { try Data("original".utf8).write(to: source, options: .withoutOverwriting) }
            let captured = try BatchRenameSelection.capture(selection: selection)
            try #require(captured.items.count == 700)
            try #require(JSONEncoder().encode(captured).count > 1_048_576)
            let store = FileOperationTicketStore(directory: directory.appendingPathComponent("tickets"))
            #expect(throws: FileOperationTicketError.batchRenameTicketLimit) {
                try store.enqueue(.batchRename(selection: captured))
            }
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("tickets").path))
        }
    }

    @Test("new menu and error labels have both languages")
    func labels() {
        #expect(FileMintStrings.text(.batchRename, language: .chinese) == "批量重命名…")
        #expect(FileMintStrings.text(.batchRename, language: .english) == "Batch Rename…")
        for key in [FileMintTextKey.batchRenameHint, .batchRenameSelectionLimit, .batchRenameTicketLimit,
                    .batchRenameChangedSelection, .batchRenameUnsupportedSelection, .batchRenameUnavailableSelection] {
            #expect(FileMintStrings.text(key, language: .english) != key.rawValue)
            #expect(FileMintStrings.text(key, language: .chinese) != key.rawValue)
            #expect(FileMintStrings.text(key, language: .english) != FileMintStrings.text(key, language: .chinese))
        }
    }

    private func workspace(_ body: (URL, [URL]) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let selection = [directory.appendingPathComponent("first.txt"), directory.appendingPathComponent("second")]
        try Data("original".utf8).write(to: selection[0], options: .withoutOverwriting)
        try FileManager.default.createDirectory(at: selection[1], withIntermediateDirectories: false)
        try body(directory, selection)
    }
}

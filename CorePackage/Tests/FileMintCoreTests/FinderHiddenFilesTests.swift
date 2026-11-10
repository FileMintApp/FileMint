import Foundation
import Testing
@testable import FileMintCore

struct FinderHiddenFilesTests {
    private let root = URL(fileURLWithPath: "/Users/example/Work", isDirectory: true)

    @Test("the same Finder toggle is available in background and item menus")
    func menus() {
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.fileTools.isEnabled = true
        preferences.fileTools.fileVisibility = true
        let dotFile = root.appendingPathComponent(".env")
        let mixedSelection = [dotFile, root.appendingPathComponent("regular.txt"), URL(fileURLWithPath: "/outside")]

        func menu(_ selection: [URL], item: Bool, background: Bool) -> [FileMenuAction] {
            FileToolsPolicy.menuActions(directory: root, selection: selection, isItemMenu: item,
                isContainer: background, preferences: preferences)
        }

        let background = menu(mixedSelection, item: false, background: true)
        #expect(background.compactMap(\.tool) == [.copyPaths, .fileVisibility])
        let toggle = background.filter { $0.tool == .fileVisibility }
        #expect(toggle.count == 1 && toggle.first?.fileToolTarget == .directory(root))
        #expect(toggle.first?.selection.isEmpty == true)
        for selection in [[], [dotFile], mixedSelection] {
            #expect(menu(selection, item: true, background: false).filter { $0.tool == .fileVisibility } == toggle)
        }
        #expect(menu([dotFile], item: false, background: false).isEmpty)
        #expect(FileMintStrings.text(FileTool.fileVisibility.title, language: .english) == "Toggle Hidden Files")
        #expect(FileMintStrings.text(FileTool.fileVisibility.title, language: .chinese) == "切换隐藏文件显示")
    }

    @Test("the toggle uses current scope and preserves saved tool placement")
    func preferences() throws {
        for json in ["{}", #"{"fileVisibility":"invalid"}"#] {
            #expect(try !JSONDecoder().decode(FileToolsPreferences.self, from: Data(json.utf8)).fileVisibility)
        }
        let legacy = Data(#"{"isEnabled":true,"fileVisibility":true,"mainMenuTools":["fileVisibility"]}"#.utf8)
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.fileTools = try JSONDecoder().decode(FileToolsPreferences.self, from: legacy)
        #expect(FileToolsPolicy.allowsHiddenFilesToggle(in: root, preferences: preferences))
        #expect(!FileToolsPolicy.allowsHiddenFilesToggle(in: root.appendingPathExtension("other"), preferences: preferences))
        let remote = try #require(URL(string: "file://example.test/Users/example/Work"))
        #expect(!FileToolsPolicy.allowsHiddenFilesToggle(in: remote, preferences: preferences))
        let tools = FileToolsPolicy.menuActions(directory: root, selection: [], isItemMenu: false,
            isContainer: true, preferences: preferences).compactMap(\.tool)
        let layout = FileToolsMenuLayout(tools: tools, hasMoveDestination: false, preferences: preferences.fileTools)
        #expect(layout.main == [.fileVisibility] && layout.submenu == [.copyPaths])
        preferences.fileTools.isEnabled = false
        #expect(!FileToolsPolicy.allowsHiddenFilesToggle(in: root, preferences: preferences))
        #expect(preferences.fileTools.fileVisibility && preferences.fileTools.mainMenuTools == [.fileVisibility])
        preferences.fileTools.isEnabled = true
        preferences.fileTools.setEnabled(false, for: .fileVisibility)
        #expect(!FileToolsPolicy.allowsHiddenFilesToggle(in: root, preferences: preferences))
    }

    @Test("Finder display tickets are bound to their route and consumed once")
    func tickets() throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storage) }
        let store = FileOperationTicketStore(directory: storage)
        let request = FileOperationRequest.toggleHiddenFiles(directory: root)
        let now = Date()
        let url = try store.enqueue(request, now: now)
        #expect(FileOperationTicketStore.handlesRoute(url))
        #expect(FileOperationTicketStore.isToggleHiddenFilesURL(url))
        #expect(try store.consume(url, now: now) == request)
        #expect(try store.consume(url, now: now) == nil)

        let expired = try store.enqueue(request, now: now)
        #expect(try store.consume(expired, now: now.addingTimeInterval(61)) == nil)
        #expect(try store.consume(expired, now: now) == nil)

        let move = try store.enqueue(.prepare([root]), now: now)
        var wrongRoute = try #require(URLComponents(url: move, resolvingAgainstBaseURL: false))
        wrongRoute.host = url.host
        #expect(try store.consume(try #require(wrongRoute.url), now: now) == nil)
        #expect(try store.consume(move, now: now) == nil)
    }
}

import FileMintCore
import Foundation
import Testing

@Suite("Open with App")
struct OpenWithTests {
    private let root = URL(fileURLWithPath: "/Users/example/Work", isDirectory: true)

    private func app(_ name: String = "Visual Studio Code", placement: OpenWithMenuPlacement = .submenu) -> OpenWithApplication {
        OpenWithApplication(name: name, bundleIdentifier: "example.\(name)",
            url: URL(fileURLWithPath: "/Applications/\(name).app"), bookmark: Data([1, 2, 3]), placement: placement)
    }

    private func preferences(_ apps: [OpenWithApplication]) -> FileMintPreferences {
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.openWith.applications = apps
        return preferences
    }

    @Test("old preferences start empty and new entries default to submenu without changing other modules")
    func defaultsAndPersistence() throws {
        let old = try JSONDecoder().decode(FileMintPreferences.self,
            from: Data(#"{"language":"zh-Hans","revealAfterCreation":false,"fileTools":{"isEnabled":true}}"#.utf8))
        #expect(old.openWith.applications.isEmpty)
        #expect(old.language == .chinese && !old.revealAfterCreation && old.fileTools.isEnabled)
        var value = old
        let added = app()
        #expect(added.placement == .submenu)
        value.openWith.add(added)
        value.openWith.add(app("Preview", placement: .main))
        let saved = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(value))
        #expect(saved.openWith == value.openWith)
        #expect(saved.fileTools == old.fileTools && saved.resourceTools == old.resourceTools)
        #expect(saved.templates == old.templates && saved.monitoredFolderURLs == old.monitoredFolderURLs)
    }

    @Test("all placements partition apps exactly once and hide only an empty submenu")
    func placement() {
        let empty = OpenWithMenuLayout(applications: [])
        #expect(empty.main.isEmpty && empty.submenu.isEmpty && !empty.showsSubmenu)
        for mask in 0..<8 {
            let apps = (0..<3).map { app("App \($0)", placement: mask & (1 << $0) == 0 ? .submenu : .main) }
            let layout = OpenWithMenuLayout(applications: apps)
            #expect(layout.main == apps.filter { $0.placement == .main })
            #expect(layout.submenu == apps.filter { $0.placement == .submenu })
            #expect(layout.main.count + layout.submenu.count == apps.count)
            #expect(Set((layout.main + layout.submenu).map(\.id)).count == apps.count)
            #expect(layout.showsSubmenu == (mask != 7))
        }
    }

    @Test("files, folders and mixed selections are allowed only for a complete local in-scope item menu")
    func selectionScope() {
        let preferences = preferences([app()])
        let file = root.appendingPathComponent("文档 % 🪴.txt")
        let folder = root.appendingPathComponent("Folder", isDirectory: true)
        for selection in [[file], [folder], [file, folder]] {
            #expect(OpenWithPolicy.availableApplications(selection: selection, isItemMenu: true,
                preferences: preferences).count == 1)
            #expect(OpenWithPolicy.availableApplications(selection: selection, isItemMenu: false,
                preferences: preferences).isEmpty)
        }
        #expect(OpenWithPolicy.availableApplications(selection: [], isItemMenu: true, preferences: preferences).isEmpty)
        for outsider in [URL(fileURLWithPath: "/Users/example/Work-other/a.txt"),
                         URL(string: "https://example.com/a.txt")!,
                         URL(string: "file://server/Users/example/Work/a.txt")!,
                         URL(string: "file:///Users/example/Work/a.txt?launch=1")!] {
            #expect(OpenWithPolicy.availableApplications(selection: [file, outsider], isItemMenu: true,
                preferences: preferences).isEmpty)
        }
    }

    @Test("duplicate apps refresh their access and location, retaining order, ID and placement")
    func duplicates() {
        var preferences = OpenWithPreferences()
        let first = app(placement: .main)
        let second = app("Preview")
        preferences.add(first)
        preferences.add(second)
        var moved = first
        moved.url = URL(fileURLWithPath: "/Users/example/Applications/Code.app")
        moved.bookmark = Data([4, 5, 6])
        moved.placement = .submenu
        preferences.add(moved)
        #expect(preferences.applications.map(\.id) == [first.id, second.id])
        #expect(preferences.applications[0].placement == .main)
        #expect(preferences.applications[0].url == moved.url && preferences.applications[0].bookmark == moved.bookmark)
        let replacement = OpenWithApplication(name: "Replacement", bundleIdentifier: "example.replacement",
            url: moved.url, bookmark: Data([7]))
        preferences.add(replacement)
        #expect(preferences.applications.count == 2)
        #expect(preferences.applications[0].id == first.id && preferences.applications[0].placement == .main)
        #expect(preferences.applications[0].bundleIdentifier == "example.replacement")
    }

    @Test("malformed records are isolated and invalid placement safely defaults to submenu")
    func malformedRecords() throws {
        let first = app()
        let last = app("Preview", placement: .main)
        let encode: (OpenWithApplication) throws -> [String: Any] = {
            try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as! [String: Any]
        }
        var badPlacement = try encode(first)
        badPlacement["placement"] = "unknown"
        var remote = try encode(app("Remote"))
        remote["url"] = "https://example.com/Remote.app"
        var emptyName = try encode(app("Blank"))
        emptyName["name"] = " "
        let json: [String: Any] = ["applications": [badPlacement, NSNull(), ["name": "partial"], remote,
                                                  emptyName, try encode(first), try encode(last)]]
        let value = try JSONDecoder().decode(OpenWithPreferences.self,
            from: JSONSerialization.data(withJSONObject: json))
        #expect(value.applications.map(\.id) == [first.id, last.id])
        #expect(value.applications[0].placement == .submenu && value.applications[1].placement == .main)
    }

    @Test("menu snapshots keep their original selection and reject removed, replaced or out-of-scope apps")
    func staleMenu() throws {
        let app = app()
        var preferences = preferences([app])
        var selection = [root.appendingPathComponent("first.txt"), root.appendingPathComponent("Folder")]
        var registry = FileMenuActionRegistry()
        let tag = registry.register([FileMenuAction(directory: root, openWithApplication: app.reference, selection: selection)])[0]
        selection = [root.appendingPathComponent("later.txt")]
        _ = registry.register([FileMenuAction(directory: root, openWithApplication: app.reference, selection: selection)])
        let snapshot = registry.takeAction(for: tag)
        let action = try #require(snapshot)
        #expect(action.selection.map(\.lastPathComponent) == ["first.txt", "Folder"])
        let consumed = registry.takeAction(for: tag)
        #expect(consumed == nil)
        let reference = try #require(action.openWithApplication)
        #expect(OpenWithPolicy.application(for: reference, selection: action.selection, preferences: preferences) == app)
        preferences.openWith.applications[0].placement = .main
        #expect(OpenWithPolicy.application(for: reference, selection: action.selection, preferences: preferences) != nil)
        preferences.openWith.applications[0].url = URL(fileURLWithPath: "/Applications/Other.app")
        #expect(OpenWithPolicy.application(for: reference, selection: action.selection, preferences: preferences) == nil)
        preferences.openWith.applications = []
        #expect(OpenWithPolicy.application(for: reference, selection: action.selection, preferences: preferences) == nil)
        preferences.openWith.applications = [app]
        preferences.monitoredFolderURLs = []
        #expect(OpenWithPolicy.application(for: reference, selection: action.selection, preferences: preferences) == nil)
    }

    @Test("opening uses private single-use expiring tickets, preserving literal paths and app identity")
    func transport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileOperationTicketStore(directory: directory)
        let request = FileOperationRequest.openWith(application: app().reference,
            selection: [root.appendingPathComponent("资料 % & #.txt"), root.appendingPathComponent("a folder")])
        let now = Date()
        let url = try store.enqueue(request, now: now)
        #expect(!url.absoluteString.contains(".app") && !url.absoluteString.contains("txt"))
        #expect(try store.consume(url, now: now) == request)
        #expect(try store.consume(url, now: now) == nil)
        let expired = try store.enqueue(request, now: now)
        #expect(try store.consume(expired, now: now.addingTimeInterval(61)) == nil)
        #expect(try store.consume(URL(string: "filemint://move?app=/Applications/Code.app&file=/tmp/a")!) == nil)
    }

    @Test("menu wording is localized and app names are literal, not format strings")
    func labels() {
        let app = app("Code %@ 资料")
        #expect(app.menuTitle(language: .chinese) == "使用「Code %@ 资料」打开")
        #expect(app.menuTitle(language: .english) == "Open with Code %@ 资料")
        for key in [FileMintTextKey.openWithApps, .openWithAppsHint, .addApplication, .openWithEmptyTitle,
                    .openWithEmptyHint, .openWithSubmenu, .openWithMenuHint, .openWithUnavailableApp,
                    .openWithChanged, .openWithMissingSelection, .openWithFailed] {
            #expect(FileMintStrings.text(key, language: .english) != key.rawValue)
            #expect(FileMintStrings.text(key, language: .english) != FileMintStrings.text(key, language: .chinese))
        }
    }
}

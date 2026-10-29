import Foundation
import Testing
@testable import FileMintCore

struct QuickSearchTests {
    @Test("shortcut migration is opt-in and corrupt fields do not reset neighbors")
    func shortcutMigration() throws {
        for field in ["", ",\"globalShortcut\":null", ",\"globalShortcut\":42"] {
            let json = "{\"showMenuBar\":false,\"language\":\"en\"\(field)}"
            let preferences = try FileMintPreferencesStore.decode(Data(json.utf8))
            #expect(!preferences.globalShortcut.isEnabled)
            #expect(preferences.globalShortcut.combination == nil)
            #expect(!preferences.showMenuBar && preferences.language == .english)
        }
        let valid = #"{"globalShortcut":{"isEnabled":"bad","combination":{"keyCode":40,"modifiers":6144}},"showMenuBar":false}"#
        let recovered = try FileMintPreferencesStore.decode(Data(valid.utf8))
        #expect(!recovered.globalShortcut.isEnabled)
        #expect(recovered.globalShortcut.combination == .init(keyCode: 40, modifiers: 6144))
        for key in [#"{"keyCode":55,"modifiers":6144}"#, #"{"keyCode":40,"modifiers":512}"#, #"{"keyCode":-1,"modifiers":6144}"#, #"{"keyCode":40,"modifiers":999999}"#] {
            let data = Data("{\"globalShortcut\":{\"isEnabled\":true,\"combination\":\(key)},\"showMenuBar\":false}".utf8)
            let restored = try FileMintPreferencesStore.decode(data)
            #expect(restored.globalShortcut.isEnabled && restored.globalShortcut.combination == nil)
            #expect(restored.globalShortcut.effectiveCombination == nil && !restored.showMenuBar)
        }
    }

    @Test("off preserves the chosen combination through a real store round trip")
    func shortcutPersistence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("shortcut-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileMintPreferencesStore(fileURL: root.appendingPathComponent("settings.json"))
        var preferences = FileMintPreferences.default
        let combination = GlobalShortcut(keyCode: 40, modifiers: GlobalShortcut.control | GlobalShortcut.option)
        preferences.globalShortcut = .init(isEnabled: true, combination: combination)
        try store.save(preferences)
        #expect(store.load().globalShortcut.effectiveCombination == combination)
        preferences.globalShortcut.isEnabled = false
        try store.save(preferences)
        #expect(store.load().globalShortcut.combination == combination)
        #expect(store.load().globalShortcut.effectiveCombination == nil)
    }

    @Test("unified search keeps bilingual actions and same-suffix template identities")
    func templatesAndActions() {
        var preferences = FileMintPreferences.default
        preferences.language = .chinese
        let first = FileTemplate(id: "notes-a", displayName: "Project Notes", suggestedFileName: "Notes.md",
                                 group: "QA", content: "", rank: 100, fileExtension: "md")
        var second = first
        second.id = "notes-b"; second.displayName = "Meeting Notes"; second.rank = 101
        preferences.templates += [first, second]
        preferences.templateMenuPlacements[first.id] = .hidden
        let catalog = FavoriteLocationsCatalog()
        let matches = QuickSearchCatalog.search(".md", preferences: preferences, favorites: catalog)
        #expect(matches.contains { $0.id == .template("notes-a") })
        #expect(matches.contains { $0.id == .template("notes-b") })
        #expect(QuickSearchCatalog.search("project", preferences: preferences, favorites: catalog).first?.id == .template("notes-a"))
        #expect(QuickSearchCatalog.search("clipboard", preferences: preferences, favorites: catalog).contains { $0.id == .command(.clipboardText) })
        preferences.templates[preferences.templates.firstIndex { $0.id == first.id }!].isEnabled = false
        #expect(!QuickSearchCatalog.search("notes", preferences: preferences, favorites: catalog).contains { $0.id == .template(first.id) })
        preferences.templates.removeAll { $0.id == second.id }
        #expect(!QuickSearchCatalog.search("notes", preferences: preferences, favorites: catalog).contains { $0.id == .template(second.id) })
    }

    @Test("favorite lookup uses saved text only and empty search remains bounded")
    func savedFavorites() {
        let favorites = (0..<1_000).map { index in
            FavoriteLocation(url: URL(fileURLWithPath: "/never-access-this-quick-search-fixture/\(index).txt"),
                bookmark: Data([1]), device: 1, inode: UInt64(index + 1), kind: .file,
                name: "Item \(index)", group: "工作", isPinned: index < 20,
                lastLocatedAt: Date(timeIntervalSince1970: Double(index)))
        }
        let catalog = FavoriteLocationsCatalog(items: favorites)
        let preferences = FileMintPreferences.default
        #expect(QuickSearchCatalog.search("工作", preferences: preferences, favorites: catalog)
            .filter { $0.group == .favorites }.count == 1_000)
        #expect(QuickSearchCatalog.search("Item 42", preferences: preferences, favorites: catalog).first?.id == .favorite(favorites[42].id))
        #expect(QuickSearchCatalog.search("/42.txt", preferences: preferences, favorites: catalog).first?.id == .favorite(favorites[42].id))
        let empty = QuickSearchCatalog.search("  ", preferences: preferences, favorites: catalog)
        #expect(empty.filter { $0.group == .favorites }.count == 10)
        #expect(empty.filter { $0.group == .actions }.count == 3)
    }

    @Test("catalog changes do not silently transfer keyboard selection to another row")
    func stableSelection() {
        let a = QuickSearchResult(id: .settings("general"), title: "General", detail: "", symbol: "gear")
        let b = QuickSearchResult(id: .settings("folders"), title: "Folders", detail: "", symbol: "folder")
        var selection = QuickSearchSelection()
        selection.reconcile([a, b], reset: true)
        #expect(selection.id == a.id)
        selection.reconcile([b, a], reset: false)
        #expect(selection.id == a.id)
        selection.reconcile([b], reset: false)
        #expect(selection.id == nil)
        selection.move(1, in: [b])
        #expect(selection.id == b.id)
        let matches = QuickSearchCatalog.search("appearance", preferences: .default, favorites: .init(),
            settings: [.init(id: a.id, title: "通用", detail: "", symbol: "gear", keywords: ["appearance", "外观"])])
        #expect(matches.map(\.id) == [a.id])
    }

    @Test("empty categories browse enabled snapshots while All keeps bounded suggestions")
    func emptyScopes() {
        var preferences = FileMintPreferences.default
        preferences.templates = [
            FileTemplate(id: "later", displayName: "Notes B", suggestedFileName: "B.md",
                         group: "QA", content: "", rank: 20),
            FileTemplate(id: "disabled", displayName: "Disabled", suggestedFileName: "Disabled.md",
                         group: "QA", content: "", isEnabled: false, rank: 0),
            FileTemplate(id: "first", displayName: "Notes A", suggestedFileName: "A.md",
                         group: "QA", content: "", rank: 10)
        ]
        preferences.templateMenuPlacements["first"] = .hidden
        let items = (0..<12).map { index in
            FavoriteLocation(url: URL(fileURLWithPath: "/never-access-this-quick-search-fixture/\(index)"),
                bookmark: Data([1]), device: 1, inode: UInt64(index + 1), kind: .folder,
                name: "Folder \(index)", isPinned: index < 6,
                addedAt: Date(timeIntervalSince1970: Double(index)))
        }
        let favorites = FavoriteLocationsCatalog(items: items)
        let settings = [
            QuickSearchResult(id: .settings("general"), title: "General", detail: "", symbol: "gear"),
            QuickSearchResult(id: .settings("about"), title: "About", detail: "", symbol: "info.circle")
        ]
        func search(_ scope: QuickSearchGroup? = nil) -> [QuickSearchResult] {
            QuickSearchCatalog.search(" \n ", preferences: preferences, favorites: favorites,
                                      settings: settings, scope: scope)
        }

        #expect(search().map(\.id) == [.command(.newFile), .command(.clipboardText), .command(.clipboardImage)]
            + [0, 1, 2, 3, 4, 5, 11, 10, 9, 8].map { .favorite(items[$0].id) })
        #expect(search(.actions).map(\.id) == [.command(.newFile), .command(.clipboardText), .command(.clipboardImage)])
        #expect(search(.templates).map(\.id) == [.template("first"), .template("later")])
        #expect(search(.favorites).map(\.id) == items.map { .favorite($0.id) })
        #expect(search(.settings) == settings)
        #expect(QuickSearchCatalog.search("", preferences: preferences, favorites: .init(), scope: .favorites).isEmpty)
        #expect(QuickSearchCatalog.search("", preferences: preferences, favorites: favorites, scope: .settings).isEmpty)
    }

    @Test("scopes retain query ranking and stable identities across categories")
    func scopedMatches() {
        var preferences = FileMintPreferences.default
        preferences.language = .english
        preferences.templates = [
            FileTemplate(id: "prefix", displayName: "Clipboard Notes", suggestedFileName: "A.md",
                         group: "QA", content: "", rank: 0),
            FileTemplate(id: "exact", displayName: "Clipboard", suggestedFileName: "B.md",
                         group: "QA", content: "", rank: 1)
        ]
        let favorite = FavoriteLocation(url: URL(fileURLWithPath: "/never-access-this-quick-search-fixture/clipboard"),
            bookmark: Data([1]), device: 1, inode: 1, kind: .folder, name: "Clipboard")
        let favorites = FavoriteLocationsCatalog(items: [favorite])
        let settings = [QuickSearchResult(id: .settings("creation"), title: "Creation", detail: "", symbol: "gear",
                                          keywords: ["clipboard"])]
        let query = " CLIPBOARD "
        let all = QuickSearchCatalog.search(query, preferences: preferences, favorites: favorites, settings: settings)
        #expect(all.map(\.id) == [.command(.clipboardText),
                                 .template("exact"), .template("prefix"), .favorite(favorite.id), .settings("creation")])
        for scope in QuickSearchGroup.allCases {
            let scoped = QuickSearchCatalog.search(query, preferences: preferences, favorites: favorites,
                                                    settings: settings, scope: scope)
            #expect(scoped == all.filter { $0.group == scope })
        }
        #expect(QuickSearchCatalog.search(".md", preferences: preferences, favorites: favorites,
                                         settings: settings, scope: .templates).map(\.id)
            == [.template("prefix"), .template("exact")])
        #expect(QuickSearchCatalog.search(".md", preferences: preferences, favorites: favorites,
                                         settings: settings, scope: .settings).isEmpty)

        var selection = QuickSearchSelection()
        selection.reconcile(all, reset: true)
        selection.select(.favorite(favorite.id))
        let templates = QuickSearchCatalog.search(query, preferences: preferences, favorites: favorites,
                                                  settings: settings, scope: .templates)
        selection.reconcile(templates, reset: true)
        #expect(selection.id == .template("exact"))
        preferences.templates.removeAll { $0.id == "exact" }
        let refreshed = QuickSearchCatalog.search(query, preferences: preferences, favorites: favorites,
                                                  settings: settings, scope: .templates)
        selection.reconcile(refreshed, reset: false)
        #expect(selection.id == nil)
        selection.move(1, in: refreshed)
        #expect(selection.id == .template("prefix"))
    }
}

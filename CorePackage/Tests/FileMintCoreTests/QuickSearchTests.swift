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
}

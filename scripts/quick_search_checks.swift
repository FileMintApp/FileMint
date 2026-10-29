import AppKit
import FileMintCore
import SwiftUI

@MainActor
enum QuickSearchChecks {
    private static var model: PreferencesModel?
    private static var search: QuickSearchPanelController?
    private static var window: NSWindow?

    private struct Failure: Error { let message: String }
    private static func check(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
        guard try condition() else { throw Failure(message: label) }
    }

    static func cleanup() {
        model?.globalShortcuts.shutdown(); search?.close(); window?.close()
        model = nil; search = nil; window = nil
    }

    static func run(root: URL, interactive: Bool) async throws {
        let store = FileMintPreferencesStore(fileURL: root.appendingPathComponent("preferences.json"))
        var preferences = FileMintPreferences.default
        preferences.language = .chinese; preferences.launchAtLogin = false
        preferences.automaticallyChecksForUpdates = false; preferences.showMenuBar = false
        preferences.monitoredFolderURLs = [root]; preferences.revealAfterCreation = false
        preferences.templates.append(FileTemplate(id: "quick-search-notes", displayName: "会议纪要",
            suggestedFileName: "会议.md", group: "QA", content: "# Fixture", rank: 200, fileExtension: "md"))
        try store.save(preferences)
        let model = PreferencesModel(store: store, documentTemplates: DocumentTemplateStore(directory: root.appendingPathComponent("assets"),
            bundledDirectory: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/OfficeTemplates")))
        self.model = model
        for _ in 0..<100 {
            if model.templateRecoveryError == nil && !model.isMutatingTemplates { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try check(model.templateRecoveryError == nil, "template recovery did not finish")
        let favorites = FavoriteLocationsModel(store: .init(file: root.appendingPathComponent("favorites.json")))
        await favorites.waitUntilLoaded()
        let example = root.appendingPathComponent("Favorite Example.txt")
        try Data("isolated fixture".utf8).write(to: example)
        _ = try await favorites.add([example])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "FileMint · 快捷搜索与通用设置验收（隔离）"
        window.isReleasedWhenClosed = false
        self.window = window
        let search = QuickSearchPanelController(openSettings: { [weak model, weak window] pane in
            model?.selectedPane = pane; window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        })
        self.search = search
        let updater = UpdateModel(preferencesModel: model, checkRelease: { _ in nil })
        window.contentView = NSHostingView(rootView: ContentView(favoriteLocations: favorites, quickSearch: search)
            .environmentObject(model).environmentObject(updater))
        model.startGlobalShortcut(searchController: search, favorites: favorites)
        model.selectedPane = .general
        if interactive {
            NSApp.setActivationPolicy(.regular)
            window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            let menu = NSMenu(), app = NSMenuItem(), items = NSMenu()
            items.addItem(withTitle: "Quit QA", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            app.submenu = items; menu.addItem(app); NSApp.mainMenu = menu
            return
        }

        let key = GlobalShortcut(keyCode: 40, modifiers: GlobalShortcut.control | GlobalShortcut.option)
        model.setGlobalShortcutEnabled(true)
        try check(model.globalShortcuts.isRegistered && store.load().globalShortcut.combination == .suggested,
                  "first enable did not fill and register the suggested combination")
        model.setGlobalShortcutEnabled(false)
        model.setGlobalShortcutCombination(nil)
        model.setGlobalShortcutCombination(key)
        try check(!model.globalShortcuts.isRegistered && !store.load().globalShortcut.isEnabled,
                  "recording implicitly enabled global registration")
        try check(store.load().globalShortcut.combination == key, "disabled key not persisted")
        model.setGlobalShortcutEnabled(true)
        try check(model.globalShortcuts.isRegistered && store.load().globalShortcut.isEnabled, "enable not registered/saved")
        let saved = try Data(contentsOf: store.location!)
        let corrupt = Data("preserve corrupt QA bytes".utf8)
        try corrupt.write(to: store.location!, options: .atomic)
        model.setGlobalShortcutEnabled(false)
        try check(model.preferences.globalShortcut.isEnabled && model.globalShortcuts.isRegistered,
                  "failed disable save released committed key")
        try check(try Data(contentsOf: store.location!) == corrupt, "failed save overwrote damaged bytes")
        try saved.write(to: store.location!, options: .atomic)
        model.setGlobalShortcutEnabled(false)
        try check(!model.globalShortcuts.isRegistered && store.load().globalShortcut.combination == key,
                  "disable forgot combination or retained registration")
        model.setGlobalShortcutCombination(nil)
        try check(store.load().globalShortcut.combination == nil, "clear not persisted")
        let custom = GlobalShortcut(keyCode: 40, modifiers: GlobalShortcut.control | GlobalShortcut.option | GlobalShortcut.shift)
        model.setGlobalShortcutCombination(custom)
        model.setGlobalShortcutEnabled(true)
        try check(model.globalShortcuts.isRegistered && store.load().globalShortcut.combination == custom,
                  "enable overwrote a custom combination")
        model.setGlobalShortcutEnabled(false)
        model.setGlobalShortcutCombination(nil)
        try await checkSearchInput()

        let destinations = QuickSearchSettingsCatalog.entries(language: .chinese)
        try check(QuickSearchCatalog.search("外观", preferences: model.committedPreferences,
                    favorites: favorites.catalog, settings: destinations).contains { $0.id == .settings("general") },
                  "settings keyword lookup")
        search.show(settings: model, favorites: favorites)
        let first = search.panel
        search.show(settings: model, favorites: favorites)
        try check(first != nil && first === search.panel, "search opened a second panel")
        try await search.execute(.settings("fileTypes"), settings: model, favorites: favorites)
        try check(model.selectedPane == .fileTypes && search.panel == nil, "settings result failed navigation")

        for stale in [QuickSearchID.template("removed-template"), .favorite(UUID()), .settings("missing-pane")] {
            do {
                try await search.execute(stale, settings: model, favorites: favorites)
                throw Failure(message: "stale result executed")
            } catch QuickSearchExecutionError.unavailable {}
        }
        let draft = CustomFileSavePanelController.shared
        draft.present(in: root, preferences: model.committedPreferences, initialText: "unsaved sentinel")
        guard let draftWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "io.github.daigua.filemint.custom-file" }) else {
            throw Failure(message: "creation draft not opened")
        }
        let views = descendants(draftWindow.contentView!)
        let editor = views.compactMap { $0 as? NSTextView }.first { $0.string == "unsaved sentinel" }
        try check(editor != nil, "draft content fixture missing")
        try await search.execute(.template("quick-search-notes"), settings: model, favorites: favorites)
        try check(draft.hasActiveDraft && editor?.string == "unsaved sentinel",
                  "template search replaced the active draft")
        // An old-result regression may request New File. Keep an existing draft
        // so the failure focuses this isolated fixture instead of opening a picker.
        try await checkImmediateSearchSubmission(search: search, model: model, favorites: favorites)
        try check(draft.hasActiveDraft && editor?.string == "unsaved sentinel",
                  "rapid search input changed the existing draft")
        draftWindow.performClose(nil)
        try check(!draft.hasActiveDraft, "draft cleanup failed")
        try await checkFavoriteSessionCompletion(model: model, favorites: favorites)

        let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 250, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        sheet.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        window.beginSheet(sheet, completionHandler: { _ in })
        search.show(settings: model, favorites: favorites)
        try check(search.panel == nil, "search replaced modal sheet")
        window.endSheet(sheet); sheet.orderOut(nil)
        try check(try Data(contentsOf: example) == Data("isolated fixture".utf8), "search modified fixture content")
        cleanup()
    }

    private static func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    private static func searchField(in panel: NSPanel) async throws -> NSSearchField {
        for _ in 0..<100 {
            if let content = panel.contentView,
               let field = descendants(content).compactMap({ $0 as? NSSearchField }).first {
                panel.makeFirstResponder(field)
                if field.currentEditor() != nil { return field }
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure(message: "quick search input did not mount")
    }

    /// Queue the whole burst before yielding, using AppKit's real event dispatch.
    /// Direct delegate calls alone miss the deferred SwiftUI onChange regression.
    private static func postKeys(_ keys: [(String, UInt16)], to panel: NSPanel) throws {
        for (characters, keyCode) in keys {
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                context: nil, characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: false, keyCode: keyCode) else { throw Failure(message: "could not create search key event") }
            NSApp.postEvent(event, atStart: false)
        }
    }

    private static func checkImmediateSearchSubmission(search: QuickSearchPanelController,
                                                       model: PreferencesModel,
                                                       favorites: FavoriteLocationsModel) async throws {
        defer { search.close() }
        model.selectedPane = .general
        search.show(settings: model, favorites: favorites)
        guard let panel = search.panel else { throw Failure(message: "rapid-input search panel missing") }
        _ = try await searchField(in: panel)
        try postKeys([("a", 0), ("b", 11), ("o", 31), ("u", 32), ("t", 17), ("\r", 36)], to: panel)
        for _ in 0..<100 {
            if model.selectedPane == .about && search.panel == nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try check(model.selectedPane == .about && search.panel == nil,
                  "immediate Return executed the previous query instead of About")

        model.selectedPane = .general
        search.show(settings: model, favorites: favorites)
        guard let emptyPanel = search.panel else { throw Failure(message: "empty-result search panel missing") }
        let field = try await searchField(in: emptyPanel)
        try postKeys([("z", 6), ("z", 6), ("z", 6), ("\r", 36)], to: emptyPanel)
        try await Task.sleep(for: .milliseconds(100))
        try check(field.stringValue == "zzz" && search.panel === emptyPanel && model.selectedPane == .general,
                  "immediate Return executed a stale row for a query with no results")
    }

    @MainActor
    private final class FavoriteActivationGate {
        enum InjectedFailure: Error { case unavailable }
        private(set) var continuation: CheckedContinuation<Void, Error>?
        private(set) var calls: [(UUID, Bool)] = []

        func wait(id: UUID, openFile: Bool) async throws {
            calls.append((id, openFile))
            try await withCheckedThrowingContinuation { continuation = $0 }
        }

        func finish(error: Error? = nil) {
            let pending = continuation
            continuation = nil
            if let error { pending?.resume(throwing: error) }
            else { pending?.resume() }
        }

        func waitUntilStarted() async throws {
            for _ in 0..<100 {
                if continuation != nil { return }
                try await Task.sleep(for: .milliseconds(10))
            }
            throw Failure(message: "favorite activation did not reach the suspended operation")
        }
    }

    private static func checkFavoriteSessionCompletion(model: PreferencesModel,
                                                       favorites: FavoriteLocationsModel) async throws {
        guard let id = favorites.catalog.items.first?.id else { throw Failure(message: "favorite fixture missing") }
        for openFile in [false, true] {
            let gate = FavoriteActivationGate()
            let search = QuickSearchPanelController(openSettings: { _ in }, activateFavorite: { itemID, open, _ in
                try await gate.wait(id: itemID, openFile: open)
            })
            defer { gate.finish(); search.close() }
            search.show(settings: model, favorites: favorites)
            let oldPanel = search.panel
            let operation = Task {
                if openFile { try await search.activateFavorite(id, openFile: true, favorites: favorites) }
                else { try await search.execute(.favorite(id), settings: model, favorites: favorites) }
            }
            try await gate.waitUntilStarted()
            try check(gate.calls.first?.0 == id && gate.calls.first?.1 == openFile,
                      "favorite activation used the wrong identity or mode")
            search.close()
            search.show(settings: model, favorites: favorites)
            guard let replacement = search.panel, replacement !== oldPanel else {
                throw Failure(message: "favorite completion fixture did not replace the panel")
            }
            let field = try await searchField(in: replacement)
            try postKeys([("a", 0)], to: replacement)
            for _ in 0..<100 {
                if field.stringValue == "a" { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            try check(field.stringValue == "a", "replacement query was not entered")
            gate.finish()
            try await operation.value
            try check(search.panel === replacement && replacement.isVisible && field.stringValue == "a",
                      "old favorite completion closed the replacement search session")

            let currentOperation = Task {
                if openFile { try await search.activateFavorite(id, openFile: true, favorites: favorites) }
                else { try await search.execute(.favorite(id), settings: model, favorites: favorites) }
            }
            try await gate.waitUntilStarted()
            gate.finish()
            try await currentOperation.value
            try check(search.panel == nil, "current favorite completion did not close its own panel")

            search.show(settings: model, favorites: favorites)
            let failedPanel = search.panel
            let failedOperation = Task {
                if openFile { try await search.activateFavorite(id, openFile: true, favorites: favorites) }
                else { try await search.execute(.favorite(id), settings: model, favorites: favorites) }
            }
            try await gate.waitUntilStarted()
            gate.finish(error: FavoriteActivationGate.InjectedFailure.unavailable)
            do {
                try await failedOperation.value
                throw Failure(message: "favorite activation failure was swallowed")
            } catch FavoriteActivationGate.InjectedFailure.unavailable {}
            try check(failedPanel != nil && search.panel === failedPanel && failedPanel?.isVisible == true,
                      "failed favorite activation closed its search panel")
        }
    }

    private static func checkSearchInput() async throws {
        var query = "md", submissions = 0
        var field: NSSearchField?
        let host = NSHostingView(rootView: QuickSearchInputField(text: Binding(get: { query }, set: { query = $0 }),
            placeholder: "QA", move: { _ in }, submit: { submissions += 1 }, cancel: {}, onCreate: { field = $0 }))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 50),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(80))
        guard let field, let cell = field.cell as? NSSearchFieldCell else { throw Failure(message: "search input not mounted") }
        field.stringValue = "md"
        cell.cancelButtonCell?.performClick(field)
        try await Task.sleep(for: .milliseconds(80))
        try check(field.stringValue.isEmpty && submissions == 0, "clear search executed a result")
        guard let delegate = field.delegate as? QuickSearchInputField.Coordinator else { throw Failure(message: "input delegate missing") }
        let editor = NSTextView()
        editor.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        try check(!delegate.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))) && submissions == 0,
                  "IME confirmation executed a result")
        editor.unmarkText()
        try check(delegate.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))) && submissions == 1,
                  "committed Return did not execute once")
    }
}

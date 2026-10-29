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
        // The fixture does not use SwiftUI App's default menu. Supply the native
        // editing commands so Command-A/Delete tests exercise real text editing.
        let menu = NSMenu(), app = NSMenuItem(), items = NSMenu()
        items.addItem(withTitle: "Quit QA", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        app.submenu = items; menu.addItem(app)
        let edit = NSMenuItem(), editItems = NSMenu(title: "Edit")
        editItems.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItems.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editItems.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.submenu = editItems; menu.addItem(edit); NSApp.mainMenu = menu
        if interactive {
            NSApp.setActivationPolicy(.regular)
            window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
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
        guard let first = search.panel else { throw Failure(message: "initial search panel missing") }
        _ = try await searchField(in: first)
        // Repeated explicit show reuses the currently focused panel. Leaving it
        // for another window is tested separately as a dismissal.
        search.show(settings: model, favorites: favorites)
        try check(first === search.panel, "search opened a second panel")
        _ = try await searchField(in: first)
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
        try await checkScopedKeyboardNavigation(search: search, model: model, favorites: favorites)
        try await checkDismissalRestoration(search: search, model: model, favorites: favorites, otherWindow: window)
        try await checkTransientInteractionProtection(search: search, model: model, favorites: favorites, otherWindow: window)
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

    private static func searchField(in panel: NSPanel, caller: StaticString = #function, line: UInt = #line) async throws -> NSSearchField {
        for _ in 0..<100 {
            if let content = panel.contentView,
               let field = descendants(content).compactMap({ $0 as? NSSearchField }).first,
               panel.isKeyWindow, let editor = field.currentEditor(), panel.firstResponder === editor {
                // Observe natural focus after one further run-loop turn. Never
                // repair it here: doing so hides first-open and restore bugs.
                try await Task.sleep(for: .milliseconds(10))
                if panel.isKeyWindow && panel.firstResponder === editor && field.currentEditor() === editor {
                    return field
                }
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        let field = panel.contentView.flatMap { descendants($0).compactMap { $0 as? NSSearchField }.first }
        throw Failure(message: "quick search focus at \(caller):\(line): visible=\(panel.isVisible), key=\(panel.isKeyWindow), active=\(NSApp.isActive), canKey=\(panel.canBecomeKey), keyWindow=\(NSApp.keyWindow?.identifier?.rawValue ?? "nil"), responder=\(panel.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"), editor=\(field?.currentEditor().map { String(describing: type(of: $0)) } ?? "nil")")
    }

    /// Queue the whole burst before yielding, using AppKit's real event dispatch.
    /// Direct delegate calls alone miss the deferred SwiftUI onChange regression.
    private static func postKeys(_ keys: [(String, UInt16)], to panel: NSPanel,
                                 modifiers: NSEvent.ModifierFlags = []) throws {
        for (characters, keyCode) in keys {
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
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

    private static func waitForNavigation(_ pane: PreferencesModel.Pane,
                                          search: QuickSearchPanelController,
                                          model: PreferencesModel, failure: String) async throws {
        for _ in 0..<100 {
            if model.selectedPane == pane && search.panel == nil { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure(message: failure)
    }

    /// Keep shortcuts, edits and Return in one event burst. A deferred SwiftUI
    /// update must never make the new scope or cleared query execute an old row.
    private static func checkScopedKeyboardNavigation(search: QuickSearchPanelController,
                                                       model: PreferencesModel,
                                                       favorites: FavoriteLocationsModel) async throws {
        defer { search.close() }
        let about: [(String, UInt16)] = [("a", 0), ("b", 11), ("o", 31), ("u", 32), ("t", 17)]

        model.selectedPane = .general
        search.show(settings: model, favorites: favorites)
        guard let scopePanel = search.panel else { throw Failure(message: "scope search panel missing") }
        let scopeField = try await searchField(in: scopePanel)
        try postKeys(about, to: scopePanel)
        try postKeys([("2", 19)], to: scopePanel, modifiers: .command)
        try postKeys([("\r", 36)], to: scopePanel)
        try await Task.sleep(for: .milliseconds(100))
        try check(scopeField.stringValue == "about" && search.panel === scopePanel && model.selectedPane == .general,
                  "switching to Actions lost the query or immediately executed stale About")
        try postKeys([("5", 23)], to: scopePanel, modifiers: .command)
        try postKeys([("\r", 36)], to: scopePanel)
        try await waitForNavigation(.about, search: search, model: model,
                                    failure: "switching to Settings did not immediately execute the retained About query")

        search.show(settings: model, favorites: favorites)
        guard let clearPanel = search.panel else { throw Failure(message: "clear-query search panel missing") }
        let clearField = try await searchField(in: clearPanel)
        try postKeys([("5", 23)], to: clearPanel, modifiers: .command)
        try postKeys(about, to: clearPanel)
        for _ in 0..<100 {
            if clearField.stringValue == "about" { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try check(clearField.stringValue == "about", "clear-query fixture did not receive About")
        try postKeys([("a", 0)], to: clearPanel, modifiers: .command)
        try postKeys([("\u{7f}", 51), ("\r", 36)], to: clearPanel)
        try await waitForNavigation(.fileTypes, search: search, model: model,
                                    failure: "clearing the query did not immediately select the first Settings result")
        try check(clearField.stringValue.isEmpty, "clear-query shortcut did not clear the input")

        model.selectedPane = .about
        search.show(settings: model, favorites: favorites)
        guard let arrowPanel = search.panel else { throw Failure(message: "arrow-navigation panel missing") }
        _ = try await searchField(in: arrowPanel)
        try postKeys([("5", 23)], to: arrowPanel, modifiers: .command)
        try postKeys([("\u{f701}", 125), ("\u{f701}", 125), ("\u{f700}", 126)],
                     to: arrowPanel, modifiers: [.function, .numericPad])
        try postKeys([("\r", 36)], to: arrowPanel)
        try await waitForNavigation(.creation, search: search, model: model,
                                    failure: "real Down/Down/Up events did not select Creation in Settings")

        model.selectedPane = .general
        search.show(settings: model, favorites: favorites)
        guard let escapePanel = search.panel else { throw Failure(message: "Escape search panel missing") }
        _ = try await searchField(in: escapePanel)
        try postKeys([("3", 20)], to: escapePanel, modifiers: .command)
        try postKeys([("z", 6), ("\u{1b}", 53)], to: escapePanel)
        for _ in 0..<100 {
            if search.panel == nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try check(search.panel == nil && model.selectedPane == .general, "Escape executed a result or failed to close")
        search.show(settings: model, favorites: favorites)
        guard let reopened = search.panel else { throw Failure(message: "search did not reopen after Escape") }
        let reopenedField = try await searchField(in: reopened)
        try check(reopenedField.stringValue == "z", "Escape discarded the unfinished query")
        try check((reopenedField.currentEditor() as? NSTextView)?.selectedRange() == NSRange(location: 0, length: 1),
                  "reopened query was not selected for replacement")
        try postKeys(about + [("\r", 36)], to: reopened)
        try await Task.sleep(for: .milliseconds(100))
        try check(reopenedField.stringValue == "about" && search.panel === reopened && model.selectedPane == .general,
                  "reopening did not preserve Templates scope or replace the selected query")
        try postKeys([("1", 18)], to: reopened, modifiers: .command)
        try postKeys([("\r", 36)], to: reopened)
        try await waitForNavigation(.about, search: search, model: model,
                                    failure: "All shortcut did not leave the restored Templates scope")
        print("PASS quick search keyboard: immediate scope/clear submission, arrow navigation and Escape restoration")
        fflush(nil)
    }

    private static func waitUntilClosed(_ search: QuickSearchPanelController, failure: String) async throws {
        for _ in 0..<100 {
            if search.panel == nil { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure(message: failure)
    }

    private static func waitForText(_ text: String, in field: NSSearchField) async throws {
        for _ in 0..<100 {
            if field.stringValue == text { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw Failure(message: "search did not receive the fixture query")
    }

    @MainActor
    private final class ClickReceiptView: NSView {
        private(set) var mouseDownCount = 0
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { mouseDownCount += 1 }
    }

    private static func checkDismissalRestoration(search: QuickSearchPanelController,
                                                  model: PreferencesModel,
                                                  favorites: FavoriteLocationsModel,
                                                  otherWindow: NSWindow) async throws {
        defer { search.close() }
        // Successful dispatch ends the search, even when it started in a scope
        // that would not contain the next query.
        search.show(settings: model, favorites: favorites)
        guard let completedPanel = search.panel else { throw Failure(message: "handoff reset panel missing") }
        let completedField = try await searchField(in: completedPanel)
        try postKeys([("3", 20)], to: completedPanel, modifiers: .command)
        try postKeys([("z", 6)], to: completedPanel)
        try await waitForText("z", in: completedField)
        try await search.execute(.settings("general"), settings: model, favorites: favorites)
        search.show(settings: model, favorites: favorites)
        guard let freshPanel = search.panel else { throw Failure(message: "fresh search panel missing") }
        let freshField = try await searchField(in: freshPanel)
        try check(freshField.stringValue.isEmpty, "successful handoff retained its query")
        try postKeys([("a", 0), ("b", 11), ("o", 31), ("u", 32), ("t", 17), ("\r", 36)], to: freshPanel)
        try await waitForNavigation(.about, search: search, model: model,
                                    failure: "successful handoff retained Templates instead of resetting to All")

        // With no query, the first Settings row is Templates & Types and the
        // second is Creation. Return after restoration proves the selected ID,
        // rather than merely preserving the visible query text.
        search.show(settings: model, favorites: favorites)
        guard let selectionPanel = search.panel else { throw Failure(message: "selection retention panel missing") }
        _ = try await searchField(in: selectionPanel)
        try postKeys([("5", 23)], to: selectionPanel, modifiers: .command)
        try postKeys([("\u{f701}", 125)], to: selectionPanel, modifiers: [.function, .numericPad])
        try postKeys([("\u{1b}", 53)], to: selectionPanel)
        try await waitUntilClosed(search, failure: "Escape did not dismiss the selected Settings result")
        search.show(settings: model, favorites: favorites)
        guard let retainedPanel = search.panel else { throw Failure(message: "selected search did not reopen") }
        _ = try await searchField(in: retainedPanel)
        try postKeys([("\r", 36)], to: retainedPanel)
        try await waitForNavigation(.creation, search: search, model: model,
                                    failure: "reopening lost the Settings scope or the selected Creation result")

        search.show(settings: model, favorites: favorites)
        guard let togglePanel = search.panel else { throw Failure(message: "toggle panel missing") }
        let toggleField = try await searchField(in: togglePanel)
        try postKeys([("5", 23)], to: togglePanel, modifiers: .command)
        try postKeys([("a", 0), ("b", 11), ("o", 31), ("u", 32), ("t", 17)], to: togglePanel)
        try await waitForText("about", in: toggleField)
        model.globalShortcuts.onTrigger()
        try await waitUntilClosed(search, failure: "a focused shortcut toggle did not dismiss")
        model.globalShortcuts.onTrigger()
        guard let toggled = search.panel else { throw Failure(message: "toggle did not reopen") }
        let toggledField = try await searchField(in: toggled)
        try check(toggledField.stringValue == "about", "toggle lost the unfinished query")
        try check((toggledField.currentEditor() as? NSTextView)?.selectedRange() == NSRange(location: 0, length: 5),
                  "toggle did not select the restored query")
        try postKeys([("x", 7)], to: toggled)
        try await waitForText("x", in: toggledField)

        otherWindow.makeKeyAndOrderFront(nil)
        try await waitUntilClosed(search, failure: "switching to another native window did not dismiss search")
        search.show(settings: model, favorites: favorites)
        guard let afterSwitch = search.panel else { throw Failure(message: "search did not reopen after switching windows") }
        let switchedField = try await searchField(in: afterSwitch)
        try check(switchedField.stringValue == "x", "window switch discarded the unfinished query")

        let receipt = ClickReceiptView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        let external = NSWindow(contentRect: NSRect(x: 30, y: 30, width: 180, height: 80),
                                styleMask: [.titled, .closable], backing: .buffered, defer: false)
        external.isReleasedWhenClosed = false; external.contentView = receipt
        external.orderFront(nil)
        defer { external.close() }
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(with: type, location: NSPoint(x: 90, y: 40), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: external.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1) else {
                throw Failure(message: "could not create outside-click event")
            }
            NSApp.postEvent(event, atStart: false)
        }
        try await waitUntilClosed(search, failure: "an outside click did not dismiss search")
        try check(receipt.mouseDownCount == 1, "dismissal swallowed or replayed the outside click")
        search.show(settings: model, favorites: favorites)
        guard let afterClick = search.panel else { throw Failure(message: "search did not reopen after outside click") }
        let clickedField = try await searchField(in: afterClick)
        try check(clickedField.stringValue == "x", "outside click discarded the unfinished query")
        print("PASS quick search lifecycle: success reset, selected-result restoration, toggle, window switch and outside-click delivery")
        fflush(nil)
    }

    private static func checkTransientInteractionProtection(search: QuickSearchPanelController,
                                                             model: PreferencesModel,
                                                             favorites: FavoriteLocationsModel,
                                                             otherWindow: NSWindow) async throws {
        defer { search.close() }
        search.show(settings: model, favorites: favorites)
        guard let relatedOwner = search.panel else { throw Failure(message: "related-interaction search missing") }
        _ = try await searchField(in: relatedOwner)
        let finish = search.beginRelatedInteraction()
        let child = NSPanel(contentRect: NSRect(x: 40, y: 40, width: 240, height: 120),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        child.isReleasedWhenClosed = false
        child.isFloatingPanel = true
        var relatedFinished = false
        defer { child.close(); if !relatedFinished { finish() } }
        child.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(100))
        try check(search.panel === relatedOwner && relatedOwner.isVisible,
                  "a related native child window dismissed its search owner")
        child.close(); finish(); relatedFinished = true
        _ = try await searchField(in: relatedOwner)

        let pickerContext = search.captureOperation()
        let finishPicker = search.beginRelatedInteraction()
        let picker = NSPanel(contentRect: NSRect(x: 50, y: 50, width: 260, height: 120),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        picker.isReleasedWhenClosed = false
        defer { picker.close(); finishPicker() }
        var observedModal = false, protectedDuringModal = false
        let modalDismissal = Timer(timeInterval: 0.05, repeats: false) { _ in
            MainActor.assumeIsolated {
                observedModal = NSApp.modalWindow === picker
                protectedDuringModal = search.panel === relatedOwner && relatedOwner.isVisible
                NSApp.stopModal(withCode: .cancel)
            }
        }
        RunLoop.main.add(modalDismissal, forMode: .modalPanel)
        defer { modalDismissal.invalidate() }
        let response = NSApp.runModal(for: picker)
        modalDismissal.invalidate()
        picker.close()
        try check(response == .cancel && observedModal && protectedDuringModal,
                  "the native modal loop did not retain its search owner until cancellation")
        // AppKit can promote the main settings window before runModal returns
        // control to the picker caller. Reproduce that handoff synchronously.
        otherWindow.makeKeyAndOrderFront(nil)
        try check(NSApp.modalWindow == nil && otherWindow.isKeyWindow,
                  "modal completion fixture did not hand focus to the ordinary window")
        search.relatedPickerDidClose(pickerContext)
        finishPicker()
        _ = try await searchField(in: relatedOwner)

        let menu = NSMenu(title: "Search fixture menu")
        // Exercise the exact AppKit notifications consumed by the controller.
        // Real context-menu pointer tracking remains a separate UI smoke check.
        NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        otherWindow.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(100))
        try check(search.panel === relatedOwner && relatedOwner.isVisible,
                  "menu tracking was treated as leaving the search interaction")
        NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: menu)
        try await waitUntilClosed(search, failure: "search did not dismiss after menu tracking ended outside its window")

        search.show(settings: model, favorites: favorites)
        guard let composing = search.panel else { throw Failure(message: "composition search missing") }
        let field = try await searchField(in: composing)
        guard let editor = field.currentEditor() as? NSTextView else { throw Failure(message: "composition editor missing") }
        editor.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        try check(editor.hasMarkedText(), "composition fixture did not mark text")
        composing.resignKey()
        try await Task.sleep(for: .milliseconds(100))
        try check(search.panel === composing && composing.isVisible,
                  "passive focus loss during IME composition dismissed search")
        editor.unmarkText()
        otherWindow.makeKeyAndOrderFront(nil)
        search.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: composing))
        try await waitUntilClosed(search, failure: "search remained after composition ended and the user left its window")

        search.show(settings: model, favorites: favorites)
        guard let departingOwner = search.panel else { throw Failure(message: "related departure search missing") }
        let departingField = try await searchField(in: departingOwner)
        try postKeys([("q", 12)], to: departingOwner)
        try await waitForText("q", in: departingField)
        let finishAfterLeaving = search.beginRelatedInteraction()
        otherWindow.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(100))
        try check(search.panel === departingOwner && otherWindow.isKeyWindow,
                  "related departure fixture did not retain search while the other window became key")
        finishAfterLeaving()
        try await waitUntilClosed(search, failure: "finishing related work stole focus back instead of dismissing after departure")
        try check(otherWindow.isKeyWindow && NSApp.keyWindow === otherWindow,
                  "finishing related work stole keyboard focus from another app-owned window")
        search.show(settings: model, favorites: favorites)
        guard let afterDeparture = search.panel else { throw Failure(message: "related departure search did not restore") }
        let afterDepartureField = try await searchField(in: afterDeparture)
        try check(afterDepartureField.stringValue == "q", "related departure lost its unfinished query")

        let stalePickerContext = search.captureOperation()
        let finishStalePicker = search.beginRelatedInteraction()
        search.close()
        search.show(settings: model, favorites: favorites)
        guard let newerOwner = search.panel else { throw Failure(message: "newer picker-owner search missing") }
        let newerField = try await searchField(in: newerOwner)
        try postKeys([("r", 15)], to: newerOwner)
        try await waitForText("r", in: newerField)
        let finishNewerInteraction = search.beginRelatedInteraction()
        otherWindow.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(100))
        search.relatedPickerDidClose(stalePickerContext)
        finishStalePicker()
        try await Task.sleep(for: .milliseconds(30))
        try check(search.panel === newerOwner && newerOwner.isVisible && newerField.stringValue == "r"
                  && otherWindow.isKeyWindow,
                  "an old picker completion restored focus into a newer search interaction")
        finishNewerInteraction()
        try await waitUntilClosed(search, failure: "newer search did not dismiss after its unrelated work finished outside")
        search.show(settings: model, favorites: favorites)
        guard let restoredNewer = search.panel else { throw Failure(message: "newer picker-owner search did not restore") }
        let restoredNewerField = try await searchField(in: restoredNewer)
        try check(restoredNewerField.stringValue == "r", "old picker completion changed the newer search in memory")
        print("PASS quick search transient guards: native modal cancellation, picker-owner restoration, no stale focus theft, menu notifications and marked-text focus loss")
        fflush(nil)
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
            search.close()
            search.show(settings: model, favorites: favorites)
            guard let retained = search.panel else { throw Failure(message: "replacement favorite search did not restore") }
            let retainedField = try await searchField(in: retained)
            try check(retainedField.stringValue == "a", "old favorite completion cleared the replacement session in memory")

            let currentOperation = Task {
                if openFile { try await search.activateFavorite(id, openFile: true, favorites: favorites) }
                else { try await search.execute(.favorite(id), settings: model, favorites: favorites) }
            }
            try await gate.waitUntilStarted()
            gate.finish()
            try await currentOperation.value
            try check(search.panel == nil, "current favorite completion did not close its own panel")

            search.show(settings: model, favorites: favorites)
            guard let failedPanel = search.panel else { throw Failure(message: "favorite failure panel missing") }
            let failureField = try await searchField(in: failedPanel)
            try check(failureField.stringValue.isEmpty, "successful favorite activation did not clear the completed query")
            try postKeys([("x", 7)], to: failedPanel)
            try await waitForText("x", in: failureField)
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
            try check(search.panel === failedPanel && failedPanel.isVisible && failureField.stringValue == "x",
                      "failed favorite activation closed its panel or cleared its query")

            let hiddenFailure = Task {
                if openFile { try await search.activateFavorite(id, openFile: true, favorites: favorites) }
                else { try await search.execute(.favorite(id), settings: model, favorites: favorites) }
            }
            try await gate.waitUntilStarted()
            search.close()
            gate.finish(error: FavoriteActivationGate.InjectedFailure.unavailable)
            do {
                try await hiddenFailure.value
                throw Failure(message: "hidden favorite failure was swallowed")
            } catch FavoriteActivationGate.InjectedFailure.unavailable {}
            try check(search.panel == nil, "a hidden favorite failure reopened search")
            search.show(settings: model, favorites: favorites)
            guard let restoredFailure = search.panel else { throw Failure(message: "failed favorite search did not restore") }
            let restoredFailureField = try await searchField(in: restoredFailure)
            try check(restoredFailureField.stringValue == "x", "a hidden favorite failure lost the unfinished query")

            let hiddenSuccess = Task {
                if openFile { try await search.activateFavorite(id, openFile: true, favorites: favorites) }
                else { try await search.execute(.favorite(id), settings: model, favorites: favorites) }
            }
            try await gate.waitUntilStarted()
            search.close()
            gate.finish()
            try await hiddenSuccess.value
            try check(search.panel == nil, "a hidden favorite success reopened search")
            search.show(settings: model, favorites: favorites)
            guard let completedHidden = search.panel else { throw Failure(message: "completed hidden search did not reopen") }
            let completedHiddenField = try await searchField(in: completedHidden)
            try check(completedHiddenField.stringValue.isEmpty, "hidden successful activation retained its completed search")

            // Capture in the initiating UI event, then defer the operation until
            // after another search exists. Capturing only inside the async method
            // would wrongly attribute this old action to the replacement panel.
            let queuedContext = search.captureOperation()
            search.close()
            search.show(settings: model, favorites: favorites)
            guard let queuedReplacement = search.panel else { throw Failure(message: "delayed-start replacement search missing") }
            let queuedField = try await searchField(in: queuedReplacement)
            try postKeys([("d", 2)], to: queuedReplacement)
            try await waitForText("d", in: queuedField)
            let delayedOperation = Task {
                if openFile {
                    try await search.activateFavorite(id, openFile: true, favorites: favorites, context: queuedContext)
                } else {
                    try await search.execute(.favorite(id), settings: model, favorites: favorites, context: queuedContext)
                }
            }
            try await gate.waitUntilStarted()
            gate.finish()
            try await delayedOperation.value
            try check(search.panel === queuedReplacement && queuedReplacement.isVisible && queuedField.stringValue == "d",
                      "an operation queued by an old UI event closed or changed the replacement search")
            search.close()
            search.show(settings: model, favorites: favorites)
            guard let queuedRestored = search.panel else { throw Failure(message: "delayed-start replacement did not restore") }
            let queuedRestoredField = try await searchField(in: queuedRestored)
            try check(queuedRestoredField.stringValue == "d", "an operation queued by an old UI event cleared the replacement search in memory")

            let beforeRefocus = search.captureOperation()
            search.show(settings: model, favorites: favorites)
            try check(search.panel === queuedRestored, "refocusing created another panel")
            _ = try await searchField(in: queuedRestored)
            try postKeys([("r", 15)], to: queuedRestored)
            try await waitForText("r", in: queuedRestoredField)
            let refocusedOperation = Task {
                try await search.activateFavorite(id, openFile: openFile, favorites: favorites, context: beforeRefocus)
            }
            try await gate.waitUntilStarted()
            gate.finish()
            try await refocusedOperation.value
            try check(search.panel === queuedRestored && queuedRestoredField.stringValue == "r",
                      "an old operation claimed a newly invoked search that reused its native window")
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

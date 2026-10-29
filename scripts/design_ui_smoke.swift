import AppKit
import SwiftUI
import ImageIO
import CoreGraphics
import CoreText
import FileMintCore

/// Runs production views/models/coordinators with an isolated store. It does not
/// run the app delegate, register login items, start update checks or install Finder.
@main
@MainActor
final class DesignUISmoke: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var model: PreferencesModel!
    private var coordinator: FileOperationCoordinator!
    private var resourceController: ResourceToolsController!
    private var updater: UpdateModel!
    private var updateBody: String?
    private var quickSearch: QuickSearchPanelController?

    static func main() {
        let app = NSApplication.shared
        let delegate = DesignUISmoke()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do { try prepare() }
        catch { print("FAIL isolated UI setup: \(error)"); exit(1) }
    }

    private func prepare() throws {
        guard let path = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String else { throw ResourceError.failed }
        let root = URL(fileURLWithPath: path, isDirectory: true)
        for i in 0..<2 { try fixture(root.appendingPathComponent(i == 0 ? "Mountain.png" : "Lake.png"), variant: i) }
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.language = CommandLine.arguments.contains("--english") ? .english : .chinese
        if CommandLine.arguments.contains("--dark") { preferences.appearance = .dark }
        if CommandLine.arguments.contains("--light") { preferences.appearance = .light }
        preferences.fileTools.isEnabled = true
        // Finder remains off; explicit main-app selection must still work.
        preferences.resourceTools.isEnabled = false
        preferences.launchAtLogin = false
        preferences.automaticallyChecksForUpdates = false
        preferences.revealAfterCreation = false
        if CommandLine.arguments.contains("--templates") {
            for (id, name, filename, content) in [("meeting", "会议纪要", "会议.md", "# 会议\n"),
                                                  ("weekly", "工作周报", "周报.md", "# 周报\n")] {
                preferences.templates.append(try TemplateCatalog.customTemplate(name: name, fileExtension: "md", content: content,
                    id: id, in: preferences.templates, suggestedFileName: filename))
            }
        }
        if CommandLine.arguments.contains("--long-templates") {
            for number in 1...160 {
                preferences.templates.append(FileTemplate(id: "scroll-\(number)", displayName: "Scroll template \(number)",
                    suggestedFileName: "Example-\(number).txt", group: "QA", content: "Fixture \(number)", rank: 1000 + number))
            }
        }
        let file = root.appendingPathComponent("fixture-preferences.json")
        let favoriteFile = root.appendingPathComponent("fixture-favorites.json")
        let favoriteStore = FavoriteLocationsStore(file: favoriteFile)
        let example = try FileMoveItem.capture(root.appendingPathComponent("Mountain.png"))
        let lake = try FileMoveItem.capture(root.appendingPathComponent("Lake.png"))
        var favoritesCatalog = FavoriteLocationsCatalog()
        _ = try favoritesCatalog.add([
            FavoriteLocation(url: example.source,
                bookmark: try example.source.bookmarkData(options: .withSecurityScope,
                    includingResourceValuesForKeys: nil, relativeTo: nil),
                // Simulate a saved favorite from before the volume was remounted.
                device: example.device + 37, inode: example.inode, createdAt: example.createdAt,
                kind: .file, name: "Mountain.png", group: "设计", isPinned: true),
            FavoriteLocation(url: lake.source,
                bookmark: try lake.source.bookmarkData(options: .withSecurityScope,
                    includingResourceValuesForKeys: nil, relativeTo: nil), device: lake.device,
                inode: lake.inode, kind: .file, name: "Lake.png", group: "工作"),
            FavoriteLocation(url: root.appendingPathComponent("Missing.pdf"), bookmark: Data([7, 8, 9]),
                device: example.device, inode: UInt64.max - 1, kind: .file, name: "Missing.pdf", group: "资料")
        ])
        try favoriteStore.save(favoritesCatalog)
        let favoriteModel = FavoriteLocationsModel(store: favoriteStore)
        let store = FileMintPreferencesStore(fileURL: file)
        if CommandLine.arguments.contains("--resume-fixture") { preferences = store.load() }
        else { try store.save(preferences) }
        model = PreferencesModel(store: store, documentTemplates: DocumentTemplateStore(directory: root.appendingPathComponent("template-assets")))
        model.selectedPane = CommandLine.arguments.contains("--open-with") ? .openWith : .resourceTools
        if CommandLine.arguments.contains("--templates") { model.selectedPane = .fileTypes }
        if CommandLine.arguments.contains("--general") { model.selectedPane = .general }
        if CommandLine.arguments.contains("--favorites") { model.selectedPane = .favoriteLocations }
        resourceController = ResourceToolsController(preferencesFile: file)
        coordinator = FileOperationCoordinator(store: PendingFileMoveStore(file: root.appendingPathComponent("pending.json")),
            tickets: FileOperationTicketStore(directory: root.appendingPathComponent("tickets")), preferencesFile: file,
            aliasAccessStore: DesktopAliasAccessStore(file: root.appendingPathComponent("aliases.json")),
            desktopDirectory: root, resourceController: resourceController)
        if let icon = NSImage(contentsOf: root.appendingPathComponent("AppIcon.png")) { NSApp.applicationIconImage = icon }
        if CommandLine.arguments.contains("--verify-updates") || CommandLine.arguments.contains("--updates") {
            guard let notesURL = Bundle.main.url(forResource: "UpdateReleaseNotes", withExtension: "md") else {
                throw ResourceError.failed
            }
            updateBody = try String(contentsOf: notesURL, encoding: .utf8)
            updater = UpdateModel(preferencesModel: model, checkRelease: { [weak self] current in
                try Self.updateFixture(body: self?.updateBody, current: current)
            })
            model.selectedPane = .about
        } else {
            updater = UpdateModel(preferencesModel: model, checkRelease: { _ in nil })
        }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "FileMint Design QA"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = FileMintStyle.backgroundNS
        window.contentMinSize = NSSize(width: 960, height: 680)
        window.isReleasedWhenClosed = false
        let coordinator = coordinator!
        let quickSearch = QuickSearchPanelController { [weak self] pane in
            self?.model.selectedPane = pane
            self?.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        self.quickSearch = quickSearch
        let hostingView = NSHostingView(rootView: ContentView(launchResourceTool: { coordinator.chooseImages(for: $0) },
            favoriteLocations: favoriteModel, quickSearch: quickSearch)
            .environmentObject(model).environmentObject(updater))
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        if CommandLine.arguments.contains("--minimum") { minimum() }
        let bar = NSMenu()
        let app = NSMenuItem()
        let actions = NSMenu()
        for (title, selector) in [("中文 / English", #selector(language)), ("Light / Dark", #selector(appearance)),
                                  ("Follow System", #selector(systemAppearance)),
                                  ("Minimum size", #selector(minimum)), ("Creation panel", #selector(creation)),
                                  ("Clipboard image fixture", #selector(clipboardImage)),
                                  ("Clipboard text fixture", #selector(clipboardText)),
                                  ("Quit fixture", #selector(quit))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            actions.addItem(item)
        }
        app.submenu = actions
        bar.addItem(app)
        NSApp.mainMenu = bar
        NSApp.activate(ignoringOtherApps: true)
        print("READY isolated FileMint UI: \(root.path)")
        if CommandLine.arguments.contains("--verify-creation-layout") {
            Task { @MainActor in
                do {
                    try await checkCreationLayout(root: root)
                    print("PASS creation panel layout: compact image/text/document forms and live action controls")
                    fflush(nil)
                    NSApp.terminate(nil)
                } catch {
                    print("FAIL creation panel layout: \(error)")
                    fflush(nil)
                    exit(1)
                }
            }
            return
        }
        if CommandLine.arguments.contains("--verify-settings-navigation") {
            Task { @MainActor in
                do {
                    try await waitForSettingsReady()
                    try await checkSettingsNavigation()
                    print("PASS settings navigation: rapid native key bursts, selection and visible-row scroll stability")
                    fflush(nil)
                    NSApp.terminate(nil)
                } catch {
                    print("FAIL settings navigation: \(error)")
                    fflush(nil)
                    exit(1)
                }
            }
            return
        }
        if CommandLine.arguments.contains("--verify-updates") {
            Task { @MainActor in
                do {
                    try await waitForSettingsReady()
                    try await checkUpdateSummaries(root: root)
                    print("PASS update summary QA: localized production views, missing-notes fallback, install availability and minimum-size captures")
                    fflush(nil)
                    NSApp.terminate(nil)
                } catch {
                    print("FAIL update summary QA: \(error)")
                    fflush(nil)
                    exit(1)
                }
            }
            return
        }
        if CommandLine.arguments.contains("--verify-creation-entry") {
            Task { @MainActor in
                do {
                    try await waitForSettingsReady()
                    try await checkCreationEntry(store: store, root: root)
                    print("PASS creation entry: direct drafts, template selection, clipboard preservation, Create-only writes and unchanged folder preferences")
                    fflush(nil)
                    NSApp.terminate(nil)
                } catch {
                    print("FAIL creation entry: \(error)"); fflush(nil); exit(1)
                }
            }
            return
        }
        if CommandLine.arguments.contains("--updates") { updater.checkForUpdates() }
        if CommandLine.arguments.contains("--verify-automation") {
            Task { @MainActor in
                do {
                    try await waitForSettingsReady()
                    print("CHECK automated settings navigation"); fflush(nil)
                    try await checkSettingsNavigation()
                    print("CHECK automated design appearance"); fflush(nil)
                    try await checkCreationEntry(store: store, root: root)
                    try await checkCreationLayout(root: root)
                    try checkAppearance(store: store, root: root)
                    print("CHECK automated design settings"); fflush(nil)
                    try await checkSettings(store: store, root: root)
                    print("CHECK automated design window size"); fflush(nil)
                    try await checkWindowSize()
                    print("PASS automated design QA: appearance, settings edits/rollback, native captures and window size")
                    fflush(nil)
                    NSApp.terminate(nil)
                } catch {
                    print("FAIL automated design QA: \(error)")
                    fflush(nil)
                    exit(1)
                }
            }
            return
        }
        if CommandLine.arguments.contains("--check-settings") {
            Task { @MainActor in
                do {
                    try await checkSettings(store: store, root: root)
                    print("PASS settings review: production edits, copy/reset/delete, rollback and 18 native view captures")
                    fflush(nil)
                } catch { print("FAIL settings review: \(error)"); fflush(nil); exit(1) }
            }
        }
        if CommandLine.arguments.contains("--check-appearance") { try checkAppearance(store: store, root: root) }
        if CommandLine.arguments.contains("--check-window-size") {
            Task { @MainActor in
                do {
                    try await checkWindowSize()
                    print("PASS window size: 960x680 survives language and appearance changes")
                    exit(0)
                } catch {
                    print("FAIL window size: \(error)")
                    exit(1)
                }
            }
        }
        if CommandLine.arguments.contains("--clipboard-image") {
            clipboardImage()
        }
        if CommandLine.arguments.contains("--clipboard-text") {
            clipboardText()
        }
        if CommandLine.arguments.contains("--document-preview"),
           let template = model.preferences.templates.first(where: { $0.document != nil }) {
            CustomFileSavePanelController.shared.present(in: root, preferences: model.preferences,
                templateID: template.id, documentTemplates: model.documentTemplates)
        }
    }

    private func checkCreationEntry(store: FileMintPreferencesStore, root: URL) async throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "CreationEntry", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
        func draftWindow() throws -> NSWindow {
            guard let panel = NSApp.windows.first(where: {
                $0.isVisible && $0.identifier?.rawValue == "io.github.daigua.filemint.custom-file"
            }) else { throw ResourceError.failed }
            return panel
        }
        // A regression into runModal must fail, rather than leave an unattended picker.
        let watchdog = Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled {
                print("FAIL creation entry: operation stalled or opened a preliminary folder picker")
                fflush(nil); exit(1)
            }
        }
        defer { watchdog.cancel() }
        let before = try Data(contentsOf: root.appendingPathComponent("fixture-preferences.json"))
        let initialFiles = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        model.newFile()
        var panel = try draftWindow()
        try require(panel.attachedSheet == nil && NSApp.modalWindow == nil, "New File opened a picker")
        panel.performClose(nil)
        guard let template = model.committedPreferences.templates.first(where: { $0.id == "markdown" && $0.isEnabled }) else {
            throw ResourceError.failed
        }
        model.newFile(templateID: template.id)
        panel = try draftWindow()
        try require(views(panel.contentView!).compactMap { $0 as? NSTextField }
            .contains { $0.isEditable && $0.stringValue == template.suggestedFileName }, "Requested template was not preselected")
        panel.performClose(nil)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let content = "  clipboard draft 🪴\r\n{{fileName}}  "
        board.setString(content, forType: .string)
        model.presentClipboardText(in: nil, pasteboard: board)
        panel = try draftWindow()
        let controls = views(panel.contentView!)
        guard let editor = controls.compactMap({ $0 as? NSTextView }).first(where: { $0.string == content }),
              let name = controls.compactMap({ $0 as? NSTextField }).first(where: { $0.isEditable && !($0 is NSComboBox) }),
              let create = controls.compactMap({ $0 as? NSButton }).first(where: { $0.action == NSSelectorFromString("createRequestedFile:") }) else {
            throw ResourceError.failed
        }
        board.clearContents()
        model.presentClipboardText(in: nil, pasteboard: board)
        model.newFile(templateID: template.id)
        try require(editor.string == content && (try draftWindow()) === panel, "Repeated creation replaced the active draft")
        try require(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == initialFiles,
                    "Opening or cancelling a draft wrote a file")
        name.stringValue = "creation-entry-result.txt"
        create.performClick(nil)
        for _ in 0..<100 where CustomFileSavePanelController.shared.hasActiveDraft {
            try await Task.sleep(for: .milliseconds(30))
        }
        try require(!CustomFileSavePanelController.shared.hasActiveDraft, "Create did not finish")
        try require(try Data(contentsOf: root.appendingPathComponent("creation-entry-result.txt")) == Data(content.utf8),
                    "Create did not preserve exact clipboard bytes")
        try require(try Data(contentsOf: root.appendingPathComponent("fixture-preferences.json")) == before,
                    "Opening a draft changed saved folders or authorization")
        try require(store.load().monitoredFolderURLs == [root], "Creation changed Finder scope")
    }

    private static func updateFixture(body: String?, current: String) throws -> AppUpdate? {
        let base = "https://github.com/FileMintApp/FileMint/releases"
        let name = "FileMint-9.9.9.dmg"
        var release: [String: Any] = [
            "tag_name": "v9.9.9", "html_url": "\(base)/tag/v9.9.9", "draft": false, "prerelease": false,
            "assets": [
                ["name": name, "browser_download_url": "\(base)/download/v9.9.9/\(name)",
                 "size": 512, "state": "uploaded"],
                ["name": "\(name).sha256", "browser_download_url": "\(base)/download/v9.9.9/\(name).sha256",
                 "size": 85, "state": "uploaded"]
            ]
        ]
        if let body { release["body"] = body }
        return try AppUpdatePolicy.availableUpdate(from: JSONSerialization.data(withJSONObject: release),
                                                  currentVersion: current)
    }

    private func checkCreationLayout(root: URL) async throws {
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "CreationLayout", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }
        let output = root.appendingPathComponent("creation-layout", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let png = try Data(contentsOf: root.appendingPathComponent("Mountain.png"))
        let controller = CustomFileSavePanelController.shared
        for language in [AppLanguage.chinese, .english] {
            for kind in ["image", "text", "document"] {
                var preferences = model.preferences
                preferences.language = language
                preferences.creationOpeningEnabled = false
                let document = preferences.templates.first { $0.document != nil }
                try require(document != nil, "Missing Office template fixture")
                controller.present(in: root, preferences: preferences,
                    templateID: kind == "document" ? document?.id : nil,
                    imageData: kind == "image" ? png : nil,
                    imagePreview: kind == "image" ? NSImage(data: png) : nil,
                    documentTemplates: model.documentTemplates)
                guard let panel = NSApp.windows.first(where: {
                    $0.isVisible && $0.identifier?.rawValue == "io.github.daigua.filemint.custom-file"
                }), let content = panel.contentView else { throw ResourceError.failed }
                defer { panel.close() }
                var closedHeight: CGFloat?
                for opening in [false, true, false] {
                    preferences.creationOpeningEnabled = opening
                    controller.updateFeatures(preferences)
                    try await Task.sleep(for: .milliseconds(50))
                    content.layoutSubtreeIfNeeded()
                    let views = descendants(content)
                    guard let cancel = views.compactMap({ $0 as? NSButton }).first(where: {
                        $0.title == FileMintStrings.text(.cancel, language: language)
                    }), let footer = cancel.superview?.superview else { throw ResourceError.failed }
                    let footerRect = footer.convert(footer.bounds, to: content)
                    try require((18...28).contains(footerRect.minY),
                                "\(language)/\(kind)/opening=\(opening): excessive footer gap \(footerRect.minY)")
                    try require(abs(content.bounds.width - 560) < 1,
                                "Creation width changed while fitting visible content")
                    for control in views where !control.isHiddenOrHasHiddenAncestor &&
                        (control is NSControl || control is NSScrollView) {
                        let rect = control.convert(control.bounds, to: content)
                        try require(rect.minY >= -1 && rect.maxY <= content.bounds.height + 1,
                                    "\(kind): visible control clipped after sizing")
                    }
                    if opening, let closedHeight {
                        try require(content.bounds.height > closedHeight,
                                    "Action controls did not receive additional height")
                    } else if let closedHeight {
                        try require(abs(content.bounds.height - closedHeight) < 1,
                                    "Closing action controls left reserved space")
                    } else { closedHeight = content.bounds.height }
                    print("LAYOUT \(language)/\(kind) opening=\(opening) height=\(content.bounds.height) footerGap=\(footerRect.minY)")
                }
                guard let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { throw ResourceError.failed }
                panel.display(); content.cacheDisplay(in: content.bounds, to: bitmap)
                guard let capture = bitmap.representation(using: .png, properties: [:]) else { throw ResourceError.failed }
                try capture.write(to: output.appendingPathComponent("\(language.rawValue)-\(kind).png"))
            }
        }
        print("CREATION_LAYOUT_CAPTURES \(output.path)")
    }

    private func checkUpdateSummaries(root: URL) async throws {
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "UpdateSummaryReview", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let output = root.appendingPathComponent("update-summary-review", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        let notes = updateBody
        let visibleWindows = NSApp.windows.filter(\.isVisible).count
        for (name, body) in [("summary", notes), ("legacy", nil)] {
            updateBody = body
            updater.checkForUpdates()
            for _ in 0..<100 where updater.isBusy { try await Task.sleep(for: .milliseconds(30)) }
            try require(updater.state == .available && updater.canDownload && !updater.isInstalling,
                        "Notes must not prevent an available update or start installation")
            try require(NSApp.windows.filter(\.isVisible).count == visibleWindows,
                        "An update result must not create a new window")
            for (language, appearance) in [(AppLanguage.chinese, AppAppearance.light), (.english, .dark)] {
                model.preferences.language = language
                model.setAppearance(appearance)
                let summary = updater.update?.releaseNotes?.summary(for: language)
                if body != nil {
                    let expected = language == .chinese ? "批量整理文件名，核对文件内容。" :
                        "Organize file names and compare file contents."
                    try require(summary?.headline == expected && summary?.highlights.count == 2,
                                "Changing language must select the matching summary")
                } else {
                    try require(summary == nil, "Missing notes must use the unavailable-summary state")
                }
                for pane in [PreferencesModel.Pane.about, .general] {
                    model.selectedPane = pane
                    window.setContentSize(NSSize(width: 960, height: 680))
                    try await Task.sleep(for: .milliseconds(250))
                    guard let view = window.contentView,
                          let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw ResourceError.failed }
                    view.layoutSubtreeIfNeeded(); window.display(); view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ResourceError.failed }
                    try png.write(to: output.appendingPathComponent("\(name)-\(language.rawValue)-\(pane.rawValue).png"))
                    try require(abs(view.bounds.width - 960) < 1 && abs(view.bounds.height - 680) < 1,
                                "Summary or help content must not grow the minimum-size window")
                }
            }
        }
        print("UPDATE_SUMMARY_CAPTURES \(output.path)")
    }

    @objc private func language() {
        model.preferences.language = model.preferences.language == .chinese ? .english : .chinese
        model.save()
        recordWindowSize("language")
    }
    @objc private func appearance() {
        model.setAppearance(NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .light : .dark)
        recordWindowSize("appearance")
    }
    @objc private func systemAppearance() { model.setAppearance(.system) }
    @objc private func minimum() {
        window.setContentSize(NSSize(width: 960, height: 680))
        recordWindowSize("minimum")
    }
    @objc private func creation() {
        if let folder = model.preferences.monitoredFolderURLs.first {
            CustomFileSavePanelController.shared.present(in: folder, preferences: model.preferences, documentTemplates: model.documentTemplates)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func recordWindowSize(_ event: String) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard let root = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String else { return }
            let size = window.contentRect(forFrameRect: window.frame).size
            try? "\(event) \(size.width) \(size.height)".write(
                toFile: URL(fileURLWithPath: root).appendingPathComponent("qa-window-size.txt").path,
                atomically: true, encoding: .utf8)
        }
    }

    private func checkSettingsNavigation() async throws {
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "SettingsNavigation", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }
        // SwiftUI accessibility elements implement the Objective-C getters but
        // do not all declare the full NSAccessibilityProtocol conformance.
        func attribute(_ node: NSObject, _ key: String) -> Any? {
            let getter = key == "accessibilitySelected" ? "isAccessibilitySelected" : key
            guard node.responds(to: NSSelectorFromString(getter)) else { return nil }
            return node.value(forKey: key)
        }
        func accessible(_ node: NSObject, depth: Int = 0) -> [NSObject] {
            guard depth < 30 else { return [] }
            return [node] + (attribute(node, "accessibilityChildren") as? [NSObject] ?? [])
                .flatMap { accessible($0, depth: depth + 1) }
        }
        func post(_ codes: [UInt16]) throws {
            for code in codes {
                let characters = code == 125 ? "\u{F701}" : "\u{F700}"
                guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, characters: characters, charactersIgnoringModifiers: characters,
                    isARepeat: true, keyCode: code) else { throw ResourceError.failed }
                NSApp.postEvent(event, atStart: false)
            }
        }
        window.setContentSize(NSSize(width: 1040, height: 900))
        model.selectedPane = .fileTypes
        try await Task.sleep(for: .milliseconds(150))
        guard let content = window.contentView else {
            throw NSError(domain: "SettingsNavigation", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Settings content view is missing"])
        }
        let nodes = accessible(content)
        guard let first = nodes.first(where: { attribute($0, "accessibilityIdentifier") as? String == "settings.fileTypes" }) else {
            let identifiers = nodes.map { "\(type(of: $0)):\(attribute($0, "accessibilityIdentifier") as? String ?? "nil")" }
            throw NSError(domain: "SettingsNavigation", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "First settings accessibility row is missing: \(identifiers)"])
        }
        let scrollViews = descendants(content).compactMap { $0 as? NSScrollView }
        guard let sidebar = scrollViews.first(where: {
            $0.convert($0.bounds, to: content).maxX <= 203
        }) else {
            let frames = scrollViews.map { "\(type(of: $0)):\($0.convert($0.bounds, to: content))" }
            throw NSError(domain: "SettingsNavigation", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Sidebar scroll view is missing: \(frames)"])
        }
        guard let firstFrame = (attribute(first, "accessibilityFrame") as? NSValue)?.rectValue else {
            throw NSError(domain: "SettingsNavigation", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "First settings row has no accessibility frame"])
        }
        let point = window.convertPoint(fromScreen: NSPoint(x: firstFrame.midX, y: firstFrame.midY))
        for kind in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1) else { throw ResourceError.failed }
            NSApp.sendEvent(event)
        }
        try await Task.sleep(for: .milliseconds(50))
        let origin = sidebar.contentView.bounds.origin
        // Queue each whole burst before yielding: focus-based navigation used to
        // calculate several successive events from the same previous frame.
        for _ in 0..<3 {
            try post([125, 125, 125, 125, 126, 126])
            try await Task.sleep(for: .milliseconds(150))
            try require(model.selectedPane == .fileTools, "Rapid arrows lost or repeated a page transition")
            try require(sidebar.contentView.bounds.origin == origin,
                        "Arrow navigation scrolled rows that were already visible")
            try post([126, 126, 126])
            try await Task.sleep(for: .milliseconds(100))
            try require(model.selectedPane == .fileTypes, "Up navigation did not clamp to the first page")
        }
        window.setContentSize(NSSize(width: 960, height: 680))
        try await Task.sleep(for: .milliseconds(100))
        try post(Array(repeating: 125, count: 12))
        try await Task.sleep(for: .milliseconds(150))
        try require(model.selectedPane == .about, "Down navigation did not reach the last page at minimum size")
        try require(sidebar.contentView.bounds.origin.y > 0, "Offscreen settings row was not revealed")
        let last = accessible(content).first { attribute($0, "accessibilityIdentifier") as? String == "settings.about" }
        try require(last.flatMap { attribute($0, "accessibilitySelected") as? Bool } == true,
                    "Visible selected appearance/accessibility state lagged behind navigation")
    }

    private func checkWindowSize() async throws {
        window.setContentSize(NSSize(width: 960, height: 680))
        try await assertWindowSize()
        model.preferences.language = .english
        guard model.save() else { throw ResourceError.failed }
        try await assertWindowSize()
        model.setAppearance(.dark)
        try await assertWindowSize()
    }

    private func assertWindowSize() async throws {
        try await Task.sleep(for: .milliseconds(300))
        let size = window.contentRect(forFrameRect: window.frame).size
        guard abs(size.width - 960) < 1, abs(size.height - 680) < 1 else {
            throw ResourceError.failed
        }
    }

    private func waitForSettingsReady() async throws {
        for _ in 0..<100 where model.isMutatingTemplates || model.templateRecoveryError != nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        guard model.templateMutationAllowed else {
            throw NSError(domain: "SettingsReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Template recovery did not finish"])
        }
    }

    private func checkSettings(store: FileMintPreferencesStore, root: URL) async throws {
        try await checkPreferenceFailureRollback(root: root)
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "SettingsReview", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        try await waitForSettingsReady()
        let original = model.preferences
        let templates = [model.preferences.templates.first { $0.document == nil }!,
                         model.preferences.templates.first { $0.document != nil }!]
        for template in templates {
            let index = model.preferences.templates.firstIndex { $0.id == template.id }!
            model.preferences.templates[index].isEnabled = false
            try require(model.save(), "Disable fixture template")
            try await model.saveType(name: template.displayName, suffix: template.fileExtension, content: template.content,
                id: template.id, suggestedFileName: template.suggestedFileName, customMenuIcon: template.customMenuIcon,
                menuPlacement: .main)
            try require(store.load().templateMenuPlacement(for: template.id) == .main &&
                store.load().templates.first { $0.id == template.id }?.isEnabled == false,
                "Editor changed enablement or lost placement")
            model.templatePlacementBinding(for: template.id).wrappedValue = .hidden
            try require(store.load().templateMenuPlacement(for: template.id) == .hidden, "Row/editor persistence differs")
        }
        let copy = TemplateCatalog.copyDraft(templates[0], copySuffix: "QA copy")
        try await model.saveType(name: copy.displayName, suffix: copy.fileExtension, content: copy.content,
            id: nil, customMenuIcon: copy.customMenuIcon, copy: copy, sourceID: templates[0].id)
        try require(store.load().templateMenuPlacement(for: copy.id) == .hidden, "Copy lost placement")
        model.resetTemplates()
        for _ in 0..<100 where model.isMutatingTemplates { try await Task.sleep(for: .milliseconds(50)) }
        try require(templates.allSatisfy { store.load().templateMenuPlacement(for: $0.id) == .submenu } &&
            store.load().templateMenuPlacement(for: copy.id) == .hidden, "Restoration changed custom placement")
        model.removeType(copy.id)
        for _ in 0..<100 where model.isMutatingTemplates { try await Task.sleep(for: .milliseconds(50)) }
        try require(store.load().templateMenuPlacements[copy.id] == nil, "Delete left orphan placement")
        let beforeBusy = model.preferences
        model.isMutatingTemplates = true
        model.templatePlacementBinding(for: templates[0].id).wrappedValue = .main
        model.preferenceBinding(\.resourceTools.isEnabled).wrappedValue.toggle()
        model.isMutatingTemplates = false
        try require(model.preferences == beforeBusy, "Busy edit was committed")
        let blocked = root.appendingPathComponent("blocked-settings-" + UUID().uuidString)
        try Data().write(to: blocked)
        let failed = PreferencesModel(store: FileMintPreferencesStore(fileURL: blocked.appendingPathComponent("settings.json")),
                                      documentTemplates: model.documentTemplates)
        let failedBefore = failed.preferences
        failed.preferenceBinding(\.fileTools.isEnabled).wrappedValue.toggle()
        failed.preferenceBinding(\.resourceTools.isEnabled).wrappedValue.toggle()
        failed.preferenceBinding(\.favoriteLocations.showListInFinder).wrappedValue.toggle()
        failed.templatePlacementBinding(for: templates[0].id).wrappedValue = .hidden
        try require(failed.preferences == failedBefore && failed.lastError != nil, "Failed controls did not roll back")
        model.preferences = original
        try require(model.save(), "Restore isolated preferences")
        let output = root.appendingPathComponent("settings-review", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        for (language, appearance, width, height) in [(AppLanguage.chinese, AppAppearance.light, 1040.0, 720.0),
                                                     (.english, .dark, 960.0, 680.0)] {
            model.preferences.language = language
            try require(model.save(), "Save fixture language")
            model.setAppearance(appearance)
            window.setContentSize(NSSize(width: width, height: height))
            for pane in PreferencesModel.Pane.allCases {
                model.selectedPane = pane
                try await Task.sleep(for: .milliseconds(250))
                guard let view = window.contentView,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw ResourceError.failed }
                view.layoutSubtreeIfNeeded(); window.display(); view.cacheDisplay(in: view.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ResourceError.failed }
                try png.write(to: output.appendingPathComponent("\(language.rawValue)-\(pane.rawValue).png"))
                try require(abs(view.bounds.width - width) < 1 && abs(view.bounds.height - height) < 1, "Window grew beyond requested size")
            }
        }
        model.selectedPane = .fileTypes
        print("SETTINGS_REVIEW_CAPTURES \(output.path)")
    }

    private func checkPreferenceFailureRollback(root: URL) async throws {
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "SettingsRollback", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let directory = root.appendingPathComponent("settings-rollback-" + UUID().uuidString, isDirectory: true)
        let retained = directory.appendingPathComponent("retained", isDirectory: true)
        let added = directory.appendingPathComponent("added", isDirectory: true)
        let second = directory.appendingPathComponent("second", isDirectory: true)
        for folder in [retained, added, second] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let store = FileMintPreferencesStore(fileURL: directory.appendingPathComponent("preferences.json"))
        var initial = FileMintPreferences.default
        initial.monitoredFolderURLs = [retained]
        initial.launchAtLogin = false
        initial.automaticallyChecksForUpdates = true
        try FolderAccess.remember(retained, in: &initial)
        try store.save(initial)
        let settings = PreferencesModel(store: store,
            documentTemplates: DocumentTemplateStore(directory: directory.appendingPathComponent("assets")))
        for _ in 0..<100 where settings.templateRecoveryError != nil || settings.isMutatingTemplates {
            try await Task.sleep(for: .milliseconds(20))
        }
        try require(settings.templateRecoveryError == nil && !settings.isMutatingTemplates,
                    "Rollback fixture did not finish startup recovery")
        try require(settings.rememberMonitoredFolders([added, second]), "Folder additions did not save")
        try require(store.load() == settings.preferences && settings.preferences.monitoredFolderURLs == [retained, added, second],
                    "Successful folder additions lost the complete selection")
        settings.removeFolder(added)
        settings.removeFolder(second)
        try require(store.load() == settings.preferences && settings.preferences.monitoredFolderURLs == [retained],
                    "Successful folder removal did not persist")

        var started = false
        var cancelled = false
        let automatic = UpdateModel(preferencesModel: settings, automaticCheckStartupDelay: 0.01) { _ in
            started = true
            do { try await Task.sleep(for: .seconds(30)) }
            catch { cancelled = true; throw error }
            return nil
        }
        automatic.startAutomaticChecks()
        defer { automatic.cancel() }
        for _ in 0..<100 where !started { try await Task.sleep(for: .milliseconds(20)) }
        try require(started && automatic.state == .checking, "Automatic rollback fixture did not start")
        let previous = settings.preferences
        // Simulate a settings file becoming damaged while the app is running.
        // The production store rejects every mutation without replacing bytes.
        let damaged = Data("{damaged".utf8)
        try damaged.write(to: store.location!)
        settings.removeFolder(retained)
        try require(settings.preferences == previous && settings.committedPreferences == previous,
                    "Failed folder removal changed settings or saved authority")
        try require(!settings.rememberMonitoredFolders([added, second]) && settings.preferences == previous,
                    "Failed folder additions retained a partial or unsaved selection")
        settings.setShowMenuBar(!previous.showMenuBar)
        settings.setAutomaticallyChecksForUpdates(false)
        try require(settings.preferences == previous, "Failed startup choices did not roll back")
        try await Task.sleep(for: .milliseconds(100))
        try require(automatic.state == .checking && !cancelled,
                    "A rejected automatic-update choice cancelled the active check")
        try require(settings.lastError != nil && (try Data(contentsOf: store.location!)) == damaged,
                    "Failed preference saves hid the error or changed damaged bytes")
        print("PASS settings rollback: complete folder edits, menu bar, update choice and active-check preservation")
    }

    private func checkAppearance(store: FileMintPreferencesStore, root: URL) throws {
        let original = model.preferences
        for choice in [AppAppearance.dark, .light, .system] {
            print("CHECK appearance \(choice.rawValue)"); fflush(nil)
            model.setAppearance(choice)
            guard store.load().appearance == choice else { throw ResourceError.failed }
            if choice == .system {
                guard NSApp.appearance == nil else { throw ResourceError.failed }
            } else {
                let expected: NSAppearance.Name = choice == .dark ? .darkAqua : .aqua
                guard window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expected else { throw ResourceError.failed }
            }
        }
        // Loading a stored choice must take effect before any new window is shown.
        model.setAppearance(.dark)
        NSApp.appearance = nil
        let reloaded = PreferencesModel(store: store, documentTemplates: model.documentTemplates)
        guard reloaded.preferences.appearance == .dark, NSApp.appearance?.name == .darkAqua else { throw ResourceError.failed }
        // A failed save restores the visible choice as well as the model value.
        let blocked = root.appendingPathComponent("not-a-directory")
        try Data().write(to: blocked)
        let failed = PreferencesModel(store: FileMintPreferencesStore(fileURL: blocked.appendingPathComponent("preferences.json")),
                                      documentTemplates: model.documentTemplates)
        failed.setAppearance(.dark)
        guard failed.preferences.appearance == .system, failed.lastError != nil, NSApp.appearance == nil else { throw ResourceError.failed }
        model.preferences = original
        // The temporary model above changed the process override; restore via the
        // production setter even when the original fixture was already dark.
        model.setAppearance(original.appearance == .light ? .dark : .light)
        model.setAppearance(original.appearance)
        print("PASS appearance: immediate window update, system reset, persistence, reload and failed-save rollback")
    }
    @objc private func clipboardImage() {
        guard let root = model.preferences.monitoredFolderURLs.first,
              let data = try? Data(contentsOf: root.appendingPathComponent("Mountain.png")) else { return }
        let clipboard = NSPasteboard(name: NSPasteboard.Name("FileMint-QA-\(UUID())"))
        clipboard.setData(data, forType: .png)
        Task {
            await model.presentClipboardImage(in: root, pasteboard: clipboard)
            clipboard.releaseGlobally()
            print("READY clipboard image draft using isolated pasteboard")
        }
    }

    @objc private func clipboardText() {
        guard let root = model.preferences.monitoredFolderURLs.first else { return }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.clearContents()
        let expected = "  中文 🪴\r\n{{fileName}}  "
        guard board.setString(expected, forType: .string) else { return }
        model.presentClipboardText(in: root, pasteboard: board)
        board.clearContents()
        _ = board.setString("Changed after capture", forType: .string)
        print("READY clipboard text draft using isolated pasteboard: \(root.path)")
    }

    private func fixture(_ url: URL, variant: Int) throws {
        guard let context = CGContext(data: nil, width: 1600, height: 1000, bitsPerComponent: 8, bytesPerRow: 6400,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ResourceError.failed }
        context.setFillColor(CGColor(red: variant == 0 ? 0.87 : 0.82, green: 0.91, blue: 0.86, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1000))
        context.setFillColor(CGColor(red: 0.4, green: 0.55, blue: variant == 0 ? 0.47 : 0.61, alpha: 1))
        context.move(to: CGPoint(x: 0, y: 0)); context.addLine(to: CGPoint(x: 590, y: 850))
        context.addLine(to: CGPoint(x: 1200, y: 0)); context.closePath(); context.fillPath()
        context.setFillColor(CGColor(red: 0.24, green: 0.42, blue: 0.34, alpha: 1))
        context.move(to: CGPoint(x: 500, y: 0)); context.addLine(to: CGPoint(x: 1200, y: 560))
        context.addLine(to: CGPoint(x: 1600, y: 100)); context.addLine(to: CGPoint(x: 1600, y: 0)); context.closePath(); context.fillPath()
        let value = NSAttributedString(string: "FILEMINT 2026", attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 42, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.2, alpha: 1)])
        context.textPosition = CGPoint(x: 80, y: 900)
        CTLineDraw(CTLineCreateWithAttributedString(value), context)
        guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { throw ResourceError.failed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ResourceError.failed }
    }
}

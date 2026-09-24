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
        let file = root.appendingPathComponent("fixture-preferences.json")
        let favoriteFile = root.appendingPathComponent("fixture-favorites.json")
        let favoriteStore = FavoriteLocationsStore(file: favoriteFile)
        let example = try FileMoveItem.capture(root.appendingPathComponent("Mountain.png"))
        let lake = try FileMoveItem.capture(root.appendingPathComponent("Lake.png"))
        var favoritesCatalog = FavoriteLocationsCatalog()
        _ = try favoritesCatalog.add([
            FavoriteLocation(url: example.source,
                bookmark: try example.source.bookmarkData(options: .withSecurityScope,
                    includingResourceValuesForKeys: nil, relativeTo: nil), device: example.device,
                inode: example.inode, kind: .file, name: "Mountain.png", group: "设计", isPinned: true),
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
        let updater = UpdateModel()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "FileMint Design QA"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = FileMintStyle.backgroundNS
        window.contentMinSize = NSSize(width: 840, height: 600)
        window.isReleasedWhenClosed = false
        let coordinator = coordinator!
        window.contentView = NSHostingView(rootView: ContentView(launchResourceTool: { coordinator.chooseImages(for: $0) },
            favoriteLocations: favoriteModel)
            .environmentObject(model).environmentObject(updater))
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
        if CommandLine.arguments.contains("--check-appearance") { try checkAppearance(store: store, root: root) }
        if CommandLine.arguments.contains("--clipboard-image") {
            clipboardImage()
        }
        if CommandLine.arguments.contains("--document-preview"),
           let template = model.preferences.templates.first(where: { $0.document != nil }) {
            CustomFileSavePanelController.shared.present(in: root, preferences: model.preferences,
                templateID: template.id, documentTemplates: model.documentTemplates)
        }
    }

    @objc private func language() {
        model.preferences.language = model.preferences.language == .chinese ? .english : .chinese
        model.save()
    }
    @objc private func appearance() {
        model.setAppearance(NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .light : .dark)
    }
    @objc private func systemAppearance() { model.setAppearance(.system) }
    @objc private func minimum() { window.setContentSize(NSSize(width: 840, height: 600)) }
    @objc private func creation() {
        if let folder = model.preferences.monitoredFolderURLs.first {
            CustomFileSavePanelController.shared.present(in: folder, preferences: model.preferences, documentTemplates: model.documentTemplates)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func checkAppearance(store: FileMintPreferencesStore, root: URL) throws {
        let original = model.preferences
        for choice in [AppAppearance.dark, .light, .system] {
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

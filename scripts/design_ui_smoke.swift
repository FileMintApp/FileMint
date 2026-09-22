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
        preferences.language = .chinese
        preferences.fileTools.isEnabled = true
        // Finder remains off; explicit main-app selection must still work.
        preferences.resourceTools.isEnabled = false
        preferences.launchAtLogin = false
        preferences.automaticallyChecksForUpdates = false
        let file = root.appendingPathComponent("fixture-preferences.json")
        let store = FileMintPreferencesStore(fileURL: file)
        try store.save(preferences)
        model = PreferencesModel(store: store)
        model.selectedPane = CommandLine.arguments.contains("--open-with") ? .openWith : .resourceTools
        resourceController = ResourceToolsController(preferencesFile: file)
        coordinator = FileOperationCoordinator(store: PendingFileMoveStore(file: root.appendingPathComponent("pending.json")),
            tickets: FileOperationTicketStore(directory: root.appendingPathComponent("tickets")), preferencesFile: file,
            aliasAccessStore: DesktopAliasAccessStore(file: root.appendingPathComponent("aliases.json")),
            desktopDirectory: root, resourceController: resourceController)
        if let icon = NSImage(contentsOf: root.appendingPathComponent("AppIcon.png")) { NSApp.applicationIconImage = icon }
        NSApp.appearance = NSAppearance(named: .aqua)
        let updater = UpdateModel()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "FileMint Design QA"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentMinSize = NSSize(width: 840, height: 600)
        window.isReleasedWhenClosed = false
        let coordinator = coordinator!
        window.contentView = NSHostingView(rootView: ContentView(launchResourceTool: { coordinator.chooseImages(for: $0) })
            .environmentObject(model).environmentObject(updater))
        window.center()
        window.makeKeyAndOrderFront(nil)
        let bar = NSMenu()
        let app = NSMenuItem()
        let actions = NSMenu()
        for (title, selector) in [("中文 / English", #selector(language)), ("Light / Dark", #selector(appearance)),
                                  ("Minimum size", #selector(minimum)), ("Creation panel", #selector(creation)),
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
    }

    @objc private func language() {
        model.preferences.language = model.preferences.language == .chinese ? .english : .chinese
        model.save()
    }
    @objc private func appearance() {
        NSApp.appearance = NSAppearance(named: NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .aqua : .darkAqua)
    }
    @objc private func minimum() { window.setContentSize(NSSize(width: 840, height: 600)) }
    @objc private func creation() {
        if let folder = model.preferences.monitoredFolderURLs.first {
            CustomFileSavePanelController.shared.present(in: folder, preferences: model.preferences)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }

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

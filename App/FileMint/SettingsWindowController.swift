import AppKit
import SwiftUI

/// Settings is opened explicitly, so a URL launch never creates a primary window.
@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 490),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "FileMint"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentView = NSHostingView(rootView: ContentView()
            .environmentObject(PreferencesModel.shared).environmentObject(UpdateModel.shared))
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func show(pane: PreferencesModel.Pane? = nil) {
        if let pane { PreferencesModel.shared.selectedPane = pane }
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

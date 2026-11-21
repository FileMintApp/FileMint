import AppKit
import SwiftUI

/// Settings is opened explicitly, so a URL launch never creates a primary window.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private enum Metrics {
        static let preferred = NSSize(width: 1040, height: 720)
        static let minimum = NSSize(width: 960, height: 680)

        static func available(on screen: NSScreen?) -> NSSize {
            guard let screen else { return preferred }
            return NSSize(width: max(1, screen.visibleFrame.width - 24),
                          height: max(1, screen.visibleFrame.height - 48))
        }

        static func clamped(_ size: NSSize, to available: NSSize) -> NSSize {
            NSSize(width: min(size.width, available.width), height: min(size.height, available.height))
        }
    }

    private init() {
        let available = Metrics.available(on: NSScreen.main)
        let initial = Metrics.clamped(Metrics.preferred, to: available)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: initial),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "FileMint"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = FileMintStyle.backgroundNS
        window.contentMinSize = Metrics.clamped(Metrics.minimum, to: available)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        let hostingView = NSHostingView(rootView: ContentView()
            .environmentObject(PreferencesModel.shared).environmentObject(UpdateModel.shared).fileMintTheme())
        // The resizable window owns its size; SwiftUI content changes must not
        // expand it past the visible screen when language or appearance changes.
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func show(pane: PreferencesModel.Pane? = nil) {
        if let pane { PreferencesModel.shared.selectedPane = pane }
        refreshScreenConstraints()
        NSApp.setActivationPolicy(.regular)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func windowDidChangeScreen(_ notification: Notification) {
        refreshScreenConstraints()
    }

    private func refreshScreenConstraints() {
        guard let window else { return }
        let available = Metrics.available(on: window.screen ?? NSScreen.main)
        window.contentMinSize = Metrics.clamped(Metrics.minimum, to: available)
        let current = window.contentRect(forFrameRect: window.frame).size
        let clamped = Metrics.clamped(current, to: available)
        if current != clamped { window.setContentSize(clamped) }
    }
}

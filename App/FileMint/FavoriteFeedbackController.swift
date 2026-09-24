import AppKit
import SwiftUI

@MainActor
enum FavoriteFeedbackController {
    private static var panel: NSPanel?
    private static var generation = UUID()

    static func show(_ message: String) {
        panel?.close()
        let current = UUID()
        generation = current
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 72),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView:
            Label(message, systemImage: "star.fill")
                .font(.callout).foregroundStyle(FileMintStyle.strong)
                .padding(17).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line)))
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 340,
                                         y: screen.visibleFrame.maxY - 92))
        }
        self.panel = panel
        panel.orderFrontRegardless()
        Task {
            try? await Task.sleep(for: .seconds(3))
            guard generation == current else { return }
            panel.close()
            if self.panel === panel { self.panel = nil }
        }
    }
}

import AppKit
import SwiftUI

@MainActor
enum FavoriteFeedbackController {
    private static var panel: NSPanel?
    private static var generation = UUID()

    static func show(_ message: String, symbol: String = "star.fill") {
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
        let content = NSHostingView(rootView:
            Label(message, systemImage: symbol)
                .font(.callout).foregroundStyle(FileMintStyle.strong)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 366, alignment: .leading).padding(17)
                .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line)))
        panel.contentView = content
        panel.setContentSize(NSSize(width: 400, height: max(72, content.fittingSize.height)))
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - panel.frame.width - 20,
                                         y: screen.visibleFrame.maxY - panel.frame.height - 20))
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

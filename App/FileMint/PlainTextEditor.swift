import AppKit
import SwiftUI

struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    let label: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = FileMintTextView(frame: NSRect(x: 0, y: 0, width: 380, height: 120))
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.allowsUndo = true
        editor.font = .monospacedSystemFont(ofSize: 12.5, weight: .regular)
        editor.textContainerInset = NSSize(width: 6, height: 6)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? NSTextView else { return }
        if editor.string != text { editor.string = text }
        editor.setAccessibilityLabel(label)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor
        init(_ parent: PlainTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}

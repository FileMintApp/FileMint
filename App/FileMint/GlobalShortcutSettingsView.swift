import AppKit
import Carbon
import FileMintCore
import SwiftUI

struct GlobalShortcutSettingsSection: View {
    @EnvironmentObject private var model: PreferencesModel
    @ObservedObject var controller: GlobalShortcutController
    let favorites: FavoriteLocationsModel
    let searchController: QuickSearchPanelController
    @State private var keyboardRevision = 0
    private var language: AppLanguage { model.preferences.language }

    var body: some View {
        SettingsSection(title: text(.title)) {
            PreferenceRow(title: text(.enable), detail: text(.enableHint)) {
                Toggle(text(.enable), isOn: Binding(
                    get: { model.preferences.globalShortcut.isEnabled },
                    set: { model.setGlobalShortcutEnabled($0) }))
                    .labelsHidden().accessibilityIdentifier("shortcut.enabled")
            }
            Divider()
            PreferenceRow(title: text(.combination), detail: text(.recordingHint)) {
                HStack(spacing: 8) {
                    ShortcutRecorder(title: recorderTitle, recording: controller.isRecording,
                        begin: controller.beginRecording, cancel: controller.endRecording,
                        record: model.setGlobalShortcutCombination)
                        .frame(width: 150, height: 24)
                        .accessibilityLabel(text(.combination) + ": " + recorderTitle).accessibilityIdentifier("shortcut.recorder")
                    Button(text(.reset)) { model.setGlobalShortcutCombination(.suggested) }
                        .disabled(model.preferences.globalShortcut.combination == nil || model.preferences.globalShortcut.combination == .suggested)
                        .accessibilityIdentifier("shortcut.reset")
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Text(status).font(.system(size: 11)).foregroundStyle(controller.failure == nil ? Color.secondary : .orange)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("shortcut.status")
                if !controller.isRecording, model.preferences.globalShortcut.effectiveCombination != nil,
                   !controller.isRegistered {
                    Button(text(.retry)) { controller.retry() }.controlSize(.small)
                        .accessibilityIdentifier("shortcut.retry")
                }
                Spacer(minLength: 0)
            }
            Button(text(.menu)) { searchController.show(settings: model, favorites: favorites) }
                .accessibilityIdentifier("shortcut.openSearch")
        }
        .onReceive(DistributedNotificationCenter.default().publisher(
            for: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String))) { _ in keyboardRevision += 1 }
        .onDisappear { controller.endRecording() }
    }

    private func text(_ key: QuickSearchText) -> String { key.text(language) }
    private var recorderTitle: String {
        _ = keyboardRevision
        if controller.isRecording { return text(.recording) }
        return model.preferences.globalShortcut.combination.map(GlobalShortcutKeyboard.title) ?? text(.defaultKey)
    }
    private var status: String {
        if controller.isRecording { return text(.recordingHint) }
        if let failure = controller.failure {
            return failure.message(language) + (controller.isRegistered ? " " + text(.previousActive) : "")
        }
        if !model.preferences.globalShortcut.isEnabled { return text(.disabled) }
        if model.preferences.globalShortcut.combination == nil { return text(.unassigned) }
        return text(controller.isRegistered ? .active : .inactive)
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let title: String
    let recording: Bool
    let begin: () -> Void
    let cancel: () -> Void
    let record: (GlobalShortcut?) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded; button.controlSize = .small
        button.focusRingType = .exterior
        button.target = button; button.action = #selector(ShortcutRecorderButton.beginRecording)
        updateNSView(button, context: context)
        return button
    }
    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.title = title; button.recording = recording
        button.begin = begin; button.cancel = cancel; button.record = record
    }
    static func dismantleNSView(_ button: ShortcutRecorderButton, coordinator: ()) { button.cancelRecording() }
}

private final class ShortcutRecorderButton: NSButton {
    var recording = false
    var begin: () -> Void = {}
    var cancel: () -> Void = {}
    var record: (GlobalShortcut?) -> Void = { _ in }
    override var acceptsFirstResponder: Bool { true }

    @objc func beginRecording() {
        guard !recording else { cancelRecording(); return }
        guard window?.makeFirstResponder(self) == true else { return }
        recording = true; begin()
    }
    @objc func cancelRecording() {
        guard recording else { return }
        recording = false; cancel()
    }
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { cancelRecording() }
        return result
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else { cancelRecording(); return }
        for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(cancelRecording), name: name, object: window)
        }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        capture(event); return true
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        capture(event)
    }
    private func capture(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        cancelRecording()
        if event.keyCode != UInt16(kVK_Escape) { record(GlobalShortcutKeyboard.capture(event)) }
    }
}

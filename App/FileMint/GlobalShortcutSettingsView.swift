import AppKit
import Carbon
import FileMintCore
import SwiftUI

struct GlobalShortcutSettingsSection: View {
    @EnvironmentObject private var model: PreferencesModel
    @ObservedObject var controller: GlobalShortcutController
    let favorites: FavoriteLocationsModel
    let searchController: QuickSearchPanelController
    var body: some View {
        SettingsSection(title: QuickSearchText.title.text(model.preferences.language)) {
            GlobalShortcutControls(controller: controller, destination: .quickSearch)
            Button(QuickSearchText.menu.text(model.preferences.language)) {
                searchController.show(settings: model, favorites: favorites)
            }.accessibilityIdentifier("shortcut.openSearch")
        }
    }
}

struct GlobalShortcutControls: View {
    enum Destination { case quickSearch, drawer }
    @EnvironmentObject private var model: PreferencesModel
    @ObservedObject var controller: GlobalShortcutController
    let destination: Destination
    @State private var keyboardRevision = 0

    private var isDrawer: Bool { destination == .drawer }
    private var language: AppLanguage { model.preferences.language }
    private var saved: GlobalShortcutPreferences { isDrawer ? model.preferences.fileDrawer.shortcut : model.preferences.globalShortcut }
    private var suggested: GlobalShortcut { isDrawer ? .suggestedDrawer : .suggested }
    private var prefix: String { isDrawer ? "drawer.shortcut." : "shortcut." }

    var body: some View {
        Group {
            PreferenceRow(title: text(.enable), detail: isDrawer
                ? (language.resolved() == .chinese ? "从其他应用呼出文件抽屉。" : "Show the drawer from another app.")
                : text(.enableHint)) {
                Toggle(text(.enable), isOn: Binding(get: { saved.isEnabled }, set: setEnabled))
                    .labelsHidden().accessibilityIdentifier(prefix + "enabled")
            }
            Divider()
            PreferenceRow(title: text(.combination), detail: recordingHint) {
                HStack(spacing: 8) {
                    ShortcutRecorder(title: recorderTitle, recording: controller.isRecording,
                        begin: model.beginShortcutRecording, cancel: model.endShortcutRecording, record: record)
                        .frame(width: 150, height: 24)
                        .accessibilityLabel(text(.combination) + ": " + recorderTitle)
                        .accessibilityIdentifier(prefix + "recorder")
                    Button(text(.reset)) { record(suggested) }
                        .disabled(saved.combination == suggested || (!isDrawer && saved.combination == nil))
                        .accessibilityIdentifier(prefix + "reset")
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Text(status).font(.system(size: 11)).foregroundStyle(controller.failure == nil ? Color.secondary : .orange)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(prefix + "status")
                if !controller.isRecording, saved.effectiveCombination != nil, !controller.isRegistered,
                   !isDrawer || model.preferences.fileDrawer.enabled {
                    Button(text(.retry)) { controller.retry() }.controlSize(.small)
                        .accessibilityIdentifier(prefix + "retry")
                }
                Spacer(minLength: 0)
            }
        }
        .onReceive(DistributedNotificationCenter.default().publisher(
            for: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String))) { _ in keyboardRevision += 1 }
        .onDisappear { if controller.isRecording { model.endShortcutRecording() } }
    }

    private func setEnabled(_ enabled: Bool) {
        if isDrawer { model.setDrawerShortcutEnabled(enabled) }
        else { model.setGlobalShortcutEnabled(enabled) }
    }
    private func record(_ value: GlobalShortcut?) {
        if isDrawer { model.setDrawerShortcutCombination(value) }
        else { model.setGlobalShortcutCombination(value) }
    }
    private func text(_ key: QuickSearchText) -> String { key.text(language) }
    private var recordingHint: String {
        if !isDrawer { return text(.recordingHint) }
        let keys = GlobalShortcutKeyboard.title(.suggestedDrawer)
        return language.resolved() == .chinese ? "默认为 \(keys)，点击录制，Esc 取消。"
            : "Default shortcut \(keys). Click to record. Escape cancels."
    }
    private var recorderTitle: String {
        _ = keyboardRevision
        if controller.isRecording { return text(.recording) }
        if let binding = saved.combination { return GlobalShortcutKeyboard.title(binding) }
        return isDrawer ? GlobalShortcutKeyboard.title(suggested) + (language.resolved() == .chinese ? " · 默认" : " · Default")
            : text(.defaultKey)
    }
    private var status: String {
        if controller.isRecording { return recordingHint }
        if let failure = controller.failure {
            return failure.message(language) + (controller.isRegistered ? " " + text(.previousActive) : "")
        }
        if !saved.isEnabled || (isDrawer && !model.preferences.fileDrawer.enabled) { return text(.disabled) }
        if saved.combination == nil { return text(.unassigned) }
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

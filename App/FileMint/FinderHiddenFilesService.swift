import AppKit
import Carbon
import CoreGraphics
import FileMintCore

@MainActor
enum FinderHiddenFilesService {
    static func toggle(language: AppLanguage) {
        guard CGPreflightPostEventAccess() else {
            requestAccess(language: language)
            return
        }
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first(where: {
            !$0.isTerminated && $0.bundleURL?.path == "/System/Library/CoreServices/Finder.app"
        }), let events = shortcutEvents() else {
            let alert = NSAlert()
            alert.messageText = FileMintStrings.text(.fileVisibility, language: language)
            alert.informativeText = FileMintStrings.text(.hiddenFilesUnavailable, language: language)
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        // The context menu requested Finder's command, even if another app has focus now.
        for event in events { event.postToPid(finder.processIdentifier) }
    }

    static func shortcutEvents() -> [CGEvent]? {
        guard let source = CGEventSource(stateID: .privateState) else { return nil }
        let modifiers: CGEventFlags = [.maskCommand, .maskShift]
        // Finder recognizes the shortcut after receiving the modifier key transitions.
        let sequence: [(key: Int, down: Bool, flags: CGEventFlags)] = [
            (kVK_Command, true, .maskCommand),
            (kVK_Shift, true, modifiers),
            (kVK_ANSI_Period, true, modifiers),
            (kVK_ANSI_Period, false, modifiers),
            (kVK_Shift, false, .maskCommand),
            (kVK_Command, false, [])
        ]
        var events: [CGEvent] = []
        for (key, down, flags) in sequence {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: down) else { return nil }
            event.flags = flags
            events.append(event)
        }
        return events
    }

    static func permissionMessage(
        language: AppLanguage,
        systemVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) -> String {
        let settingsPath: FileMintTextKey = systemVersion.majorVersion >= 27 ? .deviceControlSettingsPath : .accessibilitySettingsPath
        return String(format: FileMintStrings.text(.hiddenFilesPermission, language: language),
                      FileMintStrings.text(settingsPath, language: language))
    }

    private static func requestAccess(language: AppLanguage) {
        let alert = NSAlert()
        alert.messageText = FileMintStrings.text(.fileVisibility, language: language)
        alert.informativeText = permissionMessage(language: language)
        alert.addButton(withTitle: FileMintStrings.text(.openSystemSettings, language: language))
        alert.addButton(withTitle: FileMintStrings.text(.cancel, language: language)).keyEquivalent = "\u{1b}"
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        // PostEvent uses the Accessibility settings deep link on both versions.
        _ = CGRequestPostEventAccess()
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}

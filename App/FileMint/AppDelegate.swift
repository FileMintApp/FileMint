import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateModel.shared.startAutomaticChecks()
        if notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true {
            SettingsWindowController.shared.show()
        }
        Task { await PreferencesModel.shared.prepareLoginItemIfNeeded() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { PreferencesModel.shared.handle(url: url) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if UpdateModel.shared.isCommittingInstallation && !UpdateModel.shared.canSafelyRestart {
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return false
    }
}

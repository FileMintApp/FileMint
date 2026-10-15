import AppKit
import FileMintCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateModel.shared.startAutomaticChecks()
        BatchRenameOperations.shared.refreshStatus()
        if notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true {
            SettingsWindowController.shared.show()
        }
        Task { await PreferencesModel.shared.prepareLoginItemIfNeeded() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { PreferencesModel.shared.handle(url: url) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard ApplicationTerminationPolicy.canQuit(
            pendingCreations: PreferencesModel.shared.pendingCreationCount,
            hasActiveWrite: CustomFileSavePanelController.shared.hasActiveWrite,
            hasFileOperation: FileOperationCoordinator.shared.isBusy,
            hasFavoriteOperation: FavoriteLocationsModel.sharedIsBusy) else { return .terminateCancel }
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

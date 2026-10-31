import AppKit
import FileMintCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PreferencesModel.shared.startGlobalShortcut()
        UpdateModel.shared.startAutomaticChecks()
        BatchRenameOperations.shared.refreshStatus()
        FileMintLauncherShortcuts.updateAppShortcutParameters()
        let activationExpected = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: AEKeyword(kAEApplicationActivationExpected))?.booleanValue == true
        PreferencesModel.shared.externalInvocations.handleOrdinaryLaunch(
            isDefault: notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true,
            activationExpected: activationExpected)
        Task { await PreferencesModel.shared.prepareLoginItemIfNeeded() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { PreferencesModel.shared.handle(url: url) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if FileOperationCoordinator.shared.isReadingFiles {
            Task {
                await FileOperationCoordinator.shared.cancelActiveReadsAndWait()
                sender.reply(toApplicationShouldTerminate: self.mayTerminate)
            }
            return .terminateLater
        }
        return mayTerminate ? .terminateNow : .terminateCancel
    }

    private var mayTerminate: Bool {
        guard ApplicationTerminationPolicy.canQuit(
            pendingCreations: PreferencesModel.shared.pendingCreationCount,
            hasActiveWrite: CustomFileSavePanelController.shared.hasActiveWrite,
            hasFileOperation: FileOperationCoordinator.shared.isBusy,
            hasFavoriteOperation: FavoriteLocationsModel.sharedIsBusy) else { return false }
        if UpdateModel.shared.isCommittingInstallation && !UpdateModel.shared.canSafelyRestart {
            return false
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { PreferencesModel.shared.globalShortcuts.shutdown() }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PreferencesModel.shared.externalInvocations.handleReopen()
        return false
    }
}

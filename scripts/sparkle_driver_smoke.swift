// Compile alongside the production SparkleInstaller.swift and real Sparkle.
// This substitutes UI sinks only; it never starts networking or installs an app.
import AppKit
import FileMintCore
import Sparkle

@MainActor final class UpdateModel {
    enum State: Equatable {
        case idle, checking, downloading, verifying, installing, waitingToRestart
        case failed(FileMintTextKey)
    }
    var state: State = .idle
    var progress = 0.0
    var cancellable = false
    var canSafelyRestart = true
    var finished = false
    var isFailure: Bool { if case .failed = state { true } else { false } }
    func installationChanged(_ state: State, progress: Double = 0, cancellable: Bool = false) {
        self.state = state
        self.progress = min(1, max(0, progress))
        self.cancellable = cancellable
    }
    func installationFinished() { finished = true }
}
@MainActor final class PreferencesModel {
    enum Pane { case about }
    static let shared = PreferencesModel()
    var selectedPane = Pane.about
    func text(_ key: FileMintTextKey) -> String { FileMintStrings.text(key, language: .english) }
}
@MainActor final class SettingsWindowController {
    static let shared = SettingsWindowController()
    func show() {}
}

@main struct DriverSmoke {
    @MainActor static func main() throws {
        let model = UpdateModel()
        let driver = SparkleInstaller(model: model)
        // Optional delegate methods must have the actual Objective-C selectors.
        for name in ["updater:mayPerformUpdateCheck:error:", "updater:shouldProceedWithUpdate:updateCheck:error:",
                     "updater:didFinishUpdateCycleForUpdateCheck:error:", "feedURLStringForUpdater:"] {
            precondition(driver.responds(to: NSSelectorFromString(name)), "Missing delegate: \(name)")
        }
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: driver)
        do {
            try driver.updater(updater, mayPerform: .updatesInBackground)
            fatalError("Unexpected background update permission")
        } catch {}
        var cancelled = 0
        driver.showUserInitiatedUpdateCheck { cancelled += 1 }
        precondition(model.state == .checking && model.cancellable)
        driver.cancel()
        driver.cancel()
        precondition(cancelled == 1)
        var staleChoice: SPUUserUpdateChoice?
        driver.showReady(toInstallAndRelaunch: { staleChoice = $0 })
        precondition(staleChoice == .skip, "A cancelled download must never restart the app")
        driver.updater(updater, didFinishUpdateCycleFor: .updates, error: nil)
        precondition(model.finished)

        let active = SparkleInstaller(model: model)
        active.showDownloadInitiated { cancelled += 1 }
        active.showDownloadDidReceiveExpectedContentLength(100)
        active.showDownloadDidReceiveData(ofLength: 40)
        precondition(model.state == .downloading && model.progress == 0.4 && model.cancellable)
        active.showDownloadDidStartExtractingUpdate()
        active.cancel()
        precondition(cancelled == 1 && model.state == .verifying && !model.cancellable)
        model.canSafelyRestart = false
        var choice: SPUUserUpdateChoice?
        active.showReady(toInstallAndRelaunch: { choice = $0 })
        precondition(choice == .skip && model.state == .failed(.updateFinishWork))
        model.canSafelyRestart = true
        active.showReady(toInstallAndRelaunch: { choice = $0 })
        precondition(choice == .install && model.state == .installing)
        var retried = 0
        active.showInstallingUpdate(withApplicationTerminated: false, retryTerminatingApplication: { retried += 1 })
        active.retryTermination()
        precondition(retried == 1 && model.state == .waitingToRestart)
        active.showInstallingUpdate(withApplicationTerminated: true, retryTerminatingApplication: { retried += 1 })
        active.retryTermination()
        precondition(retried == 1)
        var acknowledged = false
        active.showUpdaterError(NSError(domain: "Test", code: 1), acknowledgement: { acknowledged = true })
        precondition(acknowledged && model.state == .failed(.updateInstallFailed))
        active.dismissUpdateInstallation()
        precondition(model.state == .failed(.updateInstallFailed))
        print("PASS Sparkle driver: selectors, no background checks, cancellation, progress, draft deferral, relaunch choice, retry and errors")
    }
}

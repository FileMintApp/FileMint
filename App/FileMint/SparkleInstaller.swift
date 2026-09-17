import AppKit
import FileMintCore
import Sparkle

/// Only explicit Update and Restart requests enter this visible user driver.
/// Sparkle owns the out-of-process installer and all downloaded executable bytes.
@MainActor
final class SparkleInstaller: NSObject, SPUUserDriver, SPUUpdaterDelegate {
    private weak var model: UpdateModel?
    private var selectedUpdate: AppUpdate?
    private var cancellation: (() -> Void)?
    private var retry: (() -> Void)?
    private var expectedLength: UInt64 = 0
    private var receivedLength: UInt64 = 0
    private var started = false
    private var cancelled = false
    private lazy var updater = SPUUpdater(hostBundle: .main, applicationBundle: .main,
                                          userDriver: self, delegate: self)

    init(model: UpdateModel) { self.model = model }

    func install(_ update: AppUpdate) {
        guard !updater.sessionInProgress else { return }
        selectedUpdate = update
        cancelled = false
        do {
            if !started {
                try updater.start()
                started = true
            }
            updater.checkForUpdates()
        } catch {
            model?.installationChanged(.failed(.updateInstallFailed))
            model?.installationFinished()
        }
    }

    func cancel() {
        guard let cancellation else { return }
        cancelled = true
        self.cancellation = nil
        cancellation()
    }

    func retryTermination() { retry?() }

    func feedURLString(for updater: SPUUpdater) -> String? {
        selectedUpdate.map { UpdateInstallationPolicy.appcastURL(for: $0).absoluteString }
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard updateCheck == .updates, selectedUpdate != nil, !cancelled else {
            throw validationError()
        }
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem,
                 updateCheck: SPUUpdateCheck) throws {
        guard let selectedUpdate,
              UpdateInstallationPolicy.accepts(selectedUpdate, displayVersion: item.displayVersionString,
                downloadURL: item.fileURL, size: item.contentLength,
                informationOnly: item.isInformationOnlyUpdate, delta: item.isDeltaUpdate),
              item.deltaUpdates?.isEmpty != false,
              item.installationType == "application" else { throw validationError() }
    }

    func updater(_ updater: SPUUpdater, shouldDownloadReleaseNotesForUpdate item: SUAppcastItem) -> Bool {
        false // The About page links to GitHub release notes; never execute remote HTML.
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if error != nil && !cancelled && model?.isFailure == false {
            model?.installationChanged(.failed(.updateInstallFailed))
        }
        selectedUpdate = nil
        cancellation = nil
        retry = nil
        model?.installationFinished()
    }

    private func validationError() -> NSError {
        NSError(domain: "FileMint.Update", code: 1,
                userInfo: [NSLocalizedDescriptionKey: PreferencesModel.shared.text(.updateInvalidRelease)])
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
        model?.installationChanged(.checking, cancellable: true)
    }

    func showUpdateFound(with item: SUAppcastItem, state: SPUUserUpdateState,
                         reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // The user already accepted this exact version in the About page.
        reply(cancelled ? .skip : .install)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        model?.installationChanged(.failed(.updateInvalidRelease))
        acknowledgement()
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        if !cancelled { model?.installationChanged(.failed(.updateInstallFailed)) }
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
        receivedLength = 0
        expectedLength = 0
        model?.installationChanged(.downloading, cancellable: true)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        expectedLength = expectedContentLength
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        guard !cancelled else { return }
        let (received, overflow) = receivedLength.addingReportingOverflow(length)
        receivedLength = overflow ? UInt64.max : received
        let progress = expectedLength > 0 ? Double(receivedLength) / Double(expectedLength) : 0
        model?.installationChanged(.downloading, progress: progress, cancellable: true)
    }

    func showDownloadDidStartExtractingUpdate() {
        cancellation = nil
        model?.installationChanged(.verifying)
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard !cancelled else { reply(.skip); return }
        guard model?.canSafelyRestart == true else {
            model?.installationChanged(.failed(.updateFinishWork))
            reply(.skip) // Cancel installation, including install-on-quit; keep the draft intact.
            return
        }
        model?.installationChanged(.installing)
        reply(.install)
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool,
                              retryTerminatingApplication: @escaping () -> Void) {
        retry = applicationTerminated ? nil : retryTerminatingApplication
        model?.installationChanged(applicationTerminated ? .installing : .waitingToRestart)
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func dismissUpdateInstallation() {
        cancellation = nil
        retry = nil
        // The delegate finishes the session; do not enable a second install early.
    }

    func showUpdateInFocus() {
        PreferencesModel.shared.selectedPane = .about
        SettingsWindowController.shared.show()
    }
}

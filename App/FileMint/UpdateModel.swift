import AppKit
import Combine
import FileMintCore
import Foundation

@MainActor
final class UpdateModel: ObservableObject {
    static let shared = UpdateModel()

    enum State: Equatable {
        case idle, checking, upToDate, available, downloading, verifying, installing, waitingToRestart
        case failed(FileMintTextKey)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var update: AppUpdate?
    @Published private(set) var progress: Double = 0
    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    private let client = UpdateClient()
    private lazy var installer = SparkleInstaller(model: self)
    @Published private(set) var isInstalling = false
    @Published private(set) var canCancelInstallation = false
    var isCommittingInstallation: Bool { isInstalling && !canCancelInstallation }
    private var operation: Task<Void, Never>?
    private var operationID = UUID()
    private var automaticCheckTimer: Timer?
    private var automaticPreferenceObserver: AnyCancellable?
    private var automaticCheckID: UUID?

    var isBusy: Bool { isInstalling || state == .checking }
    var canCancel: Bool { isInstalling ? canCancelInstallation : state == .checking }
    var canDownload: Bool { update != nil && !isBusy }
    var isFailure: Bool { if case .failed = state { return true }; return false }

    var statusKey: FileMintTextKey {
        switch state {
        case .idle: return .updateIdle
        case .checking: return .updateChecking
        case .upToDate: return .updateCurrent
        case .available: return .updateAvailable
        case .downloading: return .updateDownloading
        case .verifying: return .updateVerifying
        case .installing: return .updateInstalling
        case .waitingToRestart: return .updateFinishWork
        case .failed(let key): return key
        }
    }

    func startAutomaticChecks() {
        guard automaticPreferenceObserver == nil else { return }
        automaticPreferenceObserver = PreferencesModel.shared.$preferences
            .removeDuplicates {
                $0.automaticallyChecksForUpdates == $1.automaticallyChecksForUpdates &&
                    $0.lastUpdateCheckAttempt == $1.lastUpdateCheckAttempt
            }
            .sink { [weak self] preferences in
                // @Published emits before assigning the new preferences.
                let enabled = preferences.automaticallyChecksForUpdates
                Task { @MainActor in self?.automaticSettingsChanged(enabled: enabled) }
            }
    }

    private func automaticSettingsChanged(enabled: Bool) {
        if !enabled, automaticCheckID != nil {
            cancel()
        }
        scheduleAutomaticCheck()
    }

    private func scheduleAutomaticCheck() {
        automaticCheckTimer?.invalidate()
        automaticCheckTimer = nil
        let model = PreferencesModel.shared
        guard automaticPreferenceObserver != nil, model.preferences.automaticallyChecksForUpdates,
              !isBusy, update == nil else { return }
        let now = Date()
        if let saved = model.preferences.lastUpdateCheckAttempt, saved > now {
            guard model.recordUpdateCheckAttempt(now) else { return }
        }
        guard let next = AutomaticUpdatePolicy.nextCheckDate(enabled: true,
            lastAttempt: model.preferences.lastUpdateCheckAttempt, now: now) else { return }
        let delay = max(AutomaticUpdatePolicy.startupDelay, next.timeIntervalSince(now))
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.checkAutomaticallyIfDue() }
        }
        timer.tolerance = min(3600, delay / 10)
        automaticCheckTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func checkAutomaticallyIfDue() {
        let preferences = PreferencesModel.shared.preferences
        guard preferences.automaticallyChecksForUpdates, !isBusy, update == nil else { return }
        let now = Date()
        guard let next = AutomaticUpdatePolicy.nextCheckDate(enabled: true,
            lastAttempt: preferences.lastUpdateCheckAttempt, now: now), next <= now else {
            scheduleAutomaticCheck()
            return
        }
        checkForUpdates(automatically: true)
    }

    func checkForUpdates() { checkForUpdates(automatically: false) }

    private func checkForUpdates(automatically: Bool) {
        guard !isBusy else { return }
        automaticCheckTimer?.invalidate()
        automaticCheckTimer = nil
        // Failed and cancelled attempts also consume the weekly automatic check.
        let recorded = PreferencesModel.shared.recordUpdateCheckAttempt(Date())
        guard recorded || !automatically else {
            scheduleAutomaticCheck()
            return
        }
        let id = UUID()
        operationID = id
        automaticCheckID = automatically ? id : nil
        update = nil
        state = .checking
        operation = Task {
            defer {
                if operationID == id {
                    operation = nil
                    automaticCheckID = nil
                    scheduleAutomaticCheck()
                }
            }
            do {
                let result = try await client.check(currentVersion: currentVersion)
                guard operationID == id, !Task.isCancelled else { return }
                if automatically && !PreferencesModel.shared.preferences.automaticallyChecksForUpdates {
                    cancel()
                    return
                }
                update = result
                state = result == nil ? .upToDate : .available
            } catch {
                guard operationID == id, !Task.isCancelled else { return }
                state = .failed(errorKey(error))
            }
        }
    }

    var canSafelyRestart: Bool {
        UpdateInstallationPolicy.canRestart(
            hasDraft: CustomFileSavePanelController.shared.hasActiveDraft,
            pendingCreations: PreferencesModel.shared.pendingCreationCount,
            hasModal: NSApp.modalWindow != nil || NSApp.windows.contains { $0.attachedSheet != nil })
    }

    func downloadUpdate() {
        guard canDownload, let update else { return }
        guard canSafelyRestart else {
            state = .failed(.updateFinishWork)
            return
        }
        automaticCheckTimer?.invalidate()
        automaticCheckTimer = nil
        isInstalling = true
        canCancelInstallation = false
        progress = 0
        state = .checking
        installer.install(update)
    }

    func cancel() {
        guard canCancel else { return }
        if isInstalling {
            installer.cancel()
            return
        }
        operationID = UUID()
        operation?.cancel()
        operation = nil
        automaticCheckID = nil
        state = update == nil ? .idle : .available
        scheduleAutomaticCheck()
    }

    func retryInstallationRestart() {
        guard canSafelyRestart else { return }
        installer.retryTermination()
    }

    func installationChanged(_ newState: State, progress value: Double = 0, cancellable: Bool = false) {
        state = newState
        progress = min(1, max(0, value))
        canCancelInstallation = cancellable
    }

    func installationFinished() {
        isInstalling = false
        canCancelInstallation = false
        if !isFailure { state = update == nil ? .idle : .available }
        scheduleAutomaticCheck()
    }

    private func errorKey(_ error: Error) -> FileMintTextKey {
        if let error = error as? UpdateValidationError {
            switch error {
            case .invalidChecksum, .checksumMismatch: return .updateChecksumFailed
            case .missingAssets: return .updateMissingAssets
            default: return .updateInvalidRelease
            }
        }
        if let error = error as? UpdateClientError {
            switch error {
            case .noRelease: return .updateNoRelease
            case .rateLimited: return .updateRateLimited
            case .invalidResponse: return .updateInvalidRelease
            case .installerAuthorizationFailed: return .updateInstallerAuthorizationFailed
            }
        }
        if error is URLError { return .updateNetworkFailed }
        return .updateDownloadFailed
    }
}

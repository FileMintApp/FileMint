import AppKit
import Combine
import FileMintCore
import Foundation
import UniformTypeIdentifiers

@MainActor
final class UpdateModel: ObservableObject {
    static let shared = UpdateModel()

    enum State: Equatable {
        case idle, checking, upToDate, available, downloading, verifying, ready
        case failed(FileMintTextKey)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var update: AppUpdate?
    @Published private(set) var progress: Double = 0
    @Published private(set) var installerURL: URL?
    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    private let client = UpdateClient()
    private var verifiedInstaller: VerifiedInstaller?
    private var operation: Task<Void, Never>?
    private var operationID = UUID()
    private var isChoosingDownloadLocation = false
    private var automaticCheckTimer: Timer?
    private var automaticPreferenceObserver: AnyCancellable?
    private var automaticCheckID: UUID?

    var isBusy: Bool { state == .checking || state == .downloading || state == .verifying }
    var canDownload: Bool { update != nil && installerURL == nil && !isBusy }
    var isFailure: Bool { if case .failed = state { return true }; return false }

    var statusKey: FileMintTextKey {
        switch state {
        case .idle: return .updateIdle
        case .checking: return .updateChecking
        case .upToDate: return .updateCurrent
        case .available: return .updateAvailable
        case .downloading: return .updateDownloading
        case .verifying: return .updateVerifying
        case .ready: return .updateReady
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
              !isBusy, !isChoosingDownloadLocation, update == nil, installerURL == nil else { return }
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
        guard preferences.automaticallyChecksForUpdates, !isBusy, !isChoosingDownloadLocation,
              update == nil, installerURL == nil else { return }
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
        guard !isBusy, !isChoosingDownloadLocation else { return }
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
        installerURL = nil
        verifiedInstaller = nil
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

    func downloadUpdate() {
        guard canDownload, !isChoosingDownloadLocation, let update else { return }
        let panel = NSSavePanel()
        panel.title = PreferencesModel.shared.text(.downloadUpdate)
        panel.message = PreferencesModel.shared.text(.updateSaveHint)
        panel.allowedContentTypes = [.diskImage]
        panel.nameFieldStringValue = update.fileName
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        isChoosingDownloadLocation = true
        let response = panel.runModal()
        isChoosingDownloadLocation = false
        defer { scheduleAutomaticCheck() }
        guard response == .OK, let destination = panel.url else { return }
        let accessing = destination.startAccessingSecurityScopedResource()
        let id = UUID()
        operationID = id
        state = .downloading
        progress = 0
        operation = Task {
            defer {
                if accessing { destination.stopAccessingSecurityScopedResource() }
                if operationID == id { operation = nil }
            }
            do {
                let installer = try await client.download(update, to: destination, progress: { [weak self] value in
                    Task { @MainActor in
                        guard let self, self.operationID == id, self.state == .downloading else { return }
                        self.progress = value
                    }
                }, verifying: { [weak self] in
                    Task { @MainActor in
                        guard let self, self.operationID == id, self.state == .downloading else { return }
                        self.state = .verifying
                    }
                })
                // A fully saved file belongs to the user even if UI cancellation
                // wins the race with this callback; stale callbacks never open it.
                guard operationID == id, !Task.isCancelled else { return }
                verifiedInstaller = installer
                installerURL = installer.url
                openInstaller()
            } catch {
                guard operationID == id, !Task.isCancelled else { return }
                state = .failed(errorKey(error))
            }
        }
    }

    func cancel() {
        guard isBusy else { return }
        operationID = UUID()
        operation?.cancel()
        operation = nil
        automaticCheckID = nil
        state = update == nil ? .idle : .available
        progress = 0
        scheduleAutomaticCheck()
    }

    func openInstaller() {
        guard let installer = verifiedInstaller else { return }
        let id = UUID()
        operationID = id
        state = .verifying
        let accessing = installer.url.startAccessingSecurityScopedResource()
        operation = Task {
            defer {
                if accessing { installer.url.stopAccessingSecurityScopedResource() }
                if operationID == id { operation = nil }
            }
            do {
                try await client.validateInstaller(installer)
                guard operationID == id, !Task.isCancelled else { return }
                state = NSWorkspace.shared.open(installer.url) ? .ready : .failed(.updateOpenFailed)
            } catch {
                guard operationID == id, !Task.isCancelled else { return }
                verifiedInstaller = nil
                installerURL = nil
                state = .failed(errorKey(error))
            }
        }
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

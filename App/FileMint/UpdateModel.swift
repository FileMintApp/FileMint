import AppKit
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

    func checkForUpdates() {
        guard !isBusy, !isChoosingDownloadLocation else { return }
        let id = UUID()
        operationID = id
        update = nil
        installerURL = nil
        verifiedInstaller = nil
        state = .checking
        operation = Task {
            defer { if operationID == id { operation = nil } }
            do {
                let result = try await client.check(currentVersion: currentVersion)
                guard operationID == id, !Task.isCancelled else { return }
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
        state = update == nil ? .idle : .available
        progress = 0
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

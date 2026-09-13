import FileMintCore
import Foundation

/// Opt-in live acceptance. Uses the app's actual client without opening or installing a DMG.
@main
struct UpdateSmoke {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("filemint-update-smoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = directory.appendingPathComponent("cache", isDirectory: true)
        let client = UpdateClient(cacheDirectory: cache)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let update = try await client.check(currentVersion: "0.0.0") else {
            throw Failure("Expected a published stable release newer than 0.0.0")
        }
        print("PASS live release: \(update.version), \(update.fileName), \(update.size) bytes")
        try require(try await client.check(currentVersion: update.version.description) == nil, "same-version check")

        let destination = directory.appendingPathComponent(update.fileName)
        let previousContent = Data("existing installer must survive cancellation".utf8)
        try previousContent.write(to: destination)

        let cancellation = CancelOnProgress()
        let cancelled = Task {
            try await client.download(update, to: destination, progress: { value in
                if value > 0 { cancellation.cancel() }
            }, verifying: {})
        }
        cancellation.attach(cancelled)
        do {
            _ = try await cancelled.value
            throw Failure("Cancelled transfer unexpectedly produced an installer")
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        }
        try require(cancellation.didRequestCancellation, "cancellation after receiving download bytes")
        let remaining = try FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil)
        try require(remaining.isEmpty, "cancelled installer cleanup")
        try require(try Data(contentsOf: destination) == previousContent, "existing destination survives cancellation")

        let observations = TransferObservations()
        let installer = try await client.download(update, to: destination, progress: { observations.record(progress: $0) },
                                            verifying: { observations.recordVerification() })
        let url = installer.url
        try await client.validateInstaller(installer)
        try require(observations.receivedProgress, "download progress callbacks")
        try require(observations.verified, "verification phase")
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .quarantinePropertiesKey])
        try require(Int64(values.fileSize ?? 0) == update.size, "verified installer size")
        try require(values.quarantineProperties != nil, "macOS quarantine preserved")
        let cacheContents = try FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil)
        try require(cacheContents.isEmpty, "verified download cache cleanup")
        try Data("changed after download".utf8).write(to: url)
        do {
            try await client.validateInstaller(installer)
            throw Failure("Modified saved installer unexpectedly passed reopening validation")
        } catch UpdateValidationError.checksumMismatch {
            print("PASS modified saved installer is rejected before reopening")
        }
        try FileManager.default.removeItem(at: url)
        try require(!FileManager.default.fileExists(atPath: url.path), "installer cleanup")
        print("PASS retry: downloaded and verified the published installer; no app was installed")
    }

    private static func require(_ result: Bool, _ label: String) throws {
        guard result else { throw Failure(label) }
        print("PASS \(label)")
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}

private final class CancelOnProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<VerifiedInstaller, Error>?
    private var requested = false
    var didRequestCancellation: Bool { lock.withLock { requested } }

    func attach(_ task: Task<VerifiedInstaller, Error>) {
        let shouldCancel = lock.withLock { self.task = task; return requested }
        if shouldCancel { task.cancel() }
    }

    func cancel() {
        let current = lock.withLock { requested = true; return task }
        current?.cancel()
    }
}

private final class TransferObservations: @unchecked Sendable {
    private let lock = NSLock()
    private var progress = false
    private var verification = false
    var receivedProgress: Bool { lock.withLock { progress } }
    var verified: Bool { lock.withLock { verification } }
    func record(progress value: Double) { lock.withLock { if value > 0 { progress = true } } }
    func recordVerification() { lock.withLock { verification = true } }
}

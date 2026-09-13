import CoreServices
import CryptoKit
import FileMintCore
import Foundation

enum UpdateClientError: Error {
    case invalidResponse
    case noRelease
    case rateLimited
}

/// This actor owns network and disk work; neither runs on the UI executor.
actor UpdateClient {
    private let cacheDirectory: URL

    init(cacheDirectory: URL? = nil) {
        self.cacheDirectory = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FileMint/Updates", isDirectory: true)
    }

    func check(currentVersion: String) async throws -> AppUpdate? {
        let session = makeSession(delegate: UpdateSessionDelegate())
        defer { session.invalidateAndCancel() }
        let data = try await readData(from: AppUpdatePolicy.latestReleaseURL, session: session, maximumSize: 1_048_576)
        try Task.checkCancellation()
        return try AppUpdatePolicy.availableUpdate(from: data, currentVersion: currentVersion)
    }

    func download(_ update: AppUpdate, progress: @escaping @Sendable (Double) -> Void,
                  verifying: @escaping @Sendable () -> Void) async throws -> URL {
        try Task.checkCancellation()
        // Each attempt owns a unique directory, including while a cancelled task unwinds.
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try FileManager.default.removeItem(at: cacheDirectory)
        }
        let directory = cacheDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        var keepInstaller = false
        defer { if !keepInstaller { try? FileManager.default.removeItem(at: directory) } }
        let session = makeSession(delegate: UpdateSessionDelegate())
        defer { session.invalidateAndCancel() }

        let checksumData = try await readData(from: update.checksumURL, session: session, maximumSize: 4096)
        let expected = try AppUpdatePolicy.checksum(from: checksumData, fileName: update.fileName)
        if let digest = update.digest, digest != expected { throw UpdateValidationError.checksumMismatch }
        let temporaryURL = directory.appendingPathComponent("download.partial")
        try await downloadFile(update, to: temporaryURL, session: session, progress: progress)
        try Task.checkCancellation()
        verifying()
        let size = try temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, Int64(size) == update.size else { throw UpdateClientError.invalidResponse }
        let hash = try sha256(of: temporaryURL)
        try AppUpdatePolicy.verifyChecksum(hash, expected: expected, assetDigest: update.digest)
        try Task.checkCancellation()

        var destination = directory.appendingPathComponent(update.fileName)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        var values = URLResourceValues()
        values.quarantineProperties = [
            kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload,
            kLSQuarantineAgentNameKey as String: "FileMint",
            kLSQuarantineTimeStampKey as String: Date(),
            kLSQuarantineDataURLKey as String: update.downloadURL,
            kLSQuarantineOriginURLKey as String: update.releaseURL
        ]
        try destination.setResourceValues(values)
        try Task.checkCancellation()
        keepInstaller = true
        return destination
    }

    func removeInstaller(at url: URL) {
        guard url.deletingLastPathComponent().deletingLastPathComponent() == cacheDirectory else { return }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func makeSession(delegate: UpdateSessionDelegate) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    private func request(for url: URL) throws -> URLRequest {
        guard AppUpdatePolicy.allowsNetworkURL(url) else { throw UpdateValidationError.untrustedURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("FileMint-Update-Checker", forHTTPHeaderField: "User-Agent")
        if url == AppUpdatePolicy.latestReleaseURL {
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        }
        return request
    }

    private func readData(from url: URL, session: URLSession, maximumSize: Int) async throws -> Data {
        let (bytes, response) = try await session.bytes(for: request(for: url), delegate: session.delegate as? UpdateSessionDelegate)
        try validate(response)
        guard response.expectedContentLength <= Int64(maximumSize) else { throw UpdateClientError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < maximumSize else { throw UpdateClientError.invalidResponse }
            data.append(byte)
        }
        return data
    }

    private func downloadFile(_ update: AppUpdate, to url: URL, session: URLSession,
                              progress: @Sendable (Double) -> Void) async throws {
        let (bytes, response) = try await session.bytes(for: request(for: update.downloadURL),
                                                       delegate: session.delegate as? UpdateSessionDelegate)
        try validate(response)
        guard response.expectedContentLength < 0 || response.expectedContentLength == update.size else {
            throw UpdateClientError.invalidResponse
        }
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        var buffer = Data()
        buffer.reserveCapacity(65_536)
        var received: Int64 = 0
        for try await byte in bytes {
            received += 1
            guard received <= update.size else { throw UpdateClientError.invalidResponse }
            buffer.append(byte)
            if buffer.count == 65_536 {
                try Task.checkCancellation()
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
                progress(Double(received) / Double(update.size))
            }
        }
        try Task.checkCancellation()
        guard received == update.size else { throw UpdateClientError.invalidResponse }
        try handle.write(contentsOf: buffer)
        try handle.close()
        progress(1)
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse,
              let url = response.url, AppUpdatePolicy.allowsNetworkURL(url) else { throw UpdateClientError.invalidResponse }
        if response.statusCode == 403 || response.statusCode == 429 { throw UpdateClientError.rateLimited }
        if response.statusCode == 404 && url == AppUpdatePolicy.latestReleaseURL { throw UpdateClientError.noRelease }
        guard response.statusCode == 200 else { throw UpdateClientError.invalidResponse }
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while true {
            try Task.checkCancellation()
            guard let data = try handle.read(upToCount: 1_048_576), !data.isEmpty else { break }
            hash.update(data: data)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// URLSession calls these on its own queue. All stored values are immutable.
private final class UpdateSessionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let url = request.url, AppUpdatePolicy.allowsNetworkURL(url) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

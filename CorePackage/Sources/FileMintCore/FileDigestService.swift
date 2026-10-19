import CryptoKit
import Darwin
import Foundation

public enum FileInfoError: Error, Equatable, Sendable {
    case invalidSelection, changed, unsupported, placeholder, accessDenied, unavailable, cancelled, disabled
    public var text: FileInfoText {
        switch self {
        case .invalidSelection: .invalidSelection; case .changed: .changed
        case .unsupported: .unsupported; case .placeholder: .placeholder
        case .accessDenied: .accessDenied; case .unavailable: .readFailed
        case .cancelled: .cancelled; case .disabled: .disabled
        }
    }
}

public struct FileInfoIdentity: Codable, Equatable, Sendable {
    let device: Int32
    let inode: UInt64
    let generation: UInt32
    let birthSeconds: Int64
    let birthNanoseconds: Int64
    let kind: UInt16
    init(_ info: stat) {
        device = info.st_dev; inode = info.st_ino; generation = info.st_gen
        birthSeconds = Int64(info.st_birthtimespec.tv_sec)
        birthNanoseconds = Int64(info.st_birthtimespec.tv_nsec)
        kind = info.st_mode & UInt16(S_IFMT)
    }
}

/// Capture metadata only on the explicit Finder click. No directory/content reads.
public struct FileInfoSelection: Codable, Equatable, Sendable {
    public let source: URL
    public let parent: URL
    public let identity: FileInfoIdentity
    public let parentIdentity: FileInfoIdentity

    public static func capture(_ urls: [URL]) throws -> Self {
        guard FileInfoPolicy.canSelect(urls), let source = urls.first?.standardizedFileURL else {
            throw FileInfoError.invalidSelection
        }
        let parent = source.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let parentInfo = try fileInfoStat(parent)
        guard parentInfo.st_mode & UInt16(S_IFMT) == UInt16(S_IFDIR) else { throw FileInfoError.changed }
        let target = parent.appendingPathComponent(source.lastPathComponent)
        let captured = Self(source: source, parent: parent, identity: FileInfoIdentity(try fileInfoStat(target)),
                            parentIdentity: FileInfoIdentity(parentInfo))
        try captured.validate()
        return captured
    }

    public func validate() throws {
        guard FileInfoPolicy.canSelect([source]), parent.isFileURL,
              source.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == parent,
              FileInfoIdentity(try fileInfoStat(parent)) == parentIdentity,
              parentIdentity.kind == UInt16(S_IFDIR),
              FileInfoIdentity(try fileInfoStat(resolvedSource)) == identity else { throw FileInfoError.changed }
    }
    var resolvedSource: URL { parent.appendingPathComponent(source.lastPathComponent) }
}

public enum FileInfoKind: Equatable, Sendable { case file, directory, unsupported }

public struct FileInfoMetadata: Equatable, Sendable {
    public let kind: FileInfoKind
    public let typeIdentifier: String?
    public let logicalSize: Int64?
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let isPlaceholder: Bool
    let stamp: FileInfoStamp
    public var canCalculate: Bool { kind == .file && !isPlaceholder }
}

struct FileInfoStamp: Equatable, Sendable {
    let identity: FileInfoIdentity
    let size: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64
    let flags: UInt32
    init(_ info: stat) {
        identity = FileInfoIdentity(info); size = info.st_size
        modificationSeconds = Int64(info.st_mtimespec.tv_sec)
        modificationNanoseconds = Int64(info.st_mtimespec.tv_nsec)
        changeSeconds = Int64(info.st_ctimespec.tv_sec)
        changeNanoseconds = Int64(info.st_ctimespec.tv_nsec); flags = info.st_flags
    }
}

/// Only the cancellation flag and coordinator registration cross threads.
/// NSFileCoordinator.cancel() is explicitly callable from any thread.
public final class FileDigestCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var coordinator: NSFileCoordinator?
    public init() {}
    public func cancel() {
        lock.lock(); cancelled = true; let active = coordinator; lock.unlock()
        active?.cancel()
    }
    public func check() throws {
        lock.lock(); let stopped = cancelled; lock.unlock()
        if stopped || Task<Never, Never>.isCancelled { throw FileInfoError.cancelled }
    }
    func register(_ value: NSFileCoordinator?) {
        lock.lock(); coordinator = value; let stopped = cancelled; lock.unlock()
        if stopped { value?.cancel() }
    }
}

public struct FileDigestProgress: Sendable {
    public let bytesRead: Int64
    public let totalBytes: Int64
}

public enum FileDigestService {
    public static let chunkSize = 1_048_576

    /// Metadata only; never opens file contents or enumerates a directory.
    public static func inspect(_ selection: FileInfoSelection) throws -> FileInfoMetadata {
        try selection.validate()
        let url = selection.resolvedSource
        let info = try fileInfoStat(url)
        let kind = info.st_mode & UInt16(S_IFMT)
        let ordinary = kind == UInt16(S_IFREG) || kind == UInt16(S_IFDIR)
        // Avoid Foundation resource queries on links and special devices.
        let values = ordinary ? try url.resourceValues(forKeys: [.isPackageKey, .isAliasFileKey,
            .typeIdentifierKey, .ubiquitousItemDownloadingStatusKey]) : nil
        let supported = ordinary && values?.isPackage != true && values?.isAliasFile != true
        let placeholder = info.st_flags & UInt32(SF_DATALESS) != 0
            || values?.ubiquitousItemDownloadingStatus == .notDownloaded
        try selection.validate()
        return FileInfoMetadata(kind: supported ? (kind == UInt16(S_IFDIR) ? .directory : .file) : .unsupported,
            typeIdentifier: values?.typeIdentifier, logicalSize: supported && kind == UInt16(S_IFREG) ? info.st_size : nil,
            createdAt: info.st_birthtimespec.tv_sec > 0 ? Date(timeIntervalSince1970:
                Double(info.st_birthtimespec.tv_sec) + Double(info.st_birthtimespec.tv_nsec) / 1e9) : nil,
            modifiedAt: Date(timeIntervalSince1970: Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9),
            isPlaceholder: placeholder, stamp: FileInfoStamp(info))
    }

    /// Synchronous worker API: its caller must stay off the main thread.
    public static func calculate(_ selection: FileInfoSelection, choice: FileDigestChoice,
                                 cancellation: FileDigestCancellation = FileDigestCancellation(),
                                 progress: @Sendable (FileDigestProgress) -> Void = { _ in }) throws -> FileDigestResult {
        try cancellation.check()
        let initial = try inspect(selection)
        guard initial.kind == .file else { throw FileInfoError.unsupported }
        guard !initial.isPlaceholder else { throw FileInfoError.placeholder }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        cancellation.register(coordinator)
        defer { cancellation.register(nil) }
        try cancellation.check()
        var coordinationError: NSError?
        var result: Result<FileDigestResult, Error>?
        coordinator.coordinate(readingItemAt: selection.resolvedSource, options: [.withoutChanges], error: &coordinationError) { url in
            result = Result {
                try cancellation.check()
                guard url.standardizedFileURL == selection.resolvedSource.standardizedFileURL else { throw FileInfoError.changed }
                return try read(selection, initial: initial, choice: choice, cancellation: cancellation, progress: progress)
            }
        }
        try cancellation.check()
        if let result { return try result.get() }
        if let coordinationError { throw fileInfoError(coordinationError) }
        throw FileInfoError.unavailable
    }

    private static func read(_ selection: FileInfoSelection, initial: FileInfoMetadata, choice: FileDigestChoice,
                             cancellation: FileDigestCancellation,
                             progress: @Sendable (FileDigestProgress) -> Void) throws -> FileDigestResult {
        let fresh = try inspect(selection)
        guard fresh.canCalculate, fresh.stamp == initial.stamp else { throw FileInfoError.changed }
        let version = generation(of: selection.resolvedSource)
        // O_EVTONLY pins parent identity without asking to read its directory contents.
        let parent = open(selection.parent.path, O_EVTONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw fileInfoPOSIXError() }
        defer { close(parent) }
        var parentInfo = stat()
        guard fstat(parent, &parentInfo) == 0,
              FileInfoIdentity(parentInfo) == selection.parentIdentity else { throw FileInfoError.changed }
        let fd = openat(parent, selection.source.lastPathComponent, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw fileInfoPOSIXError() }
        defer { close(fd) }
        var before = stat()
        guard fstat(fd, &before) == 0, FileInfoStamp(before) == fresh.stamp,
              before.st_mode & UInt16(S_IFMT) == UInt16(S_IFREG), before.st_size >= 0 else { throw FileInfoError.changed }
        try selection.validate()
        var hashes = FileDigestAccumulator(choice)
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var count: Int64 = 0
        var lastProgress = ProcessInfo.processInfo.systemUptime
        progress(FileDigestProgress(bytesRead: 0, totalBytes: before.st_size))
        while true {
            try cancellation.check()
            let length = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!, $0.count) }
            if length < 0 {
                if errno == EINTR { continue }
                throw fileInfoPOSIXError()
            }
            if length == 0 { break }
            count += Int64(length)
            guard count <= before.st_size else { throw FileInfoError.changed }
            buffer.withUnsafeBytes { hashes.update(UnsafeRawBufferPointer(rebasing: $0[..<length])) }
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastProgress >= 0.08 {
                progress(FileDigestProgress(bytesRead: count, totalBytes: before.st_size)); lastProgress = now
            }
        }
        try cancellation.check()
        var after = stat()
        guard fstat(fd, &after) == 0, FileInfoStamp(after) == fresh.stamp,
              count == before.st_size, try inspect(selection).stamp == fresh.stamp,
              generation(of: selection.resolvedSource) == version else { throw FileInfoError.changed }
        progress(FileDigestProgress(bytesRead: count, totalBytes: count))
        try cancellation.check()
        return FileDigestResult(choice: choice, bytesRead: count, values: hashes.finalize(), metadata: fresh)
    }

    private static func generation(of url: URL) -> Data? {
        guard let identifier = try? url.resourceValues(forKeys: [.generationIdentifierKey]).generationIdentifier else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: identifier, requiringSecureCoding: true)
    }
}

private struct FileDigestAccumulator {
    var md5: Insecure.MD5?
    var sha1: Insecure.SHA1?
    var sha256: SHA256?
    var sha512: SHA512?
    init(_ choice: FileDigestChoice) {
        let algorithms = choice.algorithms
        md5 = algorithms.contains(.md5) ? Insecure.MD5() : nil
        sha1 = algorithms.contains(.sha1) ? Insecure.SHA1() : nil
        sha256 = algorithms.contains(.sha256) ? SHA256() : nil
        sha512 = algorithms.contains(.sha512) ? SHA512() : nil
    }
    mutating func update(_ buffer: UnsafeRawBufferPointer) {
        md5?.update(bufferPointer: buffer); sha1?.update(bufferPointer: buffer)
        sha256?.update(bufferPointer: buffer); sha512?.update(bufferPointer: buffer)
    }
    mutating func finalize() -> [FileDigestValue] {
        var values: [FileDigestValue] = []
        func add<D: Digest>(_ digest: D?, _ algorithm: FileDigestAlgorithm) {
            if let digest { values.append(FileDigestValue(algorithm: algorithm,
                hexadecimal: digest.map { String(format: "%02x", $0) }.joined())) }
        }
        add(md5?.finalize(), .md5); add(sha1?.finalize(), .sha1)
        add(sha256?.finalize(), .sha256); add(sha512?.finalize(), .sha512)
        return values
    }
}

private func fileInfoStat(_ url: URL) throws -> stat {
    var value = stat()
    guard lstat(url.path, &value) == 0 else { throw fileInfoPOSIXError() }
    return value
}
private func fileInfoPOSIXError() -> FileInfoError {
    switch errno { case EACCES, EPERM: .accessDenied; case ENOENT, ENOTDIR, ELOOP: .changed; default: .unavailable }
}
private func fileInfoError(_ error: NSError) -> FileInfoError {
    if error.domain == NSCocoaErrorDomain, error.code == NSUserCancelledError { return .cancelled }
    if error.domain == NSCocoaErrorDomain, error.code == NSFileReadNoPermissionError { return .accessDenied }
    return .unavailable
}

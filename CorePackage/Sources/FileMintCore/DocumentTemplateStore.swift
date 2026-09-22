import Foundation
import CryptoKit
import Darwin

public struct DocumentTemplateReference: Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: OfficeDocumentKind
    public let byteCount: Int
    public let sha256: String
}

public struct DocumentTemplateStore: Sendable {
    public let directory: URL
    public init(directory: URL = FileMintStorage.directory.appendingPathComponent("document-templates", isDirectory: true)) {
        self.directory = directory
    }

    public func importDocument(at source: URL) throws -> DocumentTemplateReference {
        guard let kind = OfficeDocumentKind(rawValue: source.pathExtension.lowercased()) else { throw DocumentTemplateError.unsupported }
        let data = try Self.readRegularFile(source)
        try OfficeDocumentValidator.validate(data, kind: kind)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard (try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])).isSymbolicLink != true else {
            throw DocumentTemplateError.unavailable
        }
        let reference = DocumentTemplateReference(id: UUID(), kind: kind, byteCount: data.count, sha256: Self.digest(data))
        let target = url(for: reference)
        var created = false
        do {
            _ = try BinaryFileWriter.create(data, in: directory, name: target.lastPathComponent, collision: .fail)
            created = true
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        } catch {
            // This unpredictable path belongs solely to this attempted import.
            if created { try? FileManager.default.removeItem(at: target) }
            throw error
        }
        return reference
    }

    public func data(for reference: DocumentTemplateReference) throws -> Data {
        do {
            guard (1...OfficeDocumentValidator.maximumBytes).contains(reference.byteCount), reference.sha256.count == 64 else {
                throw DocumentTemplateError.unavailable
            }
            let data = try Self.readRegularFile(url(for: reference))
            guard data.count == reference.byteCount, Self.digest(data) == reference.sha256 else { throw DocumentTemplateError.unavailable }
            try OfficeDocumentValidator.validate(data, kind: reference.kind)
            return data
        } catch { throw DocumentTemplateError.unavailable }
    }

    public func remove(_ reference: DocumentTemplateReference) throws {
        // Do not remove a replacement, symlink or unknown file at the asset path.
        _ = try data(for: reference)
        try FileManager.default.removeItem(at: url(for: reference))
    }

    private func url(for reference: DocumentTemplateReference) -> URL {
        directory.appendingPathComponent(reference.id.uuidString + "." + reference.kind.rawValue)
    }

    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    private static func readRegularFile(_ url: URL) throws -> Data {
        guard url.isFileURL else { throw DocumentTemplateError.unsupported }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              values.isUbiquitousItem != true || values.ubiquitousItemDownloadingStatus == .current || values.ubiquitousItemDownloadingStatus == .downloaded else {
            throw DocumentTemplateError.unsupported
        }
        var before = stat()
        guard url.withUnsafeFileSystemRepresentation({ lstat($0!, &before) }) == 0,
              before.st_mode & S_IFMT == S_IFREG, before.st_flags & UInt32(SF_DATALESS) == 0 else { throw DocumentTemplateError.unsupported }
        guard before.st_size > 0, before.st_size <= OfficeDocumentValidator.maximumBytes else { throw DocumentTemplateError.tooLarge }
        let descriptor = url.withUnsafeFileSystemRepresentation { open($0!, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC) }
        guard descriptor >= 0 else { throw DocumentTemplateError.unavailable }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, opened.st_mode & S_IFMT == S_IFREG, opened.st_flags & UInt32(SF_DATALESS) == 0,
              opened.st_ino == before.st_ino, opened.st_dev == before.st_dev, opened.st_size == before.st_size else {
            throw DocumentTemplateError.unavailable
        }
        guard let data = try handle.read(upToCount: OfficeDocumentValidator.maximumBytes + 1), data.count == before.st_size else {
            throw DocumentTemplateError.unavailable
        }
        var after = stat()
        guard url.withUnsafeFileSystemRepresentation({ lstat($0!, &after) }) == 0,
              after.st_ino == before.st_ino, after.st_dev == before.st_dev, after.st_size == before.st_size,
              after.st_mtimespec.tv_sec == before.st_mtimespec.tv_sec, after.st_mtimespec.tv_nsec == before.st_mtimespec.tv_nsec else {
            throw DocumentTemplateError.unavailable
        }
        return data
    }
}

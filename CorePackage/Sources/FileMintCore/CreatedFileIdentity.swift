import Foundation
import Darwin

public struct CreatedFileIdentity: Codable, Equatable, Sendable {
    public let device: Int32
    public let inode: UInt64
    public let birthSeconds: Int64
    public let birthNanos: Int64
    public let size: Int64
    public let modifiedSeconds: Int64
    public let modifiedNanos: Int64
    init(_ value: stat) {
        device = value.st_dev; inode = value.st_ino
        birthSeconds = Int64(value.st_birthtimespec.tv_sec); birthNanos = Int64(value.st_birthtimespec.tv_nsec)
        size = value.st_size
        modifiedSeconds = Int64(value.st_mtimespec.tv_sec); modifiedNanos = Int64(value.st_mtimespec.tv_nsec)
    }
    public static func capture(_ url: URL) throws -> Self {
        var value = stat()
        guard url.isFileURL, url.withUnsafeFileSystemRepresentation({ $0.map { lstat($0, &value) } ?? -1 }) == 0,
              value.st_mode & S_IFMT == S_IFREG, value.st_flags & UInt32(SF_DATALESS) == 0 else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return Self(value)
    }
    public func validate(_ url: URL) throws {
        guard try Self.capture(url) == self else { throw CocoaError(.fileReadUnknown) }
    }
}

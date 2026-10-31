import CryptoKit
import Darwin
import Foundation

public enum LauncherScriptError: Error, Equatable, Sendable {
    case invalidScript, changedScript, unavailable, invalidIndex
}

/// Reads only an explicitly selected file. Bodies stay in the script, not the index.
public struct LauncherScriptSnapshot: Equatable, Sendable {
    public let data: Data
    public let identity: CreatedFileIdentity
    public var fingerprint: String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    public static func read(at url: URL, maximumBytes: Int = 32 * 1024) throws -> Self {
        guard OpenWithPolicy.isLocalFileURL(url) else { throw LauncherScriptError.unavailable }
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else { throw LauncherScriptError.unavailable }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var before = stat(), after = stat()
        guard fstat(descriptor, &before) == 0, before.st_mode & S_IFMT == S_IFREG,
              before.st_flags & UInt32(SF_DATALESS) == 0, before.st_size <= maximumBytes,
              let data = try handle.read(upToCount: maximumBytes + 1), data.count == before.st_size,
              fstat(descriptor, &after) == 0, CreatedFileIdentity(before) == CreatedFileIdentity(after),
              try CreatedFileIdentity.capture(url) == CreatedFileIdentity(before) else { throw LauncherScriptError.unavailable }
        return Self(data: data, identity: CreatedFileIdentity(before))
    }

    public func validate(at url: URL) throws {
        guard try Self.read(at: url) == self else { throw LauncherScriptError.changedScript }
    }

    public func contents() throws -> (command: LauncherCommand, bundleIdentifier: String, scheme: String) {
        guard let script = String(data: data, encoding: .utf8) else { throw LauncherScriptError.invalidScript }
        let lines = script.components(separatedBy: "\n")
        func value(_ prefix: String, suffix: String = "") throws -> String {
            let matches = lines.filter { $0.hasPrefix(prefix) && $0.hasSuffix(suffix) }
            guard matches.count == 1, matches[0].count >= prefix.count + suffix.count else { throw LauncherScriptError.invalidScript }
            return String(matches[0].dropFirst(prefix.count).dropLast(suffix.count))
        }
        let title = try value("# @raycast.title ")
        let raw = try value("url='", suffix: "'")
        guard let separator = raw.range(of: "://") else { throw LauncherScriptError.invalidScript }
        let scheme = String(raw[..<separator.lowerBound])
        let canonical = "filemint" + raw[separator.lowerBound...]
        let invocation = try ExternalDraftRoute.parse(canonical)
        let identifier = try value("if ! /usr/bin/open -b '", suffix: "' \"$url\" >/dev/null 2>&1; then")
        let runtimeName = lines.contains { $0.hasPrefix("# @raycast.argument1 ") }
        let command = try LauncherCommand(title: title, invocation: invocation, runtimeName: runtimeName)
        // Parse data only, and accept exactly our renderer's format, including older exports.
        guard try command.raycastScript(bundleIdentifier: identifier, scheme: scheme) == script else { throw LauncherScriptError.invalidScript }
        return (command, identifier, scheme)
    }
}

public struct LauncherScriptRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let url: URL
    public let bookmark: Data
    public let identity: CreatedFileIdentity
    public let fingerprint: String

    public init(id: UUID = UUID(), url: URL, bookmark: Data, snapshot: LauncherScriptSnapshot) throws {
        self.id = id
        title = try snapshot.contents().command.title
        self.url = url.standardizedFileURL
        self.bookmark = bookmark
        identity = snapshot.identity
        fingerprint = snapshot.fingerprint
    }

    public func read(at resolvedURL: URL) throws -> LauncherScriptSnapshot {
        let snapshot = try LauncherScriptSnapshot.read(at: resolvedURL)
        guard snapshot.identity == identity, snapshot.fingerprint == fingerprint else { throw LauncherScriptError.changedScript }
        return snapshot
    }
}

public struct LauncherScriptStore: Sendable {
    public static let maximumBytes = 4 * 1024 * 1024
    public let file: URL
    public init(file: URL = FileMintStorage.directory.appendingPathComponent("launcher-scripts.json")) { self.file = file }

    public func load() throws -> [LauncherScriptRecord] {
        var metadata = stat()
        if lstat(file.path, &metadata) != 0 {
            if errno == ENOENT { return [] }
            throw LauncherScriptError.invalidIndex
        }
        do {
            let data = try LauncherScriptSnapshot.read(at: file, maximumBytes: Self.maximumBytes).data
            let records = try JSONDecoder().decode([LauncherScriptRecord].self, from: data)
            try validate(records)
            return records
        } catch { throw LauncherScriptError.invalidIndex }
    }

    public func save(_ records: [LauncherScriptRecord]) throws {
        try validate(records)
        let data = try JSONEncoder().encode(records)
        guard data.count <= Self.maximumBytes else { throw LauncherScriptError.invalidIndex }
        _ = try load() // Preserve a corrupt, oversized or redirected existing index.
        let manager = FileManager.default, directory = file.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let staging = directory.appendingPathComponent(".launcher-index-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? manager.removeItem(at: staging) }
        let output = staging.appendingPathComponent("index.json")
        try data.write(to: output, options: .withoutOverwriting)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
        guard rename(output.path, file.path) == 0 else { throw LauncherScriptError.invalidIndex }
    }

    private func validate(_ records: [LauncherScriptRecord]) throws {
        guard records.count <= 512, Set(records.map(\.id)).count == records.count,
              Set(records.map(\.url)).count == records.count,
              records.allSatisfy({ OpenWithPolicy.isLocalFileURL($0.url) && $0.url.standardizedFileURL == $0.url &&
                  !$0.title.isEmpty && $0.title.utf8.count <= 256 && !$0.bookmark.isEmpty &&
                  $0.bookmark.count <= 64 * 1024 && $0.fingerprint.count == 64 &&
                  $0.fingerprint.allSatisfy { $0.isHexDigit } }) else { throw LauncherScriptError.invalidIndex }
    }
}

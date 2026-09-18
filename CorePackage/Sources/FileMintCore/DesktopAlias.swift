import Foundation
import Darwin

public struct DesktopAliasFailure: Error, Sendable {
    public let completed: Int
    public let total: Int
}

/// Creates Finder alias files using Foundation, without reading source contents.
public enum DesktopAliasService {
    public static var desktopDirectory: URL {
        // FileManager's sandbox home can be a container. Use the same real-user
        // home resolution as Finder scope; the system handles iCloud Desktop.
        DefaultFolders.resolvedUserHomeDirectory(fileManager: .default)
            .appendingPathComponent("Desktop", isDirectory: true)
    }

    public static func capture(_ selection: [URL]) throws -> [FileMoveItem] {
        guard !selection.isEmpty else { throw FileMoveError.invalidSelection }
        let items = try selection.map(FileMoveItem.capture)
        var paths = Set<String>()
        for item in items {
            let path = item.canonicalParent.appendingPathComponent(item.source.lastPathComponent).path
            guard paths.insert(path).inserted else { throw FileMoveError.invalidSelection }
        }
        return items
    }

    public static func validate(_ items: [FileMoveItem]) throws {
        guard try capture(items.map(\.source)) == items else { throw FileMoveError.sourceChanged }
    }

    @discardableResult
    public static func perform(items: [FileMoveItem], in directory: URL,
                               isAllowed: () -> Bool) throws -> [URL] {
        var created: [URL] = []
        do {
            guard isAllowed() else { throw FileMoveError.disabled }
            try validate(items)
            let destination = try FileMoveItem.capture(directory)
            let values = try directory.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            guard values.isDirectory == true, values.isPackage != true else {
                throw FileMoveError.invalidDestination
            }
            for item in items {
                guard isAllowed() else { throw FileMoveError.disabled }
                try item.validateIdentity()
                try destination.validateIdentity()
                let data = try item.source.bookmarkData(options: .suitableForBookmarkFile,
                    includingResourceValuesForKeys: nil, relativeTo: nil)
                let staging = try makeStagingDirectory(in: directory)
                defer { try? FileManager.default.removeItem(at: staging) }
                let temporaryAlias = staging.appendingPathComponent("alias")
                // This API overwrites, so it must only see a private staging path.
                try URL.writeBookmarkData(data, to: temporaryAlias)
                try item.validateIdentity()
                try destination.validateIdentity()
                guard isAllowed() else { throw FileMoveError.disabled }
                var number = 1
                while true {
                    let target = directory.appendingPathComponent(name(for: item, number: number))
                    let result = temporaryAlias.withUnsafeFileSystemRepresentation { sourcePath in
                        target.withUnsafeFileSystemRepresentation { targetPath in
                            renamex_np(sourcePath!, targetPath!, UInt32(RENAME_EXCL))
                        }
                    }
                    if result == 0 { created.append(target); break }
                    let code = errno
                    guard code == EEXIST else {
                        throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
                    }
                    number += 1
                }
            }
            return created
        } catch {
            throw DesktopAliasFailure(completed: created.count, total: items.count)
        }
    }

    private static func name(for item: FileMoveItem, number: Int) -> String {
        let name = item.source.lastPathComponent
        guard number > 1 else { return name }
        let suffix = item.source.pathExtension
        guard !item.isDirectory, !suffix.isEmpty else { return "\(name) \(number)" }
        return "\(item.source.deletingPathExtension().lastPathComponent) \(number).\(suffix)"
    }

    private static func makeStagingDirectory(in directory: URL) throws -> URL {
        var template = Array(directory.appendingPathComponent(".FileMint-alias-XXXXXX").path.utf8CString)
        guard mkdtemp(&template) != nil else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        return URL(fileURLWithPath: String(decoding: template.dropLast().map { UInt8(bitPattern: $0) },
                                          as: UTF8.self), isDirectory: true)
    }
}

/// App-owned authorization data only; it never changes Finder's configured scope.
public struct DesktopAliasAccessStore: Sendable {
    public let file: URL
    public init(file: URL = FileMintStorage.directory.appendingPathComponent("desktop-alias-access.json")) {
        self.file = file
    }

    public func load() throws -> [String: Data] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
        return try JSONDecoder().decode([String: Data].self, from: Data(contentsOf: file))
    }

    public func save(_ bookmarks: [String: Data]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(bookmarks).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}

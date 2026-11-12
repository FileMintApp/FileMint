import Darwin
import Foundation
import UniformTypeIdentifiers

/// The file identifies the type and scope of the action. Launch Services receives
/// the frozen type, never a request to set a per-file override.
public struct DefaultApplicationSelection: Codable, Equatable, Sendable {
    public let file: FileInfoSelection
    public let typeIdentifier: String

    public static func supportsMenuSelection(_ urls: [URL]) -> Bool {
        guard FileInfoPolicy.canSelect(urls), let url = urls.first else { return false }
        return (try? readType(at: url)) != nil
    }

    public static func capture(_ urls: [URL]) throws -> Self {
        let file = try FileInfoSelection.capture(urls)
        let type = try readType(at: file.resolvedSource)
        try file.validate()
        return Self(file: file, typeIdentifier: type.identifier)
    }

    public func isEnabled(in preferences: FileMintPreferences) -> Bool {
        preferences.fileTools.allows(.defaultApplication) && FileInfoPolicy.canSelect([file.source])
            && FolderScope.contains(file.source, in: preferences.monitoredFolderURLs)
    }

    public func validate(in folders: [URL]) throws -> UTType {
        try file.validate(in: folders)
        let type = try Self.readType(at: file.resolvedSource)
        try file.validate()
        guard type.identifier == typeIdentifier else { throw FileInfoError.changed }
        return type
    }

    private static func readType(at source: URL) throws -> UTType {
        // Start with lstat and a fresh URL: don't let a cached Finder URL or a
        // link cause the metadata query to target a different kind of item.
        let url = URL(fileURLWithPath: source.path, isDirectory: false)
        guard try fileInfoStat(url).st_mode & UInt16(S_IFMT) == UInt16(S_IFREG) else {
            throw FileInfoError.unsupported
        }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey,
            .isPackageKey, .isAliasFileKey, .contentTypeKey])
        guard values.isRegularFile == true, values.isSymbolicLink == false, values.isAliasFile == false,
              values.isPackage == false, let type = values.contentType, type.isDeclared, !type.isDynamic,
              type.conforms(to: .data), type.preferredFilenameExtension != nil else { throw FileInfoError.unsupported }
        return type
    }
}

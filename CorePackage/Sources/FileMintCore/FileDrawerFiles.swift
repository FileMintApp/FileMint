import Darwin
import Foundation

public struct FileDrawerEntry: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let isRegular: Bool
    public let isPackage: Bool
    public let isLink: Bool
    public let isOffline: Bool
    public let size: Int64?
    public let modified: Date?
    public var canEnterDirectory: Bool { isDirectory && !isPackage && !isLink && !isOffline }
    public var canPreview: Bool { isRegular && !isPackage && !isLink && !isOffline }
    fileprivate let identity: BatchRenameIdentity
    fileprivate let parentIdentity: BatchRenameIdentity

    /// Display metadata may change while the same directory entry remains selected.
    public func isSameItem(as other: Self, at destination: URL? = nil) -> Bool {
        url == (destination ?? other.url) && identity == other.identity && parentIdentity == other.parentIdentity
    }

    public func isSameDirectory(as directory: FileDrawerDirectory) -> Bool {
        url == directory.url && identity == directory.identity
    }
}

public enum FileDrawerTransferError: Error, Equatable, Sendable {
    case crossVolumeMove
}

public struct FileDrawerTrashReceipt: Sendable {
    public let originalURL: URL
    public let directory: FileDrawerDirectory
    fileprivate let trashed: URL
    fileprivate let identity: BatchRenameIdentity
}

/// A captured directory within a user-selected root. The caller retains the sandbox
/// grant and runs these synchronous operations on its worker. Descriptors bind
/// mutations to the selected directory even if its pathname is replaced.
public final class FileDrawerDirectory: Sendable {
    private let handle: RenameDirectory
    private let parent: FileDrawerDirectory?
    public let rootURL: URL
    public var url: URL { handle.url }
    public var identity: BatchRenameIdentity { handle.identity }

    public init(root: URL) throws {
        guard OpenWithPolicy.isLocalFileURL(root) else { throw FileMoveError.invalidDestination }
        let path = root.standardizedFileURL
        let canonical = path.path == "/" ? path : path.deletingLastPathComponent().resolvingSymlinksInPath()
            .appendingPathComponent(path.lastPathComponent, isDirectory: true)
        guard let identity = try BatchRenameIdentity.path(canonical), identity.isDirectory,
              try canonical.resourceValues(forKeys: [.isPackageKey]).isPackage != true,
              !FolderScope.contains(canonical, in: [FileMintStorage.directory.resolvingSymlinksInPath()]) else {
            throw FileMoveError.invalidDestination
        }
        handle = try RenameDirectory(canonical, expected: identity)
        rootURL = canonical
        parent = nil
        try validate()
    }

    private init(parent: FileDrawerDirectory, entry: FileDrawerEntry) throws {
        self.parent = parent
        rootURL = parent.rootURL
        handle = try RenameDirectory(parent: parent.handle, component: entry.name, expected: entry.identity)
        try validate()
    }

    public func validate() throws {
        if let parent {
            try parent.validate()
            guard try BatchRenameIdentity.at(url.lastPathComponent, in: parent.handle.fd) == handle.identity else {
                throw FileMoveError.sourceChanged
            }
        }
        try handle.validatePath()
        guard url.resolvingSymlinksInPath().standardizedFileURL.path == url.standardizedFileURL.path,
              !FolderScope.contains(url, in: [FileMintStorage.directory.resolvingSymlinksInPath()]) else {
            throw FileMoveError.invalidDestination
        }
    }

    public func validate(_ entry: FileDrawerEntry) throws {
        try validate()
        guard entry.parentIdentity == handle.identity,
              entry.url.deletingLastPathComponent().path == url.path,
              try BatchRenameIdentity.at(entry.name, in: handle.fd) == entry.identity else {
            throw FileMoveError.sourceChanged
        }
    }

    public func child(_ entry: FileDrawerEntry) throws -> FileDrawerDirectory {
        try validate(entry)
        guard entry.canEnterDirectory else {
            throw FileMoveError.invalidDestination
        }
        return try FileDrawerDirectory(parent: self, entry: entry)
    }

    public func child(named name: String, matching identity: BatchRenameIdentity? = nil) throws -> FileDrawerDirectory {
        try RenameNamePolicy.validateRestorationComponent(name)
        try validate()
        guard let entry = try readEntry(named: name, showHidden: true), identity == nil || entry.identity == identity else {
            throw FileMoveError.sourceChanged
        }
        return try child(entry)
    }

    public func list(showHidden: Bool = false) throws -> [FileDrawerEntry] {
        try validate()
        var result: [FileDrawerEntry] = []
        try Self.enumerate(handle.fd) { name in
            try Task.checkCancellation()
            if !showHidden && name.hasPrefix(".") { return }
            if let entry = try readEntry(named: name, showHidden: showHidden) { result.append(entry) }
        }
        try validate()
        return result
    }

    /// Refresh one visible row before consuming it. In particular, size and
    /// placeholder status can change without changing the file's identity.
    public func refreshed(_ entry: FileDrawerEntry) throws -> FileDrawerEntry {
        try validate(entry)
        guard let current = try readEntry(named: entry.name, showHidden: true),
              current.identity == entry.identity else { throw FileMoveError.sourceChanged }
        try validate(current)
        return current
    }

    private func readEntry(named name: String, showHidden: Bool) throws -> FileDrawerEntry? {
        var metadata = stat()
        guard fstatat(handle.fd, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0 else {
            if errno == ENOENT { return nil }
            throw renamePOSIXError()
        }
        let identity = BatchRenameIdentity(metadata)
        let item = url.appendingPathComponent(name, isDirectory: identity.isDirectory)
        let ordinary = identity.isRegular || identity.isDirectory
        let values = ordinary ? try? item.resourceValues(forKeys: [.isPackageKey, .isAliasFileKey,
            .isHiddenKey, .ubiquitousItemDownloadingStatusKey]) : nil
        if !showHidden && values?.isHidden == true { return nil }
        guard try BatchRenameIdentity.at(name, in: handle.fd) == identity else { return nil }
        return FileDrawerEntry(url: item, name: name, isDirectory: identity.isDirectory,
            isRegular: identity.isRegular, isPackage: values?.isPackage ?? ordinary,
            isLink: identity.kind == UInt16(S_IFLNK) || values?.isAliasFile == true,
            isOffline: metadata.st_flags & UInt32(SF_DATALESS) != 0 || values?.ubiquitousItemDownloadingStatus == .notDownloaded,
            size: identity.isRegular ? metadata.st_size : nil, modified: Date(timeIntervalSince1970:
                Double(metadata.st_mtimespec.tv_sec) + Double(metadata.st_mtimespec.tv_nsec) / 1e9),
            identity: identity, parentIdentity: handle.identity)
    }

    private static func enumerate(_ fd: Int32, body: (String) throws -> Void) throws {
        // Opening "." gets an independent stream position for each refresh.
        let independent = openat(fd, ".", O_RDONLY | O_CLOEXEC | O_DIRECTORY)
        guard independent >= 0 else { throw renamePOSIXError() }
        guard let stream = fdopendir(independent) else {
            let error = renamePOSIXError(); close(independent); throw error
        }
        defer { closedir(stream) }
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                if errno != 0 { throw renamePOSIXError() }
                return
            }
            let length = Int(entry.pointee.d_namlen)
            let name = withUnsafeBytes(of: &entry.pointee.d_name) {
                String(bytes: $0.prefix(length), encoding: .utf8)
            }
            guard let name else { throw CocoaError(.fileReadInapplicableStringEncoding) }
            if name != ".", name != ".." { try body(name) }
        }
    }

    private func validateNewName(_ name: String) throws {
        try RenameNamePolicy.validateRestorationComponent(name)
        guard name == FilenamePolicy.sanitizedFileName(name), name.utf8.count <= 255 else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
    }

    @discardableResult public func createFolder(named name: String) throws -> URL {
        try validateNewName(name)
        try validate()
        guard mkdirat(handle.fd, name, 0o777) == 0 else { throw renamePOSIXError() }
        return url.appendingPathComponent(name, isDirectory: true)
    }

    private func validateAction(_ entry: FileDrawerEntry) throws {
        try validate(entry)
        let store = FileMintStorage.directory.resolvingSymlinksInPath()
        guard (entry.isRegular || entry.isDirectory), !entry.isLink,
              !FolderScope.contains(entry.url, in: [store]),
              !(entry.isDirectory && FolderScope.contains(store, in: [entry.url])) else { throw FileInfoError.unsupported }
    }

    @discardableResult public func rename(_ entry: FileDrawerEntry, to name: String) throws -> URL {
        try validateNewName(name)
        try validateAction(entry)
        let target = url.appendingPathComponent(name, isDirectory: entry.isDirectory)
        if entry.name.utf8.elementsEqual(name.utf8) { return target }
        try moveEntry(entry, into: self, named: name)
        return target
    }

    private func moveEntry(_ entry: FileDrawerEntry, into destination: FileDrawerDirectory, named name: String) throws {
        let target = destination.url.appendingPathComponent(name, isDirectory: entry.isDirectory)
        try Self.coordinated(entry.url, options: .forMoving, target: target) {
            try self.validateAction(entry)
            try destination.validate()
            try renameExclusive(from: entry.name, in: self.handle.fd, to: name, in: destination.handle.fd)
        }
    }

    /// Run on the complete selection before performing the first mutation.
    public func validateTransfer(_ entries: [FileDrawerEntry], to destination: FileDrawerDirectory, move: Bool) throws {
        try destination.validate()
        for entry in entries {
            try validateAction(entry)
            if move && (entry.identity.device != destination.identity.device || handle.identity.device != destination.identity.device) {
                throw FileDrawerTransferError.crossVolumeMove
            }
            if entry.isDirectory {
                // Identity checks catch case-insensitive spellings and volume aliases.
                var ancestor = destination.url
                while true {
                    if try BatchRenameIdentity.path(ancestor) == entry.identity { throw FileMoveError.invalidDestination }
                    if ancestor.path == "/" { break }
                    ancestor.deleteLastPathComponent()
                }
            }
            if handle.identity == destination.identity {
                if move { throw FileMoveError.invalidDestination }
            } else if try BatchRenameIdentity.at(entry.name, in: destination.handle.fd) != nil {
                throw FileMoveError.destinationExists
            }
            if !move && entry.isOffline { throw FileInfoError.placeholder }
        }
    }

    public func transfer(_ entry: FileDrawerEntry, to destination: FileDrawerDirectory, move: Bool) throws {
        try validateTransfer([entry], to: destination, move: move)
        if move {
            try moveEntry(entry, into: destination, named: entry.name)
            return
        }
        let stage = try destination.makeStage()
        defer { destination.removeEmptyStage(stage) }
        do {
            try Self.copyEntry(entry.name, from: handle.fd, to: stage.fd, expected: entry.identity)
            try validate(entry)
            try destination.validate()
            if handle.identity == destination.identity {
                var index = 2
                while true {
                    let name = entry.isDirectory ? entry.name + " " + String(index)
                        : FilenamePolicy.candidateURL(for: entry.url, index: index).lastPathComponent
                    do {
                        try renameExclusive(from: entry.name, in: stage.fd, to: name, in: destination.handle.fd)
                        break
                    } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == Int(EEXIST) {
                        index += 1
                    }
                }
            } else {
                try renameExclusive(from: entry.name, in: stage.fd, to: entry.name, in: destination.handle.fd)
            }
        } catch {
            // The staging FD still names our private directory if a parent
            // moved. Never follow a substituted path during failure cleanup.
            try? Self.discardUnpublishedCopy(entry.name, in: stage.fd)
            throw error
        }
    }

    private static func discardUnpublishedCopy(_ name: String, in parent: Int32) throws {
        guard let captured = try BatchRenameIdentity.at(name, in: parent) else { return }
        if captured.isDirectory {
            let fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard fd >= 0 else { throw renamePOSIXError() }
            defer { close(fd) }
            guard try BatchRenameIdentity.descriptor(fd) == captured else { throw FileMoveError.sourceChanged }
            try enumerate(fd) { child in try discardUnpublishedCopy(child, in: fd) }
        }
        guard try BatchRenameIdentity.at(name, in: parent) == captured else { throw FileMoveError.sourceChanged }
        guard unlinkat(parent, name, captured.isDirectory ? AT_REMOVEDIR : 0) == 0 else { throw renamePOSIXError() }
    }

    /// FDs pin the actual input and output at each level. Recursion happens
    /// only for an explicit directory copy. Special nodes and links never open.
    private static func copyEntry(_ name: String, from source: Int32, to target: Int32, expected: BatchRenameIdentity) throws {
        guard expected.isRegular || expected.isDirectory else { throw FileInfoError.unsupported }
        try Task.checkCancellation()
        let input = openat(source, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK | (expected.isDirectory ? O_DIRECTORY : 0))
        guard input >= 0 else { throw renamePOSIXError() }
        defer { close(input) }
        var before = stat()
        guard fstat(input, &before) == 0 else { throw renamePOSIXError() }
        guard BatchRenameIdentity(before) == expected else { throw FileMoveError.sourceChanged }
        guard before.st_flags & UInt32(SF_DATALESS) == 0 else { throw FileInfoError.placeholder }
        let output: Int32
        if expected.isDirectory {
            guard mkdirat(target, name, 0o700) == 0 else { throw renamePOSIXError() }
            output = openat(target, name, O_RDONLY | O_CLOEXEC | O_DIRECTORY | O_NOFOLLOW)
        } else {
            output = openat(target, name, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        }
        guard output >= 0 else { throw renamePOSIXError() }
        defer { close(output) }
        if expected.isDirectory {
            try enumerate(input) { child in
                guard let id = try BatchRenameIdentity.at(child, in: input) else { throw FileMoveError.sourceChanged }
                try copyEntry(child, from: input, to: output, expected: id)
            }
        }
        let flags = copyfile_flags_t(expected.isDirectory ? COPYFILE_METADATA : COPYFILE_ALL)
        guard fcopyfile(input, output, nil, flags) == 0 else { throw renamePOSIXError() }
        var after = stat()
        guard fstat(input, &after) == 0, FileInfoStamp(before) == FileInfoStamp(after),
              try BatchRenameIdentity.at(name, in: source) == expected else { throw FileMoveError.sourceChanged }
    }

    public func trash(_ entry: FileDrawerEntry) throws -> FileDrawerTrashReceipt? {
        try trash(entry) { source in
            var result: NSURL?
            try FileManager.default.trashItem(at: source, resultingItemURL: &result)
            return result as URL?
        }
    }

    func trash(_ entry: FileDrawerEntry, recycle: (URL) throws -> URL?) throws -> FileDrawerTrashReceipt? {
        try validateAction(entry)
        return try Self.coordinated(entry.url, options: .forDeleting) {
            try self.validateAction(entry)
            // Finder's Put Back records the URL passed to the system. Preserve
            // that original location even when a session receipt isn't available.
            guard let trashURL = try recycle(entry.url),
                  (try? BatchRenameIdentity.path(trashURL)) == entry.identity else { return nil }
            return FileDrawerTrashReceipt(originalURL: entry.url, directory: self, trashed: trashURL, identity: entry.identity)
        }
    }

    public func restore(_ receipt: FileDrawerTrashReceipt) throws {
        guard receipt.directory === self else { throw FileMoveError.invalidDestination }
        let trashParent = try RenameDirectory(receipt.trashed.deletingLastPathComponent())
        let name = receipt.trashed.lastPathComponent
        try Self.coordinated(receipt.trashed, options: .forMoving, target: receipt.originalURL) {
            try self.validate()
            try trashParent.validatePath()
            guard try BatchRenameIdentity.at(name, in: trashParent.fd) == receipt.identity else {
                throw FileMoveError.sourceChanged
            }
            try renameExclusive(from: name, in: trashParent.fd, to: receipt.originalURL.lastPathComponent, in: self.handle.fd)
        }
    }

    private static func coordinated<T>(_ source: URL, options: NSFileCoordinator.WritingOptions,
                                       target: URL? = nil, _ action: () throws -> T) throws -> T {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var error: NSError?
        var result: Result<T, Error>?
        if let target {
            coordinator.coordinate(writingItemAt: source, options: options, writingItemAt: target, options: [], error: &error) { src, dst in
                result = Result {
                    guard src.standardizedFileURL.path == source.standardizedFileURL.path,
                          dst.standardizedFileURL.path == target.standardizedFileURL.path else { throw FileMoveError.sourceChanged }
                    let value = try action()
                    coordinator.item(at: src, didMoveTo: dst)
                    return value
                }
            }
        } else {
            coordinator.coordinate(writingItemAt: source, options: options, error: &error) { src in
                result = Result {
                    guard src.standardizedFileURL.path == source.standardizedFileURL.path else { throw FileMoveError.sourceChanged }
                    return try action()
                }
            }
        }
        if let result { return try result.get() }
        throw error ?? CocoaError(.fileWriteUnknown) as NSError
    }

    private func makeStage() throws -> RenameDirectory {
        try validate()
        let name = ".FileMint-drawer-" + UUID().uuidString
        guard mkdirat(handle.fd, name, 0o700) == 0 else { throw renamePOSIXError() }
        guard let id = try BatchRenameIdentity.at(name, in: handle.fd) else { throw FileMoveError.sourceChanged }
        do { return try RenameDirectory(parent: handle, component: name, expected: id) }
        catch {
            if (try? BatchRenameIdentity.at(name, in: handle.fd)) == id { _ = unlinkat(handle.fd, name, AT_REMOVEDIR) }
            throw error
        }
    }

    private func removeEmptyStage(_ stage: RenameDirectory) {
        let name = stage.url.lastPathComponent
        if (try? BatchRenameIdentity.at(name, in: handle.fd)) == stage.identity {
            _ = unlinkat(handle.fd, name, AT_REMOVEDIR)
        }
    }
}

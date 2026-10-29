import Darwin
import Foundation

public enum FileVisibilityAction: String, Codable, CaseIterable, Sendable {
    case hide, unhide
    public var isHidden: Bool { self == .hide }
    public func title(selectionCount: Int) -> FileMintTextKey {
        switch (self, selectionCount == 1) {
        case (.hide, true): .hideItem
        case (.hide, false): .hideSelectedItems
        case (.unhide, true): .unhideItem
        case (.unhide, false): .unhideSelectedItems
        }
    }
}

public enum FileVisibilityError: Error, Equatable, Sendable {
    case invalidSelection, changed, unsupported, nameHidden, otherHiddenMechanism, disabled
    public var messageKey: FileMintTextKey {
        switch self {
        case .invalidSelection, .unsupported: .fileVisibilityUnsupported
        case .changed: .moveSourceChanged
        case .nameHidden: .fileVisibilityNameHidden
        case .otherHiddenMechanism: .fileVisibilityOtherHidden
        case .disabled: .moveDisabled
        }
    }
}

public struct FileVisibilityFailure: Error {
    public let processed: Int
    public let total: Int
    public let underlying: any Error
}

public enum FileVisibilityPolicy {
    public static let maximumItemCount = 1_000
    public static func canSelect(_ urls: [URL]) -> Bool {
        (1...maximumItemCount).contains(urls.count)
            && urls.allSatisfy { FileInfoPolicy.canSelect([$0]) }
            && Set(urls.map { $0.standardizedFileURL.path }).count == urls.count
    }

    public static func isEnabled(for urls: [URL], preferences: FileMintPreferences) -> Bool {
        preferences.fileTools.allows(.fileVisibility) && canSelect(urls)
            && urls.allSatisfy { FolderScope.contains($0, in: preferences.monitoredFolderURLs) }
    }

    /// The requested state is explicit, never a per-item toggle. Mixed or
    /// unavailable metadata must not guess which state the user wants.
    public static func actions(hiddenStates: [Bool?]) -> [FileVisibilityAction] {
        guard !hiddenStates.isEmpty else { return [] }
        if hiddenStates.allSatisfy({ $0 == false }) { return [.hide] }
        if hiddenStates.allSatisfy({ $0 == true }) { return [.unhide] }
        return [.hide, .unhide]
    }
}

public enum FileVisibilityService {
    public static func supportsMenuSelection(_ urls: [URL]) -> Bool {
        FileVisibilityPolicy.canSelect(urls) && urls.allSatisfy {
            guard let info = try? visibilityStat($0) else { return false }
            return visibilityKindIsSupported(info)
        }
    }

    /// Fresh metadata only: never open contents, follow a selected link or
    /// enumerate a selected directory, including packages and aliases.
    public static func menuActions(for urls: [URL]) -> [FileVisibilityAction] {
        guard supportsMenuSelection(urls) else { return [] }
        return FileVisibilityPolicy.actions(hiddenStates: urls.map {
            let url = $0
            return try? visibilityHiddenState(url, finderInfo: visibilityFinderInfo { buffer in
                getxattr(url.path, "com.apple.FinderInfo", buffer.baseAddress, buffer.count, 0, XATTR_NOFOLLOW)
            })
        })
    }

    public static func capture(_ urls: [URL]) throws -> [FileInfoSelection] {
        guard FileVisibilityPolicy.canSelect(urls) else { throw FileVisibilityError.invalidSelection }
        let items = try urls.map { try FileInfoSelection.capture([$0]) }
        try validate(items)
        return items
    }

    private static func validate(_ items: [FileInfoSelection]) throws {
        guard FileVisibilityPolicy.canSelect(items.map(\.source)),
              Set(items.map { "\($0.identity.device):\($0.identity.inode)" }).count == items.count else {
            throw FileVisibilityError.invalidSelection
        }
        for item in items {
            do { try item.validate() }
            catch { throw FileVisibilityError.changed }
            guard visibilityKindIsSupported(try visibilityStat(item.resolvedSource)) else {
                throw FileVisibilityError.unsupported
            }
        }
    }

    /// Call on a worker after write authorization. O_EVTONLY pins the exact
    /// selected objects; this path uses metadata APIs only. O_EVTONLY still
    /// requires read permission and is not a byte-read security boundary.
    @discardableResult
    public static func perform(_ items: [FileInfoSelection], action: FileVisibilityAction,
                               canContinue: @Sendable (URL) -> Bool = { _ in true }) throws -> Int {
        try validate(items)
        guard items.allSatisfy({ canContinue($0.source) }) else { throw FileVisibilityError.disabled }
        if action == .unhide && items.contains(where: { $0.source.lastPathComponent.hasPrefix(".") }) {
            throw FileVisibilityError.nameHidden
        }
        // Preflight the entire batch before the first mutation. Holding all
        // handles also prevents a replaced pathname from redirecting a write.
        let handles = try items.map(FileVisibilityHandle.init)
        if action == .unhide {
            for handle in handles {
                let info = try handle.stat()
                let legacyInvisible = try handle.finderInfo().map { $0[8] & 0x40 != 0 } ?? false
                let hidden = try? URL(fileURLWithPath: handle.item.resolvedSource.path)
                    .resourceValues(forKeys: [.isHiddenKey]).isHidden
                if hidden == true && info.st_flags & UInt32(UF_HIDDEN) == 0 && !legacyInvisible {
                    throw FileVisibilityError.otherHiddenMechanism
                }
            }
        }
        var processed = 0
        do {
            for handle in handles {
                guard !Task<Never, Never>.isCancelled, canContinue(handle.item.source) else {
                    throw FileVisibilityError.disabled
                }
                try handle.validate()
                let before = try handle.stat()
                let finderInfo = try handle.finderInfo()
                var counted = false
                let flags = action.isHidden ? before.st_flags | UInt32(UF_HIDDEN) : before.st_flags & ~UInt32(UF_HIDDEN)
                if flags != before.st_flags && !handle.item.source.lastPathComponent.hasPrefix(".") {
                    guard fchflags(handle.fd, flags) == 0 else { throw visibilityPOSIXError() }
                    processed += 1; counted = true
                }
                if action == .unhide, var info = finderInfo, info[8] & 0x40 != 0 {
                    info[8] &= ~0x40
                    let result = info.withUnsafeBytes {
                        fsetxattr(handle.fd, "com.apple.FinderInfo", $0.baseAddress, $0.count, 0, 0)
                    }
                    guard result == 0 else { throw visibilityPOSIXError() }
                    if !counted { processed += 1; counted = true }
                }
                if !counted { processed += 1 }
                try handle.validate()
                let after = try handle.stat()
                guard handle.item.source.lastPathComponent.hasPrefix(".") ||
                        (after.st_flags & UInt32(UF_HIDDEN) != 0) == action.isHidden else {
                    throw FileVisibilityError.changed
                }
                let effective = try visibilityHiddenState(handle.item.resolvedSource, finderInfo: handle.finderInfo())
                if let effective, effective != action.isHidden { throw FileVisibilityError.changed }
            }
        } catch {
            if processed > 0 { throw FileVisibilityFailure(processed: processed, total: items.count, underlying: error) }
            throw error
        }
        return processed
    }
}

private final class FileVisibilityHandle {
    let item: FileInfoSelection
    let fd: Int32
    private let parent: Int32

    init(_ item: FileInfoSelection) throws {
        let parent = open(item.parent.path, O_EVTONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw visibilityPOSIXError() }
        let fd = openat(parent, item.source.lastPathComponent, O_EVTONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { close(parent); throw visibilityPOSIXError() }
        self.item = item; self.fd = fd; self.parent = parent
        // The instance owns both descriptors before any fallible validation.
        try validate()
    }

    deinit { close(fd); close(parent) }

    func stat() throws -> Darwin.stat {
        var info = Darwin.stat()
        guard fstat(fd, &info) == 0 else { throw visibilityPOSIXError() }
        return info
    }

    func finderInfo() throws -> [UInt8]? {
        try visibilityFinderInfo { buffer in
            fgetxattr(fd, "com.apple.FinderInfo", buffer.baseAddress, buffer.count, 0, 0)
        }
    }

    func validate() throws {
        do { try item.validate() }
        catch { throw FileVisibilityError.changed }
        var parentInfo = Darwin.stat()
        guard fstat(parent, &parentInfo) == 0,
              FileInfoIdentity(parentInfo) == item.parentIdentity,
              FileInfoIdentity(try stat()) == item.identity else { throw FileVisibilityError.changed }
    }
}

private func visibilityStat(_ url: URL) throws -> stat {
    var info = stat()
    guard lstat(url.path, &info) == 0 else { throw visibilityPOSIXError() }
    return info
}
private func visibilityKindIsSupported(_ info: stat) -> Bool {
    let kind = info.st_mode & UInt16(S_IFMT)
    return kind == UInt16(S_IFREG) || kind == UInt16(S_IFDIR)
}
private func visibilityPOSIXError() -> NSError { NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }

/// Finder's classic invisible bit is independent of UF_HIDDEN and is not
/// reliably reflected by Foundation's isHidden value. Preserve all other bytes.
private func visibilityFinderInfo(_ fetch: (UnsafeMutableRawBufferPointer) -> Int) throws -> [UInt8]? {
    var bytes = [UInt8](repeating: 0, count: 32)
    let count = bytes.withUnsafeMutableBytes(fetch)
    if count < 0 {
        if errno == ENOATTR || errno == ENOTSUP { return nil }
        throw visibilityPOSIXError()
    }
    guard count == 32 else { throw FileVisibilityError.otherHiddenMechanism }
    return bytes
}

private func visibilityHiddenState(_ url: URL, finderInfo: [UInt8]?) throws -> Bool? {
    if let finderInfo, finderInfo[8] & 0x40 != 0 { return true }
    return try URL(fileURLWithPath: url.path).resourceValues(forKeys: [.isHiddenKey]).isHidden
}

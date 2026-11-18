import Foundation
import Darwin
import CryptoKit

/// The app holds the operation coordinator throughout. Only known locations of
/// the current item are recorded. An explicit retry revalidates them after access.
struct FileMoveProgress: Codable, Equatable, Sendable {
    let destination: URL
    let destinationIdentity: FileInfoIdentity
    var sourceStage: FileMoveItem
    var copyStage: FileMoveItem?
    var copy: FileMoveItem?
    var sourceFingerprint: Data?
    var outputFingerprint: Data?
    var originalRestored = false
    enum SourceTransition: String, Codable { case restoring, retiring }
    var sourceTransition: SourceTransition?
}

enum FileMoveStep { case claimed, copied, published, retired }
struct InterruptedFileMove: Error {}

public struct FileMoveService: Sendable {
    // Deterministic checkpoints for real isolated filesystem tests.
    var checkpoint: (@Sendable (FileMoveStep) throws -> Void)?
    var forceCopy = false
    var retire: @Sendable (URL) throws -> Void = { source in
        try FileManager.default.trashItem(at: source, resultingItemURL: nil)
    }
    public init() {}

    public func perform(batchID: UUID, to directory: URL, store: PendingFileMoveStore,
                        canContinue: @Sendable (PendingFileMove) -> Bool) throws {
        try performChecked(batchID: batchID, to: directory, store: store) { pending, _ in canContinue(pending) }
    }

    public func performPerItem(batchID: UUID, to directory: URL, store: PendingFileMoveStore,
                               canContinue: @Sendable (FileMoveItem) -> Bool) throws {
        try performChecked(batchID: batchID, to: directory, store: store) { _, item in canContinue(item) }
    }

    private func performChecked(batchID: UUID, to directory: URL, store: PendingFileMoveStore,
                                canContinue: (PendingFileMove, FileMoveItem) -> Bool) throws {
        guard var pending = try store.load(), pending.id == batchID else { throw FileMoveError.staleRequest }
        try FileMovePolicy.validateDestination(directory, items: pending.items)
        while let item = pending.items.first {
            let current = pending
            guard canContinue(current, item) else { throw FileMoveError.disabled }
            guard try store.load()?.id == pending.id else { throw FileMoveError.staleRequest }
            try transact(item, directory: directory, previous: pending.progress, forceCopy: forceCopy,
                         allowed: { canContinue(current, item) }) { progress in
                pending.progress = progress
                try store.save(pending)
            }
            // Keep the evidence until the same atomic write also advances the batch.
            pending.progress = nil
            pending.items.removeFirst()
            pending.id = UUID()
            try store.save(pending.items.isEmpty ? nil : pending)
        }
    }

    public func move(item: FileMoveItem, to directory: URL) throws {
        try move(item: item, to: directory, forceCopy: false)
    }

    func move(item: FileMoveItem, to directory: URL, forceCopy: Bool) throws {
        try FileMovePolicy.validateDestination(directory, items: [item])
        try transact(item, directory: directory, previous: nil, forceCopy: forceCopy, allowed: { true }) { _ in }
    }

    private func transact(_ item: FileMoveItem, directory: URL, previous: FileMoveProgress?, forceCopy: Bool,
                          allowed: () -> Bool, save: (FileMoveProgress?) throws -> Void) throws {
        let destination = directory.resolvingSymlinksInPath().standardizedFileURL
        let target = destination.appendingPathComponent(item.source.lastPathComponent)
        let values = try destination.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard values.isDirectory == true, values.isPackage != true else { throw FileMoveError.invalidDestination }
        let identity = FileInfoIdentity(try fileInfoStat(destination))
        if let previous {
            guard item.source.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == item.canonicalParent,
                  previous.sourceStage.canonicalParent == item.canonicalParent,
                  previous.sourceStage.source.deletingLastPathComponent().standardizedFileURL.path == item.source.deletingLastPathComponent().standardizedFileURL.path,
                  previous.sourceStage.isDirectory,
                  previous.sourceStage.source.lastPathComponent.hasPrefix(".FileMint-operation-") else {
                throw FileMoveError.sourceChanged
            }
            guard previous.destination.path == destination.path else { throw FileMoveError.retryDestination(previous.destination) }
            guard previous.destinationIdentity == identity else { throw FileMoveError.invalidDestination }
            if let stage = try FileMoveItem.ifPresent(previous.sourceStage.source), stage != previous.sourceStage {
                throw FileMoveError.recoveryRequired(previous.sourceStage.source)
            }
            if let copy = previous.copy {
                guard let folder = previous.copyStage,
                      copy.source.path == folder.source.appendingPathComponent("item").path,
                      folder.source.deletingLastPathComponent().standardizedFileURL.path == destination.path,
                      folder.source.lastPathComponent.hasPrefix(".FileMint-move-") else {
                    throw FileMoveError.invalidDestination
                }
            }
        }
        // Reconcile a published object before looking for a source: the source
        // can legitimately be absent after publication or retirement.
        let output = try FileMoveItem.ifPresent(target)
        if previous == nil, output != nil { throw FileMoveError.destinationExists }
        if let previous {
            let published = (previous.copy ?? item).sameObject(as: output)
            let staged = previous.sourceStage.source.appendingPathComponent(item.source.lastPathComponent)
            let stagedEntry = try FileMoveItem.ifPresent(staged)
            let original = try FileMoveItem.ifPresent(item.source)
            if let stagedEntry, !item.sameObject(as: stagedEntry) { throw FileMoveError.recoveryRequired(staged) }
            if item.sameObject(as: original), stagedEntry != nil { throw FileMoveError.recoveryRequired(staged) }
            if previous.sourceTransition == .restoring,
               (original == nil && stagedEntry != nil || item.sameObject(as: original) && stagedEntry == nil) {
                if stagedEntry != nil {
                    let claim = try StagedFileEntry.existing(item, directory: previous.sourceStage)
                    try restore(claim, destination: destination)
                }
                try cleanupSourceStage(previous.sourceStage, item: item)
                try cleanupCopyStage(previous, destination: destination)
                if previous.copy != nil && published {
                    var restored = previous
                    restored.originalRestored = true
                    restored.sourceTransition = nil
                    try save(restored)
                    throw FileMoveError.copiedSourceRetained
                }
                try save(nil)
                throw FileMoveError.sourceRestored
            }
            if published && !item.sameObject(as: original) && stagedEntry == nil {
                // A cross-volume output is a copy. Only a recorded retirement
                // can explain an absent original after the copy was published.
                guard previous.copy == nil || previous.sourceTransition == .retiring else {
                    throw FileMoveError.recoveryRequired(staged)
                }
                try cleanupSourceStage(previous.sourceStage, item: item)
                try cleanupCopyStage(previous, destination: destination)
                return
            }
            if !published, stagedEntry == nil, !item.sameObject(as: original) { throw FileMoveError.sourceChanged }
        }
        var progress: FileMoveProgress
        let claim: StagedFileEntry
        if let previous, try FileMoveItem.ifPresent(previous.sourceStage.source) != nil {
            claim = try StagedFileEntry.existing(item, directory: previous.sourceStage)
            progress = previous
        } else {
            try item.validateIdentity()
            claim = try StagedFileEntry.prepare(item, component: item.source.lastPathComponent)
            let stage = try FileMoveItem.capture(claim.stagingDirectory)
            progress = previous ?? FileMoveProgress(destination: destination, destinationIdentity: identity, sourceStage: stage)
            progress.sourceStage = stage
            do { try save(progress) }
            catch { claim.cleanup(); throw error }
        }

        var publishedCopy = progress.copy?.sameObject(as: output) == true
        do {
            if try FileMoveItem.ifPresent(claim.staged) == nil {
                try item.validateIdentity()
                progress.originalRestored = false
                try save(progress)
                try claim.take(keepStageOnConflict: true)
                try checkpoint?(.claimed)
            }
            try claim.validateIdentity()
            try validateDestination(progress, allowed: allowed)
            if publishedCopy {
                guard try fingerprint(claim.staged) == progress.sourceFingerprint,
                      try fingerprint(target) == progress.outputFingerprint else { throw FileMoveError.copiedSourceRetained }
            } else {
                if output != nil { throw FileMoveError.destinationExists }
                if !forceCopy && progress.copyStage == nil {
                    do {
                        try StagedFileEntry.renameExclusive(claim.staged, to: target)
                        try checkpoint?(.published)
                        claim.cleanup()
                        return
                    } catch let error as NSError where error.domain == NSPOSIXErrorDomain {
                        if error.code == EEXIST { throw FileMoveError.destinationExists }
                        if error.code != EXDEV && error.code != ENOTSUP { throw error }
                    }
                }
                // Leave an unidentifiable partial copy in place after an interruption.
                try cleanupCopyStage(progress, destination: destination)
                let copyFolder = try makeCopyStage(in: destination)
                progress.copyStage = copyFolder
                progress.copy = nil
                try save(progress)
                let candidate = copyFolder.source.appendingPathComponent("item")
                let before = try fingerprint(claim.staged)
                let beforeRoot = FileInfoStamp(try fileInfoStat(claim.staged))
                try FileManager.default.copyItem(at: claim.staged, to: candidate)
                progress.copy = try FileMoveItem.capture(candidate)
                progress.outputFingerprint = try fingerprint(candidate)
                try checkpoint?(.copied)
                guard try fingerprint(claim.staged) == before,
                      try FileInfoStamp(fileInfoStat(claim.staged)) == beforeRoot else { throw FileMoveError.sourceChanged }
                progress.sourceFingerprint = before
                try save(progress)
                try claim.validateIdentity()
                try validateDestination(progress, allowed: allowed)
                do { try StagedFileEntry.renameExclusive(candidate, to: target) }
                catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == EEXIST {
                    throw FileMoveError.destinationExists
                }
                publishedCopy = true
                try checkpoint?(.published)
            }
            try cleanupCopyStage(progress, destination: destination)
            try claim.validateIdentity()
            try validateDestination(progress, allowed: allowed)
            guard try fingerprint(claim.staged) == progress.sourceFingerprint,
                  progress.copy?.sameObject(as: try FileMoveItem.ifPresent(target)) == true,
                  try fingerprint(target) == progress.outputFingerprint else { throw FileMoveError.copiedSourceRetained }
            progress.sourceTransition = .retiring
            try save(progress)
            do { try retire(claim.staged) }
            catch { throw FileMoveError.copiedSourceRetained }
            try checkpoint?(.retired)
            claim.cleanup()
        } catch is InterruptedFileMove {
            throw InterruptedFileMove()
        } catch {
            // Keep both complete objects on a partial publication. A retry can
            // retire the unchanged original without copying over the published one.
            if let staged = try FileMoveItem.ifPresent(claim.staged) {
                guard item.sameObject(as: staged) else { throw FileMoveError.recoveryRequired(claim.staged) }
                progress.sourceTransition = .restoring
                try save(progress)
                try restore(claim, destination: destination)
                progress.sourceTransition = nil
            }
            claim.cleanup()
            try cleanupCopyStage(progress, destination: destination)
            if publishedCopy {
                progress.originalRestored = item.sameObject(as: try FileMoveItem.ifPresent(item.source))
                try save(progress)
                throw FileMoveError.copiedSourceRetained
            }
            try save(nil)
            throw error
        }
    }

    private func restore(_ claim: StagedFileEntry, destination: URL) throws {
        do { try claim.restore(keepStageOnConflict: true) }
        catch {
            throw FileMoveError.restoreBlocked(staged: claim.staged, destination: destination)
        }
    }

    private func validateDestination(_ progress: FileMoveProgress, allowed: () -> Bool) throws {
        guard allowed() else { throw FileMoveError.disabled }
        guard try FileInfoIdentity(fileInfoStat(progress.destination)) == progress.destinationIdentity else {
            throw FileMoveError.invalidDestination
        }
    }

    private func cleanupSourceStage(_ stage: FileMoveItem, item: FileMoveItem) throws {
        if try FileMoveItem.ifPresent(stage.source) != nil { try StagedFileEntry.existing(item, directory: stage).cleanup() }
    }

    private func makeCopyStage(in directory: URL) throws -> FileMoveItem {
        var pattern = Array(directory.appendingPathComponent(".FileMint-move-XXXXXX").path.utf8CString)
        guard mkdtemp(&pattern) != nil else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let path = String(decoding: pattern.dropLast().map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return try FileMoveItem.capture(URL(fileURLWithPath: path, isDirectory: true))
    }

    private func cleanupCopyStage(_ progress: FileMoveProgress, destination: URL) throws {
        guard let folder = progress.copyStage else { return }
        guard folder.source.deletingLastPathComponent().standardizedFileURL.path == destination.path,
              folder.source.lastPathComponent.hasPrefix(".FileMint-move-"), folder.isDirectory else {
            throw FileMoveError.invalidDestination
        }
        guard let current = try FileMoveItem.ifPresent(folder.source) else { return }
        guard folder == current else { return }
        let candidate = folder.source.appendingPathComponent("item")
        if let item = try FileMoveItem.ifPresent(candidate) {
            guard let recorded = progress.copy, recorded.sameObject(as: item),
                  let expected = progress.outputFingerprint, try fingerprint(candidate) == expected else { return }
            try FileManager.default.removeItem(at: candidate)
        }
        if rmdir(folder.source.path) != 0, errno != ENOTEMPTY && errno != EEXIST { throw FileMoveError.recoveryRequired(folder.source) }
    }

    /// Inspect only the selected cross-volume subtree. Sorting bytewise makes the
    /// compact fingerprint deterministic. Links are entries and never traversed.
    private func fingerprint(_ root: URL) throws -> Data {
        var digest = SHA256()
        func visit(parent: Int32, name component: String, relative: String) throws {
            var info = stat()
            guard fstatat(parent, component, &info, AT_SYMLINK_NOFOLLOW) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            let name = Data(relative.utf8)
            // Root ctime changes during our exclusive renames. Children retain
            // ctime; a regular file's size/mtime and identity follow its name.
            let times = [Int64(info.st_mtimespec.tv_sec), Int64(info.st_mtimespec.tv_nsec),
                         relative.isEmpty ? 0 : Int64(info.st_ctimespec.tv_sec),
                         relative.isEmpty ? 0 : Int64(info.st_ctimespec.tv_nsec)]
            let fields = [UInt64(name.count), UInt64(bitPattern: Int64(info.st_dev)), info.st_ino,
                          UInt64(info.st_gen), UInt64(info.st_mode), UInt64(info.st_flags),
                          UInt64(bitPattern: info.st_size)] + times.map { UInt64(bitPattern: $0) }
            for field in fields {
                var bytes = field.bigEndian
                withUnsafeBytes(of: &bytes) { digest.update(bufferPointer: $0) }
            }
            digest.update(data: name)
            if info.st_mode & S_IFMT == S_IFDIR {
                let fd = openat(parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
                guard let stream = fdopendir(fd) else {
                    let error = NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                    close(fd)
                    throw error
                }
                defer { closedir(stream) }
                var opened = stat()
                guard fstat(fd, &opened) == 0, FileInfoIdentity(opened) == FileInfoIdentity(info) else {
                    throw FileMoveError.sourceChanged
                }
                var children: [String] = []
                while true {
                    errno = 0
                    guard let entry = readdir(stream) else {
                        if errno != 0 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
                        break
                    }
                    let child = withUnsafeBytes(of: entry.pointee.d_name) { bytes in
                        String(bytes: bytes.prefix(Int(entry.pointee.d_namlen)), encoding: .utf8)
                    }
                    guard let child else { throw FileMoveError.sourceChanged }
                    if child != "." && child != ".." { children.append(child) }
                }
                for child in children.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
                    try visit(parent: fd, name: child, relative: relative + "/" + child)
                }
            }
        }
        try visit(parent: AT_FDCWD, name: root.path, relative: "")
        return Data(digest.finalize())
    }
}

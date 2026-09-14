import Foundation

public enum FileMenuDestination {
    /// Container menus already identify a directory; they need no filesystem
    /// probe, which can fail inside the Finder extension's sandbox.
    public static func directory(
        target: URL?, isContainer: Bool, targetIsDirectory: Bool,
        monitoredFolders: [URL]
    ) -> URL? {
        guard let target, target.isFileURL else { return nil }
        let directory = isContainer || targetIsDirectory ? target : target.deletingLastPathComponent()
        return FolderScope.contains(directory, in: monitoredFolders) ? directory : nil
    }
}

public struct FileMenuAction: Equatable, Sendable {
    public let directory: URL
    public let templateID: String?
    public init(directory: URL, templateID: String?) {
        self.directory = directory
        self.templateID = templateID
    }
}

/// Finder serializes tags, but does not preserve representedObject. Retain a
/// bounded set of immutable menu snapshots keyed by unique tags.
public struct FileMenuActionRegistry: Sendable {
    private var nextTag = 1
    private var entries: [Int: FileMenuAction] = [:]
    private var menus: [[Int]] = []
    private let capacity: Int

    public init(retainingMenus: Int = 32) { capacity = max(1, retainingMenus) }

    public mutating func register(_ actions: [FileMenuAction]) -> [Int] {
        guard !actions.isEmpty else { return [] }
        if nextTag > Int.max - actions.count { nextTag = 1; entries.removeAll(); menus.removeAll() }
        let tags = actions.map { action in
            let tag = nextTag
            nextTag += 1
            entries[tag] = action
            return tag
        }
        menus.append(tags)
        while menus.count > capacity {
            for tag in menus.removeFirst() { entries.removeValue(forKey: tag) }
        }
        return tags
    }

    public mutating func takeAction(for tag: Int) -> FileMenuAction? {
        entries.removeValue(forKey: tag)
    }
}

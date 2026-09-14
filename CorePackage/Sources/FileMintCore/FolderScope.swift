import Foundation

public enum FolderScope {
    public static func contains(_ directory: URL, in folders: [URL]) -> Bool {
        guard directory.isFileURL else { return false }
        let target = directory.standardizedFileURL.path
        return folders.contains {
            guard $0.isFileURL else { return false }
            let root = $0.standardizedFileURL.path
            return target == root || target.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }

    /// Finder may omit callbacks for protected folders registered alone.
    /// Observation ancestors do not expand menu scope or grant file access.
    public static func observationRoots(for folders: [URL], home: URL) -> Set<URL> {
        var roots = Set(folders.filter(\.isFileURL))
        let protectedFolders = ["Desktop", "Documents"].map {
            home.appendingPathComponent($0, isDirectory: true)
        }
        if home.isFileURL && folders.contains(where: { contains($0, in: protectedFolders) }) {
            roots.insert(home)
        }
        return roots
    }
}

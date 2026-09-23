import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

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

    /// Used by the writer after authorization. Finder's menu callback keeps the
    /// path-only check above because filesystem probes can fail in its sandbox.
    public static func containsResolvedDirectory(_ directory: URL, in folders: [URL]) -> Bool {
        guard let target = resolvedPath(directory) else { return false }
        return resolvedRoots(folders).contains { containsPath(target, in: $0) }
    }

    /// A selected symlink is an entry in its parent, not its target. Resolve only
    /// the parent so removing or moving the link itself remains in scope.
    public static func containsResolvedItem(_ item: URL, in folders: [URL]) -> Bool {
        guard item.isFileURL, item.standardizedFileURL.path != "/",
              let parent = resolvedPath(item.deletingLastPathComponent()),
              !item.lastPathComponent.contains("/") else { return false }
        let target = (parent == "/" ? "" : parent) + "/" + item.lastPathComponent
        return resolvedRoots(folders).contains { containsPath(target, in: $0) }
    }

    private static func resolvedRoots(_ folders: [URL]) -> [String] {
        folders.compactMap(resolvedPath)
    }

    private static func containsPath(_ target: String, in root: String) -> Bool {
        target == root || target.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    private static func resolvedPath(_ url: URL) -> String? {
        guard url.isFileURL else { return nil }
        return url.withUnsafeFileSystemRepresentation { path in
            guard let path, let resolved = realpath(path, nil) else { return nil }
            defer { free(resolved) }
            return String(cString: resolved)
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

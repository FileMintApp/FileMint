import AppKit
import Darwin
import FileMintCore

/// AppKit and security-scoped access stay outside the deterministic Core policy.
enum OpenWithApplicationAccess {
    static func capture(_ selectedURL: URL) throws -> OpenWithApplication {
        let started = selectedURL.startAccessingSecurityScopedResource()
        defer { if started { selectedURL.stopAccessingSecurityScopedResource() } }
        let url = selectedURL.resolvingSymlinksInPath().standardizedFileURL
        let identifier = try bundleIdentifier(at: url)
        let displayName = FileManager.default.displayName(atPath: url.path)
        let name = displayName.lowercased().hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
        let bookmark = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                            includingResourceValuesForKeys: nil, relativeTo: nil)
        return OpenWithApplication(name: name, bundleIdentifier: identifier, url: url, bookmark: bookmark)
    }

    static func resolve(_ application: OpenWithApplication) throws -> URL {
        var stale = false
        // A stale bookmark may still resolve a moved app. Identity is validated
        // after starting access; never fall back to a different registered copy.
        guard let url = try? URL(resolvingBookmarkData: application.bookmark,
            options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil,
            bookmarkDataIsStale: &stale), OpenWithPolicy.isLocalFileURL(url) else {
            throw OpenWithError.unavailableApplication
        }
        return url
    }

    static func validate(_ application: OpenWithApplication, at url: URL) throws {
        guard (try? bundleIdentifier(at: url)) == application.bundleIdentifier else {
            throw OpenWithError.unavailableApplication
        }
    }

    private static func bundleIdentifier(at url: URL) throws -> String {
        guard OpenWithPolicy.isLocalFileURL(url), url.pathExtension.lowercased() == "app",
              (try? url.resourceValues(forKeys: [.isApplicationKey]))?.isApplication == true,
              let data = try? readInfoPlist(at: url.appendingPathComponent("Contents/Info.plist")),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              info["CFBundlePackageType"] as? String == "APPL",
              let identifier = info["CFBundleIdentifier"] as? String, !identifier.isEmpty,
              let executable = info["CFBundleExecutable"] as? String, !executable.isEmpty,
              !executable.contains("/"), executable != ".", executable != "..",
              FileManager.default.isExecutableFile(atPath: url.appendingPathComponent("Contents/MacOS")
                .appendingPathComponent(executable).path) else { throw OpenWithError.invalidApplication }
        return identifier
    }

    private static func readInfoPlist(at url: URL) throws -> Data {
        let maximumBytes = 1_048_576
        var before = stat()
        guard url.withUnsafeFileSystemRepresentation({ path in path.map { lstat($0, &before) } ?? -1 }) == 0,
              before.st_mode & S_IFMT == S_IFREG, before.st_size > 0,
              before.st_size <= Int64(maximumBytes) else { throw OpenWithError.invalidApplication }
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            path.map { Darwin.open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC) } ?? -1
        }
        guard descriptor >= 0 else { throw OpenWithError.invalidApplication }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, opened.st_mode & S_IFMT == S_IFREG,
              opened.st_dev == before.st_dev, opened.st_ino == before.st_ino,
              opened.st_size == before.st_size,
              let data = try handle.read(upToCount: maximumBytes + 1),
              Int64(data.count) == before.st_size else { throw OpenWithError.invalidApplication }
        return data
    }

    @MainActor
    static func open(_ selection: [URL], with applicationURL: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // LaunchServices completes on its own queue. Do not capture a main-
            // actor callback here; the continuation safely resumes its caller.
            NSWorkspace.shared.open(selection, withApplicationAt: applicationURL, configuration: configuration) { @Sendable _, error in
                if error != nil { continuation.resume(throwing: OpenWithError.openFailed) }
                else { continuation.resume() }
            }
        }
    }
}

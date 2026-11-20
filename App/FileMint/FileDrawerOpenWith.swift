import AppKit
import FileMintCore

enum FileDrawerOpenWith {
    struct Candidate: Identifiable, Sendable {
        let url: URL
        let name: String
        var id: URL { url }
        fileprivate let identifier: String
        fileprivate let bundleIdentity: CreationDirectoryIdentity
        fileprivate let source: Source
    }

    fileprivate enum Source: Sendable {
        case configured(OpenWithApplication)
        case direct(URL)
    }

    private final class AppAccess: Sendable {
        let url: URL
        private let started: Bool

        init(_ url: URL) {
            self.url = url
            started = url.startAccessingSecurityScopedResource()
        }

        deinit { if started { url.stopAccessingSecurityScopedResource() } }
    }

    static func candidates(for items: [FileDrawerEntry], configured: [OpenWithApplication]) async throws -> [Candidate] {
        try await onWorker {
            guard let first = items.first else { return [] }
            var apps: [Candidate] = []
            var identifiers: Set<String> = []
            var paths: Set<URL> = []
            func append(_ candidate: Candidate) {
                guard !identifiers.contains(candidate.identifier), !paths.contains(candidate.url) else { return }
                identifiers.insert(candidate.identifier)
                paths.insert(candidate.url)
                apps.append(candidate)
            }

            for app in OpenWithPolicy.normalized(configured) {
                try Task.checkCancellation()
                guard let url = try? OpenWithApplicationAccess.resolve(app),
                      let candidate = try? capture(at: url, configured: app) else { continue }
                append(candidate)
            }

            let workspace = NSWorkspace.shared
            var common = workspace.urlsForApplications(toOpen: first.url)
            for item in items.dropFirst() {
                try Task.checkCancellation()
                if common.isEmpty { break }
                let supported = Set(workspace.urlsForApplications(toOpen: item.url))
                common.removeAll { !supported.contains($0) }
            }
            for url in common {
                try Task.checkCancellation()
                if let candidate = try? capture(at: url) { append(candidate) }
            }
            return apps
        }
    }

    static func picked(_ url: URL) async throws -> Candidate {
        try await onWorker { try capture(at: url) }
    }

    private static func capture(at url: URL, configured: OpenWithApplication? = nil) throws -> Candidate {
        let access = AppAccess(url)
        defer { withExtendedLifetime(access) {} }
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL
        let identity = try CreationDirectoryIdentity.capture(canonical)
        let identifier = try OpenWithApplicationAccess.validatedIdentifier(at: canonical)
        guard configured.map({ $0.bundleIdentifier == identifier }) ?? true,
              try CreationDirectoryIdentity.capture(canonical) == identity else { throw OpenWithError.unavailableApplication }
        return Candidate(url: canonical, name: configured?.name ?? OpenWithApplicationAccess.displayName(at: canonical),
                         identifier: identifier, bundleIdentity: identity,
                         source: configured.map(Source.configured) ?? .direct(url))
    }

    @MainActor
    static func open(_ candidate: Candidate, directory: FileDrawerDirectory, items: [FileDrawerEntry],
                     currentApps: @MainActor () -> [OpenWithApplication], isCurrent: @MainActor () -> Bool) async throws {
        guard !items.isEmpty else { throw OpenWithError.missingSelection }
        let app = try await onWorker {
            let url: URL
            switch candidate.source {
            case let .configured(saved): url = try OpenWithApplicationAccess.resolve(saved)
            case let .direct(selected): url = selected
            }
            let access = AppAccess(url)
            guard url.resolvingSymlinksInPath().standardizedFileURL == candidate.url,
                  (try? OpenWithApplicationAccess.validatedIdentifier(at: url)) == candidate.identifier else {
                throw OpenWithError.unavailableApplication
            }
            for item in items {
                try Task.checkCancellation()
                try directory.validate(item)
                if item.isLink {
                    // LaunchServices can follow a link. Validate its destination before
                    // passing the original item URL to the user's chosen application.
                    let target = item.isRegular
                        ? try URL(resolvingAliasFileAt: item.url, options: [.withoutUI, .withoutMounting])
                        : item.url
                    guard FolderScope.containsResolvedDirectory(target, in: [directory.rootURL]),
                          !FolderScope.containsResolvedDirectory(target, in: [FileMintStorage.directory]) else {
                        throw FileInfoError.accessDenied
                    }
                }
                try FolderAccess.checkAccess(to: item.url, mode: R_OK)
            }
            guard (try? CreationDirectoryIdentity.capture(candidate.url)) == candidate.bundleIdentity else {
                throw OpenWithError.unavailableApplication
            }
            return access
        }
        defer { withExtendedLifetime(app) {} }
        try Task.checkCancellation()
        guard isCurrent() else { throw CancellationError() }
        if case let .configured(saved) = candidate.source {
            guard let current = currentApps().first(where: { $0.reference == saved.reference }),
                  current.bookmark == saved.bookmark else { throw OpenWithError.changedConfiguration }
            if items.count == 1, let folder = items.first, folder.canEnterDirectory {
                guard current.terminalOpenMode == saved.terminalOpenMode else { throw OpenWithError.changedConfiguration }
                try await TerminalDirectoryLauncher.open(folder.url, with: current, applicationURL: app.url,
                                                        mode: current.terminalOpenMode)
                return
            }
        }
        try await OpenWithApplicationAccess.open(items.map(\.url), with: app.url)
    }

    private static func onWorker<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        let task = Task.detached(priority: .userInitiated, operation: operation)
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }
}

import AppKit
import FileMintCore

enum ExternalDraftSource: Equatable {
    case shortcuts, externalLink, preview
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .shortcuts: LauncherText.shortcuts.text(language)
        case .externalLink: LauncherText.externalRequest.text(language)
        case .preview: LauncherText.previewDraft.text(language)
        }
    }
}

struct ExternalDirectoryResolution: Sendable {
    let url: URL
    let identity: CreationDirectoryIdentity?
    let startedScopeURL: URL?
}

/// One session owns these grants, including worker/post-creation cleanup. A path
/// or an ID never starts a grant by itself; only native adapter/picker URLs do.
@MainActor
final class ExternalDraftDirectoryAccess {
    static private(set) var pendingOperationCount = 0
    private(set) var url: URL
    private(set) var identity: CreationDirectoryIdentity?
    private(set) var isChecking = false
    private(set) var error: ExternalInvocationError?
    let needsSelection: Bool
    private var activeScopes: [URL] = []
    private var operations = 0
    private var closing = false
    private var preparation: Task<Void, Never>?

    init(url: URL, needsSelection: Bool = false, nativeGrantURL: URL? = nil) {
        self.url = url
        self.needsSelection = needsSelection
        if let nativeGrantURL, nativeGrantURL.startAccessingSecurityScopedResource() { activeScopes.append(nativeGrantURL) }
    }

    func prepare(using resolve: @escaping @Sendable () throws -> ExternalDirectoryResolution,
                 stillValid: @escaping @MainActor () -> Bool = { true },
                 didChange: @escaping @MainActor () -> Void) {
        guard !closing, !needsSelection, preparation == nil else { return }
        isChecking = true
        beginOperation()
        didChange()
        preparation = Task {
            let result = await Task.detached(priority: .userInitiated) { Result { try resolve() } }.value
            if case .success(let resolved) = result, let scope = resolved.startedScopeURL { activeScopes.append(scope) }
            if !closing {
                switch result {
                case .success(let resolved) where stillValid():
                    url = resolved.url
                    identity = resolved.identity
                    error = resolved.identity == nil ? .authorizationRequired : nil
                case .success, .failure:
                    identity = nil
                    error = .destinationUnavailable
                }
                isChecking = false
                didChange()
            }
            preparation = nil
            endOperation()
        }
    }

    nonisolated static func resolveDirectory(_ url: URL) throws -> ExternalDirectoryResolution {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        do {
            return try .init(url: resolved, identity: CreationDirectoryIdentity.capture(resolved), startedScopeURL: nil)
        } catch {
            let failure = error as NSError
            let permission = (failure.domain == NSPOSIXErrorDomain && [1, 13].contains(failure.code))
                || (failure.domain == NSCocoaErrorDomain && [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(failure.code))
            guard permission else { throw error }
            return .init(url: resolved, identity: nil, startedScopeURL: nil)
        }
    }

    func beginOperation() { operations += 1; Self.pendingOperationCount += 1 }
    func endOperation() {
        precondition(operations > 0)
        operations -= 1
        Self.pendingOperationCount -= 1
        releaseIfIdle()
    }
    func releaseWhenIdle() {
        closing = true
        preparation?.cancel()
        releaseIfIdle()
    }
    private func releaseIfIdle() {
        guard closing, operations == 0 else { return }
        for url in activeScopes { url.stopAccessingSecurityScopedResource() }
        activeScopes.removeAll()
    }
}

@MainActor
struct ExternalDraftPresentation {
    let sessionID: UUID
    let seed: ExternalDraftSeed
    let source: ExternalDraftSource
    var directory: ExternalDraftDirectoryAccess
    let validateTemplate: (String?) -> Bool
    let didClose: () -> Void
}

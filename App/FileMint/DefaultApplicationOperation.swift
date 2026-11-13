import AppKit
import FileMintCore
import UniformTypeIdentifiers

@MainActor
struct DefaultApplicationOperation {
    let preferencesFile: URL?

    func present(_ selection: DefaultApplicationSelection) async throws {
        guard NSApp.modalWindow == nil, NSApp.windows.allSatisfy({ $0.attachedSheet == nil }) else {
            throw DefaultApplicationError.busy
        }
        let preferences = loadPreferences()
        guard selection.isEnabled(in: preferences) else { throw FileInfoError.disabled }
        let access = FileInfoReadAccess(preferencesFile: preferencesFile)
        access.restore(for: selection.file, preferences: preferences)
        defer { access.release() }

        let type: UTType
        do { type = try await validate(selection) }
        catch where FolderAccess.isPermissionError(error) {
            guard try access.request(for: selection.file, language: preferences.language, currentRoots: {
                let current = loadPreferences()
                guard selection.isEnabled(in: current) else { throw FileInfoError.disabled }
                return current.monitoredFolderURLs
            }) else { throw FileInfoError.cancelled }
            type = try await validate(selection)
        }

        let picker = DefaultApplicationPicker(type: type, language: preferences.language,
                                              snapshot: DefaultApplicationWorkspace.snapshot(for: type)) { app in
            _ = try await validate(selection)
            try await DefaultApplicationWorkspace.set(app, for: type)
        }
        await picker.present()
    }

    private func loadPreferences() -> FileMintPreferences {
        FileMintPreferencesStore(fileURL: preferencesFile).load()
    }

    private func validate(_ selection: DefaultApplicationSelection) async throws -> UTType {
        let preferences = loadPreferences()
        guard selection.isEnabled(in: preferences) else { throw FileInfoError.disabled }
        let roots = preferences.monitoredFolderURLs
        let type = try await Task.detached(priority: .userInitiated) { try selection.validate(in: roots) }.value
        let current = loadPreferences()
        guard selection.isEnabled(in: current), current.monitoredFolderURLs == roots else { throw FileInfoError.disabled }
        return type
    }

    func showError(_ error: Error, language: AppLanguage) {
        if (error as? DefaultApplicationError) == .busy {
            FavoriteFeedbackController.show(FileInfoText.busy.text(language), symbol: "exclamationmark.circle")
            return
        }
        let alert = NSAlert()
        alert.messageText = FileMintStrings.text(.changeDefaultApplication, language: language)
        alert.informativeText = DefaultApplicationError.message(for: error, language: language)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

struct DefaultApplicationCandidate: Identifiable {
    let url: URL
    let id: String
    let name: String
    let originalName: String

    func matches(_ query: String) -> Bool {
        query.isEmpty || name.localizedStandardContains(query) || originalName.localizedStandardContains(query)
    }
}

@MainActor
enum DefaultApplicationWorkspace {
    static func snapshot(for type: UTType) -> (apps: [DefaultApplicationCandidate], currentID: String?) {
        let workspace = NSWorkspace.shared
        let current = workspace.urlForApplication(toOpen: type)
        let urls = [current].compactMap { $0 } + workspace.urlsForApplications(toOpen: type)
        var seen = Set<String>()
        let apps: [DefaultApplicationCandidate] = urls.compactMap { url in
            guard OpenWithPolicy.isLocalFileURL(url) else { return nil }
            let id = appID(url)
            guard seen.insert(id).inserted else { return nil }
            return DefaultApplicationCandidate(url: url, id: id, name: OpenWithApplicationAccess.displayName(at: url),
                                               originalName: url.deletingPathExtension().lastPathComponent)
        }
        return (apps, current.map(appID))
    }

    static func appID(_ url: URL) -> String { url.resolvingSymlinksInPath().standardizedFileURL.path }

    static func isCompatible(_ url: URL, with type: UTType) -> Bool {
        let id = appID(url)
        return NSWorkspace.shared.urlsForApplications(toOpen: type).contains { appID($0) == id }
    }

    static func set(_ app: DefaultApplicationCandidate, for type: UTType) async throws {
        let workspace = NSWorkspace.shared
        guard appID(app.url) == app.id, isCompatible(app.url, with: type) else {
            throw DefaultApplicationError.incompatible
        }
        if workspace.urlForApplication(toOpen: type).map(appID) == app.id { return }
        // macOS may show a consent prompt. Keep the operation and picker alive
        // through the callback and verify the type-wide association afterwards.
        try await workspace.setDefaultApplication(at: app.url, toOpen: type)
        guard workspace.urlForApplication(toOpen: type).map(appID) == app.id else {
            throw DefaultApplicationError.notApplied
        }
    }
}

enum DefaultApplicationError: Error, Equatable {
    case busy, incompatible, notApplied

    static func message(for error: Error, language: AppLanguage) -> String {
        if let error = error as? FileInfoError {
            switch error {
            case .invalidSelection, .unsupported:
                return FileMintStrings.text(.defaultApplicationInvalidSelection, language: language)
            case .changed, .disabled: return DefaultApplicationText.selectionChanged.text(language)
            default: return error.text.text(language)
            }
        }
        switch error as? Self {
        case .busy: return FileInfoText.busy.text(language)
        case .incompatible: return DefaultApplicationText.incompatible.text(language)
        case .notApplied, nil: return DefaultApplicationText.notApplied.text(language)
        }
    }
}

enum DefaultApplicationText {
    case title, scope, compatible, current, search, other, choose, noApps, noMatches, apply, applying, success
    case systemConfirmation
    case selectionChanged, incompatible, notApplied

    func text(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .title: ("Change Default App", "更改默认应用")
        case .scope: ("Applies to all “%@” files in this macOS account.", "适用于当前账户中所有「%@」文件。")
        case .compatible: ("Compatible Apps · %lld", "兼容应用 · %lld 款")
        case .current: ("Current Default", "当前默认")
        case .search: ("Search app names", "搜索应用名称")
        case .other: ("Other Apps…", "其他应用…")
        case .choose: ("Choose App", "选取应用")
        case .noApps: ("macOS found no compatible apps for this type.", "macOS 未找到可打开此类型的应用。")
        case .noMatches: ("No matching apps", "未找到匹配的应用")
        case .apply: ("Set as Default", "设为默认")
        case .applying: ("Waiting for macOS…", "正在等待 macOS…")
        case .systemConfirmation: ("macOS may ask for confirmation", "macOS 可能要求确认")
        case .success: ("%@ is now the default app for %@.", "已将 %@ 设为「%@」的默认应用。")
        case .selectionChanged: ("The file, its type, or Finder scope changed. Select the file again in Finder.",
                                 "文件、文件类型或 Finder 范围已变化。请在 Finder 中重新选择文件。")
        case .incompatible: ("macOS no longer lists this app for this type. Choose a compatible app.",
                             "macOS 未将此应用列为该类型的兼容应用。请选取兼容的应用。")
        case .notApplied: ("macOS did not confirm the change. Try again, or change it in Finder’s Get Info window.",
                            "macOS 未确认更改。请重试，或在 Finder 的「显示简介」中更改。")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}

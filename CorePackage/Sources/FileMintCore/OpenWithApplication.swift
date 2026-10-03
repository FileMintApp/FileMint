import Foundation

public enum OpenWithMenuPlacement: String, Codable, CaseIterable, Sendable {
    case submenu, main
}

public enum TerminalOpenMode: String, Codable, CaseIterable, Sendable {
    case applicationDefault, newTab, newWindow
}

public enum TerminalAdapter: String, Sendable {
    case terminal, iterm2, ghostty, warp

    public init?(bundleIdentifier: String) {
        switch bundleIdentifier {
        case "com.apple.Terminal": self = .terminal
        case "com.googlecode.iterm2": self = .iterm2
        case "com.mitchellh.ghostty": self = .ghostty
        case "dev.warp.Warp-Stable": self = .warp
        default: return nil
        }
    }
}

public enum OpenWithTarget: Codable, Equatable, Sendable {
    case selection([URL])
    case directory(URL)

    public var urls: [URL] {
        switch self {
        case .selection(let urls): urls
        case .directory(let url): [url]
        }
    }
}

public enum OpenWithTargetPolicy {
    public static func target(directory: URL, selection: [URL], isContainer: Bool,
                              selectedIsOrdinaryDirectory: Bool) -> OpenWithTarget? {
        if isContainer { return .directory(directory) }
        guard !selection.isEmpty else { return nil }
        if selection.count == 1 && selectedIsOrdinaryDirectory { return .directory(selection[0]) }
        return .selection(selection)
    }
}

/// Only this identity crosses the Finder boundary, never a caller-supplied executable.
public struct OpenWithApplicationReference: Codable, Equatable, Sendable {
    public let id: UUID
    public let bundleIdentifier: String
    public let url: URL
}

public struct OpenWithApplication: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var bundleIdentifier: String
    public var url: URL
    public var bookmark: Data
    public var placement: OpenWithMenuPlacement
    public var terminalOpenMode: TerminalOpenMode

    public init(id: UUID = UUID(), name: String, bundleIdentifier: String, url: URL,
                bookmark: Data, placement: OpenWithMenuPlacement = .submenu,
                terminalOpenMode: TerminalOpenMode? = nil) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.url = url.standardizedFileURL
        self.bookmark = bookmark
        self.placement = placement
        self.terminalOpenMode = terminalOpenMode ?? (TerminalAdapter(bundleIdentifier: bundleIdentifier) == nil ? .applicationDefault : .newTab)
    }

    private enum CodingKeys: String, CodingKey { case id, name, bundleIdentifier, url, bookmark, placement, terminalOpenMode }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        bundleIdentifier = try values.decode(String.self, forKey: .bundleIdentifier)
        url = try values.decode(URL.self, forKey: .url)
        bookmark = try values.decode(Data.self, forKey: .bookmark)
        placement = (try? values.decode(OpenWithMenuPlacement.self, forKey: .placement)) ?? .submenu
        terminalOpenMode = (try? values.decode(TerminalOpenMode.self, forKey: .terminalOpenMode)) ?? .applicationDefault
    }

    public var reference: OpenWithApplicationReference {
        OpenWithApplicationReference(id: id, bundleIdentifier: bundleIdentifier, url: url)
    }

    public func menuTitle(language: AppLanguage) -> String {
        String(format: FileMintStrings.text(.openWithAppName, language: language), name)
    }

    public func menuTitle(target: OpenWithTarget, language: AppLanguage) -> String {
        let title = menuTitle(language: language)
        guard case .directory = target, TerminalAdapter(bundleIdentifier: bundleIdentifier) != nil else { return title }
        switch terminalOpenMode {
        case .applicationDefault: return title
        case .newTab: return "\(title) (\(FileMintStrings.text(.terminalNewTab, language: language)))"
        case .newWindow: return "\(title) (\(FileMintStrings.text(.terminalNewWindow, language: language)))"
        }
    }
}

public struct OpenWithPreferences: Codable, Equatable, Sendable {
    public var applications: [OpenWithApplication] = []
    public init() {}

    private enum CodingKeys: String, CodingKey { case applications }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if var entries = try? values.nestedUnkeyedContainer(forKey: .applications) {
            while !entries.isAtEnd {
                let entry = try entries.superDecoder()
                if let app = try? OpenWithApplication(from: entry) { applications.append(app) }
            }
        }
        applications = OpenWithPolicy.normalized(applications)
    }

    /// Re-adding repairs access/location without multiplying menu entries or
    /// resetting placement. A changed location invalidates old menu snapshots.
    public mutating func add(_ application: OpenWithApplication) {
        guard let app = OpenWithPolicy.normalized([application]).first else { return }
        if let index = applications.firstIndex(where: {
            $0.bundleIdentifier == app.bundleIdentifier || $0.url.standardizedFileURL == app.url.standardizedFileURL
        }) {
            let previous = applications[index]
            applications[index] = OpenWithApplication(id: previous.id, name: app.name,
                bundleIdentifier: app.bundleIdentifier, url: app.url, bookmark: app.bookmark,
                placement: previous.placement, terminalOpenMode: previous.terminalOpenMode)
        } else { applications.append(app) }
        applications = OpenWithPolicy.normalized(applications)
    }

    /// A row dropped on a later row moves after it; one dropped on an earlier
    /// row moves before it. This keeps the saved array as the menu's source order.
    public mutating func move(_ id: UUID, to targetID: UUID) {
        guard let source = applications.firstIndex(where: { $0.id == id }),
              let target = applications.firstIndex(where: { $0.id == targetID }),
              source != target else { return }
        let application = applications.remove(at: source)
        applications.insert(application, at: target)
    }

    public mutating func move(_ id: UUID, by offset: Int) {
        guard offset == -1 || offset == 1,
              let source = applications.firstIndex(where: { $0.id == id }),
              applications.indices.contains(source + offset) else { return }
        move(id, to: applications[source + offset].id)
    }
}

public enum OpenWithPolicy {
    public static func isLocalFileURL(_ url: URL) -> Bool {
        url.isFileURL && (url.host == nil || url.host == "" || url.host == "localhost") &&
            url.query == nil && url.fragment == nil && url.path.hasPrefix("/")
    }

    public static func normalized(_ applications: [OpenWithApplication]) -> [OpenWithApplication] {
        var ids = Set<UUID>()
        var bundles = Set<String>()
        var paths = Set<String>()
        return applications.compactMap { application in
            var app = application
            guard isLocalFileURL(app.url), app.url.pathExtension.lowercased() == "app",
                  !app.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !app.bookmark.isEmpty,
                  !ids.contains(app.id), !bundles.contains(app.bundleIdentifier),
                  !paths.contains(app.url.standardizedFileURL.path) else { return nil }
            app.url = app.url.standardizedFileURL
            ids.insert(app.id); bundles.insert(app.bundleIdentifier); paths.insert(app.url.path)
            return app
        }
    }

    public static func availableApplications(selection: [URL], isItemMenu: Bool,
                                             preferences: FileMintPreferences) -> [OpenWithApplication] {
        guard isItemMenu, !selection.isEmpty,
              selection.allSatisfy({ isLocalFileURL($0) && FolderScope.contains($0, in: preferences.monitoredFolderURLs) })
        else { return [] }
        return normalized(preferences.openWith.applications)
    }

    public static func availableApplications(target: OpenWithTarget, preferences: FileMintPreferences) -> [OpenWithApplication] {
        switch target {
        case .selection(let urls):
            return availableApplications(selection: urls, isItemMenu: true, preferences: preferences)
        case .directory(let url):
            guard isLocalFileURL(url), FolderScope.contains(url, in: preferences.monitoredFolderURLs) else { return [] }
            return normalized(preferences.openWith.applications)
        }
    }

    public static func application(for reference: OpenWithApplicationReference, target: OpenWithTarget,
                                   preferences: FileMintPreferences) -> OpenWithApplication? {
        availableApplications(target: target, preferences: preferences).first { $0.reference == reference }
    }

    public static func application(for reference: OpenWithApplicationReference, selection: [URL],
                                   preferences: FileMintPreferences) -> OpenWithApplication? {
        availableApplications(selection: selection, isItemMenu: true, preferences: preferences)
            .first { $0.reference == reference }
    }
}

public struct OpenWithMenuLayout: Equatable, Sendable {
    public let main: [OpenWithApplication]
    public let submenu: [OpenWithApplication]
    public var showsSubmenu: Bool { !submenu.isEmpty }

    public init(applications: [OpenWithApplication]) {
        let applications = OpenWithPolicy.normalized(applications)
        main = applications.filter { $0.placement == .main }
        submenu = applications.filter { $0.placement == .submenu }
    }
}

public enum OpenWithError: Error {
    case invalidApplication, unavailableApplication, changedConfiguration, missingSelection, missingDirectory
    case unsupportedTerminal, serviceUnavailable, openFailed, folderAccessFailed, wrongAuthorizationFolder

    public var messageKey: FileMintTextKey {
        switch self {
        case .invalidApplication: .openWithInvalidApp
        case .unavailableApplication: .openWithUnavailableApp
        case .changedConfiguration: .openWithChanged
        case .missingSelection: .openWithMissingSelection
        case .missingDirectory: .openWithMissingDirectory
        case .unsupportedTerminal: .openWithUnsupportedTerminal
        case .serviceUnavailable: .openWithServiceUnavailable
        case .openFailed: .openWithFailed
        case .folderAccessFailed: .openWithFolderAccessFailed
        case .wrongAuthorizationFolder: .moveChooseExactFolder
        }
    }
}

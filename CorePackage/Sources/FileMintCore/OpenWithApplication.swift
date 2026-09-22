import Foundation

public enum OpenWithMenuPlacement: String, Codable, CaseIterable, Sendable {
    case submenu, main
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

    public init(id: UUID = UUID(), name: String, bundleIdentifier: String, url: URL,
                bookmark: Data, placement: OpenWithMenuPlacement = .submenu) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.url = url.standardizedFileURL
        self.bookmark = bookmark
        self.placement = placement
    }

    private enum CodingKeys: String, CodingKey { case id, name, bundleIdentifier, url, bookmark, placement }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        bundleIdentifier = try values.decode(String.self, forKey: .bundleIdentifier)
        url = try values.decode(URL.self, forKey: .url)
        bookmark = try values.decode(Data.self, forKey: .bookmark)
        placement = (try? values.decode(OpenWithMenuPlacement.self, forKey: .placement)) ?? .submenu
    }

    public var reference: OpenWithApplicationReference {
        OpenWithApplicationReference(id: id, bundleIdentifier: bundleIdentifier, url: url)
    }

    public func menuTitle(language: AppLanguage) -> String {
        String(format: FileMintStrings.text(.openWithAppName, language: language), name)
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
                bundleIdentifier: app.bundleIdentifier, url: app.url, bookmark: app.bookmark, placement: previous.placement)
        } else { applications.append(app) }
        applications = OpenWithPolicy.normalized(applications)
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
    case invalidApplication, unavailableApplication, changedConfiguration, missingSelection, openFailed

    public var messageKey: FileMintTextKey {
        switch self {
        case .invalidApplication: .openWithInvalidApp
        case .unavailableApplication: .openWithUnavailableApp
        case .changedConfiguration: .openWithChanged
        case .missingSelection: .openWithMissingSelection
        case .openFailed: .openWithFailed
        }
    }
}

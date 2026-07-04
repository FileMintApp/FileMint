import Foundation

public enum FileMintAppGroup {
    public static let identifier = "group.io.github.daigua.filemint"
    public static let preferencesKey = "FileMintPreferences.v1"
    public static let preferencesDidChangeNotification = "io.github.daigua.filemint.preferencesDidChange"
}

public struct FileMintPreferences: Codable, Equatable, Sendable {
    public var templates: [FileTemplate]
    public var monitoredFolderURLs: [URL]
    public var collisionStrategy: NameCollisionStrategy
    public var revealAfterCreation: Bool
    public var favoritesFirst: Bool

    public init(
        templates: [FileTemplate],
        monitoredFolderURLs: [URL],
        collisionStrategy: NameCollisionStrategy,
        revealAfterCreation: Bool,
        favoritesFirst: Bool
    ) {
        self.templates = templates
        self.monitoredFolderURLs = monitoredFolderURLs
        self.collisionStrategy = collisionStrategy
        self.revealAfterCreation = revealAfterCreation
        self.favoritesFirst = favoritesFirst
    }

    public static var `default`: FileMintPreferences {
        FileMintPreferences(
            templates: TemplateCatalog.builtInTemplates,
            monitoredFolderURLs: DefaultFolders.urls(),
            collisionStrategy: .increment,
            revealAfterCreation: true,
            favoritesFirst: true
        )
    }
}

public enum DefaultFolders {
    public static func urls(fileManager: FileManager = .default) -> [URL] {
        let searchPaths: [FileManager.SearchPathDirectory] = [
            .desktopDirectory,
            .documentDirectory,
            .downloadsDirectory
        ]

        return searchPaths.compactMap { directory in
            fileManager.urls(for: directory, in: .userDomainMask).first
        }
    }
}

public final class FileMintPreferencesStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = UserDefaults(suiteName: FileMintAppGroup.identifier)) {
        self.defaults = defaults ?? .standard
    }

    public func load() -> FileMintPreferences {
        guard let data = defaults.data(forKey: FileMintAppGroup.preferencesKey) else {
            return .default
        }

        do {
            return try JSONDecoder().decode(FileMintPreferences.self, from: data)
        } catch {
            return .default
        }
    }

    public func save(_ preferences: FileMintPreferences) throws {
        let data = try JSONEncoder().encode(preferences)
        defaults.set(data, forKey: FileMintAppGroup.preferencesKey)
    }
}

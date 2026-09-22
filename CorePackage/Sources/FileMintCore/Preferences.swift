import Foundation
#if canImport(Darwin)
import Darwin
#endif

public enum FileMintAppGroup {
    public static let identifier = "group.io.github.daigua.filemint"
    public static let preferencesKey = "FileMintPreferences.v1"
    public static let preferencesDidChangeNotification = "io.github.daigua.filemint.preferencesDidChange"
}

public struct FileMintPreferences: Codable, Equatable, Sendable {
    public var templates: [FileTemplate]
    public var monitoredFolderURLs: [URL]
    public var monitoredFolderBookmarks: [String: Data]
    public var collisionStrategy: NameCollisionStrategy
    public var revealAfterCreation: Bool
    public var favoritesFirst: Bool
    public var language: AppLanguage
    public var launchAtLogin: Bool
    public var showMenuBar: Bool
    public var automaticallyChecksForUpdates: Bool
    public var lastUpdateCheckAttempt: Date?
    public var hasAttemptedLoginItemSetup: Bool
    public var fileTools = FileToolsPreferences()
    public var resourceTools = ResourceToolsPreferences()
    public var openWith = OpenWithPreferences()
    private var folderScopeVersion = 2

    public init(
        templates: [FileTemplate],
        monitoredFolderURLs: [URL],
        collisionStrategy: NameCollisionStrategy,
        revealAfterCreation: Bool,
        favoritesFirst: Bool,
        language: AppLanguage = .system,
        launchAtLogin: Bool = true,
        showMenuBar: Bool = true,
        hasAttemptedLoginItemSetup: Bool = false,
        automaticallyChecksForUpdates: Bool = true,
        lastUpdateCheckAttempt: Date? = nil
    ) {
        self.templates = templates
        self.monitoredFolderURLs = monitoredFolderURLs
        self.monitoredFolderBookmarks = [:]
        self.collisionStrategy = collisionStrategy
        self.revealAfterCreation = revealAfterCreation
        self.favoritesFirst = favoritesFirst
        self.language = language
        self.launchAtLogin = launchAtLogin
        self.showMenuBar = showMenuBar
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        self.lastUpdateCheckAttempt = lastUpdateCheckAttempt
        self.hasAttemptedLoginItemSetup = hasAttemptedLoginItemSetup
    }

    private enum CodingKeys: String, CodingKey {
        case templates
        case monitoredFolderURLs
        case monitoredFolderBookmarks
        case collisionStrategy
        case revealAfterCreation
        case favoritesFirst
        case language
        case launchAtLogin
        case showMenuBar
        case automaticallyChecksForUpdates
        case lastUpdateCheckAttempt
        case hasAttemptedLoginItemSetup
        case folderScopeVersion
        case fileTools
        case resourceTools
        case openWith
    }

    public init(from decoder: Decoder) throws {
        let defaults = FileMintPreferences.default
        let container = try decoder.container(keyedBy: CodingKeys.self)

        templates = (try? container.decode([FileTemplate].self, forKey: .templates)) ?? defaults.templates
        templates = TemplateCatalog.migratingTemplates(templates)
        monitoredFolderBookmarks = (try? container.decode([String: Data].self, forKey: .monitoredFolderBookmarks)) ?? [:]
        monitoredFolderURLs = (try? container.decode([URL].self, forKey: .monitoredFolderURLs)) ?? defaults.monitoredFolderURLs
        let savedFolderScopeVersion = (try? container.decode(Int.self, forKey: .folderScopeVersion)) ?? 1
        if savedFolderScopeVersion < 2 {
            monitoredFolderURLs = DefaultFolders.migratingHomeScope(monitoredFolderURLs,
                homeDirectory: DefaultFolders.resolvedUserHomeDirectory(fileManager: .default))
        }
        folderScopeVersion = max(2, savedFolderScopeVersion)
        collisionStrategy = (try? container.decode(NameCollisionStrategy.self, forKey: .collisionStrategy))
            ?? defaults.collisionStrategy
        if collisionStrategy == .replace { collisionStrategy = .increment }
        revealAfterCreation = (try? container.decode(Bool.self, forKey: .revealAfterCreation))
            ?? defaults.revealAfterCreation
        favoritesFirst = (try? container.decode(Bool.self, forKey: .favoritesFirst)) ?? defaults.favoritesFirst
        language = (try? container.decode(AppLanguage.self, forKey: .language)) ?? defaults.language
        launchAtLogin = (try? container.decode(Bool.self, forKey: .launchAtLogin)) ?? true
        showMenuBar = (try? container.decode(Bool.self, forKey: .showMenuBar)) ?? true
        automaticallyChecksForUpdates = (try? container.decode(Bool.self, forKey: .automaticallyChecksForUpdates)) ?? true
        lastUpdateCheckAttempt = try? container.decode(Date.self, forKey: .lastUpdateCheckAttempt)
        hasAttemptedLoginItemSetup = (try? container.decode(Bool.self, forKey: .hasAttemptedLoginItemSetup)) ?? false
        fileTools = (try? container.decode(FileToolsPreferences.self, forKey: .fileTools)) ?? FileToolsPreferences()
        resourceTools = (try? container.decode(ResourceToolsPreferences.self, forKey: .resourceTools)) ?? ResourceToolsPreferences()
        openWith = (try? container.decode(OpenWithPreferences.self, forKey: .openWith)) ?? OpenWithPreferences()
    }

    public static var `default`: FileMintPreferences {
        FileMintPreferences(
            templates: TemplateCatalog.builtInTemplates,
            monitoredFolderURLs: DefaultFolders.urls(),
            collisionStrategy: .increment,
            revealAfterCreation: true,
            favoritesFirst: true,
            language: .system
        )
    }
}

public enum DefaultFolders {
    public static func urls(fileManager: FileManager = .default) -> [URL] {
        urls(homeDirectory: resolvedUserHomeDirectory(fileManager: fileManager))
    }

    public static func urls(homeDirectory: URL) -> [URL] {
        [homeDirectory] + ["Desktop", "Documents", "Downloads"].map {
            homeDirectory.appendingPathComponent($0, isDirectory: true)
        }
    }

    public static func migratingHomeScope(_ folders: [URL], homeDirectory: URL) -> [URL] {
        let paths = Set(folders.filter(\.isFileURL).map { $0.standardizedFileURL.path })
        let defaults = urls(homeDirectory: homeDirectory)
        guard !paths.contains(homeDirectory.standardizedFileURL.path),
              defaults.dropFirst().allSatisfy({ paths.contains($0.standardizedFileURL.path) }) else { return folders }
        return [homeDirectory] + folders
    }

    public static func resolvedUserHomeDirectory(fileManager: FileManager) -> URL {
        #if canImport(Darwin)
        if let passwordEntry = getpwuid(getuid()),
           let homePath = passwordEntry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: homePath), isDirectory: true)
        }
        #endif

        return fileManager.homeDirectoryForCurrentUser
    }
}

public final class FileMintPreferencesStore {
    private let fileURL: URL?

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileMintStorage.directory.appendingPathComponent("preferences.json")
    }

    public static func decode(_ data: Data) throws -> FileMintPreferences {
        if let value = try? JSONDecoder().decode(FileMintPreferences.self, from: data) { return value }
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = plist as? [String: Any], let payload = dictionary[FileMintAppGroup.preferencesKey] as? Data else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try JSONDecoder().decode(FileMintPreferences.self, from: payload)
    }

    public func load() -> FileMintPreferences {
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let preferences = try? JSONDecoder().decode(FileMintPreferences.self, from: data) { return preferences }
        return .default
    }

    public func save(_ preferences: FileMintPreferences) throws {
        guard let fileURL else {
            throw NSError(domain: "FileMintPreferences", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "FileMint could not access its shared settings folder. Reinstall the app and try again."])
        }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(preferences)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}

public enum FileMintStorage {
    public static var directory: URL {
        DefaultFolders.resolvedUserHomeDirectory(fileManager: .default)
            .appendingPathComponent("Library/Application Support/FileMint", isDirectory: true)
    }
}

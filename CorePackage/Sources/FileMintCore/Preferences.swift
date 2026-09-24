import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum FileMintAppGroup {
    public static let identifier = "group.io.github.daigua.filemint"
    public static let preferencesKey = "FileMintPreferences.v1"
    public static let preferencesDidChangeNotification = "io.github.daigua.filemint.preferencesDidChange"
}

public enum AppAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    public var id: String { rawValue }

    public var title: FileMintTextKey {
        switch self {
        case .system: .followSystem
        case .light: .lightAppearance
        case .dark: .darkAppearance
        }
    }
}

public enum NewFileMenuPlacement: String, Codable, CaseIterable, Sendable {
    case submenu, main
}

public struct FileMintPreferences: Codable, Equatable, Sendable {
    public var templates: [FileTemplate]
    public var removedBuiltInTemplateIDs: [String] = []
    public var defaultTemplateIDs: [String: String] = [:]
    public var monitoredFolderURLs: [URL]
    public var monitoredFolderBookmarks: [String: Data]
    public var collisionStrategy: NameCollisionStrategy
    public var revealAfterCreation: Bool
    public var favoritesFirst: Bool
    public var language: AppLanguage
    public var appearance: AppAppearance
    public var launchAtLogin: Bool
    public var showMenuBar: Bool
    public var automaticallyChecksForUpdates: Bool
    public var lastUpdateCheckAttempt: Date?
    public var hasAttemptedLoginItemSetup: Bool
    public var fileTools = FileToolsPreferences()
    public var resourceTools = ResourceToolsPreferences()
    public var openWith = OpenWithPreferences()
    public var favoriteLocations = FavoriteLocationsPreferences()
    public var newFileMenuPlacement: NewFileMenuPlacement = .submenu
    private var folderScopeVersion = 2

    public init(
        templates: [FileTemplate],
        monitoredFolderURLs: [URL],
        collisionStrategy: NameCollisionStrategy,
        revealAfterCreation: Bool,
        favoritesFirst: Bool,
        language: AppLanguage = .system,
        appearance: AppAppearance = .system,
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
        self.appearance = appearance
        self.launchAtLogin = launchAtLogin
        self.showMenuBar = showMenuBar
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        self.lastUpdateCheckAttempt = lastUpdateCheckAttempt
        self.hasAttemptedLoginItemSetup = hasAttemptedLoginItemSetup
    }

    private enum CodingKeys: String, CodingKey {
        case templates
        case removedBuiltInTemplateIDs
        case defaultTemplateIDs
        case monitoredFolderURLs
        case monitoredFolderBookmarks
        case collisionStrategy
        case revealAfterCreation
        case favoritesFirst
        case language
        case appearance
        case launchAtLogin
        case showMenuBar
        case automaticallyChecksForUpdates
        case lastUpdateCheckAttempt
        case hasAttemptedLoginItemSetup
        case folderScopeVersion
        case fileTools
        case resourceTools
        case openWith
        case favoriteLocations
        case newFileMenuPlacement
    }

    public init(from decoder: Decoder) throws {
        let defaults = FileMintPreferences.default
        let container = try decoder.container(keyedBy: CodingKeys.self)

        templates = (try? container.decode([FileTemplate].self, forKey: .templates)) ?? defaults.templates
        let builtInIDs = Set(TemplateCatalog.builtInTemplates.map(\.id))
        removedBuiltInTemplateIDs = Array(Set((try? container.decode([String].self, forKey: .removedBuiltInTemplateIDs)) ?? [])
            .intersection(builtInIDs)).sorted()
        templates = TemplateCatalog.migratingTemplates(templates, excludingBuiltInIDs: Set(removedBuiltInTemplateIDs))
        defaultTemplateIDs = TemplateCatalog.validDefaults(
            (try? container.decode([String: String].self, forKey: .defaultTemplateIDs)) ?? [:], in: templates)
        monitoredFolderBookmarks = (try? container.decode([String: Data].self, forKey: .monitoredFolderBookmarks)) ?? [:]
        // A missing or malformed scope in an existing file is never a request
        // to restore the broader first-run home scope.
        monitoredFolderURLs = (try? container.decode([URL].self, forKey: .monitoredFolderURLs)) ?? []
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
        appearance = (try? container.decode(AppAppearance.self, forKey: .appearance)) ?? .system
        launchAtLogin = (try? container.decode(Bool.self, forKey: .launchAtLogin)) ?? true
        showMenuBar = (try? container.decode(Bool.self, forKey: .showMenuBar)) ?? true
        automaticallyChecksForUpdates = (try? container.decode(Bool.self, forKey: .automaticallyChecksForUpdates)) ?? true
        lastUpdateCheckAttempt = try? container.decode(Date.self, forKey: .lastUpdateCheckAttempt)
        hasAttemptedLoginItemSetup = (try? container.decode(Bool.self, forKey: .hasAttemptedLoginItemSetup)) ?? false
        fileTools = (try? container.decode(FileToolsPreferences.self, forKey: .fileTools)) ?? FileToolsPreferences()
        resourceTools = (try? container.decode(ResourceToolsPreferences.self, forKey: .resourceTools)) ?? ResourceToolsPreferences()
        openWith = (try? container.decode(OpenWithPreferences.self, forKey: .openWith)) ?? OpenWithPreferences()
        favoriteLocations = (try? container.decode(FavoriteLocationsPreferences.self, forKey: .favoriteLocations)) ?? FavoriteLocationsPreferences()
        newFileMenuPlacement = (try? container.decode(NewFileMenuPlacement.self, forKey: .newFileMenuPlacement)) ?? .submenu
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

public enum FileMintPreferencesStoreError: Error, LocalizedError {
    case tooLarge, invalidFile, recoveryRequired

    public var errorDescription: String? {
        switch self {
        case .tooLarge: "The settings file is too large. Keep it below 32 MiB."
        case .invalidFile: "The settings file is damaged or unavailable."
        case .recoveryRequired: "Saved settings could not be read. Import a valid settings file to recover them; the original is preserved."
        }
    }
}

public struct FileMintPreferencesLoadResult {
    public let preferences: FileMintPreferences
    public let requiresRecovery: Bool
}

public final class FileMintPreferencesStore {
    public static let maximumBytes = 32 * 1024 * 1024
    private let fileURL: URL?

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileMintStorage.directory.appendingPathComponent("preferences.json")
    }

    public static func decode(_ data: Data) throws -> FileMintPreferences {
        guard data.count <= maximumBytes else { throw FileMintPreferencesStoreError.tooLarge }
        if let value = try? JSONDecoder().decode(FileMintPreferences.self, from: data) { return value }
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = plist as? [String: Any], let payload = dictionary[FileMintAppGroup.preferencesKey] as? Data else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try JSONDecoder().decode(FileMintPreferences.self, from: payload)
    }

    public func load() -> FileMintPreferences {
        loadWithStatus().preferences
    }

    public func loadWithStatus() -> FileMintPreferencesLoadResult {
        guard let fileURL else { return .init(preferences: .default, requiresRecovery: false) }
        do {
            guard let data = try Self.readBoundedFile(at: fileURL) else {
                return .init(preferences: .default, requiresRecovery: false)
            }
            return .init(preferences: try JSONDecoder().decode(FileMintPreferences.self, from: data), requiresRecovery: false)
        } catch {
            var restricted = FileMintPreferences.default
            restricted.monitoredFolderURLs = []
            restricted.monitoredFolderBookmarks = [:]
            restricted.fileTools.isEnabled = false
            restricted.resourceTools.isEnabled = false
            restricted.openWith = OpenWithPreferences()
            return .init(preferences: restricted, requiresRecovery: true)
        }
    }

    public static func decodeFile(at url: URL) throws -> FileMintPreferences {
        guard let data = try readBoundedFile(at: url) else { throw FileMintPreferencesStoreError.invalidFile }
        return try decode(data)
    }

    public func save(_ preferences: FileMintPreferences, recoveringInvalidFile: Bool = false) throws {
        guard let fileURL else {
            throw NSError(domain: "FileMintPreferences", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "FileMint could not access its shared settings folder. Reinstall the app and try again."])
        }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(preferences)
        guard data.count <= Self.maximumBytes else { throw FileMintPreferencesStoreError.tooLarge }
        var invalidExisting = false
        do {
            if let existing = try Self.readBoundedFile(at: fileURL) {
                _ = try JSONDecoder().decode(FileMintPreferences.self, from: existing)
            }
        } catch { invalidExisting = true }
        if invalidExisting && !recoveringInvalidFile { throw FileMintPreferencesStoreError.recoveryRequired }
        let backup = invalidExisting ? directory.appendingPathComponent("preferences-recovery-\(UUID().uuidString).json") : nil
        if let backup { try StagedFileEntry.renameExclusive(fileURL, to: backup) }
        do {
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            if let backup { try? StagedFileEntry.renameExclusive(backup, to: fileURL) }
            throw error
        }
    }

    private static func readBoundedFile(at url: URL) throws -> Data? {
        guard url.isFileURL else { throw FileMintPreferencesStoreError.invalidFile }
        var before = stat()
        let status = url.withUnsafeFileSystemRepresentation { path in
            path.map { lstat($0, &before) } ?? -1
        }
        if status != 0 {
            if errno == ENOENT { return nil }
            throw FileMintPreferencesStoreError.invalidFile
        }
        guard before.st_mode & S_IFMT == S_IFREG, before.st_size >= 0 else {
            throw FileMintPreferencesStoreError.invalidFile
        }
        guard before.st_size <= Int64(maximumBytes) else { throw FileMintPreferencesStoreError.tooLarge }
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            path.map { open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC) } ?? -1
        }
        guard descriptor >= 0 else { throw FileMintPreferencesStoreError.invalidFile }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, opened.st_mode & S_IFMT == S_IFREG,
              opened.st_dev == before.st_dev, opened.st_ino == before.st_ino,
              opened.st_size <= Int64(maximumBytes) else { throw FileMintPreferencesStoreError.invalidFile }
        var data = Data()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            guard data.count <= maximumBytes - chunk.count else { throw FileMintPreferencesStoreError.tooLarge }
            data.append(chunk)
        }
        guard Int64(data.count) == opened.st_size else { throw FileMintPreferencesStoreError.invalidFile }
        return data
    }
}

public enum FileMintStorage {
    public static var directory: URL {
        DefaultFolders.resolvedUserHomeDirectory(fileManager: .default)
            .appendingPathComponent("Library/Application Support/FileMint", isDirectory: true)
    }
}

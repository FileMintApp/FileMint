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
    public var creationOpeningEnabled = false
    public var templatePreviewEnabled = false
    public var creationApplications: [CreationApplication] = []
    public var lastTemplateImportTransactionID: UUID? = nil
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
    public var creationMenuPlacements: [String: CreationMenuPlacement] = [:]
    public var templateMenuPlacements: [String: CreationMenuPlacement] = [:]
    public var menuIcons: [String: MenuIconCustomization] = [:]
    public var finderMenuIconStyle: FinderMenuIconStyle = .colored
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
        self.templates = templates.map { original in
            var template = original
            template.afterCreation = template.afterCreation ?? .basic(reveal: revealAfterCreation)
            return template
        }
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
        case creationOpeningEnabled, templatePreviewEnabled, creationApplications, lastTemplateImportTransactionID
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
        case newFileMenuPlacement, creationMenuPlacements, templateMenuPlacements
        case menuIcons
        case finderMenuIconStyle
    }

    public init(from decoder: Decoder) throws {
        let defaults = FileMintPreferences.default
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Missing fields belong to older settings. A present, damaged template
        // list must reach the store's recovery path, never become writable defaults.
        templates = container.contains(.templates)
            ? try container.decode([FileTemplate].self, forKey: .templates)
            : defaults.templates
        let savedTemplateIDs = Set(templates.map(\.id))
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
        let basicAction = TemplateCreationAction.basic(reveal: revealAfterCreation)
        templates = templates.map { original in
            var template = original
            template.afterCreation = template.afterCreation ?? basicAction
            return template
        }
        creationOpeningEnabled = (try? container.decode(Bool.self, forKey: .creationOpeningEnabled)) ?? false
        templatePreviewEnabled = (try? container.decode(Bool.self, forKey: .templatePreviewEnabled)) ?? false
        // A malformed registry entry cannot discard its valid neighbors.
        if var entries = try? container.nestedUnkeyedContainer(forKey: .creationApplications) {
            var ids = Set<UUID>()
            while !entries.isAtEnd {
                let entryDecoder = try entries.superDecoder()
                if let entry = try? CreationApplication(from: entryDecoder), ids.insert(entry.id).inserted,
                   entry.url.isFileURL, !entry.bookmark.isEmpty, !entry.hint.bundleIdentifier.isEmpty {
                    creationApplications.append(entry)
                }
            }
        }
        lastTemplateImportTransactionID = try? container.decode(UUID.self, forKey: .lastTemplateImportTransactionID)
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
        let legacyPlacement: CreationMenuPlacement = newFileMenuPlacement == .main ? .main : .submenu
        let actionPositions = (try? container.decode([String: RecoverableCreationMenuPlacement].self,
            forKey: .creationMenuPlacements)) ?? [:]
        for action in CreationMenuAction.allCases {
            if let value = actionPositions[action.rawValue]?.value { creationMenuPlacements[action.rawValue] = value }
            else if legacyPlacement != .submenu { creationMenuPlacements[action.rawValue] = legacyPlacement }
        }
        let templatePositions = (try? container.decode([String: RecoverableCreationMenuPlacement].self,
            forKey: .templateMenuPlacements)) ?? [:]
        for template in templates {
            if let value = templatePositions[template.id]?.value { templateMenuPlacements[template.id] = value }
            else if savedTemplateIDs.contains(template.id), legacyPlacement != .submenu {
                templateMenuPlacements[template.id] = legacyPlacement
            } else if !savedTemplateIDs.contains(template.id) {
                // Persist the migration default: after any store write this ID
                // becomes a saved template and must not inherit legacy main.
                templateMenuPlacements[template.id] = .submenu
            }
        }
        menuIcons = ((try? container.decode([String: MenuIconCustomization].self, forKey: .menuIcons)) ?? [:])
            .filter { MenuIconSlot(rawValue: $0.key) != nil }
        finderMenuIconStyle = (try? container.decode(FinderMenuIconStyle.self, forKey: .finderMenuIconStyle)) ?? .colored
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

public enum FileMintPreferencesStoreError: Error, Equatable, LocalizedError {
    case tooLarge, invalidFile, recoveryRequired, stalePreferences

    public var errorDescription: String? {
        switch self {
        case .tooLarge: "The settings file is too large. Keep it below 32 MiB."
        case .invalidFile: "The settings file is damaged or unavailable."
        case .recoveryRequired: "Saved settings could not be read. Import a valid settings file to recover them; the original is preserved."
        case .stalePreferences: "Settings changed while saving. Reload the current settings and try again."
        }
    }
}

public struct FileMintPreferencesLoadResult {
    public let preferences: FileMintPreferences
    public let requiresRecovery: Bool
}

public final class FileMintPreferencesStore {
    public static let maximumBytes = 32 * 1024 * 1024
    // The main app is the sole preferences writer. Share this lock across its
    // store instances, including background imports and folder authorization.
    private static let writeLock = NSRecursiveLock()
    private let fileURL: URL?

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileMintStorage.directory.appendingPathComponent("preferences.json")
    }

    public var location: URL? { fileURL }

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

    func withExclusiveAccess<T>(_ operation: () throws -> T) rethrows -> T {
        Self.writeLock.lock()
        defer { Self.writeLock.unlock() }
        return try operation()
    }

    public func update(_ mutation: (inout FileMintPreferences) throws -> Void) throws {
        try withExclusiveAccess {
            let loaded = loadWithStatus()
            guard !loaded.requiresRecovery else { throw FileMintPreferencesStoreError.recoveryRequired }
            var candidate = loaded.preferences
            try mutation(&candidate)
            try write(candidate, recoveringInvalidFile: false)
        }
    }

    public func save(_ preferences: FileMintPreferences, recoveringInvalidFile: Bool = false,
                     ifUnchangedFrom expected: FileMintPreferences? = nil) throws {
        try withExclusiveAccess {
            if let expected {
                let current = loadWithStatus()
                guard !current.requiresRecovery else { throw FileMintPreferencesStoreError.recoveryRequired }
                guard current.preferences == expected else { throw FileMintPreferencesStoreError.stalePreferences }
            }
            try write(preferences, recoveringInvalidFile: recoveringInvalidFile)
        }
    }

    private func write(_ preferences: FileMintPreferences, recoveringInvalidFile: Bool) throws {
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
            // Set private permissions before publication. A post-rename chmod
            // failure must not report a failed save after replacing preferences.
            let staging = directory.appendingPathComponent(".preferences-write-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: staging) }
            let output = staging.appendingPathComponent("preferences.json")
            try data.write(to: output, options: .withoutOverwriting)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
            let status = output.withUnsafeFileSystemRepresentation { source in
                fileURL.withUnsafeFileSystemRepresentation { destination in rename(source!, destination!) }
            }
            guard status == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
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

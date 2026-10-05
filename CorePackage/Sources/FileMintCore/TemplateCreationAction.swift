import Foundation

public struct CreationApplicationHint: Codable, Equatable, Sendable {
    public var bundleIdentifier: String
    public var displayName: String
    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
    public var isValid: Bool {
        !bundleIdentifier.isEmpty && bundleIdentifier.utf8.count <= 128 &&
        bundleIdentifier.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45,46,95].contains($0) } &&
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && displayName.utf8.count <= 1024
    }
}

public enum TemplateCreationActionError: Error, LocalizedError {
    case applicationRequired
    public var errorDescription: String? { TemplateWorkflowText.applicationRequired.text(.english) }
}

/// Separate from Finder application placement and terminal preferences.
public struct CreationApplication: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var hint: CreationApplicationHint
    public var url: URL
    public var bookmark: Data
    public init(id: UUID = UUID(), hint: CreationApplicationHint, url: URL, bookmark: Data) {
        self.id = id; self.hint = hint; self.url = url; self.bookmark = bookmark
    }
    public var openWithApplication: OpenWithApplication {
        .init(id: id, name: hint.displayName, bundleIdentifier: hint.bundleIdentifier, url: url, bookmark: bookmark)
    }
}

public struct TemplateCreationAction: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case none, revealInFinder, openWithDefaultApp, openWithApplication
    }
    public var kind: Kind
    public var application: CreationApplicationHint?
    public var localApplicationID: UUID?
    public init(_ kind: Kind, application: CreationApplicationHint? = nil, localApplicationID: UUID? = nil) {
        self.kind = kind
        self.application = kind == .openWithApplication ? application : nil
        self.localApplicationID = kind == .openWithApplication ? localApplicationID : nil
    }
    private enum CodingKeys: String, CodingKey { case kind, application, localApplicationID }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(Kind.self, forKey: .kind)
        application = kind == .openWithApplication ? try? values.decode(CreationApplicationHint.self, forKey: .application) : nil
        localApplicationID = kind == .openWithApplication ? try? values.decode(UUID.self, forKey: .localApplicationID) : nil
        try validate()
    }
    public var isValid: Bool { kind != .openWithApplication || application?.isValid == true }
    public func validate() throws {
        guard isValid else { throw TemplateCreationActionError.applicationRequired }
    }
    public static func basic(reveal: Bool) -> Self { .init(reveal ? .revealInFinder : .none) }
    public var opensApplication: Bool { kind == .openWithDefaultApp || kind == .openWithApplication }
    public var portable: Self { .init(kind, application: application) }
}

public enum CreationActionSelection: Equatable, Sendable {
    case followTemplate
    case override(TemplateCreationAction)
    public func resolve(template: FileTemplate?, fallback: TemplateCreationAction, enabled: Bool) -> TemplateCreationAction {
        guard enabled else { return fallback }
        switch self {
        case .followTemplate: return template?.afterCreation ?? fallback
        case .override(let action): return action
        }
    }
}

public struct CreationOpeningPermission: Equatable, Sendable {
    public let wasEnabled: Bool
    public let generation: UInt64
}

/// Update only after a successful preference commit.
public struct CreationOpeningGate: Sendable {
    public private(set) var isEnabled: Bool
    public private(set) var generation: UInt64 = 0
    public init(enabled: Bool) { isEnabled = enabled }
    public mutating func commit(enabled: Bool) {
        if isEnabled && !enabled { generation &+= 1 }
        isEnabled = enabled
    }
    public var permission: CreationOpeningPermission { .init(wasEnabled: isEnabled, generation: generation) }
    public func permits(_ permission: CreationOpeningPermission) -> Bool {
        permission.wasEnabled && isEnabled && permission.generation == generation
    }
}

public struct CreationFollowUp: Sendable {
    public let id: UUID
    public let action: TemplateCreationAction
    public let application: CreationApplication?
    public let permission: CreationOpeningPermission
    public let fallback: TemplateCreationAction
    public init(id: UUID = UUID(), selection: CreationActionSelection = .followTemplate,
                template: FileTemplate?, preferences: FileMintPreferences, gate: CreationOpeningGate) {
        self.id = id
        fallback = .basic(reveal: preferences.revealAfterCreation)
        let resolved = selection.resolve(template: template, fallback: fallback, enabled: gate.isEnabled)
        action = resolved
        application = preferences.creationApplications.first { $0.id == resolved.localApplicationID && $0.hint == resolved.application }
        permission = gate.permission
    }
}

public enum CreationEditingPolicy {
    /// Native text-editing profiles only. No default handler or executable fallback.
    public static func permits(bundleIdentifier: String, isDocument: Bool) -> Bool {
        !isDocument && ["com.apple.TextEdit", "com.microsoft.VSCode"].contains(bundleIdentifier)
    }
}

extension TemplateCatalog {
    public static func copyDraft(_ source: FileTemplate, copySuffix: String, id: String = "custom-\(UUID().uuidString)") -> FileTemplate {
        var copy = source
        copy.id = id; copy.displayName += " " + copySuffix; copy.isEnabled = true
        return copy
    }
    public static func preferencesInsertingCopy(_ copy: FileTemplate, after sourceID: String?, in original: FileMintPreferences) -> FileMintPreferences {
        var candidate = original
        let suffix = copy.fileExtension.lowercased()
        let previous = defaultTemplate(forExtension: suffix, in: original.templates, defaults: original.defaultTemplateIDs)
        candidate.templates = insertingCopy(copy, after: sourceID, in: original.templates)
        if candidate.defaultTemplateIDs[suffix] == nil, let previous,
           defaultTemplate(forExtension: suffix, in: candidate.templates)?.id != previous.id {
            candidate.defaultTemplateIDs[suffix] = previous.id
        }
        return candidate
    }
    public static func insertingCopy(_ copy: FileTemplate, after sourceID: String?, in templates: [FileTemplate]) -> [FileTemplate] {
        var ordered = sortedTemplates(from: templates)
        guard !ordered.contains(where: { $0.id == copy.id }) else { return ordered }
        let index = sourceID.flatMap { id in ordered.firstIndex { $0.id == id } }.map { $0 + 1 } ?? ordered.count
        ordered.insert(copy, at: index)
        return normalizedRanks(for: ordered)
    }
}

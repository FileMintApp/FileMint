import Foundation

public enum ExternalInvocationError: String, Error, Equatable, Sendable {
    case invalidRequest, unsupportedVersion, invalidFilename, templateUnavailable
    case contentTemplateMismatch, payloadTooLarge, existingDraft, busy, unavailable
    case destinationUnavailable, authorizationRequired, authorizationDenied
    case conflictingRequestID, alreadyHandled
}

public enum ExternalDraftLimits {
    public static let urlBytes = 16 * 1024
    public static let urlTextBytes = 8 * 1024
    public static let nativeTextBytes = 1024 * 1024
    public static let nameBytes = 1024
    public static let directoryBytes = 4 * 1024
    public static let identifierBytes = 256
}

public enum ExternalDraftContent: Equatable, Sendable {
    case templateDefault
    case verbatim(String)
}

public enum ExternalDraftDestination: Equatable, Sendable {
    case defaultLocation
    case directory(String)
    case favorite(UUID)
    case ask
}

/// Adapter provenance is deliberately absent: a public field cannot confer trust.
public struct ExternalDraftRequest: Equatable, Sendable {
    public let name: String?
    public let templateID: String?
    public let content: ExternalDraftContent
    public let destination: ExternalDraftDestination
    public let requestID: UUID?

    public init(name: String? = nil, templateID: String? = nil,
                content: ExternalDraftContent = .templateDefault,
                destination: ExternalDraftDestination = .defaultLocation,
                requestID: UUID? = nil) throws {
        if let name {
            guard name.utf8.count <= ExternalDraftLimits.nameBytes else { throw ExternalInvocationError.payloadTooLarge }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != ".", trimmed != "..", !trimmed.hasSuffix("."),
                  !name.contains(where: { "/:\\".contains($0) }),
                  !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw ExternalInvocationError.invalidFilename
            }
            self.name = trimmed
        } else { self.name = nil }
        if let templateID {
            guard templateID.utf8.count <= ExternalDraftLimits.identifierBytes else { throw ExternalInvocationError.payloadTooLarge }
            guard !templateID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !templateID.contains(where: { "/:\\".contains($0) }),
                  !templateID.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw ExternalInvocationError.invalidRequest
            }
        }
        self.templateID = templateID
        if case .verbatim(let text) = content {
            guard text.utf8.count <= ExternalDraftLimits.nativeTextBytes else { throw ExternalInvocationError.payloadTooLarge }
            guard !text.utf8.contains(0) else { throw ExternalInvocationError.invalidRequest }
        }
        self.content = content
        if case .directory(let path) = destination {
            guard path.utf8.count <= ExternalDraftLimits.directoryBytes else { throw ExternalInvocationError.payloadTooLarge }
            guard path.hasPrefix("/"),
                  !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw ExternalInvocationError.invalidRequest
            }
            // Lexical normalization only. Access, kind and identity remain native checks.
            self.destination = .directory(URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path)
        } else { self.destination = destination }
        self.requestID = requestID
    }

    public func resolve(preferences: FileMintPreferences, capturedAt: Date) throws -> ExternalDraftSeed {
        let templates = preferences.templates
        let explicitTemplate: FileTemplate?
        if let templateID {
            guard let template = templates.first(where: { $0.id == templateID && $0.isEnabled }) else {
                throw ExternalInvocationError.templateUnavailable
            }
            explicitTemplate = template
        } else { explicitTemplate = nil }
        var draft = CustomFileDraft(templates: templates, defaultTemplateIDs: preferences.defaultTemplateIDs,
                                    capturedAt: capturedAt)
        if let explicitTemplate {
            guard let suffix = FilenamePolicy.normalizedFileExtension(explicitTemplate.fileExtension),
                  draft.selectFormat(.init(fileExtension: suffix, templateID: explicitTemplate.id, aliases: []),
                                     templates: templates) else { throw ExternalInvocationError.templateUnavailable }
        }
        if let name, let suffix = FilenamePolicy.inferredFileExtension(from: name,
            knownExtensions: templates.map(\.fileExtension)) {
            if let explicitTemplate,
               suffix.caseInsensitiveCompare(explicitTemplate.fileExtension) != .orderedSame {
                throw ExternalInvocationError.invalidFilename
            }
            guard draft.updateExtensionInput(suffix, templates: templates) else { throw ExternalInvocationError.invalidFilename }
        }
        if case .verbatim(let text) = content {
            guard templates.first(where: { $0.id == draft.selectedTemplateID })?.document == nil else {
                throw ExternalInvocationError.contentTemplateMismatch
            }
            draft.updateContent(text)
        }
        let suggestedName = templates.first { $0.id == draft.selectedTemplateID }?.suggestedFileName
            ?? "Untitled.\(draft.extensionInput)"
        guard let fileName = FilenamePolicy.fileName(name ?? suggestedName, applyingFileExtension: draft.extensionInput) else {
            throw ExternalInvocationError.invalidFilename
        }
        return ExternalDraftSeed(fileName: fileName, draft: draft, hasExplicitName: name != nil)
    }
}

public struct ExternalDraftSeed: Equatable, Sendable {
    public let fileName: String
    public let draft: CustomFileDraft
    public let hasExplicitName: Bool
}

public enum ExternalInvocation: Equatable, Sendable {
    case draft(ExternalDraftRequest)
    case search
}

public enum ExternalSearchResult: String, Equatable, Sendable {
    case shown, alreadyVisible, busy, unavailable
}

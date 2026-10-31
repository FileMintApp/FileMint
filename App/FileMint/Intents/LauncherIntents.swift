import AppIntents
import FileMintCore
import UniformTypeIdentifiers

struct LauncherTemplateEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "File Template" }
    static var defaultQuery: LauncherTemplateQuery { LauncherTemplateQuery() }
    let id: String
    let name: String
    let suffix: String
    var displayRepresentation: DisplayRepresentation { .init(title: "\(name)", subtitle: ".\(suffix)") }
}

struct LauncherTemplateQuery: EntityStringQuery {
    @MainActor func suggestedEntities() async throws -> [LauncherTemplateEntity] {
        let runtime = ExternalInvocationCoordinator.shared
        return try await runtime.enabledTemplateSnapshot().map {
            LauncherTemplateEntity(id: $0.id, name: FileMintStrings.templateDisplayName(for: $0, language: runtime.language),
                                   suffix: $0.fileExtension)
        }
    }
    @MainActor func entities(for identifiers: [String]) async throws -> [LauncherTemplateEntity] {
        let ids = Set(identifiers)
        return try await suggestedEntities().filter { ids.contains($0.id) }
    }
    @MainActor func entities(matching string: String) async throws -> [LauncherTemplateEntity] {
        let entities = try await suggestedEntities()
        return string.isEmpty ? entities : entities.filter { ($0.name + " " + $0.suffix).localizedStandardContains(string) }
    }
}

struct LauncherFavoriteFolderEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Favorite Folder" }
    static var defaultQuery: LauncherFavoriteFolderQuery { LauncherFavoriteFolderQuery() }
    let id: String
    let name: String
    let parent: String
    let searchTerms: String
    var displayRepresentation: DisplayRepresentation { .init(title: "\(name)", subtitle: "\(parent)") }
}

struct LauncherFavoriteFolderQuery: EntityStringQuery {
    @MainActor func suggestedEntities() async throws -> [LauncherFavoriteFolderEntity] {
        try await ExternalInvocationCoordinator.shared.folderSnapshot().map {
            LauncherFavoriteFolderEntity(id: $0.id.uuidString, name: $0.name,
                parent: ($0.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath,
                searchTerms: $0.name + " " + $0.group + " " + $0.url.path)
        }
    }
    @MainActor func entities(for identifiers: [String]) async throws -> [LauncherFavoriteFolderEntity] {
        let ids = Set(identifiers.compactMap(UUID.init(uuidString:)))
        return try await suggestedEntities().filter { UUID(uuidString: $0.id).map(ids.contains) == true }
    }
    @MainActor func entities(matching string: String) async throws -> [LauncherFavoriteFolderEntity] {
        let entities = try await suggestedEntities()
        return string.isEmpty ? entities : entities.filter { $0.searchTerms.localizedStandardContains(string) }
    }
}

enum LauncherSaveLocation: String, AppEnum {
    case defaultLocation = "default", folder, favorite, ask
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Save Location" }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [.defaultLocation: "FileMint Default", .folder: "Specified Folder", .favorite: "Favorite Folder", .ask: "Choose in FileMint"]
    }
}

enum LauncherContentMode: String, AppEnum {
    case templateDefault = "template", text, empty
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Initial Content" }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [.templateDefault: "Template Content", .text: "Specified Text", .empty: "Empty Content"]
    }
}

private struct LauncherIntentFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// This single host-execution route begins on macOS 13.3. It never serializes
/// native text into a URL or waits for the user to finish creating a file.
@available(macOS 13.3, *)
struct OpenFileMintDraftIntent: ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Open File Draft"
    static let description = IntentDescription("Review a file draft in FileMint. Only choosing Create saves a file. For empty input, select Empty Content.")
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Template") var template: LauncherTemplateEntity?
    @Parameter(title: "Filename", inputOptions: .init(capitalizationType: .none, autocorrect: false, smartQuotes: false, smartDashes: false)) var name: String?
    @Parameter(title: "Save Location", default: .defaultLocation) var location: LauncherSaveLocation
    @Parameter(title: "Folder", supportedTypeIdentifiers: ["public.folder"]) var folder: IntentFile?
    @Parameter(title: "Favorite Folder") var favorite: LauncherFavoriteFolderEntity?
    @Parameter(title: "Initial Content", default: .templateDefault) var content: LauncherContentMode
    @Parameter(title: "Text", inputOptions: .init(capitalizationType: .none, multiline: true, autocorrect: false, smartQuotes: false, smartDashes: false)) var text: String?

    static var parameterSummary: some ParameterSummary {
        Switch(\.$location) {
            Case(.folder) {
                When(\.$content, .equalTo, .text) {
                    Summary("Open draft \(\.$name) using \(\.$template)") { \.$location; \.$folder; \.$content; \.$text }
                } otherwise: {
                    Summary("Open draft \(\.$name) using \(\.$template)") { \.$location; \.$folder; \.$content }
                }
            }
            Case(.favorite) {
                When(\.$content, .equalTo, .text) {
                    Summary("Open draft \(\.$name) using \(\.$template)") { \.$location; \.$favorite; \.$content; \.$text }
                } otherwise: {
                    Summary("Open draft \(\.$name) using \(\.$template)") { \.$location; \.$favorite; \.$content }
                }
            }
            DefaultCase {
                When(\.$content, .equalTo, .text) {
                    Summary("Open draft \(\.$name) using \(\.$template)") { \.$location; \.$content; \.$text }
                } otherwise: {
                    Summary("Open draft \(\.$name) using \(\.$template)") { \.$location; \.$content }
                }
            }
        }
    }

    func requestInput() throws -> (request: ExternalDraftRequest, nativeGrantURL: URL?) {
        // Shortcuts keeps hidden parameter values after a mode switch.
        // Only the explicitly selected mode contributes to the typed input.
        let destination: ExternalDraftDestination
        var nativeURL: URL?
        switch location {
        case .defaultLocation, .ask:
            destination = location == .ask ? .ask : .defaultLocation
        case .folder:
            guard let folder, let url = folder.fileURL,
                  !folder.removedOnCompletion, OpenWithPolicy.isLocalFileURL(url) else {
                throw ExternalInvocationError.invalidRequest
            }
            if let type = folder.type, !type.conforms(to: .directory), type != .item { throw ExternalInvocationError.invalidRequest }
            destination = .directory(url.path)
            nativeURL = url
        case .favorite:
            guard let favorite, let id = UUID(uuidString: favorite.id) else { throw ExternalInvocationError.invalidRequest }
            destination = .favorite(id)
        }
        let body: ExternalDraftContent
        switch content {
        case .templateDefault:
            body = .templateDefault
        case .text:
            guard let text else { throw ExternalInvocationError.invalidRequest }
            body = .verbatim(text)
        case .empty:
            body = .verbatim("")
        }
        let request = try ExternalDraftRequest(name: name?.isEmpty == true ? nil : name, templateID: template?.id,
                                               content: body, destination: destination)
        return (request, nativeURL)
    }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let runtime = ExternalInvocationCoordinator.shared
        do {
            try Task.checkCancellation()
            let input = try requestInput()
            _ = try await runtime.openDraft(input.request, source: .shortcuts, nativeGrantURL: input.nativeGrantURL)
            return .result(value: LauncherText.draftOpened.text(runtime.language))
        } catch is CancellationError { throw CancellationError() }
        catch {
            let code = error as? ExternalInvocationError ?? .unavailable
            throw LauncherIntentFailure(message: code.message(runtime.language))
        }
    }
}

@available(macOS 13.3, *)
struct ShowFileMintQuickSearchIntent: ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Show Quick Search"
    static let description = IntentDescription("Show or focus FileMint Quick Search. This action keeps an unfinished query and never toggles the panel closed.")
    static var openAppWhenRun: Bool { false }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let runtime = ExternalInvocationCoordinator.shared
        do {
            switch try await runtime.showSearch() {
            case .shown: return .result(value: LauncherText.searchShown.text(runtime.language))
            case .alreadyVisible: return .result(value: LauncherText.searchFocused.text(runtime.language))
            case .busy: throw ExternalInvocationError.busy
            case .unavailable: throw ExternalInvocationError.unavailable
            }
        } catch is CancellationError { throw CancellationError() }
        catch {
            throw LauncherIntentFailure(message: (error as? ExternalInvocationError ?? .unavailable).message(runtime.language))
        }
    }
}

@available(macOS 13.3, *)
struct FileMintLauncherShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenFileMintDraftIntent(), phrases: ["Open a file draft in \(.applicationName)"],
                    shortTitle: "Open File Draft", systemImageName: "doc.badge.plus")
        AppShortcut(intent: ShowFileMintQuickSearchIntent(), phrases: ["Show Quick Search in \(.applicationName)"],
                    shortTitle: "Show Quick Search", systemImageName: "magnifyingglass")
    }
}

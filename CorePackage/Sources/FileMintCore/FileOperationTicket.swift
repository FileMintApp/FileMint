import Foundation

public enum FileOperationRequest: Codable, Equatable, Sendable {
    case prepare([URL])
    case permanentDelete(items: [FileMoveItem], confirmation: DeleteConfirmation)
    case airDrop([URL])
    case desktopAlias([FileMoveItem])
    case batchRename(selection: BatchRenameSelection)
    case fileInfo(FileInfoSelection)
    case defaultApplication(DefaultApplicationSelection)
    case copyContents(selection: FileInfoSelection, pasteboardChangeCount: Int)
    case toggleHiddenFiles(directory: URL)
    case resource(tool: ResourceTool, selection: [URL])
    case openWith(application: OpenWithApplicationReference, selection: [URL])
    case openDirectory(application: OpenWithApplicationReference, directory: URL, mode: TerminalOpenMode)
    case favoriteAdd([URL])
    case favoriteLocate(UUID)
    case favoriteSearch
    case perform(batchID: UUID, destination: URL)

    fileprivate var ticketHost: String {
        switch self {
        case .batchRename: "rename"
        case .fileInfo: "file-info"
        case .defaultApplication: "default-application"
        case .copyContents: "copy-contents"
        case .toggleHiddenFiles: "toggle-hidden-files"
        default: "move"
        }
    }
}

private struct FileOperationTicket: Codable {
    let request: FileOperationRequest
    let issuedAt: Date
}

public enum FileOperationTicketError: Error, Equatable, Sendable {
    case batchRenameSelectionLimit, batchRenameTicketLimit

    public var messageKey: FileMintTextKey {
        switch self {
        case .batchRenameSelectionLimit: .batchRenameSelectionLimit
        case .batchRenameTicketLimit: .batchRenameTicketLimit
        }
    }
}

/// Preserve the existing private transport location and URL route; the ticket
/// payload now describes all main-app file operations, not only moves.
public struct FileOperationTicketStore: Sendable {
    private let directory: URL
    public init(directory: URL = FileMintStorage.directory.appendingPathComponent("move-requests")) {
        self.directory = directory
    }

    public func enqueue(_ request: FileOperationRequest, now: Date = Date()) throws -> URL {
        if case .batchRename(let selection) = request {
            guard FileToolsPolicy.canBatchRename(selection.items.map(\.source)) else {
                throw FileOperationTicketError.batchRenameSelectionLimit
            }
        }
        let data = try JSONEncoder().encode(FileOperationTicket(request: request, issuedAt: now))
        guard data.count <= 1_048_576 else {
            if case .batchRename = request { throw FileOperationTicketError.batchRenameTicketLimit }
            throw FileMoveError.invalidSelection
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let id = UUID()
        let file = directory.appendingPathComponent("\(id.uuidString).json")
        try data.write(to: file, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return URL(string: "filemint://\(request.ticketHost)?id=\(id.uuidString)")!
    }

    /// Separate intake lets the app consume rename requests immediately while
    /// retaining the existing queued consumption behavior for other operations.
    public static func isBatchRenameURL(_ url: URL) -> Bool {
        ticketID(url, expectedHost: "rename") != nil
    }

    public static func isFileInfoURL(_ url: URL) -> Bool {
        ticketID(url, expectedHost: "file-info") != nil
    }

    public static func isDefaultApplicationURL(_ url: URL) -> Bool {
        ticketID(url, expectedHost: "default-application") != nil
    }

    public static func isCopyContentsURL(_ url: URL) -> Bool {
        ticketID(url, expectedHost: "copy-contents") != nil
    }

    public static func isToggleHiddenFilesURL(_ url: URL) -> Bool {
        ticketID(url, expectedHost: "toggle-hidden-files") != nil
    }

    public static func handlesRoute(_ url: URL) -> Bool {
        url.scheme == "filemint" && ["move", "rename", "file-info", "default-application",
                                     "copy-contents", "toggle-hidden-files"].contains(url.host ?? "")
    }

    public func consume(_ url: URL, now: Date = Date()) throws -> FileOperationRequest? {
        guard Self.handlesRoute(url), let host = url.host,
              let id = Self.ticketID(url, expectedHost: host) else { return nil }
        let source = directory.appendingPathComponent("\(id.uuidString).json")
        let claimed = directory.appendingPathComponent("\(id.uuidString).consumed")
        guard let info = try? source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              info.isRegularFile == true, info.isSymbolicLink == false,
              let size = info.fileSize, size <= 1_048_576 else { return nil }
        do { try FileManager.default.moveItem(at: source, to: claimed) }
        catch CocoaError.fileNoSuchFile { return nil }
        defer { try? FileManager.default.removeItem(at: claimed) }
        let ticket = try JSONDecoder().decode(FileOperationTicket.self, from: Data(contentsOf: claimed))
        guard (0...60).contains(now.timeIntervalSince(ticket.issuedAt)), ticket.request.ticketHost == host else { return nil }
        return ticket.request
    }

    private static func ticketID(_ url: URL, expectedHost: String) -> UUID? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "filemint", parts.host == expectedHost, parts.path.isEmpty,
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil,
              parts.queryItems?.count == 1, let item = parts.queryItems?.first,
              item.name == "id", let value = item.value, let id = UUID(uuidString: value) else { return nil }
        return id
    }
}

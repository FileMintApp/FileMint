import Foundation

public enum FileOperationRequest: Codable, Equatable, Sendable {
    case prepare([URL])
    case permanentDelete(items: [FileMoveItem], confirmation: DeleteConfirmation)
    case airDrop([URL])
    case desktopAlias([FileMoveItem])
    case batchRename(selection: BatchRenameSelection)
    case fileInfo(FileInfoSelection)
    case copyContents(selection: FileInfoSelection, pasteboardChangeCount: Int)
    case fileVisibility(items: [FileInfoSelection], action: FileVisibilityAction)
    case resource(tool: ResourceTool, selection: [URL])
    case openWith(application: OpenWithApplicationReference, selection: [URL])
    case openDirectory(application: OpenWithApplicationReference, directory: URL, mode: TerminalOpenMode)
    case favoriteAdd([URL])
    case favoriteLocate(UUID)
    case favoriteSearch
    case perform(batchID: UUID, destination: URL)
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
        if case .fileVisibility(let items, _) = request,
           !FileVisibilityPolicy.canSelect(items.map(\.source)) { throw FileVisibilityError.invalidSelection }
        let isBatchRename: Bool
        if case .batchRename(let selection) = request {
            guard FileToolsPolicy.canBatchRename(selection.items.map(\.source)) else {
                throw FileOperationTicketError.batchRenameSelectionLimit
            }
            isBatchRename = true
        } else { isBatchRename = false }
        let data = try JSONEncoder().encode(FileOperationTicket(request: request, issuedAt: now))
        guard data.count <= 1_048_576 else {
            if isBatchRename { throw FileOperationTicketError.batchRenameTicketLimit }
            throw FileMoveError.invalidSelection
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let id = UUID()
        let file = directory.appendingPathComponent("\(id.uuidString).json")
        try data.write(to: file, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        let route: String
        if case .copyContents = request { route = "copy-contents" }
        else if case .fileInfo = request { route = "file-info" }
        else { route = isBatchRename ? "rename" : "move" }
        return URL(string: "filemint://\(route)?id=\(id.uuidString)")!
    }

    /// Separate intake lets the app consume rename requests immediately while
    /// retaining the existing queued consumption behavior for other operations.
    public static func isBatchRenameURL(_ url: URL) -> Bool {
        ticketID(url, expectedHost: "rename") != nil
    }

    public static func isFileInfoURL(_ url: URL) -> Bool {
        ticketID(url, expectedHost: "file-info") != nil
    }

    public static func isCopyContentsURL(_ url: URL) -> Bool {
        ticketID(url, expectedHost: "copy-contents") != nil
    }

    public func consume(_ url: URL, now: Date = Date()) throws -> FileOperationRequest? {
        let isBatchRename = Self.isBatchRenameURL(url)
        let isFileInfo = Self.isFileInfoURL(url)
        let isCopyContents = Self.isCopyContentsURL(url)
        let host = isBatchRename ? "rename" : isFileInfo ? "file-info" : isCopyContents ? "copy-contents" : "move"
        guard let id = Self.ticketID(url, expectedHost: host) else { return nil }
        let source = directory.appendingPathComponent("\(id.uuidString).json")
        let claimed = directory.appendingPathComponent("\(id.uuidString).consumed")
        guard let info = try? source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              info.isRegularFile == true, info.isSymbolicLink == false,
              let size = info.fileSize, size <= 1_048_576 else { return nil }
        do { try FileManager.default.moveItem(at: source, to: claimed) }
        catch CocoaError.fileNoSuchFile { return nil }
        defer { try? FileManager.default.removeItem(at: claimed) }
        let ticket = try JSONDecoder().decode(FileOperationTicket.self, from: Data(contentsOf: claimed))
        guard (0...60).contains(now.timeIntervalSince(ticket.issuedAt)) else { return nil }
        if case .fileVisibility(let items, _) = ticket.request,
           !FileVisibilityPolicy.canSelect(items.map(\.source)) { return nil }
        if case .batchRename = ticket.request {
            guard isBatchRename else { return nil }
        } else if case .fileInfo = ticket.request {
            guard isFileInfo else { return nil }
        } else if case .copyContents = ticket.request {
            guard isCopyContents else { return nil }
        } else if isBatchRename || isFileInfo || isCopyContents { return nil }
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

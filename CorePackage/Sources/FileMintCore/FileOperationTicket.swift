import Foundation

public enum FileOperationRequest: Codable, Equatable, Sendable {
    case prepare([URL])
    case permanentDelete(items: [FileMoveItem], confirmation: DeleteConfirmation)
    case airDrop([URL])
    case desktopAlias([FileMoveItem])
    case resource(tool: ResourceTool, selection: [URL])
    case perform(batchID: UUID, destination: URL)
}

private struct FileOperationTicket: Codable {
    let request: FileOperationRequest
    let issuedAt: Date
}

/// Preserve the existing private transport location and URL route; the ticket
/// payload now describes all main-app file operations, not only moves.
public struct FileOperationTicketStore: Sendable {
    private let directory: URL
    public init(directory: URL = FileMintStorage.directory.appendingPathComponent("move-requests")) {
        self.directory = directory
    }

    public func enqueue(_ request: FileOperationRequest, now: Date = Date()) throws -> URL {
        let data = try JSONEncoder().encode(FileOperationTicket(request: request, issuedAt: now))
        guard data.count <= 1_048_576 else { throw FileMoveError.invalidSelection }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let id = UUID()
        let file = directory.appendingPathComponent("\(id.uuidString).json")
        try data.write(to: file, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return URL(string: "filemint://move?id=\(id.uuidString)")!
    }

    public func consume(_ url: URL, now: Date = Date()) throws -> FileOperationRequest? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "filemint", parts.host == "move", parts.path.isEmpty,
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil,
              parts.queryItems?.count == 1, let item = parts.queryItems?.first,
              item.name == "id", let value = item.value, let id = UUID(uuidString: value) else { return nil }
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
        return ticket.request
    }
}

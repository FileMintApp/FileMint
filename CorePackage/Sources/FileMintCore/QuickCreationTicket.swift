import Foundation

public struct QuickCreationTicket: Codable, Sendable {
    public let directory: URL
    public let templateID: String
    public let issuedAt: Date
    public var clipboardImage: Bool? = nil
}

/// A URL contains only an unpredictable, expiring identifier. Actual requests
/// live in FileMint's private directory, accessible to its sandboxed targets.
public struct QuickCreationTicketStore: Sendable {
    private let directory: URL
    public init(directory: URL = FileMintStorage.directory.appendingPathComponent("requests")) {
        self.directory = directory
    }

    public func enqueue(directory destination: URL, templateID: String, now: Date = Date()) throws -> URL {
        try enqueue(QuickCreationTicket(directory: destination, templateID: templateID, issuedAt: now))
    }

    public func enqueueClipboardImage(directory destination: URL, now: Date = Date()) throws -> URL {
        try enqueue(QuickCreationTicket(directory: destination, templateID: "", issuedAt: now, clipboardImage: true))
    }

    private func enqueue(_ ticket: QuickCreationTicket) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let id = UUID().uuidString
        let data = try JSONEncoder().encode(ticket)
        let file = directory.appendingPathComponent("\(id).json")
        try data.write(to: file, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return URL(string: "filemint://quick?id=\(id)")!
    }

    public func consume(_ url: URL, preferences: FileMintPreferences, now: Date = Date()) throws -> QuickCreationTicket? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "filemint", parts.host == "quick", parts.path.isEmpty, parts.fragment == nil,
              parts.queryItems?.count == 1, let item = parts.queryItems?.first, item.name == "id",
              let value = item.value, let uuid = UUID(uuidString: value) else { return nil }
        let source = directory.appendingPathComponent("\(uuid.uuidString).json")
        let claimed = directory.appendingPathComponent("\(uuid.uuidString).consumed")
        guard let attributes = try? source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              attributes.isRegularFile == true, attributes.isSymbolicLink == false,
              let size = attributes.fileSize, size <= 8192 else { return nil }
        do { try FileManager.default.moveItem(at: source, to: claimed) }
        catch CocoaError.fileNoSuchFile { return nil }
        defer { try? FileManager.default.removeItem(at: claimed) }
        let data = try Data(contentsOf: claimed)
        let ticket = try JSONDecoder().decode(QuickCreationTicket.self, from: data)
        guard (0...60).contains(now.timeIntervalSince(ticket.issuedAt)), ticket.directory.isFileURL,
              ticket.clipboardImage == true || preferences.templates.contains(where: { $0.id == ticket.templateID && $0.isEnabled }) else { return nil }
        guard FolderScope.containsResolvedDirectory(ticket.directory, in: preferences.monitoredFolderURLs) else { return nil }
        return ticket
    }
}

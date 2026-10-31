import Foundation

/// Strict parsing applies to the representation actually delivered by AppKit.
/// Foundation may already have normalized the caller's original URL spelling.
public enum ExternalDraftRoute {
    private static let draftFields: Set<String> = ["v", "name", "template", "text", "directory", "favorite", "location", "id"]

    public static func parse(_ received: String) throws -> ExternalInvocation {
        guard received.utf8.count <= ExternalDraftLimits.urlBytes else { throw ExternalInvocationError.payloadTooLarge }
        guard received.utf8.allSatisfy({ (33...126).contains($0) }), !received.contains("#"),
              let separator = received.firstIndex(of: "?") else { throw ExternalInvocationError.invalidRequest }
        let action = received[..<separator]
        guard action == "filemint://draft" || action == "filemint://search" else { throw ExternalInvocationError.invalidRequest }
        let allowed: Set<String> = action == "filemint://draft" ? draftFields : ["v"]
        var fields: [String: String] = [:]
        for field in received[received.index(after: separator)...].split(separator: "&", omittingEmptySubsequences: false) {
            guard let equal = field.firstIndex(of: "=") else { throw ExternalInvocationError.invalidRequest }
            let key = String(field[..<equal])
            guard allowed.contains(key), fields[key] == nil else { throw ExternalInvocationError.invalidRequest }
            fields[key] = try decode(field[field.index(after: equal)...])
        }
        guard let version = fields["v"] else { throw ExternalInvocationError.invalidRequest }
        guard version == "1" else { throw ExternalInvocationError.unsupportedVersion }
        if action == "filemint://search" { return .search }
        guard ["directory", "favorite", "location"].filter({ fields[$0] != nil }).count <= 1 else {
            throw ExternalInvocationError.invalidRequest
        }
        let destination: ExternalDraftDestination
        if let path = fields["directory"] { destination = .directory(path) }
        else if let value = fields["favorite"] {
            guard value.utf8.count <= ExternalDraftLimits.identifierBytes else { throw ExternalInvocationError.payloadTooLarge }
            guard let id = UUID(uuidString: value) else { throw ExternalInvocationError.invalidRequest }
            destination = .favorite(id)
        } else if let value = fields["location"] {
            guard value == "ask" else { throw ExternalInvocationError.invalidRequest }
            destination = .ask
        } else { destination = .defaultLocation }
        let requestID: UUID?
        if let value = fields["id"] {
            guard let id = UUID(uuidString: value) else { throw ExternalInvocationError.invalidRequest }
            requestID = id
        } else { requestID = nil }
        if let text = fields["text"], text.utf8.count > ExternalDraftLimits.urlTextBytes {
            throw ExternalInvocationError.payloadTooLarge
        }
        return .draft(try ExternalDraftRequest(name: fields["name"], templateID: fields["template"],
            content: fields["text"].map(ExternalDraftContent.verbatim) ?? .templateDefault,
            destination: destination, requestID: requestID))
    }

    public static func string(for invocation: ExternalInvocation) throws -> String {
        guard case .draft(let request) = invocation else { return "filemint://search?v=1" }
        var fields = [("v", "1")]
        if let name = request.name { fields.append(("name", name)) }
        if let template = request.templateID { fields.append(("template", template)) }
        if case .verbatim(let text) = request.content {
            guard text.utf8.count <= ExternalDraftLimits.urlTextBytes else { throw ExternalInvocationError.payloadTooLarge }
            fields.append(("text", text))
        }
        switch request.destination {
        case .defaultLocation: break
        case .directory(let path): fields.append(("directory", path))
        case .favorite(let id): fields.append(("favorite", id.uuidString))
        case .ask: fields.append(("location", "ask"))
        }
        if let id = request.requestID { fields.append(("id", id.uuidString)) }
        let encoded = "filemint://draft?" + fields.map { $0.0 + "=" + encode($0.1) }.joined(separator: "&")
        guard encoded.utf8.count <= ExternalDraftLimits.urlBytes else { throw ExternalInvocationError.payloadTooLarge }
        return encoded
    }

    private static func decode(_ value: Substring) throws -> String {
        let input = Array(value.utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(input.count)
        var index = 0
        while index < input.count {
            if input[index] == 37 {
                guard index + 2 < input.count, let high = hex(input[index + 1]), let low = hex(input[index + 2]) else {
                    throw ExternalInvocationError.invalidRequest
                }
                bytes.append(high * 16 + low)
                index += 3
            } else { bytes.append(input[index]); index += 1 }
        }
        guard let decoded = String(bytes: bytes, encoding: .utf8), !bytes.contains(0) else {
            throw ExternalInvocationError.invalidRequest
        }
        return decoded
    }

    private static func encode(_ value: String) -> String {
        let allowed: Set<UInt8> = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)
        return value.utf8.map { allowed.contains($0) ? String(UnicodeScalar($0)) : String(format: "%%%02X", $0) }.joined()
    }

    private static func hex(_ value: UInt8) -> UInt8? {
        switch value {
        case 48...57: value - 48
        case 65...70: value - 55
        case 97...102: value - 87
        default: nil
        }
    }
}

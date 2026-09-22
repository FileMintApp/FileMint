import Foundation
import zlib

public enum OfficeDocumentKind: String, Codable, Sendable {
    case docx, xlsx
    var mainContentType: String {
        "application/vnd.openxmlformats-officedocument." + (self == .docx
            ? "wordprocessingml.document.main+xml" : "spreadsheetml.sheet.main+xml")
    }
}

public enum DocumentTemplateError: Error, LocalizedError {
    case unsupported, tooLarge, invalidDocument, unavailable
    public var textKey: FileMintTextKey {
        switch self {
        case .unsupported: .documentUnsupported
        case .tooLarge: .documentTooLarge
        case .invalidDocument: .documentInvalid
        case .unavailable: .documentUnavailable
        }
    }
    public var errorDescription: String? {
        switch self {
        case .unsupported: "Choose a regular DOCX or XLSX document."
        case .tooLarge: "This document exceeds the supported size limits."
        case .invalidDocument: "This is not a supported, intact Office document."
        case .unavailable: "The template copy is missing or damaged. Remove it and import the document again."
        }
    }
}

/// Reads ZIP structures in memory, never extracting a package or following its
/// relationships outside the archive. zlib is supplied by macOS.
public enum OfficeDocumentValidator {
    public static let maximumBytes = 64 * 1024 * 1024

    public static func validate(_ data: Data, kind: OfficeDocumentKind) throws {
        guard data.count <= maximumBytes else { throw DocumentTemplateError.tooLarge }
        let zip = OfficeZIP(data: data)
        let entries = try zip.entries()
        var xml: [String: OfficeXML] = [:]
        for entry in entries {
            let content = try zip.content(entry)
            if entry.name.lowercased().hasSuffix("vbaproject.bin") { throw DocumentTemplateError.unsupported }
            if entry.name.hasSuffix(".xml") || entry.name.hasSuffix(".rels") {
                xml[entry.name] = try OfficeXML.read(content)
            }
        }
        guard let types = xml["[Content_Types].xml"], types.root == "Types",
              types.namespace == "http://schemas.openxmlformats.org/package/2006/content-types",
              let relationships = xml["_rels/.rels"], relationships.root == "Relationships",
              relationships.namespace == "http://schemas.openxmlformats.org/package/2006/relationships" else {
            throw DocumentTemplateError.invalidDocument
        }
        guard !types.contentTypes.values.contains(where: { $0.lowercased().contains("macroenabled") || $0.lowercased().contains("vbaproject") }),
              let main = relationships.relationships.values.first(where: { relationshipType($0.type, is: "officeDocument") && !$0.external }),
              let path = partPath(main.target, relativeTo: ""),
              types.contentTypes["/" + path] == kind.mainContentType,
              let document = xml[path] else { throw DocumentTemplateError.invalidDocument }
        if kind == .docx {
            guard document.root == "document", document.hasBody,
                  ["http://schemas.openxmlformats.org/wordprocessingml/2006/main", "http://purl.oclc.org/ooxml/wordprocessingml/main"].contains(document.namespace) else {
                throw DocumentTemplateError.invalidDocument
            }
        } else {
            let parent = (path as NSString).deletingLastPathComponent
            let relPath = (parent.isEmpty ? "" : parent + "/") + "_rels/" + (path as NSString).lastPathComponent + ".rels"
            guard document.root == "workbook", !document.sheetIDs.isEmpty,
                  ["http://schemas.openxmlformats.org/spreadsheetml/2006/main", "http://purl.oclc.org/ooxml/spreadsheetml/main"].contains(document.namespace),
                  let rels = xml[relPath], rels.root == "Relationships",
                  rels.namespace == relationships.namespace,
                  Set(document.sheetIDs).count == document.sheetIDs.count else { throw DocumentTemplateError.invalidDocument }
            for id in document.sheetIDs {
                guard let rel = rels.relationships[id], !rel.external,
                      let sheetPath = partPath(rel.target, relativeTo: parent),
                      let sheet = xml[sheetPath],
                      sheet.namespace == document.namespace,
                      (relationshipType(rel.type, is: "worksheet") && sheet.root == "worksheet")
                        || (relationshipType(rel.type, is: "chartsheet") && sheet.root == "chartsheet") else {
                    throw DocumentTemplateError.invalidDocument
                }
            }
        }
    }

    private static func relationshipType(_ value: String, is suffix: String) -> Bool {
        ["http://schemas.openxmlformats.org/officeDocument/2006/relationships/", "http://purl.oclc.org/ooxml/officeDocument/relationships/"]
            .contains { value == $0 + suffix }
    }

    private static func partPath(_ target: String, relativeTo parent: String) -> String? {
        guard let decoded = target.removingPercentEncoding, !decoded.contains(":"), !decoded.contains("\\"),
              !decoded.contains("?"), !decoded.contains("#") else { return nil }
        let value = decoded.hasPrefix("/") ? String(decoded.dropFirst()) : (parent.isEmpty ? decoded : parent + "/" + decoded)
        var pieces: [Substring] = []
        for piece in value.split(separator: "/") {
            if piece == "." { continue }
            if piece == ".." { guard !pieces.isEmpty else { return nil }; pieces.removeLast() }
            else { pieces.append(piece) }
        }
        return pieces.isEmpty ? nil : pieces.joined(separator: "/")
    }
}

private struct OfficeZIP {
    let data: Data
    struct Entry {
        let name: String
        let method: Int
        let flags: Int
        let checksum: UInt32
        let compressed: Int
        let expanded: Int
        let offset: Int
    }

    func number(_ offset: Int, _ length: Int) throws -> Int {
        guard offset >= 0, offset <= data.count - length else { throw DocumentTemplateError.invalidDocument }
        return (0..<length).reduce(0) { $0 | (Int(data[offset + $1]) << ($1 * 8)) }
    }

    func entries() throws -> [Entry] {
        guard data.count >= 22 else { throw DocumentTemplateError.invalidDocument }
        let footer = try stride(from: data.count - 22, through: max(0, data.count - 65_557), by: -1).first {
            try number($0, 4) == 0x06054b50 && $0 + 22 + number($0 + 20, 2) == data.count
        }
        guard let footer, try number(footer + 4, 2) == 0, try number(footer + 6, 2) == 0 else {
            throw DocumentTemplateError.invalidDocument
        }
        let count = try number(footer + 10, 2)
        guard (1...4096).contains(count), try number(footer + 8, 2) == count else { throw DocumentTemplateError.tooLarge }
        var cursor = try number(footer + 16, 4)
        let end = try cursor + number(footer + 12, 4)
        guard end == footer else { throw DocumentTemplateError.invalidDocument }
        var entries: [Entry] = [], names = Set<String>(), total = 0
        for _ in 0..<count {
            guard cursor + 46 <= end, try number(cursor, 4) == 0x02014b50 else { throw DocumentTemplateError.invalidDocument }
            let flags = try number(cursor + 8, 2), method = try number(cursor + 10, 2)
            let compressed = try number(cursor + 20, 4), expanded = try number(cursor + 24, 4)
            let length = try number(cursor + 28, 2), extra = try number(cursor + 30, 2), comment = try number(cursor + 32, 2)
            let offset = try number(cursor + 42, 4)
            total += expanded
            guard expanded <= OfficeDocumentValidator.maximumBytes, total <= 128 * 1024 * 1024 else { throw DocumentTemplateError.tooLarge }
            guard flags & 0x41 == 0, [0, 8].contains(method), try number(cursor + 6, 2) <= 20, compressed <= data.count,
                  offset < cursor, try number(cursor + 34, 2) == 0,
                  cursor + 46 + length + extra + comment <= end,
                  let name = String(data: data.subdata(in: cursor + 46..<cursor + 46 + length), encoding: .utf8),
                  !name.isEmpty, !name.hasPrefix("/"), !name.contains("\\"), !name.contains(":"),
                  !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  !name.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }), names.insert(name).inserted else {
                throw DocumentTemplateError.invalidDocument
            }
            let entry = Entry(name: name, method: method, flags: flags, checksum: UInt32(try number(cursor + 16, 4)),
                              compressed: compressed, expanded: expanded, offset: offset)
            // Local data cannot overlap the central directory.
            let start = try offset + 30 + number(offset + 26, 2) + number(offset + 28, 2)
            guard start + compressed <= (try number(footer + 16, 4)) else { throw DocumentTemplateError.invalidDocument }
            entries.append(entry)
            cursor += 46 + length + extra + comment
        }
        guard cursor == end else { throw DocumentTemplateError.invalidDocument }
        return entries
    }

    func content(_ entry: Entry) throws -> Data {
        let offset = entry.offset
        guard try number(offset, 4) == 0x04034b50, try number(offset + 6, 2) == entry.flags,
              try number(offset + 4, 2) <= 20,
              try number(offset + 8, 2) == entry.method else { throw DocumentTemplateError.invalidDocument }
        let localCompressed = try number(offset + 18, 4), localExpanded = try number(offset + 22, 4)
        guard localCompressed != 0xffff_ffff, localExpanded != 0xffff_ffff else { throw DocumentTemplateError.invalidDocument }
        if entry.flags & 8 == 0 {
            guard localCompressed == entry.compressed, localExpanded == entry.expanded,
                  try number(offset + 14, 4) == entry.checksum else { throw DocumentTemplateError.invalidDocument }
        }
        let length = try number(offset + 26, 2), extra = try number(offset + 28, 2)
        let start = offset + 30 + length + extra
        guard start + entry.compressed <= data.count,
              String(data: data.subdata(in: offset + 30..<offset + 30 + length), encoding: .utf8) == entry.name else {
            throw DocumentTemplateError.invalidDocument
        }
        let compressed = data.subdata(in: start..<start + entry.compressed)
        let result: Data
        if entry.method == 0 {
            guard compressed.count == entry.expanded else { throw DocumentTemplateError.invalidDocument }
            result = compressed
        } else {
            var stream = z_stream()
            guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                throw DocumentTemplateError.invalidDocument
            }
            defer { inflateEnd(&stream) }
            var output = Data(count: max(1, entry.expanded))
            let status = output.withUnsafeMutableBytes { destination in
                compressed.withUnsafeBytes { source in
                    stream.next_in = UnsafeMutablePointer(mutating: source.bindMemory(to: Bytef.self).baseAddress)
                    stream.avail_in = uInt(compressed.count)
                    stream.next_out = destination.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(max(1, entry.expanded))
                    return inflate(&stream, Z_FINISH)
                }
            }
            guard status == Z_STREAM_END, stream.total_out == entry.expanded, stream.avail_in == 0 else {
                throw DocumentTemplateError.invalidDocument
            }
            result = output.prefix(entry.expanded)
        }
        let checksum = result.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(result.count)) }
        guard UInt32(checksum) == entry.checksum else { throw DocumentTemplateError.invalidDocument }
        return result
    }
}

private final class OfficeXML: NSObject, XMLParserDelegate {
    struct Relationship { let target: String; let type: String; let external: Bool }
    var root = "", namespace = "", hasBody = false
    var contentTypes: [String: String] = [:], relationships: [String: Relationship] = [:]
    var sheetIDs: [String] = []
    private var depth = 0
    private var valid = true

    static func read(_ data: Data) throws -> OfficeXML {
        let result = OfficeXML(), parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = result
        guard parser.parse(), result.valid, !result.root.isEmpty else { throw DocumentTemplateError.invalidDocument }
        return result
    }

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        depth += 1
        if depth > 256 || contentTypes.count + relationships.count + sheetIDs.count > 8192 { valid = false; parser.abortParsing(); return }
        if depth == 1 { root = element; namespace = namespaceURI ?? "" }
        if element == "body", namespaceURI == namespace { hasBody = true }
        if root == "Types", namespaceURI == namespace, element == "Override", let part = attributes["PartName"], let type = attributes["ContentType"] {
            if contentTypes.updateValue(type, forKey: part) != nil { valid = false; parser.abortParsing() }
        }
        if root == "Relationships", namespaceURI == namespace, element == "Relationship", let id = attributes["Id"],
           let target = attributes["Target"], let type = attributes["Type"] {
            if relationships.updateValue(.init(target: target, type: type, external: attributes["TargetMode"] == "External"), forKey: id) != nil {
                valid = false; parser.abortParsing()
            }
        }
        if root == "workbook", namespaceURI == namespace, element == "sheet", let id = attributes.first(where: { $0.key.hasSuffix(":id") })?.value { sheetIDs.append(id) }
    }
    func parser(_ parser: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName: String?) { depth -= 1 }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName: String, value: String?) { valid = false; parser.abortParsing() }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName: String, publicID: String?, systemID: String?) { valid = false; parser.abortParsing() }
}

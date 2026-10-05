import Foundation
import CryptoKit
import Darwin

public enum TemplatePackageError: Error, LocalizedError {
    case invalid, tooLarge, unsupportedVersion, emptySelection
    public var textKey: TemplateWorkflowText {
        switch self { case .invalid: .packageInvalid; case .tooLarge: .packageTooLarge; case .unsupportedVersion: .packageVersion; case .emptySelection: .noSelection }
    }
    public var errorDescription: String? { textKey.text(.english) }
}

public struct PortableTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var fileExtension: String
    public var suggestedFileName: String
    public var group: String
    public var isEnabled: Bool
    public var customMenuIcon: MenuIconCustomization?
    public var payloadID: String
    public var afterCreation: TemplateCreationAction
    public init(template: FileTemplate, payloadID: String) {
        id = template.id; displayName = template.displayName; fileExtension = template.fileExtension.lowercased()
        suggestedFileName = template.suggestedFileName; group = template.group; isEnabled = template.isEnabled
        customMenuIcon = template.customMenuIcon; self.payloadID = payloadID
        afterCreation = (template.afterCreation ?? .basic(reveal: true)).portable
    }
    private enum CodingKeys: String, CodingKey {
        case id, displayName, fileExtension, suggestedFileName, group, isEnabled, customMenuIcon, payloadID, afterCreation
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id); try values.encode(displayName, forKey: .displayName)
        try values.encode(fileExtension, forKey: .fileExtension); try values.encode(suggestedFileName, forKey: .suggestedFileName)
        try values.encode(group, forKey: .group); try values.encode(isEnabled, forKey: .isEnabled)
        try values.encode(customMenuIcon, forKey: .customMenuIcon)
        try values.encode(payloadID, forKey: .payloadID); try values.encode(afterCreation, forKey: .afterCreation)
    }
    func equivalent(to other: Self) -> Bool {
        var lhs = self, rhs = other; lhs.id = ""; rhs.id = ""
        return lhs == rhs
    }
}

public struct TemplatePackagePayload: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case utf8Text, docx, xlsx
        var prefix: String { self == .utf8Text ? "text" : rawValue }
        var suffix: String { self == .utf8Text ? "txt" : rawValue }
        var officeKind: OfficeDocumentKind? { OfficeDocumentKind(rawValue: rawValue) }
    }
    public let id: String
    public let kind: Kind
    public let path: String
    public let byteCount: Int
    public let sha256: String
    init(kind: Kind, bytes: Data) {
        self.kind = kind; byteCount = bytes.count; sha256 = TemplatePackageCodec.digest(bytes)
        id = kind.prefix + "-" + sha256
        path = "payloads/" + id + "." + kind.suffix
    }
}

public struct ValidatedTemplatePackage: Sendable {
    public let templates: [PortableTemplate]
    public let descriptors: [TemplatePackagePayload]
    public let payloads: [String: Data]
    public let defaultTemplateIDs: [String: String]
    public let digest: String
}

public enum TemplatePackageCodec {
    public static let maximumBytes = 128 * 1024 * 1024
    public static let maximumManifestBytes = 4 * 1024 * 1024
    public static let maximumTextBytes = 8 * 1024 * 1024
    private struct Manifest: Codable {
        var format = "filemint.templates"
        var schemaVersion = 1
        var templates: [PortableTemplate]
        var payloads: [TemplatePackagePayload]
        var defaultTemplateIDs: [String: String]
    }
    public static func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    public static func encode(templates: [FileTemplate], defaults: [String: String], assets: DocumentTemplateStore) throws -> Data {
        guard !templates.isEmpty else { throw TemplatePackageError.emptySelection }
        guard templates.count <= 100 else { throw TemplatePackageError.tooLarge }
        var records: [PortableTemplate] = [], descriptors: [TemplatePackagePayload] = [], bytesByID: [String: Data] = [:]
        var total = 0, textTotal = 0, expansion = 0, offices = 0
        for template in TemplateCatalog.sortedTemplates(from: templates) {
            try Task.checkCancellation()
            let bytes: Data, kind: TemplatePackagePayload.Kind
            if let reference = template.document {
                bytes = try assets.data(for: reference); kind = reference.kind == .docx ? .docx : .xlsx
            } else { bytes = Data(template.content.utf8); kind = .utf8Text }
            let descriptor = TemplatePackagePayload(kind: kind, bytes: bytes)
            if bytesByID[descriptor.id] == nil {
                total += bytes.count
                if kind == .utf8Text { textTotal += bytes.count }
                else { offices += 1; expansion += try OfficeDocumentValidator.expandedByteCount(bytes) }
                guard total <= maximumBytes, textTotal <= maximumTextBytes, expansion <= 256 * 1024 * 1024, offices <= 64 else { throw TemplatePackageError.tooLarge }
                bytesByID[descriptor.id] = bytes; descriptors.append(descriptor)
            }
            records.append(.init(template: template, payloadID: descriptor.id))
        }
        let defaultIDs = TemplateCatalog.validDefaults(defaults, in: templates)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let manifest = try encoder.encode(Manifest(templates: records, payloads: descriptors, defaultTemplateIDs: defaultIDs))
        guard manifest.count <= maximumManifestBytes else { throw TemplatePackageError.tooLarge }
        let data = try StoredTemplateArchive.encode([("manifest.json", manifest)] + descriptors.map { ($0.path, bytesByID[$0.id]!) })
        _ = try decode(data)
        return data
    }
    public static func decode(_ data: Data) throws -> ValidatedTemplatePackage {
        do {
            let entries = try StoredTemplateArchive.decode(data)
            guard let manifestData = entries["manifest.json"], manifestData.count <= maximumManifestBytes else { throw TemplatePackageError.invalid }
            var scanner = try TemplatePackageJSON(manifestData); try scanner.validate()
            try validateSchema(manifestData)
            let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
            guard manifest.format == "filemint.templates", manifest.schemaVersion == 1 else { throw TemplatePackageError.unsupportedVersion }
            guard (1...100).contains(manifest.templates.count), (1...100).contains(manifest.payloads.count) else { throw TemplatePackageError.tooLarge }
            guard Set(manifest.templates.map(\.id)).count == manifest.templates.count,
                  Set(manifest.payloads.map(\.id)).count == manifest.payloads.count else { throw TemplatePackageError.invalid }
            var payloads: [String: Data] = [:], total = 0, textTotal = 0, offices = 0, expansion = 0
            for descriptor in manifest.payloads {
                try Task.checkCancellation()
                guard descriptor.sha256.utf8.count == 64, descriptor.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                      descriptor.id == descriptor.kind.prefix + "-" + descriptor.sha256,
                      descriptor.path == "payloads/" + descriptor.id + "." + descriptor.kind.suffix,
                      descriptor.byteCount >= 0, descriptor.byteCount <= maximumBytes,
                      let bytes = entries[descriptor.path], bytes.count == descriptor.byteCount,
                      digest(bytes) == descriptor.sha256 else { throw TemplatePackageError.invalid }
                total += bytes.count
                guard total <= maximumBytes else { throw TemplatePackageError.tooLarge }
                if let kind = descriptor.kind.officeKind {
                    offices += 1; expansion += try OfficeDocumentValidator.expandedByteCount(bytes)
                    guard offices <= 64, expansion <= 256 * 1024 * 1024 else { throw TemplatePackageError.tooLarge }
                    try OfficeDocumentValidator.validate(bytes, kind: kind)
                } else {
                    textTotal += bytes.count
                    guard textTotal <= maximumTextBytes else { throw TemplatePackageError.tooLarge }
                    guard String(data: bytes, encoding: .utf8) != nil else { throw TemplatePackageError.invalid }
                }
                payloads[descriptor.id] = bytes
            }
            guard Set(entries.keys) == Set(["manifest.json"] + manifest.payloads.map(\.path)),
                  Set(manifest.templates.map(\.payloadID)) == Set(manifest.payloads.map(\.id)) else { throw TemplatePackageError.invalid }
            let descriptors = Dictionary(uniqueKeysWithValues: manifest.payloads.map { ($0.id, $0) })
            for template in manifest.templates {
                guard validID(template.id), !template.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      template.displayName == template.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                      template.fileExtension == FilenamePolicy.normalizedFileExtension(template.fileExtension)?.lowercased(),
                      template.suggestedFileName == FilenamePolicy.fileName(template.suggestedFileName, applyingFileExtension: template.fileExtension),
                      let descriptor = descriptors[template.payloadID],
                      descriptor.kind.officeKind == nil || descriptor.kind.rawValue == template.fileExtension else { throw TemplatePackageError.invalid }
                if template.afterCreation.kind == .openWithApplication {
                    guard let app = template.afterCreation.application, app.isValid else { throw TemplatePackageError.invalid }
                }
            }
            for (suffix, id) in manifest.defaultTemplateIDs {
                guard suffix == FilenamePolicy.normalizedFileExtension(suffix)?.lowercased(),
                      manifest.templates.contains(where: { $0.id == id && $0.fileExtension == suffix && $0.isEnabled }) else { throw TemplatePackageError.invalid }
            }
            return .init(templates: manifest.templates, descriptors: manifest.payloads, payloads: payloads,
                defaultTemplateIDs: manifest.defaultTemplateIDs, digest: digest(data))
        } catch let error as TemplatePackageError { throw error }
        catch is CancellationError { throw CancellationError() }
        catch let error as DocumentTemplateError { throw error }
        catch { throw TemplatePackageError.invalid }
    }
    public static func validID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 128 && id.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45,46,95].contains($0) }
    }
    private static func validateSchema(_ bytes: Data) throws {
        func object(_ value: Any?, keys: Set<String>) throws -> [String: Any] {
            guard let object = value as? [String: Any], Set(object.keys) == keys else { throw TemplatePackageError.invalid }
            return object
        }
        let root = try object(JSONSerialization.jsonObject(with: bytes), keys: ["format","schemaVersion","templates","payloads","defaultTemplateIDs"])
        guard let records = root["templates"] as? [Any], let descriptors = root["payloads"] as? [Any], records.count <= 100, descriptors.count <= 100 else { throw TemplatePackageError.tooLarge }
        for value in records {
            // Optional icon is represented explicitly as null in the portable DTO.
            guard let record = value as? [String: Any], Set(record.keys).isSubset(of: ["id","displayName","fileExtension","suggestedFileName","group","isEnabled","customMenuIcon","payloadID","afterCreation"]),
                  Set(record.keys).isSuperset(of: ["id","displayName","fileExtension","suggestedFileName","group","isEnabled","customMenuIcon","payloadID","afterCreation"]) else { throw TemplatePackageError.invalid }
            if let icon = record["customMenuIcon"], !(icon is NSNull) { _ = try object(icon, keys: ["symbolName","primaryHex","secondaryHex"]) }
            guard let action = record["afterCreation"] as? [String: Any], let kind = action["kind"] as? String,
                  TemplateCreationAction.Kind(rawValue: kind) != nil else { throw TemplatePackageError.invalid }
            _ = try object(action, keys: kind == "openWithApplication" ? ["kind","application"] : ["kind"])
            if kind == "openWithApplication" { _ = try object(action["application"], keys: ["bundleIdentifier","displayName"]) }
        }
        for value in descriptors { _ = try object(value, keys: ["id","kind","path","byteCount","sha256"]) }
    }
    public static func write(_ bytes: Data, to url: URL) throws {
        guard bytes.count <= maximumBytes, url.isFileURL else { throw TemplatePackageError.tooLarge }
        var existing = stat()
        if url.withUnsafeFileSystemRepresentation({ lstat($0!, &existing) }) == 0 {
            guard existing.st_mode & S_IFMT == S_IFREG, existing.st_flags & UInt32(SF_DATALESS) == 0 else { throw TemplatePackageError.invalid }
        } else if errno != ENOENT { throw TemplatePackageError.invalid }
        // A save-panel grant covers the selected file, not arbitrary siblings.
        // Foundation supplies an accessible replacement directory on its volume.
        let manager = FileManager.default
        let directory = try manager.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                        appropriateFor: url, create: true)
        defer { try? manager.removeItem(at: directory) }
        let staged = directory.appendingPathComponent("Templates.filemint-templates")
        try bytes.write(to: staged, options: .withoutOverwriting)
        try Task.checkCancellation()
        let status = staged.withUnsafeFileSystemRepresentation { source in
            url.withUnsafeFileSystemRepresentation { destination in rename(source!, destination!) }
        }
        guard status == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    }
    public static func read(at url: URL, limit: Int = maximumBytes) throws -> Data {
        guard url.isFileURL else { throw TemplatePackageError.invalid }
        var before = stat()
        guard url.withUnsafeFileSystemRepresentation({ $0.map { lstat($0, &before) } ?? -1 }) == 0,
              before.st_mode & S_IFMT == S_IFREG, before.st_flags & UInt32(SF_DATALESS) == 0,
              before.st_size >= 0 else { throw TemplatePackageError.invalid }
        guard before.st_size <= limit else { throw TemplatePackageError.tooLarge }
        let fd = url.withUnsafeFileSystemRepresentation { $0.map { open($0, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC) } ?? -1 }
        guard fd >= 0 else { throw TemplatePackageError.invalid }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(fd,&opened) == 0, CreatedFileIdentity(opened) == CreatedFileIdentity(before), opened.st_mode & S_IFMT == S_IFREG else { throw TemplatePackageError.invalid }
        var data = Data()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            guard data.count <= limit-chunk.count else { throw TemplatePackageError.tooLarge }
            data.append(chunk)
        }
        guard data.count == before.st_size, try CreatedFileIdentity.capture(url) == CreatedFileIdentity(before) else { throw TemplatePackageError.invalid }
        return data
    }
}

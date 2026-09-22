import Foundation
import Testing
import zlib
@testable import FileMintCore

struct DocumentTemplateTests {
    private func fixture(_ kind: OfficeDocumentKind) throws -> Data {
        let name = kind == .docx ? "weekly" : "expenses"
        return try Data(contentsOf: #require(Bundle.module.url(forResource: name, withExtension: kind.rawValue, subdirectory: "Fixtures")))
    }

    @Test func realOfficePackagesRoundTripWithoutSourceDependency() throws {
        for kind in [OfficeDocumentKind.docx, .xlsx] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let bytes = try fixture(kind)
            let source = root.appendingPathComponent("原文档.\(kind.rawValue)")
            try bytes.write(to: source)
            let assets = DocumentTemplateStore(directory: root.appendingPathComponent("assets"))
            let reference = try assets.importDocument(at: source)
            #expect(try Data(contentsOf: source) == bytes)
            #expect(try assets.data(for: reference) == bytes)
            var template = FileTemplate(id: "document", displayName: "办公文档", suggestedFileName: "新文档.\(kind.rawValue)",
                group: "Custom", content: "must not be rendered {{date}}", rank: 1)
            template.document = reference
            let encoded = try JSONEncoder().encode(template)
            #expect(!String(decoding: encoded, as: UTF8.self).contains(source.path))
            #expect(try JSONDecoder().decode(FileTemplate.self, from: encoded) == template)
            try FileManager.default.removeItem(at: source)
            let creator = FileCreationService(documentTemplates: assets)
            for expected in ["新文档.\(kind.rawValue)", "新文档 2.\(kind.rawValue)"] {
                let output = try creator.createFile(.init(destinationDirectory: root, template: template))
                #expect(output.createdURL.lastPathComponent == expected)
                #expect(try Data(contentsOf: output.createdURL) == bytes)
            }
            #expect(try assets.data(for: reference) == bytes)
            let asset = assets.directory.appendingPathComponent(reference.id.uuidString + "." + kind.rawValue)
            let extra = try assets.importDocument(at: root.appendingPathComponent("新文档.\(kind.rawValue)"))
            try assets.remove(extra)
            #expect(throws: DocumentTemplateError.self) { try assets.data(for: extra) }
            #expect(try assets.data(for: reference) == bytes)
            try Data("damaged".utf8).write(to: asset)
            let before = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
            #expect(throws: DocumentTemplateError.self) { try creator.createFile(.init(destinationDirectory: root, template: template)) }
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == before)
        }
    }

    @Test func corruptZipWrongFormatAndUnsafeXMLAreRejected() throws {
        let valid = try fixture(.docx)
        #expect(throws: DocumentTemplateError.self) { try OfficeDocumentValidator.validate(valid, kind: .xlsx) }
        #expect(throws: DocumentTemplateError.self) { try OfficeDocumentValidator.validate(Data(valid.dropLast(12)), kind: .docx) }
        var damaged = valid
        damaged[100] ^= 0xff
        #expect(throws: DocumentTemplateError.self) { try OfficeDocumentValidator.validate(damaged, kind: .docx) }
        var mismatchedHeader = valid
        mismatchedHeader[18] ^= 1
        #expect(throws: DocumentTemplateError.self) { try OfficeDocumentValidator.validate(mismatchedHeader, kind: .docx) }
        var zip64 = valid
        zip64.replaceSubrange(18..<26, with: Array(repeating: UInt8(255), count: 8))
        #expect(throws: DocumentTemplateError.self) { try OfficeDocumentValidator.validate(zip64, kind: .docx) }
        let ns = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        let types = Data("<Types xmlns='http://schemas.openxmlformats.org/package/2006/content-types'><Override PartName='/word/document.xml' ContentType='application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'/></Types>".utf8)
        let rels = Data("<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'><Relationship Id='doc' Target='word/document.xml' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument'/></Relationships>".utf8)
        let body = Data("<document xmlns='\(ns)'><body/></document>".utf8)
        let manifest = [("[Content_Types].xml", types), ("_rels/.rels", rels)]
        try OfficeDocumentValidator.validate(storedZIP(manifest + [("word/document.xml", body)]), kind: .docx)
        let macroTypes = Data(String(decoding: types, as: UTF8.self).replacingOccurrences(
            of: "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
            with: "application/vnd.ms-word.document.macroEnabled.main+xml").utf8)
        let macroPackage = storedZIP([("[Content_Types].xml", macroTypes), ("_rels/.rels", rels), ("word/document.xml", body)])
        #expect(throws: DocumentTemplateError.self) { try OfficeDocumentValidator.validate(macroPackage, kind: .docx) }
        for content in ["<broken>", "<!DOCTYPE document [<!ENTITY bad 'expanded'>]><document xmlns='\(ns)'><body>&bad;</body></document>"] {
            let archive = storedZIP(manifest + [("word/document.xml", Data(content.utf8))])
            #expect(throws: DocumentTemplateError.self) { try OfficeDocumentValidator.validate(archive, kind: .docx) }
        }
        for name in ["../word/document.xml", "/word/document.xml", "word\\document.xml"] {
            let archive = storedZIP(manifest + [("word/document.xml", body), (name, Data())])
            #expect(throws: DocumentTemplateError.self) { try OfficeDocumentValidator.validate(archive, kind: .docx) }
        }
        let index = try #require(valid.range(of: Data([0x50, 0x4b, 0x01, 0x02]))?.lowerBound)
        var oversized = valid
        oversized.replaceSubrange(index + 24..<index + 28, with: [0xff, 0xff, 0xff, 0x7f])
        #expect(throws: DocumentTemplateError.self) { try OfficeDocumentValidator.validate(oversized, kind: .docx) }
    }

    @Test func invalidAndLinkedImportsDoNotCreateAssets() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let assets = DocumentTemplateStore(directory: root.appendingPathComponent("assets"))
        let file = root.appendingPathComponent("fake.docx")
        try Data("not Office".utf8).write(to: file)
        #expect(throws: DocumentTemplateError.self) { try assets.importDocument(at: file) }
        let link = root.appendingPathComponent("linked.docx")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        #expect(throws: DocumentTemplateError.self) { try assets.importDocument(at: link) }
        #expect(!FileManager.default.fileExists(atPath: assets.directory.path))
    }

    @Test func switchingToDocumentCannotDiscardEditedText() throws {
        var document = FileTemplate(id: "office", displayName: "Office", suggestedFileName: "周报.docx", group: "Custom", content: "", rank: 100)
        document.document = DocumentTemplateReference(id: UUID(), kind: .docx, byteCount: 1, sha256: "invalid fixture")
        let templates = TemplateCatalog.builtInTemplates + [document]
        var draft = CustomFileDraft(templates: templates)
        draft.updateContent("unsaved {{date}}")
        let before = draft
        let typedFormatAccepted = draft.updateExtensionInput("docx", templates: templates)
        #expect(!typedFormatAccepted)
        let choice = try #require(FileFormatCatalog.options(from: templates).last)
        let selectionAccepted = draft.selectFormat(choice, templates: templates)
        #expect(!selectionAccepted)
        #expect(draft == before)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        json["document"] = ["kind": "unsupported"]
        let decoded = try JSONDecoder().decode(FileTemplate.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.id == document.id && decoded.document != nil && decoded.document?.byteCount == 0)
    }

    private func storedZIP(_ items: [(String, Data)]) -> Data {
        func field(_ value: Int, _ count: Int) -> Data { Data((0..<count).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }) }
        var local = Data(), central = Data()
        for (name, content) in items {
            let filename = Data(name.utf8), offset = local.count
            let crc = content.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(content.count)) }
            local += field(0x04034b50, 4) + field(20, 2) + Data(repeating: 0, count: 8)
            local += field(Int(crc), 4) + field(content.count, 4) + field(content.count, 4) + field(filename.count, 2) + field(0, 2) + filename + content
            central += field(0x02014b50, 4) + field(20, 2) + field(20, 2) + Data(repeating: 0, count: 8)
            central += field(Int(crc), 4) + field(content.count, 4) + field(content.count, 4) + field(filename.count, 2)
            central += Data(repeating: 0, count: 12) + field(offset, 4) + filename
        }
        let footer = field(0x06054b50, 4) + field(0, 4) + field(items.count, 2) + field(items.count, 2)
            + field(central.count, 4) + field(local.count, 4) + field(0, 2)
        return local + central + footer
    }
}

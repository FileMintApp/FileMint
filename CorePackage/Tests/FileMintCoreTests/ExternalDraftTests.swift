import FileMintCore
import Darwin
import Foundation
import Testing

@Suite("External draft protocol and admission")
struct ExternalDraftTests {
    private let captured = Date(timeIntervalSince1970: 1_704_067_200)

    private func draft(_ raw: String) throws -> ExternalDraftRequest {
        guard case .draft(let request) = try ExternalDraftRoute.parse(raw) else {
            throw ExternalInvocationError.invalidRequest
        }
        return request
    }

    @Test("the public parser accepts only the versioned whitelist", arguments: [
        "filemint://draft", "filemint://draft?v=1&v=1", "filemint://draft?%76=1",
        "filemint://draft?v=1&text", "filemint://draft?v=1&", "filemint://draft?v=1&&text=a",
        "filemint://draft/?v=1", "filemint://draft/extra?v=1", "filemint://user@draft?v=1",
        "filemint://draft:42?v=1", "filemint://draft?v=1#fragment", "filemint://draft?v=1&autoCreate=1",
        "filemint://draft?v=1&replace=true", "filemint://draft?v=1&ticket=x", "filemint://draft?v=1&source=trusted",
        "filemint://draft?v=1&callback=x", "filemint://draft?v=1&command=x", "filemint://draft?v=1&Name=a",
        "filemint://draft?v=1&directory=%2Ftmp&location=ask", "filemint://draft?v=1&location=default",
        "filemint://draft?v=1&directory=~%2FDocuments", "filemint://draft?v=1&directory=file%3A%2F%2F%2Ftmp",
        "filemint://draft?v=1&directory=%252Ftmp", "filemint://draft?v=1&favorite=plain-text",
        "filemint://draft?v=1&id=not-a-UUID", "filemint://search?v=1&name=a",
        "filemint://search?v=1&text=", "filemint://new?directory=%2Ftmp", "https://draft?v=1"
    ])
    func invalidProtocol(_ raw: String) {
        #expect(throws: (any Error).self) { try ExternalDraftRoute.parse(raw) }
    }

    @Test("unknown versions are distinct from malformed requests")
    func version() throws {
        for version in ["", "01", "2", " 1", "+1"] {
            #expect(throws: ExternalInvocationError.unsupportedVersion) {
                try ExternalDraftRoute.parse("filemint://draft?v=" + version.replacingOccurrences(of: " ", with: "%20"))
            }
        }
        #expect(throws: ExternalInvocationError.invalidRequest) { try ExternalDraftRoute.parse("filemint://draft?name=a") }
        #expect(try ExternalDraftRoute.parse("filemint://search?v=1") == .search)
    }

    @Test("invalid wire spelling and UTF-8 never receive Foundation repair", arguments: [
        "%", "%2", "%GG", "%FF", "%C0%AF", "%ED%A0%80", "%E4%B8", "%00", "raw space", "中文"
    ])
    func malformedEncoding(_ value: String) {
        #expect(throws: ExternalInvocationError.invalidRequest) { try ExternalDraftRoute.parse("filemint://draft?v=1&text=" + value) }
    }

    @Test("single decoding preserves plus, double encoding and exact text bytes")
    func encoding() throws {
        let request = try draft("filemint://draft?v=1&name=Report%252Fnotes.txt&text=%E4%B8%AD%E6%96%87%20%F0%9F%A7%AA%0D%0A%26%23%2B%25%3F%3D%20%24()%20%60literal%60%20%7B%7Byear%7D%7D")
        #expect(request.name == "Report%2Fnotes.txt")
        guard case .verbatim(let text) = request.content else { Issue.record("Missing verbatim text"); return }
        #expect(Data(text.utf8) == Data("中文 🧪\r\n&#+%?= $() `literal` {{year}}".utf8))
        #expect(try draft("filemint://draft?v=1&text=hello+world").content == .verbatim("hello+world"))
        #expect(try draft("filemint://draft?v=1&text=%252F").content == .verbatim("%2F"))
        #expect(try draft("filemint://draft?v=1&text=").content == .verbatim(""))
        #expect(try draft("filemint://draft?v=1").content == .templateDefault)
        let encoded = try ExternalDraftRoute.string(for: .draft(request))
        #expect(encoded.contains("name=Report%252Fnotes.txt"))
        #expect(try draft(encoded) == request)
    }

    @Test("encoded URL and decoded text limits are enforced independently")
    func urlLimits() throws {
        let prefix = "filemint://draft?v=1&text="
        for length in [16383, 16384, 16385] {
            let remaining = length - prefix.utf8.count
            let raw = prefix + String(repeating: "%41", count: remaining / 3) + String(repeating: "b", count: remaining % 3)
            #expect(raw.utf8.count == length)
            if length <= 16384 { _ = try draft(raw) }
            else { #expect(throws: ExternalInvocationError.payloadTooLarge) { try draft(raw) } }
        }
        for length in [8191, 8192, 8193] {
            let raw = prefix + String(repeating: "x", count: length)
            if length <= 8192 { _ = try draft(raw) }
            else { #expect(throws: ExternalInvocationError.payloadTooLarge) { try draft(raw) } }
        }
        let expands = try ExternalDraftRequest(content: .verbatim(String(repeating: "🧪", count: 2048)))
        #expect(throws: ExternalInvocationError.payloadTooLarge) { try ExternalDraftRoute.string(for: .draft(expands)) }
    }

    @Test("native boundaries count UTF-8 and never truncate")
    func nativeLimits() throws {
        _ = try ExternalDraftRequest(content: .verbatim(String(repeating: "é", count: 524288)))
        #expect(throws: ExternalInvocationError.payloadTooLarge) {
            try ExternalDraftRequest(content: .verbatim(String(repeating: "é", count: 524288) + "x"))
        }
        _ = try ExternalDraftRequest(name: String(repeating: "é", count: 512))
        #expect(throws: ExternalInvocationError.payloadTooLarge) { try ExternalDraftRequest(name: String(repeating: "é", count: 512) + "x") }
        _ = try ExternalDraftRequest(destination: .directory("/" + String(repeating: "a", count: 4095)))
        #expect(throws: ExternalInvocationError.payloadTooLarge) {
            try ExternalDraftRequest(destination: .directory("/" + String(repeating: "a", count: 4096)))
        }
        _ = try ExternalDraftRequest(templateID: String(repeating: "a", count: 256))
        #expect(throws: ExternalInvocationError.payloadTooLarge) { try ExternalDraftRequest(templateID: String(repeating: "a", count: 257)) }
        #expect(throws: ExternalInvocationError.invalidRequest) { try ExternalDraftRequest(content: .verbatim("text\0tail")) }
    }

    @Test("external names reject path syntax rather than sanitizing it", arguments: ["", " ", ".", "..", "a/b.txt", "a\\b.txt", "a:b.txt", "a\nb.txt", "a\0b", "a."])
    func invalidNames(_ name: String) {
        #expect(throws: ExternalInvocationError.invalidFilename) { try ExternalDraftRequest(name: name) }
    }

    @Test("destinations normalize lexically without expanding variables or granting access")
    func destination() throws {
        #expect(try draft("filemint://draft?v=1&directory=%2Ftmp%2Fa%2F..%2Fb").destination == .directory("/tmp/b"))
        #expect(try draft("filemint://draft?v=1&directory=%2Ftmp%2F%24HOME").destination == .directory("/tmp/$HOME"))
        #expect(try draft("filemint://draft?v=1&location=ask").destination == .ask)
        let id = UUID()
        let request = try ExternalDraftRequest(destination: .favorite(id), requestID: id)
        #expect(try draft(ExternalDraftRoute.string(for: .draft(request))) == request)
    }

    @Test("exact templates, compound suffixes and explicit content remain independent")
    func seed() throws {
        var preferences = FileMintPreferences.default
        let exact = FileTemplate(id: "exact", displayName: "Exact", suggestedFileName: "Project.md", group: "QA",
                                 content: "chosen {{year}}", rank: 1, fileExtension: "md")
        let compound = FileTemplate(id: "compound", displayName: "Compound", suggestedFileName: "Untitled.tar.gz", group: "QA",
                                    content: "archive text", rank: 2, fileExtension: "tar.gz")
        preferences.templates += [exact, compound]
        preferences.defaultTemplateIDs["md"] = "markdown"
        let seed = try ExternalDraftRequest(name: "Note.md", templateID: "exact").resolve(preferences: preferences, capturedAt: captured)
        #expect(seed.fileName == "Note.md")
        #expect(seed.draft.selectedTemplateID == "exact")
        #expect(seed.draft.content == "chosen {{year}}")
        #expect(!seed.draft.hasEditedContent)
        #expect(seed.draft.capturedAt == captured)
        let verbatim = try ExternalDraftRequest(name: "Note", templateID: "exact", content: .verbatim("{{year}}\r\n"))
            .resolve(preferences: preferences, capturedAt: captured)
        #expect(verbatim.fileName == "Note.md")
        #expect(verbatim.draft.selectedTemplateID == "exact")
        #expect(verbatim.draft.hasEditedContent)
        #expect(Data(verbatim.draft.content.utf8) == Data("{{year}}\r\n".utf8))
        #expect(try ExternalDraftRequest(templateID: "exact").resolve(preferences: preferences, capturedAt: captured).fileName == "Project.md")
        #expect(try ExternalDraftRequest(name: "Snapshot.tar.gz", templateID: "compound")
            .resolve(preferences: preferences, capturedAt: captured).draft.selectedTemplateID == "compound")
        #expect(throws: ExternalInvocationError.invalidFilename) {
            try ExternalDraftRequest(name: "Note.txt", templateID: "exact").resolve(preferences: preferences, capturedAt: captured)
        }
        #expect(try ExternalDraftRequest(name: "Custom.unknown").resolve(preferences: preferences, capturedAt: captured).fileName == "Custom.unknown")
        #expect(try ExternalDraftRequest(name: ".hidden", templateID: "exact").resolve(preferences: preferences, capturedAt: captured).fileName == ".hidden.md")
    }

    @Test("missing or disabled templates never substitute and Office never accepts text")
    func templateRejection() throws {
        var preferences = FileMintPreferences.default
        for id in ["missing", "csv"] {
            #expect(throws: ExternalInvocationError.templateUnavailable) {
                try ExternalDraftRequest(templateID: id).resolve(preferences: preferences, capturedAt: captured)
            }
        }
        preferences.templates[0].isEnabled = false
        #expect(throws: ExternalInvocationError.templateUnavailable) {
            try ExternalDraftRequest(templateID: "plain-text").resolve(preferences: preferences, capturedAt: captured)
        }
        for text in ["", "body", "{{year}}"] {
            #expect(throws: ExternalInvocationError.contentTemplateMismatch) {
                try ExternalDraftRequest(templateID: "word-document", content: .verbatim(text))
                    .resolve(preferences: preferences, capturedAt: captured)
            }
        }
    }

    @Test("resolved requests use the real writer with exact bytes and collision preservation")
    func realFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-External-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("Note.md")
        try Data("keep original\n".utf8).write(to: original, options: .withoutOverwriting)
        let preferences = FileMintPreferences.default
        let request = try ExternalDraftRequest(name: "Note.md", templateID: "markdown", content: .verbatim("中文 🧪\r\n{{year}}\n"),
                                               destination: .directory(root.path))
        let seed = try request.resolve(preferences: preferences, capturedAt: captured)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)) == ["Note.md"])
        var template = try #require(preferences.templates.first { $0.id == seed.draft.selectedTemplateID })
        template.content = seed.draft.content
        let result = try FileCreationService().createFile(.init(destinationDirectory: root, template: template,
            requestedFileName: seed.fileName, contentMode: .verbatim, capturedAt: seed.draft.capturedAt,
            expectedDirectoryIdentity: CreationDirectoryIdentity.capture(root)))
        #expect(result.createdURL.lastPathComponent == "Note 2.md")
        #expect(try Data(contentsOf: result.createdURL) == Data("中文 🧪\r\n{{year}}\n".utf8))
        #expect(try Data(contentsOf: original) == Data("keep original\n".utf8))
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)) == ["Note.md", "Note 2.md"])
    }

    @Test("a captured directory replaced by another object cannot receive a file")
    func replacedDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-External-Identity-\(UUID())", isDirectory: true)
        let folder = root.appendingPathComponent("selected", isDirectory: true)
        let original = root.appendingPathComponent("original", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = try CreationDirectoryIdentity.capture(folder)
        try FileManager.default.moveItem(at: folder, to: original)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try Data("preserve replacement\n".utf8).write(to: folder.appendingPathComponent("keep.txt"))
        let request = FileCreationRequest(destinationDirectory: folder, template: TemplateCatalog.builtInTemplates[0],
            requestedFileName: "must-not-exist.txt", expectedDirectoryIdentity: identity)
        do {
            _ = try FileCreationService().createFile(request)
            Issue.record("A replaced directory received a creation")
        } catch FileMintError.destinationChanged {}
        #expect(try FileManager.default.contentsOfDirectory(atPath: original.path).isEmpty)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: folder.path)) == ["keep.txt"])
        #expect(try Data(contentsOf: folder.appendingPathComponent("keep.txt")) == Data("preserve replacement\n".utf8))
        try FileManager.default.removeItem(at: folder.appendingPathComponent("keep.txt"))
        try FileManager.default.removeItem(at: folder)
        try FileManager.default.createSymbolicLink(at: folder, withDestinationURL: original)
        #expect(throws: (any Error).self) { try FileCreationService().createFile(request) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: original.path).isEmpty)
    }

    @Test("pinned Office bytes and explicit text replacement preserve originals and clean staging")
    func pinnedOfficeAndReplace() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-External-Office-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = try CreationDirectoryIdentity.capture(root)
        let template = try #require(TemplateCatalog.builtInTemplates.first { $0.id == "word-document" })
        let reference = try #require(template.document)
        let bytes = try DocumentTemplateStore().data(for: reference)
        let saved = try FileCreationService().createFile(.init(destinationDirectory: root, template: template,
            requestedFileName: "Document.docx", expectedDirectoryIdentity: identity))
        #expect(saved.contentKind == .officeDocument)
        #expect(try Data(contentsOf: saved.createdURL) == bytes)
        #expect(throws: FileMintError.self) {
            try FileCreationService().createFile(.init(destinationDirectory: root, template: template,
                requestedFileName: "Document.docx", collisionStrategy: .replace, expectedDirectoryIdentity: identity))
        }
        let target = root.appendingPathComponent("Note.txt")
        let original = root.appendingPathComponent("source.txt")
        try Data("keep symlink source".utf8).write(to: original)
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: original)
        var text = TemplateCatalog.builtInTemplates[0]
        text.content = "replacement {{year}}"
        _ = try FileCreationService().createFile(.init(destinationDirectory: root, template: text,
            requestedFileName: "Note.txt", collisionStrategy: .replace, contentMode: .verbatim,
            expectedDirectoryIdentity: identity))
        #expect(try Data(contentsOf: target) == Data("replacement {{year}}".utf8))
        #expect(try Data(contentsOf: original) == Data("keep symlink source".utf8))
        #expect(try target.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == false)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)) == ["Document.docx", "Note.txt", "source.txt"])
    }

    @Test("creation in a write-only selected directory does not require listing it")
    func writeOnlyDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-External-WriteOnly-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            _ = chmod(root.path, 0o700)
            try? FileManager.default.removeItem(at: root)
        }
        let identity = try CreationDirectoryIdentity.capture(root)
        #expect(chmod(root.path, 0o300) == 0)
        let reader = open(root.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        if reader >= 0 { close(reader); Issue.record("Fixture requires actual directory-read denial"); return }
        #expect(errno == EACCES)
        let saved = try FileCreationService().createFile(.init(destinationDirectory: root, template: TemplateCatalog.builtInTemplates[0],
            requestedFileName: "allowed.txt", expectedDirectoryIdentity: identity))
        #expect(chmod(root.path, 0o700) == 0)
        #expect(saved.createdURL.lastPathComponent == "allowed.txt")
        #expect(try Data(contentsOf: saved.createdURL).isEmpty)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)) == ["allowed.txt"])
    }

    @Test("admission reserves preparation atomically and modal priority includes duplicates")
    func admission() throws {
        var gate = ExternalDraftAdmission()
        let request = try ExternalDraftRequest(name: "one", requestID: UUID())
        let accepted = gate.admit(request, now: 0, hasDraft: false, isBusy: false)
        let session = try #require(gate.activeSessionID)
        #expect(accepted == .accepted(session))
        #expect(gate.admit(request, now: 1, hasDraft: false, isBusy: false) == .busy)
        #expect(gate.admit(try .init(name: "another"), now: 1, hasDraft: false, isBusy: false) == .busy)
        gate.markPresented(session)
        #expect(gate.admit(request, now: 2, hasDraft: true, isBusy: false) == .alreadyPresented(session))
        #expect(gate.admit(request, now: 2, hasDraft: true, isBusy: true) == .busy)
        #expect(gate.admit(try .init(name: "another"), now: 2, hasDraft: true, isBusy: false) == .existingDraft)
        #expect(gate.admit(try .init(name: "changed", requestID: request.requestID), now: 2, hasDraft: true, isBusy: false) == .conflictingRequestID)
        gate.finish(session, now: 10)
        #expect(gate.admit(request, now: 609.999, hasDraft: false, isBusy: false) == .alreadyHandled)
        #expect(gate.admit(request, now: 610, hasDraft: false, isBusy: false) != .alreadyHandled)
    }

    @Test("failed preparation can retry and stale completion cannot clear another session")
    func failedAndStale() throws {
        var gate = ExternalDraftAdmission()
        let request = try ExternalDraftRequest(requestID: UUID())
        _ = gate.admit(request, now: 0, hasDraft: false, isBusy: false)
        let first = try #require(gate.activeSessionID)
        gate.finish(first, now: 1)
        _ = gate.admit(request, now: 2, hasDraft: false, isBusy: false)
        let next = try #require(gate.activeSessionID)
        #expect(first != next)
        gate.finish(first, now: 3)
        #expect(gate.activeSessionID == next)
        gate.markPresented(next)
        gate.finish(next, now: 4)
        #expect(gate.admit(request, now: 5, hasDraft: false, isBusy: false) == .alreadyHandled)
    }

    @Test("rejected requests do not poison IDs and byte-distinct Unicode cannot deduplicate")
    func rejectedAndUnicode() throws {
        var gate = ExternalDraftAdmission()
        let id = UUID()
        let request = try ExternalDraftRequest(content: .verbatim("é"), requestID: id)
        #expect(gate.admit(request, now: 0, hasDraft: true, isBusy: false) == .existingDraft)
        #expect(gate.activeSessionID == nil)
        _ = gate.admit(request, now: 1, hasDraft: false, isBusy: false)
        let session = try #require(gate.activeSessionID)
        gate.markPresented(session)
        let decomposed = try ExternalDraftRequest(content: .verbatim("e\u{301}"), requestID: id)
        #expect(gate.admit(decomposed, now: 2, hasDraft: true, isBusy: false) == .conflictingRequestID)
    }

    @Test("completed ID metadata is bounded to 512 records")
    func boundedHistory() throws {
        var gate = ExternalDraftAdmission()
        var requests: [ExternalDraftRequest] = []
        for index in 0..<513 {
            let request = try ExternalDraftRequest(name: "note-\(index)", requestID: UUID())
            requests.append(request)
            _ = gate.admit(request, now: Double(index), hasDraft: false, isBusy: false)
            let session = try #require(gate.activeSessionID)
            gate.markPresented(session)
            gate.finish(session, now: Double(index))
        }
        #expect(gate.admit(requests[1], now: 513, hasDraft: false, isBusy: false) == .alreadyHandled)
        let firstAgain = gate.admit(requests[0], now: 513, hasDraft: false, isBusy: false)
        let session = try #require(gate.activeSessionID)
        #expect(firstAgain == .accepted(session))
    }
}

import Foundation
import CryptoKit
import Testing
import zlib
@testable import FileMintCore

struct TemplatePackageTests {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }
    private func text(_ id: String = "custom-notes", name: String = "Notes", content: String = "hello\r\n{{date}}") -> FileTemplate {
        FileTemplate(id: id, displayName: name, suggestedFileName: "Notes.txt", group: "Custom", content: content, rank: 10)
    }
    private func emptyPreferences() -> FileMintPreferences {
        var preferences = FileMintPreferences(templates: [], monitoredFolderURLs: [], collisionStrategy: .increment, revealAfterCreation: false, favoritesFirst: false)
        preferences.removedBuiltInTemplateIDs = TemplateCatalog.builtInTemplates.map(\.id).sorted()
        return preferences
    }
    private func independentZIP(_ items: [(String, Data)]) -> Data {
        func field(_ value: Int, _ count: Int) -> Data { Data((0..<count).map { UInt8(truncatingIfNeeded: value >> ($0*8)) }) }
        var local = Data(), central = Data()
        for (name, content) in items {
            let filename = Data(name.utf8), offset = local.count
            let crc = content.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(content.count)) }
            local += field(0x04034b50,4) + field(20,2) + Data(repeating: 0,count: 8)
            local += field(Int(crc),4) + field(content.count,4) + field(content.count,4) + field(filename.count,2) + field(0,2) + filename + content
            central += field(0x02014b50,4) + field(20,2) + field(20,2) + Data(repeating: 0,count: 8)
            central += field(Int(crc),4) + field(content.count,4) + field(content.count,4) + field(filename.count,2)
            central += Data(repeating: 0,count: 12) + field(offset,4) + filename
        }
        return local + central + field(0x06054b50,4) + field(0,4) + field(items.count,2) + field(items.count,2)
            + field(central.count,4) + field(local.count,4) + field(0,2)
    }
    private let emptyPayloadID = "text-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    private var sample: Data {
        Data(#"{"format":"filemint.templates","schemaVersion":1,"templates":[{"id":"custom-demo","displayName":"Notes","fileExtension":"txt","suggestedFileName":"Notes.txt","group":"Custom","isEnabled":true,"customMenuIcon":null,"payloadID":"text-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","afterCreation":{"kind":"revealInFinder"}}],"payloads":[{"id":"text-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855","kind":"utf8Text","path":"payloads/text-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.txt","byteCount":0,"sha256":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}],"defaultTemplateIDs":{"txt":"custom-demo"}}"#.utf8)
    }
    private func archive(_ manifest: Data) -> Data {
        independentZIP([("manifest.json",manifest),("payloads/"+emptyPayloadID+".txt",Data())])
    }
    @Test func revisionIsStableAcrossSetSerializationAndRelaunch() throws {
        let preferences = emptyPreferences()
        let decoded = try FileMintPreferencesStore.decode(JSONEncoder().encode(preferences))
        #expect(decoded == preferences)
        #expect(try TemplateImportPlanner.revision(decoded) == TemplateImportPlanner.revision(preferences))
    }
    @Test func independentVersionOneFixtureAndExactTextOfficeRoundTrip() throws {
        let parsed = try TemplatePackageCodec.decode(archive(sample))
        #expect(parsed.templates[0].id == "custom-demo" && parsed.payloads[emptyPayloadID] == Data())
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        let assets = DocumentTemplateStore(directory: root.appendingPathComponent("assets"))
        var notes = text(content: "\u{FEFF}中文\r\n{{fileName}} {{year}}\n ")
        let privateID = UUID()
        notes.afterCreation = .init(.openWithApplication, application: .init(bundleIdentifier: "com.microsoft.VSCode", displayName: "Code"), localApplicationID: privateID)
        let templates = [notes] + BuiltInDocumentTemplate.allCases.map(\.template)
        let bytes = try TemplatePackageCodec.encode(templates: templates, defaults: ["txt":notes.id], assets: assets)
        #expect(!String(decoding: bytes,as: UTF8.self).contains(privateID.uuidString))
        let package = try TemplatePackageCodec.decode(bytes)
        #expect(package.payloads[package.templates[0].payloadID] == Data("\u{FEFF}中文\r\n{{fileName}} {{year}}\n ".utf8))
        #expect(package.templates[0].afterCreation.localApplicationID == nil)
        let plan = try TemplateImportPlanner.plan(package, into: emptyPreferences())
        #expect(plan.preferences.templates[0].content == "\u{FEFF}中文\r\n{{fileName}} {{year}}\n ")
        #expect(!plan.preferences.creationOpeningEnabled && !plan.preferences.templatePreviewEnabled)
        #expect(plan.assets.count == 2 && plan.preferences.templates.dropFirst().allSatisfy { $0.id.hasPrefix("custom-") && $0.document?.builtInResource == nil })
        for asset in plan.assets { #expect(asset.bytes == package.payloads[asset.reference.kind.rawValue+"-"+asset.reference.sha256]) }
    }
    @Test func schemaUnknownDuplicateAndInvalidReferencesAreRejected() throws {
        for (from,to) in [
            (#""schemaVersion":1"#, #""schemaVersion":2"#),
            (#""format":"filemint.templates""#, #""format":"filemint.templates","creationOpeningEnabled":true"#),
            (#""schemaVersion":1"#, #""schemaVersion":1,"schema\u0056ersion":1"#),
            (#""kind":"revealInFinder""#, #""kind":"openWithDefaultApp","localApplicationID":"not-portable""#),
            (#""txt":"custom-demo""#, #""txt":"missing""#),
            (#""isEnabled":true"#, #""isEnabled":false"#),
            (#""byteCount":0"#, #""byteCount":-1"#),
            (#""customMenuIcon":null,"#, ""),
            (#""suggestedFileName":"Notes.txt""#, #""suggestedFileName":"../Notes.txt""#)
        ] {
            let altered = Data(String(decoding: sample,as: UTF8.self).replacingOccurrences(of: from,with: to).utf8)
            #expect(throws: TemplatePackageError.self) { try TemplatePackageCodec.decode(archive(altered)) }
        }
        let entries = [("manifest.json",sample),("payloads/"+emptyPayloadID+".txt",Data()),("extra",Data())]
        #expect(throws: TemplatePackageError.self) { try TemplatePackageCodec.decode(independentZIP(entries)) }
    }
    @Test func outerCRCFlagsPathsLinksAndRangesFailBeforeImport() throws {
        let good = archive(sample)
        let footer = good.count-22
        let central = (0..<4).reduce(0) { $0 | Int(good[footer+16+$1]) << ($1*8) }
        for (offset,value) in [(8,UInt8(8)),(6,UInt8(1)),(4,UInt8(45)),(18,UInt8(255)),(central+42,UInt8(255)),(central+41,UInt8(0xa0)),(30,UInt8(47))] {
            var altered=good; altered[offset]=value
            #expect(throws: TemplatePackageError.self) { try TemplatePackageCodec.decode(altered) }
        }
        var corrupt=good; corrupt[43] ^= 1
        #expect(throws: TemplatePackageError.self) { try TemplatePackageCodec.decode(corrupt) }
        for name in ["../payload", "/payload", "payloads/../bad", "payloads\\bad", "payloads//bad"] {
            #expect(throws: TemplatePackageError.self) { try TemplatePackageCodec.decode(independentZIP([("manifest.json",sample),(name,Data())])) }
        }
        #expect(throws: TemplatePackageError.self) { try TemplatePackageCodec.decode(independentZIP([("manifest.json",sample),("manifest.json",sample)])) }
        #expect(throws: TemplatePackageError.self) { try TemplatePackageCodec.decode(Data(good.dropLast())) }
    }
    @Test func boundedFilesAndUTF8RejectWithoutFollowingLinks() throws {
        let root=try root(); defer { try? FileManager.default.removeItem(at: root) }
        let file=root.appendingPathComponent("package")
        try archive(sample).write(to: file)
        let link=root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link,withDestinationURL: file)
        #expect(throws: TemplatePackageError.self) { try TemplatePackageCodec.read(at: link) }
        let handle=try FileHandle(forWritingTo: file); try handle.truncate(atOffset: UInt64(TemplatePackageCodec.maximumBytes+1)); try handle.close()
        #expect(throws: TemplatePackageError.tooLarge) { try TemplatePackageCodec.read(at: file) }
        let textTemplate=text(content:String(repeating:"x",count:TemplatePackageCodec.maximumTextBytes+1))
        #expect(throws: TemplatePackageError.tooLarge) { try TemplatePackageCodec.encode(templates:[textTemplate],defaults:[:],assets:DocumentTemplateStore(directory:root)) }
        #expect(throws: TemplatePackageError.tooLarge) { try TemplatePackageCodec.decode(independentZIP([("manifest.json",Data(repeating:32,count:TemplatePackageCodec.maximumManifestBytes+1))])) }
        let invalid=Data([0xff]), digest=SHA256.hash(data:invalid).map { String(format:"%02x",$0) }.joined()
        var manifest=String(decoding:sample,as: UTF8.self).replacingOccurrences(of:String(emptyPayloadID.dropFirst(5)),with:digest).replacingOccurrences(of:#""byteCount":0"#,with:#""byteCount":1"#)
        #expect(throws: TemplatePackageError.invalid) { try TemplatePackageCodec.decode(independentZIP([("manifest.json",Data(manifest.utf8)),("payloads/text-"+digest+".txt",invalid)])) }
        manifest=manifest.replacingOccurrences(of:#""kind":"utf8Text""#,with:#""kind":"docx""#).replacingOccurrences(of:"text-"+digest,with:"docx-"+digest).replacingOccurrences(of:".txt",with:".docx")
        #expect(throws: DocumentTemplateError.self) { try TemplatePackageCodec.decode(independentZIP([("manifest.json",Data(manifest.utf8)),("payloads/docx-"+digest+".docx",invalid)])) }
    }
    @Test func mergePreservesExplicitDefaultsTombstonesAndIndependentCopies() throws {
        let assets=DocumentTemplateStore()
        let original=text("custom-original",name:"Café")
        let data=try TemplatePackageCodec.encode(templates:[original],defaults:["txt":original.id],assets:assets)
        let package=try TemplatePackageCodec.decode(data)
        var local=emptyPreferences(); local.templates=[original]; local.removedBuiltInTemplateIDs=["markdown"]
        let identical=try TemplateImportPlanner.plan(package,into:local,adoptDefaults:true)
        #expect(identical.acceptedCount==0 && identical.preferences==local)
        let copied=try TemplateImportPlanner.plan(package,into:local,choices:[original.id:.copy],copySuffix:"副本")
        #expect(copied.preferences.templates[1].displayName=="Café 副本" && copied.preferences.templates[1].id != original.id)
        #expect(copied.preferences.removedBuiltInTemplateIDs==["markdown"])
        var changed=original; changed.content="different"; changed.id="custom-incoming"; changed.displayName="CAFE\u{301}"
        let changedPackage=try TemplatePackageCodec.decode(TemplatePackageCodec.encode(templates:[changed],defaults:["txt":changed.id],assets:assets))
        local.defaultTemplateIDs=["txt":original.id]
        let merge=try TemplateImportPlanner.plan(changedPackage,into:local,adoptDefaults:true,copySuffix:"Copy")
        #expect(merge.rows[0].choice == .copy && merge.preferences.defaultTemplateIDs==local.defaultTemplateIDs)
        #expect(merge.preferences.templates[0]==original)
        let suffixDistinct=try TemplatePackageCodec.decode(TemplatePackageCodec.encode(templates:[text("custom-other",name:"Distinct")],defaults:["txt":"custom-other"],assets:assets))
        local.defaultTemplateIDs=[:]
        let preserve=try TemplateImportPlanner.plan(suffixDistinct,into:local)
        #expect(preserve.rows[0].choice == .add && preserve.defaultChanges.isEmpty)
        let adopt=try TemplateImportPlanner.plan(suffixDistinct,into:local,adoptDefaults:true)
        #expect(adopt.defaultChanges.count==1 && adopt.preferences.defaultTemplateIDs["txt"]=="custom-other")
        var foreign=original; foreign.afterCreation = .init(.openWithApplication,application:.init(bundleIdentifier:"com.microsoft.VSCode",displayName:"Code"))
        let incoming=try TemplatePackageCodec.decode(TemplatePackageCodec.encode(templates:[foreign],defaults:[:],assets:assets))
        local.creationApplications=[.init(hint:foreign.afterCreation!.application!,url:URL(fileURLWithPath:"/fixture.app"),bookmark:Data([1]))]
        let unresolved=try TemplateImportPlanner.plan(incoming,into:local)
        #expect(unresolved.preferences.templates.last?.afterCreation?.localApplicationID==nil)
    }
    @Test(arguments:["journal","staged","published","beforeSave","afterSave","cleanup"])
    func freshCoordinatorRecoversEveryInterruptedCommitPhase(_ phase:String) throws {
        let root=try root(); defer { try? FileManager.default.removeItem(at:root) }
        let assets=DocumentTemplateStore(directory:root.appendingPathComponent("assets"))
        let prefsURL=root.appendingPathComponent("preferences.json"), journalURL=root.appendingPathComponent("journal.json")
        let original=emptyPreferences(); try FileMintPreferencesStore(fileURL:prefsURL).save(original)
        let before=try Data(contentsOf:prefsURL)
        let package=try TemplatePackageCodec.decode(TemplatePackageCodec.encode(templates:BuiltInDocumentTemplate.allCases.map(\.template),defaults:[:],assets:assets))
        let plan=try TemplateImportPlanner.plan(package,into:original)
        let transaction=TemplateImportTransaction(journalURL:journalURL,preferencesURL:prefsURL,assets:assets,fault:{ stage in
            let name:String = switch stage { case .journal:"journal"; case .staged:"staged"; case .published:"published"; case .beforeSave:"beforeSave"; case .afterSave:"afterSave"; case .cleanup:"cleanup" }
            if name==phase { throw TemplateImportTransaction.Interruption() }
        })
        #expect(throws:TemplateImportTransaction.Interruption.self) { try transaction.commit(plan) }
        try TemplateImportTransaction(journalURL:journalURL,preferencesURL:prefsURL,assets:assets).recover()
        #expect(!FileManager.default.fileExists(atPath:journalURL.path))
        let current=FileMintPreferencesStore(fileURL:prefsURL).load()
        if ["afterSave","cleanup"].contains(phase) {
            #expect(current.templates.count==2 && current.lastTemplateImportTransactionID != nil)
            for template in current.templates { #expect(try assets.data(for:#require(template.document)).count==template.document?.byteCount) }
        } else {
            #expect(try Data(contentsOf:prefsURL)==before)
            #expect(try FileManager.default.contentsOfDirectory(atPath:assets.directory.path).isEmpty)
        }
    }
    @Test func saveFailureRollbackCleanupFailureAndStaleReviewPreserveData() throws {
        let root=try root(); defer { try? FileManager.default.removeItem(at:root) }
        let assets=DocumentTemplateStore(directory:root.appendingPathComponent("assets")), prefsURL=root.appendingPathComponent("prefs.json"), journalURL=root.appendingPathComponent("journal.json")
        let original=emptyPreferences(); let store=FileMintPreferencesStore(fileURL:prefsURL); try store.save(original)
        let before=try Data(contentsOf:prefsURL)
        let package=try TemplatePackageCodec.decode(TemplatePackageCodec.encode(templates:[BuiltInDocumentTemplate.allCases[0].template],defaults:[:],assets:assets))
        let plan=try TemplateImportPlanner.plan(package,into:original)
        let failure=TemplateImportTransaction(journalURL:journalURL,preferencesURL:prefsURL,assets:assets,save:{ _ in throw CocoaError(.fileWriteNoPermission) })
        #expect(throws:CocoaError.self) { try failure.commit(plan) }
        #expect(try Data(contentsOf:prefsURL)==before && !FileManager.default.fileExists(atPath:journalURL.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath:assets.directory.path).isEmpty)
        var changed=original; changed.language = .chinese; try store.save(changed)
        #expect(throws:TemplateTransactionError.staleReview) { try TemplateImportTransaction(journalURL:journalURL,preferencesURL:prefsURL,assets:assets).commit(plan) }
        let fresh=try TemplateImportPlanner.plan(package,into:changed)
        let cleanup=TemplateImportTransaction(journalURL:journalURL,preferencesURL:prefsURL,assets:assets,fault:{ stage in if case .cleanup=stage { throw CocoaError(.fileWriteNoPermission) } })
        let receipt=try cleanup.commit(fresh)
        #expect(receipt.cleanupPending && store.load().templates.count==1)
        try TemplateImportTransaction(journalURL:journalURL,preferencesURL:prefsURL,assets:assets).recover()
        #expect(store.load().templates.count==1)
    }
    @Test func preferencesDamageDuringCommitPreservesJournalAndPublishedAssets() throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        let assets = DocumentTemplateStore(directory: root.appendingPathComponent("assets"))
        let preferencesURL = root.appendingPathComponent("prefs.json"), journalURL = root.appendingPathComponent("journal.json")
        let original = emptyPreferences()
        try FileMintPreferencesStore(fileURL: preferencesURL).save(original)
        let package = try TemplatePackageCodec.decode(TemplatePackageCodec.encode(templates: [BuiltInDocumentTemplate.allCases[0].template], defaults: [:], assets: assets))
        let plan = try TemplateImportPlanner.plan(package, into: original)
        let transaction = TemplateImportTransaction(journalURL: journalURL, preferencesURL: preferencesURL, assets: assets, fault: { stage in
            if case .beforeSave = stage {
                try Data("damaged preferences".utf8).write(to: preferencesURL)
                throw CocoaError(.fileWriteUnknown)
            }
        })
        #expect(throws: TemplateTransactionError.recoveryRequired) { try transaction.commit(plan) }
        #expect(FileManager.default.fileExists(atPath: journalURL.path))
        #expect(try Data(contentsOf: preferencesURL) == Data("damaged preferences".utf8))
        #expect(try assets.data(for: plan.assets[0].reference) == plan.assets[0].bytes)
    }
    @Test func recoveryPreservesReplacedAssetsAndCorruptEvidence() throws {
        let root=try root(); defer { try? FileManager.default.removeItem(at:root) }
        let assets=DocumentTemplateStore(directory:root.appendingPathComponent("assets")), prefsURL=root.appendingPathComponent("prefs.json"), journalURL=root.appendingPathComponent("journal.json")
        let original=emptyPreferences(); try FileMintPreferencesStore(fileURL:prefsURL).save(original)
        let package=try TemplatePackageCodec.decode(TemplatePackageCodec.encode(templates:[BuiltInDocumentTemplate.allCases[0].template],defaults:[:],assets:assets))
        let plan=try TemplateImportPlanner.plan(package,into:original)
        let interrupted=TemplateImportTransaction(journalURL:journalURL,preferencesURL:prefsURL,assets:assets,fault:{ stage in if case .published=stage { throw TemplateImportTransaction.Interruption() } })
        #expect(throws:TemplateImportTransaction.Interruption.self) { try interrupted.commit(plan) }
        let reference=plan.assets[0].reference, file=assets.directory.appendingPathComponent(reference.id.uuidString+"."+reference.kind.rawValue)
        let journal=try Data(contentsOf:journalURL)
        let previous=file.appendingPathExtension("preserved"); try FileManager.default.moveItem(at:file,to:previous)
        try plan.assets[0].bytes.write(to:file)
        let recovery=TemplateImportTransaction(journalURL:journalURL,preferencesURL:prefsURL,assets:assets)
        #expect(throws:TemplateTransactionError.recoveryRequired) { try recovery.recover() }
        #expect(try Data(contentsOf:file)==plan.assets[0].bytes && Data(contentsOf:journalURL)==journal)
        try Data("broken".utf8).write(to:journalURL)
        #expect(throws:TemplateTransactionError.recoveryRequired) { try recovery.recover() }
        #expect(try Data(contentsOf:journalURL)==Data("broken".utf8))
    }

    @Test func changingEarlierImportChoicesRecomputesDependentConflicts() throws {
        let first = text("custom-first", name: "Notes", content: "one")
        var second = text("custom-second", name: "Notes", content: "two")
        second.rank = 20
        let package = try TemplatePackageCodec.decode(TemplatePackageCodec.encode(
            templates: [first, second], defaults: [:], assets: DocumentTemplateStore()))
        let initial = try TemplateImportPlanner.plan(package, into: emptyPreferences())
        #expect(initial.rows.map(\.choice) == [.add, .copy])
        let skipped = try TemplateImportPlanner.plan(package, into: emptyPreferences(),
            choices: [first.id: .skip, second.id: .copy])
        #expect(skipped.rows.map(\.choice) == [.skip, .copy])
        #expect(skipped.preferences.templates.count == 1 && skipped.preferences.templates[0].content == "two")
        #expect(skipped.preferences.templates[0].displayName == "Notes Copy")
        let added = try TemplateImportPlanner.plan(package, into: emptyPreferences(),
            choices: [first.id: .skip, second.id: .add])
        #expect(added.rows.map(\.choice) == [.skip, .add])
        let reenabled = try TemplateImportPlanner.plan(package, into: emptyPreferences(),
            choices: [first.id: .add, second.id: .add])
        #expect(reenabled.rows.map(\.choice) == [.add, .copy])
    }

    @Test func preferenceChangesAtCommitBoundaryAreNeverOverwritten() throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        let preferencesURL = root.appendingPathComponent("preferences.json")
        let journalURL = root.appendingPathComponent("journal.json")
        let assets = DocumentTemplateStore(directory: root.appendingPathComponent("assets"))
        let store = FileMintPreferencesStore(fileURL: preferencesURL), original = emptyPreferences()
        try store.save(original)
        let package = try TemplatePackageCodec.decode(TemplatePackageCodec.encode(
            templates: [text()], defaults: [:], assets: assets))
        let plan = try TemplateImportPlanner.plan(package, into: original)
        let attempt = Date(timeIntervalSince1970: 1234)
        let interrupted = TemplateImportTransaction(journalURL: journalURL, preferencesURL: preferencesURL, assets: assets, fault: { stage in
            if case .beforeSave = stage {
                try FileMintPreferencesStore(fileURL: preferencesURL).update { $0.lastUpdateCheckAttempt = attempt }
            }
        })
        #expect(throws: TemplateTransactionError.staleReview) { try interrupted.commit(plan) }
        #expect(store.load().templates.isEmpty && store.load().lastUpdateCheckAttempt == attempt)
        #expect(!FileManager.default.fileExists(atPath: journalURL.path))

        let baseline = store.load()
        let currentPlan = try TemplateImportPlanner.plan(package, into: baseline)
        let receipt = try TemplateImportTransaction(journalURL: journalURL, preferencesURL: preferencesURL, assets: assets).commit(currentPlan)
        var stale = baseline; stale.revealAfterCreation.toggle()
        #expect(throws: FileMintPreferencesStoreError.stalePreferences) { try store.save(stale, ifUnchangedFrom: baseline) }
        #expect(store.load() == receipt.preferences)
        try store.update { $0.lastUpdateCheckAttempt = Date(timeIntervalSince1970: 5678) }
        #expect(store.load().templates == receipt.preferences.templates)
        #expect(store.load().lastTemplateImportTransactionID == receipt.preferences.lastTemplateImportTransactionID)
        #expect(store.load().lastUpdateCheckAttempt == Date(timeIntervalSince1970: 5678))
    }

    @Test func exportPublishesExactBytesAndPreservesDestinationOnFailure() async throws {
        let root = try root(); defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("Templates.filemint-templates")
        let first = try TemplatePackageCodec.encode(templates: [text()], defaults: [:], assets: DocumentTemplateStore())
        try TemplatePackageCodec.write(first, to: target)
        #expect(try Data(contentsOf: target) == first)
        let second = try TemplatePackageCodec.encode(templates: [text(content: "replacement")], defaults: [:], assets: DocumentTemplateStore())
        try TemplatePackageCodec.write(second, to: target)
        #expect(try Data(contentsOf: target) == second)
        let cancelled = Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            try TemplatePackageCodec.write(first, to: target)
        }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(try Data(contentsOf: target) == second)
        let link = root.appendingPathComponent("link.filemint-templates")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(throws: TemplatePackageError.invalid) { try TemplatePackageCodec.write(first, to: link) }
        #expect(try Data(contentsOf: target) == second)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == ["Templates.filemint-templates", "link.filemint-templates"])
    }
}

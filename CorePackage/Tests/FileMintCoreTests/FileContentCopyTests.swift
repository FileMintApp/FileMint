import Darwin
import Foundation
import FileMintCore
import Testing

@Suite("Copy complete file contents")
struct FileContentCopyTests {
    private func fixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("copy-content-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    @Test("default-off migration, independent choices and menu placement")
    func preferences() throws {
        for json in [#"{}"#, #"{"copyContents":"invalid","copyNames":false,"copyPaths":true}"#] {
            let value = try JSONDecoder().decode(FileToolsPreferences.self, from: Data(json.utf8))
            #expect(!value.copyContents)
        }
        var value = FileToolsPreferences()
        value.isEnabled = true; value.copyNames = false
        value.setEnabled(true, for: .copyContents); value.mainMenuTools.insert(.copyContents)
        value.isEnabled = false
        let restored = try JSONDecoder().decode(FileToolsPreferences.self, from: JSONEncoder().encode(value))
        #expect(restored.copyContents && !restored.copyNames && restored.copyPaths)
        #expect(!restored.allows(.copyContents) && restored.mainMenuTools.contains(.copyContents))
        value.isEnabled = true
        let layout = FileToolsMenuLayout(tools: [.copyContents], hasMoveDestination: false, preferences: value)
        #expect(layout.main == [.copyContents] && layout.submenu.isEmpty)
    }

    @Test("menu selects one ordinary candidate without opening its contents")
    func menu() throws {
        try fixture { root in
            var prefs = FileMintPreferences.default
            prefs.monitoredFolderURLs = [root]; prefs.fileTools.isEnabled = true; prefs.fileTools.copyContents = true
            let file = root.appendingPathComponent("代码.ts")
            try Data("hello".utf8).write(to: file)
            let selection = try FileInfoSelection.capture([file])
            #expect(FileContentCopyPolicy.isEnabled(for: selection, preferences: prefs))
            #expect(FileToolsPolicy.availableTools(selection: [file], isItemMenu: true, preferences: prefs).contains(.copyContents))
            #expect(!FileToolsPolicy.availableTools(selection: [file, file], isItemMenu: true, preferences: prefs).contains(.copyContents))
            #expect(!FileToolsPolicy.availableTools(target: .directory(root), preferences: prefs).contains(.copyContents))
            for name in ["a.png", "a.svg", "a.pdf", "a.docx", "a.xlsx", "a.pptx", "a.rtfd", "a.zip", "a.bin"] {
                let other = root.appendingPathComponent(name)
                try Data("still text".utf8).write(to: other)
                #expect(!FileContentCopyPolicy.supportsMenuSelection([other]))
            }
            let link = root.appendingPathComponent("link.txt")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
            #expect(!FileContentCopyPolicy.supportsMenuSelection([link]))
            #expect(!FileContentCopyPolicy.supportsMenuSelection([root]))
            let fifo = root.appendingPathComponent("pipe.txt")
            #expect(mkfifo(fifo.path, 0o600) == 0)
            #expect(!FileContentCopyPolicy.supportsMenuSelection([fifo]))
            prefs.monitoredFolderURLs = []
            #expect(!FileContentCopyPolicy.isEnabled(for: selection, preferences: prefs))
        }
    }

    @Test("common code, markup, config and extensionless names are text candidates")
    func candidates() {
        for name in ["a.TXT", "a.tsx", "a.swift", "a.py", "a.sh", "a.json", "a.yaml", "a.toml",
                     "a.csv", "a.md", "a.html", "a.xml", "README", "LICENSE", "Dockerfile", ".gitignore", ".env"] {
            #expect(FileContentCopyPolicy.format(for: URL(fileURLWithPath: "/fixture/\(name)")) == .plainText)
        }
    }

    @Test("UTF-8 and BOM UTF-16 preserve complete Unicode, whitespace and exact line endings")
    func encoding() throws {
        let text = "  let 文本 = \"🪴e\u{301}\";\r\n\tline\rfinal\n\n"
        let utf8 = Data(text.utf8)
        let encodings: [(Data, String.Encoding)] = [(Data(), .utf8), (Data([0xEF, 0xBB, 0xBF]), .utf8),
            (Data([0xFF, 0xFE]), .utf16LittleEndian), (Data([0xFE, 0xFF]), .utf16BigEndian)]
        for (bom, encoding) in encodings {
            let input = bom + (try #require(text.data(using: encoding)))
            #expect(Data(try FileContentCopyPolicy.decodeText(input).utf8) == utf8)
        }
        #expect(try FileContentCopyPolicy.decodeText(Data(" \t\r\n".utf8)) == " \t\r\n")
        #expect(try FileContentCopyPolicy.decodeText(Data("x\u{FEFF}y".utf8)) == "x\u{FEFF}y")
    }

    @Test("invalid encodings, binary controls and empty files never yield repaired text")
    func invalidText() {
        for bytes: [UInt8] in [[0xC0, 0xAF], [0xED, 0xA0, 0x80], [0xFF], [0xFF, 0xFE, 0x00, 0xD8],
                              [0xFE, 0xFF, 0xDC, 0x00], [0xFF, 0xFE, 0x41], [0xFF, 0xFE, 0, 0, 0x41, 0, 0, 0],
                              [65, 0, 66], [65, 27, 66], [65, 127, 66]] {
            #expect(throws: FileContentCopyError.invalidEncoding) { try FileContentCopyPolicy.decodeText(Data(bytes)) }
        }
        for bytes: [UInt8] in [[], [0xEF, 0xBB, 0xBF], [0xFE, 0xFF]] {
            #expect(throws: FileContentCopyError.empty) { try FileContentCopyPolicy.decodeText(Data(bytes)) }
        }
    }

    @Test("source and decoded output limits reject rather than truncate")
    func limits() throws {
        let maximum = FileContentCopyPolicy.maximumBytes
        #expect(try FileContentCopyPolicy.decodeText(Data(repeating: 65, count: maximum)).utf8.count == maximum)
        #expect(throws: FileContentCopyError.tooLarge) {
            try FileContentCopyPolicy.decodeText(Data(repeating: 65, count: maximum + 1))
        }
        let expands = String(repeating: "中", count: maximum / 3 + 1)
        let utf16 = Data([0xFF, 0xFE]) + (try #require(expands.data(using: .utf16LittleEndian)))
        #expect(utf16.count < maximum)
        #expect(throws: FileContentCopyError.tooLarge) { try FileContentCopyPolicy.decodeText(utf16) }
        try fixture { root in
            let file = root.appendingPathComponent("large.txt")
            try Data().write(to: file)
            let handle = try FileHandle(forWritingTo: file)
            try handle.truncate(atOffset: UInt64(maximum + 1)); try handle.close()
            #expect(throws: FileContentCopyError.tooLarge) { try FileContentRead.read(FileInfoSelection.capture([file])) }
        }
    }

    @Test("real reads preserve sources and reject replacement, later changes and cancellation")
    func reading() throws {
        try fixture { root in
            let file = root.appendingPathComponent("sample.swift")
            let original = Data("// 中文 🪴\r\n\tlet x = 1\n".utf8)
            try original.write(to: file)
            let selection = try FileInfoSelection.capture([file])
            let contents = try FileContentRead.read(selection)
            #expect(contents.data == original && contents.format == .plainText)
            try contents.validate()
            #expect(try Data(contentsOf: file) == original)
            let token = FileDigestCancellation(); token.cancel()
            #expect(throws: FileInfoError.cancelled) { try FileContentRead.read(selection, cancellation: token) }
            try Data("changed".utf8).write(to: file)
            #expect(throws: FileInfoError.changed) { try contents.validate() }
            try FileManager.default.removeItem(at: file)
            try FileManager.default.createSymbolicLink(at: file, withDestinationURL: root.appendingPathComponent("outside"))
            #expect(throws: FileInfoError.changed) { try FileContentRead.read(selection) }
        }
    }

    @Test("tickets contain identity and change counter, consume once and expire on their own route")
    func tickets() throws {
        try fixture { root in
            let file = root.appendingPathComponent("sample.txt")
            try Data("private content not for a ticket".utf8).write(to: file)
            let request = FileOperationRequest.copyContents(selection: try FileInfoSelection.capture([file]), pasteboardChangeCount: 42)
            let store = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let url = try store.enqueue(request, now: now)
            #expect(FileOperationTicketStore.isCopyContentsURL(url))
            #expect(try store.consume(url, now: now) == request)
            #expect(try store.consume(url, now: now) == nil)
            let expired = try store.enqueue(request, now: now)
            #expect(try store.consume(expired, now: now.addingTimeInterval(61)) == nil)
            let route = try store.enqueue(request, now: now)
            let wrong = URL(string: route.absoluteString.replacingOccurrences(of: "copy-contents", with: "move"))!
            #expect(try store.consume(wrong, now: now) == nil)
        }
    }

    @Test("RTF framing rejects truncation, attachments, excessive nesting and trailing documents")
    func richTextFraming() throws {
        let valid = #"{\rtf1\ansi Text \{literal\} \\ \'e9 {\b bold}\par}"#
        try FileContentCopyPolicy.validateRTFStructure(Data(valid.utf8))
        for invalid in [#"{\rtf1 missing"#, #"{\rtf1 done}extra"#, #"{\rtf1 one}{\rtf1 two}"#,
                        #"{\rtf1 {\pict image}}"#, #"{\rtf1 {\object x}}"#, #"{\rtf1 \bin4 aaaa}"#,
                        #"{\rtf1 \'xz}"#, #"{\rtf12 x}"#,
                        "{\\rtf1 " + String(repeating: "{", count: 129) + String(repeating: "}", count: 130)] {
            #expect(throws: FileContentCopyError.invalidRTF) { try FileContentCopyPolicy.validateRTFStructure(Data(invalid.utf8)) }
        }
    }
}

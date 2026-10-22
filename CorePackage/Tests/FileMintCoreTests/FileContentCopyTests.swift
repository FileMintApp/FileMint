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
        let leadingFEFF = "\u{FEFF}A"
        for (bom, encoding) in encodings.dropFirst() {
            let input = bom + (try #require(leadingFEFF.data(using: encoding)))
            #expect(Array(try FileContentCopyPolicy.decodeText(input).utf8) == Array(leadingFEFF.utf8))
        }
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

    @Test("RTF extracts the complete supported body independently of rich rendering")
    func richTextBody() throws {
        let valid = #"{\rtf1\ansi Text \{literal\} \\ \'e9 {\b bold}\par}"#
        #expect(try FileContentCopyPolicy.validatedRTFText(Data(valid.utf8)) == "Text {literal} \\ é bold\n")
        let styled = #"{\rtf1\ansi\ansicpg1252\deff0\uc1{\fonttbl{\f0\fnil\fcharset0 Helvetica;}}{\colortbl;\red255\green0\blue0;}{\*\expandedcolortbl;\cssrgb\c100000\c0\c0;}\f0\fs24\qc\b\cf1 Bold \u20013?\u25991?\b0\cf0\par\ql\i Italic\i0\tab last}"#
        #expect(try FileContentCopyPolicy.validatedRTFText(Data(styled.utf8)) == "Bold 中文\nItalic\tlast")
        let groups = #"{\rtf1\ansi\uc1 A{\uc0\u20013}\u25991?\u-10178?\u-8524?\u101?\u769?\u123\{\u125\}\u92\\}"#
        #expect(Array(try FileContentCopyPolicy.validatedRTFText(Data(groups.utf8)).utf8)
            == Array("A中文🪴e\u{301}{}\\".utf8))
        let cp1252 = #"{\rtf1\ansi \'80\'82\'9f\'a0\'e9\~\_\emdash\line\tab}"#
        #expect(try FileContentCopyPolicy.validatedRTFText(Data(cp1252.utf8)) == "€‚Ÿ é ‑—\u{2028}\t")
        for fonts in [#"\f0\fnil Helvetica;\f1\fmodern Courier;"#,
                      #"{\f0\fnil Helvetica;}{\f1\fmodern Courier;}"#,
                      #"{\f0\fnil\uc0\u20013\u25991;}"#] {
            let source = "{\\rtf1{\\fonttbl" + fonts + "}\\f0 Font body}"
            #expect(try FileContentCopyPolicy.validatedRTFText(Data(source.utf8)) == "Font body")
        }
    }

    @Test("Cocoa Unicode RTF has exact text without guessing its declared code page")
    func cocoaRichText() throws {
        let source = """
        {\\rtf1\\ansi\\ansicpg936\\cocoartf2908
        \\cocoatextscaling0\\cocoaplatform0{\\fonttbl\\f0\\fnil\\fcharset0 HelveticaNeue;}
        {\\colortbl;\\red255\\green255\\blue255;}
        {\\*\\expandedcolortbl;;}
        \\pard\\tx560\\tx1120\\pardirnatural\\partightenfactor0
        \\f0\\fs26 \\cf0 \\uc0\\u27979 \\u35797  \\u55358 \\u57012  \\u233\\
        line\t2}
        """
        #expect(try FileContentCopyPolicy.validatedRTFText(Data(source.utf8)) == "测试 🪴 é\nline\t2")
        #expect(throws: FileContentCopyError.invalidRTF) {
            try FileContentCopyPolicy.validatedRTFText(Data(source.replacingOccurrences(of: "\\u233", with: "\\'e9").utf8))
        }
        #expect(try FileContentCopyPolicy.validatedRTFText(Data("{\\rtf1\\uc0\\u65\\\r\nB\tC}".utf8)) == "A\nB\tC")
    }

    @Test("RTF rejects malformed syntax, lossy text and unsupported destinations")
    func rejectedRichText() throws {
        for invalid in [#"{\rtf1 missing"#, #"{\rtf1 done}extra"#, #"{\rtf1 one}{\rtf1 two}"#,
                        #"{\rtf1 {\pict image}}"#, #"{\rtf1 {\object x}}"#, #"{\rtf1 \bin4 aaaa}"#,
                        #"{\rtf1 \'xz}"#, #"{\rtf12 x}"#,
                        #"{\rtf1 \u2147483647?}"#, #"{\rtf1 \u65536?}"#, #"{\rtf1 \u-32769?}"#,
                        #"{\rtf1 \u99999999999999999999?}"#, #"{\rtf1 \u-?}"#, #"{\rtf1 \uc2\u65??}"#,
                        #"{\rtf1 \u65}"#, #"{\rtf1 \u65\par}"#, #"{\rtf1 \u-10178?x}"#,
                        #"{\rtf1 \uc0\u57012}"#, #"{\rtf1 \uc0\u55358\b\u57012}"#,
                        #"{\rtf1 \uc0\u55358{\u57012}}"#, #"{\rtf1 \uc0\u0}"#,
                        #"{\rtf1 \v hidden\v0 visible}"#, #"{\rtf1 {\header missing}body}"#,
                        #"{\rtf1 {\footnote missing}body}"#, #"{\rtf1 {\annotation missing}body}"#,
                        #"{\rtf1 {\field{\*\fldinst HYPERLINK x}{\fldrslt label}}}"#,
                        #"{\rtf1 {\upr{old}{\*\ud new}}}"#, #"{\rtf1 \trowd a\cell b\row}"#,
                        #"{\rtf1 {\listtext missing}body}"#, #"{\rtf1 {\*\unknown missing}body}"#,
                        #"{\rtf1 \unknown missing}"#, #"{\rtf1 \b2 bad}"#, #"{\rtf1 \par1 bad}"#,
                        #"{\rtf1 A\-B}"#, #"{\rtf1 A\qmspace B}"#,
                        #"{\rtf1\deff32768 bad}"#, #"{\rtf1\deflang65536 bad}"#,
                        #"{\rtf1\deflangfe65536 bad}"#, #"{\rtf1\paperw0 bad}"#,
                        #"{\rtf1\paperh0 bad}"#,
                        #"{\rtf1 \ansicpg0 bad}"#, #"{\rtf1 \ansicpg936 \'e9}"#,
                        #"{\rtf1 \'81}"#, #"{\rtf1 \'8d}"#, #"{\rtf1 \'8f}"#,
                        #"{\rtf1 \'90}"#, #"{\rtf1 \'9d}"#,
                        #"{\rtf1{\fonttbl\f0\fcharset1 Arial;}text}"#,
                        #"{\rtf1{\fonttbl\f0\fcharset2 Symbol;}text}"#,
                        #"{\rtf1{\fonttbl\f0\cpg1252 Arial;}text}"#,
                        #"{\rtf1{\fonttbl Arial;}text}"#, #"{\rtf1{\fonttbl\f0 Arial}text}"#,
                        #"{\rtf1{\fonttbl\f0 ;}text}"#, #"{\rtf1{\fonttbl}text}"#,
                        #"{\rtf1{\fonttbl\f0 Arial;extra}text}"#,
                        #"{\rtf1{\fonttbl{\f0 Arial;extra}}text}"#,
                        #"{\rtf1{\fonttbl{{\f0 Arial;}}}text}"#,
                        #"{\rtf1{\fonttbl{\f0 Arial;\f1 Courier;}}text}"#,
                        #"{\rtf1{\fonttbl{\f0 Arial;}\f1 Courier;}text}"#,
                        #"{\rtf1{\fonttbl\f0 Arial;{\f1 Courier;}}text}"#,
                        #"{\rtf1{\fonttbl\f0 Arial;\f0 Courier;}text}"#,
                        #"{\rtf1{\fonttbl\f0 Arial\fcharset0;}text}"#,
                        #"{\rtf1{\fonttbl\f0\par Arial;}text}"#,
                        #"{\rtf1{\fonttbl\f0 Arial\'3b}text}"#,
                        #"{\rtf1 text{\fonttbl\f0 Arial;}}"#, #"{\rtf1 text\ansicpg1252 more}"#,
                        #"{\rtf1{\b{\colortbl;}}text}"#, #"{\rtf1{\*\b missing}body}"#,
                        #"{\rtf1{\*\fonttbl\f0 Arial;}text}"#,
                        #"{\rtf1{\colortbl;\red256;}text}"#, #"{\rtf1{\colortbl;\red1}text}"#,
                        #"{\rtf1{\*\expandedcolortbl;\cssrgb\c1;}text}"#,
                        #"{\rtf1{\*\expandedcolortbl;\csgray\c100001;}text}"#,
                        "{\\rtf1 " + String(repeating: "{", count: 129) + String(repeating: "}", count: 130)] {
            #expect(throws: FileContentCopyError.invalidRTF, Comment(rawValue: invalid)) {
                try FileContentCopyPolicy.validatedRTFText(Data(invalid.utf8))
            }
        }
        for value in ["{\\rtf1}", "{\\rtf1{\\fonttbl\\f0 Arial;}}"] {
            #expect(throws: FileContentCopyError.empty) { try FileContentCopyPolicy.validatedRTFText(Data(value.utf8)) }
        }
    }

    @Test("RTF bounds source and expanded UTF-8 without truncation")
    func richTextLimits() throws {
        let maximum = FileContentCopyPolicy.maximumBytes
        #expect(throws: FileContentCopyError.tooLarge) {
            try FileContentCopyPolicy.validatedRTFText(Data(repeating: 65, count: maximum + 1))
        }
        let text = Data(repeating: 0x80, count: maximum / 3 + 1)
        let source = Data("{\\rtf1\\ansi ".utf8) + text + Data("}".utf8)
        #expect(source.count < maximum)
        #expect(throws: FileContentCopyError.tooLarge) {
            try FileContentCopyPolicy.validatedRTFText(source)
        }
    }

    @Test("RTF traverses 128 groups without recursion and rejects the 129th")
    func richTextNestingLimit() throws {
        let accepted = "{\\rtf1\\uc1 " + String(repeating: "{\\uc0", count: 127)
            + "\\u20013" + String(repeating: "}", count: 127) + "\\u25991?}"
        #expect(try FileContentCopyPolicy.validatedRTFText(Data(accepted.utf8)) == "中文")
        let rejected = "{\\rtf1 " + String(repeating: "{", count: 128)
            + "text" + String(repeating: "}", count: 129)
        #expect(throws: FileContentCopyError.invalidRTF) {
            try FileContentCopyPolicy.validatedRTFText(Data(rejected.utf8))
        }
    }
}

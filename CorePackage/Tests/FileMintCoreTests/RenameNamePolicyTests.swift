import FileMintCore
import Foundation
import Testing

@Suite("Batch rename name policy")
struct RenameNamePolicyTests {
    @Test("hidden markers and file suffixes are frozen without changing bytes")
    func splitsFileNames() throws {
        let cases = [
            ("README", "", "README", ""),
            (".env", ".", "env", ""),
            (".env.local", ".", "env", ".local"),
            ("archive.TAR.GZ", "", "archive", ".TAR.GZ"),
            ("archive.tar.bz2", "", "archive", ".tar.bz2"),
            ("archive.tar.xz", "", "archive", ".tar.xz"),
            ("archive.tar.zst", "", "archive", ".tar.zst"),
            ("types.D.TS", "", "types", ".D.TS"),
            (".config.tar.gz", ".", "config", ".tar.gz"),
            ("tar.gz", "", "tar", ".gz"),
            (".tar.gz", ".", "tar", ".gz"),
            ("report.custom", "", "report", ".custom"),
            ("report.", "", "report.", ""),
            ("...", ".", "..", ""),
            (".\u{301}env", ".", "\u{301}env", ""),
            ("report.\u{301}txt", "", "report", ".\u{301}txt")
        ]
        for (original, marker, body, suffix) in cases {
            let parts = try RenameNamePolicy.split(original, kind: .file)
            #expect(Data(parts.originalName.utf8) == Data(original.utf8))
            #expect(Data(parts.hiddenMarker.utf8) == Data(marker.utf8))
            #expect(Data(parts.body.utf8) == Data(body.utf8))
            #expect(Data(parts.suffix.utf8) == Data(suffix.utf8))
            #expect(parts.kind == .file)
            #expect(Data(try RenameNamePolicy.output(body: parts.body, parts: parts).utf8) == Data(original.utf8))
        }
    }

    @Test("directory periods never become a protected suffix")
    func splitsDirectories() throws {
        let parts = try RenameNamePolicy.split(".Photos.2025.tar.gz", kind: .directory)
        #expect(parts.kind == .directory)
        #expect(parts.hiddenMarker == ".")
        #expect(parts.body == "Photos.2025.tar.gz")
        #expect(parts.suffix.isEmpty)
        #expect(try RenameNamePolicy.output(body: "Photos.2026", parts: parts) == ".Photos.2026")
    }

    @Test("capture rejects unsafe components and enforces the UTF-8 original limit")
    func rejectsInvalidOriginals() throws {
        for original in ["", ".", "..", "one/two", "nul\0name"] {
            #expect(throws: RenameNameError.invalidComponent) {
                try RenameNamePolicy.split(original, kind: .file)
            }
        }
        let maximum = String(repeating: "🪴", count: 256)
        #expect(maximum.utf8.count == 1_024)
        #expect(try RenameNamePolicy.split(maximum, kind: .file).originalName == maximum)
        #expect(throws: RenameNameError.originalNameTooLong) {
            try RenameNamePolicy.split(maximum + "a", kind: .file)
        }
    }

    @Test("changed names preserve the original hidden marker and suffix bytes")
    func composesProtectedParts() throws {
        let parts = try RenameNamePolicy.split(".archive.TAR.GZ", kind: .file)
        #expect(try RenameNamePolicy.output(body: "new.name", parts: parts) == ".new.name.TAR.GZ")
        let unicodeSuffix = try RenameNamePolicy.split("old.E\u{301}XT", kind: .file)
        let result = try RenameNamePolicy.output(body: "new", parts: unicodeSuffix)
        #expect(Data(result.utf8) == Data("new.E\u{301}XT".utf8))
        #expect(Data(result.utf8) != Data("new.ÉXT".utf8))
    }

    @Test("list-like bodies do not have suffixes guessed or stripped")
    func doesNotReparseBody() throws {
        let parts = try RenameNamePolicy.split("old.txt", kind: .file)
        #expect(try RenameNamePolicy.output(body: "new.txt", parts: parts) == "new.txt.txt")
        #expect(try RenameNamePolicy.output(body: "new.tar.gz", parts: parts) == "new.tar.gz.txt")
    }

    @Test("suffixless regular files cannot gain an extension")
    func protectsSuffixlessFiles() throws {
        for original in ["README", ".env"] {
            let parts = try RenameNamePolicy.split(original, kind: .file)
            #expect(throws: RenameNameError.extensionChange) {
                try RenameNamePolicy.output(body: parts.body + ".txt", parts: parts)
            }
            #expect(throws: RenameNameError.extensionChange) {
                try RenameNamePolicy.output(body: "new.name", parts: parts)
            }
        }
        let directory = try RenameNamePolicy.split("Photos", kind: .directory)
        #expect(try RenameNamePolicy.output(body: "Photos.2026", parts: directory) == "Photos.2026")
    }

    @Test("empty bodies and newly introduced hidden markers are rejected")
    func rejectsEmptyOrHiddenBody() throws {
        for original in ["notes.txt", ".notes.txt"] {
            let parts = try RenameNamePolicy.split(original, kind: .file)
            #expect(throws: RenameNameError.emptyBody) { try RenameNamePolicy.output(body: "", parts: parts) }
            for body in [".new", ".", "..", ".\u{301}new"] {
                #expect(throws: RenameNameError.hiddenStatusChange) {
                    try RenameNamePolicy.output(body: body, parts: parts)
                }
            }
        }
    }

    @Test("complete components reject leading or trailing Unicode whitespace")
    func rejectsWhitespaceEdges() throws {
        let parts = try RenameNamePolicy.split("Folder", kind: .directory)
        for whitespace in [" ", "\t", "\n", "\u{A0}", "\u{2003}", "\u{202F}"] {
            for body in [whitespace + "new", "new" + whitespace] {
                #expect(throws: RenameNameError.leadingOrTrailingWhitespace) {
                    try RenameNamePolicy.output(body: body, parts: parts)
                }
            }
        }
    }

    @Test("edge rules apply to complete names rather than adding stricter body rules")
    func permitsInternalBodyWhitespaceAndPeriods() throws {
        let file = try RenameNamePolicy.split("old.txt", kind: .file)
        #expect(try RenameNamePolicy.output(body: "new ", parts: file) == "new .txt")
        #expect(try RenameNamePolicy.output(body: "new.", parts: file) == "new..txt")
        let hiddenFile = try RenameNamePolicy.split(".old.txt", kind: .file)
        #expect(try RenameNamePolicy.output(body: " new ", parts: hiddenFile) == ". new .txt")
        let directory = try RenameNamePolicy.split("Folder", kind: .directory)
        #expect(throws: RenameNameError.trailingPeriod) {
            try RenameNamePolicy.output(body: "new.", parts: directory)
        }
    }

    @Test("unsafe path components and prohibited output scalars are rejected")
    func rejectsInvalidOutputCharacters() throws {
        let parts = try RenameNamePolicy.split("old.txt", kind: .file)
        for body in ["one/two", "nul\0name"] {
            #expect(throws: RenameNameError.invalidComponent) {
                try RenameNamePolicy.output(body: body, parts: parts)
            }
        }
        for scalar in [":", "\\", "\u{1}", "\u{7F}", "\u{85}", "\u{2028}", "\u{2029}"] {
            #expect(throws: RenameNameError.invalidCharacter) {
                try RenameNamePolicy.output(body: "a" + scalar + "b", parts: parts)
            }
        }
    }

    @Test("emoji joiners and exact Unicode output spelling are preserved")
    func preservesEmojiAndUnicode() throws {
        let parts = try RenameNamePolicy.split("old.txt", kind: .file)
        let body = "👨‍👩‍👧‍👦-cafe\u{301}-中文"
        let result = try RenameNamePolicy.output(body: body, parts: parts)
        #expect(Data(result.utf8) == Data("👨‍👩‍👧‍👦-cafe\u{301}-中文.txt".utf8))
        #expect(Data(result.utf8) != Data("👨‍👩‍👧‍👦-café-中文.txt".utf8))
    }

    @Test("new-output limits count all UTF-8 bytes including marker and suffix")
    func outputByteLimits() throws {
        let parts = try RenameNamePolicy.split(".old.txt", kind: .file)
        let exactBody = String(repeating: "a", count: 250)
        #expect(try RenameNamePolicy.output(body: exactBody, parts: parts).utf8.count == 255)
        #expect(throws: RenameNameError.outputNameTooLong(limit: 255)) {
            try RenameNamePolicy.output(body: exactBody + "a", parts: parts)
        }
        let suffixless = try RenameNamePolicy.split("old", kind: .file)
        let unicodeBody = String(repeating: "🪴", count: 63) + "abc"
        #expect(try RenameNamePolicy.output(body: unicodeBody, parts: suffixless).utf8.count == 255)
        #expect(throws: RenameNameError.outputNameTooLong(limit: 255)) {
            try RenameNamePolicy.output(body: unicodeBody + "a", parts: suffixless)
        }
    }

    @Test("only positive native limits constrain changed names")
    func nativeByteLimits() throws {
        let parts = try RenameNamePolicy.split("old.txt", kind: .file)
        #expect(try RenameNamePolicy.output(body: "new", parts: parts, nativeNameByteLimit: 7) == "new.txt")
        #expect(throws: RenameNameError.outputNameTooLong(limit: 6)) {
            try RenameNamePolicy.output(body: "new", parts: parts, nativeNameByteLimit: 6)
        }
        for limit in [0, -1, Int.min, 255, 1_024, Int.max] {
            #expect(try RenameNamePolicy.output(body: "new", parts: parts, nativeNameByteLimit: limit) == "new.txt")
        }
        #expect(throws: RenameNameError.outputNameTooLong(limit: 255)) {
            try RenameNamePolicy.output(body: String(repeating: "a", count: 252), parts: parts,
                                        nativeNameByteLimit: 1_024)
        }
    }

    @Test("unchanged originals bypass output character and byte restrictions")
    func preservesUnchangedOriginals() throws {
        let originals = ["report.", "...", " old name ", "old:name", "old\\name", "old\nname",
                         String(repeating: "🪴", count: 256)]
        for original in originals {
            let parts = try RenameNamePolicy.split(original, kind: .file)
            let result = try RenameNamePolicy.output(body: parts.body, parts: parts, nativeNameByteLimit: 1)
            #expect(Data(result.utf8) == Data(original.utf8))
        }
    }

    @Test("canonical equivalence cannot activate the unchanged exemption")
    func unchangedRequiresExactBytes() throws {
        let parts = try RenameNamePolicy.split("é", kind: .file)
        #expect(try RenameNamePolicy.output(body: "é", parts: parts, nativeNameByteLimit: 1) == "é")
        #expect(throws: RenameNameError.outputNameTooLong(limit: 2)) {
            try RenameNamePolicy.output(body: "e\u{301}", parts: parts, nativeNameByteLimit: 2)
        }
        #expect(Data(try RenameNamePolicy.output(body: "e\u{301}", parts: parts).utf8) == Data([0x65, 0xCC, 0x81]))
        let cased = try RenameNamePolicy.split("Name.txt", kind: .file)
        #expect(Data(try RenameNamePolicy.output(body: "name", parts: cased).utf8) == Data("name.txt".utf8))
    }

    @Test("restoration validates only a safe single component")
    func restorationExemptions() throws {
        for original in ["report.", "...", " old name ", "old:name", "old\\name", "old\nname",
                         String(repeating: "🪴", count: 256)] {
            try RenameNamePolicy.validateRestorationComponent(original)
        }
        for original in ["", ".", "..", "one/two", "nul\0name"] {
            #expect(throws: RenameNameError.invalidComponent) {
                try RenameNamePolicy.validateRestorationComponent(original)
            }
        }
        let old = try RenameNamePolicy.split("report.", kind: .file)
        #expect(try RenameNamePolicy.output(body: "report", parts: old) == "report")
        try RenameNamePolicy.validateRestorationComponent(old.originalName)
    }

    @Test("namespace keys use canonical decomposition and optional Unicode case folding")
    func canonicalNamespaceKeys() {
        for caseSensitive in [true, false] {
            #expect(RenameNamePolicy.namespaceKey("café", caseSensitive: caseSensitive) ==
                    RenameNamePolicy.namespaceKey("cafe\u{301}", caseSensitive: caseSensitive))
        }
        #expect(RenameNamePolicy.namespaceKey("Name", caseSensitive: true) !=
                RenameNamePolicy.namespaceKey("name", caseSensitive: true))
        #expect(RenameNamePolicy.namespaceKey("Name", caseSensitive: false) ==
                RenameNamePolicy.namespaceKey("name", caseSensitive: false))
        #expect(RenameNamePolicy.namespaceKey("Straße", caseSensitive: false) ==
                RenameNamePolicy.namespaceKey("STRASSE", caseSensitive: false))
        #expect(RenameNamePolicy.namespaceKey("Σ", caseSensitive: false) ==
                RenameNamePolicy.namespaceKey("ς", caseSensitive: false))
    }

    @Test("namespace keys do not remove accents, fold width or compatibility-decompose")
    func namespaceDoesNotOverfold() {
        for caseSensitive in [true, false] {
            for (lhs, rhs) in [("é", "e"), ("Ａ", "A"), ("①", "1"), ("Ⅰ", "I")] {
                #expect(RenameNamePolicy.namespaceKey(lhs, caseSensitive: caseSensitive) !=
                        RenameNamePolicy.namespaceKey(rhs, caseSensitive: caseSensitive))
            }
        }
    }

    @Test("original names use natural order and raw UTF-8 tie breakers")
    func originalNameOrder() {
        #expect(RenameNamePolicy.compareOriginalNames("IMG_2.JPG", "IMG_10.JPG") == .orderedAscending)
        #expect(RenameNamePolicy.compareOriginalNames("IMG_10.JPG", "IMG_2.JPG") == .orderedDescending)
        #expect(RenameNamePolicy.compareOriginalNames("A", "a") == .orderedAscending)
        #expect(RenameNamePolicy.compareOriginalNames("a", "A") == .orderedDescending)
        #expect(RenameNamePolicy.compareOriginalNames("e\u{301}", "é") == .orderedAscending)
        #expect(RenameNamePolicy.compareOriginalNames("é", "e\u{301}") == .orderedDescending)
        #expect(RenameNamePolicy.compareOriginalNames("same", "same") == .orderedSame)
        let input = ["file10", "file2", "file1"]
        let sorted = input.sorted { RenameNamePolicy.compareOriginalNames($0, $1) == .orderedAscending }
        #expect(sorted == ["file1", "file2", "file10"])
    }
}

import FileMintCore
import Testing

@Suite("Batch rename ordered body rules")
struct BatchRenameRuleTests {
    private func apply(_ rules: [BatchRenameRule], _ body: String, ordinal: Int = 0, count: Int = 1) throws -> String {
        try BatchRenameRuleEngine.apply(rules, to: body, sortedOrdinal: ordinal, rowCount: count)
    }

    @Test("rules compose in order and recompute from the supplied original")
    func orderedRules() throws {
        let rules: [BatchRenameRule] = [
            .replace(search: "draft", replacement: "report"),
            .prepend("new-"), .append("-final"), .uppercase
        ]
        #expect(try apply(rules, "draft") == "NEW-REPORT-FINAL")
        #expect(try apply(rules, "draft") == "NEW-REPORT-FINAL")
        #expect(try apply([.append("x"), .replace(search: "x", replacement: "y")], "a") == "ay")
        #expect(try apply([.replace(search: "x", replacement: "y"), .append("x")], "a") == "ax")
        #expect(try apply([], "未改动👩‍💻") == "未改动👩‍💻")
    }

    @Test("replacement is literal, case-sensitive, nonoverlapping and does not revisit insertions")
    func literalReplacement() throws {
        #expect(try apply([.replace(search: "aa", replacement: "X")], "aaaaa") == "XXa")
        #expect(try apply([.replace(search: "aba", replacement: "X")], "ababa") == "Xba")
        #expect(try apply([.replace(search: "aaab", replacement: "X")], "aaaaab") == "aaX")
        #expect(try apply([.replace(search: "a", replacement: "aa")], "aab") == "aaaab")
        #expect(try apply([.replace(search: "A", replacement: "")], "AaA") == "a")
        #expect(try apply([.replace(search: ".*", replacement: "$1")], "a.*b.*") == "a$1b$1")
        #expect(try apply([.replace(search: "absent", replacement: "x")], "same") == "same")
    }

    @Test("replacement distinguishes canonical spellings and can match a combining scalar")
    func scalarExactReplacement() throws {
        let text = "é e\u{301}"
        let composed = try apply([.replace(search: "é", replacement: "X")], text)
        let decomposed = try apply([.replace(search: "e\u{301}", replacement: "Y")], text)
        #expect(Array(composed.utf8) == Array("X e\u{301}".utf8))
        #expect(Array(decomposed.utf8) == Array("é Y".utf8))
        #expect(try apply([.replace(search: "\u{301}", replacement: "")], text) == "é e")
        #expect(try apply([.replace(search: "👩", replacement: "👨")], "👩‍💻") == "👨‍💻")
    }

    @Test("rule equality preserves literal byte spelling")
    func ruleEquality() {
        #expect(BatchRenameRule.prepend("é") != .prepend("e\u{301}"))
        #expect(BatchRenameRule.append("é") != .append("e\u{301}"))
        #expect(BatchRenameRule.replace(search: "é", replacement: "x") != .replace(search: "e\u{301}", replacement: "x"))
        #expect(BatchRenameRule.replace(search: "x", replacement: "é") != .replace(search: "x", replacement: "e\u{301}"))
        #expect(BatchRenameNumbering(separator: "é") != BatchRenameNumbering(separator: "e\u{301}"))
        #expect(BatchRenameNumbering(body: .unified("é")) != BatchRenameNumbering(body: .unified("e\u{301}")))
        #expect(BatchRenameRule.number(.init()) == .number(.init()))
        #expect(BatchRenameRule.uppercase != .lowercase)
    }

    @Test("default and custom numbering use sorted ordinal with minimum padding")
    func numbering() throws {
        #expect(try apply([.number(.init())], "Photo", ordinal: 0, count: 3) == "Photo_001")
        #expect(try apply([.number(.init())], "Photo", ordinal: 2, count: 3) == "Photo_003")
        #expect(try apply([.number(.init(start: 7, step: 5, width: 2, separator: "-", position: .before))],
                          "Photo", ordinal: 2, count: 3) == "17-Photo")
        #expect(try apply([.number(.init(start: 1234, width: 1))], "Photo") == "Photo_1234")
        #expect(try apply([.number(.init(start: 0, width: 20))], "") == "00000000000000000000")
        #expect(try apply([.number(.init(start: Int64.max, width: 20))], "") == "09223372036854775807")
        #expect(try apply([.number(.init(separator: "", position: .before))], "Photo") == "001Photo")
    }

    @Test("numbering chooses current or unified body and omits separators for empty bodies")
    func numberingBody() throws {
        #expect(try apply([.prepend("pre-"), .number(.init())], "item") == "pre-item_001")
        #expect(try apply([.prepend("ignored-"), .number(.init(body: .unified("统一")))], "item") == "统一_001")
        #expect(try apply([.number(.init(separator: "---", position: .before, body: .unified("")))], "item") == "001")
        #expect(try apply([.replace(search: "x", replacement: ""), .number(.init())], "x") == "001")
        #expect(try apply([.replace(search: "x", replacement: "")], "x").isEmpty)
        #expect(try apply([.append("/"), .replace(search: "/", replacement: "")], "x") == "x")
    }

    @Test("default Unicode casing preserves context and full expansions")
    func unicodeCaseMapping() throws {
        #expect(try apply([.uppercase], "Straße ﬃ") == "STRASSE FFI")
        #expect(try apply([.lowercase], "ΟΣ ΟΣΑ Σ") == "ος οσα σ")
        #expect(try apply([.lowercase], "ΟΣ\u{301}") == "ος\u{301}")
        let lowered = try apply([.lowercase], "İ I I\u{301}")
        #expect(Array(lowered.utf8) == Array("i\u{307} i i\u{301}".utf8))
        #expect(try apply([.uppercase], "i ı") == "I I")
        let decomposedUpper = try apply([.uppercase], "e\u{301}")
        #expect(Array(decomposedUpper.utf8) == Array("E\u{301}".utf8))
        #expect(try apply([.lowercase], "文件👩‍💻") == "文件👩‍💻")
    }

    @Test("invalid parameters reject the whole plan, including later rows and unused literals")
    func invalidParameters() {
        #expect(throws: BatchRenameRuleError.emptySearch(ruleIndex: 0)) {
            try BatchRenameRuleEngine.validate([.replace(search: "", replacement: "")], rowCount: 1)
        }
        for numbering in [BatchRenameNumbering(start: -1), .init(step: 0), .init(step: -1), .init(width: 0), .init(width: 21)] {
            #expect(throws: BatchRenameRuleError.invalidNumbering(ruleIndex: 0)) {
                try BatchRenameRuleEngine.validate([.number(numbering)], rowCount: 2)
            }
        }
        #expect(throws: BatchRenameRuleError.numberingOverflow(ruleIndex: 0)) {
            try apply([.number(.init(start: Int64.max))], "first", ordinal: 0, count: 2)
        }
        #expect(throws: BatchRenameRuleError.numberingOverflow(ruleIndex: 0)) {
            try BatchRenameRuleEngine.validate([.number(.init(start: 0, step: Int64.max))], rowCount: 3)
        }
        #expect(throws: BatchRenameRuleError.emptySearch(ruleIndex: 1)) {
            try apply([.replace(search: "never", replacement: "x"), .replace(search: "", replacement: "x")], "same")
        }
    }

    @Test("row counts and ordinals are bounded before arithmetic")
    func invalidRows() throws {
        for count in [-1, 0, 1_001, Int.max] {
            #expect(throws: BatchRenameRuleError.invalidRowCount) {
                try BatchRenameRuleEngine.validate([], rowCount: count)
            }
        }
        for ordinal in [-1, 2, Int.max] {
            #expect(throws: BatchRenameRuleError.invalidSortedOrdinal) {
                try apply([], "a", ordinal: ordinal, count: 2)
            }
        }
        #expect(try apply([.number(.init())], "item", ordinal: 999, count: 1_000) == "item_1000")
    }

    @Test("each literal has its own UTF-8 byte budget")
    func literalBudgets() throws {
        let atLimit = String(repeating: "é", count: 512)
        let overLimit = atLimit + "a"
        #expect(try apply([.prepend(atLimit)], "").utf8.count == 1_024)
        let rules: [BatchRenameRule] = [
            .replace(search: overLimit, replacement: ""),
            .replace(search: "unmatched", replacement: overLimit),
            .prepend(overLimit), .append(overLimit),
            .number(.init(separator: overLimit, body: .unified(""))),
            .number(.init(body: .unified(overLimit)))
        ]
        for rule in rules {
            #expect(throws: BatchRenameRuleError.literalTooLong(ruleIndex: 0)) {
                try apply([rule], "")
            }
        }
        try BatchRenameRuleEngine.validate(Array(repeating: .uppercase, count: 32), rowCount: 1)
        #expect(throws: BatchRenameRuleError.tooManyRules) {
            try BatchRenameRuleEngine.validate(Array(repeating: .uppercase, count: 33), rowCount: 1)
        }
    }

    @Test("working bodies reject oversize before a later rule can shrink them")
    func workingBudgets() throws {
        let full = String(repeating: "a", count: 4_096)
        #expect(try apply([], full).utf8.count == 4_096)
        #expect(throws: BatchRenameRuleError.workingBodyTooLong(ruleIndex: nil)) {
            try apply([.replace(search: "a", replacement: "")], full + "a")
        }
        for rule in [BatchRenameRule.prepend("x"), .append("x"), .number(.init()), .replace(search: "a", replacement: "aa")] {
            #expect(throws: BatchRenameRuleError.workingBodyTooLong(ruleIndex: 0)) {
                try apply([rule, .replace(search: "a", replacement: "")], full)
            }
        }
        #expect(try apply([.replace(search: "a", replacement: "")], full).isEmpty)
        #expect(try apply([.append("b")], String(repeating: "a", count: 4_095)).utf8.count == 4_096)
    }

    @Test("Unicode expansion is budgeted before full-string mapping")
    func caseExpansionBudgets() throws {
        #expect(throws: BatchRenameRuleError.workingBodyTooLong(ruleIndex: 0)) {
            try apply([.uppercase], String(repeating: "ΐ", count: 1_000))
        }
        #expect(throws: BatchRenameRuleError.workingBodyTooLong(ruleIndex: 0)) {
            try apply([.lowercase], String(repeating: "İ", count: 1_400))
        }
        let exactUpper = try apply([.uppercase], String(repeating: "ΐ", count: 682) + "aaaa")
        #expect(exactUpper.utf8.count == 4_096)
        #expect(exactUpper.hasSuffix("AAAA"))
        let exactLower = try apply([.lowercase], String(repeating: "İ", count: 1_365) + "A")
        #expect(exactLower.utf8.count == 4_096)
        #expect(exactLower.hasSuffix("a"))
    }
}

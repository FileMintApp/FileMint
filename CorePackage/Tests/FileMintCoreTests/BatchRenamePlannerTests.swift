import FileMintCore
import Foundation
import Testing

@Suite("Batch rename pure planning")
struct BatchRenamePlannerTests {
    // These are naming descriptors and injected observations, not filesystem
    // identities or evidence of P2 authorization, lookup, rename or recovery.
    private func id(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012d", value))!
    }

    private func batch(_ names: [String], kind: RenameItemKind = .file) throws -> BatchRenameBatch {
        try BatchRenameBatch(id: id(10_001), sources: names.enumerated().map {
            BatchRenameSource(id: id($0.offset + 1), originalName: $0.element, kind: kind)
        })
    }

    private func listPreview(_ batch: BatchRenameBatch, text: String, rowIDs: [UUID],
                             revision: UInt64 = 1, order: BatchRenameOrder = .ascending,
                             sensitivity: BatchRenameCaseSensitivity = .insensitive,
                             nativeLimit: Int? = nil) throws -> BatchRenamePreview {
        let list = try BatchRenameNameList(text: text, rowIDs: rowIDs)
        return try BatchRenamePlanner.preview(batch: batch, revision: revision, mode: .nameList(list),
            order: order, caseSensitivity: sensitivity, nativeNameByteLimit: nativeLimit)
    }

    private func observed(_ preview: BatchRenamePreview,
                          _ targets: [(Int, String, BatchRenameTargetState)]) throws -> BatchRenamePreview {
        let snapshot = BatchRenameTargetSnapshot(preview: preview, observations: targets.map {
            BatchRenameTargetObservation(rowID: id($0.0), targetName: $0.1, state: $0.2)
        })
        return try BatchRenamePlanner.checkingTargets(of: preview, using: snapshot)
    }

    @Test("natural sorting has byte-stable ties and descending reverses the complete order")
    func naturalOrdering() throws {
        let input = try batch(["file10.txt", "file2.txt", "file1.txt", "File2.txt"])
        #expect(BatchRenamePlanner.orderedRowIDs(in: input) == [id(3), id(4), id(2), id(1)])
        #expect(BatchRenamePlanner.orderedRowIDs(in: input, order: .descending) == [id(1), id(2), id(4), id(3)])
        let preview = try BatchRenamePlanner.preview(batch: input, revision: 1, mode: .rules([]),
                                                     caseSensitivity: .sensitive)
        #expect(preview.rows.map(\.source.originalName) == ["file1.txt", "File2.txt", "file2.txt", "file10.txt"])
        #expect(preview.rows.map(\.capturedOrdinal) == [2, 3, 1, 0])
        #expect(preview.counts.checking == 4)
    }

    @Test("every rule revision starts with original bodies and numbering uses sorted ordinals")
    func recomputesOriginals() throws {
        let input = try batch(["IMG_10.JPG", "IMG_2.JPG"])
        let first = try BatchRenamePlanner.preview(batch: input, revision: 1,
            mode: .rules([.prepend("first_")]), caseSensitivity: .insensitive)
        #expect(first.rows.map(\.proposedName) == ["first_IMG_2.JPG", "first_IMG_10.JPG"])
        let second = try BatchRenamePlanner.preview(batch: input, revision: 2,
            mode: .rules([.append("_second")]), caseSensitivity: .insensitive)
        #expect(second.rows.map(\.proposedName) == ["IMG_2_second.JPG", "IMG_10_second.JPG"])
        let numbered = try BatchRenamePlanner.preview(batch: input, revision: 3,
            mode: .rules([.number(.init(body: .unified("产品图")))]), caseSensitivity: .insensitive)
        #expect(numbered.rows.map(\.source.id) == [id(2), id(1)])
        #expect(numbered.rows.map(\.proposedName) == ["产品图_001.JPG", "产品图_002.JPG"])
        let descending = try BatchRenamePlanner.preview(batch: input, revision: 4,
            mode: .rules([.number(.init(body: .unified("产品图")))]), order: .descending,
            caseSensitivity: .insensitive)
        #expect(descending.rows.map(\.source.id) == [id(1), id(2)])
        #expect(descending.rows.map(\.proposedName) == ["产品图_001.JPG", "产品图_002.JPG"])
    }

    @Test("name lists normalize CRLF and CR and ignore exactly one final terminator")
    func nameListLineEndings() throws {
        let input = try batch(["a.txt", "b.txt"])
        for text in ["First\r\nSecond\r\n", "First\rSecond\r", "First\nSecond\n", "First\nSecond"] {
            let list = try BatchRenameNameList(text: text, rowIDs: [id(1), id(2)])
            #expect(list.text == text)
            #expect(list.bodies == ["First", "Second"])
            let preview = try BatchRenamePlanner.preview(batch: input, revision: 1,
                mode: .nameList(list), caseSensitivity: .insensitive)
            #expect(preview.rows.map(\.proposedName) == ["First.txt", "Second.txt"])
        }
        #expect(throws: BatchRenamePlanningError.nameListLineCount(expected: 2, actual: 3)) {
            try BatchRenameNameList(text: "First\nSecond\n\n", rowIDs: [id(1), id(2)])
        }
        #expect(throws: BatchRenamePlanningError.nameListLineCount(expected: 2, actual: 1)) {
            try BatchRenameNameList(text: "First", rowIDs: [id(1), id(2)])
        }
    }

    @Test("name lists keep internal blank rows and reject whitespace even for unchanged legacy originals")
    func blankListRows() throws {
        let input = try batch(["a.txt", "b.txt", "c.txt"])
        let list = try BatchRenameNameList(text: "First\n\nThird", rowIDs: [id(1), id(2), id(3)])
        #expect(list.bodies == ["First", "", "Third"])
        let preview = try BatchRenamePlanner.preview(batch: input, revision: 1,
            mode: .nameList(list), caseSensitivity: .insensitive)
        #expect(preview.rows[1].state == .invalid)
        #expect(preview.rows[1].issue == .blankNameListLine)
        #expect(preview.rows[1].proposedName == nil)
        #expect(preview.rows[2].proposedName == "Third.txt")
        #expect(!preview.canFreeze)

        let legacy = try batch([" \t", "b"], kind: .directory)
        let noRules = try BatchRenamePlanner.preview(batch: legacy, revision: 1,
            mode: .rules([]), caseSensitivity: .sensitive)
        #expect(noRules.rows[0].proposedName == " \t")
        let blank = try listPreview(legacy, text: " \t\nb", rowIDs: [id(1), id(2)], sensitivity: .sensitive)
        #expect(blank.rows[0].issue == .blankNameListLine)
        #expect(blank.rows[0].state == .invalid)
        let unicodeBlank = try listPreview(try batch(["a", "b"]), text: "\u{2003}\nb",
                                          rowIDs: [id(1), id(2)])
        #expect(unicodeBlank.rows[0].issue == .blankNameListLine)
    }

    @Test("list size is measured in UTF-8 bytes and invalid bindings are rejected")
    func nameListBounds() throws {
        let exact = String(repeating: "🪴", count: 262_143) + "\nabc"
        #expect(exact.utf8.count == 1_048_576)
        let retained = try BatchRenameNameList(text: exact, rowIDs: [id(1), id(2)])
        #expect(retained.bodies.count == 2)
        #expect(retained.bodies[1] == "abc")
        #expect(throws: BatchRenamePlanningError.nameListTooLarge) {
            try BatchRenameNameList(text: exact + "x", rowIDs: [id(1), id(2)])
        }
        #expect(retained.text.utf8.count == 1_048_576)
        #expect(throws: BatchRenamePlanningError.invalidNameListBinding) {
            try BatchRenameNameList(text: "a\nb", rowIDs: [id(1), id(1)])
        }
        #expect(throws: BatchRenamePlanningError.invalidNameListBinding) {
            try BatchRenameNameList(text: "", rowIDs: [])
        }
        #expect(throws: BatchRenamePlanningError.nameListLineCount(expected: 2, actual: 1_048_576)) {
            try BatchRenameNameList(text: String(repeating: "\n", count: 1_048_576), rowIDs: [id(1), id(2)])
        }
    }

    @Test("sorting populated lists requires explicit reassignment and preserves the old binding on cancel")
    func explicitListReassignment() throws {
        let input = try batch(["a.txt", "b.txt"])
        let original = try BatchRenameNameList(text: "First\nSecond", rowIDs: [id(1), id(2)])
        #expect(throws: BatchRenamePlanningError.nameListOrderNeedsConfirmation) {
            try BatchRenamePlanner.preview(batch: input, revision: 2, mode: .nameList(original),
                order: .descending, caseSensitivity: .insensitive)
        }
        let confirmed = try original.confirmingReassignment(to: [id(2), id(1)])
        let descending = try BatchRenamePlanner.preview(batch: input, revision: 2,
            mode: .nameList(confirmed), order: .descending, caseSensitivity: .insensitive)
        #expect(descending.rows.map(\.source.originalName) == ["b.txt", "a.txt"])
        #expect(descending.rows.map(\.proposedName) == ["First.txt", "Second.txt"])
        #expect(confirmed.text == "First\nSecond")
        #expect(original.rowIDs == [id(1), id(2)])
        let cancelled = try BatchRenamePlanner.preview(batch: input, revision: 1,
            mode: .nameList(original), caseSensitivity: .insensitive)
        #expect(cancelled.rows.map(\.source.originalName) == ["a.txt", "b.txt"])
        #expect(cancelled.rows.map(\.proposedName) == ["First.txt", "Second.txt"])
        #expect(throws: BatchRenamePlanningError.invalidNameListBinding) {
            try original.confirmingReassignment(to: [id(1), id(3)])
        }
    }

    @Test("protected suffix spelling and directory bodies survive planning")
    func protectsOriginalParts() throws {
        let input = try BatchRenameBatch(id: id(10_001), sources: [
            .init(id: id(1), originalName: ".env.local", kind: .file),
            .init(id: id(2), originalName: "archive.TAR.GZ", kind: .file),
            .init(id: id(3), originalName: "Photos", kind: .directory)
        ])
        // Foundation's fixed en_US_POSIX comparison puts Photos before archive;
        // bind the list to that explicit order, not a generic alphabetic guess.
        #expect(BatchRenamePlanner.orderedRowIDs(in: input) == [id(1), id(3), id(2)])
        let preview = try listPreview(input, text: "settings\nPhotos.2026\nnew.txt", rowIDs: [id(1), id(3), id(2)])
        #expect(preview.rows.map(\.proposedName) == [".settings.local", "Photos.2026", "new.txt.TAR.GZ"])
        #expect(preview.rows.map(\.source.originalName) == [".env.local", "Photos", "archive.TAR.GZ"])
        let suffixlessInput = try batch([".env", "README"])
        #expect(BatchRenamePlanner.orderedRowIDs(in: suffixlessInput) == [id(1), id(2)])
        let suffixless = try listPreview(suffixlessInput, text: "env.local\nREADME.txt",
                                        rowIDs: [id(1), id(2)])
        #expect(suffixless.rows.map(\.issue) == [.name(.extensionChange), .name(.extensionChange)])
        #expect(suffixless.counts.invalid == 2)
    }

    @Test("invalid outputs are row errors while unchanged originals retain their exact spelling")
    func outputValidationAndLegacyExemption() throws {
        let input = try batch(["a.txt", "b.txt"])
        let whitespace = try listPreview(input, text: " new\ngood", rowIDs: [id(1), id(2)])
        #expect(whitespace.rows[0].issue == .name(.leadingOrTrailingWhitespace))
        #expect(whitespace.rows[1].proposedName == "good.txt")
        let limited = try listPreview(input, text: "long\nb", rowIDs: [id(1), id(2)], nativeLimit: 6)
        #expect(limited.rows[0].issue == .name(.outputNameTooLong(limit: 6)))
        #expect(limited.rows[1].proposedName == "b.txt")
        #expect(throws: BatchRenamePlanningError.previewNotReady) { try BatchRenamePlanner.freeze(limited) }

        let oldName = String(repeating: "a", count: 300) + " "
        let legacy = try batch([oldName, "b"], kind: .directory)
        let preview = try BatchRenamePlanner.preview(batch: legacy, revision: 1,
            mode: .rules([]), caseSensitivity: .sensitive, nativeNameByteLimit: 1)
        #expect(Data(try #require(preview.rows[0].proposedName).utf8) == Data(oldName.utf8))
        #expect(preview.rows[0].issue == nil)
        #expect(!preview.rows[0].changesName)
    }

    @Test("global parameter errors throw and row expansion errors remain attached to their row")
    func ruleFailures() throws {
        #expect(throws: BatchRenameRuleError.emptySearch(ruleIndex: 0)) {
            try BatchRenamePlanner.preview(batch: batch(["a.txt", "b.txt"]), revision: 1,
                mode: .rules([.replace(search: "", replacement: "x")]), caseSensitivity: .sensitive)
        }
        let input = try batch([String(repeating: "a", count: 1_020) + ".txt", "z.txt"])
        let preview = try BatchRenamePlanner.preview(batch: input, revision: 1,
            mode: .rules([.replace(search: "a", replacement: "bbbbb")]), caseSensitivity: .sensitive)
        #expect(preview.rows[0].issue == .rule(.workingBodyTooLong(ruleIndex: 0)))
        #expect(preview.rows[0].state == .invalid)
        #expect(preview.rows[1].proposedName == "z.txt")
        #expect(preview.counts.invalid == 1)
        #expect(!preview.canFreeze)
    }

    @Test("all final names reserve the namespace including unchanged rows")
    func duplicateFinalNames() throws {
        let input = try batch(["a.txt", "b.txt"])
        let collision = try listPreview(input, text: "a\na", rowIDs: [id(1), id(2)])
        #expect(collision.rows.map(\.issue) == [.duplicateTarget, .duplicateTarget])
        #expect(collision.counts.conflicts == 2)
        #expect(collision.proposedChangeCount == 1)
        #expect(!collision.rows[0].changesName)
        let checked = try observed(collision, [(1, "a.txt", .occupiedBySource(id(1))),
                                               (2, "a.txt", .occupiedBySource(id(1)))])
        #expect(checked.counts.conflicts == 2)
        #expect(throws: BatchRenamePlanningError.previewNotReady) { try BatchRenamePlanner.freeze(checked) }

        let insensitive = try listPreview(input, text: "Name\nname", rowIDs: [id(1), id(2)])
        #expect(insensitive.counts.conflicts == 2)
        let sensitive = try listPreview(input, text: "Name\nname", rowIDs: [id(1), id(2)], sensitivity: .sensitive)
        #expect(sensitive.counts.conflicts == 0)
        #expect(sensitive.counts.checking == 2)
        let canonical = try listPreview(input, text: "é\ne\u{301}", rowIDs: [id(1), id(2)], sensitivity: .sensitive)
        #expect(canonical.counts.conflicts == 2)
    }

    @Test("case-only changes can freeze as one changed row in a two-item batch")
    func caseOnlyAndOneChange() throws {
        let preview = try listPreview(try batch(["a.txt", "b.txt"]), text: "A\nb", rowIDs: [id(1), id(2)])
        let ready = try observed(preview, [(1, "A.txt", .occupiedBySource(id(1))),
                                           (2, "b.txt", .occupiedBySource(id(2)))])
        #expect(ready.rows.map(\.state) == [.changed, .unchanged])
        #expect(ready.rows.map(\.dependencyID) == [nil, nil])
        #expect(ready.counts.changed == 1 && ready.counts.unchanged == 1)
        #expect(ready.canFreeze)
        let plan = try BatchRenamePlanner.freeze(ready)
        #expect(plan.changedCount == 1 && plan.unchangedCount == 1)
        #expect(plan.rows.map(\.proposedName) == ["A.txt", "b.txt"])
    }

    @Test("swap and cycle targets retain dependencies on changing captured sources")
    func swapAndCycleDependencies() throws {
        let swap = try listPreview(try batch(["a.txt", "b.txt"]), text: "b\na", rowIDs: [id(1), id(2)])
        let readySwap = try observed(swap, [(1, "b.txt", .occupiedBySource(id(2))),
                                            (2, "a.txt", .occupiedBySource(id(1)))])
        #expect(readySwap.rows.map(\.dependencyID) == [id(2), id(1)])
        #expect(try BatchRenamePlanner.freeze(readySwap).changedCount == 2)
        let cycle = try listPreview(try batch(["a.txt", "b.txt", "c.txt"]), text: "b\nc\na",
                                    rowIDs: [id(1), id(2), id(3)])
        let readyCycle = try observed(cycle, [(1, "b.txt", .occupiedBySource(id(2))),
                                              (2, "c.txt", .occupiedBySource(id(3))),
                                              (3, "a.txt", .occupiedBySource(id(1)))])
        #expect(readyCycle.rows.map(\.dependencyID) == [id(2), id(3), id(1)])
        #expect(try BatchRenamePlanner.freeze(readyCycle).changedCount == 3)
    }

    @Test("external occupants and failed checks are never treated as absent")
    func failedOrOccupiedTargets() throws {
        let preview = try listPreview(try batch(["a.txt", "b.txt"]), text: "x\ny", rowIDs: [id(1), id(2)])
        let conflict = try observed(preview, [(1, "x.txt", .absent), (2, "y.txt", .occupiedExternally)])
        #expect(conflict.rows.map(\.state) == [.changed, .conflict])
        #expect(conflict.rows[1].issue == .occupiedTarget)
        #expect(conflict.counts.changed == 1 && conflict.counts.conflicts == 1)
        let failure = try observed(preview, [(1, "x.txt", .absent), (2, "y.txt", .failed)])
        #expect(failure.rows.map(\.state) == [.changed, .invalid])
        #expect(failure.rows[1].issue == .targetCheckFailed)
        #expect(throws: BatchRenamePlanningError.previewNotReady) { try BatchRenamePlanner.freeze(conflict) }
        #expect(throws: BatchRenamePlanningError.previewNotReady) { try BatchRenamePlanner.freeze(failure) }
    }

    @Test("missing observations and unknown case sensitivity prevent freezing")
    func incompleteChecks() throws {
        let input = try batch(["a.txt", "b.txt"])
        let preview = try listPreview(input, text: "x\ny", rowIDs: [id(1), id(2)])
        let partial = try observed(preview, [(1, "x.txt", .absent)])
        #expect(partial.rows.map(\.state) == [.changed, .checking])
        #expect(!partial.canFreeze)
        #expect(throws: BatchRenamePlanningError.previewNotReady) { try BatchRenamePlanner.freeze(partial) }
        let unknown = try listPreview(input, text: "x\ny", rowIDs: [id(1), id(2)], sensitivity: .unknown)
        let observedUnknown = try observed(unknown, [(1, "x.txt", .absent), (2, "y.txt", .absent)])
        #expect(observedUnknown.counts.checking == 2)
        #expect(!observedUnknown.canFreeze)
        #expect(throws: BatchRenamePlanningError.unknownCaseSensitivity) {
            try BatchRenamePlanner.freeze(observedUnknown)
        }
    }

    @Test("fresh target snapshots revoke prior successful checks instead of accumulating")
    func newerSnapshotRevokesReadiness() throws {
        let preview = try listPreview(try batch(["a.txt", "b.txt"]), text: "x\ny", rowIDs: [id(1), id(2)])
        let ready = try observed(preview, [(1, "x.txt", .absent), (2, "y.txt", .absent)])
        #expect(ready.canFreeze)
        let pending = try observed(ready, [(1, "x.txt", .pending)])
        #expect(pending.counts.checking == 2)
        #expect(!pending.canFreeze)
        let failed = try observed(ready, [(2, "y.txt", .failed)])
        #expect(failed.rows.map(\.state) == [.checking, .invalid])
        #expect(failed.rows[1].issue == .targetCheckFailed)
    }

    @Test("an unchanged row needs its original entry and a zero-change plan cannot freeze")
    func zeroChangesAndMissingOriginal() throws {
        let preview = try BatchRenamePlanner.preview(batch: batch(["a.txt", "b.txt"]), revision: 1,
            mode: .rules([]), caseSensitivity: .insensitive)
        let missing = try observed(preview, [(1, "a.txt", .absent), (2, "b.txt", .occupiedBySource(id(2)))])
        #expect(missing.rows[0].issue == .originalTargetMissing)
        #expect(missing.counts.invalid == 1)
        let ready = try observed(preview, [(1, "a.txt", .occupiedBySource(id(1))),
                                           (2, "b.txt", .occupiedBySource(id(2)))])
        #expect(ready.counts.unchanged == 2 && ready.counts.changed == 0)
        #expect(ready.proposedChangeCount == 0)
        #expect(!ready.canFreeze)
        #expect(throws: BatchRenamePlanningError.noChanges) { try BatchRenamePlanner.freeze(ready) }
    }

    @Test("snapshots reject stale revisions and different parameters at the same revision")
    func staleReferences() throws {
        let input = try batch(["a.txt", "b.txt"])
        let first = try listPreview(input, text: "x\ny", rowIDs: [id(1), id(2)])
        let snapshot = BatchRenameTargetSnapshot(preview: first, observations: [
            .init(rowID: id(1), targetName: "x.txt", state: .absent),
            .init(rowID: id(2), targetName: "y.txt", state: .absent)
        ])
        let later = try listPreview(input, text: "x\ny", rowIDs: [id(1), id(2)], revision: 2)
        let changedText = try listPreview(input, text: "z\ny", rowIDs: [id(1), id(2)])
        let changedCase = try listPreview(input, text: "x\ny", rowIDs: [id(1), id(2)], sensitivity: .sensitive)
        let changedLimit = try listPreview(input, text: "x\ny", rowIDs: [id(1), id(2)], nativeLimit: 200)
        let changedOrder = try listPreview(input, text: "x\ny", rowIDs: [id(2), id(1)], order: .descending)
        let changedMode = try BatchRenamePlanner.preview(batch: input, revision: 1,
            mode: .rules([.prepend("x")]), caseSensitivity: .insensitive)
        let replacementBatch = try BatchRenameBatch(id: id(10_002), sources: input.sources)
        let changedBatch = try listPreview(replacementBatch, text: "x\ny", rowIDs: [id(1), id(2)])
        for current in [later, changedText, changedCase, changedLimit, changedOrder, changedMode, changedBatch] {
            #expect(throws: BatchRenamePlanningError.staleTargetSnapshot) {
                try BatchRenamePlanner.checkingTargets(of: current, using: snapshot)
            }
        }
    }

    @Test("canonically equivalent literal parameters are still different byte-exact references")
    func canonicalLiteralReferences() throws {
        let input = try batch(["a.txt", "b.txt"])
        let composed = try BatchRenamePlanner.preview(batch: input, revision: 1,
            mode: .rules([.prepend("é")]), caseSensitivity: .insensitive)
        let decomposed = try BatchRenamePlanner.preview(batch: input, revision: 1,
            mode: .rules([.prepend("e\u{301}")]), caseSensitivity: .insensitive)
        #expect(Data(try #require(composed.rows[0].proposedName).utf8) == Data("éa.txt".utf8))
        #expect(Data(try #require(decomposed.rows[0].proposedName).utf8) == Data("e\u{301}a.txt".utf8))
        #expect(composed.reference != decomposed.reference)
        let snapshot = BatchRenameTargetSnapshot(preview: composed, observations: [
            .init(rowID: id(1), targetName: "éa.txt", state: .absent),
            .init(rowID: id(2), targetName: "éb.txt", state: .absent)
        ])
        #expect(throws: BatchRenamePlanningError.staleTargetSnapshot) {
            try BatchRenamePlanner.checkingTargets(of: decomposed, using: snapshot)
        }
        let composedList = try listPreview(input, text: "é\ny", rowIDs: [id(1), id(2)])
        let decomposedList = try listPreview(input, text: "e\u{301}\ny", rowIDs: [id(1), id(2)])
        #expect(composedList.reference != decomposedList.reference)
    }

    @Test("target observations must use known rows and exact proposed target bytes")
    func rejectsMalformedObservations() throws {
        let preview = try listPreview(try batch(["a.txt", "b.txt"]), text: "é\ny", rowIDs: [id(1), id(2)])
        let invalid: [[BatchRenameTargetObservation]] = [
            [.init(rowID: id(3), targetName: "é.txt", state: .absent)],
            [.init(rowID: id(1), targetName: "e\u{301}.txt", state: .absent)],
            [.init(rowID: id(1), targetName: "é.txt", state: .absent),
             .init(rowID: id(1), targetName: "é.txt", state: .failed)],
            [.init(rowID: id(1), targetName: "é.txt", state: .occupiedBySource(id(99)))],
            [.init(rowID: id(1), targetName: "é.txt", state: .occupiedBySource(id(2)))]
        ]
        for observations in invalid {
            #expect(throws: BatchRenamePlanningError.invalidTargetObservation) {
                try BatchRenamePlanner.checkingTargets(of: preview,
                    using: BatchRenameTargetSnapshot(preview: preview, observations: observations))
            }
        }
    }

    @Test("frozen proposals retain source, rule and observation values after caller input changes")
    func immutableFrozenProposal() throws {
        var sources = [BatchRenameSource(id: id(1), originalName: "a.txt", kind: .file),
                       BatchRenameSource(id: id(2), originalName: "b.txt", kind: .file)]
        let input = try BatchRenameBatch(id: id(10_001), sources: sources)
        var rules: [BatchRenameRule] = [.prepend("new_")]
        let preview = try BatchRenamePlanner.preview(batch: input, revision: 7,
            mode: .rules(rules), caseSensitivity: .insensitive)
        var observations: [BatchRenameTargetObservation] = [
            .init(rowID: id(1), targetName: "new_a.txt", state: .absent),
            .init(rowID: id(2), targetName: "new_b.txt", state: .absent)
        ]
        let snapshot = BatchRenameTargetSnapshot(preview: preview, observations: observations)
        let plan = try BatchRenamePlanner.freeze(BatchRenamePlanner.checkingTargets(of: preview, using: snapshot))
        sources[0] = .init(id: id(1), originalName: "replacement.txt", kind: .directory)
        rules[0] = .append("_later")
        observations[0] = .init(rowID: id(1), targetName: "new_a.txt", state: .occupiedExternally)
        let later = try BatchRenamePlanner.preview(batch: input, revision: 8,
            mode: .rules(rules), caseSensitivity: .insensitive)
        #expect(later.rows.map(\.proposedName) == ["a_later.txt", "b_later.txt"])
        #expect(plan.reference.revision == 7)
        #expect(plan.reference.mode == .rules([.prepend("new_")]))
        #expect(plan.rows.map(\.source.originalName) == ["a.txt", "b.txt"])
        #expect(plan.rows.map(\.proposedName) == ["new_a.txt", "new_b.txt"])
        #expect(plan.rows.map(\.state) == [.changed, .changed])
        #expect(plan.changedCount == 2)
        #expect(snapshot.observations[0].state == .absent)
        #expect(sources[0].originalName == "replacement.txt")
        #expect(observations[0].state == .occupiedExternally)
    }

    @Test("batch capture requires two through one thousand distinct rows and safe originals")
    func batchBoundsAndOriginals() throws {
        for count in [0, 1, 1_001] {
            #expect(throws: BatchRenamePlanningError.invalidSelectionCount) {
                try batch((0..<count).map { "file\($0).txt" })
            }
        }
        let maximum = try batch((1...1_000).map { "file\($0).txt" })
        #expect(maximum.sources.count == 1_000)
        let preview = try BatchRenamePlanner.preview(batch: maximum, revision: 1,
            mode: .rules([.number(.init(body: .unified("item")))]), caseSensitivity: .insensitive)
        #expect(preview.rows.count == 1_000)
        #expect(preview.rows.first?.proposedName == "item_001.txt")
        #expect(preview.rows.last?.proposedName == "item_1000.txt")
        #expect(preview.counts.checking == 1_000)
        #expect(throws: BatchRenamePlanningError.duplicateSourceID) {
            try BatchRenameBatch(id: id(10_001), sources: [
                .init(id: id(1), originalName: "a.txt", kind: .file),
                .init(id: id(1), originalName: "b.txt", kind: .file)
            ])
        }
        #expect(throws: BatchRenamePlanningError.duplicateOriginalName) { try batch(["a.txt", "a.txt"]) }
        #expect(throws: BatchRenamePlanningError.invalidOriginalName(rowID: id(1), reason: .invalidComponent)) {
            try batch(["bad/name", "b"])
        }
        #expect(throws: BatchRenamePlanningError.invalidOriginalName(rowID: id(1), reason: .originalNameTooLong)) {
            try batch([String(repeating: "a", count: 1_025), "b"])
        }
        let exact = try batch([String(repeating: "a", count: 1_024), "b"])
        #expect(exact.sources[0].originalName.utf8.count == 1_024)
    }
}

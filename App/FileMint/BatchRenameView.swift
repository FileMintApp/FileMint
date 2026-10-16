import AppKit
import FileMintCore
import SwiftUI

struct BatchRenameView: View {
    @ObservedObject var model: BatchRenameController
    @FocusState private var focusedField: RuleField?

    private struct RuleField: Hashable {
        let id: UUID
        let label: BatchRenameText
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(FileMintStyle.line)
            HSplitView {
                if model.isEditing {
                    inspector.frame(minWidth: 292, idealWidth: 316, maxWidth: 370)
                }
                preview.frame(minWidth: 480)
            }
            Divider().overlay(FileMintStyle.line)
            footer
        }
        .background(FileMintStyle.background)
        .tint(FileMintStyle.accent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand { model.requestClose() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: model.isUndo ? "arrow.uturn.backward" : "pencil.line")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(FileMintStyle.accent)
                .frame(width: 44, height: 44)
                .background(FileMintStyle.selection, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.text(model.isUndo ? .undoLast : .title))
                    .font(.system(size: 21, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(model.text(.workspaceHint)).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            if !model.rows.isEmpty {
                Text(String(format: model.text(.selectedCount), model.rows.count))
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(FileMintStyle.soft, in: Capsule())
            }
        }
        .padding(.horizontal, 24).padding(.top, 15).padding(.bottom, 20)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 11) {
                sectionTitle(.namingMethod)
                Picker(model.text(.namingMethod), selection: Binding(get: { model.mode }, set: { model.chooseMode($0) })) {
                    Text(model.text(.rules)).tag(BatchRenameController.Mode.rules)
                    Text(model.text(.nameList)).tag(BatchRenameController.Mode.nameList)
                }
                .pickerStyle(.segmented).labelsHidden()
                .accessibilityIdentifier("batchRenameMode")
                Text(model.text(model.mode == .rules ? .rulesHint : .listModeHint))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            Divider().overlay(FileMintStyle.line)
            if model.mode == .rules { ruleInspector } else { listInspector }
        }
        .background(FileMintStyle.soft)
    }

    private var ruleInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if model.rules.isEmpty {
                            ruleStarters
                        } else {
                            HStack {
                                sectionTitle(.ruleSequence)
                                Spacer()
                                Text("\(model.rules.count)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                            ForEach(Array(model.rules.enumerated()), id: \.element.id) { index, rule in
                                ruleCard(rule, index: index).id(rule.id)
                            }
                        }
                    }.padding(18)
                }
                .onChange(of: focusedField) { field in
                    if let field { proxy.scrollTo(field.id, anchor: .center) }
                }
            }
            if !model.rules.isEmpty {
                ruleMenu(label: .addRule)
                    .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 16)
            }
        }
    }

    private var ruleStarters: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.text(.startWithRule)).font(.system(size: 15, weight: .medium))
                .padding(.top, 6)
            VStack(spacing: 10) {
                starter(.replace, symbol: "text.magnifyingglass", hint: .replaceHint)
                starter(.prepend, symbol: "text.badge.plus", hint: .prependHint)
                starter(.numbering, symbol: "number", hint: .numberingHint)
            }
            ruleMenu(label: .moreRules)
        }
    }

    private func starter(_ kind: BatchRenameRuleDraft.Kind, symbol: String, hint: BatchRenameText) -> some View {
        Button { addRule(kind) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(FileMintStyle.accent)
                    .frame(width: 24).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.text(kind.label)).font(.system(size: 13, weight: .medium))
                    Text(model.text(hint)).font(.system(size: 10)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus").font(.system(size: 11)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }.frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        }
        .buttonStyle(MintButtonStyle())
        .accessibilityIdentifier("batchRenameStart.\(kind.rawValue)")
    }

    private func ruleMenu(label: BatchRenameText) -> some View {
        Menu {
            ForEach(BatchRenameRuleDraft.Kind.allCases, id: \.rawValue) { kind in
                Button(model.text(kind.label)) { addRule(kind) }
            }
        } label: {
            Label(model.text(label), systemImage: "plus")
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(FileMintStyle.line, lineWidth: 1))
        .disabled(model.rules.count >= BatchRenameRuleEngine.maximumRuleCount)
        .accessibilityIdentifier("batchRenameAddRule")
    }

    private func addRule(_ kind: BatchRenameRuleDraft.Kind) {
        guard model.rules.count < BatchRenameRuleEngine.maximumRuleCount else { return }
        model.addRule(kind)
        guard let id = model.rules.last?.id else { return }
        let key: BatchRenameText
        switch kind {
        case .replace, .delete: key = .search
        case .prepend, .append: key = .text
        case .numbering: key = .start
        case .uppercase, .lowercase: return
        }
        Task { @MainActor in
            await Task.yield()
            focusedField = RuleField(id: id, label: key)
        }
    }

    private func ruleCard(_ rule: BatchRenameRuleDraft, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(FileMintStyle.accent)
                    .frame(width: 25, height: 25)
                    .background(FileMintStyle.selection, in: RoundedRectangle(cornerRadius: 6))
                Text(model.text(rule.kind.label)).font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                Menu {
                    Button(model.text(.moveUp)) { model.moveRule(rule.id, by: -1) }.disabled(index == 0)
                    Button(model.text(.moveDown)) { model.moveRule(rule.id, by: 1) }
                        .disabled(index == model.rules.count - 1)
                    Divider()
                    Button(model.text(.remove)) { model.removeRule(rule.id) }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium))
                        .frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help(model.text(.ruleActions))
                .accessibilityLabel("\(model.text(rule.kind.label)): \(model.text(.ruleActions))")
            }
            switch rule.kind {
            case .replace, .delete:
                field(.search, rule: rule, path: \.text)
                if rule.kind == .replace { field(.replacement, rule: rule, path: \.replacement) }
            case .prepend, .append:
                field(.text, rule: rule, path: \.text)
            case .numbering:
                numbering(rule)
            case .uppercase, .lowercase:
                Text(model.text(rule.kind == .uppercase ? .uppercaseHint : .lowercaseHint))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
    }

    private func numbering(_ rule: BatchRenameRuleDraft) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel(.nameBody)
                Picker(model.text(.nameBody), selection: binding(rule, \.unified)) {
                    Text(model.text(.currentBody)).tag(false)
                    Text(model.text(.unifiedBody)).tag(true)
                }.labelsHidden().tint(.primary).frame(maxWidth: .infinity, alignment: .leading)
            }
            if rule.unified { field(.unifiedBody, rule: rule, path: \.unifiedText) }
            HStack(alignment: .top, spacing: 10) {
                field(.start, rule: rule, path: \.start)
                field(.step, rule: rule, path: \.step)
                field(.width, rule: rule, path: \.width)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel(.position)
                    Picker(model.text(.position), selection: binding(rule, \.before)) {
                        Text(model.text(.after)).tag(false)
                        Text(model.text(.before)).tag(true)
                    }.labelsHidden().tint(.primary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                field(.separator, rule: rule, path: \.separator).frame(width: 68)
            }
        }
    }

    private func sectionTitle(_ key: BatchRenameText) -> some View {
        Text(model.text(key)).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func fieldLabel(_ key: BatchRenameText) -> some View {
        Text(model.text(key)).font(.system(size: 11)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func field(_ key: BatchRenameText, rule: BatchRenameRuleDraft,
                       path: WritableKeyPath<BatchRenameRuleDraft, String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(key)
            TextField("", text: binding(rule, path)).textFieldStyle(.roundedBorder).controlSize(.large)
                .font(.system(size: 12))
                .focused($focusedField, equals: RuleField(id: rule.id, label: key))
                .accessibilityLabel(model.text(key))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func binding<Value>(_ rule: BatchRenameRuleDraft,
                                _ path: WritableKeyPath<BatchRenameRuleDraft, Value>) -> Binding<Value> {
        Binding(get: { (model.rules.first { $0.id == rule.id } ?? rule)[keyPath: path] }, set: { value in
            guard var updated = model.rules.first(where: { $0.id == rule.id }) else { return }
            updated[keyPath: path] = value
            model.updateRule(updated)
        })
    }

    private var listInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: model.text(.listRequired), model.rows.count))
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Button { model.pasteList() } label: { Label(model.text(.paste), systemImage: "doc.on.clipboard") }
                    .controlSize(.small).accessibilityIdentifier("batchRenamePaste")
            }
            BatchRenameListEditor(text: Binding(get: { model.listText }, set: { model.setListText($0) }),
                                  label: model.text(.nameList), rejected: { model.rejectOversizedList() })
                .frame(minHeight: 100, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(FileMintStyle.line, lineWidth: 1))
            Text(model.text(.listHint)).font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(18)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.text(model.result == nil && !model.isRecovery ? .preview : .results))
                        .font(.system(size: 15, weight: .semibold)).accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 0)
                if model.isEditing {
                    Picker(model.text(.order), selection: Binding(get: { model.order }, set: { model.chooseOrder($0) })) {
                        Text(model.text(.ascending)).tag(BatchRenameOrder.ascending)
                        Text(model.text(.descending)).tag(BatchRenameOrder.descending)
                    }
                    .labelsHidden().pickerStyle(.menu).controlSize(.small).tint(.primary)
                    .fixedSize().accessibilityIdentifier("batchRenameOrder")
                }
            }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
            previewNotice.padding(.horizontal, 20).padding(.bottom, 14)
            nameTable
            if let row = model.selectedRow {
                rowDetails(row)
            } else if !model.rows.isEmpty {
                Label(model.text(.selectHint), systemImage: "cursorarrow")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .padding(.horizontal, 20).padding(.vertical, 13)
            }
        }
        .background(FileMintStyle.surface)
    }

    private var nameTable: some View {
        Table(model.rows, selection: $model.selectedRowID) {
            TableColumn(model.text(.original)) { row in
                nameCell(row.original, prefix: model.text(.original))
                    .foregroundStyle(.secondary).padding(.vertical, 8)
            }.width(min: 145, ideal: 235)
            TableColumn(model.text(.proposed)) { row in
                HStack(spacing: 9) {
                    Image(systemName: "arrow.right").font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary).accessibilityHidden(true)
                    nameCell(row.target, prefix: model.text(.proposed))
                        .fontWeight(row.changesName && !model.isChecking ? .medium : .regular)
                }.padding(.vertical, 8)
            }.width(min: 155, ideal: 250)
            TableColumn(model.text(.state)) { row in
                Label(model.isChecking ? model.text(.checking) : row.state,
                      systemImage: model.isChecking ? "clock" : row.isError ? "exclamationmark.triangle" : row.changesName ? "checkmark.circle" : "minus.circle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(model.isChecking ? Color.secondary : row.isError ? Color.red : row.changesName ? FileMintStyle.accent : Color.secondary)
                    .help(row.issue ?? row.state)
                    .accessibilityLabel([model.isChecking ? model.text(.checking) : row.state, row.issue].compactMap { $0 }.joined(separator: ". "))
            }.width(min: 100, ideal: 125)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .accessibilityIdentifier("batchRenamePreview")
    }

    private var noticeMessage: String {
        if model.isAwaitingReassignment { return model.text(.reassignMessage) }
        if model.isChecking { return model.text(.checkingInstruction) }
        if model.isRunning { return model.text(model.isStopping ? .stoppingInstruction : .running) }
        if let message = model.message, message != model.statusTitle, message != model.text(.noChanges) {
            return message
        }
        if model.hasRowErrors {
            let issue = model.rows.first(where: \.isError)?.issue
            return [issue, model.text(.reviewInstruction)].compactMap { $0 }.joined(separator: "\n")
        }
        if model.isUndo && model.result == nil { return model.text(.undoHint) }
        if model.isEditing {
            if model.mode == .rules && model.rules.isEmpty { return model.text(.startInstruction) }
            return model.text(model.canSubmit ? .readyInstruction : .noChangesInstruction)
        }
        return model.text(.resultHint)
    }

    private var previewNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            if model.isChecking || model.isRunning { ProgressView().controlSize(.small).padding(.top, 3) }
            else {
                Image(systemName: statusSymbol).font(.system(size: 23, weight: .medium))
                    .foregroundStyle(statusColor).padding(.top, 1).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 12) {
                    Text(model.statusTitle).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("batchRenameStatus")
                    Spacer(minLength: 0)
                    if model.hasRowErrors {
                        Button(model.text(.firstIssue)) { model.selectFirstIssue() }
                            .buttonStyle(MintButtonStyle()).accessibilityIdentifier("batchRenameFirstIssue")
                    }
                }
                if !model.rows.isEmpty {
                    Text(model.countText).font(.system(size: 11, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("batchRenameCounts")
                }
                Text(noticeMessage).font(.system(size: 12)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("batchRenameMessage")
                if model.isEditing {
                    Label(model.text(.protectedNames), systemImage: "lock.fill")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(statusColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(statusColor.opacity(needsAttention ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(statusColor.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("batchRenameStatusNotice")
    }

    private func rowDetails(_ row: BatchRenameDisplayRow) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(FileMintStyle.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle(.details)
                    detailName(.original, value: row.original)
                    detailName(.proposed, value: row.target)
                    if let issue = row.issue {
                        Label(issue, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                    if let location = row.location {
                        HStack(alignment: .top) {
                            Text("\(model.text(.location)): \(location.path)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([location])
                            } label: { Image(systemName: "folder") }
                            .help(model.text(.location)).accessibilityLabel(model.text(.location))
                        }
                    }
                }
                .font(.system(size: 12)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 14)
            }.frame(height: 120)
        }
        .background(FileMintStyle.background)
        .accessibilityIdentifier("batchRenameDetails")
    }

    private func detailName(_ label: BatchRenameText, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(model.text(label)).foregroundStyle(.secondary).frame(width: 82, alignment: .leading)
            Text(value).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nameCell(_ name: String, prefix: String) -> some View {
        Text(name).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
            .help(name).accessibilityLabel("\(prefix): \(name)")
    }

    private var needsAttention: Bool {
        model.hasRowErrors || model.isRecovery || model.canRestore || model.canExport || model.requiresFinalization
            || (!model.isEditing && !model.isRunning && model.result == nil && model.message != nil)
    }
    private var statusColor: Color { needsAttention ? .orange : model.canSubmit || model.result != nil ? FileMintStyle.accent : .secondary }
    private var statusSymbol: String {
        if needsAttention { return "exclamationmark.triangle" }
        if model.canSubmit || model.result != nil { return "checkmark.circle" }
        return "slider.horizontal.3"
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.canUndo || model.canRestore || model.requiresFinalization || model.canExport {
                recoveryActions
            }
            HStack(spacing: 18) {
                Spacer(minLength: 0)
                if model.isRunning {
                    Button(model.text(.stop)) { model.requestStop() }
                        .buttonStyle(MintButtonStyle()).disabled(model.isStopping)
                } else {
                    Button(model.text(model.isEditing ? .cancel : .close)) { model.requestClose() }
                        .buttonStyle(MintButtonStyle())
                    if model.isEditing || model.isUndo && model.result == nil {
                        Button { model.submit() } label: {
                            HStack(spacing: 12) {
                                Text(model.submitTitle)
                                Text("⌘↩").font(.system(size: 11)).opacity(0.65).accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(MintButtonStyle(primary: true))
                        .disabled(!model.canSubmit)
                        .keyboardShortcut(.return, modifiers: .command)
                        .accessibilityLabel(model.submitTitle)
                        .accessibilityIdentifier("batchRenameSubmit")
                    }
                }
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 16)
    }

    private var recoveryActions: some View {
        HStack(spacing: 12) {
            if model.canUndo {
                Button(model.text(.undoLast)) { model.chooseResultAction(.undo) }
            }
            if model.canRestore {
                Button(model.text(model.requiresCommittedCleanup ? .finishCommitted : .restore)) {
                    model.chooseResultAction(.restore)
                }
            }
            if model.requiresFinalization {
                Button(model.text(.finishRetirement)) { model.chooseResultAction(.finishRetirement) }
            }
            if model.canExport {
                Menu {
                    Button(model.text(.exportAndUnblock)) { model.chooseResultAction(.exportAndUnblock) }
                } label: { Image(systemName: "ellipsis.circle") }
                .help(model.text(.exportAndUnblock)).accessibilityLabel(model.text(.exportAndUnblock))
            }
        }.controlSize(.small)
    }
}

/// A plain NSTextView rejects oversized edits before changing the draft, and
/// disables smart substitutions so name-list bytes retain their stated meaning.
private struct BatchRenameListEditor: NSViewRepresentable {
    @Binding var text: String
    let label: String
    let rejected: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        let editor = RenameListTextView(frame: NSRect(x: 0, y: 0, width: 280, height: 240))
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.allowsUndo = true
        editor.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        editor.textContainerInset = NSSize(width: 12, height: 12)
        editor.textColor = .labelColor
        editor.insertionPointColor = FileMintStyle.accentNS
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        scroll.documentView = editor
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? NSTextView else { return }
        if !editor.string.utf8.elementsEqual(text.utf8) { editor.string = text }
        editor.setAccessibilityLabel(label)
    }
    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BatchRenameListEditor
        init(_ parent: BatchRenameListEditor) { self.parent = parent }
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange,
                      replacementString: String?) -> Bool {
            guard let replacementString, let range = Range(affectedCharRange, in: textView.string) else { return true }
            let byteCount = textView.string.utf8.count - textView.string[range].utf8.count + replacementString.utf8.count
            guard byteCount <= BatchRenameNameList.maximumBytes else { parent.rejected(); return false }
            return true
        }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}

private final class RenameListTextView: NSTextView {
    override func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        insertText(text, replacementRange: selectedRange())
    }
}

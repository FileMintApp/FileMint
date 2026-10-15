import AppKit
import FileMintCore
import SwiftUI

struct BatchRenameView: View {
    @ObservedObject var model: BatchRenameController

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                if model.isEditing {
                    inspector.frame(minWidth: 280, idealWidth: 320, maxWidth: 370)
                }
                preview.frame(minWidth: 450)
            }
            Divider()
            footer.padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand { model.requestClose() }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(model.text(.title), selection: Binding(get: { model.mode }, set: model.chooseMode)) {
                Text(model.text(.rules)).tag(BatchRenameController.Mode.rules)
                Text(model.text(.nameList)).tag(BatchRenameController.Mode.nameList)
            }
            .pickerStyle(.segmented)
            Picker(model.text(.order), selection: Binding(get: { model.order }, set: model.chooseOrder)) {
                Text(model.text(.ascending)).tag(BatchRenameOrder.ascending)
                Text(model.text(.descending)).tag(BatchRenameOrder.descending)
            }
            if model.mode == .rules {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(model.rules.enumerated()), id: \.element.id) { index, rule in
                            ruleCard(rule, index: index)
                        }
                        if model.rules.isEmpty {
                            Text(model.text(.noRules)).foregroundStyle(.secondary).padding(.vertical)
                        }
                    }
                }
                Menu {
                    ForEach(BatchRenameRuleDraft.Kind.allCases, id: \.rawValue) { kind in
                        Button(model.text(kind.label)) { model.addRule(kind) }
                    }
                } label: { Label(model.text(.addRule), systemImage: "plus") }
                .disabled(model.rules.count >= BatchRenameRuleEngine.maximumRuleCount)
            } else {
                Text(model.text(.listHint)).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                BatchRenameListEditor(text: Binding(get: { model.listText }, set: model.setListText),
                                      label: model.text(.nameList),
                                      rejected: model.rejectOversizedList)
                    .frame(minHeight: 200)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(nsColor: .separatorColor)))
                Button(model.text(.paste)) { model.pasteList() }
            }
        }
        .padding(16)
    }

    private func ruleCard(_ rule: BatchRenameRuleDraft, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(index + 1). \(model.text(rule.kind.label))").font(.headline)
                Spacer(minLength: 0)
                Button { model.moveRule(rule.id, by: -1) } label: { Image(systemName: "arrow.up") }
                    .disabled(index == 0).help(model.text(.moveUp)).accessibilityLabel(model.text(.moveUp))
                Button { model.moveRule(rule.id, by: 1) } label: { Image(systemName: "arrow.down") }
                    .disabled(index == model.rules.count - 1).help(model.text(.moveDown)).accessibilityLabel(model.text(.moveDown))
                Button { model.removeRule(rule.id) } label: { Image(systemName: "minus.circle") }
                    .help(model.text(.remove)).accessibilityLabel(model.text(.remove))
            }
            .buttonStyle(.borderless)
            switch rule.kind {
            case .replace, .delete:
                field(.search, rule: rule, path: \.text)
                if rule.kind == .replace { field(.replacement, rule: rule, path: \.replacement) }
            case .prepend, .append:
                field(.text, rule: rule, path: \.text)
            case .numbering:
                numbering(rule)
            case .uppercase, .lowercase:
                EmptyView()
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func numbering(_ rule: BatchRenameRuleDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                field(.start, rule: rule, path: \.start)
                field(.step, rule: rule, path: \.step)
                field(.width, rule: rule, path: \.width)
            }
            field(.separator, rule: rule, path: \.separator)
            Picker(model.text(.position), selection: binding(rule, \.before)) {
                Text(model.text(.after)).tag(false)
                Text(model.text(.before)).tag(true)
            }
            Picker(model.text(.text), selection: binding(rule, \.unified)) {
                Text(model.text(.currentBody)).tag(false)
                Text(model.text(.unifiedBody)).tag(true)
            }
            if rule.unified { field(.unifiedBody, rule: rule, path: \.unifiedText) }
        }
    }

    private func field(_ key: BatchRenameText, rule: BatchRenameRuleDraft,
                       path: WritableKeyPath<BatchRenameRuleDraft, String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.text(key)).font(.caption).foregroundStyle(.secondary)
            TextField(model.text(key), text: binding(rule, path)).textFieldStyle(.roundedBorder)
                .accessibilityLabel(model.text(key))
        }
    }
    private func binding<Value>(_ rule: BatchRenameRuleDraft,
                                _ path: WritableKeyPath<BatchRenameRuleDraft, Value>) -> Binding<Value> {
        Binding(get: { (model.rules.first { $0.id == rule.id } ?? rule)[keyPath: path] }, set: { value in
            guard var updated = model.rules.first(where: { $0.id == rule.id }) else { return }
            updated[keyPath: path] = value
            model.updateRule(updated)
        })
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.text(.preview)).font(.headline)
                Spacer()
                if model.isChecking || model.isRunning {
                    ProgressView().controlSize(.small)
                    Text(model.text(model.isRunning ? (model.isStopping ? .stopping : .running) : .checking))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }.padding(16)
            if let message = model.message {
                Text(message).font(.callout).textSelection(.enabled)
                    .padding(.horizontal, 16).padding(.bottom, 12)
                    .accessibilityIdentifier("batchRenameMessage")
            }
            Table(model.rows, selection: $model.selectedRowID) {
                TableColumn(model.text(.original)) { row in
                    nameCell(row.original, prefix: model.text(.original))
                }.width(min: 150, ideal: 230)
                TableColumn(model.text(.proposed)) { row in
                    nameCell(row.target, prefix: model.text(.proposed))
                }.width(min: 150, ideal: 230)
                TableColumn(model.text(.state)) { row in
                    Text(model.isChecking ? model.text(.checking) : row.state)
                        .foregroundStyle(row.isError && !model.isChecking ? Color.red : Color.secondary)
                        .help(row.issue ?? row.state)
                        .accessibilityLabel([row.state, row.issue].compactMap { $0 }.joined(separator: ". "))
                }.width(min: 100, ideal: 150)
            }
            .accessibilityIdentifier("batchRenamePreview")
            if let row = model.selectedRow {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.text(.details)).font(.caption).foregroundStyle(.secondary)
                        Text("\(model.text(.original)): \(row.original)")
                        Text("\(model.text(.proposed)): \(row.target)")
                        if let issue = row.issue { Text(issue).foregroundStyle(.red) }
                        if let location = row.location {
                            HStack(alignment: .top) {
                                Text("\(model.text(.location)): \(location.path)")
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([location])
                                } label: { Image(systemName: "folder") }
                                .help(model.text(.location)).accessibilityLabel(model.text(.location))
                            }
                        }
                    }
                    .font(.callout).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
                .frame(maxHeight: 150)
            }
        }
    }

    private func nameCell(_ name: String, prefix: String) -> some View {
        Text(name).lineLimit(1).truncationMode(.middle)
            .help(name).accessibilityLabel("\(prefix): \(name)")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.rows.isEmpty { Text(model.countText).font(.callout).accessibilityIdentifier("batchRenameCounts") }
            HStack {
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
                Spacer()
                if model.isRunning {
                    Button(model.text(.stop)) { model.requestStop() }.disabled(model.isStopping)
                } else {
                    Button(model.text(model.isEditing ? .cancel : .close)) { model.requestClose() }
                    if model.isEditing || model.isUndo && model.result == nil {
                        Button(model.submitTitle) { model.submit() }
                            .disabled(!model.canSubmit)
                            .keyboardShortcut(.return, modifiers: .command)
                            .accessibilityIdentifier("batchRenameSubmit")
                    }
                }
            }
        }
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
        editor.textContainerInset = NSSize(width: 6, height: 6)
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

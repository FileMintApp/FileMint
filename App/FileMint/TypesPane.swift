import AppKit
import FileMintCore
import SwiftUI
import UniformTypeIdentifiers

struct TypesPane: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var model: PreferencesModel
    @State private var selection: String?
    @State private var editor: TypeEditorDraft?
    @State private var restoring = false
    @State private var removing = false
    @State private var draggedTemplateID: String?
    @State private var dropTargetID: String?
    @State private var hoveredTemplateID: String?
    private var dragAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.18) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button(model.text(.addType)) { editor = TypeEditorDraft() }
                Button(model.text(.importDocumentTemplate)) { model.importDocumentTemplate() }
                    .disabled(model.isImportingDocument)
                if model.isImportingDocument { ProgressView().controlSize(.small) }
                Spacer()
            }
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(model.preferences.templates) { template in
                        templateRow(template)
                    }
                }.padding(5)
                    .animation(dragAnimation, value: model.preferences.templates.map(\.id))
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
            HStack(spacing: 8) {
                Button(model.text(.editType)) {
                    if let type = model.preferences.templates.first(where: { $0.id == selection }) { editor = TypeEditorDraft(type) }
                }.disabled(selection == nil)
                Button(model.text(.remove)) { removing = true }
                    .disabled(selection == nil)
                Button(model.text(.makeDefaultTemplate)) {
                    if let template = model.preferences.templates.first(where: { $0.id == selection }) {
                        model.setDefaultTemplate(template)
                    }
                }.disabled(!model.preferences.templates.contains { $0.id == selection && $0.isEnabled && !model.isDefaultTemplate($0) })
                Spacer()
                Button(model.text(.moveUp)) { if let selection { model.moveTemplate(id: selection, by: -1) } }
                    .disabled(!model.canMoveTemplate(id: selection ?? "", by: -1))
                Button(model.text(.moveDown)) { if let selection { model.moveTemplate(id: selection, by: 1) } }
                    .disabled(!model.canMoveTemplate(id: selection ?? "", by: 1))
            }
            HStack {
                Text("\(model.enabledTemplates.count) / \(model.preferences.templates.count) \(model.text(.enabledTypes))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(model.text(.resetBuiltIns)) { restoring = true }.font(.callout)
            }
        }
            .sheet(item: $editor) { TypeEditor(draft: $0).environmentObject(model) }
            .alert(model.text(.restoreConfirm), isPresented: $restoring) {
                Button(model.text(.cancel), role: .cancel) {}
                Button(model.text(.restore)) { model.resetTemplates() }
            }
            .alert(model.text(.deleteTypeConfirm), isPresented: $removing) {
                Button(model.text(.cancel), role: .cancel) {}
                Button(model.text(.remove), role: .destructive) {
                    if let selection { model.removeType(selection); self.selection = nil }
                }
            }
            .onChange(of: model.preferences.templates.map(\.id)) { ids in
                if let selection, !ids.contains(selection) { self.selection = nil }
            }
    }

    private func templateRow(_ template: FileTemplate) -> some View {
        HStack(spacing: 12) {
            Toggle(model.templateDisplayName(for: template), isOn: Binding(
                get: { model.preferences.templates.first(where: { $0.id == template.id })?.isEnabled ?? false },
                set: { enabled in
                    guard let index = model.preferences.templates.firstIndex(where: { $0.id == template.id }) else { return }
                    let previous = model.preferences
                    model.preferences.templates[index].isEnabled = enabled
                    if !model.save() { model.preferences = previous }
                }
            )).labelsHidden().toggleStyle(.checkbox)
                .accessibilityLabel(model.templateDisplayName(for: template))
            Button { selection = template.id } label: {
                HStack(spacing: 12) {
                    Text(template.fileExtension.uppercased())
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .frame(width: 34, height: 38)
                        .background(FileMintStyle.soft, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                    Text(model.templateDisplayName(for: template)).font(.system(size: 13))
                    Spacer(minLength: 8)
                    if model.isDefaultTemplate(template) {
                        Text(model.text(.defaultTemplate)).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(template.suggestedFileName.replacingOccurrences(of: "Untitled", with: ""))
                        .font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityAddTraits(selection == template.id ? .isSelected : [])
                .accessibilityIdentifier("templates.\(template.id).select")
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .frame(width: 20, height: 30).contentShape(Rectangle())
                .onDrag {
                    withAnimation(dragAnimation) { draggedTemplateID = template.id }
                    return NSItemProvider(object: template.id as NSString)
                }
                .help(model.text(.templateReorderHint))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(selection == template.id ? FileMintStyle.selection : hoveredTemplateID == template.id ? FileMintStyle.soft : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
            selection == template.id ? FileMintStyle.accent.opacity(0.35) : Color.clear, lineWidth: 0.8))
        .overlay(alignment: .top) {
            if isDropTarget(template.id, after: false) { SettingsInsertionIndicator().offset(y: -4) }
        }
        .overlay(alignment: .bottom) {
            if isDropTarget(template.id, after: true) { SettingsInsertionIndicator().offset(y: 4) }
        }
        .zIndex(dropTargetID == template.id ? 1 : 0)
        .onHover { hoveredTemplateID = $0 ? template.id : nil }
        .onDrop(of: [UTType.plainText.identifier], isTargeted: Binding(
            get: { dropTargetID == template.id },
            set: { targeted in
                withAnimation(dragAnimation) {
                    if targeted { dropTargetID = template.id }
                    else if dropTargetID == template.id { dropTargetID = nil }
                }
            }
        )) { providers in dropTemplate(providers, on: template.id) }
    }

    private func isDropTarget(_ targetID: String, after: Bool) -> Bool {
        guard dropTargetID == targetID, let draggedTemplateID,
              let source = model.preferences.templates.firstIndex(where: { $0.id == draggedTemplateID }),
              let target = model.preferences.templates.firstIndex(where: { $0.id == targetID }),
              source != target else { return false }
        return (source < target) == after
    }

    private func dropTemplate(_ providers: [NSItemProvider], on targetID: String) -> Bool {
        guard let sourceID = draggedTemplateID,
              let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard object as? String == sourceID else { return }
            DispatchQueue.main.async {
                guard let source = model.preferences.templates.firstIndex(where: { $0.id == sourceID }),
                      let target = model.preferences.templates.firstIndex(where: { $0.id == targetID }),
                      source != target else { return }
                withAnimation(dragAnimation) {
                    model.moveTemplates(fromOffsets: IndexSet(integer: source), toOffset: target + (source < target ? 1 : 0))
                }
            }
        }
        withAnimation(dragAnimation) {
            draggedTemplateID = nil
            dropTargetID = nil
        }
        return true
    }
}
private struct TypeEditorDraft: Identifiable {
    let id = UUID()
    var templateID: String?
    var name = ""
    var suffix = ""
    var content = ""
    var suggestedFileName = ""
    var isDocument = false
    init() {}
    init(_ type: FileTemplate) {
        templateID = type.id
        name = type.displayName
        suffix = type.fileExtension
        suggestedFileName = type.suggestedFileName
        content = type.content
        isDocument = type.document != nil
    }
}

private struct TypeEditor: View {
    @EnvironmentObject private var model: PreferencesModel
    @Environment(\.dismiss) private var dismiss
    @State var draft: TypeEditorDraft
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.text(draft.templateID == nil ? .addType : .editType)).font(.system(size: 21, weight: .semibold))
            VStack(alignment: .leading, spacing: 7) {
                Text(model.text(.displayName)).font(.system(size: 11)).foregroundStyle(.secondary)
                TextField(model.text(.displayName), text: $draft.name).focused($nameFocused)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(model.text(.extensionLabel)).font(.system(size: 11)).foregroundStyle(.secondary)
                TextField(model.text(.extensionLabel), text: $draft.suffix).disabled(draft.isDocument)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(model.text(.defaultFileName)).font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("Untitled.\(draft.suffix.isEmpty ? "txt" : draft.suffix)", text: $draft.suggestedFileName)
            }
            if draft.isDocument {
                Text(model.text(.documentTemplateHint)).font(.callout).foregroundStyle(.secondary)
            } else {
                Text(model.text(.initialContent)).font(.callout)
                    .padding(.top, 2)
                PlainTextEditor(text: $draft.content, label: model.text(.initialContent))
                    .frame(height: 145).clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                Text(model.text(.customTypeHint)).font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button(model.text(.cancel)) { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(MintButtonStyle())
                Button(model.text(.save)) { save() }.keyboardShortcut(.defaultAction).buttonStyle(MintButtonStyle(primary: true))
            }
        }.padding(26).frame(width: 470).background(FileMintStyle.background).tint(FileMintStyle.accent)
            .textFieldStyle(.roundedBorder).onAppear { nameFocused = true }
    }

    private func save() {
        do {
            try model.saveType(name: draft.name, suffix: draft.suffix, content: draft.content, id: draft.templateID,
                suggestedFileName: draft.suggestedFileName)
            if let error = model.lastError { self.error = error } else { dismiss() }
        } catch TemplateValidationError.duplicateExtension { error = model.text(.duplicateType) }
        catch TemplateValidationError.emptyName { error = model.text(.emptyTypeName) }
        catch { self.error = model.text(.invalidFileExtension) }
    }
}

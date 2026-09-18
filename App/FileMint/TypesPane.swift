import FileMintCore
import SwiftUI

struct TypesPane: View {
    @EnvironmentObject private var model: PreferencesModel
    @State private var selection: String?
    @State private var editor: TypeEditorDraft?
    @State private var restoring = false
    @State private var removing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List(selection: $selection) {
                ForEach($model.preferences.templates) { $template in
                    HStack(spacing: 12) {
                        Text(template.suggestedFileName.split(separator: ".").last.map(String.init)?.uppercased() ?? "TXT")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .frame(width: 34, height: 38).background(FileMintStyle.soft, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                        Toggle(model.templateDisplayName(for: template), isOn: $template.isEnabled)
                            .toggleStyle(.checkbox)
                            .onChange(of: template.isEnabled) { _ in model.save() }
                        Spacer()
                        Text(template.suggestedFileName.replacingOccurrences(of: "Untitled", with: ""))
                            .font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                    }.padding(.vertical, 8).tag(template.id)
                }.onMove { model.moveTemplates(fromOffsets: $0, toOffset: $1) }
            }.listStyle(.plain).scrollContentBackground(.hidden)
                .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
            HStack(spacing: 8) {
                Button(model.text(.addType)) { editor = TypeEditorDraft() }
                Button(model.text(.editType)) {
                    if let type = model.preferences.templates.first(where: { $0.id == selection }) { editor = TypeEditorDraft(type) }
                }.disabled(selection == nil || !model.isCustom(selection ?? ""))
                Button(model.text(.remove)) { removing = true }
                    .disabled(selection == nil || !model.isCustom(selection ?? ""))
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
                Button(model.text(.remove), role: .destructive) { if let selection { model.removeType(selection) } }
            }
    }
}
private struct TypeEditorDraft: Identifiable {
    let id = UUID()
    var templateID: String?
    var name = ""
    var suffix = ""
    var content = ""
    init() {}
    init(_ type: FileTemplate) {
        templateID = type.id
        name = type.displayName
        suffix = String(type.suggestedFileName.dropFirst("Untitled.".count))
        content = type.content
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
                TextField(model.text(.extensionLabel), text: $draft.suffix)
            }
            Text(model.text(.initialContent)).font(.callout)
            PlainTextEditor(text: $draft.content, label: model.text(.initialContent))
                .frame(height: 145).clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
            Text(model.text(.customTypeHint)).font(.caption).foregroundStyle(.secondary)
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
            try model.saveType(name: draft.name, suffix: draft.suffix, content: draft.content, id: draft.templateID)
            if let error = model.lastError { self.error = error } else { dismiss() }
        } catch TemplateValidationError.duplicateExtension { error = model.text(.duplicateType) }
        catch TemplateValidationError.emptyName { error = model.text(.emptyTypeName) }
        catch { self.error = model.text(.invalidFileExtension) }
    }
}

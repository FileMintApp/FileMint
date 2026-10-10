import AppKit
import FileMintCore
import SwiftUI
import UniformTypeIdentifiers

struct TypesPane: View {
    @Environment(\.finderMenuIconStyle) private var iconStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var model: PreferencesModel
    @State private var selection: String?
    @State private var editor: TypeEditorDraft?
    @State private var preview: FileTemplate?
    @State private var exporting = false
    @State private var restoring = false
    @State private var removing = false
    @State private var draggedTemplateID: String?
    @State private var dropTargetID: String?
    private var dragAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.18) }

    init(selectionID: String? = nil) { _selection = State(initialValue: selectionID) }

    var body: some View {
        let defaultIDs = Set(TemplateCatalog.effectiveDefaultTemplateIDs(in: model.preferences.templates,
            defaults: model.preferences.defaultTemplateIDs).values)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button(model.text(.addType)) { editor = TypeEditorDraft(reveal: model.preferences.revealAfterCreation) }
                Menu(model.workflowText(.importMenu)) {
                    Button(model.workflowText(.importPackage)) { model.importTemplatePackage() }
                    Button(model.text(.importDocumentTemplate)) { model.importDocumentTemplate() }
                }.disabled(!model.templateMutationAllowed)
                Button(model.workflowText(.exportPackage)) { exporting = true }.disabled(!model.templateMutationAllowed)
                if model.isMutatingTemplates { ProgressView().controlSize(.small) }
                Spacer()
            }
            if let recovery = model.templateRecoveryError {
                HStack {
                    Text(recovery).font(.callout).foregroundStyle(.secondary)
                    Button(model.text(.retry)) { Task { await model.recoverTemplateTransactions() } }
                }
            }
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(model.preferences.templates) { template in
                        templateRow(template, isDefault: defaultIDs.contains(template.id))
                    }
                }.padding(5)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
            HStack(spacing: 8) {
                Button(model.text(.editType)) {
                    if let selection { editTemplate(selection) }
                }.disabled(selection == nil)
                Button(model.workflowText(.copy)) {
                    if let type = model.preferences.templates.first(where: { $0.id == selection }) {
                        editor = TypeEditorDraft(type, placement: model.preferences.templateMenuPlacement(for: type.id), asCopy: true, copySuffix: model.workflowText(.copySuffix))
                    }
                }.disabled(selection == nil)
                if model.preferences.templatePreviewEnabled {
                    Button(model.workflowText(.preview)) {
                        preview = model.preferences.templates.first { $0.id == selection }
                    }.disabled(selection == nil)
                }
                Button(model.text(.remove)) { removing = true }
                    .disabled(selection == nil)
                Button(model.text(.makeDefaultTemplate)) {
                    if let template = model.preferences.templates.first(where: { $0.id == selection }) {
                        model.setDefaultTemplate(template)
                    }
                }.disabled(!model.preferences.templates.contains { $0.id == selection && $0.isEnabled && !model.isDefaultTemplate($0) })
                Spacer()
                Button(model.text(.moveUp)) { if let selection { withAnimation(dragAnimation) { model.moveTemplate(id: selection, by: -1) } } }
                    .disabled(!model.canMoveTemplate(id: selection ?? "", by: -1))
                Button(model.text(.moveDown)) { if let selection { withAnimation(dragAnimation) { model.moveTemplate(id: selection, by: 1) } } }
                    .disabled(!model.canMoveTemplate(id: selection ?? "", by: 1))
            }
            if model.preferences.templatePreviewEnabled, let selected = model.preferences.templates.first(where: { $0.id == selection }) {
                TemplatePreviewView(template: selected, assets: model.documentTemplates, language: model.preferences.language)
                    .frame(height: 180)
                Text(model.workflowText(.exampleContext)).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("\(model.enabledTemplates.count) / \(model.preferences.templates.count) \(model.text(.enabledTypes))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(model.text(.resetBuiltIns)) { restoring = true }.font(.callout)
            }
        }
            .disabled(model.isMutatingTemplates)
            .overlay(alignment: .topTrailing) {
                if model.isValidatingPackage {
                    Button(model.text(.cancel)) { model.cancelTemplatePackageValidation() }
                        .disabled(false).accessibilityIdentifier("templates.cancelValidation")
                }
            }
            .sheet(item: $model.packageReview) { review in TemplateImportReviewView(review: review).environmentObject(model) }
            .sheet(isPresented: $exporting) { TemplateExportSelectionView(selectedID: selection).environmentObject(model) }
            .sheet(item: $editor) { TypeEditor(draft: $0).environmentObject(model) }
            .sheet(item: $preview) { template in
                VStack(spacing: 12) {
                    Text(model.templateDisplayName(for: template)).font(.title2)
                    if model.preferences.templatePreviewEnabled {
                        TemplatePreviewView(template: template, assets: model.documentTemplates, language: model.preferences.language)
                    }
                    Text(model.workflowText(.exampleContext)).font(.caption).foregroundStyle(.secondary)
                    Button(model.text(.cancel)) { preview = nil }.keyboardShortcut(.cancelAction)
                }.padding(24).frame(width: 640, height: 520)
            }
            .onChange(of: model.preferences.templatePreviewEnabled) { enabled in if !enabled { preview = nil } }
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

    private func editTemplate(_ id: String) {
        guard editor == nil, let template = model.preferences.templates.first(where: { $0.id == id }) else { return }
        selection = id
        editor = TypeEditorDraft(template, placement: model.preferences.templateMenuPlacement(for: id))
    }

    private func templateRow(_ template: FileTemplate, isDefault: Bool) -> some View {
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
                    if let icon = FileToolAppearance.image(for: template, size: 24, style: iconStyle) {
                        Image(nsImage: icon).renderingMode(iconStyle == .systemMonochrome ? .template : .original)
                            .resizable().interpolation(.high).foregroundStyle(.primary)
                            .frame(width: 24, height: 24).accessibilityHidden(true)
                    }
                    Text(template.fileExtension.uppercased())
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .frame(width: 34, height: 38)
                        .background(FileMintStyle.soft, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.templateDisplayName(for: template)).font(.system(size: 13))
                        if model.preferences.creationOpeningEnabled, let action = template.afterCreation {
                            Text(model.workflowText(action.kind.textKey) + (action.application.map { " · " + $0.displayName } ?? ""))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    if isDefault {
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
                .simultaneousGesture(TapGesture(count: 2).onEnded { editTemplate(template.id) })
            CreationPlacementPicker(selection: model.templatePlacementBinding(for: template.id),
                language: model.preferences.language,
                label: model.templateDisplayName(for: template) + " — " + model.text(.toolMenuPosition))
                .disabled(!template.isEnabled).accessibilityIdentifier("templates.\(template.id).placement")
            Button { editTemplate(template.id) } label: { Image(systemName: "pencil") }
                .buttonStyle(.plain).accessibilityLabel(model.text(.editType) + " — " + model.templateDisplayName(for: template))
                .accessibilityIdentifier("templates.\(template.id).edit")
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
        .modifier(TemplateRowSurface(isSelected: selection == template.id))
        .overlay(alignment: .top) {
            if isDropTarget(template.id, after: false) { SettingsInsertionIndicator().offset(y: -4) }
        }
        .overlay(alignment: .bottom) {
            if isDropTarget(template.id, after: true) { SettingsInsertionIndicator().offset(y: 4) }
        }
        .zIndex(dropTargetID == template.id ? 1 : 0)
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
private struct TemplateRowSurface: ViewModifier {
    let isSelected: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(isSelected ? FileMintStyle.selection : isHovered ? FileMintStyle.soft : Color.clear,
                in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
                isSelected ? FileMintStyle.accent.opacity(0.35) : Color.clear, lineWidth: 0.8))
            .onHover { isHovered = $0 }
    }
}

private struct TypeEditorDraft: Identifiable {
    let id = UUID()
    enum Mode { case new, edit(String), copy(String) }
    var mode: Mode = .new
    var original: FileTemplate?
    var templateID: String? { if case .edit(let id) = mode { return id }; return nil }
    var copySourceID: String? { if case .copy(let id) = mode { return id }; return nil }
    var copiedTemplate: FileTemplate? { copySourceID == nil ? nil : original }
    var action = TemplateCreationAction.basic(reveal: true)
    var application: CreationApplication?
    var name = ""
    var suffix = ""
    var content = ""
    var suggestedFileName = ""
    var isDocument = false
    var customMenuIcon: MenuIconCustomization?
    var menuPlacement: CreationMenuPlacement = .submenu
    init(reveal: Bool = true) { action = .basic(reveal: reveal) }
    init(_ source: FileTemplate, placement: CreationMenuPlacement = .submenu, asCopy: Bool = false, copySuffix: String = "Copy") {
        let type = asCopy ? TemplateCatalog.copyDraft(source, copySuffix: copySuffix) : source
        mode = asCopy ? .copy(source.id) : .edit(source.id)
        original = type
        action = type.afterCreation ?? .basic(reveal: true)
        name = type.displayName
        suffix = type.fileExtension
        suggestedFileName = type.suggestedFileName
        content = type.content
        isDocument = type.document != nil
        customMenuIcon = type.customMenuIcon
        menuPlacement = placement
    }
}

private struct TypeEditor: View {
    @EnvironmentObject private var model: PreferencesModel
    @Environment(\.dismiss) private var dismiss
    @State var draft: TypeEditorDraft
    @State private var error: String?
    @State private var isSaving = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.copySourceID == nil ? model.text(draft.templateID == nil ? .addType : .editType) : model.workflowText(.copy)).font(.system(size: 21, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
                    PreferenceRow(title: model.text(.toolMenuPosition)) {
                        CreationPlacementPicker(selection: $draft.menuPlacement, language: model.preferences.language,
                            label: model.text(.toolMenuPosition)).accessibilityIdentifier("templateEditor.placement")
                    }
                    HStack {
                        Text(model.preferences.language.resolved() == .chinese ? "菜单图标" : "Menu icon")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        MenuIconControl(template: iconPreviewTemplate, customization: $draft.customMenuIcon,
                            language: model.preferences.language)
                    }
                    if model.preferences.creationOpeningEnabled {
                        Picker(model.workflowText(.openingEnabled), selection: Binding(
                            get: { draft.action.kind }, set: { draft.action = .init($0, application: draft.action.application, localApplicationID: draft.action.localApplicationID) })) {
                            ForEach(TemplateCreationAction.Kind.allCases, id: \.self) { kind in Text(model.workflowText(kind.textKey)).tag(kind) }
                        }
                        if draft.action.kind == .openWithApplication {
                            HStack {
                                VStack(alignment: .leading) {
                                    CreationApplicationLabel(
                                        name: draft.action.application?.displayName ?? model.workflowText(.selectedApp),
                                        application: selectedApplication)
                                    if draft.action.localApplicationID == nil { Text(model.workflowText(.unresolvedApp)).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Button(model.workflowText(.chooseApp)) {
                                    Task {
                                        do {
                                            if let app = try await model.chooseCreationApplication() {
                                                draft.application = app
                                                draft.action = .init(.openWithApplication, application: app.hint, localApplicationID: app.id)
                                            }
                                        } catch { self.error = error.localizedDescription }
                                    }
                                }
                            }
                        }
                    }
                    if draft.isDocument {
                        Text(model.text(.documentTemplateHint)).font(.callout).foregroundStyle(.secondary)
                    } else {
                        Text(model.text(.initialContent)).font(.callout)
                            .padding(.top, 2)
                        HStack(alignment: .top, spacing: 12) {
                            PlainTextEditor(text: $draft.content, label: model.text(.initialContent))
                                .frame(height: 145).clipShape(RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                            if model.preferences.templatePreviewEnabled {
                                TemplatePreviewView(template: previewTemplate, assets: model.documentTemplates, language: model.preferences.language)
                                    .frame(height: 145)
                            }
                        }
                        Text(model.text(.customTypeHint)).font(.caption).foregroundStyle(.secondary)
                    }
                    if model.preferences.templatePreviewEnabled {
                        if draft.isDocument {
                            TemplatePreviewView(template: previewTemplate, assets: model.documentTemplates, language: model.preferences.language)
                                .frame(height: 180)
                        }
                        Text(model.workflowText(.exampleContext)).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(1)
            }.frame(minHeight: 260, maxHeight: 440)
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button(model.text(.cancel)) { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(MintButtonStyle())
                Button(model.text(.save)) { Task { await save() } }.keyboardShortcut(.defaultAction).buttonStyle(MintButtonStyle(primary: true))
                    .disabled(!draft.action.isValid)
            }
        }.disabled(isSaving).padding(26).frame(width: model.preferences.templatePreviewEnabled && !draft.isDocument ? 680 : 470).background(FileMintStyle.background).tint(FileMintStyle.accent)
             .textFieldStyle(.roundedBorder).onAppear { nameFocused = true; model.hasTemplateModalWork = true }
            .onDisappear { model.hasTemplateModalWork = false }
    }

    private var iconPreviewTemplate: FileTemplate {
        FileTemplate(id: draft.templateID ?? "preview", displayName: draft.name,
            suggestedFileName: draft.suggestedFileName, group: "Custom", content: "",
            rank: 0, fileExtension: draft.suffix)
    }

    private var selectedApplication: CreationApplication? {
        ([draft.application].compactMap { $0 } + model.preferences.creationApplications).first {
            $0.id == draft.action.localApplicationID && $0.hint == draft.action.application
        }
    }

    private var previewTemplate: FileTemplate {
        var template = draft.original ?? iconPreviewTemplate
        template.content = draft.content
        template.suggestedFileName = FilenamePolicy.fileName(draft.suggestedFileName, applyingFileExtension: draft.suffix,
            replacingFileExtension: draft.original?.fileExtension) ?? "Untitled.txt"
        return template
    }
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await model.saveType(name: draft.name, suffix: draft.suffix, content: draft.content, id: draft.templateID,
                suggestedFileName: draft.suggestedFileName, customMenuIcon: draft.customMenuIcon,
                copy: draft.copiedTemplate, sourceID: draft.copySourceID, action: draft.action, application: draft.application, menuPlacement: draft.menuPlacement)
            if let error = model.lastError { self.error = error } else { dismiss() }
        } catch TemplateValidationError.duplicateExtension { error = model.text(.duplicateType) }
        catch TemplateValidationError.emptyName { error = model.text(.emptyTypeName) }
        catch TemplateValidationError.invalidExtension { self.error = model.text(.invalidFileExtension) }
        catch is TemplateCreationActionError { self.error = model.workflowText(.applicationRequired) }
        catch { self.error = model.lastError ?? (error as? DocumentTemplateError).map { model.text($0.textKey) } ?? error.localizedDescription }
    }
}

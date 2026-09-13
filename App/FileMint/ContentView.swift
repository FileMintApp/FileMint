import AppKit
import FileMintCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $model.selectedPane) {
                GeneralPane().tabItem { Text(model.text(.general)) }.tag(PreferencesModel.Pane.general)
                TypesPane().tabItem { Text(model.text(.fileTypes)) }.tag(PreferencesModel.Pane.fileTypes)
                FoldersPane().tabItem { Text(model.text(.folders)) }.tag(PreferencesModel.Pane.folders)
                AboutPane().tabItem { Text(model.text(.about)) }.tag(PreferencesModel.Pane.about)
            }
            .padding(20)
            if let error = model.lastError {
                Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled)
                    .padding([.horizontal, .bottom], 20)
            }
        }
        .frame(width: 640, height: 490)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshStatus()
        }
    }
}

private struct GeneralPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text("FileMint").font(.title2.weight(.semibold))
                    Text(model.text(.productTagline)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.text(.customNewFile)) { model.newFile() }
                    .keyboardShortcut("n").controlSize(.large)
            }
            Text(model.text(.productDetail)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Text(model.text(.language))
                Spacer()
                Picker("", selection: $model.preferences.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language == .system ? model.text(.followSystem) : language.displayName).tag(language)
                    }
                }.labelsHidden().frame(width: 160)
                    .onChange(of: model.preferences.language) { _ in model.save() }
            }
            Toggle(model.text(.launchAtLogin), isOn: Binding(
                get: { model.preferences.launchAtLogin },
                set: { value in Task { await model.setLaunchAtLogin(value) } }
            )).disabled(model.isUpdatingLoginItem)
            if let hint = model.loginItemHint {
                VStack(alignment: .leading, spacing: 5) {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(model.text(.openLoginSettings)) { model.openLoginSettings() }
                        if model.loginItemError != nil {
                            Button(model.text(.retry)) { Task { await model.setLaunchAtLogin(true) } }
                                .disabled(model.isUpdatingLoginItem)
                        }
                    }.font(.caption)
                }
            }
            Toggle(model.text(.showMenuBar), isOn: Binding(
                get: { model.preferences.showMenuBar }, set: { model.setShowMenuBar($0) }
            ))
            Toggle(model.text(.revealCreatedFile), isOn: $model.preferences.revealAfterCreation)
                .onChange(of: model.preferences.revealAfterCreation) { _ in model.save() }
            HStack {
                Text(model.text(.whenFileExists))
                Spacer()
                Picker("", selection: $model.preferences.collisionStrategy) {
                    Text(model.text(.autoIncrement)).tag(NameCollisionStrategy.increment)
                    Text(model.text(.fail)).tag(NameCollisionStrategy.fail)
                }.labelsHidden().frame(width: 160)
                    .onChange(of: model.preferences.collisionStrategy) { _ in model.save() }
            }
            Divider()
            HStack {
                Text("Finder").fontWeight(.medium)
                Text(model.extensionEnabled ? model.text(.ready) : model.text(.permissionSetup))
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button(model.text(.openExtensionSettings)) { model.openExtensionSettings() }
            }
            Text(model.text(.finderSetup)).font(.callout).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                Text(model.text(.sourceAvailable)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }.padding(18)
        }
    }
}

private struct TypesPane: View {
    @EnvironmentObject private var model: PreferencesModel
    @State private var selection: String?
    @State private var editor: TypeEditorDraft?
    @State private var restoring = false
    @State private var removing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.text(.fileTypeHint)).font(.callout).foregroundStyle(.secondary)
            List(selection: $selection) {
                ForEach($model.preferences.templates) { $template in
                    HStack(spacing: 12) {
                        Toggle(model.templateDisplayName(for: template), isOn: $template.isEnabled)
                            .toggleStyle(.checkbox)
                            .onChange(of: template.isEnabled) { _ in model.save() }
                        Spacer()
                        Text(template.suggestedFileName.replacingOccurrences(of: "Untitled", with: ""))
                            .font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                    }.padding(.vertical, 4).tag(template.id)
                }.onMove { model.moveTemplates(fromOffsets: $0, toOffset: $1) }
            }.listStyle(.bordered(alternatesRowBackgrounds: true))
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
            Button(model.text(.resetBuiltIns)) { restoring = true }.font(.callout)
        }.padding(16)
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
            Text(model.text(draft.templateID == nil ? .addType : .editType)).font(.headline)
            TextField(model.text(.displayName), text: $draft.name).focused($nameFocused)
            TextField(model.text(.extensionLabel), text: $draft.suffix)
            Text(model.text(.initialContent)).font(.callout)
            PlainTextEditor(text: $draft.content, label: model.text(.initialContent))
                .frame(height: 120).border(Color(nsColor: .separatorColor))
            Text(model.text(.customTypeHint)).font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button(model.text(.cancel)) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(model.text(.save)) { save() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 430).onAppear { nameFocused = true }
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

private struct FoldersPane: View {
    @EnvironmentObject private var model: PreferencesModel
    @State private var selection: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.text(.folderHint)).font(.callout).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model.text(.fullDiskAccess)).fontWeight(.medium)
                    Spacer()
                    Button(model.text(.openFullDiskAccess)) { model.openFullDiskAccessSettings() }
                }
                Text(model.text(.fullDiskAccessStatus)).font(.callout.weight(.medium))
                Text(model.text(.fullDiskAccessStatusHint))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(model.text(.fullDiskAccessEnabledHint))
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
                Text(model.text(.fullDiskAccessHint))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Text(model.text(.folderAccessReminder))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            List(model.preferences.monitoredFolderURLs, id: \.self, selection: $selection) { url in
                VStack(alignment: .leading, spacing: 3) {
                    Text((url.path as NSString).abbreviatingWithTildeInPath).lineLimit(1).truncationMode(.middle)
                    Text(model.preferences.monitoredFolderBookmarks[url.path] == nil ? model.text(.needsAccess) : model.text(.folderAccessSaved))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 5).tag(url)
            }.listStyle(.bordered(alternatesRowBackgrounds: true))
            HStack {
                Button(model.text(.addFolder)) { model.addMonitoredFolder() }
                Button(model.text(.authorize)) { model.addMonitoredFolder(initial: selection) }.disabled(selection == nil)
                Button(model.text(.remove)) { if let selection { model.removeFolder(selection) } }.disabled(selection == nil)
                Spacer()
            }
        }.padding(16)
    }
}

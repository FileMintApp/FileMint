import FileMintCore
import SwiftUI

/// A functional preference group shared by settings pages, not a persistence layer.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 14) { content }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor).opacity(0.45)))
        }
    }
}

struct GeneralPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SettingsSection(title: model.text(.language)) {
                    HStack {
                        Text(model.text(.interfaceLanguage))
                        Spacer()
                        Picker(model.text(.interfaceLanguage), selection: $model.preferences.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language == .system ? model.text(.followSystem) : language.displayName).tag(language)
                            }
                        }.labelsHidden().frame(width: 180)
                            .onChange(of: model.preferences.language) { _ in model.save() }
                    }
                }
                SettingsSection(title: model.text(.startupAndAccess)) {
                    Toggle(isOn: Binding(
                        get: { model.preferences.launchAtLogin },
                        set: { value in Task { await model.setLaunchAtLogin(value) } }
                    )) {
                        Text(model.text(.launchAtLogin)).frame(maxWidth: .infinity, alignment: .leading)
                    }.disabled(model.isUpdatingLoginItem)
                    if let hint = model.loginItemHint {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(hint).font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Button(model.text(.openLoginSettings)) { model.openLoginSettings() }
                                if model.loginItemError != nil {
                                    Button(model.text(.retry)) { Task { await model.setLaunchAtLogin(true) } }
                                        .disabled(model.isUpdatingLoginItem)
                                }
                            }.controlSize(.small)
                        }
                    }
                    Divider()
                    Toggle(isOn: Binding(
                        get: { model.preferences.showMenuBar }, set: { model.setShowMenuBar($0) }
                    )) {
                        Text(model.text(.showMenuBar)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                SettingsSection(title: model.text(.updates)) {
                    Toggle(isOn: Binding(
                        get: { model.preferences.automaticallyChecksForUpdates },
                        set: { model.setAutomaticallyChecksForUpdates($0) }
                    )) {
                        Text(model.text(.automaticallyCheckForUpdates)).frame(maxWidth: .infinity, alignment: .leading)
                    }.accessibilityIdentifier("automaticallyCheckForUpdates")
                    Text(model.text(.automaticUpdateHint)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(model.text(.viewUpdateSettings)) { model.selectedPane = .about }
                }
            }.toggleStyle(SmallSettingsSwitchStyle()).padding(1)
        }
    }
}

struct FileToolsPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SettingsSection(title: model.text(.fileTools)) {
                    Toggle(model.text(.enableFileTools), isOn: $model.preferences.fileTools.isEnabled)
                        .accessibilityIdentifier("fileTools.enabled")
                    Text(model.text(.fileToolsOffHint)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.preferences.fileTools.isEnabled {
                    SettingsSection(title: model.text(.fileToolsActions)) {
                        ForEach(FileTool.allCases, id: \.self) { tool in
                            if tool != FileTool.allCases.first { Divider() }
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(model.text(tool.title), isOn: Binding(
                                    get: { model.preferences.fileTools.isToolEnabled(tool) },
                                    set: { model.preferences.fileTools.setEnabled($0, for: tool) }
                                )).accessibilityIdentifier("fileTools.\(tool.rawValue)")
                                Toggle(model.text(.showInMainMenu), isOn: Binding(
                                    get: { model.preferences.fileTools.mainMenuTools.contains(tool) },
                                    set: { value in
                                        if value { model.preferences.fileTools.mainMenuTools.insert(tool) }
                                        else { model.preferences.fileTools.mainMenuTools.remove(tool) }
                                    }
                                ))
                                .accessibilityLabel("\(model.text(tool.title)) — \(model.text(.showInMainMenu))")
                                .accessibilityIdentifier("fileTools.\(tool.rawValue).mainMenu")
                                .disabled(!model.preferences.fileTools.isToolEnabled(tool))
                                .padding(.leading, 16)
                                if tool == .move {
                                    Toggle(model.text(.moveHereInMainMenu), isOn: $model.preferences.fileTools.moveHereInMainMenu)
                                        .disabled(!model.preferences.fileTools.move)
                                        .accessibilityIdentifier("fileTools.moveHere.mainMenu")
                                        .padding(.leading, 16)
                                }
                                if tool == .permanentDelete {
                                    Picker(model.text(.deleteConfirmation), selection: $model.preferences.fileTools.deleteConfirmation) {
                                        Text(model.text(.deleteRequireConfirmation)).tag(DeleteConfirmation.required)
                                        Text(model.text(.deleteSilently)).tag(DeleteConfirmation.silent)
                                    }.pickerStyle(.menu)
                                        .disabled(!model.preferences.fileTools.permanentDelete)
                                        .accessibilityIdentifier("fileTools.deleteConfirmation")
                                        .padding(.leading, 16)
                                    Text(model.text(.permanentDeleteHint)).font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if tool == .airDrop {
                                    Text(model.text(.airDropHint)).font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        Text(model.text(.moveItemsHint)).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(model.text(.copyItemsHint)).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.toggleStyle(SmallSettingsSwitchStyle()).padding(1)
        }.onChange(of: model.preferences.fileTools) { _ in model.save() }
    }
}

struct CreationSettingsPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SettingsSection(title: model.text(.quickCreation)) {
                    HStack {
                        Text(model.text(.whenFileExists))
                        Spacer()
                        Picker(model.text(.whenFileExists), selection: $model.preferences.collisionStrategy) {
                            Text(model.text(.autoIncrement)).tag(NameCollisionStrategy.increment)
                            Text(model.text(.fail)).tag(NameCollisionStrategy.fail)
                        }.labelsHidden().frame(width: 180)
                            .onChange(of: model.preferences.collisionStrategy) { _ in model.save() }
                    }
                    Text(model.text(.quickCollisionHint)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                SettingsSection(title: model.text(.afterCreation)) {
                    Toggle(isOn: $model.preferences.revealAfterCreation) {
                        Text(model.text(.revealCreatedFile)).frame(maxWidth: .infinity, alignment: .leading)
                    }.toggleStyle(SmallSettingsSwitchStyle())
                        .onChange(of: model.preferences.revealAfterCreation) { _ in model.save() }
                    Text(model.text(.afterCreationHint)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(model.text(.manageTemplates)) { model.selectedPane = .fileTypes }
            }.padding(1)
        }
    }
}

private struct SmallSettingsSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: configuration.$isOn) { configuration.label }
            .toggleStyle(.switch)
            .controlSize(.small)
    }
}

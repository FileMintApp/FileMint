import FileMintCore
import SwiftUI

/// A functional preference group shared by settings pages, not a persistence layer.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 14) { content }
                .mintSurface()
        }
    }
}

struct GeneralPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 16) {
                    Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(InterfaceText.prepared.text(model.preferences.language)).font(.system(size: 17, weight: .medium))
                        Text((model.extensionEnabled ? InterfaceText.enabledFinder : .disabledFinder).text(model.preferences.language))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.mintSurface()
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
                    PreferenceRow(title: model.text(.launchAtLogin), detail: InterfaceText.launchHint.text(model.preferences.language)) {
                    Toggle(model.text(.launchAtLogin), isOn: Binding(
                        get: { model.preferences.launchAtLogin },
                        set: { value in Task { await model.setLaunchAtLogin(value) } }
                    )).labelsHidden().disabled(model.isUpdatingLoginItem)
                    }
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
                    PreferenceRow(title: model.text(.showMenuBar), detail: InterfaceText.menuBarHint.text(model.preferences.language)) {
                    Toggle(model.text(.showMenuBar), isOn: Binding(
                        get: { model.preferences.showMenuBar }, set: { model.setShowMenuBar($0) }
                    )).labelsHidden()
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
        FileToolsSettingsView(preferences: $model.preferences.fileTools,
                              language: model.preferences.language)
            .onChange(of: model.preferences.fileTools) { _ in model.save() }
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

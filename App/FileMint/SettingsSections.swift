import FileMintCore
import SwiftUI

struct GeneralPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 16) {
                    Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(InterfaceText.prepared.text(model.preferences.language)).font(.system(size: 17, weight: .medium))
                        Text((model.extensionEnabled ? InterfaceText.enabledFinder : .disabledFinder).text(model.preferences.language))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.mintSurface()
                if !model.extensionEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(model.text(.finderExtension), systemImage: "puzzlepiece.extension")
                            .font(.system(size: 15, weight: .semibold))
                        Text(model.text(.finderSetup))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(model.finderSettingsPath)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(model.text(.openExtensionSettings)) { model.openExtensionSettings() }
                            .buttonStyle(MintButtonStyle(primary: true))
                            .accessibilityIdentifier("onboarding.openExtensionSettings")
                    }
                    .mintSurface()
                    .accessibilityIdentifier("onboarding.finderExtension")
                }
                SettingsSection(title: model.text(.fullDiskAccess)) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 19)).foregroundStyle(FileMintStyle.accent)
                            .frame(width: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.text(.fullDiskSetupHint))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button(model.text(.openFullDiskAccess)) { model.openFullDiskAccessSettings() }
                                .buttonStyle(MintButtonStyle())
                                .accessibilityIdentifier("onboarding.openFullDiskAccess")
                        }
                    }
                }.accessibilityIdentifier("onboarding.fullDiskAccess")
                SettingsSection(title: model.text(.appearance)) {
                    PreferenceRow(title: model.text(.theme)) {
                        Picker(model.text(.theme), selection: Binding(
                            get: { model.preferences.appearance }, set: { model.setAppearance($0) }
                        )) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(model.text(appearance.title)).tag(appearance)
                            }
                        }.settingsMenu().accessibilityIdentifier("settings.appearance")
                    }
                    Divider()
                    PreferenceRow(title: model.text(.interfaceLanguage)) {
                        Picker(model.text(.interfaceLanguage), selection: $model.preferences.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language == .system ? model.text(.followSystem) : language.displayName).tag(language)
                            }
                        }.settingsMenu().accessibilityIdentifier("settings.language")
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
                            Text(hint).font(.system(size: 11)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
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
                    PreferenceRow(title: model.text(.automaticallyCheckForUpdates), detail: model.text(.automaticUpdateHint)) {
                        Toggle(model.text(.automaticallyCheckForUpdates), isOn: Binding(
                            get: { model.preferences.automaticallyChecksForUpdates },
                            set: { model.setAutomaticallyChecksForUpdates($0) }
                        )).labelsHidden().accessibilityIdentifier("automaticallyCheckForUpdates")
                    }
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
                    PreferenceRow(title: model.text(.newFileMenuPosition), detail: model.text(.newFileMenuPositionHint)) {
                        Picker(model.text(.newFileMenuPosition), selection: Binding(
                            get: { model.preferences.newFileMenuPlacement },
                            set: { value in
                                let previous = model.preferences.newFileMenuPlacement
                                model.preferences.newFileMenuPlacement = value
                                if !model.save() { model.preferences.newFileMenuPlacement = previous }
                            }
                        )) {
                            Text(model.text(.openWithSubmenu)).tag(NewFileMenuPlacement.submenu)
                            Text(model.text(.toolMainMenu)).tag(NewFileMenuPlacement.main)
                        }.settingsMenu().accessibilityIdentifier("settings.newFileMenuPlacement")
                    }
                    Divider()
                    PreferenceRow(title: model.text(.whenFileExists), detail: model.text(.quickCollisionHint)) {
                        Picker(model.text(.whenFileExists), selection: $model.preferences.collisionStrategy) {
                            Text(model.text(.autoIncrement)).tag(NameCollisionStrategy.increment)
                            Text(model.text(.fail)).tag(NameCollisionStrategy.fail)
                        }.settingsMenu().accessibilityIdentifier("settings.collisionStrategy")
                            .onChange(of: model.preferences.collisionStrategy) { _ in model.save() }
                    }
                }
                SettingsSection(title: model.text(.afterCreation)) {
                    PreferenceRow(title: model.text(.revealCreatedFile), detail: model.text(.afterCreationHint)) {
                        Toggle(model.text(.revealCreatedFile), isOn: $model.preferences.revealAfterCreation)
                            .labelsHidden().toggleStyle(SmallSettingsSwitchStyle())
                            .onChange(of: model.preferences.revealAfterCreation) { _ in model.save() }
                    }
                }
                Button(model.text(.manageTemplates)) { model.selectedPane = .fileTypes }
            }.padding(1)
        }
    }
}

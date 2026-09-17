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
            }.toggleStyle(.switch).padding(1)
        }
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
                    }.toggleStyle(.switch)
                        .onChange(of: model.preferences.revealAfterCreation) { _ in model.save() }
                    Text(model.text(.afterCreationHint)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(model.text(.manageTemplates)) { model.selectedPane = .fileTypes }
            }.padding(1)
        }
    }
}

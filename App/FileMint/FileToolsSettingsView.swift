import FileMintCore
import SwiftUI

/// The same settings surface runs in an isolated fixture without a preferences store.
struct FileToolsSettingsView: View {
    @Binding var preferences: FileToolsPreferences
    let language: AppLanguage
    private func text(_ key: FileMintTextKey) -> String { FileMintStrings.text(key, language: language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SettingsSection(title: text(.fileTools)) {
                    PreferenceRow(title: text(.enableFileTools), detail: text(.fileToolsOffHint)) {
                        Toggle(text(.enableFileTools), isOn: $preferences.isEnabled)
                            .labelsHidden().accessibilityIdentifier("fileTools.enabled")
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionTitle(title: text(.fileToolsActions))
                    VStack(spacing: 0) {
                        ForEach(FileTool.allCases, id: \.self) { tool in
                            if tool != FileTool.allCases.first { Divider().padding(.horizontal, 17) }
                            toolRow(tool).padding(17)
                        }
                    }.mintSurface(padding: 0)
                        .disabled(!preferences.isEnabled)
                        .saturation(preferences.isEnabled ? 1 : 0)
                        .opacity(preferences.isEnabled ? 1 : 0.5)
                }
            }.toggleStyle(SmallSettingsSwitchStyle()).tint(FileMintStyle.accent).padding(1)
        }
    }

    private func toolRow(_ tool: FileTool) -> some View {
        let enabled = preferences.isToolEnabled(tool)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if let image = FileToolAppearance.image(for: tool, size: 18) {
                    Image(nsImage: image).resizable().frame(width: 18, height: 18).accessibilityHidden(true)
                        .saturation(enabled ? 1 : 0).opacity(enabled ? 1 : 0.5)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(text(tool.title)).font(.system(size: 12, weight: .medium))
                    Text(text(hint(for: tool))).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                positionPicker(selection: Binding(
                    get: { preferences.mainMenuTools.contains(tool) },
                    set: { value in
                        if value { preferences.mainMenuTools.insert(tool) }
                        else { preferences.mainMenuTools.remove(tool) }
                    }), label: "\(text(tool.title)) — \(text(.toolMenuPosition))")
                    .disabled(!enabled).accessibilityIdentifier("fileTools.\(tool.rawValue).mainMenu")
                Toggle(text(tool.title), isOn: Binding(get: { enabled }, set: { preferences.setEnabled($0, for: tool) }))
                    .labelsHidden().accessibilityIdentifier("fileTools.\(tool.rawValue)")
            }
            if tool == .move {
                PreferenceRow(title: text(.moveHereMenuPosition)) {
                    positionPicker(selection: $preferences.moveHereInMainMenu, label: text(.moveHereMenuPosition))
                        .accessibilityIdentifier("fileTools.moveHere.mainMenu")
                }.font(.system(size: 11)).padding(.leading, 32).disabled(!enabled)
            } else if tool == .permanentDelete {
                PreferenceRow(title: text(.deleteConfirmation)) {
                    Picker(text(.deleteConfirmation), selection: $preferences.deleteConfirmation) {
                        Text(text(.deleteRequireConfirmation)).tag(DeleteConfirmation.required)
                        Text(text(.deleteSilently)).tag(DeleteConfirmation.silent)
                    }.settingsMenu()
                        .accessibilityIdentifier("fileTools.deleteConfirmation")
                }.padding(.leading, 32).disabled(!enabled)
            }
        }
    }

    private func positionPicker(selection: Binding<Bool>, label: String) -> some View {
        Picker(label, selection: selection) {
            Text(text(.toolSubmenu)).tag(false)
            Text(text(.toolMainMenu)).tag(true)
        }.settingsMenu(width: language.resolved() == .chinese ? 119 : 138).accessibilityLabel(label)
    }
    private func hint(for tool: FileTool) -> FileMintTextKey {
        switch tool {
        case .copyNames: .copyNamesSettingsHint
        case .copyPaths: .copyPathsSettingsHint
        case .move: .moveSettingsHint
        case .permanentDelete: .deleteSettingsHint
        case .airDrop: .airDropHint
        case .desktopAlias: .desktopAliasHint
        }
    }
}

import FileMintCore
import SwiftUI

/// The same settings surface runs in an isolated fixture without a preferences store.
struct FileToolsSettingsView: View {
    @Binding var preferences: FileToolsPreferences
    let language: AppLanguage
    private func text(_ key: FileMintTextKey) -> String { FileMintStrings.text(key, language: language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PreferenceRow(title: text(.enableFileTools), detail: text(.fileToolsOffHint)) {
                    Toggle(text(.enableFileTools), isOn: $preferences.isEnabled)
                        .labelsHidden().accessibilityIdentifier("fileTools.enabled")
                }.mintSurface()
                VStack(spacing: 0) {
                    ForEach(FileTool.allCases, id: \.self) { tool in
                        if tool != FileTool.allCases.first { Divider().padding(.horizontal, 17) }
                        toolRow(tool).padding(17)
                    }
                }.mintSurface(padding: 0)
                    .disabled(!preferences.isEnabled)
                    .saturation(preferences.isEnabled ? 1 : 0)
                    .opacity(preferences.isEnabled ? 1 : 0.5)
            }.toggleStyle(.switch).controlSize(.small).tint(FileMintStyle.accent).padding(1)
        }
    }

    private func toolRow(_ tool: FileTool) -> some View {
        let enabled = preferences.isToolEnabled(tool)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if let image = FileToolAppearance.image(for: tool, size: 18) {
                    Image(nsImage: image).resizable().frame(width: 18, height: 18).accessibilityHidden(true)
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
                    .frame(width: language.resolved() == .chinese ? 119 : 138)
                    .disabled(!enabled).accessibilityIdentifier("fileTools.\(tool.rawValue).mainMenu")
                Toggle(text(tool.title), isOn: Binding(get: { enabled }, set: { preferences.setEnabled($0, for: tool) }))
                    .labelsHidden().accessibilityIdentifier("fileTools.\(tool.rawValue)")
            }
            if tool == .move {
                PreferenceRow(title: text(.moveHereMenuPosition)) {
                    positionPicker(selection: $preferences.moveHereInMainMenu, label: text(.moveHereMenuPosition))
                        .frame(width: language.resolved() == .chinese ? 119 : 138)
                        .accessibilityIdentifier("fileTools.moveHere.mainMenu")
                }.font(.system(size: 11)).padding(.leading, 32).disabled(!enabled)
            } else if tool == .permanentDelete {
                PreferenceRow(title: text(.deleteConfirmation)) {
                    Picker(text(.deleteConfirmation), selection: $preferences.deleteConfirmation) {
                        Text(text(.deleteRequireConfirmation)).tag(DeleteConfirmation.required)
                        Text(text(.deleteSilently)).tag(DeleteConfirmation.silent)
                    }.labelsHidden().pickerStyle(.menu).frame(maxWidth: 180)
                        .accessibilityIdentifier("fileTools.deleteConfirmation")
                }.padding(.leading, 32).disabled(!enabled)
            }
        }
    }

    private func positionPicker(selection: Binding<Bool>, label: String) -> some View {
        Picker(label, selection: selection) {
            Text(text(.toolSubmenu)).tag(false)
            Text(text(.toolMainMenu)).tag(true)
        }.labelsHidden().pickerStyle(.menu).tint(.primary).accessibilityLabel(label)
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

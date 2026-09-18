import FileMintCore
import SwiftUI

/// The settings surface also runs in an isolated native QA fixture, without a store.
struct FileToolsSettingsView: View {
    @Binding var preferences: FileToolsPreferences
    let language: AppLanguage

    private func text(_ key: FileMintTextKey) -> String {
        FileMintStrings.text(key, language: language)
    }

    private var placementWidth: CGFloat { language.resolved() == .chinese ? 138 : 164 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    heading(.fileTools)
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(text(.enableFileTools), isOn: $preferences.isEnabled)
                            .font(.system(size: 13, weight: .semibold))
                            .accessibilityIdentifier("fileTools.enabled")
                        Text(text(.fileToolsOffHint))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20)
                    }.toolSettingsGroup()
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        heading(.fileToolsActions)
                        Text(text(.fileToolsActionsHint))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(FileTool.allCases, id: \.self) { tool in
                        toolSection(tool)
                    }
                }
                // Disable the whole subtree, not just the visible pointer targets.
                // This also disables keyboard and accessibility actions on its controls.
                .disabled(!preferences.isEnabled)
                .saturation(preferences.isEnabled ? 1 : 0)
                .opacity(preferences.isEnabled ? 1 : 0.6)
            }
            .toggleStyle(.checkbox)
            .tint(.mint)
            .padding(1)
        }
    }

    private func heading(_ key: FileMintTextKey) -> some View {
        Text(text(key)).font(.headline).accessibilityAddTraits(.isHeader)
    }

    private func toolSection(_ tool: FileTool) -> some View {
        let enabled = preferences.isToolEnabled(tool)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Toggle(isOn: Binding(
                        get: { preferences.isToolEnabled(tool) },
                        set: { preferences.setEnabled($0, for: tool) }
                    )) {
                        HStack(spacing: 9) {
                            if let image = FileToolAppearance.image(for: tool, size: 20) {
                                Image(nsImage: image).resizable().scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .saturation(enabled ? 1 : 0)
                                    .opacity(enabled ? 1 : 0.5)
                                    .accessibilityHidden(true)
                            }
                            Text(text(tool.title))
                                .font(.system(size: 13, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityLabel(text(tool.title))
                    .accessibilityIdentifier("fileTools.\(tool.rawValue)")
                    Text(text(hint(for: tool)))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 20)
                }.frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(text(.toolMenuPosition)).font(.caption).foregroundStyle(.secondary)
                    positionPicker(selection: Binding(
                        get: { preferences.mainMenuTools.contains(tool) },
                        set: { value in
                            if value { preferences.mainMenuTools.insert(tool) }
                            else { preferences.mainMenuTools.remove(tool) }
                        }
                    ), label: "\(text(tool.title)) — \(text(.toolMenuPosition))")
                    .accessibilityIdentifier("fileTools.\(tool.rawValue).mainMenu")
                }
                .frame(width: placementWidth)
                .disabled(!enabled)
            }

            if tool == .move || tool == .permanentDelete {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    if tool == .move {
                        HStack(spacing: 16) {
                            Text(text(.moveHereMenuPosition))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            positionPicker(selection: $preferences.moveHereInMainMenu,
                                           label: text(.moveHereMenuPosition))
                                .frame(width: placementWidth)
                                .accessibilityIdentifier("fileTools.moveHere.mainMenu")
                        }
                        .help(text(.moveItemsHint))
                    } else {
                        HStack(spacing: 16) {
                            Text(text(.deleteConfirmation))
                            Spacer(minLength: 0)
                            Picker(text(.deleteConfirmation), selection: $preferences.deleteConfirmation) {
                                Text(text(.deleteRequireConfirmation)).tag(DeleteConfirmation.required)
                                Text(text(.deleteSilently)).tag(DeleteConfirmation.silent)
                            }
                            .labelsHidden().pickerStyle(.segmented)
                            .frame(width: language.resolved() == .chinese ? 250 : 290)
                            .accessibilityIdentifier("fileTools.deleteConfirmation")
                        }
                        .help(text(.permanentDeleteHint))
                    }
                }
                .font(.system(size: 12))
                .padding(.leading, 20)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.6)
            }
        }.toolSettingsGroup()
    }

    private func positionPicker(selection: Binding<Bool>, label: String) -> some View {
        Picker(label, selection: selection) {
            Text(text(.toolSubmenu)).tag(false)
            Text(text(.toolMainMenu)).tag(true)
        }
        .labelsHidden().pickerStyle(.menu)
        // Menu placement is a regular choice, so keep its value in the
        // system control text color instead of the page's mint accent.
        .tint(.primary)
        .foregroundStyle(.primary)
        .accessibilityLabel(label)
    }

    private func hint(for tool: FileTool) -> FileMintTextKey {
        switch tool {
        case .copyNames: .copyNamesSettingsHint
        case .copyPaths: .copyPathsSettingsHint
        case .move: .moveSettingsHint
        case .permanentDelete: .deleteSettingsHint
        case .airDrop: .airDropHint
        }
    }
}

private extension View {
    func toolSettingsGroup() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
            }
    }
}

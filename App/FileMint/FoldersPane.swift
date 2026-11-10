import FileMintCore
import SwiftUI

struct FoldersPane: View {
    @EnvironmentObject private var model: PreferencesModel
    @State private var selection: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SettingsSection(title: model.text(.finderExtension)) {
                    HStack {
                        Label(model.text(model.extensionEnabled ? .ready : .permissionSetup),
                              systemImage: model.extensionEnabled ? "checkmark.circle.fill" : "info.circle")
                            .foregroundStyle(model.extensionEnabled ? FileMintStyle.accent : Color.secondary)
                        Spacer()
                        Button(model.text(.openExtensionSettings)) { model.openExtensionSettings() }.buttonStyle(MintButtonStyle())
                    }
                    if !model.extensionEnabled {
                        Text(model.text(.finderSetup)).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(model.finderSettingsPath).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSectionTitle(title: model.text(.menuFolders))
                    Text(model.text(.folderHint)).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    List(model.preferences.monitoredFolderURLs, id: \.self, selection: $selection) { url in
                        HStack(spacing: 12) {
                        Image(systemName: "folder").font(.system(size: 18)).foregroundStyle(FileMintStyle.accent)
                        Text((url.path as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1).truncationMode(.middle)
                        }.padding(.vertical, 8).tag(url)
                    }.listStyle(.plain).scrollContentBackground(.hidden).frame(height: 210)
                        .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                    HStack {
                        Button(model.text(.addFolder)) { model.addMonitoredFolder() }
                        Button(model.text(.remove)) {
                            if let selection { model.removeFolder(selection); self.selection = nil }
                        }.disabled(selection == nil)
                        Spacer()
                        Button(model.text(.openWithFolderSettings)) { model.selectedPane = .fileAccess }
                            .accessibilityIdentifier("settings.manageFileAccess")
                    }
                }
            }.padding(1)
        }
    }
}

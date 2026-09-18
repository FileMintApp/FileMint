import FileMintCore
import SwiftUI

struct FoldersPane: View {
    @EnvironmentObject private var model: PreferencesModel
    @State private var selection: URL?
    @State private var showsPrivacyGuide = false

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
                    Text(model.text(.finderSetup)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.text(.menuFolders)).font(.headline).accessibilityAddTraits(.isHeader)
                    Text(model.text(.folderHint)).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    List(model.preferences.monitoredFolderURLs, id: \.self, selection: $selection) { url in
                        HStack(spacing: 12) {
                        Image(systemName: "folder").font(.system(size: 18)).foregroundStyle(FileMintStyle.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text((url.path as NSString).abbreviatingWithTildeInPath)
                                .lineLimit(1).truncationMode(.middle)
                            Text(model.preferences.monitoredFolderBookmarks[url.path] == nil ? model.text(.needsAccess) : model.text(.folderAccessSaved))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        }.padding(.vertical, 8).tag(url)
                    }.listStyle(.plain).scrollContentBackground(.hidden).frame(height: 210)
                        .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                    HStack {
                        Button(model.text(.addFolder)) { model.addMonitoredFolder() }
                        Button(model.text(.authorize)) { model.addMonitoredFolder(initial: selection) }.disabled(selection == nil)
                        Button(model.text(.remove)) {
                            if let selection { model.removeFolder(selection); self.selection = nil }
                        }.disabled(selection == nil)
                    }
                    Text(model.text(.folderAccessReminder)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup(isExpanded: $showsPrivacyGuide) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.text(.fullDiskAccessStatus)).font(.callout.weight(.medium))
                        Text(model.text(.fullDiskAccessStatusHint)).foregroundStyle(.secondary)
                        Text(model.text(.fullDiskAccessEnabledHint))
                        Text(model.text(.fullDiskAccessHint)).foregroundStyle(.secondary)
                        Button(model.text(.openFullDiskAccess)) { model.openFullDiskAccessSettings() }
                    }.font(.caption).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
                } label: {
                    Text(model.text(.fullDiskAccess)).font(.headline)
                }
            }.padding(1)
        }
    }
}

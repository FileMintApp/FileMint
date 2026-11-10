import FileMintCore
import SwiftUI

struct FileAccessPane: View {
    private struct Grant: Hashable {
        let path: String
        let legacy: Bool
    }

    @EnvironmentObject private var model: PreferencesModel
    @State private var writePaths: [String] = []
    @State private var couldNotLoad = false
    @State private var selection: Grant?

    private var grants: [Grant] {
        writePaths.map { Grant(path: $0, legacy: false) }
            + model.preferences.monitoredFolderBookmarks.keys.sorted().map { Grant(path: $0, legacy: true) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SettingsSectionTitle(title: model.text(.directoryWriteAccess))
                Text(model.text(.directoryWriteAuthorizationHint))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if couldNotLoad {
                    Label(model.text(.directoryAccessLoadFailed), systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                List(grants, id: \.self, selection: $selection) { grant in
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text((grant.path as NSString).abbreviatingWithTildeInPath)
                                .lineLimit(1).truncationMode(.middle)
                            Text(model.text(grant.legacy ? .legacyDirectoryAccess : .folderAccessSaved))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "folder.badge.person.crop").foregroundStyle(FileMintStyle.accent)
                    }.padding(.vertical, 6).tag(grant)
                }.listStyle(.plain).scrollContentBackground(.hidden).frame(height: 210)
                    .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
                    .overlay {
                        if grants.isEmpty && !couldNotLoad {
                            Text(model.text(.noDirectoryWriteAccess)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("fileAccess.savedFolders")
                HStack {
                    Button(model.text(.authorizeHomeDirectory)) { model.chooseDirectoryWriteAccess(home: true) }
                        .accessibilityIdentifier("fileAccess.authorizeHome")
                    Button(model.text(.authorizeOtherDirectory)) { model.chooseDirectoryWriteAccess(home: false) }
                        .accessibilityIdentifier("fileAccess.authorizeOther")
                    Spacer()
                    Button(model.text(.removeDirectoryAccess)) {
                        if let selection, model.forgetDirectoryWriteAccess(path: selection.path, legacy: selection.legacy) {
                            self.selection = nil
                        }
                    }.disabled(selection == nil).accessibilityIdentifier("fileAccess.remove")
                }
                Text(model.text(.directoryAccessRemovalHint))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(1)
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: RememberedFileAccess.directoryWritesChanged)) { _ in refresh() }
    }

    private func refresh() {
        do {
            writePaths = try model.rememberedFileAccess.directoryWritePaths()
            couldNotLoad = false
        } catch { couldNotLoad = true }
    }
}

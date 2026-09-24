import AppKit
import FileMintCore
import SwiftUI
import UniformTypeIdentifiers

struct FavoriteLocationsPane: View {
    @EnvironmentObject private var settings: PreferencesModel
    @ObservedObject private var favorites: FavoriteLocationsModel
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var typeFilter: FavoriteLocationKind?
    @State private var groupFilter = "*"
    @State private var selected: Set<UUID> = []
    @State private var editing: FavoriteLocation?
    @State private var editingGroup = false
    @State private var batchGroup = ""
    @State private var draggedID: UUID?

    init(favorites: FavoriteLocationsModel = .shared) {
        self.favorites = favorites
    }

    private enum Filter: String, CaseIterable { case all, pinned, recent, unavailable }
    private var language: AppLanguage { settings.preferences.language }
    private func text(_ key: FavoriteText) -> String { key.text(language) }
    private var groups: [String] { Array(Set(favorites.catalog.items.map(\.group))).sorted() }
    private var rows: [FavoriteLocation] {
        var rows = favorites.catalog.search(query).filter { item in
            (typeFilter == nil || item.kind == typeFilter) &&
                (groupFilter == "*" || item.group == groupFilter) &&
                (filter != .pinned || item.isPinned) &&
                (filter != .recent || item.lastLocatedAt != nil || item.addedAt != nil) &&
                (filter != .unavailable || favorites.unavailableIDs.contains(item.id))
        }
        if filter == .recent {
            rows.sort { max($0.lastLocatedAt ?? .distantPast, $0.addedAt ?? .distantPast) >
                max($1.lastLocatedAt ?? .distantPast, $1.addedAt ?? .distantPast) }
        } else if query.isEmpty {
            let order = Dictionary(uniqueKeysWithValues: favorites.catalog.items.enumerated().map { ($0.element.id, $0.offset) })
            rows.sort { $0.isPinned != $1.isPinned ? $0.isPinned :
                $0.isPinned ? (order[$0.id] ?? 0) < (order[$1.id] ?? 0) :
                $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SettingsSectionTitle(title: text(.savedItems))
                    Text("\(favorites.catalog.items.count)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { favorites.chooseItems(language: language) } label: {
                        Label(text(.choose), systemImage: "plus")
                    }.buttonStyle(MintButtonStyle(primary: true)).disabled(favorites.recoveryRequired)
                }
                if favorites.recoveryRequired {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(text(.damagedHint), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                        Button(text(.recover)) {
                            let alert = NSAlert()
                            alert.alertStyle = .warning
                            alert.messageText = text(.recover)
                            alert.informativeText = text(.recoverConfirm)
                            alert.addButton(withTitle: text(.cancel))
                            alert.addButton(withTitle: text(.recover))
                            guard alert.runModal() == .alertSecondButtonReturn else { return }
                            favorites.backupAndReset(language: language)
                        }.buttonStyle(MintButtonStyle())
                    }.mintSurface()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            TextField(text(.searchPlaceholder), text: $query).textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("favorites.search")
                            Picker(text(.group), selection: $groupFilter) {
                                Text(text(.allGroups)).tag("*")
                                ForEach(groups, id: \.self) { group in
                                    Text(group.isEmpty ? text(.ungrouped) : group).tag(group)
                                }
                            }.settingsMenu(width: 110)
                            Picker(text(.all), selection: $typeFilter) {
                                Text(text(.allTypes)).tag(FavoriteLocationKind?.none)
                                Text(text(.files)).tag(FavoriteLocationKind?.some(.file))
                                Text(text(.folders)).tag(FavoriteLocationKind?.some(.folder))
                            }.settingsMenu(width: 116)
                        }
                        HStack(spacing: 7) {
                            filterButton(.all, label: text(.all))
                            filterButton(.pinned, label: text(.pinned))
                            filterButton(.recent, label: text(.recent))
                            filterButton(.unavailable, label: text(.unavailable))
                            Spacer()
                        }
                        HStack(spacing: 14) {
                            Spacer()
                            Button(text(.clearRecent)) { perform { try favorites.clearRecent() } }
                                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                            Button(text(.checkLocations)) { favorites.checkAllAvailability() }
                                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                                .disabled(favorites.isChecking)
                        }
                        if rows.isEmpty {
                            VStack(spacing: 9) {
                                Image(systemName: "star").font(.system(size: 30)).foregroundStyle(FileMintStyle.accent)
                                Text(text(.emptyTitle)).font(.callout.weight(.medium))
                                Text(text(.emptyHint)).font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity).padding(.vertical, 28).mintSurface()
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(rows) { item in
                                    favoriteRow(item)
                                        .task(id: item.id) { await favorites.checkAvailability(item.id) }
                                    if item.id != rows.last?.id { Divider().padding(.leading, 16) }
                                }
                            }.mintSurface(padding: 0)
                        }
                        if !selected.isEmpty {
                            HStack(spacing: 10) {
                                Text(String(format: text(.selectedCount), selected.count))
                                Spacer()
                                Button(text(favorites.catalog.items.filter { selected.contains($0.id) }.allSatisfy(\.isPinned) ? .unpin : .pin)) {
                                    let allPinned = favorites.catalog.items.filter { selected.contains($0.id) }.allSatisfy { $0.isPinned }
                                    perform { try favorites.setPinned(selected, to: !allPinned); selected.removeAll() }
                                }
                                Button(text(.moveToGroup)) { batchGroup = ""; editingGroup = true }
                                Button(text(.remove)) { perform { try favorites.remove(selected); selected.removeAll() } }
                            }.font(.caption).buttonStyle(MintButtonStyle()).padding(10).mintSurface(padding: 0)
                        }
                    }
                    Text(text(.finderHint)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 12) {
                        PreferenceRow(title: text(.showAddInFinder), detail: text(.emptyHint)) {
                            Toggle(text(.showAddInFinder), isOn: $settings.preferences.favoriteLocations.showAddInFinder)
                                .labelsHidden().toggleStyle(SmallSettingsSwitchStyle())
                                .onChange(of: settings.preferences.favoriteLocations.showAddInFinder) { _ in settings.save() }
                        }
                        Divider()
                        PreferenceRow(title: text(.showListInFinder), detail: text(.finderHint)) {
                            Toggle(text(.showListInFinder), isOn: $settings.preferences.favoriteLocations.showListInFinder)
                                .labelsHidden().toggleStyle(SmallSettingsSwitchStyle())
                                .onChange(of: settings.preferences.favoriteLocations.showListInFinder) { _ in settings.save() }
                        }
                    }.mintSurface()
                    Button(text(.searchAll)) { FavoriteQuickPanelController.shared.show(favorites: favorites, settings: settings) }
                        .buttonStyle(MintButtonStyle())
                }
                if let message = favorites.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let backup = favorites.backupURL {
                    Button(text(.showBackup)) { NSWorkspace.shared.activateFileViewerSelecting([backup]) }
                        .buttonStyle(MintButtonStyle())
                }
            }.padding(1)
            .dropDestination(for: URL.self) { urls, _ in
                perform {
                    let result = try favorites.add(urls)
                    favorites.message = String(format: text(.added), result.added, result.duplicates)
                }
                return !urls.isEmpty
            }
        }
        .sheet(item: $editing) { item in
            FavoriteEditorSheet(item: item, language: language) { name, group in
                perform { try favorites.rename(item.id, to: name); try favorites.setGroup([item.id], to: group) }
            }
        }
        .sheet(isPresented: $editingGroup) {
            VStack(alignment: .leading, spacing: 17) {
                Text(text(.moveToGroup)).font(.headline)
                TextField(text(.group), text: $batchGroup).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button(text(.cancel)) { editingGroup = false }
                    Button(text(.saved)) {
                        perform { try favorites.setGroup(selected, to: batchGroup); selected.removeAll() }
                        editingGroup = false
                    }.buttonStyle(MintButtonStyle(primary: true))
                }
            }.padding(22).frame(width: 360)
        }
        .onChange(of: query) { _ in selected.removeAll() }
        .onChange(of: filter) { _ in selected.removeAll() }
        .onChange(of: typeFilter) { _ in selected.removeAll() }
        .onChange(of: groupFilter) { _ in selected.removeAll() }
    }

    private func filterButton(_ value: Filter, label: String) -> some View {
        Button(label) { filter = value }.buttonStyle(.plain)
            .font(.caption.weight(filter == value ? .medium : .regular))
            .foregroundStyle(filter == value ? FileMintStyle.accent : Color.secondary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(filter == value ? FileMintStyle.selection : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
    }

    private func favoriteRow(_ item: FavoriteLocation) -> some View {
        HStack(spacing: 10) {
            if item.isPinned {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary).frame(width: 15, height: 25)
                    .onDrag {
                        draggedID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }.accessibilityHidden(true)
            }
            Toggle(item.name, isOn: Binding(
                get: { selected.contains(item.id) },
                set: { selectedValue in
                    if selectedValue { selected.insert(item.id) }
                    else { selected.remove(item.id) }
                })).labelsHidden().toggleStyle(.checkbox)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable().frame(width: 27, height: 27).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                Text(item.url.deletingLastPathComponent().path).font(.system(size: 10))
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }.frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture(count: 2) { locate(item.id) }
            if favorites.unavailableIDs.contains(item.id) {
                Label(text(.unavailable), systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange)
            } else {
                Text(item.group.isEmpty ? text(.ungrouped) : item.group)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Button { perform { try favorites.setPinned([item.id], to: !item.isPinned) } } label: {
                Image(systemName: item.isPinned ? "star.fill" : "star")
            }.buttonStyle(.plain).foregroundStyle(item.isPinned ? FileMintStyle.accent : Color.secondary)
                .accessibilityLabel(text(item.isPinned ? .unpin : .pin))
            Menu {
                Button(text(.locate)) { locate(item.id) }
                if item.kind == .file {
                    Button(text(.openFile)) { perform { try favorites.openFile(item.id) } }
                }
                Button(text(.rename)) { editing = item }
                Button(text(.relink)) { favorites.relink(item.id, language: language) }
                if item.isPinned {
                    Button(text(.moveUp)) { perform { try favorites.movePinned(item.id, by: -1) } }
                    Button(text(.moveDown)) { perform { try favorites.movePinned(item.id, by: 1) } }
                }
                Divider()
                Button(text(.remove)) { perform { try favorites.remove([item.id]) } }
            } label: { Image(systemName: "ellipsis").frame(width: 23, height: 25) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .accessibilityLabel("\(item.name) — \(text(.rename))")
        }.padding(12)
            .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                guard item.isPinned, let sourceID = draggedID,
                      let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let value = object as? String, UUID(uuidString: value) == sourceID else { return }
                    DispatchQueue.main.async {
                        perform { try favorites.movePinned(sourceID, to: item.id) }
                        draggedID = nil
                    }
                }
                return true
            }
    }

    private func locate(_ id: UUID) {
        perform { try favorites.locate(id) }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() }
        catch { favorites.message = error.localizedDescription }
    }
}

private struct FavoriteEditorSheet: View {
    let item: FavoriteLocation
    let language: AppLanguage
    let save: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var group: String

    init(item: FavoriteLocation, language: AppLanguage, save: @escaping (String, String) -> Void) {
        self.item = item
        self.language = language
        self.save = save
        _name = State(initialValue: item.name)
        _group = State(initialValue: item.group)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(FavoriteText.rename.text(language)).font(.headline)
            TextField(FavoriteText.title.text(language), text: $name).textFieldStyle(.roundedBorder)
            TextField(FavoriteText.group.text(language), text: $group).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(FavoriteText.cancel.text(language)) { dismiss() }
                Button(FavoriteText.saved.text(language)) { save(name, group); dismiss() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(MintButtonStyle(primary: true))
            }
        }.padding(22).frame(width: 380)
    }
}

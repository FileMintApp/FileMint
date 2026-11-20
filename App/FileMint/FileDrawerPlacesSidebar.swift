import AppKit
import FileMintCore
import SwiftUI

@MainActor
struct FileDrawerPlacesSidebar: View {
    let model: FileDrawerModel
    let favorites: FavoriteLocationsModel
    let activePlace: FileDrawerPlace?
    let currentRoot: URL?
    let showsHints: Bool
    let chinese: Bool
    let didChoose: () -> Void
    @State private var savedFolders: [FavoriteLocation] = []
    @State private var hasLoadedFolders = false

    var body: some View {
        let activeFavorite = savedFolders.first { $0.url.path == currentRoot?.path }?.id
        VStack(alignment: .leading, spacing: 6) {
            Button(action: model.showPlacesMenu) {
                Text(chinese ? "位置" : "Locations").font(.headline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(FileDrawerCommand.goToPlaceMenu.title(chinese))
            .accessibilityIdentifier("drawer.places.menu")
            .help(FileDrawerCommand.goToPlaceMenu.hint(for: FileDrawerCommand.goToPlaceMenu.title(chinese), shown: showsHints))
            ScrollViewReader { reader in
                ScrollView {
                    sidebarRows(activeFavorite: activeFavorite)
                }
                .onReceive(favorites.$catalog) { catalog in
                    let next = model.sidebarFolders(in: catalog)
                    let previousIDs = Set(savedFolders.map(\.id))
                    savedFolders = next
                    if hasLoadedFolders, !favorites.isLoading, let added = next.first(where: { !previousIDs.contains($0.id) }) {
                        Task { @MainActor in reader.scrollTo(added.id) }
                    }
                    hasLoadedFolders = true
                }
                .onChange(of: activeFavorite) { if let id = $0 { reader.scrollTo(id) } }
            }
            Divider()
            let add = model.text("Add Folder…", "添加文件夹…")
            Button(action: model.chooseSidebarFolder) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus").frame(width: 23)
                    Text(add).lineLimit(1)
                }.frame(minHeight: 29)
            }.buttonStyle(.borderless).accessibilityLabel(add).help(add)
                .accessibilityIdentifier("drawer.places.add")
        }
    }

    private func sidebarRows(activeFavorite: UUID?) -> some View {
        LazyVStack(alignment: .leading, spacing: 3) {
            ForEach(FileDrawerPlace.allCases, id: \.self) { place in
                let title = place.title(chinese)
                row(title, symbol: place.symbol, selected: activeFavorite == nil && activePlace == place,
                    help: FileDrawerCommand.place(place).hint(for: title, shown: showsHints),
                    id: "drawer.place." + place.rawValue) {
                    model.openPlace(place)
                }
            }
            if !savedFolders.isEmpty {
                Divider().padding(.vertical, 4)
                Text(chinese ? "我的文件夹" : "Saved Folders")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(savedFolders) { folder in
                    row(folder.name, symbol: "folder", selected: activeFavorite == folder.id,
                        help: folder.url.path, id: "drawer.place.favorite." + folder.id.uuidString) {
                        model.goFavorite(folder.id)
                    }.id(folder.id)
                }
            }
        }.padding(.trailing, 3)
    }

    private func row(_ title: String, symbol: String, selected: Bool, help: String, id: String,
                     activate: @escaping () -> Void) -> some View {
        Button {
            activate()
            didChoose()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 16)).frame(width: 23)
                    .foregroundStyle(FileMintStyle.accent)
                Text(verbatim: title).font(.system(size: 14)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 31, alignment: .leading)
            .contentShape(Rectangle())
            .background(selected ? FileMintStyle.selection : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain).accessibilityLabel(title).help(help)
        .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier(id)
    }
}

private enum DrawerMenuDestination {
    case place(FileDrawerPlace)
    case favorite(UUID)
}

extension FileDrawerModel {
    func sidebarFolders(in catalog: FavoriteLocationsCatalog) -> [FavoriteLocation] {
        let standard = Set(FileDrawerPlace.allCases.map { placeURL($0).path })
        return catalog.items.filter { $0.kind == .folder && !standard.contains($0.url.path) }
    }

    func makePlacesMenu() -> NSMenu {
        let chinese = settings.preferences.language.resolved() == .chinese
        let menu = NSMenu(title: FileDrawerCommand.goToPlaceMenu.title(chinese))
        let folders = sidebarFolders(in: favorites.catalog)
        let activeFavorite = folders.first { $0.url.path == rootURL?.path }?.id
        func add(_ destination: DrawerMenuDestination, _ title: String, symbol: String, selected: Bool, path: String) {
            let item = menu.addItem(withTitle: title, action: #selector(openMenuDestination(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = destination
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            item.state = selected ? .on : .off
            item.toolTip = path
        }
        for place in FileDrawerPlace.allCases {
            add(.place(place), place.title(chinese), symbol: place.symbol,
                selected: activeFavorite == nil && activePlace == place, path: placeURL(place).path)
        }
        if !folders.isEmpty { menu.addItem(.separator()) }
        for folder in folders {
            add(.favorite(folder.id), folder.name, symbol: "folder", selected: folder.id == activeFavorite, path: folder.url.path)
        }
        return menu
    }

    func showPlacesMenu() {
        guard presented, !busy, !interacting, pathMenu == nil, actionPalette == nil,
              let window, window.isKeyWindow, window.attachedSheet == nil, let view = window.contentView else { return }
        let point: NSPoint
        if let event = NSApp.currentEvent, event.window === window,
           event.type == .leftMouseDown || event.type == .leftMouseUp {
            point = view.convert(event.locationInWindow, from: nil)
        } else {
            point = NSPoint(x: 18, y: view.isFlipped ? 42 : view.bounds.height - 42)
        }
        makePlacesMenu().popUp(positioning: nil, at: point, in: view)
    }

    @objc private func openMenuDestination(_ sender: NSMenuItem) {
        guard presented, !busy, !interacting, actionPalette == nil, pathMenu == nil,
              let destination = sender.representedObject as? DrawerMenuDestination else { return }
        switch destination {
        case .place(let place): openPlace(place)
        case .favorite(let id): goFavorite(id)
        }
    }

    func chooseSidebarFolder() {
        pickFolder { [weak self] url in
            guard let self else { return }
            Task { await self.addSidebarFolder(url) }
        }
    }

    func addSidebarFolder(_ url: URL) async {
        do {
            let result = try await favorites.add([url])
            if presented {
                message = String(format: FavoriteText.added.text(settings.preferences.language), result.added, result.duplicates)
            }
        } catch {
            if presented { report(error) }
        }
    }
}

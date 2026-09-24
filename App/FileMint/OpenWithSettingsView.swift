import AppKit
import FileMintCore
import SwiftUI
import UniformTypeIdentifiers

struct OpenWithPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        OpenWithSettingsView(preferences: Binding(get: { model.preferences.openWith }, set: {
            let previous = model.preferences.openWith
            model.preferences.openWith = $0
            if !model.save() { model.preferences.openWith = previous }
        }), language: model.preferences.language, isChoosing: model.isChoosingOpenWithApp,
           addApplication: model.addOpenWithApplications)
    }
}

/// Shared by production and an isolated native UI fixture.
struct OpenWithSettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var preferences: OpenWithPreferences
    let language: AppLanguage
    var isChoosing = false
    let addApplication: () -> Void
    @State private var draggedApplicationID: UUID?
    @State private var dropTargetID: UUID?

    private func text(_ key: FileMintTextKey) -> String { FileMintStrings.text(key, language: language) }
    private var dragAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.18) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if preferences.applications.isEmpty {
                    VStack(alignment: .center, spacing: 14) {
                        Image(systemName: FileToolAppearance.openWithSymbol)
                            .font(.system(size: 30, weight: .light)).foregroundStyle(FileMintStyle.accent)
                            .accessibilityHidden(true)
                        VStack(spacing: 7) {
                            Text(text(.openWithEmptyTitle)).font(.system(size: 15, weight: .medium))
                            Text(text(.openWithEmptyHint)).font(.system(size: 12)).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 340)
                        }
                        addButton.padding(.top, 5)
                    }.frame(maxWidth: .infinity).padding(.vertical, 32).mintSurface()
                } else {
                    HStack {
                        SettingsSectionTitle(title: text(.openWithConfiguredApps))
                        Text("\(preferences.applications.count)").font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        addButton
                    }
                    VStack(spacing: 0) {
                        ForEach(preferences.applications) { app in
                            if app.id != preferences.applications.first?.id { Divider().padding(.horizontal, 17) }
                            let index = preferences.applications.firstIndex(where: { $0.id == app.id }) ?? 0
                            OpenWithApplicationRow(application: app, language: language, placement: Binding(
                                get: { preferences.applications.first(where: { $0.id == app.id })?.placement ?? .submenu },
                                set: { placement in
                                    guard let index = preferences.applications.firstIndex(where: { $0.id == app.id }) else { return }
                                    preferences.applications[index].placement = placement
                                }), canMoveUp: index > 0, canMoveDown: index < preferences.applications.count - 1,
                                moveUp: { preferences.move(app.id, by: -1) },
                                moveDown: { preferences.move(app.id, by: 1) },
                                remove: { preferences.applications.removeAll { $0.id == app.id } },
                                beginDrag: { withAnimation(dragAnimation) { draggedApplicationID = app.id } })
                                .padding(17)
                                .overlay(alignment: .top) {
                                    if isDropTarget(app.id, after: false) { SettingsInsertionIndicator().offset(y: -4) }
                                }
                                .overlay(alignment: .bottom) {
                                    if isDropTarget(app.id, after: true) { SettingsInsertionIndicator().offset(y: 4) }
                                }
                                .zIndex(dropTargetID == app.id ? 1 : 0)
                                .onDrop(of: [UTType.plainText.identifier], isTargeted: Binding(
                                    get: { dropTargetID == app.id },
                                    set: { targeted in
                                        withAnimation(dragAnimation) {
                                            if targeted { dropTargetID = app.id }
                                            else if dropTargetID == app.id { dropTargetID = nil }
                                        }
                                    }
                                )) { providers in
                                    dropApplication(providers, on: app.id)
                                }
                        }
                    }.animation(dragAnimation, value: preferences.applications.map(\.id))
                        .mintSurface(padding: 0)
                    Text(text(.openWithReorderHint)).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 2)
                }
                Label(text(.openWithMenuHint), systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 2)
            }.padding(1)
        }
    }

    private var addButton: some View {
        Button(action: addApplication) { Label(text(.addApplication), systemImage: "plus") }
            .buttonStyle(MintButtonStyle(primary: true)).disabled(isChoosing)
            .accessibilityIdentifier("openWith.add")
    }

    private func dropApplication(_ providers: [NSItemProvider], on targetID: UUID) -> Bool {
        guard let sourceID = draggedApplicationID,
              let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let value = object as? String, UUID(uuidString: value) == sourceID else { return }
            DispatchQueue.main.async {
                withAnimation(dragAnimation) { preferences.move(sourceID, to: targetID) }
            }
        }
        withAnimation(dragAnimation) {
            draggedApplicationID = nil
            dropTargetID = nil
        }
        return true
    }

    private func isDropTarget(_ targetID: UUID, after: Bool) -> Bool {
        guard dropTargetID == targetID, let draggedApplicationID,
              let source = preferences.applications.firstIndex(where: { $0.id == draggedApplicationID }),
              let target = preferences.applications.firstIndex(where: { $0.id == targetID }),
              source != target else { return false }
        return (source < target) == after
    }
}

private struct OpenWithApplicationRow: View {
    let application: OpenWithApplication
    let language: AppLanguage
    @Binding var placement: OpenWithMenuPlacement
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void
    let beginDrag: () -> Void
    @State private var icon: NSImage?
    @State private var location = ""
    @State private var unavailable = false

    private func text(_ key: FileMintTextKey) -> String { FileMintStrings.text(key, language: language) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .frame(width: 16, height: 28).contentShape(Rectangle())
                .onDrag {
                    beginDrag()
                    return NSItemProvider(object: application.id.uuidString as NSString)
                }
                .help(text(.openWithReorderHint)).accessibilityHidden(true)
            Group {
                if let icon { Image(nsImage: icon).resizable() }
                else { Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary) }
            }.frame(width: 32, height: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(application.name).font(.system(size: 12, weight: .medium))
                    .lineLimit(1).truncationMode(.middle).help(application.name)
                if unavailable {
                    Label(text(.openWithUnavailable), systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(location).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).help(location)
                }
            }.font(.system(size: 10)).frame(maxWidth: .infinity, alignment: .leading)
            Picker(text(.toolMenuPosition), selection: $placement) {
                Text(text(.openWithSubmenu)).tag(OpenWithMenuPlacement.submenu)
                Text(text(.toolMainMenu)).tag(OpenWithMenuPlacement.main)
            }.settingsMenu(width: language.resolved() == .chinese ? 119 : 138)
                .accessibilityLabel("\(application.name) — \(text(.toolMenuPosition))")
                .accessibilityIdentifier("openWith.\(application.id).placement")
            HStack(spacing: 2) {
                Button(action: moveUp) { Image(systemName: "chevron.up").frame(width: 17, height: 28) }
                    .disabled(!canMoveUp)
                    .help(text(.moveUp))
                    .accessibilityLabel("\(text(.moveUp)) \(application.name)")
                    .accessibilityIdentifier("openWith.\(application.id).moveUp")
                Button(action: moveDown) { Image(systemName: "chevron.down").frame(width: 17, height: 28) }
                    .disabled(!canMoveDown)
                    .help(text(.moveDown))
                    .accessibilityLabel("\(text(.moveDown)) \(application.name)")
                    .accessibilityIdentifier("openWith.\(application.id).moveDown")
            }.buttonStyle(.plain).foregroundStyle(.secondary)
            Button(action: remove) {
                Image(systemName: "minus.circle").font(.system(size: 15)).frame(width: 24, height: 28)
            }.buttonStyle(.plain).foregroundStyle(.secondary)
                .help(String(format: text(.openWithRemove), application.name))
                .accessibilityLabel(String(format: text(.openWithRemove), application.name))
                .accessibilityIdentifier("openWith.\(application.id).remove")
        }
        .task(id: application) { await refreshPresentation() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshPresentation() }
        }
    }

    private func refreshPresentation() async {
        let app = application
        let resolved = await Task.detached(priority: .utility) { () -> URL? in
            do {
                let url = try OpenWithApplicationAccess.resolve(app)
                let started = url.startAccessingSecurityScopedResource()
                defer { if started { url.stopAccessingSecurityScopedResource() } }
                try OpenWithApplicationAccess.validate(app, at: url)
                return url
            } catch { return nil }
        }.value
        guard !Task.isCancelled else { return }
        if let url = resolved {
            let started = url.startAccessingSecurityScopedResource()
            defer { if started { url.stopAccessingSecurityScopedResource() } }
            icon = FileToolAppearance.applicationImage(at: url, size: 32)
            location = url.deletingLastPathComponent().path
            unavailable = false
        } else {
            icon = nil
            unavailable = true
        }
    }
}

extension PreferencesModel {
    func addOpenWithApplications() {
        guard !isChoosingOpenWithApp else { return }
        let panel = NSOpenPanel()
        panel.title = text(.addApplication)
        panel.message = text(.openWithChooseHint)
        panel.prompt = text(.addApplication)
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        isChoosingOpenWithApp = true
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self else { return }
            guard response == .OK else { self.isChoosingOpenWithApp = false; return }
            let selected = panel.urls
            Task { @MainActor in
                defer { self.isChoosingOpenWithApp = false }
                do {
                    // Validate the entire choice before changing configuration.
                    let apps = try await Task.detached(priority: .userInitiated) {
                        try selected.map(OpenWithApplicationAccess.capture)
                    }.value
                    let previous = self.preferences.openWith
                    for app in apps { self.preferences.openWith.add(app) }
                    if !self.save() { self.preferences.openWith = previous }
                } catch {
                    self.lastError = self.text((error as? OpenWithError)?.messageKey ?? .openWithInvalidApp)
                }
            }
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { completion(panel.runModal()) }
    }
}

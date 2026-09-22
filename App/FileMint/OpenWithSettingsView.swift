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
    @Binding var preferences: OpenWithPreferences
    let language: AppLanguage
    var isChoosing = false
    let addApplication: () -> Void

    private func text(_ key: FileMintTextKey) -> String { FileMintStrings.text(key, language: language) }

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
                            OpenWithApplicationRow(application: app, language: language, placement: Binding(
                                get: { preferences.applications.first(where: { $0.id == app.id })?.placement ?? .submenu },
                                set: { placement in
                                    guard let index = preferences.applications.firstIndex(where: { $0.id == app.id }) else { return }
                                    preferences.applications[index].placement = placement
                                }), remove: { preferences.applications.removeAll { $0.id == app.id } })
                                .padding(17)
                        }
                    }.mintSurface(padding: 0)
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
}

private struct OpenWithApplicationRow: View {
    let application: OpenWithApplication
    let language: AppLanguage
    @Binding var placement: OpenWithMenuPlacement
    let remove: () -> Void
    @State private var icon: NSImage?
    @State private var location = ""
    @State private var unavailable = false

    private func text(_ key: FileMintTextKey) -> String { FileMintStrings.text(key, language: language) }

    var body: some View {
        HStack(spacing: 12) {
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
            Button(action: remove) {
                Image(systemName: "minus.circle").font(.system(size: 15)).frame(width: 24, height: 28)
            }.buttonStyle(.plain).foregroundStyle(.secondary)
                .help(String(format: text(.openWithRemove), application.name))
                .accessibilityLabel(String(format: text(.openWithRemove), application.name))
                .accessibilityIdentifier("openWith.\(application.id).remove")
        }
        .task(id: application) { refreshPresentation() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPresentation()
        }
    }

    private func refreshPresentation() {
        do {
            let url = try OpenWithApplicationAccess.resolve(application)
            let started = url.startAccessingSecurityScopedResource()
            defer { if started { url.stopAccessingSecurityScopedResource() } }
            try OpenWithApplicationAccess.validate(application, at: url)
            icon = FileToolAppearance.applicationImage(at: url, size: 32)
            location = url.deletingLastPathComponent().path
            unavailable = false
        } catch {
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
            defer { self.isChoosingOpenWithApp = false }
            guard response == .OK else { return }
            do {
                // Validate the entire choice before changing configuration.
                let apps = try panel.urls.map(OpenWithApplicationAccess.capture)
                let previous = self.preferences.openWith
                for app in apps { self.preferences.openWith.add(app) }
                if !self.save() { self.preferences.openWith = previous }
            } catch {
                self.lastError = self.text((error as? OpenWithError)?.messageKey ?? .openWithInvalidApp)
            }
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { completion(panel.runModal()) }
    }
}

import FileMintCore
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case status = "Status"
    case locations = "Locations"
    case templates = "Templates"
    case behavior = "Behavior"

    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var model: PreferencesModel
    @State private var selection: SettingsSection? = .status

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Text(section.rawValue)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            detailView
                .padding(24)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .status {
        case .status:
            StatusPane()
        case .locations:
            LocationsPane()
        case .templates:
            TemplatesPane()
        case .behavior:
            BehaviorPane()
        }
    }
}

private struct StatusPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        Form {
            Section("Finder") {
                LabeledContent("Integration") {
                    Text("Finder Sync Extension")
                }

                Button("Open Extension Settings") {
                    model.openExtensionSettings()
                }
            }

            Section("Active Menu") {
                LabeledContent("Templates") {
                    Text("\(model.enabledTemplates.count)")
                }

                LabeledContent("Locations") {
                    Text("\(model.preferences.monitoredFolderURLs.count)")
                }
            }

            if let error = model.lastError {
                Section("Last Error") {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("FileMint")
    }
}

private struct LocationsPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            List {
                ForEach(model.preferences.monitoredFolderURLs, id: \.self) { url in
                    Text(url.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .onDelete { offsets in
                    model.removeMonitoredFolders(at: offsets)
                }
            }

            HStack {
                Button("Add Folder") {
                    model.addMonitoredFolder()
                }
                Spacer()
            }
        }
        .navigationTitle("Locations")
    }
}

private struct TemplatesPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            List {
                ForEach($model.preferences.templates) { $template in
                    HStack {
                        Toggle("", isOn: $template.isEnabled)
                            .labelsHidden()
                            .onChange(of: template.isEnabled) { _ in model.save() }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.displayName)
                            Text(template.suggestedFileName)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }

                        Spacer()

                        Text(template.group)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                Button("Reset Built-ins") {
                    model.resetTemplates()
                }
                Spacer()
            }
        }
        .navigationTitle("Templates")
    }
}

private struct BehaviorPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        Form {
            Section("Naming") {
                Picker("When File Exists", selection: $model.preferences.collisionStrategy) {
                    Text("Auto Increment").tag(NameCollisionStrategy.increment)
                    Text("Fail").tag(NameCollisionStrategy.fail)
                }
                .onChange(of: model.preferences.collisionStrategy) { _ in model.save() }
            }

            Section("After Creation") {
                Toggle("Reveal Created File", isOn: $model.preferences.revealAfterCreation)
                    .onChange(of: model.preferences.revealAfterCreation) { _ in model.save() }

                Toggle("Favorites First", isOn: $model.preferences.favoritesFirst)
                    .onChange(of: model.preferences.favoritesFirst) { _ in model.save() }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Behavior")
    }
}

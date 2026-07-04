import FileMintCore
import SwiftUI

private enum SettingsSection: CaseIterable, Identifiable {
    case status
    case locations
    case templates
    case behavior

    var id: Self { self }

    var titleKey: FileMintTextKey {
        switch self {
        case .status:
            return .status
        case .locations:
            return .locations
        case .templates:
            return .templates
        case .behavior:
            return .behavior
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: PreferencesModel
    @State private var selection: SettingsSection? = .status

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Text(model.text(section.titleKey))
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
            Section(model.text(.finder)) {
                LabeledContent(model.text(.integration)) {
                    Text(model.text(.finderSyncExtension))
                }
            }

            Section(model.text(.permissionSetup)) {
                ForEach(Array(model.permissionGuideSteps.enumerated()), id: \.element.id) { offset, step in
                    PermissionStepRow(number: offset + 1, step: step)
                }

                Button(model.text(.openExtensionSettings)) {
                    model.openExtensionSettings()
                }
            }

            Section(model.text(.activeMenu)) {
                LabeledContent(model.text(.templates)) {
                    Text("\(model.enabledTemplates.count)")
                }

                LabeledContent(model.text(.locations)) {
                    Text("\(model.preferences.monitoredFolderURLs.count)")
                }
            }

            if let error = model.lastError {
                Section(model.text(.lastError)) {
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

private struct PermissionStepRow: View {
    let number: Int
    let step: PermissionGuideStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                Text(step.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
                Button(model.text(.addFolder)) {
                    model.addMonitoredFolder()
                }
                Spacer()
            }
        }
        .navigationTitle(model.text(.locations))
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
                            Text(model.templateDisplayName(for: template))
                            Text(template.suggestedFileName)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }

                        Spacer()

                        Text(model.templateGroupName(for: template))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Button {
                                model.moveTemplate(id: template.id, by: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!model.canMoveTemplate(id: template.id, by: -1))
                            .help(model.text(.moveUp))

                            Button {
                                model.moveTemplate(id: template.id, by: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!model.canMoveTemplate(id: template.id, by: 1))
                            .help(model.text(.moveDown))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove { offsets, destination in
                    model.moveTemplates(fromOffsets: offsets, toOffset: destination)
                }
            }

            HStack {
                Button(model.text(.resetBuiltIns)) {
                    model.resetTemplates()
                }
                Spacer()
            }
        }
        .navigationTitle(model.text(.templates))
    }
}

private struct BehaviorPane: View {
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        Form {
            Section(model.text(.language)) {
                Picker(model.text(.language), selection: $model.preferences.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: model.preferences.language) { _ in model.save() }
            }

            Section(model.text(.naming)) {
                Picker(model.text(.whenFileExists), selection: $model.preferences.collisionStrategy) {
                    Text(model.text(.autoIncrement)).tag(NameCollisionStrategy.increment)
                    Text(model.text(.fail)).tag(NameCollisionStrategy.fail)
                }
                .onChange(of: model.preferences.collisionStrategy) { _ in model.save() }
            }

            Section(model.text(.afterCreation)) {
                Toggle(model.text(.revealCreatedFile), isOn: $model.preferences.revealAfterCreation)
                    .onChange(of: model.preferences.revealAfterCreation) { _ in model.save() }

                Toggle(model.text(.favoritesFirst), isOn: $model.preferences.favoritesFirst)
                    .onChange(of: model.preferences.favoritesFirst) { _ in model.save() }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(model.text(.behavior))
    }
}

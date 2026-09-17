import AppKit
import FileMintCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: PreferencesModel
    @EnvironmentObject private var updater: UpdateModel
    @FocusState private var focusedPane: PreferencesModel.Pane?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.text(model.selectedPane.title)).font(.system(size: 25, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(model.text(model.selectedPane.subtitle))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(28)
                Divider().padding(.horizontal, 28)
                page.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if let error = model.lastError {
                    Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled)
                        .padding([.horizontal, .bottom], 28)
                }
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 840, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshStatus()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("FileMint").font(.headline)
                    Text(model.text(.settingsLabel)).font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 20)
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(PreferencesModel.Pane.allCases) { pane in
                        SettingsSidebarButton(title: model.text(pane.title), symbol: pane.symbol,
                                              isSelected: model.selectedPane == pane,
                                              isFocused: focusedPane == pane) {
                            model.selectedPane = pane
                            focusedPane = pane
                        }
                        .focusable()
                        .modifier(SidebarFocusEffect())
                        .focused($focusedPane, equals: pane)
                        .accessibilityIdentifier("settings.\(pane.rawValue)")
                    }
                }.padding(.horizontal, 12).padding(.vertical, 4)
            }
            .onMoveCommand { direction in
                guard let focusedPane,
                      let index = PreferencesModel.Pane.allCases.firstIndex(of: focusedPane) else { return }
                let offset: Int
                switch direction {
                case .up: offset = -1
                case .down: offset = 1
                default: return
                }
                let panes = PreferencesModel.Pane.allCases
                let next = max(0, min(panes.count - 1, index + offset))
                self.focusedPane = panes[next]
                model.selectedPane = panes[next]
            }
            VStack(alignment: .leading, spacing: 14) {
                if let update = updater.update, model.selectedPane != .about {
                    Button { model.selectedPane = .about } label: {
                        Label("\(model.text(.availableVersion)) \(update.version.description)", systemImage: "arrow.down.circle")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                    }.buttonStyle(.plain).foregroundStyle(Color.accentColor)
                }
                Button { model.newFile() } label: {
                    HStack {
                        Text(model.text(.customNewFile))
                        Spacer()
                        Text("⌘N").foregroundStyle(.secondary)
                    }.padding(.vertical, 3)
                }.keyboardShortcut("n").controlSize(.large)
                Divider()
                Text(model.text(.sourceAvailable)).font(.caption2).foregroundStyle(.secondary)
                Text("FileMint \(updater.currentVersion)").font(.caption2).foregroundStyle(.tertiary)
            }.padding(16)
        }.frame(width: 208).background(.regularMaterial)
    }

    @ViewBuilder private var page: some View {
        switch model.selectedPane {
        case .general: GeneralPane()
        case .creation: CreationSettingsPane()
        case .fileTypes: TypesPane()
        case .folders: FoldersPane()
        case .about: AboutPane()
        }
    }
}

private struct SettingsSidebarButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let isFocused: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var mint: Color { Color(nsColor: .systemMint) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? mint : Color.secondary)
                Text(title).font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? mint.opacity(colorScheme == .dark ? 0.13 : 0.10)
                          : Color.primary.opacity(isHovered ? 0.045 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(mint.opacity(isFocused ? 0.55 : isSelected ? 0.20 : 0),
                                  lineWidth: isFocused ? 1 : 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SidebarFocusEffect: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}

extension PreferencesModel.Pane {
    var title: FileMintTextKey {
        switch self {
        case .general: .general
        case .creation: .creationSettings
        case .fileTypes: .templatesAndTypes
        case .folders: .finderAndFolders
        case .about: .about
        }
    }

    var subtitle: FileMintTextKey {
        switch self {
        case .general: .generalSettingsHint
        case .creation: .creationSettingsHint
        case .fileTypes: .fileTypeHint
        case .folders: .finderFoldersHint
        case .about: .productTagline
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .creation: "doc.badge.plus"
        case .fileTypes: "doc.on.doc"
        case .folders: "folder"
        case .about: "info.circle"
        }
    }
}

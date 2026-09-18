import AppKit
import FileMintCore
import SwiftUI

struct ContentView: View {
    var launchResourceTool: (ResourceTool) -> Void = { FileOperationCoordinator.shared.chooseImages(for: $0) }
    @EnvironmentObject private var model: PreferencesModel
    @EnvironmentObject private var updater: UpdateModel
    @FocusState private var focusedPane: PreferencesModel.Pane?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(FileMintStyle.line).frame(width: 0.7)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Text(model.selectedPane.groupTitle(model.preferences.language))
                    Text("/").foregroundStyle(.tertiary)
                    Text(model.text(model.selectedPane.title))
                    Spacer()
                    Image(systemName: model.selectedPane.symbol).foregroundStyle(.tertiary)
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, 30).frame(height: 48)
                Rectangle().fill(FileMintStyle.line).frame(height: 0.7)
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.text(model.selectedPane.title)).font(.system(size: 25, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(model.selectedPane.subtitleText(model.preferences.language))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 30).padding(.top, 28).padding(.bottom, 23)
                page.padding(.horizontal, 30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if let error = model.lastError {
                    Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled)
                        .padding([.horizontal, .bottom], 28)
                }
                HStack(spacing: 6) {
                    Label(InterfaceText.localOnly.text(model.preferences.language), systemImage: "checkmark.shield")
                    Spacer()
                    Text("FileMint \(updater.currentVersion)").foregroundStyle(.tertiary)
                }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 30).padding(.vertical, 18)
            }.background(FileMintStyle.background)
        }
        .frame(minWidth: 840, minHeight: 600).tint(FileMintStyle.accent)
        .ignoresSafeArea(.container, edges: .top)
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
                    Text("FileMint").font(.system(size: 18, weight: .semibold))
                    Text(model.text(.productTagline)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 20).padding(.top, 54).padding(.bottom, 28)
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(PreferencesModel.Pane.allCases) { pane in
                        if pane == .fileTypes || pane == .fileTools || pane == .general {
                            Text(pane.groupTitle(model.preferences.language))
                                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12).padding(.top, pane == .fileTypes ? 0 : 20)
                                .padding(.bottom, 4)
                                .accessibilityAddTraits(.isHeader)
                        }
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
                }.keyboardShortcut("n").buttonStyle(MintButtonStyle())
                Button { model.selectedPane = .folders } label: {
                    HStack(spacing: 6) {
                        Circle().fill(model.extensionEnabled ? FileMintStyle.accent : Color.secondary).frame(width: 5, height: 5)
                        Text((model.extensionEnabled ? InterfaceText.enabledFinder : .disabledFinder).text(model.preferences.language))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain)
            }.padding(16)
        }.frame(width: 202).background(.regularMaterial)
    }

    @ViewBuilder private var page: some View {
        switch model.selectedPane {
        case .general: GeneralPane()
        case .creation: CreationSettingsPane()
        case .fileTypes: TypesPane()
        case .folders: FoldersPane()
        case .fileTools: FileToolsPane()
        case .resourceTools: ResourceToolsPane(launchTool: launchResourceTool)
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

    private var mint: Color { FileMintStyle.accent }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? mint : Color.secondary)
                Text(title).font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? FileMintStyle.strong : Color.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11).frame(height: 36)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? FileMintStyle.selection : isHovered ? FileMintStyle.soft : Color.clear)
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
    func groupTitle(_ language: AppLanguage) -> String {
        switch self {
        case .fileTypes, .creation: InterfaceText.fileCreation.text(language)
        case .fileTools, .resourceTools: FileMintStrings.text(.extensions, language: language)
        default: InterfaceText.preferences.text(language)
        }
    }

    func subtitleText(_ language: AppLanguage) -> String {
        switch self {
        case .general: InterfaceText.generalSubtitle.text(language)
        case .creation: InterfaceText.creationSubtitle.text(language)
        case .fileTypes: InterfaceText.typesSubtitle.text(language)
        case .folders: InterfaceText.foldersSubtitle.text(language)
        case .fileTools: InterfaceText.filesSubtitle.text(language)
        case .resourceTools: InterfaceText.resourceSubtitle.text(language)
        case .about: FileMintStrings.text(.productTagline, language: language)
        }
    }
    var title: FileMintTextKey {
        switch self {
        case .general: .general
        case .creation: .creationSettings
        case .fileTypes: .templatesAndTypes
        case .folders: .finderAndFolders
        case .fileTools: .fileTools
        case .resourceTools: .resourceTools
        case .about: .about
        }
    }

    var subtitle: FileMintTextKey {
        switch self {
        case .general: .generalSettingsHint
        case .creation: .creationSettingsHint
        case .fileTypes: .fileTypeHint
        case .folders: .finderFoldersHint
        case .fileTools: .fileToolsHint
        case .resourceTools: .resourceToolsHint
        case .about: .productTagline
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .creation: "doc.badge.plus"
        case .fileTypes: "doc.on.doc"
        case .folders: "folder"
        case .fileTools: "wrench.and.screwdriver"
        case .resourceTools: "photo.on.rectangle"
        case .about: "info.circle"
        }
    }
}

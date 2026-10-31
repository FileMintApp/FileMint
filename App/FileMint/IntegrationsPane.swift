import AppKit
import FileMintCore
import SwiftUI

@MainActor
struct IntegrationsPane: View {
    @ObservedObject private var settings: PreferencesModel
    @ObservedObject private var state: IntegrationsModel
    init(settings: PreferencesModel, favorites: FavoriteLocationsModel) {
        self.settings = settings
        if let existing = settings.integrationsState { state = existing }
        else {
            let value = IntegrationsModel(settings: settings, favorites: favorites)
            settings.integrationsState = value
            state = value
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                if !state.isSupported {
                    Label(ExternalInvocationError.unsupportedSystemVersion.message(state.language), systemImage: "info.circle")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("integrations.systemRequirement")
                }
                SettingsSection(title: state.text("Start with a workflow", "从一个常用场景开始")) {
                    scenario(.projectNote, title: state.text("New project note", "新建项目笔记"),
                        detail: state.text("Configure a text template and folder. Enter only the note name each day.", "配置文本模板和目录，日常只输入笔记名称。"))
                    Divider()
                    scenario(.workflowText, title: state.text("Save workflow text", "保存工作流生成的文本"),
                        detail: state.text("Pass an earlier Shortcuts action's text directly into a draft.", "把快捷指令上一步的文本直接带入草稿。"))
                    Divider()
                    scenario(.quickSearch, title: state.text("Show Quick Search", "显示快捷搜索"),
                        detail: state.text("Open or focus search without changing an unfinished query.", "直接显示或聚焦搜索，保留未完成的查询。"))
                }
                if let guide = state.guide { guidance(guide) }
                SettingsSection(title: state.text("Tools and custom commands", "工具与自定义命令")) {
                    HStack {
                        Label(state.text("Native Shortcuts actions", "原生快捷指令动作"), systemImage: "square.stack.3d.up")
                        Spacer()
                        Button(state.text("Set up example…", "设置示例动作…")) { state.start(.projectNote, tool: .shortcuts) }
                            .accessibilityIdentifier("integrations.setupShortcuts")
                        Button(state.text("Open Shortcuts", "打开快捷指令")) { state.openShortcuts() }
                            .accessibilityIdentifier("integrations.openShortcuts")
                    }.disabled(!state.isSupported)
                    Divider()
                    HStack {
                        Label("Raycast", systemImage: "command")
                        Spacer()
                        Button(state.text("Create command…", "创建启动命令…")) { state.start(.projectNote, tool: .raycast) }
                            .accessibilityIdentifier("integrations.createCommand")
                    }.disabled(!state.isSupported)
                    Divider()
                    HStack {
                        Button(state.text("Custom command…", "自定义命令…")) { state.start(.custom, tool: .url) }
                            .disabled(!state.isSupported)
                            .accessibilityIdentifier("integrations.customCommand")
                        Spacer()
                        Button(state.text("Global shortcut settings", "全局快捷键设置")) { settings.selectedPane = .general }
                            .accessibilityIdentifier("integrations.globalShortcutSettings")
                    }
                }
                SettingsSection(title: state.text("Reuse folder access", "长期复用目录访问")) {
                    Text(state.text("For a repeatable command, use a folder already authorized in Finder & Folders. Adding a folder there saves access and also changes Finder menu scope. A temporary selection may need authorization again after relaunch.",
                        "固定工作流请使用已在“Finder 与文件夹”中授权的目录。在那里添加目录会保存访问权限，也会调整 Finder 菜单范围；临时选择的位置在重启后可能需要再次授权。"))
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(settings.text(.finderAndFolders)) { settings.selectedPane = .folders }
                }
                DisclosureGroup(state.text("Limits and help", "限制与帮助")) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(state.text("These actions open drafts. Only Create writes a file. An unfinished draft is preserved when another request arrives.", "这些入口只打开草稿，只有点击创建才写入文件；新请求不会覆盖未完成草稿。"))
                        Text(state.text("Links are limited to 16 KiB, including at most 8 KiB of UTF-8 text. Native Shortcuts accepts up to 1 MiB. Tools may keep their own history; use native parameters for longer or sensitive text.", "完整链接限 16 KiB，其中文本最多 8 KiB UTF-8；原生快捷指令最多 1 MiB。调用工具可能保留自己的历史，较长或敏感文本优先使用原生参数。"))
                        Text(state.text("Requires macOS 13.3 or later and a logged-in interactive desktop. Raycast is installed separately. Template and folder IDs belong to this Mac; reconfigure them when sharing commands.", "需要 macOS 13.3 及以上和可交互的已登录桌面；Raycast 需另行安装。模板和收藏 ID 属于本机，分享命令时需重新配置。"))
                    }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 8)
                }
                if let error = state.error { Text(error.message).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
            }.padding(1)
        }
        .background(IntegrationWindowReader { state.attachOwner($0) }.frame(width: 0, height: 0))
    }

    private func scenario(_ scenario: IntegrationScenario, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Button(state.text("Shortcuts…", "快捷指令…")) { state.start(scenario, tool: .shortcuts) }
                    .accessibilityIdentifier("integrations.\(scenario).shortcuts")
                if scenario != .workflowText {
                    Button("Raycast…") { state.start(scenario, tool: .raycast) }
                        .accessibilityIdentifier("integrations.\(scenario).raycast")
                }
            }.controlSize(.small).disabled(!state.isSupported)
        }.padding(.vertical, 3)
    }

    private func guidance(_ tool: IntegrationTool) -> some View {
        SettingsSection(title: state.text("Continue setup", "继续接入")) {
            if tool == .raycast, let url = state.savedURL {
                Label(state.text("Script saved to the selected location", "脚本已保存到所选位置"), systemImage: "checkmark.circle")
                Text(url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Text(state.text("1. In Raycast Settings → Extensions → Script Commands, add the folder containing this script.", "1. 在 Raycast 设置 → Extensions → Script Commands 中添加脚本所在目录。"))
                Text(state.text("2. Search for “\(state.config.title)”.", "2. 在 Raycast 搜索“\(state.config.title)”。")
                    + (state.config.nameMode == .runtime ? state.text(" Enter only the file name.", " 只需填写文件名。") : state.text(" Run it without additional input.", " 无需额外输入，直接运行。")))
            } else if tool == .url {
                Label(state.text("Link copied", "链接已复制"), systemImage: "checkmark.circle")
                Text(state.text("Use the link in a workflow or tool that opens URLs. It carries the configuration shown below.", "在支持打开 URL 的工具或工作流中使用此链接，配置已包含在链接中。"))
            } else {
                Text(state.text("1. Open Shortcuts, create a shortcut, search FileMint and add the native action.", "1. 打开快捷指令，新建工作流，搜索 FileMint 并添加原生动作。"))
                if state.config.scenario == .quickSearch {
                    Text(state.text("2. Add Show Quick Search. It has no parameters.", "2. 添加“显示快捷搜索”，无需参数。"))
                } else if state.config.scenario == .workflowText {
                    Text(state.text("2. Choose Open File Draft, set a fixed filename and text template, then choose Specified Text and connect the earlier action's text output. Choose Empty Content for an intentionally empty file.", "2. 添加“打开文件草稿”，配置固定名称和文本模板，将初始内容设为“指定文本”，连接上一步的文本输出；需要空白文件时选择“空内容”。"))
                } else {
                    Text(state.text("2. Choose Open File Draft, select an enabled Markdown/text template and a fixed save location. Set Filename to Ask Each Time; leave content on Template Content.", "2. 添加“打开文件草稿”，选择启用的 Markdown/文本模板及固定位置；文件名设为“每次均询问”，初始内容保留“模板内容”。"))
                }
                Button(state.text("Open Shortcuts", "打开快捷指令")) { state.openShortcuts() }
            }
            Text(state.config.scenario == .quickSearch
                 ? state.text("Run it and check that the search field is ready for typing.", "运行后核对搜索框已可直接输入。")
                 : state.text("3. Review the filename, exact template, folder and content in FileMint. Choose Create to save, or Cancel to create nothing.", "3. 在 FileMint 核对名称、精确模板、位置和内容；点击创建才保存，取消不产生文件。"))
            HStack {
                Button(state.config.scenario == .quickSearch ? state.text("Preview search locally", "本机预览搜索") : state.text("Test local link", "本机测试链接")) { state.testLocally() }
                if tool != .shortcuts { Button(state.text("Return to editor", "返回编辑")) { state.returnToEditor() } }
                if state.testReceived { Label(state.text("FileMint received this test", "FileMint 已收到本次测试请求"), systemImage: "checkmark.circle") }
            }
            Text(state.text("Local testing verifies this Mac's route only. It does not prove that a third-party command was imported or that a file was created.", "本机测试只验证本机路由，不代表第三方已导入命令或文件已创建。"))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }.font(.system(size: 12))
    }
}

@MainActor
struct LauncherGeneratorView: View {
    @ObservedObject var state: IntegrationsModel
    @FocusState private var previewFocused: Bool
    @State private var showLink = false
    private func label(_ en: String, _ zh: String) -> String { state.text(en, zh) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text(label("Create Launcher Command", "创建启动命令")).font(.system(size: 21, weight: .semibold))
                Text(state.config.scenario == .quickSearch ? label("Open or focus Quick Search. No file is created by this action.", "直接显示或聚焦快捷搜索，此动作不创建文件。")
                     : state.config.nameMode == .runtime ? label("Enter a name in Raycast, review the configured draft, then create.", "在 Raycast 输入名称，检查已配置的草稿，然后创建。")
                     : label("Review the prepared name, template and location before creating.", "创建前检查已带入的名称、模板和位置。"))
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(22)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field(label("Command name", "命令名称")) { TextField(label("Command name", "命令名称"), text: $state.config.title).textFieldStyle(.roundedBorder) }
                    Picker(label("Use with", "使用方式"), selection: $state.config.tool) {
                        Text("Raycast").tag(IntegrationTool.raycast)
                        Text(label("General URL", "通用链接")).tag(IntegrationTool.url)
                    }.pickerStyle(.segmented)
                    .onChange(of: state.config.tool) { tool in
                        if tool == .url, state.config.nameMode == .runtime { state.config.nameMode = .fixed }
                    }
                    if state.config.scenario != .quickSearch {
                        field(label("File template", "文件模板")) {
                            Picker(label("File template", "文件模板"), selection: $state.config.templateID) {
                                Text(state.config.scenario == .projectNote ? label("Choose a text template…", "选择文本模板…") : label("FileMint default", "FileMint 默认模板")).tag(String?.none)
                                ForEach(state.templates.filter { state.config.scenario != .projectNote || $0.document == nil }) { template in
                                    Text(FileMintStrings.templateDisplayName(for: template, language: state.language) + " · ." + template.fileExtension).tag(Optional(template.id))
                                }
                            }.labelsHidden()
                            error("template")
                        }
                        field(label("Save location", "保存位置")) {
                            Picker(label("Save location", "保存位置"), selection: $state.config.location) {
                                Text(label("FileMint default", "FileMint 默认位置")).tag(IntegrationLocation.defaultLocation)
                                Text(label("Specified folder", "选择目录")).tag(IntegrationLocation.directory)
                                Text(label("Favorite folder", "常用目录")).tag(IntegrationLocation.favorite)
                                Text(label("Choose in FileMint", "每次在 FileMint 中选择")).tag(IntegrationLocation.ask)
                            }.labelsHidden()
                            if state.config.location == .directory {
                                HStack {
                                    Text(state.config.directory?.path ?? label("No folder selected", "尚未选择目录")).font(.caption).textSelection(.enabled)
                                    Spacer()
                                    Button(label("Choose…", "选择…")) { state.chooseDirectory() }
                                }
                            } else if state.config.location == .favorite {
                                Picker(label("Favorite folder", "常用目录"), selection: $state.config.favoriteID) {
                                    Text(label("Choose a saved folder…", "选择已保存的目录…")).tag(UUID?.none)
                                    ForEach(state.folderFavorites) { item in Text(item.name + " · " + item.url.deletingLastPathComponent().lastPathComponent).tag(Optional(item.id)) }
                                }.labelsHidden()
                            }
                            Text(label("A binding does not save permission. Use an already authorized folder for daily reuse.", "绑定位置不会保存新权限；日常复用请选用已有授权的目录。"))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            error("location")
                        }
                        field(label("Filename", "文件名")) {
                            Picker(label("Filename", "文件名"), selection: $state.config.nameMode) {
                                if state.config.tool == .raycast { Text(label("Enter in Raycast", "在 Raycast 运行时填写")).tag(IntegrationNameMode.runtime) }
                                Text(label("Fixed name", "固定名称")).tag(IntegrationNameMode.fixed)
                                Text(label("Template default", "沿用模板默认名称")).tag(IntegrationNameMode.automatic)
                            }.labelsHidden()
                            if state.config.nameMode == .fixed { TextField(label("Filename", "文件名"), text: $state.config.fileName).textFieldStyle(.roundedBorder) }
                            error("filename")
                        }
                        DisclosureGroup(label("Initial content and advanced options", "初始内容与自定义选项"), isExpanded: $state.config.advanced) {
                            VStack(alignment: .leading, spacing: 11) {
                                Picker(label("Content", "内容"), selection: $state.config.bodyMode) {
                                    Text(label("Template content", "模板内容")).tag(IntegrationBodyMode.templateDefault)
                                    Text(label("Specified text", "指定文本")).tag(IntegrationBodyMode.text)
                                    Text(label("Empty content", "空内容")).tag(IntegrationBodyMode.empty)
                                }.labelsHidden()
                                if state.config.bodyMode == .text {
                                    PlainTextEditor(text: $state.config.text, label: label("Initial content", "初始内容"))
                                        .frame(minHeight: 105)
                                    Text(label("Text is included in the link and exported script.", "文本会包含在链接及导出文件中。"))
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                error("content")
                            }.padding(.top, 10)
                        }
                    }
                    DisclosureGroup(label("View link", "查看链接"), isExpanded: $showLink) {
                        Text((try? state.link()) ?? label("Complete the fields to generate a link.", "完成配置后显示链接。"))
                            .font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    }
                    error("general")
                }.padding(22)
            }.disabled(state.isExporting)
            Divider()
            HStack {
                Button(label("Cancel", "取消")) { state.cancelConfiguration() }.keyboardShortcut(.cancelAction)
                Spacer()
                if state.config.scenario != .quickSearch {
                    Button(label("Preview draft", "预览草稿")) { state.preview() }.focusable().focused($previewFocused)
                }
                Button(state.config.tool == .raycast ? label("Export Raycast Script…", "导出 Raycast 脚本…") : label("Copy Link", "复制链接")) {
                    if state.config.tool == .raycast { state.exportRaycast() } else { state.copyLink() }
                }.buttonStyle(MintButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
            }.controlSize(.regular).disabled(state.isExporting).padding(18)
        }
        .tint(FileMintStyle.accent).buttonStyle(MintButtonStyle()).background(FileMintStyle.background)
        .onChange(of: state.previewFocus) { _ in previewFocused = true }
    }
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.system(size: 12, weight: .medium)); content() }
    }
    @ViewBuilder private func error(_ field: String) -> some View {
        if state.error?.field == field { Text(state.error!.message).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
    }
}

@MainActor
private struct IntegrationWindowReader: NSViewRepresentable {
    let found: (NSWindow) -> Void
    func makeNSView(context: Context) -> Reader { Reader(found: found) }
    func updateNSView(_ view: Reader, context: Context) {}
    final class Reader: NSView {
        let found: (NSWindow) -> Void
        init(found: @escaping (NSWindow) -> Void) { self.found = found; super.init(frame: .zero) }
        required init?(coder: NSCoder) { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if let window { found(window) } }
    }
}

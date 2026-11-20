import AppKit
import FileMintCore
import SwiftUI

struct FileDrawerPathAnchor: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        if let anchor = nextValue() { value = anchor }
    }
}

/// A single full-width path row. Each label is a destination and has a secondary browse action.
struct FileDrawerPathBar: View {
    @ObservedObject var model: FileDrawerModel
    let directory: URL

    var body: some View {
        HStack(spacing: 5) {
            ScrollViewReader { reader in
                ScrollView(.horizontal) {
                    HStack(spacing: 1) {
                        ForEach(Array(model.pathComponents.enumerated()), id: \.element.id) { index, component in
                            if index > 1 {
                                Text("/").foregroundStyle(.tertiary).accessibilityHidden(true)
                            }
                            componentButton(component, at: index)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .onAppear { reader.scrollTo(directory, anchor: .trailing) }
                .onChange(of: directory) { reader.scrollTo($0, anchor: .trailing) }
            }
            Button(action: model.copyDirectoryPath) {
                Image(systemName: "doc.on.doc").frame(width: 26, height: 27)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(model.text("Copy full path", "拷贝完整路径"))
            .accessibilityIdentifier("drawer.path.copy")
            .help(directory.path)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(directory.path)
        .accessibilityIdentifier("drawer.path.full")
        .anchorPreference(key: FileDrawerPathAnchor.self, value: .bounds) { $0 }
    }

    private func componentButton(_ component: FileDrawerPathComponent, at index: Int) -> some View {
        let browse = model.text("Browse Folder Contents…", "浏览文件夹内容…")
        let browseContents = { _ = model.showPathMenu(component) }
        return Button { model.goToPathComponent(component) } label: {
            HStack(spacing: 3) {
                if !component.isAuthorized {
                    Image(systemName: "lock").font(.system(size: 11))
                }
                Text(verbatim: component.title).lineLimit(1)
            }
            .padding(.horizontal, 4).frame(minHeight: 27).contentShape(Rectangle())
            .background(component.url == directory || model.pathMenu?.component.id == component.id
                        ? FileMintStyle.selection : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .id(component.id)
        .fixedSize()
        .font(.system(size: 13))
        .buttonStyle(.plain)
        .contextMenu { Button(browse, action: browseContents) }
        .accessibilityLabel(component.url.path)
        .accessibilityAction(named: Text(browse), browseContents)
        .accessibilityIdentifier("drawer.path.go.\(index)")
        .help(model.text("Go to this folder. Control-click to browse its contents.",
                         "前往此文件夹。按住 Control 点按可浏览文件夹内容。"))
        .disabled(model.busy || model.interacting)
    }
}

/// Kept in the panel's own window so an input field, menu tracking or the sheet
/// presented for a restricted component cannot trigger loss of the owning panel.
struct FileDrawerPathDropdown: View {
    @ObservedObject var model: FileDrawerModel
    let menu: FileDrawerPathMenu
    let availableHeight: CGFloat
    @State private var query = ""
    @State private var highlighted: URL?
    @FocusState private var focusAuthorize: Bool

    var body: some View {
        let matches = matching(menu.entries)
        let current = matches.first(where: { $0.url == highlighted }) ?? matches.first
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(menu.component.title, systemImage: menu.component.isAuthorized ? "folder" : "lock")
                    .font(.headline).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button { model.closePathMenu(menu.id) } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(model.text("Close folder menu", "关闭文件夹菜单"))
                    .accessibilityIdentifier("drawer.path.dismiss")
            }
            if menu.component.isAuthorized {
                QuickSearchInputField(text: Binding(get: { query }, set: { query = $0; highlighted = nil }),
                    placeholder: model.text("Filter files and folders", "筛选文件和文件夹"),
                    move: { delta in
                        let live = liveMatches()
                        guard !live.isEmpty else { return }
                        let index = live.firstIndex(where: { $0.url == highlighted }) ?? 0
                        highlighted = live[min(live.count - 1, max(0, index + delta))].url
                    }, submit: {
                        let live = liveMatches()
                        if let item = live.first(where: { $0.url == highlighted }) ?? live.first {
                            model.choosePathItem(item, in: menu.id)
                        }
                    }, cancel: { model.closePathMenu(menu.id) }, onCreate: {
                        $0.setAccessibilityIdentifier("drawer.path.search")
                        $0.setAccessibilityLabel(model.text("Filter files and folders", "筛选文件和文件夹"))
                    })
                    .frame(height: 29)
                if menu.isLoading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(model.text("Loading folder…", "正在读取文件夹…"))
                    }.font(.body)
                } else if let error = menu.error {
                    Text(error).font(.body).fixedSize(horizontal: false, vertical: true)
                } else if matches.isEmpty {
                    Text(query.isEmpty ? model.text("Folder is empty", "文件夹为空")
                         : model.text("No matching items", "没有匹配的项目"))
                        .font(.body).foregroundStyle(.secondary)
                } else {
                    ScrollViewReader { reader in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(matches) { item in
                                    Button { model.choosePathItem(item, in: menu.id) } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                                                .frame(width: 22).foregroundStyle(FileMintStyle.accent)
                                            Text(verbatim: item.name).lineLimit(1).truncationMode(.middle)
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, 6).frame(height: 31)
                                        .contentShape(Rectangle())
                                        .background(item.url == current?.url ? FileMintStyle.selection : .clear,
                                                    in: RoundedRectangle(cornerRadius: 5))
                                    }
                                    .buttonStyle(.plain)
                                    .id(item.url)
                                    .accessibilityHint(item.isDirectory ? model.text("Enter folder", "进入文件夹")
                                                       : model.text("Select file in drawer", "在抽屉中定位文件"))
                                    .accessibilityIdentifier("drawer.path.item.\(item.name)")
                                }
                            }
                        }
                        .frame(height: min(max(38, availableHeight - 135), CGFloat(min(matches.count, 8)) * 32))
                        .onChange(of: current?.url) { url in if let url { reader.scrollTo(url) } }
                    }
                }
            } else {
                Text(model.text("Choose this folder to browse it.", "请在系统窗口中选择此文件夹以浏览其内容。"))
                    .font(.body).foregroundStyle(.secondary)
            }
            Divider()
            Button(menu.component.isAuthorized ? model.text("Go to This Folder", "前往此文件夹")
                   : model.text("Choose This Folder…", "选择此文件夹…")) { model.goToPathComponent(menu.id) }
                .focused($focusAuthorize)
                .accessibilityIdentifier("drawer.path.go")
        }
        .padding(10)
        .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(FileMintStyle.line))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        .onAppear { if !menu.component.isAuthorized { focusAuthorize = true } }
        .onExitCommand { model.closePathMenu(menu.id) }
    }

    private func matching(_ entries: [FileDrawerEntry]) -> [FileDrawerEntry] {
        query.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func liveMatches() -> [FileDrawerEntry] {
        guard let active = model.pathMenu, active.id == menu.id else { return [] }
        return matching(active.entries)
    }
}

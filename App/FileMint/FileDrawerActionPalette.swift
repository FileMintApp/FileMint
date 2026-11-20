import AppKit
import SwiftUI

@MainActor
struct FileDrawerActionPalette: View {
    @ObservedObject var model: FileDrawerModel
    let session: FileDrawerActionSession
    let chinese: Bool
    let showsHints: Bool
    let availableHeight: CGFloat
    @State private var query = ""
    @State private var highlighted: FileDrawerAction?

    private var matches: [FileDrawerAction] {
        let words = query.split(whereSeparator: \.isWhitespace)
        return FileDrawerAction.allCases.filter { action in
            guard action.enabled(model) else { return false }
            let names = action.title(false) + " " + action.title(true)
            return words.allSatisfy { names.localizedStandardContains(String($0)) }
        }
    }

    var body: some View {
        let title = session.items.count == 1 ? session.items[0].name :
            model.text("\(session.items.count) selected items", "已选 \(session.items.count) 项")
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if model.applicationList != nil {
                    Button(action: model.backFromApplications) { Image(systemName: "chevron.backward") }
                        .buttonStyle(.borderless).accessibilityLabel(model.text("Back to Actions", "返回操作"))
                        .accessibilityIdentifier("drawer.openWithBack")
                    Text(model.text("Open With", "打开方式")).font(.headline)
                }
                Text(verbatim: title).lineLimit(1).truncationMode(.middle)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                Button(action: model.closeActionPalette) { Image(systemName: "xmark.circle") }
                    .buttonStyle(.borderless).accessibilityLabel(model.text("Close Actions", "关闭操作面板"))
            }.padding(.horizontal, 5)
            if let page = model.applicationList {
                FileDrawerApplicationPicker(model: model, page: page, availableHeight: availableHeight,
                                            showsHints: showsHints, focus: { focus($0, page: page.id) })
                    .id(page.id)
            } else {
                actionRows
            }
        }
        .padding(9)
        .font(.system(size: 14))
        .background {
            RoundedRectangle(cornerRadius: 11).fill(FileMintStyle.surface)
                .shadow(color: .black.opacity(0.20), radius: 9, y: 3)
        }
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(FileMintStyle.line))
        .onExitCommand {
            if model.applicationList != nil { model.backFromApplications() }
            else { model.closeActionPalette() }
        }
    }

    @ViewBuilder private var actionRows: some View {
        let rows = matches
        let selected = highlighted ?? rows.first
        Group {
            if rows.isEmpty {
                Text(model.text("No matching actions", "没有匹配的操作"))
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityIdentifier("drawer.noMatchingActions")
            } else {
                ScrollViewReader { reader in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(rows, id: \.self) { action in
                                Button { run(action) } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: action.symbol).frame(width: 20)
                                        Text(action.title(chinese)).lineLimit(1).truncationMode(.tail)
                                        Spacer(minLength: 2)
                                        if showsHints {
                                            Group {
                                                if selected == action { Text("↩") }
                                                else if let binding = FileDrawerCommand.bindings.first(where: { $0.paletteAction == action }) {
                                                    Text(binding.keys)
                                                }
                                            }.font(.system(size: 12)).foregroundStyle(.secondary).accessibilityHidden(true)
                                        }
                                    }
                                    .padding(.horizontal, 7).frame(minHeight: 31)
                                    .contentShape(Rectangle())
                                    .background(selected == action ? FileMintStyle.selection : .clear,
                                                in: RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain).id(action)
                                .accessibilityAddTraits(selected == action ? .isSelected : [])
                                .accessibilityIdentifier("drawer.action." + action.identifier)
                            }
                        }
                    }
                    .onChange(of: selected) { if let action = $0 { reader.scrollTo(action) } }
                }
                .frame(height: min(CGFloat(rows.count) * 33 - 2, 260, max(32, availableHeight - 94)))
            }
            Divider()
            QuickSearchInputField(text: Binding(get: { query }, set: { query = $0; highlighted = nil }),
                placeholder: model.text("Search actions", "搜索操作"), move: move, submit: submit,
                cancel: model.closeActionPalette, onCreate: { field in
                    field.setAccessibilityIdentifier("drawer.actionSearch")
                    field.setAccessibilityLabel(model.text("Search actions", "搜索操作"))
                }, onAttach: { focus($0, page: nil) })
                .frame(height: 28)
                .accessibilityIdentifier("drawer.actionSearch")
        }
    }

    private func focus(_ field: NSSearchField, page: UUID?) {
        guard let window = field.window, window === model.window, model.actionPalette?.id == session.id,
              model.applicationList?.id == page else { return }
        window.makeFirstResponder(field)
        let id = session.id
        DispatchQueue.main.async { [weak field, weak model, weak window] in
            guard model?.actionPalette?.id == id, model?.applicationList?.id == page,
                  let window, window.isKeyWindow, window.attachedSheet == nil,
                  let field, field.window === window, field.currentEditor() == nil else { return }
            window.makeFirstResponder(field)
        }
    }

    private func move(_ delta: Int) {
        let rows = matches
        guard !rows.isEmpty else { return }
        let index = highlighted.flatMap { rows.firstIndex(of: $0) } ?? 0
        highlighted = rows[min(rows.count - 1, max(0, index + delta))]
    }

    private func submit() {
        let rows = matches
        if let action = highlighted ?? rows.first, rows.contains(action) { run(action) }
    }

    private func run(_ action: FileDrawerAction) {
        model.performPaletteAction(action, session: session.id)
    }
}

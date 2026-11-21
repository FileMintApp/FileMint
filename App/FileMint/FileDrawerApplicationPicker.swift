import AppKit
import SwiftUI

@MainActor
struct FileDrawerApplicationPicker: View {
    @Environment(\.fileMintPalette) private var palette
    let model: FileDrawerModel
    let page: FileDrawerApplicationList
    let availableHeight: CGFloat
    let showsHints: Bool
    let focus: (NSSearchField) -> Void
    @State private var query = ""
    @State private var highlighted: Row?

    private enum Row: Hashable {
        case application(URL), other
    }

    private var matches: [FileDrawerOpenWith.Candidate] {
        let apps = page.candidates ?? []
        let terms = query.split(whereSeparator: \.isWhitespace)
        guard !terms.isEmpty else { return apps }
        return apps.filter { app in terms.allSatisfy { app.name.localizedStandardContains(String($0)) } }
    }

    private func selection(in apps: [FileDrawerOpenWith.Candidate]) -> Row? {
        highlighted ?? apps.first.map { .application($0.id) }
    }

    var body: some View {
        let apps = matches
        let current = selection(in: apps)
        VStack(alignment: .leading, spacing: 5) {
            if let error = page.error {
                Text(verbatim: error).font(.callout).accessibilityIdentifier("drawer.openWithError")
            }
            if page.opening || page.candidates == nil {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 40)
            } else if apps.isEmpty {
                Text(query.isEmpty ? model.text("Choose another application below.", "可在下方选择其他应用。")
                     : model.text("No matching applications", "没有匹配的应用"))
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 42)
                    .accessibilityIdentifier("drawer.openWithEmpty")
            } else {
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(apps) { app in
                                let row = Row.application(app.id)
                                Button { model.openWithApplication(app, page: page.id) } label: {
                                    rowLabel(app.name, selected: current == row) {
                                        if let icon = FileToolAppearance.applicationImage(at: app.url, size: 20) {
                                            Image(nsImage: icon).resizable()
                                        } else { Image(systemName: "app") }
                                    }
                                }
                                .buttonStyle(.plain).id(row).help(app.url.path)
                                .accessibilityAddTraits(current == row ? .isSelected : [])
                                .accessibilityIdentifier("drawer.openWithCandidate")
                            }
                        }
                    }
                    .onChange(of: current) { if let row = $0 { reader.scrollTo(row) } }
                }
                .frame(height: min(CGFloat(apps.count) * 33 - 2, 228, max(36, availableHeight - 128)))
            }
            Button { model.chooseOtherApplication(page: page.id) } label: {
                rowLabel(model.text("Other Application…", "其他应用…"), selected: current == .other) {
                    Image(systemName: "folder")
                }
            }
            .buttonStyle(.plain).disabled(page.opening).accessibilityIdentifier("drawer.openWithOther")
            Divider()
            QuickSearchInputField(text: Binding(get: { query }, set: { query = $0; highlighted = nil }),
                placeholder: model.text("Search applications", "搜索应用"), move: move, submit: submit,
                cancel: model.backFromApplications, onCreate: {
                    $0.setAccessibilityIdentifier("drawer.openWithSearch")
                    $0.setAccessibilityLabel(model.text("Search applications", "搜索应用"))
                }, onAttach: focus)
                .frame(height: 28).accessibilityIdentifier("drawer.openWithSearch")
        }
    }

    private func rowLabel(_ title: String, selected: Bool, @ViewBuilder icon: () -> some View) -> some View {
        HStack(spacing: 8) {
            icon().frame(width: 20, height: 20)
            Text(verbatim: title).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            if showsHints && selected { Text("↩").font(.system(size: 12)).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 7).frame(minHeight: 31).contentShape(Rectangle())
        .background(selected ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 5))
    }

    private func move(_ delta: Int) {
        guard !page.opening else { return }
        let apps = matches
        let rows = apps.map { Row.application($0.id) } + [.other]
        let index = selection(in: apps).flatMap { rows.firstIndex(of: $0) } ?? -1
        highlighted = rows[min(rows.count - 1, max(0, index + delta))]
    }

    private func submit() {
        guard !page.opening else { return }
        let apps = matches
        switch selection(in: apps) {
        case .other: model.chooseOtherApplication(page: page.id)
        case let .application(id):
            if let app = apps.first(where: { $0.id == id }) { model.openWithApplication(app, page: page.id) }
        case nil: break
        }
    }
}

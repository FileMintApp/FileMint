import AppKit
import FileMintCore
import SwiftUI

@MainActor
final class FavoriteQuickPanelController: NSObject, NSWindowDelegate {
    static let shared = FavoriteQuickPanelController()
    private var panel: NSPanel?

    func show(favorites: FavoriteLocationsModel = .shared,
              settings: PreferencesModel = .shared) {
        if let panel {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 540, height: 360),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = FavoriteText.title.text(settings.preferences.language)
        panel.contentMinSize = NSSize(width: 430, height: 320)
        panel.backgroundColor = FileMintStyle.backgroundNS
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: FavoriteQuickView(favorites: favorites, settings: settings))
        panel.center()
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() { panel?.close() }
    func windowWillClose(_ notification: Notification) { panel = nil }
}

private struct FavoriteQuickView: View {
    @ObservedObject var favorites: FavoriteLocationsModel
    @ObservedObject var settings: PreferencesModel
    @State private var query = ""
    @State private var selectedIndex = 0

    private var language: AppLanguage { settings.preferences.language }
    private var items: [FavoriteLocation] {
        guard query.isEmpty else { return favorites.catalog.search(query) }
        let quick = favorites.catalog.quickItems(pinnedLimit: 1_000, recentLimit: 1_000)
        let ids = Set(quick.map(\.id))
        return quick + favorites.catalog.items.filter { !ids.contains($0.id) }
    }

    var body: some View {
        let visibleItems = items
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star").foregroundStyle(FileMintStyle.accent)
                Text(FavoriteText.title.text(language)).font(.headline)
                Spacer()
                Button { FavoriteQuickPanelController.shared.close() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
                    .accessibilityLabel(FavoriteText.cancel.text(language))
            }
            ScrollViewReader { proxy in
                QuickSearchInputField(text: $query, placeholder: FavoriteText.searchPlaceholder.text(language),
                    move: { offset in
                        guard !visibleItems.isEmpty else { return }
                        selectedIndex = max(0, min(visibleItems.count - 1, selectedIndex + offset))
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(visibleItems[selectedIndex].id, anchor: .center)
                        }
                    }, submit: locateSelected,
                    cancel: { FavoriteQuickPanelController.shared.close() })
                    .frame(height: 27).accessibilityIdentifier("favorites.quickSearch")
                    .onChange(of: query) { _ in selectedIndex = 0 }
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                            Button { locate(item.id) } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: item.kind == .folder ? "folder" : "doc")
                                        .frame(width: 20).foregroundStyle(FileMintStyle.accent)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name).font(.system(size: 12, weight: .medium))
                                            .lineLimit(1).truncationMode(.middle)
                                        Text(item.url.path).font(.system(size: 10))
                                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                    }
                                    Spacer()
                                    if favorites.unavailableIDs.contains(item.id) {
                                        Label(FavoriteText.unavailable.text(language), systemImage: "exclamationmark.circle")
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                    if item.isPinned { Image(systemName: "star.fill").font(.caption).foregroundStyle(FileMintStyle.accent) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 11).padding(.vertical, 8)
                                    .background(index == selectedIndex ? FileMintStyle.selection : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 7))
                            // Position changes during search; only the catalog
                            // identity can safely key both row reuse and scrolling.
                            }.buttonStyle(.plain).id(item.id)
                                .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                                .contextMenu {
                                    Button(FavoriteText.relink.text(language)) {
                                        Task { await favorites.relink(item.id, language: language) }
                                    }
                                    if item.kind == .file {
                                        Button(FavoriteText.openFile.text(language)) {
                                            Task {
                                                do {
                                                    try await favorites.openFile(item.id)
                                                    FavoriteQuickPanelController.shared.close()
                                                } catch { favorites.message = FavoriteText.locateFailed.text(language) }
                                            }
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            if let message = favorites.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("↑↓  ·  ↩  ·  esc").font(.caption).foregroundStyle(.tertiary)
            }
        }.padding(18).background(FileMintStyle.background)
    }

    private func locateSelected() {
        guard items.indices.contains(selectedIndex) else { return }
        locate(items[selectedIndex].id)
    }

    private func locate(_ id: UUID) {
        guard !favorites.isBusy else { return }
        Task {
            do {
                try await favorites.locate(id)
                FavoriteQuickPanelController.shared.close()
            } catch { favorites.message = FavoriteText.locateFailed.text(language) }
        }
    }
}

struct QuickSearchInputField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let move: (Int) -> Void
    let submit: () -> Void
    let cancel: () -> Void
    var onCreate: ((NSSearchField) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        // Let AppKit's input context consume composition first. The shared action
        // also fires on clear, so its target accepts only a Return key event.
        field.target = context.coordinator
        field.action = #selector(Coordinator.submitFromReturn(_:))
        field.sendsWholeSearchString = true
        field.maximumRecents = 0
        onCreate?(field)
        Task { @MainActor [weak field] in
            await Task.yield()
            guard let field else { return }
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if (field.currentEditor() as? NSTextView)?.hasMarkedText() != true, field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: QuickSearchInputField
        init(_ parent: QuickSearchInputField) { self.parent = parent }
        @objc func submitFromReturn(_ field: NSSearchField) {
            guard let event = NSApp.currentEvent,
                  event.type == .keyDown || event.type == .keyUp,
                  event.keyCode == 36 || event.keyCode == 76,
                  (field.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
            parent.submit()
        }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField,
                  (field.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
            parent.text = field.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy commandSelector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)):
                parent.move(1)
            case #selector(NSResponder.moveUp(_:)):
                parent.move(-1)
            case #selector(NSResponder.insertNewline(_:)):
                parent.submit()
            case #selector(NSResponder.cancelOperation(_:)):
                parent.cancel()
            default:
                return false
            }
            return true
        }
    }
}

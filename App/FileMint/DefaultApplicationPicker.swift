import AppKit
import FileMintCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DefaultApplicationPicker: NSObject, ObservableObject, NSWindowDelegate {
    let type: UTType
    let language: AppLanguage
    @Published private(set) var apps: [DefaultApplicationCandidate]
    @Published private(set) var currentID: String?
    @Published private(set) var selectionID: String?
    @Published private(set) var feedback: String?
    @Published private(set) var isApplying = false
    @Published var query = "" {
        didSet {
            if !results.contains(where: { $0.id == selectionID }) {
                selectionID = results.first(where: { $0.id == currentID })?.id
            }
        }
    }

    private let write: @MainActor (DefaultApplicationCandidate) async throws -> Void
    private var panel: DefaultApplicationPanel?
    private weak var searchField: NSSearchField?
    private var completion: CheckedContinuation<Void, Never>?

    init(type: UTType, language: AppLanguage,
         snapshot: (apps: [DefaultApplicationCandidate], currentID: String?),
         write: @escaping @MainActor (DefaultApplicationCandidate) async throws -> Void) {
        self.type = type; self.language = language; self.write = write
        apps = snapshot.apps; currentID = snapshot.currentID; selectionID = snapshot.currentID
    }

    var typeName: String { type.localizedDescription ?? type.preferredFilenameExtension?.uppercased() ?? type.identifier }
    var results: [DefaultApplicationCandidate] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return apps.filter { $0.matches(text) }
    }
    var canApply: Bool { !isApplying && applicationToApply != nil }
    private var applicationToApply: DefaultApplicationCandidate? {
        results.first { $0.id == selectionID && $0.id != currentID }
    }
    func text(_ key: DefaultApplicationText) -> String { key.text(language) }

    func present() async {
        await withCheckedContinuation { continuation in
            completion = continuation
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
            let rows = max(2, min(apps.count, 4))
            let size = NSSize(width: min(444, visible.width), height: min(CGFloat(196 + rows * 44), visible.height))
            let window = DefaultApplicationPanel(contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = text(.title)
            window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
            window.isMovableByWindowBackground = true; window.isReleasedWhenClosed = false
            window.backgroundColor = FileMintStyle.backgroundNS
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.identifier = NSUserInterfaceItemIdentifier("defaultApplication.panel")
            window.delegate = self
            window.onEscape = { [weak self] in self?.escape() }
            panel = window
            window.contentView = NSHostingView(rootView: DefaultApplicationView(model: self)
                .ignoresSafeArea(.container, edges: .top))
            window.setFrameOrigin(NSPoint(x: visible.midX - window.frame.width / 2,
                                          y: visible.midY - window.frame.height / 2))
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    func registerSearch(_ field: NSSearchField) {
        field.setAccessibilityIdentifier("defaultApplication.search")
        field.isEnabled = !isApplying
        searchField = field
    }

    func select(_ app: DefaultApplicationCandidate) {
        guard !isApplying, selectionID != app.id else { return }
        selectionID = app.id; feedback = nil
    }

    func move(_ delta: Int) {
        guard !isApplying else { return }
        let matches = results
        guard !matches.isEmpty else { return }
        let selectedIndex = matches.firstIndex { $0.id == selectionID }
        let index = selectedIndex.map { min(max(0, $0 + delta), matches.count - 1) }
            ?? (delta > 0 ? 0 : matches.count - 1)
        select(matches[index])
    }

    func escape() {
        guard !isApplying else { return }
        if query.isEmpty { cancel() }
        else { query = ""; panel?.makeFirstResponder(searchField) }
    }

    func cancel() {
        guard !isApplying, panel?.attachedSheet == nil else { return }
        panel?.close()
    }

    func apply() {
        guard !isApplying, let app = applicationToApply else { return }
        feedback = nil; isApplying = true
        searchField?.isEnabled = false
        Task {
            do {
                try await write(app)
                isApplying = false
                panel?.close()
                FavoriteFeedbackController.show(String(format: text(.success), app.name, typeName), symbol: "checkmark.circle")
            } catch {
                isApplying = false
                feedback = DefaultApplicationError.message(for: error, language: language)
                searchField?.isEnabled = true
                panel?.makeFirstResponder(searchField)
            }
        }
    }

    func browse() {
        guard !isApplying, let panel, panel.attachedSheet == nil else { return }
        let picker = NSOpenPanel()
        picker.title = text(.choose); picker.prompt = text(.choose)
        picker.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        picker.allowedContentTypes = [.applicationBundle]
        picker.canChooseDirectories = false; picker.treatsFilePackagesAsDirectories = false
        picker.allowsMultipleSelection = false
        picker.beginSheetModal(for: panel) { [weak self] response in
            guard response == .OK, let url = picker.url, let self else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard DefaultApplicationWorkspace.isCompatible(url, with: type) else {
                feedback = text(.incompatible)
                return
            }
            let snapshot = DefaultApplicationWorkspace.snapshot(for: type)
            guard let app = snapshot.apps.first(where: { $0.id == DefaultApplicationWorkspace.appID(url) }) else {
                feedback = text(.incompatible)
                return
            }
            apps = snapshot.apps; currentID = snapshot.currentID
            query = ""; feedback = nil
            select(app)
            panel.makeFirstResponder(searchField)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { !isApplying && sender.attachedSheet == nil }

    func windowWillClose(_ notification: Notification) {
        panel = nil
        if NSApp.isActive {
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.activate(options: [])
        }
        let continuation = completion
        completion = nil
        continuation?.resume()
    }
}

private final class DefaultApplicationPanel: NSPanel {
    var onEscape: (() -> Void)?
    override func cancelOperation(_ sender: Any?) {
        guard (firstResponder as? NSTextView)?.hasMarkedText() != true else { return }
        onEscape?()
    }
}

private struct DefaultApplicationView: View {
    @ObservedObject var model: DefaultApplicationPicker

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            QuickSearchInputField(text: $model.query, placeholder: model.text(.search), move: model.move,
                submit: model.apply, cancel: model.escape, onCreate: model.registerSearch)
                .frame(height: 27).disabled(model.isApplying)
            Text(String(format: model.text(.compatible), model.results.count))
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            results
            Spacer(minLength: 0)
            if let feedback = model.feedback {
                Text(feedback).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("defaultApplication.feedback")
            }
            Divider()
            footer
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FileMintStyle.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if let suffix = model.type.preferredFilenameExtension, suffix.count <= 5 {
                    Text(suffix.uppercased()).font(.system(size: 11, weight: .semibold))
                } else {
                    Image(systemName: "doc").font(.system(size: 17))
                }
            }
            .frame(width: 42, height: 42)
            .foregroundStyle(FileMintStyle.strong)
            .background(FileMintStyle.selection, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.text(.title)).font(.system(size: 20, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(String(format: model.text(.scope), model.typeName))
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if model.results.isEmpty {
                        Text(model.text(model.apps.isEmpty ? .noApps : .noMatches))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    ForEach(model.results) { app in
                        DefaultApplicationRow(app: app, isCurrent: app.id == model.currentID,
                            isSelected: app.id == model.selectionID, currentLabel: model.text(.current)) { model.select(app) }
                            .id(app.id)
                    }
                }.padding(.trailing, 8)
            }
            .frame(maxHeight: 178)
            .scrollIndicators(.visible)
            .disabled(model.isApplying)
            .accessibilityIdentifier("defaultApplication.results")
            .onChange(of: model.selectionID) { id in if let id { proxy.scrollTo(id) } }
            .onChange(of: model.query) { _ in
                if let first = model.results.first { proxy.scrollTo(first.id, anchor: .top) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(model.text(.other), action: model.browse)
                .buttonStyle(.plain).foregroundStyle(FileMintStyle.strong).font(.system(size: 12))
                .disabled(model.isApplying)
            Spacer(minLength: 6)
            Button(FileInfoText.cancel.text(model.language), action: model.cancel)
                .buttonStyle(MintButtonStyle()).disabled(model.isApplying)
            Button(action: model.apply) {
                HStack(spacing: 6) {
                    if model.isApplying { ProgressView().controlSize(.small) }
                    Text(model.text(model.isApplying ? .applying : .apply))
                }
            }
            .buttonStyle(MintButtonStyle(primary: true)).disabled(!model.canApply)
            .accessibilityIdentifier("defaultApplication.apply")
        }
    }
}

private struct DefaultApplicationRow: View {
    let app: DefaultApplicationCandidate
    let isCurrent: Bool
    let isSelected: Bool
    let currentLabel: String
    let select: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 9) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                    .resizable().aspectRatio(contentMode: .fit).frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1).help(app.name)
                Spacer(minLength: 6)
                if isCurrent {
                    Text(currentLabel).font(.system(size: 10)).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 5))
                }
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? FileMintStyle.strong : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8).frame(height: 42)
            .background(isSelected ? FileMintStyle.selection : hovering ? FileMintStyle.soft : .clear,
                        in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isSelected ? FileMintStyle.accent.opacity(0.5) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

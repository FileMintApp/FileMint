import AppKit
import FileMintCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class FileDrawerBrowserFocus: ObservableObject {
    weak var collection: NSCollectionView?

    func restore(_ model: FileDrawerModel) {
        DispatchQueue.main.async { [weak collection, weak model] in
            guard let model, model.presented, model.pathMenu == nil, model.actionPalette == nil, !model.interacting,
                  let collection, let window = collection.window, window === model.window,
                  window.isKeyWindow, window.attachedSheet == nil else { return }
            window.makeFirstResponder(collection)
        }
    }
}

/// One native collection owns keyboard selection and drag sessions in both layouts.
struct FileDrawerBrowser: NSViewRepresentable {
    @Environment(\.fileMintPalette) private var palette
    @ObservedObject var model: FileDrawerModel
    let entries: [FileDrawerEntry]
    let resultsVersion: Int
    let mode: FileDrawerViewMode
    let chinese: Bool
    let focus: FileDrawerBrowserFocus
    let find: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(model: model, palette: palette) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let collection = DrawerCollection(frame: scroll.contentView.bounds)
        let layout = NSCollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 2
        collection.collectionViewLayout = layout
        collection.autoresizingMask = [.width]
        collection.backgroundColors = [.clear]
        collection.isSelectable = true
        collection.allowsEmptySelection = true
        collection.allowsMultipleSelection = true
        collection.register(DrawerFileCell.self, forItemWithIdentifier: DrawerFileCell.identifier)
        collection.registerForDraggedTypes([Coordinator.dragType])
        collection.setDraggingSourceOperationMask(.move, forLocal: true)
        collection.setDraggingSourceOperationMask([], forLocal: false)
        collection.setAccessibilityIdentifier("drawer.collection")
        collection.owner = context.coordinator
        collection.dataSource = context.coordinator
        collection.delegate = context.coordinator
        scroll.documentView = collection
        focus.collection = collection
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let collection = scroll.documentView as? DrawerCollection else { return }
        collection.find = find
        context.coordinator.applyPalette(palette, to: collection)
        context.coordinator.update(collection: collection, entries: entries, version: resultsVersion, mode: mode, chinese: chinese)
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        coordinator.clearRenameEditor()
        coordinator.finishDrag()
    }

    @MainActor
    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
        fileprivate static let dragType = NSPasteboard.PasteboardType("io.github.daigua.filemint.drawer-session")
        let model: FileDrawerModel
        private(set) var entries: [FileDrawerEntry] = []
        private(set) var chinese = false
        private var mode: FileDrawerViewMode = .list
        private var version: Int?
        private var palette: FileMintPalette
        private var revealVersion: Int
        private var updating = false
        private var dragEntries: [FileDrawerEntry] = []
        private weak var editingCell: DrawerFileCell?

        init(model: FileDrawerModel, palette: FileMintPalette) {
            self.model = model
            self.palette = palette
            revealVersion = model.pathSelectionVersion
        }

        func applyPalette(_ palette: FileMintPalette, to collection: NSCollectionView) {
            guard palette.accentNS != self.palette.accentNS else { return }
            self.palette = palette
            // Repaint the existing rows without resetting selection or an inline edit.
            for case let cell as DrawerFileCell in collection.visibleItems() { cell.applyPalette(palette) }
        }

        func update(collection: NSCollectionView, entries next: [FileDrawerEntry], version: Int, mode: FileDrawerViewMode, chinese: Bool) {
            guard version == model.resultsVersion else { return }
            updating = true
            defer { updating = false }
            if self.version != version || self.mode != mode || self.chinese != chinese {
                // Remove obsolete native indices while the old data is still installed.
                if next.count < entries.count, collection.selectionIndexPaths.contains(where: { $0.item >= next.count }) {
                    collection.selectionIndexPaths = []
                }
                entries = next
                self.version = version
                self.mode = mode
                self.chinese = chinese
                collection.collectionViewLayout?.invalidateLayout()
                collection.reloadData()
            }
            let paths = Set(model.selection.compactMap { url in
                model.visibleIndex(for: url).map { IndexPath(item: $0, section: 0) }
            })
            if collection.selectionIndexPaths != paths { collection.selectionIndexPaths = paths }
            if revealVersion != model.pathSelectionVersion {
                revealVersion = model.pathSelectionVersion
                if paths.count == 1 {
                    collection.layoutSubtreeIfNeeded()
                    collection.scrollToItems(at: paths, scrollPosition: .centeredVertically)
                }
            }
            if let entry = model.renamingEntry, let index = model.visibleIndex(for: entry.url) {
                let path = IndexPath(item: index, section: 0)
                if collection.item(at: path) == nil {
                    collection.scrollToItems(at: [path], scrollPosition: .centeredVertically)
                    collection.layoutSubtreeIfNeeded()
                }
                if let cell = collection.item(at: path) as? DrawerFileCell {
                    if editingCell !== cell { clearRenameEditor(); editingCell = cell }
                    cell.editName(of: entry, model: model, chinese: chinese)
                }
            } else { clearRenameEditor() }
        }

        func clearRenameEditor() {
            editingCell?.endRename()
            editingCell = nil
        }

        private func items(at paths: Set<IndexPath>) -> [FileDrawerEntry] {
            paths.sorted().compactMap { entries.indices.contains($0.item) ? entries[$0.item] : nil }
        }

        func syncSelection(_ collection: NSCollectionView) {
            guard !updating, !model.isSearching, version == model.resultsVersion else { return }
            let urls = Set(items(at: collection.selectionIndexPaths).map(\.url))
            if model.selection != urls { model.selection = urls }
        }

        func handleArrow(_ key: UInt16, in collection: NSCollectionView) {
            guard !model.busy, !model.isSearching, version == model.resultsVersion else { return }
            switch key {
            case 123:
                model.up()
            case 124:
                guard model.selection.count == 1, let item = model.selectedEntries.first, item.canEnterDirectory else { return }
                model.navigate(item.url)
            case 125, 126:
                guard !entries.isEmpty else { return }
                let indices = model.selection.compactMap { model.visibleIndex(for: $0) }
                let next = key == 125 ? min((indices.max() ?? -1) + 1, entries.count - 1)
                    : max((indices.min() ?? entries.count) - 1, 0)
                let path = IndexPath(item: next, section: 0)
                collection.selectionIndexPaths = [path]
                syncSelection(collection)
                collection.scrollToItems(at: [path], scrollPosition: .nearestHorizontalEdge)
            default: break
            }
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { entries.count }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let item = collectionView.makeItem(withIdentifier: DrawerFileCell.identifier, for: indexPath)
            if let cell = item as? DrawerFileCell, entries.indices.contains(indexPath.item) {
                cell.configure(entries[indexPath.item], mode: mode, chinese: chinese)
                cell.applyPalette(palette)
            }
            return item
        }

        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout,
                            sizeForItemAt indexPath: IndexPath) -> NSSize {
            let width = max(1, collectionView.bounds.width)
            if mode != .icons { return NSSize(width: floor(width), height: mode == .compact ? 29 : 42) }
            let columns = max(1, Int(width / 120))
            return NSSize(width: floor((width - CGFloat(columns - 1) * 4) / CGFloat(columns)), height: 100)
        }

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            syncSelection(collectionView)
        }
        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            syncSelection(collectionView)
        }

        func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
            guard !model.busy, !model.isSearching, !model.interacting else { return nil }
            let item = NSPasteboardItem()
            item.setString("move", forType: Self.dragType)
            return item
        }

        func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession,
                            willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
            dragEntries = items(at: indexPaths)
            let urls = Set(dragEntries.map(\.url))
            if model.selection != urls { model.selection = urls }
            model.dragging = true
        }

        func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession,
                            endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation) {
            finishDrag()
        }

        func finishDrag() {
            dragEntries = []
            if model.dragging { model.dragging = false }
        }

        private func destination(_ info: NSDraggingInfo, in collection: NSCollectionView) -> IndexPath? {
            guard (info.draggingSource as? NSCollectionView) === collection, !model.busy, !model.isSearching, !dragEntries.isEmpty else { return nil }
            let point = collection.convert(info.draggingLocation, from: nil)
            guard let path = collection.indexPathForItem(at: point), entries.indices.contains(path.item),
                  entries[path.item].isDirectory, !model.selection.contains(entries[path.item].url),
                  Set(dragEntries.map(\.url)) == model.selection,
                  items(at: collection.selectionIndexPaths) == dragEntries else { return nil }
            return path
        }

        func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo,
                            proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                            dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
            guard let path = destination(draggingInfo, in: collectionView) else { return [] }
            proposedDropIndexPath.pointee = path as NSIndexPath
            proposedDropOperation.pointee = .on
            return .move
        }

        func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo,
                            indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
            guard dropOperation == .on, destination(draggingInfo, in: collectionView) == indexPath else { return false }
            model.moveSelection(to: entries[indexPath.item].url)
            return true
        }
    }
}

@MainActor
private final class DrawerCollection: NSCollectionView {
    weak var owner: FileDrawerBrowser.Coordinator?
    var find: (() -> Void)?
    private var needsInitialFocus = true

    override func setFrameSize(_ size: NSSize) {
        let previousWidth = bounds.width
        super.setFrameSize(size)
        // Recompute the delegate's cell widths after the collection itself resizes.
        if bounds.width != previousWidth { collectionViewLayout?.invalidateLayout() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        guard let window else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(tryInitialFocus),
                                               name: NSWindow.didBecomeKeyNotification, object: window)
        tryInitialFocus()
    }

    @objc private func tryInitialFocus() {
        guard needsInitialFocus else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.needsInitialFocus, let model = self.owner?.model,
                  model.presented, model.pathMenu == nil, model.actionPalette == nil, !model.interacting,
                  let window = self.window, window === model.window, window.isKeyWindow,
                  window.attachedSheet == nil else { return }
            self.needsInitialFocus = false
            if !(window.firstResponder is NSTextView) { window.makeFirstResponder(self) }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let hit = indexPathForItem(at: convert(event.locationInWindow, from: nil))
        super.mouseDown(with: event)
        if event.clickCount == 2, let hit, selectionIndexPaths.contains(hit), let owner {
            owner.syncSelection(self)
            FileDrawerAction.open.run(owner.model)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let owner else { return nil }
        if let path = indexPathForItem(at: convert(event.locationInWindow, from: nil)) {
            if !selectionIndexPaths.contains(path) { selectionIndexPaths = [path] }
        } else {
            selectionIndexPaths = []
        }
        owner.syncSelection(self)
        let menu = NSMenu()
        menu.autoenablesItems = false
        for action in FileDrawerAction.allCases {
            if [.copyPaths, .copy, .trash].contains(action) { menu.addItem(.separator()) }
            let item = NSMenuItem(title: action.title(owner.chinese), action: #selector(performAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = action.rawValue
            item.isEnabled = action.enabled(owner.model)
            menu.addItem(item)
        }
        return menu
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        if let owner, let action = FileDrawerAction(rawValue: sender.tag) { action.run(owner.model) }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder === self, handleCommand(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    private func handleCommand(_ event: NSEvent) -> Bool {
        guard let owner, owner.model.pathMenu == nil, owner.model.actionPalette == nil, !owner.model.interacting,
              window?.attachedSheet == nil, let command = FileDrawerCommand.match(event) else { return false }
        let model = owner.model
        switch command {
        case .find: find?()
        case .selectAll:
            guard !model.isSearching else { return true }
            selectionIndexPaths = Set(owner.entries.indices.map { IndexPath(item: $0, section: 0) })
            owner.syncSelection(self)
        case .newFolder, .newFile, .close, .pin, .up, .togglePlaces, .goToPlaceMenu, .actions, .place:
            return command.runWindowCommand(in: model)
        case .chooseFolder: model.chooseFolder()
        case .refresh: if !model.busy { model.refresh() }
        case .back: if !model.busy { model.back() }
        case .forward: if !model.busy { model.forward() }
        case .iconView: model.setViewMode(.icons)
        case .listView: model.setViewMode(.list)
        case .compactView: model.setViewMode(.compact)
        case .togglePreview:
            if model.previewURL != nil { model.closePreview() } else { FileDrawerAction.preview.run(model) }
        case .escape:
            if model.previewURL != nil { model.closePreview() } else { model.close() }
        case let .file(action): action.run(model)
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard let model = owner?.model else { return super.keyDown(with: event) }
        if let menu = model.pathMenu {
            if event.keyCode == 53 { model.closePathMenu(menu.id) }
            return
        }
        if (123...126).contains(event.keyCode),
           event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
           window?.firstResponder === self {
            if model.presented, !model.interacting, !model.dragging, model.actionPalette == nil, window?.attachedSheet == nil {
                owner?.handleArrow(event.keyCode, in: self)
            }
            return
        }
        if !handleCommand(event) { super.keyDown(with: event) }
    }
}

private final class DrawerCellBackground: NSView {
    var selectionColor = FileMintPalette.mint.selectionNS {
        didSet { if oldValue != selectionColor { needsDisplay = true } }
    }
    var highlighted = false {
        didSet { if oldValue != highlighted { needsDisplay = true } }
    }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = (highlighted ? selectionColor : .clear).cgColor
        }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

private final class DrawerFileCell: NSCollectionViewItem, NSTextFieldDelegate {
    static let identifier = NSUserInterfaceItemIdentifier("io.github.daigua.filemint.drawer.entry")
    private let symbol = NSImageView()
    private let name = NSTextField(labelWithString: "")
    private let size = NSTextField(labelWithString: "")
    private let date = NSTextField(labelWithString: "")
    private var mode: FileDrawerViewMode = .list
    private var renameField: NSTextField?
    private var entry: FileDrawerEntry?
    private weak var renameModel: FileDrawerModel?

    override func loadView() {
        view = DrawerCellBackground()
        view.wantsLayer = true
        view.layer?.cornerRadius = 6
        for field in [name, size, date] {
            field.lineBreakMode = .byTruncatingMiddle
            field.maximumNumberOfLines = 1
            view.addSubview(field)
        }
        name.font = .systemFont(ofSize: 14, weight: .medium)
        size.font = .systemFont(ofSize: 12)
        date.font = .systemFont(ofSize: 12)
        size.textColor = .secondaryLabelColor
        date.textColor = .secondaryLabelColor
        symbol.imageScaling = .scaleProportionallyUpOrDown
        view.addSubview(symbol)
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.cell)
    }

    override var isSelected: Bool { didSet { paintSelection() } }
    override var highlightState: NSCollectionViewItem.HighlightState { didSet { paintSelection() } }

    func applyPalette(_ palette: FileMintPalette) {
        symbol.contentTintColor = palette.accentNS
        (view as? DrawerCellBackground)?.selectionColor = palette.selectionNS
    }

    private func paintSelection() {
        guard isViewLoaded else { return }
        (view as? DrawerCellBackground)?.highlighted = isSelected || highlightState == .asDropTarget
        view.setAccessibilitySelected(isSelected)
    }

    func configure(_ entry: FileDrawerEntry, mode: FileDrawerViewMode, chinese: Bool) {
        if self.entry?.isSameItem(as: entry) != true { endRename() }
        self.entry = entry
        self.mode = mode
        name.stringValue = entry.name
        size.stringValue = entry.isOffline ? (chinese ? "未下载" : "Offline")
            : entry.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—"
        date.stringValue = entry.modified?.formatted(date: .numeric, time: .omitted) ?? "—"
        let icon = Self.icon(for: entry)
        symbol.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        let kind = entry.isDirectory ? (chinese ? "文件夹" : "Folder") : (chinese ? "文件" : "File")
        view.setAccessibilityLabel([entry.name, kind, size.stringValue, date.stringValue].joined(separator: ", "))
        view.toolTip = entry.name
        paintSelection()
        view.needsLayout = true
    }

    func editName(of item: FileDrawerEntry, model: FileDrawerModel, chinese: Bool) {
        guard entry?.isSameItem(as: item) == true else { return }
        if let renameField {
            renameField.currentEditor()?.isEditable = !model.writing
            return
        }
        let input = NSTextField(string: model.renameDraft)
        input.font = name.font
        input.alignment = name.alignment
        input.usesSingleLineMode = true
        input.delegate = self
        input.setAccessibilityIdentifier("drawer.renameField")
        input.setAccessibilityLabel(chinese ? "文件名称" : "File name")
        renameField = input
        renameModel = model
        name.isHidden = true
        view.setAccessibilityElement(false)
        view.addSubview(input)
        view.needsLayout = true
        DispatchQueue.main.async { [weak self, weak input, weak model] in
            guard let self, let input, self.renameField === input, let model,
                  model.renamingEntry?.isSameItem(as: item) == true,
                  let window = input.window, window === model.window, window.makeFirstResponder(input),
                  let editor = input.currentEditor() as? NSTextView else { return }
            let original = item.name as NSString
            let selected = item.isDirectory || original.pathExtension.isEmpty ? item.name : original.deletingPathExtension
            let length = input.stringValue == item.name ? (selected as NSString).length : (input.stringValue as NSString).length
            editor.setSelectedRange(NSRange(location: 0, length: length))
        }
    }

    func endRename() {
        guard let input = renameField else { return }
        renameField = nil
        renameModel = nil
        input.delegate = nil
        if let editor = input.currentEditor() {
            editor.isEditable = true
            if input.window?.firstResponder === editor { input.window?.makeFirstResponder(collectionView) }
        }
        input.removeFromSuperview()
        name.isHidden = false
        view.setAccessibilityElement(true)
        view.needsLayout = true
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let input = notification.object as? NSTextField, input === renameField else { return }
        renameModel?.renameDraft = input.stringValue
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
        guard control === renameField, let model = renameModel, let entry, !textView.hasMarkedText() else { return false }
        switch command {
        case #selector(NSResponder.insertNewline(_:)):
            if !model.busy { model.commitRename(textView.string, of: entry) }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            if !model.writing { model.cancelRename() }
            return true
        default:
            return false
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let input = notification.object as? NSTextField, input === renameField else { return }
        DispatchQueue.main.async { [weak self, weak input] in
            guard let self, let input, self.renameField === input, let model = self.renameModel,
                  !model.writing, input.window?.isKeyWindow == true, input.currentEditor() == nil else { return }
            model.cancelRename()
        }
    }

    private static func icon(for entry: FileDrawerEntry) -> String {
        if entry.isOffline { return "icloud.slash" }
        if entry.isLink { return "link" }
        if entry.isDirectory { return "folder.fill" }
        guard let type = UTType(filenameExtension: entry.url.pathExtension) else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .movie) { return "film" }
        if type.conforms(to: .audio) { return "waveform" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        return "doc.text"
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let width = view.bounds.width
        let height = view.bounds.height
        size.isHidden = mode == .compact
        if mode == .icons {
            symbol.frame = NSRect(x: (width - 38) / 2, y: height - 44, width: 38, height: 38)
            name.frame = NSRect(x: 5, y: height - 69, width: max(0, width - 10), height: 20)
            size.frame = NSRect(x: 5, y: height - 88, width: max(0, width - 10), height: 17)
            name.alignment = .center
            size.alignment = .center
            date.isHidden = true
        } else {
            let showDate = mode == .list && width >= 420
            let dateWidth: CGFloat = showDate ? 88 : 0
            let sizeWidth: CGFloat = mode == .compact || width < 200 ? 0 : min(75, width / 4)
            size.isHidden = sizeWidth == 0
            let iconSize: CGFloat = mode == .compact ? 19 : 23
            symbol.frame = NSRect(x: 7, y: (height - iconSize) / 2, width: iconSize, height: iconSize)
            let start = symbol.frame.maxX + 6
            name.frame = NSRect(x: start, y: (height - 20) / 2, width: max(0, width - start - 12 - dateWidth - sizeWidth), height: 20)
            size.frame = NSRect(x: width - 6 - dateWidth - sizeWidth, y: (height - 17) / 2, width: sizeWidth, height: 17)
            date.frame = NSRect(x: width - 6 - dateWidth, y: (height - 17) / 2, width: dateWidth, height: 17)
            name.alignment = .left
            size.alignment = .right
            date.alignment = .right
            date.isHidden = !showDate
        }
        if let renameField {
            var frame = name.frame.insetBy(dx: -2, dy: -2)
            if mode != .icons {
                frame.size.width = max(0, width - frame.minX - 3)
                date.isHidden = true
                size.isHidden = true
            }
            renameField.frame = frame
        }
    }
}

import AppKit
import FileMintCore

@MainActor
final class CustomFileSavePanelController: NSObject {
    static let shared = CustomFileSavePanelController()

    var hasActiveDraft: Bool { panel != nil || directoryPicker != nil || isCreating }

    private var createButton: NSButton?
    private var cancelButton: NSButton?
    private var isCreating = false
    private var appliedExtension = "txt"
    private var allOptions = FileFormatCatalog.builtInOptions

    private var panel: NSPanel?
    private var directoryPicker: NSOpenPanel?
    private var fileNameField: NSTextField?
    private var destinationPopUpButton: NSPopUpButton?
    private var formatComboBox: NSComboBox?
    private var contentTextView: NSTextView?
    private var locationSelection: CustomFileLocationSelection?
    private var suggestions = FileFormatCatalog.builtInOptions
    private var templates = TemplateCatalog.builtInTemplates
    private var draft = CustomFileDraft()
    private var language: AppLanguage = .english
    private var revealAfterCreation = true
    private var isUpdatingFormatField = false
    private var isUpdatingContentField = false

    private override init() {}

    func focusExistingPanel() -> Bool {
        guard panel != nil else { return false }
        bringPanelForward(selectFileName: false)
        return true
    }

    func present(
        in defaultDirectory: URL,
        preferences: FileMintPreferences,
        templateID: String? = nil
    ) {
        if panel != nil {
            bringPanelForward(selectFileName: false)
            return
        }

        templates = preferences.templates
        language = preferences.language
        revealAfterCreation = preferences.revealAfterCreation
        draft = CustomFileDraft(templates: templates)
        allOptions = FileFormatCatalog.options(from: templates)
        suggestions = allOptions
        if let option = allOptions.first(where: { $0.templateID == templateID }) {
            draft.selectFormat(option, templates: templates)
        }
        appliedExtension = draft.extensionInput
        locationSelection = CustomFileLocationSelection(directoryURL: defaultDirectory)

        let creationPanel = makePanel()
        panel = creationPanel
        refreshDestinationMenu()
        bringPanelForward(selectFileName: true)

    }

    private func makePanel() -> NSPanel {
        let creationPanel = CreationPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        creationPanel.identifier = NSUserInterfaceItemIdentifier(
            "io.github.daigua.filemint.custom-file"
        )
        creationPanel.onCreate = { [weak self] in self?.createRequestedFile(nil) }
        creationPanel.title = FileMintStrings.text(.customNewFile, language: language)
        creationPanel.isReleasedWhenClosed = false
        creationPanel.hidesOnDeactivate = false
        creationPanel.isFloatingPanel = true
        creationPanel.becomesKeyOnlyIfNeeded = false
        creationPanel.level = .modalPanel
        creationPanel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        creationPanel.animationBehavior = .utilityWindow
        creationPanel.delegate = self
        creationPanel.contentView = makeContentView(for: creationPanel)
        creationPanel.initialFirstResponder = fileNameField
        creationPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        creationPanel.standardWindowButton(.zoomButton)?.isHidden = true
        creationPanel.center()
        return creationPanel
    }

    private func makeContentView(for creationPanel: NSPanel) -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let subtitle = wrappingLabel(
            FileMintStrings.text(.customPanelSubtitle, language: language),
            maximumNumberOfLines: 1
        )

        let nameField = NSTextField(string: "Untitled.\(draft.extensionInput)")
        nameField.placeholderString = "Untitled.txt"
        nameField.controlSize = .regular
        nameField.setAccessibilityLabel(FileMintStrings.text(.fileName, language: language))
        nameField.font = .systemFont(ofSize: NSFont.systemFontSize)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.delegate = self
        fileNameField = nameField

        let destinationButton = NSPopUpButton(frame: .zero, pullsDown: false)
        destinationButton.controlSize = .small
        destinationButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        destinationButton.translatesAutoresizingMaskIntoConstraints = false
        destinationPopUpButton = destinationButton

        let comboBox = NSComboBox()
        comboBox.controlSize = .small
        comboBox.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        comboBox.isEditable = true
        comboBox.completes = false
        comboBox.setAccessibilityLabel(FileMintStrings.text(.fileFormat, language: language))
        comboBox.usesDataSource = true
        comboBox.dataSource = self
        comboBox.delegate = self
        comboBox.stringValue = draft.extensionInput
        comboBox.numberOfVisibleItems = min(8, allOptions.count)
        comboBox.translatesAutoresizingMaskIntoConstraints = false
        formatComboBox = comboBox

        let form = NSGridView(views: [
            [formLabel(.fileName), nameField],
            [formLabel(.saveLocation), destinationButton],
            [formLabel(.fileFormat), comboBox]
        ])
        form.rowSpacing = 10
        form.columnSpacing = 12
        form.column(at: 0).width = 94
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).xPlacement = .fill
        form.translatesAutoresizingMaskIntoConstraints = false

        let formatHint = indentedLabel(
            FileMintStrings.text(.formatHint, language: language),
            leadingIndent: 106
        )

        let contentHeader = NSView()
        contentHeader.translatesAutoresizingMaskIntoConstraints = false
        let contentLabel = NSTextField(
            labelWithString: FileMintStrings.text(.initialContent, language: language)
        )
        contentLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        let encodingLabel = NSButton(title: FileMintStrings.text(.paste, language: language), target: self, action: #selector(pasteContent(_:)))
        encodingLabel.bezelStyle = .rounded
        encodingLabel.controlSize = .small
        encodingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentHeader.addSubview(contentLabel)
        contentHeader.addSubview(encodingLabel)

        let scrollView = NSScrollView()
        scrollView.borderType = .lineBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = FileMintTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 118))
        textView.setAccessibilityLabel(FileMintStrings.text(.initialContent, language: language))
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 7, height: 6)
        textView.font = .monospacedSystemFont(ofSize: 12.5, weight: .regular)
        textView.string = draft.content
        textView.delegate = self
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        contentTextView = textView

        let placeholderHint = wrappingLabel(
            FileMintStrings.text(.contentHint, language: language),
            maximumNumberOfLines: 2
        )

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        let cancelButton = NSButton(
            title: FileMintStrings.text(.cancel, language: language),
            target: self,
            action: #selector(cancelPanel(_:))
        )
        self.cancelButton = cancelButton
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        let createButton = NSButton(
            title: FileMintStrings.text(.create, language: language),
            target: self,
            action: #selector(createRequestedFile(_:))
        )
        self.createButton = createButton
        createButton.bezelStyle = .rounded
        createButton.keyEquivalent = "\r"
        let buttonStack = NSStackView(views: [cancelButton, createButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(buttonStack)
        let shortcut = wrappingLabel(FileMintStrings.text(.newFileShortcut, language: language), maximumNumberOfLines: 1)
        shortcut.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(shortcut)
        NSLayoutConstraint.activate([
            shortcut.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            shortcut.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])

        for view in [subtitle, form, formatHint, contentHeader, scrollView, placeholderHint, separator, footer] {
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -18),

            nameField.heightAnchor.constraint(equalToConstant: 26),
            destinationButton.heightAnchor.constraint(equalToConstant: 26),
            comboBox.heightAnchor.constraint(equalToConstant: 26),

            contentLabel.leadingAnchor.constraint(equalTo: contentHeader.leadingAnchor),
            contentLabel.centerYAnchor.constraint(equalTo: contentHeader.centerYAnchor),
            encodingLabel.trailingAnchor.constraint(equalTo: contentHeader.trailingAnchor),
            encodingLabel.centerYAnchor.constraint(equalTo: contentHeader.centerYAnchor),
            contentHeader.heightAnchor.constraint(equalToConstant: 20),

            scrollView.heightAnchor.constraint(equalToConstant: 126),
            separator.heightAnchor.constraint(equalToConstant: 1),
            footer.heightAnchor.constraint(equalToConstant: 32),
            buttonStack.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            buttonStack.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])

        creationPanel.defaultButtonCell = createButton.cell as? NSButtonCell
        return container
    }

    private func formLabel(_ key: FileMintTextKey) -> NSTextField {
        let label = NSTextField(labelWithString: FileMintStrings.text(key, language: language))
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.alignment = .right
        return label
    }

    private func indentedLabel(_ text: String, leadingIndent: CGFloat) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let label = wrappingLabel(text, maximumNumberOfLines: 2)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leadingIndent),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func wrappingLabel(
        _ text: String,
        maximumNumberOfLines: Int
    ) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = maximumNumberOfLines
        return label
    }

    private func bringPanelForward(selectFileName: Bool) {
        guard let panel else {
            return
        }

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        let windowToFocus = panel.attachedSheet ?? panel
        windowToFocus.makeKeyAndOrderFront(nil)
        windowToFocus.orderFrontRegardless()

        if selectFileName, panel.attachedSheet == nil {
            panel.makeFirstResponder(fileNameField)
            fileNameField?.selectText(nil)
        }
    }

    private func refreshDestinationMenu() {
        guard let destinationPopUpButton,
              let directoryURL = locationSelection?.directoryURL else {
            return
        }

        let menu = NSMenu()
        let currentItem = NSMenuItem(
            title: (directoryURL.path as NSString).abbreviatingWithTildeInPath,
            action: nil,
            keyEquivalent: ""
        )
        currentItem.state = .on
        menu.addItem(currentItem)
        menu.addItem(.separator())

        let chooseItem = NSMenuItem(
            title: FileMintStrings.text(.chooseOtherFolder, language: language),
            action: #selector(chooseOtherFolder(_:)),
            keyEquivalent: ""
        )
        chooseItem.target = self
        menu.addItem(chooseItem)

        destinationPopUpButton.menu = menu
        destinationPopUpButton.selectItem(at: 0)
        destinationPopUpButton.toolTip = directoryURL.path
        destinationPopUpButton.setAccessibilityLabel(
            FileMintStrings.text(.saveLocation, language: language)
        )
    }

    @objc private func chooseOtherFolder(_ sender: Any?) {
        guard let panel,
              directoryPicker == nil,
              var selection = locationSelection,
              !selection.isBrowsing else {
            return
        }

        selection.beginBrowsing()
        locationSelection = selection
        refreshDestinationMenu()

        let picker = NSOpenPanel()
        picker.identifier = NSUserInterfaceItemIdentifier(
            "io.github.daigua.filemint.custom-file-location"
        )
        picker.title = FileMintStrings.text(.chooseOtherFolder, language: language)
        picker.directoryURL = selection.directoryURL
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.canCreateDirectories = true
        picker.resolvesAliases = true
        directoryPicker = picker

        picker.beginSheetModal(for: panel) { [weak self] response in
            Task { @MainActor in
                guard let self else {
                    return
                }

                let selectedDirectory = response == .OK ? self.directoryPicker?.url : nil
                self.locationSelection?.finishBrowsing(
                    selectedDirectoryURL: selectedDirectory
                )
                self.directoryPicker = nil
                self.refreshDestinationMenu()
                self.bringPanelForward(selectFileName: false)
            }
        }
    }

    @objc private func cancelPanel(_ sender: Any?) {
        guard !isCreating else { return }
        closePanel(with: .cancel)
    }

    @objc private func createRequestedFile(_ sender: Any?) {
        guard !isCreating, panel?.attachedSheet == nil, directoryPicker == nil else { return }
        guard let directoryURL = locationSelection?.directoryURL,
              let fileName = resolvedFileName() else {
            showError(invalidExtensionError())
            return
        }

        createFile(
            named: fileName,
            in: directoryURL,
            replacingExistingFile: false
        )
    }

    private func resolvedFileName() -> String? {
        guard let fileExtension = draft.normalizedFileExtension,
              let fieldValue = fileNameField?.stringValue else {
            return nil
        }
        return FilenamePolicy.fileName(fieldValue, applyingFileExtension: fileExtension)
    }

    private func createFile(
        named fileName: String,
        in directoryURL: URL,
        replacingExistingFile: Bool
    ) {
        guard !isCreating else { return }
        isCreating = true
        createButton?.isEnabled = false
        cancelButton?.isEnabled = false
        panel?.standardWindowButton(.closeButton)?.isEnabled = false
        let template = FileTemplate(id: "custom", displayName: "Custom", suggestedFileName: fileName,
                                    group: "Custom", content: draft.content, rank: 0)
        let request = FileCreationRequest(destinationDirectory: directoryURL, template: template,
                                          requestedFileName: fileName,
                                          collisionStrategy: replacingExistingFile ? .replace : .fail,
                                          contentMode: draft.hasEditedContent ? .verbatim : .template)
        Task {
            let accessed = directoryURL.startAccessingSecurityScopedResource()
            defer { if accessed { directoryURL.stopAccessingSecurityScopedResource() } }
            let outcome = await Task.detached(priority: .userInitiated) {
                Result { try FileCreationService().createFile(request) }
            }.value
            isCreating = false
            createButton?.isEnabled = true
            cancelButton?.isEnabled = true
            panel?.standardWindowButton(.closeButton)?.isEnabled = true
            switch outcome {
            case .success(let result):
                closePanel(with: .OK)
                if revealAfterCreation { NSWorkspace.shared.activateFileViewerSelecting([result.createdURL]) }
            case .failure(FileMintError.fileAlreadyExists(let url)):
                confirmReplacement(of: url)
            case .failure(let error):
                if FolderAccess.isPermissionError(error) { authorizeForRetry(directoryURL) }
                else { showError(error) }
            }
        }
    }

    private func authorizeForRetry(_ directory: URL) {
        guard let panel else { return }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.directoryURL = directory
        picker.message = FileMintStrings.text(.authorizeFolderHint, language: language)
        picker.prompt = FileMintStrings.text(.allowFolder, language: language)
        picker.beginSheetModal(for: panel) { [weak self] response in
            guard let self, response == .OK, let url = picker.url else { return }
            do { try FolderAccess.persist(url) }
            catch { self.showError(error); return }
            self.locationSelection?.selectDirectory(url)
            self.refreshDestinationMenu()
            // A different folder is a new create request, never an implicit replace.
            self.createRequestedFile(nil)
        }
    }

    @objc private func pasteContent(_ sender: Any?) {
        guard let textView = contentTextView else { return }
        guard let text = NSPasteboard.general.string(forType: .string) else {
            showError(NSError(domain: "FileMint", code: 2, userInfo: [NSLocalizedDescriptionKey:
                FileMintStrings.text(.noClipboardText, language: language)]))
            return
        }
        panel?.makeFirstResponder(textView)
        textView.breakUndoCoalescing()
        textView.insertText(text, replacementRange: textView.selectedRange())
        textView.breakUndoCoalescing()
    }

    private func confirmReplacement(of existingURL: URL) {
        guard let panel else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = FileMintStrings.text(.replaceExistingFileTitle, language: language)
        alert.informativeText = FileMintStrings.replaceExistingFileMessage(
            fileName: existingURL.lastPathComponent,
            language: language
        )
        alert.addButton(withTitle: FileMintStrings.text(.cancel, language: language))
        alert.addButton(withTitle: FileMintStrings.text(.replace, language: language))
        // NSAlert recognizes Cancel and otherwise gives Return to the next
        // button. Pin the non-destructive default explicitly after loading it.
        alert.window.defaultButtonCell = alert.buttons[0].cell as? NSButtonCell
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[0].keyEquivalentModifierMask = []
        alert.buttons[1].keyEquivalent = ""
        alert.beginSheetModal(for: panel) { [weak self] response in
            guard response == .alertSecondButtonReturn else {
                return
            }
            Task { @MainActor in
                self?.createFile(
                    named: existingURL.lastPathComponent,
                    in: existingURL.deletingLastPathComponent(),
                    replacingExistingFile: true
                )
            }
        }
    }

    private func closePanel(with response: NSApplication.ModalResponse) {
        guard let panel else {
            return
        }

        if NSApp.modalWindow === panel {
            NSApp.stopModal(withCode: response)
        }
        panel.close()
    }

    private func updateSuggestions(for query: String) {
        suggestions = FileFormatCatalog.matching(query, in: allOptions)
        formatComboBox?.numberOfVisibleItems = max(1, min(7, suggestions.count))
        formatComboBox?.reloadData()
    }

    private func updateContentField() {
        guard let contentTextView, contentTextView.string != draft.content else {
            return
        }

        isUpdatingContentField = true
        contentTextView.string = draft.content
        isUpdatingContentField = false
    }

    private func updateFileNameExtension() {
        guard let fileNameField,
              let fileExtension = draft.normalizedFileExtension,
              let updatedName = FilenamePolicy.fileName(
                  fileNameField.stringValue,
                  applyingFileExtension: fileExtension,
                  replacingFileExtension: appliedExtension
              ) else {
            return
        }
        fileNameField.stringValue = updatedName
        appliedExtension = fileExtension
    }

    private func localizedTitle(for option: FileFormatOption) -> String {
        guard let template = TemplateCatalog.template(withID: option.templateID, in: templates) else {
            return ".\(option.fileExtension)"
        }
        let name = FileMintStrings.templateDisplayName(for: template, language: language)
        return "\(name) (.\(option.fileExtension))"
    }

    private func invalidExtensionError() -> NSError {
        NSError(
            domain: "io.github.daigua.filemint.custom-file",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: FileMintStrings.text(
                    .invalidFileExtension,
                    language: language
                )
            ]
        )
    }

    private func showError(_ error: Error) {
        guard let panel else {
            return
        }

        let alert = NSAlert()
        alert.messageText = FileMintStrings.text(.createFileErrorTitle, language: language)
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: panel)
    }
}

extension CustomFileSavePanelController: NSComboBoxDataSource, NSComboBoxDelegate {
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        suggestions.count
    }

    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        guard suggestions.indices.contains(index) else {
            return nil
        }
        return suggestions[index].fileExtension
    }

    func comboBox(_ comboBox: NSComboBox, completedString string: String) -> String? {
        FileFormatCatalog.matching(string, in: allOptions).first?.fileExtension
    }

    func comboBoxWillPopUp(_ notification: Notification) {
        guard let comboBox = notification.object as? NSComboBox else { return }
        let query = comboBox.stringValue
        if FileFormatCatalog.option(forFileExtension: query, in: allOptions) != nil
            || FileFormatCatalog.matching(query, in: allOptions).isEmpty {
            updateSuggestions(for: "")
        }
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let comboBox = notification.object as? NSComboBox,
              suggestions.indices.contains(comboBox.indexOfSelectedItem) else {
            return
        }

        let option = suggestions[comboBox.indexOfSelectedItem]
        draft.selectFormat(option, templates: templates)
        isUpdatingFormatField = true
        comboBox.stringValue = option.fileExtension
        isUpdatingFormatField = false
        updateSuggestions(for: "")
        updateContentField()
        updateFileNameExtension()
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        if notification.object is NSComboBox { updateSuggestions(for: "") }
    }

    func controlTextDidChange(_ notification: Notification) {
        if let field = notification.object as? NSTextField, field === fileNameField {
            if let suffix = FilenamePolicy.inferredFileExtension(from: field.stringValue,
                knownExtensions: allOptions.map(\.fileExtension) + [appliedExtension]) {
                draft.updateExtensionInput(suffix, templates: templates)
                appliedExtension = suffix
                isUpdatingFormatField = true
                formatComboBox?.stringValue = suffix
                isUpdatingFormatField = false
                updateSuggestions(for: "")
                updateContentField()
            }
            return
        }
        guard !isUpdatingFormatField,
              let comboBox = notification.object as? NSComboBox else {
            return
        }

        draft.updateExtensionInput(comboBox.stringValue, templates: templates)
        updateSuggestions(for: comboBox.stringValue)
        updateContentField()
        updateFileNameExtension()
    }
}

extension CustomFileSavePanelController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard !isUpdatingContentField,
              let textView = notification.object as? NSTextView else {
            return
        }
        draft.updateContent(textView.string)
    }
}

extension CustomFileSavePanelController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === panel else {
            return
        }

        if NSApp.modalWindow === closingWindow {
            NSApp.stopModal(withCode: .cancel)
        }

        directoryPicker?.cancel(nil)
        directoryPicker = nil
        panel = nil
        fileNameField = nil
        destinationPopUpButton = nil
        formatComboBox = nil
        contentTextView = nil
        locationSelection = nil
        createButton = nil
        cancelButton = nil
    }
}

/// Finder extension processes do not have the host app's Edit menu. Route native
/// editing shortcuts through the active text responder there as well.
@MainActor
private final class CreationPanel: NSPanel {
    var onCreate: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, event.keyCode == 36 { onCreate?(); return true }
        if modifiers.contains(.command), let editor = firstResponder as? NSTextView {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "v": editor.pasteAsPlainText(nil)
            case "c": editor.copy(nil)
            case "x": editor.cut(nil)
            case "a": editor.selectAll(nil)
            case "z":
                if modifiers.contains(.shift) { editor.undoManager?.redo() }
                else { editor.undoManager?.undo() }
            default: return super.performKeyEquivalent(with: event)
            }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class FileMintTextView: NSTextView {
    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }
    override func pasteAsPlainText(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { NSSound.beep(); return }
        breakUndoCoalescing()
        insertText(text, replacementRange: selectedRange())
        breakUndoCoalescing()
    }
}

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
    private var imageData: Data?
    private var imagePreview: NSImage?
    private var hasEditedFileName = false
    private var selectedTemplateLabel: NSTextField?
    private var contentLabel: NSTextField?
    private var pasteButton: NSButton?
    private var contentHint: NSTextField?
    private var formatHintView: NSView?
    private var documentTemplates = DocumentTemplateStore()

    private override init() {}

    func focusExistingPanel() -> Bool {
        guard panel != nil else { return false }
        bringPanelForward(selectFileName: false)
        return true
    }

    func present(
        in defaultDirectory: URL,
        preferences: FileMintPreferences,
        templateID: String? = nil,
        imageData: Data? = nil,
        imagePreview: NSImage? = nil,
        documentTemplates: DocumentTemplateStore = DocumentTemplateStore()
    ) {
        if panel != nil {
            bringPanelForward(selectFileName: false)
            return
        }

        templates = preferences.templates
        self.imageData = imageData
        self.imagePreview = imagePreview
        self.documentTemplates = documentTemplates
        language = preferences.language
        revealAfterCreation = preferences.revealAfterCreation
        hasEditedFileName = false
        draft = CustomFileDraft(templates: templates, defaultTemplateIDs: preferences.defaultTemplateIDs)
        allOptions = FileFormatCatalog.options(from: templates)
        suggestions = allOptions
        if let option = allOptions.first(where: { $0.templateID == templateID }) {
            draft.selectFormat(option, templates: templates)
        }
        appliedExtension = draft.extensionInput
        if imageData != nil { appliedExtension = "png" }
        locationSelection = CustomFileLocationSelection(directoryURL: defaultDirectory)

        let creationPanel = makePanel()
        panel = creationPanel
        refreshDestinationMenu()
        bringPanelForward(selectFileName: true)

    }

    private func makePanel() -> NSPanel {
        let creationPanel = CreationPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 570),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        creationPanel.identifier = NSUserInterfaceItemIdentifier(
            "io.github.daigua.filemint.custom-file"
        )
        creationPanel.onCreate = { [weak self] in self?.createRequestedFile(nil) }
        creationPanel.title = FileMintStrings.text(imageData == nil ? .customNewFile : .pasteImageFile, language: language)
        creationPanel.titlebarAppearsTransparent = true
        creationPanel.backgroundColor = FileMintStyle.backgroundNS
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

    private func makeContentView(for creationPanel: CreationPanel) -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let heading = NSTextField(labelWithString: creationPanel.title)
        heading.font = .systemFont(ofSize: 23, weight: .semibold)

        let subtitle = wrappingLabel(
            FileMintStrings.text(imageData == nil ? .customPanelSubtitle : .clipboardImageHint, language: language),
            maximumNumberOfLines: imageData == nil ? 1 : 2
        )

        let nameField = NSTextField(string: selectedTemplate?.suggestedFileName ?? "Untitled.\(draft.extensionInput)")
        if imageData != nil { nameField.stringValue = FileMintStrings.text(.imageFileName, language: language) }
        nameField.placeholderString = "Untitled.txt"
        nameField.controlSize = .regular
        nameField.setAccessibilityLabel(FileMintStrings.text(.fileName, language: language))
        nameField.font = .systemFont(ofSize: 15)
        nameField.bezelStyle = .roundedBezel
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.delegate = self
        fileNameField = nameField

        let destinationButton = CreationPopUpButton(frame: .zero, pullsDown: false)
        destinationButton.controlSize = .small
        destinationButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        destinationButton.translatesAutoresizingMaskIntoConstraints = false
        destinationPopUpButton = destinationButton

        let comboBox = CreationComboBox()
        comboBox.controlSize = .small
        comboBox.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        comboBox.isEditable = true
        comboBox.completes = false
        comboBox.setAccessibilityLabel(FileMintStrings.text(.fileFormat, language: language))
        comboBox.usesDataSource = true
        comboBox.dataSource = self
        comboBox.delegate = self
        comboBox.stringValue = draft.extensionInput
        if imageData != nil { comboBox.stringValue = "png"; comboBox.isEnabled = false }
        comboBox.numberOfVisibleItems = min(8, allOptions.count)
        comboBox.translatesAutoresizingMaskIntoConstraints = false
        formatComboBox = comboBox

        let nameColumn = fieldColumn(.fileName, control: nameField)
        let formatColumn = fieldColumn(.fileFormat, control: comboBox)
        formatColumn.widthAnchor.constraint(equalToConstant: 130).isActive = true
        let firstRow = NSStackView(views: [nameColumn, formatColumn])
        firstRow.orientation = .horizontal
        firstRow.alignment = .top
        firstRow.spacing = 12
        nameColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let templateLabel = NSTextField(labelWithString: templateLabelText)
        templateLabel.font = .systemFont(ofSize: 11)
        templateLabel.textColor = .secondaryLabelColor
        templateLabel.isHidden = imageData != nil
        selectedTemplateLabel = templateLabel
        let form = NSStackView(views: [firstRow, templateLabel, fieldColumn(.saveLocation, control: destinationButton)])
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 17
        for row in form.arrangedSubviews { row.widthAnchor.constraint(equalTo: form.widthAnchor).isActive = true }
        form.translatesAutoresizingMaskIntoConstraints = false

        let formatHint = indentedLabel(
            FileMintStrings.text(.formatHint, language: language),
            leadingIndent: 0
        )
        formatHintView = formatHint

        let contentHeader = NSView()
        contentHeader.translatesAutoresizingMaskIntoConstraints = false
        let contentLabel = NSTextField(
            labelWithString: FileMintStrings.text(.initialContent, language: language)
        )
        contentLabel.font = .systemFont(ofSize: 11, weight: .medium)
        contentLabel.textColor = .secondaryLabelColor
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        self.contentLabel = contentLabel
        let encodingLabel = CreationButton(title: FileMintStrings.text(.paste, language: language), target: self, action: #selector(pasteContent(_:)))
        encodingLabel.bezelStyle = .rounded
        encodingLabel.controlSize = .small
        encodingLabel.translatesAutoresizingMaskIntoConstraints = false
        pasteButton = encodingLabel
        contentHeader.addSubview(contentLabel)
        contentHeader.addSubview(encodingLabel)
        if imageData != nil {
            contentLabel.stringValue = FileMintStrings.text(.imagePreview, language: language)
            encodingLabel.isHidden = true
        }

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
        var contentArea: NSView = scrollView
        if imageData != nil {
            let preview = NSImageView(frame: NSRect(x: 0, y: 0, width: 500, height: 155))
            preview.image = imagePreview
            preview.imageScaling = .scaleProportionallyUpOrDown
            preview.translatesAutoresizingMaskIntoConstraints = false
            preview.imageFrameStyle = .grayBezel
            preview.setAccessibilityLabel(FileMintStrings.text(.imagePreview, language: language))
            contentArea = preview
        }

        let placeholderHint = wrappingLabel(
            FileMintStrings.text(.contentHint, language: language),
            maximumNumberOfLines: 2
        )
        contentHint = placeholderHint
        if imageData != nil { formatHint.isHidden = true; placeholderHint.isHidden = true }

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        let cancelButton = CreationButton(
            title: FileMintStrings.text(.cancel, language: language),
            target: self,
            action: #selector(cancelPanel(_:))
        )
        self.cancelButton = cancelButton
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        let createButton = CreationButton(
            title: FileMintStrings.text(.create, language: language),
            target: self,
            action: #selector(createRequestedFile(_:))
        )
        self.createButton = createButton
        createButton.bezelStyle = .rounded
        createButton.bezelColor = FileMintStyle.accentNS
        createButton.controlSize = .large
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

        for view in [heading, subtitle, form, formatHint, contentHeader, contentArea, placeholderHint, separator, footer] {
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 27),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -27),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 23),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -23),

            nameField.heightAnchor.constraint(equalToConstant: 30),
            destinationButton.heightAnchor.constraint(equalToConstant: 26),
            comboBox.heightAnchor.constraint(equalToConstant: 26),

            contentLabel.leadingAnchor.constraint(equalTo: contentHeader.leadingAnchor),
            contentLabel.centerYAnchor.constraint(equalTo: contentHeader.centerYAnchor),
            encodingLabel.trailingAnchor.constraint(equalTo: contentHeader.trailingAnchor),
            encodingLabel.centerYAnchor.constraint(equalTo: contentHeader.centerYAnchor),
            contentHeader.heightAnchor.constraint(equalToConstant: 20),

            contentArea.heightAnchor.constraint(equalToConstant: 155),
            separator.heightAnchor.constraint(equalToConstant: 1),
            footer.heightAnchor.constraint(equalToConstant: 32),
            buttonStack.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            buttonStack.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])

        creationPanel.defaultButtonCell = createButton.cell as? NSButtonCell
        creationPanel.focusOrder = [nameField, comboBox, destinationButton, textView, encodingLabel, cancelButton, createButton]
        if imageData == nil { updateContentField() }
        return container
    }

    private func formLabel(_ key: FileMintTextKey) -> NSTextField {
        let label = NSTextField(labelWithString: FileMintStrings.text(key, language: language))
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .left
        return label
    }

    private func fieldColumn(_ key: FileMintTextKey, control: NSView) -> NSStackView {
        let stack = NSStackView(views: [formLabel(key), control])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
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
        if imageData != nil, let value = fileNameField?.stringValue {
            return FilenamePolicy.fileName(value, applyingFileExtension: "png")
        }
        if let document = selectedTemplate?.document, let value = fileNameField?.stringValue {
            return FilenamePolicy.fileName(value, applyingFileExtension: document.kind.rawValue)
        }
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
        setDraftInputsEnabled(false)
        createButton?.isEnabled = false
        cancelButton?.isEnabled = false
        panel?.standardWindowButton(.closeButton)?.isEnabled = false
        let textTemplate = FileTemplate(id: "custom", displayName: "Custom", suggestedFileName: fileName,
                                    group: "Custom", content: draft.content, rank: 0)
        let template = selectedTemplate?.document != nil && imageData == nil ? selectedTemplate! : textTemplate
        let request = FileCreationRequest(destinationDirectory: directoryURL, template: template,
                                          requestedFileName: fileName,
                                          collisionStrategy: imageData != nil || template.document != nil ? .increment : (replacingExistingFile ? .replace : .fail),
                                          contentMode: draft.hasEditedContent ? .verbatim : .template,
                                          fileData: imageData)
        let assets = documentTemplates
        Task {
            let accessed = directoryURL.startAccessingSecurityScopedResource()
            defer { if accessed { directoryURL.stopAccessingSecurityScopedResource() } }
            let outcome = await Task.detached(priority: .userInitiated) {
                Result { try FileCreationService(documentTemplates: assets).createFile(request) }
            }.value
            isCreating = false
            setDraftInputsEnabled(true)
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

    private func setDraftInputsEnabled(_ enabled: Bool) {
        fileNameField?.isEnabled = enabled
        formatComboBox?.isEnabled = enabled && imageData == nil
        destinationPopUpButton?.isEnabled = enabled
        contentTextView?.isEditable = enabled && imageData == nil && selectedTemplate?.document == nil
        pasteButton?.isEnabled = enabled
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
        selectedTemplateLabel?.stringValue = templateLabelText
        let document = selectedTemplate?.document != nil
        contentLabel?.stringValue = FileMintStrings.text(document ? .documentTemplate : .initialContent, language: language)
        pasteButton?.isHidden = document
        contentHint?.stringValue = FileMintStrings.text(document ? .documentTemplateHint : .contentHint, language: language)
        contentHint?.isHidden = document
        formatHintView?.isHidden = document
        formatComboBox?.isEditable = !document
        contentTextView?.isEditable = !document
        contentTextView?.font = document ? .systemFont(ofSize: 13) : .monospacedSystemFont(ofSize: 12.5, weight: .regular)
        contentTextView?.textContainerInset = document ? NSSize(width: 12, height: 12) : NSSize(width: 7, height: 6)
        contentTextView?.setAccessibilityLabel(FileMintStrings.text(document ? .documentTemplate : .initialContent, language: language))
        let value = document ? FileMintStrings.text(.documentTemplateHint, language: language) : draft.content
        guard let contentTextView, contentTextView.string != value else {
            return
        }

        isUpdatingContentField = true
        contentTextView.string = value
        isUpdatingContentField = false
    }

    private func updateFileNameExtension() {
        if !hasEditedFileName, let template = selectedTemplate {
            fileNameField?.stringValue = template.suggestedFileName
            appliedExtension = template.fileExtension
            return
        }
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

    private var selectedTemplate: FileTemplate? {
        templates.first { $0.id == draft.selectedTemplateID }
    }

    private var templateLabelText: String {
        let name = selectedTemplate.map { FileMintStrings.templateDisplayName(for: $0, language: language) }
            ?? FileMintStrings.text(.noTemplate, language: language)
        return String(format: FileMintStrings.text(.selectedTemplate, language: language), name)
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
        alert.informativeText = (error as? DocumentTemplateError).map { FileMintStrings.text($0.textKey, language: language) }
            ?? error.localizedDescription
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
        return localizedTitle(for: suggestions[index])
    }

    func comboBox(_ comboBox: NSComboBox, completedString string: String) -> String? {
        nil
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
        if templates.first(where: { $0.id == option.templateID })?.document != nil,
           draft.hasEditedContent, !draft.content.isEmpty {
            comboBox.stringValue = draft.extensionInput
            showError(NSError(domain: "FileMint", code: 1, userInfo: [NSLocalizedDescriptionKey:
                FileMintStrings.text(.documentDraftEdited, language: language)]))
            return
        }
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
        guard imageData == nil else { return }
        if let field = notification.object as? NSTextField, field === fileNameField {
            hasEditedFileName = true
            if selectedTemplate?.document != nil { return }
            if let suffix = FilenamePolicy.inferredFileExtension(from: field.stringValue,
                knownExtensions: allOptions.map(\.fileExtension) + [appliedExtension]) {
                guard draft.updateExtensionInput(suffix, templates: templates) else {
                    updateFileNameExtension()
                    showDocumentDraftMessage()
                    return
                }
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

        guard draft.updateExtensionInput(comboBox.stringValue, templates: templates) else {
            comboBox.stringValue = draft.extensionInput
            showDocumentDraftMessage()
            return
        }
        updateSuggestions(for: comboBox.stringValue)
        updateContentField()
        updateFileNameExtension()
    }

    private func showDocumentDraftMessage() {
        showError(NSError(domain: "FileMint", code: 1, userInfo: [NSLocalizedDescriptionKey:
            FileMintStrings.text(.documentDraftEdited, language: language)]))
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
        imageData = nil
        imagePreview = nil
        selectedTemplateLabel = nil
        contentLabel = nil
        pasteButton = nil
        contentHint = nil
        formatHintView = nil
    }
}

/// Finder extension processes do not have the host app's Edit menu. Route native
/// editing shortcuts through the active text responder there as well.
@MainActor
private final class CreationPanel: NSPanel {
    var onCreate: (() -> Void)?
    var focusOrder: [NSView] = []

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 48, attachedSheet == nil,
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           moveFocus(backward: event.modifierFlags.contains(.shift)) { return }
        super.sendEvent(event)
    }

    private func moveFocus(backward: Bool) -> Bool {
        let candidates = focusOrder.filter { view in
            guard view.window === self, !view.isHiddenOrHasHiddenAncestor else { return false }
            if let control = view as? NSControl, !control.isEnabled { return false }
            if let editor = view as? NSTextView, !editor.isEditable { return false }
            return true
        }
        guard !candidates.isEmpty else { return false }
        let current = candidates.firstIndex { view in
            view === firstResponder || (view as? NSControl)?.currentEditor() === firstResponder
        } ?? (backward ? 0 : candidates.count - 1)
        let direction = backward ? -1 : 1
        for step in 1...candidates.count {
            let index = (current + direction * step + candidates.count) % candidates.count
            if makeFirstResponder(candidates[index]) { return true }
        }
        return false
    }

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
private final class CreationButton: NSButton {
    override var acceptsFirstResponder: Bool { true }
}

@MainActor
private final class CreationPopUpButton: NSPopUpButton {
    override var acceptsFirstResponder: Bool { true }
}

@MainActor
private final class CreationComboBox: NSComboBox {
    override var acceptsFirstResponder: Bool { true }
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

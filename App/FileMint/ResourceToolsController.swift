import AppKit
import SwiftUI
import FileMintCore
import FileMintImages

@MainActor
final class ResourceToolsController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = ResourceToolsController()
    @Published var options = ImageJobOptions()
    @Published private(set) var inputs: [ImageInput] = []
    @Published private(set) var thumbnails: [URL: NSImage] = [:]
    @Published private(set) var dimensions: [URL: ImageDimensions] = [:]
    @Published var selectedIndex = 0
    @Published var editedText: String?
    @Published private(set) var destination: URL?
    @Published private(set) var isRunning = false
    @Published private(set) var isPreparing = false
    @Published private(set) var isCancelling = false
    @Published private(set) var isSavingText = false
    @Published private(set) var completed = 0
    @Published private(set) var result: ImageJobResult?
    @Published private(set) var message: String?
    private(set) var tool: ResourceTool = .convert
    private(set) var language: AppLanguage = .system
    private var panel: NSPanel?
    private var continuation: CheckedContinuation<Void, Never>?
    private var worker: Task<ImageJobResult, Never>?
    private var previewWorker: Task<Void, Never>?
    private var grantedFolders: [URL] = []
    private var generation = UUID()
    private let preferencesFile: URL?
    private var fromFinder = true
    private var previewOrder: [URL] = []

    init(preferencesFile: URL? = nil) {
        self.preferencesFile = preferencesFile
        super.init()
    }

    var text: String {
        if let editedText { return editedText }
        guard let result else { return "" }
        return result.texts.enumerated().map { index, text in
            let content = text.isEmpty ? ResourceText.noText.text(language) : text
            return inputs.count > 1 ? "\(inputs[index].url.lastPathComponent)\n\(content)" : content
        }.joined(separator: "\n\n")
    }
    var hasText: Bool { editedText.map { !$0.isEmpty } ?? (result?.texts.contains(where: { !$0.isEmpty }) == true) }
    var formats: [ImageOutputFormat] {
        let candidates = tool == .icons ? ImageOutputFormat.icons : ImageOutputFormat.conversions
        return candidates.filter { ImageProcessor.writableFormats.contains($0) }
    }

    private func activatePanel(_ panel: NSPanel) {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func focusExistingPanel() -> Bool {
        guard let panel else { return false }
        activatePanel(panel)
        return true
    }

    func present(selection: [URL], tool: ResourceTool, fromFinder: Bool = true) async throws {
        guard panel == nil else {
            if let panel { activatePanel(panel) }
            return
        }
        let captured = try await Task.detached(priority: .userInitiated) { try ImageProcessor.capture(selection) }.value
        self.tool = tool
        self.fromFinder = fromFinder
        language = FileMintPreferencesStore(fileURL: preferencesFile).load().language
        inputs = captured
        options = ImageJobOptions()
        if tool == .icons { options.format = .icns }
        if !formats.contains(options.format), let first = formats.first { options.format = first }
        destination = nil
        result = nil
        message = nil
        completed = 0
        thumbnails = [:]
        dimensions = [:]
        selectedIndex = 0
        editedText = nil
        previewOrder = []
        isRunning = false
        isCancelling = false
        generation = UUID()
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = tool.title(language)
        panel.contentMinSize = NSSize(width: 820, height: 560)
        panel.backgroundColor = FileMintStyle.backgroundNS
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ResourceToolsView(model: self))
        self.panel = panel
        panel.center()
        activatePanel(panel)
        // A Finder XPC callback can finish while LaunchServices is still
        // activating the app. Re-assert the panel focus on the next turn.
        Task { @MainActor [weak self, weak panel] in
            await Task.yield()
            guard let self, let panel, self.panel === panel else { return }
            self.activatePanel(panel)
        }
        loadPreviews()
        await withCheckedContinuation { continuation = $0 }
    }

    private func loadPreviews(_ requested: [ImageInput]? = nil) {
        // Previews finish before Run, so preview and full-size decoders never overlap.
        isPreparing = true
        let batch = requested ?? Array(inputs.prefix(20))
        let id = generation
        previewWorker = Task {
            for input in batch {
                if Task.isCancelled || generation != id { break }
                let decoder = Task.detached(priority: .utility) { try? ImageProcessor.previewInfo(input) }
                let thumbnail = await withTaskCancellationHandler(operation: { await decoder.value }, onCancel: { decoder.cancel() })
                guard !Task.isCancelled, generation == id else { break }
                if let thumbnail {
                    if thumbnails[input.url] == nil, previewOrder.count >= 20 {
                        let removed = previewOrder.removeFirst()
                        thumbnails[removed] = nil
                    }
                    if thumbnails[input.url] == nil { previewOrder.append(input.url) }
                    thumbnails[input.url] = NSImage(data: thumbnail.data)
                    dimensions[input.url] = thumbnail.dimensions
                }
            }
            if generation == id {
                isPreparing = false
                if let input = selectedInput, thumbnails[input.url] == nil,
                   !batch.contains(where: { $0.url == input.url }) { loadPreviews([input]) }
            }
        }
    }

    var selectedInput: ImageInput? { inputs.indices.contains(selectedIndex) ? inputs[selectedIndex] : nil }

    func select(_ index: Int) {
        guard inputs.indices.contains(index) else { return }
        selectedIndex = index
        if !isRunning, !isPreparing, thumbnails[inputs[index].url] == nil { loadPreviews([inputs[index]]) }
    }

    func move(_ index: Int, by amount: Int) {
        guard !isRunning, result == nil, inputs.indices.contains(index), inputs.indices.contains(index + amount) else { return }
        inputs.swapAt(index, index + amount)
        selectedIndex = index + amount
    }

    @discardableResult
    func chooseDestination() -> Bool {
        guard !isRunning else { return false }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.canCreateDirectories = true
        picker.allowsMultipleSelection = false
        picker.directoryURL = destination ?? inputs.first?.url.deletingLastPathComponent()
        picker.title = ResourceText.output.text(language)
        guard picker.runModal() == .OK, let url = picker.url else { return false }
        if url.startAccessingSecurityScopedResource() { grantedFolders.append(url) }
        destination = url
        return true
    }

    private func authorizeOutputs() -> Bool {
        let directories = tool == .stitch ? [destination ?? inputs[0].url.deletingLastPathComponent()]
            : inputs.map { destination ?? $0.url.deletingLastPathComponent() }
        var seen = Set<URL>()
        for directory in directories where seen.insert(directory.standardizedFileURL).inserted {
            if FileManager.default.isWritableFile(atPath: directory.path) { continue }
            let picker = NSOpenPanel()
            picker.canChooseFiles = false
            picker.canChooseDirectories = true
            picker.allowsMultipleSelection = false
            picker.directoryURL = directory
            picker.message = FileMintStrings.text(.fileOperationAuthorize, language: language)
            guard picker.runModal() == .OK, let chosen = picker.url else { return false }
            guard chosen.resolvingSymlinksInPath().standardizedFileURL == directory.resolvingSymlinksInPath().standardizedFileURL else {
                message = FileMintStrings.text(.moveChooseExactFolder, language: language)
                return false
            }
            if chosen.startAccessingSecurityScopedResource() { grantedFolders.append(chosen) }
            guard FileManager.default.isWritableFile(atPath: directory.path) else {
                message = ResourceError.accessDenied.message(language)
                return false
            }
        }
        return true
    }

    func run() {
        guard !isRunning, !isPreparing, result == nil, !inputs.isEmpty else { return }
        do { try options.validate(for: tool) }
        catch { message = ResourceError.invalidOptions.message(language); return }
        if tool != .ocr, !authorizeOutputs() { return }
        let inputs = inputs, options = options, tool = tool, destination = destination
        let selection = inputs.map(\.url)
        let preferencesFile = preferencesFile
        let fromFinder = fromFinder
        let id = generation
        let progress: @Sendable (Int) -> Void = { [weak self] count in
            Task { @MainActor in
                guard let self, self.generation == id else { return }
                self.completed = count
            }
        }
        isRunning = true
        message = nil
        let worker = Task.detached(priority: .utility) {
            ImageProcessor.run(tool: tool, inputs: inputs, options: options, destination: destination,
                canContinue: {
                    guard fromFinder else { return ResourceToolsPolicy.allowsAppSelection(selection, tool: tool) }
                    let preferences = FileMintPreferencesStore(fileURL: preferencesFile).load()
                    return ResourceToolsPolicy.availableTools(selection: selection, isItemMenu: true,
                        preferences: preferences).contains(tool) &&
                        selection.allSatisfy { FolderScope.containsResolvedItem($0, in: preferences.monitoredFolderURLs) }
                }, progress: progress)
        }
        self.worker = worker
        Task {
            let result = await worker.value
            self.result = result
            completed = result.completed
            isRunning = false
            isCancelling = false
            self.worker = nil
            if let error = result.failure { message = error.message(language) }
            if let input = selectedInput, thumbnails[input.url] == nil { loadPreviews([input]) }
        }
    }

    func cancel() {
        guard !isSavingText else { return }
        if isRunning { isCancelling = true; worker?.cancel() }
        else { panel?.close() }
    }

    func copyText() {
        guard hasText else { return }
        NSPasteboard.general.clearContents()
        message = NSPasteboard.general.setString(text, forType: .string)
            ? ResourceText.copied.text(language) : FileMintStrings.text(.clipboardWriteFailed, language: language)
    }

    func setEditedText(_ value: String) {
        guard value.utf8.count <= 4_194_304 else { message = ResourceError.textTooLarge.message(language); return }
        editedText = value
    }

    func saveText() {
        guard hasText, !isRunning else { return }
        guard chooseDestination(), let destination else { return }
        let text = text
        isRunning = true
        isSavingText = true
        Task {
            defer { isRunning = false; isSavingText = false }
            do {
                let url = try await Task.detached(priority: .utility) {
                    try ImageProcessor.saveText(text, in: destination)
                }.value
                result?.outputs.append(url)
                message = ResourceText.saved.text(language)
            } catch { message = ResourceError.accessDenied.message(language) }
        }
    }

    func showOutputs() {
        if let outputs = result?.outputs, !outputs.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(outputs) }
    }

    func editOptions() {
        guard !isRunning, result?.completed == 0, result?.failure != nil else { return }
        result = nil
        message = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isRunning else { cancel(); return false }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        previewWorker?.cancel()
        generation = UUID()
        let grants = grantedFolders
        grantedFolders = []
        panel = nil
        inputs = []
        result = nil
        thumbnails = [:]
        dimensions = [:]
        editedText = nil
        previewOrder = []
        let continuation = continuation
        self.continuation = nil
        let previews = previewWorker
        previewWorker = nil
        Task {
            // Keep the serialized coordinator busy until a cancelled decoder exits.
            await previews?.value
            for folder in grants { folder.stopAccessingSecurityScopedResource() }
            continuation?.resume()
        }
    }
}

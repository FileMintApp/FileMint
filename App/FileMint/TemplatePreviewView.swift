import AppKit
import CryptoKit
import FileMintCore
import QuickLookUI
import QuickLookThumbnailing
import SwiftUI

struct TemplatePreviewView: NSViewRepresentable {
    var template: FileTemplate
    var assets: DocumentTemplateStore
    var language: AppLanguage
    var capturedAt: Date = CreationContentResolver.exampleDate
    var documentBytes: Data? = nil
    func makeNSView(context: Context) -> TemplatePreviewSurface { TemplatePreviewSurface() }
    func updateNSView(_ view: TemplatePreviewSurface, context: Context) {
        view.show(template, assets: assets, language: language, capturedAt: capturedAt, documentBytes: documentBytes)
    }
    static func dismantleNSView(_ view: TemplatePreviewSurface, coordinator: ()) { view.close() }
}

/// Owns one snapshot and one native preview; never receives a user destination.
@MainActor
final class TemplatePreviewSurface: NSView {
    struct Snapshot: Sendable {
        let directory: URL
        let url: URL
        let identity: CreatedFileIdentity
        static func create(template: FileTemplate, assets: DocumentTemplateStore, documentBytes: Data? = nil) throws -> Self {
            guard let reference = template.document else { throw DocumentTemplateError.unavailable }
            let data: Data
            if let documentBytes {
                guard documentBytes.count == reference.byteCount, TemplatePackageCodec.digest(documentBytes) == reference.sha256 else { throw DocumentTemplateError.unavailable }
                try OfficeDocumentValidator.validate(documentBytes, kind: reference.kind)
                data = documentBytes
            } else { data = try assets.data(for: reference) }
            try Task.checkCancellation()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-preview-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let url = directory.appendingPathComponent("preview." + reference.kind.rawValue)
            do {
                try data.write(to: url, options: .withoutOverwriting)
                try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: url.path)
                let value = Self(directory: directory, url: url, identity: try .capture(url))
                if Task.isCancelled { value.remove(); throw CancellationError() }
                return value
            } catch {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: directory)
                throw error
            }
        }
        func remove() {
            // Do not delete anything that replaced the owned snapshot.
            guard (try? identity.validate(url)) != nil else { return }
            try? FileManager.default.removeItem(at: url)
            _ = directory.withUnsafeFileSystemRepresentation { path in path.map { rmdir($0) } ?? -1 }
        }
    }
    private var key: FileTemplate?
    private var contextDate: Date?
    private var language: AppLanguage?
    private var token = UUID()
    private var task: Task<Void, Never>?
    private var snapshot: Snapshot?
    var ownedSnapshotURL: URL? { snapshot?.url }
    private var thumbnailRequest: QLThumbnailGenerator.Request?
    private var nativePreview: QLPreviewView?
    private(set) var state = "idle"
    private let text = NSTextView()
    private let scroll = NSScrollView()
    override init(frame: NSRect) {
        super.init(frame: frame)
        text.isEditable = false; text.isSelectable = true; text.isRichText = false
        text.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        text.textContainerInset = NSSize(width: 10, height: 10)
        text.isVerticallyResizable = true; text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        scroll.documentView = text; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.borderType = .lineBorder
        addSubview(scroll)
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layout() {
        super.layout(); scroll.frame = bounds; nativePreview?.frame = bounds
        let size = scroll.contentSize
        text.minSize = NSSize(width: 0, height: size.height)
        text.maxSize = NSSize(width: size.width, height: .greatestFiniteMagnitude)
        text.frame = NSRect(origin: .zero, size: NSSize(width: size.width, height: max(size.height, text.frame.height)))
        text.sizeToFit()
    }
    func show(_ template: FileTemplate, assets: DocumentTemplateStore, language: AppLanguage, capturedAt: Date, documentBytes: Data? = nil) {
        guard key != template || contextDate != capturedAt || self.language != language else { return }
        close()
        key = template; contextDate = capturedAt; self.language = language
        if template.document == nil {
            state = "available"
            text.string = CreationContentResolver.text(template: template, fileName: template.suggestedFileName, mode: .template, capturedAt: capturedAt)
            return
        }
        state = "loading"; text.string = TemplateWorkflowText.loading.text(language)
        let requestToken = token
        task = Task { [weak self] in
            let worker = Task.detached(priority: .utility) { try Snapshot.create(template: template, assets: assets, documentBytes: documentBytes) }
            do {
                let owned = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                guard let self, self.token == requestToken, !Task.isCancelled else { owned.remove(); return }
                self.snapshot = owned
                let request = QLThumbnailGenerator.Request(fileAt: owned.url, size: NSSize(width: 256, height: 256), scale: 1, representationTypes: .thumbnail)
                self.thumbnailRequest = request
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { @Sendable [weak self] thumbnail, error in
                    let available = thumbnail != nil && error == nil
                    Task { @MainActor [weak self] in
                        guard let self, self.token == requestToken else { return }
                        self.thumbnailRequest = nil
                        if available, let preview = QLPreviewView(frame: self.bounds, style: .compact) {
                            preview.shouldCloseWithWindow = false; preview.autostarts = false
                            preview.previewItem = owned.url as NSURL
                            self.nativePreview = preview; self.addSubview(preview)
                            self.scroll.isHidden = true; self.state = "available"
                        } else {
                            self.state = "unavailable"
                            self.text.string = TemplateWorkflowText.unavailablePreview.text(language) + "\n" + template.displayName + " · " + template.fileExtension.uppercased() + " · \(template.document?.byteCount ?? 0) B"
                        }
                    }
                }
            } catch {
                guard let self, self.token == requestToken, !Task.isCancelled else { return }
                self.state = "invalid"
                self.text.string = FileMintStrings.text((error as? DocumentTemplateError)?.textKey ?? .documentUnavailable, language: language)
            }
        }
    }
    func close() {
        token = UUID(); task?.cancel(); task = nil
        if let thumbnailRequest { QLThumbnailGenerator.shared.cancel(thumbnailRequest) }
        thumbnailRequest = nil
        nativePreview?.previewItem = nil; nativePreview?.close(); nativePreview?.removeFromSuperview(); nativePreview = nil
        snapshot?.remove(); snapshot = nil
        key = nil; scroll.isHidden = false; state = "idle"
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if window != nil && newWindow == nil { close() }
        super.viewWillMove(toWindow: newWindow)
    }
}

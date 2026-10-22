import AppKit
import FileMintCore

struct FileContentClipboardPayload: Sendable {
    let text: String
    let rtf: Data?
}

enum FileContentClipboard {
    static func prepare(_ contents: FileContentRead) throws -> FileContentClipboardPayload {
        switch contents.format {
        case .plainText:
            return FileContentClipboardPayload(text: try FileContentCopyPolicy.decodeText(contents.data), rtf: nil)
        case .rtf:
            return try prepareRTF(contents.data)
        }
    }

    /// Keep the original RTF, not a lossy attributed-string re-export. The
    /// importer supplies only the companion plain-text representation.
    static func prepareRTF(_ data: Data) throws -> FileContentClipboardPayload {
        try FileContentCopyPolicy.validateRTFStructure(data)
        let attributed: NSAttributedString
        do {
            attributed = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                documentAttributes: nil)
        } catch { throw FileContentCopyError.invalidRTF }
        var hasAttachment = false
        attributed.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if value != nil { hasAttachment = true }
        }
        guard !hasAttachment else { throw FileContentCopyError.invalidRTF }
        try FileContentCopyPolicy.validateText(attributed.string)
        return FileContentClipboardPayload(text: attributed.string, rtf: data)
    }

    @MainActor
    static func write(_ payload: FileContentClipboardPayload, to pasteboard: NSPasteboard,
                      expectedChangeCount: Int) throws {
        // Build all representations before claiming ownership of the real board.
        let item = NSPasteboardItem()
        guard item.setString(payload.text, forType: .string),
              payload.rtf.map({ item.setData($0, forType: .rtf) }) ?? true else {
            throw FileContentCopyError.clipboardWriteFailed
        }
        guard pasteboard.changeCount == expectedChangeCount else { throw FileContentCopyError.clipboardChanged }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw FileContentCopyError.clipboardWriteFailed }
    }
}

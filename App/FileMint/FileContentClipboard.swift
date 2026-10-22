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
    /// independent Core extraction must agree byte-for-byte with native import.
    static func prepareRTF(_ data: Data) throws -> FileContentClipboardPayload {
        let text = try FileContentCopyPolicy.validatedRTFText(data)
        let attributed: NSAttributedString
        do {
            attributed = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                documentAttributes: nil)
        } catch { throw FileContentCopyError.invalidRTF }
        var hasAttachment = false
        attributed.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if value != nil { hasAttachment = true }
        }
        guard !hasAttachment, attributed.string.utf8.elementsEqual(text.utf8) else {
            throw FileContentCopyError.invalidRTF
        }
        return FileContentClipboardPayload(text: text, rtf: data)
    }

    @MainActor
    static func write(_ payload: FileContentClipboardPayload, to pasteboard: NSPasteboard,
                      expectedChangeCount: Int) throws {
        // Build all representations before claiming ownership of the real board.
        let item = NSPasteboardItem()
        let textWasSet: Bool
        if payload.text.unicodeScalars.first?.value == 0xFEFF {
            // NSPasteboard's UTF-8 reader consumes one encoding BOM. Keep a
            // separate transport BOM when FEFF is the first content character.
            textWasSet = item.setData(Data([0xEF, 0xBB, 0xBF]) + Data(payload.text.utf8), forType: .string)
        } else {
            textWasSet = item.setString(payload.text, forType: .string)
        }
        guard textWasSet,
              payload.rtf.map({ item.setData($0, forType: .rtf) }) ?? true else {
            throw FileContentCopyError.clipboardWriteFailed
        }
        guard pasteboard.changeCount == expectedChangeCount else { throw FileContentCopyError.clipboardChanged }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw FileContentCopyError.clipboardWriteFailed }
    }
}

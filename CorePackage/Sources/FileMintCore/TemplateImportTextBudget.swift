import Foundation

/// Counts every accepted reference without expanding a shared payload per row.
/// Input is the immutable, validated UTF-8 from a template package.
struct TemplateImportTextBudget {
    private let maximumBytes: Int
    private var textBytes = 0
    private var payloadSizes: [String: Int] = [:]

    init(maximumBytes: Int = FileMintPreferencesStore.maximumBytes) {
        precondition(maximumBytes >= 0)
        self.maximumBytes = maximumBytes
    }

    mutating func include(_ bytes: Data, payloadID: String) throws {
        let size: Int
        if let cached = payloadSizes[payloadID] { size = cached }
        else {
            size = try Self.encodedContentSize(bytes, limit: maximumBytes - textBytes)
            payloadSizes[payloadID] = size
        }
        guard size <= maximumBytes - textBytes else { throw TemplatePackageError.tooLarge }
        textBytes += size
    }

    func validate(metadataBytes: Int) throws {
        guard metadataBytes >= 0, metadataBytes <= maximumBytes - textBytes else { throw TemplatePackageError.tooLarge }
    }

    private static func encodedContentSize(_ bytes: Data, limit: Int) throws -> Int {
        guard bytes.count <= limit else { throw TemplatePackageError.tooLarge }
        let encoder = JSONEncoder()
        var start = bytes.startIndex, total = 0
        while start < bytes.endIndex {
            try Task.checkCancellation()
            var end = min(start + 64 * 1024, bytes.endIndex)
            // Keep UTF-8 scalars intact, including across a chunk boundary.
            while end < bytes.endIndex && bytes[end] & 0xc0 == 0x80 { end -= 1 }
            let chunk = String(decoding: bytes[start..<end], as: UTF8.self)
            // Use the persistence encoder's escaping, but never build an entire
            // oversized JSON string. Quotes are already in the empty placeholder.
            let size = try encoder.encode(chunk).count - 2
            guard size <= limit - total else { throw TemplatePackageError.tooLarge }
            total += size
            start = end
        }
        return total
    }
}

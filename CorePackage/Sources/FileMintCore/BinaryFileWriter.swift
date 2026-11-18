import Foundation

/// Finish bytes in private staging, then publish exclusively on the same volume.
public enum BinaryFileWriter {
    public static func create(_ data: Data, in directory: URL, name: String,
                              collision: NameCollisionStrategy = .increment, contentKind: CreatedContentKind = .binary) throws -> FileCreationResult {
        try PinnedCreationWriter.create(in: directory, expected: nil, name: name, fileExtension: nil,
            collision: collision == .replace ? .fail : collision, kind: contentKind, contentDependsOnName: false) { _ in data }
    }
}

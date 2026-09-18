import Foundation

public struct FileDeletionFailure: Error, Sendable {
    public let completed: Int
    public let total: Int
}

/// No background traversal: only remove items captured by an explicit menu click.
public enum FileDeletionService {
    public static func capture(_ selection: [URL]) throws -> [FileMoveItem] {
        let items = try PendingFileMove.capture(selection: selection).items
        try validate(items)
        return items
    }

    public static func validate(_ items: [FileMoveItem]) throws {
        guard !items.isEmpty else { throw FileMoveError.invalidSelection }
        for item in items {
            guard item.source.standardizedFileURL.path != "/" else { throw FileMoveError.invalidSelection }
            try item.validateIdentity()
            // A mounted volume is not an ordinary selected directory.
            let parent = try FileManager.default.attributesOfItem(atPath: item.canonicalParent.path)
            guard (parent[.systemNumber] as? NSNumber)?.uint64Value == item.device else {
                throw FileMoveError.invalidSelection
            }
        }
        let fresh = try PendingFileMove.capture(selection: items.map(\.source)).items
        guard fresh == items else { throw FileMoveError.sourceChanged }
    }

    public static func perform(items: [FileMoveItem], isAllowed: () -> Bool) throws {
        var completed = 0
        do {
            guard isAllowed() else { throw FileMoveError.disabled }
            // Validate the whole batch before the first irreversible action.
            try validate(items)
            for item in items {
                guard isAllowed() else { throw FileMoveError.disabled }
                try item.validateIdentity()
                // removeItem removes a selected symlink itself, not its target.
                try FileManager.default.removeItem(at: item.source)
                completed += 1
            }
        } catch {
            throw FileDeletionFailure(completed: completed, total: items.count)
        }
    }
}

import Foundation

public struct FileDrawerSearchResults: Sendable {
    public static let empty = Self(entries: [], positions: [:])
    public let entries: [FileDrawerEntry]
    private let positions: [URL: Int]

    fileprivate init(entries: [FileDrawerEntry], positions: [URL: Int]) {
        self.entries = entries
        self.positions = positions
    }

    public func index(of url: URL) -> Int? { positions[url] }
    public func entry(at url: URL) -> FileDrawerEntry? { positions[url].map { entries[$0] } }
}

/// An in-memory snapshot of a single listing. Queries operate on prepared names
/// and retain the exact directory entries that the file-operation layer captured.
public struct FileDrawerSearchIndex: Sendable {
    private struct Row: Sendable {
        let entry: FileDrawerEntry
        let foldedName: String
        let kind: String
    }
    public let sort: FileDrawerSort
    public let ascending: Bool
    public let all: FileDrawerSearchResults
    private let rows: [Row]
    private let locale: Locale

    public init(_ entries: [FileDrawerEntry], sort: FileDrawerSort, ascending: Bool) throws {
        let locale = Locale.current
        let rows = try entries.map { entry in
            try Task.checkCancellation()
            return Row(entry: entry, foldedName: Self.fold(entry.name, locale: locale),
                       kind: entry.isDirectory ? "" : Self.fold(entry.url.pathExtension, locale: locale))
        }
        try self.init(rows: rows, sort: sort, ascending: ascending, locale: locale)
    }

    private init(rows: [Row], sort: FileDrawerSort, ascending: Bool, locale: Locale) throws {
        self.sort = sort
        self.ascending = ascending
        self.locale = locale
        self.rows = try rows.sorted { left, right in
            try Task.checkCancellation()
            let lhs = left.entry, rhs = right.entry
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            switch sort {
            case .kind where left.kind != right.kind:
                return ascending ? left.kind < right.kind : left.kind > right.kind
            case .size where lhs.size != rhs.size:
                return ascending ? (lhs.size ?? -1) < (rhs.size ?? -1) : (lhs.size ?? -1) > (rhs.size ?? -1)
            case .date where lhs.modified != rhs.modified:
                return ascending ? (lhs.modified ?? .distantPast) < (rhs.modified ?? .distantPast)
                    : (lhs.modified ?? .distantPast) > (rhs.modified ?? .distantPast)
            default:
                let direction: ComparisonResult = sort == .name && !ascending ? .orderedDescending : .orderedAscending
                let order = lhs.name.localizedStandardCompare(rhs.name)
                if order == .orderedSame { return lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8) }
                return order == direction
            }
        }
        var entries: [FileDrawerEntry] = []
        var positions: [URL: Int] = [:]
        entries.reserveCapacity(rows.count)
        positions.reserveCapacity(rows.count)
        for (index, row) in self.rows.enumerated() {
            try Task.checkCancellation()
            entries.append(row.entry)
            positions[row.entry.url] = index
        }
        all = .init(entries: entries, positions: positions)
    }

    public func ordered(by sort: FileDrawerSort, ascending: Bool) throws -> Self {
        if sort == self.sort && ascending == self.ascending { return self }
        return try Self(rows: rows, sort: sort, ascending: ascending, locale: locale)
    }

    public func matching(_ query: String) throws -> FileDrawerSearchResults {
        try Task.checkCancellation()
        let terms = Self.fold(query, locale: locale).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return all }
        var matches: [FileDrawerEntry] = []
        var positions: [URL: Int] = [:]
        for row in rows {
            try Task.checkCancellation()
            if terms.allSatisfy({ row.foldedName.contains($0) }) {
                positions[row.entry.url] = matches.count
                matches.append(row.entry)
            }
        }
        return .init(entries: matches, positions: positions)
    }

    private static func fold(_ text: String, locale: Locale) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
    }
}

import Foundation

/// Finder forwards a location only. A URL can open a draft, never create a file.
public enum CreationRoute {
    public static func url(for directory: URL, templateID: String? = nil) -> URL? {
        guard directory.isFileURL else { return nil }
        var parts = URLComponents()
        parts.scheme = "filemint"
        parts.host = "new"
        parts.queryItems = [URLQueryItem(name: "directory", value: directory.path)]
        if let templateID { parts.queryItems?.append(URLQueryItem(name: "template", value: templateID)) }
        return parts.url
    }

    public static func templateID(from url: URL) -> String? {
        guard directory(from: url) != nil else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "template" }?.value
    }

    public static func directory(from url: URL) -> URL? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "filemint", parts.host == "new",
              parts.path.isEmpty, parts.fragment == nil,
              let items = parts.queryItems, (1...2).contains(items.count),
              Set(items.map(\.name)).count == items.count,
              items.allSatisfy({ $0.name == "directory" || $0.name == "template" }),
              let item = items.first(where: { $0.name == "directory" }),
              let path = item.value, path.hasPrefix("/"),
              !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}

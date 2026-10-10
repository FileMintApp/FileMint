import Foundation
import FileMintCore

/// Only this fixture's identity and per-run store are accepted. No default
/// production store is used, including when fixture metadata is missing.
enum AccessQA {
    static let identifier = "io.github.daigua.filemint.access-qa"
    static let scheme = "filemint-access-qa"
    static let templateID = "access-qa-template"
    static let home = DefaultFolders.resolvedUserHomeDirectory(fileManager: .default)
    static var runID: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "FixtureRunID") as? String,
              value.range(of: "^run\\.[A-Za-z0-9]+$", options: .regularExpression) != nil else {
            fatalError("Invalid isolated QA run")
        }
        return value
    }
    static var root: URL { home.appendingPathComponent("Library/Application Support/FileMintAccessQA/" + runID) }
    static var preferences: URL { root.appendingPathComponent("preferences.json") }
    static var tickets: QuickCreationTicketStore { QuickCreationTicketStore(directory: root.appendingPathComponent("requests")) }
    static var template: FileTemplate {
        FileTemplate(id: templateID, displayName: "QA 自定义模板", suggestedFileName: "QA.txt",
                     group: "QA", content: "FileMint access fixture — 中文\n", rank: 1)
    }
    static func translated(_ url: URL, to scheme: String) -> URL? {
        guard var value = URLComponents(url: url, resolvingAgainstBaseURL: false),
              [Self.scheme, "filemint"].contains(value.scheme ?? "") else { return nil }
        value.scheme = scheme
        return value.url
    }
}

import AppKit
import FileMintCore
import UniformTypeIdentifiers

@MainActor
enum DefaultApplicationChecks {
    private struct Failure: Error, CustomStringConvertible { let description: String }

    static func run() async throws {
        try await checkTicket(for: .pdf, interactive: false)
        let names = [("预览", "Preview"), ("Reader Two", "Reader Two"), ("Reader Three", "Reader Three"),
                     ("Reader Four", "Reader Four"), ("Reader Five", "Reader Five"), ("图书", "Books")]
        let apps = names.enumerated().map { index, pair in
            DefaultApplicationCandidate(url: URL(fileURLWithPath: "/Applications/FileMint QA \(index).app"),
                                        id: "\(index)", name: pair.0, originalName: pair.1)
        }
        var writes: [String] = []
        let picker = DefaultApplicationPicker(type: .pdf, language: .chinese, snapshot: (apps, apps[0].id)) { app in
            writes.append(app.id)
            throw DefaultApplicationError.notApplied
        }
        let opened = Task { await picker.present() }
        defer { picker.cancel() }
        try await wait("picker window") { window != nil }
        try check(picker.results.count == 6 && picker.selectionID == apps[0].id && !picker.canApply,
                  "The unfiltered list or initial default is incomplete")
        picker.query = "PREVIEW"
        try check(picker.results.map(\.id) == [apps[0].id] && !picker.canApply, "Original-name search failed")
        picker.query = "图书"
        try check(picker.results.map(\.id) == [apps[5].id] && !picker.canApply, "Localized search selected a replacement implicitly")
        picker.move(1)
        try check(picker.selectionID == apps[5].id && picker.canApply, "Arrow did not select the match")
        picker.apply()
        try check(picker.isApplying, "Apply did not reserve the picker")
        picker.apply()
        try await wait("failed write") { !picker.isApplying && picker.feedback != nil }
        try check(writes == [apps[5].id] && picker.selectionID == apps[5].id && window != nil,
                  "Failed apply closed the picker, lost its selection, or wrote twice")
        picker.query = "unmatched"
        try check(picker.results.isEmpty && !picker.canApply, "Filtering away the selection left Apply enabled")
        picker.escape()
        try check(picker.query.isEmpty && picker.results.count == 6 && !picker.canApply, "Escape did not restore the list")
        picker.cancel()
        await opened.value
        print("PASS default application: one-use ticket, compact panel, complete list, localized search, explicit selection, failure and cancellation")
    }

    static func runFixture(_ identifier: String) async throws {
        guard identifier.hasPrefix("io.github.daigua.filemint.associationqa."),
              let type = UTType(identifier), type.isDeclared,
              type.preferredFilenameExtension?.hasPrefix("fmqa") == true else {
            throw Failure(description: "This mode requires a disposable FileMint QA type")
        }
        let apps = DefaultApplicationWorkspace.snapshot(for: type).apps
        try check(Set(apps.map { $0.url.lastPathComponent }) == ["ReaderA.app", "ReaderB.app"],
                  "The fixture must have only its two dedicated readers")
        try await checkTicket(for: type, interactive: true)
    }

    private static func checkTicket(for type: UTType, interactive: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("filemint-default-application-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        guard let suffix = type.preferredFilenameExtension else { throw Failure(description: "Missing fixture extension") }
        let source = root.appendingPathComponent("sample").appendingPathExtension(suffix)
        let bytes = Data("FileMint QA".utf8)
        try bytes.write(to: source)
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.fileTools.isEnabled = true; preferences.fileTools.defaultApplication = true
        preferences.language = .chinese
        let preferencesFile = root.appendingPathComponent("preferences.json")
        try FileMintPreferencesStore(fileURL: preferencesFile).save(preferences)
        let tickets = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
        let coordinator = FileOperationCoordinator(store: PendingFileMoveStore(file: root.appendingPathComponent("move.json")),
            tickets: tickets, preferencesFile: preferencesFile)
        let before = NSWorkspace.shared.urlForApplication(toOpen: type)
        let captured = try DefaultApplicationSelection.capture([source])
        let ticket = try tickets.enqueue(.defaultApplication(captured))
        coordinator.enqueue(ticket)
        try await wait("ticket panel") { window != nil }
        guard let panel = window else { throw Failure(description: "The ticket did not open the picker") }
        try check(coordinator.isBusy && panel.frame.height <= 410, "The picker did not hold its operation or was too tall")
        let reused = try tickets.consume(ticket)
        try check(reused == nil && NSWorkspace.shared.urlForApplication(toOpen: type) == before,
                  "Opening the picker wrote an association or left its ticket reusable")
        if !interactive { panel.close() }
        try await wait("ticket completion", timeout: interactive ? .seconds(120) : .seconds(5)) { !coordinator.isBusy }
        let after = NSWorkspace.shared.urlForApplication(toOpen: type)
        try check(try Data(contentsOf: source) == bytes, "The source file changed")
        if interactive {
            try check(after == NSWorkspace.shared.urlForApplication(toOpen: source), "The synthetic type and file resolved to different readers")
            if after == before {
                print("CANCELLED default application fixture: original association and source preserved")
            } else {
                print("PASS default application fixture: native panel, confirmed type/file readback and unchanged source")
            }
        } else {
            try check(after == before, "Closing the picker changed the association")
        }
    }

    private static var window: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == "defaultApplication.panel" && $0.isVisible }
    }

    private static func wait(_ description: String, timeout: Duration = .seconds(5),
                             until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else { throw Failure(description: "Timed out: \(description)") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func check(_ condition: Bool, _ description: String) throws {
        if !condition { throw Failure(description: description) }
    }
}

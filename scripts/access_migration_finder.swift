import AppKit
import FinderSync
import FileMintCore

/// A real, separately enabled Finder extension. Only the host writes test files.
final class AccessFinderSync: FIFinderSync {
    private var actions: [Int: URL] = [:]
    private var nextTag = 0

    override init() {
        super.init()
        refresh()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(refresh),
            name: NSNotification.Name(AccessQA.identifier + ".changed"), object: nil)
    }
    @objc private func refresh() {
        let result = FileMintPreferencesStore(fileURL: AccessQA.preferences).loadWithStatus()
        FIFinderSyncController.default().directoryURLs = result.requiresRecovery ? [] :
            FolderScope.observationRoots(for: result.preferences.monitoredFolderURLs, home: AccessQA.home)
    }
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer,
              let target = FIFinderSyncController.default().targetedURL() else { return nil }
        let loaded = FileMintPreferencesStore(fileURL: AccessQA.preferences).loadWithStatus()
        guard !loaded.requiresRecovery,
              FolderScope.contains(target, in: loaded.preferences.monitoredFolderURLs) else { return nil }
        nextTag += 1
        actions[nextTag] = target
        if actions.count > 100 { actions.removeValue(forKey: nextTag - 100) }
        let item = NSMenuItem(title: "FileMint Access QA · 测试此目录", action: #selector(probe(_:)), keyEquivalent: "")
        item.target = self
        item.tag = nextTag
        let menu = NSMenu()
        menu.addItem(item)
        return menu
    }
    @objc private func probe(_ item: NSMenuItem) {
        guard let target = actions.removeValue(forKey: item.tag),
              let request = try? AccessQA.tickets.enqueue(directory: target, templateID: AccessQA.templateID),
              let url = AccessQA.translated(request, to: AccessQA.scheme) else { return }
        NSWorkspace.shared.open(url)
    }
}

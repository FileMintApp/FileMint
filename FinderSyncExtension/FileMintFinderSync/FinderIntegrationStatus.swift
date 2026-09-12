import FinderSync

@MainActor
enum FinderIntegrationStatus {
    static var isEnabled: Bool { FIFinderSyncController.isExtensionEnabled }
    static func showSettings() { FIFinderSyncController.showExtensionManagementInterface() }
}

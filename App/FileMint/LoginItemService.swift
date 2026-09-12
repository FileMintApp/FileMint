import Foundation
import ServiceManagement
import FileMintCore

@MainActor
struct LoginItemService {
    var isInstalled: Bool {
        LoginItemPolicy.isInstalled(Bundle.main.bundleURL,
            userHome: DefaultFolders.resolvedUserHomeDirectory(fileManager: .default))
    }

    var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered: .notRegistered
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    func setEnabled(_ enabled: Bool) async throws {
        let service = SMAppService.mainApp
        if enabled {
            guard state != .enabled && state != .requiresApproval else { return }
            try service.register()
        } else if state == .enabled || state == .requiresApproval {
            try await service.unregister()
        }
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

import Foundation

public enum LoginItemState: Sendable {
    case notRegistered, enabled, requiresApproval, notFound
}

public enum LoginItemPolicy {
    public static func shouldRegisterInitially(wantsEnabled: Bool, attempted: Bool, status: LoginItemState, installed: Bool) -> Bool {
        installed && wantsEnabled && !attempted && (status == .notRegistered || status == .notFound)
    }

    public static func isInstalled(_ appURL: URL, userHome: URL) -> Bool {
        let parent = appURL.standardizedFileURL.deletingLastPathComponent().path
        return parent == "/Applications" || parent == userHome.appendingPathComponent("Applications").path
    }
}

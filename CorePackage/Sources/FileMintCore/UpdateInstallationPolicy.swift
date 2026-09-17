import Foundation

/// Bind Sparkle's independently fetched feed to the release the user accepted.
public enum UpdateInstallationPolicy {
    public static func appcastURL(for update: AppUpdate) -> URL {
        update.downloadURL.deletingLastPathComponent().appendingPathComponent("appcast.xml")
    }

    public static func accepts(_ update: AppUpdate, displayVersion: String, downloadURL: URL?,
                               size: UInt64, informationOnly: Bool, delta: Bool) -> Bool {
        !informationOnly && !delta && displayVersion == update.version.description &&
            downloadURL == update.downloadURL && size == UInt64(update.size)
    }

    public static func canRestart(hasDraft: Bool, pendingCreations: Int, hasModal: Bool) -> Bool {
        !hasDraft && pendingCreations == 0 && !hasModal
    }
}

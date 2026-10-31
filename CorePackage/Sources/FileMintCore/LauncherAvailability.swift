import Foundation

public enum LauncherAvailability {
    /// The integration's API floor is independent of FileMint's macOS 13.0 minimum.
    public static func isSupported(on version: OperatingSystemVersion) -> Bool {
        version.majorVersion > 13 || (version.majorVersion == 13 && version.minorVersion >= 3)
    }
}

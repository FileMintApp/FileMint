import Foundation
import Testing
@testable import FileMintCore

@Suite("Launcher system requirements")
struct LauncherAvailabilityTests {
    @Test("Only the optional integration requires macOS 13.3", arguments: [
        (12, 6, 9, false), (13, 0, 0, false), (13, 2, 1, false),
        (13, 3, 0, true), (13, 3, 1, true), (13, 6, 0, true),
        (14, 0, 0, true), (27, 2, 0, true)
    ])
    func supportedSystem(major: Int, minor: Int, patch: Int, expected: Bool) {
        let version = OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: patch)
        #expect(LauncherAvailability.isSupported(on: version) == expected)
    }
}

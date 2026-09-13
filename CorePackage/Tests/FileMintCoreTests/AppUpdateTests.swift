import FileMintCore
import Foundation
import Testing

@Suite("About and stable release updates")
struct AppUpdateTests {
    private let hash = String(repeating: "a", count: 64)

    @Test("numeric versions compare correctly across digit and component boundaries")
    func versionOrdering() throws {
        #expect(try #require(ReleaseVersion("0.10.0")) > #require(ReleaseVersion("0.9.9")))
        #expect(try #require(ReleaseVersion("1.0.0")) > #require(ReleaseVersion("0.99.99")))
        #expect(try #require(ReleaseVersion("0.2.10")) > #require(ReleaseVersion("0.2.9")))
        #expect(ReleaseVersion("v0.2.0") == ReleaseVersion("0.2.0"))
    }

    @Test("ambiguous and non-stable versions are rejected", arguments: [
        "", "0.2", "0.2.0.1", "v", "0.3.0-beta.1", "0.3.0+build", "01.2.0",
        "0.-1.0", " 0.2.0", "0.2.0\n", "０.2.0", "0.2.999999999999999999999999999"
    ])
    func invalidVersion(value: String) {
        #expect(ReleaseVersion(value) == nil)
    }

    @Test("current and older releases never offer a downgrade", arguments: ["v0.2.0", "v0.1.9"])
    func noDowngrade(tag: String) throws {
        #expect(try AppUpdatePolicy.availableUpdate(from: release(tag: tag), currentVersion: "0.2.0") == nil)
    }

    @Test("new stable release selects its exact installer and checksum")
    func stableUpdate() throws {
        let result = try AppUpdatePolicy.availableUpdate(from: release(tag: "v0.10.0"), currentVersion: "0.2.0")
        let update = try #require(result)
        #expect(update.version.description == "0.10.0")
        #expect(update.fileName == "FileMint-0.10.0.dmg")
        #expect(update.checksumURL.lastPathComponent == "FileMint-0.10.0.dmg.sha256")
        #expect(update.releaseURL.absoluteString == "https://github.com/FileMintApp/FileMint/releases/tag/v0.10.0")
        #expect(update.digest == hash)
        #expect(update.size == 512)
    }

    @Test("bad responses and prereleases are errors, not up-to-date results")
    func invalidResponses() throws {
        #expect(throws: UpdateValidationError.invalidRelease) {
            try AppUpdatePolicy.availableUpdate(from: Data("{}".utf8), currentVersion: "0.2.0")
        }
        for flag in ["draft", "prerelease"] {
            let data = try release { $0[flag] = true }
            #expect(throws: UpdateValidationError.invalidRelease) {
                try AppUpdatePolicy.availableUpdate(from: data, currentVersion: "0.2.0")
            }
        }
        #expect(throws: UpdateValidationError.invalidVersion) {
            try AppUpdatePolicy.availableUpdate(from: release(), currentVersion: "unknown")
        }
        #expect(throws: UpdateValidationError.invalidVersion) {
            try AppUpdatePolicy.availableUpdate(from: release(tag: "v0.3.0-rc.1"), currentVersion: "0.2.0")
        }
    }

    @Test("missing, duplicate, incomplete and oversized assets cannot be downloaded", arguments: [
        "missing-checksum", "duplicate-installer", "unuploaded", "oversized", "empty", "wrong-version"
    ])
    func invalidAssets(scenario: String) throws {
        let data = try release { value in
            var assets = value["assets"] as! [[String: Any]]
            switch scenario {
            case "missing-checksum": assets.removeLast()
            case "duplicate-installer": assets.append(assets[0])
            case "unuploaded": assets[0]["state"] = "new"
            case "oversized": assets[0]["size"] = AppUpdatePolicy.maximumInstallerSize + 1
            case "empty": assets[0]["size"] = 0
            default: assets[0]["name"] = "FileMint-0.2.0.dmg"
            }
            value["assets"] = assets
        }
        #expect(throws: UpdateValidationError.missingAssets) {
            try AppUpdatePolicy.availableUpdate(from: data, currentVersion: "0.2.0")
        }
    }

    @Test("release metadata cannot redirect downloads to another origin or repository", arguments: [
        "http://github.com/FileMintApp/FileMint/releases/download/v0.3.0/FileMint-0.3.0.dmg",
        "https://github.com/another/FileMint/releases/download/v0.3.0/FileMint-0.3.0.dmg",
        "https://github.com.evil.example/FileMintApp/FileMint/releases/download/v0.3.0/FileMint-0.3.0.dmg",
        "https://github.com/FileMintApp/FileMint/releases/download/v0.2.0/FileMint-0.3.0.dmg",
        "file:///tmp/FileMint-0.3.0.dmg"
    ])
    func untrustedDownload(url: String) throws {
        let data = try release { value in
            var assets = value["assets"] as! [[String: Any]]
            assets[0]["browser_download_url"] = url
            value["assets"] = assets
        }
        #expect(throws: UpdateValidationError.untrustedURL) {
            try AppUpdatePolicy.availableUpdate(from: data, currentVersion: "0.2.0")
        }
        let page = try release { $0["html_url"] = "https://example.com/release" }
        #expect(throws: UpdateValidationError.untrustedURL) {
            try AppUpdatePolicy.availableUpdate(from: page, currentVersion: "0.2.0")
        }
    }

    @Test("GitHub CDN redirects are allowed but insecure and lookalike hosts are rejected")
    func redirectPolicy() throws {
        for value in [
            AppUpdatePolicy.latestReleaseURL.absoluteString,
            "https://github.com/FileMintApp/FileMint/releases/download/v0.3.0/FileMint-0.3.0.dmg",
            "https://release-assets.githubusercontent.com/github-production-release-asset/123?token=example",
            "https://objects.githubusercontent.com/github-production-release-asset/123"
        ] { #expect(AppUpdatePolicy.allowsNetworkURL(try #require(URL(string: value)))) }
        for value in [
            "http://release-assets.githubusercontent.com/file", "https://example.com/file",
            "https://github.com.evil.example/file", "https://release-assets.githubusercontent.com.evil.example/file",
            "https://github.com/another/FileMint/releases/download/file", "file:///tmp/file",
            "https://user:password@github.com/FileMintApp/FileMint/releases/download/file",
            "https://release-assets.githubusercontent.com:8080/file", "https://api.github.com/user"
        ] { #expect(!AppUpdatePolicy.allowsNetworkURL(try #require(URL(string: value)))) }
    }

    @Test("checksums must identify this installer and match every provided digest")
    func checksums() throws {
        let name = "FileMint-0.3.0.dmg"
        #expect(try AppUpdatePolicy.checksum(from: Data("\(hash)  \(name)\n".utf8), fileName: name) == hash)
        #expect(try AppUpdatePolicy.checksum(from: Data("\(hash.uppercased()) *\(name)\r\n".utf8), fileName: name) == hash)
        for value in ["", "\(hash)  other.dmg", "bad  \(name)", "\(hash)  \(name)\n\(hash)  extra.dmg", "\(hash)\(name)"] {
            #expect(throws: UpdateValidationError.invalidChecksum) {
                try AppUpdatePolicy.checksum(from: Data(value.utf8), fileName: name)
            }
        }
        try AppUpdatePolicy.verifyChecksum(hash, expected: hash, assetDigest: nil)
        try AppUpdatePolicy.verifyChecksum(hash, expected: hash.uppercased(), assetDigest: hash)
        #expect(throws: UpdateValidationError.checksumMismatch) {
            try AppUpdatePolicy.verifyChecksum(String(repeating: "b", count: 64), expected: hash, assetDigest: nil)
        }
        #expect(throws: UpdateValidationError.checksumMismatch) {
            try AppUpdatePolicy.verifyChecksum(hash, expected: hash, assetDigest: String(repeating: "b", count: 64))
        }
    }

    @Test("legacy releases may omit API digest, but malformed supplied digests block updates")
    func optionalDigest() throws {
        for digest in [NSNull(), "sha256:invalid"] as [Any] {
            let data = try release { value in
                var assets = value["assets"] as! [[String: Any]]
                assets[0]["digest"] = digest
                value["assets"] = assets
            }
            if digest is NSNull {
                #expect(try AppUpdatePolicy.availableUpdate(from: data, currentVersion: "0.2.0")?.digest == nil)
            } else {
                #expect(throws: UpdateValidationError.invalidChecksum) {
                    try AppUpdatePolicy.availableUpdate(from: data, currentVersion: "0.2.0")
                }
            }
        }
    }

    @Test("About preserves the requested credits and all update copy is localized")
    func aboutAndLocalization() {
        #expect(FileMintAbout.copyright == "XiaoDaiGua-Ray")
        #expect(FileMintAbout.developers == ["XiaoDaiGua-Ray", "GPT-Astra"])
        #expect(FileMintStrings.text(.about, language: .chinese) == "关于")
        let keys: [FileMintTextKey] = [.about, .aboutFileMint, .version, .copyright, .developers, .projectPage,
            .privacyPolicy, .license, .updates, .checkForUpdates, .downloadUpdate, .openInstaller, .releaseNotes,
            .availableVersion, .updateIdle, .updateChecking, .updateCurrent, .updateAvailable, .updateDownloading,
            .updateVerifying, .updateReady, .updateInstallHint, .updateSaveHint, .updateInstallerAuthorizationFailed,
            .updateNetworkFailed, .updateChecksumFailed,
            .updateMissingAssets, .updateInvalidRelease, .updateNoRelease, .updateRateLimited, .updateDownloadFailed,
            .updateOpenFailed]
        for key in keys {
            let english = FileMintStrings.text(key, language: .english)
            let chinese = FileMintStrings.text(key, language: .chinese)
            #expect(english != key.rawValue && chinese != key.rawValue)
            #expect(english != chinese)
        }
    }

    @Test("installer quarantine keeps internet checks and rejects sandbox execution blocks")
    func installerQuarantineConsent() {
        for value in ["0083;time;FileMint;event", "0283;time;FileMint;event", "0383;time;;event", "0081;time;Browser;"] {
            #expect(InstallerQuarantinePolicy.allowsGatekeeperAssessment(value))
        }
        for value in ["0086;time;FileMint;", "0087;time;FileMint;", "0287;time;FileMint;", "0387;time;FileMint;", "0082;time;FileMint;", "0000", "", "not-hex", ";missing"] {
            #expect(!InstallerQuarantinePolicy.allowsGatekeeperAssessment(value))
        }
        #expect(!InstallerQuarantinePolicy.allowsGatekeeperAssessment(nil))
    }

    private func release(tag: String = "v0.3.0", change: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let name = "FileMint-\(version).dmg"
        let base = "https://github.com/FileMintApp/FileMint/releases"
        var value: [String: Any] = [
            "tag_name": tag, "html_url": "\(base)/tag/\(tag)", "draft": false, "prerelease": false,
            "assets": [
                ["name": name, "browser_download_url": "\(base)/download/\(tag)/\(name)",
                 "size": 512, "state": "uploaded", "digest": "sha256:\(hash)"],
                ["name": "\(name).sha256", "browser_download_url": "\(base)/download/\(tag)/\(name).sha256",
                 "size": 85, "state": "uploaded"]
            ]
        ]
        change(&value)
        return try JSONSerialization.data(withJSONObject: value)
    }
}

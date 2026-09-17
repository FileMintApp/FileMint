import FileMintCore
import Foundation
import Testing

@Suite("Automatic update installation safety")
struct UpdateInstallationTests {
    private func update() throws -> AppUpdate {
        let data = Data("""
        {"tag_name":"v0.6.0","html_url":"https://github.com/FileMintApp/FileMint/releases/tag/v0.6.0",
         "draft":false,"prerelease":false,"assets":[
          {"name":"FileMint-0.6.0.dmg","size":512,"state":"uploaded",
           "browser_download_url":"https://github.com/FileMintApp/FileMint/releases/download/v0.6.0/FileMint-0.6.0.dmg"},
          {"name":"FileMint-0.6.0.dmg.sha256","size":85,"state":"uploaded",
           "browser_download_url":"https://github.com/FileMintApp/FileMint/releases/download/v0.6.0/FileMint-0.6.0.dmg.sha256"}]}
        """.utf8)
        let result = try AppUpdatePolicy.availableUpdate(from: data, currentVersion: "0.5.4")
        return try #require(result)
    }

    @Test("installation stays on the version and archive the user accepted")
    func selectedRelease() throws {
        let update = try update()
        #expect(UpdateInstallationPolicy.appcastURL(for: update).absoluteString ==
            "https://github.com/FileMintApp/FileMint/releases/download/v0.6.0/appcast.xml")
        #expect(UpdateInstallationPolicy.accepts(update, displayVersion: "0.6.0", downloadURL: update.downloadURL,
            size: 512, informationOnly: false, delta: false))
        for version in ["0.5.4", "0.7.0", "0.6.0-beta.1", "v0.6.0"] {
            #expect(!UpdateInstallationPolicy.accepts(update, displayVersion: version, downloadURL: update.downloadURL,
                size: 512, informationOnly: false, delta: false))
        }
        for url in [nil, URL(string: "https://example.com/FileMint-0.6.0.dmg"),
                    URL(string: update.downloadURL.absoluteString + "?replacement=1")] {
            #expect(!UpdateInstallationPolicy.accepts(update, displayVersion: "0.6.0", downloadURL: url,
                size: 512, informationOnly: false, delta: false))
        }
        for size: UInt64 in [0, 511, 513, UInt64.max] {
            #expect(!UpdateInstallationPolicy.accepts(update, displayVersion: "0.6.0", downloadURL: update.downloadURL,
                size: size, informationOnly: false, delta: false))
        }
        #expect(!UpdateInstallationPolicy.accepts(update, displayVersion: "0.6.0", downloadURL: update.downloadURL,
            size: 512, informationOnly: true, delta: false))
        #expect(!UpdateInstallationPolicy.accepts(update, displayVersion: "0.6.0", downloadURL: update.downloadURL,
            size: 512, informationOnly: false, delta: true))
    }

    @Test("restart waits for drafts, asynchronous creation and modal editing")
    func restartSafety() {
        for draft in [true, false] {
            for pending in [0, 1, 2] {
                for modal in [true, false] {
                    #expect(UpdateInstallationPolicy.canRestart(hasDraft: draft, pendingCreations: pending,
                        hasModal: modal) == (!draft && pending == 0 && !modal))
                }
            }
        }
    }

    @Test("update action explains automatic installation and restart in both languages")
    func updateCopy() {
        #expect(FileMintStrings.text(.downloadUpdate, language: .chinese) == "更新并重启")
        #expect(FileMintStrings.text(.downloadUpdate, language: .english) == "Update and Restart")
        for key: FileMintTextKey in [.updateInstalling, .updateFinishWork, .updateRestartNow, .updateInstallFailed] {
            #expect(FileMintStrings.text(key, language: .chinese) != key.rawValue)
            #expect(FileMintStrings.text(key, language: .english) != key.rawValue)
        }
    }
}

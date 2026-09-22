import Foundation
import CryptoKit

// The fixture key exists only in this process. It never reads or changes the
// production update key in Keychain and never writes a private key to disk.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let key = Curve25519.Signing.PrivateKey()
let publicKey = key.publicKey.rawRepresentation.base64EncodedString()

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw NSError(domain: "FixtureBuild", code: Int(process.terminationStatus)) }
}

for folder in ["installation", "payload"] {
    let app = root.appendingPathComponent(folder + "/UpgradeQA.app")
    let infoURL = app.appendingPathComponent("Contents/Info.plist")
    var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as! [String: Any]
    info["SUPublicEDKey"] = publicKey
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
    try run("/bin/bash", ["scripts/sign_app.sh", app.path])
}
let archive = root.appendingPathComponent("server/UpgradeQA.zip")
try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", root.appendingPathComponent("payload/UpgradeQA.app").path, archive.path])
let bytes = try Data(contentsOf: archive)
let signature = try key.signature(for: bytes).base64EncodedString()
let config = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("fixture.json"))) as! [String: Any]
let port = config["port"] as! Int
let feed = """
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>Isolated update QA</title><item>
<title>QA build 2</title><sparkle:version>2</sparkle:version><sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
<enclosure url="http://127.0.0.1:\(port)/UpgradeQA.zip" length="\(bytes.count)" type="application/octet-stream" sparkle:edSignature="\(signature)"/>
</item></channel></rss>
"""
try Data(feed.utf8).write(to: root.appendingPathComponent("server/appcast.xml"))
print("PASS signed isolated update fixture; ephemeral Ed25519 key stayed in memory")

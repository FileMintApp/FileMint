import Foundation
import CryptoKit

// No production key or feed is read. The fixture key never leaves this process.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let key = Curve25519.Signing.PrivateKey()
for folder in ["installation", "payload"] {
    let url = root.appendingPathComponent(folder + "/FileMintAccessQA.app/Contents/Info.plist")
    var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as! [String: Any]
    info["SUPublicEDKey"] = key.publicKey.rawRepresentation.base64EncodedString()
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: url)
}
func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw NSError(domain: "AccessQABuild", code: Int(process.terminationStatus)) }
}
try run("/usr/bin/env", ["python3", "scripts/access_migration_fixture.py", "sign", root.path])
let archive = root.appendingPathComponent("server/FileMintAccessQA.zip")
try run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", root.appendingPathComponent("payload/FileMintAccessQA.app").path, archive.path])
let bytes = try Data(contentsOf: archive)
let signature = try key.signature(for: bytes).base64EncodedString()
let config = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("fixture.json"))) as! [String: Any]
let port = config["port"] as! Int
let feed = """
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>FileMint access QA</title><item>
<title>Non-sandbox host prototype</title><sparkle:version>28</sparkle:version><sparkle:shortVersionString>0.6.9</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
<enclosure url="http://127.0.0.1:\(port)/FileMintAccessQA.zip" length="\(bytes.count)" type="application/octet-stream" sparkle:edSignature="\(signature)"/>
</item></channel></rss>
"""
try Data(feed.utf8).write(to: root.appendingPathComponent("server/appcast.xml"))
print("PASS isolated archive signature; fixture private key stayed in memory")

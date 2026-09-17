import CryptoKit
import Foundation

// Public-key-only verification; safe for CI and never accesses the Keychain.
guard CommandLine.arguments.count == 4,
      let publicBytes = Data(base64Encoded: CommandLine.arguments[2]), publicBytes.count == 32,
      let signature = Data(base64Encoded: CommandLine.arguments[3]), signature.count == 64 else {
    fputs("Expected archive, base64 public key and Ed25519 signature\n", stderr)
    exit(2)
}
do {
    let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]), options: .mappedIfSafe)
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicBytes)
    guard key.isValidSignature(signature, for: bytes) else {
        fputs("Update archive signature mismatch\n", stderr)
        exit(1)
    }
    print("Verified update archive Ed25519 signature")
} catch {
    fputs("Cannot verify update archive signature\n", stderr)
    exit(1)
}

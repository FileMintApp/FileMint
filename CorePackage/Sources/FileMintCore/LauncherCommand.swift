import Darwin
import Foundation

/// A local export configuration, never a script runner.
public struct LauncherCommand: Sendable {
    public let title: String
    public let invocation: ExternalInvocation
    public let runtimeName: Bool

    public init(title: String, invocation: ExternalInvocation, runtimeName: Bool = false) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.utf8.count <= 256,
              !title.unicodeScalars.contains(where: { CharacterSet.controlCharacters.union(.newlines).contains($0) }) else {
            throw ExternalInvocationError.invalidRequest
        }
        if runtimeName {
            guard case .draft(let request) = invocation, request.name == nil else { throw ExternalInvocationError.invalidRequest }
        }
        self.title = title
        self.invocation = invocation
        self.runtimeName = runtimeName
    }

    public func raycastScript(bundleIdentifier: String = "io.github.daigua.filemint", scheme: String = "filemint") throws -> String {
        guard bundleIdentifier.utf8.count <= 256,
              bundleIdentifier.range(of: "^[A-Za-z0-9][A-Za-z0-9.-]+$", options: .regularExpression) != nil,
              scheme.utf8.count <= 64,
              scheme.range(of: "^[a-z][a-z0-9+.-]*$", options: .regularExpression) != nil else {
            throw ExternalInvocationError.invalidRequest
        }
        let canonical = try ExternalDraftRoute.string(for: invocation)
        let url = scheme + canonical.dropFirst("filemint".count)
        guard url.utf8.count <= ExternalDraftLimits.urlBytes else { throw ExternalInvocationError.payloadTooLarge }
        let argument = runtimeName ? "# @raycast.argument1 {\"type\":\"text\",\"placeholder\":\"File name\",\"percentEncoded\":true}\n" : ""
        let name = runtimeName ? """
        if [ -z "$1" ] || [ "${#1}" -gt 3072 ]; then
          printf '%s\\n' 'Enter a file name within the supported size.' >&2
          exit 2
        fi
        url="${url}&name=$1"
        """ : ""
        // All fixed values are percent-encoded data. The only runtime value is
        // expanded as one quoted argv value; it is never parsed as shell code.
        return """
        #!/bin/bash
        # @raycast.schemaVersion 1
        # @raycast.title \(title)
        # @raycast.mode silent
        # @raycast.packageName FileMint
        \(argument)set -eu
        export LC_ALL=C
        if [ "$#" -ne \(runtimeName ? 1 : 0) ]; then
          printf '%s\\n' 'This command received an unexpected argument count.' >&2
          exit 2
        fi
        url='\(url)'
        \(name)
        if [ "${#url}" -gt 16384 ]; then
          printf '%s\\n' 'This request is too large. Shorten it or use native Shortcuts.' >&2
          exit 2
        fi
        if ! /usr/bin/open -b '\(bundleIdentifier)' "$url" >/dev/null 2>&1; then
          printf '%s\\n' 'Could not send the request. Check that FileMint is installed.' >&2
          exit 1
        fi
        # macOS accepting the URL is not a file-creation receipt. Review FileMint.

        """
    }

    /// Prepare an owner-only executable before atomically replacing the exact
    /// save-panel destination. Failure before rename preserves its old bytes.
    public func exportRaycast(to destination: URL, bundleIdentifier: String = "io.github.daigua.filemint",
                              scheme: String = "filemint", replacing expected: LauncherScriptSnapshot? = nil) throws {
        let data = Data(try raycastScript(bundleIdentifier: bundleIdentifier, scheme: scheme).utf8)
        guard OpenWithPolicy.isLocalFileURL(destination), !destination.lastPathComponent.isEmpty,
              destination.path != "/" else { throw ExternalInvocationError.invalidRequest }
        var coordinationError: NSError?
        var outcome: Result<Void, Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: destination, options: .forReplacing,
            error: &coordinationError) { target in
                outcome = Result {
                    guard target.standardizedFileURL == destination.standardizedFileURL else { throw ExternalInvocationError.destinationUnavailable }
                    if let expected { try expected.validate(at: target) }
                    let manager = FileManager.default
                    let stagingDirectory = try manager.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                           appropriateFor: target, create: true)
                    defer { try? manager.removeItem(at: stagingDirectory) }
                    let staging = stagingDirectory.appendingPathComponent("FileMint-command.sh")
                    try data.write(to: staging, options: .withoutOverwriting)
                    try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: staging.path)
                    if let expected { try expected.validate(at: target) }
                    // rename replaces a link itself and cannot replace a directory.
                    guard rename(staging.path, target.path) == 0 else {
                        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                    }
                }
            }
        if let coordinationError { throw coordinationError }
        guard let outcome else { throw ExternalInvocationError.unavailable }
        try outcome.get()
    }
}

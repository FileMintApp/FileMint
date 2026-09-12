# Distribution

## Current channel: GitHub provenance

The owner does not currently have a paid Apple Developer account. Release 0.2
therefore uses GitHub-hosted builds, universal ad-hoc-signed app bundles, a DMG,
a portable SHA-256 checksum and GitHub artifact attestations. Installation
limitations must remain visible in README, release notes and INSTALL.md.

An ad-hoc signature validates bundle integrity but does not identify a trusted
Apple developer. GitHub provenance identifies a repository/workflow/source
commit; it does not grant Gatekeeper or Finder extension trust.

CI also retains a reviewable DMG and attests trusted main-branch builds.
The attestation job never runs for pull requests and has its own narrowly scoped
OIDC/attestation permissions. Ordinary test/build jobs cannot mint attestations.

The Release workflow checks out the version tag, verifies behavior, builds both
architectures, signs nested code first, packages and verifies the DMG, attests
its final bytes, verifies that attestation and only then publishes the assets.
It never replaces existing release assets; use a fresh version for corrections.

```sh
APP_VERSION=0.2.0 make package
# After reviewing docs/ACCEPTANCE.md and committing the version:
git tag v0.2.0
git push origin main v0.2.0
```

Release evidence should include the Actions URL, downloaded asset checksum,
attestation verification and actual runtime results, not just build success.

## Standing release policy

GitHub Releases and GitHub artifact attestations remain the default for all
future distribution. Apple Developer credentials are not a release prerequisite.
Any change of channel needs a new owner decision. The optional low-level Apple
signing helpers are not used by the default workflow and confer no Apple trust
on the GitHub provenance build.

The sandbox exception is limited to the application-owned FileMint support
directory. The main app owns destination bookmarks and writes. Finder uses
expiring local request tickets, with no dependency on App Group provisioning.

## Primary references

- [Apple: clipboard strings](https://developer.apple.com/documentation/appkit/nspasteboard/string%28fortype%3A%29)
- [Apple: Finder Sync](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
- [Apple: notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub: artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)

# Distribution

## Current channel: GitHub provenance

The owner does not currently have a paid Apple Developer account. Release 0.5
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

Local packaging also uses a temporary build directory and unregisters/removes
its own app and extension on exit. Xcode automatically registers macOS products;
leaving that development copy discoverable can make Finder load it instead of
the installed release. Do not leave packaging or mounted-image registrations
behind after installation checks.

```sh
APP_VERSION=0.5.1 make package
# After reviewing docs/ACCEPTANCE.md and committing the version:
git tag v0.5.1
git push origin main v0.5.1
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

## In-app updates

About and both app menus use the public GitHub latest-release API. No credentials
or additional update server are required. Continue publishing stable tags in
`vMAJOR.MINOR.PATCH` format with both `FileMint-VERSION.dmg` and
`FileMint-VERSION.dmg.sha256`, as the existing packaging workflow does. Do not
rename or replace assets after publication. Drafts and prereleases are excluded.

The app downloads only after the user confirms a destination in NSSavePanel,
validates the exact version's asset URLs,
restricts redirects to GitHub release hosts, checks the size and SHA-256, and
compares the GitHub asset digest when present. The private cache is used only
for verification; verified bytes are atomically saved to the authorized URL.
It preserves internet quarantine and rejects sandbox no-user-consent execution
blocks. Saved installers are revalidated before each open. The quarantine
attribute is never removed or patched to bypass a system block.
Users quit the app and replace it through the opened DMG themselves, eject the
installer volume, then reopen the copy in Applications. Cached DMG cleanup does
not eject a mounted volume. This is
download integrity verification; the app does not automatically verify artifact
attestations or claim Apple notarization. A newly published version needs a
higher marketing version before existing installations offer it as an update.

Versions 0.3.0 through 0.5.0 downloaded into a private sandbox cache and could
produce a no-user-consent execution block. Upgrading those versions requires
downloading the 0.5.1 installer through a browser; their old download code cannot
repair itself before installation. The fixed save-panel flow applies to later
downloads from 0.5.1 and newer.

The update client follows the [GitHub Releases API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)
and adds Apple's [outbound network entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client)
to the main app only. Finder remains offline.

## Primary references

- [Apple: clipboard strings](https://developer.apple.com/documentation/appkit/nspasteboard/string%28fortype%3A%29)
- [Apple: Finder Sync](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
- [Apple: notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub: artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)

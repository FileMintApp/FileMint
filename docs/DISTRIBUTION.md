# Distribution

## Developer ID releases from 0.5.2

The historical 0.5.1 release uses GitHub-hosted builds, universal ad-hoc-signed
app bundles, a DMG, a portable SHA-256 checksum and GitHub artifact attestations.
Its installation limitations remain visible in README, release notes and
INSTALL.md. Do not describe that already-published artifact as Apple notarized.

An ad-hoc signature validates bundle integrity but does not identify a trusted
Apple developer. GitHub provenance identifies a repository/workflow/source
commit; it does not grant Gatekeeper or Finder extension trust.

The published 0.5.1 GitHub attestation refers only to that historical Actions
build. A locally built release cannot claim GitHub Actions build provenance.

Public releases starting with 0.5.2 are built on the owner's Mac from a clean, tagged commit.
That Mac signs the Finder extension, app and DMG with Developer ID Application,
submits the DMG to Apple, staples its ticket, verifies the mounted app and final
checksum, then uploads only the DMG and checksum to GitHub Releases. The release
command refuses missing credentials, rejected notarization or a mismatched
artifact. Existing release assets are never replaced; use a fresh version for
corrections. GitHub CI runs core tests without rebuilding the release DMG.
After publication, a GitHub job downloads and checks the uploaded DMG without
using Apple credentials or claiming it built the binary.

Local packaging also uses a temporary build directory and unregisters/removes
its own app and extension on exit. Xcode automatically registers macOS products;
leaving that development copy discoverable can make Finder load it instead of
the installed release. Do not leave packaging or mounted-image registrations
behind after installation checks.

Local `make package` still defaults to ad-hoc signing for development checks.
For a public version, update `docs/RELEASE_NOTES.md`, commit all changes and
create `vVERSION` at `HEAD`. Store Apple notarization credentials in a local
`notarytool` Keychain profile named `FileMint` (or supply the supported local
credential variables). Then run:

```sh
APP_VERSION=VERSION BUILD_NUMBER=NUMBER make release-local
APP_VERSION=VERSION make publish-local
```

The first command runs `make verify`, signs and notarizes in a temporary output
directory, checks the mounted DMG, and saves the final DMG, `.sha256` and local
source manifest under `build/`. The second checks those exact bytes and the
tagged source again, pushes `main` and the version tag if needed, creates the GitHub Release
and downloads its assets to confirm they match. It never uploads the local
source manifest or any Apple credential.

Release evidence should include the local notarization result, downloaded asset
checksum, published-release verification job and actual runtime results.

## Standing release policy

GitHub Releases remain the distribution channel. Public stable releases from
0.5.2 require local Developer ID signing and Apple notarization.
Ordinary CI runs deterministic tests only; local development may still produce
ad-hoc bundles, but they are not public stable releases.

`Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer` is the local certificate
for the authorized team. It is ignored by Git and not embedded in the app. The private key and any
encrypted `.p12` backup stay on the owner's Mac, and notarization credentials
stay in the local Keychain or another local secure store. Nothing is put in
GitHub Actions secrets. The certificate expires on 2027-02-01 UTC; arrange
renewal with the team before subsequent releases. No Developer ID Installer
certificate is needed for this DMG channel.

The Apple notarization credential is provided by the signing team, not the
GitHub organization. A dedicated App Store Connect **Team** API key consists of
a `.p8` file, Key ID and Issuer ID; an Individual API key cannot use
`notarytool`. Alternatively, an authorized team member can use an Apple Account
app-specific password. Store either option once in the local Keychain. For a
Team API key, run the following with the real key path and identifiers:

```sh
xcrun notarytool store-credentials FileMint \
  --key /local/private/AuthKey_KEYID.p8 --key-id KEYID --issuer ISSUER_ID --validate
```

No Apple Account main password or 2FA code is needed by FileMint.

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
not eject a mounted volume. This is download integrity verification; the app
does not automatically verify artifact attestations or query Apple notarization
status. A newly published version needs a
higher marketing version before existing installations offer it as an update.

Versions 0.3.0 through 0.5.0 downloaded into a private sandbox cache and could
produce a no-user-consent execution block. Upgrading those versions requires
downloading a current installer through a browser; their old download code cannot
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

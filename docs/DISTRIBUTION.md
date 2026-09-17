# Distribution

## Developer ID releases and the 0.5.3 exception

The historical 0.5.1 release uses GitHub-hosted builds, universal ad-hoc-signed
app bundles, a DMG, a portable SHA-256 checksum and GitHub artifact attestations.
Its installation limitations remain visible in README, release notes and
INSTALL.md. Do not describe that already-published artifact as Apple notarized.

An ad-hoc signature validates bundle integrity but does not identify a trusted
Apple developer. GitHub provenance identifies a repository/workflow/source
commit; it does not grant Gatekeeper or Finder extension trust.

The published 0.5.1 GitHub attestation refers only to that historical Actions
build. A locally built release cannot claim GitHub Actions build provenance.

Version 0.5.3 is a one-time early release explicitly requested by the owner while
its exact signed DMG submission was still `In Progress` at Apple. The app,
Finder extension and DMG are Developer ID signed, with hardened runtime and
secure timestamps, but there was no notarization ticket at publication. A
2026-09-15 `notarytool info` query returned `Accepted` for the exact published
DMG under submission `11ed351a-020e-4107-bfae-72d0a8daec52`. Apple publishes
the resulting ticket online, so Gatekeeper can retrieve it for this unchanged
DMG when the Mac has network access, including copies downloaded before
acceptance. The published asset and portable checksum remain unchanged and the
DMG has no stapled ticket, so offline verification can still fail. Its GitHub
release notes and installation instructions must preserve this chronology.
The 0.5.3 asset is not replaced; a future version is required for a stapled,
independently verified release.

Subsequent public stable releases are built on the owner's Mac from a clean,
tagged commit. That Mac signs the Finder extension, app and DMG with Developer
ID Application, submits the DMG to Apple, staples its ticket, verifies the
mounted app and final checksum, then uploads the validated DMG, checksum and appcast
to GitHub Releases. The normal release command refuses missing credentials,
rejected notarization or a mismatched artifact. Existing release assets are
never replaced; use a fresh version for corrections. GitHub CI runs core tests
without rebuilding the release DMG.
After publication, a GitHub job downloads and checks the uploaded DMG without
using Apple credentials or claiming it built the binary.

Local packaging also uses a temporary build directory and unregisters/removes
its own app and extension on exit. Xcode automatically registers macOS products;
leaving that development copy discoverable can make Finder load it instead of
the installed release. Do not leave packaging or mounted-image registrations
behind after installation checks.

Local `make package` still defaults to ad-hoc signing for development checks.
For a normal notarized public version after 0.5.3, update `docs/RELEASE_NOTES.md`, commit all changes and
create `vVERSION` at `HEAD`. Store Apple notarization credentials in a local
`notarytool` Keychain profile named `FileMint` (or supply the supported local
credential variables). Then run:

```sh
APP_VERSION=VERSION BUILD_NUMBER=NUMBER make release-local
APP_VERSION=VERSION make publish-local
```

The first command runs `make verify`, signs and notarizes in a temporary output
directory, checks the mounted DMG, and saves the final DMG, `.sha256`, appcast and local
source manifest under `build/`. The second checks those exact bytes and the
tagged source again, pushes `main` and the version tag if needed, creates the GitHub Release
and downloads its assets to confirm they match. It never uploads the local
source manifest or any Apple credential.

Release evidence should include the local notarization result, downloaded asset
checksum, published-release verification job and actual runtime results.

## Standard notarytool workflow

The owner confirmed on 2026-09-17 that normal releases should use `xcrun
notarytool` with the existing local `FileMint` Keychain profile to submit the
signed DMG to Apple and wait for review. This is the standard workflow for future
release requests. Keep credentials local; routine releases do not require a new
Apple account, signing identity or credential setup.

`make release-local` already runs `notarytool submit --wait`. If submission and
waiting are performed separately, save the returned submission ID and use
`notarytool wait` or `notarytool info` with that ID. An `In Progress` result or
a wait timeout means to retain the submitted file and continue waiting on the
same submission, not upload another copy merely to retry a status check.

After `Accepted`, staple and validate the DMG ticket, then calculate the final
SHA-256 and run the artifact checks. Only then push the source/tag and publish
the exact validated DMG and checksum to GitHub. A pending or rejected submission
does not qualify for a normal stable release. The historical 0.5.3 exception
does not change this flow.

## Standing release policy

GitHub Releases remain the distribution channel. Public stable releases after
the explicit 0.5.3 exception require local Developer ID signing and Apple notarization.
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

GitHub metadata discovery and the weekly scheduler remain in FileMint. The
Sparkle-enabled client offers Update and Restart, then uses that exact release's
`appcast.xml` asset for signed download, installation and relaunch. Its own
background checks/downloads and system profiling are disabled. The main app and
Finder extension remain sandboxed; only the main app embeds Sparkle.

The dependency is pinned in `project.yml`. `make build` resolves it under
`build/SourcePackages`; `sign_app.sh` signs its nested XPC services and helpers,
then the framework, Finder extension and app. `release-local` signs the final
notarized/stapled DMG with the FileMint-specific EdDSA key, generates an immutable
appcast and verifies it using the public key before accepting the release.
The feed hash is bound into the local release manifest. `publish-local` uploads
it as `appcast.xml` alongside the DMG/checksum and compares all three downloaded
assets with the local originals. No new server or GitHub credential in the app
is needed. Continue using increasing numeric builds and `vMAJOR.MINOR.PATCH` tags.

The update private key remains in the local Keychain account
`io.github.daigua.filemint.updates`. Only its public key is in `project.yml` and
the generated app plist. Do not regenerate or rotate this key during ordinary
releases. A missing/mismatched key stops release preparation. Do not export
private keys to CI or publish them. Public-key signature verification uses
CryptoKit and needs no Keychain credentials. Apple notarization is unchanged.

Clients without Sparkle need one manual installation of the first enabled
release. DMG and `.sha256` assets remain for these clients. Versions 0.3.0–0.5.0
need a browser download because their private-cache download path could create
a sandbox execution block. `UpdateClient`, `make verify-updates` and the old
sandbox harness remain solely for compatibility checks, not production installs.

No updater forcibly quits Finder or enables the extension. Test a real signed
sandbox installation and Finder refresh before release; a build and Core tests
are not installation proof. A standard-user or managed installation may require
administrator authorization. A readonly mounted DMG cannot update in place.

## Primary references

- [Apple: clipboard strings](https://developer.apple.com/documentation/appkit/nspasteboard/string%28fortype%3A%29)
- [Apple: Finder Sync](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
- [Apple: notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub: artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)

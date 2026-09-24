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

Subsequent public stable releases are built on the owner's M-series Mac with
full Xcode from a clean,
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
For a normal notarized public version after 0.5.3, use the following sequence
whenever the owner asks to “构建发布”. The phrase authorizes the full release; a
request only to build, commit or prepare a candidate stops at its named stage.
The two stages are intentionally separate so the candidate can be checked in a
real installed environment before any public upload.

### 1. Prepare the source

1. Inspect the latest GitHub stable release and its appcast, the current main
   branch, and changes since the last tag. Choose a new three-component version
   and strictly higher numeric build. Set both once in `project.yml` under
   `settings.base`. `build_release.sh` and `package_release.sh` use those values;
   do not edit generated `FileMint.xcodeproj` or keep a second version default.
2. Put the current version at the **first** `# FileMint VERSION` heading in
   `docs/RELEASE_NOTES.md`. Write only verified shipped behavior and any migration
   instructions. Review user-facing README/website/install copy when affected.
   The first arm64-only release must state its macOS 13 minimum and that
   earlier Intel installations cannot update to it; keep older release records
   accurate to their original universal artifacts.
   The publishing script extracts only this section for the GitHub Release body.
3. Finish applicable feature verification, commit the release preparation on
   `main`, and create `vVERSION` at that exact commit. The local release command
   rejects an unclean tree, mismatched tag, stale notes, or a version/build that
   does not exceed the latest published appcast. Do not move an existing tag.

### 2. Build and inspect the candidate

Keep Apple notarization credentials in the local `FileMint` Keychain profile (or
use the supported local credential variables). Run:

```sh
make release-local
```

This runs `make verify`, builds arm64-only executables, compiles/tests the production
Sparkle driver, signs app/extension/helper contents, submits the DMG once for
Apple notarization, staples the accepted ticket, and verifies the mounted app,
embedded entitlements, checksum and signed `appcast.xml`. It saves the final DMG,
`.sha256`, appcast and source manifest under `build/`. A missing Sparkle installer
configuration or feed now fails the release, even when other signatures pass.
Keep the final files intact. If notarization is pending or its wait times out,
the script retains the staging DMG and its submission ID. Check that same ID at
Apple, then resume with `FILEMINT_RESUME_STAGE=/path/printed/by/script make
release-local`. This verifies the original DMG hash and waits on the same
submission; it does not upload again. If Apple rejects the submission or any
other check fails, stop and diagnose before making a new candidate.

Copy the **candidate from the final DMG** into an isolated installation and
verify Gatekeeper, launch, About version/build, and the Finder extension. Run the
signed sandbox two-version Sparkle installation acceptance in
[Update verification](../specs/verification/updates.md#sparkle-installation-checks)
when changing the updater, signing, packaging or permissions, and record the
observed replacement/relaunch and any untested production path. Report installed
Finder, minimum-supported-macOS and managed-device evidence separately if unavailable.
Keep this candidate evidence in the release verification record, tied to its
commit and final DMG SHA-256.

### 3. Publish and read back

After candidate acceptance, run:

```sh
make publish-local
```

This rechecks the exact local DMG, checksum, appcast, source commit and certificate
against the local manifest, pushes `main` and the tag, creates a stable GitHub
Release if absent, and compares **all three downloaded assets byte for byte**.
It rejects missing/extra assets, drafts and prereleases, then waits for the
published-release GitHub verification workflow to pass. It never uploads the
local source manifest or Apple credentials. If the remote step fails, keep the
local manifest and rerun `make publish-local`; existing assets are only checked,
never replaced. A mismatched remote asset requires a new version and investigation.

After publication, verify the actual installed update path from a compatible old
release to the newly published version, including replacement, relaunch and
Finder extension refresh, when a test installation is available. Record any
unverified platform or authorization path explicitly; GitHub asset checks do not
prove a user's installed Sparkle upgrade. Close the release verification record
only after recording local, remote and native results.

Release evidence should include the local notarization result, downloaded asset
checksum, published-release verification job and actual runtime results.

## Standard notarytool workflow

The owner confirmed on 2026-09-17 that normal releases should use `xcrun
notarytool` with the existing local `FileMint` Keychain profile to submit the
signed DMG to Apple and wait for review. This is the standard workflow for future
release requests. Keep credentials local; routine releases do not require a new
Apple account, signing identity or credential setup.

`make release-local` submits once, saves the returned submission ID and signed
DMG hash, then runs `notarytool wait`. An `In Progress` result or wait timeout
means to retain that submitted file and resume the same ID, not upload another
copy merely to retry a status check.

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

Released 0.5.7 and 0.5.8 contain unexpanded installer Mach service entitlements
from manual signing. Users must manually install 0.5.9 once; a new feed cannot
change the running old app's signed permissions. The 0.5.9 signing flow resolves
variables before codesign and reads the embedded entitlements during bundle/release
verification. See [0.5.9 release evidence](RELEASE_VERIFICATION_0.5.9.md).

No updater forcibly quits Finder or enables the extension. Test a real signed
sandbox installation and Finder refresh before release; a build and Core tests
are not installation proof. A standard-user or managed installation may require
administrator authorization. A readonly mounted DMG cannot update in place.

## Primary references

- [Apple: clipboard strings](https://developer.apple.com/documentation/appkit/nspasteboard/string%28fortype%3A%29)
- [Apple: Finder Sync](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
- [Apple: notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub: artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)

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
to a draft GitHub Release. The normal release command refuses missing credentials,
rejected notarization or a mismatched artifact. Existing release assets are
never replaced; use a fresh version for corrections. GitHub CI runs core tests
without rebuilding the release DMG.
Before publication, a GitHub job downloads and checks the uploaded draft DMG
without using Apple credentials or claiming it built the binary.

Local packaging also uses a temporary build directory and unregisters/removes
its own app and extension on exit. Xcode automatically registers macOS products;
leaving that development copy discoverable can make Finder load it instead of
the installed release. Do not leave packaging or mounted-image registrations
behind after installation checks.

Local `make package` still defaults to ad-hoc signing for development checks.
The main app also embeds the local `FileMintCompression.framework`; sign it
before the host and verify it with the other bundle components. Its exact
dependency sources and rebuild recipe must be present in the matching source
tag before distributing the binary. Normal builds/tests do not fetch or rebuild
this runtime. See [image compression runtime](../ThirdParty/ImageCompression/README.md)
for provenance, notices, replacement and artifact verification.

For a normal notarized public version after 0.5.3, use the following sequence
whenever the owner asks to “构建发布”. The phrase authorizes the full release; a
request only to build, commit or prepare a candidate stops at its named stage.
The stages separate local artifact preparation, draft upload, verification,
public availability and website deployment. On 2026-10-08 the owner chose to omit
local remote-asset downloads and content comparisons, verify a draft before making
it public, and deploy the verified website build afterward. The owner confirmed that the public update path
was validated across three recent small releases, so routine releases do not repeat
temporary app installation, launch/UI review, website screenshot capture or old-to-new
installation acceptance. The standalone UpgradeQA fixture is omitted from the
standard workflow; this does not skip any step of `make release-local` or
`make publish-local`. When updater, signing, packaging, installer permissions or
appcast behavior changes, select the applicable checks from
[HARNESS](../specs/HARNESS.md), including signed old-to-new runtime evidence when
installation behavior is under test. UpgradeQA remains a case-specific installer
diagnostic, not an automatic substitute for that evidence.

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
the script retains the staging DMG, its submission ID and `source.json` recording
the original source commit, tag, version and build. Check that same ID at
Apple, then resume with `FILEMINT_RESUME_STAGE=/path/printed/by/script make
release-local`. Resume first requires the original clean tagged source to match
`source.json`; a different commit or a legacy stage without that record is rejected
without changing the retained files. Restore the original source or build a new
candidate; do not manufacture a source record for an older DMG.
This also verifies the submitted or recorded stapled DMG hash; a
pending submission waits on the same ID, while a completed ticket is revalidated
without another upload. Stapling uses a private copy and records its verified
hash before replacing the submitted file, so interruptions preserve a recoverable
stage. A matching existing appcast is verified and reused. If Apple rejects the submission or any
other check fails, stop and diagnose before making a new candidate.

No separate UpgradeQA run is required by the standard release procedure.
`make release-local` still runs all offline tests and production Sparkle-driver
checks, then validates the signed, notarized and stapled artifact, mounted app,
entitlements, architecture, checksum and appcast. Record those results against
the release commit and final DMG SHA-256. For changes that need native update
evidence, follow the affected checks in
[Update verification](../specs/verification/updates.md#sparkle-installation-checks);
the UpgradeQA fixture is only an optional diagnostic there. Report installed Finder,
minimum-supported-macOS and managed-device evidence separately when unavailable.

### 3. Stage and verify a draft

After local artifact checks pass, run:

```sh
make publish-local
```

This rechecks the exact local DMG, checksum, appcast, source commit and certificate
against the local manifest, pushes `main` and the tag, and uploads the three assets
to a **draft** Release. Draft staging is reported as not yet available for online
updates. It never uploads the local source manifest or Apple credentials, downloads
remote assets locally or compares remote bytes/hashes with local files.

The command saves `build/FileMint-VERSION.publication.json` beside the verified
candidate. This local journal binds the source manifest, Release ID, asset IDs,
required website work and exact Actions request/run IDs. Preserve it for recovery;
do not commit, upload or manufacture it for an unrelated existing Release. A lock
prevents simultaneous local publication of the same candidate. Interrupted draft
uploads can add missing assets, but never replace an existing asset.

Source CI must succeed for the exact release commit on `main`. The command explicitly
dispatches the candidate workflow against the release tag; that job reads the
draft assets with authenticated GitHub access and performs the existing complete
DMG, Developer ID, notarization, Sparkle helper and embedded-entitlement checks.
It additionally requires the expected source version/build and download sizes.
No Apple or Sparkle signing keys enter Actions. The local GitHub identity needs
release-write and Actions-dispatch/read access; missing permissions stop the draft.

When website inputs differ from the previous stable tag, a website build for this
release commit must also succeed and produce a retained Pages artifact. No matching
run does not mean the build is optional. Unchanged website inputs are explicitly
marked not applicable. Ordinary website pushes now build only; they do not deploy
new release copy before the application is public.

### 4. Promote the verified candidate and confirm online updates

After the required Actions succeed, `make publish-local` rechecks their saved
identities and the draft asset set, then changes that same Release to stable and
Latest. It does not rebuild, re-sign or re-upload the candidate. The appcast retains
the final public tag-based asset URLs throughout draft staging; clients never
receive draft URLs. Sparkle keys, signing, installer configuration and scoped Mach
permissions remain part of the mandatory artifact checks.

Only after GitHub confirms the public release, Latest identity and final download
metadata should the command report that online updates are available. If the
promotion response is lost, query the saved Release ID to reconcile the result.
If GitHub cannot be queried, report that publication status is unknown and retain
the journal; do not assume that publication failed or upload another package.

### 5. Deploy the website and complete the release

If website work is applicable, explicitly dispatch deployment after publication.
The deployment job checks the public Release and exact successful website build,
downloads its retained Pages archive on the runner, and deploys it without rebuilding.
The archive is retained for seven days. A successfully rerun website build for the
same source can supply a fresh artifact for unfinished deployment; published app
assets stay untouched. All required Actions must finish successfully before the
command reports that the **release workflow is complete** and evidence is finalized.

Actions waits poll every 15 seconds and are bounded to 45 minutes per wait by
default (`FILEMINT_ACTIONS_POLL_SECONDS` and `FILEMINT_ACTIONS_TIMEOUT_SECONDS`).
Missing, failed, cancelled or timed-out required checks stop before publication.
A failed website deployment after promotion reports **already published; website
follow-up failed**. For a failed run, rerun that saved run in GitHub, then resume
`make publish-local` from the original clean tagged source. The journal resumes
unfinished stages instead of adopting unrelated green runs or overwriting assets.

Routine publication does not repeat an old-to-new installed update. For changes
to updater, signing, packaging, installer permissions or appcast behavior, apply
the relevant HARNESS and update-verification checks; investigate reported
failures with tests targeted to the failure. UpgradeQA is not required for any
of these cases. `make publish-local` remains mandatory for draft upload, pre-publication
Actions, promotion, public update-discovery checks and applicable website deployment. Record local
artifact results, the time online updates became available and the Actions results;
record native update results when targeted acceptance is performed.

Release evidence should include the local notarization result, local DMG checksum,
published asset names, candidate verification and website run IDs. Do not claim that
local/remote byte equality was checked. Earlier release records retain their
historical readback results. Include native runtime results when that targeted
acceptance is run.

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
it as `appcast.xml` alongside the DMG/checksum in a draft. After candidate checks
pass, the same assets become public without changing the feed's final URLs or
signature. The stable release and Latest discovery are confirmed before reporting
online-update availability.
No new server or GitHub credential in the app
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

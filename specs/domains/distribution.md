# Build and distribution

Load for: Build configuration, packaging, signing, notarization and publication boundaries.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## Distribution

- New Release apps and DMGs support M-series Macs running macOS 13 or later.
  Build the main app, Finder extension and embedded Sparkle executables as
  arm64-only. Reject any x86_64 slice in local and published bundle checks.
  Previously published universal releases keep their original architecture
  support and bytes.
  The minimum macOS version is 13.0 in the release build and appcast together.
  Arm64 does not distinguish M-series from A-series Apple silicon: A-series
  Macs are outside the support policy, without a chip-name-based launch block.
  The first arm64-only release notes and installation guidance identify the
  compatibility cutoff, while older release notes remain historical records.
- The owner explicitly chose to publish 0.5.3 while its existing `notarytool`
  submission was still `In Progress`. This one release uses the authorized
  Developer ID Application identity for the app, Finder extension and DMG,
  hardened runtime and secure timestamps, but had no stapled Apple notarization
  ticket at publication. A later query returned `Accepted` for the exact
  published DMG under submission `11ed351a-020e-4107-bfae-72d0a8daec52`.
  Apple publishes that ticket online, so Gatekeeper can retrieve it for the
  unchanged DMG when the Mac is connected, including copies downloaded before
  acceptance. The release page, README and installation guide must preserve
  this chronology and explain that the existing asset still has no stapled
  ticket, so offline verification can fail. The SHA-256 file establishes byte
  integrity, not ticket presence or permission to launch. Do not replace the
  published 0.5.3 bytes after the fact.
- Public stable releases after 0.5.3 require Apple notarization on the owner's
  Mac. Staple and validate the DMG ticket before computing its portable SHA-256
  checksum. Only the validated local DMG and checksum are uploaded to GitHub
  Releases. Missing credentials, rejected notarization or failed validation
  must stop publication.
- GitHub Releases remain the distribution channel. GitHub CI verifies the core
  without holding Apple signing assets or rebuilding the public DMG. A locally
  built release is not represented as a GitHub Actions build or GitHub build
  attestation. Existing published versions retain their original trust
  limitations; documentation must distinguish them from the first notarized
  release. Never tell users to disable Gatekeeper globally. Finder extension
  enablement remains a separate system action.
- CI and website-deployment workflows pin third-party GitHub Actions to reviewed
  commit IDs. Dependency lockfiles remain frozen during website builds.
- The Developer ID certificate stays in the project's ignored local signing
  directory. The certificate, private key, exported signing identity and Apple
  notarization credentials must remain local and never be committed, uploaded
  to GitHub Actions secrets or bundled in the app.
- Before publishing, local release checks verify the source tag, clean checkout,
  arm64-only executables, nested signatures, DMG integrity and final checksum. The
  one-time 0.5.3 exception additionally checked and recorded the actual Apple
  `In Progress` state at publication; the later `Accepted` result establishes
  an online ticket but does not retroactively staple the uploaded DMG. Later
  releases require local ticket validation before upload. GitHub re-checks the
  uploaded draft candidate before publication without building it or claiming
  build provenance.
- A normal stable release has one version/build source in `project.yml` and two
  explicit stages: `release-local` checks the committed release notes and source
  tag, then builds and verifies the notarized artifact; `publish-local` uploads
  the verified DMG, checksum and appcast to a draft Release. Source CI, remote
  candidate verification and applicable website builds must succeed before the
  same draft is made public and Latest. Only then announce online-update
  availability, deploy the verified website artifact and complete release records.
  The owner
  confirmed public update acceptance across three recent small releases; routine
  releases therefore do not require a temporary app launch/UI review, website
  screenshot capture or repeated old-to-new installation acceptance. Omitting
  the standalone UpgradeQA fixture changes none of the release gates: every
  stable version still requires the clean tagged source, `release-local` checks,
  accepted notarization, stapling, signed appcast, `publish-local` stable-release
  and asset-set checks, and candidate verification before public availability.
  Local remote-asset downloads and byte/hash comparisons remain omitted.
  Dispatch candidate checks for the exact release ID, tag, commit, build and
  asset IDs, and save their request/run identities in a local publication journal.
  Recheck the candidate identity before promotion; changed assets invalidate the
  check. Never reuse an unrelated or historical run for another candidate.
  Required failed, cancelled, missing or timed-out checks leave the Release a draft.
  GitHub checks the remote checksum, signatures, ticket, Sparkle helpers and
  resolved installer entitlements, with the expected source build number.
  An interrupted publication request must be reconciled with GitHub before
  reporting whether the version is public. Confirm Latest discovery and the final
  public asset URLs after promotion; never give clients a draft/temporary URL.
  Website builds run before publication when tracked website inputs changed;
  deployment reuses that successful build only after the Release is public.
  Missing required website jobs are failures, not evidence that no build is needed.
  A website deployment failure reports "published; website deployment failed"
  and resumes only unfinished work, preserving the published assets.
  Publication jobs use the existing GitHub identity and keep all Apple/Sparkle
  private keys local. Changes to updater, signing,
  packaging, installer permissions or appcast still receive applicable checks
  from [HARNESS](../HARNESS.md); actual installed-update behavior needs signed
  old/new runtime evidence when that behavior is under test. UpgradeQA is an
  optional, case-specific diagnostic, not a default release step. Publication
  can resume from the verified local manifest after a remote failure without
  rebuilding or replacing release assets. A notarization
  timeout retains the submitted DMG, its hash and Apple submission ID so the same
  submission can be resumed without uploading again. Preparation requires a
  reviewed commit and tag; development commands must not publish implicitly.

## Automatic-update artifacts

- Pin Sparkle in project.yml; embed its framework and installer tools only in the
  main application. Sign nested XPC services, Autoupdate and Updater.app before
  the framework and host app, with the release identity and hardened runtime.
- Manual signing must expand entitlement build variables using the actual target
  bundle identifier before codesign. Signed app entitlements must contain the
  exact `<bundle-id>-spks` and `<bundle-id>-spki` Mach service names and no unresolved
  build variables. Verify the embedded entitlements in both app and extension;
  valid signatures/notarization alone do not prove sandbox communication works.
- Publish appcast.xml alongside the existing DMG and checksum. Generate the
  EdDSA signature only after notarization/stapling fixes the final DMG bytes.
  The feed binds the numeric build, marketing version, exact GitHub asset URL,
  minimum macOS version, size and signature. Release builds and publication must
  fail if the feed/signature/public-key configuration is missing or mismatched.
- Stable release verification requires the Sparkle installer configuration and
  signed framework/helper contents in the mounted app. A missing configuration
  cannot turn appcast verification into an optional check. The remote release must
  contain exactly the DMG, portable checksum and `appcast.xml`. Upload the locally
  verified files as a draft, verify them on GitHub and only then make that Release
  public, without a local remote-content comparison.
  GitHub's independent checksum/signature/ticket verification and the client's
  signed update validation remain in place. Preserve the Sparkle public key,
  final DMG signature, immutable tag-based appcast/download URLs, version/build
  binding and installer Mach permissions across publication orchestration changes.
  A post-publication failure must not relabel a public version as unpublished;
  keep the published assets immutable.
- Keep the Sparkle EdDSA private key in the local Keychain under a FileMint-specific
  account. Only the public key belongs in source and in the app. Never export keys
  to CI, logs or release assets. Existing Apple signing credentials are unchanged.
- The first Sparkle-enabled release still includes DMG and SHA-256 for older
  clients. Publishing is a separate requested operation, not implied by development.

## Working context

- FileMintImages uses system Image I/O, Core Graphics and Vision, plus an app-only
  compression runtime containing libvips, MozJPEG, libpng, libtiff and their
  declared dependencies. This dependency improves compression without migrating
  other image actions. Ship a pinned arm64 runtime targeting macOS 13 with a small
  C interface, reproducible build recipe, source hashes and third-party notices.
  Offline builds/tests use the checked-in artifact; normal use never fetches a
  library or depends on Homebrew. Bundle and verify its nested signature and load
  paths; no third-party image runtime belongs in the Finder extension or Core.
  Preserve each dependency's license and provide the corresponding source and
  rebuild/replacement instructions alongside the binary. FileMint's own license
  does not replace the third-party licenses. No WebP encoder is bundled.
- The icon picker bundles an attributed text catalog of SF Symbol names in the
  main app only. macOS supplies the glyph artwork at runtime; the Finder
  extension reads saved names and colors without a catalog or new dependency.
- The template preview uses system Quick Look UI/Thumbnailing in the main app.
  The exported template-package type conforms to ZIP and has the
  `.filemint-templates` extension; Finder tickets and entitlements are unchanged.
- Office template validation uses system zlib, Foundation XML and CryptoKit;
  no Office, ZIP or third-party package dependency is added.
- Blank DOCX/XLSX templates ship as versioned FileMintCore package resources.
  App, extension and standalone harness builds retain the resource bundle;
  creation never depends on a source-checkout or build-directory resource path.

- Implementation entry points: `project.yml`, `Config/`, `CorePackage/Package.swift`, build/release scripts and `.github/workflows/ci.yml` / `release.yml`.
- Verification: [Distribution procedure](../../docs/DISTRIBUTION.md) and the release row of the [verification matrix](../HARNESS.md#choose-checks-by-change).
- Expand context only when needed: Load [Finder/permissions](finder-permissions.md) for entitlements and temporary bundle cleanup; [updates](updates.md) for asset formats or installation handoff. Website deployment uses [presentation](presentation.md). Historical exceptions do not authorize a new publication.

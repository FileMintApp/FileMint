# Build and distribution

Load for: Build configuration, packaging, signing, notarization and publication boundaries.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## Distribution

- New Release apps, DMGs and ZIPs support M-series Macs running macOS 13 or later.
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
  checksum. Derive the ZIP from the same DMG's signed app, staple and validate
  the app ticket before archiving it with `ditto`, and preserve framework symlinks,
  executable permissions and macOS metadata. ZIP itself cannot be codesigned or
  stapled. A ZIP contains only `FileMint.app` plus ditto's resource metadata;
  verification rejects escaping paths/links and limits expanded data to 1 GiB.
  Only the validated local archives, checksums and feeds are uploaded to GitHub
  Releases. Missing credentials, rejected notarization or failed validation must
  stop publication. A resumed accepted DMG can supply the ZIP without rebuilding
  the application or submitting another notarization request.
- GitHub Releases remain the distribution channel. GitHub CI verifies the core
  and compiles the unsigned app and Finder extension without holding Apple
  signing assets or rebuilding the public DMG. A locally built release is not
  represented as a GitHub Actions build or GitHub build
  attestation. Existing published versions retain their original trust
  limitations; documentation must distinguish them from the first notarized
  release. Never tell users to disable Gatekeeper globally. Finder extension
  enablement remains a separate system action.
- CI and website-deployment workflows pin third-party GitHub Actions to reviewed
  commit IDs. Dependency lockfiles remain frozen during website builds.
- GitHub credentials are opaque strings. Pass installation tokens, including
  Actions `GITHUB_TOKEN`, intact to GitHub CLI, Git credential helpers and
  Homebrew; do not enforce a fixed length, decode their JWT or store/log their
  contents. Support the classic format and variable-length stateless tokens
  around and above 520 characters. Offline regression checks cover both shapes
  through the release/tap API adapters and Git credentials. Source CI also uses
  its read-only job token for real API and credential-helper checks; report only
  success and token-format metadata. Local OAuth checks are not installation-token
  evidence. No workflow here mints installation tokens, so do not add the temporary
  creation-endpoint override header to ordinary requests. See GitHub's
  [format guidance](https://github.blog/changelog/2026-05-15-github-app-installation-tokens-per-request-override-header/)
  and [completed rollout and header retirement](https://github.blog/changelog/2026-10-02-stateless-github-app-installation-tokens-rolled-out/).
- Successful main-push website builds automatically trigger `deploy-website.yml`.
  Serialize with release website deployments and retain manual dispatch for retries.
  Validate the originating repository, push event, workflow, current main, stable
  release ancestry and the exact successful build and unexpired artifact IDs.
  App, CorePackage, FinderSyncExtension, SharedUI, Config, Resources, ThirdParty,
  project.yml and bundled license changes since the stable tag prevent independent
  deployment. Website, docs/specs, tests, CI and publication tooling may advance
  independently; reject unknown root paths. Skip superseded builds and unpublished
  application changes with an explicit reason, before downloading any artifact.
  Recheck identities after downloading and deploy the retained archive without
  rebuilding or modifying releases. Release-dispatched builds never auto-deploy;
  the existing application-publication and release-bound website gates remain.
- CI jobs running project scripts use the latest stable Node 26.x, selected by
  `actions/setup-node` with `check-latest: true`; record the resolved Node version
  in job logs. Website builds retain the package-manager version from
  `package.json` and frozen-lockfile installation. A pinned Action's own bundled
  JavaScript runtime is separate from the Node used for project commands.
- Source CI runs the complete offline `make verify` suite and
  `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` on the standard
  arm64 `macos-15` and `macos-26` runners. The build uses the existing Release
  scheme, generates the project from `project.yml`, and must produce both the
  main executable and its embedded Finder extension executable. Ensure XcodeGen
  is available and log its version; package resolution may use the network.
  Both tests and compilation must pass in both environments; a failure in
  one must not cancel the other. Keep the stable `Verify core behavior` check
  as an aggregate that runs even when a dependency fails, is cancelled or is
  skipped, and succeeds only when every matrix job succeeds. Log the actual OS,
  architecture and Xcode/Swift versions with each run. This is the conservative
  source-CI baseline; local acceptance selects checks by actual changes using
  [HARNESS](../HARNESS.md#choose-checks-by-change). The unsigned build checks
  compilation, linking, resources and embedding, not runtime behavior or release
  signatures. It must not install, launch, package or publish the app. This matrix
  does not prove macOS 13/14 or installed Finder/UI compatibility; those need
  separate runtime evidence on the target system.
- Fork synchronization runs only in downstream forks and preserves downstream
  commits through a normal merge without force pushing. A fork may configure
  `FORK_SYNC_TOKEN` with repository-scoped Contents and Workflows read/write
  permissions so checkout and Git push can include upstream workflow updates.
  The built-in `GITHUB_TOKEN` remains sufficient for source-only updates; incoming
  workflow changes without the dedicated token stop before push with setup
  guidance. Sync credentials belong to the fork, never to the upstream source.
  A dedicated-token push to `main` starts the existing push CI. Explicitly
  dispatch CI after built-in-token updates or updates to another default branch,
  and on an up-to-date manual run to retry CI without creating duplicate runs.
  Merge, permission and push failures must stop before CI dispatch.
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
  the verified DMG/ZIP, both checksums and both appcasts to a draft Release. Source CI, remote
  candidate verification and applicable website builds must succeed before the
  same draft is made public and Latest. Only then announce online-update
  availability, deploy the verified website artifact, synchronize the official
  Homebrew tap and complete release records after its exact commit passes CI.
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

## User-facing release notes

- `docs/RELEASE_NOTES.md` remains the sole authored release-note source. Keep the
  current release first and publish only its matching `# FileMint VERSION` section.
  Future releases after 0.8.0 use the bilingual
  [release-note template](../../docs/RELEASE_NOTES_TEMPLATE.md); existing 0.8.0
  and older records retain their original format and claims.
- Order each language's content as summary, getting started, detailed changes,
  and upgrade notes. Use the exact headings `更新摘要`, `开始使用`, `详细改进`,
  `升级须知`, then `Highlights`, `Getting started`, `Details`, `Before you update`.
  The summary follows the bounded plain-text format in [Updates](updates.md).
  Start with concrete user outcomes. Getting started gives the actual entry
  path and any opt-in requirement. Describe fixes by their trigger and visible
  result; keep compatibility, supported scope and migration limits explicit.
  Do not describe unimplemented or unverified work as shipped.
- Release metadata checks reject future release notes with missing, duplicate,
  empty, reordered or malformed required sections. The app and GitHub consume
  the same authored summary; do not maintain separate hard-coded app copy or
  introduce another release asset/feed. Formatting work does not choose a new
  version, retag a release or modify public releases.

## Homebrew distribution

- A FileMint-maintained `FileMintApp/homebrew-tap` Cask reuses the immutable,
  signed and notarized release DMG, with an explicit stable version, SHA-256,
  arm64 and macOS 13 requirements. It declares `auto_updates true`; Sparkle,
  Finder extension enablement and folder authorization keep their existing rules.
  No new build, runtime dependency, installer script or quarantine bypass is added.
- Prepare and synchronize from the current ten-string-field release manifest
  (including DMG/ZIP and both appcast hashes) and its publication journal. Require
  local archive/checksum/feed integrity, matching local and remote tag commits,
  the same six asset identities, a successful exact source CI run and exact draft
  candidate verification run, and public Latest discovery. Read-only preparation
  never dispatches workflows or downloads remote release archives. Reuse the
  existing local artifact verifier; GitHub Actions owns remote artifact checks.
- Tap synchronization follows successful application publication and applicable
  website deployment and is enabled by default for standard `publish-local`
  releases. The owner's 2026-10-20 standing instruction makes it part of
  “构建发布”; separate native installation acceptance remains unverified and does
  not disable this authorized distribution step. A missing tap fails clearly;
  the release hook never creates a repository. Preserve the public release and
  assets on tap failure, report partial success, and allow manifest-based retries
  without rebuilding, re-signing, uploading or deploying again. Persist the
  requirement before remote work, including when resuming older journals.
- After Cask push/readback, require successful `validate.yml` push CI for the exact
  tap commit on `main`, with its run ID and verified attempt in the receipt and
  publication journal. Missing, failed, cancelled or timed-out CI cannot complete
  the release workflow. Recheck tap identity around verification; never accept a
  run for another commit/workflow/branch. Resume unfinished tap work without
  repeating completed app/website stages or an already verified tap stage.
  `FILEMINT_HOMEBREW_SYNC=0` is an explicit nonstandard app-only override; it cannot
  clear a requirement already persisted in the journal. Local builds and
  `release-local` do not synchronize a tap.
- Tap writes use the existing local GitHub identity and a normal fast-forward
  update of `main`. Validate the declarative Cask and remote layout before writing;
  reject downgrades, same-version byte changes and concurrent updates. Revalidate
  release evidence before pushing, then read back the remote commit and Cask.
  Identical verified retries are no-ops. Development and `release-local` never
  publish a tap.
- The tap's read-only validation step passes its per-job GitHub token to
  Homebrew API requests. Keep `contents: read` permissions and use the ephemeral
  Actions identity; no personal access token or Apple/Sparkle key is required.
- The Cask does not quit, kill or relaunch any process and contains no `zap`.
  Before brew replacement, adoption or removal, finish/save/cancel work, wait for
  active file or Sparkle operations, manually quit FileMint and confirm exit.
  Homebrew does not enforce this prerequisite. Keep user files, preferences,
  templates and bookmarks; permission usability still depends on macOS state.
- Native installation, upgrade, migration and removal acceptance requires a
  disposable Apple-silicon macOS VM or test Mac with separate Homebrew,
  Applications, home and Finder state. The owner explicitly requested initial
  tap publication without that environment. Record those runtime checks as
  blocked; public Cask CI, command resolution and checksum fetch prove only
  distribution availability. Do not describe native installation or Finder
  behavior as verified. See the [Homebrew task](../../docs/tasks/homebrew-tap.md).

## Automatic-update artifacts

- Pin Sparkle in project.yml; embed its framework and installer tools only in the
  main application. Sign nested XPC services, Autoupdate and Updater.app before
  the framework and host app, with the release identity and hardened runtime.
- Manual signing must expand entitlement build variables using the actual target
  bundle identifier before codesign. Signed app entitlements must contain the
  exact `<bundle-id>-spks` and `<bundle-id>-spki` Mach service names and no unresolved
  build variables. Verify the embedded entitlements in both app and extension;
  valid signatures/notarization alone do not prove sandbox communication works.
- Publish `appcast.xml` for the retained DMG and `appcast-zip.xml` for the ZIP,
  alongside both archives and their portable checksums. Generate each
  EdDSA signature only after notarization/stapling fixes its final archive bytes.
  The feed binds the numeric build, marketing version, exact GitHub asset URL,
  minimum macOS version, size and signature. Release builds and publication must
  fail if the feed/signature/public-key configuration is missing or mismatched.
- Stable release verification requires the Sparkle installer configuration and
  signed framework/helper contents in each verified app. A missing configuration
  cannot turn appcast verification into an optional check. The remote release must
  contain exactly the DMG, ZIP, their two portable checksums, `appcast.xml` and
  `appcast-zip.xml`. Both feeds use the same version/build, public key, minimum OS
  and architecture requirements; bind both archive/feed hashes in the local
  source manifest and verify both remote artifacts. Their verified app code hashes
  must match, establishing the same sealed payload. Upload the locally
  verified files as a draft, verify them on GitHub and only then make that Release
  public, without a local remote-content comparison.
  GitHub's independent checksum/signature/ticket verification and the client's
  signed update validation remain in place. Preserve the Sparkle public key,
  final archive signatures, immutable tag-based appcast/download URLs, version/build
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

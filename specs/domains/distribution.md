# Build and distribution

Load for: Build configuration, packaging, signing, notarization and publication boundaries.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## Distribution

- macOS 13+; universal arm64 + x86_64 Release app and DMG on GitHub Releases.
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
- The Developer ID certificate stays in the project's ignored local signing
  directory. The certificate, private key, exported signing identity and Apple
  notarization credentials must remain local and never be committed, uploaded
  to GitHub Actions secrets or bundled in the app.
- Before publishing, local release checks verify the source tag, clean checkout,
  both architectures, nested signatures, DMG integrity and final checksum. The
  one-time 0.5.3 exception additionally checked and recorded the actual Apple
  `In Progress` state at publication; the later `Accepted` result establishes
  an online ticket but does not retroactively staple the uploaded DMG. Later
  releases require local ticket validation before upload. A published-release
  GitHub job may re-check the uploaded bytes without building them or claiming
  build provenance.

## Automatic-update artifacts

- Pin Sparkle in project.yml; embed its framework and installer tools only in the
  main application. Sign nested XPC services, Autoupdate and Updater.app before
  the framework and host app, with the release identity and hardened runtime.
- Publish appcast.xml alongside the existing DMG and checksum. Generate the
  EdDSA signature only after notarization/stapling fixes the final DMG bytes.
  The feed binds the numeric build, marketing version, exact GitHub asset URL,
  minimum macOS version, size and signature. Release builds and publication must
  fail if the feed/signature/public-key configuration is missing or mismatched.
- Keep the Sparkle EdDSA private key in the local Keychain under a FileMint-specific
  account. Only the public key belongs in source and in the app. Never export keys
  to CI, logs or release assets. Existing Apple signing credentials are unchanged.
- The first Sparkle-enabled release still includes DMG and SHA-256 for older
  clients. Publishing is a separate requested operation, not implied by development.

## Working context

- Implementation entry points: `project.yml`, `Config/`, `CorePackage/Package.swift`, build/release scripts and `.github/workflows/ci.yml` / `release.yml`.
- Verification: [Distribution procedure](../../docs/DISTRIBUTION.md) and the release row of the [verification matrix](../HARNESS.md#choose-checks-by-change).
- Expand context only when needed: Load [Finder/permissions](finder-permissions.md) for entitlements and temporary bundle cleanup; [updates](updates.md) for asset formats or installation handoff. Website deployment uses [presentation](presentation.md). Historical exceptions do not authorize a new publication.

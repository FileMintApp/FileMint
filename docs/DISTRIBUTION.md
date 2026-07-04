# Distribution

FileMint is distributed from GitHub Releases as a signed and notarized DMG.

## Local Development Package

Prerequisites:

- Full Xcode selected with `xcode-select`.
- XcodeGen installed with `brew install xcodegen`.

```sh
make verify
APP_VERSION=0.1.0 BUILD_NUMBER=1 make package
```

Without a Developer ID certificate in the environment, `make package` creates an
unsigned development DMG at `build/FileMint-0.1.0.dmg`. Gatekeeper will warn
users about unsigned builds, so do not publish unsigned DMGs as public releases.

## GitHub Workflows

- `.github/workflows/ci.yml` runs on pushes to `main`, pull requests, and manual dispatch. It runs the Swift package tests, the JSON harness, and an unsigned app build.
- `.github/workflows/release.yml` runs when a `vX.Y.Z` tag is pushed or manually dispatched for an existing tag. It verifies, builds, signs, notarizes, generates GitHub release notes, and uploads `FileMint-X.Y.Z.dmg` plus `FileMint-X.Y.Z.dmg.sha256`.

## Apple Developer Setup

Configure these identifiers in the Apple Developer portal:

- App bundle ID: `io.github.daigua.filemint`
- Finder Sync extension bundle ID: `io.github.daigua.filemint.findersync`
- App Group: `group.io.github.daigua.filemint`

Create or export a `Developer ID Application` certificate as a password-protected
`.p12` file.

## GitHub Secrets

Add these repository secrets before pushing a release tag:

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` certificate.
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`: password for the `.p12` file.
- `APPLE_BUILD_KEYCHAIN_PASSWORD`: temporary keychain password used by Actions.
- `APPLE_CODESIGN_IDENTITY`: exact Developer ID signing identity, for example `Developer ID Application: Your Name (TEAMID)`.
- `APPLE_ID`: Apple ID used for notarization.
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for that Apple ID.
- `APPLE_TEAM_ID`: Apple Developer Team ID.

Generate the certificate secret locally with:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

## Release Flow

1. Merge the implementation to `main`.
2. Run local readiness checks:

   ```sh
   make doctor
   make verify
   ```

3. Complete the manual Finder QA checklist in `docs/FINDER_QA.md`.
4. Create and push a version tag:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

5. GitHub Actions builds the release and publishes a GitHub Release named `FileMint 0.1.0`.
6. Download and install the uploaded DMG from the release page.

If the release needs to be re-run for the same tag, open the `Release` workflow
in GitHub Actions, choose `Run workflow`, and enter the existing tag. Existing
release assets are replaced.

## GitHub Repository Bootstrap

This folder must be a Git repository before the workflows can run on GitHub:

```sh
git init
git add .
git commit -m "Initial FileMint release workflow"
gh repo create <owner>/FileMint --public --source=. --remote=origin --push
```

## Local Signing Smoke Test

After your Developer ID certificate is installed locally:

```sh
APPLE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
APP_VERSION=0.1.0 \
BUILD_NUMBER=1 \
make package
```

Set `NOTARIZE=1` and the Apple notarization environment variables to test the
full notarization path locally.

# Task: FileMint 0.6.7 stable release

Status: complete
Next action: None for the standard release; remaining native acceptance stays in the feature task.

## Objective and scope

- The owner requested a formal build and publication on 2026-10-08.
- Publish 0.6.7/build 26 from the primary main checkout, including the committed
  template workflows and review fixes after v0.6.6.
- Follow the standard signed, notarized, stapled release procedure through
  downloaded asset comparisons and published-release verification.
- Preserve existing installed applications, real preferences and old release assets.
  Exhaustive native QA and installed-app replacement are outside this request.

## Selected context

- [Distribution contract](../../specs/domains/distribution.md),
  [procedure](../DISTRIBUTION.md), [HARNESS](../../specs/HARNESS.md),
  [AI Playbook](../AI_PLAYBOOK.md), [Presentation](../../specs/domains/presentation.md).
- Feature claims: [Templates](../../specs/domains/templates.md),
  [Creation](../../specs/domains/creation.md),
  [Startup](../../specs/domains/startup.md), [Updates](../../specs/domains/updates.md).
- Applicable native scheduling check: [Update verification](../../specs/verification/updates.md).
- Prior feature evidence remains tied to its source in the
  [template workflow task](2026-10-05-template-workflow.md) and
  [acceptance record](../ACCEPTANCE.md).

## Decisions and progress

- Live stable v0.6.6 was published 2026-10-03; its downloaded appcast reports
  build 25. Live main and the clean local checkout both point to `322b6df`.
  Its [source CI](https://github.com/FileMintApp/FileMint/actions/runs/37734827266) passed.
- Use the next patch version 0.6.7/build 26, set only in `project.yml`.
  Generate the Xcode project normally and retain bilingual release notes.
- Update README release highlights and remove the shipped features from future
  public roadmap lists. Their remaining native acceptance stays recorded separately.
- Run the production-model native regression for modal update-check deferral.
  The fixture uses temporary settings, injected metadata and accelerated timers;
  it does not prove network discovery or signed installation.
- Standard release does not repeat UpgradeQA. Resume retained notarization
  submissions only when their source record matches this release tag and commit.
- Release preparation commit and tag: `747527192053d9465dd08c6b6e2fc8717b1d517c`,
  `v0.6.7`. The candidate completed signing, accepted notarization, stapling and
  local mounted-artifact checks before publication.
- The first publish attempt stopped before pushing because Git's HTTP/2
  connection failed. A command-scoped HTTP/1.1 retry reused the verified
  manifest and completed publication; no rebuild or second notarization submission.
- [FileMint 0.6.7](https://github.com/FileMintApp/FileMint/releases/tag/v0.6.7)
  was published 2026-10-08 14:41:12 Asia/Shanghai with exactly the required three
  assets. All three downloaded files matched their local originals byte for byte.
- Release verification, source CI and website deployment passed for the release
  commit. This completion record is a documentation-only follow-up; it does not
  change the immutable source tag or published artifacts.

## Evidence

Preparation base: `322b6dfed4f857d13a8703149e15a3270c653092`, clean main.
Released source: `747527192053d9465dd08c6b6e2fc8717b1d517c` (`v0.6.7`).
Environment: macOS 27.2 arm64, Xcode 27.0 (27A266a); use the Makefile's explicit
`DEVELOPER_DIR` because global xcode-select points to CommandLineTools.
Logs and prior feed: `build/release-0.6.7/`.

| Check | Status | Evidence |
| --- | --- | --- |
| Live version/build/source | passed | v0.6.6/build 25 downloaded; live main equals the clean preparation base. |
| Metadata, generation and site build | passed | `make project`, metadata/successor checks, `make verify-context` and `git diff --check` passed. `SITE_BASE=/FileMint/ pnpm run site:build` passed; `build/release-0.6.7/site-build.log`. |
| Native automatic-check deferral | passed | Current production-model fixture built and passed copied compound-suffix output plus native sheet/modal deferral, single resumption, disable, manual check and cancellation; `native-build.log` and `native.log` under the evidence directory. |
| `make release-local` | passed | 220 Core tests, 14 image tests, 5/5 Harness cases, 10 CLI regressions and offline release checks passed. Arm64 Release app/extension, production Sparkle-driver callbacks, Developer ID signatures, embedded entitlements, accepted notarization, staple validation and signed appcast passed; `build/release-0.6.7/release-local.log`. |
| Final template resources/type | passed | Both Office assets in each host bundle match source bytes; both hosts report 0.6.7/build 26 and the main app declares the template-package type; `build/release-0.6.7/final-bundle-audit.json`. |
| `make publish-local` | passed after connection retry | DMG, portable checksum and appcast downloaded and compared byte for byte; `publish-local.log`, with the first connection failure retained in `publish-local-attempt-1.log`. |
| Published-release verification | passed | [Run 37738980279](https://github.com/FileMintApp/FileMint/actions/runs/37738980279), exact release source; `build/release-0.6.7/release-verification.json`. |
| Release source CI | passed | [Run 37738965395](https://github.com/FileMintApp/FileMint/actions/runs/37738965395); `build/release-0.6.7/source-ci.log`. |
| Website deployment | passed | [Run 37738965426](https://github.com/FileMintApp/FileMint/actions/runs/37738965426); `build/release-0.6.7/website-deploy.log`. This establishes deployment, not a browser screenshot review. |
| Exhaustive installed/native acceptance | not-run | Installed Finder, macOS 13, managed devices, complete keyboard/VoiceOver/appearance coverage and public-feed installation are not established. Office providers were unavailable in earlier isolated checks; installed VS Code failed strict signature validation. |

### Artifact identity

- Apple submission: `c5db414b-0b98-41b2-ade2-12b16cd67cfe`, Accepted.
- Final DMG SHA-256: `b565d9bf8cb29ba72669cd331b039079abafd3af3a9deb305a76aac64814c321`.
- Appcast SHA-256: `e0de34a2735eda902a067b0ad8399ac21f530d7abc39a052e1d458916c42b41c`.
- Local source/signing manifest: `build/FileMint-0.6.7.release.json`.
- Download: [DMG](https://github.com/FileMintApp/FileMint/releases/download/v0.6.7/FileMint-0.6.7.dmg),
  [SHA-256](https://github.com/FileMintApp/FileMint/releases/download/v0.6.7/FileMint-0.6.7.dmg.sha256),
  [appcast](https://github.com/FileMintApp/FileMint/releases/download/v0.6.7/appcast.xml).
- Remote asset names, hashes and URLs: `build/release-0.6.7/remote-release.json`.

## Handoff

- No standard release work remains. Keep published bytes and `v0.6.7` unchanged.
- Native limitations remain in the feature task and the evidence table above;
  this release does not establish exhaustive product QA or an installed public-feed upgrade.

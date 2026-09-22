# Task: FileMint 0.5.8 release

Status: complete
Next action: None; version 0.5.8 is published and verified.

## Scope and authorization

- User requested release notes for this iteration and publication of a new version.
- Live latest is v0.5.7/build 15; prepare v0.5.8/build 16 from current main.
- Include Open with App, clipboard images, multiple templates, Office document templates, and appearance/settings consistency.
- Use the existing local signing identity, FileMint notarytool profile and Sparkle key according to the standing release policy. Publish only after accepted notarization and artifact verification.

## Selected context

- [Distribution contract](../../specs/domains/distribution.md), [release procedure](../DISTRIBUTION.md), [verification matrix](../../specs/HARNESS.md).
- Feature contracts: [Open with App](../../specs/domains/open-with.md), [Creation](../../specs/domains/creation.md), [Templates](../../specs/domains/templates.md), [Startup](../../specs/domains/startup.md), [Presentation](../../specs/domains/presentation.md).
- [Settings verification](settings-appearance.md) and the linked native evidence for the other September 22 features.

## Evidence

- Release checks passed on clean tagged candidate `eb487e3250dc1a7d631332cfe4500ae769b96269`: 139 Core tests, 13 image tests, 5 public cases, 10 CLI regressions, 3 appcast tests, context checks and website build.
- Latest release and remote main checked through GitHub/Git: v0.5.7/build 15, remote main `55d9a1f4be76f7963d01020999173cee94331707`.
- Native fixtures cover the new workflows on macOS 27.2/Apple silicon. Installed Finder, Intel/macOS 13 runtime and clean-Mac authorization remain distinct from this evidence.
- The initial upload command was rejected by automatic approval review. Local
  packaging continued without upload; the user then explicitly authorized Apple
  notarization with the existing FileMint profile and subsequent GitHub publication.
- Submitted the exact prepared signed DMG once, received Accepted, stapled it,
  regenerated its checksum/appcast and passed the standard artifact verifier.
- A copy from the final DMG passed Gatekeeper and launched with About 0.5.8 (16).
  Owner preferences were unchanged; the temporary app copy/registrations were removed.
- Published stable v0.5.8 with exactly DMG, checksum and appcast; downloaded bytes
  and GitHub digests match. Release body matches this iteration's prepared notes.
- Core CI, published-DMG verification and website deployment passed for the tagged commit.
- [Complete release verification](../RELEASE_VERIFICATION_0.5.8.md).

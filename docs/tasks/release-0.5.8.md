# Task: FileMint 0.5.8 release

Status: in-progress
Next action: Commit release metadata, tag the clean candidate, then run the normal local notarization flow.

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

- Prior implementation checks passed; the release workflow will rerun checks on the clean tagged candidate.
- Latest release and remote main checked through GitHub/Git: v0.5.7/build 15, remote main `55d9a1f4be76f7963d01020999173cee94331707`.
- Native fixtures cover the new workflows on macOS 27.2/Apple silicon. Installed Finder, Intel/macOS 13 runtime and clean-Mac authorization remain distinct from this evidence.
- Apple acceptance, final checksums, published asset readback and CI results will be recorded after completion.

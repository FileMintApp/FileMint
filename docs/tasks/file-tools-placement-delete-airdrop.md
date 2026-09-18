# Task: Flexible file tools, permanent deletion and AirDrop

Status: in-progress (documentation and source push)
Next action: Verify Chinese/English website build, then commit and push the reviewed source and documentation.

## Objective and scope

Per-action main/submenu switches for file tools including new Permanent Delete and
AirDrop. Default deletion confirmation with optional silent deletion. Smaller native
settings switches. New File is unchanged.

## Selected context

- [File tools](../../specs/domains/file-tools.md)
- [Finder](../../specs/domains/finder-permissions.md)
- [Startup](../../specs/domains/startup.md)
- [Appearance](../../specs/domains/presentation.md)
- [Creation route boundaries](../../specs/domains/creation.md)
- [Verification](../../specs/HARNESS.md), Core and Finder checklists.

## Decisions and progress

- New actions start disabled; placement switches preserve existing menu defaults.
- Move, delete and AirDrop share a serialized main-app operation coordinator and
  private expiring transport. Creation remains separate.
- AirDrop uses Apple's NSSharingService, with recipient selection in the system UI.

## Evidence

Current worktree on macOS / Xcode, 2026-09-18.

- `make verify`: passed (104 Swift tests, 5 public cases, 10 CLI tests, 3 appcast tests).
- Unsigned universal Release build: passed, app and Finder extension.
- Swift/Xcode cache access needed execution outside the command sandbox.
- User requested stopping temporary native tests and installing the final build
  themselves. No native runtime pass is claimed; the temporary driver was stopped.
- Finder menus, small switches, confirmation/cancellation, sandbox authorization,
  and system AirDrop UI remain for user acceptance.
- [Distribution](../../specs/domains/distribution.md) loaded for local signed DMG.
- Local acceptance build uses 0.5.6 (14) to distinguish it from existing 0.5.5.


## Local installer

- Final `make verify` passed again after the last code changes.
- Built universal Release 0.5.6 (14) with Developer ID signatures for the app,
  Finder extension, Sparkle components and DMG.
- User explicitly approved Apple notarization after the automatic approval review
  required specific authorization for that upload; no GitHub publication occurred.
- Apple submission `7232447a-61d2-4067-a71b-3185e8c8933a`: Accepted. DMG stapled;
  `stapler validate`, DMG integrity and portable SHA-256 checks passed.
- Final SHA-256: `e94fc5eb111f6e670d436ba238a1d687916c2c04a387c22d14e462bedd7f8ec9`.
- Package logs: `/tmp/filemint-0.5.6-package.log`; final automated checks:
  `/tmp/filemint-tools-verify-final.log`; mounted installer checks:
  `/tmp/filemint-0.5.6-artifact-check.log`.
- Read-only mounted installer verification passed: universal app/extension,
  matching 0.5.6 (14), Developer ID signatures, and Gatekeeper accepted with
  `source=Notarized Developer ID`. The verification image was ejected.
- Native/runtime acceptance remains unverified, by the user's explicit request.

## Documentation and website

- The user requested the related documentation and website information before
  pushing. README, website home/install/privacy pages, installation guidance,
  privacy policy, roadmap and 0.5.6 release notes now describe the per-action
  menu placement, permanent deletion and system AirDrop behavior in Chinese and
  English.
- The GitHub Release is intentionally still separate: the release notes state
  that the public latest download remains 0.5.5 until a tagged release uploads
  the DMG, checksum and appcast built from that exact commit.

# FileMint Harness

The Harness is the executable contract between SPEC and implementation.

## Rules

- Core file creation behavior must be testable without Finder, Xcode, or UI.
- Harness cases live in `specs/harness/cases`.
- A case should describe user-observable behavior, not implementation details.
- UI and Finder code may be thin; core behavior must remain deterministic.

## Case Format

```json
{
  "name": "create markdown file with rendered title",
  "templateID": "markdown",
  "requestedFileName": null,
  "existingFileNames": [],
  "expectedFileName": "Untitled.md",
  "expectedContentContains": ["# Untitled.md"]
}
```

## Commands

```sh
make verify
```

Equivalent raw commands:

```sh
swift test --package-path CorePackage
swift run --package-path CorePackage filemint-harness specs/harness/cases/file_creation_cases.json
```

## Acceptance

A change is complete only when:

- Matching SPEC text exists.
- At least one Harness or unit test covers the behavior.
- `make verify` passes locally.
- Finder-specific behavior has a manual verification note when it cannot run headlessly.

`FocusedCreationTests.repeatedMenuCreation` exercises five fresh menu actions
through single-use tickets and filesystem creation, including name increments
after older snapshots are evicted. The native LaunchServices callback/thread and
repeated visible Finder menus require the checks in `docs/FINDER_QA.md`.
`scripts/verify_bundle.sh` also verifies the main app's accessory-launch
`LSUIElement` setting in the built bundle. Native checks cover showing the Dock
icon only for the settings window's lifetime.

## Update coverage

`AppUpdateTests` covers numeric stable-version comparison, no downgrades, release
and asset validation, trusted download/redirect URLs, exact checksum filenames,
digest mismatches, and bilingual About/update text. Network and native installer
opening remain app responsibilities; record live checks, download/cancel/retry
and installation handoff evidence in `docs/ACCEPTANCE.md`.

`make verify-updates` is an opt-in network smoke check using the real app client.
It queries the public release, verifies the equal-version result, cancels after
download bytes arrive, checks cleanup, retries the complete download, and checks
SHA-256, size and macOS quarantine. It removes temporary artifacts and never
opens the DMG or installs an app. This command requires macOS and GitHub access;
ordinary `make verify` stays offline.

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


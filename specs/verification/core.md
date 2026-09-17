# Core verification

Load for Core behavior and JSON Harness changes. Use the
[verification matrix](../HARNESS.md) for the checks required by the changed surface.

## Rules

- Test observable behavior without Finder or UI. Keep deterministic rules in Core.
- The Harness accepts only the format below. There are no legacy adapters, aliases,
  silent defaults for assertions, skipped cases or unsupported fields.
- CLI and tests share `HarnessSuite.load`; Runner accepts only an immutable,
  validated suite. Validate the complete suite before creating any files.
- Fixtures live in `specs/harness/cases`. Expected content is an independent
  constant, never calculated by the implementation being tested.

## Case format

```json
{
  "schemaVersion": 1,
  "cases": [{
    "id": "increment-text",
    "name": "Increment without overwriting an existing file",
    "templateID": "plain-text",
    "requestedFileName": null,
    "existingFiles": [{"name": "Untitled.txt", "content": "keep me\n"}],
    "expect": {
      "fileName": "Untitled 2.txt",
      "content": {"mode": "exact", "value": ""}
    }
  }]
}
```

- Input is UTF-8 JSON, at most 1 MiB, 32 container levels and 1,000 cases.
  Empty suites, duplicate object keys (including escaped equivalents), unknown
  keys at any level, missing fields, invalid types and unsupported versions fail.
- Only `requestedFileName` may be omitted or null. IDs are nonblank and unique;
  descriptions are nonblank. Templates must exist in the built-in catalog.
- `content` is required: `exact` accepts only `mode` and `value`, compares UTF-8
  bytes and allows an empty value; `contains` accepts only `mode` and `values`,
  requiring a nonempty array of nonempty UTF-8 byte fragments. No normalization,
  trimming or implicit skip is performed. Contains does not prove exact content.
- Fixture and expected output names must be single nonblank filenames, without
  `.`, `..`, path separators or control characters. Fixture names are unique;
  filesystem alias collisions are setup errors. Invalid names are not sanitized.
  `requestedFileName` remains arbitrary test input for the product's sanitization.
- JSON cases exercise built-in templates with increment collisions and a fixed
  UTC date. Other creation modes and expected product errors use Swift tests;
  adding unsupported JSON options must fail rather than silently change intent.

## Filesystem and result contract

Each run owns a unique private temporary directory, with separate case directories.
Never remove a pre-existing fixed directory. Prepare fixtures with exclusive writes
and check the actual prepared bytes. Setup failure prevents that case's product call.
After creation check the output is a regular file inside the case, its name/content,
unchanged fixture bytes, and the exact set of directory entries. Never read output
outside the case or through a symlink. Checks inspect only Harness-owned directories.

Retain every case result, including failed assertions and setup errors, and continue
independent cases. Clean up only the owned run directory on normal/caught-error
paths; cleanup failure makes the suite fail. Uncatchable termination may leave a
unique temporary directory; a later run must not delete someone else's directory.

| Exit code | Meaning |
| --- | --- |
| 0 | A nonempty validated suite executed all cases and all required checks passed, with no setup/cleanup error. |
| 1 | A product call or its output/name/content/preservation/directory assertion failed. |
| 2 | Input, fixture preparation or Harness infrastructure/cleanup error; takes precedence over assertion failures. |
| 64 | Invalid CLI arguments or output format. |

Default output is concise text. `--format json` emits one report on stdout with
case IDs, assertions, diagnostic paths, bounded expected/actual summaries and totals.
Both formats come from the same report. Invalid input has status `error` and zero
executed cases; it must not crash or masquerade as a successful empty run.

## Commands and coverage

- `make verify`: context checks, Swift tests, public JSON cases and real CLI regression.
- `make verify-harness-cli`: builds the actual executable and checks it in subprocesses.
- `swift test --package-path CorePackage`: Swift tests only.
- `swift run --package-path CorePackage filemint-harness specs/harness/cases/file_creation_cases.json --format json`: a machine-readable report for the public suite.

Harness-specific tests cover malformed/ambiguous input, byte-level assertions,
setup/cleanup failures, side effects, containment and report aggregation. CLI tests
check actual exit codes, output formats, outside-cwd execution and concurrent isolation.
A deliberately failing CLI must be observed as such for its regression test to pass.
Never silently skip a missing executable, build failure, timeout or signal exit.

Product test entry points remain `FileCreationHarnessTests`, `FocusedCreationTests`
and `StartupPreferencesTests`. See [update verification](updates.md) for update suites.
Harness self-tests prove the checker behaves correctly, not additional product coverage.

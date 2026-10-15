# Batch rename authorization review fixes

Date: 2026-10-15. Parent: [batch rename task](../2026-10-14-batch-rename.md).

Result: **passed for the two requested fixes and their applicable local HARNESS
checks**. Base is `aaf966e` in the primary checkout plus the uncommitted changes
recorded in `source-hashes.json`. No production install, Git delivery, packaging
or publication was performed.

## Changes

- Persistent directory grants compare the bookmark's saved volume UUID plus
  inode, generation, birth time and kind against the current capture and fresh
  volume metadata after scoped access starts. A changed device number does not
  reject the same directory. Candidate lookup and refresh deduplication both
  handle relocation plus renumbering. Version-1 files remain compatible without
  reset; bookmarks lacking a volume UUID keep strict device matching. Operation,
  undo and recovery snapshots retain their existing strict identity rules.
- Grant saves create an exclusive 0600 temporary file in the private directory,
  complete permission setup, writing and closing, then atomically rename it over
  the cache. No fallible permission repair follows publication. Failed preparation
  preserves the old bytes or the absence of a first cache and cleans up its own
  temporary file. Store bounds and corrupt/symlink/hard-link rejection remain.

The owning [authorization contract](../../../specs/domains/finder-permissions.md#batch-rename-authorization)
and [verification checklist](../../../specs/verification/finder.md) describe these boundaries.

## Regression coverage

- Three new Core tests cover existing version-1 bookmark metadata, simulated
  device renumbering, different/missing volume UUID, changed inode/generation/birth
  time/kind, retained strict operation identity, moved-grant refresh without
  duplicates, and strict legacy fallback without persistent volume metadata.
- `make verify-batch-rename-access` is part of `make verify`. Real child sandbox
  policies deny chmod on the published filename, which must no longer make a
  save fail, and deny mode changes on temporary files, which must reject saves
  without changing the old readable cache or publishing an unusable first cache.
  Both updates and first saves are checked, with synthetic source preservation
  and no temporary-file leaks on caught failures: **11 + 11 assertions**.
- The existing signed sandbox fixture now uses a real security-scoped version-1
  bookmark with a simulated previous device number, restores at the original and
  moved parent paths without a picker, validates the complete current batch,
  refreshes to one current entry and retains strict current-operation identity.
  Its existing invalid/replaced grant, cancellation, independent recovery bookmark,
  coordinator, rename/undo/rollback and interrupted recovery checks also pass.

## Observed verification

Environment: macOS 27.2 (`26B5101f`), arm64; Xcode 27.0 (`27A266a`).

Logs and source/artifact hashes:
`.local/verification/batch-rename-auth-review-20261015.e2m39ium/`.

| Check | Result | Evidence |
| --- | --- | --- |
| `PYTHONDONTWRITEBYTECODE=1 make verify` | passed; Core **328 / 33 suites**, Images **22 / 2**, Harness **5/5**, CLI **10**, all offline checks, capture **15**, grant publication **22** | `verify-complete.log` |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed for Release App and Finder extension | `unsigned-build.log` |
| `bash scripts/build_batch_rename_harness.sh` | passed; stable QA identity, existing Developer ID, sandbox entitlements | `native-build.log`, `artifact.json` |
| Stable `BatchRenameSmoke.app/Contents/MacOS/BatchRenameSmoke` | passed **75 assertions**, process exited normally | `native-run.log` |
| `make verify-context`, `git diff --check` after evidence updates | passed | `context-final.log` |

Stable fixture:
`build/native-qa.noindex/batch-rename/BatchRenameSmoke.app`, bundle identifier
`io.github.daigua.filemint.batch-rename-smoke`, run `run.bN3yCE`. Each invocation
uses a unique directory inside that QA app's container; production preferences,
grant stores and operation records are not fixtures.

The initial full check found a Swift Testing macro compilation issue in the new
negative assertions, fixed by evaluating throwing fixture transformations before
the assertion. The next check exposed a test-only `/private/tmp` versus standardized
`/tmp` key mismatch, corrected without weakening preservation assertions. Final
full verification and the native run above passed after both corrections.

## Limits

- Device renumbering is simulated by changing only the saved `device` field;
  real scoped-bookmark resolution and parent relocation are exercised. The machine
  was not rebooted and no volume was detached/remounted.
- Installed production Finder entry, cold-launch picker and UI acceptance were
  not rerun; the previously installed Debug remains unchanged. This run does not
  inherit the older installed evidence as validation of these changes.
- macOS 13/14, separate case-sensitive APFS, VoiceOver, NAS/iCloud/provider
  compatibility and public-release verification were not run.

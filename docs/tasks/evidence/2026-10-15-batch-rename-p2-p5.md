# Batch rename P2–P5 implementation verification

Date: 2026-10-15. Parent: [batch rename task](../2026-10-14-batch-rename.md).

## Scope and delivery

P1 was committed and pushed first as `4469763` (`origin/main`). The P2–P5 work
was implemented and verified in the primary checkout on that baseline before
its delivery commit. No production installation, package or release ran.

- P2: descriptor-relative native execution, exact-object parent/item identities,
  local writable APFS checks, protected roots/private-storage ancestors, staged
  exclusive publication, rollback, recovery, undo, bounded private state and
  explicit evidence export/retirement.
- P3: one app-owned panel with ordered rules and name lists, bounded asynchronous
  preview generations, every row/detail/count, explicit commit, stop/restore,
  reverse preview and recovery/result actions.
- P4: default-off independent preferences, Finder snapshot/click capture and
  single-use rename ticket route, settings/menu/icon/localization, prompt intake
  rejection while busy, existing operation queue preservation, exact-parent
  grants, quit/update guard, File-menu undo and passive recovery card.
- P5: offline suite, unsigned App/Finder build and a signed sandbox fixture with
  its own identity, stores, synthetic items and run directories. Installed Finder,
  older OS releases, VoiceOver and separate case-sensitive-volume checks remain
  distinct from this local evidence.

## Environment and automated checks

macOS 27.2 (`26B5101f`), arm64; Xcode 27.0 (`27A266a`), Swift 6.4.
Commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
The host's default CommandLineTools selection is not the test toolchain.

| Check | Observed result |
| --- | --- |
| `PYTHONDONTWRITEBYTECODE=1 make verify` | passed; Core **318 tests / 32 suites**, Images **22 / 2**, public creation Harness **5/5**, real Harness CLI **10**, all remaining offline tooling checks |
| Context checks | passed; 22 context documents, 129 local links; entry 6986/7000 UTF-8 bytes |
| Core native rename suite | passed; 23 tests, with loops over cancellation/syscall-journal interruption points |
| Finder integration + existing tool expansion suites | passed; 16 tests / 2 suites, retaining the existing exhaustive placement assertions |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed; app and Finder extension compiled for the configured macOS 13 deployment target; this is not a macOS 13 runtime test |
| Existing move/open-with native fixture builders | passed; stable bundle identifiers and Developer ID designated requirements retained; no existing editor/receiver workflow was exercised by merely rebuilding them |

Final offline log: `.local/verification/batch-rename-p2-p5-verify-final.log`.
App build log: `.local/verification/batch-rename-p2-p5-build-final.log`.
Related fixture build logs: `batch-rename-move-builder.log` and
`batch-rename-open-with-builder.log` in the same ignored directory.

## Native sandbox fixture

The fixture is built with `bash scripts/build_batch_rename_harness.sh` and
published at `build/native-qa.noindex/batch-rename/BatchRenameSmoke.app`.
Its identifier is `io.github.daigua.filemint.batch-rename-smoke`; it uses its own
container and a fresh `FixtureRunID`, with the application sandbox, user-selected
read/write and app-scoped bookmarks. Production FileMint stores and user files
are not fixtures. No Finder extension is registered by this builder.

The fixture exercises production Core, controller and operation coordinator:
ordinary files/directories, unchanged directory descendants, swaps, case-only
names, stop during staging/publication, receipt-based undo, a real child process
exiting between steps followed by fresh recovery, stale preview isolation,
1,000-row lists, oversized-list preservation, keyboard dispatch, immediate busy
ticket consumption/rejection, frozen panel inputs, expired/replayed tickets,
and existing move requests remaining queued until the rename panel closes.

The final ordinary fixture (`run.Bc1xEZ`, invocation
`6830D421-7A4E-4BC7-B376-0358D528E573`, including the final scratch safety fixes)
passed **62 assertions**. In particular, it focuses
both a real rule `NSTextField` and the 1,000-line list `NSTextView`: ordinary Return
does not commit; after the newest preview is ready, Command-Return commits in
both languages; Escape in the list closes without mutating the source items.
Runtime summary: `.local/verification/batch-rename-native-runtime.log`.

The external-destination mode passed **14 assertions** with real native dialogs
operated through Computer Use. Before Save Panel approval the sandbox could not
open the dedicated external QA directory for reading. Cancelling the confirmation
or the Save Panel retained the original control bytes and blocker. After explicit
acknowledgement and selecting one unique file, the production descriptor-based
export verified the exact raw evidence, retired the record and preserved the
synthetic remaining staged original. The feature switches were off. Host readback
also verified the exported `index.json` bytes against the synthetic input. This
proves that tested destination flow, not that the OS granted no temporary capability
to any ancestor. Runtime summary: `batch-rename-external-export.log`; the exact
export is retained as `.local/verification/batch-rename-export-evidence.json`,
SHA-256 `c81022ed517d8f3d1cec8fab72e78d575b4d4bbf26affd6189a401657c2e8a3c`.
The final external flow used the same `run.Bc1xEZ` binary. Host verification is
recorded in `batch-rename-external-export-readback.log`.

Computer Use inspected the real Chinese/light and English/dark windows and their
accessible row/details/count labels. `cacheDisplay` PNGs omit system-composited
layers and have transparency artifacts on this OS; they are diagnostic view-cache
outputs, not the basis for the visual acceptance claim. VoiceOver speech/navigation
and installed Finder are still untested.

## Failure and review corrections

- The initial build exposed a Darwin `getattrlistat` flags type mismatch; corrected
  to the SDK's `UInt` signature.
- The first full suite exposed two test-fixture problems: the all-tools placement
  fixture did not enable the new default-off tool, and one malformed-value fixture
  accidentally contained invalid JSON. The placement assertions were preserved;
  migration cases now construct valid JSON containing invalid field values.
- Independent review added a durable preparation reservation before staging
  allocation; fixed bounded scratch slots included in opaque export; digest-bound
  terminal cleanup; interrupted retirement finalization; exact-file export grants;
  and exclusive compensation when a raced syscall claims an unexpected object.
- A final safety review added a single-link/owner/type/0600 check before reusing
  exported index scratch, so a manually created hard link cannot cause the action
  to truncate a user original. Scratch cleanup checks the opened file identity
  and preserves concurrent replacements. Both cases have explicit regressions.
- Case-only recovery rejects a third spelling instead of assuming it is the
  original. Undo preserves its own pre-operation names on failure, retains the
  prior receipt, and can undo an ordinary directory renamed to a package-looking
  name without relaxing normal selection validation.
- A focused-editor fixture initially pressed Command-Return after a fixed delay;
  finishing field editing can invalidate preview readiness. It now waits for the
  latest valid preview instead of treating that legitimate rejection as a lost
  key. Explicit Command-Return/Escape routing is centralized at the panel boundary;
  ordinary Return remains editing and unfinished input-method composition cannot
  submit the previously checked draft.
- The app holds its own exact-parent scope even if preferences releases an
  ancestor grant. Control flow uses the status returned by its own read, while
  generation checks only govern passive UI updates. Committed cleanup is labeled
  separately from restoring pre-operation names.

## Verification limits

Local native success does not establish installed Finder callbacks, real
cold/warm LaunchServices delivery, VoiceOver behavior, macOS 13/14 runtime,
case-sensitive APFS behavior, NAS, iCloud or third-party synchronization support.
The external Save Panel test is not evidence for every exact-parent folder-picker
cancellation or system-permission-revocation scenario.
The configured deployment target, API availability, pure rule tests and fixture
keyboard events are not substitutes for those scenarios. No storage-provider
classification gate was introduced.

## Source and log integrity

The code and owning-contract snapshot tested before delivery is recorded in
[source hashes](2026-10-15-batch-rename-source-hashes.json). Its aggregate SHA-256
is `89a555213d0bcdbbe3b9841827f77fe68d4905368478ce411e7e4d04a2eeccb3`.
Documentation-only result updates are outside that code snapshot.

| Retained log | SHA-256 |
| --- | --- |
| `batch-rename-p2-p5-verify-final.log` | `b60fa6242b588bb56bf1bde70b83f121f5627b610410e9d691cf58e67a48ff24` |
| `batch-rename-p2-p5-build-final.log` | `9180d78fdcfcccfacd2532a532a15088ed9030df0e3050621c1ec182834848db` |
| `batch-rename-move-builder.log` | `391664f8d7b51d40d60c12ae442403b93ef257d67a7c673d0368e1e1f488f155` |
| `batch-rename-open-with-builder.log` | `ad9d67fc7f1026fd82a0b3255f258258ec54406780bcf38ef7d531aabb91abba` |
| `batch-rename-native-runtime.log` | `c19c9c0ce929837681f2898183bd0d3b2787dc471b811663697da9644ad264c0` |
| `batch-rename-external-export.log` | `35a50f132daa328b471cea38841a1ac149f545b532d49e7ce418e049af110ef0` |
| `batch-rename-external-export-readback.log` | `a450f7d9dfabc93bc3869be4877c202920808e997643ad462fa8d983a67bac29` |

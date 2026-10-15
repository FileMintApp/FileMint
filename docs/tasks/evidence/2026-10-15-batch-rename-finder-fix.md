# Finder sandbox fix and installed Debug acceptance

Date: 2026-10-15. Parent: [batch rename task](../2026-10-14-batch-rename.md).
This follows the [earlier failed installed acceptance](2026-10-15-batch-rename-installed-debug.md).

Result: **passed for the tested local rename, undo and authorization scenarios**.
The signed final Debug is installed at `/Applications/FileMint.app`. The Finder
capture no longer requires directory-content access before main-app authorization.
Reopening the app also keeps an active native modal window in front of settings.
No entitlements, menu scope, saved preferences or user files were broadened or
replaced. Only dedicated synthetic fixtures were renamed, then fully restored.

## Source, environment and artifact

- Primary checkout base: `7b3ebea9d48765b6f521d01cd2ba6e79744f8154`, plus the
  local changes recorded in `source-hashes-final.json` below. At validation time,
  no commit or push had run.
- Final source aggregate SHA-256:
  `f212d7301a4b0d91184a626fe7e0800402866568657638335fb3624a7f453233`.
- macOS 27.2 (`26B5101f`), arm64; Xcode 27.0 (`27A266a`), Swift 6.4.
- Version 0.7.0, build 28; Debug, `ENABLE_DEBUG_DYLIB=NO`; existing Developer ID
  team `8S66M2ZLD5`, retaining the production app/Finder sandbox entitlements.
- Final ZIP: `build/FileMint-Debug-batch-rename-fixed.zip`, SHA-256
  `ead1d06e502b0c2a13e12c3e7c2142a2b6028acecb38c164495f62238d3acd06`.
  Built, installed and archived App/Finder executables were compared byte for byte.
  No notarization, release, remote workflow or publication ran.

All logs, snapshots and previous-app backups are in the ignored directory
`.local/verification/batch-rename-finder-fix-20261015.MhmBa2/`.
`artifact-final.json`, `source-hashes-final.json` and `evidence-hashes-final.json`
bind the final artifact, relevant source and retained checks.

## Fix and regression coverage

`BatchRenameSelection.capture` now captures the real parent's metadata identity,
uses metadata-only probes for every selected entry, and checks the parent again
after the complete snapshot. It does not open the parent for reading. The main
app still obtains exact-parent access, opens a pinned handle with the captured
identity, and revalidates all sources before preview and mutation. Tickets,
selection completeness, hard-link/symlink rejection and exclusive rename remain
unchanged. A new Core test replaces the parent between capture and authorization
and verifies rejection without writes.

`make verify-batch-rename-capture` executes the production capture and ticket path
in a disposable headless child sandbox denying fixture directory/content reads
and all fixture writes. It verifies that normal read handles and preparation
remain denied while metadata capture succeeds; it checks full identities/order,
ticket round trip, symlink and hard-link rejection, and host-side fixture hashes.
The unchanged old implementation failed with `NSPOSIXErrorDomain / 1`.
The final implementation passes 15 child assertions plus host preservation checks.
An initial test assertion compared directory URLs including their trailing-slash
representation; it was corrected to compare their canonical paths, without
removing the captured identity or replacement assertions.

The first installed candidate fixed Finder intake and passed real rename/undo,
but additional authorization testing found a window-lifecycle defect: an explicit
app reopen brought settings in front of an active `NSOpenPanel.runModal` session.
Thread sampling retained the call chain at `BatchRenameAccess.authorize`.
The initial preservation-only cancellation readback did not prove that the modal
or operation guard had finished; normal quit remained blocked. The user cancelled
the obscured native picker and normally quit before the next installation.
`AppDelegate.applicationShouldHandleReopen` now focuses `sender.modalWindow`
before opening settings. The [native checklist](../../FINDER_QA.md#file-and-folder-tools)
includes explicit reopen, cancel, retry, exact-parent grant and quit checks.

## Automated and bundle checks

| Check | Observed final result |
| --- | --- |
| `PYTHONDONTWRITEBYTECODE=1 make verify` | passed; Core 319 tests / 32 suites, Images 22 / 2, creation Harness 5/5, CLI 10, existing offline tooling and the new sandbox capture regression |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed for App and Finder targets |
| Direct Debug `xcodebuild`, then `scripts/sign_app.sh` | passed; original Developer ID and production sandbox retained |
| `scripts/verify_bundle.sh` on the final installed copy | passed; nested signatures, sandbox entitlements, resolved Sparkle service names, arm64, compression runtime and minimum OS metadata |
| ZIP integrity and executable comparison | passed; built, installed and archived App/Finder SHA-256 hashes match |
| Final fixture/private-state/preferences readback | passed; all 16 regular synthetic files have their original names, inodes and content hashes; no rename control files remain; saved preferences and configured scope unchanged; normal quit confirmed |

Final logs are `verify-final.log`, `unsigned-build-final.log`,
`debug-build-final.log`, `sign-final.log`, `bundle-before-install-final.log`,
`installed-bundle-final.log`, and `final-runtime-readback.json`.

## Installed runtime evidence

Both candidates used the same metadata-capture/native transaction code. Their
App entry behavior differs by the final modal-reopen fix; do not conflate the
candidate-specific observations below.

| Candidate / actual scenario | Observed result |
| --- | --- |
| Metadata fix candidate: actual Finder → ordered rule preview → explicit rename | passed; `IMG_2.JPG` → `IMG_2_001.JPG`, `IMG_10.JPG` → `IMG_10_002.JPG`, `Photos` → `Photos_003`, `archive.TAR.GZ` → `archive_004.TAR.GZ` |
| Same candidate: result-panel reverse preview → explicit undo | passed; original names and regular-file identities/content restored; folder child preserved; receipt consumed |
| Same candidate: name-list `alpha.txt` / `beta.txt` swap, then normal quit/relaunch and File-menu undo | passed; both identities followed the exchanged names, neither file was overwritten, restart preserved the receipt and undo consumed it |
| Final candidate: actual Finder request in the repository's Documents path with no usable parent grant | passed; extension delivered the snapshot and main app showed the native exact-parent picker |
| Final candidate: explicitly reopen App during that picker | passed; the native picker stayed in front, instead of settings obscuring it |
| Final candidate: cancel authorization, normal quit, then cold Finder retry | passed; no fixture/operation writes; main app exited; new Finder request launched installed main PID 72745 and showed the picker again |
| Final candidate: grant only `rename-permission-fix-n1akv53m` | passed; two-row preview opened; configured scope and saved preferences remained unchanged |
| Final candidate: invalid line count and duplicate `A` / `A` list | passed; complete per-row errors and disabled submit; no writes |
| Final candidate: `A` / `b` list for `a.txt` / `b.txt` | passed; one case-only change and one unchanged row; `.txt` preserved; exact directory spelling verified on disk |
| Final candidate: ordinary Return versus Command-Return | passed; Return kept editing; Command-Return explicitly committed the current valid plan |
| Final candidate: close result, normal quit/relaunch, File-menu reverse preview and Undo 1 Item | passed; exact-parent receipt bookmark worked after restart, `A.txt` returned to `a.txt`, `b.txt` stayed unchanged, receipt consumed and normal quit succeeded |

The runtime readbacks are `rules-renamed-readback.json`,
`rules-undo-readback.json`, `list-swap-readback.json`,
`list-undo-after-relaunch.json`, `permission-cancel-final-readback.json`,
`permission-renamed-final.json` and `final-runtime-readback.json`.
The original `permission-cancel-readback.json` proves only preservation before
the modal fix; the final cancellation claim also has successful normal-quit and
new-request evidence. Actual native UI was inspected through Computer Use;
the rename preview screenshot was a live window, not a view-cache render.

## State and limits

- All test batches were explicitly selected synthetic files in dedicated run
  directories. The ordinary directory's child file was never renamed or rewritten.
- The existing extension on state was refreshed off/on through visible system
  settings and restored to on. Only exact development registrations were removed;
  there was no Finder restart or global system/permission-database reset.
- Parent authorization did not add menu roots or alter persisted preferences.
  The existing feature-on choice remains on. Both old App backups and fixtures
  are retained locally; no user files were used as samples.
- The earlier Documents menu absence is not a proven permanent callback limit:
  this final run displayed its actual Finder action and completed authorization
  there. No claim about all special workspaces follows from that observation.
- This is local macOS 27.2 evidence. VoiceOver, macOS 13/14, separate case-sensitive
  APFS, NAS, iCloud and third-party synchronization remain untested. Actual crash,
  interruption and recovery were not reinjected into production stores; existing
  automated/isolated recovery results remain distinct.

The requested local sandbox fix, Debug installation, rename and undo acceptance
is complete. Broader compatibility checks and publication remain separate work.

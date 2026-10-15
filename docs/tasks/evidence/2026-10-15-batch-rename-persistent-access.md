# Persistent batch rename directory authorization

Date: 2026-10-15. Parent: [batch rename task](../2026-10-14-batch-rename.md).
Follows the [Finder sandbox and modal-window fixes](2026-10-15-batch-rename-finder-fix.md).

Result: **passed for the requested local reuse and renewal flows**. The new Debug
is installed at `/Applications/FileMint.app`. Directory grants persist independently
of rename/undo/recovery records. Sandbox entitlements, Full Disk Access, configured
menu scope and saved preferences were not changed.

## Source and artifact

- Primary checkout base `7b3ebea9d48765b6f521d01cd2ba6e79744f8154`, plus the local
  changes in `source-hashes.json`. At validation time, no commit or push had run;
  no notarization or publication ran.
- Source aggregate SHA-256:
  `75639d93bf58d35f0cd7a4ba0c54eba6054081eded6e281c0ef0c81c33be846b`.
- macOS 27.2 (`26B5101f`), arm64; Xcode 27.0 (`27A266a`), Swift 6.4.
- Version 0.7.0/build 28, direct Debug (`ENABLE_DEBUG_DYLIB=NO`), existing Developer
  ID team `8S66M2ZLD5`, retaining production sandbox entitlements.
- ZIP: `build/FileMint-Debug-persistent-folder-access.zip`, SHA-256
  `726c27fb50d11af7af4077dbfce832e629b81864bae944ad23f098b2b7566057`.
  Built, installed and archived App/Finder executables have matching hashes.

Logs, previous-App backup, fixture manifests and readbacks are retained in
`.local/verification/batch-rename-access-20261015.hSlw5S/`.
`artifact.json`, `source-hashes.json` and `evidence-hashes.json` bind the final results.

## Implementation

`BatchRenameAccessStore` owns the separate versioned
`batch-rename-folder-access.json`, outside operation state and preferences. It
stores the exact directory identity and read/write scoped bookmark, bounded to
4 MiB / 1,024 grants with owner-only 0600 file permissions. Corrupt, unsupported,
oversized, symlinked and hard-linked stores are rejected and preserved. Failed
persistence stops a new request before mutation.

New batches restore matching saved authority without UI/mounting, verify the
actual parent and write access, and hold their own active scope. The complete
selection and current configured scope are checked before a new/refreshed grant
is saved. Cancelling an eligible preview retains the grant. Undo, forgotten or
replaced receipts, manual retirement and operation cleanup do not clear it; it
is excluded from recovery evidence and preferences/template export.

A valid matching configured-folder or previous-receipt bookmark can seed the
store. Undo/recovery retain independent operation bookmarks, so a damaged reusable
cache cannot block compensating authorization. Already discarded old bookmarks
cannot be reconstructed: those folders need one new explicit selection if no
other valid saved authority remains.

Failed bookmark resolution/access or a directory-identity mismatch requires the
exact-parent picker. A rejected saved authority is not bypassed using ambient
temporary access. Cancelling renewal preserves the old record; confirmation
updates it after complete request validation. Normal operation-end scope release
does not delete the durable bookmark.

## Checks

| Check | Observed result |
| --- | --- |
| `PYTHONDONTWRITEBYTECODE=1 make verify` | passed; Core **325 tests / 33 suites**, Images **22 / 2**, creation Harness **5/5**, CLI **10**, existing offline checks and metadata-capture sandbox regression **15 assertions** |
| New Core grant-store suite | passed; private persistence, moved/replaced identities, bounds, damaged/unsupported data, symlink/hard-link protection, real undo/forget/manual-retirement independence |
| Unsigned App/Finder build | passed |
| Signed isolated native fixture | passed **69 assertions**; real scoped-bookmark restoration in fresh access instances, invalid/replaced authority requiring renewal, cancellation preservation, operation bookmarks working with a damaged cache, and eligible previews persisting grants |
| Direct Debug build/sign/install and installed bundle verification | passed; original Developer ID, nested signatures, sandbox, Sparkle services, arm64 and compression runtime |
| ZIP integrity and installed/built/archive comparison | passed |

The fixture's coordinator and recovery-export adapters use injected private grant
stores, never the production cache. Its existing rename, rollback, recovery,
keyboard, preview and ticket checks also passed. Initial compilation caught
missing inner `try` in new Testing macros and an omitted MainActor annotation on
the injected picker callback; both were corrected before the final checks.

## Installed Finder acceptance

Dedicated parent: `build/debug-acceptance.noindex/rename-access-reuse-j7od014c`.
The independent production grant file was absent before testing. All files were
new synthetic samples with recorded names, inodes and hashes.

| Actual scenario | Result and readback |
| --- | --- |
| First request without a usable grant | Native exact-parent picker appeared with the remember-access explanation. Explicit selection saved a separate 0600 grant and opened preview, with no source/operation changes. `first-grant-readback.json` |
| Cancel preview and quit | Grant survived; main app exited normally. `preview-cancel-quit.json` |
| Cold new batch | New main PID **83425** opened preview directly without an authorization picker. `cold-new-batch-process.json` |
| Rename then undo | Command-Return produced `renamed_a.txt` / `renamed_b.txt`; original identities/content were preserved. Undo returned exact original names and cleared operation/receipt state; independent grant bytes were unchanged. `renamed-readback.json`, `undo-keeps-grant.json` |
| Quit and cold new batch after undo | New main PID **83468** again opened preview directly, with no undo receipt available. `post-undo-quit.json`, `post-undo-cold-process.json` |
| Same-path parent replacement | Original directory/files were preserved in the dedicated `-original` sibling; new parent had different identity. Finder was navigated through its parent listing to select the actual replacement, avoiding stale references to moved files. `replacement-fixtures.json` |
| Request against replacement | New main PID **83522** showed the exact-parent picker rather than reuse the old identity. `replacement-process.json` |
| Cancel renewal | Cache bytes and replacement files stayed unchanged; normal quit succeeded. `renewal-cancel-readback.json` |
| Explicitly renew | Preview opened and cache identity changed to the actual replacement parent; all original/replacement files remained intact. `renewal-success-readback.json` |
| Quit and cold retry after renewal | New main PID **83600** opened preview directly without another picker. `renewed-cold-process.json` |

`final-runtime-readback.json` confirms all four synthetic regular files retain
their expected names, identities and hashes, operation state is empty, the renewed
private grant remains, saved preferences are byte-identical to the initial
snapshot, and the final main app quit normally. The original fixture parent was
intentionally moved only by the host-side identity-replacement test.

This is local macOS 27.2 evidence. Invalid-bookmark resolution/cache damage were
injected in the isolated fixture; installed renewal used a real directory-object
replacement. No TCC database or system privacy switch was changed to simulate
revocation. Older OS, VoiceOver, separate case-sensitive volume and NAS/iCloud/
provider compatibility remain untested. The approved test-parent grant remains
in the cache independently of cleared undo records.

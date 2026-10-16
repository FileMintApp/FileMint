# Installed Debug batch rename acceptance — 2026-10-16

Result: **passed for the listed local flows; live menu-interaction coverage
remains incomplete**. Debug is installed at `/Applications/FileMint.app`.
No product code changed during this acceptance.

Parent: [batch rename task](../2026-10-14-batch-rename.md). Follows the
[workspace redesign](../2026-10-16-batch-rename-design.md).

## Source, installation and automatic checks

- Clean primary source revision `c97f01ba15acc82fd06642f01921fee3fd898ac0`,
  version 0.7.0/build 28; arm64 macOS 27.2 (`26B5101f`), Xcode 27.1
  (`27A9275`), Swift 6.4.
- `make project`, then the documented direct Debug `xcodebuild` command with
  `ENABLE_DEBUG_DYLIB=NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`: passed.
- Original Developer ID, team `8S66M2ZLD5`, using `scripts/sign_app.sh`.
  `scripts/verify_bundle.sh` passed before/after installation: signatures,
  production sandbox, resolved Sparkle services, arm64 and compression runtime.
- Quit the previous main app normally; preserved its complete bundle under
  `.local/debug-acceptance-20261016/installed-before`. Replaced only the installed
  bundle. All 89 installed files/symlinks match the signed build.
- Main SHA-256: `eca544f45637e3fa44f13283831394986bb57d711a265da05242dfb0d4d90e12`.
  Finder SHA-256: `6f362acba2791b8e6f1baefbaac34e088fc365e23fdb070be5dca43219a5233c`.
- Initially Finder PID 753 still mapped the backed-up old extension. Refreshed
  its existing System Settings switch off then back to its original on state.
  Final extension PID 89772 and main PID 89929 map the installed executables;
  PluginKit lists one enabled installed Finder registration. No force quit or
  system registration/privacy database reset was used.
- Explicit `NATIVE_QA_SUITES=batch-rename make native-qa-plan` and
  `make verify-native-affected` passed. Fresh signed fixture `run.acNHuJ`
  completed **118 assertions**: mixed files/folders, swaps, case, rollback,
  crash recovery, undo, revisions, keyboard dispatch, views and ticket intake.
  Report: `build/native-checks.noindex/run.yybr__x0/report.json`.

Logs/readbacks are retained in `.local/debug-acceptance-20261016/`:
`build-debug.log`, `sign-debug.log`, `verify-installed.log`, `installation.json`,
`refreshed-processes.json`, `rules-committed.json`, `final-processes.json` and
`final-state.json`. Full `make verify` was not repeated: this request selected
the affected native fixture and actual installation checks without code edits.

## Actual installed Finder observations

Fixtures: `build/installed-rename-qa-20261016/`, with 22 recorded synthetic entries
including 16 regular files and a directory child sentinel. Used `01-rules`,
`02-swap` and `03-conflict`; other prepared samples were left untouched.

| Scenario | Observed result |
| --- | --- |
| Finder selection and redesigned workspace | passed; seven mixed items, original/final names, states/counts and complete selected-row details |
| Exact-parent picker cancel/retry | passed; explicit reopen kept the picker focused; Cancel preserved all sources, grant bytes and operation state; normal quit and retry worked |
| Grant, cancel preview, quit, cold Finder request | passed; main-process absence verified, then direct preview without another picker |
| Empty rules and ordinary Return | passed; zero-change submission disabled; ordinary Return left editing active |
| Chinese prefix plus numbering | passed; seven actual targets matched preview; IMG_2 preceded IMG_10; .JPG, .TAR.GZ and .d.ts retained exact suffix spelling |
| File/folder preservation | passed; object inodes and file hashes preserved; the folder child kept its name, inode and contents |
| Quit/restart and File-menu undo | passed; complete reverse preview restored seven originals and consumed the receipt |
| Quit/cold Finder request after undo | passed; saved access reused without a receipt or operation controls |
| Name-list validation | passed; wrong line count and duplicate targets disabled the entire submission |
| Internal name swap | passed; alpha.txt/beta.txt exchanged names with corresponding identities/content, then undo restored both |
| External target occupation | passed; selected only a.txt/b.txt, proposed occupied.txt, observed the unselected occupant conflict and disabled submission; first-issue navigation selected its details; cancellation wrote nothing |
| Result-page undo, clean repeat | passed; a new swap followed directly by result-page Undo opened a valid reverse preview; Command-Return completed undo |

An earlier result-page undo showed a ready preview followed by persistent
“checking”. That attempt also encountered an accessibility failure while the
old window closed and a stale-state action rejection. Escape preserved the
receipt; reopening through File restored the files. The separate clean repeat
passed. Retain this as an **unconfirmed anomaly**, without claiming either a
reproducible product defect or a fix.

## Limits and final readback

- **blocked in live automation:** selecting a different sort order with a
  populated name list did not reliably activate reassignment confirmation in
  Computer Use. Control/menu labels were observed, but cancel/confirm behavior
  was not accepted as passed. This is a verification gap, not proof of a broken
  ordering contract.
- **not-run in the installed app:** injected crash/recovery, same-path parent
  renewal, case-only naming, large selections, VoiceOver, older systems, actual
  reboot/remount and NAS/iCloud/other provider compatibility. Isolated-fixture
  results and historical evidence remain separate.
- Final readback, 19:58:51 Asia/Shanghai: all 22 originals retain original names,
  inodes and contents; no rename-control/staging files remain. Finder added only
  `.DS_Store` metadata inside the fixture root.
- Preferences/menu scope stayed byte-identical, SHA-256
  `c6ca47c27c191110cfe9d2f57e793b3e3b842784971b02cddd30592f846529fa`.
  The separate grant store intentionally retains the explicitly authorized test
  parents; it was not reset or edited directly.
- A premature navigation-tool paste created a synthetic text clipping. Moved it
  intact to the ignored evidence directory and excluded it from rename inputs;
  later navigation checked the dialog first. Native paste reproduced Chinese
  text after typed text failed to enter the complete requested string.
- Installed FileMint remains available with the existing batch-rename setting.
  No commit, push, archive packaging, notarization or publication ran.

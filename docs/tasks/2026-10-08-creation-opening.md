# Task: Respect configured post-creation applications

Status: complete
Next action: Delivery authorized; follow [release 0.6.8](release-0.6.8.md).

## Objective and scope

- Explicit applications receive newly created files directly; system-default
  opening follows the current macOS association. Neither route has a FileMint
  editor, publisher or content-type allowlist.
- Trace saved template actions through quick tickets and the creation panel,
  including temporary overrides, receipt identity, retry and busy/access lifetime.
- Preserve user files, real preferences, system associations and installed apps.
  Installation, versioning and publication are outside this task.

## Selected context

- Contracts: [Creation](../../specs/domains/creation.md),
  [Templates](../../specs/domains/templates.md),
  [Open with App](../../specs/domains/open-with.md),
  [Finder permissions](../../specs/domains/finder-permissions.md),
  [Startup](../../specs/domains/startup.md).
- Entry points: `TypesPane`, `PreferencesModel`, `CreationFollowUp`,
  `CustomFileSavePanelController`, `PostCreationActionExecutor`,
  `OpenWithApplicationAccess`, Finder quick creation tickets.
- Checks: [HARNESS](../../specs/HARNESS.md),
  [Core](../../specs/verification/core.md),
  [native checks](../../specs/verification/finder.md).

## Decisions and progress

- The earlier local fix removed the allowlist only for explicit applications;
  the user clarified that system-default opening must also defer to macOS.
- Removed the editor policy and publisher-signature validator. Default opening
  now calls the native default-application API without selecting a handler.
- Both native APIs activate the application and send the created file in one
  request. Application startup and macOS security decisions belong to the OS.
- Added a ticket-store dependency with the same production default so native
  route tests can exercise `handle(url:)` without real request-store writes.

## Chain review

- `TypesPane` passes the chosen action and captured app into `saveType`, which
  saves the template and separate local app registry atomically. Reloaded
  preferences preserve the association by stable template/application IDs.
- Finder quick actions carry the captured directory and exact template ID in a
  single-use ticket. The app consumes and checks it, writes the file and sends
  only the successful creation receipt to the shared completion executor.
- The panel resolves Follow Template or the current override at submission,
  closes only after successful creation, and invokes that same executor.
  Overrides do not rewrite saved template actions. Failed writes do not open apps.
- Explicit dispatch resolves and validates the saved local app reference and
  calls native opening with the successful receipt's URL. Default dispatch
  passes that URL directly to macOS; it does not preselect or filter a handler.
- Both caller routes hold destination access through the awaited completion;
  the executor holds app access for explicit opening. Pending work continues
  through the callback after the panel closes, preventing premature quit/restart.
- Retry has no writer dependency, collision output uses the actual incremented
  filename, and stale/disabled actions or changed receipts cannot open another file.

## Evidence

Tested worktree: primary `main`, base `e0ba136` plus task changes.
Environment: macOS 27.2 arm64 / Xcode 27.0; VS Code 1.141.0,
WPS Office 12.1.26050 (26050), TextEdit 1.21 (419).

| Check | Status | Observed result |
| --- | --- | --- |
| Configuration, quick route, panel, executor static trace | passed | Chain and access lifetime reviewed above; no remaining editor, publisher or content-type opening policy. |
| `make verify` | passed | 220 Core tests, 14 image tests, 5 public cases, 10 CLI regressions and offline release checks. [Log](../../build/opening-chain-2026-10-08.f4gv9s80.noindex/verify.log). |
| Unsigned `make build` | passed | App and extension built; existing Quick Look async-alternative warning remains. [Log](../../build/opening-chain-2026-10-08.f4gv9s80.noindex/build.log). |
| `run_creation_opening_checks.sh` | passed | Native explicit JS/DOCX/XLSX/binary reception; native default association to an arbitrary fixture app; 12 saved-action quick/panel combinations; 6 collision receipts; cancellation, override, errors, retry, duplicate completion, stale gate and replaced-file checks. Default JS/Office route matrix uses dispatch spies; the fixture-specific default association uses the real API. [Log](../../build/opening-chain-2026-10-08.f4gv9s80.noindex/native.log). |
| Installed editor callbacks | passed | VS Code received panel and quick JS files; WPS cold launch received DOCX and warm instance received XLSX; system-default TXT dispatched to TextEdit. Isolated settings/tickets and temporary files only. [Log](../../build/opening-chain-2026-10-08.f4gv9s80.noindex/installed-apps.log). |
| Live editor windows | passed | CUA observed both JS tabs in VS Code and the Quick sample's exact two-line code, the blank DOCX page and Excel Sheet1 in WPS, and the TXT marker in TextEdit. Closed only these test documents afterward. No document-repair prompt was observed. |
| Installed Finder entry and macOS 13 | not-run | No installed FileMint was replaced; current-host fixture uses production ticket handler, model, panel and executor. This is not shipped Finder or cross-version acceptance. |

Pre-push reconfirmation (2026-10-08): rebuilt and reran the focused native suite
against the current worktree; every check passed again. The
[source snapshot](../../build/opening-confirmation-2026-10-08.6rnm4swk.noindex/source.json)
was unchanged across that run, and the removed editor-identity file remained
absent. [Fresh native log](../../build/opening-confirmation-2026-10-08.6rnm4swk.noindex/native.log).
No product-code edits were needed during this reconfirmation. At that check,
changes were uncommitted and `project.yml` was version 0.6.7 / build 26. This confirmation
does not perform a new signed/notarized release or installed-Finder acceptance.

## Handoff

- No implementation work remains for these opening semantics. Fix commit
  `acfa69e` records the code and checks. The user then authorized the standard
  [0.6.8 release](release-0.6.8.md); release results are recorded there.
- Installed Finder entry points, macOS 13 and every third-party application's
  format compatibility are not claimed by this bounded verification.

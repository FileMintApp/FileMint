# Task: Full-review corrections

Status: complete
Next action: None for implementation or verification. Authorized delivery target: `origin/main`.

## Objective and scope

- Fix the five issues identified in the whole-product review: queued ticket expiry,
  OCR pixel-budget scaling, quadratic template rendering, failed preference-save
  state, and release website artifact verification during download.
- Preserve ticket freshness/replay protection, operation order and permission
  boundaries, template single-pass semantics, image limits and release identity.
- Work in the primary checkout. After verification, the user authorized committing
  and pushing all corrections and regressions to `origin/main`. Publication,
  installation and changes to production preferences remain outside the request.

## Selected context

- Contracts: [File tools](../../specs/domains/file-tools.md),
  [Finder permissions](../../specs/domains/finder-permissions.md),
  [Startup](../../specs/domains/startup.md),
  [Creation](../../specs/domains/creation.md),
  [Templates](../../specs/domains/templates.md),
  [Resource tools](../../specs/domains/resource-tools.md),
  [Updates](../../specs/domains/updates.md),
  [Distribution](../../specs/domains/distribution.md).
- Entry points: `FileOperationCoordinator`, `FileOperationTicket`,
  `PreferencesModel`, `TemplateRenderer`, `ImageProcessor`, `ImageDimensions`,
  and `scripts/release_publication.py`.
- Verification: [HARNESS](../../specs/HARNESS.md),
  [Core](../../specs/verification/core.md),
  [Finder](../../specs/verification/finder.md),
  [Native QA](../../specs/verification/native-qa.md).

## Decisions and progress

- Separate read-only review findings from the implementation verification below.
- Template rendering uses original UTF-16 match positions and appends original
  fragments/replacements once, preserving literal replacement text.
- Deployment preparation rechecks the exact artifact, successful run/attempt and
  public release after downloading and before exposing the deployment output.
- Core and native tests use isolated stores/files and production entry points.
- Ordinary ticket intake captures receipt time synchronously and starts private
  single-use consumption immediately. FIFO execution still checks current scope,
  preferences and identities. Immediate read/rename busy rejection is preserved.
- Folder selections are captured as one candidate and grants are restored only
  after successful persistence. Failed edits restore the previous settings.
  Menu-bar/update choices also roll back, and the update observer reads the
  final value rather than a temporary `@Published` value from the rejected edit.
- OCR alone chooses a longest edge that also fits the 16 MP budget, reserving
  decoder-rounding headroom. Explicit Resize target validation is unchanged.
- An independent review of the combined production changes found no additional
  actionable issue. The first design fixture build caught a test-local assertion
  helper scope error; it was corrected and that suite was rebuilt and rerun.

## Evidence

Tested commit/worktree: primary `30c92670d84b21079e7e30457fa264252278b384`
plus these uncommitted corrections.
Environment: arm64 macOS 27.2 (26B5101f), Xcode 27.1 (27A9275), Swift 6.4.
Native reports retain source diff/untracked-file hashes. Final evidence-only
documentation updates follow those reports.

| Check / command | Status | Observed result / evidence |
| --- | --- | --- |
| `make verify` | passed | Final full run after the fixture correction: 363 Core and 23 Images tests, public JSON/CLI cases, publication/Homebrew/signing/runner and restricted permission checks. [Final log](../../build/review-corrections.noindex/verify-final.log) |
| Unsigned `make build` | passed | Final incremental check after production changes; main/embedded Finder executables exist. [Log](../../build/review-corrections.noindex/build-final.log) |
| `batch-rename`, `template-workflow`, `creation-opening`, `update-scheduling`, `open-with`, `file-info` | passed | Fresh signed isolated fixtures in [initial native report](../../build/native-checks.noindex/run.setsaegn/report.json); its overall failure belongs to the separately repaired design-fixture build below. |
| `design-ui` | passed on recheck | Corrected the new assertion helper's scope, rebuilt the fixture and passed settings rollback, active automatic-check preservation, appearance and window checks. [Final design report](../../build/native-checks.noindex/run.qyv1w57g/report.json) |
| Queue regression | passed | Real resource panel holds execution; virtual receipt clock advances 61 seconds. Prompt consumption, FIFO, expired-inbound rejection, replay and busy-state assertions pass. [Log](../../build/native-checks.noindex/run.setsaegn/open-with.log) |
| OCR regression | passed | Newly compiled production pipeline recognizes blank 4096/5000 square PNGs without size failure and preserves original bytes. Core covers limits, portrait/landscape dimensions and no enlargement. |
| Deployment race regression | passed | 49 publication tests, including nine changes injected during download; invalidated candidates emit no deployment path. Included in `make verify`. No remote request or publication. |
| Template performance | passed | Current-source `swiftc -O`: 1.04 MB repeated-token input improved from 2.95 s to 0.026–0.040 s; 2.08 MB from 11.79 s to 0.047–0.053 s. Core regression checks 160,000 replacements and exact Unicode/single-pass semantics without timing thresholds. |
| Installed Finder/external grants/online deployment | not-run | Separate runtime boundaries; no publication requested |

## Handoff

- Remaining implementation/verification work: none. Routine Git delivery to
  `origin/main` was subsequently authorized on 2026-10-23; installation and
  publication were not requested.
- `make native-qa-plan` conservatively included update-summary because the design
  fixture changed. Explicit seven-suite selection excludes that unrelated About
  rendering mode; no summary/UI behavior changed. OCR uses production image tests
  and does not change native resource controls or authorization.
- Known limitations: fixtures do not prove installed Finder delivery, external
  folder authorization persistence, every storage provider, or older macOS.
  External security-scoped grant lifetime is protected by the save-success code
  boundary; the isolated settings fixture directly verifies state/bytes and
  update lifecycle, not an external-folder picker grant across restarts.

# Task: Signed sandbox-to-native access prototype

Status: in-progress
Next action: Run the retained NAS case when a mounted network test directory is available; decide separately whether to migrate the full production app.

## Objective and scope

- Evaluate a non-sandboxed FileMint host with a sandboxed Finder extension.
- Use a separate fixed QA identity, data and loopback update source; leave the
  installed FileMint, production preferences, entitlements and release feeds alone.
- Verify folder-authorization prompts after a user-granted Full Disk Access,
  network-volume access when available, and sandbox-to-non-sandbox upgrade.
- User has no NAS test target. NAS remains not run; do not substitute local tests.

## Selected context

- [Finder permissions](../../specs/domains/finder-permissions.md),
  [creation](../../specs/domains/creation.md), [Open with App](../../specs/domains/open-with.md),
  [favorites](../../specs/domains/favorite-locations.md), [startup](../../specs/domains/startup.md),
  [updates](../../specs/domains/updates.md), [distribution](../../specs/domains/distribution.md).
- [HARNESS](../../specs/HARNESS.md), [Native QA](../../specs/verification/native-qa.md),
  [Finder checks](../../specs/verification/finder.md), [update checks](../../specs/verification/updates.md).
- Entry points: native QA publisher/builders; production FileCreationService,
  FileMintPreferencesStore, FavoriteLocationsStore and OpenWithFolderAccess.

## Decisions and progress

- QA build 27 uses the current 0.6.8 storage model and App Sandbox. Build 28 uses
  the same fixture and identity with App Sandbox absent. Both use Hardened Runtime.
- Tests use synthetic data and production Core/access helpers. A successful
  fixture upgrade is not a claim that every feature in the production app migrated.
- System Settings changes remain explicit user actions. No TCC reads or resets.
- No new dependencies, public release, production installation or worktree.

## Evidence

Base: `4aaddad`, primary checkout. Native execution on macOS 27.2 (26B5101f), arm64,
2026-10-10. The user explicitly confirmed enabling FDA for the QA identity.
The fixture does not read or infer the system switch. An independent GUI launch
used PID 52246 before upgrade and PID 52301 afterward.

Generated run: `build/access-migration-harness.noindex/run.rtLnNR2x`.
Stable app: `build/native-qa.noindex/access-migration/FileMintAccessQA.app`.
Evidence: `result.json`, `runtime-events.jsonl`, `signature-evidence.json`,
old/new signed bundles and local signed ZIP/appcast inside the generated run.
Live source events are in the matching per-run `FileMintAccessQA` Application
Support directory. They contain scenario labels/error codes, not user paths/content.

| Check | Status | Evidence |
| --- | --- | --- |
| Offline regressions | passed | `make verify`; `/private/tmp/filemint-access-qa-verify.log`. After the final fixture changes, 15 QA tests and the signed build pass. |
| Signed baseline/candidate | passed | Developer ID / Hardened Runtime, same designated requirement. Host sandbox true → absent; Finder sandbox true in both. Two builds retained the same stable identity/path with different run data. Local prototype is not notarized. |
| FDA / sandbox baseline | passed | Desktop and Documents each showed one real NSOpenPanel from production OpenWithFolderAccess. Both were cancelled; subsequent writes failed with EPERM. |
| FDA / non-sandbox candidate | passed | Same two destinations: zero helper folder pickers, create/read/move/delete and collision checks passed; no intervening target-folder grant. |
| Real permission failure | passed | Owned read-only directory: EACCES on both versions, zero helper folder pickers; no claimed access success for writes. |
| Local Sparkle replacement and data migration | passed | Build 27 → 28 at the same path, old process absent, new PID running. Actual installed signature reverified. Preferences/custom text template/favorites/folder-access bytes unchanged; saved folder and favorite bookmarks resolved and favorite identity matched. |
| NAS | not-run | User has no mounted NAS test directory |
| Production old-to-new / installed Finder | not-run | Separate from minimal prototype evidence |

## Interpretation and limits

- This verifies the core hypothesis on this Mac: removing the host sandbox can
  eliminate the extra folder-picker layer after the user's FDA grant. FDA did not
  override a real read-only filesystem permission.
- Build 27 is a synthetic baseline using current 0.6.8 Core storage/access code,
  not the public FileMint binary. The updater uses a minimal QA user driver. This
  is real Sparkle replacement evidence for the architecture change, not full
  production migration acceptance or public-update/notarization proof.
- Old production preferences/stores and installed FileMint were not read or changed.
  Production entitlements/signing validation remain unchanged.
- NAS unavailable; real Finder callback/loading, FDA revocation and other supported
  macOS versions remain outside the observed results. The real separate Finder
  extension is bundled and sandbox signed, but was not enabled during these checks.

## Repeating the checks

1. Quit the QA host. Run `bash scripts/build_access_migration_harness.sh`; it
   creates a fresh data run and prints the stable app and `fixture.json` paths.
2. Serve only the generated `server` directory with `python3 -m http.server PORT
   --bind 127.0.0.1 --directory SERVER`, using the port from `fixture.json`.
3. Launch the stable old host. The user enables FDA in System Settings, then
   quits/reopens the host and records that declaration in the QA popup control.
4. Click Test Local Folders; cancel baseline folder-grant panels to avoid adding
   a grant that would contaminate the comparison. Record the observed failures.
5. Run the isolated update. Require new process/build 28, matching source hashes,
   bookmark/identity checks, and the actual new installed entitlements.
6. Repeat local probes. With a real NAS later, enter an explicitly chosen mounted
   network directory. The probe requires `volumeIsLocal == false`; local folders
   cannot produce a passing NAS result. The app creates/removes only unique QA
   children, but uses the real mounted directory's access rules.
7. Stop the loopback server after the run. FDA revocation is a separate manual
   System Settings action; the harness never alters it.

## Handoff

- Keep all generated apps and evidence in the ignored build run / QA data root.
- Public rollout remains outside this prototype request.

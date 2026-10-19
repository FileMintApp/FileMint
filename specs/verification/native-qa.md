# Native QA identity and publication

Load for native QA builders, signing, stable launch paths and per-run data.
The owning rules are in [HARNESS](../HARNESS.md#native-qa-application-identity).

## Automated local checks

Use `make native-qa-plan` to select checks from tracked/untracked working changes
against HEAD. Set `NATIVE_QA_BASE=HEAD~1` for an already committed change, or
`NATIVE_QA_SUITES=batch-rename,file-tools-settings` after reviewing the actual
behavior in a shared file. `make verify-native-affected` executes that plan.
The equivalent CLI is `python3 scripts/native_checks.py plan|run`, with `--base`,
repeatable `--path` / `--suite`, and explicit `--all` for runner maintenance.

The runner reuses the existing builders, fixed identities and signed stable
paths. It runs serially, verifies the published identity and fresh build run ID,
and requires both exit 0 and each suite's completion marker. Logs and a JSON
report live in a unique directory under `build/native-checks.noindex`. Every new
invocation rebuilds selected fixtures with fresh data. No previous pass or last
good bundle can substitute for a failed build. An empty plan is `not-applicable`,
not a successful native test.

Automatic suites are `batch-rename`, `template-workflow`, `creation-opening`,
`update-scheduling`, `open-with`, `file-tools-settings`, `file-info`, `resource-tools`,
`design-ui`, and the headless `favorite-model`. Template scenarios share one
fresh build in a run and each create their own runtime workspace. Design QA uses
`--verify-automation`; ordinary interactive modes remain available.

The plan reports affected manual boundaries: real Finder delivery, external
folder grants, login-item registration, the interactive move/update fixtures,
isolated Sparkle installation and the access-migration experiment. Unknown
runtime paths require review. Such unresolved requirements return a nonzero
result even when the selected automatic suites pass. Explicit suite selection
is a reviewed scope choice, not proof of unrelated manual boundaries.

Local Developer ID signing and a logged-in macOS desktop are required for GUI
fixtures. Keep keys local; source CI runs only the runner's offline regressions.
Build/runtime deadlines are bounded. A timeout may stop only the process group
started by this invocation; never terminate an app discovered as already running.
If an owned process cannot stop normally, retain it as blocked and require normal
closure before rebuilding. Do not force-kill an app or manipulate permission stores.
Environment overrides that select external editors, terminals, pickers or
interactive fixture modes are removed from automatic child processes.

Selection is a conservative path-based plan, not semantic coverage analysis.
Pure Core rule and documentation changes do not start GUI QA by default. Review
shared-file changes against the owning contract before choosing a narrower set.
See the [implementation task](../../docs/tasks/native-qa-automation.md) for evidence.

## Identity registry

`scripts/native_qa.py` owns the finite QA kind registry. Builders create fresh
source bundles and publish them into `build/native-qa.noindex/KIND/APP.app`.
Launch the stable path printed by the builder, rather than its staging copy.
All paths below are relative to that stable root.

| Kind | App | Bundle identifier |
| --- | --- | --- |
| template-workflow | TemplateWorkflowSmoke.app | io.github.daigua.filemint.template-workflow-smoke |
| open-with | OpenWithSmoke.app | io.github.daigua.filemint.open-with-smoke |
| file-tools-settings | FileMintToolsUIQA.app | io.github.daigua.filemint.tools-ui-qa |
| file-info | FileInfoSmoke.app | io.github.daigua.filemint.file-info-smoke |
| batch-rename | BatchRenameSmoke.app | io.github.daigua.filemint.batch-rename-smoke |
| move-sandbox | FileMintMoveSandboxSmoke.app | io.github.daigua.filemint.move-smoke |
| update-sandbox | FileMintUpdateSandboxSmoke.app | io.github.daigua.filemint.update-smoke |
| design-ui | FileMintDesignQA.app | io.github.daigua.filemint.design-qa |
| resource-tools | FileMintResourceQA.app | io.github.daigua.filemint.resource-qa |
| sparkle-installation | UpgradeQA.app | io.github.daigua.filemint.upgrade-qa |
| access-migration | FileMintAccessQA.app | io.github.daigua.filemint.access-qa |

The template/opening receivers retain their own stable identifiers and sit inside
their host's Resources. The update fixture's inert extension remains separate from
the actual Finder extension. No running fixture or receiver may be overwritten.

`bash scripts/build_file_info_harness.sh` builds a sandboxed fixture using the
production information controller/view, streaming service, ticket store and file
operation coordinator. Isolated files/preferences and a named pasteboard cover
metadata-only opening, five choices, exact known digests, comparison/copy,
invalidating results, cancellation/close, busy request consumption and revoked
preferences. A synchronized read gate verifies the busy guard survives until the
real descriptor is cleaned up. Cache renders cover minimum-size light/dark views;
they are not live keyboard, VoiceOver, installed Finder or external-folder grant
evidence. The fixture requests no production preference or directory access.

`bash scripts/build_batch_rename_harness.sh` builds the sandboxed batch-rename
fixture using the production Core service, controller and SwiftUI view. Launch
the printed stable application's executable. It creates a fresh invocation
directory beneath its own container and the build's `FixtureRunID`; preferences,
operation records, synthetic files/folders and screenshots stay inside that
directory. It never opens production stores or registers a Finder extension.
The fixture also drives the production operation coordinator with injected
isolated stores: busy rename requests are consumed/rejected without replacing
the current panel, other tickets retain queue timing, and expired/replayed
requests release operation ownership. Its independent grant-store scenarios
exercise real scoped-bookmark restoration, invalid/replaced grants requiring
renewal, cancelled renewal preserving records and operation bookmarks remaining
usable with a damaged cache. A simulated previous device number must not prevent
real scoped-bookmark restoration, including after moving the same parent; refresh
must replace the old path entry and preserve the current operation identity.
This simulation is separate from actual reboot/remount evidence.
All grant stores are injected per run, outside the
isolated operation directory and without production-store access. Set
`FILEMINT_BATCH_RENAME_EXPORT_ARTIFACTS=1` to emit each freshly rendered PNG as a
JSON line on stdout (`artifact` and `pngBase64`); redirect stdout to an owned
build file before decoding those artifacts. This explicit export avoids needing
host access to the QA app's private container.
Set `FILEMINT_BATCH_RENAME_INTERACTIVE=1` to keep the preview open for explicit
keyboard/accessibility inspection. Automated view renders and internal action
checks are not evidence of VoiceOver or installed Finder callbacks.
The PNGs are AppKit view-cache renders; macOS may omit composited control layers.
Use the live fixture for visual acceptance instead of treating a missing cached
layer as a product rendering defect.
`FILEMINT_BATCH_RENAME_MODE=external-export` runs an interactive manual-resolution
fixture with intentionally corrupt synthetic control bytes and both tool switches
off. Cancel the first confirmation; acknowledge the second and cancel its Save
panel; acknowledge the third and choose a unique JSON destination in a fresh
host-owned QA directory. Read back that exported envelope from the host and verify
the `index.json` bytes equal `FileMint QA corrupt control record\n`. The fixture
checks that both cancellations preserve the blocker and original bytes, and that
successful retirement preserves its separate synthetic remaining original. The
Save panel grants only the chosen evidence destination; no production or broad
home-folder grant is required.

## Build and data ownership

- Run the existing `build_*_harness.sh` for the selected kind. Developer ID signing
  is local; use the project's existing certificate or the explicit QA identity
  override. Preserve existing sandbox entitlements and runtime flags.
- Every build has a unique run root and `FixtureRunID`. Persisted sandbox data
  (including pending moves and updater events) uses that run ID. Where persistence
  is intentional, relaunches retain the same run's data; another build gets separate data.
- `FixturePath` continues to refer to the generated run's fixtures, never the
  stable app directory or production preferences. Receivers use the current host's
  bundled URL. QA application paths do not grant access to fixture folders.
- Publishing verifies the source app's identity/signature, checks stopped state,
  holds a per-kind lock, stages a complete copy, and preserves the last verified
  app on a failed replacement. The immutable identity record binds the workspace,
  bundle ID, signing identity and designated requirement, with no private keys.
- For Sparkle, set the run ID in both old/new bundles before signing. Copy the
  already-signed old host without re-signing, preserving its ephemeral update key
  and archive signature; retain the per-run server and payload directories.

## Verification

- `make verify` includes offline publication tests: fixed identities/paths, isolated
  runs, failure preservation, running/concurrent rejection, signature/requirement
  mismatch, symlink containment and already-signed installer-host preservation.
- Build every affected native builder. Rebuild at least two representative kinds
  and compare the actual bundle IDs, launch paths and designated requirements;
  check their fixture roots and run IDs differ.
- Run the affected native checks at the stable paths. For the installer fixture,
  verify build 1 → build 2 at the stable path with separate launch PIDs, using the
  per-run loopback feed and event log.
- Computer Use's saved approvals are managed by Codex. Record whether repeated
  access reuses approval; fixed ID/path/signature alone is structural evidence.
  Initial approvals remain a user action. This workflow does not set app access
  policy, remove macOS permission prompts or prove installed Finder behavior.

## Access migration prototype

`bash scripts/build_access_migration_harness.sh` builds a Developer ID signed
sandboxed build 27 and non-sandboxed build 28 using a shared fixed QA identity.
The actual QA Finder extension stays sandboxed in both. Only this experiment
changes the host sandbox; production signing requirements remain unchanged.
Both builds use a per-run directory under `Library/Application Support/FileMintAccessQA`,
matching production's shared-storage layout without opening any production store.
The baseline writes synthetic current-format preferences, a custom template,
folder bookmarks and favorites. The new build checks byte preservation, decode,
bookmark resolution and actual access after a real local Sparkle replacement.

Launch only the published stable host. Grant Full Disk Access to that QA host
manually, quit and reopen, then record the user's declared state separately from
actual probe results. Never read TCC databases or infer the switch from a probe.
Use the app's explicit local probes before and after update. They create unique
owned test directories, exercise production creation and folder-access code, and
record error codes and folder-picker counts without paths or file contents.
Finder menu checks require the user to enable the separate QA extension. The
loopback update feed uses an ephemeral in-memory key; it never contacts production.

A NAS test needs a user-supplied mounted network folder. A local volume, a mock
or a permission-error fixture is not NAS evidence. The current user has no NAS
test target; retain this case as not run. This minimal prototype establishes
access/installer feasibility, not complete old production FileMint upgrade QA.

# Finder and native verification

Load only for Finder, folder access or native-window changes. See the
[verification matrix](../HARNESS.md) for completion requirements.

`FocusedCreationTests.repeatedMenuCreation` exercises five fresh menu actions
through single-use tickets and filesystem creation, including name increments
after older snapshots are evicted. The native LaunchServices callback/thread and
repeated visible Finder menus require the checks in `docs/FINDER_QA.md`.
Desktop coverage keeps a background container's destination even without
filesystem metadata, rejects missing targets and unconfigured folders, and
exercises a Desktop action through ticket consumption and file creation.
Folder-scope tests distinguish Finder observation ancestors from menu/write
scope, including removed folders and similarly named siblings. Startup tests
cover dynamic home locations, old default-folder migration, saved home removal
and retention of folder bookmarks and unrelated preferences.
`scripts/verify_bundle.sh` also verifies the main app's accessory-launch
`LSUIElement` setting in the built bundle. Native checks cover showing the Dock
icon only for the settings window's lifetime.

Use only the affected sections of [Finder QA](../../docs/FINDER_QA.md).
A Core test does not prove a visible menu, native authorization, Dock state or
a successful installation. Record the tested build, environment, scenario and
observed result; mark unavailable checks as not run.

For Open with App, `OpenWithTests` covers migration, malformed/duplicate entries,
menu partitioning, captured app/selection identity, scope and ticket replay/expiry.
`bash scripts/build_open_with_harness.sh` publishes a stable sandboxed QA app whose
production coordinator sends a real file/folder batch to a native receiver app.
It checks the received selection, source preservation, clipboard, busy guard and
single-use ticket. This does not prove installed Finder callbacks or compatibility
with every chosen application. See [Open with App QA](../../docs/FINDER_QA.md#open-with-app)
and [Native QA identity](native-qa.md) for stable paths and per-run fixtures.

`make verify-favorite-model` compiles the production favorite model against Core
and runs it with an isolated catalog. It covers asynchronous initial loading,
1,000 entries, concurrent edits, recent clearing, revoked add policy, damage
recovery and releasing the busy guard. It does not launch Finder or read real
favorite/settings files. Native UI checks also filter quick-search results from
several rows down to one, ensuring the displayed row and Return action use that
entry's stable ID; clearing history must empty Recent while preserving All.

For the optional template workflow, `bash scripts/build_template_workflow_harness.sh`
publishes a stable sandboxed fixture with production model, preview, panel and
executor code. Run the returned bundle's executable with
`FILEMINT_TEMPLATE_QA_MODE=screenshots` for bounded source/receiver/preview checks
and native view-cache renders. See the
[active task](../../docs/tasks/2026-10-05-template-workflow.md#implementation-evidence--2026-10-05)
for exact results and environment limitations. This does not replace live keyboard,
VoiceOver, actual editor rendering, working Office providers or installed Finder
acceptance. Run `bash scripts/run_creation_opening_checks.sh <bundle-path>` for
the focused post-creation checks. It temporarily registers only the disposable
receiver's unique file type and removes that app registration on exit. Explicit
applications receive text, Office and binary receipts, and a
fixture-specific macOS association exercises native default opening. Isolated
settings and tickets cover both opening actions through quick creation and the
native panel, collisions, temporary overrides, cancellation, errors and retries.
`FILEMINT_TEMPLATE_QA_MODE=opening-apps`, with exact `FILEMINT_QA_CODE_APP` and
`FILEMINT_QA_OFFICE_APP` paths, is an opt-in installed-editor check using temporary
JS/DOCX/XLSX files and a system-default TXT file. Preserve those samples for
visual inspection; callbacks alone do not prove editor rendering.

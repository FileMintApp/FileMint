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
`bash scripts/build_open_with_harness.sh` builds a disposable sandboxed app whose
production coordinator sends a real file/folder batch to a native receiver app.
It checks the received selection, source preservation, clipboard, busy guard and
single-use ticket. This does not prove installed Finder callbacks or compatibility
with every chosen application. See [Open with App QA](../../docs/FINDER_QA.md#open-with-app).

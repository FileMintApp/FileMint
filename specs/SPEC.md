# FileMint SPEC

## Product promise — 0.5

A small, native macOS utility that creates a file where the user is already working.
Fast Finder actions, a compact keyboard-friendly creation panel, and no account,
analytics, folder crawling, or clipboard monitoring. File creation works offline;
optional low-frequency update checks and user-requested downloads use the network.

## Load only the context needed

This index and the linked domain contracts form the current product SPEC.
Each product rule has one owning domain. Read this index, select by behavior and
affected paths, then open only those contracts. Links are discovery pointers,
not instructions to recursively read everything.

| Task / affected paths | Contract to load |
| --- | --- |
| Names, text, collisions, draft panel, creation URLs/tickets; `FilenamePolicy`, `TemplateRenderer`, `CustomFileDraft`, `FileCreationService`, `CreationRoute`, `QuickCreationTicket`, `SharedUI/CustomFileSavePanelController`, `PlainTextEditor` | [Creation](domains/creation.md) |
| Presets/custom types, order, restoration, template content; `FileTemplate`, type editing in `ContentView` / `PreferencesModel` | [Templates](domains/templates.md) |
| Finder menus, targets, folder scope/bookmarks, permission guidance, extension cleanup; `FinderSyncExtension/`, `SharedUI/FolderAccess`, `FolderScope`, `FileMenuAction` | [Finder and permissions](domains/finder-permissions.md) |
| Optional file/folder tools, selection snapshots, moves and clipboard actions; `FileTools`, `FileMove*`, `PendingFileMove`, tools in `FinderSync` / settings | [File tools](domains/file-tools.md) |
| Image conversion, compression, resize, icons, stitch, OCR; `ResourceTools*`, `FileMintImages` | [Resource tools](domains/resource-tools.md) |
| Launch, windows, login items, menu bar, language, persistent defaults; `FileMintApp`, `AppDelegate`, `SettingsWindowController`, `LoginItemService`, `LoginItemPolicy` | [Startup and preferences](domains/startup.md) |
| About, checks, download, quarantine, update scheduling; `AboutPane`, `UpdateModel`, `UpdateClient`, `AppUpdate`, `AutomaticUpdatePolicy`, `InstallerQuarantinePolicy`, update smoke scripts | [Updates](domains/updates.md) |
| Website, README, privacy/license copy, native appearance, icons; `website/`, `Resources/`, `generate_app_icon.swift`, site packages and `deploy-pages.yml` | [Presentation](domains/presentation.md) |
| Build, entitlements, packaging, signing, publication; `project.yml`, `Config/`, `CorePackage/Package.swift`, build/release scripts, `ci.yml`, `release.yml` | [Distribution](domains/distribution.md) |
| Agent context, test infrastructure or workflow; `AGENTS.md`, `specs/`, `Makefile`, `Harness*`, `FileMintHarness`, `verify_context.py`, `test_harness_cli.py` | [AI Playbook](../docs/AI_PLAYBOOK.md), then [HARNESS](HARNESS.md) for checks |

File names above are navigation hints, not a list of files to read in full.
`Preferences.swift`, `PreferencesModel.swift`, `Localization.swift`, `ContentView.swift`
and mixed test suites serve several domains: choose by the fields/functions or
assertions being changed. Persisted-default or migration changes also load startup;
folder authorization loads Finder; template filename/content semantics load creation.
Tests inherit the contract of the behavior they assert. Add a route for a new domain.
If no row fits, search the index and source first; do not silently skip a contract
or fall back to reading every document.

## Verification and deeper references

- Classify the current task before choosing checks: analysis/planning, documentation
  edits, or implementation. Discussing future code changes does not trigger a test
  baseline. Pure analysis needs no default test run; documentation-only work uses
  documentation checks. Run implementation checks after completing the relevant
  change, selected by actual changed behavior; pre-change tests are optional and
  need a concrete diagnostic purpose or explicit request.
- Before planning checks, read the short [verification matrix](HARNESS.md).
  Load its detailed Core, Finder or update checklist only when applicable.
- For cross-session work, use the [AI Playbook](../docs/AI_PLAYBOOK.md). Current
  task records link to contracts and evidence; they do not copy domain text.
- [Development](../docs/DEVELOPMENT.md) is for environment/build setup.
- [Roadmap](../docs/ROADMAP.md) describes future work, not current behavior.
- [Acceptance history](../docs/ACCEPTANCE.md) records past observations, not proof
  for the current checkout. Search only the relevant version/scenario when needed.

Keep this index small. Domain details, verification procedures and historical
evidence stay behind links. Workflow/framework integration must preserve this
loading boundary and must not duplicate the product SPEC.

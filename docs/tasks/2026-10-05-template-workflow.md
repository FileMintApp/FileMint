# Task: Template copying, preview, post-creation actions and template exchange

Status: in-progress (51e49db source QA and selected-app icon follow-up verified; remaining native acceptance below)
Planning status: complete; implementation authorized on 2026-10-05.
Next action: Complete the remaining native checks in the commit QA below: full keyboard/VoiceOver and appearance matrix, working Office providers, trusted VS Code, installed Finder and quit/update lifecycle. TextEdit content and the principal live copy/creation/import/export flows are now observed. Use the primary checkout; worktrees require an explicit user request.

## Objective and scope

- Let users copy an existing template, inspect the resulting file, continue in an application after creation, and transfer selected templates between Macs.
- The earlier turn authorized planning only. The 2026-10-05 implementation request authorizes this record's source work and isolated verification. The implementation is now in the primary checkout; installation and publication remain separate scopes.
- Include UTF-8 text templates, bundled and imported `.docx` / `.xlsx` templates, settings, the shared creation panel, and both creation-success paths.
- Preserve the existing clipboard-image/text creation paths when connecting post-creation actions.
- Exclude filename variables, project-folder templates, arbitrary binary formats, cloud synchronization, a rich-text/Office editor, commands, publication and installation.
- This is the active record for the earlier task's T2 and T4 plus template exchange. T1 is tracked in the [multiple-template task](2026-09-22-multiple-templates.md); T3 filename rules remain in the [earlier plan](2026-09-17-template-creation-workflow.md#t3--文件名规则).

## Selected context

- Contracts: [Templates](../../specs/domains/templates.md), [Creation](../../specs/domains/creation.md), [Startup and preferences](../../specs/domains/startup.md), [Open with App](../../specs/domains/open-with.md), and [Finder and permissions](../../specs/domains/finder-permissions.md).
- Workflow and checks: [AI Playbook](../AI_PLAYBOOK.md), [HARNESS](../../specs/HARNESS.md). Load detailed Core/native checklists only when implementing their surfaces.
- Main entry points: `App/FileMint/TypesPane.swift`, `PreferencesModel.swift`, `SettingsSections.swift`, `OpenWithApplicationAccess.swift`, and `SharedUI/CustomFileSavePanelController.swift`.
- Core entry points: `FileTemplate.swift`, `CustomFileDraft.swift`, `TemplateRenderer.swift`, `FilenamePolicy.swift`, `FileCreationService.swift`, `DocumentTemplateStore.swift`, `OfficeDocumentValidator.swift`, and `Preferences.swift` under `CorePackage/Sources/FileMintCore/`.
- Load Distribution before changing `project.yml` for framework/type registration, then run `make project`; load Presentation if editing public claims. Neither is needed to implement this planning record.
- Load [Updates](../../specs/domains/updates.md) if changing updater restart/installation logic instead of supplying its existing pending-work inputs. Do not change update scheduling or installation policy as a side effect.

### Ownership and source map

Names in the Proposed additions column describe planned components; they do not imply those files or APIs exist.

| Responsibility | Existing entry points | Proposed additions / boundary |
| --- | --- | --- |
| Template identity and copying | `FileTemplate.swift`, `TemplateCatalog.customTemplate`, `restoringBuiltIns`, `PreferencesModel.saveType` | Copy the complete template; `TemplateCreationAction` and decoding/migration |
| Gates and basic reveal behavior | `Preferences.swift`, `PreferencesModel.save`, `SettingsSections.swift` | Two default-off booleans; committed gate state and an in-memory opening-disable generation |
| Frozen creation content | `CustomFileDraft.swift`, `TemplateRenderer.swift`, `FileCreationService.swift`, `FilenamePolicy.swift` | `CreationContentResolver`, explicit render context, immutable submitted request |
| Template management | `App/FileMint/TypesPane.swift`, `PreferencesModel.swift` | Copy editor mode, gated preview/action fields, package selection/review sheets |
| Native creation window | `SharedUI/CustomFileSavePanelController.swift`, `App/FileMint/PlainTextEditor.swift` | Optional preview/action controls; preserve tab order, unsaved edits and the single panel |
| Native document preview | `DocumentTemplateStore.swift`, bundled resources | App-owned `TemplatePreviewController` / view adapter; no AppKit or Quick Look in Core |
| App identity and dispatch | `OpenWithApplicationAccess.swift`, `PreferencesModel.quickCreate`, shared-panel success branch | Separate creation-application registry and `PostCreationActionExecutor`; reuse helpers without Finder menu side effects |
| Package and merge rules | Private `OfficeZIP`, `OfficeDocumentValidator`, `DocumentTemplateStore` | `TemplatePackageCodec`, `TemplateImportPlanner`, bounded container parser and asset staging |
| Operation lifetime/recovery | `PreferencesModel`, `FileOperationCoordinator`, `AppDelegate`, existing termination/update guards | Serialized template operation coordinator and one bounded import journal |
| Verification | `MultipleTemplateTests`, `DocumentTemplateTests`, `BuiltInDocumentTemplateTests`, `FocusedCreationTests`, `StartupPreferencesTests`, `OpenWithTests` | Resolver/action/codec/planner/transaction tests and isolated native fixtures |

Before editing a shared file, load the domain for the specific behavior being changed. Do not expand Finder tickets, the public JSON Harness or the legacy whole-settings importer just to accommodate this feature.

## Planning baseline observed on 2026-10-05

Source revision: `64820a9`; the worktree was initially clean.

| Area | Existing behavior | Gap relevant to this request |
| --- | --- | --- |
| Template settings | Stable IDs, multiple same-suffix templates, ordering, icons, defaults, modal editing | No copy operation or common filename/content preview |
| Office templates | Validated private document copies and read-only bundled resources | No document-content preview or portable package |
| Text creation | Single-pass UTC content variables; edited drafts saved verbatim; collision handling in the writer | Panel holds source content, and creation samples time at execution; no shared frozen preview context |
| Successful creation | Separate `revealAfterCreation` branches in `PreferencesModel.quickCreate` and the shared panel | No common follow-up executor or open-failure state |
| Import | Legacy whole-settings import and individual Office import | Legacy import replaces preferences; it is unsuitable for template-only exchange |
| Opening apps | Validated app bookmarks and native `NSWorkspace` dispatch | Existing Finder selection-opening policy must not be assumed to provide safe automatic editing for all file types |

## Proposed interaction

### Optional features and a simple default flow

- User requested independent switches for Create and Open and Template Preview on the existing Creation Behavior page. Both default to off in the proposed design, including absent/invalid fields and migration, to keep the initial workflow simple.
- These are feature-availability switches, not a global choice of application/action. Once opening is enabled, individual templates still own their saved action and the current creation can override it.
- Opening off hides the template-list action summaries, the action/application fields in template editing, and the current-file action/application selector. The primary button remains Create. Do not leave disabled controls, empty gaps, setup prompts or repeated reminders on those surfaces.
- Opening off also prevents application-opening dispatch, including quick creation, clipboard/custom creation and stale/pending requests. Preserve the existing basic reveal/no-action behavior controlled by the legacy reveal preference; disabling the new feature must not silently launch a saved template's app or change the user's established Finder reveal preference.
- Keep the existing basic reveal checkbox and other creation settings. Its value supplies the fallback, not an additional second action after a template explicitly chooses Open, Reveal or Do nothing. Clarify that scope in help text when advanced opening is enabled.
- Retain per-template actions and selected-app references when the feature is off. Saving another template field, copying a template, restarting or importing/exporting a package must not clear these hidden values. Re-enabling restores them.
- Preview off hides the content-preview pane, Preview actions, editor preview column and new creation-result preview UI. Keep normal text-content editing and the concise Office-template notice available; this switch does not remove the existing clipboard-image confirmation preview.
- Do not instantiate Quick Look views, generate thumbnails or create temporary preview files while previews are disabled. Close/cancel active preview work when disabled, ignore stale callbacks and clean up only its owned temporary snapshots. Creation/import validation still runs when needed to perform those actions.
- Gates are independent: off/off is the simple workflow; open/on with preview/off exposes only opening controls; preview/on with open/off exposes only previews; on/on enables both. Preview visibility must never change rendered bytes, captured time, edit state or unsaved input.
- Keep the gates as local app preferences, excluded from template packages. Importing a package must never enable either feature. A failed preference save restores the previous switch state and behavior.

### Copy and preview

- Keep the current Templates & Types settings page and editor. Add Copy beside Edit; use a localized “Copy” suffix for the draft's display name.
- A copy is a draft until Save. Save assigns a new custom template identity, inserts it after its source, enables it, and preserves existing suffix defaults. Cancel writes nothing.
- Preserve suffix, default filename, content, icon, applicable grouping and the template's saved post-creation action/application choice. A copied built-in is an ordinary custom template and survives built-in restoration.
- Reuse immutable Office asset references for a local copy. No second large file is necessary merely to edit metadata; removal retains the asset while another saved template references it.
- With Template Preview enabled, the revised prototype uses the previously explored Selection Preview layout and a Preview action for a larger view. With it disabled, the list fills the available width and the editor has a single content column. The earlier alternative-layout carousel is superseded by real switches in Creation Behavior.
- Text preview shows exact resulting text, not rendered Markdown/HTML. The settings example identifies a fixed UTC date and filename. No target directory is inspected or reserved.
- Office preview is planned to use Apple's native Quick Look UI (`QLPreviewView` for embedded content, or `QLPreviewPanel` for a separate system panel). This is the Quick Look framework used for quick file inspection, not launching Preview.app. The current prototype's document page is simulated and calls neither native API. Actual rendering depends on the system/provider and requires sandbox/native acceptance. Missing/damaged assets show a useful error; missing preview support shows metadata and “Preview unavailable,” never a blank success state.
- Use verified private or bundled bytes for preview. If native rendering requires a temporary snapshot, keep a bounded, app-owned copy with an explicit lifetime; do not create a file in the user's destination or edit the template asset.

### Creation panel and follow-up actions

- User-confirmed model: each template in Templates & Types owns its post-creation choice. When Create and Open is enabled, add it to the existing template editor: Do nothing, Reveal in Finder, Open with default app, or Open with selected app. Display its concise list summary only while the feature is enabled. The global switch controls availability, not which action a template uses.
- Two templates with the same suffix can have different actions. For example, Meeting Notes may open with the default app, while Project README opens in VS Code. Store choices by template identity, never by suffix.
- Keep Finder quick creation immediate; when the opening feature is enabled it uses the exact selected template's saved action, otherwise the existing basic reveal/no-action preference. Do not add a compulsory extra dialog to quick creation.
- When opening is enabled, the shared panel initially selects Follow Template, with the resolved action/application visible. Users can override it for this creation only. Label the primary button Create or Create and Open according to the effective gated action. Creating/cancelling never saves a temporary choice back to the template.
- While Follow Template remains selected, switching templates updates the action and app. Once the user chooses an explicit temporary action/app, preserve that override across template switches; selecting Follow Template clears it. A newly opened panel starts by following its template again.
- With preview disabled, retain the straightforward editable content field. Its initial displayed value can use the same resolved text as the preview without marking the draft edited; the first actual edit makes it verbatim. With preview enabled, the prototype offers a read-only result and Edit Content. These presentations share the same underlying source, frozen context and edit-state rules. Switching visibility alone never materializes or changes content; actual edits are preserved across filename changes and compatible template switches. Pasting still requires an explicit user action.
- Preserve edited filenames on template switches. Retain the existing rejection of switching an edited text draft to an Office document and the separation of image drafts.
- On migration, retain the old `revealAfterCreation` preference as the basic behavior while opening is disabled, and use it to seed existing templates lacking a valid action: true → Reveal, false → Do nothing. Preserve already-valid per-template fields, disabled templates and removed-built-in state. Newly authored templates also start from the current basic preference (Reveal on a fresh installation); copying preserves the source choice. Old settings imports use the same decoder. Default missing/invalid feature gates to off and do not opt existing users into opening apps.
- Requests without a template (for example clipboard images or an unsaved custom suffix) use an explicit request fallback and the same temporary selector; they never guess an unrelated same-suffix template's action. Preserve their old reveal/no-action behavior for migrated users; new installations start with Reveal. The fallback is not an editable global override over templates.
- Reuse app capture/resolve/validation helpers and a local registry of validated application references. Each template's selected-app action references that registry; Finder menu exposure remains independent. Selecting an app for a template must not add an Open with App menu entry or change system associations. Saving template edits and application references is atomic; Cancel persists neither.
- Opening failures have an already-saved-file state: Reveal, choose another app, or retry opening. The retry contains the saved URL and cannot call the writer again.
- Script/unknown/executable-like types require an explicitly supported editing route. Resolve the actual handler and use a positive policy for supported type/application combinations; an extension blacklist or `NSWorkspace.open` alone is not a guarantee of editing. Start with narrow, natively verified editor profiles (TextEdit and VS Code are prototype examples, not currently verified support). If the safe route is unavailable, keep the saved file and ask for an editor instead of falling back to default dispatch.

### Template export and import

- Keep New Text Template and individual Office import. Add Import Template Package and Export on the same settings page; distinguish these from legacy settings import in the File menu.
- Export offers Selected, Enabled, All, and custom selection, followed by a native save panel. Zero selections cannot be exported.
- Include names, explicit suffixes, default filenames, exact text or document bytes, grouping, icons, enabled state, relative order, relevant suffix defaults and each template's post-creation choice.
- Selected-app choices contain only portable app identity hints (bundle identifier and display name). Exclude folder bookmarks, source paths, app paths/bookmarks, local application registry IDs, login/updater state and unrelated preferences. Text/document content is intentionally included; Office package metadata remains exact bytes rather than being silently stripped.
- The import review always shows new/identical/conflicting records and confirmation, independently of the Template Preview switch: it is required merge review, not a file-content preview. Show portable opening-action details when Create and Open is enabled; otherwise retain that metadata without activating or exposing opening controls. Reuse only a matching, already user-selected and validated local app reference. Otherwise retain an unresolved app choice for explicit local selection once the opening feature is enabled. Never crawl installed apps, launch anything on import, or fall back silently. The usual identity and safe-opening policy applies before dispatch.
- Import first validates the selected package, then presents each item and the resulting counts. Default choices: new item → Add; identical item → Skip; changed identity/name conflict → Save as copy. Each conflict can also be skipped. The first version has no destructive replace option.
- IDs are identity hints, never permission to overwrite. Compare canonical portable fields and document digests, not display names alone. Same suffix by itself is not a conflict.
- Reuse an incoming custom ID only if it is valid, unique and unused. Remap copies, reserved built-in IDs and conflicting references to fresh custom IDs. Do not resurrect built-ins through their reserved identity or clear removed-built-in markers.
- For a destination with no templates of an imported suffix, restore the exported default after ID remapping. For a merge, preserve existing items/order/defaults and append accepted items in package order. An unchecked-by-default Adopt package defaults option may fill only suffixes with no valid explicit default. If this changes an existing implicit fallback, the review must show the old and new effective template; valid explicit defaults always win. Skipping every item also skips all default changes.
- Missing/unselected/disabled default targets are omitted or rejected as appropriate and explained in the preview; never leave dangling references.
- Reimporting identical templates skips them. A deliberately renamed copy remains a separate template; do not promise synchronization or hidden provenance-based updates.
- Cancel leaves saved templates and managed assets unchanged. Invalid versions, missing assets or failed validation never partially import.

## Implementation design

### Shared creation resolution

Introduce a small deterministic resolver, reusing `FilenamePolicy` and `TemplateRenderer`, rather than new renderers in the settings view, creation panel and writer.

- Inputs: selected template, requested filename, content mode and explicit `TemplateContext`/captured time.
- Output: normalized request filename, text bytes or validated document reference, and validation errors. The preview never calls the writer.
- Capture one time per draft; reuse it across preview, permission retry and creation. Quick creation captures once when executed. Do not resample on each collision attempt.
- The writer still arbitrates collisions with exclusive creation. Preview describes the requested filename, not a guarantee that this name is free. If incrementing changes the name, render template-mode `{{fileName}}` from the actual candidate using the same time. Edited verbatim text stays literal.
- Preserve existing replacement confirmation for text drafts and increment/fail policies for other routes. No preview side effect may weaken those rules.

### Post-creation execution

- Add independent `creationOpeningEnabled` and `templatePreviewEnabled` preferences with defensive false defaults and atomic save/rollback. Do not store gates on individual templates or in the exchange DTO.
- Put per-template enum decoding/migration and action resolution in Core. If opening is disabled, resolve only the existing basic reveal/no-action behavior. If enabled, use `temporary override ?? selected template action ?? untemplated request fallback`, retaining provenance so template switches can distinguish Follow Template from an explicit override. Keep app access, dispatch and error presentation in App/SharedUI.
- Route both success branches through one native executor accepting `FileCreationResult`, a snapshot of the chosen template/action/application and the necessary access lifetime. Later template edits cannot change an already-submitted creation. Recheck the opening gate immediately before an application dispatch or retry: disabling the feature suppresses an unissued launch, without claiming to undo an application already opened.
- Hold security-scoped access and the pending-operation guard through the asynchronous completion. Preserve Finder request tickets, captured destinations and settings-window isolation.
- Revalidate saved app identity and the created item before dispatch/retry; never substitute a later Finder selection, missing app, executable handler or changed file silently.
- Use an explicit creation-success/follow-up-failure result rather than parsing localized error messages. A native open callback confirms handoff, not that an editor visibly rendered the file.
- Apple documents an embeddable [QLPreviewView](https://developer.apple.com/documentation/quicklookui/qlpreviewview) and application-specific [NSWorkspace opening](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:)). Their suitability for FileMint's sandbox, asset lifetime and safe editing needs a focused native spike; documentation alone is not runtime evidence.

### Local data contract and migration

The symbols below are implementation targets, not an existing public API.

| Data | Planned shape | Lifetime / serialization |
| --- | --- | --- |
| Feature gates | `creationOpeningEnabled: Bool`, `templatePreviewEnabled: Bool` | Local preferences; absent, invalid or unknown representations decode as false; excluded from template packages |
| Basic fallback | Existing `revealAfterCreation: Bool` | Retain its value and existing setting; used when opening is unavailable or the request has no template/override |
| Template action | `TemplateCreationAction`: `none`, `revealInFinder`, `openWithDefaultApp`, `openWithApplication` | Stored with the exact template ID; no `followTemplate` value in a saved template |
| Application choice | Validated local application ID plus portable name/bundle-ID hint, or an explicitly unresolved hint | Local reference may contain a bookmark/URL; portable representation never does |
| Creation app registry | Stable UUID → validated name, bundle ID, URL and read-only bookmark | Separate from `OpenWithPreferences.applications`; no placement or terminal mode; saved atomically with template edits |
| Draft action | `followTemplate` or an explicit one-request action/application | In memory only; new panels start at `followTemplate`; explicit choice is sticky through template changes |
| Render context | Captured UTC date, source template snapshot, requested filename and content mode | One context per draft/request; not stored in templates or recalculated on every preview |
| Submission | Resolved request, selected template ID, action snapshot, gate state/generation and basic fallback | Immutable once Create accepts the request |
| Created-file receipt | Actual created URL plus available file identity metadata and submission ID | In memory for native handoff/retry; never a caller-supplied path or new creation request |
| Import commit marker | `lastTemplateImportTransactionID: UUID?` | Set with the template import's atomic preferences commit; not exported; used only for journal recovery |

Migration requirements:

1. Decode legacy reveal behavior before materializing missing template actions. The current preferences decoder reads templates before `revealAfterCreation`; change this ordering or perform a second normalization pass after both are available.
2. Tolerate a missing/malformed new action within that template's decoder. It must not make the entire `[FileTemplate]` decode fail and fall back to built-ins. Preserve all unrelated template fields and valid neighbors.
3. Unknown action kinds use the basic no-open fallback. A recognized selected-app action with a missing/damaged app reference remains visibly unresolved when enabled; never reinterpret it as Open with default app.
4. Preserve already-valid gate values on normal relaunch. Missing/invalid gates default off. Legacy whole-settings imports go through the same decoder; template-package imports cannot read or write either gate.
5. Preserve removed built-in markers, custom IDs, icons, groups, rank, enabled state, suffix defaults, folder authorization and unrelated preferences. Newly appended built-ins retain the existing disabled-on-upgrade behavior.
6. Explicit built-in restoration resets those built-ins' actions to the current basic behavior, preserves custom copies and their actions, and does not change either gate. It uses the existing restoration confirmation.
7. Edit/save must round-trip hidden action/app fields. `TemplateCatalog.customTemplate` currently reconstructs a template: explicitly carry new fields through that path, document copies, reordering, migration and restoration.
8. Do not open apps, generate previews or perform app discovery during decoding, migration or import. Invalid/corrupt whole preferences retain the existing recovery behavior; this task cannot silently replace them.

### Gate and draft transition rules

| Opening | Preview | Templates & editor | Creation panel | Side effects |
| --- | --- | --- | --- | --- |
| Off | Off | Existing list/editor plus Copy and exchange actions; no action summary or preview controls | Editable text or Office notice; Create | Existing reveal/no-action only; no new preview preparation |
| On | Off | Per-template opening fields and summary | Current-file action selector; editable content | Exactly the resolved action after successful write |
| Off | On | Selected-content preview and Preview entry | Preview/edit presentation; Create | Preview work only; no app-opening dispatch |
| On | On | Both optional surfaces | Preview plus current-file action selector | Each feature obeys its own lifecycle |

- A successful opening-disable transition advances an in-memory generation. An accepted request records the current generation and whether opening was enabled. Dispatch requires its original permission, a still-enabled gate and a matching generation. Turning off and back on cannot resurrect an earlier suppressed launch; turning on during an off-originated write cannot add an unexpected launch.
- A failed gate save restores the prior visible value and must not advance the generation or discard work. Use committed settings for dispatch decisions.
- Disabling opening while a panel is open hides its controls and makes submission use the basic fallback. Preserve its temporary choice in memory in case the user re-enables before submitting. Closing the panel still discards the temporary choice.
- A preview task has a request token for the template/asset/context it is rendering. Disable, selection change and window close invalidate it. A late callback cannot reinsert a preview, overwrite a new selection or retain a stale temporary file.
- Gate changes never clear an edited name/body, change `hasEditedContent`, discard clipboard-image bytes, reserve a filename or resample the draft's timestamp. Hide/remove controls from keyboard traversal and move focus to a remaining field when necessary.
- Use `FilenamePolicy` and the same content resolver for both displays and writes. Before editing, renaming the file updates template-mode content; after an actual body edit, its bytes stay verbatim, including tokens, whitespace, Unicode and newlines.

### Copy operation and native boundaries

- Represent editor mode explicitly as New, Edit(existing ID) or Copy(source ID). Do not represent a document copy as an ordinary new text template: `saveType` currently recovers a document only by its existing ID.
- Copy creates an in-memory candidate with a fresh custom ID and localized Copy suffix. Source ID is only an insertion hint, not permission to edit the source. If the source disappears before Save, preserve the copy draft and append after revalidating references; do not resurrect or overwrite the source. If its Office asset is no longer available, retain the draft and show re-import guidance rather than publishing a broken copy or treating it as text.
- Save inserts after a still-existing source and normalizes ranks with existing helpers. Explicit defaults are untouched. If copying an earlier disabled source would otherwise change an existing implicit default, pin that previous effective default; an enabled copy still sits after its source. If persistence fails, keep the editor open with an error and restore the old preferences.
- A local Office copy shares an immutable validated reference. There is no asset write on opening/canceling the copy editor. Delete the asset only after the last saved reference is removed successfully; built-in resources are never deleted.
- The native post-creation executor belongs to the main app. The shared panel passes the successful receipt through an injected completion interface instead of depending on `PreferencesModel` or launching an application itself. Finder continues to send only its existing single-use requests.
- Close a successfully written draft before presenting an opening error, but keep the pending-operation/access guard until the native handoff completes. App quit/update checks must still see that work after `hasActiveWrite` becomes false.
- Before opening or retrying, verify the actual created item still exists with the expected identity/type. A removed, moved or replaced item is not a reason to recreate it or open whatever now occupies its path. Revalidate the selected app bookmark and bundle identity; do not substitute a different registered copy.
- Resolve a default handler before deciding it is a permitted route. Scripts, executable-like files and unrecognized active-content types require a natively verified editing profile. A suffix blacklist, an app's display name or the existence of `NSWorkspace.open` is insufficient. P0 records supported profiles and unresolved platform limits.
- No shell, AppleScript, simulated keystrokes, association changes, application crawling, clipboard side effects or path/content logging belongs to this flow.

### Preview implementation and lifecycle

- Text preview is a read-only native text view of the actual resolved UTF-8 result. Do not load HTML into a web view, execute JavaScript or add a Markdown-rendering dependency. Unknown content tokens retain the current renderer's literal behavior.
- List/editor examples use an explicitly labelled fixed example context. A creation preview uses that draft's captured context. Neither scans the destination to promise an available collision name.
- Office preview reads only the selected validated managed/bundled asset on a worker. Prefer an app-owned, read-only snapshot when supplying a URL to Quick Look, so a system preview affordance can never modify the template asset. At most one active Office snapshot belongs to each active preview surface.
- Keep native view updates on the main actor and release the preview item before removing its owned snapshot. Close, cancel, gate disable and replacement all share cleanup. Do not clear another window's preview or enumerate user/template folders.
- Show loading, available, unavailable-provider and invalid-asset states distinctly. A provider failure can fall back to format/name/size and Preview unavailable; a damaged asset still prevents creation/export through the normal validator.
- P0 must establish read-only behavior, offline operation, no unsolicited application launch, minimum supported macOS behavior and cleanup for the chosen Quick Look integration. If those cannot be satisfied, record the limitation rather than silently substituting a custom Office renderer or claiming native preview complete.

### Portable package and transaction

Version 1 format: `.filemint-templates`, a ZIP container containing `manifest.json` and payloads under generated, digest-based names. The outer archive uses stored entries only; Office payloads retain their existing internal ZIP format. Text payloads are separate exact UTF-8 bytes so the metadata limit does not accidentally become the content limit. This is the planned format contract to put in SPEC before implementation.

- Manifest: `format`, `schemaVersion: 1`, template entries with an explicit text/document discriminator and portable post-creation action, asset descriptors (kind, length, SHA-256), relative order, and default references. This is a dedicated DTO, never `Preferences` serialization. Selected-app hints are not authority to launch an application.
- Include validated Office bytes even for bundled templates, so packages remain usable across app versions. Import them as managed assets rather than trusting a foreign bundled-resource reference.
- Planned limits: 100 templates, 100 unique payloads of which at most 64 are Office documents, 4 MiB manifest, 8 MiB aggregate text, and 128 MiB encoded package/aggregate outer payload. Preserve current per-document 64 MiB encoded, 4,096 entries, 64 MiB per expanded entry and 128 MiB expanded-total limits. Additionally cap combined Office inner expansion across the package at 256 MiB and validate one document at a time. Check that the resulting preferences fit the existing 32 MiB cap before commit. Explain the exceeded limit and suggest a smaller selection; never silently omit items.
- Enforce the limits before allocation/decompression. Reject duplicate JSON keys and archive entry names, unsupported versions/compression, encryption, links, absolute/traversing paths, unreferenced payloads, invalid lengths/digests and invalid Office packages. Archive names are identifiers to validate, not filesystem paths to extract.
- The current ZIP reader is private to `OfficeDocumentValidator`; it is not an existing general export library. Assess a bounded shared container parser/store-only writer separately and retain Office regression coverage. No package dependency is currently proposed; any dependency would need a SPEC rationale.
- Validate on a worker under the selected-file grant. Snapshot the package for the preview, and prevent a changed input from being used at commit.
- Confirm against the current saved-preferences revision. Recompute and show conflicts if preferences changed while the sheet was open.
- Stage accepted document assets with fresh private IDs; atomically commit one new preference snapshot, then notify Finder once. If saving fails, remove only assets created by this transaction and leave previous preferences/assets intact.
- Serialize template mutations/imports with quit/updater guards. A bounded transaction journal names only assets created by the transaction; startup recovery reconciles those exact IDs with committed preferences. Do not enumerate the template directory to clean presumed orphans.
- Export validates all selected assets, creates the complete container away from the UI thread, then atomically saves via the native save-panel grant. Missing assets prevent a silently incomplete “successful” package.

### Version 1 schema and byte rules

The metadata keys are `format`, `schemaVersion`, `templates`, `payloads` and `defaultTemplateIDs`. Array order is the relative template order; do not export machine-dependent ranks or private asset UUIDs. `format` must equal `filemint.templates`, and `schemaVersion` must equal `1`.

Example metadata for a single empty text template (the matching zero-byte payload entry is still required):

```json
{
  "format": "filemint.templates",
  "schemaVersion": 1,
  "templates": [{
    "id": "custom-demo",
    "displayName": "Notes",
    "fileExtension": "txt",
    "suggestedFileName": "Notes.txt",
    "group": "Custom",
    "isEnabled": true,
    "customMenuIcon": null,
    "payloadID": "text-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "afterCreation": { "kind": "revealInFinder" }
  }],
  "payloads": [{
    "id": "text-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "kind": "utf8Text",
    "path": "payloads/text-e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.txt",
    "byteCount": 0,
    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  }],
  "defaultTemplateIDs": { "txt": "custom-demo" }
}
```

- Payload kinds are `utf8Text`, `docx` and `xlsx`. The descriptor path is exactly `payloads/<kind-prefix>-<sha256>.<txt|docx|xlsx>`; derive it from validated fields and require an exact match. No directory entries, source names, symlinks or arbitrary archive paths are needed.
- Deduplicate by kind, digest and byte count. Verify the bytes, not just matching descriptor values. Empty text is allowed; Office documents must be nonempty and pass their existing validator.
- UTF-8 payload import/export preserves exact text bytes, including CRLF, leading BOM when present, whitespace, Unicode and literal variables. Reject invalid UTF-8 rather than substituting replacement characters. Templates use the existing name/suffix/icon validation; do not add different filename-normalization rules in the package UI.
- A selected-app action uses `{"kind":"openWithApplication","application":{"bundleIdentifier":"com.microsoft.VSCode","displayName":"Visual Studio Code"}}`. Other kinds carry no application object. An imported bundle ID is a hint, not a local grant or launch authority.
- Validate duplicate/unknown keys, required fields, enum values, integer bounds, unique template/payload IDs, exact references, SHA-256 syntax, default suffix/ID consistency and mutually exclusive text/document shape. Reject unsupported versions as a whole. Known but locally unsupported symbols may use the current icon fallback while preserving their stored values.
- Reject encrypted, split, ZIP64, deflated outer entries, unsupported flags, duplicate names, overlapping/out-of-range entry ranges, central/local-header mismatches, bad CRC, traversal, absolute paths, links, unexpected entries and undeclared payload bytes. Use checked integer arithmetic before slicing or allocating.
- Limits are checked from the regular-file descriptor, archive metadata, declared sizes and actual bytes. Reject placeholders and symlinks; hold only the chosen input/save-panel grants. The archive is parsed by entry ranges, never handed to a generic extractor or shell utility.
- The manifest is metadata only; no bookmarks, local app/asset registry IDs, gate preferences, destination paths, update state or recovery journal fields are accepted. A package including those fields fails schema validation instead of affecting local settings.

### Deterministic import plan

Compute the plan without mutating preferences or the managed asset store. Keep the validated input snapshot and its digest until confirmation so a changed source cannot replace reviewed bytes.

| Incoming item | Default decision | Allowed user alternative |
| --- | --- | --- |
| Same ID and identical portable payload/metadata | Skip | Save an explicitly requested independent copy |
| Same ID, different payload or metadata | Save as copy | Skip |
| Different ID, identical portable payload/metadata | Skip exact equivalent | Save an independent copy |
| Same normalized name and suffix, different payload/metadata | Save as copy with localized suffix | Skip |
| Same suffix but a distinct name/template | Add | Skip |
| Reserved built-in ID, no identical local template | Add as custom with remapped ID | Skip |
| Invalid or unsupported package content | Reject package before review | Select another file |

- Compare display name, canonical suffix/default filename, grouping, icon, enabled state, content digest/kind and portable action/app hint. Exclude local IDs, absolute rank and default references from equivalence; defaults are resolved separately. Different intentional names are not duplicates merely because content matches.
- For name-conflict detection use Unicode canonical equivalence and case folding, but preserve saved spelling; exact-template equivalence still compares stored display-name/content strings exactly. Generate Copy / Copy 2 names against both existing and already-accepted items. Do not use a file suffix or display name as durable identity.
- Keep incoming non-reserved custom IDs only when unused. Assign fresh IDs to copied/conflicting/reserved records. Build one incoming-to-result-ID map and use it for defaults; an identical skipped item can map to its retained local equivalent.
- Preserve existing relative order and insert accepted templates at the end in package order. Normalize ranks without reordering existing entries or overflowing integers.
- Preserve explicit local defaults. With adoption disabled, preserve the effective implicit default for existing suffixes too. With adoption enabled, show every effective change before commit. A default whose target was skipped without an equivalent cannot be imported; explain it in the review.
- The review includes counts, per-item actions and a details area. It is always required, even with content preview disabled. Content previews and action editors respect the two feature gates; invalid/unresolved app metadata remains inert.
- Re-check the relevant preferences revision immediately before commit. If it changed, rebuild the plan and require review of the changed result; preserve compatible item selections. Do not overwrite concurrent template edits with a stale whole-preferences snapshot.
- Re-importing an unchanged equivalent template skips it. A deliberately renamed copy remains a separate template; this feature does not infer ongoing synchronization or hidden provenance updates.

### Atomic commit, interruption and recovery

Use a single serialized template-mutation boundary for template edit/copy/remove/default/reorder, Office import, package import and legacy settings replacement. Long validation runs on workers; the main actor does not hold a lock while awaiting I/O. Other operations may read committed settings, but cannot interleave another template mutation inside a package commit.

| Phase | Persistent changes allowed | Cancel / failure behavior |
| --- | --- | --- |
| Pick and validate | None outside an owned bounded snapshot | Cancel releases grants/snapshot; previous configuration and assets remain unchanged |
| Review | None | Cancel discards the plan; updater treats the active review as modal work |
| Prepare commit | Atomically write one journal containing generated asset IDs/descriptors and transaction ID | If journal write fails, publish no managed assets |
| Publish assets | Exclusive creation at the journal's fresh generated paths; set private permissions | Failure rolls back only assets known to this transaction |
| Commit preferences | One atomic save of merged templates, app mapping, defaults and transaction marker | Failure retains previous preferences and performs owned-asset rollback |
| Finish | Post one preference notification; remove only the completed journal/snapshot | A cleanup error is reported as cleanup pending, not an invitation to re-import or re-create committed templates |

- Write the bounded journal before publishing any asset, using a fixed app-owned journal file and generated basename-only IDs. Include a schema version, transaction UUID, expected asset kind/size/digest and expected candidate-configuration digest. Cap the journal at 1 MiB and the package's payload count. Never accept arbitrary paths from it.
- The preferences commit marker establishes whether the transaction committed even if the process stops before journal cleanup. The journal alone is not proof of a commit.
- Recovery reads only that journal, committed preferences and its exact listed assets. Keep anything referenced by valid committed preferences. Remove an unreferenced asset only when its ownership/type/identity checks succeed; never follow links, remove a replacement file or scan for presumed orphans.
- If preferences or the journal cannot be read/validated, preserve both and report recovery needed. Block a new template import/mutation until recovery is resolved; do not overwrite the journal, guess that assets are unused or broaden Finder scope.
- After a committed import, later cleanup failure must not roll back user-visible configuration. Retry cleanup against the same receipt. After an uncommitted import, retry begins from fresh validation/review after rollback, not by reusing a stale candidate configuration.
- Increment the existing pending-work accounting across validation/staging/commit and post-creation dispatch; use cancellation for read-only preview work. Wire ordinary quit and updater checks to actual active work, including work after a creation panel closes. Release every guard/grant exactly once on all exits.
- Export creates a complete bounded archive before publishing at the save-panel URL. Existing export targets require the normal native overwrite confirmation; use an atomic destination replacement under its grant. Cancellation or write failure preserves the previous destination bytes and deletes only the owned temporary export.

### Failure and recovery UI

| Condition | User-visible result | Permitted next step |
| --- | --- | --- |
| Template save fails | Editor remains open with the original draft and save error | Retry save or cancel; prior saved template remains authoritative |
| Preview provider unavailable | Preview unavailable plus file metadata | Continue editing/creating if asset validation succeeded |
| Missing/damaged Office asset | Restore bundled template or re-import guidance | No output from creation/export using that asset |
| Creation fails or authorization is canceled | Keep the unsaved draft and existing destination rules | Retry Create after explicit authorization; no app dispatch |
| File saved, opening fails | “File saved, but could not open” | Reveal, choose app, retry opening, or dismiss; never call the writer again |
| File replaced/missing before open retry | Saved item is no longer available | Dismiss or locate via an explicit separate user action; do not recreate or follow a replacement |
| Unknown/corrupt/oversized package | Specific validation/limit error before import | Choose another package or export a smaller selection |
| Merge result became stale | Updated review showing the new conflicts/default effects | Confirm revised result or cancel |
| Asset staging / preference commit fails | Import not applied; original templates retained | Retry only after bounded rollback/recovery succeeds |
| Post-commit cleanup fails | Imported templates retained; cleanup pending | Retry owned cleanup; no duplicate import |

Use structured error stages and localized text keys. Do not infer state by parsing English/Chinese error strings. Status and diagnostics must not log template contents, private paths or bookmark bytes.

## Implementation checklist and dependencies

Execute P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7. P3/P4 consume the same P1 models; P5 must use the settled action/asset representation. Finish a coherent phase and its applicable checks before broadening scope. Checked items now have source/automated evidence; unchecked items need the native evidence identified below.

### P0 — Contracts and native feasibility

Dependencies: none. Owners: the five selected domains; Distribution only if build/type registration changes.

- [x] Write the gate matrix, per-template/current-request action rules, copy semantics, render context, exchange format/limits and migration rules into their owning domain SPEC before implementing them. Keep this task as the progress/evidence record rather than a second product contract.
- [ ] Resolve the chosen Quick Look view/panel integration in an isolated fixture using only synthetic `.docx` / `.xlsx` assets. Record provider availability, read-only/offline behavior, grant lifetime, cleanup and macOS versions actually tested.
- [ ] Verify the intended default-app and selected-editor routes with a disposable receiver and actual supported editors. Record exact supported bundle identities and type rules; do not infer safe editing from method availability.
- [x] Define the fallback and release limitation for any unavailable native capability. No custom Office renderer, generic command runner or hidden dependency is an acceptable workaround.
- [x] Finalize localization keys and the small feature-switch copy. Preserve the user's labels: 创建行为, 创建后打开, 模板预览. Use distinct labels for a suffix's default template and a file's default application.

Exit: updated contracts and recorded feasibility decisions; no unresolved ambiguity about which types/apps may dispatch. A native blocker remains an explicit unfinished item, not a presumed pass.

### P1 — Core models, migration and shared resolution

Dependencies: P0. Primary paths: `Preferences.swift`, `FileTemplate.swift`, `CustomFileDraft.swift`, `TemplateRenderer.swift`, `FileCreationService.swift`, new focused Core types/tests.

- [x] Add the gates, saved action, local app-reference model and import marker without losing existing preferences.
- [x] Implement tolerant per-field migration and parent normalization after the basic reveal value is known. Preserve valid neighboring templates and unavailable Office references.
- [x] Implement action resolution with explicit Follow Template provenance, immutable submission context and opening-disable generation handling.
- [x] Extract the smallest shared pure content resolver and pass one captured date into preview and actual creation; keep collision arbitration in the writer.
- [x] Implement copy-as-new identity, insertion/rank normalization and complete-field preservation, including disabled-source copying, hidden action fields and immutable Office references.
- [x] Cover migration, content equality, copying, action resolution and fault cases in focused Swift tests using independent expected bytes.

Exit: Core rules cover the four gate combinations, template identity, migration and byte-equivalent rendering. No native application or UI dependency enters Core.

### P2 — Settings, copy editor and simple creation UI

Dependencies: P1. Primary paths: `TypesPane.swift`, `SettingsSections.swift`, `PreferencesModel.swift`, `CustomFileSavePanelController.swift`, `Localization.swift`.

- [x] Add both persistent default-off switches under Creation Behavior. Keep basic settings and their behavior; failed saves roll the switch back visibly.
- [x] Add Copy to the existing template management controls and editor modes. Save is atomic; Cancel never publishes a template or new app reference.
- [x] Show action summaries/editor fields only with opening enabled. Save hidden values unchanged, including through regular `saveType` edits.
- [x] Add the current-file selector only when opening is enabled. Follow Template reacts to template selection; explicit temporary choices remain sticky until reset/cancel/finish.
- [x] Keep the normal content editor usable with preview off. Add the optional preview presentation without changing edit-state or output semantics.
- [x] Recalculate explicit Tab/Shift-Tab traversal when controls appear/disappear; retain Return, Command-Return, Escape, editor undo/plain paste and draft-locking rules.
- [ ] Verify all four gate combinations, including compact/minimum windows, Chinese/English, light/dark and Reduce Motion.

Exit: a default-off installation retains the simple existing flow; optional controls occupy space only when enabled. Copy/save/cancel does not alter unrelated templates.

### P3 — Native preview lifecycle

Dependencies: P0–P2. Primary paths: app-owned preview controller/view, `DocumentTemplateStore`, template editor and shared-panel integration.

- [x] Connect exact text output to a read-only native preview; no browser rendering or second token engine.
- [x] Load the selected Office asset in a bounded worker, validate it and provide only a controlled snapshot to the approved native preview integration.
- [x] Implement loading/success/provider-unavailable/invalid-asset states and selection tokens; release native items before removing owned snapshots.
- [x] Cancel and suppress stale results on gate disable, selection change and close. Assert no native preview instance or snapshot is created while off.
- [ ] Run the native fixture against valid, absent, damaged and unsupported-provider cases and record cleanup evidence.

Exit: opening/closing/changing previews cannot write user files, alter templates, keep stale content visible or change a draft's bytes.

### P4 — Post-creation native execution

Dependencies: P0–P2. Primary paths: app-owned executor/registry, `OpenWithApplicationAccess`, both creation-success paths, work/termination guard integration.

- [x] Capture/validate chosen applications through native selection and reuse identity checks while keeping the creation registry separate from Finder app entries.
- [x] Inject the app completion executor into the shared panel and route quick creation through the same executor. Use only the actual successful result URL.
- [x] Snapshot action/app choices at submission and recheck committed gate generation, created-file identity and app validity before dispatch.
- [x] Extend pending-work and authorization lifetimes through completion, including after the panel closes; perform callbacks on the appropriate actor without inheriting a main-actor assumption on native completion queues.
- [x] Implement saved-but-open-failed UI and receipt-based retry. Re-selecting an app for a retry is temporary unless the user later edits/saves a template separately.
- [ ] Cover default handlers, explicit editors, rejected execution routes, app/file disappearance, disabled/re-enabled gates and duplicate completion attempts with injected dispatch tests; verify actual native handoff and visible editor behavior separately.

Exit: off means no launch; write failure means no action; a successful write triggers at most one resolved action; retry never creates a second file.

### P5 — Package codec and merge planner

Dependencies: P1 and P0's settled format/action rules. Primary paths: new Core codec/planner tests, bounded ZIP support and existing Office validation.

- [x] Implement the dedicated version-1 manifest and stored-entry container writer/reader with exact payload/digest rules and all declared bounds.
- [x] Export text and Office bytes, including bundled Office assets, without local preferences, grants or private identifiers.
- [x] Implement deterministic equivalence, Add/Skip/Copy decisions, ID remapping, copy naming, rank normalization, default adoption and unresolved application hints.
- [x] Validate the entire package before returning a reviewable plan. Bind the plan to the validated input and relevant committed-preferences revision.
- [x] Add round-trip, malformed-input, limit, corruption, collision and default-reference fixtures. Preserve existing Office tests if its private ZIP logic is generalized.

Exit: no invalid package can reach a commit-ready plan, and a valid plan predicts all resulting templates/defaults without filesystem mutation.

### P6 — Import/export workflow and recovery

Dependencies: P2, P4's registry representation and P5. Primary paths: `PreferencesModel`, native picker/review sheets, `DocumentTemplateStore`, operation coordinator, startup recovery.

- [x] Add selected/enabled/all/custom export scopes and a native save panel. Complete/validate the package before atomic publication; respect destination overwrite confirmation.
- [x] Add template-package import separately from individual Office and legacy settings imports. Show counts, per-item results and default changes before confirmation.
- [x] Show content preview/action details only when their gates permit them, while always retaining required validation/conflict review.
- [x] Implement serialized revision-check/staging/journal/preferences-commit/notification/cleanup phases with explicit cancellation points and rollback ownership.
- [x] Restore managed assets using fresh private references, preserve exact document bytes and save an unresolved app hint when no trusted local application matches.
- [x] Recover each interrupted phase from the bounded journal and committed marker; preserve corrupt/ambiguous evidence and never scan for or delete unknown assets.
- [ ] Inject failures before/after each mutation, restart a fresh coordinator against journal fixtures and verify prior files, preferences and grants remain intact.

Exit: cancel/validation/staging/save failures do not partially apply an import; interruption recovery never deletes a referenced asset or repeats a committed import.

### P7 — Integration acceptance and handoff

Dependencies: P0–P6.

- [x] Run the implementation checks required by HARNESS and the acceptance matrix below; record revision, command, environment and outcome for each evidence category.
- [ ] Verify Finder quick creation and the persistent panel with the exact selected template, captured destination and cold/warm URL-launch paths. Settings must stay closed during Finder creation.
- [ ] Verify clipboard text/image and unsaved custom suffixes still use their existing safe creation flow and correctly gated follow-up fallback.
- [ ] Check native Quick Look, actual application opening, first-use access, missing/moved apps, repeated operations, pending quit/update behavior and private temporary-file cleanup in an isolated environment.
- [x] Update this task's status/remaining checks and relevant native acceptance records. Update roadmap/public claims only to the extent actually implemented and verified; load Presentation before touching those public surfaces.
- [x] Review the final diff for unintended folder scope, settings loss, dependencies, clipboard access, logging or publication changes.

Exit: every required acceptance item has evidence or is explicitly outstanding. Do not mark the product task complete while required native behavior remains unverified. Commit, push, installation, tags and releases remain separate requests.

## Acceptance matrix

Use Core tests for deterministic rules and injected failures, app/native fixtures for lifecycle/dispatch, and visible native checks for Finder/provider/editor behavior. The HTML prototype does not satisfy these rows.

| ID | Scenario | Required observable result / evidence |
| --- | --- | --- |
| A01 | New/legacy/malformed gate values | Both gates default off; valid saved on/off values survive relaunch; unrelated preferences identical; Core |
| A02 | All four switch combinations | Only requested controls/actions exist; no disabled placeholders or unreachable focus stops; app UI + native keyboard |
| A03 | Disable, edit/save another field, re-enable | Original template action/app choice restored exactly; Core + app integration |
| A04 | Toggle save failure | Previous switch and behavior retained; no generation advance or configuration loss; injected store failure |
| A05 | Opening gate changes during pending write/retry | Off-origin requests never acquire permission later; off/on never revives old launch; current valid on-origin request dispatches once; executor spy |
| A06 | Preview disabled/change/close during rendering | No new preview work while off; canceled/stale completions invisible; owned snapshot released; injected worker + native fixture |
| A07 | Copy text, imported Office, bundled Office and a disabled source | Fresh custom ID, source unaffected, copied fields preserved, copy enabled after save, correct position/defaults; Core + editor |
| A08 | Cancel copy or fail save | No new template, persisted app entry or asset; draft retained on save failure; fault fixture |
| A09 | Source removed while copy editor open | Text/available-asset copy appends independently; unavailable Office asset keeps the draft with guidance; never resurrect source; integration |
| A10 | Remove last/shared/bundled Office reference | Delete only unreferenced managed asset after successful save; never delete bundled or another template's bytes; filesystem fixture |
| A11 | Restore built-ins / old configuration import | Custom copies and actions retained; built-in identity/removal/disabled migration rules preserved; gates unaffected except documented decode defaults; Core |
| A12 | Fixed date, UTC midnight/year boundary, preview on/off | Preview and write share captured date and exact UTF-8; independently asserted expected bytes; Core |
| A13 | Literal tokens, nested-looking replacement values, CRLF/BOM/Unicode | Single pass; actual edited body stays verbatim through format/name changes; Core + native editor |
| A14 | Same-name increment/fail/confirmed replace, including races | Existing files preserved; preview never reserves a name; template body uses actual candidate name and captured time; filesystem tests |
| A15 | Same-suffix templates with different actions | Exact selected template governs quick/panel creation; no suffix-based action conflation; Core + native routes |
| A16 | Follow Template vs temporary override across switches | Follow updates; explicit choice sticks; cancel/finish never writes it back; fresh panel resets; integration |
| A17 | Write failure, canceled authorization or duplicate submission | No follow-up dispatch; draft/content retained; normal permission retry; injected writer + native permission fixture |
| A18 | Actual default/selected application opening | Correct created file and app receive the request; actual content visible; no default-association/menu changes; receiver fixture + supported editor QA |
| A19 | Script/unknown handler or unverified editing route | No execution through default/terminal fallback; file retained with actionable editor choice; policy tests + native negative case |
| A20 | App missing/moved/identity changed; file replaced/deleted | No silent app/path substitution; clear saved-file outcome; receipt retry cannot call writer; fixture |
| A21 | Quit/update during write/import/dispatch; close during preview | Mutating/dispatch work guarded until completion; preview cancels safely; no drafts/files lost; app lifecycle fixture |
| A22 | Valid/missing/damaged Office preview, unavailable provider | Native valid rendering or explicit provider fallback; invalid asset cannot create/export; original asset unchanged; native QA + digest checks |
| A23 | Text/Office/bundled package round trip | Exact content bytes, metadata, order, enabled states, defaults and portable actions restored under ID mapping; filesystem/Core fixtures |
| A24 | Same ID changed, different ID equivalent, same name changed, same suffix distinct | Deterministic Add/Skip/Copy choices with no overwrite; unique IDs/copy names; Core planner |
| A25 | Default adoption, skipped/disabled target, reserved built-in IDs | Existing explicit defaults/tombstones preserved; every effective fallback change reviewed; no dangling references; Core |
| A26 | Unknown version/keys, duplicate keys/entries, bad CRC/hash, wrong Office kind, bad XML/UTF-8 | Entire package rejected before managed-store/config mutation; parser and asset fixtures |
| A27 | Size/count/expansion limits, offset overflow, ZIP64/encryption, path/link attacks | Early bounded failure; no arbitrary extraction, large allocation or external-file access; malformed package fixtures |
| A28 | Changed input or changed preferences after review | Reviewed snapshot remains authoritative; stale merge plan requires a new review; integration |
| A29 | Cancel at pick/validation/review and failure in journal/stage/save | Original preferences/assets remain byte-identical; only owned resources cleaned; injected faults |
| A30 | Interruption before/after asset publication or configuration commit | Fresh coordinator recovers from exact journal/marker, keeps referenced assets, never duplicates committed records; restart fixtures |
| A31 | Corrupt journal/preferences or a replaced staged path | Fail closed and preserve evidence; no scan, overwrite or deletion of replacement; recovery fixtures |
| A32 | Export cancel/failure/overwrite and unavailable selected asset | Previous export target intact until confirmed atomic commit; no incomplete successful archive; native picker + writer fault fixture |
| A33 | Imported selected app unavailable, features disabled | Choice stored inertly, gates unchanged, no application lookup crawl/launch, explicit local repair when enabled; integration |
| A34 | Chinese/English, light/dark, minimum size, VoiceOver and keyboard | Readable layout/labels, visible focus, no hidden control in traversal, existing shortcuts preserved; native UI |
| A35 | Finder repeated/cold-launch creation, clipboard text/image, custom suffix | Correct captured destination, settings-window isolation, existing content/collision rules, gated follow-up; native + focused creation tests |

## Verification plan and completion rule

- Planning-only changes: inspect changed text, Markdown links/anchors, example schema consistency and `git diff --check`. Do not run Swift tests, a native spike, app build or `make verify` during this documentation request.
- After completed Core implementation phases, run `make verify` as required by HARNESS. Add focused Swift tests for these rules; do not extend the public JSON Harness to accept arbitrary custom templates, apps, packages or unsupported assertions.
- After App/SharedUI/Finder changes, also run `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build`. If project/framework/UTType registration changes are needed, load Distribution, edit `project.yml`, then run `make project`; do not edit generated project files.
- Follow [Core checks](../../specs/verification/core.md) and [Finder/native checks](../../specs/verification/finder.md). Existing `bash scripts/build_open_with_harness.sh` demonstrates a disposable native receiver approach; adapt only if it exercises the new production path rather than duplicating its logic.
- Unit expectations must be constants or independently derived fixtures. Use unique private test directories and injected clocks/stores/dispatchers. Check output bytes, prior-file preservation, reference sets and guard/grant release, not just success status.
- Keep native fixtures separate from the user's preferences, source documents and installed app. Do not overwrite `/Applications/FileMint.app`, change real file associations or enable/disable the user's Finder extension as an implied verification step. If the required controlled native environment is unavailable, record the blocker and leave the affected acceptance rows unfinished.
- Record each implementation result as passed/failed/not-run/blocked with the exact revision/worktree, command, environment and concise evidence. A successful open callback is handoff evidence; actual editor rendering, Quick Look behavior and installed Finder interaction require their own observations.
- Product completion requires the three requested capabilities, both gates, migrations, transactional preservation and every applicable acceptance row. Updating documentation or producing a green build does not complete those requirements. Publishing is outside this task.

## Implementation risks and required decisions

| Risk | Required treatment | Resolve by |
| --- | --- | --- |
| Quick Look provider behavior varies by machine/version | Verify selected integration and explicit unavailable fallback; no synthetic preview claimed as native | P0/P3 |
| Default handlers can execute a newly created file | Resolve handler and enforce verified editing policy; record supported identities and negative cases | P0/P4 |
| New fields cause an entire template array to fall back | Tolerant per-template decoding and parent migration after reveal decoding; neighbor-preservation fixtures | P1 |
| Hidden controls accidentally reset values | Preserve complete template draft/model on every save/copy/import path | P1/P2/P6 |
| File save outlives panel/busy state | Unified completion executor with held access and pending-work guards | P4 |
| Generalizing Office ZIP logic weakens existing validation | Small bounded parser surface, store-only outer format, existing Office regressions retained | P5 |
| Multi-file import is mistaken for one atomic filesystem operation | Write-ahead journal, exclusive staging, one preferences commit and exact recovery ownership | P6 |
| Portable app hint is treated as a grant | Separate exchange/local representations; unresolved hints remain inert | P5/P6 |

These are implementation work items, not additional permission gates or reasons to pause this planning request. Any later design change must remain within the confirmed product scope and update the owning SPEC/task before code diverges.

## Decisions and progress

- 2026-10-05: Read current contracts and traced relevant source on `64820a9`. The old plan's exclusions of Office templates and template exchange no longer match this request, so T2/T4 are superseded here without implementing T3.
- 2026-10-05: User explicitly selected per-template configuration in Templates & Types plus a temporary choice while creating. This supersedes the initial global-default proposal. Updated the plan and prototype; no product code was changed.
- 2026-10-05: User asked whether preview calls Apple's preview capability. Clarified that the interactive prototype is simulated, Office previews are planned to embed native Quick Look, and text previews show FileMint's resolved output rather than relying on a system renderer to expand variables.
- 2026-10-05: User requested master switches in Creation Behavior to keep both editing and creation simple. Revised the design to independent default-off gates, hiding complete feature UI and suspending feature work without clearing saved template choices. This supplements, rather than reverses, the per-template configuration decision.
- 2026-10-05: User requested a complete task specification. Completed the local model/migration contract, gate/draft transitions, versioned package schema, deterministic merge rules, journal recovery, P0–P7 checklists and A01–A35 acceptance matrix. Text payloads are separate archive entries so the 4 MiB manifest and 8 MiB text limits are consistent. The product remains unimplemented.
- 2026-10-05: The current prototype starts on Creation Behavior with both switches off. It retains template copy/edit, per-template actions when enabled, current-file overrides, optional content previews, export selection and import conflicts. All data and success messages are simulated; no real files or apps are created/opened by the prototype.
- Planning decisions: default-off independent gates, per-template action/current-file override, optional selection preview, Add/Skip/Copy import without replacement, and a bounded version-1 container. Native feasibility for Office preview/editor profiles is explicitly assigned to P0 rather than presumed from the prototype.

## Planning evidence (historical)

The table below belongs to the earlier planning/prototype turn. Current implementation checks follow it.

Examined worktree: `64820a9` plus this planning documentation. Environment: local macOS; installed FileMint unchanged.

| Check | Status | Evidence boundary |
| --- | --- | --- |
| Source/contract tracing | passed | Current source and the five selected domains reviewed; no inference from past release evidence |
| Prototype JavaScript syntax | passed | Parsed the inline script with Node; this checks the prototype only |
| Initial prototype browser interaction/layout | passed | Initial in-app-browser checks observed copy/save, creation/open completion, import/export and readable 360px layout; these observations predate the per-template-action revision |
| Previous per-template prototype | passed | Before feature gates: Node syntax; browser observed template-specific settings, temporary override, saved-setting preservation and fresh-panel reset. No native API called |
| Optional-feature prototype | passed | Node syntax; browser observed all four gate combinations, simple editor/creation UI with both off, basic Finder reveal rather than app opening when off, independent visibility, and the saved action retained after edits while hidden and off/on cycling. No browser console errors; native preview/dispatch remain unimplemented |
| Earlier planning documentation | passed | Before this expansion: `git diff --check` and 52 local links/anchors across the three changed planning documents |
| Complete task document | passed | 55 local links/anchors resolved; P0–P7 and A01–A35 are unique/complete; example manifest parses and its empty-payload digest/ID/default references match; whitespace and `git diff --check` passed. Documentation checks only |
| Swift tests / `make verify` / app build | not-run | Planning and prototype only; no Swift/runtime change |
| Native Quick Look / Finder / open-app acceptance | not-run | Requires future product implementation and an isolated native fixture |

## Implementation evidence — 2026-10-05

Checkout: `/Users/daigua/Documents/Ray/FileMint`, `main`, base `64820a9` plus
uncommitted implementation. The initial `564d/FileMint` worktree was migrated with
15-file byte verification and then removed at the user's request. AGENTS now
requires an explicit request before using a worktree. The primary checkout's
existing planning edits were preserved.

Environment: macOS 27.2 (26B5091g), arm64, Xcode's Swift 6.4, deployment target 13.0.
Code snapshot SHA-256: `4c81e26c9f5e5192eeb55fa99dfa55eeea1d4addae61d146a3f6961314385d1e`.
The [source digest](../../build/template-workflow-qa-2026-10-05/source.sha256)
covers App/SharedUI/Core source and tests, project/Info and the native fixture.
The final Core refinement and validation-cancel UI are covered by the full run/build.
The last matching native fixture run is in [native-final.log](../../build/template-workflow-qa-2026-10-05/native-final.log);
view-cache images are from the preceding render pass and are partial evidence.

| Check | Status | Current evidence and boundary |
| --- | --- | --- |
| `make verify` | passed | [Log](../../build/template-workflow-qa-2026-10-05/verify.log): 210 Core tests, 14 image tests, 5/5 public JSON cases, 10 CLI regressions, appcast/release/notarization/resume/entitlement checks. No public Harness schema expansion. |
| `make project`; `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | [Build log](../../build/template-workflow-qa-2026-10-05/build.log). Main app and Finder extension build; `project.yml` owns the exported package type, and generated `Config/AppInfo.plist` reflects it. Version/build and entitlements unchanged. |
| `bash scripts/build_template_workflow_harness.sh` | passed | [Build log](../../build/template-workflow-qa-2026-10-05/native-build.log). Disposable sandboxed application uses production model, panel, preview and executor; receiver is a unique fixture identity with test-only policy injection. |
| `FILEMINT_TEMPLATE_QA_MODE=screenshots <fixture>/Contents/MacOS/TemplateWorkflowSmoke` | passed with explicit environment limits | [Native log](../../build/template-workflow-qa-2026-10-05/native.log): four gate combinations/persistence, failed preference save without generation advance, Office copy and last/shared-reference cleanup, hidden-action preservation, real receiver handoff, stale/off-origin gates, duplicate completion and replacement rejection. |
| TextEdit signing profile | passed | Native Security API validates Apple's signed `com.apple.TextEdit`. This establishes the publisher profile, not visible editor content. |
| VS Code signing profile | blocked | The installed `com.microsoft.VSCode` declares Microsoft team `UBF8T346G9` but strict verification reports its sealed `workbench.html` modified. The production executor rejects this route and retains the saved file. No repair or installation performed. |
| Office native content preview | blocked | Both valid bundled DOCX/XLSX return unavailable from the system thumbnail provider in the sandbox fixture. Metadata fallback, invalid/missing-asset state, source-byte preservation, stale-result cancellation and owned-snapshot cleanup passed. Native document rendering/offline provider behavior is not claimed. |
| Bilingual/native layout | partial | 24 native view-cache renders cover four gate combinations in settings/types/creation, with light/dark variants. SwiftUI layouts and full metadata fallback inspected. AppKit cached panel renders are incomplete; these are not live screen captures or keyboard/VoiceOver proof. |
| Desktop interaction automation | blocked | `cua_repl` failed to start its Node runtime with `No such file or directory`. No live clicking, typing or VoiceOver/keyboard acceptance can be inferred from the view-cache images. |
| Installed signed Finder, macOS 13, actual editor rendering, quit/update interaction | not-run | No installation requested; minimum-target compilation and isolated receiver success do not prove these scenarios. |
| Final diff/privacy review | passed | No dependencies, folder crawling, clipboard monitoring, user-file content logging, Finder transport changes, installation, commit or publication. Existing clipboard/image paths retain their fallback; Core receipts distinguish actual text from binary bytes. |

Acceptance coverage is intentionally split by evidence type:

| Acceptance IDs | Current coverage | Outstanding evidence |
| --- | --- | --- |
| A01, A03–A05 | Core migration/generation plus production-model save-failure and hidden-action fixtures | Ordinary installed-app relaunch UI remains unobserved. |
| A02, A34 | Source visibility/focus order and four-combination native renders | Live keyboard, minimum-size interaction, VoiceOver and Reduce Motion. |
| A06, A22 | Bounded validated snapshots, invalid/missing states, cancellation and unavailable-provider cleanup | Successful Quick Look content rendering, read-only/offline behavior on supported systems. |
| A07–A11 | Complete-field Core copies, restoration/migration and production Office reference cleanup | Live Copy editor cancel/failure/source-removal UI. |
| A12–A15 | Fixed UTC boundaries, independent byte expectations (BOM/CRLF/Unicode/literal tokens), actual collision names, exact-ID action rules | Live template switching/quick Finder routes. |
| A16–A21 | Immutable follow-up provenance, sticky selections, receipt identity, native receiver and rejected/duplicate routes; existing termination policies plus extended pending-work accounting | Actual supported editor content, picker/permission retry UI, moved app cases and ordinary quit/updater interaction. |
| A23–A27 | Independent V1 ZIP fixture, text/Office round trips, strict schema/CRC/header/path/flag/count/UTF-8 checks, deterministic merge/default rules and bounded-file tests | Native package picker/save-panel overwrite paths and maximal combined Office expansion stress. |
| A28–A31 | Immutable Data snapshot, semantic revision canonicalization, compatible stale-review choices; save rollback and fresh recovery at journal/staged/published/before-save/after-save/cleanup checkpoints, replaced-file/corrupt-journal and mid-commit corrupt-preferences preservation | Actual process termination/power-loss and replaced-stage native fixtures. |
| A32–A33 | Atomic export implementation, asset validation, inert app hints, unchanged gates and no automatic app discovery/launch | Interactive export cancellation/overwrite and local app repair. |
| A35 | Existing focused creation/clipboard/image tests retained; common panel/executor compiled, actual byte-kind receipts and untemplated fallback connected | Installed cold/warm/repeated Finder and clipboard interactions. |

Implementation decisions:

- Preserve the effective default when a disabled source's enabled copy would
  otherwise precede the old implicit default; pin the old ID only in that case.
  Existing explicit defaults and ordinary copies stay unchanged.
- Keep a semantic preferences revision. Set iteration order in existing resource
  and file-tool preferences is normalized only for hashing, preventing spurious
  stale-import decisions without changing saved settings semantics.
- Require actual text receipts and trusted publisher signatures for the initial
  TextEdit/VS Code editing profiles. Office and binary routes without a verified
  editing profile keep the saved file and present a follow-up failure/Reveal path.
- Give imported selected-app hints no authority. Resolve only matching existing
  local references that were freshly validated; no imported gates or bookmarks.
- The snapshot read/write guards extend through post-creation completion. A saved
  receipt can retry opening only; the executor has no file writer.

## Code-review fixes — 2026-10-05

The four findings from the review of this uncommitted implementation are fixed
in the primary checkout. These restore the existing contracts; no installation,
commit, push or publication was performed.

- Preferences: serialize store writes and atomic read/modify/save operations;
  compare model saves with their committed baseline. Block and roll back ordinary
  model saves during template work. The import revision check, settings commit
  and journal reconciliation share the same lock; folder authorization updates
  preserve the latest template configuration. Reload after import completion.
- Export: use Foundation's same-volume item replacement directory instead of
  creating a sibling directory that a file-only save-panel grant cannot authorize.
  Publish by atomic rename after writing and checking cancellation.
- Import review: resolve each conflict against the preceding accepted choices,
  retain explicit Copy choices when an earlier row is skipped, and invalidate
  the old executable plan throughout rebuilding and after failure. Both the
  button and the commit entry point require a valid current plan.
- Selected applications: reject saving an action without a valid portable app
  identity, disable Save for that draft, and migrate malformed persisted actions
  to the existing reveal fallback. Valid imported hints remain saveable/exportable
  without a local application grant.

Current source identity is recorded in the
[source manifest](../../build/template-workflow-bugfix-2026-10-05/source.sha256).
Results below apply to that uncommitted snapshot, macOS 27.2 arm64, Xcode Swift 6.4.

| Check | Status | Evidence |
| --- | --- | --- |
| `make verify` | passed | [Log](../../build/template-workflow-bugfix-2026-10-05/verify.log): 214 Core tests, 14 image tests, 5/5 public cases, 10 CLI regressions and release/appcast/signing checks. Initial restricted execution was blocked by Swift cache permissions; the approved standard-cache run passed. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | [Log](../../build/template-workflow-bugfix-2026-10-05/build.log): unsigned app and Finder extension built. |
| Native production-model regression fixture | passed | [Build](../../build/template-workflow-bugfix-2026-10-05/native-build.log), [run](../../build/template-workflow-bugfix-2026-10-05/native.log): ordinary saves roll back while busy, invalid app actions preserve settings, an actual size-limit replan failure blocks submission, and a corrected review imports successfully. Existing gate/copy/receiver/receipt checks also pass. |
| File-only sandbox export | passed | [Log](../../build/template-workflow-bugfix-2026-10-05/export-sandbox.log): the production codec creates and atomically overwrites the exact allowed destination while sibling writes are denied. [Probe](../../build/template-workflow-bugfix-2026-10-05/ExportProbe.swift) and [profile](../../build/template-workflow-bugfix-2026-10-05/export.sb) retained. This models the file grant; it is not a live Save-panel interaction. |

The earlier native limitations remain: the installed VS Code signature is rejected,
Office providers return unavailable, and installed Finder/live keyboard/VoiceOver
acceptance has not been completed. These checks do not claim full product QA.

## Commit QA and selected-application icons — 2026-10-05

The requested revision is `51e49db28dd0e342b5c84f40bf86b4ecb5af46af`;
HEAD matched and the primary checkout was clean when verification started.
Environment: macOS 27.2 (26B5091g), arm64, Swift 6.4. The installed 0.6.6/build 25
app was not replaced or used as a fixture. Its real preferences SHA-256 remained
unchanged. Only disposable sandbox fixtures and owned test files were used.

During QA the user requested native application icons after selecting a creation
application, including temporary choices. That narrow follow-up is uncommitted
on top of the requested revision. Its rule is in [Presentation](../../specs/domains/presentation.md).
Template editing and the panel show the selected icon/name, keep accessible text,
use a generic icon for an unavailable local reference, and cancel icon work when
hidden or closed. Imported hints never cause application discovery.

| Check | Status | Current evidence |
| --- | --- | --- |
| Original revision `make verify` | passed | [Log](../../build/qa-51e49db-2026-10-05/verify.log): 214 Core tests, 14 image tests, 5/5 JSON cases, 10 CLI regressions and offline release checks. Initial restricted-cache failure was resolved with the approved standard-cache run. |
| Original unsigned app/extension build | passed | [Build](../../build/qa-51e49db-2026-10-05/build.log); generated from project.yml. |
| Original sandboxed native fixture | passed | [Run](../../build/qa-51e49db-2026-10-05/native-ui.log): model/save/review regressions, copy/asset lifetime, gate generation, receiver dispatch, duplicate/replaced-file rejection and preview cleanup. |
| Live copy and text preview | passed | Office copy canceled without adding an entry. Markdown copy saved after its source with a fresh ID, enabled state and unchanged default. Editor preview displayed the exact fixed 2026-01-01 UTC example. [Readback](../../build/qa-51e49db-2026-10-05/ui-readback.json). |
| Live creation and TextEdit content | passed | Filename-to-suffix synchronization, Tab from content to Paste, plain paste/undo and Command-Return observed. The actual saved bytes matched Unicode, emoji and literal tokens. System TextEdit opened the exact created URL and visibly displayed the expected text. [Created text](../../build/qa-51e49db-2026-10-05/ui-textedit.txt). No editing policy was injected for this handoff. |
| Native package export/import | passed | Native Save panel wrote the [package](../../build/qa-51e49db-2026-10-05/ui-export.filemint-templates); independent ZIP inspection confirmed exact payload/digest, portable app hint, and no local path/bookmark/registry ID. Native import review defaulted the duplicate to Skip with Import disabled; Save as copy then added an independent 18th row. Existing 17 rows, defaults, gates and app registry were unchanged. |
| Icon follow-up automatic/build checks | passed | [Verify](../../build/qa-51e49db-2026-10-05/icons-verify.log), [build](../../build/qa-51e49db-2026-10-05/icons-build.log), [native regression](../../build/qa-51e49db-2026-10-05/icons-native-ui.log). Native icon bitmap/name, invalid identity, disable/hide and re-enable restoration checked. |
| Icon follow-up live UI | passed | Actual temporary TextEdit selection displayed icon/name; Cancel left the registry and template actions unchanged. Template editor displayed the icon immediately and after save/reopen. A fresh panel following that saved template showed the icon/name and Create and Open. Chinese/light layout inspected on screen. |
| Office native content rendering | blocked | Both DOCX and XLSX providers returned unavailable on this machine. Explicit fallback, missing/invalid asset rejection and snapshot cleanup passed; content rendering is not a pass. |
| Installed VS Code editing profile | blocked | Current strict signing validation rejects the installed bundle. The route remains denied; no repair or installation attempted. |
| Installed signed Finder, macOS 13, full keyboard/VoiceOver/Reduce Motion and bilingual appearance matrix, actual quit/update lifecycle | not-run | Isolated source QA does not prove these remaining environments/interactions. Live automation was usable but had transient AX/timeouts; native cache images were not substituted for live evidence. |

No new confirmed defect was found in the exercised original-revision paths.
This is a bounded QA result, not full A01–A35 native acceptance or release approval.
Source digests and fixture readbacks are retained in
`build/qa-51e49db-2026-10-05/`. No commit, installation or publication was performed.

## Handoff

- Base source is committed as `51e49db`; the icon follow-up and QA records remain
  uncommitted in the primary checkout. P1/P5 rules and
  the implementation parts of P2/P3/P4/P6 are present; P0/P7 native acceptance has
  explicit unfinished items. Do not mark the product task complete or publish
  while its required native checks remain outstanding.
- Start from the outstanding acceptance rows above. Read this task and only its
  relevant domains/source. Preserve the user's primary-checkout rule; no new or
  reused worktree without an explicit request.
- Remaining native evidence is listed in the commit QA above. TextEdit and core
  live editor/panel/import/export paths have current evidence; full accessibility,
  Office providers, trusted VS Code, installed Finder, macOS 13 and lifecycle do not.
- Current QA logs and readbacks live in the ignored
  `build/qa-51e49db-2026-10-05/` directory. They describe this source and
  environment, not an installed release. Old planning/prototype/release evidence
  must not be promoted to current acceptance.
- T3 filename rules, cloud synchronization, arbitrary binary templates, commands,
  installation, commit/push, tags and publication remain outside this request.

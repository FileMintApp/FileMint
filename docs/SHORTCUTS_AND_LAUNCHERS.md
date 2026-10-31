# Shortcuts & Launchers

[中文指南](SHORTCUTS_AND_LAUNCHERS.zh-CN.md)

This guide describes the **unreleased integration build**. It opens a draft for
you to review. Only **Create** writes a file. An action returning “draft opened”
does not mean the file was created.

The build requires an Apple-silicon Mac and macOS 13.3 or later, with a logged-in,
interactive desktop. Current native evidence is from macOS 27.2, Shortcuts 10.0
and Raycast 2.10.1.0. Running on macOS 13.3 remains unverified. Raycast is installed
separately. See the [task and acceptance evidence](tasks/2026-10-29-shortcuts-and-launchers.md)
for exact builds, remaining environments and first-time-user acceptance.

## New project note

For a recurring destination, first authorize it in **Settings → Finder & Folders**.
That saves folder access and also changes Finder menu scope. A folder chosen only
for one draft does not silently become a monitored folder.

In **Settings → Shortcuts & Launchers**, start **New project note**:

1. For Shortcuts, open the Shortcuts app, create a shortcut and add FileMint's
   **Open File Draft** action. Select an enabled text template, such as Markdown,
   and a fixed save location. Set Filename to **Ask Each Time**. Keep Initial
   Content on **Template Content**.
2. For Raycast, select **Raycast…**. Choose a template and location, leave Filename
   on **Enter in Raycast**, then export the script to a folder you control. In
   Raycast Settings → Extensions → Script Commands, add that folder.
3. Each day, run the command and enter only the note name. Check the template,
   destination and content in the draft; choose Create or Cancel.

The generator's **Preview draft** opens the same creation panel and writes
nothing. Cancelling or finishing that preview restores the generator's original
configuration. Draft edits do not rewrite the command configuration. Cancelling
a directory picker or a failed write keeps the draft open.

## Save text from a workflow

In Shortcuts, put a **Text** action, or another action producing text, before
**Open File Draft**. Configure a filename, a text template and a save location.
Choose Initial Content → **Specified Text**, then connect the earlier action's
text output to Text. No second manual filename or body entry is needed at runtime.

FileMint preserves spaces, line breaks, Unicode and literal template tokens.
`{{year}}`, shell syntax and URLs in supplied text remain text. Choose **Empty
Content** for an intentionally empty file. Supplied text, including an empty
string, cannot be combined with an Office template. Template Content uses the
selected template's normal rendering rules.

## Show Quick Search

Add **Show Quick Search** in Shortcuts. It has no parameters. Alternatively,
start the Quick Search scenario in settings and export a Raycast command or
copy its URL. Repeated calls focus the open search and preserve its query.
This action does not toggle search closed and does not itself create a file.

## Export and local testing

The settings guide reports only what FileMint observed: script saved, link copied,
or this local test request received. Importing a command into a third-party tool
must be checked in that tool. The guide stays nonmodal so real calls can arrive.
**Return to editor** keeps the current configuration; closing settings clears it.

A Raycast script has no Node/Python dependency. Runtime arguments are encoded as
data. A successful script exit means macOS accepted the URL handoff, not that
FileMint accepted the draft or saved a file.

Exports can contain text, folder paths and local template/favorite IDs. Review
them before sharing. Other tools may retain their own command history. Prefer
native parameters for longer or sensitive text. FileMint does not upload the
configuration, watch the clipboard or keep a content-preset library.

## Public URL version 1

```text
filemint://draft?v=1&name=Project%20Note&template=markdown
filemint://draft?v=1&name=Workflow&template=markdown&text=First%20line%0ASecond%20line%0A
filemint://draft?v=1&name=Empty&template=markdown&text=&location=ask
filemint://search?v=1
```

Encode every value separately. For example, `A & B + # %` becomes
`A%20%26%20B%20%2B%20%23%20%25`. A literal `+` is not decoded to a space.

| Field | Meaning |
| --- | --- |
| `v` | Required; exactly `1`. |
| `name` | Optional filename; a bare name gains the selected template's suffix. A supplied suffix must match it. |
| `template` | Optional exact enabled template ID on this Mac. A missing or disabled explicit ID is rejected. |
| `text` | Absent uses template content; present, including empty, supplies verbatim text. |
| `directory` | Optional absolute local directory suggestion. It grants no access. |
| `favorite` | Optional saved folder UUID on this Mac. It grants no access by itself. |
| `location` | Only `ask`; choose the destination in FileMint. |
| `id` | Optional UUID for in-memory deduplication. |

`directory`, `favorite` and `location=ask` are mutually exclusive. Search accepts
only `v=1`. Unknown/duplicate fields, path components, fragments, ports, userinfo,
invalid UTF-8/percent encoding and NUL are rejected in the representation FileMint
receives. macOS or an upstream caller may normalize the original URL first;
FileMint cannot recover the caller's earlier spelling.

Limits are UTF-8 bytes, never silently truncated: complete URL 16 KiB, URL text
8 KiB, native Shortcuts text 1 MiB, filename 1 KiB, directory 4 KiB and template/
favorite identifier 256 bytes. Use native Shortcuts for a larger body. IDs and
paths may need reconfiguration on another Mac.

Repeating an active ID with the same normalized request focuses its draft;
changing that request conflicts. A finished ID cannot reopen for ten minutes.
IDs are not persisted and the bounded ledger can evict older entries. Omit `id`
for an ordinary new invocation. An existing unfinished draft keeps its edits and
undo, and busy/modal requests are rejected without a queue.

## When a request cannot open

Keep or cancel the unfinished draft before retrying another request. Finish a
modal dialog or active operation before retrying a busy action. Choose an enabled
template again if its ID no longer exists. Reauthorize an unavailable destination
explicitly; FileMint preserves the input and does not substitute another folder.

If Shortcuts cannot make the app ready within its bounded preparation interval,
it reports unavailable. Cancelling that preparation must not open a panel later.
Headless/background-only workflows are outside this interactive draft workflow.

The development build's minimum is shared by the app, Finder extension and
appcasts. Homebrew uses its Ventura major-version dependency plus a version-only
13.3 gate. Previously released clients can still display a GitHub update notice
before Sparkle filters incompatible updates; this build cannot retroactively
remove an older client's notice. No new release, tap push or website publication
is implied by this guide.

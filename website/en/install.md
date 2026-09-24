---
title: Install FileMint
description: Install and enable FileMint on macOS.
---

# Install FileMint

The 0.6.0 stable installer supports **M-series Macs on macOS 13+** only and contains no Intel code. Intel Macs cannot install or update to 0.6.0; published installers through 0.5.10 keep their original compatibility.

Stable installers from 0.5.9 onward are Developer ID signed, Apple notarized and stapled.

## First install

1. Download the latest DMG from [GitHub Releases](https://github.com/FileMintApp/FileMint/releases/latest).
2. Open it and drag FileMint into Applications.
3. Launch FileMint from Applications, then follow the in-app prompt to enable its Finder extension and authorize your working folders.
4. Back in Finder, right-click the desktop or the background of an authorized folder and choose **New File**.
5. To use File & Folder Tools, open **Settings → Extensions → File & Folder Tools**, then enable the master switch, the actions you need, and each action's main-menu or submenu position.

The Finder extension and folder authorization are separate system capabilities. FileMint guides you to the relevant settings but never changes system permissions silently.

After installation, follow the [user guide](./guide) to create your first file, set up templates and enable optional tools.

## Create from templates

Enable and reorder formats in **Templates & Types**. Add text templates with their own default filenames and starter content, keep several templates for the same suffix and choose a default.

Choose **Import Document Template** to select a `.docx` or `.xlsx`. FileMint stores a separate local template copy. Select it from Finder or the creation panel to create a new document with formatting and content intact. Existing names are numbered, never overwritten. A custom text suffix does not convert text into Word, Excel or another binary format.

## Save a clipboard image

Copy a screenshot or bitmap, then choose **Paste Image as File** in FileMint or Finder's **New File** menu. Review the preview, filename and destination, then click **Create** to save as PNG. Cancelling creates nothing; existing names are numbered automatically.

## Open with your apps

Add applications under **Extensions → Open with App** and choose a main-menu or submenu position for each. Select files or folders in an authorized Finder location, then open them with the chosen app. New installations start with an empty list. System default file associations stay unchanged; the target app decides which file types it supports.

## Enable File & Folder Tools

File & Folder Tools is off by default. Once enabled, select one or more local files or folders inside an authorized scope. Each enabled action can appear directly in Finder's main menu or inside **File & Folder Tools**; New File stays unchanged.

- **Copy Names** retains suffixes, while **Copy Paths** writes complete local paths. A multi-selection uses one line per item.
- **Move File / Folder** captures source items without moving them. Right-click the target folder background, then choose **Move Selected Items Here** to complete the move. This target action has its own placement choice.
- Existing names never overwrite or merge. If items remain unfinished, fix the problem and try the target again; choosing a new source selection replaces the pending batch.
- **Delete Permanently** confirms by default and bypasses Trash. You can explicitly choose **Delete silently**; it never skips folder authorization, and a symbolic link is removed without touching its target.
- **AirDrop** starts off. When enabled, it opens macOS's native AirDrop UI and lets you choose a recipient; it never sends automatically or falls back to another sharing service.
- **Send Alias to Desktop** creates native Finder aliases without copying or moving the originals. Existing names are numbered. This tool starts off.
- The menu appears only when every currently selected item is inside an authorized scope. It does not crawl folders or monitor the clipboard.

## Use Resource Tools

Open **Extensions → Resource Tools → Use Tools** to choose images directly in the app, even with Finder integration off. To start from Finder, enable the default-off module and the actions you need under **Finder Menu Settings**.

- Convert formats, compress, resize, generate ICNS/ICO/PNG icon sets, stitch images and extract editable text with OCR.
- The panel shows a preview and output location before processing; originals stay unchanged and outputs are sibling copies or go to a folder you explicitly choose.
- Images and OCR results stay local. FileMint does not upload them or keep a processing history.

## Appearance and language

Under **General → Appearance**, choose Follow System, Light or Dark, and select English, Chinese or the system language. Theme changes apply immediately to FileMint windows without changing macOS appearance.

## Later updates

Automatic update checks are enabled by default and can be disabled in **General**. While FileMint is running, it checks release metadata at most once every 7 days. Downloads and installation remain your choice; manual checks still work with automatic checks off.

After installing 0.5.9, choose **About → Check for Updates → Update and Restart** for later releases. Finish creating or editing first; macOS may request administrator authorization.

When upgrading from 0.5.7/0.5.8, manually install 0.5.9 or later once. Those older versions have incorrect installer permissions that their own updater cannot repair:

1. Quit FileMint.
2. Drag the new version into Applications to replace the old copy.
3. Eject the FileMint installer volume and reopen FileMint from Applications.

For the full installation limitations, update notes and release provenance, see the [GitHub installation guide](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md).

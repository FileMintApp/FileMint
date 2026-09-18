---
title: Install FileMint
description: Install and enable FileMint on macOS.
---

# Install FileMint

FileMint supports **macOS 13 and later**. One DMG works on both Apple silicon and Intel Macs.

The 0.5.7 installer is Developer ID signed, Apple notarized and stapled.

## First install

1. Download the latest DMG from [GitHub Releases](https://github.com/FileMintApp/FileMint/releases/latest).
2. Open it and drag FileMint into Applications.
3. Launch FileMint from Applications, then follow the in-app prompt to enable its Finder extension and authorize your working folders.
4. Back in Finder, right-click the desktop or the background of an authorized folder and choose **New File**.
5. To use File & Folder Tools, open **Settings → Extensions → File & Folder Tools**, then enable the master switch, the actions you need, and each action's main-menu or submenu position.

The Finder extension and folder authorization are separate system capabilities. FileMint guides you to the relevant settings but never changes system permissions silently.

## Enable File & Folder Tools

File & Folder Tools is off by default. Once enabled, select one or more local files or folders inside an authorized scope. Each enabled action can appear directly in Finder's main menu or inside **File & Folder Tools**; New File stays unchanged.

- **Copy Names** retains suffixes, while **Copy Paths** writes complete local paths. A multi-selection uses one line per item.
- **Move File / Folder** captures source items without moving them. Right-click the target folder background, then choose **Move Selected Items Here** to complete the move. This target action has its own placement choice.
- Existing names never overwrite or merge. If items remain unfinished, fix the problem and try the target again; choosing a new source selection replaces the pending batch.
- **Delete Permanently** confirms by default and bypasses Trash. You can explicitly choose **Delete silently**; it never skips folder authorization, and a symbolic link is removed without touching its target.
- **AirDrop** starts off. When enabled, it opens macOS's native AirDrop UI and lets you choose a recipient; it never sends automatically or falls back to another sharing service.
- The menu appears only when every currently selected item is inside an authorized scope. It does not crawl folders or monitor the clipboard.

## Use Resource Tools

Resource Tools is a separate extension module and starts off. Turn it on under **Settings → Extensions → Resource Tools** to choose images in the app, or select images in Finder and open **Resource Tools** from the context menu.

- Convert formats, compress, resize, generate ICNS/ICO/PNG icon sets, stitch images and extract editable text with OCR.
- The panel shows a preview and output location before processing; originals stay unchanged and outputs are sibling copies or go to a folder you explicitly choose.
- Images and OCR results stay local. FileMint does not upload them or keep a processing history.

## Later updates

In 0.5.5 and later builds with the new updater, choose **About → Check for Updates → Update and Restart**. FileMint downloads, verifies, replaces the app and restarts. Finish creating or editing first; macOS may request administrator authorization.

Version 0.5.4 and earlier need one manual installation of 0.5.7:

1. Quit FileMint.
2. Drag the new version into Applications to replace the old copy.
3. Eject the FileMint installer volume and reopen FileMint from Applications.

For the full installation limitations, update notes and release provenance, see the [GitHub installation guide](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md).

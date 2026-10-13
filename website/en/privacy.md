---
title: Privacy
description: FileMint's local-first privacy promise.
---

# Privacy should not be a guess

FileMint creates files, stores document templates and processes images locally. It does not require an account or collect usage analytics.

## Data access you initiate

- **New File from Clipboard** reads plain text once only when you explicitly choose the action. It does not monitor the clipboard or save a file automatically.
- **Open the current folder with an app** passes only Finder's captured, authorized directory to a local app you configured. The terminal controls what it does afterward.

- **Favorite Locations** stores bookmarks and display details only for local items you add. It does not crawl folders or read file contents.
- **Remove Private Metadata** processes only local images you choose and writes a new copy after a readback check. Images are not uploaded and the original stays unchanged.
- **Finder hidden-item switching** runs only after your explicit click and requires macOS Accessibility permission. FileMint does not store or infer Finder's hidden-item state.

## What it does not collect

- Filenames, paths and content are never uploaded.
- It does not crawl folders, badge files or enumerate files in the background.
- It does not monitor the clipboard. Text is read when pasted or when you choose New File from Clipboard; an image is read when you choose Paste Image as File. Copying names, paths, editor text or OCR results requires your explicit action. Previewing an image does not save a file.
- Importing a Word or Excel template reads only the document you choose and stores an independent copy in the app’s private directory. Templates are not uploaded, and later changes to the original are not tracked.
- Open with App passes selected items or the current directory to a local app you configured without changing default file associations. The target app is responsible for what it does next.
- File & Folder Tools acts only on items you explicitly select inside an authorized scope. It does not read file contents, crawl folders, or upload names, paths or pending-move state. Delete Permanently acts only on captured selected items and does not log paths or content. AirDrop hands selected file URLs only to macOS's system sharing service, which handles recipient selection.
- Resource Tools acts only on images you explicitly choose. Conversion, compression, resizing, stitching and OCR run locally; originals stay intact, and images, text results and processing history are not uploaded or retained.

## When it uses the network

The main app uses GitHub to check for and retrieve updates. Automatic checks are enabled by default and can be disabled in General. They run only while FileMint is running, at most once every 7 days, and fetch release metadata only. Manual checks are also available. Downloading, installing and relaunching require you to choose Update and Restart; there are no automatic background downloads. The Finder extension stays offline.

When a website page opens, it requests the latest stable release metadata from GitHub’s public API to display the version and download link. This request does not read your local files or send account credentials.

Read the complete [privacy policy on GitHub](https://github.com/FileMintApp/FileMint/blob/main/PRIVACY.md).

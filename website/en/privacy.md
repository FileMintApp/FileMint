---
title: Privacy
description: FileMint's local-first privacy promise.
---

# Privacy should not be a guess

FileMint creates files, stores document templates and processes images locally. It does not require an account or collect usage analytics.

## What it does not collect

- Filenames, paths and content are never uploaded.
- It does not crawl folders, badge files or enumerate files in the background.
- It does not monitor the clipboard. Text is read when pasted, and an image is read when you choose Paste Image as File. Copying names, paths, editor text or OCR results requires your explicit action. Previewing an image does not save a file.
- Importing a Word or Excel template reads only the document you choose and stores an independent copy in the app’s private directory. Templates are not uploaded, and later changes to the original are not tracked.
- Open with App passes selected items to a local app you configured without changing default file associations. The target app is responsible for what it does next.
- File & Folder Tools acts only on items you explicitly select inside an authorized scope. It does not read file contents, crawl folders, or upload names, paths or pending-move state. Delete Permanently acts only on captured selected items and does not log paths or content. AirDrop hands selected file URLs only to macOS's system sharing service, which handles recipient selection.
- Resource Tools acts only on images you explicitly choose. Conversion, compression, resizing, stitching and OCR run locally; originals stay intact, and images, text results and processing history are not uploaded or retained.

## When it uses the network

The main app uses GitHub to check for and retrieve updates. Automatic checks are enabled by default and can be disabled in General. They run only while FileMint is running, at most once every 7 days, and fetch release metadata only. Manual checks are also available. Downloading, installing and relaunching require you to choose Update and Restart; there are no automatic background downloads. The Finder extension stays offline.

Read the complete [privacy policy on GitHub](https://github.com/FileMintApp/FileMint/blob/main/PRIVACY.md).

---
title: Install FileMint
description: Install FileMint on macOS with a DMG or Homebrew, enable the Finder extension and authorize folders. Check automatic update guidance and Apple silicon requirements.
---

# Install FileMint

<LatestRelease lang="en" />

FileMint supports **M-series Macs on macOS 13.0 or later**. Using [Shortcuts or a launcher](https://github.com/FileMintApp/FileMint/blob/main/docs/SHORTCUTS_AND_LAUNCHERS.md) requires macOS 13.3 or later. Current stable installers are Developer ID signed, Apple notarized and stapled.

## First install

1. Download the latest DMG from [GitHub Releases](https://github.com/FileMintApp/FileMint/releases/latest).
2. Open it, drag FileMint into Applications and eject the installer volume.
3. Launch FileMint from Applications. Follow the [first-time setup](./guide#complete-the-first-time-setup) to enable the Finder extension, choose where its menus appear and grant folder access. If you prefer to skip Finder setup, use **New File…** directly in FileMint.

You can also use the [official Homebrew tap](https://github.com/FileMintApp/homebrew-tap) for a fresh installation:

```sh
brew install --cask filemintapp/tap/filemint
```

If FileMint is already installed, read the tap instructions before switching from a manual install. Homebrew does not enable the Finder extension or grant folder access.

FileMint stores imported Word and Excel templates locally and reads clipboard images only when you choose **Paste Image as File**. For these and other workflows, follow the [user guide](./guide).

## Later updates

In **About → Check for Updates**, choose **Update and Restart** when an update is available. Finish creating or editing first; macOS may ask for administrator authorization.

Automatic update checks are enabled by default and can be disabled in **General**. While FileMint is running, it checks version information at most once every seven days. You can still check manually and choose whether to install.

If you are upgrading from 0.5.7 or 0.5.8, install 0.5.9 or later manually once. For other legacy versions, Intel compatibility or checksum verification, see the [GitHub installation notes](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md).

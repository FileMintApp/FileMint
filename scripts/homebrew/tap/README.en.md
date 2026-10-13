# FileMint Homebrew tap

[简体中文](README.md)

The official FileMint Homebrew tap provides a Cask using the original signed and notarized GitHub Release DMG. FileMint supports M-series Macs running macOS 13 Ventura or later; the Cask's `arm64` check cannot distinguish M-series from other Apple silicon. This tap has not been added to Homebrew's own Cask repository.

This tap provides a public FileMint Cask. Use the command below for a fresh installation. Migration from an existing manual installation and Finder behavior after upgrade or removal still await isolated native acceptance. See the [FileMint installation guide](https://filemintapp.github.io/FileMint/en/install) for other installation methods.

## Installation and first launch

On a Mac without an existing FileMint installation:

```sh
brew install --cask filemintapp/tap/filemint
```

Launch FileMint and follow the existing onboarding to enable its Finder extension in macOS settings and authorize the folders you want to use. Homebrew does not grant access, enable the extension or launch the app. Normal quarantine and Gatekeeper checks remain in place.

## Updates

FileMint's Update and Restart action and Sparkle updates remain available. After an in-app update, Homebrew's installation record may lag behind the actual app version.

`brew update` refreshes Homebrew and tap metadata without installing FileMint:

```sh
brew update
```

**Before any brew operation that may replace or remove FileMint, save or explicitly cancel drafts, finish creation, import, file operations and Sparkle updates, then manually quit FileMint and confirm it has exited. If it cannot quit safely, stop and wait; do not force termination.** The Cask sends no quit or termination signals. Homebrew does not enforce these prerequisites.

Only after completing those steps, run a bulk upgrade that may include FileMint:

```sh
brew upgrade
```

The Cask declares `auto_updates true`. Current Homebrew compares actual versions for suitable single app bundles: it can upgrade an older app and skips an equal/newer app or an unreliable comparison. Older Homebrew versions or environment settings may skip these Casks entirely. Do not assume bulk upgrades never replace FileMint. A named Cask upgrade, `--greedy` / `--greedy-auto-updates`, and `reinstall` may bypass the default skip decision; they are not general repairs for version differences. If the app is newer than the tap, keep it and wait for tap synchronization. Never run Sparkle and brew installation at the same time. Consult your version's [Homebrew manual](https://docs.brew.sh/Manpage#upgrade-options-installed_formulainstalled_cask-) and [update FAQ](https://docs.brew.sh/FAQ#how-does-brew-upgrade-handle-apps-that-update-themselves).

## Existing manual installations

Keep using your existing installation and its in-app updater. Manual-install migration awaits isolated native acceptance, so this initial delivery does not provide `--adopt` instructions. If an existing app conflicts with installation, do not use `--force`, automatically remove it, or install another copy to hide the conflict. A matching version alone does not establish identical contents, signatures or permission state.

## Uninstallation and retained data

**Save or cancel drafts, finish file operations and Sparkle updates, manually quit FileMint and confirm exit first. Defer removal if it cannot quit safely.** Once the tap is published and installed, normal removal is:

```sh
brew uninstall --cask filemintapp/tap/filemint
```

Normal removal deletes the Homebrew-managed app. The Cask has no `zap` stanza and retains user-created files, preferences, imported templates and saved folder bookmarks. This is not a full reset. Reinstallation also requires completed work and an exited app. Whether retained permissions remain usable depends on macOS; authorization may need to be granted again. Finder extension and menu behavior after removal still requires isolated native acceptance.

## Validation and maintenance

The read-only workflow checks Cask style, parsing, online metadata and upstream discovery. It does not install an app, hold Apple keys or publish releases. Those checks do not establish native installation, upgrade, migration, removal or Finder behavior.

The Cask is generated from a [verified stable FileMint release](https://github.com/FileMintApp/FileMint/releases/latest). Do not hand-edit the version or checksum, or replace a published DMG. Installing through Homebrew does not change the [FileMint license](https://github.com/FileMintApp/FileMint/blob/main/LICENSE).

Report problems to [FileMint Issues](https://github.com/FileMintApp/FileMint/issues), including your macOS, Homebrew and FileMint versions.

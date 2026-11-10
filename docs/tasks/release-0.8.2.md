# FileMint 0.8.2 release

Status: in-progress
Next action: Commit and tag the prepared source, then build and publish 0.8.2.

## Objective and scope

- Publish the owner's selected 0.8.2/build 31 from the primary `main` checkout.
  Verify the Swift 6.1 compilation repair before building the release.
- Verify the signed, notarized DMG and ZIP, both checksums and Sparkle feeds.
  Complete exact source CI, draft validation, website deployment and official
  Homebrew tap CI before recording completion.
- Document the shipped launcher entry points as the initial integration.
  The full launcher experience and promotional acceptance remain separate.

## Selected context

- [Distribution](../DISTRIBUTION.md) and [Harness](../../specs/HARNESS.md).
- [Hidden-file display](2026-11-10-finder-hidden-files-toggle.md),
  [folder authorization](2026-11-09-file-access-authorization.md), and
  [launcher checks](2026-10-29-shortcuts-and-launchers.md).

## Preparation

- GitHub Latest was `v0.8.1`, Sparkle build 30; `v0.8.2` had no existing
  local or remote tag or Release at preflight.
- [macOS 15 CI](https://github.com/FileMintApp/FileMint/actions/runs/42744566416/job/129593472937)
  failed to compile the async File Info read callback under Swift 6.1.2.
  Commit `aa167ad` explicitly isolates the callback to the main actor while
  keeping the file read on its existing detached worker. Local `make verify`
  and the unsigned main app and Finder extension build passed.
- Both runner builds passed in the
  [CI repair run](https://github.com/FileMintApp/FileMint/actions/runs/42745717477).
  Release metadata, context links and the local Pages build passed (27 site tests).
- The app and installer retain their macOS 13.0 minimum. Only Shortcuts
  and Launchers require macOS 13.3. Existing public assets stay unchanged.

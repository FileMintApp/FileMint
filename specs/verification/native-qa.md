# Native QA identity and publication

Load for native QA builders, signing, stable launch paths and per-run data.
The owning rules are in [HARNESS](../HARNESS.md#native-qa-application-identity).

## Identity registry

`scripts/native_qa.py` owns the finite QA kind registry. Builders create fresh
source bundles and publish them into `build/native-qa.noindex/KIND/APP.app`.
Launch the stable path printed by the builder, rather than its staging copy.
All paths below are relative to that stable root.

| Kind | App | Bundle identifier |
| --- | --- | --- |
| template-workflow | TemplateWorkflowSmoke.app | io.github.daigua.filemint.template-workflow-smoke |
| open-with | OpenWithSmoke.app | io.github.daigua.filemint.open-with-smoke |
| file-tools-settings | FileMintToolsUIQA.app | io.github.daigua.filemint.tools-ui-qa |
| move-sandbox | FileMintMoveSandboxSmoke.app | io.github.daigua.filemint.move-smoke |
| update-sandbox | FileMintUpdateSandboxSmoke.app | io.github.daigua.filemint.update-smoke |
| design-ui | FileMintDesignQA.app | io.github.daigua.filemint.design-qa |
| resource-tools | FileMintResourceQA.app | io.github.daigua.filemint.resource-qa |
| sparkle-installation | UpgradeQA.app | io.github.daigua.filemint.upgrade-qa |

The template/opening receivers retain their own stable identifiers and sit inside
their host's Resources. The update fixture's inert extension remains separate from
the actual Finder extension. No running fixture or receiver may be overwritten.

## Build and data ownership

- Run the existing `build_*_harness.sh` for the selected kind. Developer ID signing
  is local; use the project's existing certificate or the explicit QA identity
  override. Preserve existing sandbox entitlements and runtime flags.
- Every build has a unique run root and `FixtureRunID`. Persisted sandbox data
  (including pending moves and updater events) uses that run ID. Where persistence
  is intentional, relaunches retain the same run's data; another build gets separate data.
- `FixturePath` continues to refer to the generated run's fixtures, never the
  stable app directory or production preferences. Receivers use the current host's
  bundled URL. QA application paths do not grant access to fixture folders.
- Publishing verifies the source app's identity/signature, checks stopped state,
  holds a per-kind lock, stages a complete copy, and preserves the last verified
  app on a failed replacement. The immutable identity record binds the workspace,
  bundle ID, signing identity and designated requirement, with no private keys.
- For Sparkle, set the run ID in both old/new bundles before signing. Copy the
  already-signed old host without re-signing, preserving its ephemeral update key
  and archive signature; retain the per-run server and payload directories.

## Verification

- `make verify` includes offline publication tests: fixed identities/paths, isolated
  runs, failure preservation, running/concurrent rejection, signature/requirement
  mismatch, symlink containment and already-signed installer-host preservation.
- Build every affected native builder. Rebuild at least two representative kinds
  and compare the actual bundle IDs, launch paths and designated requirements;
  check their fixture roots and run IDs differ.
- Run the affected native checks at the stable paths. For the installer fixture,
  verify build 1 → build 2 at the stable path with separate launch PIDs, using the
  per-run loopback feed and event log.
- Computer Use's saved approvals are managed by Codex. Record whether repeated
  access reuses approval; fixed ID/path/signature alone is structural evidence.
  Initial approvals remain a user action. This workflow does not set app access
  policy, remove macOS permission prompts or prove installed Finder behavior.

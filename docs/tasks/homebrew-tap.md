# Task: Homebrew tap installation and release synchronization

Status: official FileMint tap public and distribution checks passed — isolated native acceptance pending.
Next action: Run installation, upgrade, migration, removal and Finder acceptance on a disposable Apple-silicon macOS VM or test Mac. Keep the owner’s installed FileMint untouched and enable automatic tap synchronization only after those checks.

## Objective and current scope

Provide the official FileMint-maintained [Homebrew tap](https://github.com/FileMintApp/homebrew-tap) using the existing signed, notarized release DMG, repeatable synchronization and bilingual instructions. The public command is `brew install --cask filemintapp/tap/filemint`; Homebrew resolves it and fetches the verified DMG. Submission to `homebrew/cask` is separate. Source request: [issue #4](https://github.com/FileMintApp/FileMint/issues/4).

The 2026-09-30 task was planning only. On 2026-10-13 the owner requested implementation and alignment with the latest release workflow, then confirmed no isolated VM/test Mac is available. The owner subsequently explicitly directed creation and public release of the tap. That publication proceeded after local artifact/evidence checks; it does not establish native installation, adoption, upgrade, removal or Finder behavior. Issue replies were not requested.

Selected contracts: [Distribution](../../specs/domains/distribution.md), [Updates](../../specs/domains/updates.md) and [Presentation](../../specs/domains/presentation.md). Workflow and checks: [AI Playbook](../AI_PLAYBOOK.md), [HARNESS](../../specs/HARNESS.md) and [Distribution procedure](../DISTRIBUTION.md). Before native acceptance, also load the [creation/draft](../../specs/domains/creation.md), [Finder/permission](../../specs/domains/finder-permissions.md) and affected [update verification](../../specs/verification/updates.md) rules.

## Current release contract

The implementation baseline is `project.yml` version 0.7.0 / build 28. These values are evidence context, never defaults for future updates. `release-local` creates six final assets: DMG, ZIP, each portable checksum, `appcast.xml` and `appcast-zip.xml`. `publish-local` uploads a draft, binds exact source CI and candidate verification identities, promotes that same verified draft to public Latest, then deploys the applicable retained website artifact. Homebrew synchronization follows those successful stages.

Local remote-archive downloads and remote-content comparisons remain omitted. The GitHub candidate workflow verifies remote archives, checksums, signatures, notarization tickets, resolved Sparkle entitlements and equal app code hashes. Local tooling validates existing local files and remote metadata, including published sizes and available server digest metadata; it does not dispatch substitute verification or treat an unrelated green workflow as evidence.

Main app identity remains `io.github.daigua.filemint`; Finder extension identity remains `io.github.daigua.filemint.findersync`. Cask requirements are arm64 and macOS 13 Ventura or later. FileMint supports M-series Macs; Homebrew’s arm64 condition cannot distinguish M-series from other Apple silicon. No runtime, packaging, update-key or permission behavior changes.

## File ownership and interfaces

| Path | Responsibility |
| --- | --- |
| `scripts/homebrew/filemint.rb.in` | Canonical declarative Cask; only `@VERSION@` and `@SHA256@` vary |
| `scripts/homebrew/tap/` | Bilingual README and read-only pinned validation workflow |
| `scripts/homebrew_tap.py` | Manifest/evidence validation, deterministic preparation and explicit publication |
| `scripts/test_homebrew_tap.py` | Offline validation, failure, synchronization and retry coverage |
| `scripts/release_publication.py` | Optional post-website synchronization and journal recovery |
| `Makefile` | `homebrew-prepare`, `homebrew-publish`, `verify-homebrew` and offline suite integration |
| tap `Casks/filemint.rb` | Generated version and DMG digest for one verified stable release |

The tap is a separate repository, never a nested tracked repository or submodule. It holds no binaries, appcasts, signing assets or copied application source.

```sh
python3 scripts/homebrew_tap.py prepare --manifest build/FileMint-VERSION.release.json --output-dir build/homebrew-VERSION
python3 scripts/homebrew_tap.py publish --manifest build/FileMint-VERSION.release.json
```

Equivalent Make targets use `MANIFEST=...` and, for preparation, `OUTPUT_DIR=...`. `prepare` performs read-only release queries and writes only its chosen output directory, including `Casks/filemint.rb`, the tap skeleton and `receipt.json`. It does not run brew, dispatch Actions, commit, push or install FileMint. `receipt.json` is local evidence, not a tap repository file: initial publication includes only the Cask and three skeleton files (two READMEs and one workflow). `publish` repeats validation before updating the existing tap; a receipt alone is not authority to publish. Neither mode creates a GitHub repository.

### Manifest and evidence validation

Accept the current unversioned release JSON object with exactly ten string fields:

`version`, `build`, `tag`, `commit`, `dmgSHA256`, `zipSHA256`, `certificateSHA256`, `appcastSHA256`, `zipAppcastSHA256`, `notarySubmissionID`.

Require a three-component stable version, positive decimal build, matching `vVERSION`, full commit hash, lowercase SHA-256 values and a UUID submission ID. Reject duplicate/missing/extra fields and other JSON types. Do not invent `schemaVersion` or `checksumSHA256` fields or rewrite old evidence to fit the helper.

- Resolve only expected artifact names beside the manifest. Hash both local archives and both feeds. Require each checksum to contain the matching archive hash, two spaces, exact basename and one final LF; reject paths, other names and extra lines.
- Reuse the existing local release verifier for signatures, certificate, notarization, architecture, entitlements, feeds and paired archive validation. A submission ID alone is not notarization proof.
- Match the manifest tag to local and remote source commits, including annotated-tag peeling. Tooling may be newer than the release source; do not require the helper’s HEAD to be the release tag.
- Require the matching publication journal, public stable Release and Latest identity, exact six recorded assets, exact successful source CI and exact dispatched draft-candidate workflow run/attempt. Preserve release ID, commit, tag, build and asset/request/run bindings. Changed or missing evidence fails closed.
- Require successful applicable website deployment before synchronization. Missing journal, run, artifact metadata or local files is a blocker, not permission to reconstruct success or republish an existing version.
- Do not download release assets locally or dispatch a fresh workflow from either mode. GitHub Actions remains responsible for remote artifact checks.

### Cask and user-data policy

The Cask pins version, SHA-256 and the immutable `vVERSION/FileMint-VERSION.dmg` URL, declares `auto_updates true`, installs only `FileMint.app`, and requires `arch: :arm64` and `macos: :ventura`. `livecheck` uses GitHub Latest and matches only an exact three-component `tag_name`; draft-era tags and release titles do not determine availability. Livecheck discovers versions; it does not replace release verification.

There are no installer scripts, process-management hooks, `quit:`, `signal:`, `zap`, quarantine bypasses, silent launches or Finder activation. The Cask and READMEs require saving/cancelling drafts, finishing creation/import/file/Sparkle operations, manually quitting and confirming exit before replacement, adoption or removal. Homebrew does not enforce that prerequisite; refused Quit is not an interlock against an external installer. Never force termination or run Sparkle and brew installation concurrently.

Local Homebrew inspection on 2026-10-13 found 6.0.11, revision `6bd951d96e7ebc54787799dba77bfb26ec956c4c`: default upgrades can compare actual single-app bundle versions for `auto_updates` Casks, while named upgrades use greedy selection. Current [Homebrew FAQ](https://docs.brew.sh/FAQ#how-does-brew-upgrade-handle-apps-that-update-themselves) and [manual](https://docs.brew.sh/Manpage#upgrade-options-installed_formulainstalled_cask-) describe that comparison. Do not claim all ordinary bulk upgrades skip FileMint. Older brew versions or environment settings may skip it. Retain a newer installed app while the tap catches up; named/greedy/reinstall commands are not general repairs. This is source/documentation evidence, not an installed-app test.

Normal removal retains preferences, imported templates, folder bookmarks, legacy containers and every user-created file. Reinstallation should reuse them, but macOS authorization usability needs runtime proof. Existing manual installations continue through their current path; adoption instructions stay unpublished until native acceptance. No forced overwrite, automatic removal or duplicate installation workaround.

### Synchronization, ordering and retries

1. Validate local artifacts and complete release evidence, then render deterministically. Parse existing Cask versions without evaluating remote Ruby; accept only the exact known layout.
2. Use existing local GitHub authentication and an owned temporary clone of the intended tap. Require `main`, expected remote and known layout. A missing repository fails clearly; no cross-repository PAT, Apple secret or repository creation is added.
3. Reject downgrades and a different digest for the same version. An identical verified Cask is an idempotent no-op. Do not overwrite unexpected edits or reset another writer’s work.
4. Validate the candidate with supported Homebrew tooling, recheck release/branch evidence, commit only the allowed Cask update and push normally to `main`. Never force-push or bypass protection.
5. Read back the remote commit and Cask. Reconcile ambiguous pushes before retrying; concurrent updates stop. Report tap version/commit only after verified readback.

The release hook is disabled by default. After initial native acceptance and explicit tap publication, opt in with `FILEMINT_HOMEBREW_SYNC=1 make publish-local`. The journal persists the request so an interrupted run cannot silently skip it. Application publication and applicable website deployment finish before tap synchronization; the journal saves their completion before entering the tap stage.

A tap failure reports `App release published and verified; Homebrew synchronization failed`, preserves all six public assets and records failure. Retry using the manifest-based helper or resume `publish-local`; completed application/website stages are not reuploaded, rebuilt, re-signed or redeployed. `release-local`, development builds and ordinary verification never publish a tap.

Initial bootstrap used the latest stable release’s verified local manifest/files and matching publication journal. Future recoveries require genuine retained evidence; do not manufacture a journal, reuse unrelated workflows or rebuild/re-sign public bytes. The public tap now contains the reviewed Cask and bilingual instructions. The release hook cannot bootstrap a missing repository and remains opt-in until isolated native acceptance.

## Automated verification and evidence

Run `make verify` after implementation because release/test infrastructure changes; run the website build for changed README includes. Homebrew 6.0.11 no longer accepts filesystem paths for audit/livecheck and requires a registered tap for readall. Tooling validation therefore snapshots the canonical Cask into an owned temporary Git directory, registers one uniquely named `filemint-validation/check-UUID` metadata tap through a local custom remote, then runs named style/info/readall/online metadata audit/livecheck checks sequentially. Finally it removes only that owned tap. It never installs FileMint or changes an existing tap. These are automated tooling checks, not isolated native installation QA. Read-only `prepare` does not run brew.

Local audit uses `brew audit --cask --online --strict --except=download,signing,rosetta,min_os,missing_verified,unnecessary_verified`. Homebrew's online mode otherwise implicitly downloads the payload; excluding the four payload-dependent checks preserves the release helper's no-local-remote-download contract. Local Homebrew 6.0.11 also expects a `verified` URL parameter that current Homebrew rejects; the two URL-parameter exclusions keep one canonical current Cask. The existing `verify_release_pair.sh` checks the retained local release artifacts, including signatures, architecture and minimum OS, before synchronization. The tap CI workflow retains complete online audit, including payload download and checks on the disposable runner. It uses a local custom remote, pins checkout, has only `contents: read`, disables persisted credentials, and never installs FileMint or handles Apple keys. Neither local metadata audit nor full CI payload audit proves native installation or Finder behavior.

| Area | Required automated coverage |
| --- | --- |
| Generation | Stable numeric versions, exact tag/URL/hash, deterministic rendering, injection rejection and no process/data-removal hooks |
| Manifest/files | Exact ten-string schema, duplicate/type errors, both archives/feeds/certificate/checksum mismatches and missing artifacts |
| Release evidence | Draft/prerelease/not-Latest, source/tag mismatch, missing/extra/changed assets, wrong or failed source/candidate run/attempt, website not complete |
| Synchronization | Preparation, newer version, no-op, downgrade/same-version mutation, unknown layout, auth/network/audit failure, concurrent push and ambiguous readback/retry |
| Release integration | Existing gate failures prevent sync; opt-in persists; successful website/app work survives tap failure and is not repeated |
| Homebrew | Temporary metadata-tap style/DSL/readall/livecheck and local online audit excluding `download,signing,rosetta,min_os`; existing local pair verification covers payload constraints. Actions retains full online payload audit. Network/tooling failures are recorded, never reported as success |
| Documentation | Context/local links, public availability and matching bilingual upgrade/data-retention guidance |

| Check | Status | Evidence |
| --- | --- | --- |
| Release contract refresh | passed (source inspection) | `project.yml` 0.7.0/build 28; six-asset `release-local` and exact-candidate `release_publication.py`, 2026-10-13 |
| Homebrew upgrade semantics | passed (source/documentation inspection) | Homebrew 6.0.11 revision above; no installation or upgrade executed |
| Documentation links and whitespace | passed | `make verify-context`: 22 documents and 123 local links; `git diff --check` passed. Source docs are local until Git delivery; this is not native verification |
| Complete offline suite | passed | `make verify` on the modified primary checkout based on `74cabf8`, after the public Cask syntax fix: 235 Swift tests, 45 publication tests and 45 Homebrew tests plus existing Harness/script checks. Log: `build/homebrew-published-fix-verify.log` |
| Release build | passed | `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build`; unsigned Release build only, no installation. Log: `build/homebrew-release-build.log` |
| Website | passed | `SITE_BASE=/FileMint/ pnpm run site:build`; generated bilingual homepages reflect the now-public tap and pending native acceptance. Log: `build/homebrew-public-site-build.log`; no website deployment |
| Real stable-release preparation | passed | `prepare --manifest build/FileMint-0.7.0.release.json --output-dir build/homebrew-0.7.0-published-fix.noindex`; existing signed/notarized DMG and ZIP verified, six public asset identities matched. Final generated Cask SHA-256: `7a5c6c5d1eed0aca6eb358f39a136e15063f4c02d3a60485f0518162f2db6f51`. Log: `build/homebrew-published-fix-prepare.log`; receipt stayed local |
| Complete publication evidence | passed (read-only) | `validate_release(..., require_complete=True)` against retained 0.7.0/build 28/source `318ee90f217b4c254c23d1a78553b79047afa118`; exact CI `38197755992`, candidate `38197905786`, site `38197960081`, deploy `38198021071`, all attempt 1. Evidence: `build/homebrew-publication-validation.json`; no workflow dispatched |
| Homebrew tooling | passed | Homebrew 6.0.11: style, `readall --os=all --arch=all`, exact info metadata, online metadata audit with the documented payload and obsolete-URL exclusions, and livecheck. Unique local metadata tap removed and absence confirmed. Log: `build/homebrew-published-fix-audit.log`; no app installed |
| Isolated native acceptance | blocked | Owner confirmed no disposable VM/test Mac, then explicitly requested public tap delivery; actual installation, upgrade, migration, removal and Finder behavior remain unverified |
| Initial tap publication / remote tap CI | passed | [FileMintApp/homebrew-tap](https://github.com/FileMintApp/homebrew-tap) public `main` at `f40fb29a95f358ac0553b555cc1b6b531ff34263`; exactly Cask, two READMEs and pinned read-only workflow. [Run 38353161205](https://github.com/FileMintApp/homebrew-tap/actions/runs/38353161205) succeeded after fixing the `verified` field rejected by current Homebrew; first run 38352783862 failed on that field. No release assets were repackaged. |
| Public command resolution and checksum fetch | passed (distribution only) | `brew install --cask --dry-run filemintapp/tap/filemint` resolved and planned one Cask; `brew fetch --cask filemintapp/tap/filemint` downloaded and verified 0.7.0. Logs: `build/homebrew-public-install-dry-run.log`, `build/homebrew-public-fetch.log`. No app was installed or replaced. |
| Existing version synchronization | passed (no-op) | `python3 scripts/homebrew_tap.py publish --manifest build/FileMint-0.7.0.release.json` validated the public tap and returned `unchanged` with the current tap commit. Log: `build/homebrew-public-sync-noop.log`. The opt-in release hook remains disabled pending native acceptance. |

## Native acceptance and completion gates

Use a disposable Apple-silicon macOS VM or dedicated test Mac with separate Homebrew prefix/Caskroom, Applications, home and Finder/LaunchServices state. A temporary account or `--appdir` on the working Mac is insufficient. Do not mount host app, brew or data directories. Transfer only reviewed artifacts and synthetic fixtures. Record resolved paths and bundle identities inside the isolated system before operations; stop on unexpected/shared state.

| Scenario | Required result |
| --- | --- |
| Fresh installation | Public command, Gatekeeper launch, version/build, extension/folder onboarding and real Finder creation |
| Requirements | arm64/macOS constraints; real minimum-OS runtime evidence separate from configuration parsing |
| Upgrade | Two signed published versions; exited app; retained settings/templates/bookmarks, refreshed Finder extension and successful creation |
| Sparkle coexistence | In-app upgrade then brew; app newer than tap; named/greedy/reinstall outcomes characterized without recommending downgrades |
| Manual migration | Same-version adoption, older/newer manual installs and wrong-identity conflicts; rejection preserves app/data |
| Removal/reinstall | Managed app removed, data retained, extension/menu lifecycle observed, settings and creation restored after reinstall |
| Running-app negative cases | Edited draft, active writes/imports and refused Quit; record whether brew continues, process/draft/bundle/file outcomes. Candidate-induced quit, draft loss or interrupted/corrupted writes block publication; zero exit is not proof of safe running-app replacement |

- [x] Code and applicable automated checks complete, with observed results recorded.
- [ ] Isolated install/upgrade/migration/removal and running-app negative cases have evidence.
- [x] Initial tap published with reviewed Cask and current bilingual availability text.
- [ ] Public installation and tap workflow verified from the isolated environment.
- [ ] README/install/website claims updated only after delivery; roadmap remains open until then.
- [ ] Release opt-in and recovery exercised against the intended tap; no app-asset mutation.

Do not mark the overall task complete solely because local checks pass. Publication, native runtime acceptance and any issue message remain separate deliverables.

## Primary references

- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew livecheck and GitHub Latest](https://docs.brew.sh/Brew-Livecheck#githublatest-strategy-block)
- [Homebrew manual](https://docs.brew.sh/Manpage)
- [Homebrew self-updating app FAQ](https://docs.brew.sh/FAQ#how-does-brew-upgrade-handle-apps-that-update-themselves)

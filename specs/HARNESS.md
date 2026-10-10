# FileMint Harness

The Harness is the executable contract between SPEC and implementation.
Read this matrix when planning or performing verification. Open only the detailed
checklist for the changed surface; do not preload all checklists at task start.

## Choose checks by change

Choose by the current task's intent and actual edits, not the code mentioned in
a plan or the domains read. Reading SPEC/HARNESS, starting a task, writing a plan
or changing a future requirement does not itself trigger `make verify`.
By default, run applicable tests after completing the relevant code, logic or
runtime-flow change. There is no mandatory pre-change baseline. Run a targeted
pre-change test only to reproduce a defect, investigate an existing failure or
fulfill an explicit request, and state that purpose before running it.
For an explicit verification request or a diagnosis requiring execution, run the
requested or smallest relevant check and state why it is needed. Do not expand
a generic review/check request into the full suite automatically.

| Changed surface | Automated checks | Additional evidence / load when needed |
| --- | --- | --- |
| Read-only questions, analysis, review or planning | None by default | Inspect relevant source/contracts; distinguish static findings from runtime evidence. |
| Documentation only: context routing, domain docs, agent workflow, roadmap or task plans | `make verify-context` for context-document changes; otherwise inspect changed text and local links | Check representative routes when routing changes; preserve product rules. No Swift tests, app build or full `make verify` solely for these edits. Published site content follows the website row. |
| Executable test infrastructure, Harness code/cases, verification scripts or Makefile verification targets | `make verify` after implementation | [Core checks and case format](verification/core.md) when Harness behavior changes. Editing instructions about tests is documentation only. |
| Core rules, names, templates, preferences, tickets | `make verify` after implementation | [Core checks and case format](verification/core.md); native QA for changed UI interactions. |
| App, SharedUI, Finder, login, windows or authorization | `make verify`; unsigned `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | [Finder/native checks](verification/finder.md), only affected scenarios. A build is not runtime proof. |
| About or updater | `make verify`; unsigned app build for app-code changes | [Update checks](verification/updates.md); network smoke for client changes, sandbox flow for save/download/open changes, native scheduling checks for timer/cancellation changes. |
| Website, site dependencies, README includes | `SITE_BASE=/FileMint/ pnpm run site:build` | Inspect affected pages and base-path links. Build success is not live deployment. |
| Native appearance or icon assets | Unsigned app build; `make icon` only when icon sources change | Inspect affected native surfaces. Core tests are also needed when behavior changes. |
| Build, packaging, signing or release | `make verify`; Release build and applicable artifact checks | [Distribution procedure](../docs/DISTRIBUTION.md), [Finder QA distribution checks](../docs/FINDER_QA.md#distribution). Publication remains a separate action. |

The existing `make verify` runs context and compression-artifact checks, Swift tests and the public JSON
harness plus real CLI regression, appcast and signing-entitlement preparation tests.
It stays offline and does not build the app/extension or website.
PR and main-branch CI invoke that same command independently on arm64 macOS 15
and macOS 26. Both jobs must pass the stable `Verify core behavior` aggregate
check. Runner/toolchain versions are recorded in each job; additional checks in
this table are not implied by a green CI run. In particular, the matrix does not
exercise macOS 13/14 or installed Finder/UI behavior. Swift tests and the JSON
CLI share the JSON cases; those cases are not independent coverage counted twice.

The hosted matrix uses explicit stable OS labels. GitHub has retired the
[macOS 13 images](https://github.com/actions/runner-images/issues/13046), and
[macOS 14 is in scheduled brownouts before retirement on 2026-11-02](https://github.com/actions/runner-images/issues/13518).
Older supported systems need separate runtime checks; setting a deployment
target of macOS 13 does not replace running on macOS 13.

Compression artifact checks validate the local source/archive hashes, framework
ABI, arm64/macOS 13 target and system-only load paths. They do not rebuild the
third-party runtime or access the network. Encoding behavior is covered by the
image tests; native UI, sandbox and macOS 13 runtime evidence remain separate.

`make verify-context` checks local context-document links, anchors and the size
budget of `AGENTS.md` plus the SPEC index. It cannot prove that an agent loaded
the right rules or that tests cover the meaning of a contract.

## Local verification permissions

Use the execution permissions already known to be necessary for a selected
standard check on its first invocation. In this macOS Codex environment,
`make verify` has a confirmed SwiftPM `sandbox-exec` startup restriction: request
the tool's command-scoped escalation directly, reusing applicable approval.
Do not repeat a known-failing sandbox attempt or ask the user to reconfirm an
already authorized verification. The active tool and platform approval policy
still applies; report an approval denial rather than bypassing it.

Keep this permission choice scoped to the current FileMint checkout and the
required verification command. Review changes to its Makefile recipe, invoked
scripts, package build steps and dependencies before execution; a familiar
command name does not make changed code trusted. Use ordinary sandbox permissions
where sufficient, including documentation checks. This rule grants no blanket
shell access, `sudo`, installation or publication, and changes neither the checks
nor FileMint's runtime sandbox entitlements or system security settings.

## Native QA application identity

- Each native GUI QA kind has a fixed bundle identifier, a fixed launch path under
  `build/native-qa.noindex`, and a stable Developer ID designated requirement.
  Reuse existing fixture identifiers where they were already stable. Each kind
  keeps its own identity; never use the production FileMint identity as a fixture.
- Build and sign in a fresh per-run staging directory, then publish only the
  completed verified application to its stable QA path. Refuse replacement while
  that kind or its receiver is running, or another publisher owns its lock.
  Build/signing failures preserve the last good QA app. Do not force-quit apps.
- Keep fixture files, preferences, pending work and sandbox event logs separate
  for each run. Retain sandbox and entitlement behavior; do not broaden folder
  grants, clear privacy databases or write the user's FileMint stores.
- QA signing uses the existing local Developer ID certificate, or an explicitly
  selected `FILEMINT_QA_CODESIGN_IDENTITY`. Reject ad-hoc signing for a persistent
  identity and reject an unrequested change of the pinned signing requirement.
  QA builds never publish releases or export signing keys to CI.
- Stable QA identity supports saved Computer Use approvals; it does not create
  them. Initial migration may require one approval per kind. Verify approval reuse
  through actual repeated access before claiming it. Never modify Codex approval
  stores or substitute blanket shell/computer access.
- The explicitly requested access-migration prototype is a separate QA kind:
  its build 27 host is sandboxed and build 28 host is not; both Finder extensions
  remain sandboxed. It never changes production entitlements or uses production
  stores. Full Disk Access is granted only by the user in System Settings.
- Detailed workflow and verification: [Native QA](verification/native-qa.md).

## Completion evidence

- Matching product behavior exists in the owning [domain SPEC](SPEC.md).
  Intentional changes update that contract first; defect fixes preserve it.
- New or changed behavior has appropriate Harness/unit coverage. Naming,
  templates, creation and preferences require Core coverage; documentation moves
  preserve rules and links without manufacturing product tests.
- Checks selected from the matrix pass after implementation. Run `make verify`
  only where the applicable row requires it; no baseline run is required. Analysis and
  documentation-only work do not inherit implementation completion gates.
  If a required toolchain is unavailable, record the command and blocking reason.
- Run all applicable rows above, including build/native/artifact checks when
  those surfaces change. A missing environment does not turn a check into a pass.
- Report checks as `passed`, `failed`, `not-run` or `blocked`, with the tested
  revision/worktree, command, environment and result. Keep logs outside the
  default context and link them from the task or relevant acceptance entry.
- Record Finder/runtime limitations honestly in the relevant task and
  [acceptance history](../docs/ACCEPTANCE.md) when adding native evidence. Historical
  observations do not validate new changes. Follow the [handoff workflow](../docs/AI_PLAYBOOK.md)
  for work that must continue in another session.

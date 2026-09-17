# FileMint Harness

The Harness is the executable contract between SPEC and implementation.
Read this matrix when planning or performing verification. Open only the detailed
checklist for the changed surface; do not preload all checklists at task start.

## Choose checks by change

| Changed surface | Automated checks | Additional evidence / load when needed |
| --- | --- | --- |
| Context routing, domain docs, agent workflow | `make verify-context`; `make verify` after implementation | Check representative task routes; product rules must survive documentation moves. |
| Core rules, names, templates, preferences, tickets | `make verify` before and after behavior changes | [Core checks and case format](verification/core.md); native QA for changed UI interactions. |
| App, SharedUI, Finder, login, windows or authorization | `make verify`; unsigned `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | [Finder/native checks](verification/finder.md), only affected scenarios. A build is not runtime proof. |
| About or updater | `make verify`; unsigned app build for app-code changes | [Update checks](verification/updates.md); network smoke for client changes, sandbox flow for save/download/open changes, native scheduling checks for timer/cancellation changes. |
| Website, site dependencies, README includes | `SITE_BASE=/FileMint/ pnpm run site:build` | Inspect affected pages and base-path links. Build success is not live deployment. |
| Native appearance or icon assets | Unsigned app build; `make icon` only when icon sources change | Inspect affected native surfaces. Core tests are also needed when behavior changes. |
| Build, packaging, signing or release | `make verify`; Release build and applicable artifact checks | [Distribution procedure](../docs/DISTRIBUTION.md), [Finder QA distribution checks](../docs/FINDER_QA.md#distribution). Publication remains a separate action. |

The existing `make verify` runs context checks, Swift tests and the public JSON
harness plus real CLI regression. It stays offline and does not build the app/extension or website.
PR CI invokes that same command; additional checks in this table are not implied
by a green Core test run. Swift tests and the JSON CLI share the JSON cases;
those cases are not independent coverage counted twice.

`make verify-context` checks local context-document links, anchors and the size
budget of `AGENTS.md` plus the SPEC index. It cannot prove that an agent loaded
the right rules or that tests cover the meaning of a contract.

## Completion evidence

- Matching product behavior exists in the owning [domain SPEC](SPEC.md).
  Intentional changes update that contract first; defect fixes preserve it.
- New or changed behavior has appropriate Harness/unit coverage. Naming,
  templates, creation and preferences require Core coverage; documentation moves
  preserve rules and links without manufacturing product tests.
- `make verify` passes after implementation; behavior changes also have a baseline
  run. If the toolchain is unavailable, record the command and blocking reason.
- Run all applicable rows above, including build/native/artifact checks when
  those surfaces change. A missing environment does not turn a check into a pass.
- Report checks as `passed`, `failed`, `not-run` or `blocked`, with the tested
  revision/worktree, command, environment and result. Keep logs outside the
  default context and link them from the task or relevant acceptance entry.
- Record Finder/runtime limitations honestly in the relevant task and
  [acceptance history](../docs/ACCEPTANCE.md) when adding native evidence. Historical
  observations do not validate new changes. Follow the [handoff workflow](../docs/AI_PLAYBOOK.md)
  for work that must continue in another session.

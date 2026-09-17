# Task: Demand-loaded project context

Status: complete
Next action: Use the compact SPEC router for the next task; no migration work remains.

## Objective and scope

- Make a fresh agent read a small entry and only the contracts relevant to its task.
- Keep current product behavior, Swift code and existing runtime checks intact.
- Split product/verification details, establish path-and-behavior routing, and
  preserve concise continuation records. No framework installation or publication.
- Completion requires valid links, preserved product rules, representative route
  review and passing existing offline verification.

## Selected context

- [SPEC router](../../specs/SPEC.md) and all domains for this one-time migration.
- [AI Playbook](../AI_PLAYBOOK.md) for workflow rules and handoff.
- [HARNESS](../../specs/HARNESS.md) for verification.
- Source changes: `AGENTS.md`, specs, development/playbook docs, `Makefile`,
  `scripts/verify_context.py`. No app, Finder or Core behavior is changed.

## Decisions and progress

- Keep product contracts in seven domain files; use the existing SPEC path as
  the compact router so links to the SPEC continue to work.
- Defer three detailed verification guides until the corresponding surface is
  being verified. Shared files route by the behavior being edited.
- Keep history and task records out of default loading. A framework adapter can
  reference these same files later; no duplicate source of product truth.
- Add an offline link/anchor/discoverability check and a 7,000-byte entry budget
  to the existing verification command. The budget is bytes, not model tokens.

## Evidence

Tested base: `2d67ea7`; implementation is the uncommitted context-workflow diff.
Environment: local macOS, Swift from `/Applications/Xcode.app/Contents/Developer`.

| Check / command | Status | Observed result |
| --- | --- | --- |
| Baseline `make verify` | passed | 60 Swift tests in 5 suites; 5 JSON cases. |
| Product contract preservation | passed | All 74 original product bullets occur verbatim exactly once across the domain files. |
| `make verify-context` | passed | 17 context documents and 84 local links; entry 5,763 of 7,000 UTF-8 bytes. |
| Checker failure probes | passed | Seven isolated probes: valid navigation from another working directory, missing link, missing anchor, unindexed domain, oversized entry, fenced examples, missing index. |
| Representative task routes | passed | Static walkthrough of the five cases below; not an independent agent benchmark. |
| Final `make verify` | passed | Context checks, 60 Swift tests in 5 suites and all 5 JSON cases passed on 2026-09-17. |
| Change scope / diff integrity | passed | 20 workflow/documentation files; no App, Core, SharedUI or Finder source edits; `git diff --check` passed. |

## Handoff

- Remaining work: none for this context-loading migration; changes are uncommitted.
- No native runtime validation is claimed for this documentation/workflow change.
- Previously identified product-Harness/CI improvements remain separate work.

## Routing walkthrough

| Task | Initial domain | Expand only if needed | Verification context |
| --- | --- | --- | --- |
| Website copy | Presentation | Domain of a feature claim; distribution for release claims | Website row; no default Finder/update history. |
| Filename suffix fix | Creation | Templates if selection or saved types change | Core; native creation if interaction changes. |
| Automatic-update cooldown | Updates | Startup if persistent defaults/migration change | Core/update checks; scheduling QA, no default signing history. |
| Finder observation scope | Finder/permissions | Creation if captured destinations change; startup for home-default migration | Core and affected Finder QA. |
| A template preference in shared `Preferences.swift` | Templates | Startup for migration; creation if rendered output changes | Core; native settings if UI changes. No unrelated updater contract. |

Before this change, the mandatory entry documents totaled 28,573 UTF-8 bytes
(`AGENTS.md`, full SPEC and full HARNESS). The new startup entry is approximately
5.8 KB (`AGENTS.md` and SPEC router); task-specific documents are additional.
This is a repository text-size comparison, not measured model token usage.

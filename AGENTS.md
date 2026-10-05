# FileMint Agent Guide

Use SPEC-first, demand-loaded context.

1. Read [SPEC](specs/SPEC.md), the compact product overview and task router.
2. Match the task's behavior and affected paths to its rows. Read only the selected
   domain contracts before editing; add domains when scope crosses a boundary.
   Shared files require the rules for the behavior being edited, not every domain.
3. Read [HARNESS](specs/HARNESS.md) when choosing or running verification; load
   detailed checklists only for the affected surfaces.
4. Read [AI Playbook](docs/AI_PLAYBOOK.md) for cross-domain work, handoff, resume
   or workflow edits.
5. Do not preload domain/history/roadmap/research/archive/tool files; follow links
   only when needed.

For “构建发布”, follow [Distribution](docs/DISTRIBUTION.md) through remote checks.

Keep these invariants across all tasks:

- Work in the primary checkout; use worktrees only when the user requests one.
- Update the owning domain SPEC before intentional product behavior changes;
  bug fixes restore the existing contract. Add regression coverage for behavior.
- Choose checks by task intent and actual changes using HARNESS. Analysis/planning
  needs no tests; docs-only edits use documentation checks. Test completed
  implementation; pre-change tests need a diagnostic reason or explicit request.
  Report blocked applicable checks.
- Keep deterministic rules in `CorePackage`, Finder APIs in `FinderSyncExtension`,
  SwiftUI settings in `App/FileMint`, and native creation UI in `SharedUI`.
- Preserve user files, preferences and authorization boundaries. No folder crawling,
  clipboard monitoring, path/content logging or unrequested publication.
- Edit `project.yml`, then `make project`; never edit generated `FileMint.xcodeproj`.
- Do not add package dependencies without a SPEC rationale. Report observed
  verification separately from assumptions and old evidence.

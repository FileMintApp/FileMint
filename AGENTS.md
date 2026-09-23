# FileMint Agent Guide

Use SPEC-first, demand-loaded context.

1. Read [SPEC](specs/SPEC.md), the compact product overview and task router.
2. Match the task's behavior and affected paths to its rows. Read only the selected
   domain contracts before editing; add domains when scope crosses a boundary.
   Shared files require the rules for the behavior being edited, not every domain.
3. Read [HARNESS](specs/HARNESS.md) when choosing or running verification; load
   detailed checklists only for the affected surfaces.
4. Load [AI Playbook](docs/AI_PLAYBOOK.md) only for cross-domain features, handoff,
   resuming a task or changing this workflow. Small fixes need no task document.
5. Do not preload domain, history, roadmap, research, archive or tool files.
   Follow links only when the task needs them.

For “构建发布”, follow [Distribution](docs/DISTRIBUTION.md) through remote checks.

Keep these invariants across all tasks:

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

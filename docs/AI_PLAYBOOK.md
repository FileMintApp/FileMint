# AI Playbook

Load this file for cross-domain features, resuming/handoff or changes to the agent
workflow. Ordinary fixes use the [SPEC router](../specs/SPEC.md) directly.

## Context loading contract

1. Start with `AGENTS.md` and the compact SPEC index. Classify intent and affected
   paths, then read only the matching domain contracts and relevant source.
2. Before editing, identify the selected domains in a short progress note or task
   record. Shared files are routed by changed behavior. If an implementation step
   adds another domain, load that contract before crossing the boundary.
3. Read the [verification matrix](../specs/HARNESS.md) to plan checks; defer detailed
   QA instructions until their surface is relevant. Implementation and review can
   use different context subsets, both linked to the same product rules.
4. Search historical evidence only for a specific decision, regression or version.
   Read the matching section, not all of ACCEPTANCE, research, roadmaps or archives.
5. Reuse context already read in the current session unless it changed or was lost.
   A link is a pointer, not a recursive dependency. Never concatenate `specs/**`
   or an entire task directory into the startup prompt.

This is a repository reading protocol, not a tool-specific automatic injection
hook. Agent tools still follow the entry instructions and open selected files.
Already-read text is not evicted; keep handoffs short so a fresh session starts
from the current task rather than replaying a transcript.

## Task size and continuation

- A bounded fix needs no PRD, task folder or extra approval ceremony. Read its
  contract, change the relevant files and run the applicable checks.
- For cross-domain features, migrations or work spanning sessions, create one
  `docs/tasks/<task-name>.md` using the [task template](tasks/TEMPLATE.md). Record
  scope, selected context, decisions, progress and verification. Keep the current
  next step at the top. Do not create a second task system for the same work.
- On resume, read only the named active task first, check actual worktree state,
  then load its current domain links. If no task is named, list task filenames and
  statuses to identify it; do not preload every record or archived task.
- A handoff includes the objective, current state, decisions, next action, relevant
  paths and evidence links. Never copy whole SPEC sections, tool logs or secrets.
- Keep past outcomes attached to the revision/environment that produced them.
  A previous pass is not a current pass. Preserve unresolved native checks.

## Implementation and review

- Update the owning domain contract before intentional behavior changes. Fixes
  restore the existing contract; do not weaken expectations to fit defective code.
- Use [HARNESS](../specs/HARNESS.md) for baseline and completion checks. Run
  `make doctor` only for environment diagnosis; it is not a test result.
- Preserve the architecture boundaries in [AGENTS](../AGENTS.md). Prefer small
  stable structs and explicit dependencies over hidden global state.
- Review changed paths against the router again before completion. Add any missed
  domain/check, and report observed results separately from unavailable checks.
- Product rules live in `specs/domains/`; planned ideas in [ROADMAP](ROADMAP.md);
  task decisions in their task; historical native evidence in [ACCEPTANCE](ACCEPTANCE.md).
  `specs/ROADMAP.md` is a legacy pointer, not a second active roadmap.

## Maintaining this workflow

- Keep the default `AGENTS.md` + SPEC index within 7,000 UTF-8 bytes, checked by
  `make verify-context`. This budget measures repository entry text, not model
  tokens, global instructions or the total context of a particular task.
- Put domain detail and long verification procedures behind specific links.
  New topics need a discoverable router entry and valid verification links.
- A future Trellis or other adapter should reference these existing contracts,
  select implementation/review context per task, and preserve the small-task path.
  Do not initialize a framework or add automatic hooks as a side effect of a
  feature task. Shared configuration and personal state need explicit separation.
- Validate at least website copy, naming, updates, Finder permissions and shared
  preferences routing after changing the index. Check that cross-domain work adds
  context while unrelated history stays unloaded.

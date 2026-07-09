# Process Maintenance Mode

## Purpose

Improve this reusable workflow repository itself.

Use this mode to apply workflow feedback, clarify instructions, adjust stages or templates, update process defaults, or fix contradictions in process documentation.

## When to Use

Use this mode only when the owner explicitly asks to change the workflow process, for example:

- "Apply the feedback file to the workflow."
- "Update the process repository."
- "Change how this stage works for future projects."
- "Fix the instructions so future agents behave differently."

Do not use this mode merely because a feedback entry exists. During mod development, feedback entries are evidence for later process work, not approval to edit versioned process files.

## Entry Conditions

- The owner has explicitly requested process-repository changes.
- The agent has stated that the session is switching out of mod-development work and into Process Maintenance mode.
- The outer process repository status has been inspected.
- Any active mod-development work is complete, paused, or summarized well enough to avoid losing state.

## Required Inputs

- `AGENTS.md`
- `guidelines/process-control.md`
- `guidelines/collaboration-guidelines.md`
- `workspace/documentation/workflow-feedback.md`, when the task is feedback-driven and the file exists
- The process files affected by the requested change

## AI Behavior

- Treat the outer process repository as the active repository.
- Keep the task scoped to process materials unless the owner explicitly expands it.
- Preserve the Minecraft 1.12.2 boundary unless the requested change is a rejected or deferred note about future process scope.
- Evaluate feedback before applying it. Feedback can be valid, invalid, obsolete, too project-specific, or already resolved.
- Prefer small, direct process edits over broad rewrites.
- Update cross-references when a stage, workflow, template, or guideline changes responsibility.
- Do not modify nested mod repositories under `workspace/project/`.
- Do not commit or push without explicit owner authorization.

## Sequence

1. Inspect the outer process repository status.
2. Read the required inputs.
3. Identify the requested process changes and the files that own those responsibilities.
4. Apply focused edits to versioned process files.
5. When the task is feedback-driven, update feedback status or summarize which entries were applied, rejected, deferred, or left untouched.
6. Run consistency checks over changed process text and cross-references.
7. Report changed files, verification, unresolved risks, and a suggested commit message when useful.

## Output

Typical outputs are process-repository edits such as:

- Updated `AGENTS.md`
- Updated `README.md`
- Updated files under `guidelines/`
- Updated reusable stages under `stages/`
- Updated workflows under `workflows/`
- Updated setup files or artifact templates under `setup/`
- Optional updates to `workspace/documentation/workflow-feedback.md`

Do not create project-specific mod artifacts as part of Process Maintenance mode.

## Completion Criteria

Process Maintenance mode is complete when:

- The requested process edits are made or explicitly rejected with rationale.
- Relevant cross-references have been checked.
- The outer process repository status is reported.
- No nested mod repository was modified unless the owner explicitly requested it.
- The owner has enough information to review, commit, or ask for revisions.

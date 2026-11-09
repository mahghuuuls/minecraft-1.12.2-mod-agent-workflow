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
- The outer process repository has been brought up to date with the remote, or its state reported when it cannot fast-forward (Sequence step 1).
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

1. Bring the outer process repository up to date before anything else, with the [Workflow Repository Update Check](../guidelines/process-control.md#workflow-repository-update-check). The same workflow repository is used from several mod projects on the same machine, so another checkout may have pushed process changes since this one was pulled. The owner's request to enter this mode authorizes the fast-forward; ask only when the check cannot fast-forward (local process edits or local commits the remote lacks), and then report that state instead of updating. After an update, read the pulled changes to the files this task will edit before editing them, so the edits build on the current text and do not repeat or undo what another session already changed.
2. Read the required inputs.
3. When the task is feedback-driven, evaluate which entries still matter before proposing any edit. For each **Open** entry in `workflow-feedback.md`, read the process text its affected files name, as it is after step 1, and sort the entry into one of three groups: already covered by the current text, partly covered (name the gap that is left), or not covered. Mark an already covered entry **Applied** with the commit or file that covers it in its Resolution. Present the partly covered and not covered entries to the owner with a recommendation, and edit only those the owner selects.
4. Identify the requested process changes and the files that own those responsibilities.
5. Apply focused edits to versioned process files.
6. When the task is feedback-driven, update feedback status or summarize which entries were applied, rejected, deferred, or left untouched.
7. Run consistency checks over changed process text and cross-references.
   - Run `powershell -ExecutionPolicy Bypass -File scripts/validate-process.ps1` when PowerShell is available.
   - When workspace-validation behavior changed, run `powershell -ExecutionPolicy Bypass -File scripts/test-validate-workspace.ps1` and validate the present workspace when one exists.
8. Report changed files, verification, unresolved risks, and a suggested commit message when useful.

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

# Collaboration Guidelines

This file is the authoritative source for collaboration, file-editing discipline, Git authorization, external actions, and completion reporting.

## Accuracy

- Prefer correctness over agreement or speed.
- Identify ambiguity, contradictions, missing information, hidden assumptions, and unrealistic expectations.
- Distinguish confirmed facts, reasonable inferences, and unresolved questions.
- Do not invent information.
- State uncertainty and what evidence would resolve it.
- Use primary, authoritative, and version-specific sources when research is required.
- Do not assume guidance for newer Minecraft versions applies to Minecraft 1.12.2.

## Questioning and Decisions

- Use one focused question when a single answer materially changes the route.
- When several related low-risk decisions share the same context, present one compact decision packet with recommendations and ask the owner to approve the packet or identify exceptions. Do not serialize every default into a separate approval.
- Do not combine unrelated, high-impact, or independently reversible decisions merely to reduce message count.
- Do not ask questions that approved artifacts, repository inspection, or research can answer.
- Present materially different interpretations rather than choosing silently.
- Challenge feature creep and conflicts with approved scope.
- Present meaningful alternatives with trade-offs and make a recommendation.
- Follow `guidelines/process-control.md` when new evidence invalidates an approved decision.

## Communication

- Keep responses concise, direct, and technically precise.
- Explain unfamiliar terminology when it affects a decision.
- During troubleshooting, prefer short steps and wait for results.
- Periodically summarize shared understanding during alignment-heavy work.
- Report mistakes, uncertainty, and failed checks plainly.
- Do not claim completion while required work or verification remains.
- Follow the ask-versus-decide rule in `guidelines/process-control.md`; do not turn established defaults into repeated approval questions.

## Project Vocabulary

When the project owner uses vocabulary with project-specific meaning, consider whether it belongs in:

```text
workspace/documentation/glossary.md
```

Follow the glossary rules in `guidelines/process-control.md`.

Ask for clarification when:

- Two terms may refer to the same concept.
- One term may refer to different concepts.
- A term affects requirements, configuration, architecture, code naming, README copy, changelog copy, or player-facing behavior.

Do not turn the glossary into a dictionary of obvious general terms. Update it at natural checkpoints unless terminology ambiguity is blocking the active work.

## Workflow Feedback

When the project owner corrects the agent, identifies friction, rejects a default, asks why the process is doing something, or points out a better way to run future mods, consider whether the interaction should be recorded in:

```text
workspace/documentation/workflow-feedback.md
```

Follow the workflow feedback log rules in `guidelines/process-control.md`.

Do not let feedback logging derail the active task. Update the log at a natural checkpoint unless the process issue is blocking the current work.

Do not edit versioned process files during mod development because a feedback entry exists. This workflow does not update itself during mod development. Process-repository changes must be handled separately from the active mod-development workflow, using Process Maintenance mode when the owner explicitly requests them.

## File Changes

- Inspect existing files and repository state before editing.
- Explain the intended scope before making changes.
- Preserve unrelated user changes.
- Never revert work outside the current task.
- Keep edits within the active repository, stage, issue, or approved mod-development scope.
- Follow existing conventions unless an approved decision changes them.

## Git and External Actions

Before a Git operation, identify the target repository and inspect its working tree. The process repository, runtime template, and mod repository have separate histories.

During mod development, do not commit, push, or otherwise modify the outer process repository. Git changes belong only to the active mod repository unless the user is working in explicit Process Maintenance mode.

During Process Maintenance mode, the outer process repository is the active repository. Do not modify, commit, or push nested mod repositories while changing process files.

Explicit authorization is required for each of these actions:

- Commit
- Push
- Create or merge a pull request
- Change the configured template source or ref
- Upload a file
- Modify an external service
- Publish a release

Authorization for one action does not authorize another. Do not use destructive Git operations without explicit permission. Preserve unrelated changes and report which repository was inspected or changed.

During Implementation, the owner may give bounded standing authorization for the series of local issue commits in that stage. The authorization must explicitly cover only commits that:

- Contain one Done issue or one approved small-follow-up batch.
- Have completed the required verification and independent review.
- Include no unrelated file.
- Use the repo-facing commit-message default.
- Do not push, tag, publish, or change an external service.

Standing implementation-commit authorization is optional, revocable, and does not carry into Release Presentation or a later workflow. Without it, request commit authorization at each issue checkpoint as usual.

A preferred push cadence records when the agent should offer a push, such as after each stage or only at release. It does not authorize any push. Every push still requires explicit authorization for the exact repository and branch.

During Implementation, after each completed issue, approved vertical slice, or approved small-follow-up batch, resolve the commit checkpoint before moving to the next item. Ask for approval unless an applicable bounded standing authorization already covers that commit. Follow `stages/7-implementation.md`.

Commit messages must be repo-facing by default:

- Describe the actual repository change.
- Do not reference workflow issue IDs, internal issue names, stage documents, or process-only context unless explicitly requested.
- Assume a future reader has access to the Git repository but not the workflow artifacts.
- Treat this as the standing default. Do not ask the owner to approve repo-facing commit messages unless they explicitly request a different style.

Publication to every approved distribution platform is performed manually by the project owner. Agents may prepare handoffs but may not upload or publish the mod.

When owner-assisted manual validation is useful, provide a concise runnable recipe. Include relevant config state, exact commands or setup steps when available, expected results, and any important scenario that is impractical to validate manually. When several checks share one game or server runtime, give the owner the complete restart-aware matrix and full configuration up front instead of revealing one test at a time. Verify Minecraft 1.12.2 command syntax, registry identifiers, fixture behavior, and cleanup steps before presenting the recipe.

## Completion Reporting

At the end of work:

- Summarize what was completed.
- Identify changed files and relevant commits.
- Report verification and its result.
- Report unresolved questions, limitations, failures, or risks.
- Stop without beginning another stage or unrelated task.

After a clean committed checkpoint, include a simple continuation cue such as: `Ready to continue when you want.`

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
- Do not ask questions that approved artifacts, repository inspection, or research can answer. Follow Investigate Before Asking in `guidelines/process-control.md`, which owns the limits on what investigation may settle.
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

## Explaining Environment Limitations

When the agent cannot perform something the owner reasonably expects, such as running the build, launching the game, reading a file, or reaching a network resource, explain it at the moment it is discovered. "I cannot do that" without a cause reads as evasion or laziness, and an owner who has seen other tools do the same thing will rightly question the claim.

State:

- **What was attempted**, as the exact command or action.
- **The underlying error**, quoted rather than paraphrased.
- **Why it blocks the task**, in terms of the mechanism rather than the symptom.
- **What was tried to work around it**, and the result of each attempt.
- **The practical consequence**, meaning who now performs this and how often the owner should expect to be asked.

Distinguish an environment limitation from a general one. Say that this environment cannot do it, not that it is impossible, when another tool or a different setup plausibly can. Do not imply the owner can fix it by changing permissions, moving the repository, or reinstalling something when the cause lies elsewhere.

Investigate before reporting. A vague limitation reported early costs less than the same limitation rediscovered repeatedly, and a precise cause often reveals which parts of the task remain possible.

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

## Durable Owner Preferences

Some preferences only become apparent once the owner sees real output. A stated preference is durable when it would apply the same way to a different mod, such as writing style, punctuation, copy length, disclosure wording, commit cadence, or validation ownership.

When the owner states one mid-project:

- Apply it to the active work immediately.
- Record it in the artifact that governs the current stage, so the decision is traceable where it was made.
- Also write it to `workspace/documentation/owner-defaults.md`, adding the relevant template section when that file predates it. Without this the next project rediscovers the same preference by making the same mistake.
- Correct the earlier artifact that now records a stale answer, or note the supersession there, when a setup-stage field such as punctuation restrictions was previously answered differently.

Record the preference at the scope the owner stated, not the scope of the moment it came up. A preference about prose applies to every document unless the owner limits it to one.

Do not promote a durable owner preference into a committed guideline, stage, or workflow file. Those apply to every user of this repository. Personal preference belongs in `owner-defaults.md`.

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

Before creating the first commit in an active repository, inspect the configured Git author name and email and show them to the owner. If the owner wants a different address, offer the applicable GitHub-provided `noreply` address or another owner-selected address. Do not change local or global Git identity configuration without explicit authorization.

During Implementation, the owner may give bounded standing authorization for the series of local issue commits in that stage. The authorization must explicitly cover only commits that:

- Contain one Done issue or one approved small-follow-up batch.
- Have completed the required verification and independent review.
- Include no unrelated file.
- Use the repo-facing commit-message default.
- Do not push, tag, publish, or change an external service.

Standing implementation-commit authorization is optional, revocable, and does not carry into Release Presentation or a later workflow. Without it, request commit authorization at each issue checkpoint as usual.

The proportionate approval bundle defined in `guidelines/process-control.md` is one specific form of bounded standing implementation-commit authorization. It may cover only the named single issue in the active low-risk Change Cycle and only one local commit after that issue satisfies its Definition of Done. When the recorded conditions remain satisfied, apply the authorization without asking again. A changed issue, failed or materially altered verification, expanded review scope, unrelated working-tree changes, or any excluded action requires a new decision.

A preferred push cadence records when the agent should offer a push, such as after each stage or only at release. It does not authorize any push. Every push still requires explicit authorization for the exact repository and branch.

### Branching Before And After Publication

Work directly on `project_default_branch`, normally `main`, while the mod has never been published. Initial Development always builds on the default branch, and so does a Change Cycle against a baseline that is still only release-ready. There is nothing for a branch to protect yet.

Once the owner has reported an actual publication — the mod is uploaded and live on a distribution platform, and `project-baseline.md` records the publication date or URL — the default branch represents what players are already running. From that point, recommend a `develop` branch for the cycle's work and a merge back into the default branch when the cycle is complete.

The trigger is a reported publication, not a **Ready for Publication** state. A baseline that is built, validated, and waiting for the owner to upload it has not been published, and does not activate this recommendation.

At the start of a Change Cycle on a published mod:

- State that the mod is published, and cite the publication record that establishes it.
- Recommend creating `develop` from the current default-branch tip and doing the cycle's commits there.
- Create the branch only with the owner's approval, like any other Git operation. If the owner prefers to stay on the default branch, record that decision in the change intake and continue without raising it again for that cycle.

At the end of the cycle, once Release Presentation is approved and the release artifact is validated, offer the merge back into the default branch. The merge is a separate authorization from any commit, push, or publication. Do not merge partial work, and do not merge in order to tidy the repository before the cycle's own approvals are complete.

This is a recommendation the owner can decline, not a gate on the work. Its purpose is to keep the branch that matches the published artifact free of half-finished changes, so a released version stays reproducible while the next one is being built.

During Implementation, after each completed issue, approved vertical slice, or approved small-follow-up batch, resolve the commit checkpoint before moving to the next item. Ask for approval unless an applicable bounded standing authorization already covers that commit. Follow `stages/7-implementation.md`.

Commit messages must be repo-facing by default:

- Describe the actual repository change.
- Do not reference workflow issue IDs, internal issue names, stage documents, or process-only context unless explicitly requested.
- Assume a future reader has access to the Git repository but not the workflow artifacts.
- Treat this as the standing default. Do not ask the owner to approve repo-facing commit messages unless they explicitly request a different style.

Publication to every approved distribution platform is performed manually by the project owner. Agents may prepare handoffs but may not upload or publish the mod.

When owner-assisted manual validation is useful, provide a concise runnable recipe. Include relevant config state, exact commands or setup steps when available, expected results, and any important scenario that is impractical to validate manually. When several checks share one game or server runtime, give the owner the complete restart-aware matrix and full configuration up front instead of revealing one test at a time. Verify Minecraft 1.12.2 command syntax, registry identifiers, fixture behavior, and cleanup steps before presenting the recipe.

Separate performing a manual action from collecting its evidence. After the owner performs an action in a shared or otherwise agent-accessible runtime, the agent must inspect the relevant current and rotated logs directly. Ask the owner to return only observations the agent cannot access or establish reliably, such as visual layout, perceived interaction behavior, audio, real multi-client privacy, or behavior in an external environment. Ask the owner to provide log content only when the runtime is outside the shared environment, the files are unavailable, or direct inspection fails. Treat logs as one evidence source rather than self-validating proof; corroborate diagnostic output with an independent input, automated check, controlled expectation, or owner-visible result when the claim could otherwise validate itself.

## Completion Reporting

At the end of work:

- Summarize what was completed.
- Identify changed files and relevant commits.
- Report verification and its result.
- Report unresolved questions, limitations, failures, or risks.
- Stop without beginning another stage or unrelated task.

After a clean committed checkpoint, include a simple continuation cue such as: `Ready to continue when you want.`

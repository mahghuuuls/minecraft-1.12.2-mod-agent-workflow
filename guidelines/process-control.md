# Process Control

This file is the authoritative source for workflow and stage status, approvals, artifact locations, project state snapshots, project glossary, workflow feedback, and backward transitions.

## Owner Setup Defaults

During Project Setup, read owner-specific setup preferences, when present, from:

```text
workspace/documentation/owner-defaults.md
```

Create it from:

```text
setup/owner-defaults-template.md
```

Owner defaults reduce repeated setup questions. They are workspace-specific and ignored by Git. They should contain owner-specific setup preferences and overrides, not general workflow rules. They do not override approved project-specific decisions, legal constraints, safety boundaries, or explicit owner instructions in the active conversation.

## Project Setup

Before the first workflow, execute:

| Stage | Definition | Primary Output |
| --- | --- | --- |
| 0. Project Setup | `stages/0-project-setup.md` | `workspace/documentation/project-setup.md` |

Project Setup establishes the scenario, operational configuration, deferred prerequisites, and proposed workflow. It is required when no approved setup artifact exists.

An approved setup may be carried forward across later workflows. Mark it **Needs Revision** and revisit Stage 0 when the active repository, template candidate, required environment, scenario, or operational configuration materially changes.

A new mod may defer its final repository URL and directory name until Project Initialization. Existing Mod Assessment and Change Cycle require the existing repository identity before their first repository-dependent work.

## Workflow Control

Every mod-development session belongs to one workflow:

| Workflow | Definition | Use |
| --- | --- | --- |
| Initial Development | `workflows/initial-development.md` | Create and deliver a new mod |
| Existing Mod Assessment | `workflows/existing-mod-assessment.md` | Establish an approved baseline for an existing mod |
| Change Cycle | `workflows/change-cycle.md` | Modify a mod that already has an approved baseline |

Only one workflow may be active. Workflow selection follows `AGENTS.md` and requires project-owner approval when starting a new workflow.

A workflow determines:

- Entry conditions
- Which reusable stages apply
- Workflow-specific checkpoints
- The artifact root
- Completion and allowed transitions

A workflow may skip a reusable stage only when its routing rules allow it and the reason is recorded. It may not change the responsibilities defined by a stage.

## Reusable Stages

| Stage | Definition | Primary Output |
| --- | --- | --- |
| 1. Concept and Scope | `stages/1-concept-and-scope.md` | `workspace/documentation/concept-and-scope.md` |
| 2. Feasibility Research | `stages/2-feasibility-research.md` | `workspace/documentation/feasibility-research.md` |
| 3. Requirements Definition | `stages/3-requirements-definition.md` | `workspace/documentation/requirements.md` |
| 4. Architecture Definition | `stages/4-architecture-definition.md` | `workspace/documentation/architecture.md` |
| 5. Project Initialization | `stages/5-initialization.md` | `workspace/documentation/project-initialization.md` |
| 6. Implementation Plan | `stages/6-implementation-plan.md` | `<artifact-root>/implementation-plan.md` and `issues/` |
| 7. Implementation | `stages/7-implementation.md` | Completed code and issue evidence |
| 8. Release Presentation | `stages/8-release-presentation.md` | `<artifact-root>/release-presentation.md` |
| 9. Packaging and Release Validation | `stages/9-packaging-release-validation.md` | `<artifact-root>/release-handoff.md` |

When a workflow invokes multiple stages, perform them in this order. Initial Development uses all stages. Other workflows define their approved route.

## Project Status

Track the project in:

```text
workspace/documentation/project-status.md
```

Create it when the first workflow begins. Record:

- Project Setup status and approved setup artifact
- Mod name and active repository path when known
- Active workflow and workflow status
- Approved baseline version and source revision, when available
- Glossary status and approved glossary artifact, when present
- Active cycle ID, when applicable
- Artifact root
- Current stage or workflow checkpoint
- Status or disposition of every relevant stage
- Approved output artifacts
- Current implementation issue, when applicable
- Blocking questions or decisions
- Manual publication state, when applicable

Use these workflow and stage statuses:

- **Not Started**
- **In Progress**
- **Awaiting Approval**
- **Approved**
- **Needs Revision**

Record the disposition of each reusable stage for the active workflow. Dispositions explain routing and do not replace the status of an invoked stage. Each workflow defines its allowed disposition values.

Implementation issue statuses are defined by the Implementation Plan stage.

## Project State Snapshot

Maintain a compact current-state snapshot at:

```text
workspace/documentation/project-state.md
```

Create it from:

```text
setup/artifact-templates/project-state.md
```

Use this file to reduce context reconstruction after chat forks, context compaction, or handoff between agents. It should summarize only the current working state:

- Active mod repository path
- Active workflow, stage, or checkpoint
- Artifact root
- Approved artifacts
- Current issue, when applicable
- Next required approval
- Blocking questions
- Deferred prerequisites
- Owner-managed responsibilities
- Accepted validation waivers
- Dependency source references

Update it at natural checkpoints: after setup approval, stage approval, workflow changes, issue completion, accepted validation waivers, release handoff, or a material change to the next required action. Do not treat it as a replacement for canonical artifacts.

## Project Glossary

Maintain a project-specific glossary at:

```text
workspace/documentation/glossary.md
```

Create it from:

```text
setup/glossary-template.md
```

Use the glossary to define project-specific vocabulary that affects requirements, behavior, configuration, architecture, code naming, public documentation, or owner communication.

Do not use it as a dictionary for every general Minecraft, programming, or workflow term. Add a term only when inconsistent vocabulary could create ambiguity, duplicate concepts, misleading public copy, incorrect code names, or conflicting requirements.

Record a glossary entry when:

- The owner uses a term with project-specific meaning.
- Two terms appear to mean the same thing.
- One term appears to have multiple possible meanings.
- A term affects requirement wording, config names, code naming, architecture, README copy, changelog copy, or player-facing behavior.
- A term is deprecated but may still appear in older artifacts, code, config, or public copy.

Use these term statuses:

- **Candidate:** Captured but not yet approved.
- **Approved:** Confirmed by the project owner or by approval of the artifact that depends on it.
- **Deprecated:** Replaced by another approved term but retained for traceability.

When a stage depends on a term, approved glossary wording should be used consistently in that stage's artifact. If a term is ambiguous and affects the current stage, clarify it before approving the stage.

Change cycles may update the canonical glossary when new behavior introduces new terms or changes approved vocabulary. Cycle folders must not contain full glossary copies; they should reference the canonical glossary and record only change-specific rationale.

## Stage Transition Briefing

Before starting Project Setup, any reusable stage, or any workflow-specific approval checkpoint, present a short transition briefing and ask the project owner whether to continue.

The briefing must explain:

- **Stage:** the stage or checkpoint name in plain language, not only its number.
- **Purpose:** what this stage is for.
- **User focus:** what the owner should think about, decide, review, or provide now.
- **Not yet:** what the owner should not worry about during this stage because a later stage owns it.
- **Output:** the artifact or concrete result this stage will produce.
- **Boundaries:** any relevant owner-managed responsibilities, deferred prerequisites, or approval requirements.

Ask for explicit permission to begin after the briefing. Do not mark the stage **In Progress** or perform stage work until the owner approves.

For resumed work, provide a shorter briefing that states the active stage, current status, next action, expected output, and whether approval is needed before continuing.

Do not assume the owner remembers what a numbered stage means. Use the stage's plain-language name and practical purpose whenever transitioning.

## Validation Waivers

Validation checks must be explicit, but they must not be forced repeatedly after the project owner declines or marks them owner-managed.

When a validation check is skipped by owner decision, record it as an accepted limitation rather than treating it as a continuing blocker.

Use this format:

```text
Accepted limitation: <Validation name> was not performed by owner decision.
```

Examples:

```text
Accepted limitation: Dedicated server testing was not performed by owner decision.
Accepted limitation: Cleanroom testing was not performed by owner decision.
Accepted limitation: External multiplayer testing was not performed by owner decision.
Accepted limitation: Clean launcher testing was not performed by owner decision.
```

A validation waiver is valid only when:

- The check is owner-managed, explicitly declined, infeasible in the current environment, or intentionally deferred.
- The consequence is recorded where the stage keeps evidence.
- Any public-facing claim affected by the skipped validation is removed, softened, or marked as unverified.
- The project owner explicitly accepts the limitation.

After a waiver is accepted, later stages may reference it but should not repeatedly ask to perform the same check unless new evidence makes it release-blocking or the owner reopens it.

Do not use a waiver to hide a known defect, contradiction, failed check, or unverified claim that the public materials still rely on.

## Workflow Feedback Log

Maintain a project-specific feedback log at:

```text
workspace/documentation/workflow-feedback.md
```

Create it from:

```text
setup/workflow-feedback-template.md
```

Use this log to record friction, corrections, and improvement ideas discovered while using the workflow on a specific mod. The objective is to give the project owner a concise artifact they can later share with a separate workflow-improvement session or another agent outside the active mod project.

Record an entry when an interaction suggests that the workflow may need improvement, for example:

- The owner corrects a repeated agent assumption.
- A stage asks for information too early or too late.
- A default is wrong, unclear, too strict, or too loose.
- A document is redundant, missing, confusing, or too detailed.
- A stage pushes work that should be owner-managed.
- A validation, release, setup, or documentation step creates avoidable friction.
- The agent had to invent an exception that should become explicit workflow guidance.

Do not interrupt the active stage just to update this log unless the issue is blocking. Prefer updating it at natural checkpoints, such as after a correction, before stage approval, after an issue completes, or at the end of the session.

Entries are observations, not approved process changes. This workflow does not update itself. Do not modify versioned workflow files during mod development because a feedback entry exists.

Each entry should include:

- Stable feedback ID
- Date
- Workflow and stage
- Status
- Severity
- Category
- Trigger
- Observed problem
- Suggested change
- Affected files or areas, if known
- Evidence or example, if useful
- Owner notes, if any

The mod-development agent only maintains the log. Process-repository changes must be handled separately outside the active mod-development workflow, using the feedback log as input when the owner chooses to do so.

## Dependency Reference Registry

Maintain dependency source references, when any exist, at:

```text
workspace/documentation/dependency-references.md
```

Create it from:

```text
setup/artifact-templates/dependency-references.md
```

Use this registry only for dependency source repositories or local source references that support research, architecture, implementation, or compatibility decisions. Record:

- Dependency name
- Repository URL or local path
- Requested ref and resolved commit when available
- Version context
- Reason the reference is needed
- Stage, requirement, architecture decision, or issue it supports
- License and usage constraints
- Read-only boundary

Dependency references are not active project repositories. They must not be modified, committed to, pushed, vendored, or copied from without explicit owner approval and licensing review.

## Approval Lifecycle

Apply this lifecycle to stages and workflow-specific approval checkpoints:

1. Confirm that required prerequisites are approved.
2. Present the stage transition briefing and obtain approval to begin.
3. Mark the active item **In Progress**.
4. Perform only its defined work.
5. Create or update its draft artifacts using matching templates under `setup/artifact-templates/` when present.
6. Mark it **Awaiting Approval** and present the complete result.
7. Revise it in response to review.
8. Mark it **Approved** only after explicit confirmation from the project owner.
9. Stop unless the project owner separately authorizes the next item.

A generated artifact, successful check, manual publication action, or approval of a different action does not constitute approval.

## Ask Versus Decide

Ask the project owner when the answer could materially change:

- Scope, requirements, player-facing behavior, or exclusions
- Architecture, dependency choices, or compatibility targets
- Licensing, attribution, publication, or distribution claims
- Owner-managed responsibilities or external actions
- Public wording that affects expectations or support promises
- A previously approved artifact

Decide and record the decision when:

- A workflow default or owner default already applies.
- The choice is local, reversible, and low-risk.
- Existing approved artifacts answer the question.
- The decision is an ordinary implementation detail within the approved architecture.

Do not turn defaults into repeated approval questions. Do not silently decide when a wrong assumption would require reworking approved scope, architecture, licensing, release materials, or owner responsibilities.

## Backward Transitions

When new evidence invalidates an approved decision:

1. Stop affected work.
2. Identify the conflicting evidence and every affected artifact.
3. Mark the earliest affected stage and dependent active work **Needs Revision**.
4. Ask the project owner to approve returning to that stage.
5. Revise and reapprove affected artifacts in stage order.
6. Resume later work only when its prerequisites are approved again.

Do not conceal an upstream problem with an implementation workaround or a downstream document change.

## Artifact Locations

Canonical project documents always remain under:

```text
workspace/documentation/
```

They describe the current approved project state and include project setup, concept, feasibility, requirements, architecture, glossary, project initialization or baseline, and project status.

The selected workflow defines `<artifact-root>`:

- Initial Development: `workspace/documentation/`
- Existing Mod Assessment: `workspace/documentation/`
- Change Cycle: `workspace/documentation/cycles/<cycle-id>/`

Cycle directories contain only change-specific intake, plans, issues, evidence, summaries, release presentation, and release handoff. They must not contain full copies of canonical project documents.

Mod source, repository documentation, release assets, and build outputs belong in the nested mod repository.

## Artifact Rules

All reusable process artifacts are Markdown unless another format is explicitly required.

When a matching template exists under:

```text
setup/artifact-templates/
```

use it as the starting structure for new artifacts. Omit nonapplicable sections rather than filling them with placeholders.

Approved canonical artifacts are authoritative for project-specific decisions. Later artifacts should reference stable requirement, architecture, glossary, or issue identifiers rather than copying full content. A cycle updates affected canonical documents and records only the change and traceability evidence in its own directory.

Omit nonapplicable sections and identify unresolved decisions explicitly. Never invent information to make an artifact appear complete.

## Change Control

A stage may refine only decisions it owns. Changes affecting an earlier stage follow the backward-transition procedure. Operational properties may override reusable defaults but may not silently override approved behavior, architecture, compatibility, licensing, vocabulary, or distribution decisions.

# Process Control

This file is the authoritative source for workflow and stage status, approvals, artifact locations, and backward transitions.

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

## Approval Lifecycle

Apply this lifecycle to stages and workflow-specific approval checkpoints:

1. Confirm that required prerequisites are approved.
2. Mark the active item **In Progress**.
3. Perform only its defined work.
4. Create or update its draft artifacts.
5. Mark it **Awaiting Approval** and present the complete result.
6. Revise it in response to review.
7. Mark it **Approved** only after explicit confirmation from the project owner.
8. Stop unless the project owner separately authorizes the next item.

A generated artifact, successful check, manual publication action, or approval of a different action does not constitute approval.

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

They describe the current approved project state and include project setup, concept, feasibility, requirements, architecture, project initialization or baseline, and project status.

The selected workflow defines `<artifact-root>`:

- Initial Development: `workspace/documentation/`
- Existing Mod Assessment: `workspace/documentation/`
- Change Cycle: `workspace/documentation/cycles/<cycle-id>/`

Cycle directories contain only change-specific intake, plans, issues, evidence, summaries, release presentation, and release handoff. They must not contain full copies of canonical project documents.

Mod source, repository documentation, release assets, and build outputs belong in the nested mod repository.

## Artifact Rules

All reusable process artifacts are Markdown unless another format is explicitly required.

Approved canonical artifacts are authoritative for project-specific decisions. Later artifacts should reference stable requirement, architecture, or issue identifiers rather than copying full content. A cycle updates affected canonical documents and records only the change and traceability evidence in its own directory.

Omit nonapplicable sections and identify unresolved decisions explicitly. Never invent information to make an artifact appear complete.

## Change Control

A stage may refine only decisions it owns. Changes affecting an earlier stage follow the backward-transition procedure. Operational properties may override reusable defaults but may not silently override approved behavior, architecture, compatibility, licensing, or distribution decisions.

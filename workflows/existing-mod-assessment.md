# Existing Mod Assessment Workflow

## Purpose

Establish an approved process baseline for an existing mod without redesigning it or changing its behavior.

## When to Use

Use this workflow when a mod repository already contains implementation or release history but does not have approved canonical documents produced by this process.

Assessment must finish before feature work, bug fixes, compatibility updates, or refactoring begin.

## Entry Conditions

- `workspace/documentation/project-setup.md` is approved.
- Project Setup classifies the scenario as Existing Mod Assessment.
- The project owner approves this workflow.
- The project owner identifies the existing repository.
- No approved project baseline exists.
- No other workflow is active.
- The repository is available under `workspace/project/<project_directory_name>/` or can be cloned there while preserving its history.

The repository does not need to be empty. Project Initialization is not used.

## Required Inputs

- `workspace/documentation/project-setup.md`
- `workspace/documentation/project-state.md`, when present
- `workspace/project.properties`
- Existing source code and Git history
- Existing README, changelog, issue history, releases, and other supplied evidence
- Shared guidelines and defaults

## Workflow-Specific AI Behavior

Act as a baseline investigator.

- Preserve the repository's Git history, origin, branch, source, and released behavior.
- Inspect before drawing conclusions.
- Build and run the existing project when its documented environment permits.
- Distinguish observed behavior, documented intent, owner confirmation, inference, and unknowns.
- Do not present accidental behavior as intended without owner confirmation.
- Do not modernize, migrate, refactor, fix, or reformat production files during assessment.
- Build outputs and local IDE files may be generated when required for inspection but must not be committed.
- Record technical debt and defects without correcting them.
- Use a focused question where one unresolved intent changes the baseline; group closely related low-risk confirmations when the same evidence supports them.
- Use `workspace/documentation/` as `<artifact-root>`.

## Stage Routing

| Reusable Stage | Disposition | Assessment Behavior |
| --- | --- | --- |
| Concept and Scope | Required | Document confirmed current purpose and boundaries |
| Feasibility Research | Required | Assess the current toolchain, dependencies, and constraints |
| Requirements Definition | Required | Establish behavior that must be preserved |
| Architecture Definition | Required | Document the structure that actually exists |
| Project Initialization | Not Applicable | Preserve the existing repository and history |
| Implementation Plan | Not Applicable | Assessment does not plan changes |
| Implementation | Not Applicable | Assessment does not change production behavior |
| Release Presentation | Not Applicable | Assessment does not prepare a new release |

Record this route in `project-status.md`.

## Sequence

1. Record this workflow as **In Progress** in `project-status.md` and update `project-state.md`.
2. Clone or identify the existing repository without altering its history.
3. Record its origin, branch, HEAD revision, tags, release evidence, and working-tree state.
4. Inspect its build, metadata, source structure, resources, dependencies, configuration, and existing documentation.
5. Run the least invasive meaningful build and verification available.
6. Draft `project-baseline.md` with evidence, unknowns, and observed limitations.
7. Present the assessment checkpoint for approval.
8. Execute Concept and Scope in baseline mode.
9. Execute Feasibility Research in baseline mode.
10. Execute Requirements Definition in baseline mode.
11. Execute Architecture Definition in baseline mode.
12. Reconcile `project-baseline.md` with the approved canonical documents.
13. Update `project-state.md` and present the completed assessment workflow for approval.

For baseline mode:

- Concept and Scope documents the mod's confirmed current purpose and boundaries.
- Feasibility Research documents the viability and constraints of the current toolchain, dependencies, and environment.
- Requirements describe behavior that must be preserved, distinguishing verified behavior from owner-approved intent.
- Architecture documents the structure that actually exists, including known debt and risks, without silently proposing a replacement.

Each checkpoint and invoked stage follows `guidelines/process-control.md`.

## Output Artifacts

Produce:

```text
workspace/documentation/project-baseline.md
```

Start from `setup/artifact-templates/project-baseline.md`. The template is the authoritative baseline structure; populate the existing-project evidence fields and omit release-handoff fields that genuinely do not apply.

## Completion Criteria

This workflow is complete when:

- Repository identity and assessed revision are recorded.
- The current build and available verification results are recorded honestly.
- Concept, feasibility, requirements, and architecture are approved as a current baseline.
- Existing behavior and unknowns are explicit.
- No production behavior was intentionally changed.
- `project-baseline.md` is approved.
- The workflow is explicitly approved as complete.

Any subsequent modification must begin as a Change Cycle.

# Initial Development Workflow

## Purpose

Create a new mod from an initial idea, establish its approved project documents and repository, implement it, and prepare its first release.

## When to Use

Use this workflow when no existing implementation or approved project baseline exists and the configured final repository is intended to be empty.

Do not use it to assess or update a repository that already contains mod history.

## Entry Conditions

- `workspace/documentation/project-setup.md` is approved.
- Project Setup classifies the scenario as a new mod.
- The project owner approves Initial Development.
- No other workflow is active.

The final repository URL, directory name, and empty-repository creation may be deferred, but must be resolved before Project Initialization clones the final repository.

## Required Inputs

- `workspace/documentation/project-setup.md`
- `workspace/documentation/project-state.md`, when present
- The initial mod idea
- Shared guidelines and defaults
- `workspace/project.properties` when repository values have been established

## Workflow-Specific AI Behavior

- Establish intended behavior rather than inferring it from nonexistent code.
- Execute every reusable stage in order.
- Do not create the project repository contents before Project Initialization.
- Use `workspace/documentation/` as `<artifact-root>`.
- Treat the approved release artifact and handoff as the end of agent-managed release work.
- Record manual publication as owner-managed and optional follow-up, not as a blocker for workflow completion.
- Never upload or publish the mod.

## Stage Routing

Reusable stages 1 through 8 are **Required**. Release Presentation includes release artifact validation and handoff for Initial Development. Later requests to reproduce or recheck the approved artifact use `procedures/revalidate-release.md` without adding another stage.

## Sequence

1. Record this workflow as **In Progress** in `project-status.md` and update `project-state.md`.
2. Execute Concept and Scope. The workflow-start approval may also approve starting Concept and Scope when the transition briefing clearly covers both.
3. Execute Feasibility Research.
4. Execute Requirements Definition.
5. Execute Architecture Definition.
6. Execute Project Initialization.
7. Execute Implementation Plan.
8. Execute Implementation.
9. Execute Release Presentation through its final review state, including release artifact validation and manual publication handoff when agent-managed by the ownership matrix.
10. Prepare `project-baseline.md` as a release-ready baseline draft, set the manual publication state to **Ready for Publication**, and update `project-state.md`.
11. Present one final checkpoint that separately labels:
    - approval of Release Presentation, and
    - approval of the completed Initial Development workflow and release-ready baseline.

The owner may approve both decisions in one response. Do not treat approval of one as approval of the other.

If the owner later reports a manual publication result, update `project-baseline.md` with the published URL/date/file information as an optional follow-up. Do not keep the Initial Development workflow open merely to wait for external publication.

Each stage and the final workflow record follow the approval lifecycle in `guidelines/process-control.md`.

## Output Artifacts

In addition to stage outputs, produce:

```text
workspace/documentation/project-baseline.md
```

Start from `setup/artifact-templates/project-baseline.md`. The template is the authoritative baseline structure; omit existing-project assessment fields that do not apply.

Do not claim or independently verify publication unless the project owner provides evidence or requests verification.

## Completion Criteria

This workflow is complete when:

- All required reusable stages are approved.
- Required stages are approved.
- Release Presentation, including artifact validation and handoff when agent-managed, is approved.
- `project-baseline.md` records the release-ready baseline.
- The workflow is explicitly approved as complete.

The next behavioral change must use the Change Cycle workflow.

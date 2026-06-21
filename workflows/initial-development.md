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

The final repository URL, directory name, and empty-repository creation may be deferred, but must be resolved before Project Initialization.

## Required Inputs

- `workspace/documentation/project-setup.md`
- The initial mod idea
- Shared guidelines and defaults
- `workspace/project.properties` when repository values have been established

## Workflow-Specific AI Behavior

- Establish intended behavior rather than inferring it from nonexistent code.
- Execute every reusable stage in order.
- Do not create the project repository contents before Project Initialization.
- Use `workspace/documentation/` as `<artifact-root>`.
- Treat the approved release candidate as provisional until the owner reports the manual publication result.
- Never upload or publish the mod.

## Stage Routing

All nine reusable stages are **Required**. Record that disposition for every stage in `project-status.md`.

## Sequence

1. Record this workflow as **In Progress** in `project-status.md`.
2. Execute Concept and Scope.
3. Execute Feasibility Research.
4. Execute Requirements Definition.
5. Execute Architecture Definition.
6. Execute Project Initialization.
7. Execute Implementation Plan.
8. Execute Implementation.
9. Execute Release Presentation.
10. Execute Packaging and Release Validation.
11. Keep the workflow **In Progress** and set its manual publication state to **Ready for Publication**.
12. After the owner reports publication, record the published version and source revision in `project-baseline.md`.
13. Present the completed workflow record for approval.

Each stage and the final workflow record follow the approval lifecycle in `guidelines/process-control.md`.

## Output Artifacts

In addition to stage outputs, produce:

```text
workspace/documentation/project-baseline.md
```

After publication is confirmed, it records:

- Published version
- Source revision
- Publication date reported by the owner
- Supported Minecraft, loader, runtimes, Java environment, and distribution platforms
- Canonical approved project documents
- Known limitations
- Release artifact identity and checksum

Do not claim or independently verify publication unless the project owner provides evidence or requests verification.

## Completion Criteria

This workflow is complete when:

- All nine reusable stages are approved.
- Release Presentation and Packaging and Release Validation are approved.
- The project owner reports the manual publication result.
- `project-baseline.md` records the published baseline.
- The workflow is explicitly approved as complete.

The next behavioral change must use the Change Cycle workflow.

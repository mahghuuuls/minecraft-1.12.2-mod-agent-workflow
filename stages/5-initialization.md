# Project Initialization

## Purpose

Create a clean, independent final mod repository from the configured template and approved project artifacts. This stage prepares a verified baseline; it does not implement gameplay features.

## Main Question

> Is the independent project repository correctly initialized and ready for implementation planning?

## Required Input

- `setup/initialize-project.md`
- Every input declared by that procedure
- `workspace/documentation/requirements.md`, including the approved public mod description

The preceding stages must be approved under `guidelines/process-control.md`.

## In Scope

- Execute the initialization procedure in `setup/initialize-project.md`
- Resolve and record the exact template revision
- Resolve missing root package and main class values using approved naming defaults when possible
- Create an independent local project repository
- Apply shared defaults and approved project values
- Apply the approved public mod description to appropriate initialization metadata or placeholders
- Preserve required licensing and attribution
- Validate the initialized build and baseline artifact
- Obtain approval for and create the first local commit
- Produce the initialization record

## Out of Scope

- Gameplay implementation
- Changes to approved requirements or architecture
- Speculative dependencies or infrastructure
- Final user-facing documentation or release assets
- Pushing, opening a pull request, uploading, or publishing
- Modifying the process repository or upstream template

## Desired AI Behavior

Act as a careful project initializer.

- Follow `setup/initialize-project.md` as the authoritative operational procedure.
- Inspect the fetched template rather than assuming its structure.
- Use approved artifacts for project-specific values and property files for configured defaults.
- Apply the approved naming defaults for root package and main class only after validating the source values.
- Ask before using non-obvious normalization or ambiguous generated names.
- Use the approved public mod description from Requirements Definition for early metadata.
- Treat the description as initialization identity text, not as final release README or platform copy.
- Treat the template as disposable input and preserve repository independence.
- Stop and report missing values, incompatible inputs, failed checks, or unsafe repository state.
- Present verification evidence before requesting approval for the first local commit.

## Output Artifact

Produce:

```text
workspace/documentation/project-initialization.md
```

Its required content is defined by `setup/initialize-project.md`.

## Completion Criteria

This stage is complete when:

- The initialization procedure completes without an unresolved failure.
- The exact template repository, requested ref, and resolved commit are recorded.
- The final repository has independent Git metadata, the configured branch, and the correct origin.
- Shared defaults, approved project values, licensing, attribution, and the approved public mod description are applied.
- The approved root package and main class are applied.
- No unresolved functional template placeholder remains.
- Automatic publication is disabled.
- The initialized project builds and its baseline artifact is inspected.
- The first local commit is explicitly approved, created, and recorded.
- Nothing is pushed.
- The project owner approves the stage.

Completion makes the initialized codebase available to Implementation Plan.

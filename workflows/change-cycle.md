# Change Cycle Workflow

## Purpose

Deliver one approved feature, bug fix, compatibility update, or refactor against an existing approved project baseline.

## When to Use

Use this workflow when `project-baseline.md` and the required canonical documents are approved and the project owner requests a change.

Use one cycle per coherent release objective. Do not combine unrelated requests merely because they were requested together.

## Entry Conditions

- An approved Project Setup is available and still matches the active repository.
- The project owner approves Change Cycle.
- An approved project baseline exists.
- The active repository and current source revision are known.
- No other workflow or change cycle is active.
- The project owner provides an initial change request.

If the repository has no approved baseline, use Existing Mod Assessment first.

## Required Inputs

- `workspace/documentation/project-setup.md`
- `workspace/documentation/project-baseline.md`
- `workspace/documentation/project-status.md`
- Approved canonical project documents
- The active mod repository
- The initial change request

## Workflow-Specific AI Behavior

Act as a change-impact coordinator before acting as an implementer.

- Verify the baseline version and source revision before planning the change.
- Interview the owner one focused question at a time.
- Separate the requested outcome from possible implementations.
- Identify effects on behavior, loader/runtime compatibility, configuration, persisted data, dependencies, architecture, distribution platforms, performance, and release scope.
- Propose the earliest affected reusable stage and every later stage that must be revisited.
- Never skip a stage silently.
- Keep unaffected canonical stages approved.
- Update affected canonical documents instead of copying them into the cycle.
- Store change-specific execution artifacts under the cycle artifact root.
- Never rerun Project Initialization.
- Never upload or publish the mod.

## Cycle Identity and Artifact Root

Create a stable identifier:

```text
CYCLE-NNN-short-name
```

Use:

```text
workspace/documentation/cycles/<cycle-id>/
```

as `<artifact-root>`.

Record the cycle ID, artifact root, baseline revision, and status in `project-status.md`.

## Change Intake and Impact Analysis

Produce:

```text
<artifact-root>/change-intake.md
```

It must contain:

1. Cycle ID and requested outcome
2. Motivation
3. Baseline version and source revision
4. Current working-tree state
5. In-scope and out-of-scope behavior
6. Compatibility expectations
7. Configuration and persisted-data impact
8. Loader, runtime, dependency, integration, and distribution impact
9. Technical uncertainties
10. Affected requirement and architecture identifiers
11. Intended release classification or version, when known
12. Risks and required validation
13. Stage impact matrix
14. Proposed route

Use these stage dispositions:

- **Revisit:** The stage's approved decisions or artifacts must change.
- **Carry Forward:** Existing approval remains valid for this cycle.
- **Not Applicable:** The stage does not apply to this workflow.
- **Blocked:** Routing cannot be approved until missing evidence or a decision is supplied.

Project Initialization is always **Not Applicable**. Implementation Plan, Implementation, Release Presentation, and Packaging and Release Validation are normally **Revisit** for a releasable code change. Existing branding may be carried forward within Release Presentation.

Present the complete intake and proposed route for explicit approval before revising canonical documents or code.

## Sequence

1. Confirm the entry conditions and baseline.
2. Create the cycle ID and artifact root.
3. Mark the workflow **In Progress**.
4. Conduct Change Intake and Impact Analysis.
5. Mark the intake checkpoint **Awaiting Approval** and present the route.
6. Revise it until the owner approves it.
7. Record stage dispositions in `project-status.md`.
8. Mark affected canonical stages **Needs Revision**.
9. Execute each **Revisit** stage in normal stage order.
10. Execute Implementation Plan using the cycle artifact root.
11. Execute Implementation using the cycle issues.
12. Execute Release Presentation using the cycle artifact root.
13. Execute Packaging and Release Validation using the cycle artifact root.
14. Produce `<artifact-root>/cycle-summary.md`.
15. Keep the workflow **In Progress** and set its manual publication state to **Ready for Publication**.
16. After the owner reports publication, update `project-baseline.md` with the new version and source revision.
17. Present the completed cycle for approval.

Do not enter a later selected stage until every selected prerequisite is approved. Discovery of additional impact follows the backward-transition rules in `guidelines/process-control.md`.

## Cycle Summary

`<artifact-root>/cycle-summary.md` should contain:

- Cycle ID and outcome
- Baseline version and revision
- Final source revision
- Canonical documents and identifiers changed
- Implemented issues
- Verification summary
- Known limitations
- Release artifact and checksum
- Manual publication state
- Resulting baseline version after owner confirmation

It records the delta and traceability; it must not duplicate complete canonical documents.

## Completion Criteria

The agent-managed work is ready for manual publication when:

- Change Intake and the selected route are approved.
- Every **Revisit** stage is approved.
- Every required cycle issue is Done.
- Release Presentation and Packaging and Release Validation are approved.
- The cycle summary records the final handoff.

The workflow is complete when the project owner reports the publication result, the canonical baseline is updated, and the completed cycle is explicitly approved.

A later request begins a new Change Cycle with a new identifier.

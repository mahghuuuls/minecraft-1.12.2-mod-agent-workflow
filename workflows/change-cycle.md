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
- `workspace/documentation/project-state.md`, when present
- Approved canonical project documents
- The active mod repository
- The initial change request

## Workflow-Specific AI Behavior

Act as a change-impact coordinator before acting as an implementer.

- Verify the baseline version and source revision before planning the change.
- Determine whether the baseline records a reported publication, and apply the branching recommendation in `guidelines/collaboration-guidelines.md` before the cycle's first commit.
- Use focused questions for branching impact decisions and compact decision packets for related low-risk route recommendations.
- Separate the requested outcome from possible implementations.
- Identify effects on behavior, loader/runtime compatibility, configuration, persisted data, dependencies, architecture, distribution platforms, performance, and release scope.
- Propose the earliest affected reusable stage and every later stage that must be revisited.
- Never skip a stage silently.
- Keep unaffected canonical stages approved.
- Update affected canonical documents instead of copying them into the cycle.
- Store change-specific execution artifacts under the cycle artifact root.
- Never rerun Project Initialization.
- Never upload or publish the mod.

Do not classify a change as low risk merely because the owner calls it a fix. After the Implementation Plan establishes exactly one Ready issue and resolves its material decisions, assess it against the proportionate approval-bundle criteria in `guidelines/process-control.md`. If eligible, proactively present that bounded packet and record the result in the plan and `project-status.md`. If it is not eligible, identify the material reason and retain the normal checkpoints. Final release-artifact approval is always separate from this bundle.

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

## Working Branch

Determine the cycle's working branch before any code change, using the branching rule in `guidelines/collaboration-guidelines.md`.

Check `project-baseline.md` for a reported publication date or URL:

- **No reported publication.** Work on `project_default_branch`. Record that the mod is not yet published and no branch is needed.
- **Reported publication.** Recommend a `develop` branch created from the current default-branch tip, and record the owner's decision in the change intake.

Present this with the intake route rather than as a separate interruption. Record the resulting working branch in `change-intake.md` and in `project-status.md`, so a resumed agent commits to the right branch without rediscovering the decision.

## Change Intake and Impact Analysis

Produce:

```text
<artifact-root>/change-intake.md
```

Start from `setup/artifact-templates/change-intake.md`. The template is the authoritative intake structure; this workflow's stage-disposition rules are authoritative for the route.

Use these stage dispositions:

- **Revisit:** The stage's approved decisions or artifacts must change.
- **Carry Forward:** Existing approval remains valid for this cycle.
- **Not Applicable:** The stage does not apply to this workflow.
- **Blocked:** Routing cannot be approved until missing evidence or a decision is supplied.

Project Initialization is always **Not Applicable**. Implementation Plan, Implementation, and Release Presentation are normally **Revisit** for a releasable code change. Existing branding may be carried forward within Release Presentation.

Release Presentation owns release artifact validation and handoff. A later request to reproduce or recheck the already approved artifact uses `procedures/revalidate-release.md` and does not add a stage disposition.

Present the complete intake and proposed route for explicit approval before revising canonical documents or code.

## Sequence

1. Confirm the entry conditions and baseline.
2. Create the cycle ID and artifact root.
3. Mark the workflow **In Progress**.
4. Determine the working branch from the baseline's publication record.
5. Conduct Change Intake and Impact Analysis.
6. Mark the intake checkpoint **Awaiting Approval** and present the route, including the recommended working branch.
7. Revise it until the owner approves it.
8. Create the approved working branch, when one was approved, before the first cycle commit.
9. Record stage dispositions in the authoritative `project-status.md` ledger.
10. Mark affected canonical stages **Needs Revision**.
11. Execute each **Revisit** stage in normal stage order.
12. Execute Implementation Plan using the cycle artifact root, including the proportionate approval-bundle assessment.
13. Execute Implementation using the cycle issues.
14. Execute Release Presentation using the cycle artifact root, including release artifact validation and handoff when agent-managed by the ownership matrix.
15. Produce `<artifact-root>/cycle-summary.md`.
16. Offer the merge back into `project_default_branch` when the cycle used a separate working branch, and merge only under explicit authorization.
17. Set the manual publication state to **Ready for Publication**, update `project-baseline.md` with the release-ready version and source revision, and update `project-state.md`.
18. Present the completed cycle for approval.

If the owner later reports a manual publication result, update `project-baseline.md` with the published URL/date/file information as an optional follow-up. Do not keep the Change Cycle open merely to wait for external publication.

Do not enter a later selected stage until every selected prerequisite is approved. Discovery of additional impact follows the backward-transition rules in `guidelines/process-control.md`.

## Cycle Summary

Create `<artifact-root>/cycle-summary.md` from `setup/artifact-templates/cycle-summary.md`. The template is the authoritative summary structure. Record the baseline and final source revisions, canonical identifiers changed, implemented issues, verification, limitations, artifact/checksum, resulting release-ready baseline, manual publication state, and any later owner-reported publication result in the matching sections.

It records the delta and traceability; it must not duplicate complete canonical documents.

## Completion Criteria

The agent-managed work is ready for manual publication when:

- Change Intake, the selected route, and the working-branch decision are approved.
- Every **Revisit** stage is approved.
- Every required cycle issue is Done.
- Release Presentation, including artifact validation and handoff when agent-managed, is approved.
- The cycle summary records the final handoff.

The workflow is complete when the canonical release-ready baseline is updated and the completed cycle is explicitly approved. Manual publication can be recorded later as an optional baseline update.

A later request begins a new Change Cycle with a new identifier.

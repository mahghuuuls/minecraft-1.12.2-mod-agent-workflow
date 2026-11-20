# Change Cycle Workflow

## Purpose

Deliver one approved change against an existing project baseline, including a correction to public documentation for an existing release.

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

- Reread the authoritative [local owner defaults](../guidelines/process-control.md#local-owner-defaults) before planning this cycle.
- Verify the baseline version and release source revision before planning the change. When a later approved copy-only commit is present, check its documented scope against the diff and retain the release revision for artifact identity.
- Treat a reported defect as a claim to confirm, not as an established fact, before proposing any route.
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

After the Implementation Plan resolves its material decisions, follow [Implementation Approval For Named Issues](../guidelines/process-control.md#implementation-approval-for-named-issues).

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

## Resuming A Parked Cycle

Before presenting the next checkpoint of a parked cycle, run the [Workflow Repository Update Check](../guidelines/process-control.md#workflow-repository-update-check). Read the current ledger, release-ready baseline and parked approvals, then inspect the mod's current branch and revision against the cycle's approved working branch.

When another release occurred while the cycle was parked, compare its baseline with the parked cycle's assumptions and approved scope. Carry forward approvals whose basis still holds, identify affected artifacts through change-impact analysis and obtain approval for required revisions. Resolve a changed baseline or working-branch decision before resuming implementation. Record the resumption findings in `project-status.md` and refresh `project-state.md` for the handoff.

## Reported Defect Confirmation

For a new report against an approved baseline, investigate before opening a Change Cycle. Record the report under a **Defect intake** heading in `workspace/documentation/project-status.md` with a stable report reference (an issue URL or a local date and short name), affected version, evidence and outcome. Keep the active workflow, branch and release baseline intact during triage. If a cycle is already active, use its intake or issue for a report in scope. An unrelated report can wait at intake until the active cycle closes.

This applies to any report of incorrect behavior, whoever reported it. It does not apply to a feature request, enhancement, or refactor, where there is nothing to reproduce.

Gather what the report needs to be actionable:

- Mod version, and the loader, runtime, or modpack in use
- Other installed mods, when interaction is plausible
- The relevant configuration or input file as the reporter actually has it
- Logs covering the affected launch or action
- The exact steps taken, the expected result, and the observed result

Investigate before asking the reporter or the owner for more. A log, a configuration file, or the relevant code path frequently settles the question without launching anything; follow Investigate Before Asking in `guidelines/process-control.md`. When confirmation needs a running game, use the launch and control permissions recorded for the specific runtime in Project Setup. Announce an authorized graphical launch and run the repeatable check. Ask the owner only for an owner-managed launch, an unavailable interaction, or an observation the available evidence cannot establish. An approved isolated runtime can establish a pack-specific failure only if it contains the relevant inputs.

Record exactly one outcome:

- **Reproduced:** the reported behavior was observed, or its cause was established directly from evidence. Proceed to intake.
- **Needs Info:** the report cannot be judged yet. State precisely what is missing and stop. Do not route stages on a guess.
- **Not This Mod:** the cause is another mod, a configuration or installation error, or the reporter's environment. No cycle is required.
- **Works As Designed:** the behavior matches an approved requirement. No fix is required.

Record the outcome and evidence label with the report. For **Needs Info**, name the missing evidence and resume the same entry when it arrives. Close **Not This Mod** and **Works As Designed** at intake. For **Reproduced**, propose starting a cycle and obtain the ordinary workflow-start approval. Once opened, link the intake entry and retained evidence from `change-intake.md` and record the cycle ID back on the report. Reuse this investigation when the route is prepared.

For a **Reproduced** outcome, preserve the smallest reliable reproduction available and identify the boundary where a future regression could be detected. This is intake evidence, not a premature test-design decision. When no stable reproduction can be retained, record why and identify the evidence that established the cause.

Do not propose a stage route until the outcome is **Reproduced**, unless the owner explicitly accepts proceeding on an unconfirmed report. Record that acceptance and its consequence in the report. The plan may target the wrong cause, and verification cannot establish that the reported problem was fixed. Then use the ordinary cycle-start approval.

**Not This Mod** and **Works As Designed** may still deserve a change when the mod made the mistake easy to make, such as an unclear error message, a confusing config path, or missing documentation. Route that as its own request judged on its own merits, not as a defect fix.

## Change Intake and Impact Analysis

Produce:

```text
<artifact-root>/change-intake.md
```

Start from `setup/artifact-templates/change-intake.md`. The template is the authoritative intake structure; this workflow's stage-disposition rules are authoritative for the route.

Apply the [modded deployment default](../guidelines/project-defaults.md#modpack-compatibility) to the changed behavior. Identify affected interaction paths, existing support promises, and any new compatibility expectations. Carry forward the modpack-reference decision from approved setup or prior approved intake. If no decision is recorded and the change raises a material compatibility question, use the [Project Setup reference question](../stages/0-project-setup.md#modpack-reference) in intake and record the answer there.

Use these stage dispositions:

- **Revisit:** The stage's approved decisions or artifacts must change.
- **Carry Forward:** Existing approval remains valid for this cycle.
- **Not Applicable:** The stage does not apply to this workflow.
- **Blocked:** Routing cannot be approved until missing evidence or a decision is supplied.

Project Initialization is always **Not Applicable**. Implementation Plan, Implementation, and Release Presentation are normally **Revisit** for a releasable code change. Follow the [Release Presentation icon decision](../stages/8-release-presentation.md#icon-decision) for existing branding.

Release Presentation owns release artifact validation and handoff. A later request to reproduce or recheck the already approved artifact uses `procedures/revalidate-release.md` and does not add a stage disposition.

Present the complete intake and proposed route for explicit approval before revising canonical documents or code.

### Public-copy corrections

For an existing release, use the [copy-only Release Presentation route](../stages/8-release-presentation.md#copy-only-corrections) when the requested wording follows from approved behavior and the changed files are outside all packaged outputs. Establish both from the proposed diff, release evidence and build inputs. A README included in the JAR is a packaged resource. A new compatibility promise needs requirements review even if only one sentence changes.

Record the evidence and file scope in the intake. Carry forward the approved implementation and other unaffected stages, record Implementation Plan as Not Applicable to this correction, and revisit Release Presentation for the copy. If the correction changes scope or the agent cannot establish these conditions, route to the earliest affected stage under the ordinary impact analysis.

## Sequence

1. Run the Workflow Repository Update Check in `guidelines/process-control.md` before proposing the workflow. For a defect, finish pre-cycle intake above first. Confirm the baseline and obtain workflow-start approval for a change that warrants a cycle. For runtime-affecting work when the mod declares MixinBooter, read the version the test instance's Cleanroom reports again and apply Mixins in `guidelines/project-defaults.md`.
2. Create the cycle ID and artifact root.
3. Mark the workflow **In Progress**.
4. Determine the working branch from the baseline's publication record.
5. For a defect, link the prior confirmation or the owner's acceptance to proceed unconfirmed.
6. Conduct Change Intake and Impact Analysis.
7. Mark the intake checkpoint **Awaiting Approval** and present the route, including the recommended working branch.
8. Revise it until the owner approves it.
9. Create the approved working branch, when one was approved, before the first cycle commit.
10. Record stage dispositions in the authoritative `project-status.md` ledger.
11. Mark affected canonical stages **Needs Revision**.
12. Execute only the **Revisit** stages, in normal order, applying [Stage Transition Preferences](../guidelines/process-control.md#stage-transition-preferences).
13. When the route revisits Implementation Plan, use the cycle artifact root and its approval and authorization packet.
14. When the route revisits Implementation, execute its approved cycle issues.
15. For a release, execute Release Presentation with the applicable artifact validation and handoff. For a [public-copy correction](#public-copy-corrections), use the scoped copy review and its completion criteria.
16. Run [Workflow Closure](../procedures/workflow-closure.md) for the approved release or copy-only route.

Do not enter a later selected stage until every selected prerequisite is approved. Discovery of additional impact follows the backward-transition rules in `guidelines/process-control.md`.

## Cycle Summary

Create `<artifact-root>/cycle-summary.md` from `setup/artifact-templates/cycle-summary.md`. The template is the authoritative summary structure. For a release, record the baseline and final source revisions, canonical identifiers changed, implemented issues, verification, limitations, release handoff, publication state, and any later owner-reported publication result. For copy-only work, record the documentation revision, review result and prior release handoff.

It records the delta and traceability; it must not duplicate complete canonical documents.

## Completion Criteria

For a copy-only cycle, close with the owner's explicit approval after the intake route, applicable copy review, approved documentation commit and cycle summary are complete. The summary distinguishes that commit from the prior release handoff and records any owner-managed listing edit.

For a cycle producing a new release, the agent-managed work is ready for manual publication when:

- A reported defect has a recorded confirmation outcome, or an owner-accepted decision to proceed without one.
- A reproduced defect retains a minimal reproduction and candidate detection boundary, or records why a stable reproduction is unavailable.
- Change Intake, the selected route, and the working-branch decision are approved.
- Every **Revisit** stage is approved.
- Every required cycle issue is Done.
- Release Presentation, including artifact validation and handoff when agent-managed, is approved.
- The cycle summary records the final handoff.
- The ledger records the [closure cleanup review](../procedures/cleanup-validation-workspace.md) and its disposition.

Close a release-producing Change Cycle once the release is validated, the canonical baseline records **Ready for Publication**, and the owner explicitly approves the completed cycle.

A later request begins a new Change Cycle with a new identifier.

## Publication Follow-Up

CurseForge upload, platform approval, and public file visibility are optional follow-ups after cycle closure. Update `project-baseline.md` with the owner-reported publication status, date, and project URL when available. Add the public file URL and ID when available, and distinguish owner reports from independently verified public listings.

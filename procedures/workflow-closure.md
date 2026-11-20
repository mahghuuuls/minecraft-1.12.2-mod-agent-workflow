# Workflow Closure

Initial Development and Change Cycle invoke this final checkpoint after their last applicable stage reaches its final review. Use the existing final workflow approval to close the work.

## Prepare the closure briefing

| Closing work | Outcome to prepare |
| --- | --- |
| Initial Development | Prepare the release-ready baseline draft and handoff. Set the manual publication state to **Ready for Publication**. Present Release Presentation approval and approval of the completed workflow and baseline as separately labeled decisions in the same briefing. |
| Change Cycle with a new release | Prepare the [cycle summary](../workflows/change-cycle.md#cycle-summary), validated release handoff and updated baseline version and release revision. Set the manual publication state to **Ready for Publication**. |
| Copy-only Change Cycle | Prepare the cycle summary with the approved wording or file and its documentation commit. Link the existing handoff and carry forward its release identity, checksum and publication state. |

1. Check the invoking workflow's completion criteria against the applicable records above. Name **Workflow Closure** as the current checkpoint in the ledger and refresh the resume snapshot. For a cycle on a separate working branch, offer the merge back to the project default branch under the [Git authorization rules](../guidelines/collaboration-guidelines.md#git-and-external-actions).
2. Complete the [workflow retrospective](../guidelines/process-control.md#workflow-feedback-log) and the [validation cleanup review](cleanup-validation-workspace.md). Record the cleanup disposition in the current workflow or cycle entry of `project-status.md`, including when the cycle created no disposable files.
3. Mark the workflow **Awaiting Approval** and present the outcome for explicit closure approval. Include the cleanup proposal when applicable. Approval to delete the listed paths is a separate decision and can come in the same reply. Include the [Workflow Changes offer](../guidelines/process-control.md#optional-post-closure-workflow-changes) when the owner opted in.

## Record the decision and deliver the handoff

After closure approval, record the decision, mark the workflow **Approved** and update `project-state.md`. Carry out any separately authorized merge or push and apply any approved cleanup under its procedure. Update the disposition and deliver the measured cleanup report when applicable. A pending decision, decline or deferral leaves the files in place and allows handoff.

Run the [workspace validator](../scripts/validate-workspace.ps1) against the completed ledger and follow the project's [documentation backup preference](../guidelines/process-control.md#documentation-backup-checkpoints). For a release, finish with the [publication packet](../stages/8-release-presentation.md#publication-packet). For copy-only work, deliver the approved wording or file and documentation commit for the owner's listing edit. Later publication reports follow the invoking workflow.

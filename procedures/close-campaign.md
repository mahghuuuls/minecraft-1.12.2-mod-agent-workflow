# Close Campaign

## Purpose

Close an owner-assisted validation campaign so that the evidence pack holds every file the cards used, the results file matches the session map, every included issue is Done on a reviewed record, and the borrowed runtime is back at its baseline.

This is a callable procedure, not a reusable stage. It creates no new checkpoint and approves nothing. `stages/7-implementation.md` owns when a campaign may close and which authorizations its commits need; this file owns the order of the closing work.

## When To Use

Use this procedure once the last card of a campaign has a result, passed or not, and `stages/7-implementation.md` says the campaign may close. Use it also when a campaign is abandoned: the pack then records what ran and what did not.

## Required Inputs

- The campaign's session map and the running notes kept per card (`staging/results-notes.md`)
- The campaign's staging folder with the launch logs, configuration copies, bundle files, and owner screenshots
- The included issues, each with its Manual Observability contract and acceptance criteria
- The campaign's pack specification, or the plan's description of what the pack retains
- The authorization that covers the completion commit, when one is needed

## Boundaries

- Do not write a result line for a card from memory or from the owner's `Done` alone; every line comes from the running notes and the logs.
- Do not commit, push, or publish without the authorization `stages/7-implementation.md` requires for that step.
- Do not restore the runtime before the follow-up review has finished; a criterion the review finds unreached needs the prepared instance.
- Do not rewrite an existing pack. A correction after capture creates a new pack and marks the old one superseded.

## Procedure

Each step feeds the next, and a step done out of order is the usual source of a wrong path, a stale count, or a pack captured from the wrong tree.

1. Save every runtime output the cards used (current and rotated logs, the configuration file as the game rewrote it, bundle files, owner screenshots) into the campaign staging folder before any launch, edit, or rename can change it. Use absolute paths and confirm each copy exists with a fresh listing.
2. Write the pack specification now, before the results file, naming every launch's staged log by its full path, next to the other retained files. The capture refuses a path that does not exist, so a staging copy that failed is found here, while the instance is still prepared and the rotated log can still be recovered, instead of after the reset.
3. Write the campaign results file once, after the last launch, from the running notes kept per card during the session (`staging/results-notes.md`: the log lines, times, and owner words of each card as they happen) and from the records, with the deviations, the per-card lines, the errors read from the logs, and the automated checks after any correction. Every card of the session map gets a line, including a card that was deferred or not run, with its reason; `scripts/validate-workspace.ps1` reports a map card with no results line. Do not write the results file in pieces between launches and submit each piece to review: each piece costs a review pass, and the pieces disagree with each other by the end.
4. Apply corrections the cards produced, rerun the automated checks, and submit the corrections and the results file to the follow-up review through `procedures/independent-review-brief.md`; take its findings before anything is committed. A criterion the review finds unreached is closed by one extra card in the same campaign, run while the instance is still prepared, or by a limitation the owner accepts and the issue records. It is never closed by a result line that says "met". Keep the instance prepared until this step is done; restoring it earlier means preparing it twice.
5. Remove from the development `run` folder every jar and script the campaign borrowed from another instance or added for a card, and restore the development configuration file, so the tree the pack describes is the tree a later session starts from. Keep the staged copies; they are the evidence.
6. Make the completion commit under the authorization that covers it, and confirm `git status --porcelain` is empty.
7. Build from that clean tree when the pack retains the jar or the test results, using the launch path recorded in Project Setup (see Running Builds And Tests in `guidelines/coding-standards.md`); ask the owner only when Project Setup recorded that the agent cannot build.
8. Complete the pack specification with the built files and every runtime source declared honestly, capture the pack with `tools/evidence-pack/evidence-pack.cmd capture`, and run `verify` on its manifest.
9. Record in each included issue: the in-game verification lines, the follow-up review, the completion commit, and the pack path with its manifest hash; move the issue to **Done**.
10. Update `project-status.md` (commit list, next action, next approval, current issue line) and `project-state.md`.
11. Run `scripts/validate-workspace.ps1`; it checks that every Done issue's pack exists and that its manifest still matches its recorded hash.
12. Restore the runtime: the test instance reset to its recorded baseline (`mods` folder against the template list, changed configuration restored from the copy taken before the session, generated configuration of removed mods deleted, lock note removed); write the reset check into the staging folder and record what stays, such as a test world. This is the last step for the reason given in step 4.

## Completion

The campaign is closed when:

- Every card of the session map has a result line with its evidence, or a recorded reason it did not run.
- The follow-up review's findings are addressed or declined on the record.
- The pack exists, `verify` passed, and each included issue names the pack path and manifest hash.
- Every included issue is **Done**, or the issue records the limitation the owner accepted.
- The ledgers are updated and `scripts/validate-workspace.ps1` passes.
- The test instance matches its baseline and holds no lock note from this project.

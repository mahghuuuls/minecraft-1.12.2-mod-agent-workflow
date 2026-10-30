---
name: close-campaign
description: Close an owner-assisted validation campaign in the order this workflow specifies, so the evidence pack, the results file, the issues, and the borrowed test instance all end in the right state. Use when the last card of a campaign has a result, or when an agent is about to capture a pack, reset an instance, or mark campaign issues Done.
license: MIT
---

# Close Campaign

The last card is done. What is left is bookkeeping, and bookkeeping done in the wrong order is how a pack ends up without a log, an instance ends up reset before a review asks for one more card, or a results file disagrees with the session map.

## Read first, every time

`procedures/close-campaign.md` in the workflow repository. It is the procedure; this skill only makes sure it runs when the moment comes. Find the workflow root by walking up from the working directory to the folder holding `guidelines/` and `workspace/`. Read the procedure as it is on disk now, not from memory.

## Then do it

Follow its steps in order, and say which step you are on. Do not skip ahead to the commit or the reset. Two steps that are most often done too early:

- The pack specification comes before the results file, so a staged log that is missing is found while it can still be recovered.
- The instance reset comes last, after the follow-up review, so a criterion the review finds unreached can still get its card.

## Boundaries

- This skill adds nothing to the procedure and changes nothing in `stages/7-implementation.md`. Where they disagree, the stage document is correct.
- It grants no Git permission, marks no issue Done on an unreviewed record, and waives no card. Follow the procedure's stage and collaboration-guideline references for those decisions.

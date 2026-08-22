---
name: evidence-audit
description: Re-verify an issue's completion evidence claim by claim, checking that every observed / inspected / inferred label matches how the fact was actually established and that every cited file, commit, and quote is real. Use when evidence records are suspected of saying more than anyone actually saw.
license: MIT
---

# Evidence Audit

The user invoked this skill on an issue, or on every Done issue when none was named. Your job is to re-verify its completion evidence the way an auditor would: open everything cited, trust nothing restated.

The failure this remedies: writing `(observed)` because a claim feels true. An author who believes the conclusion labels it as seen, cites the log from memory, and quotes the line they expect to be there. Each of those produced a real defect in this workflow's history, found only by independent review.

## Procedure

Work through the issue's Completion Evidence one claim at a time. For each:

1. **Identify the label.** A claim with no label is a finding by itself; evidence discipline requires one.
2. **Verify the label against how the fact was established:**
   - `(observed)` requires that the event was watched happening, or that a retained artifact directly shows it and is still openable. If the artifact was never kept, the honest label is "reported by the owner" or `(inferred)`, not observed.
   - `(inspected)` requires that the cited source was actually read. Reopen it now. Confirm the quoted text exists in the named file, at a plausible place, in the version the claim is about.
   - `(inferred)` requires the premises to be stated and themselves labeled. Inference from an unverified premise is not evidence of anything.
3. **Check provenance.** The commit the evidence claims to belong to must exist, and the artifact's timestamps must be consistent with it. A log written before the commit it supposedly validates is evidence about older code, whatever it says. This exact defect has occurred here: a cited server log predated its claimed commit by three commits, and quoted a line from a different file than the one named.
4. **Check the arithmetic.** Counts of tests, reports, files, or buttons stated in evidence must be recounted from the artifact, not accepted. Off-by-small-number count drift is common and it compounds.

## Recording the result

- **Downgrade, never delete.** A wrong label is corrected in place or in a dated correction section; the original text stays visible so the correction is inspectable. Deleting the wrong claim hides that it was made.
- Date every correction and say how the truth was established this time.
- Where a claim cannot be re-verified because the artifact is gone, say so: the claim becomes unverifiable, which is a state worth recording, not a pass and not a silent deletion.
- A clean audit lists what was checked. "Evidence reviewed, no issues" with no inventory is the same non-result this skill exists to prevent.

## Boundaries

- The audit changes records, never code. A defect in the code found along the way is routed to the workflow's defect handling, not fixed inside the audit.
- It cannot upgrade a label. Making an `(inferred)` claim `(observed)` requires performing the observation, which is validation work under `guidelines/manual-validation.md`, not auditing.

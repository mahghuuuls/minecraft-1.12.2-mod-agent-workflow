---
name: records-sync
description: Reconcile the project's status ledgers against reality - git, the issue files, and the code - and correct the drift on the record. Use when the paperwork has fallen behind the work, or before any stage transition or approval decision.
license: MIT
---

# Records Sync

The user invoked this skill. Your job is to make the status documents true again by checking them against reality, not against memory or against each other.

The failure this remedies: agents update the code and forget the paperwork. In this workflow's history the ledger once still named a superseded issue as the next action days after it died, the running commit count had drifted by four because it was incremented by hand instead of counted, and the requirements described four placement edges while the shipped code had two. Each was found late, by accident or by review, because nothing reconciles the records routinely.

## What to check, and against what

Reality is git, the filesystem, and the code. The documents follow reality, never the reverse.

1. **Commit facts.** The ledger's commit count against `git rev-list --count HEAD`. The named head commit against `git log -1`. The pushed/unpushed claim against `origin/<branch>`. Count; do not increment.
2. **Issue statuses.** Every status the ledger asserts against the `Status:` line in the issue file itself. The "current issue" and "next action" against whether that issue is still open at all.
3. **Stage table.** Each stage's status against whether its artifact exists and whether an approval for its latest revision is actually recorded. A stage revised after approval with no re-approval recorded is Awaiting Approval, whatever the table says.
4. **Claims about the code.** Spot-check any concrete assertion the records make about behavior or configuration - accepted values, defaults, counts - against the source. Requirements that drifted from code is the expensive version of this failure.
5. **Cross-document agreement.** The subordinate snapshot against the authoritative ledger. Where they disagree, reality decides which is right, and both get fixed.

## Recording the result

- Correct in place, date the correction, and where the drift was itself informative, say what had drifted and how far. A silent fix hides the failure pattern this skill exists to surface.
- Do not invent history. A record that cannot be reconstructed - when exactly something changed - is corrected to the present truth with the uncertainty stated.
- Report to the user what was out of sync. Zero findings is a fine result; report it with what was checked.

## Boundaries

- This skill never changes code, issue acceptance criteria, or evidence to make a record true. If reality is the thing that is wrong, that is a defect and it routes through the workflow's defect handling.
- It records approvals only when they actually happened; it cannot grant one. A stage found unapproved stays unapproved until the owner says otherwise.

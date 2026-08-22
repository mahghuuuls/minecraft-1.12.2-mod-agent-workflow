---
name: standards-review
description: Prompt an independent reviewer to check the code being built against this workflow's coding standards, and handle the findings honestly. Use when review is due for an issue, or when an agent has been merging its own work without a real review.
license: MIT
---

# Standards Review

The user invoked this skill because code needs reviewing against the workflow's standards. Your job is to brief an independent reviewer, run the review, and deal with the findings. Not to review your own work in your own head and call that a review.

## Why a separate reviewer

The author of a change is the one person guaranteed to read it as intended rather than as written. Every rationalization that shaped the code will shape the self-review identically. This workflow requires independent review in `stages/7-implementation.md` for exactly that reason; this skill exists for agents that skip it or perform it as a formality.

## What the reviewer gets

Brief a fresh agent context (a subagent, or a second session) with exactly these, and nothing that presupposes the answer:

1. **The diff under review**, or the file list when the change is new files.
2. **The owning issue** from `workspace/documentation/issues/`, whole: objective, constraints, acceptance criteria, verification tiers.
3. **`guidelines/coding-standards.md`**, whole. This is the standard being reviewed against. Do not summarize it into the prompt; the summary will contain your interpretation, which is part of what is under review.
4. **The named requirement and architecture sections** the issue references, from `requirements.md` and `architecture.md`.
5. The instruction below, verbatim.

Do not include your own assessment, your test results as established facts, or any sentence of the form "this is believed correct because". The reviewer confirms or refutes; it must not start from your conclusions.

## The instruction to the reviewer

> Review this change against `guidelines/coding-standards.md` and the owning issue. For every finding, cite the file, the specific rule or issue constraint violated, and the concrete consequence. Verify claims instead of accepting them: for each test said to cover a behavior, name the implementation change that would make it fail, and treat a test that cannot fail as a finding. Check that evidence labels (observed / inspected / inferred) match how each fact was actually established. Check whether the change incorporates the behavior coherently or layers a tactical patch on the existing design, per the Strategic Modification section. A review that finds nothing must list what was checked and how each check could have failed; "looks good" with no record of what was examined is not a review result.

## Handling the findings

- Address every finding, or decline it with a written reason in the issue. Silently dropping a finding is worse than never reviewing.
- A finding about your records (a wrong label, an unverified claim, a stale document) is as blocking as a finding about code. This workflow's history includes a review round where most blocking findings were in the records, not the code.
- When a finding is correct, fix it and rerun the checks the fix could have broken. When it is wrong, say why in the issue, with evidence, so the disagreement is inspectable later.
- Record the review's outcome in the owning issue: who reviewed, what was found, what was done about each item.

## Boundaries

- This skill does not replace anything in `stages/7-implementation.md`. It is a way to perform the review that stage already requires.
- It cannot mark an issue Done, approve a stage, or waive a check. Where this file and a stage document disagree, the stage document is correct.
- One clean review is evidence about this change only. It does not accumulate into permission to skip the next one.

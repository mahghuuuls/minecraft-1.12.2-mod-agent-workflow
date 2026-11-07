# Independent Review Brief

## Purpose

Write the brief that puts a fresh reviewer in front of a change, an evidence record, or a mod page, so that the review can disagree with its author.

This callable procedure owns the reviewer handoff. `stages/7-implementation.md` owns implementation reviews and `stages/8-release-presentation.md` owns mod-page reviews, including readiness, finding classification, and disposition.

## When To Use

Use this procedure every time `stages/7-implementation.md` requires an independent review:

- A code review of an implementation issue at **Review**.
- An evidence review of an evidence-only issue, where the deliverable is a confirmation, a verification, or an investigation rather than a diff.
- The follow-up review of a campaign's results file and corrections, before any included issue moves to **Done**.

Use [Mod Page Review](#mod-page-review) when `stages/8-release-presentation.md` calls for independent review or focused verification.

Review-agent initiation is governed by `guidelines/collaboration-guidelines.md#required-read-only-review-agents`; the owning stage still determines when the review is ready and required.

## Required Inputs

For implementation reviews, gather the following inputs. Mod-page inputs are listed in [Mod Page Review](#mod-page-review).

- The owning issue, whole.
- The items `stages/7-implementation.md` lists under "The review agent must receive" for a code review, or under the evidence-only paragraph for an evidence review.
- For a campaign follow-up: the session map, the results file, the staged logs and screenshots, and the pack manifest when one exists.

## Boundaries

- The reviewer runs in a separate agent context: a subagent or a second session, never the context that wrote the change or the record.
- The brief carries documents and paths, not the author's conclusions. Do not include your own assessment, your test results as established facts, or any sentence of the form "this is believed correct because". The reviewer confirms or refutes; it must not start from your conclusions.
- Do not summarize a guideline into the brief. The summary contains your interpretation, which is part of what is under review. Name the file and have the reviewer read it.
- The reviewer reads and reports. It does not edit the project, run the game with the owner, or approve anything.

## Procedure

For implementation reviews, follow these steps.

1. Name the review kind: code, evidence-only, or campaign follow-up. The kind decides which list in `stages/7-implementation.md` the brief follows.
2. List the inputs by path. For a code review, every item under "The review agent must receive". For an evidence review, the criterion, each evidence item with its label, the environment tier each came from, and the raw material. For a campaign follow-up, the map, the results file, the staged evidence, and each included issue's criteria.
3. State the rules the reviewer applies, by file: `guidelines/coding-standards.md` for code, `guidelines/manual-validation.md` and the Evidence Labels section of `stages/7-implementation.md` for evidence.
4. Give the instruction below, adapted to the kind, and nothing that presupposes the answer.
5. Ask for the report in the three groups `stages/7-implementation.md` defines (Blocking findings, Architecture/process findings, Improvement suggestions), each finding with its file and line or its results line, the rule or criterion involved, and the concrete consequence. Ask for one short paragraph per finding and a closing list of what was checked and how each check could have failed.
6. Read the report against the sources it cites before acting on it. A finding that cites a line which says something else is itself a finding about the review.
7. Handle every finding as `stages/7-implementation.md` says: address it, or decline it with a written reason in the issue. Record the review's outcome in the owning issue: who reviewed, what was found, what was done about each item.

## The Instruction To The Reviewer

For a code review:

> Review this change against `guidelines/coding-standards.md` and the owning issue. For every finding, cite the file, the specific rule or issue constraint violated, and the concrete consequence. Verify claims instead of accepting them: for each test said to cover a behavior, name the implementation change that would make it fail, and treat a test that cannot fail as a finding. Check that evidence labels (observed / inspected / inferred) match how each fact was actually established. Check whether the change incorporates the behavior coherently or layers a tactical patch on the existing design, per the Strategic Modification section. A review that finds nothing must list what was checked and how each check could have failed; "looks good" with no record of what was examined is not a review result.

For an evidence review or a campaign follow-up, add:

> Judge whether each label is correct, whether an inferred claim is presented as observed, whether an absence requirement was checked in an environment that could satisfy it at all, and whether the evidence reaches the criterion or merely surrounds it. Compare each card's expected result with the criterion it claims to check. Name every criterion, or part of one, that no card reached: a craft never performed, an effect never applied, an item never looked at. Open every cited log line and file; a citation you could not open is a finding. Downgrading a label is a blocking finding.

## Mod Page Review

1. Start each applicable persona in a separate context without the writing conversation. Send the assigned role, the review rules in `stages/8-release-presentation.md`, and the same identified page revision with its reader-visible context. Include the visible title, metadata, links, and any available preview. Ask the reviewer to record a short reader verdict and which relevant questions the page answers, leaves unclear, or directs to a link before opening supporting documentation.
2. After that reviewer records first impressions, provide release-matched sources by path, such as approved requirements, glossary terms, shipped defaults or metadata, implementation evidence, and relevant public documentation. Identify which sources a reader can access. Ask the reviewer to check claims and links and retain any navigation finding where the page lacks a useful route to the answer. Keep the author's rationale and other reviewers' feedback out of the initial round.
3. Ask for a concise report with the reader verdict and a stable ID for each finding. Include the passage or omission, Stage 8 category and severity, concrete reader impact, proportionate correction, and supporting source or verification limit. A report with no significant findings still states what was checked. Record the reports and dispositions in the Stage 8 presentation record.
4. For focused verification, give a separate reviewer the revised draft, changed passages, applicable finding IDs, and relevant evidence. Use an original reviewer when available. Ask whether the changes resolved the findings and introduced any new problems. Keep the check scoped to those changes and any regressions they caused.

## Completion

The brief is complete when the reviewer receives the inputs and instructions for each applicable pass without being told what to conclude. Record implementation review results and finding dispositions in the owning issue. Record mod-page review results and finding dispositions in `release-presentation.md`. The owning stage defines the completion criteria.

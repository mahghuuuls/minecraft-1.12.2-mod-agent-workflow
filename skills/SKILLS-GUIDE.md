# Skills Guide

What each optional skill does, the failure it remedies, when it earns its place, and which models showed the need for it. For installation, see [README.md](README.md).

Every skill here is a **remedy**. Each one exists because a specific agent failure was observed while running this workflow, and correcting it in every message got tiresome. If your agent is following the workflow as written, none of these will improve anything.

The skills are also starting points, not finished products. If one almost fits, ask your agent to tweak it - the wording, the rules, the output shape - until it matches how you work.

The model notes below record where each need was observed. They are not verdicts on those models, and a stronger model can fail the same way on a bad day - most of the evidence-discipline failures below were produced by a top-tier model and caught by review, not avoided by capability.

---

## Communication remedies

### `plain-language`

Re-explains the agent's own last message in simpler words. Every fact, path, number, and decision survives verbatim; only the explanation around them gets simpler.

**Failure it remedies:** answers that are technically correct and hard to follow - dense, jargon-heavy, structured like documentation when a conversation was wanted.

**Where observed:** Claude Opus 5, persistently. Walls of text and heavy jargon were the standing complaint of this workflow's first full project, well documented in its session history, and this skill plus `bottom-line` were the working fix.

### `bottom-line`

Strips the last message down to what is wrong and what could happen next, in a few lines, with no technical detail at all. The sharper instrument; read its rules before adopting it, because it forbids things a normal answer includes.

**Failure it remedies:** the same as `plain-language`, but when even the simplified version is too much and the user needs only problems and options.

**Where observed:** Claude Opus 5, same history.

---

## Process remedies

### `validation-session`

Runs an owner-assisted manual validation session the way `guidelines/manual-validation.md` specifies: preparation before the owner opens the game, one card at a time, the agent reading logs itself, the owner asked only for what a log cannot hold.

**Failure it remedies:** validation sessions that waste the owner's time - cards without a starting state or an expected result, the owner asked to retype output the agent can read, restarts that better grouping would have avoided.

**Where observed:** Claude Opus 5 sessions, where card-writing defects were caught repeatedly by the owner (a card that named the wrong icon; a card that said to type a command without saying where, so it was run in the terminal).

### `standards-review`

Briefs an independent reviewer against `guidelines/coding-standards.md` and the owning issue, with an instruction that forbids rubber-stamping, then makes the findings get handled on the record.

**Failure it remedies:** skipping the independent review the workflow requires, or performing it as a formality by reviewing one's own work in the same context that wrote it.

**Where observed:** prompted by Gemini 3.1 Pro and Gemini 3.7 Flash, which had trouble following `guidelines/coding-standards.md` and skipped or shallowed the review step. But the strongest evidence for it comes from Claude Opus 5: in this workflow's first project, eight issues were marked Done without the required review, and when the reviews were finally run they returned fourteen blocking findings - three code defects and eleven defects in the project's own records.

---

## Evidence remedies

These three guard the thing this workflow exists to protect: that the records mean what they say. All three encode failures produced by Claude Opus 5 and caught by independent review or by mechanical re-checking, so treat them as useful for any model, strong ones included.

### `evidence-audit`

Re-verifies an issue's completion evidence claim by claim: every observed / inspected / inferred label checked against how the fact was actually established, every cited file, commit, and quote reopened rather than trusted.

**Failure it remedies:** evidence-label inflation - writing `(observed)` because the claim feels true. Three separate reviewers independently caught this in one project. The worst single instance: an issue citing a server log that predated its claimed commit by three commits, and quoting a line from a different file than the one it named.

**When to run it:** whenever an issue is about to be marked Done on evidence nobody has re-checked, and before any release that leans on the records.

### `prove-it-can-fail`

Temporarily reverts the fix or mutates the guarded code, runs the suite, and confirms the new tests actually fail. A test that passes either way is reported as a finding.

**Failure it remedies:** verification that agrees with itself. A test written by the fix's author encodes the author's assumptions and can pass with the fix absent. Run twice in one day here, it caught a worthless test both times - one had a fixture incomplete in a way that made the code save a file for an unrelated reason, so the assertion could never miss.

**When to run it:** after writing tests for a fix, and especially when the tests were written by the same agent that wrote the fix, which is nearly always.

### `records-sync`

Reconciles the status ledgers against git, the issue files, and the code, and corrects the drift on the record.

**Failure it remedies:** paperwork falling behind the work. Documented instances: a ledger naming a superseded issue as the next action days after it died; a commit count drifted by four because it was incremented by hand instead of counted; requirements describing four placement edges while the shipped code had two.

**When to run it:** before any stage transition, approval decision, or release - the moments where a stale record silently becomes a wrong decision.

---

## The habit remedy

### `read-before-resume`

Re-reads the authoritative documents - entry point, ledgers, current stage, the relevant guideline - before acting, at session start or after a context break, and verifies the recorded next action against reality before performing it.

**Failure it remedies:** working from a mental copy of documents read earlier, which is a summary that silently dropped the qualifications and missed every edit since.

**Where observed:** Gemini 3.1 Pro and Gemini 3.7 Flash most sharply, but any model after context compaction, where the session's own summary replaces the documents and compresses exactly the parts that mattered.

**Honest caveat, stated in the skill itself:** this is the weakest remedy here. A skill can put the documents in front of an agent; it cannot make one read. If invoking it repeatedly changes nothing, the fix is a more capable agent.


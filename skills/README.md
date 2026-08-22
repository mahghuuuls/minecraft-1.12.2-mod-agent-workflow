# Optional Skills

Skills in this directory are **optional**. The workflow does not require them, does not reference them from any stage, and works exactly the same whether or not you install any of them.

In my experience, ChatGPT's 5.6 Sol models (medium and higher) follow this workflow well without any skill. Claude's Opus 5 does the work to the workflow well enough, but needs the explanation skills heavily. Google's Gemini 3.1 Pro and Gemini 3.7 Flash skip many of the workflow's requirements, and making them follow it takes significant effort even with the skills. You can still build a working mod with them, but expect more code revision and more effort on your part to think up test scenarios.

## When to reach for one

Use a skill when an agent is not behaving the way the workflow already asks it to.

The stage documents and `guidelines/` already say how an agent should work and how it should report. A capable agent following them needs nothing here. But agents differ, and some drift in ways that are tiresome to correct by hand every time: long answers when a short one was asked for, jargon where plain words would do, or skipping the parts of a procedure that make its evidence worth anything.

A skill does not fix the drift; the agent will do it again. What it replaces is typing the same correction out each time. You invoke the skill by name instead, as often as the problem recurs.

**If the agent is already following the workflow, adding these will not improve anything.** They are a remedy, not an upgrade.

## The Skills

Start from the symptom:

- Answers hard to follow: `plain-language`, then `bottom-line` if still too much.
- Owner time being wasted in testing: `validation-session`.
- Work merged without real review: `standards-review`.
- Records that say more than anyone saw: `evidence-audit`.
- Green tests you do not trust: `prove-it-can-fail`.
- Paperwork behind the work: `records-sync`.
- Agent resuming in the wrong place or on stale rules: `read-before-resume`.

Install only what the observed problem calls for. The failure log, not the catalogue, is the shopping list. Full detail on each skill, including the documented failures behind it, is in **[SKILLS-GUIDE.md](SKILLS-GUIDE.md)**.

- **`plain-language/`** re-explains the agent's last message in simpler words, with every fact, path, and number kept exact. Use it when answers are correct but hard to follow.
  *Useful for Claude Opus 5.*

- **`bottom-line/`** strips the last message down to what is wrong and what could happen next, in a few lines with no technical detail. Use it when even the simplified version is still too much.
  *Useful for Claude Opus 5.*

- **`validation-session/`** runs owner-assisted manual validation the way `guidelines/manual-validation.md` specifies: setup done before the game opens, one card at a time, logs read by the agent, the owner asked only for what a log cannot hold. Use it when in-game tests keep arriving without a starting state or a defined expected result.
  *Useful for Claude Opus 5.*

- **`standards-review/`** briefs an independent reviewer against `guidelines/coding-standards.md` and the owning issue, then makes the findings get handled on the record. Use it when changes keep being marked done without a real review behind them.
  *Useful for Gemini 3.1 Pro and Gemini 3.7 Flash.*

- **`evidence-audit/`** re-verifies an issue's completion evidence claim by claim: labels checked against how each fact was actually established, every cited file and commit reopened. Use it before trusting records nobody has re-checked.
  *Useful for any model; the failures it encodes came from Claude Opus 5.*

- **`prove-it-can-fail/`** temporarily breaks the code to confirm the new tests actually fail, and reports a test that passes either way as a finding. Use it when green tests were written by the same agent that wrote the fix.
  *Useful for any model; the failures it encodes came from Claude Opus 5.*

- **`records-sync/`** reconciles the status ledgers against git, the issue files, and the code, and corrects the drift on the record. Use it before stage transitions, approvals, and releases.
  *Useful for any model; the failures it encodes came from Claude Opus 5.*

- **`read-before-resume/`** re-reads the authoritative documents before acting, instead of working from memory of them. Use it at session start, after context compaction, or when an agent keeps resuming in the wrong place.
  *Useful for Gemini 3.1 Pro and Gemini 3.7 Flash, and for any model after context compaction.*

## Installing

Ask your agent to install the skill you want from this directory. Agents know their own skills location and can copy the directory there themselves; each skill is a single Markdown file with a small frontmatter block, so any agent tool that accepts instructions as text can use it.

Once installed, invoke it by name.

Install only what you need. There is no benefit to installing all of them.

## Changing them

They are yours once copied. Rename them, edit the rules, or throw them away. If one almost fits, ask your agent to tweak it until it matches how you work.

## A note on scope

Nothing here changes what the workflow requires. A skill cannot approve a stage, waive a check, or make evidence out of an unobserved claim. If a skill and a stage document disagree about what must happen, the stage document is right and the skill needs fixing.

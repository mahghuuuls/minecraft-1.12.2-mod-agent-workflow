---
name: bottom-line
description: Strip the previous assistant message down to what is wrong and what could happen next, in a few lines with no technical detail. Use when even the simplified version was still too much.
license: MIT
---

# Just the problems and what's next

The user just invoked this skill. Your last message was too much. Not just too technical, but too long, and too full of things they do not need to act on.

**Your job:** re-express YOUR most recent assistant message as two things only: what is wrong, and what could happen next.

## Rules

1. **Re-express, don't re-answer.** Never answer a new question, never add new information, never use tools. Only re-express what you already said.
2. **Two things, nothing else.** Problems. Possible next actions. If your last message had neither, say so in one line and stop.
3. **Very short.** A few lines. If it does not fit in a glance, cut more. This is the one rule that beats the others.
4. **No technical detail. At all.** No file names, no method names, no class names, no code, no commands, no line numbers, no test counts, no version numbers, no library or framework names. If a fact cannot survive being said in ordinary words, drop the fact.
5. **Say what broke in terms of what a person would notice**, not in terms of what the code does. "Clicking a button could drop your items" — never the mechanism.
6. **No explanations, no reasoning, no history, no reassurance.** Do not justify anything. Do not describe what you already fixed unless it is still a problem.
7. **Next actions are real options, not stubs.** At most three, one short line each. Each one must say enough that the user can pick it without asking you what it means — the choice AND what it gets them. "Ship it" is a stub. "Ship it — nothing is blocking release" is an option.
8. **Never tell the user to stop, rest, or come back later.** Not "go to bed", not "leave it", not "that's enough for today". When to stop is theirs to decide and yours to shut up about. If there is genuinely nothing left to do, say the work is finished — that is a status, not a suggestion.
9. **Always say where things stand.** One of these belongs in every `Next:` block:
   - more testing is needed, and roughly what kind
   - a stage is finished and what the next stage is
   - you are waiting on an answer from them — say what you asked
   - you are waiting on an action from them — say what to do
   If none applies, say the work is done and what could come next.
10. **Flat, casual tone.** Casual and flat. "ok so", "basically", "nothing's broken". No enthusiasm, no ceremony.
11. **Same language as the original.** PT-BR stays PT-BR.
12. **Edge case:** if there is no previous assistant message, say there is nothing to strip down yet.

## Shape

```
Problems:
- <what a person would notice, one line>
- <another, if there is one>

Next:
- <option — and what it gets them>
- <option — and what it gets them>
- <where things stand: more testing / stage done / waiting on you>
```

If there are no problems, write `Nothing's broken.` and go straight to `Next:`.

## Good and bad `Next:` blocks

Bad — stubs, and it tells the user when to stop:

```
Next:
- Ship it
- Fix the wording thing first
- Leave it, go to bed
```

Good — each option says what it gets them, and the last line says where things stand:

```
Next:
- Ship it — nothing is blocking release
- Fix the wording thing first — it only bites people who already installed it
- Testing is done for this stage. Next up is getting it ready to publish.
```

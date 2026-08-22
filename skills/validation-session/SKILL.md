---
name: validation-session
description: Run an owner-assisted manual validation session for a mod issue, the way this workflow specifies. Prepares the bundles, sets the config, presents one test card at a time, reads the logs itself, and asks the owner only for what the logs cannot show. Use when the owner invokes it by name, or asks to test, validate, or run the cards for an issue.
license: MIT
---

# Owner-Assisted Validation Session

The owner is about to sit at a game client. Their time is the scarce resource here. Everything that
can be prepared, automated, or read from a file is yours to do; what is left for them is gameplay
and the things only a human can see or hear.

## Read these first, every time

They are authoritative and they change. Do not work from memory of them, and do not copy them into
the session; read them.

1. `guidelines/manual-validation.md` — the card format, the card-writing rules, the evidence split,
   failure handling, cleanup. This is the contract.
2. `guidelines/agent-diagnostics-toolkit.md` — what belongs in a bundle and what a setup bundle
   should always do.
3. The owning issue in `workspace/documentation/issues/` — its **Verification** tiers, its **Manual
   Observability** contract, and its **Acceptance Criteria**. The Manual Observability section names
   the authoritative state, the corroborating evidence, the reset state, the cleanup, and what only
   the owner can observe. Those fields are the session's plan; do not invent a different one.
4. The pinned toolkit's own `AGENTS.md` before authoring any bundle.

Find the workflow root by walking up from the working directory to the folder holding `guidelines/`
and `workspace/`.

## Which issue

Take it from the argument (`/validation-session IMP-012`). With no argument, look for the issue at **Awaiting
Validation**, or the one just implemented. If more than one is open, name them and ask which — that
is a question worth one round trip.

## Before the owner starts the game

Do all of this first. A session that stops because a bundle has a typo has wasted the expensive part.

- **Build and check.** Run the compile and the suite. Never open a session on code that does not
  build.
- **Write the bundles.** Every deterministic sequence of commands — setup, reset, inspection, marks,
  teardown — belongs in a project bundle, not in the owner's hands. A card should normally carry
  only `/devtool reload`, one `/devtool run <name>`, and the gameplay.
- **Parse the bundle JSON before handing it over.** A bundle that fails to load costs a restart.
- **Check every command against 1.12.2.** Syntax, selectors, registry names, NBT. A command that
  errors in game is a wasted round trip.
- **Set the configuration yourself.** Say exactly which file and which values, and remember this mod
  family has no config screen: a config change means editing the file and restarting. Group the
  cards so the session needs the fewest restarts.
- **Preserve any log that a restart would rotate away.**
- **Present one session map**, then stop. The map is: the runtime, the ordered card titles and what
  each shows, the config groups and their values, every restart point, the shared setup and final
  cleanup, which bundles will be used, and which observations you will need from them. It is a map,
  not the cards.

## During the session

**One card at a time.** Batch only when the cards are independent, share exactly the same state, and
cannot make each other ambiguous. Use the card format from `guidelines/manual-validation.md` exactly,
and keep the headings identical from card to card so the owner never has to relearn it.

**Between cards, read the logs yourself.** `run/logs/latest.log` and the rotated ones. Check the
bundle's end record, its failures, its readiness marks, and the categories it enabled — a bundle
whose command was accepted is not a bundle that ran. For stateful or failure-sensitive cards, read
the evidence before sending the next card.

**Ask for one thing only: what the logs cannot hold.** Visual layout, animation, colour, sound,
whether an input felt right, real multi-client behaviour, an environment whose files you cannot
reach. Everything else — counts, occupancy, config, registry state, command output, diagnostic
records — you read yourself. Never ask the owner to retype something you can read.

**Define the expected result before the action**, including the detail that would look different if
the feature were broken or absent. "It worked" is not a result; "compartment 2 went from 3 to 4 slots
used and the log names compartment 2" is.

**State the starting state completely.** Never rely on them remembering a hotbar slot, a game mode, a
config value, or a toggle from ten minutes ago. Include a reset step whenever state can leak, and
make the reset observable when an unapplied reset could look like a pass.

**Say whether to keep the game open.** Every card ends by saying so.

## When something fails

- Stop the cards that depend on it.
- Preserve the state if it helps diagnosis; otherwise give an explicit cleanup step.
- Read the accessible evidence before asking them to repeat anything.
- Ask only the one question that separates the plausible causes.
- If your card was wrong — bad command, wrong expectation, wrong fixture — say so plainly, correct
  it, and explain what changed.
- Completing the actions is not passing. A card passes when the evidence says so.

## At the end

- Say which cards passed, failed, were deferred, or were waived.
- Read the final evidence and write the result into the owning issue, including anything that went
  unobserved. An unobserved card is not a passed card, and recording the gap is how it gets picked
  up by the next session instead of being lost.
- Turn off temporary diagnostics. Restore temporary config and world state.
- Say whether they can close the game.
- Do not make them restate anything they already reported.

## Reporting style

The owner is tired by the time they are testing. Short sentences. Exact paths and commands in code
blocks, one command per block. No requirement IDs, architecture IDs, or evidence theory in a card
unless they need it to perform the check. Tell them what to do, what you will check, and when they
are done.

## How the owner wants to be talked to

The owner is tired. Treat every word you send during a session as a cost to them.

- Write for a five year old. No jargon. If a word needs explaining, use a different word.
- Give exactly what to do. A short numbered list of steps. Nothing else.
- Do not explain why. Not the design, not the bug, not the reasoning, not the history. You keep all
  of that; they do not need it to click a mouse.
- Keep it small. A card should fit on one screen with room to spare.
- Commands in their own code block, one command per block, exact.
- Say what they should see, in plain words, because they cannot report a mismatch without it. That
  is not an explanation, it is the check.
- Say what to do when they are done.

Never send a wall of text mid-session. If you catch yourself writing a paragraph, cut it.

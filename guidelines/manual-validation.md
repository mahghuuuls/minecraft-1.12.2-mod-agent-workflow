# Owner-Assisted Manual Validation

This file is the authoritative source for presenting owner-assisted runtime checks and dividing evidence collection between the owner and the agent.

Use it when an approved implementation issue requires the owner to interact with a Minecraft client, dedicated server, modpack, alternate runtime, or external multiplayer environment. Verification quality and evidence labels remain governed by `guidelines/coding-standards.md` and `stages/7-implementation.md`; this file governs the human execution interface.

## Goals

- Make each requested action difficult to misread or perform in the wrong state.
- Minimize restarts, configuration churn, repeated prose, and owner transcription.
- Tell the owner why a check exists without exposing internal planning detail they do not need to execute it.
- Collect logs and other agent-accessible evidence directly instead of making the owner relay it.
- Make a successful result easy to report and a failed result precise enough to investigate.

## Before The Session

Before the owner starts a shared game, server, or modpack session, present the complete known validation matrix for that runtime. Keep it compact, but disclose:

- The runtime and environment tier.
- The ordered card titles and what each demonstrates.
- Configuration groups and their exact values.
- Every required start, restart, reconnect, or shutdown point.
- Shared setup, safety preparation, and final cleanup.
- The exact source revision or validation checkpoint used by the runtime and confirmation that its mod worktree is clean.
- Which evidence the agent will inspect and which observations only the owner can supply.
- Whether the Agent Diagnostics Toolkit is active, its pinned version and runtime placement, any approved automatic baseline, and the bundle names used during the session.

Group cards by configuration state and minimize restarts. Do not reveal previously known checks one at a time after the runtime is already open. This overview is a session map, not the detailed procedure for every card.

When the Implementation Plan defines an owner-assisted validation campaign spanning several issues, present one campaign session map and retain each card's issue attribution internally. Do not make the owner manage issue boundaries that do not change the actions, but do preserve enough diagnostic separation for the agent to assign every result correctly.

## Test Card Format

During execution, normally present only the next test card. A small batch is acceptable when the cards are independent, use exactly the same state, and cannot make one another ambiguous. Use this structure and omit fields that genuinely do not apply:

```markdown
### Test: <short player-facing name>

**Purpose:** <one sentence explaining the behavior this distinguishes>

**Starting state**

- <required runtime, screen, equipment, config, or prior card state>
- <exact reset command or setup action when state could carry over>

**Do this**

1. <exact command or physical action>
2. <next action>

**Owner checks**

- <only visual, audio, interaction-quality, or otherwise agent-inaccessible results>

**I will verify**

- <logs, counters, files, or authoritative values the agent will inspect directly>

**Report:** Reply `Done` after completing **Do this** if every listed **Owner checks** item passed. When **Owner checks** is omitted, `Done` confirms that the actions were completed without a visible anomaly. Otherwise report only the mismatch or unexpected behavior.

**After this test:** <keep the game open, close it, preserve state, or perform cleanup>
```

Keep headings and language stable across cards so the owner does not have to relearn the format.

## Card-Writing Rules

- Put commands in copyable code blocks and list them in execution order.
- When the selected Agent Diagnostics Toolkit supports the required operations, package every deterministic multi-command setup, reset, inspection, marker, and cleanup sequence as a project-owned bundle. The owner-facing card should normally contain only its reload command, its named run command, and genuinely interactive or judgment-dependent steps. Keep the individual commands in bundle source and evidence documentation for auditability.
- When a deterministic sequence cannot be bundled because the selected toolkit lacks a required operation, state that limitation in the plan and present the commands together in one copyable block. Convenience alone is not a reason to make the owner enter a supported sequence manually.
- Distinguish commands from mouse, keyboard, inventory, combat, waiting, or observation steps.
- State the complete starting state. Never rely on the owner remembering an earlier temporary config value, selected hotbar slot, equipped item, game mode, mana value, or diagnostic toggle.
- When a shared setup applies to several consecutive cards, state it once in the session map and identify the exact state or delta each card requires.
- Include a reset step whenever state can leak from a prior card. A reset must be observable or independently checkable when an unapplied reset could produce a false pass.
- Define expected results before the action. Include the distinguishing condition that would look different if the feature were absent or broken.
- Keep requirement IDs, architecture IDs, implementation history, and evidence theory out of the owner-facing card unless they are necessary to perform the check.
- Verify Minecraft 1.12.2 command syntax, selectors, registry identifiers, fixture behavior, and cleanup commands before presenting them.
- State whether the owner should keep the game or server open. Do not leave the runtime lifecycle implicit.
- Do not ask the owner to repeat authoritative values, diagnostic output, log lines, or file content the agent can inspect directly.
- Do not advance from a toolkit-assisted card until the agent has checked bundle completion and readiness marks when later evidence depends on them.
- Keep **Owner checks** limited to visual, audio, interaction-quality, real-multiplayer, or external-environment observations unavailable to the agent. Numeric state, command output, configuration, dimensions, registry state, and retained diagnostic records belong under **I will verify** whenever accessible.
- Ask a specific owner-only question only when `Done` cannot capture a required inaccessible observation.

## Evidence Handoff

The owner performs the interaction. The agent collects every accessible current and rotated log, generated file, command result, counter, artifact, or other planned evidence after the card.

Use **Owner checks** only for evidence the agent cannot reliably obtain, such as:

- Visual layout or animation.
- Audio.
- Perceived input or interaction behavior.
- Real multi-client privacy or isolation.
- Behavior in an external environment whose files the agent cannot access.

Use **I will verify** for accessible authoritative evidence. Do not ask the owner to transcribe it. A self-reported diagnostic still requires the independent corroboration defined by the issue's Manual Observability contract.

For stateful, failure-sensitive, or fixture-sensitive cards, inspect the planned evidence before sending the next card. For independent visual cards, a small batch may be completed before log inspection when the shared evidence remains attributable.

## Failure And Revision

When the owner reports a mismatch:

- Stop dependent cards.
- Preserve the current state when it may help diagnosis; otherwise give an explicit cleanup step.
- Inspect accessible evidence before asking the owner to repeat the check.
- Ask only for the missing observation needed to distinguish plausible causes.
- If the fixture, command, or expected result was wrong, correct the card and explain the material change.
- Do not count a check as passed merely because the owner completed the actions.

## Completion And Cleanup

At the end of the session:

- State which cards passed, failed, were deferred, or were waived.
- Inspect the final accessible evidence and record it in the owning issue.
- Disable temporary diagnostics and restore temporary configuration or world state.
- State whether the owner may close the client/server or whether another approved session remains.
- Do not make the owner restate successful observations already covered by `Done`.

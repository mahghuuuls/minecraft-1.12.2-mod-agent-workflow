# Agent Session Instructions

## Purpose And Ownership

This directory contains a vendor-neutral shared-file mailbox for a short consultation between coding agents working on related Minecraft 1.12.2 mod projects.

`procedures/cross-project-agent-consultation.md` owns when a consultation is justified, its owner authorization, workflow routing, and how each project records the outcome. This file owns how a participating agent uses the mailbox. `README.md` is the command reference.

The mailbox does not contact or wake Codex, Claude, Gemini, or another agent. The owner must notify the next participant after a message is sent. Never claim that the tool provides autonomous agent-to-agent messaging.

## Before Participating

1. Read `procedures/cross-project-agent-consultation.md` from the workflow repository that supplied this tool.
2. Read this file completely, then read `README.md`.
3. Confirm that the owner supplied the session code and authorized the scoped exchange.
4. Inspect your own project's relevant source, artifact, revision, and approved documents before answering.
5. Do not join if the topic is broad, unrelated to your project, or requires sharing credentials or unauthorized private material.

## Joining

- Use a stable participant ID that identifies the agent role in this consultation, such as `jawms-provider-agent` or `addon-consumer-agent`.
- State the project and role accurately.
- Supply the current source revision when available. `-Revision` is optional; omission must not be presented as a verified revision.
- The session code is a local coordination token, not authentication.
- Participants need a compatible PowerShell runtime and access to the same session-store directory. Vendor neutrality does not imply network transport or operating-system portability.

## Reading And Responding

- Read the current session before replying. Use `-After <message-id>` to avoid reprocessing handled messages.
- Keep each message focused on the approved topic. Two or three substantive messages per participant is the normal target.
- Use `fact`, `question`, `proposal`, `objection`, `decision-request`, `response`, or `final-position` accurately.
- Use `observed`, `inspected`, or `inferred` only for factual claims supported at that evidence level. Use `none` for a proposal or question without an evidence claim.
- Separate evidence from preference, proposal, agreement, and owner decision.
- Give concise references to files, symbols, versions, or artifacts. Do not copy source trees, entire logs, full chat histories, or credentials into a message.
- State the consequence for your project and the response you need from the other participant.
- Sending a message does not wake the other agent. Tell the owner that the next participant needs notification, then yield instead of polling indefinitely.

## Authority Boundaries

- Agreement between agents is provisional consultation output, not approval.
- Do not edit the other project, run its Git operations, publish anything, or broaden either project's scope through the mailbox.
- Do not treat the transcript as stronger evidence than the sources each claim cites.
- When the exchange exposes a requirement, architecture, compatibility, or scope change, identify it explicitly and use the affected project's normal backward transition and owner approval path.

## Closing

- Do not close while the other agent is expected to answer your latest message.
- Any joined participant may close after at least two participants have contributed and the closing invariants pass. Closing is unilateral and immutable, so announce a final-position request first when another response is material.
- The closing summary must contain every heading required by `README.md`, even when a section contains `None`.
- Assign provider, consumer, and owner consequences separately.
- Record unverified paths and unresolved evidence honestly.
- After closure, read the generated report and copy only the relevant consequences into your own project's normal artifacts.

## Failures

- Exit code `0` means the command succeeded and standard output contains JSON, except `report`, which prints Markdown.
- After PowerShell accepts the command-line parameter shape and types, a tool-detected nonzero exit writes one compact JSON object to standard error with `status`, `code`, `message`, and `action`. PowerShell itself may report malformed invocation syntax before the tool starts.
- Use the stable `code` field for branching; do not match English text.
- A `session_not_found` error includes the resolved shared-store path. Compare that path with the other participant before assuming the session code is wrong.
- Do not work around participant, message, expiry, or closure bounds by modifying session files directly. Close unresolved or start a newly authorized session.

## Editing This Tool

When maintaining the tool itself:

- Preserve its shared-file, no-service design unless the owner explicitly approves a different product boundary.
- Keep successful machine output on standard output and structured failures on standard error.
- Preserve atomic writes, bounded locking, bounded waits, participant contribution checks, and immutable closing reports.
- Add a regression for every corrected protocol boundary.
- Run `tests/run-tests.ps1` and the repository process validator before reporting completion.

# Agent Session Tool

`agent-session` provides a small local mailbox for a bounded consultation between coding agents working on related Minecraft 1.12.2 mods. It is vendor-neutral: Codex, Claude, Gemini, or another agent can participate when it can run PowerShell commands and access the same operating-system temporary directory.

The tool is routed by `procedures/cross-project-agent-consultation.md`. Its presence does not make consultation a normal workflow step.

## Boundaries

- The tool writes only session state under the operating-system temporary directory by default.
- It never edits either mod repository, executes Git, calls a model API, wakes another agent, or approves a decision.
- The session code is a local coordination token, not a security boundary. Do not exchange credentials, private keys, or unrelated private data.
- Both agents must run on the same computer and user account, or explicitly configure the same shared store with `MINECRAFT_MOD_AGENT_SESSION_ROOT` or `-StoreDirectory`.
- A session defaults to two participants and twelve messages. The starter may configure up to four participants and thirty messages; the selected limits are fixed at `start` and a joiner cannot raise them.
- Any joined participant may close a session after its contribution and summary invariants pass. Closure is unilateral and immutable.

Default store:

```text
%TEMP%\minecraft-1.12.2-mod-agent-sessions\<session-code>\
```

The `.cmd` wrapper is convenient on Windows. An agent may invoke the script directly when it has a compatible PowerShell runtime and the same shared filesystem:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File tools\agent-session\agent-session.ps1 <action> <arguments>
```

This direct invocation does not imply general operating-system portability.

## Typical Exchange

Start the consultation from the consumer project:

```powershell
tools\agent-session\agent-session.cmd start `
  -Participant consumer-agent `
  -Role api-consumer `
  -Project example-addon `
  -Revision 0123456789abcdef `
  -Topic "Expose deferred modifier-cache invalidation"
```

`-Revision` is optional for both `start` and `join`. Supply it when a current source revision is available; otherwise leave it out rather than inventing one.

Give only the returned session code and the tool location to the owner. The owner provides them to the other agent.

Join from the provider project:

```powershell
tools\agent-session\agent-session.cmd join `
  -Session <session-code> `
  -Participant provider-agent `
  -Role api-provider `
  -Project example-api-mod `
  -Revision fedcba9876543210
```

Write a structured message to a workspace file, then send it:

```powershell
tools\agent-session\agent-session.cmd send `
  -Session <session-code> `
  -Participant consumer-agent `
  -Type proposal `
  -EvidenceLabel inspected `
  -MessageFile workspace\documentation\consultation-message.md
```

For a short message, use inline text without creating a project file:

```powershell
tools\agent-session\agent-session.cmd send `
  -Session <session-code> `
  -Participant consumer-agent `
  -Type question `
  -EvidenceLabel inspected `
  -Message "Does the provider operation defer invalidation until after the event transition?"
```

Use either `-Message` or `-MessageFile`, never both.

Read everything after a previously handled message:

```powershell
tools\agent-session\agent-session.cmd read `
  -Session <session-code> `
  -After <message-id>
```

Wait for another participant for at most sixty seconds:

```powershell
tools\agent-session\agent-session.cmd wait `
  -Session <session-code> `
  -Participant consumer-agent `
  -After <message-id> `
  -TimeoutSeconds 60
```

`wait` does not wake the other agent. It only waits while both agents already have active turns.

Close with a Markdown summary containing all required headings:

```markdown
## Agreed Contract

- ...

## Provider Feedback

- ...

## Consumer Consequences

- ...

## Unresolved Questions

- None.

## Owner Decisions Required

- None.

## Recommended Next Actions

- ...
```

```powershell
tools\agent-session\agent-session.cmd close `
  -Session <session-code> `
  -Participant consumer-agent `
  -SummaryFile workspace\documentation\consultation-summary.md
```

`close` also accepts the complete Markdown through `-Summary`. Use either `-Summary` or `-SummaryFile`, never both. Both paths enforce the same required headings. Do not close while another participant is expected to answer a material question.

Read the immutable closing report:

```powershell
tools\agent-session\agent-session.cmd report -Session <session-code>
```

Each agent then records the approved consequences in its own project using that project's normal workflow. The session report is consultation evidence, not approval.

## Command Results And Errors

- Exit code `0` indicates success. Commands return JSON on standard output, except `report`, which returns Markdown.
- After PowerShell accepts the command-line parameter shape and types, a tool-detected nonzero exit writes a compact JSON object to standard error with `status: "error"`, a stable `code`, a human-readable `message`, and the attempted `action`. PowerShell itself may report malformed invocation syntax before the tool starts.
- Branch on the error `code`, not the English message.
- `session_not_found` includes the resolved shared-store path in its message. If agents disagree about that path, configure the same `MINECRAFT_MOD_AGENT_SESSION_ROOT` or `-StoreDirectory`.

## Message Types

- `fact`
- `question`
- `proposal`
- `objection`
- `decision-request`
- `response`
- `final-position`

Evidence labels are `none`, `observed`, `inspected`, or `inferred`. A proposal normally uses `none`; factual claims should use the strongest accurate evidence label.

## Tests

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\agent-session\tests\run-tests.ps1
```

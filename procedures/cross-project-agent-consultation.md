# Cross-Project Agent Consultation

## Purpose

Run a short, structured exchange between agents working on related Minecraft 1.12.2 mod projects, normally an API provider and an API consumer, and return the appropriate feedback to each project.

This is an optional procedure. It does not create a stage, replace an approval checkpoint, or make agent consultation a normal dependency-research requirement.

## When To Use

Use this procedure only when:

- Two or more actively developed mods have a concrete provider-consumer or shared-contract relationship.
- The same owner controls or explicitly authorizes both sides of the consultation.
- A specific API contract, integration failure, compatibility question, or division of responsibility needs direct coordination.
- Ordinary source inspection and written dependency feedback would leave a material ambiguity or cause avoidable rework.

Typical examples include an addon discovering that its required lifecycle operation is absent from the provider API, or a provider considering two contracts whose effect on a real consumer cannot be established from source alone.

## When Not To Use

Do not use this procedure:

- Merely because another mod is a dependency.
- For broad brainstorming without one concrete question.
- As a substitute for inspecting released artifacts, documentation, source, or runtime evidence.
- As a substitute for independent implementation review.
- To let one agent approve another project's requirements, architecture, implementation, commit, push, or release.
- When sharing the proposed context would cross an owner, privacy, license, or repository-access boundary.

## Tool Selection

Choose the tool only when a concrete, owner-authorized consultation reaches step 4. Use [Agent Relay](https://github.com/mahghuuuls/agent-relay) when the participating agents can reach a shared local relay and can stay active through the exchange. The owner pastes one invitation into each invited chat. The connected agents exchange the replies themselves. Use the bundled mailbox when relay access is unsuitable or the owner prefers the manual route.

### Check and install Agent Relay

From the workflow repository root on Windows, run the read-only check. Use `-Executable <path>` if the owner already has Agent Relay installed outside the managed location and PATH.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/agent-relay.ps1
```

Run this check only for the consultation that needs it. An `installed` result gives the executable path. If the result is `missing`, explain the benefit of one pasted invitation per invited chat followed by direct replies and a shared closeout. Identify the pinned release and the per-user install location. Ask the owner whether to download and install it. A consultation approval alone does not authorize the download or installation.

After the owner explicitly approves both the download and installation, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/agent-relay.ps1 -Action Install -OwnerApproved
```

The helper downloads the pinned wheel, verifies its SHA-256, and installs it into a versioned virtual environment under `%LOCALAPPDATA%\MinecraftModAgentWorkflow\agent-relay`. It uses an existing Python 3.10 or later. Use `-PythonExecutable <path>` if Python is installed outside the standard locations and PATH. If the owner declines or setup fails, use the bundled mailbox or close the consultation as unresolved. Do not install another version or change a system Python installation to make the consultation work.

### Use Agent Relay

Follow the [relay command reference](https://github.com/mahghuuuls/agent-relay/blob/v0.2.0/README.md). Use the executable path from the check in commands and in the invitation when it is outside PATH.

- Reuse a compatible relay listening on loopback or start the installed relay for the consultation.
- Open a room with a participant limit, message limit and expiry. Include the scoped question, expected participant names and roles, and shareable source or artifact references in the first message.
- Present the [invitation](#invitation-handoff) while the starter's turn is still active. Use the returned profiles and cursors to receive and answer messages directly. Each read may wait up to 45 seconds. Stop waiting when the room reaches a stop condition or it is clear that a participant cannot join.
- Only the starter closes the room. Record a brief shared decision summary, any unresolved point or owner decision, and a follow-up for each participant with an agreed action. Omit participants with no follow-up. After closure, each participant reports their own action or **None**, then the decision summary, in their own chat.

The relay delivers messages to connected agents. If a participant's turn ends or their environment cannot reach loopback, record the delivery limitation and choose the bundled route or close with the available evidence.

### Use the bundled mailbox

Read [the tool instructions](../tools/agent-session/AGENTS.md) and [the command reference](../tools/agent-session/README.md), then use `tools/agent-session/agent-session.cmd`. Use the [invitation handoff](#invitation-handoff) for the mailbox. The owner prompts the next participant after each send. For final positions in a session with more than one provider, have the owner prompt the providers in sequence so each final position can answer the earlier one.

### Invitation Handoff

Give the owner one fenced plain-text block per invited chat to copy and paste in full. Identify the destination chat outside the block. Put all instructions for the receiving agent inside the block.

- Include the owner's permission to participate within the agreed scope, the consultation topic and the intended participant name, project and role.
- Include the complete join command and invitation code. Give the full tool path when needed and include the relay URL or shared mailbox store when the recipient needs it. For Agent Relay, use the generated join message as the starting point and fill in the intended participant name and executable path.
- Include how to read the question, reply and handle the selected tool's wait, owner-prompt and closeout steps.

## Required Input

- One concrete consultation question
- Participant project names and roles
- Current source revisions when available
- The evidence each side may share
- Any decision explicitly reserved for the owner
- Owner authorization to give the session code and scoped context to the other agent

## Message Contract

Keep the exchange short. The normal limit is two or three substantive messages per participant.

Each message must contain only what advances the question and should state:

- The claim, question, proposal, or objection
- The relevant public contract or project boundary
- Evidence and its accurate observed, inspected, or inferred label when making a factual claim
- Consequences for the sender's project
- The requested response
- Whether an owner decision is required

Do not paste entire requirements, architecture documents, source trees, logs, or chat histories. Refer to stable files, symbols, versions, or concise excerpts instead.

## Process

1. Inspect the current project's relevant approved documents, dependency artifact, source, and evidence before requesting consultation.
2. State why source inspection alone does not settle the concrete question.
3. Obtain owner authorization to start the cross-project consultation and share its scoped context.
4. Select the tool and start the session with the initiating project's role, project identity, source revision when available, topic, participant limit, message limit, and expiration.
5. Give the owner the complete paste-ready message through [Invitation Handoff](#invitation-handoff). Do not search for or message unrelated agent tasks.
6. Each invited agent inspects its own project and joins with its role and source revision when available.
7. Exchange no more than the bounded messages needed to state the consumer need, provider constraint, alternatives, and consequences. Follow the selected tool's delivery procedure.
8. Keep facts, inferences, proposals, and owner decisions distinct. Agreement between agents is not evidence and does not approve a project decision.
9. If the exchange exposes a scope, requirement, architecture, or compatibility change, stop the affected implementation and follow the normal backward-transition rules in `guidelines/process-control.md`.
10. Close the session with the outcome format for the selected tool.
11. Each agent reports its own action or **None** and the brief decision summary. Record only its own project's relevant consequences through that project's normal artifact and approval path.
12. Record provider-facing API feedback in the provider's feedback mechanism and consumer-facing integration consequences in the consumer's applicable feasibility, requirement, architecture, issue, or status artifact.

## Required Closing Outcome

Agent Relay uses the brief decision summary and participant actions described above. The bundled mailbox enforces these headings, including headings whose outcome is `None`:

- **Agreed Contract:** the provisional shared meaning, including version or lifecycle boundaries
- **Provider Feedback:** API or documentation improvements genuinely needed by the consumer
- **Consumer Consequences:** integration changes, fallbacks, or version requirements for the consumer
- **Unresolved Questions:** disagreements or evidence still missing
- **Owner Decisions Required:** decisions neither agent may approve
- **Recommended Next Actions:** separately assigned provider, consumer, and owner actions

The bundled report includes this outcome, participant identities, source revisions, and the transcript. The selected tool's closeout remains consultation evidence. Each project's approved canonical artifacts remain authoritative.

## Failure And Stop Conditions

Stop or close with an unresolved result when:

- A participant cannot inspect the evidence needed to support its claim.
- The agents repeat positions without adding evidence or a materially different trade-off.
- The question expands beyond the approved topic.
- A required owner decision is identified.
- A participant requests repository changes, credentials, external publication, or another action outside consultation scope.
- The session expires, reaches its message limit, or loses a participant.

Do not keep an agent active merely to wait indefinitely. The bundled mailbox's `wait` call may block for at most sixty seconds. Follow the selected tool's wait and stop rules.

## Completion Criteria

The procedure is complete when:

- At least two authorized project agents participated.
- The concrete question received a bounded exchange.
- Claims and evidence labels are distinguishable from proposals and agreement.
- The session closed with the required outcome or an explicit unresolved result.
- Each project knows which feedback or artifact it should update.
- No repository was modified by the mailbox tool itself.
- Any required backward transition or owner decision is explicit.

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

## Tool

Read in order:

```text
tools/agent-session/AGENTS.md
tools/agent-session/README.md
```

Use:

```text
tools/agent-session/agent-session.cmd
```

The tool is a local shared-file mailbox. It does not call Codex, Claude, Gemini, or another model API, and it does not wake an inactive agent. The owner passes the session code to the other agent and starts or continues that agent's turn.

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
4. Start the session with the initiating project's role, project identity, source revision when available, topic, participant limit, message limit, and expiration.
5. Give the session code and tool location to the owner. Do not search for or message unrelated agent tasks.
6. The owner supplies the code to the other agent, which inspects its own project before joining with its role and source revision.
7. Exchange no more than the bounded messages needed to state the consumer need, provider constraint, alternatives, and consequences.
8. Keep facts, inferences, proposals, and owner decisions distinct. Agreement between agents is not evidence and does not approve a project decision.
9. If the exchange exposes a scope, requirement, architecture, or compatibility change, stop the affected implementation and follow the normal backward-transition rules in `guidelines/process-control.md`.
10. Close the session with all required outcome headings, even when a section says `None`.
11. Each agent reads the closing report and records only its own project's relevant consequences through that project's normal artifact and approval path.
12. Record provider-facing API feedback in the provider's feedback mechanism and consumer-facing integration consequences in the consumer's applicable feasibility, requirement, architecture, issue, or status artifact.

## Required Closing Outcome

The closing summary must contain:

- **Agreed Contract:** the provisional shared meaning, including version or lifecycle boundaries
- **Provider Feedback:** API or documentation improvements genuinely needed by the consumer
- **Consumer Consequences:** integration changes, fallbacks, or version requirements for the consumer
- **Unresolved Questions:** disagreements or evidence still missing
- **Owner Decisions Required:** decisions neither agent may approve
- **Recommended Next Actions:** separately assigned provider, consumer, and owner actions

The generated report includes this outcome, participant identities, source revisions, and the transcript. It remains consultation evidence. Each project's approved canonical artifacts remain authoritative.

## Failure And Stop Conditions

Stop or close with an unresolved result when:

- A participant cannot inspect the evidence needed to support its claim.
- The agents repeat positions without adding evidence or a materially different trade-off.
- The question expands beyond the approved topic.
- A required owner decision is identified.
- A participant requests repository changes, credentials, external publication, or another action outside consultation scope.
- The session expires, reaches its message limit, or loses a participant.

Do not keep an agent active merely to wait indefinitely. One `wait` call may block for at most sixty seconds; after that, yield to the owner or continue the other task.

## Completion Criteria

The procedure is complete when:

- At least two authorized project agents participated.
- The concrete question received a bounded exchange.
- Claims and evidence labels are distinguishable from proposals and agreement.
- The session closed with the required outcome or an explicit unresolved result.
- Each project knows which feedback or artifact it should update.
- No repository was modified by the mailbox tool itself.
- Any required backward transition or owner decision is explicit.

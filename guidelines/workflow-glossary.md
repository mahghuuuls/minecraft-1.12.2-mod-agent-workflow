# Workflow Glossary

Definitions of terms this workflow uses with a specific meaning. Read every session.

This file defines **what a term means**. It does not define **what to do about it**. Behavioral rules stay in the file that owns them, named as **Owner** on each entry.

Where this file and an owning file disagree, the owning file is authoritative. Report the contradiction rather than resolving it silently, per `AGENTS.md`.

Do not add ordinary Minecraft, programming, or project-domain words here. Vocabulary specific to the mod being built belongs in the project glossary.

## Terms

**Approved Baseline**
The approved record of an existing mod's current state, established by Existing Mod Assessment, that a Change Cycle modifies.
Owner: `guidelines/process-control.md`

**Change Cycle**
A workflow that modifies a mod which already has an approved baseline.
Owner: `workflows/change-cycle.md`

**Decision Level**
The degree of detail at which a stage settles a concern. A stage's **Out of Scope** list excludes a level, not a topic, so one concern may legitimately recur across several stages at decreasing levels.
Owner: `guidelines/process-control.md`

**Decision Packet**
A group of closely related low-risk decisions presented together for a single approval, rather than serialized into separate questions.
Owner: `guidelines/collaboration-guidelines.md`

**Diagnostic Mode**
An optional, disabled-by-default capability that lets a human see what the mod decided and why, so that working correctly can be told apart from failing silently. Whether one exists is decided in Concept and Scope; what form it takes is decided in Requirements Definition.
Owner: `stages/1-concept-and-scope.md`

**Foundation**
An issue type for work that does not itself deliver observable mod behavior but is necessary to unblock identified vertical slices.
Owner: `stages/6-implementation-plan.md`

**Manual Observability**
The contract recorded on an issue stating what authoritative state or event a manual check must observe, whether normal behavior exposes it reliably, what diagnostic support is required, and what independent evidence corroborates it.
Owner: `stages/6-implementation-plan.md`

**Planning Problem**
A condition found during Implementation where an issue is too large, incorrectly ordered, or missing dependencies or observability. Resolved by returning to the Implementation Plan, never by silently expanding the issue.
Owner: `stages/7-implementation.md`

**Process Material**
Versioned instructions, defaults, stages, workflows, and references. Read-only during mod development; editable only in Process Maintenance mode.
Owner: `AGENTS.md`

**Project Glossary**
`workspace/documentation/glossary.md`, holding the vocabulary of the mod being built. Distinct from this file, which holds the vocabulary of the workflow itself.
Owner: `guidelines/process-control.md`

**Standing Authorization**
A bounded, revocable permission covering a defined series of future actions, so that each one does not require separate approval. Never open-ended, and does not extend past the stage that granted it.
Owner: `guidelines/collaboration-guidelines.md`

**Validation Waiver**
An accepted record that an owner-managed validation check will not be performed, together with its reason. Not a way to hide a known defect, failed check, or unverified claim.
Owner: `guidelines/process-control.md`

**Vertical Slice**
A small piece of behavior implemented across every necessary part of the system, producing something observable and verifiable even while the feature is incomplete.
Owner: `stages/6-implementation-plan.md`

**Workflow Feedback**
Recorded observations about the process itself, kept separate from the project's own artifacts.
Owner: `guidelines/process-control.md`

## Status Vocabularies

These names are exact. The owning file governs transitions and permitted use; the summaries here exist so a stage that references a status does not require reading the stage that defines it.

**Workflow and stage status**
Not Started, In Progress, Awaiting Approval, Approved, Needs Revision.
Owner: `guidelines/process-control.md`

**Issue status**
Backlog, Ready, In Progress, Review, Blocked, Done, Deferred.
Owner: `stages/6-implementation-plan.md`

**Glossary term status**
Candidate, Approved, Deprecated.
Owner: `guidelines/process-control.md`

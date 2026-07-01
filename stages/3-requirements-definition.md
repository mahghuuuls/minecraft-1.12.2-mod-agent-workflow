# Requirements Definition

## Purpose

Convert the approved concept into precise, observable, and testable behavior without defining how the code will implement it.

## Main Question

> Exactly how must the mod behave?

## Required Input

- `workspace/documentation/concept-and-scope.md`
- `workspace/documentation/feasibility-research.md`
- `workspace/documentation/glossary.md`, when present
- Any approved decisions produced from feasibility findings

## Objectives

Establish:

- A short public-facing mod description for early project identity, when enough information is known
- What triggers each feature
- What behavior each feature produces
- Conditions under which the behavior applies
- Rules, limits, boundaries, and exceptions
- Configuration options and their effects
- Client, server, and multiplayer behavior
- State persistence requirements
- Compatibility expectations
- Failure and invalid-state behavior
- Relevant performance expectations
- Testable acceptance criteria
- Explicitly excluded behavior
- Approved glossary terms that affect behavior, configuration, or user-facing wording

## In Scope

- Minimal public mod description for repository metadata and initialization, when enough information is known
- Functional requirements
- Observable behavior
- Feature rules and interactions
- Inputs, outputs, triggers, and conditions
- Boundaries and exceptions
- Configuration behavior
- Default values that affect users
- Client and dedicated-server behavior
- Multiplayer synchronization and authority
- Persistence across saves and restarts
- Permission and ownership rules
- Compatibility expectations
- Error and failure behavior
- Performance requirements
- Acceptance criteria
- Requirement priorities
- Consistent terminology and glossary updates

## Out of Scope

Do not attempt to define:

- Package or class structure
- Loader events or APIs
- Libraries or implementation mechanisms
- Algorithms or internal data structures
- Architecture or design patterns
- Exact method implementations
- Implementation tasks or ordering
- Test implementation details
- Production code
- Final release copy, mod-page copy, or marketing assets

Requirements describe externally meaningful behavior and constraints, not the internal solution.

## Desired AI Behavior

Act as a requirements analyst.

- Derive candidate requirements from the approved Concept and Scope.
- Respect constraints and limitations discovered during Feasibility Research.
- Read and use approved glossary terms when present.
- Promote candidate glossary terms to approved terms when they affect requirements and the owner confirms their meaning.
- Clarify terms before using them in requirements when ambiguity could change behavior, configuration, permissions, multiplayer behavior, persistence, or public wording.
- Create a short public-facing mod description before finalizing requirements when the mod identity is stable enough.
- If the description cannot be responsibly written yet, defer it to Project Initialization instead of blocking this stage.
- Keep the public description concise, accurate, and suitable for early repository metadata.
- Do not treat the public description as final release README or platform-page copy.
- Interview the project owner one focused question at a time.
- Examine each feature through its triggers, conditions, outcomes, boundaries, and exceptions.
- Challenge vague terms such as "nearby," "fast," "compatible," or "automatically."
- Present alternative interpretations when behavior is ambiguous.
- Investigate edge cases capable of materially changing expected behavior.
- Ask about retroactive behavior when features affect existing worlds, entities, or saved data.
- Ask about multiplayer authority, synchronization, and permissions when relevant.
- Ask what happens when configuration, dependencies, input, or state are invalid.
- Distinguish required behavior from optional behavior.
- Avoid inventing requirements or expanding the approved scope.
- Avoid selecting technical solutions.
- Write requirements so their satisfaction can be objectively evaluated.
- Identify contradictions between requirements.
- Identify conflicts with project defaults or feasibility findings.
- Periodically summarize the current requirements and request corrections.
- Produce the final document only after explicit approval.

Focus questioning on meaningful behavior and risk. Do not exhaustively enumerate hypothetical edge cases without a plausible effect on the project.

## Public Mod Description

Define a minimal public-facing description when enough identity and behavior information is available. The description can be reused during Project Initialization for repository metadata, template placeholders, or early project identity.

The description should be:

- One or two short sentences.
- Understandable to a player or modpack author.
- Accurate to the approved concept and requirements.
- Stable enough for initialization, but not treated as final release copy.
- Free of internal implementation, workflow, testing, or validation details.

If the mod name, mod ID, or core behavior is still too unstable to write this accurately, record:

```text
Public mod description: Deferred to Project Initialization
Reason: <why it is not stable enough yet>
```

Use this description only as early identity text. Release Presentation owns final README, changelog, and platform-facing copy.

## Terminology and Glossary

Use `workspace/documentation/glossary.md` as the source of project-specific vocabulary.

During Requirements Definition:

- Resolve candidate glossary terms that affect required behavior.
- Add missing terms when a requirement depends on vocabulary with project-specific meaning.
- Mark terms **Approved** when the owner confirms their meaning or when the approved requirements depend on them.
- Keep requirement names, requirement text, acceptance criteria, configuration names, and public-description wording consistent with approved terms.
- Avoid using synonyms casually when the glossary has an approved preferred term.

If a term is still unresolved but does not materially affect behavior, record it as an unresolved non-blocking glossary question. If it affects behavior, do not approve the requirements until it is clarified.

## Requirement Quality

Each requirement should be:

- **Necessary:** Supports the approved concept.
- **Clear:** Has one reasonable interpretation.
- **Atomic:** Expresses one primary obligation.
- **Consistent:** Does not contradict another requirement.
- **Feasible:** Respects the accepted feasibility findings.
- **Observable:** Produces an outcome that can be evaluated.
- **Testable:** Has objective completion conditions.
- **Implementation-independent:** Does not prescribe internal code structure.
- **Traceable:** Has an identifiable origin.

Use requirement priorities consistently:

- **MUST:** Required for the project to be accepted.
- **SHOULD:** Expected unless there is an approved reason to omit it.
- **MAY:** Optional behavior that is permitted but not required.

## Requirement Format

Use stable identifiers such as `REQ-001`.

Each requirement should follow this structure:

```markdown
### REQ-001: Short Name

**Priority:** MUST  
**Source:** Related feature or project decision

**Requirement:**  
The mod must ...

**Acceptance Criteria:**

- Given ..., when ..., then ...
- Given ..., when ..., then ...

**Notes:**  
Relevant clarification, constraint, or dependency.
```

Notes should not prescribe implementation unless the detail is an established project constraint.

## Process

1. Read all required input documents.
2. Read `workspace/documentation/glossary.md`, when present.
3. Extract every approved high-level feature.
4. Draft the minimal public-facing mod description or record its deferral to Project Initialization.
5. Identify glossary terms that must be approved before requirements can be approved.
6. Identify the actors, triggers, states, and outcomes associated with each feature.
7. Interview the project owner one question at a time.
8. Resolve behavioral ambiguities, terminology ambiguities, and contradictions.
9. Define rules, limits, exceptions, and failure behavior.
10. Define configuration, multiplayer, persistence, and compatibility behavior where relevant.
11. Convert agreed behavior into atomic requirements.
12. Assign stable identifiers and priorities.
13. Add objective acceptance criteria.
14. Check every requirement for clarity, consistency, feasibility, terminology, and testability.
15. Update `workspace/documentation/glossary.md` when requirements approve, refine, or deprecate project terms.
16. Trace requirements back to approved features.
17. Generate `workspace/documentation/requirements.md` as a complete draft.
18. Present the draft for review and revise it until explicitly approved.

## Output Artifact

Produce a Markdown document named `workspace/documentation/requirements.md` containing:

1. **Purpose and Scope**
2. **Referenced Documents**
3. **Public Mod Description** or **Public Mod Description Deferral**
4. **Actors and Usage Context**
5. **Terminology**
6. **Functional Requirements**
7. **Configuration Requirements**
8. **Client and Server Requirements**
9. **Multiplayer Requirements**
10. **Persistence Requirements**
11. **Compatibility Requirements**
12. **Performance Requirements**
13. **Failure and Error Requirements**
14. **Out-of-Scope Behavior**
15. **Assumptions and Dependencies**
16. **Requirement Traceability**
17. **Glossary Updates**
18. **Unresolved Non-Blocking Questions**

Omit categories that do not apply rather than inventing requirements.

## Completion Criteria

This stage is complete when:

- The public mod description is approved or explicitly deferred to Project Initialization with a reason.
- Every approved high-level feature is represented by requirements.
- Every requirement has a stable identifier and priority.
- Required behavior is precise and observable.
- Meaningful boundaries and exceptions are defined.
- Relevant configuration, multiplayer, persistence, and failure behavior is covered.
- Every required behavior has objective acceptance criteria.
- Requirements use approved glossary terms consistently.
- Glossary terms that materially affect behavior are approved or revised.
- Requirements do not prescribe internal implementation.
- Requirements do not contradict each other.
- Requirements respect project defaults and feasibility findings.
- Every requirement is traceable to the approved concept or a documented constraint.
- No unresolved question remains that could materially change the requirements or architecture.
- The project owner explicitly approves the requirements.
- `workspace/documentation/requirements.md` has been generated and explicitly approved.

Completion does not require deciding how the requirements will be implemented, and it does not require final repository identity values.

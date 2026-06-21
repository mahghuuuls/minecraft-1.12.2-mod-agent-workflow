# Requirements Definition

## Purpose

Convert the approved concept into precise, observable, and testable behavior without defining how the code will implement it.

## Main Question

> Exactly how must the mod behave?

## Required Input

- `mod-project-defaults.md`
- `concept-and-scope.md`
- `feasibility-research.md`
- Any approved decisions produced from feasibility findings

Read and follow all input documents before beginning this stage.

## Objectives

Establish:

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

## In Scope

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
- Consistent terminology

## Out of Scope

Do not attempt to define:

- Package or class structure
- Forge events or APIs
- Libraries or implementation mechanisms
- Algorithms or internal data structures
- Architecture or design patterns
- Exact method implementations
- Implementation tasks or ordering
- Test implementation details
- Production code
- Release documentation or assets

Requirements describe externally meaningful behavior and constraints, not the internal solution.

## Desired AI Behavior

Act as a requirements analyst.

- Derive candidate requirements from the approved Concept and Scope.
- Respect constraints and limitations discovered during Feasibility Research.
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
- Return to an earlier stage when resolving a conflict requires changing an approved decision.
- Periodically summarize the current requirements and request corrections.
- Produce the final document only after explicit approval.

Focus questioning on meaningful behavior and risk. Do not exhaustively enumerate hypothetical edge cases without a plausible effect on the project.

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
2. Extract every approved high-level feature.
3. Identify the actors, triggers, states, and outcomes associated with each feature.
4. Interview the project owner one question at a time.
5. Resolve behavioral ambiguities and contradictions.
6. Define rules, limits, exceptions, and failure behavior.
7. Define configuration, multiplayer, persistence, and compatibility behavior where relevant.
8. Convert agreed behavior into atomic requirements.
9. Assign stable identifiers and priorities.
10. Add objective acceptance criteria.
11. Check every requirement for clarity, consistency, feasibility, and testability.
12. Trace requirements back to approved features.
13. Present the complete requirements for approval.
14. After approval, generate `requirements.md`.

## Output Artifact

Produce a Markdown document named `requirements.md` containing:

1. **Purpose and Scope**
2. **Referenced Documents**
3. **Actors and Usage Context**
4. **Terminology**
5. **Functional Requirements**
6. **Configuration Requirements**
7. **Client and Server Requirements**
8. **Multiplayer Requirements**
9. **Persistence Requirements**
10. **Compatibility Requirements**
11. **Performance Requirements**
12. **Failure and Error Requirements**
13. **Out-of-Scope Behavior**
14. **Assumptions and Dependencies**
15. **Requirement Traceability**
16. **Unresolved Non-Blocking Questions**

Omit categories that do not apply rather than inventing requirements.

## Completion Criteria

This stage is complete when:

- Every approved high-level feature is represented by requirements.
- Every requirement has a stable identifier and priority.
- Required behavior is precise and observable.
- Meaningful boundaries and exceptions are defined.
- Relevant configuration, multiplayer, persistence, and failure behavior is covered.
- Every required behavior has objective acceptance criteria.
- Requirements do not prescribe internal implementation.
- Requirements do not contradict each other.
- Requirements respect project defaults and feasibility findings.
- Every requirement is traceable to the approved concept or a documented constraint.
- No unresolved question remains that could materially change the requirements or architecture.
- The project owner explicitly approves the requirements.
- `requirements.md` has been generated.

Completion does not require deciding how the requirements will be implemented.


# Architecture Definition

## Purpose

Define how the codebase should be organized to satisfy the approved requirements while remaining understandable, maintainable, and easy to change.

The architecture should provide a clear map of where responsibilities belong and how the major parts of the mod interact.

## Main Question

> How should the codebase be structured to support the required behavior?

## Required Input

- `mod-project-defaults.md`
- `concept-and-scope.md`
- `feasibility-research.md`
- `requirements.md`

Read and follow all input documents before beginning this stage.

## Objectives

Establish:

- The overall organization of the codebase
- Major components and their responsibilities
- Package boundaries
- Dependency directions
- Important classes and interfaces
- Forge and Cleanroom integration points
- Client, server, and shared-code separation
- Configuration, networking, and persistence approaches
- External library and mod integrations
- Important runtime and data flows
- Performance-sensitive areas
- How the architecture supports verification
- Major technical decisions and their reasoning

## In Scope

- Architectural goals and constraints
- Package and component structure
- Component responsibilities
- Dependency rules
- Important classes and interfaces
- Selected libraries and dependencies
- Forge lifecycle integration
- Event handling boundaries
- Client and server separation
- Network communication
- Configuration management
- State ownership and persistence
- External mod integrations
- Error handling and logging strategy
- Performance-sensitive boundaries
- Important runtime flows
- Architectural support for testing and verification
- Decisions, alternatives, and trade-offs
- Requirement-to-component traceability

## Out of Scope

Do not attempt to define:

- Complete class inventories
- Every method or field
- Method implementations
- Detailed algorithms unless architecturally significant
- Production code
- Exact implementation task ordering
- Detailed verification procedures
- Release documentation or assets
- Features not present in the approved requirements

Architecture should establish structure and boundaries without attempting to write the implementation in prose.

## Desired AI Behavior

Act as a software architect collaborating with the project owner.

- Begin by identifying the responsibilities implied by the requirements.
- Propose the simplest architecture that satisfies those responsibilities.
- Prioritize understandability and clear ownership of behavior.
- Keep related behavior together and unrelated concerns separate.
- Define explicit dependency directions and prevent circular dependencies.
- Avoid abstractions, interfaces, patterns, or layers without a concrete purpose.
- Avoid designing for hypothetical future features outside the approved scope.
- Evaluate candidate libraries identified during Feasibility Research.
- Select dependencies only when they provide meaningful value.
- Explain important alternatives and their trade-offs.
- Ask one focused question at a time when a decision requires project-owner input.
- Do not ask questions that can be answered from the approved documents or technical research.
- Trace architectural decisions back to requirements or established constraints.
- Identify decisions that remain uncertain and require validation during Implementation.
- Flag conflicts with requirements or feasibility findings.
- Return to an earlier stage when resolving a conflict requires changing an approved decision.
- Periodically summarize the proposed architecture and request corrections.
- Produce the final architecture only after explicit approval.

The AI must not introduce complexity merely to demonstrate architectural sophistication. Patterns and abstractions require a specific problem that they solve.

## Architecture Quality

The architecture should be:

- **Understandable:** A developer can identify where behavior belongs.
- **Cohesive:** Each component has a focused responsibility.
- **Loosely coupled:** Components depend on limited, intentional boundaries.
- **Traceable:** Components and decisions relate to approved requirements.
- **Proportionate:** Complexity reflects the actual size and risk of the mod.
- **Side-safe:** Client-only code cannot accidentally load on a dedicated server.
- **Changeable:** Likely changes remain localized.
- **Verifiable:** Important logic can be evaluated without unnecessary environmental coupling.
- **Explicit:** Dependencies and runtime flows are documented rather than implied.

## Architectural Decisions

For each significant decision, record:

```markdown
### ARC-001: Decision Name

**Status:** Accepted

**Context:**  
What problem or constraint requires a decision?

**Decision:**  
What approach was selected?

**Alternatives Considered:**

- Alternative A
- Alternative B

**Reasoning:**  
Why was this approach selected?

**Consequences:**

- Positive consequence
- Negative consequence or trade-off

**Related Requirements:**

- REQ-001
- REQ-002

**Implementation Validation:**  
What, if anything, must be confirmed during Implementation?
```

Minor and self-evident choices do not require separate decision records.

## Process

1. Read all required input documents.
2. Extract architectural constraints and quality needs.
3. Group requirements into related responsibilities.
4. Identify major components and ownership boundaries.
5. Evaluate relevant libraries and integration approaches.
6. Define package organization and dependency directions.
7. Define Forge lifecycle and event integration.
8. Define client, server, and shared-code boundaries.
9. Define configuration, networking, persistence, and external integrations where applicable.
10. Describe important runtime and data flows.
11. Identify performance-sensitive and verification-sensitive areas.
12. Review the architecture for unnecessary complexity and coupling.
13. Trace components and decisions to requirements.
14. Present the proposed architecture for approval.
15. After approval, generate `architecture.md`.

## Output Artifact

Produce a Markdown document named `architecture.md` containing:

1. **Architecture Overview**
2. **Goals and Quality Attributes**
3. **Constraints**
4. **Selected Libraries and Dependencies**
5. **Package Structure**
6. **Components and Responsibilities**
7. **Dependency Rules**
8. **Important Classes and Interfaces**
9. **Forge Lifecycle and Event Integration**
10. **Client, Server, and Shared-Code Boundaries**
11. **Configuration Architecture**
12. **Networking Architecture**
13. **State Ownership and Persistence**
14. **External Mod Integrations**
15. **Important Runtime Flows**
16. **Error Handling and Logging**
17. **Performance Considerations**
18. **Support for Verification**
19. **Architectural Decisions and Trade-offs**
20. **Requirement Traceability**
21. **Questions Requiring Implementation Validation**

Omit sections that do not apply rather than inventing architectural concerns.

Use compact Mermaid diagrams when they make component relationships or runtime flows easier to understand. Diagrams must supplement the written responsibilities and dependency rules, not replace them.

## Completion Criteria

This stage is complete when:

- Major components and their responsibilities are defined.
- Package boundaries and dependency directions are clear.
- Relevant libraries and dependencies have been selected with reasons.
- Forge lifecycle and integration points are identified.
- Client, server, and shared-code boundaries are explicit.
- Relevant configuration, networking, persistence, and integration approaches are defined.
- Important runtime flows are understandable.
- Performance-sensitive areas are identified.
- Major decisions and trade-offs are recorded.
- Architecture complexity is proportionate to the mod.
- Components and decisions are traceable to requirements.
- Implementation uncertainties are explicitly recorded.
- A developer can determine where each major behavior belongs.
- The project owner explicitly approves the architecture.
- `architecture.md` has been generated.

Completion does not require defining every class, method, or implementation detail.

The architecture is an approved baseline, not an immutable document. Discoveries during Implementation may require updates, but changes must be explicit and justified rather than allowing the code to silently diverge.
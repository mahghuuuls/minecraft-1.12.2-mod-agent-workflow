# Architecture Definition

## Purpose

Define how the codebase should be organized to satisfy the approved requirements while remaining understandable, maintainable, and easy to change.

The architecture should provide a clear map of where responsibilities belong and how the major parts of the mod interact.

## Main Question

> How should the codebase be structured to support the required behavior?

## Required Input

- `workspace/documentation/feasibility-research.md`
- `workspace/documentation/requirements.md`
- `workspace/documentation/glossary.md`, when present
- The active mod repository, when architecture must account for existing code
- Approved dependency source reference checkouts under `workspace/dependencies/`, when Feasibility Research created or accepted them
- `guidelines/project-defaults.md`, including its Mod Dependency Version Constraints
- `guidelines/coding-standards.md`, whose General Design and Loader Integration sections are what the Architecture Quality criteria below resolve to in code
- `guidelines/collaboration-guidelines.md`, for how decisions and their alternatives are recorded and approved

## Objectives

Establish:

- The overall organization of the codebase
- Major components and their responsibilities
- Package boundaries
- Dependency directions
- Important classes and interfaces
- Selected loader and runtime integration points
- Client, server, and shared-code separation
- Configuration, networking, and persistence approaches
- External library and mod integrations
- The separation between exact dependency artifact resolution and minimum-only shipping metadata
- How dependency source findings affect integration boundaries, if applicable
- Important runtime and data flows
- Performance-sensitive areas
- How the architecture supports verification
- Major technical decisions and their reasoning
- Which boundaries carry substantial complexity, what knowledge each owns, and how their interfaces hide it
- Which responsibilities and contracts are architectural invariants and which internal structures Implementation may refine without revising this artifact
- Architectural naming that follows approved glossary vocabulary

## In Scope

- Architectural goals and constraints
- Package and component structure
- Component responsibilities
- Dependency rules
- Important classes and interfaces
- Selected libraries and dependencies
- Loader lifecycle integration
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
- Alternative sketches and complexity analysis for nontrivial public APIs, state ownership, synchronization, lifecycle orchestration, and integration boundaries
- Requirement-to-component traceability
- Glossary-aligned naming decisions

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
- Read and use approved glossary terms when present.
- Use approved terminology for components, configuration concepts, public-facing concepts, and important runtime flows.
- Ask before introducing a new term when it could overlap with an approved glossary term.
- Update the glossary when architecture introduces or deprecates a project-specific technical term that later documents or code should use consistently.
- Propose the simplest architecture that satisfies those responsibilities.
- Prioritize understandability and clear ownership of behavior.
- Keep related behavior together and unrelated concerns separate.
- Define explicit dependency directions and prevent circular dependencies.
- Avoid abstractions, interfaces, patterns, or layers without a concrete purpose.
- Avoid designing for hypothetical future features outside the approved scope.
- Evaluate candidate libraries identified during Feasibility Research.
- Use approved dependency source checkouts as read-only evidence for integration decisions.
- Select dependencies only when they provide meaningful value.
- Record the exact artifact used by the build separately from the verified minimum encoded in shipping metadata; the compatibility policy itself is owned by `guidelines/project-defaults.md` and must not be replaced by a project-specific upper bound.
- Explain important alternatives and their trade-offs.
- For each complexity-bearing boundary, sketch at least two meaningfully different designs before selecting one. Compare common usage, interface knowledge, likely changes, special cases, dependency leakage, and Minecraft lifecycle constraints.
- Do not satisfy the alternative-design requirement with cosmetic variations or a post-hoc list of rejected names for the selected structure.
- Identify the authoritative owner of each formula, precedence rule, persistence shape, synchronization contract, compatibility policy, and other nontrivial design decision.
- Prefer deep components whose interfaces hide lifecycle, compatibility, and implementation detail. Treat pass-through layers and caller-managed operation sequences as design warnings that require a concrete justification.
- Use one focused question for a branching owner decision; group closely related recommended architectural defaults into a compact decision packet when they can be reviewed together safely.
- Do not ask questions that can be answered from the approved documents or technical research.
- Trace architectural decisions back to requirements or established constraints.
- Define architecture at the level of responsibilities, contracts, ownership, and dependency direction. Name a class, method, or package as an architectural constraint only when its specific identity or boundary matters; do not freeze incidental implementation structure.
- Record the internal design freedom left to Implementation and the evidence that should trigger an architecture revision. Approval of this artifact does not make internal decomposition immutable.
- Identify decisions that remain uncertain and require validation during Implementation.
- Flag conflicts with requirements or feasibility findings.
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
- **Evolution-aware:** Approved invariants are explicit without freezing internal structures that Implementation should improve as evidence emerges.
- **Deep:** Important components hide more complexity than their interfaces expose.
- **Information-hiding:** Each nontrivial rule or representation has one authoritative owner rather than leaking across components.
- **Layered deliberately:** Adjacent layers provide different abstractions or enforce a named boundary.
- **Verifiable:** Important logic can be evaluated without unnecessary environmental coupling.
- **Explicit:** Dependencies and runtime flows are documented rather than implied.
- **Terminologically consistent:** Architectural names do not casually rename approved project concepts.

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

**Complexity Analysis:**

- Common operation and required caller knowledge
- Design knowledge hidden by this boundary
- Likely changes kept local
- Complexity or red flags accepted because of a concrete Minecraft, loader, or dependency constraint

**Consequences:**

- Positive consequence
- Negative consequence or trade-off

**Related Requirements:**

- REQ-001
- REQ-002

**Related Glossary Terms:**

- Approved term, when applicable

**Implementation Validation:**  
What, if anything, must be confirmed during Implementation?
```

Minor and self-evident choices do not require separate decision records or two design sketches. A decision is complexity-bearing when it establishes a public API, persistent representation, synchronization contract, configuration precedence rule, shared formula or policy, cross-mod boundary, or lifecycle sequence that several later changes will depend on.

## Process

1. Read all required input documents.
2. Read `workspace/documentation/glossary.md`, when present.
3. Extract architectural constraints, quality needs, and approved terminology.
4. Group requirements into related responsibilities.
5. Identify major components, ownership boundaries, complexity-bearing decisions, and the design knowledge each component owns.
6. Evaluate relevant libraries, integration approaches, exact build artifacts, and verified minimum shipping versions.
7. Review approved dependency source reference findings when they affect integration design.
8. Define package organization and dependency directions.
9. Define loader lifecycle and event integration.
10. Define client, server, and shared-code boundaries.
11. Define configuration, networking, persistence, and external integrations where applicable.
12. Describe important runtime and data flows.
13. Identify performance-sensitive and verification-sensitive areas.
14. Review the architecture for shallow modules, information leakage, pass-through layers, temporal coupling, overexposed interfaces, mixed general and special-purpose policy, unnecessary complexity, coupling, and terminology drift.
15. Trace components and decisions to requirements and glossary terms where relevant.
16. Update `workspace/documentation/glossary.md` when architecture approves, introduces, refines, or deprecates project-specific terms.
17. Generate `workspace/documentation/architecture.md` as a complete draft.
18. Present the draft for review and revise it until explicitly approved.

## Output Artifact

Produce `workspace/documentation/architecture.md` from `setup/artifact-templates/architecture.md`. The template is the authoritative document structure; this stage's architectural-decision format and completion criteria are authoritative for content quality.

Omit sections that do not apply rather than inventing architectural concerns.

Use compact Mermaid diagrams when they make component relationships or runtime flows easier to understand. Diagrams must supplement the written responsibilities and dependency rules, not replace them.

## Completion Criteria

This stage is complete when:

- Major components and their responsibilities are defined.
- Package boundaries and dependency directions are clear.
- Relevant libraries and dependencies have been selected with reasons.
- Dependency integration records exact build artifacts separately from minimum-only shipping metadata.
- Loader lifecycle and integration points are identified.
- Client, server, and shared-code boundaries are explicit.
- Relevant configuration, networking, persistence, and integration approaches are defined.
- Important runtime flows are understandable.
- Performance-sensitive areas are identified.
- Major decisions and trade-offs are recorded.
- Complexity-bearing decisions compare at least two meaningful alternatives and explain why the selected interface hides knowledge more effectively.
- Each important formula, representation, policy, precedence rule, synchronization contract, and lifecycle responsibility has an authoritative owner.
- Architectural invariants and implementation freedoms are distinguished clearly enough that local design improvement does not require unnecessary reapproval.
- Architecture complexity is proportionate to the mod.
- Components and decisions are traceable to requirements.
- Architectural names and concepts are consistent with approved glossary terms.
- Glossary entries introduced or changed by architecture are recorded.
- Implementation uncertainties are explicitly recorded.
- A developer can determine where each major behavior belongs.
- The project owner explicitly approves the architecture.
- `workspace/documentation/architecture.md` has been generated and explicitly approved.

Completion does not require defining every class, method, or implementation detail.

The architecture is an approved baseline, not an immutable document. Discoveries during Implementation may require updates, but changes must be explicit and justified rather than allowing the code to silently diverge.

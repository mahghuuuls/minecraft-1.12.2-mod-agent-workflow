# Feasibility Research

## Purpose

Determine whether the approved mod concept appears reasonably implementable within the established constraints, while identifying relevant libraries, dependencies, limitations, risks, and unresolved technical questions.

This stage performs research. It does not write or test implementation code.

## Main Question

> Can this mod reasonably be made under the established constraints?

## Required Input

- `mod-project-defaults.md`
- `concept-and-scope.md`
- Any source code, mod files, documentation, or references relevant to the concept

Read and follow the input documents before beginning this stage.

## Objectives

Establish:

- Whether each high-level feature appears technically feasible
- Which Minecraft, Forge, and Cleanroom capabilities are relevant
- Which existing mod libraries could support the implementation
- Whether required integration points appear accessible
- Which dependencies would be required or optional
- Known compatibility and platform limitations
- Client and dedicated-server considerations
- Performance concerns requiring later validation
- Technical risks and unresolved questions
- Whether the concept or scope must be reconsidered

## In Scope

- Researching Minecraft 1.12.2, Forge, Cleanroom, and relevant mods
- Inspecting documentation, APIs, source code, and existing implementations
- Finding libraries that provide relevant capabilities
- Evaluating library compatibility with project defaults
- Evaluating library API fit, licensing, dependencies, and availability
- Identifying possible technical mechanisms
- Investigating client and dedicated-server limitations
- Identifying whether Mixins, access transformers, reflection, or similar mechanisms may be necessary
- Identifying performance and compatibility risks
- Recording questions that must be validated during Implementation
- Classifying features as feasible, conditionally feasible, unverified, or infeasible

## Out of Scope

Do not attempt to:

- Write prototypes or production code
- Experimentally validate technical approaches
- Define detailed feature behavior
- Resolve requirements-level edge cases
- Design the final package or class structure
- Make every final architectural decision
- Create the implementation plan
- Implement complete features
- Prepare release documentation or assets
- Silently change the approved concept or scope

When research cannot establish feasibility confidently, record the uncertainty and the validation required during Implementation.

## Desired AI Behavior

Act as a technical researcher.

- Extract technical assumptions and uncertainties from `concept-and-scope.md`.
- Prioritize questions that could invalidate the project or materially change its scope.
- Prefer official repositories, source code, primary documentation, and version-specific evidence.
- Distinguish confirmed facts, reasonable inferences, and unresolved questions.
- Provide evidence for important conclusions.
- Avoid assuming that information for newer Minecraft versions applies to 1.12.2.
- Search for existing libraries before assuming functionality must be developed from scratch.
- Check each candidate library against the project defaults.
- Evaluate whether candidate libraries are maintained, accessible, legally usable, and suitable for distribution through CurseForge.
- Identify required and transitive dependencies.
- Compare possible approaches only far enough to establish feasibility and major trade-offs.
- Challenge unrealistic assumptions and unsupported expectations.
- Ask the project owner only questions that cannot be answered through technical research.
- Do not write code or perform implementation work.
- Do not design the final architecture.
- Do not silently modify the approved scope.
- Clearly report uncertainty and avoid overstating confidence.
- Recommend returning to Concept and Scope if findings invalidate the approved concept.

## Library Evaluation

For each relevant library, investigate:

- Purpose and relevant capabilities
- Minecraft 1.12.2 compatibility
- Forge and Cleanroom compatibility
- Required dependencies
- Client, server, or shared usage
- License and redistribution restrictions
- Source-code and documentation availability
- Maintenance status
- CurseForge availability
- Known limitations
- Apparent suitability for the project

Library research may recommend candidates, but final dependency and integration decisions belong to Architecture Definition.

## Feasibility Classifications

Classify each high-level feature as:

- **Feasible:** Available evidence provides reasonable confidence that it can be implemented.
- **Conditionally Feasible:** It appears possible only with stated dependencies, limitations, or compromises.
- **Unverified:** Research is insufficient; validation will be required during Implementation.
- **Infeasible:** Available evidence indicates that it cannot reasonably be implemented under the current constraints.

Do not classify a feature as feasible merely because a possible approach can be imagined.

## Process

1. Read all required input documents.
2. Extract high-level features and technical uncertainties.
3. Convert uncertainties into explicit research questions.
4. Prioritize project-invalidating questions.
5. Research relevant APIs, libraries, mods, dependencies, and technical mechanisms.
6. Evaluate candidate libraries against the project defaults.
7. Record evidence and confidence for each conclusion.
8. Classify the feasibility of every high-level feature.
9. Identify risks and questions requiring later validation.
10. Present findings that require project-owner decisions.
11. Return to Concept and Scope if findings require material scope changes.
12. After the findings are accepted, generate `feasibility-research.md`.

## Output Artifact

Produce `feasibility-research.md` containing:

1. **Executive Conclusion**
2. **Research Questions**
3. **Feature Feasibility**
4. **Relevant Platform Capabilities**
5. **Candidate Libraries**
6. **Dependencies and Integrations**
7. **Client and Server Considerations**
8. **Compatibility Findings**
9. **Performance Considerations**
10. **Technical Risks**
11. **Questions Requiring Implementation Validation**
12. **Limitations and Conditions**
13. **Required Scope Reconsiderations**
14. **Constraints for Requirements and Architecture**
15. **Evidence and References**

## Completion Criteria

This stage is complete when:

- Every high-level feature has a supported feasibility classification.
- Relevant existing libraries have been investigated.
- Promising libraries and their limitations are documented.
- Required and optional dependencies are identified.
- Important compatibility and client/server limitations are understood.
- Major technical and performance risks are recorded.
- Questions requiring implementation validation are explicit.
- Required scope reconsiderations have been resolved.
- Constraints for Requirements and Architecture are documented.
- The project owner accepts the findings.
- `feasibility-research.md` has been generated.

Completion does not require experimentally proving every technical conclusion. Remaining uncertainty must be explicit and assigned for later validation.


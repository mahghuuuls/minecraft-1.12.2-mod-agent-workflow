# Feasibility Research

## Purpose

Determine whether the approved mod concept appears reasonably implementable within the established constraints, while identifying relevant libraries, dependencies, limitations, risks, and unresolved technical questions.

This stage performs research. It does not write or test implementation code.

## Main Question

> Can this mod reasonably be made under the established constraints?

## Required Input

- `workspace/documentation/concept-and-scope.md`
- `workspace/documentation/project-setup.md`
- Any supplied source code, mod files, documentation, or references
- Any owner-provided dependency source repository URLs, local paths, or version constraints
- `workspace/documentation/dependency-references.md`, when present

## Objectives

Establish:

- Whether each high-level feature appears technically feasible
- Which Minecraft, loader, runtime, and distribution-platform capabilities are relevant
- Which existing mod libraries could support the implementation
- Whether required integration points appear accessible
- Which dependencies would be required or optional
- Whether advanced implementation or build mechanisms are actually required by the approved behavior
- Whether the provisional loader and template can support the identified requirements without unnecessary capabilities
- Whether dependency source repositories need local reference checkouts
- Known compatibility and platform limitations
- Client and dedicated-server considerations
- Performance concerns requiring later validation
- Technical risks and unresolved questions
- Whether the concept or scope must be reconsidered

## In Scope

- Researching Minecraft 1.12.2, candidate loaders, compatible runtimes, and relevant mods
- Inspecting documentation, APIs, source code, and existing implementations
- Finding libraries that provide relevant capabilities
- Evaluating library compatibility with project defaults
- Evaluating library API fit, licensing, dependencies, and availability
- Inspecting dependency source repositories when documentation, released artifacts, or online source browsing are insufficient
- Identifying possible technical mechanisms
- Investigating client and dedicated-server limitations
- Identifying whether Mixins, coremods, access transformers, reflection, shading, or similar mechanisms may be necessary
- Evaluating advanced build or automation capabilities only when approved behavior or operational constraints create a concrete need
- Validating the provisional template against concrete capability findings from this stage
- Identifying performance and compatibility risks
- Recording questions that must be validated during Implementation
- Classifying features as feasible, conditionally feasible, unverified, or infeasible

## Out of Scope

Do not attempt to:

- Write prototypes or production code
- Experimentally validate technical approaches
- Clone dependency source repositories speculatively or without a concrete research need
- Modify, commit to, vendor from, or otherwise treat dependency source checkouts as project source
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

- Extract technical assumptions and uncertainties from `workspace/documentation/concept-and-scope.md`.
- Resolve advanced build-capability questions deferred by Project Setup from the approved behavior and evidence; do not ask the owner to choose an implementation mechanism that research can determine.
- Prioritize questions that could invalidate the project or materially change its scope.
- Prefer official repositories, source code, primary documentation, and version-specific evidence.
- Prefer released artifacts, official documentation, and public source browsing before creating a local dependency source checkout.
- Distinguish confirmed facts, reasonable inferences, and unresolved questions.
- Provide evidence for important conclusions.
- Avoid assuming that information for newer Minecraft versions applies to 1.12.2.
- Search for existing libraries before assuming functionality must be developed from scratch.
- Check each candidate library against the project defaults.
- Evaluate whether candidate libraries are maintained, accessible, legally usable, and suitable for the approved distribution platforms.
- Identify required and transitive dependencies.
- Use `workspace/dependencies/<dependency-name>/` for approved local dependency source checkouts and treat them as read-only reference material.
- Record the dependency repository URL, requested ref, resolved commit when available, checkout reason, and licensing constraints.
- Update `workspace/documentation/dependency-references.md` whenever dependency source references are approved, added, superseded, or removed.
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
- Selected loader and runtime compatibility
- Required dependencies
- Client, server, or shared usage
- License and redistribution restrictions
- Source-code and documentation availability
- Whether a local source checkout is necessary or whether remote source/documentation is enough
- Maintenance status
- Availability through approved distribution channels
- Known limitations
- Apparent suitability for the project

Library research may recommend candidates, but final dependency and integration decisions belong to Architecture Definition.

## Dependency Source Checkouts

Use local dependency source checkouts only when they materially improve accuracy. Appropriate reasons include:

- The mod depends on another mod whose public API or behavior is not documented well enough.
- Compatibility depends on implementation details that cannot be verified from released artifacts or docs.
- The owner provides a dependency repository and asks the agent to inspect it.
- A precise version, branch, or commit must be compared against the planned integration.

Default location:

```text
workspace/dependencies/<dependency-name>/
```

These checkouts are reference inputs. They must not be copied into the active project, modified, committed, pushed, or treated as additional active mod repositories without explicit owner approval and licensing review.

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
5. Research relevant APIs, libraries, mods, dependencies, and technical mechanisms, including advanced build capabilities deferred by Project Setup when the approved behavior makes them relevant.
6. Decide whether any dependency source repository needs a local reference checkout.
7. Request owner approval before cloning dependency source locally unless the owner already provided the local path or repository for this purpose.
8. Update `workspace/documentation/dependency-references.md` when dependency source references are approved or changed.
9. Evaluate candidate libraries against the project defaults.
10. Record evidence and confidence for each conclusion.
11. Classify the feasibility of every high-level feature.
12. Identify risks and questions requiring later validation.
13. Present findings that require project-owner decisions.
14. Return to Concept and Scope if findings require material scope changes.
15. Generate `workspace/documentation/feasibility-research.md` as a complete draft.
16. Present the draft for review and revise it until explicitly approved.

## Output Artifact

Produce `workspace/documentation/feasibility-research.md` from `setup/artifact-templates/feasibility-research.md`. The template is the authoritative document structure; this stage's completion criteria are authoritative for content quality.

When dependency source references exist, also create or update:

```text
workspace/documentation/dependency-references.md
```

## Completion Criteria

This stage is complete when:

- Every high-level feature has a supported feasibility classification.
- Relevant existing libraries have been investigated.
- Promising libraries and their limitations are documented.
- Required and optional dependencies are identified.
- Necessary dependency source checkouts are recorded with URL/path, ref or commit, reason, and licensing constraints.
- Important compatibility and client/server limitations are understood.
- Major technical and performance risks are recorded.
- Questions requiring implementation validation are explicit.
- Required scope reconsiderations have been resolved.
- Constraints for Requirements and Architecture are documented.
- The project owner accepts the findings.
- `workspace/documentation/feasibility-research.md` has been generated and explicitly approved.

Completion does not require experimentally proving every technical conclusion. Remaining uncertainty must be explicit and assigned for later validation.


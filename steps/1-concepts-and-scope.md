# Concept and Scope

## Purpose

Establish a shared understanding of what the mod should accomplish and where its boundaries are, without deciding whether or how it will be implemented.

## Main Question

> What are we making, and what are we not making?

## Required Input

- The initial mod idea or problem statement
- `mod-project-defaults.md`
- Any examples or references supplied by the project owner

Read and follow `mod-project-defaults.md` before beginning this stage.

## Objectives

Establish:

- The problem or desire motivating the mod
- The intended player experience
- The target users and usage context
- The mod's high-level features
- Which features are essential or optional
- What is inside and outside the project scope
- What would make the mod successful
- Assumptions requiring later confirmation
- Technical uncertainties requiring Feasibility Research

## In Scope

- Mod purpose and motivation
- Intended player experience
- Target audience
- High-level capabilities
- Feature priorities
- Project boundaries
- Fixed project constraints
- Concept-level examples
- Assumptions and open questions
- Definition of success

## Out of Scope

Do not attempt to define:

- Technical feasibility
- Forge APIs or integration mechanisms
- Dependencies beyond established defaults
- Detailed behavior and edge cases
- Code organization or architecture
- Packages, classes, or interfaces
- Implementation tasks
- Verification procedures
- Release documentation or assets

Identify obvious contradictions, but record technical concerns for Feasibility Research instead of trying to solve them.

## Desired AI Behavior

Act as an alignment interviewer.

- Ask one focused question at a time.
- Begin with the problem and intended experience.
- Use each answer to determine the next relevant question.
- Challenge vague language, hidden assumptions, contradictions, and feature creep.
- Present alternative interpretations when something is ambiguous.
- Distinguish essential features from optional ideas.
- Explore what is explicitly outside the project scope.
- Do not introduce features that the project owner did not request.
- Do not investigate feasibility or propose technical solutions.
- Record technical uncertainties for Feasibility Research.
- Periodically summarize the current understanding.
- Ask the project owner to correct or confirm each summary.
- Continue until the concept and boundaries have shared agreement.
- Generate the final document only after receiving explicit approval.

Focus the interview on decisions that could materially change the project's identity or scope. Do not attempt to explore every detailed behavioral edge case.

## Process

1. Read `mod-project-defaults.md`.
2. Receive the initial mod idea.
3. Identify the most important unresolved concept-level question.
4. Interview the project owner one question at a time.
5. Record decisions, assumptions, boundaries, and open questions.
6. Periodically summarize the current shared understanding.
7. Resolve concept-level contradictions and ambiguities.
8. Present a final summary for approval.
9. After approval, generate `concept-and-scope.md`.

## Output Artifact

Produce a Markdown document named `concept-and-scope.md` containing:

1. **Purpose**
2. **Problem Statement**
3. **Intended Player Experience**
4. **Target Users and Usage Context**
5. **High-Level Features**
6. **Essential Features**
7. **Optional Features**
8. **In Scope**
9. **Out of Scope**
10. **Fixed Constraints**
11. **Assumptions**
12. **Open Concept Questions**
13. **Questions for Feasibility Research**
14. **Definition of Success**

Omit sections without relevant content instead of inventing information.

## Completion Criteria

This stage is complete when:

- The mod can be explained clearly in a short paragraph.
- Its purpose and intended experience are understood.
- Its target users and usage context are identified.
- Its high-level features are understood.
- Essential and optional features are distinguished.
- In-scope and out-of-scope boundaries are explicit.
- No unresolved concept-level contradictions remain.
- Technical uncertainties are recorded for Feasibility Research.
- The project owner explicitly approves the final understanding.
- `concept-and-scope.md` has been generated.

Completion does not require proving technical feasibility or defining detailed behavior.


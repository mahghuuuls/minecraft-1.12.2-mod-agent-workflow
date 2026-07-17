# Concept and Scope

## Purpose

Establish a shared understanding of what the mod should accomplish and where its boundaries are, without deciding whether or how it will be implemented.

## Main Question

> What are we making, and what are we not making?

## Required Input

- The initial mod idea or problem statement
- Any rough design notes supplied by the project owner
- Any examples or references supplied by the project owner
- `workspace/documentation/glossary.md`, when present

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
- Candidate glossary terms that have project-specific meaning

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
- Candidate project terminology

## Out of Scope

Do not attempt to define:

- Technical feasibility
- Loader APIs or integration mechanisms
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

- Before the interview starts, ask the project owner to describe the mod as fully as they can.
- For complex mods, recommend writing a rough design note first.
- Treat the owner's first draft as raw input, not as final requirements or approved scope.
- Use focused questions for branching scope decisions and compact decision packets for closely related low-risk boundaries or defaults.
- Begin with the problem and intended experience.
- Use each answer to determine the next relevant question.
- Challenge vague language, hidden assumptions, contradictions, and feature creep.
- Present alternative interpretations when something is ambiguous.
- Distinguish essential features from optional ideas.
- Explore what is explicitly outside the project scope.
- For silent, event-driven, or hard-to-observe mods, consider whether a disabled-by-default debug mode belongs in scope for development validation.
- Capture candidate glossary terms when the owner uses project-specific vocabulary.
- Ask whether similar terms are synonyms or distinct concepts when the distinction could affect scope.
- Ask whether one term has multiple meanings when that ambiguity could affect scope.
- Do not introduce features that the project owner did not request.
- Do not investigate feasibility or propose technical solutions.
- Record technical uncertainties for Feasibility Research.
- Periodically summarize the current understanding.
- Ask the project owner to correct or confirm each summary.
- Continue until the concept and boundaries have shared agreement.
- Generate a complete draft artifact when alignment is sufficient, then revise it until the project owner approves it.

Focus the interview on decisions that could materially change the project's identity or scope. Do not attempt to explore every detailed behavioral edge case.

## Initial Draft Intake

Start by asking the project owner for a rough first draft of the mod idea.

Ask for as much detail as they already know, such as:

- What problem, annoyance, fantasy, or player experience motivated the mod
- What the mod should do at a high level
- What the player should notice while using it
- Any examples from other mods, games, or manual workflows
- Any known boundaries, exclusions, or strong preferences

For small mods, a paragraph may be enough. For complex mods, recommend a rough design note before the interview continues.

Do not critique the draft as an implementation plan. Use it to choose the first focused interview question.

## Glossary Handling

Use `workspace/documentation/glossary.md` for project-specific vocabulary.

If the glossary does not exist and the discussion introduces terms with project-specific meaning, create it from:

```text
setup/glossary-template.md
```

During this stage, glossary entries may remain **Candidate**. They should capture the owner's wording, possible meanings, and questions for later clarification. Do not force every candidate term to become fully approved during Concept and Scope unless the term affects the project boundary.

Do not add ordinary Minecraft, programming, or workflow terms unless this project uses them in a special way.

## Process

1. Read `guidelines/project-defaults.md`.
2. Read `workspace/documentation/glossary.md`, when present.
3. Ask the project owner for a rough first draft of the mod idea.
4. Receive the initial mod idea, rough design note, examples, or references.
5. Identify the most important unresolved concept-level question.
6. Interview the project owner using focused questions or compact related decision packets according to `guidelines/collaboration-guidelines.md`.
7. Record decisions, assumptions, boundaries, open questions, and candidate glossary terms.
8. Periodically summarize the current shared understanding.
9. Resolve concept-level contradictions and ambiguities.
10. Create or update `workspace/documentation/glossary.md` when project-specific vocabulary appears.
11. Generate `workspace/documentation/concept-and-scope.md` as a complete draft.
12. Present the draft for review and revise it until explicitly approved.

## Output Artifact

Produce `workspace/documentation/concept-and-scope.md` from `setup/artifact-templates/concept-and-scope.md`. The template is the authoritative document structure; this stage's completion criteria are authoritative for content quality.

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
- Project-specific terms that affect scope are clarified or recorded as glossary candidates.
- The project owner explicitly approves the final understanding.
- `workspace/documentation/concept-and-scope.md` has been generated and explicitly approved.

Completion does not require proving technical feasibility, defining detailed behavior, or approving every candidate glossary term.

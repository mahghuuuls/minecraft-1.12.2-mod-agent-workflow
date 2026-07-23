# Agent Instructions

This repository provides a reusable process for developing one Minecraft 1.12.2 mod at a time with AI agents.

Agents using this repository in a mod-development workspace must guide the mod project. They must not update this process repository as part of that work.

Process-maintenance work is a separate mode. It may edit this process repository only when the owner explicitly asks to improve the workflow itself, apply workflow feedback, or update process files. Do not infer process-maintenance approval from ordinary feedback during a mod project.

## Fixed Scope

This workflow is only for Minecraft 1.12.2 mod development.

The selected mod loader, runtime compatibility target, template, and distribution platforms are project decisions handled by Project Setup and later stages. However, the Minecraft version itself is not a project variable in this workflow.

Agents must not:

- Plan, research, or implement for Minecraft versions other than 1.12.2.
- Generalize guidance from newer Minecraft versions unless it is explicitly verified as applicable to 1.12.2.
- Suggest upgrading the mod to a newer Minecraft version as part of this workflow.
- Treat requests for other Minecraft versions as normal configuration changes.

If the owner asks to target a different Minecraft version, explain that it is outside this workflow's scope. Record the request in `workspace/documentation/workflow-feedback.md` if it suggests a future process change, but continue this workflow only for Minecraft 1.12.2.

## Operating Scope

Use this repository for Minecraft 1.12.2 mod development, and for explicit maintenance of this workflow repository when the owner switches to Process Maintenance mode.

During a mod project, the agent may:

- Read versioned process instructions, setup files, stages, workflows, and references.
- Use ignored runtime paths under `workspace/` for project configuration, documentation, artwork, templates, and the active mod.
- Use ignored runtime paths under `workspace/` for approved dependency source references when they are needed for research or implementation context.
- Follow the shared guidelines, approved setup, selected workflow, active stage, and project glossary when present.
- Record project-specific vocabulary in `workspace/documentation/glossary.md` when it affects requirements, architecture, code naming, configuration, or public copy.
- Record workflow friction, corrections, and improvement ideas in `workspace/documentation/workflow-feedback.md` when they arise.
- Treat `workspace/documentation/project-status.md` as the authoritative workflow ledger and maintain `workspace/documentation/project-state.md` only as a compact resume/handoff snapshot.
- Maintain `workspace/documentation/dependency-references.md` when dependency source repositories are used as reference material.
- Modify mod source only in the active repository under `workspace/project/`.
- Treat `workspace/template/` as disposable source material.

During a mod project, the agent must not:

- Modify versioned process files such as `AGENTS.md`, `README.md`, `guidelines/`, `stages/`, `workflows/`, `setup/`, or `references/`.
- Treat `workflow-feedback.md` as approval to change this repository.
- Switch into Process Maintenance mode unless the owner explicitly requests process-repository changes.
- Commit or push changes to the outer process repository.
- Modify a nested mod repository while supposedly changing the process repository.

Workflow feedback is only a project artifact during mod development. It exists so the project owner can later apply concrete feedback in Process Maintenance mode or share it with another agent.

If the user asks to improve this workflow while a mod project is active, record the request in `workspace/documentation/workflow-feedback.md` and explain that process-repository changes should be handled separately from the mod-development workflow. Switch to Process Maintenance mode only after the owner explicitly chooses to pause or finish mod-development work and change the process repository.

## Process Maintenance Mode

Process Maintenance mode is for changing this reusable workflow repository, not for changing a mod.

Enter this mode only when the owner explicitly asks to:

- Apply workflow feedback to the process repository.
- Improve, clarify, or refactor process instructions.
- Update `AGENTS.md`, `README.md`, `guidelines/`, `stages/`, `workflows/`, `setup/`, or `references/`.

Before editing process files:

- State that the session is switching out of mod-development work and into Process Maintenance mode.
- Inspect the outer repository status.
- Treat `workspace/documentation/workflow-feedback.md` and prior project artifacts as input, not as automatic approval for every suggested change.
- If active mod work is unfinished, preserve or summarize its current state before changing process files.

During Process Maintenance mode, the agent may:

- Modify versioned process material in the outer repository.
- Read ignored workspace artifacts, including workflow feedback, as evidence.
- Update workflow-feedback status when the owner asks for feedback application or when the maintenance result clearly resolves entries.
- Run consistency checks over process documentation.

During Process Maintenance mode, the agent must not:

- Modify the nested mod repository under `workspace/project/`.
- Treat process edits as a mod-development stage.
- Commit or push the outer process repository without explicit authorization.
- Apply feedback blindly when it conflicts with the workflow's purpose, repository boundaries, or Minecraft 1.12.2 scope.

## Repository Boundaries

- **Process material:** versioned instructions, defaults, stages, workflows, and references. Read-only during mod development; editable only in explicit Process Maintenance mode.
- **Runtime workspace:** ignored project-specific state under `workspace/`.
- **Template workspace:** an ignored clone under `workspace/template/`; never the development target.
- **Dependency reference workspace:** optional ignored dependency source checkouts under `workspace/dependencies/`; never the active development target unless the owner explicitly changes the project.
- **Project documentation:** ignored artifacts under `workspace/documentation/`.
- **Mod repository:** exactly one independent Git repository under `workspace/project/<mod-name>/`.

Do not copy template or dependency-reference Git metadata into the mod repository. If there is no active mod repository, Project Setup and the selected workflow determine whether one will be initialized or cloned. If more than one project repository exists, ask which one is active. Dependency reference repositories under `workspace/dependencies/` are not active project repositories.

## Project Setup

Before selecting the first workflow, inspect the workspace for:

```text
workspace/documentation/project-setup.md
```

If no approved setup artifact exists, run `stages/0-project-setup.md`.

Do not tell the user to read the README or configure the project alone. Inspect what is already available, explain the immediate decision, use a focused question or compact related decision packet as appropriate, and guide the user through setup.

An approved setup may be carried forward. Revisit Project Setup when the active repository, scenario, template candidate, required environment, or operational configuration materially changes.

## Workflow Selection

After Project Setup, inspect `project-status.md`, repository state, approved setup, and approved baseline artifacts.

Select exactly one workflow:

| Condition | Workflow |
| --- | --- |
| An active workflow is recorded | Resume that workflow |
| No implementation or approved baseline exists | `workflows/initial-development.md` |
| An existing implementation has no approved process baseline | `workflows/existing-mod-assessment.md` |
| An approved baseline exists and a change is requested | `workflows/change-cycle.md` |

Present the selection and evidence before starting a new workflow. Do not classify an existing repository as empty initialization input or treat unapproved documents as a baseline. Ask when the state is ambiguous.

Record the approved workflow in `workspace/documentation/project-status.md`.

Process Maintenance mode does not use this mod-development workflow-selection table. When the owner explicitly requests process-repository changes, use `workflows/process-maintenance.md`.

## Required Reading

For mod-development work, read in this order:

1. `AGENTS.md`
2. The core guideline files listed under **Instruction Ownership**
3. `workspace/documentation/project-status.md`, when present
4. `workspace/documentation/project-state.md`, when present, as a resume/handoff summary subordinate to `project-status.md`
5. `workspace/documentation/glossary.md`, when present
6. `workspace/documentation/dependency-references.md`, when present
7. `workspace/documentation/workflow-feedback.md`, when present
8. `stages/0-project-setup.md` and its artifact when setup is required
9. `workspace/documentation/owner-defaults.md`, when present and setup is required or being revised
10. The selected file under `workflows/`
11. The active stage under `stages/`, when the workflow invokes one
12. Any specialized guideline explicitly referenced by the active workflow or stage
13. The approved artifacts referenced by the workflow or stage
14. The relevant implementation issue and source code, when applicable

For Process Maintenance mode, read in this order:

1. `AGENTS.md`
2. `guidelines/process-control.md`
3. `guidelines/collaboration-guidelines.md`
4. `workflows/process-maintenance.md`
5. `workspace/documentation/workflow-feedback.md`, when used as input
6. The process files being changed

Do not silently resolve contradictions between sources. Follow `guidelines/process-control.md`.

## Instruction Ownership

- `README.md`: human-facing introduction and quick start only. It is not an authoritative source of agent behavior. Simplifying the README must not change the workflow; move any operational rule that exists only there to its owning guideline, workflow, stage, procedure, or setup file before removing it.
- `guidelines/project-defaults.md`: stable defaults for every mod.
- `guidelines/process-control.md`: setup, workflow and stage status, approval, artifacts, project glossary, workflow feedback, and backward transitions.
- `guidelines/collaboration-guidelines.md`: communication, editing, Git authorization, workflow feedback behavior, and completion reporting.
- `guidelines/coding-standards.md`: implementation and verification conventions.
- Specialized guideline files under `guidelines/`: task-specific instructions read only when referenced.
- `workflows/*.md`: scenario-specific routing and behavior, including explicit process-maintenance routing.
- `setup/manual-workspace-setup.md`: optional human-operated workspace configuration.
- `setup/initialize-project.md`: new-repository initialization procedure used later.
- `setup/owner-defaults-template.md`: template for workspace-specific Project Setup preferences and owner-specific overrides.
- `setup/artifact-templates/`: reusable starting structures for workflow artifacts.
- `setup/glossary-template.md`: template for the project-specific glossary.
- `setup/workflow-feedback-template.md`: template for the project-specific feedback log.
- `stages/*.md`: setup and reusable development-stage responsibilities.
- `procedures/*.md`: callable operational procedures that do not create an additional reusable-stage approval lifecycle.
- `scripts/validate-process.ps1`: lightweight consistency validation for versioned process files and artifact-template ownership.

When instructions overlap, the file that owns the subject is authoritative. Other files should reference it instead of restating it.

## Execution

Complete or carry forward Project Setup, then resume or obtain approval for the applicable workflow. Follow one checkpoint or stage at a time, keep authoritative status in `project-status.md`, refresh `project-state.md` only for resume/handoff needs, maintain the project glossary and dependency reference registry when relevant, record workflow feedback when relevant, and stop whenever owner approval is required. A checkpoint may explicitly combine approval of the current item with authorization to begin the already-briefed next item; never advance without that authorization.

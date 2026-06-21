# Agent Instructions

This repository provides a reusable process for developing one Minecraft mod at a time with AI agents.

## Work Mode

Determine the requested mode before changing files.

### Process Maintenance

Use this mode when the user asks to change this process repository. Work only in the outer repository unless instructed otherwise. Do not modify a nested mod repository.

### Mod Development

Use this mode when working on a specific mod:

- Treat versioned process instructions and setup files as read-only.
- Use ignored runtime paths under `workspace/` for project configuration, documentation, artwork, templates, and the active mod.
- Follow the shared guidelines, approved setup, selected workflow, and active stage.
- Modify mod source only in the active repository under `workspace/project/`.
- Treat `workspace/template/` as disposable source material.

If the mode is ambiguous, ask before editing.

## Repository Boundaries

- **Process material:** versioned instructions, defaults, stages, workflows, and references.
- **Runtime workspace:** ignored project-specific state under `workspace/`.
- **Template workspace:** an ignored clone under `workspace/template/`; never the development target.
- **Project documentation:** ignored artifacts under `workspace/documentation/`.
- **Mod repository:** exactly one independent Git repository under `workspace/project/<mod-name>/`.

Do not copy template Git metadata into the mod repository. If there is no active mod repository, Project Setup and the selected workflow determine whether one will be initialized or cloned. If more than one exists, ask which one is active.

## Project Setup

Before selecting the first workflow, inspect the workspace for:

```text
workspace/documentation/project-setup.md
```

If no approved setup artifact exists, run `stages/0-project-setup.md`.

Do not tell the user to read the README or configure the project alone. Inspect what is already available, explain the immediate decision, ask one focused question at a time, and guide the user through setup.

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

## Required Reading

For mod-development work, read in this order:

1. `AGENTS.md`
2. The core guideline files listed under **Instruction Ownership**
3. `workspace/documentation/project-status.md`, when present
4. `stages/0-project-setup.md` and its artifact when setup is required
5. The selected file under `workflows/`
6. The active stage under `stages/`, when the workflow invokes one
7. Any specialized guideline explicitly referenced by the active workflow or stage
8. The approved artifacts referenced by the workflow or stage
9. The relevant implementation issue and source code, when applicable

Do not silently resolve contradictions between sources. Follow `guidelines/process-control.md`.

## Instruction Ownership

- `guidelines/project-defaults.md`: stable defaults for every mod.
- `guidelines/process-control.md`: setup, workflow and stage status, approval, artifacts, and backward transitions.
- `guidelines/collaboration-guidelines.md`: communication, editing, Git authorization, and completion reporting.
- `guidelines/coding-standards.md`: implementation and verification conventions.
- Specialized guideline files under `guidelines/`: task-specific instructions read only when referenced.
- `workflows/*.md`: scenario-specific routing and behavior.
- `setup/manual-workspace-setup.md`: optional human-operated workspace configuration.
- `setup/initialize-project.md`: new-repository initialization procedure used later.
- `stages/*.md`: setup and reusable development-stage responsibilities.

When instructions overlap, the file that owns the subject is authoritative. Other files should reference it instead of restating it.

## Execution

Complete or carry forward Project Setup, then resume or obtain approval for the applicable workflow. Follow one checkpoint or stage at a time, update `project-status.md`, and stop whenever owner approval is required. Never advance automatically.

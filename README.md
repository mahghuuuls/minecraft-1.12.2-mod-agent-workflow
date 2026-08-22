# Minecraft 1.12.2 Mod Agent Workflow

A guided workspace for developing Minecraft 1.12.2 mods with a coding agent such as Codex, Claude Code, Antigravity, or another agent that can inspect files and run development commands. It researches constraints, downloads and inspects an approved mod template such as [CleanroomMC/ForgeDevEnv](https://github.com/CleanroomMC/ForgeDevEnv), plans implementation in reviewable increments, and uses appropriate tests, diagnostic features, in-game checks, and independent review to prepare a release-ready mod. See [Development Stages](#development-stages) for the full process.

This is not designed for one-prompt, unattended vibe coding. You remain responsible for product direction, important technical decisions, approval checkpoints, gameplay judgment, and manual publication to the approved distribution platforms.

The process draws on established engineering practice rather than being invented from scratch: staged approval, requirements traced to the work that satisfies them, independent review in a separate agent context, and verification evidence labelled by how strongly each claim is actually known. Those ideas come from books including *Modern Software Engineering*, *A Philosophy of Software Design*, and *The Pragmatic Programmer*, and from the agent skills published at [AI Hero](https://www.aihero.dev/). See [Acknowledgements](#acknowledgements) for what came from where.

The workflow is revised as mods are actually built with it. Friction encountered during a real project is recorded as feedback and applied afterwards in a separate maintenance pass, so the guidance addresses problems that occurred rather than problems imagined in advance. Mods produced this way are validated in a Cleanroom modpack of over 300 mods, which is where compatibility and load-order problems tend to surface.

If your agent is not following the workflow properly, such as answering in walls of text, skipping required reviews, or recording evidence loosely, see [Working With Skills](#working-with-skills) for optional remedies.

> [!CAUTION]
> AI agents can be dangerous. Use this workflow with care and review the actions an agent proposes or performs.

> [!WARNING]
> By default, the workflow adds an AI usage disclaimer near the top of the mod-page Markdown. The disclaimer states that AI-agent assistance was used and links to this exact workflow. Some players are cautious about AI-assisted mods, so keeping this disclosure is recommended. It gives readers relevant information and lets them consider that when deciding to download the mod.

## Quick Start

Clone the repository:

```bash
git clone https://github.com/mahghuuuls/minecraft-1.12.2-mod-agent-workflow.git
cd minecraft-1.12.2-mod-agent-workflow
```

> [!IMPORTANT]
> Use a separate clone of this workflow repository for each mod project.

Open the cloned directory with your coding agent and choose the prompt matching your situation.

### Option 1: New Mod

```text
Read AGENTS.md and guide me through Project Setup for a new Minecraft 1.12.2 mod.
```

An optional `owner-defaults.md` file records preferences you want to reuse across mod projects, such as loader, runtime, template, license, publication, documentation, and Git workflow choices. When starting another mod, reuse the file from your previous workspace or create one from `setup/owner-defaults-template.md`. Attach or paste it with the request:

```text
Read AGENTS.md and guide me through Project Setup for a new Minecraft 1.12.2 mod.
I have an owner-defaults.md and I am providing it here.
```

Project Setup can also offer the optional [Agent Diagnostics Toolkit](https://github.com/mahghuuuls/agent-test-toolkit), released as Agent Test Toolkit v1.0.0, for owner-assisted runtime checks. It is installed only in development test runtimes, can prepare repeatable scenarios from command bundles, and records structured evidence in the Minecraft log. The preference can be saved in `owner-defaults.md`, so later projects either use it by default or stop asking.

### Option 2: Existing Mod New to This Workflow

```text
Read AGENTS.md and guide me through Project Setup. I have an existing
Minecraft 1.12.2 mod, and I want you to assess and document its current
state before we make changes.
```

### Option 3: Mod Already Managed by This Workflow

```text
Read AGENTS.md and guide me through Project Setup. This mod already uses
this workflow, and I want to plan a new change.
```

That is enough to begin. The agent will inspect the workspace and guide you through the remaining setup decisions.

## Development Stages

For a new mod, the workflow progresses through these stages:

1. **Project Setup:** establish the workspace, tools, defaults, ownership, and project scenario.
2. **Concept and Scope:** define what the mod should do and what it will not do.
3. **Feasibility Research:** verify the technical assumptions, dependencies, and Minecraft 1.12.2 constraints.
4. **Requirements Definition:** turn the approved concept into precise, testable behavior.
5. **Architecture Definition:** decide how the mod will be structured and how its components interact.
6. **Project Initialization:** create the independent mod repository from the approved template.
7. **Implementation Plan:** divide the work into small, ordered, verifiable issues.
8. **Implementation:** write, test, validate, and independently review each issue.
9. **Release Presentation:** prepare public documentation, validate the release artifact, and hand it off for publication.

The stages are ordered, but they are not one-way. You are not locked into the current stage. If your feedback changes the scope, requirements, architecture, or plan, the agent will return to the appropriate stage, update the affected decisions, and then continue from the corrected baseline.

Existing-mod assessments and later change cycles reuse only the stages required by their current state and requested work.

## Repository Structure

```text
minecraft-1.12.2-mod-agent-workflow/
|-- AGENTS.md
|-- guidelines/
|-- workflows/
|-- stages/
|-- procedures/
|-- references/
|-- scripts/
|-- tools/
|-- skills/
|-- setup/
|   |-- owner-defaults-template.md
|   `-- artifact-templates/
`-- workspace/
    |-- documentation/
    |-- artwork/
    |-- dependencies/
    |-- project/
    |-- project.properties
    `-- template/
```

- `AGENTS.md` is the agent entry point.
- `guidelines/` contains core and specialized rules.
- `workflows/` defines scenario-specific routing.
- `stages/` defines setup and development stages.
- `procedures/` contains callable operational checks that do not create another stage lifecycle.
- `scripts/` contains lightweight process-document consistency checks.
- `tools/` contains bundled standalone utilities used by the workflow when its task-specific guidance routes to them.
- `setup/` contains optional manual setup, owner-default templates, artifact templates, defaults, and initialization procedures.
- `references/` contains curated technical links.
- `skills/` contains optional agent skills. Nothing in the workflow requires them; see [Working With Skills](#working-with-skills).
- `workspace/` contains ignored project-specific configuration, setup owner defaults, documents, artwork, dependency references, templates, and the active mod.

Each mod under `workspace/project/` is an independent Git repository with its own commits and remote.

Rare API-provider/API-consumer questions between actively developed mods can use the optional [Cross-Project Agent Consultation](procedures/cross-project-agent-consultation.md). It provides a short local exchange and closing report without adding another development stage or giving either agent authority over the other project.

## Working With Skills

`skills/` holds optional agent skills. **They are not part of the workflow**: no stage references them, and the process behaves identically without them. Use one only when an agent keeps failing to follow the workflow as written; invoking it by name replaces typing the same correction out every time the problem recurs.

Examples from real projects. Claude Opus 5 is known for the wall-of-text problem and the jargon problem; `plain-language` and `bottom-line` are the fix. Gemini 3.1 Pro and Gemini 3.7 Flash had trouble following `guidelines/coding-standards.md`; `standards-review` is the remedy. When in-game tests of a feature keep arriving badly prepared, without a starting state or a defined expected result, `validation-session` is the remedy.

Eight skills are included. See [skills/README.md](skills/README.md) for which one fits which problem, how to install them, and which models needed them in practice.

## Updating Your Copy

The workflow changes regularly as new projects expose gaps in it, so pulling before starting a new mod is worthwhile. Normal users are not expected to edit or commit changes to this workflow repository. Update a clone with:

```bash
git pull --ff-only
```

Project-specific mod work remains in the ignored `workspace/` paths and the independent mod repository.

The workflow records project experiences in `workspace/documentation/workflow-feedback.md`. This feedback can be shared with the repository maintainer when it suggests a reusable improvement.

Process Maintenance is intended for the repository maintainer or for someone deliberately customizing their own clone or fork. Start it with:

```text
Read AGENTS.md and use Process Maintenance mode to apply the workflow feedback.
```

Process Maintenance changes the outer workflow repository only and keeps nested mod repositories out of scope. Feedback is reviewed, not applied automatically.

Recorded source and template revisions keep active mod work traceable when the reusable process changes.

## Manual Setup

Manual configuration is optional. The agent can guide you through it.

For manual instructions, see [Manual Workspace Setup](setup/manual-workspace-setup.md).

## Acknowledgements

### Books

The workflow's engineering assumptions were shaped by reading and applying:

- ***Modern Software Engineering***, David Farley. Working in small verifiable increments, treating feedback speed as a design concern, and requiring an empirical basis for believing something works rather than an assumed one.
- ***A Philosophy of Software Design***, John Ousterhout. Complexity as the thing actually being managed, and the resulting bias against speculative abstraction, unnecessary indirection, and structure added for hypothetical future needs.
- ***The Pragmatic Programmer***, Andrew Hunt and David Thomas. Vertical slices as tracer bullets, and keeping every decision in exactly one place instead of duplicating it across documents.

These show up concretely in the vertical-slice planning model, the design-principle questions in the independent review checklist, the validation environment tiers and their evidence labels, and the rule that later artifacts reference stable identifiers instead of copying content.

### Agent Skills

Several ideas were adapted from the agent skills published at [AI Hero](https://www.aihero.dev/):

- **Decision issues**, from `/wayfinder`. A tracked work item can represent a question to settle rather than a deliverable to build.
- **Reported defect confirmation**, from `/triage`. Establishing that a reported bug is real, and where its cause actually lies, before planning a fix.
- **Investigate before asking**, from the interview skills. Reading available code, artifacts, and dependency sources to answer what the agent can answer itself, instead of asking the owner.

Each was adapted to this workflow's stage, approval, and evidence model rather than adopted directly. This repository does not use or ship agent skills; its instructions are plain Markdown so they work with any agent that can read files.

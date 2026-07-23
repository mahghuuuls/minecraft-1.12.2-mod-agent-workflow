# Minecraft 1.12.2 Mod Agent Workflow

A guided workspace for developing Minecraft 1.12.2 mods with a coding agent such as Codex, Claude Code, Antigravity, or another agent that can inspect files and run development commands. It researches constraints, downloads and inspects an approved mod template such as [CleanroomMC/ForgeDevEnv](https://github.com/CleanroomMC/ForgeDevEnv), plans implementation in reviewable increments, and uses appropriate tests, diagnostic features, in-game checks, and independent review to prepare a release-ready mod.

This is not designed for one-prompt, unattended vibe coding. You remain responsible for product direction, important technical decisions, approval checkpoints, gameplay judgment, and manual publication to the approved distribution platforms.

> [!WARNING]
> By default, the workflow adds an AI usage disclaimer near the top of the mod-page Markdown. The disclaimer states that AI-agent assistance was used and links to this exact workflow. Some players are cautious about AI-assisted mods, so keeping this disclosure is recommended. It gives readers relevant information and lets them consider that when deciding to download the mod.

## Quick Start

Clone the repository:

```bash
git clone https://github.com/mahghuuuls/minecraft-1.12.2-mod-agent-workflow.git
cd minecraft-1.12.2-mod-agent-workflow
```

Open the cloned directory with your coding agent and use the prompt matching your situation.

For a new mod:

```text
Read AGENTS.md and guide me through Project Setup for a new Minecraft 1.12.2 mod.
```

An optional `owner-defaults.md` file records preferences you want to reuse across mod projects, such as loader, runtime, template, license, publication, documentation, and Git workflow choices. When starting another mod, reuse the file from your previous workspace or create one from `setup/owner-defaults-template.md`. Attach or paste it with the request:

```text
Read AGENTS.md and guide me through Project Setup for a new Minecraft 1.12.2 mod.
I have an owner-defaults.md and I am providing it here.
```

For an existing mod that has never used this workflow:

```text
Read AGENTS.md and guide me through Project Setup. I have an existing
Minecraft 1.12.2 mod, and I want you to assess and document its current
state before we make changes.
```

For a mod already managed through this workflow:

```text
Read AGENTS.md and guide me through Project Setup. This mod already uses
this workflow, and I want to plan a new change.
```

That is enough to begin. The agent will inspect the workspace and guide you through the remaining setup decisions.

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
- `setup/` contains optional manual setup, owner-default templates, artifact templates, defaults, and initialization procedures.
- `references/` contains curated technical links.
- `workspace/` contains ignored project-specific configuration, setup owner defaults, documents, artwork, dependency references, templates, and the active mod.

Use a separate clone of this process repository for each mod project.

Each mod under `workspace/project/` is an independent Git repository with its own commits and remote.

## Updating Your Copy

Normal users are not expected to edit or commit changes to this workflow repository. Update a clone with:

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

# Minecraft 1.12.2 Mod Agent Workflow

A guided workspace for developing Minecraft 1.12.2 mods with a coding agent such as Codex, Claude Code, Antigravity, or another agent that can inspect files and run development commands.

This is not designed for one-prompt, unattended vibe coding. The agent interviews you, researches constraints, produces reviewable documents, plans the work, implements approved issues, and verifies the result. You remain responsible for product direction, important technical decisions, approval checkpoints, gameplay judgment, and manual publication to the approved distribution platforms.

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

That is enough to begin. The agent should inspect the workspace, explain what is needed, configure known values, and guide you through unresolved prerequisites one question at a time.

## What to Expect

The agent will:

1. Run Project Setup.
2. Determine whether to start Initial Development, Existing Mod Assessment, or a Change Cycle.
3. Guide you through focused stages with explicit boundaries.
4. Produce project-specific documents outside the final mod repository.
5. Initialize or preserve the independent mod repository at the correct time.
6. Implement approved issues with verification and independent review.
7. Prepare presentation, artwork, the release artifact, and a manual publication handoff.

The agent stops for approval between stages. It should challenge ambiguity and report failed verification rather than inventing decisions or declaring success prematurely.

## Your Role

Expect to participate in:

- Mod purpose, features, and boundaries
- Requirements and edge cases
- Architecture approval
- Artistic direction and icon selection
- In-game and multiplayer judgment
- Review of implementation results
- Manual creation or management of GitHub and distribution-platform resources
- Final publication

The process is intended to make agent-assisted development controlled and understandable, not autonomous at any cost.

## Manual Setup

Manual configuration is optional. The agent can guide you through it.

For manual instructions, see [Manual Workspace Setup](setup/manual-workspace-setup.md).

## Supported Workflows

- **Initial Development:** create and prepare the first release of a new mod.
- **Existing Mod Assessment:** inspect and document the current state of an existing mod before changing its behavior.
- **Change Cycle:** deliver a feature, fix, compatibility update, or refactor against an approved baseline.

## Repository Structure

```text
minecraft-1.12.2-mod-agent-workflow/
├── AGENTS.md
├── guidelines/
├── workflows/
├── stages/
├── references/
├── setup/
└── workspace/
    ├── documentation/
    ├── artwork/
    ├── project/
    ├── project.properties
    └── template/
```

- `AGENTS.md` is the agent entry point.
- `guidelines/` contains core and specialized rules.
- `workflows/` defines scenario-specific routing.
- `stages/` defines setup and development stages.
- `setup/` contains optional manual setup, defaults, and initialization procedures.
- `references/` contains curated technical links.
- `workspace/` contains ignored project-specific configuration, documents, artwork, templates, and the active mod.

Use a separate clone of this process repository for each mod project.

## Git Boundaries

The process repository, temporary template clone, and final mod repository have separate purposes and histories. Before running Git commands, confirm the target:

```bash
git status
git -C workspace/project/<mod-name> status
```

Agents must follow `guidelines/collaboration-guidelines.md`. Commits, pushes, external changes, uploads, and publication require the appropriate explicit authorization.

## Update the Process

```bash
git pull --ff-only
```

Recorded source and template revisions keep active mod work traceable when the reusable process changes.

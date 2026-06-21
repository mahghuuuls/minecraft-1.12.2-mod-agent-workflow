# Manual Workspace Setup

Manual setup is optional. A coding agent can perform this interactively by reading `AGENTS.md` and running Project Setup.

Use this guide when you prefer to configure the runtime workspace yourself before starting the agent.

## 1. Clone the Process Repository

```bash
git clone https://github.com/mahghuuuls/minecraft-1.12.2-mod-agent-workflow.git
cd minecraft-1.12.2-mod-agent-workflow
```

Do not clone a mod template into the process repository manually.

## 2. Choose the Scenario

Determine which description applies:

- **New mod:** no implementation or approved baseline exists.
- **Existing mod assessment:** a repository already contains implementation or release history but has not yet been documented by this workflow.
- **Change cycle:** the mod already has an approved baseline produced by this process.

The agent will confirm this classification during Project Setup.

## 3. Review the Environment

Review the intended environment and compatibility rules in:

```text
guidelines/project-defaults.md
```

At minimum, ensure Git is available. Java and IntelliJ IDEA may be configured before the stages that require them.

Do not install a separate Gradle version; initialized projects use their configured wrapper.

## 4. Configure the Project Repository

Copy the example only when the repository URL and directory name are known:

```bash
cp setup/project.properties.example workspace/project.properties
```

Then edit:

```properties
project_repository_url=https://github.com/owner/example-mod.git
project_directory_name=example-mod
mod_loader=selected-loader
distribution_platforms=curseforge
template_repository_url=https://github.com/owner/selected-template.git
template_repository_ref=branch-tag-or-commit
```

For a new mod, the GitHub repository must be empty before Project Initialization. You may defer creating it while working through Concept, Feasibility, Requirements, and Architecture.

For an existing-mod assessment or a change cycle, identify the existing repository. Do not replace or discard its Git history.

Do not leave example URLs or invented placeholder values in the real properties file.

## 5. Review Template Defaults

Shared preferences are configured in `setup/template-defaults.properties`, but loader and template selection are project-specific.

Record the approved loader and template in `workspace/project.properties`:

```properties
mod_loader=selected-loader
template_repository_url=https://github.com/owner/template.git
template_repository_ref=branch-tag-or-commit
```

Do not edit shared defaults for one mod. Feasibility Research must validate the selected loader, runtimes, template, Java targets, and distribution constraints.

Existing-project workflows preserve the repository's current build system unless an approved change says otherwise.

## 6. Do Not Prepare Runtime Clones Manually

Project Initialization or Existing Mod Assessment will create or identify runtime repositories under:

```text
workspace/template/
workspace/project/
```

Keep template and final-project Git histories separate.

## 7. Start the Agent

Open the process-repository root with a coding agent and send:

```text
Read AGENTS.md and guide me through Project Setup.
```

Tell it whether you are creating a new mod, assessing an existing mod, or continuing an approved mod when known.

The agent will inspect this manual configuration, identify missing prerequisites, and ask for approval before beginning a workflow.

# Project Setup

## Purpose

Prepare the process workspace, establish the project scenario, and guide the project owner through the operational decisions required to begin the correct workflow.

This stage is interactive onboarding. It does not define mod behavior, prove technical feasibility, initialize a final codebase, or implement features.

## Main Question

> Is the workspace sufficiently configured to begin the correct workflow, with later prerequisites understood and assigned?

## Required Input

- The project owner's initial request
- `guidelines/project-defaults.md`
- `workspace/documentation/owner-defaults.md`, when present
- Owner-provided `owner-defaults.md` content supplied in chat, when present
- `setup/owner-defaults-template.md`
- `setup/template-defaults.properties`
- `setup/project.properties.example`
- `references/template-candidates.md`
- Existing `workspace/project.properties`, when present
- Existing workspace documents and repositories, when present

## Objectives

Establish:

- Whether the user is creating, assessing, or changing a mod
- The proposed workflow
- The current tool and workspace state
- The project repository state or the stage by which it must exist
- Practical project identity defaults, when known
- Public documentation style and commit-message style
- Client/server responsibility when the concept is known, or an explicit deferral to Concept and Scope / Feasibility Research when it is premature
- A provisional loader, compatible-runtime, and template choice for Initial Development
- Approved distribution platforms and known operational overrides
- Known dependency source repositories or owner-provided dependency references, only when already relevant
- Release-related ownership boundaries for the project owner and agent
- The intended release handoff mode
- Deferred prerequisites and their deadlines
- A clear starting point requiring no README knowledge

## In Scope

- Explain the workspace and agent-guided process briefly
- Inspect existing configuration and repositories
- Check available Git and Java installations
- Record IntelliJ IDEA availability or installation as a pending prerequisite
- Create required ignored runtime directories
- Create or update `workspace/documentation/project-state.md`
- Create or update `workspace/project.properties` when enough real values are known
- Collect GitHub username, repository name, mod ID, display name, public description, root package, main class, and side/responsibility classification when known
- Defer side/responsibility classification when the mod concept is not yet clear enough to answer it well
- Apply approved default naming conventions instead of asking the owner to invent Java naming patterns from scratch
- Record public documentation style and commit-message style
- Explain the shared platform preferences and available loader/template choices
- Research loader and template candidates when requested or unresolved
- Record provisional loader, runtime, and template candidates or defer final validation to Feasibility Research
- Record known dependency source repositories as optional references, or defer dependency-source decisions to Feasibility Research
- Create or update `workspace/documentation/dependency-references.md` when dependency source references are already approved or supplied
- Explain repository requirements for the selected scenario
- Collect and approve the release ownership matrix
- Record the intended release handoff mode
- Propose the applicable workflow
- Produce `workspace/documentation/project-setup.md`

## Out of Scope

Do not:

- Define features or detailed mod behavior
- Conclude that the concept is technically feasible
- Perform architecture design
- Clone or copy a template into the final project
- Initialize the final mod repository
- Modify existing mod source
- Create commits or push
- Create a GitHub repository or modify an external service without separate explicit authorization
- Clone dependency source repositories unless they are immediately needed and explicitly approved
- Require a new-mod repository before Concept and Scope begins
- Block Concept and Scope because the repository name, mod ID, display name, public description, root package, or main class is not final yet
- Research upload procedures, publication page setup, or external platform mechanics unless the owner explicitly assigns that work to the agent
- Write fake placeholder values into machine-readable configuration

## Desired AI Behavior

Act as an onboarding coordinator.

- Inspect before asking questions.
- Do not direct the user back to the README.
- Treat owner defaults supplied through chat or attachments as first-class setup input, not as a user placement error.
- When chat-provided owner defaults should persist across sessions, offer to save them to `workspace/documentation/owner-defaults.md`.
- Explain only the immediate setup decision.
- Ask one focused question at a time.
- Distinguish required-now values from prerequisites that may be deferred.
- Offer the configured default before researching alternatives.
- Propose conventional naming defaults and ask only when required values are missing, ambiguous, or overridden.
- Explain trade-offs when presenting template candidates.
- Record uncertainty instead of guessing.
- Preserve existing repositories and unrelated workspace content.
- Treat dependency source repositories as optional reference material, not as active project repositories.
- Treat owner-managed responsibilities as hard boundaries unless the owner explicitly changes them.
- Present the setup result and proposed workflow for explicit approval.

## Scenario Classification

Classify exactly one scenario:

### New Mod

Use when no implementation or approved baseline exists.

- Propose Initial Development.
- Explain that an empty final GitHub repository is required during Project Initialization, not before Concept and Scope.
- Collect repository URL and directory name now only when the owner already has them.
- Otherwise record them as deferred values to resolve during Project Initialization before cloning begins.

### Existing Mod Assessment

Use when implementation or release history exists without an approved process baseline.

- Propose Existing Mod Assessment.
- Require the existing repository identity before assessment begins.
- Preserve its history and never apply the empty-repository rule.

### Change to an Approved Mod

Use when an approved baseline exists and another feature, fix, compatibility update, or refactor is requested.

- Propose Change Cycle.
- Confirm that the configured repository and baseline still identify the intended mod.
- Reuse approved setup unless operational configuration changed.

If evidence is insufficient to classify the scenario, ask rather than choosing silently.

## Environment Inspection

Inspect and record:

- Operating system
- Git availability and version
- Java availability and version
- IntelliJ IDEA availability when it can be determined
- Existing process-repository status
- Existing runtime directories
- Existing nested repositories
- Existing configuration and setup artifacts

Project defaults define the intended environment. Missing tools may be installed later when they are not needed by the first stage, but record the stage by which each is required.

Do not install software without explicit authorization.

## Practical Project Defaults

Collect practical defaults early when the owner knows them, but do not block the first design stages when a new mod is still unnamed.

Collect or defer:

- GitHub username or repository owner
- Repository name, if known
- Final repository URL, if known
- Project directory name, if known
- Mod ID, if known
- Display name, if known
- Short public mod description, if known
- Preferred root package
- Preferred main mod class name
- Public documentation style
- Client/server responsibility
- Commit-message style, recorded from the fixed default unless the owner explicitly requests a different style

Use these defaults unless the owner overrides them:

| Decision | Default |
| --- | --- |
| Root package | `com.<github-owner>.<mod-id>` |
| Main mod class | `<PascalCaseDisplayName>Mod` |
| Public documentation style | `split-repository-and-player-facing` |
| Commit-message style | `repo-facing-no-workflow-issue-references` |

Root package rules:

- Use the GitHub owner and mod ID to propose `com.<github-owner>.<mod-id>`.
- Normalize package segments to valid lowercase Java identifiers.
- Ask before using a non-obvious normalization.
- Treat the proposed package as a recommendation, not a hard rule.
- Use an owner-approved override when provided.

Main class rules:

- Convert the display name to PascalCase and append `Mod`.
- The generated name must be a valid Java class identifier.
- Ask when the display name cannot be converted unambiguously.
- Treat the proposed class name as a recommendation, not a hard rule.
- Use an owner-approved override when provided.

Public documentation style rules:

- Default to `split-repository-and-player-facing`.
- For `split-repository-and-player-facing`, keep `README.md` repository-facing and prepare separate player/download-facing copy such as `MOD-PAGE.md` during Release Presentation.
- Assume repository README readers have basic repository and Gradle/modding literacy. Avoid obvious repository statements and basic build instructions unless the project has unusual steps.
- Do not put internal workflow details, implementation evidence, validation logs, or QA-style test reports in public documentation unless the owner explicitly selects a technical style or the detail affects normal player decisions.
- Use a single combined public document only when the owner explicitly chooses that structure.

Client/server responsibility values:

- `client-only`: functionality belongs only on the client.
- `client-first`: primary value is client-side, but compatibility or multiplayer behavior may need documentation or limited checks.
- `server-required`: the mod must be installed or enforced on a server for core behavior.

For a new mod whose concept is not known yet, do not force this classification during Project Setup. Record it as deferred. Concept and Scope should establish the intended behavior, and Feasibility Research should validate the runtime responsibility once the behavior is concrete enough.

Commit-message style rules:

- Default to repo-facing messages.
- Commit messages should describe the repository change itself.
- Do not reference workflow issue IDs, internal issue names, stage documents, or process-only context unless the owner explicitly requests that style.
- Assume a future reader has access to the Git repository but not to the workflow artifacts.
- Treat repo-facing messages as the standing default. Do not ask the owner to approve this default unless they explicitly request a different style.

When enough values are approved, write them to `workspace/project.properties`. When repository or identity values are missing, record them as deferred to Project Initialization rather than blocking earlier design stages.

## Template Guidance

For Initial Development:

1. Read `references/template-candidates.md`.
2. Ask whether the artifact must run on standard Forge, Cleanroom, or both.
3. Ask whether Java, Kotlin, or Scala is intended.
4. Identify required build capabilities such as Mixins, coremods, access transformers, tests, shadowing, or advanced automation.
5. Inspect the current candidate repositories and primary documentation.
6. Present a concise comparison and recommendation.
7. Record the provisional repository, ref, compatibility target, trade-offs, and evidence.
8. Store approved project-specific values in `workspace/project.properties`.

Use this recommendation order unless inspected evidence or project constraints justify another choice:

1. **ForgeDevEnv:** recommended default for broad Forge and Cleanroom compatibility.
2. **CleanroomModTemplate:** specialized choice for Cleanroom-exclusive development.
3. **GregTechCEu Buildscripts:** advanced choice for projects that need its managed build and automation.
4. **TemplateDevEnvKt:** language-specific alternative for Kotlin.
5. **Another researched candidate:** only when the maintained shortlist does not fit.

Do not select CleanroomModTemplate merely because Cleanroom compatibility is desired. A conventional Forge artifact is normally the broader compatibility target; CleanroomModTemplate is appropriate when Cleanroom-native or Java 25-only behavior is intentional.

Do not recommend archived, unlicensed, experimental, or multiversion templates without explaining their risk and proving that they support the approved Minecraft 1.12.2 target.

Template choice remains provisional until Feasibility Research validates it. Do not clone or prototype templates during this stage.

Existing Mod Assessment and Change Cycle begin from the existing loader and build system, but Stage 0 must still record supported runtimes and intended distribution platforms.

## Release Ownership Matrix

Collect an ownership matrix before approving Project Setup. This matrix defines which release-related responsibilities are agent-managed, owner-managed, shared, or deferred.

Use these owner values:

- **Agent:** The agent may perform the work within the approved workflow.
- **Owner:** The project owner performs the work. The agent may record the decision and provide only specifically requested help.
- **Shared:** The agent prepares material, but the owner performs final selection, execution, or external action.
- **Deferred:** The responsibility is intentionally postponed. Record the stage or condition that will revisit it.

Start from these defaults unless the owner changes them:

| Area | Default Owner | Default Notes |
| --- | --- | --- |
| README | Agent | Prepare concise repository-facing documentation unless another documentation style is approved. |
| Mod page or distribution-page copy | Agent | Prepare concise player/download-facing copy such as `MOD-PAGE.md` unless owner-managed or deferred. |
| Changelog | Agent | Prepare concise player-facing release notes from approved changes. |
| Icon | Owner | Do not research, generate, or select an icon unless the owner explicitly assigns icon work to the agent. |
| Screenshots | Owner | Do not plan, request, capture, select, or prepare screenshots unless explicitly assigned. |
| CurseForge upload | Owner | Do not research upload mechanics, publication page setup, or final platform field choices unless explicitly assigned. |
| Release JAR generation | Agent | Generate or identify the normal release artifact when later stages require a release handoff. |
| Final publication verification | Agent | Verify approved local handoff information by default; external publication checks require owner-provided context or explicit approval. |
| Dedicated server testing | Owner | Do not attempt, research, or repeatedly request dedicated server validation unless explicitly assigned. |
| Cleanroom testing | Owner | Record compatibility expectations or limitations; do not attempt or repeatedly request Cleanroom runtime testing unless explicitly assigned. |
| External multiplayer testing | Owner | Do not attempt, research, or repeatedly request external multiplayer validation unless explicitly assigned. |

When asking about the matrix, present the defaults first and ask what the owner wants to override. Do not ask every row as a separate question unless the owner wants detailed control. Apply owner-managed defaults directly unless the owner requests agent involvement or a one-time exception.

Record the approved matrix in `workspace/documentation/project-setup.md`. Later stages must follow it. If a later stage needs to perform owner-managed work, stop and ask the owner to revise the matrix or approve a one-time exception.

Record equivalent machine-readable fields in `workspace/project.properties` when configuration is written. Use `release_handoff_mode` to record the intended release handoff mode used by Release Presentation, or by standalone Packaging and Release Validation when explicitly selected.

## Project Configuration

Use:

```text
workspace/project.properties
```

Only write values that are known and approved.

Relevant values may include:

- `github_username`
- `repository_name`
- `project_repository_url`
- `project_directory_name`
- `mod_id`
- `display_name`
- `public_mod_description`
- `root_package`
- `main_class`
- `mod_authors`
- `minecraft_username`
- `mod_loader`
- `supported_runtimes`
- `distribution_platforms`
- `mod_runtime_role`
- `template_repository_url`
- `template_repository_ref`
- `public_documentation_style`
- `commit_message_style`
- `release_handoff_mode`
- `release_owner_readme`
- `release_owner_mod_page`
- `release_owner_changelog`
- `release_owner_icon`
- `release_owner_screenshots`
- `release_owner_curseforge_upload`
- `release_owner_release_jar_generation`
- `release_owner_final_publication_verification`
- `release_owner_dedicated_server_testing`
- `release_owner_cleanroom_testing`
- `release_owner_external_multiplayer_testing`
- `preferred_development_java_version`
- `target_java_version`
- `project_default_branch`
- `use_modern_java_syntax`
- `license`

Shared defaults remain in `setup/template-defaults.properties`. Do not edit shared defaults during mod development.

If a new mod's repository, directory name, mod ID, display name, public description, root package, or main class is deferred, do not create an invalid properties file merely to complete the stage. Record the missing values and that Project Initialization must resolve them before cloning.

## Process

1. Read the shared defaults and inspect the workspace.
2. Explain that setup can be completed interactively.
3. Identify the scenario.
4. Inspect available environment tools and repositories.
5. Resolve known repository configuration without requiring a final new-mod repository before Concept and Scope.
6. Collect or defer practical project defaults.
7. Resolve or provisionally defer loader, runtime, template, and distribution selections.
8. Present the release ownership defaults and collect approved overrides.
9. Write only approved known operational values.
10. Record deferred prerequisites and the stage by which each is required.
11. Propose the applicable workflow.
12. Produce the setup artifact.
13. Present the artifact and workflow selection for separate explicit approval.

## Output Artifact

Produce:

```text
workspace/documentation/project-setup.md
```

Also create or update:

```text
workspace/documentation/project-state.md
```

When dependency source references are already approved or supplied, create or update:

```text
workspace/documentation/dependency-references.md
```

It should contain:

1. Setup date
2. Classified scenario and evidence
3. Proposed workflow
4. Environment inspection
5. Repository state
6. Practical project defaults, including known values and deferred values
7. Configuration written
8. Provisional loader, runtime, template, and distribution decisions with evidence
9. Known dependency source references or deferred dependency-source decisions
10. Release ownership matrix
11. Release handoff mode
12. Deferred prerequisites and deadlines
13. Blocking problems
14. Owner approvals

Do not include credentials or secrets.

## Completion Criteria

This stage is complete when:

- The scenario is supported by inspected evidence and owner confirmation.
- The proposed workflow is explicit.
- Required-now operational values are configured.
- Unknown repository and project identity values are either recorded or deferred to Project Initialization.
- Future prerequisites have explicit deadlines.
- The loader, runtime, template, and distribution decisions are recorded or legitimately deferred/not applicable.
- Known dependency source references are recorded or explicitly deferred when relevant.
- The release ownership matrix is recorded and approved.
- The release handoff mode is recorded or intentionally deferred.
- No unresolved blocker prevents the selected workflow's first stage.
- `project-setup.md` is approved.
- `project-state.md` summarizes the approved setup and next required action.
- The project owner separately approves the proposed workflow.

Completion permits the selected workflow to begin. It does not approve any development stage.

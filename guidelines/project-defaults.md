# Project Defaults

These defaults apply to every mod unless an approved project-specific decision overrides them.

`setup/template-defaults.properties` is the authoritative source for machine-readable shared preferences. Project identity, loader, compatible runtimes, distribution targets, release ownership, and template selection belong in `workspace/project.properties` and approved project documents.

## Fixed Scope

- Target Minecraft 1.12.2.
- Use the selected loader and compatible runtimes approved during Project Setup and Feasibility Research.
- Do not assume Forge, Cleanroom, LiteLoader, or another loader applies until selected.
- Use loader-specific APIs, metadata, build tooling, and lifecycle rules only when applicable to the selected project.
- Do not change Minecraft version or loader during implementation without returning to the stages that own those decisions.

## Template and Build Tooling

- Project Setup selects a provisional loader and template; Feasibility Research validates them.
- Initialization uses the approved template repository and exact ref recorded in project configuration.
- Use the build tools and wrapper supplied by the approved template or existing project.
- Do not upgrade or replace build components without an approved project-specific reason.
- Record the exact fetched template commit during Initialization.

## Dependency Source References

- Clone or inspect dependency source repositories only when they are needed to answer a concrete research, compatibility, API, or implementation question.
- Prefer released artifacts, official documentation, and public source browsing before adding local dependency source checkouts.
- When a local checkout is justified, place it under `workspace/dependencies/<dependency-name>/` unless the owner provides another approved location.
- Treat dependency source checkouts as read-only reference material. Do not modify, commit, push, vendor, or copy code from them unless the owner explicitly approves that work and licensing has been checked.
- Record the dependency repository URL, ref or commit, reason for checkout, and licensing/usage constraints in the relevant project artifact.

## Development Environment

- Treat `preferred_development_java_version` as a preference, not a guarantee that every template supports it.
- Determine the actual development JDK from the approved loader, template, and build tooling.
- IntelliJ IDEA is the preferred IDE.
- Use the project's wrapper instead of a separately installed build-tool version.
- Use `project_default_branch` for a newly initialized mod repository.

## Runtime Compatibility

- Treat `target_java_version` as the default release target.
- Validate the actual Java target against the selected loader, runtimes, dependencies, and template.
- Do not use runtime APIs newer than the approved target unless an approved compatible dependency supplies them.
- A newer development JDK does not authorize a newer release target.
- Record supported runtime environments explicitly rather than inferring them from the loader name.

## Project Identity

Project Setup or approved project documents must establish:

- GitHub owner or repository owner, when known
- Repository name, when known
- Mod ID and display name
- Root Java package
- Main mod entry-point class
- Author metadata
- Development username when the toolchain uses one
- Short public mod description before repository initialization

Default recommendations for new mods:

- Root package: `com.<github-owner>.<mod-id>`
- Main mod class: `<PascalCaseDisplayName>Mod`

These are recommendations, not hard rules. Use owner-approved overrides when provided.

Normalize generated root package segments to valid lowercase Java identifiers. Ask before applying a non-obvious normalization. The main mod class must be a valid Java class identifier; ask when the display name cannot be converted unambiguously.

Do not leave example values in initialized project files.

## Public Documentation

- Default public documentation style is `split-repository-and-player-facing`.
- `README.md` should be repository-facing by default. Assume readers have basic source repository and Gradle/modding literacy; focus on project-specific purpose, source/release links, install-side expectations, configuration keys, scope boundaries, license, and attribution.
- Player/download-facing copy should live in a separate file by default, such as `MOD-PAGE.md` or another owner-approved distribution-page document.
- Keep internal workflow details, implementation evidence, validation logs, bytecode checks, QA-style test reports, and obvious repository boilerplate out of public documentation unless the owner explicitly asks for them or the information affects normal player decisions.
- Use a single combined document only when the owner explicitly chooses that structure.

## Commit Messages

- Default commit-message style is `repo-facing-no-workflow-issue-references`.
- Commit messages should describe the repository change itself.
- Do not reference workflow issue IDs, internal issue names, stage documents, or process-only context unless the owner explicitly requests that style.
- Assume a future reader has access to the Git repository but not to the workflow artifacts.
- Treat repo-facing commit messages as an invariant default. Do not ask the owner to approve this default during setup; ask only when the owner explicitly requests a different style.

## Release Ownership

Project Setup records a release ownership matrix. Defaults are:

- README: agent-managed
- Mod page or distribution-page copy: agent-managed
- Changelog: agent-managed
- Icon: owner-managed
- Screenshots: owner-managed
- CurseForge upload: owner-managed
- Release JAR generation: agent-managed
- Final publication verification: agent-managed for local handoff information only
- Dedicated server testing: owner-managed
- Cleanroom testing: owner-managed
- External multiplayer testing: owner-managed

Default release handoff mode is `agent-managed-release-validation`. A project may use `owner-managed-packaging` when the owner wants the agent to prepare only a lightweight handoff.

Owner-managed validation checks should be recorded as accepted limitations when skipped. Follow the validation waiver rules in `guidelines/process-control.md`.

Apply owner-managed defaults directly unless the owner explicitly requests agent involvement or a one-time exception.

## Licensing and Attribution

- Read the default project license from `license`.
- A project may override it through `workspace/project.properties`.
- Preserve notices and attribution required by the selected template, loader, dependencies, and reused code.
- Attribute original mod work using approved project author metadata.
- A project license override does not permit removing upstream obligations.

## Distribution

- Treat `preferred_distribution_platform` as the suggested primary destination.
- Project Setup asks the owner to approve one or more distribution platforms.
- CurseForge should be offered as the default recommendation, but it is not mandatory or exclusive.
- Research and follow the current requirements of every selected platform only for agent-managed publication responsibilities.
- Agents may prepare artifacts, documentation, metadata, and visual assets for approved platforms when the ownership matrix assigns that work to the agent.
- The project owner performs every upload and publication action.

## Versioning

- Use semantic versioning unless an approved decision requires another scheme.
- Version changes belong to release work and must not occur incidentally during feature implementation.

## Overrides

- Operational overrides belong in the ignored `workspace/project.properties`.
- Behavioral and architectural decisions belong in approved project documents.
- Explicit project decisions take precedence over shared preferences.
- Never infer or apply an override silently.
- Record consequences when an override affects compatibility, architecture, licensing, or distribution.

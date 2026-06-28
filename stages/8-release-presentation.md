# Release Presentation

## Purpose

Prepare and approve simple player-facing release materials for the implemented mod before technical packaging begins.

This stage is about how the mod is presented to players and modpack authors. It does not build, inspect, checksum, or validate the release JAR, and it does not prepare live upload steps.

## Main Question

> Do the public materials accurately explain what the mod does and why a player would use it?

## Required Input

- `workspace/documentation/project-setup.md`, including the release ownership matrix and public documentation style
- `workspace/documentation/concept-and-scope.md`
- `workspace/documentation/requirements.md`
- `<artifact-root>/implementation-plan.md`
- Completed issues under `<artifact-root>/issues/`
- The completed project under `workspace/project/<project_directory_name>/`
- Approved implementation evidence and known limitations
- Existing approved branding and release materials, when present

Implementation must be approved before this stage begins.

## Objectives

Establish:

- A concise player-facing README or public description suitable for a mod page
- A concise player-facing changelog
- A clear feature summary based only on implemented behavior
- A high-level configuration summary when the mod has user-facing configuration
- Player-facing multiplayer, client/server, dependency, or compatibility notes when normal players need them
- Optional publication-asset decisions for icon and screenshots without blocking README, changelog, or packaging when owner-managed or deferred
- An internal presentation record that separates public copy from technical evidence and unresolved limitations

## In Scope

- Create or update `README.md` as player-facing mod-page style copy
- Create or update `CHANGELOG.md` as player-facing release notes
- Prepare a CurseForge-style project description or summary text when public copy is agent-managed
- Summarize implemented features in player language
- Summarize configuration at a high level when applicable
- Include player-facing multiplayer or client/server notes when they affect installation or use
- Record known limitations in public materials only when normal players must know them before installing or using the mod
- Record icon and screenshot ownership, deferral, or agent-managed work
- Follow icon or screenshot workflows only when those areas are agent-managed or explicitly assigned
- Produce `<artifact-root>/release-presentation.md`

## Out of Scope

Do not:

- Add or change mod behavior
- Perform unrelated refactoring
- Build the final release JAR
- Inspect bytecode or JAR contents
- Generate checksums
- Perform release validation or clean-instance testing
- Include build evidence, bytecode details, validation logs, QA-style usage steps, or internal test reports in the public README
- Include redundant platform requirements that the distribution platform already displays unless players need the information to decide whether to install
- Research upload mechanics, live project fields, publication-page setup, or final platform field choices unless explicitly assigned by the owner
- Prepare screenshots or icon work when those areas are owner-managed
- Block README, changelog, or packaging approval because an owner-managed icon or screenshot is not ready
- Include Cleanroom caveats unless they affect normal player installation, compatibility expectations, or usage decisions
- Upload assets or files to a distribution platform
- Publish a release

An implementation defect returns to Implementation. An inaccurate public claim returns to the stage that owns the underlying behavior or decision.

## Desired AI Behavior

Act as a player-facing release editor.

- Use concise, plain player-facing language.
- Assume the public README may be reused as mod-page information.
- Describe only implemented and approved behavior.
- Explain why a player would want the mod before listing technical details.
- Keep configuration and multiplayer notes high-level unless a player must follow a specific rule.
- Keep internal engineering evidence out of public files.
- Keep technical evidence, unresolved validation gaps, and ownership decisions in `release-presentation.md`.
- Follow the release ownership matrix strictly.
- Treat icon and screenshot work as optional publication assets, not as blockers for README, changelog, or packaging unless explicitly agent-managed and required by the owner.
- Ask one focused question at a time when public wording, limitations, or asset ownership needs owner input.
- Never upload or publish.

## Public README Guidance

When the approved public documentation style is `player-facing`, the README should read like a concise mod-page description.

Include only sections that help normal players or modpack authors, such as:

1. Mod name and short summary
2. Why use it
3. Main features
4. High-level configuration summary, when applicable
5. Important player-facing multiplayer, client/server, dependency, or compatibility notes
6. Known limitations only when they affect installation or use
7. Credits and license when appropriate for the repository

Avoid public README sections that are primarily internal or redundant, including:

- Build verification
- Bytecode or artifact evidence
- QA test procedures
- Internal validation gaps
- Implementation details
- Workflow history
- Installation tutorials that duplicate platform conventions
- Redundant requirements already shown by the distribution platform
- Cleanroom or loader caveats that do not affect normal player decisions

If the owner selected `technical` or `both`, keep player-facing copy separate from technical repository documentation where practical.

## Changelog Guidance

The changelog should summarize player-visible changes.

Use concise categories such as:

- Added
- Changed
- Fixed
- Compatibility
- Known Issues

Exclude internal refactors, implementation history, and workflow details unless they affect users.

## Optional Publication Assets

Icon and screenshot work is optional publication-asset work. It must not block README/changelog approval or Packaging and Release Validation when it is owner-managed or deferred.

Use the release ownership matrix from Project Setup.

Stage 8 supports these icon paths:

1. **Owner Provides Icon:** The owner creates, selects, or uploads the icon outside the agent workflow.
2. **Agent Helps Create Icon:** The owner explicitly assigns icon creation or revision to the agent.
3. **Icon Deferred:** Icon work is intentionally postponed and does not block the rest of the release handoff.

If the owner provides the icon:

- Record `Owner Provides Icon`.
- Do not research, generate, select, or request icon references.
- Do not block README, changelog, or packaging on the icon.

If the icon is deferred:

- Record `Icon Deferred` and the owner-approved reason or follow-up condition.
- Do not block README, changelog, or packaging on the icon.

If the agent helps create or revise the icon, record one of these decisions and follow the icon guideline:

- **Carry Forward:** Existing approved icon remains suitable.
- **Revise:** Existing visual identity remains valid but needs a focused change.
- **Create:** No approved suitable icon exists and the agent is assigned to help create it.

Use:

```text
guidelines/mod-icon-creation.md
```

When icon work is **Revise** or **Create**, create the artwork workspace and explicitly ask the owner to add reference images there or attach them in chat. Do not assume the owner has read repository documentation.

Screenshot paths are equivalent:

- **Owner Provides Screenshots**
- **Agent Helps Prepare Screenshots**
- **Screenshots Deferred**

If screenshots are owner-managed or deferred, do not plan, request, capture, select, or prepare screenshots. If screenshots are explicitly assigned to the agent, they must show actual implemented behavior. Do not substitute generated imagery for gameplay or UI evidence.

## Internal Presentation Record

`release-presentation.md` may include technical notes that should not appear in public README copy.

Use it to record:

- Source implementation evidence supporting public claims
- Ownership decisions for README, changelog, icon, screenshots, upload, publication, and validation
- Whether icon and screenshots are owner-provided, agent-managed, or deferred
- Known limitations and whether they are public-facing or internal
- Deferred owner-managed assets or publication actions
- Questions that Packaging and Release Validation must consider

Do not use the internal record as public copy.

## Process

1. Confirm that Implementation is approved.
2. Read the release ownership matrix and public documentation style from Project Setup.
3. Review completed issues, approved behavior, and known limitations.
4. Identify which public materials are agent-managed.
5. Draft or update player-facing README content when agent-managed.
6. Draft or update player-facing changelog content when agent-managed.
7. Prepare a CurseForge-style summary or description only as reusable public copy, not as upload-field research.
8. Add high-level configuration and player-facing multiplayer/client/server notes when applicable.
9. Record icon and screenshot paths as owner-provided, agent-managed, or deferred.
10. Follow icon or screenshot workflows only when those areas are agent-managed or explicitly assigned.
11. Check every public claim against approved implementation evidence.
12. Keep technical evidence and internal limitations in `release-presentation.md` rather than public README copy.
13. Present public materials and the internal presentation record for approval.
14. Revise until explicitly approved.

## Output Artifacts

### Final Project Repository

Prepare only applicable public-facing files and agent-managed assets:

- `README.md`
- `CHANGELOG.md`
- Approved mod icon, only when agent-managed or explicitly assigned
- Approved screenshots or description images, only when agent-managed or explicitly assigned

### Presentation Record

Produce:

```text
<artifact-root>/release-presentation.md
```

It should contain:

1. Public documentation style
2. Release ownership matrix summary
3. README status and intended audience
4. Changelog status
5. Reusable public description or summary text
6. Feature summary
7. Configuration summary, when applicable
8. Player-facing multiplayer, client/server, dependency, or compatibility notes
9. Icon path: owner provides, agent helps create, or deferred
10. Screenshot path: owner provides, agent helps prepare, or deferred
11. Public-facing known limitations
12. Internal technical notes and validation gaps excluded from public copy
13. Claims checked against implementation evidence
14. Owner approvals

## Completion Criteria

This stage is complete when:

- Public README or description copy is concise, player-facing, and approved.
- Changelog is concise, player-facing, and approved.
- Feature, configuration, and multiplayer/client/server notes match implemented behavior.
- Icon and screenshot paths are recorded as owner-provided, agent-managed, or deferred.
- Owner-managed or deferred icon and screenshot work does not block README, changelog, or packaging.
- Agent-managed icon or screenshot work, if any, is approved or explicitly deferred by the owner.
- Owner-managed upload and publication responsibilities are respected.
- Public materials do not include build evidence, bytecode details, QA-style usage steps, internal validation findings, redundant platform requirements, upload mechanics, or irrelevant Cleanroom caveats.
- Technical notes are kept in `release-presentation.md`, not public README copy.
- Every public claim is supported by approved implementation evidence.
- `<artifact-root>/release-presentation.md` is generated and approved.

Completion authorizes Packaging and Release Validation. It does not authorize publication.

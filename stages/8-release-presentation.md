# Release Presentation

## Purpose

Prepare and approve repository-facing and player-facing release materials for the implemented mod, then prepare the validated release artifact handoff when release validation is agent-managed.

This stage is about how the mod is presented to players and modpack authors and what handoff the owner needs for manual publication. It does not prepare live platform-submission steps and never uploads or publishes the mod.

## Main Question

> Do the public materials accurately explain the mod, and is the release handoff ready for owner-managed publication?

## Required Input

- `workspace/documentation/project-setup.md`, including the release ownership matrix and public documentation style
- `workspace/documentation/concept-and-scope.md`
- `workspace/documentation/requirements.md`
- `workspace/documentation/glossary.md`, when present
- `<artifact-root>/implementation-plan.md`
- Completed issues under `<artifact-root>/issues/`
- The completed project under `workspace/project/<project_directory_name>/`
- Approved implementation evidence and known limitations
- Existing approved branding and release materials, when present

Implementation must be approved before this stage begins.

## Objectives

Establish:

- A concise repository-facing README when agent-managed
- A separate concise player/download-facing public description suitable for a mod page when agent-managed
- A generic AI usage disclaimer near the top of player/download-facing copy by default, unless the owner asks to remove or rewrite it
- A concise player-facing changelog
- The approved release version, defaulting to `1.0.0` for a first public release unless the owner chooses otherwise
- A clear feature summary based only on implemented behavior
- A high-level configuration summary when the mod has user-facing configuration
- Player-facing multiplayer, client/server, dependency, or compatibility notes when normal players need them
- Optional publication-asset decisions for icon and screenshots without blocking README, changelog, or packaging when owner-managed or deferred
- Public wording that uses approved glossary terms consistently when the glossary applies
- An internal presentation record that separates public copy from technical evidence and unresolved limitations
- A release handoff record when release JAR generation or validation is agent-managed

## In Scope

- Create or update `README.md` as repository-facing project documentation
- Create or update separate player/download-facing copy, such as `MOD-PAGE.md` or an owner-approved equivalent
- Create or update `CHANGELOG.md` as player-facing release notes
- Prepare a CurseForge-style project description or summary text when public copy is agent-managed
- Include the default AI usage disclaimer in `MOD-PAGE.md` or equivalent player/download-facing copy unless the owner opts out
- Summarize implemented features in player language
- Summarize configuration at a high level when applicable
- Include player-facing multiplayer or client/server notes when they affect installation or use
- Use approved glossary terms consistently in public copy
- Record known limitations in public materials only when normal players must know them before installing or using the mod
- Record icon and screenshot ownership, deferral, or agent-managed work
- Follow icon or screenshot workflows only when those areas are agent-managed or explicitly assigned
- Produce `<artifact-root>/release-presentation.md`
- Confirm the approved release version before packaging or handoff
- Build, inspect, checksum, and record the release artifact when release JAR generation/validation is agent-managed by Project Setup or explicit owner instruction
- Produce `<artifact-root>/release-handoff.md` when a release artifact is built or identified

## Out of Scope

Do not:

- Add or change mod behavior
- Perform unrelated refactoring
- Perform clean-instance, dedicated-server, Cleanroom, or multiplayer runtime testing unless assigned by the ownership matrix or explicitly requested by the owner
- Include build evidence, bytecode details, validation logs, QA-style usage steps, or internal test reports in public documentation
- Include redundant platform requirements that the distribution platform already displays unless players need the information to decide whether to install
- Research platform-submission mechanics, live project fields, page setup, or final platform field choices unless explicitly assigned by the owner
- Prepare screenshots or icon work when those areas are owner-managed
- Block README, changelog, or packaging approval because an owner-managed icon or screenshot is not ready
- Include Cleanroom caveats unless they affect normal player installation, compatibility expectations, or usage decisions
- Send assets or files to a distribution platform
- Publish a release
- Keep the workflow open only to wait for manual publication

An implementation defect returns to Implementation. An inaccurate public claim returns to the stage that owns the underlying behavior or decision. A terminology conflict returns to the glossary-owning stage that introduced or approved the term.

## Desired AI Behavior

Act as a release documentation editor.

- Use concise, plain player-facing language.
- Read and use approved glossary terms when present.
- Preserve preferred public terminology from the glossary.
- Ask before changing an approved term in public copy.
- Record new or changed public-facing terms in the glossary when they affect how players, modpack authors, config users, or later documents should refer to a feature.
- Keep repository README and mod-page copy separate by default unless the owner explicitly chooses a combined document.
- Describe only implemented and approved behavior.
- In player/download-facing copy, explain why a player would want the mod before listing technical details.
- Keep configuration and multiplayer notes high-level unless a player must follow a specific rule.
- Keep internal engineering evidence out of public files.
- Keep technical evidence, unresolved validation gaps, and ownership decisions in `release-presentation.md`.
- Keep release build, artifact inspection, checksum, and handoff evidence in `release-handoff.md`.
- Treat mod-page copy as an iterative public-copy artifact; review it for audience fit, repetition, useful links, owner-provided wording, roadmap-risk wording, concise scope, and plain install-side statements.
- Treat the AI usage disclaimer as a default transparency note, not as internal workflow history. Keep it short, generic, and removable by owner request.
- Follow the release ownership matrix strictly.
- For agent-managed validation, validate the artifact from the exact clean committed revision recorded in the handoff. Do not treat a build from uncommitted release changes as final release evidence.
- Treat icon and screenshot work as optional publication assets, not as blockers for README, changelog, or packaging unless explicitly agent-managed and required by the owner.
- Use a focused question for a branching public claim or ownership decision; group related low-risk copy decisions into a compact review packet.
- Never submit files to distribution platforms or publish releases.

## Public Documentation Guidance

Use approved glossary terms for feature names, configuration concepts, compatibility notes, and player-facing behavior. Do not introduce synonyms merely for variety when consistency matters.

### Repository README Guidance

`README.md` is repository-facing by default.

Assume readers have basic source repository and Gradle/modding literacy. Focus on project-specific information, such as:

1. Mod name and short project purpose
2. Links to player-facing release copy, changelog, license, and third-party notices when present
3. Mod identity, install-side expectations, and configuration keys when useful
4. Scope boundaries that matter to maintainers or pack authors
5. License and attribution

Avoid obvious or generic README content, including:

- Statements that merely say the repository contains the source code
- Basic build commands unless the project has unusual build steps
- Workflow history
- QA test procedures
- Internal validation gaps
- Platform-page copy duplicated at length

### Mod Page Copy Guidance

Player/download-facing copy should live in a separate file by default, such as `MOD-PAGE.md` or another owner-approved distribution-page document.

Draft the smallest useful mod page first and expand it only when a normal player needs more information to decide, install, or configure the mod. For a narrow mod, the default shape is:

1. One short opening paragraph explaining the value.
2. The approved AI usage disclaimer.
3. A few feature bullets only when the opening does not already communicate the behavior.
4. One compact configuration example when configuration is central.
5. One plain installation-side statement.
6. Only limitations that materially affect normal installation or use.
7. A useful source or companion-project link when applicable.

Do not turn the mod page into a condensed requirements document. Avoid enumerating every numeric validation rule, parser edge case, excluded source, compatibility qualification, or internal evidence result. Keep those details in generated config comments, the repository README, changelog, or internal presentation record according to their audience. Prefer combining a short explanation with its example over creating a separate section for every topic.

Include this generic AI usage disclaimer near the top of player/download-facing copy by default, after the opening description and before feature details:

```html
<p style="color: #d6a100;"><strong>AI usage disclaimer:</strong> This mod was developed with AI-agent assistance. The project owner reviewed the work during development.</p>
```

The owner may ask to remove, revise, or expand the disclaimer. Do not add project-specific testing claims, pack-size claims, Cleanroom claims, or compatibility claims to the generic disclaimer unless the owner explicitly approves that wording for the project. If the selected publication platform strips inline styling, keep the disclaimer text unless the owner asks to remove it.

Include only sections that help normal players or modpack authors decide whether and how to use the mod, such as:

1. Short owner-approved introduction
2. AI usage disclaimer, unless removed or rewritten by owner request
3. Why use it
4. Main features
5. High-level configuration summary, when applicable
6. Important player-facing multiplayer, client/server, dependency, or compatibility notes
7. Known limitations only when they affect installation or use
8. Useful project or companion-mod links

When the repository URL is known, include a GitHub/source link by default unless the owner explicitly omits it or the selected platform already provides a sufficiently visible source link.

Review mod-page copy for:

- Audience fit: player/download-page readers, not source repository readers
- Tone: preserve owner-provided introductory wording when supplied
- Repetition: avoid repeating the mod name or the same compatibility point unnecessarily
- Link usefulness: include relevant external links when they help players
- Platform redundancy: remove or justify Minecraft version, loader, dependency, and other metadata when the distribution platform already displays it and the prose does not need it
- Plain language: replace internal qualifiers such as "best-effort", "runtime evidence", "validation", or "implementation limitation" with user-facing wording, or omit them when the caveat does not affect installation or practical use
- Roadmap risk: avoid phrases such as `first release` unless future support promises are intentional
- Scope clarity: keep limitations concise without over-explaining implementation details
- Installation clarity: state required install sides plainly

Avoid player-facing sections that are primarily internal or redundant, including:

- Build verification
- Bytecode or artifact evidence
- QA test procedures
- Internal validation gaps
- Implementation details
- Workflow history
- Installation tutorials that duplicate platform conventions
- Redundant requirements already shown by the distribution platform
- Cleanroom or loader caveats that do not affect normal player decisions

If the owner explicitly selects a combined documentation style, keep repository-oriented and player-facing content clearly separated.

## Changelog Guidance

The changelog should summarize player-visible changes.

Use concise categories such as:

- Added
- Changed
- Fixed
- Compatibility
- Known Issues

Use approved glossary terms for feature names and player-visible behavior. Exclude internal refactors, implementation history, and workflow details unless they affect users.

## Optional Publication Assets

Icon and screenshot work is optional publication-asset work. It must not block README/changelog approval, release artifact validation, or handoff approval when it is owner-managed or deferred.

Use the release ownership matrix from Project Setup.

Stage 8 supports these icon paths:

1. **Owner Provides Icon:** The owner creates, selects, or provides the icon outside the agent workflow.
2. **Agent Helps Create Icon:** The owner explicitly assigns icon creation or revision to the agent.
3. **Icon Deferred:** Icon work is intentionally postponed and does not block the rest of the release handoff.

If the owner provides the icon:

- Record `Owner Provides Icon`.
- Do not research, generate, select, or request icon references.
- Do not block README, changelog, release artifact validation, or handoff approval on the icon.

If the icon is deferred:

- Record `Icon Deferred` and the owner-approved reason or follow-up condition.
- Do not block README, changelog, release artifact validation, or handoff approval on the icon.

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

If screenshots are owner-managed or deferred, do not plan, request, capture, select, or prepare screenshots. If screenshots are explicitly assigned to the agent, they must show actual implemented behavior.

## Internal Presentation Record

`release-presentation.md` may include technical notes that should not appear in public README or mod-page copy.

Use it to record:

- Source implementation evidence supporting public claims
- Ownership decisions for README, changelog, icon, screenshots, platform submission, publication, and validation
- Whether icon and screenshots are owner-provided, agent-managed, or deferred
- Known limitations and whether they are public-facing or internal
- Deferred owner-managed assets or publication actions
- Public terminology decisions and glossary updates
- Questions that release handoff or a later `procedures/revalidate-release.md` run must consider
- Release artifact identity, checksum, and inspection evidence when handled in this stage

Do not use the internal record as public copy.

## Process

1. Confirm that Implementation is approved.
2. Read the release ownership matrix and public documentation style from Project Setup.
3. Read `workspace/documentation/glossary.md`, when present.
4. Review completed issues, approved behavior, and known limitations.
5. Identify which public materials are agent-managed.
6. Draft or update repository-facing README content when agent-managed.
7. Draft or update player/download-facing mod-page copy when agent-managed, including the default AI usage disclaimer unless the owner opts out.
8. Draft or update player-facing changelog content when agent-managed.
9. Prepare a CurseForge-style summary or description only as reusable public copy, not as platform-field research.
10. Add high-level configuration and player-facing multiplayer/client/server notes when applicable.
11. Record icon and screenshot paths as owner-provided, agent-managed, or deferred.
12. Follow icon or screenshot workflows only when those areas are agent-managed or explicitly assigned.
13. Check every public claim against approved implementation evidence and approved glossary terminology.
14. Update `workspace/documentation/glossary.md` when release copy approves, refines, or deprecates public-facing project terminology.
15. Keep technical evidence and internal limitations in `release-presentation.md` rather than public README or mod-page copy.
16. Inspect the mod repository, then present the complete public materials, release version, intended release-file scope, and proposed commit message before final artifact validation. The checkpoint may ask the owner to (a) approve the materials and (b) authorize the focused release-preparation commit in one response, but the two decisions must be labeled separately.
17. Treat public-material approval and commit authorization as separate authorization boundaries even when requested together. Public-material approval alone does not authorize the commit.
18. If the materials are approved and the commit is authorized, commit only the approved release/version/public-material changes and verify the repository is clean at the resulting revision.
19. If release validation is agent-managed, build the exact release artifact from that clean committed revision, inspect it, calculate its checksum, and record the handoff.
20. If release packaging is owner-managed, record the approved source revision, expected command/artifact pattern, and owner-managed boundary instead of building.
21. Present the completed internal presentation record and release handoff for stage approval.
22. Revise until explicitly approved. If a revision changes the committed release source, obtain new commit authorization and repeat artifact validation before final approval.

## Output Artifacts

### Final Project Repository

Prepare only applicable repository/public files and agent-managed assets:

- `README.md`
- `MOD-PAGE.md` or an owner-approved equivalent when player/download-facing copy is agent-managed
- `CHANGELOG.md`
- Approved mod icon, only when agent-managed or explicitly assigned
- Approved screenshots or description images, only when agent-managed or explicitly assigned

### Presentation Record

Produce:

```text
<artifact-root>/release-presentation.md
```

Start from `setup/artifact-templates/release-presentation.md`. The template is the authoritative presentation-record structure; omit nonapplicable sections and use this stage's completion criteria to judge content quality.

When a release artifact is built, inspected, identified, or handed off, also produce:

```text
<artifact-root>/release-handoff.md
```

### Release Handoff Record

Create `release-handoff.md` from `setup/artifact-templates/release-handoff.md`. The template is the authoritative handoff structure; omit artifact-validation fields only when packaging is owner-managed and record that boundary explicitly.

## Completion Criteria

This stage is complete when:

- Repository README copy is concise, repository-facing, and approved when agent-managed.
- Mod-page or distribution-page copy is concise, player/download-facing, and approved when agent-managed.
- Mod-page or distribution-page copy includes the default AI usage disclaimer near the top unless the owner approved removing or rewriting it.
- Changelog is concise, player-facing, and approved.
- Feature, configuration, and multiplayer/client/server notes match implemented behavior.
- Public wording uses approved glossary terms consistently when the glossary applies.
- Public-facing glossary updates introduced by release copy are recorded.
- Icon and screenshot paths are recorded as owner-provided, agent-managed, or deferred.
- Owner-managed or deferred icon and screenshot work does not block README, changelog, or packaging.
- Agent-managed icon or screenshot work, if any, is approved or explicitly deferred by the owner.
- Owner-managed platform submission and publication responsibilities are respected.
- Public materials do not include build evidence, bytecode details, QA-style usage steps, internal validation findings, redundant platform requirements, platform-submission mechanics, or irrelevant Cleanroom caveats.
- Technical notes are kept in `release-presentation.md`, not public README or mod-page copy.
- Every public claim is supported by approved implementation evidence.
- `<artifact-root>/release-presentation.md` is generated and approved.
- `<artifact-root>/release-handoff.md` is generated and approved when a release artifact is built, identified, or handed off.
- The approved release version is recorded; first public releases default to `1.0.0` unless the owner chose otherwise.
- Agent-managed release artifacts are built, inspected, and checksummed from the clean committed source revision recorded in the handoff.
- No uncommitted release/version/public-material change remains when an agent-managed artifact handoff is finalized.
- Owner-managed publication remains clearly outside the agent workflow.

Completion ends agent-managed release work for the stage. Manual publication remains the project owner's responsibility and does not block workflow completion unless the owner explicitly requests publication tracking.

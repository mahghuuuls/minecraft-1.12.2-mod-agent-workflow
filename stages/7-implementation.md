# Implementation

## Purpose

Implement the approved plan one issue at a time while continuously verifying that each increment satisfies its requirements and follows the approved architecture.

Implementation includes coding, testing, in-game verification, defect correction, independent review, and commit checkpoints after completed increments.

## Main Question

> Does each planned increment work correctly?

## Required Input

- `workspace/documentation/project-status.md`
- `<artifact-root>/implementation-plan.md`
- The selected issue under `<artifact-root>/issues/`
- The requirements and architecture references named by that issue
- The active project under `workspace/project/<project_directory_name>/`
- `guidelines/coding-standards.md`, which governs how the code is written and what counts as verification in this stage
- `guidelines/manual-validation.md` when the issue includes owner-assisted runtime checks
- `guidelines/agent-diagnostics-toolkit.md` when Project Setup selected the toolkit
- `guidelines/minecraft-pixel-art.md` when the issue creates or materially revises pixel-art assets

## Objectives

For each implementation issue:

- Implement the defined behavior
- Follow the approved architecture
- Satisfy the acceptance criteria
- Run appropriate automated checks
- Verify behavior inside Minecraft where necessary
- Check client and dedicated-server behavior where relevant
- Validate technical uncertainties assigned to the issue
- Record completion evidence, labelling each claim observed, inspected, or inferred
- Record accepted validation waivers when the owner skips or owns a check
- Obtain an independent review
- Correct legitimate review findings
- Create, inspect, and obtain owner selection of pixel-art candidates when the issue includes artwork
- Resolve the commit checkpoint after the issue is Done, using either specific approval or an applicable standing authorization

## In Scope

- Production code
- Resources and configuration files
- Automated tests where practical
- Build and compilation checks
- Development-client verification
- Dedicated-server verification when assigned or required by approved issue evidence
- Multiplayer verification when assigned or required by approved issue evidence
- Compatibility verification when assigned or required by approved issue evidence
- Performance measurements
- Logging and diagnostic improvements
- Defect correction
- Refactoring directly related to the issue
- Proportionate local design improvements authorized by the Strategic Modification rules in `guidelines/coding-standards.md`
- Independent implementation and architecture review
- Updating issue status and completion evidence
- Commit checkpoint preparation after completed issues
- Accepted validation waiver recording
- Explicitly approved architecture updates

## Out of Scope

Do not:

- Add unapproved features
- Expand the issue beyond its defined scope
- Silently reinterpret requirements
- Silently change the architecture
- Perform unrelated refactoring
- Add speculative abstractions for hypothetical future needs
- Prepare the final README, changelog, icon, or distribution-platform page
- Publish or release the mod
- Perform maintenance work outside the current project scope

If implementation reveals a problem in an earlier document, return to the relevant stage instead of silently compensating in the code.

## Desired AI Behavior

Act as a focused implementation agent.

- Work on one Ready issue at a time.
- Confirm that all blocking issues are Done before starting, except for the exact **Awaiting Validation** predecessor allowed by an approved validation campaign.
- Read the issue and its referenced requirements and architecture sections.
- Read and apply the Complexity Management and Strategic Modification rules in `guidelines/coding-standards.md` before structural work.
- Inspect the existing codebase before making changes.
- Inspect approved dependency source references when the issue or architecture depends on them.
- For a pixel-art asset issue, read `guidelines/minecraft-pixel-art.md`, confirm that its brief and reference decision are approved, and keep unapproved candidates in the issue's artwork workspace rather than the mod repository.
- Preserve existing project conventions unless an approved decision requires otherwise.
- Apply the approved Existing-Code Design Fit target when one applies and follow the Strategic Modification rules; do not use diff size as a substitute for design quality.
- For a complexity-bearing issue, establish the approved interface and authoritative knowledge owner before filling in implementation details.
- Do not introduce shallow wrappers, duplicated policy, pass-through layers, or caller-managed lifecycle ordering unless the approved issue or architecture names the concrete constraint that requires them.
- Use the local-improvement authority and revision boundary in `guidelines/coding-standards.md`. Do not treat prior architecture approval as a reason to preserve a newly exposed design defect.
- Keep the change limited to the issue's scope.
- Use existing libraries and architectural components as documented.
- Avoid duplicating functionality already present in the project or its dependencies.
- Treat dependency source checkouts under `workspace/dependencies/` as read-only references. Do not modify them or copy code from them unless the owner explicitly approves that work and licensing has been checked.
- Run fast feedback checks throughout implementation.
- Use test-first development for isolated logic when it provides clear value.
- For a reproduced defect, establish the planned regression check before applying the correction when practical, record its pre-correction failure, and retain the check after it passes. If that order is impractical or unsafe, perform the planned controlled sensitivity demonstration or record the approved runtime fallback and its limitation.
- Never weaken an assertion, avoid the failing boundary, or replace the original reproducer merely to make a regression check pass.
- Do not force TDD onto behavior that can only be meaningfully verified inside Minecraft.
- Perform the verification defined by the issue.
- Before asking the owner to perform a manual check, confirm that the issue's planned observability mechanism is implemented and usable. Do not substitute indirect inference when the plan requires authoritative logs, commands, counters, or equivalent diagnostics.
- Present owner-assisted checks using the session map and test cards in `guidelines/manual-validation.md`.
- When the toolkit is selected, verify the pinned artifact and live capabilities, write the approved bundles, and inspect bundle completion and structured records instead of asking the owner to relay setup commands or log text.
- After the owner performs a manual action, inspect agent-accessible current and rotated logs directly. Ask the owner for log content only when the runtime is external, the files are unavailable, or direct inspection fails.
- Keep diagnostic work within the approved issue or its declared prerequisite. If required observability is missing from the plan, treat it as a Planning Problem rather than silently expanding the issue or sending an unreliable test recipe.
- Treat compilation as necessary but not sufficient evidence that behavior works.
- Check dedicated-server safety whenever client-only code is involved and the check is assigned or practical.
- Record accepted validation waivers instead of repeatedly pushing owner-managed or declined checks.
- Record failures honestly rather than declaring completion based on assumptions.
- Stop and report when requirements, architecture, or feasibility assumptions are invalidated.
- Do not make product or architectural decisions without approval.
- Record completion evidence in the issue file.
- Move the issue to Review only after implementation verification succeeds or accepted waivers are recorded.
- Do not mark the issue Done until independent review is complete or an eligible review limitation is explicitly accepted.
- After marking an issue Done, prepare a commit checkpoint and either ask the project owner whether to commit or apply an applicable standing implementation-commit authorization. For an approved validation campaign, wait until every included issue is Done and resolve the campaign's batch checkpoint instead.
- Do not commit without explicit approval.

At the start of Implementation, the owner may give standing, revocable approval for required independent review agents for every implementation issue in the stage. This standing approval is limited to read-only review of completed issue changes and evidence. It does not authorize commits, pushes, external-service access, non-review subagents, or changed review scope. If the scope changes, ask again.

At the start of a Change Cycle Implementation stage, inspect the Implementation Plan and `project-status.md` for a recorded proportionate approval bundle. Honor its covered implementation start, review, and commit actions without repeated approval prompts while every recorded condition remains satisfied. If the records disagree, the issue changes, verification fails or materially changes, unrelated working-tree changes enter the proposed commit, or an excluded action becomes necessary, stop and obtain a revised decision.

The agent may make ordinary implementation decisions that remain within the approved architecture. This includes the proportionate local design improvements authorized by `guidelines/coding-standards.md`, even when they touch multiple related methods or classes inside one approved responsibility. Decisions that alter component responsibilities, dependency directions, public behavior, or project scope require explicit approval.

## Pixel-Art Asset Issues

When an issue creates or materially revises pixel art:

1. Confirm that the Pixel-Art Asset section is complete and approved. If basic art direction is missing, stop and handle it as a Planning Problem instead of improvising or prompting midway through a Ready issue.
2. Use `tools/pixelart/pixelart.cmd` with `-Review` to render exact-grid PNGs and their inspection views in the approved candidate workspace.
3. For a new asset or reopened direction, create three materially different candidates. For a focused correction after owner selection, revise only the selected direction unless the owner reopens the concept decision.
4. Open and inspect every rendered PNG. Apply the actual-size, high-zoom, transparency, and use-specific checks in `guidelines/minecraft-pixel-art.md`.
5. Reject and replace objectively defective candidates before presenting the set. Do not silently choose among viable directions for the owner.
6. Present the passing candidates and obtain owner selection before copying a final runtime asset into the mod repository.
7. Reinspect every material revision and record the final grid, PNG, selection, technical checks, and contextual validation as completion evidence.

An image file existing on disk is not completion evidence. The issue must establish that the exact PNG is technically valid, visually inspected, selected by the owner, and suitable in its actual Minecraft context or has an explicit accepted validation waiver.

## Feedback Strategy

Use the fastest meaningful feedback available for the behavior being implemented.

Possible feedback mechanisms include:

- Compilation
- Static analysis
- Unit tests
- Integration tests
- Development-client launch
- Test-world verification
- Dedicated-server launch
- Multiplayer testing
- Log inspection
- Compatibility testing
- Profiling and performance measurements

Verification must match the risk. A successful build does not verify gameplay behavior, networking, rendering, entity AI, persistence, or mod compatibility.

## Validation Environment Tiers

Use the environment tiers approved in the implementation plan. Record the exact tier used and do not report evidence from one tier as proof of another. In particular:

- `runClient` may prove integrated-server behavior but does not prove a standalone dedicated-server launch.
- `runServer` does not prove client rendering or a packaged modpack installation.
- A packaged clean environment does not prove compatibility with the target modpack or alternate runtime.
- A target modpack check does not by itself prove general compatibility with every modpack.
- External multiplayer is required only when the approved risk or behavior needs separately operated multiplayer evidence.

### Absence Requirements

An acceptance criterion of the form *works without X*, *works when X is missing*, or *does not require X* cannot be verified in an environment that contains X. Such a check does not merely become harder there; it produces a passing result for the wrong reason. The development environment almost always contains X, because having X installed is what makes it a development environment.

Before recording evidence for a check like this:

- Name the component the criterion says must be absent.
- Confirm the environment used genuinely lacks it, rather than merely not using it.
- If it cannot lack it, raise the tier, build a separately configured environment, or record a validation waiver. Do not substitute a same-environment result.

Supporting evidence is still worth recording. Inspecting the built artifact for the attribute that makes the absence case work is legitimate, but it is *inspected* rather than *observed* and does not close the criterion on its own.

Dimension checks are risk-based. For dimension-agnostic code, inspect the relevant code path and use one representative non-Overworld runtime check when runtime confirmation is required. Do not require checks in every dimension unless the implementation or defect is dimension-specific.

### Development Dedicated Server Setup

A freshly created `runServer` environment rejects the development client's login and leaves the owner with no way to obtain test items. Prepare `run/server.properties` before requesting a dedicated-server check, or the request fails for reasons that have nothing to do with the mod.

- `online-mode=false`. The development client authenticates with a placeholder session that Mojang cannot verify, so the default setting refuses it as an invalid session.
- `gamemode=1` with `force-gamemode=true`. Without creative access the owner must obtain every test item by hand, which turns a short check into a scavenger hunt.
- An entry in `ops.json` when the check needs commands.

These values suit a throwaway local development server only. `online-mode=false` disables account verification entirely. Never recommend it for a server reachable from a network, never carry it into public documentation or a packaged environment, and never apply it to a server the owner actually runs.

The development client and development server share one `run/` directory, including the configuration file and the logs. Two consequences follow:

- Their output interleaves in the same log files. Attribute each line by its thread, such as `[Client thread]` against `[Server thread]`, rather than assuming which side produced it.
- They read the same configuration file. A check that depends on the two sides holding different configuration requires editing that file after the server has loaded and before the client starts. Edited at any other moment, both sides load identical configuration and the check silently proves nothing while appearing to pass.

Manual verification must also have a reliable observation path. Before requesting it, identify the authoritative state or event being checked and confirm that normal behavior exposes it reliably. If it does not, implement and verify the issue's approved diagnostic mechanism first. Suitable mechanisms include structured logs, inspect or controlled-state commands, counters, or another narrow diagnostic surface. Potentially noisy or player-visible diagnostics should remain disabled by default unless normal product behavior requires otherwise, and administrative state-changing commands must enforce the approved authorization boundary.

Presentation, session grouping, reset state, evidence handoff, binary `Done` reporting, failure handling, and cleanup for owner-assisted checks are owned by `guidelines/manual-validation.md`. Use the plan's Test now, Defer, or Waive decisions as their standing disposition. If the owner skips a check or accepts that it cannot be run, record the waiver under `guidelines/process-control.md`; do not keep asking unless new evidence makes it release-blocking.

### Agent Diagnostics Toolkit-Assisted Validation

When Project Setup selected the toolkit, follow `guidelines/agent-diagnostics-toolkit.md` before the first dependent card.

- Verify the exact JAR identity and that it is present only in the intended development runtimes.
- Read the pinned version's `AGENTS.md` and confirm the live capabilities, environment, and mod list.
- Keep the shipping mod independent of toolkit classes and inspect release artifacts when the build could leak the dependency.
- Write scenario setup into a bundle so the owner normally runs only reload, one bundle, and the gameplay action.
- Confirm the bundle end record, failures, readiness marks, enabled categories, and starting-state inspections before treating later records as evidence.
- Preserve or hash the bundle and relevant log before a restart rotates or replaces them.
- Use the mod's own narrow diagnostics for internal decisions the toolkit cannot expose.
- Record reusable toolkit improvements in the toolkit feedback artifact without changing the external toolkit project.

Toolkit use does not lower evidence standards. A structured record can still be irrelevant, self-confirming, filtered out, produced by the wrong side, or associated with the wrong test state.

## Generated Artifact Inspection

When a framework generates or rewrites user-visible files such as configuration files, metadata, manifests, or example output, inspect the actual generated artifact. Source strings alone are not sufficient evidence because the framework may add labels, reorder content, escape characters, or preserve stale values.

Check a fresh generation. When existing users or committed defaults may be affected, also check the relevant existing-file migration or preservation path. Record the generated path and observed content in completion evidence.

## Small Follow-Up Path

After the planned behavioral issues are Done, classify each requested follow-up before editing:

- **Editorial-only:** wording, comments, or examples with no parser, API, behavior, migration, or architecture effect. Batch related edits, use targeted checks while wording stabilizes, run one final clean build after the batch, and perform one independent review of the batch.
- **Generated-artifact:** a seemingly textual change whose real result is produced or rewritten by a framework. Inspect the actual fresh output and the existing-file path when relevant.
- **Behavioral or structural:** parser behavior, public API, runtime behavior, data migration, packages/classes, architecture, or compatibility. Use the full issue lifecycle or return to the appropriate earlier stage.

If investigation shows that an editorial request requires framework behavior, API use, migration logic, or structural renaming, stop and explain the expanded scope and cost before proceeding. Do not run a full clean build after every phrasing iteration when targeted checks are adequate; the final stabilized batch still requires a clean verification run.

## Owner-Assisted Validation Campaigns

An approved campaign may postpone only the named owner-assisted runtime cards while a small related issue group is implemented. It does not postpone compilation, automated checks, agent-run checks, observability verification, or independent review.

Before moving an issue to **Awaiting Validation**:

- Complete its implementation and every non-campaign verification check.
- Verify its diagnostics and evidence-retention path.
- Complete a pre-campaign independent implementation review of the code and available evidence and resolve all findings, or record an eligible accepted review limitation.
- Retain a read-only per-issue patch or equivalent change-boundary snapshot and its checksum so later cumulative work does not erase source attribution.
- Record the exact files and behavior attributable to the issue.
- Confirm that no failed or missing result makes later campaign implementation unsafe.

The next named campaign issue may then start even though its predecessor is **Awaiting Validation**, but only when the approved plan expressly permits that dependency relaxation. The mod worktree must be clean when the campaign begins, and every accumulated change must belong to the campaign and remain traceable through the retained boundaries. Do not start work outside the campaign until its commit checkpoint is resolved.

When every included issue reaches **Awaiting Validation**, present and execute the campaign through `guidelines/manual-validation.md`. Assign every card and evidence item to its owning issue. A passing card moves only its owning issue toward Done; campaign completion is not blanket proof for the group.

After the campaign cards pass, submit the newly collected evidence to a focused independent follow-up review before marking issues Done. One reviewer may inspect the complete campaign evidence in one context, but must report whether each included issue's acceptance criteria are independently supported. Any post-review correction receives its own focused verification and follow-up.

When a card fails:

- Stop dependent cards and inspect retained evidence.
- Return the affected issue to **In Progress**.
- Mark later campaign issues **Blocked** when the finding could invalidate their implementation or evidence; otherwise leave their recorded state unchanged.
- Correct, reverify, and independently review the affected scope before resuming the campaign.

After every included issue satisfies its Definition of Done, resolve one batch commit checkpoint for the exact campaign scope. The batch requires explicit authorization or standing authorization that specifically covers the named campaign; per-issue standing authorization does not silently become batch authorization.

## Testing Approach

The verification standards in `guidelines/coding-standards.md` govern every check in this stage, automated and manual alike. Read that section before defining expected results, not after observing them.

The rule most often skipped is that a check whose passing observation would look identical if the feature were absent proves nothing. A check that fails this rule cannot fail at all, so it produces evidence-shaped output that establishes nothing, and it reads as a pass in the completion record. Establish the distinguishing condition first, then observe.

Strict TDD is not required.

Use automated tests when behavior can be isolated meaningfully, such as:

- Calculations
- Selection rules
- State transitions
- Configuration validation
- Data transformations
- Algorithms independent of Minecraft runtime behavior

Use in-game verification when behavior depends on:

- Loader lifecycle events
- Rendering
- Entity AI
- World state
- Networking
- Client/server interaction
- Mixins
- Other installed mods
- Minecraft registries
- Performance under realistic conditions

Define expected results before performing any verification.

## Commit Checkpoints

After each implementation issue, approved vertical slice, approved validation campaign, or approved small-follow-up batch is marked **Done**, resolve a commit checkpoint before starting the next item. A campaign resolves one checkpoint only after every included issue is Done.

Before requesting commit approval:

- Inspect the active mod repository status.
- Summarize the completed code change in repository terms.
- Summarize verification evidence and remaining limitations.
- Confirm that no unrelated files are included.
- Propose a repo-facing commit message.

Commit-message guidance, owned by `guidelines/project-defaults.md` and repeated here because it is needed at the moment the message is written:

<!-- canonical-copy: guidelines/project-defaults.md#commit-messages -->
- Default commit-message style is `repo-facing-no-workflow-issue-references`.
- Commit messages should describe the repository change itself.
- Keep a commit message to one short subject line. Add a body only when the change has rationale a future reader could not recover from the diff, and never to restate what the diff already shows.
- Do not reference workflow issue IDs, internal issue names, stage documents, or process-only context unless the owner explicitly requests that style.
- Assume a future reader has access to the Git repository but not to the workflow artifacts.
- Treat repo-facing commit messages as an invariant default. Do not ask the owner to approve this default during setup; ask only when the owner explicitly requests a different style.
<!-- end-canonical-copy -->

Read these rules rather than recalling them. The two failures below are the ones that actually occur, and a body is what makes the second possible: process context escapes into bodies, not into subject lines.

Good example:

```text
Add client-side left-click vacation toggle
```

Bad, references a process artifact:

```text
Complete issue 3 from implementation-plan.md
```

Bad, restates the diff at length:

```text
Add the arena builder

This adds ArenaBuilder with a build method and a clearInterior method.
The build method places the floor, then the walls, then the ceiling, and
returns the number of blocks changed. The clearInterior method sets the
interior to air and returns the count. Both take a world and a record.
```

The second is a defect even though it references nothing internal. It is the diff written out in prose, and it is the shape a long message takes by default when no one is checking.

If the owner specifically approves the commit, or a bounded standing implementation-commit authorization from `guidelines/collaboration-guidelines.md` applies, create it in the active mod repository only. State when standing authorization is being applied. If neither applies, ask. If the owner declines or defers, record the decision and continue only if the owner approves moving to the next issue with uncommitted changes.

After a clean committed checkpoint, confirm the repository is clean when checked and end with a simple pause-state cue such as: `Ready to continue when you want.`

## Issue Execution Process

1. Select a Ready issue whose blockers are Done, or the next expressly named campaign issue whose only relaxed blocker is an approved **Awaiting Validation** predecessor.
2. Read the issue and all referenced documents.
3. Inspect the relevant existing code.
4. Confirm that the issue remains implementable as written and compare the current code with its Existing-Code Design Fit target when one applies.
5. Change the issue status to **In Progress**.
6. Review its acceptance criteria, verification procedure, manual-observability contract, Complexity Management contract, and authorized local-improvement boundary.
7. Confirm that any declared diagnostic prerequisite is Done; if required observability is missing from the approved plan, stop and handle it as a Planning Problem.
8. When correcting a reproduced defect, establish and record the planned regression check's pre-correction failure or other sensitivity evidence when practical. For every issue, implement the approved ownership boundary and common-use contract followed by the smallest coherent internal change, including approved same-issue diagnostic support.
9. Run compilation and fast automated checks.
10. Correct failures before expanding the implementation.
11. When diagnostics are required, verify their observation path and default and authorization behavior before giving the owner a test card under `guidelines/manual-validation.md`.
12. Perform the required in-game, server, compatibility, or performance verification, or follow an approved validation campaign for its named owner-assisted cards, or record an accepted validation waiver.
13. After owner-performed actions, inspect the planned accessible current and rotated logs directly and collect any other agent-owned evidence.
14. Corroborate diagnostic claims at the independent boundary defined by the plan.
15. Apply proportionate local improvements and route broader structural correction under the Strategic Modification rules in `guidelines/coding-standards.md`.
16. Run all relevant checks again after refactoring.
17. Record completion evidence in the issue.
18. Perform the final implementation self-review and final-diff maintenance check required by `guidelines/coding-standards.md`.
19. Change the issue status to **Review**.
20. Submit the change to an independent review agent. If the owner gave standing approval for required review agents, including a valid recorded proportionate approval bundle, do not ask for repeated per-issue approval unless the review scope changes.
21. Address legitimate review findings.
22. Repeat verification for affected behavior or record approved waiver updates.
23. Mark the issue **Done** only when the Definition of Done is satisfied. When only approved campaign cards remain, mark it **Awaiting Validation** and follow the campaign procedure instead.
24. Prepare the issue or completed-campaign commit checkpoint and determine whether a specific authorization, standing implementation-commit authorization, or valid recorded proportionate approval bundle applies.
25. Create the commit only under that authorization, otherwise request approval or record the approved deferral.
26. Select the next Ready issue only after the commit checkpoint is resolved, except for the next explicitly named issue in an approved validation campaign.

### Executing A Decision Issue

A `Type: Decision` issue produces a settled question, not a change. Steps 8 through 16 above do not apply to it. Instead:

1. Confirm the question is still open and still blocking something.
2. For an **Owner** resolver, present the question with its options, what each costs, and a recommendation. Do not choose.
3. For an **Agent** resolver, gather the evidence, label each finding observed / inspected / inferred, and state only the conclusion that evidence supports.
4. Record the decision, its rationale, and its evidence in the issue.
5. Route any resulting change to an approved artifact through its owning stage before closing.
6. Mark it Done and state which dependent issues are now Ready.

Escalate to the owner when an Agent-resolved question turns out to affect approved scope, requirements, architecture, licensing, or public claims. The resolver field records who was expected to answer, not authority to close a question that grew.

A Decision issue has no commit checkpoint. Do not invent one; the repository change belongs to the dependent implementation issue.

## Handling Discoveries

### Requirement Problem

If expected behavior is missing, ambiguous, or contradictory:

1. Stop the affected implementation.
2. Record the problem.
3. Return to Requirements Definition.
4. Resume only after the requirement is approved.

### Feasibility Problem

If an assumed capability, library, or integration is not viable:

1. Stop the affected implementation.
2. Record the evidence.
3. Return to Feasibility Research.
4. Update dependent documents after the finding is resolved.

### Architecture Problem

If the approved structure cannot support a coherent implementation without avoidable tactical complexity, even though a quick workaround might function:

1. Stop before creating an unofficial workaround.
2. Explain the architectural conflict.
3. Return to Architecture Definition.
4. Update the architecture explicitly after approval.

### Planning Problem

If an issue is too large, incorrectly ordered, or missing dependencies:

1. Stop the issue.
2. Update the Implementation Plan.
3. Split or reorder issues as necessary.
4. Resume with an approved Ready issue.

Minor implementation details that do not alter approved behavior or architectural boundaries do not require returning to an earlier stage.

When a discovery leaves an open question that blocks other planned work, add a `Type: Decision` issue for it and list it as the blocker of the affected issues, rather than carrying it as a loose caveat. This does not replace the routes above: a question that invalidates an approved artifact still returns to the owning stage. The Decision issue records what must be settled and who settles it; the owning stage still approves the change.

## Independent Implementation And Architecture Review

Implementation and review must use separate agent contexts for behavioral and structural issues. Closely related editorial-only follow-ups may be independently reviewed as one approved batch.

Independent review is also required whenever the issue's deliverable is **evidence rather than code**. A compatibility confirmation, an add-on or dependency verification, a lifecycle investigation, or any issue closed largely on inspection produces little or no diff, and that is precisely the case where the implementing agent is most likely to mistake its own reasoning for observation. Do not skip review because there is nothing to read.

For an evidence-only issue the review scope is the evidence chain, not the diff. Give the reviewer:

- The acceptance criterion and what would count as satisfying it.
- Each recorded evidence item with its observed / inspected / inferred label.
- The environment tier each item came from, and whether that environment could have produced the result for the wrong reason.
- The raw material: logs, generated files, command output, artifact inspection.

The reviewer judges whether each label is correct, whether an inferred claim is presented as observed, whether an absence requirement was checked in an environment that could satisfy it at all, and whether the evidence reaches the criterion or merely surrounds it. Downgrading a label is a blocking finding.

The review agent must receive:

- `guidelines/project-defaults.md`
- `guidelines/coding-standards.md`, especially its Complexity Management and Strategic Modification rules
- The relevant requirements
- The relevant architecture sections
- The implementation issue
- The code changes
- Verification evidence
- Accepted validation waivers

The review agent should examine:

- Requirement compliance
- Acceptance criteria coverage
- Architectural compliance
- Whether the approved requirements, architecture, or scope still make sense in light of the implementation, tests, Minecraft 1.12.2 constraints, dependency behavior, and maintainability evidence
- Whether the implementation reveals that the approved architecture has become obsolete, incomplete, too rigid, too vague, or mismatched to the actual problem
- Design-principle concerns such as cohesion, coupling, separation of responsibilities, dependency direction, lifecycle boundaries, testability, data ownership, API surface, and maintainability
- Whether the implementation introduces unnecessary indirection, abstraction, state, global behavior, lifecycle coupling, or future-facing structure
- Whether a simpler structure would satisfy the approved behavior with lower maintenance risk
- The strategic-modification assessment required by `guidelines/coding-standards.md`, supported by concrete evidence from the changed area
- Correctness and regressions
- For a defect correction, whether the retained regression check reaches the original failure boundary, would fail if the defect returned, and remains at the lowest stable meaningful level rather than duplicating implementation details
- Client/server separation
- Error handling
- Compatibility concerns
- Performance risks
- Unnecessary complexity
- Missing or inadequate verification
- Whether accepted validation waivers affect public claims or release safety
- Whether each completion-evidence label is accurate, and whether any acceptance criterion rests on an inferred claim without an accepted waiver
- Unrelated changes

For every behavioral or structural issue, the reviewer must also provide a short evidence-based **Complexity argument**. This is an argument about the actual change, not a design-principle checklist. It must:

- Identify material complexity introduced and removed.
- Apply the Strategic Modification assessment defined by `guidelines/coding-standards.md` when existing production code changed.
- Assess whether important modules present a simple common interface while hiding implementation knowledge and special cases.
- Identify the authoritative owner of rules, formulas, persistence, synchronization, lifecycle ordering, or compatibility policy, and any duplicated or leaked ownership.
- Examine the knowledge and sequencing required from callers, including temporal coupling.
- Examine whether adjacent layers provide distinct abstractions or merely pass calls through.
- Identify mixed general mechanisms and special policies when they have different reasons to change.
- Treat difficult names, hard-to-describe responsibilities, and comments that explain mechanics instead of contracts as possible abstraction evidence.
- Name any Minecraft 1.12.2, Forge, loader, or dependency constraint that requires otherwise undesirable complexity, and assess whether that complexity is localized and hidden.
- Conclude that the change decreased, left unchanged, or increased complexity. An increase is acceptable only when the approved behavior or a concrete platform constraint requires it and the implementation contains it as well as practical.

The argument must cite concrete classes, methods, interfaces, data owners, or dependency boundaries. Statements such as `follows SOLID`, `looks clean`, or `uses good abstractions` are not evidence. The reviewer need not mention a red flag that is genuinely irrelevant, but must explain enough of the change to support the conclusion. For an editorial-only or evidence-only issue with no structural effect, record that the argument is not structurally applicable and why.

The reviewer should separate:

- **Blocking findings:** defects, requirement failures, unsafe architecture drift, invalid assumptions, missing verification, or changes that would make the issue unsafe to mark Done.
- **Architecture/process findings:** evidence that an approved requirement, scope boundary, implementation plan, or architecture decision should be revisited before continuing.
- **Improvement suggestions:** nonblocking design improvements that may reduce complexity or future maintenance cost but are not required for the current issue.

The reviewer should report findings before proposing broad improvements. Architectural suggestions should cite concrete evidence from the implementation, tests, dependency behavior, Minecraft 1.12.2 constraints, or maintainability risk. The reviewer must not expand the issue scope or judge the implementation according to undocumented preferences.

If the reviewer finds that an approved requirement, architecture decision, or scope boundary is flawed, treat that as a process finding rather than forcing code to comply blindly. Evaluate it against the approved evidence and route legitimate artifact problems through the backward-transition process.

A clean review context improves independence, but does not make the review automatically correct. Review findings must be evaluated against the approved requirements, architecture, evidence, and accepted validation waivers.

### Independent Review Availability

Do not interpret a busy agent slot or a temporarily delayed reviewer as lack of review capability. Wait or resume later when a separate context is expected to become available.

When the active environment genuinely cannot provide a separate agent context, state that limitation before the issue reaches Review. Self-review, additional tests, and owner observation may reduce risk, but they are not independent review and must not be recorded as one.

The normal response is to leave the issue blocked at its review checkpoint until an independent agent or qualified human reviewer is available. The owner may explicitly accept a review limitation only when the issue is local, low-risk, reversible, has strong automated or direct runtime evidence, and does not deliver evidence as its primary output. Do not offer this exception for changes involving public APIs, persistent data or migration, networking or synchronization, logical-server authority, Mixins or coremods, dependency or licensing conclusions, release packaging, security or permissions, destructive behavior, or another boundary where a second reasoning context materially protects users.

Before requesting an eligible exception, present:

- What prevented independent review and what availability checks were made.
- The exact issue and diff scope.
- The substitute self-review, automated checks, runtime evidence, and artifact inspection completed.
- The residual risk that independence would have addressed.
- The public claims, later validation, or release decision constrained by the limitation.

Record an accepted exception under **Accepted Review Limitations** using:

```text
Accepted review limitation: <issue and scope> was not independently reviewed because <environment limitation>; <substitute evidence and residual risk> were explicitly accepted by the owner.
```

An accepted review limitation satisfies only the review checkpoint for that exact eligible issue. It does not authorize a commit, weaken validation requirements, apply to later issues, or turn self-review into independent evidence. It also invalidates any standing commit authorization whose conditions require completed independent review; that commit needs a separate explicit decision. If later evidence raises the risk or expands the scope, the exception is invalid and independent review becomes blocking again.

## Completion Evidence

### Evidence Labels

Every recorded evidence claim carries exactly one label, written in the line itself:

- **observed:** the behavior was seen happening in a running environment. A log line produced by the run, a value read in-game, a command's actual output.
- **inspected:** a concrete artifact was read directly and shows the state, but the behavior was not exercised. A generated config file, a jar's contents, bytecode, a test report, source of a dependency.
- **inferred:** the conclusion follows from reasoning about code, documentation, or dependency behavior, without either seeing the behavior or reading an artifact that records it.

Rules:

- Label each claim, not each section. One section commonly mixes labels.
- When a claim rests on several steps, use the weakest label among them. An observation that only becomes relevant through a reasoning step is *inferred*.
- An **inferred** claim never satisfies an acceptance criterion by itself. Either upgrade it to observed or inspected, or record a validation waiver and have the owner accept the limitation explicitly.
- Never restate an inferred claim in later artifacts, summaries, or public copy as though it were observed. This is the specific failure the labels exist to prevent.

Examples:

```text
- Result (observed): server log shows "Applied 3 spell overrides" at preInit; in-game mana cost read 240.
- Result (inspected): javap on the shipping jar shows acceptableRemoteVersions = "*" in the @Mod annotation.
- Result (inferred): Forge installs the always-compatible checker for that value, so a mod-less client would be admitted. Not observed; see WAIVER-001.
```

Record evidence directly in the issue file:

```markdown
## Completion Evidence

Every result line ends with one label: (observed), (inspected), or (inferred).

### Automated Checks

- Command:
- Result (observed | inspected | inferred):

### In-Game Verification

- Environment tier:
- Procedure:
- Expected result:
- Actual result (observed | inspected | inferred):

### Diagnostic Support

- Authoritative state or event observed:
- Mechanism and setup:
- Evidence source or path inspected:
- Corroborating evidence:
- Default state:
- Authorization behavior, when applicable:
- Result (observed | inspected | inferred):

### Dedicated Server

- Procedure:
- Result (observed | inspected | inferred):

### Compatibility or Performance

- Procedure:
- Result (observed | inspected | inferred):

### Accepted Validation Waivers

- Accepted limitation: <Validation name> was not performed by owner decision.

### Defect Regression Protection

- Original defect and detection boundary:
- Retained check or scenario path:
- Pre-correction failure or sensitivity evidence (observed | inspected | inferred):
- Post-correction result (observed | inspected | inferred):
- Automation limitation and runtime fallback, when applicable:

### Independent Implementation And Architecture Review

- Reviewer:
- Blocking findings:
- Architecture/process findings:
- Improvement suggestions:
- Complexity argument:
  - Complexity introduced:
  - Complexity removed:
  - Deep-module and information-hiding assessment:
  - Strategic modification assessment: Coherent fit / Justified tactical compromise / Not applicable, with evidence
  - Red flags found or accepted:
  - Simpler alternative, when applicable:
  - Local improvements completed and cleanup deferred as unrelated:
  - Conclusion: Decreased / Unchanged / Increased, with justification
- Resolutions:

### Accepted Review Limitations

- Limitation, eligibility basis, substitute checks, residual risk, and owner acceptance:

### Remaining Limitations

- None
```

Omit verification categories that genuinely do not apply. Include accepted validation waivers whenever a normally relevant check was skipped by owner decision or ownership boundary. Do not omit a label because the answer is uncomfortable; an honest *inferred* is useful evidence, a mislabelled *observed* is not.

Omit **Defect Regression Protection** when the issue does not correct a reproduced defect. For a defect correction, retain the check or repeatable scenario after the issue is complete; a one-time reproduction that is discarded does not protect against regression.

Omit **Diagnostic Support** when stable normal behavior was sufficient for all manual checks. When it applies, record enough evidence to show that the diagnostic exposed the intended authoritative state and did not remain unintentionally enabled or accessible beyond its approved authorization boundary.

## Issue Completion Criteria

An issue is complete when:

- Its implementation satisfies the acceptance criteria.
- Every included pixel-art asset satisfies `guidelines/minecraft-pixel-art.md`, has an owner-selected direction, and records agent visual inspection plus required contextual validation or an accepted waiver.
- Relevant automated checks pass.
- Required in-game verification passes or has an accepted waiver.
- Required manual observability is implemented in the issue or a completed prerequisite, and its default and authorization behavior are verified where applicable.
- Client, dedicated-server, multiplayer, compatibility, and performance checks pass where assigned or have accepted waivers.
- The implementation follows the approved architecture.
- No unrelated behavior was introduced.
- Completion evidence is recorded, and every evidence claim carries an accurate observed / inspected / inferred label.
- No acceptance criterion rests on an inferred claim without an accepted validation waiver.
- Every corrected defect has retained regression protection and sensitivity evidence, or an explicit explanation of why a repeatable runtime scenario is the lowest reliable level.
- Independent review is complete, including for an issue whose deliverable is evidence rather than code, or an eligible review limitation is explicitly accepted and recorded.
- Independent review contains an evidence-based complexity argument for every behavioral or structural change.
- For changed existing production code, independent review records the strategic-modification assessment required by `guidelines/coding-standards.md`.
- Legitimate review findings are resolved.
- Any remaining limitations are explicit and approved.
- The issue status is **Done**.
- The commit checkpoint has been completed or explicitly deferred by the project owner.

## Stage Completion Criteria

The Implementation stage is complete when:

- Every issue required for the release is Done.
- Every MUST requirement is implemented.
- Included SHOULD and MAY requirements are implemented as planned.
- All required automated checks pass.
- Required client, server, multiplayer, compatibility, and performance verification is complete or has accepted waivers.
- All implementation validation questions are resolved or recorded as accepted limitations.
- No release-blocking defects remain.
- The code matches the approved architecture.
- Approved documents reflect any accepted changes made during implementation.
- All commit checkpoints are completed or explicitly deferred.
- No required issue remains Backlog, Ready, In Progress, Review, or Blocked.
- The project owner approves the implemented mod for Release Presentation.

Completion does not include preparing user-facing documentation, creating release assets, building the final distributable release, or publishing to a distribution platform.

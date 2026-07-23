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

## Objectives

For each implementation issue:

- Implement the defined behavior
- Follow the approved architecture
- Satisfy the acceptance criteria
- Run appropriate automated checks
- Verify behavior inside Minecraft where necessary
- Check client and dedicated-server behavior where relevant
- Validate technical uncertainties assigned to the issue
- Record completion evidence
- Record accepted validation waivers when the owner skips or owns a check
- Obtain an independent review
- Correct legitimate review findings
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
- Confirm that all blocking issues are Done before starting.
- Read the issue and its referenced requirements and architecture sections.
- Inspect the existing codebase before making changes.
- Inspect approved dependency source references when the issue or architecture depends on them.
- Preserve existing project conventions unless an approved decision requires otherwise.
- Implement the smallest coherent change that satisfies the issue.
- Keep the change limited to the issue's scope.
- Use existing libraries and architectural components as documented.
- Avoid duplicating functionality already present in the project or its dependencies.
- Treat dependency source checkouts under `workspace/dependencies/` as read-only references. Do not modify them or copy code from them unless the owner explicitly approves that work and licensing has been checked.
- Run fast feedback checks throughout implementation.
- Use test-first development for isolated logic when it provides clear value.
- Do not force TDD onto behavior that can only be meaningfully verified inside Minecraft.
- Perform the verification defined by the issue.
- Before asking the owner to perform a manual check, confirm that the issue's planned observability mechanism is implemented and usable. Do not substitute indirect inference when the plan requires authoritative logs, commands, counters, or equivalent diagnostics.
- Keep diagnostic work within the approved issue or its declared prerequisite. If required observability is missing from the plan, treat it as a Planning Problem rather than silently expanding the issue or sending an unreliable test recipe.
- Treat compilation as necessary but not sufficient evidence that behavior works.
- Check dedicated-server safety whenever client-only code is involved and the check is assigned or practical.
- Record accepted validation waivers instead of repeatedly pushing owner-managed or declined checks.
- Record failures honestly rather than declaring completion based on assumptions.
- Stop and report when requirements, architecture, or feasibility assumptions are invalidated.
- Do not make product or architectural decisions without approval.
- Record completion evidence in the issue file.
- Move the issue to Review only after implementation verification succeeds or accepted waivers are recorded.
- Do not mark the issue Done until independent review is complete.
- After marking an issue Done, prepare a commit checkpoint and either ask the project owner whether to commit or apply an applicable standing implementation-commit authorization.
- Do not commit without explicit approval.

At the start of Implementation, the owner may give standing, revocable approval for required independent review agents for every implementation issue in the stage. This standing approval is limited to read-only review of completed issue changes and evidence. It does not authorize commits, pushes, external-service access, non-review subagents, or changed review scope. If the scope changes, ask again.

The agent may make ordinary method-level implementation decisions that remain within the approved architecture. Decisions that alter component responsibilities, dependency directions, public behavior, or project scope require explicit approval.

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

Dimension checks are risk-based. For dimension-agnostic code, inspect the relevant code path and use one representative non-Overworld runtime check when runtime confirmation is required. Do not require checks in every dimension unless the implementation or defect is dimension-specific.

Manual verification must also have a reliable observation path. Before requesting it, identify the authoritative state or event being checked and confirm that normal behavior exposes it reliably. If it does not, implement and verify the issue's approved diagnostic mechanism first. Suitable mechanisms include structured logs, inspect or controlled-state commands, counters, or another narrow diagnostic surface. Potentially noisy or player-visible diagnostics should remain disabled by default unless normal product behavior requires otherwise, and administrative state-changing commands must enforce the approved authorization boundary.

If the owner skips a validation check, marks it owner-managed, or accepts that it cannot be run in the current environment, record it using the validation waiver format in `guidelines/process-control.md` and continue. Do not keep asking for the same validation unless new evidence makes it release-blocking.

Use the plan's Test now, Defer, or Waive decisions as the standing disposition for owner-performed checks. Consolidate any newly discovered owner checks into the next relevant validation packet instead of asking about them one at a time.

When manual gameplay validation by the owner is useful, provide a short runnable validation recipe only after its required observability is available. Include relevant config state, exact diagnostic and setup commands, how to enable and later disable any optional logging, the authoritative values or events to inspect, expected results, and any important scenario that is not practical to validate in normal vanilla gameplay.

Before the owner starts a shared game, server, or modpack session, consolidate all currently known checks for that runtime into one validation packet:

- Map every planned check to its acceptance criterion and authoritative observation.
- Group checks by configuration state and put the full configuration for each state first.
- Minimize full restarts and state clearly where each unavoidable restart occurs.
- Verify commands, selectors, registry identifiers, and entity names specifically for Minecraft 1.12.2; do not rely on identifiers from newer versions.
- Choose fixtures whose actual registry type and attack behavior match the check. Account for spawn-replacement mods, randomized variants, custom AI, and attribute-scaling mods before treating visual health or damage as evidence.
- Include safety setup, cleanup commands, diagnostic log strings, and the exact evidence the owner should return.
- Include bounded repeated-event or churn checks when an acceptance criterion requires them; do not discover them only during final independent review.

If a result invalidates a fixture or reveals a new necessary check, revise the packet and explain the change. Do not continue an avoidable sequence of ad hoc restarts merely because testing has already begun.

## Generated Artifact Inspection

When a framework generates or rewrites user-visible files such as configuration files, metadata, manifests, or example output, inspect the actual generated artifact. Source strings alone are not sufficient evidence because the framework may add labels, reorder content, escape characters, or preserve stale values.

Check a fresh generation. When existing users or committed defaults may be affected, also check the relevant existing-file migration or preservation path. Record the generated path and observed content in completion evidence.

## Small Follow-Up Path

After the planned behavioral issues are Done, classify each requested follow-up before editing:

- **Editorial-only:** wording, comments, or examples with no parser, API, behavior, migration, or architecture effect. Batch related edits, use targeted checks while wording stabilizes, run one final clean build after the batch, and perform one independent review of the batch.
- **Generated-artifact:** a seemingly textual change whose real result is produced or rewritten by a framework. Inspect the actual fresh output and the existing-file path when relevant.
- **Behavioral or structural:** parser behavior, public API, runtime behavior, data migration, packages/classes, architecture, or compatibility. Use the full issue lifecycle or return to the appropriate earlier stage.

If investigation shows that an editorial request requires framework behavior, API use, migration logic, or structural renaming, stop and explain the expanded scope and cost before proceeding. Do not run a full clean build after every phrasing iteration when targeted checks are adequate; the final stabilized batch still requires a clean verification run.

## Testing Approach

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

After each implementation issue, approved vertical slice, or approved small-follow-up batch is marked **Done**, resolve a commit checkpoint before starting the next item.

Before requesting commit approval:

- Inspect the active mod repository status.
- Summarize the completed code change in repository terms.
- Summarize verification evidence and remaining limitations.
- Confirm that no unrelated files are included.
- Propose a repo-facing commit message.

Commit-message guidance:

- Describe the actual code or asset change.
- Do not reference internal workflow issue IDs, issue filenames, stage documents, or process-only context unless the owner explicitly requests that style.
- Do not use messages that require the reader to know the workflow documentation.
- Assume a future reader has access to the Git repository but not the process artifacts.

Good example:

```text
Add client-side left-click vacation toggle
```

Bad example:

```text
Complete issue 3 from implementation-plan.md
```

If the owner specifically approves the commit, or a bounded standing implementation-commit authorization from `guidelines/collaboration-guidelines.md` applies, create it in the active mod repository only. State when standing authorization is being applied. If neither applies, ask. If the owner declines or defers, record the decision and continue only if the owner approves moving to the next issue with uncommitted changes.

After a clean committed checkpoint, confirm the repository is clean when checked and end with a simple pause-state cue such as: `Ready to continue when you want.`

## Issue Execution Process

1. Select a Ready issue whose blockers are Done.
2. Read the issue and all referenced documents.
3. Inspect the relevant existing code.
4. Confirm that the issue remains implementable as written.
5. Change the issue status to **In Progress**.
6. Review its acceptance criteria, verification procedure, and manual-observability contract.
7. Confirm that any declared diagnostic prerequisite is Done; if required observability is missing from the approved plan, stop and handle it as a Planning Problem.
8. Implement the smallest coherent change, including approved same-issue diagnostic support.
9. Run compilation and fast automated checks.
10. Correct failures before expanding the implementation.
11. When diagnostics are required, verify their observation path and default and authorization behavior before giving the owner a manual validation recipe.
12. Perform the required in-game, server, compatibility, or performance verification, or record an accepted validation waiver.
13. Refactor only where it improves the implemented behavior without expanding scope.
14. Run all relevant checks again after refactoring.
15. Record completion evidence in the issue.
16. Perform a final implementation self-review.
17. Change the issue status to **Review**.
18. Submit the change to an independent review agent. If the owner gave standing approval for required review agents, do not ask for repeated per-issue approval unless the review scope changes.
19. Address legitimate review findings.
20. Repeat verification for affected behavior or record approved waiver updates.
21. Mark the issue **Done** only when the Definition of Done is satisfied.
22. Prepare the commit checkpoint and determine whether a specific or standing authorization applies.
23. Create the commit only under that authorization, otherwise request approval or record the approved deferral.
24. Select the next Ready issue only after the commit checkpoint is resolved.

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

If the approved structure cannot reasonably support the implementation:

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

## Independent Implementation And Architecture Review

Implementation and review must use separate agent contexts for behavioral and structural issues. Closely related editorial-only follow-ups may be independently reviewed as one approved batch.

The review agent must receive:

- `guidelines/project-defaults.md`
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
- Correctness and regressions
- Client/server separation
- Error handling
- Compatibility concerns
- Performance risks
- Unnecessary complexity
- Missing or inadequate verification
- Whether accepted validation waivers affect public claims or release safety
- Unrelated changes

The reviewer should separate:

- **Blocking findings:** defects, requirement failures, unsafe architecture drift, invalid assumptions, missing verification, or changes that would make the issue unsafe to mark Done.
- **Architecture/process findings:** evidence that an approved requirement, scope boundary, implementation plan, or architecture decision should be revisited before continuing.
- **Improvement suggestions:** nonblocking design improvements that may reduce complexity or future maintenance cost but are not required for the current issue.

The reviewer should report findings before proposing broad improvements. Architectural suggestions should cite concrete evidence from the implementation, tests, dependency behavior, Minecraft 1.12.2 constraints, or maintainability risk. The reviewer must not expand the issue scope or judge the implementation according to undocumented preferences.

If the reviewer finds that an approved requirement, architecture decision, or scope boundary is flawed, treat that as a process finding rather than forcing code to comply blindly. Evaluate it against the approved evidence and route legitimate artifact problems through the backward-transition process.

A clean review context improves independence, but does not make the review automatically correct. Review findings must be evaluated against the approved requirements, architecture, evidence, and accepted validation waivers.

## Completion Evidence

Record evidence directly in the issue file:

```markdown
## Completion Evidence

### Automated Checks

- Command:
- Result:

### In-Game Verification

- Environment:
- Procedure:
- Expected result:
- Observed result:

### Diagnostic Support

- Authoritative state or event observed:
- Mechanism and setup:
- Default state:
- Authorization behavior, when applicable:
- Result:

### Dedicated Server

- Procedure:
- Result:

### Compatibility or Performance

- Procedure:
- Result:

### Accepted Validation Waivers

- Accepted limitation: <Validation name> was not performed by owner decision.

### Independent Implementation And Architecture Review

- Reviewer:
- Blocking findings:
- Architecture/process findings:
- Improvement suggestions:
- Resolutions:

### Remaining Limitations

- None
```

Omit verification categories that genuinely do not apply. Include accepted validation waivers whenever a normally relevant check was skipped by owner decision or ownership boundary.

Omit **Diagnostic Support** when stable normal behavior was sufficient for all manual checks. When it applies, record enough evidence to show that the diagnostic exposed the intended authoritative state and did not remain unintentionally enabled or accessible beyond its approved authorization boundary.

## Issue Completion Criteria

An issue is complete when:

- Its implementation satisfies the acceptance criteria.
- Relevant automated checks pass.
- Required in-game verification passes or has an accepted waiver.
- Required manual observability is implemented in the issue or a completed prerequisite, and its default and authorization behavior are verified where applicable.
- Client, dedicated-server, multiplayer, compatibility, and performance checks pass where assigned or have accepted waivers.
- The implementation follows the approved architecture.
- No unrelated behavior was introduced.
- Completion evidence is recorded.
- Independent review is complete.
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

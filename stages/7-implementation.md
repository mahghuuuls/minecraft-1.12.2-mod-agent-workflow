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
- Ask the project owner to approve a commit checkpoint after the issue is Done

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
- Independent code review
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
- Treat compilation as necessary but not sufficient evidence that behavior works.
- Check dedicated-server safety whenever client-only code is involved and the check is assigned or practical.
- Record accepted validation waivers instead of repeatedly pushing owner-managed or declined checks.
- Record failures honestly rather than declaring completion based on assumptions.
- Stop and report when requirements, architecture, or feasibility assumptions are invalidated.
- Do not make product or architectural decisions without approval.
- Record completion evidence in the issue file.
- Move the issue to Review only after implementation verification succeeds or accepted waivers are recorded.
- Do not mark the issue Done until independent review is complete.
- After marking an issue Done, prepare a commit checkpoint and ask the project owner whether to commit before moving to the next issue.
- Do not commit without explicit approval.

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

If the owner skips a validation check, marks it owner-managed, or accepts that it cannot be run in the current environment, record it using the validation waiver format in `guidelines/process-control.md` and continue. Do not keep asking for the same validation unless new evidence makes it release-blocking.

When manual gameplay validation by the owner is useful, provide a short runnable validation recipe after each runnable vertical slice. Include relevant config state, exact commands or setup steps when available, expected results, and any important scenario that is not practical to validate in normal vanilla gameplay.

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

After each implementation issue or approved vertical slice is marked **Done**, pause and ask the project owner whether to create a commit before starting the next issue.

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

If the owner approves the commit, create it in the active mod repository only. If the owner declines or defers, record the decision and continue only if the owner approves moving to the next issue with uncommitted changes.

After a clean committed checkpoint, confirm the repository is clean when checked and end with a simple pause-state cue such as: `Ready to continue when you want.`

## Issue Execution Process

1. Select a Ready issue whose blockers are Done.
2. Read the issue and all referenced documents.
3. Inspect the relevant existing code.
4. Confirm that the issue remains implementable as written.
5. Change the issue status to **In Progress**.
6. Review its acceptance criteria and verification procedure.
7. Implement the smallest coherent change.
8. Run compilation and fast automated checks.
9. Correct failures before expanding the implementation.
10. Perform the required in-game, server, compatibility, or performance verification, or record an accepted validation waiver.
11. Refactor only where it improves the implemented behavior without expanding scope.
12. Run all relevant checks again after refactoring.
13. Record completion evidence in the issue.
14. Perform a final implementation self-review.
15. Change the issue status to **Review**.
16. Submit the change to an independent review agent.
17. Address legitimate review findings.
18. Repeat verification for affected behavior or record approved waiver updates.
19. Mark the issue **Done** only when the Definition of Done is satisfied.
20. Prepare the commit checkpoint and request owner approval to commit.
21. Create the commit only if approved, or record the approved deferral.
22. Select the next Ready issue only after the commit checkpoint is resolved.

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

## Independent Review

Implementation and review must use separate agent contexts.

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
- Correctness and regressions
- Client/server separation
- Error handling
- Compatibility concerns
- Performance risks
- Unnecessary complexity
- Missing or inadequate verification
- Whether accepted validation waivers affect public claims or release safety
- Unrelated changes

The reviewer should report findings before proposing broad improvements. The reviewer must not expand the issue scope or judge the implementation according to undocumented preferences.

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

### Dedicated Server

- Procedure:
- Result:

### Compatibility or Performance

- Procedure:
- Result:

### Accepted Validation Waivers

- Accepted limitation: <Validation name> was not performed by owner decision.

### Independent Review

- Reviewer:
- Findings:
- Resolutions:

### Remaining Limitations

- None
```

Omit verification categories that genuinely do not apply. Include accepted validation waivers whenever a normally relevant check was skipped by owner decision or ownership boundary.

## Issue Completion Criteria

An issue is complete when:

- Its implementation satisfies the acceptance criteria.
- Relevant automated checks pass.
- Required in-game verification passes or has an accepted waiver.
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

# Implementation Plan

## Purpose

Convert the approved requirements and architecture into small, ordered, and verifiable implementation issues that an agent can execute with limited additional context.

## Main Question

> In what small, verifiable increments should the mod be built?

## Required Input

- `workspace/documentation/requirements.md`
- `workspace/documentation/architecture.md`
- The approved repository baseline identified by the active workflow
- The active project under `workspace/project/<project_directory_name>/`
- The active workflow's `<artifact-root>`
- `guidelines/manual-validation.md` when owner-assisted runtime checks are planned
- `guidelines/agent-diagnostics-toolkit.md` when Project Setup selected the toolkit

## Objectives

Establish:

- The implementation strategy
- Thin vertical slices of working behavior
- Dependencies and blocking relationships
- The order in which issues should be completed
- Which requirements each issue satisfies
- Which architectural components each issue affects
- How each issue will be verified
- Which validation environment tier each check uses, what it proves, and what it does not prove
- Whether each owner-performed manual validation is scheduled now, deferred, or waived
- What authoritative state or event each manual runtime check must observe, and how it will be observed
- Who collects each evidence source, including which accessible logs the agent will inspect directly and which observations require the owner
- Which selected manual checks will use Agent Diagnostics Toolkit bundles, records, or inspections
- Which technical risks should be addressed early
- What constitutes completion for each issue
- Which optional requirements are deferred

## In Scope

- Breaking requirements into implementation issues
- Organizing work into vertical slices
- Identifying necessary foundational work
- Defining issue dependencies
- Creating an acyclic dependency graph
- Prioritizing risky or uncertain work
- Defining acceptance criteria for each issue
- Defining verification procedures
- Defining a risk-based validation environment plan
- Consolidating owner-performed manual validation decisions before implementation
- Designing the minimum observability needed for reliable manual runtime verification
- Planning development-runtime-only toolkit placement and repeatable test bundles when selected
- Linking issues to requirements and architecture
- Identifying likely code areas affected
- Establishing issue statuses and workflow
- Establishing a Definition of Done

## Out of Scope

Do not attempt to:

- Write production code
- Implement tests
- Redesign approved requirements or architecture
- Add unapproved features
- Resolve implementation discoveries that have not occurred
- Specify every method-level coding action
- Create release documentation or assets
- Plan maintenance after release
- Produce arbitrary time estimates or deadlines

If planning reveals a defect in the requirements or architecture, return the issue to the appropriate stage instead of silently compensating for it in the plan.

## Desired AI Behavior

Act as an implementation planner.

- Derive implementation issues from the approved requirements and architecture.
- Prefer small vertical slices that produce integrated, observable behavior.
- Create the smallest useful end-to-end slice early.
- Avoid organizing the entire plan into horizontal technical layers.
- Allow foundational issues only when they genuinely unblock vertical slices.
- Keep foundational work as small and specific as possible.
- Give every issue a clear objective and completion boundary.
- Make dependencies explicit.
- Ensure the dependency graph contains no cycles.
- Schedule high-risk assumptions and implementation validations early.
- Define verification before implementation begins.
- For every manual runtime check, identify the authoritative state or event being tested and whether normal behavior exposes it reliably.
- Identify the evidence source, its accessible path or surface, retention or rotation behavior when relevant, and whether the agent or owner collects it.
- When the toolkit is selected, plan bundle names, setup and teardown responsibilities, narrow record categories, readiness marks, runtime placement, and retained evidence before asking the owner to test.
- Assign every runtime check to the lowest validation tier that supplies meaningful evidence, and state any important limitation of that tier.
- When normal behavior is insufficient, include the minimum diagnostic mechanism in the same vertical slice or add an explicit prerequisite issue that delivers it first.
- Prefer same-issue diagnostics; use a prerequisite when the mechanism is shared by multiple slices or substantial enough to require separate implementation and review.
- Do not add diagnostics mechanically when stable external behavior already proves the result.
- Make noisy or player-visible diagnostics disabled by default unless normal product behavior requires otherwise, and apply approved authorization boundaries to administrative state-changing commands.
- Do not treat a diagnostic as proof merely because it reports its own internal result. Plan corroboration at an independent boundary when a faulty calculation or event path could otherwise validate itself.
- Select verification appropriate to the behavior instead of requiring strict TDD.
- Use automated tests for isolated logic where practical.
- Use Minecraft client, dedicated-server, multiplayer, compatibility, or performance verification where required.
- Do not require every environment mechanically. Use code paths and project risks to decide whether a representative non-Overworld check, packaged environment, modpack, or multiplayer check is necessary.
- Plan a dedicated-server check by default for any mod that loads on a server. Side-safety failures, such as a client-only class reaching server code, are invisible in `runClient` and fatal on a server, so this is not a risk-selected extra. Omit it only for a mod that never loads server-side, and record the reason.
- Ensure each issue is understandable to an agent starting with a fresh context.
- Avoid repeating entire project documents inside every issue.
- Reference requirements and architectural decisions by stable identifiers.
- Avoid speculative tasks for hypothetical future needs.
- Use focused questions for branching prioritization or scope decisions and compact decision packets for related plan defaults or issue-grouping choices.
- Do not ask questions that approved documents, code inspection, or dependency research can answer. Follow Investigate Before Asking in `guidelines/process-control.md`.
- Identify contradictions or missing information rather than guessing.
- Generate complete draft artifacts, present them for approval, and revise them as required.

## Vertical Slices

A vertical slice should implement a small piece of behavior across every necessary part of the system.

For example, a slice might include:

- Relevant configuration
- Core behavior
- Loader integration
- Client/server handling
- Persistence or networking
- Verification
- Any diagnostic support required to make that verification reliable

A vertical slice should produce something observable and verifiable, even if the feature is not yet complete.

Do not split work entirely into layers such as:

1. Create every data class.
2. Create every loader event handler.
3. Create every network message.
4. Connect everything at the end.

Some horizontal or foundational work may still be necessary, including:

- Shared registration infrastructure
- Test infrastructure
- Required dependency setup

Such work must have a concrete consumer and must not become speculative framework construction.

## Issue Size

An issue should:

- Have one coherent objective.
- Produce an observable result or unblock a specific slice.
- Be small enough for a focused implementation session.
- Be independently reviewable.
- Have explicit acceptance criteria.
- Have a defined verification procedure.
- Include or depend on the observability required by any manual verification procedure.
- Avoid combining unrelated requirements.

If an issue has multiple unrelated outcomes or an extensive verification procedure, split it.

## Decision Issues

Most issues deliver behavior. Some deliver a settled question.

Use `Type: Decision` for an open question that must be resolved before dependent work can proceed and that the stage normally owning it cannot answer yet. Its deliverable is a recorded decision, not code.

Create one when:

- Implementation evidence is needed before the question can be answered honestly.
- A discovery invalidates an assumption and dependent slices must wait for its replacement.
- An owner choice about scope, risk, public wording, or ownership blocks a planned slice.

Do not create one to postpone a decision the current stage already owns. A Decision issue is not a way to leave Requirements Definition or Architecture Definition incomplete and settle it later. If the owning stage can answer the question now, answer it there.

### Resolver

Every Decision issue names who closes it:

- **Owner:** only the project owner can settle it. This covers scope, acceptable risk, licensing, public claims, ownership boundaries, and preference. The agent still prepares the question, presenting the options, what each costs, and a recommendation. It does not choose.
- **Agent:** the agent can settle it from research, source inspection, an experiment, or a dependency's observed behavior, and records the finding with its evidence label.

An Agent decision that turns out to change approved scope, requirements, architecture, licensing, or public claims stops being an Agent decision. Escalate it and route the artifact change through the backward-transition process.

### Placement In The Graph

A Decision issue is an ordinary node. It has an identifier, a status, and `Blocked By`, and other issues may list it as their blocker. That is the purpose of the type: an unanswered question that blocks work should appear as a blocker rather than as a caveat in a separate list.

List it in the Issue Summary table with every other issue. Do not maintain a parallel decision register that restates it.

### Decision Completion

A Decision issue is Done when:

- The question is answered, or explicitly recorded as unanswerable with its consequence stated.
- The decision, its rationale, and its evidence are recorded in the issue.
- Every canonical artifact the decision changes has been updated through its owning stage.
- Dependent issues are unblocked or re-scoped.

A Decision issue has no commit checkpoint of its own because it produces no repository change. When it causes one, that change belongs to the dependent implementation issue.

An Agent-resolved Decision issue follows the evidence-only review rule in `stages/7-implementation.md`, since its deliverable is evidence. An Owner-resolved one needs no independent review; the owner's answer is the resolution.

## Issue Statuses

Use these statuses:

- **Backlog:** Identified but not ready to implement.
- **Ready:** Fully defined and all blockers are resolved.
- **In Progress:** Currently being implemented.
- **Awaiting Validation:** Implementation, non-campaign verification, and pre-campaign independent review are complete; only the issue's approved owner-assisted campaign and focused evidence follow-up remain.
- **Review:** Implementation is complete and awaiting independent review.
- **Blocked:** Cannot proceed because a dependency or decision is unresolved.
- **Done:** Acceptance criteria, verification, and review are complete.
- **Deferred:** Intentionally excluded from the current release.

Only issues with the **Ready** status should be given to an implementation agent. The sole exception is advancing to the next named Ready issue inside an approved validation campaign after its predecessor reaches **Awaiting Validation** under `stages/7-implementation.md`.

## Issue Format

Use stable identifiers such as `IMP-001`.

Each issue should follow this structure:

```markdown
# IMP-001: Short Issue Name

**Status:** Ready  
**Type:** Vertical Slice  
**Priority:** High  
**Blocked By:** None

## Objective

Describe the single outcome this issue must produce.

## Requirements

- REQ-001
- REQ-002

## Architecture References

- Relevant component
- ARC-001

## Expected Outcome

Describe the observable behavior available after completion.

## In Scope

- Work included in this issue

## Out of Scope

- Related work intentionally excluded from this issue

## Implementation Constraints

- Approved architectural boundaries
- Required libraries or integration points
- Client/server restrictions
- Relevant project defaults

## Likely Code Areas

- Packages, components, or resources likely to change

## Decision

- Question:
- Resolver: Owner / Agent
- Options and consequences:
- Recommendation:
- Resolution:
- Recorded in:

## Acceptance Criteria

- Given ..., when ..., then ...
- Given ..., when ..., then ...

## Verification

- Automated checks where practical
- Development-client checks
- Dedicated-server checks
- Multiplayer, compatibility, or performance checks when relevant

## Manual Observability

- Authoritative state or event that a manual check must observe
- Whether stable normal behavior exposes it reliably
- Required logs, inspect commands, controlled-state commands, counters, or other narrow diagnostics when normal behavior is insufficient
- Evidence source or path, relevant retention or rotation behavior, and collection responsibility
- Independent input, output, test, or visible behavior that corroborates diagnostic claims when needed
- Same-issue implementation or explicit prerequisite issue
- Default enabled/disabled state and relevant authorization boundary
- Owner-visible observations unavailable to the agent
- Complete starting/reset state, cleanup, and runtime stop/continue condition
- Validation packet group and unavoidable restart boundary
- Agent Diagnostics Toolkit bundle, record categories, and retained bundle/log paths when selected

## Completion Evidence

Record the tests, commands, observations, logs, or measurements demonstrating completion.
```

Omit **Manual Observability** when the issue has no manual runtime verification. When it applies, complete the section before marking the issue Ready; do not leave the observation path or the inputs required by `guidelines/manual-validation.md` to be invented during Implementation.

Omit **Decision** unless the issue's type is Decision. For a Decision issue, omit **Manual Observability** and **Verification** instead, and treat the Decision section as its acceptance criteria.

Use these types:

- `Vertical Slice`: delivers observable mod behavior. The normal case.
- `Foundation`: delivers no observable behavior directly but is necessary to unblock identified vertical slices. Use only when that consumer is identified.
- `Decision`: delivers a settled question rather than a change. See Decision Issues.

## Dependency Graph

Represent blocking relationships as a directed acyclic graph.

An issue may begin only when all issues listed under `Blocked By` are complete.

Use a compact Mermaid diagram when it makes the dependencies easier to understand:

```mermaid
flowchart TD
    A["IMP-001: First Slice"] --> B["IMP-002: Extended Behavior"]
    A --> C["IMP-003: Configuration"]
    B --> D["IMP-004: Complete Feature"]
    C --> D
```

The graph describes dependency order, not necessarily a strict sequence. Issues without dependencies may be implemented independently.

## Definition of Done

A Decision issue is Done under the criteria in Decision Completion above.

Any other implementation issue is Done only when:

- Its implementation is complete.
- Its acceptance criteria are satisfied.
- Required automated checks pass.
- Required in-game verification is complete.
- Client and dedicated-server behavior have been checked when relevant.
- No unrelated requirements were introduced.
- The implementation follows the approved architecture.
- Relevant defects have been resolved or explicitly recorded.
- An independent review has been completed, or an eligible low-risk review limitation has been explicitly accepted under `stages/7-implementation.md`.
- Completion evidence has been recorded.
- The issue status has been changed to **Done**.

## Verification Environment Plan

Use these evidence tiers consistently:

1. **Automated or static:** compilation, unit tests, static inspection, or artifact inspection.
2. **Development client:** `runClient`, including its integrated server when applicable.
3. **Development dedicated server:** `runServer`. Needs the server configuration described under Development Dedicated Server Setup in `stages/7-implementation.md`.
4. **Packaged clean environment:** the built jar in a clean Forge client or dedicated server.
5. **Target modpack or alternate runtime:** the built jar in the intended pack, including Cleanroom when selected.
6. **External multiplayer:** a separately operated multiplayer environment.

Higher numbers are not automatically better or mandatory. Select tiers from the behavior and risk. For every planned check, record the tier, the evidence it supplies, and important evidence it cannot supply.

An **absence requirement** is an acceptance criterion of the form *works without X*, *works when X is missing*, or *does not require X*. It cannot be assigned to a tier whose environment contains X. Tiers 2 and 3 share one development installation, so anything present for one side is present for the other. When planning such a check:

- Name the component that must be absent.
- Confirm the chosen tier can genuinely lack it, rather than merely not exercise it.
- If no available tier can, say so in the plan and record the check as **Waive** with its evidence limitation.

Scheduling an absence check in an environment that contains the component is worse than not scheduling it, because it will appear to pass. See Absence Requirements in `stages/7-implementation.md`.

Dimension coverage is also risk-based. When behavior is dimension-agnostic, source inspection plus one representative non-Overworld runtime check is normally sufficient. Require broader dimension coverage only when the code, dependency, configuration, or reported defect is dimension-specific.

Before Implementation begins, present one compact decision packet for owner-performed manual checks. Record each as:

- **Test now:** required before the affected issue can be Done.
- **Defer:** postponed to a named later checkpoint.
- **Waive:** accepted as unperformed for this workflow, with the evidence limitation recorded.

Do not repeatedly ask about a deferred or waived check unless new evidence materially changes its risk.

When Project Setup selected the Agent Diagnostics Toolkit, add a toolkit plan to the Implementation Plan. Name the pinned artifact, runtime placement, baseline and login-automation choices, bundle storage, log-retention path, and checks that will use it. A toolkit-assisted check must still state what the toolkit cannot prove and which mod-specific diagnostic or owner-visible observation supplies the missing evidence.

## Owner-Assisted Validation Campaigns

When several small related issues require the same expensive runtime, the plan may group their owner-assisted checks into one validation campaign. Use a campaign only when it reduces launches or configuration churn without making a failure difficult to attribute.

For each campaign, record:

- A stable campaign name and the exact included issues and test cards.
- Why one shared runtime is materially cheaper than issue-by-issue owner testing.
- The common environment, configuration groups, restart boundaries, and session order.
- The automated, static, agent-run runtime, and independent-review gate each issue must pass before the campaign begins.
- How diagnostics, evidence, and retained per-issue change-boundary snapshots distinguish every included issue.
- Whether an earlier issue may reach **Awaiting Validation** and allow the next named issue to start despite the normal Done blocker.
- The failure-isolation and rollback route.
- The final batch-commit scope and its required authorization.

Do not create a campaign for unrelated issues, high-risk migrations, destructive behavior, or checks whose failure would make later implementation unsafe or likely to target the wrong design. Keep the group as small as practical. A campaign is a testing schedule, not permission to weaken acceptance criteria, independent review, evidence attribution, or commit authorization.

## Approval And Authorization Packet

After the plan and manual-validation decisions are complete, assess the active Change Cycle against the proportionate approval-bundle criteria in `guidelines/process-control.md`.

For an eligible single-issue, low-risk cycle, present one bounded packet that explicitly requests:

- Approval of the completed Implementation Plan.
- Authorization to begin Implementation of the named Ready issue.
- Authorization for the required read-only independent review.
- Authorization for one verified local issue commit after the issue is Done.

Record the eligibility basis, each covered action, explicit exclusions, invalidating conditions, and owner response in the Implementation Plan and `project-status.md`. Do not describe the packet as general permission. If the cycle is ineligible, record the material reason and use normal approval checkpoints.

## Process

1. Read all required input documents.
2. Extract requirements, architectural components, and implementation risks.
3. Identify the smallest useful end-to-end behavior.
4. Define the first vertical slice.
5. Divide remaining behavior into additional vertical slices.
6. Add only the foundational issues required by identified slices.
7. Link every issue to requirements and architecture.
8. Define acceptance criteria and verification for every issue.
9. Assign each verification check to an environment tier and state what that evidence proves and does not prove.
10. For every manual runtime check, define its observability contract, evidence source, collection responsibility, necessary corroboration, owner-only observations, reset/cleanup state, and validation-packet group; add any required same-issue diagnostic work or prerequisite issue.
11. Present one decision packet for owner-performed manual validation and record each check as Test now, Defer, or Waive.
12. Define any eligible owner-assisted validation campaign, including readiness gates, evidence attribution, failure isolation, and batch-commit policy.
13. Identify dependencies and blockers, including diagnostic prerequisites that must be Done before dependent manual verification begins.
14. Construct the dependency graph.
15. Check the graph for cycles.
16. Schedule risky assumptions and validation work early.
17. Confirm that every required behavior is covered.
18. Identify optional requirements that will be deferred.
19. Generate the implementation-plan artifacts as complete drafts.
20. Assess and record proportionate approval-bundle eligibility.
21. Present the drafts and, when eligible, the bounded approval and authorization packet; revise them until explicitly approved.

## Output Artifacts

### `<artifact-root>/implementation-plan.md`

Produce the plan from `setup/artifact-templates/implementation-plan.md`. The template is the authoritative plan structure. The issue format defined by this stage and reproduced in that template is authoritative for issue files.

### `<artifact-root>/issues/`

Create one Markdown file for each implementation issue:

```text
issues/
├── IMP-001-short-name.md
├── IMP-002-short-name.md
└── IMP-003-short-name.md
```

The implementation plan should reference these files instead of duplicating their full contents.

## Completion Criteria

This stage is complete when:

- Every MUST requirement is covered by at least one issue.
- Every SHOULD and MAY requirement is scheduled or explicitly deferred.
- Issues are organized primarily as vertical slices.
- Necessary foundational work has a specific identified consumer.
- Every issue has an objective, scope, acceptance criteria, and verification procedure. A Decision issue instead has a question, a named resolver, and the work it blocks.
- Every verification check identifies its environment tier, evidentiary value, and material limitation.
- Owner-performed manual checks have one recorded Test now, Defer, or Waive decision.
- Every manual runtime verification procedure identifies what authoritative state or event it observes and has the necessary diagnostic support in the same issue or an explicit completed prerequisite.
- Every manual runtime verification procedure assigns evidence collection: the agent directly inspects accessible current and rotated logs, while owner-returned evidence is limited to inaccessible observations or environments.
- Every owner-assisted procedure contains enough planned state, grouping, and lifecycle information to produce the session map and test cards required by `guidelines/manual-validation.md` without inventing test behavior during Implementation.
- Every validation campaign is small, shares a justified runtime cost, preserves per-issue evidence attribution, and records readiness, failure, and commit boundaries.
- Every issue references relevant requirements and architecture.
- All blocking relationships are explicit.
- The dependency graph is acyclic.
- High-risk implementation validations are scheduled early.
- The first slice produces integrated and observable behavior.
- Each Ready issue can be understood by an agent with fresh context.
- The Definition of Done is established.
- The project owner explicitly approves the plan.
- `<artifact-root>/implementation-plan.md` and the issue files have been generated and explicitly approved.

Completion does not require writing implementation code.

The plan is an approved baseline, but it may be updated when implementation produces new evidence. Any change affecting requirements or architecture must return to the appropriate earlier stage.

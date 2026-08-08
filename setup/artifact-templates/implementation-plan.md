# Implementation Plan

## Implementation Strategy

-

## Vertical Slice Overview

-

## Foundation Work

-

## Issue Summary

| Issue | Title | Type | Status | Dependencies |
| --- | --- | --- | --- | --- |
| IMP-001 |  | Vertical Slice | Ready |  |

## Dependency Graph

-

## Suggested Execution Order

-

## Risk-Driven Priorities

-

## Verification Strategy

-

## Agent Diagnostics Toolkit Plan

- Selection and pinned artifact:
- Runtime placement and release exclusion:
- Safe baseline and join automation:
- Bundle storage and naming:
- Log retention:
- Planned toolkit-assisted checks:
- Evidence the toolkit cannot provide:

## Verification Environment Plan

| Check | Environment Tier | What It Proves | What It Does Not Prove |
| --- | --- | --- | --- |
|  |  |  |  |

## Manual Validation Decisions

| Check | Owner Decision | Due Checkpoint | Evidence Limitation |
| --- | --- | --- | --- |
|  | Test now / Defer / Waive |  |  |

## Owner-Assisted Validation Campaigns

| Campaign | Included Issues And Cards | Shared Runtime Benefit | Readiness Gate | Evidence Attribution | Failure Route | Batch Commit Policy |
| --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |

## Approval And Authorization Packet

- **Proportionate bundle eligibility:** Eligible / Ineligible, with reason
- **Implementation Plan approval:** Requested / Approved / Not Approved
- **Implementation start:** Named issue and authorization status
- **Read-only independent review:** Scope and authorization status
- **Verified local commit:** Conditions and authorization status
- **Explicit exclusions:** Push, tag, publication, upload, external-service change, destructive action, scope expansion, and unbriefed or additional issues
- **Invalidating conditions:** Material changes to requirements, architecture, issue or review scope, verification outcome, repository condition, or external effects
- **Owner response:** Pending / Exact response and date

## Definition Of Done

-

## Requirement Traceability

-

## Deferred Requirements

-

## Issue Template

```markdown
# IMP-000: Issue Title

**Status:** Ready
**Type:** Vertical Slice / Foundation / Decision
**Priority:** High
**Blocked By:** None

## Objective

## Requirements

## Architecture References

## Expected Outcome

## In Scope

## Out Of Scope

## Implementation Constraints

## Complexity Management

- Classification: Complexity-bearing / Routine
- Approved boundary or architectural decision:
- Design knowledge and authoritative owner:
- Common operation and required caller knowledge:
- Likely changes that must remain local:
- Red flags the implementation and reviewer must inspect:

## Existing-Code Design Fit

- Applies: Yes / No
- Design target if the requested behavior had existed from the beginning:
- Authorized local-improvement boundary:
- Conditions that require an architecture or earlier-stage revision:
- Known constraint and cleaner deferred alternative, when a tactical compromise is already unavoidable:

## Likely Code Areas

## Decision

- Question:
- Resolver: Owner / Agent
- Options and consequences:
- Recommendation:
- Resolution:
- Recorded in:

## Acceptance Criteria

## Verification

## Defect Regression Protection

- Applies: Yes / No
- Original defect and minimal reproduction:
- Detection boundary and lowest stable check level:
- Durable automated check, toolkit bundle, or validation card:
- How the check would fail if the defect returned:
- Planned pre-correction failure or controlled sensitivity demonstration:
- Automation limitation and runtime fallback, when applicable:
- Retained test or scenario path:

## Manual Observability

- Authoritative state or event:
- Reliably exposed by normal behavior:
- Diagnostic mechanism, when required:
- Evidence source or path:
- Retention or rotation behavior:
- Evidence collector (agent or owner):
- Independent corroborating evidence:
- Same-issue work or prerequisite:
- Default state and authorization boundary:
- Owner-visible observations unavailable to the agent:
- Complete starting/reset state:
- Cleanup and runtime stop/continue condition:
- Validation packet group and restart boundary:
- Agent Diagnostics Toolkit bundle, categories, marks, and retained paths:

## Completion Evidence

Every result line ends with one label: (observed), (inspected), or (inferred). See Evidence Labels in `stages/7-implementation.md`.

For a Decision issue, record the resolution and its evidence in the Decision section above and omit the verification categories below.

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

### Compatibility Or Performance

- Procedure:
- Result (observed | inspected | inferred):

### Accepted Validation Waivers

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
```

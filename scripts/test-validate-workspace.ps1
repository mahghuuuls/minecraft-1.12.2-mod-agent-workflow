param()

$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'validate-workspace.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("workflow-workspace-validator-" + [guid]::NewGuid().ToString('N'))
$documentationRoot = Join-Path $testRoot 'documentation'
$issuesRoot = Join-Path $documentationRoot 'issues'
$projectRoot = Join-Path $testRoot 'project/example'

function Write-Utf8([string]$path, [string]$content) {
    Set-Content -LiteralPath $path -Value $content -Encoding UTF8
}

function Invoke-Validator {
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -WorkspaceRoot $testRoot 2>&1
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join [Environment]::NewLine) }
}

function Assert-ExitCode([string]$name, [int]$expected, [object]$result) {
    if ($result.ExitCode -ne $expected) {
        throw "$name expected exit code $expected but received $($result.ExitCode). Output: $($result.Output)"
    }
}

try {
    New-Item -ItemType Directory -Path $issuesRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null

    $status = @'
# Project Status

## Active Workflow

- Workflow: Initial Development
- Status: **In Progress**
- Artifact root: `workspace/documentation/`
- Active repository: `workspace/project/example/`

## Stage Routing

| Stage | Disposition | Status | Approved Artifact |
| --- | --- | --- | --- |
| Implementation | Required | **In Progress** | Pending |

## Implementation

- IMP-001 is **Ready**.
'@
    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') $status

    $state = @'
# Project State

## Resume Context

- Active repository: `workspace/project/example/`
- Active workflow: Initial Development
- Artifact root: `workspace/documentation/`
- Current implementation issue: IMP-001
'@
    Write-Utf8 (Join-Path $documentationRoot 'project-state.md') $state

    $issueReady = @'
# IMP-001: Fixture

**Status:** Ready
'@
    $issuePath = Join-Path $issuesRoot 'IMP-001-fixture.md'
    Write-Utf8 $issuePath $issueReady

    $planReady = @'
# Implementation Plan

## Issue Summary

| Issue | Title | Status | Dependencies |
| --- | --- | --- | --- |
| IMP-001 | Fixture | Ready | None |
'@
    $planPath = Join-Path $documentationRoot 'implementation-plan.md'
    Write-Utf8 $planPath $planReady

    Assert-ExitCode 'valid workspace' 0 (Invoke-Validator)

    # Stage-status cells: an exact status may lead a date and a note; Not Applicable needs none;
    # only the active stage table fails on another word, earlier record tables warn.
    $statusWithCycle = @'
# Project Status

## Active Workflow

- Workflow: Initial Development
- Status: **Approved**
- Artifact root: `workspace/documentation/`
- Active repository: `workspace/project/example/`

| Stage | Disposition | Status |
| --- | --- | --- |
| Implementation | Required | All issues Done. Approved 2026-08-07 |

## Active Cycle

### Stage Dispositions, CYCLE-002

| Stage | Disposition | Status |
| --- | --- | --- |
| Implementation Plan | **Revisit** | **Approved 2026-11-03** ("approve plan"). Six issues |
| Project Initialization | Not Applicable | Never rerun |
| Implementation | **Revisit** | In Progress. Campaign A closed |
| Release Presentation | **Revisit** | Not Started |

## CYCLE-001 Record

| Stage | Disposition | Status |
| --- | --- | --- |
| Implementation | **Revisit** | Complete 2026-10-01 |
| Release Presentation | **Revisit** | In Progress, left over |

## Implementation

- IMP-001 is **Ready**.
'@
    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') $statusWithCycle
    $cycleStatusResult = Invoke-Validator
    Assert-ExitCode 'stage statuses with notes, Not Applicable, and earlier record tables' 0 $cycleStatusResult
    if ($cycleStatusResult.Output -notlike "*Stage record 'Implementation' in an earlier stage table*") {
        throw "Validator did not warn about the earlier record table. Output: $($cycleStatusResult.Output)"
    }
    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') ($statusWithCycle.Replace('| Not Started |', '| Complete 2026-11-03 |'))
    Assert-ExitCode 'unsupported word in the active stage table' 1 (Invoke-Validator)
    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') ($statusWithCycle.Replace('| Not Started |', '| Approvedish |'))
    Assert-ExitCode 'a word that only starts like a status' 1 (Invoke-Validator)
    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') ($statusWithCycle.Replace('| Not Started |', '| In Progress |'))
    Assert-ExitCode 'two In Progress stages in the active table' 1 (Invoke-Validator)
    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') $status

    $planNoStatus = @'
# Implementation Plan

## Issue Summary

| Issue | Title | Type | Dependencies |
| --- | --- | --- | --- |
| IMP-001 | Fixture | Vertical Slice | None |
'@
    Write-Utf8 $planPath $planNoStatus
    $noStatusResult = Invoke-Validator
    Assert-ExitCode 'plan without a status column' 0 $noStatusResult
    if ($noStatusResult.Output -notlike '*IMP-001 Ready*') {
        throw "Validator did not print the issue status roll-up. Output: $($noStatusResult.Output)"
    }
    Write-Utf8 $planPath $planReady

    $cycleRoot = Join-Path $documentationRoot 'cycles/CYCLE-001-fixture'
    $cycleIssuesRoot = Join-Path $cycleRoot 'issues'
    New-Item -ItemType Directory -Path $cycleIssuesRoot -Force | Out-Null
    Write-Utf8 (Join-Path $cycleIssuesRoot 'IMP-001-cycle-fixture.md') @'
# IMP-001: Cycle Fixture

**Status:** Done
'@
    Write-Utf8 (Join-Path $cycleRoot 'implementation-plan.md') @'
# Implementation Plan

## Issue Summary

| Issue | Title | Status | Dependencies |
| --- | --- | --- | --- |
| IMP-001 | Cycle Fixture | Done | None |
'@
    Assert-ExitCode 'same issue identifier in a separate artifact root' 0 (Invoke-Validator)

    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') ($status.Replace('IMP-001 is **Ready**', 'IMP-001 is **Done**'))
    Assert-ExitCode 'ledger and issue disagreement' 1 (Invoke-Validator)
    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') $status

    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') ($status.Replace('| Pending |', '| `workspace/documentation/missing.md` |'))
    Assert-ExitCode 'missing approved stage artifact' 1 (Invoke-Validator)
    Write-Utf8 (Join-Path $documentationRoot 'project-status.md') $status

    Write-Utf8 $issuePath ($issueReady.Replace('Ready', 'Unknown'))
    Assert-ExitCode 'invalid issue status' 1 (Invoke-Validator)

    Write-Utf8 $issuePath $issueReady
    Write-Utf8 $planPath ($planReady.Replace('| Ready |', '| Done |'))
    Assert-ExitCode 'plan and issue disagreement' 1 (Invoke-Validator)

    Write-Utf8 $issuePath ($issueReady.Replace('Ready', 'In Progress'))
    $secondIssue = @'
# IMP-002: Second Fixture

**Status:** In Progress
'@
    Write-Utf8 (Join-Path $issuesRoot 'IMP-002-second-fixture.md') $secondIssue
    $twoActivePlan = @'
# Implementation Plan

## Issue Summary

| Issue | Title | Status | Dependencies |
| --- | --- | --- | --- |
| IMP-001 | Fixture | In Progress | None |
| IMP-002 | Second Fixture | In Progress | None |
'@
    Write-Utf8 $planPath $twoActivePlan
    Assert-ExitCode 'multiple active issues' 1 (Invoke-Validator)

    # Evidence packs of Done issues: the named folder must exist and its manifest must match the recorded hash.
    Write-Utf8 $issuePath $issueReady
    Write-Utf8 (Join-Path $issuesRoot 'IMP-002-second-fixture.md') @'
# IMP-002: Second Fixture

**Status:** Done

## Evidence Pack

- Applies: Yes (Campaign X).

## Verification

- Planned pack: `workspace/validation/campaigns/campaign-x-<commit>/` (a placeholder the validator must ignore).

## Completion Evidence

- Evidence pack: `workspace/validation/campaigns/campaign-x-abc1234/`, verified.
'@
    Write-Utf8 $planPath @'
# Implementation Plan

## Issue Summary

| Issue | Title | Status | Dependencies |
| --- | --- | --- | --- |
| IMP-001 | Fixture | Ready | None |
| IMP-002 | Second Fixture | Done | None |
'@
    Assert-ExitCode 'done issue naming a missing pack' 1 (Invoke-Validator)

    $packRoot = Join-Path $testRoot 'validation/campaigns/campaign-x-abc1234'
    New-Item -ItemType Directory -Path $packRoot -Force | Out-Null
    $manifestPath = Join-Path $packRoot 'manifest.json'
    Write-Utf8 $manifestPath '{ "checkpoint": "campaign-x" }'
    $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
    Write-Utf8 (Join-Path $packRoot 'manifest.sha256') "$manifestHash  manifest.json"
    Assert-ExitCode 'done issue naming a verified pack' 0 (Invoke-Validator)

    Write-Utf8 $manifestPath '{ "checkpoint": "campaign-x", "changed": true }'
    Assert-ExitCode 'done issue naming a pack whose manifest changed' 1 (Invoke-Validator)
    Remove-Item -LiteralPath (Join-Path $packRoot 'manifest.json')
    Assert-ExitCode 'done issue naming a pack without a manifest' 1 (Invoke-Validator)

    Write-Utf8 (Join-Path $issuesRoot 'IMP-002-second-fixture.md') @'
# IMP-002: Second Fixture

**Status:** Done

## Evidence Pack

- Applies: Yes (Campaign X).
'@
    $noPackResult = Invoke-Validator
    Assert-ExitCode 'done issue with an applicable pack but no path' 0 $noPackResult
    if ($noPackResult.Output -notlike '*names no pack folder*') {
        throw "Validator did not warn about the missing pack path. Output: $($noPackResult.Output)"
    }

    $campaignRoot = Join-Path $testRoot 'validation/work/campaign-x'
    New-Item -ItemType Directory -Path $campaignRoot -Force | Out-Null
    Write-Utf8 (Join-Path $campaignRoot 'campaign-x-session-map.md') @'
# Campaign X Session Map

1. First card.
2. Second card.
2b. Repeat of the second card.
'@
    $noTable = Invoke-Validator
    Assert-ExitCode 'a session map without a criterion table before its campaign' 1 $noTable
    if ($noTable.Output -notlike '*campaign-x-session-map.md: no criterion-to-card table*') {
        throw "Validator did not name the missing criterion table. Output: $($noTable.Output)"
    }
    Write-Utf8 (Join-Path $campaignRoot 'campaign-x-session-map.md') @'
# Campaign X Session Map

1. First card.
2. Second card.
2b. Repeat of the second card.

| Criterion | Card |
| --- | --- |
| IMP-001 criterion 1 | 1 |
| IMP-001 criterion 2 | 2, 2b |
'@
    Assert-ExitCode 'a session map with a criterion table before its campaign' 0 (Invoke-Validator)
    Write-Utf8 (Join-Path $campaignRoot 'campaign-x-results.md') @'
# Campaign X Results

1. Passed.
2. Passed.
'@
    $lostCardResult = Invoke-Validator
    Assert-ExitCode 'session-map card with no results line' 1 $lostCardResult
    if ($lostCardResult.Output -notlike '*card 2b of campaign-x-session-map.md has no line*') {
        throw "Validator did not name the lost card. Output: $($lostCardResult.Output)"
    }
    Write-Utf8 (Join-Path $campaignRoot 'campaign-x-results.md') @'
# Campaign X Results

1. Passed.
2. Passed.
2b. Not run: deferred by the owner, reason recorded.
'@
    Assert-ExitCode 'every session-map card recorded' 0 (Invoke-Validator)

    # A change cycle's issues carry another prefix and a status line with a note; the older bold form is read too.
    $cycleTwoRoot = Join-Path $documentationRoot 'cycles/CYCLE-002-fixture'
    New-Item -ItemType Directory -Path (Join-Path $cycleTwoRoot 'issues') -Force | Out-Null
    Write-Utf8 (Join-Path $cycleTwoRoot 'issues/CYC2-001-fixture.md') @'
# CYC2-001: Fixture

**Status:** Done, 2026-11-04. The campaign passed; committed in the release candidate.
'@
    Write-Utf8 (Join-Path $cycleTwoRoot 'issues/CYC2-002-older-form.md') @'
# CYC2-002: Older Form

**Status: Done** 2026-08-10. Committed.
'@
    $cycleIssuesResult = Invoke-Validator
    Assert-ExitCode 'change-cycle issues with notes and the older bold status' 0 $cycleIssuesResult
    if ($cycleIssuesResult.Output -notlike '*CYC2-001 Done, CYC2-002 Done*') {
        throw "Validator did not read the change-cycle issues. Output: $($cycleIssuesResult.Output)"
    }
    Write-Utf8 (Join-Path $cycleTwoRoot 'issues/CYC2-002-older-form.md') "# CYC2-002: Older Form`n`n**Status:** Finished, 2026-08-10."
    Assert-ExitCode 'a change-cycle issue with an unsupported status' 1 (Invoke-Validator)
    Write-Utf8 (Join-Path $cycleTwoRoot 'issues/CYC2-002-older-form.md') "# CYC2-002: Older Form`n`n**Status: Done** 2026-08-10."

    # A session map under the documentation names its results file; cards are matched by their bold identifier.
    $stagingRoot = Join-Path $testRoot 'validation/staging/cyc2-final'
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
    Write-Utf8 (Join-Path $cycleTwoRoot 'final-session-map.md') @'
# Final Campaign Session Map

Results file: `workspace/validation/staging/cyc2-final/running-notes.md`

1. **G1 Create.** The world opens.
2. **G2 Quit.** The game closes.
3. **X1 Extra.** Added after the review.
'@
    Assert-ExitCode 'a linked session map without a criterion table before its results file exists' 1 (Invoke-Validator)
    Write-Utf8 (Join-Path $stagingRoot 'running-notes.md') @'
# Results

- **G1 Create.** Passed (observed).
- **X1 Extra.** Passed (observed).
'@
    $lostCycleCard = Invoke-Validator
    Assert-ExitCode 'a change-cycle session-map card with no results line' 1 $lostCycleCard
    if ($lostCycleCard.Output -notlike '*card G2 has no line*') {
        throw "Validator did not name the lost change-cycle card. Output: $($lostCycleCard.Output)"
    }
    Write-Utf8 (Join-Path $stagingRoot 'running-notes.md') "# Results`n`n- **G1 Create.** Passed.`n- **G2 Quit.** Passed.`n- **X1 Extra.** Passed.`n"
    $coveredCycle = Invoke-Validator
    Assert-ExitCode 'every change-cycle card recorded' 0 $coveredCycle
    if ($coveredCycle.Output -notlike '*every card of 2 session map(s)*') {
        throw "Validator did not count the checked session maps. Output: $($coveredCycle.Output)"
    }
    Write-Utf8 (Join-Path $cycleTwoRoot 'older-session-map.md') "# Older Map`n`n1. A card without an identifier.`n"
    $unlinked = Invoke-Validator
    Assert-ExitCode 'a session map without a results file' 0 $unlinked
    if ($unlinked.Output -notlike "*1 session map(s) under the documentation name no 'Results file:'*") {
        throw "Validator did not warn about the unlinked session map. Output: $($unlinked.Output)"
    }

    Write-Host 'Workspace validator tests passed: valid state, stage statuses with a date and a note, Not Applicable stages and earlier record tables accepted (the active table checked strictly), a plan without a status column (with the issue roll-up printed), and cycle-scoped identifiers accepted; evidence packs of Done issues checked; a session map without a criterion-to-card table rejected before its campaign and accepted with one, a session-map card without a results line rejected and a recorded one accepted, for a work-folder campaign and for a change-cycle map that names its results file (cards by identifier, maps counted, an unlinked map warned); change-cycle issues with a status note or the older bold form read; invalid status, missing stage artifacts, ledger or plan disagreement, and multiple active issues rejected.' -ForegroundColor Green
} finally {
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTestRoot.StartsWith($resolvedTempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

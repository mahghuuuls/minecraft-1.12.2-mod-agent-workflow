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

    Write-Host 'Workspace validator tests passed: valid state and cycle-scoped identifiers accepted; invalid status, missing stage artifacts, ledger or plan disagreement, and multiple active issues rejected.' -ForegroundColor Green
} finally {
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedTestRoot.StartsWith($resolvedTempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

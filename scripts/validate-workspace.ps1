param(
    [string]$WorkspaceRoot
)

$ErrorActionPreference = 'Stop'
$processRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $WorkspaceRoot = Join-Path $processRoot 'workspace'
}
$WorkspaceRoot = [System.IO.Path]::GetFullPath($WorkspaceRoot)
$documentationRoot = Join-Path $WorkspaceRoot 'documentation'
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError([string]$message) {
    $script:errors.Add($message)
}

function Add-ValidationWarning([string]$message) {
    $script:warnings.Add($message)
}

function Normalize-MarkdownValue([string]$value) {
    if ($null -eq $value) { return $null }
    return $value.Trim().Trim('`').Replace('**', '').Trim()
}

function Get-BulletValue([string]$text, [string]$label) {
    $escaped = [regex]::Escape($label)
    $match = [regex]::Match($text, "(?m)^\s*-\s*${escaped}:\s*(?<value>.+?)\s*$")
    if (-not $match.Success) { return $null }
    return Normalize-MarkdownValue $match.Groups['value'].Value
}

function Resolve-ProcessPath([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $null }
    $inlinePath = [regex]::Match($value, '`?(?<path>(?:workspace[/\\]|[A-Za-z]:[/\\])[^`]+)')
    if ($inlinePath.Success) {
        $candidate = $inlinePath.Groups['path'].Value.Trim()
    } else {
        $candidate = Normalize-MarkdownValue $value
    }
    $descriptionIndex = $candidate.IndexOf(' - ')
    if ($descriptionIndex -gt 0) {
        $candidate = $candidate.Substring(0, $descriptionIndex).Trim()
    }
    if ([System.IO.Path]::IsPathRooted($candidate)) {
        return [System.IO.Path]::GetFullPath($candidate).TrimEnd([char[]]'\/')
    }
    if ($candidate -match '^workspace[/\\](?<relative>.*)$') {
        return [System.IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $Matches['relative'])).TrimEnd([char[]]'\/')
    }
    return [System.IO.Path]::GetFullPath((Join-Path $processRoot $candidate)).TrimEnd([char[]]'\/')
}

function Get-IssueStatus([string]$path) {
    $text = Get-Content -Raw -LiteralPath $path
    $match = [regex]::Match($text, '(?m)^\*\*Status:\*\*\s*(?<status>[^\r\n]+?)\s*$')
    if (-not $match.Success) { return $null }
    return Normalize-MarkdownValue $match.Groups['status'].Value
}

if (-not (Test-Path -LiteralPath $documentationRoot -PathType Container)) {
    Add-ValidationError "Missing runtime documentation directory: $documentationRoot"
}

$statusPath = Join-Path $documentationRoot 'project-status.md'
if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
    Add-ValidationWarning 'project-status.md does not exist; workflow-ledger checks were skipped because a mod-development workflow may not have started yet.'
} else {
    $statusText = Get-Content -Raw -LiteralPath $statusPath
    $workflowStageStatuses = @('Not Started', 'In Progress', 'Awaiting Approval', 'Approved', 'Needs Revision')

    foreach ($match in [regex]::Matches($statusText, '(?m)^\s*-\s*Status:\s*\*\*(?<status>[^*]+)\*\*\s*$')) {
        $value = $match.Groups['status'].Value.Trim()
        if ($workflowStageStatuses -notcontains $value) {
            Add-ValidationError "Unsupported workflow or stage status '$value' in project-status.md."
        }
    }

    $stageRows = [System.Collections.Generic.List[object]]::new()
    $statusLines = $statusText -split "`r?`n"
    $insideStageTable = $false
    foreach ($line in $statusLines) {
        if ($line -match '^\s*\|\s*Stage\s*\|\s*Disposition\s*\|\s*Status\s*\|') {
            $insideStageTable = $true
            continue
        }
        if (-not $insideStageTable) { continue }
        if ($line -notmatch '^\s*\|') {
            $insideStageTable = $false
            continue
        }
        if ($line -match '^\s*\|\s*-+') { continue }
        $rawCells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        $cells = @($rawCells | ForEach-Object { Normalize-MarkdownValue $_ })
        if ($cells.Count -lt 3) { continue }
        if ($rawCells.Count -ge 4) { $artifact = $rawCells[3] } else { $artifact = $null }
        $stageRows.Add([pscustomobject]@{ Stage = $cells[0]; Status = $cells[2]; Artifact = $artifact })
    }

    foreach ($row in $stageRows) {
        if ($workflowStageStatuses -notcontains $row.Status) {
            Add-ValidationError "Unsupported stage status '$($row.Status)' for '$($row.Stage)' in project-status.md."
        }
        if (-not [string]::IsNullOrWhiteSpace($row.Artifact) -and $row.Artifact -match '`(?:workspace|[A-Za-z]:)[^`]+`') {
            try {
                $resolvedArtifact = Resolve-ProcessPath $row.Artifact
                if (-not (Test-Path -LiteralPath $resolvedArtifact)) {
                    Add-ValidationError "Stage '$($row.Stage)' points to a missing approved artifact: $($row.Artifact)"
                }
            } catch {
                Add-ValidationWarning "Could not resolve the approved artifact for stage '$($row.Stage)': $($row.Artifact)"
            }
        }
    }
    $activeStages = @($stageRows | Where-Object { $_.Status -eq 'In Progress' })
    if ($activeStages.Count -gt 1) {
        Add-ValidationError "Multiple reusable stages are In Progress: $($activeStages.Stage -join ', ')."
    }

    foreach ($label in @('Approved artifact', 'Artifact', 'Approved baseline', 'Artifact root', 'Active repository', 'Repository path')) {
        $value = Get-BulletValue $statusText $label
        if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^(None|Not applicable|Pending)\b') { continue }
        try {
            $resolved = Resolve-ProcessPath $value
            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-ValidationError "Structured project-status.md field '$label' points to a missing path: $value"
            }
        } catch {
            Add-ValidationWarning "Could not resolve project-status.md field '$label' as a path: $value"
        }
    }
}

$issueStatuses = @('Backlog', 'Ready', 'In Progress', 'Awaiting Validation', 'Review', 'Blocked', 'Done', 'Deferred')
$issueFiles = @(Get-ChildItem -LiteralPath $documentationRoot -Recurse -File -Filter 'IMP-*.md' -ErrorAction SilentlyContinue | Where-Object { $_.Directory.Name -eq 'issues' })
$issueRecords = [System.Collections.Generic.List[object]]::new()
foreach ($file in $issueFiles) {
    $idMatch = [regex]::Match($file.BaseName, '^(?<id>IMP-\d{3})(?:-|$)')
    if (-not $idMatch.Success) { continue }
    $status = Get-IssueStatus $file.FullName
    if ([string]::IsNullOrWhiteSpace($status)) {
        Add-ValidationError "Issue file has no parseable Status field: $($file.FullName)"
        continue
    }
    if ($issueStatuses -notcontains $status) {
        Add-ValidationError "Unsupported issue status '$status' in $($file.FullName)."
    }
    $scope = $file.Directory.Parent.FullName
    $issueRecords.Add([pscustomobject]@{ Id = $idMatch.Groups['id'].Value; Status = $status; Path = $file.FullName; Scope = $scope })
}

$duplicateIssues = @($issueRecords | Group-Object { "$($_.Scope)|$($_.Id)" } | Where-Object { $_.Count -gt 1 })
foreach ($duplicate in $duplicateIssues) {
    Add-ValidationError "Multiple issue files use $($duplicate.Group[0].Id) in artifact root $($duplicate.Group[0].Scope): $($duplicate.Group.Path -join ', ')"
}

$activeIssues = @($issueRecords | Where-Object { $_.Status -eq 'In Progress' })
if ($activeIssues.Count -gt 1) {
    Add-ValidationError "Multiple implementation issues are In Progress: $($activeIssues.Id -join ', ')."
}

$planFiles = @(Get-ChildItem -LiteralPath $documentationRoot -Recurse -File -Filter 'implementation-plan.md' -ErrorAction SilentlyContinue)
foreach ($plan in $planFiles) {
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $plan.FullName) {
        $lineNumber++
        if ($line -notmatch '^\s*\|\s*(?<id>IMP-\d{3})\s*\|') { continue }
        $id = $Matches['id']
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { Normalize-MarkdownValue $_ })
        $planStatus = $null
        foreach ($cell in $cells) {
            if ($issueStatuses -contains $cell) {
                $planStatus = $cell
                break
            }
        }
        if ($null -eq $planStatus) { continue }
        $matchingIssues = @($issueRecords | Where-Object { $_.Scope -eq $plan.Directory.FullName -and $_.Id -eq $id })
        if ($matchingIssues.Count -eq 0) {
            Add-ValidationError "Implementation plan references $id with status $planStatus, but no issue file exists ($($plan.FullName):$lineNumber)."
            continue
        }
        if ($matchingIssues[0].Status -ne $planStatus) {
            Add-ValidationError "Status disagreement for ${id}: plan says '$planStatus', issue file says '$($matchingIssues[0].Status)' ($($plan.FullName):$lineNumber)."
        }
    }
}

if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
    $activeArtifactValue = Get-BulletValue $statusText 'Artifact root'
    if (-not [string]::IsNullOrWhiteSpace($activeArtifactValue)) {
        try {
            $activeArtifactRoot = Resolve-ProcessPath $activeArtifactValue
        } catch {
            $activeArtifactRoot = $null
        }
        if ($null -ne $activeArtifactRoot) {
            foreach ($match in [regex]::Matches($statusText, '(?m)^\s*-\s*(?<id>IMP-\d{3})\b[^\r\n]*?\*\*(?<status>Backlog|Ready|In Progress|Awaiting Validation|Review|Blocked|Done|Deferred)\*\*')) {
                $id = $match.Groups['id'].Value
                $recordedStatus = $match.Groups['status'].Value
                $matchingIssues = @($issueRecords | Where-Object { $_.Scope -eq $activeArtifactRoot -and $_.Id -eq $id })
                if ($matchingIssues.Count -eq 0) {
                    Add-ValidationError "project-status.md names $id in active artifact root $activeArtifactValue, but no matching issue file exists."
                } elseif ($matchingIssues[0].Status -ne $recordedStatus) {
                    Add-ValidationError "Status disagreement for ${id}: project-status.md says '$recordedStatus', issue file says '$($matchingIssues[0].Status)'."
                }
            }
        }
    }
}

$statePath = Join-Path $documentationRoot 'project-state.md'
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    $stateText = Get-Content -Raw -LiteralPath $statePath
    foreach ($label in @('Active repository', 'Artifact root')) {
        $value = Get-BulletValue $stateText $label
        if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^(None|Not applicable|Pending)\b') { continue }
        try {
            $resolved = Resolve-ProcessPath $value
            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-ValidationError "project-state.md field '$label' points to a missing path: $value"
            }
        } catch {
            Add-ValidationWarning "Could not resolve project-state.md field '$label' as a path: $value"
        }
    }

    $currentIssue = Get-BulletValue $stateText 'Current implementation issue'
    if (-not [string]::IsNullOrWhiteSpace($currentIssue) -and $currentIssue -notmatch '^(None|Not applicable|Pending)\b') {
        $idMatch = [regex]::Match($currentIssue, 'IMP-\d{3}')
        $stateArtifactValue = Get-BulletValue $stateText 'Artifact root'
        try {
            $stateArtifactRoot = Resolve-ProcessPath $stateArtifactValue
        } catch {
            $stateArtifactRoot = $null
        }
        if ($idMatch.Success -and $null -ne $stateArtifactRoot -and @($issueRecords | Where-Object { $_.Scope -eq $stateArtifactRoot -and $_.Id -eq $idMatch.Value }).Count -eq 0) {
            Add-ValidationError "project-state.md names missing current issue $($idMatch.Value) in artifact root $stateArtifactValue."
        }
    }

    if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
        $statusText = Get-Content -Raw -LiteralPath $statusPath
        foreach ($pair in @(@('Active repository', 'Active repository'), @('Active workflow', 'Workflow'), @('Artifact root', 'Artifact root'))) {
            $stateValue = Get-BulletValue $stateText $pair[0]
            $statusValue = Get-BulletValue $statusText $pair[1]
            if ([string]::IsNullOrWhiteSpace($stateValue) -or [string]::IsNullOrWhiteSpace($statusValue)) { continue }
            if ($pair[0] -in @('Active repository', 'Artifact root')) {
                try {
                    $stateComparable = Resolve-ProcessPath $stateValue
                    $statusComparable = Resolve-ProcessPath $statusValue
                } catch {
                    continue
                }
            } else {
                $stateComparable = (Normalize-MarkdownValue $stateValue) -replace '\s+(?:[^\x00-\x7F]+|-)\s+.*$', ''
                $statusComparable = (Normalize-MarkdownValue $statusValue) -replace '\s+(?:[^\x00-\x7F]+|-)\s+.*$', ''
            }
            if ($stateComparable -ne $statusComparable) {
                Add-ValidationWarning "Resume snapshot may be stale: project-state.md '$($pair[0])' is '$stateValue', while project-status.md '$($pair[1])' is '$statusValue'."
            }
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "Workspace validation produced $($warnings.Count) warning(s):" -ForegroundColor Yellow
    foreach ($message in $warnings) {
        Write-Host "- $message" -ForegroundColor Yellow
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Workspace validation failed with $($errors.Count) error(s):" -ForegroundColor Red
    foreach ($message in $errors) {
        Write-Host "- $message" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Workspace validation passed: workflow/stage statuses, issue statuses, active-item counts, structured paths, plan/issue agreement, and resume references are mechanically consistent." -ForegroundColor Green

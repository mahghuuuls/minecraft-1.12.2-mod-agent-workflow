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
    if (-not $match.Success) {
        # The older form puts the status inside the bold label: "**Status: Done** 2026-08-10."
        $match = [regex]::Match($text, '(?m)^\*\*Status:\s*(?<status>[^*\r\n]+?)\*\*')
    }
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

    # A stage-status cell starts with an exact status and may go on with a date and a note:
    # "**Approved 2026-11-03** ("approve plan"). Six issues ...". Only the leading status is checked.
    $leadingStatusPattern = '^(?<status>' + (($workflowStageStatuses | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')(?=$|[\s.,;:(])'

    $stageRows = [System.Collections.Generic.List[object]]::new()
    $statusLines = $statusText -split "`r?`n"
    $insideStageTable = $false
    $section = ''
    $tableIndex = -1
    $activeTableIndex = -1
    $firstTableIndex = -1
    foreach ($line in $statusLines) {
        if ($line -match '^##\s+(?<heading>[^#].*?)\s*$') {
            $section = $Matches['heading']
        }
        if ($line -match '^\s*\|\s*Stage\s*\|\s*Disposition\s*\|\s*Status\s*\|') {
            $insideStageTable = $true
            $tableIndex++
            if ($firstTableIndex -lt 0) { $firstTableIndex = $tableIndex }
            if ($activeTableIndex -lt 0 -and $section -match '^Active Cycle\b') { $activeTableIndex = $tableIndex }
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
        $leading = [regex]::Match($cells[2], $leadingStatusPattern)
        if ($leading.Success) { $leadingStatus = $leading.Groups['status'].Value } else { $leadingStatus = $null }
        $stageRows.Add([pscustomobject]@{ Stage = $cells[0]; Disposition = $cells[1]; Status = $leadingStatus; Cell = $cells[2]; Artifact = $artifact; Table = $tableIndex })
    }
    # The active stage table is the first one under "## Active Cycle", or else the first in the file.
    # Later tables are records of finished workflows and cycles, which earlier workflow versions wrote
    # in other words; they are reported, not failed.
    if ($activeTableIndex -lt 0) { $activeTableIndex = $firstTableIndex }

    foreach ($row in $stageRows) {
        if ($row.Disposition -eq 'Not Applicable') {
            # A stage the workflow does not run needs no status.
        } elseif ($null -eq $row.Status) {
            if ($row.Table -eq $activeTableIndex) {
                Add-ValidationError "Unsupported stage status '$($row.Cell)' for '$($row.Stage)' in project-status.md: the cell must start with one of $($workflowStageStatuses -join ', ')."
            } else {
                Add-ValidationWarning "Stage record '$($row.Stage)' in an earlier stage table of project-status.md does not start with an exact status: '$($row.Cell)'."
            }
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
    $activeStages = @($stageRows | Where-Object { $_.Table -eq $activeTableIndex -and $_.Status -eq 'In Progress' })
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
# An issue id is a prefix and three digits: IMP-001 in Initial Development, CYC7-001 and the like in a change cycle.
$issueIdPattern = '[A-Z][A-Z0-9]*-\d{3}'
# An issue's status line may go on after the status with its date and a note: "Done, 2026-11-04. The campaign passed".
$leadingIssueStatusPattern = '^(?<status>' + (($issueStatuses | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')(?=$|[\s.,;:(])'
$issueFiles = @(Get-ChildItem -LiteralPath $documentationRoot -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue | Where-Object { $_.Directory.Name -eq 'issues' })
$issueRecords = [System.Collections.Generic.List[object]]::new()
foreach ($file in $issueFiles) {
    $idMatch = [regex]::Match($file.BaseName, "^(?<id>$issueIdPattern)(?:-|$)")
    if (-not $idMatch.Success) { continue }
    $status = Get-IssueStatus $file.FullName
    $leadingStatus = [regex]::Match([string]$status, $leadingIssueStatusPattern)
    if ($leadingStatus.Success) { $status = $leadingStatus.Groups['status'].Value }
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

# Every Done issue whose Evidence Pack section applies must name at least one pack folder that exists and whose
# manifest still matches the hash recorded beside it. The pack tool writes manifest.sha256 as "<hex>  manifest.json".
foreach ($record in ($issueRecords | Where-Object { $_.Status -eq 'Done' })) {
    $issueText = Get-Content -Raw -LiteralPath $record.Path
    $packSection = [regex]::Match($issueText, '(?ms)^## Evidence Pack\s*$(?<body>.*?)(?=^## |\z)')
    if (-not $packSection.Success) { continue }
    if ($packSection.Groups['body'].Value -notmatch 'Applies:\s*\*{0,2}Yes') { continue }
    # A planned name such as campaign-a-<commit> is a placeholder, not a path; the lookahead skips names that run into a '<'.
    $packPaths = @([regex]::Matches($issueText, '(?<path>workspace[/\\]validation[/\\]campaigns[/\\][A-Za-z0-9._-]+)(?![A-Za-z0-9._-]*<)') | ForEach-Object { $_.Groups['path'].Value } | Sort-Object -Unique)
    if ($packPaths.Count -eq 0) {
        Add-ValidationWarning "Done issue $($record.Id) says its evidence pack applies but names no pack folder under workspace/validation/campaigns: $($record.Path)"
        continue
    }
    foreach ($packPath in $packPaths) {
        $packDirectory = Resolve-ProcessPath $packPath
        if (-not (Test-Path -LiteralPath $packDirectory -PathType Container)) {
            Add-ValidationError "Done issue $($record.Id) names an evidence pack folder that does not exist: $packPath"
            continue
        }
        $manifest = Join-Path $packDirectory 'manifest.json'
        if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
            Add-ValidationError "Evidence pack named by $($record.Id) has no manifest.json: $packPath"
            continue
        }
        $recordedHashFile = Join-Path $packDirectory 'manifest.sha256'
        if (Test-Path -LiteralPath $recordedHashFile -PathType Leaf) {
            $recorded = ([regex]::Match((Get-Content -Raw -LiteralPath $recordedHashFile), '[A-Fa-f0-9]{64}')).Value
            $actual = (Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash
            if ($recorded -and $recorded.ToUpperInvariant() -ne $actual.ToUpperInvariant()) {
                Add-ValidationError "Evidence pack named by $($record.Id) has a manifest that no longer matches its recorded hash: $packPath"
            }
        }
    }
}

$rollupLines = [System.Collections.Generic.List[string]]::new()
foreach ($group in ($issueRecords | Group-Object Scope | Sort-Object Name)) {
    $summary = (@($group.Group | Sort-Object Id | ForEach-Object { "$($_.Id) $($_.Status)" })) -join ', '
    $rollupLines.Add("$($group.Name): $summary")
}

$planFiles = @(Get-ChildItem -LiteralPath $documentationRoot -Recurse -File -Filter 'implementation-plan.md' -ErrorAction SilentlyContinue)
foreach ($plan in $planFiles) {
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $plan.FullName) {
        $lineNumber++
        if ($line -notmatch "^\s*\|\s*(?<id>$issueIdPattern)\s*\|") { continue }
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
            foreach ($match in [regex]::Matches($statusText, "(?m)^\s*-\s*(?<id>$issueIdPattern)\b[^\r\n]*?\*\*(?<status>Backlog|Ready|In Progress|Awaiting Validation|Review|Blocked|Done|Deferred)\*\*")) {
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
        $idMatch = [regex]::Match($currentIssue, $issueIdPattern)
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

# Before its results file exists, a session map holds a criterion-to-card table: a Markdown table whose header names
# a criterion, so every acceptance criterion is mapped to a card, a waiver, or an accepted limitation before the
# first launch. Maps of finished campaigns, whose results file exists, are not checked for it.
$criterionTablePattern = '(?mi)^\|[^\r\n]*criteri[^\r\n]*\|[ \t]*\r?\n\|[ \t:]*-{3,}'
function Test-CriterionTable([string]$mapName, [string]$mapText) {
    if ($mapText -notmatch $criterionTablePattern) {
        Add-ValidationError "Session map ${mapName}: no criterion-to-card table before the campaign; map every acceptance criterion and verification bullet of the included issues to a card, a recorded waiver, or an owner-accepted limitation (guidelines/manual-validation.md, Before The Session)."
    }
}

# Every card of a campaign session map has a line in that campaign's results file once the results file exists.
# A card that was deferred or not run still gets a line saying so; a card with no line was silently lost.
# A session map anywhere under the documentation names its results file on a "Results file:" line, and starts
# each card with a bold identifier ("1. **G1 Create.**") that the results file repeats.
$checkedMaps = 0
$mapsWithoutResults = 0
foreach ($sessionMap in @(Get-ChildItem -LiteralPath $documentationRoot -Recurse -File -Filter '*session-map.md' -ErrorAction SilentlyContinue)) {
    $mapText = Get-Content -Raw -LiteralPath $sessionMap.FullName
    $link = [regex]::Match($mapText, '(?m)^\s*Results file:\s*`?(?<path>[^`\r\n]+?)`?\s*$')
    if (-not $link.Success) {
        $mapsWithoutResults++
        continue
    }
    $resultsPath = Resolve-ProcessPath $link.Groups['path'].Value
    if (-not (Test-Path -LiteralPath $resultsPath -PathType Leaf)) {
        Test-CriterionTable $sessionMap.Name $mapText
        continue
    }
    $checkedMaps++
    $resultsText = Get-Content -Raw -LiteralPath $resultsPath
    foreach ($card in @([regex]::Matches($mapText, '(?m)^\d+[a-z]?\.\s+\*\*(?<id>[A-Z]+\d+[a-z]?)\b') | ForEach-Object { $_.Groups['id'].Value } | Sort-Object -Unique)) {
        if ($resultsText -notmatch ('(?<![A-Za-z0-9])' + [regex]::Escape($card) + '(?![A-Za-z0-9])')) {
            Add-ValidationError "Session map $($sessionMap.Name): card $card has no line in $($link.Groups['path'].Value); record it as passed, failed, deferred, or not run."
        }
    }
}
if ($mapsWithoutResults -gt 0) {
    Add-ValidationWarning "$mapsWithoutResults session map(s) under the documentation name no 'Results file:'; their cards were not checked."
}
$campaignWorkRoot = Join-Path $WorkspaceRoot 'validation/work'
if (Test-Path -LiteralPath $campaignWorkRoot -PathType Container) {
    foreach ($campaignDirectory in Get-ChildItem -LiteralPath $campaignWorkRoot -Directory) {
        $sessionMap = Get-ChildItem -LiteralPath $campaignDirectory.FullName -File -Filter '*-session-map.md' | Select-Object -First 1
        $resultsFile = Get-ChildItem -LiteralPath $campaignDirectory.FullName -File -Filter '*-results.md' | Select-Object -First 1
        if ($null -ne $sessionMap -and $null -eq $resultsFile) {
            Test-CriterionTable $sessionMap.Name (Get-Content -Raw -LiteralPath $sessionMap.FullName)
            continue
        }
        if ($null -eq $sessionMap -or $null -eq $resultsFile) { continue }
        $checkedMaps++
        $mapCards = @([regex]::Matches((Get-Content -Raw -LiteralPath $sessionMap.FullName), '(?m)^(?<card>\d+[a-z]?)\. ') | ForEach-Object { $_.Groups['card'].Value } | Sort-Object -Unique)
        $resultCards = @([regex]::Matches((Get-Content -Raw -LiteralPath $resultsFile.FullName), '(?m)^(?<card>\d+[a-z]?)\. ') | ForEach-Object { $_.Groups['card'].Value } | Sort-Object -Unique)
        foreach ($card in $mapCards) {
            if ($resultCards -notcontains $card) {
                Add-ValidationError "Campaign $($campaignDirectory.Name): card $card of $($sessionMap.Name) has no line in $($resultsFile.Name); record it as passed, failed, deferred, or not run."
            }
        }
    }
}

if ($rollupLines.Count -gt 0) {
    Write-Host 'Issue status roll-up (read from the issue files, the only place a status is written):' -ForegroundColor Cyan
    foreach ($line in $rollupLines) {
        Write-Host "- $line" -ForegroundColor Cyan
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

if ($checkedMaps -eq 0) { $campaignNote = 'no session map with a results file was found, so no campaign cards were checked' } else { $campaignNote = "campaign results covering every card of $checkedMaps session map(s)" }
Write-Host "Workspace validation passed: workflow/stage statuses, issue statuses, active-item counts, structured paths, plan/issue agreement, evidence packs of Done issues, $campaignNote, and resume references are mechanically consistent." -ForegroundColor Green

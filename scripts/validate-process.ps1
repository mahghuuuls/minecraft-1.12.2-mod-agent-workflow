param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

function Add-Error([string]$message) {
    $script:errors.Add($message)
}

$requiredPaths = @(
    'AGENTS.md',
    'guidelines/process-control.md',
    'guidelines/collaboration-guidelines.md',
    'guidelines/project-defaults.md',
    'workflows/initial-development.md',
    'workflows/existing-mod-assessment.md',
    'workflows/change-cycle.md',
    'workflows/process-maintenance.md',
    'procedures/revalidate-release.md',
    'stages/0-project-setup.md',
    'stages/1-concept-and-scope.md',
    'stages/2-feasibility-research.md',
    'stages/3-requirements-definition.md',
    'stages/4-architecture-definition.md',
    'stages/5-initialization.md',
    'stages/6-implementation-plan.md',
    'stages/7-implementation.md',
    'stages/8-release-presentation.md'
)

foreach ($relativePath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath))) {
        Add-Error "Missing required process file: $relativePath"
    }
}

$templateOwners = [ordered]@{
    'setup/artifact-templates/project-setup.md' = 'stages/0-project-setup.md'
    'setup/artifact-templates/concept-and-scope.md' = 'stages/1-concept-and-scope.md'
    'setup/artifact-templates/feasibility-research.md' = 'stages/2-feasibility-research.md'
    'setup/artifact-templates/requirements.md' = 'stages/3-requirements-definition.md'
    'setup/artifact-templates/architecture.md' = 'stages/4-architecture-definition.md'
    'setup/artifact-templates/project-initialization.md' = 'setup/initialize-project.md'
    'setup/artifact-templates/implementation-plan.md' = 'stages/6-implementation-plan.md'
    'setup/artifact-templates/release-presentation.md' = 'stages/8-release-presentation.md'
    'setup/artifact-templates/release-handoff.md' = 'stages/8-release-presentation.md'
    'setup/artifact-templates/project-baseline.md' = 'workflows/initial-development.md'
    'setup/artifact-templates/change-intake.md' = 'workflows/change-cycle.md'
    'setup/artifact-templates/cycle-summary.md' = 'workflows/change-cycle.md'
    'setup/artifact-templates/project-state.md' = 'guidelines/process-control.md'
    'setup/artifact-templates/dependency-references.md' = 'guidelines/process-control.md'
    'setup/glossary-template.md' = 'guidelines/process-control.md'
    'setup/workflow-feedback-template.md' = 'guidelines/process-control.md'
}

foreach ($entry in $templateOwners.GetEnumerator()) {
    $templatePath = Join-Path $root $entry.Key
    $ownerPath = Join-Path $root $entry.Value
    if (-not (Test-Path -LiteralPath $templatePath)) {
        Add-Error "Missing artifact template: $($entry.Key)"
        continue
    }
    if (-not (Test-Path -LiteralPath $ownerPath)) {
        Add-Error "Missing template owner: $($entry.Value)"
        continue
    }
    $ownerText = Get-Content -Raw -LiteralPath $ownerPath
    if (-not $ownerText.Contains($entry.Key)) {
        Add-Error "Template owner $($entry.Value) does not reference $($entry.Key)"
    }
}

$requiredTemplateHeadings = [ordered]@{
    'setup/artifact-templates/project-setup.md' = @('Scenario', 'Public Copy Preferences', 'Git Workflow Preferences', 'Configuration Written', 'Workflow Feedback Log', 'Release And Publication Ownership', 'Validation Ownership', 'Owner Approvals')
    'setup/artifact-templates/requirements.md' = @('Purpose And Scope', 'Referenced Documents', 'Actors And Usage Context', 'Requirement Traceability', 'Glossary Updates', 'Unresolved Non-Blocking Questions')
    'setup/artifact-templates/project-initialization.md' = @('Project Identity Freeze', 'Template Source', 'Final Repository', 'Owner-Side Git Access Check')
    'setup/artifact-templates/implementation-plan.md' = @('Implementation Strategy', 'Vertical Slice Overview', 'Issue Summary', 'Verification Strategy', 'Verification Environment Plan', 'Manual Validation Decisions', 'Definition Of Done', 'Manual Observability')
    'setup/artifact-templates/release-handoff.md' = @('Release Identity', 'Source Revision And Repository State', 'Artifact', 'Checks Performed', 'Owner-Managed Publication Steps', 'Owner Approvals')
    'setup/artifact-templates/release-presentation.md' = @('Public Copy Preferences', 'README', 'Mod Page Or Distribution-Page Copy', 'Changelog', 'Release Handoff', 'Owner Approvals')
    'setup/artifact-templates/project-baseline.md' = @('Baseline Identity', 'Supported Environment', 'Canonical Documents', 'Build And Verification', 'Known Limitations', 'Approval')
}

$requiredProcessText = [ordered]@{
    'stages/0-project-setup.md' = @('workspace/documentation/workflow-feedback.md')
    'setup/initialize-project.md' = @('## Freeze Project Identity', '## Verify Owner-Side Git Access')
    'stages/6-implementation-plan.md' = @('## Verification Environment Plan', '**Test now:**', '**Defer:**', '**Waive:**')
    'stages/7-implementation.md' = @('## Validation Environment Tiers', '## Generated Artifact Inspection', '## Small Follow-Up Path')
    'stages/8-release-presentation.md' = @('https://github.com/mahghuuuls/minecraft-1.12.2-mod-agent-workflow', 'authoritative records for the current release artifact checksum')
    'setup/workflow-feedback-template.md' = @('## End Of Workflow Retrospective')
}

foreach ($entry in $requiredProcessText.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $text = Get-Content -Raw -LiteralPath $path
    foreach ($requiredText in $entry.Value) {
        if (-not $text.Contains($requiredText)) {
            Add-Error "Process file $($entry.Key) is missing required text: $requiredText"
        }
    }
}

foreach ($entry in $requiredTemplateHeadings.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $headings = @(Select-String -LiteralPath $path -Pattern '^#{1,6}\s+(.+)$' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() })
    foreach ($heading in $entry.Value) {
        if ($headings -notcontains $heading) {
            Add-Error "Template $($entry.Key) is missing heading: $heading"
        }
    }
}

$processDirectories = @('guidelines', 'workflows', 'stages', 'procedures', 'setup', 'references')
$markdownFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
$markdownFiles.Add((Get-Item -LiteralPath (Join-Path $root 'AGENTS.md')))
$markdownFiles.Add((Get-Item -LiteralPath (Join-Path $root 'README.md')))
foreach ($directory in $processDirectories) {
    $path = Join-Path $root $directory
    if (Test-Path -LiteralPath $path) {
        Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.md' | ForEach-Object { $markdownFiles.Add($_) }
    }
}

$retiredPatterns = @('stages/9-packaging-release-validation.md', 'Stage 9', 'Packaging and Release Validation')
foreach ($file in $markdownFiles) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    $relative = $file.FullName.Substring($root.Length).TrimStart([char[]]'\/').Replace('\', '/')
    foreach ($pattern in $retiredPatterns) {
        if ($text.Contains($pattern)) {
            Add-Error "Retired Stage 9 reference in ${relative}: $pattern"
        }
    }

    foreach ($match in [regex]::Matches($text, '`((?:guidelines|workflows|stages|procedures|setup|references)/[^`<>*]+\.md)`')) {
        $reference = $match.Groups[1].Value
        if (-not (Test-Path -LiteralPath (Join-Path $root $reference))) {
            Add-Error "Missing static Markdown reference in ${relative}: $reference"
        }
    }

    $run = [System.Collections.Generic.List[int]]::new()
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNumber++
        if ($line -match '^(\d+)\.\s+') {
            $run.Add([int]$Matches[1])
            continue
        }
        if ($run.Count -gt 1) {
            for ($index = 0; $index -lt $run.Count; $index++) {
                $expected = $run[0] + $index
                if ($run[$index] -ne $expected) {
                    Add-Error "Non-sequential numbered list in ${relative} near line $lineNumber (expected $expected, found $($run[$index]))"
                    break
                }
            }
        }
        $run.Clear()
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Process validation failed with $($errors.Count) error(s):" -ForegroundColor Red
    foreach ($errorMessage in $errors) {
        Write-Host "- $errorMessage" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Process validation passed: required files, template ownership, headings, references, retired-stage checks, and numbered lists are consistent." -ForegroundColor Green

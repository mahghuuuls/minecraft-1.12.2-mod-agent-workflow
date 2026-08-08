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
    'guidelines/agent-diagnostics-toolkit.md',
    'guidelines/coding-standards.md',
    'guidelines/manual-validation.md',
    'guidelines/project-defaults.md',
    'workflows/initial-development.md',
    'workflows/existing-mod-assessment.md',
    'workflows/change-cycle.md',
    'workflows/process-maintenance.md',
    'procedures/revalidate-release.md',
    'scripts/validate-workspace.ps1',
    'scripts/test-validate-workspace.ps1',
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
    'setup/agent-diagnostics-toolkit-feedback-template.md' = 'guidelines/agent-diagnostics-toolkit.md'
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
    'setup/artifact-templates/project-setup.md' = @('Scenario', 'Public Copy Preferences', 'Git Workflow Preferences', 'Configuration Written', 'Workflow Feedback Log', 'Agent Diagnostics Toolkit', 'Release And Publication Ownership', 'Validation Ownership', 'Owner Approvals')
    'setup/artifact-templates/requirements.md' = @('Purpose And Scope', 'Referenced Documents', 'Actors And Usage Context', 'Requirement Traceability', 'Glossary Updates', 'Unresolved Non-Blocking Questions')
    'setup/artifact-templates/feasibility-research.md' = @('Feature Feasibility', 'Dependencies And Integrations', 'Development Diagnostics Feasibility', 'Evidence And References')
    'setup/artifact-templates/architecture.md' = @('Components And Responsibilities', 'Dependency Rules', 'Complexity Management', 'Architectural Decisions And Trade-Offs')
    'setup/artifact-templates/project-initialization.md' = @('Project Identity Freeze', 'Template Source', 'Final Repository', 'Owner-Side Git Access Check', 'Development Diagnostic Tooling')
    'setup/artifact-templates/implementation-plan.md' = @('Implementation Strategy', 'Vertical Slice Overview', 'Issue Summary', 'Verification Strategy', 'Agent Diagnostics Toolkit Plan', 'Verification Environment Plan', 'Manual Validation Decisions', 'Owner-Assisted Validation Campaigns', 'Definition Of Done', 'Manual Observability', 'Complexity Management')
    'setup/artifact-templates/release-handoff.md' = @('Release Identity', 'Source Revision And Repository State', 'Artifact', 'Checks Performed', 'Owner-Managed Publication Steps', 'Owner Approvals')
    'setup/artifact-templates/release-presentation.md' = @('Public Copy Preferences', 'README', 'Mod Page Or Distribution-Page Copy', 'Changelog', 'Release Handoff', 'Development Diagnostics Feedback', 'Owner Approvals')
    'setup/artifact-templates/project-baseline.md' = @('Baseline Identity', 'Supported Environment', 'Canonical Documents', 'Build And Verification', 'Known Limitations', 'Approval')
}

$requiredProcessText = [ordered]@{
    'guidelines/collaboration-guidelines.md' = @('inspect the configured Git author name and email')
    'guidelines/coding-standards.md' = @('## Complexity Management', 'deep modules', 'information leakage')
    'stages/0-project-setup.md' = @('workspace/documentation/workflow-feedback.md', 'workspace/documentation/agent-diagnostics-toolkit-feedback.md')
    'setup/initialize-project.md' = @('## Freeze Project Identity', '## Verify Owner-Side Git Access')
    'stages/4-architecture-definition.md' = @('**Complexity Analysis:**', 'meaningfully different designs', 'authoritative owner')
    'stages/6-implementation-plan.md' = @('## Verification Environment Plan', '**Test now:**', '**Defer:**', '**Waive:**', '## Complexity Management')
    'stages/7-implementation.md' = @('## Validation Environment Tiers', '## Generated Artifact Inspection', '## Small Follow-Up Path', '**Complexity argument**')
    'stages/8-release-presentation.md' = @('https://github.com/mahghuuuls/minecraft-1.12.2-mod-agent-workflow', 'authoritative records for the current release artifact checksum')
    'setup/workflow-feedback-template.md' = @('## End Of Workflow Retrospective')
    'guidelines/agent-diagnostics-toolkit.md' = @('development-runtime only', 'Do not clone the toolkit repository into every mod project', 'setup/agent-diagnostics-toolkit-feedback-template.md')
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

$portabilityFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($file in $markdownFiles) {
    $portabilityFiles.Add($file)
}
Get-ChildItem -LiteralPath (Join-Path $root 'setup') -Recurse -File -Filter '*.properties' | ForEach-Object { $portabilityFiles.Add($_) }

$prohibitedPortabilityPatterns = [ordered]@{
    'Owner-specific GitHub username used as a project value' = '(?im)^\s*github_username\s*=\s*mahghuuuls\s*$'
    'Owner-specific Java package used as a project value' = '(?im)^\s*root_package\s*=\s*com\.mahghuuuls(?:\.|$)'
    'Prior project identity' = '(?i)\b(?:leftclickvacation|periodic[-_ ]mob[-_ ]drops|damagerecap|wizardry[-_ ]spell[-_ ]tweaker)\b'
    'Owner local Windows user path' = '(?i)[A-Za-z]:[\\/]+Users[\\/]+(?:arthurcrs|ARTHUR~1)(?:[\\/]|$)'
    'Codex attachment path' = '(?i)\.codex[\\/]attachments[\\/]'
    'Personal email address' = '(?i)arthcrs@gmail\.com'
}

foreach ($file in $portabilityFiles) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    $relative = $file.FullName.Substring($root.Length).TrimStart([char[]]'\/').Replace('\', '/')
    foreach ($entry in $prohibitedPortabilityPatterns.GetEnumerator()) {
        if ($text -match $entry.Value) {
            Add-Error "$($entry.Key) found in versioned process content: $relative"
        }
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

# Every stage must name at least one guideline. A stage that routes nowhere leaves the agent
# executing it with no path to the rules it is meant to follow, which is how coding-standards.md
# came to be reachable only from AGENTS.md while governing all of Implementation.
$stageFiles = Get-ChildItem -LiteralPath (Join-Path $root 'stages') -File -Filter '*.md' | Sort-Object Name
$referencedGuidelines = [System.Collections.Generic.HashSet[string]]::new()
foreach ($file in $stageFiles) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    $matched = [regex]::Matches($text, 'guidelines/([a-z0-9-]+\.md)')
    if ($matched.Count -eq 0) {
        Add-Error "Stage stages/$($file.Name) references no guideline. Name the guidelines it depends on."
    }
    foreach ($match in $matched) {
        [void]$referencedGuidelines.Add($match.Groups[1].Value)
    }
}

foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $root 'workflows') -File -Filter '*.md')) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    foreach ($match in [regex]::Matches($text, 'guidelines/([a-z0-9-]+\.md)')) {
        [void]$referencedGuidelines.Add($match.Groups[1].Value)
    }
}

# Guidelines that are session-level rather than stage-scoped, and so are legitimately reached
# from AGENTS.md alone. Adding a file here is a deliberate statement that no stage owns it.
$sessionLevelGuidelines = @('workflow-glossary.md')

foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $root 'guidelines') -File -Filter '*.md')) {
    if ($sessionLevelGuidelines -contains $file.Name) { continue }
    if (-not $referencedGuidelines.Contains($file.Name)) {
        Add-Error "Guideline guidelines/$($file.Name) is referenced by no stage or workflow. Route it, or list it as session-level in validate-process.ps1."
    }
}

# A marked canonical copy must still match its source. Without this, a repeated rule silently
# becomes a second and weaker version of itself, which is the failure this marker exists to catch.
foreach ($file in $markdownFiles) {
    $relative = $file.FullName.Substring($root.Length).TrimStart([char[]]'\/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $file.FullName
    $canonicalTarget = $null
    $blockStartLine = 0
    $lineNumber = 0
    $inFence = $false
    foreach ($line in $lines) {
        $lineNumber++
        # A fenced block documents the mechanism rather than using it, so markers inside one
        # are examples and must not be validated as live copies.
        if ($line -match '^\s*```') {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) { continue }
        if ($line -match '^<!--\s*canonical-copy:\s*(\S+?)\s*-->$') {
            $canonicalTarget = $Matches[1]
            $blockStartLine = $lineNumber
            continue
        }
        if ($line -match '^<!--\s*end-canonical-copy\s*-->$') {
            if ($null -eq $canonicalTarget) {
                Add-Error "Unopened end-canonical-copy in ${relative} at line $lineNumber"
            }
            $canonicalTarget = $null
            continue
        }
        if ($null -eq $canonicalTarget) { continue }
        if ($line -notmatch '^- ') { continue }

        $targetParts = $canonicalTarget.Split('#')
        $targetPath = Join-Path $root $targetParts[0]
        if (-not (Test-Path -LiteralPath $targetPath)) {
            Add-Error "Canonical copy in ${relative} points at a missing file: $($targetParts[0])"
            continue
        }
        $targetText = Get-Content -Raw -LiteralPath $targetPath
        if (-not $targetText.Contains($line)) {
            Add-Error "Canonical copy in ${relative} line ${lineNumber} does not match $($targetParts[0]): $line"
        }
    }
    if ($null -ne $canonicalTarget) {
        Add-Error "Unclosed canonical-copy block in ${relative} opened at line $blockStartLine"
    }
}

# House style. Enforced by hand until now, which did not hold.
# -Encoding UTF8 is required, not cosmetic. Windows PowerShell defaults to the ANSI codepage for
# a file with no BOM, which decodes the em dash bytes as three separate characters and makes this
# check silently incapable of failing.
foreach ($file in $markdownFiles) {
    $relative = $file.FullName.Substring($root.Length).TrimStart([char[]]'\/').Replace('\', '/')
    $lineNumber = 0
    foreach ($line in (Get-Content -LiteralPath $file.FullName -Encoding UTF8)) {
        $lineNumber++
        if ($line.Contains([char]0x2014)) {
            Add-Error "Em dash in versioned process prose: ${relative} line $lineNumber"
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Process validation failed with $($errors.Count) error(s):" -ForegroundColor Red
    foreach ($errorMessage in $errors) {
        Write-Host "- $errorMessage" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Process validation passed: required files, template ownership, headings, references, portability checks, retired-stage checks, numbered lists, stage routing, guideline coverage, canonical copies, and house style are consistent." -ForegroundColor Green

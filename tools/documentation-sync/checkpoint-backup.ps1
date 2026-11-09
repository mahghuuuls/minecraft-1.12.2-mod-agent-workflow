#Requires -Version 7.4
using namespace System.IO

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Workspace,
    [Parameter(Mandatory)] [ValidateSet('checkpoint', 'handoff', 'resume')] [string]$Trigger,
    [string]$OwnerDefaults,
    [string]$ProjectId,
    [scriptblock]$ReadGitHubMetadata
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Assert-PlainDirectory([string]$Path) {
    for ($directory = [DirectoryInfo]::new($Path); $null -ne $directory; $directory = $directory.Parent) {
        $attributes = [File]::GetAttributes($directory.FullName)
        if (-not ($attributes -band [FileAttributes]::Directory) -or ($attributes -band [FileAttributes]::ReparsePoint)) {
            throw 'Documentation backup requires ordinary workspace and configuration directories.'
        }
    }
}

function Read-LocalText([string]$Path) {
    if (-not [Path]::IsPathFullyQualified($Path) -or $Path.StartsWith('\\')) { throw 'Use an absolute local configuration path.' }
    Assert-PlainDirectory ([Path]::GetDirectoryName($Path))
    if ([File]::GetAttributes($Path) -band ([FileAttributes]::Directory -bor [FileAttributes]::ReparsePoint)) {
        throw 'Documentation backup requires ordinary configuration files.'
    }
    return [File]::ReadAllText($Path, $utf8)
}

function Read-BackupApproval([string]$Path) {
    if (-not $Path -or -not [File]::Exists($Path)) { return $null }
    $defaults = Read-LocalText $Path
    $sections = [regex]::Matches($defaults, '(?ms)^## Shared Documentation Backup[ \t]*\r?\n(?<body>.*?)(?=^## |\z)')
    if ($sections.Count -eq 0) { return $null }
    if ($sections.Count -ne 1) { throw 'Multiple documentation backup sections in owner defaults.' }
    $body = $sections[0].Groups['body'].Value
    $approval = [regex]::Matches($body, '(?im)^- Automatic sync:[ \t]*(?<value>[^\r\n]+)\r?$')
    if ($approval.Count -eq 0) { return $null }
    if ($approval.Count -ne 1) { throw 'Multiple automatic sync preferences in owner defaults.' }
    $value = $approval[0].Groups['value'].Value.Trim()
    $savedRolloutApproval = "Approved for this owner's projects once the workflow supports automatic backups. Until then, use the manual preview and approval flow."
    # Existing owner defaults can spell the rollout approval with a lowercase initial.
    if ($value -notin 'Approved', 'Approved.', $savedRolloutApproval) { return $null }

    $artwork = [regex]::Matches($body, '(?im)^- Artwork backup:[ \t]*(?<value>[^\r\n]*)\r?$')
    if ($artwork.Count -gt 1) { throw 'Multiple artwork backup preferences in owner defaults.' }
    $includeArtwork = $artwork.Count -eq 1 -and $artwork[0].Groups['value'].Value.Trim() -in 'Approved', 'Approved.'

    $destinationLines = [regex]::Matches($body, '(?im)^- Destination:[ \t]*(?<value>[^\r\n]+)\r?$')
    $pattern = '\Aprivate GitHub repository `(?<repository>[A-Za-z0-9-]+/[A-Za-z0-9_.-]+)`, repository ID `(?<id>[1-9][0-9]*)`, branch `(?<branch>[A-Za-z0-9._/-]+)`\.?\z'
    if ($destinationLines.Count -ne 1 -or $destinationLines[0].Groups['value'].Value.Trim() -cnotmatch $pattern) {
        throw 'Automatic sync approval requires one private repository name, numeric ID, and branch in owner defaults.'
    }
    return @{ Repository = $Matches.repository; RepositoryId = [long]$Matches.id; Branch = $Matches.branch; IncludeArtwork = $includeArtwork }
}

function Save-CheckpointResult($Value) {
    Assert-PlainDirectory $workspacePath
    if ([DirectoryInfo]::new($workspacePath).GetFileSystemInfos('documentation-sync').Count -eq 0) {
        [void][Directory]::CreateDirectory($stateDirectory)
    }
    Assert-PlainDirectory $stateDirectory
    $target = Join-Path $stateDirectory 'checkpoint-result.json'
    if ([DirectoryInfo]::new($stateDirectory).GetFileSystemInfos('checkpoint-result.json').Count -gt 0 -and
        ([File]::GetAttributes($target) -band ([FileAttributes]::Directory -bor [FileAttributes]::ReparsePoint))) {
        throw 'The checkpoint result path is not an ordinary file.'
    }
    $temp = Join-Path $stateDirectory ([Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [File]::WriteAllText($temp, (ConvertTo-Json -InputObject $Value -Depth 12), $utf8)
        [File]::Move($temp, $target, $true)
    }
    finally { [File]::Delete($temp) }
}

function Invoke-DocumentationBackup($Destination, [scriptblock]$Reader) {
    $arguments = @{
        Workspace = $workspacePath; Repository = $Destination.Repository; RepositoryId = $Destination.RepositoryId
        Branch = $Destination.Branch; ReadGitHubMetadata = $Reader
    }
    if ($ProjectId) { $arguments.ProjectId = $ProjectId }
    if ($Destination.IncludeArtwork) { $arguments.IncludeArtwork = $true }
    $tool = Join-Path $PSScriptRoot 'documentation-sync.ps1'
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $preview = & $tool preview @arguments | ConvertFrom-Json -AsHashtable
        if ($preview.error -or $preview.cleanupWarning -or -not $preview.approval) { return $preview }
        $result = & $tool sync @arguments -ApprovedPlan $preview.approval | ConvertFrom-Json -AsHashtable
        $result.checkpointAttempts = $attempt
        if ($result.error -notmatch '^(?:The reviewed plan is missing or stale\.|Git and GitHub metadata disagree about the branch head\.|Git advertises refs for a repository reported empty\.)') {
            return $result
        }
    }
    return $result
}

$result = @{ status = 'disabled'; trigger = $Trigger; error = $null }
$approved = $false
try {
    if (-not [Path]::IsPathFullyQualified($Workspace) -or $Workspace.StartsWith('\\')) { throw 'Use an absolute local workspace path.' }
    $workspacePath = [Path]::TrimEndingDirectorySeparator([Path]::GetFullPath($Workspace))
    if ([Path]::GetFileName($workspacePath) -ine 'workspace') { throw 'Point -Workspace at the workspace directory.' }
    Assert-PlainDirectory $workspacePath
    $stateDirectory = Join-Path $workspacePath 'documentation-sync'
    if (-not $OwnerDefaults) {
        # A shared owner-defaults file is recorded in project.properties (process-control.md#local-owner-defaults).
        $properties = Join-Path $workspacePath 'project.properties'
        if ([File]::Exists($properties)) {
            $recorded = [regex]::Matches((Read-LocalText $properties), '(?m)^owner_defaults_path=(?<path>[^\r\n]+?)[ \t]*\r?$')
            if ($recorded.Count -gt 1) { throw 'Multiple owner_defaults_path entries in project.properties.' }
            if ($recorded.Count -eq 1) { $OwnerDefaults = $recorded[0].Groups['path'].Value }
        }
    }
    if (-not $OwnerDefaults) { $OwnerDefaults = Join-Path $workspacePath 'documentation/owner-defaults.md' }
    $destination = Read-BackupApproval $OwnerDefaults
    # Name the file that was read, so a disabled result from the wrong file is visible.
    if (-not $destination) { $result.ownerDefaults = $OwnerDefaults }
    if ($destination) {
        $approved = $true
        Save-CheckpointResult @{ status = 'pending'; trigger = $Trigger; error = 'Checkpoint backup has not finished.' }
        if (-not $ProjectId -and -not [File]::Exists((Join-Path $stateDirectory 'state.json'))) {
            $properties = Join-Path $workspacePath 'project.properties'
            if ([File]::Exists($properties)) {
                $ids = [regex]::Matches((Read-LocalText $properties), '(?m)^documentation_project_id=(?<id>[a-z0-9][a-z0-9_-]{0,62})\r?$')
                if ($ids.Count -eq 1) { $ProjectId = $ids[0].Groups['id'].Value }
            }
            if (-not $ProjectId) { throw 'Set the stable documentation project ID before the first checkpoint backup.' }
        }
        if (-not $ReadGitHubMetadata) {
            Import-Module (Join-Path $PSScriptRoot 'github-preflight.psm1')
            $ReadGitHubMetadata = New-GitHubMetadataReader
        }
        $result = Invoke-DocumentationBackup $destination $ReadGitHubMetadata
        if ($result.error -or $result.cleanupWarning -or $result.status -eq 'preview') { $result.status = 'pending' }
    }
}
catch { $result = @{ status = 'pending'; error = $_.Exception.Message } }
$result.trigger = $Trigger
if ($approved) {
    try { Save-CheckpointResult $result }
    catch {
        $result.status = 'pending'
        $result.checkpointStateWarning = 'Could not record the checkpoint result locally.'
    }
}
ConvertTo-Json -InputObject $result -Depth 12
if ($result.status -eq 'pending') { exit 2 }
exit 0

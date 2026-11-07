#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'documentation-sync.ps1'
$workflowRoot = [DirectoryInfo]::new($PSScriptRoot).Parent.Parent.Parent.FullName
$git = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$utf8 = [Text.UTF8Encoding]::new($false)
$png = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aC1sAAAAASUVORK5CYII=')
$tempParent = [Path]::TrimEndingDirectorySeparator([Path]::GetFullPath([Path]::GetTempPath()))
$testRoot = Join-Path $tempParent ('documentation-sync-tests-' + [Guid]::NewGuid().ToString('N'))
$testCount = 0

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -cne $Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-Test([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:testCount++
    Write-Host "PASS $Name"
}

function Invoke-FixtureGit([string[]]$Arguments) {
    $output = & $git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Fixture Git failed: $($output -join "`n")" }
    return $output
}

function New-Workspace([string]$Name) {
    $workspace = Join-Path $testRoot "$Name/workspace"
    [void][Directory]::CreateDirectory((Join-Path $workspace 'documentation'))
    return $workspace
}

function New-Destination([string]$Name) {
    $destination = Join-Path $testRoot "$Name.git"
    [void](Invoke-FixtureGit @('init', '--bare', '--initial-branch=main', '--template=', '--', $destination))
    return $destination
}

function Write-Document([string]$Workspace, [string]$Path, [string]$Content) {
    $file = Join-Path $Workspace "documentation/$Path"
    [void][Directory]::CreateDirectory([Path]::GetDirectoryName($file))
    [File]::WriteAllText($file, $Content, $utf8)
}

function Write-Artwork([string]$Workspace, [string]$Path, [byte[]]$Bytes) {
    $file = Join-Path $Workspace "artwork/$Path"
    [void][Directory]::CreateDirectory([Path]::GetDirectoryName($file))
    [File]::WriteAllBytes($file, $Bytes)
    return $file
}

function Set-ArtworkManifest([string]$Workspace, [string[]]$Paths) {
    $files = @($Paths | ForEach-Object {
        @{ path = $_; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Workspace "artwork/$_")).Hash }
    })
    $manifest = ConvertTo-Json -InputObject @{ schemaVersion = 1; files = $files } -Depth 4
    [File]::WriteAllText((Join-Path $Workspace 'artwork/backup-manifest.json'), $manifest, $utf8)
}

function Get-State([string]$Workspace) {
    return Get-Content -Raw -LiteralPath (Join-Path $Workspace 'documentation-sync/state.json') | ConvertFrom-Json -AsHashtable
}

function Read-Remote([string]$Destination, [string]$Path, [string]$Revision = 'main') {
    return (Invoke-FixtureGit @("--git-dir=$Destination", 'show', "${Revision}:$Path")) -join "`n"
}

function Get-Tip([string]$Destination) {
    return Invoke-FixtureGit @("--git-dir=$Destination", 'rev-parse', 'refs/heads/main')
}

function Get-RemotePaths([string]$Destination) {
    return Invoke-FixtureGit @("--git-dir=$Destination", 'ls-tree', '-r', '--name-only', 'main')
}

function Assert-EmptyRemote([string]$Destination) {
    $refs = @(Invoke-FixtureGit @("--git-dir=$Destination", 'for-each-ref', '--format=%(refname)'))
    Assert-Equal $refs.Count 0 'The fixture remote gained a reference.'
}

function Set-ReceiveHook([string]$Destination, [string]$Script) {
    $hook = Join-Path $Destination 'hooks/pre-receive'
    [void][Directory]::CreateDirectory([Path]::GetDirectoryName($hook))
    [File]::WriteAllText($hook, ($Script.Replace("`r`n", "`n") + "`n"), $utf8)
    if (-not $IsWindows) {
        [File]::SetUnixFileMode($hook, [UnixFileMode]'UserRead, UserWrite, UserExecute')
    }
}

function Invoke-Sync {
    param([string]$Workspace, [string]$Destination, [hashtable]$Options = @{}, [int]$ExpectExit = 0)
    $arguments = @{ Action = 'sync'; Workspace = $Workspace; Destination = $Destination }
    foreach ($key in $Options.Keys) { $arguments[$key] = $Options[$key] }
    if ($arguments.Action -eq 'sync' -and -not $arguments.ContainsKey('ApprovedPlan')) {
        $arguments.Action = 'preview'
        $preview = & $tool @arguments | ConvertFrom-Json -AsHashtable
        $arguments.Action = 'sync'
        $arguments.ApprovedPlan = $preview.approval
    }
    $output = & $tool @arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne $ExpectExit) { throw "Unexpected sync exit $exitCode (expected $ExpectExit).`n$output" }
    $result = $output | ConvertFrom-Json -AsHashtable
    Assert-True (-not $result.cleanupWarning) "Scratch cleanup failed: $($result.cleanupWarning)"
    return $result
}

function Assert-Pending($Result, [string]$Path, [string]$Reason) {
    $found = @($Result.pending | Where-Object { $_.path -ceq $Path -and $_.reason -ceq $Reason })
    Assert-Equal $found.Count 1 "Expected '$Reason' for '$Path'."
}

[void][Directory]::CreateDirectory($testRoot)
$config = Join-Path $testRoot 'empty-config'
[File]::WriteAllBytes($config, [byte[]]::new(0))
$fixtureEnvironment = @{
    GIT_CONFIG_GLOBAL = $config
    GIT_CONFIG_NOSYSTEM = '1'
    GIT_ALLOW_PROTOCOL = 'file'
    GIT_TERMINAL_PROMPT = '0'
}
$savedEnvironment = @{}
try {
    foreach ($variable in Get-ChildItem Env:) {
        if ($variable.Name -match '^GIT_') {
            $savedEnvironment[$variable.Name] = $variable.Value
            [Environment]::SetEnvironmentVariable($variable.Name, $null)
        }
    }
    foreach ($key in $fixtureEnvironment.Keys) {
        if (-not $savedEnvironment.ContainsKey($key)) { $savedEnvironment[$key] = $null }
        [Environment]::SetEnvironmentVariable($key, $fixtureEnvironment[$key])
    }
    $workflowHead = Invoke-FixtureGit @('-C', $workflowRoot, 'rev-parse', 'HEAD')
    $workflowStatus = (Invoke-FixtureGit @('-C', $workflowRoot, 'status', '--porcelain')) -join "`n"

    Invoke-Test 'shared defaults publish only reviewed root bytes and survive unrelated backups' {
        $workspace = New-Workspace 'shared defaults'
        $remote = New-Destination 'shared defaults'
        $candidate = Join-Path $workspace 'proposed.md'
        $portable = @'
# Shared Owner Defaults

## Chat Format Preferences

- Message length: Short

## Local Source

- Local owner-defaults file: `C:\Example\Mods\owner-defaults.md`
'@ + "`n"
        $options = @{ SharedOwnerDefaults = $true; OwnerDefaultsCandidate = $candidate }
        $reader = @{ SharedOwnerDefaults = $true; Action = 'read' }
        $missing = Invoke-Sync $workspace $remote $reader
        Assert-Equal $missing.status 'missing' 'An absent shared file did not use the local fallback state.'
        Assert-EmptyRemote $remote

        [File]::WriteAllText($candidate, ($portable + "`n## Shared Documentation Backup`n`n- Automatic sync: Approved.`n"), $utf8)
        $forbidden = Invoke-Sync $workspace $remote ($options + @{ Action = 'preview' }) -ExpectExit 2
        Assert-True ($forbidden.error -like '*Unsupported*') 'Shared defaults accepted a permission.'
        [File]::WriteAllText($candidate, ($portable + "`n- Instance name and path: C:\Local\Instance`n"), $utf8)
        $machine = Invoke-Sync $workspace $remote ($options + @{ Action = 'preview' }) -ExpectExit 2
        Assert-True ($machine.error -like '*Unsupported*') 'Shared defaults accepted machine configuration.'
        Assert-EmptyRemote $remote
        [File]::WriteAllText($candidate, $portable, $utf8)
        $preview = Invoke-Sync $workspace $remote ($options + @{ Action = 'preview' })
        Assert-Equal $preview.changes[0].path 'owner-defaults.md' 'Preview did not target the root file.'
        Assert-Equal $preview.proposedContent $portable 'Preview lost the exact candidate.'
        $noReceipt = Invoke-Sync $workspace $remote ($options + @{ ApprovedPlan = '' }) -ExpectExit 2
        Assert-True ($noReceipt.error -like '*receipt*') 'Root write accepted no receipt.'
        $mixed = Invoke-Sync $workspace $remote ($options + @{ Action = 'preview'; ProjectId = 'sample' }) -ExpectExit 2
        Assert-True ($mixed.error -like '*separate*') 'Shared operation accepted a project backup option.'
        Assert-EmptyRemote $remote

        Write-Document $workspace 'requirements.md' 'Ordinary project backup.'
        $project = Invoke-Sync $workspace $remote @{ ProjectId = 'sample' }
        [File]::WriteAllText($candidate, $portable.Replace('Short', 'Balanced'), $utf8)
        $changed = Invoke-Sync $workspace $remote ($options + @{ ApprovedPlan = $preview.approval }) -ExpectExit 2
        Assert-True ($changed.error -like '*stale*') 'A change to the candidate passed the receipt.'
        [File]::WriteAllText($candidate, $portable, $utf8)
        $applied = Invoke-Sync $workspace $remote ($options + @{ ApprovedPlan = $preview.approval })
        Assert-Equal $applied.status 'synced' 'An unrelated project backup invalidated the shared receipt.'
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main^')) $project.pushedRevision 'Shared commit lost a project backup.'
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'diff-tree', '--no-commit-id', '--name-only', '-r', 'main')) 'owner-defaults.md' 'Shared commit changed another path.'
        $read = Invoke-Sync $workspace $remote $reader
        Assert-Equal $read.preferences['Chat Format Preferences']['Message length'] 'Short' 'Read did not return the validated preference.'
        Assert-True (-not $read.preferences.Contains('Local Source')) 'A remote locator became a preference.'

        [File]::WriteAllText($candidate, $portable.Replace('Short', 'Detailed'), $utf8)
        $next = Invoke-Sync $workspace $remote ($options + @{ Action = 'preview' })
        $competingFile = Join-Path $workspace 'competing.md'
        [File]::WriteAllText($competingFile, $portable.Replace('Short', 'Balanced'), $utf8)
        $competing = Invoke-Sync $workspace $remote @{ SharedOwnerDefaults = $true; OwnerDefaultsCandidate = $competingFile }
        $stale = Invoke-Sync $workspace $remote ($options + @{ ApprovedPlan = $next.approval }) -ExpectExit 2
        Assert-True ($stale.error -like '*stale*') 'Another root edit did not invalidate the older receipt.'
        Assert-Equal (Get-Tip $remote) $competing.pushedRevision 'A stale receipt changed the root file.'
        Assert-Equal (Read-Remote $remote 'sample/requirements.md') 'Ordinary project backup.' 'The project content changed.'
    }

    Invoke-Test 'preview and first import before source setup, exact draft bytes, and idempotence' {
        $workspace = New-Workspace 'first import'
        $remote = New-Destination 'first import'
        $statusText = "# Documentação`r`n**In Progress**`r`n"
        Write-Document $workspace 'project-status.md' $statusText
        Write-Document $workspace 'requirements.md' '# Draft requirements'
        Write-Document $workspace 'issues/IMP-001-draft.md' '# Review'
        Write-Document $workspace 'cycles/CYCLE-001-adjust/issues/CYC1-001-draft.md' '# Draft cycle issue'
        Write-Document $workspace 'cycles/CYCLE-001-adjust/change-intake.md' '# Draft intake'

        $preview = Invoke-Sync $workspace $remote @{ Action = 'preview'; ProjectId = 'sample' }
        Assert-Equal $preview.status 'preview' 'First preview status.'
        Assert-Equal $preview.changes.Count 6 'Expected five documents and an identity manifest.'
        Assert-True (-not (Test-Path (Join-Path $workspace 'documentation-sync'))) 'Preview wrote project state.'
        Assert-EmptyRemote $remote

        $first = Invoke-Sync $workspace $remote @{ ProjectId = 'sample'; ApprovedPlan = $preview.approval }
        Assert-Equal $first.status 'synced' "First import. $($first.error)"
        Assert-Equal (Get-Tip $remote) $first.pushedRevision 'The confirmed revision does not match the destination.'
        Assert-Equal (Get-RemotePaths $remote).Count 6 'Unexpected number of remote files.'
        Assert-Equal (Read-Remote $remote 'sample/requirements.md') '# Draft requirements' 'Draft text changed.'
        $statusPath = Join-Path $workspace 'documentation/project-status.md'
        $originalBlob = Invoke-FixtureGit @('hash-object', '--no-filters', '--', $statusPath)
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main:sample/project-status.md')) $originalBlob 'Backup changed line endings or bytes.'
        Assert-Equal ([File]::ReadAllText($statusPath, $utf8)) $statusText 'Sync altered the local approval ledger.'
        Assert-True (-not (Test-Path (Join-Path $workspace 'project'))) 'Sync created a mod source checkout.'
        Assert-True (-not (Test-Path (Join-Path $workspace 'project.properties'))) 'Sync changed setup configuration.'

        $again = Invoke-Sync $workspace $remote
        Assert-Equal $again.status 'unchanged' 'Repeated import should have no changes.'
        Assert-Equal (Get-Tip $remote) $first.pushedRevision 'Repeated import produced another commit.'
        Write-Document $workspace 'project-setup.md' 'The display name is now Renamed Mod.'
        $renamed = Invoke-Sync $workspace $remote
        Assert-Equal $renamed.projectId 'sample' 'A name change moved the documentation directory.'
        Assert-Equal (Read-Remote $remote 'sample/project-setup.md') 'The display name is now Renamed Mod.' 'Renamed mod was not backed up.'
    }

    Invoke-Test 'approval binds exact bytes, paths, destination, and project directory across branch advances' {
        $workspace = New-Workspace 'approval snapshot'
        $remote = New-Destination 'approval snapshot'
        $wrong = New-Destination 'approval wrong destination'
        Write-Document $workspace 'requirements.md' 'Reviewed requirements.'
        $preview = Invoke-Sync $workspace $remote @{ Action = 'preview'; ProjectId = 'receipt' }
        $approval = @{ ProjectId = 'receipt'; ApprovedPlan = $preview.approval }
        $reviewedBlob = @($preview.changes | Where-Object { $_.path -ceq 'requirements.md' })[0].afterBlob
        Assert-Equal $reviewedBlob (Invoke-FixtureGit @('hash-object', '--no-filters', '--', (Join-Path $workspace 'documentation/requirements.md'))) 'Preview did not expose the reviewed content hash.'

        $missing = Invoke-Sync $workspace $remote @{ ProjectId = 'receipt'; ApprovedPlan = '' } -ExpectExit 2
        Assert-True ($missing.error -like '*reviewed plan*') 'A missing receipt was accepted.'
        $wrongDestination = Invoke-Sync $workspace $wrong $approval -ExpectExit 2
        Assert-True ($wrongDestination.error -like '*stale*') 'The receipt applied to another empty destination.'
        Assert-EmptyRemote $wrong

        Write-Document $workspace 'requirements.md' 'Unreviewed bytes at the same path.'
        $changedBytes = Invoke-Sync $workspace $remote $approval -ExpectExit 2
        Assert-True ($changedBytes.error -like '*stale*') 'Changed document bytes passed the receipt.'
        Assert-EmptyRemote $remote
        Write-Document $workspace 'requirements.md' 'Reviewed requirements.'
        Write-Document $workspace 'architecture.md' 'New unreviewed path.'
        $changedPaths = Invoke-Sync $workspace $remote $approval -ExpectExit 2
        Assert-True ($changedPaths.error -like '*stale*') 'A newly eligible path passed the receipt.'
        Assert-EmptyRemote $remote
        [File]::Delete((Join-Path $workspace 'documentation/architecture.md'))

        $arguments = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tool, 'sync', '-Workspace', $workspace,
            '-Destination', $remote, '-ProjectId', 'receipt', '-ApprovedPlan', $preview.approval
        )
        $applied = & pwsh @arguments | ConvertFrom-Json -AsHashtable
        Assert-Equal $LASTEXITCODE 0 "An unchanged receipt failed in another PowerShell process. $($applied.error)"
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main:receipt/requirements.md')) $reviewedBlob 'Apply did not write the reviewed blob.'

        Write-Document $workspace 'requirements.md' 'Reviewed follow-up.'
        $followUp = Invoke-Sync $workspace $remote @{ Action = 'preview' }
        $other = New-Workspace 'approval competing project'
        Write-Document $other 'project-status.md' 'Another project advances main.'
        $advance = Invoke-Sync $other $remote @{ ProjectId = 'another' }
        $changedHead = Invoke-Sync $workspace $remote @{ ApprovedPlan = $followUp.approval }
        Assert-Equal (Get-Tip $remote) $changedHead.pushedRevision 'An unrelated advance blocked the approved upload.'
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main^')) $advance.pushedRevision 'The approved upload did not preserve the competing project.'

        Write-Document $workspace 'requirements.md' 'Another local revision.'
        $beforeDirectoryChange = Invoke-Sync $workspace $remote @{ Action = 'preview' }
        $peer = New-Workspace 'approval same project'
        Write-Document $peer 'requirements.md' 'Reviewed follow-up.'
        [void](Invoke-Sync $peer $remote @{ ProjectId = 'receipt'; AdoptBindingId = (Get-State $workspace).bindingId })
        Write-Document $peer 'architecture.md' 'Unrelated file inside the same project.'
        $changedDirectory = Invoke-Sync $peer $remote
        $stale = Invoke-Sync $workspace $remote @{ ApprovedPlan = $beforeDirectoryChange.approval } -ExpectExit 2
        Assert-True ($stale.error -like '*stale*') 'A change inside the approved directory passed the receipt.'
        Assert-Equal (Get-Tip $remote) $changedDirectory.pushedRevision 'A stale receipt changed the branch.'
    }

    Invoke-Test 'first upload keeps its binding after another project creates the branch' {
        $workspace = New-Workspace 'approved first project'
        $other = New-Workspace 'approved competing first project'
        $remote = New-Destination 'approved first push race'
        Write-Document $workspace 'project-status.md' 'First approved project draft.'
        Write-Document $other 'project-status.md' 'Another project creates the branch.'
        $preview = Invoke-Sync $workspace $remote @{ Action = 'preview'; ProjectId = 'first-project' }
        $advance = Invoke-Sync $other $remote @{ ProjectId = 'other-project' }
        $applied = Invoke-Sync $workspace $remote @{ ProjectId = 'first-project'; ApprovedPlan = $preview.approval }
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main^')) $advance.pushedRevision 'First approved upload replaced the other project.'
        Assert-Equal (Get-State $workspace).bindingId $preview.approval.Split('.')[0] 'First approved upload regenerated its binding.'
        Assert-Equal (Get-Tip $remote) $applied.pushedRevision 'First approved upload did not land.'
    }

    Invoke-Test 'allowlist, credential checks, extra paths, and link boundaries' {
        $workspace = New-Workspace 'selection'
        $remote = New-Destination 'selection'
        Write-Document $workspace 'project-status.md' '# Status'
        Write-Document $workspace 'notes/design note.md' 'Persistent project notes.'
        Write-Document $workspace 'notes/generated.md' 'Unlisted content.'
        Write-Document $workspace 'owner-defaults.md' 'Private setup preferences.'
        Write-Document $workspace 'evidence/requirements.md' 'Evidence notes.'
        Write-Document $workspace 'screenshots/image.png' 'Screenshot bytes.'
        Write-Document $workspace 'latest.log' 'Log bytes.'
        Write-Document $workspace 'mod.jar' 'Build bytes.'
        Write-Document $workspace 'notes/api-key.txt' 'opaque-example-value'
        $fakeToken = 'ghp_' + ('X' * 36)
        Write-Document $workspace 'requirements.md' "Example fixture credential $fakeToken"
        Write-Document $workspace "notes/$fakeToken.md" 'Credential-like filename.'
        [File]::WriteAllBytes((Join-Path $workspace 'documentation/architecture.md'), [byte[]]@(0, 1, 2, 255))
        $outside = Join-Path $testRoot 'outside'
        [void][Directory]::CreateDirectory($outside)
        [File]::WriteAllText((Join-Path $outside 'IMP-001-outside.md'), 'Outside documentation.')
        $linkType = 'SymbolicLink'
        if ($IsWindows) { $linkType = 'Junction' }
        [void](New-Item -ItemType $linkType -Path (Join-Path $workspace 'documentation/issues') -Target $outside)

        foreach ($extra in 'owner-defaults.md', 'evidence/requirements.md', '../project-status.md', 'mod.jar', 'notes/api-key.txt') {
            $blocked = Invoke-Sync $workspace $remote @{ ProjectId = 'selection'; IncludePath = @($extra) } -ExpectExit 2
            Assert-True ($blocked.error -like '*Extra includes*') "Unsafe explicit include was accepted: $extra"
            Assert-EmptyRemote $remote
        }

        $synced = Invoke-Sync $workspace $remote @{ ProjectId = 'selection'; IncludePath = @('notes/design note.md') } -ExpectExit 2
        Assert-Pending $synced 'requirements.md' 'possible_credential'
        Assert-Pending $synced 'architecture.md' 'non_text_document'
        Assert-True (-not (($synced | ConvertTo-Json -Depth 10).Contains($fakeToken))) 'Sync output exposed the fixture credential.'
        Assert-True (-not ((Get-Content -Raw (Join-Path $workspace 'documentation-sync/state.json')).Contains($fakeToken))) 'State exposed the fixture credential.'
        Assert-True (@($synced.excluded | Where-Object { $_.path -ceq 'notes/generated.md' -and $_.reason -ceq 'outside_allowlist' }).Count -eq 1) 'Unlisted Markdown was not reported.'
        Assert-True (@($synced.excluded | Where-Object { $_.path -ceq 'issues' -and $_.reason -ceq 'link_or_reparse_point' }).Count -eq 1) 'The link was not reported.'
        Assert-Equal ((Get-RemotePaths $remote) -join '|') 'selection/.documentation-project.json|selection/notes/design note.md|selection/project-status.md' 'Unexpected content entered the backup.'
        Assert-Equal (Read-Remote $remote 'selection/notes/design note.md') 'Persistent project notes.' 'Safe explicit document missing.'
        Assert-True ([File]::Exists((Join-Path $outside 'IMP-001-outside.md'))) 'The linked document was changed.'
    }

    Invoke-Test 'opened handle rejects hard-linked data and a mismatched physical path' {
        $workspace = New-Workspace 'hard link'
        $remote = New-Destination 'hard link'
        Write-Document $workspace 'project-status.md' '# Safe status'
        $outside = Join-Path $testRoot 'outside-hardlink-sentinel.txt'
        [File]::WriteAllText($outside, 'Sentinel outside documentation.', $utf8)
        $linked = Join-Path $workspace 'documentation/glossary.md'
        [void](New-Item -ItemType HardLink -Path $linked -Target $outside)
        $synced = Invoke-Sync $workspace $remote @{ ProjectId = 'hardlink' } -ExpectExit 2
        Assert-Pending $synced 'glossary.md' 'hard_link_or_unverified_link_count'
        Assert-Equal ((Get-RemotePaths $remote) -join '|') 'hardlink/.documentation-project.json|hardlink/project-status.md' 'The external hard-link sentinel entered the backup.'
        Assert-Equal ([File]::ReadAllText($outside)) 'Sentinel outside documentation.' 'The source of the hard link was modified.'

        $localStatus = Join-Path $workspace 'documentation/project-status.md'
        $stream = [File]::OpenRead($localStatus)
        try {
            $differentPath = Join-Path $workspace 'documentation/requirements.md'
            $reason = [DocumentationSync.WindowsFile]::GetBlockReason($stream.SafeFileHandle, $differentPath)
            Assert-Equal $reason 'opened_path_mismatch' 'A handle for a different file passed the path check.'
        }
        finally { $stream.Dispose() }
    }

    Invoke-Test 'one-time extras in an existing binding require separate approval to remember' {
        $workspace = New-Workspace 'forgotten include'
        $remote = New-Destination 'forgotten include'
        $extraPath = 'notes/project decisions.md'
        Write-Document $workspace 'project-status.md' '# Status'
        Write-Document $workspace $extraPath 'Previously backed-up extra.'
        $first = Invoke-Sync $workspace $remote @{ ProjectId = 'extras'; IncludePath = @($extraPath) }
        $state = Get-State $workspace
        $state.Remove('rememberedIncludes')
        $statePath = Join-Path $workspace 'documentation-sync/state.json'
        [File]::WriteAllText($statePath, (ConvertTo-Json $state -Depth 12), $utf8)

        $other = New-Workspace 'forgotten include peer'
        Write-Document $other 'project-status.md' 'Independent remote advance.'
        $peer = Invoke-Sync $other $remote @{ ProjectId = 'peer' }
        Write-Document $workspace $extraPath 'Newer local extra.'
        $omitted = Invoke-Sync $workspace $remote -ExpectExit 2
        Assert-Pending $omitted $extraPath 'tracked_path_outside_allowlist'
        Assert-Equal $omitted.status 'pending' 'A stale excluded document was reported as current.'
        Assert-Equal $omitted.lastVerifiedRevision $peer.pushedRevision 'The remote comparison revision was not retained.'
        Assert-Equal $omitted.lastPushedRevision $first.pushedRevision 'A remote read was reported as a new backup.'
        Assert-Equal (Read-Remote $remote "extras/$extraPath") 'Previously backed-up extra.' 'Omission changed the retained remote note.'
        $restored = Invoke-Sync $workspace $remote @{ IncludePath = @($extraPath) }
        Assert-Equal $restored.status 'synced' 'Reinstating the include did not back up the note.'
        Assert-Equal (Read-Remote $remote "extras/$extraPath") 'Newer local extra.' 'The restored include still backed up stale content.'

        $oneTime = Invoke-Sync $workspace $remote @{ Action = 'preview'; IncludePath = @($extraPath) }
        $promoted = Invoke-Sync $workspace $remote @{ ApprovedPlan = $oneTime.approval; SetRememberedIncludes = @($extraPath) } -ExpectExit 2
        Assert-True ($promoted.error -like '*stale*') 'A one-time receipt could authorize future backups.'
        Assert-Equal (Get-State $workspace).rememberedIncludes.Count 0 'A stale receipt saved a recurring path.'

        $review = Invoke-Sync $workspace $remote @{ Action = 'preview'; SetRememberedIncludes = @($extraPath) }
        Assert-Equal $review.rememberedIncludes[0] $extraPath 'Preview did not show the recurring path.'
        Assert-Equal (Get-State $workspace).rememberedIncludes.Count 0 'Preview saved a recurring path.'
        $remembered = Invoke-Sync $workspace $remote @{ ApprovedPlan = $review.approval; SetRememberedIncludes = @($extraPath) }
        Assert-Equal $remembered.status 'unchanged' 'Remembering an already backed-up file should not create a commit.'
        Assert-Equal (Get-Tip $remote) $restored.pushedRevision 'Changing the remembered list created an empty commit.'
        Assert-Equal (Get-State $workspace).rememberedIncludes[0] $extraPath 'Approved recurring path was lost.'

        $unsafe = Invoke-Sync $workspace $remote @{ Action = 'preview'; SetRememberedIncludes = @('owner-defaults.md') } -ExpectExit 2
        Assert-True ($unsafe.error -like '*hard exclusions*') 'A hard-excluded path could be remembered.'
        $beforeClearing = Invoke-Sync $workspace $remote @{ Action = 'preview'; SetRememberedIncludes = @($extraPath) }
        $forgotten = Invoke-Sync $workspace $remote @{ SetRememberedIncludes = @() } -ExpectExit 2
        Assert-Pending $forgotten $extraPath 'tracked_path_outside_allowlist'
        $replayed = Invoke-Sync $workspace $remote @{ ApprovedPlan = $beforeClearing.approval; SetRememberedIncludes = @($extraPath) } -ExpectExit 2
        Assert-True ($replayed.error -like '*stale*') 'An older receipt overrode a newer remembered list.'
        Assert-Equal (Get-State $workspace).rememberedIncludes.Count 0 'Clearing the remembered list did not take effect.'
        Assert-Equal (Get-Tip $remote) $restored.pushedRevision 'Clearing the remembered list changed the backup.'
    }

    Invoke-Test 'stable bindings, cross-project isolation, and unbased import conflicts' {
        $remote = New-Destination 'bindings'
        $alpha = New-Workspace 'bindings alpha'
        $beta = New-Workspace 'bindings beta'
        Write-Document $alpha 'requirements.md' 'Alpha requirements.'
        Write-Document $beta 'requirements.md' 'Beta requirements.'
        $first = Invoke-Sync $alpha $remote @{ ProjectId = 'alpha' }
        $alphaTree = Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main:alpha')
        $second = Invoke-Sync $beta $remote @{ ProjectId = 'beta' }
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main:alpha')) $alphaTree 'Beta changed the alpha tree.'
        Assert-Equal (Read-Remote $remote 'beta/requirements.md') 'Beta requirements.' 'Beta documents missing.'
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main^')) $first.pushedRevision 'The second project did not extend history.'

        $other = New-Workspace 'bindings other'
        Write-Document $other 'requirements.md' 'Different local draft.'
        $collision = Invoke-Sync $other $remote @{ ProjectId = 'alpha' } -ExpectExit 2
        Assert-True ($collision.error -like '*verified adoption binding*') 'An unverified workspace adopted an occupied directory.'
        Assert-Equal (Get-Tip $remote) $second.pushedRevision 'A colliding ID changed history.'
        Assert-True (-not (Test-Path (Join-Path $other 'documentation-sync/state.json'))) 'A rejected adoption pinned a binding.'

        $identity = (Get-State $alpha).bindingId
        $adopted = Invoke-Sync $other $remote @{ ProjectId = 'alpha'; AdoptBindingId = $identity } -ExpectExit 2
        Assert-Pending $adopted 'requirements.md' 'no_common_base'
        Assert-Equal (Read-Remote $remote 'alpha/requirements.md') 'Alpha requirements.' 'First import overwrote an unbased remote file.'
        Assert-Equal ([File]::ReadAllText((Join-Path $other 'documentation/requirements.md'))) 'Different local draft.' 'First import overwrote a local file.'
        Assert-Equal (Get-Tip $remote) $second.pushedRevision 'A conflict-only import created a commit.'
    }

    Invoke-Test 'removed project directory retains its historical ID reservation' {
        $remote = New-Destination 'historical identity'
        $original = New-Workspace 'historical original'
        Write-Document $original 'project-status.md' 'Original project.'
        $old = Invoke-Sync $original $remote @{ ProjectId = 'reserved' }
        $emptyTree = Invoke-FixtureGit @("--git-dir=$remote", 'hash-object', '-w', '-t', 'tree', '--no-filters', '--', $config)
        $removed = Invoke-FixtureGit @(
            "--git-dir=$remote", '-c', 'user.name=Fixture', '-c', 'user.email=fixture@localhost',
            'commit-tree', $emptyTree, '-p', $old.pushedRevision, '-m', 'Remove the old project directory'
        )
        [void](Invoke-FixtureGit @("--git-dir=$remote", 'update-ref', 'refs/heads/main', $removed, $old.pushedRevision))

        $new = New-Workspace 'historical new'
        Write-Document $new 'project-status.md' 'Different project with the same ID.'
        $attempt = Invoke-Sync $new $remote @{ ProjectId = 'reserved' } -ExpectExit 2
        Assert-True ($attempt.error -like '*reserved by destination history*') 'The historical ID was available for a new binding.'
        Assert-Equal (Get-Tip $remote) $removed 'A reserved ID altered destination history.'
        Assert-True (-not (Test-Path (Join-Path $new 'documentation-sync/state.json'))) 'The refused historical ID was pinned.'
        $different = Invoke-Sync $new $remote @{ ProjectId = 'different' }
        Assert-Equal $different.status 'synced' 'A rejected ID prevented selection of a free ID.'
    }

    Invoke-Test 'same-file divergence preserves both versions while independent files sync' {
        $remote = New-Destination 'divergence'
        $first = New-Workspace 'divergence first'
        $second = New-Workspace 'divergence second'
        foreach ($workspace in $first, $second) {
            Write-Document $workspace 'requirements.md' 'Common requirements.'
            Write-Document $workspace 'project-setup.md' 'Common setup.'
        }
        $base = Invoke-Sync $first $remote @{ ProjectId = 'divergent' }
        $binding = (Get-State $first).bindingId
        $adoption = Invoke-Sync $second $remote @{ ProjectId = 'divergent'; AdoptBindingId = $binding }
        Assert-Equal $adoption.status 'unchanged' 'Equal documents did not establish a base without committing.'
        $commonBlob = (Get-State $second).files['requirements.md']

        Write-Document $first 'requirements.md' 'First workspace requirements.'
        Write-Document $first 'project-setup.md' 'First workspace setup.'
        Write-Document $second 'requirements.md' 'Second workspace requirements.'
        Write-Document $second 'architecture.md' 'Second workspace architecture.'
        $firstUpdate = Invoke-Sync $first $remote
        $partial = Invoke-Sync $second $remote -ExpectExit 2
        Assert-Pending $partial 'requirements.md' 'diverged'
        Assert-Pending $partial 'project-setup.md' 'remote_changed'
        Assert-Equal $partial.remoteRevision $firstUpdate.pushedRevision 'The report did not pin the remote comparison revision.'
        Assert-Equal (Get-Tip $remote) $partial.pushedRevision 'Safe unrelated content was not pushed.'
        Assert-Equal (Read-Remote $remote 'divergent/requirements.md') 'First workspace requirements.' 'Sync overwrote the remote version.'
        Assert-Equal ([File]::ReadAllText((Join-Path $second 'documentation/requirements.md'))) 'Second workspace requirements.' 'Sync overwrote the local version.'
        Assert-Equal ([File]::ReadAllText((Join-Path $second 'documentation/project-setup.md'))) 'Common setup.' 'A remote-only change was applied locally.'
        Assert-Equal (Read-Remote $remote 'divergent/architecture.md') 'Second workspace architecture.' 'The unrelated local document was omitted.'
        Assert-Equal (Read-Remote $remote 'divergent/requirements.md' $base.pushedRevision) 'Common requirements.' 'The shared base was lost from history.'
        Assert-Equal (Get-State $second).files['requirements.md'] $commonBlob 'A conflict advanced its baseline.'
        $repeated = Invoke-Sync $second $remote -ExpectExit 2
        Assert-True (-not $repeated.pushedRevision) 'A repeated conflict created another commit.'

        Write-Document $second 'requirements.md' 'First workspace requirements.'
        Write-Document $second 'project-setup.md' 'First workspace setup.'
        $resolved = Invoke-Sync $second $remote
        Assert-Equal $resolved.status 'unchanged' 'Matching versions should close the conflict without a commit.'
        Write-Document $second 'requirements.md' 'New draft after owner reconciliation.'
        $updated = Invoke-Sync $second $remote
        Assert-Equal $updated.status 'synced' 'A reconciled document could not be updated.'
    }

    Invoke-Test 'intentional deletion, bulk approval, and safe first import after deletion' {
        $workspace = New-Workspace 'deletions'
        $remote = New-Destination 'deletions'
        Write-Document $workspace 'project-status.md' '# Status'
        Write-Document $workspace 'requirements.md' 'Old requirements.'
        Write-Document $workspace 'architecture.md' 'Old architecture.'
        Write-Document $workspace 'concept-and-scope.md' 'Old concept.'
        $initial = Invoke-Sync $workspace $remote @{ ProjectId = 'deletions' }
        [File]::Delete((Join-Path $workspace 'documentation/requirements.md'))
        $unmarked = Invoke-Sync $workspace $remote -ExpectExit 2
        Assert-Pending $unmarked 'requirements.md' 'deletion_intent_required'
        Assert-Equal (Get-Tip $remote) $initial.pushedRevision 'Absence alone caused a deletion.'
        $single = Invoke-Sync $workspace $remote @{ DeletePath = @('requirements.md') }
        Assert-True ('deletions/requirements.md' -notin (Get-RemotePaths $remote)) 'The named deletion was not mirrored.'
        Assert-Equal (Read-Remote $remote 'deletions/requirements.md' $initial.pushedRevision) 'Old requirements.' 'Deleted document is absent from history.'

        foreach ($path in 'architecture.md', 'concept-and-scope.md') {
            [File]::Delete((Join-Path $workspace "documentation/$path"))
        }
        $deletePaths = @('architecture.md', 'concept-and-scope.md')
        $unapproved = Invoke-Sync $workspace $remote @{ DeletePath = $deletePaths; ApproveBulkDeletionAt = $initial.pushedRevision } -ExpectExit 2
        foreach ($path in $deletePaths) { Assert-Pending $unapproved $path 'bulk_deletion_approval_required' }
        Assert-Equal (Get-Tip $remote) $single.pushedRevision 'Stale approval allowed a bulk deletion.'
        $bulkPreview = Invoke-Sync $workspace $remote @{
            Action = 'preview'; DeletePath = $deletePaths; ApproveBulkDeletionAt = $single.pushedRevision
        }
        $changedScope = Invoke-Sync $workspace $remote @{
            ApprovedPlan = $bulkPreview.approval; DeletePath = @($deletePaths[0]); ApproveBulkDeletionAt = $single.pushedRevision
        } -ExpectExit 2
        Assert-True ($changedScope.error -like '*stale*') 'A reviewed bulk receipt authorized a different path set.'
        Assert-Equal (Get-Tip $remote) $single.pushedRevision 'A modified bulk deletion plan changed history.'
        $bulk = Invoke-Sync $workspace $remote @{
            ApprovedPlan = $bulkPreview.approval; DeletePath = $deletePaths; ApproveBulkDeletionAt = $single.pushedRevision
        }
        Assert-Equal ((Get-RemotePaths $remote) -join '|') 'deletions/.documentation-project.json|deletions/project-status.md' 'Bulk deletion changed unexpected paths.'

        $oldWorkspace = New-Workspace 'deletions stale import'
        Write-Document $oldWorkspace 'project-status.md' '# Status'
        Write-Document $oldWorkspace 'requirements.md' 'Old requirements.'
        $stale = Invoke-Sync $oldWorkspace $remote @{
            ProjectId = 'deletions'; AdoptBindingId = (Get-State $workspace).bindingId
        } -ExpectExit 2
        Assert-Pending $stale 'requirements.md' 'path_missing_from_remote_history_tip'
        Assert-Equal (Get-Tip $remote) $bulk.pushedRevision 'Adoption restored a previously deleted path.'
        Write-Document $workspace 'requirements.md' 'Intentionally added again.'
        [void](Invoke-Sync $workspace $remote)
        Assert-Equal (Read-Remote $remote 'deletions/requirements.md') 'Intentionally added again.' 'A known deletion prevented deliberate re-addition.'
    }

    Invoke-Test 'unsafe absences, unreadable content, and missing documentation roots' {
        $workspace = New-Workspace 'unsafe absence'
        $remote = New-Destination 'unsafe absence'
        $issue = 'issues/IMP-001-example.md'
        $documentation = Join-Path $workspace 'documentation'
        Write-Document $workspace 'project-status.md' '# Status'
        Write-Document $workspace $issue 'Important issue.'
        $initial = Invoke-Sync $workspace $remote @{ ProjectId = 'health' }
        [File]::Delete((Join-Path $documentation $issue))
        [Directory]::Delete((Join-Path $documentation 'issues'))
        $missingParent = Invoke-Sync $workspace $remote @{ DeletePath = @($issue) } -ExpectExit 2
        Assert-Pending $missingParent $issue 'unsafe_local_absence'

        $status = Join-Path $documentation 'project-status.md'
        $reader = [File]::Open($status, [FileMode]::Open, [FileAccess]::ReadWrite, [FileShare]::None)
        try {
            $unreadable = Invoke-Sync $workspace $remote @{ DeletePath = @($issue) } -ExpectExit 2
            Assert-True ([bool]$unreadable.error) 'An unreadable document did not suspend the scan.'
        }
        finally { $reader.Dispose() }
        [File]::Delete($status)
        [void][Directory]::CreateDirectory((Join-Path $documentation 'issues'))
        $empty = Invoke-Sync $workspace $remote @{
            DeletePath = @('project-status.md', $issue); ApproveBulkDeletionAt = $initial.pushedRevision
        } -ExpectExit 2
        Assert-Pending $empty $issue 'unsafe_local_absence'
        Assert-Pending $empty 'project-status.md' 'unsafe_local_absence'
        [Directory]::Delete((Join-Path $documentation 'issues'))
        [Directory]::Delete($documentation)
        $missing = Invoke-Sync $workspace $remote @{ DeletePath = @($issue) } -ExpectExit 2
        Assert-True ([bool]$missing.error) 'A missing documentation root did not fail the scan.'
        Assert-Equal (Get-Tip $remote) $initial.pushedRevision 'An unhealthy scan changed the remote.'
        Assert-Equal (Get-State $workspace).lastResult.status 'pending' 'Unhealthy scan was not recorded.'
    }

    Invoke-Test 'push rejection, recovery, workspace locking, and push acknowledgement journal' {
        $workspace = New-Workspace 'recovery'
        $remote = New-Destination 'recovery'
        Write-Document $workspace 'project-status.md' 'First snapshot.'
        $initial = Invoke-Sync $workspace $remote @{ ProjectId = 'recovery' }
        $before = Get-State $workspace
        Write-Document $workspace 'project-status.md' 'Local update pending.'
        Set-ReceiveHook $remote "#!/bin/sh`nexit 1"
        $rejected = Invoke-Sync $workspace $remote -ExpectExit 2
        Assert-True ($rejected.error -like '*rejected the backup push*') 'A receiver rejection was not reported.'
        Assert-Equal $rejected.lastVerifiedRevision $initial.pushedRevision 'A rejected push advanced the verified revision.'
        Assert-True (-not $rejected.pushedRevision) 'A rejected push was reported as successful.'
        Assert-Equal (Get-Tip $remote) $initial.pushedRevision 'Rejected push changed the destination.'
        Assert-Equal (Get-State $workspace).lastResult.status 'pending' 'Rejected push was not recorded.'
        Assert-Equal ([File]::ReadAllText((Join-Path $workspace 'documentation/project-status.md'))) 'Local update pending.' 'Rejected push changed local content.'
        [File]::Delete((Join-Path $remote 'hooks/pre-receive'))

        $lock = [File]::Open((Join-Path $workspace 'documentation-sync/sync.lock'), [FileMode]::Open, [FileAccess]::ReadWrite, [FileShare]::None)
        try {
            $blocked = Invoke-Sync $workspace $remote -ExpectExit 2
            Assert-True ([bool]$blocked.error) 'An overlapping writer acquired the workspace lock.'
            Assert-Equal (Get-Tip $remote) $initial.pushedRevision 'A locked workspace pushed changes.'
        }
        finally { $lock.Dispose() }

        $retry = Invoke-Sync $workspace $remote
        Assert-Equal (Read-Remote $remote 'recovery/project-status.md') 'Local update pending.' 'A safe retry failed to back up the local edit.'
        $after = Get-State $workspace
        [void]$before.Remove('lastPushedRevision')
        $before.pendingPush = @{ commit = $retry.pushedRevision; files = $after.files }
        $statePath = Join-Path $workspace 'documentation-sync/state.json'
        [File]::WriteAllText($statePath, (ConvertTo-Json -InputObject $before -Depth 12), $utf8)
        Write-Document $workspace 'project-status.md' 'New edit after interruption.'
        $recovered = Invoke-Sync $workspace $remote
        Assert-Equal (Read-Remote $remote 'recovery/project-status.md') 'New edit after interruption.' 'The journal did not recover the already pushed baseline.'
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main^')) $retry.pushedRevision 'Recovery duplicated the interrupted commit.'
        Assert-Equal (Get-State $workspace).pendingPush $null 'Recovery left a pending push journal.'
        Assert-Equal $recovered.status 'synced' 'Recovery did not finish the new update.'
    }

    Invoke-Test 'in-flight push race retries the same approval after an unrelated advance' {
        $remote = New-Destination 'unrelated race'
        $alpha = New-Workspace 'unrelated race alpha'
        $beta = New-Workspace 'unrelated race beta'
        Write-Document $alpha 'project-status.md' 'Alpha before review.'
        Write-Document $beta 'project-status.md' 'Beta concurrent snapshot.'
        $initial = Invoke-Sync $alpha $remote @{ ProjectId = 'alpha' }
        $peer = Join-Path $testRoot 'unrelated race peer.git'
        [void](Invoke-FixtureGit @('clone', '--bare', '--template=', '--', $remote, $peer))
        $competitor = Invoke-Sync $beta $peer @{ ProjectId = 'beta' }
        [void](Invoke-FixtureGit @("--git-dir=$remote", 'fetch', '--no-tags', '--', $peer, 'refs/heads/main:refs/race/peer'))
        [File]::WriteAllText((Join-Path $remote 'race-target'), "$($initial.pushedRevision) $($competitor.pushedRevision)`n", $utf8)
        Set-ReceiveHook $remote @'
#!/bin/sh
read -r old new ref
read -r expected peer < race-target
if [ "$ref" = refs/heads/main ] && [ "$old" = "$expected" ]; then
    unset GIT_QUARANTINE_PATH GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
    git update-ref "$ref" "$peer" "$old" || exit 1
fi
exit 0
'@
        Write-Document $alpha 'project-status.md' 'Alpha approved snapshot.'
        $preview = Invoke-Sync $alpha $remote @{ Action = 'preview' }
        $upload = Invoke-Sync $alpha $remote @{ ApprovedPlan = $preview.approval }
        Assert-Equal $upload.attempts 2 'The original approval did not survive a push race.'
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main^')) $competitor.pushedRevision 'Retry did not extend the other project commit.'
        Assert-Equal (Read-Remote $remote 'alpha/project-status.md') 'Alpha approved snapshot.' 'The approved content did not land.'
        Assert-Equal (Read-Remote $remote 'beta/project-status.md') 'Beta concurrent snapshot.' 'Retry changed the other project.'
    }

    Invoke-Test 'branch race requires new approval and the fresh plan skips the conflicting path' {
        $remote = New-Destination 'race'
        $alpha = New-Workspace 'race alpha'
        $beta = New-Workspace 'race beta'
        Write-Document $alpha 'project-status.md' 'Alpha first snapshot.'
        Write-Document $alpha 'requirements.md' 'Alpha common requirements.'
        Write-Document $beta 'project-status.md' 'Beta concurrent snapshot.'
        $initial = Invoke-Sync $alpha $remote @{ ProjectId = 'alpha' }

        $peer = Join-Path $testRoot 'race peer.git'
        [void](Invoke-FixtureGit @('clone', '--bare', '--template=', '--', $remote, $peer))
        [void](Invoke-Sync $beta $peer @{ ProjectId = 'beta' })
        $alphaPeer = New-Workspace 'race alpha peer'
        Write-Document $alphaPeer 'project-status.md' 'Alpha first snapshot.'
        Write-Document $alphaPeer 'requirements.md' 'Alpha common requirements.'
        [void](Invoke-Sync $alphaPeer $peer @{ ProjectId = 'alpha'; AdoptBindingId = (Get-State $alpha).bindingId })
        Write-Document $alphaPeer 'requirements.md' 'Alpha concurrent requirements.'
        $competitor = Invoke-Sync $alphaPeer $peer
        [void](Invoke-FixtureGit @("--git-dir=$remote", 'fetch', '--no-tags', '--', $peer, 'refs/heads/main:refs/race/peer'))
        [File]::WriteAllText((Join-Path $remote 'race-target'), "$($initial.pushedRevision) $($competitor.pushedRevision)`n", $utf8)
        Set-ReceiveHook $remote @'
#!/bin/sh
read -r old new ref
read -r expected peer < race-target
if [ "$ref" = refs/heads/main ] && [ "$old" = "$expected" ]; then
    unset GIT_QUARANTINE_PATH GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
    git update-ref "$ref" "$peer" "$old" || exit 1
fi
exit 0
'@
        Write-Document $alpha 'project-status.md' 'Alpha second snapshot.'
        Write-Document $alpha 'requirements.md' 'Alpha local requirements.'
        $raced = Invoke-Sync $alpha $remote -ExpectExit 2
        Assert-True ($raced.error -like '*stale*') 'The same-project race did not invalidate approval.'
        Assert-True (-not $raced.pushedRevision) 'An unapproved replan was pushed.'
        Assert-Equal (Get-Tip $remote) $competitor.pushedRevision 'The rejected push changed the competing tip.'
        $retried = Invoke-Sync $alpha $remote -ExpectExit 2
        Assert-Pending $retried 'requirements.md' 'diverged'
        Assert-Equal (Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', 'main^')) $competitor.pushedRevision 'The retry did not build on the concurrent project commit.'
        Assert-Equal (Read-Remote $remote 'alpha/project-status.md') 'Alpha second snapshot.' 'The retry lost alpha changes.'
        Assert-Equal (Read-Remote $remote 'alpha/requirements.md') 'Alpha concurrent requirements.' 'The retry overwrote the newly conflicting remote document.'
        Assert-Equal (Read-Remote $remote 'beta/project-status.md') 'Beta concurrent snapshot.' 'The retry lost beta changes.'
        Assert-Equal ((Invoke-FixtureGit @("--git-dir=$remote", 'diff-tree', '--no-commit-id', '--name-only', '-r', 'main')) -join '|') 'alpha/project-status.md' 'The retry committed a path outside alpha.'
    }

    Invoke-Test 'actual Git advertisement guard rejects a rewind before sending a normal push' {
        $remote = New-Destination 'push guard'
        $alpha = New-Workspace 'push guard alpha'
        $beta = New-Workspace 'push guard beta'
        Write-Document $alpha 'project-status.md' 'Alpha original.'
        Write-Document $beta 'project-status.md' 'Beta original.'
        $older = Invoke-Sync $alpha $remote @{ ProjectId = 'alpha' }
        $approvedParent = Invoke-Sync $beta $remote @{ ProjectId = 'beta' }

        $scratchPeer = Join-Path $testRoot 'push guard scratch.git'
        [void](Invoke-FixtureGit @('clone', '--bare', '--template=', '--', $remote, $scratchPeer))
        $candidateWorkspace = New-Workspace 'push guard candidate'
        Write-Document $candidateWorkspace 'project-status.md' 'Alpha original.'
        $binding = (Get-State $alpha).bindingId
        [void](Invoke-Sync $candidateWorkspace $scratchPeer @{ ProjectId = 'alpha'; AdoptBindingId = $binding })
        Write-Document $candidateWorkspace 'project-status.md' 'Alpha reviewed change.'
        $candidate = Invoke-Sync $candidateWorkspace $scratchPeer
        $delta = @(Invoke-FixtureGit @("--git-dir=$scratchPeer", 'diff', '--name-only', $approvedParent.pushedRevision, $candidate.pushedRevision))
        Assert-Equal ($delta -join '|') 'alpha/project-status.md' 'Fixture candidate changed unrelated paths.'

        $hooks = Join-Path $scratchPeer 'hooks'
        [void][Directory]::CreateDirectory($hooks)
        $hook = [File]::ReadAllText((Join-Path (Split-Path -Parent $PSScriptRoot) 'pre-push')).Replace("`r`n", "`n")
        [File]::WriteAllText((Join-Path $hooks 'pre-push'), $hook, $utf8)
        $guardEnvironment = @{
            DOC_SYNC_PUSH_REF = 'refs/heads/main'
            DOC_SYNC_PUSH_COMMIT = $candidate.pushedRevision
            DOC_SYNC_PUSH_PARENT = $approvedParent.pushedRevision
        }
        $oldEnvironment = @{}
        try {
            foreach ($name in $guardEnvironment.Keys) {
                $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
                [Environment]::SetEnvironmentVariable($name, $guardEnvironment[$name])
            }
            $arguments = @(
                "--git-dir=$scratchPeer", 'push', '--porcelain', '--no-follow-tags', '--',
                ([Uri]::new($remote)).AbsoluteUri, "$($candidate.pushedRevision):refs/heads/main"
            )
            [void](Invoke-FixtureGit @("--git-dir=$remote", 'update-ref', 'refs/heads/main', $older.pushedRevision, $approvedParent.pushedRevision))
            $pushOutput = & $git @arguments 2>&1
            Assert-True ($LASTEXITCODE -ne 0) "The guard accepted a normal push after a rewind. $pushOutput"
            Assert-Equal (Get-Tip $remote) $older.pushedRevision 'The push restored another project after the rewind.'

            [void](Invoke-FixtureGit @("--git-dir=$remote", 'update-ref', 'refs/heads/main', $approvedParent.pushedRevision, $older.pushedRevision))
            [void](Invoke-FixtureGit $arguments)
            Assert-Equal (Get-Tip $remote) $candidate.pushedRevision 'The matching advertised head was not allowed.'
        }
        finally {
            foreach ($name in $oldEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name]) }
        }
    }

    Invoke-Test 'wrong, missing, and network destinations and source-repository isolation' {
        $remote = New-Destination 'boundary'
        $workspace = New-Workspace 'boundary'
        $wrong = New-Destination 'boundary other'
        Write-Document $workspace 'project-status.md' 'Initial status.'
        $source = Join-Path $workspace 'project/sample-mod'
        [void](Invoke-FixtureGit @('init', '--initial-branch=main', '--template=', '--', $source))
        [File]::WriteAllText((Join-Path $source 'README.md'), 'Mod source README.')
        [void](Invoke-FixtureGit @('-C', $source, 'add', 'README.md'))
        [void](Invoke-FixtureGit @('-C', $source, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@localhost', 'commit', '-m', 'Add sample source'))
        $sourceTip = Invoke-FixtureGit @('-C', $source, 'rev-parse', 'HEAD')
        $first = Invoke-Sync $workspace $remote @{ ProjectId = 'boundary' }
        $wrongRepo = Invoke-Sync $workspace $wrong -ExpectExit 2
        Assert-True ($wrongRepo.error -like '*saved binding*') 'A configured destination was silently replaced.'
        Assert-EmptyRemote $wrong
        $wrongId = Invoke-Sync $workspace $remote @{ ProjectId = 'renamed-id' } -ExpectExit 2
        Assert-True ($wrongId.error -like '*saved binding*') 'The permanent project ID could be changed.'
        $network = Invoke-Sync $workspace 'https://example.invalid/private.git' -ExpectExit 2
        Assert-True ($network.error -like '*absolute local filesystem*') 'Network destination accepted by the local prototype.'

        $fresh = New-Workspace 'boundary fresh'
        Write-Document $fresh 'project-status.md' '# Status'
        $sourceAttempt = Invoke-Sync $fresh (Join-Path $source '.git') @{ ProjectId = 'boundary' } -ExpectExit 2
        Assert-True ($sourceAttempt.error -like '*outside Git worktrees*') 'A source checkout could be used as a backup destination.'
        $invalidBranch = Invoke-Sync $fresh $wrong @{ ProjectId = 'boundary'; Branch = 'different' } -ExpectExit 2
        Assert-True ($invalidBranch.error -like '*branch does not exist*') 'The tool created an unconfigured branch.'
        Assert-EmptyRemote $wrong
        Assert-Equal (Invoke-FixtureGit @('-C', $source, 'rev-parse', 'HEAD')) $sourceTip 'Sync changed the source repository revision.'
        Assert-Equal (@(Invoke-FixtureGit @('-C', $source, 'status', '--porcelain'))).Count 0 'Sync changed the source working tree.'
        Assert-Equal (Get-Tip $remote) $first.pushedRevision 'A rejected destination changed the original backup.'

        $unavailable = Join-Path $testRoot 'boundary unavailable.git'
        if ([Path]::GetDirectoryName([Path]::GetFullPath($remote)) -cne $testRoot -or
            [Path]::GetDirectoryName([Path]::GetFullPath($unavailable)) -cne $testRoot) {
            throw 'Unexpected fixture move path.'
        }
        [Directory]::Move($remote, $unavailable)
        try {
            Write-Document $workspace 'project-status.md' 'Status while unavailable.'
            $missing = Invoke-Sync $workspace $remote -ExpectExit 2
            Assert-True ([bool]$missing.error) 'A missing destination was reported as a backup.'
            Assert-Equal $missing.lastVerifiedRevision $first.pushedRevision 'Missing destination advanced the verified revision.'
        }
        finally { [Directory]::Move($unavailable, $remote) }
        [void](Invoke-Sync $workspace $remote)
        Assert-Equal (Read-Remote $remote 'boundary/project-status.md') 'Status while unavailable.' 'A later run did not back up the pending edit.'
    }

    Invoke-Test 'remote links, unclaimed directories, and rewritten history fail closed' {
        $workspace = New-Workspace 'remote topology'
        $remote = New-Destination 'remote topology'
        Write-Document $workspace 'project-status.md' 'Initial status.'
        Write-Document $workspace 'requirements.md' 'Initial requirements.'
        $initial = Invoke-Sync $workspace $remote @{ ProjectId = 'topology' }
        $fixture = Join-Path $testRoot 'remote topology writer'
        [void](Invoke-FixtureGit @('clone', '--template=', '--', $remote, $fixture))
        $blobFile = Join-Path $testRoot 'remote-link-target.txt'
        [File]::WriteAllText($blobFile, '../outside-file', $utf8)
        $blob = Invoke-FixtureGit @('-C', $fixture, 'hash-object', '-w', '--no-filters', '--', $blobFile)
        [void](Invoke-FixtureGit @('-C', $fixture, 'update-index', '--cacheinfo', "120000,$blob,topology/requirements.md"))
        [void](Invoke-FixtureGit @('-C', $fixture, 'update-index', '--add', '--cacheinfo', "100644,$blob,unclaimed/project-status.md"))
        [void](Invoke-FixtureGit @('-C', $fixture, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@localhost', 'commit', '-m', 'Seed unsafe destination paths'))
        [void](Invoke-FixtureGit @('-C', $fixture, 'push', 'origin', 'main'))
        $manual = Get-Tip $remote

        $newWorkspace = New-Workspace 'remote topology other'
        Write-Document $newWorkspace 'project-status.md' 'Unverified local documentation.'
        $unclaimed = Invoke-Sync $newWorkspace $remote @{ ProjectId = 'unclaimed' } -ExpectExit 2
        Assert-True ($unclaimed.error -like '*no usable project identity manifest*') 'An unclaimed directory was adopted.'
        Assert-Equal (Get-Tip $remote) $manual 'Unclaimed directory was modified.'

        Write-Document $workspace 'requirements.md' 'Local requirements update.'
        Write-Document $workspace 'project-status.md' 'Safe status update.'
        $blocked = Invoke-Sync $workspace $remote -ExpectExit 2
        Assert-Pending $blocked 'requirements.md' 'remote_path_conflict'
        Assert-True ((Invoke-FixtureGit @("--git-dir=$remote", 'ls-tree', 'main', '--', 'topology/requirements.md')) -like '120000 blob*') 'Sync replaced a remote symlink.'
        Assert-Equal (Read-Remote $remote 'topology/project-status.md') 'Safe status update.' 'The remote symlink blocked an unrelated safe update.'
        Assert-Equal (Read-Remote $remote 'unclaimed/project-status.md') '../outside-file' 'Sync changed the unclaimed directory.'

        [void](Invoke-FixtureGit @("--git-dir=$remote", 'update-ref', 'refs/heads/main', $initial.pushedRevision, $blocked.pushedRevision))
        $rewound = Invoke-Sync $workspace $remote -ExpectExit 2
        Assert-True ($rewound.error -like '*ancestry*' -or $rewound.error -like '*last verified revision*') 'Sync accepted a rewritten destination branch.'
        Assert-Equal (Get-Tip $remote) $initial.pushedRevision 'Sync restored history after a destination rewind.'
        Assert-Equal $rewound.lastVerifiedRevision $blocked.pushedRevision 'Rewound destination changed the saved base.'
    }

    Invoke-Test 'opted-in artwork uses exact approved bytes and preserves the existing documentation binding' {
        $workspace = New-Workspace 'approved artwork'
        $remote = New-Destination 'approved artwork'
        $icon = 'icon/final/mod-icon.png'
        $source = 'pixelart/gem/final/gem.pixelart'
        $reference = 'icon/references/palette.png'
        $iconFile = Write-Artwork $workspace $icon $png
        [void](Write-Artwork $workspace $source ($utf8.GetBytes('@preset item')))
        $referenceFile = Write-Artwork $workspace $reference $png
        [void](Write-Artwork $workspace 'icon/references/private.png' $png)
        [void](Write-Artwork $workspace 'icon/candidates/draft.png' $png)
        [void](Write-Artwork $workspace 'icon/working/working.png' $png)
        [void](Write-Artwork $workspace 'icon/final/unapproved.png' $png)
        Set-ArtworkManifest $workspace @($icon, $source, $reference)
        Write-Document $workspace 'project-status.md' 'Document remains authoritative.'
        Write-Document $workspace 'artwork/notes.md' 'Existing custom documentation.'
        [void](Invoke-Sync $workspace $remote @{ ProjectId = 'gallery'; IncludePath = @('artwork/notes.md') })
        $options = @{ IncludeArtwork = $true; IncludePath = @('artwork/notes.md') }
        Assert-Equal (Get-RemotePaths $remote).Count 3 'Documentation approval backed up artwork.'
        $applied = Invoke-Sync $workspace $remote $options
        Assert-Equal $applied.approvedArtwork.Count 3 'Artwork preview omitted an approved file.'
        Assert-Equal (Get-RemotePaths $remote).Count 6 'An unapproved file or the manifest reached the backup.'
        Assert-Equal (Read-Remote $remote 'gallery/artwork/notes.md') 'Existing custom documentation.' 'Artwork collided with an existing documentation path.'
        foreach ($item in $icon, $source, $reference) {
            $expected = Invoke-FixtureGit @('hash-object', '--no-filters', '--', (Join-Path $workspace "artwork/$item"))
            $backedUp = Invoke-FixtureGit @("--git-dir=$remote", 'rev-parse', "main:gallery/.artwork/$item")
            Assert-Equal $backedUp $expected "Backup altered bytes for $item."
        }

        $preview = Invoke-Sync $workspace $remote ($options + @{ Action = 'preview' })
        $altered = [byte[]]($png + @(1))
        [File]::WriteAllBytes($iconFile, $altered)
        $mismatch = Invoke-Sync $workspace $remote $options -ExpectExit 2
        Assert-Pending $mismatch ".artwork/$icon" 'artwork_version_not_approved'
        Assert-Equal (Get-Tip $remote) $applied.pushedRevision 'Unapproved bytes changed the backup.'
        Set-ArtworkManifest $workspace @($icon, $source, $reference)
        $stale = Invoke-Sync $workspace $remote ($options + @{ ApprovedPlan = $preview.approval }) -ExpectExit 2
        Assert-True ($stale.error -like '*stale*') 'An old preview approved an altered image.'
        [File]::Delete($referenceFile)
        $changed = Invoke-Sync $workspace $remote $options -ExpectExit 2
        Assert-Pending $changed ".artwork/$reference" 'approved_artwork_missing'
        Assert-True ($changed.pushedRevision -ne $applied.pushedRevision) 'A missing reference prevented the approved update.'
        Set-ArtworkManifest $workspace @($icon, $source)
        $revoked = Invoke-Sync $workspace $remote $options
        Assert-Equal $revoked.status 'unchanged' 'Removing approval left an artwork path pending.'
        $paused = Invoke-Sync $workspace $remote @{ IncludePath = @('artwork/notes.md') }
        Assert-Equal $paused.status 'unchanged' 'Pausing artwork disturbed normal backup.'
        Assert-True ("gallery/.artwork/$reference" -in (Get-RemotePaths $remote)) 'The backup removed an existing reference.'
    }

    Invoke-Test 'artwork rejects draft paths, duplicate approvals, disguised files, and filesystem links' {
        $workspace = New-Workspace 'blocked artwork'
        $remote = New-Destination 'blocked artwork'
        $options = @{ ProjectId = 'gallery'; IncludeArtwork = $true }
        Write-Document $workspace 'project-status.md' 'Eligible documentation.'
        $draft = 'icon/final/drafts/unfinished.png'
        [void](Write-Artwork $workspace $draft $png)
        Set-ArtworkManifest $workspace @($draft)
        $invalid = Invoke-Sync $workspace $remote ($options + @{ Action = 'preview' }) -ExpectExit 2
        Assert-True ($invalid.error -like '*Invalid path*') 'A draft could be approved for backup.'
        Assert-EmptyRemote $remote

        $bad = 'icon/final/renamed.png'
        [void](Write-Artwork $workspace $bad ($utf8.GetBytes('Not an image.')))
        Set-ArtworkManifest $workspace @($bad, $bad.ToUpperInvariant())
        $duplicate = Invoke-Sync $workspace $remote ($options + @{ Action = 'preview' }) -ExpectExit 2
        Assert-True ($duplicate.error -like '*Duplicate path*') 'Case variants could bypass manifest identity.'

        $linked = 'icon/references/linked.png'
        $linkedFile = Write-Artwork $workspace $linked $png
        $outside = Join-Path $testRoot 'outside-artwork.png'
        [File]::WriteAllBytes($outside, $png)
        [File]::Delete($linkedFile)
        New-Item -ItemType HardLink -Path $linkedFile -Target $outside | Out-Null
        $oversize = 'icon/final/large.png'
        [void](Write-Artwork $workspace $oversize ([byte[]]::new(10MB + 1)))
        Set-ArtworkManifest $workspace @($bad, $linked, $oversize)
        $blocked = Invoke-Sync $workspace $remote $options -ExpectExit 2
        Assert-Pending $blocked ".artwork/$bad" 'unexpected_artwork_format'
        Assert-Pending $blocked ".artwork/$linked" 'hard_link_or_unverified_link_count'
        Assert-Pending $blocked ".artwork/$oversize" 'document_too_large'
        Assert-Equal (Get-RemotePaths $remote).Count 2 'Blocked artwork changed the backup.'
    }

    Invoke-Test 'checkpoint approval backs up standard and remembered documents and leaves deletions pending' {
        $workspace = New-Workspace 'checkpoint workspace'
        $remote = New-Destination 'checkpoint destination'
        $fixtureTools = Join-Path $testRoot 'checkpoint tools'
        [void][Directory]::CreateDirectory($fixtureTools)
        $wrapper = Join-Path $fixtureTools 'checkpoint-backup.ps1'
        [File]::Copy((Join-Path (Split-Path -Parent $tool) 'checkpoint-backup.ps1'), $wrapper)
        $bridge = Join-Path $fixtureTools 'documentation-sync.ps1'
        [File]::WriteAllText($bridge, @'
param($Action, $Workspace, $Repository, $RepositoryId, $Branch, $ReadGitHubMetadata, $ProjectId, $ApprovedPlan, $IncludeArtwork)
if ($Repository -cne 'fixture-owner/private-docs' -or $RepositoryId -ne 42 -or $Branch -cne 'main') { throw 'Wrong fixture destination.' }
$arguments = @{ Workspace = $Workspace; Destination = $env:CHECKPOINT_FIXTURE_REPO }
if ($ProjectId) { $arguments.ProjectId = $ProjectId }
if ($IncludeArtwork) { $arguments.IncludeArtwork = $true }
if ($Action -eq 'sync') {
    if ($env:CHECKPOINT_FIXTURE_RACE -eq 'once') {
        $env:CHECKPOINT_FIXTURE_RACE = ''
        '{"status":"pending","error":"The reviewed plan is missing or stale. Run a fresh preview before applying."}'
        exit 2
    }
    $arguments.ApprovedPlan = $ApprovedPlan
}
& $env:CHECKPOINT_FIXTURE_TOOL $Action @arguments
exit $LASTEXITCODE
'@, $utf8)
        $vars = @{ CHECKPOINT_FIXTURE_REPO = $remote; CHECKPOINT_FIXTURE_TOOL = $tool; CHECKPOINT_FIXTURE_RACE = 'once' }
        $oldVars = @{}
        try {
            foreach ($name in $vars.Keys) {
                $oldVars[$name] = [Environment]::GetEnvironmentVariable($name)
                [Environment]::SetEnvironmentVariable($name, $vars[$name])
            }
            $defaults = Join-Path $testRoot 'checkpoint owner-defaults.md'
            $configuration = @'
## Shared Documentation Backup

- Automatic sync: Disabled.
- Destination: private GitHub repository `fixture-owner/private-docs`, repository ID `42`, branch `main`.
'@
            [File]::WriteAllText($defaults, ($configuration + "`n- Artwork backup: Approved.`n"), $utf8)
            [File]::WriteAllText((Join-Path $workspace 'project.properties'), 'documentation_project_id=checkpoint-fixture', $utf8)
            Write-Document $workspace 'project-status.md' 'Awaiting Approval'
            Write-Document $workspace 'requirements.md' 'Draft requirements.'
            Write-Document $workspace 'owner-defaults.md' 'Local owner data.'
            $standardPaths = @('revisions/rev-001-review.md', 'requirements-decisions.md', 'cycles/CYCLE-001-hud-effect-groups/requirements-decisions.md')
            foreach ($path in $standardPaths) { Write-Document $workspace $path 'Draft decision record.' }
            Write-Document $workspace 'revisions/archive/private-draft.md' 'Unapproved nested file.'
            $extraPath = 'notes/design decisions.md'
            Write-Document $workspace $extraPath 'Approved custom draft.'
            Write-Document $workspace 'notes/other.md' 'Unapproved sibling.'
            $icon = 'icon/final/icon.png'
            [void](Write-Artwork $workspace $icon $png)
            Set-ArtworkManifest $workspace @($icon)
            $arguments = @{ Workspace = $workspace; OwnerDefaults = $defaults; ReadGitHubMetadata = { throw 'Offline fixture.' } }
            $disabled = & $wrapper @arguments -Trigger checkpoint | ConvertFrom-Json -AsHashtable
            Assert-Equal $disabled.status 'disabled' 'Automatic backup should require opt-in.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $workspace 'documentation-sync'))) 'Disabled backup wrote local state.'
            Assert-EmptyRemote $remote

            $savedApproval = "approved for this owner's projects once the workflow supports automatic backups. Until then, use the manual preview and approval flow."
            [File]::WriteAllText($defaults, $configuration.Replace('Disabled.', $savedApproval), $utf8)
            $first = & $wrapper @arguments -Trigger checkpoint | ConvertFrom-Json -AsHashtable
            Assert-Equal $first.status 'synced' "Saved approval did not enable the checkpoint. $($first.error)"
            Assert-Equal $first.checkpointAttempts 2 'Checkpoint did not replan a stale attempt.'
            Assert-Equal (Read-Remote $remote 'checkpoint-fixture/project-status.md') 'Awaiting Approval' 'Draft status was lost.'
            Assert-True ('checkpoint-fixture/owner-defaults.md' -notin (Get-RemotePaths $remote)) 'Owner defaults were uploaded.'
            foreach ($path in $standardPaths) {
                Assert-Equal (Read-Remote $remote "checkpoint-fixture/$path") 'Draft decision record.' 'Standard artifact was omitted.'
            }
            Assert-True ("checkpoint-fixture/$extraPath" -notin (Get-RemotePaths $remote)) 'An unapproved custom path was uploaded.'
            Assert-True ('checkpoint-fixture/revisions/archive/private-draft.md' -notin (Get-RemotePaths $remote)) 'The revisions rule included nested files.'
            Assert-True ("checkpoint-fixture/.artwork/$icon" -notin (Get-RemotePaths $remote)) 'Artwork was backed up without its own opt-in.'

            $withArtwork = $configuration.Replace('Disabled.', $savedApproval) + "`n- Artwork backup: Approved.`n"
            [File]::WriteAllText($defaults, $withArtwork, $utf8)
            $optedIn = & $wrapper @arguments -Trigger checkpoint | ConvertFrom-Json -AsHashtable
            Assert-Equal $optedIn.status 'synced' "Artwork opt-in did not sync. $($optedIn.error)"
            Assert-True ("checkpoint-fixture/.artwork/$icon" -in (Get-RemotePaths $remote)) 'Wrapper omitted the approved artwork.'

            [void](Invoke-Sync $workspace $remote @{ SetRememberedIncludes = @($extraPath) })
            Write-Document $workspace $extraPath 'Updated custom draft.'
            $updated = & $wrapper @arguments -Trigger checkpoint | ConvertFrom-Json -AsHashtable
            Assert-Equal $updated.status 'synced' 'An approved custom edit left the checkpoint pending.'
            Assert-Equal (Read-Remote $remote "checkpoint-fixture/$extraPath") 'Updated custom draft.' 'The checkpoint missed an approved custom edit.'
            Assert-True ('checkpoint-fixture/notes/other.md' -notin (Get-RemotePaths $remote)) 'Approval spilled over into the containing directory.'

            [File]::Delete((Join-Path $workspace 'documentation/requirements.md'))
            Write-Document $workspace 'project-status.md' 'Draft updated at handoff'
            $handoff = & $wrapper @arguments -Trigger handoff | ConvertFrom-Json -AsHashtable
            Assert-Pending $handoff 'requirements.md' 'deletion_intent_required'
            Assert-Equal (Read-Remote $remote 'checkpoint-fixture/requirements.md') 'Draft requirements.' 'Automatic handoff deleted a file.'
            Assert-Equal (Read-Remote $remote 'checkpoint-fixture/project-status.md') 'Draft updated at handoff' 'A safe handoff edit was omitted.'
            $resume = & $wrapper @arguments -Trigger resume | ConvertFrom-Json -AsHashtable
            Assert-Equal $resume.status 'pending' 'Pending deletion disappeared on resume.'
            Assert-Equal (Get-Tip $remote) $handoff.pushedRevision 'Retry created an unexpected commit.'
            $record = Get-Content -Raw -LiteralPath (Join-Path $workspace 'documentation-sync/checkpoint-result.json') | ConvertFrom-Json -AsHashtable
            Assert-Equal $record.trigger 'resume' 'Resume result was not recorded.'
            Assert-Equal $record.lastPushedRevision $handoff.pushedRevision 'Pending retry lost the confirmed revision.'

            $invalid = $configuration.Replace('Disabled.', 'Approved.').Replace('repository ID `42`', 'repository ID `unverified`')
            [File]::WriteAllText($defaults, $invalid, $utf8)
            $blocked = & $wrapper @arguments -Trigger handoff | ConvertFrom-Json -AsHashtable
            Assert-Equal $blocked.status 'pending' 'Malformed destination was accepted.'
            Assert-Equal (Get-Tip $remote) $handoff.pushedRevision 'Malformed destination changed the remote.'
        }
        finally {
            foreach ($name in $oldVars.Keys) { [Environment]::SetEnvironmentVariable($name, $oldVars[$name]) }
        }
    }

    Assert-Equal (Invoke-FixtureGit @('-C', $workflowRoot, 'rev-parse', 'HEAD')) $workflowHead 'Tests changed the workflow commit.'
    Assert-Equal ((Invoke-FixtureGit @('-C', $workflowRoot, 'status', '--porcelain')) -join "`n") $workflowStatus 'Tests changed the workflow working tree.'
}
finally {
    foreach ($key in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key, $savedEnvironment[$key]) }
    $resolved = [Path]::GetFullPath($testRoot)
    if ([Path]::GetDirectoryName($resolved) -cne $tempParent -or
        [Path]::GetFileName($resolved) -cnotmatch '^documentation-sync-tests-[a-f0-9]{32}$' -or
        ([File]::GetAttributes($resolved) -band [FileAttributes]::ReparsePoint)) {
        throw 'Unexpected fixture cleanup path.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Write-Host "$testCount documentation sync tests passed."

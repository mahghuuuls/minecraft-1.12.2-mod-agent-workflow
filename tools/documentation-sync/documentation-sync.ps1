#Requires -Version 7.4
using namespace System.IO
using namespace System.Collections.Generic

[CmdletBinding(DefaultParameterSetName = 'Local')]
param(
    [Parameter(Position = 0)]
    [ValidateSet('preview', 'sync')]
    [string]$Action = 'preview',

    [Parameter(Mandatory)] [string]$Workspace,
    [Parameter(Mandatory, ParameterSetName = 'Local')] [string]$Destination,
    [Parameter(Mandatory, ParameterSetName = 'GitHub')] [string]$Repository,
    [Parameter(Mandatory, ParameterSetName = 'GitHub')] [long]$RepositoryId,
    [Parameter(Mandatory, ParameterSetName = 'GitHub')] [scriptblock]$ReadGitHubMetadata,
    [string]$Branch = 'main',
    [string]$ProjectId,
    [string]$AdoptBindingId,
    [string[]]$IncludePath = @(),
    [string[]]$SetRememberedIncludes,
    [string[]]$DeletePath = @(),
    [string]$ApproveBulkDeletionAt,
    [string]$ApprovedPlan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$pathComparison = [StringComparison]::Ordinal
if ($IsWindows) { $pathComparison = [StringComparison]::OrdinalIgnoreCase }
$objectIdPattern = '\A(?:[a-f0-9]{40}|[a-f0-9]{64})\z'
$bindingIdPattern = '\A[a-f0-9]{32}\z'
$identityPath = '.documentation-project.json'
$maxDocumentBytes = 2MB
$workflowRoot = [DirectoryInfo]::new($PSScriptRoot).Parent.Parent.FullName
$githubPilot = $PSCmdlet.ParameterSetName -eq 'GitHub'

$rootDocuments = @(
    'agent-diagnostics-toolkit-feedback.md', 'architecture.md', 'concept-and-scope.md',
    'dependency-references.md', 'feasibility-research.md', 'glossary.md', 'icon-design-brief.md',
    'implementation-plan.md', 'project-baseline.md', 'project-initialization.md', 'project-setup.md',
    'project-state.md', 'project-status.md', 'release-handoff.md', 'release-presentation.md',
    'requirements.md', 'requirements-decisions.md', 'workflow-feedback.md'
)
$cycleDocuments = @(
    'change-intake.md', 'cycle-summary.md', 'icon-design-brief.md', 'implementation-plan.md',
    'release-handoff.md', 'release-presentation.md', 'requirements-decisions.md'
)

function Resolve-LocalPath([string]$Path) {
    if (-not [Path]::IsPathFullyQualified($Path) -or $Path.StartsWith('\\')) {
        throw 'Use an absolute local filesystem path.'
    }
    $fullPath = [Path]::TrimEndingDirectorySeparator([Path]::GetFullPath($Path))
    if ($IsWindows) {
        $root = [Path]::GetPathRoot($fullPath)
        if ([DriveInfo]::new($root).DriveType -eq [DriveType]::Network -or
            $fullPath.Substring($root.Length) -match '[:]|[ .](?:[\\/]|$)') {
            throw 'Network drives and Windows path aliases are outside the local test boundary.'
        }
    }
    return $fullPath
}

function Test-InDirectory([string]$Path, [string]$Directory) {
    return $Path.Equals($Directory, $pathComparison) -or
        $Path.StartsWith($Directory.TrimEnd([char[]]'\/') + [Path]::DirectorySeparatorChar, $pathComparison)
}

function Assert-PlainDirectory([string]$Path) {
    $ancestors = [Stack[DirectoryInfo]]::new()
    for ($directory = [DirectoryInfo]::new($Path); $null -ne $directory; $directory = $directory.Parent) {
        $ancestors.Push($directory)
    }
    while ($ancestors.Count -gt 0) {
        $directory = $ancestors.Pop()
        $attributes = [File]::GetAttributes($directory.FullName)
        if (-not ($attributes -band [FileAttributes]::Directory) -or
            ($attributes -band [FileAttributes]::ReparsePoint)) {
            throw "Expected an ordinary directory at '$($directory.FullName)'."
        }
    }
}

function Assert-IsolatedDirectory([string]$Path) {
    if ((Test-InDirectory $Path $workspacePath) -or (Test-InDirectory $Path $workflowRoot)) {
        throw 'The destination and scratch repository must be outside the workspace and workflow repository.'
    }
    for ($parent = [DirectoryInfo]::new($Path); $null -ne $parent; $parent = $parent.Parent) {
        if ($parent.GetFileSystemInfos('.git').Count -gt 0) {
            throw 'The destination and scratch repository must be outside Git worktrees.'
        }
    }
}

function Test-SafeRelativePath([string]$RelativePath) {
    foreach ($part in $RelativePath.Split('/')) {
        if ($part -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9 ._-]*\z' -or $part -match '[ .]$' -or
            $part -match '^(?:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)') { return $false }
    }
    return $true
}

function Test-ExcludedPath([string]$RelativePath) {
    return $RelativePath -match '(?:^|/)owner-defaults\.md(?:/|$)' -or
        $RelativePath -match '(?:^|/)(?:logs?|crash[-_]reports?|screenshots?|evidence|validation|campaigns|test[-_]results|artifacts|build|tmp|temp|diagnostics|conflicts|credentials?|secrets?|ssh)(?:[._ -][^/]*)?(?:/|$)' -or
        [Path]::GetFileName($RelativePath) -match '^(?:latest|debug|results?|session-map|tokens?|passwords?|access[-_ ]?tokens?|api[-_ ]?keys?|private[-_ ]?keys?|id_rsa|id_ed25519)(?:[._ -]|$)'
}

function Test-IncludedDocument([string]$RelativePath) {
    if ((Test-ExcludedPath $RelativePath) -or -not (Test-SafeRelativePath $RelativePath)) { return $false }
    if ($includePaths.Contains($RelativePath) -or $RelativePath -in $rootDocuments) { return $true }
    if ($RelativePath -match '^issues/[a-z][a-z0-9]*-\d{3}(?:-[a-z0-9_-]+)?\.md$') { return $true }
    if ($RelativePath -match '\Arevisions/[^/]+\.md\z') { return $true }
    if ($RelativePath -match '^cycles/cycle-\d{3}-[a-z0-9_-]+/(?<document>.+)$') {
        $cycleDocument = $Matches.document
        return $cycleDocument -in $cycleDocuments -or
            $cycleDocument -match '^issues/[a-z][a-z0-9]*-\d{3}(?:-[a-z0-9_-]+)?\.md$'
    }
    return $false
}

function Test-CredentialText([string]$Text) {
    return $Text -match '-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|\bgh[pousr]_[a-z0-9]{20,}\b|\bgithub_pat_[a-z0-9_]{20,}\b|\b(?:AKIA|ASIA)[A-Z0-9]{16}\b|https?://[^\s/@:]+:[^\s/@]+@|\bbearer\s+[a-z0-9._~-]{16,}' -or
        $Text -match '\b(?:access[-_ ]?token|api[-_ ]?key|password|client[-_ ]?secret)\s*["'']?\s*[:=]\s*["'']?[^\s"''<>]{8,}'
}

function Get-ValidatedIncludes($Paths) {
    $validated = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $Paths) {
        if ($path -isnot [string] -or -not (Test-SafeRelativePath $path) -or (Test-ExcludedPath $path) -or
            (Test-CredentialText $path) -or $path -notmatch '\.(?:md|txt|csv)\z') {
            throw 'Extra includes must name safe Markdown, text, or CSV files outside the hard exclusions.'
        }
        [void]$validated.Add($path)
    }
    return ,$validated
}

function Invoke-Git {
    param(
        [string[]]$Arguments,
        [string]$GitDirectory = $scratch,
        [byte[]]$InputBytes,
        [switch]$AllowFailure,
        [hashtable]$PushGuard
    )
    $start = [System.Diagnostics.ProcessStartInfo]::new($gitExecutable)
    $start.WorkingDirectory = $scratch
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = $utf8
    foreach ($name in @($start.Environment.Keys)) {
        if ($name -match '^(?:GIT_|DOC_SYNC_PUSH_)') { [void]$start.Environment.Remove($name) }
    }
    $start.Environment['GIT_ALLOW_PROTOCOL'] = 'file'
    if ($githubPilot) {
        $start.Environment['GIT_ALLOW_PROTOCOL'] = 'ssh'
        $start.Environment['GIT_SSH_COMMAND'] = 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostName=github.com -o ConnectTimeout=10'
    }
    $start.Environment['GIT_CONFIG_NOSYSTEM'] = '1'
    $start.Environment['GIT_CONFIG_GLOBAL'] = $emptyConfig
    $start.Environment['GIT_TERMINAL_PROMPT'] = '0'
    $start.Environment['GIT_NO_REPLACE_OBJECTS'] = '1'
    if ($PushGuard) {
        $start.Environment['DOC_SYNC_PUSH_COMMIT'] = $PushGuard.commit
        $start.Environment['DOC_SYNC_PUSH_REF'] = $branchRef
        $start.Environment['DOC_SYNC_PUSH_PARENT'] = $PushGuard.parent
    }
    foreach ($role in 'AUTHOR', 'COMMITTER') {
        $start.Environment["GIT_${role}_NAME"] = 'Documentation Sync'
        $start.Environment["GIT_${role}_EMAIL"] = 'documentation-sync@localhost'
    }
    $start.ArgumentList.Add("--git-dir=$GitDirectory")
    $start.ArgumentList.Add('--literal-pathspecs')
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    if ($null -ne $InputBytes) {
        $start.RedirectStandardInput = $true
        $start.StandardInputEncoding = $utf8
    }

    $process = [System.Diagnostics.Process]::Start($start)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if ($null -ne $InputBytes) {
            $process.StandardInput.BaseStream.Write($InputBytes, 0, $InputBytes.Length)
            $process.StandardInput.Close()
        }
        if (-not $process.WaitForExit(30000)) {
            $process.Kill($true)
            throw "Git $($Arguments[0]) timed out."
        }
        $output = $stdout.GetAwaiter().GetResult()
        [void]$stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0 -and -not $AllowFailure) {
            throw "Git $($Arguments[0]) failed with exit code $($process.ExitCode)."
        }
        return @{ ExitCode = $process.ExitCode; Output = $output }
    }
    finally { $process.Dispose() }
}

function Write-Blob([byte[]]$Bytes) {
    return (Invoke-Git @('hash-object', '-w', '--stdin') -InputBytes $Bytes).Output.Trim()
}

function Get-LocalDocuments {
    Assert-PlainDirectory $documentationRoot
    $files = @{}
    $directories = [Stack[DirectoryInfo]]::new()
    $directories.Push([DirectoryInfo]::new($documentationRoot))
    while ($directories.Count -gt 0) {
        $directory = $directories.Pop()
        Assert-PlainDirectory $directory.FullName
        foreach ($entry in $directory.EnumerateFileSystemInfos()) {
            $relativePath = [Path]::GetRelativePath($documentationRoot, $entry.FullName).Replace('\', '/')
            if (Test-CredentialText $relativePath) {
                $result.excluded.Add(@{ path = $null; reason = 'possible_credential_in_path' })
                continue
            }
            if ((Test-ExcludedPath $relativePath) -or -not (Test-SafeRelativePath $relativePath)) {
                $result.excluded.Add(@{ path = $relativePath; reason = 'excluded_path' })
                continue
            }
            if ($entry.Attributes -band [FileAttributes]::ReparsePoint) {
                $result.excluded.Add(@{ path = $relativePath; reason = 'link_or_reparse_point' })
                if (Test-IncludedDocument $relativePath) {
                    $files.Add($relativePath, @{ path = $relativePath; blocked = 'link_or_reparse_point' })
                }
                continue
            }
            if ($entry.Attributes -band [FileAttributes]::Directory) {
                $directories.Push($entry)
                continue
            }
            if (-not (Test-IncludedDocument $relativePath)) {
                $result.excluded.Add(@{ path = $relativePath; reason = 'outside_allowlist' })
                continue
            }

            $document = @{ path = $relativePath; blob = $null; blocked = $null }
            $files.Add($relativePath, $document)
            if ($entry.Length -gt $maxDocumentBytes) {
                $document.blocked = 'document_too_large'
                continue
            }
            $stream = [File]::Open($entry.FullName, [FileMode]::Open, [FileAccess]::Read, [FileShare]::Read)
            try {
                Assert-PlainDirectory $directory.FullName
                if ([File]::GetAttributes($entry.FullName) -band [FileAttributes]::ReparsePoint) {
                    $document.blocked = 'link_or_reparse_point'
                    continue
                }
                $document.blocked = [DocumentationSync.WindowsFile]::GetBlockReason($stream.SafeFileHandle, $entry.FullName)
                if ($document.blocked) { continue }
                if ($stream.Length -gt $maxDocumentBytes) {
                    $document.blocked = 'document_too_large'
                    continue
                }
                $bytes = [byte[]]::new($stream.Length)
                $stream.ReadExactly($bytes, 0, $bytes.Length)
                if ($stream.ReadByte() -ne -1) { throw "Document '$relativePath' changed while it was read." }
            }
            finally { $stream.Dispose() }

            try { $text = $utf8.GetString($bytes) }
            catch [System.Text.DecoderFallbackException] {
                $document.blocked = 'non_text_document'
                continue
            }
            if ($text -match '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]') {
                $document.blocked = 'non_text_document'
                continue
            }
            if (Test-CredentialText $text) {
                $document.blocked = 'possible_credential'
                continue
            }
            $document.blob = Write-Blob $bytes
        }
    }
    return $files
}

function Assert-FileOrMissing([string]$Path) {
    try { $attributes = [File]::GetAttributes($Path) }
    catch [FileNotFoundException] { return }
    if ($attributes -band ([FileAttributes]::Directory -bor [FileAttributes]::ReparsePoint)) {
        throw "Expected an ordinary file at '$Path'."
    }
}

function ConvertTo-BaseFiles($Files) {
    if ($Files -isnot [System.Collections.IDictionary]) { throw 'Invalid file baselines in sync state.' }
    $validated = @{}
    foreach ($path in $Files.Keys) {
        if (-not (Test-SafeRelativePath $path) -or (Test-ExcludedPath $path) -or
            ($null -ne $Files[$path] -and $Files[$path] -cnotmatch $objectIdPattern)) {
            throw 'Invalid document path or blob ID in sync state.'
        }
        $validated.Add($path, $Files[$path])
    }
    return $validated
}

function Read-SyncState {
    if ([Directory]::Exists($stateDirectory)) {
        Assert-PlainDirectory $stateDirectory
        Assert-FileOrMissing $statePath
    }
    if ([File]::Exists($statePath)) {
        try { $saved = [File]::ReadAllText($statePath, $utf8) | ConvertFrom-Json -AsHashtable }
        catch { throw 'Could not read valid JSON from the documentation sync state.' }
        if ($saved.schemaVersion -ne 1 -or $saved.bindingId -cnotmatch $bindingIdPattern -or
            $saved.adoptExisting -isnot [bool] -or
            ($null -ne $saved.lastVerifiedRevision -and $saved.lastVerifiedRevision -cnotmatch $objectIdPattern)) {
            throw 'Invalid documentation sync state.'
        }
        if (-not $destinationKey.Equals($saved.destination, $pathComparison) -or $Branch -cne $saved.branch -or
            ($ProjectId -and $ProjectId -cne $saved.projectId) -or
            ($AdoptBindingId -and $AdoptBindingId -cne $saved.bindingId)) {
            throw 'The requested destination, branch, or project identity differs from the saved binding.'
        }
        $saved.files = ConvertTo-BaseFiles $saved.files
        if (-not $saved.ContainsKey('rememberedIncludes')) { $saved.rememberedIncludes = @() }
        if ($saved.rememberedIncludes -isnot [array]) { throw 'Invalid remembered includes in sync state.' }
        $remembered = Get-ValidatedIncludes $saved.rememberedIncludes
        $saved.rememberedIncludes = @($remembered | Sort-Object -CaseSensitive)
        if (-not $saved.ContainsKey('lastPushedRevision')) { $saved.lastPushedRevision = $null }
        if ($null -ne $saved.lastPushedRevision -and $saved.lastPushedRevision -cnotmatch $objectIdPattern) {
            throw 'Invalid last pushed revision in sync state.'
        }
        if ($null -ne $saved.pendingPush) {
            if ($saved.pendingPush.commit -cnotmatch $objectIdPattern) { throw 'Invalid pending push in sync state.' }
            $saved.pendingPush.files = ConvertTo-BaseFiles $saved.pendingPush.files
        }
        return $saved
    }

    if (-not $ProjectId) { throw 'The first run requires a permanent -ProjectId.' }
    $binding = [Guid]::NewGuid().ToString('N')
    if ($approvalBinding) { $binding = $approvalBinding }
    if ($AdoptBindingId) { $binding = $AdoptBindingId }
    return @{
        schemaVersion = 1
        projectId = $ProjectId
        bindingId = $binding
        adoptExisting = [bool]$AdoptBindingId
        destination = $destinationKey
        branch = $Branch
        lastVerifiedRevision = $null
        lastPushedRevision = $null
        files = @{}
        rememberedIncludes = @()
        pendingPush = $null
        lastResult = $null
    }
}

function Save-SyncState {
    Assert-PlainDirectory $stateDirectory
    Assert-FileOrMissing $statePath
    $temporaryState = Join-Path $stateDirectory ([Guid]::NewGuid().ToString('N') + '.tmp')
    $json = ConvertTo-Json -InputObject $state -Depth 12
    try {
        [File]::WriteAllText($temporaryState, $json, $utf8)
        [File]::Move($temporaryState, $statePath, $true)
    }
    finally { [File]::Delete($temporaryState) }
}

function Get-RemoteTip {
    if ($githubPilot) {
        $preflight = Test-GitHubPilotDestination -Repository $Repository -RepositoryId $RepositoryId -Branch $Branch -ReadMetadata $ReadGitHubMetadata
        if ($preflight.status -cne 'verified') { throw "GitHub preflight is pending ($($preflight.reason))." }
        if ($preflight.gitUri -cne $destinationUri -or $preflight.branchRef -cne $branchRef) {
            throw 'GitHub preflight returned an unexpected destination.'
        }
        if ($null -eq $preflight.head) {
            $refs = (Invoke-Git @('ls-remote', '--refs', '--', $destinationUri)).Output.Trim()
            if ($refs) { throw 'Git advertises refs for a repository reported empty. Run a fresh preflight.' }
            return $null
        }
    }
    else {
        Assert-PlainDirectory $destinationPath
        $advertised = Invoke-Git @('ls-remote', '--exit-code', '--refs', '--', $destinationUri, $branchRef) -AllowFailure
        if ($advertised.ExitCode -eq 2) {
            $defaultRef = (Invoke-Git @('symbolic-ref', 'HEAD') -GitDirectory $destinationPath).Output.Trim()
            $refs = (Invoke-Git @('for-each-ref', '--format=%(refname)') -GitDirectory $destinationPath).Output.Trim().Split("`n", [StringSplitOptions]::RemoveEmptyEntries)
            if ($branchRef -cnotin $refs) {
                if ($defaultRef -ceq $branchRef -and $refs.Count -eq 0) { return $null }
                throw 'The selected destination branch does not exist.'
            }
        }
        elseif ($advertised.ExitCode -ne 0) { throw "Could not read the destination branch (Git exit $($advertised.ExitCode))." }
    }
    [void](Invoke-Git @('fetch', '--no-tags', '--no-recurse-submodules', '--no-auto-gc', '--', $destinationUri, $branchRef))
    $fetched = (Invoke-Git @('rev-parse', '--verify', 'FETCH_HEAD^{commit}')).Output.Trim()
    if ($githubPilot -and $fetched -cne $preflight.head) {
        throw 'Git and GitHub metadata disagree about the branch head. Run a fresh preflight.'
    }
    return $fetched
}

function Test-GitAncestor([string]$Ancestor, [string]$Tip) {
    if (-not $Tip) { return $false }
    $test = Invoke-Git @('merge-base', '--is-ancestor', $Ancestor, $Tip) -AllowFailure
    if ($test.ExitCode -gt 1) { throw 'Could not verify destination commit ancestry.' }
    return $test.ExitCode -eq 0
}

function Resolve-PendingPush([string]$Tip) {
    if ($state.lastVerifiedRevision -and -not (Test-GitAncestor $state.lastVerifiedRevision $Tip)) {
        throw 'The destination branch no longer contains the last verified revision.'
    }
    $pending = $state.pendingPush
    if ($null -eq $pending) { return }

    # The journal survives a lost push acknowledgement or a crash before baselines were saved.
    $known = Invoke-Git @('cat-file', '-e', "$($pending.commit)^{commit}") -AllowFailure
    if ($known.ExitCode -eq 0 -and (Test-GitAncestor $pending.commit $Tip)) {
        $state.files = $pending.files
        $state.lastVerifiedRevision = $pending.commit
        $state.lastPushedRevision = $pending.commit
        $result.pushedRevision = $pending.commit
    }
    $state.pendingPush = $null
}

function Get-GitTree {
    param([string]$Treeish, [switch]$Recursive)
    $arguments = @('ls-tree', '-z')
    if ($Recursive) { $arguments += '-r', '-t' }
    $tree = @{}
    $raw = (Invoke-Git ($arguments + $Treeish)).Output
    foreach ($entry in $raw.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($entry -cnotmatch '(?s)^(?<mode>[0-7]{6}) (?:blob|tree|commit) (?<oid>[0-9a-f]+)\t(?<path>.+)$') {
            throw 'Git returned an invalid tree entry.'
        }
        if ($tree.ContainsKey($Matches.path)) {
            $tree[$Matches.path].mode = 'case_collision'
            continue
        }
        $tree.Add($Matches.path, @{ path = $Matches.path; mode = $Matches.mode; blob = $Matches.oid })
    }
    return $tree
}

function Get-RemoteProject([string]$Tip) {
    $rootEntry = $null
    if ($Tip) { $rootEntry = (Get-GitTree $Tip)[$state.projectId] }
    if ($null -eq $rootEntry) {
        if ($state.adoptExisting -or $state.lastVerifiedRevision) {
            throw 'The bound documentation directory is missing from the destination.'
        }
        if ($Tip -and (Invoke-Git @('rev-list', '-1', $Tip, '--', $state.projectId)).Output.Trim()) {
            throw 'The project ID is reserved by destination history. Resolve its existing identity or choose a different ID.'
        }
        return @{ bound = $false; tree = $null; entries = @{} }
    }
    if ($rootEntry.path -cne $state.projectId -or $rootEntry.mode -ne '040000') {
        throw 'The documentation project ID collides with a destination path.'
    }
    $entries = Get-GitTree $rootEntry.blob -Recursive
    $manifest = $entries[$identityPath]
    if ($null -eq $manifest -or $manifest.path -cne $identityPath -or $manifest.mode -ne '100644' -or
        [int64](Invoke-Git @('cat-file', '-s', $manifest.blob)).Output.Trim() -gt 4096) {
        throw 'The occupied documentation directory has no usable project identity manifest.'
    }
    if (-not $existingState -and -not $state.adoptExisting) {
        throw 'The occupied documentation directory requires an explicitly verified adoption binding.'
    }
    try { $identity = (Invoke-Git @('cat-file', 'blob', $manifest.blob)).Output | ConvertFrom-Json -AsHashtable }
    catch { throw 'The occupied documentation directory has an invalid identity manifest.' }
    if ($identity.schemaVersion -ne 1 -or $identity.projectId -cne $state.projectId -or
        $identity.bindingId -cne $state.bindingId) {
        throw 'The occupied documentation directory does not match the saved or explicitly adopted project identity.'
    }
    return @{ bound = $true; tree = $rootEntry.blob; entries = $entries }
}

function Test-ConfirmedAbsent([string]$RelativePath) {
    $path = Join-Path $documentationRoot $RelativePath
    try { Assert-PlainDirectory ([Path]::GetDirectoryName($path)) }
    catch { return $false }
    try {
        [void][File]::GetAttributes($path)
        return $false
    }
    catch [FileNotFoundException] { return $true }
    catch { return $false }
}

function Test-RemotePathConflict([hashtable]$Entries, [string]$Path) {
    $expectedMode = '100644'
    while ($Path) {
        $entry = $Entries[$Path]
        if ($null -ne $entry -and ($entry.path -cne $Path -or $entry.mode -ne $expectedMode)) {
            return $true
        }
        $separator = $Path.LastIndexOf('/')
        if ($separator -lt 0) { break }
        $Path = $Path.Substring(0, $separator)
        $expectedMode = '040000'
    }
    return $false
}

function Get-SyncPlan([hashtable]$Local, [hashtable]$Remote, [string]$Tip) {
    $baseFiles = $state.files.Clone()
    $paths = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in @($baseFiles.Keys) + @($Remote.entries.Keys) + @($Local.Keys) + @($DeletePath)) {
        if (Test-IncludedDocument $path) { [void]$paths.Add($path) }
    }
    $missingCount = @($baseFiles.Keys | Where-Object {
        $null -ne $baseFiles[$_] -and -not $Local.ContainsKey($_) -and (Test-IncludedDocument $_)
    }).Count
    $hasReadableDocument = @($Local.Values | Where-Object { $_['blob'] }).Count -gt 0
    $changes = [List[object]]::new()
    $pending = [List[object]]::new()

    foreach ($path in ($baseFiles.Keys | Sort-Object)) {
        if ($baseFiles[$path] -and -not (Test-IncludedDocument $path)) {
            $pending.Add(@{ path = $path; reason = 'tracked_path_outside_allowlist'; baseBlob = $baseFiles[$path] })
        }
    }

    foreach ($path in ($paths | Sort-Object)) {
        $localDocument = $Local[$path]
        $remoteEntry = $Remote.entries[$path]
        $baseKnown = $baseFiles.ContainsKey($path)
        $baseBlob = $baseFiles[$path]
        $localBlob = $null
        $remoteBlob = $null
        $reason = $null
        if ($null -ne $localDocument) {
            $localBlob = $localDocument['blob']
            $reason = $localDocument['blocked']
            if ($localDocument.path -cne $path) { $reason = 'local_path_case_conflict' }
        }
        if ($null -ne $remoteEntry) { $remoteBlob = $remoteEntry.blob }

        if (-not $reason -and (Test-RemotePathConflict $Remote.entries $path)) {
            $reason = 'remote_path_conflict'
        }
        if (-not $reason -and $path -in $DeletePath -and $null -ne $localDocument) {
            $reason = 'deletion_path_still_present'
        }
        # Unreadable and unsafe inputs never represent a deletion.
        if (-not $reason) {
            if ($localBlob -ceq $remoteBlob) {
                if ($baseKnown -or $localBlob) { $baseFiles[$path] = $localBlob }
            }
            elseif (-not $baseKnown -and $remoteBlob) {
                $reason = 'no_common_base'
            }
            elseif ($baseKnown -and $remoteBlob -cne $baseBlob) {
                $reason = 'remote_changed'
                if ($localBlob -cne $baseBlob) { $reason = 'diverged' }
            }
            elseif ($localBlob) {
                if (-not $baseKnown -and $Remote.bound -and
                    (Invoke-Git @('rev-list', '-1', $Tip, '--', "$($state.projectId)/$path")).Output.Trim()) {
                    $reason = 'path_missing_from_remote_history_tip'
                }
                else {
                    $operation = 'add'
                    if ($remoteBlob) { $operation = 'update' }
                    $changes.Add(@{ path = $path; action = $operation; blob = $localBlob })
                    $baseFiles[$path] = $localBlob
                }
            }
            elseif (-not $hasReadableDocument -or -not (Test-ConfirmedAbsent $path)) {
                $reason = 'unsafe_local_absence'
            }
            elseif ($path -notin $DeletePath) {
                $reason = 'deletion_intent_required'
            }
            elseif ($missingCount -ge 2 -and $ApproveBulkDeletionAt -cne $Tip) {
                $reason = 'bulk_deletion_approval_required'
            }
            else {
                $changes.Add(@{ path = $path; action = 'delete'; blob = $null })
                $baseFiles[$path] = $null
            }
        }

        if ($reason) {
            $pending.Add(@{
                path = $path; reason = $reason; baseKnown = $baseKnown
                baseBlob = $baseBlob; localBlob = $localBlob; remoteBlob = $remoteBlob
            })
        }
    }

    if (-not $Remote.bound -and $changes.Count -gt 0) {
        $identity = ConvertTo-Json -Compress -InputObject ([ordered]@{
            schemaVersion = 1; projectId = $state.projectId; bindingId = $state.bindingId
        })
        $changes.Add(@{ path = $identityPath; action = 'bind'; blob = (Write-Blob $utf8.GetBytes($identity + "`n")) })
    }
    return @{ changes = $changes.ToArray(); pending = $pending.ToArray(); files = $baseFiles }
}

function Get-PlanDigest($ProjectTree, [string]$Anchor) {
    $snapshot = [ordered]@{
        schemaVersion = 1
        workspace = $workspacePath
        destination = $destinationKey
        branch = $branchRef
        head = $tip
        projectId = $state.projectId
        bindingId = $state.bindingId
        includePaths = @($includePaths | Sort-Object -CaseSensitive)
        deletePaths = @($DeletePath | Sort-Object -CaseSensitive)
        bulkDeletionAt = $ApproveBulkDeletionAt
        changes = $result.changes
    }
    if (-not $legacyApproval) {
        # The original anchor stays fixed as other projects advance the branch.
        $snapshot.schemaVersion = 2
        $snapshot.head = $Anchor
        $snapshot.projectTree = $ProjectTree
    }
    if ($replaceRememberedIncludes -or $result.rememberedIncludes.Count -gt 0) {
        $snapshot.rememberedIncludes = $result.rememberedIncludes
    }
    if ($replaceRememberedIncludes) { $snapshot.previousRememberedIncludes = $previousRememberedIncludes }
    $json = ConvertTo-Json -InputObject $snapshot -Depth 6 -Compress
    $digest = [Security.Cryptography.SHA256]::HashData($utf8.GetBytes($json))
    return [Convert]::ToHexString($digest).ToLowerInvariant()
}

function New-BackupCommit([hashtable]$Plan, [string]$Tip) {
    # The temporary index starts at the fetched tree. No remote file is checked out.
    $previousTree = $Tip
    if ($Tip) { [void](Invoke-Git @('read-tree', $Tip)) }
    else {
        [void](Invoke-Git @('read-tree', '--empty'))
        $previousTree = (Invoke-Git @('write-tree')).Output.Trim()
    }
    $indexRecords = [List[string]]::new()
    $expected = [HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($change in $Plan.changes) {
        $remotePath = "$($state.projectId)/$($change.path)"
        if ($change.action -eq 'delete') {
            $indexRecords.Add("0 $zeroObjectId`t$remotePath`0")
            [void]$expected.Add("D`t$remotePath")
        }
        else {
            $indexRecords.Add("100644 $($change.blob)`t$remotePath`0")
            $status = 'A'
            if ($change.action -eq 'update') { $status = 'M' }
            [void]$expected.Add("$status`t$remotePath")
        }
    }
    [void](Invoke-Git @('update-index', '-z', '--index-info') -InputBytes $utf8.GetBytes(($indexRecords -join '')))
    $tree = (Invoke-Git @('write-tree')).Output.Trim()
    $diff = (Invoke-Git @('diff-tree', '--no-commit-id', '--no-renames', '--name-status', '-r', '-z', $previousTree, $tree)).Output
    $fields = $diff.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)
    if ($fields.Count -ne 2 * $expected.Count) { throw 'The backup commit differs from the planned paths.' }
    for ($index = 0; $index -lt $fields.Count; $index += 2) {
        if (-not $expected.Remove("$($fields[$index])`t$($fields[$index + 1])")) {
            throw 'The backup commit differs from the planned paths.'
        }
    }
    $commitArguments = @('commit-tree', $tree, '-m', "Back up documentation for $($state.projectId)")
    if ($Tip) { $commitArguments += '-p', $Tip }
    return (Invoke-Git $commitArguments).Output.Trim()
}

$result = [ordered]@{
    status = 'pending'
    projectId = $null
    destination = $null
    repositoryId = $null
    branch = $Branch
    attempts = 0
    lastVerifiedRevision = $null
    lastPushedRevision = $null
    remoteRevision = $null
    pushedRevision = $null
    approval = $null
    rememberedIncludes = @()
    changes = @()
    pending = @()
    excluded = [List[object]]::new()
    error = $null
    cleanupWarning = $null
}
$state = $null
$lock = $null
$scratch = $null
$canSaveState = $false
$approvalBinding = $null
$approvalAnchor = $null
$legacyApproval = $false
$replaceRememberedIncludes = $PSBoundParameters.ContainsKey('SetRememberedIncludes')
try {
    if (-not $IsWindows) { throw 'The local pilot requires Windows for opened-file identity checks.' }
    $workspacePath = Resolve-LocalPath $Workspace
    if ($githubPilot) {
        $destinationKey = "github:$RepositoryId/$($Repository.ToLowerInvariant())"
        $destinationUri = "ssh://git@github.com/$Repository.git"
        $result.destination = "https://github.com/$Repository"
        $result.repositoryId = $RepositoryId
        Import-Module (Join-Path $PSScriptRoot 'github-preflight.psm1')
    }
    else {
        $destinationPath = Resolve-LocalPath $Destination
        $destinationKey = $destinationPath
        $destinationUri = ([Uri]::new($destinationPath)).AbsoluteUri
        $result.destination = $destinationPath
    }
    Assert-PlainDirectory $workspacePath
    if ([Path]::GetFileName($workspacePath) -ine 'workspace') { throw 'Point -Workspace at the workspace directory.' }
    $documentationRoot = Join-Path $workspacePath 'documentation'
    $stateDirectory = Join-Path $workspacePath 'documentation-sync'
    $statePath = Join-Path $stateDirectory 'state.json'
    $branchRef = "refs/heads/$Branch"
    if ($AdoptBindingId -and $AdoptBindingId -cnotmatch $bindingIdPattern) { throw 'Invalid adoption binding ID.' }
    if ($ApproveBulkDeletionAt -and ($ApproveBulkDeletionAt -cnotmatch $objectIdPattern -or $DeletePath.Count -eq 0)) {
        throw 'Bulk deletion approval requires the exact remote revision and named deletion paths.'
    }
    if ($ApprovedPlan) {
        if ($Action -ne 'sync' -or $ApprovedPlan -cnotmatch '\A(?<binding>[a-f0-9]{32})\.(?:(?<anchor>unborn|[a-f0-9]{40}|[a-f0-9]{64})\.)?[a-f0-9]{64}\z') {
            throw 'Use the approval receipt from a preview with the sync command.'
        }
        $approvalBinding = $Matches.binding
        $approvalAnchor = $Matches['anchor']
        $legacyApproval = -not $approvalAnchor
    }

    if ($Action -eq 'sync') {
        if ([DirectoryInfo]::new($workspacePath).GetFileSystemInfos('documentation-sync').Count -gt 0) {
            Assert-PlainDirectory $stateDirectory
        }
        [void][Directory]::CreateDirectory($stateDirectory)
        Assert-PlainDirectory $stateDirectory
        $lockPath = Join-Path $stateDirectory 'sync.lock'
        Assert-FileOrMissing $lockPath
        $lock = [File]::Open($lockPath, [FileMode]::OpenOrCreate, [FileAccess]::ReadWrite, [FileShare]::None)
    }
    $state = Read-SyncState
    $existingState = [File]::Exists($statePath)
    $previousRememberedIncludes = $state.rememberedIncludes
    $result.rememberedIncludes = $previousRememberedIncludes
    if ($replaceRememberedIncludes) {
        $remembered = Get-ValidatedIncludes $SetRememberedIncludes
        $result.rememberedIncludes = @($remembered | Sort-Object -CaseSensitive)
    }
    $includePaths = Get-ValidatedIncludes ($result.rememberedIncludes + $IncludePath)
    foreach ($path in $DeletePath) {
        if (-not (Test-IncludedDocument $path)) { throw 'A deletion must name an included document by its relative path.' }
    }
    if ($state.projectId -cnotmatch '\A[a-z0-9][a-z0-9_-]{0,62}\z' -or
        -not (Test-SafeRelativePath $state.projectId) -or (Test-CredentialText $state.projectId)) {
        throw 'The project ID must be a portable lowercase directory name of at most 63 characters.'
    }
    $result.projectId = $state.projectId
    $canSaveState = $Action -eq 'sync' -and $existingState

    if (-not $githubPilot) {
        Assert-PlainDirectory $destinationPath
        Assert-IsolatedDirectory $destinationPath
        if (Test-InDirectory $workspacePath $destinationPath) { throw 'The workspace must be outside the destination.' }
    }
    $tempParent = Resolve-LocalPath ([Path]::GetTempPath())
    Assert-PlainDirectory $tempParent
    Assert-IsolatedDirectory $tempParent
    if (-not $githubPilot -and (Test-InDirectory $tempParent $destinationPath)) { throw 'The scratch repository must be outside the destination.' }
    $gitExecutable = (Get-Command git -CommandType Application | Select-Object -First 1).Source
    $scratch = Join-Path $tempParent ('documentation-sync-' + [Guid]::NewGuid().ToString('N'))
    [void][Directory]::CreateDirectory($scratch)
    $emptyConfig = Join-Path $scratch 'empty-config'
    [File]::WriteAllBytes($emptyConfig, [byte[]]::new(0))
    $format = 'sha1'
    if (-not $githubPilot) {
        if ((Invoke-Git @('rev-parse', '--is-bare-repository') -GitDirectory $destinationPath).Output.Trim() -cne 'true') {
            throw 'The local destination must be a bare Git repository.'
        }
        $format = (Invoke-Git @('rev-parse', '--show-object-format') -GitDirectory $destinationPath).Output.Trim()
    }
    if ($format -cnotin 'sha1', 'sha256') { throw 'Unsupported destination object format.' }
    $zeroObjectId = '0' * 40
    if ($format -eq 'sha256') { $zeroObjectId = '0' * 64 }
    [void](Invoke-Git @('init', '--bare', '--template=', "--object-format=$format"))
    [void](Invoke-Git @('check-ref-format', $branchRef))
    $tip = Get-RemoteTip
    if (-not ('DocumentationSync.WindowsFile' -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot 'WindowsFile.cs')
    }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $result.attempts = $attempt
        $result.remoteRevision = $tip
        Resolve-PendingPush $tip
        if ($approvalAnchor -and $approvalAnchor -cne 'unborn' -and -not (Test-GitAncestor $approvalAnchor $tip)) {
            throw 'The destination branch no longer contains the approved preview revision.'
        }
        $remoteProject = Get-RemoteProject $tip
        $result.excluded.Clear()
        $plan = Get-SyncPlan (Get-LocalDocuments) $remoteProject $tip
        $result.changes = @($plan.changes | ForEach-Object {
            $previousBlob = $null
            if ($remoteProject.entries.ContainsKey($_.path)) { $previousBlob = $remoteProject.entries[$_.path].blob }
            [ordered]@{ path = $_.path; action = $_.action; beforeBlob = $previousBlob; afterBlob = $_.blob }
        })
        $result.pending = $plan.pending
        $anchor = $approvalAnchor
        if ($Action -eq 'preview') {
            $anchor = 'unborn'
            if ($tip) { $anchor = $tip }
        }
        $digest = Get-PlanDigest $remoteProject.tree $anchor
        if ($Action -eq 'preview') {
            $result.approval = "$($state.bindingId).$anchor.$digest"
            $result.status = 'preview'
            break
        }
        $receipt = "$($state.bindingId).$approvalAnchor.$digest"
        if ($legacyApproval) { $receipt = "$($state.bindingId).$digest" }
        if ($ApprovedPlan -cne $receipt) { throw 'The reviewed plan is missing or stale. Run a fresh preview before applying.' }
        $canSaveState = $true
        if ($replaceRememberedIncludes) { $state.rememberedIncludes = $result.rememberedIncludes }
        if ($plan.changes.Count -eq 0) {
            $state.files = $plan.files
            if ($remoteProject.bound) { $state.lastVerifiedRevision = $tip }
            $result.status = 'unchanged'
            break
        }
        else {
            $hooks = Join-Path $scratch 'hooks'
            [void][Directory]::CreateDirectory($hooks)
            $hook = [File]::ReadAllText((Join-Path $PSScriptRoot 'pre-push'), $utf8).Replace("`r`n", "`n")
            [File]::WriteAllText((Join-Path $hooks 'pre-push'), $hook, $utf8)
            $candidate = New-BackupCommit $plan $tip
            foreach ($change in $plan.changes) {
                if ($change.action -eq 'delete' -and -not (Test-ConfirmedAbsent $change.path)) {
                    throw 'A planned deletion is no longer confirmed absent. Run a fresh preview.'
                }
            }
            if ($githubPilot) {
                $observedTip = Get-RemoteTip
                if ($observedTip -cne $tip) {
                    if ($tip -and -not (Test-GitAncestor $tip $observedTip)) { throw 'The GitHub branch rewound during sync.' }
                    $tip = $observedTip
                    continue
                }
            }
            else { Assert-PlainDirectory $destinationPath }
            $state.pendingPush = @{ commit = $candidate; files = $plan.files }
            Save-SyncState
            $pushParent = $tip
            if (-not $pushParent) { $pushParent = $zeroObjectId }
            $pushArguments = @('push', '--porcelain', '--no-follow-tags', '--', $destinationUri, "${candidate}:${branchRef}")
            $pushed = Invoke-Git $pushArguments -PushGuard @{ commit = $candidate; parent = $pushParent } -AllowFailure
            if ($pushed.ExitCode -ne 0) {
                $observedTip = Get-RemoteTip
                Resolve-PendingPush $observedTip
                if ($result.pushedRevision -cne $candidate) {
                    if ($observedTip -cne $tip) {
                        if ($tip -and -not (Test-GitAncestor $tip $observedTip)) { throw 'The destination branch rewound during the push.' }
                        $tip = $observedTip
                        continue
                    }
                    throw "Destination rejected the backup push (Git exit $($pushed.ExitCode))."
                }
            }
            $state.files = $plan.files
            $state.lastVerifiedRevision = $candidate
            $state.lastPushedRevision = $candidate
            $state.pendingPush = $null
            $result.pushedRevision = $candidate
            $result.status = 'synced'
            break
        }
    }
    if ($result.status -eq 'pending') { throw 'The destination kept moving during sync. Retry at the next checkpoint.' }
}
catch {
    $result.status = 'pending'
    $result.error = $_.Exception.Message
}
finally {
    if ($result.pending.Count -gt 0 -and $Action -eq 'sync') { $result.status = 'pending' }
    if ($null -ne $state) {
        $result.lastVerifiedRevision = $state.lastVerifiedRevision
        $result.lastPushedRevision = $state.lastPushedRevision
    }
    try {
        if ($canSaveState) {
            $state.lastResult = $result
            Save-SyncState
        }
    }
    catch {
        $result.status = 'pending'
        $result.error = "Could not save sync state. $($result.error)"
    }
    finally {
        if ($null -ne $lock) { $lock.Dispose() }
        if ($scratch -and [Directory]::Exists($scratch)) {
            try {
                Assert-PlainDirectory $scratch
                if ([Path]::GetDirectoryName($scratch) -cne $tempParent -or
                    [Path]::GetFileName($scratch) -cnotmatch '^documentation-sync-[a-f0-9]{32}$') {
                    throw 'Unexpected scratch path.'
                }
                Remove-Item -LiteralPath $scratch -Recurse -Force
            }
            catch {
                $result.cleanupWarning = "Could not remove the scratch repository at '$scratch'."
            }
        }
    }
}

ConvertTo-Json -InputObject $result -Depth 10
if ($result.error -or $result.pending.Count -gt 0) { exit 2 }
exit 0

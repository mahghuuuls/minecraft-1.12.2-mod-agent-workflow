function ConvertFrom-SharedOwnerDefaults([string]$Text) {
    $yesNo = '\A(?:Yes|No)\z'
    $plainTone = "\A[\p{L}\p{N} ,.!?()'-]{1,400}\z"
    $rules = @{
        'Local Source' = @{
            'Local owner-defaults file' = '\A`[A-Za-z]:\\(?:[A-Za-z0-9][A-Za-z0-9 ._-]*\\)+owner-defaults\.md`\z'
        }
        'Project Setup Preferences' = @{
            'Implementation language' = '\A(?:Java|Kotlin)\z'
            'Distribution platform' = '\A(?:CurseForge|Modrinth|Both|Ask)\z'
            'License' = '\A[A-Za-z0-9][A-Za-z0-9.+-]{0,39}\z'
            'Development Java version' = '\A[1-9][0-9]?\z'
            'Release Java bytecode' = '\A[1-9][0-9]?\z'
        }
        'Chat Format Preferences' = @{
            'Actions on separate lines' = $yesNo
            'One command per code block' = $yesNo
            'Message length' = '\A(?:Short|Balanced|Detailed)\z'
            'One step at a time' = $yesNo
            'Maximum options per decision' = '\A[2-5]\z'
            'Preferred option first' = $yesNo
            'Self-contained test cards' = $yesNo
        }
        'Public Copy Preferences' = @{
            'Player-facing copy length' = '\A(?:Proportionate|Minimal|Expanded)\z'
            'ASCII punctuation' = $yesNo
            'Mod-page tone' = $plainTone
            'Integration layout' = '\A(?:One section per integration with one line per item|Project-specific)\z'
            'Link named mods' = $yesNo
            'AI usage disclaimer wording' = '\A(?:Workflow default|Project-specific)\z'
            'AI usage disclaimer link' = '\Ahttps://github\.com/[A-Za-z0-9-]+/[A-Za-z0-9_.-]+\z'
            'Unverified validation notes on player pages' = '\A(?:When material to player use|Internal only|Project-specific)\z'
            'AI disclaimer color' = '\A(?:Yellow when supported|Default)\z'
            'Verify rendered mod page' = $yesNo
        }
    }
    if (Test-CredentialText $Text) { throw 'Shared owner defaults contain a possible credential.' }
    $lines = $Text -split '\r?\n'
    if ($lines[0] -cne '# Shared Owner Defaults') { throw 'Use the Shared Owner Defaults format for the root file.' }
    $preferences = [ordered]@{}
    $section = $null
    foreach ($line in ($lines | Select-Object -Skip 1)) {
        if ($line -eq '') { continue }
        if ($line -cmatch '\A## (?<section>.+)\z') {
            $section = $Matches.section
            if (-not $rules.ContainsKey($section) -or $preferences.Contains($section)) {
                throw 'Unsupported or duplicate section in shared owner defaults.'
            }
            $preferences[$section] = [ordered]@{}
            continue
        }
        if (-not $section -or $line -cnotmatch '\A- (?<key>[^:]+): (?<value>.+)\z') {
            throw 'Shared owner defaults accept only named preference fields.'
        }
        $key = $Matches.key
        $value = $Matches.value
        if (-not $rules[$section].ContainsKey($key) -or $preferences[$section].Contains($key) -or
            $value -cnotmatch $rules[$section][$key]) {
            throw 'Unsupported, duplicate, or invalid preference in shared owner defaults.'
        }
        $preferences[$section][$key] = $value
    }
    # A locator in the backup never selects a local file or becomes a preference.
    if ($preferences.Contains('Local Source')) { $preferences.Remove('Local Source') }
    return $preferences
}

function Assert-FullOwnerDefaultsText([string]$Text) {
    if ($Text -cnotmatch '\A\uFEFF?# Owner Defaults(?:\r?\n|\z)') {
        throw 'A full backup must use the local owner-defaults.md with its Owner Defaults heading.'
    }
    $blocked = Get-TextBlockReason ($utf8.GetBytes($Text))
    if ($blocked) { throw "Full owner-defaults content is blocked ($blocked)." }
}

function Invoke-SharedOwnerDefaults([string]$Tip) {
    $path = 'owner-defaults.md'
    $portableLimit = 16KB
    $fullLimit = 128KB
    $anchor = 'unborn'
    if ($Tip) { $anchor = $Tip }
    if ($Action -eq 'sync') {
        if ($ApprovedPlan -cnotmatch '\Ashared\.(?<anchor>unborn|[a-f0-9]{40}|[a-f0-9]{64})\.[a-f0-9]{64}\z') {
            throw 'Use the approval receipt from a shared owner-defaults preview.'
        }
        $anchor = $Matches.anchor
    }
    elseif ($ApprovedPlan) { throw 'Use the approval receipt with sync.' }

    $afterBlob = $null
    $proposedContent = $null
    $proposedPreferences = $null
    if ($Action -ne 'read') {
        $sourcePath = Resolve-LocalPath $OwnerDefaultsCandidate
        if ($FullOwnerDefaultsBackup -and [Path]::GetFileName($sourcePath) -ine $path) {
            throw 'A full backup must use the local owner-defaults.md directly.'
        }
        $sourceLimit = if ($FullOwnerDefaultsBackup) { $fullLimit } else { $portableLimit }
        $source = Read-BackupBytes $sourcePath $sourceLimit
        if ($source.blocked) { throw "Shared owner-defaults candidate is blocked ($($source.blocked))." }
        $proposedContent = $utf8.GetString($source.bytes)
        if ($FullOwnerDefaultsBackup) { Assert-FullOwnerDefaultsText $proposedContent }
        else { $proposedPreferences = ConvertFrom-SharedOwnerDefaults $proposedContent }
        $afterBlob = Write-Blob $source.bytes
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $result.attempts = $attempt
        $result.remoteRevision = $Tip
        if ($anchor -cne 'unborn' -and -not (Test-GitAncestor $anchor $Tip)) {
            throw 'The destination branch no longer contains the shared preview revision.'
        }
        $current = $null
        $beforeBlob = $null
        $currentContent = $null
        $currentPreferences = $null
        $currentFormat = $null
        if ($Tip) { $current = (Get-GitTree $Tip)[$path] }
        if ($null -ne $current) {
            if ($current.path -cne $path -or $current.mode -cne '100644') {
                throw 'The root owner-defaults path is not a usable ordinary file.'
            }
            $currentSize = [long](Invoke-Git @('cat-file', '-s', $current.blob)).Output.Trim()
            if ($currentSize -gt $fullLimit) { throw 'The root owner-defaults file exceeds the backup size limit.' }
            $beforeBlob = $current.blob
            $currentContent = (Invoke-Git @('cat-file', 'blob', $beforeBlob)).Output
            if ($currentContent -cmatch '\A\uFEFF?# Owner Defaults(?:\r?\n|\z)') {
                Assert-FullOwnerDefaultsText $currentContent
                $currentFormat = 'full'
            }
            else {
                if ($currentSize -gt $portableLimit) { throw 'The portable owner-defaults file exceeds the backup size limit.' }
                $currentPreferences = ConvertFrom-SharedOwnerDefaults $currentContent
                $currentFormat = 'portable'
            }
        }
        $result.backupFormat = $currentFormat
        $result.backupBlob = $beforeBlob
        if ($Action -eq 'read') {
            $result.preferences = $currentPreferences
            $result.status = if ($beforeBlob) { 'read' } else { 'missing' }
            return
        }
        if ($currentFormat -eq 'full' -and -not $FullOwnerDefaultsBackup) {
            throw 'This destination has a full backup. Use the local owner-defaults.md in full-backup mode.'
        }

        $result.currentContent = $currentContent
        $result.proposedContent = $proposedContent
        $result.preferences = $proposedPreferences
        $result.proposedFormat = if ($FullOwnerDefaultsBackup) { 'full' } else { 'portable' }
        $result.changes = @()
        $operation = if ($beforeBlob) { 'update' } else { 'add' }
        if ($beforeBlob -cne $afterBlob) {
            $result.changes = @([ordered]@{ path = $path; action = $operation; beforeBlob = $beforeBlob; afterBlob = $afterBlob })
        }
        $snapshot = [ordered]@{
            schemaVersion = 1; destination = $destinationKey; branch = $branchRef
            anchor = $anchor; path = $path; beforeBlob = $beforeBlob; afterBlob = $afterBlob
        }
        if ($FullOwnerDefaultsBackup) { $snapshot.fullBackup = $true }
        $json = ConvertTo-Json -InputObject $snapshot -Compress
        $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($json))).ToLowerInvariant()
        $receipt = "shared.$anchor.$digest"
        if ($Action -eq 'preview') {
            $result.approval = $receipt
            $result.status = 'preview'
            return
        }
        if ($ApprovedPlan -cne $receipt) { throw 'The shared owner-defaults preview is stale. Review a fresh preview.' }
        if ($beforeBlob -ceq $afterBlob) {
            $result.status = 'unchanged'
            return
        }

        Initialize-PushGuard
        $plan = @{ changes = @(@{ path = $path; action = $operation; blob = $afterBlob }) }
        $commit = New-BackupCommit $plan $Tip '' 'Update shared owner defaults'
        if ($githubPilot) {
            $observed = Get-RemoteTip
            if ($observed -cne $Tip) {
                if ($Tip -and -not (Test-GitAncestor $Tip $observed)) { throw 'The destination branch rewound during shared sync.' }
                $Tip = $observed
                continue
            }
        }
        else { Assert-PlainDirectory $destinationPath }
        $push = Invoke-GuardedPush $commit $Tip
        if ($push.ExitCode -ne 0) {
            $observed = Get-RemoteTip
            if (-not (Test-GitAncestor $commit $observed)) {
                if ($observed -ceq $Tip) { throw 'The destination rejected the shared owner-defaults push.' }
                if ($Tip -and -not (Test-GitAncestor $Tip $observed)) { throw 'The destination branch rewound during shared sync.' }
                $Tip = $observed
                continue
            }
        }
        $result.status = 'synced'
        $result.pushedRevision = $commit
        return
    }
    throw 'The destination kept moving during shared sync. Retry with the same approval if the root file is unchanged.'
}

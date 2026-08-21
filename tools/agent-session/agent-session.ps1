[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Action,

    [string]$Session,
    [string]$Participant,
    [string]$Role,
    [string]$Project,
    [string]$Revision,
    [string]$Topic,
    [int]$ExpiresMinutes = 60,
    [int]$MaxParticipants = 2,
    [int]$MaxMessages = 12,

    [string]$Type = 'response',

    [string]$EvidenceLabel = 'none',

    [string]$Message,
    [string]$MessageFile,
    [string]$ReplyTo,
    [string]$Summary,
    [string]$SummaryFile,
    [string]$After,
    [int]$TimeoutSeconds = 30,
    [string]$StoreDirectory
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

$Utf8NoBom = New-Object Text.UTF8Encoding($false)
$InvariantCulture = [Globalization.CultureInfo]::InvariantCulture
$RequiredSummaryHeadings = @(
    'Agreed Contract',
    'Provider Feedback',
    'Consumer Consequences',
    'Unresolved Questions',
    'Owner Decisions Required',
    'Recommended Next Actions'
)
$AllowedActions = @('start', 'join', 'send', 'read', 'wait', 'close', 'status', 'report')
$AllowedMessageTypes = @('fact', 'question', 'proposal', 'objection', 'decision-request', 'response', 'final-position')
$AllowedEvidenceLabels = @('none', 'observed', 'inspected', 'inferred')

function Assert-AllowedValue {
    param([string]$Value, [string[]]$Allowed, [string]$Label)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Allowed -notcontains $Value) {
        throw "$Label must be one of: $($Allowed -join ', ')."
    }
}

function Assert-OneLineText {
    param([string]$Value, [string]$Label, [int]$MaximumLength, [bool]$AllowEmpty = $false)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($AllowEmpty) { return }
        throw "$Label is required."
    }
    if ($Value.Length -gt $MaximumLength) {
        throw "$Label must not exceed $MaximumLength characters."
    }
    foreach ($character in $Value.ToCharArray()) {
        if ([char]::IsControl($character)) {
            throw "$Label must be a single line without control characters."
        }
    }
}

function Assert-ParticipantId {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') {
        throw 'Participant must use 1..64 letters, digits, periods, underscores, or hyphens and must start with a letter or digit.'
    }
}

function Assert-SessionId {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[A-Fa-f0-9]{24}$') {
        throw 'Session must be the 24-character hexadecimal code returned by start.'
    }
}

function Assert-MessageId {
    param([string]$Value, [string]$Label, [bool]$AllowEmpty = $false)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($AllowEmpty) { return }
        throw "$Label is required."
    }
    if ($Value -notmatch '^\d{8}T\d{13}Z-[a-f0-9]{32}$') {
        throw "$Label is not a valid message ID."
    }
}

function Get-StoreRoot {
    if (-not [string]::IsNullOrWhiteSpace($StoreDirectory)) {
        return [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($StoreDirectory))
    }
    if (-not [string]::IsNullOrWhiteSpace($env:MINECRAFT_MOD_AGENT_SESSION_ROOT)) {
        return [IO.Path]::GetFullPath($env:MINECRAFT_MOD_AGENT_SESSION_ROOT)
    }
    return [IO.Path]::Combine([IO.Path]::GetTempPath(), 'minecraft-1.12.2-mod-agent-sessions')
}

function Get-SessionDirectory {
    param([string]$StoreRoot, [string]$SessionId)

    Assert-SessionId $SessionId
    return Join-Path $StoreRoot $SessionId.ToUpperInvariant()
}

function Assert-SessionDirectoryExists {
    param([string]$SessionDirectory, [string]$StoreRoot)

    if (-not [IO.Directory]::Exists($SessionDirectory)) {
        throw "Session was not found in the shared store: $StoreRoot"
    }
}

function Get-ParticipantPath {
    param([string]$SessionDirectory, [string]$ParticipantId)

    Assert-ParticipantId $ParticipantId
    return Join-Path (Join-Path $SessionDirectory 'participants') ($ParticipantId.ToLowerInvariant() + '.json')
}

function Get-MessagePath {
    param([string]$SessionDirectory, [string]$MessageId)

    Assert-MessageId $MessageId 'Message ID'
    return Join-Path (Join-Path $SessionDirectory 'messages') ($MessageId + '.json')
}

function New-SessionId {
    $bytes = New-Object byte[] 12
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }
    return (($bytes | ForEach-Object { $_.ToString('X2') }) -join '')
}

function New-MessageId {
    $timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ', $InvariantCulture)
    return "$timestamp-$([Guid]::NewGuid().ToString('N'))"
}

function Write-TextAtomic {
    param([string]$Path, [string]$Content)

    $parent = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($parent)) {
        [IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    $temporaryPath = "$Path.tmp-$([Guid]::NewGuid().ToString('N'))"
    [IO.File]::WriteAllText($temporaryPath, $Content, $Utf8NoBom)
    try {
        if ([IO.File]::Exists($Path)) {
            $backupPath = "$Path.bak-$([Guid]::NewGuid().ToString('N'))"
            try {
                [IO.File]::Replace($temporaryPath, $Path, $backupPath)
            }
            finally {
                if ([IO.File]::Exists($backupPath)) {
                    [IO.File]::Delete($backupPath)
                }
            }
        }
        else {
            [IO.File]::Move($temporaryPath, $Path)
        }
    }
    finally {
        if ([IO.File]::Exists($temporaryPath)) {
            [IO.File]::Delete($temporaryPath)
        }
    }
}

function Write-JsonAtomic {
    param([string]$Path, $Value)

    $json = ($Value | ConvertTo-Json -Depth 12) + "`r`n"
    Write-TextAtomic $Path $json
}

function Read-JsonFile {
    param([string]$Path, [string]$Label)

    if (-not [IO.File]::Exists($Path)) {
        throw "$Label not found: $Path"
    }
    return ([IO.File]::ReadAllText($Path) | ConvertFrom-Json)
}

function Read-Metadata {
    param([string]$SessionDirectory)

    $metadata = Read-JsonFile (Join-Path $SessionDirectory 'session.json') 'Session metadata'
    if ($metadata.schemaVersion -ne 1) {
        throw 'Unsupported agent-session schema version.'
    }
    return $metadata
}

function Get-EffectiveState {
    param($Metadata)

    if ($Metadata.state -ne 'open') { return [string]$Metadata.state }
    $expiresAt = [DateTime]::Parse([string]$Metadata.expiresAtUtc, $InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
    if ([DateTime]::UtcNow -gt $expiresAt.ToUniversalTime()) { return 'expired' }
    return 'open'
}

function Assert-OpenSession {
    param($Metadata)

    $state = Get-EffectiveState $Metadata
    if ($state -ne 'open') {
        throw "Session is $state and cannot be changed."
    }
}

function Invoke-WithSessionLock {
    param([string]$SessionDirectory, [scriptblock]$Operation)

    $lockPath = Join-Path $SessionDirectory '.lock'
    $stream = $null
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        try {
            $stream = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            break
        }
        catch [IO.IOException] {
            Start-Sleep -Milliseconds 100
        }
    }
    if ($null -eq $stream) {
        throw 'Could not acquire the session lock within five seconds.'
    }
    try {
        return & $Operation
    }
    finally {
        $stream.Dispose()
    }
}

function Get-Participants {
    param([string]$SessionDirectory)

    $directory = Join-Path $SessionDirectory 'participants'
    if (-not [IO.Directory]::Exists($directory)) { return @() }
    return @(Get-ChildItem -LiteralPath $directory -File -Filter '*.json' | Sort-Object Name | ForEach-Object {
        Read-JsonFile $_.FullName 'Participant record'
    })
}

function Get-Messages {
    param([string]$SessionDirectory, [string]$AfterId)

    if (-not [string]::IsNullOrWhiteSpace($AfterId)) {
        Assert-MessageId $AfterId 'After'
    }
    $directory = Join-Path $SessionDirectory 'messages'
    if (-not [IO.Directory]::Exists($directory)) { return @() }
    $files = @(Get-ChildItem -LiteralPath $directory -File -Filter '*.json' | Sort-Object Name)
    if (-not [string]::IsNullOrWhiteSpace($AfterId)) {
        $files = @($files | Where-Object { [string]::CompareOrdinal($_.BaseName, $AfterId) -gt 0 })
    }
    return @($files | ForEach-Object { Read-JsonFile $_.FullName 'Message record' })
}

function Assert-JoinedParticipant {
    param([string]$SessionDirectory, [string]$ParticipantId)

    $path = Get-ParticipantPath $SessionDirectory $ParticipantId
    if (-not [IO.File]::Exists($path)) {
        throw "Participant '$($ParticipantId.ToLowerInvariant())' has not joined this session."
    }
    return Read-JsonFile $path 'Participant record'
}

function Get-FileText {
    param([string]$Inline, [string]$FilePath, [string]$Label, [int]$MaximumLength)

    if (-not [string]::IsNullOrWhiteSpace($Inline) -and -not [string]::IsNullOrWhiteSpace($FilePath)) {
        throw "$Label accepts either inline text or a file, not both."
    }
    if (-not [string]::IsNullOrWhiteSpace($FilePath)) {
        $resolved = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath))
        if (-not [IO.File]::Exists($resolved)) { throw "$Label file not found: $resolved" }
        $value = [IO.File]::ReadAllText($resolved)
    }
    else {
        $value = $Inline
    }
    if ([string]::IsNullOrWhiteSpace($value)) { throw "$Label is required." }
    if ($value.Length -gt $MaximumLength) { throw "$Label must not exceed $MaximumLength characters." }
    if ($value.IndexOf([char]0) -ge 0) { throw "$Label must not contain a null character." }
    return $value.Trim()
}

function Assert-ClosingSummary {
    param([string]$Summary)

    foreach ($heading in $RequiredSummaryHeadings) {
        $pattern = '(?m)^## ' + [regex]::Escape($heading) + '\s*$'
        if ($Summary -notmatch $pattern) {
            throw "Closing summary is missing required heading: ## $heading"
        }
    }
}

function Escape-MarkdownTableValue {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return $Value.Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function New-SessionReport {
    param($Metadata, [object[]]$Participants, [object[]]$Messages, [string]$Summary)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Cross-Project Agent Consultation')
    $lines.Add('')
    $lines.Add("- Session: ``$($Metadata.session)``")
    $lines.Add("- Topic: $($Metadata.topic)")
    $lines.Add("- Created UTC: $($Metadata.createdAtUtc)")
    $lines.Add("- Closed UTC: $([DateTime]::UtcNow.ToString('o'))")
    $lines.Add('')
    $lines.Add('## Participants')
    $lines.Add('')
    $lines.Add('| Participant | Role | Project | Revision |')
    $lines.Add('| --- | --- | --- | --- |')
    foreach ($participantRecord in $Participants) {
        $lines.Add("| $(Escape-MarkdownTableValue $participantRecord.participant) | $(Escape-MarkdownTableValue $participantRecord.role) | $(Escape-MarkdownTableValue $participantRecord.project) | $(Escape-MarkdownTableValue $participantRecord.revision) |")
    }
    $lines.Add('')
    $lines.Add($Summary.Trim())
    $lines.Add('')
    $lines.Add('## Transcript')
    $lines.Add('')
    foreach ($messageRecord in $Messages) {
        $lines.Add("### $($messageRecord.participant): $($messageRecord.type)")
        $lines.Add('')
        $lines.Add("- Message: ``$($messageRecord.id)``")
        $lines.Add("- Created UTC: $($messageRecord.createdAtUtc)")
        $lines.Add("- Evidence label: $($messageRecord.evidenceLabel)")
        if (-not [string]::IsNullOrWhiteSpace([string]$messageRecord.replyTo)) {
            $lines.Add("- Reply to: ``$($messageRecord.replyTo)``")
        }
        $lines.Add('')
        $lines.Add([string]$messageRecord.body)
        $lines.Add('')
    }
    $lines.Add('The report records an agent consultation. It does not approve requirements, architecture, implementation, commits, or external actions.')
    return ($lines -join "`r`n") + "`r`n"
}

function Write-JsonOutput {
    param($Value)
    Write-Output ($Value | ConvertTo-Json -Depth 12)
}

function Get-AgentSessionErrorCode {
    param([string]$Message)

    switch -Wildcard ($Message) {
        'Session was not found in the shared store:*' { return 'session_not_found' }
        'Session participant limit has been reached.*' { return 'participant_limit_reached' }
        'Session message limit has been reached.*' { return 'message_limit_reached' }
        'Session is closed and cannot be changed.*' { return 'session_closed' }
        'Session is expired and cannot be changed.*' { return 'session_expired' }
        "Participant '*' has not joined this session.*" { return 'participant_not_joined' }
        'Could not acquire the session lock within five seconds.*' { return 'session_lock_timeout' }
        'Closing summary is missing required heading:*' { return 'invalid_closing_summary' }
        '* accepts either inline text or a file, not both.*' { return 'conflicting_input' }
        '* file not found:*' { return 'input_file_not_found' }
        'Session report is available only after close.*' { return 'report_unavailable' }
        default { return 'command_failed' }
    }
}

function Write-JsonError {
    param([string]$Code, [string]$Message, [string]$AttemptedAction)

    $record = [ordered]@{
        status = 'error'
        code = $Code
        message = $Message
        action = $AttemptedAction
    }
    [Console]::Error.WriteLine(($record | ConvertTo-Json -Compress))
}

try {
    Assert-AllowedValue $Action $AllowedActions 'Action'
    Assert-AllowedValue $Type $AllowedMessageTypes 'Type'
    Assert-AllowedValue $EvidenceLabel $AllowedEvidenceLabels 'EvidenceLabel'
    $storeRoot = Get-StoreRoot

    switch ($Action) {
    'start' {
        Assert-ParticipantId $Participant
        $participantId = $Participant.ToLowerInvariant()
        Assert-OneLineText $Role 'Role' 100
        Assert-OneLineText $Project 'Project' 200
        Assert-OneLineText $Topic 'Topic' 500
        if (-not [string]::IsNullOrWhiteSpace($Revision)) { Assert-OneLineText $Revision 'Revision' 128 }
        if ($ExpiresMinutes -lt 5 -or $ExpiresMinutes -gt 1440) { throw 'ExpiresMinutes must be between 5 and 1440.' }
        if ($MaxParticipants -lt 2 -or $MaxParticipants -gt 4) { throw 'MaxParticipants must be between 2 and 4.' }
        if ($MaxMessages -lt 4 -or $MaxMessages -gt 30) { throw 'MaxMessages must be between 4 and 30.' }

        [IO.Directory]::CreateDirectory($storeRoot) | Out-Null
        $sessionId = $null
        $sessionDirectory = $null
        for ($attempt = 0; $attempt -lt 10; $attempt++) {
            $candidate = New-SessionId
            $candidateDirectory = Join-Path $storeRoot $candidate
            if (-not [IO.Directory]::Exists($candidateDirectory)) {
                [IO.Directory]::CreateDirectory($candidateDirectory) | Out-Null
                $sessionId = $candidate
                $sessionDirectory = $candidateDirectory
                break
            }
        }
        if ($null -eq $sessionId) { throw 'Could not allocate a unique session code.' }

        [IO.Directory]::CreateDirectory((Join-Path $sessionDirectory 'participants')) | Out-Null
        [IO.Directory]::CreateDirectory((Join-Path $sessionDirectory 'messages')) | Out-Null
        $createdAt = [DateTime]::UtcNow
        $metadata = [ordered]@{
            schemaVersion = 1
            session = $sessionId
            topic = $Topic
            state = 'open'
            createdAtUtc = $createdAt.ToString('o')
            expiresAtUtc = $createdAt.AddMinutes($ExpiresMinutes).ToString('o')
            maxParticipants = $MaxParticipants
            maxMessages = $MaxMessages
            createdBy = $participantId
            closedAtUtc = $null
            closedBy = $null
            reportFile = $null
        }
        $participantRecord = [ordered]@{
            schemaVersion = 1
            participant = $participantId
            role = $Role
            project = $Project
            revision = if ([string]::IsNullOrWhiteSpace($Revision)) { '' } else { $Revision }
            joinedAtUtc = $createdAt.ToString('o')
        }
        Write-JsonAtomic (Join-Path $sessionDirectory 'session.json') $metadata
        Write-JsonAtomic (Get-ParticipantPath $sessionDirectory $participantId) $participantRecord
        Write-JsonOutput ([ordered]@{
            status = 'started'
            session = $sessionId
            participant = $participantId
            expiresAtUtc = $metadata.expiresAtUtc
            maxParticipants = $MaxParticipants
            maxMessages = $MaxMessages
        })
    }

    'join' {
        Assert-SessionId $Session
        Assert-ParticipantId $Participant
        $participantId = $Participant.ToLowerInvariant()
        Assert-OneLineText $Role 'Role' 100
        Assert-OneLineText $Project 'Project' 200
        if (-not [string]::IsNullOrWhiteSpace($Revision)) { Assert-OneLineText $Revision 'Revision' 128 }
        $sessionDirectory = Get-SessionDirectory $storeRoot $Session
        Assert-SessionDirectoryExists $sessionDirectory $storeRoot

        $result = Invoke-WithSessionLock $sessionDirectory {
            $metadata = Read-Metadata $sessionDirectory
            Assert-OpenSession $metadata
            $participantPath = Get-ParticipantPath $sessionDirectory $participantId
            if ([IO.File]::Exists($participantPath)) {
                $existing = Read-JsonFile $participantPath 'Participant record'
                $revisionValue = if ([string]::IsNullOrWhiteSpace($Revision)) { '' } else { $Revision }
                if ($existing.role -ne $Role -or $existing.project -ne $Project -or $existing.revision -ne $revisionValue) {
                    throw "Participant '$participantId' already joined with different identity information."
                }
                return [ordered]@{ status = 'already-joined'; session = $metadata.session; participant = $participantId }
            }
            $participants = @(Get-Participants $sessionDirectory)
            if ($participants.Count -ge [int]$metadata.maxParticipants) { throw 'Session participant limit has been reached.' }
            $participantRecord = [ordered]@{
                schemaVersion = 1
                participant = $participantId
                role = $Role
                project = $Project
                revision = if ([string]::IsNullOrWhiteSpace($Revision)) { '' } else { $Revision }
                joinedAtUtc = [DateTime]::UtcNow.ToString('o')
            }
            Write-JsonAtomic $participantPath $participantRecord
            return [ordered]@{ status = 'joined'; session = $metadata.session; participant = $participantId }
        }
        Write-JsonOutput $result
    }

    'send' {
        Assert-SessionId $Session
        Assert-ParticipantId $Participant
        $participantId = $Participant.ToLowerInvariant()
        $body = Get-FileText $Message $MessageFile 'Message' 8000
        if (-not [string]::IsNullOrWhiteSpace($ReplyTo)) { Assert-MessageId $ReplyTo 'ReplyTo' }
        $sessionDirectory = Get-SessionDirectory $storeRoot $Session
        Assert-SessionDirectoryExists $sessionDirectory $storeRoot

        $result = Invoke-WithSessionLock $sessionDirectory {
            $metadata = Read-Metadata $sessionDirectory
            Assert-OpenSession $metadata
            Assert-JoinedParticipant $sessionDirectory $participantId | Out-Null
            $messages = @(Get-Messages $sessionDirectory '')
            if ($messages.Count -ge [int]$metadata.maxMessages) { throw 'Session message limit has been reached.' }
            if (-not [string]::IsNullOrWhiteSpace($ReplyTo) -and -not [IO.File]::Exists((Get-MessagePath $sessionDirectory $ReplyTo))) {
                throw "Reply target was not found: $ReplyTo"
            }
            $messageId = New-MessageId
            $record = [ordered]@{
                schemaVersion = 1
                id = $messageId
                session = [string]$metadata.session
                participant = $participantId
                type = $Type
                evidenceLabel = $EvidenceLabel
                replyTo = if ([string]::IsNullOrWhiteSpace($ReplyTo)) { '' } else { $ReplyTo }
                createdAtUtc = [DateTime]::UtcNow.ToString('o')
                body = $body
            }
            Write-JsonAtomic (Get-MessagePath $sessionDirectory $messageId) $record
            return [ordered]@{ status = 'sent'; session = $metadata.session; message = $messageId }
        }
        Write-JsonOutput $result
    }

    'read' {
        Assert-SessionId $Session
        $sessionDirectory = Get-SessionDirectory $storeRoot $Session
        Assert-SessionDirectoryExists $sessionDirectory $storeRoot
        $metadata = Read-Metadata $sessionDirectory
        $messages = @(Get-Messages $sessionDirectory $After)
        $lastMessage = if ($messages.Count -eq 0) { $After } else { [string]$messages[$messages.Count - 1].id }
        Write-JsonOutput ([ordered]@{
            status = 'read'
            session = [string]$metadata.session
            state = Get-EffectiveState $metadata
            messages = @($messages)
            lastMessage = if ([string]::IsNullOrWhiteSpace($lastMessage)) { '' } else { $lastMessage }
        })
    }

    'wait' {
        Assert-SessionId $Session
        Assert-ParticipantId $Participant
        $participantId = $Participant.ToLowerInvariant()
        if ($TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 60) { throw 'TimeoutSeconds must be between 1 and 60.' }
        $sessionDirectory = Get-SessionDirectory $storeRoot $Session
        Assert-SessionDirectoryExists $sessionDirectory $storeRoot
        Assert-JoinedParticipant $sessionDirectory $participantId | Out-Null
        $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        do {
            $metadata = Read-Metadata $sessionDirectory
            $messages = @(Get-Messages $sessionDirectory $After | Where-Object { $_.participant -ne $participantId })
            if ($messages.Count -gt 0) {
                Write-JsonOutput ([ordered]@{
                    status = 'message'
                    session = [string]$metadata.session
                    state = Get-EffectiveState $metadata
                    messages = @($messages)
                    lastMessage = [string]$messages[$messages.Count - 1].id
                })
                exit 0
            }
            $state = Get-EffectiveState $metadata
            if ($state -ne 'open') {
                Write-JsonOutput ([ordered]@{ status = 'ended'; session = [string]$metadata.session; state = $state; messages = @() })
                exit 0
            }
            Start-Sleep -Milliseconds 250
        } while ([DateTime]::UtcNow -lt $deadline)
        Write-JsonOutput ([ordered]@{ status = 'timeout'; session = [string]$metadata.session; state = 'open'; messages = @() })
    }

    'close' {
        Assert-SessionId $Session
        Assert-ParticipantId $Participant
        $participantId = $Participant.ToLowerInvariant()
        $summary = Get-FileText $Summary $SummaryFile 'Closing summary' 16000
        Assert-ClosingSummary $summary
        $sessionDirectory = Get-SessionDirectory $storeRoot $Session
        Assert-SessionDirectoryExists $sessionDirectory $storeRoot

        $result = Invoke-WithSessionLock $sessionDirectory {
            $metadata = Read-Metadata $sessionDirectory
            Assert-OpenSession $metadata
            Assert-JoinedParticipant $sessionDirectory $participantId | Out-Null
            $participants = @(Get-Participants $sessionDirectory)
            if ($participants.Count -lt 2) { throw 'At least two participants must join before the session can close.' }
            $messages = @(Get-Messages $sessionDirectory '')
            if ($messages.Count -lt 2) { throw 'At least two messages must be exchanged before the session can close.' }
            $messageParticipants = @($messages | Select-Object -ExpandProperty participant -Unique)
            if ($messageParticipants.Count -lt 2) { throw 'At least two participants must contribute messages before the session can close.' }
            $reportPath = Join-Path $sessionDirectory 'report.md'
            if ([IO.File]::Exists($reportPath)) { throw 'Session report already exists.' }
            $closedAt = [DateTime]::UtcNow.ToString('o')
            $report = New-SessionReport $metadata $participants $messages $summary
            Write-TextAtomic $reportPath $report
            $metadata.state = 'closed'
            $metadata.closedAtUtc = $closedAt
            $metadata.closedBy = $participantId
            $metadata.reportFile = 'report.md'
            Write-JsonAtomic (Join-Path $sessionDirectory 'session.json') $metadata
            return [ordered]@{
                status = 'closed'
                session = [string]$metadata.session
                closedBy = $participantId
                participants = $participants.Count
                messages = $messages.Count
            }
        }
        Write-JsonOutput $result
    }

    'status' {
        Assert-SessionId $Session
        $sessionDirectory = Get-SessionDirectory $storeRoot $Session
        Assert-SessionDirectoryExists $sessionDirectory $storeRoot
        $metadata = Read-Metadata $sessionDirectory
        $participants = @(Get-Participants $sessionDirectory)
        $messages = @(Get-Messages $sessionDirectory '')
        Write-JsonOutput ([ordered]@{
            status = 'status'
            session = [string]$metadata.session
            topic = [string]$metadata.topic
            state = Get-EffectiveState $metadata
            participants = @($participants)
            messageCount = $messages.Count
            maxMessages = [int]$metadata.maxMessages
            expiresAtUtc = [string]$metadata.expiresAtUtc
            reportAvailable = [IO.File]::Exists((Join-Path $sessionDirectory 'report.md'))
        })
    }

    'report' {
        Assert-SessionId $Session
        $sessionDirectory = Get-SessionDirectory $storeRoot $Session
        Assert-SessionDirectoryExists $sessionDirectory $storeRoot
        $metadata = Read-Metadata $sessionDirectory
        if ((Get-EffectiveState $metadata) -ne 'closed') { throw 'Session report is available only after close.' }
        $reportPath = Join-Path $sessionDirectory 'report.md'
        if (-not [IO.File]::Exists($reportPath)) { throw 'Closed session report is missing.' }
        Write-Output ([IO.File]::ReadAllText($reportPath))
    }
}
}
catch {
    $message = [string]$_.Exception.Message
    Write-JsonError (Get-AgentSessionErrorCode $message) $message $Action
    exit 1
}

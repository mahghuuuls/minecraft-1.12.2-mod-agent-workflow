[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

$Tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'agent-session.ps1'
$TestRoot = Join-Path ([IO.Path]::GetTempPath()) ('minecraft-agent-session-tests-' + [Guid]::NewGuid().ToString('N'))
$Store = Join-Path $TestRoot 'store'
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-AgentSessionJson {
    param([string[]]$Arguments)

    $commandArguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Tool) + $Arguments + @('-StoreDirectory', $Store)
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& powershell.exe @commandArguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $text = @($output | ForEach-Object { $_.ToString() }) -join "`n"
    if ($exitCode -ne 0) { throw $text }
    return ($text | ConvertFrom-Json)
}

function Invoke-AgentSessionFailureJson {
    param([string[]]$Arguments)

    $commandArguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Tool) + $Arguments + @('-StoreDirectory', $Store)
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& powershell.exe @commandArguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -eq 0) { throw 'Expected agent-session command to fail.' }
    $lines = @($output | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_.StartsWith('{') })
    if ($lines.Count -ne 1) { throw "Expected exactly one JSON error record, got $($lines.Count)." }
    return ($lines[0] | ConvertFrom-Json)
}

function Assert-FailsLike {
    param([scriptblock]$Action, [string]$Pattern, [string]$Message)

    $failedAsExpected = $false
    try {
        & $Action
    }
    catch {
        $failedAsExpected = $_.Exception.Message -like $Pattern
    }
    Assert-True $failedAsExpected $Message
}

[IO.Directory]::CreateDirectory($TestRoot) | Out-Null
try {
    Write-Host 'agent-session test: lifecycle setup'
    $started = Invoke-AgentSessionJson -Arguments @(
        'start',
        '-Participant', 'consumer-agent',
        '-Role', 'api-consumer',
        '-Project', 'example-addon',
        '-Revision', 'consumer-revision',
        '-Topic', 'Expose one deferred cache operation',
        '-MaxParticipants', '2',
        '-MaxMessages', '6',
        '-ExpiresMinutes', '10'
    )
    Assert-Equal $started.status 'started' 'Session did not start.'
    Assert-True ([string]$started.session -match '^[A-F0-9]{24}$') 'Session code is malformed.'
    $session = [string]$started.session

    $missing = Invoke-AgentSessionFailureJson -Arguments @('read', '-Session', 'AAAAAAAAAAAAAAAAAAAAAAAA')
    Assert-Equal $missing.status 'error' 'Missing session did not return error status.'
    Assert-Equal $missing.code 'session_not_found' 'Missing session returned the wrong reason code.'
    Assert-True ([string]$missing.message).Contains([IO.Path]::GetFullPath($Store)) 'Missing-session diagnostic omitted the resolved store.'

    $joined = Invoke-AgentSessionJson -Arguments @(
        'join',
        '-Session', $session,
        '-Participant', 'provider-agent',
        '-Role', 'api-provider',
        '-Project', 'example-api-mod',
        '-Revision', 'provider-revision'
    )
    Assert-Equal $joined.status 'joined' 'Provider did not join.'

    $joinedAgain = Invoke-AgentSessionJson -Arguments @(
        'join',
        '-Session', $session,
        '-Participant', 'provider-agent',
        '-Role', 'api-provider',
        '-Project', 'example-api-mod',
        '-Revision', 'provider-revision'
    )
    Assert-Equal $joinedAgain.status 'already-joined' 'Matching repeated join was not idempotent.'

    Assert-FailsLike {
        Invoke-AgentSessionJson -Arguments @(
            'join', '-Session', $session, '-Participant', 'third-agent',
            '-Role', 'reviewer', '-Project', 'third-project'
        ) | Out-Null
    } '*participant limit*' 'Participant limit was not enforced.'

    Write-Host 'agent-session test: exchange'
    $consumerMessagePath = Join-Path $TestRoot 'consumer-message.md'
    [IO.File]::WriteAllText($consumerMessagePath, "Claim: the event fires before mutation.`r`n`r`nProposal: expose deferred invalidation.", $Utf8NoBom)
    $sentConsumer = Invoke-AgentSessionJson -Arguments @(
        'send',
        '-Session', $session,
        '-Participant', 'consumer-agent',
        '-Type', 'proposal',
        '-EvidenceLabel', 'inspected',
        '-MessageFile', $consumerMessagePath
    )
    Assert-Equal $sentConsumer.status 'sent' 'Consumer message was not sent.'
    $firstMessage = [string]$sentConsumer.message

    $read = Invoke-AgentSessionJson -Arguments @('read', '-Session', $session)
    Assert-Equal @($read.messages).Count 1 'Read did not return the first message.'
    Assert-Equal $read.messages[0].participant 'consumer-agent' 'Read returned the wrong participant.'
    Assert-Equal $read.messages[0].evidenceLabel 'inspected' 'Evidence label was not retained.'

    $readAfter = Invoke-AgentSessionJson -Arguments @('read', '-Session', $session, '-After', $firstMessage)
    Assert-Equal @($readAfter.messages).Count 0 'After filter returned an already handled message.'

    $providerMessagePath = Join-Path $TestRoot 'provider-message.md'
    [IO.File]::WriteAllText($providerMessagePath, "Response: the provider can own the deferred queue.`r`n`r`nNo owner decision is required.", $Utf8NoBom)
    $sentProvider = Invoke-AgentSessionJson -Arguments @(
        'send',
        '-Session', $session,
        '-Participant', 'provider-agent',
        '-Type', 'response',
        '-EvidenceLabel', 'inferred',
        '-ReplyTo', $firstMessage,
        '-MessageFile', $providerMessagePath
    )
    $secondMessage = [string]$sentProvider.message
    Write-Host 'agent-session test: provider response sent'

    $waited = Invoke-AgentSessionJson -Arguments @(
        'wait',
        '-Session', $session,
        '-Participant', 'consumer-agent',
        '-After', $firstMessage,
        '-TimeoutSeconds', '2'
    )
    Write-Host 'agent-session test: wait returned'
    Assert-Equal $waited.status 'message' 'Wait did not return the provider response.'
    Assert-Equal @($waited.messages).Count 1 'Wait returned the wrong number of messages.'
    Assert-Equal $waited.messages[0].id $secondMessage 'Wait returned the wrong message.'

    Assert-FailsLike {
        Invoke-AgentSessionJson -Arguments @(
            'send', '-Session', $session, '-Participant', 'unknown-agent',
            '-Type', 'response', '-Message', 'This must fail.'
        ) | Out-Null
    } '*has not joined*' 'An unknown participant was allowed to send.'
    Write-Host 'agent-session test: unknown participant rejected'

    Write-Host 'agent-session test: close and report'
    $badSummaryPath = Join-Path $TestRoot 'bad-summary.md'
    [IO.File]::WriteAllText($badSummaryPath, "## Agreed Contract`r`n`r`n- Incomplete.", $Utf8NoBom)
    Assert-FailsLike {
        Invoke-AgentSessionJson -Arguments @(
            'close', '-Session', $session, '-Participant', 'consumer-agent',
            '-SummaryFile', $badSummaryPath
        ) | Out-Null
    } '*missing required heading*' 'Incomplete closing summary was accepted.'

    $summaryPath = Join-Path $TestRoot 'summary.md'
    $summary = @'
## Agreed Contract

- The provider owns deferred invalidation.

## Provider Feedback

- Expose one public operation.

## Consumer Consequences

- Replace the local queue after the API release.

## Unresolved Questions

- None.

## Owner Decisions Required

- None.

## Recommended Next Actions

- Provider implements first; consumer updates afterward.
'@
    [IO.File]::WriteAllText($summaryPath, $summary, $Utf8NoBom)

    $conflict = Invoke-AgentSessionFailureJson -Arguments @(
        'close', '-Session', $session, '-Participant', 'consumer-agent',
        '-Summary', $summary, '-SummaryFile', $summaryPath
    )
    Assert-Equal $conflict.code 'conflicting_input' 'Conflicting inline/file summary inputs returned the wrong reason code.'

    $closed = Invoke-AgentSessionJson -Arguments @(
        'close',
        '-Session', $session,
        '-Participant', 'consumer-agent',
        '-Summary', $summary
    )
    Assert-Equal $closed.status 'closed' 'Session did not close.'
    Assert-Equal $closed.participants 2 'Closing report has the wrong participant count.'
    Assert-Equal $closed.messages 2 'Closing report has the wrong message count.'

    $status = Invoke-AgentSessionJson -Arguments @('status', '-Session', $session)
    Assert-Equal $status.state 'closed' 'Status did not retain the closed state.'
    Assert-Equal $status.reportAvailable $true 'Status did not expose the closing report.'

    $reportOutput = @(& $Tool report -Session $session -StoreDirectory $Store)
    $report = $reportOutput -join "`n"
    Assert-True ($report.Contains('## Provider Feedback')) 'Report omitted the provider feedback.'
    Assert-True ($report.Contains('consumer-agent: proposal')) 'Report omitted the consumer transcript.'
    Assert-True ($report.Contains('provider-agent: response')) 'Report omitted the provider transcript.'
    Assert-True ($report.Contains('does not approve requirements')) 'Report omitted its authority limitation.'

    Assert-FailsLike {
        Invoke-AgentSessionJson -Arguments @(
            'send', '-Session', $session, '-Participant', 'consumer-agent',
            '-Type', 'response', '-Message', 'This must fail after close.'
        ) | Out-Null
    } '*closed and cannot be changed*' 'Closed session accepted another message.'

    Write-Host 'agent-session test: both participants must contribute'
    $oneSided = Invoke-AgentSessionJson -Arguments @(
        'start', '-Participant', 'only-speaker', '-Role', 'consumer',
        '-Project', 'consumer-project', '-Topic', 'One-sided exchange',
        '-MaxParticipants', '2', '-MaxMessages', '4', '-ExpiresMinutes', '10'
    )
    $oneSidedSession = [string]$oneSided.session
    Invoke-AgentSessionJson -Arguments @(
        'join', '-Session', $oneSidedSession, '-Participant', 'silent-agent',
        '-Role', 'provider', '-Project', 'provider-project'
    ) | Out-Null
    Invoke-AgentSessionJson -Arguments @(
        'send', '-Session', $oneSidedSession, '-Participant', 'only-speaker',
        '-Type', 'question', '-Message', 'Can the provider expose this operation?'
    ) | Out-Null
    Invoke-AgentSessionJson -Arguments @(
        'send', '-Session', $oneSidedSession, '-Participant', 'only-speaker',
        '-Type', 'proposal', '-Message', 'The consumer proposes a deferred operation.'
    ) | Out-Null
    Assert-FailsLike {
        Invoke-AgentSessionJson -Arguments @(
            'close', '-Session', $oneSidedSession, '-Participant', 'only-speaker',
            '-SummaryFile', $summaryPath
        ) | Out-Null
    } '*two participants must contribute*' 'A one-sided transcript was allowed to close.'

    Write-Host 'agent-session test: message bound'
    $limited = Invoke-AgentSessionJson -Arguments @(
        'start', '-Participant', 'first-agent', '-Role', 'consumer',
        '-Project', 'first-project', '-Topic', 'Message limit',
        '-MaxParticipants', '2', '-MaxMessages', '4', '-ExpiresMinutes', '10'
    )
    $limitedSession = [string]$limited.session
    Invoke-AgentSessionJson -Arguments @(
        'join', '-Session', $limitedSession, '-Participant', 'second-agent',
        '-Role', 'provider', '-Project', 'second-project'
    ) | Out-Null
    for ($index = 0; $index -lt 4; $index++) {
        $sender = if (($index % 2) -eq 0) { 'first-agent' } else { 'second-agent' }
        Invoke-AgentSessionJson -Arguments @(
            'send', '-Session', $limitedSession, '-Participant', $sender,
            '-Type', 'response', '-Message', "Bounded message $index"
        ) | Out-Null
    }
    $messageLimit = Invoke-AgentSessionFailureJson -Arguments @(
        'send', '-Session', $limitedSession, '-Participant', 'first-agent',
        '-Type', 'response', '-Message', 'One message too many.'
    )
    Assert-Equal $messageLimit.code 'message_limit_reached' 'Message limit returned the wrong reason code.'

    Write-Output 'All agent-session tests passed.'
}
finally {
    if ([IO.Directory]::Exists($TestRoot)) {
        $resolvedRoot = [IO.Path]::GetFullPath($TestRoot)
        $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not ($resolvedRoot + [IO.Path]::DirectorySeparatorChar).StartsWith($expectedParent, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolvedRoot) -notmatch '^minecraft-agent-session-tests-[a-f0-9]{32}$') {
            throw "Refusing to remove unexpected test directory: $resolvedRoot"
        }
        [IO.Directory]::Delete($resolvedRoot, $true)
    }
}

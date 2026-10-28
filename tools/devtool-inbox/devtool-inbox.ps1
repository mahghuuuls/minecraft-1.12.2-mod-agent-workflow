[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('status', 'send', 'batch', 'results')]
    [string]$Action,

    [string]$Inbox,

    [string]$Request,

    [string]$Id,

    [string]$Prefix = 'req',

    [string]$File,

    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 120,

    [ValidateRange(0, 600)]
    [int]$ClosedGraceSeconds = 5,

    [switch]$NoWait,

    [switch]$SkipStatusCheck,

    [switch]$ContinueOnMismatch,

    [switch]$Json
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Windows PowerShell does not always autoload standard modules when the tool is launched
# through the batch wrapper. Utility provides JSON commands; Management provides the
# filesystem commands.
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

$ToolVersion = '1.0.0'
$Utf8NoBom = New-Object Text.UTF8Encoding($false)
$IdRegex = New-Object regex('^[A-Za-z0-9_.-]{1,64}$')
$PollMilliseconds = 250

# Exit codes. A caller can branch on these without parsing the output.
$ExitDone = 0
$ExitFailed = 1
$ExitRefused = 2
$ExitClosed = 3
$ExitTimeout = 4
$ExitUsage = 5
$ExitMismatch = 6

function Stop-Usage {
    # A usage or input problem: say what to change, and exit with the usage code.
    param([string]$Message)
    [Console]::Error.WriteLine("devtool-inbox: $Message")
    exit $ExitUsage
}

function Resolve-InboxDirectory {
    # An explicit -Inbox wins. Otherwise the development layout (run\config\devtool\inbox)
    # and then an instance or server layout (config\devtool\inbox) under the current directory.
    if (-not [string]::IsNullOrWhiteSpace($Inbox)) {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Inbox)
        if (-not [IO.Directory]::Exists($resolved)) {
            Stop-Usage ("Inbox folder not found: $resolved")
        }
        return $resolved
    }
    foreach ($candidate in @('run\config\devtool\inbox', 'config\devtool\inbox')) {
        $path = Join-Path (Get-Location).Path $candidate
        if ([IO.Directory]::Exists($path)) { return $path }
    }
    Stop-Usage ('No inbox folder found. Pass -Inbox <folder>, normally <game directory>\config\devtool\inbox.')
}

function Get-Property {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Read-JsonFile {
    param([string]$Path)
    # Shared read: the toolkit may be writing the folder at the same moment.
    $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
    try {
        $reader = New-Object IO.StreamReader($stream, $Utf8NoBom)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    finally { $stream.Dispose() }
    return $text | ConvertFrom-Json
}

function Get-InboxStatus {
    param([string]$Directory)
    $path = Join-Path $Directory 'status.json'
    if (-not [IO.File]::Exists($path)) { return $null }
    try { return Read-JsonFile $path }
    catch {
        # status.json is replaced under a temporary name; a read can land between the two.
        Start-Sleep -Milliseconds $PollMilliseconds
        if (-not [IO.File]::Exists($path)) { return $null }
        return Read-JsonFile $path
    }
}

function Format-Status {
    param($Status)
    if ($null -eq $Status) { return 'closed' }
    $parts = @('open')
    foreach ($name in @('operator', 'world', 'openedWorldTick')) {
        $value = Get-Property $Status $name
        if ($null -ne $value) { $parts += "$name=$value" }
    }
    return ($parts -join ' ')
}

function Test-RequestLine {
    param([string]$Line)
    # The toolkit refuses these as malformed; refusing them here costs no id and no round trip.
    if ([string]::IsNullOrWhiteSpace($Line)) { Stop-Usage ('The request is empty.') }
    if ($Line.Length -gt 512) { Stop-Usage ('The request is over 512 characters.') }
    foreach ($character in $Line.ToCharArray()) {
        $code = [int]$character
        if ($code -lt 32 -or $code -gt 126) {
            Stop-Usage ('The request must be one line of printable ASCII.')
        }
    }
}

function Test-IdUsed {
    param([string]$Directory, [string]$RequestId)
    # A reused id is refused by the toolkit with a record only and no result file, so a reused
    # id would wait forever. Any file that carries the id counts as used.
    foreach ($suffix in @('.tmp', '.req', '.claimed', '.result.json')) {
        if ([IO.File]::Exists((Join-Path $Directory ($RequestId + $suffix)))) { return $true }
    }
    return $false
}

$script:IdCounter = 0
function New-RequestId {
    param([string]$Directory, [string]$IdPrefix)
    if (-not $IdRegex.IsMatch($IdPrefix + '-x')) { Stop-Usage ("Prefix '$IdPrefix' makes an invalid id. Use letters, digits, '_', '.' or '-'.") }
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    while ($true) {
        $script:IdCounter++
        $candidate = '{0}-{1}-{2:D3}' -f $IdPrefix, $stamp, $script:IdCounter
        if ($candidate.Length -gt 64) { Stop-Usage ("Prefix '$IdPrefix' is too long for an id of 64 characters.") }
        if (-not (Test-IdUsed $Directory $candidate)) { return $candidate }
    }
}

function Write-RequestFile {
    param([string]$Directory, [string]$RequestId, [string]$Line)
    $temporary = Join-Path $Directory ($RequestId + '.tmp')
    $final = Join-Path $Directory ($RequestId + '.req')
    [IO.File]::WriteAllText($temporary, $Line, $Utf8NoBom)
    # The rename is the toolkit's rule: it reads only .req files, so it never claims a half-written one.
    [IO.File]::Move($temporary, $final)
}

function Wait-Result {
    param([string]$Directory, [string]$RequestId)
    $resultPath = Join-Path $Directory ($RequestId + '.result.json')
    $requestPath = Join-Path $Directory ($RequestId + '.req')
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $closedSince = $null
    while ($true) {
        if ([IO.File]::Exists($resultPath)) {
            return [pscustomobject]@{ State = 'answered'; Result = (Read-JsonFile $resultPath) }
        }
        # An unclaimed request in a closed inbox is never read. A claimed one is still answered
        # (senderLost, serverStopped), so only the unclaimed case ends the wait early.
        $statusPresent = [IO.File]::Exists((Join-Path $Directory 'status.json'))
        if (-not $statusPresent -and [IO.File]::Exists($requestPath)) {
            if ($null -eq $closedSince) { $closedSince = Get-Date }
            elseif (((Get-Date) - $closedSince).TotalSeconds -ge $ClosedGraceSeconds) {
                return [pscustomobject]@{ State = 'closed'; Result = $null }
            }
        }
        else { $closedSince = $null }
        if ((Get-Date) -ge $deadline) { return [pscustomobject]@{ State = 'timeout'; Result = $null } }
        Start-Sleep -Milliseconds $PollMilliseconds
    }
}

function Format-Result {
    param([string]$RequestId, [string]$Line, $Result)
    $parts = @($RequestId, "request=`"$Line`"")
    foreach ($name in @('outcome', 'reason', 'bundle', 'executed', 'failed', 'tolerated', 'total', 'stoppedEarly', 'durationTicks', 'senderLost', 'discardedOnServerStop', 'firstFailure', 'detail')) {
        $value = Get-Property $Result $name
        if ($null -eq $value) { continue }
        $text = [string]$value
        if ($value -is [bool]) { $text = $text.ToLowerInvariant() }
        if ($text -match '\s') { $text = '"' + $text + '"' }
        $parts += "$name=$text"
    }
    return ($parts -join ' ')
}

function Get-OutcomeExit {
    param($Result)
    switch ([string](Get-Property $Result 'outcome')) {
        'done' { return $ExitDone }
        'failed' { return $ExitFailed }
        'refused' { return $ExitRefused }
        default { return $ExitFailed }
    }
}

function Invoke-OneRequest {
    # Returns an object with the id, the state (answered, closed, timeout, sent) and the result.
    param([string]$Directory, [string]$Line, [string]$RequestId)
    Test-RequestLine $Line
    if (-not $SkipStatusCheck -and $null -eq (Get-InboxStatus $Directory)) {
        return [pscustomobject]@{ Id = $null; Line = $Line; State = 'closed'; Result = $null }
    }
    if ([string]::IsNullOrEmpty($RequestId)) { $RequestId = New-RequestId $Directory $Prefix }
    elseif (-not $IdRegex.IsMatch($RequestId)) { Stop-Usage ("Id '$RequestId' is invalid: 1 to 64 letters, digits, '_', '.' or '-'.") }
    elseif (Test-IdUsed $Directory $RequestId) { Stop-Usage ("Id '$RequestId' is already used in this folder; the toolkit would never answer it. Use a new id.") }
    Write-RequestFile $Directory $RequestId $Line
    if ($NoWait) { return [pscustomobject]@{ Id = $RequestId; Line = $Line; State = 'sent'; Result = $null } }
    $wait = Wait-Result $Directory $RequestId
    return [pscustomobject]@{ Id = $RequestId; Line = $Line; State = $wait.State; Result = $wait.Result }
}

function Write-Outcome {
    param($Outcome)
    if ($Json) {
        [pscustomobject]@{ id = $Outcome.Id; request = $Outcome.Line; state = $Outcome.State; result = $Outcome.Result } | ConvertTo-Json -Depth 6 -Compress
        return
    }
    switch ($Outcome.State) {
        'answered' { Format-Result $Outcome.Id $Outcome.Line $Outcome.Result }
        'sent' { "$($Outcome.Id) request=`"$($Outcome.Line)`" sent" }
        'closed' {
            if ($null -eq $Outcome.Id) { "request=`"$($Outcome.Line)`" not sent: the inbox is closed (no status.json). Ask the owner to type /devtool inbox open." }
            else { "$($Outcome.Id) request=`"$($Outcome.Line)`" unanswered: the inbox closed before the request was claimed. Ask the owner to open it again, then send it with a new id." }
        }
        'timeout' { "$($Outcome.Id) request=`"$($Outcome.Line)`" TIMEOUT after $TimeoutSeconds s with no result file. A run is answered when its bundle ends; check the log, or a menu pausing single player." }
    }
}

function Get-StateExit {
    param($Outcome)
    switch ($Outcome.State) {
        'answered' { return (Get-OutcomeExit $Outcome.Result) }
        'sent' { return $ExitDone }
        'closed' { return $ExitClosed }
        'timeout' { return $ExitTimeout }
    }
    return $ExitUsage
}

function Read-BatchFile {
    # One request per line. Blank lines and lines starting with '#' are skipped. A line may end
    # with '=> key=value ...' to state the expected answer; without it the expectation is outcome=done.
    param([string]$Path)
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not [IO.File]::Exists($resolved)) { Stop-Usage ("Batch file not found: $resolved") }
    $items = @()
    $number = 0
    foreach ($raw in [IO.File]::ReadAllLines($resolved, $Utf8NoBom)) {
        $number++
        $line = $raw.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith('#')) { continue }
        $expect = [ordered]@{}
        $split = $line.IndexOf('=>')
        if ($split -ge 0) {
            $expectText = $line.Substring($split + 2).Trim()
            $line = $line.Substring(0, $split).Trim()
            foreach ($pair in ($expectText -split '\s+')) {
                if ($pair.Length -eq 0) { continue }
                $eq = $pair.IndexOf('=')
                if ($eq -le 0) { Stop-Usage ("Line ${number}: expectation '$pair' is not key=value.") }
                $expect[$pair.Substring(0, $eq)] = $pair.Substring($eq + 1)
            }
        }
        if ($expect.Count -eq 0) { $expect['outcome'] = 'done' }
        $items += [pscustomobject]@{ Number = $number; Line = $line; Expect = $expect }
    }
    if ($items.Count -eq 0) { Stop-Usage ("Batch file has no requests: $resolved") }
    return $items
}

function Compare-Expectation {
    # Returns the list of mismatches, empty when the answer meets every expected field.
    param($Outcome, $Expect)
    $mismatches = @()
    if ($Outcome.State -ne 'answered') {
        return @("state=$($Outcome.State)")
    }
    foreach ($key in $Expect.Keys) {
        $actual = Get-Property $Outcome.Result $key
        $actualText = if ($null -eq $actual) { '(absent)' } elseif ($actual -is [bool]) { ([string]$actual).ToLowerInvariant() } else { [string]$actual }
        if ($actualText -ne [string]$Expect[$key]) { $mismatches += "$key expected $($Expect[$key]) got $actualText" }
    }
    return $mismatches
}

try {
    switch ($Action) {
        'status' {
            $directory = Resolve-InboxDirectory
            $status = Get-InboxStatus $directory
            if ($Json) {
                [pscustomobject]@{ inbox = $directory; open = ($null -ne $status); status = $status } | ConvertTo-Json -Depth 4 -Compress
            }
            else { Format-Status $status }
            if ($null -eq $status) { exit $ExitClosed }
            exit $ExitDone
        }
        'send' {
            if ([string]::IsNullOrEmpty($Request)) { Stop-Usage ('send needs -Request "<line>", such as -Request "run my_bundle".') }
            $directory = Resolve-InboxDirectory
            $outcome = Invoke-OneRequest $directory $Request $Id
            Write-Outcome $outcome
            exit (Get-StateExit $outcome)
        }
        'batch' {
            if ([string]::IsNullOrEmpty($File)) { Stop-Usage ('batch needs -File <path>, one request per line.') }
            if (-not [string]::IsNullOrEmpty($Id)) { Stop-Usage ('batch generates its own ids; use -Prefix instead of -Id.') }
            if ($NoWait) { Stop-Usage ('batch waits for every answer; -NoWait applies to send only.') }
            $directory = Resolve-InboxDirectory
            $items = Read-BatchFile $File
            $ran = 0
            $asExpected = 0
            $firstMismatch = $null
            foreach ($item in $items) {
                $outcome = Invoke-OneRequest $directory $item.Line $null
                $ran++
                Write-Outcome $outcome
                $mismatches = @(Compare-Expectation $outcome $item.Expect)
                if ($mismatches.Count -eq 0) { $asExpected++; continue }
                if (-not $Json) { "  MISMATCH line $($item.Number): $($mismatches -join '; ')" }
                if ($null -eq $firstMismatch) { $firstMismatch = $outcome }
                # A closed inbox ends the batch whatever -ContinueOnMismatch says: nothing more can run.
                if ($outcome.State -eq 'closed' -or -not $ContinueOnMismatch) { break }
            }
            if (-not $Json) { "batch: $ran of $($items.Count) sent, $asExpected as expected" }
            if ($null -eq $firstMismatch) { exit $ExitDone }
            if ($firstMismatch.State -eq 'closed') { exit $ExitClosed }
            if ($firstMismatch.State -eq 'timeout') { exit $ExitTimeout }
            exit $ExitMismatch
        }
        'results' {
            $directory = Resolve-InboxDirectory
            $files = @([IO.Directory]::GetFiles($directory, '*.result.json') | Sort-Object)
            foreach ($path in $files) {
                $name = [IO.Path]::GetFileName($path)
                $requestId = $name.Substring(0, $name.Length - '.result.json'.Length)
                if (-not [string]::IsNullOrEmpty($Prefix) -and $PSBoundParameters.ContainsKey('Prefix') -and -not $requestId.StartsWith($Prefix)) { continue }
                $result = Read-JsonFile $path
                if ($Json) { $result | ConvertTo-Json -Depth 6 -Compress }
                else { Format-Result $requestId ([string](Get-Property $result 'request')) $result }
            }
            exit $ExitDone
        }
    }
}
catch {
    [Console]::Error.WriteLine("devtool-inbox: $($_.Exception.Message)")
    exit $ExitUsage
}

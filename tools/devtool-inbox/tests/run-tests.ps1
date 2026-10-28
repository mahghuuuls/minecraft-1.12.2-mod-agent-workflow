[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

$Tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'devtool-inbox.ps1'
$Launcher = Join-Path (Split-Path -Parent $PSScriptRoot) 'devtool-inbox.cmd'
$TestDirectory = Join-Path ([IO.Path]::GetTempPath()) ('minecraft-devtool-inbox-' + [Guid]::NewGuid().ToString('N'))
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

function Assert-Contains {
    param([string[]]$Lines, [string]$Fragment, [string]$Message)
    foreach ($line in $Lines) {
        if ($line.IndexOf($Fragment, [StringComparison]::Ordinal) -ge 0) { return }
    }
    throw "$Message No output line contains '$Fragment'. Output:`n$($Lines -join "`n")"
}

function Invoke-Tool {
    # Runs the tool in a child process, as an agent does, and returns its exit code and output.
    param([string[]]$Arguments, [switch]$ThroughLauncher)
    # The tool writes usage errors to stderr; in Windows PowerShell a redirected native stderr
    # line is an error record, which Stop would turn into a test failure.
    $ErrorActionPreference = 'Continue'
    if ($ThroughLauncher) {
        $output = & cmd.exe /c "`"$Launcher`" $($Arguments -join ' ')" 2>&1
    }
    else {
        $output = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Tool @Arguments 2>&1
    }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Lines = @($output | ForEach-Object { [string]$_ }) }
}

function New-Inbox {
    param([string]$Name, [switch]$Open)
    $path = Join-Path $TestDirectory $Name
    [IO.Directory]::CreateDirectory($path) | Out-Null
    if ($Open) { Set-Open $path }
    return $path
}

function Set-Open {
    param([string]$Path)
    $status = '{"schemaVersion":1,"open":true,"operator":"Developer","operatorUuid":"u","world":"New World","openedWorldTick":120,"openedAtMillis":1}'
    [IO.File]::WriteAllText((Join-Path $Path 'status.json'), $status, $Utf8NoBom)
}

# A fake toolkit: claims each .req by renaming it to .claimed, reads the line, and writes the
# answer under a temporary name before moving it, as the toolkit does. The line decides the answer.
$Responder = {
    param([string]$Path, [int]$Seconds, [int]$DelayMilliseconds)
    $utf8 = New-Object Text.UTF8Encoding($false)
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        foreach ($req in [IO.Directory]::GetFiles($Path, '*.req')) {
            $id = [IO.Path]::GetFileNameWithoutExtension($req)
            $claimed = Join-Path $Path ($id + '.claimed')
            [IO.File]::Move($req, $claimed)
            $line = [IO.File]::ReadAllText($claimed, $utf8)
            Start-Sleep -Milliseconds $DelayMilliseconds
            switch -Regex ($line) {
                '^run ok_' { $result = [ordered]@{ schemaVersion = 1; id = $id; request = $line; verb = 'run'; outcome = 'done'; bundle = $line.Substring(4); executed = 3; failed = 0; tolerated = 1; total = 3; stoppedEarly = $false; durationTicks = 5 } }
                '^run bad_' { $result = [ordered]@{ schemaVersion = 1; id = $id; request = $line; verb = 'run'; outcome = 'failed'; reason = 'bundleFailed'; bundle = $line.Substring(4); executed = 2; failed = 1; tolerated = 0; total = 2; stoppedEarly = $false; durationTicks = 3; firstFailure = 'commands.fill.failed' } }
                '^run leave_' { $result = [ordered]@{ schemaVersion = 1; id = $id; request = $line; verb = 'run'; outcome = 'failed'; reason = 'senderLost'; bundle = $line.Substring(6); executed = 1; failed = 0; tolerated = 0; total = 4; stoppedEarly = $true; durationTicks = 30; senderLost = $true } }
                '^reload$' { $result = [ordered]@{ schemaVersion = 1; id = $id; request = $line; verb = 'reload'; outcome = 'done' } }
                default { $result = [ordered]@{ schemaVersion = 1; id = $id; request = $line; outcome = 'refused'; reason = 'verbNotAllowed' } }
            }
            $temporary = Join-Path $Path ($id + '.result.json.tmp')
            [IO.File]::WriteAllText($temporary, ([pscustomobject]$result | ConvertTo-Json -Compress), $utf8)
            [IO.File]::Move($temporary, (Join-Path $Path ($id + '.result.json')))
        }
        Start-Sleep -Milliseconds 100
    }
}

function Start-Responder {
    param([string]$Path, [int]$Seconds = 30, [int]$DelayMilliseconds = 0)
    return Start-Job -ScriptBlock $Responder -ArgumentList $Path, $Seconds, $DelayMilliseconds
}

$tests = 0
try {
    [IO.Directory]::CreateDirectory($TestDirectory) | Out-Null

    # status: closed without status.json, open with it.
    $inbox = New-Inbox 'status'
    $run = Invoke-Tool @('status', '-Inbox', $inbox)
    Assert-Equal $run.Code 3 'A closed inbox exits 3.'
    Assert-Contains $run.Lines 'closed' 'A closed inbox says so.'
    Set-Open $inbox
    $run = Invoke-Tool @('status', '-Inbox', $inbox)
    Assert-Equal $run.Code 0 'An open inbox exits 0.'
    Assert-Contains $run.Lines 'open operator=Developer world=New World openedWorldTick=120' 'The status names the operator, world and tick.'
    $tests++

    # send to a closed inbox writes nothing.
    $inbox = New-Inbox 'closed'
    $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'run ok_a')
    Assert-Equal $run.Code 3 'Sending to a closed inbox exits 3.'
    Assert-Contains $run.Lines 'not sent: the inbox is closed' 'The refusal says the inbox is closed.'
    Assert-Equal @([IO.Directory]::GetFiles($inbox)).Count 0 'Nothing is written to a closed inbox.'
    $tests++

    # send: done, failed, refused, each with its exit code and fields; no .tmp left behind.
    $inbox = New-Inbox 'send' -Open
    $job = Start-Responder $inbox
    try {
        $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'run ok_setup', '-Id', 'card-001')
        Assert-Equal $run.Code 0 'A done run exits 0.'
        Assert-Contains $run.Lines 'card-001 request="run ok_setup" outcome=done bundle=ok_setup executed=3 failed=0 tolerated=1 total=3 stoppedEarly=false durationTicks=5' 'A done run prints its counters.'
        $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'run bad_fill')
        Assert-Equal $run.Code 1 'A failed run exits 1.'
        Assert-Contains $run.Lines 'reason=bundleFailed' 'A failed run prints its reason.'
        Assert-Contains $run.Lines 'firstFailure=commands.fill.failed' 'A failed run prints its first failure.'
        $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'gamemode creative')
        Assert-Equal $run.Code 2 'A refused request exits 2.'
        Assert-Contains $run.Lines 'outcome=refused reason=verbNotAllowed' 'A refusal prints its reason.'
        $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'reload', '-Json')
        Assert-Equal $run.Code 0 'A JSON send exits by outcome too.'
        $parsed = ($run.Lines -join '') | ConvertFrom-Json
        Assert-Equal $parsed.state 'answered' 'JSON carries the state.'
        Assert-Equal $parsed.result.verb 'reload' 'JSON carries the toolkit result.'
        Assert-Equal @([IO.Directory]::GetFiles($inbox, '*.tmp')).Count 0 'No temporary request file is left.'
        Assert-Equal @([IO.Directory]::GetFiles($inbox, '*.req')).Count 0 'Every request was renamed for the toolkit to claim.'
    }
    finally { Stop-Job $job; Remove-Job $job }
    $tests++

    # Generated ids are unique and never reuse an id that has any file in the folder.
    $inbox = New-Inbox 'ids' -Open
    $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'reload', '-Prefix', 'g1', '-NoWait')
    Assert-Equal $run.Code 0 'A NoWait send exits 0.'
    $first = $run.Lines[0].Split(' ')[0]
    $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'reload', '-Prefix', 'g1', '-NoWait')
    $second = $run.Lines[0].Split(' ')[0]
    if ($first -eq $second) { throw "Two generated ids are equal: $first." }
    if (-not $first.StartsWith('g1-')) { throw "A generated id does not start with its prefix: $first." }
    [IO.File]::WriteAllText((Join-Path $inbox 'used-1.claimed'), 'reload', $Utf8NoBom)
    $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'reload', '-Id', 'used-1')
    Assert-Equal $run.Code 5 'A used id exits 5.'
    Assert-Contains $run.Lines 'already used' 'A used id is refused with the reason.'
    $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'reload', '-Id', 'bad id')
    Assert-Equal $run.Code 5 'An invalid id exits 5.'
    $tests++

    # A malformed request is refused before it is written.
    $inbox = New-Inbox 'malformed' -Open
    $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', ('run ' + ('x' * 600)))
    Assert-Equal $run.Code 5 'An over-long request exits 5.'
    $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', "run caf$([char]0xE9)")
    Assert-Equal $run.Code 5 'A non-ASCII request exits 5.'
    Assert-Equal @([IO.Directory]::GetFiles($inbox, '*.req')).Count 0 'A malformed request writes nothing.'
    $tests++

    # No answer: a timeout, and an inbox that closes before the request is claimed.
    $inbox = New-Inbox 'timeout' -Open
    $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'reload', '-TimeoutSeconds', '1')
    Assert-Equal $run.Code 4 'No answer within the timeout exits 4.'
    Assert-Contains $run.Lines 'TIMEOUT after 1 s' 'A timeout says so.'
    $inbox = New-Inbox 'closing' -Open
    $closer = Start-Job -ScriptBlock { param($p) Start-Sleep -Milliseconds 800; Remove-Item (Join-Path $p 'status.json') } -ArgumentList $inbox
    try {
        $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'reload', '-ClosedGraceSeconds', '1', '-TimeoutSeconds', '30')
    }
    finally { Wait-Job $closer | Out-Null; Remove-Job $closer }
    Assert-Equal $run.Code 3 'An inbox closing before the claim exits 3.'
    Assert-Contains $run.Lines 'the inbox closed before the request was claimed' 'The early end says why.'
    $tests++

    # A claimed run whose operator leaves is still answered.
    $inbox = New-Inbox 'leave' -Open
    $job = Start-Responder $inbox -DelayMilliseconds 1500
    try {
        $remover = Start-Job -ScriptBlock { param($p) Start-Sleep -Milliseconds 700; Remove-Item (Join-Path $p 'status.json') } -ArgumentList $inbox
        $run = Invoke-Tool @('send', '-Inbox', $inbox, '-Request', 'run leave_card', '-ClosedGraceSeconds', '0', '-TimeoutSeconds', '30')
        Wait-Job $remover | Out-Null; Remove-Job $remover
    }
    finally { Stop-Job $job; Remove-Job $job }
    Assert-Equal $run.Code 1 'A run ended by the operator leaving exits 1.'
    Assert-Contains $run.Lines 'reason=senderLost' 'The answer names senderLost.'
    Assert-Contains $run.Lines 'senderLost=true' 'The answer carries the senderLost flag.'
    $tests++

    # batch: expectations met, a mismatch that stops, and -ContinueOnMismatch.
    $inbox = New-Inbox 'batch' -Open
    $batchFile = Join-Path $TestDirectory 'batch.txt'
    [IO.File]::WriteAllLines($batchFile, @(
        '# regression',
        'run ok_one',
        '',
        'run bad_two => outcome=failed failed=1 executed=2',
        'run bad_three => failed=0',
        'run ok_four'
    ), $Utf8NoBom)
    $job = Start-Responder $inbox
    try {
        $run = Invoke-Tool @('batch', '-Inbox', $inbox, '-File', $batchFile, '-Prefix', 'b1')
        Assert-Equal $run.Code 6 'A mismatch exits 6.'
        Assert-Contains $run.Lines 'MISMATCH line 5: failed expected 0 got 1' 'The mismatch names the line and the field.'
        Assert-Contains $run.Lines 'batch: 3 of 4 sent, 2 as expected' 'The batch stops at the first mismatch.'
        $run = Invoke-Tool @('batch', '-Inbox', $inbox, '-File', $batchFile, '-Prefix', 'b2', '-ContinueOnMismatch')
        Assert-Equal $run.Code 6 'A batch with a mismatch still exits 6 when it continues.'
        Assert-Contains $run.Lines 'batch: 4 of 4 sent, 3 as expected' 'ContinueOnMismatch runs every line.'
    }
    finally { Stop-Job $job; Remove-Job $job }
    $tests++

    # results lists answers by id, optionally by prefix.
    $run = Invoke-Tool @('results', '-Inbox', $inbox, '-Prefix', 'b2')
    Assert-Equal $run.Code 0 'results exits 0.'
    Assert-Equal $run.Lines.Count 4 'results lists only the prefix asked for.'
    Assert-Contains $run.Lines 'request="run ok_four" outcome=done' 'results prints each answer.'
    $tests++

    # The default folder is run\config\devtool\inbox under the current directory, and the
    # batch launcher passes arguments and exit codes through.
    $game = Join-Path $TestDirectory 'game'
    $defaultInbox = Join-Path $game 'run\config\devtool\inbox'
    [IO.Directory]::CreateDirectory($defaultInbox) | Out-Null
    Push-Location $game
    try {
        $run = Invoke-Tool @('status') -ThroughLauncher
        Assert-Equal $run.Code 3 'The launcher passes the exit code through.'
        Assert-Contains $run.Lines 'closed' 'The default folder is found.'
    }
    finally { Pop-Location }
    $tests++

    "devtool-inbox tests passed: $tests groups."
}
finally {
    if ([IO.Directory]::Exists($TestDirectory)) { Remove-Item -LiteralPath $TestDirectory -Recurse -Force }
}

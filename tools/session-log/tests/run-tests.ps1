[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

$Tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'session-log.ps1'
$Launcher = Join-Path (Split-Path -Parent $PSScriptRoot) 'session-log.cmd'
$TestDirectory = Join-Path ([IO.Path]::GetTempPath()) ('minecraft-session-log-' + [Guid]::NewGuid().ToString('N'))
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

function Assert-NotContains {
    param([string[]]$Lines, [string]$Fragment, [string]$Message)
    foreach ($line in $Lines) {
        if ($line.IndexOf($Fragment, [StringComparison]::Ordinal) -ge 0) {
            throw "$Message An output line contains '$Fragment': $line"
        }
    }
}

function Write-PlainLog {
    param([string]$Path, [string[]]$Lines)
    [IO.File]::WriteAllText($Path, (($Lines -join "`n") + "`n"), $Utf8NoBom)
}

function Write-GzipLog {
    param([string]$Path, [string[]]$Lines)
    $bytes = $Utf8NoBom.GetBytes((($Lines -join "`n") + "`n"))
    $file = New-Object IO.FileStream($Path, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    try {
        $gzip = New-Object IO.Compression.GZipStream($file, [IO.Compression.CompressionMode]::Compress)
        try {
            $gzip.Write($bytes, 0, $bytes.Length)
        }
        finally {
            $gzip.Dispose()
        }
    }
    finally {
        $file.Dispose()
    }
}

function Invoke-Tool {
    # Converts command-line style arguments into a hashtable splat, because splatting an
    # array into a script binds every element positionally.
    param([string[]]$Arguments)
    $named = @{}
    $positional = New-Object 'System.Collections.Generic.List[string]'
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $token = $Arguments[$index]
        if ($token.StartsWith('-') -and $token.Length -gt 1) {
            $name = $token.Substring(1)
            $hasValue = ($index + 1 -lt $Arguments.Count) -and -not ($Arguments[$index + 1].StartsWith('-') -and $Arguments[$index + 1].Length -gt 1)
            if ($hasValue) {
                $named[$name] = $Arguments[$index + 1]
                $index++
            }
            else {
                $named[$name] = $true
            }
        }
        else {
            $positional.Add($token)
        }
    }
    $named['Action'] = $positional[0]
    return @(& $Tool @named | ForEach-Object { [string]$_ })
}

[IO.Directory]::CreateDirectory($TestDirectory) | Out-Null
try {
    $logs = Join-Path $TestDirectory 'logs'
    [IO.Directory]::CreateDirectory($logs) | Out-Null

    Write-GzipLog -Path (Join-Path $logs '2026-01-01-1.log.gz') -Lines @(
        '[10:00:00] [main/INFO] [LaunchWrapper]: Loading tweak class name net.minecraftforge.fml.common.launcher.FMLServerTweaker',
        '[10:00:01] [main/INFO] [FML]: Forge Mod Loader version 14.23.5.2847 for Minecraft 1.12.2 loading',
        '[10:00:02] [Server thread/INFO] [FML]: Forge Mod Loader has identified 5 mods to load',
        '[10:00:05] [Server thread/INFO] [DevToolkit]: [DevToolkit][MARK] side=SERVER worldTick=10 session=fixture sessionTick=1 label=SERVER_READY',
        '[10:00:09] [Server thread/INFO] [minecraft/MinecraftServer]: Stopping server'
    )
    Write-GzipLog -Path (Join-Path $logs '2026-01-01-2.log.gz') -Lines @(
        '[10:30:00] [main/INFO] [GradleStart]: userProperties: {}',
        '[10:30:00] [main/INFO] [LaunchWrapper]: Loading tweak class name net.minecraftforge.fml.common.launcher.FMLTweaker',
        '[10:30:01] [main/INFO] [FML]: Forge Mod Loader version 14.23.5.2847 for Minecraft 1.12.2 loading',
        '[10:30:02] [Client thread/WARN] [FML]: something odd happened',
        '[10:30:03] [Client thread/INFO] [FML]: Forge Mod Loader has identified 6 mods to load',
        '[10:30:09] [Client thread/INFO] [minecraft/Minecraft]: Stopping!'
    )
    Write-PlainLog -Path (Join-Path $logs 'latest.log') -Lines @(
        '[11:00:00] [main/INFO] [GradleStart]: userProperties: {}',
        '[11:00:00] [main/INFO] [LaunchWrapper]: Loading tweak class name net.minecraftforge.fml.common.launcher.FMLTweaker',
        '[11:00:01] [main/INFO] [FML]: Forge Mod Loader version 14.23.5.2847 for Minecraft 1.12.2 loading',
        '[11:00:02] [Client thread/INFO] [FML]: Forge Mod Loader has identified 7 mods to load',
        '[11:00:10] [Server thread/INFO] [DevToolkit]: [DevToolkit][MARK] side=SERVER worldTick=100 session=fixture sessionTick=10 label=CARD_START',
        '[11:00:11] [Server thread/INFO] [DevToolkit]: [DevToolkit][BUNDLE_START] side=SERVER worldTick=101 bundle=fa_test hash=abc commands=3',
        '[11:00:12] [Server thread/INFO] [DevToolkit]: [DevToolkit][PLAYER_INSPECT] name=Tester uuid=1 dimension=0 health=20.00 maxHealth=40.00 side=SERVER worldTick=102',
        '[11:00:13] [Server thread/INFO] [DevToolkit]: [DevToolkit][ERROR] side=SERVER worldTick=103 message="Bundle command failed" bundle=fa_test index=1 command="give @s fixture:thing" detail=commands.give.item.notFound',
        '[11:00:14] [Server thread/INFO] [DevToolkit]: [DevToolkit][BUNDLE_END] side=SERVER worldTick=104 bundle=fa_test hash=abc executed=2 failed=1 total=3 stoppedEarly=true durationTicks=3',
        '[11:00:20] [Server thread/INFO] [DevToolkit]: [DevToolkit][MARK] side=SERVER worldTick=110 session=fixture sessionTick=20 label=CARD_END',
        '[11:00:21] [Server thread/ERROR] [FML]: Exception caught during firing event',
        'java.lang.RuntimeException: boom',
        "`tat fixture.Thing.explode(Thing.java:1)",
        '[11:00:30] [Server thread/INFO] [DevToolkit]: [DevToolkit][BUNDLE_START] side=SERVER worldTick=200 bundle=fa_test hash=abc commands=3',
        '[11:00:31] [Server thread/INFO] [DevToolkit]: [DevToolkit][BUNDLE_END] side=SERVER worldTick=203 bundle=fa_test hash=abc executed=3 failed=0 total=3 stoppedEarly=false durationTicks=3',
        '[11:00:40] [Server thread/INFO] [DevToolkit]: [DevToolkit][MARK] side=SERVER worldTick=300 session=fixture sessionTick=40 label=CARD_START',
        '[11:01:00] [Client thread/INFO] [minecraft/Minecraft]: Stopping!'
    )

    $launches = Invoke-Tool @('launches', '-LogDirectory', $logs)
    Assert-Contains $launches 'Launches found: 3' 'Three launches across two rotated files and latest.log were not found.'
    Assert-Contains $launches 'Launch 1: server, 2026-01-01-1.log.gz line 1, 10:00:00 to 10:00:09, Forge 14.23.5.2847, 5 mods, stopped' 'The server launch summary is wrong.'
    Assert-Contains $launches 'Launch 2: client, 2026-01-01-2.log.gz line 1, 10:30:00 to 10:30:09, Forge 14.23.5.2847, 6 mods, stopped' 'The client launch in the rotated file is wrong, or its GradleStart prelude was split off.'
    Assert-Contains $launches 'Launch 3: client, latest.log line 1, 11:00:00 to 11:01:00, Forge 14.23.5.2847, 7 mods, stopped' 'The latest.log launch summary is wrong.'
    Assert-Contains $launches '  marks: CARD_START, CARD_END, CARD_START' 'Marks were not listed per launch in order.'
    Assert-Contains $launches '  bundles started: fa_test, fa_test' 'Bundle starts were not listed per launch.'
    Assert-Contains $launches 'entries 15, toolkit records 9, warnings 0, errors 1' 'Entry, record, warning, and error counts are wrong for the last launch.'

    $launchesJson = (Invoke-Tool @('launches', '-LogDirectory', $logs, '-Json')) -join "`n" | ConvertFrom-Json
    Assert-Equal @($launchesJson).Count 3 'JSON launches count is wrong.'
    Assert-Equal $launchesJson[0].side 'server' 'JSON side of the first launch is wrong.'
    Assert-Equal $launchesJson[2].modCount 7 'JSON mod count of the last launch is wrong.'
    Assert-Equal @($launchesJson[2].marks).Count 3 'JSON marks of the last launch are wrong.'

    $rotatedLimit = Invoke-Tool @('launches', '-LogDirectory', $logs, '-Rotated', '1')
    Assert-Contains $rotatedLimit 'Launches found: 2' '-Rotated 1 did not limit the rotated files to the newest one.'
    Assert-Contains $rotatedLimit 'Files read (oldest first): 2026-01-01-2.log.gz, latest.log' 'The newest rotated file was not the one kept.'

    $singleFile = Invoke-Tool @('launches', '-Log', (Join-Path $logs '2026-01-01-1.log.gz'))
    Assert-Contains $singleFile 'Launches found: 1' 'A single .gz log was not read.'

    $marks = Invoke-Tool @('records', '-LogDirectory', $logs, '-Type', 'MARK')
    Assert-Contains $marks 'Toolkit records selected: 3' 'The MARK records of the last launch were not selected.'
    Assert-Contains $marks '[latest.log:5] [11:00:10] MARK side=SERVER worldTick=100 session=fixture sessionTick=10 label=CARD_START' 'A MARK record was not printed with its fields.'

    $marksJson = (Invoke-Tool @('records', '-LogDirectory', $logs, '-Type', 'MARK', '-Json')) -join "`n" | ConvertFrom-Json
    Assert-Equal @($marksJson).Count 3 'JSON MARK record count is wrong.'
    Assert-Equal $marksJson[1].record.fields.label 'CARD_END' 'JSON record fields were not parsed.'

    $fields = Invoke-Tool @('records', '-LogDirectory', $logs, '-Type', 'PLAYER_INSPECT', '-Fields', 'health,maxHealth,missing')
    Assert-Contains $fields '[latest.log:7] [11:00:12] PLAYER_INSPECT health=20.00 maxHealth=40.00 missing=(absent)' 'Selected record fields were not printed.'

    $quoted = (Invoke-Tool @('records', '-LogDirectory', $logs, '-Type', 'ERROR', '-Json')) -join "`n" | ConvertFrom-Json
    Assert-Equal @($quoted).Count 1 'The toolkit ERROR record was not selected.'
    Assert-Equal $quoted[0].record.fields.message 'Bundle command failed' 'A quoted record value was not parsed.'
    Assert-Equal $quoted[0].record.fields.command 'give @s fixture:thing' 'A quoted record value with spaces was not parsed.'
    Assert-Equal $quoted[0].record.fields.detail 'commands.give.item.notFound' 'A bare record value after a quoted one was not parsed.'

    $firstSlice = Invoke-Tool @('timeline', '-LogDirectory', $logs, '-From', 'CARD_START', '-To', 'CARD_END', '-Occurrence', 'first')
    Assert-Contains $firstSlice "MARK 'CARD_START' occurrence first of 2 at line 5, 11:00:10, to MARK 'CARD_END' at line 10, 11:00:20; 6 entries in the slice, 6 after filters" 'The first mark slice scope is wrong.'
    Assert-Contains $firstSlice '[latest.log:7] [11:00:12]' 'The mark slice does not include the PLAYER_INSPECT record.'
    Assert-NotContains $firstSlice 'Exception caught' 'The mark slice leaked an entry after the To mark.'

    $lastSlice = Invoke-Tool @('timeline', '-LogDirectory', $logs, '-From', 'CARD_START', '-To', 'CARD_END')
    Assert-Contains $lastSlice "MARK 'CARD_START' occurrence last of 2 at line 16, 11:00:40, to end of launch (no MARK 'CARD_END' after it)" 'The last mark slice did not run to the end of the launch.'
    Assert-Contains $lastSlice 'Stopping!' 'The open-ended mark slice does not reach the end of the launch.'

    $bundleLast = Invoke-Tool @('timeline', '-LogDirectory', $logs, '-Bundle', 'fa_test')
    Assert-Contains $bundleLast "bundle 'fa_test' occurrence last of 2: BUNDLE_START at line 14, 11:00:30, to BUNDLE_END at line 15, 11:00:31; 2 entries in the slice" 'The last bundle slice is wrong.'
    Assert-NotContains $bundleLast 'PLAYER_INSPECT' 'The last bundle slice leaked the first run.'

    $bundleFirst = Invoke-Tool @('timeline', '-LogDirectory', $logs, '-Bundle', 'fa_test', '-Occurrence', '1', '-RecordsOnly')
    Assert-Contains $bundleFirst 'PLAYER_INSPECT' 'The first bundle slice does not include its inspection record.'
    Assert-Contains $bundleFirst 'executed=2 failed=1' 'The first bundle slice does not end at its BUNDLE_END.'

    $timeSlice = Invoke-Tool @('timeline', '-LogDirectory', $logs, '-FromTime', '11:00:20', '-ToTime', '11:00:31')
    Assert-Contains $timeSlice '4 entries in the slice' 'The time slice count is wrong.'
    Assert-Contains $timeSlice '    java.lang.RuntimeException: boom' 'Continuation lines were not attached to their entry.'

    $errors = Invoke-Tool @('errors', '-LogDirectory', $logs)
    Assert-Contains $errors 'Problem entries: 2' 'The last launch should show one ERROR entry and one toolkit ERROR record.'
    Assert-Contains $errors '  FML: 1' 'The per-logger count is missing.'
    Assert-Contains $errors "`tat fixture.Thing.explode(Thing.java:1)" 'The stack trace line was not printed under its entry.'

    $allErrors = Invoke-Tool @('errors', '-LogDirectory', $logs, '-Launch', 'all')
    Assert-Contains $allErrors 'Problem entries: 3' 'All launches should add the WARN entry of the second launch.'

    $warnOnly = Invoke-Tool @('errors', '-LogDirectory', $logs, '-Launch', 'all', '-Level', 'WARN', '-Logger', 'FML')
    Assert-Contains $warnOnly 'Problem entries: 1' 'Level and logger filters did not narrow the errors.'
    Assert-Contains $warnOnly 'something odd happened' 'The WARN entry was not the one kept.'

    $found = Invoke-Tool @('find', '-LogDirectory', $logs, '-Text', 'boom')
    Assert-Contains $found 'Launches searched: 1, 2, 3' 'find did not default to every launch.'
    Assert-Contains $found 'Matching entries: 1' 'find did not match a continuation line.'
    Assert-Contains $found '[latest.log:11] [11:00:21] [Server thread/ERROR] [FML]: Exception caught during firing event' 'find did not print the owning entry.'

    $pattern = Invoke-Tool @('find', '-LogDirectory', $logs, '-Pattern', 'identified \d+ mods', '-Launch', 'server')
    Assert-Contains $pattern 'Matching entries: 1' 'A pattern search limited to the server launch is wrong.'
    Assert-Contains $pattern '2026-01-01-1.log.gz:3' 'The pattern match did not cite the rotated file.'

    $limited = Invoke-Tool @('timeline', '-LogDirectory', $logs, '-Limit', '2')
    Assert-Contains $limited '... 13 more entries not shown (raise or remove -Limit)' 'The limit note is wrong.'

    $missingText = $false
    try { & $Tool find -LogDirectory $logs 2>$null | Out-Null }
    catch { $missingText = $_.Exception.Message -like '*find needs -Text*' }
    Assert-Equal $missingText $true 'find without -Text or -Pattern was not rejected.'

    $twoBoundaries = $false
    try { & $Tool timeline -LogDirectory $logs -Bundle fa_test -From CARD_START 2>$null | Out-Null }
    catch { $twoBoundaries = $_.Exception.Message -like '*Choose one boundary kind*' }
    Assert-Equal $twoBoundaries $true 'Two boundary kinds were not rejected.'

    $launcherCommand = 'set "PSModuleAutoLoadingPreference=None" && call "' + $Launcher + '" launches -LogDirectory "' + $logs + '"'
    $launcherOutput = @(& cmd.exe /d /c $launcherCommand)
    Assert-Equal $LASTEXITCODE 0 'Batch launcher failed with module autoload disabled.'
    Assert-Contains @($launcherOutput | ForEach-Object { [string]$_ }) 'Launches found: 3' 'Batch launcher did not list the launches with module autoload disabled.'

    Write-Output 'All session-log tests passed.'
}
finally {
    if ([IO.Directory]::Exists($TestDirectory)) {
        $resolved = [IO.Path]::GetFullPath($TestDirectory)
        $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notmatch '^minecraft-session-log-[0-9a-f]{32}$') {
            throw "Refusing to remove unexpected test directory: $resolved"
        }
        [IO.Directory]::Delete($resolved, $true)
    }
}

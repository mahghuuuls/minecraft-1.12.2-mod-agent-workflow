[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('run', 'probe')]
    [string]$Action = 'run',

    [string]$Command,
    [string]$WorkingDirectory,
    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 1800,
    [ValidateSet('wmi', 'task')]
    [string]$Launcher = 'wmi',
    [string[]]$Set = @(),
    [string]$Label = 'run',
    [ValidateRange(0, 100000)]
    [int]$TailLines = 0,
    [switch]$Quiet
)

# host-run starts one command outside the agent's own process tree and waits for it.
#
# Why this exists: inside some agent hosts, every child process inherits a restriction that breaks
# loopback networking for newer Java runtimes ("Unable to establish loopback connection" from Gradle,
# "Invalid argument: connect" from java.nio.channels.Pipe). A process started by the Windows Task
# Scheduler or by WMI is not a child of the agent host, so it does not inherit the restriction.
#
# The tool writes a small command file into its own run folder, asks Windows to start that file,
# waits for the exit-code file, prints the captured output, and exits with the command's exit code.
# It never edits a repository, never runs Git, and keeps every run in its own folder, so several
# agents on the same computer can use it at the same time.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

$ExitTimeout = 124
$ExitLost = 125
$ExitUsage = 2
$Ascii = New-Object Text.ASCIIEncoding
$script:ResultCode = $ExitUsage

function Invoke-Native {
    # Native tools such as schtasks write warnings to stderr; under 'Stop' those would become terminating errors.
    param([string]$Executable, [string[]]$Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& $Executable @Arguments 2>&1 | ForEach-Object { [string]$_ })
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Lines = $lines }
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Write-Note {
    param([string]$Text)
    if (-not $Quiet) { Write-Output ('host-run: ' + $Text) }
}

function Get-StoreRoot {
    $configured = $env:MINECRAFT_MOD_AGENT_HOST_RUN_ROOT
    if (-not [string]::IsNullOrWhiteSpace($configured)) { return [IO.Path]::GetFullPath($configured) }
    return Join-Path ([IO.Path]::GetTempPath()) 'minecraft-1.12.2-mod-agent-host-run'
}

function New-RunFolder {
    param([string]$RunLabel)
    $safeLabel = ($RunLabel -replace '[^A-Za-z0-9_-]', '-')
    if ([string]::IsNullOrWhiteSpace($safeLabel)) { $safeLabel = 'run' }
    $root = Get-StoreRoot
    if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    while ($true) {
        $id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $safeLabel + '-' + ([Guid]::NewGuid().ToString('N').Substring(0, 6))
        $folder = Join-Path $root $id
        if (-not (Test-Path -LiteralPath $folder)) {
            New-Item -ItemType Directory -Path $folder | Out-Null
            return $folder
        }
    }
}

function Write-CommandFile {
    param([string]$Folder, [string]$Directory, [string]$CommandLine, [string[]]$Assignments)
    $outputPath = Join-Path $Folder 'output.txt'
    $exitPath = Join-Path $Folder 'exit.txt'
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('@echo off')
    $lines.Add('cd /d "' + $Directory + '"')
    $lines.Add('if errorlevel 1 (')
    $lines.Add('  >"' + $outputPath + '" echo host-run: cannot enter the working directory ' + $Directory)
    $lines.Add('  >"' + $exitPath + '.tmp" echo ' + $ExitUsage)
    $lines.Add('  move /y "' + $exitPath + '.tmp" "' + $exitPath + '" >nul')
    $lines.Add('  exit /b ' + $ExitUsage)
    $lines.Add(')')
    foreach ($assignment in $Assignments) {
        if ($assignment -notmatch '^[A-Za-z_][A-Za-z0-9_]*=') {
            throw "Each -Set value must look like NAME=value. Rejected: $assignment"
        }
        $lines.Add('set "' + $assignment + '"')
    }
    $lines.Add('call ' + $CommandLine + ' >"' + $outputPath + '" 2>&1')
    $lines.Add('set "HOST_RUN_EXIT=%ERRORLEVEL%"')
    $lines.Add('>"' + $exitPath + '.tmp" echo %HOST_RUN_EXIT%')
    $lines.Add('move /y "' + $exitPath + '.tmp" "' + $exitPath + '" >nul')
    $lines.Add('exit /b %HOST_RUN_EXIT%')
    $commandPath = Join-Path $Folder 'command.cmd'
    [IO.File]::WriteAllText($commandPath, (($lines -join "`r`n") + "`r`n"), $Ascii)
    return $commandPath
}

function Start-DetachedCommand {
    param([string]$CommandPath, [string]$Directory, [string]$Method, [string]$TaskName)
    $commandLine = 'cmd.exe /d /c "' + $CommandPath + '"'
    if ($Method -eq 'wmi') {
        # Win32_Process.Create starts the process from the WMI service, not from this process tree.
        $processClass = [wmiclass]'Win32_Process'
        $result = $processClass.Create($commandLine, $Directory, $null)
        if ($result.ReturnValue -ne 0) {
            throw "Win32_Process.Create failed with return value $($result.ReturnValue). Try -Launcher task."
        }
        return [int]$result.ProcessId
    }
    # The Task Scheduler starts the process from its own service. The task is created once, run once, and removed.
    $created = Invoke-Native 'schtasks.exe' @('/create', '/tn', $TaskName, '/tr', $commandLine, '/sc', 'once', '/st', '00:00', '/f')
    if ($created.ExitCode -ne 0) { throw "schtasks /create failed: $($created.Lines -join ' ')" }
    $started = Invoke-Native 'schtasks.exe' @('/run', '/tn', $TaskName)
    if ($started.ExitCode -ne 0) {
        Invoke-Native 'schtasks.exe' @('/delete', '/tn', $TaskName, '/f') | Out-Null
        throw "schtasks /run failed: $($started.Lines -join ' ')"
    }
    return 0
}

function Find-CommandProcessId {
    param([string]$CommandPath)
    # The launched cmd.exe carries the command file path on its command line, which identifies it without a stored pid.
    $escaped = $CommandPath.Replace('\', '\\').Replace("'", "''")
    $processes = @(Get-WmiObject -Class Win32_Process -Filter "Name = 'cmd.exe' AND CommandLine LIKE '%$escaped%'")
    foreach ($process in $processes) { return [int]$process.ProcessId }
    return 0
}

function Test-ProcessAlive {
    param([int]$ProcessId)
    if ($ProcessId -le 0) { return $true }
    try {
        Get-Process -Id $ProcessId -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Stop-CommandTree {
    param([int]$ProcessId, [string]$TaskName)
    if ($TaskName) { Invoke-Native 'schtasks.exe' @('/end', '/tn', $TaskName) | Out-Null }
    if ($ProcessId -gt 0) { Invoke-Native 'taskkill.exe' @('/T', '/F', '/PID', "$ProcessId") | Out-Null }
}

function Read-Output {
    param([string]$Path, [int]$Tail)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    # The command wrote through the console code page, so the file is read the same way.
    $lines = @(Get-Content -LiteralPath $Path -Encoding Default)
    if ($Tail -gt 0 -and $lines.Count -gt $Tail) { return @($lines[($lines.Count - $Tail)..($lines.Count - 1)]) }
    return $lines
}

function Invoke-HostRun {
    param([string]$CommandLine, [string]$Directory, [int]$Timeout, [string]$Method, [string[]]$Assignments, [string]$RunLabel, [int]$Tail)
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { throw 'Give the command to run with -Command.' }
    if ([string]::IsNullOrWhiteSpace($Directory)) { $Directory = (Get-Location).Path }
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { throw "Working directory not found: $Directory" }
    $Directory = (Resolve-Path -LiteralPath $Directory).Path

    $folder = New-RunFolder -RunLabel $RunLabel
    $commandPath = Write-CommandFile -Folder $folder -Directory $Directory -CommandLine $CommandLine -Assignments $Assignments
    $outputPath = Join-Path $folder 'output.txt'
    $exitPath = Join-Path $folder 'exit.txt'
    $taskName = ''
    if ($Method -eq 'task') { $taskName = 'minecraft-1.12.2-mod-agent-host-run-' + (Split-Path -Leaf $folder) }

    Write-Note ('command   ' + $CommandLine)
    Write-Note ('directory ' + $Directory)
    Write-Note ('run folder ' + $folder)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $processId = Start-DetachedCommand -CommandPath $commandPath -Directory $Directory -Method $Method -TaskName $taskName
    $pidNote = ''
    if ($processId -gt 0) { $pidNote = ' (pid ' + $processId + ')' }
    Write-Note ('launcher  ' + $Method + $pidNote)

    $exitCode = $null
    $lostSince = $null
    while ($true) {
        if (Test-Path -LiteralPath $exitPath) {
            $text = ([IO.File]::ReadAllText($exitPath)).Trim()
            if ($text -match '^-?\d+$') { $exitCode = [int]$text; break }
        }
        if ($watch.Elapsed.TotalSeconds -ge $Timeout) {
            if ($processId -le 0) { $processId = Find-CommandProcessId -CommandPath $commandPath }
            Stop-CommandTree -ProcessId $processId -TaskName $taskName
            $exitCode = $ExitTimeout
            Write-Note ('timeout after ' + $Timeout + ' s; the command tree was stopped')
            break
        }
        if ($processId -le 0 -and $watch.Elapsed.TotalSeconds -ge 5) { $processId = Find-CommandProcessId -CommandPath $commandPath }
        if ($processId -gt 0 -and -not (Test-ProcessAlive -ProcessId $processId)) {
            # Give the exit file a moment to appear after the process ends.
            if ($null -eq $lostSince) { $lostSince = $watch.Elapsed }
            elseif (($watch.Elapsed - $lostSince).TotalSeconds -ge 3) {
                $exitCode = $ExitLost
                Write-Note 'the launched process ended without writing an exit code'
                break
            }
        }
        Start-Sleep -Milliseconds 500
    }
    $watch.Stop()
    if ($taskName) { Invoke-Native 'schtasks.exe' @('/delete', '/tn', $taskName, '/f') | Out-Null }

    $output = @(Read-Output -Path $outputPath -Tail $Tail)
    if (-not $Quiet) {
        if ($Tail -gt 0) { Write-Note ('last ' + $output.Count + ' output lines') }
        foreach ($line in $output) { Write-Output $line }
    }
    Write-Output ('host-run: exit ' + $exitCode + ' after ' + [int][Math]::Ceiling($watch.Elapsed.TotalSeconds) + ' s; output ' + $outputPath)
    # The result travels through a script variable so that the printed lines above stay in the output stream.
    $script:ResultCode = [int]$exitCode
}

switch ($Action) {
    'probe' {
        $probeDirectory = $WorkingDirectory
        if ([string]::IsNullOrWhiteSpace($probeDirectory)) { $probeDirectory = (Get-Location).Path }
        Invoke-HostRun -CommandLine 'cmd.exe /d /c echo host-run probe ok' -Directory $probeDirectory -Timeout ([Math]::Min($TimeoutSeconds, 120)) -Method $Launcher -Assignments @() -RunLabel 'probe' -Tail 0
        if ($script:ResultCode -eq 0) { Write-Output ('host-run: probe OK, launcher ' + $Launcher + ' starts commands outside this process tree') }
        else { Write-Output ('host-run: probe FAILED with exit ' + $script:ResultCode + ' for launcher ' + $Launcher) }
        exit $script:ResultCode
    }
    default {
        Invoke-HostRun -CommandLine $Command -Directory $WorkingDirectory -Timeout $TimeoutSeconds -Method $Launcher -Assignments $Set -RunLabel $Label -Tail $TailLines
        exit $script:ResultCode
    }
}

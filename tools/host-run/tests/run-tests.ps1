[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

$Tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'host-run.ps1'
$Launcher = Join-Path (Split-Path -Parent $PSScriptRoot) 'host-run.cmd'
$TestDirectory = Join-Path ([IO.Path]::GetTempPath()) ('minecraft-host-run-' + [Guid]::NewGuid().ToString('N'))
$StoreRoot = Join-Path $TestDirectory 'store'

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
    # Runs the tool in a child PowerShell so that its exit code and printed lines can both be read.
    param([string[]]$Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = @(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Tool @Arguments 2>&1 | ForEach-Object { [string]$_ })
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Lines = $lines }
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Get-RunFolder {
    param([string[]]$Lines)
    foreach ($line in $Lines) {
        if ($line -match '^host-run: run folder (.+)$') { return $Matches[1] }
    }
    throw "No run folder line in output:`n$($Lines -join "`n")"
}

function Get-LaunchedProcessId {
    param([string[]]$Lines)
    foreach ($line in $Lines) {
        if ($line -match '\(pid (\d+)\)') { return [int]$Matches[1] }
    }
    return 0
}

try {
    New-Item -ItemType Directory -Path $TestDirectory -Force | Out-Null
    $env:MINECRAFT_MOD_AGENT_HOST_RUN_ROOT = $StoreRoot

    # 1. The probe starts a command through WMI and reports success.
    $probe = Invoke-Tool @('probe', '-WorkingDirectory', $TestDirectory)
    Assert-Equal $probe.ExitCode 0 'The probe did not exit 0.'
    Assert-Contains $probe.Lines 'probe OK' 'The probe did not report OK.'
    Assert-Contains $probe.Lines 'host-run probe ok' 'The probe did not print the launched command output.'

    # 2. A run keeps its files in its own folder under the configured store root.
    $folder = Get-RunFolder $probe.Lines
    Assert-Equal ($folder.StartsWith($StoreRoot, [StringComparison]::OrdinalIgnoreCase)) $true 'The run folder is not under the configured store root.'
    foreach ($name in @('command.cmd', 'output.txt', 'exit.txt')) {
        Assert-Equal (Test-Path -LiteralPath (Join-Path $folder $name)) $true "The run folder lacks $name."
    }

    # 3. The command's exit code, output, and working directory come back from a batch file, the shape of gradlew.bat.
    $batch = Join-Path $TestDirectory 'three.cmd'
    [IO.File]::WriteAllText($batch, "@echo off`r`ncd`r`necho hello-from-host`r`nexit /b 3`r`n", (New-Object Text.ASCIIEncoding))
    $run = Invoke-Tool @('run', '-Command', 'three.cmd', '-WorkingDirectory', $TestDirectory, '-Label', 'echo test')
    Assert-Equal $run.ExitCode 3 'The command exit code was not passed through.'
    Assert-Contains $run.Lines 'hello-from-host' 'The command output was not printed.'
    Assert-Contains $run.Lines ([IO.Path]::GetFullPath($TestDirectory).TrimEnd('\')) 'The command did not run in the working directory.'
    Assert-Contains $run.Lines 'host-run: exit 3 after' 'The footer did not report the exit code.'
    $runFolder = Get-RunFolder $run.Lines
    Assert-Equal ((Split-Path -Leaf $runFolder) -match '^\d{8}-\d{6}-echo-test-[0-9a-f]{6}$') $true 'The run folder name does not carry the sanitized label.'

    # 4. -Set assigns environment variables for the command only.
    $set = Invoke-Tool @('run', '-Command', 'cmd.exe /d /c echo %HOST_RUN_TEST_VAR%', '-Set', 'HOST_RUN_TEST_VAR=abc', '-WorkingDirectory', $TestDirectory)
    Assert-Equal $set.ExitCode 0 'The -Set run did not exit 0.'
    Assert-Contains $set.Lines 'abc' 'The -Set variable did not reach the command.'
    Assert-Equal ([string]::IsNullOrEmpty($env:HOST_RUN_TEST_VAR)) $true 'The -Set variable leaked into the test process.'

    # 5. -TailLines limits the printed output; the file keeps everything.
    $counting = Join-Path $TestDirectory 'count.cmd'
    [IO.File]::WriteAllText($counting, "@echo off`r`necho one`r`necho two`r`necho three`r`n", (New-Object Text.ASCIIEncoding))
    $tail = Invoke-Tool @('run', '-Command', 'count.cmd', '-TailLines', '1', '-WorkingDirectory', $TestDirectory)
    Assert-Equal $tail.ExitCode 0 'The tail run did not exit 0.'
    Assert-Contains $tail.Lines 'three' 'The last output line was not printed.'
    $printedOne = @($tail.Lines | Where-Object { $_ -match '^one' }).Count
    Assert-Equal $printedOne 0 'The tail printed more than the last line.'
    $tailFile = Get-Content -LiteralPath (Join-Path (Get-RunFolder $tail.Lines) 'output.txt')
    Assert-Contains @($tailFile) 'one' 'The output file lost the first line.'

    # 6. A timeout stops the command tree and exits 124.
    $timeout = Invoke-Tool @('run', '-Command', 'ping -n 30 127.0.0.1', '-TimeoutSeconds', '2', '-WorkingDirectory', $TestDirectory)
    Assert-Equal $timeout.ExitCode 124 'The timeout did not exit 124.'
    Assert-Contains $timeout.Lines 'timeout after 2 s' 'The timeout was not reported.'
    $launched = Get-LaunchedProcessId $timeout.Lines
    Assert-Equal ($launched -gt 0) $true 'The launched pid was not reported.'
    Start-Sleep -Milliseconds 500
    $stillRunning = $false
    try { Get-Process -Id $launched -ErrorAction Stop | Out-Null; $stillRunning = $true } catch { $stillRunning = $false }
    Assert-Equal $stillRunning $false 'The launched process survived the timeout.'

    # 7. The Task Scheduler launcher also works and leaves no task behind.
    $task = Invoke-Tool @('run', '-Launcher', 'task', '-Command', 'cmd.exe /d /c echo via-task', '-WorkingDirectory', $TestDirectory)
    Assert-Equal $task.ExitCode 0 'The task launcher run did not exit 0.'
    Assert-Contains $task.Lines 'via-task' 'The task launcher did not capture the output.'
    $taskName = 'minecraft-1.12.2-mod-agent-host-run-' + (Split-Path -Leaf (Get-RunFolder $task.Lines))
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & schtasks.exe /query /tn $taskName 2>&1 | Out-Null; $queryCode = $LASTEXITCODE } finally { $ErrorActionPreference = $previous }
    Assert-Equal ($queryCode -ne 0) $true 'The scheduled task was not removed after the run.'

    # 8. Bad input is rejected before anything starts.
    $badSet = Invoke-Tool @('run', '-Command', 'cmd.exe /d /c echo x', '-Set', 'bad value', '-WorkingDirectory', $TestDirectory)
    Assert-Equal ($badSet.ExitCode -ne 0) $true 'A malformed -Set value was accepted.'
    Assert-Contains $badSet.Lines 'must look like NAME=value' 'The malformed -Set value was not explained.'
    $badDirectory = Invoke-Tool @('run', '-Command', 'cmd.exe /d /c echo x', '-WorkingDirectory', (Join-Path $TestDirectory 'missing'))
    Assert-Equal ($badDirectory.ExitCode -ne 0) $true 'A missing working directory was accepted.'
    Assert-Contains $badDirectory.Lines 'Working directory not found' 'The missing working directory was not explained.'
    $noCommand = Invoke-Tool @('run', '-WorkingDirectory', $TestDirectory)
    Assert-Equal ($noCommand.ExitCode -ne 0) $true 'A run without -Command was accepted.'

    # 9. The batch launcher works with module autoloading disabled.
    $launcherCommand = 'set "PSModuleAutoLoadingPreference=None" && call "' + $Launcher + '" probe -Quiet -WorkingDirectory "' + $TestDirectory + '"'
    $launcherOutput = @(& cmd.exe /d /c $launcherCommand)
    Assert-Equal $LASTEXITCODE 0 'Batch launcher failed with module autoload disabled.'
    Assert-Contains @($launcherOutput | ForEach-Object { [string]$_ }) 'probe OK' 'Batch launcher did not run the probe with module autoload disabled.'

    Write-Output 'All host-run tests passed.'
}
finally {
    Remove-Item Env:MINECRAFT_MOD_AGENT_HOST_RUN_ROOT -ErrorAction SilentlyContinue
    if ([IO.Directory]::Exists($TestDirectory)) {
        $resolved = [IO.Path]::GetFullPath($TestDirectory)
        $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notmatch '^minecraft-host-run-[0-9a-f]{32}$') {
            throw "Refusing to remove unexpected test directory: $resolved"
        }
        [IO.Directory]::Delete($resolved, $true)
    }
}

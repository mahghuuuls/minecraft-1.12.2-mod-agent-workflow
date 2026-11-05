# The cross-project consultation procedure owns when to call this helper.
[CmdletBinding()]
param(
    [ValidateSet('Check', 'Install')]
    [string]$Action = 'Check',
    [string]$Executable,
    [string]$PythonExecutable,
    [switch]$OwnerApproved
)

$ErrorActionPreference = 'Stop'
$version = '0.2.0'
$wheel = "agent_relay-$version-py3-none-any.whl"
$url = "https://github.com/mahghuuuls/agent-relay/releases/download/v$version/$wheel"
$sha256 = '796063e9a6d71f5d4f12dfb8ab314bd6a910ac445493591a984b4884e6945d8a'
$root = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'MinecraftModAgentWorkflow\agent-relay'))
$target = Join-Path $root $version
$managed = Join-Path $target 'Scripts\agent-relay.exe'

function Get-CompatibleRelay([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $resolved = (Resolve-Path -LiteralPath $Path).ProviderPath
    try {
        $reported = & $resolved --version 2>$null
        if ($LASTEXITCODE -eq 0 -and ($reported -join '').Trim() -eq "agent-relay $version") {
            return $resolved
        }
    } catch {
        Write-Verbose "Could not probe Agent Relay at $resolved."
    }
}

function Write-Result([string]$Status, [string]$Path) {
    [ordered]@{ status = $Status; version = $version; executable = $Path } | ConvertTo-Json -Compress
}

function Get-InstalledPython {
    $knownRoots = @(
        (Join-Path $env:LOCALAPPDATA 'Python'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python')
    )
    $interpreters = @($PythonExecutable) + @(
        Get-Command python.exe -CommandType Application -All -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Source }
    ) + @(
        foreach ($knownRoot in $knownRoots) {
            Get-ChildItem -LiteralPath $knownRoot -Directory -Filter 'Python*' -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName 'python.exe' }
        }
    )
    foreach ($candidate in $interpreters) {
        if (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $path = (Resolve-Path -LiteralPath $candidate).ProviderPath
        # Store aliases and the py launcher can install Python instead of probing it.
        if ((Split-Path -Leaf $path) -ine 'python.exe' -or $path -match '[\\/]WindowsApps[\\/]') { continue }
        try {
            & $path -I -c 'import sys, venv, ensurepip; sys.exit(sys.version_info < (3, 10))' 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { return $path }
        } catch {
            Write-Verbose "Could not probe Python at $path."
        }
    }
}

if ($Action -eq 'Install' -and -not $OwnerApproved) {
    throw 'Owner approval is required before downloading or installing Agent Relay.'
}

$candidates = @($Executable, $managed) + @(
    Get-Command agent-relay -CommandType Application -All -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Source }
)
foreach ($candidate in $candidates) {
    $compatible = Get-CompatibleRelay $candidate
    if ($compatible) {
        Write-Result 'installed' $compatible
        return
    }
}
if ($Action -eq 'Check') {
    Write-Result 'missing' ''
    return
}

$installedPython = Get-InstalledPython
if (-not $installedPython) {
    throw 'Install requires an existing Python 3.10 or later with venv and ensurepip. Use -PythonExecutable to supply its path.'
}
if (Test-Path -LiteralPath $target) {
    throw "The managed install path is occupied without a compatible executable: $target"
}

$temporary = Join-Path ([IO.Path]::GetTempPath()) ('agent-relay-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
$download = Join-Path $temporary $wheel
$created = $false
try {
    Invoke-WebRequest -Uri $url -OutFile $download -UseBasicParsing -TimeoutSec 60
    if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ine $sha256) {
        throw 'Agent Relay wheel checksum mismatch.'
    }
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    New-Item -ItemType Directory -Path $target | Out-Null
    $created = $true
    & $installedPython -m venv $target | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the Agent Relay virtual environment.' }
    $python = Join-Path $target 'Scripts\python.exe'
    & $python -m pip install --no-index --no-deps --disable-pip-version-check $download | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Agent Relay installation failed.' }
    $compatible = Get-CompatibleRelay $managed
    if (-not $compatible) { throw 'The installed executable did not report the pinned Agent Relay version.' }
    Write-Result 'installed' $compatible
} catch {
    if ($created -and (Test-Path -LiteralPath $target -PathType Container)) {
        $item = Get-Item -LiteralPath $target
        if ($item.FullName -eq $target -and $item.Parent.FullName -eq $root -and
            -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force
        }
    }
    throw
} finally {
    if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
    Remove-Item -LiteralPath $temporary
}

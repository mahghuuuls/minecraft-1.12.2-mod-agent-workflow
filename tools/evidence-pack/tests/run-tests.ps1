[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'evidence-pack.ps1'
$Launcher = Join-Path (Split-Path -Parent $PSScriptRoot) 'evidence-pack.cmd'
$TestDirectory = Join-Path ([IO.Path]::GetTempPath()) ('minecraft-evidence-pack-' + [Guid]::NewGuid().ToString('N'))
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $parent = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($parent)) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    [IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Invoke-GitFixture {
    param([string]$Repository, [string[]]$Arguments)
    Push-Location $Repository
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & git @Arguments 2>$null | Out-Null
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($exitCode -ne 0) { throw "Fixture Git command failed: git $($Arguments -join ' ')" }
    }
    finally {
        Pop-Location
    }
}

[IO.Directory]::CreateDirectory($TestDirectory) | Out-Null
try {
    $repository = Join-Path $TestDirectory 'repo'
    [IO.Directory]::CreateDirectory($repository) | Out-Null
    Invoke-GitFixture $repository @('init', '--initial-branch=main')
    Invoke-GitFixture $repository @('config', 'user.name', 'Evidence Pack Tests')
    Invoke-GitFixture $repository @('config', 'user.email', 'evidence-pack@example.invalid')
    Write-Utf8 (Join-Path $repository '.gitignore') "build/`r`nrun/`r`n"
    Write-Utf8 (Join-Path $repository 'source.txt') "source`r`n"
    Invoke-GitFixture $repository @('add', '.gitignore', 'source.txt')
    Invoke-GitFixture $repository @('commit', '-m', 'Create fixture')

    $reportsDirectory = Join-Path $repository 'build\test-results\test'
    Write-Utf8 (Join-Path $reportsDirectory 'TEST-one.xml') '<testsuite name="one" tests="2" failures="0" errors="0" skipped="0"></testsuite>'
    Write-Utf8 (Join-Path $reportsDirectory 'TEST-two.xml') '<testsuite name="two" tests="3" failures="0" errors="0" skipped="1"></testsuite>'

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $jarSource = Join-Path $TestDirectory 'jar-source'
    Write-Utf8 (Join-Path $jarSource 'com\example\Mod.class') 'not-real-bytecode'
    Write-Utf8 (Join-Path $jarSource 'forbidden\dependency\Leak.class') 'not-real-bytecode'
    Write-Utf8 (Join-Path $jarSource 'assets\example\lang\en_us.lang') 'item.example.name=Example'
    $jarPath = Join-Path $repository 'build\libs\example.jar'
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($jarPath)) | Out-Null
    [IO.Compression.ZipFile]::CreateFromDirectory($jarSource, $jarPath)

    $logPath = Join-Path $repository 'run\logs\latest.log'
    Write-Utf8 $logPath "[Server thread/INFO] [example]: ready`r`n"

    $specPath = Join-Path $TestDirectory 'spec.json'
    $outputDirectory = Join-Path $TestDirectory 'evidence\final-fixture'
    $specification = [ordered]@{
        schemaVersion = 1
        checkpoint = 'fixture-final'
        baseDirectory = $TestDirectory
        sourceRepository = 'repo'
        outputDirectory = 'evidence/final-fixture'
        requireClean = $true
        junit = @(
            [ordered]@{ name = 'unit'; sourceDirectory = 'repo/build/test-results/test'; pattern = '*.xml' }
        )
        files = @(
            [ordered]@{
                path = 'repo/build/libs/example.jar'
                destination = 'artifacts/example.jar'
                role = 'built-mod'
                inspectJar = $true
                forbiddenPrefixes = @('forbidden/dependency/')
            },
            [ordered]@{
                path = 'repo/run/logs/latest.log'
                destination = 'runtime/dedicated-server.log'
                role = 'dedicated-server-log'
            }
        )
    }
    Write-Utf8 $specPath (($specification | ConvertTo-Json -Depth 8) + "`r`n")

    $captureOutput = @(& $Tool capture -Spec $specPath)
    Assert-Equal ([IO.Directory]::Exists($outputDirectory)) $true 'Capture did not create the evidence pack.'
    Assert-Equal ($captureOutput -join "`n" -like '*JUnit 5 tests across 2 suites*') $true 'Capture summary did not report JUnit totals.'

    $manifestPath = Join-Path $outputDirectory 'manifest.json'
    $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    Assert-Equal $manifest.checkpoint 'fixture-final' 'Checkpoint identity is wrong.'
    Assert-Equal $manifest.toolVersion '1.1.0' 'Tool version is wrong.'
    Assert-Equal $manifest.source.worktreeClean $true 'Clean fixture was recorded as dirty.'
    Assert-Equal $manifest.source.commit.Length 40 'Captured commit is not a complete SHA-1 object ID.'
    Assert-Equal $manifest.source.tree.Length 40 'Captured tree is not a complete SHA-1 object ID.'
    Assert-Equal $manifest.tests.suites 2 'JUnit suite count is wrong.'
    Assert-Equal $manifest.tests.tests 5 'JUnit test count is wrong.'
    Assert-Equal $manifest.tests.skipped 1 'JUnit skipped count is wrong.'
    Assert-Equal $manifest.jars[0].entries 3 'JAR entry count is wrong.'
    Assert-Equal $manifest.jars[0].classes 2 'JAR class count is wrong.'
    Assert-Equal $manifest.jars[0].resources 1 'JAR resource count is wrong.'
    Assert-Equal $manifest.jars[0].forbiddenMatches.Count 1 'JAR forbidden-prefix result is wrong.'

    $verifyOutput = @(& $Tool verify -Manifest $manifestPath)
    Assert-Equal ($verifyOutput -join "`n" -like '*Evidence pack verified: fixture-final*') $true 'Verification did not report success.'
    $inspectOutput = @(& $Tool inspect -Manifest $manifestPath)
    Assert-Equal ($inspectOutput -join "`n" -like '*Checkpoint: fixture-final*') $true 'Inspection did not report checkpoint identity.'

    $launcherCommand = 'set "PSModuleAutoLoadingPreference=None" && call "' + $Launcher + '" verify -Manifest "' + $manifestPath + '"'
    $launcherOutput = @(& cmd.exe /d /c $launcherCommand)
    Assert-Equal $LASTEXITCODE 0 'Batch launcher failed with module autoload disabled.'
    Assert-Equal ($launcherOutput -join "`n" -like '*Evidence pack verified: fixture-final*') $true 'Batch launcher did not verify the pack with module autoload disabled.'

    $validManifestBytes = [IO.File]::ReadAllBytes($manifestPath)
    $validHashBytes = [IO.File]::ReadAllBytes((Join-Path $outputDirectory 'manifest.sha256'))
    $invalidIdentityManifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    $invalidIdentityManifest.source.commit = '6'
    Write-Utf8 $manifestPath (($invalidIdentityManifest | ConvertTo-Json -Depth 12) + "`r`n")
    Write-Utf8 (Join-Path $outputDirectory 'manifest.sha256') "$(Get-Sha256 $manifestPath)  manifest.json`r`n"
    $invalidIdentityRejected = $false
    try { & $Tool verify -Manifest $manifestPath 2>$null | Out-Null }
    catch { $invalidIdentityRejected = $_.Exception.Message -like '*complete 40- or 64-character*' }
    Assert-Equal $invalidIdentityRejected $true 'Verifier accepted a truncated Git object ID.'
    [IO.File]::WriteAllBytes($manifestPath, $validManifestBytes)
    [IO.File]::WriteAllBytes((Join-Path $outputDirectory 'manifest.sha256'), $validHashBytes)

    $manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
    [IO.File]::AppendAllText($manifestPath, " ", $Utf8NoBom)
    $manifestTamperRejected = $false
    try { & $Tool verify -Manifest $manifestPath 2>$null | Out-Null }
    catch { $manifestTamperRejected = $_.Exception.Message -like '*Manifest SHA-256 mismatch*' }
    Assert-Equal $manifestTamperRejected $true 'Tampered manifest was not rejected.'
    [IO.File]::WriteAllBytes($manifestPath, $manifestBytes)

    $retainedLog = Join-Path $outputDirectory 'runtime\dedicated-server.log'
    Write-Utf8 $retainedLog "tampered`r`n"
    $tamperRejected = $false
    try { & $Tool verify -Manifest $manifestPath 2>$null | Out-Null }
    catch { $tamperRejected = $_.Exception.Message -like '*mismatch*' }
    Assert-Equal $tamperRejected $true 'Tampered retained evidence was not rejected.'
    [IO.File]::Copy($logPath, $retainedLog, $true)
    & $Tool verify -Manifest $manifestPath | Out-Null

    $unexpectedPath = Join-Path $outputDirectory 'unexpected.txt'
    Write-Utf8 $unexpectedPath 'unexpected'
    $unexpectedRejected = $false
    try { & $Tool verify -Manifest $manifestPath 2>$null | Out-Null }
    catch { $unexpectedRejected = $_.Exception.Message -like '*Unexpected file*' }
    Assert-Equal $unexpectedRejected $true 'Unexpected evidence-pack file was not rejected.'
    [IO.File]::Delete($unexpectedPath)

    $overwriteRejected = $false
    try { & $Tool capture -Spec $specPath 2>$null | Out-Null }
    catch { $overwriteRejected = $_.Exception.Message -like '*will not be overwritten*' }
    Assert-Equal $overwriteRejected $true 'Existing evidence pack was not protected.'

    $noJUnitSpecification = ($specification | ConvertTo-Json -Depth 8) | ConvertFrom-Json
    $noJUnitSpecification.checkpoint = 'fixture-no-junit'
    $noJUnitSpecification.outputDirectory = 'evidence/no-junit-fixture'
    $noJUnitSpecification.junit = @()
    $noJUnitSpecification.files = @($noJUnitSpecification.files[1])
    $noJUnitSpecPath = Join-Path $TestDirectory 'no-junit-spec.json'
    Write-Utf8 $noJUnitSpecPath (($noJUnitSpecification | ConvertTo-Json -Depth 8) + "`r`n")
    & $Tool capture -Spec $noJUnitSpecPath | Out-Null
    $noJUnitManifestPath = Join-Path $TestDirectory 'evidence\no-junit-fixture\manifest.json'
    & $Tool verify -Manifest $noJUnitManifestPath | Out-Null
    $noJUnitManifest = [IO.File]::ReadAllText($noJUnitManifestPath) | ConvertFrom-Json
    Assert-Equal $noJUnitManifest.tests.tests 0 'No-JUnit pack did not record zero tests.'
    Assert-Equal $noJUnitManifest.tests.groups.Count 0 'No-JUnit pack retained a phantom report group.'

    $insideSpecification = ($specification | ConvertTo-Json -Depth 8) | ConvertFrom-Json
    $insideSpecification.outputDirectory = 'repo/evidence-pack'
    $insideSpecPath = Join-Path $TestDirectory 'inside-spec.json'
    Write-Utf8 $insideSpecPath (($insideSpecification | ConvertTo-Json -Depth 8) + "`r`n")
    $insideRejected = $false
    try { & $Tool capture -Spec $insideSpecPath 2>$null | Out-Null }
    catch { $insideRejected = $_.Exception.Message -like '*must be outside the source repository*' }
    Assert-Equal $insideRejected $true 'Output inside the source repository was not rejected.'

    $dirtyPath = Join-Path $repository 'dirty.txt'
    Write-Utf8 $dirtyPath 'dirty'
    $dirtySpecification = ($specification | ConvertTo-Json -Depth 8) | ConvertFrom-Json
    $dirtySpecification.outputDirectory = 'evidence/dirty-fixture'
    $dirtySpecPath = Join-Path $TestDirectory 'dirty-spec.json'
    Write-Utf8 $dirtySpecPath (($dirtySpecification | ConvertTo-Json -Depth 8) + "`r`n")
    $dirtyRejected = $false
    try { & $Tool capture -Spec $dirtySpecPath 2>$null | Out-Null }
    catch { $dirtyRejected = $_.Exception.Message -like '*requires a clean source worktree*' }
    Assert-Equal $dirtyRejected $true 'Dirty worktree was not rejected by the default clean gate.'

    $dirtyAllowedSpecification = ($dirtySpecification | ConvertTo-Json -Depth 8) | ConvertFrom-Json
    $dirtyAllowedSpecification.outputDirectory = 'evidence/dirty-allowed-fixture'
    $dirtyAllowedSpecification.requireClean = $false
    $dirtyAllowedSpecPath = Join-Path $TestDirectory 'dirty-allowed-spec.json'
    Write-Utf8 $dirtyAllowedSpecPath (($dirtyAllowedSpecification | ConvertTo-Json -Depth 8) + "`r`n")
    & $Tool capture -Spec $dirtyAllowedSpecPath | Out-Null
    $dirtyManifest = [IO.File]::ReadAllText((Join-Path $TestDirectory 'evidence\dirty-allowed-fixture\manifest.json')) | ConvertFrom-Json
    Assert-Equal $dirtyManifest.source.worktreeClean $false 'Explicit dirty capture was recorded as clean.'
    Assert-Equal $dirtyManifest.source.status.Count 1 'Explicit dirty capture did not retain the changed path.'

    Write-Output 'All evidence-pack tests passed.'
}
finally {
    if ([IO.Directory]::Exists($TestDirectory)) {
        $resolved = [IO.Path]::GetFullPath($TestDirectory)
        $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notmatch '^minecraft-evidence-pack-[0-9a-f]{32}$') {
            throw "Refusing to remove unexpected test directory: $resolved"
        }
        foreach ($file in Get-ChildItem -LiteralPath $resolved -Recurse -Force -File) {
            [IO.File]::SetAttributes($file.FullName, [IO.FileAttributes]::Normal)
        }
        [IO.Directory]::Delete($resolved, $true)
    }
}

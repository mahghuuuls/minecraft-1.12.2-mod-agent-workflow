[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('capture', 'verify', 'inspect')]
    [string]$Action,

    [string]$Spec,

    [string]$Manifest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

function Get-OptionalProperty {
    param($Object, [string]$Name, $DefaultValue)

    if ($null -eq $Object) { return $DefaultValue }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $DefaultValue }
    return $property.Value
}

function Get-OptionalBoolean {
    param($Object, [string]$Name, [bool]$DefaultValue)

    $value = Get-OptionalProperty $Object $Name $DefaultValue
    if ($value -isnot [bool]) { throw "Specification property '$Name' must be true or false." }
    return [bool]$value
}

function Resolve-ConfiguredPath {
    param([string]$BaseDirectory, [string]$ConfiguredPath)

    if ([string]::IsNullOrWhiteSpace($ConfiguredPath)) {
        throw 'A configured path is empty.'
    }

    if ([IO.Path]::IsPathRooted($ConfiguredPath)) {
        return [IO.Path]::GetFullPath($ConfiguredPath)
    }
    return [IO.Path]::GetFullPath((Join-Path $BaseDirectory $ConfiguredPath))
}

function Convert-ToPortablePath {
    param([string]$Path)
    return $Path.Replace('\', '/')
}

function Assert-SafeRelativePath {
    param([string]$Path, [string]$Label)

    if ([string]::IsNullOrWhiteSpace($Path) -or [IO.Path]::IsPathRooted($Path)) {
        throw "$Label must be a non-empty relative path."
    }

    $segments = $Path.Replace('\', '/').Split('/')
    foreach ($segment in $segments) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "$Label contains an unsafe path segment: '$Path'."
        }
        if ($segment.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
            throw "$Label contains an invalid filename segment: '$Path'."
        }
    }
}

function Assert-SafeIdentifier {
    param([string]$Value, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') {
        throw "$Label must use 1..128 letters, digits, periods, underscores, or hyphens and must start with a letter or digit."
    }
}

function Test-PathInside {
    param([string]$Candidate, [string]$Parent)
    $parentPrefix = [IO.Path]::GetFullPath($Parent).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $candidateFull = [IO.Path]::GetFullPath($Candidate).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    return $candidateFull.StartsWith($parentPrefix, [StringComparison]::OrdinalIgnoreCase)
}

function Invoke-Git {
    param([string]$Repository, [string[]]$Arguments)

    Push-Location $Repository
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = @(& git @Arguments 2>$null)
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($exitCode -ne 0) {
            throw "Git command failed in ${Repository}: git $($Arguments -join ' ')"
        }
        return @($output | ForEach-Object { [string]$_ })
    }
    finally {
        Pop-Location
    }
}

function Get-FileIdentity {
    param([string]$Path)

    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        bytes = [int64]$item.Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
        modifiedUtc = $item.LastWriteTimeUtc.ToString('o')
    }
}

function Get-JUnitAttribute {
    param($Node, [string]$Name)
    if ($null -eq $Node.Attributes[$Name]) { return [int64]0 }
    $value = [int64]0
    if (-not [int64]::TryParse($Node.Attributes[$Name].Value, [ref]$value)) {
        throw "JUnit attribute '$Name' is not an integer in $($Node.OwnerDocument.BaseURI)."
    }
    return $value
}

function Get-JUnitTotals {
    param([string[]]$Paths)

    [int64]$suiteCount = 0
    [int64]$testCount = 0
    [int64]$failureCount = 0
    [int64]$errorCount = 0
    [int64]$skippedCount = 0

    foreach ($path in $Paths) {
        [xml]$document = [IO.File]::ReadAllText($path)
        $root = $document.DocumentElement
        if ($null -eq $root -or ($root.LocalName -ne 'testsuite' -and $root.LocalName -ne 'testsuites')) {
            throw "JUnit report does not have a testsuite or testsuites root: $path"
        }

        $suiteNodes = @($document.SelectNodes('//testsuite'))
        $suiteCount += $suiteNodes.Count

        if ($root.LocalName -eq 'testsuites' -and $null -ne $root.Attributes['tests']) {
            $testCount += Get-JUnitAttribute $root 'tests'
            $failureCount += Get-JUnitAttribute $root 'failures'
            $errorCount += Get-JUnitAttribute $root 'errors'
            $skippedCount += Get-JUnitAttribute $root 'skipped'
        }
        elseif ($root.LocalName -eq 'testsuite') {
            $testCount += Get-JUnitAttribute $root 'tests'
            $failureCount += Get-JUnitAttribute $root 'failures'
            $errorCount += Get-JUnitAttribute $root 'errors'
            $skippedCount += Get-JUnitAttribute $root 'skipped'
        }
        else {
            foreach ($suite in $suiteNodes) {
                $testCount += Get-JUnitAttribute $suite 'tests'
                $failureCount += Get-JUnitAttribute $suite 'failures'
                $errorCount += Get-JUnitAttribute $suite 'errors'
                $skippedCount += Get-JUnitAttribute $suite 'skipped'
            }
        }
    }

    return [ordered]@{
        suites = $suiteCount
        tests = $testCount
        failures = $failureCount
        errors = $errorCount
        skipped = $skippedCount
    }
}

function Get-JarInspection {
    param([string]$Path, [string[]]$ForbiddenPrefixes)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        $fileEntryNames = @($entryNames | Where-Object { -not $_.EndsWith('/', [StringComparison]::Ordinal) })
        $classNames = @($fileEntryNames | Where-Object { $_.EndsWith('.class', [StringComparison]::OrdinalIgnoreCase) })
        $normalizedPrefixes = @($ForbiddenPrefixes | ForEach-Object { $_.Replace('\', '/').TrimStart('/').TrimEnd('/') + '/' })
        $forbiddenMatches = [System.Collections.Generic.List[string]]::new()
        foreach ($entryName in $entryNames) {
            foreach ($prefix in $normalizedPrefixes) {
                if ($entryName.StartsWith($prefix, [StringComparison]::Ordinal)) {
                    $forbiddenMatches.Add($entryName)
                    break
                }
            }
        }

        return [ordered]@{
            entries = $entryNames.Count
            classes = $classNames.Count
            resources = $fileEntryNames.Count - $classNames.Count
            forbiddenPrefixes = @($normalizedPrefixes)
            forbiddenMatches = @($forbiddenMatches | Sort-Object)
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Add-RetainedFile {
    param(
        [string]$SourcePath,
        [string]$SourceDisplay,
        [string]$Destination,
        [string]$Role,
        [string]$TemporaryDirectory,
        [System.Collections.Generic.HashSet[string]]$Destinations,
        [System.Collections.Generic.List[object]]$ManifestFiles
    )

    Assert-SafeRelativePath $Destination 'Retained destination'
    $portableDestination = Convert-ToPortablePath $Destination
    if (-not $Destinations.Add($portableDestination)) {
        throw "More than one retained file uses destination '$portableDestination'."
    }
    if (-not [IO.File]::Exists($SourcePath)) {
        throw "Source file not found: $SourcePath"
    }

    $retainedPath = Join-Path $TemporaryDirectory $Destination
    $parent = [IO.Path]::GetDirectoryName($retainedPath)
    if (-not [IO.Directory]::Exists($parent)) {
        [IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    [IO.File]::Copy($SourcePath, $retainedPath, $false)

    $identity = Get-FileIdentity $retainedPath
    $ManifestFiles.Add([ordered]@{
        sourcePath = Convert-ToPortablePath $SourceDisplay
        retainedPath = $portableDestination
        role = $Role
        bytes = $identity.bytes
        sha256 = $identity.sha256
        modifiedUtc = $identity.modifiedUtc
    })
    return $retainedPath
}

function Add-GeneratedFileRecord {
    param(
        [string]$Path,
        [string]$Destination,
        [string]$Role,
        [System.Collections.Generic.HashSet[string]]$Destinations,
        [System.Collections.Generic.List[object]]$ManifestFiles
    )

    $portableDestination = Convert-ToPortablePath $Destination
    if (-not $Destinations.Add($portableDestination)) {
        throw "More than one retained file uses destination '$portableDestination'."
    }
    $identity = Get-FileIdentity $Path
    $ManifestFiles.Add([ordered]@{
        sourcePath = '(generated)'
        retainedPath = $portableDestination
        role = $Role
        bytes = $identity.bytes
        sha256 = $identity.sha256
        modifiedUtc = $identity.modifiedUtc
    })
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    [IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function New-SummaryText {
    param($Checkpoint, $CapturedAt, $Source, $Tests, $Files, $Jars)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Evidence Pack: $Checkpoint")
    $lines.Add('')
    $lines.Add("- Captured UTC: $CapturedAt")
    $lines.Add("- Source commit: $($Source.commit)")
    $lines.Add("- Source tree: $($Source.tree)")
    $lines.Add("- Branch: $($Source.branch)")
    $lines.Add("- Worktree clean: $($Source.worktreeClean)")
    $lines.Add("- JUnit suites/tests: $($Tests.suites) / $($Tests.tests)")
    $lines.Add("- JUnit failures/errors/skipped: $($Tests.failures) / $($Tests.errors) / $($Tests.skipped)")
    $lines.Add("- Captured input files: $($Files.Count)")
    $lines.Add('')
    $lines.Add('## Retained Inputs')
    $lines.Add('')
    $lines.Add('| Role | Retained Path | Bytes | SHA-256 |')
    $lines.Add('| --- | --- | ---: | --- |')
    foreach ($file in $Files) {
        $lines.Add("| $($file.role) | ``$($file.retainedPath)`` | $($file.bytes) | ``$($file.sha256)`` |")
    }

    if ($Jars.Count -gt 0) {
        $lines.Add('')
        $lines.Add('## JAR Inspection')
        $lines.Add('')
        $lines.Add('| Retained Path | Entries | Classes | Resources | Forbidden Matches |')
        $lines.Add('| --- | ---: | ---: | ---: | ---: |')
        foreach ($jar in $Jars) {
            $lines.Add("| ``$($jar.retainedPath)`` | $($jar.entries) | $($jar.classes) | $($jar.resources) | $($jar.forbiddenMatches.Count) |")
        }
    }

    $lines.Add('')
    $lines.Add('This summary records mechanical identities only. It does not assign evidence labels or decide requirement satisfaction.')
    return ($lines -join "`r`n") + "`r`n"
}

function Remove-TemporaryPack {
    param([string]$TemporaryDirectory, [string]$ExpectedParent)

    if (-not [IO.Directory]::Exists($TemporaryDirectory)) { return }
    $resolvedTemporary = [IO.Path]::GetFullPath($TemporaryDirectory)
    $resolvedParent = [IO.Path]::GetFullPath($ExpectedParent)
    if ([IO.Path]::GetDirectoryName($resolvedTemporary) -ne $resolvedParent -or [IO.Path]::GetFileName($resolvedTemporary) -notmatch '\.tmp-[0-9a-f]{32}$') {
        throw "Refusing to remove unexpected temporary directory: $resolvedTemporary"
    }
    [IO.Directory]::Delete($resolvedTemporary, $true)
}

function Invoke-Capture {
    param([string]$SpecPath)

    if ([string]::IsNullOrWhiteSpace($SpecPath)) { throw 'capture requires -Spec <path>.' }
    $resolvedSpec = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SpecPath))
    if (-not [IO.File]::Exists($resolvedSpec)) { throw "Specification not found: $resolvedSpec" }

    $specification = [IO.File]::ReadAllText($resolvedSpec) | ConvertFrom-Json
    if ((Get-OptionalProperty $specification 'schemaVersion' 0) -ne 1) { throw 'Evidence-pack specification schemaVersion must be 1.' }
    $checkpoint = [string](Get-OptionalProperty $specification 'checkpoint' '')
    Assert-SafeIdentifier $checkpoint 'checkpoint'

    $specDirectory = [IO.Path]::GetDirectoryName($resolvedSpec)
    $configuredBase = [string](Get-OptionalProperty $specification 'baseDirectory' '.')
    $baseDirectory = Resolve-ConfiguredPath $specDirectory $configuredBase
    $sourceRepositoryValue = [string](Get-OptionalProperty $specification 'sourceRepository' '')
    $outputDirectoryValue = [string](Get-OptionalProperty $specification 'outputDirectory' '')
    $sourceRepository = Resolve-ConfiguredPath $baseDirectory $sourceRepositoryValue
    $outputDirectory = Resolve-ConfiguredPath $baseDirectory $outputDirectoryValue

    $gitMarker = Join-Path $sourceRepository '.git'
    if (-not [IO.Directory]::Exists($gitMarker) -and -not [IO.File]::Exists($gitMarker)) { throw "Source repository is not a Git worktree: $sourceRepository" }
    if (Test-PathInside $outputDirectory $sourceRepository) { throw 'Evidence-pack outputDirectory must be outside the source repository.' }
    if ([IO.Directory]::Exists($outputDirectory) -or [IO.File]::Exists($outputDirectory)) { throw "Evidence-pack output already exists and will not be overwritten: $outputDirectory" }

    $commit = (Invoke-Git $sourceRepository @('rev-parse', 'HEAD'))[0]
    $tree = (Invoke-Git $sourceRepository @('rev-parse', 'HEAD^{tree}'))[0]
    $branchLines = @(Invoke-Git $sourceRepository @('branch', '--show-current'))
    $branch = if ($branchLines.Count -gt 0) { $branchLines[0] } else { '(detached)' }
    $statusLines = @(Invoke-Git $sourceRepository @('status', '--porcelain=v1', '--untracked-files=all'))
    $worktreeClean = $statusLines.Count -eq 0
    $requireClean = Get-OptionalBoolean $specification 'requireClean' $true
    if ($requireClean -and -not $worktreeClean) {
        throw "Evidence checkpoint '$checkpoint' requires a clean source worktree, but Git reported $($statusLines.Count) changed path(s)."
    }

    $outputParent = [IO.Path]::GetDirectoryName($outputDirectory)
    if (-not [IO.Directory]::Exists($outputParent)) { [IO.Directory]::CreateDirectory($outputParent) | Out-Null }
    $temporaryDirectory = "$outputDirectory.tmp-$([Guid]::NewGuid().ToString('N'))"
    [IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null

    $destinations = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $manifestFiles = [System.Collections.Generic.List[object]]::new()
    $junitGroups = [System.Collections.Generic.List[object]]::new()
    $jarInspections = [System.Collections.Generic.List[object]]::new()
    [int64]$totalSuites = 0
    [int64]$totalTests = 0
    [int64]$totalFailures = 0
    [int64]$totalErrors = 0
    [int64]$totalSkipped = 0

    try {
        foreach ($group in @(Get-OptionalProperty $specification 'junit' @())) {
            $groupName = [string](Get-OptionalProperty $group 'name' '')
            Assert-SafeIdentifier $groupName 'JUnit group name'
            $sourceDirectoryValue = [string](Get-OptionalProperty $group 'sourceDirectory' '')
            $sourceDirectory = Resolve-ConfiguredPath $baseDirectory $sourceDirectoryValue
            if (-not [IO.Directory]::Exists($sourceDirectory)) { throw "JUnit source directory not found: $sourceDirectory" }
            $pattern = [string](Get-OptionalProperty $group 'pattern' '*.xml')
            if ($pattern.IndexOfAny([char[]]@('/', '\')) -ge 0) { throw "JUnit pattern must be a filename pattern, not a path: $pattern" }
            $reports = @(Get-ChildItem -LiteralPath $sourceDirectory -File -Filter $pattern | Sort-Object Name)
            if ($reports.Count -eq 0) { throw "JUnit group '$groupName' found no reports in $sourceDirectory matching $pattern." }

            $retainedReports = [System.Collections.Generic.List[string]]::new()
            $retainedReportPaths = [System.Collections.Generic.List[string]]::new()
            foreach ($report in $reports) {
                $destination = "test-results/$groupName/$($report.Name)"
                $retained = Add-RetainedFile $report.FullName "$sourceDirectoryValue/$($report.Name)" $destination "junit:$groupName" $temporaryDirectory $destinations $manifestFiles
                $retainedReports.Add((Convert-ToPortablePath $destination))
                $retainedReportPaths.Add($retained)
            }
            $groupTotals = Get-JUnitTotals ([string[]]$retainedReportPaths.ToArray())
            $totalSuites += $groupTotals.suites
            $totalTests += $groupTotals.tests
            $totalFailures += $groupTotals.failures
            $totalErrors += $groupTotals.errors
            $totalSkipped += $groupTotals.skipped
            $junitGroups.Add([ordered]@{
                name = $groupName
                reports = @($retainedReports)
                suites = $groupTotals.suites
                tests = $groupTotals.tests
                failures = $groupTotals.failures
                errors = $groupTotals.errors
                skipped = $groupTotals.skipped
            })
        }

        foreach ($file in @(Get-OptionalProperty $specification 'files' @())) {
            $sourceValue = [string](Get-OptionalProperty $file 'path' '')
            $destination = [string](Get-OptionalProperty $file 'destination' '')
            $role = [string](Get-OptionalProperty $file 'role' 'retained-file')
            $sourcePath = Resolve-ConfiguredPath $baseDirectory $sourceValue
            $retainedPath = Add-RetainedFile $sourcePath $sourceValue $destination $role $temporaryDirectory $destinations $manifestFiles

            $inspectJar = (Get-OptionalBoolean $file 'inspectJar' $false) -or $destination.EndsWith('.jar', [StringComparison]::OrdinalIgnoreCase)
            if ($inspectJar) {
                $forbiddenPrefixes = @((Get-OptionalProperty $file 'forbiddenPrefixes' @()) | ForEach-Object { [string]$_ })
                $inspection = Get-JarInspection $retainedPath ([string[]]$forbiddenPrefixes)
                $jarInspections.Add([ordered]@{
                    retainedPath = Convert-ToPortablePath $destination
                    entries = $inspection.entries
                    classes = $inspection.classes
                    resources = $inspection.resources
                    forbiddenPrefixes = @($inspection.forbiddenPrefixes)
                    forbiddenMatches = @($inspection.forbiddenMatches)
                })
            }
        }

        $capturedAt = [DateTime]::UtcNow.ToString('o')
        $source = [ordered]@{
            repository = Convert-ToPortablePath $sourceRepositoryValue
            commit = $commit
            tree = $tree
            branch = $branch
            worktreeClean = $worktreeClean
            status = @($statusLines)
        }
        $tests = [ordered]@{
            suites = $totalSuites
            tests = $totalTests
            failures = $totalFailures
            errors = $totalErrors
            skipped = $totalSkipped
            groups = @($junitGroups)
        }

        $summaryPath = Join-Path $temporaryDirectory 'summary.md'
        Write-Utf8File $summaryPath (New-SummaryText $checkpoint $capturedAt $source $tests $manifestFiles $jarInspections)
        Add-GeneratedFileRecord $summaryPath 'summary.md' 'generated-summary' $destinations $manifestFiles

        $manifestObject = [ordered]@{
            schemaVersion = 1
            toolVersion = '1.0.0'
            checkpoint = $checkpoint
            capturedAtUtc = $capturedAt
            source = $source
            tests = $tests
            files = @($manifestFiles)
            jars = @($jarInspections)
        }
        $manifestPath = Join-Path $temporaryDirectory 'manifest.json'
        Write-Utf8File $manifestPath (($manifestObject | ConvertTo-Json -Depth 12) + "`r`n")
        $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToUpperInvariant()
        Write-Utf8File (Join-Path $temporaryDirectory 'manifest.sha256') "$manifestHash  manifest.json`r`n"

        [IO.Directory]::Move($temporaryDirectory, $outputDirectory)
        Write-Output "Created evidence pack $outputDirectory"
        Write-Output "Manifest SHA-256 $manifestHash"
        Write-Output "Source $commit (tree $tree, clean=$worktreeClean)"
        Write-Output "JUnit $totalTests tests across $totalSuites suites; failures=$totalFailures errors=$totalErrors skipped=$totalSkipped"
    }
    catch {
        Remove-TemporaryPack $temporaryDirectory $outputParent
        throw
    }
}

function Read-ManifestWithIntegrity {
    param([string]$ManifestPath)

    $resolvedManifest = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ManifestPath))
    if (-not [IO.File]::Exists($resolvedManifest)) { throw "Manifest not found: $resolvedManifest" }
    $packRoot = [IO.Path]::GetDirectoryName($resolvedManifest)
    $hashPath = Join-Path $packRoot 'manifest.sha256'
    if (-not [IO.File]::Exists($hashPath)) { throw "Manifest hash file not found: $hashPath" }
    $hashLine = [IO.File]::ReadAllText($hashPath).Trim()
    if ($hashLine -notmatch '^(?<hash>[0-9A-Fa-f]{64})\s+manifest\.json$') { throw 'manifest.sha256 has an invalid format.' }
    $actualHash = (Get-FileHash -LiteralPath $resolvedManifest -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualHash -ne $Matches.hash.ToUpperInvariant()) { throw "Manifest SHA-256 mismatch: expected $($Matches.hash), got $actualHash." }
    $manifestObject = [IO.File]::ReadAllText($resolvedManifest) | ConvertFrom-Json
    if ((Get-OptionalProperty $manifestObject 'schemaVersion' 0) -ne 1) { throw 'Manifest schemaVersion must be 1.' }
    return [pscustomobject]@{ Path = $resolvedManifest; Root = $packRoot; Hash = $actualHash; Data = $manifestObject }
}

function Get-RetainedFullPath {
    param([string]$PackRoot, [string]$RetainedPath)
    Assert-SafeRelativePath $RetainedPath 'Manifest retainedPath'
    $fullPath = [IO.Path]::GetFullPath((Join-Path $PackRoot $RetainedPath))
    if (-not (Test-PathInside $fullPath $PackRoot)) { throw "Retained path escapes the evidence pack: $RetainedPath" }
    return $fullPath
}

function Invoke-Verify {
    param([string]$ManifestPath)

    if ([string]::IsNullOrWhiteSpace($ManifestPath)) { throw 'verify requires -Manifest <path>.' }
    $loaded = Read-ManifestWithIntegrity $ManifestPath
    $expectedPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $expectedPaths.Add('manifest.json') | Out-Null
    $expectedPaths.Add('manifest.sha256') | Out-Null

    foreach ($file in @($loaded.Data.files)) {
        $retainedPath = [string]$file.retainedPath
        $fullPath = Get-RetainedFullPath $loaded.Root $retainedPath
        if (-not [IO.File]::Exists($fullPath)) { throw "Retained file is missing: $retainedPath" }
        $identity = Get-FileIdentity $fullPath
        if ([int64]$file.bytes -ne $identity.bytes) { throw "Byte-size mismatch for ${retainedPath}: expected $($file.bytes), got $($identity.bytes)." }
        if ([string]$file.sha256 -ne $identity.sha256) { throw "SHA-256 mismatch for ${retainedPath}: expected $($file.sha256), got $($identity.sha256)." }
        if (-not $expectedPaths.Add((Convert-ToPortablePath $retainedPath))) { throw "Manifest repeats retained path '$retainedPath'." }
    }

    $actualPaths = @(Get-ChildItem -LiteralPath $loaded.Root -Recurse -File | ForEach-Object {
        $prefix = $loaded.Root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        Convert-ToPortablePath $_.FullName.Substring($prefix.Length)
    })
    foreach ($actualPath in $actualPaths) {
        if (-not $expectedPaths.Contains($actualPath)) { throw "Unexpected file in immutable evidence pack: $actualPath" }
    }
    foreach ($expectedPath in $expectedPaths) {
        if ($actualPaths -notcontains $expectedPath) { throw "Expected evidence-pack file is missing: $expectedPath" }
    }

    [int64]$totalSuites = 0
    [int64]$totalTests = 0
    [int64]$totalFailures = 0
    [int64]$totalErrors = 0
    [int64]$totalSkipped = 0
    foreach ($group in @($loaded.Data.tests.groups)) {
        $reportPaths = @($group.reports | ForEach-Object { Get-RetainedFullPath $loaded.Root ([string]$_) })
        $totals = Get-JUnitTotals ([string[]]$reportPaths)
        foreach ($field in @('suites', 'tests', 'failures', 'errors', 'skipped')) {
            if ([int64]$group.$field -ne [int64]$totals[$field]) { throw "JUnit group '$($group.name)' $field mismatch." }
        }
        $totalSuites += $totals.suites
        $totalTests += $totals.tests
        $totalFailures += $totals.failures
        $totalErrors += $totals.errors
        $totalSkipped += $totals.skipped
    }
    foreach ($field in @('suites', 'tests', 'failures', 'errors', 'skipped')) {
        $actual = Get-Variable -Name ("total" + $field.Substring(0,1).ToUpperInvariant() + $field.Substring(1)) -ValueOnly
        if ([int64]$loaded.Data.tests.$field -ne [int64]$actual) { throw "Overall JUnit $field mismatch." }
    }

    foreach ($jar in @($loaded.Data.jars)) {
        $fullPath = Get-RetainedFullPath $loaded.Root ([string]$jar.retainedPath)
        $inspection = Get-JarInspection $fullPath ([string[]]@($jar.forbiddenPrefixes))
        foreach ($field in @('entries', 'classes', 'resources')) {
            if ([int64]$jar.$field -ne [int64]$inspection[$field]) { throw "JAR $($jar.retainedPath) $field mismatch." }
        }
        $expectedMatches = @($jar.forbiddenMatches | Sort-Object) -join "`n"
        $actualMatches = @($inspection.forbiddenMatches | Sort-Object) -join "`n"
        if ($expectedMatches -ne $actualMatches) { throw "JAR $($jar.retainedPath) forbidden-prefix result mismatch." }
    }

    Write-Output "Evidence pack verified: $($loaded.Data.checkpoint)"
    Write-Output "Manifest SHA-256 $($loaded.Hash)"
    Write-Output "Retained files $($loaded.Data.files.Count); JUnit $totalTests tests across $totalSuites suites"
}

function Invoke-Inspect {
    param([string]$ManifestPath)

    if ([string]::IsNullOrWhiteSpace($ManifestPath)) { throw 'inspect requires -Manifest <path>.' }
    $loaded = Read-ManifestWithIntegrity $ManifestPath
    Write-Output "Checkpoint: $($loaded.Data.checkpoint)"
    Write-Output "Captured UTC: $($loaded.Data.capturedAtUtc)"
    Write-Output "Source commit: $($loaded.Data.source.commit)"
    Write-Output "Source tree: $($loaded.Data.source.tree)"
    Write-Output "Branch: $($loaded.Data.source.branch)"
    Write-Output "Worktree clean: $($loaded.Data.source.worktreeClean)"
    Write-Output "JUnit: $($loaded.Data.tests.tests) tests / $($loaded.Data.tests.suites) suites / $($loaded.Data.tests.failures) failures / $($loaded.Data.tests.errors) errors / $($loaded.Data.tests.skipped) skipped"
    Write-Output "Retained files: $($loaded.Data.files.Count)"
    Write-Output "Manifest SHA-256: $($loaded.Hash)"
}

switch ($Action.ToLowerInvariant()) {
    'capture' {
        if (-not [string]::IsNullOrWhiteSpace($Manifest)) { throw 'capture accepts -Spec, not -Manifest.' }
        Invoke-Capture $Spec
    }
    'verify' {
        if (-not [string]::IsNullOrWhiteSpace($Spec)) { throw 'verify accepts -Manifest, not -Spec.' }
        Invoke-Verify $Manifest
    }
    'inspect' {
        if (-not [string]::IsNullOrWhiteSpace($Spec)) { throw 'inspect accepts -Manifest, not -Spec.' }
        Invoke-Inspect $Manifest
    }
}

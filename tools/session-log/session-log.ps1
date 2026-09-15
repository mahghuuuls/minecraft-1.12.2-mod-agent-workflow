[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('launches', 'records', 'timeline', 'errors', 'find')]
    [string]$Action,

    [string]$Log,

    [string]$LogDirectory,

    [ValidateRange(0, 1000)]
    [int]$Rotated = 2,

    [switch]$AllRotated,

    [string]$Launch,

    [string]$Type,

    [string]$Bundle,

    [string]$From,

    [string]$To,

    [string]$FromTime,

    [string]$ToTime,

    [string]$Occurrence = 'last',

    [string]$Level,

    [string]$Logger,

    [string]$Thread,

    [string]$Text,

    [string]$Pattern,

    [string]$Fields,

    [switch]$RecordsOnly,

    [ValidateRange(0, 1000000)]
    [int]$Limit = 0,

    [switch]$Json
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Windows PowerShell does not always autoload standard modules when the tool is launched
# through the batch wrapper. Utility provides JSON commands; Management provides the
# filesystem commands used to list the log directory.
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

$ToolVersion = '1.0.0'
$CompiledOption = [Text.RegularExpressions.RegexOptions]::Compiled
$LineRegex = New-Object regex('^\[(?<time>\d{2}:\d{2}:\d{2})\] \[(?<thread>.+?)/(?<level>[A-Z]+)\](?: \[(?<logger>[^\]]*)\])?: ?(?<message>.*)$', $CompiledOption)
$RecordRegex = New-Object regex('^\[DevToolkit\]\[(?<type>[A-Za-z0-9_]+)\]\s*(?<fields>.*)$', $CompiledOption)
$FieldRegex = New-Object regex('(?<key>[A-Za-z0-9_]+)=(?:"(?<quoted>(?:[^"\\]|\\.)*)"|(?<bare>\S*))', $CompiledOption)
$TweakRegex = New-Object regex('Loading tweak class name net\.minecraftforge\.fml\.common\.launcher\.FML(?<server>Server)?Tweaker$', $CompiledOption)
$ForgeVersionRegex = New-Object regex('^Forge Mod Loader version (?<forge>\S+) for Minecraft (?<minecraft>\S+) loading', $CompiledOption)
$ModCountRegex = New-Object regex('Forge Mod Loader has identified (?<count>\d+) mods? to load', $CompiledOption)
$TimeRegex = New-Object regex('^\d{2}:\d{2}:\d{2}$', $CompiledOption)
$ImplicitStartKind = 'file start, no launch marker seen'

function Get-LogFiles {
    # Returns the files to read, oldest first: the selected rotated files by date and index,
    # then latest.log. A single -Log wins over a directory.
    if (-not [string]::IsNullOrWhiteSpace($Log)) {
        if (-not [string]::IsNullOrWhiteSpace($LogDirectory)) {
            throw 'Use either -Log <file> or -LogDirectory <directory>, not both.'
        }
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Log)
        if (-not [IO.File]::Exists($resolved)) {
            throw "Log file not found: $resolved"
        }
        return @($resolved)
    }

    $directory = $LogDirectory
    if ([string]::IsNullOrWhiteSpace($directory)) {
        foreach ($candidate in @('run\logs', 'logs')) {
            $probe = Join-Path (Get-Location) $candidate
            if ([IO.Directory]::Exists($probe)) {
                $directory = $probe
                break
            }
        }
        if ([string]::IsNullOrWhiteSpace($directory)) {
            throw 'Provide -Log <file> or -LogDirectory <directory>. No run\logs or logs directory exists under the current location.'
        }
    }

    $resolvedDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($directory)
    if (-not [IO.Directory]::Exists($resolvedDirectory)) {
        throw "Log directory not found: $resolvedDirectory"
    }

    $rotatedFiles = @(Get-ChildItem -LiteralPath $resolvedDirectory -File -Filter '*.log.gz' | ForEach-Object {
        $order = [datetime]::MinValue
        $index = 0
        if ($_.Name -match '^(?<date>\d{4}-\d{2}-\d{2})-(?<index>\d+)\.log\.gz$') {
            $order = [datetime]::ParseExact($Matches.date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
            $index = [int]$Matches.index
        }
        [pscustomobject]@{ Path = $_.FullName; Order = $order; Index = $index; Written = $_.LastWriteTimeUtc }
    } | Sort-Object Order, Index, Written)

    if (-not $AllRotated) {
        if ($Rotated -eq 0) {
            $rotatedFiles = @()
        }
        elseif ($rotatedFiles.Count -gt $Rotated) {
            $rotatedFiles = @($rotatedFiles[($rotatedFiles.Count - $Rotated)..($rotatedFiles.Count - 1)])
        }
    }

    $files = New-Object 'System.Collections.Generic.List[string]'
    foreach ($rotatedFile in $rotatedFiles) {
        $files.Add($rotatedFile.Path)
    }
    $latest = Join-Path $resolvedDirectory 'latest.log'
    if ([IO.File]::Exists($latest)) {
        $files.Add($latest)
    }
    if ($files.Count -eq 0) {
        throw "No latest.log or rotated *.log.gz file found in $resolvedDirectory"
    }
    return $files.ToArray()
}

function Open-LogReader {
    param([string]$Path)

    # ReadWrite sharing lets the tool read latest.log while the game still writes it.
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    if ($Path.EndsWith('.gz', [StringComparison]::OrdinalIgnoreCase)) {
        $stream = New-Object IO.Compression.GZipStream($stream, [IO.Compression.CompressionMode]::Decompress)
    }
    return New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding($false)), $true)
}

function ConvertFrom-RecordMessage {
    param([string]$Message)

    $match = $RecordRegex.Match($Message)
    if (-not $match.Success) {
        return $null
    }

    $fields = [ordered]@{}
    foreach ($fieldMatch in $FieldRegex.Matches($match.Groups['fields'].Value)) {
        $key = $fieldMatch.Groups['key'].Value
        if ($fieldMatch.Groups['quoted'].Success) {
            $value = $fieldMatch.Groups['quoted'].Value.Replace('\"', '"')
        }
        else {
            $value = $fieldMatch.Groups['bare'].Value
        }
        if (-not $fields.Contains($key)) {
            $fields[$key] = $value
        }
    }

    return [pscustomobject]@{
        Type = $match.Groups['type'].Value
        Fields = $fields
    }
}

function New-Launch {
    param([object]$Entry, [string]$Side, [string]$StartKind, [int]$Index)

    return [pscustomobject]@{
        Index = $Index
        File = $Entry.File
        Path = $Entry.Path
        StartLine = $Entry.Line
        StartTime = $Entry.Time
        EndTime = $Entry.Time
        StartKind = $StartKind
        Side = $Side
        ForgeVersion = $null
        MinecraftVersion = $null
        ModCount = $null
        Entries = 0
        NonMainEntries = 0
        Records = 0
        Warnings = 0
        Errors = 0
        Marks = New-Object 'System.Collections.Generic.List[string]'
        Bundles = New-Object 'System.Collections.Generic.List[string]'
        Stopped = $false
        Crashed = $false
        FirstIndex = $Entry.Index
        LastIndex = $Entry.Index
    }
}

function Update-LaunchState {
    param(
        [object]$Entry,
        [System.Collections.Generic.List[object]]$Launches,
        [bool]$FileStart
    )

    $message = $Entry.Message
    $launch = $null
    # Rotation happens when a process starts, so a launch never begins in the middle of a
    # file: the first entry of every file opens a new launch, implicit until a marker names it.
    if ($Launches.Count -gt 0 -and -not $FileStart) {
        $launch = $Launches[$Launches.Count - 1]
    }

    $tweak = $TweakRegex.Match($message)
    if ($tweak.Success) {
        $side = 'client'
        if ($tweak.Groups['server'].Success) {
            $side = 'server'
        }
        # A launch log opens with launcher lines on the main thread (GradleStart, LaunchWrapper)
        # before the tweak class is named. Those lines belong to this launch, so an implicit
        # launch that holds only main-thread entries is adopted instead of left as a stub.
        if ($null -ne $launch -and $launch.StartKind -eq $ImplicitStartKind -and $launch.NonMainEntries -eq 0 -and $null -eq $launch.ForgeVersion) {
            $launch.Side = $side
            $launch.StartKind = 'tweak class'
        }
        else {
            $launch = New-Launch -Entry $Entry -Side $side -StartKind 'tweak class' -Index ($Launches.Count + 1)
            $Launches.Add($launch)
        }
    }
    else {
        $forge = $ForgeVersionRegex.Match($message)
        if ($forge.Success) {
            if ($null -eq $launch -or $null -ne $launch.ForgeVersion) {
                $launch = New-Launch -Entry $Entry -Side 'unknown' -StartKind 'Forge version line' -Index ($Launches.Count + 1)
                $Launches.Add($launch)
            }
            $launch.ForgeVersion = $forge.Groups['forge'].Value
            $launch.MinecraftVersion = $forge.Groups['minecraft'].Value
        }
    }

    if ($null -eq $launch) {
        $launch = New-Launch -Entry $Entry -Side 'unknown' -StartKind $ImplicitStartKind -Index ($Launches.Count + 1)
        $Launches.Add($launch)
    }

    $Entry.Launch = $launch.Index
    $launch.Entries++
    $launch.EndTime = $Entry.Time
    $launch.LastIndex = $Entry.Index
    if ($Entry.Thread -ne 'main') {
        $launch.NonMainEntries++
    }

    if ($launch.Side -eq 'unknown') {
        if ($message.StartsWith('Starting minecraft server version')) {
            $launch.Side = 'server'
        }
        elseif ($Entry.Thread -eq 'Client thread') {
            $launch.Side = 'client'
        }
    }

    $modCount = $ModCountRegex.Match($message)
    if ($modCount.Success) {
        $launch.ModCount = [int]$modCount.Groups['count'].Value
    }
    if ($message -eq 'Stopping server' -or $message -eq 'Stopping!') {
        $launch.Stopped = $true
    }
    if ($message.Contains('Minecraft Crash Report') -or $message.Contains('crash report has been saved')) {
        $launch.Crashed = $true
    }
    if ($Entry.Level -eq 'WARN') {
        $launch.Warnings++
    }
    elseif ($Entry.Level -eq 'ERROR' -or $Entry.Level -eq 'FATAL') {
        $launch.Errors++
    }

    if ($null -ne $Entry.Record) {
        $launch.Records++
        $record = $Entry.Record
        if ($record.Type -eq 'MARK' -and $record.Fields.Contains('label')) {
            $launch.Marks.Add([string]$record.Fields['label'])
        }
        elseif ($record.Type -eq 'BUNDLE_START' -and $record.Fields.Contains('bundle')) {
            $launch.Bundles.Add([string]$record.Fields['bundle'])
        }
    }
}

function Read-LogFile {
    param(
        [string]$Path,
        [System.Collections.Generic.List[object]]$Entries,
        [System.Collections.Generic.List[object]]$Launches
    )

    $fileName = [IO.Path]::GetFileName($Path)
    $firstEntryIndex = $Entries.Count
    $reader = Open-LogReader -Path $Path
    try {
        $lineNumber = 0
        $current = $null
        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line) {
                break
            }
            $lineNumber++

            $match = $LineRegex.Match($line)
            if (-not $match.Success) {
                if ($null -ne $current) {
                    $current.Continuation.Add($line)
                }
                continue
            }

            $logger = ''
            if ($match.Groups['logger'].Success) {
                $logger = $match.Groups['logger'].Value
            }
            $message = $match.Groups['message'].Value
            $record = $null
            if ($message.StartsWith('[DevToolkit][')) {
                $record = ConvertFrom-RecordMessage -Message $message
            }

            $current = [pscustomobject]@{
                Index = $Entries.Count
                File = $fileName
                Path = $Path
                Line = $lineNumber
                Time = $match.Groups['time'].Value
                Thread = $match.Groups['thread'].Value
                Level = $match.Groups['level'].Value
                Logger = $logger
                Message = $message
                Continuation = New-Object 'System.Collections.Generic.List[string]'
                Launch = 0
                Record = $record
            }
            Update-LaunchState -Entry $current -Launches $Launches -FileStart ($Entries.Count -eq $firstEntryIndex)
            $Entries.Add($current)
        }
    }
    finally {
        $reader.Dispose()
    }
}

function Select-Launches {
    param(
        [System.Collections.Generic.List[object]]$Launches,
        [string]$Selector
    )

    if ($Launches.Count -eq 0) {
        throw 'The selected logs contain no log entries.'
    }

    $normalized = $Selector.Trim().ToLowerInvariant()
    switch ($normalized) {
        'all' { return @($Launches.ToArray()) }
        'last' { return @($Launches[$Launches.Count - 1]) }
        'first' { return @($Launches[0]) }
        'client' {
            $matching = @($Launches.ToArray() | Where-Object { $_.Side -eq 'client' })
            if ($matching.Count -eq 0) { throw 'No client launch was found in the selected logs.' }
            return @($matching[$matching.Count - 1])
        }
        'server' {
            $matching = @($Launches.ToArray() | Where-Object { $_.Side -eq 'server' })
            if ($matching.Count -eq 0) { throw 'No server launch was found in the selected logs.' }
            return @($matching[$matching.Count - 1])
        }
    }

    $number = 0
    if ([int]::TryParse($normalized, [ref]$number) -and $number -ge 1 -and $number -le $Launches.Count) {
        return @($Launches[$number - 1])
    }
    throw "-Launch must be last, first, all, client, server, or a launch number from 1 to $($Launches.Count); '$Selector' is not."
}

function Get-LaunchEntries {
    param(
        [System.Collections.Generic.List[object]]$Entries,
        [object]$LaunchRecord
    )

    $selected = New-Object 'System.Collections.Generic.List[object]'
    for ($index = $LaunchRecord.FirstIndex; $index -le $LaunchRecord.LastIndex; $index++) {
        $selected.Add($Entries[$index])
    }
    return $selected
}

function Split-List {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }
    return @($Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

function Test-EntryFilters {
    param([object]$Entry, [string[]]$Levels, [regex]$PatternRegex)

    if ($Levels.Count -gt 0) {
        $levelMatches = $false
        foreach ($wanted in $Levels) {
            if ($Entry.Level -eq $wanted) { $levelMatches = $true; break }
        }
        if (-not $levelMatches) { return $false }
    }
    if (-not [string]::IsNullOrWhiteSpace($Logger) -and $Entry.Logger.IndexOf($Logger, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        return $false
    }
    if (-not [string]::IsNullOrWhiteSpace($Thread) -and $Entry.Thread.IndexOf($Thread, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        return $false
    }
    if (-not [string]::IsNullOrWhiteSpace($Text)) {
        $found = $Entry.Message.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0
        if (-not $found) {
            foreach ($continuation in $Entry.Continuation) {
                if ($continuation.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $found = $true; break }
            }
        }
        if (-not $found) { return $false }
    }
    if ($null -ne $PatternRegex) {
        $found = $PatternRegex.IsMatch($Entry.Message)
        if (-not $found) {
            foreach ($continuation in $Entry.Continuation) {
                if ($PatternRegex.IsMatch($continuation)) { $found = $true; break }
            }
        }
        if (-not $found) { return $false }
    }
    if ($RecordsOnly -and $null -eq $Entry.Record) {
        return $false
    }
    return $true
}

function Format-Entry {
    param([object]$Entry, [switch]$WithContinuation)

    $loggerText = ''
    if ($Entry.Logger.Length -gt 0) {
        $loggerText = " [$($Entry.Logger)]"
    }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add("[$($Entry.File):$($Entry.Line)] [$($Entry.Time)] [$($Entry.Thread)/$($Entry.Level)]${loggerText}: $($Entry.Message)")
    if ($WithContinuation) {
        foreach ($continuation in $Entry.Continuation) {
            $lines.Add("    $continuation")
        }
    }
    return $lines.ToArray()
}

function ConvertTo-EntryObject {
    param([object]$Entry)

    $object = [ordered]@{
        launch = $Entry.Launch
        file = $Entry.File
        line = $Entry.Line
        time = $Entry.Time
        thread = $Entry.Thread
        level = $Entry.Level
        logger = $Entry.Logger
        message = $Entry.Message
        continuation = @($Entry.Continuation.ToArray())
    }
    if ($null -ne $Entry.Record) {
        $object['record'] = [ordered]@{
            type = $Entry.Record.Type
            fields = $Entry.Record.Fields
        }
    }
    return $object
}

function ConvertTo-LaunchObject {
    param([object]$LaunchRecord)

    return [ordered]@{
        index = $LaunchRecord.Index
        side = $LaunchRecord.Side
        file = $LaunchRecord.File
        startLine = $LaunchRecord.StartLine
        startTime = $LaunchRecord.StartTime
        endTime = $LaunchRecord.EndTime
        startKind = $LaunchRecord.StartKind
        forgeVersion = $LaunchRecord.ForgeVersion
        minecraftVersion = $LaunchRecord.MinecraftVersion
        modCount = $LaunchRecord.ModCount
        entries = $LaunchRecord.Entries
        records = $LaunchRecord.Records
        warnings = $LaunchRecord.Warnings
        errors = $LaunchRecord.Errors
        marks = @($LaunchRecord.Marks.ToArray())
        bundles = @($LaunchRecord.Bundles.ToArray())
        stopped = $LaunchRecord.Stopped
        crashed = $LaunchRecord.Crashed
    }
}

function Write-LaunchSummary {
    param([object]$LaunchRecord)

    $forgeText = 'Forge version not seen'
    if ($null -ne $LaunchRecord.ForgeVersion) {
        $forgeText = "Forge $($LaunchRecord.ForgeVersion)"
    }
    $modText = 'mod count not seen'
    if ($null -ne $LaunchRecord.ModCount) {
        $modText = "$($LaunchRecord.ModCount) mods"
    }
    $endText = 'no stop line (still running, killed, or the log was rotated away)'
    if ($LaunchRecord.Crashed) {
        $endText = 'crashed'
    }
    elseif ($LaunchRecord.Stopped) {
        $endText = 'stopped'
    }

    Write-Output "Launch $($LaunchRecord.Index): $($LaunchRecord.Side), $($LaunchRecord.File) line $($LaunchRecord.StartLine), $($LaunchRecord.StartTime) to $($LaunchRecord.EndTime), $forgeText, $modText, $endText (start: $($LaunchRecord.StartKind))"
    Write-Output "  entries $($LaunchRecord.Entries), toolkit records $($LaunchRecord.Records), warnings $($LaunchRecord.Warnings), errors $($LaunchRecord.Errors)"
    if ($LaunchRecord.Marks.Count -gt 0) {
        Write-Output "  marks: $($LaunchRecord.Marks -join ', ')"
    }
    if ($LaunchRecord.Bundles.Count -gt 0) {
        Write-Output "  bundles started: $($LaunchRecord.Bundles -join ', ')"
    }
}

function Select-Occurrence {
    param([object[]]$Candidates, [string]$Which, [string]$Label)

    if ($Candidates.Count -eq 0) {
        throw "No $Label was found in the selected launch."
    }
    $normalized = $Which.Trim().ToLowerInvariant()
    if ($normalized -eq 'last') {
        return $Candidates[$Candidates.Count - 1]
    }
    if ($normalized -eq 'first') {
        return $Candidates[0]
    }
    $number = 0
    if ([int]::TryParse($normalized, [ref]$number) -and $number -ge 1 -and $number -le $Candidates.Count) {
        return $Candidates[$number - 1]
    }
    throw "-Occurrence must be first, last, or a number from 1 to $($Candidates.Count) for $Label; '$Which' is not."
}

function Get-TimelineSlice {
    # Returns the entries of one launch between the requested boundaries, plus a description.
    param(
        [System.Collections.Generic.List[object]]$LaunchEntries,
        [object]$LaunchRecord
    )

    $startPosition = 0
    $endPosition = $LaunchEntries.Count - 1
    $description = 'whole launch'
    $boundaryKinds = 0
    if (-not [string]::IsNullOrWhiteSpace($Bundle)) { $boundaryKinds++ }
    if (-not [string]::IsNullOrWhiteSpace($From) -or -not [string]::IsNullOrWhiteSpace($To)) { $boundaryKinds++ }
    if (-not [string]::IsNullOrWhiteSpace($FromTime) -or -not [string]::IsNullOrWhiteSpace($ToTime)) { $boundaryKinds++ }
    if ($boundaryKinds -gt 1) {
        throw 'Choose one boundary kind: -Bundle, -From/-To mark labels, or -FromTime/-ToTime.'
    }

    if (-not [string]::IsNullOrWhiteSpace($Bundle)) {
        $starts = New-Object 'System.Collections.Generic.List[int]'
        for ($position = 0; $position -lt $LaunchEntries.Count; $position++) {
            $record = $LaunchEntries[$position].Record
            if ($null -ne $record -and $record.Type -eq 'BUNDLE_START' -and $record.Fields.Contains('bundle') -and $record.Fields['bundle'] -eq $Bundle) {
                $starts.Add($position)
            }
        }
        $startPosition = Select-Occurrence -Candidates @($starts.ToArray()) -Which $Occurrence -Label "BUNDLE_START of '$Bundle'"
        $endPosition = $LaunchEntries.Count - 1
        $endFound = $false
        for ($position = $startPosition + 1; $position -lt $LaunchEntries.Count; $position++) {
            $record = $LaunchEntries[$position].Record
            if ($null -ne $record -and $record.Type -eq 'BUNDLE_END' -and $record.Fields.Contains('bundle') -and $record.Fields['bundle'] -eq $Bundle) {
                $endPosition = $position
                $endFound = $true
                break
            }
        }
        $endText = 'end of launch (no BUNDLE_END found)'
        if ($endFound) {
            $endText = "BUNDLE_END at line $($LaunchEntries[$endPosition].Line), $($LaunchEntries[$endPosition].Time)"
        }
        $description = "bundle '$Bundle' occurrence $Occurrence of $($starts.Count): BUNDLE_START at line $($LaunchEntries[$startPosition].Line), $($LaunchEntries[$startPosition].Time), to $endText"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($From) -or -not [string]::IsNullOrWhiteSpace($To)) {
        if ([string]::IsNullOrWhiteSpace($From)) {
            throw '-To needs -From <mark label>.'
        }
        $marks = New-Object 'System.Collections.Generic.List[int]'
        for ($position = 0; $position -lt $LaunchEntries.Count; $position++) {
            $record = $LaunchEntries[$position].Record
            if ($null -ne $record -and $record.Type -eq 'MARK' -and $record.Fields.Contains('label') -and $record.Fields['label'] -eq $From) {
                $marks.Add($position)
            }
        }
        $startPosition = Select-Occurrence -Candidates @($marks.ToArray()) -Which $Occurrence -Label "MARK '$From'"
        $endPosition = $LaunchEntries.Count - 1
        $endText = 'end of launch'
        if (-not [string]::IsNullOrWhiteSpace($To)) {
            $endText = "end of launch (no MARK '$To' after it)"
            for ($position = $startPosition + 1; $position -lt $LaunchEntries.Count; $position++) {
                $record = $LaunchEntries[$position].Record
                if ($null -ne $record -and $record.Type -eq 'MARK' -and $record.Fields.Contains('label') -and $record.Fields['label'] -eq $To) {
                    $endPosition = $position
                    $endText = "MARK '$To' at line $($LaunchEntries[$position].Line), $($LaunchEntries[$position].Time)"
                    break
                }
            }
        }
        $description = "MARK '$From' occurrence $Occurrence of $($marks.Count) at line $($LaunchEntries[$startPosition].Line), $($LaunchEntries[$startPosition].Time), to $endText"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($FromTime) -or -not [string]::IsNullOrWhiteSpace($ToTime)) {
        foreach ($boundary in @($FromTime, $ToTime)) {
            if (-not [string]::IsNullOrWhiteSpace($boundary) -and -not $TimeRegex.IsMatch($boundary)) {
                throw "-FromTime and -ToTime use HH:mm:ss, not '$boundary'."
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($FromTime)) {
            $startPosition = $LaunchEntries.Count
            for ($position = 0; $position -lt $LaunchEntries.Count; $position++) {
                if ([string]::CompareOrdinal($LaunchEntries[$position].Time, $FromTime) -ge 0) { $startPosition = $position; break }
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($ToTime)) {
            $endPosition = -1
            for ($position = $LaunchEntries.Count - 1; $position -ge 0; $position--) {
                if ([string]::CompareOrdinal($LaunchEntries[$position].Time, $ToTime) -le 0) { $endPosition = $position; break }
            }
        }
        $description = "time $FromTime to $ToTime"
    }

    $slice = New-Object 'System.Collections.Generic.List[object]'
    for ($position = $startPosition; $position -le $endPosition -and $position -lt $LaunchEntries.Count; $position++) {
        $slice.Add($LaunchEntries[$position])
    }
    return [pscustomobject]@{
        Entries = $slice
        Description = $description
    }
}

function Write-EntryList {
    param(
        [System.Collections.Generic.List[object]]$Selected,
        [switch]$WithContinuation
    )

    $shown = 0
    foreach ($entry in $Selected) {
        if ($Limit -gt 0 -and $shown -ge $Limit) {
            Write-Output "... $($Selected.Count - $shown) more entries not shown (raise or remove -Limit)"
            break
        }
        foreach ($line in (Format-Entry -Entry $entry -WithContinuation:$WithContinuation)) {
            Write-Output $line
        }
        $shown++
    }
}

function Write-JsonOutput {
    param([object]$Value)

    Write-Output (ConvertTo-Json -InputObject $Value -Depth 8)
}

$launchSelector = $Launch
if ([string]::IsNullOrWhiteSpace($launchSelector)) {
    $launchSelector = 'last'
    if ($Action -eq 'find' -or $Action -eq 'launches') {
        $launchSelector = 'all'
    }
}

$patternRegex = $null
if (-not [string]::IsNullOrWhiteSpace($Pattern)) {
    $patternRegex = New-Object regex($Pattern, ([Text.RegularExpressions.RegexOptions]::IgnoreCase))
}
$levelFilter = @(Split-List -Value $Level | ForEach-Object { $_.ToUpperInvariant() })
$typeFilter = @(Split-List -Value $Type | ForEach-Object { $_.ToUpperInvariant() })
$fieldFilter = @(Split-List -Value $Fields)

$files = @(Get-LogFiles)
$entries = New-Object 'System.Collections.Generic.List[object]'
$launches = New-Object 'System.Collections.Generic.List[object]'
foreach ($file in $files) {
    Read-LogFile -Path $file -Entries $entries -Launches $launches
}

if ($launches.Count -eq 0) {
    throw "No log entries with the [HH:mm:ss] [thread/LEVEL] prefix were found in: $($files -join ', ')"
}

switch ($Action) {
    'launches' {
        $selectedLaunches = @(Select-Launches -Launches $launches -Selector $launchSelector)
        if ($Json) {
            Write-JsonOutput -Value @($selectedLaunches | ForEach-Object { ConvertTo-LaunchObject -LaunchRecord $_ })
            break
        }
        Write-Output "Files read (oldest first): $(@($files | ForEach-Object { [IO.Path]::GetFileName($_) }) -join ', ')"
        Write-Output "Launches found: $($launches.Count)"
        foreach ($launchRecord in $selectedLaunches) {
            Write-LaunchSummary -LaunchRecord $launchRecord
        }
    }
    'records' {
        $selectedLaunches = @(Select-Launches -Launches $launches -Selector $launchSelector)
        $results = New-Object 'System.Collections.Generic.List[object]'
        $descriptions = New-Object 'System.Collections.Generic.List[string]'
        foreach ($launchRecord in $selectedLaunches) {
            $launchEntries = Get-LaunchEntries -Entries $entries -LaunchRecord $launchRecord
            $slice = Get-TimelineSlice -LaunchEntries $launchEntries -LaunchRecord $launchRecord
            $descriptions.Add("launch $($launchRecord.Index) ($($launchRecord.Side), $($launchRecord.File)): $($slice.Description)")
            foreach ($entry in $slice.Entries) {
                $record = $entry.Record
                if ($null -eq $record) { continue }
                if ($typeFilter.Count -gt 0 -and $typeFilter -notcontains $record.Type.ToUpperInvariant()) { continue }
                if (-not (Test-EntryFilters -Entry $entry -Levels $levelFilter -PatternRegex $patternRegex)) { continue }
                $results.Add($entry)
            }
        }
        if ($Json) {
            Write-JsonOutput -Value @($results | ForEach-Object { ConvertTo-EntryObject -Entry $_ })
            break
        }
        foreach ($description in $descriptions) {
            Write-Output "Scope: $description"
        }
        Write-Output "Toolkit records selected: $($results.Count)"
        $shown = 0
        foreach ($entry in $results) {
            if ($Limit -gt 0 -and $shown -ge $Limit) {
                Write-Output "... $($results.Count - $shown) more records not shown (raise or remove -Limit)"
                break
            }
            $record = $entry.Record
            if ($fieldFilter.Count -gt 0) {
                $parts = New-Object 'System.Collections.Generic.List[string]'
                foreach ($field in $fieldFilter) {
                    $value = '(absent)'
                    if ($record.Fields.Contains($field)) { $value = $record.Fields[$field] }
                    $parts.Add("$field=$value")
                }
                Write-Output "[$($entry.File):$($entry.Line)] [$($entry.Time)] $($record.Type) $($parts -join ' ')"
            }
            else {
                $parts = New-Object 'System.Collections.Generic.List[string]'
                foreach ($key in $record.Fields.Keys) {
                    $value = [string]$record.Fields[$key]
                    if ($value.IndexOf(' ') -ge 0 -or $value.Length -eq 0) { $value = '"' + $value + '"' }
                    $parts.Add("$key=$value")
                }
                Write-Output "[$($entry.File):$($entry.Line)] [$($entry.Time)] $($record.Type) $($parts -join ' ')"
            }
            $shown++
        }
    }
    'timeline' {
        $selectedLaunches = @(Select-Launches -Launches $launches -Selector $launchSelector)
        $results = New-Object 'System.Collections.Generic.List[object]'
        $descriptions = New-Object 'System.Collections.Generic.List[string]'
        foreach ($launchRecord in $selectedLaunches) {
            $launchEntries = Get-LaunchEntries -Entries $entries -LaunchRecord $launchRecord
            $slice = Get-TimelineSlice -LaunchEntries $launchEntries -LaunchRecord $launchRecord
            $kept = 0
            foreach ($entry in $slice.Entries) {
                if (-not (Test-EntryFilters -Entry $entry -Levels $levelFilter -PatternRegex $patternRegex)) { continue }
                if ($typeFilter.Count -gt 0 -and ($null -eq $entry.Record -or $typeFilter -notcontains $entry.Record.Type.ToUpperInvariant())) { continue }
                $results.Add($entry)
                $kept++
            }
            $descriptions.Add("launch $($launchRecord.Index) ($($launchRecord.Side), $($launchRecord.File)): $($slice.Description); $($slice.Entries.Count) entries in the slice, $kept after filters")
        }
        if ($Json) {
            Write-JsonOutput -Value @($results | ForEach-Object { ConvertTo-EntryObject -Entry $_ })
            break
        }
        foreach ($description in $descriptions) {
            Write-Output "Scope: $description"
        }
        Write-EntryList -Selected $results -WithContinuation
    }
    'errors' {
        $selectedLaunches = @(Select-Launches -Launches $launches -Selector $launchSelector)
        $wantedLevels = $levelFilter
        if ($wantedLevels.Count -eq 0) {
            $wantedLevels = @('WARN', 'ERROR', 'FATAL')
        }
        $results = New-Object 'System.Collections.Generic.List[object]'
        foreach ($launchRecord in $selectedLaunches) {
            $launchEntries = Get-LaunchEntries -Entries $entries -LaunchRecord $launchRecord
            $slice = Get-TimelineSlice -LaunchEntries $launchEntries -LaunchRecord $launchRecord
            foreach ($entry in $slice.Entries) {
                $isProblem = $wantedLevels -contains $entry.Level
                if (-not $isProblem -and $null -ne $entry.Record -and $entry.Record.Type -eq 'ERROR' -and $levelFilter.Count -eq 0) {
                    $isProblem = $true
                }
                if (-not $isProblem) { continue }
                if (-not (Test-EntryFilters -Entry $entry -Levels @() -PatternRegex $patternRegex)) { continue }
                $results.Add($entry)
            }
        }
        if ($Json) {
            Write-JsonOutput -Value @($results | ForEach-Object { ConvertTo-EntryObject -Entry $_ })
            break
        }
        Write-Output "Launches: $(@($selectedLaunches | ForEach-Object { $_.Index }) -join ', '); levels $($wantedLevels -join ', ') plus toolkit ERROR records"
        Write-Output "Problem entries: $($results.Count)"
        $byLogger = @{}
        foreach ($entry in $results) {
            $key = $entry.Logger
            if ($key.Length -eq 0) { $key = '(no logger)' }
            if ($byLogger.ContainsKey($key)) { $byLogger[$key]++ } else { $byLogger[$key] = 1 }
        }
        foreach ($key in ($byLogger.Keys | Sort-Object)) {
            Write-Output "  $key`: $($byLogger[$key])"
        }
        Write-EntryList -Selected $results -WithContinuation
    }
    'find' {
        if ([string]::IsNullOrWhiteSpace($Text) -and $null -eq $patternRegex) {
            throw 'find needs -Text <substring> or -Pattern <regex>.'
        }
        $selectedLaunches = @(Select-Launches -Launches $launches -Selector $launchSelector)
        $results = New-Object 'System.Collections.Generic.List[object]'
        foreach ($launchRecord in $selectedLaunches) {
            $launchEntries = Get-LaunchEntries -Entries $entries -LaunchRecord $launchRecord
            $slice = Get-TimelineSlice -LaunchEntries $launchEntries -LaunchRecord $launchRecord
            foreach ($entry in $slice.Entries) {
                if (-not (Test-EntryFilters -Entry $entry -Levels $levelFilter -PatternRegex $patternRegex)) { continue }
                $results.Add($entry)
            }
        }
        if ($Json) {
            Write-JsonOutput -Value @($results | ForEach-Object { ConvertTo-EntryObject -Entry $_ })
            break
        }
        Write-Output "Launches searched: $(@($selectedLaunches | ForEach-Object { $_.Index }) -join ', ')"
        Write-Output "Matching entries: $($results.Count)"
        Write-EntryList -Selected $results -WithContinuation
    }
}

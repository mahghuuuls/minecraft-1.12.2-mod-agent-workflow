[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('snapshot', 'lock', 'plan', 'apply')]
    [string]$Action,

    # The test instance folder (the one holding mods, config, saves, options.txt).
    [Parameter(Mandatory = $true)]
    [string]$Instance,

    # The session's staging folder; the snapshot goes to <Staging>\instance-snapshot.
    [Parameter(Mandatory = $true)]
    [string]$Staging,

    # snapshot: a text file with the expected mods list, one "file-name size" per line (the
    # owner-defaults baseline). Lines that do not end in a number are ignored.
    [string]$BaselineMods,

    # snapshot: take the snapshot without a baseline list (the output says so).
    [switch]$NoBaseline,

    # lock: the lock note the session writes into mods\.agent-lock.
    [string]$Note,

    # lock: replace this session's lock note with -Note (after adding files).
    [switch]$Update,

    # plan: where to write the plan (default <Staging>\reset-plan.json). apply: the reviewed plan.
    [string]$Plan,

    # plan: new top-level entries to leave in place (comma-separated), besides logs and crash-reports.
    [string]$Keep,

    # plan: a folder outside the instance that already holds a copy of every new screenshot.
    [string]$ScreenshotsCopiedTo,

    # apply: leave mods\.agent-lock in place after the reset.
    [switch]$KeepLock
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

$ToolVersion = '1.0.0'
$Utf8 = New-Object Text.UTF8Encoding($false)
# Top-level entries a launch writes every time; never deleted, never restored.
$LaunchNoise = @('logs', 'crash-reports')
# Top-level files the launcher or the game rewrites; changes are reported, never deleted or restored.
$ReportOnly = @('minecraftinstance.json', 'usercache.json', 'usernamecache.json', 'servers.dat', 'modlist.html')
# Existing top-level folders whose files are compared, so session files inside them are found.
$WatchedFolders = @('screenshots', 'scripts')
# Folders under the instance the tool never touches.
$Untouchable = @('mods\1.12.2', 'logs', 'crash-reports')

function Fail { param([string]$Message) [Console]::Error.WriteLine("instance-reset: $Message"); exit 2 }
function Say { param([string]$Message) Write-Output $Message }
function Get-Full { param([string]$Path) return [IO.Path]::GetFullPath($Path).TrimEnd('\') }
function Read-Utf8 { param([string]$Path) return [IO.File]::ReadAllText($Path, $Utf8) }

$InstanceRoot = Get-Full $Instance
if ($InstanceRoot -match '^[A-Za-z]:$' -or $InstanceRoot -eq '') { Fail "Refusing a drive root as the instance: $Instance" }
if (-not (Test-Path -LiteralPath $InstanceRoot -PathType Container)) { Fail "Instance folder not found: $InstanceRoot" }
if (-not (Test-Path -LiteralPath (Join-Path $InstanceRoot 'mods') -PathType Container)) { Fail "Not an instance (no mods folder): $InstanceRoot" }
$StagingRoot = Get-Full $Staging
if ($StagingRoot -ieq $InstanceRoot -or $StagingRoot.StartsWith($InstanceRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { Fail 'The staging folder must be outside the instance.' }
$SnapshotRoot = Join-Path $StagingRoot 'instance-snapshot'
$ManifestPath = Join-Path $SnapshotRoot 'snapshot.json'
$LockPath = Join-Path $InstanceRoot 'mods\.agent-lock'
$LockCopy = Join-Path $StagingRoot 'agent-lock.txt'
if ($ScreenshotsCopiedTo) {
    $ScreenshotsCopiedTo = Get-Full $ScreenshotsCopiedTo
    if ($ScreenshotsCopiedTo -ieq $InstanceRoot -or $ScreenshotsCopiedTo.StartsWith($InstanceRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { Fail '-ScreenshotsCopiedTo must be outside the instance.' }
}

function Get-Hash { param([string]$Path) return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-Relative { param([string]$Base, [string]$Path) return $Path.Substring($Base.Length).TrimStart('\') }

function Get-FileTable { param([string]$Folder)
    # relative path -> "size sha256" for every file under a folder (empty table when absent).
    $table = @{}
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { return $table }
    $base = Get-Full $Folder
    foreach ($file in Get-ChildItem -LiteralPath $base -Recurse -File -Force) {
        $table[(Get-Relative $base $file.FullName)] = "$($file.Length) $(Get-Hash $file.FullName)"
    }
    return $table
}

function Get-Fingerprint { param([string]$Path)
    # What a planned action found at its target: a file's size and hash, a folder's file list.
    if (Test-Path -LiteralPath $Path -PathType Leaf) { $f = Get-Item -LiteralPath $Path -Force; return "file $($f.Length) $(Get-Hash $f.FullName)" }
    if (Test-Path -LiteralPath $Path -PathType Container) {
        $t = Get-FileTable $Path
        return 'folder ' + ((@($t.Keys | Sort-Object | ForEach-Object { "$_=$($t[$_])" })) -join ';')
    }
    return 'absent'
}

function Get-ModTable {
    # Top-level files of mods (the lock note aside); subfolders are libraries and are listed by name.
    $table = @{}
    foreach ($item in Get-ChildItem -LiteralPath (Join-Path $InstanceRoot 'mods') -Force) {
        if ($item.Name -eq '.agent-lock') { continue }
        if ($item.PSIsContainer) { $table[$item.Name + '\'] = 'folder' } else { $table[$item.Name] = "$($item.Length) $(Get-Hash $item.FullName)" }
    }
    return $table
}

function Get-Names { param([string]$Folder)
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $Folder -Force | ForEach-Object { $_.Name } | Sort-Object)
}

function Get-OptionalHash { param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return Get-Hash $Path } else { return '' }
}

function Get-WorldTable {
    # world name -> hash of its level.dat, to see whether a world that existed was opened.
    $table = @{}
    foreach ($name in Get-Names (Join-Path $InstanceRoot 'saves')) { $table[$name] = Get-OptionalHash (Join-Path $InstanceRoot "saves\$name\level.dat") }
    return $table
}

function Get-GameProcesses {
    # Java processes whose command line names this instance (Cleanroom and Forge pass --gameDir).
    $needle1 = $InstanceRoot.ToLowerInvariant()
    $needle2 = $needle1.Replace('\', '/')
    try { $processes = @(Get-CimInstance Win32_Process -Filter "Name='java.exe' OR Name='javaw.exe'" -ErrorAction Stop) }
    catch { Fail "Cannot read the process list ($($_.Exception.Message)); check for a running game by hand." }
    $found = @()
    foreach ($p in $processes) {
        $line = [string]$p.CommandLine
        if ($line -and ($line.ToLowerInvariant().Contains($needle1) -or $line.ToLowerInvariant().Contains($needle2))) { $found += $p.ProcessId }
    }
    return $found
}

function Assert-NoGame {
    $ids = @(Get-GameProcesses)
    if ($ids.Count -gt 0) { Fail "A game of this instance is running (process $($ids -join ', ')). Close it first." }
}

function Read-Manifest {
    if (-not (Test-Path -LiteralPath $ManifestPath)) { Fail "No snapshot at $ManifestPath; run snapshot first." }
    return (Read-Utf8 $ManifestPath | ConvertFrom-Json)
}

function ConvertTo-Table { param($Object)
    $table = @{}
    if ($null -eq $Object) { return $table }
    foreach ($p in $Object.PSObject.Properties) { $table[$p.Name] = [string]$p.Value }
    return $table
}

function Test-Inside { param([string]$Path)
    # True when Path is strictly inside the instance and outside every untouchable folder.
    $full = Get-Full $Path
    if (-not $full.StartsWith($InstanceRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { return $false }
    foreach ($u in $Untouchable) {
        $guard = Join-Path $InstanceRoot $u
        if ($full -ieq $guard -or $full.StartsWith($guard + '\', [StringComparison]::OrdinalIgnoreCase)) { return $false }
    }
    return $true
}

function Get-LockState {
    # 'none', 'ours' (equal to this session's staged copy), 'missing' (taken, now gone), or 'foreign'.
    if (-not (Test-Path -LiteralPath $LockPath)) { if (Test-Path -LiteralPath $LockCopy) { return 'missing' } else { return 'none' } }
    if ((Test-Path -LiteralPath $LockCopy) -and ((Get-Hash $LockPath) -eq (Get-Hash $LockCopy))) { return 'ours' }
    return 'foreign'
}

# ------------------------------------------------------------------ snapshot

function Invoke-Snapshot {
    if (Test-Path -LiteralPath $LockPath) { Fail "mods\.agent-lock exists; another session holds the instance:`n$(Read-Utf8 $LockPath)" }
    if (-not $BaselineMods -and -not $NoBaseline) { Fail 'snapshot needs -BaselineMods <file> (the recorded baseline mod list), or -NoBaseline to skip that check on purpose.' }
    Assert-NoGame
    if (Test-Path -LiteralPath $SnapshotRoot) { Fail "A snapshot already exists at $SnapshotRoot; use a new staging folder for a new session." }
    $mods = Get-ModTable
    if ($BaselineMods) {
        $expected = @{}
        foreach ($line in (Read-Utf8 (Get-Full $BaselineMods)).Split("`n")) {
            $m = [regex]::Match($line.Trim(), '^(?<name>.+\S)\s+(?<size>\d+)$')
            if ($m.Success) { $expected[$m.Groups['name'].Value] = [long]$m.Groups['size'].Value }
        }
        if ($expected.Count -eq 0) { Fail "No 'file-name size' line in $BaselineMods" }
        $diff = @()
        foreach ($name in $expected.Keys) {
            if (-not $mods.ContainsKey($name)) { $diff += "missing: $name" }
            elseif ([long]($mods[$name].Split(' ')[0]) -ne $expected[$name]) { $diff += "size differs: $name" }
        }
        foreach ($name in $mods.Keys) { if (-not $name.EndsWith('\') -and -not $expected.ContainsKey($name)) { $diff += "extra: $name" } }
        if ($diff.Count -gt 0) { Fail ("The mods folder differs from the baseline list:`n  " + (($diff | Sort-Object) -join "`n  ")) }
    }
    New-Item -ItemType Directory -Path $SnapshotRoot -Force | Out-Null
    $configSource = Join-Path $InstanceRoot 'config'
    $configCopy = Join-Path $SnapshotRoot 'config'
    if (Test-Path -LiteralPath $configSource) { Copy-Item -LiteralPath $configSource -Destination $configCopy -Recurse -Force }
    foreach ($f in @('options.txt', 'knownkeys.txt') + $ReportOnly) {
        $src = Join-Path $InstanceRoot $f
        if (Test-Path -LiteralPath $src -PathType Leaf) { Copy-Item -LiteralPath $src -Destination (Join-Path $SnapshotRoot $f) -Force }
    }
    $watchedTables = [ordered]@{}
    foreach ($w in $WatchedFolders) { $p = Join-Path $InstanceRoot $w; if (Test-Path -LiteralPath $p -PathType Container) { $watchedTables[$w] = Get-FileTable $p } }
    $configDirs = @()
    if (Test-Path -LiteralPath $configCopy) { $configDirs = @(Get-ChildItem -LiteralPath $configCopy -Recurse -Directory -Force | ForEach-Object { Get-Relative (Get-Full $configCopy) $_.FullName }) }
    $baselineText = 'not checked (-NoBaseline)'
    if ($BaselineMods) { $baselineText = "checked against $(Get-Full $BaselineMods)" }
    $manifest = [ordered]@{
        tool = "instance-reset $ToolVersion"
        instance = $InstanceRoot
        takenAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
        baseline = $baselineText
        root = @(Get-Names $InstanceRoot)
        saves = Get-WorldTable
        mods = $mods
        config = Get-FileTable $configCopy
        configDirs = $configDirs
        watched = $watchedTables
        options = Get-OptionalHash (Join-Path $InstanceRoot 'options.txt')
        knownkeys = Get-OptionalHash (Join-Path $InstanceRoot 'knownkeys.txt')
        reportOnly = [ordered]@{}
    }
    foreach ($f in $ReportOnly) { $manifest.reportOnly[$f] = Get-OptionalHash (Join-Path $InstanceRoot $f) }
    [IO.File]::WriteAllText($ManifestPath, ($manifest | ConvertTo-Json -Depth 6), $Utf8)
    Say "Snapshot of $InstanceRoot written to $SnapshotRoot"
    Say "  baseline: $baselineText"
    Say "  mods entries: $($mods.Count); config files: $($manifest.config.Count); root entries: $($manifest.root.Count); worlds: $($manifest.saves.Count)"
}

# ------------------------------------------------------------------ plan

function Add-Action { param($List, [string]$Kind, [string]$Rel, [string]$Reason)
    [void]$List.Add([ordered]@{ action = $Kind; path = $Rel; reason = $Reason; found = (Get-Fingerprint (Join-Path $InstanceRoot $Rel)) })
}

function Get-PlanData {
    $s = Read-Manifest
    $actions = New-Object System.Collections.ArrayList
    $problems = New-Object System.Collections.ArrayList
    $notes = New-Object System.Collections.ArrayList
    $keepNames = @($LaunchNoise)
    if ($Keep) { $keepNames += @($Keep.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

    switch (Get-LockState) {
        'foreign' { [void]$problems.Add('mods\.agent-lock is not this session''s note (it differs from agent-lock.txt); another session may hold the instance. Stop and ask the owner.') }
        'missing' { [void]$problems.Add('mods\.agent-lock is gone although this session took it; someone else may have used the instance. Stop and ask the owner.') }
    }

    # mods
    $then = ConvertTo-Table $s.mods
    $now = Get-ModTable
    foreach ($name in ($now.Keys | Sort-Object)) {
        if (-not $then.ContainsKey($name)) {
            if ($name.EndsWith('\')) { [void]$problems.Add("mods\$name is a new folder; the tool does not delete folders in mods") }
            else { Add-Action $actions 'delete' "mods\$name" 'added to mods' }
        } elseif ($now[$name] -ne $then[$name]) { [void]$problems.Add("mods\$name changed since the snapshot; restore the baseline jar by hand") }
    }
    foreach ($name in ($then.Keys | Sort-Object)) { if (-not $now.ContainsKey($name)) { [void]$problems.Add("mods\$name is missing; restore the baseline jar by hand") } }

    # config: files first, then new folders deepest first (each removed only when empty, never as a whole)
    $then = ConvertTo-Table $s.config
    $configNow = Join-Path $InstanceRoot 'config'
    $now = Get-FileTable $configNow
    foreach ($rel in ($now.Keys | Sort-Object)) {
        if (-not $then.ContainsKey($rel)) { Add-Action $actions 'delete' "config\$rel" 'new under config' }
        elseif ($now[$rel] -ne $then[$rel]) { Add-Action $actions 'restore' "config\$rel" 'changed under config' }
    }
    foreach ($rel in ($then.Keys | Sort-Object)) { if (-not $now.ContainsKey($rel)) { Add-Action $actions 'restore' "config\$rel" 'deleted under config' } }
    $dirsThen = @($s.configDirs | Where-Object { $_ })
    if (Test-Path -LiteralPath $configNow) {
        foreach ($dir in Get-ChildItem -LiteralPath $configNow -Recurse -Directory -Force | Sort-Object { $_.FullName.Length } -Descending) {
            $rel = Get-Relative (Get-Full $configNow) $dir.FullName
            if ($dirsThen -notcontains $rel) { [void]$actions.Add([ordered]@{ action = 'delete-empty-folder'; path = "config\$rel"; reason = 'new folder under config'; found = 'folder' }) }
        }
    }
    foreach ($rel in $dirsThen) {
        if (-not (Test-Path -LiteralPath (Join-Path $configNow $rel))) { [void]$actions.Add([ordered]@{ action = 'make-folder'; path = "config\$rel"; reason = 'folder deleted under config'; found = 'absent' }) }
    }

    # options and keys
    foreach ($pair in @(@('options.txt', $s.options), @('knownkeys.txt', $s.knownkeys))) {
        $nowHash = Get-OptionalHash (Join-Path $InstanceRoot $pair[0])
        if ($pair[1] -and $nowHash -ne $pair[1]) { Add-Action $actions 'restore' $pair[0] 'changed' }
        elseif (-not $pair[1] -and $nowHash) { Add-Action $actions 'delete' $pair[0] 'new' }
    }

    # saves
    $worldsThen = ConvertTo-Table $s.saves
    $worldsNow = Get-WorldTable
    foreach ($name in ($worldsNow.Keys | Sort-Object)) {
        if (-not $worldsThen.ContainsKey($name)) { Add-Action $actions 'delete' "saves\$name" 'new world' }
        elseif ($worldsNow[$name] -ne $worldsThen[$name]) { [void]$notes.Add("saves\$name existed and was opened (its level.dat changed); worlds are not restored") }
    }
    foreach ($name in $worldsThen.Keys) { if (-not $worldsNow.ContainsKey($name)) { [void]$problems.Add("saves\$name is missing; the tool does not keep worlds") } }

    # watched folders that existed: the files inside them
    $watchedThen = $s.watched
    foreach ($w in $WatchedFolders) {
        if ($null -eq $watchedThen -or $null -eq $watchedThen.PSObject.Properties[$w]) { continue }
        $thenFiles = ConvertTo-Table $watchedThen.$w
        $nowFiles = Get-FileTable (Join-Path $InstanceRoot $w)
        foreach ($rel in ($nowFiles.Keys | Sort-Object)) {
            if (-not $thenFiles.ContainsKey($rel)) { Add-Action $actions 'delete' "$w\$rel" "new in $w" }
            elseif ($nowFiles[$rel] -ne $thenFiles[$rel]) { [void]$problems.Add("$w\$rel changed since the snapshot; the tool keeps no copy") }
        }
        foreach ($rel in $thenFiles.Keys) { if (-not $nowFiles.ContainsKey($rel)) { [void]$problems.Add("$w\$rel is missing; the tool keeps no copy") } }
    }

    # top level
    $rootThen = @($s.root | Where-Object { $_ })
    foreach ($name in Get-Names $InstanceRoot) {
        if ($rootThen -contains $name -or $keepNames -contains $name -or $ReportOnly -contains $name) { continue }
        Add-Action $actions 'delete' $name 'new top-level entry'
    }
    foreach ($name in $rootThen) { if (-not (Test-Path -LiteralPath (Join-Path $InstanceRoot $name))) { [void]$notes.Add("$name existed at the snapshot and is gone (not restored)") } }
    foreach ($f in $ReportOnly) {
        $before = ''
        if ($null -ne $s.reportOnly -and $null -ne $s.reportOnly.PSObject.Properties[$f]) { $before = [string]$s.reportOnly.$f }
        $after = Get-OptionalHash (Join-Path $InstanceRoot $f)
        if ($before -ne $after) { [void]$notes.Add("$f changed or appeared (left as the launcher or the game wrote it; report it)") }
    }

    # screenshots the plan deletes must have a copy outside the instance
    $shotFiles = @()
    foreach ($a in $actions) {
        if ($a.action -ne 'delete') { continue }
        if ($a.path -eq 'screenshots') { $shotFiles += @(Get-ChildItem -LiteralPath (Join-Path $InstanceRoot 'screenshots') -Recurse -File -Force) }
        elseif ($a.path -like 'screenshots\*') { $shotFiles += @(Get-Item -LiteralPath (Join-Path $InstanceRoot $a.path) -Force) }
    }
    if ($shotFiles.Count -gt 0) {
        if (-not $ScreenshotsCopiedTo) { [void]$problems.Add("the plan deletes $($shotFiles.Count) screenshot file(s); copy them out of the instance and pass -ScreenshotsCopiedTo") }
        else {
            $copies = @{}
            if (Test-Path -LiteralPath $ScreenshotsCopiedTo) { foreach ($c in Get-ChildItem -LiteralPath $ScreenshotsCopiedTo -Recurse -File -Force) { $copies[(Get-Hash $c.FullName)] = $true } }
            foreach ($f in $shotFiles) { if (-not $copies.ContainsKey((Get-Hash $f.FullName))) { [void]$problems.Add("screenshots\$($f.Name) has no copy in $ScreenshotsCopiedTo") } }
        }
    }

    foreach ($a in $actions) { if (-not (Test-Inside (Join-Path $InstanceRoot $a.path))) { [void]$problems.Add("$($a.path) is outside what the tool may change") } }
    $lock = ''
    if (Test-Path -LiteralPath $LockPath) { $lock = Get-Hash $LockPath }
    return [ordered]@{
        tool = "instance-reset $ToolVersion"
        instance = $InstanceRoot
        snapshot = $SnapshotRoot
        actions = @($actions)
        problems = @($problems)
        notes = @($notes)
        lock = $lock
        keep = [string]$Keep
        screenshotsCopiedTo = [string]$ScreenshotsCopiedTo
    }
}

function Get-ActionKey { param($Actions) return (@($Actions | ForEach-Object { "$($_.action) $($_.path) $($_.found)" }) -join "`n") }

function Write-PlanText { param($Data)
    Say "Reset plan for $($Data.instance)"
    if ($Data.actions.Count -eq 0) { Say '  nothing to delete or restore' }
    foreach ($a in $Data.actions) { Say ("  {0,-8} {1}  ({2})" -f $a.action, $a.path, $a.reason) }
    foreach ($n in $Data.notes) { Say "  note     $n" }
    foreach ($p in $Data.problems) { Say "  PROBLEM  $p" }
}

function Invoke-Plan {
    $data = Get-PlanData
    $out = $Plan
    if (-not $out) { $out = Join-Path $StagingRoot 'reset-plan.json' }
    [IO.File]::WriteAllText((Get-Full $out), ($data | ConvertTo-Json -Depth 6), $Utf8)
    Write-PlanText $data
    Say "Plan written to $(Get-Full $out)"
    if ($data.problems.Count -gt 0) { exit 1 }
}

# ------------------------------------------------------------------ lock

function Invoke-Lock {
    if (-not $Note) { Fail 'lock needs -Note <file> with the lock note text.' }
    $text = Read-Utf8 (Get-Full $Note)
    if ($Update) {
        if ((Get-LockState) -ne 'ours') { Fail 'There is no lock note of this session to update (missing, or not equal to agent-lock.txt).' }
        [IO.File]::WriteAllText($LockPath, $text, $Utf8)
        [IO.File]::WriteAllText($LockCopy, $text, $Utf8)
        Say "Lock note updated: $LockPath (copy: $LockCopy)"
        return
    }
    if (Test-Path -LiteralPath $LockPath) { Fail "mods\.agent-lock already exists:`n$(Read-Utf8 $LockPath)" }
    if (-not (Test-Path -LiteralPath $ManifestPath)) { Fail "No snapshot at $ManifestPath; run snapshot first." }
    Assert-NoGame
    $stream = $null
    try {
        $stream = New-Object IO.FileStream($LockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $bytes = $Utf8.GetBytes($text)
        $stream.Write($bytes, 0, $bytes.Length)
    } catch [IO.IOException] {
        Fail 'mods\.agent-lock appeared while taking the lock; another session holds the instance.'
    } finally { if ($stream) { $stream.Dispose() } }
    # Compare after the lock exists (Shared Test Instance Preparation step 3), so a change made
    # while the lock was being taken is seen. Any error releases the lock again.
    $data = $null
    try {
        [IO.File]::WriteAllText($LockCopy, $text, $Utf8)
        $data = Get-PlanData
    } catch {
        if ((Test-Path -LiteralPath $LockPath) -and (Get-Hash $LockPath) -eq [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($bytes)).Replace('-', '')) { Remove-Item -LiteralPath $LockPath -Force }
        if (Test-Path -LiteralPath $LockCopy) { Remove-Item -LiteralPath $LockCopy -Force }
        Fail "The lock was released again after an error: $($_.Exception.Message)"
    }
    if ($data.actions.Count -gt 0 -or $data.problems.Count -gt 0) {
        Write-PlanText $data
        if ((Get-LockState) -eq 'ours') { Remove-Item -LiteralPath $LockPath -Force }
        Remove-Item -LiteralPath $LockCopy -Force
        Fail 'The instance differs from the snapshot; the lock was released again. Stop and check who changed it.'
    }
    Say "Lock taken: $LockPath (copy: $LockCopy)"
}

# ------------------------------------------------------------------ apply

function Invoke-Apply {
    if (-not $Plan) { Fail 'apply needs -Plan <file>, the plan that was reviewed.' }
    $reviewed = Read-Utf8 (Get-Full $Plan) | ConvertFrom-Json
    if ([string]$reviewed.instance -ne $InstanceRoot -or [string]$reviewed.snapshot -ne $SnapshotRoot) { Fail 'The plan was made for another instance or staging folder.' }
    # The plan's own options apply again, so the check repeats the reviewed plan exactly.
    if (-not $ScreenshotsCopiedTo -and $reviewed.screenshotsCopiedTo) {
        $script:ScreenshotsCopiedTo = Get-Full ([string]$reviewed.screenshotsCopiedTo)
        if ($ScreenshotsCopiedTo -ieq $InstanceRoot -or $ScreenshotsCopiedTo.StartsWith($InstanceRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { Fail 'The plan names a screenshot copy folder inside the instance.' }
    }
    if (-not $Keep -and $reviewed.keep) { $script:Keep = [string]$reviewed.keep }
    Assert-NoGame
    $data = Get-PlanData
    if ($data.problems.Count -gt 0) { Write-PlanText $data; Fail 'The plan has problems; resolve them first.' }
    if ((Get-ActionKey $reviewed.actions) -ne (Get-ActionKey $data.actions)) {
        Write-PlanText $data
        Fail 'The instance changed since the plan was made (an action, a file, or a folder''s content differs); make a new plan and review it.'
    }
    if ($reviewed.lock -ne $data.lock) { Fail 'mods\.agent-lock changed since the plan was made; another session may hold the instance.' }

    $done = New-Object System.Collections.ArrayList
    $failure = $null
    foreach ($a in $data.actions) {
        $target = Join-Path $InstanceRoot $a.path
        try {
            if (-not (Test-Inside $target)) { throw "Refusing to touch $target" }
            switch ($a.action) {
                'delete' { if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force } }
                'delete-empty-folder' { if (Test-Path -LiteralPath $target) { [IO.Directory]::Delete($target, $false) } }
                'make-folder' { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                'restore' {
                    $source = Join-Path $SnapshotRoot $a.path
                    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "No snapshot copy for $($a.path)" }
                    $parent = Split-Path -Parent $target
                    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                    Copy-Item -LiteralPath $source -Destination $target -Force
                }
            }
        } catch { $failure = "$($a.action) $($a.path): $($_.Exception.Message)"; break }
        [void]$done.Add("$($a.action) $($a.path)")
    }
    if ($failure) {
        Say 'The reset stopped part-way. Done before the error:'
        $done | ForEach-Object { Say "  $_" }
        Fail "Stopped at $failure. The lock note is left in place."
    }

    $after = Get-PlanData
    if ($after.actions.Count -gt 0 -or $after.problems.Count -gt 0) {
        Write-PlanText $after
        Fail 'The instance still differs from the snapshot after the reset; the lock note is left in place.'
    }

    $lockLine = 'lock note: none'
    if (Test-Path -LiteralPath $LockPath) {
        if ($KeepLock) { $lockLine = 'lock note: kept (-KeepLock)' }
        elseif ((Get-LockState) -eq 'ours') {
            Remove-Item -LiteralPath $LockPath -Force
            # The staged copy stays as evidence under a name that marks the lock as given back.
            Move-Item -LiteralPath $LockCopy -Destination (Join-Path $StagingRoot 'agent-lock-released.txt') -Force
            $lockLine = 'lock note: removed last (equal to the staged copy, kept as agent-lock-released.txt)'
        }
        else { $lockLine = 'lock note: NOT removed (it differs from this session''s copy)' }
    }
    $report = @("Instance reset check, $((Get-Date).ToString('yyyy-MM-dd HH:mm')), instance-reset $ToolVersion",
        "Instance: $InstanceRoot", "Snapshot: $SnapshotRoot", 'Actions:') + @($done | ForEach-Object { "  $_" }) +
        @('Check after the reset: no action left; mods, config (files and folders), options.txt, knownkeys.txt, worlds, the watched folders and the top-level entries match the snapshot, apart from the notes below.') +
        @($after.notes | ForEach-Object { "Note: $_" }) + @($lockLine)
    $reportPath = Join-Path $StagingRoot 'reset-check.txt'
    [IO.File]::WriteAllText($reportPath, (($report -join "`r`n") + "`r`n"), $Utf8)
    $report | ForEach-Object { Say $_ }
    Say "Written: $reportPath"
}

switch ($Action) {
    'snapshot' { Invoke-Snapshot }
    'lock' { Invoke-Lock }
    'plan' { Invoke-Plan }
    'apply' { Invoke-Apply }
}
exit 0

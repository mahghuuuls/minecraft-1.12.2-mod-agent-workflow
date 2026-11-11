#requires -Version 5.1
# Dependency-free tests for tools/instance-reset. Builds a fake instance in a temporary folder,
# changes it the way a test session does, and checks that the tool restores it.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$toolDir = Split-Path -Parent $PSScriptRoot
$tool = Join-Path $toolDir 'instance-reset.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ("instance-reset-tests-" + [Guid]::NewGuid().ToString('N'))
$inst = Join-Path $work 'Instance'
$utf8 = New-Object Text.UTF8Encoding($false)
$cafe = 'caf' + [char]0x00E9 + '.cfg'

$script:Failures = 0
$script:Count = 0
function Assert-True { param([bool]$Condition, [string]$Message)
    $script:Count++
    if ($Condition) { Write-Host "  ok    $Message" } else { $script:Failures++; Write-Host "  FAIL  $Message" }
}
function Put { param([string]$Rel, [string]$Text)
    $path = Join-Path $inst $Rel
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, $Text, $utf8)
}
function Has { param([string]$Rel) return (Test-Path -LiteralPath (Join-Path $inst $Rel)) }
function Text { param([string]$Rel) return [IO.File]::ReadAllText((Join-Path $inst $Rel), $utf8) }
function Invoke-Tool { param([string[]]$ToolArgs)
    $ErrorActionPreference = 'Continue'
    $output = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $tool @ToolArgs 2>&1 | Out-String -Width 4096
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}
function New-Instance {
    if (Test-Path $inst) { Remove-Item -Recurse -Force $inst }
    Put 'mods\base-1.0.jar' 'base jar'
    Put 'mods\toolkit-1.7.0.jar' 'toolkit jar'
    Put 'mods\1.12.2\library.jar' 'library'
    Put 'config\forge.cfg' 'forge=1'
    Put "config\$cafe" 'accent'
    Put 'config\devtool\devtool.cfg' 'applyOnJoin=false'
    Put 'config\stellarcore_cache_aaaa.dat' 'cache a'
    New-Item -ItemType Directory -Path (Join-Path $inst 'config\emptydir') -Force | Out-Null
    Put 'options.txt' 'pauseOnLostFocus:false'
    Put 'knownkeys.txt' 'keys'
    Put 'minecraftinstance.json' '{"installedAddons":[1,2,3]}'
    Put 'saves\Old World\level.dat' 'old'
    Put 'screenshots\owner-shot.png' 'owner png'
    Put 'logs\latest.log' 'old log'
}
function Snap { param([string]$Name) $st = Join-Path $work $Name; Invoke-Tool @('snapshot', '-Instance', $inst, '-Staging', $st, '-NoBaseline') | Out-Null; return $st }

try {
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $baseline = Join-Path $work 'baseline.txt'
    [IO.File]::WriteAllText($baseline, "Baseline mod list`r`n  base-1.0.jar 8`r`n  toolkit-1.7.0.jar 11`r`n", $utf8)
    $note = Join-Path $work 'note.txt'
    [IO.File]::WriteAllText($note, "project: test`r`nfiles added: mods/flasks-1.4.0.jar`r`n", $utf8)
    $note2 = Join-Path $work 'note2.txt'
    [IO.File]::WriteAllText($note2, "project: test`r`nfiles added: mods/flasks-1.4.0.jar, mods/extra.jar`r`n", $utf8)

    Write-Host 'snapshot'
    New-Instance
    $staging = Join-Path $work 'staging1'
    $r = Invoke-Tool @('snapshot', '-Instance', $inst, '-Staging', $staging)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'needs -BaselineMods') 'a snapshot without the baseline list or -NoBaseline is refused'
    $r = Invoke-Tool @('snapshot', '-Instance', $inst, '-Staging', $staging, '-BaselineMods', $baseline)
    Assert-True ($r.ExitCode -eq 0 -and (Test-Path (Join-Path $staging 'instance-snapshot\snapshot.json')) -and $r.Output -match 'baseline: checked') 'a snapshot is written after the baseline check'
    Assert-True (Test-Path -LiteralPath (Join-Path $staging "instance-snapshot\config\$cafe")) 'the config folder is copied, accented names included'
    $r = Invoke-Tool @('snapshot', '-Instance', $inst, '-Staging', $staging, '-NoBaseline')
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'already exists') 'a second snapshot into the same staging folder is refused'
    $bad = Join-Path $work 'baseline-bad.txt'
    [IO.File]::WriteAllText($bad, "  base-1.0.jar 8`r`n", $utf8)
    $r = Invoke-Tool @('snapshot', '-Instance', $inst, '-Staging', (Join-Path $work 'staging-bad'), '-BaselineMods', $bad)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'extra: toolkit-1.7.0.jar') 'a mods folder that differs from the baseline list is refused'
    $r = Invoke-Tool @('snapshot', '-Instance', $inst, '-Staging', (Join-Path $inst 'staging'), '-NoBaseline')
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'outside the instance') 'a staging folder inside the instance is refused'
    $r = Invoke-Tool @('plan', '-Instance', $inst, '-Staging', $staging)
    Assert-True ($r.ExitCode -eq 0 -and $r.Output -match 'nothing to delete or restore') 'an unchanged instance plans nothing (accented names read back right)'

    Write-Host 'lock'
    $r = Invoke-Tool @('lock', '-Instance', $inst, '-Staging', (Join-Path $work 'no-snapshot'), '-Note', $note)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'run snapshot first' -and -not (Has 'mods\.agent-lock')) 'a lock before the snapshot is refused and leaves no note'
    $r = Invoke-Tool @('lock', '-Instance', $inst, '-Staging', $staging, '-Note', $note)
    Assert-True ($r.ExitCode -eq 0 -and (Has 'mods\.agent-lock')) 'the lock note is created'
    Assert-True ((Get-Content (Join-Path $staging 'agent-lock.txt') -Raw) -match 'project: test') 'a copy of the note is staged'
    $r = Invoke-Tool @('lock', '-Instance', $inst, '-Staging', $staging, '-Note', $note)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'already exists') 'a second lock is refused'
    $r = Invoke-Tool @('snapshot', '-Instance', $inst, '-Staging', (Join-Path $work 'staging-other'), '-NoBaseline')
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'another session holds the instance') 'a snapshot while locked is refused'
    $r = Invoke-Tool @('lock', '-Instance', $inst, '-Staging', $staging, '-Note', $note2, '-Update')
    Assert-True ($r.ExitCode -eq 0 -and (Text 'mods\.agent-lock') -match 'extra.jar' -and (Get-Content (Join-Path $staging 'agent-lock.txt') -Raw) -match 'extra.jar') 'the session updates its own note and copy'

    Write-Host 'a session changes the instance'
    Put 'mods\flasks-1.4.0.jar' 'flasks jar'
    Put 'config\flasks.cfg' 'diagnostics=true'
    Put 'config\devtool\devtool.cfg' 'applyOnJoin=true'
    Put 'config\devtool\inbox\st-1.result.json' '{}'
    Put "config\$cafe" 'accent changed'
    Remove-Item (Join-Path $inst 'config\stellarcore_cache_aaaa.dat')
    Remove-Item (Join-Path $inst 'config\emptydir')
    Put 'config\stellarcore_cache_bbbb.dat' 'cache b'
    Put 'options.txt' 'pauseOnLostFocus:false gamma:1.0'
    Put 'saves\eft1\level.dat' 'test world'
    Put 'saves\Old World\level.dat' 'old, opened'
    Put 'patchouli_data.json' '{}'
    New-Item -ItemType Directory -Path (Join-Path $inst 'patchouli_books') -Force | Out-Null
    Put 'screenshots\shot-1.png' 'png bytes'
    Put 'crash-reports\crash-1.txt' 'crash'
    Put 'logs\latest.log' 'new log'
    Put 'usercache.json' '[]'
    Put 'keepme\a.txt' 'kept by -Keep'
    Put 'minecraftinstance.json' '{"installedAddons":[1]}'

    Write-Host 'plan'
    $planFile = Join-Path $staging 'reset-plan.json'
    $copies = Join-Path $work 'shots-copy'
    $r = Invoke-Tool @('plan', '-Instance', $inst, '-Staging', $staging, '-Keep', 'keepme')
    Assert-True ($r.ExitCode -eq 1 -and $r.Output -match 'deletes 1 screenshot') 'a new screenshot without a copy is a problem'
    $r = Invoke-Tool @('plan', '-Instance', $inst, '-Staging', $staging, '-Keep', 'keepme', '-ScreenshotsCopiedTo', (Join-Path $inst 'screenshots'))
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'must be outside the instance') 'a copy folder inside the instance is refused'
    New-Item -ItemType Directory -Path $copies -Force | Out-Null
    Copy-Item (Join-Path $inst 'screenshots\shot-1.png') $copies
    $r = Invoke-Tool @('plan', '-Instance', $inst, '-Staging', $staging, '-Keep', 'keepme', '-ScreenshotsCopiedTo', $copies)
    Assert-True ($r.ExitCode -eq 0) 'with the screenshot copied the plan has no problem'
    $o = $r.Output
    Assert-True ($o -match 'delete\s+mods\\flasks-1.4.0.jar') 'the added jar is deleted'
    Assert-True ($o -match 'delete\s+config\\flasks.cfg' -and $o -match 'delete\s+config\\devtool\\inbox\\st-1.result.json' -and $o -match 'delete\s+config\\stellarcore_cache_bbbb.dat') 'new config files are deleted one by one'
    Assert-True ($o -match 'delete-empty-folder\s+config\\devtool\\inbox\s') 'a new config folder is removed only when empty'
    Assert-True ($o -match 'restore\s+config\\devtool\\devtool.cfg' -and $o -match 'restore\s+config\\stellarcore_cache_aaaa.dat' -and $o -match "restore\s+config\\caf") 'changed and deleted config files are restored, accented names included'
    Assert-True ($o -match 'make-folder\s+config\\emptydir') 'an empty config folder the game removed is made again'
    Assert-True ($o -match 'restore\s+options.txt') 'options.txt is restored'
    Assert-True ($o -match 'delete\s+saves\\eft1' -and $o -match 'saves\\Old World existed and was opened') 'the session world is deleted, an opened old world is noted'
    Assert-True ($o -match 'delete\s+screenshots\\shot-1.png' -and $o -notmatch 'owner-shot') 'a new file in an existing screenshots folder is deleted, the old one kept'
    Assert-True ($o -match 'delete\s+patchouli_data.json' -and $o -match 'delete\s+patchouli_books') 'new top-level entries are deleted'
    Assert-True ($o -notmatch 'crash-reports' -and $o -notmatch 'delete\s+logs' -and $o -notmatch 'keepme') 'logs, crash reports and -Keep entries are left alone'
    Assert-True ($o -notmatch 'delete\s+usercache.json' -and $o -match 'usercache.json changed or appeared' -and $o -match 'minecraftinstance.json changed') 'launcher files are reported, never deleted'
    Assert-True ($o -notmatch '1\.12\.2' -and $o -notmatch 'agent-lock') 'the library folder and the lock note are not in the plan'

    Write-Host 'apply refuses a changed instance'
    Put 'mods\flasks-1.4.0.jar' 'another project''s jar with the same name'
    $r = Invoke-Tool @('apply', '-Instance', $inst, '-Staging', $staging, '-Plan', $planFile)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'changed since the plan was made') 'a planned file whose content changed is refused'
    Put 'mods\flasks-1.4.0.jar' 'flasks jar'
    Put 'patchouli_books\new-book.json' 'arrived after the plan'
    $r = Invoke-Tool @('apply', '-Instance', $inst, '-Staging', $staging, '-Plan', $planFile)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'changed since the plan was made' -and (Has 'patchouli_books\new-book.json')) 'a planned folder that gained a file is refused, nothing deleted'
    Remove-Item (Join-Path $inst 'patchouli_books\new-book.json')
    $foreign = Join-Path $work 'foreign-lock.txt'
    Copy-Item (Join-Path $inst 'mods\.agent-lock') $foreign
    [IO.File]::WriteAllText((Join-Path $inst 'mods\.agent-lock'), 'project: someone else', $utf8)
    $r = Invoke-Tool @('plan', '-Instance', $inst, '-Staging', $staging, '-Plan', (Join-Path $work 'foreign-plan.json'))
    Assert-True ($r.ExitCode -eq 1 -and $r.Output -match 'not this session''s note') 'a foreign lock note is a problem at plan time'
    $r = Invoke-Tool @('apply', '-Instance', $inst, '-Staging', $staging, '-Plan', $planFile)
    Assert-True ($r.ExitCode -ne 0 -and (Has 'mods\flasks-1.4.0.jar')) 'apply under a foreign lock note deletes nothing'
    Copy-Item $foreign (Join-Path $inst 'mods\.agent-lock') -Force

    Write-Host 'apply'
    $r = Invoke-Tool @('apply', '-Instance', $inst, '-Staging', $staging, '-Plan', $planFile)
    Assert-True ($r.ExitCode -eq 0) 'the reviewed plan applies'
    Assert-True (-not (Has 'mods\flasks-1.4.0.jar') -and (Has 'mods\1.12.2\library.jar')) 'the jar is gone and the library folder stays'
    Assert-True ((Text 'config\devtool\devtool.cfg') -eq 'applyOnJoin=false' -and (Text "config\$cafe") -eq 'accent') 'changed config files have their old content'
    Assert-True ((Has 'config\stellarcore_cache_aaaa.dat') -and -not (Has 'config\stellarcore_cache_bbbb.dat') -and (Has 'config\emptydir')) 'the deleted cache and folder are back, the new cache gone'
    Assert-True (-not (Has 'config\devtool\inbox') -and (Has 'config\devtool')) 'the new config folder is gone, its parent stays'
    Assert-True (-not (Has 'saves\eft1') -and (Has 'saves\Old World\level.dat')) 'the session world is gone, the old one stays'
    Assert-True (-not (Has 'screenshots\shot-1.png') -and (Has 'screenshots\owner-shot.png') -and -not (Has 'patchouli_books')) 'session files are gone, the owner''s screenshot stays'
    Assert-True ((Has 'crash-reports\crash-1.txt') -and (Text 'logs\latest.log') -eq 'new log' -and (Has 'keepme\a.txt') -and (Has 'usercache.json')) 'logs, crash reports, -Keep entries and launcher files are kept'
    Assert-True (-not (Has 'mods\.agent-lock')) 'the lock note is removed last'
    $check = Join-Path $staging 'reset-check.txt'
    Assert-True ((Test-Path $check) -and ((Get-Content $check -Raw) -match 'lock note: removed last') -and ((Get-Content $check -Raw) -match 'Old World existed and was opened')) 'the reset check is written with its notes'
    $r = Invoke-Tool @('plan', '-Instance', $inst, '-Staging', $staging, '-Keep', 'keepme')
    Assert-True ($r.ExitCode -eq 0 -and $r.Output -match 'nothing to delete or restore') 'a new plan after the reset is empty'

    Write-Host 'problems and guards'
    New-Instance
    $staging2 = Snap 'staging2'
    Remove-Item (Join-Path $inst 'mods\base-1.0.jar')
    Put 'mods\toolkit-1.7.0.jar' 'a different toolkit jar'
    $r = Invoke-Tool @('plan', '-Instance', $inst, '-Staging', $staging2)
    Assert-True ($r.ExitCode -eq 1 -and $r.Output -match 'base-1.0.jar is missing' -and $r.Output -match 'toolkit-1.7.0.jar changed') 'a missing or changed baseline jar is a problem'
    $r = Invoke-Tool @('apply', '-Instance', $inst, '-Staging', $staging2, '-Plan', (Join-Path $staging2 'reset-plan.json'))
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'problems') 'apply refuses a plan with problems'
    $r = Invoke-Tool @('lock', '-Instance', $inst, '-Staging', $staging2, '-Note', $note)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'released again' -and -not (Has 'mods\.agent-lock') -and -not (Test-Path (Join-Path $staging2 'agent-lock.txt'))) 'a lock over a changed instance is released again'

    New-Instance
    $staging3 = Snap 'staging3'
    Invoke-Tool @('lock', '-Instance', $inst, '-Staging', $staging3, '-Note', $note) | Out-Null
    Put 'saves\eft2\level.dat' 'w'
    Invoke-Tool @('plan', '-Instance', $inst, '-Staging', $staging3) | Out-Null
    $r = Invoke-Tool @('apply', '-Instance', $inst, '-Staging', $staging3, '-Plan', (Join-Path $staging3 'reset-plan.json'), '-KeepLock')
    Assert-True ($r.ExitCode -eq 0 -and -not (Has 'saves\eft2') -and (Has 'mods\.agent-lock') -and $r.Output -match 'kept \(-KeepLock\)') '-KeepLock leaves the note in place'
    $r = Invoke-Tool @('apply', '-Instance', $inst, '-Staging', (Join-Path $work 'staging1'), '-Plan', (Join-Path $staging3 'reset-plan.json'))
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'another instance or staging folder') 'a plan from another staging folder is refused'

    if (Test-Path $inst) { Remove-Item -Recurse -Force $inst }
    Put 'mods\base-1.0.jar' 'base jar'
    $staging4 = Snap 'staging4'
    Put 'config\new.cfg' 'x'
    $r = Invoke-Tool @('plan', '-Instance', $inst, '-Staging', $staging4)
    Assert-True ($r.ExitCode -eq 0 -and $r.Output -match 'delete\s+config\\new.cfg' -and $r.Output -match 'delete\s+config\s') 'an instance without config at the snapshot plans the new config folder away'
    $r = Invoke-Tool @('plan', '-Instance', (Join-Path $work 'nowhere'), '-Staging', $staging4)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'Instance folder not found') 'a missing instance folder is refused'
    $r = Invoke-Tool @('plan', '-Instance', 'C:\', '-Staging', $staging4)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'drive root') 'a drive root is refused'
}
finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "$($script:Count) checks, $($script:Failures) failed"
if ($script:Failures -gt 0) { exit 1 }
exit 0

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop
Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

$Tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'mod-jar.ps1'
$Launcher = Join-Path (Split-Path -Parent $PSScriptRoot) 'mod-jar.cmd'
$TestDirectory = Join-Path ([IO.Path]::GetTempPath()) ('minecraft-mod-jar-' + [Guid]::NewGuid().ToString('N'))
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

function Invoke-Tool {
    # Converts command-line style arguments into a hashtable splat, because splatting an
    # array into a script binds every element positionally. Bare tokens after the action
    # are the jar paths.
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
    if ($positional.Count -gt 1) {
        $named['Jar'] = @($positional.ToArray()[1..($positional.Count - 1)])
    }
    return @(& $Tool @named | ForEach-Object { [string]$_ })
}

# --- A minimal class-file assembler, enough to write RuntimeVisibleAnnotations. ---

function New-PoolBuilder {
    return @{ Entries = New-Object 'System.Collections.Generic.List[byte[]]'; Utf8 = @{} }
}

function Add-Utf8 {
    param($Builder, [string]$Value)
    if ($Builder.Utf8.ContainsKey($Value)) { return [int]$Builder.Utf8[$Value] }
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $entry = New-Object 'System.Collections.Generic.List[byte]'
    $entry.Add(1)
    $entry.Add([byte](($bytes.Length -shr 8) -band 0xFF))
    $entry.Add([byte]($bytes.Length -band 0xFF))
    $entry.AddRange($bytes)
    $Builder.Entries.Add($entry.ToArray())
    $index = $Builder.Entries.Count
    $Builder.Utf8[$Value] = $index
    return $index
}

function Add-Integer {
    param($Builder, [int]$Value)
    $Builder.Entries.Add([byte[]]@(3, (($Value -shr 24) -band 0xFF), (($Value -shr 16) -band 0xFF), (($Value -shr 8) -band 0xFF), ($Value -band 0xFF)))
    return $Builder.Entries.Count
}

function Add-ClassRef {
    param($Builder, [int]$NameIndex)
    $Builder.Entries.Add([byte[]]@(7, (($NameIndex -shr 8) -band 0xFF), ($NameIndex -band 0xFF)))
    return $Builder.Entries.Count
}

function Add-U2 {
    param([System.Collections.Generic.List[byte]]$Target, [int]$Value)
    $Target.Add([byte](($Value -shr 8) -band 0xFF))
    $Target.Add([byte]($Value -band 0xFF))
}

function Add-U4 {
    param([System.Collections.Generic.List[byte]]$Target, [int]$Value)
    $Target.Add([byte](($Value -shr 24) -band 0xFF))
    $Target.Add([byte](($Value -shr 16) -band 0xFF))
    $Target.Add([byte](($Value -shr 8) -band 0xFF))
    $Target.Add([byte]($Value -band 0xFF))
}

function Add-ElementValue {
    param($Builder, [System.Collections.Generic.List[byte]]$Target, [hashtable]$Element)
    switch -CaseSensitive ($Element.Tag) {
        's' { $Target.Add(0x73); Add-U2 $Target (Add-Utf8 $Builder $Element.Value) }
        'Z' { $Target.Add(0x5A); Add-U2 $Target (Add-Integer $Builder ([int]$Element.Value)) }
        'I' { $Target.Add(0x49); Add-U2 $Target (Add-Integer $Builder ([int]$Element.Value)) }
        'e' { $Target.Add(0x65); Add-U2 $Target (Add-Utf8 $Builder $Element.Type); Add-U2 $Target (Add-Utf8 $Builder $Element.Value) }
        'c' { $Target.Add(0x63); Add-U2 $Target (Add-Utf8 $Builder $Element.Value) }
        '@' { $Target.Add(0x40); Add-AnnotationBytes $Builder $Target $Element.Value }
        '[' {
            $Target.Add(0x5B)
            Add-U2 $Target $Element.Value.Count
            foreach ($item in $Element.Value) { Add-ElementValue $Builder $Target $item }
        }
        default { throw "Unknown fixture element tag $($Element.Tag)" }
    }
}

function Add-AnnotationBytes {
    param($Builder, [System.Collections.Generic.List[byte]]$Target, [hashtable]$Annotation)
    Add-U2 $Target (Add-Utf8 $Builder $Annotation.Type)
    Add-U2 $Target $Annotation.Pairs.Count
    foreach ($pair in $Annotation.Pairs) {
        Add-U2 $Target (Add-Utf8 $Builder $pair.Name)
        Add-ElementValue $Builder $Target $pair.Value
    }
}

function New-ClassBytes {
    param([string]$ClassName, [hashtable[]]$Annotations)
    $builder = New-PoolBuilder
    $thisClass = Add-ClassRef $builder (Add-Utf8 $builder $ClassName)
    $superClass = Add-ClassRef $builder (Add-Utf8 $builder 'java/lang/Object')
    $attributeName = Add-Utf8 $builder 'RuntimeVisibleAnnotations'
    $annotationBytes = New-Object 'System.Collections.Generic.List[byte]'
    Add-U2 $annotationBytes $Annotations.Count
    foreach ($annotation in $Annotations) { Add-AnnotationBytes $builder $annotationBytes $annotation }

    $class = New-Object 'System.Collections.Generic.List[byte]'
    $class.AddRange([byte[]]@(0xCA, 0xFE, 0xBA, 0xBE, 0, 0, 0, 0x34))
    Add-U2 $class ($builder.Entries.Count + 1)
    foreach ($entry in $builder.Entries) { $class.AddRange($entry) }
    Add-U2 $class 0x0021
    Add-U2 $class $thisClass
    Add-U2 $class $superClass
    Add-U2 $class 0
    Add-U2 $class 0
    Add-U2 $class 0
    Add-U2 $class 1
    Add-U2 $class $attributeName
    Add-U4 $class $annotationBytes.Count
    $class.AddRange($annotationBytes)
    return , $class.ToArray()
}

function New-ModAnnotation {
    param([string]$ModId, [string]$Version, [string]$Dependencies, [bool]$UseMetadata, [string]$Name)
    $pairs = New-Object 'System.Collections.Generic.List[hashtable]'
    $pairs.Add(@{ Name = 'modid'; Value = @{ Tag = 's'; Value = $ModId } })
    if ($null -ne $Name) { $pairs.Add(@{ Name = 'name'; Value = @{ Tag = 's'; Value = $Name } }) }
    if ($null -ne $Version) { $pairs.Add(@{ Name = 'version'; Value = @{ Tag = 's'; Value = $Version } }) }
    if ($null -ne $Dependencies) { $pairs.Add(@{ Name = 'dependencies'; Value = @{ Tag = 's'; Value = $Dependencies } }) }
    if ($UseMetadata) { $pairs.Add(@{ Name = 'useMetadata'; Value = @{ Tag = 'Z'; Value = 1 } }) }
    return @{ Type = 'Lnet/minecraftforge/fml/common/Mod;'; Pairs = @($pairs.ToArray()) }
}

$DecoyAnnotation = @{
    Type = 'Lfixture/Decoy;'
    Pairs = @(
        @{ Name = 'mode'; Value = @{ Tag = 'e'; Type = 'Lfixture/Mode;'; Value = 'FAST' } },
        @{ Name = 'names'; Value = @{ Tag = '['; Value = @(@{ Tag = 's'; Value = 'one' }, @{ Tag = 's'; Value = 'two' }) } },
        @{ Name = 'nested'; Value = @{ Tag = '@'; Value = @{ Type = 'Lfixture/Inner;'; Pairs = @(@{ Name = 'text'; Value = @{ Tag = 's'; Value = 'inner' } }) } } },
        @{ Name = 'type'; Value = @{ Tag = 'c'; Value = 'Ljava/lang/String;' } },
        @{ Name = 'count'; Value = @{ Tag = 'I'; Value = 7 } }
    )
}

function New-Jar {
    param([string]$Path, [hashtable]$Entries)
    $archive = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in $Entries.Keys) {
            $entry = $archive.CreateEntry($name)
            $stream = $entry.Open()
            try {
                $content = $Entries[$name]
                if ($content -is [byte[]]) { $bytes = $content } else { $bytes = $Utf8NoBom.GetBytes([string]$content) }
                $stream.Write($bytes, 0, $bytes.Length)
            }
            finally {
                $stream.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

[IO.Directory]::CreateDirectory($TestDirectory) | Out-Null
try {
    $okFolder = Join-Path $TestDirectory 'mods-ok'
    $badFolder = Join-Path $TestDirectory 'mods-bad'
    [IO.Directory]::CreateDirectory($okFolder) | Out-Null
    [IO.Directory]::CreateDirectory($badFolder) | Out-Null

    $fixtureClass = New-ClassBytes -ClassName 'fixture/FixtureMod' -Annotations @(
        $DecoyAnnotation,
        (New-ModAnnotation -ModId 'fixturemod' -Name 'Fixture Mod' -Version '1.2.3' -Dependencies 'required-after:libmod@[2.0,);after:jei;required-before:otherlib' -UseMetadata $false)
    )
    $fixtureEntries = @{
        'mcmod.info' = '[{"modid": "fixturemod", "name": "Fixture Mod", "version": "1.2.3", "mcversion": "1.12.2", "requiredMods": ["libmod"], "useDependencyInformation": false,}]'
        'META-INF/MANIFEST.MF' = "Manifest-Version: 1.0`r`nFMLAT: fixture_at.cfg`r`n`r`n"
        'fixture/FixtureMod.class' = $fixtureClass
        'assets/fixturemod/recipes/thing.json' = '{"type": "minecraft:crafting_shapeless", "ingredients": [{"item": "libmod:log", "data": 0}, {"type": "forge:ore_dict", "ore": "logWood"}, {"item": "stick"}], "result": {"item": "fixturemod:thing", "count": 1}}'
        'assets/fixturemod/recipes/_factories.json' = '{"item": "should_not_count"}'
        'assets/fixturemod/advancements/recipes/thing.json' = '{"criteria": {"has": {"trigger": "minecraft:inventory_changed", "conditions": {"items": [{"data": 2, "item": "libmod:gem"}]}}}}'
        'assets/fixturemod/blockstates/block_a.json' = '{}'
        'assets/fixturemod/models/item/thing.json' = '{}'
        'assets/fixturemod/models/item/thing_variant.json' = '{}'
        'assets/fixturemod/lang/en_us.lang' = "item.fixturemod.thing.name=Fixture Thing`ntile.fixturemod.block_a.name=Block A`ngui.fixturemod.title=Title`n"
    }
    $fixtureJar = Join-Path $okFolder 'fixturemod-1.2.3.jar'
    New-Jar -Path $fixtureJar -Entries $fixtureEntries
    New-Jar -Path (Join-Path $badFolder 'fixturemod-1.2.3.jar') -Entries $fixtureEntries

    $libClass = New-ClassBytes -ClassName 'lib/LibMod' -Annotations @(
        (New-ModAnnotation -ModId 'libmod' -Version '' -Dependencies $null -UseMetadata $true -Name $null)
    )
    $libJar = Join-Path $okFolder 'libmod-2.1.0.jar'
    New-Jar -Path $libJar -Entries @{
        'mcmod.info' = '{"modListVersion": 2, "modList": [{"modid": "libmod", "name": "Lib Mod", "version": "2.1.0", "requiredMods": ["forge@[14.23,)"], "dependencies": ["forge"], "useDependencyInformation": true}]}'
        'lib/LibMod.class' = $libClass
        'assets/libmod/lang/en_US.lang' = "tile.libmod.log.name=Lib Log`n"
    }

    $coremodJar = Join-Path $okFolder 'coremod.jar'
    New-Jar -Path $coremodJar -Entries @{
        'META-INF/MANIFEST.MF' = "Manifest-Version: 1.0`r`nFMLCorePlugin: fixture.Plugin`r`nMixinConfigs: mixins.fixture.json`r`n`r`n"
        'mixins.fixture.json' = '{}'
        'fixture/Plugin.class' = [byte[]]@(0xCA, 0xFE, 0xBA, 0xBE, 0, 0, 0, 0x34, 0, 1)
    }

    $oldLibClass = New-ClassBytes -ClassName 'lib/LibMod' -Annotations @(
        (New-ModAnnotation -ModId 'libmod' -Version '1.0.0' -Dependencies $null -UseMetadata $false -Name $null)
    )
    New-Jar -Path (Join-Path $badFolder 'oldlib-1.0.0.jar') -Entries @{ 'lib/LibMod.class' = $oldLibClass }

    $dupeClass = New-ClassBytes -ClassName 'dupe/DupeMod' -Annotations @(
        (New-ModAnnotation -ModId 'fixturemod' -Version '9' -Dependencies $null -UseMetadata $false -Name $null)
    )
    New-Jar -Path (Join-Path $badFolder 'dupe.jar') -Entries @{ 'dupe/DupeMod.class' = $dupeClass }

    $brokenClass = New-ClassBytes -ClassName 'broken/BrokenMod' -Annotations @(
        (New-ModAnnotation -ModId 'broken' -Version '0.1' -Dependencies $null -UseMetadata $false -Name $null)
    )
    New-Jar -Path (Join-Path $badFolder 'broken-info.jar') -Entries @{
        'mcmod.info' = '{not json'
        'broken/BrokenMod.class' = $brokenClass
    }

    # info: metadata combination and sources
    $info = Invoke-Tool @('info', $fixtureJar)
    Assert-Contains $info "  mod fixturemod 'Fixture Mod' version '1.2.3' (@Mod version) in fixture/FixtureMod.class useMetadata=False" 'The @Mod annotation was not read past the decoy annotation.'
    Assert-Contains $info '    dependencies from @Mod dependencies: required-after:libmod@[2.0,); after:jei; required-before:otherlib' 'The @Mod dependency string was not parsed.'
    Assert-Contains $info "    fixturemod 'Fixture Mod' version '1.2.3' mcversion '1.12.2' useDependencyInformation=False" 'mcmod.info with a trailing comma was not repaired and read.'
    Assert-Contains $info '      requiredMods: libmod' 'mcmod.info requiredMods were not listed.'
    Assert-Contains $info '  manifest loader attributes: FMLAT=fixture_at.cfg' 'Manifest loader attributes were not listed.'
    Assert-Contains $info '  assets: domains fixturemod; 1 classes, 9 resources, 2 recipes, 2 item models, 1 blockstates, 1 lang files' 'Asset counts are wrong.'

    $libInfo = (Invoke-Tool @('info', $libJar, '-Json')) -join "`n" | ConvertFrom-Json
    $libMod = @($libInfo)[0].mods[0]
    Assert-Equal $libMod.version '2.1.0' 'An empty @Mod version did not fall back to mcmod.info.'
    Assert-Equal $libMod.versionSource 'mcmod.info version' 'The version source label is wrong.'
    Assert-Equal $libMod.useMetadata $true 'The boolean useMetadata element was not read.'
    Assert-Equal $libMod.dependencySource 'mcmod.info (useMetadata and useDependencyInformation)' 'useMetadata plus useDependencyInformation did not select the mcmod.info lists.'
    Assert-Equal $libMod.dependencies[0].modId 'forge' 'The mcmod.info requiredMods target is wrong.'
    Assert-Equal $libMod.dependencies[0].range '[14.23,)' 'The mcmod.info requiredMods range is wrong.'
    Assert-Equal $libMod.dependencies[0].required $true 'A requiredMods entry was not marked required.'
    Assert-Equal @($libInfo)[0].mcmodInfo.mods[0].useDependencyInformation $true 'The modListVersion 2 shape was not read.'

    $brokenInfo = Invoke-Tool @('info', (Join-Path $badFolder 'broken-info.jar'))
    Assert-Contains $brokenInfo '  mcmod.info: could not be parsed' 'An unparseable mcmod.info was not reported.'
    Assert-Contains $brokenInfo "  mod broken 'broken' version '0.1' (@Mod version)" 'The @Mod data was not used when mcmod.info is broken.'

    $coremodInfo = Invoke-Tool @('info', $coremodJar)
    Assert-Contains $coremodInfo '  manifest loader attributes: FMLCorePlugin=fixture.Plugin; MixinConfigs=mixins.fixture.json' 'Coremod manifest attributes were not listed.'
    Assert-Contains $coremodInfo '  @Mod annotations: none found' 'A jar without @Mod was not reported as such.'
    Assert-Contains $coremodInfo '  mixin configs at the jar root: mixins.fixture.json' 'The root mixin config was not listed.'

    $skipped = Invoke-Tool @('info', $fixtureJar, '-SkipClasses')
    Assert-Contains $skipped '  @Mod annotations: not scanned (-SkipClasses)' '-SkipClasses did not report the skipped scan.'
    Assert-Contains $skipped "  mod fixturemod 'Fixture Mod' version '1.2.3' (mcmod.info version)" 'With -SkipClasses the mcmod.info entry was not used.'
    Assert-Contains $skipped '    note: from mcmod.info; classes were not scanned' 'The -SkipClasses note is missing.'

    # items: sources and labels
    $items = Invoke-Tool @('items', $fixtureJar)
    Assert-Contains $items '  recipe: libmod:log data 0  <- assets/fixturemod/recipes/thing.json' 'A recipe ingredient with data was not listed.'
    Assert-Contains $items '  recipe: minecraft:stick  <- assets/fixturemod/recipes/thing.json' 'A recipe ingredient without a namespace was not prefixed with minecraft.'
    Assert-Contains $items '  recipe: fixturemod:thing  <- assets/fixturemod/recipes/thing.json' 'The recipe result was not listed.'
    Assert-Contains $items '  recipe-ore: logWood  <- assets/fixturemod/recipes/thing.json' 'An ore-dictionary ingredient was not listed.'
    Assert-Contains $items '  advancement: libmod:gem data 2  <- assets/fixturemod/advancements/recipes/thing.json' 'An advancement item with data before item was not listed.'
    Assert-Contains $items '  blockstate: fixturemod:block_a  <- assets/fixturemod/blockstates/block_a.json' 'A blockstate was not listed.'
    Assert-Contains $items '  model: fixturemod:thing_variant  <- assets/fixturemod/models/item/thing_variant.json' 'An item model was not listed.'
    Assert-Contains $items "  lang: fixturemod.thing 'Fixture Thing'  <- assets/fixturemod/lang/en_us.lang item.fixturemod.thing.name" 'A lang key with its display name was not listed.'
    Assert-NotContains $items 'should_not_count' 'The _factories.json file was read as a recipe.'
    Assert-NotContains $items 'gui.fixturemod.title' 'A non-item lang key was listed.'

    $recipeJson = (Invoke-Tool @('items', $fixtureJar, '-Source', 'recipe', '-Json')) -join "`n" | ConvertFrom-Json
    Assert-Equal @($recipeJson).Count 3 'The recipe-only JSON list count is wrong.'

    # find: single jar reads recipes, folder reads names only unless asked
    $foundDisplay = Invoke-Tool @('find', '-Text', 'fixture thing', $fixtureJar)
    Assert-Contains $foundDisplay 'Matches: 1' 'find by display name did not match the lang entry.'
    Assert-Contains $foundDisplay "  lang: fixturemod.thing 'Fixture Thing'" 'The display-name hit is wrong.'

    $folderFind = Invoke-Tool @('find', '-Text', 'log', '-Folder', $okFolder)
    Assert-Contains $folderFind 'file names and lang keys only; add -IncludeRecipes' 'Folder find did not say that recipes were skipped.'
    Assert-Contains $folderFind "  lang: libmod.log 'Lib Log'  <- assets/libmod/lang/en_US.lang tile.libmod.log.name [libmod-2.1.0.jar]" 'Folder find did not read an en_US lang file.'
    Assert-NotContains $folderFind 'recipe: libmod:log' 'Folder find read recipes without -IncludeRecipes.'

    $folderDeep = Invoke-Tool @('find', '-Text', 'log', '-Folder', $okFolder, '-IncludeRecipes')
    Assert-Contains $folderDeep '  recipe: libmod:log data 0  <- assets/fixturemod/recipes/thing.json [fixturemod-1.2.3.jar]' 'Folder find with -IncludeRecipes did not read the recipe.'
    Assert-Contains $folderDeep '  recipe-ore: logWood' 'Folder find with -IncludeRecipes did not read the ore entry.'

    $filtered = Invoke-Tool @('find', '-Text', 'log', '-Folder', $okFolder, '-JarFilter', 'libmod')
    Assert-Contains $filtered 'Searched 1 jar(s)' '-JarFilter did not narrow the folder.'

    # check: a loadable set
    $okCheck = Invoke-Tool @('check', '-Folder', $okFolder)
    Assert-Contains $okCheck 'Jars checked: 3' 'The folder jar count is wrong.'
    Assert-Contains $okCheck '  fixturemod-1.2.3.jar -> fixturemod 1.2.3 (requires: required-after:libmod@[2.0,); required-before:otherlib)' 'The per-mod requirement line is wrong.'
    Assert-Contains $okCheck "  MISSING 'otherlib' required by fixturemod (fixturemod-1.2.3.jar) as required-before:otherlib" 'A missing required-before target was not reported.'
    Assert-Contains $okCheck 'Problems: 1' 'The ok folder should have exactly one problem (otherlib).'
    Assert-Contains $okCheck '  coremod, tweaker, or mixin jar: coremod.jar' 'The coremod note is missing.'
    Assert-Contains $okCheck '  no mod id found: coremod.jar (no mod id; manifest FMLCorePlugin, MixinConfigs)' 'The no-mod-id note is missing.'

    $providedCheck = Invoke-Tool @('check', '-Folder', $okFolder, '-Provided', 'otherlib')
    Assert-Contains $providedCheck 'Provided by the environment: otherlib' 'The provided list was not echoed.'
    Assert-Contains $providedCheck 'Result: OK, every required mod is present and no mod id is duplicated' '-Provided did not satisfy the missing requirement.'

    $environmentDuplicate = Invoke-Tool @('check', '-Folder', $okFolder, '-Provided', 'otherlib,libmod')
    Assert-Contains $environmentDuplicate "  DUPLICATE mod id 'libmod' is provided by (provided by the environment) and libmod-2.1.0.jar" 'A jar duplicating an environment-provided mod was not reported.'

    # check: duplicates, version mismatch, broken metadata
    $badCheck = Invoke-Tool @('check', '-Folder', $badFolder, '-Provided', 'otherlib')
    Assert-Contains $badCheck "  DUPLICATE mod id 'fixturemod' is provided by dupe.jar and fixturemod-1.2.3.jar" 'A duplicate mod id across two jars was not reported.'
    Assert-Contains $badCheck "  VERSION 'libmod' 1.0.0 is outside [2.0,) wanted by fixturemod (fixturemod-1.2.3.jar) as required-after:libmod@[2.0,); basic comparison" 'A version outside the required range was not reported.'
    Assert-Contains $badCheck 'Problems: 2' 'The bad folder should have two problems.'
    Assert-Contains $badCheck '  mcmod.info could not be parsed in broken-info.jar' 'The broken mcmod.info note is missing.'
    Assert-Contains $badCheck 'Result: 2 problem(s); a launch with this set fails or refuses to load' 'The failing result line is wrong.'

    $badJson = (Invoke-Tool @('check', '-Folder', $badFolder, '-Json')) -join "`n" | ConvertFrom-Json
    Assert-Equal @($badJson.problems).Count 3 'JSON problems should include the missing otherlib without -Provided.'
    Assert-Equal @($badJson.mods).Count 4 'JSON mods count is wrong.'

    $strictRejected = $false
    try { & $Tool check -Folder $badFolder -Strict 2>$null | Out-Null }
    catch { $strictRejected = $_.Exception.Message -like '*Dependency check found 3 problem(s).*' }
    Assert-Equal $strictRejected $true '-Strict did not fail on problems.'

    $missingJar = $false
    try { & $Tool info (Join-Path $TestDirectory 'nope.jar') 2>$null | Out-Null }
    catch { $missingJar = $_.Exception.Message -like '*Jar not found*' }
    Assert-Equal $missingJar $true 'A missing jar path was not rejected.'

    $launcherCommand = 'set "PSModuleAutoLoadingPreference=None" && call "' + $Launcher + '" check -Folder "' + $okFolder + '" -Provided otherlib'
    $launcherOutput = @(& cmd.exe /d /c $launcherCommand)
    Assert-Equal $LASTEXITCODE 0 'Batch launcher failed with module autoload disabled.'
    Assert-Contains @($launcherOutput | ForEach-Object { [string]$_ }) 'Result: OK' 'Batch launcher did not run the check with module autoload disabled.'

    Write-Output 'All mod-jar tests passed.'
}
finally {
    if ([IO.Directory]::Exists($TestDirectory)) {
        $resolved = [IO.Path]::GetFullPath($TestDirectory)
        $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notmatch '^minecraft-mod-jar-[0-9a-f]{32}$') {
            throw "Refusing to remove unexpected test directory: $resolved"
        }
        [IO.Directory]::Delete($resolved, $true)
    }
}

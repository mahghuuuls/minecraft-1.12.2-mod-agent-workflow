[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('info', 'items', 'find', 'check')]
    [string]$Action,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Jar,

    [string]$Folder,

    [string]$Text,

    [string]$Source,

    [string]$Provided,

    [string]$JarFilter,

    [switch]$IncludeRecipes,

    [switch]$SkipClasses,

    [switch]$Strict,

    [switch]$Json
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Windows PowerShell does not always autoload standard modules when the tool is launched
# through the batch wrapper. Utility provides JSON and hashing commands; Management provides
# the filesystem commands used to list a mods folder.
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop
Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

$ToolVersion = '1.0.0'
$ModAnnotationType = 'Lnet/minecraftforge/fml/common/Mod;'
$Latin1 = [Text.Encoding]::GetEncoding(28591)
$Utf8 = New-Object Text.UTF8Encoding($false)
$BuiltInModIds = @('minecraft', 'forge', 'fml', 'mcp')
$LoaderManifestKeys = @('FMLCorePlugin', 'FMLCorePluginContainsFMLMod', 'MixinConfigs', 'TweakClass', 'TweakOrder', 'FMLAT', 'ContainedDeps', 'Maven-Artifact')
$KnownInstructions = @('required-after', 'required-before', 'after', 'before', 'required-after-client', 'required-after-server', 'required-before-client', 'required-before-server', 'required', 'required-client', 'required-server')

$ItemDataRegex = New-Object regex('"item"\s*:\s*"(?<item>[^"]+)"\s*,\s*"data"\s*:\s*(?<data>\d+)')
$DataItemRegex = New-Object regex('"data"\s*:\s*(?<data>\d+)\s*,\s*"item"\s*:\s*"(?<item>[^"]+)"')
$ItemRegex = New-Object regex('"item"\s*:\s*"(?<item>[^"]+)"')
$OreRegex = New-Object regex('"ore"\s*:\s*"(?<ore>[^"]+)"')

function Split-List {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }
    return @($Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

function Get-JarList {
    $paths = New-Object 'System.Collections.Generic.List[string]'
    foreach ($candidate in @(@($Jar) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($candidate)
        if (-not [IO.File]::Exists($resolved)) {
            throw "Jar not found: $resolved"
        }
        $paths.Add($resolved)
    }

    if (-not [string]::IsNullOrWhiteSpace($Folder)) {
        $resolvedFolder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Folder)
        if (-not [IO.Directory]::Exists($resolvedFolder)) {
            throw "Folder not found: $resolvedFolder"
        }
        foreach ($file in (Get-ChildItem -LiteralPath $resolvedFolder -File -Filter '*.jar' | Sort-Object Name)) {
            if (-not [string]::IsNullOrWhiteSpace($JarFilter) -and $file.Name.IndexOf($JarFilter, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                continue
            }
            if (-not $paths.Contains($file.FullName)) {
                $paths.Add($file.FullName)
            }
        }
    }

    if ($paths.Count -eq 0) {
        throw 'Name at least one jar after the action, or pass -Folder <mods directory>.'
    }
    return $paths.ToArray()
}

function Read-EntryBytes {
    param([IO.Compression.ZipArchiveEntry]$Entry)

    $stream = $Entry.Open()
    try {
        $memory = New-Object IO.MemoryStream
        try {
            $stream.CopyTo($memory)
            return , $memory.ToArray()
        }
        finally {
            $memory.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Read-EntryText {
    param([IO.Compression.ZipArchiveEntry]$Entry)

    $bytes = Read-EntryBytes -Entry $Entry
    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $offset = 3
    }
    return $Utf8.GetString($bytes, $offset, $bytes.Length - $offset)
}

function Get-OptionalProperty {
    param($Object, [string]$Name, $DefaultValue)

    if ($null -eq $Object) { return $DefaultValue }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $DefaultValue }
    return $property.Value
}

function ConvertTo-StringList {
    param($Value)

    if ($null -eq $Value) { return @() }
    return @(@($Value) | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Read-ModInfo {
    # Reads mcmod.info in both shapes: the plain list, and the modListVersion 2 object with a
    # modList. A broken file is reported, not fatal; FML would also fall back to the @Mod data.
    param([IO.Compression.ZipArchive]$Archive)

    $entry = $Archive.GetEntry('mcmod.info')
    $result = [ordered]@{
        status = 'missing'
        error = $null
        mods = @()
    }
    if ($null -eq $entry) {
        return $result
    }

    $text = Read-EntryText -Entry $entry
    $parsed = $null
    try {
        $parsed = ConvertFrom-Json -InputObject $text
    }
    catch {
        try {
            $repaired = [regex]::Replace($text, ',\s*([\]\}])', '$1')
            $parsed = ConvertFrom-Json -InputObject $repaired
        }
        catch {
            $result.status = 'invalid'
            $result.error = $_.Exception.Message
            return $result
        }
    }

    $list = @()
    if ($null -ne $parsed -and $null -ne $parsed.PSObject.Properties['modList']) {
        $list = @($parsed.modList)
    }
    else {
        $list = @($parsed)
    }

    $mods = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $list) {
        if ($null -eq $item) { continue }
        $mods.Add([ordered]@{
            modid = [string](Get-OptionalProperty $item 'modid' '')
            name = [string](Get-OptionalProperty $item 'name' '')
            version = [string](Get-OptionalProperty $item 'version' '')
            mcversion = [string](Get-OptionalProperty $item 'mcversion' '')
            requiredMods = @(ConvertTo-StringList (Get-OptionalProperty $item 'requiredMods' $null))
            dependencies = @(ConvertTo-StringList (Get-OptionalProperty $item 'dependencies' $null))
            dependants = @(ConvertTo-StringList (Get-OptionalProperty $item 'dependants' $null))
            useDependencyInformation = [bool](Get-OptionalProperty $item 'useDependencyInformation' $false)
        })
    }
    $result.status = 'parsed'
    $result.mods = @($mods.ToArray())
    return $result
}

function Read-Manifest {
    param([IO.Compression.ZipArchive]$Archive)

    $attributes = [ordered]@{}
    $entry = $Archive.GetEntry('META-INF/MANIFEST.MF')
    if ($null -eq $entry) {
        return $attributes
    }

    $lastKey = $null
    foreach ($rawLine in (Read-EntryText -Entry $entry).Split("`n")) {
        $line = $rawLine.TrimEnd("`r")
        if ($line.Length -eq 0) {
            $lastKey = $null
            continue
        }
        if ($line.StartsWith(' ') -and $null -ne $lastKey) {
            $attributes[$lastKey] = [string]$attributes[$lastKey] + $line.Substring(1)
            continue
        }
        $separator = $line.IndexOf(':')
        if ($separator -le 0) {
            continue
        }
        $lastKey = $line.Substring(0, $separator).Trim()
        $attributes[$lastKey] = $line.Substring($separator + 1).Trim()
    }
    return $attributes
}

function New-ByteReader {
    param([byte[]]$Bytes)
    return @{ Bytes = $Bytes; Position = 0 }
}

function Read-U1 {
    param($Reader)
    $value = [int]$Reader.Bytes[$Reader.Position]
    $Reader.Position++
    return $value
}

function Read-U2 {
    param($Reader)
    $value = ([int]$Reader.Bytes[$Reader.Position] -shl 8) -bor [int]$Reader.Bytes[$Reader.Position + 1]
    $Reader.Position += 2
    return $value
}

function Read-U4 {
    param($Reader)
    $value = ([int64]$Reader.Bytes[$Reader.Position] -shl 24) -bor ([int64]$Reader.Bytes[$Reader.Position + 1] -shl 16) -bor ([int64]$Reader.Bytes[$Reader.Position + 2] -shl 8) -bor [int64]$Reader.Bytes[$Reader.Position + 3]
    $Reader.Position += 4
    return $value
}

function Read-ConstantPool {
    param($Reader)

    $count = Read-U2 $Reader
    $pool = New-Object object[] ([Math]::Max($count, 1))
    $index = 1
    while ($index -lt $count) {
        $tag = Read-U1 $Reader
        switch ($tag) {
            1 {
                $length = Read-U2 $Reader
                $pool[$index] = $Utf8.GetString($Reader.Bytes, $Reader.Position, $length)
                $Reader.Position += $length
            }
            3 {
                $pool[$index] = [int](Read-U4 $Reader)
            }
            4 { $Reader.Position += 4 }
            5 { $Reader.Position += 8; $index++ }
            6 { $Reader.Position += 8; $index++ }
            7 { $Reader.Position += 2 }
            8 { $Reader.Position += 2 }
            9 { $Reader.Position += 4 }
            10 { $Reader.Position += 4 }
            11 { $Reader.Position += 4 }
            12 { $Reader.Position += 4 }
            15 { $Reader.Position += 3 }
            16 { $Reader.Position += 2 }
            17 { $Reader.Position += 4 }
            18 { $Reader.Position += 4 }
            19 { $Reader.Position += 2 }
            20 { $Reader.Position += 2 }
            default { throw "Unknown constant pool tag $tag at byte $($Reader.Position - 1)." }
        }
        $index++
    }
    return , $pool
}

function Read-ElementValue {
    param($Reader, [object[]]$Pool)

    $tag = [string][char](Read-U1 $Reader)
    switch -CaseSensitive ($tag) {
        's' { return [string]$Pool[(Read-U2 $Reader)] }
        'Z' { return ([int]$Pool[(Read-U2 $Reader)] -ne 0) }
        'B' { return [int]$Pool[(Read-U2 $Reader)] }
        'C' { return [int]$Pool[(Read-U2 $Reader)] }
        'I' { return [int]$Pool[(Read-U2 $Reader)] }
        'S' { return [int]$Pool[(Read-U2 $Reader)] }
        'J' { $null = Read-U2 $Reader; return $null }
        'F' { $null = Read-U2 $Reader; return $null }
        'D' { $null = Read-U2 $Reader; return $null }
        'e' {
            $null = Read-U2 $Reader
            return [string]$Pool[(Read-U2 $Reader)]
        }
        'c' { return [string]$Pool[(Read-U2 $Reader)] }
        '@' { return Read-Annotation -Reader $Reader -Pool $Pool }
        '[' {
            $count = Read-U2 $Reader
            $values = New-Object 'System.Collections.Generic.List[object]'
            for ($item = 0; $item -lt $count; $item++) {
                $values.Add((Read-ElementValue -Reader $Reader -Pool $Pool))
            }
            return , $values.ToArray()
        }
        default { throw "Unknown annotation element tag '$tag'." }
    }
}

function Read-Annotation {
    param($Reader, [object[]]$Pool)

    $type = [string]$Pool[(Read-U2 $Reader)]
    $pairCount = Read-U2 $Reader
    $elements = [ordered]@{}
    for ($pair = 0; $pair -lt $pairCount; $pair++) {
        $name = [string]$Pool[(Read-U2 $Reader)]
        $elements[$name] = Read-ElementValue -Reader $Reader -Pool $Pool
    }
    return [pscustomobject]@{
        Type = $type
        Elements = $elements
    }
}

function Read-ClassModAnnotations {
    # Walks one class file far enough to reach the class-level RuntimeVisibleAnnotations
    # attribute and returns every @Mod annotation found there.
    param([byte[]]$Bytes)

    $found = New-Object 'System.Collections.Generic.List[object]'
    if ($Bytes.Length -lt 24 -or $Bytes[0] -ne 0xCA -or $Bytes[1] -ne 0xFE -or $Bytes[2] -ne 0xBA -or $Bytes[3] -ne 0xBE) {
        return , $found.ToArray()
    }

    $reader = New-ByteReader -Bytes $Bytes
    $reader.Position = 8
    $pool = Read-ConstantPool -Reader $reader
    $reader.Position += 6
    $interfaceCount = Read-U2 $reader
    $reader.Position += 2 * $interfaceCount
    for ($round = 0; $round -lt 2; $round++) {
        $memberCount = Read-U2 $reader
        for ($member = 0; $member -lt $memberCount; $member++) {
            $reader.Position += 6
            $attributeCount = Read-U2 $reader
            for ($attribute = 0; $attribute -lt $attributeCount; $attribute++) {
                $reader.Position += 2
                $length = Read-U4 $reader
                $reader.Position += $length
            }
        }
    }

    $attributeCount = Read-U2 $reader
    for ($attribute = 0; $attribute -lt $attributeCount; $attribute++) {
        $nameIndex = Read-U2 $reader
        $length = Read-U4 $reader
        $start = $reader.Position
        if ([string]$pool[$nameIndex] -eq 'RuntimeVisibleAnnotations') {
            $annotationCount = Read-U2 $reader
            for ($item = 0; $item -lt $annotationCount; $item++) {
                $annotation = Read-Annotation -Reader $reader -Pool $pool
                if ($annotation.Type -eq $ModAnnotationType) {
                    $found.Add($annotation)
                }
            }
        }
        $reader.Position = $start + $length
    }
    return , $found.ToArray()
}

function Get-ModAnnotations {
    param([IO.Compression.ZipArchive]$Archive)

    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($entry in $Archive.Entries) {
        if (-not $entry.FullName.EndsWith('.class', [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $bytes = Read-EntryBytes -Entry $entry
        if ($Latin1.GetString($bytes).IndexOf($ModAnnotationType, [StringComparison]::Ordinal) -lt 0) {
            continue
        }
        try {
            foreach ($annotation in (Read-ClassModAnnotations -Bytes $bytes)) {
                $results.Add([pscustomobject]@{
                    Class = $entry.FullName
                    Elements = $annotation.Elements
                })
            }
        }
        catch {
            $results.Add([pscustomobject]@{
                Class = $entry.FullName
                Elements = [ordered]@{ parseError = $_.Exception.Message }
            })
        }
    }
    return , $results.ToArray()
}

function ConvertFrom-DependencyTarget {
    param([string]$Target, [string]$Instruction, [string]$Origin)

    $modId = $Target
    $range = ''
    $at = $Target.IndexOf('@')
    if ($at -ge 0) {
        $modId = $Target.Substring(0, $at)
        $range = $Target.Substring($at + 1)
    }
    $normalizedInstruction = $Instruction.Trim().ToLowerInvariant()
    return [ordered]@{
        instruction = $normalizedInstruction
        modId = $modId.Trim()
        range = $range.Trim()
        required = $normalizedInstruction.StartsWith('required')
        known = ($KnownInstructions -contains $normalizedInstruction)
        origin = $Origin
    }
}

function ConvertFrom-DependencyString {
    # Parses the @Mod dependencies grammar: instruction:modid[@range] segments separated by
    # semicolons. A wildcard target (*) is kept as written.
    param([string]$Value, [string]$Origin)

    $dependencies = New-Object 'System.Collections.Generic.List[object]'
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return , $dependencies.ToArray()
    }
    foreach ($segment in $Value.Split(';')) {
        $trimmed = $segment.Trim()
        if ($trimmed.Length -eq 0) { continue }
        $separator = $trimmed.IndexOf(':')
        if ($separator -le 0) {
            $dependencies.Add([ordered]@{ instruction = '(malformed)'; modId = $trimmed; range = ''; required = $false; known = $false; origin = $Origin })
            continue
        }
        $dependencies.Add((ConvertFrom-DependencyTarget -Target $trimmed.Substring($separator + 1) -Instruction $trimmed.Substring(0, $separator) -Origin $Origin))
    }
    return , $dependencies.ToArray()
}

function ConvertFrom-ModInfoDependencies {
    param([object]$ModInfoEntry)

    $dependencies = New-Object 'System.Collections.Generic.List[object]'
    $required = @{}
    foreach ($target in $ModInfoEntry.requiredMods) {
        $parsed = ConvertFrom-DependencyTarget -Target $target -Instruction 'required-after' -Origin 'mcmod.info requiredMods'
        $required[$parsed.modId] = $true
        $dependencies.Add($parsed)
    }
    foreach ($target in $ModInfoEntry.dependencies) {
        $parsed = ConvertFrom-DependencyTarget -Target $target -Instruction 'after' -Origin 'mcmod.info dependencies'
        if (-not $required.ContainsKey($parsed.modId)) { $dependencies.Add($parsed) }
    }
    foreach ($target in $ModInfoEntry.dependants) {
        $parsed = ConvertFrom-DependencyTarget -Target $target -Instruction 'before' -Origin 'mcmod.info dependants'
        if (-not $required.ContainsKey($parsed.modId)) { $dependencies.Add($parsed) }
    }
    return , $dependencies.ToArray()
}

function Get-JarMods {
    # Combines the @Mod annotations with mcmod.info the way FML 1.12.2 does: a mod exists
    # where @Mod exists; mcmod.info supplies name and version only when the annotation asks for
    # it (useMetadata) or leaves the field empty; dependency lists come from mcmod.info only
    # when useMetadata is set and mcmod.info says useDependencyInformation, otherwise from the
    # annotation's dependencies string.
    param([object]$ModInfo, [object[]]$Annotations, [bool]$ClassesScanned)

    $mods = New-Object 'System.Collections.Generic.List[object]'
    $matchedInfo = @{}

    foreach ($annotation in $Annotations) {
        $elements = $annotation.Elements
        if ($elements.Contains('parseError')) {
            $mods.Add([ordered]@{
                modId = '(unreadable)'
                name = ''
                version = ''
                versionSource = ''
                class = $annotation.Class
                useMetadata = $false
                dependencySource = ''
                dependencies = @()
                note = "class could not be parsed: $($elements['parseError'])"
            })
            continue
        }

        $modId = ''
        if ($elements.Contains('modid')) { $modId = [string]$elements['modid'] }
        $useMetadata = $false
        if ($elements.Contains('useMetadata')) { $useMetadata = [bool]$elements['useMetadata'] }
        $annotationVersion = ''
        if ($elements.Contains('version')) { $annotationVersion = [string]$elements['version'] }
        $annotationName = ''
        if ($elements.Contains('name')) { $annotationName = [string]$elements['name'] }
        $annotationDependencies = ''
        if ($elements.Contains('dependencies')) { $annotationDependencies = [string]$elements['dependencies'] }

        $infoEntry = $null
        foreach ($candidate in $ModInfo.mods) {
            if ($candidate.modid -eq $modId) { $infoEntry = $candidate; break }
        }
        if ($null -ne $infoEntry) { $matchedInfo[$modId] = $true }

        $version = $annotationVersion
        $versionSource = '@Mod version'
        if ([string]::IsNullOrWhiteSpace($version) -and $null -ne $infoEntry -and -not [string]::IsNullOrWhiteSpace($infoEntry.version)) {
            $version = $infoEntry.version
            $versionSource = 'mcmod.info version'
        }
        if ([string]::IsNullOrWhiteSpace($version)) {
            $version = ''
            $versionSource = '(none)'
        }

        $name = $annotationName
        if ($useMetadata -and $null -ne $infoEntry -and -not [string]::IsNullOrWhiteSpace($infoEntry.name)) {
            $name = $infoEntry.name
        }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $modId }

        if ($useMetadata -and $null -ne $infoEntry -and $infoEntry.useDependencyInformation) {
            $dependencies = ConvertFrom-ModInfoDependencies -ModInfoEntry $infoEntry
            $dependencySource = 'mcmod.info (useMetadata and useDependencyInformation)'
        }
        else {
            $dependencies = ConvertFrom-DependencyString -Value $annotationDependencies -Origin '@Mod dependencies'
            $dependencySource = '@Mod dependencies'
            if ($null -ne $infoEntry -and $infoEntry.useDependencyInformation -and -not $useMetadata) {
                $dependencySource = '@Mod dependencies (mcmod.info sets useDependencyInformation, but @Mod does not set useMetadata, so FML ignores it)'
            }
        }

        $mods.Add([ordered]@{
            modId = $modId
            name = $name
            version = $version
            versionSource = $versionSource
            class = $annotation.Class
            useMetadata = $useMetadata
            dependencySource = $dependencySource
            dependencies = @($dependencies)
            note = ''
        })
    }

    foreach ($infoEntry in $ModInfo.mods) {
        if ($matchedInfo.ContainsKey($infoEntry.modid)) { continue }
        $note = 'declared in mcmod.info only; no @Mod class carries this id, so FML does not load it as a mod'
        if (-not $ClassesScanned) {
            $note = 'from mcmod.info; classes were not scanned, so the @Mod data is unknown'
        }
        $mods.Add([ordered]@{
            modId = $infoEntry.modid
            name = $infoEntry.name
            version = $infoEntry.version
            versionSource = 'mcmod.info version'
            class = ''
            useMetadata = $false
            dependencySource = 'mcmod.info lists'
            dependencies = ConvertFrom-ModInfoDependencies -ModInfoEntry $infoEntry
            note = $note
            declaredOnly = $ClassesScanned
        })
    }

    return , $mods.ToArray()
}

function Get-AssetSummary {
    param([IO.Compression.ZipArchive]$Archive)

    $domains = @{}
    $classes = 0
    $resources = 0
    $recipes = 0
    $itemModels = 0
    $blockstates = 0
    $langFiles = 0
    $mixinConfigs = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in $Archive.Entries) {
        $name = $entry.FullName
        if ($name.EndsWith('/')) { continue }
        if ($name.EndsWith('.class', [StringComparison]::OrdinalIgnoreCase)) { $classes++; continue }
        $resources++
        if ($name -match '^assets/([^/]+)/') {
            $domains[$Matches[1]] = $true
            if ($name -match '^assets/[^/]+/recipes/.*\.json$') { $recipes++ }
            elseif ($name -match '^assets/[^/]+/models/item/[^/]+\.json$') { $itemModels++ }
            elseif ($name -match '^assets/[^/]+/blockstates/[^/]+\.json$') { $blockstates++ }
            elseif ($name -match '^assets/[^/]+/lang/[^/]+\.lang$') { $langFiles++ }
        }
        elseif ($name -match '^mixins[^/]*\.json$') {
            $mixinConfigs.Add($name)
        }
    }
    return [ordered]@{
        assetDomains = @($domains.Keys | Sort-Object)
        classes = $classes
        resources = $resources
        recipes = $recipes
        itemModels = $itemModels
        blockstates = $blockstates
        langFiles = $langFiles
        mixinConfigs = @($mixinConfigs.ToArray())
    }
}

function Get-JarInfo {
    param([string]$Path)

    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $modInfo = Read-ModInfo -Archive $archive
        $manifest = Read-Manifest -Archive $archive
        $annotations = @()
        if (-not $SkipClasses) {
            $annotations = Get-ModAnnotations -Archive $archive
        }
        $mods = Get-JarMods -ModInfo $modInfo -Annotations $annotations -ClassesScanned (-not $SkipClasses)
        $assets = Get-AssetSummary -Archive $archive
    }
    finally {
        $archive.Dispose()
    }

    $loaderAttributes = [ordered]@{}
    foreach ($key in $LoaderManifestKeys) {
        if ($manifest.Contains($key)) { $loaderAttributes[$key] = $manifest[$key] }
    }

    return [ordered]@{
        jar = $Path
        file = [IO.Path]::GetFileName($Path)
        bytes = [int64](Get-Item -LiteralPath $Path).Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
        mcmodInfo = $modInfo
        manifest = $manifest
        loaderAttributes = $loaderAttributes
        classesScanned = (-not $SkipClasses)
        mods = $mods
        assets = $assets
    }
}

function Format-Dependency {
    param([object]$Dependency)

    $text = "$($Dependency.instruction):$($Dependency.modId)"
    if ($Dependency.range.Length -gt 0) { $text += "@$($Dependency.range)" }
    return $text
}

function Write-JarInfo {
    param([object]$Info)

    Write-Output "Jar: $($Info.jar)"
    Write-Output "  size $($Info.bytes) bytes, sha256 $($Info.sha256)"
    switch ($Info.mcmodInfo.status) {
        'missing' { Write-Output '  mcmod.info: missing' }
        'invalid' { Write-Output "  mcmod.info: could not be parsed ($($Info.mcmodInfo.error))" }
        default {
            Write-Output "  mcmod.info: $($Info.mcmodInfo.mods.Count) entries"
            foreach ($entry in $Info.mcmodInfo.mods) {
                Write-Output "    $($entry.modid) '$($entry.name)' version '$($entry.version)' mcversion '$($entry.mcversion)' useDependencyInformation=$($entry.useDependencyInformation)"
                if ($entry.requiredMods.Count -gt 0) { Write-Output "      requiredMods: $($entry.requiredMods -join ', ')" }
                if ($entry.dependencies.Count -gt 0) { Write-Output "      dependencies: $($entry.dependencies -join ', ')" }
                if ($entry.dependants.Count -gt 0) { Write-Output "      dependants: $($entry.dependants -join ', ')" }
            }
        }
    }
    if ($Info.loaderAttributes.Count -gt 0) {
        $pairs = @($Info.loaderAttributes.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" })
        Write-Output "  manifest loader attributes: $($pairs -join '; ')"
    }
    else {
        Write-Output '  manifest loader attributes: none (not a coremod, tweaker, or mixin jar by manifest)'
    }
    if (-not $Info.classesScanned) {
        Write-Output '  @Mod annotations: not scanned (-SkipClasses)'
    }
    elseif ($Info.mods.Count -eq 0) {
        Write-Output '  @Mod annotations: none found (library, coremod-only, or not a Forge 1.12.2 mod)'
    }
    foreach ($mod in $Info.mods) {
        $classText = ''
        if ($mod.class.Length -gt 0) { $classText = " in $($mod.class)" }
        Write-Output "  mod $($mod.modId) '$($mod.name)' version '$($mod.version)' ($($mod.versionSource))$classText useMetadata=$($mod.useMetadata)"
        if ($mod.dependencies.Count -gt 0) {
            Write-Output "    dependencies from $($mod.dependencySource): $(@($mod.dependencies | ForEach-Object { Format-Dependency $_ }) -join '; ')"
        }
        else {
            Write-Output "    dependencies from $($mod.dependencySource): none"
        }
        if ($mod.note.Length -gt 0) { Write-Output "    note: $($mod.note)" }
    }
    $assets = $Info.assets
    Write-Output "  assets: domains $(@($assets.assetDomains) -join ', '); $($assets.classes) classes, $($assets.resources) resources, $($assets.recipes) recipes, $($assets.itemModels) item models, $($assets.blockstates) blockstates, $($assets.langFiles) lang files"
    if ($assets.mixinConfigs.Count -gt 0) {
        Write-Output "  mixin configs at the jar root: $($assets.mixinConfigs -join ', ')"
    }
}

function Add-ItemHit {
    param(
        [System.Collections.Generic.Dictionary[string,object]]$Hits,
        [string]$Id,
        [string]$Data,
        [string]$SourceName,
        [string]$Detail,
        [string]$Display
    )

    $key = "$SourceName|$Id|$Data|$Display"
    if ($Hits.ContainsKey($key)) {
        $Hits[$key].count++
        return
    }
    $Hits[$key] = [ordered]@{
        id = $Id
        data = $Data
        source = $SourceName
        display = $Display
        detail = $Detail
        count = 1
    }
}

function Get-JarItems {
    # Lists the ids a jar's own resources name, labeled by where they were read:
    #   recipe       an item field in a recipe JSON (a registry name the game resolves)
    #   recipe-ore   an ore-dictionary name in a recipe JSON
    #   advancement  an item field in an advancement JSON (a registry name)
    #   blockstate   a blockstates file name (usually the block registry name)
    #   model        an item model file name (an asset name; a variant model can differ)
    #   lang         an item, tile, or entity display-name key (an unlocalized name)
    param([string]$Path, [string[]]$Sources, [bool]$ParseJson)

    $hits = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $Archive.Entries) {
            $name = $entry.FullName
            if ($name -match '^assets/(?<domain>[^/]+)/blockstates/(?<name>[^/]+)\.json$') {
                if ($Sources -contains 'blockstate') { Add-ItemHit $hits "$($Matches.domain):$($Matches.name)" '' 'blockstate' $name '' }
                continue
            }
            if ($name -match '^assets/(?<domain>[^/]+)/models/item/(?<name>[^/]+)\.json$') {
                if ($Sources -contains 'model') { Add-ItemHit $hits "$($Matches.domain):$($Matches.name)" '' 'model' $name '' }
                continue
            }
            if ($name -match '^assets/(?<domain>[^/]+)/lang/en_us\.lang$' -or $name -match '^assets/(?<domain>[^/]+)/lang/en_US\.lang$') {
                if ($Sources -contains 'lang') {
                    foreach ($rawLine in (Read-EntryText -Entry $entry).Split("`n")) {
                        $line = $rawLine.Trim()
                        if ($line -match '^(?<key>(?:item|tile|entity)\.(?<body>.+?)\.name)=(?<value>.*)$') {
                            Add-ItemHit $hits $Matches.body '' 'lang' "$name $($Matches.key)" $Matches.value.Trim()
                        }
                    }
                }
                continue
            }
            if (-not $ParseJson) { continue }
            $sourceName = $null
            if ($name -match '^assets/[^/]+/recipes/.*\.json$' -and -not $name.EndsWith('/_factories.json')) { $sourceName = 'recipe' }
            elseif ($name -match '^assets/[^/]+/advancements/.*\.json$') { $sourceName = 'advancement' }
            if ($null -eq $sourceName) { continue }
            if (($Sources -notcontains $sourceName) -and -not ($sourceName -eq 'recipe' -and $Sources -contains 'recipe-ore')) { continue }

            $text = Read-EntryText -Entry $entry
            $dataByPosition = @{}
            foreach ($match in $ItemDataRegex.Matches($text)) { $dataByPosition[$match.Groups['item'].Index] = $match.Groups['data'].Value }
            foreach ($match in $DataItemRegex.Matches($text)) { $dataByPosition[$match.Groups['item'].Index] = $match.Groups['data'].Value }
            if ($Sources -contains $sourceName) {
                foreach ($match in $ItemRegex.Matches($text)) {
                    $id = $match.Groups['item'].Value
                    if ($id.IndexOf(':') -lt 0) { $id = "minecraft:$id" }
                    $data = ''
                    if ($dataByPosition.ContainsKey($match.Groups['item'].Index)) { $data = $dataByPosition[$match.Groups['item'].Index] }
                    Add-ItemHit $hits $id $data $sourceName $name ''
                }
            }
            if ($sourceName -eq 'recipe' -and $Sources -contains 'recipe-ore') {
                foreach ($match in $OreRegex.Matches($text)) {
                    Add-ItemHit $hits $match.Groups['ore'].Value '' 'recipe-ore' $name ''
                }
            }
        }
    }
    finally {
        $archive.Dispose()
    }
    return , @($hits.Values)
}

function Get-SourceSelection {
    $all = @('recipe', 'recipe-ore', 'advancement', 'blockstate', 'model', 'lang')
    $selected = @(Split-List -Value $Source | ForEach-Object { $_.ToLowerInvariant() })
    if ($selected.Count -eq 0) { return $all }
    foreach ($item in $selected) {
        if ($all -notcontains $item) { throw "-Source accepts $($all -join ', '); '$item' is not one of them." }
    }
    return $selected
}

function Format-ItemHit {
    param([object]$Hit, [string]$JarName)

    $dataText = ''
    if ($Hit.data.Length -gt 0) { $dataText = " data $($Hit.data)" }
    $displayText = ''
    if ($Hit.display.Length -gt 0) { $displayText = " '$($Hit.display)'" }
    $countText = ''
    if ($Hit.count -gt 1) { $countText = " (x$($Hit.count))" }
    $jarText = ''
    if ($JarName.Length -gt 0) { $jarText = " [$JarName]" }
    return "$($Hit.source): $($Hit.id)$dataText$displayText  <- $($Hit.detail)$countText$jarText"
}

function ConvertFrom-VersionRange {
    # Parses a Maven-style range specification into bounds. A bare version means that
    # version or newer, which is how FML treats "modid@1.0".
    param([string]$Specification)

    $ranges = New-Object 'System.Collections.Generic.List[object]'
    $trimmed = $Specification.Trim()
    if ($trimmed.Length -eq 0) {
        return , $ranges.ToArray()
    }
    if ($trimmed.IndexOfAny([char[]]@('[', '(')) -lt 0) {
        $ranges.Add([ordered]@{ lower = $trimmed; lowerInclusive = $true; upper = ''; upperInclusive = $false; text = $trimmed })
        return , $ranges.ToArray()
    }
    foreach ($match in [regex]::Matches($trimmed, '(?<open>[\[\(])(?<body>[^\]\)]*)(?<close>[\]\)])')) {
        $body = $match.Groups['body'].Value
        $parts = $body.Split(',')
        if ($parts.Count -eq 1) {
            $ranges.Add([ordered]@{ lower = $parts[0].Trim(); lowerInclusive = $true; upper = $parts[0].Trim(); upperInclusive = $true; text = $match.Value })
        }
        elseif ($parts.Count -eq 2) {
            $ranges.Add([ordered]@{
                lower = $parts[0].Trim()
                lowerInclusive = ($match.Groups['open'].Value -eq '[')
                upper = $parts[1].Trim()
                upperInclusive = ($match.Groups['close'].Value -eq ']')
                text = $match.Value
            })
        }
        else {
            throw "Version range '$Specification' is not understood."
        }
    }
    if ($ranges.Count -eq 0) {
        throw "Version range '$Specification' is not understood."
    }
    return , $ranges.ToArray()
}

function Compare-ModVersion {
    # Basic ordering: numeric tokens compare as numbers, other tokens as text; a trailing
    # qualifier (1.0-beta) sorts before the plain version, a trailing zero (1.0.0) equals it.
    param([string]$Left, [string]$Right)

    $leftTokens = @($Left.Split([char[]]@('.', '-', '_', '+')) | Where-Object { $_.Length -gt 0 })
    $rightTokens = @($Right.Split([char[]]@('.', '-', '_', '+')) | Where-Object { $_.Length -gt 0 })
    $length = [Math]::Max($leftTokens.Count, $rightTokens.Count)
    for ($index = 0; $index -lt $length; $index++) {
        $leftToken = $null
        $rightToken = $null
        if ($index -lt $leftTokens.Count) { $leftToken = $leftTokens[$index] }
        if ($index -lt $rightTokens.Count) { $rightToken = $rightTokens[$index] }
        $leftNumber = 0
        $rightNumber = 0
        $leftNumeric = ($null -ne $leftToken) -and [int64]::TryParse($leftToken, [ref]$leftNumber)
        $rightNumeric = ($null -ne $rightToken) -and [int64]::TryParse($rightToken, [ref]$rightNumber)

        if ($null -eq $leftToken) {
            if ($rightNumeric) { if ($rightNumber -eq 0) { continue } else { return -1 } }
            return 1
        }
        if ($null -eq $rightToken) {
            if ($leftNumeric) { if ($leftNumber -eq 0) { continue } else { return 1 } }
            return -1
        }
        if ($leftNumeric -and $rightNumeric) {
            if ($leftNumber -lt $rightNumber) { return -1 }
            if ($leftNumber -gt $rightNumber) { return 1 }
            continue
        }
        if ($leftNumeric) { return 1 }
        if ($rightNumeric) { return -1 }
        $textOrder = [string]::Compare($leftToken, $rightToken, [StringComparison]::OrdinalIgnoreCase)
        if ($textOrder -ne 0) { return [Math]::Sign($textOrder) }
    }
    return 0
}

function Test-VersionInRange {
    param([string]$Version, [object[]]$Ranges)

    foreach ($range in $Ranges) {
        $inside = $true
        if ($range.lower.Length -gt 0) {
            $order = Compare-ModVersion -Left $Version -Right $range.lower
            if ($order -lt 0 -or ($order -eq 0 -and -not $range.lowerInclusive)) { $inside = $false }
        }
        if ($inside -and $range.upper.Length -gt 0) {
            $order = Compare-ModVersion -Left $Version -Right $range.upper
            if ($order -gt 0 -or ($order -eq 0 -and -not $range.upperInclusive)) { $inside = $false }
        }
        if ($inside) { return $true }
    }
    return $false
}

function Invoke-Check {
    param([string[]]$Paths)

    $infos = New-Object 'System.Collections.Generic.List[object]'
    foreach ($path in $Paths) {
        Write-Verbose "Reading $path"
        $infos.Add((Get-JarInfo -Path $path))
    }

    $providedIds = @(Split-List -Value $Provided | ForEach-Object { $_.Trim() })
    $providers = @{}
    foreach ($id in $BuiltInModIds) { $providers[$id.ToLowerInvariant()] = @([ordered]@{ jar = '(built in)'; version = '' }) }
    foreach ($id in $providedIds) { $providers[$id.ToLowerInvariant()] = @([ordered]@{ jar = '(provided by the environment)'; version = '' }) }

    $problems = New-Object 'System.Collections.Generic.List[string]'
    $notes = New-Object 'System.Collections.Generic.List[string]'
    $loadedMods = New-Object 'System.Collections.Generic.List[object]'

    foreach ($info in $infos) {
        $realMods = @($info.mods | Where-Object { $_.class.Length -gt 0 -or -not $info.classesScanned })
        if ($realMods.Count -eq 0) {
            $reason = 'no @Mod class and no mcmod.info entry'
            if ($info.loaderAttributes.Count -gt 0) { $reason = "no mod id; manifest $(@($info.loaderAttributes.Keys) -join ', ')" }
            $notes.Add("no mod id found: $($info.file) ($reason)")
        }
        if ($info.loaderAttributes.Contains('FMLCorePlugin') -or $info.loaderAttributes.Contains('MixinConfigs') -or $info.loaderAttributes.Contains('TweakClass') -or $info.assets.mixinConfigs.Count -gt 0) {
            $notes.Add("coremod, tweaker, or mixin jar: $($info.file); a development runtime that already has this mod on its classpath refuses the copy as a duplicate")
        }
        if ($info.mcmodInfo.status -eq 'invalid') {
            $notes.Add("mcmod.info could not be parsed in $($info.file): $($info.mcmodInfo.error)")
        }
        foreach ($mod in $realMods) {
            if ($mod.modId.Length -eq 0 -or $mod.modId -eq '(unreadable)') {
                $notes.Add("a @Mod class without a readable modid in $($info.file): $($mod.class) $($mod.note)")
                continue
            }
            $key = $mod.modId.ToLowerInvariant()
            $record = [ordered]@{ jar = $info.file; version = $mod.version }
            if ($providers.ContainsKey($key)) {
                $providers[$key] = @($providers[$key]) + @($record)
            }
            else {
                $providers[$key] = @($record)
            }
            $loadedMods.Add([ordered]@{ jar = $info.file; mod = $mod })
        }
    }

    foreach ($key in ($providers.Keys | Sort-Object)) {
        $sources = @($providers[$key])
        if ($sources.Count -gt 1) {
            $problems.Add("DUPLICATE mod id '$key' is provided by $(@($sources | ForEach-Object { $_.jar }) -join ' and ')")
        }
    }

    foreach ($loaded in $loadedMods) {
        foreach ($dependency in $loaded.mod.dependencies) {
            if (-not $dependency.known) {
                $notes.Add("unknown dependency instruction '$($dependency.instruction)' in $($loaded.jar) ($($loaded.mod.modId)): $(Format-Dependency $dependency)")
                continue
            }
            $targetKey = $dependency.modId.ToLowerInvariant()
            if ($targetKey -eq '*' -or $targetKey.Length -eq 0) { continue }
            $present = $providers.ContainsKey($targetKey)
            if (-not $present) {
                if ($dependency.required) {
                    $problems.Add("MISSING '$($dependency.modId)' required by $($loaded.mod.modId) ($($loaded.jar)) as $(Format-Dependency $dependency)")
                }
                continue
            }
            if ($dependency.range.Length -eq 0) { continue }
            $providerVersion = ''
            foreach ($source in @($providers[$targetKey])) {
                if ($source.version.Length -gt 0) { $providerVersion = $source.version; break }
            }
            if ($providerVersion.Length -eq 0) {
                if ($dependency.required -and $targetKey -notin $BuiltInModIds -and $providedIds -notcontains $dependency.modId) {
                    $notes.Add("version of '$($dependency.modId)' is unknown, so the range $($dependency.range) required by $($loaded.mod.modId) was not compared")
                }
                continue
            }
            try {
                $ranges = ConvertFrom-VersionRange -Specification $dependency.range
            }
            catch {
                $notes.Add("range '$($dependency.range)' for '$($dependency.modId)' in $($loaded.jar) was not compared: $($_.Exception.Message)")
                continue
            }
            if (-not (Test-VersionInRange -Version $providerVersion -Ranges $ranges)) {
                $message = "VERSION '$($dependency.modId)' $providerVersion is outside $($dependency.range) wanted by $($loaded.mod.modId) ($($loaded.jar)) as $(Format-Dependency $dependency); basic comparison"
                if ($dependency.required) { $problems.Add($message) } else { $notes.Add($message) }
            }
        }
    }

    $result = [ordered]@{
        toolVersion = $ToolVersion
        jars = @($infos | ForEach-Object { $_.file })
        provided = @($providedIds)
        mods = @($loadedMods | ForEach-Object { [ordered]@{ jar = $_.jar; modId = $_.mod.modId; version = $_.mod.version; dependencySource = $_.mod.dependencySource; dependencies = @($_.mod.dependencies | ForEach-Object { Format-Dependency $_ }) } })
        problems = @($problems.ToArray())
        notes = @($notes.ToArray())
    }

    if ($Json) {
        Write-Output (ConvertTo-Json -InputObject $result -Depth 8)
    }
    else {
        Write-Output "Jars checked: $($infos.Count)"
        if ($providedIds.Count -gt 0) { Write-Output "Provided by the environment: $($providedIds -join ', ')" }
        foreach ($loaded in $loadedMods) {
            $required = @($loaded.mod.dependencies | Where-Object { $_.required } | ForEach-Object { Format-Dependency $_ })
            $requiredText = 'none'
            if ($required.Count -gt 0) { $requiredText = $required -join '; ' }
            Write-Output "  $($loaded.jar) -> $($loaded.mod.modId) $($loaded.mod.version) (requires: $requiredText)"
        }
        Write-Output "Problems: $($problems.Count)"
        foreach ($problem in $problems) { Write-Output "  $problem" }
        Write-Output "Notes: $($notes.Count)"
        foreach ($note in $notes) { Write-Output "  $note" }
        if ($problems.Count -eq 0) { Write-Output 'Result: OK, every required mod is present and no mod id is duplicated' }
        else { Write-Output "Result: $($problems.Count) problem(s); a launch with this set fails or refuses to load" }
    }

    if ($Strict -and $problems.Count -gt 0) {
        throw "Dependency check found $($problems.Count) problem(s)."
    }
}

$paths = @(Get-JarList)

switch ($Action) {
    'info' {
        $infos = @($paths | ForEach-Object { Get-JarInfo -Path $_ })
        if ($Json) {
            Write-Output (ConvertTo-Json -InputObject @($infos) -Depth 10)
        }
        else {
            foreach ($info in $infos) { Write-JarInfo -Info $info }
        }
    }
    'items' {
        $sources = @(Get-SourceSelection)
        $all = New-Object 'System.Collections.Generic.List[object]'
        foreach ($path in $paths) {
            $jarName = [IO.Path]::GetFileName($path)
            foreach ($hit in (Get-JarItems -Path $path -Sources $sources -ParseJson $true)) {
                $hit['jar'] = $jarName
                $all.Add($hit)
            }
        }
        if ($Json) {
            Write-Output (ConvertTo-Json -InputObject @($all.ToArray()) -Depth 6)
        }
        else {
            Write-Output "Ids found: $($all.Count) (sources: $($sources -join ', '))"
            foreach ($sourceName in $sources) {
                $group = @($all | Where-Object { $_.source -eq $sourceName } | Sort-Object { $_.id }, { $_.data })
                if ($group.Count -eq 0) { continue }
                Write-Output "[$sourceName] $($group.Count)"
                foreach ($hit in $group) {
                    $jarLabel = ''
                    if ($paths.Count -gt 1) { $jarLabel = $hit.jar }
                    Write-Output "  $(Format-ItemHit -Hit $hit -JarName $jarLabel)"
                }
            }
        }
    }
    'find' {
        if ([string]::IsNullOrWhiteSpace($Text)) {
            throw 'find needs -Text <substring>; it is matched against ids, display names, and resource paths without case.'
        }
        $sources = @(Get-SourceSelection)
        $parseJson = $IncludeRecipes -or [string]::IsNullOrWhiteSpace($Folder)
        $matches = New-Object 'System.Collections.Generic.List[object]'
        $modMatches = New-Object 'System.Collections.Generic.List[string]'
        foreach ($path in $paths) {
            $jarName = [IO.Path]::GetFileName($path)
            foreach ($hit in (Get-JarItems -Path $path -Sources $sources -ParseJson $parseJson)) {
                $matched = $hit.id.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                    $hit.display.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                    $hit.detail.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0
                if ($matched) {
                    $hit['jar'] = $jarName
                    $matches.Add($hit)
                }
            }
        }
        if ($Json) {
            Write-Output (ConvertTo-Json -InputObject @($matches.ToArray()) -Depth 6)
        }
        else {
            $scopeText = 'file names, lang keys, recipe and advancement fields'
            if (-not $parseJson) { $scopeText = 'file names and lang keys only; add -IncludeRecipes to read recipe and advancement JSON across the folder' }
            Write-Output "Searched $($paths.Count) jar(s) for '$Text' ($scopeText)"
            Write-Output "Matches: $($matches.Count)"
            $order = @('recipe', 'advancement', 'blockstate', 'lang', 'model', 'recipe-ore')
            foreach ($sourceName in $order) {
                foreach ($hit in @($matches | Where-Object { $_.source -eq $sourceName } | Sort-Object { $_.jar }, { $_.id })) {
                    Write-Output "  $(Format-ItemHit -Hit $hit -JarName $hit.jar)"
                }
            }
            if ($matches.Count -gt 0) {
                Write-Output 'Reading the labels: recipe and advancement hits are registry names the game resolves; a blockstate name is usually the block registry name; a lang key is an unlocalized name; a model name is only an asset name and can differ from the registry name.'
            }
        }
    }
    'check' {
        Invoke-Check -Paths $paths
    }
}

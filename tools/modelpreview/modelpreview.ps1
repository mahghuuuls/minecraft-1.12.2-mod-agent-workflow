#requires -Version 5.1
<#
.SYNOPSIS
Renders a Minecraft 1.12.2 block model JSON to orthographic PNG views and checks the 1.12 format
rules, so an agent can see the model it wrote without opening Blockbench or the game.

.DESCRIPTION
Dependency-free on Windows PowerShell 5.1: the rasterizer is a small C# class compiled in memory
by Add-Type (the C# compiler ships with the .NET Framework), textures are read with the
System.Drawing decoder, and the PNG is written by hand. Parents are resolved from the mod's
assets folder and from the vanilla 1.12.2 client jar. Views are orthographic; the GUI view uses
the vanilla inventory angle (a look from the north-west, 30 degrees above), so the top, north,
and west faces show, as they do in the creative inventory.

What it cannot do: perspective, lighting other than the vanilla per-direction shade, block
tint (tintindex faces render untinted), item models, and animated textures (the first frame).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ModelFile,

    # A blockstate file and the variant key to read the model, x, and y from, instead of -ModelFile.
    [string]$Blockstate,
    [string]$Variant,

    # Blockstate rotations applied to the whole model, in 90 degree steps.
    [int]$RotateX = 0,
    [int]$RotateY = 0,

    # The folder that holds the namespace folders (".../src/main/resources/assets"). Derived
    # from the model path when it lies under such a folder.
    [string]$AssetsRoot,

    # The vanilla 1.12.2 client jar for "minecraft:" parents and textures. Found in the Gradle
    # cache or the launcher folder when not given.
    [string]$VanillaJar,

    # Pixels per block unit (a 16 unit face becomes Scale*16 pixels).
    [int]$Scale = 8,

    # Comma-separated views in order: gui, north, east, south, west, up, down.
    [string]$Views = 'gui,north,east,south,west,up,down',

    # #RRGGBB or #RRGGBBAA behind the model; transparent when omitted.
    [string]$Background,

    [string]$OutputFile,
    [string]$OutputDirectory,
    [switch]$Force,

    # Check the model and print the report without rendering.
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Errors = New-Object 'System.Collections.Generic.List[string]'
$script:Warnings = New-Object 'System.Collections.Generic.List[string]'
$script:Notes = New-Object 'System.Collections.Generic.List[string]'

function Add-Problem { param([string]$Kind, [string]$Text)
    switch ($Kind) {
        'error' { $script:Errors.Add($Text) }
        'warn' { $script:Warnings.Add($Text) }
        default { $script:Notes.Add($Text) }
    }
}

# ------------------------------------------------------------------ PNG writing (as tools/pixelart)

function Get-Adler32 { param([byte[]]$Bytes)
    [uint32]$a = 1; [uint32]$b = 0
    foreach ($value in $Bytes) { $a = [uint32](($a + $value) % 65521); $b = [uint32](($b + $a) % 65521) }
    return [uint32](($b -shl 16) -bor $a)
}

function Get-Crc32 { param([byte[]]$Bytes)
    [uint32]$crc = [uint32]::MaxValue
    foreach ($value in $Bytes) {
        $crc = $crc -bxor [uint32]$value
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1) -ne 0) { $crc = [uint32](($crc -shr 1) -bxor [uint32]3988292384) } else { $crc = [uint32]($crc -shr 1) }
        }
    }
    return [uint32]($crc -bxor [uint32]::MaxValue)
}

function Add-UInt32BigEndian { param([System.Collections.Generic.List[byte]]$Target, [uint32]$Value)
    $Target.Add([byte](($Value -shr 24) -band 0xFF)); $Target.Add([byte](($Value -shr 16) -band 0xFF))
    $Target.Add([byte](($Value -shr 8) -band 0xFF)); $Target.Add([byte]($Value -band 0xFF))
}

function Add-PngChunk { param([System.Collections.Generic.List[byte]]$Target, [string]$Type, [byte[]]$Data)
    $typeBytes = [Text.Encoding]::ASCII.GetBytes($Type)
    Add-UInt32BigEndian -Target $Target -Value ([uint32]$Data.Length)
    $Target.AddRange($typeBytes); $Target.AddRange($Data)
    $crcInput = New-Object byte[] ($typeBytes.Length + $Data.Length)
    [Array]::Copy($typeBytes, 0, $crcInput, 0, $typeBytes.Length)
    [Array]::Copy($Data, 0, $crcInput, $typeBytes.Length, $Data.Length)
    Add-UInt32BigEndian -Target $Target -Value (Get-Crc32 -Bytes $crcInput)
}

function Compress-Zlib { param([byte[]]$Bytes)
    $compressedStream = New-Object IO.MemoryStream
    $deflateStream = New-Object IO.Compression.DeflateStream($compressedStream, [IO.Compression.CompressionMode]::Compress, $true)
    try { $deflateStream.Write($Bytes, 0, $Bytes.Length) } finally { $deflateStream.Dispose() }
    $deflated = $compressedStream.ToArray(); $compressedStream.Dispose()
    $result = New-Object 'System.Collections.Generic.List[byte]'
    $result.Add(0x78); $result.Add(0x9C); $result.AddRange([byte[]]$deflated)
    Add-UInt32BigEndian -Target $result -Value (Get-Adler32 -Bytes $Bytes)
    return [byte[]]$result.ToArray()
}

function Write-PngFile { param([string]$Path, [int]$ImageWidth, [int]$ImageHeight, [byte[]]$Pixels)
    $rowBytes = $ImageWidth * 4; $stride = $rowBytes + 1
    $raw = New-Object byte[] ($stride * $ImageHeight)
    for ($y = 0; $y -lt $ImageHeight; $y++) { $raw[$y * $stride] = 0; [Array]::Copy($Pixels, $y * $rowBytes, $raw, ($y * $stride) + 1, $rowBytes) }
    $ihdr = New-Object 'System.Collections.Generic.List[byte]'
    Add-UInt32BigEndian -Target $ihdr -Value ([uint32]$ImageWidth); Add-UInt32BigEndian -Target $ihdr -Value ([uint32]$ImageHeight)
    $ihdr.Add(8); $ihdr.Add(6); $ihdr.Add(0); $ihdr.Add(0); $ihdr.Add(0)
    $png = New-Object 'System.Collections.Generic.List[byte]'
    $png.AddRange([byte[]]@(137, 80, 78, 71, 13, 10, 26, 10))
    Add-PngChunk -Target $png -Type 'IHDR' -Data ([byte[]]$ihdr.ToArray())
    Add-PngChunk -Target $png -Type 'IDAT' -Data (Compress-Zlib -Bytes ([byte[]]$raw))
    Add-PngChunk -Target $png -Type 'IEND' -Data ([byte[]]@())
    [IO.File]::WriteAllBytes($Path, [byte[]]$png.ToArray())
}

# ------------------------------------------------------------------ texture reading

function Read-PngPixels { param([byte[]]$Bytes, [string]$Label)
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $stream = New-Object IO.MemoryStream(, $Bytes)
    $bitmap = New-Object System.Drawing.Bitmap($stream)
    try {
        $imageWidth = [int]$bitmap.Width; $imageHeight = [int]$bitmap.Height
        $rectangle = New-Object System.Drawing.Rectangle(0, 0, $imageWidth, $imageHeight)
        $locked = $bitmap.LockBits($rectangle, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $stride = [int]$locked.Stride
            $buffer = New-Object byte[] ($stride * $imageHeight)
            [Runtime.InteropServices.Marshal]::Copy($locked.Scan0, $buffer, 0, $buffer.Length)
        } finally { $bitmap.UnlockBits($locked) }
    } finally { $bitmap.Dispose(); $stream.Dispose() }
    $pixels = New-Object byte[] ($imageWidth * $imageHeight * 4)
    for ($y = 0; $y -lt $imageHeight; $y++) {
        for ($x = 0; $x -lt $imageWidth; $x++) {
            $s = ($y * $stride) + ($x * 4); $t = (($y * $imageWidth) + $x) * 4
            $pixels[$t] = $buffer[$s + 2]; $pixels[$t + 1] = $buffer[$s + 1]; $pixels[$t + 2] = $buffer[$s]; $pixels[$t + 3] = $buffer[$s + 3]
        }
    }
    return [pscustomobject]@{ Width = $imageWidth; Height = $imageHeight; Pixels = $pixels; Label = $Label }
}

# ------------------------------------------------------------------ resource lookup

$script:VanillaZip = $null

function Find-VanillaJar {
    if ($VanillaJar) {
        if (-not (Test-Path -LiteralPath $VanillaJar)) { throw "Vanilla jar not found: $VanillaJar" }
        return $VanillaJar
    }
    $candidates = @(
        (Join-Path $env:USERPROFILE '.gradle\caches\retro_futura_gradle\mc-vanilla\1.12.2\client.jar'),
        (Join-Path $env:APPDATA '.minecraft\versions\1.12.2\1.12.2.jar')
    )
    foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate) { return $candidate } }
    return $null
}

function Get-VanillaEntryBytes { param([string]$EntryPath)
    if ($null -eq $script:VanillaZip) {
        $jar = Find-VanillaJar
        if (-not $jar) { return $null }
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        $script:VanillaZip = [IO.Compression.ZipFile]::OpenRead($jar)
        Add-Problem 'note' "Vanilla resources from $jar"
    }
    $entry = $script:VanillaZip.GetEntry($EntryPath)
    if ($null -eq $entry) { return $null }
    $stream = $entry.Open()
    try {
        $memory = New-Object IO.MemoryStream
        $stream.CopyTo($memory)
        return $memory.ToArray()
    } finally { $stream.Dispose() }
}

function Split-ResourceName { param([string]$Name, [string]$DefaultPath)
    # "elusiveflora:blocks/x" -> namespace elusiveflora, path blocks/x; "block/cross" -> minecraft.
    if ($Name -match '^([a-z0-9_.-]+):(.+)$') { return @($Matches[1], $Matches[2]) }
    return @('minecraft', $Name)
}

function Get-ResourceBytes { param([string]$Namespace, [string]$RelativePath)
    # RelativePath is below assets/<namespace>/, for example models/block/cross.json.
    if ($AssetsRoot) {
        $file = Join-Path (Join-Path $AssetsRoot $Namespace) $RelativePath
        if (Test-Path -LiteralPath $file) { return [IO.File]::ReadAllBytes($file) }
    }
    if ($Namespace -eq 'minecraft') {
        return Get-VanillaEntryBytes -EntryPath "assets/minecraft/$RelativePath"
    }
    return $null
}

function Read-ModelJson { param([string]$Namespace, [string]$Path)
    $bytes = Get-ResourceBytes -Namespace $Namespace -RelativePath "models/$Path.json"
    if ($null -eq $bytes) { return $null }
    return ([Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json)
}

# ------------------------------------------------------------------ model resolution

function Get-Prop { param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Resolve-Model {
    # Walks the parent chain. Textures: the child wins. Elements: the nearest model that has any.
    param([string]$Namespace, [string]$Path, [hashtable]$Textures, [ref]$Elements, [int]$Depth, [System.Collections.Generic.List[string]]$Chain)

    if ($Depth -gt 16) { Add-Problem 'error' "Parent chain deeper than 16 at ${Namespace}:$Path (a loop?)"; return }
    $model = Read-ModelJson -Namespace $Namespace -Path $Path
    if ($null -eq $model) { Add-Problem 'error' "Model not found: ${Namespace}:models/$Path.json"; return }
    $Chain.Add("${Namespace}:$Path")

    $textureMap = Get-Prop $model 'textures'
    if ($null -ne $textureMap) {
        foreach ($property in $textureMap.PSObject.Properties) {
            if (-not $Textures.ContainsKey($property.Name)) { $Textures[$property.Name] = [string]$property.Value }
        }
    }
    $ownElements = Get-Prop $model 'elements'
    if ($null -eq $Elements.Value -and $null -ne $ownElements) { $Elements.Value = @($ownElements) }

    $parent = Get-Prop $model 'parent'
    if ($parent) {
        $parts = Split-ResourceName -Name ([string]$parent)
        Resolve-Model -Namespace $parts[0] -Path $parts[1] -Textures $Textures -Elements $Elements -Depth ($Depth + 1) -Chain $Chain
    }
}

function Resolve-TextureVariable { param([hashtable]$Textures, [string]$Value, [string]$Origin)
    $seen = 0
    while ($Value.StartsWith('#')) {
        $key = $Value.Substring(1)
        if (-not $Textures.ContainsKey($key)) { Add-Problem 'error' "Texture variable '#$key' used by $Origin is not defined"; return $null }
        $Value = $Textures[$key]
        if (++$seen -gt 16) { Add-Problem 'error' "Texture variable loop at '#$key'"; return $null }
    }
    return $Value
}

$script:TextureCache = @{}

function Get-Texture { param([string]$Name, [string]$Origin)
    if ($script:TextureCache.ContainsKey($Name)) { return $script:TextureCache[$Name] }
    $parts = Split-ResourceName -Name $Name
    if ($parts[1] -notmatch '^(blocks|items)/') {
        Add-Problem 'warn' "Texture '$Name' ($Origin) has no 'blocks/' or 'items/' prefix; 1.12.2 looks for textures/$($parts[1]).png exactly"
    }
    $bytes = Get-ResourceBytes -Namespace $parts[0] -RelativePath "textures/$($parts[1]).png"
    if ($null -eq $bytes) {
        Add-Problem 'error' "Texture file not found: $($parts[0]):textures/$($parts[1]).png ($Origin)"
        $script:TextureCache[$Name] = $null
        return $null
    }
    $texture = Read-PngPixels -Bytes $bytes -Label $Name
    if ($texture.Width -ne $texture.Height) {
        # Animated textures stack square frames; only the first is drawn.
        if ($texture.Height % $texture.Width -eq 0) {
            Add-Problem 'note' "Texture '$Name' is $($texture.Width)x$($texture.Height): treated as $($texture.Height / $texture.Width) stacked frames, first frame drawn"
            $frame = New-Object byte[] ($texture.Width * $texture.Width * 4)
            [Array]::Copy($texture.Pixels, 0, $frame, 0, $frame.Length)
            $texture = [pscustomobject]@{ Width = $texture.Width; Height = $texture.Width; Pixels = $frame; Label = $Name }
        } else {
            Add-Problem 'error' "Texture '$Name' is $($texture.Width)x$($texture.Height): model textures must be square (or stacked square frames)"
        }
    }
    if (($texture.Width -band ($texture.Width - 1)) -ne 0) {
        Add-Problem 'warn' "Texture '$Name' is $($texture.Width) wide, not a power of two; mipmapping breaks on it"
    }
    $script:TextureCache[$Name] = $texture
    return $texture
}

# ------------------------------------------------------------------ geometry

function Get-Number { param($Value, [string]$What)
    try { return [double]$Value } catch { Add-Problem 'error' "$What is not a number: $Value"; return 0.0 }
}

function Get-DefaultUv { param([string]$Face, [double[]]$From, [double[]]$To)
    $x1 = $From[0]; $y1 = $From[1]; $z1 = $From[2]; $x2 = $To[0]; $y2 = $To[1]; $z2 = $To[2]
    switch ($Face) {
        'down' { return @($x1, (16 - $z2), $x2, (16 - $z1)) }
        'up' { return @($x1, $z1, $x2, $z2) }
        'north' { return @((16 - $x2), (16 - $y2), (16 - $x1), (16 - $y1)) }
        'south' { return @($x1, (16 - $y2), $x2, (16 - $y1)) }
        'west' { return @($z1, (16 - $y2), $z2, (16 - $y1)) }
        'east' { return @((16 - $z2), (16 - $y2), (16 - $z1), (16 - $y1)) }
    }
}

function Get-FaceCorners {
    # The face rectangle in element space as P00 (texture u1,v1), P10 (u2,v1), P01 (u1,v2): the
    # corner a texture corner lands on, in the vanilla orientation of each face.
    param([string]$Face, [double[]]$From, [double[]]$To)
    $x1 = $From[0]; $y1 = $From[1]; $z1 = $From[2]; $x2 = $To[0]; $y2 = $To[1]; $z2 = $To[2]
    switch ($Face) {
        'north' { return @(@($x2, $y2, $z1), @($x1, $y2, $z1), @($x2, $y1, $z1)) }
        'south' { return @(@($x1, $y2, $z2), @($x2, $y2, $z2), @($x1, $y1, $z2)) }
        'west' { return @(@($x1, $y2, $z1), @($x1, $y2, $z2), @($x1, $y1, $z1)) }
        'east' { return @(@($x2, $y2, $z2), @($x2, $y2, $z1), @($x2, $y1, $z2)) }
        'up' { return @(@($x1, $y2, $z1), @($x2, $y2, $z1), @($x1, $y2, $z2)) }
        'down' { return @(@($x1, $y1, $z2), @($x2, $y1, $z2), @($x1, $y1, $z1)) }
    }
}

function Rotate-Point { param([double[]]$P, [string]$Axis, [double]$Degrees, [double[]]$Origin, [double[]]$RescaleFactors)
    $r = $Degrees * [Math]::PI / 180.0; $c = [Math]::Cos($r); $s = [Math]::Sin($r)
    $x = $P[0] - $Origin[0]; $y = $P[1] - $Origin[1]; $z = $P[2] - $Origin[2]
    switch ($Axis) {
        'x' { $ny = $y * $c - $z * $s; $nz = $y * $s + $z * $c; $y = $ny; $z = $nz }
        'y' { $nx = $x * $c + $z * $s; $nz = -$x * $s + $z * $c; $x = $nx; $z = $nz }
        'z' { $nx = $x * $c - $y * $s; $ny = $x * $s + $y * $c; $x = $nx; $y = $ny }
    }
    if ($RescaleFactors) { $x *= $RescaleFactors[0]; $y *= $RescaleFactors[1]; $z *= $RescaleFactors[2] }
    return @(($x + $Origin[0]), ($y + $Origin[1]), ($z + $Origin[2]))
}

function Get-Views { param([string]$List)
    # Each view: forward (into the screen), right, up, all unit vectors in block space (east x, up y, south z).
    $all = @{
        'north' = @{ F = @(0, 0, 1); R = @(-1, 0, 0); U = @(0, 1, 0) }
        'south' = @{ F = @(0, 0, -1); R = @(1, 0, 0); U = @(0, 1, 0) }
        'west' = @{ F = @(1, 0, 0); R = @(0, 0, 1); U = @(0, 1, 0) }
        'east' = @{ F = @(-1, 0, 0); R = @(0, 0, -1); U = @(0, 1, 0) }
        'up' = @{ F = @(0, -1, 0); R = @(1, 0, 0); U = @(0, 0, -1) }
        'down' = @{ F = @(0, 1, 0); R = @(1, 0, 0); U = @(0, 0, 1) }
    }
    # The inventory angle: from the north-west, 30 degrees above the horizon.
    $h = [Math]::Cos(30 * [Math]::PI / 180); $v = [Math]::Sin(30 * [Math]::PI / 180); $d = [Math]::Sqrt(0.5)
    $f = @(($h * $d), (-$v), ($h * $d))
    $r = @(-$d, 0, $d)
    $u = @(($r[1] * $f[2] - $r[2] * $f[1]), ($r[2] * $f[0] - $r[0] * $f[2]), ($r[0] * $f[1] - $r[1] * $f[0]))
    $all['gui'] = @{ F = $f; R = $r; U = $u }
    $selected = @()
    foreach ($name in ($List -split ',')) {
        $key = $name.Trim().ToLowerInvariant()
        if (-not $key) { continue }
        if (-not $all.ContainsKey($key)) { throw "Unknown view '$key'. Views: gui, north, east, south, west, up, down." }
        $selected += [pscustomobject]@{ Name = $key; F = $all[$key].F; R = $all[$key].R; U = $all[$key].U }
    }
    if ($selected.Count -eq 0) { throw 'No view selected.' }
    return $selected
}

function Dot { param([double[]]$A, [double[]]$B) return $A[0] * $B[0] + $A[1] * $B[1] + $A[2] * $B[2] }

# ------------------------------------------------------------------ rasterizer (C#, compiled once)

$rasterSource = @'
using System;
public class ModelRaster {
    public int W; public int H; public byte[] Rgba; public float[] Depth;
    public ModelRaster(int w, int h) {
        W = w; H = h; Rgba = new byte[w * h * 4]; Depth = new float[w * h];
        for (int i = 0; i < Depth.Length; i++) Depth[i] = float.MaxValue;
    }
    public void Fill(byte r, byte g, byte b, byte a) {
        for (int i = 0; i < W * H; i++) { Rgba[i * 4] = r; Rgba[i * 4 + 1] = g; Rgba[i * 4 + 2] = b; Rgba[i * 4 + 3] = a; }
    }
    // A face is a parallelogram on screen: A + s*e1 + t*e2 with s,t in [0,1). Depth is affine in
    // s and t under an orthographic camera, so the whole face is exact.
    public int DrawFace(double ax, double ay, double e1x, double e1y, double e2x, double e2y,
                        double dA, double d1, double d2,
                        byte[] tex, int tw, int th, double u1, double v1, double u2, double v2, int rot, double shade) {
        double det = e1x * e2y - e1y * e2x;
        if (Math.Abs(det) < 1e-9) return 0;
        double minx = Math.Min(Math.Min(ax, ax + e1x), Math.Min(ax + e2x, ax + e1x + e2x));
        double maxx = Math.Max(Math.Max(ax, ax + e1x), Math.Max(ax + e2x, ax + e1x + e2x));
        double miny = Math.Min(Math.Min(ay, ay + e1y), Math.Min(ay + e2y, ay + e1y + e2y));
        double maxy = Math.Max(Math.Max(ay, ay + e1y), Math.Max(ay + e2y, ay + e1y + e2y));
        int x0 = Math.Max(0, (int)Math.Floor(minx)), x1 = Math.Min(W - 1, (int)Math.Ceiling(maxx));
        int y0 = Math.Max(0, (int)Math.Floor(miny)), y1 = Math.Min(H - 1, (int)Math.Ceiling(maxy));
        int drawn = 0;
        for (int py = y0; py <= y1; py++) {
            for (int px = x0; px <= x1; px++) {
                double cx = px + 0.5 - ax, cy = py + 0.5 - ay;
                double s = (cx * e2y - cy * e2x) / det;
                double t = (e1x * cy - e1y * cx) / det;
                if (s < 0 || s >= 1 || t < 0 || t >= 1) continue;
                double sr = s, tr = t;
                if (rot == 90) { sr = t; tr = 1 - s; } else if (rot == 180) { sr = 1 - s; tr = 1 - t; } else if (rot == 270) { sr = 1 - t; tr = s; }
                double u = u1 + sr * (u2 - u1), v = v1 + tr * (v2 - v1);
                int tx = (int)Math.Floor(u * tw / 16.0), ty = (int)Math.Floor(v * th / 16.0);
                if (tx < 0) tx = 0; if (tx >= tw) tx = tw - 1; if (ty < 0) ty = 0; if (ty >= th) ty = th - 1;
                int ti = (ty * tw + tx) * 4;
                if (tex[ti + 3] < 128) continue;
                double depth = dA + s * d1 + t * d2;
                int pi = py * W + px;
                if (depth >= Depth[pi]) continue;
                Depth[pi] = (float)depth;
                Rgba[pi * 4] = (byte)(tex[ti] * shade); Rgba[pi * 4 + 1] = (byte)(tex[ti + 1] * shade);
                Rgba[pi * 4 + 2] = (byte)(tex[ti + 2] * shade); Rgba[pi * 4 + 3] = 255;
                drawn++;
            }
        }
        return drawn;
    }
}
'@
if (-not ('ModelRaster' -as [type])) { Add-Type -TypeDefinition $rasterSource -Language CSharp }

# ------------------------------------------------------------------ main

function Resolve-Input {
    if ($Blockstate) {
        if (-not (Test-Path -LiteralPath $Blockstate)) { throw "Blockstate file not found: $Blockstate" }
        $states = Get-Content -LiteralPath $Blockstate -Raw | ConvertFrom-Json
        $variants = Get-Prop $states 'variants'
        if ($null -eq $variants) { throw "Blockstate $Blockstate has no 'variants' (multipart is not supported)." }
        if (-not $Variant) {
            $keys = @($variants.PSObject.Properties | ForEach-Object { $_.Name })
            throw "Give -Variant with one of: $($keys -join ', ')"
        }
        $chosen = Get-Prop $variants $Variant
        if ($null -eq $chosen) { throw "Variant '$Variant' is not in $Blockstate" }
        if ($chosen -is [array]) { $chosen = $chosen[0]; Add-Problem 'note' 'Variant lists several models; the first is drawn' }
        $modelName = [string](Get-Prop $chosen 'model')
        $x = Get-Prop $chosen 'x'; $y = Get-Prop $chosen 'y'
        if ($null -ne $x) { $script:RotateX = [int]$x }
        if ($null -ne $y) { $script:RotateY = [int]$y }
        $parts = Split-ResourceName -Name $modelName
        # A blockstate names "modid:name" for models/block/name.json.
        $namespace = $parts[0]; $path = $parts[1]; if ($path -notmatch '^(block|item)/') { $path = "block/$path" }
        if (-not $AssetsRoot) {
            $full = (Resolve-Path -LiteralPath $Blockstate).Path
            if ($full -match '^(.*[\\/]assets)[\\/][^\\/]+[\\/]blockstates[\\/]') { $script:AssetsRoot = $Matches[1] }
        }
        return @($namespace, $path, [IO.Path]::GetFileNameWithoutExtension($Blockstate) + '-' + ($Variant -replace '[^A-Za-z0-9]+', '_'))
    }
    if (-not $ModelFile) { throw 'Give a model JSON file, or -Blockstate with -Variant.' }
    if ($ModelFile -match '^([a-z0-9_.-]+):([a-z0-9_/.-]+)$' -and -not (Test-Path -LiteralPath $ModelFile)) {
        # A resource name such as minecraft:block/furnace, read from the assets root or the vanilla jar.
        $namespace = $Matches[1]; $path = $Matches[2]
        if ($path -notmatch '^(block|item)/') { $path = "block/$path" }
        return @($namespace, $path, ($ModelFile -replace '[^A-Za-z0-9]+', '_'))
    }
    if (-not (Test-Path -LiteralPath $ModelFile)) { throw "Model file not found: $ModelFile" }
    $full = (Resolve-Path -LiteralPath $ModelFile).Path
    if ($full -match '^(.*[\\/]assets)[\\/]([^\\/]+)[\\/]models[\\/](.+)\.json$') {
        if (-not $AssetsRoot) { $script:AssetsRoot = $Matches[1] }
        return @($Matches[2], ($Matches[3] -replace '\\', '/'), [IO.Path]::GetFileNameWithoutExtension($ModelFile))
    }
    # A loose file: read it directly under a private namespace.
    $script:LooseModel = Get-Content -LiteralPath $full -Raw | ConvertFrom-Json
    return @('_loose', 'loose', [IO.Path]::GetFileNameWithoutExtension($ModelFile))
}

$script:LooseModel = $null
$origReadModel = ${function:Read-ModelJson}
function Read-ModelJson { param([string]$Namespace, [string]$Path)
    if ($Namespace -eq '_loose') { return $script:LooseModel }
    return & $origReadModel -Namespace $Namespace -Path $Path
}

$inputInfo = Resolve-Input
$rootNamespace = $inputInfo[0]; $rootPath = $inputInfo[1]; $baseName = $inputInfo[2]
if ($RotateX % 90 -ne 0 -or $RotateY % 90 -ne 0) { throw 'RotateX and RotateY must be multiples of 90.' }

$textures = @{}
$elementsRef = [ref]$null
$chain = New-Object 'System.Collections.Generic.List[string]'
Resolve-Model -Namespace $rootNamespace -Path $rootPath -Textures $textures -Elements $elementsRef -Depth 0 -Chain $chain
Add-Problem 'note' "Model chain: $($chain -join ' -> ')"
$elements = $elementsRef.Value
if ($null -eq $elements -or $elements.Count -eq 0) { Add-Problem 'error' 'No elements anywhere in the parent chain; nothing to draw' }

if (-not $textures.ContainsKey('particle')) { Add-Problem 'warn' "No 'particle' texture: the game uses a missing-texture particle when the block breaks" }
else { $null = Resolve-TextureVariable -Textures $textures -Value '#particle' -Origin 'particle' }

$allowedAngles = @(-45.0, -22.5, 0.0, 22.5, 45.0)
$faceNames = @('down', 'up', 'north', 'south', 'west', 'east')
$faces = New-Object 'System.Collections.Generic.List[object]'
$elementIndex = 0
foreach ($element in @($elements | Where-Object { $null -ne $_ })) {
    $label = "element $elementIndex"
    $from = @((Get-Prop $element 'from') | ForEach-Object { Get-Number $_ "$label from" })
    $to = @((Get-Prop $element 'to') | ForEach-Object { Get-Number $_ "$label to" })
    if ($from.Count -ne 3 -or $to.Count -ne 3) { Add-Problem 'error' "$label needs 'from' and 'to' with three numbers each"; $elementIndex++; continue }
    for ($i = 0; $i -lt 3; $i++) {
        foreach ($value in @($from[$i], $to[$i])) { if ($value -lt -16 -or $value -gt 32) { Add-Problem 'error' "$label coordinate $value is outside -16..32" } }
        if ($from[$i] -gt $to[$i]) { Add-Problem 'warn' "$label has from > to on axis $i; the game draws it inside out" }
    }
    $shade = 1.0
    $shadeProp = Get-Prop $element 'shade'
    $shaded = ($null -eq $shadeProp) -or [bool]$shadeProp
    $rotation = Get-Prop $element 'rotation'
    $rotAxis = $null; $rotAngle = 0.0; $rotOrigin = @(8.0, 8.0, 8.0); $rescale = $null
    if ($null -ne $rotation) {
        $rotAxis = [string](Get-Prop $rotation 'axis')
        $rotAngle = Get-Number (Get-Prop $rotation 'angle') "$label rotation angle"
        $originProp = Get-Prop $rotation 'origin'
        if ($null -ne $originProp) { $rotOrigin = @($originProp | ForEach-Object { [double]$_ }) }
        if ($rotAxis -notin @('x', 'y', 'z')) { Add-Problem 'error' "$label rotation axis must be x, y, or z (got '$rotAxis')" }
        if ($allowedAngles -notcontains $rotAngle) { Add-Problem 'error' "$label rotation angle $rotAngle is not one of -45, -22.5, 0, 22.5, 45" }
        $rescaleProp = Get-Prop $rotation 'rescale'
        if ($null -ne $rescaleProp -and [bool]$rescaleProp -and $rotAngle -ne 0) {
            $factor = 1.0 / [Math]::Cos($rotAngle * [Math]::PI / 180.0)
            $rescale = switch ($rotAxis) { 'x' { @(1.0, $factor, $factor) } 'y' { @($factor, 1.0, $factor) } 'z' { @($factor, $factor, 1.0) } default { $null } }
        }
    }
    $faceMap = Get-Prop $element 'faces'
    if ($null -eq $faceMap) { Add-Problem 'warn' "$label has no faces"; $elementIndex++; continue }
    foreach ($faceProperty in $faceMap.PSObject.Properties) {
        $faceName = $faceProperty.Name; $face = $faceProperty.Value
        if ($faceNames -notcontains $faceName) { Add-Problem 'error' "$label has an unknown face '$faceName'"; continue }
        $textureRef = [string](Get-Prop $face 'texture')
        if (-not $textureRef) { Add-Problem 'error' "$label face $faceName has no texture"; continue }
        $resolved = Resolve-TextureVariable -Textures $textures -Value $textureRef -Origin "$label face $faceName"
        if ($null -eq $resolved) { continue }
        $uv = Get-Prop $face 'uv'
        if ($null -eq $uv) { $uv = Get-DefaultUv -Face $faceName -From $from -To $to }
        else {
            $uv = @($uv | ForEach-Object { Get-Number $_ "$label face $faceName uv" })
            if ($uv.Count -ne 4) { Add-Problem 'error' "$label face $faceName uv needs four numbers"; continue }
            foreach ($value in $uv) { if ($value -lt 0 -or $value -gt 16) { Add-Problem 'warn' "$label face $faceName uv value $value is outside 0..16" } }
        }
        $faceRot = 0
        $faceRotProp = Get-Prop $face 'rotation'
        if ($null -ne $faceRotProp) { $faceRot = [int]$faceRotProp; if ($faceRot -notin @(0, 90, 180, 270)) { Add-Problem 'error' "$label face $faceName rotation must be 0, 90, 180, or 270" } }
        $cull = Get-Prop $face 'cullface'
        if ($null -ne $cull -and $faceNames -notcontains [string]$cull) { Add-Problem 'error' "$label face $faceName cullface '$cull' is not a face name" }
        $tint = Get-Prop $face 'tintindex'
        if ($null -ne $tint -and [int]$tint -ge 0) { Add-Problem 'note' "$label face $faceName has tintindex $tint; drawn untinted" }
        $corners = Get-FaceCorners -Face $faceName -From $from -To $to
        $world = @()
        foreach ($corner in $corners) {
            $p = $corner
            if ($rotAxis -and $rotAngle -ne 0) { $p = Rotate-Point -P $p -Axis $rotAxis -Degrees $rotAngle -Origin $rotOrigin -RescaleFactors $rescale }
            elseif ($rotAxis -and $rescale) { $p = Rotate-Point -P $p -Axis $rotAxis -Degrees 0 -Origin $rotOrigin -RescaleFactors $rescale }
            if ($RotateX -ne 0) { $p = Rotate-Point -P $p -Axis 'x' -Degrees (-$RotateX) -Origin @(8.0, 8.0, 8.0) -RescaleFactors $null }
            if ($RotateY -ne 0) { $p = Rotate-Point -P $p -Axis 'y' -Degrees (-$RotateY) -Origin @(8.0, 8.0, 8.0) -RescaleFactors $null }
            $world += , $p
        }
        $faces.Add([pscustomobject]@{
            Label = "$label $faceName"; Texture = $resolved; Corners = $world; Uv = $uv; Rotation = $faceRot; Shaded = $shaded
        })
    }
    $elementIndex++
}

foreach ($face in $faces) { $null = Get-Texture -Name $face.Texture -Origin $face.Label }

# ---- report
foreach ($line in $script:Notes) { Write-Host "note  $line" }
foreach ($line in $script:Warnings) { Write-Host "WARN  $line" }
foreach ($line in $script:Errors) { Write-Host "ERROR $line" }
Write-Host ("Checked {0} element(s), {1} face(s): {2} error(s), {3} warning(s)." -f @($elements).Count, $faces.Count, $script:Errors.Count, $script:Warnings.Count)
if ($script:Errors.Count -gt 0) { exit 1 }
if ($ValidateOnly) { exit 0 }

# ---- render
$viewList = Get-Views -List $Views
$backRgba = @(0, 0, 0, 0)
if ($Background) {
    $hex = $Background.TrimStart('#')
    if ($hex.Length -eq 6) { $hex += 'FF' }
    if ($hex.Length -ne 8) { throw "Background must be #RRGGBB or #RRGGBBAA" }
    $backRgba = @([Convert]::ToInt32($hex.Substring(0, 2), 16), [Convert]::ToInt32($hex.Substring(2, 2), 16), [Convert]::ToInt32($hex.Substring(4, 2), 16), [Convert]::ToInt32($hex.Substring(6, 2), 16))
}
$padding = 1.0
$renders = @()
foreach ($view in $viewList) {
    # Bounds: the unit block and every face corner, so a model that overflows the block still fits.
    $points = @()
    foreach ($cx in @(0.0, 16.0)) { foreach ($cy in @(0.0, 16.0)) { foreach ($cz in @(0.0, 16.0)) { $points += , @($cx, $cy, $cz) } } }
    foreach ($face in $faces) { foreach ($c in $face.Corners) { $points += , $c } }
    $minU = [double]::MaxValue; $maxU = [double]::MinValue; $minV = [double]::MaxValue; $maxV = [double]::MinValue
    foreach ($p in $points) {
        $u = Dot $p $view.R; $v = -(Dot $p $view.U)
        if ($u -lt $minU) { $minU = $u }; if ($u -gt $maxU) { $maxU = $u }; if ($v -lt $minV) { $minV = $v }; if ($v -gt $maxV) { $maxV = $v }
    }
    $minU -= $padding; $minV -= $padding; $maxU += $padding; $maxV += $padding
    $w = [int][Math]::Ceiling(($maxU - $minU) * $Scale); $h = [int][Math]::Ceiling(($maxV - $minV) * $Scale)
    $raster = New-Object ModelRaster($w, $h)
    $raster.Fill([byte]$backRgba[0], [byte]$backRgba[1], [byte]$backRgba[2], [byte]$backRgba[3])
    $drawnFaces = 0
    foreach ($face in $faces) {
        $texture = $script:TextureCache[$face.Texture]
        if ($null -eq $texture) { continue }
        $p00 = $face.Corners[0]; $p10 = $face.Corners[1]; $p01 = $face.Corners[2]
        $e1 = @(($p10[0] - $p00[0]), ($p10[1] - $p00[1]), ($p10[2] - $p00[2]))
        $e2 = @(($p01[0] - $p00[0]), ($p01[1] - $p00[1]), ($p01[2] - $p00[2]))
        # Outward normal follows the vanilla corner order (u across, v down): e2 x e1.
        $normal = @(($e2[1] * $e1[2] - $e2[2] * $e1[1]), ($e2[2] * $e1[0] - $e2[0] * $e1[2]), ($e2[0] * $e1[1] - $e2[1] * $e1[0]))
        if ((Dot $normal $view.F) -ge 0) { continue }   # back face: the camera sees its other side
        $shade = 1.0
        if ($face.Shaded) {
            $ax = [Math]::Abs($normal[0]); $ay = [Math]::Abs($normal[1]); $az = [Math]::Abs($normal[2])
            if ($ay -ge $ax -and $ay -ge $az) { $shade = if ($normal[1] -ge 0) { 1.0 } else { 0.5 } }
            elseif ($az -ge $ax) { $shade = 0.8 } else { $shade = 0.6 }
        }
        $sx = ((Dot $p00 $view.R) - $minU) * $Scale; $sy = (-(Dot $p00 $view.U) - $minV) * $Scale
        $e1x = (Dot $e1 $view.R) * $Scale; $e1y = -(Dot $e1 $view.U) * $Scale
        $e2x = (Dot $e2 $view.R) * $Scale; $e2y = -(Dot $e2 $view.U) * $Scale
        $dA = Dot $p00 $view.F; $d1 = Dot $e1 $view.F; $d2 = Dot $e2 $view.F
        $drawn = $raster.DrawFace($sx, $sy, $e1x, $e1y, $e2x, $e2y, $dA, $d1, $d2, $texture.Pixels, $texture.Width, $texture.Height, $face.Uv[0], $face.Uv[1], $face.Uv[2], $face.Uv[3], $face.Rotation, $shade)
        if ($drawn -gt 0) { $drawnFaces++ }
    }
    $renders += [pscustomobject]@{ Name = $view.Name; Width = $w; Height = $h; Pixels = $raster.Rgba; Faces = $drawnFaces }
}

# ---- sheet: one row, cells as large as the largest view, each view centered
$gap = $Scale
$cellW = ($renders | Measure-Object -Property Width -Maximum).Maximum
$cellH = ($renders | Measure-Object -Property Height -Maximum).Maximum
$sheetW = $renders.Count * $cellW + ($renders.Count + 1) * $gap
$sheetH = $cellH + 2 * $gap
$sheet = New-Object byte[] ($sheetW * $sheetH * 4)
for ($i = 0; $i -lt $sheetW * $sheetH; $i++) { $sheet[$i * 4] = [byte]$backRgba[0]; $sheet[$i * 4 + 1] = [byte]$backRgba[1]; $sheet[$i * 4 + 2] = [byte]$backRgba[2]; $sheet[$i * 4 + 3] = [byte]$backRgba[3] }
$column = 0
foreach ($render in $renders) {
    $ox = $gap + $column * ($cellW + $gap) + [int](($cellW - $render.Width) / 2)
    $oy = $gap + [int](($cellH - $render.Height) / 2)
    for ($y = 0; $y -lt $render.Height; $y++) {
        [Array]::Copy($render.Pixels, $y * $render.Width * 4, $sheet, (($oy + $y) * $sheetW + $ox) * 4, $render.Width * 4)
    }
    $column++
}

if (-not $OutputFile) {
    if (-not $OutputDirectory) {
        $toolRoot = Split-Path -Parent $PSScriptRoot
        $repoRoot = Split-Path -Parent $toolRoot
        $OutputDirectory = Join-Path $repoRoot (Join-Path 'workspace\artwork\modelpreview' $baseName)
    }
    $suffix = ''
    if ($RotateX -ne 0 -or $RotateY -ne 0) { $suffix = "-x$RotateX-y$RotateY" }
    $OutputFile = Join-Path $OutputDirectory "$baseName$suffix-preview.png"
}
$outDir = Split-Path -Parent $OutputFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
if ((Test-Path -LiteralPath $OutputFile) -and -not $Force) { throw "Output exists: $OutputFile (use -Force to replace)" }
Write-PngFile -Path $OutputFile -ImageWidth $sheetW -ImageHeight $sheetH -Pixels $sheet
$order = ($renders | ForEach-Object { "$($_.Name) ($($_.Faces) faces)" }) -join ', '
Write-Host "Created $OutputFile (${sheetW}x${sheetH}, scale $Scale, views left to right: $order)"
if ($script:VanillaZip) { $script:VanillaZip.Dispose() }
exit 0

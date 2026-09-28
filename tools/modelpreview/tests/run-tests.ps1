#requires -Version 5.1
# Dependency-free tests for tools/modelpreview. Builds a small assets tree with one-color textures,
# renders it, and reads the output back with System.Drawing.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$toolDir = Split-Path -Parent $PSScriptRoot
$tool = Join-Path $toolDir 'modelpreview.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ("modelpreview-tests-" + [Guid]::NewGuid().ToString('N'))
$assets = Join-Path $work 'assets'
$ns = Join-Path $assets 'testmod'
New-Item -ItemType Directory -Path (Join-Path $ns 'models\block') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $ns 'textures\blocks') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $ns 'blockstates') -Force | Out-Null

$script:Failures = 0
$script:Count = 0

function Assert-True { param([bool]$Condition, [string]$Message)
    $script:Count++
    if ($Condition) { Write-Host "  ok    $Message" } else { $script:Failures++; Write-Host "  FAIL  $Message" }
}

function Write-SolidTexture { param([string]$Name, [int]$R, [int]$G, [int]$B, [int]$A = 255, [int]$Size = 16)
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    for ($y = 0; $y -lt $Size; $y++) { for ($x = 0; $x -lt $Size; $x++) { $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($A, $R, $G, $B)) } }
    $bitmap.Save((Join-Path $ns "textures\blocks\$Name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

function Write-Json { param([string]$RelativePath, [string]$Text)
    $path = Join-Path $ns $RelativePath
    [IO.File]::WriteAllText($path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function Invoke-Tool { param([string[]]$ToolArgs)
    $ErrorActionPreference = 'Continue'
    $output = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool @ToolArgs 2>&1 | Out-String -Width 4096
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Read-Pixel { param([string]$Path, [int]$X, [int]$Y)
    $bitmap = New-Object System.Drawing.Bitmap($Path)
    try { $c = $bitmap.GetPixel($X, $Y); return @($c.R, $c.G, $c.B, $c.A) } finally { $bitmap.Dispose() }
}

function Get-Size { param([string]$Path)
    $bitmap = New-Object System.Drawing.Bitmap($Path)
    try { return @($bitmap.Width, $bitmap.Height) } finally { $bitmap.Dispose() }
}

function Count-Colors { param([string]$Path)
    $bitmap = New-Object System.Drawing.Bitmap($Path)
    try {
        $seen = @{}
        for ($y = 0; $y -lt $bitmap.Height; $y++) { for ($x = 0; $x -lt $bitmap.Width; $x++) { $c = $bitmap.GetPixel($x, $y); if ($c.A -gt 0) { $seen["$($c.R),$($c.G),$($c.B)"] = $true } } }
        return $seen.Keys
    } finally { $bitmap.Dispose() }
}

try {
    # Six one-color textures: red north, green south, blue west, yellow east, white up, black-ish down.
    Write-SolidTexture -Name 'north' -R 200 -G 0 -B 0
    Write-SolidTexture -Name 'south' -R 0 -G 200 -B 0
    Write-SolidTexture -Name 'west' -R 0 -G 0 -B 200
    Write-SolidTexture -Name 'east' -R 200 -G 200 -B 0
    Write-SolidTexture -Name 'up' -R 250 -G 250 -B 250
    Write-SolidTexture -Name 'down' -R 40 -G 40 -B 40
    # A cross texture: opaque left half, clear right half.
    $bitmap = New-Object System.Drawing.Bitmap(16, 16)
    for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) { $a = if ($x -lt 8) { 255 } else { 0 }; $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, 0, 150, 0)) } }
    $bitmap.Save((Join-Path $ns 'textures\blocks\half.png'), [System.Drawing.Imaging.ImageFormat]::Png); $bitmap.Dispose()

    Write-Json 'models\block\base.json' @'
{ "textures": { "particle": "#north" },
  "elements": [ { "from": [0,0,0], "to": [16,16,16], "faces": {
    "north": { "texture": "#north" }, "south": { "texture": "#south" }, "west": { "texture": "#west" },
    "east": { "texture": "#east" }, "up": { "texture": "#up" }, "down": { "texture": "#down" } } } ] }
'@
    Write-Json 'models\block\cube.json' @'
{ "parent": "testmod:block/base", "textures": {
  "north": "testmod:blocks/north", "south": "testmod:blocks/south", "west": "testmod:blocks/west",
  "east": "testmod:blocks/east", "up": "testmod:blocks/up", "down": "testmod:blocks/down" } }
'@
    Write-Json 'models\block\cross.json' @'
{ "ambientocclusion": false, "textures": { "particle": "testmod:blocks/half", "cross": "testmod:blocks/half" },
  "elements": [
    { "from": [0.8, 0, 8], "to": [15.2, 16, 8], "rotation": { "origin": [8,8,8], "axis": "y", "angle": 45, "rescale": true }, "shade": false,
      "faces": { "north": { "uv": [0,0,16,16], "texture": "#cross" }, "south": { "uv": [0,0,16,16], "texture": "#cross" } } },
    { "from": [8, 0, 0.8], "to": [8, 16, 15.2], "rotation": { "origin": [8,8,8], "axis": "y", "angle": 45, "rescale": true }, "shade": false,
      "faces": { "west": { "uv": [0,0,16,16], "texture": "#cross" }, "east": { "uv": [0,0,16,16], "texture": "#cross" } } } ] }
'@
    Write-Json 'models\block\bad_angle.json' @'
{ "textures": { "particle": "testmod:blocks/north", "a": "testmod:blocks/north" },
  "elements": [ { "from": [0,0,0], "to": [16,16,16], "rotation": { "origin": [8,8,8], "axis": "y", "angle": 30 }, "faces": { "north": { "texture": "#a" } } } ] }
'@
    Write-Json 'models\block\out_of_range.json' @'
{ "textures": { "particle": "testmod:blocks/north", "a": "testmod:blocks/north" },
  "elements": [ { "from": [0,0,-17], "to": [16,16,16], "faces": { "north": { "texture": "#a" } } } ] }
'@
    Write-Json 'models\block\missing_texture.json' @'
{ "textures": { "particle": "testmod:blocks/nowhere", "a": "testmod:blocks/nowhere" },
  "elements": [ { "from": [0,0,0], "to": [16,16,16], "faces": { "north": { "texture": "#a" } } } ] }
'@
    Write-Json 'models\block\unbound.json' @'
{ "textures": { "particle": "testmod:blocks/north" },
  "elements": [ { "from": [0,0,0], "to": [16,16,16], "faces": { "north": { "texture": "#nobody" } } } ] }
'@
    Write-Json 'models\block\zfight.json' @'
{ "textures": { "particle": "testmod:blocks/north", "a": "testmod:blocks/north" },
  "elements": [
    { "from": [0,0,0], "to": [8,16,16], "faces": { "east": { "texture": "#a" }, "north": { "texture": "#a" } } },
    { "from": [8,2,2], "to": [8,14,14], "faces": { "east": { "texture": "#a" }, "west": { "texture": "#a" } } } ] }
'@
    Write-Json 'models\block\touching.json' @'
{ "textures": { "particle": "testmod:blocks/north", "a": "testmod:blocks/north" },
  "elements": [
    { "from": [0,0,0], "to": [8,16,16], "faces": { "east": { "texture": "#a" }, "north": { "texture": "#a" } } },
    { "from": [8,0,0], "to": [16,16,16], "faces": { "west": { "texture": "#a" }, "north": { "texture": "#a" } } } ] }
'@
    Write-Json 'blockstates\cube.json' @'
{ "variants": { "facing=north": { "model": "testmod:cube" }, "facing=east": { "model": "testmod:cube", "y": 90 } } }
'@

    Write-Host 'cube, six views at scale 4'
    $out = Join-Path $work 'cube.png'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\cube.json'), '-Views', 'north,east,south,west,up,down', '-Scale', '4', '-OutputFile', $out)
    Assert-True ($r.ExitCode -eq 0) "exit code 0 ($($r.ExitCode))"
    Assert-True ($r.Output -match 'Model chain: testmod:block/cube -> testmod:block/base') 'parent chain resolved'
    Assert-True (Test-Path $out) 'output written'
    # Each view is (16 + 2 padding) * 4 = 72 px wide; gap 4; cell centers at 4 + 36 + i * 76.
    $size = Get-Size $out
    Assert-True (($size[0] -eq 460) -and ($size[1] -eq 80)) "sheet size $($size -join 'x')"
    $expected = @(
        @('north', 160, 0, 0), @('east', 120, 120, 0), @('south', 0, 160, 0),
        @('west', 0, 0, 120), @('up', 250, 250, 250), @('down', 20, 20, 20)
    )
    for ($i = 0; $i -lt 6; $i++) {
        $px = Read-Pixel $out (4 + 36 + $i * 76) (4 + 36)
        $e = $expected[$i]
        $close = ([Math]::Abs($px[0] - [int]$e[1]) -le 1) -and ([Math]::Abs($px[1] - [int]$e[2]) -le 1) -and ([Math]::Abs($px[2] - [int]$e[3]) -le 1)
        Assert-True $close "$($e[0]) view shows its face with vanilla shade ($($px[0]),$($px[1]),$($px[2]))"
    }
    $corner = Read-Pixel $out 1 1
    Assert-True ($corner[3] -eq 0) 'background is transparent'

    Write-Host 'blockstate rotation y=90 turns the west face to the north view'
    $out2 = Join-Path $work 'cube-east.png'
    $r = Invoke-Tool @('-Blockstate', (Join-Path $ns 'blockstates\cube.json'), '-Variant', 'facing=east', '-Views', 'north', '-Scale', '4', '-OutputFile', $out2)
    Assert-True ($r.ExitCode -eq 0) "exit code 0 ($($r.ExitCode))"
    $px = Read-Pixel $out2 (4 + 36) (4 + 36)
    Assert-True ($px[2] -ge 158 -and $px[2] -le 161 -and $px[0] -eq 0) "north view shows the former west face after y=90 ($($px -join ','))"

    Write-Host 'gui view shows top, north, and west, as the inventory does'
    $out3 = Join-Path $work 'cube-gui.png'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\cube.json'), '-Views', 'gui', '-Scale', '4', '-OutputFile', $out3)
    $colors = @(Count-Colors $out3)
    Assert-True ($colors -contains '250,250,250') 'top face visible'
    Assert-True ($colors -contains '160,0,0') 'north face visible (shaded 0.8)'
    Assert-True ($colors -contains '0,0,120') 'west face visible (shaded 0.6)'
    Assert-True (-not ($colors -contains '0,160,0')) 'south face hidden'
    Assert-True (-not ($colors -contains '120,120,0')) 'east face hidden'
    $size3 = Get-Size $out3
    # North must be on the left half, west on the right half.
    $leftRed = $false; $rightBlue = $false
    $bitmap = New-Object System.Drawing.Bitmap($out3)
    try {
        for ($y = 0; $y -lt $bitmap.Height; $y++) { for ($x = 0; $x -lt $bitmap.Width; $x++) {
            $c = $bitmap.GetPixel($x, $y)
            if ($c.R -eq 160 -and $c.B -eq 0 -and $x -lt $bitmap.Width / 2) { $leftRed = $true }
            if ($c.B -eq 120 -and $c.R -eq 0 -and $x -gt $bitmap.Width / 2) { $rightBlue = $true }
        } }
    } finally { $bitmap.Dispose() }
    Assert-True ($leftRed -and $rightBlue) 'north on the left, west on the right'

    Write-Host 'cross model with a half-transparent texture'
    $out4 = Join-Path $work 'cross.png'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\cross.json'), '-Views', 'north,up', '-Scale', '4', '-OutputFile', $out4)
    Assert-True ($r.ExitCode -eq 0) "exit code 0 ($($r.ExitCode))"
    # With a half-clear texture the nearer plane can cover every opaque pixel of the other, so one or two faces draw.
    Assert-True ($r.Output -match 'north \([12] faces\)') 'the planes face the north view'
    Assert-True ($r.Output -match 'up \(0 faces\)') 'no face faces up'
    $opaque = 0; $clear = 0
    $bitmap = New-Object System.Drawing.Bitmap($out4)
    try { for ($y = 4; $y -lt 76; $y++) { for ($x = 4; $x -lt 76; $x++) { if ($bitmap.GetPixel($x, $y).A -eq 255) { $opaque++ } else { $clear++ } } } } finally { $bitmap.Dispose() }
    Assert-True ($opaque -gt 500 -and $clear -gt 500) "cutout leaves clear pixels ($opaque opaque, $clear clear)"
    $px = Read-Pixel $out4 30 40
    Assert-True ($px[3] -eq 0 -or $px[1] -eq 150) 'shade false keeps the texture color'

    Write-Host 'validation'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\bad_angle.json'), '-ValidateOnly')
    Assert-True ($r.ExitCode -eq 1 -and $r.Output -match 'rotation angle 30 is not one of') 'angle 30 is an error'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\out_of_range.json'), '-ValidateOnly')
    Assert-True ($r.ExitCode -eq 1 -and $r.Output -match 'outside -16..32') 'coordinate -17 is an error'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\missing_texture.json'), '-ValidateOnly')
    Assert-True ($r.ExitCode -eq 1 -and $r.Output -match 'Texture file not found: testmod:textures/blocks/nowhere.png') 'missing texture is an error'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\unbound.json'), '-ValidateOnly')
    Assert-True ($r.ExitCode -eq 1 -and $r.Output -match "variable '#nobody'") 'unbound texture variable is an error'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\cube.json'), '-ValidateOnly')
    Assert-True ($r.ExitCode -eq 0 -and $r.Output -match '0 error\(s\), 0 warning\(s\)' -and -not (Test-Path (Join-Path $work 'cube-validate.png'))) 'a valid model passes without rendering'

    Write-Host 'z-fight warning'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\zfight.json'), '-ValidateOnly')
    Assert-True ($r.ExitCode -eq 0 -and $r.Output -match 'z-fight: element 0 east and element 1 east lie in one plane at x=8') 'a plane on a cube face pointing the same way warns'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\touching.json'), '-ValidateOnly')
    Assert-True ($r.ExitCode -eq 0 -and $r.Output -notmatch 'z-fight') 'two cuboids touching back to back do not warn'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\cross.json'), '-ValidateOnly')
    Assert-True ($r.Output -notmatch 'z-fight') 'crossed planes do not warn'

    Write-Host 'bare model names'
    $r = Invoke-Tool @('cube', '-AssetsRoot', $assets, '-ValidateOnly')
    Assert-True ($r.ExitCode -eq 0 -and $r.Output -match 'Model chain: testmod:block/cube') 'a bare name resolves under the assets root'
    $r = Invoke-Tool @('cube', '-ValidateOnly')
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'bare name such as name or block/name together with -AssetsRoot') 'a bare name without a root names the accepted forms'

    Write-Host 'output protection'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\cube.json'), '-Views', 'north', '-Scale', '2', '-OutputFile', $out)
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'Output exists') 'an existing output is not replaced without -Force'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\cube.json'), '-Views', 'north', '-Scale', '2', '-OutputFile', $out, '-Force')
    Assert-True ($r.ExitCode -eq 0) '-Force replaces it'
    $r = Invoke-Tool @((Join-Path $ns 'models\block\cube.json'), '-Views', 'sideways', '-OutputFile', (Join-Path $work 'x.png'))
    Assert-True ($r.ExitCode -ne 0 -and $r.Output -match 'Unknown view') 'an unknown view is refused'
}
finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "$($script:Count) checks, $($script:Failures) failed"
if ($script:Failures -gt 0) { exit 1 }
exit 0

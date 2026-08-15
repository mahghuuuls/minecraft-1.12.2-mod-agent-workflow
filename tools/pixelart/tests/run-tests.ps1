[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'pixelart.ps1'
$Example = Join-Path (Split-Path -Parent $PSScriptRoot) 'examples\mana-drop.pixelart'
$TestDirectory = Join-Path ([IO.Path]::GetTempPath()) ('minecraft-pixelart-' + [Guid]::NewGuid().ToString('N'))
$DefaultWorkspaceAssetDirectory = $null

function Read-UInt32BigEndian {
    param([byte[]]$Bytes, [int]$Offset)

    return [uint32]((([uint32]$Bytes[$Offset] -shl 24) -bor
        ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 8) -bor
        [uint32]$Bytes[$Offset + 3]))
}

function Read-Png {
    param([string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $signature = [byte[]]@(137, 80, 78, 71, 13, 10, 26, 10)
    for ($index = 0; $index -lt $signature.Length; $index++) {
        if ($bytes[$index] -ne $signature[$index]) {
            throw 'PNG signature mismatch.'
        }
    }

    $offset = 8
    $width = 0
    $height = 0
    $bitDepth = 0
    $colorType = 0
    $idat = New-Object 'System.Collections.Generic.List[byte]'

    while ($offset -lt $bytes.Length) {
        $length = [int](Read-UInt32BigEndian -Bytes $bytes -Offset $offset)
        $type = [Text.Encoding]::ASCII.GetString($bytes, $offset + 4, 4)
        $dataOffset = $offset + 8

        if ($type -eq 'IHDR') {
            $width = [int](Read-UInt32BigEndian -Bytes $bytes -Offset $dataOffset)
            $height = [int](Read-UInt32BigEndian -Bytes $bytes -Offset ($dataOffset + 4))
            $bitDepth = $bytes[$dataOffset + 8]
            $colorType = $bytes[$dataOffset + 9]
        }
        elseif ($type -eq 'IDAT') {
            for ($index = 0; $index -lt $length; $index++) {
                $idat.Add($bytes[$dataOffset + $index])
            }
        }

        $offset += 12 + $length
        if ($type -eq 'IEND') {
            break
        }
    }

    if ($idat.Count -lt 6) {
        throw 'PNG does not contain a valid zlib stream.'
    }

    $compressed = $idat.ToArray()
    $deflateBytes = New-Object byte[] ($compressed.Length - 6)
    [Array]::Copy($compressed, 2, $deflateBytes, 0, $deflateBytes.Length)
    $input = New-Object IO.MemoryStream(, $deflateBytes)
    $deflate = New-Object IO.Compression.DeflateStream($input, [IO.Compression.CompressionMode]::Decompress)
    $output = New-Object IO.MemoryStream
    try {
        $deflate.CopyTo($output)
    }
    finally {
        $deflate.Dispose()
        $input.Dispose()
    }

    return [pscustomobject]@{
        Width = $width
        Height = $height
        BitDepth = $bitDepth
        ColorType = $colorType
        Scanlines = $output.ToArray()
    }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

function Get-Pixel {
    param([object]$Png, [int]$X, [int]$Y)
    $stride = 1 + (4 * $Png.Width)
    $offset = ($Y * $stride) + 1 + ($X * 4)
    return [byte[]]@(
        $Png.Scanlines[$offset],
        $Png.Scanlines[$offset + 1],
        $Png.Scanlines[$offset + 2],
        $Png.Scanlines[$offset + 3]
    )
}

function Assert-Pixel {
    param([object]$Png, [int]$X, [int]$Y, [byte[]]$Expected, [string]$Message)
    $actual = Get-Pixel -Png $Png -X $X -Y $Y
    Assert-Equal (($actual | ForEach-Object { $_.ToString('X2') }) -join '') (($Expected | ForEach-Object { $_.ToString('X2') }) -join '') $Message
}

[IO.Directory]::CreateDirectory($TestDirectory) | Out-Null
try {
    $exampleOutput = Join-Path $TestDirectory 'mana.png'
    & $Tool $Example -OutputFile $exampleOutput
    $png = Read-Png -Path $exampleOutput

    Assert-Equal $png.Width 9 'Example width is wrong.'
    Assert-Equal $png.Height 9 'Example height is wrong.'
    Assert-Equal $png.BitDepth 8 'PNG bit depth is wrong.'
    Assert-Equal $png.ColorType 6 'PNG must be truecolor with alpha.'
    Assert-Pixel $png 0 0 ([byte[]]@(0, 0, 0, 0)) 'Transparent corner is wrong.'
    Assert-Pixel $png 4 0 ([byte[]]@(7, 21, 47, 255)) 'Outline color is wrong.'
    Assert-Pixel $png 4 4 ([byte[]]@(242, 254, 255, 255)) 'Highlight color is wrong.'

    $overwriteRejected = $false
    try {
        & $Tool $Example -OutputFile $exampleOutput 2>$null
    }
    catch {
        $overwriteRejected = $_.Exception.Message -like '*already exists*'
    }
    Assert-Equal $overwriteRejected $true 'Existing output was not protected.'

    $mismatchRejected = $false
    try {
        & $Tool $Example -OutputFile (Join-Path $TestDirectory 'wrong.png') -Preset block 2>$null
    }
    catch {
        $mismatchRejected = $_.Exception.Message -like '*requires 16x16*'
    }
    Assert-Equal $mismatchRejected $true 'Preset mismatch was not rejected.'

    $besideDirectory = Join-Path $TestDirectory 'beside'
    [IO.Directory]::CreateDirectory($besideDirectory) | Out-Null
    $besideSpec = Join-Path $besideDirectory 'candidate.pixelart'
    [IO.File]::WriteAllText($besideSpec, "@size 1x1`r`n@name candidate-a`r`nX`r`nX = #ABCDEF`r`n")
    & $Tool $besideSpec -OutputBesideSpecification
    $besideOutput = Join-Path $besideDirectory 'candidate-a.png'
    Assert-Equal ([IO.File]::Exists($besideOutput)) $true 'Specification-relative output was not created beside the input.'
    Assert-Pixel (Read-Png -Path $besideOutput) 0 0 ([byte[]]@(171, 205, 239, 255)) 'Specification-relative output changed the source pixel.'

    $besideConflictRejected = $false
    try {
        & $Tool $besideSpec -OutputBesideSpecification -OutputDirectory $TestDirectory 2>$null
    }
    catch {
        $besideConflictRejected = $_.Exception.Message -like '*cannot be combined*'
    }
    Assert-Equal $besideConflictRejected $true 'Conflicting specification-relative and explicit output directories were not rejected.'

    $reviewDirectory = Join-Path $TestDirectory 'mana-review'
    & $Tool $Example -OutputFile $exampleOutput -Review -PreviewScale 4 -ReviewDirectory $reviewDirectory -Force

    $zoomPng = Read-Png -Path (Join-Path $reviewDirectory 'mana-review-zoom.png')
    Assert-Equal $zoomPng.Width 36 'Nearest-neighbor review width is wrong.'
    Assert-Equal $zoomPng.Height 36 'Nearest-neighbor review height is wrong.'
    Assert-Pixel $zoomPng 0 0 ([byte[]]@(0, 0, 0, 0)) 'Zoom preview changed transparency.'
    Assert-Pixel $zoomPng 16 16 ([byte[]]@(242, 254, 255, 255)) 'Zoom preview did not preserve the source pixel.'

    $grayscalePng = Read-Png -Path (Join-Path $reviewDirectory 'mana-review-grayscale.png')
    Assert-Equal $grayscalePng.Width 36 'Grayscale review width is wrong.'
    Assert-Pixel $grayscalePng 16 16 ([byte[]]@(251, 251, 251, 255)) 'Grayscale conversion is wrong.'

    $alphaSpec = Join-Path $TestDirectory 'alpha.pixelart'
    [IO.File]::WriteAllText($alphaSpec, "@size 2x1`r`n. X`r`nX = translucent = #11223344`r`n")
    $alphaOutput = Join-Path $TestDirectory 'alpha.png'
    & $Tool $alphaSpec -OutputFile $alphaOutput
    $alphaPng = Read-Png -Path $alphaOutput
    Assert-Pixel $alphaPng 0 0 ([byte[]]@(0, 0, 0, 0)) 'Implicit transparency is wrong.'
    Assert-Pixel $alphaPng 1 0 ([byte[]]@(17, 34, 51, 68)) 'Explicit alpha color is wrong.'

    $blockSpec = Join-Path $TestDirectory 'block.pixelart'
    $blockRow = (@('B') * 16) -join ' '
    $blockGrid = (@($blockRow) * 16) -join "`r`n"
    [IO.File]::WriteAllText($blockSpec, "@preset block`r`n@name block`r`n$blockGrid`r`nB = #345678`r`n")
    $blockOutput = Join-Path $TestDirectory 'block.png'
    $blockReviewDirectory = Join-Path $TestDirectory 'block-review'
    & $Tool $blockSpec -OutputFile $blockOutput -Review -PreviewScale 2 -ReviewDirectory $blockReviewDirectory
    $tilePng = Read-Png -Path (Join-Path $blockReviewDirectory 'block-review-tile-3x3.png')
    Assert-Equal $tilePng.Width 96 'Block tile review width is wrong.'
    Assert-Equal $tilePng.Height 96 'Block tile review height is wrong.'
    Assert-Pixel $tilePng 95 95 ([byte[]]@(52, 86, 120, 255)) 'Block tile review changed the repeated pixels.'

    $defaultAssetName = 'automated_default_' + [Guid]::NewGuid().ToString('N')
    $defaultSpec = Join-Path $TestDirectory 'default.pixelart'
    [IO.File]::WriteAllText($defaultSpec, "@size 1x1`r`n@name $defaultAssetName`r`nX`r`nX = #123456`r`n")
    Push-Location $TestDirectory
    try {
        & $Tool $defaultSpec
    }
    finally {
        Pop-Location
    }

    $workflowRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $PSScriptRoot) '..\..'))
    $DefaultWorkspaceAssetDirectory = Join-Path $workflowRoot (Join-Path 'workspace\artwork\pixelart' $defaultAssetName)
    $defaultOutput = Join-Path $DefaultWorkspaceAssetDirectory (Join-Path 'candidates' "$defaultAssetName.png")
    Assert-Equal ([IO.File]::Exists($defaultOutput)) $true 'Bundled default output did not use the workflow artwork workspace.'

    Write-Output 'All pixel-art tests passed.'
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($DefaultWorkspaceAssetDirectory) -and [IO.Directory]::Exists($DefaultWorkspaceAssetDirectory)) {
        $allowedArtworkRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $DefaultWorkspaceAssetDirectory) '.')) + [IO.Path]::DirectorySeparatorChar
        $resolvedDefaultDirectory = [IO.Path]::GetFullPath($DefaultWorkspaceAssetDirectory)
        if (-not ($resolvedDefaultDirectory + [IO.Path]::DirectorySeparatorChar).StartsWith($allowedArtworkRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove default-output fixture outside artwork root: $resolvedDefaultDirectory"
        }
        [IO.Directory]::Delete($resolvedDefaultDirectory, $true)
    }
    if ([IO.Directory]::Exists($TestDirectory)) {
        [IO.Directory]::Delete($TestDirectory, $true)
    }
}

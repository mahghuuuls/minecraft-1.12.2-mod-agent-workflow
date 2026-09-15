[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$InputFile,

    [switch]$Compose,

    [switch]$Compare,

    [string]$Reference,

    [ValidateRange(1, 64)]
    [int]$Columns,

    [ValidateRange(0, 64)]
    [int]$Gap = 1,

    [string]$Background,

    [string]$OutputFile,

    [string]$OutputDirectory,

    [switch]$OutputBesideSpecification,

    [string]$Name,

    [string]$Preset,

    [ValidateRange(1, 4096)]
    [int]$Width,

    [ValidateRange(1, 4096)]
    [int]$Height,

    [switch]$Review,

    [switch]$TilePreview,

    [string]$ReviewDirectory,

    [ValidateRange(1, 64)]
    [int]$PreviewScale,

    [switch]$Force,

    [switch]$ListPresets
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$PresetDimensions = @{
    block    = @(16, 16)
    item     = @(16, 16)
    bar_icon = @(9, 9)
}

function Show-Presets {
    Write-Output 'block    16x16'
    Write-Output 'item     16x16'
    Write-Output 'bar_icon  9x9'
}

function Convert-HexColor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Hex,

        [Parameter(Mandatory = $true)]
        [int]$LineNumber
    )

    $digits = $Hex.Substring(1)
    if ($digits.Length -ne 6 -and $digits.Length -ne 8) {
        throw "Line $LineNumber has invalid color '$Hex'. Use #RRGGBB or #RRGGBBAA."
    }

    $alpha = 255
    if ($digits.Length -eq 8) {
        $alpha = [Convert]::ToByte($digits.Substring(6, 2), 16)
    }

    return [byte[]]@(
        [Convert]::ToByte($digits.Substring(0, 2), 16),
        [Convert]::ToByte($digits.Substring(2, 2), 16),
        [Convert]::ToByte($digits.Substring(4, 2), 16),
        $alpha
    )
}

function Read-PixelArtSpec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $rows = New-Object 'System.Collections.Generic.List[object]'
    $palette = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]' ([StringComparer]::Ordinal)
    $palette.Add('.', [byte[]]@(0, 0, 0, 0))

    $specPreset = $null
    $specWidth = 0
    $specHeight = 0
    $specName = $null
    $lineNumber = 0

    foreach ($rawLine in [IO.File]::ReadAllLines($Path)) {
        $lineNumber++
        $line = $rawLine.Trim()

        if ($line.Length -eq 0 -or $line.StartsWith('//')) {
            continue
        }

        if ($line.StartsWith('@')) {
            if ($rows.Count -gt 0) {
                throw "Line $lineNumber contains a directive after the grid. Put directives before all grid rows."
            }

            if ($line -match '^@preset\s+(?<value>[A-Za-z0-9_-]+)$') {
                if ($null -ne $specPreset) {
                    throw "Line $lineNumber repeats @preset."
                }
                $specPreset = $Matches.value.ToLowerInvariant().Replace('-', '_')
                continue
            }

            if ($line -match '^@size\s+(?<width>\d+)\s*[xX]\s*(?<height>\d+)$') {
                if ($specWidth -ne 0 -or $specHeight -ne 0) {
                    throw "Line $lineNumber repeats @size."
                }
                $specWidth = [int]$Matches.width
                $specHeight = [int]$Matches.height
                if ($specWidth -lt 1 -or $specWidth -gt 4096 -or $specHeight -lt 1 -or $specHeight -gt 4096) {
                    throw "Line $lineNumber has an @size outside the supported 1..4096 range."
                }
                continue
            }

            if ($line -match '^@name\s+(?<value>.+?)\s*$') {
                if ($null -ne $specName) {
                    throw "Line $lineNumber repeats @name."
                }
                $specName = $Matches.value.Trim()
                continue
            }

            throw "Line $lineNumber has an unknown or malformed directive: '$line'."
        }

        if ($line -match '^(?<symbol>\S+)\s*=\s*(?<value>.+?)\s*$') {
            $symbol = $Matches.symbol
            $value = $Matches.value.Trim()

            if ($symbol -match '\s' -or $symbol -eq '=') {
                throw "Line $lineNumber has invalid palette symbol '$symbol'."
            }

            if ($value -match '^(?i:transparent|none)$') {
                $color = [byte[]]@(0, 0, 0, 0)
            }
            else {
                $hexMatches = [regex]::Matches($value, '#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?')
                if ($hexMatches.Count -eq 0) {
                    throw "Line $lineNumber has no #RRGGBB or #RRGGBBAA color."
                }
                $color = Convert-HexColor -Hex $hexMatches[$hexMatches.Count - 1].Value -LineNumber $lineNumber
            }

            if ($palette.ContainsKey($symbol)) {
                if ($symbol -eq '.' -and $color[3] -eq 0) {
                    continue
                }
                throw "Line $lineNumber defines palette symbol '$symbol' more than once."
            }

            $palette.Add($symbol, $color)
            continue
        }

        $tokens = [regex]::Split($line, '\s+')
        $rows.Add([pscustomobject]@{
            LineNumber = $lineNumber
            Tokens = [string[]]$tokens
        })
    }

    if ($rows.Count -eq 0) {
        throw 'The specification does not contain a pixel grid.'
    }

    $gridWidth = $rows[0].Tokens.Count
    for ($rowIndex = 0; $rowIndex -lt $rows.Count; $rowIndex++) {
        $row = $rows[$rowIndex]
        if ($row.Tokens.Count -ne $gridWidth) {
            throw "Grid line $($row.LineNumber) has $($row.Tokens.Count) pixels; expected $gridWidth."
        }

        for ($columnIndex = 0; $columnIndex -lt $row.Tokens.Count; $columnIndex++) {
            $symbol = $row.Tokens[$columnIndex]
            if (-not $palette.ContainsKey($symbol)) {
                throw "Grid line $($row.LineNumber), column $($columnIndex + 1) uses undefined symbol '$symbol'."
            }
        }
    }

    return [pscustomobject]@{
        Width = $gridWidth
        Height = $rows.Count
        Rows = $rows
        Palette = $palette
        Preset = $specPreset
        DeclaredWidth = $specWidth
        DeclaredHeight = $specHeight
        Name = $specName
    }
}

function Assert-ExpectedDimensions {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Spec,

        [string]$CommandPreset,

        [int]$CommandWidth,

        [int]$CommandHeight
    )

    $claims = New-Object 'System.Collections.Generic.List[object]'

    foreach ($entry in @(
        [pscustomobject]@{ Source = '@preset'; Value = $Spec.Preset },
        [pscustomobject]@{ Source = '-Preset'; Value = $CommandPreset }
    )) {
        if ([string]::IsNullOrWhiteSpace($entry.Value)) {
            continue
        }

        $normalized = $entry.Value.ToLowerInvariant().Replace('-', '_')
        if (-not $PresetDimensions.ContainsKey($normalized)) {
            $valid = ($PresetDimensions.Keys | Sort-Object) -join ', '
            throw "$($entry.Source) names unknown preset '$($entry.Value)'. Valid presets: $valid."
        }

        $dimensions = $PresetDimensions[$normalized]
        $claims.Add([pscustomobject]@{
            Source = "$($entry.Source) $normalized"
            Width = $dimensions[0]
            Height = $dimensions[1]
        })
    }

    if ($Spec.DeclaredWidth -ne 0 -or $Spec.DeclaredHeight -ne 0) {
        $claims.Add([pscustomobject]@{
            Source = '@size'
            Width = $Spec.DeclaredWidth
            Height = $Spec.DeclaredHeight
        })
    }

    if (($CommandWidth -eq 0) -xor ($CommandHeight -eq 0)) {
        throw '-Width and -Height must be supplied together.'
    }

    if ($CommandWidth -ne 0) {
        $claims.Add([pscustomobject]@{
            Source = '-Width/-Height'
            Width = $CommandWidth
            Height = $CommandHeight
        })
    }

    foreach ($claim in $claims) {
        if ($claim.Width -ne $Spec.Width -or $claim.Height -ne $Spec.Height) {
            throw "The grid is $($Spec.Width)x$($Spec.Height), but $($claim.Source) requires $($claim.Width)x$($claim.Height)."
        }
    }
}

function Get-Adler32 {
    param([byte[]]$Bytes)

    [uint32]$a = 1
    [uint32]$b = 0
    foreach ($value in $Bytes) {
        $a = [uint32](($a + $value) % 65521)
        $b = [uint32](($b + $a) % 65521)
    }
    return [uint32](($b -shl 16) -bor $a)
}

function Get-Crc32 {
    param([byte[]]$Bytes)

    [uint32]$crc = [uint32]::MaxValue
    foreach ($value in $Bytes) {
        $crc = $crc -bxor [uint32]$value
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1) -ne 0) {
                $crc = [uint32](($crc -shr 1) -bxor [uint32]3988292384)
            }
            else {
                $crc = [uint32]($crc -shr 1)
            }
        }
    }
    return [uint32]($crc -bxor [uint32]::MaxValue)
}

function Add-UInt32BigEndian {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[byte]]$Target,

        [Parameter(Mandatory = $true)]
        [uint32]$Value
    )

    $Target.Add([byte](($Value -shr 24) -band 0xFF))
    $Target.Add([byte](($Value -shr 16) -band 0xFF))
    $Target.Add([byte](($Value -shr 8) -band 0xFF))
    $Target.Add([byte]($Value -band 0xFF))
}

function Add-PngChunk {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[byte]]$Target,

        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [byte[]]$Data
    )

    $typeBytes = [Text.Encoding]::ASCII.GetBytes($Type)
    Add-UInt32BigEndian -Target $Target -Value ([uint32]$Data.Length)
    $Target.AddRange($typeBytes)
    $Target.AddRange($Data)

    $crcInput = New-Object byte[] ($typeBytes.Length + $Data.Length)
    [Array]::Copy($typeBytes, 0, $crcInput, 0, $typeBytes.Length)
    [Array]::Copy($Data, 0, $crcInput, $typeBytes.Length, $Data.Length)
    Add-UInt32BigEndian -Target $Target -Value (Get-Crc32 -Bytes $crcInput)
}

function Compress-Zlib {
    param([byte[]]$Bytes)

    $compressedStream = New-Object IO.MemoryStream
    $deflateStream = New-Object IO.Compression.DeflateStream(
        $compressedStream,
        [IO.Compression.CompressionMode]::Compress,
        $true
    )
    try {
        $deflateStream.Write($Bytes, 0, $Bytes.Length)
    }
    finally {
        $deflateStream.Dispose()
    }

    $deflated = $compressedStream.ToArray()
    $compressedStream.Dispose()

    $result = New-Object 'System.Collections.Generic.List[byte]'
    $result.Add(0x78)
    $result.Add(0x9C)
    $result.AddRange([byte[]]$deflated)
    Add-UInt32BigEndian -Target $result -Value (Get-Adler32 -Bytes $Bytes)
    return [byte[]]$result.ToArray()
}

function Get-SpecPixels {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Spec
    )

    $pixels = New-Object 'System.Collections.Generic.List[byte]'
    foreach ($row in $Spec.Rows) {
        foreach ($symbol in $row.Tokens) {
            $pixels.AddRange([byte[]]$Spec.Palette[$symbol])
        }
    }

    return [byte[]]$pixels.ToArray()
}

function New-PngBytesFromPixels {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ImageWidth,

        [Parameter(Mandatory = $true)]
        [int]$ImageHeight,

        [Parameter(Mandatory = $true)]
        [byte[]]$Pixels
    )

    $expectedLength = $ImageWidth * $ImageHeight * 4
    if ($Pixels.Length -ne $expectedLength) {
        throw "RGBA buffer contains $($Pixels.Length) bytes; expected $expectedLength for ${ImageWidth}x${ImageHeight}."
    }

    $rowBytes = $ImageWidth * 4
    $stride = $rowBytes + 1
    $raw = New-Object byte[] ($stride * $ImageHeight)
    for ($y = 0; $y -lt $ImageHeight; $y++) {
        $raw[$y * $stride] = 0
        [Array]::Copy($Pixels, $y * $rowBytes, $raw, ($y * $stride) + 1, $rowBytes)
    }

    $ihdr = New-Object 'System.Collections.Generic.List[byte]'
    Add-UInt32BigEndian -Target $ihdr -Value ([uint32]$ImageWidth)
    Add-UInt32BigEndian -Target $ihdr -Value ([uint32]$ImageHeight)
    $ihdr.Add(8)
    $ihdr.Add(6)
    $ihdr.Add(0)
    $ihdr.Add(0)
    $ihdr.Add(0)

    $png = New-Object 'System.Collections.Generic.List[byte]'
    $png.AddRange([byte[]]@(137, 80, 78, 71, 13, 10, 26, 10))
    Add-PngChunk -Target $png -Type 'IHDR' -Data ([byte[]]$ihdr.ToArray())
    Add-PngChunk -Target $png -Type 'IDAT' -Data (Compress-Zlib -Bytes ([byte[]]$raw))
    Add-PngChunk -Target $png -Type 'IEND' -Data ([byte[]]@())
    return [byte[]]$png.ToArray()
}

function New-PngBytes {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Spec
    )

    return New-PngBytesFromPixels -ImageWidth $Spec.Width -ImageHeight $Spec.Height -Pixels (Get-SpecPixels -Spec $Spec)
}

function Resize-PixelsNearestNeighbor {
    param(
        [byte[]]$Pixels,
        [int]$ImageWidth,
        [int]$ImageHeight,
        [int]$Scale
    )

    $scaledWidth = $ImageWidth * $Scale
    $scaledHeight = $ImageHeight * $Scale
    if ($scaledWidth -gt 4096 -or $scaledHeight -gt 4096) {
        throw "Review scale $Scale would create a ${scaledWidth}x${scaledHeight} preview. Keep each review dimension at or below 4096 pixels."
    }

    $scaled = New-Object byte[] ($scaledWidth * $scaledHeight * 4)
    for ($sourceY = 0; $sourceY -lt $ImageHeight; $sourceY++) {
        for ($sourceX = 0; $sourceX -lt $ImageWidth; $sourceX++) {
            $sourceOffset = (($sourceY * $ImageWidth) + $sourceX) * 4
            for ($offsetY = 0; $offsetY -lt $Scale; $offsetY++) {
                $targetY = ($sourceY * $Scale) + $offsetY
                for ($offsetX = 0; $offsetX -lt $Scale; $offsetX++) {
                    $targetX = ($sourceX * $Scale) + $offsetX
                    $targetOffset = (($targetY * $scaledWidth) + $targetX) * 4
                    [Array]::Copy($Pixels, $sourceOffset, $scaled, $targetOffset, 4)
                }
            }
        }
    }

    return [pscustomobject]@{
        Width = $scaledWidth
        Height = $scaledHeight
        Pixels = $scaled
    }
}

function Convert-PixelsToGrayscale {
    param([byte[]]$Pixels)

    $grayscale = New-Object byte[] $Pixels.Length
    for ($offset = 0; $offset -lt $Pixels.Length; $offset += 4) {
        $luminance = [int](($Pixels[$offset] * 77 + $Pixels[$offset + 1] * 150 + $Pixels[$offset + 2] * 29 + 128) -shr 8)
        $grayscale[$offset] = [byte]$luminance
        $grayscale[$offset + 1] = [byte]$luminance
        $grayscale[$offset + 2] = [byte]$luminance
        $grayscale[$offset + 3] = $Pixels[$offset + 3]
    }
    return [byte[]]$grayscale
}

function New-TiledPixels {
    param(
        [byte[]]$Pixels,
        [int]$ImageWidth,
        [int]$ImageHeight,
        [int]$Across,
        [int]$Down
    )

    $tiledWidth = $ImageWidth * $Across
    $tiledHeight = $ImageHeight * $Down
    $tiled = New-Object byte[] ($tiledWidth * $tiledHeight * 4)
    for ($y = 0; $y -lt $tiledHeight; $y++) {
        for ($x = 0; $x -lt $tiledWidth; $x++) {
            $sourceOffset = (((($y % $ImageHeight) * $ImageWidth) + ($x % $ImageWidth)) * 4)
            $targetOffset = (($y * $tiledWidth) + $x) * 4
            [Array]::Copy($Pixels, $sourceOffset, $tiled, $targetOffset, 4)
        }
    }

    return [pscustomobject]@{
        Width = $tiledWidth
        Height = $tiledHeight
        Pixels = $tiled
    }
}

function Assert-SafeName {
    param([string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        throw 'The output name cannot be empty.'
    }
    if ($Candidate -eq '.' -or $Candidate -eq '..' -or $Candidate.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        throw "The output name '$Candidate' is not a valid filename."
    }
}

function Read-PngPixels {
    # Decodes an existing PNG into the same RGBA layout the renderer writes. Reading uses the
    # System.Drawing decoder that ships with Windows .NET, so any PNG color type or filter
    # works; writing never depends on it. GDI+ may round the color of a semi-transparent
    # pixel by one step; fully opaque and fully transparent pixels are read exactly.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $bitmap = New-Object System.Drawing.Bitmap($Path)
    try {
        $imageWidth = [int]$bitmap.Width
        $imageHeight = [int]$bitmap.Height
        if ($imageWidth -lt 1 -or $imageHeight -lt 1 -or $imageWidth -gt 4096 -or $imageHeight -gt 4096) {
            throw "PNG $Path is ${imageWidth}x${imageHeight}; each dimension must be within 1..4096."
        }

        $rectangle = New-Object System.Drawing.Rectangle(0, 0, $imageWidth, $imageHeight)
        $locked = $bitmap.LockBits($rectangle, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $stride = [int]$locked.Stride
            $buffer = New-Object byte[] ($stride * $imageHeight)
            [Runtime.InteropServices.Marshal]::Copy($locked.Scan0, $buffer, 0, $buffer.Length)
        }
        finally {
            $bitmap.UnlockBits($locked)
        }
    }
    finally {
        $bitmap.Dispose()
    }

    $pixels = New-Object byte[] ($imageWidth * $imageHeight * 4)
    for ($y = 0; $y -lt $imageHeight; $y++) {
        for ($x = 0; $x -lt $imageWidth; $x++) {
            $sourceOffset = ($y * $stride) + ($x * 4)
            $targetOffset = (($y * $imageWidth) + $x) * 4
            $pixels[$targetOffset] = $buffer[$sourceOffset + 2]
            $pixels[$targetOffset + 1] = $buffer[$sourceOffset + 1]
            $pixels[$targetOffset + 2] = $buffer[$sourceOffset]
            $pixels[$targetOffset + 3] = $buffer[$sourceOffset + 3]
        }
    }

    return [pscustomobject]@{
        Width = $imageWidth
        Height = $imageHeight
        Pixels = $pixels
    }
}

function Get-InputImage {
    # Loads one input for -Compose or -Compare: a .pixelart grid is rendered exactly as the
    # normal mode renders it, and a .png is decoded. Command-line size claims apply to every
    # input, so one call can require, for example, that every sheet member is 16x16.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$CommandPreset,

        [int]$CommandWidth,

        [int]$CommandHeight
    )

    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not [IO.File]::Exists($resolvedPath)) {
        throw "Input file not found: $resolvedPath"
    }

    $extension = [IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()
    if ($extension -eq '.pixelart') {
        $inputSpec = Read-PixelArtSpec -Path $resolvedPath
        Assert-ExpectedDimensions -Spec $inputSpec -CommandPreset $CommandPreset -CommandWidth $CommandWidth -CommandHeight $CommandHeight
        $imageWidth = $inputSpec.Width
        $imageHeight = $inputSpec.Height
        $imagePixels = [byte[]](Get-SpecPixels -Spec $inputSpec)
    }
    elseif ($extension -eq '.png') {
        $png = Read-PngPixels -Path $resolvedPath
        $pngClaims = [pscustomobject]@{
            Width = $png.Width
            Height = $png.Height
            Preset = $null
            DeclaredWidth = 0
            DeclaredHeight = 0
        }
        Assert-ExpectedDimensions -Spec $pngClaims -CommandPreset $CommandPreset -CommandWidth $CommandWidth -CommandHeight $CommandHeight
        $imageWidth = $png.Width
        $imageHeight = $png.Height
        $imagePixels = $png.Pixels
    }
    else {
        throw "Unsupported input '$resolvedPath'. Use a .pixelart specification or a .png file."
    }

    return [pscustomobject]@{
        Path = $resolvedPath
        Label = [IO.Path]::GetFileName($resolvedPath)
        Width = $imageWidth
        Height = $imageHeight
        Pixels = $imagePixels
    }
}

function New-SheetPixels {
    # Places several images on one transparent (or solid) sheet at native resolution: equal
    # cells sized by the largest input, each image at the top-left of its cell, a gap of
    # $GapPixels source pixels between cells and around the border. Transparent source pixels
    # leave the background visible; every other pixel is copied without blending. The caller
    # scales the finished sheet with nearest-neighbor replication.
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Images,

        [Parameter(Mandatory = $true)]
        [int]$ColumnCount,

        [Parameter(Mandatory = $true)]
        [int]$GapPixels,

        [Parameter(Mandatory = $true)]
        [byte[]]$BackgroundColor
    )

    $cellWidth = 0
    $cellHeight = 0
    foreach ($image in $Images) {
        $cellWidth = [Math]::Max($cellWidth, $image.Width)
        $cellHeight = [Math]::Max($cellHeight, $image.Height)
    }

    $columnsUsed = [Math]::Min($ColumnCount, $Images.Count)
    $rowsUsed = [int][Math]::Ceiling($Images.Count / $columnsUsed)
    $sheetWidth = ($columnsUsed * $cellWidth) + (($columnsUsed + 1) * $GapPixels)
    $sheetHeight = ($rowsUsed * $cellHeight) + (($rowsUsed + 1) * $GapPixels)
    if ($sheetWidth -gt 4096 -or $sheetHeight -gt 4096) {
        throw "The sheet would be ${sheetWidth}x${sheetHeight} source pixels. Keep each sheet dimension at or below 4096 pixels."
    }

    $sheet = New-Object byte[] ($sheetWidth * $sheetHeight * 4)
    if ($BackgroundColor[3] -ne 0) {
        [Array]::Copy($BackgroundColor, 0, $sheet, 0, 4)
        $filled = 4
        while ($filled -lt $sheet.Length) {
            $chunk = [Math]::Min($filled, $sheet.Length - $filled)
            [Array]::Copy($sheet, 0, $sheet, $filled, $chunk)
            $filled += $chunk
        }
    }

    for ($index = 0; $index -lt $Images.Count; $index++) {
        $image = $Images[$index]
        $column = $index % $columnsUsed
        $row = [int][Math]::Floor($index / $columnsUsed)
        $originX = $GapPixels + ($column * ($cellWidth + $GapPixels))
        $originY = $GapPixels + ($row * ($cellHeight + $GapPixels))
        for ($y = 0; $y -lt $image.Height; $y++) {
            for ($x = 0; $x -lt $image.Width; $x++) {
                $sourceOffset = (($y * $image.Width) + $x) * 4
                if ($image.Pixels[$sourceOffset + 3] -eq 0) {
                    continue
                }
                $targetOffset = ((($originY + $y) * $sheetWidth) + $originX + $x) * 4
                [Array]::Copy($image.Pixels, $sourceOffset, $sheet, $targetOffset, 4)
            }
        }
    }

    return [pscustomobject]@{
        Width = $sheetWidth
        Height = $sheetHeight
        Pixels = $sheet
        CellWidth = $cellWidth
        CellHeight = $cellHeight
        Columns = $columnsUsed
        Rows = $rowsUsed
    }
}

function New-DifferencePixels {
    # Builds the third -Compare panel: a pixel that is identical in both images becomes the
    # grayscale candidate pixel (alpha kept), and a pixel that differs in any channel becomes
    # opaque red. The counts say how the differences split between color changes and
    # transparency changes.
    param(
        [Parameter(Mandatory = $true)]
        [object]$ReferenceImage,

        [Parameter(Mandatory = $true)]
        [object]$CandidateImage
    )

    $pixelCount = $CandidateImage.Width * $CandidateImage.Height
    $difference = [byte[]](Convert-PixelsToGrayscale -Pixels $CandidateImage.Pixels)
    $colorChanged = 0
    $becameTransparent = 0
    $becameOpaque = 0
    for ($offset = 0; $offset -lt $difference.Length; $offset += 4) {
        $same = $true
        for ($channel = 0; $channel -lt 4; $channel++) {
            if ($ReferenceImage.Pixels[$offset + $channel] -ne $CandidateImage.Pixels[$offset + $channel]) {
                $same = $false
                break
            }
        }
        if ($same) {
            continue
        }

        $referenceAlpha = $ReferenceImage.Pixels[$offset + 3]
        $candidateAlpha = $CandidateImage.Pixels[$offset + 3]
        if ($referenceAlpha -ne 0 -and $candidateAlpha -eq 0) {
            $becameTransparent++
        }
        elseif ($referenceAlpha -eq 0 -and $candidateAlpha -ne 0) {
            $becameOpaque++
        }
        else {
            $colorChanged++
        }

        $difference[$offset] = 255
        $difference[$offset + 1] = 32
        $difference[$offset + 2] = 32
        $difference[$offset + 3] = 255
    }

    return [pscustomobject]@{
        Width = $CandidateImage.Width
        Height = $CandidateImage.Height
        Pixels = $difference
        Label = 'difference'
        PixelCount = $pixelCount
        Different = $colorChanged + $becameTransparent + $becameOpaque
        ColorChanged = $colorChanged
        BecameTransparent = $becameTransparent
        BecameOpaque = $becameOpaque
    }
}

function Get-SheetScale {
    param(
        [Parameter(Mandatory = $true)]
        [int]$CellWidth,

        [Parameter(Mandatory = $true)]
        [int]$CellHeight,

        [int]$RequestedScale
    )

    if ($RequestedScale -ne 0) {
        return $RequestedScale
    }
    $largestDimension = [Math]::Max($CellWidth, $CellHeight)
    $automatic = [int][Math]::Floor(256 / $largestDimension)
    return [Math]::Max(1, [Math]::Min(16, $automatic))
}

function Write-ScaledSheet {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Sheet,

        [Parameter(Mandatory = $true)]
        [int]$Scale,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $scaled = Resize-PixelsNearestNeighbor -Pixels $Sheet.Pixels -ImageWidth $Sheet.Width -ImageHeight $Sheet.Height -Scale $Scale
    $bytes = New-PngBytesFromPixels -ImageWidth $scaled.Width -ImageHeight $scaled.Height -Pixels $scaled.Pixels
    $parentDirectory = [IO.Path]::GetDirectoryName($Destination)
    if (-not [IO.Directory]::Exists($parentDirectory)) {
        [IO.Directory]::CreateDirectory($parentDirectory) | Out-Null
    }
    [IO.File]::WriteAllBytes($Destination, [byte[]]$bytes)
    return $scaled
}

function Assert-SheetModeOptions {
    param([string]$Mode)

    if ($Review -or $TilePreview -or -not [string]::IsNullOrWhiteSpace($ReviewDirectory)) {
        throw "$Mode cannot be combined with -Review, -TilePreview, or -ReviewDirectory; the sheet is already a review image."
    }
    if (-not [string]::IsNullOrWhiteSpace($OutputDirectory) -or $OutputBesideSpecification -or -not [string]::IsNullOrWhiteSpace($Name)) {
        throw "$Mode cannot be combined with -OutputDirectory, -OutputBesideSpecification, or -Name. Use -OutputFile, or accept the default beside the first input."
    }
}

function Resolve-SheetOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FirstInputPath,

        [Parameter(Mandatory = $true)]
        [string]$Suffix
    )

    if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
        $destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    }
    else {
        $stem = [IO.Path]::GetFileNameWithoutExtension($FirstInputPath)
        $destination = Join-Path ([IO.Path]::GetDirectoryName($FirstInputPath)) "$stem-$Suffix.png"
    }

    if (-not $destination.EndsWith('.png', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The output file must use the .png extension.'
    }
    if ([IO.File]::Exists($destination) -and -not $Force) {
        throw "Output already exists: $destination. Use -Force to replace it."
    }
    return $destination
}

function Get-BackgroundColor {
    if ([string]::IsNullOrWhiteSpace($Background)) {
        return [byte[]]@(0, 0, 0, 0)
    }
    if ($Background -notmatch '^#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?$') {
        throw "-Background must be #RRGGBB or #RRGGBBAA, not '$Background'."
    }
    return Convert-HexColor -Hex $Background -LineNumber 0
}

function Invoke-ComposeMode {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Inputs
    )

    Assert-SheetModeOptions -Mode '-Compose'
    if (-not [string]::IsNullOrWhiteSpace($Reference)) {
        throw '-Reference belongs to -Compare, not -Compose. List every input after -Compose instead.'
    }

    $images = New-Object 'System.Collections.Generic.List[object]'
    foreach ($input in $Inputs) {
        $images.Add((Get-InputImage -Path $input -CommandPreset $Preset -CommandWidth $Width -CommandHeight $Height))
    }

    $columnCount = $images.Count
    if ($Columns -ne 0) {
        $columnCount = $Columns
    }

    $destination = Resolve-SheetOutput -FirstInputPath $images[0].Path -Suffix 'sheet'
    $sheet = New-SheetPixels -Images $images.ToArray() -ColumnCount $columnCount -GapPixels $Gap -BackgroundColor (Get-BackgroundColor)
    $scale = Get-SheetScale -CellWidth $sheet.CellWidth -CellHeight $sheet.CellHeight -RequestedScale $PreviewScale
    $scaled = Write-ScaledSheet -Sheet $sheet -Scale $scale -Destination $destination

    Write-Output "Created $destination ($($scaled.Width)x$($scaled.Height), $($images.Count) inputs in $($sheet.Columns)x$($sheet.Rows) cells of $($sheet.CellWidth)x$($sheet.CellHeight), gap $Gap, nearest-neighbor scale ${scale}x)"
    for ($index = 0; $index -lt $images.Count; $index++) {
        $image = $images[$index]
        $column = $index % $sheet.Columns
        $row = [int][Math]::Floor($index / $sheet.Columns)
        Write-Output "  cell row $($row + 1) column $($column + 1): $($image.Label) ($($image.Width)x$($image.Height))"
    }
}

function Invoke-CompareMode {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Inputs
    )

    Assert-SheetModeOptions -Mode '-Compare'
    if ($Inputs.Count -ne 1) {
        throw '-Compare takes exactly one candidate input plus -Reference <png or pixelart>.'
    }
    if ([string]::IsNullOrWhiteSpace($Reference)) {
        throw '-Compare needs -Reference <png or pixelart>, the image the candidate is checked against.'
    }
    if ($Columns -ne 0) {
        throw '-Columns applies to -Compose only; -Compare always uses one row.'
    }

    $referenceImage = Get-InputImage -Path $Reference -CommandPreset $Preset -CommandWidth $Width -CommandHeight $Height
    $referenceImage.Label = "reference $($referenceImage.Label)"
    $candidateImage = Get-InputImage -Path $Inputs[0] -CommandPreset $Preset -CommandWidth $Width -CommandHeight $Height
    $candidateImage.Label = "candidate $($candidateImage.Label)"

    $panels = New-Object 'System.Collections.Generic.List[object]'
    $panels.Add($referenceImage)
    $panels.Add($candidateImage)

    $difference = $null
    $sameSize = ($referenceImage.Width -eq $candidateImage.Width) -and ($referenceImage.Height -eq $candidateImage.Height)
    if ($sameSize) {
        $difference = New-DifferencePixels -ReferenceImage $referenceImage -CandidateImage $candidateImage
        $panels.Add($difference)
    }

    $destination = Resolve-SheetOutput -FirstInputPath $candidateImage.Path -Suffix 'compare'
    $sheet = New-SheetPixels -Images $panels.ToArray() -ColumnCount $panels.Count -GapPixels $Gap -BackgroundColor (Get-BackgroundColor)
    $scale = Get-SheetScale -CellWidth $sheet.CellWidth -CellHeight $sheet.CellHeight -RequestedScale $PreviewScale
    $scaled = Write-ScaledSheet -Sheet $sheet -Scale $scale -Destination $destination

    Write-Output "Created $destination ($($scaled.Width)x$($scaled.Height), nearest-neighbor scale ${scale}x)"
    Write-Output "  panel 1: $($referenceImage.Label) ($($referenceImage.Width)x$($referenceImage.Height))"
    Write-Output "  panel 2: $($candidateImage.Label) ($($candidateImage.Width)x$($candidateImage.Height))"
    if ($sameSize) {
        Write-Output '  panel 3: difference (gray = same pixel, red = different pixel)'
        $percent = [Math]::Round((100.0 * $difference.Different) / $difference.PixelCount, 1)
        Write-Output "Different pixels: $($difference.Different) of $($difference.PixelCount) ($percent%): $($difference.ColorChanged) changed color or alpha, $($difference.BecameTransparent) opaque in the reference but transparent in the candidate, $($difference.BecameOpaque) transparent in the reference but opaque in the candidate"
    }
    else {
        Write-Output "Sizes differ (reference $($referenceImage.Width)x$($referenceImage.Height), candidate $($candidateImage.Width)x$($candidateImage.Height)); no difference panel was made."
    }
}

if ($ListPresets) {
    Show-Presets
    return
}

$inputs = @(@($InputFile) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($Compose -and $Compare) {
    throw 'Use either -Compose or -Compare, not both.'
}

if ($Compose) {
    if ($inputs.Count -lt 1) {
        throw '-Compose needs at least one .pixelart or .png input.'
    }
    Invoke-ComposeMode -Inputs $inputs
    return
}

if ($Compare) {
    Invoke-CompareMode -Inputs $inputs
    return
}

if (-not [string]::IsNullOrWhiteSpace($Reference)) {
    throw '-Reference is only used with -Compare.'
}

if ($inputs.Count -eq 0) {
    throw 'Provide a .pixelart specification file, or use -ListPresets.'
}

if ($inputs.Count -gt 1) {
    throw 'Provide one specification for a normal render. Add -Compose to place several inputs on one sheet, or -Compare with -Reference to check one candidate against another image.'
}

$resolvedInput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($inputs[0])
if (-not [IO.File]::Exists($resolvedInput)) {
    throw "Input file not found: $resolvedInput"
}

$spec = Read-PixelArtSpec -Path $resolvedInput
Assert-ExpectedDimensions -Spec $spec -CommandPreset $Preset -CommandWidth $Width -CommandHeight $Height

$effectivePreset = $null
if (-not [string]::IsNullOrWhiteSpace($spec.Preset)) {
    $effectivePreset = $spec.Preset.ToLowerInvariant().Replace('-', '_')
}
if (-not [string]::IsNullOrWhiteSpace($Preset)) {
    $effectivePreset = $Preset.ToLowerInvariant().Replace('-', '_')
}

$reviewRequested = $Review -or $TilePreview -or -not [string]::IsNullOrWhiteSpace($ReviewDirectory) -or $PreviewScale -ne 0

if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
    if (-not [string]::IsNullOrWhiteSpace($OutputDirectory) -or $OutputBesideSpecification -or -not [string]::IsNullOrWhiteSpace($Name)) {
        throw '-OutputFile cannot be combined with -OutputDirectory, -OutputBesideSpecification, or -Name.'
    }
    $resolvedOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
}
else {
    if ($OutputBesideSpecification -and -not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
        throw '-OutputBesideSpecification cannot be combined with -OutputDirectory.'
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        if (-not [string]::IsNullOrWhiteSpace($spec.Name)) {
            $Name = $spec.Name
        }
        else {
            $Name = [IO.Path]::GetFileNameWithoutExtension($resolvedInput)
        }
    }

    Assert-SafeName -Candidate $Name
    $assetId = [IO.Path]::GetFileNameWithoutExtension($Name)

    if ($OutputBesideSpecification) {
        $OutputDirectory = [IO.Path]::GetDirectoryName($resolvedInput)
    }
    elseif ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        if (-not [string]::IsNullOrWhiteSpace($env:MINECRAFT_PIXELART_OUTPUT_DIR)) {
            $OutputDirectory = $env:MINECRAFT_PIXELART_OUTPUT_DIR
        }
        else {
            $possibleWorkflowRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
            $workflowMarker = Join-Path $possibleWorkflowRoot 'AGENTS.md'
            $workflowWorkspace = Join-Path $possibleWorkflowRoot 'workspace'
            if ([IO.File]::Exists($workflowMarker) -and [IO.Directory]::Exists($workflowWorkspace)) {
                $OutputDirectory = Join-Path $workflowWorkspace (Join-Path 'artwork\pixelart' (Join-Path $assetId 'candidates'))
            }
            else {
                $OutputDirectory = Join-Path (Get-Location) 'generated'
            }
        }
    }

    if (-not $Name.EndsWith('.png', [StringComparison]::OrdinalIgnoreCase)) {
        $Name = "$Name.png"
    }

    $resolvedDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
    $resolvedOutput = Join-Path $resolvedDirectory $Name
}

if (-not $resolvedOutput.EndsWith('.png', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The output file must use the .png extension.'
}

$reviewPaths = $null
$resolvedReviewDirectory = $null
$scale = 0
$shouldCreateTilePreview = $false
if ($reviewRequested) {
    if ($PreviewScale -ne 0) {
        $scale = $PreviewScale
    }
    else {
        $largestDimension = [Math]::Max($spec.Width, $spec.Height)
        $scale = [int][Math]::Floor(256 / $largestDimension)
        $scale = [Math]::Max(1, [Math]::Min(16, $scale))
    }

    if (($spec.Width * $scale) -gt 4096 -or ($spec.Height * $scale) -gt 4096) {
        throw "Review scale $scale is too large for a $($spec.Width)x$($spec.Height) asset. Keep each review dimension at or below 4096 pixels."
    }

    $outputStem = [IO.Path]::GetFileNameWithoutExtension($resolvedOutput)
    if ([string]::IsNullOrWhiteSpace($ReviewDirectory)) {
        $resolvedReviewDirectory = Join-Path ([IO.Path]::GetDirectoryName($resolvedOutput)) "$outputStem-review"
    }
    else {
        $resolvedReviewDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReviewDirectory)
    }

    $reviewPaths = [ordered]@{
        Zoom = Join-Path $resolvedReviewDirectory "$outputStem-review-zoom.png"
        Grayscale = Join-Path $resolvedReviewDirectory "$outputStem-review-grayscale.png"
    }

    $shouldCreateTilePreview = $TilePreview -or $effectivePreset -eq 'block'
    if ($shouldCreateTilePreview) {
        $reviewPaths['Tile'] = Join-Path $resolvedReviewDirectory "$outputStem-review-tile-3x3.png"
    }
}

$plannedOutputs = New-Object 'System.Collections.Generic.List[string]'
$plannedOutputs.Add($resolvedOutput)
if ($reviewRequested) {
    foreach ($path in $reviewPaths.Values) {
        $plannedOutputs.Add($path)
    }
}

foreach ($path in $plannedOutputs) {
    if ([IO.File]::Exists($path) -and -not $Force) {
        throw "Output already exists: $path. Use -Force to replace it."
    }
}

foreach ($path in $plannedOutputs) {
    $parentDirectory = [IO.Path]::GetDirectoryName($path)
    if (-not [IO.Directory]::Exists($parentDirectory)) {
        [IO.Directory]::CreateDirectory($parentDirectory) | Out-Null
    }
}

$pixels = Get-SpecPixels -Spec $spec
$pngBytes = New-PngBytesFromPixels -ImageWidth $spec.Width -ImageHeight $spec.Height -Pixels $pixels
[IO.File]::WriteAllBytes($resolvedOutput, [byte[]]$pngBytes)

Write-Output "Created $resolvedOutput ($($spec.Width)x$($spec.Height), RGBA PNG)"

if ($reviewRequested) {
    $zoom = Resize-PixelsNearestNeighbor -Pixels $pixels -ImageWidth $spec.Width -ImageHeight $spec.Height -Scale $scale
    $zoomBytes = New-PngBytesFromPixels -ImageWidth $zoom.Width -ImageHeight $zoom.Height -Pixels $zoom.Pixels
    [IO.File]::WriteAllBytes($reviewPaths['Zoom'], [byte[]]$zoomBytes)

    $grayscalePixels = Convert-PixelsToGrayscale -Pixels $pixels
    $grayscale = Resize-PixelsNearestNeighbor -Pixels $grayscalePixels -ImageWidth $spec.Width -ImageHeight $spec.Height -Scale $scale
    $grayscaleBytes = New-PngBytesFromPixels -ImageWidth $grayscale.Width -ImageHeight $grayscale.Height -Pixels $grayscale.Pixels
    [IO.File]::WriteAllBytes($reviewPaths['Grayscale'], [byte[]]$grayscaleBytes)

    Write-Output "Created review previews in $resolvedReviewDirectory (nearest-neighbor scale ${scale}x)"

    if ($shouldCreateTilePreview) {
        $tile = New-TiledPixels -Pixels $pixels -ImageWidth $spec.Width -ImageHeight $spec.Height -Across 3 -Down 3
        $maximumTileScale = [int][Math]::Floor(384 / [Math]::Max($tile.Width, $tile.Height))
        $tileScale = [Math]::Max(1, [Math]::Min($scale, $maximumTileScale))
        $scaledTile = Resize-PixelsNearestNeighbor -Pixels $tile.Pixels -ImageWidth $tile.Width -ImageHeight $tile.Height -Scale $tileScale
        $tileBytes = New-PngBytesFromPixels -ImageWidth $scaledTile.Width -ImageHeight $scaledTile.Height -Pixels $scaledTile.Pixels
        [IO.File]::WriteAllBytes($reviewPaths['Tile'], [byte[]]$tileBytes)
        Write-Output "Created 3x3 tile review at $($reviewPaths['Tile']) (nearest-neighbor scale ${tileScale}x)"
    }
}

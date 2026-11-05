param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskAssets = Join-Path $ProjectRoot 'assets'
[IO.Directory]::CreateDirectory($taskAssets) | Out-Null
$taskPalette = @{ ready = '#0f766e'; waiting = '#2563eb'; paused = '#64748b' }
$taskSvg = New-Object Xml.XmlDocument
$taskSvg.Load((Join-Path $taskAssets 'bridge-icon.svg'))
$taskCulture = [Globalization.CultureInfo]::InvariantCulture
function Get-SvgNumber($Node, [string]$Name) {
    $taskValue = $Node.GetAttribute($Name)
    if ($taskValue -eq '') { return [single]0 }
    return [single]::Parse($taskValue, $script:taskCulture)
}
function New-BridgeBitmap([int]$Size, [string]$Color) {
    # Render the font-free SVG master at 4x for smooth small tray sizes.
    $taskScale = 4
    $taskHi = New-Object Drawing.Bitmap(($Size * $taskScale), ($Size * $taskScale))
    $taskG = [Drawing.Graphics]::FromImage($taskHi)
    $taskG.Clear([Drawing.Color]::Transparent)
    $taskG.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $taskG.ScaleTransform(($Size * $taskScale / 64.0), ($Size * $taskScale / 64.0))
    try {
        foreach ($taskNode in $script:taskSvg.DocumentElement.ChildNodes) {
            if ($taskNode.LocalName -eq 'title') { continue }
            $taskFill = if ($taskNode.GetAttribute('fill') -eq 'currentColor') { $Color } else { $taskNode.GetAttribute('fill') }
            $taskBrush = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml($taskFill))
            try {
                switch ($taskNode.LocalName) {
                    'rect' {
                        $taskX = Get-SvgNumber $taskNode 'x'; $taskY = Get-SvgNumber $taskNode 'y'
                        $taskW = Get-SvgNumber $taskNode 'width'; $taskH = Get-SvgNumber $taskNode 'height'
                        $taskRadius = Get-SvgNumber $taskNode 'rx'
                        if ($taskRadius -gt 0) {
                            $taskPath = New-Object Drawing.Drawing2D.GraphicsPath
                            $taskD = $taskRadius * 2
                            try {
                                $taskPath.AddArc($taskX, $taskY, $taskD, $taskD, 180, 90)
                                $taskPath.AddArc(($taskX + $taskW - $taskD), $taskY, $taskD, $taskD, 270, 90)
                                $taskPath.AddArc(($taskX + $taskW - $taskD), ($taskY + $taskH - $taskD), $taskD, $taskD, 0, 90)
                                $taskPath.AddArc($taskX, ($taskY + $taskH - $taskD), $taskD, $taskD, 90, 90)
                                $taskPath.CloseFigure()
                                $taskG.FillPath($taskBrush, $taskPath)
                            } finally { $taskPath.Dispose() }
                        } else { $taskG.FillRectangle($taskBrush, $taskX, $taskY, $taskW, $taskH) }
                    }
                    'ellipse' {
                        $taskRx = Get-SvgNumber $taskNode 'rx'; $taskRy = Get-SvgNumber $taskNode 'ry'
                        $taskCx = Get-SvgNumber $taskNode 'cx'; $taskCy = Get-SvgNumber $taskNode 'cy'
                        $taskG.FillEllipse($taskBrush, ($taskCx - $taskRx), ($taskCy - $taskRy), ($taskRx * 2), ($taskRy * 2))
                    }
                    'polygon' {
                        $taskPoints = foreach ($taskPair in ($taskNode.GetAttribute('points') -split '\s+')) {
                            $taskXY = $taskPair -split ','
                            [Drawing.PointF]::new([single]::Parse($taskXY[0], $script:taskCulture), [single]::Parse($taskXY[1], $script:taskCulture))
                        }
                        $taskG.FillPolygon($taskBrush, [Drawing.PointF[]]$taskPoints)
                    }
                    default { throw "Unsupported SVG element: $($taskNode.LocalName)" }
                }
            } finally { $taskBrush.Dispose() }
        }
        $taskBitmap = New-Object Drawing.Bitmap($Size, $Size)
        $taskDown = [Drawing.Graphics]::FromImage($taskBitmap)
        try {
            $taskDown.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
            $taskDown.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $taskDown.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $taskDown.DrawImage($taskHi, (New-Object Drawing.Rectangle(0, 0, $Size, $Size)), 0, 0, $taskHi.Width, $taskHi.Height, [Drawing.GraphicsUnit]::Pixel)
        } finally { $taskDown.Dispose() }
        return $taskBitmap
    } finally { $taskG.Dispose(); $taskHi.Dispose() }
}
foreach ($taskState in $taskPalette.Keys) {
    $taskImages = @()
    foreach ($taskSize in @(16, 20, 24, 32, 40, 48, 64, 128, 256)) {
        $taskBitmap = New-BridgeBitmap $taskSize $taskPalette[$taskState]
        if ($taskSize -eq 256) {
            $taskBitmap.Save((Join-Path $taskAssets "bridge-$taskState.png"), [Drawing.Imaging.ImageFormat]::Png)
        }
        $taskMemory = New-Object IO.MemoryStream
        # DIB-backed entries render consistently in both Shell_NotifyIcon and
        # older Windows/.NET icon consumers, including small notification icons.
        $taskPixels = New-Object IO.BinaryWriter($taskMemory)
        $taskPixels.Write([uint32]40)
        $taskPixels.Write([int32]$taskSize)
        $taskPixels.Write([int32]($taskSize * 2))
        $taskPixels.Write([uint16]1)
        $taskPixels.Write([uint16]32)
        $taskPixels.Write([uint32]0)
        $taskPixels.Write([uint32]($taskSize * $taskSize * 4))
        foreach ($taskZero in 1..4) { $taskPixels.Write([uint32]0) }
        for ($taskY = $taskSize - 1; $taskY -ge 0; $taskY--) {
            for ($taskX = 0; $taskX -lt $taskSize; $taskX++) {
                $taskPixel = $taskBitmap.GetPixel($taskX, $taskY)
                $taskPixels.Write([byte]$taskPixel.B)
                $taskPixels.Write([byte]$taskPixel.G)
                $taskPixels.Write([byte]$taskPixel.R)
                $taskPixels.Write([byte]$taskPixel.A)
            }
        }
        $taskMaskStride = [int]([Math]::Ceiling($taskSize / 32.0) * 4)
        for ($taskY = $taskSize - 1; $taskY -ge 0; $taskY--) {
            $taskMask = New-Object byte[] $taskMaskStride
            for ($taskX = 0; $taskX -lt $taskSize; $taskX++) {
                if ($taskBitmap.GetPixel($taskX, $taskY).A -eq 0) {
                    $taskByteIndex = [int][Math]::Floor($taskX / 8.0)
                    $taskMask[$taskByteIndex] = $taskMask[$taskByteIndex] -bor (0x80 -shr ($taskX % 8))
                }
            }
            $taskPixels.Write([byte[]]$taskMask)
        }
        $taskPixels.Flush()
        $taskImages += ,([pscustomobject]@{ size = $taskSize; bytes = $taskMemory.ToArray() })
        $taskPixels.Dispose()
        $taskBitmap.Dispose()
    }
    $taskOutput = [IO.File]::Create((Join-Path $taskAssets "bridge-$taskState.ico"))
    $taskWriter = New-Object IO.BinaryWriter($taskOutput)
    try {
        $taskWriter.Write([uint16]0)
        $taskWriter.Write([uint16]1)
        $taskWriter.Write([uint16]$taskImages.Count)
        $taskOffset = 6 + 16 * $taskImages.Count
        foreach ($taskImage in $taskImages) {
            $taskDimension = if ($taskImage.size -eq 256) { 0 } else { $taskImage.size }
            $taskWriter.Write([byte]$taskDimension)
            $taskWriter.Write([byte]$taskDimension)
            $taskWriter.Write([byte]0)
            $taskWriter.Write([byte]0)
            $taskWriter.Write([uint16]1)
            $taskWriter.Write([uint16]32)
            $taskWriter.Write([uint32]$taskImage.bytes.Length)
            $taskWriter.Write([uint32]$taskOffset)
            $taskOffset += $taskImage.bytes.Length
        }
        foreach ($taskImage in $taskImages) {
            $taskWriter.Write([byte[]]$taskImage.bytes)
        }
    } finally {
        $taskWriter.Dispose()
    }
}
Write-Output 'Built !Hangul state icons and settings logos from assets/bridge-icon.svg.'

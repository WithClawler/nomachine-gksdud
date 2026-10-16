param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskAssets = Join-Path $ProjectRoot 'assets'
[IO.Directory]::CreateDirectory($taskAssets) | Out-Null
$taskPalette = @{ ready = '#0f766e'; waiting = '#2563eb'; paused = '#64748b' }
foreach ($taskState in $taskPalette.Keys) {
    $taskImages = @()
    foreach ($taskSize in @(16, 20, 24, 32, 48, 64, 128, 256)) {
        $taskBitmap = New-Object Drawing.Bitmap($taskSize, $taskSize)
        $taskGraphics = [Drawing.Graphics]::FromImage($taskBitmap)
        $taskGraphics.Clear([Drawing.Color]::Transparent)
        $taskGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $taskGraphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $taskBackground = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml($taskPalette[$taskState]))
        $taskInset = [single]($taskSize * 0.03)
        $taskGraphics.FillEllipse($taskBackground, $taskInset, $taskInset, [single]($taskSize - 2 * $taskInset), [single]($taskSize - 2 * $taskInset))
        $taskFont = New-Object Drawing.Font('Malgun Gothic', [single]($taskSize * 0.64), [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
        $taskFormat = New-Object Drawing.StringFormat
        $taskFormat.Alignment = [Drawing.StringAlignment]::Center
        $taskFormat.LineAlignment = [Drawing.StringAlignment]::Center
        $taskRect = New-Object Drawing.RectangleF(0, [single](-$taskSize * 0.015), $taskSize, $taskSize)
        $taskGraphics.DrawString([string][char]0xd55c, $taskFont, [Drawing.Brushes]::White, $taskRect, $taskFormat)
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
        $taskFormat.Dispose()
        $taskFont.Dispose()
        $taskBackground.Dispose()
        $taskGraphics.Dispose()
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

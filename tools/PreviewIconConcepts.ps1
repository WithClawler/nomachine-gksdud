param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskConceptDir = Join-Path $ProjectRoot 'assets\concepts'
$taskOutputDir = Join-Path $ProjectRoot 'outputs'
[IO.Directory]::CreateDirectory($taskConceptDir) | Out-Null
[IO.Directory]::CreateDirectory($taskOutputDir) | Out-Null
$taskTeal = '#0f766e'
$taskConcepts = @(
    @{ Id = 'A'; Name = '한영 키캡'; Detail = '익숙한 한영키를 그대로'; Mark = '<text x="32" y="46" text-anchor="middle" fill="white" font-family="Malgun Gothic, sans-serif" font-weight="700" font-size="40">한</text>' },
    @{ Id = 'B'; Name = '연결 브리지'; Detail = 'Windows와 Mac을 잇는 다리'; Mark = '<path d="M15 47V30a17 17 0 0 1 34 0v17M15 31h34M32 16v31" fill="none" stroke="white" stroke-width="6" stroke-linecap="round"/>' },
    @{ Id = 'C'; Name = '전환 화살표'; Detail = '한 번의 누름으로 입력 소스 전환'; Mark = '<path d="M14 24h34l-8-8m8 8-8 8M50 40H16l8-8m-8 8 8 8" fill="none" stroke="white" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>' },
    @{ Id = 'D'; Name = '두 개의 키'; Detail = '로컬과 원격을 겹쳐 표현'; Mark = '<rect x="10" y="13" width="29" height="32" rx="5" fill="none" stroke="white" stroke-width="3"/><rect x="26" y="23" width="29" height="30" rx="5" fill="#0f766e" stroke="white" stroke-width="3"/><text x="23" y="36" text-anchor="middle" fill="white" font-family="Segoe UI, sans-serif" font-size="20" font-weight="700">A</text><text x="41" y="45" text-anchor="middle" fill="white" font-family="Malgun Gothic, sans-serif" font-size="19" font-weight="700">한</text>' }
)
foreach ($taskConcept in $taskConcepts) {
    $taskSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 64 64"><rect x="2" y="2" width="60" height="60" rx="15" fill="#0f766e"/>' + $taskConcept.Mark + '</svg>'
    [IO.File]::WriteAllText((Join-Path $taskConceptDir ($taskConcept.Id.ToLowerInvariant() + '.svg')), $taskSvg, (New-Object Text.UTF8Encoding($false)))
}

function New-RoundedPath([single]$X, [single]$Y, [single]$W, [single]$H, [single]$R) {
    $taskPath = New-Object Drawing.Drawing2D.GraphicsPath
    $taskD = $R * 2
    $taskPath.AddArc($X, $Y, $taskD, $taskD, 180, 90)
    $taskPath.AddArc(($X + $W - $taskD), $Y, $taskD, $taskD, 270, 90)
    $taskPath.AddArc(($X + $W - $taskD), ($Y + $H - $taskD), $taskD, $taskD, 0, 90)
    $taskPath.AddArc($X, ($Y + $H - $taskD), $taskD, $taskD, 90, 90)
    $taskPath.CloseFigure()
    return $taskPath
}
function Draw-CenteredText($G, [string]$Text, [string]$Family, [single]$Size, $Brush, [single]$X, [single]$Y, [single]$W, [single]$H) {
    $taskFont = New-Object Drawing.Font($Family, $Size, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $taskFormat = New-Object Drawing.StringFormat
    $taskFormat.Alignment = [Drawing.StringAlignment]::Center
    $taskFormat.LineAlignment = [Drawing.StringAlignment]::Center
    $G.DrawString($Text, $taskFont, $Brush, (New-Object Drawing.RectangleF($X, $Y, $W, $H)), $taskFormat)
    $taskFont.Dispose()
    $taskFormat.Dispose()
}
function New-ConceptBitmap([string]$Id, [int]$Size, [string]$Color = '#0f766e') {
    $taskBitmap = New-Object Drawing.Bitmap($Size, $Size)
    $taskG = [Drawing.Graphics]::FromImage($taskBitmap)
    $taskG.Clear([Drawing.Color]::Transparent)
    $taskG.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $taskG.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $taskG.ScaleTransform(($Size / 64.0), ($Size / 64.0))
    $taskBrush = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml($Color))
    $taskShape = New-RoundedPath 2 2 60 60 15
    $taskG.FillPath($taskBrush, $taskShape)
    $taskShape.Dispose()
    $taskPen = New-Object Drawing.Pen([Drawing.Color]::White, 5)
    $taskPen.StartCap = [Drawing.Drawing2D.LineCap]::Round
    $taskPen.EndCap = [Drawing.Drawing2D.LineCap]::Round
    $taskPen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
    switch ($Id) {
        'A' { Draw-CenteredText $taskG '한' 'Malgun Gothic' 40 ([Drawing.Brushes]::White) 0 -1 64 64 }
        'B' {
            $taskPen.Width = 6
            $taskG.DrawLine($taskPen, 15, 47, 15, 30)
            $taskG.DrawArc($taskPen, 15, 13, 34, 34, 180, 180)
            $taskG.DrawLine($taskPen, 49, 30, 49, 47)
            $taskG.DrawLine($taskPen, 15, 31, 49, 31)
            $taskG.DrawLine($taskPen, 32, 16, 32, 47)
        }
        'C' {
            $taskG.DrawLines($taskPen, [Drawing.PointF[]]@([Drawing.PointF]::new(14,24),[Drawing.PointF]::new(48,24),[Drawing.PointF]::new(40,16)))
            $taskG.DrawLine($taskPen, 48, 24, 40, 32)
            $taskG.DrawLines($taskPen, [Drawing.PointF[]]@([Drawing.PointF]::new(50,40),[Drawing.PointF]::new(16,40),[Drawing.PointF]::new(24,32)))
            $taskG.DrawLine($taskPen, 16, 40, 24, 48)
        }
        'D' {
            $taskPen.Width = 3
            $taskBack = New-RoundedPath 10 13 29 32 5
            $taskG.DrawPath($taskPen, $taskBack)
            Draw-CenteredText $taskG 'A' 'Segoe UI' 20 ([Drawing.Brushes]::White) 9 13 29 32
            $taskFront = New-RoundedPath 26 23 29 30 5
            $taskG.FillPath($taskBrush, $taskFront)
            $taskG.DrawPath($taskPen, $taskFront)
            Draw-CenteredText $taskG '한' 'Malgun Gothic' 19 ([Drawing.Brushes]::White) 26 22 29 30
            $taskBack.Dispose()
            $taskFront.Dispose()
        }
    }
    $taskPen.Dispose()
    $taskBrush.Dispose()
    $taskG.Dispose()
    return $taskBitmap
}

$taskBoard = New-Object Drawing.Bitmap(1280, 720)
$taskG = [Drawing.Graphics]::FromImage($taskBoard)
$taskG.Clear([Drawing.ColorTranslator]::FromHtml('#f4f6f8'))
$taskG.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$taskG.TextRenderingHint = [Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$taskTitleFont = New-Object Drawing.Font('Segoe UI', 30, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$taskNameFont = New-Object Drawing.Font('Malgun Gothic', 21, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$taskSmallFont = New-Object Drawing.Font('Malgun Gothic', 13, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$taskInk = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#172b3a'))
$taskMuted = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#596b78'))
$taskDark = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#18242f'))
$taskG.DrawString('NoMachine Hangul Bridge', $taskTitleFont, $taskInk, 36, 28)
$taskG.DrawString('아이콘 시안 A–D  ·  밝은 배경 / 어두운 배경 / 실제 알림 영역 크기', $taskSmallFont, $taskMuted, 38, 76)
for ($taskI = 0; $taskI -lt 4; $taskI++) {
    $taskX = 36 + 310 * $taskI
    $taskConcept = $taskConcepts[$taskI]
    $taskCard = New-RoundedPath $taskX 120 280 550 18
    $taskG.FillPath([Drawing.Brushes]::White, $taskCard)
    $taskCard.Dispose()
    $taskG.DrawString(($taskConcept.Id + '  ' + $taskConcept.Name), $taskNameFont, $taskInk, ($taskX + 20), 142)
    $taskG.DrawString($taskConcept.Detail, $taskSmallFont, $taskMuted, ($taskX + 20), 178)
    $taskLarge = New-ConceptBitmap $taskConcept.Id 144
    $taskG.DrawImageUnscaled($taskLarge, ($taskX + 68), 222)
    $taskLarge.Dispose()
    $taskG.DrawString('64 / 32 / 16 px', $taskSmallFont, $taskMuted, ($taskX + 20), 392)
    $taskG.FillRectangle($taskDark, ($taskX + 16), 498, 248, 86)
    foreach ($taskSize in @(64,32,16)) {
        $taskOffset = switch ($taskSize) { 64 { 28 }; 32 { 130 }; 16 { 210 } }
        $taskSmall = New-ConceptBitmap $taskConcept.Id $taskSize
        $taskG.DrawImageUnscaled($taskSmall, ($taskX + $taskOffset), (430 + [int]((64 - $taskSize) / 2)))
        $taskG.DrawImageUnscaled($taskSmall, ($taskX + $taskOffset), (510 + [int]((64 - $taskSize) / 2)))
        $taskSmall.Dispose()
    }
    foreach ($taskState in @(@{X=28;Color='#0f766e'},@{X=66;Color='#2563eb'},@{X=104;Color='#64748b'})) {
        $taskStateIcon = New-ConceptBitmap $taskConcept.Id 24 $taskState.Color
        $taskG.DrawImageUnscaled($taskStateIcon, ($taskX + $taskState.X), 615)
        $taskStateIcon.Dispose()
    }
    $taskG.DrawString('준비 / 대기 / 중지', $taskSmallFont, $taskMuted, ($taskX + 140), 617)
}
$taskBoard.Save((Join-Path $taskOutputDir 'icon-concepts.png'), [Drawing.Imaging.ImageFormat]::Png)
$taskG.Dispose()
$taskBoard.Dispose()
$taskTitleFont.Dispose()
$taskNameFont.Dispose()
$taskSmallFont.Dispose()
$taskInk.Dispose()
$taskMuted.Dispose()
$taskDark.Dispose()
Write-Output "Icon concepts saved: $taskConceptDir"
Write-Output "Comparison saved: $taskOutputDir\icon-concepts.png"

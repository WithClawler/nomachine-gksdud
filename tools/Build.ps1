param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$SkipInstaller,
    [string]$IsccPath = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$taskVersion = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'VERSION')).Trim()
if ($taskVersion -notmatch '^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$') { throw 'Invalid VERSION.' }
$taskDeps = [IO.File]::ReadAllText((Join-Path $ProjectRoot 'build-dependencies.json')) | ConvertFrom-Json
$taskManifest = Get-Content -LiteralPath (Join-Path $ProjectRoot 'distribution-files.json') -Raw | ConvertFrom-Json
$taskBuildRoot = Join-Path $ProjectRoot 'build'
$taskDist = Join-Path $ProjectRoot 'dist'
[IO.Directory]::CreateDirectory($taskBuildRoot) | Out-Null
[IO.Directory]::CreateDirectory($taskDist) | Out-Null
# Only discard this tool's old generated packages. Unexpected files fail inspection.
Get-ChildItem -LiteralPath $taskDist -File | Where-Object { $_.Name -match '^NoMachineHangulBridge-.+\.(zip|exe)$|^SHA256SUMS\.txt$' } | Remove-Item
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-TaskHash([string]$Path) {
    $taskStream = [IO.File]::OpenRead($Path)
    $taskSha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($taskSha.ComputeHash($taskStream))).Replace('-', '').ToLowerInvariant() }
    finally { $taskStream.Dispose(); $taskSha.Dispose() }
}

function Get-VerifiedDownload([string]$Url, [string]$Path, [string]$Sha256) {
    if (!(Test-Path -LiteralPath $Path)) {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Path
    }
    if ((Get-TaskHash $Path) -ne $Sha256) { throw "SHA256 mismatch: $Path. Remove the cached file and retry." }
}

function New-TaskZip([string]$Folder, [string]$Path) {
    $taskStream = [IO.File]::Create($Path)
    $taskZip = New-Object IO.Compression.ZipArchive($taskStream, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($taskFile in Get-ChildItem -LiteralPath $Folder -Recurse -File -Force) {
            $taskRelative = $taskFile.FullName.Substring($Folder.Length + 1).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($taskZip, $taskFile.FullName, $taskRelative, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally { $taskZip.Dispose(); $taskStream.Dispose() }
}

function Copy-ManifestFiles([string[]]$Paths, [string]$Destination) {
    $taskSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($taskRelative in $Paths) {
        if (!$taskSeen.Add($taskRelative) -or $taskRelative -match '(^/|\\|:|(^|/)\.\.(/|$)|(^|/)(\.git|\.nx|\.ssh)(/|$)|\.(ini|nxs|lnk|key|pem|log)$)') {
            throw "Unsafe or duplicate manifest path: $taskRelative"
        }
        $taskInput = Join-Path $ProjectRoot $taskRelative
        $taskItem = Get-Item -LiteralPath $taskInput
        if ($taskItem.PSIsContainer) { throw 'Manifest entries must be files.' }
        $taskCheck = $taskItem
        while ($taskCheck.FullName -ne $ProjectRoot) {
            if ($taskCheck.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse points are not distributable.' }
            $taskCheck = if ($taskCheck -is [IO.FileInfo]) { $taskCheck.Directory } else { $taskCheck.Parent }
            if (!$taskCheck) { throw 'Manifest path escaped the project.' }
        }
        $taskOutput = Join-Path $Destination $taskRelative
        [IO.Directory]::CreateDirectory((Split-Path -Parent $taskOutput)) | Out-Null
        Copy-Item -LiteralPath $taskInput -Destination $taskOutput
    }
}

$taskAhk = $taskDeps.autohotkey
$taskRuntimeZip = Join-Path $taskBuildRoot "AutoHotkey-$($taskAhk.version).zip"
$taskSourceZip = Join-Path $taskBuildRoot "AutoHotkey-source-$($taskAhk.version).zip"
Get-VerifiedDownload $taskAhk.runtimeUrl $taskRuntimeZip $taskAhk.runtimeSha256
Get-VerifiedDownload $taskAhk.sourceUrl $taskSourceZip $taskAhk.sourceSha256
$taskRuntimeDir = Join-Path $taskBuildRoot ('runtime-' + [Guid]::NewGuid().ToString('N'))
[IO.Compression.ZipFile]::ExtractToDirectory($taskRuntimeZip, $taskRuntimeDir)
$taskRuntimeExe = Join-Path $taskRuntimeDir 'AutoHotkey64.exe'
if (!(Test-Path -LiteralPath $taskRuntimeExe)) { throw 'Official x64 runtime missing from archive.' }

foreach ($taskTest in @('BridgeApp.Tests.ahk', 'SessionDetector.Tests.ahk', 'Lifecycle.Tests.ahk')) {
    $taskTestPath = Join-Path $ProjectRoot "tests\$taskTest"
    $taskOut = Join-Path $taskBuildRoot "$taskTest.out"
    $taskErr = Join-Path $taskBuildRoot "$taskTest.err"
    $taskProcess = Start-Process -FilePath $taskRuntimeExe -ArgumentList ('/ErrorStdOut "' + $taskTestPath + '"') -WindowStyle Hidden -PassThru -RedirectStandardOutput $taskOut -RedirectStandardError $taskErr
    if (!$taskProcess.WaitForExit(60000)) {
        $taskProcess.Kill()
        throw "Test timed out: $taskTest"
    }
    $taskText = [IO.File]::ReadAllText($taskOut) + [IO.File]::ReadAllText($taskErr)
    Write-Output $taskText
    if ($taskProcess.ExitCode -ne 0 -or $taskText -notmatch 'PASS \d+') { throw "Tests failed: $taskTest" }
}
& (Join-Path $ProjectRoot 'tests\Process.Tests.ps1') -Runtime $taskRuntimeExe -ProjectRoot $ProjectRoot

$taskStage = Join-Path $taskBuildRoot ('stage-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($taskStage) | Out-Null
Copy-ManifestFiles $taskManifest.portable $taskStage
[IO.Directory]::CreateDirectory((Join-Path $taskStage 'runtime')) | Out-Null
Copy-Item -LiteralPath $taskRuntimeExe -Destination (Join-Path $taskStage 'runtime\AutoHotkey64.exe')
$taskNotices = Join-Path $taskStage 'third-party\AutoHotkey'
[IO.Directory]::CreateDirectory($taskNotices) | Out-Null
Copy-Item -LiteralPath (Join-Path $taskRuntimeDir 'license.txt') -Destination $taskNotices
Copy-Item -LiteralPath $taskSourceZip -Destination $taskNotices
New-TaskZip $taskStage (Join-Path $taskDist "NoMachineHangulBridge-$taskVersion-windows-x64-portable.zip")

if (!$SkipInstaller) {
    if (!(Test-Path -LiteralPath $IsccPath)) { throw 'Inno Setup 6 ISCC.exe missing. Install the build tool or use -SkipInstaller.' }
    $taskNumericVersion = ($taskVersion -split '-')[0] + '.0'
    & $IsccPath "/DAppVersion=$taskVersion" "/DAppNumericVersion=$taskNumericVersion" "/DStageDir=$taskStage" "/O$taskDist" (Join-Path $ProjectRoot 'installer\NoMachineHangulBridge.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
}

# Allowlist the source handoff; never package user profiles, NoMachine logs or keys.
$taskSourceStage = Join-Path $taskBuildRoot ('source-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($taskSourceStage) | Out-Null
Copy-ManifestFiles $taskManifest.source $taskSourceStage
New-TaskZip $taskSourceStage (Join-Path $taskDist "NoMachineHangulBridge-$taskVersion-source.zip")
$taskSums = foreach ($taskFile in Get-ChildItem -LiteralPath $taskDist -File | Where-Object { $_.Name -like "NoMachineHangulBridge-$taskVersion-*" }) {
    (Get-TaskHash $taskFile.FullName) + ' *' + $taskFile.Name
}
[IO.File]::WriteAllLines((Join-Path $taskDist 'SHA256SUMS.txt'), [string[]]$taskSums, (New-Object Text.UTF8Encoding($false)))
& (Join-Path $ProjectRoot 'tools\Test-Packages.ps1') -ProjectRoot $ProjectRoot -SkipInstaller:$SkipInstaller
Write-Output "Build completed: $taskDist"

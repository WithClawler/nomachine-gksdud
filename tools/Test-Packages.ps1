param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot), [switch]$SkipInstaller)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskVersion = (Get-Content (Join-Path $ProjectRoot 'VERSION') -Raw).Trim()
$taskDeps = Get-Content (Join-Path $ProjectRoot 'build-dependencies.json') -Raw | ConvertFrom-Json
$taskManifest = Get-Content (Join-Path $ProjectRoot 'distribution-files.json') -Raw | ConvertFrom-Json
$taskDist = Join-Path $ProjectRoot 'dist'
$taskNames = @("NoMachineHangulBridge-$taskVersion-windows-x64-portable.zip", "NoMachineHangulBridge-$taskVersion-source.zip")
if (!$SkipInstaller) { $taskNames += "NoMachineHangulBridge-$taskVersion-windows-x64-setup.exe" }
$taskExpectedDist = @($taskNames) + @('SHA256SUMS.txt')
$taskActualDist = @(Get-ChildItem -LiteralPath $taskDist -Recurse -File | ForEach-Object { $_.FullName.Substring($taskDist.Length + 1).Replace('\','/') })
if (Compare-Object $taskExpectedDist $taskActualDist -CaseSensitive) { throw 'Unexpected or missing distribution files.' }
$taskLines = @(Get-Content (Join-Path $taskDist 'SHA256SUMS.txt'))
if ($taskLines.Count -ne $taskNames.Count) { throw 'Wrong checksum count.' }
foreach ($taskName in $taskNames) {
    $taskHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $taskDist $taskName)).Hash.ToLowerInvariant()
    if ($taskLines -cnotcontains "$taskHash *$taskName") { throw "Checksum failed: $taskName" }
}
foreach ($taskKind in @('source', 'portable')) {
    $taskSuffix = if ($taskKind -eq 'source') { 'source' } else { 'windows-x64-portable' }
    $taskZip = [IO.Compression.ZipFile]::OpenRead((Join-Path $taskDist "NoMachineHangulBridge-$taskVersion-$taskSuffix.zip"))
    try {
        $taskExpected = @($taskManifest.$taskKind)
        if ($taskKind -eq 'portable') {
            $taskExpected += @('runtime/AutoHotkey64.exe', 'third-party/AutoHotkey/license.txt', "third-party/AutoHotkey/AutoHotkey-source-$($taskDeps.autohotkey.version).zip")
        }
        $taskActual = @($taskZip.Entries | ForEach-Object FullName)
        if (Compare-Object $taskExpected $taskActual -CaseSensitive) { throw "$taskKind ZIP does not match the allowlist." }
        if (($taskActual | Select-Object -Unique).Count -ne $taskActual.Count) { throw 'Duplicate ZIP entries.' }
        foreach ($taskRelative in $taskManifest.$taskKind) {
            $taskStream = $taskZip.GetEntry($taskRelative).Open()
            $taskSha = [Security.Cryptography.SHA256]::Create()
            try { $taskHash = ([BitConverter]::ToString($taskSha.ComputeHash($taskStream))).Replace('-', '') }
            finally { $taskStream.Dispose(); $taskSha.Dispose() }
            if ($taskHash -ne (Get-FileHash (Join-Path $ProjectRoot $taskRelative)).Hash) { throw "Packaged source changed: $taskRelative" }
        }
        if ($taskKind -eq 'portable') {
            $taskEntry = $taskZip.GetEntry("third-party/AutoHotkey/AutoHotkey-source-$($taskDeps.autohotkey.version).zip")
            $taskStream = $taskEntry.Open()
            $taskSha = [Security.Cryptography.SHA256]::Create()
            try { $taskHash = ([BitConverter]::ToString($taskSha.ComputeHash($taskStream))).Replace('-', '').ToLowerInvariant() }
            finally { $taskStream.Dispose(); $taskSha.Dispose() }
            if ($taskHash -ne $taskDeps.autohotkey.sourceSha256) { throw 'Bundled upstream source hash mismatch.' }
            if ($taskZip.GetEntry('third-party/AutoHotkey/license.txt').Length -lt 1000) { throw 'Runtime license missing or truncated.' }
            $taskExe = $taskZip.GetEntry('runtime/AutoHotkey64.exe').Open()
            try { if ($taskExe.ReadByte() -ne 77 -or $taskExe.ReadByte() -ne 90) { throw 'Runtime is not a Windows executable.' } }
            finally { $taskExe.Dispose() }
        }
    } finally { $taskZip.Dispose() }
}
Write-Output 'PASS package allowlists, source contents, upstream source and distribution SHA256 checks'

param([Parameter(Mandatory)][string]$Runtime, [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$taskRoot = Join-Path ([IO.Path]::GetTempPath()) ('nmhb-process-' + [guid]::NewGuid().ToString('N'))
$taskProcesses = [Collections.Generic.List[Diagnostics.Process]]::new()
$taskOriginalLocal = $env:LOCALAPPDATA
$taskChecks = 0
function Assert-Task([bool]$Condition, [string]$Label) {
    if (!$Condition) { throw "FAIL: $Label" }
    $script:taskChecks++
}
function Start-TaskAhk([string]$Arguments) {
    $taskProcess = Start-Process $Runtime -ArgumentList ('/ErrorStdOut ' + $Arguments) -PassThru
    $script:taskProcesses.Add($taskProcess)
    return $taskProcess
}
function Wait-TaskExit([Diagnostics.Process]$Process) {
    if (!$Process.WaitForExit(15000)) { throw 'Child process timed out.' }
    Assert-Task ($Process.ExitCode -eq 0) 'child process succeeds'
}
try {
    [IO.Directory]::CreateDirectory($taskRoot) | Out-Null
    $taskA = Join-Path $taskRoot 'development copy'
    $taskB = Join-Path $taskRoot 'updated copy'
    foreach ($taskCopy in @($taskA, $taskB)) {
        [IO.Directory]::CreateDirectory($taskCopy) | Out-Null
        foreach ($taskName in @('lib', 'assets', 'tests', 'NoMachineHangulBridge.ahk', 'VERSION')) {
            Copy-Item -LiteralPath (Join-Path $ProjectRoot $taskName) -Destination $taskCopy -Recurse
        }
    }
    $env:LOCALAPPDATA = Join-Path $taskRoot 'profile'
    $taskProfile = Join-Path $env:LOCALAPPDATA 'NoMachineHangulBridge'
    $taskWorker = Join-Path $taskA 'tests\ProfileWorker.ahk'
    Wait-TaskExit (Start-TaskAhk ('"' + $taskWorker + '" "' + $taskProfile + '" remember vkF2sc070'))
    Wait-TaskExit (Start-TaskAhk ('"' + $taskWorker + '" "' + $taskProfile + '" verify vkF2sc070'))
    $taskWorker = Join-Path $taskB 'tests\ProfileWorker.ahk'
    Wait-TaskExit (Start-TaskAhk ('"' + $taskWorker + '" "' + $taskProfile + '" verify vkF2sc070'))
    $taskSettings = Join-Path $taskProfile 'settings.ini'
    $taskHash = (Get-FileHash $taskSettings).Hash
    $taskResident = Join-Path $taskRoot 'unrelated.ahk'
    [IO.File]::WriteAllText($taskResident, "#Requires AutoHotkey v2.0`nPersistent()`nSetTimer(() => ExitApp(), -60000)`n")
    $taskUnrelated = Start-TaskAhk ('"' + $taskResident + '"')
    $taskFirst = Start-TaskAhk ('"' + (Join-Path $taskA 'NoMachineHangulBridge.ahk') + '" --quiet')
    Start-Sleep -Milliseconds 2000
    Assert-Task (!$taskFirst.HasExited) 'first copy stays running'
    $taskDuplicate = Start-TaskAhk ('"' + (Join-Path $taskB 'NoMachineHangulBridge.ahk') + '" --quiet')
    Wait-TaskExit $taskDuplicate
    Assert-Task (!$taskFirst.HasExited) 'duplicate does not terminate first copy'
    Assert-Task (!$taskUnrelated.HasExited) 'unrelated AHK survives'
    $taskFirst.Kill()
    $taskFirst.WaitForExit()
    $taskRestarted = Start-TaskAhk ('"' + (Join-Path $taskB 'NoMachineHangulBridge.ahk') + '" --quiet')
    Start-Sleep -Milliseconds 2000
    Assert-Task (!$taskRestarted.HasExited) 'updated folder starts after first exits'
    Assert-Task ((Get-FileHash $taskSettings).Hash -eq $taskHash) 'restart and folder update preserve exact profile'
    Write-Output "PASS $taskChecks process/persistence checks"
} finally {
    foreach ($taskProcess in $taskProcesses) {
        if (!$taskProcess.HasExited) { $taskProcess.Kill(); $taskProcess.WaitForExit() }
        $taskProcess.Dispose()
    }
    $env:LOCALAPPDATA = $taskOriginalLocal
    if (Test-Path $taskRoot) { Remove-Item -LiteralPath $taskRoot -Recurse -Force }
}

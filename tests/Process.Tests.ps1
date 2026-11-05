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
    $taskLog = Join-Path $script:taskRoot ([guid]::NewGuid().ToString('N'))
    $taskProcess = Start-Process $Runtime -ArgumentList ('/ErrorStdOut ' + $Arguments) -WindowStyle Hidden -PassThru -RedirectStandardOutput "$taskLog.out" -RedirectStandardError "$taskLog.err"
    $taskProcess | Add-Member NoteProperty OutputPath "$taskLog.out"
    $taskProcess | Add-Member NoteProperty ErrorPath "$taskLog.err"
    $script:taskProcesses.Add($taskProcess)
    return $taskProcess
}
function Wait-TaskExit([Diagnostics.Process]$Process) {
    $taskExited = $Process.WaitForExit(15000)
    Write-Output ([IO.File]::ReadAllText($Process.OutputPath) + [IO.File]::ReadAllText($Process.ErrorPath))
    if (!$taskExited) { throw 'Child process timed out.' }
    Assert-Task ($Process.ExitCode -eq 0) 'child process succeeds'
}
try {
    [IO.Directory]::CreateDirectory($taskRoot) | Out-Null
    $taskA = Join-Path $taskRoot 'development copy'
    $taskB = Join-Path $taskRoot 'updated copy'
    # Isolate only the mutex name in private test copies. A developer may have
    # the real app running; testing must neither reject nor disturb that app.
    $taskMutex = 'Local\NoMachineHangulBridge-ProcessTest-' + [guid]::NewGuid().ToString('N')
    foreach ($taskCopy in @($taskA, $taskB)) {
        [IO.Directory]::CreateDirectory($taskCopy) | Out-Null
        foreach ($taskName in @('lib', 'assets', 'tests', 'NoMachineHangulBridge.ahk', 'VERSION')) {
            Copy-Item -LiteralPath (Join-Path $ProjectRoot $taskName) -Destination $taskCopy -Recurse
        }
        $taskEntry = Join-Path $taskCopy 'NoMachineHangulBridge.ahk'
        $taskEntryText = [IO.File]::ReadAllText($taskEntry)
        $taskGuard = 'instance := BridgeInstance()'
        if ([regex]::Matches($taskEntryText, [regex]::Escape($taskGuard)).Count -ne 1) { throw 'Expected one application instance guard.' }
        $taskEntryText = $taskEntryText.Replace($taskGuard, ('instance := BridgeInstance("' + $taskMutex + '")'))
        [IO.File]::WriteAllText($taskEntry, $taskEntryText, [Text.UTF8Encoding]::new($true))
    }
    $env:LOCALAPPDATA = Join-Path $taskRoot 'profile'
    $taskProfile = Join-Path $env:LOCALAPPDATA 'NoMachineHangulBridge'
    $taskWorker = Join-Path $taskA 'tests\ProfileWorker.ahk'
    Wait-TaskExit (Start-TaskAhk ('"' + $taskWorker + '" "' + $taskProfile + '" remember vkF2sc070'))
    Wait-TaskExit (Start-TaskAhk ('"' + $taskWorker + '" "' + $taskProfile + '" verify vkF2sc070'))
    Wait-TaskExit (Start-TaskAhk ('"' + $taskWorker + '" "' + $taskProfile + '" close 1'))
    Wait-TaskExit (Start-TaskAhk ('"' + $taskWorker + '" "' + $taskProfile + '" close 0'))
    $taskWorker = Join-Path $taskB 'tests\ProfileWorker.ahk'
    Wait-TaskExit (Start-TaskAhk ('"' + $taskWorker + '" "' + $taskProfile + '" verify vkF2sc070'))
    Wait-TaskExit (Start-TaskAhk ('"' + $taskWorker + '" "' + $taskProfile + '" close 0'))
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

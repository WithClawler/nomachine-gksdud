param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Worker,
    [string]$FixtureRoot
)
$ErrorActionPreference = 'Stop'

if (!$Worker) {
    if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Account provisioning is restricted to an ephemeral GitHub Actions runner.' }
    $taskId = [guid]::NewGuid().ToString('N').Substring(0, 10)
    $taskUser = 'nmhb_' + $taskId
    $taskRoot = Join-Path $env:PUBLIC ('nmhb-install-' + $taskId)
    $taskCreatedUser = $false
    $taskWorker = $null
    try {
        [IO.Directory]::CreateDirectory($taskRoot) | Out-Null
        # Build the exact imported version for a real 0.1.2 -> current upgrade.
        $taskBaseline = Join-Path $ProjectRoot 'build\install-baseline'
        [IO.Directory]::CreateDirectory($taskBaseline) | Out-Null
        $taskArchive = Join-Path $ProjectRoot 'build\install-baseline.zip'
        & git -C $ProjectRoot archive --format=zip "--output=$taskArchive" 19b98f7266bc95709f257a4232afac5a54d0b261
        if ($LASTEXITCODE -ne 0) { throw 'Could not export the pinned baseline commit.' }
        Expand-Archive -LiteralPath $taskArchive -DestinationPath $taskBaseline -Force
        & (Join-Path $taskBaseline 'tools\Build.ps1')
        Copy-Item (Join-Path $taskBaseline 'dist\*-setup.exe') (Join-Path $taskRoot 'previous.exe')
        $taskVersion = (Get-Content (Join-Path $ProjectRoot 'VERSION') -Raw).Trim()
        Copy-Item (Join-Path $ProjectRoot "dist\NoMachineHangulBridge-$taskVersion-windows-x64-setup.exe") (Join-Path $taskRoot 'current.exe')
        Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $taskRoot 'Test-Install.ps1')
        foreach ($taskPart in @('lib', 'tests')) {
            Copy-Item -LiteralPath (Join-Path $ProjectRoot $taskPart) -Destination $taskRoot -Recurse
        }
        $taskPassword = ConvertTo-SecureString ('Nmhb!' + [guid]::NewGuid().ToString('N') + '9aZ') -AsPlainText -Force
        New-LocalUser -Name $taskUser -Password $taskPassword -AccountNeverExpires -UserMayNotChangePassword | Out-Null
        $taskCreatedUser = $true
        $taskUsersGroup = Get-LocalGroup -SID 'S-1-5-32-545'
        Add-LocalGroupMember -Group $taskUsersGroup -Member $taskUser
        & icacls $taskRoot /grant "${taskUser}:(OI)(CI)M" /T /Q | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not grant fixture access to the isolated test user.' }
        $taskCredential = [pscredential]::new("$env:COMPUTERNAME\$taskUser", $taskPassword)
        $taskOut = Join-Path $taskRoot 'worker.out'
        $taskErr = Join-Path $taskRoot 'worker.err'
        $taskArguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $taskRoot 'Test-Install.ps1') + '" -Worker -FixtureRoot "' + $taskRoot + '"'
        $taskWorker = Start-Process -FilePath (Get-Process -Id $PID).Path -Credential $taskCredential -LoadUserProfile -WorkingDirectory $taskRoot -ArgumentList $taskArguments -PassThru -RedirectStandardOutput $taskOut -RedirectStandardError $taskErr
        if (!$taskWorker.WaitForExit(180000)) { throw 'Non-administrator installer worker timed out.' }
        $taskText = [IO.File]::ReadAllText($taskOut) + [IO.File]::ReadAllText($taskErr)
        Write-Output $taskText
        if ($taskWorker.ExitCode -ne 0 -or $taskText -notmatch 'PASS \d+ non-administrator install checks') { throw 'Installer lifecycle failed.' }
    } finally {
        if ($taskWorker -and !$taskWorker.HasExited) { $taskWorker.Kill(); $taskWorker.WaitForExit() }
        if ($taskCreatedUser) { Remove-LocalUser -Name $taskUser }
        if (Test-Path $taskRoot) { Remove-Item -LiteralPath $taskRoot -Recurse -Force }
    }
    return
}

$taskChecks = 0
$taskOwnedProcesses = [Collections.Generic.List[Diagnostics.Process]]::new()
function Assert-Install([bool]$Condition, [string]$Label) {
    if (!$Condition) { throw "FAIL: $Label" }
    $script:taskChecks++
    Write-Output "OK: $Label"
}
function Start-Owned([string]$File, [string]$Arguments) {
    $taskLog = Join-Path $script:FixtureRoot ([guid]::NewGuid().ToString('N'))
    if ($Arguments.StartsWith('/VERYSILENT')) {
        $Arguments += ' /SP- /LOG="' + "$taskLog.install.log" + '"'
    }
    $taskProcess = Start-Process -FilePath $File -ArgumentList $Arguments -PassThru -RedirectStandardOutput "$taskLog.out" -RedirectStandardError "$taskLog.err"
    $taskProcess | Add-Member NoteProperty OutputPath "$taskLog.out"
    $taskProcess | Add-Member NoteProperty ErrorPath "$taskLog.err"
    $taskProcess | Add-Member NoteProperty InstallerLogPath "$taskLog.install.log"
    $script:taskOwnedProcesses.Add($taskProcess)
    return $taskProcess
}
function Wait-Owned([Diagnostics.Process]$Process, [bool]$Success = $true) {
    $taskExited = $Process.WaitForExit(45000)
    Write-Output ([IO.File]::ReadAllText($Process.OutputPath) + [IO.File]::ReadAllText($Process.ErrorPath))
    if (!$taskExited) { throw 'An owned test process timed out.' }
    if ($Success -and $Process.ExitCode -ne 0) {
        Write-Output "Child exit code: $($Process.ExitCode)"
        if (Test-Path $Process.InstallerLogPath) {
            Get-Content -LiteralPath $Process.InstallerLogPath -Tail 25 | Write-Output
        }
    }
    if ($Success) { Assert-Install ($Process.ExitCode -eq 0) 'installer/worker exited successfully' }
    else { Assert-Install ($Process.ExitCode -ne 0) 'running app blocks installer or removal' }
}
function Read-Shortcut([string]$Path) {
    return (New-Object -ComObject WScript.Shell).CreateShortcut($Path)
}
try {
    $taskIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $taskPrincipal = [Security.Principal.WindowsPrincipal]::new($taskIdentity)
    Assert-Install (!$taskPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'worker has a real non-administrator token'
    Assert-Install ($taskIdentity.Name.Split('\')[-1] -like 'nmhb_*') 'worker is the isolated CI account'
    $taskProfileKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + $taskIdentity.User.Value
    $env:USERPROFILE = (Get-ItemProperty -LiteralPath $taskProfileKey).ProfileImagePath
    $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData\Local'
    $env:APPDATA = Join-Path $env:USERPROFILE 'AppData\Roaming'
    # A new runner account has never logged into Explorer. Initialize its normal
    # per-user shell folders so Inno and AHK resolve the same actual user paths.
    $taskShellFolders = @{
        'AppData' = $env:APPDATA
        'Local AppData' = $env:LOCALAPPDATA
        'Desktop' = (Join-Path $env:USERPROFILE 'Desktop')
        'Start Menu' = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu')
        'Programs' = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs')
        'Startup' = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup')
    }
    foreach ($taskShellKey in @('Shell Folders', 'User Shell Folders')) {
        $taskRegistry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\' + $taskShellKey
        New-Item -Path $taskRegistry -Force | Out-Null
        foreach ($taskName in $taskShellFolders.Keys) {
            [IO.Directory]::CreateDirectory($taskShellFolders[$taskName]) | Out-Null
            $taskPropertyType = if ($taskShellKey -eq 'User Shell Folders') { 'ExpandString' } else { 'String' }
            New-ItemProperty -Path $taskRegistry -Name $taskName -Value $taskShellFolders[$taskName] -PropertyType $taskPropertyType -Force | Out-Null
        }
    }
    $taskApp = Join-Path $env:LOCALAPPDATA 'Programs\NoMachineHangulBridge'
    $taskProfile = Join-Path $env:LOCALAPPDATA 'NoMachineHangulBridge'
    $taskSettings = Join-Path $taskProfile 'settings.ini'
    $taskStartupDir = $taskShellFolders['Startup']
    $taskStartup = Join-Path $taskStartupDir 'NoMachine Hangul Bridge.lnk'
    Assert-Install (!(Test-Path $taskApp) -and !(Test-Path $taskProfile)) 'isolated account starts clean'
    Wait-Owned (Start-Owned (Join-Path $FixtureRoot 'previous.exe') '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART')
    $taskRuntime = Join-Path $taskApp 'runtime\AutoHotkey64.exe'
    $taskEntry = Join-Path $taskApp 'NoMachineHangulBridge.ahk'
    Assert-Install (Test-Path $taskRuntime) 'previous version installs per user without elevation'
    Assert-Install (!(Test-Path $taskStartup)) 'clean install does not enable startup'
    $taskFirst = Start-Owned $taskRuntime ('"' + $taskEntry + '" --quiet')
    Start-Sleep -Seconds 2
    Assert-Install (!$taskFirst.HasExited) 'first-run app executes as standard user'
    $taskFirst.Kill(); $taskFirst.WaitForExit()
    Wait-Owned (Start-Owned $taskRuntime ('/ErrorStdOut "' + (Join-Path $FixtureRoot 'tests\ProfileWorker.ahk') + '" "' + $taskProfile + '" remember vkF2sc070'))
    $taskProfileHash = (Get-FileHash $taskSettings).Hash

    # Explicit test-user opt-in using the same link format as the settings UI.
    $taskLink = Read-Shortcut $taskStartup
    $taskLink.TargetPath = $taskRuntime
    $taskLink.WorkingDirectory = $taskApp
    $taskLink.Arguments = '"' + $taskEntry + '" --quiet'
    $taskLink.Description = 'NoMachine Hangul Bridge'
    $taskLink.Save()
    $taskUnrelatedRuntime = Join-Path $FixtureRoot 'AutoHotkey64.exe'
    Copy-Item $taskRuntime $taskUnrelatedRuntime
    $taskUnrelatedScript = Join-Path $FixtureRoot 'unrelated.ahk'
    [IO.File]::WriteAllText($taskUnrelatedScript, "#Requires AutoHotkey v2.0`nPersistent()`nSetTimer(() => ExitApp(), -180000)`n")
    $taskUnrelated = Start-Owned $taskUnrelatedRuntime ('"' + $taskUnrelatedScript + '"')
    Wait-Owned (Start-Owned (Join-Path $FixtureRoot 'current.exe') '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART')
    Assert-Install ((Get-FileHash $taskSettings).Hash -eq $taskProfileHash) 'real version upgrade preserves exact saved settings'
    $taskLink = Read-Shortcut $taskStartup
    Assert-Install ($taskLink.TargetPath -eq $taskRuntime -and $taskLink.Arguments -eq ('"' + $taskEntry + '" --quiet')) 'upgrade startup points at installed runtime and script'
    Wait-Owned (Start-Owned $taskRuntime ('/ErrorStdOut "' + (Join-Path $FixtureRoot 'tests\ProfileWorker.ahk') + '" "' + $taskProfile + '" verify vkF2sc070'))
    $taskRunning = Start-Owned $taskRuntime ('"' + $taskEntry + '" --quiet')
    Start-Sleep -Seconds 2
    Assert-Install (!$taskRunning.HasExited) 'updated application runs with restored settings'
    Wait-Owned (Start-Owned (Join-Path $FixtureRoot 'current.exe') '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART') $false
    Assert-Install (!$taskRunning.HasExited -and !$taskUnrelated.HasExited) 'blocked update terminates no AHK process'
    Wait-Owned (Start-Owned (Join-Path $taskApp 'unins000.exe') '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART') $false
    Assert-Install (!$taskRunning.HasExited) 'blocked uninstall leaves app running'
    $taskRunning.Kill(); $taskRunning.WaitForExit()
    $taskMoved = Join-Path $env:LOCALAPPDATA 'Programs\NoMachineHangulBridge-Moved'
    Wait-Owned (Start-Owned (Join-Path $FixtureRoot 'current.exe') ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR="' + $taskMoved + '"'))
    $taskLink = Read-Shortcut $taskStartup
    Assert-Install ($taskLink.TargetPath -eq (Join-Path $taskMoved 'runtime\AutoHotkey64.exe')) 'changed install location repairs opted-in startup target'
    Assert-Install ($taskLink.Arguments -eq ('"' + (Join-Path $taskMoved 'NoMachineHangulBridge.ahk') + '" --quiet')) 'changed install location repairs startup arguments'
    $taskLogin = Start-Owned $taskLink.TargetPath $taskLink.Arguments
    Start-Sleep -Seconds 2
    Assert-Install (!$taskLogin.HasExited) 'startup command runs the relocated installation'
    $taskLogin.Kill(); $taskLogin.WaitForExit()
    Wait-Owned (Start-Owned (Join-Path $taskMoved 'unins000.exe') '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART')
    Assert-Install (!(Test-Path (Join-Path $taskMoved 'runtime\AutoHotkey64.exe'))) 'uninstall removes installed runtime'
    Assert-Install (!(Test-Path $taskStartup)) 'uninstall removes only its startup shortcut'
    Assert-Install ((Get-FileHash $taskSettings).Hash -eq $taskProfileHash) 'uninstall retains exact saved key settings'
    Assert-Install (!$taskUnrelated.HasExited) 'unrelated AHK remains running after lifecycle'
    # Reinstall must not silently restore an already removed startup registration.
    Wait-Owned (Start-Owned (Join-Path $FixtureRoot 'current.exe') '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART')
    Assert-Install (!(Test-Path $taskStartup)) 'reinstall preserves opt-out'
    Assert-Install ((Get-FileHash $taskSettings).Hash -eq $taskProfileHash) 'reinstall preserves profile'
    Wait-Owned (Start-Owned (Join-Path $taskApp 'unins000.exe') '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART')
    Write-Output "PASS $taskChecks non-administrator install checks"
} finally {
    foreach ($taskProcess in $taskOwnedProcesses) {
        if (!$taskProcess.HasExited) { $taskProcess.Kill(); $taskProcess.WaitForExit() }
        $taskProcess.Dispose()
    }
}

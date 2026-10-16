@echo off
setlocal
set "BRIDGE_AHK=%~dp0runtime\AutoHotkey64.exe"
if exist "%BRIDGE_AHK%" goto run
set "BRIDGE_AHK=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if exist "%BRIDGE_AHK%" goto run
set "BRIDGE_AHK=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if exist "%BRIDGE_AHK%" goto run
set "BRIDGE_AHK=%ProgramFiles%\AutoHotkey\v2\AutoHotkey32.exe"
if exist "%BRIDGE_AHK%" goto run
echo AutoHotkey v2 is required. Install it from https://www.autohotkey.com/
pause
exit /b 1
:run
start "" "%BRIDGE_AHK%" "%~dp0NoMachineHangulBridge.ahk" --settings %*
exit /b 0

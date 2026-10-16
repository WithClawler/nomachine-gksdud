#Requires AutoHotkey v2.0
#SingleInstance Off
#Include lib\SessionDetector.ahk
OnError((error, *) => (FileAppend("Diagnostics failed: " error.Message "`n", "*"), ExitApp(1)))
config := EnvGet("LOCALAPPDATA") "\NoMachineHangulBridge\settings.ini"
logRoot := IniRead(config, "Detection", "LogRoot", EnvGet("USERPROFILE") "\.nx")
detector := NxDetector(logRoot)
detector.Refresh()
FileAppend(detector.Diagnostics(), "*", "UTF-8")
ExitApp(0)

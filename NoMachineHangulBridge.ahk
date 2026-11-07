#Requires AutoHotkey v2.0
#SingleInstance Off
#MaxThreadsPerHotkey 1
#Include lib\SingleInstance.ahk
#Include lib\StartupLink.ahk
#Include lib\SessionDetector.ahk
#Include lib\BridgeApp.ahk

OnError(BridgeError)
; Maintenance never installs hooks, opens settings, or opts a user into startup.
mode := A_Args.Length ? A_Args[1] : ""
if mode = "--repair-startup" {
    BridgeStartup.Repair()
    ExitApp()
}
if mode = "--remove-startup" {
    BridgeStartup.RemoveOwned()
    ExitApp()
}
instance := BridgeInstance()
if !instance.acquired {
    if mode != "--quiet"
        MsgBox("이미 실행 중`n‘!한’ 더블클릭: 설정", "NoMachine Hangul Bridge")
    ExitApp()
}
if EnvGet("NMHB_DEBUG") = "1" {
    FileAppend("BOOT`n", "*")
    OnExit((reason, code) => FileAppend("EXIT " reason " " code "`n", "*"))
}
SetKeyDelay(40, 50)
app := HangulBridge()
Persistent()
; Existing users start from their saved profile; --settings explicitly opens UI.
app.Start(mode != "--settings")
app.Trace("STARTED persistent=" Persistent())

BridgeError(error, *) {
    message := "NoMachine Hangul Bridge stopped: " error.Message " (line " error.Line ")"
    try FileAppend(message "`n", "**")
    MsgBox("앱 실행 오류`n" error.Message, "NoMachine Hangul Bridge", "Iconx")
    ExitApp(1)
}

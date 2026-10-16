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
        MsgBox("이미 실행 중입니다. 알림 영역의 ‘한’ 아이콘에서 설정을 여세요.`n다른 폴더의 사본으로 바꾸려면 기존 사본을 먼저 종료하세요.", "NoMachine Hangul Bridge")
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
    MsgBox(message "`n종료하면 키 매핑은 해제됩니다.", "NoMachine Hangul Bridge", "Iconx")
    ExitApp(1)
}

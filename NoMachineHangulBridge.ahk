#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 1
#Include lib\SessionDetector.ahk
#Include lib\BridgeApp.ahk

OnError(BridgeError)
if EnvGet("NMHB_DEBUG") = "1" {
    FileAppend("BOOT`n", "*")
    OnExit((reason, code) => FileAppend("EXIT " reason " " code "`n", "*"))
}
SetKeyDelay(40, 50)
app := HangulBridge()
Persistent()
; Existing users start from their saved profile; --settings explicitly opens UI.
app.Start(!(A_Args.Length && A_Args[1] = "--settings"))
app.Trace("STARTED persistent=" Persistent())

BridgeError(error, *) {
    message := "NoMachine Hangul Bridge stopped: " error.Message " (line " error.Line ")"
    try FileAppend(message "`n", "**")
    MsgBox(message "`n종료하면 키 매핑은 해제됩니다.", "NoMachine Hangul Bridge", "Iconx")
    ExitApp(1)
}


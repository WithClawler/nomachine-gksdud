#Requires AutoHotkey v2.0
#Include ..\lib\SessionDetector.ahk
#Include ..\lib\BridgeApp.ahk
OnError((error, *) => (FileAppend(error.Message "`n", "**"), ExitApp(1)))
class ProfileBridge extends HangulBridge {
    notices := 0
    NotifyHidden() {
        this.notices += 1
    }
}
bridge := ProfileBridge(A_Args[1])
if A_Args[2] = "remember" {
    bridge.RememberKey(A_Args[3])
    ; Deliberately no SaveSettings: learning must survive process termination.
} else if A_Args[2] = "verify" {
    if bridge.key != A_Args[3] || bridge.pendingKey != A_Args[3]
        throw Error("Persisted key not restored")
} else if A_Args[2] = "close" {
    bridge.ShowSettings(false)
    bridge.HideSettings()
    if bridge.notices != Integer(A_Args[3])
        throw Error("Unexpected tray notice count after process restart")
    bridge.window.Destroy()
} else
    throw Error("Unknown test worker mode")
FileAppend("PASS profile worker " A_Args[2] "`n", "*")
ExitApp()

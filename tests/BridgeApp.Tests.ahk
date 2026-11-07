#Requires AutoHotkey v2.0
#Include ..\lib\SessionDetector.ahk
#Include ..\lib\BridgeApp.ahk
OnError(FailError)
FailError(error, *) {
    FileAppend("ERROR: " error.Message " at line " error.Line "`n", "*")
    ExitApp(1)
}
tests := 0
class NoticeBridge extends HangulBridge {
    notices := 0
    NotifyHidden() {
        this.notices += 1
    }
}
Assert(condition, label) {
    global tests
    if !condition {
        FileAppend("FAIL: " label "`n", "*")
        ExitApp(1)
    }
    tests += 1
}
PictureBackgroundColor(control) {
    bitmap := SendMessage(0x173, 0, 0, control.Hwnd) ; STM_GETIMAGE / IMAGE_BITMAP
    info := Buffer(32, 0)
    if !bitmap || !DllCall("GetObjectW", "ptr", bitmap, "int", info.Size, "ptr", info)
        throw Error("Settings logo bitmap is unavailable")
    width := NumGet(info, 4, "int"), height := NumGet(info, 8, "int")
    dc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
    old := DllCall("SelectObject", "ptr", dc, "ptr", bitmap, "ptr")
    try return DllCall("GetPixel", "ptr", dc, "int", Round(width * 0.1), "int", Round(height * 0.5), "uint")
    finally {
        DllCall("SelectObject", "ptr", dc, "ptr", old)
        DllCall("DeleteDC", "ptr", dc)
    }
}
taskDir := A_Temp "\nmhb-tests-" DllCall("GetCurrentProcessId")
startupExisted := !!FileExist(A_Startup "\NoMachine Hangul Bridge.lnk")
DirCreate(taskDir)
try {
    bridge := HangulBridge(taskDir)
    Assert(bridge.key = "", "first run does not assume VK15")
    Assert(bridge.output = "Control+Space", "default Mac shortcut")
    Assert(!bridge.CanMap(), "no mapping before key registration")
    bridge.RememberKey("vk15sc138")
    Assert(IniRead(taskDir "\settings.ini", "Mapping", "Key") = "vk15sc138", "learning immediately persists without save button")
    Assert(bridge.key = "vk15sc138", "learned key applies immediately")
    bridge.RegisterKey("")
    reloaded := HangulBridge(taskDir)
    Assert(reloaded.key = "vk15sc138", "a fresh app instance restores the measured key")
    Assert(reloaded.pendingKey = "vk15sc138", "restored key does not require recapture")
    IniWrite("", taskDir "\settings.ini", "Mapping", "Key")
    bridge := HangulBridge(taskDir)
    Assert(bridge.RunState().id = "unconfigured", "unregistered key is visible in run state")
    bridge.enabled := false
    Assert(bridge.RunState().id = "paused", "paused state is explicit")
    bridge.enabled := true
    bridge.capturing := true
    Assert(bridge.RunState().id = "learning", "learning state is explicit")
    bridge.capturing := false
    bridge.ShowSettings(false)
    Assert(bridge.window.Hwnd != 0, "settings GUI builds")
    Assert(!DllCall("IsWindowVisible", "ptr", bridge.window.Hwnd), "test GUI stays hidden")
    Assert(bridge.outputControl.Text = "Control+Space", "shortcut dropdown initialized")
    Assert(bridge.settingsView.LogRoot() = EnvGet("USERPROFILE") "\.nx", "unopened details preserve the default log folder")
    Assert(!bridge.settingsView.details, "details are not created with the primary screen")
    bridge.settingsView.ShowDetails(false)
    Assert(!DllCall("IsWindowVisible", "ptr", bridge.settingsView.details.Hwnd), "advanced settings stay out of the primary screen")
    Assert(PictureBackgroundColor(bridge.settingsView.logo) = BridgeSettingsView.Color(bridge.RunState().color), "registration logo matches blue status color")
    defaultId := SendMessage(0x400, 0, 0, bridge.window.Hwnd) ; DM_GETDEFID
    Assert((defaultId & 0xFFFF) = DllCall("GetDlgCtrlID", "ptr", bridge.saveControl.Hwnd), "save remains the native default button")
    bridge.TogglePause()
    Assert(bridge.pauseControl.Text = "재개", "pause action changes to resume")
    Assert(PictureBackgroundColor(bridge.settingsView.logo) = BridgeSettingsView.Color(bridge.RunState().color), "paused logo matches gray status color")
    bridge.TogglePause()
    Assert(bridge.pauseControl.Text = "일시 중지", "resume action changes to pause")
    bridge.capturing := true
    bridge.UpdateStatus()
    Assert(bridge.runLabel.Text = "한영키 감지 중", "capture status updates immediately")
    bridge.capturing := false
    bridge.key := "vk15sc138"
    bridge.detector.records := Map(1, {ok: true, title: "Test desktop", platform: "macOS", reason: "live-mac-evidence"})
    bridge.UpdateStatus()
    Assert(PictureBackgroundColor(bridge.settingsView.logo) = BridgeSettingsView.Color(bridge.RunState().color), "ready logo matches teal status color")
    bridge.detector.records := Map()
    bridge.settingsView.details.Destroy()
    bridge.window.Destroy()
    noticeApp := NoticeBridge(taskDir)
    noticeApp.ShowSettings(false)
    noticeApp.HideSettings()
    noticeApp.HideSettings()
    Assert(noticeApp.notices = 1, "closing repeatedly shows one tray notice")
    Assert(IniRead(taskDir "\settings.ini", "Interface", "TrayNoticeShown") = "1", "tray notice is recorded in the user profile")
    noticeApp.window.Destroy()
    noticeReload := NoticeBridge(taskDir)
    noticeReload.ShowSettings(false)
    noticeReload.HideSettings()
    Assert(noticeReload.notices = 0, "restarting does not repeat the tray notice")
    Assert(IniRead(taskDir "\settings.ini", "Mapping", "Key") = "", "notice does not rewrite mapping settings")
    noticeReload.window.Destroy()
    IniWrite("vk15sc138", taskDir "\settings.ini", "Mapping", "Key")
    IniWrite("invalid shortcut", taskDir "\settings.ini", "Mapping", "Output")
    bridge := HangulBridge(taskDir)
    Assert(bridge.key = "vk15sc138", "measured key loaded")
    Assert(bridge.output = "Control+Space", "invalid output fails to safe default")
    Assert(bridge.RunState().id = "waiting", "running without Mac is shown as waiting")
    bridge.detector.records := Map(1, {ok: true})
    Assert(bridge.RunState().id = "ready", "recognized Mac is shown as ready")
    ; Register against a detector that never approves a target, so no user's
    ; keyboard input is intercepted or generated by this test.
    bridge.detector.records := Map()
    bridge.detector.updatedAt := A_TickCount
    bridge.RegisterKey(bridge.key)
    Assert(bridge.registeredKey = "vk15", "valid VK binding derived from measured pair")
    Assert(!bridge.CanMap(), "no approved process leaves native input")
    bridge.RegisterKey("")
    Assert(bridge.registeredKey = "", "hotkeys can be unregistered")
    IniWrite("garbage", taskDir "\settings.ini", "Mapping", "Key")
    bridge := HangulBridge(taskDir)
    Assert(bridge.key = "", "malformed key disabled")
    Assert(!!FileExist(bridge.startupLink) = startupExisted, "tests do not alter startup")
    for state in ["ready", "waiting", "paused"] {
        iconPath := A_ScriptDir "\..\assets\bridge-" state ".ico"
        for size in [16, 20, 24, 32, 40, 48, 64, 128, 256] {
            iconHandle := DllCall("LoadImageW", "ptr", 0, "str", iconPath, "uint", 1, "int", size, "int", size, "uint", 0x10, "ptr")
            Assert(iconHandle != 0, state " tray icon loads through Windows at " size "px")
            DllCall("DestroyIcon", "ptr", iconHandle)
        }
    }
} finally {
    ; Remove only the exact new directory created by this test.
    if FileExist(taskDir "\settings.ini")
        FileDelete(taskDir "\settings.ini")
    DirDelete(taskDir)
}
FileAppend("PASS " tests " setup/binding checks`n", "*")
ExitApp(0)

#Requires AutoHotkey v2.0
#Include ..\lib\SingleInstance.ahk
#Include ..\lib\SessionDetector.ahk
#Include ..\lib\BridgeApp.ahk
OnError(FailError)
FailError(error, *) {
    FileAppend("ERROR: " error.Message " at line " error.Line "`n", "*")
    ExitApp(1)
}
checks := 0
Assert(condition, label) {
    global checks
    if !condition
        throw Error("FAIL: " label)
    checks += 1
}

; Fake only the external target and output. The real latch/timer/recheck runs.
class TargetStub {
    __New() {
        this.target := {hwnd: 123, pid: 456, token: "test-mac-session"}
    }
    Current() => this.target
    StillCurrent(origin) => NxEvidence.SameTarget(origin, this.target)
}
class ObservedBridge extends HangulBridge {
    EmitSwitch(keys) {
        this.sent.Push({keys: keys, tick: A_TickCount})
    }
}

root := A_Temp "\nmhb-lifecycle-" DllCall("GetCurrentProcessId")
DirCreate(root)
try {
    bridge := ObservedBridge(root)
    bridge.sent := []
    bridge.detector := TargetStub()
    bridge.RememberKey("vkF2sc070")
    Assert(IniRead(root "\settings.ini", "Mapping", "Key") = "vkF2sc070", "non-VK15 measurement persists immediately")
    bridge.RegisterKey("")
    reloaded := HangulBridge(root)
    Assert(reloaded.key = "vkF2sc070", "different measured keyboard restores")
    bridge.RememberKey("vk15sc138")
    bridge.RegisterKey("")
    Assert(HangulBridge(root).key = "vk15sc138", "recapture replaces saved key")
    started := A_TickCount
    bridge.KeyDown()
    Assert(bridge.sent.Length = 0, "no synchronous send in press handler")
    Loop 20
        bridge.KeyDown()
    Sleep(100)
    Assert(bridge.sent.Length = 1, "held key sends once")
    Assert(bridge.sent[1].tick - started >= 25, "send waits for the 30ms timer")
    Assert(bridge.sent[1].keys = "^{Space}", "verified Control+Space output")
    bridge.KeyUp()
    Sleep(70)
    Assert(bridge.sent.Length = 1, "release does not send")
    bridge.KeyDown()
    bridge.KeyUp()
    Sleep(100)
    Assert(bridge.sent.Length = 2, "short tap also sends once")
    bridge.KeyDown()
    bridge.detector.target := false
    Sleep(100)
    Assert(bridge.sent.Length = 2, "focus loss cancels scheduled send")
    bridge.KeyUp()
    bridge.KeyDown()
    Sleep(70)
    Assert(!bridge.armed && bridge.sent.Length = 2, "unknown target remains native")
    bridge.detector := TargetStub()
    bridge.KeyDown()
    bridge.detector.target := {hwnd: 123, pid: 456, token: "reconnected-session"}
    Sleep(100)
    Assert(bridge.sent.Length = 2, "reconnection cancels pending send")
    bridge.KeyUp()
    bridge.KeyDown()
    bridge.enabled := false
    Sleep(100)
    Assert(bridge.sent.Length = 2, "pause cancels pending send")
    bridge.KeyUp()
    bridge.KeyDown()
    Assert(!bridge.armed, "paused bridge does not arm")
    bridge.enabled := true
    bridge.output := "Control+Option+Space"
    bridge.KeyDown()
    Sleep(100)
    Assert(bridge.sent.Length = 3 && bridge.sent[3].keys = "^!{Space}", "optional output routes correctly in unit test")
    bridge.KeyUp()

    mutexName := BridgeInstance.Name "-test-" DllCall("GetCurrentProcessId")
    first := BridgeInstance(mutexName)
    second := BridgeInstance(mutexName)
    Assert(first.acquired && !second.acquired, "single instance name rejects duplicate")
    second := false
    first := false
    next := BridgeInstance(mutexName)
    Assert(next.acquired, "exit releases singleton")
    next := false

    link := root "\startup.lnk"
    scriptA := root "\portable\NoMachineHangulBridge.ahk"
    scriptB := root "\installed\NoMachineHangulBridge.ahk"
    BridgeStartup.Repair(link, scriptA)
    Assert(!FileExist(link), "repair never opts in")
    BridgeStartup.Set(true, link, scriptA)
    Assert(BridgeStartup.Read(link).script = scriptA, "explicit opt-in creates link")
    BridgeStartup.Repair(link, scriptB)
    Assert(BridgeStartup.Read(link).script = scriptB, "upgrade repairs existing link")
    BridgeStartup.RemoveOwned(link, scriptA)
    Assert(!!FileExist(link), "old copy cannot remove newer copy's startup")
    BridgeStartup.RemoveOwned(link, scriptB)
    Assert(!FileExist(link), "uninstall removes its own link")
    FileCreateShortcut(A_AhkPath, link, , "another-script.ahk", "Unrelated AHK")
    BridgeStartup.Repair(link, scriptB)
    Assert(!BridgeStartup.Read(link), "unrelated link is not adopted")
    BridgeStartup.Set(false, link)
    Assert(!!FileExist(link), "unrelated startup link is preserved")
} finally {
    DirDelete(root, true)
}
FileAppend("PASS " checks " lifecycle/routing checks`n", "*")
ExitApp(0)

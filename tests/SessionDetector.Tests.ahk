#Requires AutoHotkey v2.0
#Include ..\lib\SessionDetector.ahk
OnError(FailError)
FailError(error, *) {
    FileAppend("ERROR: " error.Message " at line " error.Line "`n", "*")
    ExitApp(1)
}
tests := 0
Assert(condition, label) {
    global tests
    if !condition {
        FileAppend("FAIL: " label "`n", "*")
        ExitApp(1)
    }
    tests += 1
}

path := "C:\Connections\내 Mac.nxs"
created := "20261016160535.000000+540"
session := "15300 16940 2026-10-16 16:05:37 588.918 ClientSession: Going to start session '" path "'.`n"
session .= "Session: Session started at Fri Oct 16 16:05:39 2026.`n"
mac := "NX> 106 NXSERVER-9.10.3 MS OS: macOS 27.0.1 HW: Mac mini`nNX> 884 Agent mode: macOS`n"
Assert(NxEvidence.SessionPath('nxplayer.exe --session "' path '"') = path, "quoted Unicode session path")
Assert(NxEvidence.SessionPath('nxplayer.exe "--session" "' path '"') = path, "quoted session option from NoMachine launcher")
Assert(NxEvidence.SessionPath('nxplayer.exe --session=C:\a.nxs') = "C:\a.nxs", "unquoted session path")
Assert(NxEvidence.SessionPath('nxplayer.exe') = "", "launcher has no session")
Assert(NxEvidence.Check(mac, session, 15300, created, path).ok, "current Mac allowed")
slashPath := StrReplace(path, "\", "/")
Assert(NxEvidence.Check(mac, session, 15300, created, slashPath).ok, "canonical and slash-style paths identify the same connection")
titles := NxEvidence.DesktopTitles(slashPath)
Assert(titles[1] = "내 Mac - NoMachine", "slash-style path yields a clean basename")
Assert(NxEvidence.TitleMatches(titles, RegExReplace(slashPath, "i)\.nxs$", "") " - NoMachine", 0), "exact full-path NoMachine title without extension accepted")
Assert(!NxEvidence.TitleMatches(titles, "C:/other/내 Mac - NoMachine", 0), "unrelated full-path title rejected")
Assert(!NxEvidence.Check(StrReplace(mac, "macOS", "Windows"), session, 15300, created, path).ok, "Windows blocked")
Assert(!NxEvidence.Check(StrReplace(mac, "macOS", "Linux"), session, 15300, created, path).ok, "Linux blocked")
Assert(!NxEvidence.Check("", session, 15300, created, path).ok, "missing platform blocked")
Assert(!NxEvidence.Check("NX> 106 NXSERVER OS: macOS 27 HW: Mac`n", session, 15300, created, path).ok, "login without desktop agent blocked")
Assert(!NxEvidence.Check(mac "NX> 106 NXSERVER OS: macOS 27 HW: Mac`n", session, 15300, created, path).ok, "stale agent after new handshake blocked")
Assert(!NxEvidence.Check(mac, session, 15300, "20261017160535", path).ok, "reused PID with old logs blocked")
Assert(!NxEvidence.Check(mac, session, 15300, created, "C:\other.nxs").ok, "other connection path blocked")
Assert(!NxEvidence.Check(mac, session, 100, created, path).ok, "other process blocked")
Assert(!NxEvidence.Check(mac, session "Session: Session terminated at now.`n", 15300, created, path).ok, "terminated session blocked")
Assert(!NxEvidence.Check(mac, session "Session: Session suspended at now.`n", 15300, created, path).ok, "suspended session blocked")
Assert(NxEvidence.WindowMatches("Mac - NoMachine", "Mac - NoMachine", 0), "exact desktop title")
Assert(!NxEvidence.WindowMatches("Mac - NoMachine", "Mac - NoMachine settings", 0), "settings title blocked")
Assert(!NxEvidence.WindowMatches("Mac - NoMachine", "Mac - NoMachine", 123), "owned dialog blocked")
Assert(!NxEvidence.WindowMatches("Mac - NoMachine", "Mac - NoMachine", 0, false), "disabled mapping blocked")
Assert(!NxEvidence.WindowMatches("Mac - NoMachine", "mac - NoMachine", 0), "title matching is exact")
first := {hwnd: 123, pid: 45, token: "session-A"}
Assert(NxEvidence.SameTarget(first, {hwnd: 123, pid: 45, token: "session-A"}), "same target allowed")
Assert(!NxEvidence.SameTarget(first, {hwnd: 124, pid: 45, token: "session-A"}), "focus switch cancels queued send")
Assert(!NxEvidence.SameTarget(first, {hwnd: 123, pid: 45, token: "session-B"}), "reconnect cancels queued send")
Assert(!NxEvidence.SameTarget(first, false), "focus outside cancels queued send")
FileAppend("PASS " tests " routing/evidence checks`n", "*")
ExitApp(0)

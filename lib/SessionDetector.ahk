#Requires AutoHotkey v2.0

; NoMachine's logs are an observed compatibility interface, not a public API.
; A cached .nxs platform or a hostname is never sufficient to enable remapping.
class NxEvidence {
    static LastMatch(text, pattern) {
        result := 0, offset := 1
        while RegExMatch(text, pattern, &found, offset) {
            result := found
            offset := found.Pos + Max(found.Len, 1)
        }
        return result
    }

    static SessionPath(commandLine) {
        if !RegExMatch(commandLine, 'i)(?:^|\s)(?:"--session"|--session)(?:\s+|=)(?:"([^"]+)"|([^\s]+))', &found)
            return ""
        return found[1] != "" ? found[1] : found[2]
    }

    static IsMac(platform) {
        return !!RegExMatch(Trim(platform), "i)^(?:macOS|Mac OS X|Darwin)(?:\s|$)")
    }

    static DesktopTitles(path) {
        ; AHK SplitPath and NoMachine can both handle slash-style Windows paths
        ; differently. Normalize for the basename and keep an exact raw-path
        ; alternative observed when NoMachine displays that path as its title.
        normalized := StrReplace(path, "/", "\")
        SplitPath(normalized, , , , &stem)
        titles := [stem " - NoMachine"]
        if InStr(path, "/")
            titles.Push(RegExReplace(path, "i)\.nxs$", "") " - NoMachine")
        return titles
    }

    static TitleMatches(titles, actualTitle, owner) {
        for title in titles {
            if this.WindowMatches(title, actualTitle, owner)
                return true
        }
        return false
    }

    static Check(connectionText, sessionText, pid, created, sessionPath) {
        result := {ok: false, reason: "unrecognized-log", platform: "Unknown"}
        ; Tie this folder to the CURRENT process, including its creation time.
        pattern := "m)^" pid "\s+\d+\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})[^\r\n]*ClientSession: Going to start session '([^']+)'\."
        start := this.LastMatch(sessionText, pattern)
        if !start || !RegExMatch(created, "^\d{14}") {
            result.reason := "process-not-linked"
            return result
        }
        logStamp := RegExReplace(start[1], "\D")
        try age := Abs(DateDiff(logStamp, SubStr(created, 1, 14), "Seconds"))
        catch {
            result.reason := "invalid-process-time"
            return result
        }
        if age > 15 || StrLower(StrReplace(start[2], "/", "\")) != StrLower(StrReplace(sessionPath, "/", "\")) {
            result.reason := "stale-or-other-process"
            return result
        }
        state := this.LastMatch(sessionText, "im)^Session:\s+Session\s+(started|resumed|terminated|closed|suspended|suspending|resuming|failed|disconnected)\b")
        if !state || !RegExMatch(state[1], "i)^(started|resumed)$") {
            result.reason := "desktop-not-running"
            return result
        }
        banner := this.LastMatch(connectionText, "im)^NX>\s+106\s+[^\r\n]*?\bOS:\s*(.+?)(?:\s+HW:|\r?$)")
        agent := this.LastMatch(connectionText, "im)^NX>\s+884\s+Agent mode:\s*([^\r\n]+)")
        if !banner || !agent || agent.Pos < banner.Pos {
            result.reason := "platform-not-confirmed"
            return result
        }
        result.platform := Trim(banner[1])
        if !this.IsMac(result.platform) || !this.IsMac(agent[1]) {
            result.reason := "non-mac-desktop"
            return result
        }
        result.ok := true
        result.reason := "live-mac-evidence"
        return result
    }

    static WindowMatches(expectedTitle, actualTitle, owner, enabled := true) {
        ; Explicitly reject dialogs/settings and ambiguous/localized window titles.
        return enabled && owner = 0 && StrCompare(expectedTitle, actualTitle, true) = 0
    }

    static SameTarget(first, second) {
        return first && second && first.hwnd = second.hwnd
            && first.pid = second.pid && first.token = second.token
    }
}

class NxDetector {
    __New(logRoot) {
        this.logRoot := RTrim(logRoot, "\/")
        this.records := Map()
        this.updatedAt := 0
        this.error := ""
        this.wmi := ComObjGet("winmgmts:")
    }

    static ReadBounded(path) {
        ; Connection logs can contain credentials: never return them to callers
        ; other than the evidence parser, and never copy them into diagnostics.
        if !FileExist(path) || FileGetSize(path) > 4 * 1024 * 1024
            throw Error("Missing or oversized session log")
        return FileRead(path, "UTF-8")
    }

    Refresh() {
        next := Map()
        this.error := ""
        try {
            query := "SELECT ProcessId,Name,CommandLine,CreationDate FROM Win32_Process WHERE Name='nxplayer.bin' OR Name='nxplayer.exe'"
            for process in this.wmi.ExecQuery(query) {
                pid := Integer(process.ProcessId)
                path := NxEvidence.SessionPath(process.CommandLine "")
                if path = ""
                    continue
                created := process.CreationDate ""
                record := {pid: pid, created: created, path: path, ok: false,
                    reason: "no-current-session-log", platform: "Unknown", folder: ""}
                record.titles := NxEvidence.DesktopTitles(path)
                record.title := record.titles[1]
                matches := []
                Loop Files this.logRoot "\R-*", "D" {
                    if !RegExMatch(A_LoopFileName, "i)^R-.+-" pid "-[0-9a-f]{32}$")
                        continue
                    try {
                        check := NxEvidence.Check(
                            NxDetector.ReadBounded(A_LoopFileFullPath "\connection"),
                            NxDetector.ReadBounded(A_LoopFileFullPath "\session"),
                            pid, created, path)
                        if check.reason = "stale-or-other-process" || check.reason = "process-not-linked"
                            continue
                        matches.Push({folder: A_LoopFileFullPath, evidence: check})
                    }
                }
                if matches.Length = 1 {
                    selected := matches[1]
                    record.folder := selected.folder
                    record.ok := selected.evidence.ok
                    record.reason := selected.evidence.reason
                    record.platform := selected.evidence.platform
                } else if matches.Length > 1
                    record.reason := "ambiguous-session-logs"
                record.token := created "|" path "|" record.folder
                next[pid] := record
            }
        } catch {
            ; Fail closed if process enumeration is unavailable.
            this.error := "NoMachine process information unavailable"
            next := Map()
        }
        this.records := next
        this.updatedAt := A_TickCount
    }

    Current() {
        if A_TickCount - this.updatedAt > 4000
            return false
        hwnd := WinExist("A")
        if !hwnd
            return false
        try {
            pid := WinGetPID("ahk_id " hwnd)
            if !this.records.Has(pid)
                return false
            record := this.records[pid]
            owner := DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr")
            if !record.ok || !NxEvidence.TitleMatches(record.titles, WinGetTitle("ahk_id " hwnd), owner)
                return false
            exe := StrLower(WinGetProcessName("ahk_id " hwnd))
            if exe != "nxplayer.bin" && exe != "nxplayer.exe"
                return false
            return {hwnd: hwnd, pid: pid, token: record.token, record: record}
        }
        return false
    }

    StillCurrent(target) {
        current := this.Current()
        if !NxEvidence.SameTarget(target, current)
            return false
        try {
            record := current.record
            evidence := NxEvidence.Check(
                NxDetector.ReadBounded(record.folder "\connection"),
                NxDetector.ReadBounded(record.folder "\session"),
                record.pid, record.created, record.path)
            return evidence.ok
        }
        return false
    }

    Diagnostics() {
        version := FileExist(A_ScriptDir "\VERSION") ? Trim(FileRead(A_ScriptDir "\VERSION", "UTF-8")) : "development"
        text := "NoMachine Hangul Bridge " version "`n"
        text .= "Live processes with --session: " this.records.Count "`n"
        for pid, record in this.records
            text .= "PID=" pid " platform=" record.platform " eligible=" record.ok " reason=" record.reason "`n"
        if this.error != ""
            text .= this.error "`n"
        return text
    }
}

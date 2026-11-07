#Include StartupLink.ahk
#Include SettingsView.ahk

class HangulBridge {
    __New(dataDir := "") {
        this.dataDir := dataDir != "" ? dataDir : EnvGet("LOCALAPPDATA") "\NoMachineHangulBridge"
        this.debug := EnvGet("NMHB_DEBUG") = "1"
        this.configFile := this.dataDir "\settings.ini"
        this.key := IniRead(this.configFile, "Mapping", "Key", "")
        if !RegExMatch(this.key, "i)^vk[0-9a-f]{2}sc[0-9a-f]{3}$")
            this.key := ""
        this.output := IniRead(this.configFile, "Mapping", "Output", "Control+Space")
        if this.output != "Control+Space" && this.output != "Control+Option+Space"
            this.output := "Control+Space"
        logRoot := IniRead(this.configFile, "Detection", "LogRoot", EnvGet("USERPROFILE") "\.nx")
        this.detector := NxDetector(logRoot)
        this.enabled := true
        this.armed := false
        this.capturing := false
        this.registeredKey := ""
        this.window := false
        SplitPath(A_LineFile, , &sourceDir)
        this.assetsDir := sourceDir "\..\assets"
        this.trayReady := false
        this.lastTrayState := ""
        this.hiddenNoticeShown := IniRead(this.configFile, "Interface", "TrayNoticeShown", "0") = "1"
        this.pendingKey := this.key
        this.downCondition := (*) => this.CanMap()
        this.upCondition := (*) => this.armed || this.CanMap()
        this.downCallback := ObjBindMethod(this, "KeyDown")
        this.upCallback := ObjBindMethod(this, "KeyUp")
        this.refreshTimer := ObjBindMethod(this, "Refresh")
        this.startupLink := BridgeStartup.Path
    }

    Start(quiet := false) {
        this.Refresh()
        this.RegisterKey(this.key)
        A_TrayMenu.Delete()
        A_TrayMenu.Add("설정", (*) => this.ShowSettings())
        A_TrayMenu.Add("일시 중지", (*) => this.TogglePause())
        A_TrayMenu.Add()
        A_TrayMenu.Add("종료", (*) => ExitApp())
        A_TrayMenu.Default := "설정"
        A_TrayMenu.ClickCount := 2
        this.trayReady := true
        this.UpdateStatus()
        SetTimer(this.refreshTimer, 1500)
        if !quiet || this.key = ""
            this.ShowSettings()
    }

    RegisterKey(key) {
        if this.registeredKey != "" {
            HotIf(this.downCondition)
            Hotkey("$" this.registeredKey, "Off")
            HotIf(this.upCondition)
            Hotkey("$" this.registeredKey " up", "Off")
        }
        ; AutoHotkey's Hotkey() accepts VK or SC, not the combined Send() form.
        ; Use the measured VK; retain the measured SC in settings for diagnostics.
        this.registeredKey := key = "" ? "" : SubStr(key, 1, 4)
        if key != "" {
            HotIf(this.downCondition)
            Hotkey("$" this.registeredKey, this.downCallback, "On")
            HotIf(this.upCondition)
            Hotkey("$" this.registeredKey " up", this.upCallback, "On")
        }
        HotIf()
    }

    CanMap() {
        return this.enabled && !this.capturing && this.key != "" && !!this.detector.Current()
    }

    KeyDown(*) {
        this.Trace("DOWN armed=" this.armed)
        if this.armed || !this.enabled || this.capturing || this.key = ""
            return
        target := this.detector.Current()
        if !target
            return
        this.armed := true
        ; An immutable origin prevents a queued press reaching another window.
        SetTimer(ObjBindMethod(this, "SendSwitch", target), -30)
    }

    KeyUp(*) {
        this.Trace("UP")
        this.armed := false
    }

    SendSwitch(target) {
        if !this.enabled || this.capturing || !this.detector.StillCurrent(target) {
            this.Trace("CANCEL_SEND")
            return
        }
        this.Trace("SEND")
        keys := this.output = "Control+Option+Space" ? "^!{Space}" : "^{Space}"
        this.EmitSwitch(keys)
    }

    EmitSwitch(keys) {
        SendEvent(keys)
    }

    Trace(message) {
        if this.debug
            try FileAppend(A_TickCount " " message "`n", this.dataDir "\diagnostic.log", "UTF-8")
    }

    TogglePause() {
        this.enabled := !this.enabled
        if this.trayReady {
            if this.enabled
                A_TrayMenu.Uncheck("일시 중지")
            else
                A_TrayMenu.Check("일시 중지")
        }
        this.UpdateStatus()
    }

    Refresh(*) {
        this.detector.Refresh()
        this.UpdateStatus()
    }

    ShowSettings(visible := true) {
        if !this.window {
            this.settingsView := BridgeSettingsView(this)
            this.window := this.settingsView.window
        }
        this.UpdateStatus()
        this.settingsView.Show(visible)
    }

    HideSettings() {
        this.CancelCapture()
        this.settingsView.HideDetails()
        this.window.Hide()
        if !this.hiddenNoticeShown {
            ; Persist before notifying: restarting or moving the app must not repeat it.
            DirCreate(this.dataDir)
            IniWrite("1", this.configFile, "Interface", "TrayNoticeShown")
            this.hiddenNoticeShown := true
            this.NotifyHidden()
        }
    }

    NotifyHidden() {
        TrayTip("백그라운드 실행 중`n‘!한’ 더블클릭: 설정", "NoMachine Hangul Bridge", 1)
    }

    KeyDescription() {
        return this.key = "" ? "미등록" : "등록됨"
    }

    BeginCapture(*) {
        this.CancelCapture()
        this.capturing := true
        this.keyLabel.Text := "한영키 누르기 · Esc 취소"
        this.UpdateStatus()
        ; Visible, bounded learning: no global suppression and no keystroke log.
        this.captureHook := InputHook("V L0 T8")
        this.captureHook.KeyOpt("{All}", "N")
        this.captureHook.OnKeyDown := ObjBindMethod(this, "CaptureDown")
        this.captureHook.OnEnd := ObjBindMethod(this, "CaptureEnd")
        this.captureHook.Start()
    }

    CaptureDown(hook, vk, sc) {
        if !this.capturing
            return
        if !WinActive("ahk_id " this.window.Hwnd) || vk = 0x1B {
            this.CancelCapture()
            return
        }
        ; Modifier-only mappings need different handling; keep this release scoped.
        if vk = 0 || sc = 0 || vk = 0x09 || vk = 0x0D || vk = 0x5B || vk = 0x5C
            || (vk >= 0xA0 && vk <= 0xA5) || vk = 0x10 || vk = 0x11 || vk = 0x12
            return
        measuredKey := Format("vk{1:02X}sc{2:03X}", vk, sc)
        this.capturing := false
        hook.Stop()
        this.RememberKey(measuredKey)
        this.keyLabel.Text := this.KeyDescription()
        this.captureControl.Text := "키 변경"
        this.UpdateStatus()
    }

    RememberKey(key) {
        if !RegExMatch(key, "i)^vk[0-9a-f]{2}sc[0-9a-f]{3}$")
            throw ValueError("Invalid measured key")
        ; Save immediately: closing the settings window must not lose learning.
        ; The profile lives outside the application/install directory.
        DirCreate(this.dataDir)
        IniWrite(key, this.configFile, "Mapping", "Key")
        this.RegisterKey(key)
        this.key := key
        this.pendingKey := key
    }

    CaptureEnd(*) {
        if this.capturing {
            this.capturing := false
            this.keyLabel.Text := "시간 초과 · 다시 시도"
            this.UpdateStatus()
        }
    }

    CancelCapture() {
        if !this.capturing
            return
        this.capturing := false
        this.captureHook.Stop()
        this.keyLabel.Text := this.KeyDescription()
        this.UpdateStatus()
    }

    SaveSettings(*) {
        this.CancelCapture()
        if this.pendingKey = "" {
            MsgBox("한영키 등록 필요", "NoMachine Hangul Bridge")
            return
        }
        root := RTrim(Trim(this.settingsView.LogRoot()), "\/")
        if !DirExist(root) {
            MsgBox("로그 폴더 없음 · 연결 설정 확인", "NoMachine Hangul Bridge")
            return
        }
        this.RegisterKey(this.pendingKey)
        this.key := this.pendingKey
        this.output := this.outputControl.Text
        this.detector.logRoot := root
        DirCreate(this.dataDir)
        IniWrite(this.key, this.configFile, "Mapping", "Key")
        IniWrite(this.output, this.configFile, "Mapping", "Output")
        IniWrite(root, this.configFile, "Detection", "LogRoot")
        BridgeStartup.Set(this.autoControl.Value, this.startupLink)
        this.Refresh()
        this.HideSettings()
    }

    RunState() {
        if !this.enabled
            return {id: "paused", label: "일시 중지", color: "64748B", icon: "paused"}
        if this.capturing
            return {id: "learning", label: "한영키 감지 중", color: "2563EB", icon: "waiting"}
        if this.key = ""
            return {id: "unconfigured", label: "한영키 미등록", color: "2563EB", icon: "waiting"}
        if this.detector.error != ""
            return {id: "error", label: "연결 조회 실패", color: "2563EB", icon: "waiting"}
        for pid, record in this.detector.records {
            if record.ok
                return {id: "ready", label: "Mac 연결됨", color: "0F766E", icon: "ready"}
        }
        return {id: "waiting", label: "Mac 연결 대기", color: "2563EB", icon: "waiting"}
    }

    static ReasonDescription(reason) {
        switch reason {
            case "unrecognized-log": return "로그 형식 미확인"
            case "process-not-linked", "invalid-process-time", "stale-or-other-process": return "연결 로그 불일치"
            case "desktop-not-running": return "데스크톱 시작 대기"
            case "platform-not-confirmed": return "운영체제 미확인"
            case "non-mac-desktop": return "Mac 데스크톱 아님"
            case "no-current-session-log": return "연결 로그 없음"
            case "ambiguous-session-logs": return "연결 로그 중복"
            default: return "연결 미확인"
        }
    }

    UpdateTray(state) {
        if !this.trayReady || state.id = this.lastTrayState
            return
        icon := this.assetsDir "\bridge-" state.icon ".ico"
        if FileExist(icon)
            TraySetIcon(icon, 1, true)
        A_IconTip := "NoMachine Hangul Bridge`n" state.label
        this.lastTrayState := state.id
    }

    UpdateStatus() {
        state := this.RunState()
        this.UpdateTray(state)
        if !this.window
            return
        this.settingsView.UpdateState(state)
        this.settingsView.UpdateConnections()
    }
}

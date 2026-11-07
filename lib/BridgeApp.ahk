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
        A_TrayMenu.Add("설정 및 연결 상태", (*) => this.ShowSettings())
        A_TrayMenu.Add("일시 중지", (*) => this.TogglePause())
        A_TrayMenu.Add()
        A_TrayMenu.Add("종료", (*) => ExitApp())
        A_TrayMenu.Default := "설정 및 연결 상태"
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
        if this.window {
            this.window.Show(visible ? "" : "Hide")
            return
        }
        this.settingsView := BridgeSettingsView(this)
        this.window := this.settingsView.window
        this.UpdateStatus()
        this.window.Show((visible ? "" : "Hide ") "w680 h648")
    }

    HideSettings() {
        this.CancelCapture()
        this.settingsView.details.Hide()
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
        TrayTip("알림 영역에서 계속 실행 중입니다.`n‘!한’ 아이콘을 두 번 클릭하면 설정을 열 수 있습니다.", "NoMachine Hangul Bridge", 1)
    }

    KeyDescription() {
        return this.key = "" ? "아직 등록한 키가 없습니다.`n아래 버튼을 눌러 시작하세요." : "등록됨 · " this.key "`n다음 실행에도 자동으로 불러옵니다."
    }

    BeginCapture(*) {
        this.CancelCapture()
        this.capturing := true
        this.keyLabel.Text := "한영키를 한 번 누르세요.`n8초 안에 감지 · Esc로 취소"
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
            this.keyLabel.Text := "감지 시간이 지났습니다.`n아래 버튼으로 다시 시도하세요."
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
            MsgBox("먼저 한영키 감지 버튼으로 키를 등록하세요.", "NoMachine Hangul Bridge")
            return
        }
        root := RTrim(Trim(this.rootControl.Value), "\/")
        if !DirExist(root) {
            MsgBox("NoMachine 연결 로그 폴더를 찾을 수 없습니다.", "NoMachine Hangul Bridge")
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
            return {id: "paused", label: "일시 중지됨", color: "64748B", icon: "paused"}
        if this.capturing
            return {id: "learning", label: "한영키 감지 중", color: "2563EB", icon: "waiting"}
        if this.key = ""
            return {id: "unconfigured", label: "한영키를 등록해 주세요", color: "2563EB", icon: "waiting"}
        for pid, record in this.detector.records {
            if record.ok
                return {id: "ready", label: "Mac 연결 준비 완료", color: "0F766E", icon: "ready"}
        }
        return {id: "waiting", label: "Mac 연결 대기 중", color: "2563EB", icon: "waiting"}
    }

    StateDescription(state) {
        if state.id = "paused"
            return "한영키 전환을 잠시 멈췄습니다. ‘다시 시작’을 누르면 재개합니다."
        if state.id = "learning"
            return "현재 설정 창에서 전환에 사용할 한영키를 한 번 눌러 주세요."
        if state.id = "unconfigured"
            return "한 번만 등록하면 다음 실행부터 저장된 키를 자동으로 불러옵니다."
        if this.detector.error != ""
            return "연결 정보를 읽지 못했습니다. 연결 설정에서 자세한 상태를 확인하세요."
        if state.id = "ready"
            return "확인된 Mac 연결 창에서 한영키를 누르면 입력 소스를 전환합니다."
        return "NoMachine에서 Mac에 연결하면 자동으로 준비됩니다."
    }

    static ReasonDescription(reason) {
        switch reason {
            case "unrecognized-log": return "연결 로그 형식을 확인할 수 없습니다."
            case "process-not-linked", "invalid-process-time", "stale-or-other-process": return "현재 연결과 일치하는 로그를 확인하지 못했습니다."
            case "desktop-not-running": return "원격 데스크톱이 실행 중이 아닙니다."
            case "platform-not-confirmed": return "원격 운영체제를 아직 확인하지 못했습니다."
            case "non-mac-desktop": return "Mac 데스크톱으로 확인되지 않아 기본 키 동작을 유지합니다."
            case "no-current-session-log": return "현재 연결 로그를 찾지 못했습니다."
            case "ambiguous-session-logs": return "일치하는 연결 로그가 여러 개입니다."
            default: return "연결을 확인하지 못해 기본 키 동작을 유지합니다."
        }
    }

    UpdateTray(state) {
        if !this.trayReady
            return
        if state.id != this.lastTrayState {
            icon := this.assetsDir "\bridge-" state.icon ".ico"
            if FileExist(icon)
                TraySetIcon(icon, 1, true)
            this.lastTrayState := state.id
        }
        A_IconTip := "NoMachine Hangul Bridge`n" state.label "`n더블클릭: 설정 / 우클릭: 일시 중지·종료"
    }

    UpdateStatus() {
        state := this.RunState()
        this.UpdateTray(state)
        if !this.window
            return
        this.settingsView.UpdateState(state)
        this.runLabel.Text := state.label
        this.runLabel.SetFont("c" state.color)
        this.stateDetail.Text := this.StateDescription(state)
        this.pauseControl.Text := this.enabled ? "일시 중지" : "다시 시작"
        status := this.enabled ? "실행 중" : "일시 중지됨"
        status .= this.key = "" ? " / 한영키 미등록" : " / " this.key
        for pid, record in this.detector.records {
            platform := record.platform = "Unknown" ? "운영체제 확인 중" : record.platform
            status .= "`r`n" record.title " · " platform
            status .= record.ok ? " · Mac 연결 확인됨" : "`r`n" HangulBridge.ReasonDescription(record.reason)
        }
        if this.detector.records.Count = 0
            status .= "`r`nNoMachine 연결을 기다리고 있습니다."
        if this.detector.error != ""
            status .= "`r`n연결 정보를 읽지 못했습니다. NoMachine 실행 상태를 확인해 주세요."
        this.statusControl.Value := status
    }
}

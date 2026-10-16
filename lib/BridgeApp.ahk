#Include StartupLink.ahk

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
        this.assetsDir := A_ScriptDir "\assets"
        this.trayReady := false
        this.lastTrayState := ""
        this.hiddenNoticeShown := false
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
        notice := this.key = "" ? "처음 한 번만 한영키를 등록해 주세요." : "저장된 한영키 설정을 자동으로 불러왔습니다."
        TrayTip(notice "`n알림 영역의 ‘한’ 아이콘에서 상태와 설정을 확인하세요.", "NoMachine Hangul Bridge", 1)
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
        if this.enabled {
            A_TrayMenu.Uncheck("일시 중지")
        } else {
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
        this.window := Gui(, "NoMachine Hangul Bridge")
        this.window.SetFont("s10", "Segoe UI")
        this.runLabel := this.window.AddText("w620", "")
        this.runLabel.SetFont("s13 Bold")
        this.window.AddText("xm y+8 w620", "이 프로그램은 현재 Windows에서 실행됩니다. 알림 영역의 ‘한’ 아이콘으로 확인하세요.`n현재 연결 로그에서 Mac으로 확인된 NoMachine 창에만 적용합니다.")
        this.window.AddText("xm y+16", "1. 전환에 사용할 한영키")
        this.keyLabel := this.window.AddText("w420", this.key = "" ? "아직 등록하지 않았습니다." : this.key " (저장된 키 · 재등록 불필요)")
        this.window.AddButton("x+8 yp-4 w170", "한영키 감지 / 변경").OnEvent("Click", ObjBindMethod(this, "BeginCapture"))
        this.window.AddText("xm y+16", "2. Mac에 설정된 입력 소스 전환 단축키")
        this.outputControl := this.window.AddDropDownList("w280 Choose" (this.output = "Control+Space" ? 1 : 2), ["Control+Space", "Control+Option+Space"])
        this.window.AddText("xm w620", "Mac의 시스템 설정 → 키보드 → 키보드 단축키 → 입력 소스와 맞춰 주세요.")
        this.window.AddText("xm y+12", "3. NoMachine 연결 로그 폴더")
        this.rootControl := this.window.AddEdit("w620", this.detector.logRoot)
        this.autoControl := this.window.AddCheckbox("xm y+14", "Windows 로그인 시 실행")
        this.autoControl.Value := !!BridgeStartup.Read(this.startupLink)
        this.window.AddText("xm w620", "자동 실행을 선택하지 않으면, PC 재부팅 후 Start.cmd로 다시 실행해야 합니다.")
        this.window.AddText("xm y+14", "연결 판별 상태 (약 1.5초마다 갱신)")
        this.statusControl := this.window.AddEdit("w620 r5 ReadOnly", "")
        this.window.AddButton("xm y+14 w150 Default", "저장 후 창 닫기").OnEvent("Click", ObjBindMethod(this, "SaveSettings"))
        this.window.AddButton("x+10 w140", "일시 중지 / 재개").OnEvent("Click", (*) => this.TogglePause())
        this.window.AddButton("x+10 w110", "종료").OnEvent("Click", (*) => ExitApp())
        this.window.AddText("xm y+12 w620", "gksdud 및 SSH 설치가 필요 없습니다. 원격 OS를 확인할 수 없으면 매핑하지 않습니다.`n창을 닫아도 알림 영역에서 계속 실행됩니다. 종료하려면 ‘종료’를 선택하세요.")
        this.window.OnEvent("Close", (*) => this.HideSettings())
        this.UpdateStatus()
        this.window.Show(visible ? "" : "Hide")
    }

    HideSettings() {
        this.CancelCapture()
        this.window.Hide()
        if !this.hiddenNoticeShown {
            this.hiddenNoticeShown := true
            TrayTip("설정 창을 닫아도 알림 영역의 ‘한’ 아이콘에 남습니다.`n완전히 종료하려면 아이콘 우클릭 → 종료를 선택하세요.", "NoMachine Hangul Bridge", 1)
        }
    }

    BeginCapture(*) {
        this.CancelCapture()
        this.capturing := true
        this.keyLabel.Text := "이 창에서 한영키를 한 번 누르세요. (8초, Esc 취소)"
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
        this.keyLabel.Text := this.key " (등록·저장 완료 · 다음 실행에 자동 복원)"
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
            this.keyLabel.Text := this.pendingKey = "" ? "감지가 끝났습니다. 다시 시도하세요." : this.pendingKey
        }
    }

    CancelCapture() {
        if !this.capturing
            return
        this.capturing := false
        this.captureHook.Stop()
        this.keyLabel.Text := this.pendingKey = "" ? "아직 등록하지 않았습니다." : this.pendingKey
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
            return {id: "learning", label: "실행 중 · 한영키 등록 중", color: "2563EB", icon: "waiting"}
        if this.key = ""
            return {id: "unconfigured", label: "실행 중 · 한영키 등록 필요", color: "2563EB", icon: "waiting"}
        for pid, record in this.detector.records {
            if record.ok
                return {id: "ready", label: "실행 중 · Mac 연결 확인됨", color: "0F766E", icon: "ready"}
        }
        return {id: "waiting", label: "실행 중 · Mac 연결 대기", color: "2563EB", icon: "waiting"}
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
        this.runLabel.Text := state.label
        this.runLabel.SetFont("c" state.color)
        status := this.enabled ? "실행 중" : "일시 중지됨"
        status .= this.key = "" ? " / 한영키 미등록" : " / " this.key
        for pid, record in this.detector.records {
            status .= "`r`n" record.title " / " record.platform
            status .= record.ok ? " / Mac 판별 완료" : " / 적용 안 함: " record.reason
        }
        if this.detector.records.Count = 0
            status .= "`r`n실행 중인 연결 프로세스를 찾지 못했습니다."
        if this.detector.error != ""
            status .= "`r`n" this.detector.error
        this.statusControl.Value := status
    }
}

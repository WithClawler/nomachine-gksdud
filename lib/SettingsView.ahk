; Presentation only. Key routing and session evidence stay in BridgeApp/SessionDetector.
class BridgeSettingsView {
    static StatusWidth := 512
    static StatusHeight := 56

    __New(bridge) {
        this.bridge := bridge
        this.details := false
        this.lastState := ""
        this.lastConnectionText := ""
        this.window := Gui(, "NoMachine Hangul Bridge")
        this.window.BackColor := "F4F6F8"
        this.window.SetFont("s10 c172B3A", "Malgun Gothic")
        this.window.MarginX := 0
        this.window.MarginY := 0
        this.logo := this.window.AddPicture("x24 y20 w40 h40 BackgroundTrans", bridge.assetsDir "\bridge-waiting.png")
        this.logoState := ""
        this.Text(this.window, "x76 y24 w460 h32", "NoMachine Hangul Bridge", 19, , true)

        this.statusSurface := this.Surface(this.window, 24, 80, BridgeSettingsView.StatusWidth, BridgeSettingsView.StatusHeight, "EAF1FE")
        bridge.runLabel := this.Text(this.window, "x42 y94 w360 h29", "", 14, "0F766E", true)
        bridge.pauseControl := this.Button(this.window, "x414 y92 w104 h32", "일시 중지", (*) => bridge.TogglePause(), "soft", "EAF1FE")

        this.Surface(this.window, 24, 152, 248, 108)
        this.Text(this.window, "x42 y164 w212 h24", "한영키", 11, , true)
        bridge.keyLabel := this.Text(this.window, "x42 y191 w212 h21", bridge.KeyDescription(), 9, "596B78")
        bridge.captureControl := this.Button(this.window, "x42 y218 w212 h28", bridge.key = "" ? "키 등록" : "키 변경", ObjBindMethod(bridge, "BeginCapture"))

        this.Surface(this.window, 288, 152, 248, 108)
        this.Text(this.window, "x306 y164 w212 h24", "Mac 전환 단축키", 11, , true)
        bridge.outputControl := this.window.AddDropDownList("x306 y213 w212 r2 Choose" (bridge.output = "Control+Space" ? 1 : 2), ["Control+Space", "Control+Option+Space"])

        this.Surface(this.window, 24, 276, 512, 54)
        bridge.autoControl := this.window.AddCheckbox("x42 y289 w300 h28 BackgroundFFFFFF", "Windows 로그인 시 실행")
        bridge.autoControl.Value := !!BridgeStartup.Read(bridge.startupLink)
        this.Button(this.window, "x414 y288 w104 h30", "연결 설정", (*) => this.ShowDetails(), "soft")

        this.Button(this.window, "x24 y346 w104 h36", "앱 종료", (*) => ExitApp(), "secondary", "F4F6F8")
        bridge.saveControl := this.Button(this.window, "x416 y346 w120 h36", "저장 후 닫기", ObjBindMethod(bridge, "SaveSettings"), "primary", "F4F6F8")
        ; Keep a real default button and native keyboard navigation.
        bridge.saveControl.Opt("Default")
        this.window.OnEvent("Close", (*) => bridge.HideSettings())
        this.RoundWindow(this.window)
    }

    Show(visible := true) {
        this.window.Show((visible ? "" : "Hide ") "w560 h402")
    }

    CreateDetails() {
        this.details := Gui("+Owner" this.window.Hwnd, "연결 설정")
        this.details.BackColor := "F4F6F8"
        this.details.SetFont("s10 c172B3A", "Malgun Gothic")
        this.details.MarginX := 0
        this.details.MarginY := 0
        this.Text(this.details, "x24 y20 w512 h32", "연결 설정", 17, , true)
        this.Surface(this.details, 24, 68, 512, 88)
        this.Text(this.details, "x42 y80 w476 h24", "NoMachine 로그 폴더", 11, , true)
        this.rootControl := this.details.AddEdit("x42 y110 w376 h30 -E0x200 Border", this.bridge.detector.logRoot)
        this.Button(this.details, "x430 y110 w88 h30", "찾아보기", (*) => this.BrowseLogs())
        this.Surface(this.details, 24, 172, 512, 124)
        this.Text(this.details, "x42 y184 w476 h24", "현재 연결", 11, , true)
        this.statusControl := this.details.AddEdit("x42 y216 w476 h64 ReadOnly -E0x200 -Border BackgroundFFFFFF", "")
        this.statusControl.SetFont("s9 c3D5262")
        this.Text(this.details, "x24 y321 w300 h22", "설정 창에서 저장", 9, "596B78")
        this.Button(this.details, "x416 y312 w120 h36", "돌아가기", (*) => this.details.Hide(), "primary", "F4F6F8")
        this.details.OnEvent("Close", (*) => this.details.Hide())
        this.details.OnEvent("Escape", (*) => this.details.Hide())
        this.RoundWindow(this.details)
    }

    ShowDetails(visible := true) {
        this.bridge.CancelCapture()
        if !this.details
            this.CreateDetails()
        this.UpdateConnections(true)
        this.details.Show((visible ? "" : "Hide ") "w560 h368")
    }

    HideDetails() {
        if this.details
            this.details.Hide()
    }

    LogRoot() {
        return this.details ? this.rootControl.Value : this.bridge.detector.logRoot
    }

    UpdateState(state) {
        if state.id = this.lastState
            return
        if state.icon != this.logoState {
            tint := state.icon = "ready" ? "E8F3F0" : (state.icon = "paused" ? "EEF1F5" : "EAF1FE")
            this.logo.Value := this.bridge.assetsDir "\bridge-" state.icon ".png"
            this.statusSurface.Value := "HBITMAP:" this.SurfaceBitmap(this.window, BridgeSettingsView.StatusWidth, BridgeSettingsView.StatusHeight, tint)
            this.bridge.pauseControl.paintStyle.background := tint
            this.bridge.runLabel.SetFont("c" state.color)
            this.logoState := state.icon
        }
        this.bridge.runLabel.Text := state.label
        this.bridge.pauseControl.Text := this.bridge.enabled ? "일시 중지" : "재개"
        this.lastState := state.id
    }

    UpdateConnections(force := false) {
        if !this.details || (!force && !DllCall("IsWindowVisible", "ptr", this.details.Hwnd))
            return
        detector := this.bridge.detector
        status := ""
        for pid, record in detector.records
            status .= (status = "" ? "" : "`r`n") record.title " · " (record.ok ? "Mac 연결됨" : HangulBridge.ReasonDescription(record.reason))
        if status = ""
            status := detector.error = "" ? "연결 없음" : "연결 정보 조회 실패"
        if status != this.lastConnectionText {
            this.statusControl.Value := status
            this.lastConnectionText := status
        }
    }

    BrowseLogs() {
        this.details.Opt("+OwnDialogs")
        selected := DirSelect("*" this.rootControl.Value, 0, "NoMachine 로그 폴더 선택")
        if selected != ""
            this.rootControl.Value := selected
    }

    Text(window, options, value, size := 10, color := "172B3A", bold := false) {
        control := window.AddText(options " BackgroundTrans", value)
        control.SetFont("s" size " c" color (bold ? " Bold" : " Norm"))
        return control
    }

    Surface(window, x, y, w, h, color := "FFFFFF", radius := 14) {
        return window.AddPicture("x" x " y" y " w" w " h" h, "HBITMAP:" this.SurfaceBitmap(window, w, h, color, radius))
    }

    SurfaceBitmap(window, w, h, color := "FFFFFF", radius := 14) {
        ; Use a generated bitmap so rounded surfaces also render in WM_PRINT.
        ; Gui owns the HBITMAP and releases it when the picture is destroyed.
        scale := A_ScreenDPI / 96
        width := Round(w * scale), height := Round(h * scale)
        dc := DllCall("GetDC", "ptr", 0, "ptr")
        mem := DllCall("CreateCompatibleDC", "ptr", dc, "ptr")
        bitmap := DllCall("CreateCompatibleBitmap", "ptr", dc, "int", width, "int", height, "ptr")
        oldBitmap := DllCall("SelectObject", "ptr", mem, "ptr", bitmap, "ptr")
        rect := Buffer(16, 0)
        NumPut("int", width, "int", height, rect, 8)
        background := DllCall("CreateSolidBrush", "uint", BridgeSettingsView.Color(window.BackColor), "ptr")
        DllCall("FillRect", "ptr", mem, "ptr", rect, "ptr", background)
        DllCall("DeleteObject", "ptr", background)
        brush := DllCall("CreateSolidBrush", "uint", BridgeSettingsView.Color(color), "ptr")
        pen := DllCall("CreatePen", "int", 0, "int", 1, "uint", BridgeSettingsView.Color(color), "ptr")
        oldBrush := DllCall("SelectObject", "ptr", mem, "ptr", brush, "ptr")
        oldPen := DllCall("SelectObject", "ptr", mem, "ptr", pen, "ptr")
        DllCall("RoundRect", "ptr", mem, "int", 0, "int", 0, "int", width, "int", height, "int", Round(radius * scale), "int", Round(radius * scale))
        DllCall("SelectObject", "ptr", mem, "ptr", oldBrush)
        DllCall("SelectObject", "ptr", mem, "ptr", oldPen)
        DllCall("SelectObject", "ptr", mem, "ptr", oldBitmap)
        DllCall("DeleteObject", "ptr", brush)
        DllCall("DeleteObject", "ptr", pen)
        DllCall("DeleteDC", "ptr", mem)
        DllCall("ReleaseDC", "ptr", 0, "ptr", dc)
        return bitmap
    }

    Button(window, options, text, callback, kind := "secondary", background := "FFFFFF") {
        button := window.AddButton(options, text)
        button.SetFont("s9 Bold")
        style := {kind: kind, background: background}
        button.paintStyle := style
        ; NM_CUSTOMDRAW keeps native button semantics, including default/keyboard behavior.
        button.OnNotify(-12, ObjBindMethod(BridgeSettingsView, "DrawButton", style))
        button.OnEvent("Click", callback)
        return button
    }

    RoundWindow(window) {
        ; Windows 11 rounds the frame; Windows 10 keeps its supported native frame.
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", window.Hwnd, "uint", 33, "int*", 2, "uint", 4)
    }

    static Color(hex) {
        value := Integer("0x" hex)
        return ((value & 0xFF) << 16) | (value & 0xFF00) | ((value >> 16) & 0xFF)
    }

    static DrawButton(style, control, lParam) {
        if NumGet(lParam, A_PtrSize = 8 ? 24 : 12, "uint") != 1 ; CDDS_PREPAINT
            return
        hwnd := control.Hwnd
        dc := NumGet(lParam, A_PtrSize = 8 ? 32 : 16, "ptr")
        rectOffset := A_PtrSize = 8 ? 40 : 20
        width := NumGet(lParam, rectOffset + 8, "int")
        height := NumGet(lParam, rectOffset + 12, "int")
        state := NumGet(lParam, A_PtrSize = 8 ? 64 : 40, "uint")
        pressed := state & 1
        disabled := state & 4
        hot := state & 0x40
        fill := style.kind = "primary" ? (pressed ? "115E59" : (hot ? "0D6962" : "0F766E")) : (pressed ? "DCE5E9" : (hot ? "DFE8ED" : "EAF0F3"))
        textColor := disabled ? "72818C" : (style.kind = "primary" ? "FFFFFF" : "243D4C")
        background := DllCall("CreateSolidBrush", "uint", this.Color(style.background), "ptr")
        DllCall("FillRect", "ptr", dc, "ptr", lParam + rectOffset, "ptr", background)
        DllCall("DeleteObject", "ptr", background)
        brush := DllCall("CreateSolidBrush", "uint", this.Color(fill), "ptr")
        pen := DllCall("CreatePen", "int", 0, "int", 1, "uint", this.Color(fill), "ptr")
        oldBrush := DllCall("SelectObject", "ptr", dc, "ptr", brush, "ptr")
        oldPen := DllCall("SelectObject", "ptr", dc, "ptr", pen, "ptr")
        radius := Round(10 * A_ScreenDPI / 96)
        DllCall("RoundRect", "ptr", dc, "int", 0, "int", 0, "int", width, "int", height, "int", radius, "int", radius)
        DllCall("SelectObject", "ptr", dc, "ptr", oldBrush)
        DllCall("SelectObject", "ptr", dc, "ptr", oldPen)
        DllCall("DeleteObject", "ptr", brush)
        DllCall("DeleteObject", "ptr", pen)
        font := SendMessage(0x31, 0, 0, hwnd)
        oldFont := DllCall("SelectObject", "ptr", dc, "ptr", font, "ptr")
        DllCall("SetBkMode", "ptr", dc, "int", 1)
        DllCall("SetTextColor", "ptr", dc, "uint", this.Color(textColor))
        DllCall("DrawTextW", "ptr", dc, "str", ControlGetText(hwnd), "int", -1, "ptr", lParam + rectOffset, "uint", 0x25)
        DllCall("SelectObject", "ptr", dc, "ptr", oldFont)
        if state & 0x10 {
            focus := Buffer(16)
            NumPut("int", 4, "int", 4, "int", width - 4, "int", height - 4, focus)
            DllCall("DrawFocusRect", "ptr", dc, "ptr", focus)
        }
        return 4 ; CDRF_SKIPDEFAULT
    }
}

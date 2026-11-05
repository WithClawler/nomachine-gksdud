; Presentation only. Key routing and session evidence stay in BridgeApp/SessionDetector.
class BridgeSettingsView {
    __New(bridge) {
        this.bridge := bridge
        this.window := Gui(, "NoMachine Hangul Bridge")
        this.window.BackColor := "F4F6F8"
        this.window.SetFont("s10 c172B3A", "Malgun Gothic")
        this.window.MarginX := 0
        this.window.MarginY := 0
        this.logo := this.window.AddPicture("x28 y24 w40 h40 BackgroundTrans", bridge.assetsDir "\bridge-waiting.png")
        this.logoState := ""
        this.Text(this.window, "x84 y20 w560 h32", "NoMachine Hangul Bridge", 19, , true)
        this.Text(this.window, "x84 y56 w560 h24", "원격 Mac에서도 익숙한 한영키로.", 10, "596B78")

        this.statusSurface := this.Surface(this.window, 28, 98, 624, 100, "EAF1FE")
        bridge.runLabel := this.Text(this.window, "x48 y114 w436 h28", "", 14, "0F766E", true)
        bridge.stateDetail := this.Text(this.window, "x48 y151 w576 h36", "", 9, "3D5E59")
        bridge.pauseControl := this.Button(this.window, "x526 y112 w106 h32", "일시 중지", (*) => bridge.TogglePause(), "soft", "EAF1FE")

        this.Surface(this.window, 28, 214, 302, 176)
        this.Text(this.window, "x48 y232 w262 h24", "한영키", 11, , true)
        bridge.keyLabel := this.Text(this.window, "x48 y270 w262 h40", bridge.KeyDescription(), 9, "596B78")
        bridge.captureControl := this.Button(this.window, "x48 y334 w262 h36", "한영키 감지 / 변경", ObjBindMethod(bridge, "BeginCapture"))

        this.Surface(this.window, 346, 214, 306, 176)
        this.Text(this.window, "x366 y232 w266 h24", "Mac 전환 단축키", 11, , true)
        bridge.outputControl := this.window.AddDropDownList("x366 y268 w266 r2 Choose" (bridge.output = "Control+Space" ? 1 : 2), ["Control+Space", "Control+Option+Space"])
        this.Text(this.window, "x366 y315 w266 h56", "Mac의 키보드 단축키 → 입력 소스에`n설정된 조합과 맞춰 주세요.", 9, "596B78")

        this.Surface(this.window, 28, 406, 624, 112)
        bridge.autoControl := this.window.AddCheckbox("x48 y424 w560 h26 BackgroundFFFFFF", "Windows 로그인 시 실행")
        bridge.autoControl.Value := !!BridgeStartup.Read(bridge.startupLink)
        this.Text(this.window, "x70 y456 w550 h22", "선택하면 다음 로그인부터 자동으로 실행합니다.", 9, "596B78")
        this.Button(this.window, "x48 y480 w242 h28", "연결 설정 및 상태 보기", (*) => this.ShowDetails(), "soft")

        this.Text(this.window, "x28 y532 w624 h22", "한영키는 감지 즉시 저장됩니다. 나머지 설정은 저장 후 적용됩니다.", 9, "596B78")
        this.Button(this.window, "x28 y564 w108 h38", "앱 종료", (*) => ExitApp(), "secondary", "F4F6F8")
        bridge.saveControl := this.Button(this.window, "x480 y564 w172 h38", "저장 후 닫기", ObjBindMethod(bridge, "SaveSettings"), "primary", "F4F6F8")
        ; Keep a real default button and native keyboard navigation.
        bridge.saveControl.Opt("Default")
        this.Text(this.window, "x28 y614 w624 h22", "창을 닫아도 알림 영역에서 계속 실행됩니다.", 9, "596B78")
        this.window.OnEvent("Close", (*) => bridge.HideSettings())
        this.CreateDetails()
        this.RoundWindow(this.window)
    }

    CreateDetails() {
        bridge := this.bridge
        this.details := Gui("+Owner" this.window.Hwnd, "연결 설정 및 상태")
        this.details.BackColor := "F4F6F8"
        this.details.SetFont("s10 c172B3A", "Malgun Gothic")
        this.details.MarginX := 0
        this.details.MarginY := 0
        this.Text(this.details, "x24 y22 w572 h32", "연결 설정 및 상태", 17, , true)
        this.Text(this.details, "x24 y64 w572 h24", "연결 상태는 약 1.5초마다 자동으로 갱신됩니다.", 9, "596B78")
        this.Surface(this.details, 24, 104, 572, 136)
        this.Text(this.details, "x44 y120 w532 h24", "NoMachine 로그 폴더", 11, , true)
        bridge.rootControl := this.details.AddEdit("x44 y158 w430 h30 -E0x200 Border", bridge.detector.logRoot)
        this.Button(this.details, "x486 y158 w90 h30", "찾아보기", (*) => this.BrowseLogs())
        this.Text(this.details, "x44 y202 w532 h22", "직접 바꾼 경우에만 지정하세요. 기본 위치: 사용자 폴더의 .nx", 9, "596B78")
        this.Surface(this.details, 24, 256, 572, 164)
        this.Text(this.details, "x44 y270 w532 h24", "현재 연결", 11, , true)
        bridge.statusControl := this.details.AddEdit("x44 y306 w532 h94 ReadOnly -E0x200 -Border BackgroundFFFFFF", "")
        bridge.statusControl.SetFont("s9 c3D5262")
        this.Text(this.details, "x24 y438 w572 h38", "로그 폴더 변경은 기본 창의 ‘저장 후 닫기’로 적용합니다.`nMac으로 확인된 연결 창에서만 한영키를 전환합니다.", 9, "596B78")
        this.Button(this.details, "x468 y494 w128 h36", "기본 창으로", (*) => this.details.Hide(), "primary", "F4F6F8")
        this.details.OnEvent("Close", (*) => this.details.Hide())
        this.details.OnEvent("Escape", (*) => this.details.Hide())
        this.RoundWindow(this.details)
    }

    ShowDetails() {
        this.bridge.CancelCapture()
        this.details.Show("w620 h554")
    }

    UpdateState(state) {
        if state.icon = this.logoState
            return
        tint := state.icon = "ready" ? "E8F3F0" : (state.icon = "paused" ? "EEF1F5" : "EAF1FE")
        this.logo.Value := this.bridge.assetsDir "\bridge-" state.icon ".png"
        this.statusSurface.Value := "HBITMAP:" this.SurfaceBitmap(this.window, 624, 100, tint)
        this.bridge.pauseControl.paintStyle.background := tint
        this.bridge.stateDetail.SetFont("c" state.color)
        this.logoState := state.icon
    }

    BrowseLogs() {
        this.details.Opt("+OwnDialogs")
        selected := DirSelect("*" this.bridge.rootControl.Value, 0, "NoMachine 로그 폴더 선택")
        if selected != ""
            this.bridge.rootControl.Value := selected
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

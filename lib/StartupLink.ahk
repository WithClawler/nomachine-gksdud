class BridgeStartup {
    static Path := A_Startup "\NoMachine Hangul Bridge.lnk"

    ; An existing link is consent only if it identifies this application.
    static Read(link := BridgeStartup.Path) {
        if !FileExist(link)
            return false
        try {
            FileGetShortcut(link, &target, &dir, &args, &description)
            if description != "NoMachine Hangul Bridge"
                return false
            if !RegExMatch(args, 'i)^"([^"\r\n]+\\NoMachineHangulBridge\.ahk)" --quiet$', &match)
                return false
            SplitPath(target, &exe)
            if !RegExMatch(exe, "i)^AutoHotkey(?:32|64)?\.exe$")
                return false
            return {target: target, script: match[1], dir: dir}
        }
        return false
    }

    static Set(enabled, link := BridgeStartup.Path, script := A_ScriptFullPath, runtime := A_AhkPath) {
        if !enabled {
            if this.Read(link)
                FileDelete(link)
            return
        }
        if FileExist(link) && !this.Read(link)
            throw Error("The startup shortcut belongs to another application.")
        SplitPath(script, , &dir)
        icon := dir "\assets\bridge-waiting.ico"
        if !FileExist(icon)
            icon := runtime
        FileCreateShortcut(runtime, link, dir, '"' script '" --quiet', "NoMachine Hangul Bridge", icon)
    }

    static Repair(link := BridgeStartup.Path, script := A_ScriptFullPath, runtime := A_AhkPath) {
        if this.Read(link)
            this.Set(true, link, script, runtime)
    }

    static RemoveOwned(link := BridgeStartup.Path, script := A_ScriptFullPath) {
        existing := this.Read(link)
        if existing && StrCompare(existing.script, script, false) = 0
            FileDelete(link)
    }
}

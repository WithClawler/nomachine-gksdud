; Shared by every install/portable/development copy in this Windows session.
; Keep this name stable across versions and in the Inno Setup AppMutex directive.
class BridgeInstance {
    static Name := "Local\NoMachineHangulBridge-3D80D846-ECBD-4C32-AE04-03D80C80F90B"

    __New(name := BridgeInstance.Name) {
        this.handle := DllCall("CreateMutexW", "ptr", 0, "int", false, "str", name, "ptr")
        status := A_LastError
        if !this.handle
            throw OSError(status, "CreateMutexW")
        this.acquired := status != 183 ; ERROR_ALREADY_EXISTS
    }

    __Delete() {
        if this.handle
            DllCall("CloseHandle", "ptr", this.handle)
    }
}

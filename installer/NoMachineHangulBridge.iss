#ifndef AppVersion
  #error AppVersion must be provided by tools/Build.ps1
#endif
#ifndef StageDir
  #error StageDir must be provided by tools/Build.ps1
#endif

[Setup]
AppId={{3D80D846-ECBD-4C32-AE04-03D80C80F90B}
AppName=NoMachine Hangul Bridge
AppVersion={#AppVersion}
VersionInfoVersion={#AppNumericVersion}
AppPublisher=NoMachine Hangul Bridge contributors
DefaultDirName={localappdata}\Programs\NoMachineHangulBridge
DefaultGroupName=NoMachine Hangul Bridge
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
OutputBaseFilename=NoMachineHangulBridge-{#AppVersion}-windows-x64-setup
SetupIconFile={#StageDir}\assets\bridge-ready.ico
UninstallDisplayIcon={app}\assets\bridge-ready.ico
LicenseFile={#StageDir}\LICENSE
AppMutex=Local\NoMachineHangulBridge-3D80D846-ECBD-4C32-AE04-03D80C80F90B
SetupMutex=Local\NoMachineHangulBridge-Setup-3D80D846
CloseApplications=no
RestartApplications=no

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\NoMachine Hangul Bridge"; Filename: "{app}\runtime\AutoHotkey64.exe"; Parameters: """{app}\NoMachineHangulBridge.ahk"" --settings"; WorkingDir: "{app}"; IconFilename: "{app}\assets\bridge-ready.ico"
Name: "{autodesktop}\NoMachine Hangul Bridge"; Filename: "{app}\runtime\AutoHotkey64.exe"; Parameters: """{app}\NoMachineHangulBridge.ahk"" --settings"; WorkingDir: "{app}"; IconFilename: "{app}\assets\bridge-ready.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\runtime\AutoHotkey64.exe"; Parameters: """{app}\NoMachineHangulBridge.ahk"" --repair-startup"; Flags: runhidden waituntilterminated
Filename: "{app}\runtime\AutoHotkey64.exe"; Parameters: """{app}\NoMachineHangulBridge.ahk"" --quiet"; Description: "Start NoMachine Hangul Bridge"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\runtime\AutoHotkey64.exe"; Parameters: """{app}\NoMachineHangulBridge.ahk"" --remove-startup"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveOwnedStartupLink"
; Intentionally preserve %LOCALAPPDATA%\NoMachineHangulBridge\settings.ini.
; No per-user key registration or profile is installed over an existing profile.

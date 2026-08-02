#define MyAppName "Syswatch Admin"
#define MyAppVersion "2.3.3"
#define MyAppPublisher "NU Clark"

; IMPORTANT:
; Confirm the exact .exe name inside:
; build\windows\x64\runner\Release
;
; Common possibilities:
;   itsoadminappcapstone.exe
;   staff_admin_app.exe
;
#define MyAppExeName "itsoadminappcapstone.exe"
#define VCRedistFile "VC_redist.x64.exe"

[Setup]
AppId={{6D1DC2E3-8952-4B61-8FE6-C1A5C32A7778}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\Syswatch Admin
DefaultGroupName=Syswatch Admin
DisableProgramGroupPage=yes

OutputDir=output
OutputBaseFilename=Syswatch_Admin_Setup_v{#MyAppVersion}

; Enable only when you have a valid Windows .ico file.
; SetupIconFile=..\assets\app_icon.ico

UninstallDisplayIcon={app}\{#MyAppExeName}

Compression=lzma2
SolidCompression=yes
WizardStyle=modern

PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

CloseApplications=yes
RestartApplications=no
RestartIfNeededByRun=no
SetupLogging=yes

VersionInfoVersion=2.3.3.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Syswatch Admin Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; \
    Description: "Create a desktop shortcut"; \
    GroupDescription: "Additional shortcuts:"; \
    Flags: unchecked

[Files]
; Copy the complete Flutter Windows release folder.
Source: "..\build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; Mandatory Microsoft Visual C++ x64 runtime.
; Compilation stops if this file is missing.
Source: "{#VCRedistFile}"; \
    DestDir: "{tmp}"; \
    Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\Syswatch Admin"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"

Name: "{autodesktop}\Syswatch Admin"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; \
    Tasks: desktopicon

[Run]
; Install or repair the Microsoft Visual C++ runtime first.
Filename: "{tmp}\{#VCRedistFile}"; \
    Parameters: "/install /passive /norestart"; \
    StatusMsg: "Installing Microsoft Visual C++ Runtime..."; \
    Flags: waituntilterminated

; Launch Syswatch Admin after installation.
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch Syswatch Admin"; \
    WorkingDir: "{app}"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

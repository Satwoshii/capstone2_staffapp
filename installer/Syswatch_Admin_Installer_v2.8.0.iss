#define MyAppName "SysWatch Admin"
#define MyAppVersion "2.8.0"
#define MyAppPublisher "NU Clark"
#define VCRedistFile "VC_redist.x64.exe"

; ============================================================
; SYSWATCH ADMIN / ITSO / TEACHER INSTALLER v2.8.0
;
; Current Staff project pubspec:
;   name: syswatch_admin
;   version: 2.8.0+9
;
; Includes support for the Software Inventory screen using:
;   - desktop_drop
;   - file_selector
;   - path_provider
;
; INSTALLER LOCATION:
; Put this file inside:
;   <staff-project>\installer\Syswatch_Admin_Installer_v2.8.0.iss
;
; Example:
;   C:\Users\Christian Fiel\capprog\staff\installer\
;
; The Flutter project root must be ONE folder above this file.
;
; IMPORTANT:
; This installer rebuilds the Windows Release version before
; packaging and copies the COMPLETE Flutter Release folder.
; Do NOT package only the .exe.
; ============================================================

#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"
#define VCRedistPath AddBackslash(SourcePath) + VCRedistFile

; ------------------------------------------------------------
; PROJECT VALIDATION
; ------------------------------------------------------------

#if !FileExists(AddBackslash(ProjectRoot) + "pubspec.yaml")
  #error "pubspec.yaml was not found. Put this ISS file inside the Staff project's installer folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\main.dart")
  #error "lib\main.dart was not found."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "windows\CMakeLists.txt")
  #error "Windows project files were not found. Run: flutter create --platforms=windows ."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\inventory_software_screen.dart")
  #error "inventory_software_screen.dart was not found. Copy the current Software Inventory screen first."
#endif

; ------------------------------------------------------------
; LOCATE FLUTTER
; ------------------------------------------------------------

; This is the Flutter path currently used by the project.
#if FileExists("C:\flutter\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\flutter\src\flutter\bin\flutter.bat"
#elif FileExists("C:\Flutter\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\Flutter\src\flutter\bin\flutter.bat"
#elif FileExists("C:\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\src\flutter\bin\flutter.bat"
#else
  #define FlutterExe "flutter.bat"
#endif

; ------------------------------------------------------------
; CLEAN + GET DEPENDENCIES + BUILD RELEASE
; ------------------------------------------------------------

#define FlutterCleanResult Exec(FlutterExe, "clean", ProjectRoot, 1, 1)
#if FlutterCleanResult != 0
  #error "flutter clean failed. Confirm Flutter is installed and available."
#endif

#define FlutterPubGetResult Exec(FlutterExe, "pub get", ProjectRoot, 1, 1)
#if FlutterPubGetResult != 0
  #error "flutter pub get failed. Check pubspec.yaml dependencies including desktop_drop and file_selector."
#endif

#define FlutterBuildResult Exec(FlutterExe, "build windows --release", ProjectRoot, 1, 1)
#if FlutterBuildResult != 0
  #error "Flutter Windows release build failed. Fix Flutter compile errors before creating the installer."
#endif

; ------------------------------------------------------------
; DETECT EXECUTABLE
; ------------------------------------------------------------

; Current Syswatch Windows CMake BINARY_NAME.
#if FileExists(AddBackslash(ReleaseDir) + "itsoadminappcapstone.exe")
  #define MyAppExeName "itsoadminappcapstone.exe"
#elif FileExists(AddBackslash(ReleaseDir) + "syswatch_admin.exe")
  #define MyAppExeName "syswatch_admin.exe"
#elif FileExists(AddBackslash(ReleaseDir) + "capstone2_staffapp.exe")
  #define MyAppExeName "capstone2_staffapp.exe"
#elif FileExists(AddBackslash(ReleaseDir) + "SysWatch Admin.exe")
  #define MyAppExeName "SysWatch Admin.exe"
#else
  #error "SysWatch Admin executable was not created. Check BINARY_NAME in windows\CMakeLists.txt."
#endif

; ------------------------------------------------------------
; BLANK / GRAY SCREEN SAFETY CHECKS
; ------------------------------------------------------------

#if !FileExists(AddBackslash(ReleaseDir) + "flutter_windows.dll")
  #error "flutter_windows.dll is missing. Build the COMPLETE Flutter Windows Release bundle."
#endif

#if !DirExists(AddBackslash(ReleaseDir) + "data\flutter_assets")
  #error "data\flutter_assets is missing. Do NOT package only the EXE."
#endif

; ------------------------------------------------------------
; SETUP
; ------------------------------------------------------------

[Setup]
; Keep this AppId unchanged so this installer upgrades previous
; Syswatch Admin/Staff installations instead of installing separately.
AppId={{6D1DC2E3-8952-4B61-8FE6-C1A5C32A7778}

AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\Syswatch Admin
DefaultGroupName=Syswatch Admin
DisableProgramGroupPage=yes
AllowNoIcons=yes

OutputDir=output
OutputBaseFilename=Syswatch_Admin_Setup_v{#MyAppVersion}

; Prefer the Flutter Windows icon. Fall back to the app asset icon.
#if FileExists(AddBackslash(ProjectRoot) + "windows\runner\resources\app_icon.ico")
SetupIconFile={#ProjectRoot}\windows\runner\resources\app_icon.ico
#elif FileExists(AddBackslash(ProjectRoot) + "assets\logo\syswatch_logo.ico")
SetupIconFile={#ProjectRoot}\assets\logo\syswatch_logo.ico
#endif

UninstallDisplayIcon={app}\{#MyAppExeName}

Compression=lzma2
SolidCompression=yes
WizardStyle=modern

PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}
RestartApplications=no
RestartIfNeededByRun=no
SetupLogging=yes
UsePreviousAppDir=yes

VersionInfoVersion=2.8.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=SysWatch Admin, ITSO and Teacher Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; \
    Description: "Create a desktop shortcut"; \
    GroupDescription: "Additional shortcuts:"; \
    Flags: unchecked

; ------------------------------------------------------------
; CLEAN OLD DEPLOYED ASSETS DURING UPGRADE
; ------------------------------------------------------------

[InstallDelete]
; Avoid stale Flutter assets/plugin files from an older installation.
Type: filesandordirs; Name: "{app}\data"

; ------------------------------------------------------------
; FILES
; ------------------------------------------------------------

[Files]
; CRITICAL:
; Package the ENTIRE Flutter Release directory.
;
; This includes:
; - itsoadminappcapstone.exe
; - flutter_windows.dll
; - desktop_drop plugin files
; - file_selector plugin files
; - other plugin DLLs
; - data\flutter_assets
; - ICU data
;
Source: "{#ReleaseDir}\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; Optional Microsoft Visual C++ 2015-2022 x64 Runtime.
; Put VC_redist.x64.exe beside this ISS file if you want it bundled.
#if FileExists(VCRedistPath)
Source: "{#VCRedistPath}"; \
    DestDir: "{tmp}"; \
    Flags: deleteafterinstall
#endif

; ------------------------------------------------------------
; SHORTCUTS
; ------------------------------------------------------------

[Icons]
Name: "{autoprograms}\Syswatch Admin"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"

Name: "{autodesktop}\Syswatch Admin"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; \
    Tasks: desktopicon

; ------------------------------------------------------------
; RUN
; ------------------------------------------------------------

[Run]
#if FileExists(VCRedistPath)
Filename: "{tmp}\{#VCRedistFile}"; \
    Parameters: "/install /passive /norestart"; \
    StatusMsg: "Installing Microsoft Visual C++ Runtime..."; \
    Flags: waituntilterminated
#endif

; Setup runs elevated. Start Syswatch using the actual logged-in
; Windows user after installation.
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch SysWatch Admin"; \
    WorkingDir: "{app}"; \
    Flags: postinstall nowait skipifsilent runasoriginaluser

; ------------------------------------------------------------
; UNINSTALL
; ------------------------------------------------------------

[UninstallRun]
Filename: "{cmd}"; \
    Parameters: "/C taskkill /F /IM ""{#MyAppExeName}"""; \
    Flags: runhidden; \
    RunOnceId: "StopSyswatchAdmin"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

#define MyAppName "SysWatch Admin"
#define MyAppVersion "2.7.4"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "itsoadminappcapstone.exe"
#define VCRedistFile "VC_redist.x64.exe"

; ============================================================
; SYSWATCH ADMIN / ITSO / TEACHER INSTALLER v2.10.6
; Current Staff build: secure server-address validation,
; automatic server discovery, Teacher role, status reports,
; repairs, maintenance, audit log, reports, ITSO Support,
; Teacher Chat, rooms/accounts, and NO export feature.
;
; Put this file inside:
;   <staff-project>\installer\Syswatch_Admin_Installer_v2.10.6.iss
;
; The Flutter project root must be ONE folder above this file.
; Optional: place VC_redist.x64.exe beside this .iss file.
; ============================================================

#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"
#define VCRedistPath AddBackslash(SourcePath) + VCRedistFile

#if !FileExists(AddBackslash(ProjectRoot) + "pubspec.yaml")
  #error "pubspec.yaml was not found. Put this ISS file inside the Staff project's installer folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "windows\CMakeLists.txt")
  #error "Windows project files were not found. Run: flutter create --platforms=windows ."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\main.dart")
  #error "lib\main.dart was not found. Copy the uploaded Staff lib into the project first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\staff_login_screen.dart")
  #error "staff_login_screen.dart was not found. Copy the current Staff files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\staff_dashboard_screen.dart")
  #error "staff_dashboard_screen.dart was not found. Copy the current Staff files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\teacher_dashboard_screen.dart")
  #error "teacher_dashboard_screen.dart was not found. Copy the Teacher-role files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\repair_management_screen.dart")
  #error "repair_management_screen.dart was not found. Copy the repair workflow files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\lab_maintenance_overview_screen.dart")
  #error "lab_maintenance_overview_screen.dart was not found. Copy the Maintenance files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\preventive_maintenance_screen.dart")
  #error "preventive_maintenance_screen.dart was not found. Copy the Preventive Maintenance files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\last_known_user_screen.dart")
  #error "last_known_user_screen.dart was not found. Copy the Audit Log files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\reports_screen.dart")
  #error "reports_screen.dart was not found. Copy the Reports files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\support_chat_screen.dart")
  #error "support_chat_screen.dart was not found. Copy the ITSO Support files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\teacher_chat_screen.dart")
  #error "teacher_chat_screen.dart was not found. Copy the Teacher Chat files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\admin_teacher_chat_screen.dart")
  #error "admin_teacher_chat_screen.dart was not found. Copy the Admin Teacher Chat files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\room_management_screen.dart")
  #error "room_management_screen.dart was not found. Copy the Rooms files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\account_management_screen.dart")
  #error "account_management_screen.dart was not found. Copy the Accounts files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\services\staff_service.dart")
  #error "staff_service.dart was not found. Copy the Staff service files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\services\server_discovery_service.dart")
  #error "server_discovery_service.dart was not found. Copy the automatic-server files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\services\app_config_service.dart")
  #error "app_config_service.dart was not found. Copy the secure server configuration files first."
#endif

; Export was intentionally removed from the current Staff build.
#if FileExists(AddBackslash(ProjectRoot) + "lib\services\export_service.dart")
  #error "export_service.dart is present, but the current Staff build is the NO-EXPORT version. Remove the old export_service.dart before packaging."
#endif

; Locate Flutter.
#if FileExists("C:\Flutter\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\Flutter\src\flutter\bin\flutter.bat"
#elif FileExists("C:\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\src\flutter\bin\flutter.bat"
#else
  #define FlutterExe "flutter.bat"
#endif

; Always rebuild before packaging so an old Release folder is never installed.
#define FlutterCleanResult Exec(FlutterExe, "clean", ProjectRoot, 1, 1)
#if FlutterCleanResult != 0
  #error "flutter clean failed. Confirm Flutter is installed and available in PATH."
#endif

#define FlutterPubGetResult Exec(FlutterExe, "pub get", ProjectRoot, 1, 1)
#if FlutterPubGetResult != 0
  #error "flutter pub get failed. Fix the dependency error and compile again."
#endif

#define FlutterBuildResult Exec(FlutterExe, "build windows --release", ProjectRoot, 1, 1)
#if FlutterBuildResult != 0
  #error "Flutter Windows release build failed. Install Visual Studio Desktop development with C++."
#endif

#if !FileExists(AddBackslash(ReleaseDir) + MyAppExeName)
  #error "itsoadminappcapstone.exe was not created. Check BINARY_NAME in windows\CMakeLists.txt."
#endif

[Setup]
; Keep this AppId unchanged so future installers upgrade the same Admin app.
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

#if FileExists(AddBackslash(ProjectRoot) + "windows\runner\resources\app_icon.ico")
SetupIconFile={#ProjectRoot}\windows\runner\resources\app_icon.ico
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
VersionInfoVersion=2.10.6.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Syswatch Admin, ITSO and Teacher Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
; Flutter Windows apps require the complete Release directory, not only the EXE.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

#if FileExists(VCRedistPath)
Source: "{#VCRedistPath}"; DestDir: "{tmp}"; Flags: deleteafterinstall
#endif

[Icons]
Name: "{autoprograms}\Syswatch Admin"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Syswatch Admin"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
#if FileExists(VCRedistPath)
Filename: "{tmp}\{#VCRedistFile}"; Parameters: "/install /passive /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Flags: waituntilterminated
#endif
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Syswatch Admin"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM {#MyAppExeName}"; Flags: runhidden; RunOnceId: "StopSyswatchAdmin"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

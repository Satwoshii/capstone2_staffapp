#define MyAppName "SysWatch Admin"
#define MyAppVersion "2.8.0"
#define MyAppPublisher "NU Clark"
#define VCRedistFile "VC_redist.x64.exe"

; ============================================================
; SYSWATCH ADMIN / ITSO / TEACHER INSTALLER
; Current app version: 2.8.0+9
;
; Put this file inside:
;   <staff-project>\installer\Syswatch_Admin_Installer_v2.8.0.iss
;
; Example:
;   C:\Users\Christian Fiel\capprog\staff\installer\
;
; The Flutter project root must be ONE folder above this file.
;
; IMPORTANT:
; The installer builds and packages the COMPLETE Flutter
; Windows Release folder to avoid blank/gray-screen issues.
; ============================================================

#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"
#define VCRedistPath AddBackslash(SourcePath) + VCRedistFile

; ------------------------------------------------------------
; PROJECT CHECKS
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

; ------------------------------------------------------------
; LOCATE FLUTTER
; ------------------------------------------------------------

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
; CLEAN / DEPENDENCIES / BUILD
; ------------------------------------------------------------

#define FlutterCleanResult Exec(FlutterExe, "clean", ProjectRoot, 1, 1)
#if FlutterCleanResult != 0
  #error "flutter clean failed. Confirm Flutter is installed and available."
#endif

#define FlutterPubGetResult Exec(FlutterExe, "pub get", ProjectRoot, 1, 1)
#if FlutterPubGetResult != 0
  #error "flutter pub get failed. Fix pubspec.yaml/dependency errors first."
#endif

#define FlutterBuildResult Exec(FlutterExe, "build windows --release", ProjectRoot, 1, 1)
#if FlutterBuildResult != 0
  #error "Flutter Windows release build failed. Fix compile errors before creating the installer."
#endif

; ------------------------------------------------------------
; DETECT CURRENT EXE
; ------------------------------------------------------------

#if FileExists(AddBackslash(ReleaseDir) + "itsoadminappcapstone.exe")
  #define MyAppExeName "itsoadminappcapstone.exe"
#elif FileExists(AddBackslash(ReleaseDir) + "syswatch_admin.exe")
  #define MyAppExeName "syswatch_admin.exe"
#elif FileExists(AddBackslash(ReleaseDir) + "capstone2_staffapp.exe")
  #define MyAppExeName "capstone2_staffapp.exe"
#elif FileExists(AddBackslash(ReleaseDir) + "SysWatch Admin.exe")
  #define MyAppExeName "SysWatch Admin.exe"
#else
  #error "SysWatch Admin executable was not found. Check BINARY_NAME in windows\CMakeLists.txt."
#endif

; ------------------------------------------------------------
; FLUTTER DEPLOYMENT SAFETY CHECKS
; ------------------------------------------------------------

#if !FileExists(AddBackslash(ReleaseDir) + "flutter_windows.dll")
  #error "flutter_windows.dll is missing. Do not package only the EXE."
#endif

#if !DirExists(AddBackslash(ReleaseDir) + "data\flutter_assets")
  #error "data\flutter_assets is missing. Build the complete Flutter Windows release."
#endif

[Setup]
; Keep the same AppId so newer installers upgrade the existing install.
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
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[InstallDelete]
; Remove stale Flutter assets from a previous app version.
Type: filesandordirs; Name: "{app}\data"

[Files]
; CRITICAL: package the ENTIRE Flutter Windows Release folder.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Optional Microsoft Visual C++ 2015-2022 x64 runtime.
; Put VC_redist.x64.exe beside this .iss file to bundle it.
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

; Launch under the logged-in Windows account instead of the elevated installer account.
Filename: "{app}\{#MyAppExeName}"; Description: "Launch SysWatch Admin"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM ""{#MyAppExeName}"""; Flags: runhidden; RunOnceId: "StopSyswatchAdmin"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

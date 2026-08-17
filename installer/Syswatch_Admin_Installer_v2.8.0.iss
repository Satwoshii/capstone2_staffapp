#define MyAppName "SysWatch Admin"
#define MyAppVersion "2.6.2"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "itsoadminappcapstone.exe"
#define VCRedistFile "VC_redist.x64.exe"

; Save this file inside the Admin Flutter project's installer folder:
;   capstone2_staffapp-master\installer\Syswatch_Admin_Installer_v2.8.0.iss

#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"
#define VCRedistPath AddBackslash(SourcePath) + VCRedistFile

#if !FileExists(AddBackslash(ProjectRoot) + "pubspec.yaml")
  #error "pubspec.yaml was not found. Put this ISS file inside the Admin project's installer folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "windows\CMakeLists.txt")
  #error "The Windows project files were not found. Run 'flutter create --platforms=windows .' first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\staff_login_screen.dart")
  #error "The Syswatch Staff/Admin login screen was not found."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\teacher_dashboard_screen.dart")
  #error "The v2.8.0 Teacher dashboard was not found. Copy the latest edited Admin files first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\lab_maintenance_overview_screen.dart")
  #error "The v2.8.0 per-lab maintenance screen was not found."
#endif

#if FileExists("C:\Flutter\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\Flutter\src\flutter\bin\flutter.bat"
#elif FileExists("C:\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\src\flutter\bin\flutter.bat"
#else
  #define FlutterExe "flutter.bat"
#endif

; Always rebuild so the installer never packages an old Release folder.
#define FlutterCleanResult Exec(FlutterExe, "clean", ProjectRoot, 1, 1)
#if FlutterCleanResult != 0
  #error "flutter clean failed. Confirm Flutter is installed and available in PATH."
#endif

#define FlutterPubGetResult Exec(FlutterExe, "pub get", ProjectRoot, 1, 1)
#if FlutterPubGetResult != 0
  #error "flutter pub get failed. Fix the dependency error, then compile again."
#endif

#define FlutterBuildResult Exec(FlutterExe, "build windows --release", ProjectRoot, 1, 1)
#if FlutterBuildResult != 0
  #error "Flutter Windows release build failed. Install Visual Studio Desktop development with C++."
#endif

#if !FileExists(AddBackslash(ReleaseDir) + MyAppExeName)
  #error "itsoadminappcapstone.exe was not created. Check BINARY_NAME in windows\CMakeLists.txt."
#endif

[Setup]
; Keep this AppId unchanged so this installer upgrades earlier Admin versions.
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
SetupIconFile={#ProjectRoot}\windows\runner\resources\app_icon.ico
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
VersionInfoDescription=Syswatch Admin and Teacher Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Optional: place VC_redist.x64.exe beside this ISS file to bundle it.
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

[UninstallDelete]
; Preserve user-profile configuration and logs.
Type: filesandordirs; Name: "{app}"

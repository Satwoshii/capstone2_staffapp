#define MyAppName "Syswatch Admin"
#define MyAppVersion "2.6.1"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "itsoadminappcapstone.exe."
#define VCRedistFile "VC_redist.x64.exe"

; Keep this script in the Flutter project's installer folder.
#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"

; Confirm that this is the current Syswatch Staff/Admin project.
#if !FileExists(AddBackslash(ProjectRoot) + "pubspec.yaml")
  #error "pubspec.yaml was not found. Put this .iss file inside the project's installer folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\staff_login_screen.dart")
  #error "The Syswatch Staff login source was not found. Check the project folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\preventive_maintenance_screen.dart")
  #error "The Syswatch v2.6.0 maintenance screen was not found. Use the latest Staff project."
#endif

#if !FileExists(AddBackslash(SourcePath) + VCRedistFile)
  #error "VC_redist.x64.exe was not found beside this .iss file."
#endif

; Use the Flutter installation normally used on the Syswatch development PC.
; If Flutter is installed elsewhere, flutter.bat must be available in PATH.
#if FileExists("C:\Flutter\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\Flutter\src\flutter\bin\flutter.bat"
#elif FileExists("C:\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\src\flutter\bin\flutter.bat"
#else
  #define FlutterExe "flutter.bat"
#endif

; Always rebuild the current Staff App before packaging it.
; This prevents Inno Setup from reusing an older Release folder.
#define FlutterCleanExitCode Exec(FlutterExe, "clean", ProjectRoot, 1, 1)
#if FlutterCleanExitCode != 0
  #error "flutter clean failed. Check the Flutter SDK path and try again."
#endif

#define FlutterPackagesExitCode Exec(FlutterExe, "pub get", ProjectRoot, 1, 1)
#if FlutterPackagesExitCode != 0
  #error "flutter pub get failed. Fix the dependency error and try again."
#endif

#define FlutterBuildExitCode Exec(FlutterExe, "build windows --release", ProjectRoot, 1, 1)
#if FlutterBuildExitCode != 0
  #error "Flutter Windows release build failed. Fix the build error and try again."
#endif

#if !FileExists(AddBackslash(ReleaseDir) + MyAppExeName)
  #error "The release build did not create build\windows\x64\runner\Release\itsoadminappcapstone.exe."
#endif

[Setup]
; Keep this AppId unchanged so v2.6.0 upgrades earlier Syswatch Admin installs.
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

VersionInfoVersion=2.6.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Syswatch Admin Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
; Include the complete fresh Flutter release: EXE, DLLs, plug-ins, and data.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#VCRedistFile}"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\Syswatch Admin"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Syswatch Admin"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\{#VCRedistFile}"; Parameters: "/install /passive /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Syswatch Admin"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent runasoriginaluser

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

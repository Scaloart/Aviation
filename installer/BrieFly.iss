; Inno Setup Script for BrieFly classic installer
#define MyAppName "BrieFly"
#define MyAppVersion "4.0.0"
#define MyAppPublisher "BrieFly"
#define MyAppExeName "BrieFly.exe"  ; built exe name in Release folder
#define SourceDir "..\\build\\windows\\x64\\runner\\Release"
#define IconPath "..\\windows\\runner\\resources\\app_icon.ico"

[Setup]
AppId={{B5F1F2A1-1A6E-45E3-9B66-7F4B1B6F3E21}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={pf}\\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=no
OutputDir=..\\dist\\installer
OutputBaseFilename=BrieFly_Setup_{#MyAppVersion}
SetupIconFile={#IconPath}
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\\{#MyAppExeName}
PrivilegesRequired=admin
WizardStyle=modern
LicenseFile=LICENSE.txt
; Ensure running app is closed during upgrade so files can be replaced
CloseApplications=yes
CloseApplicationsFilter=BrieFly.exe

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Explicit critical payload files (fail build if missing)
Source: "{#SourceDir}\\sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\\data\\flutter_assets\\assets\\airports.db"; DestDir: "{app}\\data\\flutter_assets\\assets"; Flags: ignoreversion
; Embed prereq installers as support files and run from {tmp}
Source: "VC_redist.x64.exe"; Flags: dontcopy
Source: "MicrosoftEdgeWebView2RuntimeInstallerX64.exe"; Flags: dontcopy

[Icons]
Name: "{group}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"
Name: "{commondesktop}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Always run VC++ Redistributable with visible UI
Filename: "{tmp}\\VC_redist.x64.exe"; Flags: waituntilterminated; StatusMsg: "Installing Microsoft Visual C++ Redistributable..."
; Always run WebView2 Evergreen Runtime with visible UI
Filename: "{tmp}\\MicrosoftEdgeWebView2RuntimeInstallerX64.exe"; Flags: waituntilterminated; StatusMsg: "Installing Microsoft Edge WebView2 Runtime..."
Filename: "{app}\\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\\*"

; No [Code] detection needed when always running installers

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    // Ensure support files are extracted to temp before run
    ExtractTemporaryFile('VC_redist.x64.exe');
    ExtractTemporaryFile('MicrosoftEdgeWebView2RuntimeInstallerX64.exe');
  end;
end;

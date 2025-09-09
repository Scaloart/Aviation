; Inno Setup Script for Briefly - Test Installer
; Requires Inno Setup 6 (https://jrsoftware.org/isinfo.php)
; Build your Flutter Windows release first: flutter build windows --release

#define MyAppName "BrieFly"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "BrieFly"
#define MyAppExeName "BrieFly.exe"

[Setup]
AppId={{8E0B6CBC-0A2D-4D15-A7A4-5E6B2B5E5B6C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=yes
Compression=lzma2
SolidCompression=yes
OutputDir=dist
OutputBaseFilename=BrieFly_Setup
WizardStyle=modern
; Use recommended identifiers; x64compatible covers WOW64 and native x64
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64compatible
; Use the app icon for the installer executable and shortcuts
SetupIconFile=..\..\..\windows\runner\resources\app_icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; Include the compiled Flutter Windows app output
; Ensure this path exists: build\windows\x64\runner\Release
Source: "..\..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

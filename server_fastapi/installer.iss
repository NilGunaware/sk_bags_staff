#ifndef AppVersion
  #error AppVersion must be supplied by the build
#endif
#define AppName "SK Bags Desktop"
#define AppPublisher "SK Bags"
#define AppExeName "SKBagsDesktop.exe"

[Setup]
AppId={{51C03676-1518-43B0-BB91-08325117DD3A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://interlinkpos.com
DefaultDirName={localappdata}\Programs\SK Bags Desktop
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=dist
OutputBaseFilename=SKBagsDesktop-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
VersionInfoVersion={#AppVersion}.0
VersionInfoCompany={#AppPublisher}
VersionInfoDescription=SK Bags Desktop Installer
UninstallDisplayIcon={app}\{#AppExeName}
CloseApplications=yes
RestartApplications=no
SignTool=skauth
SignedUninstaller=yes
SignToolRetryCount=2

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked
Name: "startupicon"; Description: "Start SK Bags Desktop when you sign in to Windows"; Flags: unchecked

[Files]
Source: "dist\SKBagsDesktop-{#AppVersion}.exe"; DestDir: "{app}"; DestName: "{#AppExeName}"; Flags: ignoreversion
Source: "dist\SKBagsDesktop-Certificate.cer"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\SIGNING.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: startupicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

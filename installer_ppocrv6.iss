#define MyAppName "Selector-app"
#define MyAppVersion "2.1-PP-OCRv6"
#define MyAppPublisher "Szabolcs Balint"
#define MyAppExeName "pythonw.exe"

[Setup]
AppId={{D7B7C8A3-1DF6-4A26-8C72-8E1EC7A02002}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
SetupIconFile=Selector-app.ico
UninstallDisplayIcon={app}\Selector-app.ico
OutputDir=installer_output
OutputBaseFilename=Selector-app-Setup-PP-OCRv6
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Tasks]
Name: "desktopicon"; Description: "Asztali ikon létrehozása"; GroupDescription: "Parancsikonok:"; Flags: unchecked

[Files]
Source: "Selector-app.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "Selector-app.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "install_online.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "requirements.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "README_PP-OCRv6.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\venv\Scripts\{#MyAppExeName}"; Parameters: """{app}\Selector-app.py"""; WorkingDir: "{app}"; IconFilename: "{app}\Selector-app.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\venv\Scripts\{#MyAppExeName}"; Parameters: """{app}\Selector-app.py"""; WorkingDir: "{app}"; IconFilename: "{app}\Selector-app.ico"; Tasks: desktopicon

[UninstallDelete]
Type: filesandordirs; Name: "{app}\python"
Type: filesandordirs; Name: "{app}\venv"
Type: filesandordirs; Name: "{app}\models"
Type: filesandordirs; Name: "{app}\poppler"

[Run]
Filename: "{app}\venv\Scripts\pythonw.exe"; Parameters: """{app}\Selector-app.py"""; WorkingDir: "{app}"; Description: "Selector-app indítása"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  PowerShellPath: String;
  Parameters: String;
begin
  if CurStep = ssPostInstall then
  begin
    PowerShellPath := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
    Parameters :=
      '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' +
      ExpandConstant('{app}\install_online.ps1') +
      '" -InstallDir "' + ExpandConstant('{app}') + '"';
    if not Exec(PowerShellPath, Parameters, ExpandConstant('{app}'),
      SW_SHOW, ewWaitUntilTerminated, ResultCode) then
      RaiseException('A függőségek telepítője nem indítható el.');
    if ResultCode <> 0 then
      RaiseException(Format('A függőségek telepítése hibával leállt (kód: %d).'#13#10#13#10 +
        'A részletes hibaüzenet itt található:'#13#10'%s', [ResultCode, ExpandConstant('{app}\install_log.txt')]));
  end;
end;

; Installateur Windows de StudioVoix (Inno Setup 6.3 ou plus récent).
; Compilé par la CI : iscc /DAppVersion=x.y.z /DBuildDir=<dossier build> /DStagingDir=<docs HTML> StudioVoix.iss

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build"
#endif
#ifndef StagingDir
  #define StagingDir "..\..\build\installer-staging"
#endif

[Setup]
AppId={{8E2B5D2C-4E0F-4B7A-9C1E-5A7D3F1B2C64}
AppName=StudioVoix
AppVersion={#AppVersion}
AppPublisher=StudioVoix
DefaultDirName={autopf}\StudioVoix
DefaultGroupName=StudioVoix
DisableProgramGroupPage=yes
OutputDir={#BuildDir}\installer
OutputBaseFilename=StudioVoix-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
; Installation sans droits administrateur par défaut (dossier utilisateur), "pour tous" au choix.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\StudioVoix.exe
UninstallDisplayName=StudioVoix

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\StudioVoix_artefacts\Release\StudioVoix.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\studiovoix_cli_artefacts\Release\studiovoix_cli.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StagingDir}\LISEZMOI.html"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StagingDir}\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\StudioVoix\StudioVoix"; Filename: "{app}\StudioVoix.exe"
Name: "{autoprograms}\StudioVoix\Guide du matériel"; Filename: "{app}\docs\GUIDE_MATERIEL.html"
Name: "{autoprograms}\StudioVoix\Lisez-moi"; Filename: "{app}\LISEZMOI.html"
Name: "{autoprograms}\StudioVoix\Désinstaller StudioVoix"; Filename: "{uninstallexe}"
Name: "{autodesktop}\StudioVoix"; Filename: "{app}\StudioVoix.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\docs\GUIDE_MATERIEL.html"; Description: "Ouvrir le guide du matériel (micro, casque, branchements)"; Flags: postinstall shellexec skipifsilent nowait
Filename: "{app}\StudioVoix.exe"; Description: "{cm:LaunchProgram,StudioVoix}"; Flags: postinstall skipifsilent nowait unchecked runasoriginaluser
; Mise à jour depuis le programme (/RELANCER=1) : relance automatique après l'installation silencieuse.
Filename: "{app}\StudioVoix.exe"; Flags: nowait runasoriginaluser; Check: RelancerApresMiseAJour

[Code]
// Mise à jour lancée par StudioVoix : le programme se ferme juste après avoir lancé l'installateur.
// On attend que son verrou nommé (InterProcessLock JUCE « StudioVoix_en_cours ») disparaisse, 30 s au plus.
function RelancerApresMiseAJour: Boolean;
begin
  Result := ExpandConstant('{param:RELANCER|0}') = '1';
end;

function InitializeSetup: Boolean;
var
  Attente: Integer;
begin
  Result := True;
  if RelancerApresMiseAJour then
  begin
    Attente := 0;
    while CheckForMutexes('Global\StudioVoix_en_cours,Local\StudioVoix_en_cours') and (Attente < 60) do
    begin
      Sleep(500);
      Attente := Attente + 1;
    end;
    Log(Format('Mise à jour : attente de la fermeture de StudioVoix %d x 500 ms', [Attente]));
  end;
end;

// Les projets (Documents\StudioVoix), réglages et journaux (%APPDATA%\StudioVoix) ne sont jamais supprimés.

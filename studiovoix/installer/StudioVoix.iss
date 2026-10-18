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
; Édition : "classique" (StudioVoix) ou "IA" (StudioVoix IA) — nom, dossier, identifiant et verrou distincts,
; les deux programmes peuvent être installés côte à côte.
#ifndef Edition
  #define Edition "classique"
#endif
#if Edition == "IA"
  #define AppNameStr "StudioVoix IA"
  #define ExeName "StudioVoixIA"
  #define AppIdStr "{{3C1F7A2E-9B6D-4F0A-8E21-7D5C2B9A4E11}"
  #define DirName "StudioVoix IA"
  #define MutexName "StudioVoixIA_en_cours"
#else
  #define AppNameStr "StudioVoix"
  #define ExeName "StudioVoix"
  #define AppIdStr "{{8E2B5D2C-4E0F-4B7A-9C1E-5A7D3F1B2C64}"
  #define DirName "StudioVoix"
  #define MutexName "StudioVoix_en_cours"
#endif

[Setup]
AppId={#AppIdStr}
AppName={#AppNameStr}
AppVersion={#AppVersion}
AppPublisher=StudioVoix
DefaultDirName={autopf}\{#DirName}
DefaultGroupName={#AppNameStr}
DisableProgramGroupPage=yes
OutputDir={#BuildDir}\installer
OutputBaseFilename={#ExeName}-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
; Installation sans droits administrateur par défaut (dossier utilisateur), "pour tous" au choix.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#ExeName}.exe
UninstallDisplayName={#AppNameStr}

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\StudioVoix_artefacts\Release\{#ExeName}.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\studiovoix_cli_artefacts\Release\studiovoix_cli.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StagingDir}\LISEZMOI.html"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StagingDir}\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppNameStr}\{#AppNameStr}"; Filename: "{app}\{#ExeName}.exe"
Name: "{autoprograms}\{#AppNameStr}\Guide du matériel"; Filename: "{app}\docs\GUIDE_MATERIEL.html"
Name: "{autoprograms}\{#AppNameStr}\Lisez-moi"; Filename: "{app}\LISEZMOI.html"
Name: "{autoprograms}\{#AppNameStr}\Désinstaller {#AppNameStr}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppNameStr}"; Filename: "{app}\{#ExeName}.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\docs\GUIDE_MATERIEL.html"; Description: "Ouvrir le guide du matériel (micro, casque, branchements)"; Flags: postinstall shellexec skipifsilent nowait
Filename: "{app}\{#ExeName}.exe"; Description: "{cm:LaunchProgram,{#AppNameStr}}"; Flags: postinstall skipifsilent nowait unchecked runasoriginaluser
; Mise à jour depuis le programme (/RELANCER=1) : relance automatique après l'installation silencieuse.
Filename: "{app}\{#ExeName}.exe"; Flags: nowait runasoriginaluser; Check: RelancerApresMiseAJour

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
    while CheckForMutexes('Global\{#MutexName},Local\{#MutexName}') and (Attente < 60) do
    begin
      Sleep(500);
      Attente := Attente + 1;
    end;
    Log(Format('Mise à jour : attente de la fermeture de StudioVoix %d x 500 ms', [Attente]));
  end;
end;

// Les projets (Documents\StudioVoix), réglages et journaux (%APPDATA%\StudioVoix) ne sont jamais supprimés.

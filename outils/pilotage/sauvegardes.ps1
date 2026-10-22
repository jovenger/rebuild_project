# Les sauvegardes du jeu et « Continuer ». Mesuré le 15/10/2026 (V59) : « Continuer » reprend la sauvegarde dont l'heure
# écrite dans son en-tête (C_SaveGameDescription, attribut SaveTime, secondes depuis 1970) est la plus récente, toutes
# parties confondues ; ni la date du fichier ni la dernière partie chargée ne comptent.
# Décision de JoVenGer (15/10/2026, question à cocher) : à chaque fin d'essai, les sauvegardes d'essai plus récentes que
# sa partie sont rangées à part (déplacées, jamais supprimées), pour que « Continuer » reprenne sa partie.
# S'emploie par « . outils\pilotage\sauvegardes.ps1 ». Lecture seule, sauf Ranger-Les-Essais, qui ne déplace que des
# sauvegardes des parties d'essai (playline2, playline3, playline4), jamais de playline0 ni de playline1.
$script:Sauvegardes = "$env:USERPROFILE\Saved Games\kingdomcome2\saves"
$script:Rangement = "$env:USERPROFILE\Saved Games\kingdomcome2\essais_du_socle_rangees"
# 18/10/2026 : playline4, la partie neuve d'essai (Partie 5), créée pour l'essai des dialogues sur une partie neuve.
# 19/10/2026 : playline9, la copie de la partie de JoVenGer (autosave1910) pour la répétition de la bascule (son accord direct).
$script:LignesDEssai = @("playline2", "playline3", "playline4", "playline9")

# L'heure de l'en-tête d'une sauvegarde (secondes), ou $null si l'en-tête est illisible.
function Heure-De-Sauvegarde([string]$chemin) {
  $flux = [IO.File]::OpenRead($chemin)
  try { $tampon = New-Object byte[] 4096; $lus = $flux.Read($tampon, 0, 4096) } finally { $flux.Close() }
  $m = [regex]::Match([Text.Encoding]::ASCII.GetString($tampon, 0, $lus), 'SaveTime="(\d+)"')
  if (-not $m.Success) { return $null }
  return [int64]$m.Groups[1].Value
}

function Date-De-Sauvegarde($heure) {
  if ($null -eq $heure) { return "?" }
  return [DateTimeOffset]::FromUnixTimeSeconds($heure).LocalDateTime.ToString("dd/MM/yyyy HH:mm:ss")
}

function Toutes-Les-Sauvegardes {
  Get-ChildItem $script:Sauvegardes -Directory -Filter "playline*" | ForEach-Object {
    $ligne = $_.Name
    Get-ChildItem $_.FullName -File -Filter *.whs | ForEach-Object {
      [pscustomobject]@{ Ligne = $ligne; Nom = $_.Name; Chemin = $_.FullName; Heure = (Heure-De-Sauvegarde $_.FullName) }
    }
  }
}

# La sauvegarde que « Continuer » reprendra (la plus récente par l'en-tête).
function Sauvegarde-De-Continuer {
  Toutes-Les-Sauvegardes | Where-Object { $null -ne $_.Heure } | Sort-Object Heure -Descending | Select-Object -First 1
}

# Range à part les sauvegardes d'essai plus récentes que la plus récente des parties de JoVenGer. Rend des lignes.
# Vu le 15/10 (V59) : rangées jeu fermé, le nuage Steam les remet au lancement suivant. -PendantLeJeu les range jeu
# ouvert (au menu, rien de chargé), pour que le nuage enregistre leur départ à la fermeture du jeu.
function Ranger-Les-Essais([switch]$PendantLeJeu) {
  if (-not $PendantLeJeu -and (Get-Process -Name KingdomCome -ErrorAction SilentlyContinue)) { "rangement : le jeu est lancé, rien n'est déplacé"; return }
  $toutes = @(Toutes-Les-Sauvegardes)
  $siennes = @($toutes | Where-Object { $script:LignesDEssai -notcontains $_.Ligne -and $null -ne $_.Heure })
  if ($siennes.Count -eq 0) { "rangement : aucune sauvegarde de JoVenGer lisible, rien n'est déplacé"; return }
  $seuil = ($siennes | Measure-Object -Property Heure -Maximum).Maximum
  foreach ($s in $toutes | Where-Object { $script:LignesDEssai -contains $_.Ligne }) {
    if ($null -eq $s.Heure) { "rangement : en-tête illisible, laissé en place : " + $s.Ligne + "\" + $s.Nom; continue }
    if ($s.Heure -lt $seuil) { continue }
    $dossier = Join-Path $script:Rangement $s.Ligne
    New-Item -ItemType Directory -Force $dossier | Out-Null
    $base = [DateTimeOffset]::FromUnixTimeSeconds($s.Heure).LocalDateTime.ToString("yyyy-MM-dd_HHmmss") + "_" + $s.Nom
    $cible = Join-Path $dossier $base
    $n = 2
    while (Test-Path -LiteralPath $cible) { $cible = Join-Path $dossier ("{0}_{1}" -f $n, $base); $n++ }
    try {
      Move-Item -LiteralPath $s.Chemin -Destination $cible -ErrorAction Stop
      "rangée : " + $s.Ligne + "\" + $s.Nom + " (" + (Date-De-Sauvegarde $s.Heure) + ") -> " + $cible
    } catch {
      "rangement : ÉCHEC pour " + $s.Ligne + "\" + $s.Nom + " : " + $_.Exception.Message
    }
  }
  $c = Sauvegarde-De-Continuer
  $texte = "« Continuer » reprendra : " + $c.Ligne + "\" + $c.Nom + " (" + (Date-De-Sauvegarde $c.Heure) + ")"
  if ($script:LignesDEssai -contains $c.Ligne) { "ATTENTION : " + $texte + ", une partie d'essai" } else { $texte }
}

# Installe le socle, lance le jeu avec -devmode et charge une PARTIE D'ESSAI, où l'on peut sauvegarder : playline2
# (par défaut ; partie neuve, au prologue, temps du jeu arrêté) ou, avec -Ligne playline3, la copie de la sauvegarde 473
# de la Partie 1 (temps qui avance ; créée le 15/10/2026 avec l'accord de JoVenGer).
# Sans -Charger : par « Continuer » ; refuse si la sauvegarde que « Continuer » reprendrait (la plus récente par l'heure
# de son en-tête, mesuré en V59 ; sauvegardes.ps1) n'est pas dans la ligne demandée ; vérifie au journal que c'est bien cette ligne qui se charge, sinon ferme le jeu sans
# sauvegarder ; dit si le chargement a échoué (retour au menu principal).
# Avec -Charger : va seulement jusqu'à la liste « Charger partie » et la capture (securite\captures\charger_partie.png),
# sans rien valider ; la suite se fait à vue, puis confirmer_sauvegarde.ps1 -Attendu "<ligne>/<sauvegarde>".
# À employer seulement pendant une séance d'essai ouverte par debut_essai.ps1, avec l'accord de JoVenGer.
# -SansDevmode : lance le jeu comme JoVenGer joue, sans -devmode.
param([switch]$Charger, [switch]$SansDevmode, [ValidateSet("playline2", "playline3")][string]$Ligne = "playline2")
$racine = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$jeu = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
$journal = Join-Path $jeu "kcd.log"
$sauvegardes = "$env:USERPROFILE\Saved Games\kingdomcome2\saves"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "sauvegardes.ps1")

if (Get-Process -Name KingdomCome -ErrorAction SilentlyContinue) { "le jeu est lancé : le fermer d'abord"; return }
$derniere = Sauvegarde-De-Continuer
if (-not $Charger -and $derniere.Ligne -ne $Ligne) { "« Continuer » reprendrait " + $derniere.Ligne + "\" + $derniere.Nom + " : pas la partie d'essai demandée ; arrêt (prendre -Charger)"; return }
Set-Location $racine
py -3.13 noyau\installer.py --jeu $jeu | Select-Object -Last 1
$t0 = Get-Date
$arguments = @("-applaunch", "1771300"); if (-not $SansDevmode) { $arguments += "-devmode" }
Start-Process -FilePath "C:\Program Files (x86)\Steam\steam.exe" -ArgumentList $arguments
$menu = $false
foreach ($i in 1..150) { Start-Sleep -Seconds 2; if ((Get-Item $journal).LastWriteTime -gt $t0 -and (Select-String -Path $journal -Pattern "PlayVideoOnly 'main_menu" -Quiet)) { $menu = $true; break } }
if (-not $menu) { "menu non atteint : arrêt"; return }
Start-Sleep -Seconds 4
$p = Get-Process -Name KingdomCome; $h = $p.MainWindowHandle
if (-not (Mettre-Le-Jeu-Devant)) { "le jeu ne vient pas au premier plan : rien n'est tapé, arrêt"; return }
if ($Charger) {
  Touche Bas; Touche Bas; Touche Entree; Start-Sleep -Seconds 3
  "liste des parties à regarder : " + (Capture "charger_partie")
  return
}
Touche Entree
$charge = $null
foreach ($i in 1..30) { $charge = Select-String -Path $journal -Pattern "Loading saved game" | Select-Object -Last 1; if ($charge) { break }; Start-Sleep -Seconds 1 }
if (-not $charge -or $charge.Line -notmatch "$Ligne/") { Stop-Process -Id $p.Id -Force; "chargement inattendu : jeu arrêté sans sauvegarde"; return }
if (Attendre-Partie-Chargee $journal) { "partie d'essai chargée (" + $charge.Line.Trim() + ")" }
else { "ÉCHEC du chargement de la partie d'essai (" + $charge.Line.Trim() + ") : le jeu est revenu au menu principal ou ne répond pas" }

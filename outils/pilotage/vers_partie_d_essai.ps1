# Installe le socle, lance le jeu avec -devmode et charge une PARTIE D'ESSAI, où l'on peut sauvegarder : playline2
# (par défaut ; partie neuve, au prologue, temps du jeu arrêté) ou, avec -Ligne playline3, la copie de la sauvegarde 473
# de la Partie 1 (temps qui avance ; créée le 15/10/2026 avec l'accord de JoVenGer).
# Sans -Charger : par « Continuer » ; refuse si la sauvegarde que « Continuer » reprendrait (la plus récente par l'heure
# de son en-tête, mesuré en V59 ; sauvegardes.ps1) n'est pas dans la ligne demandée ; vérifie au journal que c'est bien cette ligne qui se charge, sinon ferme le jeu sans
# sauvegarder ; dit si le chargement a échoué (retour au menu principal).
# Avec -Charger : descend seulement jusqu'à « Charger partie », SANS Entrée, et capture le menu
# (D:\socle_captures\captures\menu_avant_entree.png) ; la suite se fait à vue (Entrée à la main si « Charger partie » est
# bien sélectionné), puis confirmer_sauvegarde.ps1 -Attendu "<ligne>/<sauvegarde>".
# À employer seulement pendant une séance d'essai ouverte par debut_essai.ps1, avec l'accord de JoVenGer.
# -SansDevmode : lance le jeu comme JoVenGer joue, sans -devmode.
param([switch]$Charger, [switch]$SansDevmode, [ValidateSet("playline2", "playline3", "playline9")][string]$Ligne = "playline2")
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
  # Vu le 19/10 (après la bascule) : les deux Bas perdus (menu pas encore prêt), Entrée est tombée sur « Continuer »,
  # qui reprend désormais la partie de JoVenGer (jeu arrêté pendant le chargement, rien d'écrit). Donc plus d'Entrée
  # ici : on s'arrête sur « Charger partie » sélectionné, capture à regarder, puis Entrée à la main. Et si un
  # chargement apparaît quand même au journal, le jeu est arrêté sans sauvegarde.
  Start-Sleep -Seconds 6
  Touche Bas; Start-Sleep -Milliseconds 500; Touche Bas; Start-Sleep -Seconds 1
  $charge = Select-String -Path $journal -Pattern "Loading saved game" | Select-Object -Last 1
  if ($charge) { Stop-Process -Id $p.Id -Force; "chargement inattendu (" + $charge.Line.Trim() + ") : jeu arrêté sans sauvegarde"; return }
  "menu à regarder AVANT Entrée (« Charger partie » doit être sélectionné) : " + (Capture "menu_avant_entree")
  return
}
Touche Entree
$charge = $null
foreach ($i in 1..30) { $charge = Select-String -Path $journal -Pattern "Loading saved game" | Select-Object -Last 1; if ($charge) { break }; Start-Sleep -Seconds 1 }
if (-not $charge -or $charge.Line -notmatch "$Ligne/") { Stop-Process -Id $p.Id -Force; "chargement inattendu : jeu arrêté sans sauvegarde"; return }
if (Attendre-Partie-Chargee $journal) { "partie d'essai chargée (" + $charge.Line.Trim() + ")" }
else { "ÉCHEC du chargement de la partie d'essai (" + $charge.Line.Trim() + ") : le jeu est revenu au menu principal ou ne répond pas" }

# Installe le socle, lance le jeu avec -devmode et charge la PARTIE D'ESSAI (playline2, où l'on peut sauvegarder).
# Sans paramètre : par « Continuer » ; refuse si la sauvegarde la plus récente n'est pas dans playline2 (Continuer
# chargerait une autre partie) ; vérifie au journal que c'est bien playline2 qui se charge, sinon ferme le jeu sans
# sauvegarder ; dit si le chargement a échoué (retour au menu principal).
# Avec -Charger : va seulement jusqu'à la liste « Charger partie » et la capture (securite\captures\charger_partie.png),
# sans rien valider ; la suite se fait à vue, puis confirmer_sauvegarde.ps1 -Attendu "playline2/<sauvegarde>".
# À employer seulement pendant une séance d'essai ouverte par debut_essai.ps1, avec l'accord de JoVenGer.
param([switch]$Charger)
$racine = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$jeu = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
$journal = Join-Path $jeu "kcd.log"
$sauvegardes = "$env:USERPROFILE\Saved Games\kingdomcome2\saves"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")

if (Get-Process -Name KingdomCome -ErrorAction SilentlyContinue) { "le jeu est lancé : le fermer d'abord"; return }
$derniere = Get-ChildItem $sauvegardes -Recurse -File -Filter *.whs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $Charger -and $derniere.Directory.Name -ne "playline2") { "la sauvegarde la plus récente est dans " + $derniere.Directory.Name + " : « Continuer » ne chargerait pas la partie d'essai ; arrêt"; return }
Set-Location $racine
py -3.13 noyau\installer.py --jeu $jeu | Select-Object -Last 1
$t0 = Get-Date
Start-Process -FilePath "C:\Program Files (x86)\Steam\steam.exe" -ArgumentList "-applaunch","1771300","-devmode"
$menu = $false
foreach ($i in 1..150) { Start-Sleep -Seconds 2; if ((Get-Item $journal).LastWriteTime -gt $t0 -and (Select-String -Path $journal -Pattern "PlayVideoOnly 'main_menu" -Quiet)) { $menu = $true; break } }
if (-not $menu) { "menu non atteint : arrêt"; return }
Start-Sleep -Seconds 4
$p = Get-Process -Name KingdomCome; $h = $p.MainWindowHandle
[Cycle.U]::keybd_event(0x12,0,0,[System.UIntPtr]::Zero); [Cycle.U]::keybd_event(0x12,0,2,[System.UIntPtr]::Zero)
[void][Cycle.U]::ShowWindow($h, 9); [void][Cycle.U]::SetForegroundWindow($h); Start-Sleep -Milliseconds 800
if ($Charger) {
  Touche Bas; Touche Bas; Touche Entree; Start-Sleep -Seconds 3
  "liste des parties à regarder : " + (Capture "charger_partie")
  return
}
Touche Entree
$charge = $null
foreach ($i in 1..30) { $charge = Select-String -Path $journal -Pattern "Loading saved game" | Select-Object -Last 1; if ($charge) { break }; Start-Sleep -Seconds 1 }
if (-not $charge -or $charge.Line -notmatch "playline2") { "chargement inattendu : fermeture sans sauvegarde"; [void]$p.CloseMainWindow(); return }
if (Attendre-Partie-Chargee $journal) { "partie d'essai chargée (" + $charge.Line.Trim() + ")" }
else { "ÉCHEC du chargement de la partie d'essai (" + $charge.Line.Trim() + ") : le jeu est revenu au menu principal ou ne répond pas" }

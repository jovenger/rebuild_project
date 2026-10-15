# Ferme le jeu sans sauvegarder, installe le socle, relance avec -devmode, et va jusqu'au choix de la sauvegarde 473 de
# la Partie 1 (Charger partie > Partie 1 > cinquième sauvegarde). S'arrête AVANT de valider : la capture
# securite\captures\choix_473.png est à regarder, puis confirmer_partie1.ps1 valide.
# Refuse si la Partie 1 n'est plus identique à sa copie d'origine (securite\playline0_…\_etat_d_origine.txt).
# À employer seulement pendant une séance d'essai ouverte par debut_essai.ps1, avec l'accord de JoVenGer.
# -SansDevmode : lance le jeu comme JoVenGer joue, sans -devmode, et s'arrête sur la liste « Charger partie ».
param([switch]$SansDevmode)
$racine = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$jeu = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
$journal = Join-Path $jeu "kcd.log"
$etat = Join-Path $racine "securite\playline0_2026-10-14_214438\_etat_d_origine.txt"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")

# Fermeture sans sauvegarde. En partie, la fenêtre se ferme ; au menu principal, le jeu demande « Voulez-vous quitter
# le jeu ? » avec « Non » choisi : Haut puis Entrée répondent « Oui ».
$p = Get-Process -Name KingdomCome -ErrorAction SilentlyContinue
if ($p) {
  [void]$p.CloseMainWindow(); $p.WaitForExit(15000) | Out-Null
  if (-not $p.HasExited) {
    [void][Cycle.U]::SetForegroundWindow($p.MainWindowHandle); Start-Sleep -Milliseconds 800
    if (Jeu-Au-Premier-Plan) { Touche Haut; Touche Entree }
    $p.WaitForExit(30000) | Out-Null
  }
  if (-not $p.HasExited) { "le jeu ne se ferme pas : arrêt"; return }
}
Start-Sleep -Seconds 2
$maintenant = Get-ChildItem "$env:USERPROFILE\Saved Games\kingdomcome2\saves\playline0" -File | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTime.Ticks)" }
if (Compare-Object (Get-Content $etat) $maintenant) { "la Partie 1 a changé depuis sa copie : arrêt"; return }
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
[Cycle.U]::keybd_event(0x12,0,0,[System.UIntPtr]::Zero); [Cycle.U]::keybd_event(0x12,0,2,[System.UIntPtr]::Zero)
[void][Cycle.U]::ShowWindow($h, 9); [void][Cycle.U]::SetForegroundWindow($h); Start-Sleep -Milliseconds 800
Touche Bas; Touche Bas; Touche Entree; Start-Sleep -Seconds 3
# Sans -devmode, le menu du jeu n'est pas le même (vu le 15/10 : le chargement est parti une touche plus tôt) : arrêt sur
# la liste, capturée ; la suite se fait à vue, puis confirmer_sauvegarde.ps1 -Attendu "playline0/autosave473".
if ($SansDevmode) { "liste à regarder (sans -devmode) : " + (Capture "charger_partie_sans_devmode"); return }
Touche Entree; Start-Sleep -Seconds 3
Touche Bas; Touche Bas; Touche Bas; Touche Bas; Start-Sleep -Milliseconds 600
"choix de la sauvegarde à vérifier : " + (Capture "choix_473")

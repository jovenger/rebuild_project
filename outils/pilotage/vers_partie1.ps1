# Ferme le jeu sans sauvegarder, installe le socle, relance avec -devmode et s'arrête au menu principal (capture
# securite\captures\menu_principal.png). Ensuite, à vue : appuyer.ps1 -Touches ... -Attendu "playline0/autosave473".
# Refuse si la Partie 1 n'est plus identique à sa copie d'origine (securite\playline0_…\_etat_d_origine.txt).
# À employer seulement pendant une séance d'essai ouverte par debut_essai.ps1, avec l'accord de JoVenGer.
# -SansDevmode : lance le jeu comme JoVenGer joue, sans -devmode.
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
    if (Mettre-Le-Jeu-Devant) { Touche Haut; Touche Entree; $p.WaitForExit(30000) | Out-Null }
    # Si le jeu ne vient pas devant, aucune touche : il est arrêté, ce qui ne sauvegarde rien.
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; $p.WaitForExit(15000) | Out-Null }
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
if (-not (Mettre-Le-Jeu-Devant)) { "le jeu ne vient pas au premier plan : rien n'est tapé, arrêt"; return }
# Plus aucune touche à l'aveugle dans les menus (vu le 15/10 : une validation a lancé un chargement plus tôt que
# prévu) : arrêt au menu principal, capturé ; la suite se fait à vue, touche par touche, par appuyer.ps1, qui arrête le jeu
# si un chargement inattendu commence.
"menu principal à regarder : " + (Capture "menu_principal")

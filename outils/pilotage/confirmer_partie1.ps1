# Valide la sauvegarde choisie et confirme « Oui », attend l'entrée en partie et vérifie au journal que c'est
# bien playline0/autosave473 ; sinon, ferme le jeu sans sauvegarder.
$journal = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2\kcd.log"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")
Touche Entree; Start-Sleep -Seconds 2
Touche Entree
$charge = $null
foreach ($i in 1..30) { $charge = Select-String -Path $journal -Pattern "Loading saved game" | Select-Object -Last 1; if ($charge) { break }; Start-Sleep -Seconds 1 }
if (-not $charge -or $charge.Line -notmatch "playline0/autosave473") { "chargement inattendu : fermeture sans sauvegarde"; $p = Get-Process -Name KingdomCome; [void]$p.CloseMainWindow(); return }
foreach ($i in 1..90) { if (Select-String -Path $journal -Pattern "entrée en partie" -Encoding UTF8 -Quiet) { break }; Start-Sleep -Seconds 1 }
"Partie 1, sauvegarde 473 chargée"

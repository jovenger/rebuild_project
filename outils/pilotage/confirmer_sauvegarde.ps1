# Valide la sauvegarde choisie dans « Charger partie » et confirme « Oui » ; vérifie au journal que c'est bien la
# sauvegarde attendue (sinon, ferme le jeu sans sauvegarder) et que la partie est chargée (sinon, le dit : retour au
# menu principal, « Échec du chargement »).
# Exemple : confirmer_sauvegarde.ps1 -Attendu "playline2/autosave003"
param([Parameter(Mandatory = $true)][string]$Attendu)
$journal = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2\kcd.log"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")
$avant = @(Select-String -Path $journal -Pattern "Loading saved game").Count
Touche Entree; Start-Sleep -Seconds 2
Touche Entree
$charge = $null
foreach ($i in 1..30) { $lignes = @(Select-String -Path $journal -Pattern "Loading saved game"); if ($lignes.Count -gt $avant) { $charge = $lignes[-1]; break }; Start-Sleep -Seconds 1 }
if (-not $charge -or $charge.Line -notmatch [regex]::Escape($Attendu)) { "chargement inattendu : fermeture sans sauvegarde"; $p = Get-Process -Name KingdomCome; [void]$p.CloseMainWindow(); return }
if (Attendre-Partie-Chargee $journal) { "sauvegarde $Attendu chargée" }
else { "ÉCHEC du chargement de $Attendu : le jeu est revenu au menu principal ou ne répond pas" }

# « Sauvegarder et quitter » dans une PARTIE D'ESSAI seulement (playline2 ou playline3) : refuse si la dernière
# sauvegarde chargée au journal n'est pas de l'une d'elles ; donne l'alerte si la sauvegarde s'écrit hors de sa ligne. Menu de pause (Échap) : « Sauvegarder et quitter » est la neuvième ligne (huit
# fois Bas) ; la question « Voulez-vous vraiment sauvegarder et quitter ? » a « Non » choisi : Haut puis Entrée.
# Captures D:\socle_captures\captures\sauver_menu.png et sauver_oui.png. Le jeu se ferme ; la sauvegarde écrite est affichée.
$journal = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2\kcd.log"
$sauvegardes = "$env:USERPROFILE\Saved Games\kingdomcome2\saves"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")

$p = Get-Process -Name KingdomCome -ErrorAction SilentlyContinue
if (-not $p) { "le jeu n'est pas lancé"; return }
# Garde du disque (16/10/2026, conseil de la conversation Scriptorium) : les sauvegardes du jeu sont sur C ; sous 1 Go
# libre, une sauvegarde peut échouer ou être tronquée.
$libre_c = [Math]::Round((Get-PSDrive C).Free / 1GB, 2)
if ($libre_c -lt 1) { "disque C : $libre_c Go libres, moins de 1 Go : rien n'est sauvegardé ; fermer par fin_essai.ps1"; return }
$charge = Select-String -Path $journal -Pattern "Loading saved game" | Select-Object -Last 1
if (-not $charge -or $charge.Line -notmatch "(playline[23])/") { "la partie chargée n'est pas la partie d'essai : rien n'est sauvegardé"; return }
$ligne = [regex]::Match($charge.Line, "playline[23]").Value
if (-not (Attendre-Partie-Chargee $journal 5)) { "la partie d'essai n'est pas chargée : rien n'est sauvegardé"; return }
$t0 = Get-Date
if (-not (Mettre-Le-Jeu-Devant)) { "le jeu ne vient pas au premier plan : rien n'est tapé, arrêt"; return }
Touche Echap; Start-Sleep -Seconds 2
foreach ($i in 1..8) { Touche Bas }
Start-Sleep -Milliseconds 500; Capture "sauver_menu" | Out-Null
Touche Entree; Start-Sleep -Seconds 2
Touche Haut; Start-Sleep -Milliseconds 500; Capture "sauver_oui" | Out-Null
Touche Entree
foreach ($i in 1..60) { Start-Sleep -Seconds 2; if (-not (Get-Process -Name KingdomCome -ErrorAction SilentlyContinue)) { break } }
$ecrite = Get-ChildItem $sauvegardes -Recurse -File -Filter *.whs | Where-Object { $_.LastWriteTime -gt $t0 } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($ecrite -and $ecrite.Directory.Name -ne $ligne) { "ALERTE : sauvegarde écrite dans " + $ecrite.Directory.Name + " et non dans " + $ligne + " : " + $ecrite.FullName + " (ne rien faire de plus, prévenir JoVenGer)"; return }
if ($ecrite) { "sauvegardé : " + $ecrite.Directory.Name + "\" + $ecrite.Name + " (" + $ecrite.LastWriteTime + "), jeu fermé = " + (-not (Get-Process -Name KingdomCome -ErrorAction SilentlyContinue)) }
else { "aucune sauvegarde écrite : regarder D:\socle_captures\captures\sauver_menu.png et sauver_oui.png" }

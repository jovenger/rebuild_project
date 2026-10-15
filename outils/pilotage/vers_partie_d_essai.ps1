# Installe le socle, lance le jeu avec -devmode et charge la PARTIE D'ESSAI (playline2, où l'on peut sauvegarder) par
# « Continuer ». Refuse si la sauvegarde la plus récente n'est pas dans playline2 (Continuer chargerait une autre
# partie) ; vérifie au journal que c'est bien playline2 qui se charge, sinon ferme le jeu sans sauvegarder.
# À employer seulement pendant une séance d'essai ouverte par debut_essai.ps1, avec l'accord de JoVenGer.
$racine = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$jeu = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
$journal = Join-Path $jeu "kcd.log"
$sauvegardes = "$env:USERPROFILE\Saved Games\kingdomcome2\saves"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")

if (Get-Process -Name KingdomCome -ErrorAction SilentlyContinue) { "le jeu est lancé : le fermer d'abord"; return }
$derniere = Get-ChildItem $sauvegardes -Recurse -File -Filter *.whs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($derniere.Directory.Name -ne "playline2") { "la sauvegarde la plus récente est dans " + $derniere.Directory.Name + " : « Continuer » ne chargerait pas la partie d'essai ; arrêt"; return }
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
Touche Entree
$charge = $null
foreach ($i in 1..30) { $charge = Select-String -Path $journal -Pattern "Loading saved game" | Select-Object -Last 1; if ($charge) { break }; Start-Sleep -Seconds 1 }
if (-not $charge -or $charge.Line -notmatch "playline2") { "chargement inattendu : fermeture sans sauvegarde"; [void]$p.CloseMainWindow(); return }
foreach ($i in 1..90) { if (Select-String -Path $journal -Pattern "entrée en partie" -Encoding UTF8 -Quiet) { break }; Start-Sleep -Seconds 1 }
"partie d'essai chargée (" + $charge.Line.Trim() + ")"

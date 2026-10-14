# Ferme une séance d'essai en jeu (obligatoire avant de s'arrêter) :
# - ferme le jeu SANS sauvegarder ;
# - vérifie que la Partie 1 (playline0) est identique à sa copie ; sinon le dit, sans rien rétablir (accord de
#   JoVenGer nécessaire) ;
# - remet la liste des mods d'origine et vérifie son empreinte ;
# - relance le veilleur du Scriptorium actuel.
$racine = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$jeu = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
$liste = Join-Path $jeu "Mods\mod_order.txt"
$copie = Join-Path $racine "securite\mod_order_origine_2026-10-14_170426\mod_order.txt"
$empreinte = "75A3A33CC968B4868E40EDCFA2286252E299AE49230C0B6668A3A2E1252A404C"
$etat = Join-Path $racine "securite\playline0_2026-10-14_214438\_etat_d_origine.txt"
$veilleur = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\Scriptorium - veilleur du jeu.lnk"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")

$p = Get-Process -Name KingdomCome -ErrorAction SilentlyContinue
if ($p) {
  [void]$p.CloseMainWindow(); $p.WaitForExit(15000) | Out-Null
  if (-not $p.HasExited) {
    [void][Cycle.U]::SetForegroundWindow($p.MainWindowHandle); Start-Sleep -Milliseconds 800
    if (Jeu-Au-Premier-Plan) { Touche Haut; Touche Entree }
    $p.WaitForExit(30000) | Out-Null
  }
  if (-not $p.HasExited) { "le jeu ne se ferme pas : liste des mods NON remise, à refaire"; return }
}
Start-Sleep -Seconds 2
$maintenant = Get-ChildItem "$env:USERPROFILE\Saved Games\kingdomcome2\saves\playline0" -File | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTime.Ticks)" }
if (Compare-Object (Get-Content $etat) $maintenant) { "ATTENTION : la Partie 1 a changé depuis sa copie ; rien n'est rétabli sans l'accord de JoVenGer" }
else { "Partie 1 identique à sa copie (" + $maintenant.Count + " fichiers)" }
Copy-Item -LiteralPath $copie -Destination $liste -Force
if ((Get-FileHash $liste -Algorithm SHA256).Hash -eq $empreinte) { "liste des mods d'origine remise : " + ((Get-Content $liste) -join " / ") }
else { "ATTENTION : la liste des mods n'a pas l'empreinte d'origine" }
if (-not (Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "veilleur" })) { Start-Process -FilePath $veilleur; Start-Sleep -Seconds 4 }
"veilleur relancé = " + [bool](Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "veilleur" })

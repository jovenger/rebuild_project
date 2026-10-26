# Ferme une séance d'essai en jeu (obligatoire avant de s'arrêter) :
# - ferme le jeu SANS sauvegarder ;
# - vérifie que la Partie 1 (playline0) est identique à sa copie ; sinon le dit, sans rien rétablir (accord de
#   JoVenGer nécessaire) ;
# - remet la liste des mods d'origine et vérifie son empreinte ;
# - relance le veilleur du Scriptorium actuel ;
# - range à part les sauvegardes d'essai plus récentes que la partie de JoVenGer, pour que « Continuer » reprenne sa
#   partie (décision de JoVenGer du 15/10/2026 ; sauvegardes.ps1). Rangées jeu ouvert, AVANT de le fermer : rangées jeu
#   fermé, le nuage Steam les remet au lancement suivant (V59). Une séance finit donc le jeu ouvert, jamais par
#   sauvegarder_et_quitter.ps1 ; sinon ce script le dit.
$racine = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$jeu = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
$liste = Join-Path $jeu "Mods\mod_order.txt"
$copie = Join-Path $racine "securite\mod_order_origine_2026-10-14_170426\mod_order.txt"
$empreinte = "75A3A33CC968B4868E40EDCFA2286252E299AE49230C0B6668A3A2E1252A404C"
$etat = Join-Path $racine "securite\playline0_2026-10-14_214438\_etat_d_origine.txt"
$veilleur = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\Scriptorium - veilleur du jeu.lnk"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "sauvegardes.ps1")

$p = Get-Process -Name KingdomCome -ErrorAction SilentlyContinue
if ($p) {
  Ranger-Les-Essais -PendantLeJeu
  [void]$p.CloseMainWindow(); $p.WaitForExit(15000) | Out-Null
  if (-not $p.HasExited) {
    if (Mettre-Le-Jeu-Devant) { Touche Haut; Touche Entree; $p.WaitForExit(30000) | Out-Null }
    # Si le jeu ne vient pas devant, aucune touche : il est arrêté, ce qui ne sauvegarde rien.
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; $p.WaitForExit(15000) | Out-Null }
  }
  if (-not $p.HasExited) { "le jeu ne se ferme pas : liste des mods NON remise, à refaire"; return }
}
Start-Sleep -Seconds 2
$maintenant = Get-ChildItem "$env:USERPROFILE\Saved Games\kingdomcome2\saves\playline0" -File | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTime.Ticks)" }
if (Compare-Object (Get-Content $etat) $maintenant) { "ATTENTION : la Partie 1 a changé depuis sa copie ; rien n'est rétabli sans l'accord de JoVenGer" }
else { "Partie 1 identique à sa copie (" + $maintenant.Count + " fichiers)" }
# Garde-fou (19/10, plan du jour J de la bascule) : la liste n'est remise que si elle est celle d'une séance
# (debut_essai.ps1 : le socle seul). Sinon (séance avec le pair, ou partie basculée de JoVenGer où le socle est son monde
# de tous les jours), remettre l'ancienne liste y remettrait l'ancien monde : rien n'est touché.
$actuelle = @(Get-Content $liste | Where-Object { $_.Trim() -ne "" })
if ($actuelle.Count -ne 1 -or $actuelle[0].Trim() -ne "scriptorium_socle") {
  "liste des mods NON remise : ce n'est pas celle d'une séance (" + ($actuelle -join " / ") + ") ; rien n'est changé"
} else {
  Copy-Item -LiteralPath $copie -Destination $liste -Force
  if ((Get-FileHash $liste -Algorithm SHA256).Hash -eq $empreinte) { "liste des mods d'origine remise : " + ((Get-Content $liste) -join " / ") }
  else { "ATTENTION : la liste des mods n'a pas l'empreinte d'origine" }
}
if (-not (Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "veilleur" })) { Start-Process -FilePath $veilleur; Start-Sleep -Seconds 4 }
"veilleur relancé = " + [bool](Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "veilleur" })
Ranger-Les-Essais | ForEach-Object {
  if ($_ -like "rangée :*") { "ATTENTION, rangée jeu fermé (le nuage Steam la remettra au prochain lancement ; ouvrir une séance courte et la finir jeu ouvert) : " + $_ } else { $_ }
}

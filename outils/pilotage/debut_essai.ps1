# Ouvre une séance d'essai en jeu, SEULEMENT avec l'accord de JoVenGer donné juste avant (la liste des mods change).
# - vérifie que la liste des mods est celle d'origine (empreinte de la copie securite\mod_order_origine_…) ;
# - arrête le veilleur du Scriptorium actuel (tableau ouvert au lancement du jeu) ;
# - réduit la liste des mods au seul socle. Les dossiers des mods ne sont ni renommés ni déplacés.
# - range à part les sauvegardes d'essai plus récentes que la partie de JoVenGer qui seraient revenues (le nuage Steam
#   les suit) : à l'ouverture, toute sauvegarde rangée ici en est une.
# Fermer la séance par fin_essai.ps1.
$racine = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$jeu = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
$liste = Join-Path $jeu "Mods\mod_order.txt"
$copie = Join-Path $racine "securite\mod_order_origine_2026-10-14_170426\mod_order.txt"
$empreinte = "75A3A33CC968B4868E40EDCFA2286252E299AE49230C0B6668A3A2E1252A404C"

if (Get-Process -Name KingdomCome -ErrorAction SilentlyContinue) { "le jeu est lancé : le fermer d'abord"; return }
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "sauvegardes.ps1")
Ranger-Les-Essais | ForEach-Object { if ($_ -like "rangée :*") { "à l'ouverture, revenue (nuage Steam ?) et " + $_ } else { $_ } }
if (-not (Test-Path -LiteralPath $copie) -or (Get-FileHash $copie -Algorithm SHA256).Hash -ne $empreinte) { "copie d'origine de la liste des mods absente ou changée : arrêt"; return }
if ((Get-FileHash $liste -Algorithm SHA256).Hash -ne $empreinte) {
  "la liste des mods n'est pas celle d'origine : " + ((Get-Content $liste) -join " / ") + " ; rien n'est changé"; return
}
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "veilleur" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Confirm:$false }
$provisoire = "$liste.provisoire"
[IO.File]::WriteAllText($provisoire, "scriptorium_socle`r`n", (New-Object Text.UTF8Encoding $false))
Move-Item -LiteralPath $provisoire -Destination $liste -Force
"séance ouverte : liste des mods = " + ((Get-Content $liste) -join " / ") + " ; veilleur arrêté = " + [bool](-not (Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "veilleur" }))

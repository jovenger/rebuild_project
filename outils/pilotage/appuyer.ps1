# Envoie au jeu une suite de touches, une par une, jeu devant vérifié avant chacune (touches.ps1), puis capture l'écran
# (securite\captures\<Nom>.png). Après chaque Entrée, regarde au journal si un chargement de sauvegarde a commencé : s'il
# ne s'agit pas de la sauvegarde attendue (-Attendu, par exemple "playline0/autosave473"), le jeu est arrêté aussitôt,
# ce qui ne sauvegarde rien (règle de JoVenGer : jamais la partie actuelle avec le socle).
# Exemple : appuyer.ps1 -Touches "Bas,Bas,Entree" -Attendu "playline0/autosave473" -Nom "menu_charger"
param([Parameter(Mandatory = $true)][string]$Touches, [string]$Attendu = "", [string]$Nom = "appuyer")
$journal = "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2\kcd.log"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "touches.ps1")

function Chargements { return @(Select-String -Path $journal -Pattern "Loading saved game") }

$avant = (Chargements).Count
foreach ($touche in $Touches.Split(",")) {
  Touche $touche.Trim()
  if ($touche.Trim() -eq "Entree") {
    Start-Sleep -Seconds 3
    $lignes = Chargements
    if ($lignes.Count -gt $avant) {
      $charge = $lignes[-1].Line
      if (-not $Attendu -or $charge -notmatch [regex]::Escape($Attendu)) {
        $p = Get-Process -Name KingdomCome -ErrorAction SilentlyContinue
        if ($p) { Stop-Process -Id $p.Id -Force }
        "CHARGEMENT INATTENDU, jeu arrêté sans sauvegarde : $charge"
        return
      }
      "chargement attendu commencé : $charge"
      return
    }
  }
}
"écran : " + (Capture $Nom)

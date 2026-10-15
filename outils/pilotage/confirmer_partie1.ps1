# Valide la sauvegarde 473 de la Partie 1 choisie par vers_partie1.ps1 (voir confirmer_sauvegarde.ps1).
& (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "confirmer_sauvegarde.ps1") -Attendu "playline0/autosave473"

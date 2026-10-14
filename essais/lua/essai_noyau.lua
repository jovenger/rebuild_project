-- Essais du noyau et du poste d'essai.

essai("noyau : les morceaux démarrent dans l'ordre, un morceau en panne ne bloque pas les autres", function()
  depart()
  local ordre = {}
  Scriptorium.declarer_morceau("essai_a", function() table.insert(ordre, "a") end)
  Scriptorium.declarer_morceau("essai_b", function() error("cassé exprès") end)
  Scriptorium.declarer_morceau("essai_c", function() table.insert(ordre, "c") end)
  local prets, pannes = Scriptorium.demarrer()
  egal(pannes, 1, "une panne")
  verifier(prets >= 2, "les autres sont prêts")
  egal(ordre[1], "a", "ordre a")
  egal(ordre[2], "c", "ordre c, malgré la panne de b")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_socle_morceau_en_panne", "panne annoncée au joueur")
  local nouveau_prets = Scriptorium.demarrer()
  egal(nouveau_prets, prets, "un second démarrage ne relance rien")
  -- Retire les morceaux d'essai pour ne pas gêner les essais suivants.
  for i = #Scriptorium.morceaux, 1, -1 do
    if string.find(Scriptorium.morceaux[i].nom, "^essai_") then
      table.remove(Scriptorium.morceaux, i)
    end
  end
end)

essai("noyau : tout prêt -> « le socle est prêt » au joueur, et les commandes du poste sont posées", function()
  depart()
  local prets, pannes = Scriptorium.demarrer()
  egal(pannes, 0, "aucune panne")
  egal(prets, 3, "bandeau, registre, poste")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_socle_pret", "prêt annoncé")
  egal(#FauxJeu.commandes, 3, "trois commandes de console")
  egal(FauxJeu.commandes[1].nom, "scriptorium_essai_bandeau", "nom de la première commande")
end)

essai("poste : l'essai du bandeau donne nouvelle, arrivée ×3 regroupées, alerte devant", function()
  depart()
  local sorts = Scriptorium.poste.essai_bandeau()
  egal(table.concat(sorts, ","), "en_file,en_file,regroupe,regroupe,en_file", "sorts")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_essai_alerte", "l'alerte d'abord")
end)

essai("poste : l'essai du registre compte les appels à travers écriture et relecture", function()
  depart()
  local appels = Scriptorium.poste.essai_registre()
  egal(appels, 1, "premier appel")
  appels = Scriptorium.poste.essai_registre()
  egal(appels, 2, "second appel, relu depuis la partie")
end)

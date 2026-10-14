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
  egal(prets, 6, "bandeau, registre, coffre, camp, hommes, poste")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_socle_pret", "prêt annoncé")
  egal(#FauxJeu.commandes, 8, "huit commandes de console")
  egal(FauxJeu.commandes[1].nom, "scriptorium_essai_bandeau", "nom de la première commande")
end)

essai("poste : l'essai du bandeau donne nouvelle, arrivée ×3 regroupées, alerte devant", function()
  depart()
  local sorts = Scriptorium.poste.essai_bandeau()
  egal(table.concat(sorts, ","), "en_file,en_file,regroupe,regroupe,en_file", "sorts")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_essai_alerte", "l'alerte d'abord")
end)

essai("poste : l'essai du coffre dépose, paie, et refuse la dépense trop grosse", function()
  depart()
  FauxJeu.bourse_henry = 150
  local sorts, bilan = Scriptorium.poste.essai_coffre()
  egal(table.concat(sorts, ","), "true,true,true,true,false", "sorts")
  egal(bilan.groschen, 70, "solde")
  egal(bilan.reserves.vivres, 6, "vivres")
  egal(FauxJeu.bourse_henry, 50, "bourse d'Henry")
end)

essai("poste : l'essai du camp fonde là où se tient Henry, puis redresse", function()
  depart()
  FauxJeu.position_joueur = { x = 50, y = 60, z = 70 }
  FauxJeu.cap_joueur = 180
  local sort, lits, sieges = Scriptorium.poste.essai_camp()
  egal(sort, "fonde", "fondé")
  egal(lits, 5, "cinq lits")
  egal(sieges, 4, "quatre sièges")
  local p = Scriptorium.camp.position_de("feu_central")
  verifier(math.abs(p.x - 50) < 0.001 and math.abs(p.y - 60) < 0.001, "le feu est sous Henry")
  sort = Scriptorium.poste.essai_camp()
  egal(sort, "redresse", "la seconde fois, redressé")
  verifier(Scriptorium.poste.essai_camp_agrandir(), "agrandi")
  verifier(Scriptorium.poste.essai_camp_lever(), "levé")
end)

essai("poste : l'essai des hommes engage trois hommes et pose le battement", function()
  depart()
  FauxJeu.heure = 10
  Scriptorium.camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  Scriptorium.coffre.encaisser(200, "butin")
  local ids, effectif = Scriptorium.poste.essai_hommes()
  egal(table.concat(ids, ","), "homme_1,homme_2,homme_3", "trois engagés")
  egal(effectif.presents, 3, "trois présents")
  egal(Scriptorium.coffre.solde(), 200 - 24 - 28 - 24, "primes payées")
  egal(#FauxJeu.minuteries, 1, "battement posé")
  FauxJeu.tic_minuterie()
  egal(#FauxJeu.minuteries, 1, "et reposé")
  verifier(#FauxJeu.ordres >= 3, "ordres donnés aux trois")
end)

essai("poste : l'essai du registre compte les appels à travers écriture et relecture", function()
  depart()
  local appels = Scriptorium.poste.essai_registre()
  egal(appels, 1, "premier appel")
  appels = Scriptorium.poste.essai_registre()
  egal(appels, 2, "second appel, relu depuis la partie")
end)

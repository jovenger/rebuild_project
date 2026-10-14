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
  egal(FauxJeu.en_ecran, nil, "rien à l'écran avant la partie")
  FauxJeu.entrer_en_partie()
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_socle_morceau_en_panne", "panne annoncée au joueur en partie")
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
  egal(prets, 12, "bandeau, registre, coffre, camp, hommes, bataille, directeur, enceinte, atelier, patrouilles, discipline, poste")
  FauxJeu.entrer_en_partie()
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_socle_pret", "prêt annoncé à l'entrée en partie")
  egal(#FauxJeu.commandes, 23, "vingt-trois commandes de console")
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
  Scriptorium.arreter_le_battement()
end)

local function lignes_avec(motif)
  local n = 0
  for _, ligne in ipairs(FauxJeu.journal_lignes) do
    if string.find(ligne, motif, 1, true) then n = n + 1 end
  end
  return n
end

essai("poste : la console passe par executer(), avec le nom de la commande", function()
  depart()
  Scriptorium.demarrer()
  egal(FauxJeu.commandes[1].code, "Scriptorium.poste.executer('scriptorium_essai_bandeau')", "code de la première commande")
  local code = assert(loadstring(FauxJeu.commandes[1].code))
  code()
  egal(Scriptorium.bandeau.en_attente(), 3, "l'essai du bandeau a tourné : trois messages")
  verifier(not Scriptorium.poste.executer("scriptorium_inconnue"), "une commande inconnue n'est pas exécutée")
  egal(lignes_avec("commande inconnue"), 1, "et c'est noté")
end)

essai("poste : l'ordre trouvé au lancement n'est pas rejoué ; un ordre neuf l'est une seule fois", function()
  depart()
  local poste = Scriptorium.poste
  FauxJeu.fichier_ordres = { numero = 4, commande = "scriptorium_essai_bandeau" }
  egal(poste.relever_ordres(), "ancien", "ordre du lancement")
  egal(Scriptorium.bandeau.en_attente(), 0, "rien n'a tourné")
  egal(poste.relever_ordres(), "deja_fait", "relu sans changement")
  FauxJeu.fichier_ordres = { numero = 5, commande = "scriptorium_essai_bandeau" }
  egal(poste.relever_ordres(), "execute", "ordre neuf")
  egal(Scriptorium.bandeau.en_attente(), 3, "l'essai du bandeau a tourné")
  egal(poste.relever_ordres(), "deja_fait", "pas deux fois")
  egal(lignes_avec("ordre n° 5 : scriptorium_essai_bandeau"), 1, "noté une fois au journal")
end)

essai("poste : sans fichier au lancement, le premier ordre écrit est exécuté", function()
  depart()
  local poste = Scriptorium.poste
  egal(poste.relever_ordres(), "absent", "pas de fichier")
  egal(lignes_avec("pas de fichier d'ordres au lancement"), 1, "noté")
  FauxJeu.fichier_ordres = { numero = 1, commande = "scriptorium_bilan" }
  egal(poste.relever_ordres(), "execute", "premier ordre")
  verifier(lignes_avec("Poste : bandeau, affichés") == 1, "le bilan a écrit au journal")
end)

essai("poste : commande inconnue refusée, fichier illisible noté une seule fois", function()
  depart()
  local poste = Scriptorium.poste
  poste.relever_ordres()
  FauxJeu.fichier_ordres = { numero = 1, commande = "os_execute" }
  egal(poste.relever_ordres(), "refuse", "commande hors liste")
  egal(poste.relever_ordres(), "deja_fait", "pas retentée")
  FauxJeu.fichier_ordres = { numero = 2 }
  egal(poste.relever_ordres(), "illisible", "commande manquante")
  egal(poste.relever_ordres(), "illisible", "toujours illisible")
  FauxJeu.fichier_ordres = nil
  FauxJeu.fichier_ordres_raison = "erreur de syntaxe"
  egal(poste.relever_ordres(), "illisible", "syntaxe")
  poste.relever_ordres()
  egal(lignes_avec("illisible : numéro ou commande manquant"), 1, "noté une fois")
  egal(lignes_avec("illisible : erreur de syntaxe"), 1, "noté une fois")
end)

essai("poste : hors partie, l'ordre attend, puis s'exécute quand la partie est là", function()
  depart()
  local poste = Scriptorium.poste
  poste.relever_ordres()
  FauxJeu.partie = false
  FauxJeu.fichier_ordres = { numero = 1, commande = "scriptorium_essai_bandeau" }
  egal(poste.relever_ordres(), "en_attente", "pas de partie")
  egal(poste.relever_ordres(), "en_attente", "toujours pas")
  egal(lignes_avec("en attente d'une partie"), 1, "noté une fois")
  FauxJeu.partie = true
  egal(poste.relever_ordres(), "execute", "la partie est là")
  egal(Scriptorium.bandeau.en_attente(), 3, "l'essai a tourné")
end)

essai("poste : demarrer() relève les ordres par la minuterie et veille au journal", function()
  depart()
  local poste = Scriptorium.poste
  poste.demarrer()
  egal(#FauxJeu.minuteries, 1, "une minuterie")
  egal(FauxJeu.minuteries[1].ms, poste.reglages.cadence_ms, "à la cadence réglée")
  poste.demarrer()
  egal(#FauxJeu.minuteries, 1, "un second demarrer() ne double pas la minuterie")
  FauxJeu.tic_minuterie()
  egal(FauxJeu.lectures_ordres, 1, "un relevé")
  egal(lignes_avec("Poste : veille, partie en cours = true"), 1, "première veille")
  for _ = 1, poste.reglages.tours_par_veille do
    FauxJeu.tic_minuterie()
  end
  egal(lignes_avec("Poste : veille"), 2, "une veille de plus après quinze relevés")
  FauxJeu.partie = false
  FauxJeu.tic_minuterie()
  egal(lignes_avec("Poste : veille, partie en cours = false"), 1, "veille au changement de partie")
  poste.arreter()
  FauxJeu.tic_minuterie()
  egal(#FauxJeu.minuteries, 0, "arrêté : plus de minuterie")
end)

essai("socle : l'entrée en partie repose les minuteries, éteint les anciennes, relit le registre", function()
  depart()
  Scriptorium.registre.declarer_case("essai_partie", 1, function() return { n = 1 } end)
  Scriptorium.demarrer()
  egal(#FauxJeu.minuteries, 3, "bandeau, poste et battement posés au démarrage")
  Scriptorium.registre.lire("essai_partie")
  Scriptorium.registre.enregistrer()
  Scriptorium.registre.lire("essai_partie").n = 5
  FauxJeu.entrer_en_partie()
  egal(#FauxJeu.minuteries, 6, "trois minuteries reposées")
  egal(Scriptorium.registre.lire("essai_partie").n, 1, "registre relu depuis la sauvegarde (V5) : la modification non enregistrée a disparu")
  for _ = 1, 6 do
    FauxJeu.tic_minuterie()
  end
  egal(#FauxJeu.minuteries, 3, "les trois anciennes se sont éteintes, les trois neuves tournent")
  egal(lignes_avec("entrée en partie, minuteries reposées"), 1, "noté au journal")
  FauxJeu.sortir_de_partie()
  for _ = 1, 3 do
    FauxJeu.tic_minuterie()
  end
  egal(#FauxJeu.minuteries, 0, "hors partie, plus rien ne tourne")
  FauxJeu.entrer_en_partie()
  egal(#FauxJeu.minuteries, 3, "une nouvelle entrée repose les trois")
  Scriptorium.arreter_le_battement()
end)

essai("poste : l'essai du registre compte les appels à travers écriture et relecture", function()
  depart()
  local appels = Scriptorium.poste.essai_registre()
  egal(appels, 1, "premier appel")
  appels = Scriptorium.poste.essai_registre()
  egal(appels, 2, "second appel, relu depuis la partie")
end)

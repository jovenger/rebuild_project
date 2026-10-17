-- Essais des réglages par fichier (fiche 10_reglages.md).

local reglages = Scriptorium.reglages
local hommes = Scriptorium.hommes
local bataille = Scriptorium.bataille
local enceinte = Scriptorium.enceinte
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre

local function lignes_avec(motif)
  local n = 0
  for _, ligne in ipairs(FauxJeu.journal_lignes) do
    if string.find(ligne, motif, 1, true) then n = n + 1 end
  end
  return n
end

-- Les messages attendent dans la file du bandeau : on les fait défiler, puis on lit l'historique.
local function annonces(cle)
  Scriptorium.bandeau.battre()
  while Scriptorium.bandeau.en_cours() or Scriptorium.bandeau.en_attente() > 0 do
    FauxJeu.avancer(10)
    Scriptorium.bandeau.battre()
  end
  local liste = {}
  for _, entree in ipairs(Scriptorium.bandeau.historique()) do
    if entree.cle == cle then table.insert(liste, entree) end
  end
  return liste
end

local function poser(fichier, moment)
  FauxJeu.fichier_reglages = fichier
  return reglages.relever_le_fichier(moment or "en_cours")
end

essai("réglages : sans fichier, les valeurs validées s'appliquent", function()
  depart_avec_caractere()
  local r = poser(nil)
  egal(r.etat, "absent", "pas de fichier")
  egal(r.changes, 0, "rien ne change")
  egal(hommes.reglages.ration, 2, "deux rations, valeur validée")
  egal(reglages.valeur_validee("bandes.brigands.butin_par_tete"), 16, "butin validé relevé")
  egal(#annonces("ui_scriptorium_reglages_mis_a_jour"), 0, "rien à dire au joueur")
end)

essai("réglages : une valeur posée, puis retirée du fichier, puis le fichier effacé", function()
  depart_avec_caractere()
  local r = poser({ hommes = { ration = 3 }, bandes = { brigands = { butin_par_tete = 20 } } })
  egal(r.etat, "applique", "appliqué")
  egal(r.changes, 2, "deux valeurs changées")
  egal(r.refuses, 0, "rien de refusé")
  egal(hommes.reglages.ration, 3, "trois rations")
  egal(bataille.sortes.brigands.butin_par_tete, 20, "butin réglé")
  verifier(lignes_avec("« hommes.ration » = 3 (avant 2)") == 1, "le détail au journal")
  r = poser({ hommes = { ration = 3 } })
  egal(r.changes, 1, "le butin revient")
  egal(bataille.sortes.brigands.butin_par_tete, 16, "valeur validée rendue")
  r = poser(nil)
  egal(r.etat, "absent", "fichier effacé")
  egal(hommes.reglages.ration, 2, "tout revient")
end)

essai("réglages : listes à nom, désignées par le nom", function()
  depart_avec_caractere()
  local r = poser({ issues = { victoire = { blesses = 0.1 } }, fautes = { rixe = { poids = 5.5 } } })
  egal(r.changes, 2, "deux valeurs")
  egal(bataille.issues[1].nom, "victoire", "la victoire est la première")
  egal(bataille.issues[1].blesses, 0.1, "blessés de la victoire réglés")
  egal(Scriptorium.discipline.fautes[1].poids, 5.5, "poids de la rixe, un taux, réglé")
  r = poser({ issues = { [1] = { blesses = 0.2 } } })
  egal(r.refuses, 1, "une place au lieu d'un nom : refusée")
  egal(bataille.issues[1].blesses, 0.15, "valeur validée")
end)

essai("réglages : sections, noms et textes inconnus refusés, le reste s'applique", function()
  depart_avec_caractere()
  local r = poser({
    hommes = { ration = 3, rations = 9 },
    magie = { mana = 3 },
    issues = { victoire = { cle = 4 } },
    bandes = { brigands = 2 },
    chemins = { ronde_proche = { points = 1, risque = 0.2 } },
  })
  egal(r.changes, 2, "la ration et le risque passent")
  egal(r.refuses, 5, "cinq refus")
  egal(hommes.reglages.ration, 3, "la ration est posée")
  egal(Scriptorium.patrouilles.chemins.ronde_proche.risque, 0.2, "le risque est posé")
  verifier(lignes_avec("« hommes.rations » = 9 (inconnu)") == 1, "nom inconnu")
  verifier(lignes_avec("« magie.mana » = 3 (section_inconnue)") == 1, "section inconnue")
  verifier(lignes_avec("« issues.victoire.cle » = 4 (pas_reglable)") == 1, "un texte ne se règle pas")
  verifier(lignes_avec("« bandes.brigands » = 2 (pas_reglable)") == 1, "une table ne se remplace pas par un nombre")
  verifier(lignes_avec("« chemins.ronde_proche.points » = 1 (pas_reglable)") == 1, "les points d'un chemin ne se règlent pas")
end)

essai("réglages : signe, parts, heures, entiers, taux", function()
  depart_avec_caractere()
  local r = poser({
    coffre = { lignes_gardees = -3 },
    discipline = { chance_de_base = 1.5, reputation_exaction = 2 },
    hommes = { heure_repas = 24, ration = 2.5, moral_desertion = "dix" },
    enceinte = { avance_de_guet = 1.5 },
  })
  egal(r.changes, 0, "rien ne passe")
  egal(r.refuses, 7, "sept refus")
  verifier(lignes_avec("(signe)") == 2, "signe : positif reste positif, négatif reste négatif")
  verifier(lignes_avec("(hors_de_0_a_1)") == 1, "une chance au-dessus de 1")
  verifier(lignes_avec("(heure_invalide)") == 1, "24 h n'est pas une heure")
  verifier(lignes_avec("(pas_entier)") == 2, "entier reste entier, même une heure d'avance (limite validée)")
  verifier(lignes_avec("(pas_un_nombre)") == 1, "un mot")
  r = poser({ discipline = { reputation_exaction = -8 }, rangs = { soudoyer = 1.2 }, bandes = { brigands = { poids = 1.25 } },
              paliers = { palier_2 = 1.3 }, hommes = { heure_repas = 6 } })
  egal(r.refuses, 0, "négatif restant négatif, taux décimaux, heure entière")
  egal(Scriptorium.discipline.reglages.reputation_exaction, -8, "perte de réputation réglée")
  egal(hommes.rangs.soudoyer, 1.2, "multiplicateur de rang décimal")
  egal(bataille.sortes.brigands.poids, 1.25, "poids décimal")
end)

essai("réglages : une paire min et max incohérente est refusée", function()
  depart_avec_caractere()
  local r = poser({ discipline = { vol_min = 30 } })
  egal(r.refuses, 1, "minimum au-dessus du maximum validé")
  egal(Scriptorium.discipline.reglages.vol_min, 5, "minimum validé")
  r = poser({ discipline = { vol_min = 30, vol_max = 25 } })
  egal(r.refuses, 2, "les deux refusées")
  r = poser({ discipline = { vol_min = 10, vol_max = 40 } })
  egal(r.refuses, 0, "paire cohérente")
  egal(Scriptorium.discipline.reglages.vol_max, 40, "maximum posé")
end)

essai("réglages : un fichier inchangé ne fait rien, un fichier illisible ne change rien", function()
  depart_avec_caractere()
  poser({ hommes = { ration = 3 } })
  local lignes = #FauxJeu.journal_lignes
  local r = poser({ hommes = { ration = 3 } })
  egal(r.etat, "inchange", "même contenu")
  egal(#FauxJeu.journal_lignes, lignes, "rien au journal")
  FauxJeu.fichier_reglages_raison = "erreur de syntaxe"
  r = reglages.relever_le_fichier("en_cours")
  egal(r.etat, "illisible", "illisible")
  egal(hommes.reglages.ration, 3, "les valeurs en place restent")
  egal(#annonces("ui_scriptorium_reglages_illisible"), 1, "le joueur est prévenu")
  reglages.relever_le_fichier("en_cours")
  egal(#annonces("ui_scriptorium_reglages_illisible"), 1, "une seule fois")
  FauxJeu.fichier_reglages_raison = nil
  r = poser({ hommes = { ration = 4 } })
  egal(hommes.reglages.ration, 4, "relu dès qu'il est lisible")
end)

essai("réglages : le joueur n'est prévenu qu'en cours de partie", function()
  depart_avec_caractere()
  poser({ hommes = { ration = 3 } }, "lancement")
  egal(#annonces("ui_scriptorium_reglages_mis_a_jour"), 0, "au lancement, en silence")
  poser({ hommes = { ration = 4 } }, "entree")
  egal(#annonces("ui_scriptorium_reglages_mis_a_jour"), 0, "à l'entrée en partie, en silence")
  poser({ hommes = { ration = 5, rations = 1 } }, "en_cours")
  local liste = annonces("ui_scriptorium_reglages_mis_a_jour")
  egal(#liste, 1, "en cours de partie, un message")
  egal(liste[1].complement, "1 changé(s), 1 refusé(s)", "le compte au complément")
end)

essai("réglages : l'enceinte, rayon et pans acceptés, cercle ouvert et rayon dans le camp refusés", function()
  depart_avec_caractere()
  local r = poser({ enceinte = { rayon = 25, pans = 28 } })
  egal(r.refuses, 0, "25 m et 28 pans : cercle fermé")
  egal(#enceinte.plan, 28 + 2, "plan refait : 28 places et deux tours")
  verifier(math.abs(enceinte.plan[1].y - 25) < 0.01, "la porte sur le nouveau cercle")
  r = poser({ enceinte = { rayon = 25 } })
  egal(r.refuses, 1, "25 m avec 22 pans : cercle ouvert")
  verifier(lignes_avec("(cercle_ouvert)") == 1, "raison")
  egal(enceinte.reglages.rayon, 20, "rayon validé")
  egal(#enceinte.plan, 22 + 2, "plan revenu aux 22 places")
  r = poser({ enceinte = { rayon = 14 } })
  egal(r.refuses, 1, "14 m : le camp déborde")
  verifier(lignes_avec("(rayon_dans_le_camp)") == 1, "raison")
  r = poser({ enceinte = { rayon = 25, pans = 28, bois_tours = 60 } })
  egal(r.changes, 3, "forme et coût")
end)

essai("réglages : une enceinte bâtie est reposée quand son plan change, en partie et à l'entrée", function()
  depart_avec_caractere()
  FauxJeu.heure = 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  coffre.ajouter_reserve("bois", 200, "achat")
  verifier(enceinte.batir(), "palissade bâtie")
  local poses = #FauxJeu.objets_poses
  poser({ enceinte = { rayon = 25, pans = 28 } }, "en_cours")
  egal(#FauxJeu.objets_poses - poses, 28, "reposée aussitôt sur le nouveau cercle")
  poses = #FauxJeu.objets_poses
  poser({ enceinte = { rayon = 25, pans = 28, bois_tours = 60 } }, "en_cours")
  egal(#FauxJeu.objets_poses - poses, 0, "un coût changé ne repose rien")
  -- Fichier changé pendant que le jeu était au menu : à l'entrée, l'enceinte se relance d'abord (ancien cercle),
  -- puis les réglages la reposent sur le nouveau.
  poses = #FauxJeu.objets_poses
  enceinte.relancer()
  poser({ enceinte = { rayon = 22, pans = 26 } }, "entree")
  egal(#FauxJeu.objets_poses - poses, 28 + 26, "reposée sur le nouveau cercle dès l'entrée")
  poses = #FauxJeu.objets_poses
  poser({ enceinte = { rayon = 20, pans = 22 } }, "lancement")
  egal(#FauxJeu.objets_poses - poses, 0, "au lancement, rien à reposer")
end)

essai("réglages : relu au lancement, à l'entrée en partie, puis toutes les deux secondes", function()
  depart_avec_caractere()
  FauxJeu.fichier_reglages = { hommes = { ration = 3 } }
  Scriptorium.demarrer()
  egal(hommes.reglages.ration, 3, "appliqué au lancement")
  FauxJeu.fichier_reglages = { hommes = { ration = 4 } }
  FauxJeu.entrer_en_partie()
  egal(hommes.reglages.ration, 4, "relu à l'entrée en partie")
  local lectures = FauxJeu.lectures_reglages
  FauxJeu.fichier_reglages = { hommes = { ration = 5 } }
  for _ = 1, #FauxJeu.minuteries do
    FauxJeu.tic_minuterie()
  end
  verifier(FauxJeu.lectures_reglages > lectures, "relu par la veille")
  egal(hommes.reglages.ration, 5, "appliqué en cours de partie")
  egal(#annonces("ui_scriptorium_reglages_mis_a_jour"), 1, "le joueur est prévenu")
  Scriptorium.arreter_le_battement()
end)

essai("réglages : chaque valeur du catalogue est un nombre relevé, et chaque section existe", function()
  depart_avec_caractere()
  local sections = 0
  for _, entree in ipairs(reglages.catalogue) do
    local morceau = Scriptorium[entree.morceau]
    verifier(type(morceau) == "table" and type(morceau[entree.table]) == "table", "table de " .. entree.section)
    sections = sections + 1
  end
  egal(sections, 36, "trente-six sections (les exemptions des gens de métier, fiche 18, 5 c ; le socle, depuis V72 ; le cerveau et les priorités de l'arbitre, depuis le 16/10 ; les rondes et les formations, depuis le 17/10 ; les interrupteurs et les deux journées, fiche 16 ; les camps de bandits et les paliers, fiche 17)")
  verifier(reglages.relever_les_valeurs_validees() > 100, "plus de cent valeurs réglables")
  egal(reglages.valeur_en_place("prix.vivres"), 2, "prix des vivres")
  egal(reglages.valeur_validee("issues.victoire.cle"), nil, "un texte n'est pas relevé")
end)

-- Fiche 16, 3 b : l'horloge de Scriptorium pose la journée par le fichier (réveil 7 h, coucher 22 h) ; une journée qui
-- ne tient pas (trou, deux fois la même activité de suite, plus de 24 h) est refusée en entier.
essai("réglages : la journée des hommes et celle du Directeur, posées par le fichier ; une journée boiteuse refusée", function()
  depart_avec_caractere()
  FauxJeu.heure = 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  coffre.encaisser(5000, "butin")
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local function gardes_a(heure)
    hommes.reglages.postes_garde_jour, hommes.reglages.hommes_par_poste_jour = 1, 1
    local n = #hommes.gardes(heure)
    hommes.reglages.postes_garde_jour = 0
    return n
  end
  hommes.reglages.postes_garde_jour, hommes.reglages.postes_garde_nuit = 0, 0
  egal(hommes.activite_de(id, 6.5).activite, "lever", "6 h 30 : le lever du socle")
  egal(gardes_a(6.5), 1, "6 h 30 : le jour, une garde")
  local r = poser({ journee = { sommeil = { a = 7 }, lever = { de = 7, a = 8 }, repas_du_matin = { de = 8, a = 9 },
                                exercice = { de = 9 } },
                    journee_du_directeur = { sommeil = { a = 7 }, comptes = { de = 7 } } })
  egal(r.refuses, 0, "réveil à 7 h : accepté")
  egal(hommes.activite_de(id, 6.5).activite, "sommeil", "6 h 30 : il dort")
  egal(gardes_a(6.5), 0, "6 h 30 : la nuit, aucune garde de nuit au réglage")
  egal(hommes.activite_de(id, 7.5).activite, "lever", "7 h 30 : le lever")
  egal(Scriptorium.directeur.journee[3].a, 7, "le Directeur dort jusqu'à 7 h")
  r = poser({ journee = { sommeil = { a = 7 } } })
  egal(r.refuses, 1, "un trou entre le sommeil et le lever : refusé")
  verifier(lignes_avec("(trou_dans_la_journee)") == 1, "raison")
  egal(hommes.journee[8].a, 5, "le sommeil revenu à 5 h")
  egal(Scriptorium.directeur.journee[3].a, 6, "le Directeur aussi, son réglage retiré")
  r = poser({ journee = { repas_de_midi = { de = 11, a = 12 }, exercice = { a = 11 }, corvee = { de = 12 } } })
  egal(r.refuses, 0, "midi décalé, sans trou : accepté")
  r = poser({ journee = { sommeil = { de = 21 } } })
  egal(r.refuses, 1, "le sommeil commence avant la fin de la veillée : refusé")
  egal(hommes.journee[8].de, 22, "coucher validé")
  for _, cas in ipairs({
    { { nom = "a", de = 5, a = 5, activite = "x" }, { nom = "b", de = 5, a = 5, activite = "y" } },
    { { nom = "a", de = 5, a = 12, activite = "x" }, { nom = "b", de = 12, a = 5, activite = "x" } },
    { { nom = "a", de = 5, a = 12, activite = "x" }, { nom = "b", de = 12, a = 25, activite = "y" } },
    { { nom = "a", de = 0, a = 12, activite = "x" }, { nom = "b", de = 12, a = 0, activite = "y" }, { nom = "c", de = 0, a = 0, activite = "z" } },
  }) do
    verifier(not Scriptorium.journee_valable(cas), "journée boiteuse refusée")
  end
  verifier(Scriptorium.journee_valable(hommes.journee), "la journée en place est valable")
  verifier(Scriptorium.journee_valable(Scriptorium.directeur.journee), "celle du Directeur aussi")
end)

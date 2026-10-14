-- Essais du combat et des batailles (fiche 05_bataille.md).

local bataille = Scriptorium.bataille
local hommes = Scriptorium.hommes
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre

local function preparer(groschen, heure, roles)
  depart()
  FauxJeu.heure = heure or 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  camp.agrandir()
  camp.agrandir()
  coffre.encaisser(groschen or 1000, "butin")
  coffre.ajouter_reserve("vivres", 500, "achat")
  local ids = {}
  for _, role in ipairs(roles or {}) do
    table.insert(ids, hommes.embaucher({ role = role, semaines = 8, prime = 0 }))
  end
  Scriptorium.bandeau.remettre_a_zero()
  return ids
end

local function messages()
  local vus = {}
  Scriptorium.bandeau.battre()
  while Scriptorium.bandeau.en_cours() or Scriptorium.bandeau.en_attente() > 0 do
    table.insert(vus, FauxJeu.en_ecran)
    FauxJeu.avancer(10)
    Scriptorium.bandeau.battre()
  end
  return vus
end

local function contient(liste, valeur)
  for _, v in ipairs(liste) do
    if v == valeur then return true end
  end
  return false
end

essai("bataille : lever une bande, et les refus", function()
  depart()
  local ok, raison = bataille.lever_une_bande({ sorte = "brigands", effectif = 5, direction = 90 })
  egal(raison, "camp_absent", "sans camp")
  preparer(100, 10)
  ok, raison = bataille.lever_une_bande({ sorte = "dragons", effectif = 5, direction = 90 })
  egal(raison, "sorte_inconnue", "sorte")
  ok, raison = bataille.lever_une_bande({ sorte = "brigands", effectif = 0, direction = 90 })
  egal(raison, "effectif_invalide", "effectif nul")
  ok, raison = bataille.lever_une_bande({ sorte = "brigands", effectif = 61, direction = 90 })
  egal(raison, "effectif_invalide", "effectif trop grand")
  ok, raison = bataille.lever_une_bande({ sorte = "brigands", effectif = 5 })
  egal(raison, "direction_invalide", "direction")
  ok, raison = bataille.lever_une_bande({ sorte = "brigands", effectif = 5, direction = 90, delai = -1 })
  egal(raison, "delai_invalide", "délai")
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 5, direction = 450 })
  egal(id, "bande_1", "identifiant")
  local b = bataille.bande(id)
  egal(b.etat, "en_marche", "en marche")
  egal(b.arrivee, 12, "arrivée dans deux heures")
  egal(b.direction, 90, "direction normalisée")
  egal(#bataille.bandes(), 1, "une bande en cours")
end)

essai("bataille : avertissement une heure avant, arrivée, ennemis, affectations et ordres", function()
  local ids = preparer(1000, 10, { "homme_d_armes", "pavoisier", "arbaletrier", "archer", "cuisinier" })
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 4, direction = 0 })
  FauxJeu.heure = 10.5
  local rapport = bataille.battre()
  egal(rapport.annoncees, 0, "trop tôt pour prévenir")
  FauxJeu.heure = 11
  rapport = bataille.battre()
  egal(rapport.annoncees, 1, "prévenu une heure avant")
  verifier(contient(messages(), "@ui_scriptorium_bataille_approche"), "annoncé")
  egal(FauxJeu.affichages[1].complement, "4 hommes", "avec l'effectif")
  FauxJeu.heure = 12
  FauxJeu.ordres = {}
  rapport = bataille.battre()
  egal(rapport.arrivees, 1, "arrivée")
  local b = bataille.bande(id)
  egal(b.etat, "au_contact", "au contact")
  egal(b.ennemis, 4, "quatre ennemis dans le jeu")
  egal(FauxJeu.ennemis[1].sorte, "brigands", "sorte demandée au jeu")
  verifier(math.abs(FauxJeu.ennemis[1].position.y - 60) < 0.01, "arrivés à soixante mètres au nord")
  egal(#b.combattants, 4, "quatre combattants ; le cuisinier reste au feu")
  egal(hommes.activite_de(ids[1], 12).activite, "bataille", "affecté à la bataille")
  egal(hommes.activite_de(ids[5], 12).activite, "repas", "le cuisinier suit sa journée (midi : repas)")
  hommes.battre()
  local ordres_bataille = 0
  for _, o in ipairs(FauxJeu.ordres) do
    if o.activite == "bataille" then ordres_bataille = ordres_bataille + 1 end
  end
  egal(ordres_bataille, 4, "quatre ordres de bataille")
end)

essai("bataille : ordre de bataille, rangs, intervalles, ailes et réserve", function()
  local ids = preparer(1000, 10, { "homme_d_armes", "pavoisier", "homme_d_armes", "arbaletrier", "archer", "archer", "archer", "barbier" })
  hommes.blesser(ids[3], 2)
  local ordre = bataille.ordre_de_bataille(0)
  egal(#ordre.avant, 2, "deux au rang avant (le troisième est blessé)")
  egal(#ordre.arriere, 4, "quatre tireurs")
  egal(#ordre.reserve, 2, "le blessé et le barbier en réserve")
  verifier(math.abs(ordre.avant[1].position.y - 10) < 0.01, "rang avant à dix mètres")
  verifier(math.abs(ordre.arriere[1].position.y - 7) < 0.01, "rang arrière à sept mètres")
  -- Les x du rang avant : -0,6 et 0,6 ; l'intervalle est en 0 ; les suivants débordent sur les ailes.
  egal(ordre.arriere[1].x, 0, "premier tireur dans l'intervalle")
  for _, tireur in ipairs(ordre.arriere) do
    for _, devant in ipairs(ordre.avant) do
      verifier(math.abs(tireur.x - devant.x) > 0.5, "ligne de tir : jamais juste derrière un homme du rang avant")
    end
  end
  verifier(ordre.arriere[2].x < -1.2, "deuxième tireur sur l'aile gauche")
  verifier(ordre.arriere[3].x > 1.2, "troisième tireur sur l'aile droite")
  -- Face à l'est, le rang avant est à l'est du camp.
  local est = bataille.ordre_de_bataille(90)
  verifier(math.abs(est.avant[1].position.x - 10) < 0.01, "tourné vers la menace")
end)

essai("bataille : forces, moral et poids des sortes", function()
  local ids = preparer(1000, 10, { "homme_d_armes", "arbaletrier", "cuisinier" })
  -- moral 60 -> facteur 1,0 ; poids 3 + 2,5
  verifier(math.abs(bataille.force_des_notres() - 5.5) < 0.01, "force des nôtres")
  hommes.moral_pour_tous(40)
  verifier(math.abs(bataille.force_des_notres() - 5.5 * 1.2) < 0.01, "moral ardent : × 1,2")
  hommes.moral_pour_tous(-100)
  verifier(math.abs(bataille.force_des_notres() - 5.5 * 0.7) < 0.01, "moral abattu : × 0,7")
  egal(bataille.force_de_la_bande({ sorte = "coumans", effectif = 5 }), 7, "cinq Coumans")
  egal(bataille.force_de_la_bande({ sorte = "deserteurs", effectif = 5 }), 4, "cinq déserteurs")
end)

essai("bataille : la règle tranche quand le jeu ne fait pas venir la bande ; les quatre issues", function()
  local cas = {
    -- Force des nôtres : 3 + 3 + 2 + 2,5 + 2 = 12,5 (moral 60 : × 1).
    { effectif = 1, issue = "victoire" },
    { effectif = 10, issue = "victoire_couteuse" },
    { effectif = 15, issue = "repoussee" },
    { effectif = 20, issue = "defaite" },
  }
  for _, c in ipairs(cas) do
    local ids = preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "pavoisier", "arbaletrier", "archer" })
    FauxJeu.refuser_ennemis = true
    bataille.lever_une_bande({ sorte = "brigands", effectif = c.effectif, direction = 0, delai = 0 })
    local rapport = bataille.battre()
    egal(rapport.arrivees, 1, "arrivée")
    egal(rapport.finies, 1, "finie tout de suite par la règle")
    local resultats = bataille.resultats()
    egal(resultats[1].issue, c.issue, "issue pour " .. c.effectif .. " brigands")
    egal(#bataille.bandes(), 0, "plus de bande en cours")
    for _, id in ipairs(hommes.liste()) do
      egal(hommes.activite_de(id, 10).activite == "bataille", false, "affectation levée pour " .. id)
    end
  end
end)

essai("bataille : victoire, blessés et moral, butin partagé au livre", function()
  local ids = preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "pavoisier", "arbaletrier", "archer", "archer" })
  hommes.nommer_capitaine(ids[1])
  FauxJeu.refuser_ennemis = true
  bataille.lever_une_bande({ sorte = "coumans", effectif = 2, direction = 180, delai = 0 })
  bataille.battre()
  local r = bataille.resultats()[1]
  egal(r.issue, "victoire", "victoire")
  egal(r.morts, 0, "aucun mort")
  egal(r.blesses, 1, "15 % de six : un blessé")
  egal(r.butin, 24, "deux Coumans à douze")
  egal(r.part_coffre, 24 - 12 - 4, "le coffre garde le reste")
  local livre = coffre.livre(3)
  egal(livre[1].motif, "butin", "entrée du butin")
  egal(livre[2].motif, "part_hommes", "part des hommes")
  egal(livre[3].motif, "part_capitaine", "part du capitaine")
  egal(coffre.solde(), 1000 + 8, "solde du coffre")
  egal(hommes.fiche(ids[2]).moral, 70, "moral + 10")
  local blesses = hommes.effectif().blesses
  egal(blesses, 1, "un blessé sur les fiches")
  local vus = messages()
  verifier(contient(vus, "@ui_scriptorium_bataille_victoire"), "victoire annoncée")
  verifier(contient(vus, "@ui_scriptorium_bataille_butin"), "butin annoncé")
end)

essai("bataille : défaite, morts au rang avant, pillage du coffre, pas de butin", function()
  local ids = preparer(400, 10, { "homme_d_armes", "pavoisier", "archer", "archer" })
  FauxJeu.refuser_ennemis = true
  bataille.lever_une_bande({ sorte = "coumans", effectif = 30, direction = 0, delai = 0 })
  bataille.battre()
  local r = bataille.resultats()[1]
  egal(r.issue, "defaite", "défaite")
  verifier(r.morts >= 1, "au moins un mort")
  verifier(hommes.fiche(ids[1]) == nil, "l'homme d'armes du rang avant est tombé le premier")
  egal(r.butin, 0, "pas de butin")
  egal(r.pillage, 200, "la moitié du coffre pillée")
  egal(coffre.solde(), 200, "coffre réduit")
  egal(coffre.livre(1)[1].motif, "pillage", "ligne de pillage")
  egal(#hommes.anciens(), r.morts, "les morts sont dans les anciens")
  egal(hommes.anciens()[1].cause, "mort", "cause")
  verifier(hommes.fiche(ids[4]) == nil or hommes.fiche(ids[4]).moral == 45, "moral − 15 pour les survivants")
end)

essai("bataille : fin par le jeu, les ennemis tombent, nos morts sont ceux que le jeu dit", function()
  local ids = preparer(1000, 10, { "homme_d_armes", "pavoisier", "arbaletrier", "archer" })
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 0, delai = 0 })
  bataille.battre()
  egal(bataille.bande(id).etat, "au_contact", "au contact")
  FauxJeu.heure = 10.5
  local rapport = bataille.battre()
  egal(rapport.finies, 0, "le combat dure")
  -- Un des nôtres meurt, puis tous les ennemis tombent.
  FauxJeu.personnages_morts[hommes.fiche(ids[1]).personnage] = true
  for _, e in ipairs(FauxJeu.ennemis) do
    FauxJeu.ennemis_vivants_par_id[e.identifiant] = false
  end
  FauxJeu.heure = 11
  rapport = bataille.battre()
  egal(rapport.finies, 1, "finie")
  local r = bataille.resultats()[1]
  egal(r.issue, "victoire_couteuse", "un mort sur quatre : chèrement payée")
  egal(r.morts, 1, "le mort du jeu")
  egal(hommes.fiche(ids[1]), nil, "retiré")
  egal(#FauxJeu.ennemis_renvoyes, 3, "ennemis renvoyés")
  egal(r.butin, math.floor(3 * 8 * 0.6), "butin à 60 %")
end)

essai("bataille : fin par le jeu, tous nos combattants tombés, défaite", function()
  local ids = preparer(1000, 10, { "homme_d_armes", "archer", "cuisinier" })
  bataille.lever_une_bande({ sorte = "soudards", effectif = 6, direction = 0, delai = 0 })
  bataille.battre()
  FauxJeu.personnages_morts[hommes.fiche(ids[1]).personnage] = true
  FauxJeu.personnages_morts[hommes.fiche(ids[2]).personnage] = true
  FauxJeu.heure = 10.5
  bataille.battre()
  local r = bataille.resultats()[1]
  egal(r.issue, "defaite", "défaite")
  egal(r.morts, 2, "deux morts")
  verifier(hommes.fiche(ids[3]) ~= nil, "le cuisinier, au feu, vit encore")
end)

essai("bataille : après deux heures de contact sans fin, la règle tranche et renvoie les ennemis", function()
  preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "pavoisier", "arbaletrier" })
  local id = bataille.lever_une_bande({ sorte = "deserteurs", effectif = 2, direction = 270, delai = 1 })
  FauxJeu.heure = 11
  bataille.battre()
  FauxJeu.heure = 12.9
  egal(bataille.battre().finies, 0, "pas encore")
  FauxJeu.heure = 13
  egal(bataille.battre().finies, 1, "tranchée")
  egal(bataille.bande(id).etat, "finie", "finie")
  egal(bataille.bande(id).issue, "victoire", "deux déserteurs contre quatre : victoire")
  egal(#FauxJeu.ennemis_renvoyes, 2, "ennemis renvoyés")
end)

essai("bataille : la graine est gardée, deux parties identiques donnent les mêmes pertes", function()
  local function jouer()
    local ids = preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "pavoisier", "archer", "archer", "archer" })
    FauxJeu.refuser_ennemis = true
    bataille.lever_une_bande({ sorte = "soudards", effectif = 7, direction = 0, delai = 0 })
    bataille.battre()
    local r = bataille.resultats()[1]
    local blesses = {}
    for _, id in ipairs(hommes.liste()) do
      if hommes.fiche(id).blessure > 0 then table.insert(blesses, id .. ":" .. hommes.fiche(id).blessure) end
    end
    return r.issue .. "/" .. r.morts .. "/" .. table.concat(blesses, ",")
  end
  local a = jouer()
  local b = jouer()
  egal(a, b, "même déroulement")
end)

essai("bataille : le journal des batailles est borné, et tout est relu", function()
  preparer(100000, 10, { "homme_d_armes", "homme_d_armes", "pavoisier", "arbaletrier", "archer" })
  FauxJeu.refuser_ennemis = true
  for i = 1, bataille.reglages.journal_gardes + 2 do
    bataille.lever_une_bande({ sorte = "deserteurs", effectif = 1, direction = i * 10, delai = 0 })
    bataille.battre()
  end
  egal(#bataille.resultats(), bataille.reglages.journal_gardes, "borné")
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 45, delai = 5 })
  local chaine = FauxJeu.registre_stocke
  depart()
  FauxJeu.heure = 10
  FauxJeu.registre_stocke = chaine
  local b = bataille.bande(id)
  egal(b.etat, "en_marche", "bande relue")
  egal(b.arrivee, 15, "arrivée relue")
  egal(#bataille.resultats(), bataille.reglages.journal_gardes, "journal relu")
end)

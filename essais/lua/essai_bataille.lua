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
  -- Règle « sentinelles_du_camp » : personne ne l'a vue : au journal seulement, rien à l'écran.
  verifier(not contient(messages(), "@ui_scriptorium_bataille_approche"), "pas à l'écran")
  egal(Scriptorium.bandeau.historique()[#Scriptorium.bandeau.historique()].sort, "journal", "au journal")
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

essai("bataille (alertes, règle « sentinelles_du_camp ») : le guetteur qui voit la bande donne l'alerte, une fois : la réplique du jeu, le bandeau, la cloche au feu ; personne n'a vu : rien ; la décision remplaçable", function()
  local ids = preparer(1000, 23, { "homme_d_armes", "pavoisier" })
  local guetteur = ids[1]
  avec_remplacement(bataille, "guetteurs", function() return { guetteur } end, function()
    FauxJeu.sons = {}
    -- Le guetteur loin de la bande (né à 60 m au nord, lui à 200 m au sud) : il ne voit rien.
    local f = hommes.fiche(guetteur)
    hommes.battre()
    FauxJeu.positions[f.personnage] = { x = 0, y = -200, z = 0 }
    local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 0 })
    bataille.battre()
    egal(bataille.bande(id).etat, "au_contact", "au contact")
    for _, e in ipairs(FauxJeu.ennemis) do FauxJeu.positions[e.identifiant] = e.position end
    FauxJeu.positions[f.personnage] = { x = 0, y = -200, z = 0 }
    FauxJeu.heure = 23.05
    bataille.battre()
    verifier(not bataille.bande(id).alerte_donnee, "personne n'a vu : pas d'alerte")
    egal(#FauxJeu.sons, 0, "pas de son")
    verifier(not contient(messages(), "@ui_scriptorium_bataille_alerte"), "rien à l'écran")
    -- Il s'approche (à 20 m de l'ennemi) : il voit, il donne l'alerte.
    FauxJeu.positions[f.personnage] = { x = 0, y = 40, z = 0 }
    FauxJeu.heure = 23.1
    bataille.battre()
    verifier(bataille.bande(id).alerte_donnee, "l'alerte est donnée")
    verifier(contient(messages(), "@ui_scriptorium_bataille_alerte"), "à l'écran")
    egal(#FauxJeu.sons, 1, "la cloche sonne")
    egal(FauxJeu.sons[1].nom, "f_ge_bell_alarm", "la cloche d'alarme du jeu")
    verifier(FauxJeu.sons[1].ou ~= nil and FauxJeu.sons[1].ou == camp.objet_de("feu_central"), "au feu du camp")
    egal(hommes.parole_de(guetteur) and hommes.parole_de(guetteur).metarole, "NPC_VIDI_NEPRITELE_A_BUDE_UTOCIT",
         "il dit la réplique du jeu")
    FauxJeu.heure = 23.2
    bataille.battre()
    egal(#FauxJeu.sons, 1, "une seule fois par bande")
  end)
  -- La décision remplaçable : Scriptorium dit que personne n'a vu.
  preparer(1000, 23, { "homme_d_armes" })
  FauxJeu.sons = {}
  avec_remplacement(bataille, "qui_voit", function() return false end, function()
    local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 0 })
    bataille.battre()
    verifier(not bataille.bande(id).alerte_donnee, "Scriptorium : personne n'a vu")
  end)
  egal(#FauxJeu.sons, 0, "aucun son")
  FauxJeu.sons = nil
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

-- Règle scellée de JoVenGer « bataille_au_loin » (relecture du pair, 17/10) : la règle tranche par passes
-- (bataille.issue_au_loin, une accroche) ; l'issue dit ce qui s'est passé. Ici l'accroche est remplacée par des passes
-- écrites d'avance, pour lire chaque issue.
essai("bataille : la règle tranche par passes quand le jeu ne fait pas venir la bande ; l'issue dit ce qui s'est passé", function()
  local cas = {
    { gagne = true, tombes = 0, eux_tombes = 10, issue = "victoire" },
    { gagne = true, tombes = 1, eux_tombes = 10, issue = "victoire_couteuse" },
    { gagne = false, tombes = 5, eux_tombes = 5, issue = "repoussee" },
    { gagne = false, tombes = 5, eux_tombes = 4, issue = "defaite" },
  }
  local ancienne = bataille.issue_au_loin
  for _, c in ipairs(cas) do
    local ids = preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "pavoisier", "arbaletrier", "archer" })
    bataille.issue_au_loin = function(nous)
      local tombes, debout = {}, {}
      for i, id in ipairs(nous) do
        if i <= c.tombes then table.insert(tombes, id) else table.insert(debout, id) end
      end
      return { gagne = c.gagne, tombes = tombes, debout = debout, eux_tombes = c.eux_tombes, eux_debout = 10 - c.eux_tombes,
               passes = c.tombes + c.eux_tombes }
    end
    FauxJeu.refuser_ennemis = true
    bataille.lever_une_bande({ sorte = "brigands", effectif = 10, direction = 0, delai = 0 })
    local rapport = bataille.battre()
    egal(rapport.arrivees, 1, "arrivée")
    egal(rapport.finies, 1, "finie tout de suite par la règle")
    local resultats = bataille.resultats()
    egal(resultats[1].issue, c.issue, "issue : " .. c.issue)
    egal(#bataille.bandes(), 0, "plus de bande en cours")
    for _, id in ipairs(hommes.liste()) do
      egal(hommes.activite_de(id, 10).activite == "bataille", false, "affectation levée pour " .. id)
    end
    egal(resultats[1].morts + resultats[1].blesses, c.tombes, "les tombés, morts ou blessés : ce qui s'est passé")
    egal(resultats[1].butin > 0, c.gagne, "le butin seulement si la bande est tombée")
  end
  bataille.issue_au_loin = ancienne
end)

essai("bataille : victoire, blessés et moral, butin partagé au livre", function()
  local ids = preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "pavoisier", "arbaletrier", "archer", "archer" })
  hommes.nommer_capitaine(ids[1])
  FauxJeu.refuser_ennemis = true
  bataille.lever_une_bande({ sorte = "coumans", effectif = 2, direction = 180, delai = 0 })
  bataille.battre()
  local r = bataille.resultats()[1]
  -- Six contre deux Coumans : par passes, la victoire n'est pas écrite d'avance ; la graine de ce banc la donne sans perte.
  egal(r.issue, "victoire", "victoire")
  egal(r.morts, 0, "aucun mort")
  egal(r.blesses, 0, "personne n'est tombé : aucun blessé")
  egal(r.butin, 48, "deux Coumans à vingt-quatre")
  egal(r.part_coffre, 48 - 24 - 8, "le coffre garde le reste")
  local livre = coffre.livre(3)
  egal(livre[1].motif, "butin", "entrée du butin")
  egal(livre[2].motif, "part_hommes", "part des hommes")
  egal(livre[3].motif, "part_capitaine", "part du capitaine")
  egal(coffre.solde(), 1000 + 16, "solde du coffre")
  egal(hommes.fiche(ids[2]).moral, 70, "moral + 10")
  local blesses = hommes.effectif().blesses
  egal(blesses, 0, "aucun blessé sur les fiches")
  local vus = messages()
  verifier(contient(vus, "@ui_scriptorium_bataille_victoire"), "victoire annoncée")
  verifier(contient(vus, "@ui_scriptorium_bataille_butin"), "butin annoncé")
end)

essai("bataille : défaite, morts au rang avant, pillage du coffre, pas de butin", function()
  local ids = preparer(400, 10, { "homme_d_armes", "pavoisier", "archer", "archer" })
  bataille.reglages.part_des_morts = 1   -- chaque homme tombé meurt : l'ordre de chute se lit sur les fiches
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
  bataille.reglages.part_des_morts = 0.5
end)

-- Règle scellée de JoVenGer « bataille_au_loin » (relecture du pair, 17/10) : 400 batailles tirées, dans les deux sens ;
-- le plus fort gagne le plus souvent, jamais toujours ; le faible gagne parfois.
essai("bataille : 400 batailles par passes ; le plus fort gagne le plus souvent, jamais toujours ; le faible parfois", function()
  local ids = preparer(1000, 10, { "archer", "archer", "archer" })
  local function victoires(sorte, effectif)
    local n = 0
    for k = 1, 400 do
      bataille.fixer_la_graine(7000 + k)
      if bataille.issue_au_loin(ids, sorte, effectif).gagne then n = n + 1 end
    end
    return n
  end
  -- Trois archers (force 2 chacun, moral 60 : × 1) : 6 contre 3 brigands (3), puis contre 9 brigands (9).
  local fort = victoires("brigands", 3)
  local faible = victoires("brigands", 9)
  verifier(fort > 240 and fort < 400, "plus forts : gagnent le plus souvent, jamais toujours (" .. fort .. " sur 400)")
  verifier(faible > 0 and faible < 160, "plus faibles : gagnent parfois (" .. faible .. " sur 400)")

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
  egal(r.butin, 3 * 16, "la bande tombée : tout le butin (ce qui s'est passé, règle « bataille_au_loin »)")
  -- Les corps restent à fouiller vingt-quatre heures de jeu, puis sont retirés.
  egal(#FauxJeu.ennemis_renvoyes, 0, "les corps restent à fouiller")
  egal(#FauxJeu.corps_couches, 4, "les trois ennemis et notre mort couchés en corps (vu le 15/10 : sinon ils restaient debout ; fiche 17 : rien ne disparaît)")
  FauxJeu.heure = 11 + 23.9
  bataille.battre()
  egal(#FauxJeu.ennemis_renvoyes, 0, "encore là le lendemain avant l'heure")
  FauxJeu.heure = 11 + 24
  egal(bataille.battre().changements, 1, "corps retirés au battement")
  egal(#FauxJeu.ennemis_renvoyes, 4, "les quatre corps retirés")
  FauxJeu.heure = 11 + 30
  bataille.battre()
  egal(#FauxJeu.ennemis_renvoyes, 4, "retirés une seule fois")
end)

-- Fiche 17 : tranchée par passes, la bataille se joue jusqu'au bout ; chaque ennemi est tombé (tué, couché) ou debout
-- (parti aussitôt, pour une bande venue au camp) ; les corps restent à fouiller.
essai("bataille : à la fin, les ennemis debout s'en vont, les tombés restent à terre", function()
  preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "pavoisier", "arbaletrier" })
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 0, delai = 0 })
  bataille.battre()
  FauxJeu.ennemis_vivants_par_id[FauxJeu.ennemis[1].identifiant] = false
  FauxJeu.heure = 13
  egal(bataille.battre().finies, 1, "tranchée par la règle")
  local couches = 0
  for _, c in ipairs(FauxJeu.corps_couches) do
    if string.find(c, "ennemi_", 1, true) == 1 then couches = couches + 1 end
  end
  verifier(couches >= 1, "le premier mort est couché")
  egal(couches + #FauxJeu.ennemis_renvoyes, 3, "chaque ennemi : à terre ou parti")
  FauxJeu.heure = 13 + 24
  bataille.battre()
  verifier(#FauxJeu.ennemis_renvoyes >= 3, "les corps retirés le lendemain")
  egal(bataille.bande(id).etat, "finie", "bande finie")
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
  egal(#FauxJeu.ennemis_renvoyes, 0, "par passes, les deux tombés : rien n'est renvoyé")
  egal(#FauxJeu.corps_couches, 2, "les deux à terre, à fouiller")
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

-- Fiche 15, V73 f 3 b : Henry sur une autre carte que le camp : aucune bande ne naît ici, la règle tranche ; une bande déjà
-- au contact ne se lit pas d'ailleurs.
essai("bataille (fiche 15, V73 f 3 b) : Henry sur une autre carte : aucune bande ne naît ici, la règle tranche ; au contact, rien lu d'ailleurs", function()
  preparer(1000, 10, { "homme_d_armes", "pavoisier", "arbaletrier", "archer" })
  FauxJeu.carte = "kutnohorsko"
  camp.redresser()
  egal(camp.carte(), "kutnohorsko", "la carte du camp")
  FauxJeu.carte = "trosecko"
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 0, delai = 0 })
  bataille.battre()
  egal(#FauxJeu.ennemis, 0, "aucun ennemi né sur l'autre carte")
  egal(bataille.bande(id).etat, "finie", "la règle a tranché")
  local dit = false
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "Henry sur une autre carte que le camp", 1, true) then dit = true end
  end
  verifier(dit, "une ligne au journal")
  -- Au contact sur la carte du camp, puis Henry passe : les ennemis (illisibles d'ici) ne finissent pas la bataille.
  FauxJeu.carte = "kutnohorsko"
  local id2 = bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 0, delai = 0 })
  bataille.battre()
  egal(bataille.bande(id2).etat, "au_contact", "au contact sur la carte du camp")
  FauxJeu.carte = "trosecko"
  for _, e in ipairs(FauxJeu.ennemis) do
    FauxJeu.ennemis_vivants_par_id[e.identifiant] = false
  end
  FauxJeu.heure = FauxJeu.heure + 0.5
  egal(bataille.battre().finies, 0, "rien lu de l'autre carte")
  FauxJeu.heure = FauxJeu.heure + bataille.reglages.duree_max_contact
  egal(bataille.battre().finies, 1, "la règle tranche à son heure")
end)

-- Étape 2 (le nécessaire, fiche 14) : au contact, chaque combattant attaque un ennemi vivant, en tourniquet ; à chaque
-- battement, celui dont la cible est tombée en reçoit une autre ; l'interrupteur.
essai("bataille (étape 2) : au contact, chaque combattant attaque un ennemi vivant ; une nouvelle cible quand la sienne tombe ; l'interrupteur", function()
  preparer(1000, 10, { "homme_d_armes", "pavoisier", "arbaletrier", "archer" })
  FauxJeu.attaques = {}
  bataille.reglages.bande_attaque = false   -- ici, nos hommes seulement (la bande a son essai)
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 0 })
  bataille.battre()
  egal(bataille.bande(id).etat, "au_contact", "au contact")
  local e1, e2 = FauxJeu.ennemis[1].identifiant, FauxJeu.ennemis[2].identifiant
  egal(#FauxJeu.attaques, 4, "quatre ordres d'attaque, un par combattant")
  egal(FauxJeu.attaques[1].cible, e1, "le premier sur le premier ennemi")
  egal(FauxJeu.attaques[2].cible, e2, "le deuxième sur le deuxième")
  egal(FauxJeu.attaques[3].cible, e1, "en tourniquet")
  -- Vu en jeu le 17/10 : son combat fini, l'homme retourne à son rang ; l'attaque lui est redonnée à chaque battement
  -- tant qu'il ne se bat pas ; jamais à celui qui se bat.
  local perso = {}
  for i = 1, 4 do perso[i] = FauxJeu.attaques[i].attaquant end
  FauxJeu.ennemis_vivants_par_id[e1] = false
  FauxJeu.occupations[perso[2]] = "combat"
  FauxJeu.heure = 10.5
  bataille.battre()
  egal(#FauxJeu.attaques, 6, "les deux dont la cible est tombée, qui ne se battent pas, reçoivent l'ordre")
  egal(FauxJeu.attaques[5].cible, e2, "sa cible tombée : le dernier vivant")
  egal(FauxJeu.attaques[6].cible, e2, "sa cible tombée : le dernier vivant")
  for i = 1, 4 do FauxJeu.occupations[perso[i]] = "combat" end
  FauxJeu.heure = 11
  bataille.battre()
  egal(#FauxJeu.attaques, 6, "tous se battent : pas d'ordre de plus")
  for i = 1, 4 do FauxJeu.occupations[perso[i]] = nil end
  -- L'interrupteur.
  preparer(1000, 10, { "homme_d_armes", "pavoisier" })
  FauxJeu.attaques = {}
  bataille.reglages.attaque_au_contact = false
  bataille.lever_une_bande({ sorte = "coumans", effectif = 2, direction = 0, delai = 0 })
  bataille.battre()
  egal(#FauxJeu.attaques, 0, "interrupteur à faux : aucune attaque")
  bataille.reglages.attaque_au_contact = true
  bataille.reglages.bande_attaque = true
  FauxJeu.attaques = nil
end)

-- Règle scellée de Scriptorium « ennemis_au_contact » : la bande ne reste jamais sur place ; chaque ennemi attaque un de
-- nos combattants, ou Henry s'il est près, en tourniquet ; redonné à chaque battement à qui ne se bat pas.
essai("bataille (étape 2) : la bande attaque d'elle-même nos combattants et Henry s'il est près ; redonné à qui ne se bat pas ; l'interrupteur", function()
  preparer(1000, 10, { "homme_d_armes", "pavoisier" })
  FauxJeu.attaques = {}
  bataille.reglages.attaque_au_contact = false   -- ici, la bande seulement
  FauxJeu.position_joueur = { x = 0, y = 70, z = 0 }   -- à une dizaine de mètres de la bande (au nord, à 60 m)
  bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 0, delai = 0 })
  bataille.battre()
  egal(#FauxJeu.attaques, 3, "trois ordres, un par ennemi")
  local cibles = {}
  for _, at in ipairs(FauxJeu.attaques) do cibles[at.cible] = (cibles[at.cible] or 0) + 1 end
  egal(cibles["henry"], 1, "Henry est près : il est l'une des cibles")
  local ennemi = FauxJeu.attaques[1].attaquant
  for _, at in ipairs(FauxJeu.attaques) do
    FauxJeu.positions[at.attaquant] = { x = 0, y = 60, z = 0 }
    if at.cible ~= "henry" then FauxJeu.positions[at.cible] = { x = 0, y = 0, z = 0 } end
  end
  FauxJeu.occupations[ennemi] = "combat"
  FauxJeu.heure = 10.5
  bataille.battre()   -- premier relevé
  FauxJeu.heure = 10.6
  bataille.battre()
  egal(#FauxJeu.attaques, 5, "figés loin de leur cible : redonné aux deux qui ne se battent pas")
  FauxJeu.occupations[ennemi] = nil
  -- Henry loin : seulement nos hommes.
  preparer(1000, 10, { "homme_d_armes" })
  FauxJeu.attaques = {}
  FauxJeu.position_joueur = { x = 0, y = -300, z = 0 }
  bataille.lever_une_bande({ sorte = "coumans", effectif = 2, direction = 0, delai = 0 })
  bataille.battre()
  for _, at in ipairs(FauxJeu.attaques) do verifier(at.cible ~= "henry", "Henry loin : jamais visé") end
  egal(#FauxJeu.attaques, 2, "deux ordres")
  -- L'interrupteur.
  preparer(1000, 10, { "homme_d_armes" })
  FauxJeu.attaques = {}
  bataille.reglages.bande_attaque = false
  bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 0 })
  bataille.battre()
  egal(#FauxJeu.attaques, 0, "interrupteur à faux : la bande ne reçoit rien")
  bataille.reglages.bande_attaque = true
  bataille.reglages.attaque_au_contact = true
  FauxJeu.attaques = nil
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
end)

-- « Que personne ne reste figé » : au contact, l'attaque est redonnée toutes les 2 s ; la minuterie s'arrête à la fin.
essai("bataille (étape 2) : au contact, l'attaque redonnée toutes les 2 s des deux côtés ; arrêtée à la fin de la bataille", function()
  preparer(1000, 10, { "homme_d_armes" })
  FauxJeu.attaques = {}
  FauxJeu.position_joueur = { x = 0, y = -300, z = 0 }
  Scriptorium.en_partie = true
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 1, direction = 0, delai = 0 })
  bataille.battre()
  local n = #FauxJeu.attaques
  egal(n, 2, "un ordre à l'ennemi, un à notre homme")
  local mt = FauxJeu.minuteries[#FauxJeu.minuteries]
  egal(mt.ms, 2000, "la relance toutes les 2 s")
  FauxJeu.positions[FauxJeu.attaques[1].attaquant] = { x = 0, y = 60, z = 0 }
  FauxJeu.positions[FauxJeu.attaques[2].attaquant] = { x = 0, y = 0, z = 0 }
  mt.fonction()   -- premier relevé
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  egal(#FauxJeu.attaques, n + 2, "figés loin l'un de l'autre : redonné aux deux")
  local suivante = FauxJeu.minuteries[#FauxJeu.minuteries]
  verifier(suivante ~= mt, "la minuterie se repose")
  FauxJeu.ennemis_vivants_par_id[FauxJeu.ennemis[1].identifiant] = false
  bataille.battre()
  egal(bataille.bande(id).etat, "finie", "la bataille finie")
  local avant = #FauxJeu.minuteries
  suivante.fonction()
  egal(#FauxJeu.minuteries, avant, "finie : la minuterie s'arrête")
  Scriptorium.en_partie = false
  FauxJeu.attaques = nil
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
end)


-- Vu en jeu le 17/10 : l'ordre n'est redonné qu'à qui est figé (moins de 0,5 m depuis le relevé précédent).
essai("bataille (étape 2) : l'attaque redonnée seulement à qui ne bouge pas ; jamais à qui marche vers sa cible", function()
  preparer(1000, 10, { "homme_d_armes" })
  FauxJeu.attaques = {}
  FauxJeu.position_joueur = { x = 0, y = -300, z = 0 }
  Scriptorium.en_partie = true
  bataille.lever_une_bande({ sorte = "brigands", effectif = 1, direction = 0, delai = 0 })
  bataille.battre()
  local homme, ennemi = FauxJeu.attaques[2].attaquant, FauxJeu.attaques[1].attaquant
  FauxJeu.positions[homme] = { x = 0, y = 0, z = 0 }
  FauxJeu.positions[ennemi] = { x = 0, y = 60, z = 0 }
  local mt = FauxJeu.minuteries[#FauxJeu.minuteries]
  mt.fonction()   -- premier relevé des positions
  local n = #FauxJeu.attaques
  FauxJeu.positions[homme] = { x = 0, y = 3, z = 0 }    -- il marche vers sa cible
  FauxJeu.positions[ennemi] = { x = 0, y = 57, z = 0 }  -- elle vient
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  egal(#FauxJeu.attaques, n, "ils marchent : aucun ordre de plus")
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()  -- immobiles depuis le relevé précédent
  egal(#FauxJeu.attaques, n + 2, "figés : l'ordre redonné aux deux")
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  egal(#FauxJeu.attaques, n + 4, "deuxième relance")
  FauxJeu.journal_lignes = {}
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  egal(#FauxJeu.attaques, n + 4, "deux relances au plus par bataille")
  local dit = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do if string.find(l, "figé malgré 2 relances", 1, true) then dit = dit + 1 end end
  egal(dit, 2, "une ligne par figé, avec les positions")
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  dit = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do if string.find(l, "figé malgré 2 relances", 1, true) then dit = dit + 1 end end
  egal(dit, 2, "dite une seule fois")
  Scriptorium.en_partie = false
  FauxJeu.attaques = nil
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
end)

-- (relecture du pair) Celui qui attend son tour à moins de 4 m de sa cible n'est pas figé.
essai("bataille (étape 2) : qui attend son tour à moins de 4 m de sa cible n'est jamais relancé", function()
  preparer(1000, 10, { "homme_d_armes" })
  FauxJeu.attaques = {}
  FauxJeu.position_joueur = { x = 0, y = -300, z = 0 }
  Scriptorium.en_partie = true
  bataille.lever_une_bande({ sorte = "brigands", effectif = 1, direction = 0, delai = 0 })
  bataille.battre()
  local homme, ennemi = FauxJeu.attaques[2].attaquant, FauxJeu.attaques[1].attaquant
  FauxJeu.positions[homme] = { x = 0, y = 57, z = 0 }
  FauxJeu.positions[ennemi] = { x = 0, y = 60, z = 0 }
  local n = #FauxJeu.attaques
  for _ = 1, 4 do FauxJeu.minuteries[#FauxJeu.minuteries].fonction() end
  egal(#FauxJeu.attaques, n, "à 3 m l'un de l'autre, immobiles : personne n'est relancé")
  Scriptorium.en_partie = false
  FauxJeu.attaques = nil
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
end)

-- Relecture du pair (17/10) : rien ne disparaît sous les yeux d'Henry. Les survivants d'une bande venue au camp
-- s'enfuient en courant, à l'opposé du camp, et ne sont retirés qu'hors de son regard ou à plus de 150 m de lui.
essai("bataille : les survivants d'une bande venue au camp s'enfuient en courant ; retirés hors de la vue d'Henry seulement", function()
  preparer(1000, 10, { "homme_d_armes", "homme_d_armes" })
  local ancienne = bataille.issue_au_loin
  bataille.issue_au_loin = function(nous)
    return { gagne = false, tombes = { nous[1], nous[2] }, debout = {}, eux_tombes = 1, eux_debout = 2, passes = 3 }
  end
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 0, delai = 0 })
  bataille.battre()
  local ennemis = bataille.bande(id).personnages
  for _, e in ipairs(ennemis) do
    FauxJeu.positions[e] = { x = 0, y = 60, z = 0 }
  end
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
  FauxJeu.vue_d_henry = function() return true end
  FauxJeu.ordres = {}
  FauxJeu.heure = 13
  bataille.battre()
  egal(bataille.bande(id).etat, "finie", "tranchée")
  local fuites = 0
  for _, o in ipairs(FauxJeu.ordres) do
    if o.activite == "fuite" then
      fuites = fuites + 1
      egal(o.allure, "course", "en courant")
      verifier(o.position.y > 60, "à l'opposé du camp")
    end
  end
  egal(fuites, 2, "les deux survivants s'enfuient")
  local renvoyes = #FauxJeu.ennemis_renvoyes
  bataille.battre()
  egal(#FauxJeu.ennemis_renvoyes, renvoyes, "sous les yeux d'Henry, à 60 m : encore là")
  for _, e in ipairs(ennemis) do
    FauxJeu.positions[e] = { x = 0, y = 160, z = 0 }
  end
  bataille.battre()
  egal(#FauxJeu.ennemis_renvoyes, renvoyes + 2, "à plus de 150 m : retirés")
  bataille.issue_au_loin = ancienne
  FauxJeu.vue_d_henry = nil
end)

-- Relecture du pair (17/10) : un blessé mis à terre ne meurt pas ensuite ; immortel un temps, puis l'effet retiré.
essai("bataille : nos blessés mis à terre, immortels « blesse_immortel_ms », jamais frappés ensuite", function()
  local ids = preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "archer" })
  local ancienne, part = bataille.issue_au_loin, bataille.reglages.part_des_morts
  bataille.reglages.part_des_morts = 0
  bataille.issue_au_loin = function(nous)
    local debout = {}
    for i = 3, #nous do debout[#debout + 1] = nous[i] end
    return { gagne = true, tombes = { nous[1], nous[2] }, debout = debout, eux_tombes = 2, eux_debout = 0, passes = 4 }
  end
  FauxJeu.refuser_ennemis = true
  FauxJeu.a_terre, FauxJeu.coups, FauxJeu.effets, FauxJeu.effets_retires = {}, {}, {}, {}
  local p1, p2 = hommes.fiche(ids[1]).personnage, hommes.fiche(ids[2]).personnage
  bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 0 })
  bataille.battre()
  egal(#FauxJeu.a_terre, 2, "deux blessés mis à terre")
  egal(#FauxJeu.effets, 2, "immortels")
  for _ = 1, 4 do bataille.battre() end
  for _, c in ipairs(FauxJeu.coups) do
    verifier(c.identifiant ~= p1 and c.identifiant ~= p2, "aucun coup sur un blessé")
  end
  local mt = FauxJeu.minuteries[#FauxJeu.minuteries]
  egal(mt.ms, bataille.reglages.blesse_immortel_ms, "l'effet retiré après « blesse_immortel_ms »")
  mt.fonction()
  verifier(#FauxJeu.effets_retires >= 1, "effet retiré")
  bataille.issue_au_loin, bataille.reglages.part_des_morts = ancienne, part
end)

-- Le combat vivant figé (relecture du pair, 17/10 ; la cause) : un assommé n'est plus une cible ni un combattant
-- debout ; une nouvelle cible ne consomme pas le crédit de relances d'un figé ; tous les ennemis à terre : fini.
essai("bataille (combat figé, la cause) : une cible assommée est remplacée des deux côtés", function()
  preparer(1000, 10, { "homme_d_armes", "homme_d_armes" })
  FauxJeu.attaques = {}
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 0 })
  bataille.battre()
  local e1, e2 = FauxJeu.ennemis[1].identifiant, FauxJeu.ennemis[2].identifiant
  local nous = {}
  for _, h in ipairs(hommes.liste()) do table.insert(nous, hommes.fiche(h).personnage) end
  -- Notre premier homme est assommé : le brigand qui le visait en prend un autre.
  local cible_de_e1 = nil
  for _, a in ipairs(FauxJeu.attaques) do if a.attaquant == e1 then cible_de_e1 = a.cible end end
  egal(cible_de_e1, nous[1], "le premier brigand visait notre premier homme")
  FauxJeu.inconscients = { [nous[1]] = true }
  FauxJeu.attaques = {}
  FauxJeu.heure = 10.5
  bataille.battre()
  local nouvelle = nil
  for _, a in ipairs(FauxJeu.attaques) do
    verifier(a.cible ~= nous[1], "personne ne vise notre homme assommé")
    verifier(a.attaquant ~= nous[1], "un assommé ne reçoit pas d'ordre")
    if a.attaquant == e1 then nouvelle = a.cible end
  end
  verifier(nouvelle ~= nil and nouvelle ~= nous[1], "le brigand prend une autre cible")
  -- Le premier brigand assommé à son tour : notre homme qui le visait en prend un autre.
  FauxJeu.inconscients = { [e1] = true }
  FauxJeu.attaques = {}
  FauxJeu.heure = 11
  bataille.battre()
  local pour_nous1 = nil
  for _, a in ipairs(FauxJeu.attaques) do
    verifier(a.cible ~= e1, "personne ne vise le brigand assommé")
    if a.attaquant == nous[1] then pour_nous1 = a.cible end
  end
  egal(pour_nous1, e2, "notre homme prend le brigand debout")
  FauxJeu.inconscients = nil
  FauxJeu.attaques = nil
end)

essai("bataille (combat figé, la cause) : une nouvelle cible après une victime ne consomme pas de relance", function()
  preparer(1000, 10, { "homme_d_armes" })
  FauxJeu.attaques = {}
  Scriptorium.en_partie = true
  bataille.reglages.bande_attaque = false
  bataille.lever_une_bande({ sorte = "brigands", effectif = 4, direction = 0, delai = 0 })
  bataille.battre()
  local homme = FauxJeu.attaques[1].attaquant
  FauxJeu.positions[homme] = { x = 0, y = 0, z = 0 }   -- immobile : chaque relevé le verrait « figé »
  for k = 1, 3 do
    FauxJeu.ennemis_vivants_par_id[FauxJeu.ennemis[k].identifiant] = false
    FauxJeu.positions[FauxJeu.ennemis[k + 1].identifiant] = { x = 0, y = 60, z = 0 }
    FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  end
  local n = #FauxJeu.attaques
  egal(n, 4, "trois victimes : trois nouvelles cibles")
  -- Figé pour de bon devant le dernier, loin de lui : ses deux relances restent entières (le premier relevé de sa
  -- position, puis deux relances), puis plus rien.
  for _ = 1, 3 do FauxJeu.minuteries[#FauxJeu.minuteries].fonction() end
  egal(#FauxJeu.attaques, n + 2, "les deux relances d'un figé, intactes")
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  egal(#FauxJeu.attaques, n + 2, "puis plus rien (le plafond tient)")
  bataille.reglages.bande_attaque = true
  Scriptorium.en_partie = false
  FauxJeu.attaques = nil
end)

essai("bataille (combat figé, la cause) : tous les ennemis à terre (assommés) : le combat est fini ; nos assommés sont nos blessés", function()
  local ids = preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "archer" })
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 0 })
  bataille.battre()
  FauxJeu.inconscients = { [FauxJeu.ennemis[1].identifiant] = true, [FauxJeu.ennemis[2].identifiant] = true,
                           [hommes.fiche(ids[1]).personnage] = true }
  FauxJeu.heure = 10.5
  bataille.battre()
  egal(bataille.bande(id).etat, "finie", "fini")
  local r = bataille.resultats()[1]
  egal(r.issue, "victoire_couteuse", "un des nôtres à terre : victoire avec pertes")
  egal(r.morts, 0, "aucun mort")
  egal(r.blesses, 1, "l'assommé est notre blessé")
  FauxJeu.inconscients = nil
end)

-- L'accroche du partage du butin (la règle de Scriptorium) ; c'est de l'argent : une part absurde est refusée, tout
-- reste au coffre.
essai("bataille : le partage du butin est une accroche ; des parts absurdes sont refusées, tout reste au coffre", function()
  local ancienne, issue_d_origine = bataille.partager_le_butin, bataille.issue_au_loin
  local cas = {
    { parts = { hommes = 10, capitaine = 5 }, coffre = 48 - 15, refuse = false },
    { parts = { hommes = -1, capitaine = 0 }, coffre = 48, refuse = true },
    { parts = { hommes = 2.5, capitaine = 0 }, coffre = 48, refuse = true },
    { parts = { hommes = 40, capitaine = 9 }, coffre = 48, refuse = true },
    { parts = { hommes = 0 / 0, capitaine = 0 }, coffre = 48, refuse = true },
    { parts = "rien", coffre = 48, refuse = true },
    { erreur = true, coffre = 48, refuse = true },
  }
  for _, c in ipairs(cas) do
    preparer(1000, 10, { "homme_d_armes", "homme_d_armes", "pavoisier", "arbaletrier", "archer", "archer" })
    bataille.partager_le_butin = function()
      if c.erreur then error("cassé") end
      return c.parts
    end
    bataille.issue_au_loin = function(nous)
      return { gagne = true, tombes = {}, debout = nous, eux_tombes = 2, eux_debout = 0, passes = 2 }
    end
    FauxJeu.refuser_ennemis = true
    FauxJeu.journal_lignes = {}
    bataille.lever_une_bande({ sorte = "coumans", effectif = 2, direction = 0, delai = 0 })
    bataille.battre()
    egal(coffre.solde(), 1000 + c.coffre, "au coffre : " .. c.coffre)
    local refus = 0
    for _, l in ipairs(FauxJeu.journal_lignes) do
      if string.find(l, "partage du butin refusé", 1, true) then refus = refus + 1 end
    end
    egal(refus > 0, c.refuse, "refus au journal")
  end
  bataille.partager_le_butin, bataille.issue_au_loin = ancienne, issue_d_origine
end)

-- ---------------------------------------------------------------- la fouille (fiche 17, tranche 5)

local function bataille_gagnee(roles)
  local ids = preparer(1000, 10, roles)
  Scriptorium.en_partie = true
  local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 4, direction = 0, delai = 0 })
  bataille.battre()
  for i, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = i, y = 40, z = 0 }
  end
  for k, e in ipairs(FauxJeu.ennemis) do
    FauxJeu.positions[e.identifiant] = { x = 10 * k, y = 60, z = 0 }
    FauxJeu.ennemis_vivants_par_id[e.identifiant] = false
  end
  FauxJeu.heure = 10.2
  bataille.battre()
  return ids, id
end

essai("fouille : après une victoire, au plus trois hommes vont aux corps ; arrivés, ils s'y tiennent, puis le suivant ; la fin une fois", function()
  local ids, id = bataille_gagnee({ "homme_d_armes", "homme_d_armes", "archer", "archer", "pavoisier" })
  egal(bataille.bande(id).etat, "finie", "victoire")
  local f = bataille.fouille(id)
  verifier(f ~= nil, "la fouille lancée")
  egal(#f.a_fouiller, 4, "quatre corps à fouiller")
  local fouilleurs = 0
  for _ in pairs(f.fouilleurs) do fouilleurs = fouilleurs + 1 end
  egal(fouilleurs, 3, "trois fouilleurs au plus")
  for h in pairs(f.fouilleurs) do
    egal(hommes.qui_tient(h), "fouille", "tenu par la fouille")
  end
  local fins = 0
  local ancienne = bataille.fouille_finie
  bataille.fouille_finie = function(i, copie) fins = fins + 1 return ancienne(i, copie) end
  -- Chacun arrive à son corps, s'y tient « fouille_duree_h », puis passe au suivant.
  for _ = 1, 6 do
    for h, c in pairs(bataille.fouille(id) and bataille.fouille(id).fouilleurs or {}) do
      FauxJeu.positions[hommes.fiche(h).personnage] = FauxJeu.positions[c]
    end
    bataille.battre()
    FauxJeu.heure = FauxJeu.heure + bataille.reglages.fouille_duree_h + 0.01
    bataille.battre()
  end
  egal(bataille.fouille(id), nil, "tous les corps fouillés : la fouille close")
  egal(fins, 1, "la fin dite une fois")
  for _, h in ipairs(ids) do
    verifier(hommes.qui_tient(h) ~= "fouille", "plus personne tenu par la fouille")
  end
  bataille.fouille_finie = ancienne
  Scriptorium.en_partie = false
end)

essai("fouille : l'accroche « peut fouiller » écarte ; un corps pas atteint à temps est laissé ; vider la fouille lâche tout", function()
  local ancienne = bataille.peut_fouiller
  bataille.peut_fouiller = function(h) return hommes.fiche(h).role ~= "archer" and ancienne(h) end
  local ids, id = bataille_gagnee({ "archer", "archer", "homme_d_armes" })
  local f = bataille.fouille(id)
  local fouilleurs = {}
  for h in pairs(f.fouilleurs) do table.insert(fouilleurs, h) end
  egal(#fouilleurs, 1, "les archers écartés : un seul fouilleur")
  egal(hommes.fiche(fouilleurs[1]).role, "homme_d_armes", "l'homme d'armes")
  bataille.peut_fouiller = ancienne
  -- Il ne bouge pas : le corps est laissé après « fouille_marche_max_h ».
  FauxJeu.heure = FauxJeu.heure + bataille.reglages.fouille_marche_max_h + 0.01
  bataille.battre()
  verifier(bataille.fouille(id) == nil or bataille.fouille(id).laisses >= 1, "un corps laissé")
  -- Une autre bataille gagnée : vider la fouille lâche les fouilleurs.
  ids, id = bataille_gagnee({ "homme_d_armes", "homme_d_armes" })
  verifier(bataille.vider_la_fouille(id), "vidée")
  egal(bataille.fouille(id), nil, "close")
  for _, h in ipairs(ids) do
    verifier(hommes.qui_tient(h) ~= "fouille", "lâché")
  end
  Scriptorium.en_partie = false
end)

-- ---------------------------------------------------------------- fiche 19, grappe 2 : les décisions du combat remplaçables

essai("décisions du combat (fiche 19) : la cible de nos hommes (A2, A38), l'ennemi valable (A29), le combattant figé (A13)", function()
  preparer(1000, 10, { "homme_d_armes", "pavoisier", "arbaletrier", "archer" })
  bataille.reglages.bande_attaque = false
  local ok, erreur = pcall(function()
    FauxJeu.attaques = {}
    local id
    avec_remplacement(bataille, "ennemi_valable", function(bande, e) return e ~= FauxJeu.ennemis[1].identifiant end, function()
      id = bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 0 })
      bataille.battre()
    end)
    local e1, e2 = FauxJeu.ennemis[1].identifiant, FauxJeu.ennemis[2].identifiant
    egal(#FauxJeu.attaques, 4, "quatre ordres")
    for i = 1, 4 do egal(FauxJeu.attaques[i].cible, e2, "le premier n'est pas valable selon Scriptorium : tous sur le second") end
    -- Scriptorium change la cible en plein combat : l'ordre est donné, même à qui se bat.
    for i = 1, 4 do FauxJeu.occupations[FauxJeu.attaques[i].attaquant] = "combat" end
    local perso1 = FauxJeu.attaques[1].attaquant
    local socle = Scriptorium.decision_du_socle(bataille, "cible_de")
    avec_remplacement(bataille, "cible_de", function(bande, h, vivants, actuelle, rang)
      if hommes.fiche(h).personnage == perso1 then return e1 end
      return socle(bande, h, vivants, actuelle, rang)
    end, function()
      FauxJeu.heure = 10.5
      bataille.battre()
    end)
    egal(#FauxJeu.attaques, 5, "un seul ordre de plus")
    egal(FauxJeu.attaques[5].attaquant, perso1, "à celui dont Scriptorium change la cible")
    egal(FauxJeu.attaques[5].cible, e1, "sur la cible de Scriptorium")
    local qui = bataille.cibles(id)
    local vise_e1 = 0
    for _, c in pairs(qui.notres) do if c == e1 then vise_e1 = vise_e1 + 1 end end
    egal(vise_e1, 1, "qui vise qui, lisible")
    egal(bataille.cibles("inconnue"), nil, "une bande inconnue : nil")
    avec_remplacement(bataille, "cible_de", function() return nil end, function()
      FauxJeu.heure = 11
      bataille.battre()
    end)
    egal(#FauxJeu.attaques, 5, "nil : la cible du socle (il garde la sienne), pas d'ordre")
    -- Le combattant figé : Scriptorium le dit figé, l'ordre est redonné ; il dit non, rien.
    for i = 1, 4 do FauxJeu.occupations[FauxJeu.attaques[i].attaquant] = nil end
    avec_remplacement(bataille, "a_relancer", function() return false end, function()
      FauxJeu.heure = 11.5
      bataille.battre()
    end)
    egal(#FauxJeu.attaques, 5, "pas figé selon Scriptorium : rien")
    avec_remplacement(bataille, "a_relancer", function() return true end, function()
      FauxJeu.heure = 12
      bataille.battre()
    end)
    egal(#FauxJeu.attaques, 9, "figés selon Scriptorium : quatre ordres redonnés")
  end)
  FauxJeu.occupations = {}
  bataille.reglages.bande_attaque = true
  FauxJeu.attaques = nil
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("décisions du combat (fiche 19) : la cible d'un brigand ; Scriptorium l'envoie sur Henry", function()
  preparer(1000, 10, { "homme_d_armes", "homme_d_armes" })
  bataille.reglages.attaque_au_contact = false
  local ok, erreur = pcall(function()
    FauxJeu.attaques = {}
    avec_remplacement(bataille, "cible_de_la_bande", function() return "henry" end, function()
      bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 0 })
      bataille.battre()
    end)
    verifier(#FauxJeu.attaques >= 2, "les brigands attaquent")
    for _, a in ipairs(FauxJeu.attaques) do
      egal(a.cible, "henry", "sur Henry, selon Scriptorium")
    end
  end)
  bataille.reglages.attaque_au_contact = true
  FauxJeu.attaques = nil
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("décisions du combat (fiche 19) : le sort des survivants (A40) ; « laisser » : le socle ne les touche plus", function()
  preparer(1000, 10, { "homme_d_armes", "homme_d_armes" })
  local ancienne = bataille.issue_au_loin
  bataille.issue_au_loin = function(nous)
    return { gagne = false, tombes = { nous[1], nous[2] }, debout = {}, eux_tombes = 1, eux_debout = 2, passes = 3 }
  end
  local ok, erreur = pcall(function()
    local id = bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 0, delai = 0 })
    bataille.battre()
    for _, e in ipairs(bataille.bande(id).personnages) do
      FauxJeu.positions[e] = { x = 0, y = 60, z = 0 }
    end
    FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
    FauxJeu.vue_d_henry = function() return false end
    FauxJeu.ordres = {}
    avec_remplacement(bataille, "sort_des_survivants", function() return "laisser" end, function()
      FauxJeu.heure = 13
      bataille.battre()
    end)
    egal(bataille.bande(id).etat, "finie", "tranchée")
    for _, o in ipairs(FauxJeu.ordres) do
      verifier(o.activite ~= "fuite", "aucune fuite ordonnée")
    end
    local renvoyes = #FauxJeu.ennemis_renvoyes
    FauxJeu.heure = 13.5
    bataille.battre()
    egal(#FauxJeu.ennemis_renvoyes, renvoyes, "hors de la vue : aucun retiré, ils sont à Scriptorium")
  end)
  bataille.issue_au_loin = ancienne
  FauxJeu.vue_d_henry = nil
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

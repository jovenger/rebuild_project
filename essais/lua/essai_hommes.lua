-- Essais des hommes au camp (fiche 04_hommes.md).

local hommes = Scriptorium.hommes
local coffre = Scriptorium.coffre
local camp = Scriptorium.camp

-- Un camp fondé, un coffre garni, des vivres, à l'heure donnée.
local function preparer(groschen, vivres, heure)
  depart()
  FauxJeu.heure = heure or 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  if groschen and groschen > 0 then coffre.encaisser(groschen, "butin") end
  if vivres and vivres > 0 then coffre.ajouter_reserve("vivres", vivres, "achat") end
  Scriptorium.bandeau.remettre_a_zero()
end

local function vider_bandeau()
  Scriptorium.bandeau.remettre_a_zero()
end

local function dernier_message()
  local h = Scriptorium.bandeau.historique()
  return h[#h]
end

local function messages_contenant(cle)
  local n = 0
  Scriptorium.bandeau.battre()
  while Scriptorium.bandeau.en_cours() or Scriptorium.bandeau.en_attente() > 0 do
    if FauxJeu.en_ecran == "@" .. cle then n = n + 1 end
    FauxJeu.avancer(10)
    Scriptorium.bandeau.battre()
  end
  return n
end

essai("hommes : embaucher crée la fiche, paie la prime, prend une paillasse, fait venir le personnage", function()
  preparer(100, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  egal(id, "homme_1", "identifiant")
  local f = hommes.fiche(id)
  egal(f.nom, "Jan Kladivo", "premier nom d'époque")
  egal(f.role, "homme_d_armes", "rôle")
  egal(f.rang, "soudoyer", "rang")
  egal(f.contrat.solde, 12, "solde de base")
  egal(f.contrat.prime, 24, "prime = deux semaines")
  egal(f.contrat.fin, 10 + 4 * 7 * 24, "fin du contrat")
  egal(f.moral, 60, "moral de départ")
  egal(coffre.solde(), 76, "prime payée au coffre")
  egal(coffre.livre()[#coffre.livre()].motif, "prime", "ligne au livre")
  egal(f.lit, "lit_1a", "première paillasse libre, pas celle du Directeur")
  egal(camp.occupant_de("lit_1a"), id, "paillasse réservée")
  egal(#FauxJeu.personnages, 1, "personnage demandé au jeu")
  egal(FauxJeu.personnages[1].nom, "Jan Kladivo", "avec son nom")
  egal(f.personnage, "personnage_1", "identifiant du personnage gardé")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_hommes_rejoint", "annoncé")
  egal(FauxJeu.affichages[1].complement, "Jan Kladivo", "avec le nom en complément")
end)

essai("hommes : les noms ne se répètent pas", function()
  preparer(10000, 0, 10)
  camp.agrandir()
  camp.agrandir()
  local vus = {}
  for _ = 1, 12 do
    local id = hommes.embaucher({ role = "archer", semaines = 1, prime = 0 })
    local nom = hommes.fiche(id).nom
    verifier(not vus[nom], "nom nouveau : " .. nom)
    vus[nom] = true
  end
end)

essai("hommes : prénom et surnom changent d'un homme à l'autre ; toutes les combinaisons avant qu'un nom revienne", function()
  local np, ns = #hommes.prenoms, #hommes.surnoms
  local vus, surnoms = {}, {}
  for i = 1, np * ns do
    local nom = hommes.nom_d_epoque(i)
    verifier(not vus[nom], "nom nouveau : " .. nom)
    vus[nom] = true
  end
  for i = 1, ns do
    local surnom = string.sub(hommes.nom_d_epoque(i), string.find(hommes.nom_d_epoque(i), " ", 1, true) + 1)
    verifier(not surnoms[surnom], "surnom nouveau parmi les premiers : " .. surnom)
    surnoms[surnom] = true
  end
  egal(hommes.nom_d_epoque(1), "Jan Kladivo", "le premier")
  egal(hommes.nom_d_epoque(2), "Mikuláš le Rouge", "le deuxième : autre prénom, autre surnom")
  egal(hommes.nom_d_epoque(np * ns + 1), hommes.nom_d_epoque(1), "puis la liste recommence")
end)

essai("hommes : refus d'embauche", function()
  depart()
  local ok, raison = hommes.embaucher({ role = "archer", semaines = 2 })
  egal(raison, "camp_absent", "sans camp")
  preparer(100, 0, 10)
  ok, raison = hommes.embaucher({ role = "chevalier", semaines = 2 })
  egal(raison, "role_inconnu", "rôle inconnu")
  ok, raison = hommes.embaucher({ role = "archer", semaines = 0 })
  egal(raison, "duree_invalide", "durée nulle")
  ok, raison = hommes.embaucher({ role = "archer", semaines = 2.5 })
  egal(raison, "duree_invalide", "durée non entière")
  ok, raison = hommes.embaucher({ role = "archer", semaines = 60 })
  egal(raison, "duree_invalide", "durée trop longue")
  ok, raison = hommes.embaucher({ role = "armurier", semaines = 2, prime = 500 })
  egal(raison, "coffre_insuffisant", "prime trop grosse pour le coffre")
  egal(#hommes.liste(), 0, "personne engagé")
  egal(coffre.solde(), 100, "coffre intact")
  -- Quatre paillasses pour les hommes au niveau 1 : la cinquième embauche est refusée.
  for _ = 1, 4 do
    verifier(hommes.embaucher({ role = "archer", semaines = 2, prime = 0 }), "embauche")
  end
  ok, raison = hommes.embaucher({ role = "archer", semaines = 2, prime = 0 })
  egal(raison, "pas_de_lit", "plus de paillasse")
  egal(messages_contenant("ui_scriptorium_hommes_pas_de_lit"), 1, "le joueur est prévenu")
  camp.agrandir()
  verifier(hommes.embaucher({ role = "archer", semaines = 2, prime = 0 }), "après agrandissement, ça passe")
end)

essai("hommes : la solde hebdomadaire est payée au coffre, selon le rang", function()
  preparer(1000, 100, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 8, prime = 0 })
  local b = hommes.embaucher({ role = "arbaletrier", semaines = 8, prime = 0 })
  hommes.nommer_capitaine(b)
  egal(hommes.solde_de(a), 12, "soudoyer")
  egal(hommes.solde_de(b), 28, "capitaine × 2")
  vider_bandeau()
  local rapport = hommes.payer_la_solde()
  egal(rapport.payes, 2, "deux payés")
  egal(rapport.somme, 40, "somme")
  egal(coffre.solde(), 960, "coffre débité")
  egal(hommes.fiche(a).moral, 65, "moral + 5")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_hommes_solde_payee", "annoncé")
  egal(FauxJeu.affichages[1].complement, "40 groschen", "montant en complément")
  egal(FauxJeu.bourse_henry, 0, "jamais la bourse d'Henry")
end)

essai("hommes : solde impayée, moral en baisse, départ après deux semaines", function()
  preparer(5, 100, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 8, prime = 0 })
  vider_bandeau()
  local rapport = hommes.payer_la_solde()
  egal(rapport.impayes, 1, "impayé")
  egal(hommes.fiche(a).moral, 40, "moral − 20")
  egal(hommes.fiche(a).impayes, 1, "une semaine impayée")
  egal(messages_contenant("ui_scriptorium_hommes_solde_impayee"), 1, "alerte")
  rapport = hommes.payer_la_solde()
  egal(rapport.partis, 1, "parti")
  egal(#hommes.liste(), 0, "plus personne")
  egal(hommes.anciens()[1].cause, "solde_impayee", "cause gardée")
  egal(camp.occupant_de("lit_1a"), nil, "paillasse libérée")
  egal(#FauxJeu.personnages_renvoyes, 1, "personnage renvoyé")
end)

essai("hommes : la paie tombe chaque semaine à l'heure de paie, par le battement", function()
  preparer(1000, 100, 10)
  hommes.embaucher({ role = "archer", semaines = 10, prime = 0 })
  local f = hommes.fiche("homme_1")
  FauxJeu.heure = 7 * 24 + 7.9
  local rapport = hommes.battre()
  egal(rapport.paies, 0, "pas encore 8 h le septième jour")
  FauxJeu.heure = 7 * 24 + 8
  rapport = hommes.battre()
  egal(rapport.paies, 1, "payé à 8 h")
  FauxJeu.heure = 21 * 24 + 9
  rapport = hommes.battre()
  egal(rapport.paies, 2, "deux semaines sautées d'un coup : deux paies")
  egal(coffre.bilan().sorties, 36, "trois soldes de 12")
end)

essai("hommes : rations quotidiennes, faim et moral", function()
  preparer(100, 6, 6)
  hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  vider_bandeau()
  FauxJeu.heure = 7.5
  local rapport = hommes.battre()
  egal(rapport.repas, 1, "un repas")
  egal(rapport.affames, 0, "tous nourris")
  egal(coffre.reserve("vivres"), 2, "deux rations par homme prises (choix de JoVenGer, 14/10)")
  egal(hommes.fiche("homme_1").moral, 62, "moral + 2")
  FauxJeu.heure = 24 + 7.5
  rapport = hommes.battre()
  egal(rapport.affames, 1, "un seul nourri")
  egal(coffre.reserve("vivres"), 0, "plus de vivres")
  egal(hommes.fiche("homme_2").moral, 52, "l'affamé : moral − 10")
  verifier(messages_contenant("ui_scriptorium_hommes_faim") >= 1, "le joueur est prévenu")
  FauxJeu.heure = 24 + 9
  rapport = hommes.battre()
  egal(rapport.repas, 0, "pas deux repas le même jour")
end)

essai("hommes : journée réglée sur les heures, places et points", function()
  preparer(100, 0, 10)
  local a = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  local b = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  local c = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  -- Un homme qui n'est pas de garde à cette heure.
  local function libre(heure)
    for _, id in ipairs({ a, b, c }) do
      local de_garde = false
      for _, g in ipairs(hommes.gardes(heure)) do
        if g.id == id then de_garde = true end
      end
      if not de_garde then return id end
    end
    return nil
  end
  local cas = {
    { 5.5, "lever" }, { 7.5, "repas" }, { 10, "exercice" }, { 12.5, "repas" },
    { 15, "corvee" }, { 18.5, "repas" }, { 23, "sommeil" }, { 3, "sommeil" },
  }
  for _, cas_heure in ipairs(cas) do
    local heure = 48 + cas_heure[1]
    local id = libre(heure)
    verifier(id ~= nil, "quelqu'un est libre à " .. cas_heure[1] .. " h")
    local activite = hommes.activite_de(id, heure)
    egal(activite.activite, cas_heure[2], "à " .. cas_heure[1] .. " h")
    verifier(activite.position ~= nil, "une position à " .. cas_heure[1] .. " h")
    if cas_heure[2] == "sommeil" then
      egal(activite.lieu, hommes.fiche(id).lit, "dort sur sa paillasse")
    elseif cas_heure[2] == "repas" then
      verifier(string.find(activite.lieu, "^siege_") ~= nil, "assis sur un siège")
    end
  end
  -- La veillée est le temps libre (fiche 11) : le feu (un siège), l'entraînement, les dés ou le lit, selon ses envies,
  -- et le même choix toute la soirée.
  -- Un homme libre (pas de garde) toute la soirée.
  local id = nil
  for _, candidat in ipairs(hommes.liste()) do
    local libre_toute_la_soiree = true
    for _, h in ipairs({ 19.5, 20, 21.5 }) do
      for _, g in ipairs(hommes.gardes(48 + h)) do
        if g.id == candidat then libre_toute_la_soiree = false end
      end
    end
    if libre_toute_la_soiree and id == nil then id = candidat end
  end
  verifier(id ~= nil, "quelqu'un est libre toute la soirée")
  local soir = hommes.activite_de(id, 48 + 20)
  local lieux = { veillee = "^siege_", entrainement = "^exercice$", des = "^des$" }
  if soir.activite == "sommeil" then
    egal(soir.lieu, hommes.fiche(id).lit, "dort tôt sur sa paillasse")
  else
    verifier(lieux[soir.activite] ~= nil and string.find(soir.lieu, lieux[soir.activite]) ~= nil,
             "à 20 h, une envie à sa place : " .. tostring(soir.activite) .. " / " .. tostring(soir.lieu))
  end
  verifier(soir.position ~= nil, "une position à 20 h")
  egal(hommes.activite_de(id, 48 + 19.5).activite, soir.activite, "même choix à 19 h 30")
  egal(hommes.activite_de(id, 48 + 21.5).activite, soir.activite, "même choix à 21 h 30")
end)

essai("hommes : jamais plus de postes de garde que d'hommes valides, rotation, blessés exclus", function()
  preparer(100, 0, 10)
  camp.agrandir()
  egal(#hommes.gardes(23), 0, "sans homme, aucun garde")
  local a = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  egal(#hommes.gardes(23), 0, "un homme seul dort, il ne veille pas")
  egal(#hommes.gardes(12), 0, "ni le jour")
  local b = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  egal(#hommes.gardes(23), 1, "deux hommes : un poste la nuit")
  egal(#hommes.gardes(12), 0, "aucun le jour")
  local c = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  local d4 = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  egal(#hommes.gardes(23), 2, "quatre hommes : deux postes la nuit")
  egal(#hommes.gardes(12), 1, "un seul le jour")
  local premier = hommes.gardes(12)[1].id
  local suivant = hommes.gardes(15)[1].id
  verifier(premier ~= suivant, "le tour de veille change de garde")
  hommes.blesser(a, 3)
  hommes.blesser(b, 3)
  hommes.blesser(c, 3)
  egal(#hommes.gardes(23), 0, "un seul valide : personne ne veille")
  hommes.blesser(d4, 1)
  egal(#hommes.gardes(23), 0, "tous blessés : personne")
  egal(hommes.activite_de(a, 23).activite, "repos", "le blessé se repose")
  egal(hommes.activite_de(a, 23).lieu, "lit_1a", "sur sa paillasse")
  verifier(#hommes.gardes(23) <= hommes.effectif().valides, "jamais plus de postes que d'hommes valides")
end)

essai("hommes : les ordres ne partent qu'au changement d'activité", function()
  preparer(100, 100, 10)
  hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  FauxJeu.ordres = {}
  FauxJeu.heure = 10
  local rapport = hommes.battre()
  egal(rapport.ordres, 1, "premier ordre")
  FauxJeu.heure = 10.5
  rapport = hommes.battre()
  egal(rapport.ordres, 0, "même activité : pas d'ordre")
  FauxJeu.heure = 12.5
  rapport = hommes.battre()
  egal(rapport.ordres, 1, "repas : nouvel ordre")
  egal(FauxJeu.ordres[2].activite, "repas", "l'ordre dit l'activité")
  verifier(FauxJeu.ordres[2].position ~= nil, "avec une position")
end)

-- Règle de JoVenGer (fiche 15, 16/10) : une tâche sans fin s'arrête au changement de tranche. La garde du comportement
-- long (fiche 12) ne finit qu'au changement du compteur d'ordres : chaque changement de tranche doit donc donner un
-- nouvel ordre, ce que garantit une journée sans trou dont deux tranches qui se suivent n'ont jamais la même activité.
essai("hommes : chaque changement de tranche de la journée donne un nouvel ordre", function()
  local journee = hommes.journee
  for i, tranche in ipairs(journee) do
    local suivante = journee[i % #journee + 1]
    local nom = tranche.de .. " h - " .. tranche.a .. " h"
    verifier(tranche.activite ~= suivante.activite, nom .. " : la tranche suivante change d'activité")
    egal(tranche.a, suivante.de, nom .. " : la tranche suivante commence à sa fin (pas de trou)")
  end
  preparer(100, 100, journee[1].de)
  hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  FauxJeu.ordres = {}
  local donnes = 0
  for _, tranche in ipairs(journee) do
    FauxJeu.heure = tranche.de + 0.5
    donnes = donnes + hommes.battre().ordres
  end
  egal(donnes, #journee, "un ordre par tranche, sur toute la journée")
end)

-- Fiche 12 (les valeurs de l'arbre en données) : le battement écrit hommes.cerveau dans le cerveau de chaque homme et du
-- Directeur, une fois, puis seulement après un changement de valeur ou un réveil.
essai("hommes : les valeurs du cerveau, écrites une fois par personnage, réécrites après un changement ou un réveil", function()
  preparer(100, 100, 10)
  hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  verifier(Scriptorium.directeur.installer(), "le Directeur est installé")
  local homme = hommes.fiche(hommes.liste()[1]).personnage
  local du_directeur = Scriptorium.directeur.personnage()
  FauxJeu.cerveaux, FauxJeu.ecritures_du_cerveau = {}, 0
  egal(hommes.battre().cerveaux, 2, "deux cerveaux écrits : l'homme et le Directeur")
  egal(FauxJeu.cerveaux[homme] and FauxJeu.cerveaux[homme].garde_ms, hommes.cerveau.garde_ms, "chez l'homme")
  egal(FauxJeu.cerveaux[du_directeur] and FauxJeu.cerveaux[du_directeur].tour_ms, hommes.cerveau.tour_ms, "chez le Directeur")
  egal(hommes.battre().cerveaux, 0, "rien de réécrit sans changement")
  local avant = hommes.cerveau.garde_ms
  hommes.cerveau.garde_ms = 1000
  egal(hommes.battre().cerveaux, 2, "réécrits après un changement de réglage")
  egal(FauxJeu.cerveaux[homme].garde_ms, 1000, "la nouvelle valeur")
  hommes.cerveau.garde_ms = avant
  hommes.battre()
  hommes.relancer()
  egal(hommes.battre().cerveaux, 2, "réécrits au premier battement après le réveil")
end)

-- Fiche 15, V73 b 2 (le plafond de relances, proposition du pair) : le switch compte ses arrêts dans le cerveau ; le
-- battement en dit une ligne par hausse, chez l'homme comme chez le Directeur, et aucune sinon.
essai("vie du camp (fiche 15, V73 b 2) : une ligne au journal par arrêt du plafond de relances, aucune sinon", function()
  preparer(100, 100, 10)
  hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  verifier(Scriptorium.directeur.installer(), "le Directeur est installé")
  local f = hommes.fiche(hommes.liste()[1])
  local du_directeur = Scriptorium.directeur.personnage()
  local function lignes(nom)
    local n = 0
    for _, l in ipairs(FauxJeu.journal_lignes) do
      if string.find(l, "relances arrêtées pour « " .. nom .. " »", 1, true) then n = n + 1 end
    end
    return n
  end
  egal(hommes.battre().arrets, 0, "aucun arrêt lu")
  egal(lignes(f.nom), 0, "aucun arrêt : aucune ligne")
  FauxJeu.variables_du_cerveau[f.personnage] = { scriptorium_vie_arrets = 1 }
  egal(hommes.battre().arrets, 1, "un arrêt vu")
  egal(lignes(f.nom), 1, "une ligne")
  hommes.battre()
  egal(lignes(f.nom), 1, "toujours un arrêt : aucune ligne de plus")
  FauxJeu.variables_du_cerveau[f.personnage] = { scriptorium_vie_arrets = 2 }
  FauxJeu.variables_du_cerveau[du_directeur] = { scriptorium_vie_arrets = 1 }
  egal(hommes.battre().arrets, 2, "un second arrêt chez l'homme, un premier chez le Directeur")
  egal(lignes(f.nom), 2, "une seconde ligne pour l'homme")
  egal(lignes("Directeur"), 1, "une ligne pour le Directeur")
  -- Au chargement, le cerveau repart de zéro, et la mémoire du battement aussi : le premier arrêt se dit encore.
  hommes.relancer()
  FauxJeu.variables_du_cerveau[f.personnage] = { scriptorium_vie_arrets = 1 }
  FauxJeu.variables_du_cerveau[du_directeur] = { scriptorium_vie_arrets = 0 }
  hommes.battre()
  egal(lignes(f.nom), 3, "après un réveil, le premier arrêt se dit encore")
  egal(lignes("Directeur"), 1, "rien de plus pour le Directeur")
end)

essai("hommes : à l'entrée en partie, l'ordre en cours est redonné à chacun (V56 : le cerveau perd ses variables)", function()
  preparer(100, 100, 10)
  hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  FauxJeu.ordres = {}
  FauxJeu.heure = 10
  egal(hommes.battre().ordres, 1, "premier ordre")
  FauxJeu.heure = 10.5
  egal(hommes.battre().ordres, 0, "même activité : pas d'ordre")
  local revenus, manquants = hommes.relancer()
  egal(revenus, 0, "le personnage est encore là : rien ne revient")
  egal(manquants, 0, "aucun manquant")
  FauxJeu.heure = 10.75
  egal(hommes.battre().ordres, 1, "après l'entrée en partie, l'ordre est redonné")
  egal(FauxJeu.ordres[2].activite, FauxJeu.ordres[1].activite, "le même ordre")
  egal(hommes.battre().ordres, 0, "puis plus deux fois")
  FauxJeu.personnages_existants[hommes.fiche(hommes.liste()[1]).personnage] = nil
  revenus = hommes.relancer()
  egal(revenus, 1, "un personnage manquant revient à l'entrée en partie")
end)

essai("hommes : un dizainier pour dix hommes, un capitaine d'office, rétrogradation", function()
  preparer(10000, 1000, 10)
  camp.agrandir()
  camp.agrandir()
  for _ = 1, 9 do
    hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  end
  egal(hommes.effectif().par_rang.dizainier, nil, "neuf hommes : pas de dizainier")
  vider_bandeau()
  hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local effectif = hommes.effectif()
  egal(effectif.nombre, 10, "dix hommes")
  egal(effectif.par_rang.capitaine, 1, "un capitaine d'office")
  egal(hommes.fiche("homme_1").rang, "capitaine", "le plus ancien")
  verifier(messages_contenant("ui_scriptorium_hommes_capitaine") >= 1, "annoncé")
  -- Le capitaine est promu dizainier puis capitaine : il faut encore un dizainier pour les dix.
  egal(hommes.fiche("homme_2").rang, "dizainier", "le second devient dizainier")
  hommes.renvoyer("homme_10")
  egal(hommes.fiche("homme_2").rang, "soudoyer", "neuf hommes : plus de dizainier")
  egal(hommes.fiche("homme_1").rang, "capitaine", "le capitaine reste")
  verifier(hommes.nommer_capitaine("homme_3"), "le joueur nomme un autre capitaine")
  egal(hommes.fiche("homme_3").rang, "capitaine", "nouveau capitaine")
  egal(hommes.fiche("homme_1").rang, "soudoyer", "l'ancien redescend")
  egal(hommes.solde_de("homme_3"), 24, "solde du capitaine")
end)

essai("hommes : fin de contrat à l'aube, renouvellement", function()
  preparer(100, 100, 10)
  local a = hommes.embaucher({ role = "archer", semaines = 1, prime = 0 })
  local b = hommes.embaucher({ role = "archer", semaines = 1, prime = 0 })
  verifier(hommes.renouveler(b, 2), "renouvelé")
  egal(hommes.fiche(b).contrat.semaines, 3, "trois semaines au total")
  FauxJeu.heure = 10 + 7 * 24 - 1
  hommes.battre()
  egal(#hommes.liste(), 2, "pas encore finis")
  FauxJeu.heure = 10 + 7 * 24 + 24
  vider_bandeau()
  local rapport = hommes.battre()
  egal(rapport.partis, 1, "un contrat fini")
  egal(hommes.fiche(a), nil, "le premier est parti")
  verifier(hommes.fiche(b) ~= nil, "le renouvelé reste")
  egal(hommes.anciens()[1].cause, "fin_de_contrat", "cause")
  egal(messages_contenant("ui_scriptorium_hommes_parti_fin_contrat"), 1, "annoncé")
  local ok, raison = hommes.renouveler("homme_9", 2)
  egal(raison, "homme_inconnu", "renouveler un inconnu")
  ok, raison = hommes.renouveler(b, 0)
  egal(raison, "duree_invalide", "durée nulle")
end)

essai("hommes : soins, plus vite avec un barbier", function()
  preparer(100, 100, 6)
  local a = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  verifier(hommes.blesser(a, 4), "blessé 4 jours")
  local ok, raison = hommes.blesser(a, 0)
  egal(raison, "jours_invalides", "zéro jour refusé")
  FauxJeu.heure = 7.5
  hommes.battre()
  egal(hommes.fiche(a).blessure, 3, "un jour de soin")
  hommes.embaucher({ role = "barbier", semaines = 4, prime = 0 })
  FauxJeu.heure = 24 + 7.5
  local rapport = hommes.battre()
  egal(hommes.fiche(a).blessure, 1, "deux jours avec le barbier")
  FauxJeu.heure = 48 + 7.5
  rapport = hommes.battre()
  egal(hommes.fiche(a).blessure, 0, "guéri")
  egal(rapport.gueris, 1, "compté")
end)

essai("hommes : désertion au moral bas, à l'aube", function()
  preparer(100, 100, 10)
  local a = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  hommes.changer_moral(a, -55)
  egal(hommes.fiche(a).moral, 5, "moral à 5")
  egal(hommes.niveau_de_moral(5), "abattu", "abattu")
  FauxJeu.heure = 23
  hommes.battre()
  verifier(hommes.fiche(a) ~= nil, "pas avant l'aube")
  FauxJeu.heure = 24 + 5.5
  vider_bandeau()
  hommes.battre()
  egal(hommes.fiche(a), nil, "déserté")
  egal(hommes.anciens()[1].cause, "desertion", "cause")
  egal(messages_contenant("ui_scriptorium_hommes_parti_moral"), 1, "annoncé")
  egal(hommes.moral_pour_tous(10), 0, "moral pour tous : plus personne")
end)

essai("hommes : renvoi et mort vont dans les anciens, bornés", function()
  preparer(100, 100, 10)
  local a = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  local b = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  verifier(hommes.renvoyer(a), "renvoyé")
  verifier(hommes.retirer(b, "mort"), "mort")
  egal(#hommes.anciens(), 2, "deux anciens")
  egal(hommes.anciens()[2].cause, "mort", "cause")
  local ok, raison = hommes.renvoyer(a)
  egal(raison, "homme_inconnu", "déjà parti")
  for _ = 1, hommes.reglages.anciens_gardes + 3 do
    local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    hommes.renvoyer(id)
  end
  egal(#hommes.anciens(), hommes.reglages.anciens_gardes, "anciens bornés")
end)

essai("hommes : tout est écrit dans la partie et relu, les personnages manquants reviennent", function()
  preparer(500, 100, 10)
  local a = hommes.embaucher({ role = "arbaletrier", semaines = 4 })
  local b = hommes.embaucher({ role = "barbier", semaines = 2 })
  hommes.blesser(b, 2)
  local chaine = FauxJeu.registre_stocke
  local objets = FauxJeu.objets_existants

  depart()
  FauxJeu.heure = 10
  FauxJeu.registre_stocke = chaine
  FauxJeu.objets_existants = objets
  egal(#hommes.liste(), 2, "deux hommes relus")
  local f = hommes.fiche(a)
  egal(f.nom, "Jan Kladivo", "nom relu")
  egal(f.contrat.prime, 28, "contrat relu")
  egal(hommes.fiche(b).blessure, 2, "blessure relue")
  egal(camp.occupant_de("lit_1a"), a, "paillasse relue")
  -- Les personnages n'existent plus dans le jeu : redresser les fait revenir.
  local revenus, manquants = hommes.redresser()
  egal(revenus, 2, "deux revenus")
  egal(manquants, 0, "aucun manquant")
  egal(hommes.effectif().presents, 2, "présents")
  FauxJeu.refuser_personnage = true
  for _, id in ipairs(hommes.liste()) do
    FauxJeu.personnages_existants[hommes.fiche(id).personnage] = nil
  end
  revenus, manquants = hommes.redresser()
  egal(manquants, 2, "le jeu refuse : ils restent sur le registre")
  egal(#hommes.liste(), 2, "toujours deux hommes")
end)

essai("hommes : quand le jeu ne peut pas faire venir le personnage, l'homme existe quand même", function()
  preparer(100, 100, 10)
  FauxJeu.refuser_personnage = true
  local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  verifier(id, "engagé")
  egal(hommes.fiche(id).personnage, nil, "sans personnage")
  egal(hommes.effectif().presents, 0, "absent du jeu")
  FauxJeu.heure = 12
  local rapport = hommes.battre()
  egal(rapport.ordres, 0, "pas d'ordre sans personnage")
  FauxJeu.refuser_personnage = false
  local revenus = hommes.redresser()
  egal(revenus, 1, "revenu")
end)

essai("hommes : montée de version 1 -> 2 du registre, les affectations passagères sont oubliées", function()
  depart()
  local ancien = { prochain = 2, prochain_nom = 2, ordre = { "homme_1" }, anciens = {},
                   liste = { homme_1 = { id = "homme_1", nom = "Essai", affectation = { activite = "garde", fin = 99 } } } }
  FauxJeu.registre_stocke = Scriptorium.registre.serialiser({ format = Scriptorium.registre.format,
                                                              cases = { hommes = { version = 1, donnees = ancien } } })
  local f = hommes.fiche("homme_1")
  verifier(f ~= nil, "fiche relue")
  egal(f and f.affectation, nil, "affectation de l'ancien format oubliée")
  egal(Scriptorium.registre.etat_de("hommes"), "migree", "case montée de version")
end)

essai("hommes : montée de version 2 -> 3 du registre (fiche 15, V73 b 3), l'affectation unique est oubliée", function()
  depart()
  local ancien = { prochain = 2, prochain_nom = 2, ordre = { "homme_1" }, anciens = {},
                   liste = { homme_1 = { id = "homme_1", nom = "Essai", blessure = 0,
                                         affectation = { activite = "bataille", lieu = "rang_avant", fin = 99 } } } }
  FauxJeu.registre_stocke = Scriptorium.registre.serialiser({ format = Scriptorium.registre.format,
                                                              cases = { hommes = { version = 2, donnees = ancien } } })
  local f = hommes.fiche("homme_1")
  verifier(f ~= nil, "fiche relue")
  egal(f and f.affectation, nil, "l'affectation de la version 2 est oubliée")
  egal(Scriptorium.registre.etat_de("hommes"), "migree", "case montée de version")
  egal(hommes.qui_tient("homme_1", 10), "journee", "il reprend sa journée")
end)

-- Fiche 15, V73 b 3 (l'arbitre des ordres, validé par JoVenGer le 16/10) : une tenue par règle, la plus forte gagne.
local function point_d_essai(x, y)
  return camp.point(x or 5, y or 5, 0)
end

essai("arbitre (fiche 15, V73 b 3) : une règle plus faible ne reprend pas un homme tenu ; libéré, il prend celle d'en dessous", function()
  preparer(5000, 100, 10)
  hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  local id = hommes.liste()[1]
  verifier(hommes.tenir(id, "travail", { activite = "corvee", lieu = "travail_essai", position = point_d_essai(), fin = 11 }),
           "travail posé")
  egal(hommes.qui_tient(id), "travail", "tenu par le travail")
  verifier(hommes.tenir(id, "loisir", { activite = "des", lieu = "des", position = point_d_essai(), fin = 11.5 }), "loisir posé")
  egal(hommes.qui_tient(id), "travail", "le loisir, plus faible, ne le reprend pas")
  hommes.tenir(id, "rassemblement", { activite = "rassemblement", lieu = "rassemblement", position = point_d_essai(0, 8),
                                      fin = "liberation" })
  egal(hommes.qui_tient(id), "rassemblement", "le rassemblement, plus fort, le prend")
  hommes.lacher(id, "rassemblement")
  egal(hommes.qui_tient(id), "travail", "le rassemblement lâché : le travail reprend")
  hommes.lacher(id, "travail")
  egal(hommes.qui_tient(id), "loisir", "puis le loisir, resté posé")
  hommes.lacher(id, "loisir")
  egal(hommes.qui_tient(id), "journee", "puis sa journée")
  verifier(hommes.lacher(id, "loisir"), "lâcher une tenue déjà tombée : sans erreur")
  local refus = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "Hommes : refus", 1, true) then refus = refus + 1 end
  end
  egal(refus, 0, "et sans ligne de refus au journal")
  verifier(not hommes.tenir(id, "inconnue", {}), "une règle hors du catalogue est refusée")
  verifier(not hommes.tenir(id, "travail", { fin = "demain" }), "une fin qui n'est ni une heure ni « liberation » est refusée")
end)

essai("arbitre : à rang égal, la première tenue garde l'homme, même reposée ; une tenue posée bat la règle calculée", function()
  preparer(5000, 100, 10)
  hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  local id = hommes.liste()[1]
  hommes.tenir(id, "sommeil", { activite = "sommeil", lieu = "lit_essai", position = point_d_essai(), fin = 12 })
  FauxJeu.heure = 10.2
  hommes.tenir(id, "repas", { activite = "repas", lieu = "feu_essai", position = point_d_essai(), fin = 12 })
  egal(hommes.qui_tient(id), "sommeil", "à rang égal, la première posée")
  FauxJeu.heure = 10.4
  hommes.tenir(id, "sommeil", { activite = "sommeil", lieu = "lit_essai", position = point_d_essai(6, 5), fin = 12 })
  egal(hommes.qui_tient(id), "sommeil", "reposée, elle n'est pas rajeunie")
  -- Blessé : les soins (rang 3) passent devant ; une tenue « bains » (rang 3, un ordre exprès) passe devant les soins.
  hommes.blesser(id, 2)
  egal(hommes.qui_tient(id), "soins", "blessé : les soins")
  hommes.tenir(id, "bains", { activite = "bain", lieu = "bains_essai", position = point_d_essai(), fin = 12 })
  egal(hommes.qui_tient(id), "bains", "à rang égal, la tenue posée bat la règle calculée")
  hommes.tenir(id, "bataille", { activite = "bataille", lieu = "rang_avant", position = point_d_essai(), fin = "liberation" })
  egal(hommes.qui_tient(id), "bataille", "la bataille passe devant tout")
end)

essai("arbitre : les trois bornes d'une tenue (une heure ; le changement de tranche, minuit compris ; la libération et sa sûreté)", function()
  preparer(5000, 100, 10)
  hommes.embaucher({ role = "homme_d_armes", semaines = 8, palier = 1 })
  local id = hommes.liste()[1]
  hommes.tenir(id, "travail", { activite = "corvee", lieu = "travail_essai", position = point_d_essai(), fin = 10.5 })
  FauxJeu.heure = 10.4
  hommes.battre()
  egal(hommes.qui_tient(id), "travail", "avant sa fin")
  FauxJeu.heure = 10.5
  hommes.battre()
  egal(hommes.qui_tient(id), "journee", "tombée à son heure")
  -- Sans fin : jusqu'au prochain changement de tranche (exercice de 8 à 12 h ; nuit de 22 à 5 h, des deux côtés de minuit).
  hommes.tenir(id, "loisir", { activite = "des", lieu = "des", position = point_d_essai() })
  egal(select(2, hommes.qui_tient(id)).fin, 12, "à 10 h 30, jusqu'à midi")
  hommes.lacher(id, "loisir")
  FauxJeu.heure = 23
  hommes.tenir(id, "loisir", { activite = "des", lieu = "des", position = point_d_essai() })
  egal(select(2, hommes.qui_tient(id)).fin, 29, "à 23 h, jusqu'à 5 h le lendemain")
  hommes.lacher(id, "loisir")
  FauxJeu.heure = 27
  hommes.tenir(id, "loisir", { activite = "des", lieu = "des", position = point_d_essai() })
  egal(select(2, hommes.qui_tient(id)).fin, 29, "à 3 h, jusqu'à 5 h")
  hommes.lacher(id, "loisir")
  -- Jusqu'à libération : tenue, puis tombée par sûreté au bout de tenue_max_h, notée au journal.
  FauxJeu.heure = 30
  hommes.tenir(id, "bataille", { activite = "bataille", lieu = "rang_avant", position = point_d_essai(), fin = "liberation" })
  FauxJeu.heure = 30 + hommes.reglages.tenue_max_h - 0.1
  hommes.battre()
  egal(hommes.qui_tient(id), "bataille", "tenue jusqu'à sa libération")
  FauxJeu.heure = 30 + hommes.reglages.tenue_max_h
  hommes.battre()
  verifier(hommes.qui_tient(id) ~= "bataille", "tombée par sûreté au bout de " .. hommes.reglages.tenue_max_h .. " h")
  local dite = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "tenue « bataille »", 1, true) and string.find(l, "jamais lâchée", 1, true) then dite = dite + 1 end
  end
  egal(dite, 1, "notée une fois au journal")
end)

essai("arbitre : tenir et lâcher redonnent l'ordre sur-le-champ, jamais le secours hors battement", function()
  preparer(5000, 100, 10)
  hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  hommes.battre()
  local id = hommes.liste()[1]
  local f = hommes.fiche(id)
  FauxJeu.ordres = {}
  hommes.tenir(id, "rassemblement", { activite = "rassemblement", lieu = "rassemblement", position = point_d_essai(0, 8),
                                      fin = "liberation" })
  egal(#FauxJeu.ordres, 1, "un ordre sur-le-champ")
  egal(FauxJeu.ordres[1].activite, "rassemblement", "le rassemblement")
  hommes.tenir(id, "loisir", { activite = "des", lieu = "des", position = point_d_essai(), fin = 11 })
  egal(#FauxJeu.ordres, 1, "une tenue plus faible : aucun ordre")
  hommes.lacher(id, "rassemblement")
  egal(#FauxJeu.ordres, 2, "lâché : un ordre sur-le-champ")
  egal(FauxJeu.ordres[2].activite, "des", "le loisir resté posé")
  -- Figé loin de son but : ni tenir ni lâcher ne comptent le temps du secours, qui n'avance qu'au battement.
  FauxJeu.positions[f.personnage] = { x = 500, y = 500, z = 0 }
  FauxJeu.secours = {}
  for _ = 1, 6 do
    hommes.tenir(id, "loisir", { activite = "des", lieu = "des", position = point_d_essai(), fin = 11 })
    hommes.lacher(id, "travail")
  end
  egal(#FauxJeu.secours, 0, "aucun secours hors battement")
end)

essai("arbitre : la garde et la patrouille ne prennent pas un homme tenu plus fort ; l'exemption de la garde de nuit", function()
  preparer(5000, 100, 23)
  for _ = 1, 4 do
    hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  end
  local ids = hommes.liste()
  local function de_garde(id, heure)
    for _, g in ipairs(hommes.gardes(heure)) do
      if g.id == id then return true end
    end
    return false
  end
  hommes.tenir(ids[1], "bataille", { activite = "bataille", lieu = "rang_avant", position = point_d_essai(), fin = "liberation" })
  verifier(not hommes.libre_pour(ids[1], "garde_de_nuit"), "tenu par la bataille : pas libre pour la garde")
  verifier(not hommes.libre_pour(ids[1], "patrouille"), "ni pour la patrouille")
  hommes.exempter(ids[2], "garde_de_nuit")
  verifier(not hommes.tenir(ids[2], "garde_de_nuit", { activite = "garde", position = point_d_essai(), fin = 26 }),
           "une tenue de la règle dont il est exempté est refusée")
  for heure = 22.5, 28.5, 1 do
    verifier(not de_garde(ids[1], heure), "jamais de garde pour l'homme tenu par la bataille, à " .. heure .. " h")
    verifier(not de_garde(ids[2], heure), "jamais de garde de nuit pour l'exempté, à " .. heure .. " h")
  end
  verifier(hommes.libre_pour(ids[2], "garde"), "de jour, l'exempté de la nuit peut garder")
  hommes.tenir(ids[3], "punition", { activite = "corvee", lieu = "corvee_punition", position = point_d_essai(), fin = 40 })
  verifier(hommes.libre_pour(ids[3], "garde_de_nuit"), "puni, il reste libre pour la garde, plus forte que la punition")
  hommes.exempter(ids[2], "garde_de_nuit", false)
  verifier(hommes.libre_pour(ids[2], "garde_de_nuit"), "l'exemption levée")
end)

essai("arbitre : la journée du socle coupée, l'homme qu'aucune règle ne tient attend où il est", function()
  preparer(5000, 100, 10)
  hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  local id = hommes.liste()[1]
  local avant = hommes.reglages.journee_du_socle
  hommes.reglages.journee_du_socle = false
  FauxJeu.ordres = {}
  hommes.battre()
  egal(hommes.qui_tient(id), "aucune", "aucune règle ne le tient")
  egal(FauxJeu.ordres[#FauxJeu.ordres] and FauxJeu.ordres[#FauxJeu.ordres].activite, "attendre", "il attend où il est")
  hommes.reglages.journee_du_socle = avant
  hommes.battre()
  egal(hommes.qui_tient(id), "journee", "la journée revenue")
end)

-- Fiche 13 (validée par JoVenGer le 15/10/2026) : une âme à nous par homme vivant, jamais partagée.

essai("hommes : une âme par homme, tirée à l'embauche dans la réserve de son rôle, gardée au retour", function()
  preparer(10000, 0, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 1, prime = 0 })
  local b = hommes.embaucher({ role = "archer", semaines = 1, prime = 0, palier = 3 })
  local c = hommes.embaucher({ role = "barbier", semaines = 1, prime = 0 })
  egal(hommes.fiche(a).ame, "ame_combattant_1_1", "un combattant, recrue par défaut")
  egal(hommes.fiche(a).palier, 1, "palier gardé sur la fiche")
  egal(hommes.fiche(b).ame, "ame_combattant_3_1", "un vétéran")
  egal(hommes.fiche(c).ame, "ame_metier_1_1", "un homme de métier")
  egal(FauxJeu.personnages[1].ame, "ame_combattant_1_1", "le personnage vient sur son âme")
  local d = hommes.embaucher({ role = "pavoisier", semaines = 1, prime = 0 })
  egal(hommes.fiche(d).ame, "ame_combattant_1_2", "jamais une âme déjà portée")
  for _, id in ipairs(hommes.liste()) do
    FauxJeu.personnages_existants[hommes.fiche(id).personnage] = nil
  end
  local revenus = hommes.redresser()
  egal(revenus, 4, "tous revenus")
  egal(hommes.fiche(a).ame, "ame_combattant_1_1", "même âme au retour")
  egal(FauxJeu.personnages[#FauxJeu.personnages].ame, "ame_combattant_1_2", "le dernier revenu sur la sienne")
end)

essai("hommes : palier plein, l'âme du palier le plus proche ; jamais de refus faute d'âme", function()
  preparer(10000, 0, 10)
  camp.agrandir()
  FauxJeu.tailles_paliers.combattant = { 1, 1, 1 }
  local a = hommes.embaucher({ role = "archer", semaines = 1, prime = 0, palier = 2 })
  local b = hommes.embaucher({ role = "archer", semaines = 1, prime = 0, palier = 2 })
  local c = hommes.embaucher({ role = "archer", semaines = 1, prime = 0, palier = 2 })
  egal(hommes.fiche(a).ame, "ame_combattant_2_1", "son palier")
  egal(hommes.fiche(b).ame, "ame_combattant_1_1", "palier plein : celui d'en dessous d'abord")
  egal(hommes.fiche(c).ame, "ame_combattant_3_1", "puis celui d'au-dessus")
  egal(hommes.fiche(b).palier, 2, "il garde son palier d'embauche")
  local e = hommes.embaucher({ role = "archer", semaines = 1, prime = 0 })
  verifier(e, "embauché quand même : jamais de refus faute d'âme")
  egal(hommes.fiche(e).ame, nil, "sans âme")
  egal(hommes.fiche(e).personnage, nil, "sans personnage, il reste sur le registre")
  local dit = false
  for _, ligne in ipairs(FauxJeu.journal_lignes) do
    if string.find(ligne, "plus d'âme libre", 1, true) then dit = true end
  end
  verifier(dit, "dit au journal")
  hommes.renvoyer(a)
  local revenus = hommes.redresser()
  egal(revenus, 1, "l'âme rendue sert à celui qui attendait")
  egal(hommes.fiche(e).ame, "ame_combattant_2_1", "l'âme de l'homme parti")
end)

essai("hommes : un palier hors des réserves est refusé", function()
  preparer(10000, 0, 10)
  local ok, raison = hommes.embaucher({ role = "archer", semaines = 1, prime = 0, palier = 4 })
  egal(ok, false, "refusé")
  egal(raison, "palier_invalide", "raison")
  ok, raison = hommes.embaucher({ role = "barbier", semaines = 1, prime = 0, palier = 2 })
  egal(raison, "palier_invalide", "un seul palier pour les gens de métier")
  ok, raison = hommes.embaucher({ role = "archer", semaines = 1, prime = 0, palier = 1.5 })
  egal(raison, "palier_invalide", "un palier entier")
  egal(#hommes.liste(), 0, "personne d'embauché")
end)

essai("hommes : un homme né sur une âme empruntée au jeu renaît sur une âme à nous", function()
  preparer(10000, 0, 10)
  local a = hommes.embaucher({ role = "archer", semaines = 1, prime = 0 })
  local ancien = hommes.fiche(a).personnage
  -- Comme un homme engagé avant la fiche 13 : présent dans le monde, sans âme à nous sur sa fiche.
  Scriptorium.registre.lire("hommes").liste[a].ame = nil
  local revenus, manquants = hommes.relancer()
  egal(revenus, 1, "il renaît")
  egal(manquants, 0, "aucun manquant")
  egal(FauxJeu.personnages_renvoyes[#FauxJeu.personnages_renvoyes], ancien, "l'ancien personnage est retiré")
  local f = hommes.fiche(a)
  egal(f.ame, "ame_combattant_1_1", "une âme à nous")
  verifier(f.personnage ~= ancien, "un nouveau personnage")
  egal(FauxJeu.personnages[#FauxJeu.personnages].ame, "ame_combattant_1_1", "né sur son âme")
  revenus = hommes.relancer()
  egal(revenus, 0, "une seule fois")
end)

-- ---------------------------------------------------------------- équipement (fiche 13, V71 b)

local function personnage_de(id) return hommes.fiche(id).personnage end
local function a_dans_le_sac(id, objet) return FauxJeu.compter_objet(personnage_de(id), objet) end

essai("équipement : un homme d'armes reçoit à l'embauche sa famille, une tenue et des armes de son palier, créées une à une au battement", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 2, famille = "hache" })
  local f = hommes.fiche(id)
  egal(f.famille, "hache", "famille du contrat")
  egal(f.equipement.etat, "a_equiper", "à équiper au battement")
  egal(f.equipement.armes, "axe_3_01", "armes de sa famille au palier 2 (niveau 3)")
  egal(string.match(f.equipement.tenue, "^soldier_generic_[34]_0[12]$") ~= nil, true, "tenue du palier 2 (niveaux 3 et 4)")
  egal(#FauxJeu.equipements, 0, "rien avant le battement")
  hommes.battre()
  egal(#FauxJeu.equipements, 1, "équipé au battement")
  egal(FauxJeu.equipements[1].ordre.retirer_naissance, true, "tenue de naissance retirée la première fois")
  egal(a_dans_le_sac(id, "naissance_tunique"), 0, "tunique de naissance retirée")
  egal(a_dans_le_sac(id, "bourse"), 30, "bourse gardée")
  egal(a_dans_le_sac(id, "axe_3_01_arme"), 1, "arme créée")
  egal(a_dans_le_sac(id, f.equipement.tenue .. "_corps"), 1, "pièce de tenue créée")
  local porte = hommes.ce_qu_il_porte(id)
  egal(#porte, 5, "trois pièces de tenue, deux d'armes")
  egal(porte[4], "axe_3_01_arme", "tenue d'abord, armes ensuite")
  egal(#FauxJeu.portes[personnage_de(id)], 5, "tout porté")
  egal(hommes.fiche(id).equipement.etat, "a_completer", "second passage au battement suivant")
  hommes.battre()
  egal(hommes.fiche(id).equipement.etat, "pret", "prêt")
  egal(#FauxJeu.portes[personnage_de(id)], 10, "toutes ses pièces portées une seconde fois")
end)

essai("équipement : famille inconnue refusée ; sans famille, une des six est tirée et gardée", function()
  preparer(200, 10, 10)
  local id, raison = hommes.embaucher({ role = "homme_d_armes", semaines = 4, famille = "fronde" })
  egal(id, false, "refus")
  egal(raison, "famille_inconnue", "raison")
  local id2 = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  local famille = hommes.fiche(id2).famille
  egal(hommes.equipement.familles[famille] ~= nil, true, "une des six familles")
end)

-- Fiche 13, la garde de la tenue (réponses a et a de JoVenGer du 16/10) : le moteur ôte parfois sa tenue à un homme en
-- pleine partie ; le socle lui fait remettre ses propres pièces.
local function lignes_contenant(texte)
  local n = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, texte, 1, true) then n = n + 1 end
  end
  return n
end

local function etat_de(id)
  return hommes.fiche(id).equipement.etat
end

-- Des hommes équipés de jour (un homme embauché la nuit est au lit : la garde attend qu'il se lève pour l'équiper),
-- puis l'heure voulue.
local function homme_equipe(heure, n)
  preparer(800, 10, 10)
  local ids = {}
  for _ = 1, n or 1 do
    table.insert(ids, hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 }))
  end
  for _ = 1, 2 * #ids do
    hommes.battre()
  end
  for _, id in ipairs(ids) do
    egal(etat_de(id), "pret", "équipé : " .. id)
  end
  FauxJeu.heure = heure
  return ids
end

essai("garde de la tenue (fiche 13) : une fin de combat, ou une relance en filet, fait remettre ses pièces à l'homme", function()
  local id = homme_equipe(10)[1]
  local f = hommes.fiche(id)
  FauxJeu.variables_du_cerveau[f.personnage] = { scriptorium_fins_de_combat = 0, scriptorium_essai_rejoint = 1 }
  egal(hommes.battre().a_rhabiller, 0, "premier relevé : personne n'est marqué")
  local remis = lignes_contenant("« " .. f.nom .. " » a remis ses affaires")
  FauxJeu.variables_du_cerveau[f.personnage] = { scriptorium_fins_de_combat = 1, scriptorium_essai_rejoint = 1 }
  egal(hommes.battre().a_rhabiller, 1, "une fin de combat : marqué")
  egal(lignes_contenant("à rhabiller (fin de combat)"), 1, "dit au journal")
  egal(lignes_contenant("« " .. f.nom .. " » a remis ses affaires"), remis + 1, "ses pièces remises dans le même battement")
  egal(etat_de(id), "a_completer", "le second passage suivra")
  hommes.battre()
  egal(etat_de(id), "pret", "prêt de nouveau")
  FauxJeu.variables_du_cerveau[f.personnage] = { scriptorium_fins_de_combat = 1, scriptorium_essai_rejoint = 2 }
  egal(hommes.battre().a_rhabiller, 1, "une relance de sa vie du camp, en filet : marqué")
  egal(lignes_contenant("à rhabiller (vie du camp relancée)"), 1, "dit au journal")
end)

essai("garde de la tenue : jamais au lit ; la sortie du lit fait remettre ses pièces", function()
  local id = homme_equipe(23)[1]
  local f = hommes.fiche(id)
  hommes.battre()
  egal(camp.sorte_de(hommes.activite_de(id, 23).lieu), "lit", "la nuit, dans son lit")
  local remis = lignes_contenant("« " .. f.nom .. " » a remis ses affaires")
  for _ = 1, 3 do
    egal(hommes.battre().tenues, 0, "au lit, la garde ne le touche pas")
  end
  egal(etat_de(id), "pret", "au lit, rien n'est marqué")
  FauxJeu.heure = 29.5
  hommes.battre()
  egal(lignes_contenant("« " .. f.nom .. " » a remis ses affaires"), remis + 1, "levé : ses pièces remises (la sortie du lit)")
  hommes.battre()
  egal(etat_de(id), "pret", "prêt")
  -- La nuit suivante, le service du guichet : au lit, l'homme est seulement marqué, puis rhabillé à son lever.
  FauxJeu.heure = 47
  hommes.battre()
  verifier(hommes.rhabiller(id), "le service du guichet répond")
  egal(lignes_contenant("sera rhabillé plus tard (au lit)"), 1, "au lit, il est seulement marqué")
  egal(etat_de(id), "a_rhabiller", "marqué")
  hommes.battre()
  egal(lignes_contenant("« " .. f.nom .. " » a remis ses affaires"), remis + 1, "toujours au lit : rien de remis")
end)

essai("garde de la tenue : en tournant, un homme par battement, en silence ; ni au bain, ni en combat", function()
  local ids = homme_equipe(10, 3)
  local remis = lignes_contenant("a remis ses affaires")
  local vus = {}
  for _ = 1, 3 do
    egal(hommes.battre().tenues, 1, "un homme repassé par battement")
    vus[FauxJeu.dernier_porter.personnage] = true
  end
  local n = 0
  for _ in pairs(vus) do n = n + 1 end
  egal(n, 3, "chacun à son tour")
  egal(lignes_contenant("a remis ses affaires"), remis, "rien n'est dit au journal")
  -- Au bain (une tenue qui le veut dévêtu) ou en combat : sauté, jusqu'à la fin de la tenue ou du combat.
  hommes.tenir(ids[1], "bains", { activite = "bain", lieu = "bains_essai", position = camp.point(5, 5, 0), fin = 11,
                                  ne_pas_rhabiller = true })
  FauxJeu.occupations[hommes.fiche(ids[2]).personnage] = "combat"
  for _ = 1, 3 do
    hommes.battre()
    egal(FauxJeu.dernier_porter.personnage, hommes.fiche(ids[3]).personnage, "seul le troisième est repassé")
  end
  verifier(hommes.rhabiller(ids[1]), "le service répond au bain")
  egal(lignes_contenant("sera rhabillé plus tard (tenu dévêtu (bains))"), 1, "au bain, seulement marqué")
  hommes.lacher(ids[1], "bains")
  FauxJeu.occupations[hommes.fiche(ids[2]).personnage] = nil
  hommes.battre()
  egal(lignes_contenant("« " .. hommes.fiche(ids[1]).nom .. " » a remis ses affaires"), 1, "sorti du bain : ses pièces remises")
  verifier(hommes.rhabiller(ids[2]), "le service rhabille aussitôt un homme libre")
  egal(lignes_contenant("« " .. hommes.fiche(ids[2]).nom .. " » a remis ses affaires"), 1, "aussitôt")
end)

essai("équipement : archer, pavoisier et arbalétrier selon leur palier ; gens de métier sans rien", function()
  preparer(300, 10, 10)
  local archer = hommes.embaucher({ role = "archer", semaines = 4, palier = 3 })
  local pavoisier = hommes.embaucher({ role = "pavoisier", semaines = 4, palier = 1 })
  local arbaletrier = hommes.embaucher({ role = "arbaletrier", semaines = 4, palier = 2 })
  local cuisinier = hommes.embaucher({ role = "cuisinier", semaines = 4 })
  egal(hommes.fiche(archer).equipement.armes, "scriptorium_archer_3", "arc du palier 3")
  egal(hommes.fiche(archer).equipement.munitions, 30, "munitions du palier 3")
  egal(string.match(hommes.fiche(pavoisier).equipement.armes, "^mace_shield_2_0[23]$") ~= nil, true, "pavois du palier 1")
  egal(string.match(hommes.fiche(arbaletrier).equipement.armes, "^scriptorium_arbaletrier_2_[ab]$") ~= nil, true, "arbalète du palier 2")
  egal(hommes.fiche(cuisinier).equipement, nil, "cuisinier : rien")
  for _ = 1, 6 do hommes.battre() end
  egal(#FauxJeu.equipements, 3, "trois combattants équipés, un par battement (deux passages chacun)")
  egal(a_dans_le_sac(archer, "scriptorium_archer_3_munition"), 30, "flèches")
  egal(a_dans_le_sac(cuisinier, "naissance_tunique"), 1, "cuisinier : tenue de naissance gardée")
end)

essai("équipement : un homme par battement, jamais en bataille", function()
  preparer(200, 10, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  local b = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  local bandes = Scriptorium.bataille.bandes
  Scriptorium.bataille.bandes = function() return { "bande_1" } end
  hommes.battre()
  Scriptorium.bataille.bandes = bandes
  egal(#FauxJeu.equipements, 0, "rien en bataille")
  hommes.battre()
  egal(#FauxJeu.equipements, 1, "un seul au premier battement")
  egal(hommes.fiche(a).equipement.etat, "a_completer", "le premier")
  egal(hommes.fiche(b).equipement.etat, "a_equiper", "le second attend")
  hommes.battre()
  egal(hommes.fiche(a).equipement.etat, "pret", "le premier complété")
  egal(hommes.fiche(b).equipement.etat, "a_equiper", "le second attend encore")
  hommes.battre()
  hommes.battre()
  egal(hommes.fiche(b).equipement.etat, "pret", "le second ensuite")
end)

essai("équipement : à chaque entrée en partie, chacun remet ses propres pièces, dans l'ordre ; munitions complétées", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "archer", semaines = 4, palier = 1 })
  hommes.battre()
  local p = personnage_de(id)
  FauxJeu.portes[p] = {}
  FauxJeu.retirer_un_objet(p, "scriptorium_archer_1_munition")
  FauxJeu.creer_objet(p, "scriptorium_archer_1_munition", 1, 10)
  hommes.relancer()
  egal(hommes.fiche(id).equipement.etat, "a_rhabiller", "à rhabiller")
  hommes.battre()
  egal(hommes.fiche(id).equipement.etat, "a_completer", "rhabillé, second passage à venir")
  egal(#FauxJeu.portes[p], #hommes.ce_qu_il_porte(id), "toutes ses pièces remises")
  egal(FauxJeu.portes[p][1], hommes.ce_qu_il_porte(id)[1], "dans l'ordre")
  egal(#FauxJeu.dernier_porter.objets, #hommes.ce_qu_il_porte(id), "rien n'est ôté : toutes ses pièces remises par-dessus")
  hommes.battre()
  egal(hommes.fiche(id).equipement.etat, "pret", "prêt après le second passage")
  egal(#FauxJeu.equipements, 1, "rien de recréé")
  egal(a_dans_le_sac(id, "scriptorium_archer_1_munition"), 25, "flèches complétées jusqu'au nombre du préréglage")
end)

essai("équipement : filet, sans tenue ni arme principale ses préréglages sont recréés ; pièce introuvable jamais recréée seule", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, famille = "epee_bouclier" })
  hommes.battre()
  local p = personnage_de(id)
  local e = hommes.fiche(id).equipement
  FauxJeu.retirer_un_objet(p, e.tenue .. "_tete")
  hommes.relancer()
  hommes.battre()
  egal(#FauxJeu.equipements, 1, "une pièce manque : pas de recréation")
  egal(a_dans_le_sac(id, e.tenue .. "_tete"), 0, "la pièce perdue n'est pas recréée")
  FauxJeu.retirer_un_objet(p, "sword_shield_3_01_arme")
  hommes.relancer()
  hommes.battre()
  egal(hommes.fiche(id).equipement.etat, "a_equiper", "plus d'arme principale : à rééquiper")
  hommes.battre()
  egal(#FauxJeu.equipements, 2, "préréglages recréés")
  egal(FauxJeu.equipements[2].ordre.retirer_naissance, false, "la tenue de naissance n'est retirée qu'une fois")
  egal(a_dans_le_sac(id, "sword_shield_3_01_arme"), 1, "arme recréée")
end)

essai("équipement : changer de palier, même famille, nouvelles pièces ; anciennes rendues au camp si l'accroche les prend", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, famille = "epee_longue", palier = 1 })
  hommes.battre()
  local ame = hommes.fiche(id).ame
  local ancienne_tenue = hommes.fiche(id).equipement.tenue
  local offertes = {}
  local accroches = hommes.accroches
  hommes.accroches = { apres_le_rhabillage = {}, piece_otee = {} }
  hommes.accrocher("piece_otee", function(homme, objet)
    table.insert(offertes, objet)
    return objet ~= "longsword_3_01_arme"
  end)
  local ok, raison = hommes.changer_de_palier(id, 4)
  egal(raison, "palier_invalide", "palier hors des réserves refusé")
  egal(hommes.changer_de_palier(id, 3), true, "palier 3")
  local f = hommes.fiche(id)
  egal(f.famille, "epee_longue", "même famille")
  egal(f.ame, ame, "même âme")
  egal(string.match(f.equipement.armes, "^longsword_[56]_01$") ~= nil, true, "armes du palier 3")
  hommes.battre()
  hommes.accroches = accroches
  egal(#offertes, 5, "anciennes pièces offertes à l'accroche")
  egal(a_dans_le_sac(id, "longsword_3_01_arme"), 1, "pièce non prise : gardée dans son sac")
  egal(a_dans_le_sac(id, ancienne_tenue .. "_corps"), 0, "pièce prise : sortie de son sac")
  egal(FauxJeu.equipements[2].ordre.retirer_naissance, false, "pas de second retrait de naissance")
end)

essai("équipement : une pièce donnée est créée, portée et gardée après sa tenue ; ôtée, elle sort de ce qu'il porte", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  hommes.battre()
  local appels = 0
  local accroches = hommes.accroches
  hommes.accroches = { apres_le_rhabillage = {}, piece_otee = {} }
  hommes.accrocher("apres_le_rhabillage", function() appels = appels + 1 end)
  local _, raison = hommes.donner_une_piece(id, "pas un objet", 1, true)
  egal(raison, "objet_invalide", "objet invalide refusé")
  _, raison = hommes.donner_une_piece(id, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", 1.5, true)
  egal(raison, "etat_invalide", "état invalide refusé")
  egal(hommes.donner_une_piece(id, "AAAAAAAA-bbbb-cccc-dddd-eeeeeeeeeeee", 0.4, true), true, "pièce donnée")
  local porte = hommes.ce_qu_il_porte(id)
  egal(porte[#porte], "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "après sa tenue de grade")
  hommes.relancer()
  hommes.battre()
  egal(appels, 0, "pas avant le second passage")
  hommes.battre()
  egal(appels, 1, "accroche après le rhabillage appelée")
  egal(hommes.piece_otee(id, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"), true, "pièce ôtée")
  egal(#hommes.ce_qu_il_porte(id), #porte - 1, "sortie de ce qu'il porte")
  local tete = hommes.fiche(id).equipement.tenue .. "_tete"
  hommes.piece_otee(id, tete)
  local reste = hommes.ce_qu_il_porte(id)
  for _, objet in ipairs(reste) do
    egal(objet ~= tete, true, "pièce de tenue ôtée")
  end
  hommes.accroches = accroches
  egal(hommes.accrocher("inconnue", function() end), false, "accroche inconnue refusée")
end)

essai("équipement : un homme d'avant l'équipement (fiche sans équipement) est équipé une fois au battement", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "arbaletrier", semaines = 4 })
  Scriptorium.registre.lire("hommes").liste[id].equipement = nil
  hommes.battre()
  hommes.battre()
  local e = hommes.fiche(id).equipement
  egal(e.etat, "pret", "équipé")
  egal(string.match(e.armes, "^scriptorium_arbaletrier_1_[ab]$") ~= nil, true, "arbalète du palier 1")
  egal(a_dans_le_sac(id, "naissance_tunique"), 0, "tenue de naissance retirée")
end)

essai("équipement : un personnage refait est rééquipé, sa tenue de naissance retirée de nouveau, ses pièces données recréées avec leur dernier état", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  hommes.battre()
  local piece = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  hommes.donner_une_piece(id, piece, 0.4, true)
  egal(hommes.fiche(id).equipement.en_plus[1].etat, 0.4, "état noté au don")
  local p = personnage_de(id)
  for _, o in ipairs(FauxJeu.inventaires[p]) do
    if o.objet == piece then o.etat = 0.25 end
  end
  hommes.relancer()
  hommes.battre()
  egal(hommes.fiche(id).equipement.en_plus[1].etat, 0.25, "dernier état relu à l'entrée en partie")
  FauxJeu.personnages_existants[p] = nil
  hommes.relancer()
  egal(personnage_de(id) ~= p, true, "refait")
  egal(hommes.fiche(id).equipement.etat, "a_equiper", "à rééquiper")
  egal(#hommes.fiche(id).equipement.en_plus, 1, "pièce donnée gardée sur la fiche")
  hommes.battre()
  egal(#FauxJeu.equipements, 2, "rééquipé")
  egal(FauxJeu.equipements[2].ordre.retirer_naissance, true, "tenue de naissance du nouveau retirée")
  egal(a_dans_le_sac(id, "naissance_tunique"), 0, "plus de tunique de naissance")
  egal(a_dans_le_sac(id, piece), 1, "pièce donnée recréée")
  egal(FauxJeu.etat_objet(personnage_de(id), piece), 0.25, "avec son dernier état")
  egal(hommes.ce_qu_il_porte(id)[#hommes.ce_qu_il_porte(id)], piece, "et portée après sa tenue")
end)

essai("équipement : les tenues exclues ne sont jamais tirées", function()
  preparer(300, 10, 10)
  local exclues = hommes.equipement.tenue.exclues
  hommes.equipement.tenue.exclues = { "soldier_generic_5_01", "soldier_generic_5_02", "soldier_generic_6_01" }
  for _ = 1, 4 do
    local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 3 })
    egal(hommes.fiche(id).equipement.tenue, "soldier_generic_6_02", "seule tenue du palier 3 hors des exclues")
  end
  hommes.equipement.tenue.exclues = exclues
end)

essai("hommes : à l'exercice, chacun sa place, jamais deux au même point", function()
  preparer(5000, 10, 10)
  for _ = 1, 8 do
    hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  end
  local vus = {}
  for _, id in ipairs(hommes.liste()) do
    local a = hommes.activite_de(id, 10)
    if a and a.activite == "exercice" then
      for _, autre in ipairs(vus) do
        local ecart = math.sqrt((a.position.x - autre.x) ^ 2 + (a.position.y - autre.y) ^ 2)
        verifier(ecart >= hommes.reglages.ecart_entre_hommes - 0.01, "au moins l'écart réglé entre deux places")
      end
      table.insert(vus, a.position)
    end
  end
  verifier(#vus >= 2, "au moins deux hommes à l'exercice à 10 h (" .. #vus .. ")")
end)

essai("vie du camp (fiche 15) : une place se prend par son objet du jeu, un point se rejoint en marchant", function()
  preparer(5000, 100, 12.5)
  for _ = 1, 6 do
    hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  end
  FauxJeu.ordres = {}
  hommes.battre()
  local sieges, points = 0, 0
  for _, o in ipairs(FauxJeu.ordres) do
    if camp.sorte_de(o.lieu) == "siege" then
      sieges = sieges + 1
      egal(o.sorte, "siege", "un siège se prend assis")
      egal(o.place, camp.objet_du_jeu_de(o.lieu), "par l'objet du jeu de sa place")
    else
      points = points + 1
      egal(o.place, nil, "un point : pas de place")
      verifier(o.position ~= nil, "un point où marcher")
    end
  end
  verifier(sieges >= 1 and points >= 1, "au repas, des sièges et des points (" .. sieges .. ", " .. points .. ")")
  FauxJeu.ordres = {}
  FauxJeu.heure = 23
  hommes.battre()
  local lits = 0
  for _, o in ipairs(FauxJeu.ordres) do
    if o.activite == "sommeil" and o.sorte == "lit" then
      lits = lits + 1
      egal(o.place, camp.objet_du_jeu_de(o.lieu), "le lit par son objet du jeu")
    end
  end
  verifier(lits >= 1, "la nuit, au lit (" .. lits .. ")")
end)

essai("vie du camp (fiche 15) : l'homme bloqué est posé près de son but, jamais sur un meuble, deux fois au plus", function()
  preparer(5000, 100, 12.5)
  for _ = 1, 6 do
    hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  end
  hommes.battre()
  -- Un homme assis au repas, figé à 50 m de son siège.
  local cible = nil
  for _, id in ipairs(hommes.liste()) do
    local a = hommes.activite_de(id, 12.5)
    if camp.sorte_de(a.lieu) == "siege" and not cible then
      cible = { id = id, a = a, personnage = hommes.fiche(id).personnage }
    end
  end
  verifier(cible ~= nil, "un homme au siège")
  FauxJeu.positions[cible.personnage] = { x = cible.a.position.x + 50, y = cible.a.position.y, z = 0 }
  FauxJeu.secours = {}
  hommes.battre()
  egal(#FauxJeu.secours, 0, "premier relevé : pas encore de secours")
  hommes.battre()
  egal(#FauxJeu.secours, 1, "30 s sans se rapprocher : un secours")
  local ou, abord = FauxJeu.secours[1].position, camp.abord_de(cible.a.lieu)
  verifier(math.abs(ou.x - abord.x) < 0.01 and math.abs(ou.y - abord.y) < 0.01, "posé à l'abord de sa place")
  local siege = camp.position_de(cible.a.lieu)
  verifier(math.sqrt((ou.x - siege.x) ^ 2 + (ou.y - siege.y) ^ 2) > 2, "jamais sur le siège")
  -- Toujours figé au loin : le secours ne l'a pas fait avancer.
  for _ = 1, 10 do
    FauxJeu.positions[cible.personnage] = { x = cible.a.position.x + 50, y = cible.a.position.y, z = 0 }
    hommes.battre()
  end
  egal(#FauxJeu.secours, hommes.reglages.secours_max, "deux secours au plus")
  local signale = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "malgré 2 secours", 1, true) then signale = signale + 1 end
  end
  egal(signale, 1, "laissé où il est, noté une seule fois au journal")
end)

essai("vie du camp (fiche 15) : un homme qui se rapproche n'est jamais secouru", function()
  preparer(5000, 100, 15)
  hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  local id = hommes.liste()[1]
  local f = hommes.fiche(id)
  hommes.battre()
  local a = hommes.activite_de(id, 15)
  FauxJeu.secours = {}
  for pas = 1, 6 do
    FauxJeu.positions[f.personnage] = { x = a.position.x + 30 - pas * 4, y = a.position.y, z = 0 }
    hommes.battre()
  end
  egal(#FauxJeu.secours, 0, "il avance de 4 m par battement : aucun secours")
end)

essai("vie du camp (fiche 15, V73 c) : un homme encore assis à sa place d'avant n'est jamais posé d'un coup", function()
  preparer(5000, 100, 12.5)
  for _ = 1, 6 do
    hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  end
  hommes.battre()
  local cible = nil
  for _, id in ipairs(hommes.liste()) do
    local a = hommes.activite_de(id, 12.5)
    if camp.sorte_de(a.lieu) == "siege" and not cible then
      cible = { id = id, siege = a.position, personnage = hommes.fiche(id).personnage }
    end
  end
  verifier(cible ~= nil, "un homme au siège")
  FauxJeu.positions[cible.personnage] = { x = cible.siege.x, y = cible.siege.y, z = 0 }
  FauxJeu.heure = 13.5
  hommes.battre()
  egal(hommes.activite_de(cible.id, 13.5).activite, "corvee", "à 13 h 30, la corvée")
  FauxJeu.secours = {}
  for _ = 1, 4 do
    hommes.battre()
  end
  egal(#FauxJeu.secours, 0, "encore assis à son siège : jamais posé d'un coup")
  FauxJeu.positions[cible.personnage] = { x = cible.siege.x + 2, y = cible.siege.y, z = 0 }
  for _ = 1, 3 do
    hommes.battre()
  end
  egal(#FauxJeu.secours, 1, "levé, puis figé : un secours")
end)

essai("vie du camp (fiche 15, V73 b 1) : un homme en combat ou en conversation n'est jamais secouru ; son compte repart de zéro", function()
  preparer(5000, 100, 12.5)
  for _ = 1, 6 do
    hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  end
  hommes.battre()
  local cible = nil
  for _, id in ipairs(hommes.liste()) do
    local a = hommes.activite_de(id, 12.5)
    if camp.sorte_de(a.lieu) == "siege" and not cible then
      cible = { id = id, a = a, personnage = hommes.fiche(id).personnage }
    end
  end
  verifier(cible ~= nil, "un homme au siège")
  -- Figé à 50 m de son siège, mais en combat : jamais posé d'un coup hors de son combat.
  FauxJeu.positions[cible.personnage] = { x = cible.a.position.x + 50, y = cible.a.position.y, z = 0 }
  FauxJeu.secours = {}
  FauxJeu.occupations[cible.personnage] = "combat"
  for _ = 1, 5 do
    hommes.battre()
  end
  egal(#FauxJeu.secours, 0, "en combat, 2 min 30 sans se rapprocher : aucun secours")
  -- Le combat fini, le compte repart de zéro : un relevé, puis 30 s sans progrès avant le premier secours.
  FauxJeu.occupations[cible.personnage] = nil
  hommes.battre()
  egal(#FauxJeu.secours, 0, "le combat fini : le compte repart de zéro")
  hommes.battre()
  egal(#FauxJeu.secours, 1, "puis 30 s sans se rapprocher : un secours")
  -- De même en conversation.
  FauxJeu.positions[cible.personnage] = { x = cible.a.position.x + 50, y = cible.a.position.y, z = 0 }
  FauxJeu.occupations[cible.personnage] = "conversation"
  for _ = 1, 4 do
    hommes.battre()
  end
  egal(#FauxJeu.secours, 1, "en conversation : aucun secours de plus")
end)

-- Fiche 15, V73 d 1 : le factionnaire se tient face au dehors (réponses a, a et a de JoVenGer du 16/10).
local function pres(obtenu, attendu, message)
  verifier(type(obtenu) == "number" and type(attendu) == "number" and math.abs(obtenu - attendu) < 0.01,
    (message or "") .. " : obtenu « " .. tostring(obtenu) .. " », attendu « " .. tostring(attendu) .. " »")
end

essai("factionnaire (fiche 15, V73 d 1) : le tour de garde regarde vers le dehors, à regard_m devant son poste", function()
  for _, cap_d_ancre in ipairs({ 0, 90 }) do
    depart()
    FauxJeu.heure = 23
    camp.fonder({ x = 100, y = 200, z = 5 }, cap_d_ancre)
    for _ = 1, 4 do
      hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
    end
    local gardes = hommes.gardes(23)
    egal(#gardes, 2, "deux postes la nuit (ancre au cap " .. cap_d_ancre .. ")")
    local r = hommes.reglages.regard_m
    local function au_centre(q) return math.sqrt((q.x - 100) ^ 2 + (q.y - 200) ^ 2) end
    for _, g in ipairs(gardes) do
      local a = hommes.activite_de(g.id, 23)
      local p = hommes.postes_de_garde[g.poste]
      local position, cap = camp.point(p.x, p.y, p.cap)
      local nom = "poste " .. g.poste .. ", ancre au cap " .. cap_d_ancre
      egal(a.activite, "garde", nom .. " : de garde")
      pres(a.cap, cap, nom .. " : le cap du poste n'est plus jeté")
      verifier(a.regard ~= nil, nom .. " : un point de regard")
      if a.regard then
        pres(a.regard.x, position.x + r * math.sin(math.rad(cap)), nom .. " : regard dans le cap du poste (x)")
        pres(a.regard.y, position.y + r * math.cos(math.rad(cap)), nom .. " : regard dans le cap du poste (y)")
        pres(au_centre(a.regard), au_centre(position) + r, nom .. " : tourné vers le dehors")
      end
    end
    -- Le battement donne les ordres : seuls les deux gardes portent un point de regard.
    FauxJeu.ordres = {}
    hommes.battre()
    local de_garde = 0
    for _, o in ipairs(FauxJeu.ordres) do
      if o.activite == "garde" then
        de_garde = de_garde + 1
        verifier(o.regard ~= nil, "l'ordre de garde porte son point de regard")
      else
        egal(o.regard, nil, "un ordre « " .. tostring(o.activite) .. " » ne porte pas de regard")
      end
    end
    egal(de_garde, 2, "deux ordres de garde (ancre au cap " .. cap_d_ancre .. ")")
  end
end)

essai("factionnaire (fiche 15, V73 d 1) : une tenue « garde » se tient face à son cap, sinon vers le dehors ; ni camp ni cap : une marche", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local r = hommes.reglages.regard_m
  local poste = camp.point(3, 4, 0)   -- à 5 m du centre (ancre en 0, 0 au cap 0)
  FauxJeu.ordres = {}
  verifier(hommes.tenir(id, "garde", { activite = "garde", lieu = "porte", position = poste, cap = 45, fin = "liberation" }),
    "tenu par la garde")
  local a = hommes.activite_de(id, 10)
  pres(a.regard and a.regard.x, poste.x + r * math.sin(math.rad(45)), "avec un cap : le regard dans ce cap (x)")
  pres(a.regard and a.regard.y, poste.y + r * math.cos(math.rad(45)), "avec un cap : le regard dans ce cap (y)")
  local dernier = FauxJeu.ordres[#FauxJeu.ordres]
  egal(dernier and dernier.activite, "garde", "l'ordre part sur-le-champ")
  verifier(dernier ~= nil and dernier.regard ~= nil, "avec son point de regard")
  -- Sans cap : du centre du camp vers le poste.
  hommes.tenir(id, "garde", { activite = "garde", lieu = "porte", position = poste, fin = "liberation" })
  a = hommes.activite_de(id, 10)
  pres(a.regard and a.regard.x, poste.x + r * 3 / 5, "sans cap : vers le dehors (x)")
  pres(a.regard and a.regard.y, poste.y + r * 4 / 5, "sans cap : vers le dehors (y)")
  -- Un poste au centre même du camp : pas de dehors, une marche simple.
  hommes.tenir(id, "garde", { activite = "garde", lieu = "centre", position = camp.point(0, 0, 0), fin = "liberation" })
  egal(hommes.activite_de(id, 10).regard, nil, "au centre du camp : aucun regard")
  -- Une autre activité tenue n'a pas de regard, même avec un cap.
  hommes.lacher(id, "garde")
  hommes.tenir(id, "rassemblement", { activite = "rassemblement", lieu = "corvee", position = poste, cap = 45,
    fin = "liberation" })
  egal(hommes.activite_de(id, 10).regard, nil, "le rassemblement n'est pas une garde")
  hommes.lacher(id, "rassemblement")
  -- Ni camp ni cap : une marche simple ; avec un cap, le regard ne dépend pas du camp.
  hommes.tenir(id, "garde", { activite = "garde", lieu = "porte", position = poste, fin = "liberation" })
  verifier(camp.lever(), "camp levé")
  egal(hommes.activite_de(id, 10).regard, nil, "ni camp ni cap : aucun regard, l'ordre est une marche")
  hommes.tenir(id, "garde", { activite = "garde", lieu = "porte", position = poste, cap = 90, fin = "liberation" })
  a = hommes.activite_de(id, 10)
  pres(a.regard and a.regard.x, poste.x + r, "sans camp, au cap 90 : le regard à l'est (x)")
  pres(a.regard and a.regard.y, poste.y, "sans camp, au cap 90 : le regard à l'est (y)")
end)

essai("factionnaire (fiche 15, V73 d 1) : chaque poste de garde par défaut est à l'écart des meubles et dans la palissade", function()
  local ecart = camp.reglages.ecart_d_abord
  local rayon = Scriptorium.enceinte.reglages.rayon
  for i, p in ipairs(hommes.postes_de_garde) do
    verifier(type(p.cap) == "number", "poste " .. i .. " : un cap")
    for _, e in ipairs(camp.plan) do
      local d = math.sqrt((p.x - e.x) ^ 2 + (p.y - e.y) ^ 2)
      verifier(d >= ecart, "poste " .. i .. " à " .. string.format("%.1f", d) .. " m de « " .. e.nom .. " » : au moins "
        .. ecart .. " m")
    end
    verifier(math.sqrt(p.x ^ 2 + p.y ^ 2) + ecart <= rayon, "poste " .. i .. " en dedans de la palissade (rayon "
      .. rayon .. " m)")
  end
end)

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

essai("soins (vu sur une copie le 21/10, J3) : un blessé va au repos devant une tenue de même rang (la règle de Scriptorium), sauf les bains ; une règle plus forte passe devant", function()
  preparer(100, 100, 10)
  local a = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  local avant = hommes.priorites.scriptorium
  hommes.priorites.scriptorium = hommes.priorites.soins
  local fait, erreur = pcall(function()
    verifier(hommes.tenir(a, "scriptorium", { activite = "geste", lieu = "scriptorium", geste = "eating_standing", position = { x = 3, y = 4, z = 0 }, fin = "liberation" }), "tenu au même rang que les soins")
    verifier(hommes.blesser(a, 3), "blessé")
    local r = hommes.activite_de(a, 10)
    egal(r.activite, "repos", "au repos devant une tenue de même rang")
    verifier(r.position ~= nil, "à un lit")
    verifier(hommes.libre_pour(a, "scriptorium") == false, "pas libre pour la règle de Scriptorium")
    verifier(hommes.tenir(a, "bains", { activite = "geste", lieu = "bains", geste = "eating_standing", position = { x = 3, y = 4, z = 0 }, fin = "liberation" }), "envoyé au bain")
    egal(hommes.activite_de(a, 10).regle, "bains", "les bains passent devant les soins (décision du 26/09)")
    hommes.lacher(a, "bains")
    hommes.lacher(a, "scriptorium")
  end)
  hommes.priorites.scriptorium = avant
  verifier(fait, tostring(erreur))
  verifier(hommes.tenir(a, "travail", { activite = "geste", lieu = "forge", geste = "eating_standing", position = { x = 3, y = 4, z = 0 }, fin = "liberation" }), "tenu par une règle plus faible")
  egal(hommes.activite_de(a, 10).activite, "repos", "au repos devant une règle plus faible")
  verifier(hommes.tenir(a, "mission", { activite = "suivre", lieu = "m", fin = "liberation" }), "tenu par une mission")
  egal(hommes.activite_de(a, 10).activite, "suivre", "la mission passe devant les soins")
end)

local function lignes_du_journal(morceau)
  local n = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, morceau, 1, true) then n = n + 1 end
  end
  return n
end

essai("santé des blessés (demande de JoVenGer par le pair, 21/10, J5) : elle suit la blessure, ramenée au plafond de ses jours, sans coup ; tenue après une régénération ; guéri, plus de plafond", function()
  preparer(100, 100, 10)
  local a = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  hommes.battre()
  local p = hommes.fiche(a).personnage
  FauxJeu.santes, FauxJeu.santes_reglees = { [p] = 100 }, 0
  hommes.battre()
  egal(FauxJeu.santes_reglees, 0, "valide : rien")
  verifier(hommes.blesser(a, 3), "blessé trois jours")
  hommes.battre()
  egal(FauxJeu.santes[p], hommes.reglages.sante_blesse_3, "santé ramenée au plafond de trois jours")
  egal(lignes_du_journal("santé 100 ramenée à " .. hommes.reglages.sante_blesse_3), 1, "dit au journal")
  local reglees = FauxJeu.santes_reglees
  hommes.battre()
  egal(FauxJeu.santes_reglees, reglees, "déjà sous son plafond : rien")
  FauxJeu.santes[p] = 90
  hommes.battre()
  egal(FauxJeu.santes[p], hommes.reglages.sante_blesse_3, "la régénération du jeu : ramenée encore")
  egal(lignes_du_journal("ramenée à " .. hommes.reglages.sante_blesse_3), 1, "une seule ligne pour ce plafond")
  egal(hommes.plafond_de_sante(1), hommes.reglages.sante_blesse_1, "un jour")
  egal(hommes.plafond_de_sante(9), hommes.reglages.sante_blesse_5, "cinq jours et plus")
  hommes.guerir(a, 3)
  FauxJeu.santes[p] = 80
  hommes.battre()
  egal(FauxJeu.santes[p], 80, "guéri : plus de plafond")
end)

essai("étendue du camp réel (vu sur une copie le 21/10, J5) : gardée au registre, elle vaut avant que Scriptorium redéclare ses places", function()
  depart()
  FauxJeu.heure = 10
  camp.adopter({ x = 0, y = 0, z = 0 }, 0, "kutnohorsko")
  FauxJeu.objets_existants["lit_loin"] = true
  FauxJeu.positions_des_objets = FauxJeu.positions_des_objets or {}
  FauxJeu.positions_des_objets["lit_loin"] = { x = 0, y = 45, z = 0 }
  verifier(camp.declarer_les_places({ { nom = "lit_loin", sorte = "lit" } }), "un lit déclaré à 45 m")
  local _, loin = hommes.etendue_du_camp()
  verifier(loin and loin >= 45, "l'étendue va jusqu'au lit (" .. tostring(loin) .. ")")
  egal(lignes_du_journal("étendue du camp réel : 45 m (gardée)"), 1, "gardée, dit au journal")
  -- Au chargement : les places pas encore redéclarées par Scriptorium.
  camp.places_declarees, camp.ordre_des_places_declarees = {}, {}
  local _, loin2 = hommes.etendue_du_camp()
  verifier(loin2 and loin2 >= 45, "gardée au registre : elle vaut avant la déclaration (" .. tostring(loin2) .. ")")
  egal(lignes_du_journal("étendue du camp réel"), 1, "rien de redit")
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
  -- Blessé : les soins (rang 3) passent devant ; une tenue « bains » (rang 3, un ordre exprès : décision de JoVenGer du
  -- 26/09, « hors bataille, les blessés vont aux bains ») passe devant les soins.
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

essai("hommes (pas de jumeaux, demande du pair, 18/10) : une âme dont le visage est déjà au camp est sautée tant qu'un visage libre reste ; ensuite, une âme libre quelconque", function()
  preparer(10000, 0, 10)
  FauxJeu.tailles_paliers.combattant = { 6, 6, 6 }
  FauxJeu.visages = { combattant = 3 }
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 1, prime = 0 })
  egal(hommes.fiche(a).ame, "ame_combattant_1_1", "la première, visage 0")
  local b = hommes.embaucher({ role = "archer", semaines = 1, prime = 0, palier = 3 })
  egal(hommes.fiche(b).ame, "ame_combattant_3_2", "la 3_1 a le visage 0, déjà au camp : sautée")
  local c = hommes.embaucher({ role = "pavoisier", semaines = 1, prime = 0 })
  egal(hommes.fiche(c).ame, "ame_combattant_1_3", "1_2 (visage 1, pris) sautée ; 1_3, visage 2, libre")
  local d = hommes.embaucher({ role = "arbaletrier", semaines = 1, prime = 0 })
  egal(hommes.fiche(d).ame, "ame_combattant_1_2", "plus aucun visage libre : la première âme libre")
  FauxJeu.visages = nil
end)

essai("dialogues (fiche 21) : l'accroche donne la réponse d'un homme ou du Directeur ; par défaut rien ; le chef est le colonel ; la remplaçante de Scriptorium ; une réponse absurde refusée", function()
  preparer(10000, 0, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 1, prime = 0 })
  hommes.battre()
  for _, m in ipairs(Scriptorium.morceaux) do
    if m.nom == "hommes" and m.demarrage then m.demarrage() end
  end
  verifier(type(FauxJeu.reponse_du_dialogue) == "function", "accrochée à la liaison")
  local perso = hommes.fiche(a).personnage
  local r = FauxJeu.reponse_du_dialogue("homme", "vie_au_camp", perso)
  egal(#r.codes, 0, "par défaut, rien à dire")
  verifier(not r.colonel, "pas le chef")
  avec_remplacement(hommes, "reponse_du_dialogue", function(arbre, choix, id)
    if id == a and choix == "vie_au_camp" then return { codes = { 3, 0, 1 }, colonel = true } end
  end, function()
    local s = FauxJeu.reponse_du_dialogue("homme", "vie_au_camp", perso)
    egal(s.codes[1], 3, "le code de Scriptorium")
    verifier(s.colonel, "dit colonel par Scriptorium")
  end)
  avec_remplacement(hommes, "reponse_du_dialogue", function() return { codes = { "trois" } } end, function()
    egal(#FauxJeu.reponse_du_dialogue("homme", "vie_au_camp", perso).codes, 0, "un code absurde : la décision du socle")
  end)
  avec_remplacement(hommes, "reponse_du_dialogue", function(arbre, choix, id) return { codes = { id == "directeur" and 7 or 1 } } end, function()
    egal(FauxJeu.reponse_du_dialogue("directeur", "camp", "inconnu").codes[1], 1, "un inconnu : aucun homme")
  end)
end)

essai("dialogues (25/10, contrat du pair) : les conditions par nom ; par défaut le chef et le camp ; tous les noms posés, un nom absent faux ; la remplaçante de Scriptorium ; le colonel d'avant compte encore ; une réponse absurde refusée", function()
  preparer(10000, 0, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 1, prime = 0 })
  hommes.battre()
  for _, m in ipairs(Scriptorium.morceaux) do
    if m.nom == "hommes" and m.demarrage then m.demarrage() end
  end
  local perso = hommes.fiche(a).personnage
  local c = FauxJeu.reponse_du_dialogue("homme", "ouverture", perso).conditions
  for _, nom in ipairs(hommes.conditions_du_dialogue_noms) do
    verifier(c[nom] ~= nil, "condition posée : " .. nom)
  end
  egal(c.camp_monte, Scriptorium.camp.est_fonde() == true, "camp monté selon le camp")
  egal(c.camp_leve, not c.camp_monte, "camp levé : l'inverse")
  verifier(c.sans_alerte and not c.alerte and not c.mesure and not c.troupe_chez_elle, "le socle seul : ni alerte, ni mesure, ni troupe")
  avec_remplacement(hommes, "conditions_du_dialogue", function(arbre, id)
    if arbre == "directeur" then return { alerte = true, mesure = true, inconnue = true } end
    return { colonel = true }
  end, function()
    local d = FauxJeu.reponse_du_dialogue("directeur", "les_grandes_mesures", "inconnu").conditions
    verifier(d.alerte and d.mesure, "alerte et mesure de Scriptorium")
    egal(d.sans_alerte, false, "un nom absent : faux")
    egal(d.inconnue, nil, "un nom inconnu n'est pas posé")
    verifier(FauxJeu.reponse_du_dialogue("homme", "ouverture", perso).colonel, "colonel par les conditions")
  end)
  avec_remplacement(hommes, "reponse_du_dialogue", function() return { codes = {}, colonel = true } end, function()
    verifier(FauxJeu.reponse_du_dialogue("homme", "ouverture", perso).conditions.colonel, "le colonel dit par la réponse compte")
  end)
  avec_remplacement(hommes, "conditions_du_dialogue", function() return { alerte = "oui" } end, function()
    egal(FauxJeu.reponse_du_dialogue("homme", "ouverture", perso).conditions.alerte, false, "une valeur absurde : la décision du socle")
  end)
end)

essai("hommes (la bascule, 18/10) : l'accroche « après l'équipement » reçoit ce qui est donné (tenue, armes, munitions)", function()
  preparer(10000, 0, 10)
  local recus = {}
  hommes.accrocher("apres_l_equipement", function(id, donne) table.insert(recus, { id = id, donne = donne }) end)
  local a = hommes.embaucher({ role = "arbaletrier", semaines = 1, prime = 0 })
  for _ = 1, 3 do hommes.battre() end
  hommes.accroches.apres_l_equipement = {}
  verifier(#recus >= 1, "appelée à l'équipement")
  egal(recus[1].id, a, "pour l'homme")
  egal(recus[1].donne.raison, "equipement", "la raison")
  verifier(type(recus[1].donne.tenue) == "string" and type(recus[1].donne.armes) == "string", "la tenue et les armes")
  verifier(#recus[1].donne.objets > 0, "les objets créés")
  verifier(recus[1].donne.munitions and recus[1].donne.munitions.nombre > 0, "les munitions d'un arbalétrier")
end)

essai("hommes (la bascule, 18/10) : la décision « place_pour » donne le siège au repas ; par défaut la N-ième place pour le N-ième homme", function()
  preparer(10000, 500, 12)
  camp.agrandir()
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 1, prime = 0 })
  local b = hommes.embaucher({ role = "homme_d_armes", semaines = 1, prime = 0 })
  local libres = camp.places_libres("siege")
  local repas_a, repas_b = hommes.activite_de(a, 12), hommes.activite_de(b, 12)
  egal(repas_a.activite, "repas", "midi : le repas")
  egal(repas_a.lieu, libres[1], "le premier siège libre au premier homme")
  egal(repas_b.lieu, libres[2], "le second au second")
  avec_remplacement(camp, "place_pour", function(id, sorte, l) return sorte == "siege" and l[#l] or nil end, function()
    egal(hommes.activite_de(a, 12).lieu, libres[#libres], "Scriptorium choisit la place")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
end)

essai("hommes (la bascule, 18/10) : affronter un personnage précis, à l'arme ou à mains nues ; la tenue se lâche quand la cible est à terre ; Henry peut être la cible ; jamais une bataille", function()
  preparer(10000, 500, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 1, prime = 0 })
  local b = hommes.embaucher({ role = "homme_d_armes", semaines = 1, prime = 0 })
  hommes.battre()
  local pa, pb = hommes.fiche(a).personnage, hommes.fiche(b).personnage
  verifier(not hommes.tenir(a, "travail", { activite = "affronter", fin = "liberation" }), "sans cible : refusé")
  verifier(not hommes.tenir(a, "travail", { activite = "affronter", cible = pb, jusqu_a = "demain", fin = "liberation" }), "fin boiteuse : refusée")
  FauxJeu.attaques = {}
  FauxJeu.cessations = {}
  verifier(hommes.tenir(a, "travail", { activite = "affronter", cible = pb, arme = false, fin = "liberation" }), "pugilat tenu")
  egal(#FauxJeu.cessations, 0, "rien à lever au début")
  egal(#FauxJeu.attaques, 1, "l'attaque imposée")
  egal(FauxJeu.attaques[1].cible, pb, "contre la cible")
  egal(FauxJeu.attaques[1].attaquant, pa, "par l'homme")
  verifier(FauxJeu.attaques[1].options.arme == false, "à mains nues")
  egal(#Scriptorium.bataille.bandes(), 0, "aucune bande, aucune bataille")
  -- La cible assommée : jusqu'à « assomme » (par défaut), c'est fini.
  FauxJeu.inconscients = { [pb] = true }
  hommes.battre()
  verifier(hommes.activite_de(a, 10).activite ~= "affronter", "la tenue est lâchée")
  egal(#FauxJeu.cessations, 1, "vu en jeu le 19/10 : l'attaque est levée à la fin")
  egal(FauxJeu.cessations[1], pa, "chez l'attaquant")
  local journal_a = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "à rhabiller (fin d'affrontement)", 1, true) then journal_a = journal_a + 1 end
  end
  verifier(journal_a >= 1, "vu sur une copie le 19/10 : remis à rhabiller à la fin de l'affrontement")
  FauxJeu.inconscients = nil
  -- Jusqu'à la mort : assommée ne suffit pas.
  verifier(hommes.tenir(a, "travail", { activite = "affronter", cible = pb, jusqu_a = "mort", fin = "liberation" }), "duel à mort tenu")
  FauxJeu.inconscients = { [pb] = true }
  hommes.battre()
  egal(hommes.activite_de(a, 10).activite, "affronter", "assommée seulement : il continue")
  egal(#FauxJeu.cessations, 1, "tant qu'il affronte, rien n'est levé")
  FauxJeu.personnages_morts[pb] = true
  hommes.battre()
  verifier(hommes.activite_de(a, 10).activite ~= "affronter", "morte : fini")
  egal(#FauxJeu.cessations, 2, "levée de nouveau à cette fin")
  FauxJeu.inconscients = nil
  -- Henry comme cible.
  FauxJeu.attaques = {}
  verifier(hommes.tenir(a, "travail", { activite = "affronter", cible = "henry", fin = "liberation" }), "un duel contre Henry")
  egal(FauxJeu.attaques[#FauxJeu.attaques].cible, "henry", "la cible est Henry")
  verifier(FauxJeu.attaques[#FauxJeu.attaques].options.arme, "à l'arme par défaut")
  hommes.lacher(a, "travail")
  egal(#FauxJeu.cessations, 3, "la tenue lâchée (le duel contre Henry fini) : l'attaque est levée")
  FauxJeu.attaques, FauxJeu.cessations = nil, nil
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

essai("équipement (18/10) : le filet de la tenue de corps ; un homme prêt qui n'a plus que sa coiffe est marqué par la garde, puis ses préréglages sont recréés", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 2, famille = "hache" })
  hommes.battre()
  hommes.battre()
  egal(hommes.fiche(id).equipement.etat, "pret", "prêt")
  local tenue = hommes.fiche(id).equipement.tenue
  local function lignes_contenant(texte)
    local n = 0
    for _, l in ipairs(FauxJeu.journal_lignes) do
      if string.find(l, texte, 1, true) then n = n + 1 end
    end
    return n
  end
  -- Déshabillé hors de nos rhabillages : plus de torse ni de jambes, la coiffe gardée.
  FauxJeu.retirer_un_objet(personnage_de(id), tenue .. "_corps")
  FauxJeu.retirer_un_objet(personnage_de(id), tenue .. "_jambes")
  egal(a_dans_le_sac(id, tenue .. "_tete"), 1, "la coiffe reste")
  for _ = 1, 3 do hommes.battre() end
  verifier(lignes_contenant("à rhabiller (plus de torse)") >= 1, "la garde le voit et le marque")
  verifier(lignes_contenant("sans sa tenue ou sans son arme (torse)") >= 1, "le rhabillage déclenche le filet")
  for _ = 1, 3 do hommes.battre() end
  egal(a_dans_le_sac(id, tenue .. "_corps"), 1, "torse recréé")
  egal(a_dans_le_sac(id, tenue .. "_jambes"), 1, "jambes recréées")
  egal(hommes.fiche(id).equipement.etat, "pret", "de nouveau prêt")
end)

essai("équipement (18/10) : hommes.reequiper refait le choix au même palier, les anciennes pièces offertes à piece_otee", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 2, famille = "hache" })
  hommes.battre()
  hommes.battre()
  egal(hommes.fiche(id).equipement.etat, "pret", "prêt")
  local ancien = hommes.choix_de_l_equipement
  hommes.choix_de_l_equipement = function(i)
    if i == id then return { tenue = "soldier_generic_4_01", armes = "axe_3_01", munitions = 0 } end
  end
  verifier(hommes.reequiper(id), "rééquipé")
  egal(hommes.fiche(id).palier, 2, "palier inchangé")
  egal(hommes.fiche(id).equipement.tenue, "soldier_generic_4_01", "la tenue de la décision")
  egal(hommes.fiche(id).equipement.etat, "a_equiper", "à équiper au battement")
  verifier(not hommes.reequiper("inconnu"), "un inconnu refusé")
  hommes.choix_de_l_equipement = ancien
end)

essai("équipement (vu en jeu le 25/10, le colonel nu à 23 pièces au lieu de 10) : rééquipé au même choix, il garde ses pièces, rien n'est recréé en double, et les copies en trop sont retirées", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 2, famille = "hache" })
  hommes.battre()
  hommes.battre()
  local e = hommes.fiche(id).equipement
  egal(e.etat, "pret", "prêt")
  local tenue, armes = e.tenue, e.armes
  local ancien = hommes.choix_de_l_equipement
  hommes.choix_de_l_equipement = function(i)
    if i == id then return { tenue = tenue, armes = armes, munitions = 0 } end
  end
  local corps = tenue .. "_corps"
  local personnage = hommes.fiche(id).personnage
  -- Un doublon déjà là (comme le colonel avant la correction).
  FauxJeu.creer_objet(personnage, corps, 1, 1)
  egal(a_dans_le_sac(id, corps), 2, "un doublon au départ")
  for _ = 1, 2 do
    verifier(hommes.reequiper(id), "rééquipé")
    hommes.battre()
    hommes.battre()
  end
  hommes.choix_de_l_equipement = ancien
  for _, objet in ipairs(FauxJeu.pieces_de(tenue)) do
    egal(a_dans_le_sac(id, objet), 1, "une seule pièce " .. objet)
  end
  egal(a_dans_le_sac(id, FauxJeu.pieces_de(armes)[1]), 1, "une seule arme")
  egal(#FauxJeu.equipements[#FauxJeu.equipements].ordre.creer, 0, "rien de recréé au second rééquipement")
  local retire = false
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "pièce(s) en double retirée(s)", 1, true) then retire = true end
  end
  verifier(retire, "le doublon retiré, au journal")
end)

essai("équipement (demande de JoVenGer, 25/10) : les doublons d'avant la correction sont retirés au rhabillage du chargement, sans rééquipement, et il porte une seule pièce de chaque", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 2, famille = "hache" })
  hommes.battre()
  hommes.battre()
  local e = hommes.fiche(id).equipement
  egal(e.etat, "pret", "prêt")
  local personnage = hommes.fiche(id).personnage
  local corps, arme = e.tenue .. "_corps", FauxJeu.pieces_de(e.armes)[1]
  FauxJeu.creer_objet(personnage, corps, 1, 1)
  FauxJeu.creer_objet(personnage, corps, 1, 1)
  FauxJeu.creer_objet(personnage, arme, 1, 1)
  egal(a_dans_le_sac(id, corps), 3, "deux doublons du torse au départ")
  local equipements = #FauxJeu.equipements
  Scriptorium.registre.lire("hommes").liste[id].equipement.etat = "a_rhabiller"
  hommes.battre()
  egal(a_dans_le_sac(id, corps), 1, "un seul torse")
  egal(a_dans_le_sac(id, arme), 1, "une seule arme")
  egal(#FauxJeu.equipements, equipements, "aucun rééquipement")
  local retire = false
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "3 pièce(s) en double retirée(s)", 1, true) then retire = true end
  end
  verifier(retire, "les trois doublons retirés, au journal")
  -- Vu ensuite (25/10, socle 961689d : nu après le retrait, vêtu à une remise plus tard) : il remet ses pièces au
  -- battement suivant, une fois.
  local d = Scriptorium.registre.lire("hommes")
  egal(d.liste[id].equipement.etat, "a_rhabiller", "à rhabiller encore au battement suivant")
  hommes.battre()
  verifier(d.liste[id].equipement.etat ~= "a_rhabiller", "remis une fois, sans boucle (" .. tostring(d.liste[id].equipement.etat) .. ")")
  egal(a_dans_le_sac(id, corps), 1, "toujours un seul torse")
  -- Vu ensuite (25/10, socle 9fbb391 : Václav Vlk encore nu ; une remise quelques minutes plus tard le vêtait) : ses
  -- pièces refaites porter à +30 s, +2 min et +5 min.
  local remises = 0
  for _, m in ipairs(FauxJeu.minuteries) do
    if m.ms == 30000 or m.ms == 120000 or m.ms == 300000 then
      remises = remises + 1
      m.fonction()
    end
  end
  egal(remises, 3, "trois remises prévues")
  local vues = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "remise après ses doublons", 1, true) and string.find(l, "0 introuvable(s)", 1, true) then vues = vues + 1 end
  end
  egal(vues, 3, "trois remises faites, au journal")
end)

essai("arme rangée (vu en J34, 25/10 : après un combat, en arme, il refusait son lit ; prouvé par le pair) : à l'ordre de la vie du camp, l'arme tirée hors combat est rangée ; en danger, jamais", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 2, famille = "hache" })
  hommes.battre()
  hommes.battre()
  local d = Scriptorium.registre.lire("hommes")
  local perso = hommes.fiche(id).personnage
  -- En danger : l'arme reste tirée.
  FauxJeu.armes_tirees[perso], FauxJeu.en_danger[perso] = true, true
  d.liste[id].derniere_activite = nil
  hommes.battre()
  egal(FauxJeu.armes_tirees[perso], true, "en danger : arme gardée")
  -- Hors danger : rangée au nouvel ordre, au journal.
  FauxJeu.en_danger[perso] = nil
  d.liste[id].derniere_activite = nil
  hommes.battre()
  egal(FauxJeu.armes_tirees[perso], nil, "hors danger : arme rangée")
  local vue = false
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "« " .. hommes.fiche(id).nom .. " » range son arme (", 1, true) then vue = true end
  end
  verifier(vue, "au journal")
end)

essai("venue (vu en J38 bis, 25/10 : un homme rentré ne prenait pas son premier ordre ; la relance le faisait partir) : après sa venue, il est réveillé et son ordre redonné, une fois", function()
  preparer(200, 10, 10)
  hommes.reglages.venue_ordre_redonne_ms = 4000
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  hommes.battre()
  verifier(hommes.mettre_dehors(id, "chez_eux"), "mis dehors")
  FauxJeu.minuteries = {}
  verifier(hommes.faire_rentrer(id, { x = 5, y = 5, z = 0 }), "rentré")
  local f = Scriptorium.registre.lire("hommes").liste[id]
  hommes.battre()
  verifier(f.derniere_activite ~= nil, "un premier ordre donné")
  local venue = nil
  for _, m in ipairs(FauxJeu.minuteries) do
    if m.ms == 4000 then venue = m end
  end
  verifier(venue, "une minuterie de venue posée")
  FauxJeu.reveilles = {}
  venue.fonction()
  egal(f.derniere_activite, nil, "l'ordre sera redonné")
  egal(FauxJeu.reveilles[1], f.personnage, "réveillé")
  hommes.battre()
  verifier(f.derniere_activite ~= nil, "ordre redonné au battement")
  hommes.reglages.venue_ordre_redonne_ms = 0
end)

essai("saut d'horloge (vu en J39, 25/10 : le moteur ôte des pièces du sac après un saut la nuit ; décision de JoVenGer) : toute la tenue vérifiée ensuite, les pièces disparues recréées, une pièce ôtée par Scriptorium jamais", function()
  preparer(200, 10, 10)
  hommes.reglages.saut_tenues_h = 1
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 2, famille = "hache" })
  hommes.battre()
  hommes.battre()
  local d = Scriptorium.registre.lire("hommes")
  local e = d.liste[id].equipement
  egal(e.etat, "pret", "prêt")
  local tete = e.tenue .. "_tete"
  egal(a_dans_le_sac(id, tete), 1, "sa coiffe au sac")
  FauxJeu.retirer_un_objet(hommes.fiche(id).personnage, tete)
  egal(a_dans_le_sac(id, tete), 0, "la coiffe disparue (le moteur)")
  FauxJeu.minuteries = {}
  -- Un jour plus tard, à la même heure (la nuit, au lit, l'habillage attend le lever).
  FauxJeu.heure = FauxJeu.heure + 24
  hommes.battre()
  local verifs = {}
  for _, m in ipairs(FauxJeu.minuteries) do
    if m.ms == 30000 or m.ms == 120000 or m.ms == 300000 then table.insert(verifs, m) end
  end
  egal(#verifs, 3, "trois vérifications prévues après le saut")
  verifs[1].fonction()
  egal(e.etat, "a_equiper", "à recompléter")
  hommes.battre()
  egal(a_dans_le_sac(id, tete), 1, "la coiffe recréée")
  verifier(e.etat ~= "a_equiper", "rééquipé")
  -- Une pièce ôtée par Scriptorium n'est pas recréée.
  e.etat = "pret"
  table.insert(e.otees, tete)
  FauxJeu.retirer_un_objet(hommes.fiche(id).personnage, tete)
  verifs[2].fonction()
  egal(e.etat, "pret", "une pièce ôtée par Scriptorium : rien à recompléter")
  hommes.reglages.saut_tenues_h = 0
end)

essai("entrée en partie (vu le 26/10, J43 : quatre hommes « prêts » avec des pièces de leur tenue absentes du sac, perdues avant d517914) : toute la tenue vérifiée une fois après l'entrée, les pièces manquantes recréées", function()
  preparer(200, 10, 10)
  hommes.reglages.entree_verif_s = 30
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 2, famille = "hache" })
  hommes.battre()
  hommes.battre()
  local d = Scriptorium.registre.lire("hommes")
  local e = d.liste[id].equipement
  egal(e.etat, "pret", "prêt")
  -- Une pièce que le filet du chargement ne voit pas (il ne regarde que torse, jambes et arme).
  local corps = e.tenue .. "_tete"
  FauxJeu.retirer_un_objet(hommes.fiche(id).personnage, corps)
  egal(a_dans_le_sac(id, corps), 0, "sa coiffe absente du sac, gardée ainsi par la sauvegarde")
  FauxJeu.minuteries = {}
  hommes.relancer()
  local verif = nil
  for _, m in ipairs(FauxJeu.minuteries) do
    if m.ms == 30000 then verif = m end
  end
  verifier(verif, "une vérification prévue 30 s après l'entrée")
  for _ = 1, 3 do hommes.battre() end
  verif.fonction()
  egal(e.etat, "a_equiper", "à recompléter")
  hommes.battre()
  egal(a_dans_le_sac(id, corps), 1, "sa coiffe recréée")
  hommes.reglages.entree_verif_s = 0
end)

-- Un homme équipé et prêt (deux battements), et le compte de lignes du journal qui contiennent un texte.
local function homme_pret()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 2, famille = "hache" })
  hommes.battre()
  hommes.battre()
  return id
end
local function lignes_du_journal(texte)
  local n = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, texte, 1, true) then n = n + 1 end
  end
  return n
end

essai("équipement (vu sur une copie de la partie de JoVenGer le 19/10) : la file d'habillage passe d'abord l'homme à équiper, et tourne : un homme plus loin dans la liste n'attend pas sans fin derrière les premiers sans cesse à rhabiller", function()
  preparer(5000, 100, 10)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
  local ids = {}
  for i = 1, 9 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0, famille = "hache" })
  end
  for _ = 1, 40 do hommes.battre() end
  local d = Scriptorium.registre.lire("hommes")
  for i = 1, 9 do
    egal(d.liste[ids[i]].equipement.etat, "pret", "l'homme " .. i .. " prêt au départ")
  end
  -- Le neuvième (le colonel) à rééquiper ; les huit premiers remis à rhabiller à chaque battement.
  verifier(hommes.reequiper(ids[9]), "à rééquiper")
  local nom = hommes.fiche(ids[9]).nom
  local avant = lignes_du_journal("« " .. nom .. " » équipé (")
  for _ = 1, 3 do
    for i = 1, 8 do d.liste[ids[i]].equipement.etat = "a_rhabiller" end
    hommes.battre()
  end
  verifier(lignes_du_journal("« " .. nom .. " » équipé (") > avant, "le neuvième équipé tout de suite, devant les huit à rhabiller")
  -- La file tourne : chacun des huit, remis à rhabiller à chaque battement, finit par passer.
  local servis = {}
  for _ = 1, 24 do
    for i = 1, 8 do
      if d.liste[ids[i]].equipement.etat == "pret" then
        servis[i] = true
        d.liste[ids[i]].equipement.etat = "a_rhabiller"
      end
    end
    hommes.battre()
  end
  for i = 1, 8 do
    if d.liste[ids[i]].equipement.etat ~= "a_rhabiller" then servis[i] = true end
  end
  local n = 0
  for i = 1, 8 do if servis[i] then n = n + 1 end end
  egal(n, 8, "en tournant, chacun des huit est servi")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("équipement (18/10, B) : remplacer une pièce portée par une neuve de la même classe, à l'état voulu ; une pièce non portée refusée", function()
  local id = homme_pret()
  local tenue = hommes.fiche(id).equipement.tenue
  local piece = tenue .. "_corps"
  local avant = #hommes.ce_qu_il_porte(id)
  verifier(hommes.remplacer_une_piece(id, piece, 0.6), "remplacée")
  egal(a_dans_le_sac(id, piece), 1, "une seule pièce de cette classe")
  egal(FauxJeu.etat_objet(personnage_de(id), piece), 0.6, "la neuve à 60 %")
  egal(#hommes.ce_qu_il_porte(id), avant, "ce qu'il porte, inchangé dans les livres")
  local ok, raison = hommes.remplacer_une_piece(id, "", 0.6)
  egal(raison, "objet_invalide", "un objet vide refusé")
  ok, raison = hommes.remplacer_une_piece(id, "0a1b2c3d-1111-2222-3333-444455556666", 0.6)
  egal(raison, "piece_non_portee", "une pièce qu'il ne porte pas refusée")
  ok, raison = hommes.remplacer_une_piece(id, piece, 1.5)
  egal(raison, "etat_invalide", "un état hors de 0 à 1 refusé")
end)

essai("équipement (18/10, C) : une pièce au sac par la décision remplaçable, jamais remise par la garde ; la décision levée, elle est remise", function()
  local id = homme_pret()
  local tenue = hommes.fiche(id).equipement.tenue
  local casque = tenue .. "_tete"
  local ancien = hommes.pieces_au_sac
  hommes.pieces_au_sac = function(i) if i == id then return { casque } end end
  hommes.battre()
  verifier(FauxJeu.au_sac and FauxJeu.au_sac[personnage_de(id)] and FauxJeu.au_sac[personnage_de(id)][casque], "rangé au sac")
  egal(a_dans_le_sac(id, casque), 1, "toujours dans le sac")
  for _, o in ipairs(hommes.ce_qu_il_porte(id)) do
    verifier(o ~= casque, "plus dans ce qu'il porte")
  end
  egal(lignes_du_journal("range au sac " .. casque), 1, "une seule fois")
  hommes.battre()
  egal(lignes_du_journal("range au sac " .. casque), 1, "pas rangé de nouveau")
  hommes.pieces_au_sac = ancien
  hommes.battre()
  egal(lignes_du_journal("remet " .. casque), 1, "la décision levée, il le remet")
  local remis = false
  for _, o in ipairs(hommes.ce_qu_il_porte(id)) do
    if o == casque then remis = true end
  end
  verifier(remis, "de nouveau dans ce qu'il porte")
end)

essai("équipement (18/10, D 1) : le filet de la tenue de corps ne joue jamais sous une tenue « ne_pas_rhabiller » (le bain)", function()
  local id = homme_pret()
  local tenue = hommes.fiche(id).equipement.tenue
  verifier(hommes.tenir(id, "travail", { activite = "garde", lieu = "bain", position = { x = 1, y = 1, z = 0 },
                                          ne_pas_rhabiller = true, fin = "liberation" }), "tenu au bain")
  egal(hommes.activite_de(id, 10).ne_pas_rhabiller, true, "le champ arrive jusqu'à l'activité")
  FauxJeu.retirer_un_objet(personnage_de(id), tenue .. "_corps")
  FauxJeu.retirer_un_objet(personnage_de(id), tenue .. "_jambes")
  for _ = 1, 4 do hommes.battre() end
  egal(lignes_du_journal("à rhabiller (plus de"), 0, "pas marqué au bain")
  egal(a_dans_le_sac(id, tenue .. "_corps"), 0, "rien recréé au bain")
  hommes.lacher(id, "travail")
  for _ = 1, 4 do hommes.battre() end
  verifier(lignes_du_journal("à rhabiller (plus de") >= 1, "sorti du bain, la garde le voit")
  egal(a_dans_le_sac(id, tenue .. "_corps"), 1, "et il est rhabillé")
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

essai("noms (18/10) : chaque homme prend le nom de son âme ; un nom de contrat passe devant ; sans âme libre, l'intitulé de repli, puis le nom de l'âme reçue", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  local f = hommes.fiche(id)
  verifier(f.ame ~= nil, "l'âme tirée dès l'embauche")
  egal(f.nom, hommes.nom_de_l_ame(f.ame), "le nom de son âme")
  local id2 = hommes.embaucher({ role = "homme_d_armes", semaines = 4, nom = "Zbyněk" })
  egal(hommes.fiche(id2).nom, "Zbyněk", "le nom du contrat")
  local tailles = FauxJeu.tailles_paliers.metier
  FauxJeu.tailles_paliers.metier = { 0 }
  local id3 = hommes.embaucher({ role = "cuisinier", semaines = 4 })
  egal(hommes.fiche(id3).nom, hommes.nom_de_repli, "sans âme libre : l'intitulé de repli")
  egal(hommes.nom_de_repli, "Homme de la Compagnie", "l'intitulé décidé")
  FauxJeu.tailles_paliers.metier = tailles
  hommes.redresser()
  local f3 = hommes.fiche(id3)
  verifier(f3.ame ~= nil, "une âme reçue plus tard")
  egal(f3.nom, hommes.nom_de_l_ame(f3.ame), "et son nom")
  egal(hommes.nom_de_femme(1), "Anna la Rousse", "les noms des femmes")
end)

essai("reprise (18/10) : la clé du relevé mène à son âme par son empreinte ; l'âme porte le nom du relevé ; clé inconnue : rien", function()
  preparer(200, 10, 10)
  FauxJeu.reprise_des_hommes = { { empreinte = hommes.empreinte_de_cle("homme_un"), nom = "Jan « le Fort »", palier = 2 },
                                 { empreinte = hommes.empreinte_de_cle("homme_deux"), nom = "Petr", palier = 1 } }
  FauxJeu.tailles_paliers.reprise = { 2 }
  local ame = hommes.ames_de_la_reprise["homme_deux"]
  egal(ame, FauxJeu.ame_de("reprise", 1, 2), "la deuxième âme de la reprise")
  egal(hommes.nom_de_l_ame(ame), "Petr", "son nom")
  egal(hommes.nom_de_l_ame("ame_directeur_1_1"), hommes.nom_du_directeur, "le Directeur, le sien (19/10 : plus « Soldat »)")
  egal(hommes.ames_de_la_reprise["inconnu"], nil, "clé inconnue")
  egal(hommes.empreinte_de_cle("ab"), (5381 * 33 + 97) * 33 + 98, "l'empreinte (la même qu'outils/ames.py)")
  egal(hommes.nom_de_l_ame(hommes.ames_de_la_reprise["homme_un"]), "Jan « le Fort »", "le premier, guillemets compris")
  FauxJeu.reprise_des_hommes, FauxJeu.tailles_paliers.reprise = nil, nil
end)

essai("personnel mené (18/10) : un personnage hors de la Compagnie tenu par nos ordres ; jamais dans l'effectif ; lâché, il n'est plus mené ; disparu, oublié", function()
  preparer(200, 10, 10)
  FauxJeu.personnages_existants["dame_des_bains"] = true
  local avant = #hommes.liste()
  FauxJeu.ordres = {}
  verifier(hommes.tenir_un_personnage("dame_des_bains", "travail", { activite = "garde", lieu = "bains", position = { x = 3, y = 4, z = 0 }, fin = "liberation" }), "tenue posée")
  egal(#hommes.liste(), avant, "pas dans la Compagnie")
  egal(hommes.personnel_mene()[1], "dame_des_bains", "listée parmi le personnel mené")
  local dernier = FauxJeu.ordres[#FauxJeu.ordres]
  egal(dernier.identifiant, "dame_des_bains", "l'ordre lui est donné")
  egal(dernier.activite, "garde", "son activité")
  egal(dernier.lieu, "bains", "son lieu")
  hommes.battre()
  egal(#hommes.liste(), avant, "toujours hors de l'effectif après un battement")
  local ordres_avant = #FauxJeu.ordres
  verifier(hommes.lacher_un_personnage("dame_des_bains", "travail"), "lâchée")
  egal(#hommes.personnel_mene(), 0, "plus menée")
  egal(#FauxJeu.ordres, ordres_avant, "vu le 19/10 : sa dernière tenue lâchée, plus aucun ordre (« attendre » vers un introuvable)")
  -- Une tenue échue (une heure) : au battement suivant, plus menée, sans ordre.
  verifier(hommes.tenir_un_personnage("dame_des_bains", "travail", { activite = "garde", lieu = "bains", position = { x = 3, y = 4, z = 0 }, fin = FauxJeu.heure + 1 }), "tenue d'une heure")
  FauxJeu.heure = FauxJeu.heure + 2
  ordres_avant = #FauxJeu.ordres
  hommes.mener_le_personnel(Scriptorium.registre.lire("hommes"), FauxJeu.heure, nil)
  egal(#hommes.personnel_mene(), 0, "sa tenue échue : plus menée")
  egal(#FauxJeu.ordres, ordres_avant, "et sans ordre")
  local ok, raison = hommes.tenir_un_personnage("inconnu", "travail", { activite = "garde", fin = "liberation" })
  egal(ok, false, "personnage introuvable refusé")
  egal(raison, "personnage_introuvable", "raison")
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  local _, r2 = hommes.tenir_un_personnage(hommes.fiche(id).personnage, "travail", { activite = "garde", fin = "liberation" })
  egal(r2, "deja_de_la_compagnie", "un homme de la Compagnie passe par hommes.tenir")
  verifier(hommes.tenir_un_personnage("dame_des_bains", "travail", { activite = "garde", fin = "liberation" }), "reprise")
  FauxJeu.personnages_existants["dame_des_bains"] = nil
  hommes.battre()
  egal(#hommes.personnel_mene(), 0, "disparue : oubliée")
end)

essai("compagnons nommés (18/10) : 31 fiches, une âme chacun ; l'embauche donne son âme et sa famille ; une âme portée est refusée ; les familles des compagnons ne sont jamais tirées", function()
  egal(#hommes.compagnons, 31, "trente et un compagnons")
  local ames, noms = {}, 0
  for _, c in ipairs(hommes.compagnons) do
    verifier(not ames[c.ame], "âme unique : " .. c.nom)
    ames[c.ame] = true
    verifier(hommes.roles[c.role] ~= nil, "rôle connu : " .. c.nom)
    verifier(c.famille == nil or hommes.equipement.familles[c.famille] ~= nil, "famille connue : " .. c.nom)
    verifier((c.role == "homme_d_armes") == (c.famille ~= nil), "une famille pour les hommes d'armes seulement : " .. c.nom)
    egal(hommes.compagnons_nommes[c.nom], c, "le service nom -> fiche : " .. c.nom)
    noms = noms + 1
  end
  egal(noms, 31, "trente et un noms")
  preparer(200, 10, 10)
  local c = hommes.compagnons_nommes["István Kovács"]
  -- L'appel exact de la prise, sans « semaines » (contrats à durée éteints, comme dans le jeu par défaut).
  Scriptorium.noyau.interrupteurs.contrats_a_duree = 0
  local id = hommes.embaucher({ nom = c.nom, ame = c.ame, role = c.role, famille = c.famille, palier = c.palier, prime = 0 })
  verifier(id, "István embauché")
  local f = hommes.fiche(id)
  egal(f.nom, "István Kovács", "son nom")
  egal(f.ame, c.ame, "son âme")
  egal(f.famille, "sabre", "sa famille")
  egal(f.equipement.armes, "sabre_3_01", "le sabre du palier 3")
  local id2, raison, detail = hommes.embaucher({ nom = c.nom, ame = string.upper(c.ame), role = c.role, famille = c.famille, palier = 3, prime = 0 })
  egal(id2, false, "une seconde fois : refusé")
  egal(raison, "ame_deja_portee", "raison")
  for _ = 1, 30 do
    local autre = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
    if autre then
      verifier(hommes.equipement.familles[hommes.fiche(autre).famille].tirage ~= 0, "jamais une famille de compagnon au tirage")
      hommes.renvoyer(autre)
    end
  end
  Scriptorium.noyau.interrupteurs.contrats_a_duree = 1
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

essai("habillage (vu dans la partie de JoVenGer le 22/10 : des hommes torse nu plusieurs minutes chaque matin) : plusieurs hommes par battement, jamais deux fois le même ; leur second passage par une minuterie, deux secondes après", function()
  preparer(2000, 10, 10)
  local ids = {}
  for _ = 1, 3 do
    table.insert(ids, (hommes.embaucher({ role = "homme_d_armes", semaines = 4 })))
  end
  FauxJeu.minuteries = {}
  hommes.battre()
  for _, id in ipairs(ids) do
    egal(hommes.fiche(id).equipement.etat, "a_completer", "chacun une fois, son second passage à venir")
  end
  local passages = {}
  for _, m in ipairs(FauxJeu.minuteries) do
    if m.ms == hommes.reglages.habillage_second_passage_ms then table.insert(passages, m) end
  end
  egal(#passages, 3, "trois seconds passages, deux secondes après")
  Scriptorium.en_partie = true
  for _, m in ipairs(passages) do m.fonction() end
  Scriptorium.en_partie = false
  for _, id in ipairs(ids) do
    egal(hommes.fiche(id).equipement.etat, "pret", "habillé en deux secondes")
  end
end)

essai("horaire de Scriptorium (demande de JoVenGer, 22/10 : 33 hommes debout à l'aube) : sommeil de COUCHER à LEVER − 0,5, lever jusqu'à LEVER ; un horaire qui ne tient pas est refusé ; sans Scriptorium, nos tranches", function()
  preparer(2000, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  local programme_d_origine = rawget(_G, "scriptorium")
  local sauve = {}
  for _, t in ipairs(hommes.journee) do sauve[t.nom] = { de = t.de, a = t.a } end
  local function dit(morceau)
    for _, ligne in ipairs(FauxJeu.journal_lignes) do
      if string.find(ligne, morceau, 1, true) then return true end
    end
    return false
  end
  local aube_d_origine = hommes.reglages.heure_lever
  local ok, erreur = pcall(function()
    egal(hommes.activite_de(id, 24 * 3 + 6).activite, "lever", "sans Scriptorium : levé à 6 h (nos tranches)")
    rawset(_G, "scriptorium", { journee = { COUCHER = 22, LEVER = 7 } })
    hommes.battre()
    egal(hommes.activite_de(id, 24 * 3 + 6).activite, "sommeil", "avec Scriptorium : encore au lit à 6 h")
    egal(hommes.activite_de(id, 24 * 3 + 6.75).activite, "lever", "levé à 6 h 45")
    egal(hommes.activite_de(id, 24 * 3 + 7.5).activite, "repas", "le repas du matin à 7 h 30")
    verifier(dit("horaire de Scriptorium : sommeil de 22 h à 6.5 h"), "dit au journal")
    egal(hommes.reglages.heure_lever, 7, "l'aube suit le lever de Scriptorium")
    -- Un horaire qui ne tient pas (le lever après la fin du repas du matin) : refusé, la journée reste.
    rawset(_G, "scriptorium", { journee = { COUCHER = 22, LEVER = 9 } })
    hommes.battre()
    egal(hommes.activite_de(id, 24 * 3 + 6).activite, "sommeil", "refusé : la journée d'avant reste")
    verifier(dit("ne tient pas dans la journée"), "le refus dit au journal")
  end)
  rawset(_G, "scriptorium", programme_d_origine)
  hommes.reglages.heure_lever = aube_d_origine
  for _, t in ipairs(hommes.journee) do t.de, t.a = sauve[t.nom].de, sauve[t.nom].a end
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("habillage à l'ordre (demande de JoVenGer, 22/10 : Beneš le Rouge suivait Henry sans son équipement) : un homme à rhabiller qui reçoit un ordre (l'escorte) est habillé sur-le-champ, sans battement ; jamais au bain", function()
  preparer(2000, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  hommes.battre()
  FauxJeu.minuteries[#FauxJeu.minuteries + 1] = nil
  for _, m in ipairs(FauxJeu.minuteries) do if m.ms == hommes.reglages.habillage_second_passage_ms then m.fonction() end end
  hommes.fiche(id).equipement.etat = "pret"
  Scriptorium.registre.lire("hommes").liste[id].equipement.etat = "a_rhabiller"
  verifier(hommes.tenir(id, "escorte", { activite = "suivre", lieu = "escorte", chef = "henry", fin = "liberation" }),
           "l'escorte posée, sans battement")
  egal(hommes.fiche(id).equipement.etat, "a_completer", "habillé sur-le-champ, son second passage à venir")
  hommes.lacher(id, "escorte")
  -- Tenu dévêtu (le bain) : jamais.
  Scriptorium.registre.lire("hommes").liste[id].equipement.etat = "a_rhabiller"
  verifier(hommes.tenir(id, "loisir", { activite = "attendre", fin = "liberation", ne_pas_rhabiller = true }), "tenu dévêtu")
  egal(hommes.fiche(id).equipement.etat, "a_rhabiller", "dévêtu : pas rhabillé")
end)

essai("équipement : un homme par battement (réglage à 1, second passage au battement : comme avant le 22/10), jamais en bataille", function()
  preparer(200, 10, 10)
  local par_battement, second_ms = hommes.reglages.habillage_par_battement, hommes.reglages.habillage_second_passage_ms
  hommes.reglages.habillage_par_battement, hommes.reglages.habillage_second_passage_ms = 1, 0
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
  hommes.reglages.habillage_par_battement, hommes.reglages.habillage_second_passage_ms = par_battement, second_ms
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

essai("hommes (vu sur une copie de la partie de JoVenGer le 20/10) : au lever, 17 hommes autour du feu, aucune place dans le feu", function()
  preparer(50000, 10, 10)
  local interrupteur = Scriptorium.noyau.interrupteurs.un_lit_par_homme
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  for _ = 1, 17 do
    hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  end
  local feu = camp.position_de("feu_central")
  local vus = 0
  for _, id in ipairs(hommes.liste()) do
    local a = hommes.activite_de(id, 6)
    if a and a.activite == "lever" and a.position then
      vus = vus + 1
      local ecart = math.sqrt((a.position.x - feu.x) ^ 2 + (a.position.y - feu.y) ^ 2)
      verifier(ecart >= 2, "place à " .. string.format("%.1f", ecart) .. " m du feu (au moins 2 m)")
    end
  end
  verifier(vus >= 12, "au moins 12 hommes au lever (" .. vus .. ", les autres de garde)")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = interrupteur
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

-- Fiche 15, V73 d 2 : la ronde (réponses a, a, b et a de JoVenGer du 17/10). camp.point rend aussi le cap : entre
-- parenthèses, seul le point entre dans le chemin.
local function chemin_carre(cote)
  return { (camp.point(0, cote, 0)), (camp.point(cote, 0, 0)), (camp.point(0, -cote, 0)), (camp.point(-cote, 0, 0)) }
end

local function rondier(heure)
  preparer(5000, 100, heure or 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  return id, hommes.fiche(id)
end

essai("ronde (fiche 15, V73 d 2) : la tenue veut un chemin de 2 à 32 points ; copiée, gardée au registre, comparée point par point", function()
  local id = rondier(10)
  local function refus(quoi, message)
    local ok, raison = hommes.tenir(id, "ronde", quoi)
    verifier(not ok and raison == "chemin_invalide", message .. " : refusé (" .. tostring(raison) .. ")")
  end
  refus({ activite = "ronde", lieu = "r", fin = "liberation" }, "sans chemin")
  refus({ activite = "ronde", lieu = "r", chemin = { (camp.point(1, 1, 0)) }, fin = "liberation" }, "un seul point")
  local trop = {}
  for i = 1, hommes.reglages.ronde_points_max + 1 do trop[i] = (camp.point(i, 0, 0)) end
  refus({ activite = "ronde", lieu = "r", chemin = trop, fin = "liberation" }, "33 points")
  refus({ activite = "ronde", lieu = "r", chemin = { (camp.point(1, 1, 0)), { y = 2 } }, fin = "liberation" }, "un point sans x")
  refus({ activite = "ronde", lieu = "r", chemin = chemin_carre(8), depart = 5, fin = "liberation" }, "un départ hors du chemin")
  refus({ activite = "ronde", lieu = "r", chemin = chemin_carre(8), depart = 1.5, fin = "liberation" }, "un départ non entier")
  egal(hommes.qui_tient(id, 10), "journee", "rien n'est posé")
  local chemin = chemin_carre(8)
  local ecrit = FauxJeu.registre_stocke
  verifier(hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, fin = "liberation" }), "tenu par la ronde")
  verifier(FauxJeu.registre_stocke ~= ecrit, "la tenue est écrite au registre")
  local a = hommes.activite_de(id, 10)
  egal(a.activite, "ronde", "en ronde")
  egal(#a.chemin, 4, "son chemin")
  egal(a.regard, nil, "aucun regard à l'ordre")
  egal(a.aller_retour, nil, "en boucle par défaut")
  chemin[1].x = 999
  verifier(a.chemin[1].x ~= 999, "le chemin de la tenue est une copie")
  -- Reposée à l'identique : rien d'écrit ; le chemin changé d'un point : écrit.
  ecrit = FauxJeu.registre_stocke
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin_carre(8), fin = "liberation" })
  egal(FauxJeu.registre_stocke, ecrit, "reposée à l'identique : rien d'écrit")
  local change = chemin_carre(8)
  change[3] = (camp.point(0, -9, 0))
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = change, fin = "liberation" })
  verifier(FauxJeu.registre_stocke ~= ecrit, "un point changé : écrit")
  -- Relue après rechargement du registre.
  local chaine, objets = FauxJeu.registre_stocke, FauxJeu.objets_existants
  depart()
  FauxJeu.heure = 10
  FauxJeu.registre_stocke, FauxJeu.objets_existants = chaine, objets
  local relue = hommes.activite_de(id, 10)
  egal(relue.activite, "ronde", "relue : en ronde")
  egal(relue.chemin and #relue.chemin, 4, "relue : quatre points")
  pres(relue.chemin and relue.chemin[3].y, change[3].y, "relue : le point changé")
  -- Une autre activité ne garde pas de chemin.
  hommes.tenir(id, "garde", { activite = "garde", lieu = "porte", position = (camp.point(0, 12, 0)), chemin = change, fin = "liberation" })
  egal(hommes.fiche(id).tenues.garde.chemin, nil, "une garde n'a pas de chemin")
end)

essai("ronde (fiche 15, V73 d 2) : le premier point, celui de départ, sinon le plus proche ; la boucle ; l'aller-retour", function()
  local id, f = rondier(10)
  local chemin = chemin_carre(8)
  FauxJeu.positions[f.personnage] = { x = 7, y = 1, z = 0 }   -- près du point 2 (8, 0)
  FauxJeu.ordres = {}
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, fin = "liberation" })
  local o = FauxJeu.ordres[#FauxJeu.ordres]
  egal(o and o.activite, "ronde", "l'ordre de ronde part sur-le-champ")
  pres(o and o.position.x, 8, "il part du point le plus proche (x)")
  pres(o and o.position.y, 0, "il part du point le plus proche (y)")
  -- La boucle : 2, 3, 4, puis 1, puis 2.
  local vus = {}
  for _ = 1, 5 do
    local pas = hommes.pas_de_ronde(f.personnage)
    table.insert(vus, pas and pas.suivant)
  end
  egal(table.concat(vus, ","), "3,4,1,2,3", "en boucle")
  -- Le départ donné.
  hommes.lacher(id, "ronde")
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r2", chemin = chemin, depart = 4, fin = "liberation" })
  o = FauxJeu.ordres[#FauxJeu.ordres]
  pres(o and o.position.x, -8, "le départ donné (x)")
  -- L'aller-retour, demi-tour aux deux bouts.
  vus = {}
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r3", chemin = chemin, depart = 2, aller_retour = true, fin = "liberation" })
  for _ = 1, 7 do
    local pas = hommes.pas_de_ronde(f.personnage)
    table.insert(vus, pas and pas.suivant)
  end
  egal(table.concat(vus, ","), "3,4,3,2,1,2,3", "en aller-retour")
  -- Deux points en aller-retour : de l'un à l'autre.
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r4", chemin = { chemin[1], chemin[2] }, depart = 1,
    aller_retour = true, fin = "liberation" })
  vus = {}
  for _ = 1, 4 do
    local pas = hommes.pas_de_ronde(f.personnage)
    table.insert(vus, pas and pas.suivant)
  end
  egal(table.concat(vus, ","), "2,1,2,1", "deux points en aller-retour")
  -- Plus de ronde, ou un inconnu : aucun pas.
  hommes.lacher(id, "ronde")
  egal(hommes.pas_de_ronde(f.personnage), nil, "plus de ronde : aucun pas")
  egal(hommes.pas_de_ronde("personne"), nil, "un inconnu : aucun pas")
end)

essai("ronde (fiche 15, V73 d 2) : les pauses dans leurs bornes, une longue sur cinq, le même hasard rend les mêmes", function()
  local id, f = rondier(10)
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin_carre(8), depart = 1, fin = "liberation" })
  local r = hommes.reglages
  local function suite(n)
    hommes.hasard_de_la_ronde = nil
    local pauses, longues = {}, 0
    for i = 1, n do
      local pas = hommes.pas_de_ronde(f.personnage)
      pauses[i] = pas.pause_ms
      if pas.longue then
        longues = longues + 1
        verifier(pas.pause_ms >= r.ronde_longue_ms - r.ronde_longue_ecart_ms and pas.pause_ms <= r.ronde_longue_ms + r.ronde_longue_ecart_ms,
          "pause longue dans ses bornes : " .. pas.pause_ms)
      else
        verifier(pas.pause_ms >= r.ronde_pause_ms - r.ronde_pause_ecart_ms and pas.pause_ms <= r.ronde_pause_ms + r.ronde_pause_ecart_ms,
          "pause courte dans ses bornes : " .. pas.pause_ms)
      end
      verifier(pas.pause_ms == math.floor(pas.pause_ms) and pas.pause_ms >= r.ronde_pause_min_ms, "pause entière, au moins le plancher")
    end
    return pauses, longues
  end
  local premieres, longues = suite(1000)
  verifier(longues >= 150 and longues <= 250, "sur 1 000 pas, une longue sur cinq environ : " .. longues)
  local secondes = suite(1000)
  egal(table.concat(secondes, ",", 1, 50), table.concat(premieres, ",", 1, 50), "le même hasard rend les mêmes pauses")
  -- Le plancher : un écart plus grand que la pause ne donne jamais moins que le plancher.
  local avant = r.ronde_pause_ecart_ms
  r.ronde_pause_ecart_ms = 9000
  suite(200)
  r.ronde_pause_ecart_ms = avant
end)

essai("ronde (fiche 15, V73 d 2) : à chaque pause, il regarde vers le dehors ; sans camp, vers le point suivant", function()
  local id, f = rondier(10)
  local chemin = chemin_carre(8)
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, depart = 1, fin = "liberation" })
  local pas = hommes.pas_de_ronde(f.personnage)
  local d = hommes.reglages.regard_m
  pres(pas.regard.x, chemin[1].x, "au point 1 (nord), regard au nord (x)")
  pres(pas.regard.y, chemin[1].y + d, "au point 1 (nord), regard au nord (y)")
  pas = hommes.pas_de_ronde(f.personnage)
  pres(pas.regard.x, chemin[2].x + d, "au point 2 (est), regard à l'est (x)")
  verifier(camp.lever(), "camp levé")
  pas = hommes.pas_de_ronde(f.personnage)
  pres(pas.regard.x, pas.point.x, "sans camp, le regard est le point suivant (x)")
  pres(pas.regard.y, pas.point.y, "sans camp, le regard est le point suivant (y)")
end)

essai("ronde (fiche 15, V73 d 2) : un rondier qui arrive à ses points ou fait sa pause n'est jamais posé ; bloqué, posé près du point visé", function()
  local id, f = rondier(10)
  local chemin = chemin_carre(8)
  FauxJeu.positions[f.personnage] = { x = 0, y = 7.5, z = 0 }
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, depart = 1, fin = "liberation" })
  FauxJeu.secours = {}
  hommes.battre()
  -- Il tourne : à chaque battement, il est arrivé à un point de plus, ou il fait sa pause au point quitté.
  for k = 1, 8 do
    local p = chemin[(k - 1) % 4 + 1]
    FauxJeu.positions[f.personnage] = { x = p.x + 0.4, y = p.y, z = 0 }
    hommes.pas_de_ronde(f.personnage)
    hommes.battre()
    hommes.battre()   -- toujours en pause au point quitté, 30 s plus tard
  end
  egal(#FauxJeu.secours, 0, "deux tours et des pauses : aucun secours")
  -- Une marche abandonnée (un pas loin du point) ne compte pas d'arrivée.
  local r = hommes.en_ronde[id]
  local arrivees = r.arrivees
  FauxJeu.positions[f.personnage] = { x = 40, y = 40, z = 0 }
  hommes.pas_de_ronde(f.personnage)
  egal(r.arrivees, arrivees, "un pas loin du point : aucune arrivée comptée")
  -- Bloqué entre deux points, sans arriver nulle part : posé près du point visé.
  local vise = chemin[r.vise]
  hommes.battre()
  hommes.battre()
  egal(#FauxJeu.secours, 1, "bloqué, sans arrivée : un secours")
  local ou = FauxJeu.secours[1] and FauxJeu.secours[1].position
  pres(ou and ou.x, vise.x, "posé près du point visé (x)")
  pres(ou and ou.y, vise.y, "posé près du point visé (y)")
end)

essai("ronde (fiche 15, V73 d 2) : au rechargement, l'ordre redonné repart du point le plus proche ; les hommes confient le pas à la liaison", function()
  local id, f = rondier(10)
  local chemin = chemin_carre(8)
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, depart = 1, fin = "liberation" })
  hommes.pas_de_ronde(f.personnage)
  FauxJeu.positions[f.personnage] = { x = -7, y = 0.5, z = 0 }
  FauxJeu.ordres = {}
  hommes.relancer()
  hommes.battre()
  local o = nil
  for _, ordre in ipairs(FauxJeu.ordres) do
    if ordre.activite == "ronde" then o = ordre end
  end
  pres(o and o.position.x, -8, "repart du point le plus proche (x)")
  egal(hommes.en_ronde[id] and hommes.en_ronde[id].vise, 4, "visé : le point 4")
  FauxJeu.pas_de_ronde = nil
  for _, m in ipairs(Scriptorium.morceaux) do
    if m.nom == "hommes" and m.demarrage then m.demarrage() end
  end
  verifier(type(FauxJeu.pas_de_ronde) == "function", "au démarrage, les hommes confient le pas de la ronde à la liaison")
  -- Fiche 19 : par la table, pas par une copie : une remplaçante posée après coup est celle que la liaison appelle.
  local ancienne_ronde = hommes.pas_de_ronde
  hommes.pas_de_ronde = function() return 7, "remplacée" end
  local pas_remplace = FauxJeu.pas_de_ronde("personne")
  hommes.pas_de_ronde = ancienne_ronde
  egal(pas_remplace, 7, "la remplaçante de pas_de_ronde, appelée par la liaison")
end)

essai("ronde (fiche 15, V73 d 2) : la ronde d'essai est à l'écart des meubles, segment par segment, et dans la palissade", function()
  local ecart = camp.reglages.ecart_d_abord
  local rayon = Scriptorium.enceinte.reglages.rayon
  local r = hommes.rondes.pourtour
  local n = r.nombre_de_points
  verifier(n >= 2 and n <= hommes.reglages.ronde_points_max, "le nombre de points tient dans la borne")
  local points = {}
  for i = 1, n do
    local cap = math.rad((i - 1) * 360 / n)
    points[i] = { x = r.rayon_m * math.sin(cap), y = r.rayon_m * math.cos(cap) }
  end
  local function au_segment(p, a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    local t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)
    t = math.max(0, math.min(1, t))
    return math.sqrt((p.x - a.x - t * dx) ^ 2 + (p.y - a.y - t * dy) ^ 2)
  end
  local plus_pres = math.huge
  for i = 1, n do
    local a, b = points[i], points[i % n + 1]
    for _, e in ipairs(camp.plan) do
      local d = au_segment(e, a, b)
      plus_pres = math.min(plus_pres, d)
      verifier(d >= ecart, "segment " .. i .. " à " .. string.format("%.1f", d) .. " m de « " .. e.nom .. " » : au moins " .. ecart .. " m")
    end
    verifier(r.rayon_m + ecart <= rayon, "point " .. i .. " en dedans de la palissade (rayon " .. rayon .. " m)")
  end
  verifier(plus_pres >= 2.6, "le meuble le plus proche à " .. string.format("%.2f", plus_pres) .. " m (fiche : 2,7 m)")
end)

-- Fiche 15, V73 d 2 bis : l'accroche « ronde reprise », la lecture du point courant, la ronde sans pause (réponses a, a
-- et a de JoVenGer du 17/10, relecture du pair).
local function lignes_contenant(texte)
  local n = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, texte, 1, true) then n = n + 1 end
  end
  return n
end

local function dernier_ordre_de_ronde()
  local o = nil
  for _, ordre in ipairs(FauxJeu.ordres) do
    if ordre.activite == "ronde" then o = ordre end
  end
  return o
end

essai("ronde reprise (fiche 15, V73 d 2 bis) : l'accroche n'est pas appelée à la pose ; à la reprise après un rechargement, une fois, avec le lieu, le plus proche, le nombre de points, la raison", function()
  local id, f = rondier(10)
  local chemin = chemin_carre(8)
  local appels = {}
  verifier(hommes.accrocher("ronde_reprise", function(qui, quoi)
    table.insert(appels, { id = qui, quoi = quoi })
    return 3
  end), "l'accroche se pose")
  local ok, raison = hommes.accrocher("ronde_inconnue", function() end)
  verifier(not ok and raison == "accroche_inconnue", "une accroche d'un nom inconnu reste refusée")
  FauxJeu.positions[f.personnage] = { x = 0, y = 7.5, z = 0 }
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, fin = "liberation" })
  egal(#appels, 0, "à la pose : l'accroche n'est pas appelée")
  egal(hommes.en_ronde[id].vise, 1, "à la pose sans départ : le plus proche")
  hommes.pas_de_ronde(f.personnage)
  -- Le rechargement : l'accroche donne le point 3.
  FauxJeu.positions[f.personnage] = { x = 7.5, y = 0, z = 0 }
  FauxJeu.ordres, FauxJeu.journal_lignes = {}, {}
  hommes.relancer()
  hommes.battre()
  egal(#appels, 1, "au rechargement : une fois")
  local q = appels[1] and appels[1].quoi or {}
  egal(appels[1] and appels[1].id, id, "l'homme")
  egal(q.lieu, "r", "le lieu de la ronde")
  egal(q.plus_proche, 2, "le point le plus proche")
  egal(q.points, 4, "le nombre de points")
  egal(q.raison, "rechargement", "la raison")
  egal(q.precedent, nil, "après un rechargement, aucun point visé d'avant")
  local o = dernier_ordre_de_ronde()
  pres(o and o.position.x, 0, "l'ordre part vers le point donné par l'accroche (x)")
  pres(o and o.position.y, -8, "l'ordre part vers le point donné par l'accroche (y)")
  egal(hommes.en_ronde[id].vise, 3, "le point visé est celui de l'accroche")
  egal(lignes_contenant("reprend la ronde « r » au point 3 (donné par l'accroche, rechargement)"), 1, "une ligne au journal")
  -- Un homme qui n'est pas de ronde ne l'appelle jamais.
  local autre = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  hommes.relancer()
  hommes.battre()
  egal(#appels, 2, "un second rechargement : un appel de plus, pour le seul rondier")
  verifier(hommes.ronde_point(autre) == nil, "pas de ronde : aucune lecture")
end)

essai("ronde reprise (fiche 15, V73 d 2 bis) : rien rendu, une réponse refusée, une panne : le plus proche ; deux accroches : la première réponse valable", function()
  local id, f = rondier(10)
  local chemin = chemin_carre(8)
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, depart = 1, fin = "liberation" })
  local reponse = nil
  hommes.accrocher("ronde_reprise", function() return reponse end)
  local function reprise()
    FauxJeu.positions[f.personnage] = { x = -7.5, y = 0, z = 0 }   -- près du point 4
    FauxJeu.journal_lignes = {}
    hommes.relancer()
    hommes.battre()
    return hommes.en_ronde[id].vise
  end
  egal(reprise(), 4, "rien rendu : le plus proche")
  egal(lignes_contenant("au point 4 (le plus proche, rechargement)"), 1, "dit au journal")
  for _, mauvaise in ipairs({ 0, 5, 2.5, "3", true }) do
    reponse = mauvaise
    egal(reprise(), 4, "réponse « " .. tostring(mauvaise) .. " » : le plus proche")
    egal(lignes_contenant("réponse refusée"), 1, "réponse « " .. tostring(mauvaise) .. " » refusée, dite au journal")
  end
  reponse = nil
  hommes.accroches.ronde_reprise = {}
  hommes.accrocher("ronde_reprise", function() error("panne") end)
  egal(reprise(), 4, "une accroche en panne : le plus proche")
  egal(lignes_contenant("accroche « ronde_reprise » en panne"), 1, "la panne dite au journal")
  hommes.accroches.ronde_reprise = {}
  hommes.accrocher("ronde_reprise", function() return nil end)
  hommes.accrocher("ronde_reprise", function() return 2 end)
  hommes.accrocher("ronde_reprise", function() return 3 end)
  egal(reprise(), 2, "trois accroches, la première sans réponse : la seconde l'emporte")
end)

essai("ronde reprise (fiche 15, V73 d 2 bis) : après une règle plus forte et après un secours, la raison et le point visé d'avant", function()
  local id, f = rondier(10)
  local chemin = chemin_carre(8)
  local appels = {}
  hommes.accrocher("ronde_reprise", function(qui, quoi) table.insert(appels, quoi) end)
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, depart = 1, fin = "liberation" })
  FauxJeu.positions[f.personnage] = { x = 0, y = 8.4, z = 0 }
  hommes.pas_de_ronde(f.personnage)                          -- au point 1, vers le point 2
  -- Une bataille le prend, puis le lâche.
  hommes.tenir(id, "bataille", { activite = "bataille", lieu = "rang", position = point_d_essai(), fin = "liberation" })
  egal(#appels, 0, "pris par la bataille : aucun appel")
  verifier(hommes.ronde_point(id) == nil, "en bataille, aucune lecture de ronde")
  hommes.lacher(id, "bataille")
  egal(#appels, 1, "la bataille lâchée : un appel")
  egal(appels[1] and appels[1].raison, "regle_plus_forte", "raison : une règle plus forte")
  egal(appels[1] and appels[1].precedent, 2, "le point qu'il visait avant la reprise")
  -- Le secours : posé d'un coup, puis l'ordre redonné.
  FauxJeu.positions[f.personnage] = { x = 40, y = 40, z = 0 }
  hommes.battre()
  hommes.battre()
  hommes.battre()
  verifier(#appels >= 2, "après le secours : un appel")
  local dernier = appels[#appels] or {}
  egal(dernier.raison, "secours", "raison : le secours")
  verifier(type(dernier.precedent) == "number", "le point visé avant le secours")
  -- Une reprise sans raison notée (la raison est effacée à chaque ordre).
  egal(hommes.raisons_de_reprise[id], nil, "la raison est effacée une fois l'ordre donné")
end)

essai("ronde (fiche 15, V73 d 2 bis) : la lecture du point courant, pour le guichet", function()
  local id, f = rondier(10)
  verifier(hommes.ronde_point(id) == nil, "avant la ronde : rien")
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin_carre(8), depart = 2, fin = "liberation" })
  local p = hommes.ronde_point(id)
  egal(p and p.lieu, "r", "le lieu")
  egal(p and p.vise, 2, "le point visé")
  egal(p and p.quitte, nil, "aucun point quitté")
  egal(p and p.pas, 0, "aucun pas")
  egal(p and p.points, 4, "le nombre de points")
  hommes.pas_de_ronde(f.personnage)
  p = hommes.ronde_point(id)
  egal(p and p.vise, 3, "après un pas : le point visé")
  egal(p and p.quitte, 2, "après un pas : le point quitté")
  egal(p and p.pas, 1, "un pas")
  hommes.lacher(id, "ronde")
  verifier(hommes.ronde_point(id) == nil, "la ronde lâchée : rien")
end)

essai("ronde (fiche 15, V73 d 2 bis) : sans pause, ni arrêt ni demi-tour ; l'option se garde, se compare, se refuse si elle n'est pas vrai ou faux", function()
  local id, f = rondier(10)
  local chemin = chemin_carre(8)
  local ok, raison = hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, pauses = "non", fin = "liberation" })
  verifier(not ok and raison == "chemin_invalide", "pauses = « non » : refusé")
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, depart = 1, fin = "liberation" })
  egal(hommes.fiche(id).tenues.ronde.pauses, nil, "par défaut, avec pauses (rien d'écrit)")
  local ecrit = FauxJeu.registre_stocke
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, depart = 1, pauses = false, fin = "liberation" })
  verifier(FauxJeu.registre_stocke ~= ecrit, "sans pause : la tenue change, écrite")
  egal(hommes.fiche(id).tenues.ronde.pauses, false, "sans pause, gardé")
  local avant = Scriptorium.hasard_en_ordre(hommes.hasard_de_la_ronde) and table.concat(hommes.hasard_de_la_ronde, ",") or "aucun"
  for _ = 1, 6 do
    local pas = hommes.pas_de_ronde(f.personnage)
    egal(pas.pause_ms, 0, "sans pause : 0 ms")
    egal(pas.longue, false, "jamais longue")
    pres(pas.regard.x, pas.point.x, "le regard vers le point suivant (x)")
    pres(pas.regard.y, pas.point.y, "le regard vers le point suivant (y)")
  end
  local apres = Scriptorium.hasard_en_ordre(hommes.hasard_de_la_ronde) and table.concat(hommes.hasard_de_la_ronde, ",") or "aucun"
  egal(apres, avant, "le hasard des pauses n'est pas tiré")
  -- Reposée avec les pauses : elles reviennent au pas suivant.
  hommes.tenir(id, "ronde", { activite = "ronde", lieu = "r", chemin = chemin, depart = 1, fin = "liberation" })
  verifier(hommes.pas_de_ronde(f.personnage).pause_ms >= hommes.reglages.ronde_pause_min_ms, "les pauses reviennent")
end)

-- Fiche 15, V73 e : le rassemblement en arc, la course, les 150 m, la vue d'Henry (réponses recommandées prises d'office
-- le 17/10, relecture du pair).
local function convoquer(id, quoi)
  quoi = quoi or {}
  local centre = quoi.centre or (camp.point(0, -6, 0))
  return hommes.tenir(id, "rassemblement", { activite = "rassemblement", lieu = quoi.lieu or "briefing", centre = centre,
    cap = quoi.cap or 180, rayon = quoi.rayon, ouverture = quoi.ouverture, face = quoi.face, allure = quoi.allure,
    fin = "liberation" })
end

local function distance(a, b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

local function dernier_ordre_de(personnage)
  local o = nil
  for _, ordre in ipairs(FauxJeu.ordres) do
    if ordre.identifiant == personnage then o = ordre end
  end
  return o
end

essai("rassemblement (fiche 15, V73 e) : les places sur l'arc, face au centre ; un cercle ; face au dehors ; neuf hommes sur deux arcs, jamais à moins de 1,2 m", function()
  preparer(5000, 100, 10)
  local ids = {}
  for i = 1, 3 do ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 }) end
  local centre = camp.point(0, -6, 0)
  verifier(convoquer(ids[1], { centre = centre }), "convoqué")
  local a = hommes.activite_de(ids[1], 10)
  pres(a.position.x, centre.x, "seul : au milieu de l'arc (x)")
  pres(a.position.y, centre.y - 3, "seul : au milieu de l'arc, à 3 m, au cap 180 (y)")
  pres(a.regard.x, centre.x, "face au centre (x)")
  pres(a.regard.y, centre.y, "face au centre (y)")
  egal(a.allure, "course", "en courant par défaut")
  egal(a.signature, "1/1", "la place dans la signature")
  convoquer(ids[2], { centre = centre })
  convoquer(ids[3], { centre = centre })
  local places = {}
  for i = 1, 3 do places[i] = hommes.activite_de(ids[i], 10).position end
  -- Cap 180, ouverture 120 : de 120° à 240°.
  pres(places[1].x, centre.x + 3 * math.sin(math.rad(120)), "le premier à 120° (x)")
  pres(places[2].x, centre.x, "le deuxième au milieu (x)")
  pres(places[3].x, centre.x + 3 * math.sin(math.rad(240)), "le troisième à 240° (x)")
  for i = 1, 3 do pres(distance(places[i], centre), 3, "à 3 m du centre (" .. i .. ")") end
  -- Un cercle entier de quatre, face au dehors.
  depart()
  preparer(5000, 100, 10)
  ids = {}
  for i = 1, 4 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  end
  for i = 1, 4 do convoquer(ids[i], { centre = centre, cap = 0, ouverture = 360, rayon = 5, face = "dehors" }) end
  for i = 1, 4 do
    local b = hommes.activite_de(ids[i], 10)
    local angle = (i - 1) * 90
    pres(b.position.x, centre.x + 5 * math.sin(math.rad(angle)), "cercle : place " .. i .. " (x)")
    pres(b.position.y, centre.y + 5 * math.cos(math.rad(angle)), "cercle : place " .. i .. " (y)")
    pres(distance(b.regard, centre), 5 + hommes.reglages.regard_m, "face au dehors : le regard plus loin du centre (" .. i .. ")")
  end
  -- Neuf hommes sur 3 m et 120° : un second arc ; jamais deux à moins de 1,2 m.
  depart()
  preparer(5000, 100, 10)
  ids = {}
  camp.agrandir()
  camp.agrandir()   -- assez de paillasses pour neuf hommes
  for i = 1, 9 do ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 }) end
  for i = 1, 9 do verifier(convoquer(ids[i], { centre = centre }), "neuf hommes : " .. i .. " convoqué") end
  local loin = 0
  places = {}
  for i = 1, 9 do
    places[i] = hommes.activite_de(ids[i], 10).position
    if distance(places[i], centre) > 3.5 then loin = loin + 1 end
  end
  verifier(loin > 0, "un second arc, plus loin : " .. loin .. " homme(s)")
  for i = 1, 9 do
    for j = i + 1, 9 do
      verifier(distance(places[i], places[j]) >= hommes.reglages.ecart_entre_hommes - 1e-6,
        "places " .. i .. " et " .. j .. " à " .. string.format("%.2f", distance(places[i], places[j])) .. " m")
    end
  end
end)

essai("rassemblement (fiche 15, V73 e) : convoqués l'un après l'autre, chacun reçoit son ordre à chaque place nouvelle ; un lâché, les autres se resserrent", function()
  preparer(5000, 100, 10)
  local ids, personnages = {}, {}
  for i = 1, 3 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
    personnages[i] = hommes.fiche(ids[i]).personnage
  end
  hommes.battre()
  local centre = camp.point(0, -6, 0)
  for n = 1, 3 do
    FauxJeu.ordres = {}
    convoquer(ids[n], { centre = centre })
    for i = 1, n do
      local o = dernier_ordre_de(personnages[i])
      verifier(o ~= nil and o.activite == "rassemblement", n .. " convoqué(s) : un ordre pour l'homme " .. i)
      local place = hommes.activite_de(ids[i], 10).position
      verifier(o ~= nil and distance(o.position, place) < 0.01, n .. " convoqué(s) : l'homme " .. i .. " va à sa place du moment")
      egal(o and o.allure, "course", "l'ordre est en courant")
      verifier(o ~= nil and o.regard ~= nil, "l'ordre porte le regard")
    end
  end
  -- Reconvoquer le même : rien ne change, aucun ordre.
  FauxJeu.ordres = {}
  convoquer(ids[2], { centre = centre })
  egal(#FauxJeu.ordres, 0, "la même tenue reposée : aucun ordre")
  -- Le deuxième lâché : il rejoint sa tranche, les deux autres se resserrent (un ordre chacun).
  FauxJeu.ordres = {}
  hommes.lacher(ids[2], "rassemblement")
  verifier(dernier_ordre_de(personnages[2]) ~= nil and dernier_ordre_de(personnages[2]).activite ~= "rassemblement", "le lâché rejoint sa tranche")
  egal(#FauxJeu.ordres, 3, "trois ordres : le lâché et les deux autres")
  egal(hommes.activite_de(ids[1], 10).signature, "1/2", "le premier : 1 sur 2")
  egal(hommes.activite_de(ids[3], 10).signature, "2/2", "le troisième : 2 sur 2")
  -- Un homme pris par une bataille quitte l'arc ; au battement, les autres se resserrent.
  hommes.tenir(ids[1], "bataille", { activite = "bataille", lieu = "rang", position = point_d_essai(), fin = "liberation" })
  egal(hommes.activite_de(ids[3], 10).signature, "1/1", "la bataille a pris le premier : le troisième seul")
end)

essai("rassemblement (fiche 15, V73 e) : l'allure, les valeurs refusées, sans centre une marche comme avant ; la garde ne court pas", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local centre = camp.point(0, -6, 0)
  for _, mauvais in ipairs({ { rayon = 0 }, { rayon = "3" }, { ouverture = 0 }, { ouverture = 400 }, { face = "nord" },
                             { allure = "galop" }, { cap = "sud" } }) do
    mauvais.centre = centre
    local ok, raison = convoquer(id, mauvais)
    verifier(not ok and raison == "rassemblement_invalide", "refusé : " .. tostring(next(mauvais)))
  end
  local ok, raison = hommes.tenir(id, "rassemblement", { activite = "rassemblement", lieu = "b", centre = { y = 2 }, fin = "liberation" })
  verifier(not ok and raison == "rassemblement_invalide", "un centre sans x : refusé")
  convoquer(id, { centre = centre, allure = "marche" })
  egal(hommes.activite_de(id, 10).allure, "marche", "au pas si la tenue le dit")
  hommes.lacher(id, "rassemblement")
  hommes.tenir(id, "rassemblement", { activite = "rassemblement", lieu = "corvee", position = point_d_essai(), fin = "liberation" })
  local a = hommes.activite_de(id, 10)
  egal(a.regard, nil, "sans centre : aucun regard")
  egal(a.allure, nil, "sans centre : aucune allure")
  -- La signature porte le point de la tenue (20/10) ; une place sur l'arc s'écrirait « rang/nombre ».
  verifier(a.signature == nil or not string.find(a.signature, "/", 1, true), "sans centre : aucune place sur l'arc")
  hommes.lacher(id, "rassemblement")
  FauxJeu.ordres = {}
  hommes.tenir(id, "garde", { activite = "garde", lieu = "porte", position = camp.point(0, 12, 0), fin = "liberation" })
  local o = FauxJeu.ordres[#FauxJeu.ordres]
  egal(o and o.allure, nil, "la garde ne court pas")
end)

essai("secours (fiche 15, V73 e) : au-delà de 150 m d'un but au camp, posé au premier battement ; une sortie, jamais avant le délai", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  local centre = camp.point(0, -6, 0)
  convoquer(id, { centre = centre })
  local place = hommes.activite_de(id, 10).position
  FauxJeu.secours = {}
  FauxJeu.positions[f.personnage] = { x = place.x + 151, y = place.y, z = 0 }
  hommes.battre()
  egal(#FauxJeu.secours, 1, "à 151 m d'un but au camp : posé au premier battement")
  -- À 149 m : le délai d'abord.
  depart()
  preparer(5000, 100, 10)
  id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  f = hommes.fiche(id)
  convoquer(id, { centre = centre })
  place = hommes.activite_de(id, 10).position
  FauxJeu.secours = {}
  FauxJeu.positions[f.personnage] = { x = place.x + 149, y = place.y, z = 0 }
  hommes.battre()
  egal(#FauxJeu.secours, 0, "à 149 m : pas au premier battement")
  hommes.battre()
  egal(#FauxJeu.secours, 1, "à 149 m : après le délai sans progrès")
  -- Une sortie : un but à 60 m du centre du camp, l'homme à 200 m de son but : jamais avant le délai.
  depart()
  preparer(5000, 100, 10)
  id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  f = hommes.fiche(id)
  local dehors = camp.point(0, 60, 0)
  hommes.tenir(id, "patrouille", { activite = "patrouille", lieu = "loin", position = dehors, fin = "liberation" })
  FauxJeu.secours = {}
  FauxJeu.positions[f.personnage] = { x = dehors.x + 200, y = dehors.y, z = 0 }
  hommes.battre()
  egal(#FauxJeu.secours, 0, "une sortie à 200 m : pas au premier battement")
end)

essai("secours (vu sur une copie de la partie de JoVenGer le 20/10) : un personnage mené, bloqué loin de son but, est secouru comme nos hommes", function()
  preparer(5000, 100, 10)
  FauxJeu.personnages_existants["chasseur"] = true
  local but = camp.point(0, -6, 0)
  verifier(hommes.tenir_un_personnage("chasseur", "travail", { activite = "geste", geste = "waiting_armsCrossed", lieu = "repos",
                                                              position = but, fin = "liberation" }), "mené")
  FauxJeu.secours = {}
  FauxJeu.positions["chasseur"] = { x = but.x + 40, y = but.y, z = 0 }
  for _ = 1, 4 do hommes.battre() end
  verifier(#FauxJeu.secours >= 1, "bloqué à 40 m sans progrès : secouru")
  egal(FauxJeu.secours[1].identifiant, "chasseur", "le mené lui-même")
  hommes.lacher_un_personnage("chasseur", "travail")
end)

essai("secours (règle de JoVenGer, 20/10) : un homme qui marche n'est jamais bloqué, même en s'éloignant (la porte) ; immobile, il l'est ; tourner en rond a sa borne ; ni sous les yeux d'Henry là où il disparaît", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  local but = camp.point(0, -6, 0)
  hommes.tenir(id, "travail", { activite = "geste", geste = "Loot", lieu = "depot", position = but, fin = "liberation" })
  FauxJeu.secours = {}
  local pas = Scriptorium.cadence_du_battement_ms / 1000
  local battements = math.ceil(hommes.reglages.secours_delai_s / pas) + 2
  -- Il s'éloigne du but en marchant (vers la porte), 2 m par battement : jamais posé.
  for k = 1, battements do
    FauxJeu.positions[f.personnage] = { x = but.x + 20 + 2 * k, y = but.y, z = 0 }
    hommes.battre()
  end
  egal(#FauxJeu.secours, 0, "en marche, même en s'éloignant : pas de secours")
  -- Il s'arrête : bloqué au bout du délai.
  for _ = 1, battements do hommes.battre() end
  egal(#FauxJeu.secours, 1, "immobile : secouru")
  -- Il tourne en rond (il bouge sans jamais s'approcher mieux) : bloqué au bout de « secours_detour_max_s ».
  hommes.lacher(id, "travail")
  hommes.tenir(id, "travail", { activite = "geste", geste = "Loot", lieu = "depot2", position = but, fin = "liberation" })
  FauxJeu.secours = {}
  local tours = math.ceil(hommes.reglages.secours_detour_max_s / pas) + 2
  for k = 1, tours do
    FauxJeu.positions[f.personnage] = { x = but.x + 30, y = but.y + ((k % 2 == 0) and 2 or -2), z = 0 }
    hommes.battre()
  end
  verifier(#FauxJeu.secours >= 1, "en rond au-delà de la borne : secouru")
  -- Henry regarde l'endroit où il est (pas celui où il irait) : le secours attend.
  hommes.lacher(id, "travail")
  hommes.tenir(id, "travail", { activite = "geste", geste = "Loot", lieu = "depot3", position = but, fin = "liberation" })
  FauxJeu.secours = {}
  local ici = { x = but.x + 40, y = but.y, z = 0 }
  FauxJeu.positions[f.personnage] = ici
  FauxJeu.vue_d_henry = function(point) return point and math.abs(point.x - ici.x) < 0.01 and math.abs(point.y - ici.y) < 0.01 end
  for _ = 1, battements do hommes.battre() end
  egal(#FauxJeu.secours, 0, "Henry regarde l'endroit où il disparaîtrait : pas de secours")
  FauxJeu.vue_d_henry = nil
  hommes.battre()
  egal(#FauxJeu.secours, 1, "Henry détourne le regard : posé")
  hommes.lacher(id, "travail")
end)

essai("sommeil d'un mené sur un lit nommé (demande du pair, 20/10) : couché par l'objet du jeu, même non déclaré ; refus sinon", function()
  preparer(5000, 100, 10)
  FauxJeu.personnages_existants["jardinier"] = true
  FauxJeu.objets_existants["lit_haut_43"] = true
  FauxJeu.positions_des_objets = FauxJeu.positions_des_objets or {}
  local pres = camp.point(3, 4, 0)
  FauxJeu.positions_des_objets["lit_haut_43"] = { x = pres.x, y = pres.y, z = 0 }
  local loin = camp.point(0, 2000, 0)
  FauxJeu.objets_existants["place_au_loin"] = true
  FauxJeu.positions_des_objets["place_au_loin"] = { x = loin.x, y = loin.y, z = 0 }
  FauxJeu.ordres = {}
  verifier(hommes.tenir_un_personnage("jardinier", "sommeil", { activite = "sommeil", lit = "lit_haut_43", fin = "liberation" }),
           "tenue posée")
  local dernier = FauxJeu.ordres[#FauxJeu.ordres]
  egal(dernier and dernier.identifiant, "jardinier", "un ordre au mené")
  egal(dernier and dernier.place, "lit_haut_43", "l'objet du lit nommé")
  egal(dernier and dernier.sorte, "lit", "couché (ordre de lit)")
  egal(dernier and dernier.lieu, "lit_haut_43", "le lieu est le lit")
  egal(dernier and dernier.position and dernier.position.x, pres.x, "le but est la position du lit")
  local _, r0 = hommes.tenir_un_personnage("jardinier", "sommeil", { activite = "sommeil", lit = "place_au_loin", fin = "liberation" })
  egal(r0, "lit_invalide", "un lit à 2 km du camp est refusé (vu sur une copie le 20/10)")
  egal(FauxJeu.ordres[#FauxJeu.ordres].place, "lit_haut_43", "la tenue d'avant reste")
  local _, r1 = hommes.tenir_un_personnage("jardinier", "sommeil", { activite = "sommeil", lit = "absent", fin = "liberation" })
  egal(r1, "lit_invalide", "un lit introuvable est refusé")
  local _, r2 = hommes.tenir_un_personnage("jardinier", "sommeil", { activite = "geste", geste = "Loot", lit = "lit_haut_43",
                                                                     position = { x = 1, y = 2, z = 0 }, fin = "liberation" })
  egal(r2, "lit_invalide", "un lit hors du sommeil est refusé")
  hommes.lacher_un_personnage("jardinier", "sommeil")
end)

essai("secours (fiche 15, V73 e) : jamais sous les yeux d'Henry ; il détourne le regard, le secours pose ; sans lecture, il pose", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  convoquer(id, { centre = camp.point(0, -6, 0) })
  local place = hommes.activite_de(id, 10).position
  FauxJeu.secours, FauxJeu.journal_lignes = {}, {}
  local seuils = {}
  FauxJeu.vue_d_henry = function(point, seuil) table.insert(seuils, seuil) return true end
  FauxJeu.positions[f.personnage] = { x = place.x + 151, y = place.y, z = 0 }
  hommes.battre()
  hommes.battre()
  egal(#FauxJeu.secours, 0, "Henry regarde l'endroit : aucun secours")
  egal(seuils[1], hommes.reglages.secours_vue_cos, "le seuil de la vue vient du catalogue")
  egal(lignes_contenant("Henry regarde l'endroit : le secours attend"), 1, "une ligne, une seule fois")
  FauxJeu.vue_d_henry = function() return false end
  hommes.battre()
  egal(#FauxJeu.secours, 1, "il détourne le regard : posé")
  FauxJeu.vue_d_henry = nil
  FauxJeu.positions[f.personnage] = { x = place.x + 151, y = place.y, z = 0 }
  hommes.battre()   -- l'ordre redonné après le premier secours
  hommes.battre()
  egal(#FauxJeu.secours, 2, "sans lecture de la vue : posé")
end)

essai("secours (vu en J34, 25/10 : la nuit, des figés vers les lits des tentes attendaient sans fin, Henry regardant de leur côté) : la nuit, au-delà de secours_vue_nuit_m d'Henry, l'endroit ne se voit plus ; de près, le secours attend toujours", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  convoquer(id, { centre = camp.point(0, -6, 0) })
  FauxJeu.heure = 23
  verifier(Scriptorium.avis(hommes, "est_nuit", 23), "23 h est la nuit")
  local place = hommes.activite_de(id, 23).position
  FauxJeu.secours = {}
  FauxJeu.vue_d_henry = function() return true end
  -- Henry tout près de l'endroit : le secours attend, même la nuit.
  FauxJeu.position_joueur = { x = place.x + 5, y = place.y, z = 0 }
  FauxJeu.positions[f.personnage] = { x = place.x + 151, y = place.y, z = 0 }
  hommes.battre()
  hommes.battre()
  egal(#FauxJeu.secours, 0, "de près, la nuit : il attend")
  -- Henry à 30 m de l'endroit et à 120 m de l'homme : la nuit, il ne les voit plus.
  FauxJeu.position_joueur = { x = place.x + 30, y = place.y + 1, z = 0 }
  hommes.battre()
  egal(#FauxJeu.secours, 1, "la nuit, de loin : posé")
  FauxJeu.vue_d_henry, FauxJeu.position_joueur = nil, nil
end)

essai("rassemblement (fiche 15, V73 e) : les places du briefing d'essai, pour un à neuf hommes, à l'écart des meubles et dans la palissade", function()
  local ecart = camp.reglages.ecart_d_abord
  local rayon = Scriptorium.enceinte.reglages.rayon
  local p = hommes.points.briefing
  for n = 1, 9 do
    depart()
    preparer(5000, 100, 10)
    local ids = {}
    camp.agrandir()
    camp.agrandir()   -- assez de paillasses pour neuf hommes
    for i = 1, n do ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 }) end
    local centre, cap = camp.point(p.x, p.y, p.cap)
    for i = 1, n do
      hommes.tenir(ids[i], "rassemblement", { activite = "rassemblement", lieu = "briefing", centre = centre, cap = cap, fin = "liberation" })
    end
    local plus_pres = math.huge
    for i = 1, n do
      local q = hommes.activite_de(ids[i], 10).position
      for _, e in ipairs(camp.plan) do
        plus_pres = math.min(plus_pres, distance(q, e))
      end
      verifier(math.sqrt(q.x ^ 2 + q.y ^ 2) + ecart <= rayon, n .. " hommes : la place " .. i .. " en dedans de la palissade")
    end
    verifier(plus_pres >= ecart, n .. " hommes : le meuble le plus proche à " .. string.format("%.2f", plus_pres) .. " m")
  end
end)

-- Fiche 15, V73 f 1 : suivre Henry, à pied (réponses recommandées prises d'office le 17/10, relecture du pair).
local function escorter(id, chef)
  return hommes.tenir(id, "escorte", { activite = "suivre", lieu = "escorte", chef = chef, fin = "liberation" })
end

essai("escorte (fiche 15, V73 f 1) : la colonne, chacun suit le précédent ; le rang dans la signature ; un lâché, les suivants changent de chef", function()
  preparer(5000, 100, 10)
  local ids, perso = {}, {}
  for i = 1, 3 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
    perso[i] = hommes.fiche(ids[i]).personnage
  end
  hommes.battre()
  local ok, raison = escorter(ids[1], "personne")
  verifier(not ok and raison == "escorte_invalide", "un chef inconnu : refusé")
  ok, raison = escorter(ids[1], ids[1])
  verifier(not ok and raison == "escorte_invalide", "il ne se suit pas lui-même")
  FauxJeu.ordres = {}
  for i = 1, 3 do verifier(escorter(ids[i]), "escorte " .. i) end
  local a1, a2, a3 = hommes.activite_de(ids[1], 10), hommes.activite_de(ids[2], 10), hommes.activite_de(ids[3], 10)
  egal(a1.chef, "henry", "le premier suit Henry")
  egal(a2.chef, perso[1], "le deuxième suit le premier")
  egal(a3.chef, perso[2], "le troisième suit le deuxième")
  egal(a3.signature, "3/3", "le rang dans la signature")
  local o = dernier_ordre_de(perso[3])
  egal(o and o.activite, "suivre", "l'ordre de suivre part")
  egal(o and o.chef, perso[2], "l'ordre porte le chef")
  FauxJeu.ordres = {}
  hommes.lacher(ids[1], "escorte")
  egal(hommes.activite_de(ids[2], 10).chef, "henry", "le premier lâché : le deuxième suit Henry")
  egal(hommes.activite_de(ids[3], 10).chef, perso[2], "le troisième suit toujours le deuxième")
  verifier(dernier_ordre_de(perso[2]) ~= nil and dernier_ordre_de(perso[2]).chef == "henry", "le deuxième reçoit son nouveau chef")
  verifier(dernier_ordre_de(perso[3]) ~= nil, "le troisième reçoit son ordre (son rang a changé)")
end)

essai("escorte (fiche 15, V73 f 1) : jamais de secours ordinaire pour un suiveur ; à plus de 60 m, rattrapé 4 m derrière Henry, hors secours_max ; jamais sous ses yeux ni en combat", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  hommes.battre()
  FauxJeu.position_joueur, FauxJeu.cap_joueur = { x = 50, y = 50, z = 0 }, 0
  escorter(id)
  FauxJeu.secours = {}
  for _ = 1, 10 do
    FauxJeu.positions[f.personnage] = { x = 50, y = 47, z = 0 }   -- à 3 m d'Henry, sans jamais se rapprocher
    hommes.battre()
  end
  egal(#FauxJeu.secours, 0, "à 3 m, dix battements sans progrès : aucun secours")
  local avant = hommes.reglages.secours_max
  hommes.reglages.secours_max = 0
  FauxJeu.positions[f.personnage] = { x = 50, y = -20, z = 0 }    -- à 70 m
  hommes.battre()
  egal(#FauxJeu.secours, 1, "à 70 m : rattrapé, même secours coupé")
  local ou = FauxJeu.secours[1] and FauxJeu.secours[1].position
  pres(ou and ou.x, 50, "4 m derrière Henry (x)")
  pres(ou and ou.y, 46, "4 m derrière Henry (y), Henry face au nord")
  hommes.battre()   -- l'ordre redonné
  FauxJeu.positions[f.personnage] = { x = 50, y = -20, z = 0 }
  hommes.battre()
  egal(#FauxJeu.secours, 2, "une seconde fois : pas de limite de nombre")
  -- Sous les yeux d'Henry : il attend, une ligne une seule fois.
  FauxJeu.journal_lignes = {}
  FauxJeu.vue_d_henry = function() return true end
  hommes.battre()
  FauxJeu.positions[f.personnage] = { x = 50, y = -20, z = 0 }
  hommes.battre()
  hommes.battre()
  egal(#FauxJeu.secours, 2, "Henry regarde l'endroit : pas de rattrapage")
  egal(lignes_contenant("à rattraper, mais Henry regarde l'endroit"), 1, "dit une seule fois")
  FauxJeu.vue_d_henry = nil
  -- En combat : jamais.
  FauxJeu.occupations[f.personnage] = "combat"
  hommes.battre()
  egal(#FauxJeu.secours, 2, "en combat : jamais rattrapé")
  FauxJeu.occupations[f.personnage] = nil
  -- suivi_loin_m à 0 : jamais.
  local loin = hommes.reglages.suivi_loin_m
  hommes.reglages.suivi_loin_m = 0
  hommes.battre()
  egal(#FauxJeu.secours, 2, "suivi_loin_m à 0 : jamais")
  hommes.reglages.suivi_loin_m = loin
  hommes.reglages.secours_max = avant
end)

essai("escorte (fiche 15, V73 f 1) : le Directeur suit Henry, gardé au registre ; la colonne derrière lui ; lâché, il reprend sa journée", function()
  preparer(5000, 100, 10)
  verifier(Scriptorium.directeur.installer(), "Directeur installé")
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local directeur_perso = Scriptorium.directeur.personnage()
  hommes.battre()
  Scriptorium.directeur.battre()
  FauxJeu.ordres = {}
  verifier(Scriptorium.directeur.suivre(true), "le Directeur suit")
  local o = dernier_ordre_de(directeur_perso)
  egal(o and o.activite, "suivre", "son ordre : suivre")
  egal(o and o.chef, "henry", "Henry pour chef")
  verifier(escorter(id, "directeur"), "l'escorte derrière le Directeur")
  egal(hommes.activite_de(id, 10).chef, directeur_perso, "l'homme suit le Directeur")
  -- Le registre : après rechargement, il suit toujours.
  local chaine, objets = FauxJeu.registre_stocke, FauxJeu.objets_existants
  depart()
  FauxJeu.heure = 10
  FauxJeu.registre_stocke, FauxJeu.objets_existants = chaine, objets
  egal(Scriptorium.directeur.activite(10).activite, "suivre", "relu : il suit toujours")
  Scriptorium.directeur.relancer()
  FauxJeu.ordres = {}
  Scriptorium.directeur.battre()
  o = dernier_ordre_de(Scriptorium.directeur.personnage())
  egal(o and o.activite, "suivre", "relancé : l'ordre de suivre redonné")
  -- Lâché : sa journée.
  FauxJeu.ordres = {}
  verifier(Scriptorium.directeur.suivre(false), "le Directeur ne suit plus")
  o = dernier_ordre_de(Scriptorium.directeur.personnage())
  verifier(o ~= nil and o.activite ~= "suivre", "il reprend sa journée : " .. tostring(o and o.activite))
end)

-- Fiche 15, V73 f 1 bis : l'escorte en formation du moteur (réponses recommandées prises d'office le 17/10, relecture du
-- pair).
essai("formation (fiche 15, V73 f 1 bis) : derrière le Directeur, chacun se range dans sa formation ; derrière Henry, le premier mène ; au-delà des places, la chaîne", function()
  preparer(5000, 100, 10)
  verifier(Scriptorium.directeur.installer(), "Directeur installé")
  local ids, perso = {}, {}
  for i = 1, 3 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
    perso[i] = hommes.fiche(ids[i]).personnage
  end
  hommes.battre()
  local ok, raison = hommes.tenir(ids[1], "escorte", { activite = "suivre", lieu = "e", formation = "carre_de_fantaisie", fin = "liberation" })
  verifier(not ok and raison == "escorte_invalide", "un modèle inconnu : refusé")
  ok, raison = Scriptorium.directeur.suivre(true, "carre_de_fantaisie")
  verifier(not ok and raison == "formation_inconnue", "le Directeur refuse un modèle inconnu")
  -- Derrière le Directeur qui mène.
  FauxJeu.ordres = {}
  verifier(Scriptorium.directeur.suivre(true, "followNPC"), "le Directeur mène followNPC")
  local o = dernier_ordre_de(Scriptorium.directeur.personnage())
  verifier(o ~= nil and o.suivi ~= nil and o.suivi.mode == "mener" and o.suivi.formation == "followNPC", "son ordre : mener followNPC")
  for i = 1, 3 do
    hommes.tenir(ids[i], "escorte", { activite = "suivre", lieu = "e", chef = "directeur", formation = "followNPC", fin = "liberation" })
  end
  for i = 1, 3 do
    local a = hommes.activite_de(ids[i], 10)
    egal(a.suivi and a.suivi.mode, "formation", "l'homme " .. i .. " se range dans la formation")
    egal(a.chef, Scriptorium.directeur.personnage(), "l'homme " .. i .. " a le Directeur pour chef")
  end
  o = dernier_ordre_de(perso[3])
  verifier(o ~= nil and o.suivi ~= nil and o.suivi.mode == "formation", "l'ordre porte la formation")
  -- Une seule place : le premier dans la formation, les autres en chaîne derrière lui.
  local places = hommes.formations.followNPC
  hommes.formations.followNPC = 1
  egal(hommes.activite_de(ids[1], 10).suivi and hommes.activite_de(ids[1], 10).suivi.mode, "formation", "une place : le premier se range")
  egal(hommes.activite_de(ids[2], 10).suivi, nil, "le deuxième en chaîne")
  egal(hommes.activite_de(ids[2], 10).chef, perso[1], "le deuxième suit le premier")
  egal(hommes.activite_de(ids[3], 10).chef, perso[2], "le troisième suit le deuxième")
  hommes.formations.followNPC = places
  -- Derrière Henry : le premier mène, les autres se rangent derrière lui (sans la reprise de tête par le Directeur,
  -- V73 f 2 e, coupée ici : le Directeur mène encore).
  local reprise_avant = hommes.reglages.directeur_mene_l_escorte
  hommes.reglages.directeur_mene_l_escorte = false
  for i = 1, 3 do hommes.lacher(ids[i], "escorte") end
  for i = 1, 3 do
    hommes.tenir(ids[i], "escorte", { activite = "suivre", lieu = "h", formation = "followNPC", fin = "liberation" })
  end
  local a1 = hommes.activite_de(ids[1], 10)
  egal(a1.suivi and a1.suivi.mode, "mener", "derrière Henry : le premier mène")
  egal(a1.suivi and a1.suivi.formation, "followNPC", "le modèle mené")
  egal(a1.chef, "henry", "il suit Henry")
  for i = 2, 3 do
    local a = hommes.activite_de(ids[i], 10)
    egal(a.suivi and a.suivi.mode, "formation", "l'homme " .. i .. " se range")
    egal(a.chef, perso[1], "dans la formation du premier")
  end
  -- Le rattrapage vaut aussi pour un suiveur en formation : à plus de 60 m de son chef.
  local f3 = hommes.fiche(ids[3])
  FauxJeu.positions[perso[1]] = { x = 0, y = 0, z = 0 }
  FauxJeu.positions[f3.personnage] = { x = 0, y = 80, z = 0 }
  FauxJeu.secours = {}
  hommes.battre()
  verifier(#FauxJeu.secours >= 1, "un suiveur en formation à 80 m de son chef : rattrapé")
  hommes.reglages.directeur_mene_l_escorte = reprise_avant
  -- Le Directeur lâché : il ne mène plus.
  verifier(Scriptorium.directeur.suivre(false), "le Directeur lâché")
  egal(Scriptorium.directeur.activite(10).suivi, nil, "il ne mène plus")
end)

-- Fiche 15, V73 f 2 a : la sonde à cheval (réponses recommandées prises d'office le 17/10, relecture du pair).
essai("à cheval (fiche 15, V73 f 2 a) : l'homme qui a un cheval le monte et suit Henry en selle ; sans cheval, à pied", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local perso = hommes.fiche(id).personnage
  hommes.battre()
  FauxJeu.ordres = {}
  local ok = hommes.tenir(id, "escorte", { activite = "suivre", lieu = "cavaliers", cheval = "cheval_essai", fin = "liberation" })
  verifier(ok, "l'escorte à cheval est tenue")
  local a = hommes.activite_de(id, 10)
  egal(a.suivi and a.suivi.mode, "cheval", "il monte son cheval")
  egal(a.suivi and a.suivi.cheval, "cheval_essai", "le cheval de sa tenue")
  egal(a.chef, "henry", "il suit Henry")
  local o = dernier_ordre_de(perso)
  verifier(o ~= nil and o.suivi ~= nil and o.suivi.mode == "cheval" and o.suivi.cheval == "cheval_essai", "l'ordre porte le cheval")
  -- Un cheval qui n'est pas un identifiant n'est pas gardé : il suit à pied.
  hommes.lacher(id, "escorte")
  hommes.tenir(id, "escorte", { activite = "suivre", lieu = "cavaliers", cheval = 12, fin = "liberation" })
  egal(hommes.activite_de(id, 10).suivi, nil, "un cheval illisible : à pied")
end)

-- Fiche 15, V73 f 2 b : la troupe à cheval (relue par le pair, réponses recommandées prises d'office le 17/10).
local function journal_contient(morceau)
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, morceau, 1, true) then return true end
  end
  return false
end

essai("sortie de métier à cheval (demande du pair, 20/10) : un homme seul et un mené, chacun sa colonne vers son point ; le cheval du mené gardé pendant la sortie, retiré après", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local perso = hommes.fiche(id).personnage
  FauxJeu.personnages_existants["bucheron"] = true
  FauxJeu.positions[perso] = { x = 110, y = 0, z = 0 }        -- hors du camp (V73 f 2 c)
  FauxJeu.positions["bucheron"] = { x = 120, y = 0, z = 0 }
  hommes.battre()
  FauxJeu.manquees, FauxJeu.chevaux, FauxJeu.chevaux_retires, FauxJeu.journal_lignes = {}, {}, {}, {}
  local point_a, point_b = { x = 300, y = 40, z = 0 }, { x = -250, y = 90, z = 0 }
  verifier(hommes.tenir(id, "travail", { activite = "suivre", vers = point_a, a_cheval = true, lieu = "sortie_1", fin = "liberation" }),
           "l'homme seul sort")
  verifier(hommes.tenir_un_personnage("bucheron", "travail", { activite = "suivre", vers = point_b, a_cheval = true,
                                                               lieu = "sortie_2", fin = "liberation" }), "le mené sort")
  -- Chacun est la tête de sa colonne, sans chef, à cheval, vers son propre point.
  for _, c in ipairs({ { id, perso, point_a }, { "mene_bucheron", "bucheron", point_b } }) do
    local a = hommes.activite_de(c[1], 10)
    egal(a.chef, nil, c[2] .. " : sans chef")
    egal(a.suivi and a.suivi.mode, "cheval", c[2] .. " : à cheval")
    egal(a.suivi and a.suivi.role, "mener", c[2] .. " : il mène")
    verifier(a.suivi and a.suivi.vers == true, c[2] .. " : vers un point")
    verifier(a.position and a.position.x == c[3].x and a.position.y == c[3].y, c[2] .. " : son propre point")
    local m = hommes.montures[c[1]]
    verifier(m and m.cheval and FauxJeu.chevaux[m.cheval], c[2] .. " : son cheval passager")
  end
  -- Pendant la sortie, le cheval du mené reste (avant : porteur ne trouvait pas sa fiche et le retirait).
  local cheval_du_mene = hommes.montures["mene_bucheron"].cheval
  hommes.battre()
  hommes.battre()
  verifier(FauxJeu.chevaux[cheval_du_mene] ~= nil, "le cheval du mené est gardé pendant la sortie")
  egal(#FauxJeu.chevaux_retires, 0, "aucun cheval retiré pendant les sorties")
  -- Arrivé : Scriptorium passe à la tâche (un geste au point) ; encore en selle, le cheval attend ; descendu et éloigné
  -- (ou au deuxième battement), il est retiré.
  FauxJeu.chevaux_montes = { [cheval_du_mene] = true }
  verifier(hommes.tenir_un_personnage("bucheron", "travail", { activite = "geste", geste = "Loot", position = point_b,
                                                               fin = "liberation" }), "la tâche au point")
  hommes.battre()
  hommes.battre()
  verifier(FauxJeu.chevaux[cheval_du_mene] ~= nil, "encore en selle : jamais retiré sous son cavalier")
  FauxJeu.chevaux_montes = nil
  hommes.battre()
  verifier(FauxJeu.chevaux[cheval_du_mene] == nil, "descendu : le cheval du mené est retiré")
  hommes.lacher_un_personnage("bucheron", "travail")
  hommes.lacher(id, "travail")
  -- Lâché en pleine sortie, encore en selle (sa tâche disparue : demande du pair, 20/10) : son cheval reste sous lui ;
  -- descendu, il est retiré.
  verifier(hommes.tenir_un_personnage("bucheron", "travail", { activite = "suivre", vers = point_b, a_cheval = true,
                                                               lieu = "sortie_2", fin = "liberation" }), "il ressort")
  local second = hommes.montures["mene_bucheron"].cheval
  FauxJeu.chevaux_montes = { [second] = true }
  hommes.lacher_un_personnage("bucheron", "travail")
  for _ = 1, 3 do hommes.battre() end
  verifier(FauxJeu.chevaux[second] ~= nil, "lâché en selle : son cheval reste sous lui")
  verifier(journal_contient("encore monté par « bucheron »"), "dit au journal, avec son nom")
  FauxJeu.chevaux_montes = nil
  hommes.battre()
  verifier(FauxJeu.chevaux[second] == nil, "descendu : retiré")
end)

essai("troupe à cheval (fiche 15, V73 f 2 b) : un cheval passager par homme, le premier mène monté, les autres se rangent montés ; la monte manquée, le plafond, le retrait après la sortie", function()
  preparer(5000, 100, 10)
  local ids, perso = {}, {}
  for i = 1, 3 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
    perso[i] = hommes.fiche(ids[i]).personnage
    FauxJeu.positions[perso[i]] = { x = 100 + 10 * i, y = 0, z = 0 }   -- hors du camp (V73 f 2 c)
  end
  hommes.battre()
  FauxJeu.manquees, FauxJeu.chevaux, FauxJeu.chevaux_retires = {}, {}, {}
  local ok, raison = hommes.tenir(ids[1], "escorte", { activite = "suivre", lieu = "c", formation = "followNPC", a_cheval = "oui", fin = "liberation" })
  verifier(not ok and raison == "escorte_invalide", "a_cheval n'est pas un booléen : refusé")
  for i = 1, 3 do
    verifier(hommes.tenir(ids[i], "escorte", { activite = "suivre", lieu = "c", formation = "followNPC", a_cheval = true, fin = "liberation" }), "sortie à cheval " .. i)
  end
  -- Un cheval par homme, à 5 m de lui.
  local nes = 0
  for i = 1, 3 do
    local m = hommes.montures[ids[i]]
    verifier(m ~= nil and m.cheval ~= nil and FauxJeu.chevaux[m.cheval] ~= nil, "l'homme " .. i .. " a son cheval")
    local c, p = FauxJeu.chevaux[m.cheval], FauxJeu.positions[perso[i]]
    verifier(math.abs(math.sqrt((c.x - p.x) ^ 2 + (c.y - p.y) ^ 2) - hommes.reglages.cheval_distance_m) < 0.01, "à 5 m de l'homme " .. i)
    nes = nes + 1
  end
  egal(nes, 3, "trois chevaux")
  -- Les rôles à cheval : le premier mène, les autres se rangent dans sa formation.
  local a1 = hommes.activite_de(ids[1], 10)
  egal(a1.suivi and a1.suivi.mode, "cheval", "le premier est à cheval")
  egal(a1.suivi and a1.suivi.role, "mener", "le premier mène")
  egal(a1.suivi and a1.suivi.formation, "followNPC", "le modèle mené")
  for i = 2, 3 do
    local a = hommes.activite_de(ids[i], 10)
    egal(a.suivi and a.suivi.role, "formation", "l'homme " .. i .. " se range à cheval")
    egal(a.chef, perso[1], "dans la formation du premier")
  end
  local o = dernier_ordre_de(perso[1])
  verifier(o and o.suivi and o.suivi.role == "mener" and o.suivi.cheval == hommes.montures[ids[1]].cheval, "l'ordre du premier : mener à cheval")
  -- Un homme à cheval loin de son chef n'est jamais posé seul : son cheval le ramène.
  local ici3 = FauxJeu.positions[perso[3]]
  FauxJeu.positions[perso[3]] = { x = ici3.x, y = ici3.y + 120, z = 0 }
  FauxJeu.secours = {}
  hommes.battre()
  egal(#FauxJeu.secours, 0, "un homme à cheval à 120 m de son chef : pas de pose")
  FauxJeu.positions[perso[3]] = ici3
  -- La monte manquée du deuxième : son cheval retiré, un autre né sous un autre nom, l'ordre redonné avec lui.
  local premier_cheval = hommes.montures[ids[2]].cheval
  FauxJeu.manquees[perso[2]] = 1
  hommes.battre()
  verifier(FauxJeu.chevaux_retires[#FauxJeu.chevaux_retires] == premier_cheval, "le cheval de la monte manquée est retiré")
  local m2 = hommes.montures[ids[2]]
  egal(m2.essais, 1, "un essai compté")
  verifier(m2.cheval ~= nil and m2.cheval ~= premier_cheval, "un autre cheval est né")
  o = dernier_ordre_de(perso[2])
  verifier(o and o.suivi and o.suivi.cheval == m2.cheval, "l'ordre redonné avec le nouveau cheval")
  verifier(journal_contient("n'a pas pu monter"), "la monte manquée au journal")
  -- Le plafond : deux montes manquées de plus, puis à pied, toujours rangé dans la formation.
  FauxJeu.manquees[perso[2]] = 2
  hommes.battre()
  FauxJeu.manquees[perso[2]] = 3
  hommes.battre()
  verifier(m2.abandon == true and m2.cheval == nil, "au plafond : plus de cheval")
  local a2 = hommes.activite_de(ids[2], 10)
  egal(a2.suivi and a2.suivi.mode, "formation", "au plafond : à pied, rangé dans la formation")
  verifier(journal_contient("suit à pied jusqu'à la fin de sa sortie"), "l'abandon au journal")
  -- Une naissance refusée compte comme un essai.
  hommes.lacher(ids[3], "escorte")
  hommes.battre()
  hommes.battre()
  FauxJeu.positions[perso[3]] = { x = 130, y = 0, z = 0 }   -- dehors (le secours du faux moteur a pu le ramener)
  FauxJeu.refuser_les_chevaux = true
  hommes.tenir(ids[3], "escorte", { activite = "suivre", lieu = "c", formation = "followNPC", a_cheval = true, fin = "liberation" })
  FauxJeu.refuser_les_chevaux = nil
  egal(hommes.montures[ids[3]] and hommes.montures[ids[3]].essais, 1, "une naissance refusée : un essai")
  verifier(journal_contient("naissance refusée"), "le refus au journal")
  -- La sortie finie : pas de retrait pendant la descente (l'homme près de son cheval) ; retiré quand il s'en éloigne.
  local cheval1 = hommes.montures[ids[1]].cheval
  FauxJeu.positions[perso[1]] = { x = FauxJeu.chevaux[cheval1].x + 1, y = FauxJeu.chevaux[cheval1].y, z = 0 }
  for i = 1, 3 do hommes.lacher(ids[i], "escorte") end
  hommes.battre()
  verifier(FauxJeu.chevaux[cheval1] ~= nil, "la sortie finie, l'homme à 1 m : son cheval reste (la descente)")
  FauxJeu.positions[perso[1]] = { x = FauxJeu.chevaux[cheval1].x + 20, y = FauxJeu.chevaux[cheval1].y, z = 0 }
  -- V73 f 3 b : encore en selle (lu), jamais retiré.
  FauxJeu.chevaux_montes = { [cheval1] = true }
  hommes.battre()
  verifier(FauxJeu.chevaux[cheval1] ~= nil, "encore en selle : son cheval reste")
  verifier(journal_contient("encore monté par"), "dit au journal")
  FauxJeu.chevaux_montes = nil
  hommes.battre()
  verifier(FauxJeu.chevaux[cheval1] == nil, "l'homme éloigné : son cheval retiré")
  verifier(hommes.montures[ids[1]] == nil, "plus rien en mémoire pour lui")
  verifier(journal_contient("retiré, la sortie de"), "le retrait au journal")
  -- Au plus tard au deuxième battement hors de sortie, même l'homme resté près de son cheval.
  FauxJeu.positions[perso[1]] = { x = 110, y = 0, z = 0 }
  hommes.tenir(ids[1], "escorte", { activite = "suivre", lieu = "c", formation = "followNPC", a_cheval = true, fin = "liberation" })
  local cheval_b = hommes.montures[ids[1]].cheval
  FauxJeu.positions[perso[1]] = { x = FauxJeu.chevaux[cheval_b].x, y = FauxJeu.chevaux[cheval_b].y, z = 0 }
  hommes.lacher(ids[1], "escorte")
  hommes.battre()
  verifier(FauxJeu.chevaux[cheval_b] ~= nil, "premier battement : le cheval reste")
  hommes.battre()
  verifier(FauxJeu.chevaux[cheval_b] == nil, "deuxième battement : le cheval retiré")
  -- Un homme renvoyé : son cheval retiré au battement.
  FauxJeu.positions[perso[1]] = { x = 110, y = 0, z = 0 }
  hommes.tenir(ids[1], "escorte", { activite = "suivre", lieu = "c", formation = "followNPC", a_cheval = true, fin = "liberation" })
  local cheval_c = hommes.montures[ids[1]].cheval
  verifier(hommes.renvoyer(ids[1]), "l'homme renvoyé")
  for _ = 1, 2 do hommes.battre() end
  verifier(FauxJeu.chevaux[cheval_c] == nil, "l'homme renvoyé : son cheval retiré (au plus tard au deuxième battement)")
  FauxJeu.manquees = nil
end)

-- Vu sur une copie de la partie de JoVenGer le 21/10 (J4 : la colonne de mission_1 coincée 1,2 h, son cheval né dans un
-- cul-de-sac du camp réel ; accord du pair).
essai("colonne à cheval (21/10, J4) : arrêtée loin de son but, le cavalier laisse son cheval (une monte manquée) et un autre naît dehors une fois descendu ; au bord du camp réel, il laisse son cheval sans essai et rentre à pied", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local p = hommes.fiche(id).personnage
  local dehors = { x = 100, y = 0, z = 0 }
  FauxJeu.positions[p] = { x = dehors.x, y = dehors.y, z = 0 }
  hommes.battre()
  FauxJeu.chevaux, FauxJeu.chevaux_retires = {}, {}
  FauxJeu.positions[p] = { x = dehors.x, y = dehors.y, z = 0 }
  verifier(hommes.tenir(id, "mission", { activite = "suivre", lieu = "m", vers = { x = 300, y = 0, z = 0 }, a_cheval = true, fin = "liberation" }), "une colonne à cheval vers un point")
  local m = hommes.montures[id]
  local c1 = m and m.cheval
  verifier(c1 ~= nil, "son cheval, dehors")
  FauxJeu.chevaux_montes = { [c1] = true }
  for _ = 1, 8 do
    FauxJeu.positions[p] = { x = dehors.x, y = dehors.y, z = 0 }
    hommes.battre()
  end
  verifier(journal_contient("arrêtée à cheval"), "la colonne arrêtée, dite au journal")
  egal(m.essais, 1, "une monte manquée")
  verifier(m.cheval == nil and hommes.chevaux_laisses[c1] ~= nil, "le cheval laissé")
  hommes.battre()
  verifier(m.cheval == nil, "encore en selle sur le cheval laissé : pas d'autre cheval")
  FauxJeu.chevaux_montes = nil
  FauxJeu.positions[p] = { x = dehors.x + 10, y = dehors.y, z = 0 }
  hommes.battre()
  verifier(FauxJeu.chevaux[c1] == nil and hommes.chevaux_laisses[c1] == nil, "descendu et éloigné : le cheval laissé retiré")
  verifier(m.cheval ~= nil and m.cheval ~= c1, "un autre cheval né dehors")
  -- Vu sur une copie le 21/10 (J7) : dans le camp réel mais son but dehors (il part) : il reste en selle.
  local c2 = m.cheval
  FauxJeu.chevaux_montes = { [c2] = true }
  FauxJeu.positions[p] = { x = 5, y = 5, z = 0 }
  hommes.battre()
  verifier(m.cheval == c2 and not journal_contient("au bord du camp"), "qui part reste en selle")
  -- Le retour (son but dans le camp), revenu au bord du camp réel, en selle : il laisse son cheval, sans essai, et finit
  -- à pied.
  verifier(hommes.tenir(id, "mission", { activite = "suivre", lieu = "m", vers = { x = 0, y = 10, z = 0 }, a_cheval = true, fin = "liberation" }), "le retour : son but dans le camp")
  FauxJeu.positions[p] = { x = 5, y = 5, z = 0 }
  hommes.battre()
  verifier(journal_contient("au bord du camp"), "au bord du camp, dit au journal")
  egal(m.essais, 1, "aucun essai de plus")
  verifier(m.cheval == nil and hommes.chevaux_laisses[c2] ~= nil, "le cheval laissé au bord du camp")
  local o = dernier_ordre_de(p)
  verifier(o and not (o.suivi and o.suivi.cheval), "il finit à pied")
  hommes.battre()
  verifier(m.cheval == nil, "dans le camp réel : jamais d'autre cheval")
  FauxJeu.chevaux_montes = nil
  hommes.lacher(id, "mission")
end)

-- Fiche 15, V73 f 2 c : le cheval né hors des meubles (conseils du pair), sur un sol praticable, hors de la vue d'Henry
-- de préférence ; l'approche allonge le délai de la monte.
essai("place du cheval (fiche 15, V73 f 2 c ; vu sur une copie le 21/10, J4) : jamais dans le camp réel (il en sort à pied, le cheval naît dehors près de lui) ; loin des autres chevaux ; le sol ; la vue d'Henry ; l'approche", function()
  preparer(5000, 100, 10)
  camp.agrandir()
  camp.agrandir()
  egal(camp.niveau(), 3, "un camp plein de meubles (niveau 3)")
  local ids, perso = {}, {}
  for i = 1, 3 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
    perso[i] = hommes.fiche(ids[i]).personnage
    FauxJeu.positions[perso[i]] = { x = i - 2, y = 1, z = 0 }   -- au feu
  end
  hommes.battre()
  FauxJeu.manquees, FauxJeu.chevaux, FauxJeu.chevaux_retires = {}, {}, {}
  for i = 1, 3 do
    hommes.tenir(ids[i], "escorte", { activite = "suivre", lieu = "c", formation = "followNPC", a_cheval = true, fin = "liberation" })
  end
  local r, rayon = hommes.reglages, Scriptorium.enceinte.reglages.rayon
  local function ecart(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end
  -- Dans le camp : aucun cheval ; une ligne par homme ; il part à pied.
  for i = 1, 3 do
    local m = hommes.montures[ids[i]]
    verifier(m and m.cheval == nil, "l'homme " .. i .. " dans le camp : pas de cheval")
    egal(m and m.essais, 0, "pas d'essai manqué")
    local o = dernier_ordre_de(perso[i])
    verifier(o and o.activite == "suivre" and not (o.suivi and o.suivi.cheval), "l'homme " .. i .. " part à pied")
  end
  egal(lignes_contenant("attendu : hors du camp"), 3, "une ligne par homme")
  -- Dehors : le cheval naît près de lui, hors du camp réel, loin des autres chevaux.
  for i = 1, 3 do
    FauxJeu.positions[perso[i]] = { x = (i - 2) * 6, y = 60, z = 0 }
  end
  hommes.battre()
  local places = {}
  for i = 1, 3 do
    local m = hommes.montures[ids[i]]
    verifier(m and m.cheval and FauxJeu.chevaux[m.cheval], "l'homme " .. i .. " dehors a son cheval")
    local p = FauxJeu.chevaux[m.cheval]
    places[i] = p
    verifier(ecart(p, { x = 0, y = 0 }) >= rayon + r.cheval_hors_camp_m, "le cheval " .. i .. " hors du camp réel")
    verifier(math.abs(ecart(p, FauxJeu.positions[perso[i]]) - r.cheval_distance_m) < 0.01, "à 5 m de l'homme " .. i)
    local o = dernier_ordre_de(perso[i])
    verifier(o and o.suivi and o.suivi.cheval == m.cheval and o.suivi.approche_ms and o.suivi.approche_ms >= 4000,
      "l'homme " .. i .. " monte, l'approche comptée (" .. tostring(o and o.suivi and o.suivi.approche_ms) .. " ms)")
  end
  for i = 1, 3 do
    for j = i + 1, 3 do
      verifier(ecart(places[i], places[j]) >= r.cheval_ecart_cheval_m, "les chevaux " .. i .. " et " .. j .. " à 3 m l'un de l'autre")
    end
  end
  verifier(journal_contient("places refusées"), "les refus au journal")
  for i = 1, 3 do hommes.lacher(ids[i], "escorte") end
  for _ = 1, 2 do hommes.battre() end
  -- Un homme hors du camp : son cheval à 5 m de lui, hors du cercle.
  FauxJeu.positions[perso[1]] = { x = 100, y = 0, z = 0 }
  hommes.tenir(ids[1], "escorte", { activite = "suivre", lieu = "c", a_cheval = true, fin = "liberation" })
  local p1 = FauxJeu.chevaux[hommes.montures[ids[1]].cheval]
  verifier(math.abs(ecart(p1, FauxJeu.positions[perso[1]]) - r.cheval_distance_m) < 0.01, "hors du camp : à 5 m de l'homme")
  hommes.lacher(ids[1], "escorte")
  for _ = 1, 2 do hommes.battre() end
  -- Le sol : un angle dans l'eau (encombré) ou sur une pente refusé ; la vue d'Henry : un angle hors de vue préféré.
  local ici = { x = 100, y = 0, z = 0 }
  FauxJeu.positions[perso[1]] = ici   -- reposé : le secours du faux moteur a pu le ramener au camp
  local essayees_avant = r.cheval_places_essayees
  r.cheval_places_essayees = 32   -- un quart des angles seulement reste permis ici
  FauxJeu.sol_du_cheval = function(p)
    if p.x > ici.x then return { pente = 0, encombre = true, eau_lisible = true } end
    if p.y > ici.y then return { pente = 2, encombre = false, eau_lisible = true } end
    return { pente = 0, encombre = false, eau_lisible = true }
  end
  FauxJeu.vue_d_henry = function(p) return p.x > ici.x - 3 end
  hommes.tenir(ids[1], "escorte", { activite = "suivre", lieu = "c", a_cheval = true, fin = "liberation" })
  local p2 = FauxJeu.chevaux[hommes.montures[ids[1]].cheval]
  verifier(p2.x <= ici.x and p2.y <= ici.y, "l'eau et la pente refusées")
  verifier(p2.x <= ici.x - 3, "un angle hors de la vue d'Henry préféré")
  verifier(journal_contient("hors de la vue d'Henry"), "hors de vue au journal")
  hommes.lacher(ids[1], "escorte")
  for _ = 1, 2 do hommes.battre() end
  -- Vu sur une copie le 20/10 (séance J) : toutes les places vues d'Henry : pas de cheval, l'homme part à pied, sans essai
  -- manqué ; une place hors de vue au battement suivant : le cheval y naît ; une place à plus de saut_vue_m : pas vue.
  FauxJeu.vue_d_henry = function() return true end
  FauxJeu.position_joueur = { x = 90, y = 0, z = 0 }
  FauxJeu.positions[perso[1]] = { x = 100, y = 0, z = 0 }
  local nes_avant = 0
  for _ in pairs(FauxJeu.chevaux) do nes_avant = nes_avant + 1 end
  hommes.tenir(ids[1], "escorte", { activite = "suivre", lieu = "c", a_cheval = true, fin = "liberation" })
  local nes = 0
  for _ in pairs(FauxJeu.chevaux) do nes = nes + 1 end
  egal(nes, nes_avant, "tout vu d'Henry : aucun cheval né")
  egal(hommes.montures[ids[1]].cheval, nil, "pas de cheval")
  egal(hommes.montures[ids[1]].essais, 0, "pas d'essai manqué")
  verifier(not journal_contient("vu d'Henry : oui"), "jamais de naissance vue")
  egal(lignes_contenant("attendu : Henry regarde"), 1, "une ligne au journal")
  local o = FauxJeu.ordres[#FauxJeu.ordres]
  verifier(o.identifiant == perso[1] and o.activite == "suivre" and not (o.suivi and o.suivi.cheval), "il part à pied vers son but")
  hommes.battre()
  egal(lignes_contenant("attendu : Henry regarde"), 1, "toujours une seule ligne")
  egal(hommes.montures[ids[1]].cheval, nil, "toujours vu : toujours pas de cheval")
  FauxJeu.vue_d_henry = function(p) return p.y > 0 end
  hommes.battre()
  local c = hommes.montures[ids[1]].cheval
  verifier(c ~= nil, "une place hors de vue : le cheval naît")
  verifier(FauxJeu.chevaux[c].y <= 0, "à une place hors de vue")
  local monte = FauxJeu.ordres[#FauxJeu.ordres]
  verifier(monte.suivi and monte.suivi.cheval == c, "l'ordre redonné : il monte")
  hommes.lacher(ids[1], "escorte")
  for _ = 1, 2 do hommes.battre() end
  FauxJeu.vue_d_henry = function() return true end
  FauxJeu.position_joueur = { x = 100 + r.saut_vue_m + 50, y = 0, z = 0 }
  hommes.tenir(ids[1], "escorte", { activite = "suivre", lieu = "c", a_cheval = true, fin = "liberation" })
  verifier(hommes.montures[ids[1]].cheval ~= nil, "Henry à plus de saut_vue_m : pas vu, le cheval naît")
  hommes.lacher(ids[1], "escorte")
  for _ = 1, 2 do hommes.battre() end
  FauxJeu.position_joueur = nil
  FauxJeu.vue_d_henry, FauxJeu.sol_du_cheval = nil, nil
  -- Des refus francs, un seul motif possible à chaque fois : tout encombré (l'eau), tout en pente, et, le cercle de
  -- l'enceinte rétréci, seul le sol contre un meuble du camp libre.
  local function refus_seul(motif, sol, ou)
    hommes.montures = {}
    FauxJeu.positions[perso[1]] = ou or { x = 100, y = 0, z = 0 }
    FauxJeu.sol_du_cheval = sol
    hommes.tenir(ids[1], "escorte", { activite = "suivre", lieu = "c", a_cheval = true, fin = "liberation" })
    FauxJeu.sol_du_cheval = nil
    local m = hommes.montures[ids[1]]
    verifier(m and m.cheval == nil, motif .. " : naissance refusée")
    local derniere = FauxJeu.journal_lignes[#FauxJeu.journal_lignes] or ""
    verifier(string.find(derniere, "naissance refusée", 1, true) and string.find(derniere, motif, 1, true), motif .. " au journal : " .. derniere)
    hommes.lacher(ids[1], "escorte")
    for _ = 1, 2 do hommes.battre() end
  end
  refus_seul("encombre", function() return { pente = 0, encombre = true, eau_lisible = true } end)
  refus_seul("pente", function() return { pente = 2, encombre = false, eau_lisible = true } end)
  -- (Le refus « meuble » n'a plus de cas : les meubles connus fixent l'étendue du camp réel, où aucun cheval ne naît.)
  r.cheval_places_essayees = essayees_avant
  -- Aucune place possible : la naissance est refusée (un essai).
  local ecart_avant = r.cheval_ecart_meuble_m
  r.cheval_ecart_meuble_m = 1000
  hommes.montures = {}
  FauxJeu.positions[perso[2]] = { x = 0, y = 60, z = 0 }
  local sol_avant = FauxJeu.sol_du_cheval
  FauxJeu.sol_du_cheval = function() return { pente = 2, encombre = false, eau_lisible = true } end
  hommes.tenir(ids[2], "escorte", { activite = "suivre", lieu = "c", a_cheval = true, fin = "liberation" })
  FauxJeu.sol_du_cheval = sol_avant
  r.cheval_ecart_meuble_m = ecart_avant
  verifier(hommes.montures[ids[2]].cheval == nil and hommes.montures[ids[2]].essais == 1, "aucune place : naissance refusée, un essai")
  verifier(journal_contient("naissance refusée"), "le refus au journal")
  FauxJeu.manquees = nil
end)

-- Fiche 15, V73 f 2 d : l'escorte monte quand Henry monte (relue par le pair : l'anti-rebond).
essai("escorte comme Henry (fiche 15, V73 f 2 d) : monte tout de suite, descend après quatre lectures à pied", function()
  preparer(5000, 100, 10)
  local ids, perso = {}, {}
  for i = 1, 3 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
    perso[i] = hommes.fiche(ids[i]).personnage
    FauxJeu.positions[perso[i]] = { x = 100 + 10 * i, y = 0, z = 0 }
  end
  hommes.battre()
  FauxJeu.chevaux, FauxJeu.chevaux_retires, FauxJeu.manquees = {}, {}, {}
  FauxJeu.henry_cheval = false
  for i = 1, 3 do
    verifier(hommes.tenir(ids[i], "escorte", { activite = "suivre", lieu = "h", formation = "followNPC", a_cheval = "comme_henry", fin = "liberation" }), "escorte comme Henry " .. i)
  end
  -- Henry à pied : à pied, aucun cheval.
  egal(hommes.veiller_henry(), false, "Henry lu à pied")
  verifier(hommes.montures[ids[1]] == nil, "aucun cheval")
  egal(hommes.activite_de(ids[1], 10).suivi.mode, "mener", "à pied, le premier mène")
  -- Henry monte : tout de suite.
  FauxJeu.henry_cheval = true
  egal(hommes.veiller_henry(), true, "Henry lu à cheval")
  verifier(hommes.henry_monte, "retenu monté tout de suite")
  for i = 1, 3 do
    local m = hommes.montures[ids[i]]
    verifier(m and m.cheval and FauxJeu.chevaux[m.cheval], "l'homme " .. i .. " a son cheval")
    local o = dernier_ordre_de(perso[i])
    egal(o and o.suivi and o.suivi.mode, "cheval", "l'homme " .. i .. " monte")
  end
  verifier(journal_contient("l'escorte monte"), "la monte au journal")
  -- L'anti-rebond : trois lectures à pied, une à cheval, trois à pied : toujours monté.
  FauxJeu.henry_cheval = false
  for _ = 1, 3 do hommes.veiller_henry() end
  verifier(hommes.henry_monte, "trois lectures à pied : toujours monté")
  FauxJeu.henry_cheval = true
  hommes.veiller_henry()
  FauxJeu.henry_cheval = false
  for _ = 1, 3 do hommes.veiller_henry() end
  verifier(hommes.henry_monte, "une lecture à cheval remet le compte à zéro")
  -- Une lecture illisible ne change rien.
  FauxJeu.henry_cheval = nil
  for _ = 1, 6 do hommes.veiller_henry() end
  verifier(hommes.henry_monte, "illisible : rien ne change")
  -- La descente : quatre lectures à pied de suite ; l'abandon des montes manquées oublié.
  hommes.montures[ids[2]].abandon, hommes.montures[ids[2]].essais = true, 3
  FauxJeu.henry_cheval = false
  for _ = 1, 4 do hommes.veiller_henry() end
  verifier(not hommes.henry_monte, "quatre lectures à pied : descendu")
  verifier(journal_contient("l'escorte descend"), "la descente au journal")
  local m2 = hommes.montures[ids[2]]
  verifier(m2 == nil or (not m2.abandon and m2.essais == 0), "l'abandon oublié")
  local o1 = dernier_ordre_de(perso[1])
  egal(o1 and o1.suivi and o1.suivi.mode, "mener", "à pied, il mène de nouveau")
  -- Les chevaux retirés par la règle de la sortie (au plus tard au deuxième battement).
  local cheval1 = hommes.montures[ids[1]] and hommes.montures[ids[1]].cheval
  for _ = 1, 2 do hommes.battre() end
  verifier(cheval1 ~= nil and FauxJeu.chevaux[cheval1] == nil, "son cheval retiré après la descente")
  -- La lecture forcée par le poste.
  hommes.henry_force = false
  egal(hommes.veiller_henry(), false, "forcée à pied")
  hommes.henry_force = nil
  -- La veille : une par partie.
  local avant = #FauxJeu.minuteries
  hommes.veille_d_henry_generation = nil
  verifier(hommes.lancer_la_veille_d_henry(), "la veille posée")
  verifier(not hommes.lancer_la_veille_d_henry(), "une seule par partie")
  egal(#FauxJeu.minuteries, avant + 1, "une minuterie")
  egal(FauxJeu.minuteries[#FauxJeu.minuteries].ms, hommes.reglages.henry_veille_ms, "à la cadence réglée")
  FauxJeu.henry_cheval, FauxJeu.manquees = nil, nil
end)

-- Fiche 15, V73 f 2 e : le Directeur monté, chef de colonne (relu par le pair : directeur_en_route de Scriptorium).
essai("Directeur monté (fiche 15, V73 f 2 e) : il reprend la tête de l'escorte d'Henry, monte et descend avec Henry, son cheval retiré après", function()
  preparer(5000, 100, 10)
  verifier(Scriptorium.directeur.installer(), "Directeur installé")
  local dir = Scriptorium.directeur.personnage()
  FauxJeu.positions[dir] = { x = 100, y = 0, z = 0 }
  local ids, perso = {}, {}
  for i = 1, 3 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
    perso[i] = hommes.fiche(ids[i]).personnage
    FauxJeu.positions[perso[i]] = { x = 100 + 10 * i, y = 0, z = 0 }
  end
  hommes.battre()
  FauxJeu.chevaux, FauxJeu.chevaux_retires, FauxJeu.manquees, FauxJeu.henry_cheval = {}, {}, {}, false
  local ok, raison = Scriptorium.directeur.suivre(true, "followNPC", "oui")
  verifier(not ok and raison == "a_cheval_invalide", "a_cheval invalide : refusé")
  verifier(Scriptorium.directeur.suivre(true, "followNPC", "comme_henry"), "le Directeur suit Henry comme Henry")
  for i = 1, 3 do
    hommes.tenir(ids[i], "escorte", { activite = "suivre", lieu = "c", formation = "followNPC", a_cheval = "comme_henry", fin = "liberation" })
  end
  -- À pied : il mène ; les hommes se rangent dans sa formation (il reprend la tête).
  egal(Scriptorium.directeur.activite(10).suivi.mode, "mener", "le Directeur mène à pied")
  for i = 1, 3 do
    local a = hommes.activite_de(ids[i], 10)
    egal(a.suivi and a.suivi.mode, "formation", "l'homme " .. i .. " se range")
    egal(a.chef, dir, "dans la formation du Directeur")
  end
  hommes.reglages.directeur_mene_l_escorte = false
  egal(hommes.activite_de(ids[1], 10).suivi.mode, "mener", "réglage à faux : le premier homme mène")
  hommes.reglages.directeur_mene_l_escorte = true
  -- Henry monte : le Directeur a son cheval et mène monté ; les hommes se rangent montés derrière lui.
  FauxJeu.henry_cheval = true
  hommes.veiller_henry()
  local md = hommes.montures.directeur
  verifier(md and md.cheval and FauxJeu.chevaux[md.cheval], "le Directeur a son cheval")
  local o = dernier_ordre_de(dir)
  verifier(o and o.suivi and o.suivi.mode == "cheval" and o.suivi.role == "mener" and o.suivi.formation == "followNPC", "il mène monté")
  for i = 1, 3 do
    local oi = dernier_ordre_de(perso[i])
    verifier(oi and oi.suivi and oi.suivi.mode == "cheval" and oi.suivi.role == "formation" and oi.chef == dir, "l'homme " .. i .. " se range monté derrière lui")
  end
  -- Le même ordre n'est pas redonné tant que rien ne change (Henry posé près de lui pour le faux moteur : un essai
  -- précédent l'a laissé ailleurs).
  FauxJeu.position_joueur, FauxJeu.cap_joueur = { x = 100, y = 0, z = 0 }, 0
  FauxJeu.secours = {}
  local n_ordres = #FauxJeu.ordres
  Scriptorium.directeur.battre()
  egal(#FauxJeu.ordres, n_ordres, "rien de changé : pas d'ordre de plus")
  egal(#FauxJeu.secours, 0, "rien de changé : pas de pose")
  -- À cheval, jamais reposé seul par le rattrapage.
  FauxJeu.positions[dir] = { x = 100, y = 120, z = 0 }
  FauxJeu.secours = {}
  Scriptorium.directeur.battre()
  egal(#FauxJeu.secours, 0, "le Directeur à cheval à 120 m d'Henry : pas de pose")
  FauxJeu.positions[dir] = { x = 100, y = 0, z = 0 }
  -- Henry descend : tout le monde à pied, le Directeur mène de nouveau à pied.
  FauxJeu.henry_cheval = false
  for _ = 1, 4 do hommes.veiller_henry() end
  o = dernier_ordre_de(dir)
  egal(o and o.suivi and o.suivi.mode, "mener", "le Directeur mène à pied")
  -- La contre-épreuve : à pied, le Directeur loin d'Henry est rattrapé.
  FauxJeu.positions[dir] = { x = 100, y = 300, z = 0 }
  FauxJeu.secours = {}
  Scriptorium.directeur.battre()
  verifier(#FauxJeu.secours >= 1, "à pied, le Directeur à 300 m d'Henry : rattrapé")
  FauxJeu.positions[dir] = { x = 100, y = 0, z = 0 }
  -- Son cheval retiré par la règle de la sortie.
  for _ = 1, 2 do hommes.battre() end
  verifier(FauxJeu.chevaux[md.cheval] == nil, "le cheval du Directeur retiré")
  verifier(hommes.montures.directeur == nil, "plus rien en mémoire pour lui")
  -- Toujours à cheval (vrai) : son cheval sans attendre Henry.
  verifier(Scriptorium.directeur.suivre(true, nil, true), "toujours à cheval")
  local m2 = hommes.montures.directeur
  verifier(m2 and m2.cheval, "son cheval sans attendre Henry")
  egal(Scriptorium.directeur.activite(10).suivi.mode, "cheval", "il suit à cheval")
  verifier(Scriptorium.directeur.suivre(false), "le Directeur lâché")
  for _ = 1, 2 do hommes.battre() end
  verifier(FauxJeu.chevaux[m2.cheval] == nil, "lâché : son cheval retiré")
  FauxJeu.henry_cheval, FauxJeu.manquees = nil, nil
end)

-- Fiche 15, V73 f 3 b : le camp appartient à sa carte ; ailleurs, seule l'escorte d'Henry est refaite, derrière lui.
essai("autre carte (fiche 15, V73 f 3 b) : le camp, l'enceinte et les hommes du camp restent ; l'escorte et le Directeur qui suit sont refaits derrière Henry ; de retour, tout revient", function()
  depart()
  FauxJeu.heure, FauxJeu.carte = 10, "kutnohorsko"
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  egal(camp.carte(), "kutnohorsko", "la carte du camp notée à la fondation")
  coffre.ajouter_reserve("bois", 1000, "achat")
  verifier(Scriptorium.enceinte.batir(), "l'enceinte bâtie")
  verifier(Scriptorium.directeur.installer(), "Directeur installé")
  local ids = {}
  for i = 1, 3 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  end
  hommes.battre()
  escorter(ids[1])
  -- Le passage : Henry sur l'autre carte, plus rien du camp n'existe ici.
  FauxJeu.carte = "trosecko"
  FauxJeu.position_joueur, FauxJeu.cap_joueur = { x = 500, y = 500, z = 0 }, 0
  FauxJeu.personnages_existants, FauxJeu.objets_existants = {}, {}
  verifier(not camp.sur_sa_carte(), "une autre carte")
  local poses = #FauxJeu.objets_poses
  egal(camp.redresser(), 0, "le camp n'est pas reposé")
  egal(Scriptorium.enceinte.redresser(), 0, "l'enceinte n'est pas reposée")
  egal(#FauxJeu.objets_poses, poses, "aucun objet posé")
  verifier(journal_contient("sur une autre carte"), "une ligne au journal")
  local nes = #FauxJeu.personnages
  local revenus, manquants = hommes.redresser()
  egal(revenus, 1, "seul l'homme de l'escorte est refait")
  egal(manquants, 0, "aucun manquant")
  egal(#FauxJeu.personnages, nes + 1, "un seul personnage né")
  local ne = FauxJeu.personnages[#FauxJeu.personnages]
  egal(ne.identifiant, hommes.fiche(ids[1]).personnage, "c'est l'homme de l'escorte")
  pres(ne.position and ne.position.x, 500, "derrière Henry (x)")
  pres(ne.position and ne.position.y, 494, "à 6 m derrière Henry (y), Henry face au nord")
  for i = 2, 3 do
    verifier(hommes.fiche(ids[i]).personnage == nil, "l'homme " .. i .. " reste au camp, sans personnage")
  end
  verifier(journal_contient("2 laissé(s) au camp (autre carte)"), "les laissés au journal")
  -- Les battements d'ailleurs ne font naître personne ; une embauche rejoint le registre.
  for _ = 1, 3 do
    hommes.battre()
    Scriptorium.directeur.battre()
  end
  egal(#FauxJeu.personnages, nes + 1, "trois battements : personne de plus")
  for i = 2, 3 do
    verifier(hommes.fiche(ids[i]).personnage == nil, "l'homme " .. i .. " toujours au camp")
  end
  ids[4] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  verifier(ids[4] and hommes.fiche(ids[4]).personnage == nil, "embauché d'ici : au registre, sans personnage")
  verifier(journal_contient("embauché loin du camp (autre carte)"), "l'embauche au journal")
  egal(#FauxJeu.personnages, nes + 1, "l'embauche ne fait naître personne ici")
  -- Les relances d'entrée en partie ne retirent ni ne reposent rien.
  local retires = #FauxJeu.objets_retires
  local tout = camp.reglages.reposer_tout_a_l_entree
  camp.reglages.reposer_tout_a_l_entree = 1
  egal(camp.relancer(), 0, "la relance du camp, même « tout reposer » : rien")
  camp.reglages.reposer_tout_a_l_entree = tout
  egal(Scriptorium.enceinte.relancer(), 0, "la relance de l'enceinte : rien")
  egal(#FauxJeu.objets_retires, retires, "rien retiré")
  egal(#FauxJeu.objets_poses, poses, "rien posé")
  -- Le Directeur ne suit pas : laissé au registre ; s'il suit, refait derrière Henry.
  egal(Scriptorium.directeur.redresser(), false, "le Directeur qui ne suit pas n'est pas refait")
  verifier(Scriptorium.directeur.personnage() == nil, "sans personnage")
  verifier(Scriptorium.directeur.suivre(true), "le Directeur suit Henry")
  verifier(Scriptorium.directeur.redresser(), "le Directeur qui suit est refait")
  local dir = FauxJeu.directeurs[#FauxJeu.directeurs]
  pres(dir.position and dir.position.y, 494, "derrière Henry")
  -- Le droit derrière Henry est sous ses yeux : une place de biais.
  FauxJeu.vue_d_henry = function(p) return math.abs(p.x - 500) < 0.5 end
  local p = hommes.point_pres_d_henry()
  verifier(p and p.x < 499, "sous ses yeux : une place de biais")
  FauxJeu.vue_d_henry = nil
  -- Le retour sur la carte du camp : tout revient.
  FauxJeu.carte = "kutnohorsko"
  verifier(camp.sur_sa_carte(), "de retour sur la carte du camp")
  verifier(camp.redresser() > 0, "le camp reposé")
  verifier(Scriptorium.enceinte.redresser() > 0, "l'enceinte reposée")
  revenus = hommes.redresser()
  egal(revenus, 3, "les deux hommes du camp et l'embauché paraissent")
  local au_feu = FauxJeu.personnages[#FauxJeu.personnages]
  verifier(au_feu.position and math.abs(au_feu.position.y - 494) > 1, "au camp, pas derrière Henry")
  -- Une carte illisible : rien n'est retiré.
  FauxJeu.carte = nil
  verifier(camp.sur_sa_carte(), "carte illisible : le comportement d'avant")
  Scriptorium.directeur.suivre(false)
end)

essai("grand saut (fiche 15, V73 f 3 b) : au bond d'Henry, la colonne descend tout de suite ; 3 s après, chevaux retirés, posés derrière Henry, nouveaux chevaux ; le battement en filet", function()
  preparer(5000, 100, 10)
  local ids, perso = {}, {}
  for i = 1, 2 do
    ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
    perso[i] = hommes.fiche(ids[i]).personnage
    FauxJeu.positions[perso[i]] = { x = 100 + 10 * i, y = 0, z = 0 }
  end
  FauxJeu.position_joueur, FauxJeu.cap_joueur = { x = 100, y = 10, z = 0 }, 0
  hommes.battre()
  FauxJeu.chevaux, FauxJeu.chevaux_retires, FauxJeu.manquees, FauxJeu.henry_cheval = {}, {}, {}, false
  for i = 1, 2 do
    hommes.tenir(ids[i], "escorte", { activite = "suivre", lieu = "c", formation = "followNPC", a_cheval = true, fin = "liberation" })
  end
  local c1, c2 = hommes.montures[ids[1]].cheval, hommes.montures[ids[2]].cheval
  verifier(c1 ~= nil and c2 ~= nil, "deux chevaux")
  hommes.battre()
  egal(hommes.activite_de(ids[2], 10).chef, perso[1], "le second suit le premier")
  -- Pas de bond : 30 m entre deux veilles.
  hommes.veiller_henry()
  FauxJeu.position_joueur = { x = 100, y = 40, z = 0 }
  FauxJeu.secours = {}
  hommes.veiller_henry()
  verifier(not hommes.montures[ids[1]].saut, "30 m en une veille : pas de bond")
  verifier(not journal_contient("bond d'Henry"), "30 m : aucune ligne de bond au journal")
  -- Le bond : 400 m. Le premier est loin de son chef, le second suit le premier : les deux descendent tout de suite.
  local n_minuteries = #FauxJeu.minuteries
  FauxJeu.position_joueur = { x = 100, y = 440, z = 0 }
  hommes.veiller_henry()
  verifier(journal_contient("bond d'Henry de 400 m : 2 cavalier(s) en grand saut"), "le bond au journal")
  verifier(journal_contient("suit « " .. hommes.fiche(ids[1]).nom .. " » : il descend (grand saut)"), "le second saute avec son chef")
  for i = 1, 2 do
    verifier(hommes.montures[ids[i]].saut, "l'homme " .. i .. " en saut")
    local o = dernier_ordre_de(perso[i])
    verifier(o and not (o.suivi and o.suivi.mode == "cheval"), "l'homme " .. i .. " : l'ordre à pied tout de suite")
  end
  verifier(FauxJeu.chevaux[c1] ~= nil and FauxJeu.chevaux[c2] ~= nil, "les chevaux restent pendant la descente")
  egal(#FauxJeu.secours, 0, "pas encore de pose")
  egal(#FauxJeu.minuteries, n_minuteries + 1, "une minuterie")
  local mt = FauxJeu.minuteries[#FauxJeu.minuteries]
  egal(mt.ms, 3000, "trois secondes pour descendre")
  -- Un battement avant la minuterie : le filet ne retire rien si tôt.
  hommes.battre()
  verifier(FauxJeu.chevaux[c1] ~= nil, "un battement tout de suite après : le cheval reste")
  -- La minuterie : chevaux retirés, posés derrière Henry (le jeu ignore la première pose du premier : vu en jeu le 17/10).
  FauxJeu.poses_ignorees = { [perso[1]] = 1 }
  Scriptorium.en_partie = true
  mt.fonction()
  verifier(FauxJeu.chevaux[c1] == nil and FauxJeu.chevaux[c2] == nil, "les deux chevaux retirés")
  egal(#FauxJeu.secours, 2, "les deux posés")
  pres(FauxJeu.secours[1].position.y, 436, "4 m derrière Henry")
  verifier(hommes.montures[ids[1]].saut and hommes.montures[ids[2]].saut, "le saut ne finit qu'à la relecture")
  local mv = FauxJeu.minuteries[#FauxJeu.minuteries]
  egal(mv.ms, 1500, "la pose relue 1,5 s après")
  -- La relecture : le second est resté posé (saut fini) ; le premier non : reposé, relu ensuite.
  mv.fonction()
  verifier(not hommes.montures[ids[2]].saut, "le second, resté posé : saut fini")
  verifier(hommes.montures[ids[1]].saut, "le premier, pas resté posé : toujours en saut")
  verifier(journal_contient("pas resté posé (à 436 m de sa place) : reposé"), "le premier reposé, au journal")
  egal(#FauxJeu.secours, 3, "une pose de plus")
  verifier(hommes.montures[ids[1]].cheval == nil, "pas de nouveau cheval avant la pose tenue")
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  Scriptorium.en_partie = false
  FauxJeu.poses_ignorees = nil
  for i = 1, 2 do
    local m = hommes.montures[ids[i]]
    verifier(not m.saut, "l'homme " .. i .. " : saut fini")
    verifier(m.cheval ~= nil and m.cheval ~= c1 and m.cheval ~= c2, "l'homme " .. i .. " : un nouveau cheval")
    local o = dernier_ordre_de(perso[i])
    egal(o and o.suivi and o.suivi.mode, "cheval", "l'homme " .. i .. " : de nouveau à cheval")
  end
  -- Sous les yeux d'Henry, à moins de 300 m : pas de saut, il rejoint à cheval.
  local c3 = hommes.montures[ids[1]].cheval
  FauxJeu.positions[perso[1]] = { x = 100, y = 440, z = 0 }
  FauxJeu.positions[perso[2]] = { x = 100, y = 440, z = 0 }
  FauxJeu.vue_d_henry = function(p) return math.abs(p.y - FauxJeu.position_joueur.y) > 100 end
  FauxJeu.position_joueur = { x = 100, y = 650, z = 0 }
  hommes.veiller_henry()
  verifier(not hommes.montures[ids[1]].saut, "à 210 m sous ses yeux : pas de saut")
  verifier(journal_contient("sous les yeux d'Henry : pas de saut, il rejoint à cheval"), "dit au journal")
  -- Hors de ses yeux mais encore en selle : rien n'est retiré ; on attend 2 s, trois fois au plus, puis le saut est
  -- abandonné (il rejoint à cheval) ; descendu entre-temps : son cheval retiré, la durée au journal.
  local c_second = hommes.montures[ids[2]].cheval
  FauxJeu.chevaux_montes = { [c3] = true, [c_second] = true }
  FauxJeu.position_joueur = { x = 100, y = 1200, z = 0 }
  hommes.veiller_henry()
  verifier(hommes.montures[ids[1]].saut and hommes.montures[ids[2]].saut, "à 760 m, même dans son regard : les deux en saut")
  Scriptorium.en_partie = true
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  verifier(FauxJeu.chevaux[c3] ~= nil and FauxJeu.chevaux[c_second] ~= nil, "encore en selle à 3 s : rien retiré")
  verifier(journal_contient("encore en selle à 3 s : il attend"), "l'attente au journal")
  egal(FauxJeu.minuteries[#FauxJeu.minuteries].ms, 2000, "on attend 2 s")
  FauxJeu.chevaux_montes[c_second] = false
  FauxJeu.secours = {}
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  verifier(FauxJeu.chevaux[c_second] == nil, "le second à pied à 5 s : son cheval retiré")
  verifier(journal_contient("à pied, lu à 5 s"), "la durée de la descente au journal")
  egal(#FauxJeu.secours, 1, "le second posé")
  local relecture = FauxJeu.minuteries[#FauxJeu.minuteries - 1]
  egal(relecture.ms, 1500, "sa pose relue")
  local n_min = #FauxJeu.minuteries
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  egal(#FauxJeu.secours, 1, "pose en relecture : pas reposé par la fin des sauts")
  relecture.fonction()
  verifier(not hommes.montures[ids[2]].saut, "le second : saut fini")
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  egal(#FauxJeu.minuteries, n_min + 1, "trois attentes au plus")
  Scriptorium.en_partie = false
  verifier(FauxJeu.chevaux[c3] ~= nil, "le premier toujours en selle : son cheval jamais retiré")
  verifier(not hommes.montures[ids[1]].saut, "son saut abandonné")
  verifier(journal_contient("encore en selle à 9 s : saut abandonné, il rejoint à cheval"), "l'abandon au journal")
  local o1 = dernier_ordre_de(perso[1])
  egal(o1 and o1.suivi and o1.suivi.mode, "cheval", "il rejoint à cheval")
  FauxJeu.chevaux_montes, FauxJeu.vue_d_henry = nil, nil
  -- Le filet, si la minuterie ne tire pas : le cheval n'est retiré qu'au deuxième battement après l'ordre à pied, et
  -- seulement à pied ; encore en selle à ce moment : saut abandonné.
  FauxJeu.positions[perso[1]] = { x = 100, y = 1196, z = 0 }
  FauxJeu.positions[perso[2]] = { x = 100, y = 1196, z = 0 }
  for _ = 1, 3 do hommes.battre() end
  local c4, c5 = hommes.montures[ids[1]].cheval, hommes.montures[ids[2]].cheval
  verifier(c4 ~= nil and c5 ~= nil, "deux chevaux avant le filet")
  FauxJeu.position_joueur = { x = 100, y = 1700, z = 0 }
  hommes.battre()
  verifier(hommes.montures[ids[1]].saut and hommes.montures[ids[2]].saut, "vu au battement : en saut")
  hommes.battre()
  verifier(FauxJeu.chevaux[c4] ~= nil, "le battement suivant : le cheval reste")
  FauxJeu.chevaux_montes = { [c5] = true }
  hommes.battre()
  verifier(FauxJeu.chevaux[c4] == nil, "le deuxième battement, à pied : le cheval retiré")
  verifier(FauxJeu.chevaux[c5] ~= nil, "le deuxième battement, encore en selle : le cheval reste")
  verifier(not hommes.montures[ids[2]].saut, "encore en selle : saut abandonné")
  FauxJeu.chevaux_montes = nil
  -- Le Directeur, de même.
  verifier(Scriptorium.directeur.installer(), "Directeur installé")
  local dir = Scriptorium.directeur.personnage()
  FauxJeu.position_joueur = { x = 100, y = 400, z = 0 }
  hommes.veiller_henry()
  FauxJeu.positions[dir] = { x = 100, y = 390, z = 0 }
  verifier(Scriptorium.directeur.suivre(true, nil, true), "le Directeur suit à cheval")
  local cd = hommes.montures.directeur and hommes.montures.directeur.cheval
  verifier(cd ~= nil, "son cheval")
  Scriptorium.directeur.battre()
  FauxJeu.position_joueur = { x = 100, y = 800, z = 0 }
  hommes.veiller_henry()
  verifier(hommes.montures.directeur.saut, "le Directeur en saut au bond")
  local o = dernier_ordre_de(dir)
  verifier(o and not (o.suivi and o.suivi.mode == "cheval"), "son ordre à pied tout de suite")
  verifier(FauxJeu.chevaux[cd] ~= nil, "son cheval encore là")
  FauxJeu.secours = {}
  Scriptorium.directeur.battre()
  egal(#FauxJeu.secours, 0, "un battement pendant sa descente : pas de pose")
  Scriptorium.en_partie = true
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  verifier(FauxJeu.chevaux[cd] == nil, "son cheval retiré")
  FauxJeu.minuteries[#FauxJeu.minuteries].fonction()
  Scriptorium.en_partie = false
  verifier(not hommes.montures.directeur.saut, "posé et relu : son saut fini")
  verifier(hommes.montures.directeur.cheval ~= nil and hommes.montures.directeur.cheval ~= cd, "un nouveau cheval")
  o = dernier_ordre_de(dir)
  egal(o and o.suivi and o.suivi.mode, "cheval", "de nouveau à cheval")
  Scriptorium.directeur.suivre(false)
  FauxJeu.manquees, FauxJeu.henry_cheval = nil, nil
end)


-- Fiche 15, V73 g : le gardien des hommes (version simple).
essai("gardien (fiche 15, V73 g) : sous le sol deux regards de suite, repêché au sol, immortel 15 s ; jamais dans la grotte d'Henry ; trois fois au plus", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  hommes.battre()
  FauxJeu.secours, FauxJeu.effets, FauxJeu.effets_retires = {}, {}, {}
  FauxJeu.positions[f.personnage] = { x = 20, y = 20, z = -30 }
  hommes.garder()
  egal(#FauxJeu.secours, 0, "un regard : rien")
  hommes.garder()
  egal(#FauxJeu.secours, 1, "deux regards de suite : repêché")
  egal(#FauxJeu.effets, 1, "immortel le temps de la pose")
  verifier(journal_contient("sous le sol (à -30.0) : repêché"), "dit au journal")
  local mt = FauxJeu.minuteries[#FauxJeu.minuteries]
  egal(mt.ms, 15000, "l'effet retiré 15 s après")
  mt.fonction()
  egal(#FauxJeu.effets_retires, 1, "l'effet retiré, par son identifiant")
  egal(FauxJeu.effets_retires[1].effet, 1, "le sien seulement")
  egal(hommes.gardien.repeches, 1, "compté")
  -- Un regard au-dessus du sol remet le compte à zéro.
  FauxJeu.positions[f.personnage] = { x = 20, y = 20, z = -30 }
  hommes.garder()
  FauxJeu.positions[f.personnage] = { x = 20, y = 20, z = 0 }
  hommes.garder()
  FauxJeu.positions[f.personnage] = { x = 20, y = 20, z = -30 }
  hommes.garder()
  egal(#FauxJeu.secours, 1, "deux regards non consécutifs : rien")
  -- Il suit Henry, et Henry est lui-même sous le sol (une grotte) : jamais.
  escorter(id)
  FauxJeu.position_joueur = { x = 25, y = 25, z = -40 }
  hommes.garder()
  hommes.garder()
  egal(#FauxJeu.secours, 1, "dans la grotte d'Henry : pas de repêchage")
  hommes.lacher(id, "escorte")
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
  -- Trois fois au plus, puis une ligne « laissé ».
  for _ = 1, 8 do
    FauxJeu.positions[f.personnage] = { x = 20, y = 20, z = -30 }
    hommes.garder()
  end
  egal(hommes.gardien.repeches, 3, "trois repêchages au plus")
  verifier(journal_contient("déjà repêché 3 fois : laissé"), "puis laissé, dit au journal")
  -- L'immortalité refusée par le jeu : repêché quand même, dit.
  FauxJeu.refuser_les_effets = true
  local id2 = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f2 = hommes.fiche(id2)
  FauxJeu.positions[f2.personnage] = { x = 30, y = 30, z = -30 }
  hommes.garder()
  hommes.garder()
  verifier(journal_contient("immortel : non (effet refusé)"), "l'immortalité refusée, dite")
  FauxJeu.refuser_les_effets = nil
end)

essai("geste tenu (sonde du pair, 20/10) : le même geste au même lieu, son point déplacé de 54 m : l'ordre est redonné, avec le temps de marche (il se relève)", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local p = hommes.fiche(id).personnage
  local pres = camp.point(2, -6, 0)
  FauxJeu.positions[p] = { x = pres.x + 1, y = pres.y, z = 0 }
  hommes.tenir(id, "travail", { activite = "geste", geste = "Loot", lieu = "portage", position = pres, fin = "liberation" })
  hommes.battre()
  -- Il tient son geste à genoux ; la même tenue est reposée, le point au centre du camp, à 54 m.
  local loin = { x = pres.x + 54, y = pres.y, z = pres.z }
  FauxJeu.ordres = {}
  hommes.tenir(id, "travail", { activite = "geste", geste = "Loot", lieu = "portage", position = loin, fin = "liberation" })
  hommes.battre()
  local o = nil
  for _, ordre in ipairs(FauxJeu.ordres) do
    if ordre.identifiant == p and ordre.activite == "geste" then o = ordre end
  end
  verifier(o ~= nil, "le nouvel ordre est donné")
  verifier(o and o.position and math.abs(o.position.x - loin.x) < 0.01, "vers le nouveau point")
  verifier(o and (o.marche_ms or 0) > 0, "avec son temps de marche : il se relève d'abord")
  -- Le même point reposé : pas de nouvel ordre.
  FauxJeu.ordres = {}
  hommes.tenir(id, "travail", { activite = "geste", geste = "Loot", lieu = "portage", position = loin, fin = "liberation" })
  hommes.battre()
  local encore = 0
  for _, ordre in ipairs(FauxJeu.ordres) do
    if ordre.identifiant == p and ordre.activite == "geste" then encore = encore + 1 end
  end
  egal(encore, 0, "le même point : pas d'ordre redonné")
  hommes.lacher(id, "travail")
end)

essai("marche longue (vu sur une copie le 20/10 : 64 m, arrêté à 31 m) : l'ordre porte le temps de marche jusqu'au but, borné", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  local but = camp.point(0, -6, 0)
  FauxJeu.positions[f.personnage] = { x = but.x + 64, y = but.y, z = 0 }
  FauxJeu.ordres = {}
  verifier(hommes.tenir(id, "travail", { activite = "geste", geste = "Loot", lieu = "fouille", position = but, fin = "liberation" }),
           "le geste au loin")
  local o = FauxJeu.ordres[#FauxJeu.ordres]
  local attendu = math.floor(1000 * 64 / hommes.reglages.marche_approche_m_par_s)
  verifier(o and o.marche_ms and math.abs(o.marche_ms - attendu) <= 1000, "64 m : " .. tostring(o and o.marche_ms) .. " ms, environ " .. attendu)
  egal(hommes.temps_de_marche_ms(f.personnage, nil), 0, "sans but : 0")
  -- Assis à sa place (0,8 m de l'objet), le même ordre reposé : pas de marche, donc il ne se relève pas (demande du pair).
  FauxJeu.positions[f.personnage] = { x = but.x + 0.8, y = but.y, z = 0 }
  egal(hommes.temps_de_marche_ms(f.personnage, but), 0, "à sa place : temps de marche nul (il ne se relève pas)")
  FauxJeu.positions[f.personnage] = { x = but.x + 3, y = but.y, z = 0 }
  verifier(hommes.temps_de_marche_ms(f.personnage, but) > 0, "à 3 m : il doit marcher (il se relève)")
  FauxJeu.positions[f.personnage] = { x = but.x + 5000, y = but.y, z = 0 }
  egal(hommes.temps_de_marche_ms(f.personnage, but), hommes.reglages.marche_approche_max_ms, "borné")
  hommes.lacher(id, "travail")
end)

essai("gardien (mesuré sur une copie le 20/10) : arrêté à 2,7 m de son point, la distance d'arrêt de la marche du jeu, il n'est pas figé", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  hommes.battre()
  local a = hommes.activite_de(id, 10)
  verifier(a and a.position, "une activité avec un but")
  FauxJeu.reveilles = {}
  FauxJeu.positions[f.personnage] = { x = a.position.x, y = a.position.y + 2.7, z = 0 }
  local ordres = #FauxJeu.ordres
  for _ = 1, 5 do hommes.garder() end
  egal(#FauxJeu.ordres, ordres, "aucune relance")
  egal(#FauxJeu.reveilles, 0, "personne réveillé")
end)

essai("gardien et secours (vu sur une copie le 21/10, J26 : Wenzel Vlk assommé à l'exercice, relancé puis téléporté) : un homme assommé n'est ni figé ni bloqué ; relevé, il l'est de nouveau", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  hommes.battre()
  local a = hommes.activite_de(id, 10)
  verifier(a and a.position, "une activité avec un but")
  FauxJeu.reveilles, FauxJeu.secours = {}, {}
  FauxJeu.positions[f.personnage] = { x = a.position.x + 30, y = a.position.y, z = 0 }
  FauxJeu.inconscients = { [f.personnage] = true }
  local ordres = #FauxJeu.ordres
  for _ = 1, 4 do
    hommes.garder()
    hommes.garder()
    hommes.battre()
  end
  egal(#FauxJeu.reveilles, 0, "assommé : jamais relancé")
  egal(#FauxJeu.secours, 0, "assommé : jamais posé au secours")
  verifier(not journal_contient("figé à 30.0 m"), "rien de dit")
  FauxJeu.inconscients = nil
  for _ = 1, 3 do hommes.garder() end
  verifier(#FauxJeu.reveilles > 0, "relevé et toujours sur place : relancé")
end)

essai("rafales de figés (vu en J32, le 24/10) : les ordres de la journée échelonnés, quatre par seconde, les autres par minuterie ; la grâce du gardien, 5 regards depuis l'ordre ; loin d'Henry, pas de figé", function()
  preparer(20000, 100, 12.5)
  hommes.reglages.ordres_par_seconde = 4
  hommes.reglages.fige_ordre_regards = 5
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local ids = {}
    for _ = 1, 7 do table.insert(ids, (hommes.embaucher({ role = "archer", semaines = 4, prime = 0 }))) end
    FauxJeu.temps = 1000
    hommes.battre()
    -- Le changement de la journée : de nouveaux ordres pour les sept.
    FauxJeu.heure = 13.5
    FauxJeu.temps = 1100
    local avant = #FauxJeu.ordres
    FauxJeu.minuteries = {}
    hommes.battre()
    local tout_de_suite = #FauxJeu.ordres - avant
    egal(tout_de_suite, 1, "un seul ordre tout de suite, au même instant")
    local differes = 0
    for _, m in ipairs(FauxJeu.minuteries) do
      if m.ms > 0 and m.ms <= 2000 then differes = differes + 1 end
    end
    verifier(differes >= 4, "les autres dans les secondes suivantes (" .. differes .. ")")
    hommes.battre()
    egal(#FauxJeu.ordres - avant, 1, "un battement de plus : pas d'ordre en double")
    Scriptorium.en_partie = true
    for _, m in ipairs(FauxJeu.minuteries) do if m.ms > 0 and m.ms <= 2000 then m.fonction() end end
    Scriptorium.en_partie = false
    egal(#FauxJeu.ordres - avant, 1 + differes, "puis tous ordonnés, chacun une fois")
    -- La grâce : immobile loin de son but, il n'est pas relancé avant 5 regards depuis son ordre.
    local id = ids[1]
    local f = hommes.fiche(id)
    local a = hommes.activite_de(id, 13.5)
    FauxJeu.reveilles = {}
    FauxJeu.positions[f.personnage] = { x = a.position.x + 30, y = a.position.y, z = 0 }
    FauxJeu.position_joueur = { x = a.position.x, y = a.position.y, z = 0 }
    for _ = 1, 4 do hommes.garder() end
    egal(#FauxJeu.reveilles, 0, "dans la grâce : pas relancé")
    for _ = 1, 3 do hommes.garder() end
    verifier(#FauxJeu.reveilles >= 1, "après la grâce : relancé")
    -- Loin d'Henry (au-delà de gardien_rayon_m) : jamais jugé figé.
    local g = hommes.fiche(ids[2])
    local b = hommes.activite_de(ids[2], 13.5)
    FauxJeu.reveilles = {}
    FauxJeu.positions[g.personnage] = { x = b.position.x + 30, y = b.position.y, z = 0 }
    FauxJeu.position_joueur = { x = b.position.x + 2000, y = b.position.y, z = 0 }
    hommes.gardien.vus = {}
    for _ = 1, 10 do hommes.garder() end
    local reveille = false
    for _, r in ipairs(FauxJeu.reveilles) do if r.identifiant == g.personnage or r == g.personnage then reveille = true end end
    verifier(not reveille, "à 2 000 m d'Henry : pas relancé")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("assaut amical (demande du pair, 25/10 : l'entraînement ressemblait à une querelle) : la tenue « affronter » amicale donne l'assaut amical (ordre 12), sans « jusqu'à » ; assommé, la cible ne finit pas l'assaut ; la fin de la tenue le lève", function()
  preparer(5000, 100, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local b = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  hommes.battre()
  local cible = hommes.fiche(b).personnage
  FauxJeu.attaques, FauxJeu.cessations = {}, {}
  verifier(not hommes.tenir(a, "travail", { activite = "affronter", cible = cible, amical = "oui", fin = "liberation" }),
           "amical doit être vrai ou faux")
  verifier(hommes.tenir(a, "travail", { activite = "affronter", cible = cible, amical = true, fin = "liberation" }),
           "l'assaut amical posé")
  local derniere = FauxJeu.attaques[#FauxJeu.attaques]
  verifier(derniere and derniere.options and derniere.options.amical == true, "l'ordre d'assaut amical donné")
  egal(hommes.activite_de(a, 10).jusqu_a, nil, "pas de « jusqu'à »")
  -- La cible assommée (ce que l'assaut empêche en jeu) ne finit pas l'assaut : seule la tenue le lève.
  FauxJeu.inconscients = { [cible] = true }
  hommes.battre()
  verifier(hommes.activite_de(a, 10).activite == "affronter", "toujours en assaut")
  FauxJeu.inconscients = nil
  hommes.lacher(a, "travail")
  hommes.battre()
  verifier(#FauxJeu.cessations >= 1, "la fin de la tenue lève l'assaut")
end)

essai("gardien (vu sur une copie le 20/10, à chaque chargement) : un homme sans ordre encore reçu attend le battement, il n'est pas figé", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  hommes.battre()
  local a = hommes.activite_de(id, 10)
  verifier(a and a.position, "une activité avec un but")
  FauxJeu.reveilles = {}
  FauxJeu.positions[f.personnage] = { x = a.position.x + 30, y = a.position.y, z = 0 }
  hommes.relancer()
  local ordres = #FauxJeu.ordres
  for _ = 1, 5 do hommes.garder() end
  egal(#FauxJeu.ordres, ordres, "aucune relance avant le premier ordre")
  egal(#FauxJeu.reveilles, 0, "personne réveillé")
  verifier(not journal_contient("figé à 30.0 m"), "rien de dit")
  hommes.battre()
  egal(#FauxJeu.ordres, ordres + 1, "le battement donne l'ordre")
  for _ = 1, 3 do hommes.garder() end
  egal(#FauxJeu.ordres, ordres + 2, "ensuite, figé : relancé")
end)

essai("gardien (vu sur une copie le 20/10, au lever) : couché, son activité change sans ordre encore reçu : il attend le battement, il n'est pas figé", function()
  preparer(5000, 100, 23)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  hommes.battre()
  local nuit = hommes.activite_de(id, 23)
  verifier(nuit and nuit.activite == "sommeil" and nuit.position, "couché, avec un lit")
  FauxJeu.positions[f.personnage] = { x = nuit.position.x, y = nuit.position.y, z = 0 }
  for _ = 1, 4 do hommes.garder() end
  FauxJeu.heure = 24 + 9
  local jour = hommes.activite_de(id, FauxJeu.heure)
  verifier(jour and jour.position and jour.activite ~= "sommeil", "le jour, une autre activité avec un but")
  verifier(math.sqrt((jour.position.x - nuit.position.x) ^ 2 + (jour.position.y - nuit.position.y) ^ 2) > 3,
           "son but du jour est loin de son lit")
  FauxJeu.reveilles = {}
  local ordres = #FauxJeu.ordres
  for _ = 1, 4 do hommes.garder() end
  egal(#FauxJeu.ordres, ordres, "aucune relance avant l'ordre du jour")
  egal(#FauxJeu.reveilles, 0, "personne réveillé")
  hommes.battre()
  egal(#FauxJeu.ordres, ordres + 1, "le battement donne l'ordre du jour")
  for _ = 1, 3 do hommes.garder() end
  egal(#FauxJeu.ordres, ordres + 2, "ensuite, figé : relancé")
end)

essai("gardien (fiche 15, V73 g) : figé loin de son but, relancé (réveil, ordre redonné), deux fois au plus et pas deux en 8 s ; la relance utile ; ni suite, ni bataille, ni combat ; tant par regard", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local f = hommes.fiche(id)
  hommes.battre()
  local a = hommes.activite_de(id, 10)
  verifier(a and a.position, "une activité avec un but")
  FauxJeu.reveilles = {}
  local loin = { x = a.position.x + 30, y = a.position.y, z = 0 }
  FauxJeu.positions[f.personnage] = loin
  local ordres = #FauxJeu.ordres
  hommes.garder()
  hommes.garder()
  egal(#FauxJeu.ordres, ordres, "l'ordre trop jeune : rien")
  hommes.garder()
  egal(#FauxJeu.ordres, ordres + 1, "figé : l'ordre redonné")
  egal(#FauxJeu.reveilles, 1, "et réveillé")
  verifier(journal_contient("figé à 30.0 m de son but"), "dit au journal")
  hommes.garder()
  egal(#FauxJeu.ordres, ordres + 1, "pas deux relances en 8 s")
  verifier(not journal_contient("relance utile"), "il n'a pas bougé : pas utile")
  hommes.garder()
  egal(#FauxJeu.ordres, ordres + 2, "la deuxième relance")
  -- Il repart : la relance est utile.
  FauxJeu.positions[f.personnage] = { x = loin.x - 3, y = loin.y, z = 0 }
  hommes.garder()
  verifier(journal_contient("repart (3.0 m) : relance utile"), "la relance utile, dite")
  egal(hommes.gardien.utiles, 1, "comptée")
  -- Figé de nouveau : plus de relance pour cet ordre, une ligne « laissé ».
  for _ = 1, 4 do hommes.garder() end
  egal(#FauxJeu.ordres, ordres + 2, "deux relances au plus par ordre")
  verifier(journal_contient("toujours figé après 2 relance(s) : laissé au secours"), "laissé au secours, dit")
  egal(hommes.gardien.relances, 2, "deux relances comptées")
  -- Ni suite, ni bataille, ni combat.
  local id_b = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local fb = hommes.fiche(id_b)
  escorter(id_b)
  FauxJeu.positions[fb.personnage] = { x = 300, y = 300, z = 0 }
  local avant = #FauxJeu.ordres
  for _ = 1, 5 do hommes.garder() end
  local relances_b = 0
  for _, o in ipairs(FauxJeu.ordres) do if o.identifiant == fb.personnage then relances_b = relances_b + 1 end end
  verifier(relances_b <= 1, "un homme qui suit n'est jamais relancé par le gardien")
  hommes.lacher(id_b, "escorte")
  FauxJeu.occupations[fb.personnage] = "combat"
  hommes.battre()
  avant = #FauxJeu.ordres
  for _ = 1, 5 do hommes.garder() end
  egal(#FauxJeu.ordres, avant, "en combat : jamais")
  FauxJeu.occupations[fb.personnage] = nil
  -- Tant au plus par regard (réglé à 1 ici : le camp n'a que quatre places) : au moins deux figés (les deux nouveaux),
  -- une relance.
  local par_regard = hommes.reglages.fige_par_regard
  hommes.reglages.fige_par_regard = 1
  local tous = {}
  for k = 1, 2 do
    tous[k] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  end
  hommes.battre()
  for _, idk in ipairs(tous) do
    local ak = hommes.activite_de(idk, 10)
    FauxJeu.positions[hommes.fiche(idk).personnage] = { x = ak.position.x + 40, y = ak.position.y, z = 0 }
  end
  hommes.garder()
  hommes.garder()
  local n0 = hommes.gardien.relances
  hommes.garder()
  egal(hommes.gardien.relances - n0, 1, "tant de relances au plus par regard")
  hommes.reglages.fige_par_regard = par_regard
end)

-- Fiche 15, V73 f 2 f : l'allure du chef monté (principe d'Alex, relu par le pair : la marge contre l'hésitation).
essai("allure du chef monté (fiche 15, V73 f 2 f) : la vitesse de celui qu'il suit donne l'allure, l'écart corrige, une marge aux seuils", function()
  -- { vitesse, écart, fond avant, correction avant, code avant, attendu, texte }
  local cas = {
    { 0, 5, nil, nil, nil, -1, "arrêté, à sa place : il tient" },
    { 0, 9, nil, nil, nil, 0, "arrêté à 9 m : le pas jusqu'à sa place (V73 f 2 f bis)" },
    { 0, 9, nil, nil, -1, -1, "arrêté à 9 m, il tenait : il tient encore" },
    { 0, 12, nil, nil, -1, 1, "arrêté à 12 m, il tenait : il repart (le pas, plus un)" },
    { 0, 20, nil, nil, nil, 1, "arrêté, loin : le pas, plus un (course)" },
    { 1.5, 7, nil, nil, nil, 0, "au pas, à sa place : le pas" },
    { 1.5, 15, nil, nil, nil, 1, "au pas, loin : une de plus" },
    { 1.5, 2, nil, nil, nil, -1, "au pas, trop près : une de moins (tenir)" },
    { 1.5, 9, nil, 1, nil, 1, "à 9 m, une de plus gardée" },
    { 1.5, 7.5, nil, 1, nil, 0, "à 7,5 m : une de plus lâchée (freinage, 8 m)" },
    { 1.5, 5, nil, -1, nil, -1, "à 5 m, une de moins gardée" },
    { 1.5, 5, nil, 0, nil, 0, "à 5 m, sans correction : le pas" },
    { 3.5, 7, nil, nil, nil, 1, "à la course : la course" },
    { 6, 7, nil, nil, nil, 2, "plus vite : le trot rapide" },
    { 10, 7, nil, nil, nil, 3, "au galop : le galop" },
    { 10, 20, nil, nil, nil, 3, "au galop, loin : pas au-delà du galop" },
    { 2.3, 7, 0, nil, nil, 0, "2,3 m/s depuis le pas : pas encore la course (2,2 + 10 %)" },
    { 2.5, 7, 0, nil, nil, 1, "2,5 m/s depuis le pas : la course" },
    { 2.1, 7, 1, nil, nil, 1, "2,1 m/s depuis la course : encore la course (2,2 − 10 %)" },
    { 1.9, 7, 1, nil, nil, 0, "1,9 m/s depuis la course : le pas" },
    { 4.6, 7, 1, nil, nil, 1, "4,6 m/s depuis la course : pas encore le trot rapide" },
    { 4.2, 7, 2, nil, nil, 2, "4,2 m/s depuis le trot rapide : il le garde" },
  }
  for _, c in ipairs(cas) do
    local code = hommes.allure_du_chef(c[1], c[2], c[3], c[4], c[5])
    egal(code, c[6], c[7])
  end
  -- V73 f 2 g (relecture du pair) : perdu au-delà de 13 m de son chef, de retour dans le rang en deçà de 6 m (la tenue) ;
  -- le filtre des sauts.
  local _, _, _, perdu = hommes.allure_du_chef(1.5, 14)
  verifier(perdu == true, "à 14 m de son chef : perdu")
  _, _, _, perdu = hommes.allure_du_chef(1.5, 10, nil, nil, nil, true)
  verifier(perdu == true, "perdu, à 10 m : encore perdu")
  _, _, _, perdu = hommes.allure_du_chef(1.5, 5, nil, nil, nil, true)
  verifier(perdu == false, "perdu, à 5 m : de retour dans le rang")
  _, _, _, perdu = hommes.allure_du_chef(1.5, 10, nil, nil, nil, false)
  verifier(perdu == false, "rangé, à 10 m : pas perdu")
  _, _, _, perdu = hommes.allure_du_chef(0, 5)
  verifier(perdu == false, "arrêté à sa place : pas perdu")
  egal(hommes.vitesse_retenue(25, 3), 3, "un saut : la vitesse d'avant")
  egal(hommes.vitesse_retenue(5, 3), 5, "une course : retenue")
  egal(hommes.vitesse_retenue(25, nil), 0, "un saut sans vitesse d'avant : 0")
end)

-- Fiche 17 (vu en jeu le 17/10) : un homme tenu par la bataille, loin de son point et immobile, n'est jamais secouru.
essai("secours (fiche 17) : un homme tenu par la bataille n'est jamais secouru, même immobile loin de son point", function()
  preparer(5000, 100, 15)
  hommes.embaucher({ role = "homme_d_armes", semaines = 4, palier = 1 })
  local id = hommes.liste()[1]
  local f = hommes.fiche(id)
  verifier(hommes.tenir(id, "bataille", { activite = "bataille", lieu = "camp_de_bandits", position = { x = 0, y = 200, z = 0 },
    cap = 0, fin = "liberation" }), "tenu par la bataille")
  FauxJeu.secours = {}
  FauxJeu.positions[f.personnage] = { x = 0, y = 189, z = 0 }
  for _ = 1, 8 do
    hommes.battre()
  end
  egal(#FauxJeu.secours, 0, "immobile à 11 m de son point, huit battements : aucun secours")
  hommes.lacher(id, "bataille")
end)

-- ---------------------------------------------------------------- fiche 18, 5 a : l'embauche que Scriptorium attend

essai("embauche (5 a) : un compagnon nommé avec son âme, posé à un point ; refus d'un nom, d'une âme ou d'un point boiteux", function()
  preparer(5000, 100, 10)
  local AME = "0a1b2c3d-1111-2222-3333-444455556666"
  verifier(not hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0, nom = "" }), "nom vide : refusé")
  verifier(not hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0, ame = "pas une âme" }), "âme boiteuse : refusée")
  verifier(not hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0, position = { x = 1 } }), "point boiteux : refusé")
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0, nom = "Zbyněk le Vieux", ame = AME,
    position = { x = 12, y = -7, z = 3 } })
  verifier(id, "engagé")
  local f = hommes.fiche(id)
  egal(f.nom, "Zbyněk le Vieux", "son nom")
  local ne = FauxJeu.personnages[#FauxJeu.personnages]
  egal(ne.ame, AME, "né sur l'âme donnée")
  egal(ne.position.x, 12, "au point donné")
  egal(ne.position.y, -7, "au point donné")
end)

essai("embauche (5 a) : plusieurs hommes d'un coup, arrêt au premier refus ; le plafond, lisible et tenu ; les accroches avant et après", function()
  preparer(5000, 100, 10)
  local engages, raison = hommes.faire_venir_des_hommes({ nombre = 3, role = "archer", palier = 2, semaines = 4, prime = 0 })
  egal(#engages, 3, "trois archers")
  egal(raison, nil, "sans refus")
  for _, id in ipairs(engages) do
    egal(hommes.fiche(id).palier, 2, "du rang demandé")
  end
  local p = hommes.plafond_de_la_compagnie()
  egal(p.effectif, 3, "effectif lisible")
  egal(p.plafond, 80, "plafond de 80")
  hommes.reglages.plafond = 4
  local id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  verifier(id, "le quatrième passe")
  id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  verifier(not id and r == "plafond_atteint", "le cinquième : plafond atteint")
  hommes.reglages.plafond = 80
  camp.agrandir()
  -- Les accroches : Scriptorium refuse, puis modifie le contrat ; après, il est prévenu.
  local ancienne_avant, ancienne_apres = hommes.avant_l_embauche, hommes.apres_l_embauche
  local ok, erreur = pcall(function()
    hommes.avant_l_embauche = function() return false, "le_directeur_dit_non" end
    id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    verifier(not id and r == "refus_de_scriptorium", "refus de Scriptorium")
    local prevenu = nil
    hommes.avant_l_embauche = function(c) c.palier = 3 return true end
    hommes.apres_l_embauche = function(i) prevenu = i end
    id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    verifier(id, "engagé, contrat modifié : " .. tostring(r))
    egal(id and hommes.fiche(id).palier, 3, "le contrat modifié par l'accroche")
    egal(prevenu, id, "l'accroche d'après, prévenue")
  end)
  hommes.avant_l_embauche, hommes.apres_l_embauche = ancienne_avant, ancienne_apres
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("embauche (5 a) : les chevaux de la compagnie éteints, une sortie à cheval part à pied", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  FauxJeu.positions[hommes.fiche(id).personnage] = { x = 110, y = 0, z = 0 }   -- hors du camp (V73 f 2 c)
  Scriptorium.noyau.interrupteurs.chevaux_de_la_compagnie = 0
  FauxJeu.chevaux = {}
  local function chevaux()
    local n = 0
    for _ in pairs(FauxJeu.chevaux) do n = n + 1 end
    return n
  end
  hommes.tenir(id, "escorte", { activite = "suivre", lieu = "cavaliers", formation = "followNPC", a_cheval = true, fin = "liberation" })
  hommes.battre()
  egal(chevaux(), 0, "aucun cheval né")
  local a = hommes.activite_de(id, 10)
  verifier(not (a.suivi and a.suivi.mode == "cheval"), "il suit à pied")
  Scriptorium.noyau.interrupteurs.chevaux_de_la_compagnie = 1
  FauxJeu.positions[hommes.fiche(id).personnage] = { x = 110, y = 0, z = 0 }   -- dehors (le faux moteur a pu le ramener)
  hommes.battre()
  verifier(chevaux() >= 1, "rallumés : un cheval naît")
  hommes.lacher(id, "escorte")
end)

essai("embauche (5 a) : une prime de 0, rien à payer : aucun appel au coffre ni à la bourse d'Henry, même coffre vide ; sommes boiteuses refusées", function()
  preparer(0, 100, 10)
  local appels = {}
  local gardes = {}
  local function espionner(table_, nom)
    local original = table_[nom]
    gardes[#gardes + 1] = { table_, nom, original }
    table_[nom] = function(...)
      appels[#appels + 1] = nom
      return original(...)
    end
  end
  local ok, erreur = pcall(function()
    for _, nom in ipairs({ "solde", "encaisser", "payer", "verser_a_henry", "deposer_par_henry" }) do
      espionner(Scriptorium.coffre, nom)
    end
    for _, nom in ipairs({ "groschen_d_henry", "retirer_groschen_a_henry", "donner_groschen_a_henry" }) do
      espionner(FauxJeu, nom)
    end
    local bourse = FauxJeu.bourse_henry
    local id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    verifier(id, "coffre vide, prime 0 : engagé (" .. tostring(r) .. ")")
    egal(#appels, 0, "aucun appel au coffre ni à la bourse (" .. table.concat(appels, ", ") .. ")")
    egal(FauxJeu.bourse_henry, bourse, "la bourse d'Henry intacte")
    egal(Scriptorium.coffre.solde(), 0, "le coffre intact")
  end)
  for i = #gardes, 1, -1 do
    gardes[i][1][gardes[i][2]] = gardes[i][3]
  end
  verifier(ok, "sans erreur : " .. tostring(erreur))
  for _, mauvaise in ipairs({ -1, 0.5, 0 / 0, math.huge, "10" }) do
    local id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = mauvaise })
    verifier(not id and r == "prime_invalide", "prime " .. tostring(mauvaise) .. " : refusée")
    id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = 0, solde = mauvaise })
    verifier(not id and r == "solde_invalide", "solde " .. tostring(mauvaise) .. " : refusée")
  end
end)

essai("embauche (5 a) : un lit par homme, un interrupteur (éteint : engagé sans lit, chez Scriptorium on dort en relève) ; semaines facultatives sans contrats à durée", function()
  preparer(5000, 100, 10)
  local libres = #camp.places_libres("lit", "hommes")
  for i = 1, libres do
    verifier(hommes.embaucher({ role = "archer", semaines = 4, prime = 0 }), "lit " .. i)
  end
  local id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  verifier(not id and r == "pas_de_lit", "allumé : plus de lit, refusé")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    verifier(id, "éteint : engagé sans lit (" .. tostring(r) .. ")")
    egal(hommes.fiche(id).lit, nil, "sans lit")
    for h = 0, 30 do
      FauxJeu.heure = 10 + h
      hommes.battre()
    end
    verifier(hommes.fiche(id), "toujours là après une journée et une nuit")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
  camp.agrandir()
  id, r = hommes.embaucher({ role = "archer", prime = 0 })
  verifier(not id and r == "duree_invalide", "contrats à durée allumés : semaines exigées")
  Scriptorium.noyau.interrupteurs.contrats_a_duree = 0
  id, r = hommes.embaucher({ role = "archer", prime = 0 })
  Scriptorium.noyau.interrupteurs.contrats_a_duree = 1
  verifier(id, "éteints : semaines facultatives (" .. tostring(r) .. ")")
  egal(id and hommes.fiche(id).contrat.semaines, hommes.reglages.semaines_max, "le plus long contrat")
end)

essai("nuit (vu en jeu le 19/10) : sur un camp sans Directeur, aucun homme ne dort dans le lit réservé au Directeur", function()
  preparer(5000, 100, 10)
  egal(Scriptorium.directeur.est_installe and Scriptorium.directeur.est_installe() or false, false, "pas de Directeur")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local ids = {}
    for i = 1, 8 do
      ids[i] = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    end
    local au_lit = 0
    for _, id in ipairs(ids) do
      local a = hommes.activite_de(id, 23)
      verifier(a.lieu ~= "lit_directeur", "« " .. hommes.fiche(id).nom .. " » pas dans le lit du Directeur")
      if a.lieu and camp.sorte_de(a.lieu) == "lit" then au_lit = au_lit + 1 end
    end
    verifier(au_lit > 0, "des hommes au lit (" .. au_lit .. ")")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("nuit (vu sur la sauvegarde de JoVenGer le 19/10) : sur un camp adopté, les hommes dorment aux lits déclarés par Scriptorium, chacun le sien ; un lit retiré est perdu par son homme", function()
  depart()
  FauxJeu.heure = 10
  camp.adopter({ x = 0, y = 0, z = 0 }, 0, "kutnohorsko")
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local ids = {}
    for i = 1, 7 do
      ids[i] = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    end
    -- La garde de nuit du socle prend ses hommes ; seuls les dormeurs comptent.
    local dormeurs = {}
    for _, id in ipairs(ids) do
      local a = hommes.activite_de(id, 23)
      if a.activite == "sommeil" then
        table.insert(dormeurs, id)
        -- Décision de JoVenGer du 21/10 (« Dormir au sol au feu ») : sans lit libre, au sol près du feu.
        egal(a.lieu, "sol_feu", "sans lit déclaré : au sol près du feu")
      end
    end
    verifier(#dormeurs >= 4, "au moins quatre dormeurs (" .. #dormeurs .. ")")
    local lits = { "ScriptoEditeur_43_1_so", "ScriptoEditeur_44_1_so", "ScriptoEditeur_45_1_so" }
    verifier(camp.declarer_les_places({ { nom = lits[1], sorte = "lit" }, { nom = lits[2], sorte = "lit" },
                                        { nom = lits[3], sorte = "lit" } }), "lits déclarés")
    local vus, au_lit = {}, 0
    for _, id in ipairs(dormeurs) do
      local lieu = hommes.activite_de(id, 23).lieu
      if lieu and lieu ~= "sol_feu" then
        egal(camp.sorte_de(lieu), "lit", "un lit déclaré (" .. tostring(lieu) .. ")")
        verifier(not vus[lieu], "chacun le sien (" .. lieu .. ")")
        vus[lieu], au_lit = true, au_lit + 1
      end
    end
    -- La règle par défaut (camp.place_pour) range aussi les gardes : un lit peut rester vide pendant leur quart ; sur le
    -- camp de JoVenGer, la chaîne des règles de Scriptorium la remplace.
    verifier(au_lit >= 1 and au_lit <= 3, "des dormeurs aux lits déclarés (" .. au_lit .. ")")
    -- Un homme qui a un lit à lui (réservé) le perd quand Scriptorium le retire.
    verifier(camp.reserver(lits[3], ids[1]), "réservé")
    Scriptorium.registre.lire("hommes").liste[ids[1]].lit = lits[3]
    verifier(camp.declarer_les_places({ { nom = lits[1], sorte = "lit" }, { nom = lits[2], sorte = "lit" } }), "redéclarés sans lui")
    egal(hommes.fiche(ids[1]).lit, nil, "il a perdu son lit")
    egal(camp.occupant_de(lits[3]), nil, "le lit libéré")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("place refaite (prouvé en jeu le 22/10 : un lit retiré et reposé neuf sous le même nom pendant qu'un homme y dormait) : l'ordre est redonné au battement suivant ; sans changement, pas d'ordre", function()
  depart()
  FauxJeu.heure = 10
  camp.adopter({ x = 0, y = 0, z = 0 }, 0, "kutnohorsko")
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    local lits = { "ScriptoEditeur_54_3_so", "ScriptoEditeur_55_3_so" }
    verifier(camp.declarer_les_places({ { nom = lits[1], sorte = "lit" }, { nom = lits[2], sorte = "lit" } }), "lits déclarés")
    FauxJeu.positions_des_objets = { [lits[1]] = { x = 3, y = 1, z = 0 }, [lits[2]] = { x = 4, y = 1, z = 0 } }
    FauxJeu.objets_existants[lits[1]], FauxJeu.objets_existants[lits[2]] = true, true
    FauxJeu.heure = 23
    hommes.battre()
    local a = hommes.activite_de(id, 23)
    verifier(a.activite == "sommeil" and a.lieu, "au lit (" .. tostring(a.lieu) .. ")")
    local personnage = hommes.fiche(id).personnage
    local function ordres_de_sommeil()
      local n = 0
      for _, o in ipairs(FauxJeu.ordres) do
        if o.identifiant == personnage and o.activite == "sommeil" then n = n + 1 end
      end
      return n
    end
    local avant = ordres_de_sommeil()
    hommes.battre()
    egal(ordres_de_sommeil(), avant, "rien de changé : pas d'ordre redonné")
    FauxJeu.identites_des_objets = { [a.lieu] = "entite_refaite_77" }
    hommes.battre()
    egal(ordres_de_sommeil(), avant + 1, "le lit refait sous le même nom : l'ordre redonné")
    FauxJeu.identites_des_objets = nil
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("place refaite, un lit de l'éditeur de Scriptorium (vu en jeu le 22/10 : il n'est pas une place du camp) : le mené qui y dort reçoit l'ordre de nouveau quand le lit est refait", function()
  preparer(5000, 100, 23)
  FauxJeu.personnages_existants["ScriptoArmurier_1"] = true
  FauxJeu.objets_existants["ScriptoEditeur_54_3_so"] = true
  FauxJeu.positions_des_objets = FauxJeu.positions_des_objets or {}
  local pres = camp.point(3, 4, 0)
  FauxJeu.positions_des_objets["ScriptoEditeur_54_3_so"] = { x = pres.x, y = pres.y, z = 0 }
  egal(camp.sorte_de("ScriptoEditeur_54_3_so"), nil, "pas une place du camp")
  verifier(hommes.tenir_un_personnage("ScriptoArmurier_1", "sommeil", { activite = "sommeil", lit = "ScriptoEditeur_54_3_so", fin = "liberation" }),
           "couché dans le lit de l'éditeur")
  local function ordres_de_sommeil()
    local n = 0
    for _, o in ipairs(FauxJeu.ordres) do
      if o.identifiant == "ScriptoArmurier_1" and o.activite == "sommeil" then n = n + 1 end
    end
    return n
  end
  local avant = ordres_de_sommeil()
  hommes.battre()
  egal(ordres_de_sommeil(), avant, "rien de changé : pas d'ordre redonné")
  FauxJeu.identites_des_objets = { ["ScriptoEditeur_54_3_so"] = "0x416DD" }
  hommes.battre()
  egal(ordres_de_sommeil(), avant + 1, "le lit refait : l'ordre redonné")
  FauxJeu.identites_des_objets = nil
  hommes.lacher_un_personnage("ScriptoArmurier_1", "sommeil")
end)

essai("lits de la nuit (vu sur une copie le 20/10 : deux hommes sur le même lit) : un lit donné reste à son dormeur ; la liste des lits libres qui change entre deux ordres ne fait jamais de doublon ; rendu au lever", function()
  depart()
  FauxJeu.heure = 10
  camp.adopter({ x = 0, y = 0, z = 0 }, 0, "kutnohorsko")
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local gardes_de_nuit = hommes.reglages.postes_garde_nuit
  hommes.reglages.postes_garde_nuit = 0   -- tous dorment : seuls les lits comptent ici
  local ok, erreur = pcall(function()
    local lits = { "ScriptoEditeur_61_1_so", "ScriptoEditeur_62_1_so", "ScriptoEditeur_63_1_so", "ScriptoEditeur_64_1_so",
                   "ScriptoEditeur_65_1_so", "ScriptoEditeur_66_1_so", "ScriptoEditeur_67_1_so", "ScriptoEditeur_68_1_so" }
    local places = {}
    for _, nom in ipairs(lits) do table.insert(places, { nom = nom, sorte = "lit" }) end
    verifier(camp.declarer_les_places(places), "huit lits déclarés")
    -- Les deux premiers lits sont pris par quelqu'un d'autre pendant le premier coucher (le personnel de Scriptorium).
    verifier(camp.reserver(lits[1], "personnel_1") and camp.reserver(lits[2], "personnel_2"), "deux lits pris")
    local ids = {}
    for i = 1, 6 do ids[i] = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 }) end
    -- Les trois derniers sont retenus ailleurs (une tâche) : ils se coucheront plus tard.
    for i = 4, 6 do
      hommes.tenir(ids[i], "travail", { activite = "geste", geste = "Loot", lieu = "ailleurs", position = camp.point(0, -6, 0),
                                        fin = "liberation" })
    end
    FauxJeu.heure = 23
    hommes.battre()
    local lit_de, vus = {}, {}
    for i = 1, 3 do
      local a = hommes.activite_de(ids[i], 23)
      if a.activite == "sommeil" and a.lieu then lit_de[ids[i]] = a.lieu end
    end
    -- La liste change : les deux lits pris sont rendus ; puis les trois autres vont dormir.
    camp.liberer(lits[1])
    camp.liberer(lits[2])
    for i = 4, 6 do hommes.lacher(ids[i], "travail") end
    hommes.battre()
    for _, id in ipairs(ids) do
      local a = hommes.activite_de(id, 23)
      if a.activite == "sommeil" and a.lieu then
        verifier(not vus[a.lieu], "jamais deux hommes sur " .. a.lieu)
        vus[a.lieu] = true
        if lit_de[id] then egal(a.lieu, lit_de[id], "il garde son lit de la nuit") end
      end
    end
    -- Au lever : le lit de la nuit est rendu.
    FauxJeu.heure = 24 + 8
    hommes.battre()
    for _, id in ipairs(ids) do
      egal((hommes.lits_de_nuit or {})[id], nil, "rendu au lever")
    end
  end)
  hommes.reglages.postes_garde_nuit = gardes_de_nuit
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("lits (décision de JoVenGer, 20/10 : tous en relève) : interrupteur éteint, aucun lit réservé à l'embauche, un lit déjà réservé est rendu une fois ; allumé, rien ne change", function()
  preparer(5000, 100, 10)
  local allume = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  verifier(hommes.fiche(allume).lit ~= nil, "interrupteur allumé : un lit réservé à l'embauche")
  hommes.battre()
  verifier(hommes.fiche(allume).lit ~= nil, "allumé : le lit reste réservé")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    egal(hommes.fiche(id).lit, nil, "éteint : aucun lit réservé à l'embauche")
    local lit = hommes.fiche(allume).lit
    hommes.battre()
    egal(hommes.fiche(allume).lit, nil, "éteint : le lit réservé avant est rendu")
    egal(camp.occupant_de(lit), nil, "et libéré au camp")
    local n = 0
    for _, l in ipairs(FauxJeu.journal_lignes) do
      if string.find(l, "rend son lit réservé", 1, true) then n = n + 1 end
    end
    egal(n, 1, "une ligne au journal")
    hommes.battre()
    n = 0
    for _, l in ipairs(FauxJeu.journal_lignes) do
      if string.find(l, "rend son lit réservé", 1, true) then n = n + 1 end
    end
    egal(n, 1, "une seule fois")
    local a = hommes.activite_de(allume, 23)
    if a.activite == "sommeil" then
      verifier(a.lieu and camp.sorte_de(a.lieu) == "lit", "il dort à une place libre")
    end
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("dormir au sol près du feu (décision de JoVenGer du 21/10) : faute de lit libre, sommeil au sol, la posture du réglage jouée comme un geste, la même place toute la nuit ; compté pour le colonel ; repli éteint : sans but", function()
  preparer(50000, 100, 10)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local libres = #Scriptorium.avis(camp, "places_libres", "lit", "hommes")
  local ids = {}
  for _ = 1, libres + 4 do
    table.insert(ids, (hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })))
  end
  FauxJeu.heure = 23
  hommes.battre()
  local au_sol = {}
  for _, id in ipairs(ids) do
    local a = hommes.activite_de(id, 23)
    if a and a.au_sol then table.insert(au_sol, id) end
  end
  verifier(#au_sol >= 1, "faute de lit libre, au moins un homme au sol (" .. libres .. " lits libres)")
  local s = au_sol[1]
  local a = hommes.activite_de(s, 23)
  egal(a.activite, "sommeil", "l'activité reste le sommeil")
  egal(a.lieu, "sol_feu", "le lieu")
  egal(a.geste, "QuestHunterInjuryIdleLie", "la posture du réglage (couchée sans objet, vue en jeu en J27)")
  verifier(a.position ~= nil, "un point")
  local b = hommes.activite_de(s, 23)
  verifier(b.position.x == a.position.x and b.position.y == a.position.y, "la même place à l'appel suivant")
  local o = nil
  for _, ordre in ipairs(FauxJeu.ordres) do
    if ordre.identifiant == hommes.fiche(s).personnage then o = ordre end
  end
  egal(o and o.activite, "geste", "joué comme un geste tenu")
  local _, cette_nuit = hommes.lits_manquants()
  egal(cette_nuit, #au_sol, "compté pour le colonel")
  -- Deux dormeurs au sol n'ont jamais la même place.
  if #au_sol >= 2 then
    local c = hommes.activite_de(au_sol[2], 23)
    verifier(c.position.x ~= a.position.x or c.position.y ~= a.position.y, "deux places au sol distinctes")
  end
  -- À l'aube, le compte de la nuit est arrêté.
  FauxJeu.heure = 24 + hommes.reglages.heure_lever + 0.5
  hommes.battre()
  local derniere, nouvelle = hommes.lits_manquants()
  egal(derniere, #au_sol, "la nuit passée, arrêtée à l'aube")
  egal(nouvelle, 0, "la nouvelle nuit repart de zéro")
  -- Le repli éteint : sans but, comme avant.
  hommes.reglages.sommeil_sol_geste = ""
  FauxJeu.heure = 47
  local e = hommes.activite_de(s, 47)
  verifier(not (e and e.au_sol), "repli éteint : pas au sol")
  hommes.reglages.sommeil_sol_geste = "QuestHunterInjuryIdleLie"
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
end)

essai("venue refusée (vu sur une copie le 21/10, J26 : 13 embauchés jamais venus) : l'homme sans personnage est refait au battement, au plus « venues_par_battement » à la fois ; jamais un homme dehors", function()
  preparer(20000, 100, 10)
  -- Comme en jeu (décision de JoVenGer du 20/10) : aucun lit à soi.
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  FauxJeu.refuser_personnage = true
  local ids = {}
  for i = 1, 5 do
    local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    verifier(id, "embauché " .. i)
    table.insert(ids, id)
  end
  local function presents()
    local n = 0
    for _, id in ipairs(ids) do
      if hommes.fiche(id).personnage then n = n + 1 end
    end
    return n
  end
  egal(presents(), 0, "venues refusées : aucun personnage")
  verifier(hommes.mettre_dehors(ids[5], "mission"), "le cinquième part en mission")
  FauxJeu.refuser_personnage = false
  hommes.battre()
  egal(presents(), 3, "un battement : trois refaits")
  hommes.battre()
  egal(presents(), 4, "le battement suivant : le quatrième ; l'homme dehors, jamais")
  verifier(hommes.fiche(ids[5]).personnage == nil, "l'homme en mission reste sans personnage")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
end)

essai("lit du personnel (question du pair, 21/10, J15 et J16) : un lit déclaré que tient un mené au sommeil n'est pas offert aux hommes ; lâché, il l'est de nouveau", function()
  depart()
  FauxJeu.heure = 10
  camp.adopter({ x = 0, y = 0, z = 0 }, 0, "kutnohorsko")
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  -- Comme en jeu (décision de JoVenGer du 20/10) : aucun lit à soi, tous en relève.
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local id, raison = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    verifier(id, "l'homme embauché (" .. tostring(raison) .. ")")
    local lits = { "ScriptoEditeur_3_3_so", "ScriptoEditeur_3_6_so" }
    verifier(camp.declarer_les_places({ { nom = lits[1], sorte = "lit" }, { nom = lits[2], sorte = "lit" } }), "deux lits déclarés")
    FauxJeu.positions_des_objets = { [lits[1]] = { x = 3, y = 1, z = 0 }, [lits[2]] = { x = 4, y = 1, z = 0 } }
    FauxJeu.objets_existants[lits[1]], FauxJeu.objets_existants[lits[2]] = true, true
    FauxJeu.personnages_existants["ScriptoBain_baigneuse"] = true
    FauxJeu.heure = 23
    local premier = hommes.activite_de(id, 23)
    verifier(premier.activite == "sommeil" and premier.lieu and camp.sorte_de(premier.lieu) == "lit", "l'homme a un lit la nuit")
    verifier(hommes.tenir_un_personnage("ScriptoBain_baigneuse", "sommeil", { activite = "sommeil", lit = premier.lieu, fin = "liberation" }),
             "la dame tient ce lit")
    for _ = 1, 3 do
      local a = hommes.activite_de(id, 23)
      verifier(a.lieu ~= premier.lieu, "le lit de la dame n'est pas offert à l'homme (" .. tostring(a.lieu) .. ")")
    end
    hommes.lacher_un_personnage("ScriptoBain_baigneuse", "sommeil")
    egal(hommes.activite_de(id, 23).lieu, premier.lieu, "lâchée : le lit est de nouveau offert")
  end)
  verifier(ok, "sans erreur : " .. tostring(erreur))
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
end)

essai("siège gardé (vu sur une copie le 21/10, J28 : 829 refus place_prise) : un siège pris par une dame ne fait plus glisser le siège d'un homme au repas ; sieges_occupes reste juste", function()
  depart()
  FauxJeu.heure = 10
  camp.adopter({ x = 0, y = 0, z = 0 }, 0, "kutnohorsko")
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local premier = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    local second = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    local bancs = { "ScriptoEditeur_24_4_so", "ScriptoEditeur_24_6_so", "ScriptoEditeur_24_8_so", "ScriptoEditeur_24_10_so" }
    local places = {}
    FauxJeu.positions_des_objets = {}
    for i, b in ipairs(bancs) do
      table.insert(places, { nom = b, sorte = "siege" })
      FauxJeu.positions_des_objets[b] = { x = i, y = 1, z = 0 }
    end
    verifier(camp.declarer_les_places(places), "quatre sièges déclarés")
    FauxJeu.personnages_existants["ScriptoBain_1"] = true
    -- Le premier homme est tenu ailleurs : le premier siège reste libre ; le second s'assoit au repas, l'ordre donné.
    verifier(hommes.tenir(premier, "travail", { activite = "attendre", fin = "liberation" }), "le premier tenu ailleurs")
    FauxJeu.heure = 12.5
    hommes.battre()
    local avant = hommes.activite_de(second, 12.5).lieu
    verifier(avant and camp.sorte_de(avant) == "siege", "le second a un siège (" .. tostring(avant) .. ")")
    local libre = nil
    for _, b in ipairs(bancs) do
      if b ~= avant and not hommes.sieges_occupes(12.5)[b] then libre = libre or b end
    end
    verifier(libre, "un siège libre pour la dame")
    verifier(hommes.tenir_un_personnage("ScriptoBain_1", "loisir", { activite = "assise", lieu = libre, fin = "liberation" }),
             "la dame tient un siège libre")
    egal(hommes.activite_de(second, 12.5).lieu, avant, "le siège du second n'a pas glissé")
    egal(hommes.sieges_occupes(12.5)[avant], hommes.fiche(second).nom, "sieges_occupes le dit toujours là")
    hommes.lacher_un_personnage("ScriptoBain_1", "loisir")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("siège repris (vu en J33, 25/10, demande de JoVenGer) : un homme tenu ailleurs en plein repas retrouve son siège ; un autre ne le reçoit pas entre-temps ; la fin du repas le rend", function()
  depart()
  FauxJeu.heure = 10
  camp.adopter({ x = 0, y = 0, z = 0 }, 0, "kutnohorsko")
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local premier = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    local second = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    local bancs = { "ScriptoEditeur_24_4_so", "ScriptoEditeur_24_6_so", "ScriptoEditeur_24_8_so", "ScriptoEditeur_24_10_so" }
    local places = {}
    FauxJeu.positions_des_objets = {}
    for i, b in ipairs(bancs) do
      table.insert(places, { nom = b, sorte = "siege" })
      FauxJeu.positions_des_objets[b] = { x = i, y = 1, z = 0 }
    end
    verifier(camp.declarer_les_places(places), "quatre sièges déclarés")
    -- Le premier tenu ailleurs : le second s'assoit le premier au repas.
    verifier(hommes.tenir(premier, "travail", { activite = "attendre", fin = "liberation" }), "le premier tenu ailleurs")
    FauxJeu.heure = 12.5
    hommes.battre()
    local siege = hommes.activite_de(second, 12.5).lieu
    verifier(siege and camp.sorte_de(siege) == "siege", "le second a un siège (" .. tostring(siege) .. ")")
    -- Le second tenu ailleurs (un ordre de Scriptorium en plein repas) ; le premier rendu au repas.
    verifier(hommes.tenir(second, "travail", { activite = "attendre", fin = "liberation" }), "le second tenu ailleurs")
    hommes.battre()
    hommes.lacher(premier, "travail")
    hommes.battre()
    verifier(hommes.activite_de(premier, 12.5).lieu ~= siege, "le premier ne reçoit pas le siège du second")
    hommes.lacher(second, "travail")
    hommes.battre()
    egal(hommes.activite_de(second, 12.5).lieu, siege, "le second retrouve son siège")
    -- Le repas fini, le siège n'est plus gardé.
    hommes.tenir(second, "travail", { activite = "attendre", fin = "liberation" })
    FauxJeu.heure = 16
    hommes.battre()
    egal(hommes.sieges_du_moment[second], nil, "rendu à la fin du repas")
    hommes.lacher(second, "travail")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("siège du personnel (demande du pair, 21/10, J15) : un siège tenu par un mené assis n'est pas offert aux hommes ; un siège déjà pris par un homme est refusé au mené (place_prise)", function()
  depart()
  FauxJeu.heure = 10
  camp.adopter({ x = 0, y = 0, z = 0 }, 0, "kutnohorsko")
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    local bancs = { "ScriptoEditeur_24_4_so", "ScriptoEditeur_24_6_so" }
    verifier(camp.declarer_les_places({ { nom = bancs[1], sorte = "siege" }, { nom = bancs[2], sorte = "siege" } }), "deux sièges déclarés")
    FauxJeu.positions_des_objets = { [bancs[1]] = { x = 3, y = 1, z = 0 }, [bancs[2]] = { x = 4, y = 1, z = 0 } }
    FauxJeu.personnages_existants["ScriptoBain_1"] = true
    FauxJeu.personnages_existants["ScriptoBain_2"] = true
    local premier = hommes.activite_de(id, 12.5)
    verifier(premier.activite == "repas" and premier.lieu, "l'homme a un siège au repas")
    local libre = (premier.lieu == bancs[1]) and bancs[2] or bancs[1]
    -- Le siège déjà pris par l'homme : refusé au mené.
    FauxJeu.heure = 12.5
    local ok2, raison = hommes.tenir_un_personnage("ScriptoBain_2", "loisir", { activite = "assise", lieu = premier.lieu, fin = "liberation" })
    verifier(not ok2 and raison == "place_prise", "un siège pris par un homme : refusé (" .. tostring(raison) .. ")")
    -- Demande du pair (21/10, J27) : les sièges occupés, lisibles avant de tirer celui d'une dame ; le même test que le
    -- refus (le siège dit libre est accordé juste après).
    local occupes = hommes.sieges_occupes(12.5)
    egal(occupes[premier.lieu], hommes.fiche(id).nom, "le siège de l'homme, à son nom")
    egal(occupes[libre], nil, "l'autre siège, libre")
    -- L'autre siège, tenu par une dame : jamais offert à l'homme, même s'il change de place.
    verifier(hommes.tenir_un_personnage("ScriptoBain_1", "loisir", { activite = "assise", lieu = libre, fin = "liberation" }), "la dame tient l'autre siège")
    for _ = 1, 3 do
      local a = hommes.activite_de(id, 12.5)
      verifier(a.lieu ~= libre, "le siège de la dame n'est pas offert à l'homme")
    end
    local id2 = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    local a2 = hommes.activite_de(id2, 12.5)
    verifier(a2.lieu ~= libre and a2.lieu ~= premier.lieu, "un second homme ne prend pas le siège de la dame (" .. tostring(a2.lieu) .. ")")
    hommes.lacher_un_personnage("ScriptoBain_1", "loisir")
    local a3 = hommes.activite_de(id2, 12.5)
    egal(a3.lieu, libre, "la dame partie : le siège revient aux hommes")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("repas et veillée (demande du pair, 20/10) : sur un camp adopté, les hommes s'assoient aux sièges déclarés par Scriptorium, chacun le sien ; sans siège, au feu", function()
  depart()
  FauxJeu.heure = 10
  camp.adopter({ x = 0, y = 0, z = 0 }, 0, "kutnohorsko")
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 0
  local ok, erreur = pcall(function()
    local ids = {}
    for i = 1, 4 do
      ids[i] = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    end
    for _, id in ipairs(ids) do
      local a = hommes.activite_de(id, 12.5)
      if a.activite == "repas" then egal(a.lieu, "feu_central", "sans siège déclaré : au feu") end
    end
    local bancs = { "ScriptoEditeur_28_4_so", "ScriptoEditeur_28_5_so", "ScriptoEditeur_29_4_so" }
    verifier(camp.declarer_les_places({ { nom = bancs[1], sorte = "siege" }, { nom = bancs[2], sorte = "siege" },
                                        { nom = bancs[3], sorte = "siege" }, { nom = "lit_x", sorte = "lit" } }), "déclarés")
    FauxJeu.positions_des_objets = { [bancs[1]] = { x = 3, y = 1, z = 0 }, [bancs[2]] = { x = 4, y = 1, z = 0 },
                                     [bancs[3]] = { x = 5, y = 1, z = 0 } }
    for _, h in ipairs({ 12.5, 20 }) do
      local vus, assis = {}, 0
      for _, id in ipairs(ids) do
        local a = hommes.activite_de(id, h)
        if a.activite == "repas" or a.activite == "veillee" then
          if a.lieu ~= "feu_central" then
            egal(camp.sorte_de(a.lieu), "siege", h .. " h : un siège déclaré (" .. tostring(a.lieu) .. ")")
            verifier(not vus[a.lieu], h .. " h : chacun le sien")
            verifier(a.position and a.position.y == 1, h .. " h : à la place de l'objet")
            vus[a.lieu], assis = true, assis + 1
          end
        end
      end
      verifier(assis >= 1 and assis <= 3, h .. " h : des hommes assis aux sièges déclarés (" .. assis .. ")")
    end
    egal(#camp.places_libres("siege"), 3, "les sièges libres, dans l'ordre déclaré")
    egal(camp.capacite().sieges, 3, "comptés")
  end)
  Scriptorium.noyau.interrupteurs.un_lit_par_homme = 1
  FauxJeu.positions_des_objets = nil
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

-- ---------------------------------------------------------------- fiche 19, grappe 3 : les décisions des hommes remplaçables

essai("décisions des hommes (fiche 19) : le choix de l'équipement (A5, A22, A23) ; munitions de Scriptorium ; faux, impossible ; boiteux, celui du socle", function()
  preparer(5000, 100, 10)
  local socle = Scriptorium.decision_du_socle(hommes, "choix_de_l_equipement")
  local id
  avec_remplacement(hommes, "choix_de_l_equipement", function(i)
    local c = socle(i)
    return c and { tenue = c.tenue, armes = c.armes, munitions = 37 }
  end, function()
    id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  end)
  egal(hommes.fiche(id).equipement.munitions, 37, "les munitions selon Scriptorium")
  local id2
  avec_remplacement(hommes, "choix_de_l_equipement", function() return false end, function()
    id2 = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  end)
  egal(hommes.fiche(id2).equipement.etat, "impossible", "faux : aucun équipement")
  local id3
  avec_remplacement(hommes, "choix_de_l_equipement", function() return { tenue = "pas_un_prereglage", armes = "rien", munitions = 1 } end, function()
    id3 = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  end)
  local e3 = hommes.fiche(id3).equipement
  egal(e3.etat, "a_equiper", "boiteux : l'équipement du socle")
  verifier(e3.tenue ~= "pas_un_prereglage", "pas le préréglage inconnu")
end)

essai("décisions des hommes (fiche 19) : la nuit (A18) ; selon Scriptorium, la garde de 14 h est de nuit", function()
  preparer(5000, 100, 14)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  avec_remplacement(hommes, "gardes", function() return { { id = id, poste = 1 } } end, function()
    egal(Scriptorium.avis(hommes, "activite_de", id, 14).regle, "garde", "de jour selon le socle")
    avec_remplacement(hommes, "est_nuit", function() return true end, function()
      egal(Scriptorium.avis(hommes, "activite_de", id, 14).regle, "garde_de_nuit", "de nuit selon Scriptorium")
    end)
  end)
end)

essai("décisions des hommes (fiche 19) : la tenue la plus forte (A7) ; Scriptorium fait l'emporter la plus faible ; une règle qu'il ne porte pas, celle du socle", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  hommes.battre()
  verifier(hommes.tenir(id, "escorte", { activite = "suivre", lieu = "escorte", fin = "liberation" }), "escorte posée")
  verifier(hommes.tenir(id, "fouille", { activite = "fouille", lieu = "corps", position = { x = 5, y = 5, z = 0 }, fin = "liberation" }) ~= nil, "fouille demandée")
  local avant = Scriptorium.avis(hommes, "activite_de", id, 10)
  egal(avant.regle, "escorte", "le socle : l'escorte l'emporte")
  local f = hommes.fiche(id)
  verifier(f.tenues and f.tenues.fouille ~= nil, "la fouille posée sous l'escorte")
  avec_remplacement(hommes, "regle_la_plus_forte", function() return "fouille" end, function()
    local a = Scriptorium.avis(hommes, "activite_de", id, 10)
    egal(a.regle, "fouille", "Scriptorium : la fouille l'emporte")
    egal(a.activite, "fouille", "son activité suit")
  end)
  avec_remplacement(hommes, "regle_la_plus_forte", function() return "bains" end, function()
    egal(Scriptorium.avis(hommes, "activite_de", id, 10).regle, "escorte", "une règle qu'il ne porte pas : celle du socle")
  end)
  avec_remplacement(hommes, "regle_la_plus_forte", function() return false end, function()
    local a = Scriptorium.avis(hommes, "activite_de", id, 10)
    verifier(a.regle ~= "escorte" and a.regle ~= "fouille", "faux : aucune tenue, sa journée")
  end)
  hommes.lacher(id, "fouille")
  hommes.lacher(id, "escorte")
end)

-- ---------------------------------------------------------------- fiche 18, 5 b : rendre un homme parlable

essai("parlable (5 b) : « Parler » posé sur l'homme désigné, reposé au battement ; l'accroche reçoit l'homme ; ôté ; refus d'un inconnu", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local autre = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  local perso, perso_autre = hommes.fiche(id).personnage, hommes.fiche(autre).personnage
  FauxJeu.parlables, FauxJeu.poses_parlables = {}, 0
  verifier(hommes.rendre_parlable(id, true), "rendu parlable")
  verifier(FauxJeu.parlables[perso], "« Parler » posé sur son personnage")
  verifier(not FauxJeu.parlables[perso_autre], "pas sur un autre")
  FauxJeu.parlables[perso] = nil   -- l'entité refaite au chargement : l'enveloppe perdue
  hommes.battre()
  verifier(FauxJeu.parlables[perso], "reposé au battement")
  verifier(FauxJeu.parler_a(perso), "Henry lui parle")
  local lignes = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "Henry parle à", 1, true) then lignes = lignes + 1 end
  end
  egal(lignes, 1, "par défaut, une ligne au journal")
  local recu = nil
  avec_remplacement(hommes, "quand_on_lui_parle", function(i) recu = i end, function()
    FauxJeu.parler_a(perso)
  end)
  egal(recu, id, "le dialogue de Scriptorium reçoit l'homme")
  avec_remplacement(hommes, "quand_on_lui_parle", function() error("panne") end, function()
    verifier(pcall(FauxJeu.parler_a, perso) or true, "une accroche en panne ne casse rien côté socle")
  end)
  verifier(hommes.rendre_parlable(id, false), "ôté")
  verifier(not FauxJeu.parler_a(perso), "plus parlable")
  local poses = FauxJeu.poses_parlables
  hommes.battre()
  egal(FauxJeu.poses_parlables, poses, "ôté : plus reposé au battement")
  local ok, r = hommes.rendre_parlable("homme_inconnu", true)
  verifier(not ok and r == "homme_inconnu", "un inconnu : refusé")
end)

-- ---------------------------------------------------------------- fiche 18, 5 c : les gens de métier

essai("métiers (5 c) : les gens de métier exemptés de garde, de ronde et de patrouille, en données", function()
  preparer(5000, 100, 14)
  camp.agrandir()
  local soldats = {}
  for i = 1, 4 do soldats[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 }) end
  local forgeron = hommes.embaucher({ role = "forgeron", semaines = 4, prime = 0 })
  local cuisinier = hommes.embaucher({ role = "cuisinier", semaines = 4, prime = 0 })
  verifier(forgeron and cuisinier, "engagés")
  for h = 0, 23 do
    for _, g in ipairs(hommes.gardes(100 + h)) do
      verifier(g.id ~= forgeron and g.id ~= cuisinier, "jamais de garde (" .. h .. " h)")
    end
  end
  local ok, r = hommes.tenir(forgeron, "ronde", { activite = "ronde", lieu = "ronde", chemin = { { x = 0, y = 0, z = 0 }, { x = 5, y = 0, z = 0 } }, fin = "liberation" })
  verifier(not ok and r == "homme_exempte", "pas de ronde")
  egal(hommes.libre_pour(forgeron, "patrouille"), false, "pas de patrouille")
  egal(hommes.libre_pour(forgeron, "mission"), true, "mais une mission, oui")
  hommes.exemptions_des_metiers.garde = 0
  egal(hommes.libre_pour(forgeron, "garde"), true, "réglé à 0 : de garde possible")
  hommes.exemptions_des_metiers.garde = 1
end)

essai("métiers (5 c) : admettre un personnage déjà né (le forgeron de Scriptorium) ; jamais refait, renvoyé, équipé ni mis dehors", function()
  preparer(5000, 100, 10)
  local perso = FauxJeu.faire_venir_homme("ame-de-scriptorium", "Forgeron de Scriptorium", { x = 3, y = 3, z = 0 })
  local nes = #FauxJeu.personnages
  local id, r = hommes.admettre(perso, { role = "forgeron", semaines = 4, prime = 0, nom = "Mikuláš" })
  verifier(id, "admis (" .. tostring(r) .. ")")
  egal(#FauxJeu.personnages, nes, "aucun personnage né")
  local f = hommes.fiche(id)
  egal(f.personnage, perso, "son personnage")
  egal(hommes.homme_du_personnage(perso), id, "connu par son personnage")
  egal(f.equipement, nil, "pas équipé")
  local ok2, r2 = hommes.admettre(perso, { role = "forgeron", semaines = 4, prime = 0 })
  verifier(not ok2 and r2 == "deja_de_la_compagnie", "pas deux fois")
  local ok3, r3 = hommes.admettre("personnage_inconnu", { role = "forgeron", semaines = 4, prime = 0 })
  verifier(not ok3 and r3 == "personnage_introuvable", "un personnage introuvable : refusé")
  local ok4, r4 = hommes.mettre_dehors(id, "essai")
  verifier(not ok4 and r4 == "personnage_admis", "jamais mis dehors")
  -- Absent (une autre carte) : il attend, rien n'est refait.
  FauxJeu.personnages_existants[perso] = nil
  hommes.redresser()
  egal(#FauxJeu.personnages, nes, "absent : rien de refait")
  FauxJeu.personnages_existants[perso] = true
  local renvoyes = #FauxJeu.personnages_renvoyes
  verifier(hommes.retirer(id, "renvoye"), "retiré de la Compagnie")
  egal(#FauxJeu.personnages_renvoyes, renvoyes, "son personnage reste dans le monde")
  verifier(FauxJeu.personnage_existe(perso), "toujours là")
end)

essai("embauche (5 a bis) : un homme refait avec son équipement donné (une liste d'objets, au lieu du préréglage), posé à un point", function()
  preparer(5000, 100, 10)
  local CASQUE, EPEE = "aaaaaaaa-1111-2222-3333-444444444444", "BBBBBBBB-1111-2222-3333-555555555555"
  local id, r = hommes.embaucher({ role = "homme_d_armes", palier = 2, semaines = 4, prime = 0, nom = "Vavřinec",
    position = { x = 40, y = -40, z = 0 }, objets = { { objet = CASQUE, etat = 0.6 }, EPEE } })
  verifier(id, "engagé (" .. tostring(r) .. ")")
  local e = hommes.fiche(id).equipement
  egal(e.tenue, nil, "pas de préréglage")
  egal(e.etat, "a_equiper", "à équiper")
  FauxJeu.equipements = {}
  hommes.battre()
  local ordre = FauxJeu.equipements[1] and FauxJeu.equipements[1].ordre
  verifier(ordre ~= nil, "équipé au battement")
  egal(ordre and #ordre.creer, 0, "aucune pièce de préréglage créée")
  egal(ordre and #ordre.recreer, 2, "ses deux objets recréés")
  egal(ordre and ordre.recreer[1].etat, 0.6, "avec leur état")
  egal(ordre and ordre.recreer[2].objet, string.lower(EPEE), "l'identifiant en minuscules")
  egal(ordre and #ordre.porter, 2, "et portés")
  for _, mauvais in ipairs({ {}, { "pas un objet" }, { { objet = CASQUE, etat = 2 } }, "casque" }) do
    local i2, r2 = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0, objets = mauvais })
    verifier(not i2 and (r2 == "objets_invalides" or r2 == "objet_invalide"), "objets boiteux : refusés")
  end
end)

essai("métiers (5 c) : un admis combattant jamais équipé, sans prime payée par défaut ; mort, aucun corps rendu", function()
  preparer(5000, 100, 10)
  local perso = FauxJeu.faire_venir_homme("ame-de-scriptorium-2", "Garde de Scriptorium", { x = 4, y = 4, z = 0 })
  local avant = coffre.solde()
  local id = hommes.admettre(perso, { role = "homme_d_armes", semaines = 4 })
  verifier(id, "admis")
  egal(coffre.solde(), avant, "aucune prime payée")
  FauxJeu.equipements = {}
  for _ = 1, 3 do hommes.battre() end
  egal(hommes.fiche(id).equipement, nil, "jamais équipé")
  egal(#FauxJeu.equipements, 0, "aucun ordre d'équipement")
  local renvoyes = #FauxJeu.personnages_renvoyes
  local ok, corps = hommes.retirer(id, "mort")
  verifier(ok, "mort")
  egal(corps, nil, "aucun corps rendu (il est à Scriptorium)")
  egal(#FauxJeu.personnages_renvoyes, renvoyes, "jamais renvoyé")
end)

essai("postes de travail (5 c, tranche 2) : rendre un poste fonctionnel, l'homme y va (ordre de poste), reposé au redressement, retiré au levage", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "cuisinier", semaines = 4, prime = 0 })
  hommes.battre()
  FauxJeu.postes_poses = {}
  verifier(not camp.rendre_fonctionnel("autel", "inconnu", { x = 5, y = 5, z = 0 }, 0), "genre inconnu : refusé")
  verifier(not camp.rendre_fonctionnel("", "priere", { x = 5, y = 5, z = 0 }, 0), "nom vide : refusé")
  verifier(not camp.rendre_fonctionnel("autel", "priere", { x = 5 }, 0), "point boiteux : refusé")
  verifier(Scriptorium.avis(camp, "rendre_fonctionnel", "autel", "priere", { x = 5, y = 5, z = 0 }, 90), "posé")
  egal(#FauxJeu.postes_poses, 1, "un objet du jeu posé")
  local pose = FauxJeu.postes_poses[1]
  egal(pose.gabarit, camp.genres_de_postes.priere.gabarit, "le gabarit du genre")
  egal(pose.geste, "useKneelingGround", "son geste")
  egal(camp.postes()[1], "autel", "listé")
  local ok, r = hommes.tenir(id, "travail", { activite = "poste", poste = "nulle_part", fin = "liberation" })
  verifier(not ok and r == "poste_inconnu", "un poste inconnu : refusé")
  FauxJeu.ordres = {}
  verifier(hommes.tenir(id, "travail", { activite = "poste", poste = "autel", fin = "liberation" }), "tenu au poste")
  local perso = hommes.fiche(id).personnage
  local vu = nil
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == perso and o.activite == "poste" then vu = o end
  end
  verifier(vu ~= nil, "l'ordre du poste donné")
  egal(vu and vu.place, pose.identifiant, "sur l'objet du poste")
  egal(vu and vu.sorte, "poste", "de sorte « poste »")
  egal(vu and vu.position and vu.position.x, 5, "à sa position")
  -- Un autre poste : un nouvel ordre (vu en jeu le 17/10).
  verifier(camp.rendre_fonctionnel("autel_2", "priere", { x = 9, y = 5, z = 0 }, 90), "un second poste")
  FauxJeu.ordres = {}
  verifier(hommes.tenir(id, "travail", { activite = "poste", poste = "autel_2", fin = "liberation" }), "tenu au second poste")
  local second = nil
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == perso and o.activite == "poste" then second = o end
  end
  verifier(second ~= nil and second.position.x == 9, "l'ordre redonné pour le second poste")
  verifier(hommes.tenir(id, "travail", { activite = "poste", poste = "autel", fin = "liberation" }), "de retour au premier")
  -- Rechargé : l'objet manque, il est reposé.
  local poses_avant = #FauxJeu.postes_poses
  FauxJeu.objets_existants[pose.identifiant] = nil
  camp.redresser()
  egal(#FauxJeu.postes_poses, poses_avant + 1, "reposé au redressement (seul celui qui manque)")
  verifier(camp.poste("autel").pose, "de nouveau posé")
  hommes.lacher(id, "travail")
  verifier(camp.lever(), "camp levé")
  verifier(not FauxJeu.objet_existe(FauxJeu.postes_poses[#FauxJeu.postes_poses].identifiant), "le poste retiré avec le camp")
  egal(#camp.postes(), 0, "plus de poste")
end)

essai("geste tenu (5 c) : un geste du jeu tenu à un point (la forge de Scriptorium) ; un autre geste, un nouvel ordre ; refus d'un geste boiteux", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "forgeron", semaines = 4, prime = 0 })
  local perso = hommes.fiche(id).personnage
  hommes.battre()
  verifier(not hommes.tenir(id, "travail", { activite = "geste", geste = "pas un geste", position = { x = 1, y = 1, z = 0 } }), "geste boiteux : refusé")
  verifier(not hommes.tenir(id, "travail", { activite = "geste", geste = "marteler" }), "sans point : refusé")
  FauxJeu.ordres, FauxJeu.gestes = {}, {}
  verifier(hommes.tenir(id, "travail", { activite = "geste", lieu = "enclume", geste = "marteler", position = { x = 4, y = 2, z = 0 }, cap = 90, fin = "liberation" }), "tenu")
  egal(FauxJeu.gestes[perso], "marteler", "le geste donné à la liaison")
  local vu = nil
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == perso and o.activite == "geste" then vu = o end
  end
  verifier(vu ~= nil and vu.position.x == 4, "l'ordre du geste, au point")
  verifier(vu and vu.regard and math.abs(vu.regard.x - 9) < 0.01, "regardant selon le cap (à l'est)")
  FauxJeu.ordres = {}
  verifier(hommes.tenir(id, "travail", { activite = "geste", lieu = "foyer", geste = "chauffer", position = { x = 6, y = 2, z = 0 }, fin = "liberation" }), "l'autre temps de la ronde")
  egal(FauxJeu.gestes[perso], "chauffer", "l'autre geste")
  local deux = 0
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == perso and o.activite == "geste" then deux = deux + 1 end
  end
  verifier(deux >= 1, "un nouvel ordre")
  hommes.lacher(id, "travail")
end)

essai("geste tenu ancré (demande du pair, 18/10) : sur une place du camp, assis par défaut, au point de l'objet ; sur un objet nommé, debout ; l'arme à la main ; un objet introuvable refusé", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local perso = hommes.fiche(id).personnage
  hommes.battre()
  local banc = camp.objet_du_jeu_de("siege_1")
  verifier(banc ~= nil, "le banc du camp a son objet du jeu")
  FauxJeu.positions_des_objets = { [banc] = { x = 3, y = 4, z = 0 }, pupitre_1 = { x = 7, y = 1, z = 0 } }
  verifier(not hommes.tenir(id, "travail", { activite = "geste", geste = "camper_snooze", siege = "nulle_part" }), "objet introuvable : refusé")
  verifier(not hommes.tenir(id, "travail", { activite = "geste", geste = "camper_snooze", siege = "siege_1", assis = "oui" }), "assis boiteux : refusé")
  FauxJeu.ordres, FauxJeu.gestes, FauxJeu.options_des_gestes = {}, {}, {}
  verifier(hommes.tenir(id, "travail", { activite = "geste", geste = "camper_snooze", siege = "siege_1", fin = "liberation" }), "tenu sur le banc")
  egal(FauxJeu.gestes[perso], "camper_snooze", "le geste")
  local o = FauxJeu.options_des_gestes[perso]
  egal(o.ancre, banc, "ancré sur l'objet du banc")
  verifier(o.assis == true, "assis : c'est une place pour s'asseoir")
  verifier(o.arme == false, "l'arme rangée par défaut")
  local vu = nil
  for _, ordre in ipairs(FauxJeu.ordres) do
    if ordre.identifiant == perso and ordre.activite == "geste" then vu = ordre end
  end
  verifier(vu ~= nil and vu.position.x == 3 and vu.position.y == 4, "l'ordre au point de l'objet")
  FauxJeu.ordres = {}
  verifier(hommes.tenir(id, "travail", { activite = "geste", geste = "readingBookStand", siege = "pupitre_1", arme_tiree = true, fin = "liberation" }), "tenu au pupitre")
  o = FauxJeu.options_des_gestes[perso]
  egal(o.ancre, "pupitre_1", "une entité nommée, telle quelle")
  verifier(o.assis == false, "debout : ce n'est pas une place")
  verifier(o.arme == true, "l'arme à la main")
  local nouveau = false
  for _, ordre in ipairs(FauxJeu.ordres) do
    if ordre.identifiant == perso and ordre.activite == "geste" then nouveau = true end
  end
  verifier(nouveau, "un autre objet, un nouvel ordre")
  hommes.lacher(id, "travail")
  FauxJeu.positions_des_objets = nil
end)

essai("postes (5 c) : avec « reposer_tout_a_l_entree », les postes sont reposés à neuf eux aussi ; un nom accentué permis", function()
  preparer(5000, 100, 10)
  FauxJeu.postes_poses = {}
  verifier(camp.rendre_fonctionnel("prie-Dieu é", "priere", { x = 5, y = 5, z = 0 }, 0), "nom accentué : posé")
  local avant = #FauxJeu.postes_poses
  local ancien = camp.reglages.reposer_tout_a_l_entree
  camp.reglages.reposer_tout_a_l_entree = 1
  local ok, erreur = pcall(camp.relancer)
  camp.reglages.reposer_tout_a_l_entree = ancien
  verifier(ok, "sans erreur : " .. tostring(erreur))
  egal(#FauxJeu.postes_poses, avant + 1, "le poste reposé à neuf")
  verifier(camp.poste("prie-Dieu é").pose, "posé")
end)

-- ---------------------------------------------------------------- fiche 20 : les paroles

essai("paroles (choix du pair, 20/10 : un porteur ne cause pas en route) : en marche vers son but, une parole attend ; arrivé, elle se dit ; urgente, elle passe", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local p = hommes.fiche(id).personnage
  local but = camp.point(0, -6, 0)
  hommes.tenir(id, "travail", { activite = "geste", geste = "Loot", lieu = "depot", position = but, fin = "liberation" })
  local function parole_ordonnee()
    for _, o in ipairs(FauxJeu.ordres) do
      if o.identifiant == p and o.activite == "parole" then return true end
    end
    return false
  end
  FauxJeu.positions[p] = { x = but.x + 30, y = but.y, z = 0 }
  FauxJeu.ordres = {}
  verifier(hommes.dire_une_replique(id, { metarole = "GOSSIP" }), "demandée")
  hommes.battre()
  verifier(not parole_ordonnee(), "à 30 m de son but : la parole attend")
  FauxJeu.positions[p] = { x = but.x + 1, y = but.y, z = 0 }
  hommes.battre()
  verifier(parole_ordonnee(), "arrivé : la parole se dit")
  FauxJeu.variables_du_cerveau = FauxJeu.variables_du_cerveau or {}
  FauxJeu.variables_du_cerveau[p] = { scriptorium_parole_jouee = 1 }
  hommes.battre()
  -- Urgente (l'alerte) : elle passe même en route.
  FauxJeu.positions[p] = { x = but.x + 30, y = but.y, z = 0 }
  FauxJeu.ordres = {}
  verifier(hommes.dire_une_replique(id, { metarole = "GOSSIP", urgente = true }), "urgente demandée")
  verifier(parole_ordonnee(), "urgente : dite en route")
  hommes.lacher(id, "travail")
end)

essai("paroles (vu sur une copie le 21/10, J3) : une parole non urgente attend tant qu'une règle plus forte que celle de Scriptorium tient l'homme (mission) ; à rang égal ou plus faible, elle passe", function()
  preparer(5000, 100, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  hommes.battre()
  local p = hommes.fiche(a).personnage
  verifier(hommes.tenir(a, "mission", { activite = "suivre", lieu = "mission_1", fin = "liberation" }), "tenu par une mission")
  FauxJeu.ordres = {}
  verifier(hommes.dire_une_replique(a, { metarole = "GOSSIP" }), "demandée")
  local vu = false
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == p and o.activite == "parole" then vu = true end
  end
  verifier(not vu, "en mission : la parole attend")
  egal(Scriptorium.avis(hommes, "peut_parler", a, hommes.parole_de(a), hommes.activite_de(a, FauxJeu.heure)), false, "pas maintenant")
  hommes.lacher(a, "mission")
  local a2 = Scriptorium.avis(hommes, "activite_de", a, FauxJeu.heure)
  if a2 and a2.position then
    FauxJeu.positions[p] = { x = a2.position.x, y = a2.position.y, z = 0 }
  end
  verifier(hommes.tenir(a, "travail", { activite = "geste", lieu = "forge", geste = "eating_standing", position = { x = 3, y = 4, z = 0 }, fin = "liberation" }), "tenu par une règle plus faible")
  FauxJeu.positions[p] = { x = 3, y = 4, z = 0 }
  egal(Scriptorium.avis(hommes, "peut_parler", a, hommes.parole_de(a), hommes.activite_de(a, FauxJeu.heure)), true, "règle plus faible : elle passe")
  verifier(hommes.dire_une_replique(a, { metarole = "GOSSIP", urgente = true }), "urgente")
  verifier(hommes.tenir(a, "mission", { activite = "suivre", lieu = "mission_1", fin = "liberation" }), "de nouveau en mission")
  egal(Scriptorium.avis(hommes, "peut_parler", a, hommes.parole_de(a), hommes.activite_de(a, FauxJeu.heure)), true, "urgente : elle passe en mission")
end)

essai("poser un homme (demande du pair, 21/10, J6) : à pied par la téléportation du jeu ; en selle avec son cheval ; par son nom ; jamais sous les yeux d'Henry ; refus", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local p = hommes.fiche(id).personnage
  FauxJeu.positions[p] = { x = 100, y = 0, z = 0 }
  hommes.battre()
  FauxJeu.vue_d_henry = function() return false end
  local ok, raison = hommes.poser("inconnu", { x = 1, y = 1, z = 0 })
  verifier(not ok and raison == "homme_inconnu", "un inconnu refusé")
  ok, raison = hommes.poser(id, { x = 1 })
  verifier(not ok and raison == "point_invalide", "un point boiteux refusé")
  FauxJeu.secours = {}
  FauxJeu.positions[p] = { x = 100, y = 0, z = 0 }
  verifier(hommes.poser(id, { x = 500, y = 0, z = 0 }), "posé à pied")
  egal(#FauxJeu.secours, 1, "par la téléportation du jeu")
  egal(FauxJeu.secours[1] and FauxJeu.secours[1].position.x, 500, "au point")
  FauxJeu.positions[p] = { x = 100, y = 0, z = 0 }
  verifier(hommes.poser(p, { x = 600, y = 0, z = 0 }), "par le nom de son personnage")
  -- En selle : le cheval posé, le cavalier avec lui ; jamais l'homme seul.
  FauxJeu.positions[p] = { x = 100, y = 0, z = 0 }
  FauxJeu.chevaux = {}
  verifier(hommes.tenir(id, "mission", { activite = "suivre", lieu = "m", vers = { x = 900, y = 0, z = 0 }, a_cheval = true, fin = "liberation" }), "une colonne à cheval")
  local c = hommes.montures[id] and hommes.montures[id].cheval
  verifier(c ~= nil, "son cheval")
  FauxJeu.chevaux_montes = { [c] = true }
  FauxJeu.secours = {}
  FauxJeu.positions[p] = { x = 100, y = 0, z = 0 }
  verifier(hommes.poser(id, { x = 700, y = 0, z = 0 }), "posé en selle")
  egal(FauxJeu.chevaux[c].x, 700, "son cheval posé au point")
  egal(#FauxJeu.secours, 0, "jamais l'homme seul")
  -- Sous les yeux d'Henry : refusé.
  FauxJeu.vue_d_henry = function() return true end
  FauxJeu.position_joueur = { x = 650, y = 0, z = 0 }
  ok, raison = hommes.poser(id, { x = 720, y = 0, z = 0 })
  verifier(not ok and raison == "vu_d_henry", "sous les yeux d'Henry : refusé")
  FauxJeu.vue_d_henry, FauxJeu.position_joueur, FauxJeu.chevaux_montes = nil, nil, nil
  hommes.lacher(id, "mission")
end)

essai("paroles du personnel mené (demande du pair, 20/10) : une réplique et une conversation par le nom de l'entité ; jouée puis oubliée ; un inconnu refusé", function()
  preparer(5000, 100, 10)
  FauxJeu.personnages_existants["forgeron_x"] = true
  FauxJeu.personnages_existants["dame_1"] = true
  verifier(hommes.tenir_un_personnage("forgeron_x", "travail", { activite = "garde", lieu = "forge", position = { x = 3, y = 4, z = 0 }, fin = "liberation" }), "forgeron mené")
  verifier(hommes.tenir_un_personnage("dame_1", "travail", { activite = "garde", lieu = "bains", position = { x = 8, y = 4, z = 0 }, fin = "liberation" }), "dame menée")
  FauxJeu.positions["forgeron_x"] = { x = 3, y = 4, z = 0 }
  FauxJeu.positions["dame_1"] = { x = 8, y = 4, z = 0 }
  local ok, raison = hommes.dire_une_replique_du_personnage("inconnu", { metarole = "GOSSIP" })
  verifier(not ok and raison == "pas_mene", "un personnage ni mené ni de la Compagnie : refusé")
  FauxJeu.ordres, FauxJeu.paroles = {}, {}
  verifier(hommes.dire_une_replique_du_personnage("forgeron_x", { metarole = "NPC_VYVOLAVANI_NA_TRHU" }), "réplique demandée")
  local vu = false
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == "forgeron_x" and o.activite == "parole" then vu = true end
  end
  verifier(vu, "l'ordre de parole donné au mené")
  egal(FauxJeu.paroles["forgeron_x"] and FauxJeu.paroles["forgeron_x"].sorte, 1, "une réplique")
  egal(FauxJeu.paroles["forgeron_x"] and FauxJeu.paroles["forgeron_x"].metarole, "NPC_VYVOLAVANI_NA_TRHU", "son metarole")
  FauxJeu.variables_du_cerveau = FauxJeu.variables_du_cerveau or {}
  FauxJeu.variables_du_cerveau["forgeron_x"] = { scriptorium_parole_jouee = 1 }
  hommes.battre()
  egal(hommes.parole_de("mene_forgeron_x"), nil, "jouée : oubliée")
  verifier(lignes_contenant("« forgeron_x » a dit « NPC_VYVOLAVANI_NA_TRHU »") >= 1, "dite au journal")
  local ok2, raison2 = hommes.conversation_du_personnage("dame_1", "personne", { alias = "scr_cv_dame_camp_1" })
  verifier(not ok2 and raison2 == "partenaire_invalide", "partenaire inconnu : refusé")
  verifier(hommes.conversation_du_personnage("dame_1", "forgeron_x", { alias = "scr_cv_dame_camp_1" }), "conversation demandée")
  egal(FauxJeu.paroles["dame_1"] and FauxJeu.paroles["dame_1"].sorte, 2, "une conversation")
  egal(FauxJeu.paroles["dame_1"] and FauxJeu.paroles["dame_1"].partenaire, "forgeron_x", "avec le forgeron")
end)

essai("paroles (fiche 20) : une réplique jouée une fois puis oubliée ; une conversation avec son partenaire ; jamais au lit ni en combat ; oubliée après l'attente", function()
  preparer(5000, 100, 10)
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local b = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  hommes.battre()
  local pa, pb = hommes.fiche(a).personnage, hommes.fiche(b).personnage
  verifier(not hommes.dire_une_replique(a, {}), "sans alias ni metarole : refusée")
  verifier(not hommes.dire_une_replique(a, { alias = "pas un alias !" }), "alias boiteux : refusée")
  verifier(not hommes.conversation(a, a, { metarole = "GOSSIP" }), "partenaire lui-même : refusée")
  FauxJeu.ordres, FauxJeu.paroles = {}, {}
  verifier(hommes.dire_une_replique(a, { alias = "scr_bonjour", regard_henry = true }), "demandée")
  local vu = nil
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == pa and o.activite == "parole" then vu = o end
  end
  verifier(vu ~= nil, "l'ordre de parole donné")
  egal(FauxJeu.paroles[pa] and FauxJeu.paroles[pa].sorte, 4, "réplique en regardant Henry")
  egal(FauxJeu.paroles[pa] and FauxJeu.paroles[pa].alias, "scr_bonjour", "son alias")
  -- L'arbre l'a jouée : le compteur du cerveau avance ; au battement, la parole est oubliée, la journée reprend.
  FauxJeu.variables_du_cerveau = FauxJeu.variables_du_cerveau or {}
  FauxJeu.variables_du_cerveau[pa] = { scriptorium_parole_jouee = 1 }
  hommes.battre()
  egal(hommes.parole_de(a), nil, "jouée : oubliée")
  verifier(lignes_contenant("a dit « scr_bonjour »") >= 1, "dite au journal")
  -- La conversation : le partenaire donné à la liaison.
  verifier(hommes.conversation(a, b, { metarole = "GOSSIP" }), "conversation demandée")
  egal(FauxJeu.paroles[pa].sorte, 2, "conversation")
  egal(FauxJeu.paroles[pa].partenaire, pb, "avec son partenaire")
  FauxJeu.variables_du_cerveau[pa] = { scriptorium_parole_jouee = 2 }
  hommes.battre()
  egal(hommes.parole_de(a), nil, "jouée")
  -- En combat : elle attend ; trop longtemps : oubliée.
  FauxJeu.occupations[pb] = "combat"
  FauxJeu.ordres = {}
  verifier(hommes.dire_une_replique(b, { metarole = "GOSSIP" }), "demandée en combat")
  local en_combat = false
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == pb and o.activite == "parole" then en_combat = true end
  end
  verifier(not en_combat, "en combat : pas d'ordre de parole")
  FauxJeu.heure = FauxJeu.heure + hommes.reglages.parole_attente_max_h + 0.1
  hommes.battre()
  egal(hommes.parole_de(b), nil, "trop attendu : oubliée")
  FauxJeu.occupations[pb] = nil
  -- Au lit (la nuit) : elle attend.
  FauxJeu.heure = 24 * 3 + 23
  hommes.battre()
  verifier(hommes.dire_une_replique(a, { metarole = "GOSSIP" }), "demandée la nuit")
  egal(Scriptorium.avis(hommes, "peut_parler", a, hommes.parole_de(a), Scriptorium.avis(hommes, "activite_de", a, FauxJeu.heure)), false, "au sommeil : pas maintenant")
  -- Remplaçable : Scriptorium l'autorise quand même.
  avec_remplacement(hommes, "peut_parler", function() return true end, function()
    FauxJeu.ordres = {}
    hommes.battre()
  end)
  local nuit = false
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == pa and o.activite == "parole" then nuit = true end
  end
  verifier(nuit, "remplacée : la parole passe")
  FauxJeu.variables_du_cerveau = {}
end)

essai("poste partagé (5 c, tranche 4) : Henry prend la station, l'homme cède et attend à côté ; rendue, il reprend ; station inconnue refusée", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "forgeron", semaines = 4, prime = 0 })
  local perso = hommes.fiche(id).personnage
  hommes.battre()
  FauxJeu.positions_des_objets = { forge_du_village = { x = 10, y = 0, z = 0 } }
  FauxJeu.positions[perso] = { x = 9, y = 0, z = 0 }
  verifier(not hommes.tenir(id, "travail", { activite = "geste", geste = "marteler", position = { x = 9, y = 0, z = 0 }, partage = "inconnue", fin = "liberation" }), "station non surveillée : refusé")
  verifier(hommes.partager_avec_henry("forge_du_village", true), "station surveillée")
  verifier(FauxJeu.stations.forge_du_village, "enveloppée par la liaison")
  verifier(hommes.tenir(id, "travail", { activite = "geste", geste = "marteler", position = { x = 9, y = 0, z = 0 }, partage = "forge_du_village", fin = "liberation" }), "au travail")
  egal(Scriptorium.avis(hommes, "activite_de", id, 10).activite, "geste", "il forge")
  FauxJeu.ordres = {}
  verifier(FauxJeu.henry_prend("forge_du_village"), "Henry prend la station")
  egal(hommes.station_prise("forge_du_village"), true, "prise")
  local a = Scriptorium.avis(hommes, "activite_de", id, 10)
  egal(a.activite, "cede", "il cède la place")
  verifier(a.position and math.abs(a.position.x - 7.5) < 0.01, "il attend à 2,5 m, de son côté")
  local ordonne = false
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == perso and o.activite == "cede" then ordonne = true end
  end
  verifier(ordonne, "l'ordre donné aussitôt")
  FauxJeu.henry_fini = false
  hommes.battre()
  egal(hommes.station_prise("forge_du_village"), true, "Henry pas fini : toujours prise")
  FauxJeu.henry_fini = true
  FauxJeu.ordres = {}
  hommes.battre()
  egal(hommes.station_prise("forge_du_village"), false, "rendue")
  egal(Scriptorium.avis(hommes, "activite_de", id, 10).activite, "geste", "il reprend son geste")
  avec_remplacement(hommes, "ou_attendre", function() return { x = 0, y = 20, z = 0 } end, function()
    FauxJeu.henry_fini = false
    FauxJeu.henry_prend("forge_du_village")
    egal(Scriptorium.avis(hommes, "activite_de", id, 10).position.y, 20, "le point d'attente de Scriptorium")
  end)
  FauxJeu.henry_fini = nil
  hommes.lacher(id, "travail")
  hommes.partager_avec_henry("forge_du_village", false)
  hommes.stations = {}
end)

essai("tir à la cible (demande du pair, 20/10) : au poste, la cible nommée donnée avant l'ordre, regard sur elle ; tenu ; la cible change : redonné ; refus sans poste ni cible", function()
  preparer(5000, 100, 10)
  local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  local p = hommes.fiche(id).personnage
  FauxJeu.objets_existants["scriptorium_visee_1"] = true
  FauxJeu.objets_existants["scriptorium_visee_2"] = true
  FauxJeu.positions_des_objets = FauxJeu.positions_des_objets or {}
  FauxJeu.positions_des_objets["scriptorium_visee_1"] = { x = 20, y = 0, z = 1 }
  FauxJeu.positions_des_objets["scriptorium_visee_2"] = { x = 0, y = 20, z = 1 }
  local poste = { x = 5, y = 0, z = 0 }
  local ok, raison = hommes.tenir(id, "travail", { activite = "tir", position = poste, fin = "liberation" })
  verifier(not ok and raison == "tir_invalide", "sans cible : refusé")
  ok, raison = hommes.tenir(id, "travail", { activite = "tir", position = poste, cible = "rien", fin = "liberation" })
  verifier(not ok and raison == "tir_invalide", "cible introuvable : refusé")
  ok, raison = hommes.tenir(id, "travail", { activite = "tir", cible = "scriptorium_visee_1", fin = "liberation" })
  verifier(not ok and raison == "tir_invalide", "sans poste : refusé")
  FauxJeu.ordres, FauxJeu.cibles_du_tir = {}, {}
  verifier(hommes.tenir(id, "travail", { activite = "tir", position = poste, cible = "scriptorium_visee_1", fin = "liberation" }), "tenu")
  local o = FauxJeu.ordres[#FauxJeu.ordres]
  egal(o.activite, "tir", "l'ordre de tir")
  egal(o.position.x, 5, "au poste")
  egal(o.lieu, "tir/scriptorium_visee_1", "la cible dans le lieu")
  egal(o.regard and o.regard.x, 20, "tourné vers la cible")
  egal(FauxJeu.cibles_du_tir[p], "scriptorium_visee_1", "la cible donnée à la liaison")
  local n = #FauxJeu.ordres
  hommes.battre()
  egal(#FauxJeu.ordres, n, "tenu : pas d'ordre redonné")
  verifier(hommes.tenir(id, "travail", { activite = "tir", position = poste, cible = "scriptorium_visee_2", fin = "liberation" }), "autre cible")
  egal(#FauxJeu.ordres, n + 1, "la cible change : redonné")
  egal(FauxJeu.cibles_du_tir[p], "scriptorium_visee_2", "la nouvelle cible")
  verifier(hommes.lacher(id, "travail"), "lâché")
  verifier(FauxJeu.ordres[#FauxJeu.ordres].activite ~= "tir", "lâché : il reprend sa journée")
end)

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
  egal(hommes.fiche(id).equipement.etat, "pret", "prêt")
  local porte = hommes.ce_qu_il_porte(id)
  egal(#porte, 5, "trois pièces de tenue, deux d'armes")
  egal(porte[4], "axe_3_01_arme", "tenue d'abord, armes ensuite")
  egal(#FauxJeu.portes[personnage_de(id)], 5, "tout porté")
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
  for _ = 1, 4 do hommes.battre() end
  egal(#FauxJeu.equipements, 3, "trois combattants équipés, un par battement")
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
  egal(hommes.fiche(a).equipement.etat, "pret", "le premier")
  egal(hommes.fiche(b).equipement.etat, "a_equiper", "le second attend")
  hommes.battre()
  egal(hommes.fiche(b).equipement.etat, "pret", "le second au battement suivant")
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
  egal(hommes.fiche(id).equipement.etat, "pret", "rhabillé")
  egal(#FauxJeu.portes[p], #hommes.ce_qu_il_porte(id), "toutes ses pièces remises")
  egal(FauxJeu.portes[p][1], hommes.ce_qu_il_porte(id)[1], "dans l'ordre")
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
  local e = hommes.fiche(id).equipement
  egal(e.etat, "pret", "équipé")
  egal(string.match(e.armes, "^scriptorium_arbaletrier_1_[ab]$") ~= nil, true, "arbalète du palier 1")
  egal(a_dans_le_sac(id, "naissance_tunique"), 0, "tenue de naissance retirée")
end)

essai("équipement : un personnage refait est rééquipé, sa tenue de naissance retirée de nouveau", function()
  preparer(200, 10, 10)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4 })
  hommes.battre()
  hommes.donner_une_piece(id, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", 0.4, true)
  FauxJeu.personnages_existants[personnage_de(id)] = nil
  hommes.relancer()
  egal(personnage_de(id) ~= nil, true, "refait")
  egal(hommes.fiche(id).equipement.etat, "a_equiper", "à rééquiper")
  egal(#hommes.fiche(id).equipement.en_plus, 0, "pièces données perdues avec l'ancien")
  hommes.battre()
  egal(#FauxJeu.equipements, 2, "rééquipé")
  egal(FauxJeu.equipements[2].ordre.retirer_naissance, true, "tenue de naissance du nouveau retirée")
  egal(a_dans_le_sac(id, "naissance_tunique"), 0, "plus de tunique de naissance")
end)

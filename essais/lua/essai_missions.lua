-- Essais des missions, tranche 1 : le camp de bandits à un lieu (fiche 17).

local missions = Scriptorium.missions
local bataille = Scriptorium.bataille
local hommes = Scriptorium.hommes
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre

local LIEU = { x = 0, y = 200, z = 0 }

-- Au banc, le temps des missions est accéléré (dix fois les vitesses du jeu) : les heures des essais restent courtes.
local VITESSES = { colonne = missions.reglages.vitesse_m_par_h, convoi = missions.reglages.convoi_m_par_h }

local function preparer(roles)
  depart()
  missions.reglages.vitesse_m_par_h, missions.reglages.convoi_m_par_h = 12000, 4000
  FauxJeu.heure = 10
  FauxJeu.carte = "trosky"
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  coffre.encaisser(1000, "butin")
  coffre.ajouter_reserve("vivres", 500, "achat")
  local ids = {}
  for _, role in ipairs(roles or {}) do
    table.insert(ids, hommes.embaucher({ role = role, semaines = 8, prime = 0 }))
  end
  FauxJeu.attaques = {}
  Scriptorium.en_partie = true
  missions.ajouter_un_lieu("gue", "trosky", LIEU, 0)
  return ids
end

local function finir()
  missions.reglages.vitesse_m_par_h, missions.reglages.convoi_m_par_h = VITESSES.colonne, VITESSES.convoi
  Scriptorium.en_partie = false
  FauxJeu.attaques = nil
  FauxJeu.carte = nil
  FauxJeu.vue_d_henry = nil
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
end

local function battre()
  bataille.battre()
  missions.battre()
end

local function la_bande(id)
  return bataille.bande(missions.camp(id).bande)
end

local function tuer_la_bande(id)
  for _, e in ipairs(la_bande(id).personnages) do
    FauxJeu.ennemis_vivants_par_id[e] = nil
  end
end

essai("missions (18/10) : les lieux du socle, neuf par carte, tous à plus de 150 m l'un de l'autre ; le niveau du lieu plafonne celui du camp ; un lieu de Scriptorium du même nom passe devant", function()
  preparer()
  missions.lieux_du_socle = missions.lieux_du_socle_d_origine
  for _, carte in ipairs({ "kutnohorsko", "trosecko" }) do
    local lieux = missions.lieux_de(carte)
    egal(#lieux, 9, "neuf lieux sur " .. carte)
    for i, a in ipairs(lieux) do
      verifier(a.niveau == "petit" or a.niveau == "moyen" or a.niveau == "grand", "un niveau connu : " .. a.nom)
      for j = i + 1, #lieux do
        local b = lieux[j]
        verifier(math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) > 150, a.nom .. " et " .. b.nom .. " à plus de 150 m")
      end
    end
  end
  egal(missions.niveau_pour(1000000, "butte_des_archers"), "petit", "un lieu petit : jamais plus que petit")
  egal(missions.niveau_pour(1000000, "moulin_de_vrchlice"), "grand", "un lieu grand : selon la force")
  verifier(missions.ajouter_un_lieu("butte_des_archers", "kutnohorsko", { x = 1, y = 2, z = 3 }, 0), "remplacé par Scriptorium")
  egal(missions.lieu_nomme("butte_des_archers").x, 1, "celui de Scriptorium passe devant")
  egal(#missions.lieux_de("kutnohorsko"), 9, "toujours neuf, sans doublon")
  missions.lieux_du_socle = {}
end)

essai("missions : les lieux, fournis par Scriptorium, par carte ; un lieu boiteux refusé", function()
  preparer()
  verifier(not missions.ajouter_un_lieu("", "trosky", LIEU), "sans nom : refusé")
  verifier(not missions.ajouter_un_lieu("x", nil, LIEU), "sans carte : refusé")
  verifier(not missions.ajouter_un_lieu("x", "trosky", { x = 1, y = 2 }), "sans hauteur : refusé")
  verifier(missions.ajouter_un_lieu("mine", "kuttenberg", { x = 5, y = 5, z = 1 }, 90), "un lieu sur l'autre carte")
  egal(#missions.lieux_de("trosky"), 1, "un lieu sur Trosky")
  egal(#missions.lieux_de(nil), 2, "deux en tout")
  verifier(missions.lieu_sur_ma_carte("gue"), "le gué est sur ma carte")
  verifier(not missions.lieu_sur_ma_carte("mine"), "la mine n'y est pas")
  verifier(not missions.lieu_sur_ma_carte("inconnu"), "un lieu inconnu n'y est pas")
  finir()
end)

essai("missions : dresser un camp ; lieu inconnu, niveau inconnu, lieu pris refusés", function()
  preparer()
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
  verifier(not missions.dresser_un_camp("nulle_part", "petit"), "lieu inconnu")
  verifier(not missions.dresser_un_camp("gue", "enorme"), "niveau inconnu")
  local id = missions.dresser_un_camp("gue", "petit")
  verifier(id, "dressé")
  local c = missions.camp(id)
  egal(c.effectif, 4, "petit : quatre hommes")
  egal(c.coffre, 120, "petit : coffre de 120")
  egal(la_bande(id).etat, "postee", "sa bande est postée")
  local pris, raison = missions.dresser_un_camp("gue", "moyen")
  verifier(not pris and raison == "lieu_pris", "le lieu est pris")
  egal(#missions.camps(), 1, "un camp")
  finir()
end)

essai("missions : rien ne naît sur une autre carte ni sous les yeux d'Henry ; il se détourne : tout naît", function()
  preparer()
  FauxJeu.carte = "kuttenberg"
  local id = missions.dresser_un_camp("gue", "petit")
  battre()
  egal(#la_bande(id).personnages, 0, "autre carte : aucun bandit")
  verifier(not missions.camp(id).meubles, "autre carte : aucun meuble")
  FauxJeu.carte = "trosky"
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
  FauxJeu.vue_d_henry = function() return true end
  battre()
  egal(#la_bande(id).personnages, 0, "à 200 m, dans son regard : rien")
  verifier(not missions.camp(id).meubles, "ni meuble")
  FauxJeu.vue_d_henry = function() return false end
  battre()
  egal(#la_bande(id).personnages, 4, "il se détourne : quatre bandits")
  verifier(missions.camp(id).meubles, "et les meubles")
  local feu = nil
  for _, o in ipairs(FauxJeu.objets_poses) do
    if o.nom == "bandits_" .. id .. "_feu" then feu = o.identifiant end
  end
  verifier(feu and FauxJeu.feux_allumes[feu], "le feu du camp de bandits allumé")
  egal(la_bande(id).etat, "postee", "à 200 m : ils restent à leur poste")
  egal(#FauxJeu.attaques, 0, "aucune attaque")
  finir()
end)

essai("missions : Henry approche, la bande l'attaque ; tombée, le camp est vaincu une fois, son coffre au butin", function()
  preparer()
  local id = missions.dresser_un_camp("gue", "petit")
  battre()
  local vaincus = {}
  local ancienne = missions.camp_vaincu
  missions.camp_vaincu = function(c) table.insert(vaincus, c.id) return ancienne(c) end
  FauxJeu.position_joueur = { x = 0, y = 150, z = 0 }
  battre()
  egal(la_bande(id).etat, "postee", "à 50 m : rien")
  FauxJeu.position_joueur = { x = 0, y = 200 - bataille.reglages.poste_alerte_m + 1, z = 0 }
  battre()
  egal(la_bande(id).etat, "au_contact", "à moins de 35 m : au contact")
  local sur_henry = 0
  for _, a in ipairs(FauxJeu.attaques) do
    if a.cible == "henry" then sur_henry = sur_henry + 1 end
  end
  egal(sur_henry, 4, "les quatre attaquent Henry")
  battre()
  egal(la_bande(id).etat, "au_contact", "Henry tout près, seul : la bataille continue")
  local solde = coffre.solde()
  tuer_la_bande(id)
  battre()
  egal(la_bande(id).issue, "victoire", "tous tombés : victoire")
  egal(missions.camp(id).etat, "fini", "le camp est fini")
  battre()
  egal(#vaincus, 1, "camp vaincu, une seule fois")
  verifier(coffre.solde() > solde, "le coffre du camp au butin (part du coffre)")
  FauxJeu.heure = 10 + missions.reglages.camp_vaincu_reste_h + 1
  local retires = #FauxJeu.objets_retires
  battre()
  egal(#missions.camps(), 0, "24 h après : le camp est levé")
  egal(#FauxJeu.objets_retires - retires, 4, "ses quatre meubles retirés")
  verifier(missions.dresser_un_camp("gue", "petit"), "le lieu est libre")
  missions.camp_vaincu = ancienne
  finir()
end)

essai("missions : Henry s'enfuit, seul : la bande retourne à son poste avec ses survivants, sans issue", function()
  preparer()
  local id = missions.dresser_un_camp("gue", "petit")
  battre()
  FauxJeu.position_joueur = { x = 0, y = 190, z = 0 }
  battre()
  egal(la_bande(id).etat, "au_contact", "au contact")
  FauxJeu.ennemis_vivants_par_id[la_bande(id).personnages[1]] = nil
  FauxJeu.position_joueur = { x = 0, y = -200, z = 0 }
  local solde = coffre.solde()
  battre()
  egal(la_bande(id).etat, "postee", "Henry à 400 m : retour au poste")
  egal(la_bande(id).effectif, 3, "avec ses trois survivants")
  egal(coffre.solde(), solde, "rien de tranché : ni butin ni pillage")
  egal(missions.camp(id).etat, "dresse", "le camp tient")
  finir()
end)

essai("missions : un de nos hommes approche : l'alerte ; nos combattants proches s'engagent", function()
  local ids = preparer({ "homme_d_armes", "archer" })
  local id = missions.dresser_un_camp("gue", "petit")
  FauxJeu.position_joueur = { x = 0, y = -100, z = 0 }
  battre()
  local f1, f2 = hommes.fiche(ids[1]), hommes.fiche(ids[2])
  FauxJeu.positions[f1.personnage] = { x = 0, y = 170, z = 0 }    -- à 30 m
  FauxJeu.positions[f2.personnage] = { x = 0, y = 0, z = 0 }      -- au camp
  battre()
  local b = la_bande(id)
  egal(b.etat, "au_contact", "un homme à 30 m : l'alerte")
  egal(#b.combattants, 1, "seul l'homme proche s'engage")
  egal(hommes.qui_tient(ids[1]), "bataille", "tenu par la bataille")
  verifier(hommes.qui_tient(ids[2]) ~= "bataille", "l'autre reste à sa journée")
  local sur_le_notre = 0
  for _, a in ipairs(FauxJeu.attaques) do
    if a.cible == f1.personnage then sur_le_notre = sur_le_notre + 1 end
  end
  egal(sur_le_notre, 4, "la bande l'attaque (Henry est loin)")
  finir()
end)

essai("missions : au chargement, ennemis et meubles refaits, avec les survivants", function()
  preparer()
  local id = missions.dresser_un_camp("gue", "petit")
  FauxJeu.position_joueur = { x = 0, y = -100, z = 0 }
  battre()
  local avant = la_bande(id).personnages
  FauxJeu.ennemis_vivants_par_id[avant[1]] = nil
  battre()
  local renvoyes = #FauxJeu.ennemis_renvoyes
  bataille.relancer()
  missions.relancer()
  egal(#FauxJeu.ennemis_renvoyes - renvoyes, 4, "les anciens retirés")
  verifier(not missions.camp(id).meubles, "les meubles retirés")
  battre()
  egal(#la_bande(id).personnages, 3, "refaits : les trois survivants")
  verifier(la_bande(id).personnages[1] ~= avant[1], "de nouveaux personnages")
  verifier(missions.camp(id).meubles, "remeublé")
  finir()
end)

essai("missions : les accroches se remplacent ; lever un camp oublie sa bande", function()
  preparer()
  local ancienne = missions.taille_du_camp
  missions.taille_du_camp = function(lieu, niveau)
    local t = ancienne(lieu, niveau)
    t.effectif = 2
    return t
  end
  local id = missions.dresser_un_camp("gue", "grand")
  egal(missions.camp(id).effectif, 2, "la taille enveloppée")
  missions.taille_du_camp = ancienne
  FauxJeu.position_joueur = { x = 0, y = -100, z = 0 }
  battre()
  egal(#la_bande(id).personnages, 2, "deux bandits")
  verifier(missions.lever_un_camp(id), "levé")
  egal(la_bande(id).etat, "finie", "sa bande oubliée")
  egal(la_bande(id).issue, "oubliee", "sans issue")
  egal(#missions.camps(), 0, "plus de camp")
  verifier(not missions.lever_un_camp(id), "déjà levé : refusé")
  finir()
end)

essai("missions (4 b) : une colonne va à un point ; sa tête mène vers le point, les autres se rangent ; ni saut ni Directeur", function()
  local ids = preparer({ "homme_d_armes", "homme_d_armes", "archer" })
  local vers = { x = 0, y = 200, z = 0 }
  verifier(not hommes.tenir(ids[1], "escorte", { activite = "suivre", vers = { x = 1 }, fin = "liberation" }), "point boiteux : refusé")
  verifier(not hommes.tenir(ids[1], "escorte", { activite = "suivre", vers = vers, chef = "henry", fin = "liberation" }),
    "un point et un chef : refusé")
  verifier(not hommes.tenir(ids[1], "escorte", { activite = "garde", vers = vers, fin = "liberation" }), "un point hors d'une colonne : refusé")
  for _, h in ipairs(ids) do
    verifier(hommes.tenir(h, "escorte", { activite = "suivre", lieu = "colonne", vers = vers, formation = "followNPC",
      a_cheval = true, fin = "liberation" }), "tenu vers le point")
  end
  local a1, a2 = hommes.activite_de(ids[1], 10), hommes.activite_de(ids[2], 10)
  egal(a1.chef, nil, "la tête n'a pas de chef")
  egal(a1.position and a1.position.y, 200, "elle va au point")
  verifier(a1.suivi and a1.suivi.vers == true, "elle mène vers le point")
  egal(a2.chef, hommes.fiche(ids[1]).personnage, "le deuxième suit la tête")
  verifier(a2.vers == true and not (a2.suivi and a2.suivi.vers), "le deuxième est de la colonne, sans point à lui")
  -- L'ordre donné à la tête : vers le point.
  local ordre = nil
  for _, o in ipairs(FauxJeu.ordres or {}) do
    if o.identifiant == hommes.fiche(ids[1]).personnage then ordre = o end
  end
  verifier(ordre and ordre.suivi and ordre.suivi.vers == true, "l'ordre de la tête porte le point")
  finir()
end)

-- Vu en jeu le 17/10 : la tenue « bataille » ne porte pas de point ; aucun ordre de marche ne vient écraser l'attaque.
essai("missions : engagés contre une bande postée, nos hommes n'ont aucun point à rejoindre ; seul l'ordre d'attaque compte", function()
  local ids = preparer({ "homme_d_armes" })
  local id = missions.dresser_un_camp("gue", "petit")
  FauxJeu.position_joueur = { x = 0, y = -100, z = 0 }
  battre()
  local f = hommes.fiche(ids[1])
  FauxJeu.positions[f.personnage] = { x = 0, y = 170, z = 0 }
  FauxJeu.ordres = {}
  battre()
  egal(la_bande(id).etat, "au_contact", "l'alerte")
  egal(hommes.qui_tient(ids[1]), "bataille", "tenu par la bataille")
  egal(hommes.activite_de(ids[1], 10).position, nil, "sans point")
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == f.personnage then
      egal(o.position, nil, "l'ordre de la tenue : sans point (aucune marche)")
    end
  end
  finir()
end)

-- ---------------------------------------------------------------- tranche 2 : la mission

local function preparer_la_mission(roles)
  local ids = preparer(roles or { "homme_d_armes", "homme_d_armes", "archer" })
  for i, id in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(id).personnage] = { x = i, y = 0, z = 0 }
  end
  return ids
end

essai("missions (4 b) : prendre une mission ; refus : repos (accroche), lieu, hommes, chef hors colonne ; le niveau selon la force", function()
  local ids = preparer_la_mission()
  local ancienne = missions.peut_partir
  missions.peut_partir = function() return false, "jour_de_repos" end
  local id, raison = missions.prendre_une_mission({ lieu = "gue", hommes = ids })
  verifier(not id and raison == "ne_peut_partir", "le jour de repos : refusée")
  missions.peut_partir = ancienne
  verifier(not missions.prendre_une_mission({ lieu = "nulle_part", hommes = ids }), "lieu inconnu")
  verifier(not missions.prendre_une_mission({ lieu = "gue", hommes = {} }), "sans hommes")
  verifier(not missions.prendre_une_mission({ lieu = "gue", hommes = { "personne" } }), "un homme inconnu")
  verifier(not missions.prendre_une_mission({ lieu = "gue", hommes = { ids[1] }, chef = ids[2] }), "chef hors colonne")
  egal(missions.niveau_pour(0, "gue"), "petit", "sans force : le plus petit")
  egal(missions.niveau_pour(1000, "gue"), "grand", "une grande force : le plus grand")
  id = missions.prendre_une_mission({ lieu = "gue", hommes = ids, chef = ids[3] })
  verifier(id, "partie")
  local m = missions.mission(id)
  egal(m.etat, "aller", "à l'aller")
  egal(m.chef, ids[3], "son chef")
  egal(#missions.camps(), 1, "le camp de bandits dressé au lieu")
  for _, h in ipairs(ids) do
    egal(hommes.qui_tient(h), "mission", "tenu par la mission")
  end
  local a3, a1 = hommes.activite_de(ids[3], 10), hommes.activite_de(ids[1], 10)
  verifier(a3.suivi and a3.suivi.vers == true, "le chef mène vers le lieu")
  egal(a1.chef, hommes.fiche(ids[3]).personnage, "le premier homme suit le chef")
  verifier(not missions.prendre_une_mission({ lieu = "gue", hommes = ids }), "les mêmes hommes : déjà pris")
  finir()
end)

essai("missions (4 b) : loin d'Henry, dehors ; l'issue au loin à l'heure d'arrivée ; renaît sur le chemin, rentre, rapport une fois", function()
  local ids = preparer_la_mission()
  missions.ajouter_un_lieu("loin", "trosky", { x = 0, y = 1200, z = 0 }, 0)
  local rapports = {}
  local ancienne = missions.rapport_de_mission
  missions.rapport_de_mission = function(r) table.insert(rapports, r) return ancienne(r) end
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
  local id = missions.prendre_une_mission({ lieu = "loin", hommes = ids })
  battre()
  egal(missions.mission(id).etat, "aller", "près d'Henry : dans le monde")
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 400, z = 0 }
  end
  FauxJeu.vue_d_henry = function() return true end
  battre()
  egal(missions.mission(id).etat, "aller", "à 400 m mais dans son regard : pas encore dehors")
  local henry = FauxJeu.position_joueur
  FauxJeu.position_joueur = nil
  FauxJeu.vue_d_henry = function() return false end
  battre()
  egal(missions.mission(id).etat, "aller", "Henry illisible : personne n'est retiré du monde")
  FauxJeu.position_joueur = henry
  local renvoyes = #FauxJeu.personnages_renvoyes
  battre()
  egal(missions.mission(id).etat, "dehors_aller", "à 400 m, hors de son regard : dehors")
  for _, h in ipairs(ids) do
    verifier(hommes.est_dehors(h), "dehors")
    egal(hommes.fiche(h).personnage, nil, "son personnage retiré")
  end
  verifier(#FauxJeu.personnages_renvoyes > renvoyes, "retirés du monde")
  local _, manquants = hommes.redresser()
  egal(manquants, 0, "le redressement ne les refait pas")
  local avant, _ = bataille.combattants()
  egal(#avant, 0, "ils ne défendent pas le camp")
  FauxJeu.heure = 10 + 0.05
  battre()
  egal(missions.mission(id).etat, "dehors_aller", "pas encore au lieu (1 200 m à 12 km/h : 0,1 h)")
  local solde = coffre.solde()
  FauxJeu.heure = 10 + 0.11
  battre()
  egal(missions.mission(id).etat, "dehors_retour", "au lieu : l'issue calculée")
  verifier(missions.mission(id).issue ~= nil, "une issue")
  egal(bataille.bande(missions.camp(missions.mission(id).camp).bande).etat, "finie", "la bande du camp tranchée")
  FauxJeu.heure = 10 + 0.25
  battre()
  local m = missions.mission(id)
  egal(m.etat, "retour", "de retour : il renaît")
  for _, h in ipairs(m.hommes) do
    verifier(not hommes.est_dehors(h) and hommes.fiche(h).personnage ~= nil, "rentré dans le monde")
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = -2, z = 0 }
  end
  battre()
  egal(#missions.en_cours(), 1, "de l'autre côté du feu, à 17 m du bord : pas encore rentrée (on ne vise pas le milieu du camp)")
  for _, h in ipairs(m.hommes) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 14, z = 0 }
  end
  battre()
  egal(#missions.en_cours(), 0, "au bord du camp, côté du lieu : rentrée, finie")
  egal(#rapports, 1, "un rapport")
  egal(rapports[1].lieu, "loin", "du bon lieu")
  for _, h in ipairs(m.hommes) do
    verifier(hommes.qui_tient(h) ~= "mission", "lâché par la mission")
  end
  battre()
  egal(#rapports, 1, "une seule fois")
  missions.rapport_de_mission = ancienne
  finir()
end)

essai("missions (4 b) : avec Henry près du lieu, le combat sur place ; vaincu, la colonne rentre à cheval", function()
  local ids = preparer_la_mission()
  local id = missions.mission(missions.prendre_une_mission({ lieu = "gue", hommes = ids })).id
  FauxJeu.position_joueur = { x = 0, y = 100, z = 0 }
  battre()
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 180, z = 0 }
  end
  battre()
  local c = missions.camp(missions.mission(id).camp)
  egal(bataille.bande(c.bande).etat, "au_contact", "au lieu : le combat")
  for _, e in ipairs(bataille.bande(c.bande).personnages) do
    FauxJeu.ennemis_vivants_par_id[e] = nil
  end
  battre()
  battre()
  local m = missions.mission(id)
  egal(m.etat, "retour", "vaincu : retour")
  egal(m.issue, "victoire", "victoire")
  verifier(hommes.activite_de(ids[1], 10).suivi.vers == true, "la colonne mène vers le camp")
  finir()
end)

essai("missions : le registre ne garde que les derniers camps levés (« gardes »)", function()
  preparer()
  missions.reglages.gardes = 2
  local debout = missions.dresser_un_camp("gue", "petit")
  for k = 1, 4 do
    missions.ajouter_un_lieu("l" .. k, "trosky", { x = 0, y = 200 + k * 50, z = 0 }, 0)
    missions.lever_un_camp(missions.dresser_un_camp("l" .. k, "petit"))
  end
  battre()
  local gardes = 0
  for k = 1, 4 do
    if missions.camp("camp_de_bandits_" .. (k + 1)) then gardes = gardes + 1 end
  end
  egal(gardes, 2, "deux camps levés gardés")
  verifier(missions.camp("camp_de_bandits_5") ~= nil, "les plus récents")
  verifier(missions.camp(debout) ~= nil, "le camp debout, le plus ancien, jamais retiré")
  missions.reglages.gardes = 20
  finir()
end)

essai("missions (4 b) : sous les yeux d'Henry est borné : regardée à 600 m, la colonne passe dehors", function()
  local ids = preparer_la_mission()
  missions.ajouter_un_lieu("loin", "trosky", { x = 0, y = 1200, z = 0 }, 0)
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
  local id = missions.prendre_une_mission({ lieu = "loin", hommes = ids })
  FauxJeu.vue_d_henry = function() return true end
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 450, z = 0 }
  end
  battre()
  egal(missions.mission(id).etat, "aller", "à 450 m dans son regard : non")
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 600, z = 0 }
  end
  battre()
  egal(missions.mission(id).etat, "dehors_aller", "à 600 m, même regardée : dehors")
  finir()
end)

-- Vu en jeu le 17/10 : un combat au camp de bandits figé loin d'Henry (plus personne ne tombe) est tranché par passes.
essai("missions : un combat figé au camp de bandits, Henry pas sur place, est tranché par passes ; Henry sur place, jamais", function()
  local ids = preparer({ "homme_d_armes", "homme_d_armes" })
  local id = missions.dresser_un_camp("gue", "petit")
  FauxJeu.position_joueur = { x = 0, y = 60, z = 0 }       -- à 140 m du lieu
  battre()
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 180, z = 0 }
  end
  battre()
  egal(la_bande(id).etat, "au_contact", "au contact")
  FauxJeu.heure = 10.3
  battre()
  egal(la_bande(id).etat, "au_contact", "0,3 h sans tombé : on attend")
  FauxJeu.position_joueur = { x = 0, y = 150, z = 0 }      -- Henry sur place (50 m)
  FauxJeu.heure = 10.9
  battre()
  egal(la_bande(id).etat, "au_contact", "Henry sur place : le vrai combat, rien de calculé")
  FauxJeu.position_joueur = { x = 0, y = 60, z = 0 }
  FauxJeu.heure = 11
  battre()
  egal(la_bande(id).etat, "finie", "figé, Henry loin : tranché par passes")
  finir()
end)

-- Vu sur une copie de la partie de JoVenGer le 21/10 (J3, mission_1 : nos deux combattants assommés, Henry au camp) :
-- la bataille se concluait « 0 passe, 0 mort, 0 blessé » et nos tombés restaient tenus « bataille », sans plus d'ordre.
essai("missions (21/10) : plus aucun des nôtres debout, Henry pas sur place : défaite aussitôt, nos assommés blessés et libérés ; tranchée par passes, nos tombés comptent", function()
  local ids = preparer({ "homme_d_armes", "homme_d_armes" })
  local id = missions.dresser_un_camp("gue", "petit")
  FauxJeu.position_joueur = { x = 0, y = 60, z = 0 }       -- à 140 m du lieu : ni sur place, ni enfui
  battre()
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 180, z = 0 }
  end
  battre()
  egal(la_bande(id).etat, "au_contact", "au contact")
  FauxJeu.inconscients = {}
  for _, h in ipairs(ids) do
    FauxJeu.inconscients[hommes.fiche(h).personnage] = true
  end
  FauxJeu.heure = 10.05
  battre()
  egal(la_bande(id).etat, "finie", "plus personne debout, Henry pas sur place : conclue sans attendre")
  local dit = false
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, "plus aucun des nôtres debout", 1, true) then dit = true end
  end
  verifier(dit, "dit au journal")
  for _, h in ipairs(ids) do
    verifier(hommes.fiche(h).blessure > 0, "l'assommé est blessé")
    verifier(hommes.qui_tient(h) ~= "bataille", "l'assommé n'est plus tenu par la bataille")
  end
  finir()
  -- Un debout, un assommé, figé : tranchée par passes ; l'assommé compte (blessé) et est libéré.
  ids = preparer({ "homme_d_armes", "homme_d_armes" })
  id = missions.dresser_un_camp("gue", "petit")
  FauxJeu.position_joueur = { x = 0, y = 60, z = 0 }
  battre()
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 180, z = 0 }
  end
  battre()
  FauxJeu.inconscients = { [hommes.fiche(ids[2]).personnage] = true }
  battre()
  FauxJeu.heure = 11
  battre()
  egal(la_bande(id).etat, "finie", "figé, Henry loin : tranché par passes")
  local f2 = hommes.fiche(ids[2])
  verifier(f2 == nil or f2.blessure > 0, "l'assommé compte : blessé (ou mort)")
  verifier(f2 == nil or hommes.qui_tient(ids[2]) ~= "bataille", "l'assommé libéré")
  finir()
end)

-- Relecture du pair (17/10) : tranchée sous les yeux d'Henry, l'issue s'applique aux vrais personnages ; rien ne
-- disparaît sous ses yeux.
essai("missions : tranchée, l'issue s'applique aux vrais personnages ; survivants et camp retirés seulement hors de la vue d'Henry", function()
  local ids = preparer({ "homme_d_armes", "homme_d_armes", "archer" })
  local id = missions.dresser_un_camp("gue", "petit")
  FauxJeu.position_joueur = { x = 0, y = 60, z = 0 }
  battre()
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 180, z = 0 }
  end
  battre()
  -- Des passes écrites d'avance : deux bandits tombent, puis nos trois hommes (le premier mort, les autres blessés).
  local ancienne, part = bataille.issue_au_loin, bataille.reglages.part_des_morts
  bataille.issue_au_loin = function(nous)
    return { gagne = false, tombes = { nous[1], nous[2], nous[3] }, debout = {}, eux_tombes = 2, eux_debout = 2, passes = 5 }
  end
  battre()   -- le premier relevé du combat (le filet compte depuis le dernier changement vu)
  for _, e in ipairs(la_bande(id).personnages) do
    FauxJeu.positions[e] = { x = 0, y = 200, z = 0 }
  end
  FauxJeu.vue_d_henry = function() return true end
  FauxJeu.coups, FauxJeu.a_terre = {}, {}
  local premier = hommes.fiche(ids[1]).personnage
  FauxJeu.heure = 11
  battre()
  egal(la_bande(id).etat, "finie", "figée, tranchée par passes")
  local tues = 0
  for _, c in ipairs(FauxJeu.coups) do
    if c.points >= 1000 then tues = tues + 1 end
  end
  verifier(tues >= 2, "les deux bandits tombés tués dans le jeu (et nos morts)")
  egal(#FauxJeu.a_terre + (tues - 2), 3, "chacun des nôtres tombé : tué ou mis à terre")
  local renvoyes = #FauxJeu.ennemis_renvoyes
  battre()
  egal(#FauxJeu.ennemis_renvoyes, renvoyes, "Henry regarde : les deux survivants restent debout")
  FauxJeu.vue_d_henry = function() return false end
  battre()
  egal(#FauxJeu.ennemis_renvoyes, renvoyes + 2, "il se détourne : les survivants retirés")
  FauxJeu.vue_d_henry = function() return true end
  FauxJeu.heure = 11 + missions.reglages.camp_vaincu_reste_h + 1
  battre()
  verifier(#missions.camps() == 1, "le camp n'est pas levé sous ses yeux")
  FauxJeu.vue_d_henry = function() return false end
  battre()
  egal(#missions.camps(), 0, "levé hors de sa vue")
  bataille.issue_au_loin, bataille.reglages.part_des_morts = ancienne, part
  finir()
end)

-- Vu en jeu le 17/10 : au retour, le point de la colonne change ; l'ordre de la tête doit être redonné.
essai("missions (4 b) : le point de la colonne changé redonne l'ordre à sa tête", function()
  local ids = preparer_la_mission()
  for _, h in ipairs(ids) do
    hommes.tenir(h, "mission", { activite = "suivre", lieu = "colonne", vers = { x = 0, y = 200, z = 0 }, a_cheval = true,
      formation = "followNPC", fin = "liberation" })
  end
  local tete = hommes.fiche(ids[1]).personnage
  FauxJeu.ordres = {}
  hommes.tenir(ids[1], "mission", { activite = "suivre", lieu = "colonne", vers = { x = 0, y = 15, z = 0 }, a_cheval = true,
    formation = "followNPC", fin = "liberation" })
  local vers_le_camp = nil
  for _, o in ipairs(FauxJeu.ordres) do
    if o.identifiant == tete and o.position and o.position.y == 15 then vers_le_camp = o end
  end
  verifier(vers_le_camp ~= nil, "la tête reçoit l'ordre vers le nouveau point")
  finir()
end)

-- Vu en jeu le 17/10 : Jan, assommé au combat, tête de la colonne, ne remontait pas à cheval ; la colonne l'attendait.
essai("missions (4 b) : au retour, un homme hors d'état est porté ; la tête passe au premier debout ; personne debout : retour au loin", function()
  local ids = preparer_la_mission()
  local id = missions.prendre_une_mission({ lieu = "gue", hommes = ids, chef = ids[1] })
  FauxJeu.position_joueur = { x = 0, y = 100, z = 0 }
  battre()
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 180, z = 0 }
  end
  battre()
  local c = missions.camp(missions.mission(id).camp)
  for _, e in ipairs(bataille.bande(c.bande).personnages) do
    FauxJeu.ennemis_vivants_par_id[e] = nil
  end
  FauxJeu.inconscients = { [hommes.fiche(ids[1]).personnage] = true }
  FauxJeu.vue_d_henry = function() return true end
  battre()
  battre()
  egal(missions.mission(id).etat, "retour", "vaincu : retour")
  egal(hommes.activite_de(ids[2], 10).suivi.vers, true, "le chef assommé : le deuxième mène")
  verifier(not hommes.est_dehors(ids[1]), "sous les yeux d'Henry : l'assommé reste là")
  FauxJeu.vue_d_henry = function() return false end
  battre()
  verifier(hommes.est_dehors(ids[1]), "hors de sa vue : porté (dehors)")
  -- Les deux autres arrivent au bord du camp : la mission finit, le porté rentre.
  for k = 2, 3 do
    FauxJeu.positions[hommes.fiche(ids[k]).personnage] = { x = 0, y = 14, z = 0 }
  end
  battre()
  egal(#missions.en_cours(), 0, "rentrée")
  verifier(not hommes.est_dehors(ids[1]) and hommes.fiche(ids[1]).personnage ~= nil, "le porté rentré au camp")
  -- Tous hors d'état : la colonne rentre au loin.
  FauxJeu.inconscients = nil
  finir()
end)

essai("missions (4 b) : tous hors d'état au retour : la colonne entière rentre au loin, puis renaît au bord du camp", function()
  local ids = preparer_la_mission()
  local id = missions.prendre_une_mission({ lieu = "gue", hommes = ids })
  FauxJeu.position_joueur = { x = 0, y = 100, z = 0 }
  battre()
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 180, z = 0 }
  end
  battre()
  local c = missions.camp(missions.mission(id).camp)
  for _, e in ipairs(bataille.bande(c.bande).personnages) do
    FauxJeu.ennemis_vivants_par_id[e] = nil
  end
  FauxJeu.inconscients = {}
  for _, h in ipairs(ids) do FauxJeu.inconscients[hommes.fiche(h).personnage] = true end
  FauxJeu.vue_d_henry = function() return false end
  battre()
  battre()
  battre()
  egal(missions.mission(id).etat, "dehors_retour", "personne debout : rentre au loin")
  FauxJeu.inconscients = nil
  -- Vu sur une copie le 21/10 (J3) : chacun renaît au sol de sa place, pas à la hauteur du centre du camp.
  FauxJeu.terrain = function() return 7 end
  local nes_avant = #FauxJeu.personnages
  FauxJeu.heure = 13
  battre()
  egal(missions.mission(id).etat, "retour", "renaît au bord du camp")
  verifier(#FauxJeu.personnages > nes_avant, "des personnages refaits")
  for i = nes_avant + 1, #FauxJeu.personnages do
    egal(FauxJeu.personnages[i].position.z, 7, "renaît au sol")
  end
  FauxJeu.terrain = nil
  finir()
end)

-- ---------------------------------------------------------------- tranche 3 : plusieurs missions, lieux réservés

essai("missions (tranche 3) : deux missions à la fois, chacune son lieu ; un lieu pris n'est donné à personne ; l'accroche de réservation", function()
  local ids = preparer({ "homme_d_armes", "homme_d_armes", "archer", "archer" })
  missions.ajouter_un_lieu("moulin", "trosky", { x = 300, y = 0, z = 0 }, 0)
  missions.ajouter_un_lieu("autre_carte", "kuttenberg", { x = 0, y = 0, z = 0 }, 0)
  egal(missions.choisir_un_lieu("trosky"), "gue", "un lieu libre : le premier par nom")
  local m1 = missions.prendre_une_mission({ lieu = "gue", hommes = { ids[1], ids[2] } })
  verifier(m1, "la première part")
  egal(missions.lieu_reserve("gue") ~= nil, true, "le gué est réservé")
  egal(missions.choisir_un_lieu("trosky"), "moulin", "le lieu libre suivant")
  local refus, raison = missions.prendre_une_mission({ lieu = "gue", hommes = { ids[3] } })
  verifier(not refus and raison == "camp_refuse", "le gué pris : refusé pour une autre mission")
  local m2 = missions.prendre_une_mission({ lieu = "moulin", hommes = { ids[3], ids[4] } })
  verifier(m2, "la seconde part, en même temps")
  egal(#missions.en_cours(), 2, "deux missions en cours")
  egal(missions.choisir_un_lieu("trosky"), nil, "plus de lieu libre sur Trosky")
  -- Scriptorium enveloppe la réservation (ses propres missions en parallèle).
  local ancienne = missions.lieu_reserve
  missions.lieu_reserve = function(nom) if nom == "autre_carte" then return "mission_de_scriptorium" end return ancienne(nom) end
  egal(missions.choisir_un_lieu("kuttenberg"), nil, "réservé par Scriptorium : pas donné")
  verifier(not missions.dresser_un_camp("autre_carte", "petit"), "ni dressé")
  missions.lieu_reserve = ancienne
  finir()
end)

-- La liste du pair (17/10) : les personnages d'un camp de bandits connus de Scriptorium, qui en ajoute et en retire.
essai("missions : Scriptorium ajoute et retire des personnages d'un camp de bandits ; ils entrent dans sa bande", function()
  preparer()
  local id = missions.dresser_un_camp("gue", "petit")
  battre()
  egal(#missions.personnages_du_camp(id), 4, "les quatre nés")
  FauxJeu.personnages_existants["chef_de_scriptorium"] = true
  FauxJeu.ennemis_vivants_par_id["chef_de_scriptorium"] = true
  verifier(missions.ajouter_un_personnage(id, "chef_de_scriptorium"), "ajouté")
  verifier(not missions.ajouter_un_personnage(id, "chef_de_scriptorium"), "pas deux fois")
  verifier(not missions.ajouter_un_personnage(id, "inconnu"), "un personnage qui n'existe pas : refusé")
  egal(#missions.personnages_du_camp(id), 5, "cinq dans la bande")
  -- Il est visé et compté debout : tous les autres tombés, la bande tient encore.
  for _, e in ipairs(missions.personnages_du_camp(id)) do
    if e ~= "chef_de_scriptorium" then FauxJeu.ennemis_vivants_par_id[e] = nil end
  end
  FauxJeu.position_joueur = { x = 0, y = 190, z = 0 }
  battre()
  battre()
  egal(la_bande(id).etat, "au_contact", "le chef ajouté tient encore la bande")
  verifier(missions.retirer_un_personnage(id, "chef_de_scriptorium"), "retiré")
  egal(#missions.personnages_du_camp(id), 4, "quatre")
  battre()
  egal(la_bande(id).etat, "finie", "plus personne debout dans la bande : finie")
  finir()
end)

-- ---------------------------------------------------------------- tranche 4 : les convois

local ROUTE = { { x = 0, y = 400, z = 0 }, { x = 400, y = 400, z = 0 }, { x = 400, y = 800, z = 0 } }

essai("missions (convois) : une route fournie par Scriptorium ; un convoi par route ; il avance à pied et sa bande le suit", function()
  preparer()
  verifier(not missions.ajouter_une_route("courte", "trosky", { { x = 0, y = 0, z = 0 } }), "un seul point : refusé")
  verifier(not missions.ajouter_une_route("boiteuse", "trosky", { { x = 0, y = 0 }, { x = 1, y = 1, z = 0 } }), "un point sans hauteur : refusé")
  verifier(missions.ajouter_une_route("vallee", "trosky", ROUTE), "la route")
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
  local id = missions.lancer_un_convoi("vallee", "petit")
  battre()
  egal(#bataille.bande(missions.convoi(id).bande).personnages, 0, "à 400 m d'Henry : pas dans le monde")
  FauxJeu.position_joueur = { x = 0, y = 150, z = 0 }
  verifier(id, "parti")
  verifier(not missions.lancer_un_convoi("vallee", "petit"), "un seul convoi par route")
  battre()
  local cv = missions.convoi(id)
  egal(cv.position.x, 0, "au départ")
  local bande = bataille.bande(cv.bande)
  egal(#bande.personnages, 4, "sa bande née (hors du regard d'Henry)")
  FauxJeu.ordres = {}
  FauxJeu.heure = 10.05      -- 0,05 h à 4 km/h : 200 m
  battre()
  cv = missions.convoi(id)
  verifier(math.abs(cv.position.x - 200) < 0.01 and math.abs(cv.position.y - 400) < 0.01, "200 m le long de la route, sur le premier tronçon")
  local en_marche = 0
  for _, o in ipairs(FauxJeu.ordres) do
    if o.activite == "convoi" then en_marche = en_marche + 1 end
  end
  egal(en_marche, 4, "ses quatre hommes marchent vers son point")
  finir()
end)

essai("missions (convois) : loin d'Henry, retiré du monde ; au bout de sa route, arrivé ; une bande au combat ne marche plus", function()
  preparer()
  missions.ajouter_une_route("vallee", "trosky", ROUTE)
  FauxJeu.position_joueur = { x = 0, y = 150, z = 0 }
  local id = missions.lancer_un_convoi("vallee", "petit")
  battre()
  egal(#bataille.bande(missions.convoi(id).bande).personnages, 4, "à 250 m : né")
  FauxJeu.heure = 10.1        -- 400 m : au coude, à plus de 400 m d'Henry
  local renvoyes = #FauxJeu.ennemis_renvoyes
  battre()
  egal(#FauxJeu.ennemis_renvoyes - renvoyes, 4, "à plus de 300 m d'Henry : retiré du monde")
  egal(#bataille.bande(missions.convoi(id).bande).personnages, 0, "sans personnage")
  FauxJeu.heure = 10.3        -- 1 200 m : au-delà du bout (800 m)
  battre()
  egal(missions.convoi(id).etat, "arrive", "arrivé au bout de sa route")
  egal(#missions.convois(), 0, "plus de convoi en route")
  -- Un convoi dont la bande est au contact ne marche plus.
  local id2 = missions.lancer_un_convoi("vallee", "petit")
  FauxJeu.position_joueur = { x = 0, y = 380, z = 0 }
  battre()
  battre()
  egal(bataille.bande(missions.convoi(id2).bande).etat, "au_contact", "Henry à 20 m : l'alerte")
  local avant = missions.convoi(id2).parcouru
  FauxJeu.heure = 10.6
  battre()
  egal(missions.convoi(id2).parcouru, avant, "au combat : il n'avance plus")
  finir()
end)

essai("missions (convois) : une mission contre un convoi ; au loin, l'heure de la prise se calcule contre sa marche ; échappé s'il arrive avant", function()
  local ids = preparer_la_mission()
  missions.ajouter_une_route("vallee", "trosky", ROUTE)
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
  local cv = missions.lancer_un_convoi("vallee", "petit")
  local vitesse = missions.reglages.vitesse_m_par_h
  missions.reglages.vitesse_m_par_h = 3000
  verifier(not missions.prendre_une_mission({ convoi = cv, hommes = ids }), "une colonne pas plus rapide : refusée")
  missions.reglages.vitesse_m_par_h = vitesse
  local id = missions.prendre_une_mission({ convoi = cv, hommes = ids })
  verifier(id, "partie contre le convoi")
  battre()
  for _, h in ipairs(ids) do
    FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 350, z = 0 }
  end
  FauxJeu.vue_d_henry = function() return false end
  battre()
  local m = missions.mission(id)
  egal(m.etat, "dehors_aller", "dehors")
  FauxJeu.heure = 10.2
  battre()
  verifier(missions.mission(id).etat ~= "aller", "la prise tranchée au loin")
  egal(bataille.bande(missions.convoi(cv).bande).etat, "finie", "la bande du convoi tranchée")
  finir()
  -- Échappé : le convoi arrive au bout avant la colonne.
  ids = preparer_la_mission()
  missions.ajouter_une_route("courte", "trosky", { { x = 0, y = 400, z = 0 }, { x = 0, y = 420, z = 0 } })
  FauxJeu.position_joueur = { x = 0, y = 0, z = 0 }
  cv = missions.lancer_un_convoi("courte", "petit")
  id = missions.prendre_une_mission({ convoi = cv, hommes = ids })
  FauxJeu.heure = 10.1
  battre()
  battre()
  egal(missions.convoi(cv).etat, "arrive", "le convoi au bout")
  egal(missions.mission(id).issue, "echappe", "la mission : échappé")
  finir()
end)

-- ---------------------------------------------------------------- fiche 18, 5 d : les sorties à cheval

essai("sorties (5 d) : un cuisinier sort à cheval à un point, y reste, rentre ; sans camp de bandits ; rapport « faite »", function()
  local ids = preparer_la_mission({ "cuisinier", "forgeron" })
  local rapports = {}
  avec_remplacement(missions, "rapport_de_mission", function(r) table.insert(rapports, r) end, function()
    verifier(not missions.sortir({ hommes = ids, point = { x = 1 } , duree_h = 1 }), "point boiteux : refusée")
    verifier(not missions.sortir({ hommes = ids, lieu = "gue", duree_h = -1 }), "durée boiteuse : refusée")
    local id = missions.sortir({ hommes = ids, point = { x = 0, y = 60, z = 0 }, duree_h = 1, motif = "bois" })
    verifier(id, "partie")
    egal(#missions.camps(), 0, "aucun camp de bandits")
    -- Vu sur une copie le 21/10 (J4) : dans le camp réel, aucun cheval : ils en sortent à pied ; dehors, le cheval naît.
    local a = hommes.activite_de(ids[1], FauxJeu.heure)
    verifier(not (a.suivi and a.suivi.mode == "cheval"), "dans le camp : à pied")
    for _, h in ipairs(ids) do
      FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 40, z = 0 }
    end
    hommes.battre()
    a = hommes.activite_de(ids[1], FauxJeu.heure)
    verifier(a.suivi and a.suivi.mode == "cheval", "dehors : à cheval")
    battre()
    egal(missions.mission(id).etat, "aller", "en route")
    FauxJeu.positions[hommes.fiche(ids[1]).personnage] = { x = 0, y = 58, z = 0 }
    battre()
    egal(missions.mission(id).etat, "sur_place", "arrivée")
    FauxJeu.heure = FauxJeu.heure + 0.5
    battre()
    egal(missions.mission(id).etat, "sur_place", "elle y reste")
    FauxJeu.heure = FauxJeu.heure + 0.6
    battre()
    egal(missions.mission(id).etat, "retour", "le temps passé : retour")
    local retour = hommes.activite_de(ids[1], FauxJeu.heure)
    verifier(retour.suivi and retour.suivi.mode == "cheval", "rentre à cheval")
    for _, h in ipairs(ids) do
      FauxJeu.positions[hommes.fiche(h).personnage] = { x = 0, y = 10, z = 0 }
    end
    battre()
    egal(missions.mission(id).etat, "finie", "rentrée")
    egal(#rapports, 1, "un rapport")
    egal(rapports[1] and rapports[1].issue, "faite", "issue « faite »")
    egal(hommes.qui_tient(ids[1]) == "mission", false, "lâchés")
  end)
  finir()
end)

essai("sorties (5 d) : loin d'Henry, dehors ; aller, séjour et retour calculés ; renaît sur le chemin du camp", function()
  local ids = preparer_la_mission({ "forgeron" })
  missions.ajouter_un_lieu("ville", "trosky", { x = 0, y = 2000, z = 0 }, 0)
  FauxJeu.position_joueur = { x = 0, y = -1000, z = 0 }
  local id = missions.sortir({ hommes = ids, lieu = "ville", duree_h = 2 })
  verifier(id, "partie")
  battre()
  egal(missions.mission(id).etat, "dehors_aller", "loin d'Henry : dehors")
  verifier(hommes.est_dehors(ids[1]), "hors du monde")
  FauxJeu.heure = FauxJeu.heure + 2000 / missions.reglages.vitesse_m_par_h + 0.01
  battre()
  egal(missions.mission(id).etat, "dehors_retour", "au lieu, au loin")
  FauxJeu.heure = FauxJeu.heure + 2 + 2000 / missions.reglages.vitesse_m_par_h + 0.01
  FauxJeu.vue_d_henry = function() return false end
  battre()
  egal(missions.mission(id).etat, "retour", "renaît sur le chemin")
  verifier(not hommes.est_dehors(ids[1]), "dans le monde")
  finir()
end)

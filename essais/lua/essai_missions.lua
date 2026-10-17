-- Essais des missions, tranche 1 : le camp de bandits à un lieu (fiche 17).

local missions = Scriptorium.missions
local bataille = Scriptorium.bataille
local hommes = Scriptorium.hommes
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre

local LIEU = { x = 0, y = 200, z = 0 }

local function preparer(roles)
  depart()
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
    if o.nom == "scriptorium_bandits_" .. id .. "_feu" then feu = o.identifiant end
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

essai("missions (4 b) : une colonne prend le feu d'un camp de bandits pour chef ; le premier mène à cheval, les autres se rangent", function()
  local ids = preparer({ "homme_d_armes", "homme_d_armes", "archer" })
  local id = missions.dresser_un_camp("gue", "petit")
  local jalon = missions.jalon_du_camp(id)
  verifier(jalon, "le feu du camp sert de jalon")
  verifier(not hommes.tenir(ids[1], "escorte", { activite = "suivre", chef = "scriptorium_rien", fin = "liberation" }),
    "un jalon qui n'existe pas : refusé")
  for _, h in ipairs(ids) do
    verifier(hommes.tenir(h, "escorte", { activite = "suivre", lieu = "colonne", chef = jalon, formation = "followNPC",
      a_cheval = true, fin = "liberation" }), "tenu vers le jalon")
  end
  local a1, a2 = hommes.activite_de(ids[1], 10), hommes.activite_de(ids[2], 10)
  egal(a1.chef, jalon, "le premier suit le jalon")
  egal(a1.suivi and a1.suivi.role or (a1.suivi and a1.suivi.mode), "mener", "et mène")
  egal(a2.chef, hommes.fiche(ids[1]).personnage, "le deuxième suit le premier")
  missions.lever_un_camp(id)
  egal(hommes.activite_de(ids[1], 10).chef, "henry", "le jalon retiré : plus de chef lu (Henry par défaut)")
  finir()
end)

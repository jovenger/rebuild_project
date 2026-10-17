-- Faux jeu pour les essais : remplace Scriptorium.jeu (la liaison réelle n'est pas chargée).
-- Tout ce que le socle demande au jeu est noté ici, pour être vérifié par les essais.

local faux = {
  temps = 0,
  affichages = {},      -- { texte, duree, temps }
  en_ecran = nil,
  journal_lignes = {},
  dialogue = false,
  registre_stocke = nil,
  minuteries = {},      -- { ms, fonction }
  commandes = {},       -- { nom, code, aide }
  bourse_henry = 0,     -- groschen dans la bourse d'Henry
  heure = 0,            -- heure du jeu, en heures
  appels_retirer = 0,   -- fois où le socle a demandé à retirer des groschen à Henry
  donner_en_panne = false,
  objets_poses = {},      -- { identifiant, sorte, modele, position, cap, nom }
  objets_retires = {},    -- identifiants
  objets_existants = {},  -- identifiant -> true
  objets_du_jeu = {},     -- { identifiant, nom, position, cap, proprietes } : places posées sur les meubles
  prochain_objet = 1,
  refuser_pose = {},      -- nom -> true : le jeu refuse de poser cet objet
  position_joueur = { x = 0, y = 0, z = 0 },
  cap_joueur = 0,
  personnages = {},            -- { identifiant, ame, nom, position }
  tailles_paliers = nil,       -- réserves d'âmes : reserve -> { taille par palier } (remises à zéro ci-dessous)
  personnages_existants = {},  -- identifiant -> true
  personnages_renvoyes = {},
  prochain_personnage = 1,
  refuser_personnage = false,
  ordres = {},                 -- { identifiant, activite, position, lieu }
  ennemis = {},                -- { identifiant, sorte, position, cap }
  ennemis_vivants_par_id = {}, -- identifiant -> true/false
  ennemis_renvoyes = {},
  corps_couches = {},          -- identifiants des morts couchés en corps inertes
  prochain_ennemi = 1,
  refuser_ennemis = false,
  personnages_morts = {},      -- identifiant -> true
  directeurs = {},             -- { identifiant, position }
  refuser_directeur = false,
  ordres_porte = {},           -- { identifiant, etat }
  partie = true,               -- une partie est en cours
  fichier_ordres = nil,        -- table rendue par le fichier d'ordres, ou nil s'il n'y en a pas
  fichier_ordres_raison = nil, -- raison quand le fichier est illisible
  lectures_ordres = 0,
  fichier_reglages = nil,        -- table rendue par le fichier de réglages, ou nil s'il n'y en a pas
  fichier_reglages_raison = nil, -- raison quand le fichier est illisible
  lectures_reglages = 0,
  ecoute_partie = nil,         -- { entree, sortie } : ce que le socle veut qu'on appelle
  feux_allumes = {},           -- identifiant -> true
}

function faux.remettre_a_zero()
  faux.temps = 0
  faux.positions = {}
  faux.vue_d_henry = nil
  faux.secours = {}
  faux.occupations = {}
  faux.variables_du_cerveau = {}
  faux.cerveaux = {}
  faux.ecritures_du_cerveau = 0
  faux.affichages = {}
  faux.en_ecran = nil
  faux.journal_lignes = {}
  faux.dialogue = false
  faux.registre_stocke = nil
  faux.minuteries = {}
  faux.commandes = {}
  faux.bourse_henry = 0
  faux.heure = 0
  faux.appels_retirer = 0
  faux.donner_en_panne = false
  faux.objets_poses = {}
  faux.objets_retires = {}
  faux.objets_existants = {}
  faux.objets_du_jeu = {}
  faux.prochain_objet = 1
  faux.refuser_pose = {}
  faux.position_joueur = { x = 0, y = 0, z = 0 }
  faux.cap_joueur = 0
  faux.personnages = {}
  faux.tailles_paliers = { combattant = { 80, 80, 80 }, metier = { 40 }, femme = { 12 }, directeur = { 1 } }
  faux.personnages_existants = {}
  faux.inventaires = {}
  faux.portes = {}
  faux.equipements = {}
  faux.refuser_objets = false
  faux.personnages_renvoyes = {}
  faux.prochain_personnage = 1
  faux.refuser_personnage = false
  faux.ordres = {}
  faux.ennemis = {}
  faux.ennemis_vivants_par_id = {}
  faux.ennemis_renvoyes = {}
  faux.corps_couches = {}
  faux.prochain_ennemi = 1
  faux.refuser_ennemis = false
  faux.personnages_morts = {}
  faux.directeurs = {}
  faux.refuser_directeur = false
  faux.ordres_porte = {}
  faux.partie = true
  faux.fichier_ordres = nil
  faux.fichier_ordres_raison = nil
  faux.lectures_ordres = 0
  faux.fichier_reglages = nil
  faux.fichier_reglages_raison = nil
  faux.lectures_reglages = 0
  faux.ecoute_partie = nil
  faux.feux_allumes = {}
end

function faux.maintenant() return faux.temps end
function faux.avancer(secondes) faux.temps = faux.temps + secondes end
function faux.journal(texte) table.insert(faux.journal_lignes, tostring(texte)) end
function faux.afficher(texte, duree, complement)
  table.insert(faux.affichages, { texte = texte, duree = duree, temps = faux.temps, complement = complement })
  faux.en_ecran = texte
end
function faux.effacer() faux.en_ecran = nil end
function faux.dialogue_en_cours() return faux.dialogue end
function faux.minuterie(ms, fonction)
  table.insert(faux.minuteries, { ms = ms, fonction = fonction })
  return #faux.minuteries
end
function faux.lire_registre() return faux.registre_stocke end
function faux.ecrire_registre(chaine) faux.registre_stocke = chaine end
function faux.commande(nom, code, aide) table.insert(faux.commandes, { nom = nom, code = code, aide = aide }) end
function faux.lire_ordres()
  faux.lectures_ordres = faux.lectures_ordres + 1
  if faux.fichier_ordres_raison then
    return nil, "faux/ordres.lua", faux.fichier_ordres_raison
  end
  if faux.fichier_ordres then
    return faux.fichier_ordres, "faux/ordres.lua"
  end
  return nil
end
function faux.lire_reglages()
  faux.lectures_reglages = faux.lectures_reglages + 1
  if faux.fichier_reglages_raison then
    return nil, "faux/reglages.lua", faux.fichier_reglages_raison
  end
  if faux.fichier_reglages then
    return faux.fichier_reglages, "faux/reglages.lua"
  end
  return nil
end
function faux.ecouter_la_partie(entree, sortie) faux.ecoute_partie = { entree = entree, sortie = sortie } end
-- Le guetteur du noyau : un chargement qui ne finit pas (faux.chargement), et ce qui entoure Henry.
function faux.chargement_en_cours() return faux.chargement == true end
function faux.voisins_d_henry() return { "Henry (0, 0, 0) ; 0 entité(s)" } end
-- Ce que ferait le jeu : l'événement d'entrée en partie, puis celui de sortie.
function faux.entrer_en_partie()
  faux.partie = true
  faux.ecoute_partie.entree()
end
function faux.sortir_de_partie()
  faux.partie = false
  faux.ecoute_partie.sortie()
end
function faux.heure_du_jeu() return faux.heure end
function faux.groschen_d_henry() return faux.bourse_henry end
function faux.retirer_groschen_a_henry(n)
  faux.appels_retirer = faux.appels_retirer + 1
  if type(n) ~= "number" or n <= 0 or math.floor(n) ~= n then return false end
  if faux.bourse_henry < n then return false end
  faux.bourse_henry = faux.bourse_henry - n
  return true
end
function faux.donner_groschen_a_henry(n)
  if faux.donner_en_panne then return false end
  faux.bourse_henry = faux.bourse_henry + n
  return true
end

function faux.poser_objet(sorte, modele, position, cap, nom, classe)
  if faux.refuser_pose[nom] then return nil end
  local identifiant = "objet_" .. faux.prochain_objet
  faux.prochain_objet = faux.prochain_objet + 1
  table.insert(faux.objets_poses, { identifiant = identifiant, sorte = sorte, modele = modele,
                                    position = position, cap = cap, nom = nom, classe = classe })
  faux.objets_existants[identifiant] = true
  return identifiant
end
function faux.allumer(identifiant)
  faux.feux_allumes[identifiant] = true
  return true
end
function faux.retirer_objet(identifiant)
  table.insert(faux.objets_retires, identifiant)
  faux.objets_existants[identifiant] = nil
end
function faux.objet_existe(identifiant) return faux.objets_existants[identifiant] == true end
function faux.poser_objet_du_jeu(nom, position, cap, proprietes)
  if faux.refuser_pose[nom] then return nil end
  local identifiant = "place_" .. faux.prochain_objet
  faux.prochain_objet = faux.prochain_objet + 1
  table.insert(faux.objets_du_jeu, { identifiant = identifiant, nom = nom, position = position, cap = cap, proprietes = proprietes })
  faux.objets_existants[identifiant] = true
  return identifiant
end
-- Les âmes (fiche 13) : même forme que la liaison, réserve, palier et numéro.
function faux.ame_de(reserve, palier, numero)
  local paliers = faux.tailles_paliers[reserve]
  local taille = paliers and paliers[palier]
  if not taille or numero < 1 or numero > taille then return nil end
  return "ame_" .. reserve .. "_" .. palier .. "_" .. numero
end
function faux.paliers_de(reserve)
  local copie = {}
  for i, n in ipairs(faux.tailles_paliers[reserve] or {}) do copie[i] = n end
  return copie
end
function faux.faire_venir_homme(ame, nom, position)
  if faux.refuser_personnage or ame == nil then return nil end
  local identifiant = "personnage_" .. faux.prochain_personnage
  faux.prochain_personnage = faux.prochain_personnage + 1
  table.insert(faux.personnages, { identifiant = identifiant, ame = ame, nom = nom, position = position })
  faux.personnages_existants[identifiant] = true
  faux.inventaires[identifiant] = { { objet = "naissance_tunique", etat = 0.12, nombre = 1 },
                                    { objet = "naissance_chapel", etat = 0.13, nombre = 1 },
                                    { objet = "bourse", etat = 1, nombre = 30 } }
  return identifiant
end
function faux.personnage_existe(identifiant) return faux.personnages_existants[identifiant] == true end
function faux.renvoyer_homme(identifiant)
  table.insert(faux.personnages_renvoyes, identifiant)
  faux.personnages_existants[identifiant] = nil
end
function faux.ordonner(identifiant, activite, position, lieu, place, sorte, regard, allure, chef, suivi)
  table.insert(faux.ordres, { identifiant = identifiant, activite = activite, position = position, lieu = lieu,
                              place = place, sorte = sorte, regard = regard, allure = allure, chef = chef, suivi = suivi })
end
-- Fiche 15, V73 f 2 a : un cheval né (son identifiant), ou retiré.
-- V73 f 2 b : un cheval né existe et a sa place ; « refuser_les_chevaux » : aucune naissance ; les chevaux retirés.
function faux.faire_venir_cheval(nom, position)
  faux.chevaux = faux.chevaux or {}
  if faux.refuser_les_chevaux then return nil end
  local identifiant = "cheval_" .. nom
  faux.chevaux[identifiant] = position
  faux.objets_existants[identifiant] = true
  faux.positions = faux.positions or {}
  faux.positions[identifiant] = position
  return identifiant
end
function faux.retirer_cheval(identifiant)
  if faux.chevaux then faux.chevaux[identifiant] = nil end
  faux.objets_existants[identifiant] = nil
  if faux.positions then faux.positions[identifiant] = nil end
  faux.chevaux_retires = faux.chevaux_retires or {}
  table.insert(faux.chevaux_retires, identifiant)
end
-- V73 f 2 d : Henry à cheval (« henry_cheval » posé par les essais : vrai, faux, ou nil illisible) ; son cheval amené.
function faux.henry_a_cheval(pres) return faux.henry_cheval end
-- La posture d'Henry vue par l'arbre d'un homme (« postures » posé par les essais : identifiant -> { lectures, en_selle }).
function faux.posture_d_henry_vue(identifiant)
  local p = faux.postures and faux.postures[identifiant]
  if not p then return nil end
  return p.lectures, p.en_selle
end
function faux.amener_le_cheval_d_henry(distance) return true, "cheval d'Henry posé" end
-- V73 f 2 c : le sol d'une place (« sol_du_cheval » posé par les essais), sinon plat et libre.
function faux.sol_de(position, pas)
  if faux.sol_du_cheval then return faux.sol_du_cheval(position, pas) end
  return { pente = 0, encombre = false, eau_lisible = true }
end
-- V73 f 2 b : le compte des montes manquées du cerveau d'un homme (posé par les essais), 0 sinon.
function faux.montes_manquees(identifiant)
  return faux.manquees and faux.manquees[identifiant] or 0
end
-- La position d'un personnage (fiche 15, V73 f 1), posée par les essais, ou nil.
function faux.position_du_personnage(identifiant)
  return faux.positions and faux.positions[identifiant] or nil
end
-- La vue d'Henry (fiche 15, V73 e) : par défaut, rien de lisible (nil) ; un essai peut poser « vue_d_henry ».
function faux.henry_voit(point, seuil)
  if faux.vue_d_henry then return faux.vue_d_henry(point, seuil) end
  return nil
end
-- La ronde (fiche 15, V73 d 2) : la fonction confiée par les hommes, que la vraie liaison appelle à chaque point.
function faux.accrocher_la_ronde(fonction) faux.pas_de_ronde = fonction end
-- Les positions des personnages (posées par les essais) et les secours (fiche 15).
function faux.ecart_au_but(identifiant, but)
  local ici = faux.positions and faux.positions[identifiant]
  if not ici or not but then return nil end
  return math.sqrt((ici.x - but.x) ^ 2 + (ici.y - but.y) ^ 2)
end
-- Les valeurs du cerveau écrites (fiche 12) : { [identifiant] = copie des valeurs }, et le nombre d'écritures.
function faux.regler_le_cerveau(identifiant, valeurs)
  faux.cerveaux = faux.cerveaux or {}
  faux.ecritures_du_cerveau = (faux.ecritures_du_cerveau or 0) + 1
  local copie = {}
  for nom, valeur in pairs(valeurs) do
    copie[nom] = valeur
  end
  faux.cerveaux[identifiant] = copie
  return true, "écrit"
end
-- Les variables du cerveau lues par le socle (V73 b 2) : { [identifiant] = { nom = valeur } }, posées par les essais.
function faux.lire_le_cerveau(identifiant, noms)
  local rendu = {}
  local variables = faux.variables_du_cerveau and faux.variables_du_cerveau[identifiant] or {}
  for _, nom in ipairs(noms) do
    rendu[nom] = variables[nom]
  end
  return rendu
end
-- Ce qui occupe un personnage (V73 b 1) : { [identifiant] = « combat » ou « conversation » }, posé par les essais.
function faux.occupation_de(identifiant)
  return faux.occupations and faux.occupations[identifiant] or nil
end
function faux.poser_en_secours(identifiant, position)
  faux.secours = faux.secours or {}
  table.insert(faux.secours, { identifiant = identifiant, position = position })
  faux.positions = faux.positions or {}
  faux.positions[identifiant] = position
  return "posé"
end
function faux.faire_venir_ennemis(sorte, effectif, position, cap)
  if faux.refuser_ennemis then return nil end
  local liste = {}
  for _ = 1, effectif do
    local identifiant = "ennemi_" .. faux.prochain_ennemi
    faux.prochain_ennemi = faux.prochain_ennemi + 1
    table.insert(faux.ennemis, { identifiant = identifiant, sorte = sorte, position = position, cap = cap })
    faux.ennemis_vivants_par_id[identifiant] = true
    table.insert(liste, identifiant)
  end
  return liste
end
function faux.ennemis_vivants(liste)
  local n = 0
  for _, identifiant in ipairs(liste) do
    if faux.ennemis_vivants_par_id[identifiant] then n = n + 1 end
  end
  return n
end
function faux.coucher_les_corps(liste)
  for _, identifiant in ipairs(liste) do
    table.insert(faux.corps_couches, identifiant)
  end
  return #liste
end
function faux.renvoyer_ennemis(liste)
  for _, identifiant in ipairs(liste) do
    table.insert(faux.ennemis_renvoyes, identifiant)
    faux.ennemis_vivants_par_id[identifiant] = nil
  end
end
function faux.personnage_mort(identifiant) return faux.personnages_morts[identifiant] == true end
function faux.partie_en_cours() return faux.partie end
function faux.changer_porte(identifiant, etat)
  table.insert(faux.ordres_porte, { identifiant = identifiant, etat = etat })
end
function faux.faire_venir_directeur(position, ame)
  if faux.refuser_directeur or ame == nil then return nil end
  local identifiant = "directeur_" .. (#faux.directeurs + 1) .. "_" .. faux.prochain_personnage
  faux.prochain_personnage = faux.prochain_personnage + 1
  table.insert(faux.directeurs, { identifiant = identifiant, position = position, ame = ame })
  faux.personnages_existants[identifiant] = true
  return identifiant
end
function faux.position_du_joueur() return faux.position_joueur end
function faux.cap_du_joueur() return faux.cap_joueur end

-- L'équipement pièce par pièce (fiche 13, V71 b) : mêmes fonctions que la liaison. Les préréglages d'essai suivent la
-- forme des vrais noms ; chaque personnage naît avec une tenue de naissance et une bourse.
local function prereglages_d_essai()
  local pieces, munitions = {}, {}
  for n = 1, 6 do
    for v = 1, 2 do
      local nom = string.format("soldier_generic_%d_%02d", n, v)
      pieces[nom] = { nom .. "_corps", nom .. "_tete", nom .. "_jambes" }
    end
  end
  for _, sorte in ipairs({ "sword_shield", "axe_shield", "longsword", "mace_shield", "axe", "polearm" }) do
    for n = 2, 6 do
      local nom = string.format("%s_%d_01", sorte, n)
      pieces[nom] = { nom .. "_arme", nom .. "_seconde" }
    end
  end
  for _, nom in ipairs({ "mace_shield_2_02", "mace_shield_2_03", "mace_shield_3_04", "mace_shield_4_02", "axe_shield_3_02",
                         "axe_shield_3_03", "axe_shield_4_02", "huntingsword_shield_3_01", "huntingsword_shield_3_02",
                         "huntingsword_shield_4_01" }) do
    pieces[nom] = { nom .. "_arme", nom .. "_pavois" }
  end
  for _, nom in ipairs({ "scriptorium_archer_1", "scriptorium_archer_2", "scriptorium_archer_3", "scriptorium_arbaletrier_1_a",
                         "scriptorium_arbaletrier_1_b", "scriptorium_arbaletrier_2_a", "scriptorium_arbaletrier_2_b",
                         "scriptorium_arbaletrier_3_a", "scriptorium_arbaletrier_3_b" }) do
    pieces[nom] = { nom .. "_tir", nom .. "_epee" }
    munitions[nom] = nom .. "_munition"
  end
  return pieces, munitions
end
faux.pieces_d_essai, faux.munitions_d_essai = prereglages_d_essai()
faux.objet_de_la_bourse = "bourse"

function faux.noms_des_prereglages()
  local noms = {}
  for nom in pairs(faux.pieces_d_essai) do
    table.insert(noms, nom)
  end
  table.sort(noms)
  return noms
end
function faux.pieces_de(nom)
  local liste = nom and faux.pieces_d_essai[nom]
  if not liste then return nil end
  local copie = {}
  for i, objet in ipairs(liste) do copie[i] = objet end
  return copie
end
function faux.munition_de(nom) return nom and faux.munitions_d_essai[nom] or nil end
function faux.compter_objet(personnage, objet)
  local n = 0
  for _, o in ipairs(faux.inventaires[personnage] or {}) do
    if o.objet == objet then n = n + o.nombre end
  end
  return n
end
function faux.creer_objet(personnage, objet, etat, nombre)
  if not faux.personnages_existants[personnage] or faux.refuser_objets then return false end
  faux.inventaires[personnage] = faux.inventaires[personnage] or {}
  table.insert(faux.inventaires[personnage], { objet = objet, etat = etat, nombre = nombre })
  return true
end
function faux.etat_objet(personnage, objet)
  for _, o in ipairs(faux.inventaires[personnage] or {}) do
    if o.objet == objet then return o.etat end
  end
  return nil
end
function faux.faire_porter(personnage, objets)
  local portes, introuvables = 0, {}
  faux.dernier_porter = { personnage = personnage, objets = objets }
  faux.portes[personnage] = faux.portes[personnage] or {}
  for _, objet in ipairs(objets) do
    if faux.compter_objet(personnage, objet) > 0 then
      table.insert(faux.portes[personnage], objet)
      portes = portes + 1
    else
      table.insert(introuvables, objet)
    end
  end
  return portes, introuvables
end
function faux.retirer_un_objet(personnage, objet)
  for i, o in ipairs(faux.inventaires[personnage] or {}) do
    if o.objet == objet then
      table.remove(faux.inventaires[personnage], i)
      return true
    end
  end
  return false
end
function faux.equiper_homme(personnage, ordre)
  if not faux.personnages_existants[personnage] then return "personnage introuvable" end
  table.insert(faux.equipements, { personnage = personnage, ordre = ordre })
  if ordre.retirer_naissance then
    local garde = {}
    for _, o in ipairs(faux.inventaires[personnage] or {}) do
      if o.objet == faux.objet_de_la_bourse then table.insert(garde, o) end
    end
    faux.inventaires[personnage] = garde
  end
  for _, objet in ipairs(ordre.creer or {}) do faux.creer_objet(personnage, objet, ordre.etat or 1, 1) end
  if ordre.munition then faux.creer_objet(personnage, ordre.munition.objet, 1, ordre.munition.nombre) end
  for _, piece in ipairs(ordre.recreer or {}) do faux.creer_objet(personnage, piece.objet, piece.etat, 1) end
  faux.portes[personnage] = {}
  local portes = faux.faire_porter(personnage, ordre.porter or {})
  return "équipé, " .. portes .. " portée(s)"
end

-- Exécute la prochaine minuterie en attente (une seule), comme le ferait le moteur.
function faux.tic_minuterie()
  local prochaine = table.remove(faux.minuteries, 1)
  if prochaine then
    prochaine.fonction()
    return true
  end
  return false
end

Scriptorium = Scriptorium or {}
Scriptorium.jeu = faux
-- Au banc, le réveil se fait tout de suite à l'entrée en partie (le noyau garde une table déjà posée) ; l'attente de
-- 30 s du jeu a son propre essai (essai_noyau.lua).
Scriptorium.noyau = { reglages = { delai_du_reveil_s = 0, guet_du_chargement_s = 10 } }
FauxJeu = faux
return faux

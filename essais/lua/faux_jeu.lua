-- Faux jeu pour les essais : remplace Scriptorium.jeu (la liaison réelle n'est pas chargée).
-- Tout ce que le socle demande au jeu est noté ici, pour être vérifié par les essais.

local faux = {
  temps = 0,
  affichages = {},      -- { texte, duree, temps }
  en_ecran = nil,
  journal_lignes = {},
  dialogue = false,
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
  faux.carte = nil
  faux.inconscients = nil
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
  faux.cases_ecrites = {}
  faux.depuis_la_sauvegarde = nil
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
  faux.tailles_paliers = { combattant = { 80, 80, 80 }, metier = { 50 }, femme = { 30 }, directeur = { 1 } }
  faux.visages = nil
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
function faux.chrono() return faux.temps, "faux" end
function faux.avancer(secondes) faux.temps = faux.temps + secondes end
function faux.journal(texte) table.insert(faux.journal_lignes, tostring(texte)) end
function faux.afficher(texte, duree, complement, qui)
  table.insert(faux.affichages, { texte = texte, duree = duree, temps = faux.temps, complement = complement, qui = qui })
  faux.en_ecran = texte
end
function faux.effacer() faux.en_ecran = nil end
function faux.dialogue_en_cours() return faux.dialogue end
function faux.minuterie(ms, fonction)
  table.insert(faux.minuteries, { ms = ms, fonction = fonction })
  return #faux.minuteries
end
-- Fiche 01, le registre par case : l'index, la chaîne de chaque case, et l'ancien flux unique (encore lu).
-- « registre_stocke » (lu par les essais d'avant) est une PHOTO de ce qui est stocké, au format de l'ancien flux ; y poser
-- une chaîne la rend au jeu comme un ancien flux (le registre la relit puis la migre) : les essais d'avant éprouvent
-- ainsi la migration.
faux.registre_jetons = { index = nil, cases = {}, ancien = nil }
faux.cases_ecrites = {}
function faux.lire_registre() return faux.registre_jetons.ancien end
function faux.ecrire_registre(chaine) faux.registre_jetons.ancien = chaine end
function faux.lire_index() return faux.registre_jetons.index end
function faux.ecrire_index(chaine)
  faux.registre_jetons.index = chaine
  faux.index_ecrits = (faux.index_ecrits or 0) + 1
end
function faux.lire_case(nom) return faux.registre_jetons.cases[nom] end
function faux.ecrire_case(nom, chaine)
  faux.registre_jetons.cases[nom] = chaine
  table.insert(faux.cases_ecrites, nom)
end
function faux.effacer_l_ancien_registre() faux.registre_jetons.ancien = nil end
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
-- V73 f 3 a : la carte (« carte » posée par les essais) et le dernier chargement.
function faux.carte_courante() return faux.carte, faux.carte and "essai" or "aucune lecture" end
faux.dernier_chargement = nil
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
-- L'identité réelle d'un objet (22/10) : par défaut son nom ; un essai la change pour un objet refait.
function faux.identite_d_un_objet(nom)
  if type(nom) ~= "string" then return nil end
  return faux.identites_des_objets and faux.identites_des_objets[nom] or nom
end
-- Fiche 18, 5 c : un poste de travail posé (« refuser_les_postes » : aucun).
function faux.poser_poste(nom, gabarit, position, cap, aides, geste)
  if faux.refuser_les_postes then return nil end
  local identifiant = "poste_" .. faux.prochain_objet
  faux.prochain_objet = faux.prochain_objet + 1
  faux.postes_poses = faux.postes_poses or {}
  table.insert(faux.postes_poses, { identifiant = identifiant, nom = nom, gabarit = gabarit, position = position, cap = cap,
                                    geste = geste })
  faux.objets_existants[identifiant] = true
  return identifiant
end
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
-- La réserve et le rang d'une âme (même forme que la liaison).
function faux.rang_de_l_ame(ame)
  local reserve, palier, numero = string.match(tostring(ame), "^ame_(%a+)_(%d+)_(%d+)$")
  if not reserve or not faux.tailles_paliers[reserve] then return nil end
  local rang = tonumber(numero) - 1
  for p = 1, tonumber(palier) - 1 do rang = rang + faux.tailles_paliers[reserve][p] end
  return reserve, rang
end
-- Pas de jumeaux : le visage d'une âme, « réserve:rang mod visages » quand faux.visages[réserve] est posé (sinon nil).
function faux.visage_de(ame)
  local reserve, palier, numero = string.match(tostring(ame), "^ame_(%a+)_(%d+)_(%d+)$")
  local n = reserve and faux.visages and faux.visages[reserve]
  if not n then return nil end
  local rang = tonumber(numero) - 1
  for p = 1, tonumber(palier) - 1 do rang = rang + faux.tailles_paliers[reserve][p] end
  return reserve .. ":" .. (rang % n)
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
-- Le tir à la cible : la cible donnée avant l'ordre.
function faux.donner_la_cible_du_tir(identifiant, cible)
  faux.cibles_du_tir = faux.cibles_du_tir or {}
  faux.cibles_du_tir[identifiant] = cible
end

function faux.ordonner(identifiant, activite, position, lieu, place, sorte, regard, allure, chef, suivi, marche_ms)
  table.insert(faux.ordres, { identifiant = identifiant, activite = activite, position = position, lieu = lieu,
                              place = place, sorte = sorte, regard = regard, allure = allure, chef = chef, suivi = suivi,
                              marche_ms = marche_ms })
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
-- V73 f 3 b : la selle d'un cheval (« chevaux_montes » posé par les essais), à pied par défaut.
function faux.cheval_monte(identifiant)
  if faux.chevaux_montes and faux.chevaux_montes[identifiant] ~= nil then return faux.chevaux_montes[identifiant] end
  return false
end
function faux.retirer_cheval(identifiant)
  if faux.chevaux then faux.chevaux[identifiant] = nil end
  faux.objets_existants[identifiant] = nil
  if faux.positions then faux.positions[identifiant] = nil end
  faux.chevaux_retires = faux.chevaux_retires or {}
  table.insert(faux.chevaux_retires, identifiant)
end
-- V73 f 2 f : la règle de l'allure accrochée par les hommes.
function faux.accrocher_l_allure(fonction, filtre) faux.allure_choisie, faux.vitesse_filtree = fonction, filtre end
-- V73 f 2 d : Henry à cheval (« henry_cheval » posé par les essais : vrai, faux, ou nil illisible) ; son cheval amené.
function faux.henry_a_cheval(pres) return faux.henry_cheval end
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
-- Fiche 18, 5 b : les personnages parlables ; « parler_a » joue Henry qui appuie sur « Parler ».
function faux.accrocher_la_parole(fonction) faux.parole = fonction end
-- Fiche 18, 5 c : le geste tenu donné à un personnage.
-- Fiche 18, 5 c, tranche 4 : les stations partagées ; « henry_prend » joue Henry qui emploie la station.
function faux.accrocher_la_station(fonction) faux.station_prise = fonction end
-- Fiche 01 (le second canal) : l'OnSave accroché ; les cases rangées rendues une fois ; une empreinte simple.
function faux.accrocher_la_sauvegarde(fonction) faux.a_la_sauvegarde = fonction return true end
-- Fiche 21 : l'accroche des dialogues (la liaison la garde ; l'essai l'appelle comme l'ExitScript).
function faux.accrocher_le_dialogue(fonction) faux.reponse_du_dialogue = fonction end
-- Les alertes : les sons joués, dans l'ordre.
function faux.jouer_un_son(nom, identifiant)
  faux.sons = faux.sons or {}
  table.insert(faux.sons, { nom = nom, ou = identifiant })
  return true
end
function faux.cases_de_la_sauvegarde()
  local d = faux.depuis_la_sauvegarde
  faux.depuis_la_sauvegarde = nil
  return d
end
function faux.empreinte(chaine)
  local s = 0
  for i = 1, #chaine do s = (s * 31 + string.byte(chaine, i)) % 65521 end
  return #chaine, s
end
function faux.partager_avec_henry(station, oui)
  faux.stations = faux.stations or {}
  if faux.stations_absentes and faux.stations_absentes[station] then return false end
  faux.stations[station] = oui and true or nil
  return true
end
function faux.henry_prend(station)
  if faux.stations and faux.stations[station] and faux.station_prise then faux.station_prise(station) return true end
  return false
end
function faux.henry_a_fini(station, depuis, delai, loin) return faux.henry_fini == true end
function faux.position_d_un_objet(nom) return faux.positions_des_objets and faux.positions_des_objets[nom] or nil end
-- Fiche 20 : la parole donnée à un personnage.
function faux.donner_la_parole(identifiant, sorte, alias, metarole, partenaire)
  faux.paroles = faux.paroles or {}
  faux.paroles[identifiant] = { sorte = sorte, alias = alias, metarole = metarole, partenaire = partenaire }
end
function faux.donner_le_geste(identifiant, geste, options)
  faux.gestes = faux.gestes or {}
  faux.gestes[identifiant] = geste
  faux.options_des_gestes = faux.options_des_gestes or {}
  faux.options_des_gestes[identifiant] = options
end
function faux.rendre_parlable(identifiant, oui)
  faux.parlables = faux.parlables or {}
  faux.poses_parlables = (faux.poses_parlables or 0) + 1
  faux.parlables[identifiant] = oui and true or nil
  return true
end
function faux.parler_a(identifiant)
  if faux.parlables and faux.parlables[identifiant] and faux.parole then faux.parole(identifiant) return true end
  return false
end
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
-- Un cheval posé (et son cavalier en selle avec lui).
function faux.poser_le_cheval(identifiant, position)
  if not faux.chevaux or not faux.chevaux[identifiant] then return false, "cheval introuvable" end
  faux.chevaux[identifiant] = { x = position.x, y = position.y, z = position.z }
  faux.chevaux_poses = (faux.chevaux_poses or 0) + 1
  return true, "posé"
end
function faux.poser_en_secours(identifiant, position)
  faux.secours = faux.secours or {}
  table.insert(faux.secours, { identifiant = identifiant, position = position })
  -- V73 f 3 b (vu en jeu) : une pose que le jeu ignore (« poses_ignorees » posé par les essais : combien de fois).
  if faux.poses_ignorees and (faux.poses_ignorees[identifiant] or 0) > 0 then
    faux.poses_ignorees[identifiant] = faux.poses_ignorees[identifiant] - 1
    return "posé"
  end
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
-- Étape 2 : les ordres d'attaque donnés (cible, attaquant).
function faux.ordonner_l_attaque(cible, attaquant, options)
  faux.attaques = faux.attaques or {}
  table.insert(faux.attaques, { cible = cible, attaquant = attaquant, options = options })
  return "attaque : essai"
end
-- La fin d'un affrontement : les attaques levées (attaquant).
function faux.cesser_l_attaque(attaquant)
  faux.cessations = faux.cessations or {}
  table.insert(faux.cessations, attaquant)
  return "cesser l'attaque : essai"
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
-- Un coup (vu en jeu : 1000 tue) : la victime morte, ennemi ou des nôtres.
function faux.blesser(identifiant, points)
  faux.coups = faux.coups or {}
  table.insert(faux.coups, { identifiant = identifiant, points = points })
  if points >= 1000 then
    faux.personnages_morts[identifiant] = true
    faux.ennemis_vivants_par_id[identifiant] = nil
  end
  return true
end
-- La santé réglée d'un blessé (soul:SetState) : le faux jeu la retient.
function faux.regler_la_sante(identifiant, sante)
  faux.santes = faux.santes or {}
  faux.santes[identifiant] = sante
  faux.santes_reglees = (faux.santes_reglees or 0) + 1
  return true
end
function faux.sante_de(identifiant)
  return faux.santes and faux.santes[identifiant] or 100
end
function faux.personnage_inconscient(identifiant)
  return faux.inconscients ~= nil and faux.inconscients[identifiant] == true
end
function faux.mettre_a_terre(identifiant, reste)
  faux.a_terre = faux.a_terre or {}
  table.insert(faux.a_terre, identifiant)
  return true
end
function faux.personnage_mort(identifiant) return faux.personnages_morts[identifiant] == true end
function faux.partie_en_cours() return faux.partie end
function faux.changer_porte(identifiant, etat)
  table.insert(faux.ordres_porte, { identifiant = identifiant, etat = etat })
end
function faux.faire_venir_directeur(position, ame, cap)
  faux.cap_du_directeur = cap
  if faux.refuser_directeur or ame == nil then return nil end
  local identifiant = "directeur_" .. (#faux.directeurs + 1) .. "_" .. faux.prochain_personnage
  faux.prochain_personnage = faux.prochain_personnage + 1
  table.insert(faux.directeurs, { identifiant = identifiant, position = position, ame = ame })
  faux.personnages_existants[identifiant] = true
  return identifiant
end
function faux.position_du_joueur() return faux.position_joueur end
-- V73 g : le terrain (« terrain » posé par les essais : une fonction, sinon 0), l'immortalité (les effets posés et
-- retirés), le réveil (les réveillés), les poses d'essai sous le sol et le sommeil.
function faux.altitude_du_terrain(x, y)
  if faux.terrain then return faux.terrain(x, y) end
  return 0
end
function faux.rendre_immortel(identifiant)
  faux.effets = faux.effets or {}
  if faux.refuser_les_effets then return nil, "effet refusé" end
  table.insert(faux.effets, { identifiant = identifiant, pose = true })
  return #faux.effets
end
function faux.retirer_l_effet(identifiant, effet)
  faux.effets_retires = faux.effets_retires or {}
  table.insert(faux.effets_retires, { identifiant = identifiant, effet = effet })
  return true
end
function faux.eveiller(identifiant, titre)
  faux.reveilles = faux.reveilles or {}
  table.insert(faux.reveilles, identifiant)
  return true
end
function faux.poser_sous_le_sol(identifiant, profondeur) return true, "essai" end
function faux.endormir(identifiant) return true, "essai" end
-- V73 g 0 : le rechargement d'essai (« rechargement » posé par les essais : { liste = {…}, refus = { nom = raison } }).
function faux.liste_du_rechargement()
  if not faux.rechargement then return nil end
  return faux.rechargement.liste, "essai"
end
function faux.charger_un_morceau(nom)
  local refus = faux.rechargement and faux.rechargement.refus and faux.rechargement.refus[nom]
  if refus then return false, refus end
  faux.morceaux_charges = faux.morceaux_charges or {}
  table.insert(faux.morceaux_charges, nom)
  return true, "essai/" .. nom
end
-- V73 f 3 b : le plancher sous un point (« plancher » posé par les essais), sinon rien touché.
function faux.plancher_sous(x, y, z_depart, profondeur)
  if faux.plancher then return faux.plancher(x, y, z_depart, profondeur) end
  return nil, "rien touché"
end
-- V73 f 3 b : Henry posé à une position exacte (le poste d'essai des intérieurs).
function faux.poser_le_joueur(position)
  faux.position_joueur = { x = position.x, y = position.y, z = position.z }
  return true, "posé"
end
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
  -- Les sortes des compagnons nommés (18/10), aux niveaux que le jeu offre.
  for sorte, niveaux in pairs({ mace = { 1, 2, 3 }, hammer = { 2, 3, 4 }, sabre = { 1, 3 }, sword = { 2, 3, 4 },
                                huntingsword = { 1, 2, 3, 4, 5 } }) do
    for _, n in ipairs(niveaux) do
      local nom = string.format("%s_%d_01", sorte, n)
      pieces[nom] = { nom .. "_arme" }
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
-- La partie du corps d'une pièce de tenue d'essai : « _corps » le torse, « _jambes » les jambes.
function faux.partie_du_corps(objet)
  if string.find(tostring(objet), "_corps$") then return "torse" end
  if string.find(tostring(objet), "_jambes$") then return "jambes" end
  return nil
end
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
function faux.remplacer_un_objet(personnage, objet, etat)
  if not faux.retirer_un_objet(personnage, objet) then return false end
  faux.creer_objet(personnage, objet, etat, 1)
  return faux.faire_porter(personnage, { objet }) == 1
end
-- Les pièces mises au sac (le jeu n'a pas de fonction pour ôter : retirée, recréée sans être portée).
function faux.ranger_au_sac(personnage, objet)
  local etat = faux.etat_objet(personnage, objet)
  if etat == nil or not faux.retirer_un_objet(personnage, objet) then return false end
  faux.creer_objet(personnage, objet, etat, 1)
  faux.au_sac = faux.au_sac or {}
  faux.au_sac[personnage] = faux.au_sac[personnage] or {}
  faux.au_sac[personnage][objet] = true
  return true
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
Scriptorium.noyau = { reglages = { delai_du_reveil_s = 0, guet_du_chargement_s = 10, argent_d_henry_max = 1000000,
                                    registre_intervalle_s = 0, registre_journal = 0 } }
-- Fiche 16 : au banc, les règles du socle sont éprouvées allumées (le noyau garde cette table) ; les essais des
-- interrupteurs les éteignent un à un.
Scriptorium.noyau.interrupteurs = { solde_de_la_semaine = 1, aguerrissement = 1, rangs_du_socle = 1, usure_en_points = 1,
  fautes_a_l_aube = 1, rencontres_de_patrouille = 1, contrats_a_duree = 1, exactions = 1, baisse_du_risque = 1, repas_du_socle = 1,
  chevaux_de_la_compagnie = 1, un_lit_par_homme = 1, pillage_du_socle = 1, moral_de_bataille = 1 }
local function photo_du_registre()
  local j = faux.registre_jetons
  if j.index == nil then
    return j.ancien
  end
  local registre = Scriptorium.registre
  local index = registre.deserialiser(j.index)
  local contenu = { format = registre.format, cases = {} }
  for _, nom in ipairs(index and index.cases or {}) do
    local chaine = j.cases[nom]
    local valeur = chaine and registre.deserialiser(chaine)
    if valeur then
      contenu.cases[nom] = valeur
    end
  end
  return registre.serialiser(contenu)
end

setmetatable(faux, {
  __index = function(_, cle)
    if cle == "registre_stocke" then
      return photo_du_registre()
    end
    return nil
  end,
  __newindex = function(table_, cle, valeur)
    if cle == "registre_stocke" then
      faux.registre_jetons = { index = nil, cases = {}, ancien = valeur }
    else
      rawset(table_, cle, valeur)
    end
  end,
})

FauxJeu = faux
return faux

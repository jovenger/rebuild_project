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
  prochain_objet = 1,
  refuser_pose = {},      -- nom -> true : le jeu refuse de poser cet objet
  position_joueur = { x = 0, y = 0, z = 0 },
  cap_joueur = 0,
  personnages = {},            -- { identifiant, role, nom, position }
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
  faux.prochain_objet = 1
  faux.refuser_pose = {}
  faux.position_joueur = { x = 0, y = 0, z = 0 }
  faux.cap_joueur = 0
  faux.personnages = {}
  faux.personnages_existants = {}
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
function faux.faire_venir_homme(role, nom, position)
  if faux.refuser_personnage then return nil end
  local identifiant = "personnage_" .. faux.prochain_personnage
  faux.prochain_personnage = faux.prochain_personnage + 1
  table.insert(faux.personnages, { identifiant = identifiant, role = role, nom = nom, position = position })
  faux.personnages_existants[identifiant] = true
  return identifiant
end
function faux.personnage_existe(identifiant) return faux.personnages_existants[identifiant] == true end
function faux.renvoyer_homme(identifiant)
  table.insert(faux.personnages_renvoyes, identifiant)
  faux.personnages_existants[identifiant] = nil
end
function faux.ordonner(identifiant, activite, position, lieu)
  table.insert(faux.ordres, { identifiant = identifiant, activite = activite, position = position, lieu = lieu })
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
function faux.faire_venir_directeur(position)
  if faux.refuser_directeur then return nil end
  local identifiant = "directeur_" .. (#faux.directeurs + 1) .. "_" .. faux.prochain_personnage
  faux.prochain_personnage = faux.prochain_personnage + 1
  table.insert(faux.directeurs, { identifiant = identifiant, position = position })
  faux.personnages_existants[identifiant] = true
  return identifiant
end
function faux.position_du_joueur() return faux.position_joueur end
function faux.cap_du_joueur() return faux.cap_joueur end

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
FauxJeu = faux
return faux

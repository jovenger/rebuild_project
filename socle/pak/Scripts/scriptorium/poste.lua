-- Poste d'essai : des commandes en français pour éprouver chaque morceau en jeu,
-- sans rien d'autre que le socle. Voir docs/socle/essai_en_jeu.md.

local Scriptorium = Scriptorium

local poste = {}
Scriptorium.poste = poste

local function jeu()
  return Scriptorium.jeu
end

-- Bandeau : une nouvelle, une alerte qui passe devant, trois arrivées regroupées en une.
function poste.essai_bandeau()
  local bandeau = Scriptorium.bandeau
  local sorts = {
    bandeau.annoncer("ui_scriptorium_essai_nouvelle"),
    bandeau.annoncer("ui_scriptorium_essai_arrivee", { groupe = "essai_arrivee", cle_plusieurs = "ui_scriptorium_essai_arrivee_plusieurs" }),
    bandeau.annoncer("ui_scriptorium_essai_arrivee", { groupe = "essai_arrivee", cle_plusieurs = "ui_scriptorium_essai_arrivee_plusieurs" }),
    bandeau.annoncer("ui_scriptorium_essai_arrivee", { groupe = "essai_arrivee", cle_plusieurs = "ui_scriptorium_essai_arrivee_plusieurs" }),
    bandeau.annoncer("ui_scriptorium_essai_alerte", { importance = "alerte" }),
  }
  jeu().journal("Poste : bandeau, sorts = " .. table.concat(sorts, ", ") .. " ; en attente = " .. bandeau.en_attente())
  return sorts
end

-- Registre : compte les appels, enregistre, relit, et dit ce qu'il a trouvé.
function poste.essai_registre()
  local registre = Scriptorium.registre
  if not registre.etat_de("essai") then
    registre.declarer_case("essai", 1, function() return { appels = 0 } end)
  end
  local donnees = registre.lire("essai")
  donnees.appels = donnees.appels + 1
  local chaine = registre.enregistrer()
  registre.invalider()
  local rapport = registre.charger()
  local relu = registre.lire("essai")
  jeu().journal("Poste : registre, appels = " .. relu.appels .. ", source = " .. rapport.source
                .. ", longueur = " .. #chaine)
  Scriptorium.bandeau.annoncer("ui_scriptorium_essai_registre", { importance = "nouvelle", duree = 4 })
  return relu.appels, rapport
end

-- Jetons du jeu (note de JoVenGer, partie 2, point 3) : écrire des jetons de plus en plus longs et les relire aussitôt,
-- puis, après « Sauvegarder et quitter » et rechargement, les relire encore : on sait ce que garde un jeton. Jamais
-- au-delà de 65 535 octets : le 15/10, des jetons de 66 000 à 200 000 ont rendu la sauvegarde impossible à recharger ;
-- 65 535 tout juste n'est pas essayé (le bord exact pourrait casser aussi).
poste.longueurs_de_jetons = { 16000, 32000, 60000, 65000 }

function poste.essai_jetons_ecrire()
  for _, longueur in ipairs(poste.longueurs_de_jetons) do
    local relu, intact = jeu().essayer_un_jeton(longueur)
    jeu().journal("Poste : jeton de " .. longueur .. " écrit, relu aussitôt " .. tostring(relu) .. ", intact = " .. tostring(intact))
  end
  return true
end

-- Registre : ce que le jeu garde de ses tranches ; et les calculs du socle qui doivent rester justes dans le Lua du
-- jeu (simple précision).
function poste.essai_registre_tranches()
  Scriptorium.registre.enregistrer()
  for _, ligne in ipairs(jeu().decrire_le_registre()) do
    jeu().journal("Poste : registre, " .. ligne)
  end
  local justes, ligne = jeu().verifier_les_nombres()
  jeu().journal("Poste : nombres " .. (justes and "justes" or "FAUX") .. ", " .. ligne)
  return justes
end

function poste.essai_jetons_relire()
  for _, longueur in ipairs(poste.longueurs_de_jetons) do
    local relu, intact = jeu().relire_un_jeton(longueur)
    jeu().journal("Poste : jeton de " .. longueur .. " après rechargement : " .. tostring(relu) .. ", intact = " .. tostring(intact))
  end
  return true
end

-- Coffre : Henry dépose, le camp paie, une réserve entre et sort, une dépense trop grosse est refusée.
function poste.essai_coffre()
  local coffre = Scriptorium.coffre
  local bourse_avant = jeu().groschen_d_henry()
  local sorts = {
    tostring(coffre.deposer_par_henry(100, "depot")),
    tostring(coffre.payer(30, "solde")),
    tostring(coffre.ajouter_reserve("vivres", 10, "achat")),
    tostring(coffre.prelever_reserve("vivres", 4, "repas")),
    tostring(coffre.payer(500, "solde")),
  }
  local bilan = coffre.bilan()
  jeu().journal("Poste : coffre, sorts = " .. table.concat(sorts, ", ") .. " ; solde = " .. bilan.groschen
                .. ", vivres = " .. bilan.reserves.vivres .. ", lignes = " .. bilan.lignes
                .. ", bourse d'Henry = " .. bourse_avant .. " -> " .. jeu().groschen_d_henry())
  Scriptorium.bandeau.annoncer("ui_scriptorium_essai_coffre", { duree = 4 })
  return sorts, bilan
end

-- Camp : fonde le camp là où se tient Henry ; s'il existe déjà, le redresse.
function poste.essai_camp()
  local camp = Scriptorium.camp
  if camp.est_fonde() then
    local reposes, manquants = camp.redresser()
    jeu().journal("Poste : camp déjà fondé (niveau " .. camp.niveau() .. "), redressé : " .. reposes
                  .. " reposé(s), " .. manquants .. " manquant(s)")
    return "redresse", reposes, manquants
  end
  local ok, raison = camp.fonder(jeu().position_du_joueur(), jeu().cap_du_joueur())
  local capacite = camp.capacite()
  jeu().journal("Poste : camp fondé = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or "")
                .. ", lits = " .. capacite.lits .. ", sièges = " .. capacite.sieges)
  return ok and "fonde" or "refuse", capacite.lits, capacite.sieges
end

-- Camp : ce que le moteur dit du feu central, d'un banc et d'une tente (V23).
function poste.essai_feu()
  local camp = Scriptorium.camp
  for _, nom in ipairs({ "feu_central", "siege_1", "tente_1" }) do
    local identifiant = camp.objet_de(nom)
    local description = identifiant and jeu().decrire_objet and jeu().decrire_objet(identifiant) or "pas posé"
    jeu().journal("Poste : objet « " .. nom .. " » : " .. tostring(description))
  end
  for _, nom in ipairs({ "porte", "pan_1", "tour_est" }) do
    local identifiant = Scriptorium.enceinte.objet_de(nom)
    local description = identifiant and jeu().decrire_objet and jeu().decrire_objet(identifiant) or "pas posé"
    jeu().journal("Poste : objet « enceinte " .. nom .. " » : " .. tostring(description))
  end
end

-- Henry : posé quarante mètres plus loin, pour chercher un terrain d'essai vierge (demande de JoVenGer du 14/10 :
-- ne pas dresser le camp dans un campement du jeu). Une commande par direction de boussole.
function poste.essai_aller(cap)
  local ok, compte_rendu = jeu().deplacer_le_joueur(40, cap)
  jeu().journal("Poste : Henry déplacé vers " .. tostring(cap) .. " = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

-- Henry : posé sur le terrain d'essai (un pré dégagé hors du campement du jeu, liaison.terrain_d_essai).
-- Le camp du socle est levé avant, pour ne pas le laisser derrière soi.
function poste.essai_terrain_d_essai()
  if Scriptorium.camp.est_fonde() then
    Scriptorium.camp.lever()
  end
  local ok, compte_rendu = jeu().aller_au_terrain_d_essai()
  jeu().journal("Poste : terrain d'essai = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end
-- Camp : agrandit d'un niveau.
function poste.essai_camp_agrandir()
  local ok, raison = Scriptorium.camp.agrandir()
  jeu().journal("Poste : camp agrandi = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or "")
                .. ", niveau = " .. Scriptorium.camp.niveau())
  return ok
end

-- Camp : lève le camp.
-- Fin d'un essai de rechargement (V57) : renvoie les hommes, congédie le Directeur et lève le camp, pour ne rien
-- laisser dans la sauvegarde de la partie d'essai.
function poste.essai_tout_lever()
  local renvoyes = 0
  for _, id in ipairs(Scriptorium.hommes.liste()) do
    if Scriptorium.hommes.renvoyer(id) then
      renvoyes = renvoyes + 1
    end
  end
  local congedie = Scriptorium.directeur.est_installe() and Scriptorium.directeur.congedier()
  local leve = Scriptorium.camp.est_fonde() and Scriptorium.camp.lever()
  jeu().journal("Poste : tout levé, " .. renvoyes .. " homme(s) renvoyé(s), Directeur congédié = " .. tostring(congedie)
                .. ", camp levé = " .. tostring(leve))
  return true
end

function poste.essai_camp_lever()
  local ok, raison = Scriptorium.camp.lever()
  jeu().journal("Poste : camp levé = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or ""))
  return ok
end

-- Hommes : engage trois hommes (le coffre doit avoir de quoi payer les primes), puis lance le battement.
function poste.essai_hommes()
  local hommes = Scriptorium.hommes
  local ids = {}
  for _, role in ipairs({ "homme_d_armes", "arbaletrier", "archer" }) do
    local id, raison = hommes.embaucher({ role = role, semaines = 4 })
    table.insert(ids, id and tostring(id) or ("refus:" .. tostring(raison)))
  end
  local effectif = hommes.effectif()
  jeu().journal("Poste : hommes, engagés = " .. table.concat(ids, ", ") .. " ; total = " .. effectif.nombre
                .. ", présents = " .. effectif.presents .. ", coffre = " .. Scriptorium.coffre.solde())
  poste.battre_les_hommes()
  return ids, effectif
end

-- Le battement du camp est celui du socle (Scriptorium.battre, lancé au démarrage) ;
-- ici, on s'assure seulement qu'il tourne.
function poste.battre_les_hommes()
  Scriptorium.lancer_le_battement()
end

-- Patrouille : envoie deux hommes faire la ronde proche.
function poste.essai_patrouille()
  local id, raison = Scriptorium.patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  jeu().journal("Poste : patrouille = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or ""))
  return id
end

-- Bataille : lève une bande de cinq brigands venant du nord, qui arrive au prochain battement (délai nul :
-- vu le 14/10, une bande à un quart d'heure n'arrivait jamais, l'heure du jeu ne tournant pas dans le prologue).
function poste.essai_bataille()
  local id, raison = Scriptorium.bataille.lever_une_bande({ sorte = "brigands", effectif = 5, direction = 0, delai = 0 })
  jeu().journal("Poste : bande levée = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or "")
                .. ", force des nôtres = " .. Scriptorium.bataille.force_des_notres())
  poste.battre_les_hommes()
  return id
end

-- Les ennemis dans le jeu de la première bande au contact, et son nom.
local function ennemis_au_contact()
  for _, id in ipairs(Scriptorium.bataille.bandes()) do
    local b = Scriptorium.bataille.bande(id)
    if #b.personnages > 0 then
      return b.personnages, id
    end
  end
  return {}, nil
end

-- Nos hommes présents dans le jeu.
local function nos_personnages()
  local liste = {}
  for _, id in ipairs(Scriptorium.hommes.liste()) do
    local f = Scriptorium.hommes.fiche(id)
    if f and f.personnage then
      table.insert(liste, f.personnage)
    end
  end
  return liste
end

-- Étape 1 de la note de JoVenGer : nos personnages sont-ils connus de l'IA du jeu ? Le premier de nos hommes présents,
-- comparé au personnage du jeu le plus proche d'Henry.
function poste.essai_cerveau()
  local notres = nos_personnages()
  for _, ligne in ipairs(jeu().sonder_les_cerveaux(notres[1])) do
    jeu().journal("Poste : cerveau, " .. ligne)
  end
  return #notres
end

-- Les liens de l'habitant le plus proche (moteur et IA).
function poste.essai_liens()
  for _, ligne in ipairs(jeu().decrire_les_liens()) do
    jeu().journal("Poste : liens, " .. ligne)
  end
  return true
end

-- Cerveau à nous (étape 1) : le marcheur marche vers un point lu dans son cerveau ; un ordre lui donne un autre point.
function poste.essai_marcheur()
  local nom, ligne = jeu().poser_le_marcheur()
  jeu().journal("Poste : marcheur, posé = " .. tostring(nom) .. " ; " .. tostring(ligne))
  return nom ~= nil
end

function poste.essai_marcheur_point()
  jeu().journal("Poste : marcheur, " .. jeu().viser_un_point("droite"))
  return true
end

function poste.essai_marcheur_assis()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_au_marcheur(4))
  return true
end

function poste.essai_marcheur_debout()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_au_marcheur(0))
  return true
end

function poste.essai_marcheur_rejoindre()
  for _, texte in ipairs(jeu().ordonner_de_rejoindre()) do
    jeu().journal("Poste : marcheur, " .. texte)
  end
  return true
end

function poste.essai_marcheur_combat()
  for _, texte in ipairs(jeu().ordonner_le_combat()) do
    jeu().journal("Poste : marcheur, " .. texte)
  end
  return true
end

function poste.essai_marcheur_brigand()
  for _, texte in ipairs(jeu().ordonner_le_combat(true)) do
    jeu().journal("Poste : marcheur, " .. texte)
  end
  return true
end

function poste.essai_marcheur_contre_henry()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_contre_henry())
  return true
end

function poste.essai_brigand_du_jeu()
  jeu().journal("Poste : brigand, " .. jeu().poser_le_brigand_du_jeu())
  return true
end

function poste.essai_brigand_voir()
  jeu().journal("Poste : brigand, " .. jeu().voir_le_brigand_du_jeu())
  return true
end

-- Le marcheur reçoit un coup léger de la part de l'adversaire : riposte-t-il de lui-même (switch du jeu) ?
function poste.essai_coup_recu()
  if not jeu().marcheur or not jeu().adversaire then
    jeu().journal("Poste : coup, il faut d'abord le marcheur et l'adversaire")
    return false
  end
  jeu().journal("Poste : coup, " .. jeu().blesser_de_la_part_de(jeu().marcheur, jeu().adversaire, 5))
  return true
end

function poste.essai_henry_frappe()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_le_brigand(10))
  return true
end

function poste.essai_henry_frappe_habitant()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_un_habitant(10))
  return true
end

function poste.essai_habitant_voir()
  jeu().journal("Poste : habitant, " .. jeu().voir_l_habitant_frappe())
  return true
end

function poste.essai_brigand_naissance()
  jeu().journal("Poste : brigand, naissance annoncée à l'IA : " .. jeu().annoncer_la_naissance())
  return true
end

function poste.essai_marcheur_frappe()
  jeu().journal("Poste : coup, " .. jeu().marcheur_frappe_le_brigand(10))
  return true
end

-- Le coup sans blessure (V44, demande de JoVenGer) : 0 point ; s'il suffit à déclencher le combat, le Directeur pourra le
-- lancer sans que personne ne soit touché par magie.
function poste.essai_marcheur_effleure()
  jeu().journal("Poste : coup, " .. jeu().marcheur_frappe_le_brigand(0))
  return true
end

function poste.essai_henry_effleure()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_le_brigand(0))
  return true
end

function poste.essai_marcheur_attaque()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_l_attaque())
  return true
end

function poste.essai_henry_effleure_marcheur()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_le_marcheur(0))
  return true
end

-- L'adversaire à âme de brigand (notre cerveau), posé seul, sans ordre de combat (V47).
function poste.essai_adversaire_brigand()
  local _, ligne = jeu().poser_l_adversaire(true)
  jeu().journal("Poste : marcheur, " .. tostring(ligne))
  return true
end

function poste.essai_henry_effleure_adversaire()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_l_adversaire(0))
  return true
end

function poste.essai_garde_du_jeu()
  jeu().journal("Poste : garde, " .. jeu().poser_le_garde_du_jeu())
  return true
end

function poste.essai_garde_voir()
  jeu().journal("Poste : garde, " .. jeu().voir_le_garde_du_jeu())
  return true
end

-- Le marcheur attaque l'adversaire, qui ne se défend pas (V51) : ses coups portent-ils ?
function poste.essai_marcheur_attaque_adversaire()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_l_attaque(jeu().adversaire))
  return true
end

function poste.essai_marcheur_armer()
  jeu().journal("Poste : marcheur, " .. jeu().armer_le_marcheur())
  return true
end

function poste.essai_prairie()
  jeu().journal("Poste : " .. jeu().mener_henry_en_prairie())
  return true
end

function poste.essai_marcheur_competences()
  jeu().journal("Poste : marcheur, " .. jeu().donner_des_competences(jeu().niveau_de_combat_d_essai))
  return true
end

function poste.essai_brigand_leger()
  jeu().journal("Poste : brigand, " .. jeu().poser_le_brigand_du_jeu(jeu().ame_du_brigand_leger))
  return true
end

function poste.essai_marcheur_aller()
  jeu().journal("Poste : marcheur, aller : " .. jeu().ordonner_d_aller("droite"))
  return true
end

function poste.essai_marcheur_voir()
  jeu().journal("Poste : marcheur, " .. jeu().voir_le_marcheur())
  return true
end

-- Réveil (V56) : le marcheur après rechargement, retrouvé par son nom, puis éveillé ; retiré à la fin de l'essai.
function poste.essai_marcheur_retrouver()
  jeu().journal("Poste : marcheur, " .. jeu().retrouver_le_marcheur())
  return true
end

function poste.essai_marcheur_eveiller()
  jeu().journal("Poste : marcheur, " .. jeu().eveiller_le_marcheur())
  return true
end

-- S'asseoir et se coucher (V60) : les sièges et lits du jeu les plus proches, une copie posée près d'Henry, l'ordre au
-- marcheur.
function poste.essai_sieges_sonder()
  for _, ligne in ipairs(jeu().sonder_les_sieges()) do
    jeu().journal("Poste : sièges, " .. ligne)
  end
  return true
end

function poste.essai_sieges_relever()
  for _, ligne in ipairs(jeu().relever_les_sieges()) do
    local debut = 1
    while debut <= #ligne do
      jeu().journal("Poste : relevé, " .. string.sub(ligne, debut, debut + 399))
      debut = debut + 400
    end
  end
  return true
end

function poste.essai_siege_poser()
  jeu().journal("Poste : sièges, " .. jeu().poser_un_siege("siege"))
  return true
end

function poste.essai_lit_poser()
  jeu().journal("Poste : sièges, " .. jeu().poser_un_siege("lit"))
  return true
end

function poste.essai_marcheur_asseoir()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_de_prendre_place("siege", 10))
  return true
end

function poste.essai_marcheur_coucher()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_de_prendre_place("lit", 11))
  return true
end

function poste.essai_marcheur_asseoir_reel()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_de_prendre_place("siege", 10, true))
  return true
end

function poste.essai_marcheur_coucher_reel()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_de_prendre_place("lit", 11, true))
  return true
end

-- Meubles utilisables (V66) : le marcheur s'assoit sur le premier banc du camp, se couche sur le premier lit.
function poste.essai_marcheur_asseoir_camp()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_sur_la_place(Scriptorium.camp.objet_du_jeu_de("siege_1"), 10))
  return true
end

function poste.essai_marcheur_coucher_camp()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_sur_la_place(Scriptorium.camp.objet_du_jeu_de("lit_1a"), 11))
  return true
end

-- V70 (fiche 13) : les hommes du camp, nés sur nos âmes, reçoivent les ordres de notre cerveau. Chacun prend un banc du
-- camp, dans l'ordre du plan (un homme par banc), ou sa paillasse ; le Directeur, son lit. On garde la place donnée à
-- chacun pour voir ensuite où il en est.
local places_donnees = {}

local function donner_les_places(ordre, place_de)
  local hommes = Scriptorium.hommes
  local n = 0
  for _, id in ipairs(hommes.liste()) do
    local f = hommes.fiche(id)
    local place = place_de(f)
    local objet = place and Scriptorium.camp.objet_du_jeu_de(place)
    if f.personnage and objet then
      places_donnees[f.personnage] = objet
      jeu().journal("Poste : " .. f.nom .. " → " .. place .. ", " .. jeu().ordonner_sur_la_place(objet, ordre, f.personnage))
      n = n + 1
    else
      jeu().journal("Poste : " .. f.nom .. " : " .. (f.personnage and ("pas de place (" .. tostring(place) .. ")") or "sans personnage"))
    end
  end
  return n
end

function poste.essai_hommes_asseoir()
  local sieges = {}
  for _, e in ipairs(Scriptorium.camp.plan) do
    if e.sorte == "siege" and Scriptorium.camp.objet_du_jeu_de(e.nom) then
      table.insert(sieges, e.nom)
    end
  end
  local rang = 0
  return donner_les_places(10, function()
    rang = rang + 1
    return sieges[rang]
  end) > 0
end

function poste.essai_hommes_coucher()
  return donner_les_places(11, function(f) return f.lit end) > 0
end

function poste.essai_directeur_coucher()
  local personnage = Scriptorium.directeur.personnage()
  local objet = Scriptorium.camp.objet_du_jeu_de("lit_directeur")
  if not personnage or not objet then
    jeu().journal("Poste : Directeur : " .. (personnage and "pas de lit" or "sans personnage"))
    return false
  end
  places_donnees[personnage] = objet
  jeu().journal("Poste : Directeur → lit_directeur, " .. jeu().ordonner_sur_la_place(objet, 11, personnage))
  return true
end

function poste.essai_hommes_voir()
  local hommes = Scriptorium.hommes
  for _, id in ipairs(hommes.liste()) do
    local f = hommes.fiche(id)
    if f.personnage then
      jeu().journal("Poste : " .. f.nom .. " (" .. tostring(f.role) .. ", palier " .. tostring(f.palier) .. ") "
                    .. jeu().voir_sur_la_place(f.personnage, places_donnees[f.personnage]))
    else
      jeu().journal("Poste : " .. f.nom .. " : sans personnage")
    end
  end
  local personnage = Scriptorium.directeur.personnage()
  if personnage then
    jeu().journal("Poste : Directeur " .. jeu().voir_sur_la_place(personnage, places_donnees[personnage]))
  end
  return true
end

-- V71 a (fiche 13) : la sonde d'équipement, sur le premier homme du camp.
local function premier_homme()
  local liste = Scriptorium.hommes.liste()
  local f = liste[1] and Scriptorium.hommes.fiche(liste[1])
  return f and f.personnage, f and f.nom
end

function poste.essai_inventaire_sonder()
  local qui, nom = premier_homme()
  for _, ligne in ipairs(jeu().sonder_l_inventaire(qui)) do
    jeu().journal("Poste : " .. tostring(nom) .. ", " .. ligne)
  end
  return qui ~= nil
end

function poste.essai_equipement_compter()
  local qui, nom = premier_homme()
  jeu().journal("Poste : " .. tostring(nom) .. ", " .. jeu().compter_l_equipement(qui))
  return qui ~= nil
end

local function equiper_la_sonde(quoi)
  local qui, nom = premier_homme()
  jeu().journal("Poste : " .. tostring(nom) .. ", " .. jeu().equiper_la_sonde(qui, quoi))
  return qui ~= nil
end

-- V71 b (fiche 13) : l'équipement pièce par pièce, vu en jeu.
function poste.essai_equipement_voir()
  local hommes = Scriptorium.hommes
  for _, id in ipairs(hommes.liste()) do
    local f = hommes.fiche(id)
    local e = f.equipement or {}
    local porte = hommes.ce_qu_il_porte(id)
    local presents = 0
    for _, objet in ipairs(porte) do
      if f.personnage and jeu().compter_objet(f.personnage, objet) > 0 then
        presents = presents + 1
      end
    end
    local munition = e.armes and jeu().munition_de(e.armes)
    jeu().journal(string.format("Poste : %s (%s, palier %s, famille %s) : %s, %s, %s ; %d pièce(s) à porter, %d dans son sac%s",
      f.nom, f.role, tostring(f.palier), tostring(f.famille), tostring(e.tenue), tostring(e.armes), tostring(e.etat), #porte,
      presents, munition and (", munitions " .. jeu().compter_objet(f.personnage, munition) .. "/" .. tostring(e.munitions)) or ""))
  end
  return true
end

-- V71 c : les quatre à voir (un homme d'armes, un arbalétrier pour ses carreaux, le pavoisier et l'homme d'armes
-- d'hast du palier 3, réponses 2 et 3 de JoVenGer), dans les quatre paillasses du camp.
function poste.essai_equipement_embaucher()
  local hommes = Scriptorium.hommes
  local ids = {}
  for _, contrat in ipairs({
    { role = "homme_d_armes", semaines = 4, palier = 1, famille = "epee_bouclier" },
    { role = "arbaletrier", semaines = 4, palier = 1 },
    { role = "pavoisier", semaines = 4, palier = 3 },
    { role = "homme_d_armes", semaines = 4, palier = 3, famille = "arme_d_hast" },
  }) do
    local id, raison = hommes.embaucher(contrat)
    table.insert(ids, tostring(id or raison))
  end
  jeu().journal("Poste : équipement, engagés = " .. table.concat(ids, ", "))
  poste.battre_les_hommes()
  return true
end

-- L'homme posé devant Henry (le dernier vu) sort son arme.
function poste.essai_equipement_degainer()
  local hommes = Scriptorium.hommes
  local f = poste.dernier_vu and hommes.fiche(poste.dernier_vu)
  if not f then
    return false
  end
  jeu().journal("Poste : " .. f.nom .. ", " .. jeu().degainer(f.personnage))
  return true
end

-- La bascule (V71 b) : refaire porter au premier homme toutes ses pièces sans les ôter d'abord.
function poste.essai_equipement_reporter_sans_oter()
  local hommes = Scriptorium.hommes
  local id = hommes.liste()[1]
  local f = id and hommes.fiche(id)
  if not f then
    return false
  end
  local portes, introuvables = jeu().faire_porter(f.personnage, hommes.ce_qu_il_porte(id), false)
  jeu().journal("Poste : " .. f.nom .. ", refait porter sans ôter : " .. tostring(portes) .. " ; " .. #introuvables .. " refusée(s)")
  return true
end

function poste.essai_equipement_monter()
  local hommes = Scriptorium.hommes
  local id = hommes.liste()[1]
  local f = id and hommes.fiche(id)
  if not f then
    return false
  end
  local ok, raison = hommes.changer_de_palier(id, math.min((f.palier or 1) + 1, 3))
  jeu().journal("Poste : " .. f.nom .. " change de palier : " .. tostring(ok) .. " " .. tostring(raison or ""))
  return ok
end

function poste.essai_equipement_donner()
  local hommes = Scriptorium.hommes
  local id = hommes.liste()[1]
  local piece = (jeu().pieces_de("soldier_generic_6_01") or {})[1]
  local ok, raison = hommes.donner_une_piece(id, piece, 0.5, true)
  jeu().journal("Poste : pièce " .. tostring(piece) .. " donnée à " .. tostring(id) .. " : " .. tostring(ok) .. " " .. tostring(raison or ""))
  return ok
end

local prochain_vu = 0
function poste.essai_equipement_ici_suivant()
  local hommes = Scriptorium.hommes
  local liste = hommes.liste()
  if #liste == 0 then
    return false
  end
  prochain_vu = prochain_vu % #liste + 1
  poste.dernier_vu = liste[prochain_vu]
  local f = hommes.fiche(liste[prochain_vu])
  jeu().journal("Poste : " .. f.nom .. " (" .. f.role .. ", palier " .. tostring(f.palier) .. "), "
    .. jeu().poser_devant_henry(f.personnage))
  return true
end

-- V71 a2 (fiche 13) : le témoin (premier homme) et les deux sondes nées à côté de lui.
local function les_trois()
  local qui, nom = premier_homme()
  local n = jeu().noms_de_la_sonde or {}
  return { { qui, "témoin " .. tostring(nom) }, { n.seule, "sonde seule" }, { n.hors_regles, "sonde hors règles" } }
end

function poste.essai_sonde_naitre()
  local qui = premier_homme()
  for _, ligne in ipairs(jeu().faire_naitre_la_sonde(qui)) do
    jeu().journal("Poste : sonde, " .. ligne)
  end
  return qui ~= nil
end

function poste.essai_sonde_equiper()
  for _, t in ipairs(les_trois()) do
    jeu().journal("Poste : " .. t[2] .. ", " .. jeu().equiper_la_sonde(t[1], "tenue_2"))
    jeu().journal("Poste : " .. t[2] .. ", " .. jeu().equiper_la_sonde(t[1], "armes"))
  end
  return true
end

function poste.essai_sonde_compter()
  for _, t in ipairs(les_trois()) do
    jeu().journal("Poste : " .. t[2] .. ", " .. jeu().compter_l_equipement(t[1]))
  end
  return true
end

function poste.essai_sonde_objets()
  local qui, nom = premier_homme()
  for _, ligne in ipairs(jeu().sonder_les_objets(qui)) do
    jeu().journal("Poste : " .. tostring(nom) .. ", " .. ligne)
  end
  return qui ~= nil
end

-- V71 a3 (fiche 13) : objet par objet sur le premier homme, et un habitant du jeu habillé par le préréglage.
function poste.essai_objets_creer()
  local qui, nom = premier_homme()
  for _, ligne in ipairs(jeu().creer_les_objets_de_la_sonde(qui)) do
    jeu().journal("Poste : " .. tostring(nom) .. ", " .. ligne)
  end
  jeu().journal("Poste : habitant, " .. jeu().habiller_un_habitant())
  return qui ~= nil
end

function poste.essai_objets_relire()
  local qui, nom = premier_homme()
  for _, ligne in ipairs(jeu().relire_les_objets_de_la_sonde(qui)) do
    jeu().journal("Poste : " .. tostring(nom) .. ", " .. ligne)
  end
  jeu().journal("Poste : habitant, " .. jeu().compter_l_habitant())
  return qui ~= nil
end

-- V71 a4 (fiche 13) : le témoin armé pièce par pièce, vu de près, après un puis deux rechargements.
local function sur_le_temoin(action)
  local qui, nom = premier_homme()
  jeu().journal("Poste : témoin " .. tostring(nom) .. ", " .. action(qui))
  return qui ~= nil
end

function poste.essai_temoin_armer() return sur_le_temoin(jeu().armer_le_temoin) end
function poste.essai_temoin_ici() return sur_le_temoin(jeu().poser_devant_henry) end
function poste.essai_temoin_voir() return sur_le_temoin(jeu().voir_le_temoin) end
function poste.essai_temoin_reporter()
  return sur_le_temoin(function(qui)
    local portes, notres = jeu().faire_porter_la_sonde(qui)
    return string.format("%d pièce(s) refaite(s) porter sur %d ; %s", portes, notres, jeu().voir_le_temoin(qui))
  end)
end

-- V71 a5 (fiche 13) : nos pièces reconnues par identifiant, la tenue de naissance retirée.
function poste.essai_pieces_creer() return sur_le_temoin(jeu().creer_les_pieces_notees) end
function poste.essai_pieces_voir() return sur_le_temoin(jeu().voir_les_pieces_notees) end
function poste.essai_pieces_ranger() return sur_le_temoin(jeu().ranger_les_pieces_notees) end

-- V71 a6 (fiche 13) : la tenue de naissance reconnue par sa signature.
local function lignes_du_temoin(action)
  local qui, nom = premier_homme()
  for _, ligne in ipairs(action(qui)) do
    jeu().journal("Poste : témoin " .. tostring(nom) .. ", " .. ligne)
  end
  return qui ~= nil
end

function poste.essai_naissance_noter() return lignes_du_temoin(jeu().noter_la_naissance) end
function poste.essai_inventaire_relever() return lignes_du_temoin(jeu().relever_l_inventaire) end
function poste.essai_signature_ranger() return sur_le_temoin(jeu().ranger_par_signature) end

function poste.essai_equiper_tenue() return equiper_la_sonde("tenue") end
function poste.essai_equiper_tenue_2() return equiper_la_sonde("tenue_2") end
function poste.essai_equiper_armes() return equiper_la_sonde("armes") end

-- Le lit de tente vu à découvert (V69, idée de la conversation Scriptorium) : les petites tentes du camp cachent
-- l'homme couché (V68). Un lit du camp, meuble et place du jeu, avec les mêmes données que le camp, posé à 5 m devant
-- Henry, sans tente ; puis le marcheur s'y couche.
local lit_d_essai = nil

function poste.essai_lit_a_decouvert()
  local camp = Scriptorium.camp
  local henry, cap = jeu().position_du_joueur(), jeu().cap_du_joueur()
  local position, cap_lit = camp.dans_le_monde({ x = henry.x, y = henry.y, z = henry.z, cap = cap }, 0, 5, 0)
  local modele = camp.modeles.lit
  local meuble = jeu().poser_objet("lit", modele.chemin, position, cap_lit, "essai_lit_a_decouvert", modele.classe)
  local du_jeu = camp.objets_du_jeu.lit
  local p = du_jeu.places[1]
  local ici, cap_ici = camp.dans_le_monde({ x = position.x, y = position.y, z = position.z, cap = cap_lit }, p.x, p.y, p.cap)
  lit_d_essai = jeu().poser_objet_du_jeu("essai_lit_a_decouvert_" .. p.nom, ici, cap_ici, du_jeu.proprietes)
  jeu().journal("Poste : lit à découvert, meuble " .. tostring(meuble) .. ", place " .. tostring(lit_d_essai))
  return lit_d_essai ~= nil
end

function poste.essai_marcheur_coucher_a_decouvert()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_sur_la_place(lit_d_essai, 11))
  return true
end

function poste.essai_marcheur_retirer()
  jeu().journal("Poste : marcheur, " .. jeu().retirer_le_marcheur())
  return true
end

-- Combat d'essai (étape 1) : deux âmes au cerveau npc_battle de camps opposés, devant Henry ; puis ce qu'ils deviennent.
local combattants_d_essai = {}

function poste.essai_combat()
  local noms, erreur = jeu().poser_un_combat_d_essai()
  combattants_d_essai = noms or {}
  jeu().journal("Poste : combat, posés = " .. (noms and table.concat(noms, ", ") or ("refus : " .. tostring(erreur))))
  return noms ~= nil
end

function poste.essai_combat_voir()
  local a, b = combattants_d_essai[1], combattants_d_essai[2]
  if not a then
    jeu().journal("Poste : combat, rien de posé")
    return false
  end
  for _, paire in ipairs({ { a, b }, { b, a } }) do
    jeu().journal("Poste : combat « " .. paire[1] .. " » : " .. table.concat(jeu().decrire_personnage(paire[1], paire[2], false), " | "))
  end
  return true
end

-- Bataille : ce que le jeu dit d'un ennemi de la bande au contact et d'un de nos hommes (faction, hostilité, cible,
-- fonctions de leur personnage), puis de chaque ennemi en une ligne (V18, V19).
function poste.essai_sonder()
  local ennemis, bande = ennemis_au_contact()
  local notres = nos_personnages()
  jeu().journal("Poste : sonde, bande = " .. tostring(bande) .. ", ennemis = " .. #ennemis .. ", nôtres = " .. #notres)
  local paires = {}
  if ennemis[1] then table.insert(paires, { ennemis[1], notres[1] }) end
  if notres[1] then table.insert(paires, { notres[1], ennemis[1] }) end
  for _, paire in ipairs(paires) do
    for _, ligne in ipairs(jeu().decrire_personnage(paire[1], paire[2], true)) do
      jeu().journal("Poste : sonde « " .. paire[1] .. " » : " .. ligne)
    end
  end
  for _, identifiant in ipairs(ennemis) do
    local lignes = jeu().decrire_personnage(identifiant, notres[1], false)
    jeu().journal("Poste : ennemi « " .. identifiant .. " » : " .. table.concat(lignes, " | "))
  end
  return #ennemis, #notres
end

-- Bataille : pose la bande au contact à dix-huit mètres devant le camp, en ligne (V18 : à soixante mètres,
-- personne ne voit personne ; vu le 14/10).
function poste.essai_rapprocher()
  local ennemis, bande = ennemis_au_contact()
  local camp = Scriptorium.camp
  for i, identifiant in ipairs(ennemis) do
    jeu().ordonner(identifiant, "approche", jeu().au_sol(camp.point((i - (#ennemis + 1) / 2) * 1.5, 18, 180)), "devant_le_camp")
  end
  jeu().journal("Poste : bande « " .. tostring(bande) .. " » rapprochée, " .. #ennemis .. " ennemi(s) à 18 m")
  return #ennemis
end

-- Henry : posé à douze mètres du premier ennemi de la bande au contact, côté camp (V18 : la bande se bat-elle ?).
function poste.essai_voir_bande()
  local ennemis = ennemis_au_contact()
  if not ennemis[1] then
    jeu().journal("Poste : pas de bande au contact")
    return false
  end
  local ok, compte_rendu = jeu().aller_pres_de(ennemis[1], Scriptorium.camp.point(0, 0, 0), 12)
  jeu().journal("Poste : voir la bande = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

-- Bataille : blesse à mort le premier ennemi encore vivant de la bande au contact (V19 : la mort se voit-elle ?
-- la bataille finit-elle par le jeu quand le dernier tombe ?).
function poste.essai_frapper()
  local ennemis, bande = ennemis_au_contact()
  for _, identifiant in ipairs(ennemis) do
    if not jeu().personnage_mort(identifiant) then
      local ok, erreur = jeu().blesser(identifiant, 1000)
      jeu().journal("Poste : frappé « " .. identifiant .. " » = " .. tostring(ok) .. (erreur and (" (" .. erreur .. ")") or "")
                    .. ", mort = " .. tostring(jeu().personnage_mort(identifiant)) .. ", vivants = " .. jeu().ennemis_vivants(ennemis))
      poste.battre_les_hommes()
      return ok
    end
  end
  jeu().journal("Poste : aucun ennemi vivant dans la bande " .. tostring(bande))
  return false
end

-- Directeur : l'installe, puis écrit le menu de la Gestion du camp au journal.
function poste.essai_directeur()
  local directeur = Scriptorium.directeur
  if not directeur.est_installe() then
    local ok, raison = directeur.installer()
    jeu().journal("Poste : Directeur installé = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or ""))
  end
  for _, e in ipairs(directeur.menu()) do
    jeu().journal("Poste : gestion, " .. e.action .. " : " .. (e.disponible and "possible" or ("impossible (" .. tostring(e.raison) .. ")"))
                  .. ((#e.parametres > 0) and (" ; paramètres : " .. table.concat(e.parametres, ", ")) or ""))
  end
  poste.battre_les_hommes()
  return directeur.menu()
end

-- Directeur : joue une action de la Gestion du camp depuis la console.
-- Exemple : scriptorium_gestion engager role=archer semaines=4
function poste.gestion(action, parametres)
  local ok, resultat = Scriptorium.directeur.agir(action, parametres or {})
  jeu().journal("Poste : gestion « " .. tostring(action) .. " » = " .. tostring(ok) .. " ; " .. tostring(resultat))
  if ok and type(resultat) == "table" then
    for cle, valeur in pairs(resultat) do
      if type(valeur) ~= "table" then
        jeu().journal("  " .. tostring(cle) .. " = " .. tostring(valeur))
      end
    end
  end
  return ok, resultat
end

-- Enceinte : achète le bois qu'il faut, bâtit la palissade puis les tours.
function poste.essai_enceinte()
  local enceinte = Scriptorium.enceinte
  local coffre = Scriptorium.coffre
  local manque = enceinte.reglages.bois_palissade + enceinte.reglages.bois_tours - coffre.reserve("bois")
  if manque > 0 then
    coffre.ajouter_reserve("bois", manque, "essai")
  end
  local sorts = { tostring(enceinte.batir()), tostring(enceinte.batir()) }
  jeu().journal("Poste : enceinte, sorts = " .. table.concat(sorts, ", ") .. " ; niveau = " .. enceinte.niveau()
                .. ", porte = " .. enceinte.porte())
  poste.battre_les_hommes()
  return sorts
end

-- Modèles : pose huit modèles en cercle à 8 m d'Henry, un tous les 45° (cap de boussole), pour voir lesquels
-- le jeu dessine (14/10 : pans et tours de l'enceinte restaient invisibles, le portail et les tentes non).
-- Un second appel retire les huit précédents.
poste.modeles_a_essayer = {
  "Objects/manmade/structures/living/tents/tent_small_a.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_b_v4.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_b_v4_trosky.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_a_v2.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_makeshift_a_v2.cgf",
  "Objects/manmade/structures/defensive/watchtowers/watchtower_a.cgf",
  "Objects/manmade/structures/logistical/fences/fence_4rod_gate_02.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_b_v2.cgf",
}

function poste.essai_modeles()
  for i = 1, #poste.modeles_a_essayer do
    jeu().retirer_objet("scriptorium_essai_modele_" .. i)
  end
  if poste.modeles_poses then
    poste.modeles_poses = nil
    jeu().journal("Poste : modèles d'essai retirés")
    return true
  end
  local ici = jeu().position_du_joueur()
  for i, chemin in ipairs(poste.modeles_a_essayer) do
    local cap = (i - 1) * 45
    local a = math.rad(cap)
    local p = { x = ici.x + 8 * math.sin(a), y = ici.y + 8 * math.cos(a), z = ici.z }
    local identifiant = jeu().poser_objet("essai", chemin, p, (cap + 90) % 360, "essai_modele_" .. i)
    jeu().journal("Poste : modèle d'essai au cap " .. cap .. " : " .. chemin .. " = " .. tostring(identifiant))
  end
  poste.modeles_poses = true
  return true
end

-- Enceinte : pose Henry à 4 m de la porte, côté camp, pour la regarder de près.
function poste.essai_voir_porte()
  local centre = Scriptorium.camp.point(0, 0, 0)
  if not centre then
    jeu().journal("Poste : pas de camp")
    return false
  end
  local porte = Scriptorium.enceinte.objet_de("porte")
  if not porte then
    jeu().journal("Poste : pas de porte posée")
    return false
  end
  local ok, compte_rendu = jeu().aller_pres_de(porte, centre, 4)
  jeu().journal("Poste : voir la porte = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

-- Porte : la fait passer d'ouverte à fermée, ou de fermée à ouverte (V22).
function poste.essai_porte()
  local enceinte = Scriptorium.enceinte
  local avant = enceinte.porte()
  local ok, raison
  if avant == "ouverte" then
    ok, raison = enceinte.fermer()
  else
    ok, raison = enceinte.ouvrir()
  end
  jeu().journal("Poste : porte, avant = " .. tostring(avant) .. ", après = " .. tostring(enceinte.porte())
                .. (ok and "" or (" (" .. tostring(raison) .. ")")))
  return ok
end

-- Discipline : écrit les fautes à juger et la réputation au journal.
function poste.essai_discipline()
  local discipline = Scriptorium.discipline
  local fautes = discipline.a_juger()
  jeu().journal("Poste : discipline, réputation = " .. discipline.reputation() .. ", fautes à juger = " .. #fautes)
  for _, f in ipairs(fautes) do
    jeu().journal("  " .. f.id .. " : " .. f.sorte .. " par " .. f.nom)
  end
  return fautes
end

-- Résumé du socle dans le journal.
function poste.bilan()
  for _, morceau in ipairs(Scriptorium.morceaux) do
    jeu().journal("Poste : morceau « " .. morceau.nom .. " » : " .. (morceau.pret and "prêt" or ("en panne : " .. tostring(morceau.erreur))))
  end
  local effectif = Scriptorium.hommes.effectif()
  jeu().journal("Poste : hommes, total = " .. effectif.nombre .. ", valides = " .. effectif.valides
                .. ", blessés = " .. effectif.blesses .. ", présents = " .. effectif.presents)
  local resultats = Scriptorium.bataille.resultats()
  jeu().journal("Poste : batailles, en cours = " .. #Scriptorium.bataille.bandes() .. ", jouées = " .. #resultats
                .. (resultats[#resultats] and (", dernière : " .. resultats[#resultats].issue) or ""))
  local comptes = Scriptorium.bandeau.comptes()
  jeu().journal("Poste : bandeau, affichés = " .. comptes.affiches .. ", regroupés = " .. comptes.regroupes
                .. ", répétés = " .. comptes.repetes .. ", refusés = " .. comptes.refuses)
end

-- Les commandes du poste, dans l'ordre : la console et le fichier d'ordres en lisent la même liste
-- (outils/ordonner.py aussi, pour refuser un nom inconnu avant de l'écrire).
poste.commandes = {
  { nom = "scriptorium_essai_bandeau", fonction = function() return poste.essai_bandeau() end, aide = "Essai du bandeau des messages" },
  { nom = "scriptorium_essai_registre", fonction = function() return poste.essai_registre() end, aide = "Essai du registre" },
  { nom = "scriptorium_essai_coffre", fonction = function() return poste.essai_coffre() end, aide = "Essai du coffre" },
  { nom = "scriptorium_essai_jetons_ecrire", fonction = function() return poste.essai_jetons_ecrire() end, aide = "Écrit des jetons de 16 000 à 200 000 caractères et les relit" },
  { nom = "scriptorium_essai_jetons_relire", fonction = function() return poste.essai_jetons_relire() end, aide = "Relit les jetons d'essai après rechargement" },
  { nom = "scriptorium_essai_cerveau", fonction = function() return poste.essai_cerveau() end, aide = "Nos hommes sont-ils connus de l'IA du jeu ? Comparaison avec un habitant" },
  { nom = "scriptorium_essai_liens", fonction = function() return poste.essai_liens() end, aide = "Liens de l'habitant le plus proche (moteur et IA)" },
  { nom = "scriptorium_essai_marcheur", fonction = function() return poste.essai_marcheur() end, aide = "Un homme au cerveau du mod, qui marche vers un point de son cerveau" },
  { nom = "scriptorium_essai_marcheur_point", fonction = function() return poste.essai_marcheur_point() end, aide = "Donne au marcheur un autre point" },
  { nom = "scriptorium_essai_marcheur_assis", fonction = function() return poste.essai_marcheur_assis() end, aide = "Ordre au marcheur : s'asseoir par terre" },
  { nom = "scriptorium_essai_marcheur_debout", fonction = function() return poste.essai_marcheur_debout() end, aide = "Ordre au marcheur : se relever et marcher au point" },
  { nom = "scriptorium_essai_marcheur_rejoindre", fonction = function() return poste.essai_marcheur_rejoindre() end, aide = "Le marcheur rejoint l'adversaire désigné par sa variable de cerveau" },
  { nom = "scriptorium_essai_marcheur_combat", fonction = function() return poste.essai_marcheur_combat() end, aide = "Un adversaire du mod ; le marcheur et lui se battent" },
  { nom = "scriptorium_essai_marcheur_brigand", fonction = function() return poste.essai_marcheur_brigand() end, aide = "Un brigand au cerveau du mod ; le marcheur et lui se battent" },
  { nom = "scriptorium_essai_marcheur_contre_henry", fonction = function() return poste.essai_marcheur_contre_henry() end, aide = "Ordre au marcheur : se battre contre Henry" },
  { nom = "scriptorium_essai_brigand_du_jeu", fonction = function() return poste.essai_brigand_du_jeu() end, aide = "Un brigand du jeu (son âme, son cerveau), éveillé, à 8 m devant Henry" },
  { nom = "scriptorium_essai_brigand_voir", fonction = function() return poste.essai_brigand_voir() end, aide = "Ce que fait le brigand du jeu ; santé d'Henry" },
  { nom = "scriptorium_essai_coup_recu", fonction = function() return poste.essai_coup_recu() end, aide = "Le marcheur reçoit un coup léger de l'adversaire" },
  { nom = "scriptorium_essai_henry_frappe", fonction = function() return poste.essai_henry_frappe() end, aide = "Henry porte un vrai coup au brigand du jeu (règles du jeu)" },
  { nom = "scriptorium_essai_henry_frappe_habitant", fonction = function() return poste.essai_henry_frappe_habitant() end, aide = "Le même coup sur l'habitant de la carte le plus proche (contrôle)" },
  { nom = "scriptorium_essai_habitant_voir", fonction = function() return poste.essai_habitant_voir() end, aide = "Ce que devient l'habitant frappé" },
  { nom = "scriptorium_essai_brigand_naissance", fonction = function() return poste.essai_brigand_naissance() end, aide = "Annonce à l'IA la naissance du brigand du jeu (XGenAIModule.OnSpawn, OnStart)" },
  { nom = "scriptorium_essai_marcheur_frappe", fonction = function() return poste.essai_marcheur_frappe() end, aide = "Un vrai coup du marcheur au brigand du jeu (règles du jeu)" },
  { nom = "scriptorium_essai_marcheur_effleure", fonction = function() return poste.essai_marcheur_effleure() end, aide = "Un coup à 0 point du marcheur au brigand du jeu" },
  { nom = "scriptorium_essai_henry_effleure", fonction = function() return poste.essai_henry_effleure() end, aide = "Un coup à 0 point d'Henry au brigand du jeu" },
  { nom = "scriptorium_essai_marcheur_attaque", fonction = function() return poste.essai_marcheur_attaque() end, aide = "Le marcheur demande au jeu d'attaquer le brigand du jeu (ordre 8)" },
  { nom = "scriptorium_essai_henry_effleure_marcheur", fonction = function() return poste.essai_henry_effleure_marcheur() end, aide = "Un coup à 0 point d'Henry au marcheur" },
  { nom = "scriptorium_essai_adversaire_brigand", fonction = function() return poste.essai_adversaire_brigand() end, aide = "Un adversaire à âme de brigand et à notre cerveau, posé seul" },
  { nom = "scriptorium_essai_henry_effleure_adversaire", fonction = function() return poste.essai_henry_effleure_adversaire() end, aide = "Un coup à 0 point d'Henry à l'adversaire" },
  { nom = "scriptorium_essai_garde_du_jeu", fonction = function() return poste.essai_garde_du_jeu() end, aide = "Un garde du jeu (son âme, son cerveau), éveillé, à 4 m d'Henry" },
  { nom = "scriptorium_essai_garde_voir", fonction = function() return poste.essai_garde_voir() end, aide = "Ce que fait le garde du jeu ; santé du brigand du jeu" },
  { nom = "scriptorium_essai_marcheur_attaque_adversaire", fonction = function() return poste.essai_marcheur_attaque_adversaire() end, aide = "Le marcheur attaque l'adversaire (ordre 8)" },
  { nom = "scriptorium_essai_marcheur_armer", fonction = function() return poste.essai_marcheur_armer() end, aide = "Le marcheur tire son arme ; ses compétences de combat" },
  { nom = "scriptorium_essai_prairie", fonction = function() return poste.essai_prairie() end, aide = "Henry posé sur la prairie des essais de combat" },
  { nom = "scriptorium_essai_marcheur_competences", fonction = function() return poste.essai_marcheur_competences() end, aide = "Les compétences de combat du marcheur posées à 20, puis relues" },
  { nom = "scriptorium_essai_brigand_leger", fonction = function() return poste.essai_brigand_leger() end, aide = "Un brigand du jeu plus léger (kkop_bandit_7), éveillé, à 8 m devant Henry" },
  { nom = "scriptorium_essai_marcheur_aller", fonction = function() return poste.essai_marcheur_aller() end, aide = "Le marcheur va au point (8 m à droite d'Henry), en interruption (ordre 9)" },
  { nom = "scriptorium_essai_marcheur_voir", fonction = function() return poste.essai_marcheur_voir() end, aide = "Où en est le marcheur" },
  { nom = "scriptorium_essai_marcheur_retrouver", fonction = function() return poste.essai_marcheur_retrouver() end, aide = "Après rechargement : le marcheur retrouvé par son nom, et ce que garde son cerveau" },
  { nom = "scriptorium_essai_marcheur_eveiller", fonction = function() return poste.essai_marcheur_eveiller() end, aide = "Le marcheur retrouvé est éveillé comme à sa naissance" },
  { nom = "scriptorium_essai_marcheur_retirer", fonction = function() return poste.essai_marcheur_retirer() end, aide = "Retire le marcheur du monde" },
  { nom = "scriptorium_essai_sieges_sonder", fonction = function() return poste.essai_sieges_sonder() end, aide = "Les sièges et lits du jeu les plus proches d'Henry" },
  { nom = "scriptorium_essai_siege_poser", fonction = function() return poste.essai_siege_poser() end, aide = "Pose près d'Henry une copie du siège du jeu le plus proche" },
  { nom = "scriptorium_essai_marcheur_asseoir_camp", fonction = function() return poste.essai_marcheur_asseoir_camp() end, aide = "Le marcheur s'assoit sur le premier banc du camp (ordre 10)" },
  { nom = "scriptorium_essai_marcheur_coucher_camp", fonction = function() return poste.essai_marcheur_coucher_camp() end, aide = "Le marcheur se couche sur le premier lit du camp (ordre 11)" },
  { nom = "scriptorium_essai_inventaire_sonder", fonction = function() return poste.essai_inventaire_sonder() end, aide = "Fonctions de l'inventaire et de l'acteur du premier homme (V71 a)" },
  { nom = "scriptorium_essai_equipement_compter", fonction = function() return poste.essai_equipement_compter() end, aide = "Compte les pièces des tenues et des armes de la sonde sur le premier homme" },
  { nom = "scriptorium_essai_equiper_tenue", fonction = function() return poste.essai_equiper_tenue() end, aide = "Pose la tenue soldier_generic_1_01 sur le premier homme, puis compte" },
  { nom = "scriptorium_essai_equiper_tenue_lourde", fonction = function() return poste.essai_equiper_tenue_2() end, aide = "Pose la tenue soldier_generic_5_01 sur le premier homme, puis compte" },
  { nom = "scriptorium_essai_equiper_armes", fonction = function() return poste.essai_equiper_armes() end, aide = "Pose les armes sword_shield_3_01 sur le premier homme, puis compte" },
  { nom = "scriptorium_essai_sonde_naitre", fonction = function() return poste.essai_sonde_naitre() end, aide = "Fait naître les deux sondes près du premier homme (V71 a2)" },
  { nom = "scriptorium_essai_sonde_equiper", fonction = function() return poste.essai_sonde_equiper() end, aide = "Pose la tenue lourde et les armes sur le premier homme et les deux sondes, puis compte" },
  { nom = "scriptorium_essai_sonde_compter", fonction = function() return poste.essai_sonde_compter() end, aide = "Compte l'équipement du premier homme et des deux sondes" },
  { nom = "scriptorium_essai_sonde_objets", fonction = function() return poste.essai_sonde_objets() end, aide = "Ce que rendent GetInventoryTable et ItemManager pour le premier homme" },
  { nom = "scriptorium_essai_objets_creer", fonction = function() return poste.essai_objets_creer() end, aide = "Crée trois objets avec leur état sur le premier homme, et habille l'habitant le plus proche (V71 a3)" },
  { nom = "scriptorium_essai_objets_relire", fonction = function() return poste.essai_objets_relire() end, aide = "Relit les objets créés (nombre, état) et la tenue de l'habitant" },
  { nom = "scriptorium_essai_temoin_armer", fonction = function() return poste.essai_temoin_armer() end, aide = "Crée et fait porter au premier homme la tenue lourde, l'épée et l'écu, pièce par pièce, état 0,6 (V71 a4)" },
  { nom = "scriptorium_essai_temoin_ici", fonction = function() return poste.essai_temoin_ici() end, aide = "Pose le premier homme à 3 m devant Henry, face à lui" },
  { nom = "scriptorium_essai_temoin_voir", fonction = function() return poste.essai_temoin_voir() end, aide = "Trie l'inventaire du premier homme : nos pièces (état 0,6) et les autres" },
  { nom = "scriptorium_essai_temoin_reporter", fonction = function() return poste.essai_temoin_reporter() end, aide = "Refait porter au premier homme nos pièces" },
  { nom = "scriptorium_essai_pieces_creer", fonction = function() return poste.essai_pieces_creer() end, aide = "Crée et fait porter au premier homme 13 pièces, leurs identifiants notés dans un jeton (V71 a5)" },
  { nom = "scriptorium_essai_pieces_voir", fonction = function() return poste.essai_pieces_voir() end, aide = "Reconnaît les pièces notées du premier homme par leur identifiant" },
  { nom = "scriptorium_essai_pieces_ranger", fonction = function() return poste.essai_pieces_ranger() end, aide = "Refait porter les pièces notées et retire toutes les autres (rien si une pièce notée manque)" },
  { nom = "scriptorium_essai_naissance_noter", fonction = function() return poste.essai_naissance_noter() end, aide = "Note la signature de la tenue de naissance du premier homme (objet et état de chaque pièce, V71 a6)" },
  { nom = "scriptorium_essai_inventaire_relever", fonction = function() return poste.essai_inventaire_relever() end, aide = "Relève l'inventaire du premier homme et le compare à la signature de naissance" },
  { nom = "scriptorium_essai_signature_ranger", fonction = function() return poste.essai_signature_ranger() end, aide = "Refait porter ses pièces et retire celles de la signature de naissance (garde-fous)" },
  { nom = "scriptorium_essai_equipement_voir", fonction = function() return poste.essai_equipement_voir() end, aide = "Équipement de chaque homme : préréglages, état, pièces dans son sac, munitions (V71 b)" },
  { nom = "scriptorium_essai_equipement_embaucher", fonction = function() return poste.essai_equipement_embaucher() end, aide = "Embauche un pavoisier et un homme d'armes (armes d'hast), palier 3" },
  { nom = "scriptorium_essai_equipement_degainer", fonction = function() return poste.essai_equipement_degainer() end, aide = "L'homme posé devant Henry sort son arme (V71 c)" },
  { nom = "scriptorium_essai_equipement_reporter_sans_oter", fonction = function() return poste.essai_equipement_reporter_sans_oter() end, aide = "Refait porter au premier homme toutes ses pièces sans les ôter (la bascule, V71 c)" },
  { nom = "scriptorium_essai_equipement_monter", fonction = function() return poste.essai_equipement_monter() end, aide = "Le premier homme monte d'un palier" },
  { nom = "scriptorium_essai_equipement_donner", fonction = function() return poste.essai_equipement_donner() end, aide = "Donne au premier homme une pièce de soldier_generic_6_01, état 0,5, portée" },
  { nom = "scriptorium_essai_equipement_ici_suivant", fonction = function() return poste.essai_equipement_ici_suivant() end, aide = "Pose l'homme suivant à 3 m devant Henry" },
  { nom = "scriptorium_essai_hommes_asseoir", fonction = function() return poste.essai_hommes_asseoir() end, aide = "Chaque homme du camp s'assoit sur un banc du camp (ordre 10)" },
  { nom = "scriptorium_essai_hommes_coucher", fonction = function() return poste.essai_hommes_coucher() end, aide = "Chaque homme du camp se couche sur sa paillasse (ordre 11)" },
  { nom = "scriptorium_essai_directeur_coucher", fonction = function() return poste.essai_directeur_coucher() end, aide = "Le Directeur se couche sur son lit (ordre 11)" },
  { nom = "scriptorium_essai_hommes_voir", fonction = function() return poste.essai_hommes_voir() end, aide = "Où en est chaque homme et le Directeur : écart à sa place, assis, couchés, âme" },
  { nom = "scriptorium_essai_lit_a_decouvert", fonction = function() return poste.essai_lit_a_decouvert() end, aide = "Un lit du camp (meuble et place du jeu) à 5 m devant Henry, sans tente" },
  { nom = "scriptorium_essai_marcheur_coucher_a_decouvert", fonction = function() return poste.essai_marcheur_coucher_a_decouvert() end, aide = "Le marcheur se couche sur le lit à découvert (ordre 11)" },
  { nom = "scriptorium_essai_sieges_relever", fonction = function() return poste.essai_sieges_relever() end, aide = "Propriétés complètes des sièges et lits du jeu à copier ; écart des places d'un banc" },
  { nom = "scriptorium_essai_lit_poser", fonction = function() return poste.essai_lit_poser() end, aide = "Pose près d'Henry une copie du lit du jeu le plus proche" },
  { nom = "scriptorium_essai_marcheur_asseoir", fonction = function() return poste.essai_marcheur_asseoir() end, aide = "Le marcheur s'assoit sur le siège posé (ordre 10)" },
  { nom = "scriptorium_essai_marcheur_coucher", fonction = function() return poste.essai_marcheur_coucher() end, aide = "Le marcheur se couche sur le lit posé (ordre 11)" },
  { nom = "scriptorium_essai_marcheur_asseoir_reel", fonction = function() return poste.essai_marcheur_asseoir_reel() end, aide = "Le marcheur s'assoit sur le siège du jeu le plus proche (ordre 10)" },
  { nom = "scriptorium_essai_marcheur_coucher_reel", fonction = function() return poste.essai_marcheur_coucher_reel() end, aide = "Le marcheur se couche sur le lit du jeu le plus proche (ordre 11)" },
  { nom = "scriptorium_essai_combat", fonction = function() return poste.essai_combat() end, aide = "Deux combattants npc_battle de camps opposés devant Henry" },
  { nom = "scriptorium_essai_combat_voir", fonction = function() return poste.essai_combat_voir() end, aide = "Ce que deviennent les deux combattants d'essai" },
  { nom = "scriptorium_essai_registre_tranches", fonction = function() return poste.essai_registre_tranches() end, aide = "Ce que le jeu garde du registre en tranches ; nombres justes en simple précision" },
  { nom = "scriptorium_essai_camp", fonction = function() return poste.essai_camp() end, aide = "Fonde le camp où se tient Henry, ou le redresse" },
  { nom = "scriptorium_essai_camp_agrandir", fonction = function() return poste.essai_camp_agrandir() end, aide = "Agrandit le camp d'un niveau" },
  { nom = "scriptorium_essai_feu", fonction = function() return poste.essai_feu() end, aide = "Ce que le jeu dit du feu, d'un banc et d'une tente" },
  { nom = "scriptorium_essai_aller_nord", fonction = function() return poste.essai_aller(0) end, aide = "Pose Henry quarante mètres au nord" },
  { nom = "scriptorium_essai_aller_est", fonction = function() return poste.essai_aller(90) end, aide = "Pose Henry quarante mètres à l'est" },
  { nom = "scriptorium_essai_aller_sud", fonction = function() return poste.essai_aller(180) end, aide = "Pose Henry quarante mètres au sud" },
  { nom = "scriptorium_essai_aller_ouest", fonction = function() return poste.essai_aller(270) end, aide = "Pose Henry quarante mètres à l'ouest" },
  { nom = "scriptorium_essai_terrain_d_essai", fonction = function() return poste.essai_terrain_d_essai() end, aide = "Lève le camp et pose Henry sur le terrain d'essai" },
  { nom = "scriptorium_essai_camp_lever", fonction = function() return poste.essai_camp_lever() end, aide = "Lève le camp" },
  { nom = "scriptorium_essai_tout_lever", fonction = function() return poste.essai_tout_lever() end, aide = "Renvoie les hommes, congédie le Directeur et lève le camp" },
  { nom = "scriptorium_essai_hommes", fonction = function() return poste.essai_hommes() end, aide = "Engage trois hommes et lance leur journée" },
  { nom = "scriptorium_essai_bataille", fonction = function() return poste.essai_bataille() end, aide = "Lève une bande de cinq brigands venant du nord" },
  { nom = "scriptorium_essai_sonder", fonction = function() return poste.essai_sonder() end, aide = "Ce que le jeu dit des ennemis au contact et de nos hommes" },
  { nom = "scriptorium_essai_rapprocher", fonction = function() return poste.essai_rapprocher() end, aide = "Pose la bande au contact à 18 m devant le camp" },
  { nom = "scriptorium_essai_voir_bande", fonction = function() return poste.essai_voir_bande() end, aide = "Pose Henry à 12 m de la bande, côté camp" },
  { nom = "scriptorium_essai_frapper", fonction = function() return poste.essai_frapper() end, aide = "Blesse à mort le premier ennemi vivant de la bande" },
  { nom = "scriptorium_essai_directeur", fonction = function() return poste.essai_directeur() end, aide = "Installe le Directeur et écrit le menu de la Gestion du camp" },
  { nom = "scriptorium_gestion_rapport", fonction = function() return poste.gestion("rapport") end, aide = "Le rapport du Directeur" },
  { nom = "scriptorium_essai_enceinte", fonction = function() return poste.essai_enceinte() end, aide = "Bâtit la palissade et les tours" },
  { nom = "scriptorium_essai_porte", fonction = function() return poste.essai_porte() end, aide = "Ouvre la porte fermée, ou ferme la porte ouverte" },
  { nom = "scriptorium_essai_voir_porte", fonction = function() return poste.essai_voir_porte() end, aide = "Pose Henry à 4 m de la porte, côté camp" },
  { nom = "scriptorium_essai_modeles", fonction = function() return poste.essai_modeles() end, aide = "Pose huit modèles autour d'Henry, ou les retire" },
  { nom = "scriptorium_essai_patrouille", fonction = function() return poste.essai_patrouille() end, aide = "Envoie deux hommes faire la ronde proche" },
  { nom = "scriptorium_essai_discipline", fonction = function() return poste.essai_discipline() end, aide = "Les fautes à juger et la réputation" },
  { nom = "scriptorium_bilan", fonction = function() return poste.bilan() end, aide = "Bilan du socle dans le journal" },
}

local function trouver_commande(nom)
  for _, commande in ipairs(poste.commandes) do
    if commande.nom == nom then
      return commande
    end
  end
  return nil
end

-- Exécute une commande du poste par son nom. Une commande qui casse est notée au journal.
function poste.executer(nom)
  local commande = trouver_commande(nom)
  if not commande then
    jeu().journal("Poste : commande inconnue « " .. tostring(nom) .. " »")
    return false
  end
  local ok, erreur = pcall(commande.fonction)
  if not ok then
    jeu().journal("Poste : « " .. nom .. " » en erreur : " .. tostring(erreur))
  end
  return ok
end

-- Ordres par fichier. Le PC écrit Mods/scriptorium_socle/ordres.lua (outils/ordonner.py) :
--   return { numero = N, commande = "scriptorium_…" }
-- Le poste le relit à chaque battement ; un ordre au numéro plus grand que le dernier vu est exécuté
-- une seule fois, et seulement quand une partie est en cours (sinon il attend). L'ordre déjà présent
-- au lancement du jeu est ancien : il n'est pas rejoué.
poste.reglages = {
  cadence_ms = 2000,       -- intervalle entre deux relevés du fichier d'ordres
  tours_par_veille = 15,   -- une ligne de veille au journal tous les 15 relevés (30 secondes)
}

local ordres

function poste.remettre_a_zero()
  ordres = { premier_releve = true, dernier = 0, chemin = nil, raison = nil, attente = nil, tours = 0, partie = nil,
             actif = false, generation = 0 }
end
poste.remettre_a_zero()

local function noter_raison(raison)
  if raison ~= ordres.raison then
    ordres.raison = raison
    if raison then
      jeu().journal("Poste : fichier d'ordres illisible : " .. raison)
    end
  end
end

-- Un relevé du fichier d'ordres. Rend « absent », « illisible », « ancien », « deja_fait »,
-- « en_attente », « refuse » ou « execute ».
function poste.relever_ordres()
  local donnees, chemin, raison = jeu().lire_ordres()
  if chemin and chemin ~= ordres.chemin then
    ordres.chemin = chemin
    jeu().journal("Poste : fichier d'ordres trouvé à « " .. chemin .. " »")
  end
  if donnees == nil then
    noter_raison(raison)
    if ordres.premier_releve then
      ordres.premier_releve = false
      if not raison then
        jeu().journal("Poste : pas de fichier d'ordres au lancement")
      end
    end
    return raison and "illisible" or "absent"
  end
  if type(donnees.numero) ~= "number" or type(donnees.commande) ~= "string" then
    noter_raison("numéro ou commande manquant")
    ordres.premier_releve = false
    return "illisible"
  end
  noter_raison(nil)
  local numero, nom = donnees.numero, donnees.commande
  if ordres.premier_releve then
    ordres.premier_releve = false
    ordres.dernier = numero
    jeu().journal("Poste : ordre n° " .. numero .. " (" .. nom .. ") trouvé au lancement, non rejoué")
    return "ancien"
  end
  if numero <= ordres.dernier then
    return "deja_fait"
  end
  if not trouver_commande(nom) then
    ordres.dernier = numero
    jeu().journal("Poste : ordre n° " .. numero .. " refusé : commande inconnue « " .. nom .. " »")
    return "refuse"
  end
  if not jeu().partie_en_cours() then
    if ordres.attente ~= numero then
      ordres.attente = numero
      jeu().journal("Poste : ordre n° " .. numero .. " (" .. nom .. ") en attente d'une partie")
    end
    return "en_attente"
  end
  ordres.dernier = numero
  ordres.attente = nil
  jeu().journal("Poste : ordre n° " .. numero .. " : " .. nom)
  poste.executer(nom)
  return "execute"
end

-- Ligne de veille : dit au journal si les minuteries tournent encore, et où en sont le bandeau et les ordres.
function poste.veiller()
  local partie = jeu().partie_en_cours()
  ordres.tours = ordres.tours + 1
  if partie ~= ordres.partie or ordres.tours >= poste.reglages.tours_par_veille then
    ordres.partie = partie
    ordres.tours = 0
    local comptes = Scriptorium.bandeau.comptes()
    jeu().journal("Poste : veille, partie en cours = " .. tostring(partie)
                  .. ", bandeau en attente = " .. Scriptorium.bandeau.en_attente()
                  .. ", affichés = " .. comptes.affiches .. ", dernier ordre = " .. ordres.dernier
                  .. string.format(", heure du jeu = %.2f", jeu().heure_du_jeu())
                  .. (jeu().temps_arrete and (", temps arrêté = " .. tostring(jeu().temps_arrete())) or ""))
  end
end

-- Fait battre le poste tout seul : relevé des ordres, puis veille.
function poste.demarrer()
  if ordres.actif then
    return
  end
  ordres.actif = true
  ordres.generation = ordres.generation + 1
  local generation = ordres.generation
  local function battement()
    if not ordres.actif or ordres.generation ~= generation then
      return
    end
    local ok, erreur = pcall(poste.relever_ordres)
    if not ok then
      jeu().journal("Poste : erreur au relevé des ordres : " .. tostring(erreur))
    end
    ok, erreur = pcall(poste.veiller)
    if not ok then
      jeu().journal("Poste : erreur à la veille : " .. tostring(erreur))
    end
    jeu().minuterie(poste.reglages.cadence_ms, battement)
  end
  jeu().minuterie(poste.reglages.cadence_ms, battement)
end

function poste.arreter()
  ordres.actif = false
end

-- Entrée en partie : repose la minuterie (celle du démarrage du mod ne tire jamais en jeu).
function poste.relancer()
  ordres.actif = false
  poste.demarrer()
end

Scriptorium.declarer_morceau("poste", function()
  for _, commande in ipairs(poste.commandes) do
    jeu().commande(commande.nom, Scriptorium.chemin .. ".poste.executer('" .. commande.nom .. "')", commande.aide)
  end
  poste.demarrer()
end)

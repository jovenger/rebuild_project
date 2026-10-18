-- Liaison avec le jeu : le seul fichier du socle qui parle au moteur.
-- Tout le reste du socle passe par Scriptorium.jeu.<fonction>().
-- Les essais remplacent Scriptorium.jeu par un faux jeu (essais/lua/faux_jeu.lua).
--
-- Chaque fonction marquée « à vérifier en jeu » repose sur un appel du moteur
-- qui n'a pas encore été confirmé sur le PC de JoVenGer. Voir docs/socle/essai_en_jeu.md.

local Scriptorium = Scriptorium

-- V73 g 0 (le rechargement, demande du pair) : relue dans le jeu ouvert (outils/recharger.py), la liaison reprend sa
-- table : sa mémoire, ses écouteurs, ses accroches et ses relevés sont gardés ; seules ses fonctions et ses constantes
-- sont remplacées. Son état de fichier vit dans « etat_du_fichier », jamais remis à zéro par une relecture.
local liaison = Scriptorium.liaison_reelle or {}
liaison.etat_du_fichier = liaison.etat_du_fichier
  or { forme_du_dialogue = nil, poses_fermees = {}, identite_de_la_partie = nil, jeton_essaye = false, tranches_ecrites = 0 }
local etat_du_fichier = liaison.etat_du_fichier

-- Mémoire de secours pour le registre, le temps que le mécanisme de sauvegarde
-- du jeu soit confirmé : elle ne survit pas à la fermeture du jeu.
-- « identite » (V73 f 3 b, relecture du pair) : l'identité de la partie en cours, gardée en mémoire Lua (elle survit
-- au passage d'une carte à l'autre, et n'est jamais vidée à l'entrée en partie) ; « carte » et « carte_d_avant » : la
-- carte lue à l'entrée en partie, et celle de l'entrée précédente ; « heure_ecrite » : l'heure du jeu de la dernière
-- écriture du registre.
liaison.memoire = liaison.memoire or { registre = nil, identite = nil, carte = nil, carte_d_avant = nil, heure_ecrite = nil }
-- Fiche 01, l'écriture par case : la mémoire de secours de l'index et de chaque case.
liaison.memoire.cases = liaison.memoire.cases or {}
-- La règle du passage, accrochée par le noyau (sans elle, aucun passage n'est cru).
liaison.passage_croyable = liaison.passage_croyable
function liaison.accrocher_le_passage(fonction)
  liaison.passage_croyable = fonction
end

-- Temps du moteur, en secondes (pas le temps du jeu : l'horloge réelle).
function liaison.maintenant()
  return System.GetCurrTime()
end

-- Fiche 01 (vu en jeu le 17/10 : System.GetCurrTime n'avance pas pendant une image, une écriture y durait « 0,0 ms ») :
-- une horloge fine pour mesurer une durée dans la même image : os.clock (temps de calcul) s'il existe, sinon l'horloge
-- du moteur. Rend les secondes et le nom de la source.
function liaison.chrono()
  if os and type(os.clock) == "function" then
    local ok, t = pcall(os.clock)
    if ok and type(t) == "number" then
      return t, "os.clock"
    end
  end
  return System.GetCurrTime(), "System.GetCurrTime"
end

-- Journal du jeu (fichier de journal et console), jamais l'écran du joueur.
function liaison.journal(texte)
  System.LogAlways("[Scriptorium] " .. tostring(texte))
end

-- Affiche un texte au joueur, en bas de l'écran, en blanc sur une bande sombre à la taille du texte
-- (décision D8, demande de JoVenGer du 14/10) : la ligne des sous-titres de l'élément d'interface « hud »
-- (fonctions SetSubtitles et SetSubtitleBgEnable, lues dans Libs/UI/UIElements/HUD.xml du jeu).
-- Game.SendInfoText est écarté : il écrit au milieu de l'écran (vu en jeu le 14/10).
-- La bande sombre est mise le temps du message ; effacer() rend au joueur son réglage (wh_ui_EnableSubtitleBg).
-- Le bandeau efface lui-même à la fin de la durée. Avec un complément (un nom, un montant), il est ajouté
-- après le texte. À vérifier en jeu : que « @clé » est traduit dans cette ligne, avec ou sans complément.
-- « qui » (l'alerte, demande de JoVenGer du 18/10 : « Alerte » à part, en couleur si possible) : le nom de celui qui
-- parle, deuxième argument de SetSubtitles (Libs/UI/UIElements/HUD.xml : SpeakerName), affiché par
-- SetSubtitleSpeakerNameEnable le temps du message ; effacer() rend au joueur son réglage
-- (wh_ui_EnableSubtitleSpeakerName). Une balise de couleur dans le texte est lue mais sa couleur ignorée (vu en jeu le
-- 18/10, premier essai de la sonde).
function liaison.afficher(texte, duree, complement, qui)
  if complement then
    texte = texte .. " " .. complement
  end
  local ok, erreur = pcall(function()
    UIAction.CallFunction("hud", 0, "SetSubtitleBgEnable", true)
    if qui then
      UIAction.CallFunction("hud", 0, "SetSubtitleSpeakerNameEnable", true)
    end
    UIAction.CallFunction("hud", 0, "SetSubtitles", texte, qui or "", false)
  end)
  if not ok then
    liaison.journal("Affichage impossible : " .. tostring(erreur))
  end
end

-- Le fond des sous-titres tel que le joueur l'a réglé dans ses options.
local function fond_des_sous_titres_du_joueur()
  local ok, valeur = pcall(System.GetCVar, "wh_ui_EnableSubtitleBg")
  return ok and (valeur == true or valeur == 1 or valeur == "1" or valeur == "true")
end

-- Le nom de celui qui parle, tel que le joueur l'a réglé dans ses options.
local function nom_dans_les_sous_titres_du_joueur()
  local ok, valeur = pcall(System.GetCVar, "wh_ui_EnableSubtitleSpeakerName")
  return ok and (valeur == true or valeur == 1 or valeur == "1" or valeur == "true")
end

-- Efface le texte affiché et rend au joueur son réglage du fond des sous-titres (et du nom de celui qui parle).
function liaison.effacer()
  local ok, erreur = pcall(function()
    UIAction.CallFunction("hud", 0, "ClearSubtitles")
    UIAction.CallFunction("hud", 0, "SetSubtitleBgEnable", fond_des_sous_titres_du_joueur())
    UIAction.CallFunction("hud", 0, "SetSubtitleSpeakerNameEnable", nom_dans_les_sous_titres_du_joueur())
  end)
  if not ok then
    liaison.journal("Effacement impossible : " .. tostring(erreur))
  end
end

-- Vrai quand Henry est en dialogue (le bandeau attend : la ligne des sous-titres sert aussi aux dialogues).
-- DialogModule.IsSoulInDialog existe dans le Lua du jeu, mais aucun script du jeu ne l'appelle : la forme
-- de son argument est à vérifier en jeu (V6). On essaie l'âme d'Henry, son identifiant d'entité, puis son
-- WUID ; la première forme qui rend un booléen est gardée et dite au journal. Hors partie, rien n'est décidé.
local formes_du_dialogue = {
  { nom = "l'âme", argument = function() return player.soul end },
  { nom = "l'identifiant d'entité", argument = function() return player.id end },
  { nom = "le WUID", argument = function() return XGenAIModule.GetMyWUID(player) end },
}

function liaison.dialogue_en_cours()
  if etat_du_fichier.forme_du_dialogue == false or not liaison.partie_en_cours() then
    return false
  end
  local formes = etat_du_fichier.forme_du_dialogue and { etat_du_fichier.forme_du_dialogue } or formes_du_dialogue
  for _, forme in ipairs(formes) do
    local ok, resultat = pcall(function() return DialogModule.IsSoulInDialog(forme.argument()) end)
    if ok and type(resultat) == "boolean" then
      if not etat_du_fichier.forme_du_dialogue then
        etat_du_fichier.forme_du_dialogue = forme
        liaison.journal("Dialogue : IsSoulInDialog répond avec " .. forme.nom)
      end
      return resultat
    end
  end
  etat_du_fichier.forme_du_dialogue = false
  liaison.journal("Dialogue : IsSoulInDialog ne répond à aucune forme ; le bandeau n'attendra pas les dialogues")
  return false
end

-- Lance « fonction » dans « millisecondes ».
function liaison.minuterie(millisecondes, fonction)
  return Script.SetTimer(millisecondes, fonction)
end

-- Ajoute une commande de console pour le poste d'essai.
-- À vérifier en jeu : System.AddCCommand(nom, code_lua, aide).
function liaison.commande(nom, code_lua, aide)
  if System.AddCCommand then
    System.AddCCommand(nom, code_lua, aide)
  else
    liaison.journal("Commande « " .. nom .. " » non installée : System.AddCCommand absent")
  end
end

-- Fichier d'ordres du poste d'essai, écrit sur le PC par outils/ordonner.py
-- (la console du jeu ne s'ouvre pas sur le PC de JoVenGer, 14/10).
-- À vérifier en jeu : que loadfile lit un fichier hors des paks, et depuis quel répertoire courant ;
-- les deux chemins sont sondés dans l'ordre.
liaison.chemins_des_ordres = { "Mods/scriptorium_socle/ordres.lua", "../../Mods/scriptorium_socle/ordres.lua" }

-- Fichier de réglages, écrit sur le PC par outils/regler.py (et, à la bascule, par le programme Scriptorium) :
-- même transport que les ordres (fiche 10).
liaison.chemins_des_reglages = { "Mods/scriptorium_socle/reglages.lua", "../../Mods/scriptorium_socle/reglages.lua" }

-- Rend la table d'un fichier de données du PC et son chemin ; nil s'il n'y a pas de fichier ;
-- nil, chemin, raison s'il est illisible. Le fichier ne voit rien du jeu (environnement vide).
local function lire_fichier_de_donnees(chemins)
  for _, chemin in ipairs(chemins) do
    local morceau, erreur = loadfile(chemin)
    if morceau then
      setfenv(morceau, {})
      local ok, donnees = pcall(morceau)
      if ok and type(donnees) == "table" then
        return donnees, chemin
      end
      return nil, chemin, ok and "le fichier ne rend pas de table" or tostring(donnees)
    elseif erreur and not string.find(erreur, "cannot open", 1, true) then
      return nil, chemin, tostring(erreur)
    end
  end
  return nil
end

function liaison.lire_ordres()
  return lire_fichier_de_donnees(liaison.chemins_des_ordres)
end

function liaison.lire_reglages()
  return lire_fichier_de_donnees(liaison.chemins_des_reglages)
end

-- Le rechargement d'essai (V73 g 0, la sonde ; piste du pair) : des copies de nos morceaux posées par
-- outils/recharger.py dans le dossier du mod, et leur liste (« liste.lua » : return { "hommes", … }), lues par loadfile
-- comme les ordres. Un morceau est exécuté dans l'environnement du jeu (il se déclare de nouveau au noyau).
liaison.dossiers_du_rechargement = { "Mods/scriptorium_socle/recharge/", "../../Mods/scriptorium_socle/recharge/" }

function liaison.liste_du_rechargement()
  local chemins = {}
  for _, dossier in ipairs(liaison.dossiers_du_rechargement) do
    table.insert(chemins, dossier .. "liste.lua")
  end
  return lire_fichier_de_donnees(chemins)
end

-- Rend (vrai, chemin) si le morceau a été relu et exécuté, sinon (faux, raison).
function liaison.charger_un_morceau(nom)
  if type(nom) ~= "string" or not string.match(nom, "^[a-z_]+$") then
    return false, "nom refusé"
  end
  for _, dossier in ipairs(liaison.dossiers_du_rechargement) do
    local chemin = dossier .. nom .. ".lua"
    local morceau, erreur = loadfile(chemin)
    if morceau then
      local ok, raison = pcall(morceau)
      if ok then
        return true, chemin
      end
      return false, chemin .. " : " .. tostring(raison)
    elseif erreur and not string.find(erreur, "cannot open", 1, true) then
      return false, chemin .. " : " .. tostring(erreur)
    end
  end
  return false, "fichier introuvable"
end

-- Heure du jeu, en heures, pour dater le livre de comptes.
-- À vérifier en jeu : Calendar.GetWorldTime() (secondes de jeu ?). En attendant, 0 si absent.
function liaison.heure_du_jeu()
  local ok, valeur = pcall(function() return Calendar.GetWorldTime() end)
  if ok and type(valeur) == "number" then
    return valeur / 3600
  end
  return 0
end

-- Vrai si l'heure du jeu est arrêtée (Calendar.IsWorldTimePaused) ; nil si l'appel ne répond pas.
function liaison.temps_arrete()
  local ok, valeur = pcall(function() return Calendar.IsWorldTimePaused() end)
  if ok then
    return valeur
  end
  return nil
end

-- Groschen dans la bourse d'Henry.
-- À vérifier en jeu : player.inventory:GetMoney(). En attendant, 0 si absent.
function liaison.groschen_d_henry()
  local ok, valeur = pcall(function() return player.inventory:GetMoney() end)
  if ok and type(valeur) == "number" then
    return valeur
  end
  return 0
end

-- Un montant d'argent acceptable : un nombre entier, fini, strictement positif, au plus « argent_d_henry_max » (réglage
-- du noyau, section « socle » ; relecture du pair du 17/10 : un montant absurde est refusé). Un plafond illisible : tout
-- est refusé.
local function montant_juste(montant)
  local r = Scriptorium.noyau and Scriptorium.noyau.reglages
  local plafond = r and tonumber(r.argent_d_henry_max)
  return type(montant) == "number" and montant == montant and montant > 0 and montant < math.huge
         and math.floor(montant) == montant and plafond ~= nil and montant <= plafond
end

-- Retire des groschen à Henry (dépôt au coffre, voulu par le joueur). Vrai si fait.
-- Règle de JoVenGer : jamais un retrait de zéro, ni négatif, ni non entier, ni au-dessus de la bourse. Le 10/10,
-- RemoveMoney(0) a vidé toute la bourse d'Henry. Une bourse qui ne se lit pas : rien n'est retiré. Vu en jeu le 14/10 :
-- GetMoney lit la bourse, RemoveMoney retire le montant.
function liaison.retirer_groschen_a_henry(montant)
  if not montant_juste(montant) then
    liaison.journal("Argent d'Henry : retrait refusé, montant « " .. tostring(montant) .. " »")
    return false
  end
  local lu, bourse = pcall(function() return player.inventory:GetMoney() end)
  if not lu or type(bourse) ~= "number" then
    liaison.journal("Argent d'Henry : retrait refusé, bourse illisible")
    return false
  end
  if montant > bourse then
    return false
  end
  local ok = pcall(function() player.inventory:RemoveMoney(montant) end)
  return ok
end

-- Donne des groschen à Henry (versement du coffre, ou crédit simple pour Scriptorium). Vrai si fait. Même garde que le
-- retrait : un montant entier, strictement positif, sous le plafond ; jamais un ajout de zéro envoyé au jeu.
-- Vu en jeu le 14/10 : AddMoney.
function liaison.donner_groschen_a_henry(montant)
  if not montant_juste(montant) then
    liaison.journal("Argent d'Henry : versement refusé, montant « " .. tostring(montant) .. " »")
    return false
  end
  local ok = pcall(function() player.inventory:AddMoney(montant) end)
  return ok
end

-- Identifiant d'une entité posée par le socle : son nom, unique (« scriptorium_… », ou « Scriptorium_Directeur »).
-- entite.id est une donnée du moteur (userdata) que le registre ne sait pas garder (vu en jeu le 14/10) ;
-- un nom se garde, et tient après sauvegarde et rechargement. À vérifier en jeu : System.GetEntityByName.
local function nom_libre(nom)
  local essai = nom
  for n = 2, 1000 do
    local ok, deja = pcall(System.GetEntityByName, essai)
    if not ok or deja == nil then
      return essai
    end
    essai = nom .. "_" .. n
  end
  return essai
end

local function entite_nommee(identifiant)
  if type(identifiant) ~= "string" then
    return nil
  end
  local ok, entite = pcall(System.GetEntityByName, identifiant)
  if ok then
    return entite
  end
  return nil
end

-- Les alertes du camp (demande de JoVenGer du 18/10) : un déclencheur sonore du jeu joué sur une entité nommée (Henry
-- si aucune) : Sound.GetAudioTriggerID puis ExecuteAudioTrigger sur son proxy audio par défaut, comme
-- AudioUtils.PlayAudioTrigger du jeu (Scripts/Utils/AudioUtils.lua). Rend vrai, ou faux et la raison.
function liaison.jouer_un_son(nom_du_son, identifiant)
  local entite = identifiant and entite_nommee(identifiant) or player
  if not entite then
    return false, "entité introuvable"
  end
  local ok, resultat = pcall(function()
    local declencheur = Sound.GetAudioTriggerID(nom_du_son)
    if declencheur == nil then
      return "déclencheur inconnu"
    end
    entite:ExecuteAudioTrigger(declencheur, entite:GetDefaultAuxAudioProxyID())
    return true
  end)
  if not ok then
    return false, tostring(resultat)
  end
  if resultat ~= true then
    return false, resultat
  end
  return true
end

-- Les caps du socle sont ceux d'une boussole : en degrés, dans le sens des aiguilles d'une montre vu de dessus.
-- Le moteur compte l'angle autour de la verticale dans l'autre sens (vers l'ouest = +90°) : vu en jeu le 14/10,
-- un camp fondé face à l'ouest sortait en miroir, la tente du Directeur à l'est. La liaison retourne le sens.
local function cap_vers_moteur(cap)
  return math.rad((-(cap or 0) + 180) % 360 - 180)
end

local function cap_depuis_moteur(radians)
  return (-math.deg(radians)) % 360
end

-- Fait naître une entité et rend son nom, ou nil et la raison. Le nom ne garde que des lettres ASCII, chiffres et
-- « _ » : un nom d'affichage (« Mikuláš Kladivo ») ne sert pas tel quel de nom d'entité. La classe est écrite
-- en clair (« %w » dépend de la langue du système et peut garder un octet accentué).
-- « orientation » de System.SpawnEntity est un vecteur de direction (l'avant de l'entité), pas des angles :
-- vu le 14/10, en lui passant { 0, 0, angle }, tout objet de cap non nul naissait couché, l'avant vers le ciel
-- (tour de guet allongée, pans de palissade à plat, tentes renversées). L'avant est donné à l'horizontale, puis
-- les angles sont fixés par SetWorldAngles.
-- Vu le 14/10 : un personnage né avec { guidSharedSoulId = âme } pour seules propriétés restait inerte (ni marche,
-- ni combat, ni réaction à Henry à douze mètres ; l'un flottait en l'air), quelle que soit sa faction. Les
-- propriétés données à System.SpawnEntity remplacent celles de la classe : il perdait celles qui le font voir,
-- être vu, écouter et marcher (NPC.lua : bWH_PerceptorObject, bWH_PerceptibleObject, bWH_ListenerObject,
-- bWH_CreateSituationSubsystem, bWH_RequiresHome, esNavigationType…). Le jeu fait naître ses entités avec leur table
-- complète (EntityCommon.lua, Event_Spawn). Un personnage reçoit donc une copie des propriétés de sa classe, plus
-- les nôtres. (XGenAIModule.SpawnEntity, employée par les scripts de débogage du jeu, n'existe pas hors des outils
-- de Warhorse, même avec -devmode : vu le 14/10.)
local function copie_profonde(source)
  if type(source) ~= "table" then
    return source
  end
  local resultat = {}
  for cle, valeur in pairs(source) do
    resultat[cle] = copie_profonde(valeur)
  end
  return resultat
end

local function proprietes_completes(classe, proprietes)
  local modele = rawget(_G, classe)
  local resultat = (type(modele) == "table" and type(modele.Properties) == "table") and copie_profonde(modele.Properties) or {}
  for cle, valeur in pairs(proprietes or {}) do
    resultat[cle] = valeur
  end
  return resultat
end

-- Les classes qui naissent avec une copie des propriétés de leur classe, plus les nôtres : les personnages.
liaison.classes_completees = { NPC = true, Horse = true }

-- Jamais deux personnages à moins d'un mètre (réponse de JoVenGer du 16/10/2026, après V72 c : trois hommes au même
-- point, deux écrans noirs). Une place est prise si un personnage (classe NPC) ou Henry s'y tient.
liaison.ecart_minimal = 1

local function place_prise(position)
  local lu, voisins = pcall(System.GetEntitiesInSphereByClass, position, liaison.ecart_minimal, "NPC")
  if lu and type(voisins) == "table" and next(voisins) ~= nil then
    return true
  end
  local vu, henry = pcall(function() return player:GetWorldPos() end)
  return vu and type(henry) == "table"
    and math.sqrt((henry.x - position.x) ^ 2 + (henry.y - position.y) ^ 2) < liaison.ecart_minimal
end

-- La place voulue si elle est libre ; sinon la première libre sur deux cercles autour (1,2 m puis 2,4 m, huit
-- directions) ; sinon nil.
local function place_libre(position)
  if not place_prise(position) then
    return position
  end
  for _, rayon in ipairs({ 1.2, 2.4 }) do
    for k = 0, 7 do
      local angle = k * math.pi / 4
      local voisine = liaison.au_sol({ x = position.x + rayon * math.cos(angle), y = position.y + rayon * math.sin(angle),
                                       z = position.z })
      if not place_prise(voisine) then
        return voisine
      end
    end
  end
  return nil
end

-- « brut » : sans la copie des propriétés de la classe (sonde V71 a2 seulement, fiche 13).
local function faire_naitre(classe, nom, position, cap, proprietes, brut)
  if classe == "NPC" or classe == "Horse" then
    position = place_libre(position)
    if not position then
      return nil, "place prise : un personnage à moins de " .. liaison.ecart_minimal .. " m, et aucune place libre à côté"
    end
  end
  local nom_unique = nom_libre((string.gsub(nom, "[^A-Za-z0-9_]", "_")))
  local angle = cap_vers_moteur(cap)
  if liaison.classes_completees[classe] and not brut then
    proprietes = proprietes_completes(classe, proprietes)
  end
  local ok, entite = pcall(function()
    return System.SpawnEntity({
      class = classe,
      name = nom_unique,
      position = { x = position.x, y = position.y, z = position.z },
      orientation = { x = -math.sin(angle), y = math.cos(angle), z = 0 },
      properties = proprietes,
    })
  end)
  if ok and entite and entite.id then
    pcall(function() entite:SetWorldAngles({ x = 0, y = 0, z = angle }) end)
    return nom_unique
  end
  return nil, tostring(entite)
end

-- La position posée sur le sol : le camp se fonde à l'altitude d'Henry, mais le terrain n'est pas plat
-- (vu le 14/10). Chaque objet prend la hauteur du terrain sous lui (System.GetTerrainElevation).
function liaison.au_sol(position)
  local ok, sol = pcall(System.GetTerrainElevation, { x = position.x, y = position.y, z = 0 })
  if ok and type(sol) == "number" then
    return { x = position.x, y = position.y, z = sol }
  end
  return position
end
-- Pose un objet du jeu de base (modèle par son chemin) et rend son identifiant, ou nil.
-- Vu en jeu le 14/10 : System.SpawnEntity avec la classe BasicEntity pose bien l'objet ;
-- un modèle introuvable donne une forme blanche. « classe » : une classe d'entité du jeu qui prend un modèle
-- (Chair, Bed : Henry peut s'y asseoir, y dormir) ; BasicEntity par défaut (un décor).
-- Vu en jeu le 15/10 (V63) : un objet gardé par la sauvegarde revient avec le modèle par défaut de sa classe (pour
-- BasicEntity, objects/default/primitive_pyramid.cgf : les « tentes blanches ») ; les classes Chair et Bed du jeu, qui
-- ont bSaved_by_game à false, ne sont pas gardées, et le camp les repose à neuf. Chaque objet posé par le socle porte donc
-- bSaved_by_game à false, comme les classes du jeu qui ne doivent pas être sauvegardées (GeomEntity, TagPoint…).
function liaison.poser_objet(sorte, modele, position, cap, nom, classe)
  local identifiant, raison = faire_naitre(classe or "BasicEntity", "scriptorium_" .. nom, liaison.au_sol(position), cap,
                                           { object_Model = modele, bSaved_by_game = false })
  if identifiant then
    -- Vu le 14/10 : posé par script, un objet n'était plus dessiné au-delà d'une dizaine de mètres (la palissade,
    -- à 15 m, restait invisible). Sa distance d'affichage est mise au plus loin.
    local entite = entite_nommee(identifiant)
    if entite then
      pcall(function() entite:SetViewDistRatio(255) end)
      pcall(function() entite:SetLodRatio(255) end)
    end
  end
  if not identifiant then
    liaison.journal("Pose impossible pour « " .. nom .. " » (" .. sorte .. ", " .. (classe or "BasicEntity") .. ") : " .. tostring(raison))
  end
  return identifiant
end

-- Un feu qui brûle sur le foyer posé, avec l'effet des feux de cuisson des campements du jeu (Prefabs/
-- exteriorDecoration/camp_supplies/cooking_station_v1.xml) : « fires.exterior_fireplace » de la bibliothèque
-- WH_Particels (vu le 14/10 : « fireplace_nosmoke_low » ne donnait qu'une flammèche). Chargé dans un
-- emplacement du foyer comme le font les scripts du jeu (DestroyableObject.lua : LoadParticleEffect puis
-- SetSlotPos et SetSlotAngles) : 7 cm plus haut, un quart de tour autour de x pour flamber vers le haut.
-- Vu le 14/10 : une entité ParticleEffect à part est refusée par System.SpawnEntity. À vérifier en jeu (V23).
liaison.effet_du_feu = "WH_Particels.fires.exterior_fireplace"
-- Plus grand que les réglages par défaut : à quelques mètres, la flamme par défaut n'était qu'un point (vu le 14/10).
liaison.reglages_du_feu = { SpawnPeriod = 0, Scale = 3, CountScale = 2, bCountPerUnit = false, bSizePerUnit = 0,
                            AttachType = "none", AttachForm = "none", bPrime = true }

function liaison.allumer(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite then
    return false
  end
  local ok, emplacement = pcall(function()
    local slot = entite:LoadParticleEffect(-1, liaison.effet_du_feu, liaison.reglages_du_feu)
    if slot then
      entite:SetSlotPos(slot, { x = 0, y = 0, z = 0.07 })
      entite:SetSlotAngles(slot, { x = math.rad(90), y = 0, z = 0 })
    end
    return slot
  end)
  if not ok or not emplacement then
    liaison.journal("Feu impossible à allumer sur « " .. tostring(identifiant) .. " » : " .. tostring(emplacement))
    return false
  end
  return true
end

-- Ce que le moteur dit d'un objet posé (pour le poste d'essai) : position, nombre d'emplacements, géométrie,
-- émetteur de particules, et la distance à Henry.
function liaison.decrire_objet(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite then
    return "introuvable"
  end
  local ok, description = pcall(function()
    local p = entite:GetWorldPos()
    local h = player:GetWorldPos()
    local morceaux = { string.format("position %.1f, %.1f, %.1f ; Henry à %.1f m", p.x, p.y, p.z,
                                     math.sqrt((p.x - h.x) ^ 2 + (p.y - h.y) ^ 2)) }
    table.insert(morceaux, "distance d'affichage " .. tostring((entite:GetViewDistRatio())))
    local mini, maxi = entite:GetLocalBBox()
    if mini and maxi then
      table.insert(morceaux, string.format("taille %.1f × %.1f × %.1f m (x, y, z)", maxi.x - mini.x, maxi.y - mini.y, maxi.z - mini.z))
      -- V73 c 12 : les coins de la boîte, dans le repère du modèle, pour savoir où est son origine (placer un lit dans sa
      -- tente demande le centre de la tente, pas seulement sa taille).
      table.insert(morceaux, string.format("boîte de (%.2f, %.2f) à (%.2f, %.2f)", mini.x, mini.y, maxi.x, maxi.y))
    end
    local n = (entite:GetSlotCount()) or 0
    table.insert(morceaux, n .. " emplacement(s)")
    for slot = 0, n - 1 do
      table.insert(morceaux, "n° " .. slot .. " : géométrie " .. tostring((entite:IsSlotGeometry(slot)))
                   .. ", particules " .. tostring((entite:IsSlotParticleEmitter(slot))))
    end
    return table.concat(morceaux, " ; ")
  end)
  return ok and description or ("illisible : " .. tostring(description))
end

-- Pose « fermée » de chaque porte posée, gardée à son premier mouvement (voir liaison.changer_porte).

-- Retire un objet posé par le socle.
-- À vérifier en jeu : System.RemoveEntity.
function liaison.retirer_objet(identifiant)
  etat_du_fichier.poses_fermees[identifiant] = nil
  local entite = entite_nommee(identifiant)
  if entite then
    pcall(System.RemoveEntity, entite.id)
  end
end

-- Vrai si l'objet existe encore dans le monde.
function liaison.objet_existe(identifiant)
  return entite_nommee(identifiant) ~= nil
end

-- Le registre dans la sauvegarde. Vu en jeu le 14/10 : un jeton du jeu (GameToken.SetToken / GetToken) est
-- gardé par « Sauvegarder et quitter » et revient au rechargement (V4) ; mais il n'est pas remis à zéro quand
-- on charge une autre sauvegarde : une sauvegarde plus ancienne héritait du camp de la précédente.
-- Le jeton porte donc « identité|données », et une marque invisible « scriptorium_registre_<identité> » est
-- posée dans le monde : elle est enregistrée avec la sauvegarde. À la lecture, sans la marque de son identité,
-- le jeton vient d'une autre partie et il est ignoré. La mémoire de secours couvre un jeton refusé.
liaison.nom_du_jeton = "scriptorium_socle.registre"
liaison.prefixe_de_la_marque = "scriptorium_registre_"
-- Règle de JoVenGer (note du 15/10) : aucune valeur enregistrée de plus de 65 535 octets (le 8/10, des sauvegardes
-- sont devenues impossibles à recharger). Le registre est donc coupé en tranches, une par jeton :
--   en-tête  « nom_du_jeton »      : « identité|tranches|n|longueur|somme »
--   tranche  « nom_du_jeton.<i> »  : « identité|i|texte »
-- et recollé à la lecture, longueur et somme vérifiées. L'ancien format, un seul jeton « identité|données », se lit
-- toujours. Vu en jeu le 15/10 : une sauvegarde qui portait des jetons d'essai de 66 000 à 200 000 caractères
-- (relus intacts avant la sauvegarde) n'a plus pu être rechargée (« Échec du chargement »). Aucun jeton ne
-- s'écrit donc au-delà de 65 535 octets, essais compris : poser_un_jeton refuse.
liaison.taille_des_tranches = 30000
liaison.plus_long_jeton = 65535

local function jeton(nom)
  local ok, valeur = pcall(function() return GameToken.GetToken(nom) end)
  if ok and type(valeur) == "string" then
    return valeur
  end
  return nil
end

-- Le seul chemin vers GameToken.SetToken. Une valeur trop longue lève une erreur (attrapée par les appelants) au
-- lieu d'être écrite.
local function poser_un_jeton(nom, valeur)
  if #valeur > liaison.plus_long_jeton then
    error(string.format("jeton « %s » de %d octets, au-delà de %d : non écrit", nom, #valeur, liaison.plus_long_jeton))
  end
  GameToken.SetToken(nom, valeur)
end

-- Une somme de contrôle de tous les octets d'une chaîne. Le registre s'écrit après chaque événement : les octets sont
-- lus seize par seize (un seul appel), chacun avec son poids, pour que tout octet changé change la somme. Le Lua du
-- jeu compte en simple précision : le module 65521 garde chaque calcul sous 65520 × 31 + 255 × 408 = 2 135 160,
-- loin de 2^24, donc juste dans le jeu comme au banc.
local MODULE_DE_LA_SOMME = 65521

local function somme_de(chaine)
  local somme, longueur, i = 0, #chaine, 1
  while i + 15 <= longueur do
    local o1, o2, o3, o4, o5, o6, o7, o8, o9, o10, o11, o12, o13, o14, o15, o16 = string.byte(chaine, i, i + 15)
    somme = (somme * 31 + o1 + o2 * 3 + o3 * 5 + o4 * 7 + o5 * 11 + o6 * 13 + o7 * 17 + o8 * 19 + o9 * 23 + o10 * 29
             + o11 * 37 + o12 * 41 + o13 * 43 + o14 * 47 + o15 * 53 + o16 * 59) % MODULE_DE_LA_SOMME
    i = i + 16
  end
  while i <= longueur do
    somme = (somme * 31 + string.byte(chaine, i)) % MODULE_DE_LA_SOMME
    i = i + 1
  end
  return somme
end

-- Rend l'identité et les données d'un flux (« nom » : son jeton d'en-tête ; recollées s'il est en tranches), ou nil.
-- « raison » : pourquoi un flux en tranches est refusé (tranche manquante, d'une autre partie, longueur ou somme fausse).
-- Fiche 01 : l'ancien registre, l'index et chaque case sont des flux.
local function lire_un_flux(nom_du_flux)
  local valeur = jeton(nom_du_flux)
  if not valeur then
    return nil, nil
  end
  local identite, n, longueur, somme = string.match(valeur, "^([%w_]+)|tranches|(%d+)|(%d+)|(%d+)$")
  if not identite then
    local ancienne_identite, ancien = string.match(valeur, "^([%w_]+)|(.*)$")
    if ancien and string.sub(ancien, 1, 9) == "tranches|" then
      return ancienne_identite, nil, "en-tête illisible"
    end
    return ancienne_identite, ancien
  end
  local morceaux = {}
  for i = 1, tonumber(n) do
    local tranche = jeton(string.format("%s.%d", nom_du_flux, i))
    local de_qui, numero, texte = string.match(tranche or "", "^([%w_]+)|(%d+)|(.*)$")
    if de_qui ~= identite or tonumber(numero) ~= i then
      return identite, nil, "tranche " .. i .. " manquante ou d'une autre partie"
    end
    morceaux[i] = texte
  end
  local donnees = table.concat(morceaux)
  if #donnees ~= tonumber(longueur) or somme_de(donnees) ~= tonumber(somme) then
    return identite, nil, "longueur ou somme fausse"
  end
  return identite, donnees
end

local function lire_le_jeton()
  return lire_un_flux(liaison.nom_du_jeton)
end

-- Écrit le registre en tranches : les tranches d'abord, l'en-tête ensuite ; les tranches d'une écriture plus longue
-- sont vidées. Les nombres s'écrivent par « %d » : le Lua du jeu écrit 1 000 000 « 1e+06 » quand on le colle à une
-- chaîne. Rend vrai, ou faux et l'erreur.
function liaison.entete_du_registre(identite, n, chaine)
  return string.format("%s|tranches|%d|%d|%d", identite, n, #chaine, somme_de(chaine))
end

-- Fiche 01 (le second canal, demande du pair, 18/10) : ce qui n'est pas encore écrit dans les GameToken voyage DANS la
-- sauvegarde. Le jeu écrit ses GameToken avant d'appeler les OnSave des entités (vu en jeu le 18/10 : une écriture
-- faite pendant l'OnSave manquait au rechargement) ; l'OnSave d'une entité de notre classe « scriptorium_sauvegarde »
-- (Entities/ du pak, Scripts/Entities/scriptorium_sauvegarde.lua ; forme d'une classe déclarée par un .ent : le guide
-- « How-to Lua », Nexus Mods, KCD, mod 1344, et AISpawner du jeu) range donc les cases en attente dans sa propre table
-- de sauvegarde, en tranches ; son OnLoad les relit ; le registre les reprend au chargement s'il le faut. Un OnSave posé
-- sur l'instance d'Henry n'est pas appelé (vu en jeu le 18/10). Une seule entité, de nom fixe.
liaison.nom_de_l_entite_de_sauvegarde = "scriptorium_sauvegarde_1"
liaison.depuis_la_sauvegarde = nil

-- La longueur et la somme d'une chaîne (l'empreinte d'une case écrite).
function liaison.empreinte(chaine)
  return #chaine, somme_de(chaine)
end

-- « fonction » rend la liste { nom, chaine, base } des cases à ranger ; l'entité trouvée (elle revient avec la partie),
-- sinon créée près d'Henry. Rend vrai si l'entité est là.
function liaison.accrocher_la_sauvegarde(fonction)
  liaison.fonction_de_sauvegarde = fonction
  local nom = liaison.nom_de_l_entite_de_sauvegarde
  local ok, entite = pcall(System.GetEntityByName, nom)
  if ok and entite then
    liaison.journal("Sauvegarde : entité « " .. nom .. " » trouvée")
    return true
  end
  local cree, nouvelle = pcall(function()
    local la = player and player:GetWorldPos() or { x = 0, y = 0, z = 0 }
    return System.SpawnEntity({ class = "scriptorium_sauvegarde", name = nom, position = { x = la.x, y = la.y, z = la.z } })
  end)
  liaison.journal("Sauvegarde : entité « " .. nom .. " » créée = " .. tostring(cree and nouvelle ~= nil)
                  .. (cree and "" or (" : " .. tostring(nouvelle))))
  return cree and nouvelle ~= nil
end

-- L'OnSave de l'entité : les cases à ranger, dans « tableau », en tranches, avec l'identité de la partie.
function liaison.a_la_sauvegarde(tableau)
  if type(liaison.fonction_de_sauvegarde) ~= "function" or type(tableau) ~= "table" then
    return
  end
  local ok, erreur = pcall(function()
    local taille = liaison.taille_des_tranches
    local rangees = {}
    for _, e in ipairs(liaison.fonction_de_sauvegarde() or {}) do
      local r = { nom = e.nom, tranches = {} }
      if e.base then
        r.base_longueur, r.base_somme = liaison.empreinte(e.base)
      end
      for i = 1, math.max(1, math.ceil(#e.chaine / taille)) do
        r.tranches[i] = string.sub(e.chaine, (i - 1) * taille + 1, i * taille)
      end
      table.insert(rangees, r)
    end
    tableau.cases_en_attente = { identite = etat_du_fichier.identite_de_la_partie, cases = rangees }
    liaison.journal("Sauvegarde : " .. #rangees .. " case(s) en attente rangée(s) dans la sauvegarde")
  end)
  if not ok then
    liaison.journal("Sauvegarde : rangement en erreur : " .. tostring(erreur))
  end
end

-- L'OnLoad de l'entité : les cases rangées, gardées jusqu'au chargement du registre.
function liaison.a_la_relecture(tableau)
  local ok, erreur = pcall(function()
    liaison.depuis_la_sauvegarde = nil
    local s = type(tableau) == "table" and tableau.cases_en_attente or nil
    if type(s) ~= "table" or type(s.cases) ~= "table" then
      liaison.journal("Sauvegarde : relue, rien de rangé")
      return
    end
    local liste = {}
    for _, r in ipairs(s.cases) do
      if type(r) == "table" and type(r.nom) == "string" and type(r.tranches) == "table" then
        table.insert(liste, { nom = r.nom, chaine = table.concat(r.tranches), base_longueur = r.base_longueur,
                              base_somme = r.base_somme })
      end
    end
    liaison.depuis_la_sauvegarde = { identite = s.identite, cases = liste }
    liaison.journal("Sauvegarde : relue, " .. #liste .. " case(s) rangée(s)")
  end)
  if not ok then
    liaison.journal("Sauvegarde : relecture en erreur : " .. tostring(erreur))
  end
end

-- Pour le registre, une fois par chargement : les cases rangées, si elles sont de cette partie ; sinon nil.
function liaison.cases_de_la_sauvegarde()
  local d = liaison.depuis_la_sauvegarde
  liaison.depuis_la_sauvegarde = nil
  if not d then
    return nil
  end
  if d.identite ~= etat_du_fichier.identite_de_la_partie then
    liaison.journal("Sauvegarde : cases rangées d'une autre partie (" .. tostring(d.identite) .. "), ignorées")
    return nil
  end
  return d.cases
end

-- Fiche 01 : un flux nommé (l'index, une case) ; les tranches en trop d'une écriture plus longue, vidées (comptées par
-- flux).
local function ecrire_un_flux(nom_du_flux, identite, chaine)
  etat_du_fichier.tranches_par_flux = etat_du_fichier.tranches_par_flux or {}
  local taille = liaison.taille_des_tranches
  local n = math.max(1, math.ceil(#chaine / taille))
  local avant = etat_du_fichier.tranches_par_flux[nom_du_flux] or 0
  local ok, erreur = pcall(function()
    for i = 1, n do
      poser_un_jeton(string.format("%s.%d", nom_du_flux, i),
                         string.format("%s|%d|", identite, i) .. string.sub(chaine, (i - 1) * taille + 1, i * taille))
    end
    for i = n + 1, avant do
      poser_un_jeton(string.format("%s.%d", nom_du_flux, i), "")
    end
    poser_un_jeton(nom_du_flux, liaison.entete_du_registre(identite, n, chaine))
  end)
  if ok then
    etat_du_fichier.tranches_par_flux[nom_du_flux] = n
  end
  return ok, erreur, n
end

local function ecrire_le_jeton(identite, chaine)
  local ok, erreur, n = ecrire_un_flux(liaison.nom_du_jeton, identite, chaine)
  if ok then
    etat_du_fichier.tranches_ecrites = n
  end
  return ok, erreur, n
end

-- Pour le poste d'essai (note de JoVenGer, partie 2, point 3) : ce que garde un jeton du jeu. Écrit dans le jeton
-- « scriptorium_socle.essai_jeton_<longueur> » une chaîne connue de cette longueur, et rend sa relecture immédiate.
local function texte_d_essai(longueur)
  local motif = "0123456789abcdefghijklmnopqrstuvwxyz"
  return string.sub(string.rep(motif, math.ceil(longueur / #motif)), 1, longueur)
end

function liaison.essayer_un_jeton(longueur)
  local nom = "scriptorium_socle.essai_jeton_" .. longueur
  local ok, erreur = pcall(function() poser_un_jeton(nom, texte_d_essai(longueur)) end)
  if not ok then
    return false, tostring(erreur)
  end
  return liaison.relire_un_jeton(longueur)
end

-- Relit le jeton d'essai d'une longueur : rend la longueur relue et vrai si le texte est intact.
function liaison.relire_un_jeton(longueur)
  local valeur = jeton("scriptorium_socle.essai_jeton_" .. longueur)
  if not valeur then
    return 0, false
  end
  return #valeur, valeur == texte_d_essai(longueur)
end

-- Pour le poste d'essai : ce que le jeu garde du registre en tranches (en-tête, chaque tranche). Rend des lignes pour
-- le journal.
function liaison.decrire_le_registre()
  local lignes = {}
  -- Fiche 01 : l'index et chaque case (en-tête : identité, tranches, longueur).
  local index = jeton(liaison.nom_de_l_index)
  table.insert(lignes, "index : " .. (index and (string.format("%d car., « ", #index) .. string.sub(index, 1, 80) .. " »") or "absent"))
  local _, contenu = lire_un_flux(liaison.nom_de_l_index)
  for nom in string.gmatch(contenu or "", '%]="([%w_]+)"') do
    local entete = jeton(liaison.prefixe_des_cases .. nom)
    table.insert(lignes, "case « " .. nom .. " » : " .. (entete and string.sub(entete, 1, 80) or "absente"))
  end
  local entete = jeton(liaison.nom_du_jeton)
  table.insert(lignes, "en-tête : " .. (entete and (string.format("%d car., « ", #entete) .. string.sub(entete, 1, 80) .. " »") or "absent"))
  local n = entete and tonumber(string.match(entete, "|tranches|(%d+)|")) or 0
  for i = 1, n do
    local tranche = jeton(string.format("%s.%d", liaison.nom_du_jeton, i))
    table.insert(lignes, string.format("tranche %d : ", i)
                         .. (tranche and (string.format("%d car., « ", #tranche) .. string.sub(tranche, 1, 40) .. " »") or "absente"))
  end
  return lignes
end

-- Les calculs du socle qui doivent rester justes dans le Lua du jeu (simple précision) : la somme de contrôle du
-- registre et le hasard. Les valeurs attendues sont celles du banc (double précision), qui les vérifie aussi. Rend
-- vrai si tout est juste, et une ligne pour le journal.
liaison.nombres_attendus = { somme = 34016, hasard = { 3675, 21111, 15850 } }

function liaison.verifier_les_nombres()
  local somme = somme_de(texte_d_essai(100000))
  local etat = Scriptorium.hasard_depuis(12345)
  for _ = 1, 999 do
    Scriptorium.tirer(etat)
  end
  local justes = somme == liaison.nombres_attendus.somme
  for i = 1, 3 do
    justes = justes and etat[i] == liaison.nombres_attendus.hasard[i]
  end
  return justes, string.format("somme d'essai %d (attendu %d), hasard après 999 tirages %d %d %d (attendu %d %d %d)",
    somme, liaison.nombres_attendus.somme, etat[1], etat[2], etat[3],
    liaison.nombres_attendus.hasard[1], liaison.nombres_attendus.hasard[2], liaison.nombres_attendus.hasard[3])
end

local function poser_la_marque(identite)
  return faire_naitre("BasicEntity", liaison.prefixe_de_la_marque .. identite, { x = 0, y = 0, z = 0 }, 0, {})
end

-- Lit la chaîne du registre enregistrée dans cette partie, ou nil. Fiche 15, V73 f 3 b (relecture du pair) : la marque
-- est un objet posé dans une carte ; arrivé sur une carte où elle n'est pas, le jeton n'est cru, comme un passage de
-- carte de la même partie, qu'à trois conditions ensemble : la carte a changé depuis l'entrée précédente ; l'identité
-- du jeton est celle gardée en mémoire Lua ; l'horloge du monde a avancé, de « passage_jours_max » au plus, depuis la
-- dernière écriture (la règle du noyau). Alors la marque est posée ici aussi. Sinon le jeton est ignoré, comme avant :
-- le jeton n'est pas remis à zéro quand on charge une sauvegarde qui n'en a pas (V4), et une partie étrangère ou une
-- ancienne sauvegarde d'avant le camp ne doit pas en hériter. Limite connue : une partie étrangère sans jeton, chargée
-- sur l'autre carte moins de 10 jours en avant. Non vérifié en jeu (passage à faire par JoVenGer).
-- L'identité d'un flux est-elle celle de cette partie (sa marque est là, ou un passage de carte croyable) ?
local function croire(identite)
  local marquee = identite and entite_nommee(liaison.prefixe_de_la_marque .. identite) ~= nil
  if identite and not marquee and identite == liaison.memoire.identite then
    local avant, ici = liaison.memoire.carte_d_avant, liaison.memoire.carte
    local carte_changee = avant ~= nil and ici ~= nil and avant ~= ici
    local temps_croyable = liaison.passage_croyable ~= nil
      and liaison.passage_croyable(liaison.memoire.heure_ecrite, liaison.heure_du_jeu()) == true
    if carte_changee and temps_croyable then
      marquee = poser_la_marque(identite) ~= nil
      liaison.journal("Registre : passage de « " .. tostring(avant) .. " » à « " .. tostring(ici) .. " », même partie ("
                      .. identite .. ") : marque posée ici " .. (marquee and "" or "impossible"))
    elseif identite ~= liaison.identite_ignoree then
      liaison.journal("Registre : même identité sans marque (" .. identite .. "), mais "
                      .. (carte_changee and "horloge hors de la fenêtre" or "même carte") .. " : jeton ignoré")
    end
  end
  return marquee
end

function liaison.lire_registre()
  local identite, donnees, raison = lire_le_jeton()
  local marquee = croire(identite)
  if marquee then
    etat_du_fichier.identite_de_la_partie = identite
    liaison.memoire.identite = identite
    if raison then
      liaison.journal("Registre : en tranches, refusé (" .. raison .. ")")
      return liaison.memoire.registre
    end
    return donnees
  end
  if identite and identite ~= liaison.identite_ignoree then
    liaison.identite_ignoree = identite
    liaison.journal("Registre : jeton d'une autre partie (" .. identite .. "), ignoré")
  end
  etat_du_fichier.identite_de_la_partie = nil
  return liaison.memoire.registre
end

-- Donne une identité à la partie et pose sa marque dans le monde.
local function marquer_la_partie()
  local identite = string.format("p%d_%d", os.time(), math.random(100000, 999999))
  local pose = poser_la_marque(identite)
  if pose then
    etat_du_fichier.identite_de_la_partie = identite
    liaison.memoire.identite = identite
    liaison.journal("Registre : partie marquée (" .. identite .. ")")
    return true
  end
  liaison.journal("Registre : marque de la partie impossible à poser ; mémoire de secours seule")
  return false
end

-- Enregistre la chaîne du registre dans cette partie. La première fois, relit le jeton et dit au journal s'il tient.
function liaison.ecrire_registre(chaine)
  liaison.memoire.registre = chaine
  liaison.memoire.heure_ecrite = liaison.heure_du_jeu()
  if not (etat_du_fichier.identite_de_la_partie and entite_nommee(liaison.prefixe_de_la_marque .. etat_du_fichier.identite_de_la_partie)) then
    if not marquer_la_partie() then
      return
    end
  end
  local ok, erreur, n = ecrire_le_jeton(etat_du_fichier.identite_de_la_partie, chaine)
  if not etat_du_fichier.jeton_essaye then
    etat_du_fichier.jeton_essaye = true
    local _, relu, raison = lire_le_jeton()
    if ok and relu == chaine then
      liaison.journal("Registre : jeton du jeu en service (" .. #chaine .. " caractères, " .. n .. " tranche(s))")
    else
      liaison.journal("Registre : jeton du jeu refusé (" .. tostring(ok and (raison or "relu différent") or erreur)
                      .. ") ; mémoire de secours seule")
    end
  end
end

-- ---------------------------------------------------------------- fiche 01 : le registre par case
-- Un index (la liste des cases) et un flux par case, chacun en tranches, tous portant l'identité de la partie ; la
-- croyance en l'identité (sa marque, ou un passage de carte croyable) se décide sur l'index ; une case d'une autre
-- partie, ou abîmée, est refusée seule (la mémoire de secours la remplace).
liaison.nom_de_l_index = "scriptorium_socle.index"
liaison.prefixe_des_cases = "scriptorium_socle.case."

-- L'index de cette partie, ou nil (pas d'index : le registre relit l'ancien flux).
function liaison.lire_index()
  local identite, donnees, raison = lire_un_flux(liaison.nom_de_l_index)
  if not identite then
    return liaison.memoire.liste_des_cases
  end
  if croire(identite) then
    etat_du_fichier.identite_de_la_partie = identite
    liaison.memoire.identite = identite
    if raison then
      liaison.journal("Registre : index en tranches, refusé (" .. raison .. ")")
      return liaison.memoire.liste_des_cases
    end
    return donnees
  end
  if identite ~= liaison.identite_ignoree then
    liaison.identite_ignoree = identite
    liaison.journal("Registre : index d'une autre partie (" .. identite .. "), ignoré")
  end
  return liaison.memoire.liste_des_cases
end

function liaison.lire_case(nom)
  local identite, donnees, raison = lire_un_flux(liaison.prefixe_des_cases .. nom)
  if identite and identite == etat_du_fichier.identite_de_la_partie and not raison then
    return donnees
  end
  if identite and (raison or identite ~= etat_du_fichier.identite_de_la_partie) then
    liaison.journal("Registre : case « " .. nom .. " » refusée (" .. tostring(raison or ("d'une autre partie : " .. identite)) .. ")")
  end
  return liaison.memoire.cases[nom]
end

-- La partie marquée (une identité et sa marque dans le monde), sinon marquée maintenant. Rend vrai si elle l'est.
local function partie_marquee()
  if etat_du_fichier.identite_de_la_partie and entite_nommee(liaison.prefixe_de_la_marque .. etat_du_fichier.identite_de_la_partie) then
    return true
  end
  return marquer_la_partie()
end

function liaison.ecrire_index(chaine)
  liaison.memoire.liste_des_cases = chaine
  liaison.memoire.heure_ecrite = liaison.heure_du_jeu()
  if not partie_marquee() then
    return
  end
  local ok, erreur, n = ecrire_un_flux(liaison.nom_de_l_index, etat_du_fichier.identite_de_la_partie, chaine)
  if not etat_du_fichier.index_essaye then
    etat_du_fichier.index_essaye = true
    local _, relu, raison = lire_un_flux(liaison.nom_de_l_index)
    if ok and relu == chaine then
      liaison.journal("Registre : index par case en service (" .. #chaine .. " caractères, " .. n .. " tranche(s))")
    else
      liaison.journal("Registre : index refusé (" .. tostring(ok and (raison or "relu différent") or erreur)
                      .. ") ; mémoire de secours seule")
    end
  end
end

function liaison.ecrire_case(nom, chaine)
  liaison.memoire.cases[nom] = chaine
  liaison.memoire.heure_ecrite = liaison.heure_du_jeu()
  if not partie_marquee() then
    return
  end
  local ok, erreur = ecrire_un_flux(liaison.prefixe_des_cases .. nom, etat_du_fichier.identite_de_la_partie, chaine)
  if not ok then
    liaison.journal("Registre : case « " .. nom .. " » non écrite : " .. tostring(erreur))
  end
end

-- L'ancien flux unique, vidé (en-tête et tranches) une fois réécrit par case.
function liaison.effacer_l_ancien_registre()
  local entete = jeton(liaison.nom_du_jeton)
  local n = entete and tonumber(string.match(entete, "|tranches|(%d+)|")) or 0
  local ok, erreur = pcall(function()
    for i = 1, n do
      poser_un_jeton(string.format("%s.%d", liaison.nom_du_jeton, i), "")
    end
    if entete then
      poser_un_jeton(liaison.nom_du_jeton, "")
    end
  end)
  liaison.memoire.registre = nil
  if not ok then
    liaison.journal("Registre : ancien flux non vidé : " .. tostring(erreur))
  end
end

-- Position et cap d'Henry (cap de boussole), pour fonder le camp là où il se tient.
-- Vu en jeu le 14/10 : player:GetWorldPos() et player:GetWorldAngles() répondent ; z est en radians.
function liaison.position_du_joueur()
  local ok, p = pcall(function() return player:GetWorldPos() end)
  if ok and type(p) == "table" then
    return { x = p.x, y = p.y, z = p.z }
  end
  return { x = 0, y = 0, z = 0 }
end

function liaison.cap_du_joueur()
  local ok, angles = pcall(function() return player:GetWorldAngles() end)
  if ok and type(angles) == "table" and type(angles.z) == "number" then
    return cap_depuis_moteur(angles.z)
  end
  return 0
end

-- Vrai si le point est dans l'eau. AI.IsPointInWaterRegion peut rendre un nombre : en Lua, 0 compte comme vrai
-- (vu le 14/10 : tout passait pour de l'eau). Seuls true ou un nombre positif disent « dans l'eau ».
function liaison.dans_l_eau(point)
  local ok, valeur = pcall(function() return AI.IsPointInWaterRegion(point) end)
  if not ok then
    return false
  end
  return valeur == true or (type(valeur) == "number" and valeur > 0)
end

-- Pour le poste d'essai : pose Henry à « distance » mètres de lui, dans la direction « cap » (cap de boussole ;
-- par défaut celle où regarde le corps d'Henry, qui n'est pas forcément celle de la caméra), à la hauteur du
-- terrain (System.GetTerrainElevation). Refusé si la destination est dans l'eau (AI.IsPointInWaterRegion, essayé ;
-- vu le 14/10 : une règle « pas plus de deux mètres plus bas » refusait les simples descentes de colline).
-- Rend vrai et un compte rendu, ou faux et la raison.
function liaison.deplacer_le_joueur(distance, cap)
  local ok, resultat = pcall(function()
    local ici = player:GetWorldPos()
    local direction = math.rad(cap or liaison.cap_du_joueur())
    local cible = { x = ici.x + distance * math.sin(direction), y = ici.y + distance * math.cos(direction), z = ici.z }
    local sol = System.GetTerrainElevation(cible)
    if type(sol) ~= "number" then
      return { false, "hauteur du terrain illisible" }
    end
    cible.z = sol + 0.1
    if liaison.dans_l_eau(cible) then
      return { false, "destination dans l'eau" }
    end
    player:SetWorldPos(cible)
    return { true, string.format("de %.0f, %.0f, %.1f à %.0f, %.0f, %.1f", ici.x, ici.y, ici.z, cible.x, cible.y, cible.z) }
  end)
  if not ok then
    return false, tostring(resultat)
  end
  return resultat[1], resultat[2]
end

-- Pour le poste d'essai (V73 f 3 b, les intérieurs) : Henry posé à une position exacte (un plancher lu dans les calques
-- de la carte, jamais l'altitude du terrain), la pose relue aussitôt. Rend (vrai, compte rendu) s'il est à moins de 2 m
-- de la position, sinon (faux, compte rendu).
function liaison.poser_le_joueur(position)
  local ok, resultat = pcall(function()
    local avant = player:GetWorldPos()
    local de = string.format("%.0f, %.0f, %.1f", avant.x, avant.y, avant.z)
    player:SetWorldPos({ x = position.x, y = position.y, z = position.z })
    local apres = player:GetWorldPos()
    local ecart = math.sqrt((apres.x - position.x) ^ 2 + (apres.y - position.y) ^ 2 + (apres.z - position.z) ^ 2)
    return { ecart <= 2, string.format("de %s à %.1f, %.1f, %.1f, relu à %.1f m", de, apres.x, apres.y, apres.z, ecart) }
  end)
  if not ok then
    return false, tostring(resultat)
  end
  return resultat[1], resultat[2]
end

-- Pour le poste d'essai (V73 f 3 b, l'étage d'une auberge, méthode du pair) : la hauteur du premier obstacle fixe
-- (statique ou terrain, Physics.RayWorldIntersection dans la forme de sol_de) sous (x, y), en descendant de « z_depart »
-- sur « profondeur » m. Rend la hauteur touchée, ou nil et la raison.
function liaison.plancher_sous(x, y, z_depart, profondeur)
  if type(ent_static) ~= "number" or type(ent_terrain) ~= "number" then
    return nil, "masques illisibles (ent_static, ent_terrain)"
  end
  local touches = {}
  local lu, n = pcall(function()
    return Physics.RayWorldIntersection({ x = x, y = y, z = z_depart }, { x = 0, y = 0, z = -profondeur }, 1,
      ent_static + ent_terrain, nil, nil, touches)
  end)
  if not lu then
    return nil, "rayon refusé : " .. tostring(n)
  end
  local premier = touches[1]
  local z = premier and type(premier.pos) == "table" and tonumber(premier.pos.z) or nil
  if not z then
    return nil, "rien touché (" .. tostring(n) .. ")"
  end
  return z
end

-- Pour le poste d'essai : pose Henry à « distance » mètres d'un objet posé, du côté d'un point (le centre du camp).
function liaison.aller_pres_de(identifiant, vers, distance)
  local entite = entite_nommee(identifiant)
  if not entite then
    return false, "objet introuvable"
  end
  local ok, resultat = pcall(function()
    local p = entite:GetWorldPos()
    local dx, dy = vers.x - p.x, vers.y - p.y
    local longueur = math.sqrt(dx * dx + dy * dy)
    if longueur < 0.1 then
      return { false, "objet au centre" }
    end
    local cible = { x = p.x + dx / longueur * distance, y = p.y + dy / longueur * distance, z = 0 }
    cible = liaison.au_sol(cible)
    cible.z = cible.z + 0.1
    player:SetWorldPos(cible)
    return { true, string.format("Henry à %.0f m de %s (%.0f, %.0f)", distance, identifiant, cible.x, cible.y) }
  end)
  if not ok then
    return false, tostring(resultat)
  end
  return resultat[1], resultat[2]
end

-- Le terrain d'essai (demande de JoVenGer du 14/10 : pas dans un campement du jeu). Choisi à vue le 14/10 :
-- un pré dégagé, en pente douce, à 80 m à l'ouest du campement du début du jeu (Trosecko), sans tente,
-- avec la rivière au sud. Une recherche automatique a été essayée et retirée : les arbres et les buissons
-- ne se voient pas par le calcul (elle posait Henry en forêt ou dans les fourrés).
liaison.terrain_d_essai = { x = 839, y = 2000 }

function liaison.aller_au_terrain_d_essai()
  local ok, resultat = pcall(function()
    local cible = { x = liaison.terrain_d_essai.x, y = liaison.terrain_d_essai.y, z = 0 }
    local sol = System.GetTerrainElevation(cible)
    if type(sol) ~= "number" then
      return { false, "hauteur du terrain illisible" }
    end
    cible.z = sol + 0.1
    player:SetWorldPos(cible)
    return { true, string.format("terrain d'essai %.0f, %.0f, %.1f", cible.x, cible.y, cible.z) }
  end)
  if not ok then
    return false, tostring(resultat)
  end
  return resultat[1], resultat[2]
end
-- Nos âmes (fiche 13, validée par JoVenGer le 15/10/2026) : une âme par personne vivante, jamais partagée, dans
-- Libs/Tables/rpg/soul__scriptorium_socle.xml (lignes écrites par outils/ames.py, toutes avec notre cerveau). Elles
-- remplacent les âmes de gardes de Trosky empruntées au jeu (extraGuards_dummy_1, 3, 5 ; cerveau du jeu, V16). Par
-- réserve, le nombre d'âmes de chaque palier dans la table ; l'identifiant se calcule à partir de la réserve, du palier et
-- du numéro (préfixe absent des âmes du jeu). tout_verifier.py vérifie que la table et ces tailles s'accordent.
-- « visages » (demande du pair, 18/10 : pas de jumeaux) : le nombre de personnages du jeu de la palette de la réserve
-- (outils/ames.py) ; l'âme de rang r (compté sur tous les paliers) porte le visage numéro r mod visages.
liaison.reserves_d_ames = {
  combattant = { code = 1, paliers = { 80, 80, 80 }, visages = 71 },   -- recrue, confirmé, vétéran
  metier     = { code = 2, paliers = { 50 }, visages = 50 },
  femme      = { code = 3, paliers = { 30 }, visages = 30 },
  directeur  = { code = 4, paliers = { 1 }, visages = 1 },
}

-- L'identifiant d'une âme, ou nil hors des réserves.
function liaison.ame_de(reserve, palier, numero)
  local r = liaison.reserves_d_ames[reserve]
  local taille = r and r.paliers[palier]
  if type(taille) ~= "number" or type(numero) ~= "number" or numero ~= math.floor(numero) or numero < 1 or numero > taille then
    return nil
  end
  return string.format("5c7a5c7a-%04x-4%03x-8000-%012x", r.code, palier, numero)
end

-- Le visage d'une âme de nos réserves : « réserve:numéro du visage » (deux âmes au même visage sont des jumeaux), ou nil.
function liaison.visage_de(ame)
  local code, palier, numero = string.match(string.lower(tostring(ame)), "^5c7a5c7a%-(%x%x%x%x)%-4(%x%x%x)%-8000%-(%x+)$")
  if not code then
    return nil
  end
  code, palier, numero = tonumber(code, 16), tonumber(palier, 16), tonumber(numero, 16)
  for nom, r in pairs(liaison.reserves_d_ames) do
    if r.code == code and r.paliers[palier] and numero <= r.paliers[palier] then
      local rang = numero - 1
      for p = 1, palier - 1 do
        rang = rang + r.paliers[p]
      end
      return nom .. ":" .. (rang % r.visages)
    end
  end
  return nil
end

-- Le nombre d'âmes de chaque palier d'une réserve (une copie), ou une liste vide.
function liaison.paliers_de(reserve)
  local r = liaison.reserves_d_ames[reserve]
  local copie = {}
  for i, n in ipairs(r and r.paliers or {}) do
    copie[i] = n
  end
  return copie
end

-- DÉBUT DES PIÈCES (écrit par outils/equipement.py ; ne pas modifier à la main)
-- Les pièces de chaque préréglage retenu (fiche 13, V71 b), dans l'ordre du jeu, créées une à une par le socle ;
-- et l'objet des munitions de nos assemblages de tir (leur nombre est une règle de hommes.equipement).
liaison.pieces_des_prereglages = {
  ["axe_2_01"] = { "81494400-b654-4aa7-8f31-c95c689db5f6" },
  ["axe_3_01"] = { "53612e76-76fd-4dca-84b6-7905b986dc3b" },
  ["axe_5_01"] = { "0f0164d5-3746-4d07-a1ed-0f138225a6d9" },
  ["axe_shield_3_01"] = { "53612e76-76fd-4dca-84b6-7905b986dc3b", "2fd517a8-e990-45a1-8fbc-e4b3636cf30a" },
  ["axe_shield_3_02"] = { "53612e76-76fd-4dca-84b6-7905b986dc3b", "aff5df75-e6f0-4f0f-a4b7-de6cd7ab0a5e" },
  ["axe_shield_3_03"] = { "53612e76-76fd-4dca-84b6-7905b986dc3b", "684cb3f5-a873-44cb-9a8e-413b3bd6a0e5" },
  ["axe_shield_4_01"] = { "bd74ce18-2623-48ba-a1a1-c9b09bbb2827", "8baa70c0-222a-42dc-a289-035c83a33d5e" },
  ["axe_shield_4_02"] = { "bd74ce18-2623-48ba-a1a1-c9b09bbb2827", "ee57f6f1-dc5c-489b-912a-bf3f3a76d357" },
  ["axe_shield_5_01"] = { "0f0164d5-3746-4d07-a1ed-0f138225a6d9", "760d7474-6e5f-4987-9631-d007d5fff22e" },
  ["axe_shield_6_01"] = { "214ffcdd-a7a7-4b7a-b484-f60c8d00b39b", "37bffa89-4b82-48f9-9e84-b52c0130b0af" },
  ["huntingsword_shield_3_01"] = { "505b8feb-9447-462f-ab3d-68557f89d9f3", "684cb3f5-a873-44cb-9a8e-413b3bd6a0e5" },
  ["huntingsword_shield_3_02"] = { "505b8feb-9447-462f-ab3d-68557f89d9f3", "684cb3f5-a873-44cb-9a8e-413b3bd6a0e5" },
  ["huntingsword_shield_4_01"] = { "c58fa1d7-dd10-45e1-b6da-b65f1d0b3f7a", "cf5a563b-2a84-4270-92ed-c414b46a82bf" },
  ["longsword_3_01"] = { "bdb6fc2a-43e4-40b8-93c8-f2d9162c1e45" },
  ["longsword_4_01"] = { "9e31a288-7de0-4c0d-81cd-5cf00548d2d5" },
  ["longsword_5_01"] = { "3858560f-cf48-436f-8815-4426003288fb" },
  ["longsword_5_02"] = { "23855649-1783-4e0d-95ad-d3478797b642" },
  ["longsword_6_01"] = { "00cca9e3-8ef2-46db-8cbf-86ec51930919" },
  ["mace_shield_2_01"] = { "9cc07405-4195-46ab-bf17-fd0fd99721bd", "e4e1b22a-428a-4e20-aa92-ce216b324c0a" },
  ["mace_shield_2_02"] = { "9cc07405-4195-46ab-bf17-fd0fd99721bd", "3edb6ed3-6fef-4f7a-9ded-e0a842dce10e" },
  ["mace_shield_2_03"] = { "9cc07405-4195-46ab-bf17-fd0fd99721bd", "684cb3f5-a873-44cb-9a8e-413b3bd6a0e5" },
  ["mace_shield_3_02"] = { "00b0039b-daa4-4f32-ac7f-69a6a2e0add8", "8baa70c0-222a-42dc-a289-035c83a33d5e" },
  ["mace_shield_3_03"] = { "af6a6142-c6f7-4ae7-94a9-bb5be41ebecc", "f0720bb0-b964-40fe-b358-b84a35ecb601" },
  ["mace_shield_3_04"] = { "c67de991-e22a-4a19-8b68-9369919c41dd", "3edb6ed3-6fef-4f7a-9ded-e0a842dce10e" },
  ["mace_shield_4_01"] = { "839992c8-657b-4d5e-97c9-96ff94430d72", "25d5e06c-09e2-405a-b0e8-4ffb6d44c975" },
  ["mace_shield_4_02"] = { "839992c8-657b-4d5e-97c9-96ff94430d72", "9baedc28-f193-41a6-8035-2c6e3343219b" },
  ["mace_shield_5_01"] = { "65a211bd-2c7e-40a8-984f-66c8730444e4", "2fd517a8-e990-45a1-8fbc-e4b3636cf30a" },
  ["mace_shield_6_01"] = { "f2e86f22-8932-4751-8f62-fb1b8b846ddf", "e4e1b22a-428a-4e20-aa92-ce216b324c0a" },
  ["polearm_2_01"] = { "e5f25908-a843-456a-b095-c31db34aa577" },
  ["polearm_2_02"] = { "f4324daf-fe09-495e-b954-16f23226cf58" },
  ["polearm_3_01"] = { "03b6321d-4151-46cd-bdec-451ea7bfaabc" },
  ["polearm_3_02"] = { "0f41ad99-3307-47c8-a110-a7d9b4af75e8" },
  ["polearm_3_03"] = { "03b6321d-4151-46cd-bdec-451ea7bfaabc" },
  ["polearm_4_01"] = { "7cac0c1a-ad34-4fd7-a1e6-4d45edcf307f" },
  ["polearm_4_02"] = { "4bda3dd1-871c-452a-87fe-b783946435c2" },
  ["polearm_5_01"] = { "51bb7893-2054-40d3-a355-d278f416c482" },
  ["polearm_6_01"] = { "51bb7893-2054-40d3-a355-d278f416c482" },
  ["scriptorium_arbaletrier_1_a"] = { "7673efc2-0566-4dde-9e18-f96c7790ce2e", "efa237c7-3905-4813-b9c3-a32b449c17ad" },
  ["scriptorium_arbaletrier_1_b"] = { "cb6ee20b-6eee-434c-af4c-8031502e2bec", "efa237c7-3905-4813-b9c3-a32b449c17ad" },
  ["scriptorium_arbaletrier_2_a"] = { "b77f912a-042b-47ca-8f42-5fddbcad3763", "efa237c7-3905-4813-b9c3-a32b449c17ad" },
  ["scriptorium_arbaletrier_2_b"] = { "48f25a62-e787-490e-83e9-9335bf303ef9", "efa237c7-3905-4813-b9c3-a32b449c17ad" },
  ["scriptorium_arbaletrier_3_a"] = { "f0fb0494-6ebd-4c6a-bb9e-ef396db3c5d4", "efa237c7-3905-4813-b9c3-a32b449c17ad" },
  ["scriptorium_arbaletrier_3_b"] = { "588c12c6-f0fb-4b3e-847d-ce1df2739e73", "efa237c7-3905-4813-b9c3-a32b449c17ad" },
  ["scriptorium_archer_1"] = { "0fffb172-2183-4545-bbdb-01e04a3ff32f", "efa237c7-3905-4813-b9c3-a32b449c17ad" },
  ["scriptorium_archer_2"] = { "d2011311-2315-43a1-a953-76432df04329", "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a" },
  ["scriptorium_archer_3"] = { "77262956-daee-4a0e-9035-517569f18ef4", "b3f7a363-5526-45b1-a32b-422a0a8e4da4" },
  ["soldier_generic_1_01"] = { "d4ade1cb-79dd-41a7-8d72-7bd88ec2e0d4", "8ec8f99a-57a7-4006-bb61-1f737996a0a9", "ffd9af7c-d24d-4e70-8c25-ad22a37a64e7", "62183c25-a930-4044-8e08-243c5d46c6cc", "81e27f41-709f-47c8-96b3-8f8c9619d2fa", "45b6d780-23e1-4a89-a0b1-dbc234a7ce21" },
  ["soldier_generic_1_02"] = { "121c90c7-3543-4078-9360-94977d2e16ec", "8ec8f99a-57a7-4006-bb61-1f737996a0a9", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "62183c25-a930-4044-8e08-243c5d46c6cc", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "51d9a001-eb09-4db8-98f0-d23b794c530d", "3b0a1c2e-c631-47d6-b5f4-ac798318e86d", "6021520e-b6a9-4daf-adce-21a8a208646c", "fbc58e41-81e9-4447-8a86-e9d236b9dad5" },
  ["soldier_generic_1_03"] = { "ccd43d26-4668-48db-acd5-82a7226bf5e6", "6069fdce-2661-4870-815b-20c37aeda40c", "2a169fbe-251a-49f8-85d1-0b9a651f61d1", "62183c25-a930-4044-8e08-243c5d46c6cc", "868581d6-f9ab-4ae2-b074-9200e7d054bd", "a856e87a-8065-4338-919d-0aff7a63341d" },
  ["soldier_generic_1_04"] = { "f3aa4492-06fb-4ce3-9e41-784cbac8801f", "73b9efe7-4082-4d5a-a879-4b5c7bdc5ea2", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "62183c25-a930-4044-8e08-243c5d46c6cc", "965274e3-4b6e-49de-b49e-778aafbe1762", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "6021520e-b6a9-4daf-adce-21a8a208646c", "e5e650f0-dc71-48ff-afaa-b61c7770284e" },
  ["soldier_generic_1_05"] = { "d4ade1cb-79dd-41a7-8d72-7bd88ec2e0d4", "6069fdce-2661-4870-815b-20c37aeda40c", "2a169fbe-251a-49f8-85d1-0b9a651f61d1", "62183c25-a930-4044-8e08-243c5d46c6cc", "cb4cc490-717b-4a56-8e73-0b2f5820e0dd", "44e538cc-56f9-4027-a0ff-dbb96004d0e3", "6021520e-b6a9-4daf-adce-21a8a208646c" },
  ["soldier_generic_1_06"] = { "d4ade1cb-79dd-41a7-8d72-7bd88ec2e0d4", "100b9146-1c41-4136-9991-ff80983f1955", "2a169fbe-251a-49f8-85d1-0b9a651f61d1", "62183c25-a930-4044-8e08-243c5d46c6cc", "634ed69a-23dd-43e2-8208-73c167490d01", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "e5e650f0-dc71-48ff-afaa-b61c7770284e" },
  ["soldier_generic_1_07"] = { "d4ade1cb-79dd-41a7-8d72-7bd88ec2e0d4", "100b9146-1c41-4136-9991-ff80983f1955", "2a169fbe-251a-49f8-85d1-0b9a651f61d1", "e57a90f9-837c-466b-90a7-5be5ad7023a7", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "0a46c96b-11fa-4627-8a89-786a4577a441", "0973959e-9c95-477a-bbfc-31de29a429e9", "a856e87a-8065-4338-919d-0aff7a63341d" },
  ["soldier_generic_1_08"] = { "b173b837-5ee6-4b16-b843-b72eae1a1ce6", "018c1614-ddbf-4d9b-a797-40330be86c1c", "62183c25-a930-4044-8e08-243c5d46c6cc", "a1526093-c93e-4b10-9bb2-6d75ef8bf9dc", "cb4cc490-717b-4a56-8e73-0b2f5820e0dd", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "315fa220-fcb8-44e3-9a68-545c6822ec9f", "892f8540-77ed-4f33-9bf5-a8c2b17df4bf" },
  ["soldier_generic_1_09"] = { "f3aa4492-06fb-4ce3-9e41-784cbac8801f", "73b9efe7-4082-4d5a-a879-4b5c7bdc5ea2", "62183c25-a930-4044-8e08-243c5d46c6cc", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "3b0a1c2e-c631-47d6-b5f4-ac798318e86d", "3f72f25b-8763-4434-bec7-a2640057ad1e" },
  ["soldier_generic_1_10"] = { "6c9dcdf3-7db0-4272-94d5-939014a6accc", "867cddb7-32e6-4a3d-98f2-f6b9ba3ae7c9", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "62183c25-a930-4044-8e08-243c5d46c6cc", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "868581d6-f9ab-4ae2-b074-9200e7d054bd", "13eccab3-ee46-40e4-b0d1-73f3acde338c", "44e538cc-56f9-4027-a0ff-dbb96004d0e3", "a856e87a-8065-4338-919d-0aff7a63341d" },
  ["soldier_generic_1_11"] = { "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "91e17195-0d9f-4373-ab2a-aed59193ac2d", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "62183c25-a930-4044-8e08-243c5d46c6cc", "81e27f41-709f-47c8-96b3-8f8c9619d2fa", "44e538cc-56f9-4027-a0ff-dbb96004d0e3" },
  ["soldier_generic_1_12"] = { "73b9efe7-4082-4d5a-a879-4b5c7bdc5ea2", "8a8e914e-d384-4e7b-ae5e-534f48679c85", "2a169fbe-251a-49f8-85d1-0b9a651f61d1", "62183c25-a930-4044-8e08-243c5d46c6cc", "965274e3-4b6e-49de-b49e-778aafbe1762", "4e5c9449-d757-415d-b418-e5276218ee1e", "992f2afc-ee61-4787-a359-8c6adbfa7c40" },
  ["soldier_generic_1_13"] = { "b091659c-7293-4a63-992f-1b4bde3b87fd", "91e17195-0d9f-4373-ab2a-aed59193ac2d", "2a169fbe-251a-49f8-85d1-0b9a651f61d1", "62183c25-a930-4044-8e08-243c5d46c6cc", "cb4cc490-717b-4a56-8e73-0b2f5820e0dd", "76f096c4-6829-43fb-8101-a163d15468e0", "a856e87a-8065-4338-919d-0aff7a63341d", "0027df44-5f9c-4c92-9f81-a83ca124c4a8" },
  ["soldier_generic_2_01"] = { "100b9146-1c41-4136-9991-ff80983f1955", "333a3cc8-516d-44cc-8d07-4158326c235e", "6fad4fc0-eb11-4394-943f-d8def9871cc2", "62183c25-a930-4044-8e08-243c5d46c6cc", "1149024d-72f5-405d-8edb-041d58b59f74", "4e5c9449-d757-415d-b418-e5276218ee1e", "c01ca195-4129-4fbd-a966-f8eb7b162ddf", "02e23cb9-05aa-4aab-bbb8-4023a72e22f9", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "6021520e-b6a9-4daf-adce-21a8a208646c", "97318a25-2aa3-458b-b4f0-7f265fba32a0" },
  ["soldier_generic_2_02"] = { "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "cc1adb78-fa5a-45c9-be7b-b7b50e182cb3", "192733fd-accf-41bc-bb8e-7854d3ba3443", "942a42a0-5c46-4c46-983a-71d86adb43c4", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "4e5c9449-d757-415d-b418-e5276218ee1e", "e4222df1-647a-4652-9be9-9a7a72230182", "513342ce-7788-4c3e-8352-4febb17a609c", "e5e650f0-dc71-48ff-afaa-b61c7770284e" },
  ["soldier_generic_2_03"] = { "b091659c-7293-4a63-992f-1b4bde3b87fd", "be916959-2459-4a31-81fc-4b00090c3f42", "942a42a0-5c46-4c46-983a-71d86adb43c4", "a8a8db9c-955c-410f-9d47-1af70d917900", "09ba8849-d20d-48f2-b94e-c36f10abcf41", "b128bc50-58da-494a-ba3d-c47d2d044e7c", "b8df2253-e5c8-4e6c-9303-b4bc84192e67" },
  ["soldier_generic_2_04"] = { "73b9efe7-4082-4d5a-a879-4b5c7bdc5ea2", "6fad4fc0-eb11-4394-943f-d8def9871cc2", "62183c25-a930-4044-8e08-243c5d46c6cc", "1149024d-72f5-405d-8edb-041d58b59f74", "13eccab3-ee46-40e4-b0d1-73f3acde338c", "3b0a1c2e-c631-47d6-b5f4-ac798318e86d", "2cfb13ee-d15c-48d3-84e0-fed50436c49f" },
  ["soldier_generic_2_05"] = { "b091659c-7293-4a63-992f-1b4bde3b87fd", "08d82149-af01-48b6-9e72-b3f000da5e5f", "2a169fbe-251a-49f8-85d1-0b9a651f61d1", "62183c25-a930-4044-8e08-243c5d46c6cc", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "4e5c9449-d757-415d-b418-e5276218ee1e", "965274e3-4b6e-49de-b49e-778aafbe1762", "e5e650f0-dc71-48ff-afaa-b61c7770284e" },
  ["soldier_generic_2_06"] = { "100b9146-1c41-4136-9991-ff80983f1955", "993d563a-7a0b-46d9-8aba-5a9d689bfa03", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "942a42a0-5c46-4c46-983a-71d86adb43c4", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "868581d6-f9ab-4ae2-b074-9200e7d054bd", "b128bc50-58da-494a-ba3d-c47d2d044e7c" },
  ["soldier_generic_2_07"] = { "fe365538-9abe-41ca-90e8-97e191662490", "8a8e914e-d384-4e7b-ae5e-534f48679c85", "8662ab7a-6af0-468a-8bce-a1a8768c24b7", "62183c25-a930-4044-8e08-243c5d46c6cc", "1149024d-72f5-405d-8edb-041d58b59f74", "02e23cb9-05aa-4aab-bbb8-4023a72e22f9", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "b128bc50-58da-494a-ba3d-c47d2d044e7c", "c01ca195-4129-4fbd-a966-f8eb7b162ddf" },
  ["soldier_generic_2_08"] = { "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "192733fd-accf-41bc-bb8e-7854d3ba3443", "9748ecfc-9f6d-4a84-88f8-d5259070a35c", "942a42a0-5c46-4c46-983a-71d86adb43c4", "899ea0bb-89ea-495c-ad69-29e76fb7bb9e", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "4e5c9449-d757-415d-b418-e5276218ee1e", "09ba8849-d20d-48f2-b94e-c36f10abcf41", "a856e87a-8065-4338-919d-0aff7a63341d" },
  ["soldier_generic_2_09"] = { "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "8a8e914e-d384-4e7b-ae5e-534f48679c85", "942a42a0-5c46-4c46-983a-71d86adb43c4", "a8a8db9c-955c-410f-9d47-1af70d917900", "3b0a1c2e-c631-47d6-b5f4-ac798318e86d", "c01ca195-4129-4fbd-a966-f8eb7b162ddf", "0bd0ee54-f7c8-4808-b620-da6d059640fe", "fbc58e41-81e9-4447-8a86-e9d236b9dad5" },
  ["soldier_generic_2_10"] = { "73b9efe7-4082-4d5a-a879-4b5c7bdc5ea2", "6fad4fc0-eb11-4394-943f-d8def9871cc2", "62183c25-a930-4044-8e08-243c5d46c6cc", "1149024d-72f5-405d-8edb-041d58b59f74", "13eccab3-ee46-40e4-b0d1-73f3acde338c", "3b0a1c2e-c631-47d6-b5f4-ac798318e86d", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "2cfb13ee-d15c-48d3-84e0-fed50436c49f", "9bd6afca-f2cd-45b2-b057-2586811817f8" },
  ["soldier_generic_2_11"] = { "b091659c-7293-4a63-992f-1b4bde3b87fd", "9da82290-e31b-4ba6-b0e8-680081e06e9a", "4724c8d8-c049-46bf-a5f3-8bf51ea74828", "2a169fbe-251a-49f8-85d1-0b9a651f61d1", "62183c25-a930-4044-8e08-243c5d46c6cc", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "4e5c9449-d757-415d-b418-e5276218ee1e", "965274e3-4b6e-49de-b49e-778aafbe1762", "a856e87a-8065-4338-919d-0aff7a63341d" },
  ["soldier_generic_2_12"] = { "fe365538-9abe-41ca-90e8-97e191662490", "b49694c9-31dd-49f0-bc1b-be86644cf1fa", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "942a42a0-5c46-4c46-983a-71d86adb43c4", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "868581d6-f9ab-4ae2-b074-9200e7d054bd", "52d761bd-6c65-4eb0-9763-7c6c025a621d", "fc214bc3-f5cb-402a-a2e6-ba27622d9eab" },
  ["soldier_generic_2_13"] = { "b5bfc0d3-b4e2-421c-ae14-4bce9f1f54be", "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "9da82290-e31b-4ba6-b0e8-680081e06e9a", "62183c25-a930-4044-8e08-243c5d46c6cc", "1149024d-72f5-405d-8edb-041d58b59f74", "02e23cb9-05aa-4aab-bbb8-4023a72e22f9", "8dd4862d-8290-4f36-ac8b-c53d42c60f65", "c01ca195-4129-4fbd-a966-f8eb7b162ddf", "786efb5a-320e-4c2c-aec8-fc4c8ba2d534", "b40942a9-f067-4a6d-8cd3-59a03e8a59d1" },
  ["soldier_generic_3_01"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "d20252f7-51f0-4f8e-857c-b086fcec15be", "5d5b2f4d-5f18-4ebe-ae2e-6eccbd8f92ea", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "f8f97efa-a624-486d-b966-fbf35757431f", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "177e55fc-31bc-40dc-b399-899b478093d0", "d3bc6b02-d678-4336-8d4a-6f4157fd1376" },
  ["soldier_generic_3_02"] = { "100b9146-1c41-4136-9991-ff80983f1955", "6fad4fc0-eb11-4394-943f-d8def9871cc2", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "38102e92-9a28-4d57-85c4-716b97a0ecb8", "cfc1fd72-dbb7-49a4-8713-6acf215a72be", "63eff267-424a-43fd-a5ec-132c89c286f0", "7c8cdd6c-b094-4b70-b588-286b50cffe02", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "ca521570-403a-4a72-b7cf-58cca2869052" },
  ["soldier_generic_3_03"] = { "c6a66736-2f9e-4c0c-9def-4d6fd5906b82", "72a7e155-fae8-4c97-bad7-458664218252", "9da82290-e31b-4ba6-b0e8-680081e06e9a", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "3a1811fb-124e-4dbd-95ee-114debe21091", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "38c34f78-cfa0-40c9-a94e-5e04dcf35608", "7d602455-05bc-49b9-a11f-67c76992016c", "86055ea8-0e06-47f2-a976-e5453bdf84d1", "9c6aac7c-4797-4aa9-a297-939fd5e5a54e", "e5e650f0-dc71-48ff-afaa-b61c7770284e" },
  ["soldier_generic_3_04"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "9da82290-e31b-4ba6-b0e8-680081e06e9a", "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "942a42a0-5c46-4c46-983a-71d86adb43c4", "177e55fc-31bc-40dc-b399-899b478093d0", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "7d602455-05bc-49b9-a11f-67c76992016c", "38c34f78-cfa0-40c9-a94e-5e04dcf35608", "ca521570-403a-4a72-b7cf-58cca2869052" },
  ["soldier_generic_3_05"] = { "100b9146-1c41-4136-9991-ff80983f1955", "d86cfc84-c1b4-4b13-bfcb-a09c5ae6d314", "d20252f7-51f0-4f8e-857c-b086fcec15be", "a8a8db9c-955c-410f-9d47-1af70d917900", "260ccafb-0504-4c17-9833-304539d30698", "63eff267-424a-43fd-a5ec-132c89c286f0", "9c6aac7c-4797-4aa9-a297-939fd5e5a54e", "48e7619e-9436-4f27-948c-1577daa9a6e9", "263e6aa0-cffd-4c30-87ea-98e3fcaa4dc7", "6021520e-b6a9-4daf-adce-21a8a208646c" },
  ["soldier_generic_3_06"] = { "100b9146-1c41-4136-9991-ff80983f1955", "5a189394-0191-4545-9d9f-98db7fce4745", "d20252f7-51f0-4f8e-857c-b086fcec15be", "260ccafb-0504-4c17-9833-304539d30698", "9dfd4215-673d-460b-a052-a38ba439857e", "d1926fdf-d10e-4ab5-9531-2deeff6f8d07", "fb7ebf36-7aea-410d-800e-2482193d0982", "c01ca195-4129-4fbd-a966-f8eb7b162ddf", "3f72f25b-8763-4434-bec7-a2640057ad1e" },
  ["soldier_generic_3_07"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "e1c454dd-9834-4da0-940e-da2a27b0b795", "d20252f7-51f0-4f8e-857c-b086fcec15be", "260ccafb-0504-4c17-9833-304539d30698", "faed9509-92fe-42f2-be78-3c07d2c494b5", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "0bd0ee54-f7c8-4808-b620-da6d059640fe", "fb7ebf36-7aea-410d-800e-2482193d0982" },
  ["soldier_generic_3_08"] = { "01fd6791-d9dc-46d3-8331-1ac65ee61dd5", "cdafe0da-d6fa-4285-80e2-02ad7626f3dd", "d20252f7-51f0-4f8e-857c-b086fcec15be", "260ccafb-0504-4c17-9833-304539d30698", "627e8530-e405-487b-9bef-7f85d2459360", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "0a46c96b-11fa-4627-8a89-786a4577a441", "c01ca195-4129-4fbd-a966-f8eb7b162ddf", "ba9c9623-40fc-49ee-8eee-5f3ba2b93e74" },
  ["soldier_generic_3_09"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "d20252f7-51f0-4f8e-857c-b086fcec15be", "5d5b2f4d-5f18-4ebe-ae2e-6eccbd8f92ea", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "177e55fc-31bc-40dc-b399-899b478093d0", "0a46c96b-11fa-4627-8a89-786a4577a441", "77288289-02b0-4664-86b7-c786163388c9" },
  ["soldier_generic_3_10"] = { "100b9146-1c41-4136-9991-ff80983f1955", "6fad4fc0-eb11-4394-943f-d8def9871cc2", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "38102e92-9a28-4d57-85c4-716b97a0ecb8", "cfc1fd72-dbb7-49a4-8713-6acf215a72be", "7c8cdd6c-b094-4b70-b588-286b50cffe02", "ca521570-403a-4a72-b7cf-58cca2869052", "e9f59d27-ee5f-4a7e-8341-643854166285", "233e4fbc-42b8-4a70-a699-8b1978419f0c", "513342ce-7788-4c3e-8352-4febb17a609c" },
  ["soldier_generic_3_11"] = { "c6a66736-2f9e-4c0c-9def-4d6fd5906b82", "72a7e155-fae8-4c97-bad7-458664218252", "9da82290-e31b-4ba6-b0e8-680081e06e9a", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "d20252f7-51f0-4f8e-857c-b086fcec15be", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "38c34f78-cfa0-40c9-a94e-5e04dcf35608", "7d602455-05bc-49b9-a11f-67c76992016c", "86055ea8-0e06-47f2-a976-e5453bdf84d1", "b107b189-7eea-4eae-bc64-2a23bd650b14" },
  ["soldier_generic_3_12"] = { "5a189394-0191-4545-9d9f-98db7fce4745", "9da82290-e31b-4ba6-b0e8-680081e06e9a", "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "942a42a0-5c46-4c46-983a-71d86adb43c4", "260ccafb-0504-4c17-9833-304539d30698", "177e55fc-31bc-40dc-b399-899b478093d0", "38c34f78-cfa0-40c9-a94e-5e04dcf35608", "ca521570-403a-4a72-b7cf-58cca2869052", "215026f1-e62b-4aa5-a919-36ece35a7817" },
  ["soldier_generic_3_13"] = { "100b9146-1c41-4136-9991-ff80983f1955", "d86cfc84-c1b4-4b13-bfcb-a09c5ae6d314", "d20252f7-51f0-4f8e-857c-b086fcec15be", "a8a8db9c-955c-410f-9d47-1af70d917900", "260ccafb-0504-4c17-9833-304539d30698", "48e7619e-9436-4f27-948c-1577daa9a6e9", "263e6aa0-cffd-4c30-87ea-98e3fcaa4dc7", "51ea4abf-bff3-4458-89f2-2ed18a4340a2", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "a856e87a-8065-4338-919d-0aff7a63341d" },
  ["soldier_generic_3_14"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "d20252f7-51f0-4f8e-857c-b086fcec15be", "9dfd4215-673d-460b-a052-a38ba439857e", "260ccafb-0504-4c17-9833-304539d30698", "fb7ebf36-7aea-410d-800e-2482193d0982", "c01ca195-4129-4fbd-a966-f8eb7b162ddf", "3d03fd46-32cb-4a9c-a7a1-f159a5f926d0", "a3c3146a-84a7-4c98-a7a9-eb27d547e547", "315fa220-fcb8-44e3-9a68-545c6822ec9f" },
  ["soldier_generic_3_15"] = { "fe365538-9abe-41ca-90e8-97e191662490", "6ca69142-da64-4abc-b989-682fc91b83c7", "d20252f7-51f0-4f8e-857c-b086fcec15be", "7ae64aa3-444f-4f10-b05d-4a943c965551", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "0bd0ee54-f7c8-4808-b620-da6d059640fe", "cc672cc6-b8a8-4604-bf1d-6f42716fab59", "7d602455-05bc-49b9-a11f-67c76992016c" },
  ["soldier_generic_3_16"] = { "c42f0260-8490-438a-a67b-ae521a48bf0d", "9748ecfc-9f6d-4a84-88f8-d5259070a35c", "d20252f7-51f0-4f8e-857c-b086fcec15be", "627e8530-e405-487b-9bef-7f85d2459360", "0a46c96b-11fa-4627-8a89-786a4577a441", "c01ca195-4129-4fbd-a966-f8eb7b162ddf", "3024ad3e-9647-41f7-9be6-0aa29c2e7bd2", "54933fe9-c9e1-43af-b0bf-8595fc3bad76", "978586ca-3269-493b-a1fd-88ae04a6ded6", "e5e650f0-dc71-48ff-afaa-b61c7770284e" },
  ["soldier_generic_4_01"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "a8a8db9c-955c-410f-9d47-1af70d917900", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "713a4f57-647f-4ab6-8c6e-ad189f6f5eee", "3b912b8e-3669-43e6-a53f-8136b7ae3e99", "a856e87a-8065-4338-919d-0aff7a63341d" },
  ["soldier_generic_4_02"] = { "a157447c-3c6f-463a-a02d-d4b696e644e1", "fe365538-9abe-41ca-90e8-97e191662490", "a8a8db9c-955c-410f-9d47-1af70d917900", "62a81406-526e-400a-bea3-16cc76dfd069", "38102e92-9a28-4d57-85c4-716b97a0ecb8", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "7c8cdd6c-b094-4b70-b588-286b50cffe02", "737fcf80-5ce8-45d2-9ffe-10b952d125a0", "8472dd03-91d6-4496-a92e-e6e9baaa46ba", "fbc58e41-81e9-4447-8a86-e9d236b9dad5" },
  ["soldier_generic_4_03"] = { "a6f4fcf5-9d0a-45c4-8641-b9689415983b", "c6a66736-2f9e-4c0c-9def-4d6fd5906b82", "d20252f7-51f0-4f8e-857c-b086fcec15be", "260ccafb-0504-4c17-9833-304539d30698", "a8a8db9c-955c-410f-9d47-1af70d917900", "3437c616-a14c-4ba2-a382-f4898765eeff", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "63eff267-424a-43fd-a5ec-132c89c286f0" },
  ["soldier_generic_4_04"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "fe365538-9abe-41ca-90e8-97e191662490", "a8a8db9c-955c-410f-9d47-1af70d917900", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "713a4f57-647f-4ab6-8c6e-ad189f6f5eee", "8472dd03-91d6-4496-a92e-e6e9baaa46ba", "892f8540-77ed-4f33-9bf5-a8c2b17df4bf" },
  ["soldier_generic_4_05"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "100b9146-1c41-4136-9991-ff80983f1955", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "627e8530-e405-487b-9bef-7f85d2459360", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "7e55a88a-1a07-443e-846b-b24217c732f9", "916a6a5e-a1c1-4db7-b573-909c139a1b52", "48bd6984-747d-4ae3-9489-666a2bdcd66c", "6021520e-b6a9-4daf-adce-21a8a208646c" },
  ["soldier_generic_4_06"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "fe365538-9abe-41ca-90e8-97e191662490", "a8a8db9c-955c-410f-9d47-1af70d917900", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "9c6aac7c-4797-4aa9-a297-939fd5e5a54e", "e9f59d27-ee5f-4a7e-8341-643854166285", "48e7619e-9436-4f27-948c-1577daa9a6e9", "f7bcdadb-de2f-4576-b84f-474c2a56804f" },
  ["soldier_generic_4_07"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "fe365538-9abe-41ca-90e8-97e191662490", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "7ae64aa3-444f-4f10-b05d-4a943c965551", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "8472dd03-91d6-4496-a92e-e6e9baaa46ba", "916a6a5e-a1c1-4db7-b573-909c139a1b52", "d3bc6b02-d678-4336-8d4a-6f4157fd1376" },
  ["soldier_generic_4_08"] = { "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "8a8e914e-d384-4e7b-ae5e-534f48679c85", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "5a0fb76a-1999-450d-ab39-48cf75d9952e", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "76f096c4-6829-43fb-8101-a163d15468e0", "d534337c-54ff-4534-a62e-fc555bd9c571", "ccb82eee-2caa-445d-9cd1-ca3820edb6b5", "0a46c96b-11fa-4627-8a89-786a4577a441" },
  ["soldier_generic_4_09"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "a6f4fcf5-9d0a-45c4-8641-b9689415983b", "a8a8db9c-955c-410f-9d47-1af70d917900", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "81e27f41-709f-47c8-96b3-8f8c9619d2fa", "8472dd03-91d6-4496-a92e-e6e9baaa46ba" },
  ["soldier_generic_4_10"] = { "b6b5f07a-d94d-4a1b-a9af-bad64277ab13", "078e439b-1a5b-40ca-b009-d4abf6fcf810", "d20252f7-51f0-4f8e-857c-b086fcec15be", "a8a8db9c-955c-410f-9d47-1af70d917900", "3437c616-a14c-4ba2-a382-f4898765eeff", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "978586ca-3269-493b-a1fd-88ae04a6ded6", "63eff267-424a-43fd-a5ec-132c89c286f0", "6021520e-b6a9-4daf-adce-21a8a208646c" },
  ["soldier_generic_4_11"] = { "a6f4fcf5-9d0a-45c4-8641-b9689415983b", "a157447c-3c6f-463a-a02d-d4b696e644e1", "e72e27a2-87db-480d-977b-318c34e0444f", "a8a8db9c-955c-410f-9d47-1af70d917900", "38102e92-9a28-4d57-85c4-716b97a0ecb8", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "7c8cdd6c-b094-4b70-b588-286b50cffe02", "b90f82a2-f590-4564-af7b-f5f5bd44bc1c", "737fcf80-5ce8-45d2-9ffe-10b952d125a0" },
  ["soldier_generic_4_12"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "a8a8db9c-955c-410f-9d47-1af70d917900", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "713a4f57-647f-4ab6-8c6e-ad189f6f5eee", "8472dd03-91d6-4496-a92e-e6e9baaa46ba", "86055ea8-0e06-47f2-a976-e5453bdf84d1", "3f72f25b-8763-4434-bec7-a2640057ad1e" },
  ["soldier_generic_4_13"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "d40cc1ba-5ea4-44d7-86fb-ccb1680b611d", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "627e8530-e405-487b-9bef-7f85d2459360", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "7e55a88a-1a07-443e-846b-b24217c732f9", "916a6a5e-a1c1-4db7-b573-909c139a1b52", "93d145b7-251f-49e2-b44d-8c3e455621a4", "3b912b8e-3669-43e6-a53f-8136b7ae3e99" },
  ["soldier_generic_4_14"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "fe365538-9abe-41ca-90e8-97e191662490", "a8a8db9c-955c-410f-9d47-1af70d917900", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "3f5dc1aa-ae52-4760-a466-0ebac0d483ed", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "91f76dc9-7d86-4fd3-b4f0-e518ca6c342e", "9c6aac7c-4797-4aa9-a297-939fd5e5a54e", "315fa220-fcb8-44e3-9a68-545c6822ec9f" },
  ["soldier_generic_4_15"] = { "be916959-2459-4a31-81fc-4b00090c3f42", "40700938-bd53-480d-80c3-2820ed3b5380", "d20252f7-51f0-4f8e-857c-b086fcec15be", "7ae64aa3-444f-4f10-b05d-4a943c965551", "2a4b891d-9131-4a45-8b93-4734da890724", "916a6a5e-a1c1-4db7-b573-909c139a1b52", "25bd008c-f308-4521-8a4f-a1feeb76ea3c", "3b912b8e-3669-43e6-a53f-8136b7ae3e99", "b40942a9-f067-4a6d-8cd3-59a03e8a59d1" },
  ["soldier_generic_5_01"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "0aba49a1-bffe-460b-bcc0-781654d79ac1", "9da82290-e31b-4ba6-b0e8-680081e06e9a", "808101ad-28ff-4425-ad2a-5fbe4f9fbbbe", "3a1811fb-124e-4dbd-95ee-114debe21091", "260ccafb-0504-4c17-9833-304539d30698", "f9be9c8b-de15-4216-bf0d-7e71d25c0b84", "9c6aac7c-4797-4aa9-a297-939fd5e5a54e", "63eff267-424a-43fd-a5ec-132c89c286f0", "403db8bc-649a-4b10-9385-01275b96f141", "43f25763-bdbd-4e22-a946-722e2fd156c4" },
  ["soldier_generic_5_02"] = { "a6f4fcf5-9d0a-45c4-8641-b9689415983b", "c6a66736-2f9e-4c0c-9def-4d6fd5906b82", "d20252f7-51f0-4f8e-857c-b086fcec15be", "260ccafb-0504-4c17-9833-304539d30698", "a8a8db9c-955c-410f-9d47-1af70d917900", "2a4b891d-9131-4a45-8b93-4734da890724", "916a6a5e-a1c1-4db7-b573-909c139a1b52", "bfee5c98-846b-4535-9827-98a3300d4302", "8b2cb8f5-31e8-4ee3-b4bc-b50c06f7ff4c", "663d6ec1-c5b9-406e-9017-04f1688331ea", "cc0c46b1-830f-46cb-aeb9-38d18ff06ab4" },
  ["soldier_generic_5_03"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "c684625e-5f43-4e05-8cca-bb8cfadef4b7", "260ccafb-0504-4c17-9833-304539d30698", "ee8a0292-d4be-4066-a4b1-edb18f1e7b44", "cd17455c-b023-4977-8205-4f2685370b5e", "f19e049a-1209-4f18-b02d-615e5efb2c48", "d1926fdf-d10e-4ab5-9531-2deeff6f8d07", "aea861d5-30ef-483d-a326-6a29a98ea726", "9c6aac7c-4797-4aa9-a297-939fd5e5a54e", "c01ca195-4129-4fbd-a966-f8eb7b162ddf" },
  ["soldier_generic_5_04"] = { "fe365538-9abe-41ca-90e8-97e191662490", "91e17195-0d9f-4373-ab2a-aed59193ac2d", "6fad4fc0-eb11-4394-943f-d8def9871cc2", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "86055ea8-0e06-47f2-a976-e5453bdf84d1", "6c7ea4d3-011f-4052-a23e-3349cc54d56c", "3b912b8e-3669-43e6-a53f-8136b7ae3e99", "85bf9cdb-d3ad-4ff3-b77e-a01319ed87d3", "49ac17ff-a290-4fb4-8ca6-0e3bed1ddbd7" },
  ["soldier_generic_5_05"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "9da82290-e31b-4ba6-b0e8-680081e06e9a", "0658b976-5789-4349-ad70-10042b84e870", "3a1811fb-124e-4dbd-95ee-114debe21091", "260ccafb-0504-4c17-9833-304539d30698", "808101ad-28ff-4425-ad2a-5fbe4f9fbbbe", "a0ff8ee9-9c48-4906-b25d-1ee2865f8c4e", "9e19280b-f3a2-445b-9283-8bd2b6b611ad", "3b912b8e-3669-43e6-a53f-8136b7ae3e99", "978586ca-3269-493b-a1fd-88ae04a6ded6", "38c34f78-cfa0-40c9-a94e-5e04dcf35608", "a856e87a-8065-4338-919d-0aff7a63341d" },
  ["soldier_generic_5_06"] = { "ba6a0b5e-4674-4fac-9f2f-bd6076a6069c", "0f70adb9-d36a-4f72-8367-a64454159a4f", "260ccafb-0504-4c17-9833-304539d30698", "cd17455c-b023-4977-8205-4f2685370b5e", "88f1ceff-5a1e-40b5-92f7-68e941268f3b", "38c34f78-cfa0-40c9-a94e-5e04dcf35608", "177e55fc-31bc-40dc-b399-899b478093d0", "737fcf80-5ce8-45d2-9ffe-10b952d125a0", "b29874c7-734e-448a-9227-b0b261c900d2", "263e6aa0-cffd-4c30-87ea-98e3fcaa4dc7", "fbc58e41-81e9-4447-8a86-e9d236b9dad5" },
  ["soldier_generic_5_07"] = { "a6f4fcf5-9d0a-45c4-8641-b9689415983b", "c6a66736-2f9e-4c0c-9def-4d6fd5906b82", "d20252f7-51f0-4f8e-857c-b086fcec15be", "260ccafb-0504-4c17-9833-304539d30698", "a8a8db9c-955c-410f-9d47-1af70d917900", "2a4b891d-9131-4a45-8b93-4734da890724", "bf69906e-4f4b-40dd-803c-9deee8c0bd15", "916a6a5e-a1c1-4db7-b573-909c139a1b52", "bfee5c98-846b-4535-9827-98a3300d4302", "737fcf80-5ce8-45d2-9ffe-10b952d125a0" },
  ["soldier_generic_5_08"] = { "ba6a0b5e-4674-4fac-9f2f-bd6076a6069c", "0f70adb9-d36a-4f72-8367-a64454159a4f", "260ccafb-0504-4c17-9833-304539d30698", "cd17455c-b023-4977-8205-4f2685370b5e", "88f1ceff-5a1e-40b5-92f7-68e941268f3b", "407d0b00-9517-45c5-9d87-63895ed72dd0", "7c8cdd6c-b094-4b70-b588-286b50cffe02", "263e6aa0-cffd-4c30-87ea-98e3fcaa4dc7", "38c34f78-cfa0-40c9-a94e-5e04dcf35608", "b0b3babe-9c0a-4cb4-9f50-f4447a835ffa" },
  ["soldier_generic_5_09"] = { "91e17195-0d9f-4373-ab2a-aed59193ac2d", "6fad4fc0-eb11-4394-943f-d8def9871cc2", "fe365538-9abe-41ca-90e8-97e191662490", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "5f0a8ce2-8ebd-4a1a-ade0-997c2621b7f3", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "63eff267-424a-43fd-a5ec-132c89c286f0", "86055ea8-0e06-47f2-a976-e5453bdf84d1", "7dc23682-02cd-43d9-bcc8-e805489ae1a0" },
  ["soldier_generic_5_10"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "9da82290-e31b-4ba6-b0e8-680081e06e9a", "0658b976-5789-4349-ad70-10042b84e870", "3a1811fb-124e-4dbd-95ee-114debe21091", "260ccafb-0504-4c17-9833-304539d30698", "808101ad-28ff-4425-ad2a-5fbe4f9fbbbe", "63eff267-424a-43fd-a5ec-132c89c286f0", "a0ff8ee9-9c48-4906-b25d-1ee2865f8c4e", "7c8cdd6c-b094-4b70-b588-286b50cffe02", "3b912b8e-3669-43e6-a53f-8136b7ae3e99", "9e19280b-f3a2-445b-9283-8bd2b6b611ad" },
  ["soldier_generic_5_11"] = { "91e17195-0d9f-4373-ab2a-aed59193ac2d", "6fad4fc0-eb11-4394-943f-d8def9871cc2", "fe365538-9abe-41ca-90e8-97e191662490", "765d83b6-e6c8-4caf-8fb4-cdae43c41985", "260ccafb-0504-4c17-9833-304539d30698", "d20252f7-51f0-4f8e-857c-b086fcec15be", "3625fd0b-94df-47ca-a0db-09f5f8833ac0", "7d602455-05bc-49b9-a11f-67c76992016c", "9c6aac7c-4797-4aa9-a297-939fd5e5a54e", "d1926fdf-d10e-4ab5-9531-2deeff6f8d07", "aea861d5-30ef-483d-a326-6a29a98ea726", "97318a25-2aa3-458b-b4f0-7f265fba32a0" },
  ["soldier_generic_5_12"] = { "ba6a0b5e-4674-4fac-9f2f-bd6076a6069c", "0f70adb9-d36a-4f72-8367-a64454159a4f", "260ccafb-0504-4c17-9833-304539d30698", "cd17455c-b023-4977-8205-4f2685370b5e", "88f1ceff-5a1e-40b5-92f7-68e941268f3b", "38c34f78-cfa0-40c9-a94e-5e04dcf35608", "f7bcdadb-de2f-4576-b84f-474c2a56804f", "85bf9cdb-d3ad-4ff3-b77e-a01319ed87d3", "177e55fc-31bc-40dc-b399-899b478093d0", "8b2cb8f5-31e8-4ee3-b4bc-b50c06f7ff4c", "315fa220-fcb8-44e3-9a68-545c6822ec9f" },
  ["soldier_generic_6_01"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "7963c946-f52a-4373-94f4-b30fabd15f8f", "86cf52c6-4329-4e07-b316-facdb667a386", "5d5b2f4d-5f18-4ebe-ae2e-6eccbd8f92ea", "b1b9a304-4f2c-4e43-8f2c-166abf25243c", "135a64e5-8958-42f4-bbe8-16e6744fc20b", "344b633a-b7a0-44ef-8a11-9d1288f9a0ca", "156a20c9-d2ff-48e3-a9cb-e3e106139042", "8472dd03-91d6-4496-a92e-e6e9baaa46ba", "916a6a5e-a1c1-4db7-b573-909c139a1b52", "9bd6afca-f2cd-45b2-b057-2586811817f8" },
  ["soldier_generic_6_02"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "2f20e7ab-77ae-4c17-be1d-e6f4931769d5", "d20252f7-51f0-4f8e-857c-b086fcec15be", "0fda3070-6b14-4fa9-bfd1-26da6924d32e", "260ccafb-0504-4c17-9833-304539d30698", "3d03fd46-32cb-4a9c-a7a1-f159a5f926d0", "5f0a8ce2-8ebd-4a1a-ade0-997c2621b7f3", "3f31f6fd-e150-4564-80a5-2a9d1ed7dd6b", "a6fdf67f-f133-429d-a06b-ef4380ba5c35", "737fcf80-5ce8-45d2-9ffe-10b952d125a0", "6aabc182-4cc0-4095-a134-a2b23eafc5c6" },
  ["soldier_generic_6_03"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "6f275925-deff-47ba-8bd6-68ac4ce1c6ed", "d20252f7-51f0-4f8e-857c-b086fcec15be", "260ccafb-0504-4c17-9833-304539d30698", "d444ea2d-1233-4040-b3bc-269e8426d40e", "168579ba-c191-41ba-80e4-ed711a328ec9", "177e55fc-31bc-40dc-b399-899b478093d0", "2463ac9b-f30b-4cac-bfbc-d846b54c328e", "663d6ec1-c5b9-406e-9017-04f1688331ea", "b9fa2db6-ee6e-4976-9449-24ae92916789", "45b6d780-23e1-4a89-a0b1-dbc234a7ce21" },
  ["soldier_generic_6_04"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "c684625e-5f43-4e05-8cca-bb8cfadef4b7", "d20252f7-51f0-4f8e-857c-b086fcec15be", "ad878f77-e53d-4dec-948b-2627fea5df1d", "b1b9a304-4f2c-4e43-8f2c-166abf25243c", "25bd008c-f308-4521-8a4f-a1feeb76ea3c", "916a6a5e-a1c1-4db7-b573-909c139a1b52", "d89df714-7b5e-41a0-a3f6-d9538a97e630", "403db8bc-649a-4b10-9385-01275b96f141", "34f2f8b6-2ed4-4b89-ba68-ac4d6a8a7fab", "cc0c46b1-830f-46cb-aeb9-38d18ff06ab4" },
  ["soldier_generic_6_05"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "3cea4901-cce2-4582-b4a0-c208df45cd53", "d20252f7-51f0-4f8e-857c-b086fcec15be", "0fda3070-6b14-4fa9-bfd1-26da6924d32e", "260ccafb-0504-4c17-9833-304539d30698", "b90f82a2-f590-4564-af7b-f5f5bd44bc1c", "3d03fd46-32cb-4a9c-a7a1-f159a5f926d0", "219debf1-3e0a-4bad-b6bb-6bad5e334b8c", "53a0ba78-7f73-4f19-8932-a8bae86f7814" },
  ["soldier_generic_6_06"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "7963c946-f52a-4373-94f4-b30fabd15f8f", "cfc1fd72-dbb7-49a4-8713-6acf215a72be", "b1b9a304-4f2c-4e43-8f2c-166abf25243c", "5d5b2f4d-5f18-4ebe-ae2e-6eccbd8f92ea", "156a20c9-d2ff-48e3-a9cb-e3e106139042", "135a64e5-8958-42f4-bbe8-16e6744fc20b", "344b633a-b7a0-44ef-8a11-9d1288f9a0ca", "403db8bc-649a-4b10-9385-01275b96f141", "63eff267-424a-43fd-a5ec-132c89c286f0" },
  ["soldier_generic_6_07"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "b26e6866-c903-4238-9f64-24eca84fc34a", "d20252f7-51f0-4f8e-857c-b086fcec15be", "0fda3070-6b14-4fa9-bfd1-26da6924d32e", "260ccafb-0504-4c17-9833-304539d30698", "3d03fd46-32cb-4a9c-a7a1-f159a5f926d0", "2463ac9b-f30b-4cac-bfbc-d846b54c328e", "5f0a8ce2-8ebd-4a1a-ade0-997c2621b7f3", "3f31f6fd-e150-4564-80a5-2a9d1ed7dd6b", "a6fdf67f-f133-429d-a06b-ef4380ba5c35" },
  ["soldier_generic_6_08"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "6f275925-deff-47ba-8bd6-68ac4ce1c6ed", "d20252f7-51f0-4f8e-857c-b086fcec15be", "260ccafb-0504-4c17-9833-304539d30698", "d444ea2d-1233-4040-b3bc-269e8426d40e", "168579ba-c191-41ba-80e4-ed711a328ec9", "177e55fc-31bc-40dc-b399-899b478093d0", "2463ac9b-f30b-4cac-bfbc-d846b54c328e", "663d6ec1-c5b9-406e-9017-04f1688331ea", "b9fa2db6-ee6e-4976-9449-24ae92916789" },
  ["soldier_generic_6_09"] = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "100b9146-1c41-4136-9991-ff80983f1955", "d20252f7-51f0-4f8e-857c-b086fcec15be", "6f6bc011-d298-4f69-8877-71f94abe6d9e", "ad878f77-e53d-4dec-948b-2627fea5df1d", "38c34f78-cfa0-40c9-a94e-5e04dcf35608", "459ae318-ac5d-4de1-b34e-f6ce5ef6492c", "25bd008c-f308-4521-8a4f-a1feeb76ea3c", "a6fdf67f-f133-429d-a06b-ef4380ba5c35" },
  ["sword_shield_3_01"] = { "efa237c7-3905-4813-b9c3-a32b449c17ad", "401266f6-ffb4-4ad0-a8e1-4a3cb3edab3e" },
  ["sword_shield_4_01"] = { "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", "760d7474-6e5f-4987-9631-d007d5fff22e" },
  ["sword_shield_5_01"] = { "e37bdf86-4cc8-4805-b04c-3b05964b9484", "25d5e06c-09e2-405a-b0e8-4ffb6d44c975" },
}
liaison.munitions_des_prereglages = {
  ["scriptorium_arbaletrier_1_a"] = "bcdd6887-8c80-4bae-8aa6-567574a75867",
  ["scriptorium_arbaletrier_1_b"] = "bcdd6887-8c80-4bae-8aa6-567574a75867",
  ["scriptorium_arbaletrier_2_a"] = "8460003f-637f-4713-92c9-4954037c4b9c",
  ["scriptorium_arbaletrier_2_b"] = "8460003f-637f-4713-92c9-4954037c4b9c",
  ["scriptorium_arbaletrier_3_a"] = "081fc4a1-25e9-4492-8dc8-2d9d6668c07a",
  ["scriptorium_arbaletrier_3_b"] = "081fc4a1-25e9-4492-8dc8-2d9d6668c07a",
  ["scriptorium_archer_1"] = "dfea5d01-b25c-414a-9ab4-6911a5f82118",
  ["scriptorium_archer_2"] = "ad6f0f01-aec4-44d1-982c-1210eb01b74a",
  ["scriptorium_archer_3"] = "710e3706-8974-404b-b23a-6f51670ef1ed",
}
-- FIN DES PIÈCES

-- L'équipement pièce par pièce (fiche 13, V71 b ; mesuré en V71 a3 à a6). inventory:CreateItem(objet, état, nombre) :
-- la pièce est gardée au rechargement avec son usure ; actor:EquipInventoryItem la fait porter ; inventory:DeleteItem(id,
-- 1) la retire (Scripts/Entities/WH/Triggers/TriggerBase.lua). L'identifiant d'un objet change à chaque chargement :
-- un objet se désigne ici par sa classe.
liaison.objet_de_la_bourse = "5ef63059-322e-4e1b-abe8-926e100c770e"   -- pièces de monnaie : jamais retirées

function liaison.noms_des_prereglages()
  local noms = {}
  for nom in pairs(liaison.pieces_des_prereglages or {}) do
    table.insert(noms, nom)
  end
  table.sort(noms)
  return noms
end

function liaison.pieces_de(nom)
  local liste = nom and (liaison.pieces_des_prereglages or {})[nom]
  if not liste then
    return nil
  end
  local copie = {}
  for i, objet in ipairs(liste) do
    copie[i] = objet
  end
  return copie
end

function liaison.munition_de(nom)
  return nom and (liaison.munitions_des_prereglages or {})[nom] or nil
end

local function porteur(personnage)
  local entite = entite_nommee(personnage)
  if entite and entite.inventory and entite.actor then
    return entite
  end
  return nil
end

function liaison.compter_objet(personnage, objet)
  local entite = porteur(personnage)
  if not entite then
    return 0
  end
  local ok, n = pcall(function() return entite.inventory:GetCountOfClass(objet) end)
  return ok and tonumber(n) or 0
end

function liaison.creer_objet(personnage, objet, etat, nombre)
  local entite = porteur(personnage)
  if not entite then
    return false
  end
  local ok, erreur = pcall(function() entite.inventory:CreateItem(objet, etat, nombre) end)
  if not ok then
    liaison.journal("Objet " .. tostring(objet) .. " refusé : " .. tostring(erreur))
  end
  return ok
end

local function trouver(entite, personnage, objet)
  if liaison.compter_objet(personnage, objet) == 0 then
    return nil
  end
  local trouve, id = pcall(function() return entite.inventory:FindItem(objet) end)
  return trouve and id or nil
end

-- Fait porter chaque objet, dans l'ordre (une pièce de cette classe trouvée dans le sac). Rien n'est ôté d'abord : V71 c,
-- refaire porter une pièce déjà portée ne l'ôte pas ; V71 d, ôter d'abord faisait perdre la cotte de dessus. Rend le
-- nombre de pièces portées et la liste des objets introuvables ou refusés.
function liaison.faire_porter(personnage, objets)
  local entite = porteur(personnage)
  local introuvables = {}
  if not entite then
    return 0, objets
  end
  local portes = 0
  for _, objet in ipairs(objets) do
    local id = trouver(entite, personnage, objet)
    if id and pcall(function() entite.actor:EquipInventoryItem(id) end) then
      portes = portes + 1
    else
      table.insert(introuvables, objet)
    end
  end
  return portes, introuvables
end

-- Le personnage sort son arme (forme de Player:CheatGiveSword, Scripts/Entities/actor/player.lua) : une arme d'hast
-- rangée ne se voit pas (règle de JoVenGer dans Scriptorium). Pour le poste d'essai.
function liaison.degainer(personnage)
  local entite = porteur(personnage)
  if not entite then
    return "introuvable"
  end
  local ok, erreur = pcall(function() entite.human:DrawWeapon() end)
  return ok and "arme sortie" or ("refusé : " .. tostring(erreur))
end

-- L'état d'une pièce de cet objet dans son sac (V71 a3 : ItemManager.GetItem(id).health), ou nil.
function liaison.etat_objet(personnage, objet)
  local entite = porteur(personnage)
  local id = entite and trouver(entite, personnage, objet)
  if not id then
    return nil
  end
  local lu, piece = pcall(function() return ItemManager.GetItem(id) end)
  return (lu and type(piece) == "table") and tonumber(piece.health) or nil
end

-- Retire de son sac une pièce de cet objet. Rend vrai si le compte a baissé.
function liaison.retirer_un_objet(personnage, objet)
  local entite = porteur(personnage)
  local avant = liaison.compter_objet(personnage, objet)
  if not entite or avant == 0 then
    return false
  end
  pcall(function() entite.inventory:DeleteItem(entite.inventory:FindItem(objet), 1) end)
  return liaison.compter_objet(personnage, objet) < avant
end

-- Équipe un homme : sa tenue de naissance retirée d'abord (tout son sac, sauf la bourse), puis chaque pièce créée,
-- ses munitions, puis ce qu'il porte, dans l'ordre. Rend une ligne pour le journal.
function liaison.equiper_homme(personnage, ordre)
  local entite = porteur(personnage)
  if not entite then
    return "personnage introuvable"
  end
  local retires = 0
  if ordre.retirer_naissance then
    local ok, liste = pcall(function() return entite.inventory:GetInventoryTable() end)
    for _, id in pairs((ok and type(liste) == "table") and liste or {}) do
      local lu, objet = pcall(function() return ItemManager.GetItem(id) end)
      local classe = (lu and type(objet) == "table") and string.lower(tostring(objet.class)) or nil
      -- Une pile (carreaux, flèches) se retire entière : DeleteItem(id, 1) n'en ôtait qu'un (V71 b).
      local nombre = (lu and type(objet) == "table") and tonumber(objet.amount) or 1
      if classe and classe ~= liaison.objet_de_la_bourse
         and pcall(function() entite.inventory:DeleteItem(id, math.max(nombre or 1, 1)) end) then
        retires = retires + 1
      end
    end
  end
  local crees = 0
  for _, objet in ipairs(ordre.creer or {}) do
    if liaison.creer_objet(personnage, objet, ordre.etat or 1, 1) then
      crees = crees + 1
    end
  end
  if ordre.munition then
    liaison.creer_objet(personnage, ordre.munition.objet, 1, ordre.munition.nombre)
  end
  for _, piece in ipairs(ordre.recreer or {}) do
    if liaison.creer_objet(personnage, piece.objet, piece.etat, 1) then
      crees = crees + 1
    end
  end
  local portes, introuvables = liaison.faire_porter(personnage, ordre.porter or {})
  return string.format("%d pièce(s) de naissance retirée(s), %d créée(s), %d portée(s), %d introuvable(s)", retires, crees,
    portes, #introuvables)
end

-- Fait venir un personnage de la Compagnie sur son âme et rend son identifiant, ou nil.
-- La propriété d'âme d'un personnage s'appelle guidSharedSoulId (relevé Lua du jeu, table NPC.Properties).
-- Éveillé aussitôt né : sans réveil, le cerveau d'un personnage né par script ne fait qu'un tour (V29). Au
-- rechargement, il n'en a pas besoin : son cerveau tourne encore (V56).
function liaison.faire_venir_homme(ame, nom, position)
  if ame == nil or position == nil then
    liaison.journal("Venue impossible pour « " .. nom .. " » : " .. (ame == nil and "pas d'âme" or "pas de position"))
    return nil
  end
  local identifiant, raison = faire_naitre("NPC", "scriptorium_" .. nom, position, 0, { guidSharedSoulId = ame })
  if not identifiant then
    liaison.journal("Venue impossible pour « " .. nom .. " » : " .. tostring(raison))
    return nil
  end
  liaison.eveiller(identifiant, nom)
  return identifiant
end

-- Vrai si le personnage existe encore.
function liaison.personnage_existe(identifiant)
  return liaison.objet_existe(identifiant)
end

-- Renvoie un personnage (départ de la Compagnie).
function liaison.renvoyer_homme(identifiant)
  liaison.retirer_objet(identifiant)
end

-- Fiche 15, V73 f 2 a (la sonde à cheval) : un cheval de la classe du jeu (Scripts/Entities/AI/Horse.lua), sur une âme
-- de cheval du jeu (relecture du pair : sans âme de cheval, la monte risque d'échouer), hors de la sauvegarde
-- (bSaved_by_game à faux, un cheval de passage), sans maison à rejoindre, au sol, sur une place libre, éveillé. Rend son
-- identifiant, ou nil.
liaison.ame_de_cheval = "1b356948-3d22-427c-86f9-f33ab2b441c6"   -- Horse2 (Libs/Tables/rpg/soul.xml, archétype 3, classe 7)

function liaison.faire_venir_cheval(nom, position)
  local identifiant, raison = faire_naitre("Horse", "scriptorium_cheval_" .. nom, liaison.au_sol(position), 0,
    { guidSharedSoulId = liaison.ame_de_cheval, bSaved_by_game = false, bWH_RequiresHome = false })
  if not identifiant then
    liaison.journal("Cheval « " .. nom .. " » : venue impossible : " .. tostring(raison))
    return nil
  end
  liaison.eveiller(identifiant, "Cheval « " .. nom .. " »")
  return identifiant
end

function liaison.retirer_cheval(identifiant)
  liaison.retirer_objet(identifiant)
end

-- Fiche 15, V73 f 2 c (relecture du pair) : le sol d'une place, pour un cheval. « pente » : la plus forte pente du
-- terrain autour (hauteurs du terrain à « pas » m de part et d'autre, en mètres par mètre) ; « encombre » : vrai si un
-- rayon descendu de 3 m au-dessus du terrain (Physics.RayWorldIntersection, la forme de
-- Scripts/Entities/Physics/PressurizedObject.lua) touche quelque chose à plus de 0,3 m au-dessus : un objet, un
-- personnage, et l'eau quand le jeu donne « ent_water » (« eau_lisible ») ; nil quand le rayon est illisible. Rend
-- { pente, encombre, eau_lisible }, ou nil si le terrain est illisible.
function liaison.sol_de(position, pas)
  local function hauteur(x, y)
    local lu, z = pcall(System.GetTerrainElevation, { x = x, y = y, z = position.z or 0 })
    return lu and tonumber(z) or nil
  end
  local z0 = hauteur(position.x, position.y)
  if not z0 then
    return nil
  end
  local pente = 0
  for _, d in ipairs({ { pas, 0 }, { -pas, 0 }, { 0, pas }, { 0, -pas } }) do
    local z = hauteur(position.x + d[1], position.y + d[2])
    if z then
      pente = math.max(pente, math.abs(z - z0) / pas)
    end
  end
  local eau_lisible = type(ent_water) == "number"
  local encombre = nil
  if type(ent_all) == "number" then
    local masque = ent_all + (eau_lisible and ent_water or 0)
    local touches = {}
    local lu, n = pcall(function()
      return Physics.RayWorldIntersection({ x = position.x, y = position.y, z = z0 + 3 }, { x = 0, y = 0, z = -4 }, 1,
        masque, nil, nil, touches)
    end)
    if lu and tonumber(n) then
      local premier = touches[1]
      local z = premier and type(premier.pos) == "table" and tonumber(premier.pos.z) or nil
      encombre = (tonumber(n) > 0 and z ~= nil and z > z0 + 0.3) or false
    end
  end
  -- Une fois par partie : ce que le jeu a laissé lire (à vérifier en jeu, fiche 15, V73 f 2 c).
  if not liaison.sol_dit then
    liaison.sol_dit = true
    liaison.journal("Sol : rayon " .. (encombre == nil and "illisible" or "lisible") .. ", eau "
                    .. (eau_lisible and "lisible (ent_water)" or "illisible (pas de ent_water)"))
  end
  return { pente = pente, encombre = encombre, eau_lisible = eau_lisible }
end
Scriptorium.remplacable(liaison, "sol_de")

-- Fiche 15, V73 f 2 d : le cheval d'Henry (player.player:GetPlayerHorse rend son WUID, __null s'il n'en a pas ;
-- XGenAIModule.GetEntityByWUID, la forme de Scripts/Utils/GameUtils.lua). Rend l'entité, ou (nil, raison).
local function cheval_d_henry()
  local lu, wuid = pcall(function() return player.player:GetPlayerHorse() end)
  if not lu then
    return nil, "illisible : " .. tostring(wuid)
  end
  if wuid == nil or wuid == rawget(_G, "__null") then
    return nil, "Henry n'a pas de cheval"
  end
  local trouve, cheval = pcall(XGenAIModule.GetEntityByWUID, wuid)
  if not trouve or not cheval then
    return nil, "introuvable"
  end
  return cheval
end

-- Henry à cheval : un cheval monté (horse:HasRider, Scripts/Entities/AI/Horse.lua) se tient à moins de « pres » m de
-- lui (System.GetEntitiesInSphereByClass, classe Horse) : n'importe quel cheval, le sien, un emprunté ou un volé ; nos
-- chevaux (nom commençant par « scriptorium_cheval_ ») ne comptent pas. Rend vrai, faux, ou nil si rien n'est lisible.
function liaison.henry_a_cheval(pres)
  local ici_lu, ici = pcall(function() return player:GetWorldPos() end)
  if not ici_lu or type(ici) ~= "table" then
    return nil
  end
  local lu, chevaux = pcall(System.GetEntitiesInSphereByClass, ici, pres, "Horse")
  if not lu then
    return nil
  end
  local vus, lisibles = 0, 0
  for _, cheval in pairs(type(chevaux) == "table" and chevaux or {}) do
    local nom_lu, nom = pcall(function() return cheval:GetName() end)
    if not (nom_lu and type(nom) == "string" and string.sub(nom, 1, 19) == "scriptorium_cheval_") then
      vus = vus + 1
      local monte_lu, monte = pcall(function() return cheval.horse:HasRider() end)
      if monte_lu then
        lisibles = lisibles + 1
        if monte then
          return true
        end
      end
    end
  end
  if vus > 0 and lisibles == 0 then
    return nil
  end
  return false
end

-- V73 f 3 b (relecture du pair) : un de nos chevaux porte-t-il encore son cavalier (horse:HasRider, la lecture d'Henry
-- à cheval) ? Rend vrai, faux, ou nil si rien n'est lisible.
function liaison.cheval_monte(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite then
    return nil
  end
  local lu, monte = pcall(function() return entite.horse:HasRider() end)
  if not lu then
    return nil
  end
  return monte and true or false
end

-- V73 g (le gardien des hommes) : l'altitude du terrain sous (x, y), ou nil.
function liaison.altitude_du_terrain(x, y)
  local lu, z = pcall(System.GetTerrainElevation, { x = x, y = y, z = 0 })
  return lu and tonumber(z) or nil
end

-- V73 g : l'immortalité du jeu le temps d'un repêchage : l'effet « immortality_nonpersistent » (imm=1,
-- Libs/Tables/rpg/buff.xml), posé par soul:AddBuff (la forme de Scripts/Entities/actor/player.lua), retiré par son
-- identifiant seulement (soul:RemoveBuff) : une immortalité donnée par une autre règle reste.
liaison.effet_immortel = "730503bf-735a-4f47-baae-c2d84ee77524"

-- Rend l'identifiant de l'effet posé, ou nil et la raison.
function liaison.rendre_immortel(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite then
    return nil, "introuvable"
  end
  local lu, effet = pcall(function() return entite.soul:AddBuff(liaison.effet_immortel) end)
  if not lu then
    return nil, tostring(effet)
  end
  if effet == nil then
    return nil, "effet refusé"
  end
  return effet
end

function liaison.retirer_l_effet(identifiant, effet)
  local entite = entite_nommee(identifiant)
  if not entite or effet == nil then
    return false
  end
  return (pcall(function() entite.soul:RemoveBuff(effet) end))
end

-- Pour le poste d'essai (V73 g) : un homme posé « profondeur » m sous le terrain ; ou endormi (Activate(0) et l'IA en
-- sommeil), le contraire du réveil. Rendent (vrai, compte rendu) ou (faux, raison).
function liaison.poser_sous_le_sol(identifiant, profondeur)
  local entite = entite_nommee(identifiant)
  if not entite then
    return false, "introuvable"
  end
  local ok, resultat = pcall(function()
    local ici = entite:GetWorldPos()
    local sol = System.GetTerrainElevation(ici)
    entite:SetWorldPos({ x = ici.x, y = ici.y, z = sol - profondeur })
    local apres = entite:GetWorldPos()
    return string.format("posé à %.1f (terrain %.1f)", apres.z, sol)
  end)
  return ok, tostring(resultat)
end

function liaison.endormir(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite then
    return false, "introuvable"
  end
  local endormi = pcall(function() entite:Activate(0) end)
  local sommeil = pcall(function() AI.AutoDisable(entite.id, 1) end)
  return endormi and sommeil, "Activate(0) = " .. tostring(endormi) .. ", AutoDisable(1) = " .. tostring(sommeil)
end

-- Séance d'essai (V73 f 2 d) : le cheval d'Henry amené à « distance » m devant lui, au sol, sur une place que rien
-- n'encombre (sol_de). Rend (vrai, ligne) ou (faux, raison).
function liaison.amener_le_cheval_d_henry(distance)
  local cheval, raison = cheval_d_henry()
  if not cheval then
    return false, "cheval d'Henry : " .. tostring(raison)
  end
  local henry, cap = liaison.position_du_joueur(), liaison.cap_du_joueur()
  local ou = liaison.au_sol({ x = henry.x + distance * math.sin(math.rad(cap)),
                              y = henry.y + distance * math.cos(math.rad(cap)), z = henry.z })
  local sol = Scriptorium.avis(liaison, "sol_de", ou, 1.5)
  if sol and sol.encombre then
    return false, "place encombrée devant Henry"
  end
  local pose, erreur = pcall(function() cheval:SetWorldPos(ou) end)
  local nom_lu, nom = pcall(function() return cheval:GetName() end)
  return pose, string.format("« %s » posé à %g m devant Henry : %s", nom_lu and tostring(nom) or "?", distance,
                             pose and "oui" or tostring(erreur))
end

-- Fiche 15, V73 f 2 b : le compte des montes manquées que tient le cerveau de l'homme (l'arbre l'augmente quand le délai
-- de la monte passe sans qu'il soit en selle) ; nil s'il est illisible.
function liaison.montes_manquees(identifiant)
  local entite = entite_nommee(identifiant)
  local this_lu, this = pcall(function() return entite.this end)
  if not entite or not this_lu or type(this) ~= "table" then
    return nil
  end
  local lu, valeur = pcall(function() return XGenAIModule.GetBrainVariable(this.id, "scriptorium_monte_manquee") end)
  return lu and tonumber(valeur) or nil
end

-- Donne un ordre simple à un personnage : dormir ici, s'asseoir là, se tenir là.
-- À vérifier en jeu : l'appel du moteur. En attendant, l'ordre est noté au journal.
-- Vu le 14/10 (V17) : le jeu de base n'a pas d'ordre générique « marcher, s'asseoir, dormir » ; ses personnages
-- obéissent à des cerveaux propres à chaque quête. Ces ordres attendent un cerveau à nous (tables du jeu).
-- En attendant, « se tenir là » : le personnage est posé au lieu s'il en est à plus de deux mètres.

-- Âmes des ennemis par sorte de bande, prises dans le jeu de base.
-- Premier essai (V18, 14/10) : une seule âme, un brigand générique d'une quête de Trosecko
-- (bohutovaVlozka_bandit_3, faction trosecko_enemies_bandits_bohutovaVlozka, table soul__bohutovaVlozka.xml).
-- Étape 2 (le nécessaire, fiche 14) : nos quatre âmes de bande (soul__scriptorium_socle.xml), faction
-- scriptorium_socle_bande, copiées sur des âmes réelles du jeu (cerveau d'ennemi, personnage, voix, niveau de combat).
liaison.ames_ennemies = {
  brigands = "5c7a5c7a-0005-4001-8000-000000000001",
  deserteurs = "5c7a5c7a-0005-4001-8000-000000000002",
  soudards = "5c7a5c7a-0005-4001-8000-000000000003",
  coumans = "5c7a5c7a-0005-4001-8000-000000000004",
}
-- Un numéro pour chaque ennemi né (deux bandes de la même sorte n'ont jamais le même nom) ; gardé à la relecture.
liaison.ennemis_nes = liaison.ennemis_nes or 0

-- Fait venir une bande ennemie et rend la liste de ses identifiants, ou nil.
-- À vérifier en jeu : System.SpawnEntity classe NPC, et comment les rendre hostiles au camp.
function liaison.faire_venir_ennemis(sorte, effectif, position, cap)
  local ame = liaison.ames_ennemies[sorte]
  if ame == nil or position == nil then
    liaison.journal("Bande impossible (" .. tostring(sorte) .. ") : pas d'âme pour cette sorte")
    return nil
  end
  local liste = {}
  for i = 1, effectif do
    -- Au sol (vu le 14/10 : posé à la hauteur du camp, un brigand flottait au-dessus d'un chemin plus bas).
    local place = liaison.au_sol({ x = position.x + (i % 5) * 1.5, y = position.y + math.floor(i / 5) * 1.5, z = position.z })
    liaison.ennemis_nes = liaison.ennemis_nes + 1
    local identifiant = faire_naitre("NPC", "scriptorium_ennemi_" .. sorte .. "_" .. liaison.ennemis_nes, place, cap,
      { guidSharedSoulId = ame })
    if identifiant then
      -- Étape 2 : éveillée à sa naissance, comme nos hommes (sinon son cerveau ne fait qu'un tour).
      liaison.eveiller(identifiant, "Ennemi « " .. identifiant .. " »")
      table.insert(liste, identifiant)
    end
  end
  if #liste == 0 then
    return nil
  end
  return liste
end

-- Nombre d'ennemis encore vivants.
-- À vérifier en jeu : l'appel qui dit qu'un personnage est mort (entite.actor:IsDead() ?).
function liaison.ennemis_vivants(liste)
  local n = 0
  for _, identifiant in ipairs(liste) do
    if liaison.objet_existe(identifiant) and not liaison.personnage_mort(identifiant) then
      n = n + 1
    end
  end
  return n
end

-- Fait tomber les morts en corps inertes (actor:RagDollize, relevé des fonctions du personnage le 14/10).
-- Vu le 15/10 : un brigand tué par soul:DealDamage restait debout, figé penché en avant, et le jeu ne proposait
-- pas de le fouiller (nos personnages n'ont pas de comportement actif, leur mort ne joue pas la chute).
-- Rend le nombre de corps couchés.
function liaison.coucher_les_corps(liste)
  local couches = 0
  for _, identifiant in ipairs(liste) do
    local entite = entite_nommee(identifiant)
    if entite and type(entite.actor) == "table" then
      local ok = pcall(function() entite.actor:RagDollize() end)
      if ok then couches = couches + 1 end
    end
  end
  return couches
end

function liaison.renvoyer_ennemis(liste)
  for _, identifiant in ipairs(liste) do
    liaison.retirer_objet(identifiant)
  end
end

-- Vrai si le personnage est mort.
-- À vérifier en jeu : entite.actor:IsDead(), ou entite.soul:GetHealth() == 0.
function liaison.personnage_mort(identifiant)
  local ok, mort = pcall(function()
    local entite = entite_nommee(identifiant)
    if entite == nil then return true end
    if entite.actor and entite.actor.IsDead then return entite.actor:IsDead() end
    if entite.soul and entite.soul.GetHealth then return entite.soul:GetHealth() <= 0 end
    return false
  end)
  return ok and mort == true
end

-- Le texte des valeurs rendues par un appel protégé (pcall) : « erreur … », « rien », ou les valeurs, une entité
-- rendue étant donnée par son nom.
local function en_texte(ok, ...)
  if not ok then
    return "erreur " .. tostring((...))
  end
  local n = select("#", ...)
  if n == 0 then
    return "rien"
  end
  local morceaux = {}
  for i = 1, n do
    local valeur = select(i, ...)
    if type(valeur) == "table" and type(valeur.GetName) == "function" then
      local lu, nom = pcall(valeur.GetName, valeur)
      morceaux[i] = lu and ("entité " .. tostring(nom)) or tostring(valeur)
    else
      morceaux[i] = tostring(valeur)
    end
  end
  return table.concat(morceaux, ", ")
end

-- Appel d'une fonction d'une table du jeu (AI.GetFactionOf…), sans « self ».
local function appel(table_du_jeu, nom, ...)
  if type(table_du_jeu) ~= "table" or type(table_du_jeu[nom]) ~= "function" then
    return "absente"
  end
  return en_texte(pcall(table_du_jeu[nom], ...))
end

-- Appel d'une fonction d'une partie d'un personnage (actor, soul, human), avec « self ».
local function sonder(objet, nom, ...)
  if type(objet) ~= "table" then
    return "pas de partie"
  end
  local lu, fonction = pcall(function() return objet[nom] end)
  if not lu or type(fonction) ~= "function" then
    return "absente"
  end
  return en_texte(pcall(fonction, objet, ...))
end

-- Les noms des fonctions d'une partie d'un personnage : celles de la table, puis celles de sa métatable
-- (les parties du moteur portent leurs fonctions dans la métatable).
local function fonctions_de(objet)
  local noms, vus = {}, {}
  local function relever(source)
    if type(source) == "table" then
      for cle, valeur in pairs(source) do
        if type(cle) == "string" and type(valeur) == "function" and not vus[cle] then
          vus[cle] = true
          table.insert(noms, cle)
        end
      end
    end
  end
  relever(objet)
  local ok, meta = pcall(getmetatable, objet)
  if ok and type(meta) == "table" then
    relever(meta)
    relever(meta.__index)
  end
  table.sort(noms)
  return noms
end

-- Ce que le jeu dit d'un personnage, en lignes (poste d'essai, V18 et V19) : position, faction, hostilité envers
-- Henry et envers « autre », vigilance, cible, et les réponses des fonctions qui pourraient dire la mort.
-- « avec_fonctions » : ajoute la liste des fonctions de ses parties actor, soul et human.
function liaison.decrire_personnage(identifiant, autre, avec_fonctions)
  local entite = entite_nommee(identifiant)
  if not entite then
    return { "introuvable" }
  end
  local lignes = {}
  local function ajouter(texte) table.insert(lignes, texte) end
  local lu, ici = pcall(function()
    local p = entite:GetWorldPos()
    local h = player:GetWorldPos()
    return string.format("position %.1f, %.1f ; Henry à %.1f m", p.x, p.y, math.sqrt((p.x - h.x) ^ 2 + (p.y - h.y) ^ 2))
  end)
  ajouter(lu and ici or ("position illisible : " .. tostring(ici)))
  ajouter("mort selon le socle = " .. tostring(liaison.personnage_mort(identifiant)))
  local p = type(entite.Properties) == "table" and entite.Properties or {}
  ajouter("propriétés : voit = " .. tostring(p.bWH_PerceptorObject) .. " ; vu = " .. tostring(p.bWH_PerceptibleObject)
          .. " ; navigation = " .. tostring(p.esNavigationType) .. " ; maison = " .. tostring(p.bWH_RequiresHome))
  local id_d_henry = type(player) == "table" and player.id or nil
  ajouter("agent IA actif = " .. appel(AI, "IsEnabled", entite.id) .. " ; faction = " .. appel(AI, "GetFactionOf", entite.id)
          .. " ; vigilance = " .. appel(AI, "GetAlertness", entite.id)
          .. " ; cible = " .. appel(AI, "GetAttentionTargetEntity", entite.id))
  ajouter("hostile à Henry = " .. appel(AI, "Hostile", entite.id, id_d_henry) .. " ; personnellement = "
          .. appel(AI, "IsPersonallyHostile", entite.id, id_d_henry))
  local autre_entite = entite_nommee(autre)
  if autre_entite then
    ajouter("hostile à « " .. autre .. " » = " .. appel(AI, "Hostile", entite.id, autre_entite.id) .. " ; personnellement = "
            .. appel(AI, "IsPersonallyHostile", entite.id, autre_entite.id))
  end
  for _, partie in ipairs({ "actor", "soul", "human" }) do
    local objet = entite[partie]
    local reponses = {}
    for _, nom in ipairs({ "IsDead", "IsUnconscious", "GetHealth", "GetMaxHealth" }) do
      table.insert(reponses, nom .. " = " .. sonder(objet, nom))
    end
    ajouter(partie .. " : " .. table.concat(reponses, " ; "))
    if avec_fonctions and type(objet) == "table" then
      ajouter(partie .. ", fonctions : " .. table.concat(fonctions_de(objet), " "))
    end
  end
  ajouter("soul : GetState(health) = " .. sonder(entite.soul, "GetState", "health") .. " ; IsInCombatMode = "
          .. sonder(entite.soul, "IsInCombatMode") .. " ; IsInCombatDanger = " .. sonder(entite.soul, "IsInCombatDanger")
          .. " ; GetFactionID = " .. sonder(entite.soul, "GetFactionID"))
  return lignes
end

-- Ce que le monde de l'IA du jeu sait d'une entité (étape 1 de la note de JoVenGer). Dans les scripts du jeu,
-- « entite.this » n'existe que pour une entité inscrite auprès de l'IA (AnimStash.lua : « if self.this ~= nil ») ;
-- l'IA la désigne par son WUID (XGenAIModule.GetMyWUID) et lui attache des liens (XGenAIModule.FindLinks).
local function decrire_le_cerveau(entite)
  local lignes = {}
  local function ajouter(texte) table.insert(lignes, texte) end
  local lu_nom, nom = pcall(function() return entite:GetName() end)
  local lu_this, this = pcall(function() return entite.this end)
  ajouter("« " .. tostring(lu_nom and nom or "?") .. " », classe " .. tostring(entite.class) .. " ; this = "
          .. (lu_this and type(this) or ("illisible : " .. tostring(this))))
  local ou_lu, ou = pcall(function() return entite:GetWorldPos() end)
  if ou_lu and type(ou) == "table" then
    ajouter(string.format("position %.1f, %.1f, %.1f", ou.x, ou.y, ou.z))
  end
  local wuid_lu, wuid = pcall(function() return XGenAIModule.GetMyWUID(entite) end)
  local texte_du_wuid = tostring(wuid)
  if wuid_lu and type(Framework) == "table" and type(Framework.WUIDToMsg) == "function" then
    local lu, message = pcall(Framework.WUIDToMsg, wuid)
    if lu then texte_du_wuid = tostring(message) end
  end
  ajouter("WUID : " .. (wuid_lu and texte_du_wuid or ("refusé : " .. tostring(wuid))))
  if lu_this and type(this) == "table" then
    local lu, liens = pcall(function() return XGenAIModule.FindLinks(this.id, "") end)
    local nombre = 0
    if lu and type(liens) == "table" then
      for _ in pairs(liens) do nombre = nombre + 1 end
    end
    ajouter("liens : " .. (lu and tostring(nombre) or ("refusé : " .. tostring(liens))))
    local retour_lu, retour = pcall(function() return XGenAIModule.GetEntityByWUID(wuid) end)
    ajouter("retour par le WUID : " .. (retour_lu and tostring(retour == entite or (type(retour) == "table" and retour.id == entite.id))
                                         or ("refusé : " .. tostring(retour))))
  end
  local p = type(entite.Properties) == "table" and entite.Properties or {}
  local ames = {}
  for cle, valeur in pairs(p) do
    if type(cle) == "string" and string.find(string.lower(cle), "soul", 1, true) then
      table.insert(ames, cle .. " = " .. tostring(valeur))
    end
  end
  table.sort(ames)
  ajouter("propriétés d'âme : " .. (#ames > 0 and table.concat(ames, " ; ") or "aucune"))
  ajouter("soul : " .. sonder(entite.soul, "GetFactionID") .. " (faction) ; actor = " .. type(entite.actor))
  return lignes
end

-- Les liens d'une entité, tels que le moteur les garde (liens posés par la carte : « _!home », « _@camper_work »…) :
-- une liste de { nom, cible }. Rend aussi la façon de lire qui a marché, ou l'erreur.
local function liens_de(entite)
  local liste = {}
  local lu, nombre = pcall(function() return entite:CountLinks() end)
  if not lu or type(nombre) ~= "number" then
    return liste, "CountLinks : " .. tostring(nombre)
  end
  -- Plusieurs liens peuvent viser la même cible : GetLinkName(cible, rang) les distingue.
  local rangs = {}
  for i = 0, nombre - 1 do
    local cible_lue, cible = pcall(function() return entite:GetLink(i) end)
    local nom = "?"
    if cible_lue and cible ~= nil and type(cible) ~= "table" then
      local brut = cible
      local lue, entite_cible = pcall(System.GetEntity, brut)
      cible = (lue and type(entite_cible) == "table") and entite_cible or nil
      if not cible then nom = "? (cible " .. type(brut) .. ")" end
    end
    if cible_lue and type(cible) == "table" then
      local rang = rangs[cible.id] or 0
      rangs[cible.id] = rang + 1
      local nom_lu, texte = pcall(function() return entite:GetLinkName(cible.id, rang) end)
      if not (nom_lu and texte) then
        nom_lu, texte = pcall(function() return entite:GetLinkName(cible.id) end)
      end
      if nom_lu and texte then nom = tostring(texte) end
    end
    table.insert(liste, { nom = nom, cible = cible_lue and cible or nil })
  end
  return liste, string.format("%d lien(s)", nombre)
end

-- Un figurant du jeu (« additive », « extras » dans son nom) : vie simplifiée ; en V72 a, frappé, il n'a ni perdu de
-- santé ni réagi.
local function est_un_figurant(nom)
  local bas = string.lower(nom)
  return string.find(bas, "additive", 1, true) ~= nil or string.find(bas, "extras", 1, true) ~= nil
end

-- Les classes sociales armées ou d'autorité (V72 b : le vrai habitant le plus proche était un garde de Kuttenberg ; le
-- frapper, c'est une arrestation, pas un petit délit). Noms de social_class.xml.
local CLASSES_ECARTEES = { guard = true, guardLeader = true, watchman = true, catchpole = true, soldier = true,
                           soldier_crimeAuthority = true, bailiff = true, huntsman_crimeAuthority = true, security = true,
                           officer = true }

local function classe_sociale(habitant)
  local lu, nom = pcall(function() return habitant.soul:GetSocialClass().Name end)
  return lu and nom or nil
end

-- Ce que valent les liens de l'habitant du jeu le plus proche d'Henry : chaque lien du moteur, sa cible, et si l'IA
-- le connaît aussi (XGenAIModule.FindLinks sous ce nom). « vrai_habitant » : ni figurant, ni garde, soldat ou autorité.
local function habitant_le_plus_proche(vrai_habitant)
  local plus_proche, distance = nil, nil
  local function chercher_un_habitant()
    local henry = player:GetWorldPos()
    for _, rayon in ipairs({ 40, 150, 300, 600 }) do
      for _, habitant in pairs(System.GetEntitiesInSphereByClass(henry, rayon, "NPC") or {}) do
        -- Sans majuscules : le Directeur s'appelle « Scriptorium_Directeur » (V72 a, il était pris pour un habitant).
        if string.lower(string.sub(habitant:GetName(), 1, 12)) ~= "scriptorium_"
           and not (vrai_habitant and (est_un_figurant(habitant:GetName())
                                       or CLASSES_ECARTEES[classe_sociale(habitant) or ""])) then
          local ou = habitant:GetWorldPos()
          local ecart = math.sqrt((ou.x - henry.x) ^ 2 + (ou.y - henry.y) ^ 2)
          if not distance or ecart < distance then plus_proche, distance = habitant, ecart end
        end
      end
      if plus_proche then break end
    end
  end
  pcall(chercher_un_habitant)
  return plus_proche, distance
end

function liaison.decrire_les_liens()
  local habitant, distance = habitant_le_plus_proche()
  if not habitant then
    return { "aucun personnage du jeu à moins de 150 m d'Henry" }
  end
  local lignes = { string.format("« %s », à %.0f m d'Henry", habitant:GetName(), distance) }
  local liste, comment = liens_de(habitant)
  table.insert(lignes, "moteur : " .. comment)
  for _, lien in ipairs(liste) do
    local cible = lien.cible
    local texte_cible = "?"
    if type(cible) == "table" then
      local lu, nom = pcall(function() return cible:GetName() end)
      texte_cible = (lu and tostring(nom) or "?") .. " [" .. tostring(cible.class) .. "]"
    end
    local connu = "pas de this"
    local lu_this, this = pcall(function() return habitant.this end)
    if lu_this and type(this) == "table" then
      local lu, trouves = pcall(function() return XGenAIModule.FindLinks(this.id, lien.nom) end)
      local n = 0
      if lu and type(trouves) == "table" then for _ in pairs(trouves) do n = n + 1 end end
      connu = lu and tostring(n) or ("refusé : " .. tostring(trouves))
    end
    table.insert(lignes, "  « " .. lien.nom .. " » -> " .. texte_cible .. " ; connu de l'IA : " .. connu)
  end
  return lignes
end

-- Vu en jeu le 15/10 : un personnage né par System.SpawnEntity reçoit le cerveau de son âme, mais son arbre ne fait
-- qu'un tour à la naissance et n'est plus mis à jour. Activé dans la boucle du moteur (Activate), sans mise en sommeil
-- de l'IA (AI.AutoDisable à 0, comme la fabrique AISpawner.lua du jeu), il vit : l'arbre tourne et il marche.
function liaison.eveiller(nom, titre)
  local entite = entite_nommee(nom)
  if not entite then
    return false
  end
  local active = pcall(function() entite:Activate(1) end)
  local eveillee = pcall(function() AI.AutoDisable(entite.id, 0) end)
  liaison.journal(tostring(titre or nom) .. " : Activate = " .. tostring(active) .. ", AutoDisable(0) = " .. tostring(eveillee))
  return active and eveillee
end

-- Essai de combat (étape 1, piste des cerveaux sans horaires) : deux âmes au cerveau npc_battle, de camps faits pour
-- s'affronter au siège de Suchdol (un défenseur, un fantassin de l'armée ennemie), posées à 6 m l'une de l'autre près
-- d'Henry, sans besoin d'une maison (bWH_RequiresHome, vrai par défaut dans la classe NPC). Rend leurs deux noms, ou nil et l'erreur.
liaison.ames_du_combat_d_essai = {
  defenseur = "e2366f94-2002-44c3-905a-f29ae50dba93",   -- oblehaniSuchdole_spojenciB_obrance1
  assaillant = "dda22693-6704-49ff-9278-a4ab030bd186",  -- oblehaniSuchdole_neprateleA_pesak20
}

function liaison.poser_un_combat_d_essai()
  local henry = liaison.position_du_joueur()
  local cap = liaison.cap_du_joueur()
  local angle = math.rad(cap)
  local function devant(metres)
    return liaison.au_sol({ x = henry.x + math.sin(angle) * metres, y = henry.y + math.cos(angle) * metres, z = henry.z })
  end
  local defenseur, erreur = faire_naitre("NPC", "scriptorium_essai_defenseur", devant(8), cap + 180,
                                        { guidSharedSoulId = liaison.ames_du_combat_d_essai.defenseur, bWH_RequiresHome = false })
  if not defenseur then
    return nil, "défenseur : " .. tostring(erreur)
  end
  local assaillant, erreur2 = faire_naitre("NPC", "scriptorium_essai_assaillant", devant(14), cap,
                                          { guidSharedSoulId = liaison.ames_du_combat_d_essai.assaillant, bWH_RequiresHome = false })
  if not assaillant then
    return nil, "assaillant : " .. tostring(erreur2)
  end
  liaison.eveiller(defenseur, "Défenseur")
  liaison.eveiller(assaillant, "Assaillant")
  return { defenseur, assaillant }
end

-- Sonde du cerveau à nous (étape 1). Depuis V50, son arbre (AI/scriptorium/essai_ordres.xml) est un switch (type 6),
-- avec les horaires du jeu à côté : il pose les interruptions (ordre 8 : attaquer la cible), les horaires les jouent.
-- Jusqu'à V49, c'était un simple arbre qui marchait vers un point lu dans une variable de son cerveau
-- (scriptorium_essai_point, vec3) : point A posé à la naissance (8 m à gauche d'Henry), point B par un ordre.
liaison.ame_du_marcheur = "3241c366-db25-47da-9710-f621eb79554e"   -- scriptorium_essai_marcheur
liaison.marcheur = liaison.marcheur
liaison.point_vise = liaison.point_vise

local function pres_d_henry(devant, a_droite)
  local henry = liaison.position_du_joueur()
  local angle = math.rad(liaison.cap_du_joueur())
  local x = henry.x + math.sin(angle) * devant + math.cos(angle) * a_droite
  local y = henry.y + math.cos(angle) * devant - math.sin(angle) * a_droite
  return liaison.au_sol({ x = x, y = y, z = henry.z })
end

-- Pose le point visé dans le cerveau du marcheur ; rend une ligne.
function liaison.viser_un_point(cote)
  local entite = entite_nommee(liaison.marcheur)
  local this_lu, this = pcall(function() return entite.this end)
  if not entite or not this_lu or type(this) ~= "table" then
    return "point : marcheur introuvable ou sans this"
  end
  local point = pres_d_henry(0, cote == "droite" and 8 or -8)
  local ok, erreur = pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_point", point) end)
  liaison.point_vise = point
  local relu_lu, relu = pcall(function() return XGenAIModule.GetBrainVariable(this.id, "scriptorium_essai_point") end)
  local texte_relu = tostring(relu)
  if relu_lu and type(relu) == "table" then
    texte_relu = string.format("%.1f, %.1f, %.1f", relu.x or -1, relu.y or -1, relu.z or -1)
  end
  return string.format("point %s (%.1f, %.1f) : %s ; relu %s", cote, point.x, point.y,
    ok and "posé" or ("refusé : " .. tostring(erreur)), relu_lu and texte_relu or "illisible")
end

function liaison.poser_le_marcheur()
  local nom, erreur = faire_naitre("NPC", "scriptorium_essai_marcheur", pres_d_henry(10, 0), liaison.cap_du_joueur() + 180,
                                   { guidSharedSoulId = liaison.ame_du_marcheur, bWH_RequiresHome = false })
  if not nom then
    return nil, erreur
  end
  liaison.marcheur = nom
  local ligne = liaison.viser_un_point("gauche")
  liaison.eveiller(nom, "Marcheur")
  return nom, ligne
end

-- L'adversaire d'essai : même âme et même cerveau que le marcheur, posé à 6 m devant Henry ; son point visé est sa
-- place de naissance (il y reste). Rend son nom et une ligne.
liaison.adversaire = liaison.adversaire

liaison.ame_du_brigand_d_essai = "edd4e924-20ea-441e-8048-e8d73aee4bca"   -- scriptorium_essai_brigand : notre cerveau, faction de brigands

-- « brigand » : l'adversaire reçoit l'âme du brigand d'essai (faction ennemie publique de Kuttenberg) au lieu de celle du
-- marcheur ; même cerveau.
function liaison.poser_l_adversaire(brigand)
  local place = pres_d_henry(6, 3)
  local nom, erreur = faire_naitre("NPC", "scriptorium_essai_adversaire", place, liaison.cap_du_joueur() + 180,
                                   { guidSharedSoulId = brigand and liaison.ame_du_brigand_d_essai or liaison.ame_du_marcheur,
                                     bWH_RequiresHome = false })
  if not nom then
    return nil, "adversaire refusé : " .. tostring(erreur)
  end
  liaison.adversaire = nom
  local entite = entite_nommee(nom)
  local this_lu, this = pcall(function() return entite.this end)
  local ok = this_lu and type(this) == "table" and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_point", place) end)
  liaison.eveiller(nom, "Adversaire")
  return nom, "adversaire posé, sa place gardée : " .. tostring(ok)
end

-- L'ordre « rejoindre » : le marcheur reçoit l'adversaire pour cible (variable wuid) et l'ordre 6, marcher jusqu'à lui,
-- sans rien de combat. Pose l'adversaire au besoin. Rend des lignes.
function liaison.ordonner_de_rejoindre()
  local lignes = {}
  if not entite_nommee(liaison.adversaire) then
    local _, ligne = liaison.poser_l_adversaire()
    table.insert(lignes, tostring(ligne))
  end
  local qui, contre = entite_nommee(liaison.marcheur), entite_nommee(liaison.adversaire)
  local this_lu, this = pcall(function() return qui.this end)
  local wuid_lu, wuid = pcall(function() return XGenAIModule.GetMyWUID(contre) end)
  if qui and contre and this_lu and type(this) == "table" and wuid_lu then
    local cible_ok, erreur = pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_cible", wuid) end)
    local ordre_ok = pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_ordre", 6) end)
    local relu_lu, relu = pcall(function() return XGenAIModule.GetBrainVariable(this.id, "scriptorium_essai_cible") end)
    table.insert(lignes, "rejoindre : cible " .. (cible_ok and "posée" or ("refusée : " .. tostring(erreur))) .. " (" .. tostring(wuid)
      .. "), relue " .. tostring(relu_lu and relu) .. ", ordre " .. tostring(ordre_ok))
  else
    table.insert(lignes, "rejoindre : impossible (introuvable ou sans this)")
  end
  return lignes
end

-- L'ordre de combat : chacun reçoit l'autre pour cible (variable wuid scriptorium_essai_cible) et l'ordre 5 ; l'adversaire
-- déjà posé est repris (vu le 15/10 : en poser un second au même endroit les superpose). Rend des lignes.
function liaison.ordonner_le_combat(brigand)
  local lignes = {}
  if brigand or not entite_nommee(liaison.adversaire) then
    local _, ligne = liaison.poser_l_adversaire(brigand)
    table.insert(lignes, tostring(ligne))
  end
  local paires = { { liaison.marcheur, liaison.adversaire }, { liaison.adversaire, liaison.marcheur } }
  for _, paire in ipairs(paires) do
    local qui, contre = entite_nommee(paire[1]), entite_nommee(paire[2])
    local this_lu, this = pcall(function() return qui.this end)
    local wuid_lu, wuid = pcall(function() return XGenAIModule.GetMyWUID(contre) end)
    if qui and contre and this_lu and type(this) == "table" and wuid_lu then
      local cible_ok, erreur = pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_cible", wuid) end)
      local ordre_ok = pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_ordre", 5) end)
      table.insert(lignes, tostring(paire[1]) .. " contre " .. tostring(paire[2]) .. " : cible " ..
        (cible_ok and "posée" or ("refusée : " .. tostring(erreur))) .. ", ordre " .. tostring(ordre_ok))
    else
      table.insert(lignes, tostring(paire[1]) .. " : combat impossible (introuvable ou sans this)")
    end
  end
  return lignes
end

-- Un ordre à l'un de nos personnages (variable de cerveau scriptorium_essai_ordre). Rend une ligne.
local function poser_l_ordre(entite, ordre)
  local this_lu, this = pcall(function() return entite.this end)
  if not entite or not this_lu or type(this) ~= "table" then
    return "ordre : personnage introuvable ou sans this"
  end
  local ok, erreur = pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_ordre", ordre) end)
  return "ordre " .. ordre .. " : " .. (ok and "posé" or ("refusé : " .. tostring(erreur)))
end

-- Fiche 12 (les valeurs de l'arbre en données) : chaque valeur (nom → entier) dans la variable de cerveau
-- scriptorium_cerveau_<nom> du personnage, gardée dans la sauvegarde. Rend (vrai si tout est écrit, ligne).
function liaison.regler_le_cerveau(identifiant, valeurs)
  local entite = entite_nommee(identifiant)
  local this_lu, this = pcall(function() return entite.this end)
  if not entite or not this_lu or type(this) ~= "table" then
    return false, "cerveau : personnage introuvable ou sans this"
  end
  local ecrites, refusees = 0, {}
  for nom, valeur in pairs(valeurs) do
    local ecrite, refus = pcall(XGenAIModule.SetBrainVariable, this.id, "scriptorium_cerveau_" .. nom, valeur)
    if ecrite then
      ecrites = ecrites + 1
    else
      table.insert(refusees, nom .. " (" .. tostring(refus) .. ")")
    end
  end
  table.sort(refusees)
  return #refusees == 0, ecrites .. " valeur(s) écrite(s)" .. (#refusees > 0 and (", refusées : " .. table.concat(refusees, ", ")) or "")
end

-- Les variables du cerveau d'un personnage (fiche 15, V73 b 2 : les arrêts du plafond de relances) : { nom = valeur } ;
-- un nom dont la lecture est refusée n'a pas de clé.
function liaison.lire_le_cerveau(identifiant, noms)
  local rendu = {}
  local entite = entite_nommee(identifiant)
  local this_lu, this = pcall(function() return entite.this end)
  if not entite or not this_lu or type(this) ~= "table" then
    return rendu
  end
  for _, nom in ipairs(noms) do
    local lu, valeur = pcall(XGenAIModule.GetBrainVariable, this.id, nom)
    if lu then
      rendu[nom] = valeur
    end
  end
  return rendu
end

-- Fiche 12, révision du 16/10 : l'activité de la vie du camp (variable de cerveau scriptorium_activite : 0 attendre sur
-- place, 9 marcher au point, 10 s'asseoir, 11 se coucher), puis le compteur d'ordres. La garde du comportement long voit
-- le compteur changer : l'activité en cours finit du dedans (le jeu joue le geste de se lever), et la boucle prend la
-- nouvelle. L'activité est posée avant le compteur. Rend une ligne, avec le compteur tel que lu puis écrit.
local function poser_l_activite(entite, activite)
  local this_lu, this = pcall(function() return entite.this end)
  if not entite or not this_lu or type(this) ~= "table" then
    return "activité : personnage introuvable ou sans this"
  end
  local activite_posee, refus = pcall(XGenAIModule.SetBrainVariable, this.id, "scriptorium_activite", activite)
  local numero_lu, numero = pcall(XGenAIModule.GetBrainVariable, this.id, "scriptorium_essai_numero")
  local suivant = (numero_lu and tonumber(numero) or 0) + 1
  local numero_pose, refus_du_numero = pcall(XGenAIModule.SetBrainVariable, this.id, "scriptorium_essai_numero", suivant)
  local compteur = numero_lu and ("compteur " .. tostring(numero) .. " → " .. suivant) or ("compteur illisible : " .. tostring(numero))
  if not numero_pose then
    compteur = compteur .. ", non écrit : " .. tostring(refus_du_numero)
  end
  return "activité " .. activite .. " : " .. (activite_posee and "posée" or ("refusée : " .. tostring(refus))) .. " ; " .. compteur
end

-- Un ordre au marcheur (4 = s'asseoir par terre, 0 = marcher au point). Rend une ligne.
function liaison.ordonner_au_marcheur(ordre)
  local entite = entite_nommee(liaison.marcheur)
  if not entite then
    return "ordre : marcheur introuvable"
  end
  return poser_l_ordre(entite, ordre)
end

-- Le brigand du jeu (étape 1, conseil du 15/10) : une âme du jeu avec son cerveau d'origine (npc_basic), faction ennemie
-- publique de Kuttenberg, née à 8 m devant Henry et éveillée, sans rien de notre cerveau ni de nos arbres. Se bat-elle ?
liaison.ame_du_brigand_du_jeu = "08994591-c246-401d-bcd9-ca5d0fe1ddd7"   -- kopa_man_16, camp d'Opatovice
-- Un brigand plus léger (V54) : kopa_man_16 porte une armure complète et n'a jamais été blessé (V43 à V53) ; celui-ci a
-- le plus bas niveau de combat des brigands de Kuttenberg au cerveau npc_basic (combat_level 0.1 dans soul__kkop.xml).
liaison.ame_du_brigand_leger = "74aea673-42aa-4e0d-b861-cc5d56a44574"   -- kkop_bandit_7, camp de Kopec Vysoká
liaison.brigand_du_jeu = liaison.brigand_du_jeu

-- « ame » : l'âme du brigand ; celle de kopa_man_16 par défaut.
-- « position » (facultative, V73 b 1) : posé sur une place libre près de ce point ; sinon, 8 m devant Henry.
function liaison.poser_le_brigand_du_jeu(ame, position)
  local ou = pres_d_henry(8, 0)
  if position then
    ou = place_libre(liaison.au_sol(position))
    if not ou then
      return "brigand du jeu refusé : aucune place libre près du point voulu"
    end
  end
  local nom, erreur = faire_naitre("NPC", "scriptorium_essai_brigand_du_jeu", ou, liaison.cap_du_joueur() + 180,
                                   { guidSharedSoulId = ame or liaison.ame_du_brigand_du_jeu, bWH_RequiresHome = false })
  if not nom then
    return "brigand du jeu refusé : " .. tostring(erreur)
  end
  liaison.brigand_du_jeu = nom
  liaison.eveiller(nom, "Brigand du jeu")
  return "brigand du jeu posé " .. (position and string.format("en (%.1f, %.1f)", ou.x, ou.y) or "à 8 m") .. " : " .. nom
end

function liaison.voir_le_brigand_du_jeu()
  local entite = entite_nommee(liaison.brigand_du_jeu)
  if not entite then
    return "brigand du jeu introuvable"
  end
  local vie_lue, vie = pcall(function() return entite.actor:GetHealth() end)
  local henry_lu, henry = pcall(function() return player.actor:GetHealth() end)
  local faction = sonder(entite.soul, "GetFactionID")
  local ligne = string.format("brigand du jeu à %.1f m d'Henry, santé %s ; Henry santé %s ; faction %s",
    liaison.distance_a_henry(liaison.brigand_du_jeu) or -1, vie_lue and tostring(vie) or "?", henry_lu and tostring(henry) or "?", faction)
  local marcheur = entite_nommee(liaison.marcheur)
  if marcheur then
    local ou_lu, ecart = pcall(function()
      local p, q = entite:GetWorldPos(), marcheur:GetWorldPos()
      return math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2)
    end)
    local sa_vie_lue, sa_vie = pcall(function() return marcheur.actor:GetHealth() end)
    ligne = ligne .. string.format(" ; à %s m du marcheur, santé du marcheur %s", ou_lu and string.format("%.1f", ecart) or "?",
      sa_vie_lue and tostring(sa_vie) or "?")
  end
  return ligne
end

-- Le coup reçu (étape 1) : blesse « victime » de quelques points en donnant « auteur » comme auteur du coup ; le troisième
-- argument de soul:DealDamage vaut __null dans l'aide du jeu (Scripts/Debug/Quick.lua) : on essaie l'entité de l'auteur,
-- puis son this.id. Rend une ligne.
function liaison.blesser_de_la_part_de(victime, auteur, points)
  local cible, source = entite_nommee(victime), entite_nommee(auteur)
  if not cible or not source or type(cible.soul) ~= "table" then
    return "coup impossible : victime ou auteur introuvable"
  end
  local essais = {}
  local this_lu, this = pcall(function() return source.this end)
  for _, forme in ipairs({ { "entité", source }, { "this.id", (this_lu and type(this) == "table") and this.id or nil }, { "id", source.id } }) do
    if forme[2] ~= nil then
      local ok, erreur = pcall(function() cible.soul:DealDamage(points, points, forme[2], true) end)
      table.insert(essais, forme[1] .. " " .. (ok and "accepté" or ("refusé : " .. tostring(erreur))))
      if ok then break end
    end
  end
  return "coup de " .. auteur .. " à " .. victime .. " (" .. points .. ") : " .. table.concat(essais, ", ")
end

-- Le vrai coup d'Henry (étape 1, 15/10) : par les règles du jeu (g_gameRules:CreateHit, Scripts/GameRules/SinglePlayer.lua),
-- le chemin de tous les coups du jeu (réaction, stimulus de l'IA), Henry pour auteur ; soul:DealDamage (V42) ne baisse
-- peut-être que la santé. Rend une ligne.
local function frapper(cible, auteur, qui, titre, points)
  if not cible or not auteur then
    return titre .. " ou " .. qui .. " introuvable"
  end
  local ok, erreur = pcall(function() g_gameRules:CreateHit(cible.id, auteur.id, auteur.id, points) end)
  return string.format("coup de %s à %s (%d) : %s", qui, titre, points, ok and "porté" or ("refusé : " .. tostring(erreur)))
end

local function frapper_par_henry(cible, titre, points)
  return frapper(cible, player, "Henry", titre, points)
end

-- Le coup « de la part de » notre homme (V44) : le marcheur pour auteur d'un vrai coup sur le brigand du jeu. Le brigand
-- l'attaque-t-il, et le marcheur se défend-il ? (moyen possible, pour le Directeur, de lancer un combat).
function liaison.marcheur_frappe_le_brigand(points)
  return frapper(entite_nommee(liaison.brigand_du_jeu), entite_nommee(liaison.marcheur), "marcheur", "brigand du jeu", points)
end

function liaison.henry_frappe_le_brigand(points)
  return frapper_par_henry(entite_nommee(liaison.brigand_du_jeu), "brigand du jeu", points)
end

function liaison.henry_frappe_le_marcheur(points)
  return frapper_par_henry(entite_nommee(liaison.marcheur), "marcheur", points)
end

function liaison.henry_frappe_l_adversaire(points)
  return frapper_par_henry(entite_nommee(liaison.adversaire), "adversaire", points)
end

-- Le contrôle : le même coup sur l'habitant de la carte le plus proche. S'il ne réagit pas non plus, le coup ne prouve
-- rien sur le brigand.
liaison.habitant_frappe = liaison.habitant_frappe

function liaison.henry_frappe_un_habitant(points)
  local habitant, distance = habitant_le_plus_proche()
  if not habitant then
    return "aucun habitant à moins de 150 m d'Henry"
  end
  liaison.habitant_frappe = habitant:GetName()
  return frapper_par_henry(habitant, string.format("« %s », à %.0f m,", habitant:GetName(), distance), points)
end

function liaison.voir_l_habitant_frappe()
  local entite = entite_nommee(liaison.habitant_frappe)
  if not entite then
    return "habitant frappé introuvable"
  end
  local vie_lue, vie = pcall(function() return entite.actor:GetHealth() end)
  local henry_lu, henry = pcall(function() return player.actor:GetHealth() end)
  return string.format("« %s » à %.1f m d'Henry, santé %s ; Henry santé %s", liaison.habitant_frappe,
    liaison.distance_a_henry(liaison.habitant_frappe) or -1, vie_lue and tostring(vie) or "?", henry_lu and tostring(henry) or "?")
end

-- Les appels de naissance de l'IA (piste de la conversation Scriptorium, 15/10) : XGenAIModule.OnSpawn et OnStart existent
-- dans le jeu publié, et aucun script du jeu ne les appelle. Essayés sur le brigand du jeu : this.id, puis l'entité,
-- puis son id ; on s'arrête à la première forme acceptée. Rend une ligne.
function liaison.annoncer_la_naissance()
  local entite = entite_nommee(liaison.brigand_du_jeu)
  if not entite then
    return "brigand du jeu introuvable"
  end
  local this_lu, this = pcall(function() return entite.this end)
  local formes = { { "this.id", (this_lu and type(this) == "table") and this.id or nil }, { "entité", entite }, { "id", entite.id } }
  local lignes = {}
  for _, nom in ipairs({ "OnSpawn", "OnStart" }) do
    local lu, appel = pcall(function() return XGenAIModule[nom] end)
    if not lu or type(appel) ~= "function" then
      table.insert(lignes, nom .. " absente")
    else
      for _, forme in ipairs(formes) do
        if forme[2] ~= nil then
          local ok, rendu = pcall(appel, forme[2])
          table.insert(lignes, nom .. "(" .. forme[1] .. ") " .. (ok and ("rend " .. tostring(rendu)) or ("refusé : " .. tostring(rendu))))
          if ok then break end
        end
      end
    end
  end
  return table.concat(lignes, " ; ")
end

-- L'ordre 8 (V45) : le marcheur reçoit le brigand du jeu pour cible (variable wuid) et l'ordre 8 ; son arbre appelle la
-- fonction d'arbre du jeu callInterrupt_attack (AI/npc/basic/switch/callInterrupt_attack.xml), qui lui pose
-- l'interruption « attaque » du jeu contre cette cible, sans aucun coup. Rend une ligne.
-- « cible » : le nom de l'entité à attaquer ; le brigand du jeu par défaut (V51 : l'adversaire, qui ne se défend pas).
-- « attaquant » : le marcheur par défaut ; un de nos hommes (même cerveau) pour V71 d (voir ce qu'il prend en main).
function liaison.ordonner_l_attaque(cible, attaquant)
  -- Étape 2 : la cible « henry » est le joueur (la bande l'attaque s'il est là).
  local qui = entite_nommee(attaquant or liaison.marcheur)
  local contre = (cible == "henry") and player or entite_nommee(cible or liaison.brigand_du_jeu)
  local this_lu, this = pcall(function() return qui.this end)
  local wuid_lu, wuid = pcall(function() return XGenAIModule.GetMyWUID(contre) end)
  if not qui or not contre or not this_lu or type(this) ~= "table" or not wuid_lu then
    return "attaque : marcheur ou cible introuvable, ou sans this"
  end
  -- Vu en V51, V52 : sans arme tirée, il engage sans blesser ; l'ordre d'attaque la fait donc tirer (human:DrawWeapon,
  -- comme Scripts/Debug/CombatDebug.lua du jeu après la naissance de ses combattants).
  local tiree, refus = pcall(function() qui.human:DrawWeapon() end)
  local cible_ok, erreur = pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_cible", wuid) end)
  local ordre_ok = pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_ordre", 8) end)
  return "attaque : arme " .. (tiree and "tirée" or ("non tirée : " .. tostring(refus))) .. ", cible "
    .. (cible_ok and "posée" or ("refusée : " .. tostring(erreur))) .. ", ordre 8 " .. tostring(ordre_ok)
end

-- Le garde du jeu (V49) : une âme de garde de Kuttenberg faite pour être appelée par le jeu (extraGuards, cerveau
-- npc_basic), née par script à 4 m d'Henry, sur sa gauche, et éveillée. Vient-il défendre Henry contre le brigand du jeu ?
liaison.ame_du_garde_du_jeu = "0e1aba06-82de-4270-b0ec-46a8b4744abc"   -- extraGuards_kutnaHora_soldiers_guards_7
liaison.garde_du_jeu = liaison.garde_du_jeu

function liaison.poser_le_garde_du_jeu()
  local nom, erreur = faire_naitre("NPC", "scriptorium_essai_garde_du_jeu", pres_d_henry(2, -4), liaison.cap_du_joueur(),
                                   { guidSharedSoulId = liaison.ame_du_garde_du_jeu, bWH_RequiresHome = false })
  if not nom then
    return "garde du jeu refusé : " .. tostring(erreur)
  end
  liaison.garde_du_jeu = nom
  liaison.eveiller(nom, "Garde du jeu")
  return "garde du jeu posé à 4 m : " .. nom
end

function liaison.voir_le_garde_du_jeu()
  local garde = entite_nommee(liaison.garde_du_jeu)
  if not garde then
    return "garde du jeu introuvable"
  end
  local vie_lue, vie = pcall(function() return garde.actor:GetHealth() end)
  local ligne = string.format("garde du jeu à %.1f m d'Henry, santé %s", liaison.distance_a_henry(liaison.garde_du_jeu) or -1,
    vie_lue and tostring(vie) or "?")
  local brigand = entite_nommee(liaison.brigand_du_jeu)
  if brigand then
    local ecart_lu, ecart = pcall(function()
      local p, q = garde:GetWorldPos(), brigand:GetWorldPos()
      return math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2)
    end)
    local sa_vie_lue, sa_vie = pcall(function() return brigand.actor:GetHealth() end)
    ligne = ligne .. string.format(" ; à %s m du brigand du jeu, santé du brigand %s", ecart_lu and string.format("%.1f", ecart) or "?",
      sa_vie_lue and tostring(sa_vie) or "?")
  end
  return ligne
end

-- Armer le marcheur (V52) : l'arme tirée, comme l'outil de combat du jeu après la naissance de ses combattants
-- (Scripts/Debug/CombatDebug.lua : human:DrawWeapon). Relève aussi ses compétences de combat (soul:GetSkillLevel), pour
-- savoir si elles sont nulles. Rend une ligne.
liaison.competences_de_combat = { "weapon_sword", "heavy_weapons", "weapon_large", "weapon_unarmed", "defense" }

function liaison.armer_le_marcheur()
  local entite = entite_nommee(liaison.marcheur)
  if not entite then
    return "armer : marcheur introuvable"
  end
  local tiree, erreur = pcall(function() entite.human:DrawWeapon() end)
  local niveaux = {}
  for _, competence in ipairs(liaison.competences_de_combat) do
    table.insert(niveaux, competence .. " " .. sonder(entite.soul, "GetSkillLevel", competence))
  end
  return "armer : arme tirée " .. (tiree and "demandée" or ("refusée : " .. tostring(erreur))) .. " ; " .. table.concat(niveaux, ", ")
end

-- Le lieu des essais de combat (V43 à V52) : la prairie au nord des remparts de Kuttenberg, loin des maisons. Plutôt
-- que d'y mener Henry en courant à chaque séance (question de JoVenGer du 15/10), il y est posé, posé au sol, comme le
-- jeu pose Henry à un point d'apparition (Scripts/GameRules/SinglePlayer.lua : player:SetWorldPos). Rend une ligne.
liaison.prairie_des_essais = { x = 3327.4, y = 1078.5 }

function liaison.mener_henry_en_prairie()
  local lieu = liaison.au_sol({ x = liaison.prairie_des_essais.x, y = liaison.prairie_des_essais.y, z = 0 })
  local ok, erreur = pcall(function() player:SetWorldPos(lieu) end)
  if not ok then
    return "prairie : refusé : " .. tostring(erreur)
  end
  return string.format("prairie : Henry posé en (%.1f, %.1f, %.1f)", lieu.x, lieu.y, lieu.z)
end

-- Les compétences de combat du marcheur (essai V53) : l'outil de combat du jeu les pose par soul:SetSkillLevelDebug
-- (Scripts/Debug/CombatDebug.lua), le jeu fait monter celles d'Henry par soul:AdvanceToSkillLevel
-- (Scripts/Entities/actor/player.lua). On essaie l'un puis l'autre, et on relit. Rend une ligne.
liaison.niveau_de_combat_d_essai = 20

function liaison.donner_des_competences(niveau)
  local entite = entite_nommee(liaison.marcheur)
  if not entite or type(entite.soul) ~= "table" then
    return "compétences : marcheur introuvable"
  end
  local lignes = {}
  for _, competence in ipairs(liaison.competences_de_combat) do
    local comment = "aucun appel accepté"
    for _, appel in ipairs({ "SetSkillLevelDebug", "AdvanceToSkillLevel" }) do
      local ok = pcall(function() entite.soul[appel](entite.soul, competence, niveau) end)
      if ok then comment = appel break end
    end
    table.insert(lignes, competence .. " " .. sonder(entite.soul, "GetSkillLevel", competence) .. " (" .. comment .. ")")
  end
  return "compétences : " .. table.concat(lignes, ", ")
end

-- Aller au point (V55). Le point (8 m à droite d'Henry) est posé dans la variable du cerveau ; depuis la révision du
-- 16/10 (fiche 12), c'est l'activité 9 du comportement long « scriptorium_vie_du_camp » (AI/scriptorium/comportements.xml),
-- lancé par le switch. Compteurs : « rejoint » = lancements du comportement long, « arrive » = arrivées. Rend une ligne.
function liaison.ordonner_d_aller(cote)
  local ligne = liaison.viser_un_point(cote or "droite")
  return ligne .. " ; " .. poser_l_activite(entite_nommee(liaison.marcheur), 9)
end

-- L'ordre 7 : le marcheur se bat contre Henry (pour savoir si un homme né par script peut frapper qui que ce soit).
function liaison.ordonner_contre_henry()
  return liaison.ordonner_au_marcheur(7)
end

-- Ce que devient le marcheur : distance au point visé et à Henry, tours de l'arbre, arrivées.
function liaison.voir_le_marcheur()
  local entite = entite_nommee(liaison.marcheur)
  if not entite then
    return "marcheur introuvable"
  end
  local this_lu, this = pcall(function() return entite.this end)
  local function variable(nom)
    if not this_lu or type(this) ~= "table" then return "?" end
    local ok, valeur = pcall(function() return XGenAIModule.GetBrainVariable(this.id, nom) end)
    return ok and tostring(valeur) or "?"
  end
  local ici = entite:GetWorldPos()
  local au_point = "-"
  if liaison.point_vise then
    au_point = string.format("%.1f", math.sqrt((ici.x - liaison.point_vise.x) ^ 2 + (ici.y - liaison.point_vise.y) ^ 2))
  end
  local sante_lue, sante = pcall(function() return entite.actor:GetHealth() end)
  local texte_adversaire = ""
  local adversaire = entite_nommee(liaison.adversaire)
  if adversaire then
    local la = adversaire:GetWorldPos()
    local vie_lue, vie = pcall(function() return adversaire.actor:GetHealth() end)
    texte_adversaire = string.format(" ; adversaire à %.1f m, à %.1f m d'Henry, santé %s, endurance %s", math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2),
      liaison.distance_a_henry(liaison.adversaire) or -1, vie_lue and tostring(vie) or "?", sonder(adversaire.soul, "GetState", "stamina"))
  end
  local henry_lu, henry_sante = pcall(function() return player.actor:GetHealth() end)
  texte_adversaire = texte_adversaire .. " ; Henry santé " .. (henry_lu and tostring(henry_sante) or "?")
  local ecart = liaison.ecart_a_l_objet_vise()
  if ecart then
    local liens_lus, liens = false, nil
    if this_lu and type(this) == "table" then
      liens_lus, liens = pcall(function() return XGenAIModule.FindLinks(this.id, "bench") end)
    end
    local n = 0
    if liens_lus and type(liens) == "table" then
      for _ in pairs(liens) do n = n + 1 end
    end
    texte_adversaire = texte_adversaire .. string.format(" ; à %.2f m de l'objet visé, liens « bench » %s", ecart, liens_lus and tostring(n) or "?")
  end
  return string.format("à %s m du point visé, %.1f m d'Henry ; tours %s, arrivées %s, assis %s, couchés %s, rejoint %s, combats %s, santé %s%s", au_point,
    liaison.distance_a_henry(liaison.marcheur) or -1, variable("scriptorium_essai_vivant"), variable("scriptorium_essai_arrive"),
    variable("scriptorium_essai_assis"), variable("scriptorium_essai_couche"), variable("scriptorium_essai_rejoint"), variable("scriptorium_essai_combats"),
    sante_lue and tostring(sante) or "?", texte_adversaire)
end

-- Essai du réveil (V56). Après « Sauvegarder et quitter » puis rechargement, la mémoire Lua est neuve : liaison.marcheur
-- est nul. Le marcheur est cherché sous son nom de naissance (le premier rendu par nom_libre) ; la ligne dit s'il est
-- encore dans le monde, s'il a encore un cerveau lisible (this) et ce que gardent ses variables. Le jeu ne réveille pas
-- lui-même ses personnages au chargement : sa fabrique (Scripts/Entities/AI/AISpawner.lua) ne fait AI.AutoDisable(id, 0)
-- qu'à la naissance, et BasicAI.lua ne garde à la sauvegarde que sa table AI. Rend une ligne.
liaison.nom_du_marcheur = "scriptorium_essai_marcheur"

function liaison.retrouver_le_marcheur()
  local nom = liaison.marcheur or liaison.nom_du_marcheur
  local entite = entite_nommee(nom)
  if not entite then
    return "retrouver : « " .. nom .. " » absent du monde"
  end
  liaison.marcheur = nom
  local this_lu, this = pcall(function() return entite.this end)
  if not this_lu or type(this) ~= "table" then
    return "retrouver : « " .. nom .. " » présent, sans this (cerveau illisible)"
  end
  local function variable(cle)
    local ok, valeur = pcall(function() return XGenAIModule.GetBrainVariable(this.id, cle) end)
    if not ok then
      return "?"
    end
    return valeur
  end
  local point = variable("scriptorium_essai_point")
  local texte_point = tostring(point)
  if type(point) == "table" then
    liaison.point_vise = { x = point.x, y = point.y, z = point.z }
    texte_point = string.format("%.1f, %.1f", point.x or -1, point.y or -1)
  end
  return string.format("retrouver : « %s » présent, à %.1f m d'Henry ; point %s, ordre %s, tours %s, arrivées %s", nom,
    liaison.distance_a_henry(nom) or -1, texte_point, tostring(variable("scriptorium_essai_ordre")),
    tostring(variable("scriptorium_essai_vivant")), tostring(variable("scriptorium_essai_arrive")))
end

-- Le réveil du marcheur retrouvé (V56), le même que celui de sa naissance. Rend une ligne.
function liaison.eveiller_le_marcheur()
  if not entite_nommee(liaison.marcheur) then
    return "éveiller : marcheur introuvable (le retrouver d'abord)"
  end
  return "éveiller : " .. (liaison.eveiller(liaison.marcheur, "Marcheur") and "fait" or "refusé (voir la ligne du marcheur)")
end

-- Retire le marcheur du monde (fin de l'essai V56, pour ne pas le laisser dans la sauvegarde de la partie d'essai).
function liaison.retirer_le_marcheur()
  local nom = liaison.marcheur or liaison.nom_du_marcheur
  if not entite_nommee(nom) then
    return "retirer : « " .. nom .. " » absent"
  end
  liaison.retirer_objet(nom)
  liaison.marcheur = nil
  liaison.point_vise = nil
  return "retirer : « " .. nom .. " » retiré, encore là = " .. tostring(entite_nommee(nom) ~= nil)
end

-- S'asseoir et se coucher (V60 à V62). Principe transmis par la conversation Scriptorium : un StanceSmartObject et son
-- WUID. Vu en jeu (V60) : sièges et lits du monde sont tous des StanceSmartObject (5 354 autour de Kuttenberg, aucune
-- entité Bed) ; un banc a la sorte « Chair », le type so_sitPlace (57cbebae-…), les points d'appui
-- « Sit_1Place_Bench_Low », et un WUID lisible ; un lit, la sorte GroundBed, NormalBed ou Bench et le type so_bed
-- (425d4fdf-…). Notre StanceElement sur ce WUID, hébergé ailleurs que sur l'objet, n'assoit pas l'homme : ni sur place
-- (V60), ni après une marche jusqu'au banc (V61, arrivé à 0,57 m, resté debout). Le jeu, lui, héberge la posture sur
-- l'objet : son gabarit (Libs/Tables/ai/smartEntity/SmartEntity__so_sitPlace.xml, __so_bed.xml) porte un comportement
-- « use » (AI/world/so_sitPlace.xml, so_bed.xml : liens « bench », puis StanceElement sur $__object.id), et un personnage
-- le joue par CallBehavior sur l'objet (AI/crime/mournOnBench.xml). Nos comportements font de même (V62).
liaison.objet_vise = liaison.objet_vise
liaison.sieges_d_essai = liaison.sieges_d_essai or {}

local function sorte_de(e)
  local p = type(e.Properties) == "table" and e.Properties or {}
  local donnees_script = type(p.Script) == "table" and p.Script or {}
  return tostring(donnees_script.esBedTypes), tostring(p.soclass_SmartObjectHelpers)
end

-- Un lit se reconnaît à sa sorte ou à ses points d'appui (couché, sommeil) ; un siège à la sorte « Chair ».
local function est_un_lit(e)
  local sorte, aides = sorte_de(e)
  local texte = string.lower(sorte .. " " .. aides)
  return sorte ~= "Chair" and (string.find(texte, "bed", 1, true) or string.find(texte, "sleep", 1, true)
    or string.find(texte, "lie", 1, true) or string.find(texte, "lying", 1, true)) ~= nil
end

local function est_un_siege(e)
  return (sorte_de(e)) == "Chair"
end

local genres = { siege = est_un_siege, lit = est_un_lit }

-- Les StanceSmartObject du monde qui passent le filtre, du plus proche d'Henry au plus loin ; rend les « combien »
-- premiers et le total.
local function plus_proches(filtre, combien)
  local henry = liaison.position_du_joueur()
  local ok, liste = pcall(System.GetEntitiesByClass, "StanceSmartObject")
  if not ok or type(liste) ~= "table" then
    return {}, "liste refusée : " .. tostring(liste)
  end
  local trouves = {}
  for _, e in pairs(liste) do
    local lu, ici = pcall(function() return e:GetWorldPos() end)
    if lu and type(ici) == "table" and (filtre == nil or filtre(e)) then
      table.insert(trouves, { entite = e, distance = math.sqrt((ici.x - henry.x) ^ 2 + (ici.y - henry.y) ^ 2) })
    end
  end
  table.sort(trouves, function(a, b) return a.distance < b.distance end)
  local rendus = {}
  for i = 1, math.min(combien, #trouves) do
    rendus[i] = trouves[i]
  end
  return rendus, #trouves
end

local function decrire_un_siege(e, distance)
  local sorte, aides = sorte_de(e)
  local p = type(e.Properties) == "table" and e.Properties or {}
  local nom_lu, nom = pcall(function() return e:GetName() end)
  local wuid_lu, wuid = pcall(function() return XGenAIModule.GetMyWUID(e) end)
  return string.format("« %s » à %.0f m : sorte %s, aides %s, type %s, WUID %s", nom_lu and tostring(nom) or "?",
    distance or -1, sorte, aides, tostring(p.guidSmartObjectType), wuid_lu and "lu" or ("refusé : " .. tostring(wuid)))
end

-- Relevé des propriétés complètes d'un objet du jeu (V65), pour écrire en données les sièges et les lits du camp
-- d'après des objets réels, jamais devinés. Rend une ligne « clé=valeur » par propriété, triées.
local function proprietes_a_plat(t, prefixe, lignes, profondeur)
  if profondeur > 4 or type(t) ~= "table" then
    return lignes
  end
  for cle, valeur in pairs(t) do
    local nom = prefixe .. tostring(cle)
    if type(valeur) == "table" then
      proprietes_a_plat(valeur, nom .. ".", lignes, profondeur + 1)
    else
      table.insert(lignes, nom .. "=" .. tostring(valeur))
    end
  end
  return lignes
end

liaison.aides_a_relever = { "Sit_1Place_Bench_Low", "Bed_1Place_Tent", "Bed_1Place_Low" }

-- Pour chaque sorte de points d'appui à relever : le plus proche objet du jeu, son cap, ses propriétés complètes ; et
-- pour le plus proche banc à deux places, l'écart et les caps de ses deux objets. Rend des lignes.
function liaison.relever_les_sieges()
  local lignes = {}
  local function cap_de(e)
    local lu, angles = pcall(function() return e:GetWorldAngles() end)
    return lu and type(angles) == "table" and string.format("%.0f", cap_depuis_moteur(angles.z or 0)) or "?"
  end
  for _, aides_voulues in ipairs(liaison.aides_a_relever) do
    local proches = plus_proches(function(e) return select(2, sorte_de(e)) == aides_voulues end, 1)
    local t = proches[1]
    if not t then
      table.insert(lignes, aides_voulues .. " : aucun")
    else
      local nom_lu, nom = pcall(function() return t.entite:GetName() end)
      table.insert(lignes, string.format("%s : « %s » à %.0f m, cap %s", aides_voulues, nom_lu and tostring(nom) or "?",
        t.distance, cap_de(t.entite)))
      local props = proprietes_a_plat(t.entite.Properties, "", {}, 1)
      table.sort(props)
      table.insert(lignes, "  " .. table.concat(props, " ; "))
    end
  end
  local bancs = plus_proches(function(e) return select(2, sorte_de(e)) == "Sit_1Place_Bench_Low" end, 40)
  for i = 1, #bancs do
    for j = i + 1, #bancs do
      local a, b = bancs[i].entite, bancs[j].entite
      local na_lu, na = pcall(function() return a:GetName() end)
      local nb_lu, nb = pcall(function() return b:GetName() end)
      if na_lu and nb_lu and na == nb then
        local pa, pb = a:GetWorldPos(), b:GetWorldPos()
        table.insert(lignes, string.format("banc à deux places « %s » : écart %.2f m (dz %.2f), caps %s et %s, du premier au second : %.0f°",
          tostring(na), math.sqrt((pa.x - pb.x) ^ 2 + (pa.y - pb.y) ^ 2), pb.z - pa.z, cap_de(a), cap_de(b),
          cap_depuis_moteur(math.atan2(-(pb.x - pa.x), pb.y - pa.y))))
        return lignes
      end
    end
  end
  table.insert(lignes, "banc à deux places : aucun parmi les 40 plus proches")
  return lignes
end

-- Les sortes d'objets à moins de 300 m d'Henry (nombre, la plus proche), puis les deux sièges et les deux lits les
-- plus proches. Rend des lignes.
function liaison.sonder_les_sieges()
  local lignes = {}
  local tous, total = plus_proches(nil, 100000)
  table.insert(lignes, "StanceSmartObject : " .. tostring(total) .. " dans le monde")
  local sortes, ordre = {}, {}
  for _, t in ipairs(tous) do
    if t.distance > 300 then break end
    local sorte, aides = sorte_de(t.entite)
    local cle = sorte .. " / " .. aides
    if not sortes[cle] then
      sortes[cle] = { nombre = 0, distance = t.distance }
      table.insert(ordre, cle)
    end
    sortes[cle].nombre = sortes[cle].nombre + 1
  end
  for i = 1, math.min(15, #ordre) do
    table.insert(lignes, string.format("  sorte %s : %d, la plus proche à %.0f m", ordre[i], sortes[ordre[i]].nombre, sortes[ordre[i]].distance))
  end
  for _, genre in ipairs({ "siege", "lit" }) do
    local proches, nombre = plus_proches(genres[genre], 2)
    table.insert(lignes, genre .. " : " .. tostring(nombre) .. " dans le monde")
    for _, t in ipairs(proches) do
      table.insert(lignes, "  " .. decrire_un_siege(t.entite, t.distance))
    end
  end
  return lignes
end

-- Pose près d'Henry une copie (mêmes propriétés) du plus proche siège ou lit du jeu. Rend une ligne.
function liaison.poser_un_siege(genre)
  local proches = plus_proches(genres[genre], 1)
  if #proches == 0 then
    return "poser : aucun " .. genre .. " dans le monde"
  end
  local modele = proches[1].entite
  local place = pres_d_henry(4, genre == "lit" and -3 or 3)
  local nom, erreur = faire_naitre("StanceSmartObject", "scriptorium_essai_" .. genre, place, liaison.cap_du_joueur(),
                                   copie_profonde(modele.Properties))
  if not nom then
    return "poser : " .. genre .. " refusé : " .. tostring(erreur)
  end
  liaison.sieges_d_essai[genre] = nom
  return "poser : copie de " .. decrire_un_siege(modele, proches[1].distance) .. " ; la copie : "
    .. decrire_un_siege(entite_nommee(nom), liaison.distance_a_henry(nom))
end

-- L'écart entre deux entités, ou nil.
local function ecart_entre(a, b)
  local lu, ecart = pcall(function()
    local ici, la = a:GetWorldPos(), b:GetWorldPos()
    return math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2 + (ici.z - la.z) ^ 2)
  end)
  return lu and ecart or nil
end

-- Donne à l'un de nos personnages le WUID de l'objet, puis l'activité (10 s'asseoir, 11 se coucher). Rend une ligne.
local function donner_la_place(entite, objet, libelle, ordre)
  local this_lu, this = pcall(function() return entite.this end)
  if not this_lu or type(this) ~= "table" then
    return "place : personnage sans this"
  end
  local wuid_lu, wuid = pcall(function() return XGenAIModule.GetMyWUID(objet) end)
  if not wuid_lu then
    return "place : WUID refusé : " .. tostring(wuid)
  end
  local pose = pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_siege", wuid) end)
  liaison.objet_vise = objet
  -- Fiche 18, 5 c : au poste de travail (ordre 21), le geste de ce poste, lu par l'arbre (liaison.geste_du_poste).
  if ordre == 21 then
    local lu_nom, nom = pcall(function() return entite:GetName() end)
    local lu_objet, nom_objet = pcall(function() return objet:GetName() end)
    if lu_nom and lu_objet then
      liaison.gestes[nom] = liaison.gestes_des_postes[nom_objet]
    end
  end
  return string.format("place : %s, %s ; WUID posé %s ; %s", libelle, decrire_un_siege(objet, ecart_entre(entite, objet)),
    tostring(pose), poser_l_activite(entite, ordre))
end

-- L'ordre 10 (s'asseoir) ou 11 (se coucher) : le marcheur reçoit le WUID de la copie posée (sauf « reel ») ou du plus
-- proche siège ou lit du jeu. Rend une ligne.
function liaison.ordonner_de_prendre_place(genre, ordre, reel)
  local marcheur = entite_nommee(liaison.marcheur)
  if not marcheur then
    return "place : marcheur introuvable"
  end
  local objet, origine = nil, "copie posée"
  if not reel then
    objet = entite_nommee(liaison.sieges_d_essai[genre])
  end
  if not objet then
    local proches = plus_proches(genres[genre], 1)
    objet, origine = proches[1] and proches[1].entite, "le plus proche du jeu"
  end
  if not objet then
    return "place : aucun " .. genre
  end
  return donner_la_place(marcheur, objet, genre .. " (" .. origine .. ")", ordre)
end

-- L'ordre 10 ou 11 sur une place du camp, désignée par l'identifiant de son objet du jeu, au personnage « qui » (le
-- marcheur s'il n'est pas donné). Rend une ligne.
function liaison.ordonner_sur_la_place(identifiant, ordre, qui)
  local personnage = entite_nommee(qui or liaison.marcheur)
  if not personnage then
    return "place du camp : « " .. tostring(qui or "marcheur") .. " » introuvable"
  end
  local objet = entite_nommee(identifiant)
  if not objet then
    return "place du camp : « " .. tostring(identifiant) .. " » introuvable"
  end
  return donner_la_place(personnage, objet, "place du camp", ordre)
end

-- La vie du camp (fiche 15, V73 a) : l'ordre devient un geste, plus de téléportation. Une place du camp (« place » :
-- l'identifiant de son objet du jeu, « sorte » : « siege » ou « lit ») se prend par l'ordre 10 ou 11 ; sinon l'homme
-- marche jusqu'à « position » (ordre 9, point posé dans son cerveau). Rend une ligne.
liaison.ordres_des_places = { siege = 10, lit = 11, poste = 21 }

-- Fiche 15, V73 d 1 : le dernier point de regard posé chez chaque personnage (pour le poste d'essai, qui dit l'écart
-- entre son cap et ce point). En mémoire seulement.
liaison.regards = liaison.regards or {}

-- Fiche 15, V73 d 2 : le dernier but posé chez chaque personnage (par l'ordre, ou par le pas de la ronde), pour le poste
-- d'essai, qui dit l'écart entre l'homme et ce but ; et ses pas de ronde. En mémoire seulement.
liaison.buts = liaison.buts or {}
liaison.pas_de_ronde_vus = liaison.pas_de_ronde_vus or {}
-- Fiche 15, V73 f 1 : le chef que suit chaque personnage (« henry » ou un identifiant), pour le poste d'essai.
liaison.chefs = liaison.chefs or {}
-- Fiche 15, V73 f 1 bis : le modèle de formation que mène chaque chef de formation, lu par son arbre (ordre 15).
liaison.formations_menees = liaison.formations_menees or {}

-- Appelée par l'arbre de la vie du camp (branche 15) sous pcall : écrit dans « formation_nom » le modèle que ce chef
-- mène ; une ligne au journal ; une erreur, au journal.
function liaison.nom_de_la_formation(entite, donnees)
  local fait, erreur = pcall(function()
    local nom = entite:GetName()
    local formation = liaison.formations_menees[nom]
    if formation then
      donnees.formation_nom = formation
    end
    liaison.journal("Formation de " .. tostring(nom) .. " : « " .. tostring(formation) .. " »")
  end)
  if not fait then
    liaison.journal("Formation : erreur : " .. tostring(erreur))
  end
end

-- « regard » (fiche 15, V73 d 1) : un point ; l'homme tient un poste (ordre 12) : il marche jusqu'à « position », puis
-- se tourne vers ce point et s'y tient. « allure » (V73 e) : « course » le fait courir jusqu'au poste (variable de
-- cerveau scriptorium_allure, 1 ; remise à 0 à chaque autre ordre de poste). « chef » (V73 f 1) : l'identifiant d'un
-- personnage, ou « henry » : l'homme le suit (son WUID dans scriptorium_chef, ordre 14). « suivi » (V73 f 1 bis) :
-- { mode = "mener", formation } : il ouvre la formation du moteur et suit son chef (ordre 15) ; { mode = "formation" } :
-- il se range dans la formation de son chef (ordre 16) ; { mode = "cheval", cheval } (V73 f 2 a) : il monte ce cheval
-- (son WUID dans scriptorium_cheval) et suit son chef en selle (ordre 17) ; un cheval introuvable : à pied (ordre 14).
-- V73 f 2 b : { mode = "cheval", cheval, role = "mener", formation } : il monte et mène la formation (ordre 18) ;
-- { mode = "cheval", cheval, role = "formation" } : il monte et se range dans la formation de son chef (ordre 19) ; un
-- cheval introuvable : le même rôle à pied (ordres 15, 16).
function liaison.ordonner(identifiant, activite, position, lieu, place, sorte, regard, allure, chef, suivi)
  local entite = entite_nommee(identifiant)
  local ligne
  liaison.regards[identifiant] = nil
  liaison.buts[identifiant] = nil
  liaison.chefs[identifiant] = nil
  liaison.points_menes[identifiant] = nil
  liaison.formations_menees[identifiant] = nil
  liaison.allures_relevees[identifiant] = nil
  if not entite then
    ligne = "introuvable"
  else
    local objet = place and entite_nommee(place)
    local ordre = sorte and liaison.ordres_des_places[sorte]
    if objet and ordre then
      ligne = donner_la_place(entite, objet, tostring(lieu), ordre)
    elseif activite == "attendre" then
      -- Fiche 15, V73 b 3 : la journée du socle coupée, l'homme qu'aucune règle ne tient attend où il est (activité 0).
      ligne = "attendre sur place ; " .. poser_l_activite(entite, 0)
    elseif activite == "suivre" and suivi and suivi.vers and position then
      -- Fiche 17, 4 b (la sonde du 17/10 : l'ordre 18 ne mène pas vers un objet du monde) : le chef de colonne mène vers
      -- un point. Le point posé dans le cerveau, la formation ouverte, puis l'ordre 20 (à cheval) ; sans cheval, il
      -- marche au point (ordre 9).
      local this_lu, this = pcall(function() return entite.this end)
      local point = liaison.au_sol(position)
      local pose = this_lu and type(this) == "table"
        and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_point", point) end)
      local monture = suivi.mode == "cheval" and entite_nommee(suivi.cheval)
      local monture_lue, wuid_monture = pcall(function() return XGenAIModule.GetMyWUID(monture) end)
      local en_selle = pose and monture and monture_lue and wuid_monture ~= nil
        and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_cheval", wuid_monture) end)
      if not pose then
        ligne = "colonne : point refusé, sans but"
      elseif en_selle then
        pcall(XGenAIModule.SetBrainVariable, this.id, "scriptorium_monte_approche_ms",
          math.floor(tonumber(suivi.approche_ms) or 0))
        liaison.points_menes[identifiant] = point
        liaison.formations_menees[identifiant] = suivi.formation
        ligne = string.format("monte « %s » et mène la formation « %s » vers (%.1f, %.1f) ; ", tostring(suivi.cheval),
          tostring(suivi.formation), point.x, point.y) .. poser_l_activite(entite, 20)
      else
        ligne = string.format("colonne à pied vers (%.1f, %.1f) ; ", point.x, point.y) .. poser_l_activite(entite, 9)
      end
    elseif activite == "suivre" and chef then
      -- Suivre (V73 f 1) : le WUID du chef dans le cerveau, puis l'ordre 14 (la fonction de suivi du jeu) ; un chef
      -- introuvable : une marche simple vers « position », s'il y en a une.
      local this_lu, this = pcall(function() return entite.this end)
      local cible = (chef == "henry") and player or entite_nommee(chef)
      local wuid_lu, wuid = pcall(function() return XGenAIModule.GetMyWUID(cible) end)
      local pose = this_lu and type(this) == "table" and cible ~= nil and wuid_lu and wuid ~= nil
        and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_chef", wuid) end)
      if pose then
        liaison.chefs[identifiant] = chef
        if suivi and suivi.mode == "mener" and suivi.formation then
          liaison.formations_menees[identifiant] = suivi.formation
          ligne = "mène la formation « " .. suivi.formation .. " » derrière « " .. tostring(chef) .. " » ; "
            .. poser_l_activite(entite, 15)
        elseif suivi and suivi.mode == "formation" then
          ligne = "se range dans la formation de « " .. tostring(chef) .. " » ; " .. poser_l_activite(entite, 16)
        elseif suivi and suivi.mode == "cheval" then
          local monture = entite_nommee(suivi.cheval)
          local monture_lue, wuid_monture = pcall(function() return XGenAIModule.GetMyWUID(monture) end)
          local en_selle = monture ~= nil and monture_lue and wuid_monture ~= nil
            and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_cheval", wuid_monture) end)
          -- V73 f 2 c : le temps de la marche jusqu'au cheval, ajouté par l'arbre au délai de la monte.
          if en_selle then
            local approche = math.floor(tonumber(suivi.approche_ms) or 0)
            pcall(XGenAIModule.SetBrainVariable, this.id, "scriptorium_monte_approche_ms", approche)
          end
          local menee = suivi.role == "mener" and suivi.formation or nil
          if menee then
            liaison.formations_menees[identifiant] = menee
          end
          if en_selle and menee then
            ligne = "monte « " .. tostring(suivi.cheval) .. " » et mène la formation « " .. menee .. " » derrière « "
              .. tostring(chef) .. " » ; " .. poser_l_activite(entite, 18)
          elseif en_selle and suivi.role == "formation" then
            ligne = "monte « " .. tostring(suivi.cheval) .. " » et se range dans la formation de « " .. tostring(chef)
              .. " » ; " .. poser_l_activite(entite, 19)
          elseif en_selle then
            ligne = "monte « " .. tostring(suivi.cheval) .. " » et suit « " .. tostring(chef) .. " » ; " .. poser_l_activite(entite, 17)
          elseif menee then
            ligne = "cheval « " .. tostring(suivi.cheval) .. " » introuvable, mène la formation « " .. menee .. " » à pied ; "
              .. poser_l_activite(entite, 15)
          elseif suivi.role == "formation" then
            ligne = "cheval « " .. tostring(suivi.cheval) .. " » introuvable, se range dans la formation de « "
              .. tostring(chef) .. " » à pied ; " .. poser_l_activite(entite, 16)
          else
            ligne = "cheval « " .. tostring(suivi.cheval) .. " » introuvable, suit « " .. tostring(chef) .. " » à pied ; "
              .. poser_l_activite(entite, 14)
          end
        else
          ligne = "suit « " .. tostring(chef) .. " » ; " .. poser_l_activite(entite, 14)
        end
      elseif position then
        local point = liaison.au_sol(position)
        local marche = this_lu and type(this) == "table"
          and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_point", point) end)
        ligne = "chef « " .. tostring(chef) .. " » introuvable, marche, point " .. (marche and "posé" or "refusé") .. " ; "
          .. poser_l_activite(entite, 9)
      else
        ligne = "chef « " .. tostring(chef) .. " » introuvable, sans but"
      end
    elseif activite == "parole" and liaison.paroles[identifiant] then
      -- Fiche 20 : la parole, sur place (ordre 23) : l'arbre la joue une fois.
      ligne = "parole ; " .. poser_l_activite(entite, 23)
    elseif not position then
      ligne = "sans but"
    elseif activite == "ronde" then
      -- La ronde (fiche 15, V73 d 2) : le premier point posé, puis l'activité 13 ; l'arbre appelle ensuite
      -- liaison.au_point_de_ronde à chaque point.
      local this_lu, this = pcall(function() return entite.this end)
      local point = liaison.au_sol(position)
      local pose = this_lu and type(this) == "table"
        and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_point", point) end)
      if pose then
        liaison.buts[identifiant] = point
        ligne = string.format("ronde, premier point posé (%.1f, %.1f) ; ", point.x, point.y) .. poser_l_activite(entite, 13)
      else
        ligne = "ronde refusée ; " .. poser_l_activite(entite, 9)
      end
    elseif activite == "geste" and liaison.gestes_tenus[identifiant] then
      -- Fiche 18, 5 c (la forge « pareil », principe transmis par le pair) : le geste tenu à un point : l'homme marche au
      -- point, se tourne vers le point regardé, puis tient le geste (une posture « unstance » du jeu ou de Scriptorium,
      -- par son nom, lu par l'arbre : liaison.geste_tenu) jusqu'au changement d'ordre (ordre 22).
      local this_lu, this = pcall(function() return entite.this end)
      local point = liaison.au_sol(position)
      local vers = regard and liaison.au_sol(regard) or point
      local pose = this_lu and type(this) == "table"
        and pcall(function()
          XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_point", point)
          XGenAIModule.SetBrainVariable(this.id, "scriptorium_regard", vers)
          XGenAIModule.SetBrainVariable(this.id, "scriptorium_allure", 0)
        end)
      -- L'objet d'ancrage (demande du pair, 18/10) : son WUID dans le cerveau, lu par l'arbre comme celui d'une place.
      local o = liaison.options_des_gestes[identifiant] or {}
      o.ancre_posee = false
      local objet = pose and o.ancre and entite_nommee(o.ancre)
      if objet then
        local lu, wuid = pcall(function() return XGenAIModule.GetMyWUID(objet) end)
        o.ancre_posee = lu and wuid ~= nil
          and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_siege", wuid) end) or false
      end
      if pose then
        liaison.regards[identifiant], liaison.buts[identifiant] = vers, point
        ligne = string.format("geste « %s », point posé (%.1f, %.1f) ; ", liaison.gestes_tenus[identifiant], point.x, point.y)
          .. (o.ancre and ("ancre « " .. tostring(o.ancre) .. " » " .. (o.ancre_posee and "posée" or "introuvable") .. " ; ") or "")
          .. poser_l_activite(entite, 22)
      else
        ligne = "geste refusé ; " .. poser_l_activite(entite, 9)
      end
    elseif regard then
      -- Tenir un poste : le poste et le point regardé posés d'abord, puis l'activité ; l'homme marche, et ne se tourne
      -- qu'une fois arrivé (relecture du pair : montré trop tôt, un homme glissait).
      local this_lu, this = pcall(function() return entite.this end)
      local point, vers = liaison.au_sol(position), liaison.au_sol(regard)
      local pose = this_lu and type(this) == "table"
        and pcall(function()
          XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_point", point)
          XGenAIModule.SetBrainVariable(this.id, "scriptorium_regard", vers)
          XGenAIModule.SetBrainVariable(this.id, "scriptorium_allure", allure == "course" and 1 or 0)
        end)
      if pose then
        liaison.regards[identifiant], liaison.buts[identifiant] = vers, point
        ligne = string.format("poste, point posé (%.1f, %.1f), regard posé (%.1f, %.1f)%s ; ", point.x, point.y, vers.x,
          vers.y, allure == "course" and ", en courant" or "") .. poser_l_activite(entite, 12)
      else
        ligne = "poste refusé ; " .. poser_l_activite(entite, 9)
      end
    else
      local this_lu, this = pcall(function() return entite.this end)
      local point = liaison.au_sol(position)
      local pose = this_lu and type(this) == "table"
        and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_point", point) end)
      if pose then
        liaison.buts[identifiant] = point
      end
      ligne = "marche, point " .. (pose and string.format("posé (%.1f, %.1f)", point.x, point.y) or "refusé") .. " ; "
        .. poser_l_activite(entite, 9)
    end
  end
  liaison.journal("Ordre à " .. tostring(identifiant) .. " : " .. activite .. " (" .. tostring(lieu) .. ") : " .. ligne)
  return ligne
end

-- La ronde (fiche 15, V73 d 2) : la fonction des hommes qui donne le pas suivant, confiée au démarrage (la liaison
-- n'appelle aucun morceau).
liaison.pas_de_ronde = liaison.pas_de_ronde

-- Fiche 18, 5 c, tranche 2 : les postes de travail du jeu. Un SmartObjectHolder (Scripts/Entities/WH/Others/
-- SmartObjectHolder.lua : un objet intelligent sans géométrie) porte le gabarit du poste (guidSmartObjectType, le
-- DatabaseId de Libs/Tables/ai/smartEntity/SmartEntity__<nom>.xml) ; l'arbre de la vie du camp (branche 21) y lance le
-- geste, un comportement nommé du gabarit (CallBehavior, comme AI/crime/mournOnBench.xml). En mémoire : le geste de
-- chaque poste posé, et celui donné à chaque personnage.
liaison.gestes_des_postes = liaison.gestes_des_postes or {}
liaison.gestes = liaison.gestes or {}

function liaison.poser_poste(nom, gabarit, position, cap, aides, geste)
  local proprietes = { guidSmartObjectType = gabarit, soclass_SmartObjectHelpers = aides or "", bSaved_by_game = false,
                       bOwnedByHome = false }
  local identifiant, raison = faire_naitre("SmartObjectHolder", "scriptorium_poste_" .. nom, liaison.au_sol(position), cap,
                                           proprietes)
  if not identifiant then
    liaison.journal("Poste de travail « " .. nom .. " » : pose impossible : " .. tostring(raison))
    return nil
  end
  liaison.gestes_des_postes[identifiant] = geste
  liaison.journal("Poste de travail « " .. nom .. " » posé : " .. identifiant .. " (gabarit " .. tostring(gabarit)
                  .. ", geste « " .. tostring(geste) .. " »)")
  return identifiant
end

-- Appelée par l'arbre de la vie du camp (branche 21) sous pcall, à chaque lancement du geste (l'arbre le relance quand
-- il finit, tant que l'ordre tient) : écrit dans « poste_geste » le geste du poste donné à ce personnage ; une ligne au
-- journal au premier lancement, puis aux relances 1 à 3 et toutes les 20 (pas d'inondation si un geste finit aussitôt) ;
-- une erreur, au journal.
liaison.lancements_des_gestes = {}

function liaison.geste_du_poste(entite, donnees)
  local fait, erreur = pcall(function()
    local nom = entite:GetName()
    local geste = liaison.gestes[nom] or "use"
    donnees.poste_geste = geste
    local deja = liaison.lancements_des_gestes[nom]
    local relances = (deja and deja.geste == geste) and deja.relances + 1 or 0
    liaison.lancements_des_gestes[nom] = { geste = geste, relances = relances }
    if relances == 0 then
      liaison.journal("Poste de travail : « " .. tostring(nom) .. " » lance le geste « " .. geste .. " »")
    elseif relances <= 3 or relances % 20 == 0 then
      liaison.journal("Poste de travail : « " .. tostring(nom) .. " » relance le geste « " .. geste .. " » ("
                      .. relances .. "e relance)")
    end
  end)
  if not fait then
    liaison.journal("Poste de travail : erreur : " .. tostring(erreur))
  end
end

-- Le relevé des postes du monde (outil d'essai, comme V65 pour les sièges) : les objets intelligents des classes qui
-- portent un gabarit (relevé dans Scripts.pak), dont le gabarit est dans « gabarits » ({ [identifiant en minuscules] =
-- genre }), à moins de « rayon » mètres d'Henry ; au plus « combien » lignes, du plus proche au plus loin. Rend le
-- nombre trouvé.
liaison.classes_des_postes = { "SmartObjectHolder", "GeomEntity", "AnimObject", "RigidBodyEx", "SO_ActionSettings",
                               "SmartObjectTrigger", "StanceSmartObject" }

function liaison.relever_les_postes(gabarits, rayon, combien)
  local henry = liaison.position_du_joueur()
  if not henry then
    return 0
  end
  local trouves = {}
  for _, classe in ipairs(liaison.classes_des_postes) do
    local ok, liste = pcall(System.GetEntitiesByClass, classe)
    for _, entite in ipairs((ok and type(liste) == "table") and liste or {}) do
      local lu, ligne = pcall(function()
        local p = entite.Properties or {}
        local genre = gabarits[string.lower(tostring(p.guidSmartObjectType))]
        if not genre then
          return nil
        end
        local ici = entite:GetWorldPos()
        local distance = math.sqrt((ici.x - henry.x) ^ 2 + (ici.y - henry.y) ^ 2)
        if distance > rayon then
          return nil
        end
        return { distance = distance, texte = string.format("Relevé des postes : %s, %s « %s », à %.1f m (%.1f, %.1f, %.1f) ; "
          .. "aides « %s », modèle « %s »", genre, classe, tostring(entite:GetName()), distance, ici.x, ici.y, ici.z,
          tostring(p.soclass_SmartObjectHelpers), tostring(p.object_Model or p.object_editorModel)) }
      end)
      if lu and ligne then
        table.insert(trouves, ligne)
      end
    end
  end
  table.sort(trouves, function(a, b) return a.distance < b.distance end)
  for i = 1, math.min(#trouves, combien or 30) do
    liaison.journal(trouves[i].texte)
  end
  liaison.journal("Relevé des postes : " .. #trouves .. " à moins de " .. rayon .. " m")
  return #trouves
end

-- Fiche 18, 5 c, la sonde de la forge (principe transmis par le pair le 17/10 : un préfabriqué né entier garde peut-être
-- ses liens imbriqués) : un préfabriqué du jeu (IPL_GameData.pak, Prefabs/…) né par la classe RuntimePrefab
-- (Scripts/Entities/Others/RuntimePrefab.lua : guidPrefabTemplate, Game.SpawnPrefab). Rend l'identifiant, ou nil.
function liaison.faire_naitre_un_prefabrique(nom, prefabrique, position, cap)
  local identifiant, raison = faire_naitre("RuntimePrefab", "scriptorium_prefab_" .. nom, liaison.au_sol(position), cap,
                                           { guidPrefabTemplate = prefabrique, nMaxSpawn = 0 })
  liaison.journal("Préfabriqué « " .. nom .. " » (" .. tostring(prefabrique) .. ") : " .. tostring(identifiant or raison))
  return identifiant
end

-- Donne à « qui » le plus proche objet intelligent du monde de ce gabarit (à moins de « rayon » mètres de lui), avec ce
-- geste (ordre 21). Rend une ligne.
function liaison.ordonner_au_poste_du_monde(qui, gabarit, geste, rayon)
  local personnage = entite_nommee(qui)
  if not personnage then
    return "poste du monde : « " .. tostring(qui) .. " » introuvable"
  end
  local ici = personnage:GetWorldPos()
  local choisi, plus_pres = nil, nil
  for _, classe in ipairs(liaison.classes_des_postes) do
    local ok, liste = pcall(System.GetEntitiesByClass, classe)
    for _, entite in ipairs((ok and type(liste) == "table") and liste or {}) do
      local lu, ecart = pcall(function()
        if string.lower(tostring((entite.Properties or {}).guidSmartObjectType)) ~= string.lower(gabarit) then
          return nil
        end
        local la = entite:GetWorldPos()
        return math.sqrt((la.x - ici.x) ^ 2 + (la.y - ici.y) ^ 2)
      end)
      if lu and ecart and ecart <= rayon and (plus_pres == nil or ecart < plus_pres) then
        choisi, plus_pres = entite, ecart
      end
    end
  end
  if not choisi then
    return "poste du monde : aucun objet du gabarit " .. gabarit .. " à moins de " .. rayon .. " m"
  end
  liaison.gestes_des_postes[choisi:GetName()] = geste
  return donner_la_place(personnage, choisi, "poste du monde (" .. string.format("%.1f", plus_pres) .. " m)", 21)
end

-- Fiche 20 : la parole donnée à un personnage (avant son ordre « parole ») : sa sorte (1 réplique, 2 conversation,
-- 3 dialogue vers Henry, 4 réplique en regardant Henry), son alias ou son metarole ; le partenaire d'une conversation,
-- par son WUID dans le cerveau (scriptorium_parole_partenaire). Lue par l'arbre (branche 23) sous pcall.
liaison.paroles = liaison.paroles or {}

function liaison.donner_la_parole(identifiant, sorte, alias, metarole, partenaire)
  liaison.paroles[identifiant] = { sorte = sorte, alias = alias or "", metarole = metarole or "" }
  if partenaire then
    local entite, autre = entite_nommee(identifiant), entite_nommee(partenaire)
    local ok, erreur = pcall(function()
      XGenAIModule.SetBrainVariable(entite.this.id, "scriptorium_parole_partenaire", XGenAIModule.GetMyWUID(autre))
    end)
    if not ok then
      liaison.journal("Parole : le partenaire de « " .. identifiant .. " » non posé : " .. tostring(erreur))
    end
  end
end

function liaison.parole_de(entite, donnees)
  local fait, erreur = pcall(function()
    local nom = entite:GetName()
    local p = liaison.paroles[nom]
    if p then
      donnees.parole_sorte, donnees.parole_alias, donnees.parole_metarole = p.sorte, p.alias, p.metarole
      liaison.journal("Parole : « " .. tostring(nom) .. " » dit « " .. (p.alias ~= "" and p.alias or p.metarole) .. " » (sorte "
                      .. tostring(p.sorte) .. ")")
    end
  end)
  if not fait then
    liaison.journal("Parole : erreur : " .. tostring(erreur))
  end
end

-- Fiche 18, 5 c : le geste tenu donné à un personnage (avant son ordre « geste ») ; lu par l'arbre (branche 22) sous
-- pcall, écrit dans « geste_nom » ; une ligne au journal ; une erreur, au journal.
liaison.gestes_tenus = liaison.gestes_tenus or {}

-- « options » (demande du pair, 18/10) : { ancre = nom de l'entité sur laquelle le geste se joue, assis = vrai pour
-- s'asseoir dessus d'abord, arme = vrai pour tenir l'arme à la main } ; l'arme est rangée quand l'ordre change (le
-- décorateur du jeu prend fin avec le geste).
liaison.options_des_gestes = liaison.options_des_gestes or {}

function liaison.donner_le_geste(identifiant, geste, options)
  liaison.gestes_tenus[identifiant] = geste
  liaison.options_des_gestes[identifiant] = options or {}
end

function liaison.geste_tenu(entite, donnees)
  local fait, erreur = pcall(function()
    local nom = entite:GetName()
    local geste = liaison.gestes_tenus[nom] or "LookingAround"
    local o = liaison.options_des_gestes[nom] or {}
    donnees.geste_nom = geste
    donnees.geste_ancre = o.ancre_posee and 1 or 0
    donnees.geste_assis = (o.ancre_posee and o.assis) and 1 or 0
    donnees.geste_arme = o.arme == true
    liaison.journal("Geste : « " .. tostring(nom) .. " » tient le geste « " .. geste .. " »"
                    .. (o.ancre_posee and (" sur « " .. tostring(o.ancre) .. " »" .. (o.assis and ", assis" or "")) or "")
                    .. (o.arme and ", l'arme à la main" or ""))
  end)
  if not fait then
    liaison.journal("Geste : erreur : " .. tostring(erreur))
  end
end

-- Fiche 18, 5 c, tranche 4 : le poste partagé avec Henry. Une station du jeu (Smithery, AlchemyTable… : leur GetActions
-- bâtit l'action « use » par Action()…:func(...), Scripts/Entities/WH/Minigames/Smithery.lua) : son GetActions est
-- enveloppé sur l'instance, et l'action « use » rebâtie avec le constructeur du jeu, sa fonction enveloppée : Henry
-- l'emploie, la station est dite prise (l'accroche des hommes), puis la fonction du jeu joue.
liaison.stations_surveillees = liaison.stations_surveillees or {}

function liaison.accrocher_la_station(fonction)
  liaison.station_prise = fonction
end

local function quand_henry_prend(station)
  if type(liaison.station_prise) ~= "function" then
    return
  end
  local ok, erreur = pcall(liaison.station_prise, station)
  if not ok then
    liaison.journal("Station : « " .. station .. " » : accroche en erreur : " .. tostring(erreur))
  end
end

local function rebatir_l_action(a, station)
  local fonction = a.func
  return Action():hint(a.hint):action(a.action):actionMap(a.actionMap):hintType(a.hintType):hintClass(a.hintClass)
    :enabled(a.enabled):reason(a.reason):disabledBarkMetarole(a.disabledBarkMetarole):uiOrder(a.uiOrder)
    :interaction(a.interactionName):uiVisible(a.uiVisible)
    :func(function(soi, qui, emplacement)
      if qui ~= nil and player ~= nil and (qui == player or qui.id == player.id) then
        quand_henry_prend(station)
      end
      return fonction(soi, qui, emplacement)
    end)
end

function liaison.partager_avec_henry(station, oui)
  local entite = entite_nommee(station)
  if not entite then
    return false
  end
  if not oui then
    if rawget(entite, "scriptorium_partage") then
      entite.GetActions = entite.scriptorium_actions_du_partage
      entite.scriptorium_partage, entite.scriptorium_actions_du_partage = nil, nil
    end
    return true
  end
  if rawget(entite, "scriptorium_partage") then
    return true
  end
  if type(Action) ~= "function" or type(AddInteractorAction) ~= "function" then
    liaison.journal("Station : Action ou AddInteractorAction absents : « " .. station .. " » pas surveillée")
    return false
  end
  local d_origine = rawget(entite, "GetActions")
  local origine = entite.GetActions
  entite.scriptorium_actions_du_partage = d_origine
  entite.scriptorium_partage = true
  entite.GetActions = function(soi, utilisateur, premier_seul)
    local sortie = (type(origine) == "function" and origine(soi, utilisateur, premier_seul)) or {}
    local ok, refaite = pcall(function()
      local liste = {}
      for _, a in ipairs(sortie) do
        if a.action == "use" and type(a.func) == "function" then
          AddInteractorAction(liste, false, rebatir_l_action(a, station))
        else
          table.insert(liste, a)
        end
      end
      return liste
    end)
    if ok then
      return refaite
    end
    if not soi.scriptorium_partage_en_erreur then
      soi.scriptorium_partage_en_erreur = true
      liaison.journal("Station : « " .. station .. " » : action non rebâtie : " .. tostring(refaite))
    end
    return sortie
  end
  liaison.journal("Station : « " .. station .. " » surveillée (partagée avec Henry)")
  return true
end

-- Henry a-t-il fini avec la station ? Vrai s'il s'en est éloigné de plus de « loin » mètres, ou si, « delai » secondes
-- au moins après la prise, il peut de nouveau lancer un mini-jeu (Minigame.CanUseMinigame, employée par les stations).
function liaison.henry_a_fini(station, depuis, delai, loin)
  local entite, henry = entite_nommee(station), liaison.position_du_joueur()
  if entite and henry then
    local lu, la = pcall(function() return entite:GetWorldPos() end)
    if lu and la and math.sqrt((la.x - henry.x) ^ 2 + (la.y - henry.y) ^ 2) > loin then
      return true
    end
  end
  if depuis and liaison.maintenant() - depuis < delai then
    return false
  end
  local ok, peut = pcall(function() return Minigame.CanUseMinigame(player.id) end)
  return ok and (peut == true or peut == 1)
end

-- Fiche 21 (les dialogues) : appelée par l'ExitScript d'un choix d'Henry dans nos arbres de dialogue, avec le nom de
-- l'arbre, le nom du choix et l'interlocuteur (dc['ROLE'] : une entité, ou son WUID). La fonction accrochée (les hommes)
-- rend { codes = { c1, c2, c3 }, colonel = vrai|faux } ; les codes vont dans les variables globales du jeu
-- (Variables.SetGlobal, comme Scripts/Systems/KCD1/Negotiation.lua du jeu), lues par les EntryCondition gvar(…) des
-- répliques ; 0 : rien à dire à cette place. Une erreur : au journal, et tous les codes à 0 (la réplique de repli).
liaison.variables_du_dialogue = { "scriptorium_dialogue_code_1", "scriptorium_dialogue_code_2",
                                  "scriptorium_dialogue_code_3" }
liaison.variable_du_colonel = "scriptorium_dialogue_colonel"

function liaison.accrocher_le_dialogue(fonction)
  liaison.reponse_du_dialogue = fonction
end

local function nom_de_l_interlocuteur(qui)
  local entite = qui
  if type(qui) ~= "table" then
    local ok, trouvee = pcall(function() return XGenAIModule.GetEntityByWUID(qui) end)
    entite = ok and trouvee or nil
  end
  local ok, nom = pcall(function() return entite:GetName() end)
  return ok and nom or nil
end

function liaison.dialogue_choix(arbre, choix, qui)
  local reponse = {}
  local ok, erreur = pcall(function()
    local nom = nom_de_l_interlocuteur(qui)
    if type(liaison.reponse_du_dialogue) == "function" then
      reponse = liaison.reponse_du_dialogue(tostring(arbre), tostring(choix), nom) or {}
    end
  end)
  if not ok then
    liaison.journal("Dialogue : « " .. tostring(arbre) .. "/" .. tostring(choix) .. " » en erreur : " .. tostring(erreur))
    reponse = {}
  end
  local codes = type(reponse.codes) == "table" and reponse.codes or {}
  local poses = {}
  for i, variable in ipairs(liaison.variables_du_dialogue) do
    local code = tonumber(codes[i]) or 0
    pcall(function() Variables.SetGlobal(variable, code) end)
    table.insert(poses, tostring(code))
  end
  pcall(function() Variables.SetGlobal(liaison.variable_du_colonel, reponse.colonel and 1 or 0) end)
  liaison.journal("Dialogue : « " .. tostring(arbre) .. "/" .. tostring(choix) .. " » : codes " .. table.concat(poses, ", ")
                  .. (reponse.colonel and " (colonel)" or ""))
end

-- Pour le poste d'essai (fiche 18, 5 c, tranche 4 ; la nuit, la station ne se vise pas à l'écran) : ce que fait le jeu
-- quand Henry appuie sur E devant une station : ses actions demandées (GetActions, donc notre enveloppe si elle est
-- partagée), puis l'action « use » exécutée pour Henry. Rend (vrai ou faux, une ligne).
function liaison.utiliser_la_station(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite or not player then
    return false, "introuvable"
  end
  local ok, sortie = pcall(function() return entite:GetActions(player, false) end)
  if not ok or type(sortie) ~= "table" then
    return false, "actions illisibles : " .. tostring(sortie)
  end
  local noms, use = {}, nil
  for _, a in ipairs(sortie) do
    table.insert(noms, tostring(a.action))
    if a.action == "use" and type(a.func) == "function" and not use then
      use = a
    end
  end
  if not use then
    return false, "pas d'action « use » parmi [" .. table.concat(noms, ", ") .. "]"
  end
  local fait, erreur = pcall(use.func, entite, player)
  return fait, "actions [" .. table.concat(noms, ", ") .. "], « use » exécutée = " .. tostring(fait)
         .. (fait and "" or (" : " .. tostring(erreur)))
end

-- Pour le poste d'essai (fiche 21) : ce que fait le jeu quand Henry appuie sur E devant un personnage : ses actions
-- demandées (GetActions), puis l'action « nom » (« talk » : Parler) exécutée pour Henry. Rend (vrai ou faux, une ligne).
function liaison.executer_l_action(identifiant, nom)
  local entite = entite_nommee(identifiant)
  if not entite or not player then
    return false, "introuvable"
  end
  local ok, sortie = pcall(function() return entite:GetActions(player, false) end)
  if not ok or type(sortie) ~= "table" then
    return false, "actions illisibles : " .. tostring(sortie)
  end
  local noms, voulue = {}, nil
  for _, a in ipairs(sortie) do
    table.insert(noms, tostring(a.action))
    if a.action == nom and type(a.func) == "function" and not voulue then
      voulue = a
    end
  end
  if not voulue then
    return false, "pas d'action « " .. tostring(nom) .. " » parmi [" .. table.concat(noms, ", ") .. "]"
  end
  local fait, erreur = pcall(voulue.func, entite, player)
  return fait, "actions [" .. table.concat(noms, ", ") .. "], « " .. nom .. " » exécutée = " .. tostring(fait)
         .. (fait and "" or (" : " .. tostring(erreur)))
end

-- Pour le poste d'essai (fiche 18, 5 b) : les actions qu'un personnage offre à Henry, demandées au jeu (sa fonction
-- GetActions), et s'il est en combat. Rend une ligne.
function liaison.actions_offertes(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite or not player then
    return "introuvable"
  end
  local ok, sortie = pcall(function() return entite:GetActions(player, false) end)
  if not ok then
    return "actions illisibles : " .. tostring(sortie)
  end
  local noms = {}
  for _, a in ipairs(type(sortie) == "table" and sortie or {}) do
    table.insert(noms, tostring(a.action))
  end
  local lu, combat = pcall(function() return entite.soul:IsInCombatMode() end)
  return "actions [" .. table.concat(noms, ", ") .. "], en combat = " .. tostring(lu and combat)
end

-- Pour le poste d'essai (fiche 18, 5 c, tranche 4) : les stations du jeu qu'Henry emploie (forge, table d'alchimie,
-- meule), à moins de « rayon » mètres de lui, de la plus proche à la plus loin. Rend la liste { nom, classe, distance }.
function liaison.stations_proches(rayon)
  local henry = liaison.position_du_joueur()
  local liste = {}
  if not henry then
    return liste
  end
  for _, classe in ipairs({ "Smithery", "AlchemyTable", "Grindstone" }) do
    local ok, entites = pcall(System.GetEntitiesByClass, classe)
    for _, entite in ipairs((ok and type(entites) == "table") and entites or {}) do
      local lu, la = pcall(function() return entite:GetWorldPos() end)
      if lu and la then
        local d = math.sqrt((la.x - henry.x) ^ 2 + (la.y - henry.y) ^ 2)
        if d <= rayon then
          table.insert(liste, { nom = entite:GetName(), classe = classe, distance = d })
        end
      end
    end
  end
  table.sort(liste, function(a, b) return a.distance < b.distance end)
  return liste
end

-- La position d'une entité du monde par son nom, ou nil.
function liaison.position_d_un_objet(nom)
  local entite = entite_nommee(nom)
  local lu, la = pcall(function() return entite:GetWorldPos() end)
  return (entite and lu and la) and { x = la.x, y = la.y, z = la.z } or nil
end

-- Fiche 18, 5 b : un personnage parlable. Le jeu ne met « Parler » (Scripts/Entities/AI/Shared/BasicAIActions.lua,
-- GetActions) que si un dialogue existe pour son âme ; le socle enveloppe GetActions sur l'instance de l'entité (jamais
-- la classe) et y ajoute « Parler » (Scripts/Utils/InteractorAction.lua : Action, AddInteractorAction ; interaction
-- inr_talk), qui appelle la fonction accrochée par les hommes avec l'identifiant du personnage. Une entité refaite au
-- chargement perd l'enveloppe : les hommes la reposent (sans effet si elle y est).
function liaison.accrocher_la_parole(fonction)
  liaison.parole = fonction
end

local function quand_on_parle(identifiant)
  if type(liaison.parole) ~= "function" then
    return
  end
  local ok, erreur = pcall(liaison.parole, identifiant)
  if not ok then
    liaison.journal("Parole : « " .. identifiant .. " » : accroche en erreur : " .. tostring(erreur))
  end
end

local function peut_parler(entite)
  local ok, oui = pcall(function()
    return entite.actor:IsDead() == false and entite.actor:IsUnconscious() == false and not entite.soul:IsInCombatMode()
  end)
  return ok and oui == true
end

function liaison.rendre_parlable(identifiant, oui)
  local entite = entite_nommee(identifiant)
  if not entite then
    return false
  end
  if not oui then
    if rawget(entite, "scriptorium_parlable") then
      entite.GetActions = entite.scriptorium_actions_d_origine
      entite.scriptorium_parlable, entite.scriptorium_actions_d_origine = nil, nil
      liaison.journal("Parole : « " .. identifiant .. " » n'est plus parlable")
    end
    return true
  end
  if rawget(entite, "scriptorium_parlable") then
    return true
  end
  if type(Action) ~= "function" or type(AddInteractorAction) ~= "function" or inr_talk == nil then
    liaison.journal("Parole : Action, AddInteractorAction ou inr_talk absents : « " .. identifiant .. " » pas parlable")
    return false
  end
  local d_origine = rawget(entite, "GetActions")
  local origine = entite.GetActions
  entite.scriptorium_actions_d_origine = d_origine
  entite.scriptorium_parlable = true
  entite.GetActions = function(soi, utilisateur, premier_seul)
    if not soi.scriptorium_parole_appelee then
      soi.scriptorium_parole_appelee = true
      liaison.journal("Parole : « " .. identifiant .. " » : le jeu demande ses actions (premier_seul = " .. tostring(premier_seul) .. ")")
    end
    local sortie = (type(origine) == "function" and origine(soi, utilisateur, premier_seul)) or {}
    local ok, erreur = pcall(function()
      if type(sortie) ~= "table" or (premier_seul and #sortie > 0) or not peut_parler(soi) then
        return
      end
      for _, a in ipairs(sortie) do
        if a.action == "talk" then return end
      end
      AddInteractorAction(sortie, premier_seul, Action():hint("@ui_hud_talk"):action("talk"):uiOrder(0)
        :func(function() quand_on_parle(identifiant) end):interaction(inr_talk):enabled(true))
    end)
    if not ok and not soi.scriptorium_parole_en_erreur then
      soi.scriptorium_parole_en_erreur = true
      liaison.journal("Parole : « " .. identifiant .. " » : « Parler » non ajouté : " .. tostring(erreur))
    end
    return sortie
  end
  liaison.journal("Parole : « " .. identifiant .. " » parlable")
  return true
end

function liaison.accrocher_la_ronde(fonction)
  liaison.pas_de_ronde = fonction
end

-- Appelée par l'arbre de la vie du camp (branche 13) à chaque point de la ronde, sous pcall dans l'arbre même
-- (relecture du pair : une erreur non attrapée casse la branche, et l'homme se fige). « entite » : le personnage qui
-- joue l'arbre ; « donnees » : les variables de l'arbre. Pose le point suivant et le point regardé dans son cerveau, et
-- écrit la pause dans « ronde_pause » (« 6000ms ») ; sans pas (homme inconnu, plus de ronde), rien : l'arbre garde sa
-- pause par défaut. Une ligne au journal par pas ; une erreur, écrite au journal.
function liaison.au_point_de_ronde(entite, donnees)
  local fait, erreur = pcall(function()
    local nom = entite:GetName()
    if not liaison.pas_de_ronde then
      liaison.journal("Ronde de " .. tostring(nom) .. " : aucune accroche des hommes")
      return
    end
    local pas, raison = liaison.pas_de_ronde(nom)
    if not pas then
      liaison.journal("Ronde de " .. tostring(nom) .. " : aucun pas (" .. tostring(raison) .. ")")
      return
    end
    local point, vers = liaison.au_sol(pas.point), liaison.au_sol(pas.regard)
    XGenAIModule.SetBrainVariable(entite.this.id, "scriptorium_essai_point", point)
    XGenAIModule.SetBrainVariable(entite.this.id, "scriptorium_regard", vers)
    donnees.ronde_pause = string.format("%dms", pas.pause_ms)
    liaison.buts[nom], liaison.regards[nom] = point, vers
    liaison.pas_de_ronde_vus[nom] = (liaison.pas_de_ronde_vus[nom] or 0) + 1
    liaison.journal(string.format("Ronde de %s : pas %d, au point %d (à %s m), vers le point %d (%.1f, %.1f), pause %d ms%s",
      nom, pas.pas, pas.ici, pas.ecart and string.format("%.1f", pas.ecart) or "?", pas.suivant, point.x, point.y,
      pas.pause_ms, pas.longue and " (longue)" or ""))
  end)
  if not fait then
    liaison.journal("Ronde : erreur au point : " .. tostring(erreur))
  end
end

-- Fiche 15, V73 f 2 f (principe d'Alex, transmis par le pair) : l'allure d'un cavalier qui se mène lui-même vers son
-- chef. La vitesse de **son chef** (celui qu'il suit : Henry, ou un homme) est mesurée par sa position : la distance
-- parcourue depuis le relevé précédent, divisée par le temps écoulé (System.GetCurrTime, la forme de
-- Scripts/Entities/Physics/AnimObject.lua ; sans horloge lisible, la cadence de l'arbre) ; deux relevés à moins de 0,15 s
-- gardent la vitesse d'avant. L'écart du cavalier à son chef corrige ; la règle est celle des hommes (accrochée). Écrit
-- « allure_code » pour l'arbre ; une ligne au journal seulement quand l'allure change.
liaison.allure_choisie = liaison.allure_choisie
liaison.vitesse_filtree = liaison.vitesse_filtree
liaison.allures_relevees = liaison.allures_relevees or {}
-- Fiche 17, 4 b : le point vers lequel un chef de colonne mène (ordre 20), par homme ; l'allure s'y règle comme sur un
-- chef immobile.
liaison.points_menes = liaison.points_menes or {}
-- V73 f 2 g (relecture du pair) : une mesure par homme suivi, partagée par tous ceux qui le suivent.
liaison.vitesses_des_chefs = liaison.vitesses_des_chefs or {}
liaison.noms_des_allures = { [-1] = "tenir", [0] = "pas", [1] = "course", [2] = "trot rapide", [3] = "galop" }

function liaison.accrocher_l_allure(fonction, filtre)
  liaison.allure_choisie = fonction
  liaison.vitesse_filtree = filtre
end

-- La vitesse d'un homme suivi (« chef » : « henry » ou un identifiant), à « la » maintenant : relevée au plus une fois
-- par 0,15 s, partagée ; le filtre des hommes écarte les sauts.
local function vitesse_du_chef(chef, la, maintenant, cadence)
  local v = liaison.vitesses_des_chefs[chef]
  if not v then
    liaison.vitesses_des_chefs[chef] = { t = maintenant, la = { x = la.x, y = la.y }, vitesse = 0 }
    return 0
  end
  local ecoule = (maintenant and v.t) and (maintenant - v.t) or cadence
  if ecoule >= 0.15 then
    local mesuree = ((la.x - v.la.x) ^ 2 + (la.y - v.la.y) ^ 2) ^ 0.5 / ecoule
    v.vitesse = liaison.vitesse_filtree and liaison.vitesse_filtree(mesuree, v.vitesse) or mesuree
    v.t, v.la = maintenant, { x = la.x, y = la.y }
  end
  return v.vitesse
end

function liaison.allure_vers_chef(entite, donnees)
  local fait, erreur = pcall(function()
    local nom = entite:GetName()
    local chef = liaison.chefs[nom]
    local point = liaison.points_menes[nom]
    local la = point or (chef and ((chef == "henry") and liaison.position_du_joueur() or liaison.position_du_personnage(chef)))
    local ici_lu, ici = pcall(function() return entite:GetWorldPos() end)
    if not la or not ici_lu or type(ici) ~= "table" or not liaison.allure_choisie then
      return
    end
    local horloge_lue, maintenant = pcall(function() return System.GetCurrTime() end)
    maintenant = horloge_lue and tonumber(maintenant) or nil
    local cadence = (tonumber(donnees and donnees.allure_cadence_ms) or 300) / 1000
    local vitesse = point and 0 or vitesse_du_chef(chef, la, maintenant, cadence)
    local memo = liaison.allures_relevees[nom] or {}
    liaison.allures_relevees[nom] = memo
    local ecart = ((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2) ^ 0.5
    local code, fond, correction, perdu = liaison.allure_choisie(vitesse, ecart, memo.fond, memo.correction, memo.code,
      memo.perdu)
    donnees.allure_code = code
    donnees.allure_perdu = perdu and 1 or 0
    if memo.code ~= code then
      liaison.journal(string.format("Allure de %s : %s (son chef à %.1f m/s, à %.1f m)", tostring(nom),
        liaison.noms_des_allures[code] or tostring(code), vitesse, ecart))
    end
    -- « perdu » ne sert qu'à qui suit un autre cavalier (un suiveur de formation) : rien au journal pour qui suit Henry
    -- (vu en jeu, V73 f 2 g : des lignes inutiles pour le chef de colonne et le cavalier seul).
    if (memo.perdu == true) ~= (perdu == true) and memo.code ~= nil and chef ~= "henry" then
      liaison.journal(string.format("Allure de %s : %s (à %.1f m de son chef)", tostring(nom),
        perdu and "sa place perdue" or "de retour dans le rang", ecart))
    end
    memo.code, memo.fond, memo.correction, memo.perdu = code, fond, correction, perdu == true
  end)
  if not fait then
    liaison.journal("Allure : erreur : " .. tostring(erreur))
  end
end

-- Fiche 15, V73 e (relecture du pair ; la règle de Scriptorium, `arrivee_des_recrues`) : Henry voit-il ce point ? Vrai si
-- le cosinus entre la direction de son regard (ses angles dans le monde) et la direction du point dépasse « seuil » ;
-- nil si rien n'est lisible (pas d'Henry).
function liaison.henry_voit(point, seuil)
  local lu, voit = pcall(function()
    local ici, angles = player:GetWorldPos(), player:GetWorldAngles()
    local cap = cap_depuis_moteur(angles.z)
    local dx, dy = point.x - ici.x, point.y - ici.y
    local jusqu_au_point = math.sqrt(dx ^ 2 + dy ^ 2)
    if jusqu_au_point < 0.1 then
      return true
    end
    return (dx * math.sin(math.rad(cap)) + dy * math.cos(math.rad(cap))) / jusqu_au_point > seuil
  end)
  if lu then
    return voit
  end
  return nil
end

-- L'écart, au sol, entre un personnage et le but de son ordre (fiche 15 : le secours de l'homme bloqué), ou nil.
function liaison.ecart_au_but(identifiant, but)
  local entite = entite_nommee(identifiant)
  if not entite or type(but) ~= "table" then
    return nil
  end
  local lu, ecart = pcall(function()
    local ici = entite:GetWorldPos()
    return math.sqrt((ici.x - but.x) ^ 2 + (ici.y - but.y) ^ 2)
  end)
  return lu and ecart or nil
end

-- Le secours d'un homme bloqué (fiche 15, réponse 1 de JoVenGer) : posé sur une place libre près de « position » (jamais
-- à moins d'un mètre d'un autre personnage). Rend une ligne.
function liaison.poser_en_secours(identifiant, position)
  local entite = entite_nommee(identifiant)
  if not entite or not position then
    return "introuvable ou sans but"
  end
  local place = place_libre(liaison.au_sol(position))
  if not place then
    return "aucune place libre près du but"
  end
  local ok, erreur = pcall(function() entite:SetWorldPos(place) end)
  return ok and string.format("posé en (%.1f, %.1f)", place.x, place.y) or ("refusé : " .. tostring(erreur))
end

-- Les contextes que posait le « use » du jeu autour d'un siège ou d'un lit (V73 c) ; notre propre posture (fiche 12,
-- V73 c 6) ne les pose plus : à 1, ils diraient qu'un « use » du jeu tient encore l'homme.
local CONTEXTES_DE_LA_POSTURE = { "activity_disableSchedulerLooping", "bench_disableSnooze" }

-- Les contextes qui disent un homme pris par le jeu, les mêmes que ceux du switch (AI/scriptorium/essai_ordres.xml,
-- comparés au banc) : en combat (posé par AI/npc/basic/switch/interrupt_attack.xml), en conversation (posé par
-- AI/speech/switchDialog.xml). Le switch ne relance pas la vie du camp pendant ce temps (fiche 12) ; le secours ne prend
-- pas un tel homme pour un homme bloqué (fiche 15, V73 b 1).
local CONTEXTES_OCCUPE = { { "combat", "crime_interruptAttack" }, { "conversation", "speech_switchDialogRunning" } }

-- Ce qui occupe un personnage d'après son âme : « combat », « conversation », ou nil (libre, ou rien de lisible).
function liaison.occupation_de(qui)
  local noms = {}
  for _, c in ipairs(CONTEXTES_OCCUPE) do
    table.insert(noms, c[2])
  end
  local lus = liaison.contextes_de(qui, noms)
  for _, c in ipairs(CONTEXTES_OCCUPE) do
    if lus[c[2]] then
      return c[1]
    end
  end
  return nil
end

-- Ce que devient l'un de nos personnages sur sa place : écart à l'objet, ses compteurs « assis » et « couchés »,
-- les approches réussies d'un siège ou d'un lit, l'activité et les ordres donnés par la liaison, le pouls du
-- comportement long, ses lancements par le switch, les arrivées de la marche, ses combats (ordre 8), les contextes du
-- « use » et ceux qui le disent occupé (combat, conversation : V73 b 1), et si l'objet de
-- la place se dit libre ou bloqué pour une posture (XGenAIModule.IsStanceAvailable et IsStanceBlocked, comme
-- Scripts/Entities/WH/Triggers/ActionTrigger.lua) : un siège qui ne se libère pas après le départ de l'homme le
-- réclamerait (V73 c 8) ; et deux valeurs du cerveau (garde, tour du switch), pour savoir après un chargement si
-- les valeurs gardées par la sauvegarde sont revenues saines (V73 c 9). Rend une ligne.
function liaison.voir_sur_la_place(qui, identifiant)
  local personnage = entite_nommee(qui)
  if not personnage then
    return "« " .. tostring(qui) .. " » introuvable"
  end
  local this_lu, this = pcall(function() return personnage.this end)
  local function variable(nom)
    if not this_lu or type(this) ~= "table" then return "?" end
    local ok, valeur = pcall(function() return XGenAIModule.GetBrainVariable(this.id, nom) end)
    return ok and tostring(valeur) or "?"
  end
  local objet = entite_nommee(identifiant)
  local ecart = objet and ecart_entre(personnage, objet)
  local ame_lue, ame = pcall(function() return personnage.Properties.guidSharedSoulId end)
  local siege_libre, siege_bloque = "?", "?"
  local wuid_lu, wuid = pcall(XGenAIModule.GetMyWUID, objet)
  if objet and wuid_lu and wuid then
    local libre_lu, libre = pcall(XGenAIModule.IsStanceAvailable, wuid)
    local bloque_lu, bloque = pcall(XGenAIModule.IsStanceBlocked, wuid)
    siege_libre = libre_lu and tostring(libre) or "?"
    siege_bloque = bloque_lu and tostring(bloque) or "?"
  end
  -- Les contextes de la posture, puis ceux qui disent l'homme occupé (V73 b 1 : la lecture « en combat »).
  local noms = {}
  for _, nom in ipairs(CONTEXTES_DE_LA_POSTURE) do
    table.insert(noms, nom)
  end
  for _, c in ipairs(CONTEXTES_OCCUPE) do
    table.insert(noms, c[2])
  end
  local lus = liaison.contextes_de(qui, noms)
  local contextes = {}
  for _, nom in ipairs(noms) do
    table.insert(contextes, nom .. "=" .. (lus[nom] == nil and "?" or (lus[nom] and "1" or "0")))
  end
  -- Fiche 15, V73 d 1 : son cap (ses angles dans le monde, comme cap_du_joueur) et, s'il tient un poste, l'écart entre
  -- ce cap et la direction du point qu'il doit regarder.
  local angles_lus, angles = pcall(function() return personnage:GetWorldAngles() end)
  local cap = angles_lus and type(angles) == "table" and type(angles.z) == "number" and cap_depuis_moteur(angles.z) or nil
  local regard, ecart_de_cap = liaison.regards[qui], nil
  local ici_lu, ici = pcall(function() return personnage:GetWorldPos() end)
  if cap and regard and ici_lu and type(ici) == "table" then
    local vers_le_regard = math.deg(math.atan2(regard.x - ici.x, regard.y - ici.y)) % 360
    ecart_de_cap = math.abs((cap - vers_le_regard + 180) % 360 - 180)
  end
  -- Fiche 15, V73 d 2 : l'écart au but de son ordre (le poste, le point de la ronde), et ses pas de ronde.
  local but, ecart_au_but = liaison.buts[qui], nil
  if but and ici_lu and type(ici) == "table" then
    ecart_au_but = math.sqrt((ici.x - but.x) ^ 2 + (ici.y - but.y) ^ 2)
  end
  -- Fiche 15, V73 f 1 : l'écart à son chef, s'il suit quelqu'un.
  local chef, ecart_au_chef = liaison.chefs[qui], nil
  local la = chef and ((chef == "henry") and liaison.position_du_joueur() or liaison.position_du_personnage(chef))
  if la and ici_lu and type(ici) == "table" then
    ecart_au_chef = math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2)
  end
  return string.format("à %s m de sa place (libre %s, bloquée %s) ; assis %s, couchés %s, approches %s, tours %s ; activité %s, ordres donnés %s, pouls %s, lancements %s, arrêts %s, arrivées %s, combats %s, fins de combat %s ; cap %s°, écart au regard %s°, en poste %s ; à %s m de son but, pas de ronde %s, à %s m de son chef, en selle %s, montes manquées %s ; cerveau garde %s ms, tour %s ms ; %s ; âme %s",
    ecart and string.format("%.2f", ecart) or "?", siege_libre, siege_bloque,
    variable("scriptorium_essai_assis"), variable("scriptorium_essai_couche"), variable("scriptorium_essai_approche"),
    variable("scriptorium_essai_vivant"),
    variable("scriptorium_activite"), variable("scriptorium_essai_numero"), variable("scriptorium_vie_pouls"),
    variable("scriptorium_essai_rejoint"), variable("scriptorium_vie_arrets"), variable("scriptorium_essai_arrive"),
    variable("scriptorium_essai_combats"), variable("scriptorium_fins_de_combat"),
    cap and string.format("%.0f", cap) or "?", ecart_de_cap and string.format("%.0f", ecart_de_cap) or "-",
    variable("scriptorium_en_poste"),
    ecart_au_but and string.format("%.2f", ecart_au_but) or "-", tostring(liaison.pas_de_ronde_vus[qui] or 0),
    ecart_au_chef and string.format("%.2f", ecart_au_chef) or "-", variable("scriptorium_en_selle"), variable("scriptorium_monte_manquee"),
    variable("scriptorium_cerveau_garde_ms"), variable("scriptorium_cerveau_tour_ms"), table.concat(contextes, " "),
    ame_lue and tostring(ame) or "?")
end

-- L'écart entre le marcheur et l'objet visé, ou nil.
function liaison.ecart_a_l_objet_vise()
  local marcheur = entite_nommee(liaison.marcheur)
  if not marcheur or not liaison.objet_vise then
    return nil
  end
  local lu, ecart = pcall(function()
    local ici, la = marcheur:GetWorldPos(), liaison.objet_vise:GetWorldPos()
    return math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2 + (ici.z - la.z) ^ 2)
  end)
  return lu and ecart or nil
end

-- La distance entre un personnage et Henry, ou nil.
function liaison.distance_a_henry(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite then
    return nil
  end
  local lu, ecart = pcall(function()
    local ici, henry = entite:GetWorldPos(), player:GetWorldPos()
    return math.sqrt((ici.x - henry.x) ^ 2 + (ici.y - henry.y) ^ 2)
  end)
  return lu and ecart or nil
end

-- Compare un de nos personnages et le personnage du jeu (classe NPC, pas à nous) le plus proche d'Henry. Rend des
-- lignes pour le journal.
function liaison.sonder_les_cerveaux(identifiant)
  local lignes = {}
  local notre = entite_nommee(identifiant)
  table.insert(lignes, "le nôtre (" .. tostring(identifiant) .. ") :")
  if notre then
    for _, ligne in ipairs(decrire_le_cerveau(notre)) do table.insert(lignes, "  " .. ligne) end
  else
    table.insert(lignes, "  introuvable")
  end
  local plus_proche, distance = habitant_le_plus_proche()
  if plus_proche then
    table.insert(lignes, string.format("celui du jeu, à %.0f m d'Henry :", distance))
    for _, ligne in ipairs(decrire_le_cerveau(plus_proche)) do table.insert(lignes, "  " .. ligne) end
  else
    table.insert(lignes, "aucun personnage du jeu à moins de 150 m d'Henry")
  end
  return lignes
end

-- Blesse un personnage (soul:DealDamage, comme l'aide de débogage du jeu Scripts/Debug/Quick.lua :
-- vie, endurance, puis rien et vrai). Rend vrai, ou faux et l'erreur.
function liaison.blesser(identifiant, points)
  local entite = entite_nommee(identifiant)
  if not entite or type(entite.soul) ~= "table" then
    return false, "personnage introuvable"
  end
  local ok, erreur = pcall(function() entite.soul:DealDamage(points, points, __null, true) end)
  return ok, (not ok) and tostring(erreur) or nil
end

-- Fiche 17 (relecture du pair, 17/10 : l'issue tranchée appliquée aux vrais personnages) : un blessé est mis à terre,
-- sa santé portée à « reste » par un coup du jeu (soul:DealDamage, comme « blesser ») ; vu en jeu le 17/10 : Jan, à
-- 4,7 de santé, était inconscient. Vrai si fait.
function liaison.mettre_a_terre(identifiant, reste)
  local entite = entite_nommee(identifiant)
  if not entite or type(entite.soul) ~= "table" or type(entite.actor) ~= "table" then
    return false, "personnage introuvable"
  end
  local ok, erreur = pcall(function()
    local sante = entite.actor:GetHealth()
    if type(sante) == "number" and sante > reste then
      entite.soul:DealDamage(sante - reste, sante - reste, __null, true)
    end
  end)
  return ok, (not ok) and tostring(erreur) or nil
end

-- La santé d'un personnage (actor:GetHealth), ou nil : pour le journal du combat (diagnostic du combat figé, 17/10).
function liaison.sante_de(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite or type(entite.actor) ~= "table" then
    return nil
  end
  local lu, sante = pcall(function() return entite.actor:GetHealth() end)
  return lu and tonumber(sante) or nil
end

-- Fiche 17 (vu en jeu le 17/10 : Jan, assommé au combat, ne remontait pas à cheval) : le personnage est-il inconscient ?
-- (actor:IsUnconscious, lu par la sonde du combat.) Vrai, faux, ou nil s'il ne se lit pas.
function liaison.personnage_inconscient(identifiant)
  local entite = entite_nommee(identifiant)
  if not entite or type(entite.actor) ~= "table" then
    return nil
  end
  local lu, inconscient = pcall(function() return entite.actor:IsUnconscious() end)
  if lu then
    return inconscient == true
  end
  return nil
end

-- V71 a (fiche 13) : l'équipement par le Lua, mesuré avant d'écrire les tables. Les appels de l'outil de combat du jeu
-- (Scripts/Debug/CombatDebug.lua : actor:EquipClothingPreset, actor:EquipWeaponPreset) sur l'un de nos hommes, hors
-- -devmode ; et ce qu'ils donnent, compté par inventory:GetCountOfClass (Scripts/Utils/ItemUtils.lua). Préréglages et
-- objets relevés dans Tables.pak (clothing_preset.xml, weapon_preset.xml, item.xml).
liaison.sonde_d_equipement = {
  tenues = {
    { nom = "soldier_generic_1_01", id = "9c2ff51e-e487-4455-974a-c5933ae0e452",
      pieces = { "45b6d780-23e1-4a89-a0b1-dbc234a7ce21", "d4ade1cb-79dd-41a7-8d72-7bd88ec2e0d4", "ffd9af7c-d24d-4e70-8c25-ad22a37a64e7",
                 "62183c25-a930-4044-8e08-243c5d46c6cc", "8ec8f99a-57a7-4006-bb61-1f737996a0a9", "81e27f41-709f-47c8-96b3-8f8c9619d2fa" } },
    { nom = "soldier_generic_5_01", id = "dcd55b1c-00f1-487f-a8b5-c271a6e36af5",
      pieces = { "a79e8354-4706-4dde-bec3-51e1d88bf699", "808101ad-28ff-4425-ad2a-5fbe4f9fbbbe", "f9be9c8b-de15-4216-bf0d-7e71d25c0b84",
                 "3a1811fb-124e-4dbd-95ee-114debe21091", "9c6aac7c-4797-4aa9-a297-939fd5e5a54e", "260ccafb-0504-4c17-9833-304539d30698",
                 "0aba49a1-bffe-460b-bcc0-781654d79ac1", "63eff267-424a-43fd-a5ec-132c89c286f0", "403db8bc-649a-4b10-9385-01275b96f141",
                 "9da82290-e31b-4ba6-b0e8-680081e06e9a", "43f25763-bdbd-4e22-a946-722e2fd156c4" } },
  },
  armes = { nom = "sword_shield_3_01", id = "9bb17a1a-8691-4b0b-8443-c7bc6210bb5b",
            epee = "efa237c7-3905-4813-b9c3-a32b449c17ad",       -- shortswordCommon, « Épée militaire »
            bouclier = "401266f6-ffb4-4ad0-a8e1-4a3cb3edab3e" },  -- shieldHeater_whole_T, « Écu »
}

-- Ce que l'inventaire et l'acteur d'un de nos personnages savent faire (de quoi bâtir le filet du rechargement). Rend
-- des lignes.
function liaison.sonder_l_inventaire(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return { "« " .. tostring(qui) .. " » introuvable" }
  end
  local acteur = {}
  for _, nom in ipairs(fonctions_de(entite.actor)) do
    if string.find(nom, "Equip") or string.find(nom, "Cloth") or string.find(nom, "Dress") or string.find(nom, "Item")
       or string.find(nom, "Weapon") or string.find(nom, "Inventor") then
      table.insert(acteur, nom)
    end
  end
  return { "inventaire : " .. table.concat(fonctions_de(entite.inventory), ", "),
           "acteur (équipement) : " .. table.concat(acteur, ", ") }
end

-- Le compte des objets de la sonde dans l'inventaire du personnage. Rend une ligne.
function liaison.compter_l_equipement(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return "« " .. tostring(qui) .. " » introuvable"
  end
  local function compte(id)
    local ok, n = pcall(function() return entite.inventory:GetCountOfClass(id) end)
    return ok and tonumber(n) or nil
  end
  local function pieces(liste)
    local total, lues = 0, 0
    for _, id in ipairs(liste) do
      local n = compte(id)
      if n then
        total, lues = total + n, lues + 1
      end
    end
    return string.format("%d (sur %d pièces lues)", total, lues)
  end
  local s = liaison.sonde_d_equipement
  return string.format("tenue 1 %s ; tenue 2 %s ; épée %s ; écu %s", pieces(s.tenues[1].pieces), pieces(s.tenues[2].pieces),
    tostring(compte(s.armes.epee)), tostring(compte(s.armes.bouclier)))
end

-- Pose sur le personnage la tenue 1 ou 2, ou les armes, de la sonde ; puis compte. Rend une ligne.
function liaison.equiper_la_sonde(qui, quoi)
  local entite = entite_nommee(qui)
  if not entite then
    return "« " .. tostring(qui) .. " » introuvable"
  end
  local s = liaison.sonde_d_equipement
  local ok, erreur, nom
  if quoi == "armes" then
    nom = s.armes.nom
    ok, erreur = pcall(function() entite.actor:EquipWeaponPreset(s.armes.id) end)
  else
    local tenue = s.tenues[quoi == "tenue_2" and 2 or 1]
    nom = tenue.nom
    ok, erreur = pcall(function() entite.actor:EquipClothingPreset(tenue.id) end)
  end
  return nom .. " : " .. (ok and "accepté" or ("refusé : " .. tostring(erreur))) .. " ; " .. liaison.compter_l_equipement(qui)
end

-- V71 a2 (fiche 13) : pourquoi l'équipement posé n'est pas gardé au rechargement. Deux sondes à côté du premier homme
-- (le témoin), chacune différente de lui sur un seul point : « seule », née avec l'âme pour seule propriété ;
-- « hors_regles », née comme lui sur une âme que seule la règle Storm par défaut vise (faction animalCompanions,
-- classe 63). Leurs âmes sont des âmes d'essai de notre table (copies de scriptorium_combattant_1_01).
liaison.ames_de_la_sonde = {
  seule = "58a3065f-3817-414f-b5d6-59e160a700e8",        -- scriptorium_essai_sonde_seule
  hors_regles = "4a509f20-d52c-4eb8-bc89-771560f87728",  -- scriptorium_essai_sonde_hors_regles
}
liaison.noms_de_la_sonde = { seule = "scriptorium_sonde_seule", hors_regles = "scriptorium_sonde_hors_regles" }

-- Fait naître les deux sondes à 2 et 4 m du témoin (une seule fois : déjà nées, elles ne renaissent pas). Rend des lignes.
function liaison.faire_naitre_la_sonde(temoin)
  local entite = entite_nommee(temoin)
  local ok, ici = pcall(function() return entite:GetWorldPos() end)
  if not entite or not ok or type(ici) ~= "table" then
    return { "témoin « " .. tostring(temoin) .. " » introuvable" }
  end
  local lignes = {}
  for i, sorte in ipairs({ "seule", "hors_regles" }) do
    local nom = liaison.noms_de_la_sonde[sorte]
    if entite_nommee(nom) then
      table.insert(lignes, nom .. " : déjà née")
    else
      local place = liaison.au_sol({ x = ici.x + 2 * i, y = ici.y, z = ici.z })
      local ne, raison = faire_naitre("NPC", nom, place, 0, { guidSharedSoulId = liaison.ames_de_la_sonde[sorte] },
                                     sorte == "seule")
      if ne then
        liaison.eveiller(ne, ne)
      end
      table.insert(lignes, nom .. " : " .. (ne and ("née (" .. ne .. ")") or ("refusée : " .. tostring(raison))))
    end
  end
  return lignes
end

-- Ce que rendent l'inventaire et le gestionnaire d'objets du jeu pour les pièces portées (de quoi reposer chaque pièce
-- avec son état, s'il le faut). Rend des lignes.
function liaison.sonder_les_objets(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return { "« " .. tostring(qui) .. " » introuvable" }
  end
  local lignes = { "ItemManager : " .. table.concat(fonctions_de(ItemManager), ", ") }
  local ok, liste = pcall(function() return entite.inventory:GetInventoryTable() end)
  if not ok or type(liste) ~= "table" then
    table.insert(lignes, "GetInventoryTable : " .. tostring(liste))
    return lignes
  end
  local vus = 0
  for cle, valeur in pairs(liste) do
    vus = vus + 1
    if vus <= 3 then
      local champs = {}
      if type(valeur) == "table" then
        for k, v in pairs(valeur) do
          table.insert(champs, tostring(k) .. "=" .. tostring(v))
        end
      end
      local lu, objet = pcall(function() return ItemManager.GetItem(valeur) end)
      local du_jeu = {}
      if lu and type(objet) == "table" then
        for k, v in pairs(objet) do
          table.insert(du_jeu, tostring(k) .. "=" .. tostring(v))
        end
      end
      table.insert(lignes, string.format("objet %s : %s (%s) ; GetItem : %s", tostring(cle), tostring(valeur),
        table.concat(champs, ", "),
        lu and (type(objet) == "table" and table.concat(du_jeu, ", ") or tostring(objet)) or ("erreur " .. tostring(objet))))
    end
  end
  table.insert(lignes, "GetInventoryTable : " .. vus .. " entrée(s)")
  return lignes
end

-- V71 a3 (fiche 13) : les deux axes que V71 a2 n'a pas fait varier. (1) Objet par objet, à la façon du jeu
-- (Scripts/Utils/ItemUtils.lua, CreateInvItem ; player.lua, CheatGiveSword) : inventory:CreateItem(objet, état, nombre),
-- inventory:FindItem(objet), actor:EquipInventoryItem(id), avec un état choisi pour le relire après le rechargement.
-- (2) Un habitant du jeu habillé par le préréglage de V71 a, son nom gardé dans un jeton de la sauvegarde.
liaison.sonde_objet_par_objet = {
  { nom = "épée militaire", objet = "efa237c7-3905-4813-b9c3-a32b449c17ad", etat = 0.55, porter = true },
  { nom = "écu", objet = "401266f6-ffb4-4ad0-a8e1-4a3cb3edab3e", etat = 0.45, porter = false },
  { nom = "pièce 1 de soldier_generic_1_01", objet = "45b6d780-23e1-4a89-a0b1-dbc234a7ce21", etat = 0.35, porter = true },
}
liaison.jeton_de_l_habitant_sonde = "scriptorium_socle.essai_habitant_sonde"

-- L'état de chaque objet de la sonde chez ce personnage : nombre, et état du premier trouvé. Rend des lignes.
local function etat_des_objets(entite)
  local lignes = {}
  for _, o in ipairs(liaison.sonde_objet_par_objet) do
    local _, nombre = pcall(function() return entite.inventory:GetCountOfClass(o.objet) end)
    local _, id = pcall(function() return entite.inventory:FindItem(o.objet) end)
    local lu, objet = pcall(function() return ItemManager.GetItem(id) end)
    local etat = (lu and type(objet) == "table") and tostring(objet.health) or "?"
    table.insert(lignes, string.format("%s : %s, état %s (voulu %.2f)", o.nom, tostring(nombre), etat, o.etat))
  end
  return lignes
end

function liaison.creer_les_objets_de_la_sonde(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return { "« " .. tostring(qui) .. " » introuvable" }
  end
  local lignes = { "ItemManager.CreateItem : " .. type(ItemManager.CreateItem) .. ", inventory.CreateItem : "
                   .. type(entite.inventory.CreateItem) }
  for _, o in ipairs(liaison.sonde_objet_par_objet) do
    local cree, erreur = pcall(function() entite.inventory:CreateItem(o.objet, o.etat, 1) end)
    local trouve, id = pcall(function() return entite.inventory:FindItem(o.objet) end)
    local porte = "non demandé"
    if o.porter and trouve and id then
      local ok, e = pcall(function() return entite.actor:EquipInventoryItem(id) end)
      porte = ok and ("accepté (" .. tostring(e) .. ")") or ("refusé : " .. tostring(e))
    end
    table.insert(lignes, string.format("%s : créé %s, trouvé %s, porté %s", o.nom,
      cree and "oui" or ("non : " .. tostring(erreur)), trouve and tostring(id) or "non", porte))
  end
  for _, ligne in ipairs(etat_des_objets(entite)) do
    table.insert(lignes, ligne)
  end
  return lignes
end

function liaison.relire_les_objets_de_la_sonde(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return { "« " .. tostring(qui) .. " » introuvable" }
  end
  return etat_des_objets(entite)
end

-- L'habitant du jeu le plus proche d'Henry (hors des nôtres) reçoit la tenue lourde de la sonde ; son nom va au jeton.
function liaison.habiller_un_habitant()
  local habitant, distance = habitant_le_plus_proche()
  if not habitant or string.lower(string.sub(habitant:GetName(), 1, 12)) == "scriptorium_" then
    return "aucun habitant du jeu à moins de 150 m"
  end
  local nom = habitant:GetName()
  local ecrit, erreur = pcall(poser_un_jeton, liaison.jeton_de_l_habitant_sonde, nom)
  local ligne = string.format("%s à %.0f m (jeton %s) : %s", nom, distance or -1,
    ecrit and "écrit" or ("refusé : " .. tostring(erreur)), liaison.equiper_la_sonde(nom, "tenue_2"))
  return ligne
end

function liaison.compter_l_habitant()
  local nom = jeton(liaison.jeton_de_l_habitant_sonde)
  if not nom then
    return "pas de jeton d'habitant"
  end
  return nom .. " : " .. liaison.compter_l_equipement(nom)
end

-- V71 a4 (fiche 13) : ce que le témoin porte après un, puis deux rechargements. Toute la tenue lourde de la sonde
-- (soldier_generic_5_01), son épée et son écu créés un à un à l'état 0,6 et portés ; la tenue de naissance
-- s'empile-t-elle à chaque chargement ; nos pièces refaites porter.
liaison.etat_de_la_sonde_a4 = 0.6

local function pieces_de_la_sonde_a4()
  local s = liaison.sonde_d_equipement
  local liste = {}
  for _, id in ipairs(s.tenues[2].pieces) do
    table.insert(liste, id)
  end
  table.insert(liste, s.armes.epee)
  table.insert(liste, s.armes.bouclier)
  return liste
end

-- Les objets de l'inventaire en deux listes d'identifiants : les nôtres (objet de la sonde à l'état 0,6) et les autres.
local function trier_l_inventaire(entite)
  local a_nous = {}
  for _, id in ipairs(pieces_de_la_sonde_a4()) do
    a_nous[string.lower(id)] = true
  end
  local notres, autres = {}, {}
  local ok, liste = pcall(function() return entite.inventory:GetInventoryTable() end)
  if not ok or type(liste) ~= "table" then
    return notres, autres
  end
  for _, id in pairs(liste) do
    local lu, objet = pcall(function() return ItemManager.GetItem(id) end)
    if lu and type(objet) == "table" and a_nous[string.lower(tostring(objet.class))]
       and math.abs((tonumber(objet.health) or -1) - liaison.etat_de_la_sonde_a4) < 0.001 then
      table.insert(notres, id)
    else
      table.insert(autres, id)
    end
  end
  return notres, autres
end

-- Fait porter au personnage chacune de nos pièces. Rend le nombre de pièces acceptées et le nombre de pièces.
function liaison.faire_porter_la_sonde(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return 0, 0
  end
  local notres = trier_l_inventaire(entite)
  local portes = 0
  for _, id in ipairs(notres) do
    if pcall(function() entite.actor:EquipInventoryItem(id) end) then
      portes = portes + 1
    end
  end
  return portes, #notres
end

function liaison.armer_le_temoin(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return "« " .. tostring(qui) .. " » introuvable"
  end
  local crees = 0
  for _, objet in ipairs(pieces_de_la_sonde_a4()) do
    if pcall(function() entite.inventory:CreateItem(objet, liaison.etat_de_la_sonde_a4, 1) end) then
      crees = crees + 1
    end
  end
  local portes, notres = liaison.faire_porter_la_sonde(qui)
  return string.format("%d pièce(s) créée(s) sur %d, %d portée(s) sur %d trouvée(s) ; %s", crees, #pieces_de_la_sonde_a4(),
    portes, notres, liaison.voir_le_temoin(qui))
end

function liaison.voir_le_temoin(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return "« " .. tostring(qui) .. " » introuvable"
  end
  local notres, autres = trier_l_inventaire(entite)
  return string.format("inventaire : %d objet(s), dont %d à nous (état 0,6) et %d autre(s)", #notres + #autres, #notres, #autres)
end

-- Pose le personnage à 3 m devant Henry, face à lui (on déplace l'homme, jamais Henry : V67).
function liaison.poser_devant_henry(qui)
  local entite = entite_nommee(qui)
  local ok, angles = pcall(function() return player:GetWorldAngles() end)
  if not entite or not ok or type(angles) ~= "table" or type(angles.z) ~= "number" then
    return "« " .. tostring(qui) .. " » ou Henry introuvable"
  end
  local henry = liaison.position_du_joueur()
  local a = angles.z
  local place = place_libre(liaison.au_sol({ x = henry.x - 3 * math.sin(a), y = henry.y + 3 * math.cos(a), z = henry.z }))
  if not place then
    return "refusé : place prise, et aucune place libre à côté"
  end
  local pose, erreur = pcall(function()
    entite:SetWorldPos(place)
    entite:SetWorldAngles({ x = 0, y = 0, z = a + math.pi })
  end)
  return pose and "posé à 3 m devant Henry" or ("refusé : " .. tostring(erreur))
end

-- V72 (fiche 14) : le point à « devant » m devant Henry, dans le repère de poser_devant_henry (Henry regarde vers
-- (-sin a, cos a), a = angle z de ses angles du monde, en radians).
function liaison.point_devant_henry(devant)
  local ok, angles = pcall(function() return player:GetWorldAngles() end)
  if not ok or type(angles) ~= "table" or type(angles.z) ~= "number" then
    return nil
  end
  local henry = liaison.position_du_joueur()
  return { x = henry.x - devant * math.sin(angles.z), y = henry.y + devant * math.cos(angles.z), z = henry.z }
end

-- Pose le personnage à « devant » m devant Henry et « a_droite » m sur sa droite, tourné vers le point « vers » (vers
-- Henry si nil). On déplace le personnage, jamais Henry (V67).
function liaison.poser_pres_d_henry(qui, devant, a_droite, vers)
  local entite = entite_nommee(qui)
  local ok, angles = pcall(function() return player:GetWorldAngles() end)
  if not entite or not ok or type(angles) ~= "table" or type(angles.z) ~= "number" then
    return "« " .. tostring(qui) .. " » ou Henry introuvable"
  end
  local henry = liaison.position_du_joueur()
  local a = angles.z
  local place = place_libre(liaison.au_sol({ x = henry.x - devant * math.sin(a) + a_droite * math.cos(a),
                                           y = henry.y + devant * math.cos(a) + a_droite * math.sin(a), z = henry.z }))
  if not place then
    return "refusé : place prise, et aucune place libre à côté"
  end
  local cible = vers or henry
  local regard = math.atan2(place.x - cible.x, cible.y - place.y)
  local pose, erreur = pcall(function()
    entite:SetWorldPos(place)
    entite:SetWorldAngles({ x = 0, y = 0, z = regard })
  end)
  return pose and string.format("posé à %.1f m devant Henry, %.1f m sur sa droite", devant, a_droite)
    or ("refusé : " .. tostring(erreur))
end

-- Le nom de la faction d'un personnage, ou nil : soul:GetFactionID() rend le nom (vu en V72 a sur le brigand du jeu) ;
-- AI.GetFactionOf(id) rend nil hors -devmode (V72 a).
function liaison.faction_de(qui)
  local entite = entite_nommee(qui)
  if not entite or type(entite.soul) ~= "table" then
    return nil
  end
  local ok, nom = pcall(function() return entite.soul:GetFactionID() end)
  return ok and nom or nil
end

-- Les contextes de script de son âme (soul:HasScriptContext, Scripts/Entities/actor/BasicActor.lua) : { nom = vrai ou
-- faux } ; un nom dont la lecture est refusée n'a pas de clé.
function liaison.contextes_de(qui, noms)
  local entite = entite_nommee(qui)
  local rendu = {}
  if not entite or type(entite.soul) ~= "table" then
    return rendu
  end
  for _, nom in ipairs(noms) do
    local ok, oui = pcall(function() return entite.soul:HasScriptContext(nom) end)
    if ok then
      rendu[nom] = oui == true or oui == 1
    end
  end
  return rendu
end

-- La position d'un personnage, en texte « x, y », ou nil (V72 b : au prochain écran noir, les positions).
-- Fiche 15, V73 f 1 : la position d'un personnage, en point du monde, ou nil.
function liaison.position_du_personnage(qui)
  local entite = entite_nommee(qui)
  local ok, ou = pcall(function() return entite:GetWorldPos() end)
  if ok and type(ou) == "table" and type(ou.x) == "number" then
    return { x = ou.x, y = ou.y, z = ou.z }
  end
  return nil
end

function liaison.position_de(qui)
  local entite = entite_nommee(qui)
  local ok, ou = pcall(function() return entite:GetWorldPos() end)
  return ok and type(ou) == "table" and string.format("%.1f, %.1f", ou.x, ou.y) or nil
end

-- Le vrai habitant le plus proche (pas un figurant), nommé sans être touché : nom, distance, faction, classe sociale.
-- Pour regarder qui serait frappé avant le coup (V72 b : pas un garde).
function liaison.qui_serait_frappe()
  local habitant, distance = habitant_le_plus_proche(true)
  if not habitant then
    return "aucun vrai habitant du jeu à moins de 600 m d'Henry"
  end
  local nom = habitant:GetName()
  return string.format("« %s » à %.0f m, faction %s, classe %s", nom, distance or -1, tostring(liaison.faction_de(nom)),
    tostring(classe_sociale(habitant)))
end

-- La santé d'un personnage, ou nil.
function liaison.sante_de(qui)
  local entite = entite_nommee(qui)
  local ok, vie = pcall(function() return entite.actor:GetHealth() end)
  return ok and tonumber(vie) or nil
end

-- Le délit d'Henry (fiche 14, réponses 4 a et « refaire autrement » de JoVenGer, V72 b) : le vrai habitant du jeu le
-- plus proche (pas un figurant), posé à « devant » m devant Henry, face à lui, et frappé dans le même appel par les
-- règles du jeu (V43, sans clic) ; sa santé avant et juste après. Son nom va à liaison.habitant_frappe
-- (voir_l_habitant_frappe le suit).
function liaison.frapper_un_vrai_habitant(devant, points)
  local habitant, distance = habitant_le_plus_proche(true)
  if not habitant then
    return "aucun vrai habitant du jeu à moins de 600 m d'Henry"
  end
  local nom = habitant:GetName()
  liaison.habitant_frappe = nom
  local avant = liaison.sante_de(nom)
  local pose = liaison.poser_pres_d_henry(nom, devant, 0)
  local coup = frapper_par_henry(habitant, "« " .. nom .. " »", points)
  return string.format("« %s » (à %.0f m, faction %s) : %s ; %s ; santé %s, juste après %s", nom, distance or -1,
    tostring(liaison.faction_de(nom)), pose, coup, tostring(avant), tostring(liaison.sante_de(nom)))
end

-- Le jeu croit-il encore charger une sauvegarde ? (Game.IsLoadingEngineSaveGame, Scripts/Entities/Others/RuntimePrefab.lua :
-- seul indice du Lua du jeu, V72) ; nil si l'appel manque. Pour le guetteur du noyau.
function liaison.chargement_en_cours()
  local ok, oui = pcall(function() return Game.IsLoadingEngineSaveGame() end)
  if not ok then
    return nil
  end
  return oui == true or oui == 1
end

-- V72 c (fiche 14) : l'écran noir. Après un rechargement, la cible de l'archer retrouvée par son nom d'entité.
function liaison.retrouver_la_cible()
  if not liaison.cible_de_l_archer and entite_nommee("scriptorium_essai_cible") then
    liaison.cible_de_l_archer = "scriptorium_essai_cible"
  end
  return liaison.cible_de_l_archer
end

-- Ce qui entoure Henry dans « rayon » m (System.GetEntitiesInSphere) : nom, classe, position x, y, z et distance, du
-- plus proche au plus loin, au plus « nombre » lignes. Pour voir une entité posée dans une autre.
function liaison.voisins_d_henry(rayon, nombre)
  local lignes = {}
  local lu, erreur = pcall(function()
    local henry = player:GetWorldPos()
    local liste = {}
    for _, entite in pairs(System.GetEntitiesInSphere(henry, rayon) or {}) do
      local ou = entite:GetWorldPos()
      table.insert(liste, { nom = entite:GetName(), classe = entite.class, x = ou.x, y = ou.y, z = ou.z,
                            d = math.sqrt((ou.x - henry.x) ^ 2 + (ou.y - henry.y) ^ 2) })
    end
    table.sort(liste, function(a, b) return a.d < b.d end)
    table.insert(lignes, string.format("Henry (%.1f, %.1f, %.1f) ; %d entité(s) à moins de %d m", henry.x, henry.y, henry.z,
      #liste, rayon))
    for i = 1, math.min(#liste, nombre) do
      local v = liste[i]
      table.insert(lignes, string.format("%s [%s] (%.1f, %.1f, %.1f) à %.1f m", tostring(v.nom), tostring(v.classe), v.x, v.y,
        v.z, v.d))
    end
  end)
  if not lu then
    table.insert(lignes, "voisins illisibles : " .. tostring(erreur))
  end
  return lignes
end

-- Retire la cible de l'archer, entité d'essai (System.RemoveEntity).
function liaison.retirer_la_cible()
  local entite = entite_nommee(liaison.cible_de_l_archer)
  if not entite then
    return "cible introuvable"
  end
  local ok, erreur = pcall(function() System.RemoveEntity(entite.id) end)
  if ok then
    liaison.cible_de_l_archer = nil
  end
  return ok and "cible retirée" or ("retrait refusé : " .. tostring(erreur))
end

-- La cible de l'archer (V72 b) : une âme du brigand d'essai (notre cerveau, faction ennemie publique de Kuttenberg ; il
-- ne réagit pas, V48), née directement à « devant » m devant Henry (repère de poser_devant_henry), sur une place
-- regardée libre à l'image avant l'ordre (V72 a : personne dans un meuble du camp), et qui y reste.
liaison.cible_de_l_archer = liaison.cible_de_l_archer

function liaison.poser_la_cible_de_l_archer(devant)
  local point = liaison.point_devant_henry(devant)
  if not point then
    return "Henry introuvable"
  end
  local place = liaison.au_sol(point)
  local nom, erreur = faire_naitre("NPC", "scriptorium_essai_cible", place, liaison.cap_du_joueur() + 180,
                                   { guidSharedSoulId = liaison.ame_du_brigand_d_essai, bWH_RequiresHome = false })
  if not nom then
    return "cible refusée : " .. tostring(erreur)
  end
  liaison.cible_de_l_archer = nom
  local entite = entite_nommee(nom)
  local this_lu, this = pcall(function() return entite.this end)
  local gardee = this_lu and type(this) == "table"
    and pcall(function() XGenAIModule.SetBrainVariable(this.id, "scriptorium_essai_point", place) end)
  liaison.eveiller(nom, "Cible de l'archer")
  return string.format("cible posée à %.0f m devant Henry : %s (place gardée : %s)", devant, nom, tostring(gardee))
end

-- V71 a5 (fiche 13) : nos pièces reconnues par l'identifiant noté à leur création, jamais par leur état ; la tenue de
-- naissance retirée (inventory:DeleteItem(id, 1), Scripts/Entities/WH/Triggers/TriggerBase.lua). L'identifiant
-- tient-il après un rechargement ? Garde-fou : si une de nos pièces n'est pas reconnue, rien n'est retiré.
liaison.jeton_des_pieces_sonde = "scriptorium_socle.essai_pieces_sonde"

local function objets_de_l_inventaire(entite)
  local ok, liste = pcall(function() return entite.inventory:GetInventoryTable() end)
  local objets = {}
  if ok and type(liste) == "table" then
    for _, id in pairs(liste) do
      table.insert(objets, id)
    end
  end
  return objets
end

local function pieces_notees()
  local notees, nombre = {}, 0
  for texte in string.gmatch(jeton(liaison.jeton_des_pieces_sonde) or "", "[^,]+") do
    notees[texte] = true
    nombre = nombre + 1
  end
  return notees, nombre
end

-- Les objets du personnage en deux listes : les nôtres (identifiant noté) et les autres ; plus le nombre des nôtres
-- reconnus par objet et état 0,6 (contrôle) et le nombre de pièces notées.
local function trier_par_identifiant(entite)
  local notees, nombre = pieces_notees()
  local notres, autres = {}, {}
  for _, id in ipairs(objets_de_l_inventaire(entite)) do
    if notees[tostring(id)] then
      table.insert(notres, id)
    else
      table.insert(autres, id)
    end
  end
  local par_etat = trier_l_inventaire(entite)
  return notres, autres, #par_etat, nombre
end

local function dire_les_pieces(entite)
  local notres, autres, par_etat, nombre = trier_par_identifiant(entite)
  return string.format("inventaire : %d objet(s) ; %d des nôtres reconnus par identifiant (sur %d notés), %d par objet et "
    .. "état ; %d autre(s)", #notres + #autres, #notres, nombre, par_etat, #autres)
end

function liaison.creer_les_pieces_notees(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return "« " .. tostring(qui) .. " » introuvable"
  end
  local avant = {}
  for _, id in ipairs(objets_de_l_inventaire(entite)) do
    avant[tostring(id)] = true
  end
  for _, objet in ipairs(pieces_de_la_sonde_a4()) do
    pcall(function() entite.inventory:CreateItem(objet, liaison.etat_de_la_sonde_a4, 1) end)
  end
  local textes, portes = {}, 0
  for _, id in ipairs(objets_de_l_inventaire(entite)) do
    if not avant[tostring(id)] then
      table.insert(textes, tostring(id))
      if pcall(function() entite.actor:EquipInventoryItem(id) end) then
        portes = portes + 1
      end
    end
  end
  local ecrit, erreur = pcall(poser_un_jeton, liaison.jeton_des_pieces_sonde, table.concat(textes, ","))
  return string.format("%d pièce(s) neuve(s) notée(s) (jeton %s, premier « %s »), %d portée(s) ; %s", #textes,
    ecrit and "écrit" or ("refusé : " .. tostring(erreur)), tostring(textes[1]), portes, dire_les_pieces(entite))
end

function liaison.voir_les_pieces_notees(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return "« " .. tostring(qui) .. " » introuvable"
  end
  return dire_les_pieces(entite)
end

function liaison.ranger_les_pieces_notees(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return "« " .. tostring(qui) .. " » introuvable"
  end
  local notres, autres, _, nombre = trier_par_identifiant(entite)
  if nombre == 0 or #notres < nombre then
    return string.format("retrait refusé : %d des nôtres reconnus sur %d notés ; %s", #notres, nombre, dire_les_pieces(entite))
  end
  local portes, retires = 0, 0
  for _, id in ipairs(notres) do
    if pcall(function() entite.actor:EquipInventoryItem(id) end) then
      portes = portes + 1
    end
  end
  for _, id in ipairs(autres) do
    if pcall(function() entite.inventory:DeleteItem(id, 1) end) then
      retires = retires + 1
    end
  end
  return string.format("%d portée(s), %d autre(s) retiré(s) sur %d ; %s", portes, retires, #autres, dire_les_pieces(entite))
end

-- V71 a6 (fiche 13) : la tenue de naissance reconnue par sa signature (objet et état de chaque pièce, à six décimales),
-- notée à la naissance avant tout ; « à lui » est tout le reste. Rangement : ses pièces refaites porter, puis celles de la
-- signature retirées une à une (inventory:DeleteItem(id, 1)), recompte après chaque retrait.
liaison.jeton_de_la_signature_sonde = "scriptorium_socle.essai_signature_sonde"

local function pieces_avec_etat(entite)
  local pieces = {}
  for _, id in ipairs(objets_de_l_inventaire(entite)) do
    local lu, objet = pcall(function() return ItemManager.GetItem(id) end)
    if lu and type(objet) == "table" then
      table.insert(pieces, { id = id, objet = string.lower(tostring(objet.class)),
                             cle = string.lower(tostring(objet.class)) .. ":" .. string.format("%.6f", tonumber(objet.health) or -1) })
    end
  end
  return pieces
end

local function nombre_d_objets(entite)
  return #objets_de_l_inventaire(entite)
end

-- Sépare les pièces : celles de la signature (chaque entrée de la signature ne sert qu'une fois) et les autres.
local function trier_par_signature(entite)
  local restantes, nombre = {}, 0
  for cle in string.gmatch(jeton(liaison.jeton_de_la_signature_sonde) or "", "[^,]+") do
    restantes[cle] = (restantes[cle] or 0) + 1
    nombre = nombre + 1
  end
  local naissance, a_lui = {}, {}
  for _, p in ipairs(pieces_avec_etat(entite)) do
    if (restantes[p.cle] or 0) > 0 then
      restantes[p.cle] = restantes[p.cle] - 1
      table.insert(naissance, p)
    else
      table.insert(a_lui, p)
    end
  end
  return naissance, a_lui, nombre
end

local function dire_la_signature(entite)
  local naissance, a_lui, nombre = trier_par_signature(entite)
  local _, par_etat = pcall(function() return #(trier_l_inventaire(entite)) end)
  return string.format("inventaire : %d objet(s) ; %d de la signature (sur %d notées), %d à lui ; %s par objet et état 0,6",
    #naissance + #a_lui, #naissance, nombre, #a_lui, tostring(par_etat))
end

function liaison.noter_la_naissance(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return { "« " .. tostring(qui) .. " » introuvable" }
  end
  local cles = {}
  for _, p in ipairs(pieces_avec_etat(entite)) do
    table.insert(cles, p.cle)
  end
  table.sort(cles)
  local ecrit, erreur = pcall(poser_un_jeton, liaison.jeton_de_la_signature_sonde, table.concat(cles, ","))
  return { string.format("signature de naissance : %d pièce(s), jeton %s", #cles, ecrit and "écrit" or ("refusé : " .. tostring(erreur))),
           "pièces : " .. table.concat(cles, " ") }
end

function liaison.relever_l_inventaire(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return { "« " .. tostring(qui) .. " » introuvable" }
  end
  local naissance, a_lui = trier_par_signature(entite)
  local function cles(liste)
    local t = {}
    for _, p in ipairs(liste) do
      table.insert(t, p.cle)
    end
    table.sort(t)
    return table.concat(t, " ")
  end
  return { dire_la_signature(entite), "de la signature : " .. cles(naissance), "à lui : " .. cles(a_lui) }
end

function liaison.ranger_par_signature(qui)
  local entite = entite_nommee(qui)
  if not entite then
    return "« " .. tostring(qui) .. " » introuvable"
  end
  local naissance, a_lui, nombre = trier_par_signature(entite)
  local de_la_sonde = {}
  for _, id in ipairs(pieces_de_la_sonde_a4()) do
    de_la_sonde[string.lower(id)] = true
  end
  local justes = 0
  for _, p in ipairs(a_lui) do
    if de_la_sonde[p.objet] then
      justes = justes + 1
    end
  end
  if nombre == 0 or #a_lui ~= #pieces_de_la_sonde_a4() or justes ~= #a_lui then
    return string.format("rangement refusé : %d pièce(s) « à lui », dont %d de la sonde, pour %d attendues ; %s", #a_lui, justes,
      #pieces_de_la_sonde_a4(), dire_la_signature(entite))
  end
  local portes = 0
  for _, p in ipairs(a_lui) do
    if pcall(function() entite.actor:EquipInventoryItem(p.id) end) then
      portes = portes + 1
    end
  end
  local retires, echecs = 0, 0
  for _, p in ipairs(naissance) do
    local avant = nombre_d_objets(entite)
    pcall(function() entite.inventory:DeleteItem(p.id, 1) end)
    if nombre_d_objets(entite) == avant - 1 then
      retires = retires + 1
    else
      echecs = echecs + 1
    end
  end
  return string.format("%d portée(s) sur %d ; %d pièce(s) de naissance retirée(s), %d échec(s) ; %s", portes, #a_lui, retires,
    echecs, dire_la_signature(entite))
end

-- Fait venir le Directeur dans sa tente, sur son âme (fiche 13 : réserve « directeur », son personnage d'avant, celui
-- d'extraGuards_dummy_6). Rend son identifiant, ou nil.
function liaison.faire_venir_directeur(position, ame)
  if ame == nil or position == nil then
    liaison.journal("Venue impossible pour le Directeur : " .. (ame == nil and "pas d'âme" or "pas de position"))
    return nil
  end
  local identifiant, raison = faire_naitre("NPC", "Scriptorium_Directeur", position, 0, { guidSharedSoulId = ame })
  if not identifiant then
    liaison.journal("Venue impossible pour le Directeur : " .. tostring(raison))
    return nil
  end
  liaison.eveiller(identifiant, "Directeur")
  return identifiant
end

-- Pose un objet du jeu (StanceSmartObject) sur un meuble du camp : une place où s'asseoir ou se coucher (V62 ; propriétés
-- relevées sur des objets réels, V65). Comme les autres objets du socle, il n'est pas gardé par la sauvegarde (V64) ;
-- bOwnedByHome à false : le camp n'est pas une maison du jeu. Rend son identifiant, ou nil.
function liaison.poser_objet_du_jeu(nom, position, cap, proprietes)
  local p = copie_profonde(proprietes)
  p.bSaved_by_game = false
  p.bOwnedByHome = false
  local identifiant, raison = faire_naitre("StanceSmartObject", "scriptorium_" .. nom, liaison.au_sol(position), cap, p)
  if not identifiant then
    liaison.journal("Pose impossible pour la place « " .. nom .. " » : " .. tostring(raison))
  end
  return identifiant
end

-- Ouvre, ferme ou barre la porte posée. Le modèle du portail n'a pas d'animation, et son point de pose est
-- son gond (mesuré dans les paks le 14/10) : « ouverte », il tourne d'un quart de tour sur lui-même ;
-- « fermée » et « barrée », il revient à sa pose d'origine, gardée au premier mouvement. À vérifier en jeu (V22).
function liaison.changer_porte(identifiant, etat)
  liaison.journal("Porte " .. tostring(identifiant) .. " : " .. tostring(etat))
  local entite = entite_nommee(identifiant)
  if not entite then
    return
  end
  local ok, erreur = pcall(function()
    local fermee = etat_du_fichier.poses_fermees[identifiant]
    if not fermee then
      fermee = { angle = entite:GetWorldAngles().z }
      etat_du_fichier.poses_fermees[identifiant] = fermee
    end
    local angle = fermee.angle
    if etat == "ouverte" then
      angle = angle + math.pi / 2
    end
    entite:SetWorldAngles({ x = 0, y = 0, z = angle })
  end)
  if not ok then
    liaison.journal("Porte " .. tostring(identifiant) .. " : mouvement impossible : " .. tostring(erreur))
  end
end

-- Vrai quand une partie est chargée (le camp ne bat pas au menu principal).
-- À vérifier en jeu : l'appel sûr ; en attendant, vrai si « player » existe.
function liaison.partie_en_cours()
  local ok, present = pcall(function() return player ~= nil and player.id ~= nil end)
  return ok and present == true
end

-- Entrée en partie et sortie. Constaté le 14/10 (sondes) : une minuterie posée au démarrage du mod ne tire
-- jamais, ni au menu ni en partie ; une minuterie posée à l'événement System « OnGameplayStarted » tire en
-- partie. Le jeu accepte aussi l'abonnement à « OnGameplayEnded » (à vérifier en jeu : qu'il arrive au
-- retour au menu). Les fonctions rendues sont appelées sans argument.
liaison.ecouteur = liaison.ecouteur or {}

-- Fiche 15, V73 f 3 a (la sonde de la carte) : la carte où l'on est. Aucun script du jeu ne lit son nom (et, d'après le
-- pair, le jeu n'en expose aucun au Lua) : une seule lecture de nom, la variable du moteur « sv_map », sous pcall ;
-- puis la voie qui marche chez Scriptorium depuis le 5/10 (la tournée du coursier, transmise par le pair) : l'altitude
-- du terrain en un point connu de chaque carte, à « tolerance_des_reperes_m » près. Rend (la carte, la voie qui a
-- répondu), ou (nil, ce que chaque voie a rendu).
liaison.reperes_des_cartes = {
  { carte = "kutnohorsko", x = 1548.706, y = 1916.385, altitude = 143.74 },   -- sous le forgeron de Miskovice
  { carte = "trosecko", x = 1997.568, y = 2499.344, altitude = 115.34 },      -- sous le forgeron de Radovan
}
liaison.tolerance_des_reperes_m = 1.5

function liaison.carte_courante()
  local essais = {}
  local lu, nom = pcall(function() return System.GetCVar("sv_map") end)
  if lu and type(nom) == "string" and nom ~= "" then
    return nom, "sv_map"
  end
  table.insert(essais, "sv_map : " .. (lu and tostring(nom) or "refusée"))
  for _, repere in ipairs(liaison.reperes_des_cartes) do
    local mesure, altitude = pcall(System.GetTerrainElevation, { x = repere.x, y = repere.y, z = 0 })
    altitude = mesure and tonumber(altitude) or nil
    if altitude and math.abs(altitude - repere.altitude) <= liaison.tolerance_des_reperes_m then
      return repere.carte, "altitude du terrain"
    end
    table.insert(essais, repere.carte .. " : " .. (altitude and string.format("%.2f m", altitude) or "illisible"))
  end
  return nil, table.concat(essais, " ; ")
end

-- Les événements de chargement du groupe « System » (documentation de CryEngine 5, « UI Action ») : une ligne au
-- journal avec leurs arguments tels quels et ce que dit Game.IsLoadingEngineSaveGame ; le dernier gardé.
liaison.dernier_chargement = liaison.dernier_chargement
liaison.evenements_de_chargement = { "OnLoadingStart", "OnLoadingComplete", "OnLoadingError", "OnUnloadStart",
                                     "OnUnloadComplete" }

local function dire_le_chargement(evenement, ...)
  local morceaux = {}
  for i = 1, select("#", ...) do
    local valeur = select(i, ...)
    if valeur ~= liaison.ecouteur then
      if type(valeur) == "table" then
        for cle, v in pairs(valeur) do
          table.insert(morceaux, tostring(cle) .. "=" .. tostring(v))
        end
      else
        table.insert(morceaux, tostring(valeur))
      end
    end
  end
  local sauvegarde = liaison.chargement_en_cours()
  -- Fiche 01 (le second canal) : un nouveau chargement oublie les cases rangées d'un chargement précédent.
  if evenement == "OnLoadingStart" then
    liaison.depuis_la_sauvegarde = nil
  end
  liaison.dernier_chargement = { evenement = evenement, arguments = table.concat(morceaux, ", "), sauvegarde = sauvegarde }
  liaison.journal("Chargement : " .. evenement .. " (" .. table.concat(morceaux, ", ") .. ") ; sauvegarde = "
                  .. tostring(sauvegarde))
end

function liaison.ecouter_la_partie(a_l_entree, a_la_sortie)
  -- La mémoire de secours ne passe jamais d'une partie à l'autre : vidée à chaque entrée, avant la relecture.
  liaison.ecouteur.SurEntreeEnPartie = function()
    liaison.memoire.registre = nil
    liaison.memoire.liste_des_cases, liaison.memoire.cases = nil, {}
    -- V73 f 3 a : la carte lue, une ligne au journal ; V73 f 3 b : gardée en mémoire avec celle d'avant.
    local carte, source = liaison.carte_courante()
    liaison.journal("Carte : " .. tostring(carte) .. " (" .. tostring(source) .. ")")
    liaison.memoire.carte_d_avant, liaison.memoire.carte = liaison.memoire.carte, carte
    a_l_entree()
  end
  liaison.ecouteur.SurSortieDePartie = function() a_la_sortie() end
  local abonnements = {
    { evenement = "OnGameplayStarted", methode = "SurEntreeEnPartie" },
    { evenement = "OnGameplayEnded", methode = "SurSortieDePartie" },
  }
  for _, evenement in ipairs(liaison.evenements_de_chargement) do
    local methode = "Sur" .. evenement
    liaison.ecouteur[methode] = function(...) dire_le_chargement(evenement, ...) end
    table.insert(abonnements, { evenement = evenement, methode = methode })
  end
  for _, abonnement in ipairs(abonnements) do
    local ok, resultat = pcall(function()
      return UIAction.RegisterEventSystemListener(liaison.ecouteur, "System", abonnement.evenement, abonnement.methode)
    end)
    if not ok then
      liaison.journal("Abonnement à « " .. abonnement.evenement .. " » refusé : " .. tostring(resultat))
    end
  end
end

Scriptorium.liaison_reelle = liaison
Scriptorium.jeu = Scriptorium.jeu or liaison

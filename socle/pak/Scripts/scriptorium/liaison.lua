-- Liaison avec le jeu : le seul fichier du socle qui parle au moteur.
-- Tout le reste du socle passe par Scriptorium.jeu.<fonction>().
-- Les essais remplacent Scriptorium.jeu par un faux jeu (essais/lua/faux_jeu.lua).
--
-- Chaque fonction marquée « à vérifier en jeu » repose sur un appel du moteur
-- qui n'a pas encore été confirmé sur le PC de JoVenGer. Voir docs/socle/essai_en_jeu.md.

Scriptorium = Scriptorium or {}

local liaison = {}

-- Mémoire de secours pour le registre, le temps que le mécanisme de sauvegarde
-- du jeu soit confirmé : elle ne survit pas à la fermeture du jeu.
liaison.memoire = { registre = nil }

-- Temps du moteur, en secondes (pas le temps du jeu : l'horloge réelle).
function liaison.maintenant()
  return System.GetCurrTime()
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
function liaison.afficher(texte, duree, complement)
  if complement then
    texte = texte .. " " .. complement
  end
  local ok, erreur = pcall(function()
    UIAction.CallFunction("hud", 0, "SetSubtitleBgEnable", true)
    UIAction.CallFunction("hud", 0, "SetSubtitles", texte, "", false)
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

-- Efface le texte affiché et rend au joueur son réglage du fond des sous-titres.
function liaison.effacer()
  local ok, erreur = pcall(function()
    UIAction.CallFunction("hud", 0, "ClearSubtitles")
    UIAction.CallFunction("hud", 0, "SetSubtitleBgEnable", fond_des_sous_titres_du_joueur())
  end)
  if not ok then
    liaison.journal("Effacement impossible : " .. tostring(erreur))
  end
end

-- Vrai quand Henry est en dialogue (le bandeau attend : la ligne des sous-titres sert aussi aux dialogues).
-- DialogModule.IsSoulInDialog existe dans le Lua du jeu, mais aucun script du jeu ne l'appelle : la forme
-- de son argument est à vérifier en jeu (V6). On essaie l'âme d'Henry, son identifiant d'entité, puis son
-- WUID ; la première forme qui rend un booléen est gardée et dite au journal. Hors partie, rien n'est décidé.
local forme_du_dialogue = nil
local formes_du_dialogue = {
  { nom = "l'âme", argument = function() return player.soul end },
  { nom = "l'identifiant d'entité", argument = function() return player.id end },
  { nom = "le WUID", argument = function() return XGenAIModule.GetMyWUID(player) end },
}

function liaison.dialogue_en_cours()
  if forme_du_dialogue == false or not liaison.partie_en_cours() then
    return false
  end
  local formes = forme_du_dialogue and { forme_du_dialogue } or formes_du_dialogue
  for _, forme in ipairs(formes) do
    local ok, resultat = pcall(function() return DialogModule.IsSoulInDialog(forme.argument()) end)
    if ok and type(resultat) == "boolean" then
      if not forme_du_dialogue then
        forme_du_dialogue = forme
        liaison.journal("Dialogue : IsSoulInDialog répond avec " .. forme.nom)
      end
      return resultat
    end
  end
  forme_du_dialogue = false
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

-- Un montant d'argent acceptable : un nombre entier, fini, strictement positif.
local function montant_juste(montant)
  return type(montant) == "number" and montant == montant and montant > 0 and montant < math.huge
         and math.floor(montant) == montant
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

-- Donne des groschen à Henry (versement du coffre). Vrai si fait. Même garde : un montant entier, strictement positif.
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

local function faire_naitre(classe, nom, position, cap, proprietes)
  local nom_unique = nom_libre((string.gsub(nom, "[^A-Za-z0-9_]", "_")))
  local angle = cap_vers_moteur(cap)
  if classe == "NPC" then
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
function liaison.poser_objet(sorte, modele, position, cap, nom, classe)
  local identifiant, raison = faire_naitre(classe or "BasicEntity", "scriptorium_" .. nom, liaison.au_sol(position), cap, { object_Model = modele })
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
local poses_fermees = {}

-- Retire un objet posé par le socle.
-- À vérifier en jeu : System.RemoveEntity.
function liaison.retirer_objet(identifiant)
  poses_fermees[identifiant] = nil
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
local identite_de_la_partie = nil
local jeton_essaye = false
local tranches_ecrites = 0

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

-- Rend l'identité et les données du registre (recollées s'il est en tranches), ou nil. « raison » : pourquoi un
-- registre en tranches est refusé (tranche manquante, d'une autre partie, longueur ou somme fausse).
local function lire_le_jeton()
  local valeur = jeton(liaison.nom_du_jeton)
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
    local tranche = jeton(string.format("%s.%d", liaison.nom_du_jeton, i))
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

-- Écrit le registre en tranches : les tranches d'abord, l'en-tête ensuite ; les tranches d'une écriture plus longue
-- sont vidées. Les nombres s'écrivent par « %d » : le Lua du jeu écrit 1 000 000 « 1e+06 » quand on le colle à une
-- chaîne. Rend vrai, ou faux et l'erreur.
function liaison.entete_du_registre(identite, n, chaine)
  return string.format("%s|tranches|%d|%d|%d", identite, n, #chaine, somme_de(chaine))
end

local function ecrire_le_jeton(identite, chaine)
  local taille = liaison.taille_des_tranches
  local n = math.max(1, math.ceil(#chaine / taille))
  local ok, erreur = pcall(function()
    for i = 1, n do
      poser_un_jeton(string.format("%s.%d", liaison.nom_du_jeton, i),
                         string.format("%s|%d|", identite, i) .. string.sub(chaine, (i - 1) * taille + 1, i * taille))
    end
    for i = n + 1, tranches_ecrites do
      poser_un_jeton(string.format("%s.%d", liaison.nom_du_jeton, i), "")
    end
    poser_un_jeton(liaison.nom_du_jeton, liaison.entete_du_registre(identite, n, chaine))
  end)
  if ok then
    tranches_ecrites = n
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

-- Lit la chaîne du registre enregistrée dans cette partie, ou nil.
function liaison.lire_registre()
  local identite, donnees, raison = lire_le_jeton()
  if identite and entite_nommee(liaison.prefixe_de_la_marque .. identite) then
    identite_de_la_partie = identite
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
  identite_de_la_partie = nil
  return liaison.memoire.registre
end

-- Donne une identité à la partie et pose sa marque dans le monde.
local function marquer_la_partie()
  local identite = string.format("p%d_%d", os.time(), math.random(100000, 999999))
  local pose = faire_naitre("BasicEntity", liaison.prefixe_de_la_marque .. identite, { x = 0, y = 0, z = 0 }, 0, {})
  if pose then
    identite_de_la_partie = identite
    liaison.journal("Registre : partie marquée (" .. identite .. ")")
    return true
  end
  liaison.journal("Registre : marque de la partie impossible à poser ; mémoire de secours seule")
  return false
end

-- Enregistre la chaîne du registre dans cette partie. La première fois, relit le jeton et dit au journal s'il tient.
function liaison.ecrire_registre(chaine)
  liaison.memoire.registre = chaine
  if not (identite_de_la_partie and entite_nommee(liaison.prefixe_de_la_marque .. identite_de_la_partie)) then
    if not marquer_la_partie() then
      return
    end
  end
  local ok, erreur, n = ecrire_le_jeton(identite_de_la_partie, chaine)
  if not jeton_essaye then
    jeton_essaye = true
    local _, relu, raison = lire_le_jeton()
    if ok and relu == chaine then
      liaison.journal("Registre : jeton du jeu en service (" .. #chaine .. " caractères, " .. n .. " tranche(s))")
    else
      liaison.journal("Registre : jeton du jeu refusé (" .. tostring(ok and (raison or "relu différent") or erreur)
                      .. ") ; mémoire de secours seule")
    end
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
-- Les âmes (du jeu ou à nous) par rôle, pour faire venir un personnage.
-- Provisoire, en attendant les tables à nous : des gardes « en réserve » de Trosky, génériques et non hostiles
-- (extraGuards_dummy_*, table Libs/Tables/rpg/soul__extraGuards.xml). Vu en jeu le 14/10 : l'homme d'armes vient
-- (V16). Une âme par rôle seulement : deux hommes du même rôle partagent la même âme (à vérifier en jeu).
liaison.ames = {
  homme_d_armes = "63daa80b-d1f4-46f5-8222-c22a541cae07",   -- extraGuards_dummy_1
  arbaletrier   = "6e04789b-f704-4da7-98b6-4558fac75748",   -- extraGuards_dummy_3
  archer        = "2e96ee86-7c95-4b57-91f6-6d3abce75d22",   -- extraGuards_dummy_5
}

-- Fait venir un personnage de la Compagnie et rend son identifiant, ou nil.
-- La propriété d'âme d'un personnage s'appelle guidSharedSoulId (relevé Lua du jeu, table NPC.Properties).
-- À vérifier en jeu : System.SpawnEntity avec la classe NPC et cette propriété.
function liaison.faire_venir_homme(role, nom, position)
  local ame = liaison.ames[role]
  if ame == nil or position == nil then
    liaison.journal("Venue impossible pour « " .. nom .. " » : pas d'âme pour le rôle " .. tostring(role))
    return nil
  end
  local identifiant, raison = faire_naitre("NPC", "scriptorium_" .. nom, position, 0, { guidSharedSoulId = ame })
  if not identifiant then
    liaison.journal("Venue impossible pour « " .. nom .. " » : " .. tostring(raison))
  end
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

-- Donne un ordre simple à un personnage : dormir ici, s'asseoir là, se tenir là.
-- À vérifier en jeu : l'appel du moteur. En attendant, l'ordre est noté au journal.
-- Vu le 14/10 (V17) : le jeu de base n'a pas d'ordre générique « marcher, s'asseoir, dormir » ; ses personnages
-- obéissent à des cerveaux propres à chaque quête. Ces ordres attendent un cerveau à nous (tables du jeu).
-- En attendant, « se tenir là » : le personnage est posé au lieu s'il en est à plus de deux mètres.
function liaison.ordonner(identifiant, activite, position, lieu)
  liaison.journal("Ordre à " .. tostring(identifiant) .. " : " .. activite .. " (" .. tostring(lieu) .. ")")
  local entite = entite_nommee(identifiant)
  if not entite or not position then
    return
  end
  local ok, ici = pcall(function() return entite:GetWorldPos() end)
  if ok and type(ici) == "table" and ((ici.x - position.x) ^ 2 + (ici.y - position.y) ^ 2) > 4 then
    local pose, erreur = pcall(function() entite:SetWorldPos({ x = position.x, y = position.y, z = position.z }) end)
    if not pose then
      liaison.journal("Ordre à " .. tostring(identifiant) .. " : déplacement impossible : " .. tostring(erreur))
    end
  end
end

-- Âmes des ennemis par sorte de bande, prises dans le jeu de base.
-- Premier essai (V18, 14/10) : une seule âme, un brigand générique d'une quête de Trosecko
-- (bohutovaVlozka_bandit_3, faction trosecko_enemies_bandits_bohutovaVlozka, table soul__bohutovaVlozka.xml).
liaison.ames_ennemies = {
  brigands = "11c514e3-1c7c-40de-8011-318192937d41",
}

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
    local identifiant = faire_naitre("NPC", "scriptorium_ennemi_" .. sorte .. "_" .. i, place, cap, { guidSharedSoulId = ame })
    if identifiant then
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

-- L'âme du Directeur (personnage à nous, apparence neuve).
-- À vérifier en jeu : à renseigner depuis les tables du socle.
-- Provisoire, en attendant une âme et une apparence à nous (V20) : un garde « en réserve » de Trosky
-- (extraGuards_dummy_6), générique et non hostile.
liaison.ame_du_directeur = "5f05b3d3-3c0f-4a55-95d7-d2eef1af4bbb"

-- Fait venir le Directeur dans sa tente. Rend son identifiant, ou nil.
function liaison.faire_venir_directeur(position)
  if liaison.ame_du_directeur == nil or position == nil then
    liaison.journal("Venue impossible pour le Directeur : pas d'âme renseignée")
    return nil
  end
  local identifiant, raison = faire_naitre("NPC", "Scriptorium_Directeur", position, 0, { guidSharedSoulId = liaison.ame_du_directeur })
  if not identifiant then
    liaison.journal("Venue impossible pour le Directeur : " .. tostring(raison))
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
    local fermee = poses_fermees[identifiant]
    if not fermee then
      fermee = { angle = entite:GetWorldAngles().z }
      poses_fermees[identifiant] = fermee
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
liaison.ecouteur = {}

function liaison.ecouter_la_partie(a_l_entree, a_la_sortie)
  -- La mémoire de secours ne passe jamais d'une partie à l'autre : vidée à chaque entrée, avant la relecture.
  liaison.ecouteur.SurEntreeEnPartie = function()
    liaison.memoire.registre = nil
    a_l_entree()
  end
  liaison.ecouteur.SurSortieDePartie = function() a_la_sortie() end
  local abonnements = {
    { evenement = "OnGameplayStarted", methode = "SurEntreeEnPartie" },
    { evenement = "OnGameplayEnded", methode = "SurSortieDePartie" },
  }
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

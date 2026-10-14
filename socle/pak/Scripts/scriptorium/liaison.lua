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

-- Vrai quand un dialogue ou une cinématique est en cours.
-- À vérifier en jeu : l'appel du moteur qui le dit. En attendant : jamais.
function liaison.dialogue_en_cours()
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

-- Rend la table du fichier d'ordres et son chemin ; nil s'il n'y a pas de fichier ;
-- nil, chemin, raison s'il est illisible. Le fichier ne voit rien du jeu (environnement vide).
function liaison.lire_ordres()
  for _, chemin in ipairs(liaison.chemins_des_ordres) do
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

-- Heure du jeu, en heures, pour dater le livre de comptes.
-- À vérifier en jeu : Calendar.GetWorldTime() (secondes de jeu ?). En attendant, 0 si absent.
function liaison.heure_du_jeu()
  local ok, valeur = pcall(function() return Calendar.GetWorldTime() end)
  if ok and type(valeur) == "number" then
    return valeur / 3600
  end
  return 0
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

-- Retire des groschen à Henry (dépôt au coffre, voulu par le joueur). Vrai si fait.
-- À vérifier en jeu : player.inventory:RemoveMoney(n). Si l'appel manque, rien n'est fait.
function liaison.retirer_groschen_a_henry(montant)
  if liaison.groschen_d_henry() < montant then
    return false
  end
  local ok = pcall(function() player.inventory:RemoveMoney(montant) end)
  return ok
end

-- Donne des groschen à Henry (versement du coffre). Vrai si fait.
-- À vérifier en jeu : player.inventory:AddMoney(n).
function liaison.donner_groschen_a_henry(montant)
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
  return math.rad(-(cap or 0))
end

local function cap_depuis_moteur(radians)
  return (-math.deg(radians)) % 360
end

-- Fait naître une entité et rend son nom, ou nil et la raison.
local function faire_naitre(classe, nom, position, cap, proprietes)
  local nom_unique = nom_libre(nom)
  local ok, entite = pcall(function()
    return System.SpawnEntity({
      class = classe,
      name = nom_unique,
      position = { x = position.x, y = position.y, z = position.z },
      orientation = { x = 0, y = 0, z = cap_vers_moteur(cap) },
      properties = proprietes,
    })
  end)
  if ok and entite and entite.id then
    return nom_unique
  end
  return nil, tostring(entite)
end

-- Pose un objet du jeu de base (modèle par son chemin) et rend son identifiant, ou nil.
-- Vu en jeu le 14/10 : System.SpawnEntity avec la classe BasicEntity pose bien l'objet ;
-- un modèle introuvable donne une forme blanche.
function liaison.poser_objet(sorte, modele, position, cap, nom)
  local identifiant, raison = faire_naitre("BasicEntity", "scriptorium_" .. nom, position, cap, { object_Model = modele })
  if not identifiant then
    liaison.journal("Pose impossible pour « " .. nom .. " » (" .. sorte .. ") : " .. tostring(raison))
  end
  return identifiant
end

-- Retire un objet posé par le socle.
-- À vérifier en jeu : System.RemoveEntity.
function liaison.retirer_objet(identifiant)
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
local identite_de_la_partie = nil
local jeton_essaye = false

local function lire_le_jeton()
  local ok, valeur = pcall(function() return GameToken.GetToken(liaison.nom_du_jeton) end)
  if not ok or type(valeur) ~= "string" then
    return nil, nil
  end
  local identite, donnees = string.match(valeur, "^([%w_]+)|(.*)$")
  return identite, donnees
end

-- Lit la chaîne du registre enregistrée dans cette partie, ou nil.
function liaison.lire_registre()
  local identite, donnees = lire_le_jeton()
  if identite and entite_nommee(liaison.prefixe_de_la_marque .. identite) then
    identite_de_la_partie = identite
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
  local valeur = identite_de_la_partie .. "|" .. chaine
  local ok, erreur = pcall(function() GameToken.SetToken(liaison.nom_du_jeton, valeur) end)
  if not jeton_essaye then
    jeton_essaye = true
    local relu_ok, relu = pcall(function() return GameToken.GetToken(liaison.nom_du_jeton) end)
    if ok and relu_ok and relu == valeur then
      liaison.journal("Registre : jeton du jeu en service (" .. #chaine .. " caractères)")
    else
      liaison.journal("Registre : jeton du jeu refusé (" .. tostring(ok and (relu_ok and "relu différent" or relu) or erreur)
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

-- Les âmes (du jeu ou à nous) par rôle, pour faire venir un personnage.
-- À vérifier en jeu : à remplir avec les identifiants d'âmes des tables du socle (morceau 2.9).
liaison.ames = {}

-- Fait venir un personnage de la Compagnie et rend son identifiant, ou nil.
-- À vérifier en jeu : System.SpawnEntity avec la classe NPC et sharedSoulGuid.
function liaison.faire_venir_homme(role, nom, position)
  local ame = liaison.ames[role]
  if ame == nil or position == nil then
    liaison.journal("Venue impossible pour « " .. nom .. " » : pas d'âme pour le rôle " .. tostring(role))
    return nil
  end
  local identifiant, raison = faire_naitre("NPC", "scriptorium_" .. nom, position, 0, { sharedSoulGuid = ame })
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
function liaison.ordonner(identifiant, activite, position, place)
  liaison.journal("Ordre à " .. tostring(identifiant) .. " : " .. activite .. " (" .. tostring(place) .. ")")
end

-- Âmes des ennemis par sorte de bande, prises dans le jeu de base.
-- À vérifier en jeu : à remplir avec les identifiants d'âmes des brigands, Coumans, etc.
liaison.ames_ennemies = {}

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
    local place = { x = position.x + (i % 5) * 1.5, y = position.y + math.floor(i / 5) * 1.5, z = position.z }
    local identifiant = faire_naitre("NPC", "scriptorium_ennemi_" .. sorte .. "_" .. i, place, cap, { sharedSoulGuid = ame })
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

-- L'âme du Directeur (personnage à nous, apparence neuve).
-- À vérifier en jeu : à renseigner depuis les tables du socle.
liaison.ame_du_directeur = nil

-- Fait venir le Directeur dans sa tente. Rend son identifiant, ou nil.
function liaison.faire_venir_directeur(position)
  if liaison.ame_du_directeur == nil or position == nil then
    liaison.journal("Venue impossible pour le Directeur : pas d'âme renseignée")
    return nil
  end
  local identifiant, raison = faire_naitre("NPC", "Scriptorium_Directeur", position, 0, { sharedSoulGuid = liaison.ame_du_directeur })
  if not identifiant then
    liaison.journal("Venue impossible pour le Directeur : " .. tostring(raison))
  end
  return identifiant
end

-- Ouvre, ferme ou barre la porte posée.
-- À vérifier en jeu : comment animer ou remplacer une porte posée. En attendant, journal.
function liaison.changer_porte(identifiant, etat)
  liaison.journal("Porte " .. tostring(identifiant) .. " : " .. tostring(etat))
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

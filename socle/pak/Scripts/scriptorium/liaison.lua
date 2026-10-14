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

-- Affiche un texte au joueur pendant « duree » secondes.
-- À vérifier en jeu : Game.SendInfoText est l'appel connu pour afficher un texte
-- au joueur ; sa place et son aspect (bande noire en bas) restent à confirmer.
-- Avec un complément (un nom, un montant), il est ajouté après le texte traduit.
-- À vérifier en jeu : que la traduction de « @clé » tient quand on lui colle un complément.
function liaison.afficher(texte, duree, complement)
  if complement then
    texte = texte .. " " .. complement
  end
  Game.SendInfoText(texte, true, nil, duree)
end

-- Efface le texte affiché. Avec Game.SendInfoText, le texte disparaît de lui-même.
function liaison.effacer()
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

-- Lit la chaîne du registre enregistrée dans la partie, ou nil.
-- À vérifier en jeu : le mécanisme de sauvegarde à employer. En attendant, mémoire de secours.
function liaison.lire_registre()
  return liaison.memoire.registre
end

-- Enregistre la chaîne du registre dans la partie.
-- À vérifier en jeu : même remarque.
function liaison.ecrire_registre(chaine)
  liaison.memoire.registre = chaine
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

-- Pose un objet du jeu de base (modèle par son chemin) et rend son identifiant, ou nil.
-- À vérifier en jeu : System.SpawnEntity avec la classe BasicEntity et object_Model,
-- et la forme de l'orientation attendue (angles en degrés ou en radians ?).
function liaison.poser_objet(sorte, modele, position, cap, nom)
  local ok, entite = pcall(function()
    return System.SpawnEntity({
      class = "BasicEntity",
      name = "scriptorium_" .. nom,
      position = { x = position.x, y = position.y, z = position.z },
      orientation = { x = 0, y = 0, z = math.rad(cap) },
      properties = { object_Model = modele },
    })
  end)
  if ok and entite and entite.id then
    return entite.id
  end
  liaison.journal("Pose impossible pour « " .. nom .. " » (" .. sorte .. ") : " .. tostring(entite))
  return nil
end

-- Retire un objet posé par le socle.
-- À vérifier en jeu : System.RemoveEntity(identifiant).
function liaison.retirer_objet(identifiant)
  pcall(function() System.RemoveEntity(identifiant) end)
end

-- Vrai si l'objet existe encore dans le monde.
-- À vérifier en jeu : System.GetEntity(identifiant).
function liaison.objet_existe(identifiant)
  local ok, entite = pcall(function() return System.GetEntity(identifiant) end)
  return ok and entite ~= nil
end

-- Position et cap d'Henry, pour fonder le camp là où il se tient.
-- À vérifier en jeu : player:GetWorldPos() et player:GetWorldAngles() (z en radians ?).
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
    return math.deg(angles.z)
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
  local ok, entite = pcall(function()
    return System.SpawnEntity({
      class = "NPC",
      name = "scriptorium_" .. nom,
      position = { x = position.x, y = position.y, z = position.z },
      orientation = { x = 0, y = 0, z = 0 },
      properties = { sharedSoulGuid = ame },
    })
  end)
  if ok and entite and entite.id then
    return entite.id
  end
  liaison.journal("Venue impossible pour « " .. nom .. " » : " .. tostring(entite))
  return nil
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
    local ok, entite = pcall(function()
      return System.SpawnEntity({
        class = "NPC",
        name = "scriptorium_ennemi_" .. sorte .. "_" .. i,
        position = { x = position.x + (i % 5) * 1.5, y = position.y + math.floor(i / 5) * 1.5, z = position.z },
        orientation = { x = 0, y = 0, z = math.rad(cap) },
        properties = { sharedSoulGuid = ame },
      })
    end)
    if ok and entite and entite.id then
      table.insert(liste, entite.id)
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
    local entite = System.GetEntity(identifiant)
    if entite == nil then return true end
    if entite.actor and entite.actor.IsDead then return entite.actor:IsDead() end
    if entite.soul and entite.soul.GetHealth then return entite.soul:GetHealth() <= 0 end
    return false
  end)
  return ok and mort == true
end

Scriptorium.liaison_reelle = liaison
Scriptorium.jeu = Scriptorium.jeu or liaison

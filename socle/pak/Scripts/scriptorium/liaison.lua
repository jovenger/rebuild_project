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
function liaison.afficher(texte, duree)
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

Scriptorium.liaison_reelle = liaison
Scriptorium.jeu = Scriptorium.jeu or liaison

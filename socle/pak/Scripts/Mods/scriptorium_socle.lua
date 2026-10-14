-- Démarrage du socle Scriptorium (mod d'essai « scriptorium_socle »).
-- Le jeu exécute de lui-même Scripts/Mods/<modid>.lua juste après Scripts/main.lua (wiki de Warhorse).
-- Ordre de chargement : noyau, liaison, puis les morceaux, puis le poste d'essai.

Script.ReloadScript("Scripts/scriptorium/noyau.lua")
Script.ReloadScript("Scripts/scriptorium/liaison.lua")
Script.ReloadScript("Scripts/scriptorium/bandeau.lua")
Script.ReloadScript("Scripts/scriptorium/registre.lua")
Script.ReloadScript("Scripts/scriptorium/coffre.lua")
Script.ReloadScript("Scripts/scriptorium/camp.lua")
Script.ReloadScript("Scripts/scriptorium/hommes.lua")
Script.ReloadScript("Scripts/scriptorium/bataille.lua")
Script.ReloadScript("Scripts/scriptorium/directeur.lua")
Script.ReloadScript("Scripts/scriptorium/enceinte.lua")
Script.ReloadScript("Scripts/scriptorium/atelier.lua")
Script.ReloadScript("Scripts/scriptorium/patrouilles.lua")
Script.ReloadScript("Scripts/scriptorium/discipline.lua")
Script.ReloadScript("Scripts/scriptorium/caractere.lua")
Script.ReloadScript("Scripts/scriptorium/reglages.lua")
Script.ReloadScript("Scripts/scriptorium/poste.lua")

Scriptorium.demarrer()

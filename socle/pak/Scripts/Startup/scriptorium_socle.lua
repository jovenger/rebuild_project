-- Démarrage du socle Scriptorium (mod d'essai « scriptorium_socle »).
-- Le jeu exécute de lui-même les scripts de Scripts/Startup/ au lancement.
-- Ordre de chargement : noyau, liaison, puis les morceaux, puis le poste d'essai.

Script.ReloadScript("Scripts/scriptorium/noyau.lua")
Script.ReloadScript("Scripts/scriptorium/liaison.lua")
Script.ReloadScript("Scripts/scriptorium/bandeau.lua")
Script.ReloadScript("Scripts/scriptorium/registre.lua")
Script.ReloadScript("Scripts/scriptorium/poste.lua")

Scriptorium.demarrer()

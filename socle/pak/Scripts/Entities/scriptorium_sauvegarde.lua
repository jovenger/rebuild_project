-- Fiche 01 (le second canal) : la classe d'entité du socle dont le jeu appelle l'OnSave pendant la sauvegarde de la
-- partie et l'OnLoad à son chargement ; colle du moteur, extension de liaison.lua : elle ne fait que passer sa table à
-- liaison.a_la_sauvegarde et liaison.a_la_relecture. Forme d'après le guide « How-to Lua » (Nexus Mods, KCD, mod 1344)
-- et AISpawner du jeu (Entities/AISpawner.ent, Scripts/Entities/AI/AISpawner.lua) : 43 des 59 classes du jeu qui ont un
-- OnSave ne déclarent ni bSaved_by_game ni bSerialize (Scripts.pak, lecture seule) ; une entité créée est sauvegardée
-- par défaut (vu en jeu le 18/10 : elle revient avec la partie).
scriptorium_sauvegarde = {
  Properties = {},
}

function scriptorium_sauvegarde:OnSave(tableau)
  if Scriptorium and Scriptorium.jeu and Scriptorium.jeu.a_la_sauvegarde then
    Scriptorium.jeu.a_la_sauvegarde(tableau)
  end
end

function scriptorium_sauvegarde:OnLoad(tableau)
  if Scriptorium and Scriptorium.jeu and Scriptorium.jeu.a_la_relecture then
    Scriptorium.jeu.a_la_relecture(tableau)
  end
end

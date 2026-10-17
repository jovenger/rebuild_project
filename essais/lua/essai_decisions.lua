-- Essais des décisions remplaçables (fiche 19) : remplacée, la décision du socle suit ; nil, la décision du socle ;
-- en erreur ou boiteuse, la décision du socle et une ligne au journal.

local hommes = Scriptorium.hommes
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre
local missions = Scriptorium.missions
local bataille = Scriptorium.bataille
local directeur = Scriptorium.directeur

local function preparer(heure)
  depart()
  FauxJeu.heure = heure or 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  Scriptorium.bandeau.remettre_a_zero()
end

local function lignes_contenant(texte)
  local n = 0
  for _, l in ipairs(FauxJeu.journal_lignes) do
    if string.find(l, texte, 1, true) then n = n + 1 end
  end
  return n
end

essai("décisions (fiche 19) : le moyen du noyau ; direct, remplacée, nil, erreur, valeur refusée, faux gardé, plusieurs valeurs", function()
  depart()
  local morceau = {}
  function morceau.choix(a) return "socle:" .. tostring(a), "deuxieme" end
  Scriptorium.remplacable(morceau, "choix", function(rendu) return type(rendu) == "string" end)
  local avant = #FauxJeu.journal_lignes
  local un, deux = Scriptorium.avis(morceau, "choix", 1)
  egal(un, "socle:1", "la décision du socle, directe")
  egal(deux, "deuxieme", "ses deux valeurs")
  avec_remplacement(morceau, "choix", function(a) return "scriptorium:" .. a, "autre" end, function()
    local x, y = Scriptorium.avis(morceau, "choix", 2)
    egal(x, "scriptorium:2", "remplacée : sa valeur")
    egal(y, "autre", "remplacée : sa deuxième valeur")
  end)
  avec_remplacement(morceau, "choix", function() return nil end, function()
    egal(Scriptorium.avis(morceau, "choix", 3), "socle:3", "nil : la décision du socle")
  end)
  egal(#FauxJeu.journal_lignes, avant, "rien au journal pour nil")
  avec_remplacement(morceau, "choix", function() error("panne") end, function()
    egal(Scriptorium.avis(morceau, "choix", 4), "socle:4", "en erreur : la décision du socle")
  end)
  egal(lignes_contenant("en erreur"), 1, "l'erreur au journal")
  avec_remplacement(morceau, "choix", function() return 42 end, function()
    egal(Scriptorium.avis(morceau, "choix", 5), "socle:5", "valeur refusée : la décision du socle")
  end)
  egal(lignes_contenant("valeur refusée"), 1, "le refus au journal")
  local oui_non = {}
  function oui_non.permis() return true end
  Scriptorium.remplacable(oui_non, "permis")
  avec_remplacement(oui_non, "permis", function() return false, "non" end, function()
    local p, r = Scriptorium.avis(oui_non, "permis")
    egal(p, false, "un « non » reste non")
    egal(r, "non", "avec sa raison")
  end)
  egal(Scriptorium.decision_du_socle(oui_non, "permis"), oui_non.permis, "la décision du socle, lisible")
  local libre = {}
  function libre.f() return 1 end
  egal(Scriptorium.avis(libre, "f"), 1, "un point non déclaré : la fonction de la table")
  oui_non.permis = nil
  egal(Scriptorium.avis(oui_non, "permis"), true, "la fonction ôtée : la décision du socle")
end)

essai("décisions (fiche 19) : les places libres (A1) ; plus de lit selon Scriptorium, l'embauche refusée ; nil, elle passe", function()
  preparer()
  avec_remplacement(camp, "places_libres", function() return {} end, function()
    local id, r = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
    verifier(not id and r == "pas_de_lit", "aucune place selon Scriptorium : refusé")
  end)
  avec_remplacement(camp, "places_libres", function() return nil end, function()
    verifier(hommes.embaucher({ role = "archer", semaines = 4, prime = 0 }), "nil : les places du socle")
  end)
  avec_remplacement(camp, "places_libres", function() return "boiteux" end, function()
    verifier(hommes.embaucher({ role = "archer", semaines = 4, prime = 0 }), "boiteux : les places du socle")
  end)
end)

essai("décisions (fiche 19) : le plan du camp dans le monde (A19) ; un point du camp suit la remplaçante", function()
  preparer()
  avec_remplacement(camp, "dans_le_monde", function(ancre, x, y, cap) return { x = 1000 + x, y = y, z = 0 }, cap end, function()
    local p = camp.point(3, 4, 0)
    egal(p.x, 1003, "décalé par Scriptorium")
  end)
  local p = camp.point(3, 4, 0)
  verifier(p.x < 1000, "remise : le plan du socle")
  avec_remplacement(camp, "dans_le_monde", function() return { x = "a" } end, function()
    local q = camp.point(3, 4, 0)
    egal(q.x, p.x, "boiteux : le plan du socle")
  end)
end)

essai("décisions (fiche 19) : l'activité d'un homme (A10) ; la tâche de Scriptorium est ordonnée ; nil, celle du socle", function()
  preparer()
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local perso = hommes.fiche(id).personnage
  hommes.battre()
  local socle = Scriptorium.decision_du_socle(hommes, "activite_de")
  avec_remplacement(hommes, "activite_de", function(i, h)
    if i == id then
      return { activite = "pilori", lieu = "pilori", position = { x = 7, y = 7, z = 0 } }
    end
    return socle(i, h)
  end, function()
    FauxJeu.ordres = {}
    hommes.battre()
    local vu = false
    for _, o in ipairs(FauxJeu.ordres) do
      if o.identifiant == perso and o.activite == "pilori" then vu = true end
    end
    verifier(vu, "la tâche de Scriptorium ordonnée")
  end)
  avec_remplacement(hommes, "activite_de", function() return nil end, function()
    local a = Scriptorium.avis(hommes, "activite_de", id, FauxJeu.heure)
    egal(a.activite, socle(id, FauxJeu.heure).activite, "nil : l'activité du socle")
  end)
end)

essai("décisions (fiche 19) : le tour de garde (A28) ; l'homme que Scriptorium met de garde y va", function()
  preparer(14)
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  avec_remplacement(hommes, "gardes", function() return { { id = id, poste = 2 } } end, function()
    local a = Scriptorium.avis(hommes, "activite_de", id, FauxJeu.heure)
    egal(a.activite, "garde", "de garde selon Scriptorium")
    egal(a.lieu, "poste_2", "à son poste")
  end)
  avec_remplacement(hommes, "gardes", function() return {} end, function()
    local a = Scriptorium.avis(hommes, "activite_de", id, FauxJeu.heure)
    verifier(a.activite ~= "garde", "personne de garde selon Scriptorium")
  end)
end)

essai("décisions (fiche 19) : libre pour une règle (A7) ; un homme que Scriptorium retient ne fouille pas", function()
  preparer()
  local id = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  hommes.battre()
  egal(Scriptorium.avis(bataille, "peut_fouiller", id, "bande"), true, "libre : il peut fouiller")
  avec_remplacement(hommes, "libre_pour", function() return false end, function()
    egal(Scriptorium.avis(bataille, "peut_fouiller", id, "bande"), false, "retenu par Scriptorium : il ne fouille pas")
  end)
  avec_remplacement(hommes, "libre_pour", function() return "oui" end, function()
    egal(Scriptorium.avis(bataille, "peut_fouiller", id, "bande"), true, "boiteux : la décision du socle")
  end)
end)

essai("décisions (fiche 19) : le Directeur (A9) ; la tâche de Scriptorium est ordonnée", function()
  preparer()
  directeur.retirer_entrees()
  directeur.installer()
  directeur.battre()
  local perso = directeur.personnage()
  avec_remplacement(directeur, "activite", function()
    return { activite = "retrait", lieu = "retrait", position = { x = 9, y = 9, z = 0 } }
  end, function()
    FauxJeu.ordres = {}
    directeur.battre()
    local vu = false
    for _, o in ipairs(FauxJeu.ordres) do
      if o.identifiant == perso and o.activite == "retrait" then vu = true end
    end
    verifier(vu, "la tâche de Scriptorium ordonnée au Directeur")
  end)
end)

essai("décisions (fiche 19) : la force d'un homme et le niveau d'un camp (missions) suivent les remplaçantes", function()
  preparer()
  local ids = {}
  for i = 1, 2 do ids[i] = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 }) end
  avec_remplacement(bataille, "force_d_un_homme", function() return 50 end, function()
    egal((bataille.force_de(ids)), 100, "la force selon Scriptorium")
  end)
  avec_remplacement(bataille, "force_d_un_homme", function() return -3 end, function()
    local socle = Scriptorium.decision_du_socle(bataille, "force_d_un_homme")
    egal((bataille.force_de(ids)), socle(ids[1]) + socle(ids[2]), "négative : la force du socle")
  end)
  avec_remplacement(missions, "niveau_pour", function() return "grand" end, function()
    egal(Scriptorium.avis(missions, "niveau_pour", 1, "gue"), "grand", "le niveau de Scriptorium")
  end)
  avec_remplacement(missions, "niveau_pour", function() return "immense" end, function()
    egal(Scriptorium.avis(missions, "niveau_pour", 1, "gue"), "petit", "un niveau inconnu : celui du socle")
  end)
end)

essai("décisions (fiche 19) : la taille d'un camp de bandits (A15) ; boiteuse, celle du socle et une ligne au journal", function()
  preparer()
  missions.ajouter_un_lieu("gue_decisions", "trosky", { x = 0, y = 400, z = 0 }, 0)
  FauxJeu.carte = "trosky"
  avec_remplacement(missions, "taille_du_camp", function() return { sorte = "brigands", effectif = -2, coffre = 5 } end, function()
    local id = missions.dresser_un_camp("gue_decisions", "petit")
    verifier(id, "dressé")
    egal(id and missions.camp(id).effectif, 4, "l'effectif du socle")
  end)
  egal(lignes_contenant("taille_du_camp » : valeur refusée"), 1, "le refus au journal")
end)

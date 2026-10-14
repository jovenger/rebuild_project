-- Un scénario complet, avec le battement commun du socle : fondation, Directeur, hommes,
-- enceinte, journée, paie, bande, patrouille, sauvegarde et relecture.

local camp = Scriptorium.camp
local coffre = Scriptorium.coffre
local hommes = Scriptorium.hommes
local bataille = Scriptorium.bataille
local directeur = Scriptorium.directeur
local enceinte = Scriptorium.enceinte
local patrouilles = Scriptorium.patrouilles

essai("scénario : une semaine de la Compagnie, par le battement commun", function()
  depart()
  directeur.retirer_entrees()
  enceinte.installer_les_entrees()
  Scriptorium.atelier.installer_les_entrees()
  patrouilles.installer_les_entrees()
  Scriptorium.discipline.installer_les_entrees()
  FauxJeu.partie = true
  FauxJeu.heure = 9
  FauxJeu.bourse_henry = 2000
  FauxJeu.position_joueur = { x = 500, y = 500, z = 20 }
  FauxJeu.cap_joueur = 90

  -- Henry fonde le camp là où il se tient, installe le Directeur et garnit le coffre.
  verifier(Scriptorium.poste.essai_camp() == "fonde", "camp fondé")
  verifier(directeur.installer(), "Directeur installé")
  verifier(directeur.agir("deposer", { montant = 1500 }), "dépôt")
  egal(FauxJeu.bourse_henry, 500, "bourse d'Henry")
  verifier(directeur.agir("acheter", { sorte = "vivres", quantite = 100 }), "vivres achetés")
  verifier(directeur.agir("acheter", { sorte = "bois", quantite = 150 }), "bois acheté")
  verifier(directeur.agir("acheter", { sorte = "fer", quantite = 5 }), "fer")
  verifier(directeur.agir("acheter", { sorte = "cuir", quantite = 5 }), "cuir")
  local solde_apres_achats = coffre.solde()
  egal(solde_apres_achats, 1500 - 200 - 150 - 25 - 15, "achats au prix juste")

  -- Quatre hommes, l'enceinte, les tours.
  for _, role in ipairs({ "homme_d_armes", "pavoisier", "arbaletrier", "armurier" }) do
    verifier(directeur.agir("engager", { role = role, semaines = 4 }), "engagé : " .. role)
  end
  egal(hommes.effectif().total, 4, "quatre hommes")
  verifier(directeur.agir("batir_enceinte"), "palissade")
  verifier(directeur.agir("batir_tours"), "tours")
  egal(coffre.reserve("bois"), 30, "bois restant")

  -- Le battement commun tourne, heure par heure, pendant sept jours.
  Scriptorium.demarrer()
  local ordres_avant = #FauxJeu.ordres
  local paies, rentrees, batailles_finies = 0, 0, 0
  local patrouille_envoyee, bande_levee = false, false
  for heure = 9, 9 + 7 * 24 do
    FauxJeu.heure = heure
    local rapport = Scriptorium.battre()
    egal(rapport.erreurs, 0, "sans erreur à " .. heure .. " h")
    -- Le deuxième jour à 10 h, une patrouille ; le troisième jour à 14 h, une bande.
    if heure == 24 + 10 and not patrouille_envoyee then
      verifier(directeur.agir("envoyer_patrouille", { chemin = "ronde_proche", hommes = 2 }), "patrouille envoyée")
      patrouille_envoyee = true
    end
    if heure == 48 + 14 and not bande_levee then
      FauxJeu.refuser_ennemis = true
      verifier(bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 45, delai = 2 }), "bande levée")
      bande_levee = true
    end
  end
  verifier(#FauxJeu.ordres > ordres_avant, "des ordres ont été donnés aux hommes")
  egal(patrouilles.en_cours(), nil, "la patrouille est rentrée")
  egal(#patrouilles.journal(), 1, "un compte rendu de patrouille")
  egal(#bataille.bandes(), 0, "la bande est finie")
  verifier(#bataille.resultats() >= 1, "une bataille au journal")
  egal(enceinte.porte(), "ouverte", "porte ouverte à 9 h")
  -- La solde est tombée une fois (le septième jour à 8 h), les vivres ont été mangés chaque jour.
  local lignes_solde, lignes_repas = 0, 0
  for _, l in ipairs(coffre.livre()) do
    if l.motif == "solde" then lignes_solde = lignes_solde + 1 end
    if l.motif == "repas" then lignes_repas = lignes_repas + 1 end
  end
  verifier(lignes_solde >= hommes.effectif().total, "la solde a été payée à chacun")
  verifier(lignes_repas >= 7 * hommes.effectif().total, "des rations chaque jour")
  verifier(coffre.reserve("vivres") < 100, "les vivres ont baissé")
  egal(FauxJeu.bourse_henry, 500, "la bourse d'Henry n'a jamais bougé pour le camp")

  -- Le rapport du Directeur tient.
  local ok, rapport = directeur.agir("rapport")
  verifier(ok and rapport.hommes >= 1 and rapport.groschen >= 0, "rapport")

  -- Sauvegarde, fermeture, relecture : tout revient, les objets et personnages manquants reviennent.
  local chaine = FauxJeu.registre_stocke
  local hommes_avant = #hommes.liste()
  local solde_avant = coffre.solde()
  depart()
  FauxJeu.heure = 9 + 7 * 24 + 1
  FauxJeu.registre_stocke = chaine
  egal(#hommes.liste(), hommes_avant, "hommes relus")
  egal(coffre.solde(), solde_avant, "coffre relu")
  egal(enceinte.niveau(), 2, "enceinte relue")
  local reposes = camp.redresser()
  verifier(reposes > 0, "le camp a été redressé")
  local reposes_enceinte = enceinte.redresser()
  verifier(reposes_enceinte > 0, "l'enceinte a été redressée")
  local revenus = hommes.redresser()
  egal(revenus, hommes_avant, "les hommes sont revenus")
  verifier(directeur.redresser(), "le Directeur est revenu")
  local apres = Scriptorium.battre()
  egal(apres.erreurs, 0, "le battement reprend sans erreur")
  Scriptorium.arreter_le_battement()
end)

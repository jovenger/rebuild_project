-- Essais de la discipline et de la justice du camp (fiche 09_discipline.md).

local discipline = Scriptorium.discipline
local hommes = Scriptorium.hommes
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre
local bataille = Scriptorium.bataille
local directeur = Scriptorium.directeur

local function preparer(nb_hommes, heure)
  depart()
  directeur.retirer_entrees()
  discipline.installer_les_entrees()
  FauxJeu.heure = heure or 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  camp.agrandir()
  coffre.encaisser(1000, "butin")
  coffre.ajouter_reserve("vivres", 500, "achat")
  coffre.ajouter_reserve("biere", 10, "achat")
  local ids = {}
  for _ = 1, (nb_hommes or 0) do
    table.insert(ids, hommes.embaucher({ role = "homme_d_armes", semaines = 8, prime = 0 }))
  end
  directeur.installer()
  discipline.battre()
  Scriptorium.bandeau.remettre_a_zero()
  return ids
end

-- Cherche une graine qui produit une faute de la sorte voulue à la prochaine aube.
local function provoquer(sorte)
  local depart_heure = FauxJeu.heure
  for graine = 1, 2000 do
    bataille.fixer_la_graine(graine)
    FauxJeu.heure = depart_heure + 24
    local rapport = discipline.battre()
    local fautes = discipline.a_juger()
    local trouvee = nil
    for _, f in ipairs(fautes) do
      if f.sorte == sorte then trouvee = f end
    end
    if trouvee then
      return trouvee, graine
    end
    -- Pas la bonne : on nettoie, on soigne tout le monde, et on recommence à l'aube suivante.
    for _, f in ipairs(fautes) do
      discipline.juger(f.id, "pardon")
    end
    for _, id in ipairs(hommes.liste()) do
      if hommes.fiche(id).blessure > 0 then hommes.guerir(id, 10) end
    end
    depart_heure = FauxJeu.heure
  end
  return nil
end

essai("discipline : sans homme, aucune faute ; réputation à 50 au départ", function()
  preparer(0, 10)
  FauxJeu.heure = 34
  local rapport = discipline.battre()
  egal(rapport.aubes, 1, "une aube")
  egal(rapport.fautes, 0, "aucune faute")
  egal(discipline.reputation(), 50, "réputation")
  egal(discipline.facteur_de_prix(), 1, "prix de base")
end)

essai("discipline : la rixe blesse le camarade et coûte du moral aux deux", function()
  local ids = preparer(3, 10)
  local faute = provoquer("rixe")
  verifier(faute ~= nil, "une rixe")
  verifier(faute.victime ~= nil and faute.victime ~= faute.coupable, "une victime autre que le coupable")
  egal(hommes.fiche(faute.victime).blessure, 1, "la victime est blessée un jour")
  verifier(hommes.fiche(faute.coupable).moral < 60, "le coupable a perdu du moral")
  local vus = {}
  Scriptorium.bandeau.battre()
  while Scriptorium.bandeau.en_cours() or Scriptorium.bandeau.en_attente() > 0 do
    table.insert(vus, FauxJeu.en_ecran)
    FauxJeu.avancer(10)
    Scriptorium.bandeau.battre()
  end
  local annonce = false
  for _, v in ipairs(vus) do if v == "@ui_scriptorium_discipline_rixe" then annonce = true end end
  verifier(annonce, "annoncée")
end)

essai("discipline : le vol prend au coffre, au livre", function()
  preparer(2, 10)
  local faute = provoquer("vol")
  verifier(faute ~= nil, "un vol")
  verifier(faute.montant >= 5 and faute.montant <= 20, "de 5 à 20 groschen")
  local ligne = nil
  for _, l in ipairs(coffre.livre()) do
    if l.motif == "vol" then ligne = l end
  end
  verifier(ligne ~= nil and ligne.montant == -faute.montant, "ligne de vol au livre")
end)

essai("discipline : l'ivresse boit la bière et met l'homme hors d'état un jour", function()
  local ids = preparer(2, 10)
  local biere = coffre.reserve("biere")
  local faute = provoquer("ivresse")
  verifier(faute ~= nil, "une ivresse")
  egal(hommes.fiche(faute.coupable).blessure, 1, "hors d'état un jour")
  verifier(coffre.reserve("biere") < biere, "de la bière en moins")
end)

essai("discipline : l'exaction coûte de la réputation, et la justice en rend", function()
  preparer(2, 10)
  local faute = provoquer("exaction")
  verifier(faute ~= nil, "une exaction")
  verifier(discipline.reputation() <= 45, "réputation − 5 (au moins)")
  local avant = discipline.reputation()
  verifier(discipline.juger(faute.id, "amende"), "jugée")
  egal(discipline.reputation(), avant + 2, "justice rendue : + 2")
  verifier(discipline.facteur_de_prix() > 1, "les villages vendent plus cher")
  egal(#discipline.a_juger(), 0, "plus rien à juger")
  egal(discipline.juges()[#discipline.juges()].peine, "amende", "dans les jugés")
end)

essai("discipline : les peines", function()
  local ids = preparer(4, 10)
  -- Chaque faute est jugée dès qu'elle est trouvée.
  local f1 = provoquer("rixe")
  verifier(f1 ~= nil, "première rixe")
  local temoin = (f1.coupable == ids[1]) and ids[3] or ids[1]
  local moral_temoin = hommes.fiche(temoin).moral
  verifier(discipline.juger(f1.id, "pardon"), "pardon")
  egal(hommes.fiche(temoin).moral, moral_temoin - 2, "laxisme : les autres perdent du moral")

  local f2 = provoquer("rixe")
  verifier(f2 ~= nil, "deuxième rixe")
  verifier(discipline.juger(f2.id, "corvee"), "corvée")
  egal(hommes.activite_de(f2.coupable, FauxJeu.heure).activite, "corvee", "en corvée")
  hommes.liberer_affectation(f2.coupable)

  local f3 = provoquer("rixe")
  verifier(f3 ~= nil, "troisième rixe")
  verifier(discipline.juger(f3.id, "pilori"), "pilori")
  verifier(hommes.fiche(f3.coupable).blessure >= 1, "au pilori, hors d'état")
  local ok, raison = discipline.juger(f3.id, "pilori")
  egal(raison, "deja_juge", "déjà jugé")
  ok, raison = discipline.juger("faute_99", "pilori")
  egal(raison, "incident_inconnu", "inconnu")

  local f4 = provoquer("rixe")
  verifier(f4 ~= nil, "quatrième rixe")
  ok, raison = discipline.juger(f4.id, "bucher")
  egal(raison, "peine_inconnue", "peine inconnue")
  verifier(discipline.juger(f4.id, "renvoi"), "renvoi")
  egal(hommes.fiche(f4.coupable), nil, "renvoyé")
end)

essai("discipline : l'amende est retenue sur la prochaine solde", function()
  local ids = preparer(2, 10)
  local faute = provoquer("rixe")
  local coupable = faute.coupable
  verifier(discipline.juger(faute.id, "amende"), "amende")
  egal(hommes.fiche(coupable).retenue, 6, "la moitié de 12")
  local solde_avant = coffre.solde()
  local rapport = hommes.payer_la_solde()
  egal(rapport.payes, 2, "deux payés")
  egal(solde_avant - coffre.solde(), 12 + 6, "l'un plein, l'autre amputé de six")
  egal(hommes.fiche(coupable).retenue, 0, "retenue soldée")
  hommes.retenir(coupable, 100)
  rapport = hommes.payer_la_solde()
  egal(hommes.fiche(coupable).retenue, 88, "ce qui dépasse reste dû")
end)

essai("discipline : la corvée de punition est levée après vingt-quatre heures", function()
  local ids = preparer(2, 10)
  local faute = provoquer("rixe")
  local coupable = faute.coupable
  local heure = FauxJeu.heure
  discipline.juger(faute.id, "corvee")
  FauxJeu.heure = heure + 23
  hommes.battre()
  egal(hommes.activite_de(coupable, FauxJeu.heure).activite, "corvee", "encore en corvée")
  FauxJeu.heure = heure + 24
  hommes.battre()
  verifier(hommes.activite_de(coupable, FauxJeu.heure).activite ~= "corvee" or hommes.affectation_de(coupable) == nil, "libéré")
  egal(hommes.affectation_de(coupable), nil, "affectation levée")
end)

essai("discipline : une faute non jugée deux jours est prescrite, les hommes murmurent", function()
  local ids = preparer(2, 10)
  local faute = provoquer("exaction")
  local reputation = discipline.reputation()
  local moral = hommes.fiche(ids[2]).moral
  bataille.fixer_la_graine(777)
  FauxJeu.heure = FauxJeu.heure + 24
  discipline.battre()
  for _, f in ipairs(discipline.a_juger()) do
    if f.id ~= faute.id then discipline.juger(f.id, "pardon") end
  end
  FauxJeu.heure = FauxJeu.heure + 24
  local rapport = discipline.battre()
  verifier(rapport.prescrites >= 1, "prescrite")
  egal(discipline.reputation(), reputation - 1, "laxisme : réputation − 1")
  verifier(hommes.fiche(ids[2]).moral <= moral - 2, "moral − 2 pour tous")
  local ok, raison = discipline.juger(faute.id, "amende")
  egal(raison, "deja_juge", "trop tard")
end)

essai("discipline : la réputation change le prix des réserves chez le Directeur", function()
  preparer(2, 10)
  egal(directeur.prix_de("vivres"), 2, "prix de base à 50")
  local faute = provoquer("exaction")
  verifier(discipline.reputation() < 50, "réputation en baisse")
  verifier(directeur.cout_de("fer", 10) > 50, "dix fers coûtent plus que cinquante")
  local ok, resultat = directeur.agir("acheter", { sorte = "vivres", quantite = 10 })
  verifier(ok and resultat.cout > 20, "achat au prix des villages")
end)

essai("discipline : entrée de la Gestion du camp", function()
  preparer(2, 10)
  local e
  for _, x in ipairs(directeur.menu()) do
    if x.action == "juger" then e = x end
  end
  egal(e.raison, "rien_a_juger", "rien à juger")
  local faute = provoquer("vol")
  for _, x in ipairs(directeur.menu()) do
    if x.action == "juger" then e = x end
  end
  egal(e.disponible, true, "une faute à juger")
  egal(#e.detail.peines, 5, "cinq peines")
  verifier(directeur.agir("juger", { incident = faute.id, peine = "pilori" }), "jugée par le Directeur")
end)

essai("discipline : tout est relu", function()
  preparer(2, 10)
  local faute = provoquer("rixe")
  local chaine = FauxJeu.registre_stocke
  depart()
  FauxJeu.heure = 40
  FauxJeu.registre_stocke = chaine
  egal(#discipline.a_juger(), 1, "faute relue")
  egal(discipline.a_juger()[1].id, faute.id, "la même")
  egal(discipline.reputation(), 50, "réputation relue")
end)

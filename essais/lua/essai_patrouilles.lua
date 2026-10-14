-- Essais des patrouilles et du battement commun (fiche 08_patrouilles.md).

local patrouilles = Scriptorium.patrouilles
local hommes = Scriptorium.hommes
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre
local bataille = Scriptorium.bataille
local directeur = Scriptorium.directeur

local function preparer(nb_hommes, heure)
  depart()
  directeur.retirer_entrees()
  patrouilles.installer_les_entrees()
  FauxJeu.heure = heure or 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  camp.agrandir()
  camp.agrandir()
  coffre.encaisser(1000, "butin")
  coffre.ajouter_reserve("vivres", 500, "achat")
  local ids = {}
  for _ = 1, (nb_hommes or 0) do
    table.insert(ids, hommes.embaucher({ role = "homme_d_armes", semaines = 8, prime = 0 }))
  end
  directeur.installer()
  Scriptorium.bandeau.remettre_a_zero()
  return ids
end

-- Fait rentrer la patrouille en cours avec l'issue voulue, en cherchant la graine qui la donne.
local function rentrer_avec(issue)
  for graine = 1, 400 do
    bataille.fixer_la_graine(graine)
    local p = patrouilles.en_cours()
    FauxJeu.heure = p.retour
    local solde_avant = coffre.solde()
    patrouilles.battre()
    local j = patrouilles.journal()
    if j[#j].issue == issue then
      return j[#j], graine, solde_avant
    end
    -- Pas la bonne issue : on renvoie la même patrouille.
    FauxJeu.heure = 10
    patrouilles.envoyer({ chemin = p.chemin, hommes = #p.hommes })
  end
  return nil
end

essai("patrouilles : les chemins sont cohérents", function()
  local n = 0
  for nom, chemin in pairs(patrouilles.chemins) do
    n = n + 1
    verifier(#chemin.points >= 3, "au moins trois points : " .. nom)
    verifier(chemin.duree > 0 and chemin.risque >= 0 and chemin.risque <= 1, "durée et risque : " .. nom)
    verifier(bataille.sortes[chemin.embuscade] ~= nil, "sorte d'embuscade connue : " .. nom)
  end
  egal(n, 3, "trois chemins")
end)

essai("patrouilles : envoi, affectations, refus", function()
  depart()
  local ok, raison = patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  egal(raison, "camp_absent", "sans camp")
  local ids = preparer(3, 10)
  ok, raison = patrouilles.envoyer({ chemin = "la_mer", hommes = 2 })
  egal(raison, "chemin_inconnu", "chemin")
  ok, raison = patrouilles.envoyer({ chemin = "ronde_proche", hommes = 1 })
  egal(raison, "effectif_invalide", "trop peu")
  ok, raison = patrouilles.envoyer({ chemin = "ronde_proche", hommes = 7 })
  egal(raison, "effectif_invalide", "trop")
  ok, raison = patrouilles.envoyer({ chemin = "ronde_proche", hommes = 4 })
  egal(raison, "pas_assez_d_hommes", "pas assez")
  local id = patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  egal(id, "patrouille_1", "partie")
  local p = patrouilles.en_cours()
  egal(#p.hommes, 2, "deux hommes")
  egal(p.hommes[1], ids[1], "les plus anciens d'abord")
  egal(p.retour, 12, "retour dans deux heures")
  egal(hommes.activite_de(ids[1], 10).activite, "patrouille", "affecté")
  egal(hommes.activite_de(ids[1], 10).lieu, "ronde_proche_1", "au premier point")
  verifier(math.abs(hommes.activite_de(ids[1], 10).position.y - 30) < 0.01, "trente mètres au nord")
  egal(hommes.activite_de(ids[3], 10).activite ~= "patrouille", true, "le troisième reste")
  ok, raison = patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  egal(raison, "patrouille_en_cours", "une seule à la fois")
  egal(#hommes.gardes(23), 0, "les patrouilleurs ne comptent pas pour la garde")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_patrouille_partie", "annoncé")
end)

essai("patrouilles : la marche passe les points, un ordre par point", function()
  local ids = preparer(2, 10)
  patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  FauxJeu.ordres = {}
  hommes.battre()
  egal(#FauxJeu.ordres, 2, "deux ordres pour le premier point")
  FauxJeu.heure = 10.4
  egal(patrouilles.battre().points, 0, "toujours au premier point")
  FauxJeu.heure = 10.5
  egal(patrouilles.battre().points, 1, "deuxième point")
  egal(patrouilles.en_cours().point, 2, "point 2")
  hommes.battre()
  egal(#FauxJeu.ordres, 4, "deux ordres de plus")
  verifier(math.abs(FauxJeu.ordres[3].position.x - 30) < 0.01, "trente mètres à l'est")
  FauxJeu.heure = 11.6
  patrouilles.battre()
  egal(patrouilles.en_cours().point, 4, "dernier point")
end)

essai("patrouilles : retour sans rencontre, hommes libérés", function()
  local ids = preparer(2, 10)
  patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  local compte_rendu, _, solde_avant = rentrer_avec("rien")
  verifier(compte_rendu ~= nil, "une graine donne « rien »")
  egal(patrouilles.en_cours(), nil, "rentrée")
  egal(hommes.affectation_de(ids[1]), nil, "libéré")
  egal(compte_rendu.butin, 0, "pas de butin")
  egal(coffre.solde(), solde_avant, "le coffre n'a pas bougé")
  verifier(patrouilles.risque_de("ronde_proche") < 0.1, "le risque a baissé")
  local vus = {}
  Scriptorium.bandeau.battre()
  while Scriptorium.bandeau.en_cours() or Scriptorium.bandeau.en_attente() > 0 do
    table.insert(vus, FauxJeu.en_ecran)
    FauxJeu.avancer(10)
    Scriptorium.bandeau.battre()
  end
  egal(vus[#vus], "@ui_scriptorium_patrouille_rien", "rien à signaler")
end)

essai("patrouilles : rôdeurs chassés, butin au coffre", function()
  local ids = preparer(3, 10)
  patrouilles.envoyer({ chemin = "les_bois", hommes = 3 })
  local compte_rendu = rentrer_avec("rodeurs")
  verifier(compte_rendu ~= nil, "une graine donne des rôdeurs")
  verifier(compte_rendu.butin >= 9 and compte_rendu.butin <= 36, "butin de 3 à 12 par homme")
  egal(coffre.solde(), 1000 + compte_rendu.butin, "au coffre")
  egal(coffre.livre(1)[1].motif, "butin_patrouille", "ligne au livre")
  egal(#hommes.liste(), 3, "personne de perdu")
end)

essai("patrouilles : embuscade, pertes, le risque remonte", function()
  local ids = preparer(4, 10)
  patrouilles.envoyer({ chemin = "les_bois", hommes = 3 })
  local compte_rendu, graine = rentrer_avec("embuscade")
  verifier(compte_rendu ~= nil, "une graine donne une embuscade")
  verifier(compte_rendu.issue_du_combat ~= nil, "issue du combat")
  verifier(compte_rendu.morts + compte_rendu.blesses >= 0, "pertes comptées")
  verifier(hommes.fiche(ids[4]) ~= nil and hommes.fiche(ids[4]).blessure == 0, "celui resté au camp n'a rien")
  egal(patrouilles.risque_de("les_bois"), 0.5, "le risque est revenu au plein")
  for _, id in ipairs(hommes.liste()) do
    egal(hommes.affectation_de(id), nil, "libéré : " .. id)
  end
  egal(#bataille.resultats(), 1, "l'escarmouche est dans le journal des batailles")
end)

essai("patrouilles : une ronde proche avance le guet", function()
  preparer(3, 10)
  egal(patrouilles.avance_de_guet(), 0, "sans patrouille")
  patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  egal(patrouilles.avance_de_guet(), 0.5, "une demi-heure")
  bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 1.4 })
  egal(bataille.battre().annoncees, 1, "annoncée une heure et demie avant")
end)

essai("patrouilles : entrée de la Gestion du camp", function()
  preparer(3, 10)
  local e
  for _, x in ipairs(directeur.menu()) do
    if x.action == "envoyer_patrouille" then e = x end
  end
  verifier(e ~= nil and e.disponible, "possible")
  egal(#e.detail.chemins, 3, "trois chemins proposés")
  local ok, id = directeur.agir("envoyer_patrouille", { chemin = "route_du_village", hommes = 2 })
  verifier(ok, "envoyée par le Directeur")
  egal(id, "patrouille_1", "identifiant")
  for _, x in ipairs(directeur.menu()) do
    if x.action == "envoyer_patrouille" then e = x end
  end
  egal(e.raison, "patrouille_en_cours", "plus possible")
end)

essai("socle : le battement commun fait avancer tous les morceaux, seulement en partie", function()
  local ids = preparer(2, 10)
  patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  FauxJeu.partie = false
  FauxJeu.heure = 13
  local rapport = Scriptorium.battre()
  egal(rapport.saute, true, "hors partie : rien")
  verifier(patrouilles.en_cours() ~= nil, "la patrouille n'a pas bougé")
  FauxJeu.partie = true
  rapport = Scriptorium.battre()
  egal(rapport.saute, nil, "en partie : battu")
  egal(patrouilles.en_cours(), nil, "la patrouille est rentrée")
  egal(#rapport.morceaux, 7, "sept morceaux battus")
  egal(rapport.erreurs, 0, "sans erreur")
  -- Un morceau qui casse ne bloque pas les autres.
  Scriptorium.patrouilles.battre = function() error("cassé exprès") end
  rapport = Scriptorium.battre()
  egal(rapport.erreurs, 1, "une erreur comptée")
  egal(#rapport.morceaux, 6, "les six autres ont battu")
  Scriptorium.patrouilles.battre = patrouilles.battre_original
end)

essai("socle : le démarrage pose le battement commun", function()
  depart()
  FauxJeu.partie = true
  Scriptorium.demarrer()
  local trouve = false
  for _, m in ipairs(FauxJeu.minuteries) do
    if m.ms == Scriptorium.cadence_du_battement_ms then trouve = true end
  end
  verifier(trouve, "minuterie du battement posée")
end)

essai("patrouilles : tout est relu", function()
  local ids = preparer(3, 10)
  patrouilles.envoyer({ chemin = "route_du_village", hommes = 2 })
  local chaine = FauxJeu.registre_stocke
  depart()
  FauxJeu.heure = 11
  FauxJeu.registre_stocke = chaine
  local p = patrouilles.en_cours()
  verifier(p ~= nil, "patrouille relue")
  egal(p.chemin, "route_du_village", "chemin")
  egal(#p.hommes, 2, "hommes")
  egal(hommes.affectation_de(ids[1]).activite, "patrouille", "affectation relue")
end)

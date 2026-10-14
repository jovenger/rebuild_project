-- Essais de l'enceinte, de la porte et de l'atelier (fiche 07_enceinte.md).

local enceinte = Scriptorium.enceinte
local atelier = Scriptorium.atelier
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre
local hommes = Scriptorium.hommes
local bataille = Scriptorium.bataille
local directeur = Scriptorium.directeur

local function preparer(bois, heure)
  depart()
  directeur.retirer_entrees()
  enceinte.installer_les_entrees()
  atelier.installer_les_entrees()
  FauxJeu.heure = heure or 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  camp.agrandir()
  coffre.encaisser(1000, "butin")
  coffre.ajouter_reserve("vivres", 500, "achat")
  if bois and bois > 0 then coffre.ajouter_reserve("bois", bois, "achat") end
  directeur.installer()
  Scriptorium.bandeau.remettre_a_zero()
end

local function entree(action)
  for _, e in ipairs(directeur.menu()) do
    if e.action == action then return e end
  end
  return nil
end

essai("enceinte : à l'entrée en partie, pans, porte et tours sont reposés à neuf", function()
  preparer(enceinte.reglages.bois_palissade + enceinte.reglages.bois_tours)
  verifier(enceinte.batir(), "palissade")
  verifier(enceinte.batir(), "tours")
  local retires_avant = #FauxJeu.objets_retires
  local reposes, manquants = enceinte.relancer()
  verifier(reposes > 0, "des objets reposés")
  egal(manquants, 0, "rien ne manque")
  egal(#FauxJeu.objets_retires - retires_avant, reposes, "autant de retirés que de reposés")
end)

essai("enceinte : le plan est cohérent", function()
  local pans, portes, tours = 0, 0, 0
  local noms = {}
  for _, e in ipairs(enceinte.plan) do
    verifier(not noms[e.nom], "nom unique " .. e.nom)
    noms[e.nom] = true
    verifier(enceinte.modeles[e.sorte] ~= nil, "sorte connue " .. e.sorte)
    if e.sorte == "palissade" then pans = pans + 1 end
    if e.sorte == "porte" then portes = portes + 1 end
    if e.sorte == "tour" then tours = tours + 1 end
    local distance = math.sqrt(e.x * e.x + e.y * e.y)
    verifier(distance > 10 and distance < 16, "autour du camp : " .. e.nom)
  end
  egal(pans, 15, "quinze pans")
  egal(portes, 1, "une porte")
  egal(tours, 2, "deux tours")
end)

essai("enceinte : bâtir prend le bois, pose les objets, puis les tours", function()
  preparer(200, 10)
  local ok, raison = enceinte.batir()
  verifier(ok, "bâtie")
  egal(enceinte.niveau(), 1, "niveau 1")
  egal(coffre.reserve("bois"), 120, "quatre-vingts bois pris")
  egal(coffre.livre(1)[1].motif, "palissade", "ligne au livre")
  local poses = 0
  for _, o in ipairs(FauxJeu.objets_poses) do
    if string.find(o.nom, "^enceinte_") then poses = poses + 1 end
  end
  egal(poses, 16, "seize objets posés")
  verifier(enceinte.point_d_entree() ~= nil, "la porte a une position")
  verifier(math.abs(enceinte.point_d_entree().y - 15) < 0.01, "au nord, à quinze mètres")
  verifier(math.abs(enceinte.bonus() - 1.3) < 0.001, "bonus de la palissade")
  egal(enceinte.avance_de_guet(), 0, "pas de tours : pas d'avance")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_enceinte_batie", "annoncé")
  verifier(enceinte.batir(), "tours")
  egal(enceinte.niveau(), 2, "niveau 2")
  egal(coffre.reserve("bois"), 80, "quarante de plus")
  verifier(math.abs(enceinte.bonus() - 1.4) < 0.001, "bonus des tours")
  egal(enceinte.avance_de_guet(), 1, "une heure de guet")
  ok, raison = enceinte.batir()
  egal(raison, "niveau_maximal", "pas de niveau 3")
end)

essai("enceinte : refus sans camp, sans bois", function()
  depart()
  local ok, raison = enceinte.batir()
  egal(raison, "camp_absent", "sans camp")
  preparer(10, 10)
  ok, raison = enceinte.batir()
  egal(raison, "bois_insuffisant", "sans bois")
  egal(enceinte.est_batie(), false, "pas bâtie")
  egal(enceinte.bonus(), 1, "sans bonus")
  egal(enceinte.point_d_entree(), nil, "pas de porte")
  ok, raison = enceinte.fermer()
  egal(raison, "pas_batie", "pas de porte à fermer")
end)

essai("enceinte : la bataille lit le bonus et l'avance de guet", function()
  preparer(200, 10)
  hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local sans = bataille.force_des_notres()
  enceinte.batir()
  enceinte.batir()
  verifier(math.abs(bataille.force_des_notres() - sans * 1.4) < 0.001, "force × 1,4")
  bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 90, delai = 3 })
  FauxJeu.heure = 11
  egal(bataille.battre().annoncees, 1, "annoncée deux heures avant, grâce aux tours")
end)

essai("enceinte : la porte suit l'heure et les bandes, un ordre au changement", function()
  preparer(200, 10)
  enceinte.batir()
  Scriptorium.bandeau.remettre_a_zero()
  FauxJeu.ordres_porte = {}
  egal(enceinte.battre().porte, 0, "ouverte le jour : rien à changer")
  egal(enceinte.porte(), "ouverte", "ouverte")
  FauxJeu.heure = 22
  egal(enceinte.battre().porte, 1, "fermée à 22 h")
  egal(enceinte.porte(), "fermee", "fermée")
  egal(FauxJeu.ordres_porte[1].etat, "fermee", "ordre au jeu")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_enceinte_porte_fermee", "annoncé")
  FauxJeu.heure = 23
  egal(enceinte.battre().porte, 0, "toujours fermée : pas d'ordre")
  FauxJeu.heure = 24 + 6
  egal(enceinte.battre().porte, 1, "ouverte le matin")
  bataille.lever_une_bande({ sorte = "brigands", effectif = 2, direction = 0, delai = 2 })
  egal(enceinte.battre().porte, 1, "barrée dès que la bande est levée")
  egal(enceinte.porte(), "barree", "barrée")
  FauxJeu.refuser_ennemis = true
  FauxJeu.heure = 24 + 8
  bataille.battre()
  egal(enceinte.battre().porte, 1, "rouverte après la bataille")
  egal(enceinte.porte(), "ouverte", "ouverte")
  verifier(enceinte.fermer(), "fermée à la main")
  egal(enceinte.porte(), "fermee", "fermée")
  local ok, raison = enceinte.barrer()
  verifier(ok, "barrée à la main")
end)

essai("enceinte : redressement et démolition", function()
  preparer(200, 10)
  enceinte.batir()
  local avant = #FauxJeu.objets_poses
  egal(enceinte.redresser(), 0, "rien à reposer")
  -- Le dernier objet posé est un pan de palissade : le jeu l'a perdu.
  FauxJeu.objets_existants[FauxJeu.objets_poses[#FauxJeu.objets_poses].identifiant] = nil
  local reposes = enceinte.redresser()
  egal(reposes, 1, "un objet reposé")
  egal(#FauxJeu.objets_poses, avant + 1, "une pose de plus")
  verifier(enceinte.demolir(), "démolie")
  egal(enceinte.est_batie(), false, "plus d'enceinte")
  egal(enceinte.bonus(), 1, "plus de bonus")
  local ok, raison = enceinte.demolir()
  egal(raison, "pas_batie", "déjà démolie")
end)

essai("atelier : recettes, refus, réserves de remèdes et d'onguents", function()
  preparer(0, 10)
  coffre.ajouter_reserve("herbes", 10, "achat")
  coffre.ajouter_reserve("biere", 2, "achat")
  coffre.ajouter_reserve("cuir", 1, "achat")
  local ok, reserve = atelier.preparer("remede", 2)
  verifier(ok, "deux remèdes")
  egal(reserve, 2, "en réserve")
  egal(coffre.reserve("herbes"), 4, "six herbes prises")
  egal(coffre.reserve("biere"), 0, "deux bières prises")
  local raison
  ok, raison = atelier.preparer("remede", 1)
  egal(raison, "ingredients_insuffisants", "plus de bière")
  egal(coffre.reserve("herbes"), 4, "rien pris au refus")
  verifier(atelier.preparer("onguent"), "un onguent")
  egal(coffre.reserve("onguents"), 1, "onguent en réserve")
  ok, raison = atelier.preparer("elixir")
  egal(raison, "recette_inconnue", "recette inconnue")
  ok, raison = atelier.preparer("remede", 0)
  egal(raison, "nombre_invalide", "nombre")
end)

essai("atelier : soigner avec un remède", function()
  preparer(0, 10)
  local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  hommes.blesser(id, 5)
  local ok, raison = atelier.soigner(id)
  egal(raison, "pas_de_remede", "sans remède")
  coffre.ajouter_reserve("remedes", 2, "achat")
  local ok2, reste = atelier.soigner(id)
  verifier(ok2, "soigné")
  egal(reste, 3, "deux jours de moins")
  egal(coffre.reserve("remedes"), 1, "un remède pris")
  atelier.soigner(id)
  egal(hommes.fiche(id).blessure, 1, "un jour")
  ok, raison = atelier.soigner(id)
  egal(raison, "pas_de_remede", "plus de remède")
  hommes.guerir(id, 5)
  egal(hommes.fiche(id).blessure, 0, "guéri sans aller sous zéro")
  ok, raison = atelier.soigner(id)
  egal(raison, "pas_blesse", "plus blessé")
end)

essai("atelier : usure par bataille, poids au combat, entretien par l'armurier", function()
  preparer(0, 6)
  atelier.battre()
  local a = hommes.embaucher({ role = "homme_d_armes", semaines = 4, prime = 0 })
  local b = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  local force = bataille.force_des_notres()
  FauxJeu.refuser_ennemis = true
  for _ = 1, 4 do
    bataille.lever_une_bande({ sorte = "deserteurs", effectif = 1, direction = 0, delai = 0 })
    bataille.battre()
  end
  egal(atelier.usure_de(a), 80, "quatre batailles : usure 80")
  egal(atelier.facteur_de(a), 0.7, "au-delà du seuil : × 0,7")
  verifier(bataille.force_des_notres() < force, "la force baisse avec l'usure")
  local rapport = atelier.entretenir()
  egal(rapport.sans_armurier, true, "pas d'armurier")
  hommes.embaucher({ role = "armurier", semaines = 4, prime = 0 })
  rapport = atelier.entretenir()
  egal(rapport.sans_matiere, true, "pas de fer ni de cuir")
  coffre.ajouter_reserve("fer", 1, "achat")
  coffre.ajouter_reserve("cuir", 5, "achat")
  rapport = atelier.entretenir()
  egal(rapport.repares, 1, "un seul réparé : un seul fer")
  egal(atelier.usure_de(a), 55, "le plus usé d'abord, moins 25")
  egal(coffre.reserve("fer"), 0, "fer pris")
  coffre.ajouter_reserve("fer", 10, "achat")
  FauxJeu.heure = 7.5
  local battu = atelier.battre()
  egal(battu.entretiens, 1, "un entretien par jour, au repas")
  egal(atelier.usure_de(a), 30, "encore moins 25")
  egal(atelier.usure_de(b), 55, "l'archer aussi")
  FauxJeu.heure = 9
  egal(atelier.battre().entretiens, 0, "pas deux fois le même jour")
end)

essai("atelier et enceinte : entrées de la Gestion du camp", function()
  preparer(200, 10)
  egal(entree("batir_enceinte").disponible, true, "on peut bâtir")
  egal(entree("batir_tours").raison, "pas_de_palissade", "pas de tours sans palissade")
  egal(entree("preparer_remede").raison, "ingredients_insuffisants", "pas d'herbes")
  egal(entree("soigner").raison, "pas_de_remede", "pas de remède")
  verifier(directeur.agir("batir_enceinte"), "bâtie par le Directeur")
  egal(entree("batir_enceinte").raison, "deja_batie", "déjà bâtie")
  egal(entree("batir_tours").disponible, true, "tours possibles")
  verifier(directeur.agir("batir_tours"), "tours bâties")
  coffre.ajouter_reserve("herbes", 3, "achat")
  coffre.ajouter_reserve("biere", 1, "achat")
  verifier(directeur.agir("preparer_remede", { nombre = 1 }), "remède par le Directeur")
  local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  hommes.blesser(id, 4)
  egal(entree("soigner").disponible, true, "soigner possible")
  verifier(directeur.agir("soigner", { id = id }), "soigné par le Directeur")
  egal(hommes.fiche(id).blessure, 2, "deux jours de moins")
end)

essai("enceinte et atelier : tout est relu", function()
  preparer(200, 10)
  enceinte.batir()
  enceinte.fermer()
  local id = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  atelier.user(id, 30)
  local chaine = FauxJeu.registre_stocke
  local objets = FauxJeu.objets_existants
  depart()
  FauxJeu.heure = 10
  FauxJeu.registre_stocke = chaine
  FauxJeu.objets_existants = objets
  egal(enceinte.niveau(), 1, "niveau relu")
  egal(enceinte.porte(), "fermee", "porte relue")
  egal(atelier.usure_de(id), 30, "usure relue")
  egal(enceinte.redresser(), 0, "rien à reposer")
end)

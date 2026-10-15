-- Essais du camp (fiche 03_camp.md).

local camp = Scriptorium.camp

local function proche(a, b)
  return math.abs(a - b) < 0.001
end

local function compter_niveau(niveau)
  local n = 0
  for _, e in ipairs(camp.plan) do
    if e.niveau <= niveau then n = n + 1 end
  end
  return n
end

essai("camp : le plan est cohérent", function()
  local vus = {}
  for _, e in ipairs(camp.plan) do
    verifier(not vus[e.nom], "nom unique : " .. e.nom)
    vus[e.nom] = true
    verifier(camp.modeles[e.sorte] ~= nil, "sorte connue : " .. e.sorte)
    verifier(e.niveau >= 1 and e.niveau <= camp.niveau_maximal, "niveau valide : " .. e.nom)
  end
  verifier(compter_niveau(1) >= 10, "le niveau 1 a un vrai camp")
  verifier(compter_niveau(3) > compter_niveau(2) and compter_niveau(2) > compter_niveau(1), "les niveaux ajoutent")
end)

essai("camp : géométrie, rotation et décalage depuis l'ancre", function()
  local p, cap = camp.dans_le_monde({ x = 100, y = 200, z = 5, cap = 0 }, 2, 3, 10)
  verifier(proche(p.x, 102) and proche(p.y, 203) and p.z == 5, "sans rotation")
  egal(cap, 10, "cap additionné")
  p, cap = camp.dans_le_monde({ x = 0, y = 0, z = 0, cap = 90 }, 0, 1, 0)
  verifier(proche(p.x, 1) and proche(p.y, 0), "devant tourné de 90° vers la droite")
  egal(cap, 90, "cap 90")
  p, cap = camp.dans_le_monde({ x = 0, y = 0, z = 0, cap = 180 }, 1, 0, 270)
  verifier(proche(p.x, -1) and proche(p.y, 0), "droite tournée de 180°")
  egal(cap, 90, "cap normalisé (180 + 270 = 450 -> 90)")
end)

essai("camp : le décalage propre au modèle s'ajoute au cap posé", function()
  depart()
  local garde = camp.modeles.siege.decalage
  camp.modeles.siege.decalage = 90
  verifier(camp.fonder({ x = 0, y = 0, z = 0 }, 0), "fondation")
  camp.modeles.siege.decalage = garde
  local caps = {}
  for _, o in ipairs(FauxJeu.objets_poses) do
    caps[o.nom] = o.cap
  end
  egal(caps.siege_3, (180 + 90) % 360, "siège devant le feu : son cap plus le décalage")
  egal(caps.feu_central, 0, "feu sans décalage")
  egal(caps.tente_directeur, 180, "tente sans décalage")
end)

essai("camp : bancs et lits posés comme objets du jeu, le feu allumé", function()
  depart()
  verifier(camp.fonder({ x = 0, y = 0, z = 0 }, 0), "fondation")
  local classes = {}
  for _, o in ipairs(FauxJeu.objets_poses) do
    classes[o.nom] = o.classe or "decor"
  end
  egal(classes.siege_1, "Chair", "banc : Chair")
  egal(classes.lit_1a, "Bed", "lit : Bed")
  egal(classes.tente_1, "decor", "tente : décor")
  verifier(FauxJeu.feux_allumes[camp.objet_de("feu_central")], "le feu central brûle")
  camp.relancer()
  verifier(FauxJeu.feux_allumes[camp.objet_de("feu_central")], "et brûle encore après la relance")
end)

essai("camp : à l'entrée en partie, seuls les objets qui manquent sont reposés (choix de JoVenGer)", function()
  depart()
  egal(camp.reglages.reposer_tout_a_l_entree, 0, "réglage validé : seulement les manquants")
  verifier(camp.fonder({ x = 0, y = 0, z = 0 }, 0), "fondation")
  local avant = #FauxJeu.objets_poses
  local ancien_feu = camp.objet_de("feu_central")
  local reposes, manquants = camp.relancer()
  egal(reposes, 0, "rien à reposer")
  egal(manquants, 0, "rien ne manque")
  egal(#FauxJeu.objets_retires, 0, "rien retiré")
  egal(camp.objet_de("feu_central"), ancien_feu, "le feu garde son identifiant")
  FauxJeu.objets_existants[camp.objet_de("siege_1")] = nil
  reposes, manquants = camp.relancer()
  egal(reposes, 1, "le siège manquant est reposé")
  egal(#FauxJeu.objets_poses, avant + 1, "un seul objet posé de plus")
end)

essai("camp : réglage à 1, à l'entrée en partie, tous les objets sont retirés et reposés à neuf", function()
  depart()
  camp.reglages.reposer_tout_a_l_entree = 1
  verifier(camp.fonder({ x = 0, y = 0, z = 0 }, 0), "fondation")
  local avant = #FauxJeu.objets_poses
  local ancien_feu = camp.objet_de("feu_central")
  local reposes, manquants = camp.relancer()
  camp.reglages.reposer_tout_a_l_entree = 0
  egal(reposes, avant, "autant d'objets reposés que posés")
  egal(manquants, 0, "rien ne manque")
  egal(#FauxJeu.objets_retires, avant + 9, "les anciens retirés, meubles et leurs 9 places du jeu")
  local presents = 0
  for _ in pairs(FauxJeu.objets_existants) do presents = presents + 1 end
  egal(presents, avant + 9, "pas de doublon dans le monde (meubles et places du jeu)")
  verifier(camp.objet_de("feu_central") ~= nil and camp.objet_de("feu_central") ~= ancien_feu, "le feu a un nouvel identifiant")
end)

essai("camp : sans camp, la relance ne pose rien", function()
  depart()
  local reposes, manquants = camp.relancer()
  egal(reposes, 0, "rien reposé")
  egal(manquants, 0, "rien manquant")
  egal(#FauxJeu.objets_poses, 0, "rien posé")
end)

essai("camp : fonder dresse le niveau 1 aux bonnes positions", function()
  depart()
  egal(camp.est_fonde(), false, "pas fondé au départ")
  verifier(camp.fonder({ x = 1000, y = 2000, z = 50 }, 90), "fondation")
  egal(camp.est_fonde(), true, "fondé")
  egal(camp.niveau(), 1, "niveau 1")
  egal(#FauxJeu.objets_poses, compter_niveau(1), "tous les objets du niveau 1 posés")
  local feu = camp.position_de("feu_central")
  verifier(proche(feu.x, 1000) and proche(feu.y, 2000), "le feu est sur l'ancre")
  local tente = camp.position_de("tente_directeur")
  verifier(proche(tente.x, 1007) and proche(tente.y, 2000), "la tente du Directeur, 7 m devant, tournée de 90°")
  verifier(camp.objet_de("feu_central") ~= nil, "identifiant gardé")
  egal(camp.position_de("tente_3"), nil, "un emplacement du niveau 2 n'a pas encore de position")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_camp_dresse", "annoncé au joueur")
  local poses = FauxJeu.objets_poses[1]
  egal(poses.modele, camp.modeles[poses.sorte].chemin, "le modèle du jeu de base est passé par son chemin")
end)

essai("camp : double fondation et position invalide refusées", function()
  depart()
  local ok, raison = camp.fonder("ici", 0)
  egal(ok, false, "position invalide refusée")
  egal(raison, "position_invalide", "raison")
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  ok, raison = camp.fonder({ x = 1, y = 1, z = 1 }, 0)
  egal(ok, false, "double fondation refusée")
  egal(raison, "deja_fonde", "raison")
  ok, raison = camp.agrandir()
  verifier(ok, "agrandir possible après fondation")
  depart()
  ok, raison = camp.agrandir()
  egal(raison, "pas_fonde", "agrandir sans camp refusé")
  ok, raison = camp.lever()
  egal(raison, "pas_fonde", "lever sans camp refusé")
end)

essai("camp : un objet que le jeu refuse de poser est noté, les autres sont posés", function()
  depart()
  FauxJeu.refuser_pose["tente_1"] = true
  verifier(camp.fonder({ x = 0, y = 0, z = 0 }, 0), "fondation malgré le refus")
  egal(#FauxJeu.objets_poses, compter_niveau(1) - 1, "un de moins")
  egal(camp.objet_de("tente_1"), nil, "pas d'identifiant pour l'objet manquant")
  local trouve = false
  for _, ligne in ipairs(FauxJeu.journal_lignes) do
    if string.find(ligne, "tente_1", 1, true) then trouve = true end
  end
  verifier(trouve, "noté au journal")
  FauxJeu.refuser_pose["tente_1"] = nil
  local reposes = camp.redresser()
  egal(reposes, 1, "redresser repose l'objet manquant")
  egal(camp.objet_de("tente_1") ~= nil, true, "identifiant maintenant gardé")
end)

essai("camp : agrandir ajoute les niveaux, jusqu'au maximum", function()
  depart()
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  verifier(camp.agrandir(), "niveau 2")
  egal(camp.niveau(), 2, "niveau 2")
  egal(#FauxJeu.objets_poses, compter_niveau(2), "objets du niveau 2 posés")
  verifier(camp.position_de("tente_3") ~= nil, "la tente 3 a une position")
  verifier(camp.agrandir(), "niveau 3")
  egal(#FauxJeu.objets_poses, compter_niveau(3), "objets du niveau 3 posés")
  local ok, raison = camp.agrandir()
  egal(ok, false, "pas de niveau 4")
  egal(raison, "niveau_maximal", "raison")
  local capacite = camp.capacite()
  egal(capacite.lits, 13, "treize lits au niveau 3")
  egal(capacite.sieges, 8, "huit sièges au niveau 3")
end)

essai("camp : redresser ne repose que ce qui manque", function()
  depart()
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  local avant = #FauxJeu.objets_poses
  local reposes, manquants = camp.redresser()
  egal(reposes, 0, "rien à reposer quand tout existe")
  egal(manquants, 0, "rien ne manque")
  egal(#FauxJeu.objets_poses, avant, "aucune pose de plus")
  -- Le jeu a perdu deux objets (par exemple après un chargement).
  FauxJeu.objets_existants[camp.objet_de("siege_1")] = nil
  FauxJeu.objets_existants[camp.objet_de("lit_1a")] = nil
  reposes = camp.redresser()
  egal(reposes, 2, "les deux manquants reposés")
  egal(#FauxJeu.objets_poses, avant + 2, "deux poses de plus")
  verifier(FauxJeu.objets_existants[camp.objet_de("siege_1")], "le siège existe à nouveau")
end)

essai("camp : redresser sans aucun homme marche, et sans camp ne fait rien", function()
  depart()
  local reposes, manquants = camp.redresser()
  egal(reposes, 0, "sans camp : rien")
  egal(manquants, 0, "sans camp : rien ne manque")
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  for identifiant in pairs(FauxJeu.objets_existants) do
    FauxJeu.objets_existants[identifiant] = nil
  end
  reposes = camp.redresser()
  egal(reposes, compter_niveau(1), "tout reposé, sans aucun homme")
end)

essai("camp : meubles utilisables, une place du jeu sur chaque banc et chaque lit (fiche 03, V62, V65)", function()
  depart()
  verifier(camp.fonder({ x = 100, y = 200, z = 5 }, 90), "fondation")
  egal(#FauxJeu.objets_du_jeu, 9, "quatre bancs et cinq lits au niveau 1 : neuf places du jeu")
  local par_nom = {}
  for _, o in ipairs(FauxJeu.objets_du_jeu) do par_nom[o.nom] = o end
  local siege, lit = par_nom["siege_1_assise"], par_nom["lit_1a_couche"]
  verifier(siege ~= nil and lit ~= nil, "places nommées d'après leur meuble")
  egal(siege.proprietes.soclass_SmartObjectHelpers, "Sit_1Place_Bench_Low", "le banc : un siège bas")
  egal(lit.proprietes.soclass_SmartObjectHelpers, "Bed_1Place_Tent", "le lit : un lit de tente (choix de JoVenGer)")
  local meuble
  for _, o in ipairs(FauxJeu.objets_poses) do if o.nom == "siege_1" then meuble = o end end
  verifier(proche(siege.position.x, meuble.position.x) and proche(siege.position.y, meuble.position.y), "la place est sur son meuble")
  egal(siege.cap, (meuble.cap + 180) % 360, "un demi-tour par rapport au banc : face au feu (V66)")
  egal(camp.objet_du_jeu_de("siege_1"), siege.identifiant, "objet du jeu d'une place du camp")
  egal(camp.objet_du_jeu_de("feu_central"), nil, "le feu n'a pas de place")
  -- Après un chargement, rien du camp n'est gardé (V64) : tout est reposé, places comprises, sans doublon.
  FauxJeu.objets_existants = {}
  local reposes = camp.redresser()
  egal(reposes, compter_niveau(1), "tous les meubles reposés")
  egal(#FauxJeu.objets_du_jeu, 18, "et leurs neuf places")
  verifier(camp.objet_du_jeu_de("siege_1") ~= siege.identifiant, "l'objet du jeu change d'identifiant, relu à chaque fois")
  -- Une place perdue seule est reposée seule.
  FauxJeu.objets_existants[camp.objet_du_jeu_de("lit_1a")] = nil
  egal(camp.redresser(), 0, "aucun meuble à reposer")
  egal(#FauxJeu.objets_du_jeu, 19, "seule la place perdue est reposée")
end)

essai("camp : lever retire tout et permet une nouvelle fondation", function()
  depart()
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  camp.reserver("lit_1a", "jan")
  Scriptorium.bandeau.battre()
  FauxJeu.avancer(10)
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, nil, "le message de fondation est passé")
  verifier(camp.lever(), "levée")
  egal(camp.est_fonde(), false, "plus fondé")
  egal(#FauxJeu.objets_retires, compter_niveau(1) + 9, "tous retirés, avec les 9 places du jeu des bancs et des lits")
  local reste = 0
  for _ in pairs(FauxJeu.objets_existants) do reste = reste + 1 end
  egal(reste, 0, "plus rien dans le jeu")
  egal(camp.occupant_de("lit_1a"), nil, "places oubliées")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_camp_leve", "annoncé")
  verifier(camp.fonder({ x = 5, y = 5, z = 5 }, 45), "nouvelle fondation possible")
end)

essai("camp : places réservées et libérées", function()
  depart()
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  egal(#camp.places_libres("lit"), 5, "cinq lits libres au niveau 1")
  egal(#camp.places_libres("siege"), 4, "quatre sièges libres")
  egal(#camp.places_libres("tente"), 0, "une tente n'est pas une place")
  verifier(camp.reserver("lit_1a", "jan"), "réservation")
  egal(camp.occupant_de("lit_1a"), "jan", "occupant")
  egal(#camp.places_libres("lit"), 4, "quatre lits libres")
  local ok, raison = camp.reserver("lit_1a", "ondrej")
  egal(raison, "place_prise", "place prise")
  ok, raison = camp.reserver("tente_1", "ondrej")
  egal(raison, "place_inconnue", "une tente ne se réserve pas")
  ok, raison = camp.reserver("lit_3a", "ondrej")
  egal(raison, "place_inconnue", "un lit du niveau 2 n'existe pas encore")
  ok, raison = camp.liberer("lit_1b")
  egal(raison, "place_libre", "libérer une place libre")
  verifier(camp.liberer("lit_1a"), "libération")
  egal(#camp.places_libres("lit"), 5, "cinq lits libres à nouveau")
end)

essai("camp : tout est écrit dans la partie et relu tel quel", function()
  depart()
  camp.fonder({ x = 10, y = 20, z = 30 }, 45)
  camp.agrandir()
  camp.reserver("siege_5", "mikulas")
  local feu = camp.objet_de("feu_central")
  local chaine = FauxJeu.registre_stocke
  local existants = FauxJeu.objets_existants

  depart()
  FauxJeu.registre_stocke = chaine
  FauxJeu.objets_existants = existants
  egal(camp.est_fonde(), true, "fondé relu")
  egal(camp.niveau(), 2, "niveau relu")
  egal(camp.objet_de("feu_central"), feu, "identifiant relu")
  egal(camp.occupant_de("siege_5"), "mikulas", "place relue")
  local p = camp.position_de("feu_central")
  verifier(proche(p.x, 10) and proche(p.y, 20) and p.z == 30, "ancre relue")
  local reposes = camp.redresser()
  egal(reposes, 0, "rien à reposer : les objets existent encore")
end)

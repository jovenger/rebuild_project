-- Le camp : tentes, lits, feux, sièges, coffre. Sa fondation, son agrandissement,
-- son redressement après un chargement, sa levée.
-- Fiche de comportement : docs/socle/fiches/03_camp.md

Scriptorium = Scriptorium or {}

local camp = {}
Scriptorium.camp = camp

camp.niveau_maximal = 3
camp.proprietaire = "JoVenGer"

-- Les sortes d'objets et leur modèle du jeu de base, appelé par son chemin.
-- Chemins relevés le 14/10 dans les paks du jeu (IPL_Objects-part*.pak) ; les anciens donnaient une forme blanche.
-- Le jeu n'a pas de modèle de feu de camp : un tas de branches en tient lieu, un vrai feu qui brûle
-- est une entité à part (V23). « decalage » : quart de tour propre au modèle, en degrés de boussole ;
-- le banc de rondin a son long côté dans son sens « devant » (vu en jeu le 14/10 : il pointait vers le feu).
camp.modeles = {
  feu    = { chemin = "Objects/manmade/task_specific_props/household/firewood/branches/firewood_branches_a.cgf" },
  siege  = { chemin = "Objects/manmade/common_furniture/benches/low/bench_log_a.cgf", decalage = 90 },
  tente  = { chemin = "Objects/manmade/structures/living/tents/tent_small_a.cgf" },
  lit    = { chemin = "Objects/manmade/common_furniture/beds/low/bed_makeshift_a.cgf" },
  coffre = { chemin = "Objects/manmade/common_furniture/chests/chest-small-a.cgf" },
}

-- Les sortes qui sont des places (un homme peut les prendre).
camp.sortes_places = { lit = true, siege = true }

-- Le plan du camp : positions en mètres par rapport à l'ancre (x à droite, y devant),
-- cap en degrés (0 = devant, sens des aiguilles d'une montre vu de dessus), niveau 1 à 3.
local function emplacement(nom, sorte, x, y, cap, niveau, reserve)
  return { nom = nom, sorte = sorte, x = x, y = y, cap = cap, niveau = niveau, reserve = reserve }
end

camp.plan = {
  -- Niveau 1 : le feu, quatre sièges, la tente du Directeur, deux tentes, le coffre.
  emplacement("feu_central", "feu", 0, 0, 0, 1),
  emplacement("siege_1", "siege", 1.6, 0, 270, 1),
  emplacement("siege_2", "siege", -1.6, 0, 90, 1),
  emplacement("siege_3", "siege", 0, 1.6, 180, 1),
  emplacement("siege_4", "siege", 0, -1.6, 0, 1),
  emplacement("tente_directeur", "tente", 0, 7, 180, 1),
  emplacement("lit_directeur", "lit", 0, 8, 180, 1, "directeur"),
  emplacement("coffre_camp", "coffre", 1.4, 7.5, 180, 1),
  emplacement("tente_1", "tente", -6, 4, 135, 1),
  emplacement("lit_1a", "lit", -6.6, 4.6, 135, 1),
  emplacement("lit_1b", "lit", -5.4, 5.2, 135, 1),
  emplacement("tente_2", "tente", 6, 4, 225, 1),
  emplacement("lit_2a", "lit", 6.6, 4.6, 225, 1),
  emplacement("lit_2b", "lit", 5.4, 5.2, 225, 1),
  -- Niveau 2 : deux tentes de plus, quatre lits, deux sièges.
  emplacement("tente_3", "tente", -6, -3, 45, 2),
  emplacement("lit_3a", "lit", -6.6, -3.6, 45, 2),
  emplacement("lit_3b", "lit", -5.4, -4.2, 45, 2),
  emplacement("tente_4", "tente", 6, -3, 315, 2),
  emplacement("lit_4a", "lit", 6.6, -3.6, 315, 2),
  emplacement("lit_4b", "lit", 5.4, -4.2, 315, 2),
  emplacement("siege_5", "siege", 1.2, 1.2, 225, 2),
  emplacement("siege_6", "siege", -1.2, -1.2, 45, 2),
  -- Niveau 3 : un second feu avec ses sièges, deux tentes de plus, quatre lits.
  emplacement("feu_2", "feu", 0, -9, 0, 3),
  emplacement("siege_7", "siege", 1.6, -9, 270, 3),
  emplacement("siege_8", "siege", -1.6, -9, 90, 3),
  emplacement("tente_5", "tente", -7, -11, 45, 3),
  emplacement("lit_5a", "lit", -7.6, -11.6, 45, 3),
  emplacement("lit_5b", "lit", -6.4, -12.2, 45, 3),
  emplacement("tente_6", "tente", 7, -11, 315, 3),
  emplacement("lit_6a", "lit", 7.6, -11.6, 315, 3),
  emplacement("lit_6b", "lit", 6.4, -12.2, 315, 3),
}

local function jeu()
  return Scriptorium.jeu
end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return {
    fonde = false,
    ancre = { x = 0, y = 0, z = 0, cap = 0 },
    niveau = 0,
    proprietaire = camp.proprietaire,
    objets = {},   -- nom -> { identifiant }
    places = {},   -- nom -> qui
  }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("camp") then
    registre.declarer_case("camp", 1, donnees_neuves)
  end
  return registre.lire("camp")
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

local function refuser(raison, detail)
  jeu().journal("Camp : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

-- ---------------------------------------------------------------- géométrie

local function normaliser_cap(cap)
  cap = cap % 360
  if cap < 0 then cap = cap + 360 end
  return cap
end

-- Position et cap dans le monde d'un point (x, y, cap) donné par rapport à une ancre.
function camp.dans_le_monde(ancre, x, y, cap)
  local radians = math.rad(ancre.cap)
  local cosinus, sinus = math.cos(radians), math.sin(radians)
  -- Un cap positif tourne dans le sens des aiguilles d'une montre vu de dessus.
  local monde_x = ancre.x + x * cosinus + y * sinus
  local monde_y = ancre.y - x * sinus + y * cosinus
  return { x = monde_x, y = monde_y, z = ancre.z }, normaliser_cap(ancre.cap + (cap or 0))
end

-- Un point du camp (x, y, cap par rapport à l'ancre) dans le monde, ou nil sans camp.
function camp.point(x, y, cap)
  local d = donnees()
  if not d.fonde then
    return nil
  end
  local position = camp.dans_le_monde(d.ancre, x, y, cap)
  return position
end

local function emplacement_par_nom(nom)
  for _, e in ipairs(camp.plan) do
    if e.nom == nom then
      return e
    end
  end
  return nil
end

local function position_valide(position)
  return type(position) == "table"
    and type(position.x) == "number" and type(position.y) == "number" and type(position.z) == "number"
end

-- ---------------------------------------------------------------- pose

-- Pose un emplacement s'il ne l'est pas déjà. Rend vrai si l'objet est en place.
local function poser(d, e)
  local objet = d.objets[e.nom]
  if objet and objet.identifiant and jeu().objet_existe(objet.identifiant) then
    return true
  end
  local modele = camp.modeles[e.sorte]
  local position, cap = camp.dans_le_monde(d.ancre, e.x, e.y, e.cap)
  cap = (cap + (modele.decalage or 0)) % 360
  local identifiant = jeu().poser_objet(e.sorte, modele.chemin, position, cap, e.nom)
  if identifiant == nil then
    jeu().journal("Camp : le jeu n'a pas posé « " .. e.nom .. " » (" .. e.sorte .. ")")
    return false
  end
  d.objets[e.nom] = { identifiant = identifiant }
  return true
end

-- Dresse tous les emplacements jusqu'au niveau courant. Rend (posés, manquants).
local function dresser(d)
  local poses, manquants = 0, 0
  for _, e in ipairs(camp.plan) do
    if e.niveau <= d.niveau then
      if poser(d, e) then poses = poses + 1 else manquants = manquants + 1 end
    end
  end
  return poses, manquants
end

-- ---------------------------------------------------------------- fondation, agrandissement, levée

function camp.est_fonde()
  return donnees().fonde
end

function camp.niveau()
  return donnees().niveau
end

function camp.fonder(position, cap)
  local d = donnees()
  if d.fonde then
    return refuser("deja_fonde")
  end
  if not position_valide(position) then
    return refuser("position_invalide", tostring(position))
  end
  d.fonde = true
  d.ancre = { x = position.x, y = position.y, z = position.z, cap = normaliser_cap(cap or 0) }
  d.niveau = 1
  d.proprietaire = camp.proprietaire
  d.objets = {}
  d.places = {}
  local poses, manquants = dresser(d)
  enregistrer()
  jeu().journal("Camp : fondé, niveau 1, " .. poses .. " objet(s) posé(s), " .. manquants .. " manquant(s)")
  annoncer("ui_scriptorium_camp_dresse")
  return true
end

function camp.agrandir()
  local d = donnees()
  if not d.fonde then
    return refuser("pas_fonde")
  end
  if d.niveau >= camp.niveau_maximal then
    return refuser("niveau_maximal", tostring(d.niveau))
  end
  d.niveau = d.niveau + 1
  local poses, manquants = dresser(d)
  enregistrer()
  jeu().journal("Camp : agrandi au niveau " .. d.niveau .. ", " .. poses .. " objet(s) en place, " .. manquants .. " manquant(s)")
  annoncer("ui_scriptorium_camp_agrandi")
  return true
end

-- Après un chargement : repose ce qui manque, sans toucher au reste. Rend (reposés, manquants).
function camp.redresser()
  local d = donnees()
  if not d.fonde then
    return 0, 0
  end
  local reposes, manquants = 0, 0
  for _, e in ipairs(camp.plan) do
    if e.niveau <= d.niveau then
      local objet = d.objets[e.nom]
      local present = objet and objet.identifiant and jeu().objet_existe(objet.identifiant)
      if not present then
        if poser(d, e) then reposes = reposes + 1 else manquants = manquants + 1 end
      end
    end
  end
  if reposes > 0 or manquants > 0 then
    enregistrer()
  end
  jeu().journal("Camp : redressé, " .. reposes .. " objet(s) reposé(s), " .. manquants .. " manquant(s)")
  return reposes, manquants
end

function camp.lever()
  local d = donnees()
  if not d.fonde then
    return refuser("pas_fonde")
  end
  local retires = 0
  for nom, objet in pairs(d.objets) do
    if objet.identifiant then
      jeu().retirer_objet(objet.identifiant)
      retires = retires + 1
    end
    d.objets[nom] = nil
  end
  d.fonde = false
  d.niveau = 0
  d.places = {}
  d.ancre = { x = 0, y = 0, z = 0, cap = 0 }
  enregistrer()
  jeu().journal("Camp : levé, " .. retires .. " objet(s) retiré(s)")
  annoncer("ui_scriptorium_camp_leve")
  return true
end

-- ---------------------------------------------------------------- places et positions

function camp.position_de(nom)
  local d = donnees()
  local e = emplacement_par_nom(nom)
  if not d.fonde or not e or e.niveau > d.niveau then
    return nil
  end
  return camp.dans_le_monde(d.ancre, e.x, e.y, e.cap)
end

function camp.objet_de(nom)
  local objet = donnees().objets[nom]
  return objet and objet.identifiant or nil
end

-- Les places libres d'une sorte (« lit » ou « siege »), dans l'ordre du plan.
-- Avec « pour », les places réservées à quelqu'un d'autre sont écartées.
function camp.places_libres(sorte, pour)
  local d = donnees()
  local libres = {}
  if not d.fonde then
    return libres
  end
  for _, e in ipairs(camp.plan) do
    if e.sorte == sorte and camp.sortes_places[sorte] and e.niveau <= d.niveau and d.places[e.nom] == nil
       and (pour == nil or e.reserve == nil or e.reserve == pour) then
      table.insert(libres, e.nom)
    end
  end
  return libres
end

function camp.occupant_de(nom)
  return donnees().places[nom]
end

function camp.reserver(nom, qui)
  local d = donnees()
  local e = emplacement_par_nom(nom)
  if not d.fonde or not e or not camp.sortes_places[e.sorte] or e.niveau > d.niveau then
    return refuser("place_inconnue", tostring(nom))
  end
  if d.places[nom] ~= nil then
    return refuser("place_prise", nom .. " par " .. tostring(d.places[nom]))
  end
  d.places[nom] = qui
  enregistrer()
  return true
end

function camp.liberer(nom)
  local d = donnees()
  if d.places[nom] == nil then
    return refuser("place_libre", tostring(nom))
  end
  d.places[nom] = nil
  enregistrer()
  return true
end

-- Nombre de lits et de sièges au niveau courant.
function camp.capacite()
  local d = donnees()
  local lits, sieges = 0, 0
  if d.fonde then
    for _, e in ipairs(camp.plan) do
      if e.niveau <= d.niveau then
        if e.sorte == "lit" then lits = lits + 1 end
        if e.sorte == "siege" then sieges = sieges + 1 end
      end
    end
  end
  return { lits = lits, sieges = sieges, niveau = d.niveau }
end

Scriptorium.declarer_morceau("camp", function()
  -- Au démarrage du jeu, aucune partie n'est chargée : le redressement se fait
  -- au chargement d'une partie (voir registre.invalider et la liaison).
end)

-- L'enceinte : palissade, porte, tours de guet. Bâtie contre du bois, posée comme le camp.
-- Fiche de comportement : docs/socle/fiches/07_enceinte.md

Scriptorium = Scriptorium or {}

local enceinte = {}
Scriptorium.enceinte = enceinte

enceinte.reglages = {
  rayon = 20,             -- plus grande, à la validation de la fiche par JoVenGer (14/10 ; d'abord 15 m)
  pans = 22,
  bois_palissade = 80,
  bois_tours = 40,
  bonus_palissade = 1.3,
  bonus_tours = 1.4,
  avance_de_guet = 1,     -- heures d'avertissement en plus avec les tours
  heure_fermeture = 22,
  heure_ouverture = 5,
}

enceinte.niveau_maximal = 2

-- Modèles du jeu de base, appelés par leur chemin, relevés le 14/10 dans les paks du jeu.
-- Mesures lues dans les paks (boîtes englobantes) et vues en jeu le 14/10 :
-- - « decalage » : quart de tour propre au modèle ; le portail est long sur son axe y, il faut le tourner ;
-- - « centre » : le centre du modèle par rapport à son point de pose, en mètres (x à droite, y devant) ;
--   le pan pose à une extrémité, le portail à son gond.
-- Le pan fait 8,3 m, le portail 4 m (le premier modèle de pan, 2,4 m, laissait des trous). Vu en jeu : seize pans
-- fermaient un cercle de 15 m. Sur 20 m, seize pans laisseraient près de 1,7 m ouvert de chaque côté du portail ;
-- vingt-deux pans (5,7 m de l'un à l'autre) le ferment, les pans voisins chevauchant le portail de 0,4 m.
enceinte.modeles = {
  palissade = { chemin = "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_b_v4.cgf",
                centre = { x = -3.85, y = 0.12 }, longueur = 8.3 },
  porte     = { chemin = "Objects/manmade/structures/logistical/fences/fence_4rod_gate_02.cgf", decalage = 90,
                centre = { x = 0, y = 1.48 }, longueur = 4 },
  tour      = { chemin = "Objects/manmade/structures/defensive/watchtowers/watchtower_a.cgf" },
}

-- Le plan : pans sur un cercle, la porte au nord, deux tours au niveau 2.
local function faire_le_plan()
  local plan = {}
  local r = enceinte.reglages
  for i = 0, r.pans - 1 do
    local cap = i * (360 / r.pans)
    local radians = math.rad(cap)
    local x, y = r.rayon * math.sin(radians), r.rayon * math.cos(radians)
    if i == 0 then
      table.insert(plan, { nom = "porte", sorte = "porte", x = x, y = y, cap = cap, niveau = 1 })
    else
      table.insert(plan, { nom = "pan_" .. i, sorte = "palissade", x = x, y = y, cap = cap, niveau = 1 })
    end
  end
  table.insert(plan, { nom = "tour_est", sorte = "tour", x = r.rayon * 0.75, y = r.rayon * 0.75, cap = 45, niveau = 2 })
  table.insert(plan, { nom = "tour_ouest", sorte = "tour", x = -r.rayon * 0.75, y = r.rayon * 0.75, cap = 315, niveau = 2 })
  return plan
end
enceinte.plan = faire_le_plan()

local function jeu() return Scriptorium.jeu end
local function camp() return Scriptorium.camp end
local function coffre() return Scriptorium.coffre end

-- Refait le plan d'après les réglages (rayon et pans réglables par fichier, fiche 10). Vrai s'il a changé.
function enceinte.refaire_le_plan()
  local avant = enceinte.plan
  enceinte.plan = faire_le_plan()
  if #avant ~= #enceinte.plan then
    return true
  end
  for i, e in ipairs(enceinte.plan) do
    if e.nom ~= avant[i].nom or math.abs(e.x - avant[i].x) > 1e-6 or math.abs(e.y - avant[i].y) > 1e-6 then
      return true
    end
  end
  return false
end

-- Ce qu'occupe le camp, du feu au plus loin : emplacements du camp à tous les niveaux, postes de garde,
-- points d'exercice et de corvée.
local function emprise_du_camp()
  local plus_loin = 0
  local function mesurer(liste)
    for _, point in pairs(liste or {}) do
      if type(point) == "table" and type(point.x) == "number" and type(point.y) == "number" then
        plus_loin = math.max(plus_loin, math.sqrt(point.x * point.x + point.y * point.y))
      end
    end
  end
  if Scriptorium.camp then mesurer(Scriptorium.camp.plan) end
  if Scriptorium.hommes then
    mesurer(Scriptorium.hommes.postes_de_garde)
    mesurer(Scriptorium.hommes.points)
  end
  return plus_loin
end

-- La forme réglée tient-elle ? Au moins trois pans ; le cercle fermé (d'un pan à l'autre moins que la longueur
-- d'un pan, et les pans voisins atteignent la porte) ; le rayon au-delà de l'emprise du camp, plus la marge.
-- Rend vrai, ou faux et la raison.
enceinte.marge_autour_du_camp = 2
function enceinte.verifier_reglages()
  local r = enceinte.reglages
  if type(r.pans) ~= "number" or r.pans < 3 or math.floor(r.pans) ~= r.pans then
    return false, "pans_invalides"
  end
  if type(r.rayon) ~= "number" or r.rayon <= 0 then
    return false, "rayon_invalide"
  end
  local ecart = 2 * r.rayon * math.sin(math.pi / r.pans)
  local pan, porte = enceinte.modeles.palissade.longueur, enceinte.modeles.porte.longueur
  if ecart >= pan or ecart - pan / 2 > porte / 2 then
    return false, "cercle_ouvert"
  end
  if r.rayon < emprise_du_camp() + enceinte.marge_autour_du_camp then
    return false, "rayon_dans_le_camp"
  end
  return true
end

-- Après une application des réglages (morceau « reglages ») : le plan est refait ; une enceinte bâtie dont le plan a
-- changé est retirée et reposée aussitôt, en cours de partie comme à l'entrée (l'enceinte se relance avant les
-- réglages : un fichier changé pendant que le jeu était au menu la laisserait sur l'ancien cercle). Au lancement,
-- aucune partie n'est chargée : rien à reposer.
function enceinte.apres_reglages(moment)
  local change = enceinte.refaire_le_plan()
  if change and moment ~= "lancement" and enceinte.est_batie() then
    enceinte.relancer()
  end
  return change
end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return { batie = false, niveau = 0, objets = {}, porte = { etat = "ouverte", voulu = "ouverte" } }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("enceinte") then
    registre.declarer_case("enceinte", 1, donnees_neuves)
  end
  return registre.lire("enceinte")
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

local function refuser(raison, detail)
  jeu().journal("Enceinte : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

-- ---------------------------------------------------------------- pose

local function poser(d, e)
  local objet = d.objets[e.nom]
  if objet and objet.identifiant and jeu().objet_existe(objet.identifiant) then
    return true
  end
  -- Le cap tient compte de l'orientation du camp (vu le 14/10 : il l'ignorait), plus le quart de tour du modèle.
  local modele = enceinte.modeles[e.sorte]
  local position, cap = camp().point(e.x, e.y, e.cap)
  cap = (cap + (modele.decalage or 0)) % 360
  if modele.centre then
    -- Le point de pose est placé pour que le centre du modèle tombe sur l'emplacement.
    local a = math.rad(cap)
    local droite = { x = math.cos(a), y = -math.sin(a) }
    local devant = { x = math.sin(a), y = math.cos(a) }
    position = { x = position.x - modele.centre.x * droite.x - modele.centre.y * devant.x,
                 y = position.y - modele.centre.x * droite.y - modele.centre.y * devant.y,
                 z = position.z }
  end
  local identifiant = jeu().poser_objet(e.sorte, modele.chemin, position, cap, "enceinte_" .. e.nom)
  if identifiant == nil then
    jeu().journal("Enceinte : le jeu n'a pas posé « " .. e.nom .. " »")
    return false
  end
  d.objets[e.nom] = { identifiant = identifiant }
  return true
end

local function dresser(d)
  local poses, manquants = 0, 0
  for _, e in ipairs(enceinte.plan) do
    if e.niveau <= d.niveau then
      if poser(d, e) then poses = poses + 1 else manquants = manquants + 1 end
    end
  end
  return poses, manquants
end

-- ---------------------------------------------------------------- bâtir, redresser, démolir

function enceinte.est_batie()
  return donnees().batie
end

function enceinte.niveau()
  return donnees().niveau
end

function enceinte.cout_du_niveau(niveau)
  if niveau == 1 then return enceinte.reglages.bois_palissade end
  if niveau == 2 then return enceinte.reglages.bois_tours end
  return nil
end

-- Bâtit le niveau suivant (palissade, puis tours), contre du bois.
function enceinte.batir()
  local d = donnees()
  if not camp().est_fonde() then
    return refuser("camp_absent")
  end
  if d.niveau >= enceinte.niveau_maximal then
    return refuser("niveau_maximal")
  end
  local bois = enceinte.cout_du_niveau(d.niveau + 1)
  if coffre().reserve("bois") < bois then
    return refuser("bois_insuffisant", bois .. " > " .. coffre().reserve("bois"))
  end
  coffre().prelever_reserve("bois", bois, (d.niveau == 0) and "palissade" or "tours")
  d.niveau = d.niveau + 1
  d.batie = true
  local poses, manquants = dresser(d)
  -- La porte est posée fermée : son état est redit au jeu au prochain battement.
  d.porte.etat = nil
  enregistrer()
  jeu().journal("Enceinte : niveau " .. d.niveau .. ", " .. poses .. " posé(s), " .. manquants .. " manquant(s)")
  annoncer((d.niveau == 1) and "ui_scriptorium_enceinte_batie" or "ui_scriptorium_enceinte_tours")
  return true
end

function enceinte.redresser()
  local d = donnees()
  if not d.batie then
    return 0, 0
  end
  local reposes, manquants = 0, 0
  for _, e in ipairs(enceinte.plan) do
    if e.niveau <= d.niveau then
      local objet = d.objets[e.nom]
      if not (objet and objet.identifiant and jeu().objet_existe(objet.identifiant)) then
        if poser(d, e) then reposes = reposes + 1 else manquants = manquants + 1 end
      end
    end
  end
  if reposes > 0 then
    -- La porte reposée repart ouverte : on redit son état au jeu.
    d.porte.etat = nil
    enregistrer()
  end
  return reposes, manquants
end

-- Entrée en partie : retire et repose pans, porte et tours, comme le camp (les objets gardés par la
-- sauvegarde reviennent blancs, vu en jeu le 14/10). La porte reposée repart ouverte : son état est redit au jeu.
function enceinte.relancer()
  local d = donnees()
  enceinte.refaire_le_plan()
  if not d.batie then
    return 0, 0
  end
  for _, objet in pairs(d.objets) do
    if objet.identifiant then
      jeu().retirer_objet(objet.identifiant)
    end
  end
  d.objets = {}
  local reposes, manquants = dresser(d)
  d.porte.etat = nil
  enregistrer()
  jeu().journal("Enceinte : reposée, " .. reposes .. " objet(s), " .. manquants .. " manquant(s)")
  return reposes, manquants
end

-- L'identifiant de l'objet posé pour un emplacement (« porte », « pan_1 », « tour_est »), ou nil. Une pièce reposée
-- peut changer de nom (vu le 15/10 : l'ancienne porte n'était pas encore effacée, la neuve a pris un « _2 »).
function enceinte.objet_de(nom)
  local objet = donnees().objets[nom]
  return objet and objet.identifiant or nil
end

function enceinte.demolir()
  local d = donnees()
  if not d.batie then
    return refuser("pas_batie")
  end
  local retires = 0
  for nom, objet in pairs(d.objets) do
    if objet.identifiant then
      jeu().retirer_objet(objet.identifiant)
      retires = retires + 1
    end
    d.objets[nom] = nil
  end
  d.batie = false
  d.niveau = 0
  d.porte = { etat = "ouverte", voulu = "ouverte" }
  enregistrer()
  jeu().journal("Enceinte : démolie, " .. retires .. " objet(s) retiré(s)")
  return true
end

-- ---------------------------------------------------------------- ce que lisent les autres morceaux

function enceinte.bonus()
  local d = donnees()
  if not d.batie then return 1 end
  if d.niveau >= 2 then return enceinte.reglages.bonus_tours end
  return enceinte.reglages.bonus_palissade
end

function enceinte.avance_de_guet()
  local d = donnees()
  if d.batie and d.niveau >= 2 then
    return enceinte.reglages.avance_de_guet
  end
  return 0
end

function enceinte.point_d_entree()
  local d = donnees()
  if not d.batie then
    return nil
  end
  for _, e in ipairs(enceinte.plan) do
    if e.nom == "porte" then
      return camp().point(e.x, e.y, e.cap)
    end
  end
  return nil
end

-- ---------------------------------------------------------------- la porte

local etats_de_porte = { ouverte = true, fermee = true, barree = true }

function enceinte.porte()
  local d = donnees()
  return d.porte.etat or "ouverte", d.porte.voulu
end

local function appliquer_porte(d, etat)
  if d.porte.etat == etat then
    return false
  end
  d.porte.etat = etat
  local objet = d.objets["porte"]
  if objet and objet.identifiant then
    jeu().changer_porte(objet.identifiant, etat)
  end
  return true
end

local function vouloir(etat)
  local d = donnees()
  if not d.batie then
    return refuser("pas_batie")
  end
  if not etats_de_porte[etat] then
    return refuser("etat_inconnu", tostring(etat))
  end
  d.porte.voulu = etat
  local change = appliquer_porte(d, etat)
  enregistrer()
  return true, change
end

function enceinte.ouvrir() return vouloir("ouverte") end
function enceinte.fermer() return vouloir("fermee") end
function enceinte.barrer() return vouloir("barree") end

-- L'état que la porte devrait avoir à cette heure, bandes comprises.
function enceinte.etat_voulu(heure)
  local d = donnees()
  if Scriptorium.bataille and #Scriptorium.bataille.bandes() > 0 then
    return "barree"
  end
  local h = heure - math.floor(heure / 24) * 24
  if h >= enceinte.reglages.heure_fermeture or h < enceinte.reglages.heure_ouverture then
    return "fermee"
  end
  return "ouverte"
end

function enceinte.battre()
  local d = donnees()
  local rapport = { porte = 0 }
  if not d.batie then
    return rapport
  end
  local voulu = enceinte.etat_voulu(jeu().heure_du_jeu())
  if appliquer_porte(d, voulu) then
    rapport.porte = 1
    if voulu == "barree" then
      annoncer("ui_scriptorium_enceinte_porte_barree", { importance = "alerte" })
    elseif voulu == "fermee" then
      annoncer("ui_scriptorium_enceinte_porte_fermee")
    end
    enregistrer()
  end
  return rapport
end

-- ---------------------------------------------------------------- Gestion du camp

local function entrees()
  if not Scriptorium.directeur then
    return
  end
  Scriptorium.directeur.ajouter_entree({
    action = "batir_enceinte", cle = "ui_scriptorium_gestion_enceinte", parametres = {},
    disponible = function()
      local d = donnees()
      if d.niveau >= 1 then return false, "deja_batie" end
      if coffre().reserve("bois") < enceinte.reglages.bois_palissade then return false, "bois_insuffisant" end
      return true, { bois = enceinte.reglages.bois_palissade }
    end,
    agir = function()
      if donnees().niveau >= 1 then return false, "deja_batie" end
      return enceinte.batir()
    end,
  })
  Scriptorium.directeur.ajouter_entree({
    action = "batir_tours", cle = "ui_scriptorium_gestion_tours", parametres = {},
    disponible = function()
      local d = donnees()
      if d.niveau < 1 then return false, "pas_de_palissade" end
      if d.niveau >= 2 then return false, "deja_baties" end
      if coffre().reserve("bois") < enceinte.reglages.bois_tours then return false, "bois_insuffisant" end
      return true, { bois = enceinte.reglages.bois_tours }
    end,
    agir = function()
      local d = donnees()
      if d.niveau < 1 then return false, "pas_de_palissade" end
      if d.niveau >= 2 then return false, "deja_baties" end
      return enceinte.batir()
    end,
  })
end
enceinte.installer_les_entrees = entrees

Scriptorium.declarer_morceau("enceinte", function()
  entrees()
end)
entrees()

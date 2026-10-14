-- L'enceinte : palissade, porte, tours de guet. Bâtie contre du bois, posée comme le camp.
-- Fiche de comportement : docs/socle/fiches/07_enceinte.md

Scriptorium = Scriptorium or {}

local enceinte = {}
Scriptorium.enceinte = enceinte

enceinte.reglages = {
  rayon = 15,
  pans = 16,
  bois_palissade = 80,
  bois_tours = 40,
  bonus_palissade = 1.3,
  bonus_tours = 1.4,
  avance_de_guet = 1,     -- heures d'avertissement en plus avec les tours
  heure_fermeture = 22,
  heure_ouverture = 5,
}

enceinte.niveau_maximal = 2

-- Modèles du jeu de base, appelés par leur chemin. À vérifier en jeu.
enceinte.modeles = {
  palissade = { chemin = "objects/props/fence/palisade_section.cgf" },
  porte     = { chemin = "objects/props/fence/palisade_gate.cgf" },
  tour      = { chemin = "objects/props/camp/watchtower_wood.cgf" },
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
  local position = camp().point(e.x, e.y, e.cap)
  local _, cap = camp().dans_le_monde({ x = 0, y = 0, z = 0, cap = 0 }, 0, 0, e.cap)
  local identifiant = jeu().poser_objet(e.sorte, enceinte.modeles[e.sorte].chemin, position, cap, "enceinte_" .. e.nom)
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

-- Les patrouilles : des hommes envoyés sur un chemin, qui reviennent et rendent compte.
-- Fiche de comportement : docs/socle/fiches/08_patrouilles.md

local Scriptorium = Scriptorium

local patrouilles = {}
Scriptorium.patrouilles = patrouilles

patrouilles.reglages = {
  hommes_min = 2,
  hommes_max = 6,
  butin_min = 3,            -- par homme, rôdeurs chassés
  butin_max = 12,
  part_rodeurs = 2 / 3,     -- des rencontres
  baisse_de_risque = 0.1,
  duree_de_la_baisse = 7 * 24,
  avance_de_guet = 0.5,     -- heures, pendant une ronde proche
  journal_gardes = 20,
}

-- Chemins en données : points par rapport au camp, durée en heures, risque, sorte d'embuscade.
patrouilles.chemins = {
  ronde_proche = {
    points = { { x = 0, y = 30 }, { x = 30, y = 0 }, { x = 0, y = -30 }, { x = -30, y = 0 } },
    duree = 2, risque = 0.1, embuscade = "deserteurs",
  },
  route_du_village = {
    points = { { x = 20, y = 60 }, { x = 40, y = 110 }, { x = 50, y = 150 } },
    duree = 5, risque = 0.3, embuscade = "brigands",
  },
  les_bois = {
    points = { { x = -40, y = 50 }, { x = -90, y = 110 }, { x = -140, y = 170 }, { x = -120, y = 200 } },
    duree = 8, risque = 0.5, embuscade = "coumans",
  },
}

local function jeu() return Scriptorium.jeu end
local function camp() return Scriptorium.camp end
local function coffre() return Scriptorium.coffre end
local function hommes() return Scriptorium.hommes end
local function bataille() return Scriptorium.bataille end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return { prochaine = 1, en_cours = nil, journal = {}, risques = {} }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("patrouilles") then
    registre.declarer_case("patrouilles", 1, donnees_neuves)
  end
  return registre.lire("patrouilles")
end

local function enregistrer()
  Scriptorium.registre.enregistrer("patrouilles")
end

local function refuser(raison, detail)
  jeu().journal("Patrouilles : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

-- ---------------------------------------------------------------- risque

function patrouilles.risque_de(nom)
  local chemin = patrouilles.chemins[nom]
  if not chemin then
    return nil
  end
  local d = donnees()
  local r = d.risques[nom]
  if Scriptorium.actif("baisse_du_risque") and r and r.jusqu_a and jeu().heure_du_jeu() < r.jusqu_a then
    return math.max(0, chemin.risque - r.baisse)
  end
  return chemin.risque
end

-- ---------------------------------------------------------------- envoi

function patrouilles.en_cours()
  local p = donnees().en_cours
  if not p then
    return nil
  end
  local copie = { id = p.id, chemin = p.chemin, depart = p.depart, retour = p.retour, point = p.point, hommes = {} }
  for i, id in ipairs(p.hommes) do copie.hommes[i] = id end
  return copie
end

-- Les hommes disponibles : libres pour la patrouille (ni blessés, ni tenus par une règle aussi forte : fiche 15, V73 b 3),
-- pas de garde à cette heure.
local function disponibles(heure)
  local de_garde = {}
  for _, g in ipairs(Scriptorium.avis(hommes(), "gardes", heure)) do de_garde[g.id] = true end
  local liste = {}
  for _, id in ipairs(hommes().liste()) do
    if Scriptorium.avis(hommes(), "libre_pour", id, "patrouille") and not de_garde[id] then
      table.insert(liste, id)
    end
  end
  return liste
end

local function point_du_chemin(chemin, i)
  local p = patrouilles.chemins[chemin].points[i]
  return camp().point(p.x, p.y, 0)
end

local function ordonner_le_point(p)
  local position = point_du_chemin(p.chemin, p.point)
  for _, id in ipairs(p.hommes) do
    if hommes().fiche(id) then
      hommes().tenir(id, "patrouille", { activite = "patrouille", lieu = p.chemin .. "_" .. p.point, position = position,
                                         cap = 0, fin = "liberation" })
    end
  end
  p.dernier_point_ordonne = p.point
end

function patrouilles.envoyer(ordre)
  ordre = ordre or {}
  local d = donnees()
  if not camp().est_fonde() then
    return refuser("camp_absent")
  end
  local chemin = patrouilles.chemins[ordre.chemin]
  if not chemin then
    return refuser("chemin_inconnu", tostring(ordre.chemin))
  end
  local n = ordre.hommes
  if type(n) ~= "number" or math.floor(n) ~= n or n < patrouilles.reglages.hommes_min or n > patrouilles.reglages.hommes_max then
    return refuser("effectif_invalide", tostring(n))
  end
  if d.en_cours then
    return refuser("patrouille_en_cours", d.en_cours.id)
  end
  local heure = jeu().heure_du_jeu()
  local libres = disponibles(heure)
  if #libres < n then
    return refuser("pas_assez_d_hommes", #libres .. " < " .. n)
  end
  local id = "patrouille_" .. d.prochaine
  d.prochaine = d.prochaine + 1
  local p = { id = id, chemin = ordre.chemin, hommes = {}, depart = heure, retour = heure + chemin.duree, point = 1 }
  for i = 1, n do
    table.insert(p.hommes, libres[i])
  end
  d.en_cours = p
  ordonner_le_point(p)
  enregistrer()
  jeu().journal("Patrouilles : « " .. id .. " » partie sur " .. ordre.chemin .. " avec " .. n .. " homme(s), retour à " .. p.retour .. " h")
  annoncer("ui_scriptorium_patrouille_partie")
  return id
end

-- ---------------------------------------------------------------- retour

local function tirage()
  -- Le hasard de la bataille, gardé au registre.
  return bataille().tirage()
end

local function rentrer(d, p)
  local chemin = patrouilles.chemins[p.chemin]
  local compte_rendu = { id = p.id, chemin = p.chemin, hommes = #p.hommes, issue = "rien", butin = 0, morts = 0, blesses = 0, moment = jeu().heure_du_jeu() }
  local presents = {}
  for _, id in ipairs(p.hommes) do
    if hommes().fiche(id) then table.insert(presents, id) end
  end
  local risque = patrouilles.risque_de(p.chemin)
  -- Fiche 16 : les sorties sont les missions de Scriptorium ; les rencontres tirées au sort, éteintes.
  if Scriptorium.actif("rencontres_de_patrouille") and #presents > 0 and tirage() < risque then
    if tirage() < patrouilles.reglages.part_rodeurs then
      compte_rendu.issue = "rodeurs"
      local butin = 0
      for _ = 1, #presents do
        butin = butin + patrouilles.reglages.butin_min
          + math.floor(tirage() * (patrouilles.reglages.butin_max - patrouilles.reglages.butin_min + 1))
      end
      coffre().encaisser(butin, "butin_patrouille")
      compte_rendu.butin = butin
    else
      compte_rendu.issue = "embuscade"
      local resultat = bataille().escarmouche(presents, chemin.embuscade, #presents + 1)
      compte_rendu.morts = #resultat.morts
      compte_rendu.blesses = #resultat.blesses
      compte_rendu.issue_du_combat = resultat.issue
    end
  end
  -- Le risque du chemin baisse pour une semaine sans embuscade, remonte sinon.
  if compte_rendu.issue == "embuscade" then
    d.risques[p.chemin] = nil
  else
    d.risques[p.chemin] = { baisse = patrouilles.reglages.baisse_de_risque, jusqu_a = jeu().heure_du_jeu() + patrouilles.reglages.duree_de_la_baisse }
  end
  for _, id in ipairs(p.hommes) do
    if hommes().fiche(id) then
      hommes().lacher(id, "patrouille")
    end
  end
  d.en_cours = nil
  table.insert(d.journal, compte_rendu)
  while #d.journal > patrouilles.reglages.journal_gardes do
    table.remove(d.journal, 1)
  end
  jeu().journal("Patrouilles : « " .. p.id .. " » rentrée : " .. compte_rendu.issue .. ", butin " .. compte_rendu.butin
                .. ", " .. compte_rendu.morts .. " mort(s), " .. compte_rendu.blesses .. " blessé(s)")
  if compte_rendu.issue == "rien" then
    annoncer("ui_scriptorium_patrouille_rien")
  elseif compte_rendu.issue == "rodeurs" then
    annoncer("ui_scriptorium_patrouille_rodeurs", { complement = compte_rendu.butin .. " groschen" })
  else
    annoncer("ui_scriptorium_patrouille_embuscade", { importance = "alerte" })
  end
  return compte_rendu
end

function patrouilles.battre()
  local d = donnees()
  local rapport = { points = 0, rentrees = 0 }
  local p = d.en_cours
  if not p then
    return rapport
  end
  local heure = jeu().heure_du_jeu()
  if heure >= p.retour then
    rentrer(d, p)
    rapport.rentrees = 1
    enregistrer()
    return rapport
  end
  local chemin = patrouilles.chemins[p.chemin]
  local part = (heure - p.depart) / chemin.duree
  local point = math.min(#chemin.points, math.floor(part * #chemin.points) + 1)
  if point ~= p.point then
    p.point = point
    ordonner_le_point(p)
    rapport.points = 1
    enregistrer()
  end
  return rapport
end

function patrouilles.avance_de_guet()
  local p = donnees().en_cours
  if p and p.chemin == "ronde_proche" then
    return patrouilles.reglages.avance_de_guet
  end
  return 0
end

function patrouilles.journal()
  local copie = {}
  for i, c in ipairs(donnees().journal) do
    copie[i] = { id = c.id, chemin = c.chemin, hommes = c.hommes, issue = c.issue, butin = c.butin,
                 morts = c.morts, blesses = c.blesses, issue_du_combat = c.issue_du_combat, moment = c.moment }
  end
  return copie
end

-- ---------------------------------------------------------------- Gestion du camp

local function entrees()
  if not Scriptorium.directeur then
    return
  end
  Scriptorium.directeur.ajouter_entree({
    action = "envoyer_patrouille", cle = "ui_scriptorium_gestion_patrouille", parametres = { "chemin", "hommes" },
    disponible = function()
      if donnees().en_cours then return false, "patrouille_en_cours" end
      local libres = disponibles(jeu().heure_du_jeu())
      if #libres < patrouilles.reglages.hommes_min then return false, "pas_assez_d_hommes" end
      local chemins = {}
      for nom in pairs(patrouilles.chemins) do table.insert(chemins, nom) end
      table.sort(chemins)
      return true, { chemins = chemins, disponibles = #libres }
    end,
    agir = function(p)
      local id, raison = patrouilles.envoyer({ chemin = p.chemin, hommes = p.hommes })
      if not id then return false, raison end
      return true, id
    end,
  })
end
patrouilles.installer_les_entrees = entrees

Scriptorium.declarer_morceau("patrouilles", function()
  entrees()
end)
entrees()

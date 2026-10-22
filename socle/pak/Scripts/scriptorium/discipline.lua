-- La discipline et la justice du camp : fautes, jugements, réputation auprès des villages.
-- Fiche de comportement : docs/socle/fiches/09_discipline.md

local Scriptorium = Scriptorium

local discipline = {}
Scriptorium.discipline = discipline

discipline.reglages = {
  chance_de_base = 0.03,       -- par homme et par jour
  chance_morose = 0.06,
  chance_abattu = 0.10,
  vol_min = 5,
  vol_max = 20,
  bieres_par_ivresse = 2,
  jours_avant_prescription = 2,
  reputation_depart = 50,
  reputation_exaction = -5,
  reputation_justice = 2,
  reputation_laxisme = -1,
  fautes_gardees = 20,
}

-- Les sortes de fautes, leur poids dans le tirage, leur message.
discipline.fautes = {
  { nom = "rixe", poids = 4, cle = "ui_scriptorium_discipline_rixe" },
  { nom = "vol", poids = 2.5, cle = "ui_scriptorium_discipline_vol" },
  { nom = "ivresse", poids = 2, cle = "ui_scriptorium_discipline_ivresse" },
  { nom = "exaction", poids = 1.5, cle = "ui_scriptorium_discipline_exaction" },
}

discipline.peines = { pardon = true, amende = true, corvee = true, pilori = true, renvoi = true }

local function jeu() return Scriptorium.jeu end
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
  return { prochain = 1, a_juger = {}, juges = {}, reputation = discipline.reglages.reputation_depart, derniere_aube = nil }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("discipline") then
    registre.declarer_case("discipline", 1, donnees_neuves)
  end
  return registre.lire("discipline")
end

local function enregistrer()
  Scriptorium.registre.enregistrer("discipline")
end

local function refuser(raison, detail)
  jeu().journal("Discipline : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

local function borner(valeur, mini, maxi)
  if valeur < mini then return mini end
  if valeur > maxi then return maxi end
  return valeur
end

local function changer_reputation(d, delta)
  -- Fiche 16 : les exactions et la réputation auprès des villages, reportées (éteintes).
  if not Scriptorium.actif("exactions") then
    return
  end
  d.reputation = borner(d.reputation + delta, 0, 100)
end

-- ---------------------------------------------------------------- réputation

function discipline.reputation()
  return donnees().reputation
end

-- Le facteur de prix auprès des villages : 1 à 50, 1,5 à 0, 0,5 à 100.
function discipline.facteur_de_prix()
  if not Scriptorium.actif("exactions") then
    return 1
  end
  return 1.5 - donnees().reputation / 100
end

-- ---------------------------------------------------------------- fautes

-- La sorte de faute, selon les poids et les penchants du coupable (fiche 11). Rend nil s'il n'a aucun penchant.
local function tirer_la_sorte(coupable)
  local caractere = Scriptorium.caractere
  local poids = {}
  local total = 0
  for i, f in ipairs(discipline.fautes) do
    poids[i] = f.poids * (caractere and caractere.poids_de_faute(coupable, f.nom) or 1)
    total = total + poids[i]
  end
  if total <= 0 then
    return nil
  end
  local t = bataille().tirage() * total
  for i, f in ipairs(discipline.fautes) do
    t = t - poids[i]
    if t < 0 then return f end
  end
  return discipline.fautes[#discipline.fautes]
end

local function commettre(d, coupable, faute, heure)
  local f = hommes().fiche(coupable)
  local incident = { id = "faute_" .. d.prochain, sorte = faute.nom, coupable = coupable, nom = f.nom, moment = heure }
  d.prochain = d.prochain + 1
  if faute.nom == "rixe" then
    local liste = hommes().liste()
    local autre = nil
    for i, id in ipairs(liste) do
      if id == coupable then
        autre = liste[(i % #liste) + 1]
      end
    end
    if autre == nil or autre == coupable then
      return nil
    end
    incident.victime = autre
    hommes().changer_moral(coupable, -5)
    hommes().changer_moral(autre, -5)
    hommes().blesser(autre, 1)
    if Scriptorium.caractere then
      Scriptorium.caractere.blessure_recue(autre)
    end
  elseif faute.nom == "vol" then
    local montant = discipline.reglages.vol_min
      + math.floor(bataille().tirage() * (discipline.reglages.vol_max - discipline.reglages.vol_min + 1))
    montant = math.min(montant, coffre().solde())
    if montant > 0 then
      coffre().payer(montant, "vol")
    end
    incident.montant = montant
  elseif faute.nom == "ivresse" then
    if coffre().reserve("biere") >= discipline.reglages.bieres_par_ivresse then
      coffre().prelever_reserve("biere", discipline.reglages.bieres_par_ivresse, "ivresse")
    end
    hommes().blesser(coupable, 1)
    hommes().changer_moral(coupable, -2)
  elseif faute.nom == "exaction" then
    changer_reputation(d, discipline.reglages.reputation_exaction)
  end
  table.insert(d.a_juger, incident)
  while #d.a_juger > discipline.reglages.fautes_gardees do
    table.remove(d.a_juger, 1)
  end
  if Scriptorium.caractere then
    Scriptorium.caractere.faute_commise(coupable, faute.nom)
  end
  jeu().journal("Discipline : " .. faute.nom .. " par « " .. f.nom .. " » (" .. incident.id .. ")")
  annoncer(faute.cle, { importance = (faute.nom == "exaction") and "alerte" or "nouvelle", complement = f.nom })
  return incident
end

-- La chance de faute selon le moral, multipliée selon le jugement de l'homme (fiche 11).
local function chance_de(f)
  local niveau = hommes().niveau_de_moral(f.moral)
  local chance = discipline.reglages.chance_de_base
  if niveau == "abattu" then
    chance = discipline.reglages.chance_abattu
  elseif niveau == "morose" then
    chance = discipline.reglages.chance_morose
  end
  if Scriptorium.caractere then
    chance = chance * Scriptorium.caractere.facteur_de_faute(f.id)
  end
  return chance
end

-- Les fautes d'une aube. Rend le nombre de fautes commises.
local function aube(d, heure)
  local fautes = 0
  for _, id in ipairs(hommes().liste()) do
    local f = hommes().fiche(id)
    -- Fiche 16 : les fautes sont à Scriptorium ; le tirage du socle, éteint.
    if Scriptorium.actif("fautes_a_l_aube") and f and f.blessure == 0 and bataille().tirage() < chance_de(f) then
      local faute = tirer_la_sorte(id)
      if faute and commettre(d, id, faute, heure) then
        fautes = fautes + 1
      end
    end
  end
  return fautes
end

-- Les fautes trop vieilles sans jugement sont prescrites : les hommes murmurent.
local function prescrire(d, heure)
  local prescrites = 0
  local restantes = {}
  for _, incident in ipairs(d.a_juger) do
    if heure >= incident.moment + discipline.reglages.jours_avant_prescription * 24 then
      incident.peine = "prescrite"
      hommes().moral_pour_tous(-2)
      if incident.sorte == "exaction" then
        changer_reputation(d, discipline.reglages.reputation_laxisme)
      end
      table.insert(d.juges, incident)
      prescrites = prescrites + 1
      annoncer("ui_scriptorium_discipline_laxisme")
    else
      table.insert(restantes, incident)
    end
  end
  d.a_juger = restantes
  while #d.juges > discipline.reglages.fautes_gardees do
    table.remove(d.juges, 1)
  end
  return prescrites
end

function discipline.battre()
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local rapport = { aubes = 0, fautes = 0, prescrites = 0 }
  local jour = math.floor((heure - hommes().reglages.heure_lever) / 24)
  if d.derniere_aube == nil then
    d.derniere_aube = jour
    return rapport
  end
  if jour < d.derniere_aube then
    d.derniere_aube = jour
  end
  while d.derniere_aube < jour do
    d.derniere_aube = d.derniere_aube + 1
    rapport.aubes = rapport.aubes + 1
    rapport.fautes = rapport.fautes + aube(d, heure)
    rapport.prescrites = rapport.prescrites + prescrire(d, heure)
  end
  if rapport.aubes > 0 then
    enregistrer()
  end
  return rapport
end

-- ---------------------------------------------------------------- jugements

function discipline.a_juger()
  local copie = {}
  for i, incident in ipairs(donnees().a_juger) do
    copie[i] = { id = incident.id, sorte = incident.sorte, coupable = incident.coupable, nom = incident.nom,
                 victime = incident.victime, montant = incident.montant, moment = incident.moment }
  end
  return copie
end

function discipline.juges()
  local copie = {}
  for i, incident in ipairs(donnees().juges) do
    copie[i] = { id = incident.id, sorte = incident.sorte, coupable = incident.coupable, nom = incident.nom,
                 peine = incident.peine, moment = incident.moment }
  end
  return copie
end

local function classer(d, incident, peine)
  incident.peine = peine
  for i, autre in ipairs(d.a_juger) do
    if autre.id == incident.id then
      table.remove(d.a_juger, i)
      break
    end
  end
  table.insert(d.juges, incident)
  while #d.juges > discipline.reglages.fautes_gardees do
    table.remove(d.juges, 1)
  end
end

function discipline.juger(id_incident, peine)
  local d = donnees()
  local incident = nil
  for _, i in ipairs(d.a_juger) do
    if i.id == id_incident then incident = i end
  end
  if not incident then
    for _, i in ipairs(d.juges) do
      if i.id == id_incident then return refuser("deja_juge", id_incident) end
    end
    return refuser("incident_inconnu", tostring(id_incident))
  end
  if not discipline.peines[peine] then
    return refuser("peine_inconnue", tostring(peine))
  end
  local f = hommes().fiche(incident.coupable)
  if not f then
    classer(d, incident, "classee")
    enregistrer()
    return refuser("homme_parti", incident.coupable)
  end
  if peine == "pardon" then
    for _, id in ipairs(hommes().liste()) do
      if id ~= incident.coupable then hommes().changer_moral(id, -2) end
    end
  elseif peine == "amende" then
    hommes().retenir(incident.coupable, math.floor(hommes().solde_de(incident.coupable) / 2))
    hommes().changer_moral(incident.coupable, -5)
  elseif peine == "corvee" then
    local position = Scriptorium.camp.point(Scriptorium.hommes.points.corvee.x, Scriptorium.hommes.points.corvee.y, 0)
    -- L'arbitre (fiche 15, V73 b 3) : la punition au rang du travail (réponse 1 a de JoVenGer, V73 b).
    hommes().tenir(incident.coupable, "punition", { activite = "corvee", lieu = "corvee_punition", position = position,
                                                    cap = 0, fin = jeu().heure_du_jeu() + 24 })
    hommes().changer_moral(incident.coupable, -3)
  elseif peine == "pilori" then
    hommes().blesser(incident.coupable, 1)
    hommes().changer_moral(incident.coupable, -10)
  elseif peine == "renvoi" then
    hommes().renvoyer(incident.coupable)
  end
  if incident.sorte == "exaction" and peine ~= "pardon" then
    changer_reputation(d, discipline.reglages.reputation_justice)
  end
  classer(d, incident, peine)
  enregistrer()
  jeu().journal("Discipline : " .. incident.id .. " jugé : " .. peine)
  annoncer("ui_scriptorium_discipline_jugement", { complement = incident.nom })
  return true
end

-- ---------------------------------------------------------------- Gestion du camp

local function entrees()
  if not Scriptorium.directeur then
    return
  end
  Scriptorium.directeur.ajouter_entree({
    action = "juger", cle = "ui_scriptorium_gestion_juger", parametres = { "incident", "peine" },
    disponible = function()
      local liste = discipline.a_juger()
      if #liste == 0 then return false, "rien_a_juger" end
      local peines = {}
      for p in pairs(discipline.peines) do table.insert(peines, p) end
      table.sort(peines)
      return true, { fautes = liste, peines = peines, reputation = discipline.reputation() }
    end,
    agir = function(p) return discipline.juger(p.incident, p.peine) end,
  })
end
discipline.installer_les_entrees = entrees

Scriptorium.declarer_morceau("discipline", function()
  entrees()
end)
entrees()

-- Les hommes au camp : fiches, contrats, solde, vivres, moral, journée, garde, départs.
-- Fiche de comportement : docs/socle/fiches/04_hommes.md

Scriptorium = Scriptorium or {}

local hommes = {}
Scriptorium.hommes = hommes

hommes.reglages = {
  moral_depart = 60,
  ration = 2,                 -- vivres par homme et par jour (choix de JoVenGer, 14/10)
  heure_lever = 5,            -- aube : contrats finis, désertions
  heure_repas = 7,            -- repas du matin : rations et soins
  heure_paie = 8,             -- heure de la solde, le jour de paie
  semaines_impayees_max = 2,  -- au-delà, l'homme s'en va
  moral_desertion = 10,       -- en dessous, à l'aube, il déserte
  postes_garde_jour = 1,      -- au plus, le jour : un poste pour quatre hommes valides
  postes_garde_nuit = 2,      -- au plus, la nuit : un poste pour deux hommes valides
  hommes_par_poste_jour = 4,
  hommes_par_poste_nuit = 2,
  duree_tour_de_garde = 3,    -- heures
  anciens_gardes = 50,
  semaines_min = 1,
  semaines_max = 52,
}

-- Rôles et solde hebdomadaire de base, en groschen.
hommes.roles = {
  homme_d_armes = { solde = 12 },
  arbaletrier   = { solde = 14 },
  archer        = { solde = 12 },
  pavoisier     = { solde = 10 },
  barbier       = { solde = 15 },
  cuisinier     = { solde = 8 },
  armurier      = { solde = 16 },
}

-- Rangs et multiplicateur de solde.
hommes.rangs = { soudoyer = 1, dizainier = 1.5, capitaine = 2 }

-- Les niveaux de moral.
hommes.niveaux_de_moral = {
  { seuil = 75, nom = "ardent" },
  { seuil = 50, nom = "content" },
  { seuil = 25, nom = "morose" },
  { seuil = 0, nom = "abattu" },
}

-- La journée, par tranches d'heures (de inclus, a exclu ; la dernière passe minuit).
hommes.journee = {
  { de = 5, a = 7, activite = "lever" },
  { de = 7, a = 8, activite = "repas" },
  { de = 8, a = 12, activite = "exercice" },
  { de = 12, a = 13, activite = "repas" },
  { de = 13, a = 18, activite = "corvee" },
  { de = 18, a = 19, activite = "repas" },
  { de = 19, a = 22, activite = "veillee" },
  { de = 22, a = 5, activite = "sommeil" },
}

-- Points du camp où se font les activités, par rapport à l'ancre.
hommes.points = {
  exercice = { x = 5, y = -1, cap = 90 },
  corvee = { x = -4, y = 6, cap = 0 },
  feu = { x = 0, y = 2.2, cap = 180 },
}

-- Postes de garde, autour du camp.
hommes.postes_de_garde = {
  { x = 0, y = 12, cap = 0 },
  { x = 12, y = 0, cap = 90 },
  { x = 0, y = -12, cap = 180 },
  { x = -12, y = 0, cap = 270 },
}

-- Noms d'époque (Bohême vers 1400). Prénoms et surnoms se combinent sans se répéter.
hommes.prenoms = {
  "Jan", "Mikuláš", "Ondřej", "Václav", "Jakub", "Petr", "Matěj", "Vít", "Havel", "Beneš",
  "Jindřich", "Oldřich", "Zdeněk", "Bohuslav", "Hanuš", "Kunrát", "Albrecht", "Ulrich",
  "Heinz", "Wenzel", "Prokop", "Beneda", "Martin", "Diviš",
}
hommes.surnoms = {
  "Kladivo", "le Rouge", "de Sázava", "Vlk", "le Long", "Sekera", "de Talmberk", "Hrom",
  "le Borgne", "Kozel", "de Rataje", "Medvěd", "le Taciturne", "Šíp", "de Skalice", "Holub",
}

local function jeu()
  return Scriptorium.jeu
end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

local function coffre()
  return Scriptorium.coffre
end

local function camp()
  return Scriptorium.camp
end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return {
    prochain = 1,
    prochain_nom = 1,
    liste = {},
    ordre = {},
    anciens = {},
    prochaine_paie = nil,
    dernier_jour_repas = nil,
    derniere_aube = nil,
    derniere_heure = nil,
    capitaine = nil,
  }
end

-- Montées de version de la case « hommes ».
-- 1 -> 2 (14/10) : le lieu d'une affectation change de nom de champ. Les affectations sont passagères
-- (elles ont une fin) : on les oublie, et chacun reprend sa journée.
local migrations = {
  [1] = function(d)
    for _, f in pairs(d.liste or {}) do
      if type(f) == "table" then
        f.affectation = nil
      end
    end
    return d
  end,
}

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("hommes") then
    registre.declarer_case("hommes", 2, donnees_neuves, migrations)
  end
  return registre.lire("hommes")
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

local function refuser(raison, detail)
  jeu().journal("Hommes : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

local function borner(valeur, mini, maxi)
  if valeur < mini then return mini end
  if valeur > maxi then return maxi end
  return valeur
end

local function jour_de(heure)
  return math.floor(heure / 24)
end

local function heure_dans_le_jour(heure)
  return heure - jour_de(heure) * 24
end

-- ---------------------------------------------------------------- noms

local function nom_suivant(d)
  local i = d.prochain_nom
  local prenom = hommes.prenoms[(i - 1) % #hommes.prenoms + 1]
  local surnom = hommes.surnoms[math.floor((i - 1) / #hommes.prenoms) % #hommes.surnoms + 1]
  d.prochain_nom = i + 1
  return prenom .. " " .. surnom
end

-- ---------------------------------------------------------------- lecture

function hommes.liste()
  local copie = {}
  for i, id in ipairs(donnees().ordre) do
    copie[i] = id
  end
  return copie
end

function hommes.fiche(id)
  local f = donnees().liste[id]
  if not f then
    return nil
  end
  local copie = {}
  for cle, valeur in pairs(f) do
    if type(valeur) == "table" then
      local sous = {}
      for k, v in pairs(valeur) do sous[k] = v end
      copie[cle] = sous
    else
      copie[cle] = valeur
    end
  end
  return copie
end

function hommes.niveau_de_moral(moral)
  for _, niveau in ipairs(hommes.niveaux_de_moral) do
    if moral >= niveau.seuil then
      return niveau.nom
    end
  end
  return "abattu"
end

function hommes.effectif()
  local d = donnees()
  local bilan = { nombre = 0, valides = 0, blesses = 0, presents = 0, par_role = {}, par_rang = {} }
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    bilan.nombre = bilan.nombre + 1
    if f.blessure > 0 then bilan.blesses = bilan.blesses + 1 else bilan.valides = bilan.valides + 1 end
    if f.personnage then bilan.presents = bilan.presents + 1 end
    bilan.par_role[f.role] = (bilan.par_role[f.role] or 0) + 1
    bilan.par_rang[f.rang] = (bilan.par_rang[f.rang] or 0) + 1
  end
  return bilan
end

function hommes.anciens()
  local copie = {}
  for i, a in ipairs(donnees().anciens) do
    copie[i] = { id = a.id, nom = a.nom, role = a.role, cause = a.cause, moment = a.moment }
  end
  return copie
end

-- ---------------------------------------------------------------- solde d'un homme

local function solde_hebdomadaire(f)
  return math.floor(f.contrat.solde * hommes.rangs[f.rang] + 0.5)
end

function hommes.solde_de(id)
  local f = donnees().liste[id]
  return f and solde_hebdomadaire(f) or nil
end

-- ---------------------------------------------------------------- rangs

local function verifier_rangs(d, rapport)
  local total = #d.ordre
  -- Capitaine d'office à dix hommes, s'il n'y en a pas : le plus ancien.
  if d.capitaine == nil and total >= 10 then
    local id = d.ordre[1]
    d.liste[id].rang = "capitaine"
    d.capitaine = id
    annoncer("ui_scriptorium_hommes_capitaine", { complement = d.liste[id].nom })
    rapport.capitaine = id
  end
  -- Un dizainier pour dix hommes, parmi ceux qui ne sont pas capitaine.
  local voulus = math.floor(total / 10)
  local dizainiers = {}
  local soudoyers = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.rang == "dizainier" then table.insert(dizainiers, id) end
    if f.rang == "soudoyer" then table.insert(soudoyers, id) end
  end
  -- Promotions, parmi les plus anciens.
  while #dizainiers < voulus and #soudoyers > 0 do
    local id = table.remove(soudoyers, 1)
    d.liste[id].rang = "dizainier"
    table.insert(dizainiers, id)
    annoncer("ui_scriptorium_hommes_promu_dizainier", { complement = d.liste[id].nom })
    rapport.promotions = (rapport.promotions or 0) + 1
  end
  -- Rétrogradations, les plus récents d'abord.
  while #dizainiers > voulus do
    local id = table.remove(dizainiers)
    d.liste[id].rang = "soudoyer"
    rapport.retrogradations = (rapport.retrogradations or 0) + 1
  end
end

function hommes.nommer_capitaine(id)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if d.capitaine and d.capitaine ~= id and d.liste[d.capitaine] then
    d.liste[d.capitaine].rang = "soudoyer"
  end
  f.rang = "capitaine"
  d.capitaine = id
  verifier_rangs(d, {})
  enregistrer()
  annoncer("ui_scriptorium_hommes_capitaine", { complement = f.nom })
  return true
end

-- ---------------------------------------------------------------- venue et départ des personnages

local function faire_venir(d, f)
  if f.personnage and jeu().personnage_existe(f.personnage) then
    return true
  end
  local position = nil
  if camp().est_fonde() then
    position = camp().point(hommes.points.feu.x, hommes.points.feu.y, hommes.points.feu.cap)
  end
  local personnage = jeu().faire_venir_homme(f.role, f.nom, position)
  if personnage == nil then
    jeu().journal("Hommes : le jeu n'a pas fait venir « " .. f.nom .. " » ; il reste sur le registre")
    f.personnage = nil
    return false
  end
  f.personnage = personnage
  f.derniere_activite = nil
  return true
end

local function liberer_place(f)
  if f.lit and camp().occupant_de(f.lit) == f.id then
    camp().liberer(f.lit)
  end
  f.lit = nil
end

local function faire_partir(d, f, cause, cle)
  if f.personnage then
    jeu().renvoyer_homme(f.personnage)
    f.personnage = nil
  end
  liberer_place(f)
  d.liste[f.id] = nil
  for i, id in ipairs(d.ordre) do
    if id == f.id then
      table.remove(d.ordre, i)
      break
    end
  end
  if d.capitaine == f.id then
    d.capitaine = nil
  end
  table.insert(d.anciens, { id = f.id, nom = f.nom, role = f.role, cause = cause, moment = jeu().heure_du_jeu() })
  while #d.anciens > hommes.reglages.anciens_gardes do
    table.remove(d.anciens, 1)
  end
  jeu().journal("Hommes : « " .. f.nom .. " » parti (" .. cause .. ")")
  if cle then
    annoncer(cle, { complement = f.nom })
  end
end

-- ---------------------------------------------------------------- embauche

function hommes.embaucher(contrat)
  contrat = contrat or {}
  local d = donnees()
  if not camp().est_fonde() then
    return refuser("camp_absent")
  end
  local role = hommes.roles[contrat.role]
  if not role then
    return refuser("role_inconnu", tostring(contrat.role))
  end
  local semaines = contrat.semaines
  if type(semaines) ~= "number" or math.floor(semaines) ~= semaines
     or semaines < hommes.reglages.semaines_min or semaines > hommes.reglages.semaines_max then
    return refuser("duree_invalide", tostring(semaines))
  end
  local solde = contrat.solde or role.solde
  local prime = contrat.prime or solde * 2
  local lits = camp().places_libres("lit", "hommes")
  if #lits == 0 then
    annoncer("ui_scriptorium_hommes_pas_de_lit")
    return refuser("pas_de_lit")
  end
  if coffre().solde() < prime then
    annoncer("ui_scriptorium_coffre_manque", { groupe = "coffre_manque" })
    return refuser("coffre_insuffisant", "prime " .. prime .. " > " .. coffre().solde())
  end
  local heure = jeu().heure_du_jeu()
  local id = "homme_" .. d.prochain
  d.prochain = d.prochain + 1
  local f = {
    id = id,
    nom = nom_suivant(d),
    role = contrat.role,
    rang = "soudoyer",
    contrat = { semaines = semaines, solde = solde, prime = prime, debut = heure, fin = heure + semaines * 7 * 24 },
    moral = hommes.reglages.moral_depart,
    blessure = 0,
    impayes = 0,
    personnage = nil,
    lit = lits[1],
    derniere_activite = nil,
    engage = heure,
    retenue = 0,
  }
  if prime > 0 then
    local ok = coffre().payer(prime, "prime")
    if not ok then
      return refuser("coffre_insuffisant", "prime")
    end
  end
  d.liste[id] = f
  table.insert(d.ordre, id)
  camp().reserver(f.lit, id)
  if d.prochaine_paie == nil then
    d.prochaine_paie = (jour_de(heure) + 7) * 24 + hommes.reglages.heure_paie
    d.derniere_heure = heure
    d.derniere_aube = jour_de(heure - hommes.reglages.heure_lever)
    d.dernier_jour_repas = jour_de(heure - hommes.reglages.heure_repas)
  end
  faire_venir(d, f)
  verifier_rangs(d, {})
  enregistrer()
  annoncer("ui_scriptorium_hommes_rejoint", { complement = f.nom })
  return id
end

function hommes.renouveler(id, semaines)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(semaines) ~= "number" or math.floor(semaines) ~= semaines
     or semaines < hommes.reglages.semaines_min or semaines > hommes.reglages.semaines_max then
    return refuser("duree_invalide", tostring(semaines))
  end
  local base = math.max(f.contrat.fin, jeu().heure_du_jeu())
  f.contrat.fin = base + semaines * 7 * 24
  f.contrat.semaines = f.contrat.semaines + semaines
  f.moral = borner(f.moral + 5, 0, 100)
  enregistrer()
  return true
end

function hommes.renvoyer(id)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  faire_partir(d, f, "renvoye", "ui_scriptorium_hommes_parti_renvoye")
  verifier_rangs(d, {})
  enregistrer()
  return true
end

-- Départ pour une cause venue d'ailleurs (« mort » par le morceau 5).
function hommes.retirer(id, cause)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  local cle = (cause == "mort") and "ui_scriptorium_hommes_mort" or nil
  faire_partir(d, f, cause or "retire", cle)
  verifier_rangs(d, {})
  enregistrer()
  return true
end

-- ---------------------------------------------------------------- moral et blessures

function hommes.changer_moral(id, delta)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  f.moral = borner(f.moral + delta, 0, 100)
  enregistrer()
  return true
end

function hommes.moral_pour_tous(delta)
  local d = donnees()
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    f.moral = borner(f.moral + delta, 0, 100)
  end
  enregistrer()
  return #d.ordre
end

function hommes.blesser(id, jours)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(jours) ~= "number" or jours < 1 or math.floor(jours) ~= jours then
    return refuser("jours_invalides", tostring(jours))
  end
  f.blessure = f.blessure + jours
  enregistrer()
  return true
end

-- Ôte des jours de soins (un remède, un barbier).
function hommes.guerir(id, jours)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(jours) ~= "number" or jours < 1 or math.floor(jours) ~= jours then
    return refuser("jours_invalides", tostring(jours))
  end
  f.blessure = math.max(0, f.blessure - jours)
  enregistrer()
  return true
end

local function barbier_valide(d)
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.role == "barbier" and f.blessure == 0 then
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------- garde et activités

local function tranche_de(heure_du_jour)
  for _, t in ipairs(hommes.journee) do
    if t.de < t.a then
      if heure_du_jour >= t.de and heure_du_jour < t.a then return t end
    else
      if heure_du_jour >= t.de or heure_du_jour < t.a then return t end
    end
  end
  return hommes.journee[#hommes.journee]
end

local function est_nuit(heure_du_jour)
  return heure_du_jour >= 22 or heure_du_jour < hommes.reglages.heure_lever
end

-- Les hommes de garde à cette heure, en rotation par tour de veille, jamais plus que d'hommes valides.
function hommes.gardes(heure)
  local d = donnees()
  local valides = {}
  for _, id in ipairs(d.ordre) do
    if d.liste[id].blessure == 0 and d.liste[id].affectation == nil then
      table.insert(valides, id)
    end
  end
  local h = heure_dans_le_jour(heure)
  local postes
  if est_nuit(h) then
    postes = math.min(hommes.reglages.postes_garde_nuit, math.floor(#valides / hommes.reglages.hommes_par_poste_nuit))
  else
    postes = math.min(hommes.reglages.postes_garde_jour, math.floor(#valides / hommes.reglages.hommes_par_poste_jour))
  end
  postes = math.min(postes, #valides, #hommes.postes_de_garde)
  local resultat = {}
  if postes == 0 then
    return resultat
  end
  local tour = math.floor(heure / hommes.reglages.duree_tour_de_garde)
  local depart = (tour * postes) % #valides
  for i = 1, postes do
    local id = valides[(depart + i - 1) % #valides + 1]
    table.insert(resultat, { id = id, poste = i })
  end
  return resultat
end

local function sieges_libres_pour(d)
  return camp().places_libres("siege")
end

-- Affecte un homme à une tâche qui passe devant sa journée (bataille, patrouille, corvée de punition).
-- « fin » (heure du jeu) : l'affectation tombe d'elle-même à cette heure.
function hommes.affecter(id, activite, lieu, position, cap, fin)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  f.affectation = { activite = activite, lieu = lieu, position = position, cap = cap, fin = fin }
  return true
end

-- Retient une somme sur les prochaines soldes (amende).
function hommes.retenir(id, montant)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(montant) ~= "number" or montant < 0 then
    return refuser("montant_invalide", tostring(montant))
  end
  f.retenue = (f.retenue or 0) + math.floor(montant)
  enregistrer()
  return true
end

function hommes.liberer_affectation(id)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  f.affectation = nil
  return true
end

function hommes.affectation_de(id)
  local f = donnees().liste[id]
  return f and f.affectation or nil
end

-- L'activité d'un homme à une heure : { activite, lieu, position }.
function hommes.activite_de(id, heure)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return nil
  end
  local resultat = { activite = nil, lieu = nil, position = nil }
  if f.affectation then
    resultat.activite = f.affectation.activite
    resultat.lieu = f.affectation.lieu
    resultat.position = f.affectation.position
    resultat.cap = f.affectation.cap
    return resultat
  end
  if f.blessure > 0 then
    resultat.activite = "repos"
    resultat.lieu = f.lit
    resultat.position = f.lit and camp().position_de(f.lit) or nil
    return resultat
  end
  for _, g in ipairs(hommes.gardes(heure)) do
    if g.id == id then
      local poste = hommes.postes_de_garde[g.poste]
      resultat.activite = "garde"
      resultat.lieu = "poste_" .. g.poste
      resultat.position = camp().point(poste.x, poste.y, poste.cap)
      return resultat
    end
  end
  local tranche = tranche_de(heure_dans_le_jour(heure))
  resultat.activite = tranche.activite
  if tranche.activite == "sommeil" then
    resultat.lieu = f.lit
    resultat.position = f.lit and camp().position_de(f.lit) or nil
  elseif tranche.activite == "repas" or tranche.activite == "veillee" then
    local sieges = sieges_libres_pour(d)
    local rang = 0
    for i, autre in ipairs(d.ordre) do
      if autre == id then rang = i end
    end
    if rang >= 1 and rang <= #sieges then
      resultat.lieu = sieges[rang]
      resultat.position = camp().position_de(sieges[rang])
    else
      resultat.lieu = "feu_central"
      resultat.position = camp().point(hommes.points.feu.x, hommes.points.feu.y, hommes.points.feu.cap)
    end
  elseif tranche.activite == "exercice" or tranche.activite == "corvee" then
    local p = hommes.points[tranche.activite]
    resultat.lieu = tranche.activite
    resultat.position = camp().point(p.x, p.y, p.cap)
  else
    resultat.lieu = "feu_central"
    resultat.position = camp().point(hommes.points.feu.x, hommes.points.feu.y, hommes.points.feu.cap)
  end
  return resultat
end

-- ---------------------------------------------------------------- solde, repas, aube

function hommes.payer_la_solde()
  local d = donnees()
  local rapport = { payes = 0, impayes = 0, somme = 0, partis = 0 }
  local partants = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local montant = solde_hebdomadaire(f)
    -- Une amende retient sur la solde ; ce qui dépasse reste dû.
    if f.retenue and f.retenue > 0 then
      local retenu = math.min(f.retenue, montant)
      montant = montant - retenu
      f.retenue = f.retenue - retenu
    end
    if montant == 0 or coffre().payer(montant, "solde") then
      f.impayes = 0
      f.moral = borner(f.moral + 5, 0, 100)
      rapport.payes = rapport.payes + 1
      rapport.somme = rapport.somme + montant
    else
      f.impayes = f.impayes + 1
      f.moral = borner(f.moral - 20, 0, 100)
      rapport.impayes = rapport.impayes + 1
      if f.impayes >= hommes.reglages.semaines_impayees_max then
        table.insert(partants, f)
      end
    end
  end
  for _, f in ipairs(partants) do
    faire_partir(d, f, "solde_impayee", "ui_scriptorium_hommes_parti_solde")
    rapport.partis = rapport.partis + 1
  end
  if rapport.payes > 0 then
    annoncer("ui_scriptorium_hommes_solde_payee", { complement = rapport.somme .. " groschen" })
  end
  if rapport.impayes > 0 then
    annoncer("ui_scriptorium_hommes_solde_impayee", { importance = "alerte" })
  end
  verifier_rangs(d, rapport)
  enregistrer()
  return rapport
end

local function repas_du_jour(d, rapport)
  local affames = 0
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if coffre().prelever_reserve("vivres", hommes.reglages.ration, "repas") then
      f.moral = borner(f.moral + 2, 0, 100)
    else
      f.moral = borner(f.moral - 10, 0, 100)
      affames = affames + 1
    end
  end
  if affames > 0 then
    annoncer("ui_scriptorium_hommes_faim")
  end
  rapport.affames = affames
  -- Soins : un jour de moins, deux avec un barbier valide.
  local soin = barbier_valide(d) and 2 or 1
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.blessure > 0 then
      f.blessure = math.max(0, f.blessure - soin)
      if f.blessure == 0 then
        rapport.gueris = (rapport.gueris or 0) + 1
      end
    end
  end
end

local function aube_du_jour(d, heure, rapport)
  local partants = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if heure >= f.contrat.fin then
      table.insert(partants, { f = f, cause = "fin_de_contrat", cle = "ui_scriptorium_hommes_parti_fin_contrat" })
    elseif f.moral < hommes.reglages.moral_desertion then
      table.insert(partants, { f = f, cause = "desertion", cle = "ui_scriptorium_hommes_parti_moral" })
    end
  end
  for _, p in ipairs(partants) do
    faire_partir(d, p.f, p.cause, p.cle)
    rapport.partis = (rapport.partis or 0) + 1
  end
end

-- ---------------------------------------------------------------- battement

-- Fait avancer les hommes jusqu'à l'heure du jeu : aubes, repas, paies, puis les ordres.
function hommes.battre()
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local rapport = { aubes = 0, repas = 0, paies = 0, ordres = 0, changements = 0 }
  if #d.ordre == 0 and #d.anciens == 0 then
    return rapport
  end
  if d.derniere_heure == nil then
    d.derniere_heure = heure
  end
  if heure < d.derniere_heure then
    -- L'horloge a reculé (autre partie chargée) : on repart d'ici.
    d.derniere_heure = heure
    d.derniere_aube = jour_de(heure - hommes.reglages.heure_lever)
    d.dernier_jour_repas = jour_de(heure - hommes.reglages.heure_repas)
    rapport.changements = rapport.changements + 1
  end
  -- Aubes passées.
  local aube = jour_de(heure - hommes.reglages.heure_lever)
  if d.derniere_aube == nil then d.derniere_aube = aube end
  while d.derniere_aube < aube do
    d.derniere_aube = d.derniere_aube + 1
    aube_du_jour(d, heure, rapport)
    rapport.aubes = rapport.aubes + 1
    rapport.changements = rapport.changements + 1
  end
  -- Repas passés.
  local repas = jour_de(heure - hommes.reglages.heure_repas)
  if d.dernier_jour_repas == nil then d.dernier_jour_repas = repas end
  while d.dernier_jour_repas < repas do
    d.dernier_jour_repas = d.dernier_jour_repas + 1
    repas_du_jour(d, rapport)
    rapport.repas = rapport.repas + 1
    rapport.changements = rapport.changements + 1
  end
  -- Paies passées.
  while d.prochaine_paie and heure >= d.prochaine_paie do
    d.prochaine_paie = d.prochaine_paie + 7 * 24
    hommes.payer_la_solde()
    rapport.paies = rapport.paies + 1
    rapport.changements = rapport.changements + 1
  end
  if rapport.changements > 0 then
    verifier_rangs(d, rapport)
  end
  -- Les affectations à durée tombent d'elles-mêmes.
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.affectation and f.affectation.fin and heure >= f.affectation.fin then
      f.affectation = nil
      rapport.changements = rapport.changements + 1
    end
  end
  -- Ordres, seulement quand l'activité change.
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.personnage then
      local a = hommes.activite_de(id, heure)
      local resume = a.activite .. "@" .. tostring(a.lieu)
      if f.derniere_activite ~= resume then
        jeu().ordonner(f.personnage, a.activite, a.position, a.lieu)
        f.derniere_activite = resume
        rapport.ordres = rapport.ordres + 1
      end
    end
  end
  d.derniere_heure = heure
  if rapport.changements > 0 then
    enregistrer()
  end
  return rapport
end

-- Après un chargement : fait revenir les personnages manquants. Rend (revenus, manquants).
function hommes.redresser()
  local d = donnees()
  local revenus, manquants = 0, 0
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local present = f.personnage and jeu().personnage_existe(f.personnage)
    if not present then
      if faire_venir(d, f) then revenus = revenus + 1 else manquants = manquants + 1 end
    end
  end
  if revenus > 0 then
    enregistrer()
  end
  jeu().journal("Hommes : redressés, " .. revenus .. " revenu(s), " .. manquants .. " manquant(s)")
  return revenus, manquants
end

Scriptorium.declarer_morceau("hommes", function()
  -- Le battement est lancé par le poste d'essai ou par le socle une fois la partie chargée.
end)

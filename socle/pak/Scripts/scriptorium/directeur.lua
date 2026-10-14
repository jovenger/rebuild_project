-- Le Directeur : le personnage qui tient le camp, et la Gestion du camp (un menu en données).
-- Fiche de comportement : docs/socle/fiches/06_directeur.md

Scriptorium = Scriptorium or {}

local directeur = {}
Scriptorium.directeur = directeur

directeur.nom = "Scriptorium_Directeur"

-- Prix d'achat des réserves, en groschen l'unité, payés au coffre.
directeur.prix = {
  vivres = 2, biere = 1, fourrage = 1, traits = 1, bois = 1, herbes = 3, fer = 5, cuir = 3,
}

-- Coût d'un agrandissement du camp, par niveau gagné.
directeur.agrandissement = { bois = 30, groschen = 100 }

-- Sa journée : de (inclus) à (exclu), lieu du camp.
directeur.journee = {
  { de = 6, a = 20, activite = "comptes", place = "coffre_camp" },
  { de = 20, a = 22, activite = "veillee", place = "feu_central" },
  { de = 22, a = 6, activite = "sommeil", place = "lit_directeur" },
}

local function jeu()
  return Scriptorium.jeu
end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

local function camp() return Scriptorium.camp end
local function coffre() return Scriptorium.coffre end
local function hommes() return Scriptorium.hommes end
local function bataille() return Scriptorium.bataille end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return { installe = false, personnage = nil, derniere_activite = nil }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("directeur") then
    registre.declarer_case("directeur", 1, donnees_neuves)
  end
  return registre.lire("directeur")
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

local function refuser(raison, detail)
  jeu().journal("Directeur : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

-- ---------------------------------------------------------------- le personnage

local function faire_venir(d)
  if d.personnage and jeu().personnage_existe(d.personnage) then
    return true
  end
  local position = camp().position_de("lit_directeur")
  local personnage = jeu().faire_venir_directeur(position)
  if personnage == nil then
    jeu().journal("Directeur : le jeu n'a pas fait venir le Directeur ; il reste sur le registre")
    d.personnage = nil
    return false
  end
  d.personnage = personnage
  d.derniere_activite = nil
  return true
end

function directeur.est_installe()
  return donnees().installe
end

function directeur.installer()
  local d = donnees()
  if not camp().est_fonde() then
    return refuser("camp_absent")
  end
  if d.installe then
    return refuser("deja_installe")
  end
  d.installe = true
  if camp().occupant_de("lit_directeur") == nil then
    camp().reserver("lit_directeur", "directeur")
  end
  faire_venir(d)
  enregistrer()
  annoncer("ui_scriptorium_directeur_installe")
  return true
end

function directeur.redresser()
  local d = donnees()
  if not d.installe then
    return false
  end
  local revenu = faire_venir(d)
  if revenu then
    enregistrer()
  end
  return revenu
end

-- Le Directeur s'en va (le camp est levé).
function directeur.congedier()
  local d = donnees()
  if not d.installe then
    return refuser("pas_de_directeur")
  end
  if d.personnage then
    jeu().renvoyer_homme(d.personnage)
  end
  d.installe = false
  d.personnage = nil
  d.derniere_activite = nil
  enregistrer()
  return true
end

function directeur.activite(heure)
  local h = heure - math.floor(heure / 24) * 24
  for _, t in ipairs(directeur.journee) do
    if (t.de < t.a and h >= t.de and h < t.a) or (t.de > t.a and (h >= t.de or h < t.a)) then
      return { activite = t.activite, place = t.place, position = camp().position_de(t.place) }
    end
  end
  return nil
end

function directeur.battre()
  local d = donnees()
  local rapport = { ordres = 0 }
  if not d.installe or not d.personnage then
    return rapport
  end
  local a = directeur.activite(jeu().heure_du_jeu())
  if a and d.derniere_activite ~= a.activite then
    jeu().ordonner(d.personnage, a.activite, a.position, a.place)
    d.derniere_activite = a.activite
    rapport.ordres = 1
  end
  return rapport
end

-- ---------------------------------------------------------------- le rapport

function directeur.rapport()
  local effectif = hommes().effectif()
  local moral, n = 0, 0
  for _, id in ipairs(hommes().liste()) do
    moral = moral + hommes().fiche(id).moral
    n = n + 1
  end
  local bilan = coffre().bilan()
  local resultats = bataille().resultats()
  return {
    groschen = bilan.groschen,
    reserves = bilan.reserves,
    hommes = effectif.total,
    valides = effectif.valides,
    blesses = effectif.blesses,
    presents = effectif.presents,
    moral_moyen = (n > 0) and math.floor(moral / n + 0.5) or nil,
    niveau_de_moral = (n > 0) and hommes().niveau_de_moral(moral / n) or nil,
    camp_niveau = camp().niveau(),
    capacite = camp().capacite(),
    bandes_en_marche = #bataille().bandes(),
    derniere_bataille = resultats[#resultats] and resultats[#resultats].issue or nil,
    directeur_present = donnees().personnage ~= nil,
  }
end

-- ---------------------------------------------------------------- la Gestion du camp

local entrees_ajoutees = {}

-- Les autres morceaux ajoutent leurs entrées : { action, cle, parametres, disponible = fonction, agir = fonction }.
function directeur.ajouter_entree(entree)
  assert(type(entree.action) == "string" and type(entree.agir) == "function", "directeur : entrée mal formée")
  for i, e in ipairs(entrees_ajoutees) do
    if e.action == entree.action then
      entrees_ajoutees[i] = entree
      return
    end
  end
  table.insert(entrees_ajoutees, entree)
end

function directeur.retirer_entrees()
  entrees_ajoutees = {}
end

local function nombre_valide(n)
  return type(n) == "number" and n > 0 and math.floor(n) == n
end

-- Le prix d'une réserve chez les villages, selon la réputation de la Compagnie (morceau 9).
function directeur.prix_de(sorte)
  local prix = directeur.prix[sorte]
  if not prix then
    return nil
  end
  local facteur = 1
  if Scriptorium.discipline and Scriptorium.discipline.facteur_de_prix then
    facteur = Scriptorium.discipline.facteur_de_prix()
  end
  return math.max(1, math.floor(prix * facteur + 0.5))
end

-- Le coût d'un achat, calculé sur le total : la réputation compte même sur les denrées à un groschen.
function directeur.cout_de(sorte, quantite)
  local prix = directeur.prix[sorte]
  if not prix then
    return nil
  end
  local facteur = 1
  if Scriptorium.discipline and Scriptorium.discipline.facteur_de_prix then
    facteur = Scriptorium.discipline.facteur_de_prix()
  end
  return math.max(1, math.floor(prix * quantite * facteur + 0.5))
end

local function roles_disponibles()
  local liste = {}
  for role in pairs(hommes().roles) do table.insert(liste, role) end
  table.sort(liste)
  return liste
end

local function sortes_disponibles()
  local liste = {}
  for sorte in pairs(directeur.prix) do table.insert(liste, sorte) end
  table.sort(liste)
  return liste
end

local entrees_de_base = {
  { action = "rapport", cle = "ui_scriptorium_gestion_rapport", parametres = {},
    disponible = function() return true end,
    agir = function() return true, directeur.rapport() end },
  { action = "livre", cle = "ui_scriptorium_gestion_livre", parametres = {},
    disponible = function() return true end,
    agir = function() return true, coffre().livre(20) end },
  { action = "payer_la_solde", cle = "ui_scriptorium_gestion_payer", parametres = {},
    disponible = function()
      if hommes().effectif().total == 0 then return false, "personne" end
      return true
    end,
    agir = function() return true, hommes().payer_la_solde() end },
  { action = "engager", cle = "ui_scriptorium_gestion_engager", parametres = { "role", "semaines" },
    disponible = function()
      if #camp().places_libres("lit", "hommes") == 0 then return false, "pas_de_lit" end
      return true, { roles = roles_disponibles() }
    end,
    agir = function(p)
      local id, raison = hommes().embaucher({ role = p.role, semaines = p.semaines, prime = p.prime, solde = p.solde })
      if not id then return false, raison end
      return true, id
    end },
  { action = "renvoyer", cle = "ui_scriptorium_gestion_renvoyer", parametres = { "id" },
    disponible = function()
      if hommes().effectif().total == 0 then return false, "personne" end
      return true, { hommes = hommes().liste() }
    end,
    agir = function(p) return hommes().renvoyer(p.id) end },
  { action = "nommer_capitaine", cle = "ui_scriptorium_gestion_capitaine", parametres = { "id" },
    disponible = function()
      if hommes().effectif().total == 0 then return false, "personne" end
      return true, { hommes = hommes().liste() }
    end,
    agir = function(p) return hommes().nommer_capitaine(p.id) end },
  { action = "renouveler", cle = "ui_scriptorium_gestion_renouveler", parametres = { "id", "semaines" },
    disponible = function()
      if hommes().effectif().total == 0 then return false, "personne" end
      return true, { hommes = hommes().liste() }
    end,
    agir = function(p) return hommes().renouveler(p.id, p.semaines) end },
  { action = "acheter", cle = "ui_scriptorium_gestion_acheter", parametres = { "sorte", "quantite" },
    disponible = function()
      if coffre().solde() <= 0 then return false, "coffre_vide" end
      local prix = {}
      for sorte in pairs(directeur.prix) do prix[sorte] = directeur.prix_de(sorte) end
      return true, { sortes = sortes_disponibles(), prix = prix }
    end,
    agir = function(p)
      if not directeur.prix[p.sorte] then return false, "sorte_inconnue" end
      if not nombre_valide(p.quantite) then return false, "quantite_invalide" end
      local cout = directeur.cout_de(p.sorte, p.quantite)
      if coffre().solde() < cout then return false, "coffre_insuffisant" end
      local ok, raison = coffre().payer(cout, "achat_" .. p.sorte)
      if not ok then return false, raison end
      coffre().ajouter_reserve(p.sorte, p.quantite, "achat")
      return true, { cout = cout, reserve = coffre().reserve(p.sorte) }
    end },
  { action = "deposer", cle = "ui_scriptorium_gestion_deposer", parametres = { "montant" },
    disponible = function()
      if jeu().groschen_d_henry() <= 0 then return false, "henry_sans_le_sou" end
      return true, { bourse = jeu().groschen_d_henry() }
    end,
    agir = function(p) return coffre().deposer_par_henry(p.montant, "depot") end },
  { action = "verser", cle = "ui_scriptorium_gestion_verser", parametres = { "montant" },
    disponible = function()
      if coffre().solde() <= 0 then return false, "coffre_vide" end
      return true, { coffre = coffre().solde() }
    end,
    agir = function(p) return coffre().verser_a_henry(p.montant, "versement_henry") end },
  { action = "agrandir_le_camp", cle = "ui_scriptorium_gestion_agrandir", parametres = {},
    disponible = function()
      if camp().niveau() >= camp().niveau_maximal then return false, "niveau_maximal" end
      if coffre().reserve("bois") < directeur.agrandissement.bois then return false, "bois_insuffisant" end
      if coffre().solde() < directeur.agrandissement.groschen then return false, "coffre_insuffisant" end
      return true, { bois = directeur.agrandissement.bois, groschen = directeur.agrandissement.groschen }
    end,
    agir = function()
      if coffre().reserve("bois") < directeur.agrandissement.bois then return false, "bois_insuffisant" end
      if coffre().solde() < directeur.agrandissement.groschen then return false, "coffre_insuffisant" end
      if camp().niveau() >= camp().niveau_maximal then return false, "niveau_maximal" end
      coffre().payer(directeur.agrandissement.groschen, "agrandissement")
      coffre().prelever_reserve("bois", directeur.agrandissement.bois, "agrandissement")
      return camp().agrandir()
    end },
  { action = "lever_le_camp", cle = "ui_scriptorium_gestion_lever", parametres = {},
    disponible = function()
      if #bataille().bandes() > 0 then return false, "bande_en_marche" end
      return true
    end,
    agir = function()
      if #bataille().bandes() > 0 then return false, "bande_en_marche" end
      for _, id in ipairs(hommes().liste()) do
        hommes().renvoyer(id)
      end
      directeur.congedier()
      return camp().lever()
    end },
}

-- Le menu de la Gestion du camp : une liste d'entrées { action, cle, parametres, disponible, raison, detail }.
function directeur.menu()
  local menu = {}
  local toutes = {}
  for _, e in ipairs(entrees_de_base) do table.insert(toutes, e) end
  for _, e in ipairs(entrees_ajoutees) do table.insert(toutes, e) end
  for _, e in ipairs(toutes) do
    local disponible, detail = e.disponible()
    local entree = { action = e.action, cle = e.cle, parametres = e.parametres or {}, disponible = disponible == true }
    if disponible then
      entree.detail = detail
    else
      entree.raison = detail
    end
    table.insert(menu, entree)
  end
  return menu
end

local function entree_par_action(action)
  for _, e in ipairs(entrees_de_base) do
    if e.action == action then return e end
  end
  for _, e in ipairs(entrees_ajoutees) do
    if e.action == action then return e end
  end
  return nil
end

-- Fait agir le Directeur. Rend true et un résultat, ou false et une raison.
function directeur.agir(action, parametres)
  parametres = parametres or {}
  if not donnees().installe then
    return refuser("pas_de_directeur")
  end
  local e = entree_par_action(action)
  if not e then
    return refuser("action_inconnue", tostring(action))
  end
  for _, nom in ipairs(e.parametres or {}) do
    if parametres[nom] == nil then
      return refuser("parametre_manquant", action .. " : " .. nom)
    end
  end
  local ok, resultat = e.agir(parametres)
  if not ok then
    jeu().journal("Directeur : « " .. action .. " » refusé : " .. tostring(resultat))
  end
  return ok, resultat
end

Scriptorium.declarer_morceau("directeur", function()
  -- Le Directeur s'installe par la Gestion du camp ou le poste d'essai, une fois le camp fondé.
end)

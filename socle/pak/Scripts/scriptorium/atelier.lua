-- L'atelier : l'alchimie (des herbes en remèdes) et l'armurerie (l'entretien des armes).
-- Fiche de comportement : docs/socle/fiches/07_enceinte.md

local Scriptorium = Scriptorium

local atelier = {}
Scriptorium.atelier = atelier

atelier.reglages = {
  usure_par_bataille = 20,
  seuil_usure = 60,          -- au-delà, l'homme pèse moins au combat
  malus_usure = 0.7,
  reparation = 25,           -- points rendus par entretien
  hommes_par_jour = 5,       -- combien l'armurier répare par jour
}

-- Recettes d'alchimie : ingrédients pris au coffre, produit mis au coffre.
atelier.recettes = {
  remede  = { ingredients = { herbes = 3, biere = 1 }, produit = "remedes", cle = "ui_scriptorium_gestion_remede" },
  onguent = { ingredients = { herbes = 2, cuir = 1 }, produit = "onguents", cle = "ui_scriptorium_gestion_onguent" },
}

-- Soins : ce que chacun prend au coffre et les jours de soins qu'il ôte à un blessé. L'onguent, soin léger,
-- à la validation de la fiche par JoVenGer (14/10).
atelier.soins = {
  remede  = { reserve = "remedes",  jours = 2, manque = "pas_de_remede",  action = "soigner",
              cle = "ui_scriptorium_gestion_soigner" },
  onguent = { reserve = "onguents", jours = 1, manque = "pas_d_onguent", action = "soigner_onguent",
              cle = "ui_scriptorium_gestion_soigner_onguent" },
}

local function jeu() return Scriptorium.jeu end
local function coffre() return Scriptorium.coffre end
local function hommes() return Scriptorium.hommes end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return { usure = {}, dernier_jour_entretien = nil }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("atelier") then
    registre.declarer_case("atelier", 1, donnees_neuves)
  end
  return registre.lire("atelier")
end

local function enregistrer()
  Scriptorium.registre.enregistrer("atelier")
end

local function refuser(raison, detail)
  jeu().journal("Atelier : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

local function nombre_valide(n)
  return type(n) == "number" and n > 0 and math.floor(n) == n
end

-- ---------------------------------------------------------------- alchimie

function atelier.preparer(nom, nombre)
  local recette = atelier.recettes[nom]
  if not recette then
    return refuser("recette_inconnue", tostring(nom))
  end
  if nombre == nil then nombre = 1 end
  if not nombre_valide(nombre) then
    return refuser("nombre_invalide", tostring(nombre))
  end
  for sorte, quantite in pairs(recette.ingredients) do
    if (coffre().reserve(sorte) or 0) < quantite * nombre then
      return refuser("ingredients_insuffisants", sorte .. " " .. (quantite * nombre) .. " > " .. tostring(coffre().reserve(sorte)))
    end
  end
  for sorte, quantite in pairs(recette.ingredients) do
    coffre().prelever_reserve(sorte, quantite * nombre, "alchimie_" .. nom)
  end
  coffre().ajouter_reserve(recette.produit, nombre, "alchimie_" .. nom)
  return true, coffre().reserve(recette.produit)
end

-- Soigne un blessé avec un remède (par défaut) ou un onguent.
function atelier.soigner(id, nom_du_soin)
  local soin = atelier.soins[nom_du_soin or "remede"]
  if not soin then
    return refuser("soin_inconnu", tostring(nom_du_soin))
  end
  local f = hommes().fiche(id)
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if f.blessure == 0 then
    return refuser("pas_blesse", id)
  end
  if coffre().reserve(soin.reserve) < 1 then
    return refuser(soin.manque)
  end
  coffre().prelever_reserve(soin.reserve, 1, "soin")
  hommes().guerir(id, soin.jours)
  return true, hommes().fiche(id).blessure
end

-- ---------------------------------------------------------------- armurerie

function atelier.usure_de(id)
  return donnees().usure[id] or 0
end

function atelier.user(id, points)
  local d = donnees()
  if not hommes().fiche(id) then
    return refuser("homme_inconnu", tostring(id))
  end
  d.usure[id] = math.min(100, (d.usure[id] or 0) + (points or atelier.reglages.usure_par_bataille))
  enregistrer()
  return true
end

-- Use l'équipement de chaque combattant d'une bataille.
function atelier.user_apres_bataille(combattants)
  -- Fiche 16 : l'usure réelle des objets est à Scriptorium ; l'usure en points, éteinte.
  if not Scriptorium.actif("usure_en_points") then
    return
  end
  local d = donnees()
  for _, combattant in ipairs(combattants) do
    if hommes().fiche(combattant) then
      d.usure[combattant] = math.min(100, (d.usure[combattant] or 0) + atelier.reglages.usure_par_bataille)
    end
  end
  enregistrer()
end

-- Facteur de poids au combat selon l'usure.
function atelier.facteur_de(id)
  if Scriptorium.actif("usure_en_points") and atelier.usure_de(id) > atelier.reglages.seuil_usure then
    return atelier.reglages.malus_usure
  end
  return 1
end

local function armurier_valide()
  for _, id in ipairs(hommes().liste()) do
    local f = hommes().fiche(id)
    if f.role == "armurier" and f.blessure == 0 then
      return true
    end
  end
  return false
end

-- L'entretien du jour : l'armurier répare les plus usés contre du fer et du cuir.
function atelier.entretenir()
  local d = donnees()
  local rapport = { repares = 0, fer = 0, cuir = 0, sans_armurier = false, sans_matiere = false }
  if not Scriptorium.actif("usure_en_points") then
    return rapport
  end
  if not armurier_valide() then
    rapport.sans_armurier = true
    return rapport
  end
  local uses = {}
  for _, id in ipairs(hommes().liste()) do
    if (d.usure[id] or 0) > 0 then
      table.insert(uses, { id = id, usure = d.usure[id] })
    end
  end
  table.sort(uses, function(a, b)
    if a.usure ~= b.usure then return a.usure > b.usure end
    return a.id < b.id
  end)
  for i = 1, math.min(#uses, atelier.reglages.hommes_par_jour) do
    if coffre().reserve("fer") < 1 or coffre().reserve("cuir") < 1 then
      rapport.sans_matiere = true
      break
    end
    coffre().prelever_reserve("fer", 1, "entretien")
    coffre().prelever_reserve("cuir", 1, "entretien")
    d.usure[uses[i].id] = math.max(0, uses[i].usure - atelier.reglages.reparation)
    rapport.repares = rapport.repares + 1
    rapport.fer = rapport.fer + 1
    rapport.cuir = rapport.cuir + 1
  end
  -- Oublier les partis.
  for id in pairs(d.usure) do
    if not hommes().fiche(id) then d.usure[id] = nil end
  end
  enregistrer()
  return rapport
end

-- Un entretien par jour, au repas.
function atelier.battre()
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local jour = math.floor((heure - hommes().reglages.heure_repas) / 24)
  local rapport = { entretiens = 0 }
  if d.dernier_jour_entretien == nil then
    d.dernier_jour_entretien = jour
    return rapport
  end
  while d.dernier_jour_entretien < jour do
    d.dernier_jour_entretien = d.dernier_jour_entretien + 1
    rapport.dernier = atelier.entretenir()
    rapport.entretiens = rapport.entretiens + 1
  end
  if rapport.entretiens > 0 then
    enregistrer()
  end
  return rapport
end

-- ---------------------------------------------------------------- Gestion du camp

local function entrees()
  if not Scriptorium.directeur then
    return
  end
  for nom, recette in pairs(atelier.recettes) do
    Scriptorium.directeur.ajouter_entree({
      action = "preparer_" .. nom, cle = recette.cle, parametres = { "nombre" },
      disponible = function()
        for sorte, quantite in pairs(recette.ingredients) do
          if (coffre().reserve(sorte) or 0) < quantite then return false, "ingredients_insuffisants" end
        end
        return true, { ingredients = recette.ingredients, en_reserve = coffre().reserve(recette.produit) }
      end,
      agir = function(p) return atelier.preparer(nom, p.nombre) end,
    })
  end
  for _, nom_du_soin in ipairs({ "remede", "onguent" }) do
    local soin = atelier.soins[nom_du_soin]
    Scriptorium.directeur.ajouter_entree({
      action = soin.action, cle = soin.cle, parametres = { "id" },
      disponible = function()
        if coffre().reserve(soin.reserve) < 1 then return false, soin.manque end
        local blesses = {}
        for _, id in ipairs(hommes().liste()) do
          if hommes().fiche(id).blessure > 0 then table.insert(blesses, id) end
        end
        if #blesses == 0 then return false, "personne_de_blesse" end
        return true, { blesses = blesses, en_reserve = coffre().reserve(soin.reserve) }
      end,
      agir = function(p) return atelier.soigner(p.id, nom_du_soin) end,
    })
  end
end
atelier.installer_les_entrees = entrees

Scriptorium.declarer_morceau("atelier", function()
  entrees()
end)
entrees()

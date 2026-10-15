-- Coffre et logistique : l'argent du camp, ses réserves et son livre de comptes.
-- Fiche de comportement : docs/socle/fiches/02_coffre.md
--
-- Règle de JoVenGer : le camp paie au coffre, jamais avec la bourse d'Henry.
-- Une dépense que le coffre ne peut pas couvrir est refusée ; rien n'est pris ailleurs.

local Scriptorium = Scriptorium

local coffre = {}
Scriptorium.coffre = coffre

coffre.reglages = {
  lignes_gardees = 50,    -- lignes du livre conservées dans la partie (choix de JoVenGer, 14/10)
}

-- Les réserves du camp, par sorte, avec le message d'épuisement de chacune.
coffre.sortes = {
  vivres   = { cle_epuise = "ui_scriptorium_coffre_epuise_vivres" },
  biere    = { cle_epuise = "ui_scriptorium_coffre_epuise_biere" },
  fourrage = { cle_epuise = "ui_scriptorium_coffre_epuise_fourrage" },
  traits   = { cle_epuise = "ui_scriptorium_coffre_epuise_traits" },
  bois     = { cle_epuise = "ui_scriptorium_coffre_epuise_bois" },
  herbes   = { cle_epuise = "ui_scriptorium_coffre_epuise_herbes" },
  fer      = { cle_epuise = "ui_scriptorium_coffre_epuise_fer" },
  cuir     = { cle_epuise = "ui_scriptorium_coffre_epuise_cuir" },
  remedes  = { cle_epuise = "ui_scriptorium_coffre_epuise_remedes" },
  onguents = { cle_epuise = "ui_scriptorium_coffre_epuise_onguents" },
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
  local reserves = {}
  for sorte in pairs(coffre.sortes) do
    reserves[sorte] = 0
  end
  return {
    groschen = 0,
    entrees = 0,
    sorties = 0,
    reserves = reserves,
    livre = { lignes = {}, prochain_numero = 1 },
  }
end

-- La case est déclarée au premier usage, pour survivre à une remise à zéro du registre.
local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("coffre") then
    registre.declarer_case("coffre", 1, donnees_neuves)
  end
  local d = registre.lire("coffre")
  -- Une sorte ajoutée au socle après coup part à zéro.
  for sorte in pairs(coffre.sortes) do
    if d.reserves[sorte] == nil then
      d.reserves[sorte] = 0
    end
  end
  return d
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

-- ---------------------------------------------------------------- contrôles

local function montant_valide(montant)
  return type(montant) == "number" and montant > 0 and math.floor(montant) == montant
end

local function motif_valide(motif)
  return type(motif) == "string" and string.find(motif, "^[a-z][a-z0-9_]*$") ~= nil
end

local function refuser(raison, detail)
  jeu().journal("Coffre : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

local function controler(montant, motif)
  if not montant_valide(montant) then
    return refuser("montant_invalide", tostring(montant))
  end
  if not motif_valide(motif) then
    return refuser("motif_invalide", tostring(motif))
  end
  return true
end

-- ---------------------------------------------------------------- livre

local function inscrire(d, sorte, montant, motif, apres)
  local livre = d.livre
  table.insert(livre.lignes, {
    numero = livre.prochain_numero,
    moment = jeu().heure_du_jeu(),
    sorte = sorte,
    montant = montant,
    motif = motif,
    apres = apres,
  })
  livre.prochain_numero = livre.prochain_numero + 1
  while #livre.lignes > coffre.reglages.lignes_gardees do
    table.remove(livre.lignes, 1)
  end
end

local function crediter(d, montant, motif)
  d.groschen = d.groschen + montant
  d.entrees = d.entrees + montant
  inscrire(d, "groschen", montant, motif, d.groschen)
end

local function debiter(d, montant, motif)
  d.groschen = d.groschen - montant
  d.sorties = d.sorties + montant
  inscrire(d, "groschen", -montant, motif, d.groschen)
end

-- ---------------------------------------------------------------- groschen

function coffre.solde()
  return donnees().groschen
end

-- Recette du camp (butin, prime, vente) : entre au coffre.
function coffre.encaisser(montant, motif)
  local ok, raison = controler(montant, motif)
  if not ok then return false, raison end
  local d = donnees()
  crediter(d, montant, motif)
  enregistrer()
  return true
end

-- Dépense du camp : sort du coffre, et de nulle part ailleurs.
function coffre.payer(montant, motif)
  local ok, raison = controler(montant, motif)
  if not ok then return false, raison end
  local d = donnees()
  if d.groschen < montant then
    annoncer("ui_scriptorium_coffre_manque", { groupe = "coffre_manque" })
    return refuser("coffre_insuffisant", motif .. " " .. montant .. " > " .. d.groschen)
  end
  debiter(d, montant, motif)
  enregistrer()
  return true
end

-- Le camp remet des groschen à Henry : le coffre n'est débité que si le jeu a bien donné.
function coffre.verser_a_henry(montant, motif)
  local ok, raison = controler(montant, motif)
  if not ok then return false, raison end
  local d = donnees()
  if d.groschen < montant then
    annoncer("ui_scriptorium_coffre_manque", { groupe = "coffre_manque" })
    return refuser("coffre_insuffisant", motif .. " " .. montant .. " > " .. d.groschen)
  end
  if not jeu().donner_groschen_a_henry(montant) then
    return refuser("jeu_en_echec", "le jeu n'a pas remis " .. montant .. " groschen à Henry")
  end
  debiter(d, montant, motif)
  enregistrer()
  return true
end

-- Henry dépose des groschen de sa bourse : le coffre n'est crédité que si le jeu les a bien retirés.
function coffre.deposer_par_henry(montant, motif)
  local ok, raison = controler(montant, motif)
  if not ok then return false, raison end
  if jeu().groschen_d_henry() < montant then
    annoncer("ui_scriptorium_coffre_henry_manque")
    return refuser("henry_insuffisant", montant .. " > " .. jeu().groschen_d_henry())
  end
  if not jeu().retirer_groschen_a_henry(montant) then
    return refuser("jeu_en_echec", "le jeu n'a pas retiré " .. montant .. " groschen à Henry")
  end
  local d = donnees()
  crediter(d, montant, motif)
  enregistrer()
  return true
end

-- ---------------------------------------------------------------- réserves

function coffre.reserve(sorte)
  if not coffre.sortes[sorte] then
    return nil
  end
  return donnees().reserves[sorte]
end

function coffre.ajouter_reserve(sorte, quantite, motif)
  if not coffre.sortes[sorte] then
    return refuser("sorte_inconnue", tostring(sorte))
  end
  local ok, raison = controler(quantite, motif)
  if not ok then return false, raison end
  local d = donnees()
  d.reserves[sorte] = d.reserves[sorte] + quantite
  inscrire(d, sorte, quantite, motif, d.reserves[sorte])
  enregistrer()
  return true
end

function coffre.prelever_reserve(sorte, quantite, motif)
  if not coffre.sortes[sorte] then
    return refuser("sorte_inconnue", tostring(sorte))
  end
  local ok, raison = controler(quantite, motif)
  if not ok then return false, raison end
  local d = donnees()
  if d.reserves[sorte] < quantite then
    return refuser("reserve_insuffisante", sorte .. " " .. quantite .. " > " .. d.reserves[sorte])
  end
  d.reserves[sorte] = d.reserves[sorte] - quantite
  inscrire(d, sorte, -quantite, motif, d.reserves[sorte])
  if d.reserves[sorte] == 0 then
    annoncer(coffre.sortes[sorte].cle_epuise)
  end
  enregistrer()
  return true
end

-- ---------------------------------------------------------------- lecture

-- Les n dernières lignes du livre (toutes si n est absent), de la plus ancienne à la plus récente.
function coffre.livre(n)
  local lignes = donnees().livre.lignes
  local debut = 1
  if n and n < #lignes then
    debut = #lignes - n + 1
  end
  local copie = {}
  for i = debut, #lignes do
    local l = lignes[i]
    table.insert(copie, { numero = l.numero, moment = l.moment, sorte = l.sorte,
                          montant = l.montant, motif = l.motif, apres = l.apres })
  end
  return copie
end

function coffre.bilan()
  local d = donnees()
  local reserves = {}
  for sorte in pairs(coffre.sortes) do
    reserves[sorte] = d.reserves[sorte]
  end
  return {
    groschen = d.groschen,
    entrees = d.entrees,
    sorties = d.sorties,
    reserves = reserves,
    lignes = #d.livre.lignes,
    prochain_numero = d.livre.prochain_numero,
  }
end

Scriptorium.declarer_morceau("coffre", function()
  -- Rien à lancer : la case se déclare au premier usage.
end)

-- Le Directeur : le personnage qui tient le camp, et la Gestion du camp (un menu en données).
-- Fiche de comportement : docs/socle/fiches/06_directeur.md

local Scriptorium = Scriptorium

local directeur = {}
Scriptorium.directeur = directeur

directeur.nom = "Scriptorium_Directeur"

-- Prix d'achat des réserves, en groschen l'unité, payés au coffre.
directeur.prix = {
  vivres = 2, biere = 1, fourrage = 1, traits = 1, bois = 1, herbes = 3, fer = 5, cuir = 3,
}

-- Coût d'un agrandissement du camp, par niveau gagné.
directeur.agrandissement = { bois = 30, groschen = 100 }

-- Sa journée : de (inclus) à (exclu), lieu du camp. Réglable par le fichier (section « journee_du_directeur »,
-- fiche 16, 3 b).
directeur.journee = {
  { nom = "comptes", de = 6, a = 20, activite = "comptes", lieu = "coffre_camp" },
  { nom = "veillee", de = 20, a = 22, activite = "veillee", lieu = "feu_central" },
  { nom = "sommeil", de = 22, a = 6, activite = "sommeil", lieu = "lit_directeur" },
}

function directeur.verifier_journee()
  return Scriptorium.journee_valable(directeur.journee)
end

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
  Scriptorium.registre.enregistrer("directeur")
end

local function refuser(raison, detail)
  jeu().journal("Directeur : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

-- ---------------------------------------------------------------- le personnage

-- Le Directeur vient sur son âme (fiche 13, réserve « directeur »). Né avant la fiche 13 sur une âme empruntée au jeu
-- (cerveau du jeu), il renaît sur la sienne.
local function faire_venir(d, pres_d_henry)
  local ame = jeu().ame_de("directeur", 1, 1)
  if d.personnage and jeu().personnage_existe(d.personnage) then
    if d.ame == ame then
      return true
    end
    jeu().journal("Directeur : renaît sur son âme")
    jeu().renvoyer_homme(d.personnage)
    d.personnage = nil
  end
  -- V73 f 3 b : sur une autre carte, près d'Henry (derrière lui, hors de sa vue). La bascule (19/10) : sa place donnée à
  -- l'installation (camp adopté : celle de Scriptorium), sinon son lit du plan.
  local position = pres_d_henry and hommes() and hommes().point_pres_d_henry()
    or (d.lieu_de_naissance and { x = d.lieu_de_naissance.x, y = d.lieu_de_naissance.y, z = d.lieu_de_naissance.z }) or camp().position_de("lit_directeur")
  local personnage = jeu().faire_venir_directeur(position, ame, (not pres_d_henry and d.lieu_de_naissance) and d.lieu_de_naissance.cap or nil)
  if personnage == nil then
    jeu().journal("Directeur : le jeu n'a pas fait venir le Directeur ; il reste sur le registre")
    d.personnage = nil
    return false
  end
  d.personnage = personnage
  d.ame = ame
  d.derniere_activite = nil
  return true
end

-- Fiche 18, 5 c (D67, D69) : la tenue et les armes du Directeur, données par Scriptorium : une liste de { objet
-- (identifiant du jeu), etat (0 à 1) } ou d'identifiants (état neuf) ; portées à chaque naissance, sa tenue de naissance
-- retirée d'abord (la voie des hommes, V71) : au battement qui suit, puis un second passage. Une liste vide : sa tenue
-- de naissance. Rend vrai, ou faux et la raison.
function directeur.donner_les_objets(objets)
  if type(objets) ~= "table" then
    return refuser("objets_invalides")
  end
  local liste = {}
  for i, piece in ipairs(objets) do
    local objet = type(piece) == "table" and piece.objet or piece
    local etat = type(piece) == "table" and piece.etat or 1
    if type(objet) ~= "string" or not string.match(objet, "^%x+%-%x+%-%x+%-%x+%-%x+$")
        or type(etat) ~= "number" or etat <= 0 or etat > 1 then
      return refuser("objet_invalide", tostring(i))
    end
    liste[i] = { objet = string.lower(objet), etat = etat }
  end
  local d = donnees()
  d.objets = (#liste > 0) and liste or nil
  d.habille_pour, d.second_passage_pour = nil, nil
  enregistrer()
  jeu().journal("Directeur : " .. #liste .. " objet(s) donné(s) à porter")
  return true
end

-- Habille le Directeur de ses objets donnés, une fois par personnage (puis un second passage au battement suivant).
local function habiller(d)
  if not d.objets or not d.personnage then
    return
  end
  local portes = {}
  for i, piece in ipairs(d.objets) do portes[i] = piece.objet end
  -- Remis à l'entrée en partie : s'il en manque, tout est recréé (ses pièces de naissance et les restes retirés d'abord,
  -- donc sans doublon) ; sinon, seulement reportés.
  if d.habille_pour == d.personnage and d.second_passage_pour ~= d.personnage then
    for _, objet in ipairs(portes) do
      if (tonumber(jeu().compter_objet(d.personnage, objet)) or 0) == 0 then
        d.habille_pour = nil
        jeu().journal("Directeur : un objet donné manque (" .. objet .. ") : ses objets recréés")
        break
      end
    end
  end
  if d.habille_pour ~= d.personnage then
    local recreer = {}
    for i, piece in ipairs(d.objets) do recreer[i] = { objet = piece.objet, etat = piece.etat } end
    local compte = jeu().equiper_homme(d.personnage, { retirer_naissance = true, creer = {}, etat = 1, recreer = recreer,
                                                       porter = portes })
    d.habille_pour = d.personnage
    jeu().journal("Directeur : habillé de ses objets : " .. tostring(compte))
  elseif d.second_passage_pour ~= d.personnage then
    jeu().faire_porter(d.personnage, portes)
    d.second_passage_pour = d.personnage
    jeu().journal("Directeur : second passage de ses objets")
  end
end

-- Le personnage du Directeur dans le jeu, ou nil.
function directeur.personnage()
  return donnees().personnage
end

function directeur.est_installe()
  return donnees().installe
end

-- Son ordre redonné tout de suite (le saut rapide, V73 f 3 b).
function directeur.redonner_l_ordre()
  donnees().derniere_activite = nil
  return directeur.battre()
end

-- « position » et « cap » (facultatifs ; la bascule, demande du pair, 19/10) : là où il naît et revient à chaque
-- chargement (sur un camp adopté, la place que donne Scriptorium) ; sinon son lit du plan. Sur un camp adopté, aucun lit
-- du plan n'est réservé (son coucher lui vient de Scriptorium). Rend vrai, ou faux et la raison.
function directeur.installer(position, cap)
  local d = donnees()
  if not camp().est_fonde() then
    return refuser("camp_absent")
  end
  if d.installe then
    return refuser("deja_installe")
  end
  if position ~= nil and (type(position) ~= "table" or type(position.x) ~= "number" or type(position.y) ~= "number"
      or type(position.z) ~= "number") then
    return refuser("position_invalide")
  end
  if cap ~= nil and type(cap) ~= "number" then
    return refuser("cap_invalide", tostring(cap))
  end
  d.installe = true
  d.lieu_de_naissance = position and { x = position.x, y = position.y, z = position.z, cap = cap or 0 } or nil
  local adopte = camp().est_adopte and camp().est_adopte()
  if not adopte and camp().occupant_de("lit_directeur") == nil then
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
  -- V73 f 3 b : sur une autre carte que celle du camp, le Directeur n'est refait (près d'Henry) que s'il le suit ; sinon
  -- il reste au camp, au registre.
  local sur_place = camp().sur_sa_carte == nil or camp().sur_sa_carte()
  if not sur_place and not d.suivre then
    if d.personnage and not jeu().personnage_existe(d.personnage) then
      d.personnage = nil
      enregistrer()
    end
    jeu().journal("Directeur : laissé au camp (autre carte)")
    return false
  end
  local revenu = faire_venir(d, not sur_place)
  if revenu then
    enregistrer()
  end
  return revenu
end

-- Entrée en partie : son ordre en cours lui est redonné au battement suivant (son cerveau ne garde pas ses variables
-- à la sauvegarde, V56), et il revient s'il manque.
function directeur.relancer()
  donnees().derniere_activite = nil
  -- Fiche 18, 5 c : à l'entrée en partie, ses objets donnés remis (le jeu lui en ôte au chargement, comme aux hommes).
  donnees().second_passage_pour = nil
  return directeur.redresser()
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

-- Fiche 15, V73 f 1 : le Directeur suit Henry, en tête (« c'est lui le premier qui me suit » ; service pour le guichet).
-- Gardé à son registre : au rechargement, l'ordre redonné le remet en route. « oui » à faux : il reprend sa journée.
-- « formation » (V73 f 1 bis) : il mène une formation du moteur (un modèle de hommes.formations), où se rangent les hommes
-- d'une escorte dont le chef est « directeur ». « a_cheval » (V73 f 2 e) : rien, vrai (toujours à cheval) ou
-- « comme_henry » (à cheval tant qu'Henry l'est) ; son cheval est celui des hommes (un cheval passager).
function directeur.suivre(oui, formation, a_cheval)
  local d = donnees()
  if not d.installe then
    return refuser("pas_de_directeur")
  end
  local formations = Scriptorium.hommes and Scriptorium.hommes.formations or {}
  if formation ~= nil and not formations[formation] then
    return refuser("formation_inconnue", tostring(formation))
  end
  if a_cheval ~= nil and type(a_cheval) ~= "boolean" and a_cheval ~= "comme_henry" then
    return refuser("a_cheval_invalide", tostring(a_cheval))
  end
  d.suivre = (oui ~= false) or nil
  d.formation = d.suivre and formation or nil
  d.a_cheval = (d.suivre and (a_cheval == true or a_cheval == "comme_henry")) and a_cheval or nil
  d.derniere_activite = nil
  enregistrer()
  directeur.battre()
  return true
end

-- V73 f 2 e : le Directeur en sortie à cheval (il suit Henry, à cheval toujours, ou tant qu'Henry l'est).
function directeur.en_sortie_a_cheval()
  local d = donnees()
  local h = Scriptorium.hommes
  return d.suivre == true
    and (d.a_cheval == true or (d.a_cheval == "comme_henry" and h ~= nil and h.henry_monte == true))
end

-- V73 f 2 e : il suit Henry en menant une formation (il reprend alors la tête des escortes d'Henry en formation).
function directeur.mene_une_formation()
  local d = donnees()
  return d.installe == true and d.suivre == true and d.formation ~= nil and d.personnage ~= nil
end

-- La tâche « parler » (demande du pair, 19/10 : le dialogue du Directeur sans le poursuivre) : il se tient debout au
-- point « position », tourné vers « regard » (Henry), jusqu'à directeur.parler(false). Elle passe devant sa journée et
-- devant « suivre ». Rend vrai, ou faux et la raison.
function directeur.parler(oui, position, regard)
  local d = donnees()
  if not d.installe then
    return refuser("pas_de_directeur")
  end
  if oui == false then
    d.parler = nil
  else
    local function point_valide(p)
      return type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" and type(p.z) == "number"
    end
    if not point_valide(position) or not point_valide(regard) then
      return refuser("position_invalide")
    end
    d.parler = { position = { x = position.x, y = position.y, z = position.z },
                 regard = { x = regard.x, y = regard.y, z = regard.z } }
  end
  d.derniere_activite = nil
  enregistrer()
  directeur.battre()
  return true
end

function directeur.activite(heure)
  local d = donnees()
  if d.parler then
    return { activite = "garde", lieu = "parler", position = d.parler.position, regard = d.parler.regard,
             signature = string.format("%.1f,%.1f", d.parler.position.x, d.parler.position.y) }
  end
  if d.suivre then
    local suivi = d.formation and { mode = "mener", formation = d.formation } or nil
    -- V73 f 2 e : à cheval, dans son rôle (mener sa formation, ou suivre) ; sans cheval encore, à pied.
    local a_cheval = Scriptorium.hommes and Scriptorium.hommes.suivi_du_directeur(d.formation and "mener" or nil, d.formation)
    return { activite = "suivre", lieu = "henry", chef = "henry", position = jeu().position_du_joueur(),
             suivi = a_cheval or suivi }
  end
  local h = heure - math.floor(heure / 24) * 24
  for _, t in ipairs(directeur.journee) do
    if (t.de < t.a and h >= t.de and h < t.a) or (t.de > t.a and (h >= t.de or h < t.a)) then
      -- Vu sur une copie de la partie de JoVenGer le 19/10 : sur un camp adopté, les places de notre plan sont relatives
      -- à l'ancre (sa cabane) : le Directeur allait dans la cabane, et des hommes s'y collaient. Là, il prend la place
      -- que Scriptorium déclare à la place de celle du plan (camp.declarer_les_places, « remplace ») ; sinon il reste à
      -- sa place d'installation.
      if camp().est_adopte and camp().est_adopte() then
        local remplacant = camp().remplacant_de and camp().remplacant_de(t.lieu)
        if remplacant then
          return { activite = t.activite, lieu = remplacant, position = camp().position_de(remplacant) }
        end
        local p = d.lieu_de_naissance
        return { activite = t.activite, lieu = "place_du_directeur",
                 position = p and { x = p.x, y = p.y, z = p.z } or nil }
      end
      return { activite = t.activite, lieu = t.lieu, position = camp().position_de(t.lieu) }
    end
  end
  return nil
end
Scriptorium.remplacable(directeur, "activite", function(rendu) return type(rendu) == "table" end)

function directeur.battre()
  local d = donnees()
  local rapport = { ordres = 0 }
  if not d.installe or not d.personnage then
    return rapport
  end
  habiller(d)
  -- V73 f 2 e : son cheval passager préparé s'il est en sortie à cheval ; son ordre redonné quand son activité ou sa
  -- monture change (le rôle et le nom du cheval dans sa signature).
  if Scriptorium.hommes then
    Scriptorium.hommes.preparer_la_monture_du_directeur(jeu().heure_du_jeu())
  end
  local a = Scriptorium.avis(directeur, "activite", jeu().heure_du_jeu())
  local resume = a and (a.activite .. (a.suivi and ("/" .. tostring(a.suivi.mode) .. "/" .. tostring(a.suivi.cheval)) or "")
                        .. (a.signature and ("#" .. a.signature) or ""))
  if a and d.derniere_activite ~= resume then
    -- Fiche 15, V73 a : son lit se prend par l'objet du jeu ; le coffre et le feu s'abordent à l'écart, jamais dessus
    -- (avant, il était posé dans le feu à la veillée).
    local sorte = camp().sorte_de(a.lieu)
    local objet = sorte and camp().sortes_places[sorte] and camp().objet_du_jeu_de(a.lieu) or nil
    local position = objet and a.position or camp().abord_de(a.lieu) or a.position
    jeu().ordonner(d.personnage, a.activite, position, a.lieu, objet, objet and sorte or nil, a.regard, nil, a.chef, a.suivi)
    if Scriptorium.hommes then
      Scriptorium.hommes.ordre_donne_en_saut("directeur")
    end
    d.derniere_activite = resume
    rapport.ordres = 1
  elseif a and a.activite == "suivre" and Scriptorium.hommes and Scriptorium.hommes.montures.directeur
      and ((a.suivi and a.suivi.mode == "cheval") or Scriptorium.hommes.montures.directeur.saut)
      and Scriptorium.hommes.saut_du_cavalier("directeur", d.personnage, a.chef, "Directeur") then
    -- V73 f 3 b : le grand saut : il descend (ou, revenu, remonte) ; son ordre redonné.
    d.derniere_activite = nil
  elseif a and a.activite == "suivre" and not (a.suivi and a.suivi.mode == "cheval") and Scriptorium.hommes
      and not (Scriptorium.hommes.montures.directeur and Scriptorium.hommes.montures.directeur.saut
               and Scriptorium.hommes.montures.directeur.cheval)
      and Scriptorium.avis(Scriptorium.hommes, "rattraper", d.personnage, a.chef, "Directeur") then
    -- Le rattrapage (V73 f 1) : posé derrière Henry, son ordre redonné au battement suivant.
    d.derniere_activite = nil
    rapport.rattrapages = 1
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
    hommes = effectif.nombre,
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
      if hommes().effectif().nombre == 0 then return false, "personne" end
      return true
    end,
    agir = function() return true, hommes().payer_la_solde() end },
  { action = "engager", cle = "ui_scriptorium_gestion_engager", parametres = { "role", "semaines" },
    disponible = function()
      if #Scriptorium.avis(camp(), "places_libres", "lit", "hommes") == 0 then return false, "pas_de_lit" end
      return true, { roles = roles_disponibles() }
    end,
    agir = function(p)
      local id, raison = hommes().embaucher({ role = p.role, semaines = p.semaines, prime = p.prime, solde = p.solde })
      if not id then return false, raison end
      return true, id
    end },
  { action = "renvoyer", cle = "ui_scriptorium_gestion_renvoyer", parametres = { "id" },
    disponible = function()
      if hommes().effectif().nombre == 0 then return false, "personne" end
      return true, { hommes = hommes().liste() }
    end,
    agir = function(p) return hommes().renvoyer(p.id) end },
  { action = "nommer_capitaine", cle = "ui_scriptorium_gestion_capitaine", parametres = { "id" },
    disponible = function()
      if hommes().effectif().nombre == 0 then return false, "personne" end
      return true, { hommes = hommes().liste() }
    end,
    agir = function(p) return hommes().nommer_capitaine(p.id) end },
  { action = "renouveler", cle = "ui_scriptorium_gestion_renouveler", parametres = { "id", "semaines" },
    disponible = function()
      if hommes().effectif().nombre == 0 then return false, "personne" end
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

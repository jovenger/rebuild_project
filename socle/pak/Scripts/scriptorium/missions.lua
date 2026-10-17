-- Les missions : les lieux, les camps de bandits (tranche 1), puis les missions et leur colonne.
-- Fiche de comportement : docs/socle/fiches/17_missions.md

local Scriptorium = Scriptorium

local missions = {}
Scriptorium.missions = missions

-- La sorte des bandits d'un camp, et la durée (heures de jeu) où un camp vaincu reste debout avant d'être levé.
missions.reglages = {
  sorte = "brigands",
  camp_vaincu_reste_h = 24,
}

-- Les tailles d'un camp de bandits : ses hommes et la somme de son coffre (réglables, section « niveaux_des_camps »).
missions.niveaux = {
  { nom = "petit", effectif = 4, coffre = 120 },
  { nom = "moyen", effectif = 7, coffre = 250 },
  { nom = "grand", effectif = 10, coffre = 400 },
}

-- Le plan d'un camp de bandits, par rapport au lieu (x à droite, y devant, cap en degrés), avec les meubles du camp
-- déjà vus en jeu (fiche 03) ; réglable (section « plan_des_camps »).
missions.plan = {
  { nom = "feu", sorte = "feu", x = 0, y = 0, cap = 0 },
  { nom = "tente_1", sorte = "tente", x = -5, y = 3, cap = 135 },
  { nom = "tente_2", sorte = "tente", x = 5, y = 3, cap = 225 },
  { nom = "coffre", sorte = "coffre", x = 0, y = 5.5, cap = 180 },
}

-- Les lieux nommés, par carte : fournis par Scriptorium (« ajouter_un_lieu »), en mémoire ; un camp dressé garde une
-- copie de son lieu au registre.
missions.lieux = missions.lieux or {}

local function jeu() return Scriptorium.jeu end
local function camp() return Scriptorium.camp end
local function bataille() return Scriptorium.bataille end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return { prochain = 1, camps = {}, ordre = {} }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("missions") then
    registre.declarer_case("missions", 1, donnees_neuves)
  end
  return registre.lire("missions")
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

local function refuser(raison, detail)
  jeu().journal("Missions : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

local function niveau_nomme(nom)
  for _, n in ipairs(missions.niveaux) do
    if n.nom == nom then
      return n
    end
  end
  return nil
end

-- ---------------------------------------------------------------- lieux

-- Un lieu : un nom, une carte (le nom de niveau du jeu), une position { x, y, z } et un cap. Rend vrai, ou faux et la
-- raison. Un lieu du même nom est remplacé.
function missions.ajouter_un_lieu(nom, carte, position, cap)
  if type(nom) ~= "string" or nom == "" then
    return refuser("nom_invalide", tostring(nom))
  end
  if type(carte) ~= "string" or carte == "" then
    return refuser("carte_invalide", tostring(carte))
  end
  if type(position) ~= "table" or type(position.x) ~= "number" or type(position.y) ~= "number"
      or type(position.z) ~= "number" then
    return refuser("position_invalide", nom)
  end
  missions.lieux[nom] = { nom = nom, carte = carte, x = position.x, y = position.y, z = position.z, cap = tonumber(cap) or 0 }
  jeu().journal(string.format("Missions : lieu « %s » sur %s (%.0f, %.0f)", nom, carte, position.x, position.y))
  return true
end

-- Les lieux d'une carte (toutes si « carte » est nil), triés par nom : des copies.
function missions.lieux_de(carte)
  local liste = {}
  for _, l in pairs(missions.lieux) do
    if carte == nil or l.carte == carte then
      table.insert(liste, { nom = l.nom, carte = l.carte, x = l.x, y = l.y, z = l.z, cap = l.cap })
    end
  end
  table.sort(liste, function(a, b) return a.nom < b.nom end)
  return liste
end

-- Le lieu est-il sur la carte où se tient Henry ? (Une carte illisible ne ferme rien.)
function missions.lieu_sur_ma_carte(nom)
  local l = missions.lieux[nom]
  if not l then
    return false
  end
  local ici = jeu().carte_courante and (jeu().carte_courante()) or nil
  return ici == nil or ici == l.carte
end

-- ---------------------------------------------------------------- accroches (Scriptorium les remplace)

-- La taille d'un camp de bandits à ce lieu et à ce niveau : { sorte, effectif, coffre }, ou nil.
function missions.taille_du_camp(lieu, niveau)
  local n = niveau_nomme(niveau)
  if not n then
    return nil
  end
  return { sorte = missions.reglages.sorte, effectif = n.effectif, coffre = n.coffre }
end

-- Un camp de bandits vient d'être vaincu (une fois). « c » : la copie du camp (« missions.camp »).
function missions.camp_vaincu(c)
  jeu().journal("Missions : camp « " .. c.id .. " » vaincu (" .. c.lieu .. ", " .. tostring(c.issue) .. ")")
  annoncer("ui_scriptorium_missions_camp_vaincu", { complement = c.lieu })
end

-- ---------------------------------------------------------------- camps de bandits

local function copie_du_camp(c)
  return { id = c.id, lieu = c.lieu.nom, carte = c.lieu.carte, niveau = c.niveau, bande = c.bande, etat = c.etat,
           issue = c.issue, coffre = c.coffre, effectif = c.effectif, meubles = c.meubles_poses == true }
end

-- Le lieu est-il pris par un camp qui n'est pas levé ?
local function lieu_pris(d, nom)
  for _, id in ipairs(d.ordre) do
    local c = d.camps[id]
    if c.etat ~= "leve" and c.lieu.nom == nom then
      return c.id
    end
  end
  return nil
end

local function retirer_les_meubles(c)
  for _, identifiant in pairs(c.meubles or {}) do
    jeu().retirer_objet(identifiant)
  end
  c.meubles = {}
  c.meubles_poses = false
end

-- Les meubles d'un camp naissent comme ses hommes : sur la carte du lieu, hors du regard d'Henry (fiche 17).
local function poser_les_meubles(c)
  local l = c.lieu
  local ici = jeu().carte_courante and (jeu().carte_courante()) or nil
  if ici ~= nil and ici ~= l.carte then
    return false
  end
  local henry = jeu().position_du_joueur()
  if henry and math.sqrt((henry.x - l.x) ^ 2 + (henry.y - l.y) ^ 2) <= bataille().reglages.poste_vue_m
      and jeu().henry_voit(l, Scriptorium.hommes.reglages.secours_vue_cos) == true then
    return false
  end
  c.meubles = c.meubles or {}
  local manquants = 0
  for _, e in ipairs(missions.plan) do
    local modele = camp().modeles[e.sorte]
    if modele and not (c.meubles[e.nom] and jeu().objet_existe(c.meubles[e.nom])) then
      local position, cap = camp().dans_le_monde(l, e.x, e.y, e.cap)
      local identifiant = jeu().poser_objet(e.sorte, modele.chemin, position, (cap + (modele.decalage or 0)) % 360,
                                            "bandits_" .. c.id .. "_" .. e.nom, modele.classe)
      if identifiant then
        c.meubles[e.nom] = identifiant
        if modele.allume then
          jeu().allumer(identifiant)
        end
      else
        manquants = manquants + 1
      end
    end
  end
  c.meubles_poses = true
  jeu().journal("Missions : camp « " .. c.id .. " » meublé" .. (manquants > 0 and (", " .. manquants .. " manquant(s)") or ""))
  return true
end

-- Dresse un camp de bandits à un lieu connu, à un niveau. Rend son nom, ou faux et la raison.
function missions.dresser_un_camp(nom_du_lieu, niveau)
  local d = donnees()
  local l = missions.lieux[nom_du_lieu]
  if not l then
    return refuser("lieu_inconnu", tostring(nom_du_lieu))
  end
  local pris = lieu_pris(d, nom_du_lieu)
  if pris then
    return refuser("lieu_pris", pris)
  end
  local taille = missions.taille_du_camp(nom_du_lieu, niveau)
  if type(taille) ~= "table" then
    return refuser("niveau_inconnu", tostring(niveau))
  end
  local bande, raison = bataille().poster_une_bande({ sorte = taille.sorte, effectif = taille.effectif,
    position = { x = l.x, y = l.y, z = l.z }, cap = l.cap, carte = l.carte, butin = taille.coffre })
  if not bande then
    return refuser("bande_refusee", raison)
  end
  local id = "camp_de_bandits_" .. d.prochain
  d.prochain = d.prochain + 1
  d.camps[id] = { id = id, lieu = { nom = l.nom, carte = l.carte, x = l.x, y = l.y, z = l.z, cap = l.cap },
                  niveau = niveau, bande = bande, etat = "dresse", coffre = taille.coffre, effectif = taille.effectif,
                  meubles = {}, meubles_poses = false }
  table.insert(d.ordre, id)
  poser_les_meubles(d.camps[id])
  enregistrer()
  jeu().journal("Missions : camp « " .. id .. " » dressé à « " .. l.nom .. " » (" .. tostring(niveau) .. ", "
                .. taille.effectif .. " " .. taille.sorte .. ", coffre " .. taille.coffre .. ")")
  return id
end

function missions.camp(id)
  local c = donnees().camps[id]
  return c and copie_du_camp(c) or nil
end

-- Les camps qui ne sont pas levés, dans l'ordre où ils ont été dressés.
function missions.camps()
  local d = donnees()
  local liste = {}
  for _, id in ipairs(d.ordre) do
    if d.camps[id].etat ~= "leve" then
      table.insert(liste, copie_du_camp(d.camps[id]))
    end
  end
  return liste
end

-- Lève un camp : ses meubles retirés, sa bande (si elle tient encore) renvoyée. Rend vrai, ou faux et la raison.
function missions.lever_un_camp(id)
  local d = donnees()
  local c = d.camps[id]
  if not c or c.etat == "leve" then
    return refuser("camp_inconnu", tostring(id))
  end
  retirer_les_meubles(c)
  local b = bataille().bande(c.bande)
  if b and b.etat ~= "finie" and #b.personnages > 0 then
    jeu().renvoyer_ennemis(b.personnages)
  end
  if b and b.etat ~= "finie" then
    bataille().oublier_la_bande(c.bande)
  end
  c.etat = "leve"
  enregistrer()
  jeu().journal("Missions : camp « " .. id .. " » levé")
  return true
end

-- ---------------------------------------------------------------- battement et chargement

function missions.battre()
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local rapport = { meubles = 0, vaincus = 0, leves = 0 }
  local change = false
  for _, id in ipairs(d.ordre) do
    local c = d.camps[id]
    if (c.etat == "dresse" or c.etat == "fini") and not c.meubles_poses and poser_les_meubles(c) then
      rapport.meubles = rapport.meubles + 1
      change = true
    end
    if c.etat == "dresse" then
      local b = bataille().bande(c.bande)
      if b and b.etat == "finie" then
        c.etat = "fini"
        c.issue = b.issue
        c.fini_a = heure
        change = true
        if b.issue == "victoire" or b.issue == "victoire_couteuse" then
          rapport.vaincus = rapport.vaincus + 1
          local ok, erreur = pcall(missions.camp_vaincu, copie_du_camp(c))
          if not ok then
            jeu().journal("Missions : accroche « camp vaincu » en erreur : " .. tostring(erreur))
          end
        end
      end
    elseif c.etat == "fini" and heure >= c.fini_a + missions.reglages.camp_vaincu_reste_h then
      retirer_les_meubles(c)
      c.etat = "leve"
      rapport.leves = rapport.leves + 1
      change = true
      jeu().journal("Missions : camp « " .. id .. " » levé (" .. missions.reglages.camp_vaincu_reste_h .. " h après sa fin)")
    end
  end
  if change then
    enregistrer()
  end
  return rapport
end

-- À l'entrée en partie : les meubles des camps debout sont retirés et refaits par le battement (comme le camp, fiche 03).
function missions.relancer()
  local d = donnees()
  local n = 0
  for _, id in ipairs(d.ordre) do
    local c = d.camps[id]
    if c.etat == "dresse" or c.etat == "fini" then
      retirer_les_meubles(c)
      n = n + 1
    end
  end
  if n > 0 then
    enregistrer()
    jeu().journal("Missions : " .. n .. " camp(s) de bandits à remeubler")
  end
  return n
end

Scriptorium.declarer_morceau("missions", function()
  -- Les camps de bandits avancent par le battement du socle.
end)

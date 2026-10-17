-- Les missions : les lieux, les camps de bandits (tranche 1), puis les missions et leur colonne.
-- Fiche de comportement : docs/socle/fiches/17_missions.md

local Scriptorium = Scriptorium

local missions = {}
Scriptorium.missions = missions

-- La sorte des bandits d'un camp, et la durée (heures de jeu) où un camp vaincu reste debout avant d'être levé.
missions.reglages = {
  sorte = "brigands",
  camp_vaincu_reste_h = 24,
  -- Tranche 2, la colonne (fiche 17) : au loin, une colonne à cheval parcourt « vitesse_m_par_h » mètres par heure du jeu ;
  -- chacun de ses hommes à plus de « henry_loin_m » d'Henry et hors de son regard : elle passe « dehors » ; au retour,
  -- elle renaît à « retour_naissance_m » du camp sur le chemin du lieu ; rentrée quand un de ses hommes est à moins de
  -- « arrivee_m » du centre du camp. Le niveau selon la force : le plus grand dont la force, multipliée par
  -- « marge_de_force », ne dépasse pas celle de la colonne.
  vitesse_m_par_h = 12000,
  henry_loin_m = 300,
  -- (relecture) « sous les yeux d'Henry » est borné, comme partout dans le socle : dans son regard et à moins de
  -- « dehors_vue_m » ; au-delà, même regardée, la colonne peut passer dehors (le jeu ne la fait plus vivre).
  dehors_vue_m = 500,
  -- (relecture) La colonne ne rentre pas au feu, au milieu des meubles : elle vise un point au bord du camp, à
  -- « retour_m » du centre du côté du lieu, et se dit rentrée à moins de « arrivee_m » de ce point.
  retour_m = 15,
  retour_naissance_m = 150,
  arrivee_m = 6,
  marge_de_force = 1.5,
  -- Le registre ne garde que les « gardes » derniers camps levés et dernières missions finies.
  gardes = 20,
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
  local d = registre.lire("missions")
  -- Tranche 2 : les missions, ajoutées à la case (un registre d'avant n'en a pas).
  d.missions = d.missions or {}
  d.ordre_des_missions = d.ordre_des_missions or {}
  d.prochaine_mission = d.prochaine_mission or 1
  return d
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

-- Une mission peut-elle partir ? (Scriptorium l'enveloppe : le jour de repos, l'état d'urgence.) Rend vrai, ou faux et
-- la raison.
function missions.peut_partir(ordre)
  return true
end

-- Le niveau d'un camp de bandits selon la force d'une colonne : le plus grand dont la force, multipliée par
-- « marge_de_force », ne dépasse pas la sienne ; sinon le plus petit.
function missions.niveau_pour(force, lieu)
  local choisi = missions.niveaux[1] and missions.niveaux[1].nom
  for _, n in ipairs(missions.niveaux) do
    local t = missions.taille_du_camp(lieu, n.nom)
    local sorte = t and bataille().sortes[t.sorte]
    if sorte and t.effectif * sorte.poids * missions.reglages.marge_de_force <= force then
      choisi = n.nom
    end
  end
  return choisi
end

-- Le rapport d'une mission rentrée (ou perdue) : une fois ; par défaut, une ligne au journal et l'annonce.
function missions.rapport_de_mission(r)
  jeu().journal(string.format("Missions : rapport de « %s » (%s, %s) : %s, %d mort(s), %d blessé(s), butin %d", r.id,
    r.lieu, tostring(r.niveau), tostring(r.issue), r.morts, r.blesses, r.butin))
  annoncer("ui_scriptorium_missions_rapport", { complement = r.lieu .. " : " .. tostring(r.issue) })
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

-- ---------------------------------------------------------------- missions (tranche 2)

local function centre_du_camp()
  local c = camp().point(0, 0, 0)
  return c and { x = c.x, y = c.y, z = c.z } or nil
end

-- Le résumé d'une bande finie, d'après les résultats de la bataille (morts, blessés, butin).
local function resultat_de_la_bande(bande)
  local trouve = nil
  for _, r in ipairs(bataille().resultats()) do
    if r.bande == bande then
      trouve = { morts = r.morts, blesses = r.blesses, butin = r.butin, part_coffre = r.part_coffre }
    end
  end
  return trouve
end

-- Les hommes de la mission encore au registre (les morts en sont partis).
local function vivants_de(m)
  local liste = {}
  for _, id in ipairs(m.hommes) do
    if Scriptorium.hommes.fiche(id) then
      table.insert(liste, id)
    end
  end
  return liste
end

-- La colonne va à un point, à cheval, son chef en tête.
local function envoyer(m, vers)
  for _, id in ipairs(vivants_de(m)) do
    Scriptorium.hommes.tenir(id, "mission", { activite = "suivre", lieu = m.id, vers = vers, a_cheval = true,
      formation = "followNPC", tete = m.chef, fin = "liberation" })
  end
end

-- Chacun est-il à plus de « henry_loin_m » d'Henry, et pas sous ses yeux (dans son regard à moins de « dehors_vue_m ») ?
-- Henry illisible : non (on ne retire personne du monde sur une lecture manquée). Un homme sans position lisible : loin.
local function hors_de_la_vue(vivants)
  local henry = jeu().position_du_joueur()
  if not henry then
    return false
  end
  for _, id in ipairs(vivants) do
    local f = Scriptorium.hommes.fiche(id)
    local ici = f and f.personnage and jeu().position_du_personnage(f.personnage)
    local ecart = ici and math.sqrt((ici.x - henry.x) ^ 2 + (ici.y - henry.y) ^ 2)
    if ecart and (ecart <= missions.reglages.henry_loin_m or (ecart <= missions.reglages.dehors_vue_m
                  and jeu().henry_voit(ici, Scriptorium.hommes.reglages.secours_vue_cos) == true)) then
      return false
    end
  end
  return true
end

-- Le point d'arrivée au camp : au bord, à « retour_m » du centre du côté du lieu.
local function point_de_retour(m)
  local centre = centre_du_camp()
  if not centre then
    return nil
  end
  local la = m.lieu
  local loin = math.sqrt((la.x - centre.x) ^ 2 + (la.y - centre.y) ^ 2)
  local k = (loin > 0) and math.min(1, missions.reglages.retour_m / loin) or 0
  return { x = centre.x + (la.x - centre.x) * k, y = centre.y + (la.y - centre.y) * k, z = centre.z }
end

local function copie_de_la_mission(m)
  return { id = m.id, lieu = m.lieu.nom, carte = m.lieu.carte, niveau = m.niveau, camp = m.camp, chef = m.chef,
           etat = m.etat, issue = m.issue, depart = m.depart, hommes = vivants_de(m) }
end

local function finir_la_mission(d, m, heure)
  for _, id in ipairs(vivants_de(m)) do
    Scriptorium.hommes.lacher(id, "mission")
  end
  m.etat = "finie"
  m.fin = heure
  local resultat = m.resultat or {}
  local r = { id = m.id, lieu = m.lieu.nom, niveau = m.niveau, issue = m.issue or "perdue", depart = m.depart, fin = heure,
              hommes = #m.hommes, morts = resultat.morts or (#m.hommes - #vivants_de(m)), blesses = resultat.blesses or 0,
              butin = resultat.butin or 0, part_coffre = resultat.part_coffre or 0 }
  m.rapport = r
  local ok, erreur = pcall(missions.rapport_de_mission, r)
  if not ok then
    jeu().journal("Missions : accroche « rapport de mission » en erreur : " .. tostring(erreur))
  end
end

-- Prendre une mission : { lieu, hommes = { ids }, chef (un des hommes, en tête), niveau (sinon selon la force) }. Le camp
-- de bandits est dressé au lieu, la colonne part à cheval. Rend son nom, ou faux et la raison.
function missions.prendre_une_mission(ordre)
  ordre = ordre or {}
  local d = donnees()
  if not camp().est_fonde() then
    return refuser("camp_absent")
  end
  local permis, pourquoi = missions.peut_partir(ordre)
  if not permis then
    return refuser("ne_peut_partir", tostring(pourquoi))
  end
  local l = missions.lieux[ordre.lieu]
  if not l then
    return refuser("lieu_inconnu", tostring(ordre.lieu))
  end
  if type(ordre.hommes) ~= "table" or #ordre.hommes == 0 then
    return refuser("hommes_absents")
  end
  local dans = {}
  for _, id in ipairs(ordre.hommes) do
    local f = Scriptorium.hommes.fiche(id)
    if not f or f.dehors or f.blessure > 0 or dans[id] or not Scriptorium.hommes.libre_pour(id, "mission") then
      return refuser("homme_indisponible", tostring(id))
    end
    dans[id] = true
  end
  if ordre.chef ~= nil and not dans[ordre.chef] then
    return refuser("chef_hors_colonne", tostring(ordre.chef))
  end
  local niveau = ordre.niveau or missions.niveau_pour((bataille().force_de(ordre.hommes)), ordre.lieu)
  local camp_id, raison = missions.dresser_un_camp(ordre.lieu, niveau)
  if not camp_id then
    return refuser("camp_refuse", raison)
  end
  local heure = jeu().heure_du_jeu()
  local id = "mission_" .. d.prochaine_mission
  d.prochaine_mission = d.prochaine_mission + 1
  local hommes = {}
  for i, h in ipairs(ordre.hommes) do hommes[i] = h end
  local m = { id = id, lieu = { nom = l.nom, carte = l.carte, x = l.x, y = l.y, z = l.z }, camp = camp_id, niveau = niveau,
              hommes = hommes, chef = ordre.chef or hommes[1], etat = "aller", depart = heure }
  d.missions[id] = m
  table.insert(d.ordre_des_missions, id)
  envoyer(m, { x = l.x, y = l.y, z = l.z })
  enregistrer()
  jeu().journal("Missions : « " .. id .. " » partie vers « " .. l.nom .. " » (" .. tostring(niveau) .. ", " .. #hommes
                .. " homme(s), chef « " .. m.chef .. " »)")
  annoncer("ui_scriptorium_missions_partie", { complement = l.nom })
  return id
end

function missions.mission(id)
  local m = donnees().missions[id]
  return m and copie_de_la_mission(m) or nil
end

-- Les missions qui ne sont pas finies, dans l'ordre où elles sont parties.
function missions.en_cours()
  local d = donnees()
  local liste = {}
  for _, id in ipairs(d.ordre_des_missions) do
    if d.missions[id].etat ~= "finie" then
      table.insert(liste, copie_de_la_mission(d.missions[id]))
    end
  end
  return liste
end

function missions.rapport(id)
  local m = donnees().missions[id]
  return m and m.rapport or nil
end

-- Une mission avance d'un battement. Rend vrai si elle a changé.
local function avancer(d, m, heure)
  local vivants = vivants_de(m)
  if #vivants == 0 then
    m.issue = m.issue or "perdue"
    finir_la_mission(d, m, heure)
    return true
  end
  local c = d.camps[m.camp]
  local b = c and bataille().bande(c.bande)
  if m.etat == "aller" then
    if b and b.etat == "finie" then
      -- Tranché sur place (Henry présent) : la colonne rentre à cheval ; sans camp (levé entre-temps), finie là.
      m.issue = b.issue
      m.resultat = resultat_de_la_bande(c.bande)
      local retour = point_de_retour(m)
      if not retour then
        finir_la_mission(d, m, heure)
        return true
      end
      m.etat = "retour"
      envoyer(m, retour)
      jeu().journal("Missions : « " .. m.id .. " » : " .. tostring(b.issue) .. " au lieu, retour au camp")
      return true
    end
    if hors_de_la_vue(vivants) then
      for _, id in ipairs(vivants) do
        Scriptorium.hommes.mettre_dehors(id, m.id)
      end
      local la = m.lieu
      local depuis = centre_du_camp() or la
      m.etat = "dehors_aller"
      m.arrivee = heure + math.sqrt((la.x - depuis.x) ^ 2 + (la.y - depuis.y) ^ 2) / missions.reglages.vitesse_m_par_h
      jeu().journal(string.format("Missions : « %s » dehors, au lieu à %.2f h", m.id, m.arrivee))
      return true
    end
  elseif m.etat == "dehors_aller" and heure >= m.arrivee then
    if b and b.etat ~= "finie" then
      m.resultat = bataille().trancher_la_bande_postee(c.bande, vivants)
    end
    local fini = c and bataille().bande(c.bande)
    m.issue = fini and fini.issue or "perdue"
    if m.resultat then
      m.resultat = { morts = #m.resultat.morts, blesses = #m.resultat.blesses, butin = m.resultat.butin,
                     part_coffre = m.resultat.part_coffre }
    end
    local depuis, la = centre_du_camp() or m.lieu, m.lieu
    m.etat = "dehors_retour"
    m.retour = heure + math.sqrt((la.x - depuis.x) ^ 2 + (la.y - depuis.y) ^ 2) / missions.reglages.vitesse_m_par_h
    jeu().journal(string.format("Missions : « %s » : %s au loin, de retour à %.2f h", m.id, tostring(m.issue), m.retour))
    return true
  elseif m.etat == "dehors_retour" and heure >= m.retour then
    local centre = centre_du_camp()
    if not centre then
      -- Le camp levé pendant la mission : ils rentrent au registre, près d'Henry au prochain redressement.
      for _, id in ipairs(vivants) do
        Scriptorium.hommes.faire_rentrer(id, nil)
      end
      finir_la_mission(d, m, heure)
      return true
    end
    local la = m.lieu
    local loin = math.sqrt((la.x - centre.x) ^ 2 + (la.y - centre.y) ^ 2)
    local k = (loin > 0) and math.min(1, missions.reglages.retour_naissance_m / loin) or 0
    local point = { x = centre.x + (la.x - centre.x) * k, y = centre.y + (la.y - centre.y) * k, z = centre.z }
    local henry = jeu().position_du_joueur()
    if henry and math.sqrt((point.x - henry.x) ^ 2 + (point.y - henry.y) ^ 2) <= missions.reglages.henry_loin_m
        and jeu().henry_voit(point, Scriptorium.hommes.reglages.secours_vue_cos) == true then
      return false
    end
    for i, id in ipairs(vivants) do
      Scriptorium.hommes.faire_rentrer(id, { x = point.x + (i - 1) * 2, y = point.y, z = point.z })
    end
    m.etat = "retour"
    envoyer(m, point_de_retour(m))
    jeu().journal("Missions : « " .. m.id .. " » renaît sur le chemin du camp")
    return true
  elseif m.etat == "retour" then
    local retour = point_de_retour(m)
    for _, id in ipairs(vivants) do
      local f = Scriptorium.hommes.fiche(id)
      local ici = f.personnage and jeu().position_du_personnage(f.personnage)
      if retour and ici and math.sqrt((ici.x - retour.x) ^ 2 + (ici.y - retour.y) ^ 2) <= missions.reglages.arrivee_m then
        finir_la_mission(d, m, heure)
        return true
      end
    end
  end
  return false
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
  -- Les plus anciens camps levés et missions finies quittent le registre au-delà de « gardes ».
  for _, liste in ipairs({ { ordre = d.ordre, table = d.camps, fini = "leve" },
                           { ordre = d.ordre_des_missions, table = d.missions, fini = "finie" } }) do
    local finis = 0
    for _, id in ipairs(liste.ordre) do
      if liste.table[id].etat == liste.fini then finis = finis + 1 end
    end
    local k = 1
    while finis > missions.reglages.gardes and k <= #liste.ordre do
      local id = liste.ordre[k]
      if liste.table[id].etat == liste.fini then
        liste.table[id] = nil
        table.remove(liste.ordre, k)
        finis = finis - 1
        change = true
      else
        k = k + 1
      end
    end
  end
  for _, id in ipairs(d.ordre_des_missions) do
    local m = d.missions[id]
    if m.etat ~= "finie" and avancer(d, m, heure) then
      rapport.missions = (rapport.missions or 0) + 1
      change = true
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

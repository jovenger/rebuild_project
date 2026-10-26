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
  -- Vu en jeu le 17/10 : une heure du jeu dure environ 4,75 minutes réelles ; une colonne au trot (3 m/s) fait donc
  -- quelque 900 m par heure du jeu, un convoi à pied (1,3 m/s) quelque 400 m.
  vitesse_m_par_h = 900,
  henry_loin_m = 300,
  -- (relecture) « sous les yeux d'Henry » est borné, comme partout dans le socle : dans son regard et à moins de
  -- « dehors_vue_m » ; au-delà, même regardée, la colonne peut passer dehors (le jeu ne la fait plus vivre).
  dehors_vue_m = 500,
  -- (relecture) La colonne ne rentre pas au feu, au milieu des meubles : elle vise un point au bord du camp, à
  -- « retour_m » du centre du côté du lieu, et se dit rentrée à moins de « arrivee_m » de ce point.
  retour_m = 15,
  retour_naissance_m = 150,
  -- Vu en jeu le 17/10 : la tête s'arrête à 6,4–6,7 m de son point (l'arrêt de l'allure, avec son écart).
  arrivee_m = 10,
  marge_de_force = 1.5,
  -- Le registre ne garde que les « gardes » derniers camps levés et dernières missions finies.
  gardes = 20,
  -- Tranche 4, les convois : à pied, « convoi_m_par_h » mètres par heure du jeu (plus lent qu'une colonne à cheval).
  convoi_m_par_h = 400,
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

-- Les routes des convois, par carte : fournies par Scriptorium (« ajouter_une_route »), en mémoire ; un convoi lancé
-- garde une copie de sa route au registre.
missions.routes = missions.routes or {}

-- Les lieux nommés, par carte : fournis par Scriptorium (« ajouter_un_lieu »), en mémoire ; un camp dressé garde une
-- copie de son lieu au registre.
missions.lieux = missions.lieux or {}

-- Les lieux du socle (demande du pair, 18/10 : sans eux, les missions du Directeur n'auraient aucun lieu) : neuf par
-- carte, pris dans le jeu lui-même, là où il a déjà des brigands (centre des entités des calques nommés en commentaire,
-- Data/Levels/<carte>/level.pak, lecture seule) ; jamais les lieux de l'ancien mod. Le niveau : la plus grande taille de
-- camp qu'on y dresse (selon le nombre de brigands que le jeu y met). Liste à nom, réglable (section « lieux_du_socle ») ;
-- lue en direct ; un lieu du même nom ajouté par Scriptorium (« ajouter_un_lieu ») passe devant.
missions.lieux_du_socle = {
  { nom = "colline_de_vysoka", carte = "kutnohorsko", x = 1066, y = 2443, z = 193, cap = 0, niveau = "moyen" },   -- kkop_kopecVysoka/series_banditCamp
  { nom = "bois_de_mezholezy", carte = "kutnohorsko", x = 214, y = 1466, z = 132, cap = 0, niveau = "petit" },   -- kmez_mezholezsko/banditCampWithHorse
  { nom = "moulin_de_vrchlice", carte = "kutnohorsko", x = 1574, y = 235, z = 57, cap = 0, niveau = "grand" },   -- kvrc_vrchlicko/danemarkMill/series_banditCamp
  { nom = "butte_des_archers", carte = "kutnohorsko", x = 2214, y = 1198, z = 105, cap = 0, niveau = "petit" },   -- nobodyWantsArchery_bandit
  { nom = "chemin_des_convois", carte = "kutnohorsko", x = 2620, y = 918, z = 91, cap = 0, niveau = "moyen" },   -- kradeneZasilky/posledniBereVse/bandits
  { nom = "lisiere_des_sept", carte = "kutnohorsko", x = 2907, y = 2925, z = 106, cap = 0, niveau = "moyen" },   -- sedmStatecnych/bandits
  { nom = "pierre_du_tonnerre", carte = "kutnohorsko", x = 1890, y = 3768, z = 86, cap = 0, niveau = "petit" },   -- hromovyKamen/bandits
  { nom = "fosse_de_l_ouest", carte = "kutnohorsko", x = 597, y = 1377, z = 118, cap = 0, niveau = "petit" },   -- zakopanyZitrek/bandit_1-2
  { nom = "fosse_de_l_est", carte = "kutnohorsko", x = 1296, y = 1340, z = 137, cap = 0, niveau = "petit" },   -- zakopanyZitrek/bandit_3-4
  { nom = "premier_repaire", carte = "trosecko", x = 2179, y = 1586, z = 27, cap = 0, niveau = "petit" },   -- taboryLapkuTrosecko/firstCamp
  { nom = "deuxieme_repaire", carte = "trosecko", x = 944, y = 2588, z = 78, cap = 0, niveau = "petit" },   -- taboryLapkuTrosecko/secondCamp
  { nom = "troisieme_repaire", carte = "trosecko", x = 898, y = 2000, z = 14, cap = 0, niveau = "petit" },   -- taboryLapkuTrosecko/thirdCamp
  { nom = "quatrieme_repaire", carte = "trosecko", x = 2798, y = 2605, z = 122, cap = 0, niveau = "moyen" },   -- taboryLapkuTrosecko/forthCamp, KasparCamp
  { nom = "chemin_de_l_embuscade", carte = "trosecko", x = 1207, y = 1940, z = 29, cap = 0, niveau = "grand" },   -- m01_prepadeni/bandits
  { nom = "bois_de_bohuta", carte = "trosecko", x = 2046, y = 1329, z = 14, cap = 0, niveau = "moyen" },   -- m10_bohutovaVlozka/bandit
  { nom = "camp_du_chevalier_brigand", carte = "trosecko", x = 2790, y = 2290, z = 116, cap = 0, niveau = "grand" },   -- zbranePanaSemina/tabor
  { nom = "clairiere_du_meurtrier", carte = "trosecko", x = 2695, y = 2768, z = 128, cap = 0, niveau = "moyen" },   -- tkop_kopanina/vrahCamp
  { nom = "bois_du_veneur", carte = "trosecko", x = 2611, y = 1376, z = 70, cap = 0, niveau = "moyen" },   -- cin_s0750t huntsman_bandits
}

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
  -- Tranche 4 : les convois.
  d.convois = d.convois or {}
  d.ordre_des_convois = d.ordre_des_convois or {}
  d.prochain_convoi = d.prochain_convoi or 1
  return d
end

local function enregistrer()
  Scriptorium.registre.enregistrer("missions")
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
-- Un lieu par son nom : celui de Scriptorium, sinon celui du socle ; nil sinon.
local function lieu_nomme(nom)
  if missions.lieux[nom] then
    return missions.lieux[nom]
  end
  for _, l in ipairs(missions.lieux_du_socle) do
    if l.nom == nom then
      return l
    end
  end
  return nil
end
missions.lieu_nomme = lieu_nomme

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
      table.insert(liste, { nom = l.nom, carte = l.carte, x = l.x, y = l.y, z = l.z, cap = l.cap, niveau = l.niveau })
    end
  end
  for _, l in ipairs(missions.lieux_du_socle) do
    if not missions.lieux[l.nom] and (carte == nil or l.carte == carte) then
      table.insert(liste, { nom = l.nom, carte = l.carte, x = l.x, y = l.y, z = l.z, cap = l.cap, niveau = l.niveau })
    end
  end
  table.sort(liste, function(a, b) return a.nom < b.nom end)
  return liste
end

-- Le lieu est-il sur la carte où se tient Henry ? (Une carte illisible ne ferme rien.)
function missions.lieu_sur_ma_carte(nom)
  local l = lieu_nomme(nom)
  if not l then
    return false
  end
  local ici = jeu().carte_courante and (jeu().carte_courante()) or nil
  return ici == nil or ici == l.carte
end

-- ---------------------------------------------------------------- routes et convois (tranche 4)

-- Une route : un nom, une carte, au moins deux points { x, y, z }. Rend vrai, ou faux et la raison.
function missions.ajouter_une_route(nom, carte, points)
  if type(nom) ~= "string" or nom == "" then
    return refuser("nom_invalide", tostring(nom))
  end
  if type(carte) ~= "string" or carte == "" then
    return refuser("carte_invalide", tostring(carte))
  end
  if type(points) ~= "table" or #points < 2 then
    return refuser("route_trop_courte", nom)
  end
  local copie = {}
  for i, p in ipairs(points) do
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number" then
      return refuser("point_invalide", nom .. " #" .. i)
    end
    copie[i] = { x = p.x, y = p.y, z = p.z }
  end
  missions.routes[nom] = { nom = nom, carte = carte, points = copie }
  jeu().journal("Missions : route « " .. nom .. " » sur " .. carte .. ", " .. #copie .. " points")
  return true
end

-- La longueur d'une route et le point à « parcouru » mètres de son départ (le dernier point au-delà) ; avec le point
-- suivant (vers lequel on regarde) et vrai si la route est finie.
local function point_de_la_route(route, parcouru)
  local reste = parcouru
  local points = route.points
  for numero = 1, #points - 1 do
    local depuis, jusqu_a = points[numero], points[numero + 1]
    local troncon = math.sqrt((jusqu_a.x - depuis.x) ^ 2 + (jusqu_a.y - depuis.y) ^ 2)
    if reste <= troncon and troncon > 0 then
      local k = reste / troncon
      return { x = depuis.x + (jusqu_a.x - depuis.x) * k, y = depuis.y + (jusqu_a.y - depuis.y) * k,
               z = depuis.z + (jusqu_a.z - depuis.z) * k }, jusqu_a, false
    end
    reste = reste - troncon
  end
  return points[#points], points[#points], true
end

local function copie_du_convoi(cv)
  return { id = cv.id, route = cv.route.nom, carte = cv.route.carte, niveau = cv.niveau, bande = cv.bande, etat = cv.etat,
           issue = cv.issue, parcouru = cv.parcouru, position = cv.position and { x = cv.position.x, y = cv.position.y,
           z = cv.position.z } or nil, convoi = true }
end

-- Où sera le convoi à l'heure « t » (il avance tant que sa bande n'est pas au combat).
local function position_du_convoi_a(cv, t)
  local parcouru = cv.parcouru + math.max(0, t - cv.dernier) * missions.reglages.convoi_m_par_h
  return point_de_la_route(cv.route, parcouru)
end



-- La taille d'un camp de bandits à ce lieu et à ce niveau : { sorte, effectif, coffre }, ou nil.
function missions.taille_du_camp(lieu, niveau)
  local n = niveau_nomme(niveau)
  if not n then
    return nil
  end
  return { sorte = missions.reglages.sorte, effectif = n.effectif, coffre = n.coffre }
end
Scriptorium.remplacable(missions, "taille_du_camp", function(rendu) return type(rendu) == "table" and type(rendu.sorte) == "string"
  and type(rendu.effectif) == "number" and rendu.effectif >= 0 and math.floor(rendu.effectif) == rendu.effectif
  and type(rendu.coffre) == "number" and rendu.coffre >= 0 and rendu.coffre < math.huge end)

-- Une mission peut-elle partir ? (Scriptorium l'enveloppe : le jour de repos, l'état d'urgence.) Rend vrai, ou faux et
-- la raison.
function missions.peut_partir(ordre)
  return true
end
Scriptorium.remplacable(missions, "peut_partir", function(rendu) return type(rendu) == "boolean" end)

-- Le niveau d'un camp de bandits selon la force d'une colonne : le plus grand dont la force, multipliée par
-- « marge_de_force », ne dépasse pas la sienne ; sinon le plus petit.
function missions.niveau_pour(force, lieu)
  local choisi = missions.niveaux[1] and missions.niveaux[1].nom
  -- Le niveau du lieu (les lieux du socle) : la plus grande taille qu'on y dresse.
  local l = type(lieu) == "string" and lieu_nomme(lieu) or nil
  local plafond = l and l.niveau
  for _, n in ipairs(missions.niveaux) do
    local t = Scriptorium.avis(missions, "taille_du_camp", lieu, n.nom)
    local sorte = t and bataille().sortes[t.sorte]
    if sorte and t.effectif * sorte.poids * missions.reglages.marge_de_force <= force then
      choisi = n.nom
    end
    if n.nom == plafond then
      break
    end
  end
  return choisi
end
Scriptorium.remplacable(missions, "niveau_pour", function(rendu) return niveau_nomme(rendu) ~= nil end)

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

-- Le lieu est-il pris par un camp qui n'est pas levé ? (Un lieu pris n'est donné à aucune autre mission.)
local function lieu_pris(d, nom)
  for _, id in ipairs(d.ordre) do
    local c = d.camps[id]
    if c.etat ~= "leve" and c.lieu.nom == nom then
      return c.id
    end
  end
  return nil
end

-- Accroche (tranche 3 ; Scriptorium l'enveloppe pour ses missions en parallèle) : le lieu est-il réservé ? Rend la
-- raison (le camp qui l'occupe), ou nil s'il est libre.
function missions.lieu_reserve(nom)
  return lieu_pris(donnees(), nom)
end
Scriptorium.remplacable(missions, "lieu_reserve")

-- Service : un lieu libre de la carte (celle où se tient Henry si nil), le premier par nom, ou nil.
function missions.choisir_un_lieu(carte)
  if carte == nil then
    carte = jeu().carte_courante and (jeu().carte_courante()) or nil
  end
  for _, l in ipairs(missions.lieux_de(carte)) do
    if not Scriptorium.avis(missions, "lieu_reserve", l.nom) then
      return l.nom
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

-- Henry voit-il ce lieu ? Dans son regard et à moins de « poste_vue_m » (rien ne disparaît sous ses yeux).
local function lieu_sous_les_yeux(l)
  local henry = jeu().position_du_joueur()
  return henry ~= nil and math.sqrt((henry.x - l.x) ^ 2 + (henry.y - l.y) ^ 2) <= bataille().reglages.poste_vue_m
    and jeu().henry_voit(l, Scriptorium.hommes.reglages.secours_vue_cos) == true
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
      local position, cap = Scriptorium.avis(camp(), "dans_le_monde", l, e.x, e.y, e.cap)
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
  local l = lieu_nomme(nom_du_lieu)
  if not l then
    return refuser("lieu_inconnu", tostring(nom_du_lieu))
  end
  local pris = Scriptorium.avis(missions, "lieu_reserve", nom_du_lieu)
  if pris then
    return refuser("lieu_pris", tostring(pris))
  end
  local taille = Scriptorium.avis(missions, "taille_du_camp", nom_du_lieu, niveau)
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

-- Les personnages d'un camp de bandits (Scriptorium en ajoute et en retire, ses propres bandits) : ils entrent dans sa
-- bande, et rien d'autre.
function missions.personnages_du_camp(id)
  local c = donnees().camps[id]
  return c and bataille().personnages_de(c.bande) or {}
end

function missions.ajouter_un_personnage(id, personnage)
  local c = donnees().camps[id]
  return c ~= nil and bataille().ajouter_a_la_bande(c.bande, personnage) == true
end

function missions.retirer_un_personnage(id, personnage)
  local c = donnees().camps[id]
  return c ~= nil and bataille().retirer_de_la_bande(c.bande, personnage) == true
end

-- Lance un convoi sur une route connue, à un niveau (la taille : l'accroche « taille du camp », le coffre transporté).
-- Un seul convoi par route à la fois. Rend son nom, ou faux et la raison.
function missions.lancer_un_convoi(nom_de_la_route, niveau)
  local d = donnees()
  local route = missions.routes[nom_de_la_route]
  if not route then
    return refuser("route_inconnue", tostring(nom_de_la_route))
  end
  for _, id in ipairs(d.ordre_des_convois) do
    if d.convois[id].etat == "en_route" and d.convois[id].route.nom == nom_de_la_route then
      return refuser("route_prise", id)
    end
  end
  local taille = Scriptorium.avis(missions, "taille_du_camp", nom_de_la_route, niveau)
  if type(taille) ~= "table" then
    return refuser("niveau_inconnu", tostring(niveau))
  end
  local depart = route.points[1]
  local bande, raison = bataille().poster_une_bande({ sorte = taille.sorte, effectif = taille.effectif,
    position = { x = depart.x, y = depart.y, z = depart.z }, cap = 0, carte = route.carte, butin = taille.coffre,
    mobile = true })
  if not bande then
    return refuser("bande_refusee", raison)
  end
  local id = "convoi_" .. d.prochain_convoi
  d.prochain_convoi = d.prochain_convoi + 1
  local points = {}
  for i, p in ipairs(route.points) do points[i] = { x = p.x, y = p.y, z = p.z } end
  local heure = jeu().heure_du_jeu()
  d.convois[id] = { id = id, route = { nom = route.nom, carte = route.carte, points = points }, niveau = niveau,
                    bande = bande, etat = "en_route", parcouru = 0, dernier = heure, coffre = taille.coffre,
                    position = { x = depart.x, y = depart.y, z = depart.z } }
  table.insert(d.ordre_des_convois, id)
  enregistrer()
  jeu().journal("Missions : convoi « " .. id .. " » parti sur « " .. route.nom .. " » (" .. tostring(niveau) .. ", "
                .. taille.effectif .. " " .. taille.sorte .. ")")
  return id
end

function missions.convoi(id)
  local cv = donnees().convois[id]
  return cv and copie_du_convoi(cv) or nil
end

-- Les convois en route.
function missions.convois()
  local d = donnees()
  local liste = {}
  for _, id in ipairs(d.ordre_des_convois) do
    if d.convois[id].etat == "en_route" then
      table.insert(liste, copie_du_convoi(d.convois[id]))
    end
  end
  return liste
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
-- Un homme hors d'état (assommé) ne monte pas à cheval (vu en jeu le 17/10) : la colonne le porte.
local function hors_d_etat(id)
  local f = Scriptorium.hommes.fiche(id)
  return f ~= nil and f.personnage ~= nil and jeu().personnage_inconscient(f.personnage) == true
end

-- La tête de la colonne : son chef s'il tient debout, sinon le premier homme debout (dans le monde, pas hors d'état).
local function tete_de(m)
  local debout = {}
  for _, id in ipairs(vivants_de(m)) do
    if not Scriptorium.hommes.est_dehors(id) and not hors_d_etat(id) then
      table.insert(debout, id)
    end
  end
  for _, id in ipairs(debout) do
    if id == m.chef then
      return id
    end
  end
  return debout[1]
end

-- La colonne va à un point, à cheval, sa tête en avant.
local function envoyer(m, vers)
  m.tete = tete_de(m)
  m.vers = vers and { x = vers.x, y = vers.y, z = vers.z } or nil
  for _, id in ipairs(vivants_de(m)) do
    Scriptorium.hommes.tenir(id, "mission", { activite = "suivre", lieu = m.id, vers = vers, a_cheval = true,
      formation = "followNPC", tete = m.tete, fin = "liberation" })
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
           etat = m.etat, issue = m.issue, depart = m.depart, hommes = vivants_de(m), sortie = m.sortie,
           duree_h = m.duree_h, motif = m.motif }
end

local function finir_la_mission(d, m, heure)
  -- Les portés rentrent avec la colonne, au bord du camp (sans camp, près d'Henry).
  local retour = centre_du_camp() and point_de_retour(m) or nil
  for i, id in ipairs(vivants_de(m)) do
    if Scriptorium.hommes.est_dehors(id) then
      Scriptorium.hommes.faire_rentrer(id, retour and { x = retour.x + i * 1.5, y = retour.y, z = retour.z } or nil)
    end
  end
  for _, id in ipairs(vivants_de(m)) do
    Scriptorium.hommes.lacher(id, "mission")
  end
  m.etat = "finie"
  m.fin = heure
  local resultat = m.resultat or {}
  local r = { id = m.id, lieu = m.lieu.nom, niveau = m.niveau or (m.sortie and "sortie") or nil, issue = m.issue or "perdue",
              depart = m.depart, fin = heure,
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
  local permis, pourquoi = Scriptorium.avis(missions, "peut_partir", ordre)
  if not permis then
    return refuser("ne_peut_partir", tostring(pourquoi))
  end
  local cv = ordre.convoi ~= nil and d.convois[ordre.convoi] or nil
  if ordre.convoi ~= nil and (not cv or cv.etat ~= "en_route") then
    return refuser("convoi_inconnu", tostring(ordre.convoi))
  end
  if cv and missions.reglages.vitesse_m_par_h <= missions.reglages.convoi_m_par_h then
    return refuser("convoi_trop_rapide", cv.id)
  end
  local l = cv and { nom = cv.route.nom, carte = cv.route.carte, x = cv.position.x, y = cv.position.y, z = cv.position.z }
    or lieu_nomme(ordre.lieu)
  -- Fiche 18, 5 d : une sortie vise un lieu connu ou un point du monde.
  local p = ordre.point
  if ordre.sortie and not l and p ~= nil then
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number" then
      return refuser("point_invalide")
    end
    l = { nom = tostring(ordre.motif or "sortie"), carte = jeu().carte_courante and (jeu().carte_courante()) or nil,
          x = p.x, y = p.y, z = p.z }
  end
  if not l then
    return refuser("lieu_inconnu", tostring(ordre.lieu))
  end
  if ordre.sortie and (type(ordre.duree_h) ~= "number" or ordre.duree_h ~= ordre.duree_h or ordre.duree_h < 0
      or ordre.duree_h == math.huge) then
    return refuser("duree_invalide", tostring(ordre.duree_h))
  end
  if type(ordre.hommes) ~= "table" or #ordre.hommes == 0 then
    return refuser("hommes_absents")
  end
  local dans = {}
  for _, id in ipairs(ordre.hommes) do
    local f = Scriptorium.hommes.fiche(id)
    if not f or f.dehors or f.blessure > 0 or dans[id] or not Scriptorium.avis(Scriptorium.hommes, "libre_pour", id, "mission") then
      return refuser("homme_indisponible", tostring(id))
    end
    dans[id] = true
  end
  if ordre.chef ~= nil and not dans[ordre.chef] then
    return refuser("chef_hors_colonne", tostring(ordre.chef))
  end
  local niveau, camp_id = nil, nil
  if not ordre.sortie then
    niveau = cv and cv.niveau or (ordre.niveau or Scriptorium.avis(missions, "niveau_pour", (bataille().force_de(ordre.hommes)), ordre.lieu))
  end
  if not cv and not ordre.sortie then
    local raison
    camp_id, raison = missions.dresser_un_camp(ordre.lieu, niveau)
    if not camp_id then
      return refuser("camp_refuse", raison)
    end
  end
  local heure = jeu().heure_du_jeu()
  local id = "mission_" .. d.prochaine_mission
  d.prochaine_mission = d.prochaine_mission + 1
  local hommes = {}
  for i, h in ipairs(ordre.hommes) do hommes[i] = h end
  local m = { id = id, lieu = { nom = l.nom, carte = l.carte, x = l.x, y = l.y, z = l.z }, camp = camp_id, niveau = niveau,
              hommes = hommes, chef = ordre.chef or hommes[1], etat = "aller", depart = heure, convoi = cv and cv.id or nil,
              sortie = ordre.sortie == true or nil, duree_h = ordre.sortie and ordre.duree_h or nil,
              motif = ordre.sortie and ordre.motif or nil }
  d.missions[id] = m
  table.insert(d.ordre_des_missions, id)
  envoyer(m, { x = l.x, y = l.y, z = l.z })
  enregistrer()
  jeu().journal("Missions : « " .. id .. " » partie vers « " .. l.nom .. " » (" .. tostring(niveau) .. ", " .. #hommes
                .. " homme(s), chef « " .. m.chef .. " »)")
  annoncer("ui_scriptorium_missions_partie", { complement = l.nom })
  return id
end

-- Fiche 18, 5 d : une sortie à cheval (gens de métier, coursier) : { hommes, chef, lieu | point, duree_h, motif }. Rend
-- son nom, ou faux et la raison.
function missions.sortir(ordre)
  local o = {}
  for cle, valeur in pairs(ordre or {}) do o[cle] = valeur end
  o.sortie = true
  return missions.prendre_une_mission(o)
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

local function distance_au_camp(m)
  local depuis, la = centre_du_camp() or m.lieu, m.lieu
  return math.sqrt((la.x - depuis.x) ^ 2 + (la.y - depuis.y) ^ 2)
end

-- Fiche 18, 5 d : une sortie avance d'un battement (aller, sur place, au loin). Rend vrai si elle a changé, faux sinon,
-- ou nil pour le retour (« dehors_retour », « retour »), commun avec les missions.
local function avancer_la_sortie(d, m, heure, vivants)
  local r = missions.reglages
  if m.etat == "aller" then
    for _, id in ipairs(vivants) do
      local f = Scriptorium.hommes.fiche(id)
      local ici = f.personnage and jeu().position_du_personnage(f.personnage)
      if ici and math.sqrt((ici.x - m.lieu.x) ^ 2 + (ici.y - m.lieu.y) ^ 2) <= r.arrivee_m then
        m.etat = "sur_place"
        m.jusqu_a = heure + m.duree_h
        jeu().journal(string.format("Missions : sortie « %s » arrivée à « %s », jusqu'à %.2f h", m.id, m.lieu.nom, m.jusqu_a))
        return true
      end
    end
    if hors_de_la_vue(vivants) then
      for _, id in ipairs(vivants) do
        Scriptorium.hommes.mettre_dehors(id, m.id)
      end
      m.etat = "dehors_aller"
      m.arrivee = heure + distance_au_camp(m) / r.vitesse_m_par_h
      jeu().journal(string.format("Missions : sortie « %s » dehors, au lieu à %.2f h", m.id, m.arrivee))
      return true
    end
    return false
  elseif m.etat == "sur_place" then
    if heure >= m.jusqu_a then
      m.issue = "faite"
      local retour = point_de_retour(m)
      if not retour then
        finir_la_mission(d, m, heure)
        return true
      end
      m.etat = "retour"
      envoyer(m, retour)
      jeu().journal("Missions : sortie « " .. m.id .. " » : retour au camp")
      return true
    end
    if hors_de_la_vue(vivants) then
      for _, id in ipairs(vivants) do
        Scriptorium.hommes.mettre_dehors(id, m.id)
      end
      m.issue = "faite"
      m.etat = "dehors_retour"
      m.retour = m.jusqu_a + distance_au_camp(m) / r.vitesse_m_par_h
      jeu().journal(string.format("Missions : sortie « %s » dehors sur place, de retour à %.2f h", m.id, m.retour))
      return true
    end
    return false
  elseif m.etat == "dehors_aller" then
    if heure >= m.arrivee then
      m.issue = "faite"
      m.etat = "dehors_retour"
      m.retour = heure + m.duree_h + distance_au_camp(m) / r.vitesse_m_par_h
      jeu().journal(string.format("Missions : sortie « %s » au lieu (au loin), de retour à %.2f h", m.id, m.retour))
      return true
    end
    return false
  end
  return nil
end

-- Une mission avance d'un battement. Rend vrai si elle a changé.
local function avancer(d, m, heure)
  local vivants = vivants_de(m)
  if #vivants == 0 then
    m.issue = m.issue or "perdue"
    finir_la_mission(d, m, heure)
    return true
  end
  if m.sortie then
    local change = avancer_la_sortie(d, m, heure, vivants)
    if change ~= nil then
      return change
    end
  end
  -- La bande visée : celle du camp de bandits, ou celle du convoi (tranche 4).
  local cv = m.convoi and d.convois[m.convoi] or nil
  local c = d.camps[m.camp] or (cv and { bande = cv.bande }) or nil
  local b = c and bataille().bande(c.bande)
  if m.etat == "aller" and cv and cv.etat == "arrive" then
    -- Le convoi est arrivé au bout de sa route avant d'être pris : échappé, la colonne rentre.
    m.issue = "echappe"
    local retour = point_de_retour(m)
    if not retour then
      finir_la_mission(d, m, heure)
      return true
    end
    m.etat = "retour"
    envoyer(m, retour)
    jeu().journal("Missions : « " .. m.id .. " » : le convoi s'est échappé, retour au camp")
    return true
  end
  if m.etat == "aller" and cv and cv.position then
    -- La colonne vise le convoi où il est ; l'ordre redonné quand il a bougé de plus de 15 m.
    m.lieu.x, m.lieu.y, m.lieu.z = cv.position.x, cv.position.y, cv.position.z
    if not m.vers or math.sqrt((m.vers.x - cv.position.x) ^ 2 + (m.vers.y - cv.position.y) ^ 2) > 15 then
      envoyer(m, { x = cv.position.x, y = cv.position.y, z = cv.position.z })
    end
  end
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
      if cv then
        -- Le convoi avance : l'heure de la prise se calcule contre sa position à cette heure (trois approches).
        for _ = 1, 3 do
          local p = position_du_convoi_a(cv, m.arrivee)
          m.lieu.x, m.lieu.y, m.lieu.z = p.x, p.y, p.z
          m.arrivee = heure + math.sqrt((p.x - depuis.x) ^ 2 + (p.y - depuis.y) ^ 2) / missions.reglages.vitesse_m_par_h
        end
      end
      jeu().journal(string.format("Missions : « %s » dehors, au lieu à %.2f h", m.id, m.arrivee))
      return true
    end
  elseif m.etat == "dehors_aller" and heure >= m.arrivee then
    if cv and cv.etat == "arrive" then
      m.issue = "echappe"
    else
      if b and b.etat ~= "finie" then
        m.resultat = bataille().trancher_la_bande_postee(c.bande, vivants)
      end
      local fini = c and bataille().bande(c.bande)
      m.issue = fini and fini.issue or "perdue"
    end
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
    -- Vu sur une copie de la partie de JoVenGer le 21/10 (J3 : Jan Kladivo renaissait 3,7 m en l'air, debout et raide) :
    -- chacun renaît au sol de sa place (le terrain lu au point), non à la hauteur du centre du camp.
    for i, id in ipairs(vivants) do
      if Scriptorium.hommes.est_dehors(id) then
        local x = point.x + (i - 1) * 2
        local sol = jeu().altitude_du_terrain and jeu().altitude_du_terrain(x, point.y)
        Scriptorium.hommes.faire_rentrer(id, { x = x, y = point.y, z = tonumber(sol) or point.z })
      end
    end
    m.etat = "retour"
    envoyer(m, point_de_retour(m))
    jeu().journal("Missions : « " .. m.id .. " » renaît sur le chemin du camp")
    return true
  elseif m.etat == "retour" then
    local retour = point_de_retour(m)
    -- Les hommes hors d'état sont portés : mis dehors hors de la vue d'Henry, ils rentrent avec la colonne ; si personne
    -- ne tient debout, toute la colonne rentre « dehors », à l'heure calculée.
    local change = false
    for _, id in ipairs(vivants) do
      local f = Scriptorium.hommes.fiche(id)
      local ici = f.personnage and jeu().position_du_personnage(f.personnage)
      if not Scriptorium.hommes.est_dehors(id) and hors_d_etat(id) and ici and not lieu_sous_les_yeux(ici) then
        Scriptorium.hommes.mettre_dehors(id, m.id)
        jeu().journal("Missions : « " .. m.id .. " » : « " .. f.nom .. " » hors d'état, porté par la colonne")
        change = true
      end
    end
    local tete = tete_de(m)
    if not tete then
      local fini = true
      for _, id in ipairs(vivants) do
        if not Scriptorium.hommes.est_dehors(id) then fini = false end
      end
      if fini then
        local depuis, la = centre_du_camp() or m.lieu, m.lieu
        m.etat = "dehors_retour"
        m.retour = heure + math.sqrt((la.x - depuis.x) ^ 2 + (la.y - depuis.y) ^ 2) / missions.reglages.vitesse_m_par_h
        jeu().journal("Missions : « " .. m.id .. " » : personne debout, la colonne rentre au loin")
        return true
      end
      return change
    end
    if tete ~= m.tete and retour then
      envoyer(m, retour)
      change = true
    end
    for _, id in ipairs(vivants) do
      local f = Scriptorium.hommes.fiche(id)
      local ici = f.personnage and jeu().position_du_personnage(f.personnage)
      if retour and ici and math.sqrt((ici.x - retour.x) ^ 2 + (ici.y - retour.y) ^ 2) <= missions.reglages.arrivee_m then
        finir_la_mission(d, m, heure)
        return true
      end
    end
    return change
  end
  return false
end

-- Un convoi avance d'un battement : à pied, tant que sa bande n'est pas au combat ; sa bande suit son point (née, elle y
-- marche ; loin d'Henry et hors de sa vue, retirée du monde, elle renaîtra au bon endroit) ; au bout de sa route,
-- arrivé (retiré hors de la vue d'Henry) ; sa bande finie, le convoi aussi (vaincu : l'accroche « camp vaincu »).
-- Rend vrai s'il a changé.
local function avancer_le_convoi(cv, heure)
  if cv.etat ~= "en_route" then
    return false
  end
  local b = bataille().bande(cv.bande)
  if not b or b.etat == "finie" then
    cv.etat = "fini"
    cv.issue = b and b.issue or "oubliee"
    if cv.issue == "victoire" or cv.issue == "victoire_couteuse" then
      local copie = copie_du_convoi(cv)
      copie.lieu = cv.route.nom
      local ok, erreur = pcall(missions.camp_vaincu, copie)
      if not ok then
        jeu().journal("Missions : accroche « camp vaincu » (convoi) en erreur : " .. tostring(erreur))
      end
    end
    jeu().journal("Missions : convoi « " .. cv.id .. " » fini (" .. tostring(cv.issue) .. ")")
    return true
  end
  if b.etat == "postee" then
    cv.parcouru = cv.parcouru + math.max(0, heure - cv.dernier) * missions.reglages.convoi_m_par_h
  end
  cv.dernier = heure
  local position, regard, au_bout = point_de_la_route(cv.route, cv.parcouru)
  cv.position = { x = position.x, y = position.y, z = position.z }
  if b.etat ~= "postee" then
    return false
  end
  if au_bout then
    if #b.personnages > 0 and lieu_sous_les_yeux(position) then
      return false
    end
    if #b.personnages > 0 then
      jeu().renvoyer_ennemis(b.personnages)
    end
    bataille().oublier_la_bande(cv.bande)
    cv.etat = "arrive"
    jeu().journal("Missions : convoi « " .. cv.id .. " » arrivé au bout de « " .. cv.route.nom .. " »")
    return true
  end
  bataille().deplacer_la_bande(cv.bande, position, regard)
  local henry = jeu().position_du_joueur()
  if #b.personnages > 0 and henry and math.sqrt((henry.x - position.x) ^ 2 + (henry.y - position.y) ^ 2)
      > bataille().reglages.poste_vue_m then
    bataille().retirer_la_bande_du_monde(cv.bande)
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
    elseif c.etat == "fini" and heure >= c.fini_a + missions.reglages.camp_vaincu_reste_h and not lieu_sous_les_yeux(c.lieu) then
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
  for _, id in ipairs(d.ordre_des_convois) do
    if avancer_le_convoi(d.convois[id], heure) then
      rapport.convois = (rapport.convois or 0) + 1
      change = true
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
  -- Les camps de bandits avancent par le battement du socle. Les lieux du socle : une ligne au journal par carte.
  local par_carte, cartes = {}, {}
  for _, l in ipairs(missions.lieux_du_socle) do
    if not par_carte[l.carte] then
      par_carte[l.carte] = 0
      table.insert(cartes, l.carte)
    end
    par_carte[l.carte] = par_carte[l.carte] + 1
  end
  for _, carte in ipairs(cartes) do
    jeu().journal("Missions : " .. par_carte[carte] .. " lieux du socle sur " .. carte)
  end
end)

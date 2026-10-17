-- Le combat et les batailles : lever une bande, l'ordre de bataille, l'issue, les pertes, le butin.
-- Fiche de comportement : docs/socle/fiches/05_bataille.md

local Scriptorium = Scriptorium

local bataille = {}
Scriptorium.bataille = bataille

bataille.reglages = {
  delai_par_defaut = 2,        -- heures de jeu avant l'arrivée
  distance_arrivee = 60,       -- mètres du camp
  avertissement = 1,           -- heures avant l'arrivée où le joueur est prévenu
  duree_max_contact = 2,       -- heures de contact avant que la règle tranche
  ecart_entre_hommes = 1.2,    -- mètres
  distance_rang_avant = 10,
  distance_rang_arriere = 7,
  effectif_max = 60,
  journal_gardes = 30,
  duree_des_corps = 24,        -- heures de jeu où les corps ennemis restent à fouiller (choix de JoVenGer, 14/10)
  -- Étape 2 (le nécessaire, fiche 14) : au contact, chaque combattant reçoit l'ordre d'attaque contre un ennemi vivant ;
  -- redonné à chaque battement à ceux dont la cible est tombée.
  attaque_au_contact = true,
  -- La bande attaque d'elle-même (règle scellée de Scriptorium « ennemis_au_contact ») : chaque ennemi vivant qui ne se
  -- bat pas reçoit l'ordre d'attaque contre un de nos combattants vivants, ou contre Henry s'il est à moins de
  -- « bande_vise_henry_m » de la bande ; en tourniquet ; redonné à chaque battement.
  bande_attaque = true,
  bande_vise_henry_m = 80,
  -- « Que personne ne reste figé » (JoVenGer ; le raid du 8/10) : pendant une bataille au contact, l'attaque est
  -- redonnée toutes les « relance_au_contact_ms » à chaque combattant vivant qui ne se bat pas, des deux côtés ; la
  -- minuterie s'arrête à la fin de la bataille ; le battement reste le filet.
  relance_au_contact_ms = 2000,
  -- Vu en jeu le 17/10 : un ordre redonné toutes les 2 s à un homme qui marche vers sa cible coupait son approche ; il
  -- n'est redonné qu'à qui n'a pas bougé de « relance_bouge_m » depuis le relevé précédent (figé), ou dont la cible est
  -- tombée.
  relance_bouge_m = 0.5,
  -- (relecture du pair, la leçon du dégel de Scriptorium) Celui qui attend son tour à moins de « relance_pres_m » de sa
  -- cible n'est pas figé ; « relances_par_bataille » relances au plus par personnage, puis une ligne au journal.
  relance_pres_m = 4,
  relances_par_bataille = 2,
  -- Fiche 17 (le camp de bandits) : une bande « postée » à un lieu naît quand Henry est sur la carte du lieu et que le
  -- lieu n'est pas dans son regard à moins de « poste_vue_m » ; Henry ou un de nos hommes à moins de « poste_alerte_m »
  -- du lieu : elle attaque ; nos combattants à moins de « poste_engagement_m » s'engagent ; Henry à plus de
  -- « poste_fuite_m » sans aucun de nos combattants : elle retourne à son poste avec ses survivants.
  poste_vue_m = 300,
  poste_alerte_m = 35,
  poste_engagement_m = 80,
  poste_fuite_m = 300,
}

-- Butin par tête doublé à la validation de la fiche par JoVenGer (14/10).
bataille.sortes = {
  brigands   = { poids = 1.0, butin_par_tete = 16 },
  deserteurs = { poids = 0.8, butin_par_tete = 10 },
  soudards   = { poids = 1.2, butin_par_tete = 20 },
  coumans    = { poids = 1.4, butin_par_tete = 24 },
}

-- Poids au combat et rang de chaque rôle ; les rôles absents restent au feu.
bataille.roles = {
  homme_d_armes = { poids = 3, rang = "avant" },
  pavoisier     = { poids = 2, rang = "avant" },
  arbaletrier   = { poids = 2.5, rang = "arriere" },
  archer        = { poids = 2, rang = "arriere" },
}

-- Issues, du meilleur au pire : rapport de force minimal, pertes, moral, part du butin.
bataille.issues = {
  { nom = "victoire", rapport = 1.5, morts = 0, blesses = 0.15, moral = 10, butin = 1.0, cle = "ui_scriptorium_bataille_victoire" },
  { nom = "victoire_couteuse", rapport = 1.0, morts = 0.10, blesses = 0.30, moral = 5, butin = 0.6, cle = "ui_scriptorium_bataille_victoire_couteuse" },
  { nom = "repoussee", rapport = 0.7, morts = 0.20, blesses = 0.40, moral = -5, butin = 0.2, cle = "ui_scriptorium_bataille_repoussee" },
  { nom = "defaite", rapport = 0, morts = 0.35, blesses = 0.40, moral = -15, butin = 0, cle = "ui_scriptorium_bataille_defaite" },
}

local function jeu()
  return Scriptorium.jeu
end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

local function hommes()
  return Scriptorium.hommes
end

local function camp()
  return Scriptorium.camp
end

local function coffre()
  return Scriptorium.coffre
end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return { prochaine = 1, bandes = {}, ordre = {}, resultats = {}, graine = Scriptorium.hasard_depuis(12345) }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("bataille") then
    registre.declarer_case("bataille", 1, donnees_neuves)
  end
  return registre.lire("bataille")
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

local function refuser(raison, detail)
  jeu().journal("Bataille : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

-- Hasard gardé au registre : la même partie rejoue les mêmes coups. Une ancienne graine (un seul nombre) donne ses
-- trois germes à la première lecture.
local function tirage(d)
  if not Scriptorium.hasard_en_ordre(d.graine) then
    d.graine = Scriptorium.hasard_depuis(d.graine)
  end
  return Scriptorium.tirer(d.graine)
end

-- Le même hasard, pour les autres morceaux (patrouilles).
function bataille.tirage()
  return tirage(donnees())
end

function bataille.fixer_la_graine(graine)
  donnees().graine = Scriptorium.hasard_depuis(graine)
end

-- ---------------------------------------------------------------- lever une bande

function bataille.lever_une_bande(ordre)
  ordre = ordre or {}
  local d = donnees()
  if not camp().est_fonde() then
    return refuser("camp_absent")
  end
  local sorte = bataille.sortes[ordre.sorte]
  if not sorte then
    return refuser("sorte_inconnue", tostring(ordre.sorte))
  end
  local effectif = ordre.effectif
  if type(effectif) ~= "number" or math.floor(effectif) ~= effectif or effectif < 1 or effectif > bataille.reglages.effectif_max then
    return refuser("effectif_invalide", tostring(effectif))
  end
  if type(ordre.direction) ~= "number" then
    return refuser("direction_invalide", tostring(ordre.direction))
  end
  local delai = ordre.delai
  if delai == nil then delai = bataille.reglages.delai_par_defaut end
  if type(delai) ~= "number" or delai < 0 then
    return refuser("delai_invalide", tostring(delai))
  end
  local heure = jeu().heure_du_jeu()
  local id = "bande_" .. d.prochaine
  d.prochaine = d.prochaine + 1
  d.bandes[id] = {
    id = id,
    sorte = ordre.sorte,
    effectif = effectif,
    direction = ordre.direction % 360,
    levee = heure,
    arrivee = heure + delai,
    etat = "en_marche",
    annoncee = false,
    contact = nil,
    personnages = nil,
    combattants = {},
  }
  table.insert(d.ordre, id)
  enregistrer()
  jeu().journal("Bataille : bande « " .. id .. " » levée, " .. effectif .. " " .. ordre.sorte .. ", arrivée à " .. (heure + delai) .. " h")
  return id
end

-- Une bande postée à un lieu (fiche 17) : { sorte, effectif, position, cap, carte, butin } ; elle ne marche pas vers le
-- camp ; « butin » : la somme de son camp, qui remplace le butin par tête. Rend son nom, ou faux et la raison.
function bataille.poster_une_bande(ordre)
  ordre = ordre or {}
  local d = donnees()
  if not bataille.sortes[ordre.sorte] then
    return refuser("sorte_inconnue", tostring(ordre.sorte))
  end
  local effectif = ordre.effectif
  if type(effectif) ~= "number" or math.floor(effectif) ~= effectif or effectif < 1 or effectif > bataille.reglages.effectif_max then
    return refuser("effectif_invalide", tostring(effectif))
  end
  local p = ordre.position
  if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number" then
    return refuser("position_invalide")
  end
  if type(ordre.carte) ~= "string" or ordre.carte == "" then
    return refuser("carte_invalide", tostring(ordre.carte))
  end
  if ordre.butin ~= nil and (type(ordre.butin) ~= "number" or ordre.butin < 0) then
    return refuser("butin_invalide", tostring(ordre.butin))
  end
  local heure = jeu().heure_du_jeu()
  local id = "bande_" .. d.prochaine
  d.prochaine = d.prochaine + 1
  d.bandes[id] = {
    id = id, sorte = ordre.sorte, effectif = effectif, direction = 0, levee = heure, arrivee = heure,
    etat = "postee", postee = true, carte = ordre.carte, cap = tonumber(ordre.cap) or 0, butin_du_camp = ordre.butin,
    point_d_arrivee = { x = p.x, y = p.y, z = p.z }, annoncee = true, contact = nil, personnages = nil, combattants = {},
  }
  table.insert(d.ordre, id)
  enregistrer()
  jeu().journal("Bataille : bande « " .. id .. " » postée, " .. effectif .. " " .. ordre.sorte .. ", carte " .. ordre.carte
                .. string.format(" (%.0f, %.0f)", p.x, p.y))
  return id
end

function bataille.bande(id)
  local b = donnees().bandes[id]
  if not b then
    return nil
  end
  local copie = {}
  for cle, valeur in pairs(b) do
    if type(valeur) ~= "table" then copie[cle] = valeur end
  end
  copie.combattants = {}
  for i, c in ipairs(b.combattants or {}) do copie.combattants[i] = c end
  copie.personnages = {}
  for i, p in ipairs(b.personnages or {}) do copie.personnages[i] = p end
  copie.ennemis = b.personnages and #b.personnages or 0
  return copie
end

-- Les bandes qui ne sont pas finies, dans l'ordre de levée.
function bataille.bandes()
  local d = donnees()
  local liste = {}
  for _, id in ipairs(d.ordre) do
    if d.bandes[id].etat ~= "finie" then
      table.insert(liste, id)
    end
  end
  return liste
end

-- ---------------------------------------------------------------- forces et ordre de bataille

-- Les combattants valides, rang avant puis rang arrière, par ancienneté.
function bataille.combattants()
  local avant, arriere = {}, {}
  for _, id in ipairs(hommes().liste()) do
    local f = hommes().fiche(id)
    local role = bataille.roles[f.role]
    if role and f.blessure == 0 then
      if role.rang == "avant" then table.insert(avant, id) else table.insert(arriere, id) end
    end
  end
  return avant, arriere
end

function bataille.force_des_notres()
  local avant, arriere = bataille.combattants()
  local force, moral, nombre = 0, 0, 0
  for _, liste in ipairs({ avant, arriere }) do
    for _, id in ipairs(liste) do
      local f = hommes().fiche(id)
      local facteur = 1
      if Scriptorium.atelier and Scriptorium.atelier.facteur_de then
        facteur = Scriptorium.atelier.facteur_de(id)
      end
      -- Aguerrissement, courage et fatigue de l'homme (fiche 11).
      if Scriptorium.caractere then
        facteur = facteur * Scriptorium.caractere.facteur_de_combat(id)
      end
      force = force + bataille.roles[f.role].poids * facteur
      moral = moral + f.moral
      nombre = nombre + 1
    end
  end
  if nombre == 0 then
    return 0
  end
  local facteur_moral = 0.7 + 0.5 * (moral / nombre) / 100
  local bonus = 1
  if Scriptorium.enceinte and Scriptorium.enceinte.bonus then
    bonus = Scriptorium.enceinte.bonus()
  end
  return force * facteur_moral * bonus
end

function bataille.force_de_la_bande(b)
  return b.effectif * bataille.sortes[b.sorte].poids
end

-- Un point du camp dans le monde, le plan étant tourné vers la menace.
local function point_face_a(direction, x, y)
  local tourne = camp().dans_le_monde({ x = 0, y = 0, z = 0, cap = direction }, x, y, 0)
  return camp().point(tourne.x, tourne.y, direction)
end

-- L'ordre de bataille face à une direction : { avant = {…}, arriere = {…}, reserve = {…} },
-- chaque entrée { id, position, cap }.
function bataille.ordre_de_bataille(direction)
  local avant, arriere = bataille.combattants()
  local r = bataille.reglages
  local ordre = { avant = {}, arriere = {}, reserve = {} }
  local n = #avant
  for i, id in ipairs(avant) do
    local x = (i - (n + 1) / 2) * r.ecart_entre_hommes
    table.insert(ordre.avant, { id = id, position = point_face_a(direction, x, r.distance_rang_avant), cap = direction, x = x })
  end
  -- Les tireurs se placent dans les intervalles du rang avant, puis débordent sur les ailes.
  local intervalles = {}
  for i = 1, n - 1 do
    table.insert(intervalles, (i - n / 2) * r.ecart_entre_hommes)
  end
  local gauche = -(n / 2) * r.ecart_entre_hommes
  local droite = (n / 2) * r.ecart_entre_hommes
  for j, id in ipairs(arriere) do
    local x
    if intervalles[j] ~= nil then
      x = intervalles[j]
    else
      local k = j - #intervalles
      local cote = (k % 2 == 1) and -1 or 1
      local ecart = math.ceil(k / 2) * r.ecart_entre_hommes
      x = (cote < 0) and (gauche - ecart) or (droite + ecart)
    end
    table.insert(ordre.arriere, { id = id, position = point_face_a(direction, x, r.distance_rang_arriere), cap = direction, x = x })
  end
  for _, id in ipairs(hommes().liste()) do
    local place = false
    for _, liste in ipairs({ avant, arriere }) do
      for _, autre in ipairs(liste) do
        if autre == id then place = true end
      end
    end
    if not place then
      table.insert(ordre.reserve, { id = id })
    end
  end
  return ordre
end

-- ---------------------------------------------------------------- contact et fin

local function mettre_en_bataille(d, b)
  local ordre = bataille.ordre_de_bataille(b.direction)
  b.combattants = {}
  for _, rang in ipairs({ "avant", "arriere" }) do
    for _, entree in ipairs(ordre[rang]) do
      -- L'arbitre (fiche 15, V73 b 3) : la bataille, la règle la plus forte, jusqu'à la fin de la bataille.
      hommes().tenir(entree.id, "bataille", { activite = "bataille", lieu = "rang_" .. rang, position = entree.position,
                                             cap = entree.cap, fin = "liberation" })
      table.insert(b.combattants, entree.id)
    end
  end
end

local function liberer_les_hommes(b)
  for _, id in ipairs(b.combattants or {}) do
    if hommes().fiche(id) then
      hommes().lacher(id, "bataille")
    end
  end
end

-- Le personnage est-il figé (à relancer) ? Jamais s'il se bat ; il faut deux relevés de suite ; figé s'il n'a pas bougé
-- de « relance_bouge_m » et qu'il est à plus de « relance_pres_m » de sa cible (ou sans cible lisible) ; au plus
-- « relances_par_bataille » fois, puis une ligne « figé malgré … relances » avec sa position et celle de sa cible.
bataille.vus = {}

local function a_relancer(b, personnage, nom, cible)
  if jeu().occupation_de(personnage) == "combat" then
    bataille.vus[personnage] = nil
    return false
  end
  local ici = jeu().position_du_personnage(personnage)
  local avant = bataille.vus[personnage]
  bataille.vus[personnage] = ici and { x = ici.x, y = ici.y } or nil
  local bouge = avant and jeu().ecart_au_but(personnage, avant)
  if not (ici and bouge) or bouge >= bataille.reglages.relance_bouge_m then
    return false
  end
  local la = (cible == "henry") and jeu().position_du_joueur() or (cible and jeu().position_du_personnage(cible))
  local pres = la and jeu().ecart_au_but(personnage, la)
  if pres and pres <= bataille.reglages.relance_pres_m then
    return false
  end
  b.relances_de = b.relances_de or {}
  local n = b.relances_de[personnage] or 0
  if n >= bataille.reglages.relances_par_bataille then
    if n == bataille.reglages.relances_par_bataille then
      b.relances_de[personnage] = n + 1
      jeu().journal(string.format("Bataille : « %s » figé malgré %d relances (en %.1f, %.1f ; sa cible %s)", nom, n,
        ici.x, ici.y, la and string.format("en %.1f, %.1f", la.x, la.y) or "illisible"))
    end
    return false
  end
  b.relances_de[personnage] = n + 1
  return true
end

-- L'attaque (étape 2) : chaque combattant qui ne se bat pas (vu en jeu le 17/10 : son combat fini, il retourne à son
-- rang et ne repart pas) reçoit l'ordre d'attaque : sa cible si elle vit encore, sinon un autre ennemi vivant, en
-- tourniquet. Rend le nombre d'ordres donnés.
local function lancer_l_attaque(b)
  if not bataille.reglages.attaque_au_contact or type(b.personnages) ~= "table" then
    return 0
  end
  local vivants = {}
  for _, e in ipairs(b.personnages) do
    if jeu().ennemis_vivants({ e }) > 0 then
      table.insert(vivants, e)
    end
  end
  if #vivants == 0 then
    return 0
  end
  b.cibles = b.cibles or {}
  local donnes, k = 0, 0
  for _, id in ipairs(b.combattants or {}) do
    local f = hommes().fiche(id)
    local cible = b.cibles[id]
    local tombee = cible == nil or jeu().ennemis_vivants({ cible }) == 0
    if f and f.personnage and not jeu().personnage_mort(f.personnage)
        and (a_relancer(b, f.personnage, f.nom, cible) or (tombee and jeu().occupation_de(f.personnage) ~= "combat")) then
      if tombee then
        k = k % #vivants + 1
        b.cibles[id] = vivants[k]
      end
      jeu().journal("Bataille : « " .. f.nom .. " » attaque « " .. b.cibles[id] .. " » : "
                    .. tostring(jeu().ordonner_l_attaque(b.cibles[id], f.personnage)))
      donnes = donnes + 1
    end
  end
  return donnes
end

-- L'attaque de la bande (étape 2, règle scellée « ennemis_au_contact ») : une bande ne reste jamais sur place. Rend le
-- nombre d'ordres donnés.
local function lancer_l_attaque_de_la_bande(b)
  if not bataille.reglages.bande_attaque or type(b.personnages) ~= "table" then
    return 0
  end
  local cibles = {}
  for _, id in ipairs(b.combattants or {}) do
    local f = hommes().fiche(id)
    if f and f.personnage and not jeu().personnage_mort(f.personnage) then
      table.insert(cibles, f.personnage)
    end
  end
  local henry = jeu().position_du_joueur()
  -- La bande se repère par un ennemi vivant, sinon par son point d'arrivée.
  local premier = nil
  for _, e in ipairs(b.personnages) do
    premier = premier or (jeu().ennemis_vivants({ e }) > 0 and jeu().position_du_personnage(e)) or nil
  end
  premier = premier or b.point_d_arrivee
  if henry and premier and math.sqrt((henry.x - premier.x) ^ 2 + (henry.y - premier.y) ^ 2) <= bataille.reglages.bande_vise_henry_m then
    table.insert(cibles, "henry")
  end
  if #cibles == 0 then
    return 0
  end
  b.cibles_de_la_bande = b.cibles_de_la_bande or {}
  local vivantes = {}
  for _, c in ipairs(cibles) do
    vivantes[c] = true
  end
  local donnes, k = 0, 0
  for _, e in ipairs(b.personnages) do
    local tombee = not vivantes[b.cibles_de_la_bande[e]]
    if jeu().ennemis_vivants({ e }) > 0
        and (a_relancer(b, e, e, b.cibles_de_la_bande[e]) or (tombee and jeu().occupation_de(e) ~= "combat")) then
      if tombee then
        k = k % #cibles + 1
        b.cibles_de_la_bande[e] = cibles[k]
      end
      jeu().journal("Bataille : « " .. e .. " » attaque « " .. b.cibles_de_la_bande[e] .. " » : "
                    .. tostring(jeu().ordonner_l_attaque(b.cibles_de_la_bande[e], e)))
      donnes = donnes + 1
    end
  end
  return donnes
end

-- La relance au contact : une minuterie par bande et par partie (génération).
bataille.relances = {}
local function assurer_la_relance(id)
  local generation = Scriptorium.generation
  if bataille.relances[id] == generation then
    return false
  end
  bataille.relances[id] = generation
  local function tour()
    if generation ~= Scriptorium.generation or not Scriptorium.en_partie then
      return
    end
    local b = donnees().bandes[id]
    if not b or b.etat ~= "au_contact" or not b.personnages then
      bataille.relances[id] = nil
      return
    end
    local ok, erreur = pcall(function()
      lancer_l_attaque_de_la_bande(b)
      lancer_l_attaque(b)
    end)
    if not ok then
      jeu().journal("Bataille : relance au contact en erreur : " .. tostring(erreur))
    end
    jeu().minuterie(bataille.reglages.relance_au_contact_ms, tour)
  end
  jeu().minuterie(bataille.reglages.relance_au_contact_ms, tour)
  return true
end

local function arriver(d, b)
  local position = point_face_a(b.direction, 0, bataille.reglages.distance_arrivee)
  local cap = (b.direction + 180) % 360
  b.point_d_arrivee = position and { x = position.x, y = position.y, z = position.z } or nil
  b.etat = "au_contact"
  b.contact = jeu().heure_du_jeu()
  mettre_en_bataille(d, b)
  -- Fiche 15, V73 f 3 b : sur une autre carte que celle du camp, aucune bande ne naît ici : la règle tranchera.
  local ailleurs = camp().sur_sa_carte and not camp().sur_sa_carte()
  local personnages = nil
  if ailleurs then
    jeu().journal("Bataille : « " .. b.id .. " » au contact, Henry sur une autre carte que le camp")
  else
    personnages = jeu().faire_venir_ennemis(b.sorte, b.effectif, position, cap)
  end
  if type(personnages) == "table" and #personnages > 0 then
    b.personnages = personnages
    jeu().journal("Bataille : « " .. b.id .. " » au contact, " .. #personnages .. " ennemi(s) dans le jeu")
    lancer_l_attaque_de_la_bande(b)
    lancer_l_attaque(b)
    assurer_la_relance(b.id)
  else
    b.personnages = nil
    jeu().journal("Bataille : « " .. b.id .. " » au contact, le jeu n'a pas fait venir la bande : la règle tranchera")
  end
end

local function choisir_issue(rapport)
  for _, issue in ipairs(bataille.issues) do
    if rapport >= issue.rapport then
      return issue
    end
  end
  return bataille.issues[#bataille.issues]
end

-- Applique l'issue : morts, blessés, moral, pillage, butin. Rend le résultat.
local function appliquer(d, b, issue, morts_par_le_jeu)
  local resultat = { bande = b.id, sorte = b.sorte, effectif = b.effectif, issue = issue.nom,
                     morts = {}, blesses = {}, butin = 0, part_coffre = 0, pillage = 0, moment = jeu().heure_du_jeu() }
  -- Les combattants encore là, rang avant d'abord (il tombe le premier).
  local vivants = {}
  for _, id in ipairs(b.combattants) do
    if hommes().fiche(id) then table.insert(vivants, id) end
  end
  -- Dans un même rang, l'homme de moindre jugement tombe le premier (fiche 11).
  if Scriptorium.caractere then
    vivants = Scriptorium.caractere.ordre_de_chute(vivants)
  end
  if morts_par_le_jeu then
    for _, id in ipairs(morts_par_le_jeu) do
      table.insert(resultat.morts, id)
    end
  else
    local nombre_morts = math.floor(#vivants * issue.morts + tirage(d))
    nombre_morts = math.min(nombre_morts, #vivants)
    for i = 1, nombre_morts do
      table.insert(resultat.morts, vivants[i])
    end
  end
  local survivants = {}
  for _, id in ipairs(vivants) do
    local mort = false
    for _, m in ipairs(resultat.morts) do
      if m == id then mort = true end
    end
    if not mort then table.insert(survivants, id) end
  end
  local nombre_blesses = math.min(#survivants, math.floor(#survivants * issue.blesses + 0.5))
  -- Les blessés sont pris au hasard parmi les survivants.
  local candidats = {}
  for i, id in ipairs(survivants) do candidats[i] = id end
  for _ = 1, nombre_blesses do
    local k = math.floor(tirage(d) * #candidats) + 1
    local id = table.remove(candidats, k)
    local jours = 2 + math.floor(tirage(d) * 4)
    table.insert(resultat.blesses, { id = id, jours = jours })
  end
  -- L'équipement des combattants s'use.
  if Scriptorium.atelier and Scriptorium.atelier.user_apres_bataille then
    Scriptorium.atelier.user_apres_bataille(vivants)
  end
  -- Lâcher les tenues de bataille avant de toucher aux fiches.
  liberer_les_hommes(b)
  for _, id in ipairs(resultat.morts) do
    hommes().retirer(id, "mort")
  end
  for _, blesse in ipairs(resultat.blesses) do
    hommes().blesser(blesse.id, blesse.jours)
  end
  -- Le retour de bataille : fatigue, aguerrissement, découverte ; une blessure affaiblit la forme (fiche 11).
  if Scriptorium.caractere then
    Scriptorium.caractere.apres_bataille(survivants)
    for _, blesse in ipairs(resultat.blesses) do
      Scriptorium.caractere.blessure_recue(blesse.id)
    end
  end
  hommes().moral_pour_tous(issue.moral)
  -- Pillage en cas de défaite (pas pour une bande postée : elle se bat chez elle, fiche 17).
  if issue.nom == "defaite" and not b.postee then
    local pille = math.floor(coffre().solde() / 2)
    if pille > 0 then
      coffre().payer(pille, "pillage")
      resultat.pillage = pille
    end
  end
  -- Butin, partagé selon la coutume.
  local butin = math.floor((b.butin_du_camp or b.effectif * bataille.sortes[b.sorte].butin_par_tete) * issue.butin)
  if butin > 0 then
    coffre().encaisser(butin, "butin")
    local part_hommes = math.floor(butin / 2)
    local part_capitaine = 0
    local effectif = hommes().effectif()
    if effectif.par_rang.capitaine and effectif.par_rang.capitaine > 0 then
      part_capitaine = math.floor(butin / 6)
    end
    if part_hommes > 0 then coffre().payer(part_hommes, "part_hommes") end
    if part_capitaine > 0 then coffre().payer(part_capitaine, "part_capitaine") end
    resultat.butin = butin
    resultat.part_coffre = butin - part_hommes - part_capitaine
  end
  annoncer(issue.cle, { importance = "alerte" })
  if resultat.butin > 0 then
    annoncer("ui_scriptorium_bataille_butin", { complement = resultat.part_coffre .. " groschen" })
  end
  table.insert(d.resultats, resultat)
  while #d.resultats > bataille.reglages.journal_gardes do
    table.remove(d.resultats, 1)
  end
  return resultat
end

-- À la fin, les ennemis encore debout s'en vont ; les corps restent à fouiller un temps, puis le battement
-- les retire (choix de JoVenGer, 14/10).
local function finir(d, b, resultat)
  if b.personnages then
    local debout, corps = {}, {}
    for _, identifiant in ipairs(b.personnages) do
      if jeu().ennemis_vivants({ identifiant }) > 0 then
        table.insert(debout, identifiant)
      else
        table.insert(corps, identifiant)
      end
    end
    if #debout > 0 then
      jeu().renvoyer_ennemis(debout)
    end
    if #corps > 0 then
      b.corps = corps
      b.corps_retires_a = jeu().heure_du_jeu() + bataille.reglages.duree_des_corps
      jeu().coucher_les_corps(corps)
    end
    b.personnages = nil
  end
  b.etat = "finie"
  b.fin = jeu().heure_du_jeu()
  b.issue = resultat.issue
  jeu().journal("Bataille : « " .. b.id .. " » finie : " .. resultat.issue .. ", " .. #resultat.morts .. " mort(s), "
                .. #resultat.blesses .. " blessé(s), butin " .. resultat.butin)
end

-- L'issue par la règle, pour une bande au contact.
function bataille.resoudre_par_la_regle(id)
  local d = donnees()
  local b = d.bandes[id]
  if not b or b.etat ~= "au_contact" then
    return nil
  end
  local notre = bataille.force_des_notres()
  local leur = bataille.force_de_la_bande(b)
  local rapport = (leur > 0) and (notre / leur) or 10
  local issue = choisir_issue(rapport)
  local resultat = appliquer(d, b, issue, nil)
  resultat.rapport = rapport
  finir(d, b, resultat)
  enregistrer()
  return resultat
end

-- Une escarmouche loin du camp (embuscade de patrouille) : les seuls hommes donnés,
-- sans enceinte, tranchée tout de suite par la règle. Rend le résultat.
function bataille.escarmouche(ids, sorte, effectif)
  local d = donnees()
  local id = "escarmouche_" .. d.prochaine
  d.prochaine = d.prochaine + 1
  local b = { id = id, sorte = sorte, effectif = effectif, direction = 0, levee = jeu().heure_du_jeu(),
              arrivee = jeu().heure_du_jeu(), etat = "au_contact", contact = jeu().heure_du_jeu(),
              personnages = nil, combattants = {} }
  local force, moral, nombre = 0, 0, 0
  for _, homme in ipairs(ids) do
    local f = hommes().fiche(homme)
    if f and bataille.roles[f.role] and f.blessure == 0 then
      table.insert(b.combattants, homme)
      local facteur = (Scriptorium.atelier and Scriptorium.atelier.facteur_de) and Scriptorium.atelier.facteur_de(homme) or 1
      if Scriptorium.caractere then
        facteur = facteur * Scriptorium.caractere.facteur_de_combat(homme)
      end
      force = force + bataille.roles[f.role].poids * facteur
      moral = moral + f.moral
      nombre = nombre + 1
    end
  end
  if nombre > 0 then
    force = force * (0.7 + 0.5 * (moral / nombre) / 100)
  end
  local leur = bataille.force_de_la_bande(b)
  local rapport = (leur > 0) and (force / leur) or 10
  local issue = choisir_issue(rapport)
  d.bandes[id] = b
  table.insert(d.ordre, id)
  local resultat = appliquer(d, b, issue, nil)
  resultat.rapport = rapport
  b.etat = "finie"
  b.fin = jeu().heure_du_jeu()
  b.issue = resultat.issue
  enregistrer()
  return resultat
end

-- Fiche 17 : Henry est-il sur la carte de cette bande ? Une bande postée a sa carte ; les autres, celle du camp.
local function sur_la_carte_de(b)
  if b.postee then
    local ici = jeu().carte_courante and (jeu().carte_courante()) or nil
    return ici == nil or ici == b.carte
  end
  return not (camp().sur_sa_carte and not camp().sur_sa_carte())
end

-- L'écart au sol entre Henry et le lieu d'une bande postée, ou nil s'il est illisible.
local function henry_a(b)
  local henry, la = jeu().position_du_joueur(), b.point_d_arrivee
  return henry and math.sqrt((henry.x - la.x) ^ 2 + (henry.y - la.y) ^ 2) or nil
end

-- Nos hommes (fiches) à moins de « rayon » du point, et, s'il le faut, seulement les combattants valides.
local function hommes_pres_de(point, rayon, combattants_seulement)
  local liste = {}
  for _, id in ipairs(hommes().liste()) do
    local f = hommes().fiche(id)
    local ici = f and f.personnage and not jeu().personnage_mort(f.personnage) and jeu().position_du_personnage(f.personnage)
    if ici and math.sqrt((ici.x - point.x) ^ 2 + (ici.y - point.y) ^ 2) <= rayon
        and (not combattants_seulement or (bataille.roles[f.role] and f.blessure == 0)) then
      table.insert(liste, id)
    end
  end
  return liste
end

-- La bande postée passe au contact : nos combattants proches s'engagent et vont au lieu ; l'attaque est donnée.
local function engager_la_bande_postee(b)
  local r = bataille.reglages
  b.etat = "au_contact"
  b.contact = jeu().heure_du_jeu()
  b.combattants = {}
  for _, id in ipairs(hommes_pres_de(b.point_d_arrivee, r.poste_engagement_m, true)) do
    hommes().tenir(id, "bataille", { activite = "bataille", lieu = "camp_de_bandits", position = b.point_d_arrivee,
                                     cap = 0, fin = "liberation" })
    table.insert(b.combattants, id)
  end
  jeu().journal("Bataille : « " .. b.id .. " » postée, alerte : " .. #b.combattants .. " des nôtres engagé(s)")
  lancer_l_attaque_de_la_bande(b)
  lancer_l_attaque(b)
  assurer_la_relance(b.id)
end

-- La bande postée retourne à son poste avec ses survivants (Henry parti, aucun de nos combattants).
local function remettre_au_poste(b, vivants)
  liberer_les_hommes(b)
  b.etat = "postee"
  b.effectif = vivants
  b.contact = nil
  b.combattants = {}
  b.cibles, b.cibles_de_la_bande, b.relances_de = nil, nil, nil
  jeu().journal("Bataille : « " .. b.id .. " » retourne à son poste, " .. vivants .. " debout")
end

-- Le battement d'une bande postée : naître hors de la vue d'Henry, sur la carte du lieu ; puis guetter l'alerte.
-- Rend vrai si quelque chose a changé.
local function garder_le_poste(b)
  local r = bataille.reglages
  if not sur_la_carte_de(b) then
    return false
  end
  if b.personnages == nil then
    local vu = (henry_a(b) or math.huge) <= r.poste_vue_m
               and jeu().henry_voit(b.point_d_arrivee, hommes().reglages.secours_vue_cos) == true
    if vu then
      return false
    end
    local personnages = jeu().faire_venir_ennemis(b.sorte, b.effectif, b.point_d_arrivee, b.cap)
    if type(personnages) ~= "table" or #personnages == 0 then
      jeu().journal("Bataille : « " .. b.id .. " » postée : le jeu ne l'a pas fait naître")
      return false
    end
    b.personnages = personnages
    b.vivants = #personnages
    jeu().journal("Bataille : « " .. b.id .. " » postée, née : " .. #personnages .. " ennemi(s)")
    return true
  end
  local vivants = jeu().ennemis_vivants(b.personnages)
  local change = vivants ~= b.vivants
  b.vivants = vivants
  local alerte = vivants == 0 or (henry_a(b) or math.huge) <= r.poste_alerte_m
                 or #hommes_pres_de(b.point_d_arrivee, r.poste_alerte_m, false) > 0
  if alerte then
    engager_la_bande_postee(b)
    return true
  end
  return change
end

-- L'issue par le jeu : les ennemis vivants et nos morts constatés.
local function resoudre_par_le_jeu(d, b)
  local vivants = jeu().ennemis_vivants(b.personnages)
  local morts = {}
  local combattants_vivants = 0
  for _, id in ipairs(b.combattants) do
    local f = hommes().fiche(id)
    if f then
      if f.personnage and jeu().personnage_mort(f.personnage) then
        table.insert(morts, id)
      else
        combattants_vivants = combattants_vivants + 1
      end
    end
  end
  if vivants > 0 and combattants_vivants > 0 then
    return nil
  end
  -- Fiche 17 : contre une bande postée, Henry se bat seul tant qu'il reste à moins de « poste_fuite_m » ; parti sans
  -- aucun de nos combattants engagés, la bande retourne à son poste.
  if b.postee and vivants > 0 then
    if (henry_a(b) or math.huge) <= bataille.reglages.poste_fuite_m then
      return nil
    end
    if #b.combattants == 0 then
      remettre_au_poste(b, vivants)
      return nil
    end
  end
  local issue
  if vivants == 0 then
    local part = (#b.combattants > 0) and (#morts / #b.combattants) or 0
    issue = (part <= 0.1) and bataille.issues[1] or bataille.issues[2]
  else
    issue = bataille.issues[4]
  end
  local resultat = appliquer(d, b, issue, morts)
  finir(d, b, resultat)
  return resultat
end

-- ---------------------------------------------------------------- battement

function bataille.battre()
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local rapport = { annoncees = 0, arrivees = 0, finies = 0, changements = 0 }
  for _, id in ipairs(d.ordre) do
    local b = d.bandes[id]
    if b.etat == "en_marche" then
      local avance = bataille.reglages.avertissement
      if Scriptorium.enceinte and Scriptorium.enceinte.avance_de_guet then
        avance = avance + Scriptorium.enceinte.avance_de_guet()
      end
      if Scriptorium.patrouilles and Scriptorium.patrouilles.avance_de_guet then
        avance = avance + Scriptorium.patrouilles.avance_de_guet()
      end
      if not b.annoncee and heure >= b.arrivee - avance then
        b.annoncee = true
        annoncer("ui_scriptorium_bataille_approche", { importance = "alerte", complement = b.effectif .. " hommes" })
        rapport.annoncees = rapport.annoncees + 1
        rapport.changements = rapport.changements + 1
      end
      if heure >= b.arrivee then
        arriver(d, b)
        rapport.arrivees = rapport.arrivees + 1
        rapport.changements = rapport.changements + 1
        if b.personnages == nil then
          bataille.resoudre_par_la_regle(id)
          rapport.finies = rapport.finies + 1
        end
      end
    elseif b.etat == "postee" then
      if garder_le_poste(b) then
        rapport.changements = rapport.changements + 1
      end
    elseif b.etat == "au_contact" then
      local resultat = nil
      -- V73 f 3 b : une bande née sur la carte du camp ne se lit pas d'une autre carte : seule la règle, à son heure.
      if b.personnages and sur_la_carte_de(b) then
        resultat = resoudre_par_le_jeu(d, b)
        if resultat == nil and b.etat == "au_contact" then
          lancer_l_attaque_de_la_bande(b)
          lancer_l_attaque(b)
          assurer_la_relance(id)
        elseif resultat == nil then
          rapport.changements = rapport.changements + 1
        end
      end
      -- Fiche 17 : une bande postée n'est pas tranchée par la règle à l'heure (l'issue au loin vient avec la colonne,
      -- tranche 2).
      if resultat == nil and b.etat == "au_contact" and not b.postee
          and heure >= b.contact + bataille.reglages.duree_max_contact then
        resultat = bataille.resoudre_par_la_regle(id)
      end
      if resultat then
        rapport.finies = rapport.finies + 1
        rapport.changements = rapport.changements + 1
      end
    elseif b.etat == "finie" and b.corps and heure >= b.corps_retires_a then
      jeu().journal("Bataille : corps de « " .. b.id .. " » retirés (" .. #b.corps .. ")")
      jeu().renvoyer_ennemis(b.corps)
      b.corps = nil
      b.corps_retires_a = nil
      rapport.changements = rapport.changements + 1
    end
  end
  if rapport.changements > 0 then
    enregistrer()
  end
  return rapport
end

function bataille.resultats()
  local copie = {}
  for i, r in ipairs(donnees().resultats) do
    copie[i] = { bande = r.bande, sorte = r.sorte, effectif = r.effectif, issue = r.issue, morts = #r.morts,
                 blesses = #r.blesses, butin = r.butin, part_coffre = r.part_coffre, pillage = r.pillage, moment = r.moment }
  end
  return copie
end

-- Fiche 17 : une bande qui n'est pas finie est oubliée (son camp levé) : nos hommes lâchés, sans issue ni butin.
function bataille.oublier_la_bande(id)
  local d = donnees()
  local b = d.bandes[id]
  if not b or b.etat == "finie" then
    return false
  end
  liberer_les_hommes(b)
  b.etat = "finie"
  b.issue = "oubliee"
  b.fin = jeu().heure_du_jeu()
  b.personnages = nil
  enregistrer()
  jeu().journal("Bataille : « " .. id .. " » oubliée")
  return true
end

-- À l'entrée en partie (fiche 17) : les ennemis d'une bande postée sont retirés et refaits par le battement, avec ses
-- survivants comptés au dernier battement ; une bande postée au contact retourne à son poste.
function bataille.relancer()
  local d = donnees()
  local refaites = 0
  for _, id in ipairs(d.ordre) do
    local b = d.bandes[id]
    -- Tous tombés avant le chargement : rien à refaire, le battement tranchera (victoire).
    if b.postee and b.etat ~= "finie" and (b.vivants or b.effectif) > 0 then
      if b.personnages then
        jeu().renvoyer_ennemis(b.personnages)
      end
      if b.etat == "au_contact" then
        remettre_au_poste(b, b.vivants or b.effectif)
      end
      b.effectif = b.vivants or b.effectif
      b.personnages = nil
      refaites = refaites + 1
    end
  end
  if refaites > 0 then
    jeu().journal("Bataille : " .. refaites .. " bande(s) postée(s) à refaire")
    enregistrer()
  end
  return refaites
end

Scriptorium.declarer_morceau("bataille", function()
  -- Les bandes avancent par le battement du socle.
end)

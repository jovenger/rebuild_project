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
  -- Diagnostic (relecture du pair, 17/10 : le combat vivant figé trois fois) : 1 = à chaque relance (2 s), une ligne par
  -- combattant au journal : sa cible, debout ou non, la distance, en combat ou non, ses relances, sa santé.
  journal_du_combat = 0,
  -- Fiche 17 (le camp de bandits) : une bande « postée » à un lieu naît quand Henry est sur la carte du lieu et que le
  -- lieu n'est pas dans son regard à moins de « poste_vue_m » ; Henry ou un de nos hommes à moins de « poste_alerte_m »
  -- du lieu : elle attaque ; nos combattants à moins de « poste_engagement_m » s'engagent ; Henry à plus de
  -- « poste_fuite_m » sans aucun de nos combattants : elle retourne à son poste avec ses survivants.
  poste_vue_m = 300,
  poste_alerte_m = 35,
  poste_engagement_m = 80,
  poste_fuite_m = 300,
  -- Vu en jeu le 17/10 (la colonne au camp de bandits, Henry à 117 m) : le combat commence (Jan assommé), puis plus
  -- personne ne se bat, les relances épuisées ; « que personne ne reste figé » : sans aucun tombé, d'un côté ou de
  -- l'autre, depuis « poste_stagnation_h » heures du jeu, et Henry à plus de « poste_sur_place_m » du lieu (il n'y est
  -- pas), la bande postée est tranchée par passes.
  poste_stagnation_h = 0.5,
  poste_sur_place_m = 80,
  -- L'issue tranchée (règle scellée de JoVenGer « bataille_au_loin », 24/09 : « laisser le jeu en décider selon la
  -- puissance de chacun », « rien n'est écrit d'avance ») : chaque homme tombé l'est mort avec cette chance, blessé
  -- sinon.
  part_des_morts = 0.5,
  -- Relecture du pair (17/10) : tranchée, l'issue s'applique aux vrais personnages ; un blessé des nôtres est mis à terre
  -- (sa santé portée à « blesse_sante »), pas retiré ; rien ne disparaît sous les yeux d'Henry (corps et survivants d'une
  -- bande postée retirés hors de sa vue).
  blesse_sante = 5,
  -- (relecture du pair) Mis à terre, un blessé ne doit pas mourir ensuite (un saignement, un coup) : immortel
  -- « blesse_immortel_ms », comme l'homme repêché par le gardien.
  blesse_immortel_ms = 120000,
  -- (relecture du pair) Les survivants d'une bande venue au camp s'enfuient en courant, à l'opposé du camp, jusqu'à
  -- « fuite_m » ; retirés une fois hors du regard d'Henry ou à plus de « fuite_retrait_m » de lui (ceux d'une bande
  -- postée, qui restent à leur camp : hors de son regard ou à plus de « poste_vue_m »).
  fuite_m = 200,
  fuite_retrait_m = 150,
  -- La fouille (fiche 17, tranche 5) : 1 allumée ; après une victoire, au plus « fouilleurs_max » hommes vont aux corps
  -- ennemis à moins de « fouille_rayon_m » d'eux, s'y tiennent « fouille_duree_h », laissent un corps pas atteint en
  -- « fouille_marche_max_h » (heures du jeu ; une heure du jeu dure environ 4,75 minutes réelles).
  fouille = 1,
  fouilleurs_max = 3,
  fouille_rayon_m = 80,
  fouille_duree_h = 0.1,
  fouille_marche_max_h = 0.5,
  -- Vu en jeu le 17/10 : la marche s'arrête à quelque 3 m de son point ; arrivé au corps à moins de 4 m.
  fouille_pres_m = 4,
}

-- La force d'un homme selon son palier (recrue, confirmé, vétéran) : un facteur, réglable.
bataille.paliers = { palier_1 = 1, palier_2 = 1.25, palier_3 = 1.5 }

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

-- Issues, du meilleur au pire : ce qu'elles font au moral, la part du butin, et, pour le combat vu dans le jeu (où seuls
-- les morts se lisent), la part de blessés. L'issue tranchée par la règle se joue par passes (bataille.issue_au_loin) :
-- elle dit ce qui s'est passé (victoire sans perte, victoire avec pertes, repoussée : nos hommes tombés mais la moitié
-- au moins des leurs aussi, défaite), pas un barème.
bataille.issues = {
  { nom = "victoire", morts = 0, blesses = 0.15, moral = 10, butin = 1.0, cle = "ui_scriptorium_bataille_victoire" },
  { nom = "victoire_couteuse", morts = 0.10, blesses = 0.30, moral = 5, butin = 0.6, cle = "ui_scriptorium_bataille_victoire_couteuse" },
  { nom = "repoussee", morts = 0.20, blesses = 0.40, moral = -5, butin = 0.2, cle = "ui_scriptorium_bataille_repoussee" },
  { nom = "defaite", morts = 0.35, blesses = 0.40, moral = -15, butin = 0, cle = "ui_scriptorium_bataille_defaite" },
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

-- Les alertes du camp (règle scellée de Scriptorium « sentinelles_du_camp » : « l'alerte vient des gardes, pas du
-- lancement du raid » ; demande de JoVenGer du 18/10, par le pair : la voix du guetteur). Un de nos hommes occupé à une
-- des « activites » (relevée avant l'affectation à la bataille) qui voit un ennemi d'une bande née à moins de « vue_m »
-- mètres donne l'alerte, une fois par bande : il dit la réplique du jeu « metarole » (le service des paroles, fiche 20 ;
-- « le PNJ voit l'ennemi et va attaquer », AI/crime/attack/startBark.xml du jeu), le bandeau l'affiche (importance
-- « alerte »), et le déclencheur sonore du jeu « son » sonne au feu du camp (Libs/GameAudio/foleys.xml du jeu :
-- f_ge_bell_alarm, la cloche d'alarme ; f_ge_crosscountry_horn, une trompe). Personne n'a vu : rien ne s'affiche.
bataille.alerte = {
  vue_m = 80,
  activites = { garde = 1, ronde = 1, patrouille = 1 },
  metarole = "NPC_VIDI_NEPRITELE_A_BUDE_UTOCIT",
  son = "f_ge_bell_alarm",
}

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
  Scriptorium.registre.enregistrer("bataille")
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
    mobile = ordre.mobile == true or nil,
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
    -- Fiche 17 : un homme dehors (en mission, hors du monde) ne défend pas le camp.
    if role and f.blessure == 0 and not f.dehors then
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
  local tourne = Scriptorium.avis(camp(), "dans_le_monde", { x = 0, y = 0, z = 0, cap = direction }, x, y, 0)
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

-- Debout : ni mort, ni assommé (vu en jeu le 17/10 : un homme assommé restait une cible « vivante » ; les brigands
-- restaient sur lui, nos hommes visaient un brigand à terre, et le combat ne pouvait plus finir).
local function debout(personnage)
  return personnage ~= nil and jeu().ennemis_vivants({ personnage }) > 0 and jeu().personnage_inconscient(personnage) ~= true
end

local function des_notres_debout(f)
  return f ~= nil and f.personnage ~= nil and not jeu().personnage_mort(f.personnage)
    and jeu().personnage_inconscient(f.personnage) ~= true
end

-- Le personnage est-il figé (à relancer) ? Jamais s'il se bat ; il faut deux relevés de suite ; figé s'il n'a pas bougé
-- de « relance_bouge_m » et qu'il est à plus de « relance_pres_m » de sa cible (ou sans cible lisible) ; au plus
-- « relances_par_bataille » fois, puis une ligne « figé malgré … relances » avec sa position et celle de sa cible.
bataille.vus = {}

-- Fiche 19 (A13, le suivi au contact) : décision remplaçable ; « bande » est le nom de la bande. Rend vrai s'il faut le
-- relancer.
function bataille.a_relancer(bande, personnage, nom, cible)
  local b = donnees().bandes[bande]
  if not b or jeu().occupation_de(personnage) == "combat" then
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
Scriptorium.remplacable(bataille, "a_relancer", function(rendu) return type(rendu) == "boolean" end)

local function a_relancer(b, personnage, nom, cible)
  return Scriptorium.avis(bataille, "a_relancer", b.id, personnage, nom, cible)
end

local function contient(liste, valeur)
  for _, v in ipairs(liste) do
    if v == valeur then return true end
  end
  return false
end

-- Fiche 19 (A29) : cet ennemi est-il une cible valable pour nos hommes ? Par défaut, debout (ni mort ni assommé).
function bataille.ennemi_valable(bande, personnage)
  return debout(personnage)
end
Scriptorium.remplacable(bataille, "ennemi_valable", function(rendu) return type(rendu) == "boolean" end)

-- Fiche 19 (A2, A38 ; le tourniquet des cibles) : la cible d'un de nos hommes. « vivants » : les ennemis valables ;
-- « actuelle » : sa cible (ou nil) ; « rang » : le rang de la prochaine nouvelle cible au tourniquet. Par défaut, il
-- garde sa cible tant qu'elle est valable, sinon la suivante du tourniquet. Rend un personnage.
function bataille.cible_de(bande, id, vivants, actuelle, rang)
  if actuelle and contient(vivants, actuelle) then
    return actuelle
  end
  return vivants[(rang - 1) % #vivants + 1]
end
Scriptorium.remplacable(bataille, "cible_de", function(rendu) return type(rendu) == "string" end)

-- Fiche 19 : la cible d'un brigand de la bande, parmi « cibles » (nos hommes debout, et « henry » s'il est près) ; même
-- défaut que pour nos hommes.
function bataille.cible_de_la_bande(bande, personnage, cibles, actuelle, rang)
  if actuelle and contient(cibles, actuelle) then
    return actuelle
  end
  return cibles[(rang - 1) % #cibles + 1]
end
Scriptorium.remplacable(bataille, "cible_de_la_bande", function(rendu) return type(rendu) == "string" end)

-- Fiche 19 : qui vise qui dans une bataille (une copie) : { notres = { [homme] = personnage }, bande = { [brigand] =
-- personnage ou « henry » } }, ou nil.
function bataille.cibles(bande)
  local b = donnees().bandes[bande]
  if not b then
    return nil
  end
  local copie = { notres = {}, bande = {} }
  for id, c in pairs(b.cibles or {}) do copie.notres[id] = c end
  for e, c in pairs(b.cibles_de_la_bande or {}) do copie.bande[e] = c end
  return copie
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
    if Scriptorium.avis(bataille, "ennemi_valable", b.id, e) then
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
    local tombee = cible == nil or not contient(vivants, cible)
    -- Sa cible (fiche 19 : Scriptorium peut la changer à tout moment ; tombée, une nouvelle au tourniquet, sans user son
    -- crédit de relances, réservé à qui est figé).
    local nouvelle = des_notres_debout(f) and Scriptorium.avis(bataille, "cible_de", b.id, id, vivants, cible, k + 1)
    local changee = nouvelle and nouvelle ~= cible
    if des_notres_debout(f) and ((changee and (not tombee or jeu().occupation_de(f.personnage) ~= "combat"))
        or a_relancer(b, f.personnage, f.nom, cible)) then
      if changee then
        k = k + 1
        b.cibles[id] = nouvelle
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
    if des_notres_debout(f) then
      table.insert(cibles, f.personnage)
    end
  end
  local henry = jeu().position_du_joueur()
  -- La bande se repère par un ennemi vivant, sinon par son point d'arrivée.
  local premier = nil
  for _, e in ipairs(b.personnages) do
    premier = premier or (debout(e) and jeu().position_du_personnage(e)) or nil
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
    local actuelle = b.cibles_de_la_bande[e]
    local tombee = not vivantes[actuelle]
    local nouvelle = debout(e) and Scriptorium.avis(bataille, "cible_de_la_bande", b.id, e, cibles, actuelle, k + 1)
    local changee = nouvelle and nouvelle ~= actuelle
    if debout(e) and ((changee and (not tombee or jeu().occupation_de(e) ~= "combat"))
        or a_relancer(b, e, e, actuelle)) then
      if changee then
        k = k + 1
        b.cibles_de_la_bande[e] = nouvelle
      end
      jeu().journal("Bataille : « " .. e .. " » attaque « " .. b.cibles_de_la_bande[e] .. " » : "
                    .. tostring(jeu().ordonner_l_attaque(b.cibles_de_la_bande[e], e)))
      donnes = donnes + 1
    end
  end
  return donnes
end

-- Diagnostic : une ligne par combattant (les nôtres, puis la bande).
local function ligne_de_combat(nom, personnage, cible, relances)
  local ici = jeu().position_du_personnage(personnage)
  local la = cible and ((cible == "henry") and jeu().position_du_joueur() or jeu().position_du_personnage(cible))
  jeu().journal(string.format("Combat : « %s » : cible %s (%s), à %s m, %s, %d relance(s), santé %s%s", tostring(nom),
    tostring(cible), (cible == "henry" or (cible and debout(cible))) and "debout" or "à terre",
    (ici and la) and string.format("%.1f", math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2)) or "?",
    jeu().occupation_de(personnage) == "combat" and "en combat" or "hors combat", relances or 0,
    tostring(jeu().sante_de(personnage)), jeu().personnage_inconscient(personnage) == true and ", assommé" or ""))
end

local function journal_du_combat(b)
  for _, id in ipairs(b.combattants or {}) do
    local f = hommes().fiche(id)
    if f and f.personnage then
      ligne_de_combat(f.nom, f.personnage, b.cibles and b.cibles[id], b.relances_de and b.relances_de[f.personnage])
    end
  end
  for _, e in ipairs(b.personnages or {}) do
    ligne_de_combat(e, e, b.cibles_de_la_bande and b.cibles_de_la_bande[e], b.relances_de and b.relances_de[e])
  end
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
      if bataille.reglages.journal_du_combat == 1 then
        journal_du_combat(b)
      end
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
  -- Les alertes : qui guettait, relevé avant que la bataille ne prenne les hommes.
  local guetteurs = bataille.guetteurs()
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
    bataille.guetter_l_alerte(b.id, guetteurs)
    lancer_l_attaque_de_la_bande(b)
    lancer_l_attaque(b)
    assurer_la_relance(b.id)
  else
    b.personnages = nil
    jeu().journal("Bataille : « " .. b.id .. " » au contact, le jeu n'a pas fait venir la bande : la règle tranchera")
  end
end

-- Applique l'issue : morts, blessés, moral, pillage, butin. Rend le résultat.
local function appliquer(d, b, issue, morts_par_le_jeu, blesses_donnes, gagne)
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
  if blesses_donnes then
    -- Par passes : les blessés sont ceux qui sont tombés sans mourir.
    for _, blesse in ipairs(blesses_donnes) do
      table.insert(resultat.blesses, blesse)
    end
  else
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
  end
  -- L'équipement des combattants s'use.
  if Scriptorium.atelier and Scriptorium.atelier.user_apres_bataille then
    Scriptorium.atelier.user_apres_bataille(vivants)
  end
  -- Lâcher les tenues de bataille avant de toucher aux fiches.
  liberer_les_hommes(b)
  resultat.corps_des_notres = {}
  for _, id in ipairs(resultat.morts) do
    local _, corps = hommes().retirer(id, "mort")
    if corps then
      table.insert(resultat.corps_des_notres, corps)
    end
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
  -- Par passes, le butin est ce qui s'est passé : tout si la bande est tombée, rien sinon.
  local part = (gagne == nil) and issue.butin or (gagne and 1 or 0)
  local butin = math.floor((b.butin_du_camp or b.effectif * bataille.sortes[b.sorte].butin_par_tete) * part)
  if butin > 0 then
    coffre().encaisser(butin, "butin")
    -- Le partage (accroche ; la règle de Scriptorium « partage_40_60 », « part du capitaine ») : des parts entières,
    -- positives, dont la somme ne dépasse pas le butin ; sinon refusé (une ligne au journal) et tout reste au coffre.
    -- Fiche 19 : appelée par la table ; nil (pas d'avis), le partage du socle. L'argent garde sa règle stricte : une
    -- remplaçante en erreur ou absurde ne retombe pas sur le partage du socle, tout reste au coffre.
    local lu, parts = pcall(bataille.partager_le_butin, butin, b.combattants or {})
    if lu and parts == nil then
      lu, parts = pcall(Scriptorium.decision_du_socle(bataille, "partager_le_butin"), butin, b.combattants or {})
    end
    local part_hommes = lu and type(parts) == "table" and parts.hommes
    local part_capitaine = lu and type(parts) == "table" and parts.capitaine
    local function juste(n)
      return type(n) == "number" and n == n and n >= 0 and n < math.huge and math.floor(n) == n
    end
    if not (juste(part_hommes) and juste(part_capitaine) and part_hommes + part_capitaine <= butin) then
      jeu().journal("Bataille : partage du butin refusé (" .. tostring(lu and type(parts) == "table" and
        (tostring(parts.hommes) .. " / " .. tostring(parts.capitaine)) or parts) .. ") : tout reste au coffre")
      part_hommes, part_capitaine = 0, 0
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

-- Le partage du butin (accroche : la règle de Scriptorium le remplace) : la moitié aux hommes, un sixième au capitaine
-- s'il y en a un. Rend { hommes, capitaine } en groschen entiers.
function bataille.partager_le_butin(butin, combattants)
  local part_capitaine = 0
  local effectif = hommes().effectif()
  if effectif.par_rang.capitaine and effectif.par_rang.capitaine > 0 then
    part_capitaine = math.floor(butin / 6)
  end
  return { hommes = math.floor(butin / 2), capitaine = part_capitaine }
end
Scriptorium.remplacable(bataille, "partager_le_butin", function(rendu) return type(rendu) == "table" end)

-- Les personnages d'une bande (fiche 17 ; Scriptorium en ajoute et en retire : ses propres bandits à un camp) : une
-- copie ; ajouter un personnage du monde qui n'y est pas ; le retirer de la bande (pas du monde). Vrai si fait.
function bataille.personnages_de(id)
  local b = donnees().bandes[id]
  local copie = {}
  for i, p in ipairs(b and b.personnages or {}) do copie[i] = p end
  return copie
end

function bataille.ajouter_a_la_bande(id, personnage)
  local b = donnees().bandes[id]
  if not b or b.etat == "finie" or type(personnage) ~= "string" or not jeu().personnage_existe(personnage) then
    return refuser("ajout_refuse", tostring(personnage))
  end
  b.personnages = b.personnages or {}
  for _, p in ipairs(b.personnages) do
    if p == personnage then return false end
  end
  table.insert(b.personnages, personnage)
  b.effectif = b.effectif + 1
  enregistrer()
  return true
end

function bataille.retirer_de_la_bande(id, personnage)
  local b = donnees().bandes[id]
  for i, p in ipairs(b and b.personnages or {}) do
    if p == personnage then
      table.remove(b.personnages, i)
      b.effectif = math.max(0, b.effectif - 1)
      enregistrer()
      return true
    end
  end
  return false
end

-- Trancher une bande par passes (bataille.issue_au_loin) contre ces combattants : morts ou blessés selon
-- « part_des_morts », puis l'issue qui dit ce qui s'est passé. Rend le résultat d'« appliquer », avec les passes.
local function trancher_par_passes(d, b, combattants, bonus)
  local r = Scriptorium.avis(bataille, "issue_au_loin", combattants, b.sorte, b.effectif, bonus)
  local morts, blesses = {}, {}
  for _, id in ipairs(r.tombes) do
    if tirage(d) < bataille.reglages.part_des_morts then
      table.insert(morts, id)
    else
      table.insert(blesses, { id = id, jours = 2 + math.floor(tirage(d) * 4) })
    end
  end
  local issue
  if r.gagne then
    issue = (#r.tombes == 0) and bataille.issues[1] or bataille.issues[2]
  else
    issue = (r.eux_tombes * 2 >= b.effectif) and bataille.issues[3] or bataille.issues[4]
  end
  -- Les vrais personnages (relecture du pair) : leurs tombés tués, nos morts tués, nos blessés mis à terre.
  local a_tuer = r.eux_tombes
  for _, e in ipairs(b.personnages or {}) do
    if a_tuer > 0 and jeu().ennemis_vivants({ e }) > 0 then
      jeu().blesser(e, 1000)
      a_tuer = a_tuer - 1
    end
  end
  for _, id in ipairs(morts) do
    local f = hommes().fiche(id)
    if f and f.personnage then
      jeu().blesser(f.personnage, 1000)
    end
  end
  for _, blesse in ipairs(blesses) do
    local f = hommes().fiche(blesse.id)
    if f and f.personnage then
      local personnage = f.personnage
      jeu().mettre_a_terre(personnage, bataille.reglages.blesse_sante)
      local effet = jeu().rendre_immortel(personnage)
      if effet ~= nil then
        jeu().minuterie(bataille.reglages.blesse_immortel_ms, function()
          jeu().retirer_l_effet(personnage, effet)
        end)
      end
    end
  end
  b.combattants = combattants
  local resultat = appliquer(d, b, issue, morts, blesses, r.gagne)
  resultat.passes, resultat.eux_tombes = r.passes, r.eux_tombes
  return resultat
end

-- À la fin, les ennemis encore debout s'en vont ; les corps restent à fouiller un temps, puis le battement
-- les retire (choix de JoVenGer, 14/10).
-- Fiche 19 (A40) : que faire des survivants d'une bande à la fin de sa bataille ? « fuite » (ils partent en courant,
-- retirés hors de la vue d'Henry), « rester » (debout, retirés hors de la vue), « laisser » (le socle ne les touche plus :
-- Scriptorium les prend, ses prisonniers). Par défaut, « rester » pour une bande postée, sinon « fuite ».
bataille.sorts_des_survivants = { fuite = true, rester = true, laisser = true }

function bataille.sort_des_survivants(bande, survivants)
  local b = donnees().bandes[bande]
  return (b and b.postee) and "rester" or "fuite"
end
Scriptorium.remplacable(bataille, "sort_des_survivants", function(rendu) return bataille.sorts_des_survivants[rendu] == true end)

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
    local sort = #debout > 0 and Scriptorium.avis(bataille, "sort_des_survivants", b.id, debout) or nil
    if sort == "laisser" then
      jeu().journal("Bataille : « " .. b.id .. " » : " .. #debout .. " survivant(s) laissé(s) à Scriptorium")
    elseif sort == "rester" then
      -- Fiche 17 : les survivants d'une bande postée restent debout ; retirés hors de la vue d'Henry (le battement).
      b.partants = debout
    elseif sort == "fuite" then
      -- (relecture du pair) Ils partent aussitôt (choix de JoVenGer du 14/10), en courant, à l'opposé du camp ; rien ne
      -- disparaît sous les yeux d'Henry : retirés plus tard par le battement.
      local centre = camp().point(0, 0, 0)
      for _, e in ipairs(debout) do
        local ici = jeu().position_du_personnage(e) or b.point_d_arrivee
        local dx, dy = 0, 1
        if ici and centre then
          dx, dy = ici.x - centre.x, ici.y - centre.y
        end
        local longueur = math.sqrt(dx * dx + dy * dy)
        if longueur < 0.1 then
          dx, dy, longueur = math.sin(math.rad(b.direction or 0)), math.cos(math.rad(b.direction or 0)), 1
        end
        local base = ici or { x = 0, y = 0, z = 0 }
        local m = bataille.reglages.fuite_m / longueur
        local point = { x = base.x + dx * m, y = base.y + dy * m, z = base.z }
        local plus_loin = { x = base.x + dx * m * 2, y = base.y + dy * m * 2, z = base.z }
        jeu().ordonner(e, "fuite", point, "fuite", nil, nil, plus_loin, "course")
      end
      b.partants = debout
    end
    if #corps > 0 then
      b.corps = corps
      b.corps_retires_a = jeu().heure_du_jeu() + bataille.reglages.duree_des_corps
      jeu().coucher_les_corps(corps)
      b.corps_ennemis = {}
      for i, c in ipairs(corps) do b.corps_ennemis[i] = c end
    end
    b.personnages = nil
  end
  -- Nos morts restent à terre (relecture du pair), couchés, et partent avec les corps de la bande.
  local nos_corps = resultat.corps_des_notres or {}
  if #nos_corps > 0 then
    jeu().coucher_les_corps(nos_corps)
    b.corps = b.corps or {}
    for _, c in ipairs(nos_corps) do
      table.insert(b.corps, c)
    end
    b.corps_retires_a = b.corps_retires_a or (jeu().heure_du_jeu() + bataille.reglages.duree_des_corps)
  end
  b.etat = "finie"
  b.fin = jeu().heure_du_jeu()
  b.issue = resultat.issue
  jeu().journal("Bataille : « " .. b.id .. " » finie : " .. resultat.issue .. ", " .. #resultat.morts .. " mort(s), "
                .. #resultat.blesses .. " blessé(s), butin " .. resultat.butin)
  -- La fouille après une victoire (fiche 17, tranche 5).
  if bataille.reglages.fouille == 1 and (resultat.issue == "victoire" or resultat.issue == "victoire_couteuse")
      and b.corps_ennemis and #b.corps_ennemis > 0 then
    bataille.lancer_la_fouille(b.id)
  end
end

-- ---------------------------------------------------------------- la fouille (fiche 17, tranche 5)

-- Accroche : cet homme peut-il fouiller les corps de cette bande ? (Scriptorium l'enveloppe : les bains…) Par défaut,
-- un combattant debout, valide, libre pour la fouille, pas dehors.
function bataille.peut_fouiller(id, bande)
  local f = hommes().fiche(id)
  return f ~= nil and bataille.roles[f.role] ~= nil and f.blessure == 0 and not f.dehors and des_notres_debout(f)
    and Scriptorium.avis(hommes(), "libre_pour", id, "fouille")
end
Scriptorium.remplacable(bataille, "peut_fouiller", function(rendu) return type(rendu) == "boolean" end)

-- Accroche : la fouille d'une bande est finie (une fois). Par défaut, une ligne au journal.
function bataille.fouille_finie(id, fouille)
  jeu().journal("Bataille : fouille de « " .. id .. " » finie, " .. #fouille.vus .. " corps fouillé(s), "
                .. fouille.laisses .. " laissé(s)")
end

-- Lance la fouille des corps ennemis d'une bande finie. Vrai si lancée.
function bataille.lancer_la_fouille(id)
  local b = donnees().bandes[id]
  if not b or b.etat ~= "finie" or not b.corps_ennemis or #b.corps_ennemis == 0 or b.fouille then
    return false
  end
  b.fouille = { a_fouiller = {}, vus = {}, fouilleurs = {}, laisses = 0, debut = jeu().heure_du_jeu() }
  for i, c in ipairs(b.corps_ennemis) do b.fouille.a_fouiller[i] = c end
  enregistrer()
  jeu().journal("Bataille : fouille de « " .. id .. " » : " .. #b.corps_ennemis .. " corps")
  return true
end

-- La fouille d'une bande : une copie (les corps à fouiller, les vus, les fouilleurs et leur corps), ou nil.
function bataille.fouille(id)
  local b = donnees().bandes[id]
  if not b or not b.fouille then
    return nil
  end
  local f = b.fouille
  local copie = { a_fouiller = {}, vus = {}, fouilleurs = {}, laisses = f.laisses }
  for i, c in ipairs(f.a_fouiller) do copie.a_fouiller[i] = c end
  for i, c in ipairs(f.vus) do copie.vus[i] = c end
  for h, a in pairs(f.fouilleurs) do copie.fouilleurs[h] = a.corps end
  return copie
end

-- Vider la fouille (le portage des corps, les sentinelles) : les fouilleurs lâchés, la fouille close. Vrai si faite.
function bataille.vider_la_fouille(id)
  local b = donnees().bandes[id]
  if not b or not b.fouille then
    return false
  end
  for h in pairs(b.fouille.fouilleurs) do
    if hommes().fiche(h) then hommes().lacher(h, "fouille") end
  end
  b.fouille = nil
  enregistrer()
  jeu().journal("Bataille : fouille de « " .. id .. " » vidée")
  return true
end

-- Un battement de la fouille : les fouilleurs arrivés s'y tiennent, puis passent au suivant ; un corps pas atteint à
-- temps est laissé ; les corps libres reçoivent le fouilleur le plus proche. Rend vrai si quelque chose a changé.
local function avancer_la_fouille(b, heure)
  local f, r = b.fouille, bataille.reglages
  local change = false
  for h, a in pairs(f.fouilleurs) do
    local fiche = hommes().fiche(h)
    local ici = fiche and fiche.personnage and jeu().position_du_personnage(fiche.personnage)
    local la = jeu().position_du_personnage(a.corps)
    local fini = false
    if not fiche or hommes().qui_tient(h) ~= "fouille" then
      fini = true   -- pris par plus fort (une bataille, les soins) : le corps redevient libre
    elseif ici and la and math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2) <= r.fouille_pres_m then
      a.arrive = a.arrive or heure
      if heure >= a.arrive + r.fouille_duree_h then
        table.insert(f.vus, a.corps)
        fini = true
      end
    elseif heure >= a.depuis + r.fouille_marche_max_h then
      table.insert(f.vus, a.corps)
      f.laisses = f.laisses + 1
      jeu().journal("Bataille : « " .. tostring(fiche.nom) .. " » n'atteint pas le corps « " .. a.corps .. " » : laissé")
      fini = true
    end
    if fini then
      f.fouilleurs[h] = nil
      if fiche then hommes().lacher(h, "fouille") end
      change = true
    end
  end
  local occupes, nombre = {}, 0
  for h, a in pairs(f.fouilleurs) do
    occupes[a.corps] = true
    nombre = nombre + 1
  end
  for _, c in ipairs(f.a_fouiller) do
    if nombre >= r.fouilleurs_max then break end
    local la = jeu().position_du_personnage(c)
    if not contient(f.vus, c) and not occupes[c] and la then
      local choisi, plus_pres = nil, nil
      for _, h in ipairs(hommes().liste()) do
        local fiche = hommes().fiche(h)
        local ici = fiche.personnage and jeu().position_du_personnage(fiche.personnage)
        local ecart = ici and math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2)
        if not f.fouilleurs[h] and ecart and ecart <= r.fouille_rayon_m and (plus_pres == nil or ecart < plus_pres) then
          local lu, peut = pcall(Scriptorium.avis, bataille, "peut_fouiller", h, b.id)
          if lu and peut == true then
            choisi, plus_pres = h, ecart
          end
        end
      end
      if choisi then
        hommes().tenir(choisi, "fouille", { activite = "fouille", lieu = "corps", position = { x = la.x, y = la.y, z = la.z },
          fin = "liberation" })
        f.fouilleurs[choisi] = { corps = c, depuis = heure }
        occupes[c] = true
        nombre = nombre + 1
        change = true
      end
    end
  end
  if next(f.fouilleurs) == nil then
    local reste = false
    for _, c in ipairs(f.a_fouiller) do
      if not contient(f.vus, c) and jeu().position_du_personnage(c) then reste = true end
    end
    if not reste or (#f.vus == 0 and heure >= f.debut + r.fouille_marche_max_h) then
      local copie = bataille.fouille(b.id)
      b.fouille = nil
      local lu, erreur = pcall(bataille.fouille_finie, b.id, copie)
      if not lu then
        jeu().journal("Bataille : accroche « fouille finie » en erreur : " .. tostring(erreur))
      end
      change = true
    end
  end
  return change
end

-- L'issue par la règle, pour une bande au contact.
function bataille.resoudre_par_la_regle(id)
  local d = donnees()
  local b = d.bandes[id]
  if not b or b.etat ~= "au_contact" then
    return nil
  end
  local combattants = {}
  for _, h in ipairs(b.combattants or {}) do
    if Scriptorium.avis(bataille, "force_d_un_homme", h) > 0 then table.insert(combattants, h) end
  end
  local bonus = (Scriptorium.enceinte and Scriptorium.enceinte.bonus) and Scriptorium.enceinte.bonus() or 1
  local resultat = trancher_par_passes(d, b, combattants, bonus)
  finir(d, b, resultat)
  enregistrer()
  return resultat
end

-- Une escarmouche loin du camp (embuscade de patrouille) : les seuls hommes donnés,
-- sans enceinte, tranchée tout de suite par la règle. Rend le résultat.
-- La force d'un homme (accroche : Scriptorium y met l'expérience de l'homme) : le poids de son rôle, son palier, son
-- équipement (l'usure), son caractère (aguerrissement, courage, sang-froid, fatigue) et son moral ; 0 s'il ne combat
-- pas (rôle hors combat, blessé). Le sang-froid y entre par le moral (une perte de moral amortie, fiche 11).
function bataille.force_d_un_homme(id)
  local f = hommes().fiche(id)
  local role = f and bataille.roles[f.role]
  if not role or f.blessure > 0 then
    return 0
  end
  local facteur = bataille.paliers["palier_" .. tostring(f.palier or 1)] or 1
  if Scriptorium.atelier and Scriptorium.atelier.facteur_de then
    facteur = facteur * Scriptorium.atelier.facteur_de(id)
  end
  if Scriptorium.caractere then
    facteur = facteur * Scriptorium.caractere.facteur_de_combat(id)
  end
  return role.poids * facteur * (0.7 + 0.5 * f.moral / 100)
end
Scriptorium.remplacable(bataille, "force_d_un_homme", function(rendu) return type(rendu) == "number" and rendu >= 0 and rendu < math.huge end)

-- La force d'une liste d'hommes (une patrouille, une colonne), et ceux qui combattent : les rôles de combat, valides.
function bataille.force_de(ids)
  local combattants = {}
  local force = 0
  for _, homme in ipairs(ids) do
    local sienne = Scriptorium.avis(bataille, "force_d_un_homme", homme)
    if sienne > 0 then
      table.insert(combattants, homme)
      force = force + sienne
    end
  end
  return force, combattants
end

-- L'issue tranchée, par passes (accroche ; règle scellée de JoVenGer « bataille_au_loin », méthode de Scriptorium) : à
-- chaque passe, un camp perd un homme, tiré au sort avec une chance de tomber qui suit le rapport des forces encore
-- debout ; nos hommes tombent dans leur ordre de chute (le rang avant, puis le moindre jugement, fiche 11) ; la fin quand
-- un camp n'a plus personne debout. « bonus » : celui de l'enceinte, au camp. Rend { gagne, tombes (nos hommes, dans
-- l'ordre), debout, eux_tombes, eux_debout, passes }.
function bataille.issue_au_loin(nous, sorte, effectif, bonus)
  local debout = {}
  for i, id in ipairs(nous) do debout[i] = id end
  if Scriptorium.caractere then
    debout = Scriptorium.caractere.ordre_de_chute(debout)
  end
  local force_de_chacun = {}
  for _, id in ipairs(debout) do
    force_de_chacun[id] = Scriptorium.avis(bataille, "force_d_un_homme", id) * (bonus or 1)
  end
  local poids = bataille.sortes[sorte] and bataille.sortes[sorte].poids or 1
  local eux, tombes, passes = effectif, {}, 0
  while #debout > 0 and eux > 0 do
    passes = passes + 1
    local notre = 0
    for _, id in ipairs(debout) do
      notre = notre + force_de_chacun[id]
    end
    local leur = eux * poids
    if bataille.tirage() < leur / (notre + leur) then
      table.insert(tombes, table.remove(debout, 1))
    else
      eux = eux - 1
    end
  end
  return { gagne = eux == 0 and #debout > 0, tombes = tombes, debout = debout, eux_tombes = effectif - eux,
           eux_debout = eux, passes = passes }
end
Scriptorium.remplacable(bataille, "issue_au_loin", function(rendu) return type(rendu) == "table" end)

function bataille.escarmouche(ids, sorte, effectif)
  local d = donnees()
  local id = "escarmouche_" .. d.prochaine
  d.prochaine = d.prochaine + 1
  local b = { id = id, sorte = sorte, effectif = effectif, direction = 0, levee = jeu().heure_du_jeu(),
              arrivee = jeu().heure_du_jeu(), etat = "au_contact", contact = jeu().heure_du_jeu(),
              personnages = nil, combattants = {} }
  local _, combattants = bataille.force_de(ids)
  d.bandes[id] = b
  table.insert(d.ordre, id)
  local resultat = trancher_par_passes(d, b, combattants, 1)
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
    -- Sans point (vu en jeu le 17/10) : un ordre « marche au point » redonné en plein combat (après le retrait du cheval)
    -- écrasait l'ordre d'attaque, et Jan, Ondřej et un brigand restaient figés ; la tenue ne fait que les tenir, l'ordre
    -- d'attaque reste le seul.
    hommes().tenir(id, "bataille", { activite = "bataille", lieu = "camp_de_bandits", fin = "liberation" })
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
    -- Une bande qui bouge (un convoi, fiche 17) n'existe dans le monde qu'à moins de « poste_vue_m » d'Henry : plus loin,
    -- elle avance par le calcul.
    local trop_loin = b.mobile and (henry_a(b) or math.huge) > r.poste_vue_m
    if vu or trop_loin then
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

-- Fiche 17, 4 b : l'issue au loin d'une bande postée contre une colonne (Henry à plus de « henry_loin_m ») : la force de
-- ces hommes contre celle de la bande (ses ennemis encore debout s'ils sont nés), par la règle. Rend le résultat, ou nil.
function bataille.trancher_la_bande_postee(id, ids)
  local d = donnees()
  local b = d.bandes[id]
  if not b or not b.postee or b.etat == "finie" then
    return nil
  end
  if b.personnages then
    b.effectif = jeu().ennemis_vivants(b.personnages)
  end
  local _, combattants = bataille.force_de(ids)
  b.contact = b.contact or jeu().heure_du_jeu()
  local resultat = trancher_par_passes(d, b, combattants, 1)
  finir(d, b, resultat)
  enregistrer()
  jeu().journal(string.format("Bataille : « %s » tranchée au loin en %d passes, %d des leurs tombés", id, resultat.passes,
    resultat.eux_tombes))
  return resultat
end

-- Henry voit-il le lieu d'une bande ? Dans son regard et à moins de « poste_vue_m ».
local function sous_les_yeux(b)
  return (henry_a(b) or math.huge) <= bataille.reglages.poste_vue_m
    and jeu().henry_voit(b.point_d_arrivee, hommes().reglages.secours_vue_cos) == true
end

-- Les survivants à retirer : hors du regard d'Henry, ou plus loin de lui que « fuite_retrait_m » (« poste_vue_m » pour
-- une bande postée, qui reste à son camp), ou sans position lisible. Henry illisible : personne (rien ne disparaît sur
-- une lecture manquée).
local function partants_hors_de_vue(b)
  local henry = jeu().position_du_joueur()
  local loin = b.postee and bataille.reglages.poste_vue_m or bataille.reglages.fuite_retrait_m
  local liste = {}
  if not henry then
    return liste
  end
  for _, e in ipairs(b.partants or {}) do
    local ici = jeu().position_du_personnage(e)
    if not ici or math.sqrt((ici.x - henry.x) ^ 2 + (ici.y - henry.y) ^ 2) > loin
        or jeu().henry_voit(ici, hommes().reglages.secours_vue_cos) ~= true then
      table.insert(liste, e)
    end
  end
  return liste
end

-- Une bande postée au contact, figée (aucun tombé depuis « poste_stagnation_h ») et Henry pas sur place : tranchée par
-- passes contre nos combattants encore debout. Rend le résultat, ou nil.
local function trancher_si_fige(d, b, heure)
  local r = bataille.reglages
  local leurs = 0
  for _, e in ipairs(b.personnages) do
    if debout(e) then leurs = leurs + 1 end
  end
  local notres = {}
  for _, id in ipairs(b.combattants or {}) do
    if des_notres_debout(hommes().fiche(id)) then table.insert(notres, id) end
  end
  local compte = leurs .. "/" .. #notres
  if b.compte_vu ~= compte then
    b.compte_vu, b.progres = compte, heure
    return nil
  end
  if heure < (b.progres or heure) + r.poste_stagnation_h or (henry_a(b) or math.huge) <= r.poste_sur_place_m then
    return nil
  end
  b.effectif = leurs
  local resultat = trancher_par_passes(d, b, notres, 1)
  finir(d, b, resultat)
  jeu().journal(string.format("Bataille : « %s » figée sans Henry depuis %.2f h : tranchée par passes (%d passes)", b.id,
    heure - b.progres, resultat.passes))
  return resultat
end

-- L'issue par le jeu : les ennemis vivants et nos morts constatés.
local function resoudre_par_le_jeu(d, b)
  local vivants = 0
  for _, e in ipairs(b.personnages) do
    if debout(e) then vivants = vivants + 1 end
  end
  local morts, assommes = {}, {}
  local combattants_vivants = 0
  for _, id in ipairs(b.combattants) do
    local f = hommes().fiche(id)
    if f then
      if f.personnage and jeu().personnage_mort(f.personnage) then
        table.insert(morts, id)
      elseif des_notres_debout(f) then
        combattants_vivants = combattants_vivants + 1
      else
        table.insert(assommes, { id = id, jours = 2 + math.floor(tirage(d) * 4) })
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
    issue = (#morts + #assommes == 0) and bataille.issues[1] or bataille.issues[2]
  else
    issue = bataille.issues[4]
  end
  -- Ce qui s'est passé (règle « bataille_au_loin ») : nos morts sont ceux du jeu, nos blessés ses assommés.
  local resultat = appliquer(d, b, issue, morts, assommes, vivants == 0)
  finir(d, b, resultat)
  return resultat
end

-- ---------------------------------------------------------------- les alertes

-- Nos hommes occupés maintenant à une des activités de guet (bataille.alerte.activites). Rend leurs identifiants.
function bataille.guetteurs()
  local liste = {}
  local heure = jeu().heure_du_jeu()
  for _, id in ipairs(hommes().liste()) do
    local a = hommes().activite_de(id, heure)
    if a and (tonumber(bataille.alerte.activites[a.activite]) or 0) > 0 then
      table.insert(liste, id)
    end
  end
  return liste
end

-- Décision remplaçable (fiche 19) : qui voit la bande « id » ? Parmi « guetteurs » (sinon ceux qui guettent maintenant),
-- vivants, le plus proche d'un ennemi debout à moins de bataille.alerte.vue_m mètres. Rend son identifiant, ou false.
function bataille.qui_voit(id, guetteurs)
  local b = donnees().bandes[id]
  if not (b and type(b.personnages) == "table") then
    return false
  end
  local ennemis = {}
  for _, e in ipairs(b.personnages) do
    local la = not jeu().personnage_mort(e) and jeu().position_du_personnage(e)
    if la then
      table.insert(ennemis, la)
    end
  end
  local meilleur, plus_pres = false, nil
  for _, hid in ipairs(guetteurs or bataille.guetteurs()) do
    local f = hommes().fiche(hid)
    local ici = f and f.personnage and not jeu().personnage_mort(f.personnage) and jeu().position_du_personnage(f.personnage)
    if ici then
      for _, la in ipairs(ennemis) do
        local d = math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2)
        if d <= bataille.alerte.vue_m and (plus_pres == nil or d < plus_pres) then
          meilleur, plus_pres = hid, d
        end
      end
    end
  end
  return meilleur
end
Scriptorium.remplacable(bataille, "qui_voit", function(rendu)
  return rendu == false or (hommes().fiche(rendu) ~= nil)
end)

-- Si un guetteur voit la bande et que l'alerte n'est pas encore donnée : il la donne (la réplique, le bandeau, le son).
-- Rend l'identifiant de celui qui l'a donnée, ou nil.
function bataille.guetter_l_alerte(id, guetteurs)
  local b = donnees().bandes[id]
  if not b or b.alerte_donnee then
    return nil
  end
  local qui = Scriptorium.avis(bataille, "qui_voit", id, guetteurs)
  if not qui then
    return nil
  end
  b.alerte_donnee = true
  local a, f = bataille.alerte, hommes().fiche(qui)
  local dit = hommes().dire_une_replique(qui, { metarole = a.metarole })
  annoncer("ui_scriptorium_bataille_alerte", { importance = "alerte", complement = f.nom })
  local ou = camp().est_fonde() and camp().objet_de("feu_central") or f.personnage
  local sonne, raison = false, "pas de son"
  if jeu().jouer_un_son then
    sonne, raison = jeu().jouer_un_son(a.son, ou)
  end
  jeu().journal("Bataille : alerte de « " .. b.id .. " » donnée par « " .. f.nom .. " » ; réplique = " .. tostring(dit)
                .. ", son « " .. tostring(a.son) .. " » = " .. tostring(sonne or raison))
  return qui
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
        -- Silencieuse (règle « sentinelles_du_camp ») : personne ne l'a vue ; l'alerte viendra d'un guetteur.
        annoncer("ui_scriptorium_bataille_approche", { importance = "journal", complement = b.effectif .. " hommes" })
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
      bataille.guetter_l_alerte(id)
    elseif b.etat == "au_contact" then
      bataille.guetter_l_alerte(id)
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
      -- Fiche 17 : une bande postée n'est pas tranchée par la règle à l'heure ; seulement figée sans Henry (ci-dessous).
      if resultat == nil and b.etat == "au_contact" and b.postee and b.personnages then
        resultat = trancher_si_fige(d, b, heure)
      end
      if resultat == nil and b.etat == "au_contact" and not b.postee
          and heure >= b.contact + bataille.reglages.duree_max_contact then
        resultat = bataille.resoudre_par_la_regle(id)
      end
      if resultat then
        rapport.finies = rapport.finies + 1
        rapport.changements = rapport.changements + 1
      end
    elseif b.etat == "finie" and b.partants and #partants_hors_de_vue(b) > 0 then
      local partis = partants_hors_de_vue(b)
      jeu().journal("Bataille : « " .. b.id .. " » : " .. #partis .. " survivant(s) retiré(s), hors de la vue d'Henry")
      jeu().renvoyer_ennemis(partis)
      local restent = {}
      for _, e in ipairs(b.partants) do
        local parti = false
        for _, p in ipairs(partis) do
          if p == e then parti = true end
        end
        if not parti then table.insert(restent, e) end
      end
      b.partants = (#restent > 0) and restent or nil
      rapport.changements = rapport.changements + 1
    elseif b.etat == "finie" and b.corps and heure >= b.corps_retires_a and not (b.postee and sous_les_yeux(b)) then
      if b.fouille then
        bataille.vider_la_fouille(b.id)
      end
      jeu().journal("Bataille : corps de « " .. b.id .. " » retirés (" .. #b.corps .. ")")
      jeu().renvoyer_ennemis(b.corps)
      b.corps = nil
      b.corps_retires_a = nil
      rapport.changements = rapport.changements + 1
    end
    if b.etat == "finie" and b.fouille and avancer_la_fouille(b, heure) then
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

-- Fiche 17, tranche 4 (le convoi) : le point d'une bande postée avance ; née, ses hommes debout y marchent (l'ordre de
-- poste, vers « regard »), redonné seulement quand le point a bougé de plus de 5 m. Vrai si fait.
function bataille.deplacer_la_bande(id, position, regard)
  local b = donnees().bandes[id]
  if not b or not b.postee or b.etat ~= "postee" or type(position) ~= "table" then
    return false
  end
  b.point_d_arrivee = { x = position.x, y = position.y, z = position.z }
  local avant = b.point_ordonne
  if b.personnages and (not avant or math.sqrt((avant.x - position.x) ^ 2 + (avant.y - position.y) ^ 2) > 5) then
    for i, e in ipairs(b.personnages) do
      if debout(e) then
        local place = { x = position.x + ((i - 1) % 3) * 1.5, y = position.y - math.floor((i - 1) / 3) * 1.5, z = position.z }
        jeu().ordonner(e, "convoi", place, "convoi", nil, nil, regard or position, nil)
      end
    end
    b.point_ordonne = { x = position.x, y = position.y }
  end
  return true
end

-- Une bande postée retirée du monde (ses hommes debout comptés, pour renaître ailleurs) : jamais sous les yeux d'Henry.
-- Vrai si fait.
function bataille.retirer_la_bande_du_monde(id)
  local b = donnees().bandes[id]
  if not b or not b.postee or b.etat ~= "postee" or not b.personnages or sous_les_yeux(b) then
    return false
  end
  local reste = 0
  for _, e in ipairs(b.personnages) do
    if debout(e) then reste = reste + 1 end
  end
  jeu().renvoyer_ennemis(b.personnages)
  b.effectif = reste
  b.personnages = nil
  b.point_ordonne = nil
  enregistrer()
  jeu().journal("Bataille : « " .. id .. " » retirée du monde, hors de la vue d'Henry (" .. reste .. " debout)")
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

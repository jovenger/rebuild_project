-- Les hommes au camp : fiches, contrats, solde, vivres, moral, journée, garde, départs.
-- Fiche de comportement : docs/socle/fiches/04_hommes.md

local Scriptorium = Scriptorium

local hommes = {}
Scriptorium.hommes = hommes

hommes.reglages = {
  moral_depart = 60,
  ecart_entre_hommes = 1.2,   -- autour d'un point d'activité, mètres entre deux places (JoVenGer, 16/10, après V72 c)
  -- Le secours de l'homme bloqué (fiche 15, réponse 1 de JoVenGer du 16/10) : s'il ne s'est pas rapproché d'au moins
  -- « secours_progres_m » pendant « secours_delai_s », il est posé près de son but ; au plus « secours_max » fois par
  -- ordre ; « secours_arrivee_m » : arrivé.
  -- V73 a : le jeu arrête une marche entre 1,5 et 2,5 m du but ; « arrivé » doit le dépasser. « secours_assis_m » : un
  -- homme encore à moins de tant de mètres de sa place d'avant (assis, couché) n'est jamais posé d'un coup (poser un
  -- homme assis le fait se lever à son banc, sans le déplacer).
  secours_delai_s = 30,
  secours_progres_m = 1,
  secours_arrivee_m = 3,
  secours_max = 2,
  secours_assis_m = 1.5,
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
  -- Le factionnaire (fiche 15, V73 d 1) : il se tient face à un point de regard, à tant de mètres devant son poste.
  regard_m = 10,
  anciens_gardes = 50,
  semaines_min = 1,
  semaines_max = 52,
  palier_par_defaut = 1,      -- palier d'embauche quand le contrat n'en donne pas : 1 recrue, 2 confirmé, 3 vétéran
  -- L'arbitre (fiche 15, V73 b 3) : une tenue « jusqu'à libération » (bataille, patrouille) tombe par sûreté au bout de
  -- tant d'heures du jeu, notée au journal (réponse 2 a de JoVenGer) ; la journée du socle tient l'homme qu'aucune règle
  -- ne tient (réponse 3 a) : à faux, il attend où il est (Scriptorium la coupera à la bascule).
  tenue_max_h = 24,
  journee_du_socle = true,
  -- La garde de la tenue (fiche 13, après V73 b, réponses a et a de JoVenGer du 16/10) : tant d'hommes par battement, en
  -- tournant, remettent leurs propres pièces (le moteur leur ôte parfois leur tenue en pleine partie).
  tenue_garde_par_battement = 1,
}

-- L'arbitre des ordres (fiche 15, V73 b 3) : le rang de chaque règle, du plus fort (1) au plus faible. Ordre validé par
-- JoVenGer le 16/10 (bataille, rassemblement, soins et bains, garde et ronde, travail, repas et sommeil, loisir) ; la
-- patrouille au rang de la garde, la corvée de punition au rang du travail (réponse 1 a du V73 b). La journée du socle
-- vient après toutes. Une règle absente de cette table ne tient personne.
hommes.priorites = {
  bataille = 1,
  rassemblement = 2,
  soins = 3,
  bains = 3,
  garde = 4,
  garde_de_nuit = 4,
  ronde = 4,
  patrouille = 4,
  travail = 5,
  punition = 5,
  repas = 6,
  sommeil = 6,
  loisir = 7,
}

-- Fiche 12 (les valeurs de l'arbre en données, règle de JoVenGer du 14/10) : les valeurs du comportement long et du
-- switch, en entiers, écrites dans le cerveau de chaque homme et du Directeur (variables scriptorium_cerveau_<nom>) au
-- premier battement après le réveil, à la naissance et à chaque changement. Tant que rien n'est écrit (zéro), l'arbre
-- prend ces mêmes valeurs par défaut, recopiées dans l'arbre et comparées au banc ; zéro vaut donc « par défaut ».
hommes.cerveau = {
  garde_ms = 500,             -- la garde relit l'ordre et fait battre le pouls
  tour_ms = 2000,             -- un tour du switch
  sortie_ms = 2000,           -- après une posture, le temps laissé au jeu pour jouer la sortie
  relance_tours = 3,          -- pouls figé tant de tours, le comportement en marche : relancé
  file_tours = 30,            -- lancé, jamais commencé depuis tant de tours : relancé
  marche_delai_ms = 30000,    -- une marche abandonnée au-delà
  marche_arret_cm = 200,      -- une marche s'arrête à tant du but, plus ou moins l'écart
  marche_ecart_cm = 50,
  siege_arret_cm = 10,        -- l'approche d'un siège (posture « sitting »)
  siege_ecart_cm = 5,
  lit_arret_cm = 50,          -- l'approche d'un lit (posture « lying »)
  lit_ecart_cm = 5,
  -- Le factionnaire (fiche 15, V73 d 1, réponses a et a de JoVenGer du 16/10) : l'arrêt au poste, court comme celui du
  -- siège ; le jour, un geste « regarder autour » toutes les « poste_geste_ms », plus ou moins « poste_geste_ecart_ms »
  -- tirés au hasard par le jeu (les gardes ne bougent pas tous ensemble).
  poste_arret_cm = 50,
  poste_ecart_cm = 10,
  poste_geste_ms = 60000,
  poste_geste_ecart_ms = 30000,
  -- Le plafond de relances (fiche 15, V73 b 2, proposition du pair) : au plus « relances_max » lancements de la vie du
  -- camp par fenêtre de « relances_fenetre_ms » ; au-delà, plus aucun pendant une fenêtre entière, et une ligne au journal.
  relances_max = 3,
  relances_fenetre_ms = 60000,
}

-- Rôles, solde hebdomadaire de base en groschen, et réserve d'âmes où l'homme prend la sienne (fiche 13 : combattants
-- par palier, gens de métier).
hommes.roles = {
  homme_d_armes = { solde = 12, reserve = "combattant" },
  arbaletrier   = { solde = 14, reserve = "combattant" },
  archer        = { solde = 12, reserve = "combattant" },
  pavoisier     = { solde = 10, reserve = "combattant" },
  barbier       = { solde = 15, reserve = "metier" },
  cuisinier     = { solde = 8, reserve = "metier" },
  armurier      = { solde = 16, reserve = "metier" },
}

-- Rangs et multiplicateur de solde.
hommes.rangs = { soudoyer = 1, dizainier = 1.5, capitaine = 2 }

-- L'équipement des combattants (fiche 13, V71 b ; règles validées par JoVenGer le 15/10/2026) : la tenue selon le grade,
-- la famille d'armes de l'homme d'armes tirée à l'embauche (ou donnée par le contrat) et gardée à vie, la qualité selon
-- le grade ; le pavoisier, un préréglage à pavois peint ; archers et arbalétriers, nos assemblages de tir et leurs
-- munitions. Niveaux de préréglage « de » à « a » compris, la variante tirée ; les pièces de chaque préréglage sont dans
-- la liaison (outils/equipement.py). Chaque pièce est créée une à une : le jeu la garde avec son usure (V71 a3).
hommes.equipement = {
  etat_neuf = 1,     -- état des pièces neuves (1 : neuves)
  tenue = { sorte = "soldier_generic", palier_1 = { de = 1, a = 2 }, palier_2 = { de = 3, a = 4 }, palier_3 = { de = 5, a = 6 },
            -- Hors du tirage (réponse de JoVenGer du 15/10/2026, après V71 e) : les six tenues du palier 3 qui superposent
            -- une cotte, une brigandine ou une cuirasse et une cotte de mailles ; la cotte de dessus n'y est pas portée.
            exclues = { "soldier_generic_5_02", "soldier_generic_5_05", "soldier_generic_5_12", "soldier_generic_6_01",
                        "soldier_generic_6_03", "soldier_generic_6_04" } },
  familles = {
    epee_bouclier  = { sorte = "sword_shield", palier_1 = { de = 3, a = 3 }, palier_2 = { de = 4, a = 4 }, palier_3 = { de = 5, a = 5 } },
    hache_bouclier = { sorte = "axe_shield", palier_1 = { de = 3, a = 3 }, palier_2 = { de = 4, a = 4 }, palier_3 = { de = 5, a = 6 } },
    epee_longue    = { sorte = "longsword", palier_1 = { de = 3, a = 3 }, palier_2 = { de = 4, a = 4 }, palier_3 = { de = 5, a = 6 } },
    masse_bouclier = { sorte = "mace_shield", palier_1 = { de = 2, a = 3 }, palier_2 = { de = 4, a = 4 }, palier_3 = { de = 5, a = 6 } },
    hache          = { sorte = "axe", palier_1 = { de = 2, a = 2 }, palier_2 = { de = 3, a = 3 }, palier_3 = { de = 5, a = 5 } },
    arme_d_hast    = { sorte = "polearm", palier_1 = { de = 2, a = 2 }, palier_2 = { de = 3, a = 3 }, palier_3 = { de = 4, a = 6 } },
  },
  pavois = {
    palier_1 = { "mace_shield_2_02", "mace_shield_2_03" },
    palier_2 = { "mace_shield_3_04", "axe_shield_3_02", "axe_shield_3_03", "huntingsword_shield_3_01", "huntingsword_shield_3_02" },
    palier_3 = { "mace_shield_4_02", "axe_shield_4_02", "huntingsword_shield_4_01" },
  },
  tir = {
    archer = {
      palier_1 = { prereglages = { "scriptorium_archer_1" }, munitions = 25 },
      palier_2 = { prereglages = { "scriptorium_archer_2" }, munitions = 30 },
      palier_3 = { prereglages = { "scriptorium_archer_3" }, munitions = 30 },
    },
    arbaletrier = {
      palier_1 = { prereglages = { "scriptorium_arbaletrier_1_a", "scriptorium_arbaletrier_1_b" }, munitions = 20 },
      palier_2 = { prereglages = { "scriptorium_arbaletrier_2_a", "scriptorium_arbaletrier_2_b" }, munitions = 20 },
      palier_3 = { prereglages = { "scriptorium_arbaletrier_3_a", "scriptorium_arbaletrier_3_b" }, munitions = 20 },
    },
  },
}

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
  des = { x = -2.5, y = -1.5, cap = 45 },   -- un coin près du feu, pour les dés de la veillée (fiche 11)
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
-- 2 -> 3 (16/10, fiche 15, V73 b 3) : l'affectation unique devient une tenue par règle (« tenues ») ; l'ancienne,
-- passagère elle aussi, est oubliée de même.
local function oublier_les_affectations(d)
  for _, f in pairs(d.liste or {}) do
    if type(f) == "table" then
      f.affectation = nil
    end
  end
  return d
end

local migrations = {
  [1] = oublier_les_affectations,
  [2] = oublier_les_affectations,
}

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("hommes") then
    registre.declarer_case("hommes", 3, donnees_neuves, migrations)
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

local function pgcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

-- Le nom du i-ième homme engagé. Prénom et surnom changent tous deux d'un homme à l'autre (« aucun pareil », souhait
-- de JoVenGer transmis le 15/10/2026 : en V70, les trois premiers s'appelaient tous Kladivo), et toutes les
-- combinaisons passent avant qu'un nom revienne : par tranches du plus petit commun multiple des deux listes, le surnom
-- décalé d'un cran à chaque tranche.
function hommes.nom_d_epoque(i)
  local np, ns = #hommes.prenoms, #hommes.surnoms
  local tranche = np * ns / pgcd(np, ns)
  local k = (i - 1) % (np * ns)
  local decalage, r = math.floor(k / tranche), k % tranche
  return hommes.prenoms[r % np + 1] .. " " .. hommes.surnoms[(r + decalage) % ns + 1]
end

local function nom_suivant(d)
  local i = d.prochain_nom
  d.prochain_nom = i + 1
  return hommes.nom_d_epoque(i)
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

-- Une âme libre pour l'homme (fiche 13, validée par JoVenGer le 15/10/2026) : une âme par homme vivant, jamais partagée,
-- prise dans la réserve de son rôle, à son palier ; palier plein, au palier le plus proche (ses compétences corrigent
-- ensuite son niveau). Rend l'identifiant de l'âme, ou nil quand toute la réserve est prise.
local function choisir_ame(d, f)
  local role = hommes.roles[f.role]
  local reserve = role and role.reserve
  local paliers = reserve and jeu().paliers_de(reserve) or {}
  local prises = {}
  for _, id in ipairs(d.ordre) do
    local autre = d.liste[id]
    if autre and autre ~= f and autre.ame then
      prises[autre.ame] = true
    end
  end
  local voulu = f.palier or 1
  local ordre_des_paliers = { voulu }
  for ecart = 1, #paliers do
    table.insert(ordre_des_paliers, voulu - ecart)
    table.insert(ordre_des_paliers, voulu + ecart)
  end
  for _, palier in ipairs(ordre_des_paliers) do
    for numero = 1, paliers[palier] or 0 do
      local ame = jeu().ame_de(reserve, palier, numero)
      if ame and not prises[ame] then
        return ame
      end
    end
  end
  return nil
end

-- L'âme est tirée une fois, à la première venue, et gardée sur le registre : même visage et même voix au retour, et
-- l'homme la garde quand il monte en grade. Un homme né avant la fiche 13 sur une âme empruntée au jeu (cerveau du jeu)
-- renaît sur une âme à nous.
local function faire_venir(d, f)
  local present = f.personnage and jeu().personnage_existe(f.personnage)
  if present and f.ame then
    return true
  end
  if not f.ame then
    f.ame = choisir_ame(d, f)
    if not f.ame then
      jeu().journal("Hommes : plus d'âme libre pour « " .. f.nom .. " » (" .. tostring(f.role) .. ") ; il reste sur le registre")
      if not present then
        f.personnage = nil
      end
      return present and true or false
    end
    if present then
      jeu().journal("Hommes : « " .. f.nom .. " » renaît sur une âme à nous")
      jeu().renvoyer_homme(f.personnage)
      f.personnage = nil
    end
  end
  local position = nil
  if camp().est_fonde() then
    position = camp().point(hommes.points.feu.x, hommes.points.feu.y, hommes.points.feu.cap)
  end
  local personnage = jeu().faire_venir_homme(f.ame, f.nom, position)
  if personnage == nil then
    jeu().journal("Hommes : le jeu n'a pas fait venir « " .. f.nom .. " » ; il reste sur le registre")
    f.personnage = nil
    return false
  end
  f.personnage = personnage
  f.derniere_activite = nil
  -- Fiche 13, V71 b : un personnage refait naît avec une tenue de naissance et sans les pièces de l'ancien, parties avec
  -- lui : il est rééquipé (tenue de naissance retirée de nouveau) ; les pièces données ensuite sont perdues.
  local e = f.equipement
  if e and e.etat ~= "impossible" and (e.naissance_retiree or e.etat == "pret" or e.etat == "a_rhabiller"
                                       or e.etat == "a_completer") then
    if #(e.en_plus or {}) > 0 then
      jeu().journal("Hommes : « " .. f.nom .. " » refait : " .. #e.en_plus .. " pièce(s) donnée(s) recréée(s) avec leur dernier état")
      e.recreer_en_plus = true
    end
    e.naissance_retiree, e.etat, e.otees, e.anciennes = false, "a_equiper", {}, nil
  end
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
  if Scriptorium.caractere then
    Scriptorium.caractere.oublier(f.id)
  end
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

-- ---------------------------------------------------------------- équipement (fiche 13, V71 b)

-- Les accroches : le programme Scriptorium y branche ses fonctions. « apres_le_rhabillage » (identifiant de l'homme) :
-- après qu'un homme a été équipé ou a remis ses affaires ; « piece_otee » (identifiant, objet) : une pièce de son ancien
-- grade, rendue au camp (réponse a de JoVenGer, 15/10) : la fonction rend vrai si elle la prend, et la pièce sort alors
-- du sac de l'homme ; si personne ne la prend, elle y reste, rien n'est détruit.
hommes.accroches = { apres_le_rhabillage = {}, piece_otee = {} }

function hommes.accrocher(nom, fonction)
  local liste = hommes.accroches[nom]
  if not liste or type(fonction) ~= "function" then
    return refuser("accroche_inconnue", tostring(nom))
  end
  table.insert(liste, fonction)
  return true
end

local function appeler(nom, ...)
  local pris = false
  for _, fonction in ipairs(hommes.accroches[nom] or {}) do
    local ok, rendu = pcall(fonction, ...)
    if not ok then
      jeu().journal("Hommes : accroche « " .. nom .. " » en panne : " .. tostring(rendu))
    elseif rendu then
      pris = true
    end
  end
  return pris
end

local function est_combattant(f)
  local role = hommes.roles[f.role]
  return role ~= nil and role.reserve == "combattant"
end

-- Le hasard de l'équipement, propre aux hommes et gardé sur le registre.
local function tirer(d)
  if not Scriptorium.hasard_en_ordre(d.graine_equipement) then
    d.graine_equipement = Scriptorium.hasard_depuis(7171)
  end
  return Scriptorium.tirer(d.graine_equipement)
end

local function choisir(d, liste)
  if #liste == 0 then
    return nil
  end
  return liste[math.floor(tirer(d) * #liste) + 1]
end

local function est_un_pavois(nom)
  for _, liste in pairs(hommes.equipement.pavois) do
    for _, p in ipairs(liste) do
      if p == nom then
        return true
      end
    end
  end
  return false
end

-- Les préréglages connus d'une sorte entre deux niveaux, sans ceux à pavois (réservés au pavoisier) ni ceux de la liste
-- « exclues ».
local function prereglages_de(sorte, bornes, exclues)
  local liste, hors = {}, {}
  for _, nom in ipairs(exclues or {}) do
    hors[nom] = true
  end
  if type(bornes) ~= "table" or type(bornes.de) ~= "number" or type(bornes.a) ~= "number" then
    return liste
  end
  for _, nom in ipairs(jeu().noms_des_prereglages()) do
    local s, niveau = string.match(nom, "^(.-)_(%d+)_%d+$")
    niveau = tonumber(niveau)
    if s == sorte and niveau and niveau >= bornes.de and niveau <= bornes.a and not est_un_pavois(nom) and not hors[nom] then
      table.insert(liste, nom)
    end
  end
  return liste
end

local function noms_des_familles()
  local noms = {}
  for nom in pairs(hommes.equipement.familles) do
    table.insert(noms, nom)
  end
  table.sort(noms)
  return noms
end

-- Choisit la tenue et les armes d'un combattant pour son palier (sa famille tirée une fois, s'il n'en a pas), à
-- équiper au prochain battement. Rend vrai s'il en a.
local function choisir_l_equipement(d, f)
  local regles = hommes.equipement
  local cle = "palier_" .. tostring(f.palier or 1)
  local e = f.equipement or {}
  e.en_plus, e.otees = e.en_plus or {}, e.otees or {}
  e.naissance_retiree = e.naissance_retiree or false
  f.equipement = e
  local tenue = choisir(d, prereglages_de(regles.tenue.sorte, regles.tenue[cle], regles.tenue.exclues))
  local armes, munitions = nil, 0
  if f.role == "homme_d_armes" then
    if not (f.famille and regles.familles[f.famille]) then
      f.famille = choisir(d, noms_des_familles())
    end
    local famille = regles.familles[f.famille]
    armes = choisir(d, prereglages_de(famille.sorte, famille[cle]))
  elseif f.role == "pavoisier" then
    armes = choisir(d, regles.pavois[cle] or {})
  elseif regles.tir[f.role] then
    local tir = regles.tir[f.role][cle] or {}
    armes = choisir(d, tir.prereglages or {})
    munitions = tir.munitions or 0
  end
  if not tenue or not armes then
    e.etat = "impossible"
    jeu().journal("Hommes : pas de préréglage pour « " .. f.nom .. " » (" .. tostring(f.role) .. ", " .. cle .. ")")
    return false
  end
  e.tenue, e.armes, e.munitions, e.etat = tenue, armes, munitions, "a_equiper"
  return true
end

-- Une pièce donnée (en_plus) : { objet, etat }, son dernier état connu (V71 c) ; une fiche d'avant n'a que l'objet.
local function objet_de(piece)
  return type(piece) == "table" and piece.objet or piece
end

-- Ce qu'il porte, dans l'ordre : pièces de sa tenue, de ses armes, ses munitions, puis les pièces données ensuite, moins
-- celles qu'il ne porte plus. La dernière pièce d'une même place l'emporte : toujours la même (pair, 15/10).
local function liste_portee(f)
  local e = f.equipement or {}
  local liste = {}
  for _, nom in ipairs({ e.tenue or false, e.armes or false }) do
    for _, objet in ipairs(nom and jeu().pieces_de(nom) or {}) do
      table.insert(liste, objet)
    end
  end
  local munition = e.armes and jeu().munition_de(e.armes)
  if munition then
    table.insert(liste, munition)
  end
  for _, piece in ipairs(e.en_plus or {}) do
    table.insert(liste, objet_de(piece))
  end
  for _, objet in ipairs(e.otees or {}) do
    for i = #liste, 1, -1 do
      if liste[i] == objet then
        table.remove(liste, i)
        break
      end
    end
  end
  return liste
end

function hommes.ce_qu_il_porte(id)
  local f = donnees().liste[id]
  return f and liste_portee(f) or {}
end

-- Équipe l'homme : sa tenue de naissance retirée d'abord, une fois (V71 a6), puis chaque pièce créée une à une, puis
-- portée dans l'ordre ; les pièces de l'ancien grade offertes à l'accroche « piece_otee ».
local function equiper(d, f)
  local e = f.equipement
  local a_creer = {}
  for _, nom in ipairs({ e.tenue, e.armes }) do
    for _, objet in ipairs(jeu().pieces_de(nom) or {}) do
      table.insert(a_creer, objet)
    end
  end
  local munition = jeu().munition_de(e.armes)
  -- Un personnage refait retrouve les pièces qu'on lui avait données, avec leur dernier état connu (V71 c ; « ce qu'il
  -- a acheté est à lui », règle de JoVenGer dans Scriptorium).
  local a_recreer = {}
  if e.recreer_en_plus then
    for i, piece in ipairs(e.en_plus) do
      local etat = type(piece) == "table" and piece.etat or nil
      if type(etat) ~= "number" then
        etat = 1
        jeu().journal("Hommes : « " .. f.nom .. " », état inconnu pour " .. tostring(objet_de(piece)) .. " : recréée neuve")
      end
      e.en_plus[i] = { objet = objet_de(piece), etat = etat }
      table.insert(a_recreer, e.en_plus[i])
    end
    e.recreer_en_plus = nil
  end
  local compte = jeu().equiper_homme(f.personnage, {
    retirer_naissance = not e.naissance_retiree,
    creer = a_creer,
    etat = hommes.equipement.etat_neuf,
    munition = (munition and (e.munitions or 0) > 0) and { objet = munition, nombre = e.munitions } or nil,
    recreer = a_recreer,
    porter = liste_portee(f),
  })
  e.naissance_retiree = true
  e.etat = "a_completer"
  if e.anciennes then
    local portees = {}
    for _, objet in ipairs(liste_portee(f)) do
      portees[objet] = true
    end
    local rendues = 0
    for _, objet in ipairs(e.anciennes) do
      if not portees[objet] and appeler("piece_otee", f.id, objet) and jeu().retirer_un_objet(f.personnage, objet) then
        rendues = rendues + 1
      end
    end
    jeu().journal("Hommes : « " .. f.nom .. " », " .. rendues .. " pièce(s) de l'ancien grade rendue(s) au camp")
    e.anciennes = nil
  end
  jeu().journal("Hommes : « " .. f.nom .. " » équipé (" .. tostring(e.tenue) .. ", " .. tostring(e.armes) .. ") : " .. tostring(compte))
end

-- À chaque entrée en partie, l'homme remet ses propres pièces, dans l'ordre (réponse a de JoVenGer, 15/10) : le jeu ne
-- lui laisse portée qu'une partie de ses pièces et lui ôte ses armes (V71 a6). Une pièce introuvable est notée, jamais
-- recréée au hasard. Filet (règle du 5/10) : plus aucune pièce de sa tenue, ou plus son arme principale : ses
-- préréglages sont recréés au battement suivant. Ses munitions sont complétées jusqu'au nombre de son préréglage.
local function rhabiller(d, f)
  local e = f.equipement
  local portes, introuvables = jeu().faire_porter(f.personnage, liste_portee(f))
  e.etat = "a_completer"
  -- Le dernier état connu de chaque pièce donnée, pour la recréer telle quelle si le personnage est refait (V71 c).
  for i, piece in ipairs(e.en_plus or {}) do
    local etat = jeu().etat_objet(f.personnage, objet_de(piece))
    e.en_plus[i] = { objet = objet_de(piece), etat = etat or (type(piece) == "table" and piece.etat or nil) }
  end
  if e.tenue and e.armes then
    local reste = 0
    for _, objet in ipairs(jeu().pieces_de(e.tenue) or {}) do
      if jeu().compter_objet(f.personnage, objet) > 0 then
        reste = reste + 1
      end
    end
    local armes = jeu().pieces_de(e.armes) or {}
    if reste == 0 or not armes[1] or jeu().compter_objet(f.personnage, armes[1]) == 0 then
      jeu().journal("Hommes : « " .. f.nom .. " » sans sa tenue ou sans son arme : ses préréglages seront recréés")
      e.etat = "a_equiper"
      return
    end
    local munition = jeu().munition_de(e.armes)
    if munition then
      local n = jeu().compter_objet(f.personnage, munition)
      if n < (e.munitions or 0) then
        jeu().creer_objet(f.personnage, munition, 1, e.munitions - n)
        jeu().journal("Hommes : « " .. f.nom .. " », munitions complétées (" .. n .. " -> " .. e.munitions .. ")")
      end
    end
  end
  jeu().journal("Hommes : « " .. f.nom .. " » a remis ses affaires (" .. tostring(portes) .. " pièce(s)"
    .. (#introuvables > 0 and (", " .. #introuvables .. " introuvable(s) ou refusée(s)") or "") .. ")")
end

-- La garde de la tenue (fiche 13) : marque un homme équipé « à rhabiller » ; le battement lui fera remettre ses pièces,
-- par le chemin du chargement (journal, second passage, accroche). Rend vrai s'il est marqué.
local function marquer_a_rhabiller(f)
  local e = f.equipement
  if e and (e.etat == "pret" or e.etat == "a_completer") then
    e.etat = "a_rhabiller"
    return true
  end
  return false
end

-- Second passage, au battement suivant (V71 c : un seul passage juste après la création ou la remise ne fait pas tout
-- porter ; un second complète la tenue, un troisième ne change rien). Puis l'accroche « après le rhabillage ».
local function completer(d, f)
  local portes, introuvables = jeu().faire_porter(f.personnage, liste_portee(f))
  f.equipement.etat = "pret"
  jeu().journal("Hommes : « " .. f.nom .. " », second passage (" .. tostring(portes) .. " pièce(s)"
    .. (#introuvables > 0 and (", " .. #introuvables .. " introuvable(s) ou refusée(s)") or "") .. ")")
  appeler("apres_le_rhabillage", f.id)
end

local function en_bataille()
  return Scriptorium.bataille ~= nil and #Scriptorium.bataille.bandes() > 0
end

-- La garde de la tenue ne touche pas un homme (fiche 13, réponse 2 a de JoVenGer) : au lit (sa place est un lit ; la
-- sortie du lit le rhabillera), sous une tenue qui le veut dévêtu (le bain : « ne_pas_rhabiller »), en combat ou en
-- conversation. Rend la raison, ou nil.
local function garde_suspendue(id, f)
  local a = hommes.activite_de(id, jeu().heure_du_jeu())
  if a and a.lieu and camp().sorte_de(a.lieu) == "lit" then
    return "au lit"
  end
  if a and a.ne_pas_rhabiller then
    return "tenu dévêtu (" .. tostring(a.regle) .. ")"
  end
  local occupe = f.personnage and jeu().occupation_de(f.personnage)
  if occupe then
    return "en " .. occupe
  end
  return nil
end

-- Un homme par battement, jamais en bataille ; un homme que la garde ne doit pas toucher attend son tour (fiche 13).
-- Rend l'identifiant de l'homme équipé ou rhabillé, ou faux.
local function equiper_un_homme(d)
  if en_bataille() then
    return false
  end
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.personnage and jeu().personnage_existe(f.personnage) then
      if not f.equipement and est_combattant(f) then
        choisir_l_equipement(d, f)
      end
      local etat = f.equipement and f.equipement.etat
      -- La garde n'est lue que pour un homme qui a quelque chose à faire (elle interroge l'arbitre).
      local a_faire = etat == "a_equiper" or etat == "a_rhabiller" or etat == "a_completer"
      if a_faire and not garde_suspendue(id, f) then
        if etat == "a_equiper" then
          equiper(d, f)
        elseif etat == "a_rhabiller" then
          rhabiller(d, f)
        else
          completer(d, f)
        end
        return id
      end
    end
  end
  return false
end

-- La garde de la tenue, en tournant (fiche 13, réponse 2 a de JoVenGer) : « tenue_garde_par_battement » hommes prêts,
-- chacun à son tour, remettent leurs propres pièces, sans rien créer ni rien ôter (remettre une pièce portée ne l'ôte pas,
-- V71 c), en silence : compté au rapport, pas au journal. Jamais en bataille ; un homme que la garde ne doit pas toucher
-- est sauté, comme celui que le rhabillage vient de traiter dans ce battement (« deja »). Rend le nombre d'hommes repassés.
hommes.garde_de_la_tenue_rang = 0

local function garder_les_tenues(d, deja)
  if en_bataille() or #d.ordre == 0 then
    return 0
  end
  local repasses, vus = 0, 0
  local voulus = math.max(0, math.floor(tonumber(hommes.reglages.tenue_garde_par_battement) or 0))
  while repasses < voulus and vus < #d.ordre do
    hommes.garde_de_la_tenue_rang = hommes.garde_de_la_tenue_rang % #d.ordre + 1
    vus = vus + 1
    local id = d.ordre[hommes.garde_de_la_tenue_rang]
    local f = d.liste[id]
    if id ~= deja and f.personnage and f.equipement and f.equipement.etat == "pret" and jeu().personnage_existe(f.personnage)
        and not garde_suspendue(id, f) then
      jeu().faire_porter(f.personnage, liste_portee(f))
      repasses = repasses + 1
    end
  end
  return repasses
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
  local palier = contrat.palier or hommes.reglages.palier_par_defaut
  local nb_paliers = #jeu().paliers_de(role.reserve)
  if type(palier) ~= "number" or math.floor(palier) ~= palier or palier < 1 or palier > math.max(nb_paliers, 1) then
    return refuser("palier_invalide", tostring(palier))
  end
  if contrat.famille ~= nil and not hommes.equipement.familles[contrat.famille] then
    return refuser("famille_inconnue", tostring(contrat.famille))
  end
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
    palier = palier,
    ame = nil,
    contrat = { semaines = semaines, solde = solde, prime = prime, debut = heure, fin = heure + semaines * 7 * 24 },
    moral = hommes.reglages.moral_depart,
    blessure = 0,
    impayes = 0,
    personnage = nil,
    lit = lits[1],
    derniere_activite = nil,
    engage = heure,
    retenue = 0,
    famille = contrat.famille,
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
  if Scriptorium.caractere then
    Scriptorium.caractere.naitre(id)
  end
  if d.prochaine_paie == nil then
    d.prochaine_paie = (jour_de(heure) + 7) * 24 + hommes.reglages.heure_paie
    d.derniere_heure = heure
    d.derniere_aube = jour_de(heure - hommes.reglages.heure_lever)
    d.dernier_jour_repas = jour_de(heure - hommes.reglages.heure_repas)
  end
  faire_venir(d, f)
  if est_combattant(f) then
    choisir_l_equipement(d, f)
  end
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

-- Le même événement pour tous ; une perte de moral pèse selon le sang-froid de chacun (fiche 11).
function hommes.moral_pour_tous(delta)
  local d = donnees()
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local sa_part = Scriptorium.caractere and Scriptorium.caractere.moral_ajuste(id, delta) or delta
    f.moral = borner(f.moral + sa_part, 0, 100)
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

-- ---------------------------------------------------------------- l'arbitre des ordres (fiche 15, V73 b 3)

-- Le rang d'une règle au catalogue (1 le plus fort), ou nil : une règle inconnue ne tient personne.
local function rang_de(regle)
  return hommes.priorites[regle]
end

-- Le prochain changement de tranche de la journée après « heure » (heure du jeu, absolue) : la borne d'une tenue posée
-- sans fin (réponse 4 a de JoVenGer, 16/10). La tranche de la nuit passe minuit (22 h → 5 h).
local function prochain_changement_de_tranche(heure)
  local h = heure_dans_le_jour(heure)
  local debut_du_jour = heure - h
  local t = tranche_de(h)
  if t.de < t.a or h < t.a then
    return debut_du_jour + t.a
  end
  return debut_du_jour + 24 + t.a
end

-- La tenue posée la plus forte d'un homme : (règle, tenue, rang). À rang égal, la plus ancienne garde l'homme, puis le nom
-- de la règle (l'ordre de « pairs » n'est pas sûr).
local function tenue_la_plus_forte(f)
  local regle_choisie, tenue_choisie, rang_choisi = nil, nil, nil
  for regle, t in pairs(f.tenues or {}) do
    local rang = rang_de(regle)
    if rang then
      local depuis, depuis_choisi = t.depuis or 0, tenue_choisie and (tenue_choisie.depuis or 0)
      if rang_choisi == nil or rang < rang_choisi
          or (rang == rang_choisi and (depuis < depuis_choisi or (depuis == depuis_choisi and regle < regle_choisie))) then
        regle_choisie, tenue_choisie, rang_choisi = regle, t, rang
      end
    end
  end
  return regle_choisie, tenue_choisie, rang_choisi
end

-- Service pour le guichet et pour les morceaux du socle : l'homme est-il libre pour cette règle ? Il n'en est pas exempté,
-- et aucune règle aussi forte ne le tient (une tenue posée, ou ses blessures : les soins). Une tenue de la même règle ne
-- compte pas : la reposer la met à jour.
function hommes.libre_pour(id, regle)
  local f = donnees().liste[id]
  local rang = rang_de(regle)
  if not f or not rang or (f.exemptions and f.exemptions[regle]) then
    return false
  end
  local soins = rang_de("soins")
  if f.blessure > 0 and soins and soins <= rang then
    return false
  end
  for autre in pairs(f.tenues or {}) do
    local r = rang_de(autre)
    if autre ~= regle and r and r <= rang then
      return false
    end
  end
  return true
end

-- Les hommes de garde à cette heure, en rotation par tour de veille, jamais plus que d'hommes valides. Valide : libre
-- pour la garde de cette heure (« garde_de_nuit » la nuit, dont Scriptorium exempte les compagnons, réponse 3 a du V73 b).
function hommes.gardes(heure)
  local d = donnees()
  local h = heure_dans_le_jour(heure)
  local regle = est_nuit(h) and "garde_de_nuit" or "garde"
  local valides = {}
  for _, id in ipairs(d.ordre) do
    if hommes.libre_pour(id, regle) then
      table.insert(valides, id)
    end
  end
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

-- Le factionnaire (fiche 15, V73 d 1) : le point qu'il regarde, à « regard_m » devant son poste. « cap » : cap de
-- boussole en degrés (0 au nord, 90 à l'est, comme tout le socle) ; sans cap, du centre du camp vers le poste, donc vers
-- le dehors. Rend nil sans position, sans cap ni camp, ou pour un poste au centre même du camp : l'ordre est alors une
-- marche simple.
local function regard_du_poste(position, cap)
  local distance = tonumber(hommes.reglages.regard_m) or 0
  if type(position) ~= "table" or distance <= 0 then
    return nil
  end
  local dx, dy
  if type(cap) == "number" then
    dx, dy = math.sin(math.rad(cap)), math.cos(math.rad(cap))
  else
    local centre = camp().point(0, 0, 0)
    if not centre then
      return nil
    end
    local ex, ey = position.x - centre.x, position.y - centre.y
    local longueur = math.sqrt(ex * ex + ey * ey)
    if longueur < 0.1 then
      return nil
    end
    dx, dy = ex / longueur, ey / longueur
  end
  return { x = position.x + distance * dx, y = position.y + distance * dy, z = position.z }
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

-- L'activité d'un homme à une heure : { regle, activite, lieu, position, cap, fin, regard }. L'arbitre (fiche 15, V73 b 3) : la
-- tenue posée la plus forte, contre les règles que le socle calcule lui-même (les soins d'un blessé, son tour de garde) ;
-- à rang égal, la tenue posée l'emporte (un ordre exprès) ; sinon la journée du socle, ou l'attente si elle est coupée.
function hommes.activite_de(id, heure)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return nil
  end
  local resultat = { activite = nil, lieu = nil, position = nil }
  local regle, tenue, rang = tenue_la_plus_forte(f)
  local soins = rang_de("soins")
  if f.blessure > 0 and soins and (not rang or soins < rang) then
    resultat.regle, resultat.activite = "soins", "repos"
    resultat.lieu = f.lit
    resultat.position = f.lit and camp().position_de(f.lit) or nil
    return resultat
  end
  -- Le tour de garde ne prend que des hommes libres pour la garde (aucune tenue aussi forte) : il passe donc devant
  -- leurs tenues, toutes plus faibles.
  for _, g in ipairs(hommes.gardes(heure)) do
    if g.id == id then
      local poste = hommes.postes_de_garde[g.poste]
      resultat.regle = est_nuit(heure_dans_le_jour(heure)) and "garde_de_nuit" or "garde"
      resultat.activite = "garde"
      resultat.lieu = "poste_" .. g.poste
      -- V73 d 1 : le cap du poste n'est plus jeté ; le garde se tient face au dehors.
      resultat.position, resultat.cap = camp().point(poste.x, poste.y, poste.cap)
      resultat.regard = regard_du_poste(resultat.position, resultat.cap)
      return resultat
    end
  end
  if tenue then
    resultat.regle, resultat.activite, resultat.lieu = regle, tenue.activite, tenue.lieu
    resultat.position, resultat.cap, resultat.fin = tenue.position, tenue.cap, tenue.fin
    resultat.ne_pas_rhabiller = tenue.ne_pas_rhabiller
    -- V73 d 1 : une garde se tient face au dehors (le cap de la tenue, sinon du centre du camp vers le poste).
    if tenue.activite == "garde" then
      resultat.regard = regard_du_poste(tenue.position, tenue.cap)
    end
    return resultat
  end
  if hommes.reglages.journee_du_socle == false then
    resultat.regle, resultat.activite = "aucune", "attendre"
    return resultat
  end
  resultat.regle = "journee"
  local tranche = tranche_de(heure_dans_le_jour(heure))
  local activite = tranche.activite
  -- Une place à soi autour d'un point d'activité (fiche 04 ; V72 c : trois hommes au même point) : en rangs de quatre,
  -- à « ecart_entre_hommes » mètres, selon le rang de l'homme au camp.
  local function place_autour(p)
    local rang = 1
    for i, autre in ipairs(d.ordre) do
      if autre == id then rang = i end
    end
    local ecart = tonumber(hommes.reglages.ecart_entre_hommes) or 0
    local colonne, rangee = (rang - 1) % 4, math.floor((rang - 1) / 4)
    return camp().point(p.x + (colonne - 1.5) * ecart, p.y - rangee * ecart, p.cap)
  end
  -- La veillée est le temps libre : chacun y fait ce que lui dictent sa fatigue et ses envies (fiche 11) ; « le feu »
  -- garde la veillée ordinaire.
  if activite == "veillee" and Scriptorium.caractere then
    local choix = Scriptorium.caractere.choix_du_soir(id, heure)
    if choix == "sommeil" or choix == "entrainement" or choix == "des" then
      activite = choix
    end
  end
  resultat.activite = activite
  if activite == "sommeil" then
    resultat.lieu = f.lit
    resultat.position = f.lit and camp().position_de(f.lit) or nil
  elseif activite == "entrainement" or activite == "des" then
    local p = hommes.points[(activite == "des") and "des" or "exercice"]
    resultat.lieu = (activite == "des") and "des" or "exercice"
    resultat.position = place_autour(p)
  elseif activite == "repas" or activite == "veillee" then
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
      resultat.position = place_autour(hommes.points.feu)
    end
  elseif activite == "exercice" or activite == "corvee" then
    local p = hommes.points[activite]
    resultat.lieu = activite
    resultat.position = place_autour(p)
  else
    resultat.lieu = "feu_central"
    resultat.position = place_autour(hommes.points.feu)
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

-- Le repas du matin d'un jour (« moment » : son heure) : rations selon l'appétit de chacun, soins selon sa forme,
-- puis le compte de la journée passée (fatigue, aguerrissement, fiche 11).
local function repas_du_jour(d, rapport, moment)
  local caractere = Scriptorium.caractere
  local affames, affame = 0, {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local ration = caractere and caractere.ration_de(id, hommes.reglages.ration) or hommes.reglages.ration
    if coffre().prelever_reserve("vivres", ration, "repas") then
      f.moral = borner(f.moral + 2, 0, 100)
    else
      f.moral = borner(f.moral - 10, 0, 100)
      affames = affames + 1
      affame[id] = true
    end
  end
  if affames > 0 then
    annoncer("ui_scriptorium_hommes_faim")
  end
  rapport.affames = affames
  -- Soins : un jour de moins, deux avec un barbier valide, selon la forme de chacun.
  local soin = barbier_valide(d) and 2 or 1
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.blessure > 0 then
      local jours = caractere and caractere.jours_de_soin(id, soin) or soin
      f.blessure = math.max(0, f.blessure - jours)
      if f.blessure == 0 then
        rapport.gueris = (rapport.gueris or 0) + 1
      end
    end
  end
  if caractere then
    for _, id in ipairs(d.ordre) do
      local f = d.liste[id]
      local variation = caractere.passer_la_journee(id, moment, affame[id] == true)
      if variation ~= 0 then
        f.moral = borner(f.moral + variation, 0, 100)
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
-- Le suivi des marches, en mémoire seulement (fiche 15 : une position perdue au rechargement ne coûte rien, et le
-- registre reste sous 65 535 octets) : id -> { reste, bloque_s, secours, signale, resume }.
hommes.suivi = {}

-- Ce que l'ordre vise (fiche 15, V73 a) : une place du camp (siège, lit) se prend par son objet du jeu ; tout le reste est
-- un point où marcher. Rend (position, objet de la place, sorte de la place).
local function but_de(a)
  local sorte = a.lieu and camp().sorte_de(a.lieu)
  if sorte and camp().sortes_places[sorte] then
    local objet = camp().objet_du_jeu_de(a.lieu)
    if objet then
      return a.position, objet, sorte
    end
  end
  return a.position, nil, nil
end

-- Le secours de l'homme bloqué (réponse 1 de JoVenGer du 16/10) : posé près de son but, jamais dans un meuble (une
-- place s'aborde à l'écart, camp.abord_de), sur une place libre (la liaison), puis son ordre est redonné.
local function secourir(id, f, a, rapport)
  -- « Rapproché » : l'écart restant jusqu'au but a baissé (règle de JoVenGer : au moins 1 m en 30 s).
  local but = a.position
  local reste = but and jeu().ecart_au_but(f.personnage, but)
  local s = hommes.suivi[id]
  if not reste or not s then
    return
  end
  if reste <= hommes.reglages.secours_arrivee_m then
    s.reste, s.bloque_s = reste, 0
    return
  end
  -- Encore à sa place d'avant (assis ou couché) : on attend qu'il se lève, jamais de pose d'un coup.
  local pres = s.assis_a and jeu().ecart_au_but(f.personnage, s.assis_a)
  if pres and pres <= hommes.reglages.secours_assis_m then
    s.reste, s.bloque_s = reste, 0
    return
  end
  -- En combat ou en conversation, il ne se rapproche pas de son but sans être bloqué (fiche 15, V73 b 1) : jamais posé
  -- d'un coup hors de son combat ; son compte repart de zéro quand le jeu le rend.
  if jeu().occupation_de(f.personnage) then
    s.reste, s.bloque_s = nil, 0
    return
  end
  if s.reste and s.reste - reste < hommes.reglages.secours_progres_m then
    s.bloque_s = s.bloque_s + Scriptorium.cadence_du_battement_ms / 1000
  else
    s.bloque_s = 0
  end
  s.reste = reste
  if s.bloque_s < hommes.reglages.secours_delai_s then
    return
  end
  if s.secours >= hommes.reglages.secours_max then
    if not s.signale then
      s.signale = true
      jeu().journal("Hommes : « " .. f.nom .. " » ne rejoint pas « " .. tostring(a.lieu) .. " » malgré " .. s.secours
                    .. " secours ; laissé où il est")
    end
    return
  end
  s.secours, s.bloque_s = s.secours + 1, 0
  local _, objet = but_de(a)
  local ou = objet and camp().abord_de(a.lieu) or but
  jeu().journal("Hommes : « " .. f.nom .. " » bloqué vers « " .. tostring(a.lieu) .. " », secours "
                .. s.secours .. " : " .. tostring(jeu().poser_en_secours(f.personnage, ou)))
  f.derniere_activite = nil
  rapport.secours = (rapport.secours or 0) + 1
end

-- Les cerveaux réglés depuis le dernier réveil : { [personnage] = signature des valeurs écrites, ou « refus: » suivi de
-- la signature si l'écriture a échoué (dit une fois au journal, retentée au prochain réveil ou au prochain changement).
hommes.cerveaux_regles = {}

local function signature_du_cerveau()
  local cles = {}
  for cle in pairs(hommes.cerveau) do
    table.insert(cles, cle)
  end
  table.sort(cles)
  local morceaux = {}
  for _, cle in ipairs(cles) do
    table.insert(morceaux, cle .. "=" .. tostring(hommes.cerveau[cle]))
  end
  return table.concat(morceaux, ";")
end

-- Fiche 12 : écrit les valeurs du cerveau chez chaque homme et chez le Directeur dont le personnage est nouveau, ou dont
-- les valeurs ont changé (réglage par fichier). Rend le nombre de cerveaux écrits.
local function regler_les_cerveaux(d)
  local signature = signature_du_cerveau()
  local personnages = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.personnage then
      table.insert(personnages, f.personnage)
    end
  end
  local du_directeur = Scriptorium.directeur and Scriptorium.directeur.personnage()
  if du_directeur then
    table.insert(personnages, du_directeur)
  end
  local ecrits = 0
  for _, qui in ipairs(personnages) do
    local deja = hommes.cerveaux_regles[qui]
    if deja ~= signature and deja ~= "refus:" .. signature then
      local ok, ligne = jeu().regler_le_cerveau(qui, hommes.cerveau)
      jeu().journal("Hommes : cerveau de « " .. tostring(qui) .. " » : " .. tostring(ligne))
      hommes.cerveaux_regles[qui] = ok and signature or ("refus:" .. signature)
      if ok then
        ecrits = ecrits + 1
      end
    end
  end
  return ecrits
end

-- Les compteurs du switch vus au dernier battement, par personnage (en mémoire seulement, remis à zéro au réveil comme
-- le cerveau) : les arrêts du plafond de relances (fiche 15, V73 b 2) ; les fins de combat et les lancements de la vie
-- du camp (la garde de la tenue, fiche 13).
hommes.arrets_vus = {}
hommes.fins_de_combat_vues = {}
hommes.lancements_vus = {}

local COMPTEURS_DU_SWITCH = { "scriptorium_vie_arrets", "scriptorium_fins_de_combat", "scriptorium_essai_rejoint" }

-- Une ligne au journal par hausse du compteur des arrêts, chez chaque homme et chez le Directeur ; un homme équipé dont
-- un combat vient de finir (le signal direct du switch), ou dont la vie du camp a été relancée (le filet), est marqué
-- « à rhabiller » (la garde de la tenue). Le premier relevé après le réveil ne marque personne : le réveil rhabille déjà.
-- Rend (arrêts nouveaux, hommes marqués).
local function surveiller_les_cerveaux(d)
  local suivis = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.personnage then
      table.insert(suivis, { qui = f.personnage, nom = f.nom, fiche = f })
    end
  end
  local du_directeur = Scriptorium.directeur and Scriptorium.directeur.personnage()
  if du_directeur then
    table.insert(suivis, { qui = du_directeur, nom = "Directeur" })
  end
  local nouveaux, marques = 0, 0
  for _, s in ipairs(suivis) do
    local lus = jeu().lire_le_cerveau(s.qui, COMPTEURS_DU_SWITCH)
    local arrets = tonumber(lus.scriptorium_vie_arrets)
    if arrets then
      local vus = hommes.arrets_vus[s.qui] or 0
      if arrets > vus then
        nouveaux = nouveaux + (arrets - vus)
        jeu().journal("Hommes : pouls : relances arrêtées pour « " .. s.nom .. " » (" .. arrets .. " fois depuis le chargement)")
      end
      hommes.arrets_vus[s.qui] = arrets
    end
    local fins, lancements = tonumber(lus.scriptorium_fins_de_combat), tonumber(lus.scriptorium_essai_rejoint)
    local raison = nil
    if fins then
      local vues = hommes.fins_de_combat_vues[s.qui]
      if vues and fins > vues then
        raison = "fin de combat"
      end
      hommes.fins_de_combat_vues[s.qui] = fins
    end
    if lancements then
      local vus = hommes.lancements_vus[s.qui]
      if vus and lancements > vus then
        raison = raison or "vie du camp relancée"
      end
      hommes.lancements_vus[s.qui] = lancements
    end
    if raison and s.fiche and marquer_a_rhabiller(s.fiche) then
      marques = marques + 1
      jeu().journal("Hommes : « " .. s.nom .. " » à rhabiller (" .. raison .. ")")
    end
  end
  return nouveaux, marques
end

-- L'ordre d'un homme, seulement quand son activité change : un geste (fiche 15, V73 a), plus de téléportation ; sinon,
-- au battement, le secours de l'homme bloqué. « sans_secours » : l'ordre redonné sur-le-champ par l'arbitre, hors
-- battement (V73 b 3), ne compte pas le temps du secours (il avance d'un battement à chaque appel).
local function ordonner_un_homme(d, id, heure, rapport, sans_secours)
  local f = d.liste[id]
  if not f or not f.personnage then
    return
  end
  local a = hommes.activite_de(id, heure)
  local resume = a.activite .. "@" .. tostring(a.lieu)
  if f.derniere_activite ~= resume then
    local position, objet, sorte = but_de(a)
    jeu().ordonner(f.personnage, a.activite, position, a.lieu, objet, sorte, a.regard)
    -- La garde de la tenue (fiche 13, proposé par le pair) : à la sortie du lit, l'homme est marqué « à rhabiller ».
    local ancien_lieu = f.derniere_activite and string.match(f.derniere_activite, "@(.+)$")
    if ancien_lieu and camp().sorte_de(ancien_lieu) == "lit" and not (a.lieu and camp().sorte_de(a.lieu) == "lit") then
      marquer_a_rhabiller(f)
    end
    f.derniere_activite = resume
    local garde = hommes.suivi[id]
    hommes.suivi[id] = { reste = nil, bloque_s = 0, secours = (garde and garde.resume == resume) and garde.secours or 0,
                         signale = garde and garde.resume == resume and garde.signale or nil, resume = resume,
                         place_position = objet and position or nil,
                         assis_a = garde and (garde.place_position or garde.assis_a) or nil }
    if rapport then
      rapport.ordres = rapport.ordres + 1
    end
  elseif not sans_secours then
    secourir(id, f, a, rapport)
  end
end

function hommes.battre()
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local rapport = { aubes = 0, repas = 0, paies = 0, ordres = 0, equipes = 0, changements = 0, cerveaux = 0, arrets = 0,
                    a_rhabiller = 0, tenues = 0 }
  rapport.cerveaux = regler_les_cerveaux(d)
  rapport.arrets, rapport.a_rhabiller = surveiller_les_cerveaux(d)
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
    repas_du_jour(d, rapport, d.dernier_jour_repas * 24 + hommes.reglages.heure_repas)
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
  -- Les tenues tombent à leur fin ; une tenue « jusqu'à libération » tombe par sûreté au bout de « tenue_max_h »
  -- (réponse 2 a de JoVenGer, V73 b), notée au journal : sa règle l'avait oubliée (fiche 15, V73 b 3).
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    for regle, t in pairs(f.tenues or {}) do
      local tombee = false
      if type(t.fin) == "number" then
        tombee = heure >= t.fin
      elseif heure >= (t.depuis or heure) + hommes.reglages.tenue_max_h then
        tombee = true
        jeu().journal("Hommes : tenue « " .. regle .. " » de « " .. f.nom .. " » tombée au bout de "
                      .. string.format("%g", hommes.reglages.tenue_max_h) .. " h, jamais lâchée")
      end
      if tombee then
        f.tenues[regle] = nil
        rapport.changements = rapport.changements + 1
      end
    end
  end
  for _, id in ipairs(d.ordre) do
    ordonner_un_homme(d, id, heure, rapport, false)
  end
  local equipe = equiper_un_homme(d)
  if equipe then
    rapport.equipes = rapport.equipes + 1
    rapport.changements = rapport.changements + 1
  end
  rapport.tenues = garder_les_tenues(d, equipe)
  d.derniere_heure = heure
  if rapport.changements > 0 or rapport.a_rhabiller > 0 then
    enregistrer()
  end
  return rapport
end

-- ---------------------------------------------------------------- l'arbitre : services (fiche 15, V73 b 3)

local function memes_points(a, b)
  if a == nil or b == nil then
    return a == b
  end
  return a.x == b.x and a.y == b.y and a.z == b.z
end

local function memes_tenues(a, b)
  return a.activite == b.activite and a.lieu == b.lieu and a.cap == b.cap and a.fin == b.fin
    and a.ne_pas_rhabiller == b.ne_pas_rhabiller and memes_points(a.position, b.position)
end

-- Service pour le guichet et pour les morceaux du socle : tenir un homme par une règle (au catalogue, hommes.priorites).
-- « quoi » : activite, lieu, position, cap, et sa fin : une heure du jeu ; « liberation » (jusqu'à ce que la règle le
-- lâche, borné par sûreté à « tenue_max_h ») ; rien (jusqu'au prochain changement de tranche, réponse 4 a). Une règle
-- plus faible ne reprend pas un homme qu'une plus forte tient : sa tenue reste posée, et prend effet quand la plus forte
-- le lâche. Reposer la même règle la met à jour sans la rajeunir. L'ordre est redonné sur-le-champ si l'activité de
-- l'homme change. Rend vrai, ou (faux, raison).
function hommes.tenir(id, regle, quoi)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not rang_de(regle) then
    return refuser("regle_inconnue", tostring(regle))
  end
  if f.exemptions and f.exemptions[regle] then
    return refuser("homme_exempte", f.nom .. " : " .. regle)
  end
  quoi = quoi or {}
  local heure = jeu().heure_du_jeu()
  local fin = quoi.fin
  if fin == nil then
    fin = prochain_changement_de_tranche(heure)
  elseif fin ~= "liberation" and type(fin) ~= "number" then
    return refuser("fin_invalide", tostring(fin))
  end
  f.tenues = f.tenues or {}
  local avant = f.tenues[regle]
  -- « ne_pas_rhabiller » : une règle qui veut l'homme dévêtu (le bain) ; la garde de la tenue le saute (fiche 13).
  local tenue = { activite = quoi.activite, lieu = quoi.lieu, position = quoi.position, cap = quoi.cap, fin = fin,
                  depuis = avant and avant.depuis or heure, ne_pas_rhabiller = (quoi.ne_pas_rhabiller == true) or nil }
  f.tenues[regle] = tenue
  if not avant or not memes_tenues(avant, tenue) then
    enregistrer()
  end
  ordonner_un_homme(d, id, heure, nil, true)
  return true
end

-- Service : lâcher la tenue d'une règle ; l'homme prend aussitôt ce que dit la règle d'en dessous. Une tenue déjà tombée
-- (fin, sûreté, montée de version) n'a rien à lâcher : rien n'est dit.
function hommes.lacher(id, regle)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not (f.tenues and f.tenues[regle]) then
    return true
  end
  f.tenues[regle] = nil
  enregistrer()
  ordonner_un_homme(d, id, jeu().heure_du_jeu(), nil, true)
  return true
end

-- Service (réponse 3 a de JoVenGer, V73 b) : exempter un homme d'une règle, par exemple un compagnon de la garde de nuit
-- (« garde_de_nuit ») ; l'arbitre et la garde du socle ne la lui donnent plus, et sa tenue de cette règle tombe. « oui »
-- à faux lève l'exemption. Qui est compagnon, c'est Scriptorium qui le décide.
function hommes.exempter(id, regle, oui)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not rang_de(regle) then
    return refuser("regle_inconnue", tostring(regle))
  end
  f.exemptions = f.exemptions or {}
  if oui == false then
    f.exemptions[regle] = nil
  else
    f.exemptions[regle] = true
    if f.tenues then
      f.tenues[regle] = nil
    end
  end
  enregistrer()
  ordonner_un_homme(d, id, jeu().heure_du_jeu(), nil, true)
  return true
end

-- Service pour le guichet (fiche 13, proposé par le pair) : rhabiller cet homme maintenant (sortie du bain, achat à la
-- forge, changement de grade) : il remet ses propres pièces aussitôt (le second passage et l'accroche suivent au
-- battement) ; au lit, au bain ou en combat, il est seulement marqué, pour quand la garde pourra le toucher.
function hommes.rhabiller(id)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not (f.equipement and f.personnage) then
    return refuser("sans_equipement", f.nom)
  end
  local raison = garde_suspendue(id, f)
  if raison then
    f.equipement.etat = "a_rhabiller"
    jeu().journal("Hommes : « " .. f.nom .. " » sera rhabillé plus tard (" .. raison .. ")")
  else
    rhabiller(d, f)
  end
  enregistrer()
  return true
end

-- Service : la règle qui tient l'homme à cette heure (une règle du catalogue, « journee », ou « aucune » quand la
-- journée du socle est coupée), et son activité ({ regle, activite, lieu, position, cap, fin }). Rend nil si l'homme est
-- inconnu.
function hommes.qui_tient(id, heure)
  local a = hommes.activite_de(id, heure or jeu().heure_du_jeu())
  if not a then
    return nil
  end
  return a.regle, a
end

-- Après un chargement : fait revenir les personnages manquants. Rend (revenus, manquants).
function hommes.redresser()
  local d = donnees()
  local revenus, manquants = 0, 0
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local present = f.personnage and jeu().personnage_existe(f.personnage)
    if not present or not f.ame then
      if faire_venir(d, f) then revenus = revenus + 1 else manquants = manquants + 1 end
    end
  end
  if revenus > 0 then
    enregistrer()
  end
  jeu().journal("Hommes : redressés, " .. revenus .. " revenu(s), " .. manquants .. " manquant(s)")
  return revenus, manquants
end

-- Entrée en partie (nouvelle ou chargée). Vu en jeu le 15/10 (V56) : après « Sauvegarder et quitter » puis
-- rechargement, nos personnages sont encore dans le monde et leur cerveau tourne sans réveil, mais ses variables
-- reviennent à zéro : l'ordre en cours est perdu. Chaque homme présent reçoit donc de nouveau son ordre au battement
-- suivant, et les personnages manquants reviennent. Rend (revenus, manquants).
function hommes.relancer()
  local d = donnees()
  hommes.suivi = {}
  hommes.cerveaux_regles = {}
  hommes.arrets_vus = {}
  hommes.fins_de_combat_vues = {}
  hommes.lancements_vus = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    f.derniere_activite = nil
    -- Fiche 13, V71 b : chacun remettra ses propres affaires, un par battement.
    if f.equipement and (f.equipement.etat == "pret" or f.equipement.etat == "a_completer") then
      f.equipement.etat = "a_rhabiller"
    elseif f.equipement and f.equipement.etat == "impossible" then
      f.equipement = nil
    end
  end
  return hommes.redresser()
end

-- Service pour le programme Scriptorium (fiche 13, V71 b) : le grade d'un homme change ; sa famille et son âme
-- restent ; il reçoit au battement suivant la tenue et les armes du nouveau grade ; les pièces de l'ancien grade sont
-- rendues au camp par l'accroche « piece_otee » (réponse a de JoVenGer, 15/10).
function hommes.changer_de_palier(id, palier)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  local nb_paliers = #jeu().paliers_de(hommes.roles[f.role].reserve)
  if type(palier) ~= "number" or math.floor(palier) ~= palier or palier < 1 or palier > math.max(nb_paliers, 1) then
    return refuser("palier_invalide", tostring(palier))
  end
  if palier == f.palier then
    return true
  end
  local e = f.equipement
  local anciennes = {}
  if e and (e.etat == "pret" or e.etat == "a_rhabiller" or e.etat == "a_completer") then
    for _, nom in ipairs({ e.tenue, e.armes }) do
      for _, objet in ipairs(jeu().pieces_de(nom) or {}) do
        table.insert(anciennes, objet)
      end
    end
  end
  f.palier = palier
  if est_combattant(f) and choisir_l_equipement(d, f) then
    f.equipement.otees = {}
    f.equipement.anciennes = #anciennes > 0 and anciennes or nil
  end
  enregistrer()
  jeu().journal("Hommes : « " .. f.nom .. " » passe au palier " .. palier)
  return true
end

-- Service pour le guichet (fiche 13, V71 b) : une pièce donnée à un homme (forge, butin) est créée une à une dans son
-- sac, avec son état ; portée, elle s'ajoute à ce qu'il porte, après sa tenue de grade.
function hommes.donner_une_piece(id, objet, etat, porter)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(objet) ~= "string" or not string.match(objet, "^%x+%-%x+%-%x+%-%x+%-%x+$") then
    return refuser("objet_invalide", tostring(objet))
  end
  etat = etat or hommes.equipement.etat_neuf
  if type(etat) ~= "number" or etat <= 0 or etat > 1 then
    return refuser("etat_invalide", tostring(etat))
  end
  if not (f.personnage and jeu().personnage_existe(f.personnage)) then
    return refuser("homme_absent", f.nom)
  end
  objet = string.lower(objet)
  if not jeu().creer_objet(f.personnage, objet, etat, 1) then
    return refuser("objet_refuse", objet)
  end
  if porter then
    if not f.equipement and est_combattant(f) then
      choisir_l_equipement(d, f)
    end
    f.equipement = f.equipement or { en_plus = {}, otees = {}, naissance_retiree = false, etat = "pret" }
    table.insert(f.equipement.en_plus, { objet = objet, etat = etat })
    jeu().faire_porter(f.personnage, { objet })
  end
  enregistrer()
  jeu().journal("Hommes : une pièce donnée à « " .. f.nom .. " » (" .. objet .. ", état " .. etat .. ")")
  return true
end

-- Accroche du guichet (fiche 13, V71 b) : une pièce qu'il ne porte plus (vendue, cassée, perdue) sort de ce qu'il porte.
function hommes.piece_otee(id, objet)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(objet) ~= "string" then
    return refuser("objet_invalide", tostring(objet))
  end
  objet = string.lower(objet)
  local e = f.equipement
  if not e then
    return refuser("sans_equipement", f.nom)
  end
  for i = #e.en_plus, 1, -1 do
    if objet_de(e.en_plus[i]) == objet then
      table.remove(e.en_plus, i)
      enregistrer()
      return true
    end
  end
  table.insert(e.otees, objet)
  enregistrer()
  return true
end

Scriptorium.declarer_morceau("hommes", function()
  -- Le battement est lancé par le poste d'essai ou par le socle une fois la partie chargée.
end)

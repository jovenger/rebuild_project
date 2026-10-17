-- Le camp : tentes, lits, feux, sièges, coffre. Sa fondation, son agrandissement,
-- son redressement après un chargement, sa levée.
-- Fiche de comportement : docs/socle/fiches/03_camp.md

local Scriptorium = Scriptorium

local camp = {}
Scriptorium.camp = camp

camp.niveau_maximal = 3
camp.proprietaire = "JoVenGer"

-- Les sortes d'objets et leur modèle du jeu de base, appelé par son chemin.
-- Chemins relevés le 14/10 dans les paks du jeu (IPL_Objects-part*.pak) ; les anciens donnaient une forme blanche.
-- Le feu : le foyer de bois du feu de camp du jeu (Prefabs/Procedural/Fireplace/fireplace_on_camp.xml) ;
-- le tas de branches essayé d'abord ne se voyait pas en jeu (14/10). La flamme est chargée sur le foyer (V23).
-- « decalage » : quart de tour propre au modèle, en degrés de boussole, quand son long côté est sur son axe y.
-- Le banc de rondin est long sur x (3,7 m, mesuré dans les paks) : sans décalage, il est en travers du feu
-- (14/10 : un quart de tour essayé le faisait pointer vers le feu).
-- « classe » : classe d'entité du jeu (Chair : Henry peut s'y asseoir ; Bed : y dormir), sinon un simple décor.
-- « allume » : un feu brûle dessus (effet de particules, liaison.allumer).
camp.modeles = {
  feu    = { chemin = "Objects/manmade/task_specific_props/food_processing/cooking/fireplace_wood_c.cgf", allume = true },
  siege  = { chemin = "Objects/manmade/common_furniture/benches/low/bench_log_a.cgf", classe = "Chair" },
  tente  = { chemin = "Objects/manmade/structures/living/tents/tent_small_b.cgf" },
  lit    = { chemin = "Objects/manmade/common_furniture/beds/low/bed_makeshift_a.cgf", classe = "Bed" },
  -- Le premier coffre mesurait 30 cm (mesuré dans les paks le 14/10) : un coffre de 1,6 m.
  coffre = { chemin = "Objects/manmade/common_furniture/chests/chest_fancy_d_big.cgf" },
}

-- Réglages (fiche 03, choix de JoVenGer du 15/10/2026) : à l'entrée en partie, 0 = ne reposer que les objets qui
-- manquent ; 1 = retirer et reposer tout le camp à l'identique (ce qui se faisait depuis le 14/10, quand les objets
-- gardés par la sauvegarde revenaient blancs).
-- « fonder_devant » (réponse de JoVenGer du 16/10/2026, après V72 c) : le centre du camp est posé à tant de mètres
-- devant Henry, pas sous ses pieds (V72 c : Henry debout dans le feu central).
-- « ecart_d_abord » (fiche 15, V73 a) : on ne marche jamais sur un meuble ; on s'arrête à tant de mètres de lui.
camp.reglages = { reposer_tout_a_l_entree = 0, fonder_devant = 4, ecart_d_abord = 2.4 }

-- Les objets du jeu posés sur les meubles du camp pour qu'on puisse s'y asseoir ou s'y coucher (fiche 03, « Meubles
-- utilisables », validée par JoVenGer le 15/10 ; acquis en jeu, V62). Propriétés relevées sur des objets réels du jeu
-- (V65 : un siège bas de banc, un lit de tente). Une place de jeu par meuble (une place du camp = un homme) ; son
-- décalage par rapport au meuble : x à droite, y devant (mètres), cap ajouté à celui du meuble (degrés), réglables.
-- Relevé V65 pour plus tard : sur un vrai banc à deux places, les deux places sont côte à côte, à 0,70 m, même cap.
camp.objets_du_jeu = {
  siege = {
    proprietes = { guidSmartObjectType = "57cbebae-c19a-443b-8945-999d8ee87955", soclass_SmartObjectHelpers = "Sit_1Place_Bench_Low",
                   sWH_AI_EntityCategory = "Seat", Script = { esBedTypes = "Chair" }, Bed = { esReadingQuality = "bench_notable" } },
    -- Vu en jeu (V66) : à cap 0, l'homme assis tournait le dos au feu ; un demi-tour le met face au feu.
    places = { { nom = "assise", x = 0, y = 0, cap = 180 } },
  },
  lit = {
    proprietes = { guidSmartObjectType = "425d4fdf-8dcd-4a2b-fdc5-cbb1b5d25b89", soclass_SmartObjectHelpers = "Bed_1Place_Tent",
                   sWH_AI_EntityCategory = "Bed", Script = { esBedTypes = "GroundBed" },
                   Bed = { esSleepQuality = "low", esReadingQuality = "bed_ground" } },
    -- Vu en jeu (V73 c 13 et c 14) : à cap 0, l'homme se couchait en travers du lit, à moitié hors de sa tente ; un quart
    -- de tour le couche le long du lit (principe transmis par le pair : l'objet de posture d'un lit prend son orientation
    -- à la naissance avec un quart de tour de décalage sur le meuble ; les sièges, symétriques, ne le montrent pas).
    places = { { nom = "couche", x = 0, y = 0, cap = 90 } },
  },
}

-- Les sortes qui sont des places (un homme peut les prendre).
camp.sortes_places = { lit = true, siege = true }

-- Le plan du camp : positions en mètres par rapport à l'ancre (x à droite, y devant),
-- cap en degrés (0 = devant, sens des aiguilles d'une montre vu de dessus), niveau 1 à 3.
local function emplacement(nom, sorte, x, y, cap, niveau, reserve)
  return { nom = nom, sorte = sorte, x = x, y = y, cap = cap, niveau = niveau, reserve = reserve }
end

-- Les lits (V73 c 12, mesures du jeu : tente de (-1,20 ; -1,47) à (1,19 ; 1,67), lit de (-0,44 ; -1,32) à (0,58 ; 0,98),
-- dans le repère de chaque modèle) : deux lits côte à côte dans chaque tente, à -0,60 et 0,46 m de son axe, 0,27 m vers
-- l'avant, même cap que la tente ; le lit du Directeur au milieu de la sienne. Avant, tous dépassaient de leur tente.
camp.plan = {
  -- Niveau 1 : le feu, quatre sièges, la tente du Directeur, deux tentes, le coffre.
  emplacement("feu_central", "feu", 0, 0, 0, 1),
  emplacement("siege_1", "siege", 1.6, 0, 270, 1),
  emplacement("siege_2", "siege", -1.6, 0, 90, 1),
  emplacement("siege_3", "siege", 0, 1.6, 180, 1),
  emplacement("siege_4", "siege", 0, -1.6, 0, 1),
  emplacement("tente_directeur", "tente", 0, 7, 180, 1),
  emplacement("lit_directeur", "lit", 0.07, 6.73, 180, 1, "directeur"),
  emplacement("coffre_camp", "coffre", 1.4, 7.5, 180, 1),
  emplacement("tente_1", "tente", -6, 4, 135, 1),
  emplacement("lit_1a", "lit", -5.38, 4.23, 135, 1),
  emplacement("lit_1b", "lit", -6.13, 3.48, 135, 1),
  emplacement("tente_2", "tente", 6, 4, 225, 1),
  emplacement("lit_2a", "lit", 6.23, 3.38, 225, 1),
  emplacement("lit_2b", "lit", 5.48, 4.13, 225, 1),
  -- Niveau 2 : deux tentes de plus, quatre lits, deux sièges.
  emplacement("tente_3", "tente", -6, -3, 45, 2),
  emplacement("lit_3a", "lit", -6.23, -2.38, 45, 2),
  emplacement("lit_3b", "lit", -5.48, -3.13, 45, 2),
  emplacement("tente_4", "tente", 6, -3, 315, 2),
  emplacement("lit_4a", "lit", 5.38, -3.23, 315, 2),
  emplacement("lit_4b", "lit", 6.13, -2.48, 315, 2),
  emplacement("siege_5", "siege", 1.2, 1.2, 225, 2),
  emplacement("siege_6", "siege", -1.2, -1.2, 45, 2),
  -- Niveau 3 : un second feu avec ses sièges, deux tentes de plus, quatre lits.
  emplacement("feu_2", "feu", 0, -9, 0, 3),
  emplacement("siege_7", "siege", 1.6, -9, 270, 3),
  emplacement("siege_8", "siege", -1.6, -9, 90, 3),
  emplacement("tente_5", "tente", -7, -11, 45, 3),
  emplacement("lit_5a", "lit", -7.23, -10.38, 45, 3),
  emplacement("lit_5b", "lit", -6.48, -11.13, 45, 3),
  emplacement("tente_6", "tente", 7, -11, 315, 3),
  emplacement("lit_6a", "lit", 6.38, -11.23, 315, 3),
  emplacement("lit_6b", "lit", 7.13, -10.48, 315, 3),
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
  return {
    fonde = false,
    ancre = { x = 0, y = 0, z = 0, cap = 0 },
    niveau = 0,
    proprietaire = camp.proprietaire,
    objets = {},   -- nom -> { identifiant }
    places = {},   -- nom -> qui
  }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("camp") then
    registre.declarer_case("camp", 1, donnees_neuves)
  end
  return registre.lire("camp")
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

local function refuser(raison, detail)
  jeu().journal("Camp : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

-- ---------------------------------------------------------------- géométrie

local function normaliser_cap(cap)
  cap = cap % 360
  if cap < 0 then cap = cap + 360 end
  return cap
end

-- Position et cap dans le monde d'un point (x, y, cap) donné par rapport à une ancre.
function camp.dans_le_monde(ancre, x, y, cap)
  local radians = math.rad(ancre.cap)
  local cosinus, sinus = math.cos(radians), math.sin(radians)
  -- Un cap positif tourne dans le sens des aiguilles d'une montre vu de dessus.
  local monde_x = ancre.x + x * cosinus + y * sinus
  local monde_y = ancre.y - x * sinus + y * cosinus
  return { x = monde_x, y = monde_y, z = ancre.z }, normaliser_cap(ancre.cap + (cap or 0))
end

-- Un point du camp (x, y, cap par rapport à l'ancre) dans le monde, ou nil sans camp.
function camp.point(x, y, cap)
  local d = donnees()
  if not d.fonde then
    return nil
  end
  return camp.dans_le_monde(d.ancre, x, y, cap)
end

local function emplacement_par_nom(nom)
  for _, e in ipairs(camp.plan) do
    if e.nom == nom then
      return e
    end
  end
  return nil
end

local function position_valide(position)
  return type(position) == "table"
    and type(position.x) == "number" and type(position.y) == "number" and type(position.z) == "number"
end

-- ---------------------------------------------------------------- pose

-- Pose sur un meuble les objets du jeu de ses places, ceux qui manquent seulement (meubles utilisables).
local function poser_les_objets_du_jeu(e, objet, position, cap)
  local du_jeu = camp.objets_du_jeu[e.sorte]
  if not du_jeu then
    return
  end
  objet.du_jeu = objet.du_jeu or {}
  for _, p in ipairs(du_jeu.places) do
    local deja = objet.du_jeu[p.nom]
    if not (deja and jeu().objet_existe(deja)) then
      local ici, cap_ici = camp.dans_le_monde({ x = position.x, y = position.y, z = position.z, cap = cap }, p.x, p.y, p.cap)
      local identifiant = jeu().poser_objet_du_jeu(e.nom .. "_" .. p.nom, ici, cap_ici, du_jeu.proprietes)
      if identifiant == nil then
        jeu().journal("Camp : le jeu n'a pas posé la place « " .. p.nom .. " » de « " .. e.nom .. " »")
      end
      objet.du_jeu[p.nom] = identifiant
    end
  end
end

-- Retire un objet du camp et les objets du jeu posés dessus.
local function retirer(objet)
  if objet.identifiant then
    jeu().retirer_objet(objet.identifiant)
  end
  for _, identifiant in pairs(objet.du_jeu or {}) do
    jeu().retirer_objet(identifiant)
  end
end

-- Pose un emplacement s'il ne l'est pas déjà, et les objets du jeu de ses places qui manquent. Rend vrai si l'objet est
-- en place.
local function poser(d, e)
  local modele = camp.modeles[e.sorte]
  local position, cap = camp.dans_le_monde(d.ancre, e.x, e.y, e.cap)
  cap = (cap + (modele.decalage or 0)) % 360
  local objet = d.objets[e.nom]
  if not (objet and objet.identifiant and jeu().objet_existe(objet.identifiant)) then
    local identifiant = jeu().poser_objet(e.sorte, modele.chemin, position, cap, e.nom, modele.classe)
    if identifiant == nil then
      jeu().journal("Camp : le jeu n'a pas posé « " .. e.nom .. " » (" .. e.sorte .. ")")
      return false
    end
    if modele.allume then
      jeu().allumer(identifiant)
    end
    objet = { identifiant = identifiant, du_jeu = objet and objet.du_jeu or nil }
    d.objets[e.nom] = objet
  end
  poser_les_objets_du_jeu(e, objet, position, cap)
  return true
end

-- Dresse tous les emplacements jusqu'au niveau courant. Rend (posés, manquants).
local function dresser(d)
  local poses, manquants = 0, 0
  for _, e in ipairs(camp.plan) do
    if e.niveau <= d.niveau then
      if poser(d, e) then poses = poses + 1 else manquants = manquants + 1 end
    end
  end
  return poses, manquants
end

-- ---------------------------------------------------------------- fondation, agrandissement, levée

function camp.est_fonde()
  return donnees().fonde
end

function camp.niveau()
  return donnees().niveau
end

-- Le centre d'un camp fondé par quelqu'un qui se tient à « position » et regarde vers « cap » : à
-- camp.reglages.fonder_devant mètres devant lui (fiche 03). C'est ce point qu'on donne à camp.fonder.
function camp.ancre_devant(position, cap)
  if not position_valide(position) then
    return position
  end
  local devant = tonumber(camp.reglages.fonder_devant) or 0
  local ici = camp.dans_le_monde({ x = position.x, y = position.y, z = position.z, cap = normaliser_cap(cap or 0) }, 0, devant, 0)
  return ici
end

function camp.fonder(position, cap)
  local d = donnees()
  if d.fonde then
    return refuser("deja_fonde")
  end
  if not position_valide(position) then
    return refuser("position_invalide", tostring(position))
  end
  d.fonde = true
  d.ancre = { x = position.x, y = position.y, z = position.z, cap = normaliser_cap(cap or 0) }
  -- Fiche 15, V73 f 3 b : la carte du camp (lue par la liaison ; nil si illisible).
  d.carte = (jeu().carte_courante and (jeu().carte_courante())) or nil
  d.niveau = 1
  d.proprietaire = camp.proprietaire
  d.objets = {}
  d.places = {}
  local poses, manquants = dresser(d)
  enregistrer()
  jeu().journal("Camp : fondé, niveau 1, " .. poses .. " objet(s) posé(s), " .. manquants .. " manquant(s)")
  annoncer("ui_scriptorium_camp_dresse")
  return true
end

function camp.agrandir()
  local d = donnees()
  if not d.fonde then
    return refuser("pas_fonde")
  end
  if d.niveau >= camp.niveau_maximal then
    return refuser("niveau_maximal", tostring(d.niveau))
  end
  d.niveau = d.niveau + 1
  local poses, manquants = dresser(d)
  enregistrer()
  jeu().journal("Camp : agrandi au niveau " .. d.niveau .. ", " .. poses .. " objet(s) en place, " .. manquants .. " manquant(s)")
  annoncer("ui_scriptorium_camp_agrandi")
  return true
end

-- Après un chargement : repose ce qui manque, sans toucher au reste. Rend (reposés, manquants).
-- Fiche 15, V73 f 3 b : le camp appartient à sa carte. Vrai si la carte lue est la sienne, ou si l'une des deux est
-- inconnue (un camp fondé avant V73 f 3 b, une carte illisible : on ne retire jamais rien sur un doute).
function camp.sur_sa_carte()
  local d = donnees()
  if not d.fonde or not d.carte then
    return true
  end
  local ici = jeu().carte_courante and (jeu().carte_courante()) or nil
  return ici == nil or ici == d.carte
end

function camp.carte()
  return donnees().carte
end

-- Un camp fondé avant V73 f 3 b n'a pas de carte notée : il prend la carte lue dès que l'un de ses objets est déjà là
-- (une preuve, jamais un doute). Rend vrai si la carte vient d'être notée.
local function prendre_la_carte_sur_preuve(d)
  if d.carte then
    return false
  end
  local ici = jeu().carte_courante and (jeu().carte_courante()) or nil
  if not ici then
    return false
  end
  for _, objet in pairs(d.objets or {}) do
    if objet.identifiant and jeu().objet_existe(objet.identifiant) then
      d.carte = ici
      jeu().journal("Camp : fondé avant la carte notée ; ses objets sont ici : sa carte est « " .. ici .. " »")
      return true
    end
  end
  return false
end

function camp.redresser()
  local d = donnees()
  if not d.fonde then
    return 0, 0
  end
  prendre_la_carte_sur_preuve(d)
  if not camp.sur_sa_carte() then
    jeu().journal("Camp : sur une autre carte (le camp est sur « " .. tostring(d.carte) .. " ») : rien reposé")
    return 0, 0
  end
  local reposes, manquants = 0, 0
  for _, e in ipairs(camp.plan) do
    if e.niveau <= d.niveau then
      local objet = d.objets[e.nom]
      local present = objet and objet.identifiant and jeu().objet_existe(objet.identifiant)
      if not present then
        if poser(d, e) then reposes = reposes + 1 else manquants = manquants + 1 end
      else
        poser(d, e)  -- le meuble est là : seules ses places du jeu qui manquent sont reposées
      end
    end
  end
  enregistrer()
  jeu().journal("Camp : redressé, " .. reposes .. " objet(s) reposé(s), " .. manquants .. " manquant(s)")
  return reposes, manquants
end

-- Entrée en partie (nouvelle ou chargée). Choix de JoVenGer (15/10) : ne reposer que ce qui manque. Avec le réglage
-- reposer_tout_a_l_entree à 1 : retire et repose tous les objets du camp à l'identique (vu en jeu le 14/10 : les objets
-- gardés par la sauvegarde revenaient blancs, sans texture ; posés à neuf, ils s'affichaient bien).
-- Rend (reposés, manquants).
function camp.relancer()
  local d = donnees()
  if not d.fonde then
    return 0, 0
  end
  if camp.reglages.reposer_tout_a_l_entree ~= 1 or not camp.sur_sa_carte() then
    return camp.redresser()
  end
  for _, objet in pairs(d.objets) do
    retirer(objet)
  end
  d.objets = {}
  local reposes, manquants = dresser(d)
  enregistrer()
  jeu().journal("Camp : reposé à l'entrée en partie, " .. reposes .. " objet(s), " .. manquants .. " manquant(s)")
  return reposes, manquants
end

function camp.lever()
  local d = donnees()
  if not d.fonde then
    return refuser("pas_fonde")
  end
  local retires = 0
  for nom, objet in pairs(d.objets) do
    if objet.identifiant then
      retires = retires + 1
    end
    retirer(objet)
    d.objets[nom] = nil
  end
  d.fonde = false
  d.niveau = 0
  d.places = {}
  d.ancre = { x = 0, y = 0, z = 0, cap = 0 }
  enregistrer()
  jeu().journal("Camp : levé, " .. retires .. " objet(s) retiré(s)")
  annoncer("ui_scriptorium_camp_leve")
  return true
end

-- ---------------------------------------------------------------- places et positions

-- L'objet du jeu d'une place du camp (« siege_1 », « lit_1a ») : là où s'asseoir ou se coucher, ou nil. Son identifiant
-- change à chaque chargement (V64 : rien du camp n'est gardé par la sauvegarde) ; on le relit ici à chaque fois.
function camp.objet_du_jeu_de(nom)
  local objet = donnees().objets[nom]
  local e = emplacement_par_nom(nom)
  local du_jeu = e and camp.objets_du_jeu[e.sorte]
  if not objet or not objet.du_jeu or not du_jeu or not du_jeu.places[1] then
    return nil
  end
  return objet.du_jeu[du_jeu.places[1].nom]
end

-- La sorte d'un emplacement du plan (« siege », « lit », « coffre »…), ou nil.
function camp.sorte_de(nom)
  local e = emplacement_par_nom(nom)
  return e and e.sorte or nil
end

-- Où s'arrêter près d'un emplacement sans marcher dessus (fiche 15, V73 a) : à camp.reglages.ecart_d_abord mètres.
-- Une place (siège, lit) s'aborde du côté opposé au centre du camp (hors du cercle des bancs, hors de la tente) ; un
-- autre meuble (coffre, feu) s'aborde devant lui. Rend une position du monde, ou nil.
function camp.abord_de(nom)
  local d = donnees()
  local e = emplacement_par_nom(nom)
  if not d.fonde or not e or e.niveau > d.niveau then
    return nil
  end
  local ecart = tonumber(camp.reglages.ecart_d_abord) or 0
  local x, y
  local loin = math.sqrt(e.x * e.x + e.y * e.y)
  if camp.sortes_places[e.sorte] and loin > 0.01 then
    x, y = e.x + ecart * e.x / loin, e.y + ecart * e.y / loin
  else
    local radians = math.rad(e.cap or 0)
    x, y = e.x + ecart * math.sin(radians), e.y + ecart * math.cos(radians)
  end
  return (camp.dans_le_monde(d.ancre, x, y, 0))
end

function camp.position_de(nom)
  local d = donnees()
  local e = emplacement_par_nom(nom)
  if not d.fonde or not e or e.niveau > d.niveau then
    return nil
  end
  return camp.dans_le_monde(d.ancre, e.x, e.y, e.cap)
end

function camp.objet_de(nom)
  local objet = donnees().objets[nom]
  return objet and objet.identifiant or nil
end

-- Les places libres d'une sorte (« lit » ou « siege »), dans l'ordre du plan.
-- Avec « pour », les places réservées à quelqu'un d'autre sont écartées.
function camp.places_libres(sorte, pour)
  local d = donnees()
  local libres = {}
  if not d.fonde then
    return libres
  end
  for _, e in ipairs(camp.plan) do
    if e.sorte == sorte and camp.sortes_places[sorte] and e.niveau <= d.niveau and d.places[e.nom] == nil
       and (pour == nil or e.reserve == nil or e.reserve == pour) then
      table.insert(libres, e.nom)
    end
  end
  return libres
end

function camp.occupant_de(nom)
  return donnees().places[nom]
end

function camp.reserver(nom, qui)
  local d = donnees()
  local e = emplacement_par_nom(nom)
  if not d.fonde or not e or not camp.sortes_places[e.sorte] or e.niveau > d.niveau then
    return refuser("place_inconnue", tostring(nom))
  end
  if d.places[nom] ~= nil then
    return refuser("place_prise", nom .. " par " .. tostring(d.places[nom]))
  end
  d.places[nom] = qui
  enregistrer()
  return true
end

function camp.liberer(nom)
  local d = donnees()
  if d.places[nom] == nil then
    return refuser("place_libre", tostring(nom))
  end
  d.places[nom] = nil
  enregistrer()
  return true
end

-- Nombre de lits et de sièges au niveau courant.
function camp.capacite()
  local d = donnees()
  local lits, sieges = 0, 0
  if d.fonde then
    for _, e in ipairs(camp.plan) do
      if e.niveau <= d.niveau then
        if e.sorte == "lit" then lits = lits + 1 end
        if e.sorte == "siege" then sieges = sieges + 1 end
      end
    end
  end
  return { lits = lits, sieges = sieges, niveau = d.niveau }
end

Scriptorium.declarer_morceau("camp", function()
  -- Au démarrage du jeu, aucune partie n'est chargée : le redressement se fait
  -- au chargement d'une partie (voir registre.invalider et la liaison).
end)

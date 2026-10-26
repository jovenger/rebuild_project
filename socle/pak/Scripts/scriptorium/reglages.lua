-- Les réglages par fichier : les valeurs des règles (soldes, rations, prix, butin, pertes, heures, enceinte…)
-- changées sans toucher au code, par un fichier du PC relu en jeu. Règle de JoVenGer du 14/10 : le programme
-- Scriptorium doit pouvoir modifier règles et comportements ; pendant le chantier, outils/regler.py écrit le fichier.
-- Fiche de comportement : docs/socle/fiches/10_reglages.md

local Scriptorium = Scriptorium

local reglages = {}
Scriptorium.reglages = reglages

reglages.cadence_ms = 2000          -- intervalle entre deux relevés du fichier, en partie
reglages.profondeur_maximale = 8    -- un fichier plus profond est refusé (il ne peut pas être un fichier de réglages)

-- Le catalogue : chaque section du fichier désigne une table de valeurs d'un morceau. « parts » : valeurs entre
-- 0 et 1 ; « taux » : valeurs qui acceptent les décimales même quand la valeur validée tombe rond ; « forme » :
-- valeurs que le morceau vérifie (« verifier ») avant de les accepter. Une valeur se reconnaît à son nom, le dernier
-- du chemin.
reglages.catalogue = {
  { section = "socle", morceau = "noyau", table = "reglages" },
  { section = "interrupteurs", morceau = "noyau", table = "interrupteurs" },
  { section = "bandeau", morceau = "bandeau", table = "reglages" },
  { section = "coffre", morceau = "coffre", table = "reglages" },
  { section = "camp", morceau = "camp", table = "reglages", taux = { fonder_devant = true } },
  { section = "meubles", morceau = "camp", table = "objets_du_jeu" },
  { section = "postes_du_jeu", morceau = "camp", table = "genres_de_postes" },
  { section = "hommes", morceau = "hommes", table = "reglages", noms = { sommeil_sol_geste = true }, taux = { secours_progres_m = true, secours_arrivee_m = true, secours_assis_m = true, regard_m = true,
    rassemblement_rayon_m = true, secours_loin_m = true, secours_loin_camp_m = true, secours_vue_cos = true,
    suivi_loin_m = true, suivi_derriere_m = true, cheval_distance_m = true, cheval_retrait_m = true,
    cheval_hors_camp_m = true, cheval_ecart_meuble_m = true, cheval_ecart_cheval_m = true, cheval_pente_max = true,
    cheval_sol_pas_m = true, monte_approche_m_par_s = true, henry_cheval_pres_m = true, allure_arret_m_s = true,
    allure_pas_m_s = true, allure_course_m_s = true, allure_galop_m_s = true, allure_marge = true, allure_place_m = true,
    allure_plus_m = true, allure_moins_m = true, allure_freinage_m = true, allure_saut_m_s = true, allure_perdu_m = true,
    allure_rang_m = true, escorte_derriere_m = true, cheval_saut_m = true,
    henry_bond_m = true, saut_vue_m = true, saut_pose_ecart_m = true, gardien_sous_sol_m = true, fige_but_m = true,
    fige_bouge_m = true, fige_utile_m = true, partage_loin_m = true, partage_attente_m = true } },
  { section = "cerveau", morceau = "hommes", table = "cerveau" },
  { section = "priorites", morceau = "hommes", table = "priorites" },
  { section = "rondes", morceau = "hommes", table = "rondes", taux = { rayon_m = true } },
  { section = "formations", morceau = "hommes", table = "formations" },
  { section = "soldes", morceau = "hommes", table = "roles" },
  { section = "exemptions_des_metiers", morceau = "hommes", table = "exemptions_des_metiers" },
  { section = "rangs", morceau = "hommes", table = "rangs", taux = { soudoyer = true, dizainier = true, capitaine = true } },
  { section = "equipement", morceau = "hommes", table = "equipement", parts = { etat_neuf = true } },
  { section = "compagnons", morceau = "hommes", table = "compagnons" },
  { section = "paliers", morceau = "bataille", table = "paliers", taux = { palier_1 = true, palier_2 = true, palier_3 = true } },
  { section = "bataille", morceau = "bataille", table = "reglages", parts = { part_des_morts = true },
    taux = { bande_vise_henry_m = true, relance_bouge_m = true, relance_pres_m = true, poste_vue_m = true,
             poste_alerte_m = true, poste_engagement_m = true, poste_fuite_m = true } },
  { section = "bandes", morceau = "bataille", table = "sortes", taux = { poids = true } },
  { section = "alerte", morceau = "bataille", table = "alerte", taux = { vue_m = true } },
  { section = "combattants", morceau = "bataille", table = "roles", taux = { poids = true } },
  { section = "issues", morceau = "bataille", table = "issues", parts = { morts = true, blesses = true, butin = true } },
  { section = "journee", morceau = "hommes", table = "journee", taux = { de = true, a = true }, forme = { de = true, a = true },
    verifier = function() return Scriptorium.hommes.verifier_journee() end },
  { section = "journee_du_directeur", morceau = "directeur", table = "journee", taux = { de = true, a = true },
    forme = { de = true, a = true }, verifier = function() return Scriptorium.directeur.verifier_journee() end },
  { section = "prix", morceau = "directeur", table = "prix" },
  { section = "agrandissement", morceau = "directeur", table = "agrandissement" },
  { section = "enceinte", morceau = "enceinte", table = "reglages", forme = { rayon = true, pans = true },
    verifier = function() return Scriptorium.enceinte.verifier_reglages() end },
  { section = "atelier", morceau = "atelier", table = "reglages", parts = { malus_usure = true } },
  { section = "recettes", morceau = "atelier", table = "recettes" },
  { section = "soins", morceau = "atelier", table = "soins" },
  { section = "patrouilles", morceau = "patrouilles", table = "reglages", parts = { part_rodeurs = true, baisse_de_risque = true } },
  { section = "chemins", morceau = "patrouilles", table = "chemins", parts = { risque = true } },
  { section = "missions", morceau = "missions", table = "reglages" },
  { section = "niveaux_des_camps", morceau = "missions", table = "niveaux" },
  { section = "plan_des_camps", morceau = "missions", table = "plan", taux = { x = true, y = true } },
  { section = "lieux_du_socle", morceau = "missions", table = "lieux_du_socle", taux = { x = true, y = true, z = true } },
  { section = "discipline", morceau = "discipline", table = "reglages",
    parts = { chance_de_base = true, chance_morose = true, chance_abattu = true } },
  { section = "fautes", morceau = "discipline", table = "fautes", taux = { poids = true } },
  { section = "caractere", morceau = "caractere", table = "reglages", parts = { malus_fatigue = true, malus_epuise = true, part_hors_du_commun = true } },
}

local function jeu() return Scriptorium.jeu end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

local function section_du_catalogue(nom)
  for _, entree in ipairs(reglages.catalogue) do
    if entree.section == nom then
      return entree
    end
  end
  return nil
end

local function table_de(entree)
  local morceau = Scriptorium[entree.morceau]
  return type(morceau) == "table" and morceau[entree.table] or nil
end

-- Une liste à nom (bataille.issues, discipline.fautes) : ses entrées se désignent par leur nom.
local function est_une_liste_a_nom(t)
  return type(t) == "table" and type(t[1]) == "table" and type(t[1].nom) == "string"
end

-- L'enfant « cle » d'une table de valeurs, par son nom dans une liste à nom.
local function enfant(t, cle)
  if est_une_liste_a_nom(t) then
    for _, element in ipairs(t) do
      if element.nom == cle then
        return element
      end
    end
    return nil
  end
  return t[cle]
end

-- ---------------------------------------------------------------- valeurs validées

-- Chaque valeur réglable : { parent, cle, chemin, valeur validée, entree du catalogue }. Relevées une fois, au
-- chargement du socle, avant toute application du fichier.
local releve = { liste = {}, par_chemin = {} }
-- Un nom réglable (une posture du jeu, un modèle…) : au plus tant de caractères.
reglages.nom_longueur_maximale = 80

local function relever_les_nombres(entree, t, chemin, profondeur)
  if profondeur > reglages.profondeur_maximale then
    return
  end
  if est_une_liste_a_nom(t) then
    for _, element in ipairs(t) do
      relever_les_nombres(entree, element, chemin .. "." .. element.nom, profondeur + 1)
    end
    return
  end
  for cle, valeur in pairs(t) do
    if type(cle) == "string" then
      -- Vu le 21/10 (J27 : la posture du sommeil au sol, un nom, ne se réglait pas) : un nom (lettres, chiffres, « _ ») est
      -- réglable lui aussi, s'il est déclaré dans « noms » de son entrée du catalogue (comme « taux » et « parts ») ; les
      -- textes et les clés de textes ne le sont jamais.
      if type(valeur) == "number"
          or (type(valeur) == "string" and entree.noms and entree.noms[cle] and string.match(valeur, "^[%w_]*$") ~= nil) then
        local fiche = { parent = t, cle = cle, chemin = chemin .. "." .. cle, validee = valeur, entree = entree }
        table.insert(releve.liste, fiche)
        releve.par_chemin[fiche.chemin] = fiche
      elseif type(valeur) == "table" and not (type(valeur[1]) == "table" and valeur[1].nom == nil) then
        relever_les_nombres(entree, valeur, chemin .. "." .. cle, profondeur + 1)
      end
    end
  end
end

function reglages.relever_les_valeurs_validees()
  releve = { liste = {}, par_chemin = {} }
  for _, entree in ipairs(reglages.catalogue) do
    local t = table_de(entree)
    if type(t) == "table" then
      relever_les_nombres(entree, t, entree.section, 1)
    end
  end
  table.sort(releve.liste, function(a, b) return a.chemin < b.chemin end)
  return #releve.liste
end

-- La valeur validée d'un chemin (« hommes.ration »), ou nil.
function reglages.valeur_validee(chemin)
  local fiche = releve.par_chemin[chemin]
  return fiche and fiche.validee or nil
end

-- La valeur en place d'un chemin, ou nil.
function reglages.valeur_en_place(chemin)
  local fiche = releve.par_chemin[chemin]
  return fiche and fiche.parent[fiche.cle] or nil
end

-- Toutes les valeurs réglables, triées par chemin : { chemin, validee, en_place }.
function reglages.liste_des_valeurs()
  local liste = {}
  for i, fiche in ipairs(releve.liste) do
    liste[i] = { chemin = fiche.chemin, validee = fiche.validee, en_place = fiche.parent[fiche.cle] }
  end
  return liste
end

-- ---------------------------------------------------------------- lecture du fichier

-- Forme fixe du contenu lu (noms triés), pour savoir s'il a changé.
local function mettre_en_forme(valeur, profondeur)
  local sorte = type(valeur)
  if sorte == "number" then
    return string.format("%.17g", valeur)
  elseif sorte == "string" then
    return string.format("%q", valeur)
  elseif sorte == "boolean" then
    return tostring(valeur)
  elseif sorte == "table" then
    if profondeur > reglages.profondeur_maximale then
      return "{trop profond}"
    end
    local cles = {}
    for cle in pairs(valeur) do
      table.insert(cles, cle)
    end
    table.sort(cles, function(a, b)
      if type(a) ~= type(b) then return type(a) < type(b) end
      return tostring(a) < tostring(b)
    end)
    local morceaux = {}
    for _, cle in ipairs(cles) do
      table.insert(morceaux, mettre_en_forme(cle, profondeur + 1) .. "=" .. mettre_en_forme(valeur[cle], profondeur + 1))
    end
    return "{" .. table.concat(morceaux, ";") .. "}"
  end
  return "<" .. sorte .. ">"
end

-- Les feuilles du fichier : { chemin, valeur }, et les branches trop profondes.
local function feuilles_du_fichier(t, chemin, profondeur, feuilles)
  for cle, valeur in pairs(t) do
    local ici = (chemin == "") and tostring(cle) or (chemin .. "." .. tostring(cle))
    if type(valeur) == "table" and profondeur < reglages.profondeur_maximale then
      feuilles_du_fichier(valeur, ici, profondeur + 1, feuilles)
    else
      table.insert(feuilles, { chemin = ici, valeur = valeur })
    end
  end
  return feuilles
end

-- Pourquoi un chemin du fichier n'est pas une valeur réglable.
local function raison_d_un_chemin_inconnu(chemin)
  local premier = string.match(chemin, "^[^.]+")
  local entree = section_du_catalogue(premier)
  if not entree then
    return "section_inconnue"
  end
  local t = table_de(entree)
  for cle in string.gmatch(string.sub(chemin, #premier + 2), "[^.]+") do
    if type(t) ~= "table" then
      return "inconnu"
    end
    t = enfant(t, cle)
    if t == nil then
      return "inconnu"
    end
  end
  return "pas_reglable"
end

-- La raison de refuser une valeur, ou nil si elle est acceptable.
local function raison_de_refuser(fiche, valeur)
  if type(fiche.validee) == "string" then
    if type(valeur) ~= "string" or #valeur > reglages.nom_longueur_maximale or string.match(valeur, "^[%w_]*$") == nil then
      return "pas_un_nom"
    end
    return nil
  end
  if type(valeur) ~= "number" or valeur ~= valeur or valeur == math.huge or valeur == -math.huge then
    return "pas_un_nombre"
  end
  local validee, cle, entree = fiche.validee, fiche.cle, fiche.entree
  if (validee >= 0 and valeur < 0) or (validee < 0 and valeur > 0) then
    return "signe"
  end
  local est_une_part = entree.parts and entree.parts[cle]
  if est_une_part and (valeur < 0 or valeur > 1) then
    return "hors_de_0_a_1"
  end
  if string.sub(cle, 1, 6) == "heure_" and (valeur < 0 or valeur >= 24) then
    return "heure_invalide"
  end
  local est_un_taux = entree.taux and entree.taux[cle]
  if not est_une_part and not est_un_taux and math.floor(validee) == validee and math.floor(valeur) ~= valeur then
    return "pas_entier"
  end
  return nil
end

-- ---------------------------------------------------------------- application

local etat = { signature = nil, actif = false, generation = 0 }
-- Ce que le fichier a posé : par chemin, { posee, avant } (la valeur posée, et celle d'avant le fichier).
local poses = {}

local function noter_le_refus(refus, chemin, valeur, raison)
  table.insert(refus, { chemin = chemin, valeur = valeur, raison = raison })
  jeu().journal("Réglages : refusé « " .. chemin .. " » = " .. tostring(valeur) .. " (" .. raison .. ")")
end

local function remettre_les_valeurs_validees()
  for _, fiche in ipairs(releve.liste) do
    fiche.parent[fiche.cle] = fiche.validee
  end
end

local function morceaux_a_prevenir()
  local vus, liste = {}, {}
  for _, entree in ipairs(reglages.catalogue) do
    local morceau = Scriptorium[entree.morceau]
    if not vus[entree.morceau] and type(morceau) == "table" and type(morceau.apres_reglages) == "function" then
      vus[entree.morceau] = true
      table.insert(liste, entree.morceau)
    end
  end
  return liste
end

-- Pose les valeurs du fichier. Rend le nombre de valeurs changées et la liste des refus.
-- Vu sur une copie de la partie de JoVenGer le 20/10 : le fichier remettait d'abord tout le catalogue aux valeurs
-- validées, et effaçait ainsi ce que Scriptorium avait réglé en cours de partie (six valeurs pour une seule posée).
-- Désormais, le fichier ne touche qu'aux valeurs qu'il nomme ; une valeur qu'il ne nomme plus reprend celle d'avant
-- lui, sauf si quelqu'un l'a changée depuis (elle est alors laissée).
function reglages.poser_les_valeurs(donnees, moment)
  local avant = {}
  for i, fiche in ipairs(releve.liste) do
    avant[i] = fiche.parent[fiche.cle]
  end
  -- La valeur d'avant le fichier, pour un chemin qu'il pose ou qu'il refuse.
  local function valeur_d_avant(fiche)
    local p = poses[fiche.chemin]
    return p and p.avant or fiche.parent[fiche.cle]
  end
  local nommes = {}
  for _, feuille in ipairs(feuilles_du_fichier(donnees or {}, "", 1, {})) do
    nommes[feuille.chemin] = true
  end
  for chemin, p in pairs(poses) do
    local fiche = releve.par_chemin[chemin]
    if not nommes[chemin] then
      if fiche and fiche.parent[fiche.cle] == p.posee then
        fiche.parent[fiche.cle] = p.avant
      end
      poses[chemin] = nil
    end
  end
  local refus, du_fichier = {}, {}
  local avant_le_fichier = {}
  local feuilles = feuilles_du_fichier(donnees or {}, "", 1, {})
  table.sort(feuilles, function(a, b) return a.chemin < b.chemin end)
  for _, feuille in ipairs(feuilles) do
    local fiche = releve.par_chemin[feuille.chemin]
    if not fiche then
      noter_le_refus(refus, feuille.chemin, feuille.valeur, raison_d_un_chemin_inconnu(feuille.chemin))
    else
      local raison = raison_de_refuser(fiche, feuille.valeur)
      avant_le_fichier[fiche] = valeur_d_avant(fiche)
      if raison then
        noter_le_refus(refus, feuille.chemin, feuille.valeur, raison)
        fiche.parent[fiche.cle] = avant_le_fichier[fiche]
        poses[fiche.chemin] = nil
      else
        fiche.parent[fiche.cle] = feuille.valeur
        du_fichier[fiche] = true
      end
    end
  end
  -- Paires « …_min » / « …_max » : un minimum au-dessus du maximum refuse ce que le fichier y a mis.
  for _, fiche in ipairs(releve.liste) do
    local racine = string.match(fiche.cle, "^(.*)_min$")
    if racine then
      local autre = releve.par_chemin[string.sub(fiche.chemin, 1, -5) .. "_max"]
      if autre and fiche.parent[fiche.cle] > autre.parent[autre.cle] then
        for _, membre in ipairs({ fiche, autre }) do
          if du_fichier[membre] then
            noter_le_refus(refus, membre.chemin, membre.parent[membre.cle], "min_au_dessus_du_max")
            membre.parent[membre.cle] = avant_le_fichier[membre]
            du_fichier[membre] = nil
          end
        end
      end
    end
  end
  -- La forme : le morceau vérifie ; sinon, ce que le fichier y a mis est refusé.
  for _, entree in ipairs(reglages.catalogue) do
    if entree.verifier and entree.forme then
      local ok, raison = entree.verifier()
      if not ok then
        for _, fiche in ipairs(releve.liste) do
          if fiche.entree == entree and entree.forme[fiche.cle] and du_fichier[fiche] then
            noter_le_refus(refus, fiche.chemin, fiche.parent[fiche.cle], raison)
            fiche.parent[fiche.cle] = avant_le_fichier[fiche]
            du_fichier[fiche] = nil
          end
        end
      end
    end
  end
  for fiche in pairs(avant_le_fichier) do
    if du_fichier[fiche] then
      poses[fiche.chemin] = { posee = fiche.parent[fiche.cle], avant = avant_le_fichier[fiche] }
    else
      poses[fiche.chemin] = nil
    end
  end
  local changes = 0
  for i, fiche in ipairs(releve.liste) do
    if fiche.parent[fiche.cle] ~= avant[i] then
      changes = changes + 1
      jeu().journal("Réglages : « " .. fiche.chemin .. " » = " .. tostring(fiche.parent[fiche.cle])
                    .. " (avant " .. tostring(avant[i]) .. ")")
    end
  end
  if changes > 0 then
    for _, nom in ipairs(morceaux_a_prevenir()) do
      local ok, erreur = pcall(Scriptorium[nom].apres_reglages, moment)
      if not ok then
        jeu().journal("Réglages : « " .. nom .. " » en erreur après les réglages : " .. tostring(erreur))
      end
    end
  end
  return changes, refus
end

-- Un relevé du fichier. Rend { etat, changes, refuses } ; « etat » : absent, inchange, illisible, applique.
-- « moment » : lancement, entree, en_cours. Le joueur n'est prévenu qu'en cours de partie.
function reglages.relever_le_fichier(moment)
  local donnees, chemin, raison = jeu().lire_reglages()
  if raison then
    local signature = "illisible:" .. tostring(raison)
    if signature ~= etat.signature then
      etat.signature = signature
      jeu().journal("Réglages : fichier « " .. tostring(chemin) .. " » illisible, rien n'a changé : " .. tostring(raison))
      if moment == "en_cours" then
        annoncer("ui_scriptorium_reglages_illisible", { importance = "alerte" })
      end
    end
    return { etat = "illisible", changes = 0, refuses = 0 }
  end
  local signature = donnees and mettre_en_forme(donnees, 1) or "absent"
  if signature == etat.signature then
    return { etat = "inchange", changes = 0, refuses = 0 }
  end
  etat.signature = signature
  local changes, refus = reglages.poser_les_valeurs(donnees, moment)
  jeu().journal("Réglages : " .. (donnees and ("fichier « " .. tostring(chemin) .. " » appliqué") or "pas de fichier, valeurs validées")
                .. ", " .. changes .. " changé(s), " .. #refus .. " refusé(s)")
  if moment == "en_cours" and (changes > 0 or #refus > 0) then
    annoncer("ui_scriptorium_reglages_mis_a_jour", { complement = changes .. " changé(s), " .. #refus .. " refusé(s)" })
  end
  return { etat = donnees and "applique" or "absent", changes = changes, refuses = #refus }
end

-- ---------------------------------------------------------------- veille du fichier

function reglages.demarrer()
  if etat.actif then
    return
  end
  etat.actif = true
  etat.generation = etat.generation + 1
  local generation = etat.generation
  local function tour_de_veille()
    if not etat.actif or etat.generation ~= generation then
      return
    end
    local ok, erreur = pcall(reglages.relever_le_fichier, "en_cours")
    if not ok then
      jeu().journal("Réglages : erreur au relevé du fichier : " .. tostring(erreur))
    end
    jeu().minuterie(reglages.cadence_ms, tour_de_veille)
  end
  jeu().minuterie(reglages.cadence_ms, tour_de_veille)
end

function reglages.arreter()
  etat.actif = false
end

-- Entrée en partie : relit le fichier, puis repose la minuterie (celle du lancement ne tire jamais en jeu).
function reglages.relancer()
  etat.actif = false
  reglages.relever_le_fichier("entree")
  reglages.demarrer()
end

-- Pour les essais : les valeurs validées remises, le fichier oublié, la veille arrêtée.
function reglages.remettre_a_zero()
  remettre_les_valeurs_validees()
  poses = {}
  etat.signature = nil
  etat.actif = false
  for _, nom in ipairs(morceaux_a_prevenir()) do
    pcall(Scriptorium[nom].apres_reglages, "lancement")
  end
end

-- Les valeurs validées sont relevées au chargement de ce fichier, chargé après les morceaux qu'il règle.
reglages.relever_les_valeurs_validees()

Scriptorium.declarer_morceau("reglages", function()
  reglages.relever_le_fichier("lancement")
  reglages.demarrer()
end)

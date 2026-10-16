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
  { section = "bandeau", morceau = "bandeau", table = "reglages" },
  { section = "coffre", morceau = "coffre", table = "reglages" },
  { section = "camp", morceau = "camp", table = "reglages", taux = { fonder_devant = true } },
  { section = "meubles", morceau = "camp", table = "objets_du_jeu" },
  { section = "hommes", morceau = "hommes", table = "reglages" },
  { section = "soldes", morceau = "hommes", table = "roles" },
  { section = "rangs", morceau = "hommes", table = "rangs", taux = { soudoyer = true, dizainier = true, capitaine = true } },
  { section = "equipement", morceau = "hommes", table = "equipement", parts = { etat_neuf = true } },
  { section = "bataille", morceau = "bataille", table = "reglages" },
  { section = "bandes", morceau = "bataille", table = "sortes", taux = { poids = true } },
  { section = "combattants", morceau = "bataille", table = "roles", taux = { poids = true } },
  { section = "issues", morceau = "bataille", table = "issues", parts = { morts = true, blesses = true, butin = true },
    taux = { rapport = true } },
  { section = "prix", morceau = "directeur", table = "prix" },
  { section = "agrandissement", morceau = "directeur", table = "agrandissement" },
  { section = "enceinte", morceau = "enceinte", table = "reglages", forme = { rayon = true, pans = true },
    verifier = function() return Scriptorium.enceinte.verifier_reglages() end },
  { section = "atelier", morceau = "atelier", table = "reglages", parts = { malus_usure = true } },
  { section = "recettes", morceau = "atelier", table = "recettes" },
  { section = "soins", morceau = "atelier", table = "soins" },
  { section = "patrouilles", morceau = "patrouilles", table = "reglages", parts = { part_rodeurs = true, baisse_de_risque = true } },
  { section = "chemins", morceau = "patrouilles", table = "chemins", parts = { risque = true } },
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
      if type(valeur) == "number" then
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

-- Remet les valeurs validées puis pose celles du fichier. Rend le nombre de valeurs changées et la liste des refus.
function reglages.poser_les_valeurs(donnees, moment)
  local avant = {}
  for i, fiche in ipairs(releve.liste) do
    avant[i] = fiche.parent[fiche.cle]
  end
  remettre_les_valeurs_validees()
  local refus, du_fichier = {}, {}
  local feuilles = feuilles_du_fichier(donnees or {}, "", 1, {})
  table.sort(feuilles, function(a, b) return a.chemin < b.chemin end)
  for _, feuille in ipairs(feuilles) do
    local fiche = releve.par_chemin[feuille.chemin]
    if not fiche then
      noter_le_refus(refus, feuille.chemin, feuille.valeur, raison_d_un_chemin_inconnu(feuille.chemin))
    else
      local raison = raison_de_refuser(fiche, feuille.valeur)
      if raison then
        noter_le_refus(refus, feuille.chemin, feuille.valeur, raison)
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
            membre.parent[membre.cle] = membre.validee
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
            fiche.parent[fiche.cle] = fiche.validee
            du_fichier[fiche] = nil
          end
        end
      end
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

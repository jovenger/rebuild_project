-- Registre : la sauvegarde des données du camp dans la partie.
-- Fiche de comportement : docs/socle/fiches/01_registre.md
--
-- Chaque morceau déclare sa case : Scriptorium.registre.declarer_case(nom, version, par_defaut, migrations)
--   nom        : nom de la case ("coffre", "camp", …)
--   version    : numéro de version de la forme des données (entier ≥ 1)
--   par_defaut : fonction qui rend les données d'une case neuve
--   migrations : { [1] = fonction(donnees) -> donnees de version 2, [2] = …, … }
-- Scriptorium.registre.lire(nom) rend la table vivante de la case (chargée au besoin).
-- Scriptorium.registre.enregistrer(nom) écrit la case nommée (sans nom : toutes) ; charger() relit tout. Fiche 01 :
-- l'écriture par case (un index léger, une chaîne et ses jetons par case).

local Scriptorium = Scriptorium

local registre = {}
Scriptorium.registre = registre

registre.format = 1   -- version de l'enveloppe { format, cases } de l'ancien flux unique (encore lu)
registre.format_de_l_index = 2   -- fiche 01 : l'index des cases écrites chacune à part

local cases, ordre, charge, contenu_stocke, dernier_rapport
-- Fiche 01, l'écriture par case : les noms de l'index lu, l'index écrit, les cases marquées, la dernière chaîne écrite de
-- chaque case (le détecteur), et la migration de l'ancien flux à faire.
local noms_stockes, index_ecrit, marquees, dernieres_chaines, migration_a_faire, sans_nom_dit

local function jeu()
  return Scriptorium.jeu
end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

function registre.remettre_a_zero()
  cases = {}
  ordre = {}
  charge = false
  contenu_stocke = nil
  dernier_rapport = nil
  noms_stockes, index_ecrit, marquees, dernieres_chaines = {}, nil, {}, {}
  migration_a_faire, sans_nom_dit = false, false
  registre.en_attente = false
  registre.vidage_pose = false
end
registre.remettre_a_zero()

-- ---------------------------------------------------------------- écriture / lecture

local function trier_cles(table_)
  local nombres, chaines = {}, {}
  for cle in pairs(table_) do
    if type(cle) == "number" then
      table.insert(nombres, cle)
    elseif type(cle) == "string" then
      table.insert(chaines, cle)
    else
      error("registre : clé de type " .. type(cle) .. " impossible à enregistrer")
    end
  end
  table.sort(nombres)
  table.sort(chaines)
  return nombres, chaines
end

-- Les nombres courts (note de JoVenGer du 15/10) : un entier sans décimales, un autre nombre à neuf chiffres
-- significatifs (assez pour l'heure du jeu à la seconde près, une fatigue, une part).
local function ecrire_nombre(nombre)
  if nombre ~= nombre or nombre == math.huge or nombre == -math.huge then
    error("registre : nombre impossible à enregistrer")
  end
  if nombre == math.floor(nombre) and math.abs(nombre) < 1e15 then
    return string.format("%.0f", nombre)
  end
  return string.format("%.9g", nombre)
end

local function serialiser_valeur(valeur, morceaux, profondeur)
  local genre = type(valeur)
  if genre == "number" then
    table.insert(morceaux, ecrire_nombre(valeur))
  elseif genre == "string" then
    table.insert(morceaux, string.format("%q", valeur))
  elseif genre == "boolean" then
    table.insert(morceaux, tostring(valeur))
  elseif genre == "table" then
    if profondeur > 32 then
      error("registre : table trop profonde (boucle ?)")
    end
    table.insert(morceaux, "{")
    local nombres, chaines = trier_cles(valeur)
    for _, cle in ipairs(nombres) do
      table.insert(morceaux, "[" .. ecrire_nombre(cle) .. "]=")
      serialiser_valeur(valeur[cle], morceaux, profondeur + 1)
      table.insert(morceaux, ",")
    end
    for _, cle in ipairs(chaines) do
      table.insert(morceaux, "[" .. string.format("%q", cle) .. "]=")
      serialiser_valeur(valeur[cle], morceaux, profondeur + 1)
      table.insert(morceaux, ",")
    end
    table.insert(morceaux, "}")
  else
    error("registre : valeur de type " .. genre .. " impossible à enregistrer")
  end
end

-- Table -> chaîne, toujours la même pour les mêmes données (clés triées).
function registre.serialiser(valeur)
  local morceaux = {}
  serialiser_valeur(valeur, morceaux, 0)
  return table.concat(morceaux)
end

-- Chaîne -> table, ou nil et un message. La chaîne est lue dans un bac à sable sans accès au jeu.
function registre.deserialiser(chaine)
  if type(chaine) ~= "string" or string.sub(chaine, 1, 1) ~= "{" then
    return nil, "chaîne vide ou mal formée"
  end
  local fonction, erreur = loadstring("return " .. chaine, "registre")
  if not fonction then
    return nil, tostring(erreur)
  end
  setfenv(fonction, {})
  local ok, valeur = pcall(fonction)
  if not ok then
    return nil, tostring(valeur)
  end
  if type(valeur) ~= "table" then
    return nil, "le contenu n'est pas une table"
  end
  return valeur
end

-- ---------------------------------------------------------------- cases

local function charger_case(case, stocke, rapport)
  if stocke == nil then
    case.donnees = case.par_defaut()
    case.etat = "neuve"
    rapport.neuves = rapport.neuves + 1
    return
  end
  local function abimee(raison)
    jeu().journal("Registre : case « " .. case.nom .. " » remise à neuf : " .. raison)
    case.donnees = case.par_defaut()
    case.etat = "abimee"
    rapport.abimees = rapport.abimees + 1
  end
  if type(stocke) ~= "table" or type(stocke.version) ~= "number" or type(stocke.donnees) ~= "table" then
    return abimee("contenu mal formé")
  end
  if stocke.version > case.version then
    return abimee("version " .. stocke.version .. " plus récente que le socle (" .. case.version .. ")")
  end
  local donnees, version = stocke.donnees, stocke.version
  while version < case.version do
    local migration = case.migrations[version]
    if type(migration) ~= "function" then
      return abimee("pas de montée de version " .. version .. " -> " .. (version + 1))
    end
    local ok, resultat = pcall(migration, donnees)
    if not ok or type(resultat) ~= "table" then
      return abimee("montée de version " .. version .. " -> " .. (version + 1) .. " en échec : " .. tostring(resultat))
    end
    donnees = resultat
    version = version + 1
  end
  case.donnees = donnees
  if version ~= stocke.version then
    case.etat = "migree"
    rapport.migrees = rapport.migrees + 1
  else
    case.etat = "chargee"
    rapport.chargees = rapport.chargees + 1
  end
end

-- « options » (fiche 01) : { surveillee = false } : la case n'est pas comparée à la fin de chaque battement (une grosse
-- case de Scriptorium, qui nomme elle-même ses écritures). Par défaut, surveillée : rien ne se perd.
function registre.declarer_case(nom, version, par_defaut, migrations, options)
  assert(type(nom) == "string" and nom ~= "", "registre : nom de case manquant")
  assert(type(version) == "number" and version >= 1 and math.floor(version) == version,
         "registre : version de case invalide pour " .. tostring(nom))
  assert(type(par_defaut) == "function", "registre : la valeur par défaut de « " .. nom .. " » doit être une fonction")
  if cases[nom] then
    error("registre : case déjà déclarée : " .. nom)
  end
  local case = { nom = nom, version = version, par_defaut = par_defaut,
                 migrations = migrations or {}, donnees = nil, etat = "non_chargee",
                 surveillee = not (type(options) == "table" and options.surveillee == false) }
  cases[nom] = case
  table.insert(ordre, nom)
  if charge then
    -- Déclarée après le chargement : on la sert tout de suite depuis le contenu lu.
    local rapport = { chargees = 0, neuves = 0, migrees = 0, abimees = 0 }
    charger_case(case, contenu_stocke and contenu_stocke[nom], rapport)
  end
  return case
end

-- Fiche 01 : l'index lu (format 2) : la liste des cases, chacune relue dans ses jetons. Une case listée mais absente ou
-- illisible est notée « false » (elle seule sera remise à neuf). Rend vrai si l'index est lu.
local function lire_par_case(rapport)
  local index = jeu().lire_index and jeu().lire_index() or nil
  if index == nil then
    return false
  end
  local valeur, erreur = registre.deserialiser(index)
  if not (valeur and valeur.format == registre.format_de_l_index and type(valeur.cases) == "table") then
    rapport.source = "illisible"
    jeu().journal("Registre : index illisible, tout est remis à neuf (" .. tostring(erreur or "enveloppe inconnue") .. ")")
    return true
  end
  contenu_stocke = {}
  for _, nom in ipairs(valeur.cases) do
    if type(nom) == "string" then
      noms_stockes[nom] = true
      local chaine_de_la_case = jeu().lire_case(nom)
      local stocke, raison = nil, "absente"
      if chaine_de_la_case ~= nil then
        stocke, raison = registre.deserialiser(chaine_de_la_case)
      end
      if stocke then
        contenu_stocke[nom] = stocke
        dernieres_chaines[nom] = chaine_de_la_case
      else
        contenu_stocke[nom] = false
        jeu().journal("Registre : case « " .. nom .. " » illisible (" .. tostring(raison) .. ")")
      end
    end
  end
  index_ecrit = index
  rapport.source = "lu"
  return true
end

-- Relit tout depuis la partie (ou depuis « chaine », un ancien flux unique, si elle est donnée). Rend un rapport.
function registre.charger(chaine)
  local rapport = { chargees = 0, neuves = 0, migrees = 0, abimees = 0, source = "vide" }
  contenu_stocke = nil
  noms_stockes, index_ecrit, marquees, dernieres_chaines, migration_a_faire = {}, nil, {}, {}, false
  local par_case = chaine == nil and lire_par_case(rapport)
  if not par_case then
    if chaine == nil then
      chaine = jeu().lire_registre()
    end
    if chaine ~= nil then
      local valeur, erreur = registre.deserialiser(chaine)
      if valeur and valeur.format == registre.format and type(valeur.cases) == "table" then
        contenu_stocke = valeur.cases
        rapport.source = "lu"
        -- Fiche 01 : l'ancien flux unique : à la première écriture, tout est réécrit par case.
        migration_a_faire = true
        for nom in pairs(valeur.cases) do noms_stockes[nom] = true end
      else
        rapport.source = "illisible"
        jeu().journal("Registre : contenu illisible, tout est remis à neuf (" .. tostring(erreur or "enveloppe inconnue") .. ")")
      end
    end
  end
  for _, nom in ipairs(ordre) do
    charger_case(cases[nom], contenu_stocke and contenu_stocke[nom], rapport)
  end
  charge = true
  dernier_rapport = rapport
  if rapport.source == "illisible" or rapport.abimees > 0 then
    annoncer("ui_scriptorium_registre_remis_a_neuf")
  elseif rapport.migrees > 0 then
    annoncer("ui_scriptorium_registre_mis_a_jour", { importance = "journal" })
  end
  return rapport
end

-- Oublie ce qui est chargé (à appeler quand le joueur charge une autre partie).
function registre.invalider()
  charge = false
  contenu_stocke = nil
  noms_stockes, index_ecrit, marquees, dernieres_chaines, migration_a_faire = {}, nil, {}, {}, false
  registre.en_attente = false
  registre.vidage_pose = false
  for _, nom in ipairs(ordre) do
    cases[nom].donnees = nil
    cases[nom].etat = "non_chargee"
  end
end

-- Rend la table vivante de la case. Les morceaux la modifient directement, puis appellent enregistrer().
function registre.lire(nom)
  local case = cases[nom]
  if not case then
    error("registre : case inconnue : " .. tostring(nom))
  end
  if not charge then
    registre.charger()
  end
  if case.donnees == nil then
    case.donnees = case.par_defaut()
    case.etat = "neuve"
  end
  return case.donnees
end

function registre.etat_de(nom)
  local case = cases[nom]
  return case and case.etat or nil
end

-- Remet une case à neuf (données par défaut). N'enregistre pas.
function registre.remettre_a_neuf(nom)
  local case = cases[nom]
  if not case then
    error("registre : case inconnue : " .. tostring(nom))
  end
  case.donnees = case.par_defaut()
  case.etat = "neuve"
  return case.donnees
end

-- Fiche 01 (demandes du pair, 17/10 : Scriptorium écrit plusieurs clés à chaque battement) : l'écriture PAR CASE et
-- REGROUPÉE. Seules les cases marquées sont sérialisées et écrites, chacune dans ses jetons ; l'index (la liste des
-- cases) seulement quand il change. Une écriture au plus par « registre_intervalle_s » secondes réelles (réglage du
-- noyau) ; une demande plus rapprochée attend, vidée par une minuterie à la fin de l'intervalle (ou par le battement
-- commun, registre.vider, s'il passe avant). Mesuré au banc avant
-- l'écriture par case : 10 000 clés, 1 Mo, 34 ms ; 50 000 clés, 5 Mo, 203 ms.
registre.en_attente = false
local derniere_ecriture = nil

local function reglage(nom)
  return tonumber(Scriptorium.noyau and Scriptorium.noyau.reglages and Scriptorium.noyau.reglages[nom]) or 0
end

-- Fiche 01 (vu en jeu le 17/10 : le Directeur installé et ses objets donnés, la partie sauvegardée 10 s après : tout
-- perdu, l'écriture attendait le battement de 30 s) : une écriture mise en attente est vidée par une minuterie dès que
-- l'intervalle est passé, sans attendre le battement. Une seule minuterie à la fois ; une partie oubliée entre-temps
-- (registre.invalider) : rien n'est écrit. La fenêtre de perte au plus tôt : l'intervalle (2 s).
local function poser_le_vidage(t, intervalle)
  if registre.vidage_pose or not jeu().minuterie then
    return
  end
  registre.vidage_pose = true
  local reste = intervalle - ((t and derniere_ecriture and t >= derniere_ecriture) and (t - derniere_ecriture) or 0)
  jeu().minuterie(math.max(100, math.floor(reste * 1000 + 0.5)), function()
    registre.vidage_pose = false
    if charge and registre.en_attente then
      local ok, erreur = pcall(registre.vider)
      if not ok then
        jeu().journal("Registre : vidage de l'attente en erreur : " .. tostring(erreur))
      end
    end
  end)
end

local function chaine_de(case)
  return registre.serialiser({ version = case.version, donnees = case.donnees })
end

local function ecrire_maintenant()
  if not charge then
    registre.charger()
  end
  local debut = jeu().chrono and (jeu().chrono()) or nil
  -- L'ancien flux : toutes ses cases connues sont réécrites (avant de le vider), pas seulement les nommées.
  if migration_a_faire then
    for nom in pairs(contenu_stocke or {}) do
      if cases[nom] and cases[nom].donnees ~= nil then
        marquees[nom] = true
      end
    end
  end
  local ecrites, octets = 0, 0
  for _, nom in ipairs(ordre) do
    local case = cases[nom]
    if marquees[nom] and case.donnees ~= nil then
      local chaine = chaine_de(case)
      jeu().ecrire_case(nom, chaine)
      dernieres_chaines[nom] = chaine
      noms_stockes[nom] = true
      ecrites, octets = ecrites + 1, octets + #chaine
    end
  end
  -- L'ancien flux unique : ses cases inconnues du socle sont écrites chacune à part, une fois ; puis il est vidé.
  if migration_a_faire then
    for nom, stocke in pairs(contenu_stocke or {}) do
      -- Inconnue du socle, ou connue mais jamais lue (ses données pas encore chargées) : telle quelle.
      if (not cases[nom] or cases[nom].donnees == nil) and type(stocke) == "table" then
        local chaine = registre.serialiser(stocke)
        jeu().ecrire_case(nom, chaine)
        ecrites, octets = ecrites + 1, octets + #chaine
      end
    end
  end
  local noms = {}
  for nom in pairs(noms_stockes) do table.insert(noms, nom) end
  table.sort(noms)
  local index = registre.serialiser({ format = registre.format_de_l_index, cases = noms })
  if index ~= index_ecrit then
    jeu().ecrire_index(index)
    index_ecrit = index
  end
  if migration_a_faire then
    jeu().effacer_l_ancien_registre()
    migration_a_faire = false
    jeu().journal("Registre : l'ancien flux réécrit par case (" .. #noms .. " case(s))")
  end
  marquees = {}
  registre.en_attente = false
  derniere_ecriture = jeu().maintenant and jeu().maintenant() or nil
  if reglage("registre_journal") == 1 then
    local fin = jeu().chrono and (jeu().chrono()) or nil
    jeu().journal(string.format("Registre : écrit, %d case(s), %d octets, %s ms", ecrites, octets,
      (debut and fin) and string.format("%.1f", (fin - debut) * 1000) or "?"))
  end
  return ecrites
end

-- Marque la case nommée (sans nom : toutes, une ligne au journal la première fois), puis écrit, ou met en attente.
-- « forcer » écrit tout de suite. Rend le nombre de cases écrites, ou nil si l'écriture attend.
function registre.enregistrer(nom, forcer)
  if not charge then
    registre.charger()
  end
  if nom == nil then
    for _, n in ipairs(ordre) do marquees[n] = true end
    if not sans_nom_dit then
      sans_nom_dit = true
      jeu().journal("Registre : enregistrer sans nom de case : toutes les cases sont écrites (nommer sa case)")
    end
  elseif cases[nom] then
    marquees[nom] = true
  else
    error("registre : case inconnue : " .. tostring(nom))
  end
  local intervalle = reglage("registre_intervalle_s")
  local t = jeu().maintenant and jeu().maintenant() or nil
  if forcer or migration_a_faire or intervalle <= 0 or not t or not derniere_ecriture or t < derniere_ecriture
      or t - derniere_ecriture >= intervalle then
    return ecrire_maintenant()
  end
  registre.en_attente = true
  poser_le_vidage(t, intervalle)
  return nil
end

-- Vide l'écriture en attente (le battement commun). Rend le nombre de cases écrites, ou nil.
function registre.vider()
  if registre.en_attente then
    return ecrire_maintenant()
  end
  return nil
end

-- Fiche 01 (relecture, 17/10) : à la fin de chaque battement, chaque case surveillée (déjà chargée) est comparée à sa
-- dernière chaîne écrite ; changée sans avoir été nommée (le moral, la dernière activité…), elle est marquée, puis
-- écrite (au plus une fois par intervalle, sinon au battement suivant). Rend le nombre de cases marquées ainsi.
function registre.surveiller()
  if not charge then
    return 0
  end
  local nouvelles = 0
  for _, nom in ipairs(ordre) do
    local case = cases[nom]
    if case.surveillee and case.donnees ~= nil and not marquees[nom] and chaine_de(case) ~= dernieres_chaines[nom] then
      marquees[nom] = true
      nouvelles = nouvelles + 1
    end
  end
  if next(marquees) ~= nil then
    local intervalle = reglage("registre_intervalle_s")
    local t = jeu().maintenant and jeu().maintenant() or nil
    if intervalle <= 0 or not t or not derniere_ecriture or t < derniere_ecriture or t - derniere_ecriture >= intervalle then
      ecrire_maintenant()
    else
      registre.en_attente = true
      poser_le_vidage(t, intervalle)
    end
  end
  return nouvelles
end

-- La chaîne de la case telle qu'elle serait écrite (pour le poste d'essai et les essais), ou nil.
function registre.chaine_de_la_case(nom)
  local case = cases[nom]
  return case and case.donnees ~= nil and chaine_de(case) or nil
end

function registre.dernier_rapport()
  return dernier_rapport
end

function registre.cases_declarees()
  local copie = {}
  for i, nom in ipairs(ordre) do
    copie[i] = nom
  end
  return copie
end

Scriptorium.declarer_morceau("registre", function()
  -- Rien à lancer : le registre se charge au premier lire().
end)

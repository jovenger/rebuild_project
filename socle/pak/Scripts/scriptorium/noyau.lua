-- Noyau du socle : la table Scriptorium, la liste des morceaux et le démarrage.
-- Chaque morceau se déclare avec Scriptorium.declarer_morceau(nom, demarrage).
-- Scriptorium.demarrer() lance les morceaux dans l'ordre de déclaration ;
-- un morceau qui échoue est annoncé en clair et ne bloque pas les suivants.

-- La table du socle (note de JoVenGer, partie 2, point 5 : un seul nom par table). Elle s'appelle aujourd'hui
-- « Scriptorium », à côté du mod actuel « scriptorium » ; à la bascule, elle deviendra la sous-table
-- « scriptorium.socle ». Seul ce fichier la pose ; chaque autre fichier la reprend par sa première ligne,
-- « local Scriptorium = Scriptorium », seule ligne à changer à la bascule. « chemin » sert aux chaînes que le jeu
-- exécute (commandes de la console). Aucun autre nom du socle ne diffère d'un autre par une majuscule seulement.
Scriptorium = Scriptorium or {}
Scriptorium.chemin = "Scriptorium"
Scriptorium.version = "0.1.0"
Scriptorium.nom_du_mod = "scriptorium_socle"
Scriptorium.morceaux = Scriptorium.morceaux or {}
Scriptorium.demarre = Scriptorium.demarre or false
Scriptorium.cadence_du_battement_ms = 30000
Scriptorium.generation = Scriptorium.generation or 0   -- change à chaque entrée et sortie de partie
Scriptorium.en_partie = Scriptorium.en_partie or false
-- L'ordre dans lequel les morceaux battent (ceux qui ont une fonction battre).
Scriptorium.ordre_du_battement = { "bataille", "hommes", "discipline", "directeur", "enceinte", "atelier", "patrouilles" }

local function jeu()
  return Scriptorium.jeu
end

local function journal(texte)
  if Scriptorium.jeu and Scriptorium.jeu.journal then
    Scriptorium.jeu.journal(texte)
  end
end

-- Déclare un morceau. Un morceau redéclaré (rechargement du script) remplace l'ancien.
function Scriptorium.declarer_morceau(nom, demarrage)
  assert(type(nom) == "string" and nom ~= "", "socle : nom de morceau manquant")
  assert(type(demarrage) == "function", "socle : le démarrage d'un morceau est une fonction")
  for _, morceau in ipairs(Scriptorium.morceaux) do
    if morceau.nom == nom then
      morceau.demarrage = demarrage
      morceau.pret = false
      morceau.erreur = nil
      return morceau
    end
  end
  local morceau = { nom = nom, demarrage = demarrage, pret = false, erreur = nil }
  table.insert(Scriptorium.morceaux, morceau)
  return morceau
end

-- Lance tous les morceaux. Rend le nombre de morceaux prêts et le nombre en panne.
function Scriptorium.demarrer()
  if Scriptorium.demarre then
    journal("Socle : déjà démarré, rien à refaire")
    return Scriptorium.bilan()
  end
  assert(jeu(), "socle : la liaison avec le jeu n'est pas chargée")
  for _, morceau in ipairs(Scriptorium.morceaux) do
    local ok, erreur = pcall(morceau.demarrage)
    morceau.pret = ok
    morceau.erreur = ok and nil or tostring(erreur)
    if ok then
      journal("Socle : morceau « " .. morceau.nom .. " » prêt")
    else
      journal("Socle : morceau « " .. morceau.nom .. " » en panne : " .. morceau.erreur)
    end
  end
  Scriptorium.demarre = true
  Scriptorium.lancer_le_battement()
  if jeu().ecouter_la_partie then
    jeu().ecouter_la_partie(Scriptorium.entrer_en_partie, Scriptorium.sortir_de_partie)
  end
  local prets, pannes = Scriptorium.bilan()
  journal("Socle " .. Scriptorium.version .. " : " .. prets .. " morceau(x) prêt(s), " .. pannes .. " en panne")
  return prets, pannes
end

-- Entrée en partie (nouvelle ou chargée), signalée par le jeu. Les minuteries posées au démarrage du mod
-- ne tirent jamais en jeu (constaté le 14/10) : on les repose ici. Une ancienne boucle encore vivante
-- s'éteint d'elle-même (génération). Le registre est relu (V5) et le joueur apprend que le socle est prêt.
function Scriptorium.entrer_en_partie()
  Scriptorium.generation = Scriptorium.generation + 1
  Scriptorium.en_partie = true
  journal("Socle : entrée en partie, minuteries reposées")
  if Scriptorium.registre then
    Scriptorium.registre.invalider()
  end
  Scriptorium.battement_lance = false
  Scriptorium.lancer_le_battement()
  for _, morceau in ipairs(Scriptorium.morceaux) do
    local table_du_morceau = Scriptorium[morceau.nom]
    if morceau.pret and type(table_du_morceau) == "table" and type(table_du_morceau.relancer) == "function" then
      local ok, erreur = pcall(table_du_morceau.relancer)
      if not ok then
        journal("Socle : relance de « " .. morceau.nom .. " » en erreur : " .. tostring(erreur))
      end
    end
  end
  local _, pannes = Scriptorium.bilan()
  if Scriptorium.bandeau then
    if pannes > 0 then
      Scriptorium.bandeau.annoncer("ui_scriptorium_socle_morceau_en_panne", { importance = "alerte" })
    else
      Scriptorium.bandeau.annoncer("ui_scriptorium_socle_pret")
    end
  end
end

-- Sortie de partie (retour au menu) : les boucles s'arrêtent jusqu'à la prochaine entrée.
function Scriptorium.sortir_de_partie()
  Scriptorium.generation = Scriptorium.generation + 1
  Scriptorium.en_partie = false
  Scriptorium.battement_lance = false
  for _, morceau in ipairs(Scriptorium.morceaux) do
    local table_du_morceau = Scriptorium[morceau.nom]
    if type(table_du_morceau) == "table" and type(table_du_morceau.relancer) == "function"
       and type(table_du_morceau.arreter) == "function" then
      pcall(table_du_morceau.arreter)
    end
  end
  journal("Socle : sortie de partie")
end

function Scriptorium.bilan()
  local prets, pannes = 0, 0
  for _, morceau in ipairs(Scriptorium.morceaux) do
    if morceau.pret then prets = prets + 1 else pannes = pannes + 1 end
  end
  return prets, pannes
end

-- Un battement du camp : chaque morceau avance jusqu'à l'heure du jeu, seulement quand une partie est en cours.
-- Un morceau qui casse ne bloque pas les autres.
function Scriptorium.battre()
  local rapport = { morceaux = {}, erreurs = 0 }
  if jeu().partie_en_cours and not jeu().partie_en_cours() then
    rapport.saute = true
    return rapport
  end
  for _, nom in ipairs(Scriptorium.ordre_du_battement) do
    local morceau = Scriptorium[nom]
    if type(morceau) == "table" and type(morceau.battre) == "function" then
      local ok, erreur = pcall(morceau.battre)
      if ok then
        table.insert(rapport.morceaux, nom)
      else
        rapport.erreurs = rapport.erreurs + 1
        journal("Battement de « " .. nom .. " » en erreur : " .. tostring(erreur))
      end
    end
  end
  return rapport
end

function Scriptorium.lancer_le_battement()
  if Scriptorium.battement_lance then
    return
  end
  Scriptorium.battement_lance = true
  local generation = Scriptorium.generation
  local function battement()
    if not Scriptorium.battement_lance or generation ~= Scriptorium.generation then
      return
    end
    Scriptorium.battre()
    jeu().minuterie(Scriptorium.cadence_du_battement_ms, battement)
  end
  jeu().minuterie(Scriptorium.cadence_du_battement_ms, battement)
end

function Scriptorium.arreter_le_battement()
  Scriptorium.battement_lance = false
end

-- Le hasard du socle, gardé au registre par chaque morceau qui en a besoin (Wichmann et Hill, 1982 : trois suites
-- mêlées). Le Lua du jeu compte en simple précision (vu en jeu le 15/10 : 16777217 s'y écrit 1.67772e+07, et
-- (2147483646 × 16807) mod 2147483647 y vaut 0) : ici, aucun calcul ne dépasse 172 × 30306 = 5 212 632, sous
-- 2^24 = 16 777 216 ; la suite est donc la même dans le jeu et au banc.
Scriptorium.modules_du_hasard = { 30269, 30307, 30323 }
Scriptorium.facteurs_du_hasard = { 171, 172, 170 }

-- Trois germes tirés d'un nombre quelconque (une ancienne graine, une graine d'essai). Les divisions par deux sont
-- justes en simple précision ; sous 2^20, les restes le sont aussi.
function Scriptorium.hasard_depuis(graine)
  local n = tonumber(graine) or 1
  if n ~= n or n == math.huge or n == -math.huge then
    n = 1
  end
  n = math.floor(math.abs(n))
  while n >= 1048576 do
    n = math.floor(n / 2)
  end
  local etat = {}
  for i, module in ipairs(Scriptorium.modules_du_hasard) do
    etat[i] = (n + 97 * i) % (module - 1) + 1
  end
  return etat
end

-- Vrai si la valeur est un état du hasard en bon ordre : trois entiers, chacun entre 1 et son module moins un.
function Scriptorium.hasard_en_ordre(etat)
  if type(etat) ~= "table" then
    return false
  end
  for i, module in ipairs(Scriptorium.modules_du_hasard) do
    local valeur = etat[i]
    if type(valeur) ~= "number" or valeur ~= math.floor(valeur) or valeur < 1 or valeur >= module then
      return false
    end
  end
  return true
end

-- Un tirage entre 0 (compris) et 1 (exclu) ; l'état avance.
function Scriptorium.tirer(etat)
  local somme = 0
  for i, module in ipairs(Scriptorium.modules_du_hasard) do
    etat[i] = (Scriptorium.facteurs_du_hasard[i] * etat[i]) % module
    somme = somme + etat[i] / module
  end
  return somme % 1
end

-- Pour les essais : oublie le démarrage, sans toucher aux morceaux déclarés.
function Scriptorium.remettre_a_zero()
  Scriptorium.demarre = false
  Scriptorium.battement_lance = false
  Scriptorium.en_partie = false
  for _, morceau in ipairs(Scriptorium.morceaux) do
    morceau.pret = false
    morceau.erreur = nil
  end
end

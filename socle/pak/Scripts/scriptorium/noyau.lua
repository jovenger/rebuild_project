-- Noyau du socle : la table Scriptorium, la liste des morceaux et le démarrage.
-- Chaque morceau se déclare avec Scriptorium.declarer_morceau(nom, demarrage).
-- Scriptorium.demarrer() lance les morceaux dans l'ordre de déclaration ;
-- un morceau qui échoue est annoncé en clair et ne bloque pas les suivants.

Scriptorium = Scriptorium or {}
Scriptorium.version = "0.1.0"
Scriptorium.nom_du_mod = "scriptorium_socle"
Scriptorium.morceaux = Scriptorium.morceaux or {}
Scriptorium.demarre = Scriptorium.demarre or false
Scriptorium.cadence_du_battement_ms = 30000
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
  local prets, pannes = Scriptorium.bilan()
  if Scriptorium.bandeau then
    if pannes > 0 then
      Scriptorium.bandeau.annoncer("ui_scriptorium_socle_morceau_en_panne", { importance = "alerte" })
    else
      Scriptorium.bandeau.annoncer("ui_scriptorium_socle_pret")
    end
  end
  journal("Socle " .. Scriptorium.version .. " : " .. prets .. " morceau(x) prêt(s), " .. pannes .. " en panne")
  return prets, pannes
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
  local function battement()
    if not Scriptorium.battement_lance then
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

-- Pour les essais : oublie le démarrage, sans toucher aux morceaux déclarés.
function Scriptorium.remettre_a_zero()
  Scriptorium.demarre = false
  Scriptorium.battement_lance = false
  for _, morceau in ipairs(Scriptorium.morceaux) do
    morceau.pret = false
    morceau.erreur = nil
  end
end

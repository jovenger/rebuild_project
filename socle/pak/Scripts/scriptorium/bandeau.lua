-- Bandeau des messages : la seule porte de sortie vers l'écran du joueur.
-- Fiche de comportement : docs/socle/fiches/00_bandeau.md
--
-- Scriptorium.bandeau.annoncer(cle, options) met un message en file.
--   cle      : clé de texte, de la forme ui_scriptorium_<morceau>_<sujet> (sans « @ »).
--   options  : { importance = "alerte" | "nouvelle" | "journal",
--                duree = secondes, groupe = "nom", cle_plusieurs = "clé du message groupé",
--                complement = "texte ajouté après le message (un nom, un montant)",
--                qui = "clé du nom affiché à part, comme celui qui parle (l'alerte)" }
-- Scriptorium.bandeau.battre() fait avancer le bandeau ; demarrer() le fait battre tout seul.

local Scriptorium = Scriptorium

local bandeau = {}
Scriptorium.bandeau = bandeau

bandeau.reglages = {
  duree_par_defaut = 5,     -- secondes à l'écran quand le message n'en fixe pas
  duree_min = 3,
  duree_max = 8,
  delai_repetition = 30,    -- un même message n'est pas redit avant ce délai (secondes)
  taille_historique = 20,   -- derniers messages gardés pour la relecture
  cadence_ms = 500,         -- intervalle entre deux battements
}

bandeau.importances = { alerte = 3, nouvelle = 2, journal = 1 }

local etat

local function jeu()
  return Scriptorium.jeu
end

function bandeau.remettre_a_zero()
  etat = {
    file = {},            -- messages en attente, dans l'ordre d'affichage
    en_cours = nil,       -- { message, debut, fin } pendant l'affichage
    dernieres = {},       -- clé -> dernier moment d'annonce
    historique = {},      -- derniers messages, du plus ancien au plus récent
    comptes = { affiches = 0, repetes = 0, regroupes = 0, refuses = 0, journal = 0 },
    actif = false,
  }
end
bandeau.remettre_a_zero()

local function cle_valide(cle)
  return type(cle) == "string" and string.find(cle, "^ui_scriptorium_[%w_]+$") ~= nil
end

local function borner(valeur, mini, maxi)
  if valeur < mini then return mini end
  if valeur > maxi then return maxi end
  return valeur
end

local function texte_du_message(message)
  if message.nombre > 1 and message.cle_plusieurs then
    return "@" .. message.cle_plusieurs
  end
  return "@" .. message.cle
end

local function inscrire_historique(message, sort)
  table.insert(etat.historique, {
    cle = message.cle,
    importance = message.importance,
    complement = message.complement,
    nombre = message.nombre,
    temps = jeu().maintenant(),
    sort = sort,
  })
  while #etat.historique > bandeau.reglages.taille_historique do
    table.remove(etat.historique, 1)
  end
end

-- Rend le sort du message : "en_file", "regroupe", "repete", "journal" ou "refuse".
function bandeau.annoncer(cle, options)
  options = options or {}
  local maintenant = jeu().maintenant()

  if not cle_valide(cle) then
    etat.comptes.refuses = etat.comptes.refuses + 1
    jeu().journal("Bandeau : clé refusée « " .. tostring(cle) .. " » (attendu : ui_scriptorium_…)")
    return "refuse"
  end
  local importance = options.importance or "nouvelle"
  if not bandeau.importances[importance] then
    etat.comptes.refuses = etat.comptes.refuses + 1
    jeu().journal("Bandeau : importance inconnue « " .. tostring(importance) .. " » pour " .. cle)
    return "refuse"
  end
  if options.qui ~= nil and not cle_valide(options.qui) then
    etat.comptes.refuses = etat.comptes.refuses + 1
    jeu().journal("Bandeau : clé du nom refusée « " .. tostring(options.qui) .. " »")
    return "refuse"
  end
  if options.cle_plusieurs ~= nil and not cle_valide(options.cle_plusieurs) then
    etat.comptes.refuses = etat.comptes.refuses + 1
    jeu().journal("Bandeau : clé groupée refusée « " .. tostring(options.cle_plusieurs) .. " »")
    return "refuse"
  end

  local message = {
    cle = cle,
    importance = importance,
    duree = options.duree,
    groupe = options.groupe,
    cle_plusieurs = options.cle_plusieurs,
    qui = options.qui,
    complement = (type(options.complement) == "string" or type(options.complement) == "number")
                 and tostring(options.complement) or nil,
    nombre = 1,
    cree = maintenant,
  }

  -- Importance « journal » : jamais à l'écran, seulement dans le journal et l'historique.
  if importance == "journal" then
    etat.comptes.journal = etat.comptes.journal + 1
    jeu().journal("Bandeau (journal) : " .. cle)
    inscrire_historique(message, "journal")
    return "journal"
  end

  -- Regroupement : un message du même groupe attend déjà, on le grossit.
  if message.groupe then
    for _, attente in ipairs(etat.file) do
      if attente.groupe == message.groupe then
        attente.nombre = attente.nombre + 1
        etat.comptes.regroupes = etat.comptes.regroupes + 1
        return "regroupe"
      end
    end
  end

  -- Répétition : le même message a été annoncé il y a moins de « delai_repetition ».
  local derniere = etat.dernieres[cle]
  if derniere and (maintenant - derniere) < bandeau.reglages.delai_repetition then
    etat.comptes.repetes = etat.comptes.repetes + 1
    return "repete"
  end
  etat.dernieres[cle] = maintenant

  -- Place dans la file : une alerte passe devant tout ce qui n'est pas une alerte.
  if importance == "alerte" then
    local place = #etat.file + 1
    for i, attente in ipairs(etat.file) do
      if attente.importance ~= "alerte" then
        place = i
        break
      end
    end
    table.insert(etat.file, place, message)
  else
    table.insert(etat.file, message)
  end
  return "en_file"
end

-- Un battement : efface le message fini, puis affiche le suivant si rien ne l'empêche.
-- Rend l'affichage en cours ({ message, debut, fin }) ou nil.
function bandeau.battre()
  local maintenant = jeu().maintenant()

  if etat.en_cours and maintenant >= etat.en_cours.fin then
    jeu().effacer()
    etat.en_cours = nil
  end
  if etat.en_cours then
    return etat.en_cours
  end
  if #etat.file == 0 then
    return nil
  end
  if jeu().dialogue_en_cours() then
    return nil
  end

  local message = table.remove(etat.file, 1)
  local duree = borner(message.duree or bandeau.reglages.duree_par_defaut,
                       bandeau.reglages.duree_min, bandeau.reglages.duree_max)
  -- Un message regroupé perd son complément : il parle de plusieurs.
  local complement = message.complement
  if message.nombre > 1 and message.cle_plusieurs then
    complement = nil
  end
  jeu().afficher(texte_du_message(message), duree, complement, message.qui and ("@" .. message.qui) or nil)
  etat.en_cours = { message = message, debut = maintenant, fin = maintenant + duree }
  etat.comptes.affiches = etat.comptes.affiches + 1
  inscrire_historique(message, "affiche")
  return etat.en_cours
end

-- Fait battre le bandeau tout seul, à la cadence réglée.
function bandeau.demarrer()
  if etat.actif then
    return
  end
  etat.actif = true
  etat.generation = (etat.generation or 0) + 1
  local generation = etat.generation
  local function battement()
    if not etat.actif or etat.generation ~= generation then
      return
    end
    local ok, erreur = pcall(bandeau.battre)
    if not ok then
      jeu().journal("Bandeau : erreur au battement : " .. tostring(erreur))
    end
    jeu().minuterie(bandeau.reglages.cadence_ms, battement)
  end
  jeu().minuterie(bandeau.reglages.cadence_ms, battement)
end

function bandeau.arreter()
  etat.actif = false
end

-- Entrée en partie : repose la minuterie (celle du démarrage du mod ne tire jamais en jeu).
-- Une ancienne boucle encore vivante s'éteint d'elle-même à son prochain tour.
function bandeau.relancer()
  etat.actif = false
  bandeau.demarrer()
end

function bandeau.est_actif()
  return etat.actif
end

function bandeau.en_attente()
  return #etat.file
end

function bandeau.en_cours()
  return etat.en_cours
end

function bandeau.historique()
  local copie = {}
  for i, entree in ipairs(etat.historique) do
    copie[i] = {
      cle = entree.cle, importance = entree.importance, nombre = entree.nombre,
      complement = entree.complement, temps = entree.temps, sort = entree.sort,
    }
  end
  return copie
end

function bandeau.comptes()
  local copie = {}
  for nom, valeur in pairs(etat.comptes) do
    copie[nom] = valeur
  end
  return copie
end

Scriptorium.declarer_morceau("bandeau", function()
  bandeau.demarrer()
end)

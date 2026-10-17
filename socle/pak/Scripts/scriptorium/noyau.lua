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
-- Les valeurs du noyau, réglables (section « socle » du catalogue de reglages.lua). Réponse de JoVenGer du 16/10/2026,
-- sur le conseil de la conversation Scriptorium après les écrans noirs de V72 : « delai_du_reveil_s », à l'entrée en
-- partie, le socle attend tant de secondes, Henry jouable, avant de relancer ses morceaux (camp redressé, hommes
-- rhabillés, ordres redonnés ; 0 = tout de suite) ; « guet_du_chargement_s », au-delà, un chargement qui ne finit pas
-- est noté au journal avec les positions autour d'Henry.
Scriptorium.noyau = Scriptorium.noyau or {}
-- « passage_jours_max » (V73 f 3 b, la règle de Scriptorium transmise par le pair, après le 24/09) : un passage d'une
-- carte à l'autre n'est cru que si l'horloge du monde a avancé, de tant de jours au plus, depuis la dernière écriture du
-- registre.
-- « argent_d_henry_max » (relecture du pair, 17/10) : aucun mouvement de la bourse d'Henry au-delà de ce montant.
Scriptorium.noyau.reglages = Scriptorium.noyau.reglages
  or { delai_du_reveil_s = 30, guet_du_chargement_s = 10, passage_jours_max = 10, argent_d_henry_max = 1000000 }

-- La règle du passage (V73 f 3 b), accrochée à la liaison : l'horloge (heures du jeu) a avancé, de
-- « passage_jours_max » au plus.
-- Les interrupteurs (fiche 16, 3 a ; le tableau des règles en double, 17/10) : 1 allumé, 0 éteint, réglables par le
-- fichier de réglages (section « interrupteurs »). Éteints par défaut : ce que Scriptorium décide, et les ajouts
-- reportés par JoVenGer.
Scriptorium.noyau.interrupteurs = Scriptorium.noyau.interrupteurs or {
  solde_de_la_semaine = 0,
  aguerrissement = 0,
  rangs_du_socle = 0,
  usure_en_points = 0,
  fautes_a_l_aube = 0,
  rencontres_de_patrouille = 0,
  contrats_a_duree = 0,
  exactions = 0,
  baisse_du_risque = 0,
  -- L'entretien de la compagnie (relecture du pair, 17/10) : les repas du socle (rations prises aux vivres) ; coupés,
  -- Scriptorium nourrit à sa place. Allumés par défaut (rien ne change tant que Scriptorium ne les coupe pas).
  repas_du_socle = 1,
  -- Fiche 18, 5 a (la liste du pair) : les chevaux de la compagnie ; éteints, chacun sort à pied. Allumés par défaut.
  chevaux_de_la_compagnie = 1,
  -- Fiche 18, 5 a (relecture du pair, 17/10) : un lit libre exigé à chaque embauche. Éteint, l'homme est engagé sans
  -- lit s'il n'en reste pas (chez Scriptorium, les hommes dorment en relève). Allumé par défaut.
  un_lit_par_homme = 1,
}

function Scriptorium.actif(nom)
  local valeur = Scriptorium.noyau.interrupteurs[nom]
  assert(valeur ~= nil, "socle : interrupteur inconnu : " .. tostring(nom))
  return valeur == 1
end

-- Une journée en tranches (fiche 16, 3 b : l'horloge de Scriptorium la pose par le fichier de réglages) est-elle
-- valable ? Chaque tranche dure, commence où finit la précédente, deux tranches qui se suivent changent d'activité
-- (chaque changement doit donner un nouvel ordre), et l'ensemble fait 24 h. Rend vrai, ou faux et la raison.
function Scriptorium.journee_valable(tranches)
  if type(tranches) ~= "table" or #tranches < 2 then
    return false, "journee_trop_courte"
  end
  local total = 0
  for i, t in ipairs(tranches) do
    local suivante = tranches[i % #tranches + 1]
    if type(t.de) ~= "number" or type(t.a) ~= "number" or t.de < 0 or t.de >= 24 or t.a < 0 or t.a >= 24 then
      return false, "heure_hors_du_jour"
    end
    if t.a == t.de then
      return false, "tranche_vide"
    end
    if suivante.de ~= t.a then
      return false, "trou_dans_la_journee"
    end
    if suivante.activite == t.activite then
      return false, "meme_activite_de_suite"
    end
    total = total + (t.a - t.de) % 24
  end
  if total ~= 24 then
    return false, "journee_de_plus_de_24_h"
  end
  return true
end

function Scriptorium.passage_croyable(avant_h, maintenant_h)
  local jours = tonumber(Scriptorium.noyau.reglages.passage_jours_max) or 10
  return type(avant_h) == "number" and type(maintenant_h) == "number" and maintenant_h >= avant_h
    and maintenant_h - avant_h <= jours * 24
end
Scriptorium.cadence_du_guet_ms = 5000
Scriptorium.reveil_en_attente = false
-- L'ordre dans lequel les morceaux battent (ceux qui ont une fonction battre).
Scriptorium.ordre_du_battement = { "bataille", "hommes", "discipline", "directeur", "enceinte", "atelier", "patrouilles",
                                    "missions" }

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
  if jeu().accrocher_le_passage then
    jeu().accrocher_le_passage(Scriptorium.passage_croyable)
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
  Scriptorium.lancer_le_guet()
  local delai = tonumber(Scriptorium.noyau.reglages.delai_du_reveil_s) or 0
  if delai > 0 then
    Scriptorium.reveil_en_attente = true
    local generation = Scriptorium.generation
    journal("Socle : réveil dans " .. delai .. " s, la partie d'abord prête")
    jeu().minuterie(delai * 1000, function()
      if generation == Scriptorium.generation then
        Scriptorium.reveiller()
      end
    end)
  else
    Scriptorium.reveiller()
  end
end

-- Le réveil : chaque morceau relancé (camp redressé, hommes rhabillés, ordres redonnés…), puis le joueur apprend que
-- le socle est prêt.
function Scriptorium.reveiller()
  Scriptorium.reveil_en_attente = false
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
  Scriptorium.reveil_en_attente = false
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
  if (jeu().partie_en_cours and not jeu().partie_en_cours()) or Scriptorium.reveil_en_attente then
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

-- Le guetteur (réponse de JoVenGer du 16/10/2026) : toutes les cinq secondes, le jeu croit-il encore charger une
-- sauvegarde ? Au-delà de « guet_du_chargement_s », une seule note au journal : depuis quand, la génération, si le
-- réveil attend, l'heure du jeu, et ce qui entoure Henry. Les dernières actions du socle sont juste au-dessus.
function Scriptorium.lancer_le_guet()
  local generation = Scriptorium.generation
  local tours, note = 0, false
  local function guet()
    if generation ~= Scriptorium.generation or not Scriptorium.en_partie then
      return
    end
    local charge = jeu().chargement_en_cours and jeu().chargement_en_cours()
    if charge then
      tours = tours + 1
      local secondes = tours * Scriptorium.cadence_du_guet_ms / 1000
      if not note and secondes >= (tonumber(Scriptorium.noyau.reglages.guet_du_chargement_s) or 10) then
        note = true
        journal("Socle : GUET, le jeu charge encore depuis " .. secondes .. " s ; génération " .. generation
                .. ", réveil en attente = " .. tostring(Scriptorium.reveil_en_attente) .. ", heure du jeu "
                .. tostring(jeu().heure_du_jeu and jeu().heure_du_jeu()))
        for _, ligne in ipairs(jeu().voisins_d_henry and jeu().voisins_d_henry(15, 20) or {}) do
          journal("Socle : GUET, " .. ligne)
        end
      end
    else
      if note then
        journal("Socle : GUET, le chargement a fini")
      end
      tours, note = 0, false
    end
    jeu().minuterie(Scriptorium.cadence_du_guet_ms, guet)
  end
  jeu().minuterie(Scriptorium.cadence_du_guet_ms, guet)
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

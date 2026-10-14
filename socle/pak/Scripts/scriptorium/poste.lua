-- Poste d'essai : des commandes en français pour éprouver chaque morceau en jeu,
-- sans rien d'autre que le socle. Voir docs/socle/essai_en_jeu.md.

Scriptorium = Scriptorium or {}

local poste = {}
Scriptorium.poste = poste

local function jeu()
  return Scriptorium.jeu
end

-- Bandeau : une nouvelle, une alerte qui passe devant, trois arrivées regroupées en une.
function poste.essai_bandeau()
  local bandeau = Scriptorium.bandeau
  local sorts = {
    bandeau.annoncer("ui_scriptorium_essai_nouvelle"),
    bandeau.annoncer("ui_scriptorium_essai_arrivee", { groupe = "essai_arrivee", cle_plusieurs = "ui_scriptorium_essai_arrivee_plusieurs" }),
    bandeau.annoncer("ui_scriptorium_essai_arrivee", { groupe = "essai_arrivee", cle_plusieurs = "ui_scriptorium_essai_arrivee_plusieurs" }),
    bandeau.annoncer("ui_scriptorium_essai_arrivee", { groupe = "essai_arrivee", cle_plusieurs = "ui_scriptorium_essai_arrivee_plusieurs" }),
    bandeau.annoncer("ui_scriptorium_essai_alerte", { importance = "alerte" }),
  }
  jeu().journal("Poste : bandeau, sorts = " .. table.concat(sorts, ", ") .. " ; en attente = " .. bandeau.en_attente())
  return sorts
end

-- Registre : compte les appels, enregistre, relit, et dit ce qu'il a trouvé.
function poste.essai_registre()
  local registre = Scriptorium.registre
  if not registre.etat_de("essai") then
    registre.declarer_case("essai", 1, function() return { appels = 0 } end)
  end
  local donnees = registre.lire("essai")
  donnees.appels = donnees.appels + 1
  local chaine = registre.enregistrer()
  registre.invalider()
  local rapport = registre.charger()
  local relu = registre.lire("essai")
  jeu().journal("Poste : registre, appels = " .. relu.appels .. ", source = " .. rapport.source
                .. ", longueur = " .. #chaine)
  Scriptorium.bandeau.annoncer("ui_scriptorium_essai_registre", { importance = "nouvelle", duree = 4 })
  return relu.appels, rapport
end

-- Coffre : Henry dépose, le camp paie, une réserve entre et sort, une dépense trop grosse est refusée.
function poste.essai_coffre()
  local coffre = Scriptorium.coffre
  local bourse_avant = jeu().groschen_d_henry()
  local sorts = {
    tostring(coffre.deposer_par_henry(100, "depot")),
    tostring(coffre.payer(30, "solde")),
    tostring(coffre.ajouter_reserve("vivres", 10, "achat")),
    tostring(coffre.prelever_reserve("vivres", 4, "repas")),
    tostring(coffre.payer(500, "solde")),
  }
  local bilan = coffre.bilan()
  jeu().journal("Poste : coffre, sorts = " .. table.concat(sorts, ", ") .. " ; solde = " .. bilan.groschen
                .. ", vivres = " .. bilan.reserves.vivres .. ", lignes = " .. bilan.lignes
                .. ", bourse d'Henry = " .. bourse_avant .. " -> " .. jeu().groschen_d_henry())
  Scriptorium.bandeau.annoncer("ui_scriptorium_essai_coffre", { duree = 4 })
  return sorts, bilan
end

-- Camp : fonde le camp là où se tient Henry ; s'il existe déjà, le redresse.
function poste.essai_camp()
  local camp = Scriptorium.camp
  if camp.est_fonde() then
    local reposes, manquants = camp.redresser()
    jeu().journal("Poste : camp déjà fondé (niveau " .. camp.niveau() .. "), redressé : " .. reposes
                  .. " reposé(s), " .. manquants .. " manquant(s)")
    return "redresse", reposes, manquants
  end
  local ok, raison = camp.fonder(jeu().position_du_joueur(), jeu().cap_du_joueur())
  local capacite = camp.capacite()
  jeu().journal("Poste : camp fondé = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or "")
                .. ", lits = " .. capacite.lits .. ", sièges = " .. capacite.sieges)
  return ok and "fonde" or "refuse", capacite.lits, capacite.sieges
end

-- Camp : agrandit d'un niveau.
function poste.essai_camp_agrandir()
  local ok, raison = Scriptorium.camp.agrandir()
  jeu().journal("Poste : camp agrandi = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or "")
                .. ", niveau = " .. Scriptorium.camp.niveau())
  return ok
end

-- Camp : lève le camp.
function poste.essai_camp_lever()
  local ok, raison = Scriptorium.camp.lever()
  jeu().journal("Poste : camp levé = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or ""))
  return ok
end

-- Hommes : engage trois hommes (le coffre doit avoir de quoi payer les primes), puis lance le battement.
function poste.essai_hommes()
  local hommes = Scriptorium.hommes
  local ids = {}
  for _, role in ipairs({ "homme_d_armes", "arbaletrier", "archer" }) do
    local id, raison = hommes.embaucher({ role = role, semaines = 4 })
    table.insert(ids, id and tostring(id) or ("refus:" .. tostring(raison)))
  end
  local effectif = hommes.effectif()
  jeu().journal("Poste : hommes, engagés = " .. table.concat(ids, ", ") .. " ; total = " .. effectif.total
                .. ", présents = " .. effectif.presents .. ", coffre = " .. Scriptorium.coffre.solde())
  poste.battre_les_hommes()
  return ids, effectif
end

-- Le battement du camp est celui du socle (Scriptorium.battre, lancé au démarrage) ;
-- ici, on s'assure seulement qu'il tourne.
function poste.battre_les_hommes()
  Scriptorium.lancer_le_battement()
end

-- Patrouille : envoie deux hommes faire la ronde proche.
function poste.essai_patrouille()
  local id, raison = Scriptorium.patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  jeu().journal("Poste : patrouille = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or ""))
  return id
end

-- Bataille : lève une bande de cinq brigands venant du nord, qui arrive dans un quart d'heure de jeu.
function poste.essai_bataille()
  local id, raison = Scriptorium.bataille.lever_une_bande({ sorte = "brigands", effectif = 5, direction = 0, delai = 0.25 })
  jeu().journal("Poste : bande levée = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or "")
                .. ", force des nôtres = " .. Scriptorium.bataille.force_des_notres())
  poste.battre_les_hommes()
  return id
end

-- Directeur : l'installe, puis écrit le menu de la Gestion du camp au journal.
function poste.essai_directeur()
  local directeur = Scriptorium.directeur
  if not directeur.est_installe() then
    local ok, raison = directeur.installer()
    jeu().journal("Poste : Directeur installé = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or ""))
  end
  for _, e in ipairs(directeur.menu()) do
    jeu().journal("Poste : gestion, " .. e.action .. " : " .. (e.disponible and "possible" or ("impossible (" .. tostring(e.raison) .. ")"))
                  .. ((#e.parametres > 0) and (" ; paramètres : " .. table.concat(e.parametres, ", ")) or ""))
  end
  poste.battre_les_hommes()
  return directeur.menu()
end

-- Directeur : joue une action de la Gestion du camp depuis la console.
-- Exemple : scriptorium_gestion engager role=archer semaines=4
function poste.gestion(action, parametres)
  local ok, resultat = Scriptorium.directeur.agir(action, parametres or {})
  jeu().journal("Poste : gestion « " .. tostring(action) .. " » = " .. tostring(ok) .. " ; " .. tostring(resultat))
  if ok and type(resultat) == "table" then
    for cle, valeur in pairs(resultat) do
      if type(valeur) ~= "table" then
        jeu().journal("  " .. tostring(cle) .. " = " .. tostring(valeur))
      end
    end
  end
  return ok, resultat
end

-- Enceinte : achète le bois qu'il faut, bâtit la palissade puis les tours.
function poste.essai_enceinte()
  local enceinte = Scriptorium.enceinte
  local coffre = Scriptorium.coffre
  local manque = enceinte.reglages.bois_palissade + enceinte.reglages.bois_tours - coffre.reserve("bois")
  if manque > 0 then
    coffre.ajouter_reserve("bois", manque, "essai")
  end
  local sorts = { tostring(enceinte.batir()), tostring(enceinte.batir()) }
  jeu().journal("Poste : enceinte, sorts = " .. table.concat(sorts, ", ") .. " ; niveau = " .. enceinte.niveau()
                .. ", porte = " .. enceinte.porte())
  poste.battre_les_hommes()
  return sorts
end

-- Discipline : écrit les fautes à juger et la réputation au journal.
function poste.essai_discipline()
  local discipline = Scriptorium.discipline
  local fautes = discipline.a_juger()
  jeu().journal("Poste : discipline, réputation = " .. discipline.reputation() .. ", fautes à juger = " .. #fautes)
  for _, f in ipairs(fautes) do
    jeu().journal("  " .. f.id .. " : " .. f.sorte .. " par " .. f.nom)
  end
  return fautes
end

-- Résumé du socle dans le journal.
function poste.bilan()
  for _, morceau in ipairs(Scriptorium.morceaux) do
    jeu().journal("Poste : morceau « " .. morceau.nom .. " » : " .. (morceau.pret and "prêt" or ("en panne : " .. tostring(morceau.erreur))))
  end
  local effectif = Scriptorium.hommes.effectif()
  jeu().journal("Poste : hommes, total = " .. effectif.total .. ", valides = " .. effectif.valides
                .. ", blessés = " .. effectif.blesses .. ", présents = " .. effectif.presents)
  local resultats = Scriptorium.bataille.resultats()
  jeu().journal("Poste : batailles, en cours = " .. #Scriptorium.bataille.bandes() .. ", jouées = " .. #resultats
                .. (resultats[#resultats] and (", dernière : " .. resultats[#resultats].issue) or ""))
  local comptes = Scriptorium.bandeau.comptes()
  jeu().journal("Poste : bandeau, affichés = " .. comptes.affiches .. ", regroupés = " .. comptes.regroupes
                .. ", répétés = " .. comptes.repetes .. ", refusés = " .. comptes.refuses)
end

-- Les commandes du poste, dans l'ordre : la console et le fichier d'ordres en lisent la même liste
-- (outils/ordonner.py aussi, pour refuser un nom inconnu avant de l'écrire).
poste.commandes = {
  { nom = "scriptorium_essai_bandeau", fonction = function() return poste.essai_bandeau() end, aide = "Essai du bandeau des messages" },
  { nom = "scriptorium_essai_registre", fonction = function() return poste.essai_registre() end, aide = "Essai du registre" },
  { nom = "scriptorium_essai_coffre", fonction = function() return poste.essai_coffre() end, aide = "Essai du coffre" },
  { nom = "scriptorium_essai_camp", fonction = function() return poste.essai_camp() end, aide = "Fonde le camp où se tient Henry, ou le redresse" },
  { nom = "scriptorium_essai_camp_agrandir", fonction = function() return poste.essai_camp_agrandir() end, aide = "Agrandit le camp d'un niveau" },
  { nom = "scriptorium_essai_camp_lever", fonction = function() return poste.essai_camp_lever() end, aide = "Lève le camp" },
  { nom = "scriptorium_essai_hommes", fonction = function() return poste.essai_hommes() end, aide = "Engage trois hommes et lance leur journée" },
  { nom = "scriptorium_essai_bataille", fonction = function() return poste.essai_bataille() end, aide = "Lève une bande de cinq brigands venant du nord" },
  { nom = "scriptorium_essai_directeur", fonction = function() return poste.essai_directeur() end, aide = "Installe le Directeur et écrit le menu de la Gestion du camp" },
  { nom = "scriptorium_gestion_rapport", fonction = function() return poste.gestion("rapport") end, aide = "Le rapport du Directeur" },
  { nom = "scriptorium_essai_enceinte", fonction = function() return poste.essai_enceinte() end, aide = "Bâtit la palissade et les tours" },
  { nom = "scriptorium_essai_patrouille", fonction = function() return poste.essai_patrouille() end, aide = "Envoie deux hommes faire la ronde proche" },
  { nom = "scriptorium_essai_discipline", fonction = function() return poste.essai_discipline() end, aide = "Les fautes à juger et la réputation" },
  { nom = "scriptorium_bilan", fonction = function() return poste.bilan() end, aide = "Bilan du socle dans le journal" },
}

local function trouver_commande(nom)
  for _, commande in ipairs(poste.commandes) do
    if commande.nom == nom then
      return commande
    end
  end
  return nil
end

-- Exécute une commande du poste par son nom. Une commande qui casse est notée au journal.
function poste.executer(nom)
  local commande = trouver_commande(nom)
  if not commande then
    jeu().journal("Poste : commande inconnue « " .. tostring(nom) .. " »")
    return false
  end
  local ok, erreur = pcall(commande.fonction)
  if not ok then
    jeu().journal("Poste : « " .. nom .. " » en erreur : " .. tostring(erreur))
  end
  return ok
end

-- Ordres par fichier. Le PC écrit Mods/scriptorium_socle/ordres.lua (outils/ordonner.py) :
--   return { numero = N, commande = "scriptorium_…" }
-- Le poste le relit à chaque battement ; un ordre au numéro plus grand que le dernier vu est exécuté
-- une seule fois, et seulement quand une partie est en cours (sinon il attend). L'ordre déjà présent
-- au lancement du jeu est ancien : il n'est pas rejoué.
poste.reglages = {
  cadence_ms = 2000,       -- intervalle entre deux relevés du fichier d'ordres
  tours_par_veille = 15,   -- une ligne de veille au journal tous les 15 relevés (30 secondes)
}

local ordres

function poste.remettre_a_zero()
  ordres = { premier_releve = true, dernier = 0, chemin = nil, raison = nil, attente = nil, tours = 0, partie = nil,
             actif = false, generation = 0 }
end
poste.remettre_a_zero()

local function noter_raison(raison)
  if raison ~= ordres.raison then
    ordres.raison = raison
    if raison then
      jeu().journal("Poste : fichier d'ordres illisible : " .. raison)
    end
  end
end

-- Un relevé du fichier d'ordres. Rend « absent », « illisible », « ancien », « deja_fait »,
-- « en_attente », « refuse » ou « execute ».
function poste.relever_ordres()
  local donnees, chemin, raison = jeu().lire_ordres()
  if chemin and chemin ~= ordres.chemin then
    ordres.chemin = chemin
    jeu().journal("Poste : fichier d'ordres trouvé à « " .. chemin .. " »")
  end
  if donnees == nil then
    noter_raison(raison)
    if ordres.premier_releve then
      ordres.premier_releve = false
      if not raison then
        jeu().journal("Poste : pas de fichier d'ordres au lancement")
      end
    end
    return raison and "illisible" or "absent"
  end
  if type(donnees.numero) ~= "number" or type(donnees.commande) ~= "string" then
    noter_raison("numéro ou commande manquant")
    ordres.premier_releve = false
    return "illisible"
  end
  noter_raison(nil)
  local numero, nom = donnees.numero, donnees.commande
  if ordres.premier_releve then
    ordres.premier_releve = false
    ordres.dernier = numero
    jeu().journal("Poste : ordre n° " .. numero .. " (" .. nom .. ") trouvé au lancement, non rejoué")
    return "ancien"
  end
  if numero <= ordres.dernier then
    return "deja_fait"
  end
  if not trouver_commande(nom) then
    ordres.dernier = numero
    jeu().journal("Poste : ordre n° " .. numero .. " refusé : commande inconnue « " .. nom .. " »")
    return "refuse"
  end
  if not jeu().partie_en_cours() then
    if ordres.attente ~= numero then
      ordres.attente = numero
      jeu().journal("Poste : ordre n° " .. numero .. " (" .. nom .. ") en attente d'une partie")
    end
    return "en_attente"
  end
  ordres.dernier = numero
  ordres.attente = nil
  jeu().journal("Poste : ordre n° " .. numero .. " : " .. nom)
  poste.executer(nom)
  return "execute"
end

-- Ligne de veille : dit au journal si les minuteries tournent encore, et où en sont le bandeau et les ordres.
function poste.veiller()
  local partie = jeu().partie_en_cours()
  ordres.tours = ordres.tours + 1
  if partie ~= ordres.partie or ordres.tours >= poste.reglages.tours_par_veille then
    ordres.partie = partie
    ordres.tours = 0
    local comptes = Scriptorium.bandeau.comptes()
    jeu().journal("Poste : veille, partie en cours = " .. tostring(partie)
                  .. ", bandeau en attente = " .. Scriptorium.bandeau.en_attente()
                  .. ", affichés = " .. comptes.affiches .. ", dernier ordre = " .. ordres.dernier)
  end
end

-- Fait battre le poste tout seul : relevé des ordres, puis veille.
function poste.demarrer()
  if ordres.actif then
    return
  end
  ordres.actif = true
  ordres.generation = ordres.generation + 1
  local generation = ordres.generation
  local function battement()
    if not ordres.actif or ordres.generation ~= generation then
      return
    end
    local ok, erreur = pcall(poste.relever_ordres)
    if not ok then
      jeu().journal("Poste : erreur au relevé des ordres : " .. tostring(erreur))
    end
    ok, erreur = pcall(poste.veiller)
    if not ok then
      jeu().journal("Poste : erreur à la veille : " .. tostring(erreur))
    end
    jeu().minuterie(poste.reglages.cadence_ms, battement)
  end
  jeu().minuterie(poste.reglages.cadence_ms, battement)
end

function poste.arreter()
  ordres.actif = false
end

-- Entrée en partie : repose la minuterie (celle du démarrage du mod ne tire jamais en jeu).
function poste.relancer()
  ordres.actif = false
  poste.demarrer()
end

Scriptorium.declarer_morceau("poste", function()
  for _, commande in ipairs(poste.commandes) do
    jeu().commande(commande.nom, "Scriptorium.poste.executer('" .. commande.nom .. "')", commande.aide)
  end
  poste.demarrer()
end)

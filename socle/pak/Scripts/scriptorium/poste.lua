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
                .. ", bourse d'Henry = " .. jeu().groschen_d_henry())
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

-- Lance le battement des hommes toutes les trente secondes.
function poste.battre_les_hommes()
  if poste.battement_hommes_actif then
    return
  end
  poste.battement_hommes_actif = true
  local function battement()
    if not poste.battement_hommes_actif then
      return
    end
    local ok, erreur = pcall(Scriptorium.hommes.battre)
    if not ok then
      jeu().journal("Hommes : erreur au battement : " .. tostring(erreur))
    end
    jeu().minuterie(30000, battement)
  end
  jeu().minuterie(30000, battement)
end

-- Résumé du socle dans le journal.
function poste.bilan()
  for _, morceau in ipairs(Scriptorium.morceaux) do
    jeu().journal("Poste : morceau « " .. morceau.nom .. " » : " .. (morceau.pret and "prêt" or ("en panne : " .. tostring(morceau.erreur))))
  end
  local effectif = Scriptorium.hommes.effectif()
  jeu().journal("Poste : hommes, total = " .. effectif.total .. ", valides = " .. effectif.valides
                .. ", blessés = " .. effectif.blesses .. ", présents = " .. effectif.presents)
  local comptes = Scriptorium.bandeau.comptes()
  jeu().journal("Poste : bandeau, affichés = " .. comptes.affiches .. ", regroupés = " .. comptes.regroupes
                .. ", répétés = " .. comptes.repetes .. ", refusés = " .. comptes.refuses)
end

Scriptorium.declarer_morceau("poste", function()
  jeu().commande("scriptorium_essai_bandeau", "Scriptorium.poste.essai_bandeau()", "Essai du bandeau des messages")
  jeu().commande("scriptorium_essai_registre", "Scriptorium.poste.essai_registre()", "Essai du registre")
  jeu().commande("scriptorium_essai_coffre", "Scriptorium.poste.essai_coffre()", "Essai du coffre")
  jeu().commande("scriptorium_essai_camp", "Scriptorium.poste.essai_camp()", "Fonde le camp où se tient Henry, ou le redresse")
  jeu().commande("scriptorium_essai_camp_agrandir", "Scriptorium.poste.essai_camp_agrandir()", "Agrandit le camp d'un niveau")
  jeu().commande("scriptorium_essai_camp_lever", "Scriptorium.poste.essai_camp_lever()", "Lève le camp")
  jeu().commande("scriptorium_essai_hommes", "Scriptorium.poste.essai_hommes()", "Engage trois hommes et lance leur journée")
  jeu().commande("scriptorium_bilan", "Scriptorium.poste.bilan()", "Bilan du socle dans le journal")
end)

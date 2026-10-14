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

-- Lance le battement du camp (hommes, bandes) toutes les trente secondes.
function poste.battre_les_hommes()
  if poste.battement_hommes_actif then
    return
  end
  poste.battement_hommes_actif = true
  local function battement()
    if not poste.battement_hommes_actif then
      return
    end
    for _, morceau in ipairs({ "bataille", "hommes", "directeur", "enceinte", "atelier" }) do
      local ok, erreur = pcall(Scriptorium[morceau].battre)
      if not ok then
        jeu().journal("Battement de « " .. morceau .. " » en erreur : " .. tostring(erreur))
      end
    end
    jeu().minuterie(30000, battement)
  end
  jeu().minuterie(30000, battement)
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

Scriptorium.declarer_morceau("poste", function()
  jeu().commande("scriptorium_essai_bandeau", "Scriptorium.poste.essai_bandeau()", "Essai du bandeau des messages")
  jeu().commande("scriptorium_essai_registre", "Scriptorium.poste.essai_registre()", "Essai du registre")
  jeu().commande("scriptorium_essai_coffre", "Scriptorium.poste.essai_coffre()", "Essai du coffre")
  jeu().commande("scriptorium_essai_camp", "Scriptorium.poste.essai_camp()", "Fonde le camp où se tient Henry, ou le redresse")
  jeu().commande("scriptorium_essai_camp_agrandir", "Scriptorium.poste.essai_camp_agrandir()", "Agrandit le camp d'un niveau")
  jeu().commande("scriptorium_essai_camp_lever", "Scriptorium.poste.essai_camp_lever()", "Lève le camp")
  jeu().commande("scriptorium_essai_hommes", "Scriptorium.poste.essai_hommes()", "Engage trois hommes et lance leur journée")
  jeu().commande("scriptorium_essai_bataille", "Scriptorium.poste.essai_bataille()", "Lève une bande de cinq brigands venant du nord")
  jeu().commande("scriptorium_essai_directeur", "Scriptorium.poste.essai_directeur()", "Installe le Directeur et écrit le menu de la Gestion du camp")
  jeu().commande("scriptorium_gestion_rapport", "Scriptorium.poste.gestion('rapport')", "Le rapport du Directeur")
  jeu().commande("scriptorium_essai_enceinte", "Scriptorium.poste.essai_enceinte()", "Bâtit la palissade et les tours")
  jeu().commande("scriptorium_bilan", "Scriptorium.poste.bilan()", "Bilan du socle dans le journal")
end)

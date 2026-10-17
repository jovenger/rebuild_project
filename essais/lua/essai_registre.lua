-- Essais du registre (fiche 01_registre.md).

local registre = Scriptorium.registre

local function case_coffre_v1()
  return registre.declarer_case("coffre", 1, function() return { groschen = 0, lignes = {} } end)
end

essai("registre : écrire puis relire rend les mêmes données", function()
  depart()
  case_coffre_v1()
  local coffre = registre.lire("coffre")
  coffre.groschen = 125
  table.insert(coffre.lignes, { jour = 3, motif = "solde", montant = -40 })
  table.insert(coffre.lignes, { jour = 4, motif = "butin", montant = 165.5 })
  coffre.note = "première paie"
  coffre.ouvert = true
  registre.enregistrer()
  verifier(FauxJeu.registre_stocke ~= nil, "quelque chose est écrit dans la partie")
  registre.invalider()
  local rapport = registre.charger()
  egal(rapport.source, "lu", "source")
  egal(rapport.chargees, 1, "une case chargée")
  local relu = registre.lire("coffre")
  egal(relu.groschen, 125, "nombre entier")
  egal(relu.lignes[2].montant, 165.5, "nombre à virgule")
  egal(relu.lignes[1].motif, "solde", "chaîne")
  egal(relu.note, "première paie", "chaîne avec accent")
  egal(relu.ouvert, true, "booléen")
  egal(#relu.lignes, 2, "liste")
end)

essai("registre : un registre vide donne des cases neuves", function()
  depart()
  case_coffre_v1()
  local rapport = registre.charger()
  egal(rapport.source, "vide", "source")
  egal(rapport.neuves, 1, "case neuve")
  egal(registre.lire("coffre").groschen, 0, "valeur par défaut")
  egal(registre.etat_de("coffre"), "neuve", "état")
  egal(#FauxJeu.affichages, 0, "rien à l'écran pour une partie neuve")
end)

essai("registre : un contenu illisible est remis à neuf, avec un mot au joueur et au journal", function()
  depart()
  case_coffre_v1()
  FauxJeu.registre_stocke = "n'importe quoi"
  local rapport = registre.charger()
  egal(rapport.source, "illisible", "source")
  egal(registre.lire("coffre").groschen, 0, "valeur par défaut")
  verifier(#FauxJeu.journal_lignes >= 1, "journal")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_registre_remis_a_neuf", "mot au joueur")
end)

essai("registre : la chaîne enregistrée ne peut pas exécuter de code", function()
  depart()
  case_coffre_v1()
  FauxJeu.registre_stocke = '{["format"]=1,["cases"]={["coffre"]={["version"]=1,["donnees"]=(function() Piege = true return {["groschen"]=7} end)()}}}'
  registre.charger()
  egal(rawget(_G, "Piege"), nil, "le bac à sable ne touche pas aux globales")
  -- Le contenu est accepté s'il se lit, mais sans accès au jeu : les globales restent intactes.
end)

essai("registre : une case d'ancienne version est montée de version, une par une", function()
  depart()
  case_coffre_v1()
  registre.lire("coffre").groschen = 50
  registre.enregistrer()
  local ancienne = FauxJeu.registre_stocke

  -- Nouveau socle : version 3 de la case, avec les deux montées.
  depart()
  FauxJeu.registre_stocke = ancienne
  registre.declarer_case("coffre", 3,
    function() return { bourse = { groschen = 0 }, lignes = {}, sceau = true } end,
    {
      [1] = function(d) return { bourse = { groschen = d.groschen }, lignes = d.lignes } end,
      [2] = function(d) d.sceau = true return d end,
    })
  local rapport = registre.charger()
  egal(rapport.migrees, 1, "une case montée")
  egal(registre.etat_de("coffre"), "migree", "état")
  local coffre = registre.lire("coffre")
  egal(coffre.bourse.groschen, 50, "donnée conservée à travers les montées")
  egal(coffre.sceau, true, "seconde montée appliquée")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, nil, "la montée ne dérange pas le joueur (journal seulement)")
end)

essai("registre : une montée manquante ou en échec remet la case à neuf", function()
  depart()
  case_coffre_v1()
  registre.lire("coffre").groschen = 50
  registre.enregistrer()
  local ancienne = FauxJeu.registre_stocke

  depart()
  FauxJeu.registre_stocke = ancienne
  registre.declarer_case("coffre", 2, function() return { groschen = 0 } end, {})
  local rapport = registre.charger()
  egal(rapport.abimees, 1, "case abîmée")
  egal(registre.lire("coffre").groschen, 0, "remise à neuf")

  depart()
  FauxJeu.registre_stocke = ancienne
  registre.declarer_case("coffre", 2, function() return { groschen = 0 } end,
    { [1] = function() error("boum") end })
  rapport = registre.charger()
  egal(rapport.abimees, 1, "montée en échec -> abîmée")
end)

essai("registre : une case venant d'un socle plus récent n'est pas devinée", function()
  depart()
  registre.declarer_case("coffre", 5, function() return { groschen = 9 } end)
  registre.lire("coffre")
  registre.enregistrer()
  local future = FauxJeu.registre_stocke

  depart()
  FauxJeu.registre_stocke = future
  case_coffre_v1()
  local rapport = registre.charger()
  egal(rapport.abimees, 1, "abîmée")
  egal(registre.lire("coffre").groschen, 0, "par défaut")
end)

essai("registre : une case déclarée après le chargement est servie depuis le contenu lu", function()
  depart()
  case_coffre_v1()
  registre.declarer_case("camp", 1, function() return { tentes = 0 } end)
  registre.lire("camp").tentes = 4
  registre.enregistrer()
  local sauvegarde = FauxJeu.registre_stocke

  depart()
  FauxJeu.registre_stocke = sauvegarde
  case_coffre_v1()
  registre.charger()
  registre.declarer_case("camp", 1, function() return { tentes = 0 } end)
  egal(registre.lire("camp").tentes, 4, "servie après coup")
end)

essai("registre : les cases inconnues du contenu lu sont conservées à l'écriture", function()
  depart()
  case_coffre_v1()
  registre.declarer_case("camp", 1, function() return { tentes = 2 } end)
  registre.lire("camp")
  registre.enregistrer()
  local sauvegarde = FauxJeu.registre_stocke

  depart()
  FauxJeu.registre_stocke = sauvegarde
  case_coffre_v1()
  registre.lire("coffre").groschen = 1
  registre.enregistrer()
  local contenu = registre.deserialiser(FauxJeu.registre_stocke)
  egal(contenu.cases.camp.donnees.tentes, 2, "case « camp » gardée")
end)

essai("registre : lire() charge tout seul ; enregistrer() avant toute lecture n'écrase pas la partie", function()
  depart()
  case_coffre_v1()
  registre.lire("coffre").groschen = 77
  registre.enregistrer()
  local sauvegarde = FauxJeu.registre_stocke

  depart()
  FauxJeu.registre_stocke = sauvegarde
  case_coffre_v1()
  registre.enregistrer()
  egal(registre.deserialiser(FauxJeu.registre_stocke).cases.coffre.donnees.groschen, 77, "gardé")
end)

essai("registre : la sérialisation est stable et refuse ce qui ne s'enregistre pas", function()
  depart()
  local a = registre.serialiser({ b = 1, a = { 3, 2, x = "y" }, [2] = true })
  local b = registre.serialiser({ [2] = true, a = { x = "y", 3, 2 }, b = 1 })
  egal(a, b, "même chaîne quel que soit l'ordre de construction")
  verifier(not pcall(registre.serialiser, { f = function() end }), "fonction refusée")
  verifier(not pcall(registre.serialiser, { [true] = 1 }), "clé booléenne refusée")
  verifier(not pcall(registre.serialiser, { n = 0 / 0 }), "nombre impossible refusé")
  local boucle = {}
  boucle.moi = boucle
  verifier(not pcall(registre.serialiser, boucle), "boucle refusée")
  local valeur, erreur = registre.deserialiser("")
  verifier(valeur == nil and erreur ~= nil, "chaîne vide refusée")
  valeur, erreur = registre.deserialiser("{ oups")
  verifier(valeur == nil and erreur ~= nil, "chaîne cassée refusée")
end)

essai("registre : déclarations invalides refusées", function()
  depart()
  verifier(not pcall(registre.declarer_case, "", 1, function() return {} end), "nom vide")
  verifier(not pcall(registre.declarer_case, "x", 0, function() return {} end), "version 0")
  verifier(not pcall(registre.declarer_case, "x", 1.5, function() return {} end), "version non entière")
  verifier(not pcall(registre.declarer_case, "x", 1, {}), "valeur par défaut qui n'est pas une fonction")
  case_coffre_v1()
  verifier(not pcall(case_coffre_v1), "double déclaration")
  verifier(not pcall(registre.lire, "inconnue"), "case inconnue")
end)

essai("registre (fiche 01, le pair, 17/10) : les écritures regroupées, une au plus par intervalle ; le battement vide l'attente ; « forcer » écrit tout de suite", function()
  depart()
  local registre = Scriptorium.registre
  local ancien = Scriptorium.noyau.reglages.registre_intervalle_s
  Scriptorium.noyau.reglages.registre_intervalle_s = 2
  local ok, erreur = pcall(function()
    registre.declarer_case("essai_groupe", 1, function() return { n = 0 } end)
    FauxJeu.temps = 100
    verifier(registre.enregistrer() ~= nil, "la première écriture, tout de suite")
    local premiere = FauxJeu.registre_stocke
    local d = registre.lire("essai_groupe")
    d.n = 1
    FauxJeu.temps = 100.5
    egal(registre.enregistrer(), nil, "rapprochée : en attente")
    verifier(registre.en_attente, "notée en attente")
    egal(FauxJeu.registre_stocke, premiere, "pas encore écrite")
    local avant = FauxJeu.registre_stocke
    Scriptorium.battre()
    verifier(not registre.en_attente, "le battement vide l'attente")
    verifier(FauxJeu.registre_stocke ~= avant, "écrite au battement")
    d.n = 2
    FauxJeu.temps = 100.6
    verifier(registre.enregistrer(nil, true) ~= nil, "forcée : écrite tout de suite")
    d.n = 3
    FauxJeu.temps = 103
    verifier(registre.enregistrer() ~= nil, "l'intervalle passé : tout de suite")
  end)
  Scriptorium.noyau.reglages.registre_intervalle_s = ancien
  registre.en_attente = false
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

-- Fiche 01 (le second canal) : ce que fait le jeu : il écrit ses jetons, PUIS appelle l'OnSave ; au rechargement, les
-- jetons de la sauvegarde reviennent, l'OnLoad rend les cases rangées.
local function sauver_et_recharger(retoucher)
  local j = FauxJeu.registre_jetons
  local jetons = { index = j.index, cases = {}, ancien = j.ancien }
  for k, v in pairs(j.cases) do jetons.cases[k] = v end
  local liste = FauxJeu.a_la_sauvegarde()
  local rangees = {}
  for _, e in ipairs(liste) do
    local r = { nom = e.nom, chaine = e.chaine }
    if e.base then
      r.base_longueur, r.base_somme = FauxJeu.empreinte(e.base)
    end
    table.insert(rangees, r)
  end
  if retoucher then
    retoucher(jetons)
  end
  FauxJeu.registre_jetons = jetons
  FauxJeu.depuis_la_sauvegarde = rangees
  Scriptorium.registre.invalider()
  return liste
end

essai("registre (fiche 01, le second canal, demande du pair, 18/10) : ce qui n'est pas écrit voyage dans la sauvegarde et revient au rechargement ; rien en attente : rien de doublé ; une case rangée plus ancienne que la case lue : ignorée ; une case jamais écrite : reprise", function()
  depart()
  local registre = Scriptorium.registre
  local ancien = Scriptorium.noyau.reglages.registre_intervalle_s
  Scriptorium.noyau.reglages.registre_intervalle_s = 2
  local ok, erreur = pcall(function()
    Scriptorium.entrer_en_partie()
    egal(FauxJeu.a_la_sauvegarde, registre.a_la_sauvegarde, "accrochée à l'entrée en partie")
    registre.declarer_case("essai_canal", 1, function() return { n = 0 } end)
    local function n_ecrit()
      return registre.deserialiser(FauxJeu.registre_jetons.cases["essai_canal"]).donnees.n
    end
    FauxJeu.temps = 400
    registre.lire("essai_canal").n = 1
    verifier(registre.enregistrer("essai_canal") ~= nil, "écrite tout de suite")
    -- 1. Nommée, en attente au moment de la sauvegarde.
    registre.lire("essai_canal").n = 2
    FauxJeu.temps = 400.5
    egal(registre.enregistrer("essai_canal"), nil, "en attente")
    egal(#sauver_et_recharger(), 1, "une case rangée dans la sauvegarde")
    FauxJeu.temps = 410
    egal(registre.lire("essai_canal").n, 2, "revenue au rechargement")
    egal(n_ecrit(), 2, "réécrite dans les jetons")
    -- 2. Changée sans être nommée (la surveillance) : rangée aussi.
    registre.lire("essai_canal").n = 3
    sauver_et_recharger()
    FauxJeu.temps = 420
    egal(registre.lire("essai_canal").n, 3, "la case changée sans être nommée revient aussi")
    -- 3. Rien en attente : rien de rangé, rien de doublé.
    FauxJeu.temps = 430
    registre.lire("essai_canal")
    local ecrites = #FauxJeu.cases_ecrites
    egal(#sauver_et_recharger(), 0, "rien en attente : rien de rangé")
    egal(registre.lire("essai_canal").n, 3, "la valeur inchangée")
    egal(#FauxJeu.cases_ecrites, ecrites, "rien de réécrit")
    -- 4. Les jetons plus récents que la case rangée (elle repose sur une autre chaîne) : ignorée.
    FauxJeu.temps = 440
    registre.lire("essai_canal").n = 4
    registre.enregistrer("essai_canal")
    registre.lire("essai_canal").n = 5
    FauxJeu.temps = 440.5
    egal(registre.enregistrer("essai_canal"), nil, "de nouveau en attente")
    sauver_et_recharger(function(jetons)
      local plus_recente = registre.serialiser({ version = 1, donnees = { n = 9 } })
      jetons.cases["essai_canal"] = plus_recente
    end)
    egal(registre.lire("essai_canal").n, 9, "la case lue, plus récente, est gardée")
    -- 5. Une case jamais écrite avant la sauvegarde : reprise.
    registre.declarer_case("essai_canal_neuve", 1, function() return { n = 0 } end)
    FauxJeu.temps = 450
    registre.lire("essai_canal_neuve").n = 7
    FauxJeu.temps = 450.1
    sauver_et_recharger(function(jetons) jetons.cases["essai_canal_neuve"] = nil end)
    FauxJeu.temps = 460
    egal(registre.lire("essai_canal_neuve").n, 7, "la case jamais écrite revient")
  end)
  Scriptorium.noyau.reglages.registre_intervalle_s = ancien
  registre.en_attente = false
  registre.vidage_pose = false
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("registre (fiche 01, vu en jeu le 17/10 : le Directeur perdu à la sauvegarde) : l'attente vidée par une minuterie à la fin de l'intervalle, une seule à la fois ; rien d'écrit après une partie oubliée", function()
  depart()
  local registre = Scriptorium.registre
  local ancien = Scriptorium.noyau.reglages.registre_intervalle_s
  Scriptorium.noyau.reglages.registre_intervalle_s = 2
  local ok, erreur = pcall(function()
    registre.declarer_case("essai_vidage", 1, function() return { n = 0 } end)
    FauxJeu.temps = 200
    verifier(registre.enregistrer("essai_vidage") ~= nil, "la première écriture, tout de suite")
    local d = registre.lire("essai_vidage")
    d.n = 1
    FauxJeu.temps = 200.5
    local avant_minuteries = #FauxJeu.minuteries
    egal(registre.enregistrer("essai_vidage"), nil, "rapprochée : en attente")
    egal(#FauxJeu.minuteries, avant_minuteries + 1, "une minuterie posée")
    local m = FauxJeu.minuteries[#FauxJeu.minuteries]
    egal(m.ms, 1500, "pour le reste de l'intervalle (1,5 s)")
    d.n = 2
    egal(registre.enregistrer("essai_vidage"), nil, "encore en attente")
    egal(#FauxJeu.minuteries, avant_minuteries + 1, "pas de seconde minuterie")
    local avant = FauxJeu.registre_stocke
    m.fonction()
    verifier(not registre.en_attente, "la minuterie vide l'attente")
    verifier(FauxJeu.registre_stocke ~= avant, "écrite sans battement")
    -- Une partie oubliée entre la mise en attente et la minuterie : rien d'écrit.
    d.n = 3
    FauxJeu.temps = 200.6
    egal(registre.enregistrer("essai_vidage"), nil, "de nouveau en attente")
    local m2 = FauxJeu.minuteries[#FauxJeu.minuteries]
    verifier(m2 ~= m, "une nouvelle minuterie")
    registre.invalider()
    local apres = FauxJeu.registre_stocke
    m2.fonction()
    egal(FauxJeu.registre_stocke, apres, "rien d'écrit après la partie oubliée")
    verifier(not registre.vidage_pose, "plus de minuterie posée")
  end)
  Scriptorium.noyau.reglages.registre_intervalle_s = ancien
  registre.en_attente = false
  registre.vidage_pose = false
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

essai("registre par case (fiche 01) : seule la case nommée s'écrit ; l'index seulement s'il change ; case inconnue gardée ; repli sans nom", function()
  depart()
  local registre = Scriptorium.registre
  registre.declarer_case("essai_a", 1, function() return { n = 0 } end)
  registre.declarer_case("essai_b", 1, function() return { n = 0 } end)
  registre.enregistrer(nil, true)
  -- Une case d'une autre version, écrite à la main dans la partie.
  local index = registre.deserialiser(FauxJeu.registre_jetons.index)
  table.insert(index.cases, "inconnue")
  FauxJeu.registre_jetons.index = registre.serialiser(index)
  FauxJeu.registre_jetons.cases.inconnue = registre.serialiser({ version = 9, donnees = { x = 1 } })
  registre.invalider()
  registre.charger()
  registre.lire("essai_a").n = 5
  FauxJeu.cases_ecrites, FauxJeu.index_ecrits = {}, 0
  egal(registre.enregistrer("essai_a"), 1, "une case écrite")
  egal(#FauxJeu.cases_ecrites, 1, "une seule")
  egal(FauxJeu.cases_ecrites[1], "essai_a", "la nommée")
  egal(FauxJeu.index_ecrits, 0, "l'index inchangé : pas réécrit")
  verifier(FauxJeu.registre_jetons.cases.inconnue ~= nil, "la case inconnue gardée")
  verifier(string.find(FauxJeu.registre_jetons.index, "inconnue", 1, true), "et dans l'index")
  FauxJeu.cases_ecrites = {}
  registre.enregistrer()
  verifier(#FauxJeu.cases_ecrites >= 2, "sans nom : toutes les cases déclarées")
  egal(FauxJeu.registre_jetons.cases.inconnue, registre.serialiser({ version = 9, donnees = { x = 1 } }), "l'inconnue jamais réécrite")
  local ok, erreur = pcall(registre.enregistrer, "pas_une_case")
  verifier(not ok and string.find(tostring(erreur), "case inconnue", 1, true), "une case non déclarée : erreur")
  registre.invalider()
  egal(registre.lire("essai_a").n, 5, "relue")
end)

essai("registre par case (fiche 01) : l'ancien flux relu puis réécrit par case ; une case illisible seule remise à neuf", function()
  depart()
  local registre = Scriptorium.registre
  registre.declarer_case("essai_c", 1, function() return { n = 0 } end)
  registre.declarer_case("essai_d", 1, function() return { n = 0 } end)
  FauxJeu.registre_stocke = registre.serialiser({ format = registre.format, cases = {
    essai_c = { version = 1, donnees = { n = 3 } }, essai_d = { version = 1, donnees = { n = 4 } },
    ancienne = { version = 1, donnees = { y = 2 } } } })
  registre.invalider()
  egal(registre.lire("essai_c").n, 3, "l'ancien flux relu")
  registre.lire("essai_c").n = 30
  registre.enregistrer("essai_c")
  verifier(FauxJeu.registre_jetons.index ~= nil, "l'index posé")
  egal(FauxJeu.registre_jetons.ancien, nil, "l'ancien flux vidé")
  verifier(FauxJeu.registre_jetons.cases.essai_d ~= nil, "toutes les cases réécrites à la migration")
  verifier(FauxJeu.registre_jetons.cases.ancienne ~= nil, "même celle que le socle ne connaît pas")
  -- Une case abîmée : elle seule est remise à neuf.
  FauxJeu.registre_jetons.cases.essai_d = "{abime"
  registre.invalider()
  egal(registre.lire("essai_c").n, 30, "l'autre case intacte")
  egal(registre.lire("essai_d").n, 0, "l'abîmée remise à neuf")
  egal(registre.etat_de("essai_d"), "abimee", "notée abîmée")
end)

essai("registre par case (fiche 01) : à la fin du battement, une case changée sans être nommée est écrite ; une case non surveillée, non", function()
  depart()
  local registre = Scriptorium.registre
  registre.declarer_case("essai_e", 1, function() return { n = 0 } end)
  registre.declarer_case("essai_f", 1, function() return { n = 0 } end, nil, { surveillee = false })
  registre.enregistrer(nil, true)
  registre.lire("essai_e").n = 7
  registre.lire("essai_f").n = 8
  FauxJeu.cases_ecrites = {}
  Scriptorium.battre()
  local e, f = false, false
  for _, nom in ipairs(FauxJeu.cases_ecrites) do
    if nom == "essai_e" then e = true end
    if nom == "essai_f" then f = true end
  end
  verifier(e, "la surveillée, changée : écrite au battement")
  verifier(not f, "la non surveillée : pas écrite")
  FauxJeu.cases_ecrites = {}
  Scriptorium.battre()
  local encore = false
  for _, nom in ipairs(FauxJeu.cases_ecrites) do
    if nom == "essai_e" then encore = true end
  end
  verifier(not encore, "inchangée : pas réécrite")
end)

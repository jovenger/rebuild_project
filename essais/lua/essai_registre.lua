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
    verifier(registre.enregistrer(true) ~= nil, "forcée : écrite tout de suite")
    d.n = 3
    FauxJeu.temps = 103
    verifier(registre.enregistrer() ~= nil, "l'intervalle passé : tout de suite")
  end)
  Scriptorium.noyau.reglages.registre_intervalle_s = ancien
  registre.en_attente = false
  verifier(ok, "sans erreur : " .. tostring(erreur))
end)

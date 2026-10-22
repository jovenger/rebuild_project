-- Essais du coffre et de la logistique (fiche 02_coffre.md).

local coffre = Scriptorium.coffre

essai("coffre : au départ, rien dans le coffre ni dans les réserves", function()
  depart()
  egal(coffre.solde(), 0, "groschen")
  for sorte in pairs(coffre.sortes) do
    egal(coffre.reserve(sorte), 0, "réserve " .. sorte)
  end
  egal(#coffre.livre(), 0, "livre vide")
  egal(coffre.reserve("or"), nil, "sorte inconnue -> nil")
end)

essai("coffre : encaisser puis payer tient le livre et le solde", function()
  depart()
  FauxJeu.heure = 12.5
  verifier(coffre.encaisser(100, "butin"), "encaisser")
  verifier(coffre.payer(30, "solde"), "payer")
  egal(coffre.solde(), 70, "solde")
  local livre = coffre.livre()
  egal(#livre, 2, "deux lignes")
  egal(livre[1].numero, 1, "numéro 1")
  egal(livre[1].montant, 100, "entrée signée +")
  egal(livre[1].apres, 100, "solde après la 1re")
  egal(livre[1].moment, 12.5, "moment du jeu")
  egal(livre[2].montant, -30, "sortie signée -")
  egal(livre[2].motif, "solde", "motif")
  egal(livre[2].apres, 70, "solde après la 2e")
  local bilan = coffre.bilan()
  egal(bilan.entrees, 100, "total entrées")
  egal(bilan.sorties, 30, "total sorties")
  egal(bilan.entrees - bilan.sorties, bilan.groschen, "entrées moins sorties = solde")
end)

essai("coffre : une dépense que le coffre ne couvre pas est refusée, et Henry n'est jamais touché", function()
  depart()
  FauxJeu.bourse_henry = 1000
  coffre.encaisser(20, "butin")
  local ok, raison = coffre.payer(50, "solde")
  egal(ok, false, "refusé")
  egal(raison, "coffre_insuffisant", "raison")
  egal(coffre.solde(), 20, "solde intact")
  egal(#coffre.livre(), 1, "aucune ligne ajoutée")
  egal(FauxJeu.bourse_henry, 1000, "bourse d'Henry intacte")
  egal(FauxJeu.appels_retirer, 0, "le camp n'a jamais demandé la bourse d'Henry")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_coffre_manque", "le joueur est prévenu")
end)

essai("coffre : montants et motifs invalides refusés, sans ligne", function()
  depart()
  coffre.encaisser(100, "butin")
  local cas = {
    { 0, "solde", "montant_invalide" },
    { -5, "solde", "montant_invalide" },
    { 2.5, "solde", "montant_invalide" },
    { "dix", "solde", "montant_invalide" },
    { 10, "", "motif_invalide" },
    { 10, "Solde", "motif_invalide" },
    { 10, "paie du jour", "motif_invalide" },
    { 10, nil, "motif_invalide" },
  }
  for _, c in ipairs(cas) do
    local ok, raison = coffre.payer(c[1], c[2])
    egal(ok, false, "refus " .. tostring(c[1]) .. " / " .. tostring(c[2]))
    egal(raison, c[3], "raison " .. tostring(c[1]) .. " / " .. tostring(c[2]))
  end
  egal(coffre.solde(), 100, "solde intact")
  egal(#coffre.livre(), 1, "une seule ligne")
end)

essai("coffre : verser à Henry débite le coffre seulement si le jeu a donné", function()
  depart()
  coffre.encaisser(100, "butin")
  verifier(coffre.verser_a_henry(40, "part_henry"), "versement")
  egal(coffre.solde(), 60, "coffre débité")
  egal(FauxJeu.bourse_henry, 40, "bourse d'Henry créditée")
  local ok, raison = coffre.verser_a_henry(100, "part_henry")
  egal(ok, false, "refus faute de groschen")
  egal(raison, "coffre_insuffisant", "raison")
  FauxJeu.donner_en_panne = true
  ok, raison = coffre.verser_a_henry(10, "part_henry")
  egal(ok, false, "refus si le jeu ne donne pas")
  egal(raison, "jeu_en_echec", "raison")
  egal(coffre.solde(), 60, "coffre non débité quand le jeu échoue")
end)

essai("coffre : Henry dépose depuis sa bourse, refus s'il n'a pas assez", function()
  depart()
  FauxJeu.bourse_henry = 50
  verifier(coffre.deposer_par_henry(30, "depot"), "dépôt")
  egal(coffre.solde(), 30, "coffre crédité")
  egal(FauxJeu.bourse_henry, 20, "bourse débitée")
  local ok, raison = coffre.deposer_par_henry(25, "depot")
  egal(ok, false, "refus")
  egal(raison, "henry_insuffisant", "raison")
  egal(coffre.solde(), 30, "coffre intact")
  egal(FauxJeu.bourse_henry, 20, "bourse intacte")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_coffre_henry_manque", "le joueur est prévenu")
end)

essai("coffre : réserves, ajout et prélèvement, sorte inconnue, insuffisance, épuisement", function()
  depart()
  verifier(coffre.ajouter_reserve("vivres", 10, "achat"), "ajout")
  egal(coffre.reserve("vivres"), 10, "dix vivres")
  verifier(coffre.prelever_reserve("vivres", 4, "repas"), "prélèvement")
  egal(coffre.reserve("vivres"), 6, "six vivres")
  local ok, raison = coffre.prelever_reserve("vivres", 7, "repas")
  egal(ok, false, "refus au-delà")
  egal(raison, "reserve_insuffisante", "raison")
  ok, raison = coffre.ajouter_reserve("or", 1, "achat")
  egal(ok, false, "sorte inconnue")
  egal(raison, "sorte_inconnue", "raison")
  ok, raison = coffre.ajouter_reserve("vivres", 1.5, "achat")
  egal(ok, false, "unité non entière")
  egal(raison, "montant_invalide", "raison")
  verifier(coffre.prelever_reserve("vivres", 6, "repas"), "tout prélevé")
  Scriptorium.bandeau.battre()
  egal(FauxJeu.en_ecran, "@ui_scriptorium_coffre_epuise_vivres", "épuisement annoncé")
  local livre = coffre.livre()
  egal(livre[3].sorte, "vivres", "sorte de la ligne")
  egal(livre[3].montant, -6, "montant signé")
  egal(livre[3].apres, 0, "reste après")
  egal(coffre.solde(), 0, "les réserves ne touchent pas aux groschen")
end)

essai("coffre : chaque sorte a son message d'épuisement", function()
  depart()
  for sorte, fiche in pairs(coffre.sortes) do
    verifier(string.find(fiche.cle_epuise, "^ui_scriptorium_coffre_epuise_" .. sorte .. "$") ~= nil, "clé de " .. sorte)
  end
end)

essai("coffre : le livre est borné, les totaux restent exacts", function()
  depart()
  local garde = coffre.reglages.lignes_gardees
  for _ = 1, garde + 25 do
    coffre.encaisser(3, "butin")
  end
  coffre.payer(7, "solde")
  local livre = coffre.livre()
  egal(#livre, garde, "borné")
  egal(livre[#livre].numero, garde + 26, "les numéros continuent")
  local bilan = coffre.bilan()
  egal(bilan.entrees, 3 * (garde + 25), "entrées exactes malgré l'oubli des vieilles lignes")
  egal(bilan.sorties, 7, "sorties exactes")
  egal(bilan.groschen, 3 * (garde + 25) - 7, "solde exact")
  egal(#coffre.livre(5), 5, "les 5 dernières")
  egal(coffre.livre(5)[5].montant, -7, "la toute dernière est la dépense")
end)

essai("coffre : tout est écrit dans la partie et relu tel quel", function()
  depart()
  FauxJeu.bourse_henry = 10
  coffre.deposer_par_henry(10, "depot")
  coffre.encaisser(90, "butin")
  coffre.payer(25, "solde")
  coffre.ajouter_reserve("biere", 12, "achat")
  local avant = coffre.bilan()
  local chaine = FauxJeu.registre_stocke
  verifier(chaine ~= nil, "écrit")

  depart()
  FauxJeu.registre_stocke = chaine
  local apres = coffre.bilan()
  egal(apres.groschen, avant.groschen, "solde relu")
  egal(apres.entrees, avant.entrees, "entrées relues")
  egal(apres.reserves.biere, 12, "réserve relue")
  egal(apres.lignes, 4, "lignes relues")
  egal(coffre.livre()[3].motif, "solde", "motif relu")
end)

essai("coffre : une sorte ajoutée au socle après coup part à zéro dans une partie ancienne", function()
  depart()
  coffre.encaisser(5, "butin")
  local chaine = FauxJeu.registre_stocke
  depart()
  FauxJeu.registre_stocke = string.gsub(chaine, '%["cuir"%]=0,', "")
  verifier(FauxJeu.registre_stocke ~= chaine, "la partie ancienne n'a pas la sorte")
  egal(coffre.reserve("cuir"), 0, "sorte servie à zéro")
end)

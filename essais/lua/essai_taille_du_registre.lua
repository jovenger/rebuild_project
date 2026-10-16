-- La taille du registre d'un camp plein (note de JoVenGer du 15/10 : aucune valeur enregistrée de plus de 65 535
-- octets ; le registre est coupé en tranches par la liaison). La mesure est affichée par essais/tout_verifier.py.

local registre = Scriptorium.registre
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre
local hommes = Scriptorium.hommes
local enceinte = Scriptorium.enceinte
local directeur = Scriptorium.directeur

local function copie_profonde(source)
  if type(source) ~= "table" then return source end
  local resultat = {}
  for cle, valeur in pairs(source) do resultat[cle] = copie_profonde(valeur) end
  return resultat
end

essai("registre : un camp plein (80 hommes) se mesure, s'écrit et se relit à l'identique", function()
  depart_avec_caractere()
  FauxJeu.heure = 2600.5
  camp.fonder({ x = 3283, y = 1098, z = 52 }, 0)
  camp.agrandir()
  camp.agrandir()
  coffre.encaisser(100000, "butin")
  for sorte in pairs(coffre.sortes) do coffre.ajouter_reserve(sorte, 500, "achat") end
  verifier(enceinte.batir() and enceinte.batir(), "palissade et tours")
  verifier(directeur.installer(), "Directeur")
  -- Douze hommes engagés (les lits du camp), puis copiés jusqu'à quatre-vingts, chacun avec son caractère.
  for i = 1, 12 do
    hommes.embaucher({ role = (i % 3 == 0) and "arbaletrier" or ((i % 3 == 1) and "homme_d_armes" or "archer"), semaines = 20 })
  end
  local donnees_hommes = registre.lire("hommes")
  local donnees_caractere = registre.lire("caractere")
  local modele = donnees_hommes.liste[donnees_hommes.ordre[1]]
  -- Fiche 15, V73 b 3 : chacun porte deux tenues (une bataille et une punition, avec leur point) et une exemption, pour
  -- peser la vraie taille d'un camp plein.
  hommes.tenir(modele.id, "bataille", { activite = "bataille", lieu = "rang_avant", cap = 90, fin = "liberation",
                                        position = { x = 3301.25, y = 1012.75, z = 112.5 } })
  hommes.tenir(modele.id, "punition", { activite = "corvee", lieu = "corvee_punition", cap = 0, fin = 2420.5,
                                        position = { x = 3298.5, y = 1015.25, z = 112.5 } })
  hommes.exempter(modele.id, "garde_de_nuit")
  local modele_caractere = Scriptorium.caractere.de(modele.id) and donnees_caractere.hommes[modele.id]
  for i = 13, 80 do
    local id = "homme_" .. i
    local f = copie_profonde(modele)
    f.id, f.nom, f.lit = id, "Bohuslav de Talmberk", nil
    donnees_hommes.liste[id] = f
    table.insert(donnees_hommes.ordre, id)
    donnees_caractere.hommes[id] = copie_profonde(modele_caractere)
  end
  egal(#hommes.liste(), 80, "quatre-vingts hommes")
  for i = 1, 50 do
    table.insert(donnees_hommes.anciens, { id = "homme_" .. (100 + i), nom = "Jindřich le Taciturne", role = "archer",
                                          cause = "fin_de_contrat", moment = 2400.25 + i })
  end
  -- Le livre plein, trente batailles, vingt fautes de chaque côté, vingt patrouilles (leurs cases se déclarent au
  -- premier usage).
  Scriptorium.bataille.resultats()
  Scriptorium.discipline.reputation()
  Scriptorium.patrouilles.journal()
  for _ = 1, 60 do coffre.payer(1, "solde") end
  local donnees_bataille = registre.lire("bataille")
  for i = 1, 30 do
    table.insert(donnees_bataille.resultats, { bande = "bande_" .. i, sorte = "brigands", effectif = 12, issue = "victoire_couteuse",
      morts = { "homme_7", "homme_9" }, blesses = { { id = "homme_3", jours = 3 }, { id = "homme_4", jours = 5 } },
      butin = 115, part_coffre = 39, pillage = 0, moment = 2500.75 + i })
  end
  local donnees_discipline = registre.lire("discipline")
  for i = 1, 20 do
    table.insert(donnees_discipline.a_juger, { id = "faute_" .. i, sorte = "ivresse", coupable = "homme_5",
                                               nom = "Ondřej le Rouge", moment = 2550.25 + i })
    table.insert(donnees_discipline.juges, { id = "faute_" .. (20 + i), sorte = "rixe", coupable = "homme_6",
                                             nom = "Mikuláš Kladivo", moment = 2520.25 + i, peine = "amende", victime = "homme_8" })
  end
  local donnees_patrouilles = registre.lire("patrouilles")
  donnees_patrouilles.journal = donnees_patrouilles.journal or {}
  for i = 1, 20 do
    table.insert(donnees_patrouilles.journal, { id = "patrouille_" .. i, chemin = "route_du_village", issue = "rodeurs",
                                               hommes = { "homme_10", "homme_11", "homme_12" }, butin = 21, retour = 2560.5 + i })
  end
  local chaine = registre.enregistrer()
  Essais.taille_du_registre_plein = #chaine
  verifier(#chaine > 10000, "un registre de camp plein pèse : " .. #chaine .. " octets")
  -- Relu, il se réécrit à l'identique.
  registre.invalider()
  registre.charger(chaine)
  egal(registre.enregistrer(), chaine, "relu puis réécrit à l'identique")
end)

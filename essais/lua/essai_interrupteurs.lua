-- Essais des interrupteurs (fiche 16, 3 a) : chaque règle éteinte ne fait plus rien ; rallumée, elle reprend.

local hommes = Scriptorium.hommes
local coffre = Scriptorium.coffre
local camp = Scriptorium.camp
local I = Scriptorium.noyau.interrupteurs

local function preparer()
  depart()
  FauxJeu.heure = 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 100, "achat")
  return hommes.embaucher({ role = "homme_d_armes", semaines = 1, prime = 0 })
end

essai("interrupteurs : chaque nom est connu, un nom inconnu est une erreur ; 0 éteint, 1 allumé", function()
  for nom in pairs(I) do
    verifier(Scriptorium.actif(nom) == true, nom .. " allumé au banc")
  end
  verifier(not pcall(Scriptorium.actif, "inconnu"), "un nom inconnu : erreur")
end)

essai("interrupteurs : la solde de la semaine éteinte ne paie rien et ne compte pas d'impayé", function()
  local id = preparer()
  I.solde_de_la_semaine = 0
  local avant = coffre.solde()
  local r = hommes.payer_la_solde()
  egal(coffre.solde(), avant, "éteinte : rien payé")
  egal(r.impayes, 0, "éteinte : aucun impayé")
  egal(hommes.fiche(id).impayes, 0, "aucun impayé compté")
  I.solde_de_la_semaine = 1
  hommes.payer_la_solde()
  verifier(coffre.solde() < avant, "rallumée : la solde payée")
end)

essai("interrupteurs : les contrats à durée éteints : personne ne part en fin de contrat", function()
  preparer()
  hommes.battre()
  I.contrats_a_duree = 0
  FauxJeu.heure = 10 + 9 * 24
  hommes.battre()
  egal(#hommes.liste(), 1, "éteints : il reste après la fin de son contrat")
  I.contrats_a_duree = 1
  FauxJeu.heure = 10 + 10 * 24
  hommes.battre()
  egal(#hommes.liste(), 0, "rallumés : il part")
end)

essai("interrupteurs : l'aguerrissement éteint ne monte plus et ne pèse plus au combat", function()
  local id = preparer()
  Scriptorium.caractere.poser_le_trait(id, "aguerri", 90)
  I.aguerrissement = 0
  local facteur_eteint = Scriptorium.caractere.facteur_de_combat(id)
  Scriptorium.caractere.apres_bataille({ id })
  egal(Scriptorium.caractere.de(id).aguerri, 90, "éteint : rien gagné à la bataille")
  I.aguerrissement = 1
  local facteur_allume = Scriptorium.caractere.facteur_de_combat(id)
  verifier(facteur_allume > facteur_eteint, "allumé : un vétéran pèse plus")
  Scriptorium.caractere.apres_bataille({ id })
  verifier(Scriptorium.caractere.de(id).aguerri > 90, "allumé : il s'aguerrit")
end)

essai("interrupteurs : l'usure en points éteinte : rien d'usé, aucun malus", function()
  local id = preparer()
  I.usure_en_points = 0
  Scriptorium.atelier.user_apres_bataille({ id, id, id, id })
  egal(Scriptorium.atelier.usure_de(id), 0, "éteinte : aucune usure")
  egal(Scriptorium.atelier.facteur_de(id), 1, "aucun malus")
  I.usure_en_points = 1
  for _ = 1, 4 do Scriptorium.atelier.user_apres_bataille({ id }) end
  verifier(Scriptorium.atelier.usure_de(id) > 0, "rallumée : il s'use")
end)

essai("interrupteurs : les fautes à l'aube éteintes : aucun incident ; les exactions éteintes : prix neutre", function()
  preparer()
  Scriptorium.directeur.installer()
  Scriptorium.discipline.battre()
  local r = Scriptorium.discipline.reglages
  local avant = { r.chance_de_base, r.chance_morose, r.chance_abattu }
  r.chance_de_base, r.chance_morose, r.chance_abattu = 1, 1, 1
  I.fautes_a_l_aube = 0
  local eteintes, allumees = 0, 0
  for k = 1, 4 do
    FauxJeu.heure = 10 + 24 * k
    eteintes = eteintes + Scriptorium.discipline.battre().fautes
  end
  egal(eteintes, 0, "éteintes : aucune faute en quatre aubes")
  I.fautes_a_l_aube = 1
  for k = 5, 8 do
    FauxJeu.heure = 10 + 24 * k
    allumees = allumees + Scriptorium.discipline.battre().fautes
  end
  verifier(allumees > 0, "rallumées : des fautes")
  r.chance_de_base, r.chance_morose, r.chance_abattu = avant[1], avant[2], avant[3]
  I.exactions = 0
  egal(Scriptorium.discipline.facteur_de_prix(), 1, "exactions éteintes : prix neutre")
  I.exactions = 1
end)

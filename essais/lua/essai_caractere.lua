-- Essais du caractère de chaque homme (fiche 11_caractere.md).

local caractere = Scriptorium.caractere
local hommes = Scriptorium.hommes
local camp = Scriptorium.camp
local coffre = Scriptorium.coffre
local bataille = Scriptorium.bataille
local discipline = Scriptorium.discipline
local directeur = Scriptorium.directeur

-- Un camp de trois niveaux (douze places), un coffre garni, « nombre » hommes engagés.
-- « vrai » : les fourchettes validées du caractère ; sinon des hommes ordinaires (traits à 50).
local function preparer(nombre, vrai)
  if vrai then depart_avec_caractere() else depart() end
  FauxJeu.heure = 10
  camp.fonder({ x = 0, y = 0, z = 0 }, 0)
  camp.agrandir()
  camp.agrandir()
  coffre.encaisser(5000, "butin")
  coffre.ajouter_reserve("vivres", 1000, "achat")
  local ids = {}
  for i = 1, nombre do
    local role = (i % 2 == 1) and "homme_d_armes" or "archer"
    ids[i] = hommes.embaucher({ role = role, semaines = 20, prime = 0 })
  end
  return ids
end

local function jours(n)
  local depart_heure = FauxJeu.heure
  for k = 1, n do
    FauxJeu.heure = depart_heure + 24 * k
    hommes.battre()
  end
end

local function lignes_avec(motif)
  local n = 0
  for _, ligne in ipairs(FauxJeu.journal_lignes) do
    if string.find(ligne, motif, 1, true) then n = n + 1 end
  end
  return n
end

essai("caractère : tirage dans les fourchettes, avec sa propre graine", function()
  local ids = preparer(0, true)
  bataille.fixer_la_graine(77)
  local attendu = bataille.tirage()
  bataille.fixer_la_graine(77)
  ids[1] = hommes.embaucher({ role = "archer", semaines = 4, prime = 0 })
  ids[2] = hommes.embaucher({ role = "barbier", semaines = 4, prime = 0 })
  egal(bataille.tirage(), attendu, "l'embauche ne touche pas au hasard des batailles")
  local differents = false
  for _, id in ipairs(ids) do
    local c = caractere.de(id)
    for _, trait in ipairs(caractere.traits) do
      local v = c.traits[trait.nom]
      verifier(v >= 0 and v <= 100 and math.floor(v) == v, "trait " .. trait.nom .. " entier de 0 à 100 : " .. tostring(v))
    end
    for _, envie in ipairs(caractere.envies) do
      verifier(c.envies[envie.nom] >= 0 and c.envies[envie.nom] <= 100, "envie " .. envie.nom)
    end
    verifier(c.aguerri >= 10 and c.aguerri <= 40, "aguerrissement de départ de 10 à 40 : " .. c.aguerri)
    egal(c.fatigue, 0, "frais à l'embauche")
  end
  for _, trait in ipairs(caractere.traits) do
    if caractere.de(ids[1]).traits[trait.nom] ~= caractere.de(ids[2]).traits[trait.nom] then differents = true end
  end
  verifier(differents, "deux hommes ne se ressemblent pas")
end)

essai("caractère : la ration selon l'appétit, jamais moins d'un vivre", function()
  local ids = preparer(3, true)
  caractere.poser_le_trait(ids[1], "appetit", 0)
  caractere.poser_le_trait(ids[2], "appetit", 50)
  caractere.poser_le_trait(ids[3], "appetit", 100)
  egal(caractere.ration_de(ids[1], 2), 1, "petit mangeur : un vivre")
  egal(caractere.ration_de(ids[2], 2), 2, "ordinaire : deux")
  egal(caractere.ration_de(ids[3], 2), 3, "gros mangeur : trois")
  local avant = coffre.reserve("vivres")
  jours(1)
  egal(avant - coffre.reserve("vivres"), 6, "un repas : 1 + 2 + 3 vivres")
end)

essai("caractère : une semaine ordinaire laisse reposés les hommes ordinaires d'une compagnie de dix", function()
  local ids = preparer(10, false)
  jours(7)
  for _, id in ipairs(ids) do
    verifier(caractere.de(id).fatigue < 50, "reposé après une semaine : " .. caractere.de(id).fatigue)
  end
end)

essai("caractère : le vite las s'épuise, perd du moral et va au lit le soir", function()
  local ids = preparer(10, false)
  local las = ids[3]
  caractere.poser_le_trait(las, "endurance", 0)
  caractere.poser_le_trait(las, "forme", 0)
  jours(2)
  verifier(caractere.de(las).fatigue > caractere.de(ids[4]).fatigue, "plus fatigué que l'ordinaire")
  jours(3)
  verifier(caractere.de(las).fatigue >= caractere.reglages.seuil_epuise, "épuisé : " .. caractere.de(las).fatigue)
  local moral = hommes.fiche(las).moral
  local moral_ordinaire = hommes.fiche(ids[4]).moral
  jours(1)
  egal(hommes.fiche(las).moral - moral, (hommes.fiche(ids[4]).moral - moral_ordinaire) - 2, "épuisé : moral − 2 de plus par jour")
  -- Le soir suivant, à chaque heure où il n'est pas de garde, il est au lit.
  local veilles = 0
  for _, h in ipairs({ 19.5, 20.5, 21.5 }) do
    local heure = FauxJeu.heure - FauxJeu.heure % 24 + 24 + h
    local soir = hommes.activite_de(las, heure)
    if soir.activite ~= "garde" then
      egal(soir.activite, "sommeil", "l'épuisé va au lit à " .. h .. " h")
      veilles = veilles + 1
    end
  end
  verifier(veilles > 0, "au moins une heure de veillée sans garde")
  verifier(caractere.facteur_de_combat(las) < caractere.facteur_de_combat(ids[4]), "il se bat moins bien")
  egal(caractere.connaitre(las).fatigue, "ui_scriptorium_caractere_epuise", "dit épuisé au rapport")
end)

essai("caractère : les soins selon la forme, les fractions s'additionnent", function()
  local ids = preparer(2, true)
  caractere.poser_le_trait(ids[1], "forme", 100)
  caractere.poser_le_trait(ids[2], "forme", 0)
  hommes.blesser(ids[1], 3)
  hommes.blesser(ids[2], 3)
  jours(1)
  egal(hommes.fiche(ids[1]).blessure, 2, "forme 100, jour 1 : 1,5 → un jour ôté")
  egal(hommes.fiche(ids[2]).blessure, 3, "forme 0, jour 1 : 0,5 → rien encore")
  jours(1)
  egal(hommes.fiche(ids[1]).blessure, 0, "jour 2 : 1,5 + 0,5 → deux jours ôtés")
  egal(hommes.fiche(ids[2]).blessure, 2, "jour 2 : 0,5 + 0,5 → un jour ôté")
end)

essai("caractère : l'aguerrissement selon le don, l'entraînement renforce l'endurance", function()
  local ids = preparer(2, true)
  caractere.poser_le_trait(ids[1], "don", 100)
  caractere.poser_le_trait(ids[2], "don", 0)
  for _, id in ipairs(ids) do
    caractere.poser_le_trait(id, "aguerri", 20)
    caractere.poser_le_trait(id, "endurance", 50)
    for _, envie in ipairs(caractere.envies) do caractere.poser_le_trait(id, envie.nom, 0) end
    caractere.poser_le_trait(id, "feu", 100)
  end
  jours(2)
  local vite, lent = caractere.de(ids[1]).aguerri - 20, caractere.de(ids[2]).aguerri - 20
  verifier(vite > 0 and lent > 0, "les deux progressent à l'exercice")
  verifier(math.abs(vite - 3 * lent) < 1e-9, "le doué progresse trois fois plus vite : " .. vite .. " / " .. lent)
  verifier(caractere.de(ids[1]).traits.endurance > 50, "l'exercice renforce l'endurance")
end)

essai("caractère : la force au combat, l'ordre de chute, le sang-froid", function()
  local ids = preparer(3, true)
  caractere.poser_le_trait(ids[1], "aguerri", 0)
  caractere.poser_le_trait(ids[1], "courage", 0)
  caractere.poser_le_trait(ids[2], "aguerri", 100)
  caractere.poser_le_trait(ids[2], "courage", 100)
  verifier(math.abs(caractere.facteur_de_combat(ids[1]) - 0.8 * 0.85) < 1e-9, "bleu craintif : 0,8 × 0,85")
  verifier(math.abs(caractere.facteur_de_combat(ids[2]) - 1.2 * 1.15) < 1e-9, "vétéran hardi : 1,2 × 1,15")
  caractere.poser_le_trait(ids[2], "fatigue", 75)
  verifier(math.abs(caractere.facteur_de_combat(ids[2]) - 1.2 * 1.15 * 0.85) < 1e-9, "fatigué : × 0,85")
  caractere.poser_le_trait(ids[2], "fatigue", 95)
  verifier(math.abs(caractere.facteur_de_combat(ids[2]) - 1.2 * 1.15 * 0.7) < 1e-9, "épuisé : × 0,7")
  -- ids[1] et ids[3] sont hommes d'armes (rang avant), ids[2] archer (rang arrière).
  caractere.poser_le_trait(ids[1], "jugement", 90)
  caractere.poser_le_trait(ids[3], "jugement", 10)
  caractere.poser_le_trait(ids[2], "jugement", 0)
  local ordre = caractere.ordre_de_chute({ ids[1], ids[2], ids[3] })
  egal(ordre[1], ids[3], "rang avant, moindre jugement : tombe le premier")
  egal(ordre[2], ids[1], "puis l'avisé du rang avant")
  egal(ordre[3], ids[2], "le rang arrière ensuite, même écervelé")
  caractere.poser_le_trait(ids[1], "sang_froid", 0)
  caractere.poser_le_trait(ids[2], "sang_froid", 100)
  egal(caractere.moral_ajuste(ids[1], -10), -15, "s'emporte : − 15")
  egal(caractere.moral_ajuste(ids[2], -10), -5, "sang-froid : − 5")
  egal(caractere.moral_ajuste(ids[1], 10), 10, "un gain n'est pas touché")
end)

essai("caractère : une bataille fatigue, aguerrit, fait connaître ; une blessure affaiblit la forme", function()
  local ids = preparer(4, true)
  for _, id in ipairs(ids) do
    caractere.poser_le_trait(id, "fatigue", 0)
    caractere.poser_le_trait(id, "aguerri", 20)
    caractere.poser_le_trait(id, "don", 50)
    caractere.poser_le_trait(id, "forme", 50)
  end
  FauxJeu.refuser_ennemis = true
  bataille.lever_une_bande({ sorte = "deserteurs", effectif = 1, direction = 0, delai = 0 })
  bataille.battre()
  local r = bataille.resultats()[1]
  egal(r.issue, "victoire", "victoire facile")
  for _, id in ipairs(ids) do
    if hommes.fiche(id) then
      egal(caractere.de(id).fatigue, 20, "fatigue de la bataille")
      egal(caractere.de(id).aguerri, 24, "aguerri : 20 + 4")
      verifier(caractere.de(id).connus.courage and caractere.de(id).connus.jugement and caractere.de(id).connus.sang_froid,
               "courage, jugement et sang-froid connus")
      local attendu = (hommes.fiche(id).blessure > 0) and 49 or 50
      egal(caractere.de(id).traits.forme, attendu, "le blessé perd un point de forme")
    end
  end
end)

essai("caractère : le jugement et les penchants orientent les fautes", function()
  local ids = preparer(4, true)
  egal(caractere.facteur_de_faute(ids[1]), 1.5 - caractere.de(ids[1]).traits.jugement / 100, "facteur selon le jugement")
  caractere.poser_le_trait(ids[1], "boisson", 100)
  caractere.poser_le_trait(ids[1], "bagarre", 0)
  caractere.poser_le_trait(ids[1], "vol", 0)
  egal(caractere.poids_de_faute(ids[1], "ivresse"), 2, "buveur : ivresse × 2")
  egal(caractere.poids_de_faute(ids[1], "rixe"), 0, "paisible : jamais de rixe")
  egal(caractere.poids_de_faute(ids[1], "exaction"), 0, "ni bagarre ni vol : jamais d'exaction")
  -- Un homme sans aucun penchant ne commet aucune faute, même quand la chance l'y pousse.
  for _, id in ipairs(ids) do
    caractere.poser_le_trait(id, "jugement", 0)
    for _, nom in ipairs({ "boisson", "bagarre", "vol" }) do caractere.poser_le_trait(id, nom, 0) end
  end
  caractere.poser_le_trait(ids[1], "boisson", 100)
  discipline.reglages.chance_de_base, discipline.reglages.chance_morose, discipline.reglages.chance_abattu = 1, 1, 1
  local heure = FauxJeu.heure
  for k = 1, 4 do
    FauxJeu.heure = heure + 24 * k
    discipline.battre()
  end
  -- Les fautes à juger, et celles restées sans jugement deux jours (prescrites).
  local fautes = discipline.a_juger()
  for _, f in ipairs(discipline.juges()) do table.insert(fautes, f) end
  verifier(#fautes > 0, "le buveur fait des fautes")
  for _, f in ipairs(fautes) do
    egal(f.coupable, ids[1], "seul le buveur en commet")
    egal(f.sorte, "ivresse", "et ce sont des ivresses")
  end
  verifier(caractere.de(ids[1]).connus.boisson, "son penchant est connu")
  verifier(not caractere.de(ids[2]).connus.boisson, "pas celui des autres")
end)

essai("caractère : le temps libre selon les envies, le choix gardé pour la soirée", function()
  local ids = preparer(1, true)
  local id = ids[1]
  for _, envie in ipairs(caractere.envies) do caractere.poser_le_trait(id, envie.nom, 0) end
  caractere.poser_le_trait(id, "des", 100)
  local soir = 24 + 20
  local a = hommes.activite_de(id, soir)
  egal(a.activite, "des", "il aime les dés")
  egal(a.lieu, "des", "au coin des dés")
  caractere.poser_le_trait(id, "des", 0)
  caractere.poser_le_trait(id, "entrainement", 100)
  egal(hommes.activite_de(id, soir + 1).activite, "des", "le choix du soir ne change pas")
  egal(hommes.activite_de(id, soir + 24).activite, "entrainement", "le lendemain soir, l'entraînement")
  for _, envie in ipairs(caractere.envies) do caractere.poser_le_trait(id, envie.nom, 0) end
  egal(hommes.activite_de(id, soir + 48).activite, "veillee", "sans aucune envie : la veillée au feu")
end)

essai("caractère : la faim affaiblit", function()
  local ids = preparer(1, true)
  caractere.poser_le_trait(ids[1], "forme", 50)
  caractere.poser_le_trait(ids[1], "endurance", 50)
  coffre.prelever_reserve("vivres", coffre.reserve("vivres"), "essai")
  FauxJeu.heure = 10
  jours(1)
  egal(caractere.de(ids[1]).traits.forme, 49, "affamé : forme − 1")
  verifier(caractere.de(ids[1]).traits.endurance < 50 + 9 * 0.1, "affamé : l'endurance perd 0,5 malgré l'exercice")
end)

essai("caractère : découvert avec le temps, dit en mots au rapport", function()
  local ids = preparer(2, true)
  local id = ids[1]
  caractere.poser_le_trait(id, "appetit", 90)
  caractere.poser_le_trait(id, "endurance", 50)
  local savoir = caractere.connaitre(id)
  egal(#savoir.mots, 0, "rien de connu à l'embauche")
  egal(savoir.inconnus, #caractere.traits + 1, "tous les traits et les envies inconnus")
  jours(6)
  verifier(not caractere.de(id).connus.appetit, "pas avant sept jours")
  jours(1)
  verifier(caractere.de(id).connus.appetit and caractere.de(id).connus.envies, "après sept jours : appétit, envies")
  verifier(caractere.de(id).connus.don, "sept jours d'exercice : le don")
  verifier(not caractere.de(id).connus.courage, "le courage attend une bataille")
  local trouve = false
  for _, mot in ipairs(caractere.connaitre(id).mots) do
    if mot == "ui_scriptorium_caractere_appetit_fort" then trouve = true end
    verifier(mot ~= "ui_scriptorium_caractere_endurance_faible" and mot ~= "ui_scriptorium_caractere_endurance_fort",
             "un trait ordinaire ne s'écrit pas")
  end
  verifier(trouve, "« gros mangeur » au rapport")
  verifier(lignes_avec("on connaît mieux") > 0, "découverte notée au journal")
  jours(23)
  verifier(caractere.de(id).connus.boisson and caractere.de(id).connus.vol, "après trente jours : les penchants")
  -- La Gestion du camp.
  verifier(directeur.installer(), "Directeur installé")
  local ok, liste = directeur.agir("connaitre_ses_hommes", {})
  verifier(ok, "Connaître ses hommes, par le Directeur")
  egal(#liste, 2, "un compte rendu par homme")
  egal(liste[1].nom, hommes.fiche(id).nom, "avec son nom")
end)

essai("caractère : un homme d'une sauvegarde d'avant le caractère en reçoit un, gardé ensuite", function()
  local ids = preparer(1, true)
  Scriptorium.registre.lire("caractere").hommes[ids[1]] = nil
  verifier(caractere.ration_de(ids[1], 2) >= 1, "un premier usage")
  local c = caractere.de(ids[1])
  verifier(c ~= nil and c.traits.appetit >= 0 and c.traits.appetit <= 100, "caractère tiré au premier usage")
  verifier(c.aguerri >= 10 and c.aguerri <= 40, "aguerrissement de départ")
  Scriptorium.registre.enregistrer()
  Scriptorium.registre.invalider()
  local relu = caractere.de(ids[1])
  for _, trait in ipairs(caractere.traits) do
    egal(relu.traits[trait.nom], c.traits[trait.nom], "même trait relu : " .. trait.nom)
  end
end)

essai("caractère : un homme parti est oublié ; tout est relu", function()
  local ids = preparer(2, true)
  caractere.poser_le_trait(ids[1], "appetit", 77)
  local graine_avant = Scriptorium.registre.lire("caractere").graine
  Scriptorium.registre.enregistrer()
  Scriptorium.registre.invalider()
  egal(caractere.de(ids[1]).traits.appetit, 77, "trait relu")
  egal(Scriptorium.registre.lire("caractere").graine, graine_avant, "graine relue")
  hommes.renvoyer(ids[2])
  egal(caractere.de(ids[2]), nil, "parti : oublié")
  egal(Scriptorium.registre.lire("caractere").hommes[ids[2]], nil, "plus rien au registre")
end)

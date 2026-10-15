-- Le combat et les batailles : lever une bande, l'ordre de bataille, l'issue, les pertes, le butin.
-- Fiche de comportement : docs/socle/fiches/05_bataille.md

Scriptorium = Scriptorium or {}

local bataille = {}
Scriptorium.bataille = bataille

bataille.reglages = {
  delai_par_defaut = 2,        -- heures de jeu avant l'arrivée
  distance_arrivee = 60,       -- mètres du camp
  avertissement = 1,           -- heures avant l'arrivée où le joueur est prévenu
  duree_max_contact = 2,       -- heures de contact avant que la règle tranche
  ecart_entre_hommes = 1.2,    -- mètres
  distance_rang_avant = 10,
  distance_rang_arriere = 7,
  effectif_max = 60,
  journal_gardes = 30,
  duree_des_corps = 24,        -- heures de jeu où les corps ennemis restent à fouiller (choix de JoVenGer, 14/10)
}

-- Butin par tête doublé à la validation de la fiche par JoVenGer (14/10).
bataille.sortes = {
  brigands   = { poids = 1.0, butin_par_tete = 16 },
  deserteurs = { poids = 0.8, butin_par_tete = 10 },
  soudards   = { poids = 1.2, butin_par_tete = 20 },
  coumans    = { poids = 1.4, butin_par_tete = 24 },
}

-- Poids au combat et rang de chaque rôle ; les rôles absents restent au feu.
bataille.roles = {
  homme_d_armes = { poids = 3, rang = "avant" },
  pavoisier     = { poids = 2, rang = "avant" },
  arbaletrier   = { poids = 2.5, rang = "arriere" },
  archer        = { poids = 2, rang = "arriere" },
}

-- Issues, du meilleur au pire : rapport de force minimal, pertes, moral, part du butin.
bataille.issues = {
  { nom = "victoire", rapport = 1.5, morts = 0, blesses = 0.15, moral = 10, butin = 1.0, cle = "ui_scriptorium_bataille_victoire" },
  { nom = "victoire_couteuse", rapport = 1.0, morts = 0.10, blesses = 0.30, moral = 5, butin = 0.6, cle = "ui_scriptorium_bataille_victoire_couteuse" },
  { nom = "repoussee", rapport = 0.7, morts = 0.20, blesses = 0.40, moral = -5, butin = 0.2, cle = "ui_scriptorium_bataille_repoussee" },
  { nom = "defaite", rapport = 0, morts = 0.35, blesses = 0.40, moral = -15, butin = 0, cle = "ui_scriptorium_bataille_defaite" },
}

local function jeu()
  return Scriptorium.jeu
end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

local function hommes()
  return Scriptorium.hommes
end

local function camp()
  return Scriptorium.camp
end

local function coffre()
  return Scriptorium.coffre
end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return { prochaine = 1, bandes = {}, ordre = {}, resultats = {}, graine = Scriptorium.hasard_depuis(12345) }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("bataille") then
    registre.declarer_case("bataille", 1, donnees_neuves)
  end
  return registre.lire("bataille")
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

local function refuser(raison, detail)
  jeu().journal("Bataille : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

-- Hasard gardé au registre : la même partie rejoue les mêmes coups. Une ancienne graine (un seul nombre) donne ses
-- trois germes à la première lecture.
local function tirage(d)
  if not Scriptorium.hasard_en_ordre(d.graine) then
    d.graine = Scriptorium.hasard_depuis(d.graine)
  end
  return Scriptorium.tirer(d.graine)
end

-- Le même hasard, pour les autres morceaux (patrouilles).
function bataille.tirage()
  return tirage(donnees())
end

function bataille.fixer_la_graine(graine)
  donnees().graine = Scriptorium.hasard_depuis(graine)
end

-- ---------------------------------------------------------------- lever une bande

function bataille.lever_une_bande(ordre)
  ordre = ordre or {}
  local d = donnees()
  if not camp().est_fonde() then
    return refuser("camp_absent")
  end
  local sorte = bataille.sortes[ordre.sorte]
  if not sorte then
    return refuser("sorte_inconnue", tostring(ordre.sorte))
  end
  local effectif = ordre.effectif
  if type(effectif) ~= "number" or math.floor(effectif) ~= effectif or effectif < 1 or effectif > bataille.reglages.effectif_max then
    return refuser("effectif_invalide", tostring(effectif))
  end
  if type(ordre.direction) ~= "number" then
    return refuser("direction_invalide", tostring(ordre.direction))
  end
  local delai = ordre.delai
  if delai == nil then delai = bataille.reglages.delai_par_defaut end
  if type(delai) ~= "number" or delai < 0 then
    return refuser("delai_invalide", tostring(delai))
  end
  local heure = jeu().heure_du_jeu()
  local id = "bande_" .. d.prochaine
  d.prochaine = d.prochaine + 1
  d.bandes[id] = {
    id = id,
    sorte = ordre.sorte,
    effectif = effectif,
    direction = ordre.direction % 360,
    levee = heure,
    arrivee = heure + delai,
    etat = "en_marche",
    annoncee = false,
    contact = nil,
    personnages = nil,
    combattants = {},
  }
  table.insert(d.ordre, id)
  enregistrer()
  jeu().journal("Bataille : bande « " .. id .. " » levée, " .. effectif .. " " .. ordre.sorte .. ", arrivée à " .. (heure + delai) .. " h")
  return id
end

function bataille.bande(id)
  local b = donnees().bandes[id]
  if not b then
    return nil
  end
  local copie = {}
  for cle, valeur in pairs(b) do
    if type(valeur) ~= "table" then copie[cle] = valeur end
  end
  copie.combattants = {}
  for i, c in ipairs(b.combattants or {}) do copie.combattants[i] = c end
  copie.personnages = {}
  for i, p in ipairs(b.personnages or {}) do copie.personnages[i] = p end
  copie.ennemis = b.personnages and #b.personnages or 0
  return copie
end

-- Les bandes qui ne sont pas finies, dans l'ordre de levée.
function bataille.bandes()
  local d = donnees()
  local liste = {}
  for _, id in ipairs(d.ordre) do
    if d.bandes[id].etat ~= "finie" then
      table.insert(liste, id)
    end
  end
  return liste
end

-- ---------------------------------------------------------------- forces et ordre de bataille

-- Les combattants valides, rang avant puis rang arrière, par ancienneté.
function bataille.combattants()
  local avant, arriere = {}, {}
  for _, id in ipairs(hommes().liste()) do
    local f = hommes().fiche(id)
    local role = bataille.roles[f.role]
    if role and f.blessure == 0 then
      if role.rang == "avant" then table.insert(avant, id) else table.insert(arriere, id) end
    end
  end
  return avant, arriere
end

function bataille.force_des_notres()
  local avant, arriere = bataille.combattants()
  local force, moral, nombre = 0, 0, 0
  for _, liste in ipairs({ avant, arriere }) do
    for _, id in ipairs(liste) do
      local f = hommes().fiche(id)
      local facteur = 1
      if Scriptorium.atelier and Scriptorium.atelier.facteur_de then
        facteur = Scriptorium.atelier.facteur_de(id)
      end
      -- Aguerrissement, courage et fatigue de l'homme (fiche 11).
      if Scriptorium.caractere then
        facteur = facteur * Scriptorium.caractere.facteur_de_combat(id)
      end
      force = force + bataille.roles[f.role].poids * facteur
      moral = moral + f.moral
      nombre = nombre + 1
    end
  end
  if nombre == 0 then
    return 0
  end
  local facteur_moral = 0.7 + 0.5 * (moral / nombre) / 100
  local bonus = 1
  if Scriptorium.enceinte and Scriptorium.enceinte.bonus then
    bonus = Scriptorium.enceinte.bonus()
  end
  return force * facteur_moral * bonus
end

function bataille.force_de_la_bande(b)
  return b.effectif * bataille.sortes[b.sorte].poids
end

-- Un point du camp dans le monde, le plan étant tourné vers la menace.
local function point_face_a(direction, x, y)
  local tourne = camp().dans_le_monde({ x = 0, y = 0, z = 0, cap = direction }, x, y, 0)
  return camp().point(tourne.x, tourne.y, direction)
end

-- L'ordre de bataille face à une direction : { avant = {…}, arriere = {…}, reserve = {…} },
-- chaque entrée { id, position, cap }.
function bataille.ordre_de_bataille(direction)
  local avant, arriere = bataille.combattants()
  local r = bataille.reglages
  local ordre = { avant = {}, arriere = {}, reserve = {} }
  local n = #avant
  for i, id in ipairs(avant) do
    local x = (i - (n + 1) / 2) * r.ecart_entre_hommes
    table.insert(ordre.avant, { id = id, position = point_face_a(direction, x, r.distance_rang_avant), cap = direction, x = x })
  end
  -- Les tireurs se placent dans les intervalles du rang avant, puis débordent sur les ailes.
  local intervalles = {}
  for i = 1, n - 1 do
    table.insert(intervalles, (i - n / 2) * r.ecart_entre_hommes)
  end
  local gauche = -(n / 2) * r.ecart_entre_hommes
  local droite = (n / 2) * r.ecart_entre_hommes
  for j, id in ipairs(arriere) do
    local x
    if intervalles[j] ~= nil then
      x = intervalles[j]
    else
      local k = j - #intervalles
      local cote = (k % 2 == 1) and -1 or 1
      local ecart = math.ceil(k / 2) * r.ecart_entre_hommes
      x = (cote < 0) and (gauche - ecart) or (droite + ecart)
    end
    table.insert(ordre.arriere, { id = id, position = point_face_a(direction, x, r.distance_rang_arriere), cap = direction, x = x })
  end
  for _, id in ipairs(hommes().liste()) do
    local place = false
    for _, liste in ipairs({ avant, arriere }) do
      for _, autre in ipairs(liste) do
        if autre == id then place = true end
      end
    end
    if not place then
      table.insert(ordre.reserve, { id = id })
    end
  end
  return ordre
end

-- ---------------------------------------------------------------- contact et fin

local function mettre_en_bataille(d, b)
  local ordre = bataille.ordre_de_bataille(b.direction)
  b.combattants = {}
  for _, rang in ipairs({ "avant", "arriere" }) do
    for _, entree in ipairs(ordre[rang]) do
      hommes().affecter(entree.id, "bataille", "rang_" .. rang, entree.position, entree.cap)
      table.insert(b.combattants, entree.id)
    end
  end
end

local function liberer_les_hommes(b)
  for _, id in ipairs(b.combattants or {}) do
    if hommes().fiche(id) then
      hommes().liberer_affectation(id)
    end
  end
end

local function arriver(d, b)
  local position = point_face_a(b.direction, 0, bataille.reglages.distance_arrivee)
  local cap = (b.direction + 180) % 360
  b.etat = "au_contact"
  b.contact = jeu().heure_du_jeu()
  mettre_en_bataille(d, b)
  local personnages = jeu().faire_venir_ennemis(b.sorte, b.effectif, position, cap)
  if type(personnages) == "table" and #personnages > 0 then
    b.personnages = personnages
    jeu().journal("Bataille : « " .. b.id .. " » au contact, " .. #personnages .. " ennemi(s) dans le jeu")
  else
    b.personnages = nil
    jeu().journal("Bataille : « " .. b.id .. " » au contact, le jeu n'a pas fait venir la bande : la règle tranchera")
  end
end

local function choisir_issue(rapport)
  for _, issue in ipairs(bataille.issues) do
    if rapport >= issue.rapport then
      return issue
    end
  end
  return bataille.issues[#bataille.issues]
end

-- Applique l'issue : morts, blessés, moral, pillage, butin. Rend le résultat.
local function appliquer(d, b, issue, morts_par_le_jeu)
  local resultat = { bande = b.id, sorte = b.sorte, effectif = b.effectif, issue = issue.nom,
                     morts = {}, blesses = {}, butin = 0, part_coffre = 0, pillage = 0, moment = jeu().heure_du_jeu() }
  -- Les combattants encore là, rang avant d'abord (il tombe le premier).
  local vivants = {}
  for _, id in ipairs(b.combattants) do
    if hommes().fiche(id) then table.insert(vivants, id) end
  end
  -- Dans un même rang, l'homme de moindre jugement tombe le premier (fiche 11).
  if Scriptorium.caractere then
    vivants = Scriptorium.caractere.ordre_de_chute(vivants)
  end
  if morts_par_le_jeu then
    for _, id in ipairs(morts_par_le_jeu) do
      table.insert(resultat.morts, id)
    end
  else
    local nombre_morts = math.floor(#vivants * issue.morts + tirage(d))
    nombre_morts = math.min(nombre_morts, #vivants)
    for i = 1, nombre_morts do
      table.insert(resultat.morts, vivants[i])
    end
  end
  local survivants = {}
  for _, id in ipairs(vivants) do
    local mort = false
    for _, m in ipairs(resultat.morts) do
      if m == id then mort = true end
    end
    if not mort then table.insert(survivants, id) end
  end
  local nombre_blesses = math.min(#survivants, math.floor(#survivants * issue.blesses + 0.5))
  -- Les blessés sont pris au hasard parmi les survivants.
  local candidats = {}
  for i, id in ipairs(survivants) do candidats[i] = id end
  for _ = 1, nombre_blesses do
    local k = math.floor(tirage(d) * #candidats) + 1
    local id = table.remove(candidats, k)
    local jours = 2 + math.floor(tirage(d) * 4)
    table.insert(resultat.blesses, { id = id, jours = jours })
  end
  -- L'équipement des combattants s'use.
  if Scriptorium.atelier and Scriptorium.atelier.user_apres_bataille then
    Scriptorium.atelier.user_apres_bataille(vivants)
  end
  -- Libérer les affectations avant de toucher aux fiches.
  liberer_les_hommes(b)
  for _, id in ipairs(resultat.morts) do
    hommes().retirer(id, "mort")
  end
  for _, blesse in ipairs(resultat.blesses) do
    hommes().blesser(blesse.id, blesse.jours)
  end
  -- Le retour de bataille : fatigue, aguerrissement, découverte ; une blessure affaiblit la forme (fiche 11).
  if Scriptorium.caractere then
    Scriptorium.caractere.apres_bataille(survivants)
    for _, blesse in ipairs(resultat.blesses) do
      Scriptorium.caractere.blessure_recue(blesse.id)
    end
  end
  hommes().moral_pour_tous(issue.moral)
  -- Pillage en cas de défaite.
  if issue.nom == "defaite" then
    local pille = math.floor(coffre().solde() / 2)
    if pille > 0 then
      coffre().payer(pille, "pillage")
      resultat.pillage = pille
    end
  end
  -- Butin, partagé selon la coutume.
  local butin = math.floor(b.effectif * bataille.sortes[b.sorte].butin_par_tete * issue.butin)
  if butin > 0 then
    coffre().encaisser(butin, "butin")
    local part_hommes = math.floor(butin / 2)
    local part_capitaine = 0
    local effectif = hommes().effectif()
    if effectif.par_rang.capitaine and effectif.par_rang.capitaine > 0 then
      part_capitaine = math.floor(butin / 6)
    end
    if part_hommes > 0 then coffre().payer(part_hommes, "part_hommes") end
    if part_capitaine > 0 then coffre().payer(part_capitaine, "part_capitaine") end
    resultat.butin = butin
    resultat.part_coffre = butin - part_hommes - part_capitaine
  end
  annoncer(issue.cle, { importance = "alerte" })
  if resultat.butin > 0 then
    annoncer("ui_scriptorium_bataille_butin", { complement = resultat.part_coffre .. " groschen" })
  end
  table.insert(d.resultats, resultat)
  while #d.resultats > bataille.reglages.journal_gardes do
    table.remove(d.resultats, 1)
  end
  return resultat
end

-- À la fin, les ennemis encore debout s'en vont ; les corps restent à fouiller un temps, puis le battement
-- les retire (choix de JoVenGer, 14/10).
local function finir(d, b, resultat)
  if b.personnages then
    local debout, corps = {}, {}
    for _, identifiant in ipairs(b.personnages) do
      if jeu().ennemis_vivants({ identifiant }) > 0 then
        table.insert(debout, identifiant)
      else
        table.insert(corps, identifiant)
      end
    end
    if #debout > 0 then
      jeu().renvoyer_ennemis(debout)
    end
    if #corps > 0 then
      b.corps = corps
      b.corps_retires_a = jeu().heure_du_jeu() + bataille.reglages.duree_des_corps
      jeu().coucher_les_corps(corps)
    end
    b.personnages = nil
  end
  b.etat = "finie"
  b.fin = jeu().heure_du_jeu()
  b.issue = resultat.issue
  jeu().journal("Bataille : « " .. b.id .. " » finie : " .. resultat.issue .. ", " .. #resultat.morts .. " mort(s), "
                .. #resultat.blesses .. " blessé(s), butin " .. resultat.butin)
end

-- L'issue par la règle, pour une bande au contact.
function bataille.resoudre_par_la_regle(id)
  local d = donnees()
  local b = d.bandes[id]
  if not b or b.etat ~= "au_contact" then
    return nil
  end
  local notre = bataille.force_des_notres()
  local leur = bataille.force_de_la_bande(b)
  local rapport = (leur > 0) and (notre / leur) or 10
  local issue = choisir_issue(rapport)
  local resultat = appliquer(d, b, issue, nil)
  resultat.rapport = rapport
  finir(d, b, resultat)
  enregistrer()
  return resultat
end

-- Une escarmouche loin du camp (embuscade de patrouille) : les seuls hommes donnés,
-- sans enceinte, tranchée tout de suite par la règle. Rend le résultat.
function bataille.escarmouche(ids, sorte, effectif)
  local d = donnees()
  local id = "escarmouche_" .. d.prochaine
  d.prochaine = d.prochaine + 1
  local b = { id = id, sorte = sorte, effectif = effectif, direction = 0, levee = jeu().heure_du_jeu(),
              arrivee = jeu().heure_du_jeu(), etat = "au_contact", contact = jeu().heure_du_jeu(),
              personnages = nil, combattants = {} }
  local force, moral, nombre = 0, 0, 0
  for _, homme in ipairs(ids) do
    local f = hommes().fiche(homme)
    if f and bataille.roles[f.role] and f.blessure == 0 then
      table.insert(b.combattants, homme)
      local facteur = (Scriptorium.atelier and Scriptorium.atelier.facteur_de) and Scriptorium.atelier.facteur_de(homme) or 1
      if Scriptorium.caractere then
        facteur = facteur * Scriptorium.caractere.facteur_de_combat(homme)
      end
      force = force + bataille.roles[f.role].poids * facteur
      moral = moral + f.moral
      nombre = nombre + 1
    end
  end
  if nombre > 0 then
    force = force * (0.7 + 0.5 * (moral / nombre) / 100)
  end
  local leur = bataille.force_de_la_bande(b)
  local rapport = (leur > 0) and (force / leur) or 10
  local issue = choisir_issue(rapport)
  d.bandes[id] = b
  table.insert(d.ordre, id)
  local resultat = appliquer(d, b, issue, nil)
  resultat.rapport = rapport
  b.etat = "finie"
  b.fin = jeu().heure_du_jeu()
  b.issue = resultat.issue
  enregistrer()
  return resultat
end

-- L'issue par le jeu : les ennemis vivants et nos morts constatés.
local function resoudre_par_le_jeu(d, b)
  local vivants = jeu().ennemis_vivants(b.personnages)
  local morts = {}
  local combattants_vivants = 0
  for _, id in ipairs(b.combattants) do
    local f = hommes().fiche(id)
    if f then
      if f.personnage and jeu().personnage_mort(f.personnage) then
        table.insert(morts, id)
      else
        combattants_vivants = combattants_vivants + 1
      end
    end
  end
  if vivants > 0 and combattants_vivants > 0 then
    return nil
  end
  local issue
  if vivants == 0 then
    local part = (#b.combattants > 0) and (#morts / #b.combattants) or 0
    issue = (part <= 0.1) and bataille.issues[1] or bataille.issues[2]
  else
    issue = bataille.issues[4]
  end
  local resultat = appliquer(d, b, issue, morts)
  finir(d, b, resultat)
  return resultat
end

-- ---------------------------------------------------------------- battement

function bataille.battre()
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local rapport = { annoncees = 0, arrivees = 0, finies = 0, changements = 0 }
  for _, id in ipairs(d.ordre) do
    local b = d.bandes[id]
    if b.etat == "en_marche" then
      local avance = bataille.reglages.avertissement
      if Scriptorium.enceinte and Scriptorium.enceinte.avance_de_guet then
        avance = avance + Scriptorium.enceinte.avance_de_guet()
      end
      if Scriptorium.patrouilles and Scriptorium.patrouilles.avance_de_guet then
        avance = avance + Scriptorium.patrouilles.avance_de_guet()
      end
      if not b.annoncee and heure >= b.arrivee - avance then
        b.annoncee = true
        annoncer("ui_scriptorium_bataille_approche", { importance = "alerte", complement = b.effectif .. " hommes" })
        rapport.annoncees = rapport.annoncees + 1
        rapport.changements = rapport.changements + 1
      end
      if heure >= b.arrivee then
        arriver(d, b)
        rapport.arrivees = rapport.arrivees + 1
        rapport.changements = rapport.changements + 1
        if b.personnages == nil then
          bataille.resoudre_par_la_regle(id)
          rapport.finies = rapport.finies + 1
        end
      end
    elseif b.etat == "au_contact" then
      local resultat = nil
      if b.personnages then
        resultat = resoudre_par_le_jeu(d, b)
      end
      if resultat == nil and heure >= b.contact + bataille.reglages.duree_max_contact then
        resultat = bataille.resoudre_par_la_regle(id)
      end
      if resultat then
        rapport.finies = rapport.finies + 1
        rapport.changements = rapport.changements + 1
      end
    elseif b.etat == "finie" and b.corps and heure >= b.corps_retires_a then
      jeu().journal("Bataille : corps de « " .. b.id .. " » retirés (" .. #b.corps .. ")")
      jeu().renvoyer_ennemis(b.corps)
      b.corps = nil
      b.corps_retires_a = nil
      rapport.changements = rapport.changements + 1
    end
  end
  if rapport.changements > 0 then
    enregistrer()
  end
  return rapport
end

function bataille.resultats()
  local copie = {}
  for i, r in ipairs(donnees().resultats) do
    copie[i] = { bande = r.bande, sorte = r.sorte, effectif = r.effectif, issue = r.issue, morts = #r.morts,
                 blesses = #r.blesses, butin = r.butin, part_coffre = r.part_coffre, pillage = r.pillage, moment = r.moment }
  end
  return copie
end

Scriptorium.declarer_morceau("bataille", function()
  -- Les bandes avancent par le battement du socle.
end)

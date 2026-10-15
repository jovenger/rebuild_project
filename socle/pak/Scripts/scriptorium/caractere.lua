-- Le caractère de chaque homme : traits tirés à l'embauche (appétit, endurance, forme, don d'apprendre, jugement,
-- courage, sang-froid, penchants, envies), fatigue et aguerrissement, temps libre, évolution, découverte.
-- Idée de JoVenGer du 15/10 : chaque homme est quelqu'un.
-- Fiche de comportement : docs/socle/fiches/11_caractere.md

local Scriptorium = Scriptorium

local caractere = {}
Scriptorium.caractere = caractere

caractere.reglages = {
  trait_min = 0,                -- fourchette du tirage des traits et des envies (choix de JoVenGer : de 0 à 100)
  trait_max = 100,
  trait_ecart = 10,             -- largeur de la cloche (note de JoVenGer ; « étroite » : 2 sur 3 entre 40 et 60)
  aguerri_min = 10,             -- aguerrissement à l'embauche, en cloche autour du milieu (25)
  aguerri_max = 40,
  aguerri_ecart = 5,            -- 2 sur 3 entre 20 et 30
  appetit_facteur_min = 0.5,    -- ration × ce facteur pour l'appétit 0 …
  appetit_facteur_max = 1.5,    -- … et celui-ci pour 100
  fatigue_par_heure = 4,        -- par heure de travail, × (1,5 − endurance ⁄ 100)
  repos_par_heure = 10,         -- par heure de sommeil, × (0,5 + forme ⁄ 100)
  fatigue_bataille = 20,
  seuil_fatigue = 70,
  seuil_epuise = 90,
  malus_fatigue = 0.85,         -- force au combat du fatigué
  malus_epuise = 0.7,           -- et de l'épuisé
  moral_epuise = -2,            -- par jour passé épuisé
  gain_par_heure = 0.25,        -- aguerrissement par heure d'exercice, × (0,5 + don ⁄ 100)
  gain_bataille = 4,            -- par bataille survécue, × (0,5 + don ⁄ 100)
  aguerri_facteur_min = 0.8,    -- force au combat du bleu (0) …
  aguerri_facteur_max = 1.2,    -- … et du vétéran (100)
  courage_facteur_min = 0.85,
  courage_facteur_max = 1.15,
  endurance_par_heure = 0.1,    -- l'entraînement renforce
  faim_forme = -1,              -- un jour affamé
  faim_endurance = -0.5,
  blessure_forme = -1,          -- une blessure reçue
  forme_par_jour_sain = 0.1,    -- un jour bien nourri et sans blessure : la forme remonte, jusqu'à celle de l'embauche
  jours_pour_connaitre = 7,
  jours_pour_les_penchants = 30,
  seuil_faible = 35,            -- en dessous, le trait se dit « faible » ; au-dessus du seuil fort, « fort »
  seuil_fort = 65,
  seuil_bleu = 30,
  seuil_veteran = 70,
}

-- Les traits, et ce qui les fait découvrir : « sejour » (sept jours au camp), « exercice » (sept jours d'exercice),
-- « bataille » (la première), « faute » (la première de sa sorte, sinon après trente jours).
caractere.traits = {
  { nom = "appetit", decouverte = "sejour" },
  { nom = "endurance", decouverte = "sejour" },
  { nom = "forme", decouverte = "sejour" },
  { nom = "don", decouverte = "exercice" },
  { nom = "jugement", decouverte = "bataille" },
  { nom = "courage", decouverte = "bataille" },
  { nom = "sang_froid", decouverte = "bataille" },
  { nom = "boisson", decouverte = "faute" },
  { nom = "bagarre", decouverte = "faute" },
  { nom = "vol", decouverte = "faute" },
}

-- Les envies du temps libre (la veillée), et le lieu où chacune se passe.
caractere.envies = {
  { nom = "feu", cle = "ui_scriptorium_caractere_envie_feu" },
  { nom = "entrainement", cle = "ui_scriptorium_caractere_envie_entrainement" },
  { nom = "des", cle = "ui_scriptorium_caractere_envie_des" },
  { nom = "sommeil", cle = "ui_scriptorium_caractere_envie_sommeil" },
}

-- La faute qu'un penchant fait commettre, et le penchant qu'elle révèle.
caractere.penchant_de_la_faute = { ivresse = "boisson", rixe = "bagarre", vol = "vol" }

-- Les mots du rapport, par trait : faible, fort (un trait ordinaire ne s'écrit pas).
caractere.mots = {
  appetit = { faible = "ui_scriptorium_caractere_appetit_faible", fort = "ui_scriptorium_caractere_appetit_fort" },
  endurance = { faible = "ui_scriptorium_caractere_endurance_faible", fort = "ui_scriptorium_caractere_endurance_fort" },
  forme = { faible = "ui_scriptorium_caractere_forme_faible", fort = "ui_scriptorium_caractere_forme_fort" },
  don = { faible = "ui_scriptorium_caractere_don_faible", fort = "ui_scriptorium_caractere_don_fort" },
  jugement = { faible = "ui_scriptorium_caractere_jugement_faible", fort = "ui_scriptorium_caractere_jugement_fort" },
  courage = { faible = "ui_scriptorium_caractere_courage_faible", fort = "ui_scriptorium_caractere_courage_fort" },
  sang_froid = { faible = "ui_scriptorium_caractere_sang_froid_faible", fort = "ui_scriptorium_caractere_sang_froid_fort" },
  boisson = { faible = "ui_scriptorium_caractere_boisson_faible", fort = "ui_scriptorium_caractere_boisson_fort" },
  bagarre = { faible = "ui_scriptorium_caractere_bagarre_faible", fort = "ui_scriptorium_caractere_bagarre_fort" },
  vol = { faible = "ui_scriptorium_caractere_vol_faible", fort = "ui_scriptorium_caractere_vol_fort" },
}
caractere.mots_de_l_etat = {
  fatigue = "ui_scriptorium_caractere_fatigue",
  epuise = "ui_scriptorium_caractere_epuise",
  bleu = "ui_scriptorium_caractere_bleu",
  veteran = "ui_scriptorium_caractere_veteran",
}

-- Activités qui fatiguent, qui reposent, qui apprennent.
local travail = { exercice = true, corvee = true, garde = true, patrouille = true, bataille = true, entrainement = true }
local repos = { sommeil = true, repos = true }
local apprentissage = { exercice = true, entrainement = true }

local function jeu() return Scriptorium.jeu end
local function hommes() return Scriptorium.hommes end

local function borner(valeur, mini, maxi)
  if valeur < mini then return mini end
  if valeur > maxi then return maxi end
  return valeur
end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return { graine = Scriptorium.hasard_depuis(4242), hommes = {} }
end

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("caractere") then
    registre.declarer_case("caractere", 1, donnees_neuves)
  end
  return registre.lire("caractere")
end

local function enregistrer()
  Scriptorium.registre.enregistrer()
end

-- Le hasard du caractère, avec sa propre graine : il ne dérange pas celui des batailles.
local function tirage(d)
  if not Scriptorium.hasard_en_ordre(d.graine) then
    d.graine = Scriptorium.hasard_depuis(d.graine)
  end
  return Scriptorium.tirer(d.graine)
end

-- Un entier tiré en cloche autour du milieu de la fourchette : douze tirages de 0 à 1 ajoutés, moins six (presque
-- une loi normale, bornée à six écarts), fois l'écart ; arrondi et gardé dans la fourchette.
local function tirer_en_cloche(d, mini, maxi, ecart)
  if maxi <= mini then
    return mini
  end
  local somme = 0
  for _ = 1, 12 do
    somme = somme + tirage(d)
  end
  local valeur = math.floor((mini + maxi) / 2 + math.max(0, ecart) * (somme - 6) + 0.5)
  return math.max(mini, math.min(maxi, valeur))
end

-- Le même tirage, avec le hasard du caractère, pour qui veut tirer un trait (essais, Scriptorium).
function caractere.tirer_en_cloche(mini, maxi, ecart)
  return tirer_en_cloche(donnees(), mini, maxi, ecart)
end

-- La fiche de caractère d'un homme ; tirée au premier usage pour un homme qui n'en a pas (sauvegarde d'avant ce
-- morceau). Rend nil pour un homme inconnu.
local function fiche_de(d, id)
  local c = d.hommes[id]
  if c then
    return c
  end
  if not hommes().fiche(id) then
    return nil
  end
  local r = caractere.reglages
  c = { traits = {}, envies = {}, connus = {}, fatigue = 0, soin_reste = 0, jours = 0, jours_exercice = 0, soir = nil }
  for _, trait in ipairs(caractere.traits) do
    c.traits[trait.nom] = tirer_en_cloche(d, r.trait_min, r.trait_max, r.trait_ecart)
  end
  for _, envie in ipairs(caractere.envies) do
    c.envies[envie.nom] = tirer_en_cloche(d, r.trait_min, r.trait_max, r.trait_ecart)
  end
  c.aguerri = tirer_en_cloche(d, r.aguerri_min, r.aguerri_max, r.aguerri_ecart)
  c.forme_d_embauche = c.traits.forme
  d.hommes[id] = c
  return c
end

-- Tire le caractère d'un homme qui vient d'être engagé.
function caractere.naitre(id)
  local c = fiche_de(donnees(), id)
  if c then
    enregistrer()
  end
  return c ~= nil
end

function caractere.oublier(id)
  donnees().hommes[id] = nil
end

-- Une copie de la fiche de caractère (pour les essais et le rapport).
function caractere.de(id)
  local c = fiche_de(donnees(), id)
  if not c then
    return nil
  end
  local copie = { fatigue = c.fatigue, aguerri = c.aguerri, jours = c.jours, jours_exercice = c.jours_exercice,
                  traits = {}, envies = {}, connus = {} }
  for k, v in pairs(c.traits) do copie.traits[k] = v end
  for k, v in pairs(c.envies) do copie.envies[k] = v end
  for k, v in pairs(c.connus) do copie.connus[k] = v end
  return copie
end

-- Pour les essais et les réglages : pose un trait.
function caractere.poser_le_trait(id, nom, valeur)
  local c = fiche_de(donnees(), id)
  if not c then
    return false
  end
  if c.traits[nom] ~= nil then
    c.traits[nom] = valeur
  elseif c.envies[nom] ~= nil then
    c.envies[nom] = valeur
  elseif nom == "fatigue" or nom == "aguerri" then
    c[nom] = valeur
  else
    return false
  end
  return true
end

-- Un facteur qui va de « mini » (valeur 0) à « maxi » (valeur 100).
local function entre(mini, maxi, valeur)
  return mini + (maxi - mini) * valeur / 100
end

-- ---------------------------------------------------------------- découverte

local function decouvrir(c, nom, id)
  if c.connus[nom] then
    return
  end
  c.connus[nom] = true
  local f = hommes().fiche(id)
  jeu().journal("Caractère : on connaît mieux « " .. (f and f.nom or tostring(id)) .. " » : " .. nom)
end

local function decouvrir_par(c, id, moyen)
  for _, trait in ipairs(caractere.traits) do
    if trait.decouverte == moyen then
      decouvrir(c, trait.nom, id)
    end
  end
  if moyen == "sejour" then
    decouvrir(c, "envies", id)
  end
end

-- ---------------------------------------------------------------- ce que les traits changent

-- La ration du jour selon l'appétit : jamais moins d'un vivre.
function caractere.ration_de(id, base)
  local c = fiche_de(donnees(), id)
  if not c then
    return base
  end
  local r = caractere.reglages
  return math.max(1, math.floor(base * entre(r.appetit_facteur_min, r.appetit_facteur_max, c.traits.appetit) + 0.5))
end

-- Les jours de soin ôtés aujourd'hui selon la forme ; les fractions s'additionnent d'un jour à l'autre.
function caractere.jours_de_soin(id, soin)
  local c = fiche_de(donnees(), id)
  if not c then
    return soin
  end
  local total = soin * (0.5 + c.traits.forme / 100) + (c.soin_reste or 0)
  local jours = math.floor(total)
  c.soin_reste = total - jours
  return jours
end

-- La force au combat : aguerrissement, courage, fatigue.
function caractere.facteur_de_combat(id)
  local c = fiche_de(donnees(), id)
  if not c then
    return 1
  end
  local r = caractere.reglages
  local facteur = entre(r.aguerri_facteur_min, r.aguerri_facteur_max, c.aguerri)
                * entre(r.courage_facteur_min, r.courage_facteur_max, c.traits.courage)
  if c.fatigue >= r.seuil_epuise then
    facteur = facteur * r.malus_epuise
  elseif c.fatigue >= r.seuil_fatigue then
    facteur = facteur * r.malus_fatigue
  end
  return facteur
end

-- L'ordre dans lequel tombent les combattants : par rang (avant, puis arrière), et dans un rang, le moindre jugement
-- d'abord ; à jugement égal, l'ordre reçu.
function caractere.ordre_de_chute(ids)
  local d = donnees()
  local rangees = {}
  for i, id in ipairs(ids) do
    local f = hommes().fiche(id)
    local role = f and Scriptorium.bataille and Scriptorium.bataille.roles[f.role]
    local c = fiche_de(d, id)
    rangees[i] = { id = id, rang = (role and role.rang == "avant") and 1 or 2, jugement = c and c.traits.jugement or 50, i = i }
  end
  table.sort(rangees, function(a, b)
    if a.rang ~= b.rang then return a.rang < b.rang end
    if a.jugement ~= b.jugement then return a.jugement < b.jugement end
    return a.i < b.i
  end)
  local ordre = {}
  for i, p in ipairs(rangees) do ordre[i] = p.id end
  return ordre
end

-- Une perte de moral selon le sang-froid ; un gain n'est pas touché. Rend un entier.
function caractere.moral_ajuste(id, delta)
  if delta >= 0 then
    return delta
  end
  local c = fiche_de(donnees(), id)
  if not c then
    return delta
  end
  return math.floor(delta * (1.5 - c.traits.sang_froid / 100) + 0.5)
end

-- La chance de faute selon le jugement.
function caractere.facteur_de_faute(id)
  local c = fiche_de(donnees(), id)
  return c and (1.5 - c.traits.jugement / 100) or 1
end

-- Le poids d'une sorte de faute pour cet homme, selon ses penchants.
function caractere.poids_de_faute(id, nom)
  local c = fiche_de(donnees(), id)
  if not c then
    return 1
  end
  local penchant = caractere.penchant_de_la_faute[nom]
  if penchant then
    return c.traits[penchant] / 50
  end
  if nom == "exaction" then
    return (c.traits.bagarre + c.traits.vol) / 100
  end
  return 1
end

-- Une faute commise révèle son penchant.
function caractere.faute_commise(id, nom)
  local c = fiche_de(donnees(), id)
  local penchant = caractere.penchant_de_la_faute[nom]
  if c and penchant then
    decouvrir(c, penchant, id)
    enregistrer()
  end
end

-- Une blessure reçue (bataille, rixe) affaiblit la forme.
function caractere.blessure_recue(id)
  local c = fiche_de(donnees(), id)
  if c then
    c.traits.forme = borner(c.traits.forme + caractere.reglages.blessure_forme, 0, 100)
    enregistrer()
  end
end

-- Le retour d'une bataille ou d'une escarmouche, pour les survivants : fatigue, aguerrissement, découverte.
function caractere.apres_bataille(ids)
  local d = donnees()
  local r = caractere.reglages
  for _, survivant in ipairs(ids) do
    local c = fiche_de(d, survivant)
    if c then
      c.fatigue = borner(c.fatigue + r.fatigue_bataille, 0, 100)
      c.aguerri = borner(c.aguerri + r.gain_bataille * (0.5 + c.traits.don / 100), 0, 100)
      decouvrir_par(c, survivant, "bataille")
    end
  end
  enregistrer()
end

-- ---------------------------------------------------------------- le temps libre

-- Ce que l'homme fait de sa soirée : l'épuisé va au lit ; sinon ses envies, au hasard pondéré. Le choix d'un soir est
-- gardé. Rend « feu », « entrainement », « des » ou « sommeil ».
function caractere.choix_du_soir(id, heure)
  local d = donnees()
  local c = fiche_de(d, id)
  if not c then
    return "feu"
  end
  local jour = math.floor(heure / 24)
  if c.soir and c.soir.jour == jour then
    return c.soir.choix
  end
  local choix
  if c.fatigue >= caractere.reglages.seuil_epuise then
    choix = "sommeil"
  else
    local total = 0
    for _, envie in ipairs(caractere.envies) do total = total + c.envies[envie.nom] end
    choix = "feu"
    if total > 0 then
      local t = tirage(d) * total
      for _, envie in ipairs(caractere.envies) do
        t = t - c.envies[envie.nom]
        if t < 0 then
          choix = envie.nom
          break
        end
      end
    end
  end
  c.soir = { jour = jour, choix = choix }
  return choix
end

-- ---------------------------------------------------------------- la journée passée

-- Le compte d'une journée, au repas du matin : les vingt-quatre heures avant « fin » (au plus tôt depuis l'embauche).
-- Fatigue, aguerrissement, endurance, faim, découvertes. Rend la variation de moral du jour (épuisé).
function caractere.passer_la_journee(id, fin, affame)
  local d = donnees()
  local c = fiche_de(d, id)
  local f = hommes().fiche(id)
  if not c or not f then
    return 0
  end
  local r = caractere.reglages
  local debut = math.max(fin - 24, f.engage or (fin - 24))
  local heures_de_travail, heures_de_sommeil, heures_d_exercice = 0, 0, 0
  local h = debut
  while h < fin do
    local a = hommes().activite_de(id, h + 0.5)
    local activite = a and a.activite
    if travail[activite] then heures_de_travail = heures_de_travail + 1 end
    if repos[activite] then heures_de_sommeil = heures_de_sommeil + 1 end
    if apprentissage[activite] then heures_d_exercice = heures_d_exercice + 1 end
    h = h + 1
  end
  c.fatigue = borner(c.fatigue
    + heures_de_travail * r.fatigue_par_heure * (1.5 - c.traits.endurance / 100)
    - heures_de_sommeil * r.repos_par_heure * (0.5 + c.traits.forme / 100), 0, 100)
  c.aguerri = borner(c.aguerri + heures_d_exercice * r.gain_par_heure * (0.5 + c.traits.don / 100), 0, 100)
  c.traits.endurance = borner(c.traits.endurance + heures_d_exercice * r.endurance_par_heure, 0, 100)
  if affame then
    c.traits.forme = borner(c.traits.forme + r.faim_forme, 0, 100)
    c.traits.endurance = borner(c.traits.endurance + r.faim_endurance, 0, 100)
  elseif f.blessure == 0 then
    -- Bien nourri et sans blessure : la forme remonte doucement, jusqu'à celle de l'embauche (choix de JoVenGer, 15/10).
    local plafond = c.forme_d_embauche or c.traits.forme
    if c.traits.forme < plafond then
      c.traits.forme = math.min(plafond, c.traits.forme + r.forme_par_jour_sain)
    end
  end
  c.jours = c.jours + 1
  if heures_d_exercice > 0 then
    c.jours_exercice = c.jours_exercice + 1
  end
  if c.jours >= r.jours_pour_connaitre then decouvrir_par(c, id, "sejour") end
  if c.jours_exercice >= r.jours_pour_connaitre then decouvrir_par(c, id, "exercice") end
  if c.jours >= r.jours_pour_les_penchants then decouvrir_par(c, id, "faute") end
  enregistrer()
  if c.fatigue >= r.seuil_epuise then
    return r.moral_epuise
  end
  return 0
end

-- ---------------------------------------------------------------- connaître ses hommes

local function mot_du_trait(nom, valeur)
  local r = caractere.reglages
  local mots = caractere.mots[nom]
  if not mots then return nil end
  if valeur <= r.seuil_faible then return mots.faible end
  if valeur >= r.seuil_fort then return mots.fort end
  return nil
end

-- Ce que la Compagnie sait d'un homme : les traits découverts, en clés de texte ; le nombre encore inconnu ; sa fatigue
-- et son aguerrissement en mots.
function caractere.connaitre(id)
  local c = fiche_de(donnees(), id)
  local f = hommes().fiche(id)
  if not c or not f then
    return nil
  end
  local r = caractere.reglages
  local resultat = { id = id, nom = f.nom, mots = {}, inconnus = 0 }
  for _, trait in ipairs(caractere.traits) do
    if c.connus[trait.nom] then
      local mot = mot_du_trait(trait.nom, c.traits[trait.nom])
      if mot then table.insert(resultat.mots, mot) end
    else
      resultat.inconnus = resultat.inconnus + 1
    end
  end
  if c.connus.envies then
    local meilleure, poids = nil, -1
    for _, envie in ipairs(caractere.envies) do
      if c.envies[envie.nom] > poids then meilleure, poids = envie, c.envies[envie.nom] end
    end
    if meilleure and poids >= r.seuil_fort then table.insert(resultat.mots, meilleure.cle) end
  else
    resultat.inconnus = resultat.inconnus + 1
  end
  if c.fatigue >= r.seuil_epuise then
    resultat.fatigue = caractere.mots_de_l_etat.epuise
  elseif c.fatigue >= r.seuil_fatigue then
    resultat.fatigue = caractere.mots_de_l_etat.fatigue
  end
  if c.aguerri < r.seuil_bleu then
    resultat.aguerri = caractere.mots_de_l_etat.bleu
  elseif c.aguerri >= r.seuil_veteran then
    resultat.aguerri = caractere.mots_de_l_etat.veteran
  end
  return resultat
end

-- ---------------------------------------------------------------- Gestion du camp

local function entrees()
  if not Scriptorium.directeur then
    return
  end
  Scriptorium.directeur.ajouter_entree({
    action = "connaitre_ses_hommes", cle = "ui_scriptorium_gestion_connaitre", parametres = {},
    disponible = function()
      if #hommes().liste() == 0 then return false, "personne" end
      return true
    end,
    agir = function()
      local liste = {}
      for _, id in ipairs(hommes().liste()) do
        table.insert(liste, caractere.connaitre(id))
      end
      return true, liste
    end,
  })
end
caractere.installer_les_entrees = entrees

Scriptorium.declarer_morceau("caractere", function()
  entrees()
end)
entrees()

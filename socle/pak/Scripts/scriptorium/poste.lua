-- Poste d'essai : des commandes en français pour éprouver chaque morceau en jeu,
-- sans rien d'autre que le socle. Voir docs/socle/essai_en_jeu.md.

local Scriptorium = Scriptorium

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

-- Jetons du jeu (note de JoVenGer, partie 2, point 3) : écrire des jetons de plus en plus longs et les relire aussitôt,
-- puis, après « Sauvegarder et quitter » et rechargement, les relire encore : on sait ce que garde un jeton. Jamais
-- au-delà de 65 535 octets : le 15/10, des jetons de 66 000 à 200 000 ont rendu la sauvegarde impossible à recharger ;
-- 65 535 tout juste n'est pas essayé (le bord exact pourrait casser aussi).
poste.longueurs_de_jetons = { 16000, 32000, 60000, 65000 }

function poste.essai_jetons_ecrire()
  for _, longueur in ipairs(poste.longueurs_de_jetons) do
    local relu, intact = jeu().essayer_un_jeton(longueur)
    jeu().journal("Poste : jeton de " .. longueur .. " écrit, relu aussitôt " .. tostring(relu) .. ", intact = " .. tostring(intact))
  end
  return true
end

-- Registre : ce que le jeu garde de ses tranches ; et les calculs du socle qui doivent rester justes dans le Lua du
-- jeu (simple précision).
function poste.essai_registre_tranches()
  Scriptorium.registre.enregistrer()
  for _, ligne in ipairs(jeu().decrire_le_registre()) do
    jeu().journal("Poste : registre, " .. ligne)
  end
  local justes, ligne = jeu().verifier_les_nombres()
  jeu().journal("Poste : nombres " .. (justes and "justes" or "FAUX") .. ", " .. ligne)
  return justes
end

function poste.essai_jetons_relire()
  for _, longueur in ipairs(poste.longueurs_de_jetons) do
    local relu, intact = jeu().relire_un_jeton(longueur)
    jeu().journal("Poste : jeton de " .. longueur .. " après rechargement : " .. tostring(relu) .. ", intact = " .. tostring(intact))
  end
  return true
end

-- Coffre : Henry dépose, le camp paie, une réserve entre et sort, une dépense trop grosse est refusée.
function poste.essai_coffre()
  local coffre = Scriptorium.coffre
  local bourse_avant = jeu().groschen_d_henry()
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
                .. ", bourse d'Henry = " .. bourse_avant .. " -> " .. jeu().groschen_d_henry())
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
  local ok, raison = camp.fonder(camp.ancre_devant(jeu().position_du_joueur(), jeu().cap_du_joueur()), jeu().cap_du_joueur())
  local capacite = camp.capacite()
  jeu().journal("Poste : camp fondé = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or "")
                .. ", lits = " .. capacite.lits .. ", sièges = " .. capacite.sieges)
  return ok and "fonde" or "refuse", capacite.lits, capacite.sieges
end

-- Camp : ce que le moteur dit du feu central, d'un banc, d'une tente et d'un de ses lits (V23 ; le lit, V73 c 12 : un
-- lit du plan posé hors de sa tente, à replacer d'après les vraies dimensions).
function poste.essai_feu()
  local camp = Scriptorium.camp
  for _, nom in ipairs({ "feu_central", "siege_1", "tente_1", "lit_1a", "lit_1b" }) do
    local identifiant = camp.objet_de(nom)
    local description = identifiant and jeu().decrire_objet and jeu().decrire_objet(identifiant) or "pas posé"
    jeu().journal("Poste : objet « " .. nom .. " » : " .. tostring(description))
  end
  for _, nom in ipairs({ "porte", "pan_1", "tour_est" }) do
    local identifiant = Scriptorium.enceinte.objet_de(nom)
    local description = identifiant and jeu().decrire_objet and jeu().decrire_objet(identifiant) or "pas posé"
    jeu().journal("Poste : objet « enceinte " .. nom .. " » : " .. tostring(description))
  end
end

-- Henry : posé quarante mètres plus loin, pour chercher un terrain d'essai vierge (demande de JoVenGer du 14/10 :
-- ne pas dresser le camp dans un campement du jeu). Une commande par direction de boussole.
function poste.essai_aller(cap)
  local ok, compte_rendu = jeu().deplacer_le_joueur(40, cap)
  jeu().journal("Poste : Henry déplacé vers " .. tostring(cap) .. " = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

-- Fiche 15, V73 g 0 (la sonde du rechargement, piste du pair) : nos morceaux relus dans le jeu ouvert, depuis les copies
-- posées par outils/recharger.py, sans relancer le jeu. Seulement les morceaux dont les données vivent au registre et
-- qui n'ont pas de boucle à eux (ni le noyau, ni le registre, ni le bandeau, ni les réglages, ni le poste) ; et la
-- liaison, pour ses fonctions seulement (elle garde sa table et sa mémoire), relue la première. Les chevaux passagers sont retirés d'abord ; puis la sortie et l'entrée en partie, comme un chargement :
-- les anciennes boucles s'éteignent (génération), le réveil relance chaque morceau 30 s après.
poste.morceaux_rechargeables = { coffre = true, camp = true, hommes = true, bataille = true, directeur = true,
                                 enceinte = true, atelier = true, patrouilles = true, missions = true, discipline = true,
                                 caractere = true }

function poste.essai_recharger()
  local liste, chemin, raison = jeu().liste_du_rechargement()
  if type(liste) ~= "table" then
    jeu().journal("Poste : rechargement : pas de liste (" .. tostring(chemin) .. " " .. tostring(raison) .. ")")
    return false
  end
  local a_charger = {}
  for _, nom in ipairs(liste) do
    if nom == "liaison" then
      table.insert(a_charger, 1, nom)
    elseif poste.morceaux_rechargeables[nom] then
      table.insert(a_charger, nom)
    else
      jeu().journal("Poste : rechargement : « " .. tostring(nom) .. " » refusé (pas rechargeable)")
    end
  end
  if #a_charger == 0 then
    return false
  end
  local chevaux = 0
  for _, m in pairs(Scriptorium.hommes and Scriptorium.hommes.montures or {}) do
    if m.cheval then
      jeu().retirer_cheval(m.cheval)
      chevaux = chevaux + 1
    end
  end
  Scriptorium.sortir_de_partie()
  local recharges = {}
  for _, nom in ipairs(a_charger) do
    local ok, quoi = jeu().charger_un_morceau(nom)
    if ok then
      for _, morceau in ipairs(Scriptorium.morceaux) do
        if morceau.nom == nom then
          local demarre, erreur = pcall(morceau.demarrage)
          morceau.pret, morceau.erreur = demarre, demarre and nil or tostring(erreur)
          ok = demarre
          quoi = demarre and quoi or tostring(erreur)
        end
      end
    end
    jeu().journal("Poste : rechargement de « " .. nom .. " » : " .. (ok and "fait" or "ÉCHEC") .. " (" .. tostring(quoi) .. ")")
    if ok then
      table.insert(recharges, nom)
    end
  end
  Scriptorium.entrer_en_partie()
  jeu().journal("Poste : rechargement : " .. #recharges .. " morceau(x) (" .. table.concat(recharges, ", ") .. "), "
                .. chevaux .. " cheval(aux) retiré(s) ; réveil à venir")
  return #recharges == #a_charger
end

-- Fiche 15, V73 f 3 b : le bond d'Henry (comme un voyage rapide) : posé 200 mètres devant lui, pour le grand saut des
-- cavaliers ; l'heure du bond au journal (la latence se lit jusqu'à la pose de l'escorte).
function poste.essai_grand_saut()
  local ok, compte_rendu = jeu().deplacer_le_joueur(200, nil)
  jeu().journal("Poste : bond d'Henry de 200 m = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

-- Fiche 15, V73 f 3 b (les intérieurs, méthode du pair) : des lieux d'essai lus dans les calques de la carte (level.pak
-- de kutnohorsko, lecture seule), à l'auberge de Přítoky : « dedans », à 1 m des personnages de l'auberge (calque
-- kpri_pritoky/inn, z = leur plancher, 107,0) ; « dehors », le point du crieur « hostinec2 », à 32 m.
poste.lieux_d_essai = {
  auberge_dehors = { x = 2165.9, y = 1513.3, z = 107.3 },
  auberge_dedans = { x = 2160.0, y = 1482.2, z = 107.1 },
}

-- L'étage (méthode du pair) : un rayon vers le bas lancé de « depart_z » (le rez-de-chaussée à 107,0 + 4,5 m), en trois
-- points de l'intérieur au plus ; un plancher touché entre « plancher_min » et « plancher_max » est l'étage.
poste.etage_d_essai = {
  points = { { 2160.0, 1482.2 }, { 2157.5, 1484.0 }, { 2162.5, 1480.0 } },
  depart_z = 111.5, profondeur = 6, plancher_min = 108.5, plancher_max = 111,
}

function poste.essai_auberge_etage()
  local e = poste.etage_d_essai
  for i, p in ipairs(e.points) do
    local z, raison = jeu().plancher_sous(p[1], p[2], e.depart_z, e.profondeur)
    jeu().journal("Poste : étage, point " .. i .. " (" .. p[1] .. ", " .. p[2] .. ") : "
                  .. (z and string.format("touché à %.2f", z) or tostring(raison)))
    if z and z >= e.plancher_min and z <= e.plancher_max then
      local ok, compte_rendu = jeu().poser_le_joueur({ x = p[1], y = p[2], z = z + 0.1 })
      jeu().journal("Poste : Henry posé à l'étage = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
      return ok
    end
  end
  jeu().journal("Poste : pas d'étage trouvé en " .. #e.points .. " points")
  return false
end

-- La porte (V73 g, le nécessaire de JoVenGer) : l'intérieur de l'auberge cherché par des rayons autour du point du
-- crieur : un point est sous un toit si le premier obstacle vu d'en haut est à plus de « toit_min » m au-dessus du
-- terrain ; l'intérieur est un point sous un toit dont les quatre voisins (à « pas » m) le sont aussi ; le plus proche
-- du point du crieur (le côté de la porte) ; son plancher lu par un rayon lancé à « plancher_depuis_m » au-dessus du
-- terrain. Henry y est posé, relu.
poste.interieur_d_essai = { centre = { 2165.9, 1513.3 }, rayon = 16, pas = 2, haut_z = 130, toit_min = 2.5,
                            plancher_depuis_m = 1.6 }

function poste.essai_auberge_interieur()
  local e = poste.interieur_d_essai
  local toit = {}
  local function sous_un_toit(i, j)
    local cle = i .. "," .. j
    if toit[cle] == nil then
      local x, y = e.centre[1] + i * e.pas, e.centre[2] + j * e.pas
      local terrain = jeu().altitude_du_terrain(x, y)
      local haut = jeu().plancher_sous(x, y, e.haut_z, e.haut_z - (terrain or 0) + 2)
      toit[cle] = terrain ~= nil and haut ~= nil and haut > terrain + e.toit_min
    end
    return toit[cle]
  end
  local n = math.floor(e.rayon / e.pas)
  local meilleur, distance = nil, nil
  local sous_toit = 0
  for i = -n, n do
    for j = -n, n do
      if sous_un_toit(i, j) then
        sous_toit = sous_toit + 1
        if sous_un_toit(i + 1, j) and sous_un_toit(i - 1, j) and sous_un_toit(i, j + 1) and sous_un_toit(i, j - 1) then
          local d = math.sqrt(i * i + j * j) * e.pas
          if not distance or d < distance then
            meilleur, distance = { i, j }, d
          end
        end
      end
    end
  end
  if not meilleur then
    jeu().journal("Poste : intérieur : aucun point sous un toit entouré (" .. sous_toit .. " point(s) sous un toit)")
    return false
  end
  local x, y = e.centre[1] + meilleur[1] * e.pas, e.centre[2] + meilleur[2] * e.pas
  local terrain = jeu().altitude_du_terrain(x, y)
  local plancher = jeu().plancher_sous(x, y, terrain + e.plancher_depuis_m, e.plancher_depuis_m + 2)
  jeu().journal("Poste : intérieur : " .. sous_toit .. " point(s) sous un toit ; choisi (" .. x .. ", " .. y .. ") à "
                .. string.format("%.0f", distance) .. " m du crieur, terrain " .. tostring(terrain) .. ", plancher "
                .. tostring(plancher))
  if not plancher then
    return false
  end
  local ok, compte_rendu = jeu().poser_le_joueur({ x = x, y = y, z = plancher + 0.1 })
  jeu().journal("Poste : Henry posé à l'intérieur = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

-- Le gardien (V73 g) : le premier homme posé 20 m sous le terrain ; ou endormi.
function poste.essai_homme_sous_le_sol()
  local id = Scriptorium.hommes.liste()[1]
  local f = id and Scriptorium.hommes.fiche(id)
  if not (f and f.personnage) then
    jeu().journal("Poste : homme sous le sol : aucun homme présent")
    return false
  end
  local ok, compte_rendu = jeu().poser_sous_le_sol(f.personnage, 20)
  jeu().journal("Poste : « " .. f.nom .. " » sous le sol = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

function poste.essai_homme_endormi()
  local id = Scriptorium.hommes.liste()[2] or Scriptorium.hommes.liste()[1]
  local f = id and Scriptorium.hommes.fiche(id)
  if not (f and f.personnage) then
    jeu().journal("Poste : homme endormi : aucun homme présent")
    return false
  end
  local ok, compte_rendu = jeu().endormir(f.personnage)
  jeu().journal("Poste : « " .. f.nom .. " » endormi = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

function poste.essai_lieu(nom)
  local ok, compte_rendu = jeu().poser_le_joueur(poste.lieux_d_essai[nom])
  jeu().journal("Poste : Henry posé au lieu « " .. nom .. " » = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

-- Henry : posé sur le terrain d'essai (un pré dégagé hors du campement du jeu, liaison.terrain_d_essai).
-- Le camp du socle est levé avant, pour ne pas le laisser derrière soi.
function poste.essai_terrain_d_essai()
  if Scriptorium.camp.est_fonde() then
    Scriptorium.camp.lever()
  end
  local ok, compte_rendu = jeu().aller_au_terrain_d_essai()
  jeu().journal("Poste : terrain d'essai = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end
-- Camp : agrandit d'un niveau.
function poste.essai_camp_agrandir()
  local ok, raison = Scriptorium.camp.agrandir()
  jeu().journal("Poste : camp agrandi = " .. tostring(ok) .. (raison and (" (" .. raison .. ")") or "")
                .. ", niveau = " .. Scriptorium.camp.niveau())
  return ok
end

-- Camp : lève le camp.
-- Fin d'un essai de rechargement (V57) : renvoie les hommes, congédie le Directeur et lève le camp, pour ne rien
-- laisser dans la sauvegarde de la partie d'essai.
function poste.essai_tout_lever()
  local renvoyes = 0
  for _, id in ipairs(Scriptorium.hommes.liste()) do
    if Scriptorium.hommes.renvoyer(id) then
      renvoyes = renvoyes + 1
    end
  end
  local congedie = Scriptorium.directeur.est_installe() and Scriptorium.directeur.congedier()
  local leve = Scriptorium.camp.est_fonde() and Scriptorium.camp.lever()
  jeu().journal("Poste : tout levé, " .. renvoyes .. " homme(s) renvoyé(s), Directeur congédié = " .. tostring(congedie)
                .. ", camp levé = " .. tostring(leve))
  return true
end

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
  jeu().journal("Poste : hommes, engagés = " .. table.concat(ids, ", ") .. " ; total = " .. effectif.nombre
                .. ", présents = " .. effectif.presents .. ", coffre = " .. Scriptorium.coffre.solde())
  poste.battre_les_hommes()
  return ids, effectif
end

-- Le battement du camp est celui du socle (Scriptorium.battre, lancé au démarrage) ;
-- ici, on s'assure seulement qu'il tourne.
function poste.battre_les_hommes()
  Scriptorium.lancer_le_battement()
end

-- Patrouille : envoie deux hommes faire la ronde proche.
function poste.essai_patrouille()
  local id, raison = Scriptorium.patrouilles.envoyer({ chemin = "ronde_proche", hommes = 2 })
  jeu().journal("Poste : patrouille = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or ""))
  return id
end

-- Bataille : lève une bande de cinq brigands venant du nord, qui arrive au prochain battement (délai nul :
-- vu le 14/10, une bande à un quart d'heure n'arrivait jamais, l'heure du jeu ne tournant pas dans le prologue).
function poste.essai_bataille()
  local id, raison = Scriptorium.bataille.lever_une_bande({ sorte = "brigands", effectif = 5, direction = 0, delai = 0 })
  jeu().journal("Poste : bande levée = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or "")
                .. ", force des nôtres = " .. Scriptorium.bataille.force_des_notres())
  poste.battre_les_hommes()
  return id
end

-- Fiche 17 : un camp de bandits d'essai, petit, à « distance » mètres devant Henry, sur sa carte ; il naît quand Henry
-- ne regarde plus le lieu.
poste.camps_d_essai = 0
function poste.essai_camp_de_bandits(distance)
  local point = jeu().point_devant_henry(distance)
  local carte = jeu().carte_courante and (jeu().carte_courante()) or nil
  if not point or not carte then
    jeu().journal("Poste : camp de bandits : ni point devant Henry ni carte lisibles")
    return false
  end
  poste.camps_d_essai = poste.camps_d_essai + 1
  local nom = "essai_" .. poste.camps_d_essai
  Scriptorium.missions.ajouter_un_lieu(nom, carte, point, 0)
  local id, raison = Scriptorium.missions.dresser_un_camp(nom, "petit")
  jeu().journal("Poste : camp de bandits = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or ""))
  poste.battre_les_hommes()
  return id
end

-- Les camps de bandits, leur bande, ses ennemis debout.
function poste.essai_camps_de_bandits()
  local camps = Scriptorium.missions.camps()
  for _, c in ipairs(camps) do
    local b = Scriptorium.bataille.bande(c.bande) or {}
    local debout = b.personnages and jeu().ennemis_vivants(b.personnages) or 0
    jeu().journal("Poste : « " .. c.id .. " » à « " .. c.lieu .. " » : " .. c.etat .. ", meublé " .. tostring(c.meubles)
                  .. ", bande " .. tostring(b.etat) .. ", " .. debout .. "/" .. tostring(b.effectif) .. " debout"
                  .. (c.issue and (", issue " .. c.issue) or ""))
  end
  jeu().journal("Poste : " .. #camps .. " camp(s) de bandits")
  return #camps
end

-- Pose Henry à 50 m au sud du premier camp de bandits debout, tourné vers lui.
function poste.essai_vers_le_camp_de_bandits()
  for _, c in ipairs(Scriptorium.missions.camps()) do
    for _, l in ipairs(Scriptorium.missions.lieux_de(c.carte)) do
      if l.nom == c.lieu then
        jeu().journal("Poste : Henry vers « " .. c.id .. " » : "
                      .. tostring(jeu().poser_le_joueur({ x = l.x, y = l.y - 50, z = l.z })))
        return true
      end
    end
  end
  jeu().journal("Poste : aucun camp de bandits debout dont le lieu est connu")
  return false
end

-- Fiche 17, 4 b (la sonde de la colonne) : les trois premiers hommes, à cheval, menés vers le lieu du premier camp de
-- bandits (un point, sans chef : l'ordre 20).
function poste.essai_colonne_vers_le_camp_de_bandits()
  local vers = nil
  for _, c in ipairs(Scriptorium.missions.camps()) do
    for _, l in ipairs(Scriptorium.missions.lieux_de(c.carte)) do
      if not vers and l.nom == c.lieu then vers = { x = l.x, y = l.y, z = l.z } end
    end
  end
  if not vers then
    jeu().journal("Poste : colonne : aucun camp de bandits au lieu connu")
    return false
  end
  local n = 0
  for k, id in ipairs(Scriptorium.hommes.liste()) do
    if k <= 3 then
      local ok, raison = Scriptorium.hommes.tenir(id, "escorte", { activite = "suivre", lieu = "colonne", vers = vers,
        formation = "followNPC", a_cheval = true, fin = "liberation" })
      if ok then n = n + 1 else jeu().journal("Poste : colonne : " .. id .. " refusé (" .. tostring(raison) .. ")") end
    end
  end
  jeu().journal(string.format("Poste : colonne de %d homme(s) vers (%.0f, %.0f)", n, vers.x, vers.y))
  return n > 0
end

-- Fiche 17, 4 b : une mission d'essai des trois premiers hommes (le premier en chef) vers un lieu posé à « distance »
-- mètres devant Henry : à 120 m, Henry voit le combat ; à 450 m, la colonne passe dehors et l'issue se calcule.
function poste.essai_mission(distance)
  local point = jeu().point_devant_henry(distance)
  local carte = jeu().carte_courante and (jeu().carte_courante()) or nil
  if not point or not carte then
    jeu().journal("Poste : mission : ni point devant Henry ni carte lisibles")
    return false
  end
  poste.camps_d_essai = poste.camps_d_essai + 1
  local nom = "essai_" .. poste.camps_d_essai
  Scriptorium.missions.ajouter_un_lieu(nom, carte, point, 0)
  -- Trois hommes libres (pas déjà en mission, ni dehors, ni blessés) : une seconde mission peut suivre la première.
  local hommes = {}
  for _, id in ipairs(Scriptorium.hommes.liste()) do
    local f = Scriptorium.hommes.fiche(id)
    if #hommes < 3 and f.blessure == 0 and not f.dehors and Scriptorium.avis(Scriptorium.hommes, "libre_pour", id, "mission")
        and Scriptorium.bataille.roles[f.role] then
      table.insert(hommes, id)
    end
  end
  local id, raison = Scriptorium.missions.prendre_une_mission({ lieu = nom, hommes = hommes, chef = hommes[1] })
  jeu().journal("Poste : mission = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or ""))
  poste.battre_les_hommes()
  return id
end

-- Les missions en cours, et le rapport des finies.
function poste.essai_missions()
  for _, m in ipairs(Scriptorium.missions.en_cours()) do
    jeu().journal("Poste : « " .. m.id .. " » vers « " .. m.lieu .. " » : " .. m.etat .. ", " .. #m.hommes .. " homme(s)"
                  .. (m.issue and (", issue " .. m.issue) or ""))
  end
  return true
end

-- Fiche 17, tranche 4 : un convoi d'essai sur une route de trois points devant Henry (60 m, 120 m à droite, 200 m) ; il
-- naît quand Henry ne regarde plus son départ.
function poste.essai_convoi()
  local carte = jeu().carte_courante and (jeu().carte_courante()) or nil
  local p1, p3 = jeu().point_devant_henry(60), jeu().point_devant_henry(200)
  local p2 = jeu().point_devant_henry(120)
  if not (carte and p1 and p2 and p3) then
    jeu().journal("Poste : convoi : ni points devant Henry ni carte lisibles")
    return false
  end
  -- Le point du milieu, 40 m sur la droite de la ligne (perpendiculaire au regard).
  local dx, dy = p3.x - p1.x, p3.y - p1.y
  local l = math.sqrt(dx * dx + dy * dy)
  if l > 0 then p2 = { x = p2.x + dy / l * 40, y = p2.y - dx / l * 40, z = p2.z } end
  poste.camps_d_essai = poste.camps_d_essai + 1
  local nom = "route_essai_" .. poste.camps_d_essai
  Scriptorium.missions.ajouter_une_route(nom, carte, { p1, p2, p3 })
  local id, raison = Scriptorium.missions.lancer_un_convoi(nom, "petit")
  jeu().journal("Poste : convoi = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or ""))
  poste.battre_les_hommes()
  return id
end

function poste.essai_convois()
  for _, cv in ipairs(Scriptorium.missions.convois()) do
    local b = Scriptorium.bataille.bande(cv.bande) or {}
    jeu().journal(string.format("Poste : « %s » sur « %s » : %.0f m parcourus, en (%.1f, %.1f), bande %s, %d personnage(s)",
      cv.id, cv.route, cv.parcouru, cv.position.x, cv.position.y, tostring(b.etat), b.personnages and #b.personnages or 0))
  end
  return true
end

function poste.essai_lever_les_camps()
  local n = 0
  for _, c in ipairs(Scriptorium.missions.camps()) do
    if Scriptorium.missions.lever_un_camp(c.id) then n = n + 1 end
  end
  jeu().journal("Poste : " .. n .. " camp(s) de bandits levé(s)")
  return n
end

-- Diagnostic du combat figé (relecture du pair, 17/10) : trois brigands, du nord, au prochain battement.
function poste.essai_bataille_trois()
  local id, raison = Scriptorium.bataille.lever_une_bande({ sorte = "brigands", effectif = 3, direction = 0, delai = 0 })
  jeu().journal("Poste : bande de trois = " .. tostring(id) .. (raison and (" (" .. raison .. ")") or ""))
  poste.battre_les_hommes()
  return id
end

-- Les ennemis dans le jeu de la première bande au contact, et son nom.
local function ennemis_au_contact()
  for _, id in ipairs(Scriptorium.bataille.bandes()) do
    local b = Scriptorium.bataille.bande(id)
    if #b.personnages > 0 then
      return b.personnages, id
    end
  end
  return {}, nil
end

-- Nos hommes présents dans le jeu.
local function nos_personnages()
  local liste = {}
  for _, id in ipairs(Scriptorium.hommes.liste()) do
    local f = Scriptorium.hommes.fiche(id)
    if f and f.personnage then
      table.insert(liste, f.personnage)
    end
  end
  return liste
end

-- Étape 1 de la note de JoVenGer : nos personnages sont-ils connus de l'IA du jeu ? Le premier de nos hommes présents,
-- comparé au personnage du jeu le plus proche d'Henry.
function poste.essai_cerveau()
  local notres = nos_personnages()
  for _, ligne in ipairs(jeu().sonder_les_cerveaux(notres[1])) do
    jeu().journal("Poste : cerveau, " .. ligne)
  end
  return #notres
end

-- Les liens de l'habitant le plus proche (moteur et IA).
function poste.essai_liens()
  for _, ligne in ipairs(jeu().decrire_les_liens()) do
    jeu().journal("Poste : liens, " .. ligne)
  end
  return true
end

-- Cerveau à nous (étape 1) : le marcheur marche vers un point lu dans son cerveau ; un ordre lui donne un autre point.
function poste.essai_marcheur()
  local nom, ligne = jeu().poser_le_marcheur()
  jeu().journal("Poste : marcheur, posé = " .. tostring(nom) .. " ; " .. tostring(ligne))
  return nom ~= nil
end

function poste.essai_marcheur_point()
  jeu().journal("Poste : marcheur, " .. jeu().viser_un_point("droite"))
  return true
end

function poste.essai_marcheur_assis()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_au_marcheur(4))
  return true
end

function poste.essai_marcheur_debout()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_au_marcheur(0))
  return true
end

function poste.essai_marcheur_rejoindre()
  for _, texte in ipairs(jeu().ordonner_de_rejoindre()) do
    jeu().journal("Poste : marcheur, " .. texte)
  end
  return true
end

function poste.essai_marcheur_combat()
  for _, texte in ipairs(jeu().ordonner_le_combat()) do
    jeu().journal("Poste : marcheur, " .. texte)
  end
  return true
end

function poste.essai_marcheur_brigand()
  for _, texte in ipairs(jeu().ordonner_le_combat(true)) do
    jeu().journal("Poste : marcheur, " .. texte)
  end
  return true
end

function poste.essai_marcheur_contre_henry()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_contre_henry())
  return true
end

function poste.essai_brigand_du_jeu()
  jeu().journal("Poste : brigand, " .. jeu().poser_le_brigand_du_jeu())
  return true
end

function poste.essai_brigand_voir()
  jeu().journal("Poste : brigand, " .. jeu().voir_le_brigand_du_jeu())
  return true
end

-- Le marcheur reçoit un coup léger de la part de l'adversaire : riposte-t-il de lui-même (switch du jeu) ?
function poste.essai_coup_recu()
  if not jeu().marcheur or not jeu().adversaire then
    jeu().journal("Poste : coup, il faut d'abord le marcheur et l'adversaire")
    return false
  end
  jeu().journal("Poste : coup, " .. jeu().blesser_de_la_part_de(jeu().marcheur, jeu().adversaire, 5))
  return true
end

function poste.essai_henry_frappe()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_le_brigand(10))
  return true
end

function poste.essai_henry_frappe_habitant()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_un_habitant(10))
  return true
end

function poste.essai_habitant_voir()
  jeu().journal("Poste : habitant, " .. jeu().voir_l_habitant_frappe())
  return true
end

function poste.essai_brigand_naissance()
  jeu().journal("Poste : brigand, naissance annoncée à l'IA : " .. jeu().annoncer_la_naissance())
  return true
end

function poste.essai_marcheur_frappe()
  jeu().journal("Poste : coup, " .. jeu().marcheur_frappe_le_brigand(10))
  return true
end

-- Le coup sans blessure (V44, demande de JoVenGer) : 0 point ; s'il suffit à déclencher le combat, le Directeur pourra le
-- lancer sans que personne ne soit touché par magie.
function poste.essai_marcheur_effleure()
  jeu().journal("Poste : coup, " .. jeu().marcheur_frappe_le_brigand(0))
  return true
end

function poste.essai_henry_effleure()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_le_brigand(0))
  return true
end

function poste.essai_marcheur_attaque()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_l_attaque())
  return true
end

function poste.essai_henry_effleure_marcheur()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_le_marcheur(0))
  return true
end

-- L'adversaire à âme de brigand (notre cerveau), posé seul, sans ordre de combat (V47).
function poste.essai_adversaire_brigand()
  local _, ligne = jeu().poser_l_adversaire(true)
  jeu().journal("Poste : marcheur, " .. tostring(ligne))
  return true
end

function poste.essai_henry_effleure_adversaire()
  jeu().journal("Poste : coup, " .. jeu().henry_frappe_l_adversaire(0))
  return true
end

function poste.essai_garde_du_jeu()
  jeu().journal("Poste : garde, " .. jeu().poser_le_garde_du_jeu())
  return true
end

function poste.essai_garde_voir()
  jeu().journal("Poste : garde, " .. jeu().voir_le_garde_du_jeu())
  return true
end

-- Le marcheur attaque l'adversaire, qui ne se défend pas (V51) : ses coups portent-ils ?
function poste.essai_marcheur_attaque_adversaire()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_l_attaque(jeu().adversaire))
  return true
end

function poste.essai_marcheur_armer()
  jeu().journal("Poste : marcheur, " .. jeu().armer_le_marcheur())
  return true
end

function poste.essai_prairie()
  jeu().journal("Poste : " .. jeu().mener_henry_en_prairie())
  return true
end

function poste.essai_marcheur_competences()
  jeu().journal("Poste : marcheur, " .. jeu().donner_des_competences(jeu().niveau_de_combat_d_essai))
  return true
end

function poste.essai_brigand_leger()
  jeu().journal("Poste : brigand, " .. jeu().poser_le_brigand_du_jeu(jeu().ame_du_brigand_leger))
  return true
end

-- V73 b 1 (fiche 15) : le brigand léger, posé hors du camp, jamais dans un meuble ni sur Henry : sur la ligne qui va du
-- centre du camp à Henry, 10 m au-delà d'Henry (le camp est fondé devant lui : 8 m devant, il naîtrait dans le camp).
function poste.essai_brigand_leger_hors_du_camp()
  local centre = Scriptorium.camp.point(0, 0)
  local henry = jeu().position_du_joueur()
  if not centre or not henry then
    jeu().journal("Poste : brigand, " .. (centre and "Henry introuvable" or "pas de camp"))
    return false
  end
  local dx, dy = henry.x - centre.x, henry.y - centre.y
  local ecart = math.sqrt(dx * dx + dy * dy)
  if ecart < 1 then
    jeu().journal("Poste : brigand, Henry au centre du camp : aucune direction pour sortir du camp")
    return false
  end
  local position = { x = henry.x + dx / ecart * 10, y = henry.y + dy / ecart * 10, z = henry.z }
  jeu().journal("Poste : brigand, " .. jeu().poser_le_brigand_du_jeu(jeu().ame_du_brigand_leger, position))
  return true
end

function poste.essai_marcheur_aller()
  jeu().journal("Poste : marcheur, aller : " .. jeu().ordonner_d_aller("droite"))
  return true
end

function poste.essai_marcheur_voir()
  jeu().journal("Poste : marcheur, " .. jeu().voir_le_marcheur())
  return true
end

-- Réveil (V56) : le marcheur après rechargement, retrouvé par son nom, puis éveillé ; retiré à la fin de l'essai.
function poste.essai_marcheur_retrouver()
  jeu().journal("Poste : marcheur, " .. jeu().retrouver_le_marcheur())
  return true
end

function poste.essai_marcheur_eveiller()
  jeu().journal("Poste : marcheur, " .. jeu().eveiller_le_marcheur())
  return true
end

-- S'asseoir et se coucher (V60) : les sièges et lits du jeu les plus proches, une copie posée près d'Henry, l'ordre au
-- marcheur.
function poste.essai_sieges_sonder()
  for _, ligne in ipairs(jeu().sonder_les_sieges()) do
    jeu().journal("Poste : sièges, " .. ligne)
  end
  return true
end

function poste.essai_sieges_relever()
  for _, ligne in ipairs(jeu().relever_les_sieges()) do
    local debut = 1
    while debut <= #ligne do
      jeu().journal("Poste : relevé, " .. string.sub(ligne, debut, debut + 399))
      debut = debut + 400
    end
  end
  return true
end

function poste.essai_siege_poser()
  jeu().journal("Poste : sièges, " .. jeu().poser_un_siege("siege"))
  return true
end

function poste.essai_lit_poser()
  jeu().journal("Poste : sièges, " .. jeu().poser_un_siege("lit"))
  return true
end

function poste.essai_marcheur_asseoir()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_de_prendre_place("siege", 10))
  return true
end

function poste.essai_marcheur_coucher()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_de_prendre_place("lit", 11))
  return true
end

function poste.essai_marcheur_asseoir_reel()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_de_prendre_place("siege", 10, true))
  return true
end

function poste.essai_marcheur_coucher_reel()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_de_prendre_place("lit", 11, true))
  return true
end

-- Meubles utilisables (V66) : le marcheur s'assoit sur le premier banc du camp, se couche sur le premier lit.
function poste.essai_marcheur_asseoir_camp()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_sur_la_place(Scriptorium.camp.objet_du_jeu_de("siege_1"), 10))
  return true
end

function poste.essai_marcheur_coucher_camp()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_sur_la_place(Scriptorium.camp.objet_du_jeu_de("lit_1a"), 11))
  return true
end

-- V70 (fiche 13) : les hommes du camp, nés sur nos âmes, reçoivent les ordres de notre cerveau. Chacun prend un banc du
-- camp, dans l'ordre du plan (un homme par banc), ou sa paillasse ; le Directeur, son lit. On garde la place donnée à
-- chacun pour voir ensuite où il en est.
local places_donnees = {}

local function donner_les_places(ordre, place_de)
  local hommes = Scriptorium.hommes
  local n = 0
  for _, id in ipairs(hommes.liste()) do
    local f = hommes.fiche(id)
    local place = place_de(f)
    local objet = place and Scriptorium.camp.objet_du_jeu_de(place)
    if f.personnage and objet then
      places_donnees[f.personnage] = objet
      jeu().journal("Poste : " .. f.nom .. " → " .. place .. ", " .. jeu().ordonner_sur_la_place(objet, ordre, f.personnage))
      n = n + 1
    else
      jeu().journal("Poste : " .. f.nom .. " : " .. (f.personnage and ("pas de place (" .. tostring(place) .. ")") or "sans personnage"))
    end
  end
  return n
end

function poste.essai_hommes_asseoir()
  local sieges = {}
  for _, e in ipairs(Scriptorium.camp.plan) do
    if e.sorte == "siege" and Scriptorium.camp.objet_du_jeu_de(e.nom) then
      table.insert(sieges, e.nom)
    end
  end
  local rang = 0
  return donner_les_places(10, function()
    rang = rang + 1
    return sieges[rang]
  end) > 0
end

-- V73 c (fiche 15) : l'homme suivant reçoit l'ordre de marcher vers sa place d'exercice ; un seul à la fois, pour mesurer
-- la levée selon le temps passé assis.
local prochain_leve = 0
function poste.essai_hommes_lever()
  local hommes = Scriptorium.hommes
  local liste = hommes.liste()
  if #liste == 0 then
    return false
  end
  prochain_leve = prochain_leve % #liste + 1
  local id = liste[prochain_leve]
  local f = hommes.fiche(id)
  local a = Scriptorium.avis(hommes, "activite_de", id, 10)
  jeu().journal("Poste : levée de " .. f.nom .. " : " .. tostring(jeu().ordonner(f.personnage, "lever", a and a.position, "exercice")))
  return true
end

-- V73 b 1 (fiche 15) : l'homme suivant attaque le brigand du jeu (ordre 8), sans être déplacé : assis, il doit se lever
-- de lui-même. Il devient le dernier vu.
local prochain_attaquant = 0
function poste.essai_hommes_attaque()
  local hommes = Scriptorium.hommes
  local liste = hommes.liste()
  if #liste == 0 then
    return false
  end
  prochain_attaquant = prochain_attaquant % #liste + 1
  local id = liste[prochain_attaquant]
  local f = hommes.fiche(id)
  if not f.personnage then
    jeu().journal("Poste : attaque de " .. f.nom .. " : sans personnage")
    return false
  end
  poste.dernier_vu = id
  jeu().journal("Poste : attaque de " .. f.nom .. " : " .. jeu().ordonner_l_attaque(nil, f.personnage))
  return true
end

-- V73 b 3 (fiche 15) : l'arbitre en jeu, par des commandes qui jouent le guichet sur le premier homme du camp.
local function premier_du_camp()
  local id = Scriptorium.hommes.liste()[1]
  return id, id and Scriptorium.hommes.fiche(id)
end

local function point_du_camp(nom)
  local p = Scriptorium.hommes.points[nom]
  return p and Scriptorium.camp.point(p.x, p.y, p.cap)
end

-- Une tenue « rassemblement » (rang 2) au point de la corvée, jusqu'à ce qu'elle soit lâchée.
function poste.essai_tenir_rassemblement()
  local id, f = premier_du_camp()
  if not f then
    return false
  end
  local ok, raison = Scriptorium.hommes.tenir(id, "rassemblement", { activite = "rassemblement", lieu = "rassemblement",
    position = point_du_camp("corvee"), fin = "liberation" })
  jeu().journal("Poste : " .. f.nom .. ", tenu par le rassemblement : " .. tostring(ok) .. " " .. tostring(raison or ""))
  return ok == true
end

-- Une tenue « loisir » (rang 7) au coin des dés, pour une heure du jeu : plus faible, elle attend sous le rassemblement.
function poste.essai_tenir_loisir()
  local id, f = premier_du_camp()
  if not f then
    return false
  end
  local ok, raison = Scriptorium.hommes.tenir(id, "loisir", { activite = "des", lieu = "des", position = point_du_camp("des"),
    fin = jeu().heure_du_jeu() + 1 })
  jeu().journal("Poste : " .. f.nom .. ", tenu par le loisir : " .. tostring(ok) .. " " .. tostring(raison or ""))
  return ok == true
end

function poste.essai_lacher_rassemblement()
  local id, f = premier_du_camp()
  if not f then
    return false
  end
  local ok = Scriptorium.hommes.lacher(id, "rassemblement")
  jeu().journal("Poste : " .. f.nom .. ", rassemblement lâché : " .. tostring(ok))
  return ok == true
end

-- Fiche 15, V73 d 1 : le premier homme tenu par la garde au poste 1 du socle (son point et son cap), jusqu'à libération :
-- il y marche, se tourne vers le dehors et s'y tient.
function poste.essai_tenir_garde()
  local id, f = premier_du_camp()
  if not f then
    return false
  end
  local p = Scriptorium.hommes.postes_de_garde[1]
  local position, cap = Scriptorium.camp.point(p.x, p.y, p.cap)
  local ok, raison = Scriptorium.hommes.tenir(id, "garde", { activite = "garde", lieu = "poste_1", position = position,
    cap = cap, fin = "liberation" })
  jeu().journal("Poste : " .. f.nom .. ", tenu par la garde au poste 1 : " .. tostring(ok) .. " " .. tostring(raison or ""))
  return ok == true
end

function poste.essai_lacher_garde()
  local id, f = premier_du_camp()
  if not f then
    return false
  end
  local ok = Scriptorium.hommes.lacher(id, "garde")
  jeu().journal("Poste : " .. f.nom .. ", garde lâchée : " .. tostring(ok))
  return ok == true
end

-- Fiche 15, V73 d 2 : les deux premiers hommes du camp sur la ronde d'essai « pourtour », partis de deux points opposés
-- (Scriptorium espace ses gardes en donnant le départ, réponse 2 a de JoVenGer), jusqu'à libération.
function poste.essai_tenir_ronde()
  local r = Scriptorium.hommes.rondes.pourtour
  local n = r.nombre_de_points
  local chemin = {}
  for i = 1, n do
    local cap = (i - 1) * 360 / n
    chemin[i] = Scriptorium.camp.point(r.rayon_m * math.sin(math.rad(cap)), r.rayon_m * math.cos(math.rad(cap)), 0)
    if not chemin[i] then
      jeu().journal("Poste : ronde d'essai sans camp")
      return false
    end
  end
  local ids, tenus = Scriptorium.hommes.liste(), 0
  for k = 1, math.min(2, #ids) do
    local f = Scriptorium.hommes.fiche(ids[k])
    local depart = (k - 1) * math.floor(n / 2) + 1
    local ok, raison = Scriptorium.hommes.tenir(ids[k], "ronde", { activite = "ronde", lieu = "pourtour", chemin = chemin,
      depart = depart, fin = "liberation" })
    jeu().journal("Poste : " .. f.nom .. ", tenu par la ronde « pourtour », départ au point " .. depart .. " : "
      .. tostring(ok) .. " " .. tostring(raison or ""))
    if ok then
      tenus = tenus + 1
    end
  end
  return tenus > 0
end

-- Fiche 15, V73 d 2 bis : l'accroche « ronde reprise » d'essai, qui rend le point opposé au plus proche ; posée une
-- seule fois chez les hommes, active ou non selon la commande.
poste.accroche_de_ronde_active = false

function poste.accroche_de_ronde(id, quoi)
  if not poste.accroche_de_ronde_active then
    return nil
  end
  local point = (quoi.plus_proche + math.floor(quoi.points / 2) - 1) % quoi.points + 1
  local f = Scriptorium.hommes.fiche(id)
  jeu().journal("Poste : accroche d'essai, « " .. tostring(f and f.nom) .. " » : " .. tostring(quoi.raison)
    .. ", plus proche " .. tostring(quoi.plus_proche) .. ", visé avant " .. tostring(quoi.precedent) .. " → point "
    .. point)
  return point
end

function poste.essai_ronde_accroche(active)
  local posee = false
  for _, fonction in ipairs(Scriptorium.hommes.accroches.ronde_reprise or {}) do
    if fonction == poste.accroche_de_ronde then
      posee = true
    end
  end
  if not posee then
    posee = Scriptorium.hommes.accrocher("ronde_reprise", poste.accroche_de_ronde) == true
  end
  poste.accroche_de_ronde_active = active == true
  jeu().journal("Poste : accroche d'essai de la ronde " .. (poste.accroche_de_ronde_active and "active" or "inactive"))
  return posee
end

-- Les deux premiers hommes tenus par un rassemblement (rang 2) au point de la corvée, puis lâchés : leur ronde reprend.
function poste.essai_rassembler_rondiers(tenir)
  local ids, faits = Scriptorium.hommes.liste(), 0
  local position = point_du_camp("corvee")
  for k = 1, math.min(2, #ids) do
    local ok
    if tenir then
      ok = Scriptorium.hommes.tenir(ids[k], "rassemblement", { activite = "rassemblement", lieu = "corvee",
        position = position, fin = "liberation" })
    else
      ok = Scriptorium.hommes.lacher(ids[k], "rassemblement")
    end
    if ok then
      faits = faits + 1
    end
  end
  jeu().journal("Poste : rassemblement des rondiers " .. (tenir and "posé" or "lâché") .. " pour " .. faits .. " homme(s)")
  return faits > 0
end

-- Le second homme sur la même ronde d'essai, sans pause (V73 d 2 bis) : la tenue change, l'ordre en cours reste ; le
-- pas suivant n'a plus de pause.
function poste.essai_ronde_sans_pause()
  local ids = Scriptorium.hommes.liste()
  local f = ids[2] and Scriptorium.hommes.fiche(ids[2])
  local tenue = f and f.tenues and f.tenues.ronde
  if not tenue then
    jeu().journal("Poste : pas de second rondier")
    return false
  end
  local ok, raison = Scriptorium.hommes.tenir(ids[2], "ronde", { activite = "ronde", lieu = tenue.lieu,
    chemin = tenue.chemin, depart = tenue.depart, pauses = false, fin = tenue.fin })
  jeu().journal("Poste : " .. f.nom .. ", ronde sans pause : " .. tostring(ok) .. " " .. tostring(raison or ""))
  return ok == true
end

-- Fiche 15, V73 e : le briefing d'essai. Chaque appel convoque l'homme suivant (pas encore tenu par le briefing) autour
-- du centre d'essai, en courant, face au centre ; les places se recalculent à chaque convocation.
function poste.essai_briefing()
  local p = Scriptorium.hommes.points.briefing
  local centre, cap = Scriptorium.camp.point(p.x, p.y, p.cap)
  if not centre then
    jeu().journal("Poste : briefing d'essai sans camp")
    return false
  end
  for _, id in ipairs(Scriptorium.hommes.liste()) do
    local f = Scriptorium.hommes.fiche(id)
    if not (f.tenues and f.tenues.rassemblement) then
      local ok, raison = Scriptorium.hommes.tenir(id, "rassemblement", { activite = "rassemblement", lieu = "briefing",
        centre = centre, cap = cap, fin = "liberation" })
      jeu().journal("Poste : " .. f.nom .. " convoqué au briefing : " .. tostring(ok) .. " " .. tostring(raison or ""))
      return ok == true
    end
  end
  jeu().journal("Poste : tous sont déjà convoqués")
  return false
end

-- « Rompez ! » : le rassemblement lâché pour tous ceux qu'il tenait.
function poste.essai_rompre()
  local n = 0
  for _, id in ipairs(Scriptorium.hommes.liste()) do
    local f = Scriptorium.hommes.fiche(id)
    local tenu = f and f.tenues and f.tenues.rassemblement ~= nil
    if Scriptorium.hommes.lacher(id, "rassemblement") and tenu then
      n = n + 1
    end
  end
  jeu().journal("Poste : rompez, " .. n .. " homme(s)")
  return n > 0
end

-- Fiche 15, V73 f 1 : l'escorte d'essai : le Directeur suit Henry, en tête ; les trois premiers hommes en colonne
-- derrière lui.
function poste.essai_escorte()
  local ok_d, raison_d = Scriptorium.directeur.suivre(true)
  jeu().journal("Poste : le Directeur suit Henry : " .. tostring(ok_d) .. " " .. tostring(raison_d or ""))
  local n = 0
  for k, id in ipairs(Scriptorium.hommes.liste()) do
    if k <= 3 then
      local ok = Scriptorium.hommes.tenir(id, "escorte", { activite = "suivre", lieu = "escorte",
        chef = ok_d and "directeur" or "henry", fin = "liberation" })
      if ok then
        n = n + 1
      end
    end
  end
  jeu().journal("Poste : escorte de " .. n .. " homme(s) derrière " .. (ok_d and "le Directeur" or "Henry"))
  return n > 0 or ok_d == true
end

-- Fiche 15, V73 f 1 bis : l'escorte d'essai en formation du moteur : le Directeur mène « followNPC », les trois premiers
-- hommes s'y rangent.
function poste.essai_escorte_formation()
  local ok_d, raison_d = Scriptorium.directeur.suivre(true, "followNPC")
  jeu().journal("Poste : le Directeur mène la formation : " .. tostring(ok_d) .. " " .. tostring(raison_d or ""))
  local n = 0
  for k, id in ipairs(Scriptorium.hommes.liste()) do
    if k <= 3 then
      local ok = Scriptorium.hommes.tenir(id, "escorte", { activite = "suivre", lieu = "escorte",
        chef = ok_d and "directeur" or "henry", formation = "followNPC", fin = "liberation" })
      if ok then
        n = n + 1
      end
    end
  end
  jeu().journal("Poste : escorte en formation de " .. n .. " homme(s)")
  return n > 0 or ok_d == true
end

-- Fiche 15, V73 f 2 a (la sonde à cheval) : un cheval né à 5 m du premier homme (angle au hasard) ; le premier homme suit Henry en selle ;
-- le cheval retiré.
poste.cheval_d_essai = nil

function poste.essai_cheval()
  local id, f = premier_du_camp()
  local ici = f and f.personnage and jeu().position_du_personnage(f.personnage)
  if not ici then
    jeu().journal("Poste : pas d'homme pour le cheval d'essai")
    return false
  end
  -- Relecture du pair (V73 f 2 a) : à 5 m, sous un angle tiré au hasard ; un cheval né derrière une barrière se retire
  -- (essai_retirer_cheval) et la commande redonnée tire un autre angle.
  poste.hasard_du_cheval = poste.hasard_du_cheval or Scriptorium.hasard_depuis(5171)
  local angle = Scriptorium.tirer(poste.hasard_du_cheval) * 2 * math.pi
  poste.cheval_d_essai = jeu().faire_venir_cheval("essai", { x = ici.x + 5 * math.cos(angle), y = ici.y + 5 * math.sin(angle), z = ici.z })
  jeu().journal("Poste : cheval d'essai = " .. tostring(poste.cheval_d_essai))
  return poste.cheval_d_essai ~= nil
end

function poste.essai_escorte_a_cheval()
  local id, f = premier_du_camp()
  if not f or not poste.cheval_d_essai then
    jeu().journal("Poste : pas d'homme ou pas de cheval d'essai")
    return false
  end
  local ok, raison = Scriptorium.hommes.tenir(id, "escorte", { activite = "suivre", lieu = "cavaliers",
    cheval = poste.cheval_d_essai, fin = "liberation" })
  jeu().journal("Poste : " .. f.nom .. " suit Henry à cheval : " .. tostring(ok) .. " " .. tostring(raison or ""))
  return ok == true
end

function poste.essai_retirer_cheval()
  if not poste.cheval_d_essai then
    return false
  end
  jeu().retirer_cheval(poste.cheval_d_essai)
  jeu().journal("Poste : cheval d'essai retiré")
  poste.cheval_d_essai = nil
  return true
end

-- Fiche 15, V73 f 2 b (la troupe à cheval) : les trois premiers hommes suivent Henry à cheval, en formation followNPC
-- (le premier mène) ; chacun reçoit son cheval passager.
function poste.essai_troupe_a_cheval()
  local n = 0
  for k, id in ipairs(Scriptorium.hommes.liste()) do
    if k <= 3 then
      local ok = Scriptorium.hommes.tenir(id, "escorte", { activite = "suivre", lieu = "cavaliers", formation = "followNPC",
        a_cheval = true, fin = "liberation" })
      if ok then
        n = n + 1
      end
    end
  end
  jeu().journal("Poste : troupe à cheval de " .. n .. " homme(s)")
  return n > 0
end

-- Fiche 15, V73 f 2 d : l'escorte qui monte quand Henry monte ; la lecture d'Henry forcée ou rendue au jeu ; son
-- cheval amené devant lui pour la séance.
function poste.essai_escorte_comme_henry()
  local n = 0
  for k, id in ipairs(Scriptorium.hommes.liste()) do
    if k <= 3 then
      local ok = Scriptorium.hommes.tenir(id, "escorte", { activite = "suivre", lieu = "cavaliers", formation = "followNPC",
        a_cheval = "comme_henry", fin = "liberation" })
      if ok then
        n = n + 1
      end
    end
  end
  jeu().journal("Poste : escorte « comme Henry » de " .. n .. " homme(s)")
  return n > 0
end

local function forcer_henry(valeur, quoi)
  Scriptorium.hommes.henry_force = valeur
  local lu = Scriptorium.hommes.veiller_henry()
  jeu().journal("Poste : lecture d'Henry " .. quoi .. " ; lue " .. tostring(lu) .. ", retenu monté "
                .. tostring(Scriptorium.hommes.henry_monte))
  return true
end

function poste.essai_henry_a_cheval() return forcer_henry(true, "forcée à cheval") end
function poste.essai_henry_a_pied() return forcer_henry(false, "forcée à pied") end
function poste.essai_henry_lu() return forcer_henry(nil, "rendue au jeu") end

function poste.essai_cheval_d_henry()
  local ok, ligne = jeu().amener_le_cheval_d_henry(4)
  jeu().journal("Poste : " .. tostring(ligne))
  return ok == true
end

-- Fiche 15, V73 f 2 e : le Directeur suit Henry « comme Henry » en menant la formation followNPC ; les trois premiers
-- hommes « comme Henry » derrière Henry (ils se rangent dans sa formation : il reprend la tête).
function poste.essai_directeur_a_cheval()
  local ok_d, raison_d = Scriptorium.directeur.suivre(true, "followNPC", "comme_henry")
  jeu().journal("Poste : le Directeur suit Henry comme Henry : " .. tostring(ok_d) .. " " .. tostring(raison_d or ""))
  local n = 0
  for k, id in ipairs(Scriptorium.hommes.liste()) do
    if k <= 3 then
      local ok = Scriptorium.hommes.tenir(id, "escorte", { activite = "suivre", lieu = "cavaliers", formation = "followNPC",
        a_cheval = "comme_henry", fin = "liberation" })
      if ok then
        n = n + 1
      end
    end
  end
  jeu().journal("Poste : escorte « comme Henry » de " .. n .. " homme(s) derrière le Directeur")
  return ok_d == true
end

-- Fiche 15, V73 f 3 a (la sonde de la carte) : la carte lue, et le dernier événement de chargement vu.
function poste.essai_carte_voir()
  local carte, source = jeu().carte_courante()
  local dernier = jeu().dernier_chargement
  jeu().journal("Poste : carte " .. tostring(carte) .. " (" .. tostring(source) .. ") ; dernier chargement : "
                .. (dernier and (tostring(dernier.evenement) .. " (" .. tostring(dernier.arguments) .. "), sauvegarde = "
                    .. tostring(dernier.sauvegarde)) or "aucun"))
  return carte ~= nil
end

function poste.essai_fin_escorte()
  local n = 0
  for _, id in ipairs(Scriptorium.hommes.liste()) do
    local f = Scriptorium.hommes.fiche(id)
    local tenu = f and f.tenues and f.tenues.escorte ~= nil
    if Scriptorium.hommes.lacher(id, "escorte") and tenu then
      n = n + 1
    end
  end
  local ok_d = Scriptorium.directeur.suivre(false)
  jeu().journal("Poste : fin de l'escorte, " .. n .. " homme(s), Directeur " .. tostring(ok_d))
  return n > 0 or ok_d == true
end

function poste.essai_lacher_ronde()
  -- Seuls comptent les hommes qui étaient tenus par la ronde (lâcher une tenue absente rend vrai aussi).
  local lache = 0
  for _, id in ipairs(Scriptorium.hommes.liste()) do
    local f = Scriptorium.hommes.fiche(id)
    local tenu = f and f.tenues and f.tenues.ronde ~= nil
    if Scriptorium.hommes.lacher(id, "ronde") and tenu then
      lache = lache + 1
    end
  end
  jeu().journal("Poste : ronde lâchée pour " .. lache .. " homme(s)")
  return lache > 0
end

-- Qui tient chaque homme : la règle, l'activité, le lieu, la fin.
function poste.essai_qui_tient()
  local hommes = Scriptorium.hommes
  for _, id in ipairs(hommes.liste()) do
    local f = hommes.fiche(id)
    local regle, a = hommes.qui_tient(id)
    jeu().journal("Poste : " .. f.nom .. " tenu par « " .. tostring(regle) .. " » : " .. tostring(a and a.activite) .. " ("
      .. tostring(a and a.lieu) .. "), fin " .. ((a and type(a.fin) == "number") and string.format("%.2f", a.fin)
      or tostring(a and a.fin)))
  end
  return true
end

function poste.essai_hommes_coucher()
  return donner_les_places(11, function(f) return f.lit end) > 0
end

function poste.essai_directeur_coucher()
  local personnage = Scriptorium.directeur.personnage()
  local objet = Scriptorium.camp.objet_du_jeu_de("lit_directeur")
  if not personnage or not objet then
    jeu().journal("Poste : Directeur : " .. (personnage and "pas de lit" or "sans personnage"))
    return false
  end
  places_donnees[personnage] = objet
  jeu().journal("Poste : Directeur → lit_directeur, " .. jeu().ordonner_sur_la_place(objet, 11, personnage))
  return true
end

function poste.essai_hommes_voir()
  local hommes = Scriptorium.hommes
  for _, id in ipairs(hommes.liste()) do
    local f = hommes.fiche(id)
    if f.personnage then
      jeu().journal("Poste : " .. f.nom .. " (" .. tostring(f.role) .. ", palier " .. tostring(f.palier) .. ") "
                    .. jeu().voir_sur_la_place(f.personnage, places_donnees[f.personnage]))
    else
      jeu().journal("Poste : " .. f.nom .. " : sans personnage")
    end
  end
  local personnage = Scriptorium.directeur.personnage()
  if personnage then
    jeu().journal("Poste : Directeur " .. jeu().voir_sur_la_place(personnage, places_donnees[personnage]))
  end
  -- V73 f 2 d : Henry à cheval, lu et retenu.
  jeu().journal("Poste : Henry à cheval : lu " .. tostring(hommes.henry_lu) .. ", retenu monté " .. tostring(hommes.henry_monte)
                .. ", lectures à pied " .. tostring(hommes.henry_pied_lectures) .. ", forcé " .. tostring(hommes.henry_force))
  return true
end

-- V71 a (fiche 13) : la sonde d'équipement, sur le premier homme du camp.
local function premier_homme()
  local liste = Scriptorium.hommes.liste()
  local f = liste[1] and Scriptorium.hommes.fiche(liste[1])
  return f and f.personnage, f and f.nom
end

function poste.essai_inventaire_sonder()
  local qui, nom = premier_homme()
  for _, ligne in ipairs(jeu().sonder_l_inventaire(qui)) do
    jeu().journal("Poste : " .. tostring(nom) .. ", " .. ligne)
  end
  return qui ~= nil
end

function poste.essai_equipement_compter()
  local qui, nom = premier_homme()
  jeu().journal("Poste : " .. tostring(nom) .. ", " .. jeu().compter_l_equipement(qui))
  return qui ~= nil
end

local function equiper_la_sonde(quoi)
  local qui, nom = premier_homme()
  jeu().journal("Poste : " .. tostring(nom) .. ", " .. jeu().equiper_la_sonde(qui, quoi))
  return qui ~= nil
end

-- V71 b (fiche 13) : l'équipement pièce par pièce, vu en jeu.
function poste.essai_equipement_voir()
  local hommes = Scriptorium.hommes
  for _, id in ipairs(hommes.liste()) do
    local f = hommes.fiche(id)
    local e = f.equipement or {}
    local porte = hommes.ce_qu_il_porte(id)
    local presents, manquants = 0, {}
    for _, objet in ipairs(porte) do
      if f.personnage and jeu().compter_objet(f.personnage, objet) > 0 then
        presents = presents + 1
      else
        table.insert(manquants, objet)
      end
    end
    if #manquants > 0 then
      jeu().journal("Poste : " .. f.nom .. ", pièces manquantes : " .. table.concat(manquants, ", "))
    end
    local munition = e.armes and jeu().munition_de(e.armes)
    jeu().journal(string.format("Poste : %s (%s, palier %s, famille %s) : %s, %s, %s ; %d pièce(s) à porter, %d dans son sac%s",
      f.nom, f.role, tostring(f.palier), tostring(f.famille), tostring(e.tenue), tostring(e.armes), tostring(e.etat), #porte,
      presents, munition and (", munitions " .. jeu().compter_objet(f.personnage, munition) .. "/" .. tostring(e.munitions)) or ""))
  end
  return true
end

-- V71 c : les quatre à voir (un homme d'armes, un arbalétrier pour ses carreaux, le pavoisier et l'homme d'armes
-- d'hast du palier 3, réponses 2 et 3 de JoVenGer), dans les quatre paillasses du camp.
function poste.essai_equipement_embaucher()
  local hommes = Scriptorium.hommes
  local ids = {}
  for _, contrat in ipairs({
    { role = "homme_d_armes", semaines = 4, palier = 1, famille = "epee_bouclier" },
    { role = "arbaletrier", semaines = 4, palier = 1 },
    { role = "pavoisier", semaines = 4, palier = 3 },
    { role = "homme_d_armes", semaines = 4, palier = 3, famille = "arme_d_hast" },
  }) do
    local id, raison = hommes.embaucher(contrat)
    table.insert(ids, tostring(id or raison))
  end
  jeu().journal("Poste : équipement, engagés = " .. table.concat(ids, ", "))
  poste.battre_les_hommes()
  return true
end

-- L'homme posé devant Henry (le dernier vu) sort son arme.
function poste.essai_equipement_degainer()
  local hommes = Scriptorium.hommes
  local f = poste.dernier_vu and hommes.fiche(poste.dernier_vu)
  if not f then
    return false
  end
  jeu().journal("Poste : " .. f.nom .. ", " .. jeu().degainer(f.personnage))
  return true
end

-- V71 d : l'homme posé devant Henry (le dernier vu) attaque le brigand du jeu (ordre 8, comme le marcheur en V54) :
-- son cerveau de combat choisit ce qu'il prend en main (pavois, arme d'hast).
function poste.essai_equipement_combat()
  local hommes = Scriptorium.hommes
  local f = poste.dernier_vu and hommes.fiche(poste.dernier_vu)
  if not f then
    return false
  end
  jeu().journal("Poste : " .. f.nom .. ", " .. jeu().ordonner_l_attaque(nil, f.personnage))
  return true
end

-- La bascule (V71 b) : refaire porter au premier homme toutes ses pièces sans les ôter d'abord.
function poste.essai_equipement_reporter_sans_oter()
  local hommes = Scriptorium.hommes
  local id = hommes.liste()[1]
  local f = id and hommes.fiche(id)
  if not f then
    return false
  end
  local portes, introuvables = jeu().faire_porter(f.personnage, hommes.ce_qu_il_porte(id))
  jeu().journal("Poste : " .. f.nom .. ", refait porter sans ôter : " .. tostring(portes) .. " ; " .. #introuvables .. " refusée(s)")
  return true
end

function poste.essai_equipement_monter()
  local hommes = Scriptorium.hommes
  local id = hommes.liste()[1]
  local f = id and hommes.fiche(id)
  if not f then
    return false
  end
  local ok, raison = hommes.changer_de_palier(id, math.min((f.palier or 1) + 1, 3))
  jeu().journal("Poste : " .. f.nom .. " change de palier : " .. tostring(ok) .. " " .. tostring(raison or ""))
  return ok
end

function poste.essai_equipement_donner()
  local hommes = Scriptorium.hommes
  local id = hommes.liste()[1]
  local piece = (jeu().pieces_de("soldier_generic_6_01") or {})[1]
  local ok, raison = hommes.donner_une_piece(id, piece, 0.5, true)
  jeu().journal("Poste : pièce " .. tostring(piece) .. " donnée à " .. tostring(id) .. " : " .. tostring(ok) .. " " .. tostring(raison or ""))
  return ok
end

local prochain_vu = 0
function poste.essai_equipement_ici_suivant()
  local hommes = Scriptorium.hommes
  local liste = hommes.liste()
  if #liste == 0 then
    return false
  end
  prochain_vu = prochain_vu % #liste + 1
  poste.dernier_vu = liste[prochain_vu]
  local f = hommes.fiche(liste[prochain_vu])
  jeu().journal("Poste : " .. f.nom .. " (" .. f.role .. ", palier " .. tostring(f.palier) .. "), "
    .. jeu().poser_devant_henry(f.personnage))
  return true
end

-- V72 (fiche 14) : la Compagnie. Pour chaque homme et le Directeur : sa faction, sa distance à Henry, ses munitions
-- (point 1 du pair : les flèches avant et après un tir) et ses contextes de crime (conseil du pair).
local CONTEXTES_DE_CRIME = { "crime_isCivilian", "crime_isSecurity", "crime_isAuthority", "crime_interrupt",
                             "crime_interruptAttack", "crime_skipInformationBroadcast" }

local function contextes_en_ligne(qui)
  local lus = jeu().contextes_de(qui, CONTEXTES_DE_CRIME)
  local morceaux = {}
  for _, nom in ipairs(CONTEXTES_DE_CRIME) do
    local valeur = lus[nom]
    table.insert(morceaux, (string.gsub(nom, "^crime_", "")) .. "=" .. (valeur == nil and "?" or (valeur and "1" or "0")))
  end
  return table.concat(morceaux, " ")
end

function poste.essai_compagnie_voir()
  local hommes = Scriptorium.hommes
  for _, id in ipairs(hommes.liste()) do
    local f = hommes.fiche(id)
    local e = f.equipement or {}
    local munition = e.armes and jeu().munition_de(e.armes)
    local ici = f.personnage and jeu().distance_a_henry(f.personnage)
    jeu().journal(string.format("Poste : %s (%s) : faction %s, à %s m d'Henry (%s)%s ; %s", f.nom, f.role,
      tostring(f.personnage and jeu().faction_de(f.personnage)), ici and string.format("%.1f", ici) or "?",
      tostring(f.personnage and jeu().position_de(f.personnage)),
      munition and (", " .. munition .. " " .. jeu().compter_objet(f.personnage, munition)) or "",
      f.personnage and contextes_en_ligne(f.personnage) or "absent"))
  end
  local directeur = Scriptorium.directeur.personnage()
  if directeur then
    jeu().journal("Poste : le Directeur : faction " .. tostring(jeu().faction_de(directeur)) .. " (" .. tostring(jeu().position_de(directeur))
      .. ") ; " .. contextes_en_ligne(directeur))
  end
  -- V72 b : la cible de l'archer et l'habitant frappé, s'ils sont là.
  for _, autre in ipairs({ { "cible de l'archer", jeu().cible_de_l_archer }, { "habitant frappé", jeu().habitant_frappe } }) do
    if autre[2] then
      local ici = jeu().distance_a_henry(autre[2])
      jeu().journal(string.format("Poste : %s « %s » : santé %s, à %s m d'Henry (%s), faction %s", autre[1], autre[2],
        tostring(jeu().sante_de(autre[2])), ici and string.format("%.1f", ici) or "?", tostring(jeu().position_de(autre[2])),
        tostring(jeu().faction_de(autre[2]))))
    end
  end
  return true
end

-- Un archer du palier 1 (homme d'après la Compagnie), qui devient le dernier vu (pour l'ordre d'attaque).
function poste.essai_compagnie_embaucher()
  local id, raison = Scriptorium.hommes.embaucher({ role = "archer", semaines = 4, palier = 1 })
  jeu().journal("Poste : la Compagnie, archer engagé : " .. tostring(id or raison))
  poste.dernier_vu = id or poste.dernier_vu
  poste.battre_les_hommes()
  return id ~= nil
end

-- Le dernier archer engagé, posé à 3 m devant Henry ; il devient le dernier vu.
function poste.essai_compagnie_archer_ici()
  local hommes = Scriptorium.hommes
  local archer = nil
  for _, id in ipairs(hommes.liste()) do
    if hommes.fiche(id).role == "archer" then
      archer = id
    end
  end
  if not archer then
    return false
  end
  poste.dernier_vu = archer
  local f = hommes.fiche(archer)
  jeu().journal("Poste : " .. f.nom .. " (archer), " .. jeu().poser_devant_henry(f.personnage))
  return true
end

-- Le délit d'Henry (réponse 4 a de JoVenGer) : les deux premiers hommes du camp en témoins, à 2 m devant Henry et 3 m
-- de part et d'autre, tournés vers la place de la victime, à 1,5 m devant Henry.
function poste.essai_compagnie_temoins()
  local hommes = Scriptorium.hommes
  local liste = hommes.liste()
  local vers = jeu().point_devant_henry(1.5)
  if #liste < 2 or not vers then
    return false
  end
  for rang, cote in ipairs({ -3, 3 }) do
    local f = hommes.fiche(liste[rang])
    jeu().journal("Poste : témoin " .. f.nom .. ", " .. jeu().poser_pres_d_henry(f.personnage, 2, cote, vers))
  end
  return true
end

-- V72 b : le vrai habitant le plus proche (pas un figurant), posé à 1,5 m devant Henry et frappé dans le même appel,
-- par les règles du jeu, 5 points (réponses de JoVenGer du 16/10).
function poste.essai_compagnie_frapper()
  jeu().journal("Poste : coup, " .. jeu().frapper_un_vrai_habitant(1.5, 5))
  return true
end

-- V72 c (fiche 14) : l'écran noir. Ce qui entoure Henry dans 15 m, puis le relevé de la Compagnie (cible comprise).
function poste.essai_ecran_noir_voir()
  jeu().retrouver_la_cible()
  for _, ligne in ipairs(jeu().voisins_d_henry(15, 40)) do
    jeu().journal("Poste : autour d'Henry, " .. ligne)
  end
  return poste.essai_compagnie_voir()
end

-- Un seul changement : la cible retirée.
function poste.essai_ecran_noir_retirer_la_cible()
  jeu().retrouver_la_cible()
  jeu().journal("Poste : écran noir, " .. jeu().retirer_la_cible())
  return true
end

-- Un seul changement : le dernier archer posé à 4 m derrière Henry.
function poste.essai_ecran_noir_archer_derriere()
  local hommes = Scriptorium.hommes
  local archer = nil
  for _, id in ipairs(hommes.liste()) do
    if hommes.fiche(id).role == "archer" then
      archer = id
    end
  end
  if not archer then
    return false
  end
  local f = hommes.fiche(archer)
  jeu().journal("Poste : écran noir, " .. f.nom .. " " .. jeu().poser_pres_d_henry(f.personnage, -4, 0))
  return true
end

-- V72 b : qui serait frappé (le vrai habitant le plus proche), sans le toucher.
function poste.essai_compagnie_qui()
  jeu().journal("Poste : victime possible, " .. jeu().qui_serait_frappe())
  return true
end

-- V72 b : la cible de l'archer, née à 12 m devant Henry (place regardée libre avant l'ordre).
function poste.essai_compagnie_cible()
  jeu().journal("Poste : " .. jeu().poser_la_cible_de_l_archer(12))
  return jeu().cible_de_l_archer ~= nil
end

-- V72 b : le dernier archer engagé attaque la cible (ordre 8) ; ses flèches sont comptées par compagnie_voir.
function poste.essai_compagnie_archer_tire()
  local hommes = Scriptorium.hommes
  local archer = nil
  for _, id in ipairs(hommes.liste()) do
    if hommes.fiche(id).role == "archer" then
      archer = id
    end
  end
  if not archer or not jeu().cible_de_l_archer then
    return false
  end
  poste.dernier_vu = archer
  local f = hommes.fiche(archer)
  jeu().journal("Poste : " .. f.nom .. ", " .. jeu().ordonner_l_attaque(jeu().cible_de_l_archer, f.personnage))
  return true
end

-- V71 a2 (fiche 13) : le témoin (premier homme) et les deux sondes nées à côté de lui.
local function les_trois()
  local qui, nom = premier_homme()
  local n = jeu().noms_de_la_sonde or {}
  return { { qui, "témoin " .. tostring(nom) }, { n.seule, "sonde seule" }, { n.hors_regles, "sonde hors règles" } }
end

function poste.essai_sonde_naitre()
  local qui = premier_homme()
  for _, ligne in ipairs(jeu().faire_naitre_la_sonde(qui)) do
    jeu().journal("Poste : sonde, " .. ligne)
  end
  return qui ~= nil
end

function poste.essai_sonde_equiper()
  for _, t in ipairs(les_trois()) do
    jeu().journal("Poste : " .. t[2] .. ", " .. jeu().equiper_la_sonde(t[1], "tenue_2"))
    jeu().journal("Poste : " .. t[2] .. ", " .. jeu().equiper_la_sonde(t[1], "armes"))
  end
  return true
end

function poste.essai_sonde_compter()
  for _, t in ipairs(les_trois()) do
    jeu().journal("Poste : " .. t[2] .. ", " .. jeu().compter_l_equipement(t[1]))
  end
  return true
end

function poste.essai_sonde_objets()
  local qui, nom = premier_homme()
  for _, ligne in ipairs(jeu().sonder_les_objets(qui)) do
    jeu().journal("Poste : " .. tostring(nom) .. ", " .. ligne)
  end
  return qui ~= nil
end

-- V71 a3 (fiche 13) : objet par objet sur le premier homme, et un habitant du jeu habillé par le préréglage.
function poste.essai_objets_creer()
  local qui, nom = premier_homme()
  for _, ligne in ipairs(jeu().creer_les_objets_de_la_sonde(qui)) do
    jeu().journal("Poste : " .. tostring(nom) .. ", " .. ligne)
  end
  jeu().journal("Poste : habitant, " .. jeu().habiller_un_habitant())
  return qui ~= nil
end

function poste.essai_objets_relire()
  local qui, nom = premier_homme()
  for _, ligne in ipairs(jeu().relire_les_objets_de_la_sonde(qui)) do
    jeu().journal("Poste : " .. tostring(nom) .. ", " .. ligne)
  end
  jeu().journal("Poste : habitant, " .. jeu().compter_l_habitant())
  return qui ~= nil
end

-- V71 a4 (fiche 13) : le témoin armé pièce par pièce, vu de près, après un puis deux rechargements.
local function sur_le_temoin(action)
  local qui, nom = premier_homme()
  jeu().journal("Poste : témoin " .. tostring(nom) .. ", " .. action(qui))
  return qui ~= nil
end

function poste.essai_temoin_armer() return sur_le_temoin(jeu().armer_le_temoin) end
function poste.essai_temoin_ici() return sur_le_temoin(jeu().poser_devant_henry) end
function poste.essai_temoin_voir() return sur_le_temoin(jeu().voir_le_temoin) end
function poste.essai_temoin_reporter()
  return sur_le_temoin(function(qui)
    local portes, notres = jeu().faire_porter_la_sonde(qui)
    return string.format("%d pièce(s) refaite(s) porter sur %d ; %s", portes, notres, jeu().voir_le_temoin(qui))
  end)
end

-- V71 a5 (fiche 13) : nos pièces reconnues par identifiant, la tenue de naissance retirée.
function poste.essai_pieces_creer() return sur_le_temoin(jeu().creer_les_pieces_notees) end
function poste.essai_pieces_voir() return sur_le_temoin(jeu().voir_les_pieces_notees) end
function poste.essai_pieces_ranger() return sur_le_temoin(jeu().ranger_les_pieces_notees) end

-- V71 a6 (fiche 13) : la tenue de naissance reconnue par sa signature.
local function lignes_du_temoin(action)
  local qui, nom = premier_homme()
  for _, ligne in ipairs(action(qui)) do
    jeu().journal("Poste : témoin " .. tostring(nom) .. ", " .. ligne)
  end
  return qui ~= nil
end

function poste.essai_naissance_noter() return lignes_du_temoin(jeu().noter_la_naissance) end
function poste.essai_inventaire_relever() return lignes_du_temoin(jeu().relever_l_inventaire) end
function poste.essai_signature_ranger() return sur_le_temoin(jeu().ranger_par_signature) end

function poste.essai_equiper_tenue() return equiper_la_sonde("tenue") end
function poste.essai_equiper_tenue_2() return equiper_la_sonde("tenue_2") end
function poste.essai_equiper_armes() return equiper_la_sonde("armes") end

-- Le lit de tente vu à découvert (V69, idée de la conversation Scriptorium) : les petites tentes du camp cachent
-- l'homme couché (V68). Un lit du camp, meuble et place du jeu, avec les mêmes données que le camp, posé à 5 m devant
-- Henry, sans tente ; puis le marcheur s'y couche.
local lit_d_essai = nil

function poste.essai_lit_a_decouvert()
  local camp = Scriptorium.camp
  local henry, cap = jeu().position_du_joueur(), jeu().cap_du_joueur()
  local position, cap_lit = Scriptorium.avis(camp, "dans_le_monde", { x = henry.x, y = henry.y, z = henry.z, cap = cap }, 0, 5, 0)
  local modele = camp.modeles.lit
  local meuble = jeu().poser_objet("lit", modele.chemin, position, cap_lit, "essai_lit_a_decouvert", modele.classe)
  local du_jeu = camp.objets_du_jeu.lit
  local p = du_jeu.places[1]
  local ici, cap_ici = Scriptorium.avis(camp, "dans_le_monde", { x = position.x, y = position.y, z = position.z, cap = cap_lit }, p.x, p.y, p.cap)
  lit_d_essai = jeu().poser_objet_du_jeu("essai_lit_a_decouvert_" .. p.nom, ici, cap_ici, du_jeu.proprietes)
  jeu().journal("Poste : lit à découvert, meuble " .. tostring(meuble) .. ", place " .. tostring(lit_d_essai))
  return lit_d_essai ~= nil
end

function poste.essai_marcheur_coucher_a_decouvert()
  jeu().journal("Poste : marcheur, " .. jeu().ordonner_sur_la_place(lit_d_essai, 11))
  return true
end

function poste.essai_marcheur_retirer()
  jeu().journal("Poste : marcheur, " .. jeu().retirer_le_marcheur())
  return true
end

-- Combat d'essai (étape 1) : deux âmes au cerveau npc_battle de camps opposés, devant Henry ; puis ce qu'ils deviennent.
local combattants_d_essai = {}

function poste.essai_combat()
  local noms, erreur = jeu().poser_un_combat_d_essai()
  combattants_d_essai = noms or {}
  jeu().journal("Poste : combat, posés = " .. (noms and table.concat(noms, ", ") or ("refus : " .. tostring(erreur))))
  return noms ~= nil
end

function poste.essai_combat_voir()
  local a, b = combattants_d_essai[1], combattants_d_essai[2]
  if not a then
    jeu().journal("Poste : combat, rien de posé")
    return false
  end
  for _, paire in ipairs({ { a, b }, { b, a } }) do
    jeu().journal("Poste : combat « " .. paire[1] .. " » : " .. table.concat(jeu().decrire_personnage(paire[1], paire[2], false), " | "))
  end
  return true
end

-- Bataille : ce que le jeu dit d'un ennemi de la bande au contact et d'un de nos hommes (faction, hostilité, cible,
-- fonctions de leur personnage), puis de chaque ennemi en une ligne (V18, V19).
function poste.essai_sonder()
  local ennemis, bande = ennemis_au_contact()
  local notres = nos_personnages()
  jeu().journal("Poste : sonde, bande = " .. tostring(bande) .. ", ennemis = " .. #ennemis .. ", nôtres = " .. #notres)
  local paires = {}
  if ennemis[1] then table.insert(paires, { ennemis[1], notres[1] }) end
  if notres[1] then table.insert(paires, { notres[1], ennemis[1] }) end
  for _, paire in ipairs(paires) do
    for _, ligne in ipairs(jeu().decrire_personnage(paire[1], paire[2], true)) do
      jeu().journal("Poste : sonde « " .. paire[1] .. " » : " .. ligne)
    end
  end
  for _, identifiant in ipairs(ennemis) do
    local lignes = jeu().decrire_personnage(identifiant, notres[1], false)
    jeu().journal("Poste : ennemi « " .. identifiant .. " » : " .. table.concat(lignes, " | "))
  end
  return #ennemis, #notres
end

-- Bataille : pose la bande au contact à dix-huit mètres devant le camp, en ligne (V18 : à soixante mètres,
-- personne ne voit personne ; vu le 14/10).
function poste.essai_rapprocher()
  local ennemis, bande = ennemis_au_contact()
  local camp = Scriptorium.camp
  for i, identifiant in ipairs(ennemis) do
    jeu().ordonner(identifiant, "approche", jeu().au_sol(camp.point((i - (#ennemis + 1) / 2) * 1.5, 18, 180)), "devant_le_camp")
  end
  jeu().journal("Poste : bande « " .. tostring(bande) .. " » rapprochée, " .. #ennemis .. " ennemi(s) à 18 m")
  return #ennemis
end

-- Henry : posé à douze mètres du premier ennemi de la bande au contact, côté camp (V18 : la bande se bat-elle ?).
function poste.essai_voir_bande()
  local ennemis = ennemis_au_contact()
  if not ennemis[1] then
    jeu().journal("Poste : pas de bande au contact")
    return false
  end
  local ok, compte_rendu = jeu().aller_pres_de(ennemis[1], Scriptorium.camp.point(0, 0, 0), 12)
  jeu().journal("Poste : voir la bande = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

-- Bataille : blesse à mort le premier ennemi encore vivant de la bande au contact (V19 : la mort se voit-elle ?
-- la bataille finit-elle par le jeu quand le dernier tombe ?).
function poste.essai_frapper()
  local ennemis, bande = ennemis_au_contact()
  for _, identifiant in ipairs(ennemis) do
    if not jeu().personnage_mort(identifiant) then
      local ok, erreur = jeu().blesser(identifiant, 1000)
      jeu().journal("Poste : frappé « " .. identifiant .. " » = " .. tostring(ok) .. (erreur and (" (" .. erreur .. ")") or "")
                    .. ", mort = " .. tostring(jeu().personnage_mort(identifiant)) .. ", vivants = " .. jeu().ennemis_vivants(ennemis))
      poste.battre_les_hommes()
      return ok
    end
  end
  jeu().journal("Poste : aucun ennemi vivant dans la bande " .. tostring(bande))
  return false
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

-- Modèles : pose huit modèles en cercle à 8 m d'Henry, un tous les 45° (cap de boussole), pour voir lesquels
-- le jeu dessine (14/10 : pans et tours de l'enceinte restaient invisibles, le portail et les tentes non).
-- Un second appel retire les huit précédents.
poste.modeles_a_essayer = {
  "Objects/manmade/structures/living/tents/tent_small_a.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_b_v4.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_b_v4_trosky.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_a_v2.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_makeshift_a_v2.cgf",
  "Objects/manmade/structures/defensive/watchtowers/watchtower_a.cgf",
  "Objects/manmade/structures/logistical/fences/fence_4rod_gate_02.cgf",
  "Objects/manmade/structures/defensive/walls/palisade/palisade_wall_b_v2.cgf",
}

function poste.essai_modeles()
  for i = 1, #poste.modeles_a_essayer do
    jeu().retirer_objet("scriptorium_essai_modele_" .. i)
  end
  if poste.modeles_poses then
    poste.modeles_poses = nil
    jeu().journal("Poste : modèles d'essai retirés")
    return true
  end
  local ici = jeu().position_du_joueur()
  for i, chemin in ipairs(poste.modeles_a_essayer) do
    local cap = (i - 1) * 45
    local a = math.rad(cap)
    local p = { x = ici.x + 8 * math.sin(a), y = ici.y + 8 * math.cos(a), z = ici.z }
    local identifiant = jeu().poser_objet("essai", chemin, p, (cap + 90) % 360, "essai_modele_" .. i)
    jeu().journal("Poste : modèle d'essai au cap " .. cap .. " : " .. chemin .. " = " .. tostring(identifiant))
  end
  poste.modeles_poses = true
  return true
end

-- Enceinte : pose Henry à 4 m de la porte, côté camp, pour la regarder de près.
function poste.essai_voir_porte()
  local centre = Scriptorium.camp.point(0, 0, 0)
  if not centre then
    jeu().journal("Poste : pas de camp")
    return false
  end
  local porte = Scriptorium.enceinte.objet_de("porte")
  if not porte then
    jeu().journal("Poste : pas de porte posée")
    return false
  end
  local ok, compte_rendu = jeu().aller_pres_de(porte, centre, 4)
  jeu().journal("Poste : voir la porte = " .. tostring(ok) .. " (" .. tostring(compte_rendu) .. ")")
  return ok
end

-- Porte : la fait passer d'ouverte à fermée, ou de fermée à ouverte (V22).
function poste.essai_porte()
  local enceinte = Scriptorium.enceinte
  local avant = enceinte.porte()
  local ok, raison
  if avant == "ouverte" then
    ok, raison = enceinte.fermer()
  else
    ok, raison = enceinte.ouvrir()
  end
  jeu().journal("Poste : porte, avant = " .. tostring(avant) .. ", après = " .. tostring(enceinte.porte())
                .. (ok and "" or (" (" .. tostring(raison) .. ")")))
  return ok
end

-- Discipline : écrit les fautes à juger et la réputation au journal.
function poste.essai_discipline()
  local discipline = Scriptorium.discipline
  local fautes = discipline.a_juger()
  jeu().journal("Poste : discipline, réputation = " .. discipline.reputation() .. ", fautes à juger = " .. #fautes)
  for _, f in ipairs(fautes) do
    jeu().journal("  " .. f.id .. " : " .. f.sorte .. " par " .. f.nom)
  end
  return fautes
end

-- Résumé du socle dans le journal.
function poste.bilan()
  for _, morceau in ipairs(Scriptorium.morceaux) do
    jeu().journal("Poste : morceau « " .. morceau.nom .. " » : " .. (morceau.pret and "prêt" or ("en panne : " .. tostring(morceau.erreur))))
  end
  local effectif = Scriptorium.hommes.effectif()
  jeu().journal("Poste : hommes, total = " .. effectif.nombre .. ", valides = " .. effectif.valides
                .. ", blessés = " .. effectif.blesses .. ", présents = " .. effectif.presents)
  local resultats = Scriptorium.bataille.resultats()
  jeu().journal("Poste : batailles, en cours = " .. #Scriptorium.bataille.bandes() .. ", jouées = " .. #resultats
                .. (resultats[#resultats] and (", dernière : " .. resultats[#resultats].issue) or ""))
  local comptes = Scriptorium.bandeau.comptes()
  jeu().journal("Poste : bandeau, affichés = " .. comptes.affiches .. ", regroupés = " .. comptes.regroupes
                .. ", répétés = " .. comptes.repetes .. ", refusés = " .. comptes.refuses)
end

-- Les commandes du poste, dans l'ordre : la console et le fichier d'ordres en lisent la même liste
-- (outils/ordonner.py aussi, pour refuser un nom inconnu avant de l'écrire).
poste.commandes = {
  { nom = "scriptorium_essai_bandeau", fonction = function() return poste.essai_bandeau() end, aide = "Essai du bandeau des messages" },
  { nom = "scriptorium_essai_registre", fonction = function() return poste.essai_registre() end, aide = "Essai du registre" },
  { nom = "scriptorium_essai_coffre", fonction = function() return poste.essai_coffre() end, aide = "Essai du coffre" },
  { nom = "scriptorium_essai_jetons_ecrire", fonction = function() return poste.essai_jetons_ecrire() end, aide = "Écrit des jetons de 16 000 à 200 000 caractères et les relit" },
  { nom = "scriptorium_essai_jetons_relire", fonction = function() return poste.essai_jetons_relire() end, aide = "Relit les jetons d'essai après rechargement" },
  { nom = "scriptorium_essai_cerveau", fonction = function() return poste.essai_cerveau() end, aide = "Nos hommes sont-ils connus de l'IA du jeu ? Comparaison avec un habitant" },
  { nom = "scriptorium_essai_liens", fonction = function() return poste.essai_liens() end, aide = "Liens de l'habitant le plus proche (moteur et IA)" },
  { nom = "scriptorium_essai_marcheur", fonction = function() return poste.essai_marcheur() end, aide = "Un homme au cerveau du mod, qui marche vers un point de son cerveau" },
  { nom = "scriptorium_essai_marcheur_point", fonction = function() return poste.essai_marcheur_point() end, aide = "Donne au marcheur un autre point" },
  { nom = "scriptorium_essai_marcheur_assis", fonction = function() return poste.essai_marcheur_assis() end, aide = "Ordre au marcheur : s'asseoir par terre" },
  { nom = "scriptorium_essai_marcheur_debout", fonction = function() return poste.essai_marcheur_debout() end, aide = "Ordre au marcheur : se relever et marcher au point" },
  { nom = "scriptorium_essai_marcheur_rejoindre", fonction = function() return poste.essai_marcheur_rejoindre() end, aide = "Le marcheur rejoint l'adversaire désigné par sa variable de cerveau" },
  { nom = "scriptorium_essai_marcheur_combat", fonction = function() return poste.essai_marcheur_combat() end, aide = "Un adversaire du mod ; le marcheur et lui se battent" },
  { nom = "scriptorium_essai_marcheur_brigand", fonction = function() return poste.essai_marcheur_brigand() end, aide = "Un brigand au cerveau du mod ; le marcheur et lui se battent" },
  { nom = "scriptorium_essai_marcheur_contre_henry", fonction = function() return poste.essai_marcheur_contre_henry() end, aide = "Ordre au marcheur : se battre contre Henry" },
  { nom = "scriptorium_essai_brigand_du_jeu", fonction = function() return poste.essai_brigand_du_jeu() end, aide = "Un brigand du jeu (son âme, son cerveau), éveillé, à 8 m devant Henry" },
  { nom = "scriptorium_essai_brigand_voir", fonction = function() return poste.essai_brigand_voir() end, aide = "Ce que fait le brigand du jeu ; santé d'Henry" },
  { nom = "scriptorium_essai_coup_recu", fonction = function() return poste.essai_coup_recu() end, aide = "Le marcheur reçoit un coup léger de l'adversaire" },
  { nom = "scriptorium_essai_henry_frappe", fonction = function() return poste.essai_henry_frappe() end, aide = "Henry porte un vrai coup au brigand du jeu (règles du jeu)" },
  { nom = "scriptorium_essai_henry_frappe_habitant", fonction = function() return poste.essai_henry_frappe_habitant() end, aide = "Le même coup sur l'habitant de la carte le plus proche (contrôle)" },
  { nom = "scriptorium_essai_habitant_voir", fonction = function() return poste.essai_habitant_voir() end, aide = "Ce que devient l'habitant frappé" },
  { nom = "scriptorium_essai_brigand_naissance", fonction = function() return poste.essai_brigand_naissance() end, aide = "Annonce à l'IA la naissance du brigand du jeu (XGenAIModule.OnSpawn, OnStart)" },
  { nom = "scriptorium_essai_marcheur_frappe", fonction = function() return poste.essai_marcheur_frappe() end, aide = "Un vrai coup du marcheur au brigand du jeu (règles du jeu)" },
  { nom = "scriptorium_essai_marcheur_effleure", fonction = function() return poste.essai_marcheur_effleure() end, aide = "Un coup à 0 point du marcheur au brigand du jeu" },
  { nom = "scriptorium_essai_henry_effleure", fonction = function() return poste.essai_henry_effleure() end, aide = "Un coup à 0 point d'Henry au brigand du jeu" },
  { nom = "scriptorium_essai_marcheur_attaque", fonction = function() return poste.essai_marcheur_attaque() end, aide = "Le marcheur demande au jeu d'attaquer le brigand du jeu (ordre 8)" },
  { nom = "scriptorium_essai_henry_effleure_marcheur", fonction = function() return poste.essai_henry_effleure_marcheur() end, aide = "Un coup à 0 point d'Henry au marcheur" },
  { nom = "scriptorium_essai_adversaire_brigand", fonction = function() return poste.essai_adversaire_brigand() end, aide = "Un adversaire à âme de brigand et à notre cerveau, posé seul" },
  { nom = "scriptorium_essai_henry_effleure_adversaire", fonction = function() return poste.essai_henry_effleure_adversaire() end, aide = "Un coup à 0 point d'Henry à l'adversaire" },
  { nom = "scriptorium_essai_garde_du_jeu", fonction = function() return poste.essai_garde_du_jeu() end, aide = "Un garde du jeu (son âme, son cerveau), éveillé, à 4 m d'Henry" },
  { nom = "scriptorium_essai_garde_voir", fonction = function() return poste.essai_garde_voir() end, aide = "Ce que fait le garde du jeu ; santé du brigand du jeu" },
  { nom = "scriptorium_essai_marcheur_attaque_adversaire", fonction = function() return poste.essai_marcheur_attaque_adversaire() end, aide = "Le marcheur attaque l'adversaire (ordre 8)" },
  { nom = "scriptorium_essai_marcheur_armer", fonction = function() return poste.essai_marcheur_armer() end, aide = "Le marcheur tire son arme ; ses compétences de combat" },
  { nom = "scriptorium_essai_prairie", fonction = function() return poste.essai_prairie() end, aide = "Henry posé sur la prairie des essais de combat" },
  { nom = "scriptorium_essai_marcheur_competences", fonction = function() return poste.essai_marcheur_competences() end, aide = "Les compétences de combat du marcheur posées à 20, puis relues" },
  { nom = "scriptorium_essai_brigand_leger", fonction = function() return poste.essai_brigand_leger() end, aide = "Un brigand du jeu plus léger (kkop_bandit_7), éveillé, à 8 m devant Henry" },
  { nom = "scriptorium_essai_brigand_leger_hors_du_camp", fonction = function() return poste.essai_brigand_leger_hors_du_camp() end, aide = "Le brigand léger, hors du camp : 10 m derrière Henry, sur la ligne du centre du camp (V73 b 1)" },
  { nom = "scriptorium_essai_marcheur_aller", fonction = function() return poste.essai_marcheur_aller() end, aide = "Le marcheur va au point (8 m à droite d'Henry), en interruption (ordre 9)" },
  { nom = "scriptorium_essai_marcheur_voir", fonction = function() return poste.essai_marcheur_voir() end, aide = "Où en est le marcheur" },
  { nom = "scriptorium_essai_marcheur_retrouver", fonction = function() return poste.essai_marcheur_retrouver() end, aide = "Après rechargement : le marcheur retrouvé par son nom, et ce que garde son cerveau" },
  { nom = "scriptorium_essai_marcheur_eveiller", fonction = function() return poste.essai_marcheur_eveiller() end, aide = "Le marcheur retrouvé est éveillé comme à sa naissance" },
  { nom = "scriptorium_essai_marcheur_retirer", fonction = function() return poste.essai_marcheur_retirer() end, aide = "Retire le marcheur du monde" },
  { nom = "scriptorium_essai_sieges_sonder", fonction = function() return poste.essai_sieges_sonder() end, aide = "Les sièges et lits du jeu les plus proches d'Henry" },
  { nom = "scriptorium_essai_siege_poser", fonction = function() return poste.essai_siege_poser() end, aide = "Pose près d'Henry une copie du siège du jeu le plus proche" },
  { nom = "scriptorium_essai_marcheur_asseoir_camp", fonction = function() return poste.essai_marcheur_asseoir_camp() end, aide = "Le marcheur s'assoit sur le premier banc du camp (ordre 10)" },
  { nom = "scriptorium_essai_marcheur_coucher_camp", fonction = function() return poste.essai_marcheur_coucher_camp() end, aide = "Le marcheur se couche sur le premier lit du camp (ordre 11)" },
  { nom = "scriptorium_essai_inventaire_sonder", fonction = function() return poste.essai_inventaire_sonder() end, aide = "Fonctions de l'inventaire et de l'acteur du premier homme (V71 a)" },
  { nom = "scriptorium_essai_equipement_compter", fonction = function() return poste.essai_equipement_compter() end, aide = "Compte les pièces des tenues et des armes de la sonde sur le premier homme" },
  { nom = "scriptorium_essai_equiper_tenue", fonction = function() return poste.essai_equiper_tenue() end, aide = "Pose la tenue soldier_generic_1_01 sur le premier homme, puis compte" },
  { nom = "scriptorium_essai_equiper_tenue_lourde", fonction = function() return poste.essai_equiper_tenue_2() end, aide = "Pose la tenue soldier_generic_5_01 sur le premier homme, puis compte" },
  { nom = "scriptorium_essai_equiper_armes", fonction = function() return poste.essai_equiper_armes() end, aide = "Pose les armes sword_shield_3_01 sur le premier homme, puis compte" },
  { nom = "scriptorium_essai_sonde_naitre", fonction = function() return poste.essai_sonde_naitre() end, aide = "Fait naître les deux sondes près du premier homme (V71 a2)" },
  { nom = "scriptorium_essai_sonde_equiper", fonction = function() return poste.essai_sonde_equiper() end, aide = "Pose la tenue lourde et les armes sur le premier homme et les deux sondes, puis compte" },
  { nom = "scriptorium_essai_sonde_compter", fonction = function() return poste.essai_sonde_compter() end, aide = "Compte l'équipement du premier homme et des deux sondes" },
  { nom = "scriptorium_essai_sonde_objets", fonction = function() return poste.essai_sonde_objets() end, aide = "Ce que rendent GetInventoryTable et ItemManager pour le premier homme" },
  { nom = "scriptorium_essai_objets_creer", fonction = function() return poste.essai_objets_creer() end, aide = "Crée trois objets avec leur état sur le premier homme, et habille l'habitant le plus proche (V71 a3)" },
  { nom = "scriptorium_essai_objets_relire", fonction = function() return poste.essai_objets_relire() end, aide = "Relit les objets créés (nombre, état) et la tenue de l'habitant" },
  { nom = "scriptorium_essai_temoin_armer", fonction = function() return poste.essai_temoin_armer() end, aide = "Crée et fait porter au premier homme la tenue lourde, l'épée et l'écu, pièce par pièce, état 0,6 (V71 a4)" },
  { nom = "scriptorium_essai_temoin_ici", fonction = function() return poste.essai_temoin_ici() end, aide = "Pose le premier homme à 3 m devant Henry, face à lui" },
  { nom = "scriptorium_essai_temoin_voir", fonction = function() return poste.essai_temoin_voir() end, aide = "Trie l'inventaire du premier homme : nos pièces (état 0,6) et les autres" },
  { nom = "scriptorium_essai_temoin_reporter", fonction = function() return poste.essai_temoin_reporter() end, aide = "Refait porter au premier homme nos pièces" },
  { nom = "scriptorium_essai_pieces_creer", fonction = function() return poste.essai_pieces_creer() end, aide = "Crée et fait porter au premier homme 13 pièces, leurs identifiants notés dans un jeton (V71 a5)" },
  { nom = "scriptorium_essai_pieces_voir", fonction = function() return poste.essai_pieces_voir() end, aide = "Reconnaît les pièces notées du premier homme par leur identifiant" },
  { nom = "scriptorium_essai_pieces_ranger", fonction = function() return poste.essai_pieces_ranger() end, aide = "Refait porter les pièces notées et retire toutes les autres (rien si une pièce notée manque)" },
  { nom = "scriptorium_essai_naissance_noter", fonction = function() return poste.essai_naissance_noter() end, aide = "Note la signature de la tenue de naissance du premier homme (objet et état de chaque pièce, V71 a6)" },
  { nom = "scriptorium_essai_inventaire_relever", fonction = function() return poste.essai_inventaire_relever() end, aide = "Relève l'inventaire du premier homme et le compare à la signature de naissance" },
  { nom = "scriptorium_essai_signature_ranger", fonction = function() return poste.essai_signature_ranger() end, aide = "Refait porter ses pièces et retire celles de la signature de naissance (garde-fous)" },
  { nom = "scriptorium_essai_equipement_voir", fonction = function() return poste.essai_equipement_voir() end, aide = "Équipement de chaque homme : préréglages, état, pièces dans son sac, munitions (V71 b)" },
  { nom = "scriptorium_essai_equipement_embaucher", fonction = function() return poste.essai_equipement_embaucher() end, aide = "Embauche un pavoisier et un homme d'armes (armes d'hast), palier 3" },
  { nom = "scriptorium_essai_equipement_degainer", fonction = function() return poste.essai_equipement_degainer() end, aide = "L'homme posé devant Henry sort son arme (V71 c)" },
  { nom = "scriptorium_essai_equipement_combat", fonction = function() return poste.essai_equipement_combat() end, aide = "L'homme posé devant Henry attaque le brigand du jeu (V71 d)" },
  { nom = "scriptorium_essai_equipement_reporter_sans_oter", fonction = function() return poste.essai_equipement_reporter_sans_oter() end, aide = "Refait porter au premier homme toutes ses pièces sans les ôter (la bascule, V71 c)" },
  { nom = "scriptorium_essai_equipement_monter", fonction = function() return poste.essai_equipement_monter() end, aide = "Le premier homme monte d'un palier" },
  { nom = "scriptorium_essai_equipement_donner", fonction = function() return poste.essai_equipement_donner() end, aide = "Donne au premier homme une pièce de soldier_generic_6_01, état 0,5, portée" },
  { nom = "scriptorium_essai_equipement_ici_suivant", fonction = function() return poste.essai_equipement_ici_suivant() end, aide = "Pose l'homme suivant à 3 m devant Henry" },
  { nom = "scriptorium_essai_compagnie_voir", fonction = function() return poste.essai_compagnie_voir() end, aide = "Faction, distance à Henry, munitions et contextes de crime de chaque homme et du Directeur (V72)" },
  { nom = "scriptorium_essai_compagnie_embaucher", fonction = function() return poste.essai_compagnie_embaucher() end, aide = "Engage un archer du palier 1, homme d'après la Compagnie (V72)" },
  { nom = "scriptorium_essai_compagnie_archer_ici", fonction = function() return poste.essai_compagnie_archer_ici() end, aide = "Pose le dernier archer à 3 m devant Henry (V72)" },
  { nom = "scriptorium_essai_compagnie_temoins", fonction = function() return poste.essai_compagnie_temoins() end, aide = "Deux hommes en témoins, de part et d'autre de la place de la victime (V72)" },
  { nom = "scriptorium_essai_compagnie_frapper", fonction = function() return poste.essai_compagnie_frapper() end, aide = "Un vrai habitant posé devant Henry et frappé par les règles du jeu, 5 points (V72 b)" },
  { nom = "scriptorium_essai_ecran_noir_voir", fonction = function() return poste.essai_ecran_noir_voir() end, aide = "Ce qui entoure Henry dans 15 m, et le relevé de la Compagnie (V72 c)" },
  { nom = "scriptorium_essai_ecran_noir_retirer_la_cible", fonction = function() return poste.essai_ecran_noir_retirer_la_cible() end, aide = "Retire la cible de l'archer (V72 c)" },
  { nom = "scriptorium_essai_ecran_noir_archer_derriere", fonction = function() return poste.essai_ecran_noir_archer_derriere() end, aide = "Pose le dernier archer à 4 m derrière Henry (V72 c)" },
  { nom = "scriptorium_essai_compagnie_qui", fonction = function() return poste.essai_compagnie_qui() end, aide = "Nomme le vrai habitant qui serait frappé, sans le toucher (V72 b)" },
  { nom = "scriptorium_essai_compagnie_cible", fonction = function() return poste.essai_compagnie_cible() end, aide = "La cible de l'archer, née à 12 m devant Henry (V72 b)" },
  { nom = "scriptorium_essai_compagnie_archer_tire", fonction = function() return poste.essai_compagnie_archer_tire() end, aide = "Le dernier archer attaque la cible (V72 b)" },
  { nom = "scriptorium_essai_hommes_asseoir", fonction = function() return poste.essai_hommes_asseoir() end, aide = "Chaque homme du camp s'assoit sur un banc du camp (ordre 10)" },
  { nom = "scriptorium_essai_hommes_coucher", fonction = function() return poste.essai_hommes_coucher() end, aide = "Chaque homme du camp se couche sur sa paillasse (ordre 11)" },
  { nom = "scriptorium_essai_directeur_coucher", fonction = function() return poste.essai_directeur_coucher() end, aide = "Le Directeur se couche sur son lit (ordre 11)" },
  { nom = "scriptorium_essai_hommes_lever", fonction = function() return poste.essai_hommes_lever() end, aide = "L'homme suivant marche vers sa place d'exercice (V73 c : la levée)" },
  { nom = "scriptorium_essai_hommes_attaque", fonction = function() return poste.essai_hommes_attaque() end, aide = "L'homme suivant attaque le brigand du jeu, sans être déplacé (V73 b 1 : l'attaque sur un homme assis)" },
  { nom = "scriptorium_essai_tenir_rassemblement", fonction = function() return poste.essai_tenir_rassemblement() end, aide = "Le premier homme tenu par le rassemblement, au point de la corvée (V73 b 3 : l'arbitre)" },
  { nom = "scriptorium_essai_tenir_loisir", fonction = function() return poste.essai_tenir_loisir() end, aide = "Le premier homme tenu par le loisir, aux dés, pour une heure (V73 b 3)" },
  { nom = "scriptorium_essai_lacher_rassemblement", fonction = function() return poste.essai_lacher_rassemblement() end, aide = "Le rassemblement du premier homme lâché (V73 b 3)" },
  { nom = "scriptorium_essai_tenir_garde", fonction = function() return poste.essai_tenir_garde() end, aide = "Le premier homme tenu par la garde au poste 1 : il y marche et se tient face au dehors (V73 d 1)" },
  { nom = "scriptorium_essai_lacher_garde", fonction = function() return poste.essai_lacher_garde() end, aide = "La garde du premier homme lâchée (V73 d 1)" },
  { nom = "scriptorium_essai_tenir_ronde", fonction = function() return poste.essai_tenir_ronde() end, aide = "Les deux premiers hommes sur la ronde d'essai, partis de deux points opposés (V73 d 2)" },
  { nom = "scriptorium_essai_lacher_ronde", fonction = function() return poste.essai_lacher_ronde() end, aide = "La ronde lâchée pour tous (V73 d 2)" },
  { nom = "scriptorium_essai_ronde_accroche_poser", fonction = function() return poste.essai_ronde_accroche(true) end, aide = "L'accroche d'essai « ronde reprise » active : le point opposé au plus proche (V73 d 2 bis)" },
  { nom = "scriptorium_essai_ronde_accroche_retirer", fonction = function() return poste.essai_ronde_accroche(false) end, aide = "L'accroche d'essai « ronde reprise » inactive : le point le plus proche (V73 d 2 bis)" },
  { nom = "scriptorium_essai_rassembler_rondiers", fonction = function() return poste.essai_rassembler_rondiers(true) end, aide = "Les deux premiers hommes tenus par un rassemblement à la corvée (V73 d 2 bis)" },
  { nom = "scriptorium_essai_lacher_rondiers", fonction = function() return poste.essai_rassembler_rondiers(false) end, aide = "Le rassemblement des deux premiers hommes lâché : leur ronde reprend (V73 d 2 bis)" },
  { nom = "scriptorium_essai_ronde_sans_pause", fonction = function() return poste.essai_ronde_sans_pause() end, aide = "Le second rondier sans pause (V73 d 2 bis)" },
  { nom = "scriptorium_essai_briefing", fonction = function() return poste.essai_briefing() end, aide = "Convoque l'homme suivant au briefing d'essai, en courant, face au centre (V73 e)" },
  { nom = "scriptorium_essai_rompre", fonction = function() return poste.essai_rompre() end, aide = "Rompez : le rassemblement lâché pour tous (V73 e)" },
  { nom = "scriptorium_essai_escorte", fonction = function() return poste.essai_escorte() end, aide = "Le Directeur suit Henry, trois hommes en colonne derrière lui (V73 f 1)" },
  { nom = "scriptorium_essai_fin_escorte", fonction = function() return poste.essai_fin_escorte() end, aide = "Fin de l'escorte : chacun reprend sa tranche (V73 f 1)" },
  { nom = "scriptorium_essai_escorte_formation", fonction = function() return poste.essai_escorte_formation() end, aide = "Le Directeur mène la formation followNPC, trois hommes s'y rangent (V73 f 1 bis)" },
  { nom = "scriptorium_essai_cheval", fonction = function() return poste.essai_cheval() end, aide = "Un cheval né à 5 m du premier homme, angle au hasard (V73 f 2 a)" },
  { nom = "scriptorium_essai_escorte_a_cheval", fonction = function() return poste.essai_escorte_a_cheval() end, aide = "Le premier homme suit Henry sur le cheval d'essai (V73 f 2 a)" },
  { nom = "scriptorium_essai_retirer_cheval", fonction = function() return poste.essai_retirer_cheval() end, aide = "Le cheval d'essai retiré (V73 f 2 a)" },
  { nom = "scriptorium_essai_troupe_a_cheval", fonction = function() return poste.essai_troupe_a_cheval() end, aide = "Les trois premiers hommes suivent Henry à cheval, en formation followNPC (V73 f 2 b)" },
  { nom = "scriptorium_essai_auberge_dehors", fonction = function() return poste.essai_lieu("auberge_dehors") end, aide = "Pose Henry devant l'auberge de Přítoky (les intérieurs, V73 f 3 b)" },
  { nom = "scriptorium_essai_auberge_dedans", fonction = function() return poste.essai_lieu("auberge_dedans") end, aide = "Pose Henry dans l'auberge de Přítoky, au rez-de-chaussée (V73 f 3 b)" },
  { nom = "scriptorium_essai_auberge_etage", fonction = function() return poste.essai_auberge_etage() end, aide = "Cherche l'étage de l'auberge de Přítoky par un rayon et y pose Henry (V73 f 3 b)" },
  { nom = "scriptorium_essai_recharger", fonction = function() return poste.essai_recharger() end, aide = "Relit nos morceaux Lua posés par outils/recharger.py, sans relancer le jeu (sonde V73 g 0)" },
  { nom = "scriptorium_essai_auberge_interieur", fonction = function() return poste.essai_auberge_interieur() end, aide = "Cherche l'intérieur de l'auberge de Přítoky par des rayons et y pose Henry (la porte, V73 g)" },
  { nom = "scriptorium_essai_homme_sous_le_sol", fonction = function() return poste.essai_homme_sous_le_sol() end, aide = "Pose le premier homme 20 m sous le terrain (le gardien, V73 g)" },
  { nom = "scriptorium_essai_homme_endormi", fonction = function() return poste.essai_homme_endormi() end, aide = "Endort le deuxième homme (Activate(0)) : le gardien doit le relancer (V73 g)" },
  { nom = "scriptorium_essai_grand_saut", fonction = function() return poste.essai_grand_saut() end, aide = "Pose Henry deux cents mètres devant lui (le grand saut, V73 f 3 b)" },
  { nom = "scriptorium_essai_carte_voir", fonction = function() return poste.essai_carte_voir() end, aide = "La carte lue et le dernier chargement vu (V73 f 3 a)" },
  { nom = "scriptorium_essai_directeur_a_cheval", fonction = function() return poste.essai_directeur_a_cheval() end, aide = "Le Directeur mène la formation followNPC, à cheval quand Henry l'est, trois hommes derrière lui (V73 f 2 e)" },
  { nom = "scriptorium_essai_escorte_comme_henry", fonction = function() return poste.essai_escorte_comme_henry() end, aide = "Les trois premiers hommes suivent Henry, à cheval quand il l'est (V73 f 2 d)" },
  { nom = "scriptorium_essai_henry_a_cheval", fonction = function() return poste.essai_henry_a_cheval() end, aide = "La lecture d'Henry forcée à cheval (V73 f 2 d)" },
  { nom = "scriptorium_essai_henry_a_pied", fonction = function() return poste.essai_henry_a_pied() end, aide = "La lecture d'Henry forcée à pied (V73 f 2 d)" },
  { nom = "scriptorium_essai_henry_lu", fonction = function() return poste.essai_henry_lu() end, aide = "La lecture d'Henry rendue au jeu (V73 f 2 d)" },
  { nom = "scriptorium_essai_cheval_d_henry", fonction = function() return poste.essai_cheval_d_henry() end, aide = "Le cheval d'Henry amené à 4 m devant lui (V73 f 2 d)" },
  { nom = "scriptorium_essai_qui_tient", fonction = function() return poste.essai_qui_tient() end, aide = "La règle qui tient chaque homme, son activité, sa fin (V73 b 3)" },
  { nom = "scriptorium_essai_hommes_voir", fonction = function() return poste.essai_hommes_voir() end, aide = "Où en est chaque homme et le Directeur : écart à sa place, assis, couchés, occupé, combats, âme" },
  { nom = "scriptorium_essai_lit_a_decouvert", fonction = function() return poste.essai_lit_a_decouvert() end, aide = "Un lit du camp (meuble et place du jeu) à 5 m devant Henry, sans tente" },
  { nom = "scriptorium_essai_marcheur_coucher_a_decouvert", fonction = function() return poste.essai_marcheur_coucher_a_decouvert() end, aide = "Le marcheur se couche sur le lit à découvert (ordre 11)" },
  { nom = "scriptorium_essai_sieges_relever", fonction = function() return poste.essai_sieges_relever() end, aide = "Propriétés complètes des sièges et lits du jeu à copier ; écart des places d'un banc" },
  { nom = "scriptorium_essai_lit_poser", fonction = function() return poste.essai_lit_poser() end, aide = "Pose près d'Henry une copie du lit du jeu le plus proche" },
  { nom = "scriptorium_essai_marcheur_asseoir", fonction = function() return poste.essai_marcheur_asseoir() end, aide = "Le marcheur s'assoit sur le siège posé (ordre 10)" },
  { nom = "scriptorium_essai_marcheur_coucher", fonction = function() return poste.essai_marcheur_coucher() end, aide = "Le marcheur se couche sur le lit posé (ordre 11)" },
  { nom = "scriptorium_essai_marcheur_asseoir_reel", fonction = function() return poste.essai_marcheur_asseoir_reel() end, aide = "Le marcheur s'assoit sur le siège du jeu le plus proche (ordre 10)" },
  { nom = "scriptorium_essai_marcheur_coucher_reel", fonction = function() return poste.essai_marcheur_coucher_reel() end, aide = "Le marcheur se couche sur le lit du jeu le plus proche (ordre 11)" },
  { nom = "scriptorium_essai_combat", fonction = function() return poste.essai_combat() end, aide = "Deux combattants npc_battle de camps opposés devant Henry" },
  { nom = "scriptorium_essai_combat_voir", fonction = function() return poste.essai_combat_voir() end, aide = "Ce que deviennent les deux combattants d'essai" },
  { nom = "scriptorium_essai_registre_tranches", fonction = function() return poste.essai_registre_tranches() end, aide = "Ce que le jeu garde du registre en tranches ; nombres justes en simple précision" },
  { nom = "scriptorium_essai_camp", fonction = function() return poste.essai_camp() end, aide = "Fonde le camp où se tient Henry, ou le redresse" },
  { nom = "scriptorium_essai_camp_agrandir", fonction = function() return poste.essai_camp_agrandir() end, aide = "Agrandit le camp d'un niveau" },
  { nom = "scriptorium_essai_feu", fonction = function() return poste.essai_feu() end, aide = "Ce que le jeu dit du feu, d'un banc et d'une tente" },
  { nom = "scriptorium_essai_aller_nord", fonction = function() return poste.essai_aller(0) end, aide = "Pose Henry quarante mètres au nord" },
  { nom = "scriptorium_essai_aller_est", fonction = function() return poste.essai_aller(90) end, aide = "Pose Henry quarante mètres à l'est" },
  { nom = "scriptorium_essai_aller_sud", fonction = function() return poste.essai_aller(180) end, aide = "Pose Henry quarante mètres au sud" },
  { nom = "scriptorium_essai_aller_ouest", fonction = function() return poste.essai_aller(270) end, aide = "Pose Henry quarante mètres à l'ouest" },
  { nom = "scriptorium_essai_terrain_d_essai", fonction = function() return poste.essai_terrain_d_essai() end, aide = "Lève le camp et pose Henry sur le terrain d'essai" },
  { nom = "scriptorium_essai_camp_lever", fonction = function() return poste.essai_camp_lever() end, aide = "Lève le camp" },
  { nom = "scriptorium_essai_tout_lever", fonction = function() return poste.essai_tout_lever() end, aide = "Renvoie les hommes, congédie le Directeur et lève le camp" },
  { nom = "scriptorium_essai_hommes", fonction = function() return poste.essai_hommes() end, aide = "Engage trois hommes et lance leur journée" },
  { nom = "scriptorium_essai_bataille", fonction = function() return poste.essai_bataille() end, aide = "Lève une bande de cinq brigands venant du nord" },
  { nom = "scriptorium_essai_camp_de_bandits", fonction = function() return poste.essai_camp_de_bandits(120) end, aide = "Dresse un petit camp de bandits à 120 m devant Henry (il naît quand Henry ne le regarde plus)" },
  { nom = "scriptorium_essai_camps_de_bandits", fonction = function() return poste.essai_camps_de_bandits() end, aide = "Les camps de bandits, leur bande et ses ennemis debout" },
  { nom = "scriptorium_essai_vers_le_camp_de_bandits", fonction = function() return poste.essai_vers_le_camp_de_bandits() end, aide = "Pose Henry à 50 m au sud du premier camp de bandits" },
  { nom = "scriptorium_essai_colonne_vers_le_camp_de_bandits", fonction = function() return poste.essai_colonne_vers_le_camp_de_bandits() end, aide = "Les trois premiers hommes, à cheval, menés vers le lieu du camp de bandits" },
  { nom = "scriptorium_essai_mission_pres", fonction = function() return poste.essai_mission(120) end, aide = "Mission des trois premiers hommes vers un camp de bandits à 120 m devant Henry" },
  { nom = "scriptorium_essai_mission_loin", fonction = function() return poste.essai_mission(450) end, aide = "Mission des trois premiers hommes vers un camp de bandits à 450 m devant Henry (issue au loin)" },
  { nom = "scriptorium_essai_missions", fonction = function() return poste.essai_missions() end, aide = "Les missions en cours" },
  { nom = "scriptorium_essai_convoi", fonction = function() return poste.essai_convoi() end, aide = "Lance un convoi d'essai sur une route de trois points devant Henry" },
  { nom = "scriptorium_essai_convois", fonction = function() return poste.essai_convois() end, aide = "Les convois en route : parcours, position, bande" },
  { nom = "scriptorium_essai_lever_les_camps", fonction = function() return poste.essai_lever_les_camps() end, aide = "Lève tous les camps de bandits" },
  { nom = "scriptorium_essai_bataille_trois", fonction = function() return poste.essai_bataille_trois() end, aide = "Lève une bande de trois brigands venant du nord (diagnostic du combat)" },
  { nom = "scriptorium_essai_sonder", fonction = function() return poste.essai_sonder() end, aide = "Ce que le jeu dit des ennemis au contact et de nos hommes" },
  { nom = "scriptorium_essai_rapprocher", fonction = function() return poste.essai_rapprocher() end, aide = "Pose la bande au contact à 18 m devant le camp" },
  { nom = "scriptorium_essai_voir_bande", fonction = function() return poste.essai_voir_bande() end, aide = "Pose Henry à 12 m de la bande, côté camp" },
  { nom = "scriptorium_essai_frapper", fonction = function() return poste.essai_frapper() end, aide = "Blesse à mort le premier ennemi vivant de la bande" },
  { nom = "scriptorium_essai_directeur", fonction = function() return poste.essai_directeur() end, aide = "Installe le Directeur et écrit le menu de la Gestion du camp" },
  { nom = "scriptorium_gestion_rapport", fonction = function() return poste.gestion("rapport") end, aide = "Le rapport du Directeur" },
  { nom = "scriptorium_essai_enceinte", fonction = function() return poste.essai_enceinte() end, aide = "Bâtit la palissade et les tours" },
  { nom = "scriptorium_essai_porte", fonction = function() return poste.essai_porte() end, aide = "Ouvre la porte fermée, ou ferme la porte ouverte" },
  { nom = "scriptorium_essai_voir_porte", fonction = function() return poste.essai_voir_porte() end, aide = "Pose Henry à 4 m de la porte, côté camp" },
  { nom = "scriptorium_essai_modeles", fonction = function() return poste.essai_modeles() end, aide = "Pose huit modèles autour d'Henry, ou les retire" },
  { nom = "scriptorium_essai_patrouille", fonction = function() return poste.essai_patrouille() end, aide = "Envoie deux hommes faire la ronde proche" },
  { nom = "scriptorium_essai_discipline", fonction = function() return poste.essai_discipline() end, aide = "Les fautes à juger et la réputation" },
  { nom = "scriptorium_bilan", fonction = function() return poste.bilan() end, aide = "Bilan du socle dans le journal" },
}

local function trouver_commande(nom)
  for _, commande in ipairs(poste.commandes) do
    if commande.nom == nom then
      return commande
    end
  end
  return nil
end

-- Exécute une commande du poste par son nom. Une commande qui casse est notée au journal.
function poste.executer(nom)
  local commande = trouver_commande(nom)
  if not commande then
    jeu().journal("Poste : commande inconnue « " .. tostring(nom) .. " »")
    return false
  end
  local ok, erreur = pcall(commande.fonction)
  if not ok then
    jeu().journal("Poste : « " .. nom .. " » en erreur : " .. tostring(erreur))
  end
  return ok
end

-- Ordres par fichier. Le PC écrit Mods/scriptorium_socle/ordres.lua (outils/ordonner.py) :
--   return { numero = N, commande = "scriptorium_…" }
-- Le poste le relit à chaque battement ; un ordre au numéro plus grand que le dernier vu est exécuté
-- une seule fois, et seulement quand une partie est en cours (sinon il attend). L'ordre déjà présent
-- au lancement du jeu est ancien : il n'est pas rejoué.
poste.reglages = {
  cadence_ms = 2000,       -- intervalle entre deux relevés du fichier d'ordres
  tours_par_veille = 15,   -- une ligne de veille au journal tous les 15 relevés (30 secondes)
}

local ordres

function poste.remettre_a_zero()
  ordres = { premier_releve = true, dernier = 0, chemin = nil, raison = nil, attente = nil, tours = 0, partie = nil,
             actif = false, generation = 0 }
end
poste.remettre_a_zero()

local function noter_raison(raison)
  if raison ~= ordres.raison then
    ordres.raison = raison
    if raison then
      jeu().journal("Poste : fichier d'ordres illisible : " .. raison)
    end
  end
end

-- Un relevé du fichier d'ordres. Rend « absent », « illisible », « ancien », « deja_fait »,
-- « en_attente », « refuse » ou « execute ».
function poste.relever_ordres()
  local donnees, chemin, raison = jeu().lire_ordres()
  if chemin and chemin ~= ordres.chemin then
    ordres.chemin = chemin
    jeu().journal("Poste : fichier d'ordres trouvé à « " .. chemin .. " »")
  end
  if donnees == nil then
    noter_raison(raison)
    if ordres.premier_releve then
      ordres.premier_releve = false
      if not raison then
        jeu().journal("Poste : pas de fichier d'ordres au lancement")
      end
    end
    return raison and "illisible" or "absent"
  end
  if type(donnees.numero) ~= "number" or type(donnees.commande) ~= "string" then
    noter_raison("numéro ou commande manquant")
    ordres.premier_releve = false
    return "illisible"
  end
  noter_raison(nil)
  local numero, nom = donnees.numero, donnees.commande
  if ordres.premier_releve then
    ordres.premier_releve = false
    ordres.dernier = numero
    jeu().journal("Poste : ordre n° " .. numero .. " (" .. nom .. ") trouvé au lancement, non rejoué")
    return "ancien"
  end
  if numero <= ordres.dernier then
    return "deja_fait"
  end
  if not trouver_commande(nom) then
    ordres.dernier = numero
    jeu().journal("Poste : ordre n° " .. numero .. " refusé : commande inconnue « " .. nom .. " »")
    return "refuse"
  end
  if not jeu().partie_en_cours() then
    if ordres.attente ~= numero then
      ordres.attente = numero
      jeu().journal("Poste : ordre n° " .. numero .. " (" .. nom .. ") en attente d'une partie")
    end
    return "en_attente"
  end
  ordres.dernier = numero
  ordres.attente = nil
  jeu().journal("Poste : ordre n° " .. numero .. " : " .. nom)
  poste.executer(nom)
  return "execute"
end

-- Ligne de veille : dit au journal si les minuteries tournent encore, et où en sont le bandeau et les ordres.
function poste.veiller()
  local partie = jeu().partie_en_cours()
  ordres.tours = ordres.tours + 1
  if partie ~= ordres.partie or ordres.tours >= poste.reglages.tours_par_veille then
    ordres.partie = partie
    ordres.tours = 0
    local comptes = Scriptorium.bandeau.comptes()
    jeu().journal("Poste : veille, partie en cours = " .. tostring(partie)
                  .. ", bandeau en attente = " .. Scriptorium.bandeau.en_attente()
                  .. ", affichés = " .. comptes.affiches .. ", dernier ordre = " .. ordres.dernier
                  .. string.format(", heure du jeu = %.2f", jeu().heure_du_jeu())
                  .. (jeu().temps_arrete and (", temps arrêté = " .. tostring(jeu().temps_arrete())) or ""))
  end
end

-- Fait battre le poste tout seul : relevé des ordres, puis veille.
function poste.demarrer()
  if ordres.actif then
    return
  end
  ordres.actif = true
  ordres.generation = ordres.generation + 1
  local generation = ordres.generation
  local function battement()
    if not ordres.actif or ordres.generation ~= generation then
      return
    end
    local ok, erreur = pcall(poste.relever_ordres)
    if not ok then
      jeu().journal("Poste : erreur au relevé des ordres : " .. tostring(erreur))
    end
    ok, erreur = pcall(poste.veiller)
    if not ok then
      jeu().journal("Poste : erreur à la veille : " .. tostring(erreur))
    end
    jeu().minuterie(poste.reglages.cadence_ms, battement)
  end
  jeu().minuterie(poste.reglages.cadence_ms, battement)
end

function poste.arreter()
  ordres.actif = false
end

-- Entrée en partie : repose la minuterie (celle du démarrage du mod ne tire jamais en jeu).
function poste.relancer()
  ordres.actif = false
  poste.demarrer()
end

Scriptorium.declarer_morceau("poste", function()
  for _, commande in ipairs(poste.commandes) do
    jeu().commande(commande.nom, Scriptorium.chemin .. ".poste.executer('" .. commande.nom .. "')", commande.aide)
  end
  poste.demarrer()
end)

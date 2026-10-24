-- Petits outils pour écrire les essais Lua : verifier(), egal(), essai().
-- Les résultats sont rassemblés dans la table globale Essais, lue par essais/tout_verifier.py.

Essais = Essais or { reussis = 0, echecs = 0, messages = {}, courant = "?" }

function essai(nom, fonction)
  Essais.courant = nom
  local ok, erreur = pcall(fonction)
  if not ok then
    Essais.echecs = Essais.echecs + 1
    table.insert(Essais.messages, "ÉCHEC [" .. nom .. "] erreur : " .. tostring(erreur))
  end
end

function verifier(condition, message)
  if condition then
    Essais.reussis = Essais.reussis + 1
  else
    Essais.echecs = Essais.echecs + 1
    table.insert(Essais.messages, "ÉCHEC [" .. Essais.courant .. "] " .. tostring(message))
  end
  return condition
end

function egal(obtenu, attendu, message)
  return verifier(obtenu == attendu,
    (message or "") .. " : obtenu « " .. tostring(obtenu) .. " », attendu « " .. tostring(attendu) .. " »")
end

-- Remet le socle et le faux jeu dans l'état de départ, pour chaque essai.
-- Fiche 16 : les essais d'avant éprouvent les règles du socle allumées.
function allumer_les_interrupteurs()
  for nom in pairs(Scriptorium.noyau.interrupteurs or {}) do
    Scriptorium.noyau.interrupteurs[nom] = 1
  end
end

function depart()
  FauxJeu.remettre_a_zero()
  Scriptorium.bandeau.remettre_a_zero()
  Scriptorium.registre.remettre_a_zero()
  Scriptorium.remettre_a_zero()
  if Scriptorium.reglages then
    Scriptorium.reglages.remettre_a_zero()
  end
  allumer_les_interrupteurs()
  FauxJeu.chargement = false
  if Scriptorium.hommes then
    -- Vu en J32 (24/10) : les ordres de la journée sont échelonnés en jeu (4 par seconde) ; au banc, l'horloge réelle ne
    -- bouge pas : les épreuves les veulent tout de suite, sauf celle de l'échelonnement, qui pose le réglage.
    Scriptorium.hommes.reglages.ordres_par_seconde = 0
    -- De même, les épreuves du gardien comptent sur une grâce de 2 regards (20 s, 5 regards, en jeu depuis J32).
    Scriptorium.hommes.reglages.fige_ordre_regards = 2
    Scriptorium.hommes.ordres_differes, Scriptorium.hommes.prochain_creneau = {}, nil
    Scriptorium.hommes.suivi = {}
    Scriptorium.hommes.cerveaux_regles = {}
    Scriptorium.hommes.arrets_vus = {}
    Scriptorium.hommes.fins_de_combat_vues = {}
    Scriptorium.hommes.lancements_vus = {}
    Scriptorium.hommes.garde_de_la_tenue_rang = 0
    Scriptorium.hommes.habillage_rang = 0
    Scriptorium.hommes.en_ronde = {}
    Scriptorium.hommes.montures = {}
    Scriptorium.hommes.henry_monte, Scriptorium.hommes.henry_pied_lectures, Scriptorium.hommes.henry_force = false, 0, nil
    Scriptorium.hommes.hasard_de_la_ronde = nil
    Scriptorium.hommes.raisons_de_reprise = {}
    Scriptorium.hommes.accroches.ronde_reprise = {}
    -- Fiches 20 et 18 (tranche 4) : les paroles et les stations partagées vivent en mémoire.
    Scriptorium.hommes.paroles, Scriptorium.hommes.stations = {}, {}
    Scriptorium.hommes.rattrapages_en_attente = {}
    Scriptorium.hommes.gardien = { vus = {}, relances = 0, utiles = 0, repeches = 0 }
  end
  -- Les places déclarées par Scriptorium (19/10) vivent en mémoire.
  if Scriptorium.camp then
    Scriptorium.camp.places_declarees, Scriptorium.camp.ordre_des_places_declarees = {}, {}
  end
  if Scriptorium.bataille then
    Scriptorium.bataille.relances = {}
    Scriptorium.bataille.vus = {}
  end
  if Scriptorium.missions then
    Scriptorium.missions.lieux = {}
    -- Les lieux du socle (18/10) : gardés à part, remis seulement pour leur essai (lieux_du_socle_d_origine).
    Scriptorium.missions.lieux_du_socle_d_origine = Scriptorium.missions.lieux_du_socle_d_origine
      or Scriptorium.missions.lieux_du_socle
    Scriptorium.missions.lieux_du_socle = {}
  end
  -- Des hommes ordinaires (tous les traits à 50, fiche 11) : ration, force, fautes et moral comme avant le caractère.
  -- Les essais du caractère reprennent les vraies fourchettes par depart_avec_caractere().
  -- À 50, chaque facteur vaut exactement 1 parce que les bornes validées sont symétriques autour de 1 (0,8 et 1,2 ;
  -- 0,85 et 1,15 ; 0,5 et 1,5 ; 0,25 et 4 en progression géométrique) : si l'une d'elles change, ce profil doit être
  -- revu. Ni don ni faiblesse marqués.
  if Scriptorium.caractere then
    local r = Scriptorium.caractere.reglages
    r.trait_min, r.trait_max, r.aguerri_min, r.aguerri_max = 50, 50, 50, 50
    r.dons_min, r.dons_max, r.faiblesses_min, r.faiblesses_max, r.part_hors_du_commun = 0, 0, 0, 0, 0
  end
  if Scriptorium.poste then
    Scriptorium.poste.remettre_a_zero()
  end
  if Scriptorium.patrouilles and not Scriptorium.patrouilles.battre_original then
    Scriptorium.patrouilles.battre_original = Scriptorium.patrouilles.battre
  end
end

-- Départ avec les vraies fourchettes du caractère (fiche 11), validées par JoVenGer.
function depart_avec_caractere()
  depart()
  Scriptorium.reglages.remettre_a_zero()
  allumer_les_interrupteurs()
end

-- Fiche 19 : remplace « morceau[nom] » le temps de « corps », et remet l'original même si « corps » échoue (l'erreur
-- est alors relancée).
function avec_remplacement(morceau, nom, fonction, corps)
  local original = morceau[nom]
  morceau[nom] = fonction
  local ok, erreur = pcall(corps)
  morceau[nom] = original
  if not ok then
    error(erreur, 0)
  end
end

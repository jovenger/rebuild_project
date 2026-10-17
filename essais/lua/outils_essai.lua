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
function depart()
  FauxJeu.remettre_a_zero()
  Scriptorium.bandeau.remettre_a_zero()
  Scriptorium.registre.remettre_a_zero()
  Scriptorium.remettre_a_zero()
  if Scriptorium.reglages then
    Scriptorium.reglages.remettre_a_zero()
  end
  FauxJeu.chargement = false
  if Scriptorium.hommes then
    Scriptorium.hommes.suivi = {}
    Scriptorium.hommes.cerveaux_regles = {}
    Scriptorium.hommes.arrets_vus = {}
    Scriptorium.hommes.fins_de_combat_vues = {}
    Scriptorium.hommes.lancements_vus = {}
    Scriptorium.hommes.garde_de_la_tenue_rang = 0
    Scriptorium.hommes.en_ronde = {}
    Scriptorium.hommes.hasard_de_la_ronde = nil
    Scriptorium.hommes.raisons_de_reprise = {}
    Scriptorium.hommes.accroches.ronde_reprise = {}
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
end

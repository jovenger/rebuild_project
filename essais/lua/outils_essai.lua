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
  if Scriptorium.poste then
    Scriptorium.poste.remettre_a_zero()
  end
  if Scriptorium.patrouilles and not Scriptorium.patrouilles.battre_original then
    Scriptorium.patrouilles.battre_original = Scriptorium.patrouilles.battre
  end
end

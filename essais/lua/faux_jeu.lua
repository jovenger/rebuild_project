-- Faux jeu pour les essais : remplace Scriptorium.jeu (la liaison réelle n'est pas chargée).
-- Tout ce que le socle demande au jeu est noté ici, pour être vérifié par les essais.

local faux = {
  temps = 0,
  affichages = {},      -- { texte, duree, temps }
  en_ecran = nil,
  journal_lignes = {},
  dialogue = false,
  registre_stocke = nil,
  minuteries = {},      -- { ms, fonction }
  commandes = {},       -- { nom, code, aide }
  bourse_henry = 0,     -- groschen dans la bourse d'Henry
  heure = 0,            -- heure du jeu, en heures
  appels_retirer = 0,   -- fois où le socle a demandé à retirer des groschen à Henry
  donner_en_panne = false,
}

function faux.remettre_a_zero()
  faux.temps = 0
  faux.affichages = {}
  faux.en_ecran = nil
  faux.journal_lignes = {}
  faux.dialogue = false
  faux.registre_stocke = nil
  faux.minuteries = {}
  faux.commandes = {}
  faux.bourse_henry = 0
  faux.heure = 0
  faux.appels_retirer = 0
  faux.donner_en_panne = false
end

function faux.maintenant() return faux.temps end
function faux.avancer(secondes) faux.temps = faux.temps + secondes end
function faux.journal(texte) table.insert(faux.journal_lignes, tostring(texte)) end
function faux.afficher(texte, duree)
  table.insert(faux.affichages, { texte = texte, duree = duree, temps = faux.temps })
  faux.en_ecran = texte
end
function faux.effacer() faux.en_ecran = nil end
function faux.dialogue_en_cours() return faux.dialogue end
function faux.minuterie(ms, fonction)
  table.insert(faux.minuteries, { ms = ms, fonction = fonction })
  return #faux.minuteries
end
function faux.lire_registre() return faux.registre_stocke end
function faux.ecrire_registre(chaine) faux.registre_stocke = chaine end
function faux.commande(nom, code, aide) table.insert(faux.commandes, { nom = nom, code = code, aide = aide }) end
function faux.heure_du_jeu() return faux.heure end
function faux.groschen_d_henry() return faux.bourse_henry end
function faux.retirer_groschen_a_henry(n)
  faux.appels_retirer = faux.appels_retirer + 1
  if faux.bourse_henry < n then return false end
  faux.bourse_henry = faux.bourse_henry - n
  return true
end
function faux.donner_groschen_a_henry(n)
  if faux.donner_en_panne then return false end
  faux.bourse_henry = faux.bourse_henry + n
  return true
end

-- Exécute la prochaine minuterie en attente (une seule), comme le ferait le moteur.
function faux.tic_minuterie()
  local prochaine = table.remove(faux.minuteries, 1)
  if prochaine then
    prochaine.fonction()
    return true
  end
  return false
end

Scriptorium = Scriptorium or {}
Scriptorium.jeu = faux
FauxJeu = faux
return faux

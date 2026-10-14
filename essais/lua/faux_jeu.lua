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

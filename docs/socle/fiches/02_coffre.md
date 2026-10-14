# Fiche 02 — Le coffre et la logistique

- Morceau : 2. Table : `Scriptorium.coffre`. Fichier : `socle/pak/Scripts/scriptorium/coffre.lua`.
- État : écrit et passé au banc ; vu en jeu (dépôt pris dans la bourse d'Henry, paiement refusé faute de groschen, heure du jeu au livre). Validée par JoVenGer le 14/10/2026 : le camp paie au coffre seul, échanges avec Henry dans les deux sens, 50 lignes au livre, les huit réserves.

## Ce que le joueur voit
- Rien tant que tout va bien : les mouvements d'argent et de marchandises s'inscrivent au livre de comptes, lisible plus tard dans la Gestion du camp.
- « Le coffre du camp ne peut pas payer : il manque des groschen. » quand une dépense du camp est refusée.
- « Henry n'a pas assez de groschen pour ce dépôt. » quand Henry veut déposer plus qu'il n'a.
- « Les vivres du camp sont épuisés. » (et de même pour chaque réserve) quand une réserve tombe à zéro.

## Règles
- **Le camp paie au coffre, jamais avec la bourse d'Henry.** Une dépense du camp (`payer`) ne touche que le coffre. Si le coffre ne peut pas la couvrir, elle est refusée et rien n'est pris ailleurs. Le code ne demande jamais au jeu de retirer des groschen à Henry pour une dépense du camp.
- **Henry et le coffre.** Henry peut déposer (`deposer_par_henry`) : le jeu retire les groschen de sa bourse, puis le coffre les reçoit ; s'il n'a pas assez, refus. Le camp peut verser à Henry (`verser_a_henry`) : le coffre est débité seulement si le jeu a bien remis les groschen. Chaque fois, une ligne au livre, avec son motif.
- **Livre de comptes.** Chaque mouvement est une ligne : numéro, moment du jeu, sorte (`groschen` ou une réserve), montant signé, motif, solde après. Les 50 dernières lignes sont gardées ; les totaux d'entrées et de sorties de groschen restent exacts même quand les plus anciennes sont oubliées.
- **Dépenses justes.** Un montant est un entier strictement positif, sinon refus (journal seulement). Un motif est un mot non vide, sans accent (par exemple `solde`, `butin`, `embauche`, `vivres`).
- **Réserves par sorte**, en unités entières : `vivres`, `biere`, `fourrage`, `traits` (flèches et carreaux), `bois`, `herbes`, `fer`, `cuir`. Une sorte inconnue est refusée. Un prélèvement au-delà de la réserve est refusé. Quand une réserve tombe à zéro, le joueur en est averti.
- **Enregistrement.** Le coffre enregistre le registre après chaque mouvement réussi.
- **Lecture.** `solde()`, `reserve(sorte)`, `livre(n)` (les n dernières lignes), `bilan()` (solde, entrées, sorties, réserves, nombre de lignes).

## Sorts rendus
Chaque mouvement rend `true`, ou `false` et une raison : `montant_invalide`, `motif_invalide`, `sorte_inconnue`, `coffre_insuffisant`, `reserve_insuffisante`, `henry_insuffisant`, `jeu_en_echec`.

## Réglages (`coffre.reglages`)
`lignes_gardees` 50.

## Ce qui est sauvegardé (case `coffre`, version 1)
`{ groschen, entrees, sorties, reserves = { vivres, biere, … }, livre = { lignes = {…}, prochain_numero } }`.

## Ce que le coffre demande au jeu (liaison)
`heure_du_jeu()` (moment inscrit au livre), `groschen_d_henry()`, `retirer_groschen_a_henry(n)` (vrai si fait), `donner_groschen_a_henry(n)` (vrai si fait), `journal(texte)`.

## À vérifier en jeu
- Les appels qui lisent et changent la bourse d'Henry (la liaison essaie `player.inventory:GetMoney()`, `RemoveMoney`, `AddMoney`, en se protégeant : si l'appel n'existe pas, le mouvement est refusé, sans rien casser).
- L'appel qui donne l'heure du jeu (`Calendar.GetWorldTime()` ?), pour dater les lignes du livre.

## Essais au banc (`essais/lua/essai_coffre.lua`)
Départ à zéro ; encaisser puis payer, lignes et solde après ; refus faute de groschen sans toucher Henry ; montants et motifs invalides ; versement à Henry et dépôt par Henry, avec refus ; réserves : ajout, prélèvement, sorte inconnue, insuffisance, avertissement d'épuisement ; livre borné et totaux exacts ; écriture puis relecture par le registre ; le camp ne retire jamais rien à Henry pour payer.

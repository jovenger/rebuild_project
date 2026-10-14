# Fiche 08 — Les patrouilles et le reste

- Morceau : 8. Table : `Scriptorium.patrouilles`. Fichier : `socle/pak/Scripts/scriptorium/patrouilles.lua`. Avec lui, le battement commun du socle (`Scriptorium.battre`) dans `noyau.lua`.
- État : écrit et passé au banc. En attente de l'essai en jeu et de la validation de la fiche par JoVenGer.

## Ce que le joueur voit
- Des patrouilles envoyées par la Gestion du camp : une ronde proche, la route du village, les bois. Les hommes partent, suivent leur chemin, reviennent et rendent compte au Directeur : « La patrouille est rentrée : rien à signaler. », « … a chassé des rôdeurs et rapporté du butin. », « … est tombée dans une embuscade. »
- Les tours de guet (morceau 7) et les patrouilles préviennent plus tôt des bandes.

## Règles
- **Chemins en données** (`patrouilles.chemins`) : nom, points par rapport au camp, durée en heures, risque (0 à 1) : `ronde_proche` (4 points à 30 m, 2 h, risque 0,1), `route_du_village` (3 points jusqu'à 150 m, 5 h, risque 0,3), `les_bois` (4 points jusqu'à 200 m, 8 h, risque 0,5).
- **Envoyer** (`envoyer{ chemin, hommes }`) : de 2 à 6 hommes valides, pris parmi ceux qui ne sont ni de garde ni affectés, les plus anciens d'abord ; chacun reçoit l'affectation « patrouille » (il quitte sa journée et la garde). Refus : `camp_absent`, `chemin_inconnu`, `effectif_invalide`, `pas_assez_d_hommes`, `patrouille_en_cours` (une seule à la fois).
- **Marche** : à chaque battement, la patrouille passe au point suivant quand sa part de durée est écoulée ; ses hommes reçoivent l'ordre d'aller au point (par la liaison, au changement seulement).
- **Rencontres** : au retour, tirées de la graine de la bataille : avec une chance égale au risque, une rencontre ; si rencontre, deux tiers « rôdeurs chassés » (butin de 3 à 12 groschen par homme de la patrouille, au coffre, « butin_patrouille »), un tiers « embuscade » : une petite bande (effectif = hommes de la patrouille + 1, sorte selon le chemin) tranchée par la règle de la bataille, sans enceinte, avec les seuls hommes de la patrouille ; morts, blessés et moral comme pour une bataille. Sinon, « rien à signaler ». Un chemin parcouru sans embuscade fait baisser le risque de ce chemin d'un dixième pour une semaine (les rôdeurs se font rares) ; une embuscade le remonte.
- **Retour** : les hommes sont libérés, le compte rendu va au bandeau et au journal des patrouilles (vingt gardés).
- **Avance de guet** : une patrouille en cours sur `ronde_proche` ajoute une demi-heure d'avertissement aux bandes (lue par la bataille par `patrouilles.avance_de_guet`).
- **Entrée de la Gestion du camp** : `envoyer_patrouille` (chemin, hommes).
- **Le battement commun** : `Scriptorium.battre()` appelle, dans l'ordre, bataille, hommes, directeur, enceinte, atelier, patrouilles ; `Scriptorium.demarrer()` le lance toutes les trente secondes quand une partie est en cours (`jeu.partie_en_cours()`). Le poste d'essai n'a plus son propre battement.

## Ce qui est sauvegardé (case `patrouilles`, version 1)
`{ prochaine = 1, en_cours = { id, chemin, hommes, depart, retour, point, dernier_point_ordonne }, journal = {…}, risques = { [chemin] = { valeur, jusqu_a } } }`.

## Ce que le morceau demande au jeu (liaison)
`ordonner` (par les hommes), `partie_en_cours()`, `heure_du_jeu`, `journal`.

## À vérifier en jeu
- `partie_en_cours()` : l'appel qui dit qu'une partie est chargée (en attendant, vrai si `player` existe).
- Que les hommes suivent les points du chemin par l'ordre « marcher ».

## Essais au banc (`essais/lua/essai_patrouilles.lua`)
Chemins cohérents ; envoi et refus ; affectations et ordres par point ; retour sans rencontre ; rôdeurs et butin ; embuscade et pertes ; risque qui baisse et remonte ; avance de guet ; entrée de la Gestion ; battement commun ; relecture.

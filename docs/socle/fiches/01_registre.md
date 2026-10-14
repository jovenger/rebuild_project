# Fiche 01 — Le registre (sauvegarde des données du camp)

- Morceau : 1. Table : `Scriptorium.registre`. Fichier : `socle/pak/Scripts/scriptorium/registre.lua`.
- État : écrit et passé au banc (12 essais). En attente de l'essai en jeu, surtout pour le mécanisme de sauvegarde.

## Ce que le joueur voit
- Rien, en temps normal.
- « Le registre du camp a été remis à neuf. » si le contenu de la partie est illisible ou si une case est abîmée.
- Une montée de version se fait en silence (journal seulement).

## Règles
- **Un seul registre**, une enveloppe `{ format = 1, cases = { <nom> = { version, donnees } } }`, écrite dans la partie sous forme d'une seule chaîne.
- **Une case par morceau.** `declarer_case(nom, version, par_defaut, migrations)` ; `par_defaut` est une fonction qui rend les données d'une case neuve.
- **Lecture.** `lire(nom)` rend la table vivante ; le premier `lire` charge tout depuis la partie. Les morceaux modifient la table puis appellent `enregistrer()`.
- **Montée de version.** Si la case stockée est d'une version plus ancienne, les migrations `[v]` s'appliquent une par une, de `v` à `v+1`. Une migration manquante ou en échec remet la case à neuf.
- **Plus récent que le socle.** Une case stockée avec une version plus grande n'est pas devinée : remise à neuf, notée au journal.
- **Case abîmée.** Contenu mal formé ⇒ valeur par défaut, message au journal, mot au joueur.
- **Case déclarée après le chargement** (un morceau chargé tard) : servie tout de suite depuis le contenu lu.
- **Cases inconnues** du contenu lu (d'un socle plus récent, par exemple) : conservées telles quelles à l'écriture.
- **Sérialisation stable** : clés triées, mêmes données ⇒ même chaîne. Fonctions, clés booléennes, nombres impossibles et boucles sont refusés.
- **Lecture en bac à sable** : la chaîne est relue sans aucun accès aux globales du jeu.
- **`invalider()`** oublie ce qui est chargé : à appeler quand le joueur charge une autre partie.
- **`enregistrer()` avant toute lecture** charge d'abord : il n'écrase jamais la partie avec des valeurs par défaut.

## Rapport de `charger()`
`{ source = "vide" | "lu" | "illisible", chargees, neuves, migrees, abimees }`.

## Ce que le registre demande au jeu (liaison)
`lire_registre()` → chaîne ou nil ; `ecrire_registre(chaine)` ; `journal(texte)`.

## À vérifier en jeu
- **Le mécanisme de sauvegarde** : quel appel du moteur garde une chaîne dans la partie et la rend au chargement. En attendant, la liaison garde la chaîne en mémoire : elle ne survit pas à la fermeture du jeu.
- **Le moment du chargement** : l'appel du jeu qui dit « une partie vient d'être chargée », pour appeler `invalider()`.
- **La taille** : si le mécanisme limite la longueur, découper la chaîne en plusieurs morceaux.

## Essais au banc (`essais/lua/essai_registre.lua`)
Écrire puis relire ; registre vide ; contenu illisible ; bac à sable ; montée de version en deux pas ; montée manquante ou en échec ; version plus récente ; déclaration après chargement ; cases inconnues conservées ; enregistrer avant lecture ; sérialisation stable et refus ; déclarations invalides.

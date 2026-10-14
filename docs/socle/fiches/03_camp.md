# Fiche 03 — Le camp : tentes, lits, feux, sièges

- Morceau : 3. Table : `Scriptorium.camp`. Fichier : `socle/pak/Scripts/scriptorium/camp.lua`.
- État : écrit et passé au banc. En attente de l'essai en jeu (pose d'objets, modèles du jeu de base) et de la validation de la fiche par JoVenGer.

## Ce que le joueur voit
- Un camp dressé autour d'un feu : des sièges, des tentes avec leurs paillasses, la tente du Directeur avec son lit et le coffre du camp.
- Après un chargement, le camp est là, complet, qu'il y ait des hommes ou non.
- « Le camp est dressé. » à la fondation, « Le camp est levé. » quand on le démonte. Le redressement après chargement se fait en silence (journal seulement).

## Règles
- **Le plan est en données, pas dans le code.** `camp.plan` liste les emplacements : nom, sorte (`feu`, `siege`, `tente`, `lit`, `coffre`), position par rapport à l'ancre du camp (mètres : x à droite, y devant), cap (degrés, 0 = devant), niveau (1 à 3).
- **L'ancre.** `fonder(position, cap)` fixe l'ancre du camp (là où se tient Henry, dans le poste d'essai). Chaque emplacement est tourné du cap de l'ancre puis décalé de sa position. Fonder deux fois est refusé : il faut lever le camp d'abord.
- **Niveaux.** Le camp commence au niveau 1 (un feu, quatre sièges, la tente du Directeur, deux tentes, cinq lits, le coffre). `agrandir()` passe au niveau suivant et dresse les emplacements du nouveau niveau : plus de tentes, de lits et de sièges, pour une compagnie qui grossit. Le niveau 3 est le dernier.
- **Objets du jeu de base.** Chaque sorte renvoie à un modèle du jeu (`camp.modeles`), appelé par son chemin, jamais copié. Les chemins restent à confirmer en jeu.
- **Dresser.** Pour chaque emplacement du niveau courant qui n'est pas posé, le camp demande au jeu de poser l'objet et garde l'identifiant rendu. Un objet que le jeu refuse de poser est noté au journal ; le camp continue avec les autres.
- **Redresser.** Après un chargement, `redresser()` demande au jeu, pour chaque objet gardé, s'il existe encore ; les manquants sont reposés. Rien d'autre n'est touché. Cela marche sans aucun homme.
- **Lever.** `lever()` retire tous les objets du jeu et oublie l'ancre. Les tentes appartiennent à JoVenGer : le camp garde le propriétaire dans le registre.
- **Places.** Les lits et les sièges sont des places : `reserver(nom, qui)` et `liberer(nom)` ; `places_libres(sorte, pour)` les rend, en écartant celles réservées à quelqu'un d'autre (le lit du Directeur est réservé au Directeur). Les hommes (morceau 4) s'en servent. Une place déjà prise est refusée.
- **Positions.** `position_de(nom)` rend la position et le cap dans le monde d'un emplacement ; `point(x, y, cap)` fait de même pour un point quelconque du plan (postes de garde, lieux d'exercice).
- **Enregistrement.** Après fondation, agrandissement, redressement et levée.

## Sorts rendus
`fonder`, `agrandir`, `lever`, `reserver`, `liberer` rendent `true`, ou `false` et une raison : `deja_fonde`, `pas_fonde`, `niveau_maximal`, `place_inconnue`, `place_prise`, `place_libre`, `position_invalide`.

## Ce qui est sauvegardé (case `camp`, version 1)
`{ fonde, ancre = { x, y, z, cap }, niveau, proprietaire, objets = { [nom] = { identifiant } }, places = { [nom] = qui } }`.

## Ce que le camp demande au jeu (liaison)
`poser_objet(sorte, modele, position, cap, nom)` → identifiant ou nil ; `retirer_objet(identifiant)` ; `objet_existe(identifiant)` ; `position_du_joueur()` et `cap_du_joueur()` (pour le poste d'essai) ; `journal(texte)`.

## À vérifier en jeu
- L'appel qui pose un objet avec un modèle (`System.SpawnEntity` avec la classe `BasicEntity` et `object_Model`) et celui qui le retire (`System.RemoveEntity`).
- Les chemins des modèles du jeu de base pour la tente, la paillasse, le feu, le banc et le coffre (`camp.modeles`), à relever dans les paks du jeu.
- Que les objets posés sont bien gardés par la sauvegarde du jeu, ou qu'il faut les reposer à chaque chargement (`redresser` couvre les deux cas).
- Que le feu posé brûle, et que les hommes du jeu reconnaissent un lit et un siège posés ainsi (sinon, chercher les objets « intelligents » du jeu).

## Essais au banc (`essais/lua/essai_camp.lua`)
Géométrie (rotation et décalage) ; fondation et positions des objets ; double fondation refusée ; objet refusé par le jeu noté sans bloquer ; agrandissement par niveau et niveau maximal ; redressement ne reposant que les manquants ; levée ; places réservées et libérées ; écriture puis relecture ; plan cohérent (noms uniques, sortes connues, niveaux valides).

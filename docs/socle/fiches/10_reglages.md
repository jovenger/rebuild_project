# Fiche 10 — Les réglages par fichier

- Morceau : 10. Table : `Scriptorium.reglages`. Fichier : `socle/pak/Scripts/scriptorium/reglages.lua`.
- Vient de la règle de JoVenGer du 14/10 : les règles, les agissements et le comportement des hommes et du camp doivent pouvoir être modifiés par le programme Scriptorium. Pendant le chantier, le programme est mis à part : le socle a son propre transport, un fichier écrit sur le PC et relu en jeu, comme les ordres du poste.
- Choix de JoVenGer du 14/10 (questions à cocher) : le fichier change les chiffres **et la forme** (taille de l'enceinte) ; il est relu **dès qu'il change** ; il vaut pour **toutes les parties** ; une valeur fausse est **refusée seule**.
- État : écrit et passé au banc (essais `essai_reglages.lua`, et l'étape « 2 quater » de `tout_verifier.py` : outil, liaison, installateur). Limites validées par JoVenGer le 14/10 (voir « Limites »). Vu en jeu le 15/10 : lu au lancement, gardé par l'installateur, réglage changé en pleine partie avec son message, enceinte reposée à 25 m.

## Ce que le joueur voit
- Rien tant que le fichier ne change pas. Sans fichier, les valeurs validées par JoVenGer dans les fiches 02 à 09 s'appliquent.
- Quand le fichier change pendant une partie : « Réglages du camp mis à jour : » suivi de « 3 changé(s), 1 refusé(s) ». Le détail de chaque valeur, et la raison d'un refus, va au journal.
- Un fichier illisible pendant une partie : « Le fichier de réglages est illisible : rien n'a changé. »
- À l'entrée en partie et au lancement du jeu, les réglages sont appliqués en silence (journal seulement).

## Le fichier
- `Mods\scriptorium_socle\reglages.lua`, sur le PC, à côté du fichier d'ordres. Il ne contient que des données et ne voit rien du jeu :
  `return { hommes = { ration = 3 }, bandes = { brigands = { butin_par_tete = 20 } }, issues = { victoire = { blesses = 0.1 } } }`
- Écrit par l'outil `outils/regler.py` (et, à la bascule, par le programme Scriptorium). L'installateur le garde quand il réinstalle le socle.

## Règles
- **Le catalogue.** Le fichier est fait de sections ; chaque section désigne une table de valeurs d'un morceau :
  `bandeau` (`bandeau.reglages`), `coffre` (`coffre.reglages`), `hommes` (`hommes.reglages`), `soldes` (`hommes.roles`), `rangs` (`hommes.rangs`), `bataille` (`bataille.reglages`), `bandes` (`bataille.sortes`), `combattants` (`bataille.roles`), `issues` (`bataille.issues`), `prix` (`directeur.prix`), `agrandissement` (`directeur.agrandissement`), `enceinte` (`enceinte.reglages`), `atelier` (`atelier.reglages`), `recettes` (`atelier.recettes`), `soins` (`atelier.soins`), `patrouilles` (`patrouilles.reglages`), `chemins` (`patrouilles.chemins`), `discipline` (`discipline.reglages`), `fautes` (`discipline.fautes`).
- **Seuls des nombres qui existent déjà** se changent : une section, un nom ou une valeur inconnus sont refusés ; un texte (clé de message, rang « avant »…) ne se règle pas.
- **Les listes à nom** (`issues`, `fautes`) se désignent par le nom de l'entrée (`victoire`, `rixe`), jamais par leur place. Une liste sans nom (les points d'un chemin de patrouille) ne se règle pas.
- **Une valeur est refusée** (elle garde sa valeur d'avant, le reste s'applique) si :
  - ce n'est pas un nombre fini ;
  - elle n'a pas le signe de la valeur validée (une valeur validée positive ou nulle reste positive ou nulle ; une négative, comme une perte de réputation, reste négative ou nulle) ;
  - c'est une **part** (chance, risque, part des morts, des blessés, du butin, malus d'usure…) hors de 0 à 1 ;
  - c'est une **heure** (nom commençant par `heure_`) hors de 0 à 24 (24 exclu) ;
  - la valeur validée est **entière** et la nouvelle ne l'est pas (nombres d'hommes, prix, soldes, butin par tête, ingrédients, jours de soin, nombre de pans, heures…), sauf pour les **taux** : poids au combat, multiplicateurs de solde des rangs, seuils de rapport des issues, qui acceptent les décimales même quand leur valeur validée tombe rond ;
  - elle rend une paire `…_min` / `…_max` incohérente (le minimum au-dessus du maximum) : les deux sont refusées.
  Chaque section dit lesquelles de ses valeurs sont des parts et des taux (en données, dans le catalogue).
- **Les valeurs validées sont gardées.** Au chargement du socle, toutes les valeurs du catalogue sont relevées.
- **Le fichier ne touche qu'aux valeurs qu'il nomme** (corrigé le 20/10, vu sur une copie de la partie de JoVenGer : poser une seule valeur remettait tout le catalogue aux valeurs validées et effaçait six coupures posées en partie par Scriptorium). Une valeur retirée du fichier (ou un fichier effacé) reprend la valeur qu'elle avait avant que le fichier la pose, sauf si quelqu'un l'a changée depuis : elle est alors laissée. Une valeur refusée ne change rien.
- **Relu dès qu'il change.** Au lancement du jeu, à chaque entrée en partie, puis toutes les deux secondes en partie. Le contenu lu est mis sous une forme fixe (noms triés) et comparé au précédent : rien ne se passe s'il n'a pas changé. Un fichier illisible ne change rien : les valeurs en place restent.
- **La forme : l'enceinte.** Le rayon et le nombre de pans de l'enceinte se règlent. Avant de les accepter, l'enceinte vérifie (`enceinte.verifier_reglages`) : au moins trois pans ; le cercle fermé (d'un pan à l'autre moins que la longueur d'un pan, et les pans voisins atteignent la porte) ; le rayon au-delà de l'emprise du camp (tentes, feux, postes de garde, points d'exercice et de corvée), plus une marge de deux mètres. Sinon, le rayon et les pans du fichier sont refusés. Le plan de l'enceinte est refait après chaque application ; si l'enceinte est bâtie et que son plan a changé, elle est retirée et reposée aussitôt, en cours de partie comme à l'entrée en partie (un fichier changé pendant que le jeu était au menu).
- **Toutes les parties.** Rien n'est écrit dans le registre : le fichier vaut pour toute partie chargée.

## Limites (validées par JoVenGer le 14/10)
- Une valeur validée entière reste entière : par exemple, l'avance de guet des tours (1 heure) ne peut pas passer à 1,5 heure dans cette version.
- La forme réglable est celle de l'enceinte seulement : le plan du camp (tentes, lits, bancs), les postes de garde et les points des chemins de patrouille ne se règlent pas dans cette version.

## Bon à savoir
- Zéro est accepté là où la valeur validée est positive : c'est le choix de celui qui écrit le fichier (par exemple `hommes.semaines_max = 0` empêche toute embauche).
- Le bandeau ne redit pas un même message dans les trente secondes : deux changements du fichier coup sur coup ne donnent qu'un message ; le détail reste au journal.

## Sorts rendus
`relever_le_fichier(moment)` rend un compte rendu : `{ etat, changes, refuses }`, `etat` parmi `absent`, `inchange`, `illisible`, `applique`. `moment` : `lancement`, `entree` ou `en_cours`.

## Ce que le morceau demande au jeu (liaison)
`lire_reglages()` → la table du fichier et son chemin, `nil` sans fichier, ou `nil`, chemin, raison s'il est illisible (même lecture que le fichier d'ordres : `loadfile` dans un environnement vide) ; `minuterie` ; `journal`.

## Essais au banc (`essais/lua/essai_reglages.lua`)
Sans fichier, les valeurs validées ; une valeur posée puis retirée ; fichier effacé ; le fichier ne touche qu'aux valeurs qu'il nomme (les réglages de Scriptorium en partie restent) ; section, nom et texte inconnus ; listes à nom ; signe, parts, heures, entiers, paires min et max ; refus partiel ; fichier inchangé sans effet ; fichier illisible ; message au joueur en partie seulement ; enceinte : rayon et pans acceptés, cercle ouvert refusé, rayon dans le camp refusé, plan refait, reposée si bâtie ; relance à l'entrée en partie.

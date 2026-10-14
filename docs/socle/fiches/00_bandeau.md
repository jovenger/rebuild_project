# Fiche 00 — Le bandeau des messages

- Morceau : 0. Table : `Scriptorium.bandeau`. Fichier : `socle/pak/Scripts/scriptorium/bandeau.lua`.
- État : écrit et passé au banc (12 essais). En attente de l'essai en jeu.
- Demande de JoVenGer (14/10) : plus aucun texte jaune par-dessus l'image ; une bande noire en bas de l'écran, écrite proprement, au moment où la chose arrive.

## Ce que le joueur voit
- Un seul message à la fois, en bas de l'écran, pendant 3 à 8 secondes.
- Des phrases courtes en français d'époque. Jamais de nom de fonction, de valeur technique ni d'anglais.
- Pendant un dialogue ou une cinématique, le message attend.

## Règles
- **Une seule porte.** Tout message au joueur passe par `Scriptorium.bandeau.annoncer(cle, options)`. Aucun autre endroit du socle n'écrit à l'écran.
- **Clés, pas textes.** `cle` est une clé de texte de la forme `ui_scriptorium_<morceau>_<sujet>` ; le bandeau y ajoute `@` pour que le jeu traduise. Une clé mal formée est refusée et notée au journal, sans erreur.
- **Importances.** `alerte` (passe devant tout ce qui n'est pas une alerte), `nouvelle` (par défaut), `journal` (jamais à l'écran : journal et historique seulement).
- **Durée.** `options.duree`, sinon 5 s ; bornée entre 3 et 8 s.
- **Répétition.** Une même clé n'est pas redite avant 30 s : le message est repoussé (`repete`).
- **Regroupement.** `options.groupe` : si un message du même groupe attend déjà, on le grossit au lieu d'en ajouter un ; à l'affichage, s'il compte plus d'un et que `options.cle_plusieurs` est donnée, c'est cette clé qui s'affiche (« Plusieurs hommes sont arrivés au camp »).
- **Historique.** Les 20 derniers messages (clé, importance, nombre, moment, sort) se relisent avec `historique()`.
- **Battement.** `battre()` fait avancer le bandeau ; `demarrer()` le fait battre tout seul toutes les 500 ms par la minuterie du jeu ; `arreter()` l'arrête.
- **Comptes.** `comptes()` rend affichés, répétés, regroupés, refusés, journal.

## Sorts rendus par `annoncer`
`en_file`, `regroupe`, `repete`, `journal`, `refuse`.

## Réglages (`bandeau.reglages`)
`duree_par_defaut` 5, `duree_min` 3, `duree_max` 8, `delai_repetition` 30, `taille_historique` 20, `cadence_ms` 500.

## Ce qui est sauvegardé
Rien : le bandeau vit le temps de la session.

## Ce que le bandeau demande au jeu (liaison)
`maintenant()`, `afficher(texte, duree)`, `effacer()`, `dialogue_en_cours()`, `minuterie(ms, fonction)`, `journal(texte)`.

## À vérifier en jeu
- L'appel d'affichage (`Game.SendInfoText`) : sa place, son aspect, s'il peut donner la bande noire en bas. Sinon, chercher les sous-titres ou un élément d'écran.
- Comment savoir qu'un dialogue est en cours (la liaison répond « jamais » en attendant).
- D'où viennent les textes jaunes du mod d'Alex, pour s'assurer que le socle n'en produit aucun.

## Essais au banc (`essais/lua/essai_bandeau.lua`)
Affichage et effacement à la durée ; un seul à la fois, dans l'ordre ; alerte devant ; répétition ; regroupement avec et sans clé groupée ; attente pendant un dialogue ; durée bornée ; importance journal ; refus propres ; historique borné ; démarrage et arrêt par la minuterie.

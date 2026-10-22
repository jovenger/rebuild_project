# Plan d'attaque pour la reprise (écrit le 16/10/2026 vers 3 h, à la demande de JoVenGer)

Ordre de JoVenGer toujours valable : finir l'étape 1 (les comportements, dans l'ordre de la vie du camp), puis les
étapes 2 à 8 de sa note ; la bascule seulement sur son ordre. Méthode inchangée, pour chaque point : fiche, relecture
par le pair « kcd2 mods 3 », questions à cocher à JoVenGer, code, banc vert, essai en jeu, notes, commit, push.

## 0. Au démarrage (une demi-heure)
1. Nouvelle conversation, ou celle-ci compactée : coller `docs/socle/note_complete.md`.
2. Mettre le dépôt à jour, lancer `py -3.13 essais/tout_verifier.py` (« tout passe », 2 330 vérifications).
3. Relire : `CLAUDE.md`, `reprise.md` (section 6 ter), `plan_d_action.md` (règles du 16/10), la fiche 14 (tableau de
   l'écran noir), et côté Scriptorium, en lecture seule : `NOTE_POUR_LE_SOCLE.md`, `NOTE_METIERS.md` (parties 1 à 3),
   puis dans `CARTE_DES_REGLES.md` les dossiers de la vie du camp (horaires, repas, veillée, garde, sentinelles,
   rassemblement, suivre Henry).
4. Dire bonjour au pair, et à JoVenGer en quelques lignes où on en est.

## 1. Fiche 15 : la vie du camp (étape 1, suite)
Le principe de JoVenGer : **le geste vient du jeu, l'ordre vient de nous** ; Scriptorium décide de qui, quand et
combien, le socle fournit la mécanique ; nettement meilleur qu'Alex (aucun homme figé, rien de perdu au rechargement).
1. **Un seul arbitre des ordres** (défaut n° 3 d'Alex) : chaque homme a un ordre en cours et sa priorité (bataille,
   puis soins et bains, puis travail, puis loisir) ; une règle ne reprend pas un homme qu'une règle plus forte tient ;
   interrompre puis reprendre proprement (défaut n° 4). Au banc d'abord.
2. **Commencer, tenir, interrompre un geste à un poste** : le service que le guichet offrira à Scriptorium ; chaque
   poste borné (fin sur ordre ou au bout d'une durée en temps du jeu), jamais laissé tourner seul.
3. **Les comportements, un par un, chacun prouvé en jeu avant le suivant** :
   - a. **repas, veillée, sommeil** par les places du camp (s'asseoir sur les bancs, se coucher dans les paillasses :
     déjà acquis en V62 à V70 ; il reste à les jouer aux bonnes heures, par l'arbitre) ;
   - b. **monter la garde** au poste (poste du jeu `guard/so_guardspot`, `so_lookAround`), arme prête ;
   - c. **le rassemblement** (l'alerte) : tous au point de rassemblement ;
   - d. **suivre Henry** (modèle : le chien du jeu, `companion_playerDog`) ;
   - e. puis la veillée vivante avec les postes de repos du jeu (réparer ses flèches, dés, conteur, pugilat amical).
4. Questions probables à JoVenGer (en choix à cocher) : les priorités de l'arbitre, la durée bornée par défaut, ce que
   fait un homme sans ordre.

## 2. À chaque séance en jeu, sans exception
- Garde du disque (1 Go libre sur C, dans les outils) ; captures dans `D:\socle_captures\captures`.
- Prévenir le pair au début et à la fin ; toujours fermer par `fin_essai.ps1`.
- **L'écran noir** : ajouter la séance au tableau de la fiche 14 (normal ou noir) ; au moindre noir, lancer
  `scriptorium_essai_ecran_noir_voir` et lire les lignes « GUET » du journal.
- Ne poser personne dans un meuble du camp ni sur Henry.

## 3. Le gardien des hommes (idée validée n° 1, fin de l'étape 1)
Un contrôle régulier : chaque homme vit, obéit, n'est ni figé ni tombé (sous le sol, d'une tour) ; sinon il est remis
d'aplomb seul (réveil, replacement) et c'est noté au journal (défaut n° 2 d'Alex).

## 4. Ensuite, les étapes 2 à 8 de la note de JoVenGer (dans l'ordre, une à la fois)
- Étape 2 : nos personnages (apparences, le caractère sur l'âme, les factions ennemies des bandes, de premier niveau,
  étiquette `publicEnemy`, pour les raids et les missions).
- Étape 3 : le guichet pour Scriptorium (ne pas refaire la Gestion du camp ni les dialogues du Directeur).
- Les étapes suivantes de sa note (missions, embauche et métiers **à cheval**, quête, voix et icônes, essais restants),
  avec la note des métiers relue avant chaque fiche.

## 5. Points ouverts notés (pas avant leur étape)
- Un délit plus lourd, vu aussi par des gens du monde ; Henry qui frappe un de nos hommes (pugilat, duel).
- L'attaque à vue d'une bande qui voit le camp.
- Les six tenues du palier 3 exclues du tirage (piste `ClothingHidingGroup.xml`).
- Les postes d'Henry partagés avec le camp (fumoir, séchoir, prie-Dieu, table de tri : l'homme cède la place à Henry).

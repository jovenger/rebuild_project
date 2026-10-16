# Fiche 15 — La vie du camp : les gestes et l'arbitre des ordres

- Morceaux : `hommes` (l'activité de chaque homme, l'arbitre), `liaison` (l'ordre donné au cerveau), cerveau à nous
  (`AI/scriptorium/`, fiche 12), `camp` (les places).
- But (étape 1 de la note de JoVenGer, fin ; règle du 16/10) : **le socle fait la mécanique, Scriptorium décide** ; le
  geste vient du jeu, l'ordre vient de nous ; nettement meilleur qu'Alex : aucun homme figé, rien de perdu au
  rechargement, tout vu en jeu.
- État : **validée par JoVenGer le 16/10/2026** (questions à cocher, après relecture par la conversation Scriptorium) :
  le socle pose un homme d'un coup dans les quatre cas seulement (homme bloqué, archers des tours, suivre Henry au-delà
  de 60 m, retours au camp), toujours hors d'un meuble et hors de la vue d'Henry si possible (1) ; l'ordre des
  priorités proposé (2) ; la journée du socle pour l'homme qu'aucune règle ne tient (3) ; une tâche sans fin s'arrête au
  changement de tranche (4).

## Le constat (relu dans le code du socle, 16/10)
- La vie du camp **téléporte** encore : `hommes.battre` calcule l'activité (`hommes.activite_de`) et `liaison.ordonner`
  pose l'homme à sa place (`SetWorldPos`) s'il en est à plus de 2 m. Aucun geste.
- Les gestes prouvés en jeu ne servent qu'aux commandes d'essai : marcher à un point (ordre 9, V55), s'asseoir et se
  coucher sur une place du camp (ordres 10 et 11, `liaison.ordonner_sur_la_place`, V60 à V70), attaquer (ordre 8, V54).
- Au réveil, chaque homme reçoit de nouveau son ordre, donc **est téléporté** vers sa place (banc, lit) s'il en est à
  plus de 2 m (V72 d et e : positions identiques après rechargement, quand il y était déjà). Un homme posé dans un
  meuble, c'est l'hypothèse de l'écran noir (fiche 14).
- **Une preuve à l'image** : en V72 c, trois hommes à l'exercice étaient au même point au dixième de mètre près. C'est la
  signature d'une téléportation : des hommes qui marchent se poussent.
- L'ordre de priorité existe sans être dit : une affectation (bataille, patrouille, punition) passe devant la blessure
  (repos), puis la garde, puis la journée. Aucune marque « occupé », ni interruption puis reprise.
- L'affectation a trois appelants : `bataille` (rang de bataille), `discipline` (corvée de punition, 24 h) et
  `patrouilles` (la patrouille). Une nouvelle affectation **écrase** la précédente sans regarder sa force : une punition
  pourrait remplacer une bataille.

## Ce que Scriptorium attend de la mécanique (15 fiches `LISEZMOI.md` relues, 16/10)
Relu par un agent de recherche, sans aucun code : `journee_du_camp`, `nuit_du_camp`, `repas_du_camp`, `repas_a_table`,
`besoins_des_hommes`, `repos_des_fatigues`, `jours_de_repos`, `assises_des_feux`, `en_garde_du_camp`,
`sentinelles_du_camp`, `rassemblement_sans_retard`, `alerte_du_camp`, `entrainement_du_service`,
`volonte_de_s_entrainer`, `lits_des_tentes`, et `directeur_en_route` (suivre Henry).
1. **Rompre une pose** (assis, couché, à la tâche) : « debout d'abord », puis l'ordre (`en_garde_du_camp` : un homme
   sorti de sa routine se figeait ; montrer le poste trop tôt le faisait glisser).
2. **Faire marcher ou courir** vers un point ou une cible qui bouge, et **poser l'homme sur place en secours** s'il est
   bloqué (`rassemblement_sans_retard` : moins de 1 m de progrès en 30 s ; un homme était passé sous la carte).
3. **Interrompre n'importe quelle tâche, puis rendre la précédente** (rassemblement, alerte).
4. **Asseoir sur un siège désigné** (banc, bûche, table posée par JoVenGer), **coucher dans un lit désigné** la nuit,
   faire somnoler sur un banc le jour.
5. **Marquer un homme « occupé » par une règle**, et que les autres règles le respectent (dormeur, attablé, en duel).
6. Mettre un homme dans la ronde ou l'en sortir (quarts qui tournent) ; poster face à l'ennemi, arme tirée.
7. Suivre Henry (le Directeur d'abord, la troupe en colonne ; réapparaître derrière lui au-delà de 60 m).
8. Lire l'état de chacun : présent, assis, couché, au travail, distance à Henry.
- **Qui l'emporte** : l'attaque sur tout loisir, repas et sommeil (le dormeur se relève) ; le rassemblement sur toute
  tâche ; l'urgence sur le jour de repos ; le Directeur n'est jamais déplacé pendant un dialogue ; un homme marqué
  « occupé » n'est pas repris pour un loisir.

## Remarques de la conversation Scriptorium (16/10)
- **Les cas où Scriptorium pose déjà un homme d'un coup** (liste fermée, question 1) : le secours (moins de 1 m de
  progrès en 30 s, `rassemblement_sans_retard`) ; les archers des tours de guet, posés sur la plateforme et tenus là,
  faute de chemin pour monter (`tours_de_guet`, prouvé le 12/10) ; suivre Henry au-delà de 60 m (`directeur_en_route`) ;
  le retour d'une sortie, hors de vue d'Henry ; un homme pas rentré au camp en 4 min (`metiers_du_camp`). Deux
  garde-fous toujours : **jamais dans un meuble**, et **hors de la vue d'Henry** si possible.
- **Trois règles de JoVenGer qui touchent l'arbitre** : les compagnons nommés ne montent jamais la garde de nuit, ils
  dorment dans leur tente (12/10) ; un poste qu'Henry veut prendre lui est cédé tout de suite (16/10) ; un homme n'est
  jamais retiré du monde (`service_en_sortie`), seuls les gens du service peuvent l'être une fois hors de vue.
- **L'homme qu'aucune règle ne tient** : la journée du socle par défaut ; à la bascule, c'est la journée de Scriptorium
  (`journee_du_camp`, `nuit_du_camp`) qui la remplace, et celle du socle est coupée par son interrupteur (tableau des
  doublons de l'étape 3).
- **Suivre Henry (V73 f)** : l'idée validée n° 3 (voyage rapide, Henry à cheval, villes et intérieurs, changement de
  carte) et la règle du 16/10 (sorties à cheval) : si Henry monte, l'escorte le suit à cheval. Question à ce pas-là.
- **À chaque séance de V73** : le décompte de l'écran noir (fiche 14). Si la fin de la téléportation au réveil le fait
  tomber à zéro, c'est la preuve de l'hypothèse.
- **Principe transmis (« debout d'abord », mécanisme du jeu seulement)** : une posture est tenue par le nœud
  `StanceElement` (objet, `stance` « sitting » ou « lying ») qui entoure la suite de l'arbre ; tant qu'il tourne, l'homme
  reste assis ; quand il se termine (suite finie, ou comportement interrompu par un plus prioritaire), **le jeu joue
  lui-même le geste de se lever**. On ne lève donc jamais un homme en le déplaçant : on fait finir le comportement qui
  tient la posture. Pour V73 a : vérifier que l'ordre 9 interrompt le comportement de l'ordre 10 (priorités de la
  fiche 12 : 100 contre 160, `IgnorePriorityOnPreviousInterrupt`) ; sinon, une priorité plus haute. Lire la posture :
  le nœud `StanceCheck`. Gestes sur place sans objet (manger debout, s'étirer, regarder autour) : le nœud
  `UnstanceElement`, employé par 70 arbres du jeu (`Scripts.pak`, `AI/…`), pour les loisirs debout. La monte est aussi
  une posture (`stance` « horse », 57 arbres du jeu ; à lire en premier pour V73 f : `AI/move/moveOnHorse.xml`,
  `AI/autotest/horse/test_so_horseAction.xml`, `AI/player/scheduler/playerAction_horse.xml`,
  `AI/npc/basic/switch/handleAwareness_playerCompanion.xml`).

## Comment ce serait fait (un pas à la fois, chacun vu en jeu avant le suivant)
1. **V73 a — les gestes à la place de la téléportation.** `liaison.ordonner` traduit l'activité en geste : une place du
   camp (siège, lit) → s'asseoir ou se coucher (ordres 10, 11) ; un point (exercice, corvée, feu, poste de garde) →
   marcher jusqu'au point (ordre 9). **La téléportation ne reste qu'en secours** (question 1) : l'homme ne s'est pas
   rapproché d'au moins 1 m en 30 s ; alors il est posé sur une place libre (fiche 04 : jamais deux personnages à moins
   d'un mètre), à l'**abord** de son but, jamais sur un meuble (`camp.abord_de` : une place s'aborde du côté opposé au
   centre du camp, un autre meuble devant lui, à `camp.reglages.ecart_d_abord` = 2,4 m), deux fois au plus par ordre,
   puis il est laissé là et c'est noté au journal (le gardien des hommes reprendra ce cas). Valeurs réglables
   (`hommes.reglages` : `secours_delai_s`, `secours_progres_m`, `secours_arrivee_m`, `secours_max`). L'écart restant
   jusqu'au but, pour mesurer son progrès, est gardé **en mémoire**, pas au registre (limite de 65 535 octets ; perdu au
   rechargement, il ne coûte rien). Les trois autres cas accordés (archers des tours, suivre Henry, retours au camp)
   viendront à leur pas.
   **Le Directeur aussi** : son lit se prend par l'objet du jeu ; le coffre et le feu s'abordent à l'écart (avant, à la
   veillée, il était posé dans le feu).
   L'essai V73 a contient forcément le pas 3 : à chaque changement de tranche (repas → exercice, veillée → sommeil), un
   homme assis par l'ordre 10 reçoit l'ordre 9. L'essai s'en sert : embaucher juste avant un changement de tranche, ou
   le forcer par une affectation, et regarder si l'homme se lève puis part.
2. **V73 b — l'arbitre des ordres.** Chaque homme est « tenu » par une règle, avec sa priorité (question 2). Services
   pour le guichet : imposer une activité (règle, priorité, lieu ou point, fin), la libérer, lire qui tient l'homme.
   Une règle plus faible ne reprend pas un homme tenu par une plus forte ; quand la plus forte le libère, l'homme
   reprend ce que dit la règle d'en dessous, au battement suivant. L'actuelle affectation devient une règle de
   l'arbitre ; ses trois appelants (bataille, discipline, patrouilles) gardent leurs fonctions, avec leur priorité.
   La journée du socle reste la règle la plus faible, par défaut, jusqu'à ce que Scriptorium la coupe (question 3).
   **Chaque geste est borné** (note des métiers) : une fin donnée ; sans fin, la borne par défaut (question 4).
3. **V73 c — rompre une pose** : un homme assis ou couché qui reçoit un ordre plus fort se lève d'abord, puis part.
   C'est la mesure attendue dès V73 a : l'ordre 9 donné à un homme assis le fait-il se lever, ou faut-il un ordre
   « debout » à nous ? Si un ordre à nous est nécessaire, il devient ce pas-là.
4. **V73 d — monter la garde** au poste (marcher, puis rester tourné vers l'extérieur ; arme prête ; poste du jeu
   `guard/so_guardspot` plus tard, note des métiers).
5. **V73 e — le rassemblement** : interrompre toute tâche, courir au point, secours au bout de 30 s.
6. **V73 f — suivre Henry** (modèle : le chien du jeu ; recherches « Réutiliser avant de créer » à ce pas-là).

## Règles en données (catalogue de `reglages.lua`)
- `hommes.reglages` : `secours_delai_s` (30), `secours_progres_m` (1), `secours_arrivee_m` (2), `secours_max` (2) ;
  `camp.reglages.ecart_d_abord` (2,4 m).
- Une table nouvelle `hommes.priorites` (nom de règle → rang), dans le catalogue.

## Essais au banc (`essais/lua/essai_hommes.lua`)
- Une activité de siège donne l'ordre 10 sur la bonne place ; de lit, l'ordre 11 ; de point, l'ordre 9 avec le point.
- Le secours ne pose l'homme qu'après le délai sans progrès, et sur une place libre.
- L'arbitre : une règle plus faible ne reprend pas un homme tenu ; à la libération, la règle d'en dessous reprend.

## Questions à JoVenGer (après relecture par la conversation Scriptorium)
1. **Quand le socle peut-il encore poser un homme d'un coup (téléportation) ?** (a) seulement en secours : l'homme ne
   s'est pas rapproché d'au moins 1 m en 30 s, ou il est à plus de 150 m (Recommandé : `rassemblement_sans_retard`) ;
   (b) jamais ; (c) aussi au réveil, pour remettre chacun à sa place.
2. **L'ordre des priorités de l'arbitre** : (a) bataille, puis rassemblement, puis soins et bains, puis garde et ronde,
   puis travail, puis repas et sommeil, puis loisir (Recommandé : l'ordre de la note des métiers, avec le rassemblement
   de `rassemblement_sans_retard` et la garde) ; (b) le même, mais la garde avant les soins et bains ; (c) un autre
   ordre, à dire.
3. **Un homme qu'aucune règle de Scriptorium ne tient** : (a) il suit la journée du socle (repas, exercice, corvée,
   veillée, sommeil), la règle la plus faible (Recommandé) ; (b) il reste où il est, debout ; (c) il va s'asseoir au feu.
4. **La borne d'un geste sans fin donnée** : (a) jusqu'au changement de tranche de la journée (Recommandé) ; (b) une durée
   réglable, par exemple une heure de jeu ; (c) refusé : Scriptorium doit toujours donner une fin.

## Sources
- Socle : `hommes.lua` (`battre`, `activite_de`, `affecter`), `liaison.lua` (`ordonner`, `ordonner_sur_la_place`),
  `AI/scriptorium/essai_ordres.xml` (ordres 8 à 11), `comportements.xml`.
- Scriptorium (lecture seule) : `NOTE_POUR_LE_SOCLE.md` (étape 1), `NOTE_METIERS.md` (parties 1 à 3),
  `CARTE_DES_REGLES.md` et les 16 `LISEZMOI.md` ci-dessus.

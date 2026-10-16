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
   **Garde de l'arbitre (remarque de la conversation Scriptorium, 16/10)** : depuis V73 c, un ordre du socle remplace
   aussi une interruption du jeu plus prioritaire (l'attaque, à 160). Avant tout ordre qui n'est pas de bataille, le
   socle vérifie donc que l'homme n'est pas en combat (`soul:HasScriptContext("crime_interruptAttack")`, ou l'état de
   combat du jeu) ; sinon il attend le battement suivant. À mesurer : un homme qui se bat n'est jamais repris par un
   ordre de routine ; le combat fini, il reprend sa journée.
3. **V73 c — rompre une pose** : un homme assis ou couché qui reçoit un ordre plus fort se lève d'abord, puis part.
   C'est la mesure attendue dès V73 a : l'ordre 9 donné à un homme assis le fait-il se lever, ou faut-il un ordre
   « debout » à nous ? Si un ordre à nous est nécessaire, il devient ce pas-là.
4. **V73 d — monter la garde** au poste (marcher, puis rester tourné vers l'extérieur ; arme prête ; poste du jeu
   `guard/so_guardspot` plus tard, note des métiers).
5. **V73 e — le rassemblement** : interrompre toute tâche, courir au point, secours au bout de 30 s.
6. **V73 f — suivre Henry** (modèle : le chien du jeu ; recherches « Réutiliser avant de créer » à ce pas-là).

## Mesuré en V73 a (16/10)
- **Acquis** : les ordres de la vie du camp partent en gestes ; au repas, les hommes marchent jusqu'à leur banc et s'y
  assoient (vu) ; debout, ils marchent vers leur but.
- **Pas encore** : un homme assis ne se lève pas à l'ordre de marcher (l'interruption « aller », à la même priorité 100,
  ne remplace pas celle qui le tient assis). C'est V73 c : nos ordres 9, 10 et 11 posent leur interruption avec
  `IgnorePriorityOnPreviousInterrupt="true"` (forme employée par le jeu, `AI/world/sa_deterrentArea.xml`) : le dernier
  ordre remplace le précédent, le comportement qui tient la posture se termine, et le jeu joue le geste de se lever
  (principe transmis par la conversation Scriptorium). L'arbitre en Lua décide déjà quel ordre a le droit de partir.
- **Le secours** : le seuil d'arrivée doit dépasser la tolérance de la marche du jeu (2 ± 0,5 m) : 3 m. Et il ne doit
  jamais viser un homme assis ou couché : poser d'un coup un homme assis ne le déplace pas, il se lève à son banc.

## Mesuré en V73 c (16/10) : la levée, trois essais, arrêt
- (1) Remplacement d'interruption seul : 1 homme sur 3 se lève (celui qui venait de s'asseoir). (2) Les contextes du
  villageois du jeu autour du « use » : aucun. (3) En plus, la fin du dedans (compteur d'ordres et garde) : aucun, à 30 s,
  90 s et 2 min 30 d'assise. L'assise marche à chaque fois.
- **Hypothèses restantes** : (a) le remplacement d'interruption (« true ») tue notre comportement **avant** que sa garde
  voie le changement, et le « use » du jeu, lancé par `CallBehavior`, continue seul et tient l'homme assis ; essai : ordres
  remis à « false » (le nouvel ordre attend), contextes et garde gardés, pour que la garde termine l'assise du dedans ;
  (b) le compteur d'ordres n'est pas augmenté en jeu (la forme `pcall(XGenAIModule.GetBrainVariable, …)` n'est pas
  vérifiée) : à lire au poste dans le même essai ; (c) la façon d'Alex (sa propre posture, `StanceElement`, et non le
  « use » du jeu) : à demander au pair dans le détail (V60, V61 : notre `StanceElement` hébergé ailleurs n'asseyait pas).
- **En attente de JoVenGer** (règle anti-boucle). Il a choisi d'attendre la réponse du pair (16/10).
- **Le principe transmis par la conversation Scriptorium (16/10, mécanisme seulement)** :
  - une **seule interruption longue** pour toute la vie du camp, lancée une fois par le switch (priorité haute, elle
    remplace l'interruption en cours, urgence « Fast », un drapeau empêche de la relancer à chaque tour), relancée
    seulement au changement d'état (vie du camp, suivre Henry) ; **pas une interruption par ordre** ;
  - quand l'ordre change, **c'est la même interruption qui continue** : sous la posture, une boucle bornée de courtes
    attentes (environ 500 ms) relit les variables de cerveau posées par le Lua ; au changement, elle échoue, la posture
    se défait (le jeu joue la sortie), et la boucle principale prend la nouvelle activité ; personne ne tue le
    comportement de l'extérieur ;
  - la posture est tenue par **notre propre `StanceElement`**, avec, dedans, l'attente que la mise en posture soit finie
    (`WaitAction`) puis un geste assis du jeu (`UnstanceElement`) dont le `locationObject` est le siège lui-même (sans
    lui, l'homme reste debout sur le siège) : ce qui manquait en V60 et V61.
  - L'hypothèse (a) est donc très probablement la bonne : en remplaçant l'interruption à chaque ordre, on tue notre
    comportement de l'extérieur, et le « use » lancé par `CallBehavior` continue seul.
  - Deux voies, une à la fois : (a) l'essai court (« false », contextes et garde gardés, compteur lu au journal) ; (b) le
    modèle durable : un seul comportement « vie du camp », posture tenue par notre `StanceElement` et `UnstanceElement`
    sur le siège (changement d'architecture de la fiche 12).
- **Choix de JoVenGer (16/10)** : « Court, puis durable » : l'essai court d'abord, puis le modèle durable avec sa fiche
  et ses questions.

## Essai court V73 c 4 : grille de lecture écrite avant la séance
- **Ce qui change** (un seul essai) : ordres 9, 10 et 11 remis à `IgnorePriorityOnPreviousInterrupt="false"` (le 8 ne
  bouge pas) ; contextes et garde gardés. Au journal : la ligne de chaque ordre dit le compteur lu puis écrit (ou
  « illisible », ou « non écrit ») ; `hommes_voir` dit, par homme, l'écart au siège donné, les ordres donnés (compteur),
  reçus (`scriptorium_essai_rejoint`, qui n'avance que si l'`AddInterrupt` est accepté), l'ordre en attente, les
  arrivées de la marche et les deux contextes de la posture.
- **Déroulé** : comme V73 c 3 (secours coupé, trois assis, levés un par un à environ 30 s, 90 s et 3 min, positions et
  captures, secours remis, `fin_essai`).
- **Lecture, une suite par issue** :
  1. compteur figé ou illisible : hypothèse (b) ; corriger la lecture ou l'écriture du compteur, pas l'arbre ;
  2. compteur qui bouge, « reçus » qui avance, l'homme se lève et marche : (a) confirmée, et l'ordre de même priorité est
     mis en file ; passer au modèle durable ;
  3. compteur qui bouge, « reçus » qui n'avance pas, l'homme se lève sans marcher : (a) confirmée pour la mort du
     dehors, mais l'interruption de même priorité est jetée ; le modèle durable (une seule interruption) la contourne ;
  4. compteur qui bouge et personne ne se lève : la fin du `Parallel` ne défait pas la posture du « use » ; hypothèse
     (c) ; droit au modèle durable avec notre `StanceElement` et `UnstanceElement`.
- Un contexte de la posture encore posé après la levée dirait que l'abandon du « use » ne fait pas le ménage.
- Un ordre venu du battement (changement d'heure) augmente aussi le compteur : la ligne de l'ordre le montre au journal.

## Mesuré en V73 c 4 (16/10) : l'essai court
- **Le compteur** : lu puis écrit à chaque ordre (« compteur 1 → 2 » à l'assise, « 2 → 3 » à la levée) : l'hypothèse
  (b) est écartée.
- **Les ordres** : chacun est reçu (`scriptorium_essai_rejoint` avance) ; avec « false », l'ordre de même priorité est
  mis en file, pas jeté.
- **La levée** : les contextes de la posture tombent à 0 et l'homme se lève : Mikuláš est debout et en marche 5 s après
  l'ordre, Ondřej 7 s après. La garde termine donc l'assise du dedans, et le jeu joue le geste de se lever : c'est
  l'issue 2 de la grille, l'hypothèse (a) est confirmée.
- **Ce qui suit, nouveau** : Jan et Mikuláš arrivent à leur place d'exercice ; Ondřej s'arrête à 2,1 m de son siège, et
  sa marche n'arrive pas. Puis **chacun retourne s'asseoir sur son propre siège, sans nous** (le compteur « assis »
  ne bouge pas), moins de 15 s après la fin de notre marche. Notre interruption finie, le jeu reprend la main : sa
  propre vie, rendue par la fin du contexte `activity_disableSchedulerLooping`, ou le lien laissé entre l'homme et le
  siège par le « use » du jeu, le ramène à ce siège.
- **Suite, selon la grille** : le modèle durable. Une seule interruption longue, qui ne finit jamais tant que l'homme
  vit au camp, ne laisse jamais la main au jeu entre deux activités ; entre deux ordres, l'homme attend à sa place
  dans notre comportement. À vérifier aussi en V73 c 5 : qu'aucun lien ne reste entre l'homme et le siège après la
  levée.

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

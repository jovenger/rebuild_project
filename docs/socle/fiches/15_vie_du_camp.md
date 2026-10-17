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
- **V73 b revu le 16/10** pour le comportement long (section « V73 b » ci-dessous) : relu par le pair, **validé par
  JoVenGer le jour même** (trois questions à cocher, réponses a, a, a).
- **V73 d écrit le 16/10** (section « V73 d » ci-dessous) : relu par le pair, **validé par JoVenGer le jour même**
  (trois questions à cocher, réponses a, a, a) ; V73 d 1 fait, au banc.

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

## La levée, résolue (16/10, V73 c 5 à V73 c 8 ; détail dans la fiche 12)
- Un seul comportement long, la « vie du camp » ; notre propre posture pour s'asseoir et se coucher ; la tenue échoue au
  changement d'ordre ; les marches changent l'état du personnage (`changeNPCState="true"`).
- Vu en jeu (V73 c 8) : à midi, repas assis face au feu ; à 13 h, levés et partis à la corvée, debout plus de 2 min.
- Ouvert : un homme repris assis d'une sauvegarde, dont le but est tout près, reste à demi assis ; un lit du plan placé
  hors de sa tente.

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

## V73 b — l'arbitre des ordres, revu pour le comportement long (16/10, en relecture par le pair)
- **Pourquoi revoir** : le pas 2 ci-dessus date d'avant le comportement long. Depuis V73 c, un ordre n'est plus une
  interruption : le Lua écrit l'activité et augmente le compteur, le comportement long la joue (fiche 12). Deux suites :
  - la « garde de l'arbitre » du pas 2 (aucun ordre de routine à un homme en combat) n'a plus d'objet sous cette forme :
    une activité écrite pendant un combat ne fait rien tant que le comportement long est arrêté, et il la lit à sa
    relance, le combat fini ;
  - il en reste une, nouvelle : le **secours** ne doit pas prendre un homme qui se bat ou qui parle pour un homme bloqué.

### Ce que dit la carte des règles (relue le 16/10, lecture seule, par un agent de recherche)
- Aucun classement d'ensemble ; des énoncés partiels, tous d'accord avec l'ordre validé (réponse 2 a) :
  - l'attaque du camp passe avant tout (`permissions_de_sortie`) ; la nuit, les dormeurs ne se relèvent que pour une
    attaque ou une alerte (`chef_du_camp`) ;
  - assis ou couchés, tous se lèvent à l'attaque et se mettent en garde (`en_garde_du_camp`) ; un homme assis au moment
    de l'alerte se lève d'abord, puis court à son poste (`degel_des_hommes`) ;
  - le rassemblement arrête toute tâche : entraînement, repas, assise, tir, bain (`rassemblement_sans_retard`) ;
  - le blessé va au bain même pendant le travail (`soins_du_service`), puis il peut reprendre son activité
    (`soins_apres_bataille`, le seul « reprendre » de la carte).
- **Rien dans la carte** sur : un homme « occupé » que les autres règles respectent ; Henry qui veut un poste occupé
  (au plus près : `objets_d_henry`, ce qui est assigné à Henry, il doit pouvoir vraiment l'utiliser) ; les compagnons
  et la garde de nuit (règle de JoVenGer du 12/10, transmise par le pair) ; une durée ou une borne d'interruption ; une
  file d'attente. C'est la mécanique que le socle doit fournir ; Scriptorium décidera par elle.

### Le constat (code relu le 16/10)
- **Une seule affectation par homme** (`f.affectation`) : la dernière écrase la précédente sans regarder sa force (une
  punition remplacerait une bataille), et la libération rend l'homme à sa journée : un patrouilleur appelé à la bataille
  perd sa patrouille pour de bon. Deux lectures en dépendent : `hommes.gardes` (« valides » : sans affectation) et
  `patrouilles.disponibles` (`affectation_de == nil`).
- **Le secours compte un homme qui se bat comme bloqué** : il ne se rapproche pas du but de sa tranche ; au bout de
  30 s, il serait posé d'un coup hors de son combat.
- Les ordres partent au battement des hommes, toutes les 30 s (`Scriptorium.cadence_du_battement_ms`) : trop lent pour
  un homme qui doit s'arrêter tout de suite (règle de JoVenGer du 16/10 : il cède le poste à Henry).
- **La relance n'a pas de plafond** (proposition du pair après V73 c 10 : la tempête de 117 lancements montre que le
  pouls peut s'emballer pour une autre cause qu'une valeur).
- **L'attaque** : l'ordre 8 appelle `callInterrupt_attack` (160, priorité ignorée), qui remplace notre comportement long.
  Lu dans le jeu (`AI/npc/basic/switch/interrupt_attack.xml`, lecture seule) : avant le combat (`CombatAction`), un
  personnage debout finit son geste et s'arrête ; un personnage qui n'est pas debout passe tout droit (commentaire du
  jeu : il ne peut pas bouger sans être debout). Le jeu ne le lève donc pas lui-même : il compte sur la fin de la posture
  du comportement remplacé (chez nous, notre `StanceElement`).
- Le Directeur n'a pas d'affectation : hors de V73 b.
- Recherche d'un exemple existant (règle du 15/10) : deux recherches (web, dépôts de code) ; rien de propre à KCD2. Le
  schéma général, une file de tâches par personnage rangée par priorité, est celui de
  `gamedev.stackexchange.com/questions/96433` ; le reste vient des arbres du jeu.

### Comment ce serait fait : trois pas, chacun vu en jeu avant le suivant
**V73 b 1 — Mesure : l'attaque sur un homme assis, puis le retour après le combat.**
- Code, petit, aucun arbre touché :
  - une commande d'essai : l'homme suivant attaque le brigand du jeu **sans être déplacé** (`poste.essai_hommes_attaque`,
    sur le modèle de `essai_hommes_lever`) ;
  - `voir_sur_la_place` dit en plus les deux contextes « occupé » (combat `crime_interruptAttack`, conversation
    `speech_switchDialogRunning`) et le compteur des combats ;
  - **le secours se fige** pour un homme en combat ou en conversation (`liaison.contextes_de`) : son compte du temps
    sans progrès repart de zéro ; essai au banc.
- Séance (`playline3`) : les hommes assis (`essai_hommes_asseoir`), secours coupé ; le brigand léger posé hors du camp,
  10 m derrière Henry sur la ligne du centre du camp (`essai_brigand_leger_hors_du_camp` : le camp est fondé devant
  Henry, et 8 m devant lui, le brigand naîtrait dans le camp, peut-être dans un meuble) ; l'attaque ; une lecture toutes
  les 5 s environ.
- **Grille, écrite avant la séance** :
  1. il se lève et se bat : combats + 1, contexte de combat à 1, pouls figé, **aucune relance pendant le combat** (la
     lecture « en combat », jamais vue en jeu) → bon ;
  2. le combat fini : une relance (deux au plus si la suite du combat du jeu dure plus d'une minute), le pouls repart, et
     l'homme reprend sa tranche (rassis, si c'est l'heure du repas) → rien à ajouter ; ou le pouls repart sans relance
     (le jeu a rendu notre comportement) → rien à ajouter, c'est noté ;
  3. il reste assis, ou se bat assis, ou ne se bat pas → **dégager d'abord** (principe d'Alex, transmis par le pair) :
     l'activité « attendre » et le compteur font finir la posture du dedans, et le switch **retient** l'attaque tant que
     le comportement long dit l'homme encore en posture, au plus quelques secondes (environ 4 s, réglable) ; passé ce
     délai, l'attaque part quand même. L'horloge de la retenue ne tourne **que lorsqu'une attaque attend vraiment
     l'homme** (chez Alex, une première version la faisait tourner pour tout homme assis : 341 lignes au journal en une
     séance, et la retenue était épuisée quand un vrai combat arrivait). Un seul changement, V73 b 1 bis ;
  4. aucune relance plus d'une minute après la fin du combat (contexte resté à 1) → lire les contextes, chercher un
     autre signe de la fin du combat ; un seul changement ;
  5. à part : le siège se dit libre après la levée (`IsStanceAvailable`).
- Décompte de l'écran noir (fiche 14).

**V73 b 2 — Le plafond de relances (proposition du pair).**
- **Dans le switch**, là où se fait la relance : le battement de 30 s est trop lent pour « au plus 3 par minute » (avec
  les valeurs par défaut, 5 relances pourraient partir avant qu'il ne voie rien).
- Deux variables locales : les lancements dans la fenêtre, et le temps écoulé dans la fenêtre (chaque tour y ajoute sa
  durée) ; la fenêtre finie, les deux reviennent à zéro. Un lancement n'est permis que sous le plafond ; chaque
  lancement compte, le premier aussi. Un lancement refusé par le plafond augmente, une fois par fenêtre, le compteur de
  cerveau `scriptorium_vie_arrets`.
- Valeurs en données (`hommes.cerveau`, défauts recopiés dans l'arbre et comparés au banc) : `relances_max` (3),
  `relances_fenetre_ms` (60 000).
- **La ligne au journal, par le Lua** : à chaque battement, le compteur des arrêts de chaque homme et du Directeur est
  relu (une fonction de la liaison qui lit des variables de cerveau) ; une ligne par hausse : « Hommes : pouls :
  relances arrêtées pour « X » ». En mémoire seulement, remise à zéro au chargement comme le cerveau.
- **Au banc** : contrôles statiques (`tout_verifier.py` : le plafond garde les deux chemins de relance, ses valeurs sont
  lues avec leur défaut) ; essai Lua de la ligne au journal (une par hausse, aucune sinon). Le « 3 relances, puis
  arrêt » se mesure **en jeu** : le banc ne joue pas les arbres. Accepté par le pair (16/10) ; un lecteur de nos arbres
  au banc reste une idée pour plus tard, si les arbres grossissent (un outil de plus à entretenir).
- En jeu : non-régression (la vie du camp, un lancement par homme) ; puis une tempête provoquée par fichier
  (`cerveau.garde_ms` très long, `relance_tours` et `file_tours` à 1) : au plus 3 lancements par minute et par homme,
  une ligne par arrêt ; puis `regler.py --retirer`.
- **Grille, écrite avant la séance** (tempête : `cerveau.garde_ms=20000`, le pouls ne bat plus que toutes les 20 s ;
  `relance_tours` et `file_tours` à 1, une relance possible à chaque tour de 2 s) :
  1. avant la tempête : un lancement par homme et pour le Directeur, arrêts à 0, pouls à 2 par seconde → bon ;
  2. pendant 2 min de tempête : au plus 3 lancements par fenêtre et par homme (6 à 9 en 2 min, au lieu d'une
     soixantaine sans plafond), le compteur des arrêts monte, une ligne au journal par arrêt → le plafond tient ;
  3. plus de 3 lancements dans une fenêtre → le plafond ne tient pas : lire le switch (la condition `&lt;`, la
     fenêtre), un seul changement ;
  4. les valeurs retirées : en 20 s au plus, le pouls revient à 2 par seconde, et plus aucun lancement.

**V73 b 3 — L'arbitre en Lua.**
- **Une tenue par règle** : `f.tenues[regle] = { activite, lieu, position, cap, fin, depuis }`. Le rang de chaque règle
  est au catalogue (`hommes.priorites`, nouvelle section « priorites »), d'après l'ordre validé (réponse 2 a) :
  bataille 1 ; rassemblement 2 ; soins, bains 3 ; garde, garde de nuit, ronde 4 ; travail 5 ; repas, sommeil 6 ;
  loisir 7. La journée du socle vient après toutes (réponse 3 a).
- **Qui tient l'homme** : la tenue du plus petit rang ; à rang égal, la plus ancienne garde l'homme (une règle ne reprend
  pas un homme qu'une règle aussi forte tient). Les blessures (soins, rang 3), le tour de garde du socle (garde, rang 4)
  et la journée se calculent comme aujourd'hui, chacun à son rang.
- **Services**, pour le guichet et pour les morceaux du socle : `hommes.tenir(id, regle, quoi)` ;
  `hommes.lacher(id, regle)` ; `hommes.qui_tient(id)` (règle, activité, fin) ; `hommes.libre_pour(id, regle)` (aucune
  règle aussi forte ne le tient).
- **Tout de suite** : `tenir` et `lacher` redonnent l'ordre à cet homme sur-le-champ (le même chemin que le battement,
  pour lui seul). C'est ce qui fait qu'un homme cède aussitôt un poste à Henry : Scriptorium lâche sa tenue (il
  s'arrête, sa posture finit du dedans, il prend la règle d'en dessous), puis la lui redonne plus tard. **Savoir quand
  Henry veut le poste n'est pas de V73 b** : avec les postes, à l'étape des métiers.
- **Les bornes** (réponse 4 a, et question 2 ci-dessous) : une heure de fin → la tenue tombe à cette heure ; sans fin →
  au prochain changement de tranche (`hommes.journee`), calculé à la pose ; les tenues des morceaux du socle (bataille,
  patrouille) → jusqu'à ce qu'ils les lâchent, avec une borne de sûreté (`tenue_max_h`, 24 h de jeu) notée au journal.
- **Les trois appelants convertis** : `bataille`, `patrouilles` et `discipline` passent par `tenir` et `lacher` ;
  `patrouilles.disponibles` et `hommes.gardes`, par `libre_pour`. `affecter`, `liberer_affectation` et `affectation_de`
  sont retirés (rien laissé en essai).
- **Le registre** : case `hommes` en version 3 ; la montée jette l'ancien champ `affectation`, comme la 1 → 2 (les
  affectations sont passagères).
- **L'interrupteur de la journée** : `hommes.reglages.journee_du_socle` (vrai) ; à faux, un homme qu'aucune règle ne
  tient attend où il est (activité 0). C'est par lui que Scriptorium coupera la journée du socle à la bascule
  (réponse 3 a).
- Noté, sans changement : la corvée de punition du morceau `discipline` dure 24 h et passe devant toute la journée,
  sommeil compris, comme aujourd'hui ; c'est une décision de ce morceau, que la discipline de Scriptorium remplacera.
- **Essais au banc** (`essai_hommes.lua`) : une règle plus faible ne reprend pas un homme tenu ; à la libération, la
  règle d'en dessous reprend (y compris une tenue plus faible restée posée) ; à rang égal, la première garde l'homme ;
  les trois bornes ; l'ordre redonné sur-le-champ ; la montée 2 → 3 ; la garde et la patrouille ne prennent pas un
  homme tenu plus fort ; l'interrupteur de la journée.
- **En jeu**, par des commandes d'essai qui jouent le guichet : assis au repas, une tenue « rassemblement » sur un point
  → il se lève aussitôt et marche ; une tenue « loisir » en plus → rien ne change ; le rassemblement lâché → il reprend
  le loisir, ou sa tranche si le loisir est tombé.

### Les trois règles de JoVenGer qui touchent l'arbitre (le mécanisme ; qui et quand restent à Scriptorium)
- **Les compagnons ne montent jamais la garde de nuit** : le socle ne connaît pas les compagnons (question 3).
- **Un poste qu'Henry veut lui est cédé tout de suite** : `lacher` sur-le-champ, ci-dessus ; la détection viendra avec
  les postes.
- **Un homme n'est jamais retiré du monde** : la règle vise les sorties (V73 f, missions), pas le départ d'un homme qui
  quitte la Compagnie (fin de contrat, désertion, renvoi, mort : `faire_partir`). L'arbitre ne retire jamais personne.

### Relecture du pair (16/10)
- **L'attaque sur un homme assis, chez Alex (mécanisme seulement)** : il défait la posture **avant** de lancer le combat ;
  il ne compte pas sur le remplacement de l'interruption. Le Lua pose « céder la place », la tenue de la posture échoue,
  le jeu lève l'homme ; le switch retient le combat tant qu'un drapeau dit l'homme encore en posture, borné à environ
  4 s. Notre repli de V73 b 1 (issue 3) est ce schéma.
- **Deux signaux, à garder distincts** : « céder la place » fait quitter la vie du camp pour le combat ; l'alerte de
  Scriptorium (`en_garde_du_camp`) rompt la pose **sans** quitter la vie du camp. Chez Alex, « céder » seul, hors combat,
  laissait l'homme figé, faute de relance ; notre pouls couvre ce piège, mais les deux sens restent séparés (chez nous :
  l'attaque d'un côté, un changement d'activité de l'autre).
- **Henry qui veut un poste** : chez Alex, « céder la place » ne sert qu'au combat (les postes d'Henry étaient à lui
  seul ; la règle du 16/10 est nouvelle). Pour savoir qu'Henry veut le poste, se fier à **l'interaction**, pas à la
  distance : Scriptorium donne déjà à ces postes un déclencheur qu'Henry utilise (`objets_d_henry`) ; quand Henry
  l'utilise alors qu'un homme l'occupe, la tenue de l'homme est lâchée, il cède et se lève, puis Henry prend le poste.
  À l'étape des postes.
- **Le banc** : la vérification statique et la tempête provoquée en jeu suffisent (V73 b 2).
- **Rappels de Scriptorium pour les questions** : les punis restaient pris par leur loisir, et Scriptorium a dû les
  tirer de force (`pilori_du_directeur`) : la punition doit passer au moins avant les loisirs. Compagnons : le pair
  recommande l'exemption par règle, posée par Scriptorium (c'est lui qui décide).

### Questions à JoVenGer (V73 b, après relecture par le pair)
1. **Le rang de la patrouille et de la corvée de punition** (les deux tâches du socle que l'ordre validé ne nomme pas) :
   (a) la patrouille au rang « garde et ronde », la corvée de punition au rang « travail », donc avant le repas, le
   sommeil et les loisirs (Recommandé ; rappel de Scriptorium : la punition doit passer au moins avant les loisirs) ;
   (b) les deux au rang « travail » ; (c) les deux au rang « garde et ronde ».
2. **La borne des tâches que le socle donne lui-même sans heure de fin** (bataille, patrouille) : (a) jusqu'à ce que leur
   morceau les lâche, avec une borne de sûreté de 24 h de jeu notée au journal (Recommandé) ; (b) au changement de
   tranche, comme les autres (une bataille à cheval sur deux tranches serait coupée).
3. **Compagnons sans garde de nuit, le mécanisme** : (a) une exemption par règle, posée par Scriptorium sur l'homme
   (`hommes.exempter(id, "garde_de_nuit")`), respectée par l'arbitre et par la garde du socle (Recommandé) ; (b) rien dans
   le socle : les règles de garde de Scriptorium ne choisissent jamais un compagnon.
- **Réponses de JoVenGer (16/10)** : 1 (a) la patrouille au rang « garde et ronde », la corvée de punition au rang
  « travail » ; 2 (a) jusqu'à ce que leur morceau les lâche, sûreté de 24 h notée au journal ; 3 (a) l'exemption par
  règle, posée par Scriptorium.

### Mesuré en V73 b 1 (16/10)
- **Issues 1, 2 et 5 de la grille, deux fois** (Jan Kladivo, homme d'armes ; Mikuláš le Rouge, arbalétrier) : assis au
  feu, chacun se lève de lui-même à l'ordre d'attaque et se bat ; son siège se dit libre aussitôt ; pendant le combat,
  contexte de combat à 1, pouls figé, **aucune relance** (la lecture « en combat », vue pour la première fois) ; le
  brigand tué (à 39 m, puis à 110 m), le contexte tombe et **une seule relance** part ; le pouls repart, et chacun
  revient s'asseoir sur son siège.
- **Conclusion** : chez nous, le remplacement de l'interruption suffit : notre `StanceElement`, tué du dehors, joue la
  levée. Le dégagement d'Alex (issue 3) n'est pas nécessaire ; il reste en réserve.
- Le secours figé en combat n'a pas été mis à l'épreuve en jeu (secours coupé pendant l'essai, comme à chaque séance) ;
  il l'est au banc.
- Noté, sans changement : revenant de 110 m, Mikuláš s'est d'abord éloigné (de 85 à 125 m) avant de revenir. La marche
  vers un siège est bornée à 30 s (`marche_delai_ms`), puis la posture est tentée de loin : un long retour vers un
  siège passerait mieux par une marche d'abord. À reprendre avec le rassemblement (V73 e).
- **Fait nouveau, hors grille : des hommes dévêtus en pleine partie** (détail dans la fiche 13) : leurs pièces restent
  dans leur sac, mais ne sont plus portées. Jan est revenu du combat torse nu ; Mikuláš se battait en simple tunique ;
  Ondřej, qui ne s'est pas battu, était torse nu à 16 h 40.

### Mesuré en V73 b 2 (16/10)
- **Issues 1 et 2 de la grille** : avant la tempête, un lancement par homme et pour le Directeur, arrêts à 0, pouls à
  2 par seconde ; pendant la tempête, **3 lancements par fenêtre, puis une fenêtre entière sans relance** (lancements
  1 → 4 → 7 → 10 en 3 min, au lieu de près de 90 sans plafond) ; une ligne au journal par arrêt, chez chacun.
- **Issue 4, presque** : les valeurs retirées, la garde revient à 500 ms au battement suivant et le pouls à 2 par
  seconde ; mais **un lancement de trop** vers 70 s. Retenu par le plafond, le switch restait à l'état « à lancer »
  (seul cet état lance, et le pouls n'était relu qu'aux autres états) : à la fin de la fenêtre, il a relancé un
  comportement vivant (mis en file derrière lui, sans dommage, mais inutile).
- **Corrigé, un seul changement** : un pouls qui avance remet le switch « en marche », quel que soit son état (contrôlé
  au banc). À revoir en jeu : la même tempête, puis plus aucun lancement une fois les valeurs retirées.

### V73 b 3, fait (16/10) : l'arbitre par tenues
- `hommes.priorites` au catalogue (section « priorites », 26 sections) ; `hommes.reglages.tenue_max_h` (24) et
  `journee_du_socle` (vrai). Services : `tenir`, `lacher`, `qui_tient`, `libre_pour`, `exempter`. Case `hommes` en
  version 3 (l'affectation unique oubliée). `bataille`, `discipline` et `patrouilles` passent par l'arbitre ; la garde
  du socle nomme sa règle selon l'heure (« garde_de_nuit » la nuit) et ne prend que des hommes libres pour elle.
- Précisions de mise en œuvre (relecture du 16/10) : à rang égal entre une tenue posée et une règle que le socle calcule
  (les soins d'un blessé), la tenue posée l'emporte (un ordre exprès) ; à rang égal entre deux tenues, la plus ancienne,
  puis le nom de la règle ; reposer une règle ne la rajeunit pas ; lâcher une tenue déjà tombée ne dit rien ; l'ordre
  sur-le-champ ne compte jamais le temps du secours ; le registre n'est réécrit que si la tenue change ; l'activité
  « attendre » (0) n'a pas de branche, c'est la garde seule.
- **Changement visible, voulu par l'ordre validé** : avant, une affectation passait toujours devant la blessure ;
  maintenant, un puni blessé se repose (soins, rang 3, avant la punition, rang 5), et l'ordre d'une patrouille part
  sur-le-champ, à chaque point, sans attendre le battement.
- Banc : 2 473 vérifications ; le registre d'un camp plein, deux tenues et une exemption par homme : 142 403 octets en
  5 tranches. Garde-fous éprouvés par erreurs injectées (l'ordre à rang égal, le secours hors battement).
- **Grille de l'essai en jeu, écrite avant la séance** (premier homme assis au feu, secours coupé) :
  1. `essai_tenir_rassemblement` : la ligne « Ordre à … : rassemblement » vient au journal **juste avant** la ligne du
     poste (l'ordre est donné dans `tenir`, sans attendre le battement) ; il se lève et marche au point de la corvée ;
     `essai_qui_tient` dit « rassemblement » → bon ;
  2. `essai_tenir_loisir` (fin dans une heure) : aucun ordre pour lui ; toujours « rassemblement » → bon ;
  3. `essai_lacher_rassemblement` : un ordre « des » aussitôt, il va au coin des dés ; « loisir » → bon ;
  4. les autres hommes suivent leur journée, un lancement chacun ;
  5. un ordre qui n'arrive qu'au battement → le chemin « sur-le-champ » ne marche pas en jeu : lire `tenir` et
     `ordonner_un_homme`, un seul changement.

### Mesuré en V73 b 3 (16/10) : l'arbitre, acquis
- **Issues 1 à 4 de la grille** : la tenue « rassemblement » donne l'ordre dans `tenir`, juste avant la ligne du poste
  au journal ; Jan se lève (siège libre) et marche au point de la corvée ; la tenue « loisir », plus faible, ne donne
  aucun ordre ; le rassemblement lâché, l'ordre « dés » part aussitôt et Jan va au coin des dés, tenu par le loisir pour
  une heure ; les deux autres restent assis, un lancement chacun.
- À savoir pour les essais : un ordre du poste donné moins de 30 s après la naissance des hommes est remplacé par le
  premier ordre de leur journée, qui arrive au battement suivant (vu en début de séance ; redonné, il tient).
- **V73 b est fini** : l'attaque sur un homme assis (b 1), le plafond de relances (b 2), l'arbitre (b 3). Suite décidée
  par JoVenGer : la tenue (fiche 13), puis l'ancre du camp (fiche 03), puis V73 d, la garde.

### Mesuré en V73 b 2 bis (16/10) : le plafond, acquis
- Non-régression : un lancement par homme et pour le Directeur, arrêts à 0.
- La même tempête : au plus 3 lancements par fenêtre et par personnage (la fenêtre de chacun part de sa naissance, d'où
  des rythmes un peu différents entre les hommes et le Directeur), une ligne au journal par arrêt.
- **Les valeurs retirées : plus aucun lancement en 173 s** (près de trois fenêtres), pouls à 2 par seconde. Le plafond
  et sa correction sont acquis.

## V73 d — monter la garde (16/10, relu par le pair)

### Le périmètre
- **V73 d 1, ce pas-ci : le geste du factionnaire.** L'homme va à un poste précis, s'y tient **face au dehors**, et n'y
  reste pas planté sans bouger. **Qui, quand et où** restent à la règle : aujourd'hui le tour de garde du socle
  (`hommes.gardes`), demain Scriptorium par `hommes.tenir(id, "garde", { position, cap, fin })`. Les quatre postes à 12 m
  sont des valeurs par défaut du socle ; ceux de Scriptorium (2 m en dedans de chaque porte, face au dehors ; 3 m devant
  la cabane d'Henry) viendront par la tenue.
- **Plus tard, chacun à son pas** :
  - la ronde, de point en point avec de courtes pauses (V73 d 2, question 3) ;
  - l'arme tirée au calme, si JoVenGer la veut (V73 d 1 bis, question 1) ;
  - l'alerte et l'anneau, arme tirée face à l'ennemi ;
  - le veilleur de tour, posé sur le plancher (un des quatre cas de pose accordés) ;
  - les postes du jeu (`guard/so_guardspot` et les autres de la note des métiers), posés sur un meuble, avec les postes.

### Ce que Scriptorium attend (relu le 16/10, lecture seule, par un agent de recherche : carte des règles, note des métiers et son relevé, LISEZMOI)
- **Le factionnaire** (`garde_du_directeur`, 28/09) marche jusqu'à son point et s'y tient **face au dehors** ; devant la
  cabane, la porte dans le dos. Il ne poursuit pas un ennemi à plus de 20 m de son poste (`en_garde_du_camp`, 4/10).
- **La ronde** : un cercle de 24 points, ou une ronde tracée par JoVenGer ; de point en point, de courtes pauses ; six
  hommes espacés ; « un garde n'est jamais assis » (`sentinelles_du_camp`, 3/10).
- **Le veilleur de tour** : sur le plancher, tourné vers l'extérieur, **arme rangée la nuit, tirée à l'alerte**
  (`tours_de_guet`, 10/10).
- **L'arme d'un garde au calme n'est écrite nulle part** : « arme prête » n'apparaît dans aucun document, aucun geste
  « en garde » arme tirée n'y est prouvé. Pour se tenir aux aguets, `en_garde_du_camp` propose le geste
  `waiting_nervous_lookingAround_noObject`. **Aucun document ne parle de torche la nuit.**
- **À éviter** : l'homme planté sans bouger (note des métiers) ; la glissade ; le garde recouché par une autre règle
  (`chef_du_camp`, 12/10 ; réglé par l'arbitre : la garde, rang 4, passe avant le sommeil, rang 6).
- **La relève** : quarts de 3 h (22 h, 1 h, 4 h, 7 h), jamais de trou dans la ronde, « qu'un garde ne reste pas 24 heures
  debout » (`garde_du_directeur`) ; les compagnons sans garde de nuit (exemption, V73 b 3). La règle décide ; le socle
  tient et lâche.
- **Ce que le socle doit savoir** (note des métiers, 16/10) : commencer le geste à ce poste, le tenir jusqu'à l'ordre de
  fin ou une durée, l'interrompre ; aucun poste laissé tourner seul.

### Le constat (code relu le 16/10)
- Le tour de garde existe (`hommes.gardes`), mais en jeu la garde n'est qu'une marche (ordre 9) vers le poste : l'homme
  s'arrête à 2 ± 0,5 m du point (tolérance de la marche), tourné comme il est arrivé, et reste planté là.
- **Le cap du poste est jeté** : `camp.point` rend la position et le cap, `activite_de` ne garde que la position
  (`resultat.position = camp().point(...)`) ; `liaison.ordonner` et `faux_jeu.ordonner` n'ont aucun paramètre de cap ;
  le champ `cap` des tenues n'est lu par personne.
- Les postes par défaut, (0 ; 12), (12 ; 0), (0 ; −12), (−12 ; 0), chacun tourné vers l'extérieur, ne tombent dans
  aucun meuble du plan (le plus proche : le second feu du niveau 3, à 3 m du poste sud) et sont à 8 m en dedans de la
  palissade (rayon 20). Mais rien ne le vérifie : un plan ou un réglage changé pourrait y mettre un meuble.
- Noté, sans changement : la nuit, les deux postes pris sont les deux premiers de la table (nord et est, deux côtés
  voisins) ; la table des postes n'est pas au catalogue des réglages. Ce sont des défauts du socle, que les postes de
  Scriptorium remplaceront.

### Ce que le jeu fait (lu dans `Scripts.pak`, lecture seule, rien d'extrait)
- **Le poste de garde du jeu** (`AI/profession/guard/so_guardspot.xml`) : un déplacement exact jusqu'à l'objet du
  poste, aligné sur lui, puis une attente dont l'objet donne la durée ; une place assise ou d'appui liée au poste, il
  s'y met. Les postes de Kuttenberg (`so_kzik_guardSpot.xml`) jouent en plus la posture de garde du jeu (« unstance »
  `guard`) sur l'objet. Les deux ont besoin d'un objet du jeu : à l'étape des postes.
- **Se tourner vers un point** : `Turn` vers une position (vec3), 8 emplois (`AI/crime/sharePlayersLastSeenPosition.xml`,
  `AI/npc/basic/switch/interrupt_lookAround.xml`) ; nous l'employons déjà vers un siège (un objet). Repli : un
  déplacement exact vers un point avec une direction en vecteur (`ExactMove`, `directionType="FromVariable"`,
  `AI/situation/helpers/helpers.xml`), jamais employé chez nous.
- **Regarder autour, sans objet** : `UnstanceAction` `LookingAround` le jour, une simple attente la nuit
  (`AI/events/randomEventsBehaviors.xml`, sous `IsNightTimeOfDay`) ; aussi `AlertedLookingAround` et `standingNervous`
  sans objet. `waiting_nervous_lookingAround` n'est employé qu'avec un objet.
- **L'arme tirée au repos** (`AI/quests/nebakovObrana/nebakovObrana.xml`, arbre `guardIdleNotification`) : si l'arme
  principale n'est pas en main (`IsWeaponDrawn`), `DrawAction` (jeu d'armes « Primary ») ; puis tenir sous le décorateur
  qui garde l'état et les objets en main (`AnyDecorator`, préréglage `crime_keepStateAndItems`). Le choix de l'arme d'un
  soldat (`AI/battles/battlegroupcontroller.xml`, `move_SwitchWeapons`) : le tir d'abord (« Secondary »), sinon la mêlée
  (« Primary »). La torche la nuit : la fonction du jeu `drawWeapon_withTorchAtNight`.
- **Pas connu** : la durée d'un `UnstanceAction` (un geste qui finit seul, ou une pose tenue jusqu'au geste suivant) ;
  le rengainage d'un habitant (aucun nœud trouvé ; `holsterWeapon` est au joueur seul).
- Recherche d'un exemple existant (règle du 15/10) : deux recherches sur le web, rien de propre à KCD2 ; le seul
  principe proche vient d'un autre moteur (un marqueur orienté donne au garde la direction à regarder), c'est notre point
  de regard. Le reste vient des arbres du jeu ci-dessus.

### Comment ce serait fait (V73 d 1, un seul pas, vu en jeu)
1. **Le regard** (`hommes`) : le garde reçoit, en plus de son poste, un point de regard à `regard_m` (10 m) devant le
   poste, dans son cap. Une tenue « garde » de Scriptorium donne son `cap` (cap de boussole en degrés, comme tout le
   socle : 0 au nord, 90 à l'est) ; sans cap, le regard part du centre du camp vers le poste (vers le dehors) ; ni camp
   ni cap : une marche simple (ordre 9), notée au journal.
2. **L'ordre 12, « tenir un poste »** (`liaison.ordonner`, un paramètre de plus, et `faux_jeu`) : le poste dans
   `scriptorium_essai_point`, le regard dans une nouvelle variable de cerveau `scriptorium_regard` (vec3), puis
   l'activité 12 et le compteur ; la ligne au journal dit le poste et le regard.
3. **La branche 12 du comportement long** (`comportements.xml`) : debout d'abord (comme la marche) ; marcher jusqu'au
   poste avec un arrêt court, comme le siège (`poste_arret_cm` 50, ± `poste_ecart_cm` 10, au lieu de 2 m) ; se tourner
   vers le regard (`Turn`, position) ; compter « en poste » (`scriptorium_en_poste`, entier, pour le poste d'essai) ;
   puis tenir avec le pouls jusqu'au changement d'ordre, et, le jour, un geste « regarder autour » (`UnstanceAction`
   `LookingAround`, sans objet) toutes les `poste_geste_ms` (60 000), à ± `poste_geste_ecart_ms`
   (30 000) tirés au hasard par l'attente du jeu (`Wait` avec `variation`), suivi d'un nouveau `Turn` vers le regard ; la
   nuit, rien, comme le jeu. Six variables de cerveau de plus (36, ci-dessous). L'ordre, d'après la relecture du pair : le regard
   est posé avant l'activité, l'homme marche, et ne se tourne qu'une fois arrivé.
4. **L'arme** : selon la question 1 ; par défaut rangée au calme, comme le veilleur de Scriptorium (rien à faire : le
   jeu la fait tirer au combat, vu en V73 b 1).
5. **Le garde-fou des postes** (banc) : chaque poste par défaut à plus de 2 m de tout meuble du plan, tous niveaux, et en
   dedans de la palissade. Aucun choix de lieu, une vérification.
- **Valeurs en données** : `hommes.reglages.regard_m` (10) ; `hommes.cerveau.poste_arret_cm` (50), `poste_ecart_cm`
  (10), `poste_geste_ms` (60 000), `poste_geste_ecart_ms` (30 000), défauts recopiés dans l'arbre et comparés au banc.
- **Rien au registre** : la garde du socle est calculée, le cap des tenues y est déjà.
- **Le secours ne change pas** : il vise le poste, arrivé à moins de 3 m.
- **La relève** : un nouvel ordre fait finir la tenue du dedans, et l'homme part, comme à chaque changement de tranche.

### Essais au banc
- Le tour de garde donne « garde », le poste et un regard à 10 m devant lui, vers le dehors (les quatre postes, deux caps
  d'ancre) ; une tenue « garde » avec un cap : le regard dans ce cap ; sans cap : vers le dehors ; sans camp : marche.
- La liaison pose le poste, le regard et l'activité 12.
- Contrôles statiques (`tout_verifier.py`) : la branche 12 existe et lit le poste et le regard ; les nouvelles valeurs ont
  leur défaut dans l'arbre ; les deux nouvelles variables sont déclarées et employées.
- Le garde-fou des postes.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé, trois hommes assis au feu ; `essai_tenir_garde` (le premier homme tenu par la garde au
poste 1, jusqu'à libération) ; une lecture toutes les 5 s environ ; `voir_sur_la_place` dit en plus le cap de l'homme
(ses angles dans le monde, comme `cap_du_joueur`) et son écart au cap du regard.
1. Il se lève, marche au poste, s'arrête à moins de 1 m, se tourne vers le dehors (écart de cap sous 20°), « en poste »
   à 1, et **ne glisse pas** en prenant le poste (deux lectures à 5 s d'écart, moins de 0,3 m entre elles, et à
   l'image) → bon.
2. Il s'arrête à 2 m ou plus → l'arrêt court ne tient pas : lire la ligne de l'ordre et l'écart ; un seul changement.
3. Il ne se tourne pas (écart de cap au-dessus de 20°) → le repli `ExactMove` vers une direction ; un seul changement.
   Il glisse en prenant le poste → lire si le `Turn` part avant la fin de la marche ; un seul changement.
4. Pendant 3 min : des gestes « regarder autour » à des moments différents d'un homme à l'autre, chacun finit seul, et
   après chacun il fait de nouveau face au dehors → bon ; une pose qui ne finit pas, ou un homme qui reste tourné
   ailleurs → lire, un seul changement.
5. `essai_lacher_garde` : il rejoint sa tranche (rassis, si c'est l'heure du repas), un seul ordre → bon.
6. Les deux autres suivent leur journée, un lancement chacun.
- Décompte de l'écran noir (fiche 14).

### Relecture du pair (16/10)
- **La garde chez Alex est une ronde, pas un poste fixe** (mécanisme seulement) : marcher d'un point du périmètre au
  suivant, arrêt à 1 m (± 0,5), état du personnage changé par la marche ; puis une pause, courte la plupart du temps
  (environ 6 s ± 4), longue une fois sur cinq (environ 20 s ± 8). Ni `Turn` ni geste : la pause variable est le geste
  vivant. À reprendre pour la ronde (V73 d 2).
- **Les pièges, chez Scriptorium** : un homme sorti de sa routine se figeait ; lui montrer son poste trop tôt le faisait
  glisser (`en_garde_du_camp`). L'ordre à garder : le regard posé d'abord, puis la marche, puis le `Turn`, une fois
  arrivé. Les archers des tours sont posés sur la plateforme et tenus là (`tours_de_guet`).
- **Ranger l'arme** : aucun nœud dans les arbres ; c'est l'appel du jeu qui la tire, `human:DrawWeapon`, avec « faux »,
  depuis le Lua ou un `ExecuteLua` (le jeu l'appelle sans argument dans `Scripts/Entities/actor/player.lua`,
  `Scripts/FlowNodes/InventoryWeapon.lua`). Deux leçons d'Alex : ne **jamais** ranger tant que le combat continue autour
  (le combat finit à chaque cible morte : ses hommes rangeaient puis retiraient sans cesse ; sa garde : aucun ennemi à
  moins de 25 m) ; ranger au calme, après environ 16 s sans rien à faire, ou quand l'homme s'éloigne trop d'Henry.
- **`UnstanceAction`** : un nœud sans enfant, un geste joué (plus de 2 000 emplois dans le jeu) ; Alex emploie
  `UnstanceElement`, qui tient la pose tant que sa suite tourne. Le fragment d'entrée d'un geste range l'arme de
  lui-même : un « regarder autour » joué par un garde à l'arme tirée la lui ferait ranger (à noter pour V73 d 1 bis).
  À vérifier en jeu : `LookingAround` finit-il seul ?
- **Relecture** : la grille est bonne, avec une issue de plus (il ne glisse pas en prenant le poste, et son cap final est
  à moins de 20° du regard) ; l'arme rangée au calme, recommandée ; le geste vivant avec un intervalle tiré au hasard,
  comme les pauses d'Alex, pour que les gardes ne bougent pas tous ensemble ; la ronde : qui, quand et où sont déjà
  décidés chez Scriptorium (JoVenGer la trace, `ronde_tracee` ; `sentinelles_du_camp`, `en_garde_du_camp`), le socle ne
  fournit que la mécanique « suivre un chemin de points, avec des pauses » : un pas à part, V73 d 2.
- **Ce qui change dans la fiche** : l'intervalle du geste tiré au hasard par l'attente du jeu (`Wait` avec `variation`,
  forme de `AI/events/randomEventsBehaviors.xml`, par exemple 5 s ± 3) ; la grille (glissade, 20°) ; les options des
  questions.

### Questions à JoVenGer (après relecture par le pair)
1. **L'arme du garde au calme** (rien chez Scriptorium ; le veilleur de tour l'a rangée la nuit, tirée à l'alerte) :
   (a) rangée au calme, tirée seulement au combat ou à l'alerte, comme le veilleur de Scriptorium (Recommandé, avec le
   pair) ; (b) rangée par défaut, tirée quand la tenue le demande (`arme = "tiree"`), dans un pas à part (V73 d 1 bis :
   rangée par l'appel du jeu, jamais avec un ennemi à moins de 25 m ; un geste joué range l'arme) ; (c) tirée toute la
   garde.
2. **Le garde au calme** : (a) le jour, il regarde autour de lui de temps en temps (geste du jeu sans objet, environ
   toutes les minutes, l'intervalle tiré au hasard pour que les gardes ne bougent pas ensemble, réglable), la nuit il se
   tient immobile, comme le jeu (Recommandé : la note des métiers ne veut pas d'homme planté) ; (b) immobile, face au dehors ; (c) le geste aux aguets proposé par `en_garde_du_camp` (jamais employé sans
   objet dans le jeu).
3. **La ronde** : (a) un pas à part, V73 d 2, juste après le factionnaire, **mécanique seulement** : suivre un chemin de
   points avec des pauses (courtes, parfois longues, tirées au hasard) ; qui, quand et où restent à Scriptorium, où
   JoVenGer trace déjà la ronde (Recommandé, avec le pair) ; (b) rien dans le socle : Scriptorium pose une tenue par
   point ; (c) plus tard, après le rassemblement.

- **Réponses de JoVenGer (16/10)** : 1 (a) l'arme rangée au calme, tirée seulement au combat ou à l'alerte ; 2 (a) le
  jour, un regard autour de temps en temps, l'intervalle tiré au hasard, la nuit immobile ; 3 (a) la ronde dans un pas à
  part, V73 d 2, mécanique seulement (suivre un chemin de points avec des pauses).

### V73 d 1, fait (16/10) : tenir un poste
- `hommes` : le cap du poste n'est plus jeté ; `activite_de` rend un point de regard pour toute garde (tour du socle ou
  tenue « garde ») : à `regard_m` (10 m) devant le poste, dans son cap, sinon du centre du camp vers le poste ; ni camp ni
  cap, ou un poste au centre même du camp : aucun regard, l'ordre reste une marche. L'ordre (battement ou sur-le-champ)
  porte ce regard.
- `liaison.ordonner` : avec un regard, le poste et le point regardé posés d'abord (`scriptorium_essai_point`,
  `scriptorium_regard`), puis l'ordre 12 ; refusés, une marche (ordre 9). Le poste d'essai dit en plus le cap de
  l'homme, son écart au regard et « en poste ».
- La branche 12 du comportement long : debout d'abord ; la marche au poste, arrêt à 50 cm ± 10 ; le `Turn` vers le
  regard, puis « en poste » + 1 ; la tenue avec le pouls ; le jour, `LookingAround` toutes les 60 s ± 30 (attente du jeu
  à durée variable), suivi d'un nouveau `Turn` ; la nuit, rien.
- Six variables de cerveau de plus (36) : le regard (vec3), « en poste », et les quatre valeurs du poste au catalogue
  (`poste_arret_cm`, `poste_ecart_cm`, `poste_geste_ms`, `poste_geste_ecart_ms`), lues avec leur défaut comme les
  autres : zéro vaut le défaut, aucune ne « coupe » le geste (un intervalle très long fait un garde presque immobile).
- Commandes d'essai `essai_tenir_garde` (le premier homme tenu par la garde au poste 1 du socle, jusqu'à libération) et
  `essai_lacher_garde` (134 commandes).
- Banc : 2 725 vérifications ; trois essais (le tour de garde regarde vers le dehors aux deux caps d'ancre, et seuls les
  ordres de garde portent un regard ; la tenue avec cap, sans cap, au centre, sans camp, et le rassemblement sans
  regard ; le garde-fou des postes) ; contrôle statique de la branche 12 (le `Turn` avant « en poste », et de nouveau
  après chaque geste) et du regard posé par la liaison. Garde-fous éprouvés par quatre erreurs injectées, toutes
  attrapées : le regard inversé, l'ordre sans regard, le `Turn` retiré après l'arrivée, le `Turn` retiré après le geste.
- **Contrôle d'absence** : une ligne de structure de plus en commun avec Alex et présente telle quelle dans le jeu,
  `<Else canSkip="1">` (la branche « sinon » de `IsNightTimeOfDay`, `AI/events/randomEventsBehaviors.xml`) : la borne des
  lignes de forme passe de 31 à 32, revue. Chaque ligne admise est relue dans les fichiers du jeu à chaque passage du banc
  (rappel du pair : c'est à JoVenGer de dire si cette tolérance lui va).

### Mesuré en V73 d 1 (16/10) : tenir un poste, acquis
- **Issue 1 de la grille** : Jan, assis au feu, tenu par la garde au poste 1 ; l'ordre 12 part dans `tenir` (poste et
  regard posés) ; il se lève vers 13 s (la tenue de la posture finit du dedans), marche, et arrive vers 26 s : « en
  poste » 1, cap à 18° du regard, à environ 0,5 m du poste (estimé : la lecture du poste dit l'écart au siège, 11,55 m,
  et le poste est à 12,1 m du siège). **Aucune glissade** : position fixe sur 77 s puis 2 min de film.
- **Issue 3, le `Turn`** : à 18°, il ne tourne pas (sa tolérance, environ 20°). Prouvé à part : une tenue de rassemblement
  (rang 2) l'envoie à la corvée (le regard effacé), puis on la lâche : la garde reprend aussitôt (ordre redonné) ; il
  revient en biais (cap 155°, 27° d'écart en marche) et **se tourne à l'arrivée jusqu'à 0°** (« en poste » 2), sans
  glisser.
- **Issue 4, le geste** : `LookingAround` sans objet vu une fois dans 2 min de film (une image toutes les 1,25 s) : il
  regarde d'un côté puis de l'autre, environ 15 s, puis reprend seul sa pose de garde ; le cap n'a pas bougé (le geste
  tourne le buste, pas le corps). Le geste finit donc seul.
- **Issue 5** : la garde lâchée, un seul ordre, sur-le-champ (la corvée, 13 h) ; il rejoint sa tranche.
- **Issue 6** : les deux autres suivent leur journée (la corvée à 13 h), un lancement chacun, aucun arrêt ; 18 valeurs
  écrites dans chaque cerveau ; aucune erreur au journal ; arme rangée ; écran normal.
- **Pas vu en jeu** : le tour de garde du socle (avec trois hommes, aucun poste le jour ; prouvé au banc), la nuit (aucun
  geste), plusieurs gardes ensemble (gestes à des moments différents), l'écart au poste lui-même (à lire au poste
  d'essai avec V73 d 2 : l'écart au but de l'ordre, pas seulement au siège).
- **Suite** : V73 d 2, la ronde (mécanique seulement : suivre un chemin de points avec des pauses).

## V73 d 2 — la ronde (17/10, relu par le pair)

### Le périmètre
- **Mécanique seulement** (réponse 3 a de JoVenGer, 16/10) : l'homme suit un chemin de points, avec une pause à chaque
  point. **Qui, quand et où** restent à Scriptorium (`sentinelles_du_camp` : un cercle de 24 points, ou la ronde tracée
  par JoVenGer, six hommes espacés ; la relève par quarts de 3 h). Le service : `hommes.tenir(id, "ronde", { chemin,
  aller_retour, depart, fin })` ; la règle « ronde » est déjà au catalogue des rangs (4, comme la garde).
- Aucune règle du socle ne donne de ronde (ni la journée, ni le tour de garde) : seulement la tenue, et la commande
  d'essai.
- **Plus tard, chacun à son pas** : un geste aux pauses (question 3) ; l'alerte ; la relève tenue sans trou.

### Ce que Scriptorium attend (relu en V73 d, 16/10)
- De point en point, de courtes pauses ; « un garde n'est jamais assis » ; jamais de trou dans la ronde (la règle
  décide de la relève ; le socle tient et lâche).
- Le principe d'Alex, transmis par le pair (mécanisme seulement) : marcher d'un point au suivant, arrêt à 1 m (± 0,5),
  l'état du personnage changé par la marche ; puis une pause, courte la plupart du temps (environ 6 s ± 4), longue une
  fois sur cinq (environ 20 s ± 8). Ni `Turn` ni geste : la pause variable est le geste vivant.

### Le constat (code relu le 17/10)
- **Le battement du socle tourne toutes les 30 s** (`Scriptorium.cadence_du_battement_ms`), une pause dure de 2 à 28 s :
  le Lua ne peut pas donner chaque point au battement. Les patrouilles le font (`patrouilles.battre`, un point par
  tenue, `lieu = chemin_point`), mais d'heure en heure.
- `activite_de` n'a pas de branche « ronde » ; une tenue n'a pas de chemin ; `memes_tenues` ne comparerait pas un
  chemin (chaque repose réenregistrerait, ou ne serait jamais mise à jour).
- **Le secours** mesure le progrès vers `a.position` : un rondier qui quitte un point s'en éloigne ; au bout d'un
  battement sans progrès (30 s), il serait posé d'un coup. À changer pour la ronde.
- `patrouilles.chemins.ronde_proche` est à 30 m du centre, hors de l'enceinte (20 m) : pas réutilisée.
- Le poste d'essai dit l'écart au siège, pas au but de l'ordre (relevé en V73 d 1) : à ajouter.
- La liaison n'appelle aucun morceau ; les morceaux lui confient leurs fonctions (la minuterie du noyau).

### Ce que le jeu fait (lu dans `Scripts.pak`, lecture seule, rien d'extrait)
- **Un arbre qui appelle le Lua** : `ExecuteLua code="…"`, 784 emplois dans 174 fichiers, dont 7 interruptions du
  switch du jeu (`AI/npc/basic/switch/interrupt_attack.xml`). Le code voit `entity` (le personnage qui joue l'arbre),
  `data` (les variables de l'arbre, et `data.this`), et les modules Lua globaux (`ShootingContest.…`,
  `AI/quests/lukostreleckaSoutez/shootingRange.xml`). **La forme exacte du besoin existe** :
  `AI/quests/kutnohorskyTurnaj/kutnohorskyturnaj.xml` écrit une durée tirée au hasard dans une variable `_string` de
  l'arbre (`data.waitTimeString = math.random(…) .. 's'`), puis `Wait duration="$waitTimeString"`.
- **Le hasard dans l'arbre** : `RandomGate opensWithChance`, 376 emplois, la chance littérale ou en variable
  (`$chance`, `$clampedChance`) ; et `Wait` avec `variation`.
- **Les tableaux** : `ForEach array=… value=…`, 734 emplois, avec un `Move` dans la boucle
  (`AI/_lukas/test_lukas_helper.xml`, sur des `_wuid`) ; 9 tableaux de `vec3` déclarés
  (`AI/animal/basic/switch/animal_getPointOutsideLabelFromBuffer.xml`), aucun rempli depuis le Lua, et la table des
  variables de cerveau du jeu n'en déclare aucun.
- **Les patrouilles du jeu** (`Function_npc_patroling path=… startPath=…`, `Function_guard_patroling pathStart=…
  patrolType=Loop`) suivent un chemin du niveau, une entité posée dans l'éditeur (`_wuid`) : pas pour nos points
  calculés.
- Recherche d'un exemple existant (règle du 15/10) : une recherche, rien de propre à KCD2 ; une vidéo de Warhorse pour
  KCD 1 (« Guard's Behavior, Loops »), illisible ici. Les arbres du jeu ci-dessus suffisent.

### Comment ce serait fait : trois voies (question 1)
- **(a) L'arbre appelle le Lua à chaque point (recommandé)** : arrivé au point, l'arbre appelle
  `Scriptorium.jeu.au_point_de_ronde(entity, data)` ; la liaison demande à `hommes` le point suivant et la pause, pose
  le point dans le cerveau, écrit la pause dans une variable de l'arbre ; l'arbre attend cette pause, puis marche au
  point suivant. Aucune attente du battement, aucun relevé de plus ; le hasard est celui du socle, comparé au banc.
  Coût : un appel Lua par point et par rondier (environ toutes les 10 s). Risque : `ExecuteLua` jamais employé chez
  nous, vérifié en premier dans l'essai (issue 1). À la bascule, le nom de la table écrit dans l'arbre change avec elle
  (le banc vérifie que l'arbre nomme `Scriptorium.chemin`).
- **(b) Le Lua relève les arrivées par le guet de 5 s** : l'arbre pause seul (`RandomGate` une fois sur cinq, `Wait`
  avec `variation`) et compte ses étapes ; le guet relit le compte et pose le point suivant. Jusqu'à 5 s de plus à
  chaque point, une lecture de cerveau par rondier toutes les 5 s, et le hasard du jeu (pas comparable au banc). Le
  repli si (a) échoue.
- **(c) L'arbre tient tout le chemin** : un tableau de points dans le cerveau, parcouru par `ForEach`. Aucun exemple
  dans le jeu d'un tableau de cerveau rempli par le Lua : à sonder d'abord ; sinon autant de variables et de branches
  que de points (lourd).

### Le détail de la voie (a)
1. **La tenue « ronde »** (`hommes.tenir`) : `chemin`, une liste de 2 à `ronde_points_max` (32) points du monde
   ({ x, y, z }, comme la `position` d'une garde) ; `aller_retour` (faux par défaut : boucle) ; `depart`, le numéro du
   premier point (facultatif). Refus `chemin_invalide` sinon. Scriptorium garde sa ronde dans le repère du camp
   (relecture du pair) : il la redonne, en points du monde (`camp.point`), à chaque nouvelle fondation. La ronde se
   joue le jour comme la nuit. Gardée au registre comme toute tenue (24 points font
   environ 1 Ko par homme, loin des 65 535 octets d'un jeton ; mesuré au banc). `memes_tenues` compare le chemin point
   par point et les deux options.
2. **`activite_de`** : la tenue « ronde » rend l'activité « ronde », son chemin et ses options ; le regard de chaque
   pause est donné par le pas (réponse 3 b, ci-dessous).
3. **L'ordre** (`ordonner_un_homme`) : le premier point est `depart`, sinon le point du chemin le plus proche de
   l'homme ; l'état de sa ronde est gardé en mémoire (`hommes.en_ronde` : point visé, point quitté, sens) ; l'ordre 13
   part avec ce premier point. Au rechargement, le cerveau repart de zéro ; l'ordre redonné repart du point le plus
   proche.
4. **Le pas** (`hommes.pas_de_ronde`, que `hommes` confie à la liaison au démarrage) : le point suivant (en boucle,
   après le dernier, le premier ; en aller-retour, demi-tour aux deux bouts) ; la pause, longue une fois sur
   `ronde_longue_sur` (5), sinon courte, sa durée tirée au hasard du socle : `ronde_pause_ms` (6 000) ±
   `ronde_pause_ecart_ms` (4 000), ou `ronde_longue_ms` (20 000) ± `ronde_longue_ecart_ms` (8 000), jamais moins de
   500 ms. Un homme qui n'est plus de ronde : rien (l'arbre garde sa pause par défaut, et finit au changement d'ordre).
5. **La liaison** : `liaison.ordonner` avec l'activité « ronde » pose le point, puis l'activité 13 ;
   `liaison.au_point_de_ronde(entite, donnees)` retrouve l'homme par le nom de l'entité, demande le pas, pose le point,
   écrit la pause (« 6000ms ») ; tout sous `pcall`, l'erreur écrite au journal ; une ligne au journal par pas (le
   point, la pause, l'écart au point quitté). Dans l'arbre, l'appel est lui-même sous `pcall(function() … end)` (si la
   table manquait, l'erreur ne casserait pas la branche), une seule instruction, **jamais de commentaire Lua dans
   `code`** (un « -- » couperait sans bruit tout le reste) ; le banc le vérifie.
6. **Le secours** : pour un rondier, le but est le point visé ; il est « arrivé » s'il est à moins de
   `secours_arrivee_m` du point visé ou du point quitté (il y fait sa pause) ; posé d'un coup seulement s'il ne se
   rapproche d'aucun des deux pendant `secours_delai_s`, et alors près du point visé.
7. **La branche 13 du comportement long** : debout d'abord (comme la marche) ; puis, tant que l'ordre tient : la marche
   au point (arrêt `ronde_arret_cm` 100 ± `ronde_ecart_cm` 50, délai de la marche), « arrivées » + 1 ; la pause par
   défaut (celle de la sortie, 2 s) ; l'appel au Lua ; l'attente de la pause ; le pouls en parallèle. Une marche
   abandonnée (délai) ne compte pas d'arrivée, mais le Lua donne quand même le point suivant : un point inaccessible
   est sauté, et le journal le dit (l'écart au point quitté).
8. **La mesure promise en V73 d 1** : le dernier point posé chez chaque homme, par l'ordre ou par le pas
   (`liaison.buts`) ; le poste d'essai dit l'écart à ce but, et le nombre de pas.
9. **Le contrôle d'absence** : aucune ligne de forme du jeu de plus n'est attendue (nos propres noms de variables) ;
   vérifié au banc. La borne reste à 32, en attendant la décision de JoVenGer.
- **Valeurs en données** : `hommes.reglages` : `ronde_points_max` (32), `ronde_pause_ms` (6 000),
  `ronde_pause_ecart_ms` (4 000), `ronde_longue_ms` (20 000), `ronde_longue_ecart_ms` (8 000), `ronde_longue_sur` (5) ;
  `hommes.cerveau` : `ronde_arret_cm` (100), `ronde_ecart_cm` (50), lus par l'arbre avec leur défaut (38 variables de
  cerveau). Une table nouvelle au catalogue, `hommes.rondes`, avec la ronde d'essai « pourtour » (12 points à 16 m du
  centre, par rapport à l'ancre), pour la commande d'essai seulement. À 12 m, deux segments passeraient à moins de
  2,4 m de la tente 6 (1,8 m) et d'un banc du second feu (2,2 m), au niveau 3 ; à 16 m, le plus proche est à 2,7 m,
  et la palissade à 4 m.

### Essais au banc
- La tenue : refusée avec un seul point, plus de 32, un point sans `x` ; acceptée sinon, gardée au registre et relue ;
  reposée à l'identique, rien d'enregistré ; le chemin changé, enregistré.
- Le départ au point le plus proche, ou au point `depart`.
- Le pas : la boucle (après le dernier, le premier), l'aller-retour (demi-tour aux bouts, deux points compris) ; les
  pauses dans leurs bornes ; sur 1 000 pas, entre 15 et 25 % de longues ; le même hasard donne les mêmes pauses.
- Le secours : un rondier en pause au point quitté n'est jamais posé ; bloqué entre deux points, posé près du point
  visé.
- La liaison, sur un faux moteur : le pas pose le point et écrit la pause ; un homme inconnu, rien, sans erreur.
- Contrôles statiques : la branche 13 (la marche, l'arrivée, l'appel sous `pcall` au nom de `Scriptorium.chemin`, sans
  commentaire Lua, l'attente de `$ronde_pause`) ; la fonction appelée existe dans la liaison ; les deux variables de cerveau, déclarées, avec leur
  défaut dans l'arbre.
- Le garde-fou de la ronde d'essai : chaque segment à au moins `ecart_d_abord` (2,4 m) de tout meuble du plan, tous
  niveaux, et en dedans de la palissade.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé (le banc le prouve), trois hommes au camp ; `essai_tenir_ronde` (les deux premiers hommes
sur la ronde « pourtour », partis de deux points opposés) ; une lecture toutes les 5 s environ (écart au but, pas,
arrivées).
0. **D'abord les trois hommes** (`essai_hommes_voir`) : le troisième suit sa journée, un lancement chacun, pouls qui
   avance ; un nœud mal reçu casserait tout l'arbre, pas la seule branche 13 (conseil reçu avant la séance).
1. **L'appel** : à la première arrivée, une ligne « pas de ronde » au journal → l'arbre appelle le Lua, bon. Sinon, trois
   lectures à ne pas confondre (au poste : arrivées, pas de ronde, pouls) :
   - « arrivées » monte d'environ une toutes les 2 s, pas de ronde à 0 : `ExecuteLua` est joué, mais l'appel échoue
     avant la liaison (table invisible, `entity` nul) → lire le code de l'appel, un seul changement ;
   - « arrivées » reste à 1, pas de ronde à 0, pouls qui avance : `ExecuteLua` n'est pas joué → la voie (b) ;
   - la ligne « aucun pas (homme inconnu) » : la liaison est appelée, mais le nom de l'entité n'est pas celui du
     registre → accorder les noms, ce n'est pas la voie (b).
2. À chaque point : arrivé à moins de 1,5 m, une pause, puis il repart seul vers le suivant ; les pauses lues aux
   heures des lignes : courtes de 2 à 10 s, une longue (12 à 28 s) environ une fois sur cinq → bon.
3. Pendant chaque pause, il se tourne vers le dehors (écart au regard sous 25°, la tolérance du `Turn` est d'environ
   20°), **sans glisser alors que le point visé vient de changer** (deux lectures dans la pause, à moins de 0,3 m), puis
   repart vers le point suivant → bon (réponse 3 b).
4. Le tour complet (environ 3 min) : les 12 points puis le premier, aucun arrêt, aucune glissade, jamais planté plus de 30 s → bon.
5. Les deux rondiers : chacun son pas, aucun ne bloque l'autre → bon.
6. `essai_lacher_ronde` : un seul ordre par homme, chacun rejoint sa tranche → bon.
7. Le troisième homme suit sa journée, un lancement.
- Décompte de l'écran noir (fiche 14).

### Relecture du pair (17/10)
- **Alex fait la voie (a)** (mécanisme seulement) : arrivé au point (arrêt à 1 m ± 0,5, état du personnage changé par
  la marche), l'arbre appelle le Lua, qui pose le point suivant dans une variable de cerveau `vec3` ; un second appel
  écrit dans les variables de l'arbre une pause demandée ou non, et la longue pause est tirée dans l'arbre une fois sur
  cinq ; puis l'attente (20 s ± 8, 6 s ± 4, ou 200 ms). Ni minuterie ni guet. Notre variante (la pause tirée par le
  socle, écrite dans `data.ronde_pause`) est équivalente et garde le hasard du côté du socle.
- **Les pièges d'`ExecuteLua`** : chaque appel sous `pcall(function() … end)` (une erreur non attrapée casse la
  branche, l'homme se fige), l'erreur écrite au journal ; jamais de commentaire Lua dans `code` (tout le reste est coupé
  sans bruit) ; une seule instruction qui appelle une fonction du module. Le code tourne bien sur le personnage qui joue
  l'arbre (`entity.this.id` chez Alex) ; aucun cas « hors du personnage » vu.
- **La ronde de Scriptorium** (`ronde_tracee`, `nuit_du_camp`) : une boucle (JoVenGer trace au moins 3 points, la boucle
  se ferme d'elle-même) ; redécoupée en 24 points à égale distance ; six gardes de quart espacés, à cadence commune,
  et c'est Scriptorium qui les espace (le point de départ) ; points gardés dans le repère du camp ; le jour et la nuit.
  La borne de 32 points couvre ses 24.
- **Ce qui change dans la fiche** : l'appel sous `pcall` dans l'arbre et dans la liaison, sans commentaire ; le chemin
  redonné par Scriptorium à chaque fondation ; jour et nuit. Les recommandations des quatre questions sont confirmées.

### Questions à JoVenGer (après relecture par le pair)
1. **La voie** : (a) l'arbre appelle le Lua à chaque point, la pause tirée par le socle (Recommandé : aucune attente, le
   hasard vérifié au banc, la forme du jeu existe) ; (b) le guet de 5 s relit les arrivées (jusqu'à 5 s de plus à chaque
   point) ; (c) tout le chemin dans le cerveau (aucun exemple dans le jeu, à sonder d'abord).
2. **Plusieurs hommes sur une ronde** : (a) chacun part du point le plus proche de lui, et Scriptorium peut donner le
   point de départ pour les espacer (Recommandé, avec le pair : Scriptorium espace déjà ses six gardes de quart) ; (b) le socle les
   espace lui-même, à égale distance le long du chemin ; (c) ensemble, l'un derrière l'autre.
3. **La pause** : (a) debout, rien d'autre, comme le principe d'Alex (Recommandé, avec le pair ; un geste pourra
   venir après l'avoir vu) ; (b) se tourner vers le dehors à chaque pause ; (c) le jour, regarder autour aux pauses longues.
4. **La forme du chemin** : (a) en boucle par défaut, en aller-retour si la tenue le demande (Recommandé, avec le
   pair : la ronde tracée de Scriptorium est une boucle) ; (b) en boucle seulement ; (c) en aller-retour seulement.

- **Réponses de JoVenGer (17/10)** : 1 (a) l'arbre appelle le Lua à chaque point ; 2 (a) chacun part du point le plus
  proche, Scriptorium donne le départ pour espacer ses gardes ; **3 (b) à chaque pause, il se tourne vers le dehors** ;
  4 (a) en boucle par défaut, en aller-retour sur demande.

### V73 d 2, fait (17/10) : la ronde
- **La tenue « ronde »** (`hommes.tenir`) : `chemin` (2 à 32 points du monde, copié), `aller_retour`, `depart` ; refus
  `chemin_invalide` (sans chemin, un seul point, plus de 32, un point sans x ou sans y, un départ hors du chemin ou non
  entier). Une autre activité ne garde pas de chemin. `memes_tenues` compare le chemin point par point.
- **Le départ** (règle ajoutée en codant, à confirmer en jeu) : le point `depart` vaut pour l'ordre donné quand la tenue est
  posée ; ensuite (rechargement, secours, reprise après une règle plus forte), le point le plus proche de l'homme :
  ses gardes restent espacés, et aucun ne retraverse le camp pour revenir à son point de départ.
- **Le pas** (`hommes.pas_de_ronde`, confié à la liaison au démarrage des hommes) : le point suivant (boucle, ou
  demi-tour aux deux bouts) ; la pause tirée au hasard du socle, en mémoire (6 s ± 4, longue une fois sur 5 : 20 s ± 8,
  jamais sous 500 ms) ; **le point regardé pendant la pause : à `regard_m` (10 m) vers le dehors, du centre du camp à
  travers le point atteint** (réponse 3 b ; sans camp, le point suivant) ; une arrivée n'est comptée que si l'homme est à
  moins de `secours_arrivee_m` (3 m) du point.
- **La liaison** : l'ordre « ronde » pose le premier point puis l'activité 13 ; `liaison.au_point_de_ronde(entite,
  donnees)` pose le point suivant et le regard, écrit `ronde_pause`, retient le but et compte les pas, une ligne au
  journal par pas ; sans accroche ni pas, rien ; une erreur, au journal. Le poste d'essai dit en plus l'écart au but
  de l'ordre et les pas de ronde (la mesure promise en V73 d 1).
- **Le secours** : le but d'un rondier est son point visé ; son compte repart de zéro à chaque arrivée depuis le
  battement d'avant, ou s'il est au point quitté (sa pause) ; bloqué sans arrivée, il est posé près du point visé.
- **La branche 13** : debout ; puis, tant que l'ordre tient : la marche (1 m ± 0,5, délai de la marche), « arrivées »
  + 1, la pause par défaut (2 s), l'appel `pcall(function() Scriptorium.jeu.au_point_de_ronde(entity, data) end)`, le
  `Turn` vers le regard, l'attente de `$ronde_pause` ; le pouls en parallèle.
- **Valeurs en données** : sept dans `hommes.reglages` (`ronde_points_max`, `ronde_pause_ms`, `ronde_pause_ecart_ms`,
  `ronde_longue_ms`, `ronde_longue_ecart_ms`, `ronde_longue_sur`, `ronde_pause_min_ms`) ; deux dans `hommes.cerveau`
  (`ronde_arret_cm`, `ronde_ecart_cm` ; 38 variables de cerveau) ; la section « rondes » au catalogue (vingt-sept
  sections), la ronde d'essai `pourtour` en `rayon_m` (16) et `nombre_de_points` (12), réglables.
- Commandes d'essai `essai_tenir_ronde` (les deux premiers hommes, partis des points 1 et 7) et `essai_lacher_ronde`
  (136 commandes).
- **Banc** : 7 557 vérifications (dont 2 000 et plus pour les pauses) ; sept essais (la tenue et le registre ; le départ, la boucle, l'aller-retour ; les pauses sur 1 000 pas,
  le même hasard ; le regard vers le dehors ; le secours ; le rechargement et l'accroche ; le garde-fou de la ronde
  d'essai, le meuble le plus proche à 2,7 m) ; la liaison sur un faux moteur (le point, le regard, la pause, le
  journal ; sans accroche, sans pas, une panne, une entité absente) ; contrôle statique de la branche 13 et des appels
  au Lua (sous `pcall`, sans commentaire, sur une ligne). Contrôle d'absence : toujours 32 lignes de forme.
- Garde-fous éprouvés par sept erreurs injectées, toutes attrapées : l'appel sans `pcall`, un commentaire dans l'appel, le
  `Turn` retiré, la pause non écrite par la liaison, le regard tourné vers le point suivant, le secours de la ronde
  retiré, le départ donné jamais pris.

### Mesuré en V73 d 2 (17/10) : la ronde, acquise
- **Issue 0** : les trois hommes à l'exercice, 20 valeurs écrites dans chaque cerveau (les deux de la ronde comprises),
  un lancement chacun, pouls qui avance ; la lecture nouvelle « à x m de son but » marche (2,1 à 2,6 m à l'exercice,
  arrêt de la marche à 2 m ± 0,5).
- **Issue 1, l'appel** : `ExecuteLua` est joué dans notre interruption, et `entity` est bien le personnage (la liaison le
  retrouve par son nom, aucun nom à accorder) : une ligne « pas de ronde » à chaque point, 33 pas en environ 4 min pour
  deux rondiers, aucune erreur, aucun « aucun pas ».
- **Issue 2** : arrivée à 1,2 à 1,7 m du point ; les pauses écrites par le Lua sont tenues par le `Wait` de l'arbre
  (lues aux heures des relevés : 4,4 s puis 27 s pour Jan) ; de 2,2 à 27,2 s, 9 longues sur 33 (une sur cinq attendue :
  6,6 ± 2,3) ; arrivées = pas + 1 chez les deux : aucun point sauté.
- **Issue 3** : **à chaque pause, tourné vers le dehors** (écart au regard de 0 à 8° dans les relevés de pause) ; aucune
  glissade : l'écart au but suivant reste fixe pendant toute la pause, alors que le point visé vient de changer.
- **Issues 4 et 5** : la boucle vue (Mikuláš du point 12 au point 1) ; les deux rondiers, chacun son pas, aucun ne
  bloque l'autre.
- **Issue 6** : la ronde lâchée, un ordre chacun (compteur 2 → 3), retour à l'exercice en environ 13 s, aucune relance ; le poste disait « ronde lâchée pour 3 homme(s) » pour deux tenus (lâcher une tenue absente rend vrai) :
  corrigé, il ne compte plus que les hommes tenus (vérifié au banc, pas en jeu).
- **Issue 7** : le troisième homme suit sa journée (exercice), un lancement.
- **En passant** : l'archer, hors de la ronde, torse nu sans combat (habillé sur deux vues, dévêtu sur les deux
  suivantes du même tour de vue), puis rhabillé en moins de 90 s, sans ligne au journal (le tour de la garde de la
  tenue est silencieux) : sans doute par le tour, non prouvé (fiche 13).
- **Pas vu en jeu** : l'aller-retour, la nuit, le secours d'un rondier (coupé ; prouvé au banc), la reprise après un
  rechargement (la règle du départ), une marche abandonnée (point sauté).
- **À faire confirmer par JoVenGer** : la règle du départ ajoutée en codant (après un rechargement, un secours ou une
  règle plus forte, le point le plus proche) ; et la proposition du pair, une accroche « ronde reprise » (l'homme, le
  point de reprise) par laquelle Scriptorium redonnerait lui-même le départ, donc l'espacement de ses six gardes de
  quart ; sans accroche prise, le défaut s'applique.
- **Réponses de JoVenGer (17/10, après la séance)** : la règle du départ est confirmée (le point le plus proche par
  défaut), **avec l'accroche « ronde reprise »**, dans un petit pas à part (V73 d 2 bis : fiche, pair, code, banc) ; la
  borne des lignes de forme du jeu à 32 lui va.

## V73 d 2 bis — l'accroche « ronde reprise » (17/10, à relire par le pair)

### Le périmètre
- Choix de JoVenGer (17/10, proposé par le pair) : quand un rondier **reprend** sa ronde (après un rechargement, un
  secours, ou une règle plus forte qui le lâche, comme une bataille), le socle demande à Scriptorium d'où il repart ;
  sans réponse, le point le plus proche (la règle confirmée). Scriptorium peut ainsi redonner lui-même l'espacement de
  ses six gardes de quart.
- Mécanique seulement : le socle demande et applique ; **quel** point, c'est Scriptorium.

### Le constat (code relu le 17/10)
- Les accroches des hommes (`hommes.accroches`, `hommes.accrocher`) ne font que prévenir : `appeler` rend seulement
  « prise ou non » (`apres_le_rhabillage`, `piece_otee`). Celle-ci doit **rendre une réponse** (un numéro de point).
- Scriptorium ne peut pas redonner le départ par la tenue : reposer la même ronde avec un autre `depart` change la
  tenue, mais pas l'activité ni le lieu, donc aucun ordre ne part (`ordonner_un_homme` ne redonne l'ordre que si
  « activité@lieu » change). D'où l'accroche.
- Le point de reprise se choisit dans `ordonner_un_homme`, seul endroit où part l'ordre de ronde ; « à la pose » (l'ordre
  donné par `hommes.tenir`) se distingue déjà de la reprise (`a_la_pose`).

### Comment ce serait fait
1. **Une accroche de plus**, `ronde_reprise`, dans `hommes.accroches`, posée par `hommes.accrocher("ronde_reprise", f)`.
2. **Quand** : à chaque ordre de ronde qui n'est pas donné à la pose de sa tenue (question 1). À la pose, Scriptorium
   donne lui-même `depart` s'il le veut.
3. **Ce qu'elle reçoit** : `f(id, { lieu, plus_proche, points })` : l'homme, le lieu de la ronde, le numéro du point le
   plus proche de l'homme (le défaut), le nombre de points du chemin.
4. **Ce qu'elle rend** : un numéro de point, entier de 1 à `points` ; ou rien (le point le plus proche). Plusieurs
   accroches : la première réponse valable l'emporte, dans l'ordre où elles ont été posées. Une réponse hors du chemin
   ou non entière : refusée, une ligne au journal, le point le plus proche. Une accroche en panne : sous `pcall`, une
   ligne au journal, le point le plus proche.
5. **Une ligne au journal par reprise** : « Hommes : « Jan Kladivo » reprend la ronde « pourtour » au point 4 (le plus
   proche) », ou « (donné par l'accroche) ».
- Rien au registre, aucune valeur nouvelle, rien dans l'arbre ni dans la liaison.

### Essais au banc
- L'accroche se pose ; une accroche d'un nom inconnu reste refusée.
- À la pose, elle n'est pas appelée ; à la reprise après un rechargement (`relancer`, puis le battement), elle l'est une
  fois par rondier, avec le lieu, le point le plus proche et le nombre de points ; le point rendu devient le premier
  point de l'ordre et le point visé.
- Rien de rendu : le point le plus proche. Rendu 0, 13 (sur 12), 2,5 ou « 3 » : refusé, une ligne, le point le plus
  proche. En panne : une ligne, le point le plus proche. Deux accroches, la première sans réponse : la seconde l'emporte.
- La reprise après une règle plus forte (une tenue de bataille posée puis lâchée) appelle l'accroche ; un homme qui
  n'est pas de ronde ne l'appelle jamais.

### Essai en jeu (question 2) : grille écrite avant la séance
`playline3`, secours coupé, deux rondiers sur la ronde d'essai (partis des points 1 et 7). Une commande d'essai pose une
accroche d'essai, qui rend pour chaque homme le point opposé au plus proche (plus proche + 6, modulo 12) et l'écrit au
journal ; puis une tenue de rassemblement (rang 2) posée sur les deux, et lâchée 20 s plus tard.
1. Au lâcher, une ligne « reprend la ronde … au point k (donné par l'accroche) » par homme, k opposé au plus proche ; et
   chacun marche vers ce point, puis reprend sa ronde → bon.
2. L'accroche d'essai retirée, même manœuvre : « (le plus proche) », chacun repart du point le plus proche → bon.
3. Aucune ligne « reprend » : la reprise ne passe pas par l'ordre de ronde → lire le journal, un seul changement.
- Décompte de l'écran noir (fiche 14).

### Questions à JoVenGer (après relecture par le pair)
1. **Quand l'accroche est-elle appelée ?** (a) à chaque reprise seulement : rechargement, secours, règle plus forte
   (Recommandé : à la pose, Scriptorium donne déjà le départ) ; (b) aussi à la pose quand Scriptorium n'a pas donné de
   départ ; (c) seulement après un rechargement.
2. **L'essai** : (a) au banc, puis un court essai en jeu (rassemblement posé puis lâché, avec et sans l'accroche
   d'essai), qui montre aussi la reprise d'une ronde, pas encore vue (Recommandé) ; (b) au banc seulement (aucun
   changement du côté du jeu).

## Règles en données (catalogue de `reglages.lua`)
- `hommes.reglages` : `secours_delai_s` (30), `secours_progres_m` (1), `secours_arrivee_m` (2), `secours_max` (2) ;
  `camp.reglages.ecart_d_abord` (2,4 m).
- Une table nouvelle `hommes.priorites` (nom de règle → rang), dans le catalogue (V73 b 3).
- V73 b : `hommes.cerveau.relances_max` (3) et `relances_fenetre_ms` (60 000) ; `hommes.reglages.tenue_max_h` (24) et
  `journee_du_socle` (vrai).
- V73 d 1 : `hommes.reglages.regard_m` (10) ; `hommes.cerveau.poste_arret_cm` (50), `poste_ecart_cm` (10),
  `poste_geste_ms` (60 000), `poste_geste_ecart_ms` (30 000).
- V73 d 2 : `hommes.reglages.ronde_points_max` (32), `ronde_pause_ms` (6 000), `ronde_pause_ecart_ms` (4 000),
  `ronde_longue_ms` (20 000), `ronde_longue_ecart_ms` (8 000), `ronde_longue_sur` (5), `ronde_pause_min_ms` (500) ;
  `hommes.cerveau.ronde_arret_cm` (100), `ronde_ecart_cm` (50) ; la table `hommes.rondes` (section « rondes » : la
  ronde d'essai, `rayon_m` 16, `nombre_de_points` 12).

## Essais au banc (`essais/lua/essai_hommes.lua`)
- Une activité de siège donne l'ordre 10 sur la bonne place ; de lit, l'ordre 11 ; de point, l'ordre 9 avec le point.
- Le secours ne pose l'homme qu'après le délai sans progrès, et sur une place libre.
- L'arbitre : une règle plus faible ne reprend pas un homme tenu ; à la libération, la règle d'en dessous reprend.
- La tranche (règle de JoVenGer : une tâche sans fin s'arrête au changement de tranche ; rappel du pair, 16/10) : la
  journée n'a pas de trou, deux tranches qui se suivent n'ont jamais la même activité, et chaque changement de tranche
  donne un nouvel ordre, donc un nouveau compteur, qui fait finir la tenue du comportement long (fiche 12).

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
- V73 d, jeu (lecture seule, `Scripts.pak`) : `AI/profession/guard/so_guardspot.xml`, `so_kzik_guardSpot.xml`,
  `AI/npc/basic/switch/interrupt_lookAround.xml`, `AI/situation/helpers/helpers.xml`, `AI/events/randomEventsBehaviors.xml`,
  `AI/quests/nebakovObrana/nebakovObrana.xml`, `AI/battles/battlegroupcontroller.xml` ; Scriptorium (lecture seule) :
  `NOTE_METIERS_RELEVE.md`, les LISEZMOI de `garde_du_directeur`, `sentinelles_du_camp`, `en_garde_du_camp`,
  `tours_de_guet`, `nuit_du_camp`, `journee_du_camp`, `chef_du_camp`, `paye_des_postes`.
- V73 d 2, jeu (lecture seule, `Scripts.pak`) : `AI/quests/kutnohorskyTurnaj/kutnohorskyturnaj.xml` (une durée écrite
  par `ExecuteLua` dans une variable de l'arbre, puis `Wait`), `AI/quests/lukostreleckaSoutez/shootingRange.xml` (un
  module Lua global appelé), `AI/npc/basic/switch/interrupt_attack.xml`, `AI/_lukas/test_lukas_helper.xml`,
  `AI/animal/basic/switch/animal_getPointOutsideLabelFromBuffer.xml`, `AI/situation/helpers/helpers.xml`,
  `AI/quests/prepadeni/prepadeni.xml`, `AI/quests/stealthMiseZaJindru/stealthMiseZaJindru.xml` ; socle :
  `noyau.lua` (la cadence du battement), `patrouilles.lua`, `hommes.lua` (`secourir`, `memes_tenues`, `tenir`).

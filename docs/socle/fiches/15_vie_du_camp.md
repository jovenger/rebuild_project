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

## V73 d 2 bis — l'accroche « ronde reprise » (17/10, relu par le pair)

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
`playline3`, secours coupé, trois hommes ; `essai_tenir_ronde` (Jan et Mikuláš, partis des points 1 et 7) ; une lecture
toutes les 2 à 3 s (écart au but, pas, regard).
1. **Sans pause** (`essai_ronde_sans_pause`, sur Mikuláš) : ses lignes de pas disent « pause 0 ms », et il repart aussitôt
   vers le point suivant (l'écart au but ne reste jamais fixe deux lectures de suite) ; Jan garde ses pauses → bon. Un
   arrêt à chaque point, ou une attente « 0ms » qui ne finit pas → lire, un seul changement.
2. **Avec l'accroche** (`essai_ronde_accroche_poser`, puis `essai_rassembler_rondiers`, 20 s, puis
   `essai_lacher_rondiers`) : au lâcher, par homme, une ligne de l'accroche d'essai (« regle_plus_forte, plus proche k,
   visé avant j → point opposé ») et une ligne « reprend la ronde « pourtour » au point … (donné par l'accroche,
   regle_plus_forte) » ; chacun marche vers ce point, puis reprend sa ronde → bon.
3. **Sans l'accroche** (`essai_ronde_accroche_retirer`, même manœuvre) : « (le plus proche, regle_plus_forte) », chacun
   repart du point le plus proche → bon.
4. Aucune ligne « reprend » : la reprise ne passe pas par l'ordre de ronde → lire le journal, un seul changement.
5. `essai_lacher_ronde` : un ordre chacun, retour à sa tranche ; le troisième homme suit sa journée.
- Décompte de l'écran noir (fiche 14).

### Relecture du pair (17/10)
- La forme de l'accroche lui va, et les recommandations des questions 1 et 2 aussi ; « la première réponse valable,
  sinon le plus proche », une ligne par reprise, rien au registre : bon.
- **Ce que fera Scriptorium** (`nuit_du_camp`) : six gardes de quart sur un seul tour de 24 points, partis à 60° l'un de
  l'autre, **sans pause** : même pas, même écart (règle de JoVenGer du 22/09 : « pas tous collés, à distance égale l'un
  de l'autre » ; les pauses au hasard les regroupaient ; Alex avait un drapeau « pas de pause » par homme). **Il manque
  donc à la ronde elle-même** une ronde sans pause : `hommes.tenir(id, "ronde", { …, pauses = false })`, sans arrêt, et
  donc sans demi-tour vers le dehors (la réponse 3 b ne vaut que là où il y a des pauses). À combler avant la nuit.
- **L'accroche a besoin de deux choses de plus** : `precedent`, le point que l'homme visait avant la reprise ; et
  `raison` (rechargement, secours, règle plus forte), pour le journal et pour Scriptorium. Et d'une **lecture au
  guichet** du point courant de chaque rondier (`hommes.ronde_point(id)`) : pour placer un garde à 60° des autres, il
  faut savoir où ils sont.

### Ce qui s'ajoute, d'après la relecture
6. **L'appel reçoit aussi** `precedent` (le point visé avant la reprise ; rien après un rechargement : le cerveau repart
   de zéro, et la mémoire d'avant ne vaut pas pour une autre sauvegarde) et `raison` : « rechargement » (l'ordre
   redonné par `hommes.relancer`), « secours » (l'homme posé près de son but), « regle_plus_forte » (sinon : une règle
   plus forte l'a tenu, puis lâché). La ligne du journal dit la raison.
7. **La lecture** `hommes.ronde_point(id)` : pour un rondier, { lieu, vise, quitte, pas, points } ; sinon rien. En
   mémoire seulement, comme l'état de la ronde.
8. **La ronde sans pause** (question 3) : `pauses = false` dans la tenue (vrai par défaut), comparé par
   `memes_tenues`, gardé au registre avec la tenue. Le pas rend alors une pause de 0 (« 0ms », forme du jeu : 2 emplois,
   et « 0s » 18 fois, `AI/quests/utokNaNebakov/utokNaNebakov.xml`, `AI/crime/playstartleanimation.xml`), sans le
   plancher de 500 ms, et un regard vers le point suivant (aucun demi-tour) ; le hasard des pauses n'est pas tiré. Rien
   ne change dans l'arbre : il attend 0 ms et se tourne vers où il va.
- L'essai en jeu (si la question 2 le veut) montre en plus une ronde sans pause : les deux rondiers repartis, l'un des
  deux tenu sans pause.

### Questions à JoVenGer (après relecture par le pair)
1. **Quand l'accroche est-elle appelée ?** (a) à chaque reprise seulement : rechargement, secours, règle plus forte
   (Recommandé, avec le pair : à la pose, Scriptorium donne déjà le départ) ; (b) aussi à la pose quand Scriptorium n'a pas donné de
   départ ; (c) seulement après un rechargement.
2. **L'essai** : (a) au banc, puis un court essai en jeu (rassemblement posé puis lâché, avec et sans l'accroche
   d'essai), qui montre aussi la reprise d'une ronde, pas encore vue (Recommandé, avec le pair) ; (b) au banc seulement
   (aucun changement du côté du jeu).
3. **La ronde sans pause** (le manque relevé par le pair, pour la nuit de Scriptorium) : (a) dans ce pas, l'option
   `pauses = false` : aucun arrêt, aucun demi-tour vers le dehors, le regard vers le point suivant (Recommandé : la nuit
   de Scriptorium en a besoin, et l'essai en jeu la montrera) ; (b) dans un pas à part, juste après ; (c) non, toujours
   des pauses.

- **Réponses de JoVenGer (17/10)** : 1 (a) à chaque reprise seulement ; 2 (a) banc, puis un court essai en jeu ; 3 (a) la
  ronde sans pause dans ce pas.

### V73 d 2 bis, fait (17/10)
- **L'accroche `ronde_reprise`** (`hommes.accrocher`) : appelée à chaque ordre de ronde qui n'est pas donné à la pose de
  sa tenue, `f(id, { lieu, plus_proche, points, precedent, raison })` ; elle rend un point (entier de 1 à `points`) ou
  rien. Une fonction nouvelle, `demander`, prend la première réponse valable dans l'ordre des accroches ; une réponse
  refusée ou une panne : une ligne au journal, le point le plus proche. Une ligne par reprise : « reprend la ronde « … »
  au point k (le plus proche | donné par l'accroche, raison) ».
- **La raison** : « rechargement » (posée par `relancer`, et pour un personnage refait, dont le cerveau est neuf),
  « secours » (posée par le secours), sinon « regle_plus_forte » ; en mémoire, effacée à chaque ordre. **Le point visé
  d'avant** : l'état de la ronde n'est plus effacé quand l'homme passe à une autre activité ; s'il reprend la même ronde
  (même lieu), son ancien point visé est donné ; rien après un rechargement.
- **La lecture** `hommes.ronde_point(id)` : { lieu, vise, quitte, pas, points }, ou rien (pas de ronde, ou une autre
  activité).
- **La ronde sans pause** : `pauses = false` dans la tenue (vérifié : vrai ou faux seulement ; écrit seulement à faux ;
  comparé par `memes_tenues`, gardé au registre) ; le pas rend 0 ms, le regard vers le point suivant, sans tirer le
  hasard des pauses.
- **Poste d'essai** : `essai_ronde_accroche_poser` et `essai_ronde_accroche_retirer` (l'accroche d'essai, posée une fois
  chez les hommes, qui rend le point opposé au plus proche quand elle est active), `essai_rassembler_rondiers` et
  `essai_lacher_rondiers` (les deux premiers hommes, rang 2, à la corvée), `essai_ronde_sans_pause` (le second
  rondier) : 141 commandes.
- **Banc** : 7 638 vérifications, cinq essais de plus (l'accroche à la pose et au rechargement ; les réponses rien,
  refusées, en panne, plusieurs accroches ; la règle plus forte et le secours, la raison et le point d'avant ; la
  lecture ; la ronde sans pause). Garde-fous éprouvés par cinq erreurs injectées, toutes attrapées : l'accroche appelée
  à la pose, la raison du secours oubliée, le point visé d'avant perdu, « sans pause » ignoré, une réponse jamais
  vérifiée. Rien dans l'arbre ni dans la liaison ; contrôle d'absence inchangé (32).

### Mesuré en V73 d 2 bis (17/10) : la reprise et la ronde sans pause, acquises
- **Issue 1, sans pause** : Mikuláš, rendu sans pause en pleine ronde, écrit « pause 0 ms » à chaque pas suivant (16
  pas) ; il va de point en point, tourné vers le point suivant (écart au regard de 0 à 8°) ; Jan garde ses pauses.
  **Il reste un court arrêt d'environ 2 s à certains points** (l'écart au but fixe deux lectures de suite) : la marche
  finit à 1 m du point, l'appel au Lua et le `Turn` passent, puis la marche repart. Ce n'est pas une marche continue ;
  pour la ronde de nuit de Scriptorium (même pas, même écart), à regarder si l'écart entre gardes s'en ressent.
- **Issue 2, avec l'accroche** : rassemblement (rang 2) posé puis lâché ; au lâcher, l'accroche d'essai est appelée
  pour chacun avec « regle_plus_forte », le point le plus proche (12) et le point visé d'avant (8 et 4), rend le point 6
  (opposé au plus proche) ; le journal dit « reprend la ronde « pourtour » au point 6 (donné par l'accroche,
  regle_plus_forte) » ; les deux marchent environ 20 m jusqu'au point 6, puis reprennent leur ronde.
- **Issue 3, sans l'accroche** : « au point 11 (le plus proche, regle_plus_forte) », courte marche, ronde reprise.
- **Issue 5** : la ronde lâchée (« pour 2 homme(s) » : le décompte corrigé), retour à l'exercice ; le troisième homme
  suit sa journée ; un lancement chacun, aucun arrêt ; 30 pas, aucune erreur ni réponse refusée.
- **La reprise d'une ronde est donc vue en jeu** (après une règle plus forte), ce qui manquait à V73 d 2.
- **Pas vu en jeu** : les raisons « rechargement » et « secours » (prouvées au banc), `hommes.ronde_point` (banc), une
  accroche de Scriptorium qui espace vraiment six gardes.
- **Gardé pour l'essai de nuit** (le pair, 17/10) : ce qui compte la nuit, c'est que les gardes restent espacés ; des
  arrêts irréguliers d'un homme à l'autre feraient dériver l'écart. **La mesure qui tranchera** : trois rondiers sans
  pause partis à 120° l'un de l'autre, 10 min, l'écart entre eux relevé chaque minute ; s'il reste à peu près égal, les
  arrêts ne gênent pas. Sinon, une piste à la fois : (1) pour une ronde sans pause, un arrêt de marche plus large (2 à
  3 m au lieu de 1 m), pour que l'appel au Lua et la marche suivante partent avant l'arrêt ; (2) les marches du jeu le
  long d'un chemin de points (`AI/move/moveinformation_tagpointroute.xml`, à lire d'abord), qui suivent des points du
  niveau : il faudrait poser des points à nous, plus lourd.

## V73 e — le rassemblement (17/10, relu par le pair ; réponses recommandées prises d'office)

### Le périmètre
- **Le mécanisme** : rejoindre une place sur un **arc autour d'un centre**, face au centre ou au dehors, en courant ou en
  marchant, en quittant toute tâche, et s'y tenir jusqu'à ce que la règle lâche l'homme. **Ce pas le prouve sur le
  briefing** de Scriptorium (le rassemblement avant mission) ; l'anneau d'alerte (face au dehors, arme tirée) et le
  cercle des duels s'en serviront à leur pas.
- **Qui, quand, où, combien de temps** : Scriptorium (le Directeur décide la mission, choisit les aptes, garde une
  garnison, mène le discours et le lâche). Le socle tient et lâche.
- **Les 150 m** (réponse 1 a de JoVenGer du 16/10, jamais codée) : un homme à plus de 150 m de son but est posé d'un coup
  sans attendre les 30 s, pour toutes les activités.

### Ce que Scriptorium attend (relu le 17/10, lecture seule, par un agent de recherche : LISEZMOI de
`rassemblement_sans_retard`, `briefing_du_directeur`, `missions_du_directeur`, `garde_du_directeur`, `en_garde_du_camp`,
`sentinelles_du_camp`, `duels_judiciaires`, `hommes_sous_la_carte`, `troupe_chez_elle`, `degel_des_hommes`,
`NOTE_POUR_LE_SOCLE`)
- **Le briefing** : devant le Directeur, à son poste, tourné vers le camp ; les hommes en **demi-cercle à 3 m, de −60° à
  +60°, face à lui** ; ils viennent **en courant** ; « peu importe ce qu'il fait » (entraînement, repas, assis, tir,
  bain), il quitte sa tâche, qui lui est rendue après ; un convoqué qui ne s'est pas rapproché de 1 m en 30 s est posé à
  sa place ; discours de 40 s, réactions, « Rompez ! », les tâches rendues.
- **L'anneau d'alerte** (le ralliement au cor, retiré le 3/10, remplacé par un déploiement) : en anneau, face au
  dehors, arme tirée ; exemptés : le service, le Directeur, les factionnaires, les hommes dehors. À son pas.
- **Le cercle des duels** : un cercle de 10 m, les hommes tournés vers les duellistes, venus en marchant, au plus 90 s ;
  il passe avant toute tâche et tout siège. À son pas, par la même mécanique.
- **Les pièges** : la levée qui fige (chez eux, lever un homme puis le faire courir le figeait : « d'où une course sans
  levée ») ; les assis qui glissent (lever d'abord) ; un homme passé sous la carte ; à 250 m, le jeu ne trace pas de
  chemin ; recréés à 150 m, « on les voyait apparaître ».
- **Contradictions laissées à Scriptorium** : 90 s ou 5 min pour venir, « démarre dès que tous y sont » ou « un retard
  n'empêche pas le discours » (le départ et la fin du discours sont à Scriptorium ; le socle n'a besoin d'aucune
  durée) ; le lieu (devant le bureau du Directeur, ou la zone de briefing derrière les tentes) : c'est le centre que
  donne la tenue. **L'arme** : rien dans aucun document : rangée, comme la garde (réponse 1 a de V73 d).
- **Aucun document ne parle de rangs** : seulement demi-cercle, anneau, cercle, et la colonne de marche (V73 f).

### Le constat (code relu le 17/10)
- La règle « rassemblement » est au rang 2 (après la bataille) ; une tenue la donne sur-le-champ et rend la règle
  d'en dessous quand elle est lâchée (vu en V73 b 3, V73 d 1, V73 d 2 bis) ; mais elle n'est qu'une **marche** (ordre 9)
  au point donné, au pas, sans place à soi ni direction.
- Plusieurs hommes au même rassemblement iraient au même point (le secours les poserait l'un sur l'autre, la liaison les
  écarte d'un mètre).
- **Les 150 m ne sont pas codés** : le secours n'attend que le délai sans progrès.
- La branche 12 (« tenir un poste ») fait déjà : debout, marche à un arrêt court, `Turn` vers un point de regard, tenue
  avec le pouls, le geste « regarder autour » le jour. Il lui manque la course.

### Ce que le jeu fait (lu dans `Scripts.pak`, lecture seule)
- **La course** : le même `Move`, `speed="Run"` (124 emplois ; « Walk » 498, « Sprint » 40) ; la vitesse peut être une
  variable de l'arbre de type `enum:movementSpeed` (46 emplois de `$speed`), écrite par une `Expression`
  `$speed = $enum:movementSpeed.run` (`AI/crime/followhelpingnpc.xml`, `AI/_lukas/test_lukas_helper.xml`), déclarée
  `<Variable name="speed" type="enum:movementSpeed" …/>`. Aucun ternaire sur un enum n'est relevé : la valeur s'écrit
  sous une condition.
- **Les formations du jeu** (`MakeFormation`, `FormationFollower`, `EndFormation` ; 63 définitions dans
  `AI/FormationDefinitions.xml`, dont `dogCompanion_followHeel`) suivent un chef qui bouge (`AI/battles/battlegroupcontroller.xml`,
  `AI/move/moveUtils.xml`) : une piste pour V73 f (suivre Henry), pas pour une place fixe.
- Recherche d'un exemple existant (règle du 15/10) : celle de V73 d 2 (aucun mod KCD2 sur ce sujet) ; les arbres du jeu
  ci-dessus suffisent.

### Comment ce serait fait
1. **La tenue « rassemblement » avec un centre** : `hommes.tenir(id, "rassemblement", { activite = "rassemblement", lieu,
   centre, cap, rayon, ouverture, face, allure, fin })`. `centre` : un point du monde ; `cap` : la direction du milieu de
   l'arc vu du centre (cap de boussole) ; `rayon` (défaut `rassemblement_rayon_m`, 3) ; `ouverture` en degrés (défaut
   `rassemblement_ouverture`, 120 ; 360 : un cercle entier) ; `face` « centre » (défaut) ou « dehors » ; `allure`
   « course » (défaut) ou « marche ». Valeurs refusées sinon (`rassemblement_invalide`). **Sans centre**, comme avant :
   une marche au point `position`.
2. **Les places** (`hommes`) : les hommes que tient le même rassemblement (même lieu, leur tenue la plus forte), dans
   l'ordre du camp, répartis sur l'arc (un seul : au milieu ; un cercle entier : à égale distance ; sinon d'un bout à
   l'autre) ; **jamais à moins de `ecart_entre_hommes` (1,2 m) l'un de l'autre** : ce qui ne tient pas sur l'arc passe
   sur un second arc, `ecart_entre_hommes` plus loin, et ainsi de suite. Le point regardé : le centre, ou le dehors à
   `regard_m`.
3. **Une place qui change redonne l'ordre** : la place (son numéro et le nombre de places) entre dans la signature de
   l'ordre (« activité@lieu#2/3 »), et poser ou lâcher une tenue de rassemblement redonne sur-le-champ l'ordre de chacun
   des hommes de ce rassemblement dont la place a changé. Le secours repart de zéro à chaque nouvel ordre.
4. **L'ordre** : la liaison reçoit l'allure en plus (« course », « marche » ou rien) ; avec un regard, elle pose le
   point, le regard et **l'allure** (`scriptorium_allure`, entier : 1 course, 0 sinon, remise à 0 à chaque ordre de
   poste, sinon une garde qui suit un briefing courrait), puis l'ordre 12 ; la ligne du journal dit « en courant ».
5. **La branche 12** : avant la marche, `$allure = $enum:movementSpeed.walk`, puis, si `$scriptorium_allure == 1`,
   `$allure = $enum:movementSpeed.run` ; le `Move` prend `speed="$allure"`. Le reste ne change pas (le `Turn` vers le
   regard, le pouls, le geste « regarder autour » le jour : question 2).
6. **Les 150 m** (`secours_loin_m`, 150) : au-delà, le secours n'attend pas le délai ; il reste compté (au plus
   `secours_max`), jamais en combat ni en conversation, jamais pour un homme encore assis à sa place d'avant ; seulement
   pour un but au camp, et jamais sous les yeux d'Henry (ci-dessous, d'après la relecture du pair).
- **Valeurs en données** : `hommes.reglages.rassemblement_rayon_m` (3), `rassemblement_ouverture` (120),
  `secours_loin_m` (150) ; `hommes.points.briefing`, le centre d'essai (−10 ; −3, cap 270, à l'ouest du camp, à
  l'écart des meubles) ; une variable de cerveau de plus, `scriptorium_allure` (39).
- Rien au registre de plus que la tenue (son centre et ses options).

### Essais au banc
- Les places : un homme au milieu de l'arc, face au centre ; trois hommes à −60°, 0°, +60° ; un cercle entier de quatre à
  90° ; « dehors » : le regard au dehors ; neuf hommes sur 3 m et 120° : un second arc, jamais deux hommes à moins de
  1,2 m.
- Trois hommes convoqués l'un après l'autre : à chaque fois, chacun a un ordre vers sa place du moment, jamais deux la
  même ; un lâché : les autres se resserrent, un ordre chacun.
- L'allure : « course » par défaut, « marche » si la tenue le dit ; la garde n'en a pas ; les valeurs refusées.
- La liaison (faux moteur) : l'allure 1 avec un rassemblement, 0 avec une garde.
- Les 150 m : à 151 m, posé au premier battement ; à 149 m, pas avant le délai ; un but hors du camp (60 m du centre) :
  jamais avant le délai. La vue d'Henry : sous ses yeux, le secours attend, une ligne au journal ; il détourne le regard,
  le secours pose ; sans lecture, il pose.
- Contrôles statiques : la branche 12 écrit l'allure sous condition et la donne au `Move` ; la variable d'arbre et la
  variable de cerveau déclarées ; la liaison écrit `scriptorium_allure`. Le garde-fou : les places du briefing d'essai,
  pour un à neuf hommes, à l'écart des meubles du plan (2,4 m) et en dedans de la palissade.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé ; trois hommes assis sur les bancs (`essai_hommes_asseoir`) ; `essai_briefing` : les trois
convoqués l'un après l'autre, à 3 s d'écart, autour du centre d'essai ; une lecture toutes les 2 s.
1. **La levée, puis la course** : chacun se lève et court (la ligne de l'ordre dit « en courant ») ; un homme qui reste
   assis ou se fige après la levée → le piège noté chez Scriptorium : lire, un seul changement.
2. À chaque convocation, les places se recalculent (un ordre de plus aux déjà convoqués) ; à la fin, trois places
   distinctes, à moins de 1 m de chacune, face au centre (écart au regard sous 25°), sans glisser.
3. Une capture de face : l'arc des trois.
4. `essai_rompre` : un ordre chacun, retour à leur tranche (l'exercice).
5. Les 150 m : au banc seulement (dit tel quel).
- Décompte de l'écran noir (fiche 14).

### Relecture du pair (17/10)
- Les places sur l'arc et la signature de l'ordre : bien vues ; le second arc 1,2 m derrière : un bon défaut (aucun rang
  chez Scriptorium ; l'anneau d'alerte, 34 à 48 postes, ce sont des places de garde).
- **La course chez Alex** (principe) : l'attribut `speed` du `Move`, écrit en clair (`Walk` le plus souvent, `Run`,
  `Sprint`, `Dash`) ; notre variable d'enum vient du jeu. Les pièges de la course après une levée viennent de
  Scriptorium (le suivi de chaque convoqué, l'homme sorti de sa routine qui se fige) : la grille les vise.
- **Les 150 m pour toutes les activités : un vrai piège.** Les sorties sont légitimement à plus de 150 m (un homme de
  métier en ville ou au bois, une troupe en mission, le coursier) : les poser d'un coup les ramènerait au camp.
  **Seulement pour un but au camp** (rassemblement, poste, ronde, repas, travail au camp) ; jamais une sortie, une
  mission, ni suivre Henry, qui a sa propre règle des 60 m.
- **« Hors de la vue d'Henry » se vérifie** (Scriptorium le fait déjà, `arrivee_des_recrues`) : la direction du regard
  d'Henry contre la direction vers le point ; un cosinus au-dessus de 0,5 (Henry regarde à moins de 60° du point) : on
  ne pose pas là, on attend (ou un autre point qu'il ne voit pas).
- **Pour la ronde de nuit** (piste 2 bis, essayée par Alex dans un fichier d'essai seulement, donc sans preuve) : un
  `Parallel` dont une branche fait une seule marche sans fin vers une variable de but, et l'autre, toutes les 150 ms
  environ, regarde la distance au but et donne le point suivant avant l'arrivée (« couper le virage ») : la marche
  change de but sans s'arrêter. À vérifier en jeu, à l'essai de nuit.

### Ce qui change, d'après la relecture
- **Les 150 m** : seulement si le but de l'ordre est **au camp**, à moins de `secours_loin_camp_m` (50 m) de son centre ;
  sans camp, jamais. Une sortie, une mission, une patrouille au loin n'y sont donc jamais soumises.
- **Le secours ne pose jamais un homme sous les yeux d'Henry** (tout secours, pas seulement les 150 m) : la liaison dit
  si Henry regarde à moins de 60° de l'endroit (`secours_vue_cos`, 0,5, le cosinus de l'angle) ; alors le secours
  attend le battement suivant, une ligne au journal la première fois. Sans lecture (pas d'Henry), il pose comme avant.

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **La forme** : (a) un arc autour d'un centre, rayon et ouverture donnés par la tenue, face au centre ou au dehors,
   un second arc quand le premier est plein (Recommandé : couvre le briefing, l'anneau et le cercle des duels) ; (b) des
   rangs ; (c) Scriptorium donne chaque place. **Prise : (a).**
2. **Le geste pendant le rassemblement** : (a) celui de V73 d 1 reste (regarder autour, le jour, 60 s ± 30) ; l'éteindre
   serait un petit pas après si Scriptorium le veut (Recommandé : une chose à la fois, et un homme qui regarde autour
   pendant un discours de 40 s n'est pas choquant) ; (b) aucun geste. **Prise : (a).**
3. **L'allure** : (a) donnée par la tenue, la course par défaut pour un rassemblement (Recommandé : le briefing en
   courant, le duel en marchant) ; (b) toujours en courant. **Prise : (a).**
4. **Les 150 m** (revue après la relecture du pair) : (a) maintenant, seulement pour un but au camp (à moins de 50 m de
   son centre), jamais une sortie (Recommandé, avec le pair) ; (b) pour toutes les activités ; (c) plus tard.
   **Prise : (a).**
5. **Hors de la vue d'Henry** : (a) vérifié pour tout secours : Henry regarde à moins de 60° de l'endroit, le secours
   attend (Recommandé, avec le pair : c'est la règle de Scriptorium) ; (b) seulement pour les 150 m ; (c) non vérifié.
   **Prise : (a).**

### V73 e, fait (17/10) : le rassemblement
- **La tenue « rassemblement » avec un centre** (`hommes.tenir`) : `centre`, `cap`, `rayon` (3), `ouverture` (120), `face`
  (« centre » ou « dehors »), `allure` (« course » par défaut, ou « marche ») ; refus `rassemblement_invalide` ; sans
  centre, une marche au point comme avant. `memes_tenues` compare le centre et les options.
- **Les places** (`place_sur_l_arc`) : les hommes que tient le même rassemblement (même lieu, leur tenue la plus forte),
  dans l'ordre du camp, répartis sur l'arc ; l'écart entre deux places est une corde d'au moins `ecart_entre_hommes`
  (1,2 m) ; le surplus passe sur un second arc, 1,2 m plus loin. Le regard : le centre, ou le dehors à `regard_m`.
- **La signature de l'ordre** porte la place (« rassemblement@briefing#2/3 ») ; poser ou lâcher une tenue redonne l'ordre
  sur-le-champ à chaque homme d'un rassemblement dont la place change (`redonner_au_rassemblement`) ; un homme pris par
  une règle plus forte quitte l'arc, les autres se resserrent au battement.
- **La course** : la liaison écrit `scriptorium_allure` (1 en courant, 0 sinon) avec le point et le regard de l'ordre 12,
  et dit « en courant » au journal ; la branche 12 écrit `` (marche, puis course sous condition) et le `Move` du
  poste prend `speed=""`. 39 variables de cerveau.
- **Les 150 m** : au-delà de `secours_loin_m` d'un but à moins de `secours_loin_camp_m` (50 m) du centre du camp, le
  secours n'attend pas le délai ; une sortie, jamais. **La vue d'Henry** (`liaison.henry_voit`, cosinus au-dessus de
  `secours_vue_cos`, 0,5) : sous ses yeux, aucun secours, une ligne au journal la première fois. La ligne du secours dit
  la distance.
- **Poste d'essai** : `essai_briefing` (convoque l'homme suivant autour de `hommes.points.briefing`, en courant, face au
  centre) et `essai_rompre` (143 commandes).
- **Banc** : 7 815 vérifications ; six essais de plus (les places, le cercle, le dehors, les neuf hommes sur deux arcs ;
  les convocations une à une et le lâcher ; l'allure, les refus, sans centre, la garde ; les 150 m, au camp et en
  sortie ; la vue d'Henry ; le garde-fou du briefing d'essai pour un à neuf hommes) ; la liaison sur faux moteur (l'allure,
  la vue d'Henry). Une ligne de la liaison, identique à une ligne d'Alex (`local d = math.sqrt(dx * dx + dy * dy)`), est
  réécrite à notre façon (contrôle d'absence : 0 ; formes du jeu : 32). Garde-fous éprouvés par cinq erreurs injectées,
  toutes attrapées : la course jamais écrite, la place hors de la signature, les 150 m pour une sortie, la vue d'Henry
  ignorée, aucun second arc.

### Mesuré en V73 e (17/10) : le rassemblement, acquis
- **Issue 1, la levée puis la course** : les trois, assis sur les bancs, convoqués à 3 s d'écart ; les ordres partent
  « en courant » (`scriptorium_allure` à 1) ; chacun se lève et **court** (environ 10 m en 2 à 4 s) ; Ondřej met environ
  9 s à se lever, puis court. **Le piège de Scriptorium (la levée qui fige la course) ne se montre pas** : notre levée du
  dedans (V73 c) suivie de la course marche.
- **Issue 2** : à chaque convocation, les places se recalculent et les déjà convoqués reçoivent leur nouvel ordre
  (Mikuláš de 2/2, à +60°, à 2/3, au milieu ; Jan, à −60°, garde son point, la signature change) ; trois places
  distinctes ; arrivée à 0,1–0,7 m de la place ; **tournés vers le centre** (écart au regard de 1°, 10° et 13°), sans
  glisser (écart au but fixe sur 30 s).
- **Issue 3, l'image** : les trois debout sur l'arc, à des places distinctes, habillés et armés, tournés vers le centre
  (de dos pour Henry, resté au camp).
- **Issue 4** : « Rompez » (`essai_rompre`) : un ordre chacun, retour au pas à l'exercice (arrêt à 2–2,7 m), un
  lancement chacun, aucun arrêt de relance.
- **Pas vu en jeu (banc seulement)** : les 150 m, la vue d'Henry, le second arc (neuf hommes), « face au dehors », un
  arc plein de plus d'hommes, le Directeur au centre (sa place est à Scriptorium).

## V73 f 1 — suivre Henry, à pied (17/10, relu par le pair ; réponses recommandées prises d'office)

### Le périmètre
- **Ce pas** : à pied ; le Directeur en tête (« c'est lui le premier qui me suit »), la troupe en colonne derrière lui ;
  au-delà de 60 m de son chef, l'homme réapparaît 4 m derrière Henry, hors de sa vue (ce qui couvre déjà le voyage
  rapide sur une même carte : à l'arrivée, l'escorte réapparaît près d'Henry, idée validée n° 3 du 15/10).
- **Plus tard, chacun à son pas** : à cheval (V73 f 2 : la monte n'est pas vue chez Scriptorium et y a figé un homme ;
  règle du 16/10, « tous ceux qui sortent du camp partent à cheval ») ; le changement de carte et les intérieurs ;
  « appelez la troupe » (recréée à 200–300 m, hors de vue) ; la garde d'Henry en route.
- **Qui, quand** : Scriptorium (le pliage du camp, les ordres par la conversation du Directeur, jamais au milieu d'un
  dialogue ; camp levé, seuls le Directeur et le colonel restent ; la troupe appelée). Le socle fait suivre et lâche.

### Ce que Scriptorium attend (relu le 17/10, lecture seule, par un agent de recherche : LISEZMOI de
`directeur_en_route`, `troupe_chez_elle`, `intendant_du_camp`, `dialogue_des_mercenaires`, `retour_de_la_troupe`,
`chacun_son_combat`, `combat_exterieur`, `hommes_sous_la_carte`, `degel_des_hommes`, `correctif_passage_de_carte` ;
`NOTE_METIERS`, `NOTE_METIERS_RELEVE`, `CONTRAT_DU_SOCLE` en lecture seule)
- Le Directeur en tête tient l'allure d'Henry (il court ; à cheval quand Henry l'est) ; la troupe en colonne. Mesuré chez
  eux le 3/10 : le Directeur à 1,2 m d'Henry, la troupe à 31 m en moyenne. Réglages de leur règle : `LOIN` 60 m,
  `ARRIERE` 4 m (le Directeur apparaît 4 m derrière Henry si sa dernière place est à plus de 60 m).
- En combat, on se bat d'abord ; la troupe ne s'arrête que si Henry est en danger.
- **Pièges** : des hommes bloqués autour d'Henry ; à 250 m le jeu ne trace pas de chemin ; au-delà d'environ 300 m, le
  jeu ne fait plus vivre personne ; un homme planté (relancé chez eux en 25 s) ; des apparitions visibles (recréés à
  150 m, « on les voyait apparaître ») ; « ne jamais téléporter Henry ».
- **Pas trouvé** : l'espacement et la vitesse chiffrés de la colonne ; le voyage rapide, la nage, Henry qui dort ou entre
  dans une maison.

### Le constat (code relu le 17/10)
- Aucune règle « escorte » ni activité « suivre » ; le Directeur reçoit ses ordres par son morceau (`directeur.activite`,
  `directeur.battre`), pas par l'arbitre.
- **Le secours ordinaire tuerait la suite** : un homme qui suit Henry au pas garde un écart constant ; « moins de 1 m de
  progrès en 30 s » serait vrai à chaque battement, et il serait posé d'un coup.
- La liaison sait lire la position d'Henry (`position_du_joueur`), son cap (`cap_du_joueur`), la position d'un
  personnage (`position_de`), et écrire un WUID dans un cerveau (`GetMyWUID`, déjà fait pour la cible d'une attaque).

### Ce que le jeu fait (lu dans `Scripts.pak`, lecture seule)
- **La fonction de suivi du jeu** : `followNpc` (`AI/move/moveUtils.xml`, `is_function="1"`), appelée par
  `<Function_followNpc leader=… startDistance="5" stopDistance="2.5" walk2run="20" walk2sprint="30" run2walk="10"
  run2sprint="30" sprint2run="20" sprint2walk="10" …/>` (5 emplois, par exemple `AI/quests/budovaniLazni/budovanilazni.xml`).
  Elle fait : si le chef est plus loin que `startDistance`, un `Move` vers son WUID (qui suit un chef qui bouge), arrêt à
  `stopDistance` ; sinon se tourner vers lui et attendre 1 s ; à côté, toutes les secondes, l'allure (marche, course,
  sprint) d'après la distance qui reste, avec ces seuils. `followPlayer` du jeu ne fait que la même chose avec
  `$__player` pour chef.
- Les formations du jeu (`dogCompanion_followHeel`, `followNPC`, `prototypeFollowPlayer`) : un chef qui les fait et des
  suiveurs ; le chien d'Henry (`companion_playerDog`) en est le modèle (idée n° 3) ; pas pour ce pas.
- La monte : `HorseUsageElement` (56 emplois), `Function_moveOnHorse` (16), `GetPlayerHorse` (66) : à lire pour V73 f 2.

### Comment ce serait fait : deux voies (question 2)
- **(a) La fonction du jeu (recommandée)** : la branche 14 du comportement long, debout d'abord, puis `Function_followNpc`
  avec le chef en variable de cerveau `scriptorium_chef` (WUID) et ses huit distances en variables de l'arbre, lues du
  cerveau avec leur défaut ; le pouls à côté. Aucun de nos arbres n'a encore appelé une fonction du jeu avec des
  flottants en variables : issue 1 de la grille.
- **(b) La réécriture à notre façon**, si (a) ne joue pas : un `Move` vers `$scriptorium_chef` arrêté à la distance de
  suite, et une boucle d'allure à côté (la forme de V73 e).

### Le détail de la voie (a)
1. **La règle « escorte »** (rang 2, avec le rassemblement : question 1) et la tenue
   `hommes.tenir(id, "escorte", { activite = "suivre", lieu, chef, fin })` ; `chef` : « henry » (défaut), « directeur »,
   ou le numéro d'un homme ; refus `escorte_invalide` sinon.
2. **La colonne** (question 3) : les hommes que tient la même escorte (même lieu), dans l'ordre du camp ; le premier suit
   le chef de la tenue, chacun suit le précédent. Le rang entre dans la signature de l'ordre (« suivre@escorte#2/3 ») :
   un homme qui quitte la colonne fait redonner leur chef aux suivants.
3. **L'ordre** : la liaison reçoit le chef (l'identifiant d'un personnage, ou « henry ») ; elle écrit son WUID dans
   `scriptorium_chef`, puis l'ordre 14 ; la ligne du journal dit qui suit qui.
4. **La branche 14** : debout ; `Function_followNpc` (chef `$scriptorium_chef`, `startDistance` `suivi_depart_cm` 500,
   `stopDistance` `suivi_arret_cm` 250, les seuils d'allure `suivi_marche_course_m` 20, `suivi_marche_sprint_m` 30,
   `suivi_course_marche_m` 10, `suivi_course_sprint_m` 30, `suivi_sprint_course_m` 20, `suivi_sprint_marche_m` 10 : les
   valeurs du jeu) ; le pouls à côté.
5. **Le rattrapage remplace le secours pour « suivre »** (question 4) : aucun secours ordinaire ; à plus de
   `suivi_loin_m` (60) de son chef, l'homme est posé `suivi_derriere_m` (4) derrière Henry (son cap), sur une place
   libre, jamais sous ses yeux (la vue d'Henry de V73 e), **sans compter dans `secours_max`** (un long trajet en demande
   plusieurs) ; `suivi_loin_m` à 0 : jamais. Jamais en combat ni en conversation.
6. **Le Directeur** (question 5) : un service `directeur.suivre(oui)`, gardé à son registre (il revient au
   rechargement) ; son activité devient « suivre », Henry pour chef, le même ordre, la même branche (son cerveau a déjà
   nos valeurs) ; le même rattrapage. Une escorte dont le chef est « directeur » suit donc la tête de la colonne.
7. **La fin** : la tenue lâchée, l'homme reprend sa tranche ; loin du camp, le but redevient un point du camp et les
   150 m de V73 e le posent au camp au premier battement (Scriptorium fait de même : « tous rentrent d'un coup ») : une
   issue à observer.
- **Valeurs en données** : `hommes.cerveau` : les huit distances (en centimètres pour les deux premières, en mètres pour
  les seuils, entiers) ; `hommes.reglages` : `suivi_loin_m` (60), `suivi_derriere_m` (4) ; la règle « escorte » au rang 2
  (`hommes.priorites`). 41 variables de cerveau (le chef et les huit distances, moins rien).
- Contrôle statique de plus : `followNpc` relu dans `Scripts.pak` à chaque passage du banc, avec ses huit paramètres et
  le type `_wuid` de son chef (une mise à jour du jeu casserait l'appel en silence).

### Essais au banc
- La tenue : refus d'un chef inconnu ; la colonne : le premier suit le chef, chacun le précédent, le rang dans la
  signature ; un homme lâché, les suivants changent de chef (un ordre chacun).
- **Le secours ne prend jamais un suiveur** : il suit à 3 m pendant dix battements sans progrès : aucun secours ; à
  61 m, posé 4 m derrière Henry, plusieurs fois s'il le faut, hors `secours_max` ; sous les yeux d'Henry, il attend ;
  `suivi_loin_m` à 0, jamais ; en combat, jamais.
- Le Directeur : `directeur.suivre` gardé au registre, son ordre « suivre » avec Henry pour chef, rendu au rechargement ;
  lâché, il reprend sa journée.
- La liaison (faux moteur) : le WUID du chef (Henry ou un personnage) écrit avant l'ordre 14 ; un chef introuvable : une
  marche simple, dite au journal.
- Statiques : la branche 14 appelle `Function_followNpc` avec `$scriptorium_chef` et les huit distances ; les variables
  déclarées, lues avec leur défaut ; `followNpc` relu dans le jeu.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé (`secours_max=0` ; le rattrapage n'en dépend pas, il reste actif) ; trois hommes et le
Directeur (`essai_directeur`) ; `essai_escorte` : le Directeur suit Henry, les trois en colonne derrière lui.
1. **L'appel de la fonction** : Henry fait quelques pas (`Marcher 15`) ; chacun bouge, l'écart à son chef baisse puis se
   tient entre 2,5 et 5 m → bon ; aucun ne bouge → lire, la voie (b), un seul changement.
2. **La colonne** : Directeur, puis Jan, Mikuláš, Ondřej, chacun derrière le précédent ; aucun ne dépasse Henry.
3. **La course** : Henry court (`Marcher 10 -Course`) ; ils courent (l'écart à leur chef se maintient).
4. **Le rattrapage** : Henry posé 40 m plus loin, deux fois (`essai_aller_nord`) ; au battement, chacun à plus de 60 m de
   son chef réapparaît 4 m derrière Henry (une ligne au journal par homme), jamais sous ses yeux.
5. **La fin** : `essai_fin_escorte` ; chacun reprend sa tranche ; loin du camp, posé au camp par les 150 m (à observer).
- Décompte de l'écran noir (fiche 14).

### Relecture du pair (17/10)
- La voie (a) par la fonction du jeu : un bon premier pas.
- **Alex n'emploie pas `followNpc`** (mécanisme seulement) : il passe par les **formations du moteur** : un homme est élu
  chef de formation (il suit Henry, et une boucle à côté tient la formation ouverte tant qu'il mène) ; tous les autres
  sont des suiveurs de formation (`FormationFollower`), rangés sur les places d'un modèle de la table des formations
  (`AI/FormationDefinitions.xml`). En repli seulement (la formation ne peut placer l'homme), une chaîne bornée dans le
  temps. À cheval aussi, par la formation (le suiveur monté, « historique du mouvement », un `WaitAction` avant, l'allure
  du chef réglée sur la vitesse mesurée d'Henry) : **à lire avant V73 f 2** (« Réutiliser avant de créer »).
- **La colonne de Scriptorium** (`directeur_en_route`) est un modèle de formation en colonne : le Directeur chef de
  formation, la troupe rangée derrière lui (mesuré le 7/10 : Henry marche 12 s, le Directeur à 1,2 m, la troupe étirée à
  31 m en moyenne). Notre chaîne est un bon départ pour trois hommes ; pour une vraie troupe, la formation du moteur est
  la voie d'Alex et du jeu (ses batailles) : un pas à part (V73 f 1 bis).
- **Les pièges** (notes d'Alex) : un suiveur du jeu qui ne rend jamais la main seul (toujours une borne : chez nous, le
  pouls finit la branche au changement d'ordre) ; une branche sans mouvement où l'homme se gare et reste planté (le pouls
  la couvre) ; le retour : les règles de Scriptorium (`retour_de_la_troupe`, `troupe_chez_elle`) décideront à la
  bascule ; notre défaut (les 150 m qui reposent au camp, hors de vue) va pour l'instant.

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **Le rang de l'escorte** : (a) 2, avec le rassemblement : un ordre exprès d'Henry ; la bataille passe devant
   (Recommandé) ; (b) 3 ; (c) 4. **Prise : (a).**
2. **La voie** : (a) la fonction de suivi du jeu, (b) en réserve (Recommandé : réutiliser avant de créer) ; (b) notre
   réécriture d'emblée. **Prise : (a).**
3. **La colonne** : (a) le socle chaîne les hommes d'une même escorte, le premier suit le chef, chacun le précédent
   (Recommandé) ; (b) tous suivent le même chef ; (c) Scriptorium donne le chef de chacun. **Prise : (a).**
4. **Le rattrapage** : (a) au-delà de 60 m du chef, posé 4 m derrière Henry, hors de sa vue, sans limite de nombre (la
   règle de Scriptorium, `LOIN` 60, `ARRIERE` 4) (Recommandé) ; (b) jamais. **Prise : (a).**
5. **Le Directeur** : (a) dans ce pas, en tête (Recommandé : « c'est lui le premier qui me suit ») ; (b) plus tard.
   **Prise : (a).**
6. **À cheval** : (a) un pas à part, V73 f 2 (Recommandé) ; (b) dans ce pas. **Prise : (a).**

### V73 f 1, fait (17/10) : suivre Henry à pied
- **La règle « escorte »** (rang 2) et la tenue `activite = "suivre"`, `chef` (« henry », « directeur » ou un homme ;
  refus `escorte_invalide` pour un inconnu ou lui-même) ; `memes_tenues` compare le chef.
- **La colonne** (`activite_de`) : les hommes de la même escorte, dans l'ordre du camp ; le premier suit le chef de la
  tenue, chacun le précédent ; le rang dans la signature ; une escorte posée ou lâchée redonne leur ordre aux suiveurs
  dont le rang change.
- **La liaison** : l'ordre « suivre » écrit le WUID du chef (`GetMyWUID` d'Henry ou du personnage) dans `scriptorium_chef`,
  puis l'ordre 14 ; un chef introuvable : une marche simple ; `liaison.position_du_personnage` (un point) ; le poste
  d'essai dit l'écart de chacun à son chef.
- **La branche 14** : debout, puis `Function_followNpc` (le chef ``, nos huit distances lues du cerveau
  avec leur défaut, celles du jeu) ; le pouls à côté finit la branche au changement d'ordre (la borne que demandait le
  pair). 48 variables de cerveau (le chef et huit distances de plus).
- **Le rattrapage** (`hommes.rattraper`, partagé avec le Directeur) remplace le secours ordinaire pour un suiveur : à
  plus de `suivi_loin_m` (60) de son chef, posé `suivi_derriere_m` (4) derrière Henry, jamais sous ses yeux (une ligne
  une fois), jamais en combat, sans limite de nombre ; l'ordre redonné ensuite.
- **Le Directeur** : `directeur.suivre(oui)` au registre ; son activité « suivre », Henry pour chef ; le même rattrapage.
- **Poste d'essai** : `essai_escorte` (le Directeur suit Henry, les trois premiers hommes derrière lui) et
  `essai_fin_escorte` (145 commandes).
- **Banc** : 7 849 vérifications ; trois essais (la colonne et le lâcher ; aucun secours ordinaire à 3 m sur dix
  battements, le rattrapage à 70 m hors `secours_max`, deux fois, la vue d'Henry, le combat, `suivi_loin_m` à 0 ; le
  Directeur au registre, relancé, lâché) ; la liaison sur faux moteur (le WUID d'Henry ou d'un homme, un chef
  introuvable) ; le contrôle statique de l'appel et de la fonction `followNpc` du jeu (ses paramètres, relus dans
  `Scripts.pak`). Garde-fous éprouvés par quatre erreurs injectées, toutes attrapées : le secours ordinaire sur un
  suiveur, le chef pris ailleurs, tous derrière Henry, le Directeur qui oublie qu'il suit.

### Mesuré en V73 f 1 (17/10) : suivre Henry à pied, acquis
- **Issue 1, la fonction du jeu** : `Function_followNpc` est joué dans notre interruption, le chef en WUID et nos distances
  en variables : Henry marche (15 s) puis court (10 s) ; le Directeur se tient à 2,3–4,1 m d'Henry, chaque homme à 1,2–8,4 m
  de son chef. La voie (b) n'est pas nécessaire.
- **Issue 2, la colonne** : Jan derrière le Directeur, Mikuláš derrière Jan, Ondřej derrière Mikuláš (les lignes des
  ordres) ; à l'image, le Directeur juste derrière Henry, la colonne sur le chemin, le camp au fond.
- **Issue 3, la course** : l'écart au chef se maintient quand Henry court.
- **Issue 4, le rattrapage** : deux sauts de 40 m : ils rattrapent seuls, en courant (le Directeur de 33 à 2,5 m en 13 s),
  aucun rattrapage ; quatre sauts de plus (160 m) : la course du Directeur se bloque vers 95 m dix secondes ; au
  battement, « à 97 m de son chef, rattrapé 4 m derrière Henry » ; au battement suivant, en chaîne, Jan (66 m), Mikuláš
  (109 m), Ondřej (97 m), posés à plus de 1 m l'un de l'autre ; ensuite, 2,2–3,4 m de leur chef. Aucun n'a été posé sous
  les yeux d'Henry (posés derrière lui).
- **Issue 5, la fin** : le secours remis, `essai_fin_escorte` : un ordre d'exercice chacun ; à 188 m de leur point au camp,
  **reposés au camp par les 150 m** au premier battement (Henry regardait ailleurs) ; le Directeur, sans secours, rentre à
  pied (190 m).
- Une erreur de pilotage, sans rapport avec le socle : l'ordre de fin écrasé par la lecture suivante avant d'être lu
  (cinq secondes entre deux ordres, rappel) ; redonné.
- **Pas vu en jeu** : un homme en combat pendant la suite, la reprise au rechargement en route, Henry dans une maison, la
  vue d'Henry qui retient un rattrapage (banc seulement).
- **Suite** : V73 f 1 bis, la formation du moteur (la voie d'Alex et de la colonne de Scriptorium, relecture du pair),
  à lire avant V73 f 2, à cheval.

## V73 f 1 bis — l'escorte en formation du moteur (17/10, relu par le pair ; réponses recommandées prises d'office)

### Le périmètre
- La relecture du pair (V73 f 1) : Alex fait suivre sa troupe par les **formations du moteur**, et la colonne de
  Scriptorium (`directeur_en_route`) est un modèle de formation, le Directeur en chef. Notre chaîne (chacun suit le
  précédent) marche pour trois hommes, mais s'étire avec une vraie troupe. Ce pas ajoute la formation, au choix de la
  tenue ; la chaîne reste le défaut. À lire aussi avant V73 f 2 (à cheval, par la formation chez Alex).

### Ce que le jeu fait (lu dans `Scripts.pak`, lecture seule)
- **Le chef** ouvre une formation par son nom et la tient : `<MakeFormation FormationName=… HandleVariable=…/>` puis une
  attente sans fin (`formation_lead`, `AI/move/moveUtils.xml`) ; `moveInFormation_leader` l'entoure d'un `FuseBox` qui la
  ferme (`EndFormation`) en sortant (« OnSuccess » 774 emplois, « OnFail » 514 dans le jeu).
- **Les suiveurs** la retrouvent par le WUID du chef et s'y rangent : `<GetMemberFormation MemberWUID=… FormationHandleOut=…/>`
  puis `<FormationFollower FormationHandle=… PreferredPositions="" FormationMode=… AllowRelocation="false"/>`
  (`formation_follow`, `moveInFormation_slave`). Modes : `MoveHistory` (13 emplois : ils marchent où le chef a marché),
  `KeepShape` (6), `KeepDistance` (2), `Relaxed` (2).
- **Les modèles** (`AI/FormationDefinitions.xml`, 63) : `followNPC` (8 places, deux colonnes, de 1,7 à 6,9 m derrière le
  chef), `infantryMen20` (19), `battleFormation_basic25` (24), `cavalryRiders6` (5, à cheval), `mucirna_vypaleniSemina_rideToSemin`
  (14, à cheval). Un mod ne peut pas ajouter de modèle sans remplacer tout ce fichier du jeu : on prend ceux du jeu.

### Comment ce serait fait
1. **La tenue « escorte » accepte `formation`** (le nom d'un modèle du jeu, connu du catalogue `hommes.formations` avec
   son nombre de places) ; sans formation, la chaîne de V73 f 1.
2. **Le chef de formation** : le Directeur s'il mène (`directeur.suivre(oui, formation)`, chef « directeur »), sinon le
   premier homme de l'escorte. Son ordre devient « mener » (ordre 15) : debout ; un appel au Lua (comme la ronde,
   `ExecuteLua` sous `pcall`) écrit le nom du modèle dans une variable de l'arbre ; puis, en parallèle, **une branche sans
   marche** qui ouvre la formation (`MakeFormation`) et attend, et **une branche sœur** qui suit son propre chef (Henry)
   par `Function_followNpc` ; le pouls. **La formation n'est fermée** (`EndFormation`) qu'au début de l'ordre suivant,
   s'il n'est plus « mener » (revu après la relecture du pair : aucun `FuseBox`).
3. **Les suiveurs** (rang 2 et plus, dans la limite des places du modèle) : ordre « en formation » (ordre 16) : debout ;
   tant que l'ordre tient, retrouver la formation du chef (`GetMemberFormation`, le chef en WUID dans
   `scriptorium_chef`) et s'y ranger (`FormationFollower`, **un nœud par mode**, `MoveHistory` par défaut) ; si la
   formation n'est pas ouverte, **suivre normalement son chef** (`Function_followNpc`) pendant `formation_reessai_ms`
   (4 s), puis réessayer ; le pouls. **Au-delà des places**, les surnuméraires suivent en chaîne (V73 f 1) le dernier
   rangé.
4. **Le rattrapage** (V73 f 1) vaut pour tous, par rapport à leur chef (le chef de formation pour les suiveurs).
- **Valeurs en données** : `hommes.formations` (le nom de chaque modèle permis et ses places : `followNPC` 8,
  `infantryMen20` 19, `battleFormation_basic25` 24) au catalogue ; `hommes.cerveau.formation_mode` (1 `MoveHistory`,
  2 `KeepShape`, 3 `KeepDistance`, 4 `Relaxed`). Le nom passe par le Lua, pas par le cerveau (une chaîne).
- Le contrôle statique relit dans `Scripts.pak` que chaque modèle du catalogue existe encore.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé ; trois hommes et le Directeur ; `essai_escorte_formation` : le Directeur mène, en
`followNPC`, les trois en formation derrière lui.
1. Le Directeur suit Henry ; les trois prennent des places de la formation (deux colonnes derrière lui), à l'image.
2. Henry marche puis court : la formation suit (écarts au chef entre 1,7 et 7 m).
3. Un saut de 160 m : le rattrapage du Directeur, puis des suiveurs ; la formation se reforme.
4. `essai_fin_escorte` : chacun reprend sa tranche ; le Directeur rejoint sa journée.
- Aucune ligne au journal ne dit « la formation est ouverte » : l'image et les écarts le disent.

### Relecture du pair (17/10), qui change le montage
- **La fermeture** (mécanisme d'Alex) : la formation se tient dans une branche **à part, sans marche** (ouvrir, puis
  attendre), la marche du chef dans une branche sœur : c'est la forme du jeu (`formation_lead`, la tournée du bailli).
  Quand la formation vivait dans la branche de marche, monter à cheval ou un combat interrompait cette branche, son
  nettoyage **détruisait la formation**, et toute la troupe se défaisait. Un `FuseBox` qui ferme la formation à chaque
  échec du chef reproduirait ce piège ; et un nettoyage qui relance fait boucle (l'arbre est terminé chaque fois qu'on le
  remplace exprès). **La formation ne se ferme que quand le chef cesse de mener** (son ordre change).
- **Les suiveurs** : `FormationFollower` est la marche ; tant que la formation n'est pas ouverte (départ, chef en combat,
  relais), le suiveur doit **suivre normalement** son chef, pas attendre sur place (il se garerait) ; le suiveur de repli
  du jeu ne rend jamais la main seul : une borne, **4 s** (pas 1,5 : chaque fin de borne refait le suiveur du moteur ; à
  1,5 s, une escouade de cinq coûtait jusqu'à 40 images par seconde en ville).
- **Le mode et `AllowRelocation` sont des attributs écrits en clair** : un nœud par mode, derrière un aiguillage.
- `MoveHistory`, le bon défaut pour une colonne sur les chemins ; pour les cavaliers (V73 f 2), la seule forme du jeu
  avec `Relaxed` (aucun suiveur monté en `KeepShape`), et un `WaitAction` avant le suiveur monté laisse la monture se
  stabiliser.

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **Quand la formation** : (a) quand la tenue nomme un modèle, la chaîne sinon (Recommandé : la chaîne est prouvée,
   la forme de la troupe est à Scriptorium) ; (b) toujours la formation. **Prise : (a).**
2. **Le mode des suiveurs** : (a) `MoveHistory` par défaut, réglable (Recommandé : le plus employé par le jeu ; la
   colonne passe où le chef est passé) ; (b) `KeepShape`. **Prise : (a).**
3. **Plus d'hommes que de places** : (a) les surnuméraires suivent en chaîne le dernier rangé (Recommandé) ; (b) refusés.
   **Prise : (a).**

### V73 f 1 bis, fait (17/10)
- **Données** : `hommes.formations` (followNPC 8, infantryMen20 19, battleFormation_basic25 24 ; section « formations » du
  catalogue, vingt-huit sections) ; `hommes.cerveau.formation_mode` (1) et `formation_reessai_ms` (4 000) ; 50 variables
  de cerveau.
- **`hommes`** : la tenue « escorte » accepte `formation` (refus `escorte_invalide` pour un modèle inconnu) ; la colonne
  donne à chacun son rôle : derrière le Directeur, les hommes se rangent dans sa formation ; derrière Henry, le premier
  mène, les suivants se rangent dans sa formation ; au-delà des places, la chaîne ; le rôle entre dans la signature.
- **`directeur.suivre(oui, formation)`** : il mène le modèle (refus `formation_inconnue`), gardé au registre.
- **La liaison** : avec `suivi`, l'ordre 15 (mener ; le modèle retenu pour l'arbre) ou 16 (se ranger) ;
  `liaison.nom_de_la_formation`, appelée par l'arbre sous `pcall`, écrit le modèle dans `formation_nom`.
- **L'arbre** : la fermeture (`EndFormation`) au début d'un ordre qui n'est plus « mener » ; la branche 15 (debout, le
  modèle par le Lua, la branche sans marche qui ouvre la formation, la branche sœur qui suit Henry, le pouls) ; la
  branche 16 (debout ; tant que l'ordre tient : retrouver la formation et s'y ranger par l'un des quatre nœuds, sinon
  suivre son chef 4 s ; le pouls).
- `essai_escorte_formation` (146 commandes).
- **Banc** : 7 876 vérifications ; un essai de plus (le modèle inconnu, la formation derrière le Directeur, une seule
  place et la chaîne, derrière Henry le premier qui mène, le rattrapage d'un suiveur en formation, le Directeur lâché) ;
  la liaison sur faux moteur (mener, se ranger, le modèle écrit pour l'arbre, une entité absente) ; les contrôles
  statiques (les branches 15 et 16, une seule `EndFormation` et aucun `FuseBox`, chaque modèle du catalogue relu dans
  `AI/FormationDefinitions.xml`). Contrôle d'absence inchangé (32). Garde-fous éprouvés par trois erreurs injectées,
  toutes attrapées : la formation fermée à chaque ordre, les places ignorées, le suiveur jamais rangé.

### Mesuré en V73 f 1 bis (17/10) : l'escorte en formation, acquise
- **Issues 1 et 2** : le Directeur mène (ordre 15) ; « Formation de Scriptorium_Directeur : « followNPC » » au journal
  (l'appel au Lua de la branche 15) ; les trois s'y rangent (ordre 16) ; **à l'image, la forme `followNPC`** : deux côte
  à côte derrière le Directeur, le troisième au rang suivant ; écarts au chef de 1,7 à 4,3 m, Henry marchant puis
  courant.
- **Issue 3, le saut de 160 m** : pendant que le Directeur court après Henry, ses suiveurs restent à 2–6 m de lui (la
  formation suit son chef) ; au battement, « Directeur à 86 m de son chef, rattrapé 4 m derrière Henry » ; sa formation
  rouverte (l'ordre redonné) ; les hommes, alors à 60 m de lui, courent et se rangent de nouveau (2–3,7 m) ; à l'image,
  la formation reformée dans un champ de blé.
- **Issue 4, la fin** : le Directeur reprend sa journée (« comptes », au coffre) et rentre à pied ; les hommes, à plus de
  170 m, sont reposés au camp par les 150 m.
- **À surveiller** : après un rattrapage, le chef reçoit de nouveau l'ordre 15 et ouvre une nouvelle formation sans
  fermer l'ancienne (la fermeture ne vient qu'à un ordre qui n'est plus « mener ») ; les suiveurs retrouvent la nouvelle.
  Une formation orpheline par rattrapage reste possible : aucune trace n'en est lisible au journal.
  **Corrigé le 17/10 (remède du pair, « fermer avant d'ouvrir »)** : la branche 15 ferme l'ancienne formation du même chef
  (`EndFormation`, sans effet s'il n'y en a pas) juste avant d'en ouvrir une ; contrôle statique au banc (deux
  `EndFormation`, aucun `FuseBox`). Non revu en jeu : à regarder à la prochaine séance d'escorte (le cheval). Si cela ne
  suffit pas, le second remède du pair : ne redonner l'ordre 15 au chef rattrapé que si son pouls est figé.
- **Pas vu en jeu** : un homme en combat pendant l'escorte, la formation menée par le premier homme (derrière Henry), les
  surnuméraires en chaîne, un autre mode que `MoveHistory`.
- **Suite** : V73 f 2, à cheval.

## V73 f 2 a — à cheval : la sonde d'un homme (17/10, relu par le pair, fait et vu en jeu ; réponses recommandées prises d'office)

### Le périmètre
- Règle de JoVenGer du 16/10 : « tous ceux qui sortent du camp partent à cheval et en reviennent à cheval » ; chez
  Scriptorium, la monte a figé un homme (24/09) et le coursier « restait figé dès qu'on essayait de le faire monter » ;
  aucune fonction Lua ne fait monter un personnage. Le plan (règle du 16/10) : **d'abord lire comment les arbres du jeu
  font monter, chevaucher et descendre, puis un seul homme, prouvé à l'image**.
- **Ce pas, une sonde** : un cheval né par script près d'un homme ; l'homme monte, suit Henry à cheval, puis descend.
  La troupe montée, la formation montée, le cheval gardé au registre, les montures du camp (l'écurie), Henry à cheval :
  à leurs pas, après la sonde.

### Ce que le jeu fait (lu dans `Scripts.pak`, lecture seule)
- **Monter, c'est une posture** : la fonction du jeu `moveOnHorse` (`AI/move/moveOnHorse.xml`, paramètres `horse` en WUID,
  `moveData`, `speed`) entoure sa marche d'un `StanceElement smartObject="$horse" stance="horse"` ; dedans, un
  `WaitAction` puis le `Move` ; à la fin de la posture, le jeu joue la descente (comme pour s'asseoir : V73 c). La
  posture « horse » a 57 emplois dans le jeu.
- `HorseUsageElement horse=…` (56 emplois ; `AI/autotest/horse/test_so_horseAction.xml`) : l'usage du cheval comme objet ;
  `GetPlayerHorse` (66) : le cheval d'Henry.
- **La classe `Horse`** (`Scripts/Entities/AI/Horse.lua`) : modèle `Objects/Characters/animals/horse/horse.cdf`,
  `defaultSoulArchetype = "Horse"`, `defaultSoulClass = "horse"` (une âme par défaut), `bWH_RequiresHome = true`,
  `bNotPlayerMountable = false`, `bMountIsLegal = false`. Aucun script Lua du jeu ne fait naître de cheval (ils sont posés
  dans le niveau ou par les quêtes).
- Relecture du pair (V73 f 1 bis) : chez Alex, le suiveur monté passe par la formation (`MoveHistory`, un `WaitAction`
  avant, pour que la monture se stabilise) ; tous les suiveurs montés du jeu sont en `MoveHistory` ou `Relaxed`.

### Comment ce serait fait (la sonde)
1. **Le cheval** : `liaison.faire_venir_cheval(nom, position)` : `System.SpawnEntity` de la classe `Horse`, propriétés
   copiées de la classe (comme pour nos hommes), **sur une âme de cheval du jeu** (`liaison.ame_de_cheval`, Horse2,
   `1b356948-3d22-427c-86f9-f33ab2b441c6`, `Libs/Tables/rpg/soul.xml`, archétype 3, classe 7 : relecture du pair),
   `bSaved_by_game = false` (un cheval de passage, hors de la sauvegarde), `bWH_RequiresHome = false`, au sol, à
   l'écart (place libre, jamais à moins de 1 m d'un personnage), éveillé comme nos hommes ; rend son identifiant.
2. **Monter et suivre** : l'activité « suivre » à cheval : une tenue « escorte » avec `cheval` (l'identifiant du cheval) ;
   la liaison écrit son WUID dans `scriptorium_cheval`, puis l'ordre 17 : debout ; la posture
   `StanceElement smartObject="$scriptorium_cheval" stance="horse"` ; dedans, un `WaitAction` (la monture se stabilise),
   « en selle » compté, puis `Function_followNpc` vers son chef (Henry) ; le pouls à côté. **La monte est bornée**
   (relecture du pair) : la posture est en `Parallel` (le premier qui finit) avec une attente de `monte_delai_ms`
   (10 000 ms, `hommes.cerveau`, au catalogue) ; l'attente ne finit pas si « en selle » a bougé ; pas en selle au bout
   du délai, la posture est quittée et l'homme suit à pied (jamais figé à côté de son cheval). Au changement d'ordre,
   la posture finit : le jeu joue la descente.
3. **Les commandes d'essai** : `essai_cheval` (un cheval né à 5 m du premier homme, sous un angle tiré au hasard ; né
   derrière une barrière : `essai_retirer_cheval`, puis la commande redonnée tire un autre angle) ; `essai_escorte_a_cheval` (le premier
   homme suit Henry sur ce cheval) ; `essai_fin_escorte` (il descend, il reprend sa tranche) ; `essai_retirer_cheval`.
- Rien au registre pour la sonde (le cheval d'essai n'est pas gardé : retiré en fin de séance).
- La forme du jeu (une posture « horse » autour d'une marche) est celle de `moveOnHorse` ; aucune ligne de forme nouvelle
  attendue (nos noms de variables).

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé, trois hommes ; `essai_cheval` puis `essai_escorte_a_cheval`.
1. **Le cheval naît** : visible à l'image, debout, près de Jan ; il ne s'enfuit pas (`bWH_RequiresHome`) ; sinon lire
   le journal, un seul changement.
2. **Jan monte** (à l'image : en selle) → bon ; s'il reste figé à côté (le piège de Scriptorium) : lire le pouls et les
   contextes, un seul changement (par exemple `HorseUsageElement` à la place de la posture seule).
3. **Il suit Henry à cheval** quand Henry marche et court ; l'écart à son chef se tient.
4. `essai_fin_escorte` : **il descend**, reprend sa tranche ; le cheval reste là, puis `essai_retirer_cheval`.
- Décompte de l'écran noir (fiche 14).

### Relecture du pair (17/10)
- **Le principe chez Alex** (principe seulement, sans son code) : ses chevaux naissent par script, classe `Horse`, avec
  deux propriétés seulement, une **âme de cheval** et `bSaved_by_game = false`. Notre sonde naissait sans âme : son
  premier soupçon si la monte échoue. → Âme Horse2 du jeu (relevée dans `Tables.pak`, lecture seule : Horse2,
  kkut_horse_5 et animal_horse ont le même archétype 3, la même classe 7 et le même cerveau ; Horse2 gardée).
- **La monte bornée** : `Parallel(Any)` entre la posture (avec le suiveur dedans) et une attente de 10 s qui ne finit pas
  une fois « en selle » compté ; repli à pied sinon. Le `WaitAction` reste avant le suiveur monté. → Fait.
- **Le cheval à 5 m sous un angle au hasard**, redonné s'il tombe derrière une barrière. → Fait (`essai_cheval`).
- Un `StanceCheck` horse après la monte : non retenu pour la sonde (le compte « en selle » et l'image disent la même
  chose) ; à reprendre avec la troupe montée si la monte se défait en route.

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **La sonde** : (a) un cheval né par script et un seul homme, avant toute troupe montée (Recommandé : la règle du
   16/10, « un seul homme, prouvé à l'image ») ; (b) la troupe d'emblée. **Prise : (a).**
2. **Le cheval** : (a) de la classe `Horse` avec l'âme par défaut, le temps de la sonde (Recommandé : rien à écrire dans
   les tables) ; (b) des âmes de chevaux à nous (une table, comme nos hommes). **Prise : (a)**, puis revue par la
   relecture du pair : une âme de cheval **du jeu** (Horse2), sans table à nous ; une table de chevaux viendra avec la
   troupe montée.
3. **Monter** : (a) la posture « horse » du jeu autour de la suite, comme `moveOnHorse` (Recommandé) ; (b)
   `HorseUsageElement`. **Prise : (a).**

### Mesuré en V73 f 2 a (17/10) : la sonde à cheval, acquise
- ad37d81, `playline3` (473), sans `-devmode`, secours coupé puis remis ; trois hommes et le Directeur.
- **Le cheval naît** (âme Horse2) : sellé, debout, à 5 m de Jan ; il ne s'enfuit pas.
- **Jan monte** au premier essai : « en selle 1 » ; à l'image, en selle à 6 s, jamais figé à côté du cheval (le piège
  connu chez Scriptorium n'est pas reproduit : la posture « horse » du jeu, une âme de cheval).
- **Il suit Henry à cheval** : 12,45 m pendant qu'Henry marche 10 s, puis à côté de lui ; 10,76 m juste après une
  course de 5 s, 3,64 m 8 s plus tard.
- **Il descend** à la fin de l'escorte (la posture finie, le jeu joue la descente) et repart à pied à sa tranche ; le
  cheval reste ; `essai_retirer_cheval` le retire.
- Pas vu : le repli à pied au bout de `monte_delai_ms` (la monte a réussi aussitôt) ; contrôlé au banc seulement.
- **Le piège des doublures** (transmis par le pair après la séance) : pendant un dialogue, le jeu crée des doublures
  des personnages et des chevaux proches, dont le nom contient celui de l'original (« DialogTwin_… ») ; chez Scriptorium,
  un ménage par nom « qui contient » en a retiré une, et le jeu a planté. Relu : le socle trouve et retire par le nom
  exact (`System.GetEntityByName`) et ne trie que par le début du nom (`scriptorium_`). Au banc : une doublure n'est
  jamais retirée avec le cheval, même l'original parti ; un retrait « qui contient » injecté est attrapé.
- Suite : V73 f 2 b, la troupe à cheval.

## V73 f 2 b — la troupe à cheval (17/10, relu par le pair, fait et vu en jeu ; réponses recommandées prises d'office)

### Le périmètre
- Après la sonde (V73 f 2 a, vue en jeu) : **les hommes d'une escorte partent à cheval**, chacun sur un cheval né pour la
  sortie, en formation derrière Henry (le premier mène, les autres s'y rangent), et descendent à la fin de la sortie.
- **Ce pas** : les hommes seuls derrière Henry. Le Directeur monté (il mène la troupe), l'allure du chef réglée sur
  Henry, la descente au combat, Henry à cheval, les chevaux gardés au camp : à leurs pas, plus tard.

### Ce que le pair a transmis (principes seulement, sans le code d'Alex ni celui de Scriptorium)
1. **La formation montée** : le suiveur monté en `MoveHistory` (tous les suiveurs montés du jeu sont en `MoveHistory` ou
   `Relaxed`, aucun en `KeepShape`) ; un `WaitAction` avant le suiveur monté, pour que la monture se pose ; la formation
   tenue par la branche à part sans marche (notre montage de V73 f 1 bis), qui survit à la monte du chef.
2. **L'allure du chef réglée sur Henry** (toutes les 300 ms environ, la vitesse d'Henry mesurée, l'allure du chef
   choisie). Pas dans ce pas : `followNpc` en selle a déjà tenu 3,64 m après une course (V73 f 2 a) ; la grille regarde
   si le chef monté distance ou traîne la colonne. S'il le faut, au pas suivant (un appel au Lua toutes les 300 ms par
   chef : latence ajoutée, à signaler).
3. **Qui monte** : seuls les hommes en sortie ; ceux du camp restent à pied ; l'homme descend quand un combat est assez
   proche (à son pas, plus tard ; l'interruption de combat du jeu finit sans doute la posture d'elle-même).
4. **La vie du cheval** : un cheval par homme, né à 5 m ; **une monte qui n'aboutit pas dans le délai** (10 s) : le
   cheval est retiré et un autre naît sous un autre angle tiré au hasard (réessayer le même cheval échoue pareil) ; les
   essais comptés, un plafond (2 ou 3, réglable), puis l'homme suit à pied le reste de la sortie ; une ligne au journal
   par essai. Le cheval n'est retiré qu'une fois l'homme sûrement descendu (chez Alex : plusieurs lectures de suite
   « plus en selle » ; une seule lecture manquée tuait un cheval vers lequel l'homme marchait encore).
5. **Le piège des doublures** (« DialogTwin_… ») : retrait par le nom exact seulement (fait et contrôlé au banc).

### Comment ce serait fait
1. **La tenue** : `hommes.tenir(id, "escorte", { activite = "suivre", lieu, formation, a_cheval = true, fin })` ;
   `a_cheval` doit être un booléen (sinon `escorte_invalide`). La sonde (`cheval = <identifiant>`) reste.
2. **Le cheval de chacun** (passager, en mémoire seulement, jamais au registre ; un rechargement le perd et il en
   renaît un) : à l'ordre de l'homme (`ordonner_un_homme`), si sa tenue la plus forte est une sortie à cheval et qu'il
   n'a pas de cheval vivant (`objet_existe`), un cheval naît à `cheval_distance_m` (5 m) de lui, sous un angle tiré au
   hasard du socle (`faire_venir_cheval`, sa recherche de place libre) ; journal à chaque naissance et à chaque refus.
3. **Monter et mener, monter et se ranger** : deux branches neuves de l'arbre, sur la coque de la branche 17 (debout,
   la posture « horse » du jeu, le `WaitAction`, « en selle » compté, la monte bornée par `monte_delai_ms`) :
   - **18, mener à cheval** : le montage de la branche 15 (le modèle lu par le Lua ; la formation fermée puis rouverte
     dans une branche à part, sans marche) ; dans la branche sœur, la marche : monter, puis `followNpc` vers Henry en
     selle ; la monte manquée : `followNpc` à pied, la formation toujours ouverte (il mène toujours). La formation est
     **hors de la posture** : changer de posture ne la touche pas (notre lecture du point 1 du pair, à confirmer).
   - **19, se ranger à cheval** : monter, puis dans la posture la boucle de la branche 16 (`GetMemberFormation`, le
     suiveur du moteur, repli `followNpc` pendant `$reessai`), mode lu dans `formation_mode_monte` (1 `MoveHistory`,
     par défaut ; 4 `Relaxed`), un nœud par mode ; la monte manquée : `followNpc` à pied.
   - **La fermeture** de la formation menée (le bloc avant l'aiguillage) épargne les ordres 15 **et 18** ; sinon un chef
     monté verrait sa formation fermée à chaque tour.
4. **La monte manquée** : quand le délai finit sans « en selle », l'arbre compte `scriptorium_monte_manquee` (+ 1) ; au
   battement, le Lua lit ce compte (`liaison.montes_manquees`) : s'il a bougé, l'essai est compté et écrit au journal,
   le cheval retiré, et, sous le plafond `monte_essais_max` (3), un autre naît sous un autre angle, l'ordre redonné
   (le nom du cheval entre dans la signature) ; au plafond, l'homme suit à pied jusqu'à la fin de sa sortie (l'abandon
   est oublié quand la sortie finit). Latence : jusqu'à un battement (30 s) à pied entre deux essais ; acceptée pour ce
   pas (pas d'appel au Lua en plus).
5. **Le retrait du cheval après la sortie** : au battement, un cheval dont l'homme n'est plus en sortie à cheval **et**
   dont l'homme est à plus de `cheval_retrait_m` (6 m) est retiré (la descente est finie : il s'en est éloigné) ;
   jamais pendant la sortie, jamais pendant la descente ; aussi quand l'homme n'est plus au camp (renvoyé, mort).
6. **Le rattrapage** (V73 f 1 : au-delà de 60 m, le suiveur posé 4 m derrière Henry) : **jamais pour un homme à cheval**
   (posé seul, il serait séparé de son cheval) ; son cheval le ramène au galop. Le rattrapage d'un cavalier (le cheval
   avec lui) viendra avec le changement de carte. Réponse recommandée prise d'office (consigne du 17/10).
7. **Les commandes d'essai** : `essai_troupe_a_cheval` (les trois premiers hommes suivent Henry à cheval, en formation
   followNPC ; le premier mène) ; `essai_fin_escorte` (déjà là : la sortie finie). La monte manquée s'éprouve par le
   fichier de réglages (`hommes.cerveau.monte_delai_ms` très court), sans commande de plus.

### Règles en données (catalogue)
- `hommes.reglages` : `cheval_distance_m` 5, `cheval_retrait_m` 6, `monte_essais_max` 3.
- `hommes.cerveau` : `formation_mode_monte` 1.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé, trois hommes ; `essai_troupe_a_cheval`.
1. **Trois chevaux naissent** près des hommes, à au moins 1 m de tout personnage ; journal : trois naissances.
2. **Les trois montent** (« en selle » à 1 chacun) ; le premier ouvre la formation (« Formation de … : « followNPC » »).
3. **La troupe suit Henry** à pied puis à la course, en forme followNPC à l'image (chef devant, deux derrière) ; le chef
   monté distance-t-il ou traîne-t-il la colonne ? (l'allure du point 2, à décider sur l'image).
4. **Henry s'éloigne par deux sauts de 40 m** : aucun cavalier n'est posé ; la troupe le rejoint d'elle-même au galop,
   et la formation tient (« fermer avant d'ouvrir » reste à revoir en jeu, avec un chef à pied).
5. `essai_fin_escorte` : **ils descendent**, reprennent leur tranche ; **les chevaux retirés** au battement où chaque
   homme est à plus de 6 m du sien (journal).
6. **La monte manquée** : `monte_delai_ms` à 300 par le fichier de réglages, `essai_troupe_a_cheval` : trois essais par
   homme au journal (retrait, renaissance sous un autre angle), puis à pied ; réglage retiré.
- Décompte de l'écran noir (fiche 14).

### Relecture du pair (17/10)
- **Fiche bonne ; la lecture du point 1 est juste** : la formation tenue par la branche à part, sans marche, hors de la
  posture ; c'est pourquoi, chez Alex, elle survit quand le chef monte.
- **La barrière** : aucune mesure chez Alex ; c'est la monte qui n'aboutit pas dans le délai (10 s) qui fait retirer le
  cheval et en faire naître un autre sous un autre angle (réessayer le même échoue pareil) ; plafond de 2 ou 3 essais,
  réglable, puis à pied ; une ligne au journal par essai. Chez Alex, l'abandon n'est oublié que quand Henry descend de
  cheval ; ici, à la fin de la sortie (Henry à cheval viendra à son pas).
- **Pour les pas suivants** (pas pour celui-ci) :
  - **Quand monter** : ici la tenue le dit (`a_cheval`), bon pour la sonde. Mais l'escorte d'Henry monte **quand Henry
    monte** et descend quand il descend (chez Scriptorium, le Directeur suit Henry « à cheval quand Henry l'est ») : à
    lire par un `StanceCheck` « horse » sur Henry, avec un **anti-rebond** (monter tout de suite, descendre seulement
    après plusieurs lectures de suite). La règle de JoVenGer, « tous ceux qui sortent du camp partent à cheval », vaut
    pour les sorties **sans** Henry (missions, métiers, coursier). Deux déclencheurs, chacun à son pas.
  - **Le Directeur monté** : chez Scriptorium, c'est lui le chef de la colonne ; quand il viendra, il reprend la tête,
    et « le premier homme mène » ne sert qu'en son absence.
  - **La fluidité** (idée n° 6, 80 hommes) : un cheval par homme, jusqu'à 80 chevaux ; à mesurer à l'essai du camp plein.
- Fait en plus au code : une naissance refusée ne compte qu'une fois à la même heure du jeu (la pose d'une tenue ordonne
  l'homme deux fois : la tenue, puis l'escorte redonnée).

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **Les chevaux de la Compagnie** (question du pair pour JoVenGer) : (a) **passagers**, nés à la monte et retirés après
   la descente, rien au registre (Recommandé : comme chez Alex ; aucun soin, aucun fourrage à tenir) ; (b) **gardés**,
   des chevaux de la Compagnie, au piquet du camp, nourris au fourrage (idée n° 13 de la liste pour plus tard ;
   Scriptorium a déjà un cheval de coursier qui mange et s'entretient). **Prise : (a)**, à redire en tête du bilan :
   c'est la réponse qui engage la suite.
2. **Qui mène** : (a) les hommes seuls derrière Henry, le premier mène (Recommandé : la sonde la plus légère) ; (b) le
   Directeur monté d'emblée. **Prise : (a)**.
3. **L'allure du chef réglée sur Henry** : (a) pas dans ce pas, à décider sur l'image (Recommandé) ; (b) tout de suite.
   **Prise : (a)**.

### Mesuré en V73 f 2 b (17/10) : la troupe à cheval, acquise
- 64ed7f8, `playline3` (473), sans `-devmode`, secours coupé puis remis ; trois hommes.
- **Trois chevaux nés, trois montes** (« en selle 1 » chacun) ; Jan mène (ordre 18), les deux autres se rangent (ordre 19) ;
  à l'image, Jan devant, les deux autres en flanc derrière lui.
- **La troupe suit Henry** au pas (Jan à 17,98 m juste après 10 s de marche, puis contre Henry ; suiveurs à 3,1–3,5 m de
  lui) et à la course (Jan à 10,53 m, puis 2,38 m 8 s plus tard ; suiveurs à 2,1–2,5 m). **L'allure du chef réglée sur
  Henry n'est pas nécessaire** à ce stade (question 3 : rien à faire).
- **Deux sauts de 40 m** : la troupe rejoint d'elle-même au galop (Jan à 31,78 m 11 s après le saut, 2,44 m 26 s plus
  tard) ; la formation tient : la formation hors de la posture se vérifie. Aucune pose ni rattrapage au journal.
- **Descentes** à la fin de la sortie, **chevaux retirés** au battement suivant (une ligne chacun).
- **Monte manquée** (`cerveau.monte_delai_ms` à 300 par le fichier de réglages) : pour chacun, trois essais (chevaux `_1`,
  `_2`, `_3` retirés tour à tour), puis à pied jusqu'à la fin de la sortie (ordres 15 et 16, en formation autour d'Henry).
- Vu aussi : à la pose de la troupe et à sa fin, l'ordre du premier est redonné à chaque homme ajouté ou lâché (le nombre
  est dans la signature) ; sans effet visible (tout se passe au même instant).
- **Ouvert** : la naissance du cheval n'évite que les personnages (à 1 m), pas les meubles du camp ; la règle « jamais
  reposé seul » n'a pas été éprouvée en jeu (aucun battement n'a vu un cavalier à plus de 60 m) ; « fermer avant d'ouvrir »
  toujours pas revu en jeu.
- Suite (relecture du pair) : monter **quand Henry monte** (un `StanceCheck` « horse » sur Henry, anti-rebond), le
  Directeur monté chef de colonne ; puis le changement de carte et les intérieurs.

## V73 f 2 c — le cheval né hors des meubles (17/10, relu par le pair, fait et vu en jeu ; réponses recommandées prises d'office)

### Le périmètre
- Premier point ouvert de V73 f 2 b : la naissance du cheval n'évite que les personnages (à 1 m), pas les meubles. Un
  cheval né dans une tente, sur un banc ou contre la palissade : c'est l'hypothèse même de l'écran noir (un corps posé
  dans un objet). Le pair conseille de ne pas l'attendre.

### Ce que le pair a transmis
- Réemployer le garde-fou des postes (fiche 15, V73 d 1 : à plus de 2 m de tout meuble du plan, en dedans ou en dehors
  de la palissade selon le cas), et sinon un autre angle.
- Pour un homme au camp, le plus sûr : faire naître le cheval **hors du camp, sur le chemin de sortie**, et l'homme
  marche jusqu'à lui (on va chercher sa monture) ; au banc, un camp plein de meubles.

### Comment ce serait fait
1. **La base** : sans camp, l'homme ; camp fondé et homme **dans le cercle de l'enceinte** (le cercle du plan, rayon
   `enceinte.reglages.rayon`, bâtie ou non) : **le point de sortie**, du côté de la porte (le plan la met au nord de
   l'ancre), à `cheval_hors_camp_m` (6) au-delà du cercle ; homme hors du cercle : l'homme.
2. **La place** : jusqu'à `cheval_places_essayees` (8) angles tirés au hasard, à `cheval_distance_m` (5) de la base ;
   une place est bonne si elle est à au moins `cheval_ecart_meuble_m` (3 ; un cheval est plus long qu'un homme) de tout
   objet du plan du camp et de l'enceinte (tous niveaux, bâtis ou non : par prudence), **hors du cercle** de l'enceinte d'au moins le même
   écart quand un camp est fondé, à au moins `cheval_ecart_cheval_m` (3) des chevaux des autres hommes, **sur un sol
   praticable** (relecture du pair) : une pente au plus `cheval_pente_max` (0,5 m par m ; hauteurs du terrain à
   `cheval_sol_pas_m`, 1,5 m, de part et d'autre, `System.GetTerrainElevation`) et rien qui encombre (un rayon descendu
   de 3 m au-dessus, `Physics.RayWorldIntersection`, la forme de `Scripts/Entities/Physics/PressurizedObject.lua`, qui
   touche quelque chose à plus de 0,3 m au-dessus du terrain : objet, personnage, et l'eau si le jeu donne `ent_water`).
   **La vue d'Henry** (relecture du pair) : d'abord une place qu'Henry ne voit pas (`henry_voit`, `secours_vue_cos`) ;
   sinon une place qu'il voit, plutôt qu'un refus. Aucune place : la naissance est refusée (un essai, une ligne au
   journal avec les refus par raison, comme avant).
3. **L'approche** : l'homme marche jusqu'à son cheval ; le délai de la monte s'allonge du temps de la marche :
   `scriptorium_monte_approche_ms` (variable de cerveau écrite par la liaison avec l'ordre), la distance de l'homme à
   son cheval à `monte_approche_m_par_s` (1 m/s, une marche prudente), au plus `monte_approche_max_ms` (60 000) ; l'arbre
   l'ajoute à `monte_delai_ms`.
4. **Au banc** : un camp fondé au niveau 3 (tous ses meubles), l'enceinte bâtie, trois hommes au feu ; chaque cheval à
   au moins 3 m de chaque meuble et de chaque objet de l'enceinte, hors du cercle, à 3 m des autres ; l'approche donnée ;
   un homme hors du camp : son cheval à 5 m de lui, hors du cercle ; aucune place possible : refus.

### Relecture du pair (17/10)
- Fiche bonne ; deux ajouts à la « bonne place » : **le sol** (au sol, pas dans l'eau, pas sur une pente trop raide : un
  cheval mal posé glisse ou reste coincé) et **la vue d'Henry** (préférer les angles qu'il ne voit pas ; ceux qu'il voit
  seulement si aucun autre ne convient, plutôt que refuser ; la règle des hommes posés d'un coup). Faits.
- **L'eau** : aucun script du jeu ne la lit (`Scripts.pak`, lecture seule : ni `GetWaterLevel` ni `ent_water`) ; deux
  recherches sur la toile (documentation de CryEngine 5) sans réponse sûre. D'où la mesure prudente : le rayon descendu
  ajoute `ent_water` seulement si le jeu le donne (« eau lisible », écrit au journal de la séance) ; à vérifier en jeu.

### Règles en données (catalogue)
- `hommes.reglages` : `cheval_hors_camp_m` 6, `cheval_places_essayees` 8, `cheval_ecart_meuble_m` 3,
  `cheval_ecart_cheval_m` 3, `cheval_pente_max` 0,5, `cheval_sol_pas_m` 1,5, `monte_approche_m_par_s` 1,
  `monte_approche_max_ms` 60 000.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé ; camp fondé, trois hommes au camp ; `essai_troupe_a_cheval`.
1. **Trois chevaux hors du camp**, du côté de la porte, sur l'herbe, aucun dans un meuble (à l'image, et journal).
2. **Les hommes marchent jusqu'à eux et montent** sans monte manquée (l'approche comptée).
3. Puis comme V73 f 2 b : la troupe suit Henry ; fin de sortie, descentes, chevaux retirés.
- Décompte de l'écran noir (fiche 14).

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **Où naît le cheval d'un homme au camp** : (a) hors du camp, du côté de la porte (Recommandé : le conseil du pair,
   aucun meuble là, et vraisemblable) ; (b) à 5 m de l'homme, loin des meubles. **Prise : (a).**
2. **L'écart aux meubles** : (a) 3 m (Recommandé : un cheval est plus long qu'un homme) ; (b) 2 m, comme les postes.
   **Prise : (a).**
3. **Le délai de monte** : (a) allongé du temps de la marche jusqu'au cheval (Recommandé) ; (b) inchangé.
   **Prise : (a).**

### Mesuré en V73 f 2 c (17/10) : le cheval né hors des meubles, acquis
- c65f206, `playline3` (473), sans `-devmode`, secours coupé puis remis ; trois hommes au camp.
- **Ce que le jeu laisse lire** : « Sol : rayon lisible, eau illisible (pas de `ent_water`) ». La pente et l'encombrement
  se mesurent ; **l'eau, non** (point ouvert : un cheval peut encore naître dans un ruisseau peu profond si rien d'autre
  ne l'encombre).
- **Trois chevaux nés hors du camp**, côté porte, dans le pré (refus au journal : 1, 6 et 1 places dans le cercle, 2 près
  d'un autre cheval) ; tous vus d'Henry, le point de sortie étant devant lui (la règle : plutôt vu que refusé).
- **Les hommes marchent jusqu'à eux et montent** sans monte manquée (l'approche comptée), puis rejoignent Henry à cheval.
- Fin de sortie : chevaux retirés au battement.
- **L'eau, limite connue** (le pair, 17/10) : ni Alex ni Scriptorium ne la lisent, ni aucun script du jeu de base.
  Deux parades : la monte manquée bornée (un cheval dans un ruisseau où l'homme ne monte pas dans le délai est retiré et
  renaît sous un autre angle : la parade d'Alex contre la barrière) ; plus tard, faire naître les chevaux **sur le chemin
  le plus proche** (Scriptorium sait le trouver, entre 40 et 220 m du camp : un chemin est sec et praticable, c'est là
  qu'on attache les montures). Rien de plus pour l'instant.
- Ouvert : « jamais reposé seul » et « fermer avant d'ouvrir » toujours pas éprouvés en jeu.

## V73 f 2 d — l'escorte monte quand Henry monte (17/10, relu par le pair, vu en jeu par la lecture forcée ; réponses recommandées prises d'office)

### Le périmètre
- Relecture du pair (V73 f 2 b) : chez Alex comme chez Scriptorium, l'escorte d'Henry **monte quand Henry monte et
  descend quand il descend**, avec un **anti-rebond** (monter tout de suite, descendre seulement après plusieurs
  lectures de suite). La règle de JoVenGer « tous ceux qui sortent du camp partent à cheval » vaut pour les sorties sans
  Henry (`a_cheval = true`, déjà fait).
- **Ce pas** : le second déclencheur, pour les hommes. Le Directeur monté (chef de colonne) : au pas suivant.

### Ce que le jeu fait (lu dans `Scripts.pak`, lecture seule)
- `player.player:GetPlayerHorse()` rend le WUID du cheval d'Henry (`__null` s'il n'en a pas), puis
  `XGenAIModule.GetEntityByWUID` donne l'entité (`Scripts/Utils/GameUtils.lua`, `HideHorseCutscene`) ;
  `cheval.horse:HasRider()` dit si quelqu'un le monte (`Scripts/Entities/AI/Horse.lua`).
- Les arbres du jeu lisent la monte d'Henry par `StanceCheck soul="$__player" stance="horse" smartObject="$horse"`
  (`AI/world/sa_land.xml`) : il faut le cheval ; le Lua le donne déjà.

### Comment ce serait fait
1. **La lecture** (`liaison.henry_a_cheval(pres)`) : vrai si un cheval monté (n'importe lequel, sauf les nôtres) se
   tient à moins de `henry_cheval_pres_m` (1,5) d'Henry ; faux sinon ; nil si rien n'est lisible (voir la relecture du
   pair ci-dessous).
2. **La veille** (`hommes`) : toutes les `henry_veille_ms` (1 000), une minuterie lancée à l'entrée en partie (comme le
   guet du noyau, arrêtée au changement de partie) lit Henry. **Monté** : tout de suite. **À pied** : seulement après
   `henry_descente_lectures` (4) lectures « à pied » de suite (une lecture « monté » remet le compte à zéro). Une lecture
   illisible ne change rien. À chaque changement, une ligne au journal, et l'ordre redonné aux hommes dont l'escorte
   suit Henry « comme Henry » ; à la descente, l'abandon des montes manquées est oublié (comme chez Alex).
3. **La tenue** : `a_cheval = "comme_henry"` (sinon un booléen, comme avant) : l'homme est en sortie à cheval tant
   qu'Henry est retenu monté. Henry descend : la sortie à cheval finit, le cheval est retiré par la règle de V73 f 2 b
   (l'homme éloigné de 6 m, ou au 2e battement) ; Henry remonte avant : le cheval encore vivant resert.
4. **Les commandes d'essai** : `essai_escorte_comme_henry` (les trois premiers hommes suivent Henry « comme Henry », en
   formation followNPC) ; `essai_cheval_d_henry` (le cheval d'Henry amené à 4 m devant lui, sur un sol libre, pour la
   séance) ; `essai_henry_a_cheval` et `essai_henry_a_pied` (la lecture forcée, pour éprouver la chaîne sans
   monter) ; `essai_henry_lu` (retour à la vraie lecture). `essai_hommes_voir` dit aussi la lecture d'Henry.

### Relecture du pair (17/10), qui change la lecture
- Fiche bonne (le cheval resservi si Henry remonte vite, l'abandon oublié à la descente). **Chez Alex, Henry « monté » se
  lit par sa posture**, pas par son cheval : un `StanceCheck` dans un arbre, `soul` = Henry, `stance="horse"`,
  `smartObject=""` (n'importe quel cheval : un cheval volé ou emprunté compte) ; l'anti-rebond dans le Lua. Conseil :
  garder la lecture Lua en filet, faire lire la posture par un arbre.
- **Essayé, puis retiré** (ef36ec9) : la lecture par l'arbre. Sa seule ligne possible
  (`StanceCheck soul="$__player" stance="horse" smartObject=""`, avec les attributs du jeu) est celle d'Alex, et elle
  n'est pas telle quelle dans le jeu (le jeu n'écrit « horse » qu'avec un objet : `$horse`, `$companion`) : on ne peut
  pas l'admettre comme forme du jeu. L'avoir inversée (`negate="true"`) dans le seul but de passer le contrôle, c'est ce
  que JoVenGer a écarté le 16/10 (« c'est tromper le contrôle ») : rappel du pair, juste ; retiré.
- **Fait à la place, notre mécanisme** : la lecture en Lua de **n'importe quel cheval monté près d'Henry**
  (`System.GetEntitiesInSphereByClass(…, "Horse")`, déjà employé pour les places libres ; `horse:HasRider()`), à moins
  de `henry_cheval_pres_m` (1,5 m) ; nos chevaux (nom commençant par `scriptorium_cheval_`) ne comptent pas. Un cheval
  emprunté ou volé compte. Limite connue : un cavalier du jeu qui passe à moins de 1,5 m d'Henry à pied le ferait
  croire monté une seconde (l'escorte monterait, puis redescendrait après 4 s). **À dire à JoVenGer** : la lecture par
  l'arbre demanderait d'admettre la ligne d'Alex, ce qui est sa décision.
- **Pour plus tard** (idée d'Alex) : un réglage « pas de chevaux » : Henry monte, la Compagnie jamais ; la formation
  prend un modèle à pied, et le rattrapage d'un coup reste armé (des hommes à pied suivent un cavalier). Utile si
  JoVenGer veut couper les chevaux pour la fluidité.

### Règles en données (catalogue)
- `hommes.reglages` : `henry_veille_ms` 1 000, `henry_descente_lectures` 4, `henry_cheval_pres_m` 1,5.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé, trois hommes ; `essai_escorte_comme_henry`.
1. **Henry à pied** : la lecture dit « à pied » (ou « pas de cheval ») ; les hommes suivent à pied (ordres 15 et 16).
2. **La chaîne forcée** : `essai_henry_a_cheval` : tout de suite, trois chevaux naissent et les hommes montent ;
   `essai_henry_a_pied` : la descente retenue après 4 lectures (4 s), les hommes descendent, chevaux retirés au battement.
3. **La vraie monte** (si Henry a un cheval) : `essai_henry_lu`, `essai_cheval_d_henry`, Henry monte (touche
   « utiliser ») : la lecture dit « monté », les hommes montent ; Henry descend : ils descendent après 4 s.
- Décompte de l'écran noir (fiche 14).

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **La lecture** : (a) le cheval d'Henry a un cavalier, près d'Henry, en Lua (Recommandé : déjà lisible, aucune branche
   d'arbre de plus) ; (b) un `StanceCheck` dans l'arbre de chaque homme. **Prise : (a).**
2. **L'anti-rebond** : (a) 4 lectures à pied de suite, une par seconde (Recommandé : le principe du pair) ; (b) une
   seule. **Prise : (a).**
3. **La séance** : (a) la chaîne forcée d'abord, puis la vraie monte si Henry a un cheval (Recommandé) ; (b) la vraie
   monte seulement. **Prise : (a).**

### Mesuré en V73 f 2 d (17/10)
- a4e12b6, `playline3` (473), sans `-devmode`, secours coupé puis remis ; trois hommes.
- **Henry à pied** : la vraie lecture rend « false » ; l'escorte « comme Henry » suit à pied en formation (15 et 16).
- **La chaîne, lecture forcée** : à cheval, l'escorte monte tout de suite (trois chevaux nés hors de la vue d'Henry,
  trois montes, ordres 18 et 19) ; à pied, la descente seulement après 4 lectures de suite, les hommes à pied, les
  chevaux retirés au battement. Acquise.
- **Le cheval d'Henry** (« kmal_horseForSale_2 ») amené à 4 m devant lui : posé, sellé.
- **La vraie monte d'Henry n'a pas abouti** : la touche E simulée (code de balayage 0x12, appui court puis long, au
  flanc) ne fait pas monter Henry ; arrêt après deux échecs. **Non vérifié en jeu** : la lecture « monté » vraie (un
  cheval monté à moins de 1,5 m d'Henry). À éprouver par JoVenGer en jouant, ou par une autre façon de faire monter
  Henry (à chercher, pas une troisième variante de la touche). Le pair (17/10) : ni Alex ni Scriptorium ne font
  monter Henry par script ; le jeu a deux comportements du joueur (`AI/player/scheduler/playerAction_horse.xml`,
  `playerAction_teleportOnHorse.xml`), lancés sans doute par les quêtes. **À vérifier par JoVenGer**, en jouant : il
  monte sur son cheval, l'escorte « comme Henry » monte ; il descend, elle descend au bout d'environ 4 s.
- Les parades du pair au faux départ (un cavalier du jeu qui frôle Henry) : deux lectures « monté » de suite, ou la
  hauteur d'Henry au-dessus du sol (à mesurer d'abord, monté et à pied) ; pas encore faites.

## V73 f 2 e — le Directeur monté, chef de colonne (17/10, relu par le pair, fait et vu en jeu ; réponses recommandées prises d'office)

### Le périmètre
- Relecture du pair (V73 f 2 b) : chez Scriptorium, **le Directeur est le chef de la colonne** ; quand il est là, il
  reprend la tête, et « le premier homme mène » ne sert qu'en son absence.
- **Ce pas** : le Directeur suit Henry à cheval (toujours, ou « comme Henry »), mène la formation monté, et l'escorte
  d'Henry en formation se range derrière lui d'elle-même.

### Comment ce serait fait
1. **Le service** : `directeur.suivre(oui, formation, a_cheval)` ; `a_cheval` : rien (à pied), vrai (toujours à cheval)
   ou « comme_henry » ; autre chose : refus `a_cheval_invalide`. Gardé à son registre, comme `formation`.
2. **Son cheval** : le même que celui des hommes (V73 f 2 b et c) : un cheval passager, en mémoire, né hors des
   meubles, la monte bornée et la monte manquée (3 essais), le retrait après la sortie. Le code des chevaux sert à un
   « porteur » : un homme (sa tenue) ou le Directeur (son registre, clé « directeur »).
3. **Son ordre** : en sortie à cheval, « suivre » à cheval dans son rôle (mener sa formation : ordre 18 ; sinon 17) ;
   l'approche comptée. Son ordre est redonné quand son activité **ou sa monture** change (le nom du cheval et le rôle
   dans sa signature, comme pour les hommes). À cheval, jamais reposé seul par le rattrapage (comme les hommes).
4. **Henry monte, Henry descend** (V73 f 2 d) : la veille redonne aussi l'ordre du Directeur s'il suit « comme Henry ».
5. **Il reprend la tête** (réglable : `hommes.reglages.directeur_mene_l_escorte`, vrai) : quand il suit Henry en
   formation, une escorte d'Henry en formation (chef « henry » ou rien) se range dans **sa** formation (le chef de
   chacun : le Directeur) au lieu que son premier homme en ouvre une autre.
6. **Les commandes d'essai** : `essai_directeur_a_cheval` (le Directeur suit Henry « comme Henry » en formation
   followNPC, et les trois premiers hommes « comme Henry » derrière Henry) ; `essai_fin_escorte` (déjà là, lâche aussi
   le Directeur) ; la lecture forcée (`essai_henry_a_cheval`, `essai_henry_a_pied`).

### Règles en données (catalogue)
- `hommes.reglages.directeur_mene_l_escorte` : vrai.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé, trois hommes, le Directeur ; `essai_directeur_a_cheval`.
1. **À pied** : le Directeur mène (ordre 15), les trois hommes se rangent dans sa formation (ordre 16, chef le
   Directeur), même si leur escorte dit « henry ».
2. **Lecture forcée à cheval** : quatre chevaux naissent ; le Directeur mène monté (18), les hommes se rangent montés
   (19) derrière lui ; à l'image, le Directeur en tête.
3. **L'allure du chef** (relecture du pair) : l'écart Directeur–Henry, lecture forcée à cheval, Henry au pas puis à la
   course ; s'il dépasse nettement les 2 à 4 m de la colonne à pied, il faudra l'allure du chef réglée sur la vitesse
   d'Henry (le principe d'Alex, repoussé en V73 f 2 b).
4. **Lecture forcée à pied** : tout le monde descend après 4 s, chevaux retirés au battement.
- Décompte de l'écran noir (fiche 14).

### Relecture du pair (17/10)
- Fiche bonne : c'est `directeur_en_route` de Scriptorium (le Directeur chef de la formation, la troupe derrière lui).
  Scriptorium dit qu'il « tient l'allure d'Henry » (au pas, à la course, à cheval) : en tête d'une colonne montée, s'il
  distance Henry ou traîne, toute la colonne fait de même. À mesurer dans la séance (point 3 de la grille).
- Fait en plus : un essai probant du rattrapage (le Directeur à pied loin d'Henry est rattrapé ; à cheval, non).

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **Le cheval du Directeur** : (a) le même mécanisme que les hommes, un « porteur » de plus (Recommandé : un seul code
   des chevaux) ; (b) un cheval à lui, gardé au registre. **Prise : (a).**
2. **Il reprend la tête d'elle-même** : (a) oui, réglable (Recommandé : la règle de Scriptorium transmise par le pair) ;
   (b) seulement si l'escorte dit chef « directeur ». **Prise : (a).**

### Mesuré en V73 f 2 e (17/10) : le Directeur monté, acquis ; son allure, à faire
- a0e7449, `playline3` (473), sans `-devmode`, secours coupé puis remis ; trois hommes et le Directeur.
- **Il reprend la tête** : à pied, les trois hommes se rangent dans sa formation (ordre 16, chef le Directeur).
- **Lecture forcée à cheval** : quatre chevaux ; il mène monté (18), les hommes rangés montés (19) ; à l'image, en tête.
- **Son allure** : à l'arrêt 4,11 m d'Henry ; juste après 10 s de marche d'Henry 15,93 m, puis 2,43 m 8 s plus tard ;
  juste après 5 s de course 11,61 m, puis 2,28 m 8 s plus tard ; la formation tient derrière lui (1,6–5 m). **Le chef
  monté démarre tard** (déjà vu en V73 f 2 b : le premier homme monté à 17,98 m après 10 s de marche) : nettement au-delà
  des 2 à 4 m de la colonne à pied. Selon la relecture du pair, **l'allure du chef réglée sur la vitesse d'Henry** est le
  pas suivant (V73 f 2 f).
- Descente après 4 lectures, il mène à pied de nouveau ; son cheval retiré au battement avec ceux des hommes.

## V73 f 2 f — l'allure du chef monté réglée sur Henry (17/10, relu par le pair ; réponses recommandées prises d'office)

### Le périmètre
- Mesuré en V73 f 2 b et e : le chef monté démarre tard (11 à 18 m d'Henry juste après que celui-ci se met en route,
  rattrapé en 8 s) ; la colonne fait de même.
- **Ce pas** : le chef monté (ordre 18 : le Directeur, ou le premier homme) règle son allure sur la vitesse de son chef
  (Henry). Les suiveurs montés qui perdent leur place (ordre 19, repli) et le cavalier seul (ordre 17) : au pas suivant.

### Ce que le jeu fait (lu dans `Scripts.pak`, lecture seule)
- `followNpc` (`AI/move/moveUtils.xml`) : à moins de `startDistance` (5 m), le suiveur s'arrête et attend 1 s ; sinon il
  marche ; chaque seconde, il ne passe à la course qu'au-delà de `walk2run` (20 m) : un cheval au pas traîne jusqu'à
  20 m : c'est ce qu'on a mesuré.
- Le `Move` du jeu prend son allure dans une variable (`speed="$speed"` dans `followNpc`) ; les allures : `walk`, `run`,
  `dash`, `sprint` (`movementSpeed`, plus de 10 emplois chacune). Une horloge en Lua : `System.GetCurrTime()`
  (`Scripts/Entities/Physics/AnimObject.lua`).

### Le principe d'Alex (transmis par le pair, principe seulement)
- Le chef monté ne peut pas être un suiveur de formation : il se mène lui-même par un `Move` vers son chef (arrêt à 3 m
  ± 1, `changeNPCState`), son allure tenue par une variable : 3 galop (`sprint`), 2 trot rapide (`dash`), 1 course
  (`run`), 0 pas (`walk`), −1 « tenir » (il attend au lieu d'avancer).
- **La vitesse d'Henry mesurée par sa position** : toutes les 300 ms, un appel au Lua depuis l'arbre relève sa
  position ; vitesse = distance parcourue / temps écoulé ; **elle donne l'allure**. La distance ne fait qu'une petite
  correction : le chef vise une place à 7 m de lui ; au-delà de 7 + 4 m, une allure de plus ; en deçà de 7 − 3 m, une
  de moins ; Henry arrêté et le chef à sa place : il tient.
- **La leçon** : sa première version choisissait l'allure d'après l'écart seul (galop au-delà de 10 m, pas en deçà,
  relevé chaque seconde) : à-coups du chef, et la colonne en accordéon (chaque suiveur `MoveHistory` refait son chemin).
  Régler la vitesse sur celle d'Henry tient l'écart constant.

### Comment ce serait fait
1. **La règle, en données, chez les hommes** (`hommes.allure_du_chef(vitesse, ecart)`) : vitesse sous
   `allure_arret_m_s` (0,3) : il tient s'il est à sa place (écart ≤ 7 + 4), sinon pas ; sous `allure_pas_m_s` (2,2) :
   pas ; sous `allure_course_m_s` (4,5) : course ; sous `allure_galop_m_s` (8) : trot rapide (`dash`) ; au-delà :
   galop (`sprint`) ; puis la correction : au-delà de `allure_place_m` (7) + `allure_plus_m` (4), une de plus (au plus
   3) ; en deçà de 7 − `allure_moins_m` (3), une de moins (jusqu'à « tenir »).
2. **La mesure, dans la liaison** (`liaison.allure_vers_chef(entite, donnees)`, appelée par l'arbre) : la position du
   chef (Henry ou un homme) et l'heure (`System.GetCurrTime`) gardées à chaque relevé ; vitesse = distance / temps ;
   l'écart du cavalier à son chef ; la règle accrochée par les hommes (comme la ronde) ; « allure_code » écrit pour
   l'arbre ; une ligne au journal **seulement quand l'allure change**.
3. **L'arbre, branche 18** (le chef monté) : dans la posture « horse », à la place de `followNpc`, une boucle : la
   mesure ; l'allure posée dans `$allure` (un `IfCondition` par allure, la forme de la branche 12) ; un seul `Move` vers
   `$scriptorium_chef` (arrêt `allure_arret_cm` 300 ± `allure_ecart_cm` 100) à `speed="$allure"`, ou une attente pour
   « tenir » ; en parallèle, une nouvelle mesure toutes les `allure_cadence_ms` (300) : l'allure change → le `Move` est
   redonné. La formation reste dans sa branche à part (inchangée).
4. **Latence ajoutée, signalée** : un appel au Lua toutes les 300 ms par chef monté (un ou deux par troupe), quelques
   opérations ; aucune autre.

### Relecture du pair (17/10)
- Fiche bonne ; `speed="$allure"` : la preuve vient du jeu (`followNpc` passe `speed="$speed"`), elle vaut mieux que la
  note d'Alex (un nœud par allure) ; redonner le `Move` à chaque changement d'allure est la bonne précaution.
- **Mesurer le bon homme** : la vitesse de **celui que le chef suit** (Henry), pas la sienne, sinon il ne démarrerait
  jamais. Fait et éprouvé au banc (le cavalier bouge, Henry non : vitesse nulle).
- **Un seuil qui hésite** : près d'un seuil, l'allure basculerait à chaque relevé. Fait : `allure_marge` (10 %) : on
  ne monte d'allure qu'au-dessus du seuil plus la marge, on ne descend qu'en dessous du seuil moins la marge ; la ligne
  au journal « seulement quand l'allure change » dira en jeu si ça bascule trop.

### Règles en données (catalogue)
- `hommes.reglages` : `allure_arret_m_s` 0,3, `allure_pas_m_s` 2,2, `allure_course_m_s` 4,5, `allure_galop_m_s` 8,
  `allure_marge` 0,1, `allure_place_m` 7, `allure_plus_m` 4, `allure_moins_m` 3.
- `hommes.cerveau` : `allure_cadence_ms` 300, `allure_arret_cm` 300, `allure_ecart_cm` 100.

### Essai en jeu : grille écrite avant la séance
`playline3`, secours coupé, trois hommes, le Directeur ; `essai_directeur_a_cheval`, lecture forcée à cheval.
1. Henry marche 10 s : l'écart Directeur–Henry juste après, puis 8 s plus tard ; Henry court 5 s : idem. But : près de
   7 m, sans à-coups (journal des allures).
2. La formation tient derrière lui, sans accordéon (écarts des hommes à lui).
- Décompte de l'écran noir (fiche 14).

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **Le remède** : (a) l'allure réglée sur la vitesse mesurée d'Henry, la distance en correction (Recommandé : le principe
   d'Alex, et sa leçon contre l'accordéon) ; (b) des seuils de distance plus bas dans `followNpc` (sa première version,
   écartée). **Prise : (a).**
2. **Pour qui** : (a) le chef monté d'abord (Recommandé : une chose à la fois) ; (b) tous les cavaliers tout de suite.
   **Prise : (a).**

### Mesuré en V73 f 2 f (17/10) : le chef monté ne traîne plus, l'écart à affiner
- 4869393, `playline3` (473), sans `-devmode`, secours coupé puis remis ; le Directeur et trois hommes, lecture forcée.
- **L'écart Directeur–Henry** : à l'arrêt 9,0 m ; juste après 10 s de marche **10,8 m** (15,9 m en V73 f 2 e) ; juste
  après 5 s de course **8,7 m** (11,6 m) ; la formation tient derrière lui (1,3–4,2 m).
- **Le journal des allures** : 7 changements en une quarantaine de secondes, entre pas et course autour de 11 m ;
  aucune bascule à chaque relevé (la marge des vitesses tient).
- **À reprendre** (V73 f 2 f bis) : arrêté, le chef « tient » dès 11 m (ma règle : place + plus), au lieu d'aller à sa
  place (7 m) comme le dit le principe ; la correction par la distance, sans marge, fait l'aller-retour pas/course à 11 m.

## V73 f 2 f bis — l'allure du chef monté, affinée (17/10 ; réponses recommandées prises d'office)

### Ce qui change (d'après la mesure de V73 f 2 f)
1. **Arrêté, il tient seulement à sa place** (écart ≤ `allure_place_m`, 7 m) ; plus loin, il va au pas jusqu'à elle. Ma
   règle de V73 f 2 f le faisait tenir dès 11 m (place + plus), contrairement au principe transmis (« à sa place »).
2. **La correction par la distance, tenue** : « une allure de plus » au-delà de la place + `allure_plus_m` (11 m), gardée
   tant qu'il n'est pas revenu à sa place (7 m) ; « une de moins » en deçà de la place − `allure_moins_m` (4 m), gardée
   tant qu'il n'est pas revenu à 7 m. Fini l'aller-retour pas/course autour de 11 m. La règle reçoit la correction du
   relevé précédent (gardée par la liaison, comme l'allure de fond).
3. **Relecture du pair** : l'arrêt aussi a sa tenue : il s'arrête à ≤ 7 m, et ne repart au pas qu'au-delà de la
   place + plus (11 m ; mon ancien seuil était le bon pour repartir) ; « une de plus » est lâchée un peu avant la place,
   à la place + `allure_freinage_m` (1 m, soit 8 m) : à cheval, il faut de la distance pour freiner. À vérifier à
   l'image : après une course, il s'arrête vers 7 m, pas à 3-4 m (son `Move` s'arrête à 3 m ± 1 d'Henry ; il ne doit
   pas bousculer le cheval d'Henry).
- Une valeur nouvelle : `hommes.reglages.allure_freinage_m` (1).

### Vu en jeu, première séance du bis (17/10, 06833ae)
- **Le freinage marche** : « course » jusqu'à 8 m, puis « pas » à 7,9 m, « tenir » à 6,5 m.
- **Mais le chef se fige** (11,34 m puis 20,52 m d'Henry, constant, plus aucun changement d'allure). Cause : le `Move`
  visait la place d'Henry au moment de l'ordre, puis l'attente sans fin le gardait arrêté tant que l'allure restait la
  même. **Corrigé** : le `Move` reçoit `additionalParams="$allure_parametres"` (`destChangedThreshold`, comme
  `followNpc` : il suit sa cible qui bouge) ; après le `Move`, une attente d'une cadence (300 ms), puis il est redonné ;
  contrôlé au banc (deux erreurs injectées attrapées).

### Mesuré en V73 f 2 f bis, seconde séance (17/10, f91587e) : l'allure du chef monté, acquise
- **L'écart Directeur–Henry** : juste après 10 s de marche **5,4 m** (10,8 m en V73 f 2 f, 15,9 m en V73 f 2 e) ; juste
  après 4 s de course **4,3 m** (8,7 m ; 11,6 m) ; arrêté, 4,3 à 6,4 m (il ne se colle pas à 3 m) ; la formation tient
  derrière lui (1,6–4,1 m).
- **Le journal** : quatre changements d'allure seulement (pas, tenir, pas, tenir) ; le freinage à 8 m (« course » →
  « pas » à 7,6 m → « tenir » à 6,8 m).
- À l'image : les cavaliers à quelques mètres derrière Henry, sans le bousculer ; aucun petit arrêt visible.
- (Le message de l'enregistrement f91587e disait déjà « le chef ne se fige plus » avant cette séance : c'était
  prématuré ; c'est vérifié ici.)
- Suite : l'allure des suiveurs montés qui perdent leur place (ordre 19, repli) et du cavalier seul (ordre 17).

### Essai en jeu : grille
Comme V73 f 2 f : l'écart Directeur–Henry au pas et à la course, et le journal des allures ; but : le chef près de
7 m à l'arrêt, moins de changements d'allure.

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **La marge de la distance** : (a) tenue jusqu'au retour à la place (Recommandé : aucune valeur de plus) ; (b) une
   valeur de marge à part. **Prise : (a).**

## V73 f 2 g — l'allure de tous les cavaliers (17/10, principe relu par le pair ; réponses recommandées prises d'office)

### Le périmètre
- Relecture du pair (V73 f 2 f) : chez Alex, l'allure est calculée pour **chaque** homme, pas seulement pour le chef :
  un suiveur monté qui perd un instant sa place dans la formation retombe sur les mêmes nœuds d'allure, sinon il resterait
  au pas et sortirait de la colonne.
- **Ce pas** : la même boucle d'allure que le chef monté (V73 f 2 f bis), pour le cavalier seul (ordre 17, à la place de
  `followNpc` en selle) et pour le suiveur monté qui n'a pas (ou plus) sa formation (ordre 19, le repli de 4 s, à la place
  de `followNpc`). Les replis à pied après une monte manquée gardent `followNpc` (à pied, il ne traîne pas).

### Le principe d'Alex pour le suiveur (transmis par le pair, avec ses corrections)
- Un suiveur monté qui a sa formation n'a aucune allure à lui (le suiveur du moteur règle sa vitesse). S'il la perd, il
  retombe sur les mêmes `Move` que le chef. Chez Alex, une seule mesure (la vitesse d'Henry, lissée), la correction sur
  la distance à Henry, même quand il vise son chef : une incohérence à ne pas reprendre.
- **À faire mieux** (le pair) : 1. il se mène vers son **chef de formation**, pas vers sa place (qui bouge avec le chef) ;
  deux seuils : **perdu au-delà de 12 à 15 m** du chef, **de retour dans le rang en deçà de 6 m** ; 2. la vitesse
  mesurée est celle de **celui qu'il vise** (son chef : quand le chef rattrape Henry, il va plus vite qu'Henry), et la
  correction sur **sa** distance à son chef ; 3. **une mesure par homme suivi**, partagée par tous ceux qui le suivent ;
  4. **les sauts d'Henry ignorés** : un relevé au-delà de 20 m/s n'est pas une course.

### Comment ce serait fait
1. **La règle** (`hommes.allure_du_chef`) rend aussi « perdu » : au-delà de `allure_perdu_m` (13) de son chef, ou déjà
   perdu et encore au-delà de `allure_rang_m` (6). **Le filtre des sauts** (`hommes.vitesse_retenue`) : un relevé
   au-delà de `allure_saut_m_s` (20) garde la vitesse d'avant. Les deux accrochés à la liaison avec la règle.
2. **La mesure** (`liaison.allure_vers_chef`) : la vitesse **par homme suivi** (`liaison.vitesses_des_chefs`, une seule
   pour tous ses suiveurs) ; le reste (allure, correction, perdu) par cavalier ; « allure_perdu » écrit pour l'arbre ;
   une ligne au journal quand l'allure change, et quand un suiveur perd ou reprend sa place.
3. **Branche 17** (le cavalier seul) : la boucle d'allure de la branche 18 à la place de `followNpc` en selle.
4. **Branche 19** (le suiveur monté), dans la posture : une mesure, puis **perdu** : la boucle d'allure vers son chef,
   tant qu'il est perdu ; **sinon** : son suivi de formation comme avant (et son repli sans formation, 4 s, par la boucle
   d'allure au lieu de `followNpc`), avec, en parallèle, une mesure toutes les `$reessai` (4 s) pour voir s'il s'est
   perdu.
5. Les replis à pied après une monte manquée gardent `followNpc` (à pied, la suite ne traîne pas).
6. **Latence ajoutée** : un appel au Lua toutes les 300 ms par cavalier qui se mène lui-même (le chef, le cavalier seul,
   un suiveur perdu) ; une mesure toutes les 4 s par suiveur rangé.

### Règles en données (catalogue)
- `hommes.reglages` : `allure_saut_m_s` 20, `allure_perdu_m` 13, `allure_rang_m` 6.

### Essai en jeu : grille
`playline3`, secours coupé ; le Directeur et trois hommes « comme Henry », lecture forcée à cheval ; Henry marche et court.
1. Le journal : des lignes d'allure pour le Directeur ; pour un suiveur, seulement s'il perd sa place.
2. Un cavalier seul (`essai_escorte_a_cheval`, la sonde, sur le cheval d'essai) : l'écart à Henry au pas et à la course,
   comme le chef (sous 6 à 8 m).
- Décompte de l'écran noir (fiche 14).

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **Les replis à pied** : (a) garder `followNpc` à pied (Recommandé : à pied, la suite ne traîne pas, vu en V73 f 1) ;
   (b) la boucle d'allure partout. **Prise : (a).**

### Mesuré en V73 f 2 g (17/10, 352cbfc) : l'allure de tous les cavaliers, acquise
- **Les suiveurs** arrivés de loin rejoignent le Directeur par la boucle d'allure (le repli sans formation), puis
  « tenir » à 0,6–3,4 m de lui.
- **La perte et le retour** (seuils abaissés un moment, 3 et 1,5 m, par le fichier de réglages : un saut d'Henry
  n'éloigne pas un suiveur de son chef, remarque du pair ; déplacer un cavalier le séparerait de son cheval) : « sa place
  perdue (à 4,3 m) », il rejoint son chef à l'allure du Directeur, puis, seuils remis, « de retour dans le rang (3,8 m) ».
- **Le cavalier seul** (ordre 17) : 4,2 m après 10 s de marche, 4,35 m après 4 s de course (12,45 et 10,76 m avec
  `followNpc`, V73 f 2 a).
- Corrigé après la séance : la ligne « perdu / de retour dans le rang » n'est plus écrite pour qui suit Henry (le chef de
  colonne, le cavalier seul), seulement pour qui suit un autre cavalier ; contrôlé au banc.
- L'outil `regler.py` ajoute aux valeurs déjà écrites : un réglage d'essai se retire par `--retirer`.

## V73 f 3 a — suivre Henry partout : la sonde de la carte (17/10, relu par le pair ; réponses recommandées prises d'office)

### Le périmètre
- Idée n° 3 validée par JoVenGer (15/10) : suivre Henry partout (voyage rapide, villes et intérieurs, d'une carte à
  l'autre) ; à l'arrivée, l'escorte réapparaît près d'Henry.
- **Ce que le pair a transmis** (principe d'Alex, corrigé par Scriptorium) : les deux régions (Trosky, Kuttenberg) sont
  deux cartes ; tout ce qui est né appartient à sa carte ; la compagnie voyage en mémoire et ses hommes sont refaits
  près d'Henry à l'arrivée (par paquets, même âme, même nom ; hors de sa vue, sur un sol vérifié ; à cheval s'ils
  l'étaient) ; le camp reste sur sa carte ; ce que Scriptorium décide : qui passe. Distinguer un passage de carte d'un
  chargement de partie : chez Alex, par l'horloge du monde (0 à 2 jours ; 10 jours chez Scriptorium, après une perte de
  40 hommes) ; **à faire mieux : un signe du jeu**. Le voyage rapide sur une même carte est un saut (le rattrapage le
  couvre, sauf nos cavaliers, à traiter) ; les maisons sont dans la même carte.
- **Ce pas : une sonde**, avant toute règle : que dit le jeu au chargement d'une carte et d'une sauvegarde, et peut-on
  lire le nom de la carte en Lua ?

### Ce que le jeu offre (lu, lecture seule ; deux recherches)
- Aucun script Lua du jeu ne lit le nom de la carte (`Scripts.pak`). `Game.IsLoadingEngineSaveGame()` existe
  (`Scripts/Entities/Others/RuntimePrefab.lua`) et nous sert déjà au guet.
- Les événements d'interface du groupe « System » de CryEngine (documentation de CryEngine 5, « UI Action ») :
  `OnLoadingStart`, `OnLoadingComplete`, `OnLoadingError`, `OnUnloadStart`, `OnUnloadComplete` ; le socle s'abonne
  déjà à `OnGameplayStarted` et `OnGameplayEnded` de cette façon (`UIAction.RegisterEventSystemListener`).

### Comment ce serait fait
1. **Les abonnements de plus** (liaison) : `OnLoadingStart`, `OnLoadingComplete`, `OnLoadingError`, `OnUnloadStart`,
   `OnUnloadComplete` : à chacun, une ligne au journal avec ses arguments tels quels et ce que rend
   `Game.IsLoadingEngineSaveGame()` ; le dernier gardé en mémoire. Un abonnement refusé est dit (comme les autres).
2. **La carte lue** (`liaison.carte_courante()`) : la variable du moteur `sv_map` sous `pcall` ; puis **l'altitude
   du terrain** en un point connu de chaque carte (`System.GetTerrainElevation`, tolérance 1,5 m ; relecture du pair :
   ce qui marche chez Scriptorium depuis le 5/10, la tournée du coursier) : kutnohorsko, x 1548,706, y 1916,385 →
   143,74 m (sous le forgeron de Miskovice) ; trosecko, x 1997,568, y 2499,344 → 115,34 m (sous le forgeron de Radovan).
   La voie qui a répondu, écrite au journal à l'entrée en partie. Les autres lectures de nom que j'avais devinées
   (`CryAction`, `Game`, `System.GetLevelName`) sont retirées : aucun script du jeu ne les emploie, et la note d'Alex
   transmise par le pair dit que le jeu n'expose aucun nom de carte au Lua.
3. **La commande** `essai_carte_voir` : la carte lue et le dernier chargement vu.
- Rien ne change dans la vie des hommes à ce pas.

### Essai en jeu : grille
1. Le chargement de la sauvegarde 473 : les événements au journal, dans l'ordre, avec leurs arguments ; la carte lue.
2. `essai_carte_voir` en partie.
- Le passage de carte lui-même (Trosky ↔ Kuttenberg) : je ne sais pas le provoquer seul ; **à vérifier par JoVenGer**
  en jouant (dans la liste des vérifications à lui demander, pas compté comme prouvé).

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **D'abord la sonde** : (a) oui (Recommandé : on ne devine pas un signe du jeu) ; (b) la règle de l'horloge tout de
   suite. **Prise : (a).**

### Mesuré en V73 f 3 a (17/10, 7adeaf2)
- **La carte se lit par `sv_map`** : « kutnohorsko » (l'altitude des repères reste en secours, pas servie ici).
- **Un seul événement de chargement** au chargement de la sauvegarde 473 : `OnLoadingComplete`, argument
  « @ui_kutnohorsko » (le nom affiché de la carte) ; `IsLoadingEngineSaveGame` à faux à ce moment ; `OnLoadingStart`
  n'est pas venu.
- **Conséquence pour la suite** : pas besoin de distinguer un passage de carte d'un chargement de partie. Le registre
  (gardé par la sauvegarde) sait sur quelle carte est le camp ; `sv_map` dit où est Henry ; s'ils diffèrent, le camp
  n'est pas reposé et seule l'escorte d'Henry est refaite près de lui ; s'ils sont les mêmes, tout comme avant. Un
  chargement dans l'autre carte donne la même réponse, ce qui est juste. Plus d'horloge, plus de risque comme celui du
  24/09 chez Scriptorium (40 hommes perdus sur un passage pris pour un chargement).
- **À vérifier par JoVenGer** : le passage Trosky ↔ Kuttenberg en jouant.

## V73 f 3 b — la carte du camp, l'escorte refaite près d'Henry (17/10, envoyé au pair ; réponses recommandées prises d'office)

### Le périmètre
- Ce que la sonde a montré (V73 f 3 a) : la carte se lit par `sv_map` ; le registre (gardé par la sauvegarde) suit les
  passages de carte comme les chargements.
- **Ce pas** : le camp appartient à sa carte ; sur une autre carte, il n'est pas reposé, les hommes du camp ne sont pas
  refaits (ils restent « de l'autre côté » au registre), et seule l'escorte d'Henry (les hommes qui le suivent, et le
  Directeur s'il le suit) est refaite près de lui. **Et le grand saut sur une même carte** (voyage rapide) : un cavalier
  loin de son chef est remis près d'Henry.

### Le registre au passage (relecture du pair, deux objections justes ; fait : b80694a, puis les trois conditions)
- **Le défaut** (antérieur à ce pas) : le jeton du registre n'est cru que si la marque de la partie (un objet posé
  dans le monde) existe ; or elle est posée dans une seule carte. Sur l'autre, le registre aurait été ignoré puis écrasé
  par une nouvelle identité : caisse et hommes perdus, comme le 24/09 chez Scriptorium.
- **La parade** : l'identité de la partie est gardée en mémoire Lua (elle survit au passage) ; arrivé sur une carte sans
  marque, le jeton est cru, comme un passage, **seulement si les trois conditions tiennent ensemble** : la carte a changé
  depuis l'entrée précédente (`sv_map`, gardé en mémoire) ; l'identité du jeton est celle en mémoire ; l'horloge du
  monde a avancé, de `socle.passage_jours_max` (10, la règle de Scriptorium) au plus, depuis la dernière écriture du
  registre. Alors la marque est posée ici aussi. Sinon le jeton est ignoré, comme avant (le jeton n'est pas remis à zéro
  quand on charge une sauvegarde qui n'en a pas, V4 : une partie étrangère ou une ancienne sauvegarde d'avant le camp
  n'en hérite pas). Au banc : ancienne sauvegarde sans jeton sur la même carte, ignorée ; sur l'autre carte horloge en
  arrière, ignorée ; onze jours plus tard, ignorée ; le vrai passage, cru et marqué.
- **Limite connue** : une partie étrangère sans jeton, chargée sur l'autre carte moins de 10 jours en avant. Rare.
- **Non vérifié en jeu** : le passage Trosky ↔ Kuttenberg est à faire par JoVenGer.

### Comment ce serait fait
1. **La carte du camp** : à la fondation, `camp` note la carte (`d.carte`, lue par la liaison) ; un camp ancien sans carte
   notée garde le comportement d'avant (il est de la carte où l'on est). `camp.sur_sa_carte()` : vrai si la carte lue est
   la sienne, ou si l'une des deux est illisible (on ne retire jamais rien sur un doute).
2. **Le redressement à l'entrée en partie** : le camp et l'enceinte ne se reposent que sur leur carte. Les hommes :
   sur la carte du camp, comme avant ; ailleurs, seuls les hommes **en escorte d'Henry** (tenue « suivre » dont le chef
   est Henry, ou le Directeur, ou un homme de l'escorte) sont refaits, **près d'Henry** (derrière lui, hors de sa vue,
   à `escorte_derriere_m` (6), sur une place libre et un sol vérifié comme les chevaux) ; les autres restent au registre,
   sans personnage, et reviennent quand Henry revient sur la carte du camp. Le Directeur : de même (refait près d'Henry
   s'il le suit, sinon laissé au registre).
3. **À cheval** : rien de plus : l'escorte refaite à pied retrouve son cheval passager par la règle habituelle (un cheval
   né hors des meubles, la monte) s'il le faut.
4. **Le grand saut sur une même carte** : au battement, un cavalier (homme ou Directeur) à plus de `cheval_saut_m` (150)
   de son chef voit son cheval retiré et lui-même posé à pied près d'Henry (comme le rattrapage, hors de sa vue) ; un
   nouveau cheval naît près de lui ; une ligne au journal. (Un cavalier n'est toujours jamais posé seul avec son cheval
   à côté : c'est le cheval qui est retiré.)
5. **Qui passe** reste la décision de Scriptorium : ce sont les tenues posées par le guichet.

### Règles en données (catalogue)
- `hommes.reglages` : `escorte_derriere_m` 6, `cheval_saut_m` 150.

### Essai en jeu : grille
1. Au banc : un camp fondé sur « kutnohorsko », la carte lue « trosecko » : le camp n'est pas reposé, les hommes du camp
   restent au registre, l'escorte est refaite près d'Henry ; de retour sur « kutnohorsko », tout revient.
2. En jeu : le grand saut d'un cavalier (Henry s'éloigne de plus de 150 m par sauts) : le cheval retiré, l'homme posé près
   d'Henry, un nouveau cheval, la monte.
- **À vérifier par JoVenGer** : un vrai passage Trosky ↔ Kuttenberg avec une escorte.

### Questions (réponses recommandées prises d'office, consigne de JoVenGer du 17/10)
1. **Distinguer un passage d'un chargement** : (a) inutile, la carte du camp et la carte lue suffisent (Recommandé :
   aucune horloge, aucun risque de perte) ; (b) l'horloge à 10 jours. **Prise : (a).**
2. **Une carte illisible** : (a) on garde le comportement d'avant, rien n'est retiré (Recommandé) ; (b) on ne refait
   personne. **Prise : (a).**

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

# Fiche 12 — Le cerveau de nos hommes

- Morceau : à venir (`hommes` pour les ordres, `liaison` pour le moteur). Données du jeu : tables
  `Libs/Tables/ai/*__scriptorium_socle.xml`, arbres `AI/scriptorium/`.
- But (étape 1 de la note de JoVenGer) : que nos hommes vivent, obéissent au Directeur et se battent, comme des
  personnages du jeu, sans rien emprunter au code d'Alex (principes seulement, décision de JoVenGer du 15/10).
- État : **validée par JoVenGer le 15/10/2026** (questions à cocher, après lecture par la conversation Scriptorium) :
  architecture adoptée ; faction « la Compagnie », à nous ; compétences selon le niveau acheté puis le caractère ;
  comportements dans l'ordre de la vie du camp, après le réveil au chargement. Tout ce qui est marqué « acquis » a été vu
  en jeu (`essai_en_jeu.md`, V29 à V55, sans `-devmode`) ; le reste est marqué « non vérifié ».
- **Révision du 16/10/2026, validée par JoVenGer le jour même** (après relecture par la conversation Scriptorium) : un
  seul comportement long, la « vie du camp », au lieu d'un comportement par ordre (section ci-dessous).

## Ce que le joueur voit
- Sur ordre, un homme va au point que le Directeur lui donne et y reste (acquis : « aller au point », V55). Les autres
  ordres (poste, garde, rassemblement, lit, suivre Henry) sont à écrire sur le même modèle (non vérifié).
- Sur ordre, un homme tire son arme et attaque l'ennemi désigné : il blesse et met en fuite un brigand léger du jeu
  (V54), il tue un adversaire qui ne se défend pas (V52). Un brigand du jeu en armure complète l'a toujours emporté
  (V43 à V53).
- **Sans ordre, il ne fait rien** : il reste planté (V50 à V55). Les veillées de la fiche 11 (feu, dés, entraînement,
  lit) devront devenir des comportements à nous, choisis selon ses envies (à faire).
- Plus tard (ouvert) : ils attaquent d'eux-mêmes une bande qu'ils voient, ripostent quand on les frappe, défendent Henry.

## Comment c'est fait (acquis)
- **Naissance** : un personnage de classe `NPC`, avec une copie des propriétés de sa classe plus son âme
  (`guidSharedSoulId`), puis **réveillé** aussitôt (`entite:Activate(1)`, `AI.AutoDisable(id, 0)`) ; sans réveil, son
  cerveau ne tourne pas (V29).
- **Le cerveau** (table `brain`), composé de **deux sous-cerveaux seulement** (V50) :
  - un **switch à nous** (type 6, déclaré dans `subbrain_switching`) : une boucle qui lit la variable d'ordre et pose
    les interruptions ; il ne fait ni marcher ni tirer d'arme lui-même (comme les switchs du jeu) ;
  - les **horaires du jeu** (`npc_basic_scheduler`, type 9) : c'est lui qui **joue** les interruptions.
  - Interdits vus en jeu : un simple arbre (type 1) à côté des horaires, ou le switch du jeu à côté, empêche la partie
    de se charger (V47) ; un sous-cerveau seul de type 9 portant notre arbre n'est pas joué (V49).
  - Les **24 boîtes aux lettres** de `npc_basic` (coups reçus, perception, crimes…), gardées.
- **Les variables du cerveau** (table `brain_variable`) : l'ordre (nombre), la cible (`wuid`), le point (`vec3`), et des
  compteurs. Le Lua les écrit (`XGenAIModule.SetBrainVariable`) ; le switch et les comportements les lisent.
- **Un ordre du Directeur** = la variable d'ordre (et sa cible ou son point) écrite par la liaison, puis le switch pose
  l'interruption correspondante et remet l'ordre à 0.
  - **Attaquer** : la liaison fait tirer l'arme (`human:DrawWeapon`, comme l'outil de combat du jeu) ; le switch appelle
    la fonction d'arbre du jeu `callInterrupt_attack` sur la cible (V50 à V54). Sans arme tirée, l'homme engage sans
    blesser (V51).
  - **Aller quelque part, et les autres ordres** : un **comportement à nous** par ordre (arbre dans
    `AI/scriptorium/comportements.xml`), déclaré en plus sur l'entité des interruptions du jeu
    (`Libs/Tables/ai/smartEntity/SmartEntity__so_interrupt__scriptorium_socle.xml`), posé par le nœud générique
    `AddInterrupt`. Il lit et écrit les variables du cerveau de l'homme (V55).
- **Au chargement** (V56, partie d'essai, « Sauvegarder et quitter » puis rechargement) : nos hommes sont encore dans le
  monde et leur cerveau tourne sans réveil, mais **ses variables reviennent à zéro** (ordre, point, cible, compteurs). À
  chaque entrée en partie, le socle redonne donc à chacun son ordre en cours et fait revenir les manquants
  (`hommes.relancer`, `directeur.relancer`) ; un homme est éveillé à sa venue (`liaison.faire_venir_homme`). Un réveil de
  plus ne gêne pas.
  Vu en jeu (V57) : à l'instant de l'entrée en partie, les hommes de la sauvegarde sont déjà là (aucun doublon), et
  leurs ordres sont redonnés une fois.
- **S'asseoir, se coucher** (V60 à V62) : sièges et lits du monde sont des entités `StanceSmartObject` (sortes « Chair »
  pour s'asseoir ; « GroundBed », « NormalBed », « Bench » pour dormir ; gabarits du jeu `so_sitPlace` et `so_bed`).
  L'homme reçoit le WUID de l'objet, et notre comportement joue le comportement « use » de l'objet lui-même
  (`CallBehavior`, comme le jeu) : il y va, s'assoit ou se couche. Une copie posée par script (mêmes propriétés) marche
  aussi, mais sans meuble visible.
- **Compétences de combat** : posables par `soul:AdvanceToSkillLevel` (relu, V53 ; l'appel ne fait que monter, comme
  l'aguerrissement de la fiche 11). À 0, un homme frappe déjà (V52).

## Révision du 16/10/2026 : un seul comportement long, la « vie du camp » (validée)
### Pourquoi (fiche 15, V73 a à V73 c 4)
- Un comportement par ordre, posé en interruption, est tué de l'extérieur quand l'ordre suivant le remplace
  (`IgnorePriorityOnPreviousInterrupt="true"`) : l'homme assis ne se lève pas (V73 c 1 à 3).
- Sans remplacement (« false »), la garde finit l'assise du dedans : l'homme se lève et marche (V73 c 4). Mais **dès
  que notre interruption finit**, le jeu reprend la main et le rassoit sur son siège, sans nous.
- Principe transmis par la conversation Scriptorium (mécanisme seulement) : une seule interruption longue, qui ne finit
  jamais, et qui change d'activité du dedans.

### Ce que Scriptorium attend (carte des règles et note des métiers relues le 16/10, lecture seule)
- Jouer le geste d'un poste par le « use » de l'objet du jeu (s'asseoir, se coucher, travailler), en sortir proprement,
  et changer de geste quand la tâche change : « le geste vient du jeu, l'ordre vient de nous » (note des métiers, § 1).
- Tenir un geste jusqu'à l'ordre de fin ou une durée en temps du jeu, puis reprendre après une interruption ; ne jamais
  décider seul quand commencer ou finir, ni laisser un poste tourner seul.
- Céder aussitôt à la bataille ou à l'alerte, au rassemblement, à Henry qui veut le poste, au démontage, à la nuit : se
  lever d'abord, puis partir. Une règle ne reprend pas un homme qu'une règle plus forte tient (l'arbitre, V73 b).
- Ne jamais rester figé ; dormir sans se relever la nuit, sauf attaque ou alerte ; se retrouver intact au rechargement.
- Rien n'est dit de ce que devient l'activité quand Henry parle à un homme.

### Ce que le joueur verra
- Un homme reste sous nos ordres du début à la fin : il marche, s'assoit, se lève, se couche à l'ordre.
- Entre deux ordres, il reste debout là où il est ; le jeu ne le rassoit plus de lui-même.
- Après une conversation ou une réaction du jeu, la vie du camp reprend d'elle-même.

### Comment ce serait fait (non vérifié)
- **Le switch** (boucle de 2 s) lance le comportement long par `AddInterrupt`, priorité 100, sans remplacement
  (« false ») : il n'écrase pas une interruption plus forte du jeu, il attend derrière elle (mis en file, vu en
  V73 c 4). Il tient un état à lui, local à son arbre, donc remis à zéro à chaque chargement (V56) : 0 = à lancer ;
  1 = lancé, pas encore commencé ; 2 = en marche.
- **Le pouls** : le comportement long augmente une variable du cerveau (`scriptorium_vie_pouls`) à chaque tour de sa
  garde (toutes les 0,5 s). Le switch le voit avancer (état 2). S'il reste figé plus longtemps que le délai du
  catalogue alors qu'il avançait, le switch relance le comportement, une seule fois par arrêt. C'est une amélioration
  sur le principe transmis, qui ne relance qu'au changement d'état : rien n'est perdu si le jeu tue notre comportement.
  C'est aussi le début du gardien des hommes (idée validée n° 1).
  - **Pas de relance en plein combat ni en pleine conversation** (relecture du pair) : pendant ce temps, le pouls est
    figé normalement. Le switch ne relance que si l'homme n'est ni en combat (contexte `crime_interruptAttack`, déjà
    relu au poste en V72) ni en conversation (le signe est à trouver dans les arbres du jeu). Sinon, il attend la fin,
    puis relance une fois.
- **Le comportement long** (`scriptorium_vie_du_camp`, déclaré comme les autres dans
  `SmartEntity__so_interrupt__scriptorium_socle.xml`) : une boucle sans fin. À chaque tour, il retient le compteur
  d'ordres, lit l'activité, puis la joue. Chaque activité a la même forme, **faire, puis tenir** :
  - l'action (marcher, s'asseoir, se coucher) est finie du dedans par la garde dès que le compteur change ;
  - si elle finit d'elle-même (arrivée, échec, délai), l'homme reste là où il est jusqu'au prochain ordre ;
  - sans activité, il reste debout ; la garde tourne toujours, donc le pouls aussi.
- **Les activités d'abord** : 0 attendre sur place, 9 marcher vers un point, 10 s'asseoir sur un siège, 11 se coucher
  dans un lit (les numéros des ordres d'aujourd'hui), dans une **variable à part**, `scriptorium_activite`, que le
  switch ne touche pas (il remet `scriptorium_essai_ordre` à 0 après l'attaque : partagée, l'attaque effacerait
  l'activité). Plus tard, dans la même boucle : la garde (V73 d), le rassemblement (V73 e), les postes et métiers.
  Suivre Henry (V73 f) et le combat restent d'autres états.
- **Le Lua** : `liaison.ordonner` écrit l'activité, le point ou la place, puis augmente le compteur. Il ne pose plus
  d'interruption par ordre. Tout y passe : le battement des hommes, le secours, le Directeur, les commandes du poste.
  Les comportements d'un ordre (`scriptorium_aller`, `scriptorium_s_asseoir`, `scriptorium_se_coucher`) sont retirés
  dans le même pas : rien n'est laissé en essai.
- **L'attaque : à mesurer, pas acquise.** `callInterrupt_attack` (160, priorité ignorée) tue le comportement long du
  dehors, comme le « true » des ordres de V73 c 1 à 3. Soit l'attaque du jeu défait la posture d'elle-même (un
  personnage assis attaqué se lève), soit l'homme reste assis. À voir en V73 b : l'ordre 8 sur un homme assis. Si la
  posture reste, le Lua dégage l'homme d'abord (activité 0, compteur augmenté, 3 s au plus), la garde finit la posture
  du dedans, puis l'attaque part ; c'est le même principe que le signal « céder la place » transmis par le pair. Après
  le combat, le pouls fait relancer la vie du camp.
- **Au chargement** : l'état du switch revient à 0 et le comportement long est relancé au premier tour. L'homme attend
  debout, puis le réveil différé (30 s) redonne l'activité en cours (`hommes.relancer`).
- **Les valeurs** (attente de la garde, délai de la marche, distance d'arrêt, délai du pouls figé) passent par des
  variables du cerveau, écrites par le Lua depuis le catalogue (`reglages.lua`). Structure réelle du jeu :
  `Wait duration="$duration"` (76 fois, variable texte `_string`, par ex. `AI/animal/basic/switch/animal_alertMode.xml`) ;
  `Move stopWithinDistance="$boostedStopDistance"` (17 fois, nombre `_float`, `AI/crime/continuouslyfollowplayer.xml`).
  À vérifier : qu'une variable du cerveau y soit prise comme une variable locale.

### La posture (question 1)
- (a) **Le « use » du jeu**, sous nos contextes (`activity_disableSchedulerLooping`, `bench_disableSnooze`) et notre
  garde. Vu en jeu : l'homme s'assoit, puis se lève à l'ordre (V73 c 4). C'est aussi la méthode attendue pour les postes
  et les métiers (note des métiers, § 1). Reste le lien que le « use » laisse peut-être entre l'homme et le siège.
- (b) **Notre propre posture** : `StanceElement` sur le siège (« sitting » ou « lying »), puis la pose sur le siège
  (`UnstanceAction` avec `locationObject` = le siège), puis la tenue sous notre garde. Aucun lien avec le siège.
  - Structure réelle du jeu : `AI/special/party/party_duo_sitting_minion.xml`, `AI/temp/so_test_waitspot.xml`.
  - À écrire en plus : l'arrivée serrée à la place, et le demi-tour vers le feu (la pose garde le cap qu'on a).
  - Notre `StanceElement` de V60 et V61 n'asseyait pas : il lui manquait la pose sur le siège.
- Pourquoi (a) d'abord : un seul changement (l'interruption longue), et son échec se lit au pouls. (b) changerait deux
  choses à la fois : en cas d'échec, on ne saurait pas si c'est la boucle ou la posture. (b) est la suite prévue si
  l'essai des 2 min le demande (règle de décision ci-dessous).

### Essais
- **Au banc** : l'activité, la place et le compteur écrits par `ordonner` (faux jeu). `tout_verifier.py` vérifie que
  chaque activité donnée par le Lua a sa branche dans le comportement long.
- **En jeu, V73 c 5** (`playline3`, sans `-devmode`) :
  1. le pouls avance pour chaque homme et pour le Directeur ;
  2. assis, puis levés à 30 s, 90 s et 3 min : chacun se lève et marche ;
  3. **le critère du modèle** : debout 2 min après la levée, **sans être rassis** ;
  4. **le critère du chemin**, à part : il arrive à l'exercice (Ondřej s'était arrêté à 2,1 m de son siège en
     V73 c 4 : les rondins autour du feu sont un obstacle possible, un échec du chemin n'est pas un échec du modèle) ;
  5. sauvegarder et quitter, recharger : le pouls revient, l'activité est redonnée après 30 s ;
  6. Henry parle à un homme du camp (voir « ce qui reste ouvert ») ;
  7. l'écran noir, au décompte.
- **Règle de décision, écrite avant l'essai** :
  - rassis pendant que le pouls avance : le siège l'a repris sous notre comportement ; on passe à (b) ;
  - rassis après un pouls figé : quelque chose a tué le comportement ; lire le journal avant toute suite ;
  - jamais rassis : le modèle tient avec (a) ; on garde (a), et (b) reste en réserve.
- Recherche d'un exemple existant (règle du 15/10) : deux recherches (web, dépôts de code), rien de pertinent. Les
  structures viennent des arbres du jeu (`Data/Scripts.pak`, lecture seule, rien d'extrait).

### Ce qui reste ouvert
- **Ce que la priorité 100 sans remplacement retient du jeu** : avant, les interruptions du jeu plus faibles (le relevé
  en montre à 1, 15, 35, 42) passaient entre deux ordres courts ; désormais, elles attendent derrière un comportement
  qui ne finit pas. Pour les hommes du camp, cela peut être voulu ; pour un homme qui cède sa place à Henry, ou pour le
  dialogue du Directeur (étape 3), non. À mesurer en V73 c 5 : Henry peut-il encore parler à un homme, et quelles
  réactions du jeu disparaissent.
- Indice transmis par le pair : Alex lance sa vie du camp à 160, avec remplacement et l'urgence « Fast », et son
  combat aussi à 160 ; son dialogue forcé vers Henry passe à 170. Le dialogue ordinaire (Henry qui parle au Directeur
  ou à un homme) marche pourtant chaque jour dans la partie de JoVenGer : il passe sans doute par la boîte aux lettres
  de dialogue du cerveau (`npc_basic`), pas par une interruption. C'est rassurant pour notre 100 ; V73 c 5 tranchera.

### Questions à JoVenGer (révision du 16/10, relue par le pair)
1. **La posture** : (a) le « use » du jeu d'abord, notre propre posture si l'essai des 2 min le demande (Recommandé) ;
   (b) notre propre posture tout de suite.
2. **Le retour de la vie du camp** quand le jeu la tue : (a) relance par le pouls, hors combat et hors conversation
   (Recommandé) ; (b) au prochain ordre seulement.
3. **La priorité de la vie du camp** : (a) 100 sans remplacement, mesurée en V73 c 5 (Recommandé) ; (b) 160 avec
   remplacement, comme Alex.
- **Réponses de JoVenGer (16/10)** : 1 (a) le geste du jeu d'abord ; 2 (a) la relance automatique par le pouls ;
  3 (a) la priorité 100, à mesurer.

### Mise en œuvre (d'après des structures réelles du jeu, `Data/Scripts.pak`, lecture seule)
- **En combat, en conversation** : le switch lit deux contextes de l'homme par `EntityContextCheck` (forme du jeu :
  `AI/animal/basic/switch/animal_affectFeelings.xml`, une branche `Then` qui pose une variable locale `_bool`) :
  `crime_interruptAttack` (posé par `AI/npc/basic/switch/interrupt_attack.xml`) et `speech_switchDialogRunning` (posé
  par `AI/speech/switchDialog.xml`). Conditions écrites comme celles du jeu : « et » `&amp;`, « non » `~$`, `&gt;=`.
- **Le switch** : à lancer (0) → `AddInterrupt` ; lancé (1) → en marche (2) dès que le pouls avance ; en marche et
  pouls figé 3 tours de suite (6 s), hors combat et hors conversation → à lancer ; lancé depuis 30 tours (60 s) sans
  pouls, hors combat et hors conversation → à lancer (une file perdue ne laisse pas l'homme sans vie du camp). Le
  compteur `scriptorium_essai_rejoint` compte les lancements.
- **Le comportement long** : chaque branche d'activité vérifie aussi que le compteur n'a pas changé depuis le début du
  tour, pour ne jamais commencer une activité déjà remplacée.
- **Le Lua** : une fonction de la liaison pose l'activité puis augmente le compteur ; la pose d'un ordre (l'attaque,
  les essais du marcheur) ne touche plus au compteur.
- **Les valeurs de l'arbre** (garde 0,5 s, tour du switch 2 s, marche 30 s, arrêt à 2 ± 0,5 m, 3 et 30 tours) restent
  d'abord écrites dans l'arbre, comme celles des comportements d'un ordre vus en jeu : un seul changement à la fois.
  Leur passage par des variables du cerveau, écrites par le Lua depuis le catalogue, est le pas suivant, éprouvé à part
  (une attente qui ne prendrait pas sa variable ferait tourner la garde sans attendre).

### Mesuré en V73 c 5 (16/10)
- **Le comportement long tient** : un lancement par homme et pour le Directeur, jamais relancé pendant l'essai ; après
  « sauvegarder et quitter » et reprise, relancé dès l'entrée en partie, puis l'activité redonnée par le réveil différé.
- **L'attente de la garde ne prenait pas** : « 0.5s » n'est pas une forme du jeu ; ses arbres écrivent `'500ms'`
  (55 fois), jamais de secondes à virgule. Le pouls avançait d'environ 4 000 par seconde. Correction : `'500ms'`.
- **Le siège reprend l'homme sous notre comportement** : levé, l'homme marche jusqu'à l'exercice, puis il est replacé
  d'un coup, assis, sur son siège (de 1,5 à 3 s après l'arrivée, sans marcher), pendant que le pouls avance. C'est le
  premier cas de la règle de décision : **on passe à notre propre posture (b)**, sans le « use » du jeu. Le même lien
  semble survivre à la sauvegarde (Jan, assis avant, repris après la reprise).
- Un homme dont le but est à moins de 2,5 m de son siège ne se lève pas : sa marche réussit sans un pas. Notre propre
  posture devra se défaire d'elle-même quand l'activité change, avant toute marche.

### Notre propre posture (b), d'après le « use » du jeu et le principe transmis (16/10)
- **Ce que fait le « use » du siège** (`AI/world/so_sitPlace.xml`, lecture seule) : `StanceElement` sur l'objet,
  posture « sitting », avec dedans une attente que la mise en posture soit jouée (`WaitAction`) ; puis, après 15 s sans
  le contexte `activity_disableSchedulerLooping`, un `InstantSynchronize` « keepInBehavior » : c'est sans doute lui qui
  replace l'homme d'un coup sur le siège. Hébergé par l'objet, le « use » fait aussi l'approche ; hébergé par notre
  interruption, il faut la faire nous-mêmes.
- **Principe transmis par la conversation Scriptorium (mécanisme seulement)** : l'objet de la posture est l'objet
  invisible `StanceSmartObject` posé sur le meuble (celui que le camp pose depuis V66) ; pour s'asseoir ou se coucher,
  aucun geste nommé : une marche serrée, un demi-tour pour un siège, la posture avec son attente, puis la tenue. La
  tenue finie, la posture se défait et le jeu joue lui-même la sortie. En V60 et V61, il manquait sans doute l'attente
  intérieure et l'arrêt serré (0,57 m).
- **Notre branche « s'asseoir »** (activité 10) :
  1. l'approche, interrompue par la garde si un nouvel ordre arrive : marche jusqu'à l'objet du siège, arrêt à 0,1 m
     (± 0,05), `changeNPCState="true"` (forme du jeu : 809 marches sur 854 qui le disent), délai de 30 s ; puis
     `<Turn target="$scriptorium_essai_siege" align="true" />` : l'homme prend le cap de l'objet, posé tourné vers le
     feu par le plan du camp (forme du jeu pour s'aligner sur un objet : `AI/quests/kutnohorskyTurnaj/kutnohorskyturnaj.xml`) ;
  2. si aucun nouvel ordre n'est arrivé : `StanceElement` sur l'objet, « sitting », avec dedans, en parallèle, la mise
     en posture (`WaitAction`, puis l'attente sans fin) et la garde : le pouls bat aussi pendant la mise en posture, et
     la garde finit la tenue (relecture du conseiller : sans elle, un pouls figé ferait relancer une copie) ;
     l'approche est tentée même si la marche n'arrive pas à 0,1 m (le principe transmis dit que la posture marche le
     petit reste) ; un compteur à part, `scriptorium_essai_approche`, dit les approches réussies ;
  3. la garde finie, la posture se défait ; 2 s d'attente laissent au jeu le temps de jouer la sortie avant l'activité
     suivante.
- **Notre branche « se coucher »** (activité 11) : la même, posture « lying », arrêt à 0,5 m, sans demi-tour (à vérifier
  à l'image : si l'homme se couche en travers, on ajoutera l'alignement sur l'objet).
- Les contextes du « use » (`activity_disableSchedulerLooping`, `bench_disableSnooze`) ne servent plus : retirés.
- **La garde attend `'500ms'`**, la forme du jeu.
- **Essai V73 c 6** (`playline3`, sans `-devmode`), critères écrits avant. Deux changements arrivent ensemble (l'attente
  `'500ms'` et la posture) : le critère 1 se lit au premier relevé et conditionne les autres.
  1. le pouls avance d'environ 2 par seconde (sinon, tout le reste est suspendu) ;
  2. chacun marche jusqu'à son siège et s'assoit **face au feu** ;
  3. levés à 30 s, 90 s et 3 min : chacun se lève (Jan compris, dont le but est tout près) et **reste debout 2 min sans
     être replacé** ;
  4. coucher puis lever : couché dans le bon sens, puis levé ;
  5. sauvegarder assis, recharger : l'homme n'est pas replacé sur son siège par le jeu ; le pouls revient ;
  6. l'écran noir, au décompte.
- **Règle de décision** : s'il ne s'assoit pas (debout devant le siège, comme en V60 et V61) : avec « approches 0 »,
  c'est la marche qui n'arrive pas, on essaie l'arrêt à 0,2 m (forme du jeu, 639 marches sur 809) ; avec « approches 1 »,
  c'est la posture qui ne prend pas : arrêt et rapport (une seule tentative de cette voie avant de revenir à JoVenGer) ; s'il s'assoit mais dos au feu, alignement sur le feu ;
  s'il est encore replacé, arrêt et rapport.

## Ce qu'il faut décider (questions à JoVenGer)
1. **L'architecture** ci-dessus (switch à nous + horaires du jeu ; un ordre = un comportement à nous joué en
   interruption ; l'attaque par la fonction du jeu).
2. **La faction de nos hommes** : elle décide qui ils attaquent et qui les attaque, et si le jeu les traite en gardes
   (un garde arrête Henry pour un vol).
   - a. **une faction à nous** (« la Compagnie »), ajoutée à l'arbre des factions du jeu (`Libs/Tables/rpg/FactionTree__scriptorium_socle.xml` :
     le jeu en charge déjà en plus, par ex. `FactionTree__tests.xml` ; amie d'Henry, hostile aux brigands et aux
     Coumans, sans autorité) — faisable sur le papier, **non vérifié** en jeu ;
   - b. une faction de soldats du jeu, amie d'Henry — risque d'agir en gardes.
   - Ce qui pèse : la faction change le comportement des deux côtés, pas seulement « qui attaque qui » : un brigand a
     fui devant notre homme à âme de garde de Trosky (V54), et un garde du jeu s'est porté de lui-même sur un brigand
     (V49). Vérifier (a) coûte une séance : un `FactionTree__scriptorium_socle.xml` avec deux relations hostiles
     (brigands, Coumans), sur la structure réelle de `FactionTree__tests.xml`.
   - Côté programme Scriptorium (remarque de sa conversation) : un de nos hommes n'arrête ni n'attaque jamais Henry de
     lui-même (la justice du camp est celle du Directeur) ; mais les duels et pugilats avec Henry sont voulus : la
     faction doit pouvoir être rendue hostile le temps d'un ordre (`RelationOverride` de l'attaque), puis amie.
3. **Les compétences de combat** (règle nouvelle, réglable) :
   - a. selon le **niveau acheté** puis le **caractère** : le programme Scriptorium embauche par niveau (recrue,
     confirmé, vétéran, avec prix et paie selon le niveau) ; une fourchette par niveau (par exemple recrue 5–10,
     confirmé 10–15, vétéran 15–20, réglables), la place dans la fourchette selon l'aguerrissement et les dons de la
     fiche 11 ; montées quand il s'aguerrit ou s'entraîne (jamais baissées). Même cohérence à reprendre pour
     l'aguerrissement de départ de la fiche 11 (aujourd'hui en cloche autour de 25, sans lien avec le niveau) ;
   - b. un niveau fixe pour tous, réglable ;
   - c. laissées à 0 pour l'instant.
4. **Les premiers comportements à écrire**, une chose à la fois, dans l'ordre de la vie du camp : (1) monter la garde
   (aller au poste et y rester, arme prête) ; (2) rejoindre le rassemblement (l'alerte) ; (3) aller au poste ou au
   travail ; (4) suivre Henry ; (5) dormir, quand le lit sera reconnu ; puis les veillées de la fiche 11. Le socle
   fournit le geste ; qui va où reste une règle du programme Scriptorium.

## Règles (toutes en données, catalogue de `reglages.lua`, règle de JoVenGer du 14/10)
- Priorité des interruptions de nos ordres, distance d'arrêt au point, durée d'attente avant d'abandonner un trajet,
  niveaux de compétences (si 3 a ou b), délai entre deux tours du switch.

## Ce qui reste ouvert (non vérifié), par ordre d'urgence
- **Réveil** : acquis pour « Sauvegarder et quitter » puis rechargement, homme près d'Henry (V56, V57). Non vérifié : le
  rechargement en cours de partie (menu de pause), un homme loin d'Henry au chargement, et le sommeil au-delà d'environ
  300 m d'Henry.
- **La partie d'essai `playline2` est au prologue, temps du jeu arrêté** : l'ordre « aller » y est posé mais pas joué
  (V56) ; sur la partie d'essai n° 3 (`playline3`, copie de la sauvegarde 473, temps qui avance), il est joué, avant
  comme après rechargement (V58). L'hypothèse (les horaires du jeu ne jouent pas d'interruption quand le temps est
  arrêté) en sort renforcée, sans être isolée. Les essais de comportements et de rechargement se font sur `playline3`.
- La table `SmartEntity__so_interrupt__scriptorium_socle.xml` n'est pas annoncée au journal du jeu ; elle est prise
  puisque le comportement est joué (V55).
- **L'attaque à vue** (une bande qui attaque d'elle-même en voyant le camp) et la riposte : le brigand du jeu n'attaque
  pas Henry de lui-même à 8 m, même en prairie (V41, V43) ; pistes : perception (`IgnorePerception`), volumes perçus et
  sons des crimes du jeu.
- **Rappeler un homme engagé** : rendre au Directeur un homme en combat. Piste à essayer d'abord (une séance, un seul
  changement) : les priorités. Nos ordres sont posés à 100, l'attaque du jeu à 160 : un ordre à 100 ne reprend pas un
  homme pris par une interruption à 160, sauf `IgnorePriorityOnPreviousInterrupt="true"`. Sinon : garde des
  comportements par la variable d'ordre (`IfGate … RunLogic="Halt"`, comme `interrupt_attack.xml` du jeu).
- **S'asseoir, dormir au camp** : acquis sur les objets du jeu (V62) et sur les meubles du camp (V66, V68, V69 ; fiche 03). Reste à poser, pour chaque siège et chaque
  paillasse du camp, un `StanceSmartObject` de la bonne sorte à l'endroit du modèle visible, à la même hauteur, puis à
  faire passer les ordres « repas », « veillée » et « sommeil » des hommes par ces objets.
- **Âmes du mod** : fiche 13, validée ; acquis en jeu (V70) : les hommes du camp et le Directeur naissent sur nos âmes et
  reçoivent nos ordres (assis sur les bancs, couchés dans leurs paillasses). Reste l'équipement par le Lua (fiche 13).
- La version publiée n'aura ni poste ni ordres d'essai (`scriptorium_essai_*`).

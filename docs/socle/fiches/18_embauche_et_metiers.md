# Fiche 18 — L'embauche et les métiers (étape 5 du nécessaire)

Sources : la note de JoVenGer (`Scriptorium/docs/socle/NOTE_POUR_LE_SOCLE.md`, partie 7) et `NOTE_METIERS.md` (lecture
seule), la liste du pair du 17/10 (ce que Scriptorium attend), le tableau du guichet (`docs/socle/guichet.md`, entrées
« étape 5 »). Les règles (prix, pécule de 200, réembauche, le Directeur qui engage, salaires, stocks, horaires) sont celles
de Scriptorium : le socle n'offre que la mécanique, et des accroches.

Découpage, une tranche à la fois :
1. **5 a, l'embauche** (ci-dessous) ;
2. 5 b, rendre un homme parlable (le dialogue de Scriptorium s'y greffe) ;
3. 5 c, les métiers : le forgeron connu par son personnage, les postes de travail du jeu (le geste vient du jeu, l'ordre
   vient de nous ; ce qui marche est refait pareil, sans nouveau poste) ;
4. 5 d, les sorties à cheval des gens de métier (la colonne de l'étape 4).

## 5 a — L'embauche

Réponses prises d'office (consigne du 17/10) :
- **Faire venir plusieurs hommes** : `hommes.faire_venir_des_hommes({ nombre, role, palier, famille, semaines, prime })`
  embauche un à un et s'arrête au premier refus (rendu avec les engagés).
- **Un compagnon nommé** : `contrat.nom` (son nom, sinon un nom d'époque) et `contrat.ame` (l'âme donnée par
  Scriptorium, un identifiant du jeu ; sinon une âme à nous).
- **Un homme posé à un point** : `contrat.position` ; il naît là (sinon au feu du camp).
- **Le plafond de la compagnie** : réglage `hommes.plafond` (80, le chiffre de JoVenGer du 28/09) ; refus
  « plafond_atteint » ; `hommes.plafond_de_la_compagnie()` rend le plafond, l'effectif et les lits libres.
- **Les chevaux de la compagnie** : interrupteur `chevaux_de_la_compagnie` (allumé) ; éteint, aucune sortie ne fait naître
  de cheval : chacun sort à pied.
- **Accroches** : `hommes.avant_l_embauche(contrat)` (rend vrai, ou faux et la raison : Scriptorium refuse ou modifie le
  contrat) et `hommes.apres_l_embauche(id, contrat)`.

Relecture du pair (17/10, l'argent pour la prise) :
- **Une prime de 0 : rien à payer.** Scriptorium paie lui-même l'embauche à sa caisse, puis engage avec une prime de 0 :
  alors aucun appel au coffre (ni lecture ni paiement) ni à la bourse d'Henry, et pas de refus « coffre insuffisant ».
  Prime et solde boiteuses (négatives, fractionnaires, NaN, infinies, pas des nombres) : refus `prime_invalide`,
  `solde_invalide`. Au banc, avec trois erreurs injectées (garde de la prime ôtée, `payer(0)`, sommes non vérifiées) :
  toutes attrapées.
- **Un lit par homme** : interrupteur `un_lit_par_homme` (allumé). Éteint, l'homme est engagé sans lit s'il n'en reste
  pas (chez Scriptorium, on dort en relève ; les tentes sont à JoVenGer) ; une ligne au journal.
- **Les semaines** (réponse prise d'office) : les contrats à durée éteints (`contrats_a_duree`), `semaines` est
  facultatif et vaut le plus long contrat (`hommes.reglages.semaines_max`) ; donné, il reste vérifié.

## 5 b — Rendre un homme parlable

Recherche (règle du 15/10) : deux recherches (GitHub, Nexus) sans exemple pour KCD2. Source réelle : les scripts du jeu
(`Scripts.pak`, lecture seule) : `Scripts/Entities/AI/Shared/BasicAIActions.lua` (`GetActions` construit les actions
d'un personnage ; « Parler » y est ajouté par `AddInteractorAction` avec `Action():hint("@ui_hud_talk"):action("talk")
:interaction(inr_talk)` seulement si `actor:CanTalk` — un dialogue existe pour son âme — et hors combat) et
`Scripts/Utils/InteractorAction.lua` (`Action`, `AddInteractorAction`).

Comportement :
- `hommes.rendre_parlable(id, oui)` : la fiche garde `parlable` ; l'entité de l'homme reçoit « Parler » tant qu'il est
  vivant, conscient et hors combat, s'il n'a pas déjà « Parler » (un dialogue du jeu ou de Scriptorium). Reposé à chaque
  battement (une entité refaite au chargement perd l'enveloppe) ; rien n'est écrit dans les fichiers ni dans la classe du
  jeu : seulement l'instance de l'entité.
- Henry appuie sur « Parler » : l'accroche `hommes.quand_on_lui_parle(id)` (appelée par la table sous `pcall` ; le
  dialogue de Scriptorium la remplace). Par défaut, une ligne au journal et une annonce (« … vous écoute »).
- Une enveloppe en erreur rend les actions d'origine (jamais d'actions cassées) ; une ligne au journal, une fois.
- Réponses prises d'office : parlable pour l'homme qu'on désigne (pas tous d'office) ; le Directeur plus tard (sa
  Gestion du camp est à Scriptorium).
- Contrôle d'absence : `GetActions` (le nom que le moteur appelle sur l'entité) est aussi chez Alex. Décision de JoVenGer
  du 17/10 (par le pair) : une liste fermée de « noms du jeu admis » dans `tout_verifier.py`, un nom n'y entrant que
  s'il est défini comme fonction dans `Data/Scripts.pak` du jeu de base (vérifié à chaque passage ; refusé sans le jeu),
  au plus un (`GetActions`), affiché au rapport. Un nom de plus se demande à JoVenGer.
- Au banc : posé, reposé au battement, l'accroche reçoit l'homme, ôté, inconnu refusé. Non vérifié en jeu.

## 5 c — Les métiers

### Tranche 1 : les gens de métier à part, et admettre un personnage déjà né

Réponses prises d'office :
- **Exemptions en données** : `hommes.exemptions_des_metiers = { garde = 1, garde_de_nuit = 1, ronde = 1,
  patrouille = 1 }` (section de réglages `exemptions_des_metiers`) ; tout rôle de réserve « metier » (barbier,
  cuisinier, armurier, forgeron) en est exempté. Avant, les gens de métier prenaient la garde. Les missions restent
  permises (les sorties de 5 d).
- **Le rôle `forgeron`** (solde 16, métier).
- **Admettre un personnage déjà né** : `hommes.admettre(personnage, contrat)` (le contrat de l'embauche, sans âme ni
  point) ; `hommes.homme_du_personnage(personnage)`. Un admis n'est jamais refait (absent, il attend au registre),
  jamais renvoyé (retiré, son personnage reste dans le monde : il est à Scriptorium), jamais équipé, jamais mis dehors
  (refus `personnage_admis`). Pour les gens que Scriptorium fait naître lui-même (le forgeron, le service) ; les hommes
  de la partie de JoVenGer, eux, seront refaits sur nos âmes à la bascule (le pair, 17/10).
- Au banc ; non vérifié en jeu.

### 5 a bis : un homme refait avec son équipement donné (la reprise de la partie de JoVenGer, le pair, 17/10)

- Contrat `objets` : une liste de `{ objet, etat }` (ou d'identifiants du jeu, état neuf) ; pas de préréglage ; les
  objets sont recréés à la naissance avec leur état par la voie des pièces données (V71 c), puis portés ; refaits de même
  si le personnage est refait. Avec `nom`, `role`, `palier` et `position` : l'homme repris. Le point est choisi par qui
  appelle (hors de la vue d'Henry : à lui d'y veiller, comme pour `faire_rentrer`). Objets boiteux : refus.
- Au banc ; non vérifié en jeu.
- Relecture (17/10), réponses prises d'office : un admis combattant n'est jamais équipé (les deux boucles de
  l'équipement l'ignorent) ; sans prime donnée, un admis ne coûte rien (Scriptorium paie les siens) ; mort, il ne rend
  aucun corps (son entité est à Scriptorium : personne ne la retire).

**Vu en jeu le 17/10** (séance groupée, `essai_en_jeu.md`) : 5 a (trois d'un coup, un posé au point, le compagnon nommé), 5 a bis (9 objets portés à l'état 0,5), 5 b (« Parler [E] » puis « Il vous écoute : … » ; le moteur appelle bien l'enveloppe de l'instance), 5 c tranche 1 (l'admis mené par nos ordres ; les gens de métier hors de la garde). Non vus : pas de « Parler » en combat ; l'admis après un rechargement.

### Tranche 2 : les postes de travail du jeu

Sources réelles (lecture seule) : `Tables.pak`, `Libs/Tables/ai/smartEntity/SmartEntity__<nom>.xml` (le gabarit : son
`DatabaseId`, ses comportements nommés) ; `Scripts.pak`, `AI/profession/…` (l'arbre de chaque comportement),
`Scripts/Entities/WH/Others/SmartObjectHolder.lua` (un objet intelligent sans géométrie, qui porte
`guidSmartObjectType`), `AI/crime/mournOnBench.xml` (un personnage lance le comportement d'un objet :
`<CallBehavior Target=… BehaviorName=…>`). Deux recherches (GitHub, Nexus) sans exemple pour KCD2 (5 b).

Comportement :
- **Le catalogue des genres** `camp.genres_de_postes` (section de réglages `postes_du_jeu`) : pour chaque genre, le
  gabarit du jeu, le geste (le comportement nommé) et les points d'appui. D'abord la prière (`so_praying`,
  `useKneelingGround`), le désherbage, la clôture et la pelle (`so_weeding`, `so_fence`, `so_shoveling`, `use`) : sans objet lié. La forge (sac de forge, emplacements du
  marteau et de l'épée, liés au poste) viendra après, prouvée à part.
- **Rendre un poste fonctionnel** : `camp.rendre_fonctionnel(nom, genre, position, cap)` (décision remplaçable, A34) :
  un `SmartObjectHolder` du gabarit, posé au sol là où Scriptorium (ou JoVenGer par le plan) le veut ; gardé au
  registre, reposé à l'entrée en partie s'il manque, retiré quand le camp est levé ; `camp.retirer_le_poste(nom)`,
  `camp.postes()`.
- **Le geste vient du jeu, l'ordre vient de nous** : `hommes.tenir(id, regle, { activite = "poste", poste = nom, fin })`
  : l'homme marche au poste (ordre 21), puis l'arbre lance le comportement du poste (`CallBehavior`), le relance quand
  il finit, et l'interrompt au changement d'ordre (la fin de la tenue, une bataille, la nuit : l'arbitre).
- **Le relevé** (outil d'essai) : les objets intelligents du monde d'un gabarit du catalogue, autour d'Henry : classe,
  nom, gabarit, points d'appui, modèle, distance (comme V65 pour les sièges).
- Non vérifié en jeu tant que le relevé et la première prière ne sont pas vus.
- **Vu en jeu le 17/10** : le relevé (359 postes à moins de 400 m d'Henry, tous des `SmartObjectHolder` ; points d'appui lus : prière « Praying », désherbage « Weeding », clôture « GenU_repairFenceHammer », pelle « coalThrowing » ; aucun balai alentour : retiré du catalogue, les points d'appui mis d'après le relevé). Puis la prière : le poste posé à 3 m devant Henry, l'homme y marche, s'agenouille (le geste du jeu, lancé une fois et tenu) ; lâché, il se relève aussitôt et repart à l'exercice. Non vus : le désherbage, la clôture, la pelle ; un geste qui finit et qu'on relance ; le poste reposé après un chargement.

- **Vu en jeu le 17/10, les lots** (tous les genres du catalogue, quatre à la fois, un homme à chacun) : chaque poste posé, chaque geste lancé une fois et tenu (aucune relance en 55 s : le comportement du jeu tourne). Visibles : la prière (agenouillé, et la prière du jeu dite en sous-titre « Priez pour nous, sainte Mère de Dieu… »), la clôture (bras au marteau), le banc du camp et l'établi de l'armurier (postures qui changent). Pas distinguables à cette distance : le beurre, la lecture, le guet, l'appui sur l'épée, le linge, le puits, le soin des chevaux. Le balai, le désherbage, la pelle et le tri des herbes non éprouvés : leur homme était de garde (la garde, rang 4, passe avant le travail, rang 5 : l'arbitre a raison). **Corrigé en jeu** : d'un poste à un autre, aucun nouvel ordre (le lieu d'un poste était vide dans la signature de l'ordre) ; le lieu vaut maintenant le nom du poste (essai qui l'attrape).
- **Vu en jeu le 17-18/10, les postes un par un** (gros plans, `essai_poste_suivant`, un homme à 2,5 m d'Henry) : les
  seize genres posés et tenus, leur geste lancé. Distingués : le désherbage (accroupi, mains au sol), la pelle (penché),
  le puits (bras tendus), le tri des herbes, le guet et la lecture (postures de tête et de main), la prière et la prière
  courte (à genoux). Debout sans outil : l'appui sur l'épée, le balai, le beurre, le linge : il leur manque l'objet du
  jeu (épée, balai, baratte, baquet), pas d'autres points d'appui. **Corrigé en jeu** : un geste à un coup (la prière
  courte, `useKneelingGroundOneShotShort`) finissait et n'était pas relancé, contrairement à cette fiche ; l'arbre le
  relance maintenant tant que l'ordre tient (garde-fou au banc) ; vu : trois relances en 60 s.
- **La sonde de la forge** (principe du pair : un préfabriqué né entier par `RuntimePrefab`), deux essais au plus : 1) la petite forge (préfabriqué imbriqué) : l'entité naît, rien ne paraît ; 2) le préfabriqué de base (poste du forgeron, station de forge, emplacements, boutique) : de même. Entre les deux, le préfabriqué simple de la prière naît bien (un poste « Praying » de plus au relevé) : `RuntimePrefab` marche, mais pas pour les forges. Sonde arrêtée ; la forge passera par la ronde de gestes (la voie prouvée de Scriptorium : enclume, foyer, bac d'eau).

## 5 d — Les sorties à cheval des gens de métier

Règle de JoVenGer du 16/10 (NOTE_METIERS §0) : tous ceux qui sortent du camp partent à cheval et reviennent à cheval
(coursier, gens de métier qui vont en ville, au bois, à la chasse). Les raisons et les heures sont des règles de
Scriptorium ; le socle offre la sortie.

- `missions.sortir({ hommes, chef, lieu | point, duree_h, motif })` : une mission sans camp de bandits, par la même
  machine que les missions (étape 4) : la colonne part à cheval, sa tête en avant ; arrivée au lieu (à
  `arrivee_m`), elle y reste `duree_h` heures du jeu, puis rentre à cheval au bord du camp. Loin d'Henry et hors de sa
  vue, elle passe « dehors » (retirée du monde) ; l'aller, le séjour et le retour se calculent alors (vitesse de la
  colonne) ; elle renaît sur le chemin du camp, hors de la vue d'Henry. Rapport à la fin (issue « faite »), par
  l'accroche `rapport_de_mission`.
- Réponses prises d'office : une sortie vise un lieu connu (`missions.ajouter_un_lieu`, ceux de Scriptorium) ou un
  point du monde ; les gens de métier peuvent sortir (aucune exemption) ; un homme exempté de mission, non.

### Tranche 3 : le geste tenu à un point (la forge de Scriptorium, « refaite pareil »)

Principe transmis par le pair le 17/10 (Scriptorium, pas Alex) : la forge du camp est un coin en modèles du jeu et une
ronde de deux gestes (« marteler » à l'enclume, « chauffer » au foyer), postures « unstance » que Scriptorium déclare
dans sa table des postures. La trempe (une seule fois, elle fige le cerveau) n'entre jamais dans une boucle. Scriptorium
garde la ronde, ses durées et le décor ; le socle fournit le geste tenu et la marche entre les points.

- `hommes.tenir(id, regle, { activite = "geste", lieu, geste, position, cap, fin })` : l'homme marche au point, se
  tourne selon le cap, puis tient le geste (`UnstanceAction` par son nom, lu par l'arbre : ordre 22 ; le jeu emploie
  aussi le nom en variable, `AI/special/so_injured.xml`) jusqu'au changement d'ordre. Le nom du geste entre dans la
  signature de l'ordre : un autre geste redonne l'ordre ; un autre point aussi (au mètre, pour toute tenue à point fixe : vu sur une copie le 20/10, sonde du pair, le même geste déplacé de 54 m gardait sa signature et l'homme restait à genoux ; il se relève puis marche). Refus `geste_invalide`.
- Au banc ; à voir en jeu avec un geste du jeu (`repairFenceHammer`, le marteau des clôtures).
- **Vu en jeu le 17/10, le geste tenu** : avec `repairFenceHammer` (posture alignée dans
  `Libs/Tables/ai/NPCStateUnstanceDatabase.xml` : elle exige un objet d'ancrage), l'homme reste figé au point ; avec
  `AngryIdle` (non alignée, `IsAligned` et `UseLocationObject` à faux), la posture se joue (le corps change d'une capture
  à l'autre). Le mécanisme est prouvé ; c'est pourquoi Scriptorium déclare ses propres postures non alignées
  (« marteler », « chauffer »).
- **Vu en jeu le 17/10, la sortie à cheval** (5 d) : deux hommes montent, la colonne part à 80 m, arrive, reste 0,2 h du
  jeu, rentre à cheval ; rapport « faite ». Non vus : la sortie au loin (dehors, calculée) ; couverte au banc.
- **La tenue et les armes du Directeur** (D67, D69) : `directeur.donner_les_objets(objets)` (une liste de `{ objet,
  etat }` ou d'identifiants ; portés à chaque naissance, sa tenue de naissance retirée, puis un second passage ; une
  liste vide rend sa tenue de naissance). Au banc ; non vu en jeu.
- **Le guichet à la fin de l'étape 5** : plus aucune case « étape 5 » (221 servies, dont des « en partie » qui disent
  ce qui reste à Scriptorium ; 93 pas utiles avec leur raison ; 23 réglages ; 0 à ouvrir).
- **Reste ouvert** (dit au pair) : le poste partagé avec Henry (Henry passe avant, par l'interaction ; l'enveloppe sur
  l'instance d'une fonction du jeu peut demander un second « nom du jeu admis » : à JoVenGer).
- **Vu en jeu le 17/10 (séance sauvegardée puis rechargée)** : la sortie lointaine (dehors loin d'Henry, arrivée et
  retour calculés, renaissance sur le chemin du camp, rapport « faite ») ; le Directeur habillé de ses objets (7 créés,
  7 portés) ; après rechargement, le poste de prière reposé et repris, l'admis retrouvé et mené, jamais refait. Ajouté
  ensuite : à l'entrée en partie, le Directeur remet ses objets (recréés s'il en manque, sans doublon) ; non vu en jeu.

### Tranche 4 : le poste partagé avec Henry (Henry passe avant)

NOTE_METIERS §2 (réponse de JoVenGer du 16/10) et principe transmis par le pair (17/10) : un poste qu'Henry emploie
aussi (la forge, la table d'alchimie…) est partagé ; quand Henry veut s'en servir, l'homme cède aussitôt la place, sans
être renvoyé de son métier, attend à côté, puis reprend. On sait qu'Henry s'en sert par son **interaction** avec la
station, pas par la distance.

Sources (lecture seule) : `Scripts/Entities/WH/Minigames/Smithery.lua`, `AlchemyTable.lua` : `GetActions` y bâtit
l'action « use » par `Action()…:func(<la fonction de la station>)` et `AddInteractorAction` ; aucune lecture « Henry en
mini-jeu » dans les scripts ; `Minigame.CanUseMinigame(user.id)` (employée par ces stations) dit si Henry peut lancer un
mini-jeu.

Comportement :
- `hommes.partager_avec_henry(station, oui)` : la station (le nom de son entité) est surveillée. Le socle enveloppe son
  `GetActions` sur l'instance (le nom du jeu déjà admis) et **reconstruit** l'action « use » avec le constructeur du jeu,
  sa fonction enveloppée : quand Henry l'emploie, la station est « prise par Henry » (une ligne au journal), puis la
  fonction du jeu joue. Reposé à chaque battement (une entité refaite au chargement perd l'enveloppe).
- La fin : Henry peut de nouveau lancer un mini-jeu (`Minigame.CanUseMinigame`), après `partage_delai_s` secondes au
  moins, ou il s'est éloigné de plus de `partage_loin_m` mètres.
- Un homme tenu avec `partage = station` (`hommes.tenir(..., { ..., partage = station })`) : la station prise, il
  marche au point d'attente (décision remplaçable `hommes.ou_attendre(id, station)` : par défaut à `partage_attente_m`
  mètres de la station, de son côté) ; libérée, il reprend sa tenue (son geste, son poste).
- Non vérifié en jeu tant qu'une station du jeu n'a pas été prise puis rendue par Henry.
- **Essai en jeu du 18/10, arrêté après deux essais** : Henry posé à une forge (`essai_henry_a_la_forge`), la station
  partagée, puis « Henry la prend » comme à la touche E (`essai_henry_prend_la_station` : GetActions puis « use »). La
  meule (`IsUsable` du jeu) puis la forge (`Blacksmithing.CanUse`) n'offrent **aucune action** à Henry à cet endroit (de
  nuit, une forge qui n'est pas à lui). Et **le nom d'une station, même avec son GUID, peut se résoudre vers une autre
  entité** (la forge visée : une autre à 3,3 km) : le partage devrait tenir l'entité par son identifiant
  (`stations_proches` la tient déjà), pas par son nom. À voir par JoVenGer, de jour, à une forge qu'il peut utiliser.

## Le personnel mené, hors de la Compagnie (demande du pair, 18/10/2026)
- Les gens de Scriptorium (métiers du camp, clients de passage, prisonniers, notaire…) ont notre cerveau et sont menés
  par les mêmes ordres que nos hommes, sans être de la Compagnie : ni effectif, ni plafond, ni solde, ni moral, ni garde,
  ni bataille, ni mission, ni ronde de notre fait.
- `hommes.tenir_un_personnage(personnage, regle, quoi)` : « quoi » comme `hommes.tenir` (geste ancré, poste, marche à un
  point, suivre, à cheval…) ; la fiche du mené naît à sa première tenue, dans `d.menes` (jamais dans `d.ordre`) ; un
  personnage de la Compagnie est refusé (`deja_de_la_compagnie`), un personnage absent aussi (`personnage_introuvable`).
  Sans « fin », la tenue tombe au prochain changement de tranche, comme pour nos hommes : Scriptorium donne « fin ».
- Le sommeil sur un lit nommé (demande du pair, 20/10/2026 : à 23 h, les 17 gens du personnel avaient chacun un lit
  chez Scriptorium mais restaient debout) : `{ activite = "sommeil", lit = "<nom d'entité>", fin = … }`, règle
  `sommeil` ; le lit, déclaré ou non, doit exister (`jeu().objet_existe`), sinon refus `lit_invalide` ; « lit » hors du
  sommeil : `lit_invalide` ; un lit à plus de `hommes.reglages.lit_nomme_max_m` (100 m) du centre du camp fondé :
  `lit_invalide` (vu sur une copie le 20/10 : trois gens envoyés dormir sur des objets à plus de 2 km, puis posés
  là-bas par le secours). Le lieu (signature de l'ordre) est ce lit, le but sa position (ou « position » si donnée) ;
  l'ordre est celui des lits (11, par le WUID de l'objet), comme pour une place déclarée. Vaut aussi pour nos hommes
  par `hommes.tenir`. Le socle ne réserve pas ce lit : Scriptorium le retire de ce qu'il donne aux hommes.
- Les sorties de métier à cheval (demande du pair, 20/10/2026 ; règle de JoVenGer du 16/10 : qui sort du camp part et
  revient à cheval) : `{ activite = "suivre", vers = <point>, a_cheval = true, lieu = "sortie_<id>", fin = … }` par
  `hommes.tenir` ou `tenir_un_personnage`. Un homme seul ou un mené est la tête de sa propre colonne (un « lieu » par
  sortant ; un mené est toujours seul), sans chef, son cheval passager monté (ordre 20 vers le point). La tête
  s'arrête à quelque 6,5 m de son point (vu le 17/10, fiche 17). La tenue changée (la tâche au point), l'ordre suivant
  le fait descendre ; le cheval est retiré une fois l'homme descendu, à plus de `cheval_retrait_m` de lui ou au
  `cheval_retrait_battements`-ième battement, jamais sous son cavalier ; de même pour un mené lâché en pleine sortie, encore en selle (sa tâche disparue : son personnage et son nom sont gardés avec sa monture). Corrigé ce jour : le cheval d'un mené était
  retiré à chaque battement et refait (sa fiche n'était pas trouvée). En sortie, ni gardien ni secours (ni le passage
  « dehors », propre aux missions) ; au-delà de ~450 m d'Henry, le jeu ne fait plus vivre un personnage (fiche 17).
- `hommes.lacher_un_personnage(personnage, regle)` ; sans plus aucune tenue, il n'est plus mené (il attend).
- `hommes.personnel_mene()` : la liste des personnages menés.
- Au battement : tenues échues, personnage disparu oublié, ordre redonné ; pas de secours (fait pour nos hommes au camp).
- Non vérifié en jeu.

## Un mené sans plus aucune tenue ne reçoit plus d'ordre (vu sur une copie de la partie de JoVenGer, 19/10/2026)
- Vu : « Ordre à ScriptoClient_scr_client_1 : attendre (nil) : introuvable » : la prise lâchait la dernière tenue d'un
  client que Scriptorium venait de faire disparaître, et `hommes.lacher` lui donnait encore un ordre « attendre ».
- Désormais : la dernière tenue lâchée (`hommes.lacher_un_personnage`), ou toutes ses tenues échues au battement
  (`hommes.mener_le_personnel`), le personnage n'est plus mené, sans aucun ordre. Essai (vérifié qu'il échoue sans).
- Le personnel mené est secouru comme nos hommes (vu sur une copie de la partie de JoVenGer le 20/10 : deux chasseurs, un
  jardinier et un porteur d'eau, envoyés par Scriptorium à une place dans la cabane puis à 40 m au sud, restés bloqués
  contre le mur ouest pendant des heures) : `hommes.mener_le_personnel` donne désormais le secours (téléportation du jeu,
  jamais sous les yeux d'Henry). Et sans aucun homme dans la Compagnie, le personnel est encore mené (il ne l'était plus).
  Essai (vérifié qu'il échoue sans). Non vérifié en jeu.
- **Tous en relève** (décision de JoVenGer, 20/10, transmise par le pair, choix recommandé pris d'office) : interrupteur
  `un_lit_par_homme` éteint (la prise l'éteint), aucun lit n'est réservé à l'embauche (il dort à une place libre par
  `place_pour`, comme les autres) ; un lit encore réservé à un homme (embauché avant) est rendu une fois au battement, avec
  une ligne au journal. Interrupteur allumé, rien ne change. Essai (vérifié qu'il échoue sans).
- **Le lit de la nuit** (vu sur une copie le 20/10 : deux hommes sur le même lit, trois fois ; la liste des lits libres
  ne savait pas qui dormait déjà où, et la déclaration de Scriptorium, raccourcie entre deux ordres, faisait glisser les
  rangs) : un lit donné au sommeil est GARDÉ pour cet homme jusqu'à son lever (`hommes.lits_de_nuit`, en mémoire) ;
  redemandé, il garde le même ; la liste des lits libres passée à `camp.place_pour` écarte les lits gardés par les autres ;
  le rang par défaut ne compte que les hommes sans lit ni lit de la nuit ; un lit gardé qui disparaît de la déclaration
  est rendu. Le choix reste à `camp.place_pour` (Scriptorium), la réservation est au socle (accord du pair). Essai
  (vérifié qu'il échoue sans) ; non vu en jeu.

## Le tir à la cible (demande du pair, 20/10/2026, séance J)
- Scriptorium (mode 26, tir_a_la_cible) envoie un chasseur ou un archer au poste de tir, à 7–25 m d'une cible posée dans
  l'Aménagement ; le socle n'avait aucun équivalent (le chasseur restait à son établi).
- `hommes.tenir(id, regle, { activite = "tir", position = <poste>, cible = <nom de l'entité visée>, fin })` (et
  `hommes.tenir_un_personnage` pour un mené). La cible est le point de visée que Scriptorium pose au cœur de la cible
  (une entité nommée : son WUID est lu par la liaison). Refus `tir_invalide` : sans poste, sans cible, cible introuvable.
- L'ordre : la cible donnée à la liaison avant l'ordre (`donner_la_cible_du_tir`), la cible dans le lieu (la signature :
  une autre cible redonne l'ordre), le regard sur la cible ; la liaison pose le poste, le WUID de la cible
  (`scriptorium_essai_cible`) et l'activité 24.
- Branche 24 de l'arbre, d'après la pile de tir sur cible fixe du jeu (AI/quests/prepadeni/prepadeni.xml,
  bandit_shootOnTargetWithNotification ; le contexte du concours de tir, AI/quests/archery/archery.xml,
  bandits_shooting) : se relever (sous l'urgence du cerveau), marcher au poste (marche rejouée), se tourner vers la
  cible ; puis, tant que l'ordre tient : l'arc mis en main gauche (HandContentElement, jeu d'armes secondaire par
  GetWeaponsFromWeaponSet), la cible posée (InstantSetTarget), l'automate de tir (MeleeOffenseAutomationDecorator autour
  de WaitAction) dans le contexte combat_missileAttackerIgnoreTrajectoryCollision. Fin dès que l'ordre change (une
  alerte est une règle plus forte : nouvel ordre).
- Pas de munitions sans fin : chaque flèche tirée est prise au carquois (munitions complétées au lever et au
  rechargement).
- Contrôle d'absence : la valeur de l'automate passe par une variable (`$tir_automate`) ; deux balises fermantes du jeu
  (EntityContextElement, MeleeOffenseAutomationDecorator) ajoutées aux formes admises (38, revue).
- Au banc : essai_hommes (refus, ordre, cible, regard, tenu, cible changée, lâché) et contrôles de la branche 24 et de
  la liaison (vérifiés en échec sans). Non vu en jeu.

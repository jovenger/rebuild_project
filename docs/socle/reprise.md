# Fiche de reprise — socle de Scriptorium (état au 15/10/2026)

Pour une nouvelle conversation Claude Code lancée sur l'ordinateur de JoVenGer. La note courte à coller est
`docs/socle/note_complete.md` ; ce fichier-ci donne le détail.

- **D'abord**, la note de JoVenGer `C:\Users\maste\Desktop\Scriptorium\docs\socle\NOTE_POUR_LE_SOCLE.md` (lecture seule) : elle passe
  avant le plan d'action ; la suivre dans l'ordre, une étape à la fois (où on en est : `avancement.md`).

## 1. Le projet
- JoVenGer construit « Scriptorium », un grand mod pour Kingdom Come: Deliverance II (KCD2 1.5.6). Il vit dans
  `C:\Users\maste\Desktop\Scriptorium` (git local seulement). Il repose aujourd'hui sur le mod « Mercenaries » d'Alex.
- **Mission du chantier :** refaire entièrement ce mod, à notre façon, comme un mod à part, `scriptorium_socle`, sans
  jamais copier, traduire ni renommer le code d'Alex. L'adaptation à Scriptorium (la « bascule ») viendra après, sur
  l'ordre de JoVenGer.
- Dépôt : `https://github.com/jovenger/rebuild_project`, branche `ccr-c18b8b50-tespti`, sur le PC dans
  `C:\Users\maste\Desktop\rebuild_project`.

## 2. Comment travailler avec JoVenGer
- **Tout en français**, réflexion comprise ; réponses courtes, en listes. Il ne lit pas l'anglais.
- **Il ne tape aucune commande** : Claude lance tout lui-même (PowerShell), JoVenGer clique « Autoriser » et répond.
- Il valide par **questions à cocher** (outil de questions), une série de quatre au plus à la fois.
- Il est souvent loin de l'écran : lui dire régulièrement en deux lignes où on en est.
- Une chose à la fois, menée jusqu'au bout ; rien laissé en essai ; pas de `TODO`. Un message de lui pendant le travail
  se prend en compte tout de suite.

## 3. Interdits (règles de JoVenGer)
- Ne jamais écrire dans `C:\Users\maste\Desktop\Scriptorium` ni dans son git ; ne jamais ouvrir ni lire
  `Scriptorium\mercenaires\` (salle blanche : seul `outils\empreintes.py` le parcourt, et n'en garde que des sha256).
- Ne jamais toucher à `D:\Scriptorium V2\Scriptorium`.
- Dans le jeu (`G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2`) : ne jamais écrire dans `Mods\scriptorium`,
  `Mods\scriptorium_regles`, `Mods\scriptorium_lumiere`, ni dans `Data\` (lecture des paks permise, en mémoire). Le
  socle s'installe dans `Mods\scriptorium_socle` seulement, par `noyau\installer.py`.
- Ne jamais charger la **Partie 2** (`playline1`, partie actuelle) avec le socle. La **Partie 1** (`playline0`, finie)
  sert aux essais, chargée sur la sauvegarde 473, **jamais sauvegardée**.
- Aucune action destructive (suppression, écrasement, modification de la liste des mods) sans l'accord de JoVenGer
  juste avant. Ne jamais renommer ni déplacer les dossiers des mods.
- Pas de commit si `py -3.13 essais\tout_verifier.py` ne finit pas par « tout passe ». Commits signés
  `-c user.name="Claude" -c user.email="noreply@anthropic.com"`, message terminé par
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Plus aucun texte jaune par-dessus l'image du jeu : tout message passe par le bandeau en bas, bande noire, texte blanc.
- Le camp paie au coffre, jamais avec la bourse d'Henry.
- Règles, agissements et comportements des hommes et du camp : **toujours en données et réglables** (fichier de
  réglages, fiche 10), pour que le programme Scriptorium puisse les changer plus tard.
- `docs\socle\idees_pour_plus_tard.md` : n'y pas toucher avant la fin du reste.

## 4. Ce qui est fait
- **Quatorze morceaux** dans `socle\pak\Scripts\scriptorium\` : `noyau`, `liaison` (seul fichier qui parle au moteur),
  `bandeau`, `registre`, `coffre`, `camp`, `hommes`, `bataille`, `directeur`, `enceinte` et `atelier`, `patrouilles`,
  `discipline`, `caractere` (fiche 11, idée de JoVenGer du 15/10 : chaque homme est quelqu'un), `reglages`, et le `poste`
  d'essai (30 ordres). Démarrage : `socle\pak\Scripts\Mods\scriptorium_socle.lua`. Seul le noyau pose la table
  `Scriptorium` ; chaque morceau la reprend par `local Scriptorium = Scriptorium` (à la bascule : `scriptorium.socle`).
- **Note de JoVenGer, partie 2, toute faite le 15/10** : argent d'Henry sûr ; registre en tranches de 30 000 (vu en jeu
  après sauvegarde et rechargement) ; nombres justes en simple précision (hasard du noyau à trois germes) ; aucun jeton
  au-delà de 65 535 octets ; caractère tiré en cloche (étroite) ; un seul nom par table. Suite : son étape 1.
- **Fiches 00 à 11** dans `docs\socle\fiches\` ; **02 à 11 validées par JoVenGer** (14 et 15/10, questions à cocher).
  Changements qu'il a demandés : livre de comptes à 50 lignes, deux rations par homme et par jour, butin doublé, corps
  ennemis laissés à fouiller une journée, enceinte de 20 m (22 pans), l'onguent soin léger, réglages par fichier.
- **Banc** : `essais\tout_verifier.py` — syntaxe Lua 5.1, 1 731 vérifications sur un faux jeu, ordres par fichier,
  liaison sur un faux moteur, réglages par fichier (outil, liaison, installateur), noms interdits, 80 textes, manifeste,
  contrôle d'absence contre les empreintes d'Alex (0 partout). Tout passe.
- **Outils** : `noyau\installer.py` (garde le fichier de réglages), `outils\ordonner.py` (ordres au poste),
  `outils\regler.py` (réglages : `chemin=valeur`, `--retirer`, `--voir`, `--liste` des 168 valeurs),
  `outils\verifier_modeles.py`, `outils\empreintes.py`, et `outils\pilotage\` (voir partie 6).

## 5. Ce qui est vu en jeu (points V1 à V24 dans `essai_en_jeu.md`)
- Chargement du mod, textes français, bandeau en bas, ordres par fichier, minuteries posées à l'entrée en partie,
  registre gardé par la sauvegarde et lié à sa partie, coffre et bourse d'Henry, heure du jeu.
- Camp debout et orienté comme Henry, feu qui brûle, bancs `Chair`, paillasses `Bed`, coffre ; enceinte de 20 m fermée,
  tours, porte qui s'ouvre et se ferme (et se ferme seule la nuit, barrée si une bande vient : au banc).
- Hommes et Directeur présents (âmes provisoires) ; bande de cinq qui vient ; mort vue (`actor:IsDead`) ; fins de
  bataille par le jeu et par la règle ; butin doublé ; morts couchés en corps (`actor:RagDollize`) que le jeu propose de
  piller, retirés après la durée réglée.
- Fichier de réglages lu au lancement, appliqué en pleine partie avec son message, enceinte reposée à la nouvelle taille.
- **Pas encore** : nos personnages ne bougent pas et ne se battent pas (V17, V18) ; pas de dialogue du Directeur (V21) ;
  âmes et apparences à nous (V20) ; une aube, une semaine, une patrouille, la porte la nuit, V6.

## 6. Mener un essai en jeu (seul, sans que JoVenGer touche à rien)
1. Accord de JoVenGer pour changer la liste des mods.
2. `outils\pilotage\debut_essai.ps1` : vérifie la liste d'origine, arrête le veilleur du Scriptorium, ne laisse que
   `scriptorium_socle`.
3. `outils\pilotage\vers_partie1.ps1` : ferme le jeu sans sauvegarder, contrôle la Partie 1, installe, lance avec
   `-devmode`, va jusqu'à la sauvegarde 473 ; regarder `securite\captures\choix_473.png`, puis
   `outils\pilotage\confirmer_partie1.ps1`.
4. Ordres : `py -3.13 outils\ordonner.py --jeu "<jeu>" scriptorium_essai_aller_nord` (deux fois : le pré fauché),
   puis `_camp`, `_coffre` (trois fois), `_hommes`, `_directeur`, `_enceinte`, `_bataille`, `_voir_bande`, `_frapper`…
   (`--liste` pour tous). Cinq secondes entre deux ordres. Le journal `kcd.log` (racine du jeu) dit le résultat, lignes
   `[Scriptorium]`, écrites par moments.
5. Voir : `. outils\pilotage\touches.ps1` puis `Capture "nom"`, `Tourner pas`, `Marcher secondes` ;
   `outils\pilotage\tour.ps1 -Nom x` fait une planche de huit vues. Les images vont dans `securite\captures\`.
- Partie d'essai (`playline2`, sauvegarde permise) : `outils\pilotage\vers_partie_d_essai.ps1` (par « Continuer ») ou,
  pour une sauvegarde précise, `vers_partie_d_essai.ps1 -Charger` (s'arrête sur la liste, capture `charger_partie.png`),
  choix à vue, puis `confirmer_sauvegarde.ps1 -Attendu "playline2/<sauvegarde>"`. Le chargement n'est réussi que si la
  veille du poste dit « partie en cours = true » (un échec ramène au menu, et « entrée en partie » s'écrit quand même).
  `sauvegarder_et_quitter.ps1` sauvegarde la partie d'essai et ferme le jeu (refuse si la partie chargée n'est pas `playline2`).
6. **Toujours finir** par `outils\pilotage\fin_essai.ps1` : jeu fermé sans sauvegarde, Partie 1 contrôlée, liste des
   mods d'origine remise (empreinte `75A3A33C…`), veilleur relancé. Le noter dans `avancement.md`.
- Pièges connus : la console du jeu ne s'ouvre pas (d'où les ordres par fichier) ; au menu principal, fermer demande
  « Voulez-vous quitter le jeu ? » (les scripts répondent) ; une minuterie posée au lancement du mod ne tire jamais ;
  dans le prologue d'une partie neuve l'heure est arrêtée (d'où la Partie 1) ; le dossier `securite\` (copies de la
  liste des mods et de la Partie 1, captures) n'est pas dans git.
- **Le Lua du jeu compte en simple précision** (vu le 15/10) : entiers justes jusqu'à 16 777 216 seulement, et un nombre
  collé à une chaîne s'écrit avec six chiffres (« 1.03997e+09 »). Aucun calcul du socle ne doit dépasser 2^24 ; écrire les
  nombres par `string.format`. Le banc (Lua en double précision) ne le voit pas : l'ordre `scriptorium_essai_registre_tranches`
  compare en jeu la somme et le hasard aux valeurs du banc (« nombres justes »).
- **Jamais un jeton de plus de 65 535 octets**, même pour un essai : le 15/10, une sauvegarde de la partie d'essai qui en
  portait de 66 000 à 200 000 caractères ne s'est plus rechargée (`playline2\exit.whs`, « Échec du chargement » ;
  `autosave003.whs` intacte). La liaison refuse désormais (`poser_un_jeton`).

## 6 bis. Où reprendre l'étape 1 (pause du 15/10/2026, demandée par JoVenGer)
- **Acquis en jeu** (V29 à V36, `essai_en_jeu.md`) : un homme né par script, avec une âme du mod
  (`Libs/Tables/rpg/soul__scriptorium_socle.xml`) et un cerveau du mod (tables `Libs/Tables/ai/*__scriptorium_socle.xml`,
  arbre `AI/scriptorium/essai_ordres.xml`), **vit s'il est éveillé** juste après sa naissance (`liaison.eveiller` :
  `entite:Activate(1)` et `AI.AutoDisable(id, 0)`). Il marche vers un point donné en variable `vec3` du cerveau, change de
  point sur ordre (variable `int` lue à chaque tour : l'arbre finit chaque branche et recommence), rejoint un autre homme
  désigné par une variable `wuid`. Avec le sous-cerveau « switch » du jeu (`npc_basic_switch`) en plus, il tire l'épée.
- **Ouvert** : s'asseoir à même le sol (V32, V33 : la branche bloque) ; s'asseoir sur un siège posé par script (pas de
  `this`) ; **porter des coups** (V34, V36 à V40 : épée tirée, aucun coup ; avec la chaîne de la bagarre du jeu, le
  sous-arbre n'est plus mis à jour). **15/10 au soir (V43) : un brigand du jeu (cerveau `npc_basic`), né par script et
  éveillé, se bat pour de bon dès qu'Henry lui porte un vrai coup** (`g_gameRules:CreateHit`, le chemin des coups du
  jeu) : il charge, frappe et tue Henry. Le combat du jeu marche donc sur un homme né par script ; ce qui manquait est le
  déclencheur. `soul:DealDamage` (V42) ne déclenche sans doute rien. Essais suivants, dans l'ordre : (1) notre marcheur
  (notre cerveau + switch du jeu) reçoit un vrai coup : riposte-t-il ? sinon, alors seulement, les boîtes aux lettres de
  `npc_basic` (`hitData`…) dans notre cerveau ; (2) un vrai coup « de la part de » notre homme sur un brigand : le
  brigand l'attaque-t-il, et notre homme se défend-il ? (moyen possible pour le Directeur de lancer un combat).
  V44 (15/10 au soir) : un coup à 0 point d'Henry suffit ; un coup « de la part de » notre marcheur (0 ou 10 points) ne
  déclenche rien. V45, V46 : notre arbre appelle `Function_callInterrupt_attack` (ordre 8) ; avec ou sans les 24 boîtes
  aux lettres de `npc_basic`, pas d'attaque, et le marcheur ne réagit pas au coup d'Henry. Trois différences restent avec
  `npc_basic` : le sous-cerveau des horaires (type 9 « Scheduler », qui joue sans doute les interruptions), notre arbre
  (un `Move` relancé à chaque tour), l'âme (garde contre brigand). V47 : horaires ajoutés, compteur d'appel dans le
  `SuppressFailure`, deux hommes observés (garde et brigand à notre cerveau). Si rien : un arbre qui se tait après
  l'ordre 8 (`Wait` long). Pour la fiche 12 : l'architecture du jeu serait « ordres = interruptions jouées par le
  Scheduler » ; le type 8 (DogCompanion) est une piste pour l'escorte d'Henry, plus tard.
  V47 à V49 (15/10 au soir) : le sous-cerveau des horaires de `npc_basic` empêche la partie de se charger ; notre
  sous-cerveau en type 9 n'est plus joué ; la fonction d'attaque réussit mais notre cerveau ne la joue pas ; c'est le
  cerveau, pas l'âme. **Mais un garde du jeu né par script se porte de lui-même vers le brigand du jeu, qui le tue**
  (brigand à 100 : que le garde ait frappé n'est pas établi). Voie à confirmer : nos hommes d'armes au cerveau
  `npc_basic`, avec nos propres âmes ; décision d'architecture à faire valider par JoVenGer (fiche 12). Étapes suivantes : (1) une âme du
  mod au cerveau `npc_basic` (faction amie d'Henry) : se bat-elle contre le brigand comme le garde du jeu ? (2) les
  « télécommandes » : quels messages aux boîtes de `npc_basic` deviennent des interruptions (`AI/npc/basic/switch/`),
  pour que le Directeur donne ses ordres (poste, garde, rassemblement, sommeil) à des hommes au cerveau du jeu.
  **V50 (15/10 au soir), percée** : notre cerveau = un switch à nous (type 6, table `subbrain_switching`) + les
  horaires du jeu (`npc_basic_scheduler`), rien d'autre (principe transmis par la conversation Scriptorium). La
  partie se charge ; à l'ordre 8 (`Function_callInterrupt_attack`), notre homme charge le brigand du jeu : les
  horaires jouent l'interruption. Ouvert : nos hommes frappent-ils ? (le brigand reste à 100 contre quatre). Prochain
  essai : notre homme contre un adversaire qui ne se défend pas (sa santé baisse-t-elle ?). Puis les ordres de
  marche en interruptions à nous (aller au point, poste, garde, rassemblement, sommeil).
  **V51, V52 : le combat de l'étape 1 aboutit.** Sans arme tirée, notre homme engage sans blesser (V51) ; arme
  tirée par `human:DrawWeapon` (comme `CombatDebug.lua` du jeu), il tue l'adversaire sur ordre (V52), compétences à 0.
  Suite : les comportements à nous joués en interruption (aller au point, poste, garde, rassemblement, sommeil),
  par la table `SmartEntity__so_interrupt` (principe transmis par la conversation Scriptorium) ; puis la fiche 12.
  V53 : Henry posé en prairie par l'ordre `scriptorium_essai_prairie` (plus de trajet) ; l'ordre d'attaque tire l'arme
  et l'homme frappe ; compétences posables par `soul:AdvanceToSkillLevel` (relu, hors `-devmode`). Le brigand du jeu
  `kopa_man_16` (armure complète) n'est jamais blessé : mesures suivantes contre une âme ennemie plus légère. Le
  tirage des compétences selon le caractère est une règle nouvelle : fiche 11 ou 12 d'abord, validation de JoVenGer.
  V54 : contre un brigand léger (`kkop_bandit_7`), notre homme le blesse et le met en fuite. Le combat de l'étape 1 est
  acquis. Suite : comportements à nous joués en interruption (`SmartEntity__so_interrupt`), puis fiche 12.
  V55 : un comportement à nous (« scriptorium_aller ») joué en interruption, posé par notre switch avec le nœud
  générique `AddInterrupt` sur l'entité des interruptions du jeu : l'homme va au point et compte son arrivée ; l'arbre
  lit et écrit les variables de son cerveau. **Architecture de l'étape 1 trouvée** : cerveau = switch à nous (type 6)
  + horaires du jeu ; chaque ordre du Directeur = une variable d'ordre + un comportement à nous en interruption ; le
  combat = l'interruption d'attaque du jeu, arme tirée par l'ordre. Suite : fiche 12 (à envoyer à la conversation
  Scriptorium, puis à faire valider par JoVenGer), puis les comportements poste, garde, rassemblement, sommeil.
  **Fiche 12 validée par JoVenGer (15/10 au soir)** : architecture adoptée ; faction « la Compagnie » à nous ;
  compétences selon le niveau puis le caractère ; ordre : réveil au chargement, puis garde, rassemblement, poste ou
  travail, suivre Henry, dormir, puis veillées. Prochaine chose : le réveil de nos hommes à chaque entrée en partie.
  **V56 (15/10)** : après « Sauvegarder et quitter » puis rechargement, nos hommes sont encore là et leur cerveau
  tourne sans réveil ; ses variables reviennent à zéro. Fait : à l'entrée en partie, ordres redonnés et manquants
  ramenés (`hommes.relancer`, `directeur.relancer`), réveil à la venue. Attention : la partie d'essai `playline2` est
  au prologue, temps arrêté ; « aller » n'y est pas joué. Les essais de comportements se font sur la Partie 1.
  Demandes de JoVenGer (relayées le 15/10 au soir) : le plus petit coup qui déclenche encore (0 point, sinon 1) ; Henry
  tenu à distance pendant les essais. **Ouvert pour plus tard : l'attaque à vue** (une bande qui attaque d'elle-même en
  voyant le camp, pour les raids et les missions) : le brigand du jeu n'attaque pas Henry de lui-même à 8 m, même en
  prairie ; pistes : boîtes aux lettres de `npc_basic`, `XGenAIModule.IgnorePerception`, volumes perceptibles et sons
  des crimes du jeu.
- **Pour la fiche 12 (le cerveau de nos hommes)**, déjà acquis : une branche de combat ne rend jamais la main, et l'homme
  n'obéit plus à aucun ordre (compteur des tours figé, nouveau marcheur à chaque essai). Les arbres du jeu entourent
  chaque action longue d'une garde `IfGate … RunLogic="Halt"` sur leur variable d'état (`AI/npc/basic/switch/interrupt_attack.xml` :
  `$attackState == …attacking`, vu dans `Scripts.pak`). Le même arbre note de ne mettre aucun nœud d'horloge (attente)
  avant le `CombatAction` ; nos essais V37 à V40 en ont un à côté (`Parallel` avec `Wait`). Chaque branche de notre arbre sera gardée par la variable d'ordre, sinon le Directeur ne pourra pas
  rappeler un homme engagé.
- **Méthode** (JoVenGer, via la conversation Scriptorium) : une chose changée à la fois, en partant de ce qui marche ;
  prévenir la conversation Scriptorium au début et à la fin de chaque essai ; JoVenGer laisse Claude choisir les essais.
  Décision de JoVenGer du 15/10 (confirmée directement) : quand le socle bloque, la conversation Scriptorium regarde
  comment le mod d'Alex s'y prend et transmet seulement le principe (le mécanisme du jeu), jamais son code, ses noms,
  ses fichiers ni sa structure ; Claude n'ouvre jamais le dossier d'Alex, écrit son propre code, contrôle d'absence strict.
- Acquis revus sans `-devmode` le 15/10 : mêmes résultats (`essai_en_jeu.md`, « Avec ou sans `-devmode` »).
- Contrôle d'absence : les lignes XML identiques au jeu de base qui portent un réglage s'écrivent à notre façon (choix de
  JoVenGer du 15/10) ; seules les lignes de forme (structure) sont excusées, listées, au plus 31.

## 7. Ce qui reste à faire
Voir `docs/socle/plan_d_action.md` : 1. comportement des personnages (priorité) ; 2. nos âmes et personnages ;
3. dialogue du Directeur et Gestion du camp à l'écran ; 4. quête de fond ; 5. voix et icônes ; 6. essais en jeu restants ;
7. fin du chantier (contrôle strict, scellés, langues, bascule sur ordre).

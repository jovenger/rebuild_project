# Fiche de reprise — socle de Scriptorium (état au 18/10/2026, nuit)

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
   `-devmode`, va jusqu'à la sauvegarde 473 ; regarder `D:\socle_captures\captures\choix_473.png`, puis
   `outils\pilotage\confirmer_partie1.ps1`.
4. Ordres : `py -3.13 outils\ordonner.py --jeu "<jeu>" scriptorium_essai_aller_nord` (deux fois : le pré fauché),
   puis `_camp`, `_coffre` (trois fois), `_hommes`, `_directeur`, `_enceinte`, `_bataille`, `_voir_bande`, `_frapper`…
   (`--liste` pour tous). Cinq secondes entre deux ordres. Le journal `kcd.log` (racine du jeu) dit le résultat, lignes
   `[Scriptorium]`, écrites par moments.
5. Voir : `. outils\pilotage\touches.ps1` puis `Capture "nom"`, `Tourner pas`, `Marcher secondes` ;
   `outils\pilotage\tour.ps1 -Nom x` fait une planche de huit vues. Les images vont dans `D:\socle_captures\captures\`.
- Partie d'essai (`playline2`, sauvegarde permise) : `outils\pilotage\vers_partie_d_essai.ps1` (par « Continuer ») ou,
  pour une sauvegarde précise, `vers_partie_d_essai.ps1 -Charger` (s'arrête sur la liste, capture `charger_partie.png`),
  choix à vue, puis `confirmer_sauvegarde.ps1 -Attendu "playline2/<sauvegarde>"`. Le chargement n'est réussi que si la
  veille du poste dit « partie en cours = true » (un échec ramène au menu, et « entrée en partie » s'écrit quand même).
  `sauvegarder_et_quitter.ps1` sauvegarde la partie d'essai et ferme le jeu (refuse si la partie chargée n'est pas `playline2`
  ou `playline3` ; alerte si la sauvegarde s'écrit hors de la ligne chargée).
- **Partie d'essai n° 3** (`playline3`, « Partie 4 » au menu ; accord de JoVenGer du 15/10) : copie de la sauvegarde 473 de
  la Partie 1, temps qui avance, sauvegarde permise ; c'est elle qu'il faut pour les comportements et les rechargements
  (`playline2` est au prologue, temps arrêté : les interruptions n'y sont pas jouées). `vers_partie_d_essai.ps1 -Ligne
  playline3` (par « Continuer », seulement si une sauvegarde d'essai faite dans la séance est la plus récente) ; sinon
  `-Charger`, « Partie 4 » choisie à vue (troisième ligne depuis le 15/10 : la Partie 3 a disparu), puis
  `confirmer_sauvegarde.ps1 -Attendu "playline3/<sauvegarde>"`. Ne jamais appuyer sur X, ni dans la liste ni au menu
  principal (supprime la sauvegarde choisie).
- **« Continuer »** reprend la sauvegarde dont l'heure de l'en-tête (`SaveTime`) est la plus récente (V59). Décision de
  JoVenGer (15/10) : il doit reprendre sa partie après chaque essai. `fin_essai.ps1` range donc à part (déplace, ne
  supprime jamais) les sauvegardes d'essai plus récentes que sa partie, dans `Saved Games\kingdomcome2\essais_du_socle_rangees`,
  **jeu ouvert, avant de le fermer** : rangées jeu fermé, le nuage Steam les remet au lancement suivant. Une séance finit
  donc le jeu ouvert (au menu ou en partie), jamais par `sauvegarder_et_quitter.ps1`. `sauvegardes.ps1` dit aussi ce que
  « Continuer » reprendra.
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
  **V57** : correctif vérifié en jeu (aucun doublon à l'entrée en partie, ordres redonnés une fois) ; partie d'essai
  laissée sans camp ni hommes (`scriptorium_essai_tout_lever`, puis sauvegarde).
  **V58** : partie d'essai n° 3 créée (`playline3`) ; « aller » y est joué, avant et après rechargement ; sauvegarde écrite
  dans `playline3`, autres lignes intactes. Suite : la faction « la Compagnie », puis monter la garde.
  **V60 à V62 (s'asseoir, se coucher)** : acquis par `CallBehavior` du comportement « use » de l'objet (banc ou lit du
  jeu, ou copie posée, sans meuble visible). Suite : sièges et paillasses du camp en objets du jeu, puis les ordres
  « repas », « veillée », « sommeil » des hommes par eux. Sept idées validées par JoVenGer le 15/10 : dans
  `plan_d_action.md`, à leur étape (pas maintenant).
  **Meubles utilisables (fiche 03), validés par JoVenGer le 15/10** : un objet du jeu par place, posé sur le meuble
  visible ; paillasses des tentes en « Bed_1Place_Tent » ; au rechargement, seulement les manquants (après une séance
  qui vérifie les meubles blancs ; jamais un objet à état à l'aveugle) ; places gardées à la Compagnie et à Henry.
  V63 : les tentes gardées par la sauvegarde revenaient blanches (modèle par défaut de BasicEntity) ; V64 : objets du
  socle posés avec `bSaved_by_game` à false, plus rien n'est gardé, tout est reposé à neuf depuis le registre (vu à
  l'image). Suite : poser les objets du jeu (sièges, lits de tente) sur les meubles du camp, relire leurs WUID après
  chaque repose, puis les ordres repas, veillée, sommeil des hommes par eux.
  V66 : le marcheur s'assoit sur un banc du camp (vu), dos au feu, corrigé par un demi-tour de la place (V67, non
  revu) ; le lit de tente non vu à l'image. Ne jamais poser Henry près des meubles du camp par script : écran noir (V67).
  Pour voir : tour de vue sans déplacer Henry. Ensuite : des âmes à nous pour les hommes du camp (notre cerveau), puis
  leurs ordres repas, veillée, sommeil par les places du camp.
  V68, V69 : assis face au feu sur un banc du camp, couché sur une paillasse du camp (vus). Meubles utilisables acquis.
  **Fiche 13, nos âmes** (validée 15/10) : 293 âmes à nous (`outils/ames.py` écrit `soul__scriptorium_socle.xml` ;
  identifiant calculé `5c7a5c7a-RRRR-4PPP-8000-N…`, `liaison.ame_de` ; `tout_verifier.py` 2 quinquies accorde table et
  liaison). Une âme par homme, tirée à l'embauche, gardée sur sa fiche, jamais changée (montée en grade comprise) ;
  palier plein : le plus proche ; jamais de refus faute d'âme. V70 : hommes et Directeur nés sur nos âmes, assis sur les
  bancs et couchés dans leurs paillasses sur ordre (vus). Ensuite : l'équipement par le Lua (V71), la faction (V72), puis
  les ordres repas, veillée, sommeil des hommes par les places du camp.
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

## 6 ter. Où reprendre (pause du 16/10/2026, vers 3 h, demandée par JoVenGer, ordinateur éteint)
- **Fait dans la nuit du 15 au 16/10** (détail dans `essai_en_jeu.md`, V71 et V72 a à e, et les fiches 13 et 14) :
  - V71 : l'équipement pièce par pièce, gardé au rechargement avec son usure ; munitions complétées à l'entrée en partie.
  - V72 : la faction « la Compagnie » (`FactionTree__scriptorium_socle.xml`, écrite par `outils/ames.py`, relations du
    chien et du cheval d'Henry) ; nos hommes ne réagissent pas à un délit d'Henry ; flèches usées puis complétées.
  - Écran noir intermittent (emblème de chargement, jeu actif) : correctifs décidés par JoVenGer : camp fondé à 4 m
    devant Henry, une place à soi par homme, jamais deux personnages à moins d'un mètre, réveil différé de 30 s à
    l'entrée en partie, guetteur du chargement. Décompte dans la fiche 14 : **à poursuivre à chaque séance** (ajouter une
    ligne au tableau ; rien n'est conclu avant plusieurs séances propres de suite).
- **Règles nouvelles du 16/10** (dans `plan_d_action.md`) : le socle fait la mécanique et Scriptorium décide ; nettement
  meilleur qu'Alex ; toute sortie du camp à cheval (missions et métiers) ; la note des métiers à relire avant chaque
  fiche de la vie du camp ; les postes d'Henry (fumoir, séchoir, prie-Dieu, table de tri) partagés avec tout le camp,
  l'homme cède la place à Henry ; questions toujours en choix à cocher.
- **Outils** : captures dans `D:\socle_captures\captures` ; garde du disque C (1 Go) dans `debut_essai.ps1` et
  `sauvegarder_et_quitter.ps1` ; commandes d'essai `scriptorium_essai_compagnie_*` et `scriptorium_essai_ecran_noir_*`
  (positions autour d'Henry) ; une sauvegarde d'essai rangée qui a donné l'écran noir une fois (non reproduit) :
  `C:\Users\maste\Saved Games\kingdomcome2\essais_du_socle_rangees\playline3\2026-10-16_012417_exit.whs`.
- **Prochaine étape** : la fiche des comportements suivants de la vie du camp (étape 1 : repas, veillée, sommeil par les
  places du camp ; garde, rassemblement, suivre Henry), après relecture de `CARTE_DES_REGLES.md` et de `NOTE_METIERS.md`
  (Scriptorium, lecture seule) ; fiche envoyée au pair, questions à cocher à JoVenGer, puis code et essais.

## 6 quater. Où reprendre (16/10/2026, après V73 c 4)
- **Vie du camp (fiche 15)** : V73 a, les gestes (marcher, s'asseoir au repas) ; V73 c 1 à 3, la levée d'un homme assis
  échoue ; V73 c 4, l'essai court (choix de JoVenGer « court, puis durable ») : la garde fait lever l'homme du dedans,
  il marche, puis **le jeu le rassoit dès que notre interruption finit**. Grille de lecture et mesures dans la fiche 15.
- **Le modèle durable, fait et vu en jeu** (fiche 12, révision validée par JoVenGer ; V73 c 5 à V73 c 8) : un seul
  comportement long, la « vie du camp » (pouls, relance hors combat et hors conversation, « faire, puis tenir »,
  activité dans `scriptorium_activite`) ; notre propre posture pour s'asseoir et se coucher ; la tenue échoue au
  changement d'ordre ; les marches en `changeNPCState="true"`. Vu : repas assis à midi, levés et partis à la corvée à
  13 h. **Valeurs de l'arbre en données, acquises** (V73 c 9 à c 11) : table `hommes.cerveau` au catalogue, écrite
  dans le cerveau par le battement, valeur par défaut du catalogue tant que rien n'est écrit (comparée au banc),
  variables non gardées dans la sauvegarde ; seules la priorité et l'urgence de l'interruption restent dans l'arbre
  (aucune forme du jeu). Le lever du lit est vu (V73 c 13) ; les lits dans leur tente, les hommes couchés le long du
  lit grâce au quart de tour (V73 c 14, fiche 03). La levée courte d'un homme repris assis : cas résiduel accepté par
  JoVenGer (« rien pour l'instant », voie du pair en réserve, fiche 12). **Suite** : V73 b, l'arbitre des priorités, avec
  le plafond de relances du pair ; la première mesure : un ordre d'attaque donné à un homme assis.
- **V73 b, fiche revue le 16/10** (fiche 15, section « V73 b », commit 7ac7a62) : trois pas, chacun vu en jeu avant le
  suivant. V73 b 1 : la mesure de l'attaque sur un homme assis (commande d'essai, lecture des contextes « occupé », le
  secours figé en combat ; grille écrite) ; V73 b 2 : le plafond de relances, dans le switch, ligne au journal par le
  Lua ; V73 b 3 : l'arbitre par tenues (une par règle, rangs au catalogue, ordre redonné sur-le-champ, bornes, registre
  en version 3). Relue par le pair, validée par JoVenGer (réponses a, a, a).
- **V73 b 1, vu en jeu** (0f324f1, 6970cdd) : un homme assis se lève de lui-même à l'ordre d'attaque et se bat ; pendant
  le combat, aucune relance ; après, une seule, et il revient s'asseoir (deux fois). Le dégagement d'Alex n'est pas
  nécessaire. **Fait nouveau** : des hommes dévêtus en pleine partie (pièces dans le sac, plus portées ; au combat, et
  une fois sans combat) : fiche 13. Décision de JoVenGer : finir V73 b, puis la tenue (garde de la tenue d'abord,
  principe du pair).
- **V73 b 2, vu en jeu** (3183209) : le plafond tient (3 lancements par fenêtre, puis une fenêtre d'arrêt, une ligne au
  journal par arrêt) ; un lancement de trop après la tempête, corrigé (un pouls qui avance remet le switch en marche),
  vu en jeu en V73 b 2 bis (plus aucun lancement en 173 s une fois les valeurs retirées) : **acquis**.
- **V73 b 3, vu en jeu** (d506a0e) : l'arbitre par tenues (une par règle, rangs au catalogue `hommes.priorites`, ordre
  redonné sur-le-champ, bornes, exemptions, interrupteur de la journée, registre en version 3) ; bataille, discipline
  et patrouilles converties. En jeu : la tenue forte donne l'ordre aussitôt, la faible attend dessous, la forte lâchée
  rend la faible aussitôt. **V73 b est fini.**
- **La garde de la tenue, faite et vue en jeu** (16eaf77, V71 g ; fiche 13, réponses a et a de JoVenGer) : fins de
  combat comptées par le switch, sortie du lit, un homme par battement en tournant ; jamais au lit, au bain ni en
  combat ; service `hommes.rhabiller` pour le guichet. Vu : rhabillé dans le battement qui suit la fin de son combat.
  Pas encore vu : un homme dévêtu sans combat, rhabillé par le tour. La cause reste à chercher, si JoVenGer le veut.
- **L'ancre du camp** : vérifiée dans le code, prouvée au banc (5f40493) et **vue en jeu** (Henry éloigné à 44 m et
  tourné, sauvegardé puis repris : le camp reposé exactement à sa place ; fiche 03). Acquis.
- **V73 d 1, tenir un poste, fait et vu en jeu** (dcd34c8 ; fiche 15, réponses a, a, a de JoVenGer) : le garde marche à
  son poste (arrêt à 50 cm), se tourne vers un point de regard posé dans son cerveau (cap du poste, sinon vers le dehors),
  regarde autour de lui le jour (60 s ± 30), arme rangée ; ordre 12, branche 12. Vu : arrivé sans glisser, tourné (de 27°
  à 0°), le geste fini seul, la garde lâchée qui rend sa tranche. Borne des lignes de forme du jeu à 32 (à dire à
  JoVenGer).
- **V73 d 2, la ronde, faite et vue en jeu** (55e0d40, 408c6af ; fiche 15, réponses a, a, b, a de JoVenGer) : tenue
  « ronde » (chemin de 2 à 32 points du monde, boucle ou aller-retour, départ) ; à chaque point, l'arbre appelle le Lua
  (`ExecuteLua`, sous `pcall`), qui pose le point suivant, le regard vers le dehors et la pause tirée par le socle ;
  branche 13. Vu : 33 pas, aucune erreur, pauses tenues, tourné vers le dehors, sans glisser, la boucle, la ronde lâchée.
  Règle du départ confirmée par JoVenGer (17/10) : après rechargement, secours ou règle plus forte, le point le plus
  proche. La borne des lignes de forme du jeu à 32 lui va.
- **V73 d 2 bis, fait et vu en jeu** (3ca2b99 ; fiche 15, réponses a, a, a de JoVenGer) : l'accroche « ronde_reprise »
  (appelée à chaque reprise avec le lieu, le plus proche, le nombre de points, le point visé d'avant et la raison :
  rechargement, secours, regle_plus_forte ; première réponse valable, sinon le plus proche) ; `hommes.ronde_point(id)`
  pour le guichet ; la ronde sans pause (`pauses = false` : 0 ms, regard vers le point suivant). Vu : la reprise après un
  rassemblement, avec et sans l'accroche ; sans pause, un court arrêt d'environ 2 s reste à certains points.
- **Gardé pour l'essai de nuit** (fiche 15, « Mesuré en V73 d 2 bis ») : l'arrêt d'environ 2 s de la ronde sans pause ;
  mesure : trois rondiers sans pause à 120°, 10 min, l'écart relevé chaque minute ; pistes : arrêt de marche plus large,
  puis les marches du jeu le long d'un chemin de points.
- **V73 e, le rassemblement, fait et vu en jeu** (443c950 ; fiche 15, réponses recommandées prises d'office) : une place
  sur un arc autour d'un centre (rayon, ouverture, face au centre ou au dehors, course ou marche), la place dans la
  signature de l'ordre, redonnée aux autres à chaque convocation ; la course par `scriptorium_allure` et `$allure` dans la
  branche 12 ; les 150 m pour un but au camp ; jamais secouru sous les yeux d'Henry (`liaison.henry_voit`). Vu : trois
  hommes assis se lèvent et courent, places recalculées, tournés vers le centre ; « Rompez » rend l'exercice.
- **Consigne de JoVenGer du 17/10** : continuer sans s'arrêter ; les réponses recommandées sont prises d'office et notées
  comme telles dans les fiches (à lui redire dans le bilan).
- **V73 f 1, suivre Henry à pied, fait et vu en jeu** (2a4c69d ; fiche 15, réponses recommandées prises d'office) : règle
  « escorte » (rang 2), la colonne chaînée (le premier suit le chef, chacun le précédent, le rang dans la signature),
  `Function_followNpc` du jeu (le chef en WUID dans `scriptorium_chef`, nos huit distances), le rattrapage au-delà de 60 m
  (4 m derrière Henry, hors de sa vue) à la place du secours pour un suiveur, `directeur.suivre`. Vu : la colonne qui suit
  Henry à pied et en courant, le rattrapage en chaîne après un saut de 160 m, le retour au camp par les 150 m.
- **V73 f 1 bis, l'escorte en formation du moteur, faite et vue en jeu** (a6ab701 ; montage revu avec le pair) : le chef
  (le Directeur, ou le premier homme) ouvre la formation dans une branche sans marche et suit Henry dans une branche sœur
  (ordre 15 ; le modèle lu par le Lua) ; les suiveurs s'y rangent (ordre 16, un nœud par mode, `MoveHistory` par défaut),
  sinon suivent leur chef 4 s ; la formation fermée seulement quand le chef cesse de mener ; `hommes.formations` au
  catalogue. Vu : la forme followNPC à l'image, reformée après un rattrapage. À surveiller : une formation orpheline après
  un rattrapage du chef.
- **V73 f 2 a, la sonde à cheval, faite et vue en jeu** (ad37d81 ; relecture du pair intégrée) : un cheval né par script
  (classe `Horse`, âme Horse2 du jeu, hors de la sauvegarde) ; l'ordre 17 : la posture « horse » du jeu autour de la suite
  (forme de `moveOnHorse`), un `WaitAction` avant, « en selle » compté, la monte bornée par `monte_delai_ms` (10 s, au
  catalogue), sinon à pied. Vu : Jan monte, suit Henry à cheval au pas et à la course, descend à la fin de l'escorte.
  Pas vu : le repli à pied au bout de 10 s.
- **Séance** : depuis la liste « Sélectionner une partie », descendre deux fois (Partie 4), Entrée, regarder la liste des
  sauvegardes (« 473 »), puis seulement `confirmer_sauvegarde.ps1` (sinon rien ne se charge et le script ferme le jeu).
- **V73 f 2 b, la troupe à cheval, faite et vue en jeu** (64ed7f8 ; relue par le pair) : tenue « escorte » avec
  `a_cheval` ; un cheval passager par homme (mémoire seulement, né à 5 m sous un angle au hasard) ; branche 18 (mener à
  cheval, la formation hors de la posture), branche 19 (se ranger à cheval, `MoveHistory` ou `Relaxed`) ; la monte manquée
  comptée par l'arbre et lue au battement (3 essais puis à pied) ; retrait après la sortie (homme à plus de 6 m, ou au 2e
  battement) ; un cavalier jamais reposé seul. Réponse prise d'office, à redire à JoVenGer en tête du bilan : **chevaux
  passagers** (pas de chevaux gardés au camp ; idée n° 13 pour plus tard).
- **V73 f 2 c, le cheval né hors des meubles, fait et vu en jeu** (c65f206 ; relu par le pair) : un homme au camp va
  chercher son cheval hors du camp, côté porte ; place à 3 m de tout objet du camp et de l'enceinte, hors du cercle, à
  3 m des autres chevaux, sur un sol praticable (pente, rayon descendu), hors de la vue d'Henry si possible ; le délai
  de monte allongé de la marche. Vu : l'eau n'est pas lisible (pas de `ent_water`) ; le reste se mesure.
- **V73 f 2 d, l'escorte monte quand Henry monte** (ef36ec9, a4e12b6) : tenue `a_cheval = "comme_henry"` ; une veille
  d'une seconde (une par partie) lit Henry à cheval en Lua (un cheval monté à moins de 1,5 m de lui, n'importe lequel, pas
  les nôtres) ; monté tout de suite, à pied après 4 lectures de suite. Vu en jeu avec la lecture forcée ; la vraie monte
  d'Henry n'a pas abouti (touche E simulée sans effet, deux essais) : non vérifiée. La lecture par l'arbre (`StanceCheck`
  sans objet) retirée : sa seule ligne est celle d'Alex, absente du jeu ; l'admettre est la décision de JoVenGer.
- **V73 f 2 e, le Directeur monté, chef de colonne, fait et vu en jeu** (a0e7449) : `directeur.suivre(oui, formation,
  a_cheval)` ; son cheval est celui des hommes (un « porteur ») ; il reprend la tête des escortes d'Henry en formation
  (réglable). Vu : il mène monté, la colonne derrière lui ; mais **le chef monté démarre tard** (11 à 16 m d'Henry juste
  après qu'il se met en route, rattrapé en 8 s).
- **V73 f 2 f, l'allure du chef monté réglée sur Henry, faite et vue en jeu** (4869393) : branche 18, un `Move` vers son
  chef à l'allure mesurée toutes les 300 ms (vitesse d'Henry par sa position), la distance en correction, une marge de
  10 % aux seuils. Vu : 10,8 m après 10 s de marche (15,9 avant), 8,7 m après une course (11,6 avant).
- **V73 f 2 f bis, l'allure affinée, faite et vue en jeu** (06833ae, f91587e) : l'arrêt à sa place avec sa tenue, la
  correction tenue, le freinage à 8 m ; le `Move` suit sa cible (`destChangedThreshold`) et se redonne à chaque cadence.
  Vu : 5,4 m après la marche, 4,3 m après la course, quatre changements d'allure.
- **V73 f 2 g, l'allure de tous les cavaliers, faite et vue en jeu** (352cbfc) : le cavalier seul (17) et le suiveur
  perdu ou sans formation (19) passent par la boucle d'allure ; perdu au-delà de 13 m de son chef, de retour en deçà de
  6 m ; une mesure par homme suivi ; les sauts écartés. Vu : le cavalier seul à 4,2–4,35 m d'Henry ; la perte et le retour.
- **V73 f 3 a, la sonde de la carte, faite** (7adeaf2) : la carte se lit par `sv_map` (« kutnohorsko »), l'altitude des
  repères de Scriptorium en secours ; au chargement, seul `OnLoadingComplete`.
- **V73 f 3 b, la carte du camp et le grand saut, faits** (ba0906c, 7a4a05f, 741346d, ded2994) : le camp note sa carte
  (un camp ancien la prend sur preuve) et ne se repose que sur elle ; ailleurs, seule l'escorte est refaite derrière
  Henry, l'embauche va au registre, aucune bande ne naît ; le grand saut lancé au bond d'Henry (veille d'une seconde),
  ordre à pied tout de suite, selle lue avant tout retrait (attentes, abandon), rien sous ses yeux, pose relue avant le
  nouveau cheval. Vu en jeu : six bonds, la colonne posée 5 à 6 s après, 0 pose perdue sur 12 avec la relecture.
- **Le rechargement du Lua sans relancer le jeu, vu en jeu** (df2974e) : `outils/recharger.py --jeu "<jeu>" hommes …`
  puis l'ordre `scriptorium_essai_recharger` ; seulement les morceaux sans boucle à eux (pas le noyau, la liaison, le
  registre, le bandeau, les réglages, le poste ; ni les arbres XML ni les tables). Fiche 15, V73 g 0.
- **Fin de l'étape 1, vue en jeu** (bf9b02e) : le gardien des hommes en version simple (sous le sol repêché, figé
  relancé, relance utile), la liaison relisible dans le jeu ouvert, la porte (l'escorte dans l'embrasure, puis dehors).
- **Étape 2, vue en jeu** (0100eff et la bataille rechargée) : les bandes sur nos âmes (copiées sur des âmes du jeu),
  leur faction, éveillées ; nos hommes les attaquent, l'attaque redonnée à chaque battement ; la bataille se clôt.
  À reprendre : l'initiative de la bande (elle n'attaque ni nos hommes ni Henry d'elle-même ; fiche 14).
- **Suite** : le nécessaire de JoVenGer (`plan_d_action.md`, en tête), point 3 : le guichet (brancher Scriptorium sur
  le socle, le tableau des règles en double) ; puis les missions, l'embauche et les métiers, la bascule. À vérifier par JoVenGer : le passage Trosky ↔ Kuttenberg
  (avec une sauvegarde portant un camp du socle d'avant ba0906c : la charger d'abord sur la carte du camp), la vraie monte d'Henry, le voyage rapide par la carte, et les intérieurs (l'escorte à pied dans une auberge : porte, escalier, étage).
- **À faire après V73 b (JoVenGer, 16/10, transmis par le pair)** : le camp ne suit jamais Henry. Vérifier que, une fois
  fondé, le camp se repose depuis l'ancre gardée au registre (origine et cap), jamais depuis Henry ; essai au banc et en
  jeu (fonder, déplacer Henry de 50 m, sauvegarder, recharger : le camp reste à sa place) ; l'écrire dans la fiche 03.
  La règle de Scriptorium pour choisir le lieu (`camp_selon_le_terrain`) : on ne s'en mêle pas (JoVenGer).
- **Ensuite** : V73 b (l'arbitre des priorités, et l'attaque sur un homme assis), V73 d (la garde), V73 e (le
  rassemblement), V73 f (suivre Henry, à cheval), le gardien des hommes, puis les étapes 2 à 8.
- **Écran noir** : 1 sur 113 chargements ou poses depuis la séparation (V73 c 9, non reproduit en reprenant la même sauvegarde ;
  décompte et observations dans la fiche 14, à poursuivre).

## 6 quinquies. Où reprendre (17/10/2026 au soir : étapes 1 à 5 franchies ; la bascule attend l'ordre de JoVenGer)

- **Fait** (le « nécessaire » de la note de JoVenGer) : étape 1 ; âmes et faction ; étape 3, le guichet
  (`docs/socle/guichet.md` : 337 entrées du contrat, plus aucune « à ouvrir » ni « étape 5 » : 221 servies, 93 pas utiles
  avec leur raison, 23 réglages) ; étape 4, les missions (fiche 17) ; étape 5, l'embauche et les métiers (fiche 18).
- **Ajouté à la demande du pair pour la bascule** : les décisions remplaçables (fiche 19 : `Scriptorium.remplacable`,
  `Scriptorium.avis`) ; les paroles (fiche 20) ; le registre par case, regroupé et surveillé (fiche 01) ; les noms du
  jeu admis au contrôle d'absence (`GetActions` seul, décision de JoVenGer du 17/10 : un nom de plus se demande à lui).
- **Banc** : 18 fichiers d'essais, 8 877 vérifications, tout passe (commit de tête : voir `git log`).
- **Vu en jeu** (détail dans `essai_en_jeu.md`) : l'embauche groupée, l'homme refait avec ses objets, « Parler »,
  l'admis (après rechargement aussi), les gens de métier hors de la garde, quinze postes de travail du jeu (la prière dite
  en sous-titre), le geste tenu, les sorties à cheval proche et lointaine, le Directeur habillé, le registre par case
  sauvegardé puis rechargé (644 Ko intacts, écrits en 30 à 33 ms), les paroles de bout en bout (aucune ligne dite).
- **Non vu en jeu** : la liste finale est `docs/socle/a_verifier_par_jovenger.md`.
- **En attente** : l'ordre de JoVenGer pour la bascule (étape 6) ; le poste partagé avec Henry (pas encore écrit ; un
  second « nom du jeu admis » possible, à soumettre à JoVenGer).
- **Séances d'essai** : `debut_essai.ps1`, puis `vers_partie_d_essai.ps1 -Charger -SansDevmode -Ligne playline3`, Bas
  deux fois, Entrée, capture, `confirmer_sauvegarde.ps1 -Attendu "playline3/autosave473"`, ordres par
  `outils/ordonner.py`, toujours `fin_essai.ps1`. Une sauvegarde d'essai faite par `sauvegarder_et_quitter.ps1` est
  rangée à part par `fin_essai.ps1`. Lua rechargeable en jeu ouvert : `outils/recharger.py` puis
  `scriptorium_essai_recharger` (le poste lui-même ne se recharge pas : une commande nouvelle demande de relancer le jeu).
- **Leçons de la journée** : une sonde à deux essais au plus, puis on s'arrête ; un détecteur d'oublis qui dénonce des
  états intermédiaires ne prouve rien (la surveillance au battement l'a remplacé) ; l'horloge du moteur n'avance pas
  dans une image (mesurer avec `liaison.chrono`) ; une posture « unstance » alignée ne se joue pas sans objet d'ancrage.

## 6 sexies. Où reprendre (18/10/2026, nuit : finitions, demandes du pair pour la bascule)

- **Fait et vu en jeu** (détail : `essai_en_jeu.md`, S1 ; fiches 01, 18, 20) : « Parler » absent en combat ; le
  Directeur rhabillé après rechargement ; le geste de poste relancé (défaut de l'arbre corrigé) ; les postes jamais tenus ;
  la perte du registre à la sauvegarde corrigée (minuterie de 2 s) puis le **second canal** (les cases en attente rangées
  dans la sauvegarde par l'OnSave de notre entité `scriptorium_sauvegarde`, reprises au chargement) ; les **alertes par la
  voix du guetteur** (réplique urgente, cloche `f_ge_bell_alarm`, « Alerte ! » à part au bandeau ; le rouge impossible).
- **Fait, au banc seulement** : âmes sans jumeaux (fiche 13 : 71 / 50 / 30 visages) ; geste ancré (`siege`, `assis`) et
  arme tirée (`arme_tiree`) ; `bandeau.annoncer_texte` (texte composé par Scriptorium) ; garde-fou « ordre des locales ».
- **En cours : les dialogues** (fiche 21). Écrits par `outils/dialogues.py` depuis `socle/dialogues/arbres.json` : projet de
  quêtes `Quests/scriptorium_socle.xml`, rôles, règles Storm, textes. Vu en jeu le 18/10 : la table des rôles et les
  textes chargés par le jeu ; **le jeu n'offre pas encore son « Parler »** à nos hommes (premier essai) ; questions de
  principe posées au pair (fichier Storm, sélecteur, projet, démarrage sur une partie existante).
- **Commandes d'essai nouvelles** : `henry_a_la_forge`, `henry_prend_la_station`, `alerte_texte`, `parler`,
  `parler_directeur` (216 commandes).
- **Arrêtés après deux essais** : le poste partagé (stations refusées à Henry, noms ambigus) ; le rouge du bandeau.
- **Liste de JoVenGer** (courte) : `a_verifier_par_jovenger.md`.
- **Leçon** : un commit est parti avec le banc en échec (13aee49, réparé par 9539c82) : commit seulement par « && » après
  « tout passe ».

## 6 septies. Où reprendre (pause du 18/10/2026, vers 3 h 50, demandée par JoVenGer : PC éteint)

État : banc vert, tout commité et poussé, mod propre installé, jeu fermé, ordre des mods remis (scriptorium,
scriptorium_regles, scriptorium_lumiere), « Continuer » reprend la partie de JoVenGer (playline1). Aucune sonde dans
l'arbre de travail.

**1. « Parler » des dialogues (fiche 21) — en cours, bloqué.**
- Établi en jeu : les règles Storm s'appliquent à nos hommes (mêmes métarôles qu'un villageois) ; `actor:CanTalk(henry)`
  est VRAI pour eux (version actuelle : rôles avec role_id, une règle Storm par âme, arbres complets) et ils ne sont pas
  en mode combat ; donc rôles, Storm et quête sont reconnus.
- MAIS à la visée (notre « Parler » de secours retiré), le jeu affiche « Soldat » et aucune action : `GetActions` du jeu
  rend une liste vide (`user.actor:CanInteractWith` faux, ou un retour anticipé).
- Écarté : la copie des propriétés à la naissance (un homme « brut » fait pareil) ; les branches 'dialogMailbox' de
  l'interrupteur du jeu (essayées, sans effet seules) ; la vie du camp (premier temps de la sonde du pair : un homme
  brut dont l'interrupteur ne lance PAS la vie du camp n'a toujours pas « Parler »).
- PIÈGE : ne jamais juger un essai sur la ligne « Henry parle à » : notre secours ajoute « talk » quand le jeu n'en met
  pas. Seul l'écran, secours retiré (`scriptorium_essai_parlable_fin`), fait foi.
- Suite proposée par le pair (sonde en trois temps) : temps 1 fait (négatif) ; temps 2 (vie du camp sans hôte) et
  temps 3 (vie du camp par l'interruption d'attaque du jeu) n'ont plus de sens si le temps 1 est négatif : redemander
  au pair d'autres pistes (différences restantes avec ses dames des bains : personnage Skald à nous + skald_character2role,
  classe NPC_Female, classe sociale, autre).
- Les sondes employées sont dans le dossier de travail de la session (scratchpad : sonde_metaroles.py,
  sonde_parle.py, sonde_brut.py, sonde_sans_vie.py ; essai_ordres_avec_boite.xml dans %TEMP%) : à réappliquer pour
  sonder, jamais à commiter.

**2. Fait au banc, à voir en jeu (prochaine séance regroupée)** :
- geste ancré (`siege`, `assis`) et arme tirée (`arme_tiree`) ;
- les cinq points de la bascule : `pillage_du_socle`, accroche `apres_l_equipement`, `camp.place_pour`,
  `enceinte.place_valable`, activité « affronter » (`cible`, `arme`, `jusqu_a`) ;
- `bandeau.annoncer_texte` ; âmes sans jumeaux (71 / 50 / 30 visages).

**3. Liste de JoVenGer** : `a_verifier_par_jovenger.md` (voyage rapide, Trosky ↔ Kuttenberg, monte d'Henry, escalier,
poste partagé à une forge de jour, écran noir ; puis « après la bascule »). La bascule attend « Parler », puis son ordre.

**4. Règles de séance ajoutées le 18/10** : à chaque fin de séance, écrire « fenêtre ouverte » au pair et attendre
« fenêtre rendue » avant de relancer le jeu ; la partie neuve d'essai (playline4) est rangée par `sauvegardes.ps1`
(le nuage Steam la remet au lancement : `fin_essai` la range jeu ouvert) ; commit seulement par « && » après
« tout passe ».

## 6 octies. Où reprendre (18/10/2026, après « reprend le boulot »)

État : banc vert, tout commité et poussé (dernier : da8ea9d), socle propre installé, jeu fermé, ordre des mods remis,
aucune sonde dans l'arbre.

**Fait aujourd'hui (au banc ; vu en jeu quand c'est dit)**
- « Parler » : vu en jeu, l'action ne paraît qu'à environ 1,5 m (les essais d'avant étaient trop loin). Notre cerveau
  ouvre le dialogue grâce à deux branches parallèles sans fin sur 'dialogMailbox' (896a54d, garde-fou au banc). La suite
  d'entrée est choisie d'office (plus de clé brute). Menu, sous-menu et retour : vus en jeu.
- Caméra du dialogue : filme toujours Henry. Essayé : CameraCommand, ReferenceLength, SelectedSouls, nos âmes, le
  cerveau npc_basic, une âme de villageois du jeu née par script. Arrêté, en FINITIONS (accord du pair). Reste à
  essayer : un PNJ du monde à portée, ou le principe des dames des bains.
- Vu en jeu : le visage suit l'âme, pas le personnage du jeu. Le nom affiché vient du personnage (ui_name_string_name).
- Faits : une âme jamais portée deux fois (f9cb612) ; les 31 compagnons nommés (64528fa) ; l'interrupteur
  « moral_de_bataille » (80bb5f7) ; le personnel mené hors de la Compagnie (80e600c) ; chaque homme son nom, 351
  personnages (fb1fbfc) ; l'outil de la reprise, `outils/ames.py --releve` (6b103e2) ; les lieux de mission, neuf par
  carte, pris dans level.pak (da8ea9d).

**Séance regroupée du 18/10 (accord direct de JoVenGer ; Scriptorium construit pour le socle, playline3, jamais sauvée)**
- Vu en jeu : noms au-dessus des têtes ; dialogue ouvert ; annonce par texte au bandeau ; 9 lieux par carte au journal ;
  la prise démarre (après correction du pair) ; plus d'oscillation (cabane imaginaire, corrigée chez le pair) ; la
  baigneuse et trois lavandières menées hors de la Compagnie, à leurs postes sous la tente des bains.
- Non vérifié : le geste tenu à l'image ; l'affrontement (pas d'ordre d'essai).
- Défaut vu par JoVenGer : un soldat presque nu (sous-vêtement, coiffe, tour de cou, épée, bouclier, bottes). Cause non
  trouvée : un homme engagé par Scriptorium sans ligne « équipé » chez nous, ou le colonel rhabillé par Scriptorium.
  Décidé avec le pair : la tenue est gardée par le socle seul ; Scriptorium passera ses décisions par une décision
  remplaçable (il écrit le détail).
- Remis par le pair ; vérifié : liste des mods d'origine (empreinte), Partie 1 identique, « Continuer » sur playline1,
  veilleur en marche.

**Reste**
- La tenue des hommes : gardée par le socle seul. Fait chez nous au banc (filet de la tenue de corps, reequiper,
  remplacer_une_piece, pieces_au_sac, tenue du colonel ; fiche 13) ; branché chez le pair (bascule/prise 99558f89, le 19/10 :
  tenue du colonel, tête nue au camp, forge, achats, ne_pas_rhabiller ; colonel_du_camp ne touche plus à la tenue).
  Décision de JoVenGer (19/10, transmise par le pair) : la tenue suit TOUJOURS le grade (changer_de_palier à chaque
  promotion). Les arbalétriers naissent en rôle « arbaletrier ». Les hommes libres sont branchés : forge, armurier, bains,
  fouille, portage et chantiers prendront nos hommes (plus d'ordres « scriptorium »).
- Séance regroupée du 19/10 (accord direct de JoVenGer, playline3, jamais sauvée ; remis par le pair, vérifié : liste des
  mods d'origine, Partie 1 identique, « Continuer » sur playline1, veilleur en marche) :
  - vu à l'image : le colonel en tenue de capitaine, TÊTE NUE au camp (bassinet rangé au sac) ; les hommes en attente
    d'équipement entièrement vêtus de leur tenue de naissance (le soldat nu du 18/10 ne venait donc pas de l'attente) ;
  - au journal : deux arbalétriers engagés par Scriptorium, équipés en assemblages d'arbalétrier (arbalète au dos non
    vue à l'image) ; les 4 femmes des bains menées (« seller » : leur repos voulu) ; aucune erreur, aucun refus, aucun
    homme à rhabiller ;
  - la file d'habillage (un homme à la fois, ~30-40 s chacun) : gardée, accord du pair.
- Trois répétitions de la bascule le 19/10 (sur des copies de sa partie, accord direct de JoVenGer à chaque fois ;
  toujours rangées, jamais sauvées ; remis et vérifié après chacune). À la troisième, TOUT vu : reprise des valeurs,
  de l'état et de la caisse (juste au groschen près), camp adopté, cabane d'Henry et tente du Directeur reposées par
  Scriptorium, caisse d'Henry visible à la tête du lit, Directeur repris et son dialogue en entier. L'écran noir : Henry
  épuisé et affamé dans cette sauvegarde (le jeu assombrit la vue), pas un défaut. Reste avant le vrai jour : la marque
  du camp sur la carte (réglée à la cinquième, ci-dessous), la caisse d'Henry à ouvrir en jeu (aucune invite vue), puis l'ordre de
  JoVenGer pour la vraie bascule.
- Quatrième répétition (19/10, même accord, rangée, jamais sauvée, remis et vérifié) : la marque du camp est sur la
  BOUSSOLE (écu bleu), pas sur la carte, même à ~60 m du Directeur (question laissée au pair, rien à relancer chez
  nous) ; « Des fautes aujourd'hui ? » sans fautif : plus de sous-menu ; l'aller-retour de caisse (1000 donnés puis
  remis) juste au groschen près, arrondi prouvé par le pair. Vu : le Directeur affichait « Soldat » : il s'appelle
  désormais « Le Directeur » (`hommes.nom_du_directeur`, fiche 13).
- Cinquième répétition (19/10, accord direct de JoVenGer, rangée, jamais sauvée, remis et vérifié) : « Le Directeur »
  vu au-dessus de lui ; au chargement, la carte reste sans écu ; la sonde du pair éteint puis rallume la marque et
  l'écu bleu apparaît sur la carte (à côté du drapeau rouge, à part d'Henry). JoVenGer l'a aussi sur la carte dans sa
  partie : la correction est chez le pair (la prise éteint la marque une fois à la reprise), à voir au vrai jour.
- **Bascule faite (19/10, ordre de JoVenGer)** : Mods\scriptorium_socle est son mod de tous les jours (version figée
  0e0113b). Verrou des séances (6214ad2) : rien n'y est écrit hors d'une séance ouverte par Scriptorium.
- **Séance avec des hommes (19/10, accord direct de JoVenGer, playline3, jamais sauvée, remis par le pair)** :
  - incident au lancement : en mode « Charger », Entrée est tombée sur « Continuer » (sa partie a commencé à charger) ;
    jeu arrêté pendant le chargement, rien d'écrit (vérifié) ; vers_partie_d_essai.ps1 corrigé : plus d'Entrée, arrêt
    sur une capture, arrêt du jeu si un chargement paraît ;
  - vu juste : l'embauche par Scriptorium (6 hommes, 0 pièce introuvable), le colonel (tenue de capitaine, tête nue),
    les dialogues d'un homme et du colonel (codes et répliques selon l'état), « Double la garde », l'appel au feu (vu
    au journal du pair), le duel (départ, cercle à 57 m, fin par fuite) ;
  - **défauts chez nous, à corriger** : (1) « affronter » ne défait pas sa cible à la fin
    (liaison.ordonner_l_attaque : arme tirée, scriptorium_essai_cible, ordre 8, callInterrupt_attack ; aucun inverse) :
    Henry reste en combat, la nuit de Scriptorium (gardes, ronde) ne se met pas en place ; CORRIGÉ au banc (ordre 9 :
    callInterrupt_stopReaction, comme le jeu ; liaison.cesser_l_attaque ; fiche 14), non vérifié en jeu ; (2) le secours qui pose un homme (SetWorldPos) pendant
    une marche menée le laisse figé en posture en T (Albrecht ; un nouveau geste ne le répare pas) : CORRIGÉ au banc
    (le secours passe par la téléportation du jeu, ordre 10, callInterrupt_teleport ; fiche 15) ; (3) PAS UN DÉFAUT :
    la famille epee_bouclier donne sword_shield de rang 3 au palier 1 (hommes.equipement.familles), sword_shield_3_01
    est juste ; (4) le lit du Directeur donné à un homme sur un camp sans Directeur : CORRIGÉ au banc (place_pour
    demande les places libres « pour les hommes », comme le compte des lits ; essai, vérifié qu'il échoue sans) ;
  - défauts chez le pair (notés de son côté) : nom du dialogue des hommes (corrigé), loisir qui bloque missions,
    métiers, exercice et troupe, nom tiré au hasard dans l'annonce du duel, « vers le est ».
- **Séance de vérification (19/10 au soir, accord direct de JoVenGer, playline3, jamais sauvée, remis par le pair)** :
  - VU JUSTE : la fin du duel (« cesse d'affronter : ordre 9 : posé » ; bandeau « Henry remporte le duel » ; plus
    d'icône de combat, la vue tourne librement ; chez le pair : IsInCombatMode faux, en_bataille faux) ; le lit du
    Directeur laissé libre la nuit (4 hommes aux lits des tentes, 2 sans lit) ; le secours par la téléportation du jeu
    (4 téléportations « ordre 10 : posé », puis « tient le geste », plus aucun « figé » ; posture vue au journal
    seulement, sauf Albrecht, debout, sans posture en T) ; chez le pair : le palier payé (les forts mieux habillés),
    le nom de l'adversaire et « vers le sud-est » ;
  - reste chez le pair : la garde de nuit (CampPatrollers vide : sa nuit prenait ses gardes dans la garde de jour de
    l'ancien mod, absente dans notre monde ; les hommes sans lit restent « sommeil sans but »).
  - fin de séance : JoVenGer a choisi (question du pair) de GARDER ce socle pour tous les jours : sa version est
    désormais 29ad4f6 (pak du 19/10, 20:09) ; retour arrière : Scriptorium_securite61019_193225_498548_seance_du_socle.
    Vérifié : Partie 1 identique, « Continuer » sur playline1utosave1912, veilleur en marche, verrou qui refuse.
- **Vérification complète de SA sauvegarde (19/10 au soir, accord direct de JoVenGer, copie de playline1utosave1912 dans
  playline2, jamais sauvée, rangée jeu ouvert ; rien installé : vers_partie_d_essai.ps1 -SansInstallation)** :
  - au journal : tous les morceaux prêts, réglages sans refus, camp redressé (0 manquant), Directeur à son lit, aucune
    erreur ; chez le pair : 16 hommes, colonel Havel le Borgne, caisse 606,78, garde de jour à 6 de quart, ronde de jour,
    Directeur, marque, caisse d'Henry, camp adopté, dialogues justes ;
  - à l'image (9 h) : cabane, tente du Directeur, tour de guet, forge, râteliers ; « Le Directeur » au-dessus de lui ;
    l'écu bleu du camp SUR LA CARTE, à part d'Henry une fois éloigné (la correction de la répétition 5 tient) ;
  - **MANQUE CHEZ NOUS, à faire** : la nuit, aucun homme n'a de lit (10 « sommeil (nil) : sans but » ; Directeur à son
    lit). Sur un camp adopté, camp.places_libres rend une liste vide (voulu), et camp.place_pour n'accepte qu'un nom
    du plan, but_de() ne vise que les objets du plan : les 11 lits hauts et les 4 tentes achetés par JoVenGer à
    l'Aménagement de Scriptorium ne servent à personne. À faire : une place de Scriptorium donnée par l'objet du jeu
    (nom d'entité, classe Bed, sorte, tente), la liste venant du pair ;
  - à surveiller (pair) : des hommes serrés contre le mur de la cabane (un point de métier ou de passage trop près).
- Reste à voir en jeu : le remplacement d'une pièce à la forge ; un homme au bain (déshabillé, puis rhabillé) ; les hommes
  libres au travail (forge, armurier, fouille, portage, chantiers).
- Caméra du dialogue : PAS un défaut (vu par JoVenGer le 18/10) : quand l'homme parle, c'est lui qu'on voit ; mes
  captures tombaient sur le menu des choix, où le jeu filme Henry. Les essais ci-dessus étaient sans objet.
- Protocole de fenêtre : « fenêtre ouverte » au pair à chaque fin de séance, « fenêtre rendue » avant de relancer.
- Liste de JoVenGer : `a_verifier_par_jovenger.md`.

## 7. Ce qui reste à faire
Voir `docs/socle/plan_d_action.md` : 1. comportement des personnages (priorité) ; 2. nos âmes et personnages ;
3. dialogue du Directeur et Gestion du camp à l'écran ; 4. quête de fond ; 5. voix et icônes ; 6. essais en jeu restants ;
7. fin du chantier (contrôle strict, scellés, langues, bascule sur ordre).

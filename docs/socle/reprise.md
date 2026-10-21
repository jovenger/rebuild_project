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
    désormais 29ad4f6 (pak du 19/10, 20:09) ; retour arrière : Scriptorium_securite\20261019_193225_498548_seance_du_socle.
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
- **Séance des lits achetés (19/10 au soir, accord direct de JoVenGer, copie de autosave1912 dans playline2, jamais
  sauvée ; socle ce77192, Scriptorium du pair d604c5b1 puis 37416824 ; remis par le pair)** :
  - « Camp : 16 place(s) déclarée(s) par Scriptorium », une fois (les 4 tentes des hommes, 4 lits chacune ; les 11
    lits hauts sont réservés au personnel de JoVenGer) ; zéro « sommeil : sans but » ; la liaison reconnaît les
    ScriptoEditeur_*_so comme des lits du jeu (GroundBed, Bed_1Place_Low, type so_bed) ;
  - premier passage : un homme oscillait entre deux lits et un lit était visé par deux hommes (la règle de Scriptorium
    rechoisissait la place à chaque ordre) ; corrigé chez le pair (lit gardé pour la nuit, 37416824) ; second passage :
    chacun son lit, aucun doublon, mêmes lits sur cinq relevés (pair) ;
  - couchés : mesuré par le pair (tête à +0,27 m pour les 10 dormeurs, +1,5 m pour les 6 rondiers) ; à l'image, une
    tente vide (la 6 : 16 lits pour 10 dormeurs) et le nom d'un dormeur à travers la toile ; la ronde de nuit tourne ;
  - non vu : le lever du matin (jeu fermé avant le saut du pair).
  - INSTALLÉ pour tous les jours (accord direct de JoVenGer, 19/10, 23 h 06) : socle ce77192 + Scriptorium 37416824 ;
    séance « gardée » ; retour arrière : Scriptorium_securite\20261019_230515_819024_seance_du_socle. Vérifié : Partie 1
    identique, « Continuer » sur playline1utosave1912, veilleur en marche, verrou qui refuse.
- **Vérification de l'installation des lits (19/10 vers 23 h 15, demande de JoVenGer, accord direct, copie, jamais
  sauvée, remis par le pair)** : la nuit juste (16 lits déclarés, 10 dormeurs chacun le sien, couchés, 0 erreur) ; le
  lever juste au journal (aucun lit redemandé) et à l'image (personne couché en plein jour ; la mesure du pair par l'os de
  la tête est fausse pour un homme loin d'Henry) ; DÉFAUT CHEZ NOUS : le colonel presque nu et figé (la file d'habillage
  repartait toujours du début ; corrigé au banc, fiche 13, non installé) ; chez le pair : l'oscillation de Bohuslav
  (une file d'achat de Scriptorium).
  - INSTALLÉ pour tous les jours (accord direct de JoVenGer, 19/10, 23 h 31) : socle e0550ec (la file d'habillage) ;
    séance « gardée » ; retour arrière : Scriptorium_securite\20261019_233035_871440_seance_du_socle. Vérifié : Partie 1
    identique, « Continuer » sur playline1utosave1912, veilleur en marche, verrou qui refuse. Reste à voir en jeu :
    le colonel habillé après un chargement, et son geste à la marmite (séance de sonde proposée par le pair).
- **Séance de sonde du matin (19/10 vers 23 h 40, accord direct de JoVenGer, copie, jamais sauvée ; la garde du pair
  refusée par son système, la mienne posée : elle a vu « playline2 » au chargement)** : le colonel « équipé » dès les
  premiers battements (au journal) ; à l'image, Matěj torse nu après un affrontement (corrigé au banc : « à rhabiller
  (fin d'affrontement) », non installé) ; deux hommes encore collés au mur de la cabane ; chez le pair : la tâche
  « hors cabane » de son moteur du camp (pose et retire un geste huit fois en sept secondes), cause probable de
  l'hésitation du matin et des hommes collés à la cabane.
- **Séance de preuve commune (20/10 vers 0 h, accord direct de JoVenGer, copie, jamais sauvée ; tour complet d'une
  journée par sauts d'horloge ; liste unique des problèmes, à la demande de JoVenGer : « arrête de tourner en rond »)** :
  juste : 0 erreur, 0 refus, 16 lits, 0 doublon, colonel équipé, points d'activité hors de la cabane (correction du
  pair) ; chez nous : le Directeur envoyé aux places du plan (dans la cabane) sur un camp adopté, des hommes collés à
  lui contre le mur (corrigé au banc : « remplace », fiches 03 et 06, non installé) ; chez le pair : l'alternance
  ronde/sommeil de la garde composée pendant la veillée ; et chez nous, un mené sans plus aucune tenue recevait encore un
  ordre (« introuvable ») : corrigé au banc (lâché ou tenues échues : plus mené, sans ordre ; essai), non installé.
- **Séance de preuve unique (20/10, 0 h 30 à 1 h 10, accord direct de JoVenGer, copie, jamais sauvée ; trois passages)** :
  au dernier passage, TOUT JUSTE : mur ouest de la cabane vide à 8 h et pendant deux minutes ; personnel sur les bancs
  de l'Aménagement, forgeron à la forge ; Directeur à sa tente et à son lit (« remplace ») ; 16 lits + 3 remplaçants
  déclarés ; 0 erreur, 0 refus, 0 introuvable, 0 sommeil sans but ; colonel équipé. Corrigé en route : chez nous, le
  personnel mené n'était jamais secouru (b9564e9) ; chez le pair, les places du personnel et des hommes rentrés d'un
  métier dans la cabane, la garde composée par l'énergie, la forge de Kunrát. À installer : socle b9564e9 (avec 8c5b6ea,
  87b9c14, d50c70a), Scriptorium du pair 63ee0241, sur l'accord de JoVenGer.
  - INSTALLÉ pour tous les jours (accord direct de JoVenGer, 20/10, 1 h 25) : socle b9564e9, Scriptorium 63ee0241 ;
    retour arrière : `Scriptorium_securite\20261020_012413_521706_seance_du_socle`. Puis, sur sa demande : tout enregistré
    et l'ordinateur éteint par le pair.
- **Pour la prochaine session** : rien d'ouvert chez nous. À voir en jeu un jour : le lever du matin avec les lits ; la
  posture en T du colonel au geste de la marmite (non revue) ; l'idée de rendre la cabane obstacle de navigation (pair,
  plus tard).
- **20/10, reprise du travail (consigne de JoVenGer, confirmée directement par question à cocher : prendre d'office l'option
  recommandée pour les séances sur copie et l'installation, avec mise de côté et retour arrière ; interdits sans lui :
  charger sa partie, éteindre l'ordinateur, toucher sa bourse, enlever ses tentes)** :
  - sièges déclarés (demande du pair, les bancs au repas) : rien à changer chez nous ; le repas et la veillée prennent
    déjà un siège déclaré (`place_pour(id, "siege")` → `places_libres("siege", "hommes")`, sur un camp adopté) ; essai
    ajouté (chacun le sien, à la place de l'objet ; sans siège, au feu).
  - « tous en relève » (décision de JoVenGer transmise par le pair, choix recommandé pris d'office) : interrupteur éteint,
    aucun lit réservé à l'embauche ; un lit réservé est rendu une fois (fiche 18).
  - Séance de preuve (20/10, 9 h 30 à 9 h 50, copie playline2, jamais sauvée ; d'office) : socle e99eaad + Scriptorium
    093546e2 ; 0 erreur, 0 refus ; rondins en cercle aux 4 feux, hommes assis à la veillée ; le colonel n'est plus figé
    à la marmite ; lits partagés en relève sans collision ; figés relancés par le gardien. Restes chez le pair : son
    pugilat (« scripto_prendre_epee ») pris et lâché contre notre repas, ses temps libres qui tiennent les hommes à
    midi, la tour de guet, les sorties de métier à pied (à cheval, consigne du 16/10). Fermé sans sauver, playline1
    intact.
  - INSTALLÉ pour tous les jours (d'office, consigne du 20/10) : socle e99eaad, Scriptorium 093546e2 ; retour arrière :
    `Scriptorium_securite\20261020_095256_783460_seance_du_socle`.
  - Sommeil d'un mené sur un lit nommé (demande du pair, le personnel debout la nuit) : `{ activite = "sommeil", lit =
    "<entité>" }` par `tenir_un_personnage`, règle `sommeil` (fiche 18) ; essai (vérifié qu'il échoue sans).
  - Séance regroupée (20/10, 10 h 10 à 11 h 30, copie playline2, jamais sauvée, quatre passages ; d'office) :
    - vu juste : le personnel couché chacun dans son lit réservé (les 4 femmes des bains et le coursier dans des lits
      d'hommes libres, faute de tente « femmes ») ; repas de midi assis aux bancs ; veillée sur les rondins ; tour de
      guet tenue par un archer engagé dans la copie (équipé à son lever, flèches comprises) ;
    - corrigé chez nous : lit nommé à plus de 100 m du camp refusé (8ba1040 : trois gens envoyés à 2 km, cause chez le
      pair) ; rangs autour d'un point derrière le premier, plus à travers le feu (46ec2e8) ; gardien : figé au-delà
      de 3 m, la marche du jeu s'arrêtant à 2,2-2,5 m (bbbf563, mesuré par les sondes du pair ; non revu en jeu) ;
    - reste (pair, plus tard) : au lever, des hommes bloqués par les objets du camp de Scriptorium, absents du maillage
      de navigation (feu #23, rondins, foyer #26), posés par le secours hors de la vue d'Henry ;
    - à dire à JoVenGer : avec 16 hommes (17 dans la copie) en relève plus le personnel dans des lits d'hommes, il manque des lits la nuit
      (un homme « sans but » à 4 h 50) : une tente des hommes de plus (4 lits) suffirait.
  - INSTALLÉ pour tous les jours (d'office, consigne du 20/10) : socle bbbf563, Scriptorium 1d4d5705 ; retour arrière :
    `Scriptorium_securite\20261020_101103_974149_seance_du_socle`.
  - Sorties à cheval (règle de JoVenGer du 16/10 : qui sort du camp part et revient à cheval ; mécanique chez nous,
    décision chez le pair) : forme `suivre` + `vers` + `a_cheval` (fiche 18) ; corrigés : le cheval d'un mené retiré
    à chaque battement (d55f173), un mené lâché en selle garde son cheval jusqu'à sa descente (1b8b820, non vu en jeu).
    Séance du 20/10 (11 h 40 à 12 h 50, copie, jamais sauvée ; d'office) : vu juste : aller et retour à cheval des deux
    bûcherons et du porteur d'eau, départ du coursier vers le marché ; une monte manquée rattrapée ; chevaux retirés
    après la descente ; 0 erreur, 0 refus. Reste : deux chevaux nés sous les yeux d'Henry (aucune place cachée libre ;
    chez nous, plus tard) ; le retour du coursier non vu ; au lever, 5 hommes téléportés vers le feu (le foyer #26 sur
    leur chemin : le pair déplacera le point du lever).
  - INSTALLÉ pour tous les jours (d'office) : socle 1b8b820, Scriptorium 1d62c129 ; retour arrière :
    `Scriptorium_securite\20261020_114003_726730_seance_du_socle`.
  - Lever (séance courte, 20/10, copie, jamais sauvée) : le point du lever déplacé chez le pair (78a5c99e) : 4 hommes
    téléportés au lieu de 5, arrêtés au feu de camp #23 entre les tentes et le foyer ; deuxième essai par le placement,
    approche arrêtée (règle anti-boucle). Cause : les objets de l'Aménagement hors du maillage de navigation. Piste du
    pair (sonde à faire) : Properties.AI.bUsedAsDynamicObstacle (déclaré seulement par RigidBodyEx.lua dans
    Scripts.pak) sur une classe à lui, et les variables du moteur wh_ai_ObstaclesAddToCollisionAvoidance,
    ai_EnableORCA, ai_AdjustPathsAroundDynamicObstacles (chaînes de WHGame.dll). Rien chez nous.
    Sonde du pair (copie) : les quatre variables déjà à 1 ; #23 et #26 marqués obstacles : 6 téléportés (pire) ; le
    pair arrête (trois essais). Notre essai (copie, d'office) : sans aucune relance du gardien
    (`hommes.fige_relances_max = 0` par le fichier, retiré après) : 5 téléportés, autant qu'avec : les relances ne sont
    pas en cause ; nous arrêtons aussi. Reste la navigation : le feu de camp #23, posé entre les tentes et le foyer, à
    déplacer dans l'Aménagement (le pair le dit à JoVenGer).
  - Réglages par fichier corrigés (bc130f6, vu en jeu sur la copie le 20/10) : le fichier ne touche qu'aux valeurs
    qu'il nomme ; avant, poser une seule valeur remettait tout le catalogue et effaçait six coupures de Scriptorium.
  - INSTALLÉ pour tous les jours (d'office) : socle bc130f6, Scriptorium 78a5c99e ; retour arrière :
    `Scriptorium_securite\20261020_132037_061740_seance_du_socle`.
  - Raid sur copie (20/10, 14 h 10 à 14 h 45, d'office) : une bande ne faisait vivre qu'UN ennemi depuis le 18/10 (la
    règle de l'âme unique refusait les ennemis qui partagent l'âme de leur sorte) ; corrigé (adec9ee, contrôle au banc)
    et vu : 6 ennemis au contact, alerte, femmes à l'abri, Directeur en retrait (décision du pair par
    `directeur.activite`), victoire coûteuse, 0 mort, 2 survivants en fuite. Deux fouilles en même temps (la nôtre et
    le pillage du pair) : notre fouille reste maîtresse, le temps libre du pair lui cède (d0c50d11, non vu) ; service
    proposé au pair (`bataille.compter_comme_fouille`) pour qu'un corps pris par son « Loot » ne soit pas revisité.
  - INSTALLÉ pour tous les jours (d'office) : socle adec9ee, Scriptorium 067c8106 ; retour arrière :
    `Scriptorium_securite\20261020_141125_658071_seance_du_socle`.
  - Puis INSTALLÉ (« garder » du pair, 15 h 09) : socle e4f2b3f (compter_comme_fouille ; fouille vidée par la charrette,
    vue en jeu), Scriptorium e0d1316d ; retour arrière `Scriptorium_securite\20261020_144641_007394_seance_du_socle`.
  - Séance sur copie (20/10, 15 h 16, dccf77c, « remise » : non gardée) : vu juste : un homme assis se relève et marche
    (61 à 70 m, par la porte) ; 4 corps sur 6 portés au dépôt. Défauts trouvés et corrigés ensuite, au banc seulement
    (non vus en jeu) : le secours punissait les détours (2f2b2c8 : un homme qui marche n'est jamais bloqué ; borne
    secours_detour_max_s ; pas de pose sous les yeux d'Henry là où il disparaît) ; deux porteurs causaient au lieu de
    porter (3a7dd26 : une parole non urgente attend l'arrivée) ; le même geste déplacé ne redonnait aucun ordre
    (1f355fa : le point d'une tenue entre dans la signature). À installer à la prochaine séance : 1f355fa (contient
    372a00f, dccf77c, 2f2b2c8, 3a7dd26).
  - Séances sur copie suivantes (20/10, 15 h 43 et 16 h 12, remises) : la marche rejouée empêchait la posture vers un
    objet (lit, siège, poste de travail : le Move n'y réussit jamais) ; corrigé par l'arrivée LUE (ec3fd9c,
    liaison.pres_de_la_place, seuil place_arrivee_cm) ; vu : 8 hommes sur 10 couchés près d'Henry (la mesure par la tête
    ne vaut rien loin d'Henry). Doublons de lits (la liste qui change entre deux ordres) : lit de la nuit gardé (90beb30,
    non vu). Départ depuis Loot à genoux : environ 7 s dans la branche 22, arbre non bloqué (sonde du pair) ; compteurs
    de sonde ajoutés (191604f) pour trouver l'étape lente. À installer à la prochaine séance : 90beb30.
  - Séance sur copie (20/10, 16 h 34, e41be67, remise) : vu juste : la nuit, 10 hommes couchés chacun dans son lit,
    0 doublon ; repas de midi, 6 assis à leur place, 0 doublon ; personnel à 0,0 m de son lit. Sonde du départ depuis
    Loot : relève 2,5 s, puis 4 à 5,5 s avant le premier pas (le WaitAction attendait la fin normale du geste). Corrigé
    par l'urgence du relever (336610e : UrgencyDecorator sous $urgence_relever, valeur de hommes.cerveau, rapide par
    défaut ; fiche 12).
  - Séance sur copie (20/10, 16 h 48, 336610e) puis INSTALLÉ pour tous les jours (« garder » d'office du pair, consigne
    de JoVenGer) : socle 336610e, Scriptorium 0e35a4a9 ; retour arrière
    `Scriptorium_securite\20261020_164827_733945_seance_du_socle`. Vu juste : le lever à 5 h, les 10 hommes à leur point
    (1,8 à 2,5 m), aucun secours ni figé ; le relever en rapide : premier pas 3 à 4 s après le changement de but (2 s de
    battement, relève 0,5 s, puis le Move), contre 8,9 à 11 s avant ; instantané non essayé (rapide suffit). La branche
    21 (poste de travail) ne sert pas dans sa partie. À revoir sans saut d'horloge : 5 sortants « essai 1 sur 3 : cheval
    retiré » dans le même battement juste après un saut de 6 h à 10 h, puis partis au second essai (non vu sans saut,
    rien corrigé).
  - Séance J sur copie (20/10, 18 h 51, socle 336610e, la journée entière de 4 h 50 à 22 h 45, remise ; deux
    sauvegardes automatiques du jeu faites sur la copie, rangées). Relevés et corrections au banc seulement (non
    installées, non vues en jeu), chacune avec l'accord du pair :
    - 75dd935 : le gardien ne juge un homme que sur l'ordre reçu (20 faux figés sur 39 : chargement, lever, place changée
      par Scriptorium ; il passait devant le battement, relançait deux fois puis laissait au secours).
    - d2b02a2 : les gestes du Directeur (directeur.activite peut rendre un geste à un point, joué comme pour un homme ;
      chaque ordre du Directeur porte le temps de marche).
    - dd17a9d : les paroles du personnel mené (dire_une_replique_du_personnage, conversation_du_personnage).
    - a66cbf0 : le tir à la cible (tenue « tir », branche 24 d'après prepadeni.xml et archery.xml ; carquois réel, règle
      de JoVenGer du 26/09 ; deux fermantes du jeu admises au contrôle d'absence, 38, revue).
    - 29ed6c4 : les montes depuis le lit ou un banc (branches 19 et 20 sous l'urgence ; les 5 premières montes ratées
      partaient d'un homme couché ou assis).
    - 299ddf4 : jamais de cheval né sous les yeux d'Henry (7 sur 21) : l'homme part à pied, le cheval naît hors de vue ;
      au journal, « hors de la vue d'Henry » remplace « vu d'Henry : oui/non ».
    - 457cb10 : se relever avant d'aller s'asseoir ou se coucher (branches 10 et 11 ; 19 vrais figés, presque tous sortis
      d'un geste de Scriptorium). À mesurer en J2 : la sortie de eating_standing et scripto_getMash en rapide puis en
      instantanée (urgence_relever = 3).
    - À installer à la prochaine séance (J2) : 457cb10.
- Reste à voir en jeu : le remplacement d'une pièce à la forge ; un homme au bain (déshabillé, puis rhabillé) ; les hommes
  libres au travail (forge, armurier, fouille, portage, chantiers).
- Caméra du dialogue : PAS un défaut (vu par JoVenGer le 18/10) : quand l'homme parle, c'est lui qu'on voit ; mes
  captures tombaient sur le menu des choix, où le jeu filme Henry. Les essais ci-dessus étaient sans objet.
- Protocole de fenêtre : « fenêtre ouverte » au pair à chaque fin de séance, « fenêtre rendue » avant de relancer.
- Liste de JoVenGer : `a_verifier_par_jovenger.md`.

## 6 nonies. Où reprendre (pause du 20/10/2026 au soir, demandée par JoVenGer : PC éteint)
- Installé pour tous les jours (« garder » d'office après J2) : socle 457cb10 + Scriptorium fd7e1961 ; retour arrière
  `Scriptorium_securite\20261020_201702_763534_seance_du_socle`. playline1 intacte (146 fichiers, 19/10 16:59:16).
- J2 vue juste (le pair) : lever sans faux figé, départs à cheval depuis le lit du premier coup et hors de vue, tir
  (l'arc levé), crieurs, gestes du Directeur (feux), veillée assise, nuit couchée sans doublon.
- En cours, rien corrigé :
  - **16 vrais figés vers un geste de Scriptorium** (journal J2 : 0 faux ; 14 vers la branche 22, venant de l'exercice
    ×4 (Jindřich), de scripto_getMash ×6, de waiting_armsCrossed ou prendre_epee ×3, ronde, corvée, camper_snooze ;
    2 vers un siège depuis getMash ; 1 vers l'entraînement). Hypothèse : certains gestes et l'exercice ne se coupent pas
    à l'urgence rapide.
  - **À lire en J3** : à un « Gardien : … figé … relancé (1 sur 2) » vers un geste, les sondes de la branche 22
    (`scriptorium_sonde_entree`, `_releve`, `_marche` par `Scriptorium.jeu.lire_le_cerveau`), deux fois à 2 s :
    entrée sans relève = sortie de l'ancien geste ; relève sans marche = le Move ne part pas ; marche sans avancer = le
    chemin. Et la mesure du pair : départs depuis eating_standing et getMash en rapide puis en instantanée
    (`Scriptorium.hommes.cerveau.urgence_relever = 3`). Décider sur la mesure.
  - **La mort hors bataille, à provoquer en J3** : aucune détection trouvée dans le code (seule la bataille lit
    personnage_mort) ; un homme tué hors bataille resterait dans la Compagnie. Si c'est confirmé : l'ajouter au battement.
  - **Les déclencheurs du jour** (pour aller plus vite, dans des copies) : `docs/socle/declencheurs.md` (mission, camp,
    convoi, désertion, mort, renvoi, blessure ; jamais lancés).
- Journaux gardés (brouillon de la session, hors dépôt) : kcd_seance_J.log, kcd_seance_J2.log.

## 6 decies. Où reprendre (21/10/2026, vers midi, après J18)
- Installé pour tous les jours (« garder » après J18, demandé par JoVenGer via le pair) : socle def2eae + Scriptorium
  aee2a75b ; retour arrière `Scriptorium_securite61021_054840_948806_seance_du_socle`. playline1 intacte
  (146 fichiers, 19/10 16:59:16), playline0 intacte (178).
- Commits du 21/10 (depuis 0040dde) : 621abf3 blessure visible et étendue du camp ; 38a8bc9 fouille d'un corps disparu ;
  7b270a7 service `hommes.poser` ; 9731a8a cavalier au bord du camp ; a9b1cc9 interlocuteur visé ; d1b5bd4 paroles du
  Directeur ; da57e83 cadre de visée ; 1b7b90c provocations des pillards ; a6838f7 siège du personnel ; 09d847d
  « Rentrez tous au camp » ; def2eae essai du lit du personnel (sans code).
- Vu juste en jeu (le pair, J11 à J18) : dialogue lié à l'homme visé, cadre de visée, provocations, dames assises,
  « Rentrez tous au camp » (réplique 44, escorte lâchée, chacun à sa place), coucher des dames sans boucle (la boucle
  venait de la prise de Scriptorium, corrigée chez lui en aee2a75b).
- Abandonné à la demande du pair : « Où en es-tu ? » (le statut existe sous « Discutons un peu ») ; rustine gardée dans le
  brouillon de la session, hors dépôt.
- « relance de « camp » en erreur : registre : case inconnue : v_ScriptoBesoins » à chaque chargement (J12 à J19) :
  défaut du registre (une case reprise de la sauvegarde pas encore déclarée), la relance du camp était sautée ;
  corrigé en 17561a9 (fiche 01), vu juste en J20 (« Camp : redressé, 0 objet(s) reposé(s), 0 manquant(s) », plus
  aucune relance en erreur).
- Installé pour tous les jours depuis J20 (« garder » demandé au pair) : socle 17561a9 + Scriptorium ecacd021 ; retour
  arrière `Scriptorium_securite61021_101018_035599_seance_du_socle`. playline1 et playline0 intactes.
- J21 (décisions de JoVenGer de midi, chez Scriptorium : garnison du Directeur au tiers, deux gardes des bains sous
  25 hommes, prime du contrat d'Henry dans le partage 40/60) : vu juste par le pair ; gardé pour tous les jours :
  socle 17561a9 + Scriptorium 1b74decd ; retour arrière `Scriptorium_securite61021_120151_274126_seance_du_socle`.
- J22 et J23 (vérifications restantes du pair ; J22 : expédition 4 contre 4 puis 3 contre 4, rien d'anormal côté socle) :
  gardé pour tous les jours : socle 17561a9 + Scriptorium 5bc3c579 ; retour arrière
  `Scriptorium_securite61021_121136_661933_seance_du_socle`.
- J24 (l'inspection du colonel, matin et soir, chez Scriptorium ; trois défauts corrigés chez lui : mesure avant la
  déclaration des places, tournée du soir vide, colonel parti à cheval hors du camp, réglé avec
  `hommes.etendue_du_camp()` qui rend (centre, rayon)) : vu juste ; gardé pour tous les jours : socle 17561a9 +
  Scriptorium 0b5d6400 ; retour arrière `Scriptorium_securite61021_163948_817892_seance_du_socle`.
- J25 à J29 (le camp qui tourne seul, 30 embauches d'un coup, relevés du journal toutes les 10 minutes) ; commits :
  17561a9 puis ff70204 (embauchés jamais venus : reprise au battement, 33 places au feu), 9ce0348 (ordre sans but :
  activité 0 ; ronde à vide arrêtée), e54d043 (un assommé n'est ni figé ni bloqué), 455a71e et 35d2b48 (dormir au sol
  près du feu, décision de JoVenGer : posture QuestHunterInjuryIdleLie, jouée sans objet, vue couchée en jeu ; un nom
  réglable par le fichier), 9a845d1 (hommes.sieges_occupes), 61c1ebb (le siège de l'homme gardé pendant le repas et la
  veillée). Leçon : « tient le geste » au journal ne prouve que l'ordre posé, pas la posture jouée (fiche 15).
- Gardé pour tous les jours après J29 : socle 61c1ebb + Scriptorium 340a9c26 ; retour arrière
  `Scriptorium_securite61021_172541_788513_seance_du_socle`.
- Journaux gardés (brouillon de la session, hors dépôt) : kcd_seance_J16.log à kcd_seance_J18.log.

## 7. Ce qui reste à faire
Voir `docs/socle/plan_d_action.md` : 1. comportement des personnages (priorité) ; 2. nos âmes et personnages ;
3. dialogue du Directeur et Gestion du camp à l'écran ; 4. quête de fond ; 5. voix et icônes ; 6. essais en jeu restants ;
7. fin du chantier (contrôle strict, scellés, langues, bascule sur ordre).

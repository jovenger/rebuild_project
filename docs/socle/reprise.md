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
  d'essai (27 ordres). Démarrage : `socle\pak\Scripts\Mods\scriptorium_socle.lua`.
- **Fiches 00 à 11** dans `docs\socle\fiches\` ; **02 à 11 validées par JoVenGer** (14 et 15/10, questions à cocher).
  Changements qu'il a demandés : livre de comptes à 50 lignes, deux rations par homme et par jour, butin doublé, corps
  ennemis laissés à fouiller une journée, enceinte de 20 m (22 pans), l'onguent soin léger, réglages par fichier.
- **Banc** : `essais\tout_verifier.py` — syntaxe Lua 5.1, 1 701 vérifications sur un faux jeu, ordres par fichier,
  liaison sur un faux moteur, réglages par fichier (outil, liaison, installateur), noms interdits, 80 textes, manifeste,
  contrôle d'absence contre les empreintes d'Alex (0 partout). Tout passe.
- **Outils** : `noyau\installer.py` (garde le fichier de réglages), `outils\ordonner.py` (ordres au poste),
  `outils\regler.py` (réglages : `chemin=valeur`, `--retirer`, `--voir`, `--liste` des 166 valeurs),
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

## 7. Ce qui reste à faire
Voir `docs/socle/plan_d_action.md` : 1. comportement des personnages (priorité) ; 2. nos âmes et personnages ;
3. dialogue du Directeur et Gestion du camp à l'écran ; 4. quête de fond ; 5. voix et icônes ; 6. essais en jeu restants ;
7. fin du chantier (contrôle strict, scellés, langues, bascule sur ordre).

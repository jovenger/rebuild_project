# Essai en jeu du socle (sur le PC de JoVenGer)

Rappel : rien de tout ceci ne touche au Scriptorium actuel, à son git ni à ses trois mods. Le socle s'installe dans `Mods\scriptorium_socle`, à part.

## 1. Préparer le PC (une fois)
1. Cloner ce dépôt : `git clone https://github.com/jovenger/rebuild_project "C:\Users\maste\Desktop\rebuild_project"` (décision D9), puis se placer sur la branche `ccr-c18b8b50-tespti`.
2. Installer le banc : `py -3.13 -m pip install lupa`.
3. Vérifier : `py -3.13 essais\tout_verifier.py` doit finir par « tout passe ».

## 2. Installer le socle dans le jeu
```
py -3.13 noyau\installer.py --jeu "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
```
- L'installateur relance la vérification, met de côté l'ancien mod d'essai dans `securite\`, puis écrit `Mods\scriptorium_socle` (manifeste, `Data\scriptorium_socle.pak`, `Localization\French_xml.pak`).
- Il refuse tout autre chemin.

## 3. Avant de lancer le jeu
- Liste des mods (décision D10, vérifié le 14/10 dans le wiki de Warhorse et dans `kcd.log`) : `Mods\mod_order.txt` choisit les mods chargés ; un mod absent de la liste n'est pas chargé. Pendant l'essai, la liste ne contient que `scriptorium_socle` ; l'original est copié dans `securite\` avant, et remis à la fin de l'essai. Ne jamais renommer ni déplacer les dossiers des trois mods.
- Lancer le jeu avec l'option `-devmode`, sans laquelle la console ne s'ouvre pas : `steam.exe -applaunch 1771300 -devmode`.
- Le « veilleur du jeu » du Scriptorium actuel (tableau ouvert au lancement du jeu) est arrêté pendant l'essai, à la demande de JoVenGer, et relancé à la fin ; son raccourci de démarrage n'est pas touché.
- Jouer sur une **partie d'essai neuve**, jamais sur la partie actuelle.

## 4. Ce qu'il faut voir, dans l'ordre
1. Au lancement, dans le journal du jeu (`kcd.log`, à la racine du jeu, réécrit à chaque lancement) : `[Mod] 1 mods enabled`, `'mods/scriptorium_socle' is not limited to any game version, it will be enabled`, `Loading lua init script for mod scriptorium_socle`, `Loading localization patch 'Localization\text_ui__scriptorium_socle.xml'` sans erreur « hash clash » ; puis `[Scriptorium] Socle : morceau « bandeau » prêt`, puis `registre`, `coffre`, `camp`, `hommes`, `bataille`, `directeur`, `enceinte`, `atelier`, `patrouilles`, `discipline`, `poste`, puis `Socle 0.1.0 : 12 morceau(x) prêt(s), 0 en panne`.
2. En entrant dans la partie : « Le socle de Scriptorium est prêt. » à l'écran.
3. Les essais se lancent par ordres, sans console : `py -3.13 outils\ordonner.py --jeu "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2" <commande>` écrit `Mods\scriptorium_socle\ordres.lua`, que le poste relit toutes les deux secondes en partie (la console ne s'ouvre pas sur le PC de JoVenGer : ², ù et * essayés le 14/10, avec `-devmode`). Avec Henry debout sur un terrain plat et dégagé, au moins 300 groschen sur lui :
   - `scriptorium_essai_bandeau` → cinq annonces ; à l'écran, dans l'ordre : « Essai : une alerte, qui passe devant. », « Essai : une nouvelle ordinaire. », « Essai : plusieurs hommes sont arrivés au camp. » ;
   - `scriptorium_essai_registre` → « Essai : le registre a été écrit puis relu. » et, au journal, `appels = 1` ; relancer : `appels = 2` ;
   - `scriptorium_essai_camp` → un camp se dresse autour d'Henry (feu, 4 sièges, 3 tentes, 5 paillasses, coffre) ; « Le camp est dressé. » ; au journal, `camp fondé = true, lits = 5, sièges = 4` ;
   - `scriptorium_essai_coffre` → au journal, `sorts = true, true, true, true, false ; solde = 70, vivres = 6, lignes = 4` ; la bourse d'Henry a baissé de 100 ; à l'écran, « Le coffre du camp ne peut pas payer : il manque des groschen. » puis « Essai : le coffre a encaissé, payé et refusé comme il faut. » ;
   - `scriptorium_essai_directeur` → « Le Directeur a pris ses fonctions. » et, au journal, les entrées de la Gestion du camp avec « possible » ou « impossible (raison) » ; `scriptorium_gestion_rapport` → le rapport au journal ;
   - `scriptorium_essai_hommes` → au journal, `engagés = homme_1, homme_2, homme_3 ; total = 3, présents = N` ; à l'écran, « Un homme a rejoint la Compagnie : Jan Kladivo » puis les deux suivants. Attendu à ce stade : `présents = 0` et « Venue impossible … pas d'âme pour le rôle » tant que les âmes ne sont pas renseignées (V16) ;
   - `scriptorium_essai_enceinte` → au journal, `sorts = true, true ; niveau = 2, porte = ouverte` ; à l'écran, « La palissade est dressée autour du camp. » puis « Les tours de guet sont bâties. » ; seize pans, une porte, deux tours posés autour du camp ;
   - `scriptorium_essai_camp_agrandir` → deux tentes de plus, « Le camp s'est agrandi. » ;
   - `scriptorium_essai_patrouille` → « La patrouille est partie. » ; deux heures de jeu plus tard, un compte rendu ;
   - `scriptorium_essai_bataille` → un quart d'heure de jeu plus tard, « Une bande approche du camp : 5 hommes » puis, attendu à ce stade, la règle tranche faute d'âmes ennemies (V18) : une issue à l'écran et, s'il y a butin, « Butin partagé, au coffre : … » ;
   - `scriptorium_essai_discipline` → au journal, la réputation (50 au départ) et les fautes à juger, s'il y en a eu à l'aube ;
   - `scriptorium_essai_camp_lever` → tout disparaît, « Le camp est levé. » ;
   - `scriptorium_bilan` → résumé au journal.
4. Sauvegarder la partie d'essai, fermer le jeu, relancer, recharger, puis `scriptorium_essai_registre` : si `appels` repart à 1, le mécanisme de sauvegarde n'est pas encore le bon (attendu à ce stade : la liaison garde en mémoire seulement, V4).

## 5. À vérifier en jeu, et à me rapporter
| N° | Question | Où ça se décide |
|---|---|---|
| V1 | Le texte s'affiche-t-il ? Où, et de quel aspect (bande noire en bas ou non) ? | `liaison.afficher` |
| V2 | Le texte est-il traduit (clé `@ui_scriptorium_…` remplacée par le français) ? Premier lancement (14/10) : `text_ui_scriptorium_socle.xml` n'est pas chargé ; le jeu ne prend comme textes de mod que `<nom>__<modid>.xml` (deux traits bas), d'où `text_ui__scriptorium_socle.xml`, gardé par `tout_verifier.py` | `socle/textes/fr`, installateur |
| V3 | Les commandes de console existent-elles (`System.AddCCommand`) ? Comment ouvrir la console ? 14/10 : elle ne s'ouvre pas (², ù, * ; `-devmode` actif). Voie de remplacement : ordres par fichier ; au journal, `Poste : fichier d'ordres trouvé à …` dit quel chemin `loadfile` atteint, et `Poste : veille …` toutes les 30 s dit si les minuteries survivent au chargement de la partie | `liaison.commande`, `liaison.lire_ordres` |
| V4 | Quel appel garde une chaîne dans la sauvegarde et la rend au chargement ? | `liaison.lire_registre` / `ecrire_registre` |
| V5 | Quel appel prévient qu'une partie vient d'être chargée ? 14/10 (sondes) : l'événement System `OnGameplayStarted`, par `UIAction.RegisterEventSystemListener` ; il arrive après le chargement d'une sauvegarde, partie en cours. Le socle y relit le registre | `liaison.ecouter_la_partie`, `Scriptorium.entrer_en_partie`, `registre.invalider` |
| V6 | Quel appel dit qu'un dialogue est en cours ? | `liaison.dialogue_en_cours` |
| V7 | Le manifeste est-il accepté ? Au journal : `'mods/scriptorium_socle' is not limited to any game version, it will be enabled`. Pas de bloc `<supports>` : le jeu le compare à sa version et désactive le mod hors liste ; le socle ne remplace aucun fichier du jeu | `socle/mod.manifest` |
| V8 | Reste-t-il un texte jaune à l'écran avec le socle seul ? | — |
| V9 | La bourse d'Henry bouge-t-elle avec `scriptorium_essai_coffre` (moins 100) ? Sinon, `GetMoney`, `RemoveMoney`, `AddMoney` sont à corriger | `liaison.groschen_d_henry`, `retirer_groschen_a_henry`, `donner_groschen_a_henry` |
| V10 | Les lignes du livre ont-elles un `moment` autre que 0 (heure du jeu) ? | `liaison.heure_du_jeu` |
| V11 | Les objets du camp apparaissent-ils (`System.SpawnEntity`, `BasicEntity`, `object_Model`) ? Sinon, le journal dit « Pose impossible pour … » | `liaison.poser_objet` |
| V12 | Les chemins des modèles existent-ils dans les paks du jeu ? Relever les vrais chemins de la tente, de la paillasse, du feu, du banc, du coffre, de la palissade, de la porte et de la tour | `camp.modeles`, `enceinte.modeles` |
| V13 | Le camp est-il orienté comme Henry (tente du Directeur devant lui, à 7 m) ? | `liaison.cap_du_joueur`, `camp.dans_le_monde` |
| V14 | Après sauvegarde, fermeture et rechargement, les objets sont-ils encore là ? Sinon, `scriptorium_essai_camp` doit les reposer | `camp.redresser`, `liaison.objet_existe` |
| V15 | Le message avec complément s'affiche-t-il traduit et suivi du nom ? | `liaison.afficher` |
| V16 | Comment faire venir un personnage à nous : quelle âme (`sharedSoulGuid`) et quelle classe (`NPC`) ? Un essai avec une âme de garde du jeu de base suffit pour commencer | `liaison.faire_venir_homme`, `liaison.ames` |
| V17 | Comment ordonner à un personnage de dormir ici, de s'asseoir là, de se tenir là, de marcher jusqu'à un point ? | `liaison.ordonner` |
| V18 | Comment faire venir une bande ennemie hostile (âmes de brigands, de Coumans) ? | `liaison.faire_venir_ennemis`, `liaison.ames_ennemies` |
| V19 | Comment savoir qu'un personnage est mort (`actor:IsDead`, `soul:GetHealth`) ? | `liaison.personnage_mort` |
| V20 | Quelle âme et quelle apparence pour le Directeur (neuves, à nous) ? | `liaison.ame_du_directeur` |
| V21 | Comment ouvrir un dialogue avec le Directeur qui présente le menu de la Gestion du camp ? | `directeur.menu`, système de dialogues du jeu |
| V22 | Comment ouvrir, fermer et barrer une porte posée ? | `liaison.changer_porte` |
| V23 | Le feu posé brûle-t-il ? Les hommes reconnaissent-ils une paillasse et un banc posés ? | `camp.modeles` |
| V24 | `partie_en_cours` : le battement s'arrête-t-il bien au menu principal, et repart-il en partie ? 14/10 (sondes) : une minuterie posée au démarrage du mod ne tire jamais (ni simple, ni « aussi en pause », ni par nom de fonction) ; une minuterie posée à `OnGameplayStarted` tire toutes les 5 s en partie. Le socle repose donc bandeau, poste et battement à chaque entrée en partie ; `partie_en_cours` valait faux au chargement et vrai en partie. Reste à voir : `OnGameplayEnded` au retour au menu | `liaison.partie_en_cours`, `Scriptorium.entrer_en_partie`, `Scriptorium.sortir_de_partie` |

Pour me répondre : le contenu de `kcd.log` autour de `[Scriptorium]`, et une ligne par question.

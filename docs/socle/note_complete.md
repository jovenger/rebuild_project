# NOTE COMPLÈTE — le socle de Scriptorium, ce qui a été construit le 14/10/2026

À coller tel quel comme premier message d'une nouvelle conversation Claude Code sur le PC. Claude fera le reste (récupérer le dépôt, lire les fichiers, continuer).

## 0. Première consigne pour Claude (à lire en premier)
- Récupère le dépôt `https://github.com/jovenger/rebuild_project`, branche `ccr-c18b8b50-tespti`, dans `C:\Users\maste\Desktop\rebuild_project` (clone-le s'il n'y est pas, sinon mets-le à jour). Fais-le toi-même ; JoVenGer ne tape aucune commande.
- Lis `CLAUDE.md`, puis `docs\socle\reprise.md`, `docs\socle\avancement.md` et `docs\socle\essai_en_jeu.md`. Tout ce qui est écrit ci-dessous y est, en plus détaillé.
- Tout en français. Réponses courtes, en listes. Une chose à la fois.

## 1. Le projet
- JoVenGer construit « Scriptorium », un grand mod pour Kingdom Come: Deliverance II (camp de soudoyers, Directeur, hommes, raids, coffre, Gestion du camp). Il vit dans `C:\Users\maste\Desktop\Scriptorium`.
- Scriptorium repose sur le mod « Mercenaries » d'Alex (Steam Workshop n° 3689921142, version 3.0), copié dans `Scriptorium\mercenaires\`.
- **Mission du chantier :** refaire entièrement ce mod, à notre façon, comme un mod à part (`scriptorium_socle`), sans jamais copier, traduire ni renommer le code d'Alex. L'adaptation à Scriptorium viendra après, hors de ce chantier.

## 2. Les règles de JoVenGer (obligatoires)
- Tout en français, sans exception.
- **Ne jamais toucher** au Scriptorium actuel ni à son git, ni à la copie `D:\Scriptorium V2\Scriptorium`, ni aux trois mods installés (`Mods\scriptorium`, `scriptorium_regles`, `scriptorium_lumiere`), ni à `Data\` du jeu. Le socle s'installe dans `Mods\scriptorium_socle` seulement, et se joue sur une partie d'essai neuve, jamais sur la partie actuelle.
- Jamais le code d'Alex : fiche de comportement d'abord, code neuf ensuite, d'après la fiche seule.
- Une chose à la fois, menée jusqu'au bout ; rien laissé en essai ; pas de `TODO`.
- Pas de commit si `essais\tout_verifier.py` ne passe pas entièrement.
- Aucune action destructive sans l'accord de JoVenGer juste avant.
- Plus aucun texte jaune par-dessus l'image du jeu : tout message passe par le bandeau en bas de l'écran.
- Le camp paie au coffre, jamais avec la bourse d'Henry. Les tentes sont à JoVenGer. Les dépenses restent justes.

## 3. Ce qui a été construit (tout est dans le dépôt, tout passe au banc)
Dix morceaux de code Lua, dans `socle\pak\Scripts\scriptorium\` :
- **`noyau.lua`** : la table `Scriptorium`, la liste des morceaux, un démarrage où un morceau en panne ne bloque pas les autres, et le battement commun (`Scriptorium.battre`, toutes les trente secondes, seulement quand une partie est en cours).
- **`liaison.lua`** : le **seul fichier qui parle au moteur du jeu**. Tout le reste passe par lui. Il contient 24 appels marqués « à vérifier en jeu ».
- **Morceau 0, `bandeau.lua`** : les messages au joueur. Une seule porte, un message à la fois, 3 à 8 secondes, alertes devant, pas de répétition avant 30 secondes, regroupement (« plusieurs hommes sont arrivés »), complément (un nom, un montant), attente pendant un dialogue, historique.
- **Morceau 1, `registre.lua`** : la sauvegarde des données du camp. Une seule sauvegarde versionnée, une case par morceau, montées de version, remise à neuf propre si le contenu est abîmé, lecture en bac à sable.
- **Morceau 2, `coffre.lua`** : les groschen du camp, le livre de comptes (200 lignes gardées, totaux exacts), dix réserves (vivres, bière, fourrage, traits, bois, herbes, fer, cuir, remèdes, onguents), dépôt et versement avec Henry. Le camp ne paie jamais avec la bourse d'Henry.
- **Morceau 3, `camp.lua`** : le plan du camp en données sur trois niveaux (feu, sièges, tentes, paillasses, coffre), fondé là où se tient Henry, agrandi, redressé après chargement avec ou sans homme, levé. Paillasses et sièges réservables ; le lit du Directeur lui est réservé.
- **Morceau 4, `hommes.lua`** : une fiche par homme (nom d'époque comme Jan Kladivo, rôle, rang, contrat, moral, blessure). Sept rôles (homme d'armes, arbalétrier, archer, pavoisier, barbier, cuisinier, armurier). Embauche par contrat avec prime payée au coffre et paillasse obligatoire. Solde chaque semaine selon le rang ; impayée deux semaines, l'homme s'en va. Une ration de vivres par jour ; la faim fait baisser le moral. Journée réglée sur les heures (lever, repas, exercice, corvée, veillée, sommeil). Garde par tours de veille, jamais plus de postes que d'hommes. Dizainiers (un pour dix) et capitaine. Fin de contrat, désertion, renvoi, mort, soins (plus vite avec un barbier). Ordres au jeu seulement quand l'activité change.
- **Morceau 5, `bataille.lua`** : une seule entrée, « lever une bande » (brigands, déserteurs, soudards, Coumans). Avertissement une heure avant. Ordre de bataille d'époque : pavois et hommes d'armes devant, tireurs dans les intervalles puis sur les ailes. Fin par le jeu (ennemis morts) ou par la règle (rapport de forces, moral, enceinte). Pertes, soins, moral, pillage du coffre en cas de défaite, butin partagé selon la coutume (moitié aux hommes, un sixième au capitaine, le reste au coffre). Escarmouches pour les patrouilles. Graine de hasard gardée au registre.
- **Morceau 6, `directeur.lua`** : le personnage `Scriptorium_Directeur` à sa tente, sa journée, le rapport du camp, et la **Gestion du camp en données** : dix-huit entrées (rapport, livre, payer la solde, engager, renvoyer, nommer le capitaine, renouveler, acheter des réserves, déposer, prendre, agrandir le camp, lever le camp, palissade, tours, remède, onguent, soigner, patrouille), chacune disant si elle est possible et pourquoi pas sinon.
- **Morceau 7, `enceinte.lua` et `atelier.lua`** : palissade de seize pans à quinze mètres, porte ouverte le jour, fermée la nuit, barrée dès qu'une bande approche ; tours de guet ; bonus de défense. Alchimie (remèdes, onguents, soins) et armurerie (usure de l'équipement par bataille, entretien quotidien par l'armurier contre fer et cuir).
- **Morceau 8, `patrouilles.lua`** : trois chemins en données (ronde proche, route du village, les bois), marche par points, rencontres au retour (rien, rôdeurs chassés avec butin, embuscade), risque du chemin qui baisse puis remonte, avance de guet.
- **Morceau 9, `discipline.lua`** (décision D7) : fautes à l'aube selon le moral (rixe, vol, ivresse, exaction chez les paysans), jugements par la Gestion du camp (pardon, amende retenue sur la solde, corvée, pilori, renvoi), prescription et laxisme, réputation auprès des villages qui change le prix des réserves.
- **`poste.lua`** : quatorze commandes de console d'essai (`scriptorium_essai_bandeau`, `_registre`, `_coffre`, `_camp`, `_camp_agrandir`, `_camp_lever`, `_hommes`, `_bataille`, `_directeur`, `_enceinte`, `_patrouille`, `_discipline`, `scriptorium_gestion_rapport`, `scriptorium_bilan`).

Autour du code :
- `socle\textes\fr\text_ui__scriptorium_socle.xml` : 77 textes français, tous employés. `socle\mod.manifest` : le manifeste du mod.
- `essais\tout_verifier.py` : la vérification complète en six étapes (syntaxe Lua 5.1, banc de 1 322 vérifications sur un faux jeu dont un scénario complet d'une semaine, noms interdits, textes, manifeste, contrôle d'absence contre les empreintes d'Alex). Tout passe.
- `outils\empreintes.py` : relève les empreintes du mod d'Alex (sha256 seulement, rien en clair), pour prouver qu'il n'en reste rien.
- `noyau\installer.py` : installe dans `Mods\scriptorium_socle` seulement, refuse les chemins interdits, met de côté l'ancien mod d'essai avant de le remplacer, relance la vérification avant.
- Documents : `docs\socle\plan_de_refonte.md` (le plan et les décisions), `avancement.md`, `reprise.md`, `essai_en_jeu.md`, et une fiche de comportement par morceau dans `docs\socle\fiches\00` à `09`.

## 4. L'état exact
- Tout est écrit et passe au banc (1 322 vérifications).
- **Rien n'a été essayé dans le jeu.** 24 appels du moteur restent à confirmer dans `liaison.lua` : affichage du texte et son aspect, dialogue en cours, sauvegarde et relecture du registre (en attendant, il ne survit pas à la fermeture du jeu), chargement d'une partie, commandes de console, version du manifeste, bourse d'Henry, heure du jeu, pose et retrait d'objets, position d'Henry, chemins des modèles, message avec complément, venue des personnages et des ennemis (il faut des âmes : `liaison.ames`, `ames_ennemies`, `ame_du_directeur` sont vides), ordres aux personnages, morts, dialogue de la Gestion du camp, porte, partie en cours.
- Les chemins des modèles du jeu de base (`camp.modeles`, `enceinte.modeles`) sont provisoires.
- Les empreintes d'Alex ne sont pas relevées : le contrôle d'absence ne tourne pas encore.
- Aucun morceau n'est scellé ; les fiches 02 à 09 attendent la validation de JoVenGer.

## 5. Les décisions prises (accord de principe de JoVenGer)
- D1 : éviter le mot « mercenaire » dans les textes (« la Compagnie », « soudoyers », « hommes d'armes », « soudards » pour les ennemis).
- D2 : voix du jeu de base pour les répliques courtes ; menus du Directeur sans voix.
- D3 : français seul au début.
- D4 : partie d'essai neuve pendant le chantier.
- D5 : salle blanche stricte : ne jamais ouvrir `mercenaires\` pour écrire le code.
- D6 : à la fin, seules les empreintes d'Alex sont gardées.
- D7 : toutes les nouveautés d'époque (contrat, solde, moral, vivres, rangs, pavois, guet, butin, barbier, usure, discipline, noms d'époque) : faites au banc.
- D8 : bandeau en bas de l'écran, premier morceau.
- D9 : projet dans `C:\Users\maste\Desktop\rebuild_project`, mod d'essai `Mods\scriptorium_socle`.
- D10 : pendant un essai, désactiver les trois mods Scriptorium par la liste des mods chargés du jeu (`mod_order.txt`, à vérifier), jamais en renommant un dossier.

## 6. Ce qui reste à faire, dans l'ordre
1. Vérifier sur le PC : `py -3.13 -m pip install lupa`, puis `py -3.13 essais\tout_verifier.py` doit dire « tout passe ».
2. Installer : `py -3.13 noyau\installer.py --jeu "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"`.
3. Essai en jeu avec JoVenGer, en suivant `docs\socle\essai_en_jeu.md` : les commandes `scriptorium_essai_*`, puis les 24 points V1 à V24 ; corriger `liaison.lua`, renseigner les âmes et les modèles d'après ce que le jeu dit. Lire les paks du jeu pour trouver les modèles et les âmes.
4. Relever les empreintes d'Alex (lecture seule sur `C:\Users\maste\Desktop\Scriptorium\mercenaires`) : `py -3.13 outils\empreintes.py "C:\Users\maste\Desktop\Scriptorium\mercenaires" docs\socle\empreintes_alex.json`, puis vérifier que le contrôle d'absence donne 0 partout.
5. Faire valider les fiches 02 à 09 par JoVenGer ; sceller les morceaux un par un, chacun après son essai en jeu.
6. Ensuite : les tables du jeu (âmes et personnages à nous, apparence neuve du Directeur), le dialogue de la Gestion du camp dans le jeu, la quête de fond, le contrôle d'absence en mode strict.

## 7. À part, pour après
- `docs\socle\idees_pour_plus_tard.md` : vingt-six idées d'amélioration notées le 14/10. Consigne de JoVenGer : **on termine d'abord ce qui est commencé**, on n'y touche pas avant.

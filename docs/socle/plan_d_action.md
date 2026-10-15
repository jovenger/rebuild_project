# Plan d'action — la suite du socle (écrit le 15/10/2026)

> **Passe avant ce plan :** la note de JoVenGer `C:\Users\maste\Desktop\Scriptorium\docs\socle\NOTE_POUR_LE_SOCLE.md`,
> lecture seule (avec `CARTE_DES_REGLES.md` et, à l'étape du guichet seulement, `CONTRAT_DU_SOCLE.md`). Le but : le socle
> remplace le mod d'Alex **sous Scriptorium**, dont les règles priment ; chaque règle du socle a un interrupteur et passe par
> un point d'accroche. Ordre : sa partie 2 (retrait sûr, taille du registre, tirage en cloche, un seul
> nom par table — toute faite le 15/10), puis ses étapes 1 à 9. Son étape 3 (le « guichet ») remplace l'étape 3 ci-dessous : on ne refait ni la
> Gestion du camp ni les dialogues du Directeur, que Scriptorium a déjà.

Ce qui reste pour que le mod refait vive dans le jeu. Les règles (coffre, camp, hommes, batailles, Directeur,
enceinte, atelier, patrouilles, discipline, réglages) sont écrites, validées par JoVenGer et passent au banc ;
une bonne part est vue en jeu. Ce qui manque est surtout **ce que le joueur voit bouger** : nos personnages, leurs
gestes, le combat, le dialogue du Directeur, la quête.

## Comment on travaille (pour chaque étape)
1. Recherche en lecture seule dans les paks du jeu (`Data\*.pak`, lus en mémoire, jamais extraits ni modifiés) et dans
   le relevé Lua du jeu (`LuaState_Sorted.txt` à la racine du jeu). Jamais le code d'Alex.
2. Fiche de comportement (`docs/socle/fiches/NN_….md`), puis validation par JoVenGer en **questions à cocher**
   (il préfère cocher plutôt que lire une fiche entière).
3. Code neuf d'après la fiche ; toute valeur de règle en données, ajoutée au catalogue de `reglages.lua`
   (règle de JoVenGer : tout doit rester réglable par le programme Scriptorium).
4. Essais au banc ; `py -3.13 essais\tout_verifier.py` doit finir par « tout passe » avant tout commit.
5. Essai en jeu dans la **Partie 4** (`playline3`, copie de la sauvegarde 473 de la Partie 1, sauvegarde permise ; accord
   de JoVenGer du 15/10), ou dans la Partie 1 (`playline0`), **jamais sauvegardée** : `outils\pilotage\debut_essai.ps1`,
   `vers_partie_d_essai.ps1 -Charger -Ligne playline3` (ou `vers_partie1.ps1`), choix à vue, `confirmer_sauvegarde.ps1`,
   ordres par `outils\ordonner.py`, puis `fin_essai.ps1`, le jeu encore ouvert (obligatoire avant de s'arrêter ; il
   range les sauvegardes d'essai pour que « Continuer » reprenne la partie de JoVenGer).
6. Notes dans `docs/socle/avancement.md` et `essai_en_jeu.md`, commit et envoi sur GitHub.

## Étape 1 — Le comportement des personnages (priorité)
**Le problème (vu le 14 et le 15/10) :** un personnage né par `System.SpawnEntity`, même avec toutes les propriétés de
la classe `NPC` et une âme du jeu, a un agent d'IA actif mais aucun comportement : il ne marche pas, ne suit personne,
ne réagit pas à Henry à 10 m, ne se bat pas, quelle que soit sa faction. `XGenAIModule.SpawnEntity` (celle des scripts
de débogage du jeu) n'existe pas dans le jeu publié. `AI.AddPersonallyHostile`, `AI.AddAggressiveTarget`,
`actor:StartFollow` sont acceptés sans effet. Voir `essai_en_jeu.md`, V17 et V18.

**Pistes, dans l'ordre :**
1. Les commandes de débogage du moteur : un ordre d'essai qui lance `System.ExecuteCommand("DumpCommandsVars")`
   (écrit `consolecommandsandvars.txt` à la racine du jeu) ; y chercher les commandes `wh_*` qui font naître un
   personnage ou réveillent son cerveau (les scripts du jeu emploient déjà `wh_rpg_AddBuffDebug`).
2. Les messages aux cerveaux : `XGenAIModule.SendMessageToEntityData`, `SetBrainVariable`, `GetBrainVariable`
   (relevé Lua) ; lire dans `Tables.pak` les cerveaux (`Libs/Tables/ai/brain*.xml`, `brain2mailbox`, `brain2subbrain`)
   et ce que le cerveau `npc_basic` attend.
3. Les données de carte d'un mod : le jeu ouvre `Mods\scriptorium_socle\data\levels\kutnohorsko\*.pak` (vu au
   journal) ; un personnage placé dans une couche de la carte est peut-être enregistré auprès des cerveaux comme ceux
   du jeu. Essai : un seul personnage posé ainsi, voir s'il vit.
4. Les entités « fabriques » du jeu (`Event_Spawn` d'`EntityCommon.lua`, entités `Spawner`) : faire naître un
   personnage depuis une entité modèle posée.
- **Fait quand :** un de nos hommes marche jusqu'à un point, s'assoit, dort ; une bande marche sur le camp ; nos hommes
  et la bande se battent ; la mort et la fin de bataille par le jeu suivent (déjà prêtes).
- **Fiche à écrire :** 12 — les gestes des personnages (se tenir, marcher, s'asseoir, dormir, garder, combattre). Le cerveau suivra le caractère de chaque homme (fiche 11, faite le 15/10) : ses besoins (fatigue, faim) et ses goûts (le feu, l'entraînement, les dés, le lit) disent déjà ce qu'il choisit de faire de son temps libre ; le Directeur et les ennemis recevront leur caractère à cette étape, et l'entraînement fera monter les compétences du jeu (`soul:AddSkillXP`).

## Étape 2 — Nos propres personnages (tables du jeu)
- Âmes à nous pour les sept rôles, les bandes (brigands, déserteurs, soudards, Coumans) et le Directeur (V20) ;
  apparences neuves ; faction de la Compagnie, amie du joueur et ennemie des bandes (arbre `FactionTree`).
- Aujourd'hui, provisoire : gardes de Trosky pour nos hommes, brigand de Trosecko pour les bandes, garde « en réserve »
  pour le Directeur (`liaison.reserves_d_ames` et `liaison.ame_de` depuis la fiche 13, `ames_ennemies`).
- Recherche : comment un mod ajoute des lignes aux tables du jeu (fichiers de table propres au mod, comme les textes
  `…__scriptorium_socle.xml`) ; vérifier au journal que les lignes sont chargées.
- **Fait quand :** nos personnages viennent avec nos âmes, et la faction est respectée en combat (après l'étape 1).

## Étape 3 — Le dialogue du Directeur et la Gestion du camp à l'écran (V21)
- Le menu existe en données (`directeur.menu()`, vingt entrées, chacune possible ou non avec sa raison) ; il ne se
  joue aujourd'hui que par les ordres d'essai.
- Recherche : le système de dialogues du jeu (fichiers de dialogue et de quête dans `Scripts.pak`), un dialogue en texte
  seul (décision D2 : pas de voix pour les menus).
- Dialogues neufs en français d'époque pour le Directeur, puis le capitaine et les hommes.
- **Fait quand :** parler au Directeur ouvre la Gestion du camp, et chaque entrée agit.

## Étape 4 — La quête de fond « La Compagnie »
- Une quête neuve qui tient le camp en vie sur les deux cartes, avec ses objectifs (payer la solde, tenir les vivres,
  garder le camp). Nom à choisir par JoVenGer.

## Étape 5 — Voix et icônes
- Répliques déjà enregistrées du jeu (salut, acquiescement, cris de combat), appelées par leur identifiant (D2).
- Icônes du jeu de base ou neuves.

## Étape 6 — Essais en jeu restants (le code est prêt)
- Une aube : fautes, désertions, fins de contrat. Une semaine : la solde. Une patrouille de bout en bout. La porte
  fermée la nuit. Le bandeau qui attend pendant un dialogue (V6).
- L'onguent n'a été vu qu'au banc (pas d'appel au moteur).

## Étape 7 — Fin du chantier
- **Version publiée sans essai** (remarque de la conversation Scriptorium, 15/10) : le mod publié ne contient ni le poste
  d'essai (`poste.lua`, ses ordres `scriptorium_essai_*`), ni la lecture du fichier d'ordres, ni aucun cerveau, âme ou
  arbre d'essai (`essai_*`). L'installateur fait deux versions, « essai » avec le poste, « publiée » sans ; le banc
  vérifie que la version publiée n'a aucun nom en « essai ».
- **Revu sans `-devmode`** : chaque résultat clé (cerveau à nous V29, ordres V31, cible V35, tables suffixées, registre
  en tranches) vu au moins une fois en jeu lancé sans `-devmode` ; `essai_en_jeu.md` le dit pour chaque point.
- Contrôle d'absence en mode strict (`tout_verifier.py --strict`), morceaux scellés un par un dans `avancement.md`.
- Autres langues (D3 : plus tard).
- La bascule vers Scriptorium : seulement sur l'ordre de JoVenGer (le programme Scriptorium écrira alors le fichier de
  réglages, `fiche 10`).
- Ensuite seulement : `docs/socle/idees_pour_plus_tard.md` (vingt-six idées).

## Sept idées validées par JoVenGer le 15/10/2026 (question à cocher, transmise par la conversation Scriptorium)
Pas maintenant : on finit d'abord s'asseoir et dormir, puis la vie du camp. Chacune à son étape de la note de JoVenGer
(`NOTE_POUR_LE_SOCLE.md`, étapes 1 à 9).
1. **Le gardien des hommes** (fin de l'étape 1) : un contrôle régulier que chaque homme vit — son cerveau tourne, il
   obéit, il n'est ni coincé ni tombé (d'une tour, sous le sol) ; sinon il est remis d'aplomb seul (réveil,
   replacement), et c'est noté au journal. (Déjà vus : des hommes figés, des archers qui sautaient des tours.)
2. **Les crimes d'Henry** (étape 1 ou 2, avec la faction « la Compagnie ») : nos hommes ont les boîtes `crime_*` de
   `npc_basic` ; ils ne dénoncent jamais Henry aux gardes et ne l'attaquent jamais pour un crime. La Compagnie ferme les
   yeux sur son capitaine ; au camp, seule la discipline de Scriptorium juge. Duel et pugilat restent hostiles le temps
   du combat (fiche 12).
3. **Suivre Henry partout** (étape 1, au comportement « suivre Henry ») : voyage rapide, Henry à cheval, villes et
   intérieurs, passage d'une carte à l'autre ; à l'arrivée, l'escorte réapparaît près d'Henry. Modèle : le chien du jeu
   (`companion_playerDog`).
4. **La garde contre les mises à jour du jeu** (étape 3 ou 7) : au lancement, vérifier que chaque fonction et chaque
   table du jeu dont le socle a besoin existe encore ; sinon le dire clairement au bandeau et passer en mode prudent,
   sans rien écrire qui puisse abîmer la sauvegarde.
5. **Le retrait propre pour le Workshop** (étape 9) : un ordre « quitter le mod » qui renvoie les hommes, congédie le
   Directeur, lève le camp, rend le coffre à Henry et efface le registre. Partir de l'ordre de fin de V57
   (`poste.essai_tout_lever`).
6. **La fluidité mesurée** (étape 7, essai du camp plein) : mesurer les images par seconde avec 80 hommes ; les hommes
   loin d'Henry ou hors de sa vue réfléchissent moins souvent.
7. **Le banc de l'économie** (étapes 4 et 5) : simuler au banc un mois du camp en quelques secondes (missions, solde,
   vivres, embauches) pour prouver que le Directeur fait des bénéfices et que le coffre ne se vide pas en boucle. Règles
   de Scriptorium : le camp paie au coffre, dépenses justes.

## Deux règles de JoVenGer du 16/10/2026 (transmises par la conversation Scriptorium)
1. **Le socle fait la mécanique, Scriptorium décide.** La vie du camp, les missions, l'embauche et les métiers existent
   déjà dans Scriptorium, avec leurs règles (repas, garde, paye, prix, rapports, objectifs) : ne pas les refaire. Le
   socle fournit ce que le mod d'Alex faisait en dessous : faire marcher, asseoir, coucher, garder, suivre et combattre
   les hommes, poser les camps de bandits, envoyer une troupe dehors et la faire revenir. Qui, quand et combien restent à
   Scriptorium, par le guichet. Avant chaque fiche de ces étapes : relire dans `CARTE_DES_REGLES.md` les dossiers de
   Scriptorium qui en parlent, et n'écrire que la mécanique qui leur manquera sans Alex. La quête, les voix et les icônes
   n'existent pas dans Scriptorium : là, tout est à faire.
   **Nettement meilleur qu'Alex**, pas seulement équivalent : hommes vraiment vivants, rien de perdu au rechargement,
   aucun homme figé, tout vérifié en jeu (« il faut vraiment que ça soit beaucoup mieux »).
2. **Tous ceux qui sortent du camp partent à cheval et en reviennent à cheval** (validé par JoVenGer le 16/10) : le
   coursier, les gens de métier (ville, bois, chasse) et les soldats en mission ou en sortie. Aux étapes des missions et
   des métiers, pas maintenant. Chez Scriptorium, le coursier restait figé dès qu'on essayait de le faire monter. D'abord
   chercher comment les arbres du jeu font monter, chevaucher et descendre ses cavaliers (messagers, soldats montés ;
   « Réutiliser avant de créer »), puis un seul homme, prouvé à l'image.

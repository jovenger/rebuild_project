# Fiche 13 — Nos âmes

- Morceaux : `liaison` (la table des âmes, la venue, l'équipement), `hommes` (l'âme tirée à l'embauche, gardée sur le
  registre), `directeur`. Données du jeu : `Libs/Tables/rpg/soul__scriptorium_socle.xml` (existe déjà : le marcheur et
  le brigand d'essai).
- But (étape 2 de la note de JoVenGer, avancée parce que l'étape 1 en a besoin) : que **les hommes du camp aient notre
  cerveau**, pour recevoir les ordres (aller, s'asseoir, se coucher, attaquer). Aujourd'hui ils ont des âmes de gardes de
  Trosky empruntées au jeu (`extraGuards_dummy_1, 3, 5`, cerveau du jeu) : ils ne reçoivent pas nos ordres. Le
  Directeur aussi (`extraGuards_dummy_6`).
- État : **validée par JoVenGer le 15/10/2026** (questions à cocher, réponses revues avec lui par la conversation
  Scriptorium) : personnages du jeu d'abord, trois paliers, équipement par le Lua seul, soldats du jeu. Ce qui est marqué
  « acquis » a été relu dans les tables du jeu ou vu en jeu ; le reste est « non vérifié ».

## Ce que le joueur voit
- Les hommes du camp obéissent comme le marcheur : assis au feu, couchés dans leur paillasse, au poste.
- Chaque homme a son visage, sa voix et sa tenue ; un homme qui revient (rechargement, retour au camp) garde les siens.
- Tous les gens du camp viennent : combattants, Directeur, gens de métier, leurs assistants, et les femmes (dames des
  bains, jardinière). Aujourd'hui, seuls trois rôles ont une âme ; le pavoisier, le barbier, le cuisinier et l'armurier
  ne viennent pas (« pas d'âme pour le rôle »).

## Ce qui est acquis (relu dans les tables du jeu, ou vu en jeu)
- **Une âme du mod est chargée et jouée** : une ligne de `soul__scriptorium_socle.xml` portant notre `brain_id` donne
  le marcheur (V29 à V69) et le brigand d'essai (V51).
- **Une âme resservit après la mort** de son homme : en V50, trois marcheurs sont venus l'un après l'autre sur la même
  âme, chacun après la mort du précédent, et chacun a chargé.
- **L'apparence et l'équipement de départ viennent du personnage** nommé par `skald_character_name` : le marcheur porte
  le personnage d'un garde du jeu (`char_GENERIC_MAN_GUARD_15`), il est vêtu, tire une arme et blesse (V53, V54). La
  table `Libs/Tables/skald/skald_character.xml` (1 162 personnages, dont 196 génériques) donne l'âge, le corps, le sexe,
  les noms affichés et la voix (`voice_id`, `voice_categories`) ; le visage lui-même n'y est pas.
- **Palette réelle** des personnages génériques : soldats (`char_GENERIC_MAN_SOLDIER_*`, 33 personnages, employés par
  2 361 âmes), gardes (10), gens du commun (`char_GENERIC_MAN_COMMONER_*`), mineurs, bourgeois, Coumans, brigands ; et
  **41 femmes** (`char_GENERIC_WOMAN_COMMONER_*`, `TOWNSWOMAN`, marchandes…).
- **La classe sociale compte** : les gardes ont la classe 101 « guard », dont le rôle face au crime est « soldier », que
  la table du jeu réserve aux figures d'autorité (`social_class.xml`, `soul_crime_role.xml` : « Only socialClasses that
  are authority figures »). La classe 33 « soldier » a le rôle « civilian ». Nos hommes ont aujourd'hui la classe 101 :
  le jeu peut les traiter en gardes (arrêter Henry pour un vol, fiche 12, question 2).
- **Les attributs d'une âme** dans le jeu : `brain_id`, `combat_level`, `digestion_multiplier`,
  `enable_perk_point_gain`, `factionName`, `initial_clothing_dirt`, `inventory_preset_override`, `skald_character_name`,
  `social_class_id`, `soul_archetype_id`, `soul_class_id`, `soul_id`, `soul_name`, `soul_vip_class_id`, `unique`,
  `voice_group_name`, `xp_multiplier`.
- **Les tables suffixées** de tenues et d'armes sont chargées par le jeu lui-même (`clothing_preset__temp.xml`,
  `weapon_preset__autotest.xml`, dans `Tables.pak`) : un `clothing_preset__scriptorium_socle.xml` et un
  `weapon_preset__scriptorium_socle.xml` suivent la même voie.
- **Les appels d'équipement** de l'outil de combat du jeu (`Scripts/Debug/CombatDebug.lua`) : `actor:EquipClothingPreset`
  (une tenue, par son identifiant de `clothing_preset`) et `actor:EquipWeaponPreset` (des armes, par `weapon_preset`).
- **Compétences, homme par homme** : `soul:AdvanceToSkillLevel` après la venue (V53). Les tables `soul2skald_skill` et
  `soul2skald_soul_stat` sont par âme : le caractère de la fiche 11 se pose à la venue, pas dans la table.

## Acquis en jeu (V70, 15/10/2026)
- Les hommes engagés et le Directeur **naissent sur nos âmes** (identifiants relus sur chacun) ; **notre cerveau tourne**
  pour chacun ; à l'image, **des soldats du jeu** (le jeu les nomme « Soldat »).
- Ils **reçoivent nos ordres** : l'ordre 10 sur les bancs du camp (assis autour du feu, vu à l'image), l'ordre 11 sur
  leurs paillasses et sur le lit du Directeur (couchés, vu à l'image).
- Non vérifié en jeu : la renaissance d'un homme né sur une âme empruntée (vérifiée au banc) ; le rechargement avec nos
  âmes (le marcheur, sur une âme à nous, revient au rechargement : V56).

## Le principe transmis par la conversation Scriptorium (mécanisme seulement, décision de JoVenGer du 15/10)
- **Une âme par homme vivant, jamais partagée**, tirée d'une grande réserve rangée par palier de niveau ; chaque âme porte
  son `combat_level` et son propre personnage.
- **Des personnages à soi** se déclarent dans une table suffixée `skald_character` (âge, corps, sexe, voix, noms
  affichés), sans données uniques ; un mod en emploie une centaine dans la partie de JoVenGer. Le visage que le jeu leur
  donne est à mesurer.
- **L'équipement par le Lua**, à la venue et ensuite, sur des tables de tenues et d'armes à soi. Rapporté comme marchant
  hors `-devmode` dans la partie de JoVenGer (non vu par nous : vérifié à notre premier essai d'équipement).
- **Une classe sociale** dont le rôle face au crime est « civilian », jamais la 101.

## Ce que demande le programme Scriptorium (relu dans sa carte des règles, pour les rôles seulement)
- **L'équipement change homme par homme** au cours du jeu : la forge et l'armurerie habillent un homme, le butin lui
  revient, le colonel va tête nue au camp et casqué en sortie (`colonel_tete_nue`, `armures_de_la_forge`,
  `armurerie_de_la_forge`). La tenue ne peut donc pas être figée sur l'âme.
- **Les gens du camp** : les combattants (dont le colonel, choisi parmi eux) ; le Directeur ; les compagnons nommés ; les
  métiers (forge, armurier, coursier, jardiniers, bûcherons, chasseurs, cueilleurs, bains, taverne, marchand, barbier,
  cuisinier) et un assistant par métier (`assistants_des_metiers`) ; **des femmes** : les dames des bains et la
  jardinière (`abri_des_femmes`, `bain_et_lavoir`).

## Proposition
1. **Une âme à nous par personne vivante**, jamais partagée, dans `soul__scriptorium_socle.xml`, toutes avec notre
   cerveau. Quatre réserves :
   - **combattants**, trois paliers (recrue, confirmé, vétéran), chacun assez pour le camp plein (80 hommes) : 80 âmes
     par palier, `combat_level` 0,3, 0,5 et 0,7, personnages de soldats du jeu, classe sociale 33 « soldier » ;
   - **gens de métier** (hommes, assistants et compagnons nommés compris) : 40 âmes, personnages de gens du commun,
     classe 1 « villager » (face au crime : civil) ;
   - **femmes** : 12 âmes, personnages de femmes du commun, archétype 1 « NPC_Female », classe 1 « villager » ;
   - **le Directeur** : une âme (son personnage d'aujourd'hui, `char_GENERIC_MAN_GUARD_08`, classe 33).
   - Faction provisoire de toutes : celle du marcheur (gardes de Trosky), jusqu'à l'essai de la faction.
2. **L'âme est tirée une fois, à l'embauche**, parmi celles qu'aucune personne vivante ne porte, et **gardée sur le
   registre** (même visage, même voix quand il revient). Elle ne change jamais : **un homme qui monte en grade garde son
   âme** ; le `combat_level` de l'âme n'est que son point de départ, son niveau suit ensuite ses compétences
   (`AdvanceToSkillLevel`). À sa mort ou à son départ, l'âme retourne à la réserve (réemploi vu en V50).
   - Palier plein : l'âme est prise au palier le plus proche ; les compétences corrigent le niveau.
   - **Jamais de refus d'embauche faute d'âme** : toutes les réserves pleines, l'homme reste sur le registre sans
     personnage, avec une ligne au journal (comme aujourd'hui quand le jeu refuse la venue).
3. **Les identifiants d'âmes sont stables** : un homme enregistré renvoie à son âme, donc une âme publiée ne change
   jamais d'identifiant. L'identifiant se calcule à partir de la réserve, du palier et du numéro
   (`5c7a5c7a-RRRR-4PPP-8000-NNNNNNNNNNNN`, en hexadécimal ; préfixe absent des 8 206 âmes du jeu, vérifié par l'outil) :
   le Lua le refait sans liste, et l'outil du dépôt (`outils/ames.py`) écrit les lignes de la table, toujours les mêmes.
4. **L'équipement par le Lua, homme par homme** : la tenue et les armes de départ selon le rôle et le palier, à la venue
   et après chaque rechargement ; ensuite, ce que décide le programme Scriptorium (forge, armurerie, butin, tête nue au
   camp). Les tenues et les armes sont des préréglages du jeu, ou à nous (tables suffixées), désignés en données.
5. **La faction** « la Compagnie » (fiche 12, 2 a) à un essai à part : seul `factionName` change.

## Questions à JoVenGer (cochées le 15/10/2026 : 1 a, 2 a, 3 a, 4 a)
1. **Les personnages** : a) ceux du jeu d'abord (soldats génériques pour les combattants, gens du commun pour les
   métiers, femmes du commun), nos propres personnages ensuite (recommandé) ; b) nos propres personnages tout de suite
   (noms et voix à nous ; le visage que le jeu leur donne est inconnu).
2. **Les paliers de la réserve des combattants** : a) trois paliers, recrue, confirmé, vétéran (le niveau acheté de la
   fiche 12), chacun avec son `combat_level` (recommandé) ; b) un seul palier, le niveau de chaque homme seulement par ses
   compétences.
3. **L'équipement de départ** : a) par le Lua seul, homme par homme (recommandé) ; b) une tenue de départ portée par
   l'âme selon le palier (`inventory_preset_override` et `combat_level`, employé seulement par des âmes d'essais
   automatiques du jeu), puis le Lua.
4. **L'apparence des combattants** : a) soldats génériques du jeu (33 personnages) (recommandé) ; b) gardes du jeu
   (10 personnages), avec la classe 33 quand même.

## Essais prévus (un changement chacun, partie d'essai `playline3`)
- **V70** : les hommes du camp nés sur nos âmes (notre cerveau, soldats du jeu, classe 33, faction provisoire du
  marcheur) ; ceux d'une partie déjà en cours, nés sur une âme empruntée, renaissent sur une âme à nous à l'entrée en
  partie ; le Directeur aussi. Ils reçoivent l'ordre 10 (s'asseoir sur les bancs du camp), puis l'ordre 11 (se coucher
  dans leur paillasse). La mesure « deux hommes sur la même âme » est abandonnée : une âme par homme dans tous les cas.
- **V71** : l'équipement de départ par le Lua (`EquipClothingPreset`, `EquipWeaponPreset`) : accepté hors `-devmode` ?
  vu à l'image ? gardé au rechargement ?
- **V72** : la faction « la Compagnie ».
- Plus tard, si la question 1 b ou après : nos propres personnages (le visage à mesurer).

## Règles en données (catalogue de `reglages.lua`, règle de JoVenGer du 14/10)
- Les identifiants d'âmes, de tenues et d'armes restent dans les tables du mod et dans `liaison` : ce ne sont pas des
  règles, et le catalogue ne prend que des nombres.
- Au catalogue : la part de chaque palier à l'embauche si le programme ne la donne pas, et plus tard l'équipement de
  départ par rôle et par palier (par numéro de préréglage dans une liste).

## Sources
- Paks du jeu, en lecture seule : `Tables.pak` (`Libs/Tables/rpg/soul*.xml`, `SoulPool.xml`, `social_class.xml`,
  `soul_crime_role.xml`, `Libs/Tables/skald/skald_character.xml`, `Libs/Tables/item/InventoryPreset*.xml`,
  `clothing_preset*.xml`, `weapon_preset*.xml`), `Scripts.pak` (`Scripts/Debug/CombatDebug.lua`).
- Programme Scriptorium, en lecture seule : `docs/socle/CARTE_DES_REGLES.md` (rôles seulement).
- Recherches « Réutiliser avant de créer » (deux) : rien de propre à KCD2 sur les âmes d'un mod. Le forum de Warhorse
  (2019, « How to change NPC Armors ») décrit l'équipement de KCD1 par `initial_clothing_preset_ID` sur l'âme : cet
  attribut n'existe plus dans les âmes de KCD2, donc ne s'applique pas. Le dépôt `muyuanjin/kcd2-mod-docs` (copie du
  wiki officiel) rappelle que le comportement des personnages passe par Lua, XGEN AI et Skald.
- Le mod d'Alex : non ouvert (règle de JoVenGer) ; son principe seulement, par la conversation Scriptorium.

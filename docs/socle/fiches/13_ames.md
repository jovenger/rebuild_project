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

## L'équipement (V71) : validé par JoVenGer le 15/10/2026 (questions à cocher, après relecture par la conversation Scriptorium)
- **Ses réponses** : 1. la tenue selon le grade (`soldier_generic` 1–2, 3–4, 5–6, variante tirée) ; 2. le tirage au hasard
  de la famille (contrat sans famille) se fait parmi **les six familles, armes d'hast comprises** ; 3. le pavoisier porte
  **un pavois peint** (masse, hache ou coutelas et pavois, préréglages du jeu, selon son grade) ; 4. flèches et carreaux
  **selon le grade** (grossiers, ordinaires, puis de chasse ou de fin tireur).
- **Ajouts de la conversation Scriptorium** : un point d'accroche « après le rhabillage d'un homme » (le programme y
  repose les pièces d'armure que l'homme a achetées à la forge, qui sont à lui) ; si l'inventaire ne sait pas compter ses
  objets, le filet devient « l'homme n'a plus son arme principale ou plus sa tenue de corps ».
- **Règles déjà fixées par JoVenGer dans Scriptorium** (elles priment ; lues dans `Scriptorium\choses\`, LISEZMOI de
  `styles_du_camp` du 28/09, `tenue_selon_le_grade` du 26/09, `tenue_gardee_au_chargement` du 5/10, transmises par la
  conversation Scriptorium) :
  - **six familles** de fantassins : épée et bouclier, hache et bouclier, épée longue à deux mains, masse et bouclier,
    hache, armes d'hast (lance à crochet, glaive, guisarme, bardiche, hache d'armes) ; jamais « masse seule » ni « épée
    courte seule ». **La famille se choisit à l'embauche, homme par homme, et il la garde toute sa vie** ; seule la
    qualité suit le grade (trois grades : faible, moyen, fort = recrue, confirmé, vétéran) ;
  - **la tenue et les armes changent à chaque grade** ; archers : débutant `bow_b` (105) et une épée courte commune, bon
    tireur `bow_c` (155) et une épée courte large, œil de lynx `bow_d_a` (230, le meilleur arc du jeu) et une épée courte
    lourde ; arbalétriers : faible, vieille arbalète de chasse ou arbalète de chasse ; moyen, vieille arbalète de campagne
    ou arbalète de campagne ; fort, arbalète lourde renforcée ou arbalète lourde ;
  - **jamais rhabillé au rechargement** : le jeu sauve l'inventaire (usure et réparations de la forge comprises) ;
    l'équipement se donne à l'embauche et à chaque changement de grade, un homme à la fois, jamais en bataille ; filet :
    un homme revenu presque nu (moins de 4 objets) est rhabillé ;
  - une arme d'hast rangée ne s'affiche pas : l'homme semble désarmé tant qu'il ne l'a pas sortie ;
  - principe d'Alex (conversation Scriptorium) : le bouclier est compris dans le préréglage d'arme ; un archer garde
    toujours son arme de tir ; une tenue complète posée sur des pièces données une à une ne les retire pas ; seulement des
    objets du jeu de base.
- **Relevé** (`Tables.pak`, lecture seule ; objets dans `Libs/Tables/item/item.xml`, préréglages dans
  `weapon_preset.xml` et `clothing_preset.xml`, noms français dans `Localization/French_xml.pak`) : le jeu a, par
  niveau, des préréglages d'arme **pour les six familles, bouclier compris** :
  - épée et bouclier : `sword_shield_3` (épée militaire et écu), `_4` (épée large), `_5` (basilard) ;
  - hache et bouclier : `axe_shield_3` (doloire), `_4` (hache de guerre), `_5`–`_6` (bec de faucon, hache de chevalier) ;
  - épée longue : `longsword_3` (de chevalier), `_4` (commune), `_5`–`_6` (à lame large, de bataille, de duel) ;
  - masse et bouclier : `mace_shield_2` (massue légère), `_3` (masse ordinaire, masse d'armes lourde), `_4`–`_6` ;
  - hache : `axe_2` (de charpentier), `_3` (doloire), `_5` (bec de faucon) ;
  - armes d'hast : `polearm_2` (glaive, serpe), `_3` (vouge, guisarme), `_4`–`_6` (bardiche, morgenstern, hache
    d'armes), chacune **avec une arme courte** à la ceinture (visible quand l'arme d'hast est rangée) ;
  - des préréglages à **pavois peint** : `mace_shield_2_02`, `_2_03`, `_3_04`, `_4_02`, `axe_shield_3_02`, `_3_03`,
    `_4_02`, `huntingsword_shield_3_01`, `_3_02`, `_4_01` ;
  - tenues de soldat `soldier_generic_1` à `_6` (13, 13, 16, 15, 12 et 9 variantes ; six pièces chacune) ;
  - les arcs et arbalètes de la règle existent (`bow_b`, `bow_c`, `bow_d_a` ; `crossbowLightCheap01`,
    `crossbowLightNormal01`, `crossbowMediumCheap01`, `crossbowMediumNormal01`, `crossbowHeavyCheap01`,
    `crossbowHeavyNormal01`), ainsi que les épées courtes (`shortswordCommon` « épée militaire », `shortswordBroad`
    « épée large », `shortswordHeavy` « épée de chevalier ») ; mais aucun préréglage du jeu ne les assemble ainsi.
- **Proposé** :
  - fantassins (homme d'armes) : la **famille** sur la fiche de l'homme, donnée par le contrat (`famille`), sinon selon la
    question 2 ; l'arme, un préréglage du jeu de sa famille au niveau de son grade (faible, moyen, fort ci-dessus), la
    variante tirée pour chaque homme ;
  - archers et arbalétriers : **nos préréglages** (`weapon_preset__scriptorium_socle.xml`, forme de `weapon_preset.xml`,
    objets du jeu de base seulement) : par grade, l'arc ou l'arbalète de la règle, ses flèches ou carreaux (question 4)
    et l'épée courte de la règle (épée militaire pour les arbalétriers) ;
  - pavoisier : question 3 ; gens de métier et Directeur : rien (la tenue de leur personnage) ;
  - la tenue selon le grade (question 1) ;
  - **quand** : à l'embauche, et à chaque changement de grade (`hommes.changer_de_palier`, service pour le programme
    Scriptorium) ; un homme par battement ; jamais en bataille ; **rien au rechargement**, sauf le filet ;
  - les noms des préréglages choisis gardés sur la fiche de l'homme ; leurs identifiants écrits dans la liaison par un
    outil du dépôt (comme les âmes).
- **Mesuré en V71 a** (15/10) : les deux appels sont acceptés hors `-devmode` ; une tenue complète remplace l'autre,
  les armes remplacent les armes ; l'inventaire sait compter (`GetCount`, `GetInventoryTable`). **Mais l'équipement posé
  n'est pas gardé au rechargement** : l'homme revient avec la tenue de son personnage. Bloquant pour la règle du 5/10 ;
  principe demandé à la conversation Scriptorium (comment les hommes du mod d'Alex gardent leur inventaire).
- **À mesurer en V71** : les deux appels acceptés hors `-devmode` sur nos hommes ; tenue et armes vues à l'image ; une
  tenue complète posée sur une autre la remplace-t-elle ; l'inventaire revient-il au rechargement ; ce que l'inventaire
  d'un homme sait dire (le jeu n'a pas d'appel « nombre d'objets » dans ses scripts ; il a `GetCountOfClass`, `FindItem`,
  `AddItem`, `CreateItem`) : de quoi bâtir le filet.

## Pourquoi l'équipement n'est pas gardé : diagnostic V71 a2 (avant V71 b ; sans question à JoVenGer, essai seulement)
- **Ce que dit le journal de V71 a** : au rechargement, « Hommes : redressés, 0 revenu(s), 0 manquant(s) », et les ordres
  vont à `scriptorium_Jan_Kladivo` : l'homme rechargé est **le même personnage**, gardé par le jeu, pas refait par le
  socle. C'est donc le jeu qui l'a rhabillé.
- **Ce qui l'habille, relu dans le jeu** (`IPL_GameData.pak`, `Libs/Storm/equipment/`, lecture seule) : les règles
  « Storm » donnent à chaque personnage un préréglage d'inventaire (`setInventory`) selon sa classe sociale, sa faction,
  le nom de son âme, son archétype. Nos âmes (classe 33 « soldier », faction `trosecko_settlements_trosky_soldiers_guards`)
  tombent sous `inventory_combatants_tro` et `inventory_bergovSoldier_tro` (`world/classes.xml`, `world/factions.xml`) ;
  tout homme tombe au moins sous `inventory_default_male` (`world/default.xml`). La tenue n'est pas dans la ligne Skald
  du personnage (`skald_character.xml` : âge, corps, voix, noms ; `unique_assets` vide pour les soldats génériques).
  Le Lua du jeu ne rhabille rien au chargement (`BasicActor.ResetCommon` ne fait que vider `self.AI`) : c'est le moteur.
- **Ce que la conversation Scriptorium a transmis** (principe) : chez JoVenGer le 5/10, 69 tenues sur 69 et les armes de
  mêlée revenues au chargement ; mais 12 archers sur 20 sans arc (Scriptorium réarme donc au chargement un archer sans arc
  et un homme sans arme : **le filet est à prévoir de toute façon**). Ses hommes naissent en classe NPC avec la seule
  âme pour propriété ; leurs âmes pointent vers ses propres personnages Skald.
- **Essai V71 a2, trois hommes côte à côte, un seul changement chacun par rapport au premier** (même tenue lourde
  `soldier_generic_5_01` et mêmes armes `sword_shield_3_01` posées sur les trois, compte avant et après le rechargement,
  comme en V71 a) :
  1. **témoin** : le premier homme du camp (copie des propriétés de la classe, âme de soldat) ;
  2. **la seule âme** (piste du pair) : un homme né avec `{ guidSharedSoulId }` pour seule propriété, sur une âme d'essai
     identique à celle du témoin (`scriptorium_essai_sonde_seule`) ; inerte possible (vu le 14/10), sans effet ici ;
  3. **hors des règles Storm** (la piste Skald du pair, ramenée à ce qui habille vraiment) : né comme le témoin, sur une
     âme d'essai que seule la règle par défaut vise (faction `animalCompanions`, classe 63 « fortuneTeller », toutes deux
     absentes des règles d'équipement ; `scriptorium_essai_sonde_hors_regles`).
  Les deux sondes ne sont pas au registre : le socle ne les touche pas au chargement.
- **Lecture** : si le 2 garde son équipement, la cause est la copie des propriétés ; essai suivant : la copie sans les
  propriétés qui composent le personnage (`esClothingConfig`, `fileModel`), les autres le font vivre. Si le 3 le garde,
  ce sont les règles Storm visant nos âmes ; la faction « la Compagnie » (V72) et une classe hors règles en seraient le
  remède. Si aucun ne le garde : repose depuis le registre, chaque pièce et son état (question à JoVenGer).
- **Mesuré en V71 a2** (15/10) : **les trois reviennent exactement à leur inventaire de naissance** (comptes d'avant
  l'équipement retrouvés homme par homme ; 16 objets avant, 11 après, d'autres identifiants et d'autres états : un
  inventaire régénéré, pas gardé). Les sondes, inconnues du socle, sont gardées par le jeu comme le témoin. **Ni la copie
  des propriétés, ni les règles Storm qui visent nos âmes n'en sont la cause.** Les deux essais ont fait varier l'homme ;
  restent deux axes jamais variés (V71 a3) : **la façon d'équiper** (les deux préréglages viennent de l'outil de combat
  du jeu, `Scripts/Debug/CombatDebug.lua` ; `player.lua` crée l'objet, le met à l'inventaire et le fait porter :
  `ItemManager.CreateItem`, `inventory:AddItem`, `actor:EquipInventoryItem`) et **l'origine du personnage** (un
  personnage du jeu, posé dans le niveau, équipé par le Lua). La piste Skald du pair reste non essayée, après celles-ci.
- **Ce que la conversation Scriptorium a corrigé après V71 a2** (15/10, principe) : les hommes d'Alex sont équipés par
  les mêmes appels de préréglages (`EquipClothingPreset`, `EquipWeaponPreset`), à l'embauche ; le 5/10, « gardée »
  voulait dire « au moins 4 objets après le chargement » : **l'usure n'a jamais été comparée** ; et Scriptorium remet
  après chaque chargement les pièces achetées à la forge, signe qu'elles ne survivaient pas. « Le jeu garde
  l'inventaire » était une hypothèse, non une mesure : la règle du 5/10 (garder l'usure et les réparations) serait
  tenue par une repose depuis le registre, non par le jeu.
- **Essai V71 a3** (diagnostic, deux axes jamais variés, un changement chacun) :
  1. **objet par objet** sur le témoin, à la façon du jeu (`Scripts/Utils/ItemUtils.lua`, `CreateInvItem` ;
     `player.lua`, `CheatGiveSword`) : `inventory:CreateItem(objet, état, 1)`, `inventory:FindItem(objet)`,
     `actor:EquipInventoryItem(id)`, avec un état choisi (0,55 ; 0,45 ; 0,35) pour le relire après le rechargement :
     l'épée militaire portée, l'écu seulement mis à l'inventaire (non porté), une pièce de `soldier_generic_1_01`
     portée ;
  2. **un personnage du jeu** (l'habitant le plus proche d'Henry) habillé par le préréglage `soldier_generic_5_01`,
     comme le témoin en V71 a ; son nom gardé dans un jeton de la sauvegarde pour le retrouver au rechargement.
  Lecture : la création avec état est-elle acceptée, et l'état relu est-il le bon (faisabilité de la repose) ; les
  pièces créées une à une sont-elles gardées (alors l'équipement se fait ainsi, sans repose) ; l'habitant du jeu
  garde-t-il sa tenue (la régénération vise-t-elle tous les personnages, ou ceux nés par script).
- **Mesuré en V71 a3** (15/10) : **les objets créés un à un par `inventory:CreateItem(objet, état, 1)` sont gardés au
  rechargement, chacun avec son état exact** (0,55, 0,45, 0,35 relus avant et après), porté ou non. `ItemManager.CreateItem`
  n'existe pas hors des outils. Les préréglages de l'outil de combat ne tiennent pour personne (l'habitant du jeu perd
  aussi la tenue posée). La tenue de naissance revient à chaque chargement, à côté de nos objets, toujours la même
  (mêmes états qu'en V71 a2). **Conséquence** : la règle du 5/10 (garder l'usure et les réparations) est tenue par le
  jeu lui-même si chaque pièce est créée une à une ; pas de repose depuis le registre. **Non vérifié** : quelles pièces
  l'homme porte après le rechargement (les nôtres, ou celles de naissance revenues) ; à voir de près (V71 a4).
- **Essai V71 a4** (diagnostic) : sur le témoin, les 11 pièces de `soldier_generic_5_01`, l'épée et l'écu créés un à
  un à l'état 0,6, puis portés ; le témoin posé à 3 m devant Henry, face à lui, pour le voir de près (on déplace
  l'homme, jamais Henry). Puis **deux rechargements de suite** (conseil du pair) : à chacun, l'inventaire trié (nos
  pièces : objet de la tenue et état 0,6 ; les autres) et une vue de près. Enfin nos pièces refaites porter
  (`EquipInventoryItem`) et revues. Lecture : ce qu'il porte après le rechargement ; la tenue de naissance s'empile-t-elle
  (alors la retirer à chaque entrée en partie, sans toucher à nos pièces) ; refaire porter suffit-il.
- **Mesuré en V71 a4** (15/10) : nos 13 pièces créées une à une restent à l'inventaire après un puis deux
  rechargements (état 0,6 gardé) ; **mais à chaque chargement le jeu rhabille l'homme de sa tenue de naissance** : nos
  pièces ne sont plus portées. La tenue de naissance **ne s'empile pas** (11 objets après chaque chargement). **Refaire
  porter nos pièces marche** (13 sur 13, vu de près) ; une pièce de naissance dont la place n'est pas prise par une des
  nôtres reste portée (le tabard rouge). Pour un aspect net, il faudrait aussi ôter ou retirer la tenue de naissance à
  chaque entrée en partie (non essayé). **Ceci touche la règle validée « rien au rechargement »** : question à JoVenGer.
- **Question à JoVenGer (V71 b, après V71 a2 à a4) : cochée le 15/10/2026, réponse a (« Remettre et retirer »)** : la règle du 5/10 disait « pas de rhabillage au chargement, parce
  que le jeu garde l'inventaire ». Mesuré : le jeu garde bien les **pièces** (créées une à une, avec leur usure et donc
  les réparations), mais pas le fait de les **porter** : à chaque chargement il rhabille l'homme de sa tenue de
  naissance. Refaire porter les mêmes pièces ne perd ni usure ni réparation : l'esprit de la règle tient, pas sa lettre.
  Le but de la règle (même allure, usure et réparations gardées, rien de tiré au hasard) est tenu si **chacun remet ses
  propres affaires** à chaque chargement (présentation du pair, 15/10).
  a) **à chaque entrée en partie, chaque homme remet ses propres pièces, et la tenue de naissance revenue est retirée**
     (aspect net ; elle revient à chaque chargement sans s'empiler, le joueur n'y perd rien). Nos pièces reconnues par
     leurs identifiants notés au registre à leur création, jamais par leur état (l'usure change en jeu) ; une pièce à
     nous n'est jamais retirée. Un homme par battement, après l'entrée en partie, jamais en bataille. À mesurer d'abord
     en V71 b : l'identifiant d'un objet reste-t-il le même après un rechargement, et le retrait — recommandé ;
  b) refaire porter seulement (les pièces de naissance aux places non prises restent portées, le tabard par exemple) ;
  c) chercher encore une ou deux séances à empêcher le jeu de rhabiller (préréglage d'inventaire de l'âme, directives
     Storm) : incertain ;
  d) rien au chargement : les hommes reviennent en tenue de naissance, leur équipement dans le sac.
- **Essai V71 a5** (avant V71 b, les deux points ouverts de la réponse a) : sur le témoin, les 13 pièces créées une à
  une ; leurs identifiants (texte de l'identifiant d'objet) notés dans un jeton de la sauvegarde. Après un rechargement :
  nos pièces reconnues par identifiant (et, pour contrôle, par objet et état 0,6) ; puis **rangement** : nos pièces
  refaites porter, toutes les autres retirées (`inventory:DeleteItem(id, 1)`, forme de
  `Scripts/Entities/WH/Triggers/TriggerBase.lua`), vu de près ; puis un second rechargement. Garde-fou : si une seule
  de nos pièces n'est pas reconnue par son identifiant, rien n'est retiré. Lecture : l'identifiant tient-il ; le retrait
  marche-t-il ; la tenue de naissance revient-elle après un retrait.
- **Mesuré en V71 a5** (15/10) : **l'identifiant d'un objet change à chaque chargement** (0 de nos 13 pièces reconnues
  par identifiant après le rechargement, 13 par objet et état). Le garde-fou a joué, rien n'a été retiré. Nos pièces ne
  peuvent donc pas être reconnues par un identifiant noté ; le retrait reste à mesurer.
- **Essai V71 a6** : la tenue de naissance régénérée a été la même dans toutes les séances (mêmes objets, mêmes états à
  six décimales : 0,121384, 0,130205, 0,133178…), mais toujours lue après un rechargement, jamais à la naissance. Si elle
  est aussi la même à la naissance, on la reconnaît par sa **signature** (objet et état de chaque pièce) notée à
  l'embauche, et « à lui » est tout le reste. L'essai : relevé complet de l'inventaire du témoin à la naissance, avant
  tout, noté dans un jeton ; les 13 pièces créées (état 0,6) et portées ; rechargement, relevé, comparaison ; rangement
  par signature (ses pièces refaites porter d'abord, puis les pièces de la signature retirées une à une, recompte après
  chaque retrait ; garde-fous : rien si les pièces « à lui » ne sont pas exactement nos 13) ; vue de près ; second
  rechargement : la tenue de naissance revient-elle, toujours la même, nos 13 toujours là.
- **Mesuré en V71 a6** (15/10) : la signature de naissance (11 pièces) est la même à la naissance et après le
  rechargement, et la reconnaissance par signature est exacte (11 sur 11, nos 13 à part, une pièce de même objet que
  l'une des nôtres départagée par l'état). Le retrait marche (10 sur 10 ; la bourse, une pile de pièces de monnaie,
  n'est pas une pièce de tenue : à laisser). **Une fois retirée, la tenue de naissance ne revient pas** : elle n'était
  pas régénérée mais gardée, comme nos pièces ; ce que le jeu fait au chargement, c'est **ne remettre portées qu'une
  partie des pièces et ôter les armes** (après le second rechargement : gambison, chapel, gants ; ni écu ni épée).
  **Conséquences pour V71 b** :
  1. à l'embauche (et à la naissance d'un homme sans fiche d'équipement), la tenue de naissance est retirée **une fois**,
     reconnue sans ambiguïté puisqu'elle est tout ce que l'homme a avant qu'on lui crée ses pièces (la bourse gardée) ;
     **retirer d'abord, faire porter ensuite** (fait dans l'autre ordre, des pièces de naissance encore portées gênent :
     la tenue lourde n'est complète qu'au second rangement) ;
  2. à chaque entrée en partie, **refaire porter toutes ses pièces**, armes comprises (un homme par battement, jamais en
     bataille) : c'est la réponse a de JoVenGer ; le « retrait de la tenue de naissance revenue » devient sans objet,
     sauf pour un homme embauché avant V71 b (retrait une fois, par la même règle) ;
  3. ni identifiant noté (il change à chaque chargement), ni signature à garder : le registre garde seulement les noms
     des préréglages et la famille, les pièces données plus tard étant ajoutées à sa fiche par le service du guichet.
- **Objection du pair au point 3 (15/10), retenue** : « refaire porter toutes ses pièces » laisse au hasard de l'ordre
  des appels ce qu'il porte dès qu'il a deux pièces pour une même place (armure de la forge et ancienne dans le sac,
  arme de rechange) : c'est le rhabillage au hasard refusé le 5/10. Sa fiche garde donc **ce qu'il porte**, dans l'ordre.

## V71 b : l'équipement pièce par pièce (proposé, d'après V71 a à a6 et la réponse a de JoVenGer)
- **Les pièces des préréglages** : un outil du dépôt (`outils/equipement.py`) lit en lecture seule dans `Tables.pak`
  les objets de chaque préréglage retenu (`clothing_preset.xml` : `<Items><Guid>` ; `weapon_preset.xml` :
  `weapon_preset_item item_class_id`), vérifie chaque objet dans `item.xml`, et écrit dans `liaison` un bloc de données :
  `liaison.pieces_des_prereglages[nom] = { objet, … }`. Les arcs et arbalètes de la règle (pas de préréglage du jeu à
  leur mesure) y sont écrits de même, objet par objet, avec leurs munitions (nombre). Plus besoin de
  `weapon_preset__scriptorium_socle.xml`. Préréglages retenus : ceux de la section validée ci-dessus (tenues
  `soldier_generic_1` à `6` sans `_crimeScene` ; les six familles par niveau ; pavois peint pour le pavoisier).
- **Règles en données** (catalogue de `reglages.lua`) : tenue par palier (1 → `soldier_generic_1` ou `2`, 2 → `3` ou
  `4`, 3 → `5` ou `6`) ; familles et préréglages par palier ; arcs et arbalètes par palier ; état des pièces neuves
  (1 par défaut).
- **La fiche de l'homme** garde : sa famille (tirée à l'embauche, à vie), ses deux préréglages (tenue, armes), les
  pièces données ensuite (`en_plus`, dans l'ordre, objet seulement) et celles qu'il ne porte plus (`otees`). **Ce qu'il
  porte** = pièces de la tenue, puis des armes, puis `en_plus`, moins `otees` : une liste ordonnée d'objets, la dernière
  pièce d'une même place l'emportant, toujours la même. Ni identifiant (il change à chaque chargement, V71 a5), ni état
  (le jeu le garde, V71 a3).
- **À l'embauche** (et pour un homme embauché avant V71 b, une fois) : un homme par battement, jamais en bataille ;
  **retirer d'abord sa tenue de naissance** (tout ce qu'il a, sauf la bourse), puis créer chaque pièce une à une
  (`inventory:CreateItem(objet, état, nombre)`), puis lui faire porter ce qu'il porte, dans l'ordre.
- **Au changement de grade** (`hommes.changer_de_palier`, service pour le programme Scriptorium) : nouveaux préréglages
  de la même famille, créés et portés ; les pièces `en_plus` gardées. **Les pièces de l'ancien grade** (objets de
  valeur ; rien ne se perd sans raison) : question à JoVenGer ci-dessous ; tant qu'il n'a pas répondu, elles passent
  par l'accroche « pièce ôtée » et restent dans le sac de l'homme si personne ne les prend ; rien n'est détruit.
- **Munitions** (pair, 15/10) : flèches et carreaux s'usent au combat ; l'essai mesure si le nombre d'un homme baisse
  après un tir. Si oui, à chaque entrée en partie, ses munitions sont complétées jusqu'au nombre de son préréglage (plus
  tard, le programme Scriptorium pourra les prendre sur le stock du camp, par une accroche).
- **Question à JoVenGer (pièces de l'ancien grade, proposée par le pair) : cochée le 15/10/2026, réponse a (« Rendues au camp »)** : a) rendues au camp par l'accroche « pièce
  ôtée », pour que le programme Scriptorium les range dans la réserve de l'armurerie ou les vende (recommandé) ;
  b) détruites.
- **À chaque entrée en partie** (réponse a) : chaque homme, un par battement, jamais en bataille, se voit refaire porter
  ce qu'il porte : pour chaque objet de la liste, dans l'ordre, une pièce de cet objet est cherchée dans son sac
  (`FindItem`) et portée. Une pièce introuvable est notée au journal, jamais recréée au hasard. **Filet** (règle du
  5/10) : s'il n'a plus aucune pièce de sa tenue de corps ou plus d'arme principale, ses préréglages sont recréés.
- **Pour le guichet** : `hommes.donner_une_piece(nom, objet, état, porter)` crée la pièce dans son sac et, si elle est
  portée, l'ajoute à `en_plus` ; `hommes.piece_otee(nom, objet)` (vendue, cassée, perdue) l'ajoute à `otees`.
- Gens de métier et Directeur : rien (leur tenue de naissance), comme validé.
- **Essai V71 b** : trois hommes embauchés (un par grade), vus de près ; deux rechargements ; un changement de grade ;
  une pièce donnée par le service ; un homme d'avant V71 b équipé une fois.
- **Acquis en V71 b** (15/10) : équipement à l'embauche (tenue de naissance retirée, pièces créées et portées), pièces
  toutes présentes après deux rechargements, flèches gardées (25/25), changement de grade (nouvelles pièces, anciennes
  dans le sac), pièce donnée et portée.
- **À revoir après V71 b (V71 c)** :
  1. **retirer les piles entières** de la tenue de naissance (carreaux : `DeleteItem(id, 1)` n'en ôte qu'un ; 49 carreaux
     pour 20) : `DeleteItem(id, nombre)`, le nombre lu par `ItemManager.GetItem(id).amount` ; la bourse toujours gardée ;
  2. **même allure après la remise qu'à l'embauche** : refaire porter une pièce déjà portée semble l'ôter (bascule) ;
     la remise ôte donc d'abord toutes ses pièces (`UnequipInventoryItem`), puis les remet dans l'ordre ;
  3. **pièces données (`en_plus`) avec leur dernier état connu** (pair, 15/10 ; règle « ce qu'il a acheté est à lui »,
     `armures_de_la_forge`) : à chaque entrée en partie, l'état de chacune est relu (`ItemManager.GetItem(id).health`) et
     noté sur la fiche ; un personnage refait les retrouve, recréées avec cet état (1 sans état connu, écrit au journal),
     au lieu de les perdre.
- **Essai V71 c** : quatre hommes dans les quatre paillasses (homme d'armes et arbalétrier au palier 1 ; pavoisier et
  homme d'armes d'hast au palier 3, arme sortie, pour les réponses 2 et 3 de JoVenGer) ; carreaux comptés (20 attendus) ;
  **la bascule éprouvée seule** (conseil du pair) : sur le premier homme équipé, ses pièces refaites porter sans les ôter,
  vu, puis une seconde fois, vu ; puis rechargement : l'allure après la remise (ôter puis remettre) comparée à celle de
  l'embauche.
- **Mesuré en V71 c** (15/10) : piles de naissance retirées entières (carreaux 20/20) ; **pas de bascule** : un seul
  passage juste après la création ne fait pas tout porter (Jan sans chausses), un second passage complète la tenue, un
  troisième ne change rien ; après la remise (ôter puis remettre), même tenue sauf le chapel. **En attente** (deux remèdes
  essayés sur l'allure, arrêt selon la règle anti-boucle) : savoir pourquoi un passage ne suffit pas (hypothèses : le jeu
  n'applique pas tout dans le même instant ; des pièces d'une même tenue se disputent une place et l'ordre décide) avant
  un troisième remède ; voir le pavois et l'arme d'hast (« sortir son arme » tire l'arme courte).
- **Éléments de la conversation Scriptorium après V71 c** (15/10, principe) :
  - arme d'hast chez Alex : ses préréglages d'hast ne contiennent que l'arme d'hast, sans arme courte ; l'homme n'a
    rien d'autre à sortir. L'arme rangée invisible n'est pas réglée chez lui, seulement notée. Pavois : ni Alex ni
    Scriptorium n'en ont ;
  - pour voir pavois et arme d'hast : un vrai combat (ordre d'attaque contre un brigand léger, comme en V54), le cerveau
    de combat choisissant ce qu'il prend en main, plutôt que `DrawWeapon` au repos ;
  - l'allure, deux pistes éprouvables dans un même essai : **deux passages séparés par un battement** (le second passage
    de V71 c a complété la tenue) ; **l'ordre des couches** (dessous : chemise, chausses, gambison, coiffe ; puis dessus :
    cotte, plates, casque ; puis armes), la coiffe mise après le chapel pouvant l'ôter.
- **Troisième remède sur l'allure : accordé par JoVenGer le 15/10/2026 (V71 d : couches dans l'ordre, second passage au battement suivant, combat pour voir pavois et arme d'hast)** ; **l'arme courte de l'homme d'hast est gardée** (réponse de JoVenGer, même jour).
- **V71 d (fait au banc, à essayer)** : l'outil écrit les pièces de chaque tenue **des dessous aux dessus** (couche de
  la place, `equipment_slot.xml` ; type de la pièce, début de son modèle `Clothing` ; toutes les pièces de nos 78
  tenues ont une couche connue ; Jan : gambison, chausses, souliers, coiffe, puis brassards, chapel, gants) ; après
  l'équipement comme après la remise, **un second passage au battement suivant** (état « à compléter »), puis l'accroche
  « après le rhabillage » ; un homme vu peut attaquer le brigand du jeu (ordre 8 de V54, même cerveau) pour voir ce
  qu'il prend en main.
- **Mesuré en V71 d** (15/10) : à l'embauche, tenue complète du premier coup ; après le rechargement, même allure pour
  l'homme d'armes et l'arbalétrier (chapel compris), mais **la cotte de dessus (couche 4) du pavoisier et de l'homme d'hast
  est perdue** ; en combat, **l'homme d'hast prend son épée**, pas l'arme d'hast ; pavois pas vu (le brigand du jeu a
  mis nos hommes à terre). **En attente de JoVenGer** : un quatrième essai sur l'allure (deux passages sans rien ôter,
  puisqu'il n'y a pas de bascule) et la façon de voir pavois et arme d'hast.
- **Réponses de JoVenGer après V71 d (15/10/2026)** : **quatrième essai accordé** (au chargement, deux passages sans rien
  ôter) ; **l'arme courte de l'homme d'hast est enlevée, comme chez Alex** (il n'a que l'arme d'hast et la prend au
  combat ; au repos elle ne se voit pas). La piste du pair (choix de l'arme par la compétence, `AdvanceToSkillLevel`) est
  notée, sans objet après cette réponse. La pièce manquante après le combat (11 sur 12) est à identifier (V71 e) avant
  une question sur les pièces tombées en combat.
- **V71 e (fait au banc, à essayer)** : remise sans rien ôter, deux passages ; préréglages d'hast réduits à l'arme d'hast
  (`item.xml`, `MeleeWeapon Class="7"` ; ex. `polearm_4_02` : la bardiche seule) ; le relevé du poste nomme les pièces
  manquantes. Essai : quatre hommes vus de près avant et après un rechargement ; puis l'homme d'hast contre le brigand du
  jeu ; pièces manquantes relevées après le combat.
- **Mesuré en V71 e** (15/10) : homme d'armes, arbalétrier et pavoisier ont la même allure avant et après le
  rechargement ; **l'homme d'hast se bat avec son arme d'hast** (réponse de JoVenGer vérifiée) ; aucune pièce manquante
  après le combat. **Reste** : la cotte de dessus du pavoisier n'est plus portée, même à l'embauche, et son camail
  disparaît après le rechargement. Quatre essais faits sur l'allure : **arrêt** (règle anti-boucle) ; piste pour plus
  tard, à lire d'abord : `Libs/Tables/Character/ClothingHidingGroup.xml` (le jeu masque des couches selon l'ensemble
  porté) ; le pavois reste à voir en main.
- **Réponses de JoVenGer après V71 e (15/10/2026)** : **les six tenues du palier 3 qui superposent une cotte, une
  brigandine ou une cuirasse et une cotte de mailles sont retirées du tirage** (`soldier_generic_5_02`, `5_05`, `5_12`,
  `6_01`, `6_03`, `6_04` ; 15 tenues restent au palier 3 ; liste `hommes.equipement.tenue.exclues`, vérifiée par le banc) ;
  **un essai de combat du pavoisier** pour voir s'il prend son pavois (V71 f) ; s'il ne le prend pas, question : un
  bouclier ordinaire en attendant, ou le pavois laissé tel quel.
- **Mesuré en V71 f** (15/10) : les tenues tirées au palier 3 ne sont plus parmi les exclues ; **le pavoisier se bat avec
  son pavois au bras gauche** et son coutelas en main : réponse 3 de JoVenGer vérifiée. Pas de question à poser.

- **Vu en V73 b 1 (16/10) : des hommes dévêtus en pleine partie, sans chargement.** Les trois hommes, équipés à
  l'embauche (tenue de naissance retirée, pièces créées et portées), assis au feu :
  - Jan Kladivo, habillé à l'ordre d'attaque (capture), revient du combat **torse nu** : ses 9 pièces sont toujours
    dans son sac (`essai_equipement_voir`), mais plus portées ; `essai_equipement_reporter_sans_oter` les lui remet, et
    il est rhabillé (casque, gambison, gants) ;
  - Mikuláš le Rouge se bat **en simple tunique**, sans casque ni cape, dès le début du combat ;
  - Ondřej de Sázava, **qui ne s'est pas battu**, est torse nu à 16 h 40 (habillé vers 16 h 35, juste après son
    équipement) ; aucune ligne du socle ne touche à sa tenue entre les deux.
  - Ce que cela rappelle : à chaque chargement, le moteur rhabille l'homme de sa tenue de naissance (V71 b). Ici, en
    pleine partie, le moteur semble remettre la tenue de l'âme dans d'autres situations (au combat, et une autre, pas
    encore connue) ; nos pièces sont alors ôtées, et la tenue de naissance, retirée à l'embauche, ne peut plus revenir :
    l'homme reste à moitié nu. **Hypothèse, non vérifiée.**
  - Pistes relevées dans le jeu (`Data/Scripts.pak`, lecture seule, rien d'extrait) : `EquipClothingPreset` et
    `GetInitialClothingPreset` (`Scripts/Debug/CombatDebug.lua`) : le jeu habille ses personnages par un préréglage de
    tenue ; le nœud d'arbre `ClothingPresetOverride` (424 emplois dans les quêtes) ; `Function_item_findEquippedItem`
    (`AI/item/equipItemByCategory.xml`), une lecture de ce qui est porté.
  - **Ouvert, à décider avec JoVenGer** : trouver ce qui déclenche ce rhabillage, puis le remède (remettre nos pièces
    quand il arrive, ou donner à nos âmes un préréglage de tenue qui soit le nôtre).
  - **Décision de JoVenGer (16/10)** : finir V73 b (le plafond de relances, l'arbitre), puis la tenue, avec sa fiche.
  - **Principe transmis par le pair (mécanisme seulement)** : Alex habille par préréglage (`EquipClothingPreset`), à
    l'embauche et à chaque rhabillage ; pièce par pièce seulement pour une tenue faite de pièces données par le joueur.
    Le moteur connaît le préréglage comme la tenue de l'homme : quand il rhabille de lui-même, il remet ce préréglage,
    et l'homme reste vêtu. Deux défauts chez lui : un préréglage posé par-dessus des pièces données ne les retire pas
    (tout se mélange) ; une tenue faite de pièces, défaite sans cesse, était remise en boucle. Scriptorium remet les
    armures de la forge après chaque rhabillage (`armures_de_la_forge`), avec un filet : un homme revenu presque nu
    (moins de 4 objets) est rhabillé.
  - **Recommandation du pair, une chose à la fois** : d'abord une garde de la tenue, qui compare ce que l'homme porte à
    sa liste et lui refait porter ce qui manque (`EquipInventoryItem`, sans rien créer), à la fin d'un combat, à la
    sortie d'un lit, et de temps en temps, un homme par battement ; ensuite seulement, si JoVenGer le veut, la cause.
- **Levier noté, sans question** (proche de la réponse c, non retenue) : une âme sans tenue de naissance ôterait le
  problème pour les combattants (rien à retirer, tout est à lui) ; la sonde « hors règles » de V71 a2 est née sans aucune
  des pièces comptées. À reprendre seulement si la signature se montre fragile.
- **Ce qui change sans question** (la règle reste celle validée) : la façon d'équiper (pièce par pièce au lieu des
  préréglages de l'outil de combat ; le contenu des préréglages lu dans les tables du jeu par un outil du dépôt) ; le
  registre ne garde que les noms des préréglages (et la famille) de chaque homme, le jeu gardant l'usure ; le filet des
  archers est compris dans la repose au chargement si a ou b.
- **Pour le guichet** (pair, 15/10, sans question) : les pièces données plus tard par le programme Scriptorium (forge,
  butin, armure d'un gradé) sont elles aussi « à lui » : un service « donner une pièce à un homme » la crée une à une,
  avec son état, et la note sur sa fiche ; une accroche « pièce retirée ou perdue » la sort de la fiche (vendue,
  cassée). Sinon elle serait retirée comme la tenue de naissance, ou jamais remise.
- **Le chemin d'équipement qui en découle** (pair, 15/10) : lire dans les tables du jeu la liste des objets de chaque
  préréglage (`clothing_preset.xml`, `weapon_preset.xml`) par un outil du dépôt, et créer chaque pièce une à une ; les
  choix de JoVenGer (préréglages par grade et par famille) restent valables tels quels.
- **Pour la repose, s'il le faut** : le jeu crée un objet avec son état (`ItemManager.CreateItem(identifiant, état,
  nombre)`, `Scripts/Utils/ItemUtils.lua`) ; reste à savoir **lire** l'état d'une pièce portée : la sonde relève ce que
  rendent `inventory:GetInventoryTable()` et les fonctions d'`ItemManager` sur le témoin. **Vu en V71 a2** : l'état se lit
  (`ItemManager.GetItem(id)` rend `health`, `amount`, `class`, `entity`) ; `ItemManager.CreateItem` n'apparaît pas dans la
  liste des fonctions d'`ItemManager` (à vérifier par l'appel). Si la repose est retenue : ne pas garder l'identifiant de
  chaque pièce (300 hommes × 16 pièces × 42 octets dépassent 65 535 octets, même en tranches) mais le nom du préréglage
  et l'état de ses pièces dans l'ordre ; retirer d'abord l'inventaire régénéré.
- Recherches « Réutiliser avant de créer » (deux, sur les personnages Skald d'un mod et l'équipement gardé) : rien de
  propre à KCD2.

## La garde de la tenue (16/10, après V73 b ; en relecture par le pair)
- **Le constat** (V73 b 1 et V73 b 3) : en pleine partie, sans chargement, des hommes perdent leur tenue : les pièces
  restent dans leur sac, mais ne sont plus portées. Jan revenu du combat torse nu ; Mikuláš en simple tunique pendant le
  sien ; Ondřej puis Jan, **assis au feu sans s'être battus**, torse nu. Remettre les pièces (`EquipInventoryItem`) les
  rhabille aussitôt.
- **L'hypothèse** (non vérifiée) : le moteur remet la tenue de l'âme dans certaines situations, comme il le fait à
  chaque chargement (V71 b) ; or la tenue de naissance est retirée à l'embauche : il ne reste rien à remettre.
- **Ce que le socle a déjà** : le rhabillage du chargement. Un homme marqué « à rhabiller » remet ses propres pièces au
  battement (`rhabiller`, puis un second passage), un homme à la fois, jamais en bataille ; puis l'accroche « après le
  rhabillage » (Scriptorium y remet les armures de la forge, `armures_de_la_forge`).
- **Ce qu'on ne sait pas lire** : si une pièce est portée. `ItemManager.GetItem(id)` rend l'état, la quantité, la classe
  et l'entité, sans marque « portée » (V71 a2) ; le jeu n'a pas d'appel Lua de lecture (relevé du 16/10). Mais remettre
  une pièce déjà portée ne l'ôte pas (V71 c) : la remise est sans danger, même à l'aveugle.

### Comment ce serait fait (principe du pair : la garde d'abord, la cause ensuite)
- **La garde de la tenue** (`hommes`) remet à un homme ses propres pièces, sans rien créer ni rien ôter :
  1. **à la fin d'un combat** (relecture du pair : un signal direct, comme chez Alex) : le switch retient à chaque tour
     si l'homme est en combat (contexte `crime_interruptAttack`, qu'il lit déjà) ; le tour où il ne l'est plus, il
     augmente un compteur de cerveau `scriptorium_fins_de_combat`, relu par le battement comme les arrêts de V73 b 2 ;
     à la hausse, l'homme est marqué « à rhabiller » : le chemin du chargement, avec sa ligne au journal et l'accroche.
     **En filet**, une hausse du compteur des lancements (`scriptorium_essai_rejoint` : un comportement tué, par un
     combat ou autre chose) marque aussi l'homme ; rhabiller est sans danger ;
  2. **à la sortie du lit** : quand l'activité d'un homme passe du sommeil à autre chose (proposé par le pair), même
     marque ;
  3. **et en tournant, un homme par battement** (nombre réglable), pour les cas qu'on ne connaît pas encore (Ondřej) :
     une remise directe et silencieuse, comptée au rapport du battement (sinon une ligne par homme toutes les quelques
     minutes : la leçon des 341 lignes d'Alex).
- **Jamais** : en bataille ni en combat (le rhabillage du chargement attend déjà la fin de la bataille ; un homme en
  combat ou en conversation est laissé pour le tour suivant) ; **au lit** (un homme couché n'est pas rhabillé ; la sortie
  du lit s'en charge) ; **au bain**, ou sous toute règle qui veut l'homme dévêtu (chez Scriptorium, l'homme se dévêt pour
  le bain, `mercenaires_aux_bains`, `bain_et_lavoir`) : une tenue de l'arbitre peut porter la marque « ne pas
  rhabiller » (`quoi.ne_pas_rhabiller`), et la garde saute l'homme tant que cette tenue le tient.
- **Pour le guichet** (proposé par le pair) : un service « rhabiller cet homme maintenant » (`hommes.rhabiller(id)`),
  pour la sortie du bain, un achat à la forge, un changement de grade.
- **La cause** viendra ensuite, si JoVenGer le veut : trouver ce qui remet la tenue de l'âme (le préréglage de tenue de
  nos âmes, le nœud `ClothingPresetOverride`), avec une sonde et ses captures.
- Valeur en données : `hommes.reglages.tenue_garde_par_battement` (1).
- **Essais au banc** : une hausse des fins de combat marque l'homme, une hausse des lancements aussi ; la sortie du lit
  aussi ; la remise en tournant passe par chacun à son tour, rien n'est créé, rien n'est dit au journal ; rien en
  bataille, en combat, au lit, ni sous une tenue « ne pas rhabiller » ; le service du guichet rhabille aussitôt. Au banc
  statique : le switch compte les fins de combat au front descendant du contexte de combat.
- **En jeu** : un homme assis à qui l'on fait attaquer le brigand : rhabillé dans la minute qui suit le combat ; les
  autres, laissés assis 10 min : jamais plus d'un tour sans tenue ; captures avant et après.

### Questions à JoVenGer (après relecture par le pair)
1. **Le remède** : (a) la garde de la tenue : remettre à l'homme ses propres pièces, sans rien créer (Recommandé, principe
   du pair) ; (b) chercher d'abord la cause, avant tout remède (plusieurs séances, les hommes restent dévêtus d'ici là) ;
   (c) habiller par préréglage, comme Alex : l'usure et les réparations de chaque pièce seraient perdues à chaque
   chargement (V71 a), contre la règle de JoVenGer du 5/10.
2. **Quand la garde passe** : (a) à la fin d'un combat (le lancement en filet), à la sortie du lit, et un homme par
   battement en tournant ; jamais au lit, au bain ni en combat (Recommandé) ; (b) seulement en tournant, un homme par
   battement ; (c) seulement à la fin d'un combat.
- Relu par le pair le 16/10 : la garde est la bonne recommandation ; ses apports sont dans la section ci-dessus.
- **Réponses de JoVenGer (16/10)** : 1 (a) la garde de la tenue ; 2 (a) à la fin d'un combat (la relance en filet), à la
  sortie du lit, et un homme par battement en tournant ; jamais au lit, au bain ni en combat.

### La garde de la tenue, faite (16/10)
- **Le switch** compte les fins de combat (`scriptorium_fins_de_combat`) au front descendant du contexte de combat, lu à
  chaque tour (contrôlé au banc statique).
- **Le battement** relit, par homme, les arrêts, les fins de combat et les lancements (un seul appel) ; une fin de combat,
  ou une relance en filet, marque l'homme « à rhabiller » (une ligne au journal) ; le premier relevé après le réveil ne
  marque personne. **La sortie du lit** marque de même. Le rhabillage du chargement fait le reste, dans le même
  battement si l'homme est libre (la ligne « a remis ses affaires », le second passage, l'accroche).
- **En tournant** : `tenue_garde_par_battement` (1) homme prêt par battement remet ses pièces en silence (compté au
  rapport du battement) ; l'homme que le rhabillage vient de traiter est sauté.
- **Jamais** : au lit (sa place est un lit), sous une tenue « ne pas rhabiller » (le bain), en combat ou en conversation ;
  l'homme attend son tour, et un homme embauché la nuit, déjà au lit, est équipé à son lever. La garde n'est lue que
  pour un homme qui a quelque chose à faire (elle interroge l'arbitre).
- **Service du guichet** : `hommes.rhabiller(id)`, aussitôt si l'homme est libre, sinon marqué pour plus tard.
- Banc : 2 544 vérifications ; garde-fous éprouvés par erreurs injectées (la sortie du lit, l'exception du lit).
- **Grille de l'essai en jeu, écrite avant la séance** (`playline3`, secours coupé ; les trois hommes équipés, ce qui
  prend environ 3 min, un homme par battement et deux passages chacun ; puis assis au feu) :
  1. le premier attaque le brigand posé hors du camp ; le combat fini, au journal « à rhabiller (fin de combat) » puis
     « a remis ses affaires », et à l'image il est habillé dans la minute → bon ;
  2. les autres, laissés assis 5 min, captures toutes les 90 s : jamais dévêtus plus d'un tour (un tour de 3 hommes,
     90 s) → bon ;
  3. un homme dévêtu après « a remis ses affaires » → la remise ne rhabille pas en jeu : lire le journal et la tenue de
     l'homme, un seul changement.

### Mesuré en V71 g (16/10)
- **Issue 1** : Jan attaque le brigand ; le combat fini (moins de 17 s), le switch compte la fin de combat (0 → 1), le
  battement marque « à rhabiller (fin de combat) » puis « a remis ses affaires (9 pièce(s)) » dans le même battement ;
  revenu s'asseoir en 41 s, il est habillé (casque, gambison, gants, bouclier).
- **Issue 2, en partie** : les trois, assis 6 min, une capture toutes les 90 s, sont toujours habillés. Mais aucun ne
  s'est dévêtu sans combat pendant ce temps : la garde en tournant n'a pas été vue rhabiller quelqu'un (elle l'est au
  banc). À regarder aux prochaines séances : un homme dévêtu sans combat, et rhabillé dans le tour qui suit.
- **Vu en V73 d 2 (17/10)** : l'archer, à l'exercice, sans combat ni changement d'ordre, habillé sur deux vues d'un tour
  de vue puis torse nu sur les deux suivantes (arc et carquois gardés ; état « prêt », 13 pièces dans son sac) ; 90 s
  plus tard, rhabillé. Aucune ligne au journal (le tour est silencieux) : sans doute par le tour (trois hommes, un par
  battement), non prouvé. La cause du déshabillage reste à chercher, si JoVenGer le veut.
- La garde de la tenue est en place ; la cause du déshabillage reste à chercher, si JoVenGer le veut.
- **Changement visible, contrepartie de « jamais au lit »** : un homme au lit (embauché la nuit, ou blessé au repos dans
  son lit) n'est équipé, rhabillé ou changé de grade qu'à son lever ; l'accroche « après le rhabillage » de Scriptorium
  (les armures de la forge) est différée d'autant. Avant, il était équipé couché, au battement suivant.

## Essais prévus (un changement chacun, partie d'essai `playline3`)
- **V70** : les hommes du camp nés sur nos âmes (notre cerveau, soldats du jeu, classe 33, faction provisoire du
  marcheur) ; ceux d'une partie déjà en cours, nés sur une âme empruntée, renaissent sur une âme à nous à l'entrée en
  partie ; le Directeur aussi. Ils reçoivent l'ordre 10 (s'asseoir sur les bancs du camp), puis l'ordre 11 (se coucher
  dans leur paillasse). La mesure « deux hommes sur la même âme » est abandonnée : une âme par homme dans tous les cas.
- **V71** : l'équipement de départ par le Lua (`EquipClothingPreset`, `EquipWeaponPreset`) : accepté hors `-devmode` ?
  vu à l'image ? gardé au rechargement ?
- **V72** : la faction « la Compagnie » : sa fiche est la fiche 14 (`14_compagnie.md`). **Le dernier point de V71 y est
  fermé** (V72 b, 16/10) : les flèches s'usent au tir (25 → 22 → 18) et le socle les complète à l'entrée en partie
  (18 → 25).
  À prévoir dans sa fiche (conversation Scriptorium, 15/10) : (1) dans un de ses combats, un archer contre le brigand,
  **les flèches comptées avant et après le tir** (dernier point de V71) ; (2) **les crimes d'Henry** (idée validée n° 2,
  rattachée à la faction) : les hommes de la Compagnie ne dénoncent jamais Henry et ne l'attaquent jamais pour un crime ;
  seuls le duel et le pugilat sont hostiles, le temps du combat ; essai : Henry commet un petit délit devant un homme
  de la Compagnie ; (3) **la classe sociale** : vérifier que les règles d'équipement Storm ne visent pas la Compagnie
  (piste de V71 a2).
- Plus tard, si la question 1 b ou après : nos propres personnages (le visage à mesurer).

## Règles en données (catalogue de `reglages.lua`, règle de JoVenGer du 14/10)
- Les identifiants d'âmes, de tenues et d'armes restent dans les tables du mod et dans `liaison` : ce ne sont pas des
  règles, et le catalogue ne prend que des nombres.
- Au catalogue : la part de chaque palier à l'embauche si le programme ne la donne pas, et plus tard l'équipement de
  départ par rôle et par palier (par numéro de préréglage dans une liste).

## Sources
- Paks du jeu, en lecture seule : `Tables.pak` (`Libs/Tables/rpg/soul*.xml`, `SoulPool.xml`, `social_class.xml`,
  `soul_crime_role.xml`, `Libs/Tables/skald/skald_character.xml`, `Libs/Tables/item/InventoryPreset*.xml`,
  `clothing_preset*.xml`, `weapon_preset*.xml`), `Scripts.pak` (`Scripts/Debug/CombatDebug.lua`,
  `Scripts/Utils/ItemUtils.lua`, `Scripts/Entities/actor/player.lua`, `BasicActor.lua`, `BasicAI.lua`, `NPC.lua`),
  `IPL_GameData.pak` (`Libs/Storm/equipment/world/default.xml`, `classes.xml`, `factions.xml`, `Libs/Storm/common/base.xml`).
- Appels vérifiés en jeu hors `-devmode` (V71 a à a4) : `inventory:CreateItem(objet, état, nombre)`, `inventory:FindItem`,
  `inventory:GetInventoryTable`, `inventory:GetCountOfClass`, `ItemManager.GetItem(id)` (`health`, `amount`, `class`),
  `actor:EquipInventoryItem(id)`, `actor:EquipClothingPreset`, `actor:EquipWeaponPreset` (acceptés, mais non gardés).
  **`ItemManager.CreateItem` n'existe pas hors des outils** (`nil`), bien que des scripts du jeu l'emploient.
- Programme Scriptorium, en lecture seule : `docs/socle/CARTE_DES_REGLES.md` (rôles seulement).
- Recherches « Réutiliser avant de créer » (deux) : rien de propre à KCD2 sur les âmes d'un mod. Le forum de Warhorse
  (2019, « How to change NPC Armors ») décrit l'équipement de KCD1 par `initial_clothing_preset_ID` sur l'âme : cet
  attribut n'existe plus dans les âmes de KCD2, donc ne s'applique pas. Le dépôt `muyuanjin/kcd2-mod-docs` (copie du
  wiki officiel) rappelle que le comportement des personnages passe par Lua, XGEN AI et Skald.
- Le mod d'Alex : non ouvert (règle de JoVenGer) ; son principe seulement, par la conversation Scriptorium.

## Pas de jumeaux (demande du pair, 18/10/2026, décision de JoVenGer : « le camp ne doit pas être peuplé de jumeaux »)
- Le visage suit le personnage du jeu (`skald_character_name`) : deux âmes sur le même personnage sont des jumeaux.
- Trois palettes sans personnage commun (outils/ames.py, personnages génériques du jeu de base) : **combattants 71**
  (soldats, gardes sauf `GUARD_08` du Directeur, brigands, bourgeois, Allemands, Coumans ; l'habit est remis par notre
  Lua), **gens de métier 50** (gens du commun, mineurs, gardes-chasse, marchands, charbonniers, potiers), **femmes 30**
  (femmes du commun, bourgeoises, marchandes, potières…). Réserves : 80 par palier de combattants, 50 gens de métier,
  30 femmes, 1 Directeur.
- L'âme de rang r (compté sur tous les paliers de sa réserve) porte le visage r mod visages : la liaison le refait sans
  liste (`liaison.visage_de`) ; le banc vérifie que table et liaison s'accordent.
- Au tirage (`choisir_ame`) : d'abord une âme dont le visage n'est porté par personne de la Compagnie, puis, s'il n'en
  reste plus, une âme libre quelconque (au-delà de 71 combattants, des jumeaux reviennent ; plafond du camp : 80).
- Non vérifié en jeu : que des personnages différents donnent bien des visages différents (vu pour quelques gens du
  commun le 17/10).

## Une âme, un seul porteur vivant (règle du pair, 18/10/2026)
- Vu en jeu le 18/10 : deux personnages sur une même âme, et le dialogue ouvert avec l'un partait vers l'autre.
- La liaison refuse toute naissance sur une âme de nos réserves (`5c7a5c7a-…`) déjà portée par un personnage vivant
  (relevé au moteur : les PNJ dont `guidSharedSoulId` est cette âme) : raison `ame_deja_portee`, une ligne au journal.
  Les âmes du jeu n'y sont pas soumises (des brigands du jeu en partagent une, voulu).
- Ni nos quatre âmes de bande (`liaison.ames_ennemies`, une par sorte, partagée par tous les ennemis de la sorte) :
  `liaison.ame_a_porteur_unique(ame)` les écarte. Vu sur une copie de la partie de JoVenGer le 20/10 : sans cela, une
  bande de six déserteurs n'en faisait vivre qu'un (cinq « naissance refusée »), et ce depuis le 18/10 pour toute
  bande (raid, camp de mission, convoi). Contrôlé au banc (2 quinquies) : âmes de bande partagées, âmes des réserves
  uniques.
- Vu en jeu le 20/10 : le refus marche (il a refusé, à tort, les ennemis).

## Les 31 compagnons nommés (demande du pair, liste validée par JoVenGer le 18/10/2026)
- Source : Scriptorium `docs/socle/COMPAGNONS.md` (nom, surnom, arme, prix ; le prix est payé au coffre par Scriptorium).
- Réserve « compagnon » (code 7 ; le code 6 est celui des rôles) : 31 âmes, numéro = rang dans la liste ; un visage fixe
  chacun, hors des trois palettes (personnages génériques du jeu de base : 11 nobles, 8 prêtres, 4 juifs, 3 marchands
  juifs, 3 Roms, 1 marchand rom, 1 potier ; aucun jumeau) ; classe des soldats (le jeu affiche « Soldat »), niveau 0.7.
  L'âge suit le surnom : le Vieux et le Chevalier déchu ont un visage âgé, le Chauve un visage de prêtre, Ulrich der
  Rote la voix allemande. `outils/ames.py` refuse un visage de compagnon pris ailleurs ou deux fois.
- Règles Storm : comme les autres réserves (ils peuvent parler).
- Service pour la prise : `hommes.compagnons_nommes[nom] = { nom, surnom, ame, role, famille, palier = 3 }` (les mêmes
  fiches que `hommes.compagnons`, liste à nom réglable, section « compagnons »). Embauche :
  `hommes.embaucher({ nom, ame, role, famille, palier = 3, prime = 0 })` ; une âme déjà portée dans la Compagnie est
  refusée (`ame_deja_portee`).
- Armes : cinq familles de plus, données par contrat seulement (`tirage = 0`, jamais tirées pour un homme ordinaire) :
  masse (mace), marteau (hammer), sabre, epee (sword, l'épée seule), epee_courte (huntingsword). Plus proches, faute de
  préréglage du jeu : hache à deux mains -> hache ; arbalète et dague -> arbaletrier (son assemblage porte une épée
  courte) ; épée et dague -> epee ; arc long -> archer.
- Le nom affiché au-dessus de la tête reste « Soldat » (classe sociale) : un nom propre à l'écran demanderait un
  personnage Skald à nous par compagnon (question posée au pair).
- Non vérifié en jeu.

## Chaque homme son nom (décision de JoVenGer, 18/10/2026, transmise par le pair)
- Vu en jeu le 18/10 : trois âmes sur le même personnage générique (SOLDIER_01) ont trois visages et trois tenues
  différents, et une âme garde son visage quand elle passe sur un personnage à nous. Le visage suit l'âme, pas le
  personnage : la section « Pas de jumeaux » reposait sur une hypothèse fausse. Le tirage par visage reste, sans effet.
- Le nom affiché au-dessus de la tête vient du personnage (clé `ui_name_string_name`, vu en jeu : « Jan Kladivo »).
  `outils/ames.py` écrit un personnage à nous par âme des réserves nommées (combattants, gens de métier, femmes,
  compagnons, le Directeur : 352), copie du personnage générique tiré, et `socle/textes/fr/text_ui_soul__scriptorium_socle.xml`.
- Le nom d'une âme : `hommes.nom_de_l_ame(ame)` (par `liaison.rang_de_l_ame`) : combattants puis gens de métier suivent
  les noms d'époque, les femmes `hommes.nom_de_femme`, les compagnons leur liste, le Directeur `hommes.nom_du_directeur` ; `outils/ames.py` lit les mêmes listes
  dans hommes.lua, et le banc vérifie que chaque âme affiche le nom que donne le Lua, sans doublon.
- À l'embauche, l'âme est tirée tout de suite et l'homme prend son nom ; un nom de contrat passe devant ; sans âme libre,
  l'intitulé de repli « Homme de la Compagnie », remplacé par le nom de l'âme reçue plus tard.
- Le Directeur (demande du pair, 19/10 ; vu à la répétition 4 : il affichait « Soldat ») : « Le Directeur »
  (`hommes.nom_du_directeur`), sur une copie de son personnage du jeu (GUARD_08, voix et visage inchangés).
- Pas de nom propre : les bandes (personnages génériques).
- Non vérifié en jeu (sauf le nom d'une âme et le visage, le 18/10).

## La reprise des hommes de JoVenGer (demande du pair, 18/10/2026)
- À la bascule : `py -3.13 outils/ames.py --jeu … --releve <relevé JSON de Scriptorium>` (version 1 : « hommes », chacun
  « cle », « nom » (sinon « Homme de la Compagnie »), « rang » weak/medium/strong -> palier 1/2/3, « compagnon » -> palier 3),
  juste avant l'installation. Une âme par homme (réserve « reprise », code 8, ajoutée à la fin : les identifiants
  publiés ne bougent pas), son personnage et son nom.
- La liste est gardée dans la liaison (entre les repères de la reprise : empreinte, nom, palier) et relue à chaque
  passage sans --releve. La clé du relevé (nom d'entité de l'ancien mod) n'y est jamais écrite : seulement son empreinte
  (`hommes.empreinte_de_cle`, la même en Python).
- Pour la prise : `hommes.ames_de_la_reprise[cle]` -> l'âme (nil si inconnue) ; contrat `ame = …` à l'embauche.
- Essayé au banc avec un relevé d'essai (guillemets, « », accents, nom manquant, compagnon) ; non vérifié en jeu.

## Le filet de la tenue de corps (18/10/2026, d'après un soldat presque nu vu par JoVenGer)
- Vu en jeu le 18/10 (séance regroupée) : un soldat ne gardait que sous-vêtement, coiffe, tour de cou, épée, bouclier et
  bottes. L'ancien filet ne recréait la tenue que s'il ne restait AUCUNE pièce, et seulement au rhabillage (chargement,
  fin de combat, vie relancée) : contraire à la règle validée ci-dessus (« plus sa tenue de corps »).
- Désormais : la tenue de corps, ce sont les pièces du torse et des jambes (places du jeu, equipment_slot.xml ;
  `outils/equipement.py` écrit `liaison.parties_des_pieces`). Si la tenue de l'homme a des pièces d'une de ces parties
  et qu'il n'en porte plus aucune (ou plus son arme principale), ses préréglages sont recréés.
- Le contrôle se fait au rhabillage ET à la garde de la tenue en pleine journée : un homme prêt qu'on a déshabillé est
  marqué « à rhabiller (plus de torse | jambes | arme) », puis rhabillé par le chemin habituel.
- Cause probable du 18/10 : le rhabillage du colonel par Scriptorium (il ôte les habits et pose un préréglage du jeu) ;
  le pair retire ces gestes directs : la tenue est gardée par le socle seul, Scriptorium passera ses décisions.
- Non vérifié en jeu.
- Service `hommes.reequiper(id)` (demande du pair, 18/10, pour la tenue propre du colonel) : le choix d'équipement est
  refait par la décision remplaçable `choix_de_l_equipement`, sans changer de palier ; les anciennes pièces sont
  offertes à l'accroche `piece_otee` une fois le nouveau porté (comme `changer_de_palier`, qui passe par le même chemin,
  `hommes.reequiper_la_fiche`).

## La tenue gardée par le socle seul : les services pour Scriptorium (demandes du pair, 18-19/10/2026)
- La tenue du colonel (règle de JoVenGer du 6/10) : « ZachranaPtacka_malesovCaptain_05 », la tenue du capitaine de
  Malesov (10 pièces), connue par `outils/equipement.py` ; Scriptorium la rend par `choix_de_l_equipement`, puis
  `hommes.reequiper(id)`.
- `hommes.remplacer_une_piece(id, objet, etat)` (la forge, règles du 22/09 et du 6/10) : une pièce qu'il porte, changée
  pour une neuve de la même classe, portée, à « etat » ; l'ancienne détruite AVANT (le jeu trouve une pièce par sa classe) ;
  ce qu'il porte ne change pas dans les livres. Refus : homme_inconnu, homme_absent, objet_invalide, etat_invalide,
  piece_non_portee, remplacement_refuse.
- Décision remplaçable `hommes.pieces_au_sac(id)` (tête nue au camp, règle du 7/10) : les pièces qui restent au sac
  maintenant (une liste, ou nil). Au battement, une pièce nouvellement au sac y est rangée ; plus voulue au sac, elle est
  remise ; la garde ne remet jamais une pièce au sac. Le jeu n'a aucune fonction pour ôter une pièce (cherché dans
  Data/Scripts.pak) : la pièce est retirée puis recréée au même état, sans être portée.
- Le filet de la tenue de corps ne joue jamais sous une tenue « ne_pas_rhabiller » (le bain) : la garde est suspendue,
  et le champ du « quoi » de `hommes.tenir` arrive bien jusqu'à l'activité (essai).
- Les munitions : la garde ne les compte pas ; le rhabillage complète jusqu'au nombre du préréglage, n'en retire jamais :
  les flèches et carreaux ramassés restent au sac.
- Non vérifié en jeu (en particulier : une pièce recréée reste-t-elle bien au sac, sans être portée).

## La file d'habillage, en tournant (vu sur une copie de la partie de JoVenGer, 19/10/2026)
- Vu : le colonel (Havel le Borgne, neuvième de la liste) presque nu (caleçon, bottes) et figé bras écartés, près de la
  marmite, des heures de jeu après le chargement. Au journal : « sera rééquipé (palier 1) » (la tenue du colonel, appelée
  par la prise), puis jamais « équipé ». Lu en direct par le pair : état « a_equiper », rien ne le suspend (ni lit, ni
  occupation, ni « ne_pas_rhabiller »).
- Cause : un homme par battement (toutes les 30 s), et la file repartait toujours du premier de la liste ; les premiers,
  remis « à rhabiller » sans cesse (vie du camp relancée, fin de combat), passaient toujours devant.
- Désormais (`equiper_un_homme`) : par ordre, l'homme commencé (son second passage), puis un homme à équiper (sans sa
  tenue), puis un homme à rhabiller ; et chaque fois en tournant (`hommes.habillage_rang`, en mémoire). Toujours un homme
  par battement, jamais en bataille. Essai : neuf hommes, les huit premiers remis à rhabiller à chaque battement, le
  neuvième équipé tout de suite, et chacun des huit servi (vérifié qu'il échoue avec l'ancienne file).
- La posture en T du colonel : pas un secours (aucune téléportation au journal) ; il tenait le geste
  « woman_cookingCampfire_loop » (à la marmite, choisi par Scriptorium). Non expliquée ; à revoir une fois l'homme
  habillé. Non vérifié en jeu.
- Vu sur une seconde copie (19/10, vers 23 h 40) : la file tourne, le colonel est « équipé » dès les premiers battements
  (au journal ; pas vu à l'image, il marchait sa ronde). Mais Matěj de Talmberk, après un affrontement avec Vít Hrom
  (lancé par Scriptorium), était torse nu : la levée de l'attaque par l'ordre 9 (fiche 14) ne compte plus de « fin de
  combat » au cerveau, et l'homme n'était plus marqué « à rhabiller ». Désormais, à la fin d'un affrontement, l'homme est
  marqué « à rhabiller (fin d'affrontement) ». Essai (vérifié qu'il échoue sans). Non vérifié en jeu.

## Habiller plusieurs hommes par battement, le second passage deux secondes après (vu dans la partie de JoVenGer le 22/10)
- Vu (journal, lecture seule) : à 6 h 20 de jeu, six hommes « a_rhabiller » ; à 6 h 36, encore quatre (dont Matěj de
  Talmberk « a_completer ») ; JoVenGer voit des hommes torse nu plusieurs minutes réelles chaque matin. Cause : le socle
  n'habillait qu'UN homme par battement (30 s), et chaque homme demandait deux battements (le rhabillage, puis le second
  passage au battement suivant, V71 c) ; au lever (sortie du lit) ou au chargement (« vie du camp relancée »), la file
  durait une minute par homme. « a_completer » ne manque de rien : c'est l'homme qui attend son second passage.
- Désormais : au plus `hommes.reglages.habillage_par_battement` hommes par battement (8 ; 1 : comme avant), jamais deux
  fois le même dans un battement ; le second passage de chacun part `habillage_second_passage_ms` après (2000 ;
  0 : au battement suivant, comme avant), par une minuterie (jamais en bataille, ni d'une autre partie) ; la file du
  battement reste le filet. Un homme est habillé en deux secondes.
- Essai (vérifié en échec sans : un seul habillé au lieu de trois) ; les épreuves « un homme par battement » et « poste »
  tournent désormais avec le réglage à 1 et le second passage au battement, ce qui éprouve l'ancien comportement.
- Non mesuré en jeu : le coût d'un battement qui habille huit hommes (au banc, le moteur est simulé) ; à regarder à la
  séance d'essai, au journal (temps du battement) ou à l'œil (saccade au lever) ; le réglage le baisse sans commit.
- Demande de JoVenGer (22/10, « plus aucun soldat sans équipement » ; mesuré dans la copie à 22 h 27 : 6 hommes à
  rhabiller sur 60, dont Beneš le Rouge qui suivait Henry) : plus de plafond (`habillage_par_battement` = 100) ; et un
  homme qui reçoit un nouvel ordre hors du lit (lever, escorte, ronde, chargement) et reste à rhabiller ou à équiper est
  habillé sur-le-champ, son second passage deux secondes après, sans attendre le battement ; jamais en bataille, ni tenu
  dévêtu, ni en combat ou en conversation ; la file du battement ne le reprend pas dans le même battement. Essai (vérifié
  en échec sans) ; à voir en jeu au lever.
- Vu en jeu le 25/10 (le colonel Havel le Borgne nu, 23 pièces de sa tenue dans son sac au lieu de 10 ; la prise de
  Scriptorium appelle `hommes.reequiper` à chaque chargement) : un rééquipement au même choix recréait toutes ses pièces
  à côté des siennes ; deux pièces de la même classe trompent le jeu (`FindItem` prend l'une ou l'autre ; la forge
  détruisait la copie portée). Désormais, sa tenue de naissance déjà retirée, l'homme garde ses pièces et leur usure :
  seules celles qui manquent sont créées (munitions comprises), les copies en trop retirées avant de porter, au journal
  « pièce(s) en double retirée(s) ». Le préréglage du jeu (`EquipClothingPreset`), proposé par le pair, n'est pas retenu
  sans question à JoVenGer : non gardé au rechargement (V71 a3), il perd l'usure (réponse a du 15/10). Essai (vérifié en
  échec sans) ; à voir en jeu au rechargement de la copie.
- Demande de JoVenGer (25/10 ; sa vraie partie a sans doute les mêmes doublons) : le retrait des copies en trop se fait
  aussi à chaque rhabillage (chargement, garde de la tenue), avant de faire porter, sans attendre un rééquipement ; le
  nombre voulu de chaque pièce : une par mention dans sa tenue et ses armes, plus ses pièces données de la même classe.
  Essai (vérifié en échec sans).
- Vu ensuite (25/10, socle 961689d, le pair à l'image) : le colonel était nu juste après le retrait de ses 13 doublons,
  ses pièces au sac, non portées, malgré « a remis ses affaires (13) » et le second passage ; une remise faite plus tard
  par le pair (`faire_porter`, 13 portées) l'a vêtu. Hypothèse (non vérifiée) : la copie détruite était la portée, et
  celle refaite porter aussitôt n'était pas la bonne ou pas encore prête. Deux changements à la fois (demande du pair :
  « va au radical ») : la liaison garde la copie que trouve le jeu et détruit les autres par leur identifiant
  (`retirer_les_copies`) ; et l'homme dont des doublons ont été retirés remet encore ses pièces au battement suivant
  (« a_rhabiller », une fois). Essai (vérifié en échec sans) ; à voir à l'image au chargement de la copie de 10 h 31.
- Vu ensuite (25/10, socle 9fbb391, le pair à l'image) : le colonel vêtu, mais Václav Vlk (3 doublons) encore nu après
  la remise du battement suivant ; une remise faite par le pair quelques minutes plus tard (9 portées) le vêtait. Le
  jeu n'a pas d'appel pour lire qu'une pièce est portée (relevé du 16/10) : après un retrait de doublons, ses pièces
  sont refaites porter encore à +30 s, +2 min et +5 min (secondes réelles, `doublons_remise_1_s` à `_3_s`, réglables ;
  remettre une pièce portée ne l'ôte pas, V71 c), au journal « remise après ses doublons ». Essai (vérifié en échec sans).

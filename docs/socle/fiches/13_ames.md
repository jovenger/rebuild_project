# Fiche 13 — Nos âmes

- Morceaux : `liaison` (la table des âmes et la venue), `hommes` (le choix d'une âme à l'embauche, gardé sur le registre),
  `directeur`. Données du jeu : `Libs/Tables/rpg/soul__scriptorium_socle.xml` (existe déjà : le marcheur et le brigand
  d'essai).
- But (étape 2 de la note de JoVenGer, avancée parce que l'étape 1 en a besoin) : que **les hommes du camp aient notre
  cerveau**, pour recevoir les ordres (aller, s'asseoir, se coucher, attaquer). Aujourd'hui ils ont des âmes de gardes de
  Trosky empruntées au jeu (`extraGuards_dummy_1, 3, 5`, cerveau du jeu) : ils ne reçoivent pas nos ordres. Le
  Directeur aussi (`extraGuards_dummy_6`).
- État : **proposition**, à lire par la conversation Scriptorium, puis questions à cocher à JoVenGer.

## Ce que le joueur voit
- Les hommes du camp obéissent comme le marcheur : assis au feu, couchés dans leur paillasse, au poste.
- Les sept rôles viennent au camp. Aujourd'hui, le pavoisier, le barbier, le cuisinier et l'armurier ne viennent pas
  (« pas d'âme pour le rôle ») : seuls trois rôles ont une âme empruntée.
- Selon la question 1 : des visages variés, ou un seul visage par rôle.

## Ce qui est acquis (relu dans les tables du jeu, ou vu en jeu)
- **Une âme du mod est chargée et jouée** : une ligne de `soul__scriptorium_socle.xml` portant notre `brain_id` donne
  le marcheur (V29 à V69) et le brigand d'essai (V51).
- **L'apparence et l'équipement viennent du personnage** nommé par `skald_character_name` : le marcheur porte le
  personnage d'un garde du jeu (`char_GENERIC_MAN_GUARD_15`), il est vêtu, tire une arme et blesse (V53, V54). La table
  `Libs/Tables/skald/skald_character.xml` ne donne que l'âge, le corps, le sexe, le nom et la voix d'un personnage ; sa
  tenue et son visage sont dans les données Skald du jeu, hors des tables. **On choisit donc un personnage existant ; on
  ne compose pas un visage neuf** par les tables (« apparences neuves » de la note : non faisable ainsi, à dire à
  JoVenGer).
- **Palette réelle** (relevé des 8 206 âmes du jeu) : personnages génériques de soldats (`char_GENERIC_MAN_SOLDIER_*`,
  33 personnages, employés par 2 361 âmes), de gardes (`char_GENERIC_MAN_GUARD_*`, 10 personnages), de gens du commun
  (`char_GENERIC_MAN_COMMONER_*`), de mineurs, de bourgeois, de Coumans, de brigands.
- **La classe sociale compte** : les gardes ont la classe 101 « guard », dont le rôle face au crime est « soldier » ; la
  table du jeu le réserve aux figures d'autorité (`Libs/Tables/rpg/social_class.xml`, `soul_crime_role.xml` : « Only
  socialClasses that are authority figures »). Les soldats génériques ont la classe 33 « soldier », rôle face au crime
  « civilian ». Nos hommes ont aujourd'hui la classe 101 : le jeu peut les traiter en gardes (arrêter Henry pour un vol,
  fiche 12, question 2). Non vérifié en jeu.
- **Les attributs d'une âme** dans le jeu : `brain_id`, `combat_level`, `digestion_multiplier`,
  `enable_perk_point_gain`, `factionName`, `initial_clothing_dirt`, `inventory_preset_override`, `skald_character_name`,
  `social_class_id`, `soul_archetype_id`, `soul_class_id`, `soul_id`, `soul_name`, `soul_vip_class_id`, `unique`,
  `voice_group_name`, `xp_multiplier`.
- **La réserve d'âmes du jeu** : `Libs/Tables/rpg/SoulPool.xml`, par exemple la réserve `extraGuards_dummy`, huit âmes à
  huit personnages différents, pour des gardes nés à la demande.
- **Compétences, homme par homme** : `soul:AdvanceToSkillLevel` après la venue (V53). Les tables `soul2skald_skill` et
  `soul2skald_soul_stat` sont par âme, donc par rôle, pas par homme : le caractère de la fiche 11 se pose à la venue.

## Ce qui n'est pas établi
- **Deux hommes vivants en même temps sur la même âme** : jamais vu. Les marcheurs de V50 sont venus l'un après
  l'autre ; les trois hommes du camp ont trois âmes différentes. L'existence de réserves dans le jeu laisse penser qu'une
  âme ne sert qu'à un homme à la fois. Si c'est le cas, **il faut une âme par homme** ; si deux hommes la partagent,
  il faut voir si les compétences posées sur l'un se retrouvent sur l'autre.
- **L'équipement par rôle** : le personnage donne une tenue et une arme, mais on ignore laquelle (un archer de la
  réserve des gardes porte-t-il un arc ?).

## Proposition
1. **Des âmes à nous pour les sept rôles et pour le Directeur**, dans `soul__scriptorium_socle.xml` : des copies de la
   ligne du marcheur, avec des `soul_id` neufs (`scriptorium_<rôle>_<n>`), notre cerveau, et le reste provisoire
   (personnage, classe, voix et faction des gardes de Trosky) : à l'essai, **seul le cerveau change**.
2. **Une réserve par rôle** (selon la question 1) : N âmes par rôle, chacune un personnage différent (modèle :
   `SoulPool.xml` du jeu) ; une âme tirée à l'embauche parmi celles qu'aucun homme vivant ne porte, et **gardée sur le
   registre** de l'homme (même visage quand il revient). N proposé : 8, comme la réserve du jeu ; à relever si la mesure
   montre qu'une âme ne sert qu'à un homme à la fois et qu'un rôle dépasse 8 hommes.
3. **L'apparence** (question 2), puis la **classe sociale** 33 « soldier » avec elle, à l'essai suivant.
4. **La faction** « la Compagnie » (fiche 12, 2 a), à l'essai d'après : seul `factionName` change.
5. **L'équipement par rôle et par niveau** (question 3), quand l'apparence est choisie. Trois voies réelles :
   - A. le personnage seul (acquis : le marcheur est armé) ; ce qu'il porte se mesure à la venue ;
   - B. sur l'âme, `inventory_preset_override` (un préréglage d'inventaire du mod) et `combat_level` : le jeu choisit la
     tenue par niveau, par exemple `clothes_genericSoldier_combatLevel_kut` (`InventoryPreset__armedFactions.xml`, mode
     « OneChild » : une tenue par `CombatLevel`, de 0,2 à 0,9), exactement « l'équipement par niveau » de la fiche 12 ;
     **employé seulement par onze âmes d'essais automatiques du jeu** : à vérifier en partie normale ;
   - C. par le Lua, après la venue : `actor:EquipClothingPreset` et `actor:EquipWeaponPreset`, comme l'outil de combat
     du jeu (`Scripts/Debug/CombatDebug.lua`) ; peut-être refusé hors `-devmode`, comme `SetSkillLevelDebug` (V53).

## Questions à JoVenGer (à cocher)
1. **Les visages** : a) une réserve par rôle, visages variés (recommandé) ; b) une âme par rôle, tous les hommes d'un
   rôle ont le même visage (seulement si la mesure montre que deux hommes peuvent partager une âme).
2. **L'apparence des combattants** : a) soldats génériques du jeu (33 personnages, classe « soldier », pas de figure
   d'autorité) (recommandé) ; b) gardes du jeu (10 personnages, classe « guard », figure d'autorité).
3. **L'équipement** : a) mesurer d'abord ce que porte le personnage (A), puis le niveau par l'âme (B) (recommandé) ;
   b) par le Lua à la venue (C) ; c) le personnage seul (A), rien de plus pour l'instant.
4. **Les artisans** (barbier, cuisinier, armurier) : a) apparence de gens du commun (recommandé) ; b) la même que les
   combattants.

## Essais prévus (un changement chacun, partie d'essai `playline3`)
- **V70** : nos âmes, seul le cerveau change. Les hommes du camp reçoivent l'ordre 10 (s'asseoir sur un banc du camp).
  Mesure en plus, sans rien changer d'autre : deux hommes nés en même temps sur la même âme (viennent-ils tous les
  deux ? compétences posées sur l'un, relues sur l'autre).
- **V71** : l'apparence choisie et la classe sociale ; ce que chaque personnage porte (relevé de l'inventaire à la
  venue).
- **V72** : la faction « la Compagnie ».
- Puis l'équipement par niveau, quand le niveau acheté existe (fiche 12, question 3).

## Règles en données (catalogue de `reglages.lua`, règle de JoVenGer du 14/10)
- Les identifiants d'âmes restent dans `liaison` : ce ne sont pas des règles, et le catalogue ne prend que des nombres.
- Au catalogue : le nombre d'âmes de la réserve employées par rôle (au plus N), et plus tard le `combat_level` par niveau
  acheté.

## Sources
- Paks du jeu, en lecture seule : `Tables.pak` (`Libs/Tables/rpg/soul*.xml`, `SoulPool.xml`, `social_class.xml`,
  `soul_crime_role.xml`, `Libs/Tables/skald/skald_character.xml`, `Libs/Tables/item/InventoryPreset*.xml`),
  `Scripts.pak` (`Scripts/Debug/CombatDebug.lua`).
- Recherches « Réutiliser avant de créer » (deux) : rien de propre à KCD2 sur les âmes d'un mod. Le forum de Warhorse
  (2019, « How to change NPC Armors ») décrit l'équipement de KCD1 par `initial_clothing_preset_ID` sur l'âme : cet
  attribut n'existe plus dans les âmes de KCD2 (relevé ci-dessus), donc ne s'applique pas. Le dépôt
  `muyuanjin/kcd2-mod-docs` (copie du wiki officiel) rappelle que le comportement des personnages passe par Lua, XGEN AI
  et Skald, et que tout ne se règle pas par le Lua.
- Le mod d'Alex : non ouvert (règle de JoVenGer).

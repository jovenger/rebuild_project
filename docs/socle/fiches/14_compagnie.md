# Fiche 14 — La Compagnie (la faction de nos hommes)

- Morceaux : aucun morceau Lua neuf. Données du jeu : `Libs/Tables/rpg/FactionTree__scriptorium_socle.xml` (neuf) et
  `Libs/Tables/rpg/soul__scriptorium_socle.xml` (seul `factionName` change), écrits par `outils/ames.py`. Peut-être,
  selon l'essai : `Libs/Storm/storm__scriptorium_socle.xml` et une règle Storm à nous (voir « Les crimes d'Henry »).
- But (étape 2 de la note de JoVenGer ; fiche 12, question 2, réponse a ; fiche 13, essai V72) : que nos hommes aient
  **leur faction à eux, « la Compagnie », amie d'Henry et ennemie des bandes**, et qu'ils ne dénoncent jamais Henry
  (idée validée n° 2 du 15/10). Aujourd'hui, toutes nos âmes ont la faction provisoire du marcheur, celle des gardes de
  Trosky (`trosecko_settlements_trosky_soldiers_guards`).
- État : **relue par la conversation Scriptorium le 16/10** (principe d'Alex et remarques inscrits ci-dessous) ;
  **questions à JoVenGer**. Rien n'est codé. Ce qui est marqué
  « relu » vient des paks du jeu (lecture seule) ; tout le reste est « non vérifié » en jeu.

## Ce que le joueur voit
- Les hommes du camp, le Directeur, les gens de métier et les femmes sont de la Compagnie.
- Ils sont amis d'Henry, de ses amis et des alliés du jeu ; les brigands, les Coumans et les ennemis d'Henry sont leurs
  ennemis. Les gardes et les villageois les laissent en paix, et inversement.
- Ils ne dénoncent jamais Henry et ne l'attaquent jamais pour un crime : la Compagnie ferme les yeux sur son capitaine.
  Au camp, seule la discipline de Scriptorium juge. Un duel ou un pugilat avec Henry reste hostile le temps du combat,
  puis ils redeviennent amis (plus tard, avec ces règles).

## Ce qui est relu dans les paks du jeu
- **L'arbre des factions** : `Tables.pak`, `Libs/Tables/rpg/FactionTree.xml` (1 028 factions). Le jeu y ajoute des
  fichiers à part, sur le même modèle que nos âmes : `FactionTree__tests.xml` et `FactionTree__autotests.xml`
  déclarent des factions de premier niveau, avec leurs relations. Forme d'une faction :
  `<Faction Name="…"><Relations><Relation target="…" reputation="1" /></Relations></Faction>`. La réputation va de -1
  (ennemie) à 1 (amie). On trouve aussi les attributs `Labels` (étiquettes : `camp`, `settlement`, `solitude`,
  `publicEnemy`…), `LocationId` (rattachement à un lieu) et `UIName` (nom dans l'écran des réputations).
- **L'enveloppe exacte** (`FactionTree.xsd`, et les fichiers du jeu) : `<database … name="barbora"
  xsi:noNamespaceSchemaLocation="FactionTree.xsd">`, puis `<FactionTree version="1">`. Attributs permis d'une faction :
  `Name`, `Comment`, `Labels`, `LocationId`, `LevelId`, `UIName` ; d'une relation : `target`, `reputation` (nombre),
  `qualities`.
- **Le modèle** : la faction du chien et du cheval d'Henry, `animalCompanions`, au premier niveau, sans étiquette ni
  lieu. Amie (1) de `player`, `players_friends`, `kutnohorsko_allies`, `trosecko_allies` ; ennemie (-1) de
  `players_enemies`, `trosecko_enemies`, `kutnohorsko_enemies`, `kutnohorsko_enemies_oblehaniSuchdoleEnemyArmy`. Les
  Coumans ennemis sont rangés sous ces ennemis (`trosecko_enemies_cumans`, `kutnohorsko_enemies_cumans`…).
  - Elle n'a pas de `LevelId` : elle vaut pour les deux cartes (« pro oba levely », dit son commentaire), alors que
    toute faction `trosecko_*` porte `LevelId="2"`. C'est ce qu'il faut à une compagnie qui suivra Henry d'une carte à
    l'autre.
  - Ses relations ne sont déclarées que de son côté : les ennemis ne déclarent rien envers elle, et pourtant le chien
    se bat contre les bandits. Si, à l'essai, le brigand n'attaque pas nos hommes, on ne touche pas pour autant aux
    factions du jeu depuis notre fichier : c'est une autre hypothèse, pour un autre essai.
- **Ce que la faction de Trosky donne aujourd'hui à nos hommes**, et qu'ils perdront (règles Storm,
  `IPL_GameData.pak`, `Libs/Storm/`) :
  - `rpg_faction_troskySoldiers` : +0,1 à +0,2 de niveau de combat (`combatLevel`). Les compétences viendront plus tard
    du niveau acheté et du caractère (fiche 12, question 3) ;
  - l'habillement de naissance des soldats de Trosky (`inventory_combatants_tro`, `inventory_bergovSoldeir_tro`…).
    Avec la Compagnie, aucune règle d'habillement ne vise plus leur faction. Leur classe (« soldier », 33) reste visée
    par la torche (`inventory_additive_torch`) et par la règle par défaut. Tout cela est retiré une fois à l'embauche,
    sauf la bourse (V71). C'est le point 3 du pair : **vérifié sur le papier**.
  - Les gens de métier et les femmes (classe « villager », 1) ne sont pas rhabillés par le socle : ils gardent leur
    tenue de naissance. Elle vient des règles de leur classe (`inventory_villager_male`, `inventory_villager_female`),
    sans condition de faction ; les règles de Trosky demandent une classe de soldat (`isSoldier`). **Leur allure ne
    change pas** avec la Compagnie (relu, non vu en jeu).
  - Leur classe ne change pas : « soldier » (33), rôle de crime « civilian ». Elle ne fait pas d'eux des gardes : le
    sélecteur `isGuard` demande une classe de garde (`watchman`, `guard`, `guardLeader`, `catchpole`,
    `soldier_crimeAuthority`).
- **Les crimes** (`Libs/Storm/roles/world/crime.xml`, `Libs/Storm/common/base.xml`) :
  - La règle `crime_man` donne 330 rôles de crime à **tout homme « valide du monde ouvert »**, quelle que soit sa
    faction : voir Henry voler, courir dénoncer, prévenir la garde, chasser d'un lieu interdit… Les femmes ont la leur
    (`crime_woman`, 313 rôles). Nos hommes les reçoivent sans doute aujourd'hui.
  - Le jeu en exclut lui-même les amis d'Henry (Ptáček, Bohuta, Žižka…) par une liste de noms et de voix
    (`isNotBffAndHasNoUniqueBffVoice`). **Une faction amie ne suffit donc probablement pas.**
  - Ces rôles sont surtout des **répliques** (les commentaires du fichier renvoient au responsable des voix). Les
    **comportements** de crime (courir, dénoncer, attaquer) sont dans les arbres du jeu (`Scripts.pak`, `AI/crime/`,
    323 fichiers). Retirer les rôles pourrait donc faire taire nos hommes sans les empêcher de courir prévenir la
    garde : c'est une hypothèse.
  - Storm sait retirer un rôle (`removeRole`, `Libs/Storm/storm.dtd`). La liste des fichiers Storm est
    `Libs/Storm/storm.xml`. Un mod y ajouterait les siens par un fichier `Libs/Storm/storm__<nom>.xml` : déduit du nom
    du fichier qu'a le mod Scriptorium installé (vu seulement dans la liste de son pak ; son contenu n'est pas lu). Une règle à nous
    (`hasFaction name="la Compagnie"`, puis `removeRole` pour chaque rôle de crime) retirerait ces rôles à nos seuls
    hommes. **Non vérifié**, en particulier l'ordre : notre retrait passe-t-il après l'ajout du jeu ?
  - **Les contextes de script** (`Libs/Tables/ai/ScriptContext.xml`) : `crime_isCivilian`, `crime_isSecurity`,
    `crime_isAuthority`, `crime_interrupt`, `crime_interruptAttack`, `crime_interruptArrest`… Les arbres de crime s'y
    branchent (`AI/crime/getAuthorityKindByContext.xml`), et le Lua les lit sur l'âme
    (`soul:HasScriptContext(nom)`, `Scripts/Entities/actor/BasicActor.lua`).
  - **Un contexte joue pour la Compagnie** : la règle Storm `contexts_disabledInformationBroadcast`
    (`Libs/Storm/contexts/contexts.xml`) donne `crime_skipInformationBroadcast` à toute âme dont la faction n'a pas
    l'étiquette `settlement`. Nos hommes de Trosky ne l'ont pas (Trosky porte cette étiquette) ; ceux de la Compagnie,
    sans étiquette, l'auront : **ils ne transmettront plus ce qu'ils ont vu** (relu, non mesuré).
  - **Mais nos hommes n'ont pas le switch du jeu** (fiche 12) : c'est notre switch qui pose leurs interruptions, et
    sans ordre ils ne font rien. Ils gardent les 24 boîtes aux lettres de `npc_basic`, dont quatre de crime
    (`crime_forgetCrimes`, `crime_switchBark`, `crime_playerIsSurrendering`, `crime_attackInitiatedByConcept`) et la
    perception. Il se peut donc qu'ils ne réagissent déjà à aucun crime. **Seule la mesure en jeu le dira.**
- **Le duel et le pugilat** : notre ordre d'attaque passe déjà `relationOverride="true"` à la fonction du jeu
  (`callInterrupt_attack`, V54) : il rend l'attaque possible sans changer la faction. Ces règles viendront plus tard.
- **Lire la faction en jeu** : `AI.GetFactionOf(id)` rend son nom (`Scripts/Entities/Triggers/AreaTrigger.lua`) ;
  `soul:GetFactionID()` rend son numéro (`Scripts/Utils/EntityUtils.lua`).
- **Ce que la conversation Scriptorium a transmis du mod d'Alex** (16/10, principe seulement) : sa faction de compagnie
  a exactement les relations du chien et du cheval (éprouvées depuis des semaines dans la partie de JoVenGer) ; il a
  aussi ses propres factions d'ennemis pour les bandes (premier niveau, étiquette `publicEnemy`, hostiles à Henry et à
  sa compagnie), à prévoir plus tard, aux raids et aux missions ; **pour les crimes, il n'a rien fait** (ni Storm, ni
  retrait de rôle), et JoVenGer ne s'en est jamais plaint ; il lit `crime_interruptAttack` sur l'âme pour savoir qu'un
  homme est pris par une attaque de crime.
- Recherches « Réutiliser avant de créer » (deux, sur les règles Storm d'un mod et sur une faction amie qui ne dénonce
  pas) : rien de propre à KCD2 ; on s'appuie sur les fichiers du jeu ci-dessus.

## Comment ce serait fait
- **La faction** : `FactionTree__scriptorium_socle.xml`, une faction de premier niveau `scriptorium_socle_compagnie`
  (préfixe à nous : aucun risque de croiser une faction du jeu ou du mod Scriptorium), sans étiquette ni lieu, avec les
  relations de `animalCompanions` (question 1). Écrite par `outils/ames.py`, qui refuse si une cible de relation
  n'existe pas dans l'arbre du jeu, ou si le nom y est déjà pris.
- **Les âmes** : `FACTION` de `outils/ames.py` devient `scriptorium_socle_compagnie` pour toutes les réserves
  (combattants, gens de métier, femmes, Directeur). Les identifiants ne changent pas. Les âmes d'essai (marcheur,
  brigand, sondes) gardent la leur.
- **Le banc** (`tout_verifier.py`) : la faction nommée par chaque âme des réserves existe dans notre fichier de
  factions ; le fichier est bien formé ; chaque cible de relation est une faction du jeu (relevée par
  `outils/ames.py`).
- **Une commande d'essai** au poste : la faction de chaque homme (`AI.GetFactionOf`), et ses flèches ou carreaux
  (nombre exact, pour le point 1 du pair).
- **Rien au catalogue de `reglages.lua`** : les relations sont une table du jeu, chargée au lancement ; le Lua ne les
  change pas (aucun appel relevé). Comme les identifiants d'âmes, ce ne sont pas des réglages chiffrés.

## Essai prévu (V72 a, partie d'essai `playline3`, un seul changement : la faction)
1. **La faction est prise** : après installation et rechargement, `AI.GetFactionOf` rend la Compagnie pour un homme
   embauché avant (déjà dans la sauvegarde) et pour un homme embauché après. Si l'ancien garde Trosky, la faction est
   gardée dans la sauvegarde : question à JoVenGer (le faire renaître).
2. **Amis et ennemis** : le brigand du jeu posé près de nos hommes, sans ordre : l'attaque-t-il ? Un garde du jeu
   reste-t-il en paix avec eux ? Puis l'ordre d'attaque (ordre 8), comme en V71.
3. **Les flèches** (point 1 du pair) : un archer contre le brigand ; flèches comptées avant et après le tir.
4. **Le délit d'Henry** (point 2 du pair) : **un crime contre le monde** devant deux de nos hommes (question 4) :
   l'habitant du jeu le plus proche est posé devant Henry (on déplace l'habitant, jamais Henry), et Henry le frappe à
   mains nues. La partie d'essai est sauvegardée avant le délit, jamais après. On note à part, pour chacun de nos deux
   témoins : (a) une réplique ou un cri ; (b) une course, vers la garde ou ailleurs ; (c) une attaque contre Henry, ou
   aux côtés des gardes ; et pour Henry : (d) recherché, ou réputation en baisse. Mesure exacte en plus de l'image
   (conseil du pair) : les contextes de nos témoins avant et après (`crime_isCivilian`, `crime_isAuthority`,
   `crime_isSecurity`, `crime_interrupt`, `crime_interruptAttack`, `crime_skipInformationBroadcast`). « Henry frappe
   un de nos hommes » relève de la discipline et du pugilat : question à part, plus tard. Si (a) seulement :
   V72 b, la règle Storm à nous (question 3). Si (b), (c) ou (d) : la règle Storm ne suffira sans doute pas (ce sont
   des comportements) ; nouveau diagnostic, et question à JoVenGer.

## Questions à JoVenGer (après relecture par la conversation Scriptorium)
1. **Les relations de la Compagnie** : (a) celles du chien et du cheval d'Henry (Recommandé : réglage du jeu déjà
   éprouvé pour les compagnons d'Henry, valable sur les deux cartes) ; (b) les mêmes, et ennemie de tous les ennemis du jeu (dont les bandits des
   rencontres sur les routes, `eventNPCs_enemies`) ; (c) amie d'Henry seulement, neutre envers tous les autres.
2. **La classe sociale** : (a) garder « soldier » (Recommandé : un seul changement par essai, et elle ne fait pas
   d'eux des gardes) ; (b) « mercenary » (61) : son rôle de crime est « renegade », dont l'effet n'est ni relu ni
   mesuré ; elle est visée par les mêmes règles d'habillement que « soldier » (la torche, la règle par défaut).
3. **Le retrait des rôles de crime** : (a) d'abord la faction seule ; si nos hommes ne font que des répliques au délit
   d'Henry, la règle Storm à nous en V72 b (Recommandé : un changement à la fois, et le retrait n'est peut-être pas
   utile) ; (b) les deux d'un coup, dans le même essai.
4. **Le délit de l'essai** : (a) Henry frappe à mains nues un habitant du jeu devant deux de nos hommes ; je pilote. Il
   faut pour cela ajouter un clic gauche à `touches.ps1` (aujourd'hui, seulement des touches et des déplacements de
   souris), avec la même garde : rien ne part si le jeu n'est pas au premier plan (Recommandé : c'est le cas de l'idée
   n° 2, un crime contre le monde) ; (b) tu fais le délit toi-même pendant l'essai ; (c) pas de délit dans cet essai,
   seulement la faction.

## Sources
- `Tables.pak` : `Libs/Tables/rpg/FactionTree.xml`, `FactionTree__tests.xml`, `FactionTree__autotests.xml`,
  `faction_label.xml`, `social_class.xml`, `soul_crime_role.xml`, `Libs/Tables/ai/mailbox.xml`,
  `Libs/Tables/ai/ScriptContext.xml`.
- `IPL_GameData.pak` : `Libs/Storm/storm.xml`, `storm.dtd`, `common/base.xml`, `roles/world/crime.xml`,
  `abilities/base/factions.xml`, `abilities/base/classes.xml`, `equipment/world/classes.xml`,
  `equipment/world/factions.xml`, `names/names.xml`, `contexts/contexts.xml`.
- `Scripts.pak` : `Scripts/Entities/Triggers/AreaTrigger.lua`, `Scripts/Utils/EntityUtils.lua`,
  `Scripts/Systems/KCD1/SocialClass.lua`,
  `Scripts/Entities/actor/BasicActor.lua`, `AI/crime/getAuthorityKindByContext.xml`.
- Pak du mod Scriptorium installé : seulement la liste de ses fichiers (`storm__scriptorium.xml`,
  `FactionTree__scriptorium.xml`) : signe, non vérifié, que le jeu accepte ces fichiers ajoutés ; leur contenu n'est
  pas lu.

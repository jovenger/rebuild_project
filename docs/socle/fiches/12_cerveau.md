# Fiche 12 — Le cerveau de nos hommes

- Morceau : à venir (`hommes` pour les ordres, `liaison` pour le moteur). Données du jeu : tables
  `Libs/Tables/ai/*__scriptorium_socle.xml`, arbres `AI/scriptorium/`.
- But (étape 1 de la note de JoVenGer) : que nos hommes vivent, obéissent au Directeur et se battent, comme des
  personnages du jeu, sans rien emprunter au code d'Alex (principes seulement, décision de JoVenGer du 15/10).
- État : **proposée, à valider par JoVenGer** (questions à cocher). Tout ce qui est marqué « acquis » a été vu en jeu
  (`essai_en_jeu.md`, V29 à V55, sans `-devmode`) ; le reste est marqué « non vérifié ».

## Ce que le joueur voit
- Nos hommes marchent, vont où le Directeur les envoie (poste, garde, rassemblement, lit), et y restent.
- Sur ordre, un homme tire son arme et attaque l'ennemi désigné ; il blesse, met en fuite ou tue (acquis, V52 à V54).
- Plus tard (ouvert) : ils attaquent d'eux-mêmes une bande qu'ils voient, ripostent quand on les frappe, défendent Henry.

## Comment c'est fait (acquis)
- **Naissance** : un personnage de classe `NPC`, avec une copie des propriétés de sa classe plus son âme
  (`guidSharedSoulId`), puis **réveillé** aussitôt (`entite:Activate(1)`, `AI.AutoDisable(id, 0)`) ; sans réveil, son
  cerveau ne tourne pas (V29).
- **Le cerveau** (table `brain`), composé de **deux sous-cerveaux seulement** (V50) :
  - un **switch à nous** (type 6, déclaré dans `subbrain_switching`) : une boucle qui lit la variable d'ordre et pose
    les interruptions ; il ne fait ni marcher ni tirer d'arme lui-même (comme les switchs du jeu) ;
  - les **horaires du jeu** (`npc_basic_scheduler`, type 9) : c'est lui qui **joue** les interruptions.
  - Interdits vus en jeu : un simple arbre (type 1) à côté des horaires, ou le switch du jeu à côté, empêche la partie
    de se charger (V47) ; un sous-cerveau seul de type 9 portant notre arbre n'est pas joué (V49).
  - Les **24 boîtes aux lettres** de `npc_basic` (coups reçus, perception, crimes…), gardées.
- **Les variables du cerveau** (table `brain_variable`) : l'ordre (nombre), la cible (`wuid`), le point (`vec3`), et des
  compteurs. Le Lua les écrit (`XGenAIModule.SetBrainVariable`) ; le switch et les comportements les lisent.
- **Un ordre du Directeur** = la variable d'ordre (et sa cible ou son point) écrite par la liaison, puis le switch pose
  l'interruption correspondante et remet l'ordre à 0.
  - **Attaquer** : la liaison fait tirer l'arme (`human:DrawWeapon`, comme l'outil de combat du jeu) ; le switch appelle
    la fonction d'arbre du jeu `callInterrupt_attack` sur la cible (V50 à V54). Sans arme tirée, l'homme engage sans
    blesser (V51).
  - **Aller quelque part, et les autres ordres** : un **comportement à nous** par ordre (arbre dans
    `AI/scriptorium/comportements.xml`), déclaré en plus sur l'entité des interruptions du jeu
    (`Libs/Tables/ai/smartEntity/SmartEntity__so_interrupt__scriptorium_socle.xml`), posé par le nœud générique
    `AddInterrupt`. Il lit et écrit les variables du cerveau de l'homme (V55).
- **Compétences de combat** : posables par `soul:AdvanceToSkillLevel` (relu, V53). À 0, un homme frappe déjà (V52).

## Ce qu'il faut décider (questions à JoVenGer)
1. **L'architecture** ci-dessus (switch à nous + horaires du jeu ; un ordre = un comportement à nous joué en
   interruption ; l'attaque par la fonction du jeu).
2. **La faction de nos hommes** : elle décide qui ils attaquent et qui les attaque, et si le jeu les traite en gardes
   (un garde arrête Henry pour un vol).
   - a. **une faction à nous**, ajoutée à l'arbre des factions du jeu (`Libs/Tables/rpg/FactionTree__scriptorium_socle.xml` :
     le jeu en charge déjà en plus, par ex. `FactionTree__tests.xml` ; amie d'Henry, hostile aux brigands et aux
     Coumans, sans autorité) — faisable sur le papier, **non vérifié** en jeu ;
   - b. une faction de soldats du jeu, amie d'Henry — risque d'agir en gardes.
3. **Les compétences de combat** (règle nouvelle, réglable) :
   - a. tirées de l'**aguerrissement** de la fiche 11 (0 à 100) : par exemple de 5 (bleu) à 20 (vétéran), proportionnelles,
     bornes réglables, remises à jour quand il s'aguerrit ;
   - b. un niveau fixe pour tous, réglable ;
   - c. laissées à 0 pour l'instant.
4. **Les premiers comportements à écrire**, une chose à la fois : aller au poste, monter la garde (rester au poste,
   arme prête), rejoindre le rassemblement, dormir (au lit ou par terre), suivre Henry.

## Règles (toutes en données, catalogue de `reglages.lua`, règle de JoVenGer du 14/10)
- Priorité des interruptions de nos ordres, distance d'arrêt au point, durée d'attente avant d'abandonner un trajet,
  niveaux de compétences (si 3 a ou b), délai entre deux tours du switch.

## Ce qui reste ouvert (non vérifié)
- **L'attaque à vue** (une bande qui attaque d'elle-même en voyant le camp) et la riposte : le brigand du jeu n'attaque
  pas Henry de lui-même à 8 m, même en prairie (V41, V43) ; pistes : perception (`IgnorePerception`), volumes perçus et
  sons des crimes du jeu.
- **Rappeler un homme engagé** : rendre au Directeur un homme en combat (garde des comportements par la variable
  d'ordre, `IfGate … RunLogic="Halt"` comme `interrupt_attack.xml` du jeu).
- **S'asseoir, dormir** : siège ou lit reconnu par l'IA (V32, V33 : la posture assise par arbre bloquait).
- **Réveil** à chaque entrée en partie et après rechargement ; sommeil au-delà d'environ 300 m d'Henry.
- **Âmes du mod** par rôle (homme d'armes, Directeur, artisan), avec leur équipement (préréglages d'inventaire du jeu par
  niveau de combat : `Libs/Tables/item/InventoryPreset__armedFactions.xml`).
- La version publiée n'aura ni poste ni ordres d'essai (`scriptorium_essai_*`).

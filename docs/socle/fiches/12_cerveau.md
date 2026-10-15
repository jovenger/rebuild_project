# Fiche 12 — Le cerveau de nos hommes

- Morceau : à venir (`hommes` pour les ordres, `liaison` pour le moteur). Données du jeu : tables
  `Libs/Tables/ai/*__scriptorium_socle.xml`, arbres `AI/scriptorium/`.
- But (étape 1 de la note de JoVenGer) : que nos hommes vivent, obéissent au Directeur et se battent, comme des
  personnages du jeu, sans rien emprunter au code d'Alex (principes seulement, décision de JoVenGer du 15/10).
- État : **validée par JoVenGer le 15/10/2026** (questions à cocher, après lecture par la conversation Scriptorium) :
  architecture adoptée ; faction « la Compagnie », à nous ; compétences selon le niveau acheté puis le caractère ;
  comportements dans l'ordre de la vie du camp, après le réveil au chargement. Tout ce qui est marqué « acquis » a été vu
  en jeu (`essai_en_jeu.md`, V29 à V55, sans `-devmode`) ; le reste est marqué « non vérifié ».

## Ce que le joueur voit
- Sur ordre, un homme va au point que le Directeur lui donne et y reste (acquis : « aller au point », V55). Les autres
  ordres (poste, garde, rassemblement, lit, suivre Henry) sont à écrire sur le même modèle (non vérifié).
- Sur ordre, un homme tire son arme et attaque l'ennemi désigné : il blesse et met en fuite un brigand léger du jeu
  (V54), il tue un adversaire qui ne se défend pas (V52). Un brigand du jeu en armure complète l'a toujours emporté
  (V43 à V53).
- **Sans ordre, il ne fait rien** : il reste planté (V50 à V55). Les veillées de la fiche 11 (feu, dés, entraînement,
  lit) devront devenir des comportements à nous, choisis selon ses envies (à faire).
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
- **Compétences de combat** : posables par `soul:AdvanceToSkillLevel` (relu, V53 ; l'appel ne fait que monter, comme
  l'aguerrissement de la fiche 11). À 0, un homme frappe déjà (V52).

## Ce qu'il faut décider (questions à JoVenGer)
1. **L'architecture** ci-dessus (switch à nous + horaires du jeu ; un ordre = un comportement à nous joué en
   interruption ; l'attaque par la fonction du jeu).
2. **La faction de nos hommes** : elle décide qui ils attaquent et qui les attaque, et si le jeu les traite en gardes
   (un garde arrête Henry pour un vol).
   - a. **une faction à nous** (« la Compagnie »), ajoutée à l'arbre des factions du jeu (`Libs/Tables/rpg/FactionTree__scriptorium_socle.xml` :
     le jeu en charge déjà en plus, par ex. `FactionTree__tests.xml` ; amie d'Henry, hostile aux brigands et aux
     Coumans, sans autorité) — faisable sur le papier, **non vérifié** en jeu ;
   - b. une faction de soldats du jeu, amie d'Henry — risque d'agir en gardes.
   - Ce qui pèse : la faction change le comportement des deux côtés, pas seulement « qui attaque qui » : un brigand a
     fui devant notre homme à âme de garde de Trosky (V54), et un garde du jeu s'est porté de lui-même sur un brigand
     (V49). Vérifier (a) coûte une séance : un `FactionTree__scriptorium_socle.xml` avec deux relations hostiles
     (brigands, Coumans), sur la structure réelle de `FactionTree__tests.xml`.
   - Côté programme Scriptorium (remarque de sa conversation) : un de nos hommes n'arrête ni n'attaque jamais Henry de
     lui-même (la justice du camp est celle du Directeur) ; mais les duels et pugilats avec Henry sont voulus : la
     faction doit pouvoir être rendue hostile le temps d'un ordre (`RelationOverride` de l'attaque), puis amie.
3. **Les compétences de combat** (règle nouvelle, réglable) :
   - a. selon le **niveau acheté** puis le **caractère** : le programme Scriptorium embauche par niveau (recrue,
     confirmé, vétéran, avec prix et paie selon le niveau) ; une fourchette par niveau (par exemple recrue 5–10,
     confirmé 10–15, vétéran 15–20, réglables), la place dans la fourchette selon l'aguerrissement et les dons de la
     fiche 11 ; montées quand il s'aguerrit ou s'entraîne (jamais baissées). Même cohérence à reprendre pour
     l'aguerrissement de départ de la fiche 11 (aujourd'hui en cloche autour de 25, sans lien avec le niveau) ;
   - b. un niveau fixe pour tous, réglable ;
   - c. laissées à 0 pour l'instant.
4. **Les premiers comportements à écrire**, une chose à la fois, dans l'ordre de la vie du camp : (1) monter la garde
   (aller au poste et y rester, arme prête) ; (2) rejoindre le rassemblement (l'alerte) ; (3) aller au poste ou au
   travail ; (4) suivre Henry ; (5) dormir, quand le lit sera reconnu ; puis les veillées de la fiche 11. Le socle
   fournit le geste ; qui va où reste une règle du programme Scriptorium.

## Règles (toutes en données, catalogue de `reglages.lua`, règle de JoVenGer du 14/10)
- Priorité des interruptions de nos ordres, distance d'arrêt au point, durée d'attente avant d'abandonner un trajet,
  niveaux de compétences (si 3 a ou b), délai entre deux tours du switch.

## Ce qui reste ouvert (non vérifié), par ordre d'urgence
- **Réveil** à chaque entrée en partie et après rechargement (sans lui, tout le camp serait figé au premier chargement) ;
  sommeil au-delà d'environ 300 m d'Henry.
- La table `SmartEntity__so_interrupt__scriptorium_socle.xml` n'est pas annoncée au journal du jeu ; elle est prise
  puisque le comportement est joué (V55).
- **L'attaque à vue** (une bande qui attaque d'elle-même en voyant le camp) et la riposte : le brigand du jeu n'attaque
  pas Henry de lui-même à 8 m, même en prairie (V41, V43) ; pistes : perception (`IgnorePerception`), volumes perçus et
  sons des crimes du jeu.
- **Rappeler un homme engagé** : rendre au Directeur un homme en combat. Piste à essayer d'abord (une séance, un seul
  changement) : les priorités. Nos ordres sont posés à 100, l'attaque du jeu à 160 : un ordre à 100 ne reprend pas un
  homme pris par une interruption à 160, sauf `IgnorePriorityOnPreviousInterrupt="true"`. Sinon : garde des
  comportements par la variable d'ordre (`IfGate … RunLogic="Halt"`, comme `interrupt_attack.xml` du jeu).
- **S'asseoir, dormir** : siège ou lit reconnu par l'IA (V32, V33 : la posture assise par arbre bloquait).
- **Âmes du mod** par rôle (homme d'armes, Directeur, artisan), avec leur équipement (préréglages d'inventaire du jeu par
  niveau de combat : `Libs/Tables/item/InventoryPreset__armedFactions.xml`).
- La version publiée n'aura ni poste ni ordres d'essai (`scriptorium_essai_*`).

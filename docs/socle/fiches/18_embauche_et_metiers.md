# Fiche 18 — L'embauche et les métiers (étape 5 du nécessaire)

Sources : la note de JoVenGer (`Scriptorium/docs/socle/NOTE_POUR_LE_SOCLE.md`, partie 7) et `NOTE_METIERS.md` (lecture
seule), la liste du pair du 17/10 (ce que Scriptorium attend), le tableau du guichet (`docs/socle/guichet.md`, entrées
« étape 5 »). Les règles (prix, pécule de 200, réembauche, le Directeur qui engage, salaires, stocks, horaires) sont celles
de Scriptorium : le socle n'offre que la mécanique, et des accroches.

Découpage, une tranche à la fois :
1. **5 a, l'embauche** (ci-dessous) ;
2. 5 b, rendre un homme parlable (le dialogue de Scriptorium s'y greffe) ;
3. 5 c, les métiers : le forgeron connu par son personnage, les postes de travail du jeu (le geste vient du jeu, l'ordre
   vient de nous ; ce qui marche est refait pareil, sans nouveau poste) ;
4. 5 d, les sorties à cheval des gens de métier (la colonne de l'étape 4).

## 5 a — L'embauche

Réponses prises d'office (consigne du 17/10) :
- **Faire venir plusieurs hommes** : `hommes.faire_venir_des_hommes({ nombre, role, palier, famille, semaines, prime })`
  embauche un à un et s'arrête au premier refus (rendu avec les engagés).
- **Un compagnon nommé** : `contrat.nom` (son nom, sinon un nom d'époque) et `contrat.ame` (l'âme donnée par
  Scriptorium, un identifiant du jeu ; sinon une âme à nous).
- **Un homme posé à un point** : `contrat.position` ; il naît là (sinon au feu du camp).
- **Le plafond de la compagnie** : réglage `hommes.plafond` (80, le chiffre de JoVenGer du 28/09) ; refus
  « plafond_atteint » ; `hommes.plafond_de_la_compagnie()` rend le plafond, l'effectif et les lits libres.
- **Les chevaux de la compagnie** : interrupteur `chevaux_de_la_compagnie` (allumé) ; éteint, aucune sortie ne fait naître
  de cheval : chacun sort à pied.
- **Accroches** : `hommes.avant_l_embauche(contrat)` (rend vrai, ou faux et la raison : Scriptorium refuse ou modifie le
  contrat) et `hommes.apres_l_embauche(id, contrat)`.

Relecture du pair (17/10, l'argent pour la prise) :
- **Une prime de 0 : rien à payer.** Scriptorium paie lui-même l'embauche à sa caisse, puis engage avec une prime de 0 :
  alors aucun appel au coffre (ni lecture ni paiement) ni à la bourse d'Henry, et pas de refus « coffre insuffisant ».
  Prime et solde boiteuses (négatives, fractionnaires, NaN, infinies, pas des nombres) : refus `prime_invalide`,
  `solde_invalide`. Au banc, avec trois erreurs injectées (garde de la prime ôtée, `payer(0)`, sommes non vérifiées) :
  toutes attrapées.
- **Un lit par homme** : interrupteur `un_lit_par_homme` (allumé). Éteint, l'homme est engagé sans lit s'il n'en reste
  pas (chez Scriptorium, on dort en relève ; les tentes sont à JoVenGer) ; une ligne au journal.
- **Les semaines** (réponse prise d'office) : les contrats à durée éteints (`contrats_a_duree`), `semaines` est
  facultatif et vaut le plus long contrat (`hommes.reglages.semaines_max`) ; donné, il reste vérifié.

## 5 b — Rendre un homme parlable

Recherche (règle du 15/10) : deux recherches (GitHub, Nexus) sans exemple pour KCD2. Source réelle : les scripts du jeu
(`Scripts.pak`, lecture seule) : `Scripts/Entities/AI/Shared/BasicAIActions.lua` (`GetActions` construit les actions
d'un personnage ; « Parler » y est ajouté par `AddInteractorAction` avec `Action():hint("@ui_hud_talk"):action("talk")
:interaction(inr_talk)` seulement si `actor:CanTalk` — un dialogue existe pour son âme — et hors combat) et
`Scripts/Utils/InteractorAction.lua` (`Action`, `AddInteractorAction`).

Comportement :
- `hommes.rendre_parlable(id, oui)` : la fiche garde `parlable` ; l'entité de l'homme reçoit « Parler » tant qu'il est
  vivant, conscient et hors combat, s'il n'a pas déjà « Parler » (un dialogue du jeu ou de Scriptorium). Reposé à chaque
  battement (une entité refaite au chargement perd l'enveloppe) ; rien n'est écrit dans les fichiers ni dans la classe du
  jeu : seulement l'instance de l'entité.
- Henry appuie sur « Parler » : l'accroche `hommes.quand_on_lui_parle(id)` (appelée par la table sous `pcall` ; le
  dialogue de Scriptorium la remplace). Par défaut, une ligne au journal et une annonce (« … vous écoute »).
- Une enveloppe en erreur rend les actions d'origine (jamais d'actions cassées) ; une ligne au journal, une fois.
- Réponses prises d'office : parlable pour l'homme qu'on désigne (pas tous d'office) ; le Directeur plus tard (sa
  Gestion du camp est à Scriptorium).
- Contrôle d'absence : `GetActions` (le nom que le moteur appelle sur l'entité) est aussi chez Alex. Décision de JoVenGer
  du 17/10 (par le pair) : une liste fermée de « noms du jeu admis » dans `tout_verifier.py`, un nom n'y entrant que
  s'il est défini comme fonction dans `Data/Scripts.pak` du jeu de base (vérifié à chaque passage ; refusé sans le jeu),
  au plus un (`GetActions`), affiché au rapport. Un nom de plus se demande à JoVenGer.
- Au banc : posé, reposé au battement, l'accroche reçoit l'homme, ôté, inconnu refusé. Non vérifié en jeu.

## 5 c — Les métiers

### Tranche 1 : les gens de métier à part, et admettre un personnage déjà né

Réponses prises d'office :
- **Exemptions en données** : `hommes.exemptions_des_metiers = { garde = 1, garde_de_nuit = 1, ronde = 1,
  patrouille = 1 }` (section de réglages `exemptions_des_metiers`) ; tout rôle de réserve « metier » (barbier,
  cuisinier, armurier, forgeron) en est exempté. Avant, les gens de métier prenaient la garde. Les missions restent
  permises (les sorties de 5 d).
- **Le rôle `forgeron`** (solde 16, métier).
- **Admettre un personnage déjà né** : `hommes.admettre(personnage, contrat)` (le contrat de l'embauche, sans âme ni
  point) ; `hommes.homme_du_personnage(personnage)`. Un admis n'est jamais refait (absent, il attend au registre),
  jamais renvoyé (retiré, son personnage reste dans le monde : il est à Scriptorium), jamais équipé, jamais mis dehors
  (refus `personnage_admis`). Pour les gens que Scriptorium fait naître lui-même (le forgeron, le service) ; les hommes
  de la partie de JoVenGer, eux, seront refaits sur nos âmes à la bascule (le pair, 17/10).
- Au banc ; non vérifié en jeu.

### 5 a bis : un homme refait avec son équipement donné (la reprise de la partie de JoVenGer, le pair, 17/10)

- Contrat `objets` : une liste de `{ objet, etat }` (ou d'identifiants du jeu, état neuf) ; pas de préréglage ; les
  objets sont recréés à la naissance avec leur état par la voie des pièces données (V71 c), puis portés ; refaits de même
  si le personnage est refait. Avec `nom`, `role`, `palier` et `position` : l'homme repris. Le point est choisi par qui
  appelle (hors de la vue d'Henry : à lui d'y veiller, comme pour `faire_rentrer`). Objets boiteux : refus.
- Au banc ; non vérifié en jeu.
- Relecture (17/10), réponses prises d'office : un admis combattant n'est jamais équipé (les deux boucles de
  l'équipement l'ignorent) ; sans prime donnée, un admis ne coûte rien (Scriptorium paie les siens) ; mort, il ne rend
  aucun corps (son entité est à Scriptorium : personne ne la retire).

**Vu en jeu le 17/10** (séance groupée, `essai_en_jeu.md`) : 5 a (trois d'un coup, un posé au point, le compagnon nommé), 5 a bis (9 objets portés à l'état 0,5), 5 b (« Parler [E] » puis « Il vous écoute : … » ; le moteur appelle bien l'enveloppe de l'instance), 5 c tranche 1 (l'admis mené par nos ordres ; les gens de métier hors de la garde). Non vus : pas de « Parler » en combat ; l'admis après un rechargement.

### Tranche 2 : les postes de travail du jeu

Sources réelles (lecture seule) : `Tables.pak`, `Libs/Tables/ai/smartEntity/SmartEntity__<nom>.xml` (le gabarit : son
`DatabaseId`, ses comportements nommés) ; `Scripts.pak`, `AI/profession/…` (l'arbre de chaque comportement),
`Scripts/Entities/WH/Others/SmartObjectHolder.lua` (un objet intelligent sans géométrie, qui porte
`guidSmartObjectType`), `AI/crime/mournOnBench.xml` (un personnage lance le comportement d'un objet :
`<CallBehavior Target=… BehaviorName=…>`). Deux recherches (GitHub, Nexus) sans exemple pour KCD2 (5 b).

Comportement :
- **Le catalogue des genres** `camp.genres_de_postes` (section de réglages `postes_du_jeu`) : pour chaque genre, le
  gabarit du jeu, le geste (le comportement nommé) et les points d'appui. D'abord la prière (`so_praying`,
  `useKneelingGround`), le désherbage, la clôture et la pelle (`so_weeding`, `so_fence`, `so_shoveling`, `use`) : sans objet lié. La forge (sac de forge, emplacements du
  marteau et de l'épée, liés au poste) viendra après, prouvée à part.
- **Rendre un poste fonctionnel** : `camp.rendre_fonctionnel(nom, genre, position, cap)` (décision remplaçable, A34) :
  un `SmartObjectHolder` du gabarit, posé au sol là où Scriptorium (ou JoVenGer par le plan) le veut ; gardé au
  registre, reposé à l'entrée en partie s'il manque, retiré quand le camp est levé ; `camp.retirer_le_poste(nom)`,
  `camp.postes()`.
- **Le geste vient du jeu, l'ordre vient de nous** : `hommes.tenir(id, regle, { activite = "poste", poste = nom, fin })`
  : l'homme marche au poste (ordre 21), puis l'arbre lance le comportement du poste (`CallBehavior`), le relance quand
  il finit, et l'interrompt au changement d'ordre (la fin de la tenue, une bataille, la nuit : l'arbitre).
- **Le relevé** (outil d'essai) : les objets intelligents du monde d'un gabarit du catalogue, autour d'Henry : classe,
  nom, gabarit, points d'appui, modèle, distance (comme V65 pour les sièges).
- Non vérifié en jeu tant que le relevé et la première prière ne sont pas vus.
- **Vu en jeu le 17/10** : le relevé (359 postes à moins de 400 m d'Henry, tous des `SmartObjectHolder` ; points d'appui lus : prière « Praying », désherbage « Weeding », clôture « GenU_repairFenceHammer », pelle « coalThrowing » ; aucun balai alentour : retiré du catalogue, les points d'appui mis d'après le relevé). Puis la prière : le poste posé à 3 m devant Henry, l'homme y marche, s'agenouille (le geste du jeu, lancé une fois et tenu) ; lâché, il se relève aussitôt et repart à l'exercice. Non vus : le désherbage, la clôture, la pelle ; un geste qui finit et qu'on relance ; le poste reposé après un chargement.

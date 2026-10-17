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

# Fiche 16 — Le guichet (étape 3 du nécessaire)

Source : le tableau des règles en double de Scriptorium (`Scriptorium/docs/socle/DOUBLONS.md`, lecture seule, 17/10),
la règle de JoVenGer du 17/10 (la plus juste pour la réalité du camp gagne, l'autre s'éteint) et la note de JoVenGer
(étape 3 : le guichet).

## 3 a — Les interrupteurs (17/10)
- Une table en données, `Scriptorium.noyau.interrupteurs`, au catalogue (section `interrupteurs`) : 1 allumé, 0 éteint
  (le fichier de réglages transporte déjà les nombres). `Scriptorium.actif(nom)` les lit ; un nom inconnu est une
  erreur au banc.
- Éteints par défaut, d'après le tableau :
  - **Scriptorium décide** : `solde_de_la_semaine` (la solde et le départ pour impayé), `aguerrissement` (gains gelés,
    facteur de combat neutre), `rangs_du_socle` (capitaine et dizainiers d'office), `usure_en_points` (usure et
    entretien, facteur neutre), `fautes_a_l_aube` (le tirage des fautes), `rencontres_de_patrouille`.
  - **Ajouts reportés** (réponse de JoVenGer, 17/10) : `contrats_a_duree` (le départ en fin de contrat),
    `exactions` (la réputation et ses prix), `baisse_du_risque` (les patrouilles).
- **Allumé par défaut, l'exception** (relecture du pair, 17/10) : `repas_du_socle` (les rations prises aux vivres) ; rien
  ne change tant que Scriptorium ne le coupe pas ; coupé, Scriptorium nourrit (l'entretien), les soins et le compte de
  la journée continuent. Avec lui, `hommes.jour_d_entretien(heure)`, qui change à `heure_d_entretien` (20 h).
- Déjà conformes, sans interrupteur : pas de palissade posée d'office (l'enceinte ne se bâtit que sur demande) ; les
  heures et les nombres de gardes sont des réglages que Scriptorium écrira (la journée en tranches, elle, reste à
  ouvrir au guichet : 3 b).
- Au banc : les essais d'avant allument tout (leur comportement ne change pas) ; un essai par interrupteur éteint.

## 3 b — Le guichet lui-même
- **L'horloge (17/10)** : la journée des hommes (`hommes.journee`) et celle du Directeur (`directeur.journee`) sont des
  listes à nom, réglables par le fichier (sections `journee` et `journee_du_directeur`, chemins comme
  `journee.sommeil.a`). Scriptorium y pose son réveil (7 h) et son coucher (22 h). La nuit (garde de nuit) est la
  tranche du sommeil, plus une heure écrite en dur. Une journée boiteuse (trou, tranche vide, deux fois la même
  activité de suite, autre chose que 24 h) est refusée en entier : `Scriptorium.journee_valable`. Plusieurs valeurs se
  posent ensemble (`regler.py journee.sommeil.a=7 journee.lever.de=7 …`).
- **Le jour de repos (réponse du pair, 17/10)** : tout le camp le même jour, un jour sur cinq, calculé par Scriptorium,
  rien dans la partie. Le socle n'a besoin que de l'accroche « une mission peut-elle partir ? » (étape 4), que
  Scriptorium enveloppe pour dire non.
- La liste de ce que Scriptorium attend (missions, embauche, métiers) est arrivée du pair le 17/10 : elle se traite aux
  étapes 4 et 5 (sources : `NOTE_POUR_LE_SOCLE.md` parties 6 et 7, `NOTE_METIERS.md`, `CONTRAT_DU_SOCLE.md`, en lecture
  seule, sans en reprendre aucun nom).

## Poser un homme (demande du pair, 21/10, J6)
- `hommes.poser(qui, point)` : « qui » est l'identifiant d'un homme, ou le nom d'entité d'un homme ou d'un mené ; le
  point est un point du monde. Jamais sous les yeux d'Henry (ni d'où il part, ni où il arrive). En selle sur son cheval
  de sortie : le cheval est posé au point (`liaison.poser_le_cheval`), le cavalier avec lui ; à pied : l'homme par la
  téléportation du jeu (l'ordre 10 du secours), son cheval de sortie posé près du point. Son ordre est redonné au
  battement suivant. Rend vrai, ou faux et la raison (`homme_inconnu`, `point_invalide`, `personnage_introuvable`,
  `vu_d_henry`, `pose_refusee`). C'est la seule voie de l'expédition de Scriptorium pour avancer un homme hors de vue
  (vu en J6 : un homme en selle ne bougeait pas par un SetWorldPos sur l'homme seul).
- Essai (vérifié en échec sans) ; non vu en jeu : que le cavalier suive bien son cheval posé.

## L'horaire de Scriptorium (demande de JoVenGer du 22/10, transmise par le pair)
- Vu (copie de sa partie, 5 h 58) : sommeil 0, « lever » 33 (debout au feu central) ; notre journée disait « sommeil 22 → 5,
  lever 5 → 7 », Scriptorium dit au lit jusqu'à 7 h (`scriptorium.journee.COUCHER` = 22, `LEVER` = 7) : deux heures
  debout dans le noir. C'est Scriptorium qui décide de l'horaire.
- Désormais, au battement (`hommes.suivre_l_horaire_de_scriptorium`) : quand Scriptorium donne COUCHER et LEVER, le
  sommeil va de COUCHER à LEVER moins `hommes.reglages.lever_duree_h` (0,5), le lever jusqu'à LEVER ; la veillée finit au
  coucher, le repas du matin commence au lever ; l'aube du socle (`heure_lever` : contrats, désertions) suit LEVER. Une
  journée qui ne tiendrait plus (`Scriptorium.journee_valable`) n'est pas posée, une ligne au journal. Sans Scriptorium,
  nos tranches (réglables).
- Essai (vérifié en échec sans : levé à 6 h au lieu d'au lit) ; à voir en jeu au lever de 6 h 30.

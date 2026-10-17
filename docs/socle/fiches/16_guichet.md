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

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
- Déjà conformes, sans interrupteur : pas de palissade posée d'office (l'enceinte ne se bâtit que sur demande) ; les
  heures et les nombres de gardes sont des réglages que Scriptorium écrira (la journée en tranches, elle, reste à
  ouvrir au guichet : 3 b).
- Au banc : les essais d'avant allument tout (leur comportement ne change pas) ; un essai par interrupteur éteint.

## 3 b — Le guichet lui-même (à suivre)
- La liste des services et des accroches, d'après la note de JoVenGer et ce que la conversation Scriptorium prépare
  (missions, embauche, métiers).

# Fiche 19 — Les décisions remplaçables (demande du pair du 17/10, pour la bascule)

Source : la vérification du pair dans les dossiers de Scriptorium (17/10). Scriptorium n'agit pas seulement avant ou
après les décisions du socle : souvent il les **remplace** (l'activité d'un homme, le siège, la cible au combat, la
taille et la fin d'un camp de bandits…). Les 40 accroches du contrat (lignes A1 à A40 du guichet) doivent donc être des
points remplaçables.

## La règle d'une décision remplaçable

1. Une fonction **publique** de la table du morceau (`Scriptorium.hommes.activite_de`…), jamais une locale.
2. Le socle l'appelle **toujours à travers la table**, à chaque emploi, jamais par une copie capturée : si Scriptorium la
   remplace par la sienne (qui peut appeler l'ancienne), c'est la sienne qui joue.
3. Le socle **emploie la valeur rendue** : une valeur différente change vraiment la décision.
4. **nil = pas d'avis** : la décision du socle s'applique. Faux reste faux (un « non » de Scriptorium n'est jamais
   changé en « oui » par défaut).

## Le moyen (noyau)

- `Scriptorium.remplacable(morceau, nom, valable)` : posé juste après la définition ; garde la décision du socle (la
  fonction d'origine) et, au besoin, un contrôle de la valeur rendue.
- `Scriptorium.avis(morceau, nom, ...)` : la demande. Si la fonction est encore celle du socle, appel direct (aucun coût).
  Sinon, la remplaçante sous `pcall` : en erreur, une ligne au journal et la décision du socle ; nil, la décision du
  socle ; une valeur que `valable` refuse, une ligne au journal et la décision du socle ; sinon sa valeur (toutes).
- `Scriptorium.decision_du_socle(morceau, nom)` : la fonction d'origine (pour les essais, et pour qui veut l'appeler).
- Les accroches d'observation (avant, après) restent à côté.

## Grappes (une à la fois, chacune avec ses essais : remplacer, vérifier que la décision suit ; nil ; erreur)

1. Les décisions déjà publiques, rendues sûres (nil, erreur, valeur boiteuse) et appelées par `Scriptorium.avis` ; la
   ronde passée au moteur par la table, plus par une copie.
2. Le combat (`bataille.lua`) : l'ennemi valable, la cible d'un de nos hommes, la cible d'un brigand, le combattant
   figé, le sort des survivants.
3. Les hommes (`hommes.lua`) : le choix de l'équipement (tenue, armes, munitions), la nuit, la tenue la plus forte.

Les noms publics nouveaux sont écrits au guichet dans le même commit et dits au pair (son interface).

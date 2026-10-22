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

## Fait

- **Grappe 1** (commit 0e5e9f9) : remplaçables et appelées par `Scriptorium.avis` : `camp.places_libres`,
  `camp.dans_le_monde`, `hommes.activite_de`, `hommes.gardes`, `hommes.libre_pour`, `hommes.rattraper`,
  `hommes.pas_de_ronde` (confiée au moteur par la table), `directeur.activite`, `missions.taille_du_camp`,
  `missions.lieu_reserve` (un « faux » de Scriptorium : libre), `missions.peut_partir`, `missions.niveau_pour`,
  `bataille.force_d_un_homme`, `bataille.issue_au_loin`, `bataille.peut_fouiller`, `jeu.sol_de` (liaison). Le partage du
  butin (argent) est appelé par la table, nil = partage du socle, mais garde sa règle stricte : en erreur ou absurde,
  tout reste au coffre.
- **Grappe 2** (le combat) : `bataille.ennemi_valable(bande, personnage)`, `bataille.cible_de(bande, id, vivants,
  actuelle, rang)` (Scriptorium peut changer la cible à tout moment : l'ordre est alors donné, même en plein combat),
  `bataille.cible_de_la_bande(bande, personnage, cibles, actuelle, rang)`, `bataille.a_relancer(bande, personnage, nom,
  cible)`, `bataille.sort_des_survivants(bande, survivants)` (« fuite », « rester », « laisser » : le socle ne les touche
  plus) ; lecture : `bataille.cibles(bande)`. Le comportement par défaut est inchangé (banc entier vert) ; trois
  contournements injectés, attrapés.
- **Grappe 3** (les hommes) : `hommes.choix_de_l_equipement(id)` → `{ tenue, armes, munitions }` (noms de préréglages
  du jeu, éprouvés : chacun doit avoir des pièces) ou faux (aucun) ; `hommes.est_nuit(heure_du_jour)` ;
  `hommes.regle_la_plus_forte(id)` → la règle dont la tenue l'emporte, ou faux (aucune) ; une règle que l'homme ne
  porte pas, ou inconnue des priorités, laisse la décision du socle (sans ligne au journal : elle est demandée à chaque
  battement). Trois contournements injectés, attrapés.

## Ce qui n'est pas une décision (dit au pair)

- **Les ordres** (A3 `tenir`, A4 `camp.reserver`, A11 `vider_la_fouille`, A12 `camp.fonder`, A17 `camp.lever`, A21
  `donner_une_piece`, A25 et A27 `tenir`, A30 `payer_la_solde`, A31 `retirer`, A36 `directeur.installer`, A39
  `directeur.suivre`) : publiques, et le socle les appelle par la table ; Scriptorium peut les remplacer, mais ce sont des
  actions : leur valeur (fait ou non, et la raison) n'a pas de « pas d'avis ».
- **Les observations** (A6 `missions.camp_vaincu`, `missions.rapport_de_mission`, `bataille.fouille_finie`) : appelées
  par la table sous `pcall` ; remplacées, la remplaçante agit à la place de l'annonce du socle. La fin d'un camp vient de
  sa bande : Scriptorium la tient ouverte par `bataille.ennemi_valable` et `missions.ajouter_un_personnage`.
- **Pas utiles** : A20, A26, A32 ; **étape 5** : A34, A35 (les postes, pas encore écrits).

**Vu en jeu le 17/10** (fumée, séance de l'étape 5) : le comportement par défaut inchangé : les ordres à chaque tranche (`activite_de` par `avis`), le tour de garde, le combat en tourniquet, la fouille. Les remplaçantes elles-mêmes sont éprouvées au banc seulement.

# Fiche 17 — Les missions (étape 4 du nécessaire)

Sources : la note de JoVenGer (`Scriptorium/docs/socle/NOTE_POUR_LE_SOCLE.md`, partie 6, lecture seule), la liste du
pair du 17/10 (ce que Scriptorium attend), la règle scellée « ennemis_au_contact » (les ennemis viennent attaquer,
personne ne reste figé). Deux recherches (mods KCD2 qui posent un camp de bandits ; naissance de groupes de PNJ) : rien
d'utilisable, seulement des demandes de mods et des guides du premier jeu. Le socle s'appuie sur ce qu'il sait déjà
faire : ses bandes (fiche 05, âmes de la fiche 13) et les meubles du camp (fiche 03, modèles déjà vus en jeu).

Découpage, une tranche à la fois, chacune vue en jeu avant la suivante :
1. le camp de bandits à un lieu (ci-dessous) ;
2. la mission et sa colonne (prendre, lieu, niveau selon la force, carte, à cheval aller et retour, issue calculée
   au-delà de 300 m, rapport) ; l'accroche « une mission peut-elle partir ? » (le jour de repos de Scriptorium) ;
3. plusieurs missions à la fois (réservation des lieux), puis les convois.

## Tranche 1 — Le camp de bandits à un lieu

Réponses prises d'office (consigne du 17/10 : l'option recommandée, notée ici) :
- **Un morceau `missions`** tient les lieux, les camps de bandits et (tranche 2) les missions. **Le combat reste à la
  bataille** : les hommes d'un camp de bandits sont une bande « postée » (pas de deuxième machine à combat).
- **Les lieux sont fournis par Scriptorium** (`missions.ajouter_un_lieu(nom, carte, position, cap)`), jamais devinés :
  le socle n'en connaît aucun ; le poste d'essai en pose un devant Henry.
- **Le coffre du camp est une somme** (selon la taille) ; vaincu, sa part entre au coffre de la compagnie par le partage
  du butin de la bataille (règle de Scriptorium, enveloppable). Pas de pillage de notre camp si on perd là-bas.
- **Rien ne naît ailleurs ni sous les yeux d'Henry** : meubles et hommes du camp naissent quand Henry est sur la carte
  du lieu et que le lieu n'est pas dans son regard (`henry_voit`, le même seuil que le secours) à moins de
  `naissance_vue_m` (300 m).
- **L'alerte** : Henry ou un de nos hommes à moins de `alerte_m` (35 m) du lieu : la bande passe au contact et
  attaque (ordre 8, relance des figés : tout ce que la bataille fait déjà). Combattants : nos hommes à moins de
  `engagement_m` (80 m) du lieu.
- **Henry seul** : la bataille ne finit que quand la bande est tombée ; Henry à plus de `fuite_m` (300 m) sans aucun de
  nos combattants debout : la bande retourne à son poste avec ses survivants (rien n'est tranché).
- **Au chargement** : meubles et hommes du camp de bandits sont retirés et refaits depuis le registre (les survivants
  comptés au dernier battement), comme le camp (fiche 03).
- **Après la victoire** : les corps et les meubles restent `duree_des_corps` (24 h), puis le camp est levé et le lieu
  redevient libre.

Accroches (fonctions publiques du morceau, que Scriptorium remplace en appelant l'ancienne) :
- `missions.taille_du_camp(lieu, niveau)` rend `{ sorte, effectif, coffre }` ;
- `missions.camp_vaincu(camp)` est appelée une fois, à la victoire (par défaut : une ligne au journal et l'annonce).

Services : `ajouter_un_lieu`, `lieux(carte)`, `dresser_un_camp(lieu, niveau)`, `camp(id)`, `camps()`,
`lever_un_camp(id)`, `lieu_sur_ma_carte(lieu)`.

Réglages au catalogue : `missions.reglages` (section `missions`), `missions.niveaux` (section `niveaux_des_camps`),
`missions.plan` (section `plan_des_camps`).

À reprendre plus tard : un vrai coffre du jeu à fouiller au milieu du camp ; les bandits assis au feu ou couchés.

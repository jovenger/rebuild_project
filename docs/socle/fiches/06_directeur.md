# Fiche 06 — Le Directeur

- Morceau : 6. Table : `Scriptorium.directeur`. Fichier : `socle/pak/Scripts/scriptorium/directeur.lua`.
- État : écrit et passé au banc ; vu en jeu (le Directeur vient à sa tente, âme provisoire ; menu et rapport au journal par le poste d'essai). Validée par JoVenGer le 14/10/2026 : journée, prix, coût de l'agrandissement et menu tels quels. Son âme, son apparence et le dialogue qui ouvre le menu attendent la section 6 (V20, V21).
- Avec la fiche 11 (caractère, 15/10) : une entrée de plus, « Connaître ses hommes » (ce que la Compagnie sait de chacun, en mots) ; vingt entrées en tout.

## Ce que le joueur voit
- Un personnage neuf, `Scriptorium_Directeur`, qui vit au camp : le jour à son coffre, le soir au feu, la nuit dans sa tente. Il tient le livre de comptes, paie la solde, signe les contrats et ouvre la Gestion du camp.
- La **Gestion du camp** : un menu en français, ouvert en parlant au Directeur. Chaque entrée dit si elle est possible et pourquoi pas sinon.
- Un **rapport** en clair : groschen au coffre, réserves, hommes (valides, blessés, moral), prochaine paie, bandes en marche, dernières batailles.
- « Le Directeur a pris ses fonctions. » à son arrivée.

## Règles
- **Un seul Directeur.** `installer()` le fait venir dans sa tente (place `lit_directeur` réservée pour lui). Refus sans camp. `redresser()` le fait revenir s'il manque. Il part quand le camp est levé.
- **Sa journée :** 6 h à 20 h au coffre du camp (`coffre_camp`) ; 20 h à 22 h au feu ; 22 h à 6 h sur son lit. Un ordre au jeu seulement quand l'activité change.
- **Le menu est en données** (`directeur.menu()`), pas dans le code des écrans : une liste d'entrées, chacune avec sa clé de texte, son action, ce qu'elle demande comme paramètres, et si elle est possible (`disponible`, `raison`). Un écran, un dialogue ou le poste d'essai le présente tel quel.
- **Les actions** (`directeur.agir(action, parametres)`) :
  - `rapport` ;
  - `livre` : les vingt dernières lignes ;
  - `payer_la_solde` : paie tout de suite (en plus de la paie hebdomadaire) ;
  - `engager` : rôle, semaines (prime par défaut) ;
  - `renvoyer` : identifiant ;
  - `nommer_capitaine` : identifiant ;
  - `renouveler` : identifiant, semaines ;
  - `acheter` : sorte, quantité, au prix de base (vivres 2, bière 1, fourrage 1, traits 1, bois 1, herbes 3, fer 5, cuir 3 groschen l'unité), modulé par la réputation auprès des villages (morceau 9), payé au coffre ;
  - `deposer` : montant, de la bourse d'Henry au coffre ;
  - `verser` : montant, du coffre à Henry ;
  - `agrandir_le_camp` : coûte du bois (30 par niveau) et des groschen (100 par niveau), au coffre ;
  - `lever_le_camp`.
  - Les morceaux 7 et 8 ajoutent leurs entrées (`enceinte`, `alchimie`, `patrouille`) par `directeur.ajouter_entree`.
- **Rien par la bourse d'Henry**, sauf `deposer` et `verser`, qui sont les actes du joueur.
- **Prix** en données (`directeur.prix`), tous entiers.
- **Enregistrement** : par les morceaux appelés ; le Directeur garde sa présence et sa dernière activité.

## Sorts rendus
`agir` rend `true` et un résultat, ou `false` et une raison : `action_inconnue`, `parametre_manquant`, `pas_de_directeur`, puis les raisons des morceaux appelés (`coffre_insuffisant`, `pas_de_lit`, `bois_insuffisant`, …).

## Ce qui est sauvegardé (case `directeur`, version 1)
`{ installe, personnage, derniere_activite }`.

## Ce que le Directeur demande au jeu (liaison)
`faire_venir_directeur(position, ame)` → identifiant ou nil (son âme : réserve « directeur », fiche 13) ; `personnage_existe` ; `renvoyer_homme` ; `ordonner` ; `heure_du_jeu` ; `journal`.

## À vérifier en jeu
- Comment faire venir le Directeur (âme à nous, apparence neuve, différente de tout intendant d'un autre mod) et ouvrir un dialogue avec lui qui présente le menu (système de dialogues du jeu) ; en attendant, le poste d'essai joue le menu par la console.

## Essais au banc (`essais/lua/essai_directeur.lua`)
Installation et refus ; journée du Directeur ; menu complet, disponibilités et raisons ; chaque action (succès et refus) ; achats au prix juste et au coffre ; agrandissement payé en bois et en groschen ; rapport ; redressement ; départ avec le camp ; écriture puis relecture ; entrées ajoutées par d'autres morceaux.

## L'installation à une place donnée (la bascule, demande du pair, 19/10/2026)
- `directeur.installer(position, cap)` : « position » et « cap » facultatifs ; là où il naît et revient à chaque
  chargement (gardés au registre). Sur un camp adopté, aucun lit du plan n'est réservé : son coucher lui vient de
  Scriptorium. Refus : camp_absent, deja_installe, position_invalide, cap_invalide.
- Non vérifié en jeu.

## La tâche « parler » (demande du pair, 19/10/2026)
- Vu à la seconde répétition de la bascule : le Directeur, qui va et vient à sa journée, ne se laissait pas aborder pour
  son dialogue (deux échecs).
- `directeur.parler(true, position, regard)` : il se tient debout au point, tourné vers « regard » (Henry), jusqu'à
  `directeur.parler(false)` ; elle passe devant sa journée et devant « suivre ». Refus : pas_de_directeur,
  position_invalide.
- Ordres d'essai : `scriptorium_essai_directeur_parler` (à 2,5 m devant Henry, face à lui) et
  `scriptorium_essai_directeur_parler_fin`.
- Non vérifié en jeu.

## Sur un camp adopté : jamais une place du plan (vu le 19/10 sur une copie de la partie de JoVenGer)
- Sa journée (comptes au coffre, veillée au feu, sommeil à son lit) visait les places de notre plan, relatives à l'ancre :
  sur le camp de JoVenGer, l'ancre est sa cabane, et le Directeur y entrait (0,8 m dans la boîte de la maison).
- Désormais, sur un camp adopté, `directeur.activite` prend la place que Scriptorium déclare à la place de celle du plan
  (`camp.declarer_les_places`, champ `remplace`, fiche 03) ; sans remplaçant, il reste à sa place d'installation
  (`directeur.installer(position, cap)`). Essai (vérifié qu'il échoue sans). Non vérifié en jeu.

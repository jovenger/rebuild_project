# Fiche 06 — Le Directeur

- Morceau : 6. Table : `Scriptorium.directeur`. Fichier : `socle/pak/Scripts/scriptorium/directeur.lua`.
- État : écrit et passé au banc. En attente de l'essai en jeu (venue du personnage, menu en jeu) et de la validation de la fiche par JoVenGer.

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
  - `acheter` : sorte, quantité, au prix du marché de la Compagnie (vivres 2, bière 1, fourrage 1, traits 1, bois 1, herbes 3, fer 5, cuir 3 groschen l'unité), payé au coffre ;
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
`faire_venir_directeur(position)` → identifiant ou nil ; `personnage_existe` ; `renvoyer_homme` ; `ordonner` ; `heure_du_jeu` ; `journal`.

## À vérifier en jeu
- Comment faire venir le Directeur (âme à nous, apparence neuve, différente de tout intendant d'un autre mod) et ouvrir un dialogue avec lui qui présente le menu (système de dialogues du jeu) ; en attendant, le poste d'essai joue le menu par la console.

## Essais au banc (`essais/lua/essai_directeur.lua`)
Installation et refus ; journée du Directeur ; menu complet, disponibilités et raisons ; chaque action (succès et refus) ; achats au prix juste et au coffre ; agrandissement payé en bois et en groschen ; rapport ; redressement ; départ avec le camp ; écriture puis relecture ; entrées ajoutées par d'autres morceaux.

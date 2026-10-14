# Avancement du socle

Périmètre (14/10) : refaire entièrement le mod d'Alex, à notre façon, comme mod à part. Sans toucher au Scriptorium actuel ni à son git. L'adaptation à Scriptorium viendra après.

| Morceau | Fiche | Code | Banc | Essai en jeu | Scellé |
|---|---|---|---|---|---|
| 0. Bandeau des messages | `fiches/00_bandeau.md` | `bandeau.lua` | 13 essais, passent | à faire (V1, V2, V6, V8, V15) | non |
| 1. Registre | `fiches/01_registre.md` | `registre.lua` | 12 essais, passent | à faire (V4, V5) | non |
| 2. Coffre et logistique | `fiches/02_coffre.md` | `coffre.lua` | 12 essais, passent | à faire (V9, V10) | non |
| 3. Camp : tentes, lits, feux | `fiches/03_camp.md` | `camp.lua` | 11 essais, passent | à faire (V11 à V14) | non |
| 4. Hommes au camp | `fiches/04_hommes.md` | `hommes.lua` | 17 essais, passent | à faire (V16, V17) | non |
| 5. Combat et batailles | `fiches/05_bataille.md` | `bataille.lua` | 12 essais, passent | à faire (V18, V19) | non |
| 6. Directeur et Gestion du camp | `fiches/06_directeur.md` | `directeur.lua` | 12 essais, passent | à faire (V20, V21) | non |
| 7. Enceinte, porte, atelier | `fiches/07_enceinte.md` | `enceinte.lua`, `atelier.lua` | 12 essais, passent | à faire (V22, V23) | non |
| 8. Patrouilles et battement commun | `fiches/08_patrouilles.md` | `patrouilles.lua`, `noyau.lua` | 11 essais, passent | à faire (V24) | non |
| 9. Discipline et justice (D7) | `fiches/09_discipline.md` | `discipline.lua` | 12 essais, passent | à faire (rien de neuf côté moteur) | non |
| Scénario complet (une semaine) | — | tous | 1 essai, passe | — | — |

Tous les morceaux sont écrits et passent au banc : 1 322 vérifications. Aucun n'est scellé : le scellé attend l'essai en jeu et la validation des fiches par JoVenGer.

## Socle commun
- `noyau.lua` : table `Scriptorium`, morceaux, démarrage tolérant aux pannes, battement commun toutes les trente secondes en partie seulement. 2 essais.
- `liaison.lua` : seul fichier qui parle au moteur ; 24 points « à vérifier en jeu » (`docs/socle/essai_en_jeu.md`).
- `poste.lua` : quatorze commandes de console d'essai. 6 essais.
- `essais/tout_verifier.py` : 6 étapes ; 1 322 vérifications au banc.
- `outils/empreintes.py` : relevé des empreintes d'Alex (à lancer sur le PC, en lecture seule).
- `noyau/installer.py` : installation dans `Mods\scriptorium_socle` seulement.
- `socle/textes/fr/text_ui__scriptorium_socle.xml` : 77 textes, tous employés.

## Ce que le socle fait, en une page
- **Bandeau :** tout message au joueur passe par une seule porte, un à la fois, alertes devant, sans répétition, regroupés, avec un complément (nom, montant).
- **Registre :** une seule sauvegarde versionnée, une case par morceau, montées de version, remise à neuf propre.
- **Coffre :** groschen du camp, livre de comptes, dix réserves (vivres, bière, fourrage, traits, bois, herbes, fer, cuir, remèdes, onguents) ; le camp ne paie jamais avec la bourse d'Henry.
- **Camp :** plan en données sur trois niveaux, fondé là où se tient Henry, agrandi, redressé après chargement, levé ; paillasses et sièges réservables.
- **Hommes :** contrats, prime, solde hebdomadaire par rang, rations et faim, moral, journée sur les heures, garde bornée au nombre d'hommes, dizainiers et capitaine, départs, soins, ordres au changement.
- **Bataille :** « lever une bande », avertissement, ordre de bataille d'époque, fin par le jeu ou par la règle, pertes, moral, pillage, butin partagé selon la coutume, escarmouches.
- **Directeur :** personnage à sa tente, sa journée, le rapport, la Gestion du camp en données (dix-huit entrées avec les morceaux 7 et 8).
- **Enceinte et atelier :** palissade, porte (jour, nuit, barrée), tours de guet, bonus de défense ; alchimie (remèdes, onguents, soins) ; armurerie (usure, entretien).
- **Patrouilles :** chemins en données, marche par points, rencontres (rien, rôdeurs, embuscade), risque qui bouge, avance de guet.
- **Discipline :** fautes à l'aube selon le moral (rixe, vol, ivresse, exaction), jugements par la Gestion du camp (pardon, amende retenue sur la solde, corvée, pilori, renvoi), prescription et laxisme, réputation auprès des villages qui module le prix des réserves.

## Pour plus tard
- À l'adaptation à Scriptorium : le socle vit dans `Scripts/scriptorium/` et dans la table globale `Scriptorium`, comme le mod `scriptorium` actuel. Sans effet pendant l'essai (les trois mods sont hors de `mod_order.txt`), mais c'est le premier conflit à régler.
- `docs/socle/idees_pour_plus_tard.md` : vingt-six idées notées le 14/10, à reprendre seulement quand le socle de base sera essayé en jeu et scellé.

## Prochaine étape
- JoVenGer : essai en jeu (`docs/socle/essai_en_jeu.md`), relevé des empreintes d'Alex, validation des fiches 02 à 08.
- Ensuite, d'après le jeu : corriger `liaison.lua` (sauvegarde, âmes, ordres, porte, affichage), renseigner `camp.modeles`, `enceinte.modeles`, `liaison.ames`, `liaison.ames_ennemies`, `liaison.ame_du_directeur` ; puis les tables du jeu (âmes, personnages) et la quête de fond, hors de ce premier passage.

## Journal
- 14/10/2026 : plan, règles, squelette, morceaux 0 et 1 au banc.
- 14/10/2026 : morceau 2 (coffre) au banc ; liaison : argent d'Henry et heure du jeu.
- 14/10/2026 : morceau 3 (camp) au banc ; plan en données sur 3 niveaux ; liaison : pose et retrait d'objets, position d'Henry.
- 14/10/2026 : morceau 4 (hommes) au banc ; bandeau : complément ; camp : places réservées, points.
- 14/10/2026 : morceaux 5 (bataille), 6 (Directeur), 7 (enceinte, atelier), 8 (patrouilles, battement commun) au banc ; scénario complet d'une semaine.
- 14/10/2026 : morceau 9 (discipline, décision D7) au banc ; note « Idées pour plus tard ».
- 14/10/2026 : préparation du premier essai, d'après `kcd.log` (jeu 1.5.6) et le wiki officiel de Warhorse : manifeste sans bloc `<supports>` (V7) ; démarrage déplacé dans `Scripts/Mods/scriptorium_socle.lua`, seul script de mod que le jeu exécute ; paks faits sans compression par l'installateur ; liste des mods (D10) et console (`-devmode`, touche ²) établies.
- 14/10/2026 : premier lancement avec le socle seul : manifeste accepté (V7), script de démarrage exécuté, 12 morceaux prêts, 0 en panne. Textes non chargés (V2) : fichier renommé `text_ui__scriptorium_socle.xml`, nom vérifié par `tout_verifier.py`.
- 14/10/2026 : la console ne s'ouvre pas (V3). Poste : ordres par fichier (`outils/ordonner.py` écrit `Mods\scriptorium_socle\ordres.lua`, `liaison.lire_ordres` le relit sans accès au jeu, liste blanche des quatorze commandes, numéro croissant, ordre en attente hors partie) et ligne de veille toutes les 30 s ; 35 vérifications de plus au banc, aller-retour avec la liaison dans `tout_verifier.py`.
- 14/10/2026 : deuxième essai (partie d'essai `playline2`) : journal complet lu au quitter, aucune ligne du socle après son démarrage : les minuteries posées au démarrage du mod ne tirent jamais (bandeau, poste, battement). Sondes posées par la liaison pour trouver le moyen qui tire en partie (`Script.SetTimer` simple ou « aussi en pause », `Script.SetTimerForFunction`, événements `System` par `UIAction.RegisterEventSystemListener`). Manifeste en ASCII (le « — » sortait mal dans la sauvegarde), vérifié par `tout_verifier.py`.
- 14/10/2026 : troisième essai, sondes lues : seules les minuteries posées à l'événement `OnGameplayStarted` tirent en partie (V24) ; cet événement dit aussi qu'une partie est chargée (V5). Le socle s'y abonne (`liaison.ecouter_la_partie`) ; à chaque entrée en partie, `Scriptorium.entrer_en_partie` repose les minuteries du battement, du bandeau et du poste (les anciennes boucles s'éteignent par génération), relit le registre et annonce « socle prêt » ; à la sortie, tout s'arrête. Sondes retirées. Banc : 1 366 vérifications.

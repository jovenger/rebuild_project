# Avancement du socle

Périmètre (14/10) : refaire entièrement le mod d'Alex, à notre façon, comme mod à part. Sans toucher au Scriptorium actuel ni à son git. L'adaptation à Scriptorium viendra après.

| Morceau | Fiche | Code | Banc | Essai en jeu | Scellé |
|---|---|---|---|---|---|
| 0. Bandeau des messages | `fiches/00_bandeau.md` | `bandeau.lua` | 12 essais, passent | à faire (V1, V2, V6, V8) | non |
| 1. Registre | `fiches/01_registre.md` | `registre.lua` | 12 essais, passent | à faire (V4, V5) | non |
| 2. Coffre et logistique | `fiches/02_coffre.md` | `coffre.lua` | 12 essais, passent | à faire (V9, V10) | non |
| 3. Camp : tentes, lits, feux | — | — | — | — | — |
| 4. Hommes au camp | — | — | — | — | — |
| 5. Combat et batailles | — | — | — | — | — |
| 6. Directeur | — | — | — | — | — |
| 7. Murs, porte, alchimie | — | — | — | — | — |
| 8. Patrouilles et le reste | — | — | — | — | — |

## Socle commun
- `noyau.lua` : table `Scriptorium`, morceaux, démarrage tolérant aux pannes. 2 essais.
- `liaison.lua` : seul fichier qui parle au moteur ; 10 points « à vérifier en jeu ».
- `poste.lua` : commandes de console d'essai. 3 essais.
- `essais/tout_verifier.py` : 6 étapes ; 221 vérifications au banc.
- `outils/empreintes.py` : relevé des empreintes d'Alex (à lancer sur le PC, en lecture seule).
- `noyau/installer.py` : installation dans `Mods\scriptorium_socle` seulement.

## Prochaine étape
- JoVenGer : essai en jeu des morceaux 0, 1 et 2 (`docs/socle/essai_en_jeu.md`), relevé des empreintes, validation de la fiche 02.
- Ensuite : morceau 3, le camp (tentes, lits, feux, sièges), fiche d'abord.

## Journal
- 14/10/2026 : plan, règles, squelette, morceaux 0 et 1 au banc.
- 14/10/2026 : morceau 2 (coffre) au banc ; liaison : argent d'Henry et heure du jeu.

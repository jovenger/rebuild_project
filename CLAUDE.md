# Projet : nouveau socle de Scriptorium (mod Kingdom Come: Deliverance II)

- Tout en français, sans exception. Réponses concises, techniques, en listes.
- Périmètre (14/10/2026) : refaire entièrement, à notre façon, le mod « Mercenaries » d'Alex, comme mod à part (`scriptorium_socle`). Son adaptation à Scriptorium viendra après, hors de ce chantier.
- Plan : `docs/socle/plan_de_refonte.md`. Suite : `docs/socle/plan_d_action.md`. Reprise : `docs/socle/reprise.md` (et la note à coller `docs/socle/note_complete.md`). Avancement : `docs/socle/avancement.md`. Fiches : `docs/socle/fiches/`. Essai en jeu : `docs/socle/essai_en_jeu.md`. Idées pour plus tard (pas maintenant) : `docs/socle/idees_pour_plus_tard.md`.

## Interdits (règle de JoVenGer du 14/10/2026)
- Ne jamais écrire dans le Scriptorium actuel (`C:\Users\maste\Desktop\Scriptorium`), ni dans son git local. Lecture seule, si JoVenGer la donne.
- Ne jamais toucher à la copie de sécurité `D:\Scriptorium V2\Scriptorium`.
- Ne jamais écrire dans `Mods\scriptorium`, `Mods\scriptorium_regles` ni `Mods\scriptorium_lumiere` du jeu, ni dans `Data\*.pak`. Le socle s'installe dans `Mods\scriptorium_socle` seulement (`noyau/installer.py`).
- Ne jamais charger la partie actuelle de JoVenGer avec le socle : partie d'essai à part.

## Règles de travail
- Jamais recopier, traduire ou renommer le code d'Alex : fiche de comportement d'abord (`docs/socle/fiches/`), code neuf ensuite, d'après la fiche seule.
- Décision de JoVenGer (15/10/2026, confirmée directement) : quand le socle bloque, la conversation Scriptorium regarde comment le mod d'Alex s'y prend et transmet SEULEMENT le principe (quel mécanisme du jeu employer), jamais son code, ses noms, ses fichiers ni sa structure. Claude n'ouvre toujours jamais le dossier d'Alex, écrit son propre code, et le contrôle d'absence reste strict.
- Une chose à la fois, menée jusqu'au bout ; rien laissé en essai ; pas de `TODO`.
- Pas de commit si `py -3.13 essais/tout_verifier.py` ne passe pas entièrement (ici : `python3`, avec `lupa` installé).
- Aucune action destructive sans l'accord de JoVenGer juste avant.
- Un message de JoVenGer pendant le travail se prend en compte tout de suite.
- Règle de JoVenGer (14/10/2026) : les règles, les agissements et le comportement des hommes et du camp doivent pouvoir être modifiés par le programme Scriptorium. Pendant le chantier, le programme est mis à part et le socle a son propre transport (fichiers du PC relus en jeu : ordres, et réglages par le morceau `reglages`, fiche 10) ; donc toute valeur de règle reste en données, dans une table du catalogue de `reglages.lua` (`*.reglages`, `camp.plan`, `bataille.sortes`, `atelier.soins`…), jamais écrite en dur dans le code.

## Où sont les choses
- `socle/pak/` : contenu du pak du mod (Lua sous `Scripts/scriptorium/`, démarrage dans `Scripts/Mods/scriptorium_socle.lua`, que le jeu exécute juste après `Scripts/main.lua`).
- `socle/textes/fr/` : textes de langue (clés `ui_scriptorium_<morceau>_<sujet>`).
- `socle/mod.manifest` : manifeste du mod.
- `liaison.lua` est le seul fichier qui parle au moteur ; tout le reste passe par `Scriptorium.jeu`. Les essais utilisent `essais/lua/faux_jeu.lua`.
- Morceaux, dans l'ordre de chargement : `noyau`, `liaison`, `bandeau`, `registre`, `coffre`, `camp`, `hommes`, `bataille`, `directeur`, `enceinte`, `atelier`, `patrouilles`, `discipline`, `caractere`, `reglages`, `poste`. Chaque morceau a sa fiche dans `docs/socle/fiches/` et son essai dans `essais/lua/`. Le battement commun (`Scriptorium.battre`) fait avancer bataille, hommes, discipline, directeur, enceinte, atelier, patrouilles.
- Pour ajouter un morceau : fiche, fichier Lua dont la première ligne de code est `local Scriptorium = Scriptorium` (seul le noyau pose la table ; à la bascule elle deviendra `scriptorium.socle` ; aucun nom ne diffère d'un autre par une majuscule seulement, vérifié par `tout_verifier.py`, 3 bis), déclaré par `Scriptorium.declarer_morceau`, ligne dans `Scripts/Mods/scriptorium_socle.lua` et dans `ORDRE_SOCLE` de `essais/tout_verifier.py`, textes en clés `ui_scriptorium_…` tous employés, essais, et ses tables de valeurs ajoutées au catalogue de `reglages.lua` (règle de JoVenGer : tout réglable par le programme Scriptorium).
- `essais/lua/essai_*.lua` : banc d'essai, lancé par `essais/tout_verifier.py` (Lua 5.1 via lupa).
- `outils/empreintes.py` : relevé des empreintes d'Alex, pour le contrôle d'absence.
- `outils/verifier_modeles.py` : vérifie que les modèles appelés par le camp et l'enceinte existent dans les paks du jeu (lecture seule).
- `outils/ordonner.py` : ordres au poste d'essai sans console (fichier `Mods\scriptorium_socle\ordres.lua`, relu par `liaison.lire_ordres`).
- `outils/pilotage/` : séance d'essai en jeu sans que JoVenGer touche à rien (`debut_essai.ps1`, `vers_partie1.ps1`, `confirmer_partie1.ps1`, `touches.ps1`, `tour.ps1`, `fin_essai.ps1` ; captures dans `securite\captures`, hors de git).
- `outils/regler.py` : réglages par fichier (`Mods\scriptorium_socle\reglages.lua`, relu par `liaison.lire_reglages`, appliqué par le morceau `reglages`, fiche 10) ; chaque valeur est éprouvée par le socle avant d'être écrite ; `--liste` donne les valeurs réglables. L'installateur garde ce fichier.

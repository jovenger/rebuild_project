# Projet : nouveau socle de Scriptorium (mod Kingdom Come: Deliverance II)

- Tout en français, sans exception. Réponses concises, techniques, en listes.
- Périmètre (14/10/2026) : refaire entièrement, à notre façon, le mod « Mercenaries » d'Alex, comme mod à part (`scriptorium_socle`). Son adaptation à Scriptorium viendra après, hors de ce chantier.
- Plan : `docs/socle/plan_de_refonte.md`. Avancement : `docs/socle/avancement.md`. Fiches : `docs/socle/fiches/`. Essai en jeu : `docs/socle/essai_en_jeu.md`. Idées pour plus tard (pas maintenant) : `docs/socle/idees_pour_plus_tard.md`.

## Interdits (règle de JoVenGer du 14/10/2026)
- Ne jamais écrire dans le Scriptorium actuel (`C:\Users\maste\Desktop\Scriptorium`), ni dans son git local. Lecture seule, si JoVenGer la donne.
- Ne jamais toucher à la copie de sécurité `D:\Scriptorium V2\Scriptorium`.
- Ne jamais écrire dans `Mods\scriptorium`, `Mods\scriptorium_regles` ni `Mods\scriptorium_lumiere` du jeu, ni dans `Data\*.pak`. Le socle s'installe dans `Mods\scriptorium_socle` seulement (`noyau/installer.py`).
- Ne jamais charger la partie actuelle de JoVenGer avec le socle : partie d'essai à part.

## Règles de travail
- Jamais recopier, traduire ou renommer le code d'Alex : fiche de comportement d'abord (`docs/socle/fiches/`), code neuf ensuite, d'après la fiche seule.
- Une chose à la fois, menée jusqu'au bout ; rien laissé en essai ; pas de `TODO`.
- Pas de commit si `py -3.13 essais/tout_verifier.py` ne passe pas entièrement (ici : `python3`, avec `lupa` installé).
- Aucune action destructive sans l'accord de JoVenGer juste avant.
- Un message de JoVenGer pendant le travail se prend en compte tout de suite.
- Règle de JoVenGer (14/10/2026) : les règles, les agissements et le comportement des hommes et du camp doivent pouvoir être modifiés par le programme Scriptorium. Pendant le chantier, le programme est mis à part et le socle a son propre transport (fichier d'ordres) ; donc toute valeur de règle reste en données (`*.reglages`, `camp.plan`, `bataille.sortes`, `atelier.soins`…), jamais écrite en dur dans le code.

## Où sont les choses
- `socle/pak/` : contenu du pak du mod (Lua sous `Scripts/scriptorium/`, démarrage dans `Scripts/Mods/scriptorium_socle.lua`, que le jeu exécute juste après `Scripts/main.lua`).
- `socle/textes/fr/` : textes de langue (clés `ui_scriptorium_<morceau>_<sujet>`).
- `socle/mod.manifest` : manifeste du mod.
- `liaison.lua` est le seul fichier qui parle au moteur ; tout le reste passe par `Scriptorium.jeu`. Les essais utilisent `essais/lua/faux_jeu.lua`.
- Morceaux, dans l'ordre de chargement : `noyau`, `liaison`, `bandeau`, `registre`, `coffre`, `camp`, `hommes`, `bataille`, `directeur`, `enceinte`, `atelier`, `patrouilles`, `discipline`, `poste`. Chaque morceau a sa fiche dans `docs/socle/fiches/` et son essai dans `essais/lua/`. Le battement commun (`Scriptorium.battre`) fait avancer bataille, hommes, discipline, directeur, enceinte, atelier, patrouilles.
- Pour ajouter un morceau : fiche, fichier Lua déclaré par `Scriptorium.declarer_morceau`, ligne dans `Scripts/Mods/scriptorium_socle.lua` et dans `ORDRE_SOCLE` de `essais/tout_verifier.py`, textes en clés `ui_scriptorium_…` tous employés, essais.
- `essais/lua/essai_*.lua` : banc d'essai, lancé par `essais/tout_verifier.py` (Lua 5.1 via lupa).
- `outils/empreintes.py` : relevé des empreintes d'Alex, pour le contrôle d'absence.
- `outils/verifier_modeles.py` : vérifie que les modèles appelés par le camp et l'enceinte existent dans les paks du jeu (lecture seule).
- `outils/ordonner.py` : ordres au poste d'essai sans console (fichier `Mods\scriptorium_socle\ordres.lua`, relu par `liaison.lire_ordres`).

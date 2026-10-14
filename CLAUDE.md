# Projet : nouveau socle de Scriptorium (mod Kingdom Come: Deliverance II)

- Tout en français, sans exception. Réponses concises, techniques, en listes.
- Périmètre (14/10/2026) : refaire entièrement, à notre façon, le mod « Mercenaries » d'Alex, comme mod à part (`scriptorium_socle`). Son adaptation à Scriptorium viendra après, hors de ce chantier.
- Plan : `docs/socle/plan_de_refonte.md`. Avancement : `docs/socle/avancement.md`. Fiches : `docs/socle/fiches/`. Essai en jeu : `docs/socle/essai_en_jeu.md`.

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

## Où sont les choses
- `socle/pak/` : contenu du pak du mod (Lua sous `Scripts/scriptorium/`, démarrage sous `Scripts/Startup/`).
- `socle/textes/fr/` : textes de langue (clés `ui_scriptorium_<morceau>_<sujet>`).
- `socle/mod.manifest` : manifeste du mod.
- `liaison.lua` est le seul fichier qui parle au moteur ; tout le reste passe par `Scriptorium.jeu`. Les essais utilisent `essais/lua/faux_jeu.lua`.
- `essais/lua/essai_*.lua` : banc d'essai, lancé par `essais/tout_verifier.py` (Lua 5.1 via lupa).
- `outils/empreintes.py` : relevé des empreintes d'Alex, pour le contrôle d'absence.

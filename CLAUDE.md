# Projet : mod Kingdom Come: Deliverance 2

- Le programme `tools/director/` (IA Ollama externe) dirige Claude ; voir `tools/director/README.md`.
- Ordre : recherche -> spec -> arborescence -> assets -> données -> localisation -> packaging -> test.
- Docs : `docs/requests.md` (demandes), `docs/research/` (sources), `docs/spec/` (specs), `docs/audit/` (cohérence), `docs/native-catalog/` (briques natives).
- Ne pas inventer de conventions KCD2 : vérifier, citer la source.
- Réponses : concises, techniques, en listes.

## Mod : Scriptorium
- Dossier (PC de Yann) : `C:\Users\maste\Desktop\Scriptorium` (hors de ce dépôt) -> `MOD_DIR`.
- Conventions observées dans une session existante [À VÉRIFIER avec `adopt`] : un dossier `choses/<metier>/*.lua` par fonction ; noyau Python (`py -3.13 -m noyau.choses`) ; outils `outils_de_session/` ; modules « scellés » ; points de sauvegarde `securite/`.
- Règle de Yann : pas de nouveau dossier qui tire les PNJ de son côté ; toute nouveauté reste dans le dossier de son métier et réutilise le mécanisme existant (ex. forge -> armurier).
- Ne jamais modifier Scriptorium pendant qu'une autre session Claude y travaille.
- Jeu (`GAME_DIR`) : `G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2` (Mods\, Data\*.pak en lecture seule). Ne jamais toucher aux fichiers du jeu.
- Résumé détaillé (sur le PC, non publié) : `Scriptorium\docs\RESUME_POUR_DIRECTEUR.md`. Scriptorium n'a aucun dépôt distant (git local uniquement).
- État rapporté au 6/10 : 237 dossiers dans `choses/`, 231 scellés, 6 en essai, banc 6554/6554 ; étape en cours : « chef de la vie du camp » (sommeil). Règles rapportées : français uniquement, sceaux, `mettre_de_cote`, garde.

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

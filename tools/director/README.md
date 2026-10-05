# Directeur (IA locale Ollama) -> Claude

Boucle : demande de Yann -> brief profond (intention, critères, interdits, natif) -> ordre à Claude
-> Claude exécute et fournit preuves (captures dans `docs/evidence/`, logs) -> le directeur juge
(texte + images via VISION_MODEL) -> OK, ou "non, Yann veut ça" -> Claude corrige. Journal: `docs/audit/director-log.md`.

Prérequis: Ollama lancé, `claude` installé, session Claude existante (`CLAUDE_SESSION`, optionnel).

    ollama pull qwen3:14b          # cerveau (ou plus gros si le PC le permet)
    ollama pull qwen2.5vl          # vision (optionnel)
    MOD_DIR=C:\chemin\mod CLAUDE_SESSION=<id> VISION_MODEL=qwen2.5vl python3 tools/director/director.py "atelier de forgeron"

Claude doit pouvoir produire les captures lui-même (ex. via un outil de capture d'écran sur le PC) ; sinon il décrit en texte.

## Reprendre le mod là où il en est
1. `python3 tools/director/director.py adopt` : Claude inventorie le mod existant (fichiers, git log, fait/partiel/manquant, bugs, dernière action) -> `docs/state/STATE.md`. À relire une fois.
2. Chaque nouvelle demande part de cet état (le directeur ne refait pas ce qui existe) ; l'état est mis à jour après chaque réussite.
3. Si le run est interrompu (PC éteint, etc.) : relancer sans argument reprend au tour en cours (`docs/state/run.json`).

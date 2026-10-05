# Directeur (IA locale Ollama) -> Claude

Boucle : demande de Yann -> brief profond (intention, critères, interdits, natif) -> ordre à Claude
-> Claude exécute et fournit preuves (captures dans `docs/evidence/`, logs) -> le directeur juge
(texte + images via VISION_MODEL) -> OK, ou "non, Yann veut ça" -> Claude corrige. Journal: `docs/audit/director-log.md`.

Prérequis: Ollama lancé, `claude` installé, session Claude existante (`CLAUDE_SESSION`, optionnel).

    ollama pull qwen3:14b          # cerveau (ou plus gros si le PC le permet)
    ollama pull qwen2.5vl          # vision (optionnel)
    MOD_DIR=C:\chemin\mod CLAUDE_SESSION=<id> VISION_MODEL=qwen2.5vl python3 tools/director/director.py "atelier de forgeron"

Claude doit pouvoir produire les captures lui-même (ex. via un outil de capture d'écran sur le PC) ; sinon il décrit en texte.

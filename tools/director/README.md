# Directeur — programme IA externe à Claude

Cerveau : Ollama (sur le PC). Il comprend la demande de Yann, **fait ses propres recherches** (fichiers du mod Scriptorium,
fichiers du jeu, web), **donne les ordres à Claude**, **contrôle le résultat** (texte + captures) et renvoie Claude corriger :
« non, ce n'est pas ce que Yann veut, il veut ça, ça et ça ».

    Yann -> DIRECTEUR (Ollama) --ordre--> Claude (claude -p) --résultat + preuves--> DIRECTEUR --ok / redo--> ...

## Installation (Windows)
    ollama pull qwen3:14b        # cerveau (un modèle avec "tools"; plus gros = meilleur)
    ollama pull qwen2.5vl        # vision, pour juger les captures (optionnel)
    set MOD_DIR=C:\Users\maste\Desktop\Scriptorium
    set GAME_DIR=<dossier d'installation de KCD2>
    set VISION_MODEL=qwen2.5vl
    python tools\director\director.py adopt          # 1 fois: Claude inventorie Scriptorium -> docs/state/STATE.md
    python tools\director\director.py                # mode interactif (reprend la demande interrompue)
    python tools\director\director.py "atelier de forgeron"

Variables: OLLAMA_MODEL, VISION_MODEL, MOD_DIR, GAME_DIR, CLAUDE_SESSION (reprendre une session précise), MAX_ROUNDS (6), MAX_RESEARCH (12), OLLAMA_URL.

## Fichiers
- `docs/state/STATE.md` : état du mod (mis à jour après chaque réussite) ; `run.json` : reprise après interruption
- `docs/audit/director-log.md` : tout ce que le directeur a cherché, ordonné et jugé
- `docs/evidence/` : captures que Claude dépose pour que le directeur les voie

## Limites
- Ne pas lancer pendant qu'une autre session Claude modifie Scriptorium.
- Sans `VISION_MODEL`, le directeur ne voit pas les images : il juge le texte de Claude.
- Un petit modèle Ollama juge moins bien ; changer `OLLAMA_MODEL` au besoin.

#!/usr/bin/env python3
"""Directeur : une IA locale (Ollama) comprend la demande de Yann, donne les ordres
à Claude (session existante), contrôle le résultat (texte + images) et renvoie
Claude corriger tant que ce n'est pas ce que Yann veut.

Usage:
  MOD_DIR=... CLAUDE_SESSION=<id> python3 tools/director/director.py "atelier de forgeron"

Env:
  OLLAMA_URL     (défaut http://localhost:11434)
  OLLAMA_MODEL   modèle de raisonnement (défaut qwen3:14b)
  VISION_MODEL   modèle d'images, optionnel (ex. llava, qwen2.5vl) : sans lui, le directeur juge sur le texte de Claude
  CLAUDE_SESSION id de la session Claude à reprendre (sinon nouvelle session)
  MAX_ROUNDS     défaut 6
"""
import base64, json, os, pathlib, subprocess, sys, time, urllib.request

OLLAMA = os.environ.get("OLLAMA_URL", "http://localhost:11434")
BRAIN = os.environ.get("OLLAMA_MODEL", "qwen3:14b")
VISION = os.environ.get("VISION_MODEL", "")
MOD_DIR = pathlib.Path(os.environ.get("MOD_DIR", ".")).resolve()
ROOT = pathlib.Path(__file__).resolve().parents[2]
EVID = ROOT / "docs" / "evidence"
LOG = ROOT / "docs" / "audit" / "director-log.md"
MAX_ROUNDS = int(os.environ.get("MAX_ROUNDS", "6"))
session = os.environ.get("CLAUDE_SESSION", "")

def chat(model, system, user, images=None, as_json=False):
    msg = {"role": "user", "content": user}
    if images:
        msg["images"] = [base64.b64encode(p.read_bytes()).decode() for p in images]
    body = {"model": model, "stream": False,
            "messages": [{"role": "system", "content": system}, msg]}
    if as_json:
        body["format"] = "json"
    req = urllib.request.Request(OLLAMA + "/api/chat", json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=1800) as r:
        return json.load(r)["message"]["content"]

def ask_claude(prompt):
    global session
    cmd = ["claude", "-p", prompt, "--output-format", "json",
           "--permission-mode", "acceptEdits", "--add-dir", str(ROOT)]
    if session:
        cmd += ["--resume", session]
    out = subprocess.run(cmd, cwd=MOD_DIR, capture_output=True, text=True)
    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError:
        return f"[ERREUR Claude] {out.stderr or out.stdout}"
    session = data.get("session_id", session)
    return data.get("result", "")

def log(title, text):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a") as f:
        f.write(f"\n## {time.strftime('%F %T')} {title}\n\n{text}\n")

def images_since(t0):
    EVID.mkdir(parents=True, exist_ok=True)
    return sorted(p for p in EVID.iterdir()
                  if p.suffix.lower() in (".png", ".jpg", ".jpeg") and p.stat().st_mtime >= t0)

def describe(imgs, intent):
    if not imgs:
        return "(aucune image fournie)"
    if not VISION:
        return "(images reçues mais aucun VISION_MODEL configuré : " + ", ".join(p.name for p in imgs) + ")"
    return chat(VISION, "Décris précisément ce que montrent ces images, sans interpréter.",
                "Contexte du but recherché :\n" + intent, images=imgs)

SYS_BRIEF = """Tu es le DIRECTEUR d'un mod Kingdom Come: Deliverance 2 pour Yann.
Tu ne codes pas. Tu comprends ce que Yann veut vraiment, au fond, et tu le formules sans ambiguïté.
Réponds en JSON: {"intent": "ce que Yann veut, en profondeur",
"success_criteria": ["critères vérifiables en jeu/fichiers"],
"must_not": ["ce qu'il ne faut jamais faire"],
"native_requirement": "comment ce doit être natif au jeu",
"order": "ordre précis et complet pour Claude (développeur), avec les preuves à fournir"}.
Les preuves demandées à Claude: captures dans docs/evidence/, extraits de log, fichiers modifiés, chaque choix justifié par un équivalent natif du jeu."""

SYS_JUDGE = """Tu es le DIRECTEUR. Tu juges le travail de Claude contre l'intention de Yann et ses critères.
Sois exigeant: rejette si une preuve manque, si ce n'est pas natif, si c'est illogique ou si ça ne correspond pas à l'intention.
Réponds en JSON: {"verdict": "ok" | "redo", "feedback": "ce qui ne va pas, précisément",
"order": "si redo: l'ordre corrigé pour Claude, qui dit clairement ce que Yann veut: ...", "learned": "préférence de Yann à retenir, ou vide"}"""

def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    request = " ".join(sys.argv[1:])
    brief = json.loads(chat(BRAIN, SYS_BRIEF, "Demande de Yann: " + request, as_json=True))
    log("BRIEF", json.dumps(brief, ensure_ascii=False, indent=2))
    order = brief["order"]
    intent = json.dumps({k: brief[k] for k in ("intent", "success_criteria", "must_not", "native_requirement")},
                        ensure_ascii=False)
    for rnd in range(1, MAX_ROUNDS + 1):
        t0 = time.time()
        print(f"[tour {rnd}] ordre -> Claude")
        result = ask_claude(order + "\n\nContexte (intention de Yann):\n" + intent +
                            "\n\nFournis tes preuves: captures dans " + str(EVID) + ", logs, fichiers.")
        log(f"TOUR {rnd} — réponse de Claude", result)
        view = describe(images_since(t0), intent)
        verdict = json.loads(chat(BRAIN, SYS_JUDGE,
            f"Intention:\n{intent}\n\nOrdre donné:\n{order}\n\nRéponse de Claude:\n{result}\n\nImages:\n{view}",
            as_json=True))
        log(f"TOUR {rnd} — verdict", json.dumps(verdict, ensure_ascii=False, indent=2))
        print(f"[tour {rnd}] verdict: {verdict['verdict']}")
        if verdict["verdict"] == "ok":
            print("Terminé. Journal:", LOG); return
        order = verdict["order"] or verdict["feedback"]
    print(f"Arrêt après {MAX_ROUNDS} tours sans validation. Voir", LOG)

if __name__ == "__main__":
    main()

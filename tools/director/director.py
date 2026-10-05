#!/usr/bin/env python3
"""Directeur : une IA locale (Ollama) comprend la demande de Yann, donne les ordres
à Claude (session existante), contrôle le résultat (texte + images) et renvoie
Claude corriger tant que ce n'est pas ce que Yann veut.

Usage:
  python3 tools/director/director.py adopt                 # 1 fois: Claude inventorie le mod existant -> docs/state/STATE.md
  python3 tools/director/director.py "atelier de forgeron" # nouvelle demande, part de l'état actuel du mod
  python3 tools/director/director.py                       # reprend la demande interrompue (docs/state/run.json)

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
STATE = ROOT / "docs" / "state" / "STATE.md"
RUN = ROOT / "docs" / "state" / "run.json"
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

def state_text():
    return STATE.read_text() if STATE.exists() else "(aucun état: lance 'adopt' pour que Claude inventorie le mod existant)"

def save_run(**kw):
    RUN.parent.mkdir(parents=True, exist_ok=True)
    RUN.write_text(json.dumps(kw, ensure_ascii=False, indent=2))

def adopt():
    r = ask_claude("MODE: ADOPTION. Reprends ce mod là où il en est, sans rien modifier. Inventorie: dossier du mod, "
        "git log et notes existantes, fichiers/IDs, ce qui est fait / partiel / manquant, bugs connus, conventions "
        "déjà adoptées, dernière action en cours, prochaines étapes logiques. Écris le tout dans " + str(STATE) +
        " (crée le dossier). Marque les doutes [À VÉRIFIER]. Réponds par un résumé court.")
    log("ADOPTION", r); print(r); print("État écrit dans", STATE)

def main():
    global session
    if sys.argv[1:] == ["adopt"]:
        return adopt()
    start = 1
    if len(sys.argv) < 2:
        if not RUN.exists():
            sys.exit(__doc__)
        run = json.loads(RUN.read_text())
        if run.get("done"):
            sys.exit("Aucune demande en cours. Donne une nouvelle demande.")
        request, intent, order = run["request"], run["intent"], run["order"]
        session = run.get("session") or session
        start = run["round"]
        print(f"Reprise de la demande: {request} (tour {start})")
    else:
        request = " ".join(sys.argv[1:])
        brief = json.loads(chat(BRAIN, SYS_BRIEF,
            "Demande de Yann: " + request + "\n\nÉTAT ACTUEL DU MOD (pars de là, ne refais pas ce qui existe):\n" + state_text(),
            as_json=True))
        log("BRIEF", json.dumps(brief, ensure_ascii=False, indent=2))
        order = brief["order"]
        intent = json.dumps({k: brief[k] for k in ("intent", "success_criteria", "must_not", "native_requirement")},
                            ensure_ascii=False)
    for rnd in range(start, MAX_ROUNDS + 1):
        save_run(request=request, intent=intent, order=order, round=rnd, session=session, done=False)
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
            ask_claude("MODE: MISE À JOUR D'ÉTAT. Mets à jour " + str(STATE) + " avec ce qui vient d'être fait pour: " + request +
                       " (fait/partiel/manquant, bugs, prochaines étapes).")
            save_run(request=request, intent=intent, order=order, round=rnd, session=session, done=True)
            print("Terminé. Journal:", LOG); return
        order = verdict["order"] or verdict["feedback"]
    print(f"Arrêt après {MAX_ROUNDS} tours sans validation. Voir", LOG)

if __name__ == "__main__":
    main()

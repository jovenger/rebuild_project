#!/usr/bin/env python3
"""DIRECTEUR : programme IA externe à Claude (cerveau = Ollama, sur le PC de Yann).

Il réfléchit, fait ses propres recherches (fichiers du mod, fichiers du jeu, web), puis DIRIGE Claude :
  1. comprend la demande de Yann en profondeur (+ état actuel du mod)
  2. recherche ce qu'il faut savoir (le jeu natif, le mod, le web)
  3. donne un ordre précis à Claude
  4. contrôle ce que Claude a fait (texte + captures d'écran) et dit "non, Yann veut ça, ça et ça" tant que ce n'est pas bon

Usage:
  python director.py                       # mode interactif: tu tapes tes demandes (reprend une demande interrompue)
  python director.py "ta demande"          # une demande
  python director.py adopt                 # Claude inventorie le mod existant -> docs/state/STATE.md

Env (voir README): MOD_DIR, GAME_DIR, OLLAMA_MODEL, VISION_MODEL, CLAUDE_SESSION, MAX_ROUNDS, OLLAMA_URL
"""
import base64, json, os, pathlib, re, subprocess, sys, time, urllib.parse, urllib.request

OLLAMA = os.environ.get("OLLAMA_URL", "http://localhost:11434")
BRAIN = os.environ.get("OLLAMA_MODEL", "qwen3:14b")
VISION = os.environ.get("VISION_MODEL", "")
MOD_DIR = pathlib.Path(os.environ.get("MOD_DIR", ".")).resolve()
GAME_DIR = os.environ.get("GAME_DIR", "")
ROOT = pathlib.Path(__file__).resolve().parents[2]
EVID = ROOT / "docs" / "evidence"
STATE = ROOT / "docs" / "state" / "STATE.md"
RUN = ROOT / "docs" / "state" / "run.json"
LOG = ROOT / "docs" / "audit" / "director-log.md"
MAX_ROUNDS = int(os.environ.get("MAX_ROUNDS", "6"))
MAX_RESEARCH = int(os.environ.get("MAX_RESEARCH", "12"))
session = os.environ.get("CLAUDE_SESSION", "")
ALLOWED = [p for p in (MOD_DIR, ROOT, pathlib.Path(GAME_DIR).resolve() if GAME_DIR else None) if p]

# ---------------------------------------------------------------- Ollama
def ollama(model, messages, tools=None, as_json=False):
    body = {"model": model, "stream": False, "messages": messages}
    if tools: body["tools"] = tools
    if as_json: body["format"] = "json"
    req = urllib.request.Request(OLLAMA + "/api/chat", json.dumps(body).encode(),
                                 {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=3600) as r:
        return json.load(r)["message"]

def chat(model, system, user, images=None, as_json=False):
    msg = {"role": "user", "content": user}
    if images:
        msg["images"] = [base64.b64encode(p.read_bytes()).decode() for p in images]
    return ollama(model, [{"role": "system", "content": system}, msg], as_json=as_json)["content"]

# ---------------------------------------------------------------- outils de recherche du directeur
def _safe(path):
    p = pathlib.Path(path)
    p = (MOD_DIR / p) if not p.is_absolute() else p
    p = p.resolve()
    if not any(p == a or a in p.parents for a in ALLOWED):
        raise ValueError(f"chemin hors zone autorisée: {p}")
    return p

def t_list_dir(path="."):
    p = _safe(path)
    return "\n".join(sorted(f"{'[D] ' if x.is_dir() else '    '}{x.name}" for x in p.iterdir()))[:6000]

def t_read_file(path, start=1, lines=200):
    p = _safe(path)
    L = p.read_text(errors="replace").splitlines()
    return "\n".join(f"{i+start}: {l}" for i, l in enumerate(L[start-1:start-1+lines]))[:8000]

def t_grep(pattern, path="."):
    p, rx, out = _safe(path), re.compile(pattern, re.I), []
    for f in ([p] if p.is_file() else p.rglob("*")):
        if f.is_file() and f.suffix.lower() in (".lua", ".xml", ".py", ".md", ".txt", ".json", ".tbl", ".cfg", ".ini"):
            try:
                for i, l in enumerate(f.read_text(errors="replace").splitlines(), 1):
                    if rx.search(l): out.append(f"{f}:{i}: {l.strip()[:200]}")
            except OSError: pass
            if len(out) > 80: break
    return "\n".join(out[:80]) or "(aucun résultat)"

def t_web_search(query):
    url = "https://html.duckduckgo.com/html/?q=" + urllib.parse.quote(query)
    html = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=30).read().decode("utf-8", "replace")
    res = re.findall(r'class="result__a" href="([^"]+)">(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>', html, re.S)
    clean = lambda s: re.sub(r"<[^>]+>", "", s).strip()
    return "\n".join(f"- {clean(t)}\n  {u}\n  {clean(s)}" for u, t, s in res[:8]) or "(aucun résultat)"

def t_web_fetch(url):
    html = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=30).read().decode("utf-8", "replace")
    html = re.sub(r"(?s)<(script|style).*?</\1>", "", html)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))[:8000]

TOOLS = {"list_dir": t_list_dir, "read_file": t_read_file, "grep": t_grep, "web_search": t_web_search, "web_fetch": t_web_fetch}
def _spec(name, desc, props, req):
    return {"type": "function", "function": {"name": name, "description": desc,
            "parameters": {"type": "object", "properties": props, "required": req}}}
S = {"type": "string"}
TOOL_SPECS = [
    _spec("list_dir", "Liste un dossier (mod, jeu ou dépôt).", {"path": S}, ["path"]),
    _spec("read_file", "Lit un fichier texte (numéroté).", {"path": S, "start": {"type": "integer"}, "lines": {"type": "integer"}}, ["path"]),
    _spec("grep", "Cherche une regex dans un fichier/dossier.", {"pattern": S, "path": S}, ["pattern"]),
    _spec("web_search", "Recherche web (docs de modding KCD2, forums, wiki).", {"query": S}, ["query"]),
    _spec("web_fetch", "Récupère le texte d'une page web.", {"url": S}, ["url"]),
]

def research(topic):
    """Boucle de recherche autonome du directeur. Retourne des notes sourcées."""
    msgs = [{"role": "system", "content": SYS_RESEARCH},
            {"role": "user", "content": f"Sujet à investiguer:\n{topic}\n\nZones: mod={MOD_DIR} jeu={GAME_DIR or '(inconnu)'}\n\nÉTAT ACTUEL DU MOD:\n{state_text()}"}]
    for _ in range(MAX_RESEARCH):
        m = ollama(BRAIN, msgs, tools=TOOL_SPECS)
        msgs.append(m)
        calls = m.get("tool_calls") or []
        if not calls:
            return m.get("content", "")
        for c in calls:
            fn = c["function"]; name, args = fn["name"], fn.get("arguments", {})
            try:
                res = TOOLS[name](**args)
            except Exception as e:
                res = f"ERREUR: {e}"
            log(f"RECHERCHE {name}", f"{json.dumps(args, ensure_ascii=False)}\n\n{str(res)[:1500]}")
            msgs.append({"role": "tool", "tool_name": name, "content": str(res)})
    msgs.append({"role": "user", "content": "Stop. Donne maintenant tes notes finales sourcées."})
    return ollama(BRAIN, msgs).get("content", "")

# ---------------------------------------------------------------- Claude
def ask_claude(prompt):
    global session
    cmd = ["claude", "-p", prompt, "--output-format", "json", "--permission-mode", "acceptEdits", "--add-dir", str(ROOT)]
    if GAME_DIR: cmd += ["--add-dir", GAME_DIR]
    if session: cmd += ["--resume", session]
    out = subprocess.run(cmd, cwd=MOD_DIR, capture_output=True, text=True)
    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError:
        return f"[ERREUR Claude] {out.stderr or out.stdout}"
    session = data.get("session_id", session)
    return data.get("result", "")

# ---------------------------------------------------------------- utilitaires
def log(title, text):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(f"\n## {time.strftime('%F %T')} {title}\n\n{text}\n")

def state_text():
    return STATE.read_text(encoding="utf-8") if STATE.exists() else "(aucun état: lance 'adopt')"

def save_run(**kw):
    RUN.parent.mkdir(parents=True, exist_ok=True)
    RUN.write_text(json.dumps(kw, ensure_ascii=False, indent=2), encoding="utf-8")

def images_since(t0):
    EVID.mkdir(parents=True, exist_ok=True)
    return sorted(p for p in EVID.iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg") and p.stat().st_mtime >= t0)

def describe(imgs, intent):
    if not imgs: return "(aucune image fournie)"
    if not VISION: return "(images reçues, pas de VISION_MODEL: " + ", ".join(p.name for p in imgs) + ")"
    return chat(VISION, "Décris précisément ce que montrent ces images, sans interpréter.", "But recherché:\n" + intent, images=imgs)

# ---------------------------------------------------------------- prompts
RULES = """Règles absolues:
- Tu es le DIRECTEUR, extérieur à Claude. Tu ne codes pas: tu comprends, tu cherches, tu ordonnes, tu contrôles.
- Le mod est Scriptorium (Kingdom Come: Deliverance 2). Il doit être NATIF au jeu et fonctionnel.
- N'invente jamais un format, un chemin, un ID ou un nom de balise: cherche (fichiers du jeu, du mod, web) et cite la source. Marque [VÉRIFIÉ source] ou [HYPOTHÈSE].
- Réutilise d'abord les briques natives du jeu (modèles, animations, sons, effets, accroches, déclencheurs), puis dérive, puis crée.
- Respecte les règles de Yann (voir état du mod): pas de nouveau dossier qui tire les PNJ de son côté, la nouveauté reste dans le dossier de son métier et réutilise le mécanisme existant. Une seule source de vérité par donnée, pas de doublons."""
SYS_RESEARCH = "Tu es le DIRECTEUR en phase de RECHERCHE. Utilise tes outils (list_dir, read_file, grep, web_search, web_fetch) pour établir les faits nécessaires: comment le jeu fait déjà cela, comment le mod est organisé, ce que dit la documentation. Termine par des notes concises, sourcées (fichier:ligne ou URL).\n" + RULES
SYS_BRIEF = """Tu es le DIRECTEUR. Tu comprends ce que Yann veut vraiment, au fond, à partir de sa demande, des recherches et de l'état du mod.
Réponds en JSON: {"intent": "ce que Yann veut, en profondeur", "success_criteria": ["critères vérifiables"], "must_not": ["interdits"],
"native_requirement": "comment ce doit être natif, avec preuves", "order": "ordre précis et complet pour Claude: quoi faire, où, comment, avec quelles briques natives (chemins/IDs trouvés), dans quel ordre, et les preuves à fournir"}.
Preuves exigées de Claude: captures dans docs/evidence/, extraits de log, fichiers modifiés, chaque choix justifié par un équivalent natif.
""" + RULES
SYS_JUDGE = """Tu es le DIRECTEUR. Tu juges le travail de Claude contre l'intention de Yann et ses critères. Tu juges seulement sur preuves.
Sois exigeant: rejette si une preuve manque, si ce n'est pas natif, si c'est illogique, si une règle de Yann est enfreinte, ou si ça ne correspond pas à l'intention.
Réponds en JSON: {"verdict": "ok" | "redo", "feedback": "ce qui ne va pas, précisément", "order": "si redo: ordre corrigé pour Claude, qui dit clairement 'non, ce n'est pas ce que Yann veut, il veut: ...'", "learned": "préférence de Yann à retenir, ou vide"}
""" + RULES

# ---------------------------------------------------------------- flux
def adopt():
    r = ask_claude("MODE: ADOPTION. Reprends ce mod là où il en est, sans rien modifier. Inventorie: arborescence, git log et notes, fichiers/IDs, "
        "fait / partiel / scellé / manquant, bugs connus, conventions et règles de Yann, dernière action en cours, prochaines étapes. "
        "Écris le tout dans " + str(STATE) + " (crée le dossier). Marque les doutes [À VÉRIFIER]. Réponds par un résumé court.")
    log("ADOPTION", r); print(r); print("État écrit dans", STATE)

def handle(request, resume=None):
    start = 1
    if resume:
        intent, order, start = resume["intent"], resume["order"], resume["round"]
    else:
        print("[recherche]"); notes = research(request); log("NOTES DE RECHERCHE", notes)
        brief = json.loads(chat(BRAIN, SYS_BRIEF, f"Demande de Yann: {request}\n\nNOTES DE RECHERCHE:\n{notes}\n\nÉTAT DU MOD:\n{state_text()}", as_json=True))
        log("BRIEF", json.dumps(brief, ensure_ascii=False, indent=2))
        order = brief["order"]
        intent = json.dumps({k: brief.get(k) for k in ("intent", "success_criteria", "must_not", "native_requirement")}, ensure_ascii=False)
    for rnd in range(start, MAX_ROUNDS + 1):
        save_run(request=request, intent=intent, order=order, round=rnd, session=session, done=False)
        t0 = time.time(); print(f"[tour {rnd}] ordre -> Claude")
        result = ask_claude(order + "\n\nIntention de Yann:\n" + intent + "\n\nFournis tes preuves (captures dans " + str(EVID) + ", logs, fichiers modifiés).")
        log(f"TOUR {rnd} — Claude", result)
        view = describe(images_since(t0), intent)
        v = json.loads(chat(BRAIN, SYS_JUDGE, f"Intention:\n{intent}\n\nOrdre donné:\n{order}\n\nRéponse de Claude:\n{result}\n\nImages:\n{view}", as_json=True))
        log(f"TOUR {rnd} — verdict", json.dumps(v, ensure_ascii=False, indent=2))
        print(f"[tour {rnd}] verdict: {v['verdict']} — {v.get('feedback','')[:200]}")
        if v["verdict"] == "ok":
            ask_claude("MODE: MISE À JOUR D'ÉTAT. Mets à jour " + str(STATE) + " avec ce qui vient d'être fait pour: " + request)
            save_run(request=request, intent=intent, order=order, round=rnd, session=session, done=True)
            print("Terminé. Journal:", LOG); return
        order = v.get("order") or v.get("feedback", "")
    print(f"Arrêt après {MAX_ROUNDS} tours sans validation. Voir", LOG)

def main():
    global session
    a = sys.argv[1:]
    if a == ["adopt"]: return adopt()
    if a: return handle(" ".join(a))
    if RUN.exists():
        run = json.loads(RUN.read_text(encoding="utf-8"))
        if not run.get("done"):
            session = run.get("session") or session
            print(f"Reprise: {run['request']} (tour {run['round']})"); return handle(run["request"], resume=run)
    while True:
        try: req = input("\nYann > ").strip()
        except (EOFError, KeyboardInterrupt): return
        if req in ("", "quit", "exit"): return
        handle(req)

if __name__ == "__main__":
    main()

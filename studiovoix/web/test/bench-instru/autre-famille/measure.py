# Mesures du banc (lib.py, copie conforme de B/bench/lib.py) pour la ligne de base et les candidats d'autres architectures.
#   python -I measure.py <items> <B/out> <B2/out> <B2/results> [extrait …]      (ONLY=cand1,cand2 ; FORCE=1)
# Variantes par candidat : <cand>_sub = chanson − voix du modèle ; <cand>_inst = sortie instrumentale du modèle (si elle existe) ;
# la voix mesurée est toujours la voix du modèle (ou chanson − instru si le modèle ne sort pas de voix).
import sys, os, json, time
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

setup_log()
ITEMS, BOUT, OUT, RES = sys.argv[1:5]
ids = sys.argv[5:] or sorted(d for d in os.listdir(ITEMS) if os.path.isdir(os.path.join(ITEMS, d)))
os.makedirs(RES, exist_ok=True)
C_VOC = 1.021
ONLY = set(filter(None, os.environ.get('ONLY', '').split(',')))
CANDS = [c for c in os.environ.get('CANDS', 'htdemucs,bsrof,mdx23c,melinst,scnet').split(',') if c]


def rd(p, n):
    if not os.path.exists(p): return None
    x = read_f32(p)
    if len(x) < n: raise ValueError(f'{p} : {len(x)} < {n}')
    return x[:n]


for iid in ids:
    it = Item(os.path.join(ITEMS, iid))
    n, song = it.n, it.song
    rp = os.path.join(RES, f'{iid}.json')
    res = json.load(open(rp)) if os.path.exists(rp) and not os.environ.get('FORCE') else {}
    todo = {}
    b = rd(os.path.join(BOUT, f'{iid}.voc.f32'), n)
    if b is not None: todo['base'] = (song - C_VOC * b, C_VOC * b)                       # sorties de la 1re campagne
    b2 = rd(os.path.join(OUT, f'{iid}.voc.f32'), n)
    if b2 is not None: todo['base_rejoue'] = (song - C_VOC * b2, C_VOC * b2)              # ligne de base rejouée ici
    for c in CANDS:
        if not os.path.exists(os.path.join(OUT, f'{iid}.{c}.json')): continue
        v = rd(os.path.join(OUT, f'{iid}.{c}.voc.f32'), n); i = rd(os.path.join(OUT, f'{iid}.{c}.inst.f32'), n)
        if v is not None: todo[f'{c}_sub'] = (song - v, v)
        if i is not None: todo[f'{c}_inst'] = (i, v if v is not None else song - i)
    for k, (est, voc) in todo.items():
        if k in res or (ONLY and k not in ONLY): continue
        t0 = time.perf_counter()
        m = metrics(it, est, voc_est=voc)
        m['resid_db'] = float(db(((song - est - voc) ** 2).sum() / (song ** 2).sum()))     # instru + voix = chanson ? (−300 = oui)
        res[k] = m
        log.info(f"{iid} / {k} : SDR {m['sdr']:.2f} D1 {m['d1_voc_left']:.1f} SAR chanté {m.get('d2_sar_sung', float('nan')):.1f} σ6-12k {m.get('d3_std_sung_6-12k', float('nan')):.2f} >6k {m.get('d4_hf_level_sung', float('nan')):.2f} hors chant {m.get('sdr_unsung', float('nan')):.1f} voix {m['voc_sdr']:.2f} ({time.perf_counter() - t0:.1f} s)")
        json.dump(res, open(rp, 'w'))
log.info('fini')

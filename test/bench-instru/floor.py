# Plancher de la mesure « restes de voix » : même projection de l'erreur de la ligne de base, mais sur une FAUSSE voix
# (la voix vraie retournée dans le temps : même spectre, aucun lien avec l'erreur). Ce qui « s'explique » par cette
# fausse voix est le niveau en dessous duquel la mesure ne distingue plus un reste de voix du hasard.
#   python -I floor.py <items> <out> <results>
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
setup_log()
ITEMS, OUT, RES = sys.argv[1:4]
res = {}
for iid in sorted(d for d in os.listdir(ITEMS) if os.path.isdir(os.path.join(ITEMS, d))):
    it = Item(os.path.join(ITEMS, iid))
    voc = read_f32(os.path.join(OUT, f'{iid}.voc.f32'))[:it.n]
    e = it.song - 1.021 * voc - it.I
    ev, ei, ea = it.decompose(e)
    true_left = db((ev ** 2).sum() / (it.V ** 2).sum())
    it2 = Item(os.path.join(ITEMS, iid)); j = it2.junction or it2.n; it2.Vp = np.concatenate([it2.V[:j][::-1], it2.V[j:]])   # retournée dans la partie chantée
    ev2, _, _ = it2.decompose(e)
    floor = db((ev2 ** 2).sum() / (it.V ** 2).sum())
    res[iid] = dict(d1_voc_left=float(true_left), d1_floor=float(floor))
    log.info(f'{iid} : restes de voix {true_left:.1f} dB ; plancher (fausse voix) {floor:.1f} dB ; marge {true_left - floor:.1f} dB')
json.dump(res, open(os.path.join(RES, '_floor.json'), 'w'), indent=1)

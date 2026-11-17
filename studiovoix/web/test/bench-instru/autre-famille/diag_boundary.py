# Où se trouve l'erreur de l'instru (chanson − voix du modèle) dans les trames non chantées ? Part de l'énergie d'erreur
# dans ±0,1 s autour de la limite de morceau (8,0 s pour bsrof sans recouvrement) contre le reste.
import sys, os, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
ITEMS, OUT, tag, bound = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
for iid in sys.argv[5:]:
    it = Item(os.path.join(ITEMS, iid))
    v = read_f32(os.path.join(OUT, f'{iid}.{tag}.voc.f32'))[:it.n]
    e = (it.song - v) - it.I
    fe = frame_energy(e); t = (np.arange(len(fe)) + 0.5) * FR
    near = np.abs(t - bound) <= 0.1 * SR
    u = it.unsung[:len(fe)]
    Eu = sel_energy(it.I, it.unsung)
    tot = fe[u].sum(); nb = fe[u & near].sum()
    worst = np.argsort(fe * u)[-3:][::-1]
    print(f"{iid} {tag} : trames non chantées {int(u.sum())} ; SDR hors chant {db(Eu / tot):.1f} dB ; part de l'erreur à ±0,1 s de la limite ({bound / SR:.2f} s) : {100 * nb / tot:.1f} % ; SDR hors chant sans ces trames : {db(sel_energy(it.I, it.unsung & ~np.pad(near, (0, it.k - len(near)))) / max(tot - nb, 1e-30)):.1f} dB ; 3 pires trames à {[round(float(t[i] / SR), 2) for i in worst]} s ; jonction {it.junction / SR:.2f} s")

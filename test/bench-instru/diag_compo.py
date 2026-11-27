# De quoi est faite l'erreur de la ligne de base, par bande, là où la voix chante : restes de voix / instru retirée ou
# déformée / artefacts (ni l'un ni l'autre), en dB par rapport à l'instru vraie de la bande (trames chantées).
#   python -I diag_compo.py <items> <out>
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
setup_log()
ITEMS, OUT = sys.argv[1:3]
rows = {}
for iid in sorted(d for d in os.listdir(ITEMS) if os.path.isdir(os.path.join(ITEMS, d))):
    it = Item(os.path.join(ITEMS, iid))
    e = it.song - 1.021 * read_f32(os.path.join(OUT, f'{iid}.voc.f32'))[:it.n] - it.I
    parts = [band_split(x) for x in it.decompose(e)]
    Vb = band_split(it.V)
    r = {}
    for bi, (name, _, _) in enumerate(BANDS):
        den = sel_energy(it.Ib[bi], it.sung)
        r[name] = dict(voc=db(sel_energy(parts[0][bi], it.sung) / den), ins=db(sel_energy(parts[1][bi], it.sung) / den), art=db(sel_energy(parts[2][bi], it.sung) / den),
                       voix_vraie=db(sel_energy(Vb[bi], it.sung) / den), restes_sur_voix=db(sel_energy(parts[0][bi], it.sung) / max(sel_energy(Vb[bi], it.sung), 1e-30)))
    rows[iid] = r
    log.info(iid + ' : ' + ' ; '.join(f"{b} voix {v['voc']:.1f} instru {v['ins']:.1f} artefacts {v['art']:.1f} (voix vraie {v['voix_vraie']:+.1f}, restes/voix {v['restes_sur_voix']:.1f})" for b, v in r.items()))
sung = [i for i in rows if i != 'p_parle']
for b, _, _ in BANDS:
    log.info(f"MOYENNE 12 extraits chantés, {b} : restes de voix {np.mean([rows[i][b]['voc'] for i in sung]):.1f} dB ; instru retirée/déformée {np.mean([rows[i][b]['ins'] for i in sung]):.1f} dB ; "
             f"artefacts {np.mean([rows[i][b]['art'] for i in sung]):.1f} dB (par rapport à l'instru vraie de la bande) ; voix vraie {np.mean([rows[i][b]['voix_vraie'] for i in sung]):+.1f} dB ; restes / voix vraie {np.mean([rows[i][b]['restes_sur_voix'] for i in sung]):.1f} dB")
json.dump(rows, open(os.path.join(os.path.dirname(OUT.rstrip('/')), 'results', '_compo.json'), 'w'), indent=1)

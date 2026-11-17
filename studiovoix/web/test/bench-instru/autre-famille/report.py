# Tableau : ligne de base + candidats, moyenne des 12 extraits chantés [pire], écarts, découpe test / MedleyDB, chanson d'essai.
#   python -I report.py <B2/results> [B/results]
import sys, os, json
import numpy as np
RES = sys.argv[1]
res = {f[:-5]: json.load(open(os.path.join(RES, f))) for f in sorted(os.listdir(RES)) if f.endswith('.json') and not f.startswith('_')}
ref = {}
if len(sys.argv) > 2:
    ref = {f[:-5]: json.load(open(os.path.join(sys.argv[2], f))).get('base') for f in sorted(os.listdir(sys.argv[2])) if f.endswith('.json') and not f.startswith('_')}
sung = [i for i in res if i != 'p_parle']
KEYS = [('sdr', 'SDR instru', 1), ('d1_voc_left', 'D1 restes voix', -1), ('d2_sar_sung', 'SAR chanté', 1), ('d3_std_sung_6-12k', 'σ gain 6-12k chanté', -1),
        ('d4_hf_level_sung', '>6k sous la voix', 0), ('sdr_unsung', 'SDR hors chant', 1), ('voc_sdr', 'SDR voix', 1), ('sdr_hf2', 'aigus2', 1), ('d2_sar', 'SAR', 1), ('d3_std_sung', 'σ gain pleine bande', -1), ('d4_hf_coh_sung', '>6k cohérent', 0)]
cands = []
for i in res:
    for c in res[i]:
        if c not in cands: cands.append(c)
if ref:
    print('=== Contrôle : ligne de base recalculée ici (sorties de la 1re campagne) contre results de la 1re campagne — écart maximal par mesure')
    for k, n, _ in KEYS:
        d = [abs(res[i]['base'][k] - ref[i][k]) for i in res if 'base' in res[i] and ref.get(i) and k in res[i]['base'] and k in ref[i]]
        print(f'  {n} : {max(d):.4f} dB sur {len(d)} extraits' if d else f'  {n} : n/a')
    if any('base_rejoue' in res[i] for i in res):
        print('=== Contrôle : ligne de base REJOUÉE (modèle relancé ici) contre 1re campagne')
        for i in res:
            if 'base_rejoue' in res[i] and ref.get(i):
                print('  ' + i + ' : ' + ' ; '.join(f"{n} {res[i]['base_rejoue'][k]:.2f} / {ref[i][k]:.2f}" for k, n, _ in KEYS[:7] if k in ref[i]))


def table(label, grp):
    print(f'\n=== {label} (n={len(grp)}) : moyenne (écart à la ligne de base) [pire extrait]')
    print('candidat\t' + '\t'.join(n for _, n, _ in KEYS) + '\tn')
    for c in cands:
        have = [i for i in grp if c in res[i] and 'base' in res[i]]
        if not have: continue
        row = [c]
        for k, _, sense in KEYS:
            v = np.array([res[i][c].get(k, np.nan) for i in have], float); b = np.array([res[i]['base'].get(k, np.nan) for i in have], float)
            if np.all(np.isnan(v)): row.append('n/a'); continue
            mean = np.nanmean(v); dm = mean - np.nanmean(b)
            j = np.nanargmin(v) if sense == 1 else (np.nanargmax(v) if sense == -1 else np.nanargmax(np.abs(v)))
            row.append(f'{mean:.2f} ({dm:+.2f}) [{v[j]:.1f} {have[j]}]')
        row.append(str(len(have)))
        print('\t'.join(row))


table('12 extraits chantés', sung)
table('6 extraits MUSDB test (t_*)', [i for i in sung if i.startswith('t_')])
table('6 extraits MedleyDB / MUSDB train (m_*)', [i for i in sung if i.startswith('m_')])
if 'p_parle' in res:
    print('\n=== chanson d\'essai du produit (p_parle, voix parlées)')
    print('candidat\t' + '\t'.join(n for _, n, _ in KEYS))
    for c in cands:
        if c in res['p_parle']:
            print(c + '\t' + '\t'.join(('n/a' if k not in res['p_parle'][c] else f"{res['p_parle'][c][k]:.2f}" + (f" ({res['p_parle'][c][k] - res['p_parle']['base'][k]:+.2f})" if 'base' in res['p_parle'] and k in res['p_parle']['base'] else '')) for k, _, _ in KEYS))
print('\n=== par extrait : SDR instru / D1 / SAR chanté / SDR voix')
for i in res:
    print(i + '\t' + '\t'.join(f"{c}: {res[i][c]['sdr']:.1f}/{res[i][c]['d1_voc_left']:.1f}/{res[i][c].get('d2_sar_sung', float('nan')):.1f}/{res[i][c]['voc_sdr']:.1f}" for c in cands if c in res[i]))

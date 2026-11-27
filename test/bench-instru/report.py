# Tableaux à partir de results/*.json.   python -I report.py <results> [items.json]
import sys, os, json
import numpy as np

RES = sys.argv[1]
res = {f[:-5]: json.load(open(os.path.join(RES, f))) for f in sorted(os.listdir(RES)) if f.endswith('.json') and not f.startswith('_')}
floor = json.load(open(os.path.join(RES, '_floor.json'))) if os.path.exists(os.path.join(RES, '_floor.json')) else {}
sung = [i for i in res if i != 'p_parle']
test = [i for i in sung if i.startswith('t_')]; med = [i for i in sung if i.startswith('m_')]
BN = ['<250', '250-2k', '2-6k', '6-12k', '>12k']
f1 = lambda v: 'n/a' if v is None or not np.isfinite(v) else f'{v:.1f}'


def g(i, c, k):
    return res[i].get(c, {}).get(k)


def derived(m):
    d = dict(m)
    if 'd3_gain_sung' in m and 'd3_gain_unsung' in m: d['d3_offset'] = m['d3_gain_sung'] - m['d3_gain_unsung']
    if 'd4_hf_level_sung' in m and 'd4_hf_level_unsung' in m: d['d4_offset'] = m['d4_hf_level_sung'] - m['d4_hf_level_unsung']
    return d


for i in res:
    for c in res[i]: res[i][c] = derived(res[i][c])

print('=== T1 ligne de base, par extrait (dB)')
cols = [('sdr_song', 'brut'), ('sdr', 'SDR'), ('sdr_hf2', 'aigus2'), *[(f'sdr_{b}', b) for b in BN], ('d1_voc_left', 'D1 voix/voix'), ('d1_sir', 'D1 SIR'),
        ('d2_sar', 'D2 SAR'), ('d2_sar_sung', 'SAR chanté'), ('d2_sar_unsung', 'SAR non ch.'), ('d_ins_loss', 'perte instru'),
        ('d3_gain_sung', 'D3 gain ch.'), ('d3_gain_unsung', 'gain non ch.'), ('d3_std_sung', 'σ ch.'), ('d3_std_unsung', 'σ non ch.'),
        ('d4_hf_level_sung', 'D4 >6k ch.'), ('d4_hf_level_unsung', '>6k non ch.'), ('d4_hf_coh_sung', '>6k cohérent ch.'), ('d4_hf_sdr_sung', 'SDR>6k ch.'), ('d4_hf_sdr_unsung', 'SDR>6k non ch.'), ('voc_sdr', 'voix SDR')]
print('extrait\t' + '\t'.join(n for _, n in cols) + '\tplancher D1')
for i in list(res):
    print(i + '\t' + '\t'.join(f1(g(i, 'base', k)) for k, _ in cols) + '\t' + f1(floor.get(i, {}).get('d1_floor')))
for label, grp in (('moyenne chant (12)', sung), ('moyenne test (6)', test), ('moyenne MedleyDB (6)', med)):
    print(label + '\t' + '\t'.join(f1(np.mean([g(i, 'base', k) for i in grp if g(i, 'base', k) is not None])) for k, _ in cols))

print('\n=== T1b ligne de base, défaut 3 par bande : gain moyen (σ d\'une trame à l\'autre), moyenne des 12 extraits chantés ; puis gain cohérent')
print('bande\tgain chanté (σ)\tgain non chanté (σ)\tcohérent chanté (σ)\tcohérent non chanté (σ)\tpire σ chanté')
for b in BN:
    def mm(k):
        v = [g(i, 'base', k.format(b=b)) for i in sung]; v = [x for x in v if x is not None]
        return np.mean(v) if v else float('nan')
    worst = max((g(i, 'base', f'd3_std_sung_{b}') or 0, i) for i in sung)
    print(f"{b}\t{mm('d3_gain_sung_{b}'):.2f} ({mm('d3_std_sung_{b}'):.2f})\t{mm('d3_gain_unsung_{b}'):.2f} ({mm('d3_std_unsung_{b}'):.2f})\t{mm('d3_coh_sung_{b}'):.2f} ({mm('d3_cohstd_sung_{b}'):.2f})\t{mm('d3_coh_unsung_{b}'):.2f} ({mm('d3_cohstd_unsung_{b}'):.2f})\t{worst[0]:.2f} {worst[1]}")
if 'p_parle' in res:
    print('p_parle (voix parlées) :')
    for b in BN:
        gg = lambda k: f1(g('p_parle', 'base', k.format(b=b)))
        print(f"{b}\t{gg('d3_gain_sung_{b}')} ({gg('d3_std_sung_{b}')})\t{gg('d3_gain_unsung_{b}')} ({gg('d3_std_unsung_{b}')})\t{gg('d3_coh_sung_{b}')} ({gg('d3_cohstd_sung_{b}')})\t{gg('d3_coh_unsung_{b}')} ({gg('d3_cohstd_unsung_{b}')})")

print('\n=== T2 candidats : moyenne des 12 extraits chantés [pire extrait] ; écart à la ligne de base entre parenthèses ; puis p_parle')
keys = [('sdr', 'SDR', 1), ('sdr_hf2', 'aigus2', 1), ('sdr_2-6k', '2-6k', 1), ('sdr_6-12k', '6-12k', 1), ('sdr_>12k', '>12k', 1), ('d1_voc_left', 'D1 restes voix', -1), ('d2_sar', 'D2 SAR', 1),
        ('d2_sar_sung', 'SAR chanté', 1), ('sdr_unsung', 'SDR non chanté', 1), ('d3_offset', 'D3 écart gain', 0), ('d3_std_sung', 'D3 σ chanté', -1), ('d4_hf_level_sung', 'D4 >6k chanté', 0), ('d4_hf_coh_sung', 'D4 cohérent', 0), ('voc_sdr', 'voix SDR', 1)]
cands = list(res[sung[0]].keys()) if sung else []
for i in res:
    for c in res[i]:
        if c not in cands: cands.append(c)
print('candidat\tfamille\tcoût\t' + '\t'.join(n for _, n, _ in keys) + '\tp_parle SDR\tp_parle aigus2\tp_parle D1\tp_parle SAR\tp_parle voix SDR\tn')
out = {}
for c in cands:
    have = [i for i in sung if c in res[i]]
    if not have: continue
    row = [c, res[have[0]][c]['family'], f"×{res[have[0]][c]['cost']:g}"]
    out[c] = {}
    for k, _, sense in keys:
        v = np.array([res[i][c].get(k, np.nan) for i in have], float); b = np.array([res[i]['base'].get(k, np.nan) for i in have], float)
        mean = np.nanmean(v); dm = mean - np.nanmean(b)
        if sense == 1: w = np.nanmin(v)
        elif sense == -1: w = np.nanmax(v)
        else: w = v[np.nanargmax(np.abs(v))]
        worst_delta = np.nanmin(v - b) if sense == 1 else (np.nanmax(v - b) if sense == -1 else np.nan)
        out[c][k] = dict(mean=float(mean), delta=float(dm), worst=float(w), worst_delta=float(worst_delta))
        row.append(f'{mean:.2f} ({dm:+.2f}) [{w:.1f}]' + (f' {{{worst_delta:+.2f}}}' if sense else ''))
    for k in ('sdr', 'sdr_hf2', 'd1_voc_left', 'd2_sar', 'voc_sdr'):
        v, b = g('p_parle', c, k), g('p_parle', 'base', k)
        row.append('n/a' if v is None else f'{v:.2f} ({v - b:+.2f})')
    row.append(str(len(have)))
    print('\t'.join(row))
json.dump(out, open(os.path.join(RES, '_summary.json'), 'w'), indent=1)
print('\n{…} = pire écart à la ligne de base sur un extrait (sens défavorable).')

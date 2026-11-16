# Fabrique les extraits à vérité connue à partir de MUSDB18-7 (stems AAC 256 kb/s décodés par ffmpeg).
# Par piste : A = 7 s vrais (instru + chant), puis B = LES MÊMES 7 s d'instru SANS la voix. Même contenu instrumental
# avec et sans voix → comparaison appariée « là où la voix chante » / « là où elle ne chante pas ».
# Fondus de 10 ms au début, à la jonction et à la fin. Chanson = instru + voix (somme des stems, pas la piste « mixture »).
import subprocess, sys, os, json, numpy as np, soundfile as sf
root, out = sys.argv[1], sys.argv[2]
SEL = [  # (id, split, fichier, style [croyance : non écouté], origine / licence)
 ('t_rap1',  'test',  'Side Effects Project - Sing With Me', 'rap, voix masculine', 'DSD100 / Mixing Secrets — usage éducatif et recherche uniquement (MUSDB18)'),
 ('t_rap2',  'test',  'Triviul feat. The Fiend - Widow', 'hip-hop, voix masculine', 'DSD100 / Mixing Secrets — usage éducatif et recherche uniquement (MUSDB18)'),
 ('t_fem1',  'test',  'Signe Jakobsen - What Have You Done To Me', 'pop-rock, voix féminine', 'DSD100 / Mixing Secrets — usage éducatif et recherche uniquement (MUSDB18)'),
 ('t_fem2',  'test',  'Georgia Wonder - Siren', 'pop, voix féminine', 'DSD100 / Mixing Secrets — usage éducatif et recherche uniquement (MUSDB18)'),
 ('t_pop1',  'test',  'Zeno - Signs', 'pop-rock, voix masculine', 'DSD100 / Mixing Secrets — usage éducatif et recherche uniquement (MUSDB18)'),
 ('t_rock1', 'test',  'The Easton Ellises - Falcon 69', 'électro-rock, voix masculine', 'The Easton Ellises — CC BY-NC-SA 3.0 (MUSDB18)'),
 ('m_fem1',  'train', 'Clara Berry And Wooldog - Stella', 'folk-pop, voix féminine', 'MedleyDB — CC BY-NC-SA 4.0'),
 ('m_fem2',  'train', 'Hop Along - Sister Cities', 'rock indé, voix féminine', 'MedleyDB — CC BY-NC-SA 4.0'),
 ('m_pop1',  'train', 'Night Panther - Fire', 'synth-pop, voix masculine aiguë', 'MedleyDB — CC BY-NC-SA 4.0'),
 ('m_pop2',  'train', 'Helado Negro - Mitad Del Mundo', 'électro latine, voix masculine', 'MedleyDB — CC BY-NC-SA 4.0'),
 ('m_disco', 'train', 'Music Delta - Disco', 'disco', 'MedleyDB — CC BY-NC-SA 4.0'),
 ('m_rock1', 'train', 'Dreamers Of The Ghetto - Heavy Love', 'rock indé, voix masculine', 'MedleyDB — CC BY-NC-SA 4.0'),
]
def dec(path, stream):
    p = subprocess.run(['ffmpeg', '-v', 'error', '-threads', '1', '-i', path, '-map', f'0:{stream}', '-f', 'f32le', '-ac', '2', '-ar', '44100', '-'], capture_output=True, check=True)
    return np.frombuffer(p.stdout, dtype=np.float32).reshape(-1, 2).astype(np.float64)
meta = []
for iid, split, name, style, lic in SEL:
    path = os.path.join(root, split, name + '.stem.mp4')
    st = [dec(path, s) for s in (1, 2, 3, 4)]
    n = min(len(x) for x in st)
    ins = st[0][:n] + st[1][:n] + st[2][:n]; voc = st[3][:n].copy()
    f = 441; ramp = np.linspace(0, 1, f)[:, None]
    for x in (ins, voc): x[:f] *= ramp; x[-f:] *= ramp[::-1]
    I = np.concatenate([ins, ins]); V = np.concatenate([voc, np.zeros_like(voc)])
    song = I + V
    pk = np.abs(song).max(); g = 0.98 / pk if pk > 0.98 else 1.0
    d = os.path.join(out, iid); os.makedirs(d, exist_ok=True)
    for fn, x in (('song.wav', song), ('truth_instru.wav', I), ('truth_voc.wav', V)):
        sf.write(os.path.join(d, fn), (x * g).astype(np.float32), 44100, subtype='FLOAT')
    m = dict(id=iid, split=split, name=name, style=style, licence=lic, n=2 * n, junction=n, gain=g,
             voc_db=float(10 * np.log10((voc ** 2).mean() + 1e-12)), ins_db=float(10 * np.log10((ins ** 2).mean() + 1e-12)))
    json.dump(m, open(os.path.join(d, 'meta.json'), 'w'), ensure_ascii=False)
    meta.append(m); print(iid, name, 2 * n / 44100, 's gain', round(g, 3), flush=True)
json.dump(meta, open(os.path.join(out, 'items.json'), 'w'), ensure_ascii=False, indent=1)

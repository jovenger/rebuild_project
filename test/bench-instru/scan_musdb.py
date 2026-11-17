# Parcourt MUSDB18-7 (stems AAC) : par piste, niveau de la voix, part de trames de 50 ms où la voix chante, largeur de bande.
import subprocess, sys, os, json, numpy as np
root = sys.argv[1]; out = sys.argv[2]
def dec(path, stream):
    p = subprocess.run(['ffmpeg', '-v', 'error', '-threads', '1', '-i', path, '-map', f'0:{stream}', '-f', 'f32le', '-ac', '2', '-ar', '44100', '-'], capture_output=True, check=True)
    return np.frombuffer(p.stdout, dtype=np.float32).reshape(-1, 2)
rows = []
for split in ('test', 'train'):
    for f in sorted(os.listdir(os.path.join(root, split))):
        if not f.endswith('.stem.mp4'): continue
        path = os.path.join(root, split, f)
        try:
            st = [dec(path, s) for s in (1, 2, 3, 4)]   # drums, bass, other, vocals
        except Exception as e:
            print('ERR', f, e); continue
        n = min(len(x) for x in st)
        ins = st[0][:n] + st[1][:n] + st[2][:n]; voc = st[3][:n]
        fr = 2205; k = n // fr
        ve = (voc[:k*fr].reshape(k, fr, 2) ** 2).mean(axis=(1, 2)); ie = (ins[:k*fr].reshape(k, fr, 2) ** 2).mean(axis=(1, 2))
        active = float((ve > 1e-5).mean())
        rows.append(dict(split=split, name=f[:-9], n=n, voc_db=float(10*np.log10(ve.mean()+1e-12)), ins_db=float(10*np.log10(ie.mean()+1e-12)), active=active))
        print(f"{split:5s} {f[:-9][:52]:52s} voc {rows[-1]['voc_db']:6.1f} dB  ins {rows[-1]['ins_db']:6.1f} dB  actif {active:4.2f}", flush=True)
json.dump(rows, open(out, 'w'))

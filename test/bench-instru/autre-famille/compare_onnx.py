# Écart entre la sortie ONNX (onnxruntime-node) et la sortie PyTorch du même cœur, sur le même morceau : en dB sur la sortie
# brute du cœur, puis sur l'audio reconstruit (masque × spectre → iSTFT).   python -I compare_onnx.py <cand> <dossier> [ort_out.bin]
import sys, os, json
import numpy as np, torch
cand, d = sys.argv[1:3]
ob = sys.argv[3] if len(sys.argv) > 3 else os.path.join(d, f'{cand}.ort_out.bin')
meta = json.load(open(os.path.join(d, f'{cand}.export.json')))
ref = torch.load(os.path.join(d, f'{cand}.ref.pt'), weights_only=True)
inp, out = ref['inp'], ref['out']
o = torch.tensor(np.fromfile(ob, dtype=np.float32).reshape(out.shape))
snr = lambda a, b: float(10 * torch.log10((a ** 2).sum() / ((a - b) ** 2).sum().clamp_min(1e-30)))
r = dict(core_db=snr(out, o), max_abs_err=float((out - o).abs().max()))
if cand in ('bsrof', 'melinst'):
    win = torch.hann_window(2048)

    def audio(mask):
        z = torch.view_as_complex(inp.contiguous())[:, None] * torch.view_as_complex(mask.contiguous())
        z = z.reshape(1, mask.shape[1], -1, 2, z.shape[-1]).permute(0, 1, 3, 2, 4).reshape(-1, z.shape[2] // 2, z.shape[-1])
        return torch.istft(z, n_fft=2048, hop_length=441, win_length=2048, window=win, normalized=False, length=meta['chunk'])
else:
    win = torch.hann_window(8192)

    def audio(x):
        b, c, f, t = x.shape
        x = torch.cat([x, torch.zeros(b, c, 8192 // 2 + 1 - f, t)], -2).reshape(-1, 2, 4097, t).permute(0, 2, 3, 1)
        return torch.istft(torch.complex(x[..., 0], x[..., 1]), n_fft=8192, hop_length=1024, window=win, center=True)
a, b = audio(out), audio(o)
r['audio_db'] = snr(a, b)
print(json.dumps(r))
json.dump(r, open(ob + '.cmp.json', 'w'))

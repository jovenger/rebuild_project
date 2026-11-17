# Export ONNX du « cœur » d'un candidat + entrée / sortie de référence PyTorch sur un vrai morceau.
#   THREADS=3 python -I export_onnx.py <bsrof|mdx23c|melinst> <song.wav> <dossier_sortie> [opset]
import sys, os, json, time, logging
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import infer
from infer import load, log, rss_mb, CANDS
import numpy as np, soundfile as sf, torch
from cores import BSCore, MDX23CCore

cand, wav, outdir = sys.argv[1:4]
opset = int(sys.argv[4]) if len(sys.argv) > 4 else 18
os.makedirs(outdir, exist_ok=True)
model, cfg, info = load(cand)
chunk = info['chunk_size']
song, sr = sf.read(wav, dtype='float32', always_2d=True)
x = torch.tensor(song[44100:44100 + chunk].T)[None]                    # (1, 2, chunk) : 1 s après le début
meta = dict(cand=cand, chunk=chunk, opset=opset, torch=torch.__version__, time_group=int(os.environ.get('TIME_GROUP', 0)))
REF = os.path.join(outdir, f'{cand}.ref.pt')
REUSE = bool(os.environ.get('REUSE_REF')) and os.path.exists(REF)       # reprise : pas de nouvelle passe PyTorch (≈ 85 s pour bsrof)
if REUSE:
    r_ = torch.load(REF, weights_only=True); inp, out = r_['inp'], r_['out']
    core = (BSCore(model, int(os.environ.get('TIME_GROUP', 0))) if cand in ('bsrof', 'melinst') else MDX23CCore(model)).eval()
    old_meta = os.path.join(outdir, f'{cand}.export.json')
    if os.path.exists(old_meta): meta.update({k: v for k, v in json.load(open(old_meta)).items() if k in ('torch_full_s', 'torch_core_s', 'core_vs_full_db')})
    log.info(f'reprise de {REF} : entrée {tuple(inp.shape)} sortie {tuple(out.shape)}')
with torch.no_grad():
    if REUSE: pass
    else:
      t0 = time.perf_counter(); full = model(x); meta['torch_full_s'] = time.perf_counter() - t0
      if cand in ('bsrof', 'melinst'):
          core = BSCore(model, int(os.environ.get('TIME_GROUP', 0))).eval()
          win = model.stft_window_fn(device=x.device)
          st = torch.stft(x[0], **model.stft_kwargs, window=win, return_complex=True)          # (2, f, t)
          inp = torch.view_as_real(st)[None]                                                   # (1, s, f, t, 2)
          inp = inp.permute(0, 2, 1, 3, 4).reshape(1, -1, inp.shape[3], 2).contiguous()        # 'b s f t c -> b (f s) t c'
          t0 = time.perf_counter(); out = core(inp); meta['torch_core_s'] = time.perf_counter() - t0

          def finish(mask):                                                                    # masque → audio (n, s, t)
              z = torch.view_as_complex(inp.contiguous())[:, None] * torch.view_as_complex(mask.contiguous())
              z = z.reshape(1, mask.shape[1], -1, 2, z.shape[-1]).permute(0, 1, 3, 2, 4).reshape(-1, z.shape[2] // 2, z.shape[-1])
              if getattr(model, 'zero_dc', False): z[:, 0] = 0
              a = torch.istft(z, **model.stft_kwargs, window=win, return_complex=False, length=x.shape[-1])
              return a.reshape(mask.shape[1], 2, -1)
      else:
          core = MDX23CCore(model).eval()
          inp = model.stft(x).contiguous()
          t0 = time.perf_counter(); out = core(inp); meta['torch_core_s'] = time.perf_counter() - t0

          def finish(o):
              b, c, f, t = o.shape
              return model.stft.inverse(o.reshape(b, model.num_target_instruments, -1, f, t))[0]
      rec = finish(out)
      ref = full[0].reshape(rec.shape)
      meta['core_vs_full_db'] = float(10 * torch.log10((ref ** 2).sum() / ((ref - rec) ** 2).sum().clamp_min(1e-30)))
if not REUSE: log.info(f"cœur contre modèle complet : {meta['core_vs_full_db']:.1f} dB ; entrée {tuple(inp.shape)} sortie {tuple(out.shape)} ; modèle complet {meta['torch_full_s']:.1f} s, cœur {meta['torch_core_s']:.1f} s ; mémoire max {rss_mb():.0f} Mo")
if not REUSE:
    inp.numpy().astype(np.float32).tofile(os.path.join(outdir, f'{cand}.in.bin'))
    out.numpy().astype(np.float32).tofile(os.path.join(outdir, f'{cand}.torch_out.bin'))
    torch.save(dict(inp=inp, out=out, full=full, x=x), REF)
meta.update(in_shape=list(inp.shape), out_shape=list(out.shape), peak_rss_before_export_mb=rss_mb())
path = os.path.join(outdir, f'{cand}.onnx')
for mode in os.environ.get('MODES', 'dynamo,legacy').split(','):
    t0 = time.perf_counter()
    try:
        if mode == 'dynamo':
            prog = torch.onnx.export(core, (inp,), dynamo=True, opset_version=opset, input_names=['input'], output_names=['output'], external_data=False)
            prog.save(path)
        else:
            torch.onnx.export(core, (inp,), path, dynamo=False, opset_version=min(opset, 17), input_names=['input'], output_names=['output'], do_constant_folding=True)
        meta.update(export_mode=mode, export_s=time.perf_counter() - t0, onnx_bytes=os.path.getsize(path))
        log.info(f"export {mode} réussi en {meta['export_s']:.0f} s : {path} ({meta['onnx_bytes'] / 1e6:.0f} Mo)")
        break
    except Exception as e:
        log.exception(f'export {mode} échoué : {type(e).__name__} : {str(e)[:2000]}')
        meta[f'export_error_{mode}'] = f'{type(e).__name__} : {str(e)[:1500]}'
if 'export_mode' in meta:
    import onnx
    mdl = onnx.load(path, load_external_data=False)
    ops = {}
    for n in mdl.graph.node: ops[n.op_type] = ops.get(n.op_type, 0) + 1
    meta.update(ops=ops, opset_imports={o.domain or 'ai.onnx': o.version for o in mdl.opset_import}, n_nodes=len(mdl.graph.node))
    log.info(f"opérateurs : {ops}")
json.dump(meta, open(os.path.join(outdir, f'{cand}.export.json'), 'w'), indent=1)
